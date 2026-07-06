class MacroFileService {
  __New(settings, logger) {
    this.Settings := settings
    this.Logger := logger
    this.EnsureMacroFolder()
    this.EnsureEmptyMacroFile()
  }

  EnsureMacroFolder() {
    if (!DirExist(this.Settings.MacroDir))
      DirCreate(this.Settings.MacroDir)
  }

  EmptyMacroTemplate() {
    return "; Empty macro file created by Macro Recorder`n; MacroRecorder.LoopDelay=2000`n; MacroRecorder.LoopSpeed=1x`nExitApp()`n"
  }

  EnsureEmptyMacroFile() {
    this.EnsureMacroFolder()
    if (!FileExist(this.Settings.CurrentMacroFile))
      FileAppend(this.EmptyMacroTemplate(), this.Settings.CurrentMacroFile, "UTF-8")
  }

  ReadCurrent() {
    this.EnsureEmptyMacroFile()
    return FileRead(this.Settings.CurrentMacroFile)
  }

  WriteCurrent(text) {
    this.WriteFile(this.Settings.CurrentMacroFile, text)
  }

  WriteFile(path, text) {
    if (FileExist(path))
      FileDelete(path)
    FileAppend(text, path, "UTF-8")
  }

  SetCurrentMacroFile(path, savePreference := true) {
    path := this.Settings.ResolveMacroPath(path)
    this.Settings.CurrentMacroFile := path
    this.Settings.MacroDir := this.Settings.GetFolderFromPath(path, this.Settings.MacroDir)
    this.EnsureMacroFolder()
    this.EnsureEmptyMacroFile()
    if (savePreference)
      ConfigManager.Save(this.Settings)
    return true
  }

  SetDefaultMacroFile(savePreference := true) {
    this.Settings.CurrentMacroFile := this.Settings.MacroDir "\DefaultMacro.txt"
    this.EnsureMacroFolder()
    this.WriteCurrent(this.EmptyMacroTemplate())
    if (savePreference)
      ConfigManager.Save(this.Settings)
    return this.Settings.CurrentMacroFile
  }

  CreateTimestampedMacroFile(prefix := "Macro", savePreference := true) {
    this.EnsureMacroFolder()
    baseName := prefix "-" FormatTime(, "yyyyMMdd-HHmmss")
    path := this.Settings.ResolveMacroPath(baseName ".txt")
    suffix := 2
    while FileExist(path) {
      path := this.Settings.ResolveMacroPath(baseName "-" suffix ".txt")
      suffix += 1
    }
    this.WriteFile(path, this.EmptyMacroTemplate())
    this.SetCurrentMacroFile(path, savePreference)
    return path
  }

  IsDefaultMacroFile(path := "") {
    if (path == "")
      path := this.Settings.CurrentMacroFile
    defaultPath := this.Settings.ResolveMacroPath(this.Settings.MacroDir "\DefaultMacro.txt")
    return StrLower(path) == StrLower(defaultPath)
  }

  GetCurrentLoopDelay() {
    return this.GetLoopDelayFromText(this.ReadCurrent())
  }

  GetLoopDelayFromText(text) {
    if (RegExMatch(text, "im)^\s*;\s*MacroRecorder\.LoopDelay\s*=\s*(\d+)\s*$", &match))
      return Integer(match[1])
    return 2000
  }

  SetCurrentLoopDelay(delay) {
    delay := Max(0, Integer(delay))
    text := this.ReadCurrent()
    text := this.SetLoopDelayInText(text, delay)
    this.WriteCurrent(text)
    return delay
  }

  SetLoopDelayInText(text, delay) {
    delay := Max(0, Integer(delay))
    line := "; MacroRecorder.LoopDelay=" delay
    if (RegExMatch(text, "im)^\s*;\s*MacroRecorder\.LoopDelay\s*=\s*\d+\s*$"))
      return RegExReplace(text, "im)^\s*;\s*MacroRecorder\.LoopDelay\s*=\s*\d+\s*$", line, , 1)
    if (RegExMatch(text, "im)^\s*ExitApp\(\)?\s*$", &match))
      return RegExReplace(text, "im)^\s*ExitApp\(\)?\s*$", line "`n" match[0], , 1)
    return RTrim(text, "`r`n") "`n" line "`nExitApp()`n"
  }

  GetCurrentLoopSpeed() {
    return this.GetLoopSpeedFromText(this.ReadCurrent())
  }

  GetLoopSpeedFromText(text) {
    if (RegExMatch(text, "im)^\s*;\s*MacroRecorder\.LoopSpeed\s*=\s*(1x|2x|5x|10x)\s*$", &match))
      return match[1]
    return "1x"
  }

  GetLoopSpeedMultiplier(speed := "") {
    speed := speed == "" ? this.GetCurrentLoopSpeed() : speed
    if (speed == "2x")
      return 2
    if (speed == "5x")
      return 5
    if (speed == "10x")
      return 10
    return 1
  }

  SetLoopSpeedInText(text, speed) {
    if (speed != "2x" && speed != "5x" && speed != "10x")
      speed := "1x"
    line := "; MacroRecorder.LoopSpeed=" speed
    if (RegExMatch(text, "im)^\s*;\s*MacroRecorder\.LoopSpeed\s*=\s*(1x|2x|5x|10x)\s*$"))
      return RegExReplace(text, "im)^\s*;\s*MacroRecorder\.LoopSpeed\s*=\s*(1x|2x|5x|10x)\s*$", line, , 1)
    if (RegExMatch(text, "im)^\s*;\s*MacroRecorder\.LoopDelay\s*=\s*\d+\s*$", &match))
      return RegExReplace(text, "im)^\s*;\s*MacroRecorder\.LoopDelay\s*=\s*\d+\s*$", match[0] "`n" line, , 1)
    if (RegExMatch(text, "im)^\s*ExitApp\(\)?\s*$", &match))
      return RegExReplace(text, "im)^\s*ExitApp\(\)?\s*$", line "`n" match[0], , 1)
    return RTrim(text, "`r`n") "`n" line "`nExitApp()`n"
  }

  WritePlaybackCopy() {
    text := this.ReadCurrent()
    multiplier := this.GetLoopSpeedMultiplier(this.GetLoopSpeedFromText(text))
    if (multiplier <= 1)
      return this.Settings.CurrentMacroFile
    path := A_Temp "\MacroRecorderPlayback-" A_TickCount ".ahk"
    FileAppend(this.ScalePlaybackTiming(text, multiplier), path, "UTF-8")
    return path
  }

  ScalePlaybackTiming(text, multiplier) {
    normalized := RegExReplace(text, "\R", "`n")
    output := ""
    for index, line in StrSplit(normalized, "`n")
      output .= (index == 1 ? "" : "`n") this.ScaleTimingLine(line, multiplier)
    return output
  }

  ScaleTimingLine(line, multiplier) {
    if (RegExMatch(line, "i)^(\s*Sleep\()\s*(\d+)(\s*\).*)$", &match))
      return match[1] Max(1, Round(Integer(match[2]) / multiplier)) match[3]
    if (RegExMatch(line, "i)^(\s*SetKeyDelay\()\s*(-?\d+)(.*)$", &match)) {
      delay := Integer(match[2])
      if (delay > 0)
        delay := Max(1, Round(delay / multiplier))
      return match[1] delay match[3]
    }
    return line
  }

  SanitizeMacroFileName(name) {
    name := Trim(name)
    name := RegExReplace(name, '[<>:"/\\|?*]', "_")
    return this.Settings.EnsureTxtExtension(name)
  }
}
