class WebViewAppGui {
  __New(settings, state, macroFiles, logger, roblox, screenshotService := "") {
    this.Settings := settings
    this.State := state
    this.MacroFiles := macroFiles
    this.Logger := logger
    this.Roblox := roblox
    this.ScreenshotService := screenshotService
    this.Controller := ""
    this.Gui := ""
    this.BrowserControl := ""
    this.Browser := ""
    this.BridgeHandler := ObjBindMethod(this, "PollBridge")
    this.AttachHandler := ObjBindMethod(this, "SyncRobloxWorkspace")
    this.CopyHandler := ObjBindMethod(this, "CopyFocusedInput")
    this.CutHandler := ObjBindMethod(this, "CutFocusedInput")
    this.PasteHandler := ObjBindMethod(this, "PasteFocusedInput")
    this.SelectAllHandler := ObjBindMethod(this, "SelectAllFocusedInput")
    this.AttachedToRoblox := false
    this.IsMinimized := false
    this.LastSavedText := "Loaded"
    this.EditorLoaded := false
    this.HiddenBeforeRows := []
    this.HiddenAfterRows := []
    this.HiddenLineCount := 0
    this.RecordingMinimized := false
    this.RecordingMinMax := 0
    this.PendingScreenshotCropEnabled := settings.DiscordScreenshotCropEnabled
    this.PendingScreenshotCropX := settings.DiscordScreenshotCropX
    this.PendingScreenshotCropY := settings.DiscordScreenshotCropY
    this.PendingScreenshotCropW := settings.DiscordScreenshotCropW
    this.PendingScreenshotCropH := settings.DiscordScreenshotCropH
  }

  SetController(controller) {
    this.Controller := controller
  }

  RegisterClipboardHotkeys() {
    HotIfWinActive("ahk_id " this.Gui.Hwnd)
    Hotkey("^c", this.CopyHandler, "On")
    Hotkey("^x", this.CutHandler, "On")
    Hotkey("^v", this.PasteHandler, "On")
    Hotkey("^a", this.SelectAllHandler, "On")
    HotIfWinActive()
  }

