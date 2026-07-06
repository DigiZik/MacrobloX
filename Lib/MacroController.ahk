class MacroController {
  __New(settings, state, recorder, playback, guiApp, macroFiles, notifier, logger) {
    this.Settings := settings
    this.State := state
    this.Recorder := recorder
    this.Playback := playback
    this.Gui := guiApp
    this.MacroFiles := macroFiles
    this.Notifier := notifier
    this.Logger := logger
  }

  RegisterHotkeys() {
    Hotkey(this.Settings.PlayKey, (*) => this.PlayKeyAction())
    Hotkey(this.Settings.RecordKey, (*) => this.RecordKeyAction())
    Hotkey(this.Settings.EditKey, (*) => this.EditKeyAction())
    Hotkey(this.Settings.LoopKey, (*) => this.LoopKeyAction())
    Hotkey(this.Settings.ToggleKey, (*) => this.ToggleScript())
  }

  RecordKeyAction() {
    #SuspendExempt
    if (this.State.Recording) {
      this.StopRecording()
      return
    }
    this.StopLoop(false)
    if (this.MacroFiles.IsDefaultMacroFile() && !this.CreateMacroForRecording())
      return
    if (this.Recorder.Start()) {
      this.Notifier.Show("Recording")
      this.Gui.UpdateState()
    }
  }

  CreateMacroForRecording() {
    try {
      path := this.MacroFiles.CreateTimestampedMacroFile("Macro", true)
      this.State.EditorDirty := false
      this.Gui.ReloadEditorFromFile(false)
      this.Gui.UpdateState("Recording to " this.Settings.GetFileNameFromPath(path))
      return true
    } catch as err {
      this.Logger.ShowError("Recording setup failed", "Could not create a macro file for recording.", err)
      this.Gui.UpdateState()
      return false
    }
  }

  StopRecording() {
    try {
      this.Recorder.Stop()
      this.Notifier.Hide()
      this.Gui.ReloadEditorFromFile(false)
      this.Gui.UpdateState()
    } catch as err {
      this.Logger.ShowError("Stop recording failed", "Could not stop recording.", err)
    }
  }

  PlayKeyAction() {
    #SuspendExempt
    this.StopLoop(false)
    if (this.State.Recording)
      this.StopRecording()
    if (this.State.Playing)
      return
    if (this.Playback.RunMacroFile(false)) {
      this.Gui.UpdateState("Playing macro")
      this.Playback.WatchPlayback(ObjBindMethod(this, "PlaybackFinished"))
    }
  }

  PlaybackFinished() {
    this.Notifier.Timed("Macro finished", "y35", "Green|00FF00", 700)
    this.Gui.UpdateState()
  }

  LoopKeyAction() {
    #SuspendExempt
    if (this.StopLoop(true))
      return
    if (this.State.Recording)
      this.StopRecording()
    if (this.State.Playing)
      this.StopLoop(false)
    this.Playback.StartLoop()
    this.Notifier.Timed("LOOP Started", "y35", "Green|00FF00", 2000)
    this.Gui.UpdateState()
  }

  StopLoop(showTip := true) {
    stopped := this.Playback.StopLoop()
    if (stopped && showTip) {
      this.Notifier.Timed("LOOP Stopped", "y35", "Red|FF4444", 2000)
      this.Gui.UpdateState()
    }
    return stopped
  }

  EditKeyAction() {
    #SuspendExempt
    this.StopLoop(false)
    this.MacroFiles.EnsureEmptyMacroFile()
    if (IsObject(this.Gui.Gui))
      this.Gui.ShowAndFocusEditor()
    else
      Run("notepad.exe `"" this.Settings.CurrentMacroFile "`"")
  }

  ToggleScript() {
    #SuspendExempt
    this.State.ScriptEnabled := !this.State.ScriptEnabled
    mode := this.State.ScriptEnabled ? "On" : "Off"
    if (!this.State.ScriptEnabled) {
      this.StopLoop(false)
      if (this.State.Recording)
        this.StopRecording()
    }
    Hotkey(this.Settings.PlayKey, mode)
    Hotkey(this.Settings.RecordKey, mode)
    Hotkey(this.Settings.EditKey, mode)
    Hotkey(this.Settings.LoopKey, mode)
    color := this.State.ScriptEnabled ? "Green|00FF00" : "Gray|888888"
    message := this.State.ScriptEnabled ? "Macro Recorder ENABLED" : "Macro Recorder DISABLED"
    this.Notifier.Timed(message, "y35", color, 500)
    this.Gui.UpdateState()
  }

  ConfirmEditorCanSwitch() {
    if (!this.State.EditorDirty)
      return true
    result := MsgBox("Save changes to the current macro before switching files?", "Unsaved macro changes", "YesNoCancel Icon?")
    if (result == "Cancel")
      return false
    if (result == "Yes")
      return this.SaveEditorToFile(false)
    return true
  }

  SetCurrentMacroFile(path, savePreference := true, reloadEditor := true) {
    this.MacroFiles.SetCurrentMacroFile(path, savePreference)
    this.State.EditorDirty := false
    if (reloadEditor)
      this.Gui.ReloadEditorFromFile(false)
    this.Gui.UpdateState("Opened " this.Settings.GetFileNameFromPath(this.Settings.CurrentMacroFile))
    return true
  }

  NewMacroFile() {
    if (this.State.Recording) {
      MsgBox("Stop recording before creating a new macro file.", "Macro Recorder", 4096)
      return
    }
    if (!this.ConfirmEditorCanSwitch())
      return
    this.MacroFiles.EnsureMacroFolder()
    defaultName := "Macro-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
    result := InputBox("Name for the new .txt macro file:", "New macro file", "w420 h130", defaultName)
    if (result.Result != "OK")
      return
    name := this.MacroFiles.SanitizeMacroFileName(result.Value)
    if (name == "") {
      MsgBox("Enter a file name for the new macro.", "New macro file", 4096)
      return
    }
    path := this.Settings.ResolveMacroPath(name)
    if (FileExist(path)) {
      overwrite := MsgBox("That macro file already exists. Replace it?", "New macro file", "YesNo Icon?")
      if (overwrite != "Yes")
        return
    }
    try {
      this.MacroFiles.WriteFile(path, this.MacroFiles.EmptyMacroTemplate())
      this.SetCurrentMacroFile(path)
      this.Notifier.Timed("Macro Created")
    } catch as err {
      this.Logger.ShowError("New macro failed", "Could not create macro file.", err)
    }
  }

  OpenMacroFile() {
    if (this.State.Recording) {
      MsgBox("Stop recording before opening another macro file.", "Macro Recorder", 4096)
      return
    }
    if (!this.ConfirmEditorCanSwitch())
      return
    this.MacroFiles.EnsureMacroFolder()
    path := FileSelect(1, this.Settings.MacroDir "\*.txt", "Open .txt macro", "Text macros (*.txt)")
    if (path == "")
      return
    this.SetCurrentMacroFile(path)
  }

  SaveEditorToFile(showTip := true) {
    if (this.State.Recording) {
      MsgBox("Stop recording before saving the macro editor.", "Macro Recorder", 4096)
      return false
    }
    if (this.MacroFiles.IsDefaultMacroFile()) {
      result := MsgBox("DefaultMacro.txt is the reset template. Save this as a new macro file?", "Save macro", "YesNo Icon?")
      if (result != "Yes")
        return false
      return this.SaveEditorAs()
    }
    try {
      this.MacroFiles.WriteCurrent(this.Gui.EditorValue)
      this.State.EditorDirty := false
      if (showTip)
        this.Notifier.Timed("Macro Saved")
      this.Gui.MarkSaved("Saved")
      this.Gui.UpdateState()
      return true
    } catch as err {
      this.Logger.ShowError("Save failed", "Could not save macro file.", err)
      this.Gui.UpdateState()
      return false
    }
  }

  SaveEditorAs() {
    if (this.State.Recording) {
      MsgBox("Stop recording before saving the macro editor.", "Macro Recorder", 4096)
      return
    }
    this.MacroFiles.EnsureMacroFolder()
    defaultPath := this.Settings.MacroDir "\" this.Settings.GetFileNameFromPath(this.Settings.CurrentMacroFile)
    if (this.MacroFiles.IsDefaultMacroFile())
      defaultPath := this.Settings.MacroDir "\Macro-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
    path := FileSelect("S16", defaultPath, "Save .txt macro as", "Text macros (*.txt)")
    if (path == "")
      return false
    path := this.Settings.ResolveMacroPath(path)
    try {
      this.MacroFiles.WriteFile(path, this.Gui.EditorValue)
      this.SetCurrentMacroFile(path, true, true)
      this.Notifier.Timed("Macro Saved As")
      this.Gui.MarkSaved("Saved")
      return true
    } catch as err {
      this.Logger.ShowError("Save As failed", "Could not save macro file.", err)
    }
    return false
  }

  ChooseMacroFolder() {
    folder := DirSelect(this.Settings.MacroDir, 0, "Choose where new .txt macro files are created")
    if (folder == "")
      return
    this.Settings.MacroDir := ConfigManager.NormalizeFolderPath(folder, A_ScriptDir "\Macros")
    this.MacroFiles.EnsureMacroFolder()
    ConfigManager.Save(this.Settings)
    Run("explorer.exe `"" this.Settings.MacroDir "`"")
    this.Gui.UpdateState("New macro folder saved")
  }

  ResetMacroFile() {
    #SuspendExempt
    this.StopLoop(false)
    try {
      this.Recorder.Reset()
      this.Playback.ReleaseModifiers()
      this.State.Looping := false
      this.State.Playing := false
      this.State.LoopPid := 0
      this.State.EditorDirty := false
      this.Settings.MouseMode := "screen"
      ConfigManager.Save(this.Settings)
      this.MacroFiles.SetDefaultMacroFile(true)
      this.Gui.ReloadEditorFromFile(false)
      this.Notifier.Timed("Macro Reset")
      this.Gui.UpdateState("Resetting...")
      SetTimer((*) => Reload(), -250)
    } catch as err {
      this.Logger.ShowError("Reset failed", "Could not reset macro file.", err)
      this.Gui.UpdateState()
    }
  }

  OpenExternalEditor() {
    this.MacroFiles.EnsureEmptyMacroFile()
    Run("notepad.exe `"" this.Settings.CurrentMacroFile "`"")
  }

  ExitApplication(*) {
    #SuspendExempt
    try this.StopLoop(false)
    try {
      if (this.State.Recording)
        this.Recorder.Stop()
    }
    try this.Playback.ReleaseModifiers()
    try this.Notifier.Hide()
    ExitApp()
  }
}
