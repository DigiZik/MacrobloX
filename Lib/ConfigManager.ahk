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
}
