class ConfigManager {
  static Load(scriptDir, args) {
    configPath := scriptDir "\MacroRecorder.ini"
    defaults := Map(
      "PLAY_KEY", "F1",
      "RECORD_KEY", "F2",
      "EDIT_KEY", "F3",
      "TOGGLE_KEY", "F4",
      "LOOP_KEY", "F6",
      "LOOP_DELAY", 2000,
      "MouseMode", "screen",
      "RecordSleep", "true",
      "APP_THEME", "dark",
      "CHECK_UPDATES_ON_STARTUP", "true",
      "DISCORD_ENABLED", "false",
      "DISCORD_WEBHOOK_URL", "",
      "DISCORD_USER_ID", "",
      "DISCORD_SEND_SCREENSHOTS", "false",
      "DISCORD_SCREENSHOT_CROP_ENABLED", "false",
      "DISCORD_SCREENSHOT_CROP_X", 0,
      "DISCORD_SCREENSHOT_CROP_Y", 0,
      "DISCORD_SCREENSHOT_CROP_W", 0,
      "DISCORD_SCREENSHOT_CROP_H", 0,
      "MACRO_DIR", scriptDir "\Macros",
      "CURRENT_MACRO_FILE", scriptDir "\Macros\DefaultMacro.txt",
      "ConfigPath", configPath
    )

    settings := MacroRecorderSettings(defaults)
    if (FileExist(configPath))
      ConfigManager.ReadIni(configPath, settings)

    settings.MacroDir := ConfigManager.NormalizeFolderPath(settings.MacroDir, scriptDir "\Macros")
    if (args.Length >= 1 && args[1] != "")
      settings.CurrentMacroFile := settings.ResolveMacroPath(args[1])
    else
      settings.CurrentMacroFile := settings.ResolveMacroPath(settings.CurrentMacroFile)

    settings.MacroDir := settings.GetFolderFromPath(settings.CurrentMacroFile, settings.MacroDir)
    settings.Normalize()
    ConfigManager.Save(settings)
    return settings
  }

  static ReadIni(path, settings) {
    settings.PlayKey := IniRead(path, "Hotkeys", "Play", settings.PlayKey)
    settings.RecordKey := IniRead(path, "Hotkeys", "Record", settings.RecordKey)
    settings.EditKey := IniRead(path, "Hotkeys", "Edit", settings.EditKey)
    settings.ToggleKey := IniRead(path, "Hotkeys", "Toggle", settings.ToggleKey)
    settings.LoopKey := IniRead(path, "Hotkeys", "Loop", settings.LoopKey)
    settings.MouseMode := IniRead(path, "Recording", "MouseMode", settings.MouseMode)
    settings.RecordSleep := IniRead(path, "Recording", "RecordSleep", settings.RecordSleep)
    settings.AppTheme := IniRead(path, "Ui", "Theme", settings.AppTheme)
    settings.CheckUpdatesOnStartup := IniRead(path, "Updates", "CheckOnStartup", settings.CheckUpdatesOnStartup)
    settings.DiscordEnabled := IniRead(path, "Discord", "Enabled", settings.DiscordEnabled)
    settings.DiscordWebhookUrl := IniRead(path, "Discord", "WebhookUrl", settings.DiscordWebhookUrl)
    settings.DiscordUserId := IniRead(path, "Discord", "UserId", settings.DiscordUserId)
    settings.DiscordSendScreenshots := IniRead(path, "Discord", "SendScreenshots", settings.DiscordSendScreenshots)
    settings.DiscordScreenshotCropEnabled := IniRead(path, "Discord", "ScreenshotCropEnabled", settings.DiscordScreenshotCropEnabled)
    settings.DiscordScreenshotCropX := IniRead(path, "Discord", "ScreenshotCropX", settings.DiscordScreenshotCropX)
    settings.DiscordScreenshotCropY := IniRead(path, "Discord", "ScreenshotCropY", settings.DiscordScreenshotCropY)
    settings.DiscordScreenshotCropW := IniRead(path, "Discord", "ScreenshotCropW", settings.DiscordScreenshotCropW)
    settings.DiscordScreenshotCropH := IniRead(path, "Discord", "ScreenshotCropH", settings.DiscordScreenshotCropH)
    settings.MacroDir := IniRead(path, "Files", "MacroDir", settings.MacroDir)
    settings.CurrentMacroFile := IniRead(path, "Files", "CurrentMacroFile", settings.CurrentMacroFile)
  }