  Build() {
    try {
      this.Settings.Normalize()
      this.MacroFiles.EnsureEmptyMacroFile()

      this.Gui := Gui("+Resize +MinSize960x640", "MacrobloX - " AppVersion.Display())
      this.Gui.MarginX := 0
      this.Gui.MarginY := 0
      this.BrowserControl := this.Gui.Add("ActiveX", "x0 y0 w960 h640", "Shell.Explorer")
      this.Browser := this.BrowserControl.Value
      this.Browser.Silent := true
      this.Gui.OnEvent("Size", ObjBindMethod(this, "Resize"))
      this.Gui.OnEvent("Close", (*) => this.CloseApplication())

      indexPath := A_ScriptDir "\Gui\index.html"
      this.Browser.Navigate("file:///" StrReplace(indexPath, "\", "/"))
      this.Gui.Show("Maximize")
      this.RegisterClipboardHotkeys()
      SetTimer(ObjBindMethod(this, "InitialPush"), -700)
      SetTimer(this.BridgeHandler, 120)
      SetTimer(this.AttachHandler, 1500)
    } catch as err {
      this.Logger.ShowError("GUI startup failed", "Could not start the MacrobloX interface.", err)
      throw err
    }
  }

  InitialPush() {
    try {
      if (!this.IsDocumentReady()) {
        SetTimer(ObjBindMethod(this, "InitialPush"), -250)
        return
      }
      this.ReloadEditorFromFile(false)
      this.UpdateState()
      this.SyncRobloxWorkspace()
    } catch as err {
      this.Logger.ShowError("GUI refresh failed", "Could not initialize the MacrobloX interface.", err)
    }
  }

  IsDocumentReady() {
    try {
      if (!IsObject(this.Browser) || this.Browser.Busy)
        return false
      doc := this.Browser.Document
      return IsObject(doc) && doc.readyState == "complete" && IsObject(doc.getElementById("macroRows"))
    } catch {
      return false
    }
  }

  Resize(thisGui, minMax, width, height) {
    if (minMax == -1) {
      this.IsMinimized := true
      if (this.AttachedToRoblox) {
        this.Roblox.Restore()
        this.AttachedToRoblox := false
      }
      this.UpdateState()
      return
    }
    this.IsMinimized := false
    try this.BrowserControl.Move(0, 0, width, height)
    this.SyncRobloxWorkspace()
    this.UpdateState()
  }

  MinimizeForStandaloneRecording() {
    if (!IsObject(this.Gui) || this.Roblox.IsAvailable())
      return false
    try {
      this.RecordingMinMax := WinGetMinMax("ahk_id " this.Gui.Hwnd)
      this.RecordingMinimized := true
      this.IsMinimized := true
      this.Gui.Show("Minimize")
      return true
    } catch as err {
      this.RecordingMinimized := false
      this.Logger.Warn("Could not minimize MacrobloX for standalone recording: " err.Message)
      return false
    }
  }

  MinimizeForStandalonePlayback() {
    return this.MinimizeForStandaloneRecording()
  }

  RestoreAfterStandaloneRecording() {
    if (!this.RecordingMinimized || !IsObject(this.Gui))
      return false
    this.RecordingMinimized := false
    this.IsMinimized := false
    try {
      hwnd := "ahk_id " this.Gui.Hwnd
      WinShow(hwnd)
      if (this.RecordingMinMax == 1) {
        this.Gui.Show("Maximize")
      } else {
        WinRestore(hwnd)
        this.Gui.Show("Restore")
      }
      WinActivate(hwnd)
      this.SyncRobloxWorkspace()
      this.UpdateState()
      return true
    } catch as err {
      this.Logger.Warn("Could not restore MacrobloX after standalone recording: " err.Message)
      return false
    }
  }

  RestoreAfterStandalonePlayback() {
    return this.RestoreAfterStandaloneRecording()
  }

  PollBridge() {
    if (!IsObject(this.Browser))
      return
    if (!this.IsDocumentReady())
      return
    try {
      doc := this.Browser.Document
      title := doc.title
      if (InStr(title, "MacrobloXBridge:") != 1)
        return
      action := this.GetElementValue("bridgePayload")
      doc.title := "MacrobloX"
      this.HandleAction(action)
    } catch {
    }
  }

  HandleAction(action) {
    if (action == "")
      return
    try {
      if (action == "record")
        this.Controller.RecordKeyAction()
      else if (action == "play")
        this.Controller.PlayKeyAction()
      else if (action == "loop")
        this.Controller.LoopKeyAction()
      else if (action == "toggleHotkeys")
        this.Controller.ToggleScript()
      else if (action == "reset")
        this.Controller.ResetMacroFile()
      else if (action == "focusEditor")
        this.ShowAndFocusEditor()
      else if (action == "save")
        this.Controller.SaveEditorToFile()
      else if (action == "reload")
        this.ReloadEditorFromFile(true)
      else if (action == "external")
        this.Controller.OpenExternalEditor()
      else if (action == "fileNew")
        this.Controller.NewMacroFile()
      else if (action == "fileOpen")
        this.Controller.OpenMacroFile()
      else if (action == "fileSaveAs")
        this.Controller.SaveEditorAs()
      else if (action == "fileChooseFolder")
        this.Controller.ChooseMacroFolder()
      else if (action == "addAction")
        this.HandleAddAction()
      else if (action == "editorDirty")
        this.MarkEditorDirty()
      else if (action == "loopControls")
        this.HandleLoopControlsChanged()
      else if (action == "saveSettings")
        this.SaveSettingsFromGui()
      else if (action == "testWebhook")
        this.Controller.TestWebhook(this.GetDiscordSettingsSnapshot())
      else if (action == "setScreenshotCrop")
        this.SetScreenshotCrop()
      else if (action == "clearScreenshotCrop")
        this.ClearScreenshotCrop()
      else if (action == "syncWorkspace")
        this.SyncRobloxWorkspace()
    } catch as err {
      this.Logger.ShowError("Action failed", "MacrobloX could not finish the `" action "` action.", err)
      this.UpdateState(action " failed")
    }
  }

  HandleAddAction() {
    action := this.GetElementValue("addAction")
    this.SetElementValue("addAction", "")
    if (action == "")
      return
    if (action == "Send")
      this.InsertEditorText("Send `"{Blind}{Enter}`"")
    else if (action == "Sleep")
      this.InsertEditorText("Sleep(500)")
    else if (action == "MouseClick")
      this.InsertEditorText(this.BuildMouseClickLine("L"))
    else if (action == "MouseDown")
      this.InsertEditorText(this.BuildMouseClickLine("L", "D"))
    else if (action == "MouseUp")
      this.InsertEditorText(this.BuildMouseClickLine("L", "U"))
  }

  BuildMouseClickLine(button, mode := "") {
    try {
      CoordMode("Mouse", this.Settings.MouseMode == "window" ? "Window" : "Screen")
      MouseGetPos(&x, &y)
      if (mode == "D" || mode == "U")
        return "MouseClick(`"" button "`", " x ", " y ",,, `"" mode "`")"
      return "MouseClick(`"" button "`", " x ", " y ")"
    } catch {
      if (mode == "D" || mode == "U")
        return "MouseClick(`"" button "`", 0, 0,,, `"" mode "`")"
      return "MouseClick(`"" button "`", 0, 0)"
    }
  }

  HandleLoopControlsChanged() {
    if (this.State.EditorLoading)
      return
    delayText := Trim(this.GetElementValue("loopDelay"))
    if (delayText == "" || !RegExMatch(delayText, "^\d+$")) {
      this.UpdateState("Loop delay must be a number")
      return
    }
    speed := this.GetElementValue("loopSpeed")
    this.MarkEditorDirty()
  }

  UseWindowMouseModeForRoblox() {
    if (this.Settings.MouseMode == "window")
      return
    this.Settings.MouseMode := "window"
    this.Settings.Normalize()
    this.UpdateState("Using window mouse mode for Roblox")
  }

  ReloadEditorFromFile(promptIfDirty := true) {
    if (promptIfDirty && this.State.EditorDirty) {
      result := MsgBox("Reload and discard unsaved editor changes?", "Reload macro", "YesNo Icon?")
      if (result != "Yes")
        return
    }
    this.MacroFiles.EnsureEmptyMacroFile()
    this.State.EditorLoading := true
    text := this.MacroFiles.ReadCurrent()
    this.SetEditorText(text, this.MacroFiles.GetLoopDelayFromText(text), this.MacroFiles.GetLoopSpeedFromText(text))
    this.State.EditorLoading := false
    this.State.EditorDirty := false
    this.EditorLoaded := true
    this.MarkSaved("Loaded")
    this.UpdateState()
  }

  MarkEditorDirty() {
    if (this.State.EditorLoading)
      return
    this.State.EditorDirty := true
    this.UpdateState()
  }

  MarkSaved(prefix := "Saved") {
    this.LastSavedText := prefix " " FormatTime(, "HH:mm:ss")
    this.UpdateState()
  }

  UpdateState(message := "") {
    if (!IsObject(this.Browser))
      return
    if (message != "")
      status := message
    else if (!this.State.ScriptEnabled)
      status := "Disabled"
    else if (this.State.Recording)
      status := "Recording"
    else if (this.State.Playing)
      status := "Playing"
    else if (this.State.Looping)
      status := "Looping"
    else
      status := "Idle"

    robloxStatus := this.GetRobloxStatusText()
    saveState := this.State.EditorDirty ? "Unsaved changes" : this.LastSavedText
    stateJson := "{"
      . '"version":"' this.JsonEscape(AppVersion.Display()) '",'
      . '"theme":"' this.JsonEscape(this.Settings.AppTheme) '",'
      . '"status":"' this.JsonEscape(status) '",'
      . '"robloxStatus":"' this.JsonEscape(robloxStatus) '",'
      . '"robloxAttached":' (this.AttachedToRoblox ? "true" : "false") ","
      . '"currentMacroFile":"' this.JsonEscape(this.Settings.CurrentMacroFile) '",'
      . '"macroDir":"' this.JsonEscape(this.Settings.MacroDir) '",'
      . '"saveState":"' this.JsonEscape(saveState) '",'
      . '"recordButton":"' this.JsonEscape(this.State.Recording ? "Stop recording  " this.Settings.RecordKey : "Record  " this.Settings.RecordKey) '",'
      . '"playButton":"' this.JsonEscape("Play  " this.Settings.PlayKey) '",'
      . '"loopButton":"' this.JsonEscape(this.State.Looping ? "Stop  " this.Settings.LoopKey : "Loop  " this.Settings.LoopKey) '",'
      . '"toggleButton":"' this.JsonEscape(this.State.ScriptEnabled ? "Disable hotkeys  " this.Settings.ToggleKey : "Enable hotkeys  " this.Settings.ToggleKey) '",'
      . '"mouseMode":"' this.JsonEscape(this.Settings.MouseMode) '",'
      . '"checkUpdatesOnStartup":"' this.JsonEscape(this.Settings.CheckUpdatesOnStartup) '",'
      . '"discordEnabled":"' this.JsonEscape(this.Settings.DiscordEnabled) '",'
      . '"discordWebhookUrl":"' this.JsonEscape(this.Settings.DiscordWebhookUrl) '",'
      . '"discordUserId":"' this.JsonEscape(this.Settings.DiscordUserId) '",'
      . '"discordSendScreenshots":"' this.JsonEscape(this.Settings.DiscordSendScreenshots) '",'
      . '"discordScreenshotCropEnabled":"' this.JsonEscape(this.PendingScreenshotCropEnabled) '",'
      . '"discordScreenshotCropX":' Integer(this.PendingScreenshotCropX) ','
      . '"discordScreenshotCropY":' Integer(this.PendingScreenshotCropY) ','
      . '"discordScreenshotCropW":' Integer(this.PendingScreenshotCropW) ','
      . '"discordScreenshotCropH":' Integer(this.PendingScreenshotCropH) ','
      . '"discordScreenshotCropSummary":"' this.JsonEscape(this.GetPendingScreenshotCropSummary()) '",'
      . '"loopDelay":' this.GetLoopDelayForState() ','
      . '"loopSpeed":"' this.JsonEscape(this.GetLoopSpeedForState()) '",'
      . '"statusDetail":"' this.JsonEscape(this.GetStatusDetail(status, message)) '"'
      . "}"
    this.ExecScript("if (window.MacrobloXApplyState) window.MacrobloXApplyState(" stateJson ");")
  }

  GetStatusDetail(status, message := "") {
    if (message != "")
      return message
    if (status == "Recording")
      return "Recording input events"
    if (status == "Playing")
      return "Playback process running"
    if (status == "Looping")
      return "Loop playback active"
    if (status == "Disabled")
      return "Hotkeys disabled"
    if (this.State.EditorDirty)
      return "Macro editor has unsaved changes"
    return "Ready"
  }

  GetLoopDelayForState() {
    value := Trim(this.GetElementValue("loopDelay"))
    if (value != "" && RegExMatch(value, "^\d+$"))
      return Integer(value)
    try return this.MacroFiles.GetCurrentLoopDelay()
    catch
      return 2000
  }

  GetLoopSpeedForState() {
    value := this.GetElementValue("loopSpeed")
    if (value == "2x" || value == "5x" || value == "10x")
      return value
    return "1x"
  }

  GetRobloxStatusText() {
    if (this.AttachedToRoblox)
      return "Roblox overlaying the dashboard workspace"
    if (this.Roblox.IsAvailable())
      return "Roblox detected - overlaying..."
    return "Roblox not detected - standalone mode"
  }

  SyncRobloxWorkspace() {
    if (!IsObject(this.Gui) || !IsObject(this.Browser))
      return
    if (this.IsMinimized) {
      if (this.AttachedToRoblox) {
        this.Roblox.Restore()
        this.AttachedToRoblox := false
      }
      this.UpdateState()
      return
    }
    if (this.Roblox.IsAvailable())
      this.UseWindowMouseModeForRoblox()
    rect := this.GetWorkspaceScreenRect()
    if (rect == "hidden")
      return
    if (!IsObject(rect)) {
      this.Roblox.Restore()
      this.AttachedToRoblox := false
      this.UpdateState()
      return
    }
    wasAttached := this.AttachedToRoblox
    this.AttachedToRoblox := this.Roblox.OverlayInRect(this.Gui.Hwnd, rect.X, rect.Y, rect.W, rect.H)
    if (this.AttachedToRoblox != wasAttached)
      this.UpdateState()
  }

  GetWorkspaceScreenRect() {
    try {
      doc := this.Browser.Document
      el := doc.getElementById("robloxWorkspace")
      if (!IsObject(el))
        return ""
      rect := el.getBoundingClientRect()
      if ((rect.right - rect.left) <= 1 || (rect.bottom - rect.top) <= 1)
        return "hidden"
      this.BrowserControl.GetPos(&browserX, &browserY)
      point := Buffer(8, 0)
      NumPut("Int", browserX + Round(rect.left), point, 0)
      NumPut("Int", browserY + Round(rect.top), point, 4)
      DllCall("ClientToScreen", "Ptr", this.Gui.Hwnd, "Ptr", point)
      return {
        X: NumGet(point, 0, "Int"),
        Y: NumGet(point, 4, "Int"),
        W: Max(320, Round(rect.right - rect.left)),
        H: Max(240, Round(rect.bottom - rect.top))
      }
    } catch as err {
      this.Logger.Warn("Web workspace bounds failed: " err.Message)
      return ""
    }
  }

  SaveSettingsFromGui() {
    this.Settings.AppTheme := this.GetElementChecked("themeToggle") ? "light" : "dark"
    this.Settings.MouseMode := this.GetElementValue("mouseMode")
    this.Settings.CheckUpdatesOnStartup := this.GetElementChecked("updateStartup") ? "true" : "false"
    this.Settings.DiscordEnabled := this.GetElementChecked("discordEnabled") ? "true" : "false"
    this.Settings.DiscordWebhookUrl := Trim(this.GetElementValue("discordWebhookUrl"))
    this.Settings.DiscordUserId := Trim(this.GetElementValue("discordUserId"))
    this.Settings.DiscordSendScreenshots := this.GetElementChecked("discordScreenshots") ? "true" : "false"
    this.Settings.DiscordScreenshotCropEnabled := this.GetElementValue("screenshotCropEnabled")
    this.Settings.DiscordScreenshotCropX := this.GetElementValue("screenshotCropX")
    this.Settings.DiscordScreenshotCropY := this.GetElementValue("screenshotCropY")
    this.Settings.DiscordScreenshotCropW := this.GetElementValue("screenshotCropW")
    this.Settings.DiscordScreenshotCropH := this.GetElementValue("screenshotCropH")
    this.Settings.RecordSleep := "true"
    this.Settings.Normalize()
    this.PendingScreenshotCropEnabled := this.Settings.DiscordScreenshotCropEnabled
    this.PendingScreenshotCropX := this.Settings.DiscordScreenshotCropX
    this.PendingScreenshotCropY := this.Settings.DiscordScreenshotCropY
    this.PendingScreenshotCropW := this.Settings.DiscordScreenshotCropW
    this.PendingScreenshotCropH := this.Settings.DiscordScreenshotCropH
    ConfigManager.Save(this.Settings)
    this.ExecScript("if (window.MacrobloXMarkSettingsSaved) window.MacrobloXMarkSettingsSaved();")
    this.UpdateState("Settings saved")
  }

  GetDiscordSettingsSnapshot() {
    url := Trim(this.GetElementValue("discordWebhookUrl"))
    return {
      DiscordEnabled: url != "" ? "true" : "false",
      DiscordWebhookUrl: url,
      DiscordUserId: Trim(this.GetElementValue("discordUserId")),
      DiscordSendScreenshots: this.GetElementChecked("discordScreenshots") ? "true" : "false",
      DiscordScreenshotCropEnabled: this.GetElementValue("screenshotCropEnabled"),
      DiscordScreenshotCropX: this.GetElementValue("screenshotCropX"),
      DiscordScreenshotCropY: this.GetElementValue("screenshotCropY"),
      DiscordScreenshotCropW: this.GetElementValue("screenshotCropW"),
      DiscordScreenshotCropH: this.GetElementValue("screenshotCropH")
    }
  }

  SetScreenshotCrop() {
    if (!IsObject(this.ScreenshotService)) {
      this.UpdateState("Screenshot crop unavailable")
      return
    }
    this.UpdateState("Select screenshot crop")
    rect := this.ScreenshotService.PickScreenCrop()
    if (!IsObject(rect)) {
      this.UpdateState("Screenshot crop cancelled")
      return
    }
    this.PendingScreenshotCropEnabled := "true"
    this.PendingScreenshotCropX := rect.X
    this.PendingScreenshotCropY := rect.Y
    this.PendingScreenshotCropW := rect.W
    this.PendingScreenshotCropH := rect.H
    this.PushPendingScreenshotCrop()
    this.UpdateState("Screenshot crop selected")
  }

  ClearScreenshotCrop() {
    this.PendingScreenshotCropEnabled := "false"
    this.PendingScreenshotCropX := 0
    this.PendingScreenshotCropY := 0
    this.PendingScreenshotCropW := 0
    this.PendingScreenshotCropH := 0
    this.PushPendingScreenshotCrop()
    this.UpdateState("Screenshot crop cleared")
  }

  PushPendingScreenshotCrop() {
    summary := this.GetPendingScreenshotCropSummary()
    script := "if (window.MacrobloXSetScreenshotCrop) window.MacrobloXSetScreenshotCrop({"
      . "enabled:" (this.PendingScreenshotCropEnabled == "true" ? "true" : "false") ","
      . "x:" Integer(this.PendingScreenshotCropX) ","
      . "y:" Integer(this.PendingScreenshotCropY) ","
      . "w:" Integer(this.PendingScreenshotCropW) ","
      . "h:" Integer(this.PendingScreenshotCropH) ","
      . 'summary:"' this.JsonEscape(summary) '"'
      . "});"
    this.ExecScript(script)
  }

  GetPendingScreenshotCropSummary() {
    if (this.PendingScreenshotCropEnabled != "true" || this.PendingScreenshotCropW < 16 || this.PendingScreenshotCropH < 16)
      return "Full current screen"
    return "Crop: " this.PendingScreenshotCropW "x" this.PendingScreenshotCropH
      . " at " this.PendingScreenshotCropX "," this.PendingScreenshotCropY
  }

  ShowAndFocusEditor() {
    this.ExecScript("var b=document.querySelector('.nav button[data-tab='dashboard']'); if (b) b.click(); var s=document.getElementById('dashboardShell'); if (s) s.className='dashboard-shell'; var t=document.getElementById('editorToggleButton'); if (t) t.innerText='Hide Editor'; var e=document.getElementById('macroGrid'); if (e) e.focus();")
    this.ReloadEditorFromFile(false)
    try this.Gui.Show()
  }

  CloseApplication() {
    this.Logger.Info("Application close requested by GUI window.")
    this.UnregisterClipboardHotkeys()
    SetTimer(this.BridgeHandler, 0)
    SetTimer(this.AttachHandler, 0)
    this.Roblox.Restore()
    this.Controller.ExitApplication()
  }

  UnregisterClipboardHotkeys() {
    try {
      HotIfWinActive("ahk_id " this.Gui.Hwnd)
      Hotkey("^c", this.CopyHandler, "Off")
      Hotkey("^x", this.CutHandler, "Off")
      Hotkey("^v", this.PasteHandler, "Off")
      Hotkey("^a", this.SelectAllHandler, "Off")
      HotIfWinActive()
    }
  }

  CopyFocusedInput(*) {
    if (!this.IsDocumentReady())
      return
    this.SetElementValue("clipboardPayload", "")
    this.ExecScript("if (window.MacrobloXCopyFocusedInput) window.MacrobloXCopyFocusedInput(false);")
    text := this.GetElementValue("clipboardPayload")
    if (text != "")
      A_Clipboard := text
  }

  CutFocusedInput(*) {
    if (!this.IsDocumentReady())
      return
    this.SetElementValue("clipboardPayload", "")
    this.ExecScript("if (window.MacrobloXCopyFocusedInput) window.MacrobloXCopyFocusedInput(true);")
    text := this.GetElementValue("clipboardPayload")
    if (text != "")
      A_Clipboard := text
  }

  PasteFocusedInput(*) {
    if (!this.IsDocumentReady())
      return
    this.ExecScript('if (window.MacrobloXPasteFocusedInput) window.MacrobloXPasteFocusedInput("' this.JsonEscape(A_Clipboard) '");')
  }

  SelectAllFocusedInput(*) {
    if (!this.IsDocumentReady())
      return
    this.ExecScript("var e=document.activeElement; if (e && (e.tagName=='INPUT' || e.tagName=='TEXTAREA') && e.select) e.select();")
  }

  InsertEditorText(text) {
    row := this.ParseActionLine(text)
    if (IsObject(row))
      this.ExecScript('if (window.MacrobloXInsertRow) window.MacrobloXInsertRow("' this.JsonEscape(row.Event) '","' this.JsonEscape(row.Key) '","' this.JsonEscape(row.X) '","' this.JsonEscape(row.Y) '");')
    this.MarkEditorDirty()
  }

  SetEditorText(text, loopDelay := 2000, loopSpeed := "1x") {
    payload := this.BuildEditorPayload(text, loopDelay, loopSpeed)
    this.ExecScript("if (window.MacrobloXSetEditor) window.MacrobloXSetEditor(" payload ");")
  }

  GetEditorText() {
    this.ExecScript("var e=document.getElementById('editorPayload'); if (e && window.MacrobloXSerializeEditor) e.value=window.MacrobloXSerializeEditor();")
    return this.GetElementValue("editorPayload")
  }

  JoinEditorText() {
    delayText := Trim(this.GetElementValue("loopDelay"))
    if (delayText == "" || !RegExMatch(delayText, "^\d+$"))
      delayText := "2000"
    speed := this.GetElementValue("loopSpeed")
    text := this.SerializeEditorPayload(this.GetEditorText())
    text := this.MacroFiles.SetLoopDelayInText(text, Integer(delayText))
    text := this.MacroFiles.SetLoopSpeedInText(text, speed)
    return text == "" ? this.MacroFiles.EmptyMacroTemplate() : RTrim(text, "`r`n") "`n"
  }

  BuildEditorPayload(text, loopDelay := 2000, loopSpeed := "1x") {
    rowsJson := ""
    this.HiddenBeforeRows := []
    this.HiddenAfterRows := []
    this.HiddenLineCount := 0
    sawAction := false
    normalized := RegExReplace(text, "\R", "`n")
    for _, line in StrSplit(normalized, "`n") {
      row := this.ParseActionLine(line)
      if (IsObject(row)) {
        rowsJson .= (rowsJson == "" ? "" : ",") "{"
          . '"event":"' this.JsonEscape(row.Event) '",'
          . '"key":"' this.JsonEscape(row.Key) '",'
          . '"x":"' this.JsonEscape(row.X) '",'
          . '"y":"' this.JsonEscape(row.Y) '"'
          . "}"
        sawAction := true
      } else if (line != "") {
        if (sawAction)
          this.HiddenAfterRows.Push(line)
        else
          this.HiddenBeforeRows.Push(line)
        this.HiddenLineCount += 1
      }
    }
    if (!sawAction && this.HiddenBeforeRows.Length == 0 && this.HiddenAfterRows.Length == 0)
      this.HiddenAfterRows.Push("ExitApp()"), this.HiddenLineCount := 1
    return "{"
      . '"rows":[' rowsJson "],"
      . '"loopDelay":' Integer(loopDelay) ","
      . '"loopSpeed":"' this.JsonEscape(loopSpeed) '",'
      . '"hiddenLineCount":' this.HiddenLineCount
      . "}"
  }

  ParseActionLine(line) {
    trimmed := Trim(line)
    if (trimmed == "" || SubStr(trimmed, 1, 1) == ";")
      return ""
    if (RegExMatch(trimmed, "i)^Sleep\(\s*(\d+)\s*\)\s*$", &match))
      return { Event: "Sleep", Key: "", X: match[1], Y: "" }
    if (RegExMatch(trimmed, 'i)^Send\s+"(?:\{Blind\})?(.+)"\s*$', &match)) {
      value := this.UnescapeAhkString(match[1])
      if (RegExMatch(value, "i)^\{(.+)\s+Down\}$", &keyMatch))
        return { Event: "KeyDown", Key: keyMatch[1], X: "", Y: "" }
      if (RegExMatch(value, "i)^\{(.+)\s+Up\}$", &keyMatch))
        return { Event: "KeyUp", Key: keyMatch[1], X: "", Y: "" }
      return { Event: "Send", Key: value, X: "", Y: "" }
    }
    if (RegExMatch(trimmed, 'i)^MouseClick\(\s*"([LRM])"\s*,\s*([^,\)]+)\s*,\s*([^,\)]+)(.*)\)\s*(?:;.*)?$', &match)) {
      suffix := match[4]
      button := StrUpper(match[1])
      event := "MouseClick"
      if (InStr(suffix, '"D"'))
        event := "MouseDown"
      else if (InStr(suffix, '"U"'))
        event := "MouseUp"
      return { Event: event, Key: button, X: Trim(match[2]), Y: Trim(match[3]) }
    }
    return ""
  }

  SerializeEditorPayload(payload) {
    output := ""
    for _, line in this.HiddenBeforeRows
      output .= line "`n"
    payload := Trim(payload, "`r`n")
    if (payload != "") {
      for _, encodedRow in StrSplit(payload, "`n") {
        fields := StrSplit(encodedRow, "`t")
        event := fields.Length >= 1 ? this.UrlDecode(fields[1]) : ""
        if (fields.Length >= 4) {
          key := this.UrlDecode(fields[2])
          x := this.UrlDecode(fields[3])
          y := this.UrlDecode(fields[4])
        } else {
          key := ""
          x := fields.Length >= 2 ? this.UrlDecode(fields[2]) : ""
          y := fields.Length >= 3 ? this.UrlDecode(fields[3]) : ""
        }
        line := this.SerializeEditorRow(event, key, x, y)
        if (line != "")
          output .= line "`n"
      }
    }
    for _, line in this.HiddenAfterRows
      output .= line "`n"
    if (!RegExMatch(output, "im)^\s*ExitApp\(\)?\s*$"))
      output .= "ExitApp()`n"
    return output
  }

  SerializeEditorRow(event, key, x, y) {
    event := Trim(event), key := Trim(key), x := Trim(x), y := Trim(y)
    if (RegExMatch(event, "i)^Mouse(Click|Down|Up)\s+([LRM])$", &legacy)) {
      event := "Mouse" legacy[1]
      key := legacy[2]
    }
    if (event == "Sleep")
      return "Sleep(" (RegExMatch(x, "^\d+$") ? x : "500") ")"
    if (event == "Send")
      return 'Send "' this.BuildSendPayload(key == "" ? x : key) '"'
    if (event == "KeyDown")
      return 'Send "{Blind}{' this.EscapeAhkString(key == "" ? "Shift" : key) ' Down}"'
    if (event == "KeyUp")
      return 'Send "{Blind}{' this.EscapeAhkString(key == "" ? "Shift" : key) ' Up}"'
    if (RegExMatch(event, "i)^Mouse(Click|Down|Up)$", &match)) {
      mode := match[1], button := StrUpper(key == "" ? "L" : key)
      if (button != "L" && button != "R" && button != "M")
        button := "L"
      x := x == "" ? "0" : x
      y := y == "" ? "0" : y
      if (mode == "Down")
        return 'MouseClick("' button '", ' x ', ' y ',,, "D")'
      if (mode == "Up")
        return 'MouseClick("' button '", ' x ', ' y ',,, "U")'
      return 'MouseClick("' button '", ' x ', ' y ')'
    }
    return ""
  }

  BuildSendPayload(value) {
    value := value == "" ? "{Enter}" : value
    if (InStr(value, "{Blind}") == 1)
      return this.EscapeAhkString(value)
    return "{Blind}" this.EscapeAhkString(value)
  }

  EscapeAhkString(value) {
    value := StrReplace(value, "``", "````")
    value := StrReplace(value, '"', '``"')
    return value
  }

  UnescapeAhkString(value) {
    value := StrReplace(value, '``"', '"')
    value := StrReplace(value, "````", "``")
    return value
  }

  UrlDecode(value) {
    value := StrReplace(value, "+", " ")
    while RegExMatch(value, "i)%([0-9a-f]{2})", &match)
      value := StrReplace(value, match[0], Chr("0x" match[1]))
    return value
  }

  GetElementValue(id) {
    try {
      el := this.Browser.Document.getElementById(id)
      return IsObject(el) ? el.value : ""
    } catch {
      return ""
    }
  }

  SetElementValue(id, value) {
    this.ExecScript('var e=document.getElementById("' this.JsonEscape(id) '"); if (e) e.value="' this.JsonEscape(value) '";')
  }

  GetElementChecked(id) {
    try {
      el := this.Browser.Document.getElementById(id)
      return IsObject(el) ? (el.checked ? true : false) : false
    } catch {
      return false
    }
  }

  ExecScript(script) {
    try this.Browser.Document.parentWindow.execScript(script, "JavaScript")
  }

  JsonEscape(value) {
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, '"', '\"')
    value := StrReplace(value, "`r", "\r")
    value := StrReplace(value, "`n", "\n")
    value := StrReplace(value, "`t", "\t")
    return value
  }

  EditorValue {
    get => this.JoinEditorText()
  }
}
