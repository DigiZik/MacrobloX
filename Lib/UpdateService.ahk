class UpdateService {
  __New(settings, logger, appDir) {
    this.Settings := settings
    this.Logger := logger
    this.AppDir := appDir
    this.LatestReleaseUrl := "https://api.github.com/repos/" AppVersion.Repository "/releases/latest"
  }

  CheckLatest() {
    response := this.GetText(this.LatestReleaseUrl)
    if (this.GetJsonBool(response, "prerelease"))
      return { HasUpdate: false }

    tag := this.GetJsonString(response, "tag_name")
    if (tag == "")
      throw Error("GitHub latest release response did not include a tag.")
    version := this.NormalizeVersion(tag)
    if (this.CompareVersions(version, AppVersion.Number) <= 0)
      return { HasUpdate: false, Version: version, VersionTag: tag }

    assetName := "MacrobloX-v" version "-source.zip"
    assetUrl := this.GetReleaseAssetUrl(response, assetName)
    if (assetUrl == "")
      throw Error("Release " tag " does not include " assetName ".")

    return { HasUpdate: true, Version: version, VersionTag: "v" version, AssetName: assetName, AssetUrl: assetUrl }
  }

  DownloadAndInstall(update) {
    updateDir := A_Temp "\MacrobloXUpdate-" A_TickCount
    DirCreate(updateDir)
    zipPath := updateDir "\" update.AssetName
    scriptPath := updateDir "\Install-MacrobloXUpdate.ps1"

    this.Logger.Info("Downloading update " update.VersionTag " from " update.AssetUrl)
    Download(update.AssetUrl, zipPath)
    if (!FileExist(zipPath))
      throw Error("Update download did not create " zipPath ".")

    FileAppend(this.BuildUpdaterScript(), scriptPath, "UTF-8")
    pid := ProcessExist()
    restartPath := A_ScriptFullPath
    command := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' scriptPath '" -AppDir "' this.AppDir '" -ZipPath "' zipPath '" -AhkPath "' A_AhkPath '" -RestartPath "' restartPath '" -ParentPid ' pid
    this.Logger.Info("Starting detached updater for " update.VersionTag ".")
    Run(command, , "Hide")
    ExitApp()
  }

  GetText(url) {
    request := ComObject("WinHttp.WinHttpRequest.5.1")
    request.Open("GET", url, false)
    request.SetRequestHeader("Accept", "application/vnd.github+json")
    request.SetRequestHeader("User-Agent", "MacrobloX/" AppVersion.Number)
    request.Send()
    status := request.Status
    if (status < 200 || status >= 300)
      throw Error("GitHub returned HTTP " status ".")
    return request.ResponseText
  }

  GetJsonString(json, key) {
    pattern := '"' key '"\s*:\s*"((?:\\.|[^"\\])*)"'
    if (!RegExMatch(json, pattern, &match))
      return ""
    return this.UnescapeJsonString(match[1])
  }

  GetJsonBool(json, key) {
    pattern := '"' key '"\s*:\s*(true|false)'
    if (!RegExMatch(json, pattern, &match))
      return false
    return match[1] == "true"
  }

  GetReleaseAssetUrl(json, assetName) {
    assetPattern := 's)"name"\s*:\s*"' this.EscapeRegex(assetName) '".*?"browser_download_url"\s*:\s*"((?:\\.|[^"\\])*)"'
    if (RegExMatch(json, assetPattern, &match))
      return this.UnescapeJsonString(match[1])

    fallbackPattern := 's)"browser_download_url"\s*:\s*"((?:\\.|[^"\\])*)".*?"name"\s*:\s*"' this.EscapeRegex(assetName) '"'
    if (RegExMatch(json, fallbackPattern, &match))
      return this.UnescapeJsonString(match[1])
    return ""
  }

  NormalizeVersion(tag) {
    tag := Trim(tag)
    if (SubStr(tag, 1, 1) == "v" || SubStr(tag, 1, 1) == "V")
      tag := SubStr(tag, 2)
    if (!RegExMatch(tag, "^\d+\.\d+\.\d+$"))
      throw Error("Unsupported release version: " tag)
    return tag
  }

  CompareVersions(left, right) {
    leftParts := StrSplit(left, ".")
    rightParts := StrSplit(right, ".")
    Loop 3 {
      l := Integer(leftParts[A_Index])
      r := Integer(rightParts[A_Index])
      if (l > r)
        return 1
      if (l < r)
        return -1
    }
    return 0
  }

  UnescapeJsonString(value) {
    value := StrReplace(value, '\"', '"')
    value := StrReplace(value, "\\", "\")
    value := StrReplace(value, "\/", "/")
    return value
  }

  EscapeRegex(value) {
    return RegExReplace(value, "([\\\.\*\?\+\[\{\|\(\)\^\$])", "\$1")
  }

  BuildUpdaterScript() {
    lines := [
      "param(",
      "  [Parameter(Mandatory=$true)][string]$AppDir,",
      "  [Parameter(Mandatory=$true)][string]$ZipPath,",
      "  [Parameter(Mandatory=$true)][string]$AhkPath,",
      "  [Parameter(Mandatory=$true)][string]$RestartPath,",
      "  [Parameter(Mandatory=$true)][int]$ParentPid",
      ")",
      "",
      "$ErrorActionPreference = 'Stop'",
      "$extractDir = Join-Path ([System.IO.Path]::GetDirectoryName($ZipPath)) 'extracted'",
      "if (Test-Path -LiteralPath $extractDir) {",
      "  Remove-Item -LiteralPath $extractDir -Recurse -Force",
      "}",
      "New-Item -ItemType Directory -Path $extractDir -Force | Out-Null",
      "",
      "try {",
      "  Wait-Process -Id $ParentPid -Timeout 20 -ErrorAction SilentlyContinue",
      "} catch {",
      "}",
      "",
      "Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractDir -Force",
      "$sourceDir = $extractDir",
      "$children = @(Get-ChildItem -LiteralPath $extractDir)",
      "if ($children.Count -eq 1 -and $children[0].PSIsContainer) {",
      "  $sourceDir = $children[0].FullName",
      "}",
      "",
      "$requiredPaths = @('MacroRecorder.ahk', 'README.md', 'LICENSE', 'Lib', 'Gui')",
      "$missingPaths = @($requiredPaths | Where-Object { !(Test-Path -LiteralPath (Join-Path $sourceDir $_)) })",
      "if ($missingPaths.Count -gt 0) {",
      "  throw ('Update package is incomplete. Missing: ' + ($missingPaths -join ', '))",
      "}",
      "",
      "$mainScript = Join-Path $sourceDir 'MacroRecorder.ahk'",
      "$includePaths = @()",
      "foreach ($line in Get-Content -LiteralPath $mainScript) {",
      "  if ($line -notmatch '^\s*#Include\s+(.+?)\s*$') {",
      "    continue",
      "  }",
      "  $includePath = $Matches[1].Trim().Trim([char]34)",
      "  $includePaths += $includePath",
      "  if (!(Test-Path -LiteralPath (Join-Path $sourceDir $includePath) -PathType Leaf)) {",
      "    throw ('Update package is missing required include: ' + $includePath)",
      "  }",
      "}",
      "",
      "$sourceLib = Join-Path $sourceDir 'Lib'",
      "$targetLib = Join-Path $AppDir 'Lib'",
      "if (!(Test-Path -LiteralPath $targetLib)) {",
      "  New-Item -ItemType Directory -Path $targetLib -Force | Out-Null",
      "}",
      "Copy-Item -Path (Join-Path $sourceLib '*') -Destination $targetLib -Recurse -Force",
      "",
      "$sourceGui = Join-Path $sourceDir 'Gui'",
      "$targetGui = Join-Path $AppDir 'Gui'",
      "if (!(Test-Path -LiteralPath $targetGui)) {",
      "  New-Item -ItemType Directory -Path $targetGui -Force | Out-Null",
      "}",
      "Copy-Item -Path (Join-Path $sourceGui '*') -Destination $targetGui -Recurse -Force",
      "",
      "$missingInstalledIncludes = @($includePaths | Where-Object { !(Test-Path -LiteralPath (Join-Path $AppDir $_) -PathType Leaf) })",
      "if ($missingInstalledIncludes.Count -gt 0) {",
      "  throw ('Update did not install required includes: ' + ($missingInstalledIncludes -join ', '))",
      "}",
      "",
      "foreach ($file in @('README.md', 'LICENSE')) {",
      "  Copy-Item -LiteralPath (Join-Path $sourceDir $file) -Destination (Join-Path $AppDir $file) -Force",
      "}",
      "; Replace the entry point last so it never references dependencies that were not installed.",
      "Copy-Item -LiteralPath $mainScript -Destination (Join-Path $AppDir 'MacroRecorder.ahk') -Force",
      "",
      "Start-Process -FilePath $AhkPath -ArgumentList @($RestartPath) -WorkingDirectory $AppDir"
    ]
    script := ""
    for line in lines
      script .= line "`r`n"
    return script
  }
}