  static Save(settings) {
    try {
      IniWrite(settings.PlayKey, settings.ConfigPath, "Hotkeys", "Play")
      IniWrite(settings.RecordKey, settings.ConfigPath, "Hotkeys", "Record")
      IniWrite(settings.EditKey, settings.ConfigPath, "Hotkeys", "Edit")
      IniWrite(settings.ToggleKey, settings.ConfigPath, "Hotkeys", "Toggle")
      IniWrite(settings.LoopKey, settings.ConfigPath, "Hotkeys", "Loop")
      IniWrite(settings.MouseMode, settings.ConfigPath, "Recording", "MouseMode")
      IniWrite(settings.RecordSleep, settings.ConfigPath, "Recording", "RecordSleep")
      IniWrite(settings.AppTheme, settings.ConfigPath, "Ui", "Theme")
      IniWrite(settings.CheckUpdatesOnStartup, settings.ConfigPath, "Updates", "CheckOnStartup")
      IniWrite(settings.DiscordEnabled, settings.ConfigPath, "Discord", "Enabled")
      IniWrite(settings.DiscordWebhookUrl, settings.ConfigPath, "Discord", "WebhookUrl")
      IniWrite(settings.DiscordUserId, settings.ConfigPath, "Discord", "UserId")
      IniWrite(settings.DiscordSendScreenshots, settings.ConfigPath, "Discord", "SendScreenshots")
      IniWrite(settings.DiscordScreenshotCropEnabled, settings.ConfigPath, "Discord", "ScreenshotCropEnabled")
      IniWrite(settings.DiscordScreenshotCropX, settings.ConfigPath, "Discord", "ScreenshotCropX")
      IniWrite(settings.DiscordScreenshotCropY, settings.ConfigPath, "Discord", "ScreenshotCropY")
      IniWrite(settings.DiscordScreenshotCropW, settings.ConfigPath, "Discord", "ScreenshotCropW")
      IniWrite(settings.DiscordScreenshotCropH, settings.ConfigPath, "Discord", "ScreenshotCropH")
      IniWrite(settings.MacroDir, settings.ConfigPath, "Files", "MacroDir")
      IniWrite(settings.CurrentMacroFile, settings.ConfigPath, "Files", "CurrentMacroFile")
      return true
    } catch as err {
      MsgBox("Could not save settings.`n`n" err.Message, "Settings not saved", 4096)
      return false
    }
  }

  static NormalizeFolderPath(path, fallback) {
    path := Trim(path)
    if (path == "")
      return fallback
    return RegExReplace(path, "\\+$")
  }

  static NormalizeBool(value, fallback := "false") {
    value := StrLower(Trim(value))
    if (value == "true" || value == "1" || value == "yes" || value == "on")
      return "true"
    if (value == "false" || value == "0" || value == "no" || value == "off")
      return "false"
    return fallback
  }
}

class MacroRecorderSettings {
  __New(defaults) {
    this.PlayKey := defaults["PLAY_KEY"]
    this.RecordKey := defaults["RECORD_KEY"]
    this.EditKey := defaults["EDIT_KEY"]
    this.ToggleKey := defaults["TOGGLE_KEY"]
    this.LoopKey := defaults["LOOP_KEY"]
    this.LoopDelay := defaults["LOOP_DELAY"]
    this.MouseMode := defaults["MouseMode"]
    this.RecordSleep := defaults["RecordSleep"]
    this.AppTheme := defaults["APP_THEME"]
    this.CheckUpdatesOnStartup := defaults["CHECK_UPDATES_ON_STARTUP"]
    this.DiscordEnabled := defaults["DISCORD_ENABLED"]
    this.DiscordWebhookUrl := defaults["DISCORD_WEBHOOK_URL"]
    this.DiscordUserId := defaults["DISCORD_USER_ID"]
    this.DiscordSendScreenshots := defaults["DISCORD_SEND_SCREENSHOTS"]
    this.DiscordScreenshotCropEnabled := defaults["DISCORD_SCREENSHOT_CROP_ENABLED"]
    this.DiscordScreenshotCropX := defaults["DISCORD_SCREENSHOT_CROP_X"]
    this.DiscordScreenshotCropY := defaults["DISCORD_SCREENSHOT_CROP_Y"]
    this.DiscordScreenshotCropW := defaults["DISCORD_SCREENSHOT_CROP_W"]
    this.DiscordScreenshotCropH := defaults["DISCORD_SCREENSHOT_CROP_H"]
    this.MacroDir := defaults["MACRO_DIR"]
    this.CurrentMacroFile := defaults["CURRENT_MACRO_FILE"]
    this.ConfigPath := defaults["ConfigPath"]
  }

  Normalize() {
    if (this.MouseMode != "screen" && this.MouseMode != "window" && this.MouseMode != "relative")
      this.MouseMode := "screen"
    this.RecordSleep := "true"
    if (this.AppTheme != "light" && this.AppTheme != "dark")
      this.AppTheme := "dark"
    this.CheckUpdatesOnStartup := ConfigManager.NormalizeBool(this.CheckUpdatesOnStartup, "true")
    this.DiscordEnabled := ConfigManager.NormalizeBool(this.DiscordEnabled, "false")
    this.DiscordWebhookUrl := Trim(this.DiscordWebhookUrl)
    this.DiscordUserId := Trim(this.DiscordUserId)
    this.DiscordSendScreenshots := ConfigManager.NormalizeBool(this.DiscordSendScreenshots, "false")
    this.DiscordScreenshotCropEnabled := ConfigManager.NormalizeBool(this.DiscordScreenshotCropEnabled, "false")
    this.DiscordScreenshotCropX := this.NormalizeInteger(this.DiscordScreenshotCropX, 0)
    this.DiscordScreenshotCropY := this.NormalizeInteger(this.DiscordScreenshotCropY, 0)
    this.DiscordScreenshotCropW := this.NormalizeInteger(this.DiscordScreenshotCropW, 0)
    this.DiscordScreenshotCropH := this.NormalizeInteger(this.DiscordScreenshotCropH, 0)
    if (this.DiscordScreenshotCropW < 16 || this.DiscordScreenshotCropH < 16) {
      this.DiscordScreenshotCropEnabled := "false"
      this.DiscordScreenshotCropX := 0
      this.DiscordScreenshotCropY := 0
      this.DiscordScreenshotCropW := 0
      this.DiscordScreenshotCropH := 0
    }
    if (!IsInteger(this.LoopDelay) || this.LoopDelay < 0)
      this.LoopDelay := 1000
    this.MacroDir := ConfigManager.NormalizeFolderPath(this.MacroDir, A_ScriptDir "\Macros")
    this.CurrentMacroFile := this.ResolveMacroPath(this.CurrentMacroFile)
  }

  ResolveMacroPath(path) {
    path := Trim(path)
    if (path == "")
      return this.MacroDir "\DefaultMacro.txt"
    if (this.IsAbsolutePath(path))
      return this.EnsureTxtExtension(path)
    return this.EnsureTxtExtension(this.MacroDir "\" path)
  }

  IsAbsolutePath(path) {
    return RegExMatch(path, "i)^[A-Z]:\\|^\\\\")
  }

  EnsureTxtExtension(path) {
    SplitPath(path,,, &ext)
    if (ext == "")
      return path ".txt"
    if (StrLower(ext) != "txt")
      return RegExReplace(path, "\.[^\\.]+$", ".txt")
    return path
  }

  GetFolderFromPath(path, fallback := "") {
    SplitPath(path,, &dir)
    return dir != "" ? dir : fallback
  }

  GetFileNameFromPath(path) {
    SplitPath(path, &name)
    return name
  }

  NormalizeInteger(value, fallback := 0) {
    value := Trim(value)
    return RegExMatch(value, "^-?\d+$") ? Integer(value) : fallback
  }

  HasDiscordScreenshotCrop() {
    return this.DiscordScreenshotCropEnabled == "true"
      && this.DiscordScreenshotCropW >= 16
      && this.DiscordScreenshotCropH >= 16
  }

  DiscordScreenshotCropSummary() {
    if (!this.HasDiscordScreenshotCrop())
      return "Full current screen"
    return "Crop: " this.DiscordScreenshotCropW "x" this.DiscordScreenshotCropH
      . " at " this.DiscordScreenshotCropX "," this.DiscordScreenshotCropY
  }
}
