class AppGui {
  __New(settings, state, macroFiles, logger, roblox) {
    this.Settings := settings
    this.State := state
    this.MacroFiles := macroFiles
    this.Logger := logger
    this.Roblox := roblox
    this.Controller := ""
    this.Gui := ""
    this.EditorRows := []
    this.SidebarWidth := 188
    this.ContentGap := 18
    this.PageMargin := 16
    this.SaveSettingsHandler := ObjBindMethod(this, "SaveSettingsFromGui")
    this.NotifyHandler := ObjBindMethod(this, "HandleNotify")
    this.AttachHandler := ObjBindMethod(this, "SyncRobloxWorkspace")
    this.AttachedToRoblox := false
    this.IsMinimized := false
    this.EditorCollapsed := false
    this.WorkspaceX := 222
    this.WorkspaceY := 178
    this.WorkspaceW := 736
    this.WorkspaceH := 472
    this.EditorX := 222
    this.EditorY := 178
    this.EditorW := 180
    this.EditorH := 472
    this.LastSavedText := "Loaded"
  }

  SetController(controller) {
    this.Controller := controller
  }

  Build() {
    this.Settings.Normalize()
    this.MacroFiles.EnsureEmptyMacroFile()

    this.Gui := Gui("+Resize +MinSize860x620", "MacrobloX - " AppVersion.Display())
    this.Gui.MarginX := 16
    this.Gui.MarginY := 14
    this.Gui.SetFont("s9", "Segoe UI")

    this.BrandText := this.Gui.Add("Text", "xm ym w188 h26", "MacrobloX " AppVersion.Display())
    this.BrandText.SetFont("s14 bold")
    this.RobloxText := this.Gui.Add("Text", "x+18 yp+2 w660 h22", "")
    this.RobloxText.SetFont("s9 bold")
    this.StatusText := this.Gui.Add("Text", "xm y+10 w188 h32 Center 0x200", "")
    this.StatusText.SetFont("s10 bold")

    this.RecordButton := this.Gui.Add("Button", "xm y+14 w188 h38", "Record")
    this.RecordButton.OnEvent("Click", (*) => this.Controller.RecordKeyAction())
    this.PlayButton := this.Gui.Add("Button", "xm y+8 w90 h34", "Play")
    this.PlayButton.OnEvent("Click", (*) => this.Controller.PlayKeyAction())
    this.LoopButton := this.Gui.Add("Button", "x+8 yp w90 h34", "Loop")
    this.LoopButton.OnEvent("Click", (*) => this.Controller.LoopKeyAction())
    this.ToggleButton := this.Gui.Add("Button", "xm y+8 w188 h34", "Disable hotkeys")
    this.ToggleButton.OnEvent("Click", (*) => this.Controller.ToggleScript())
    this.ResetButton := this.Gui.Add("Button", "xm y+8 w188 h34", "Reset")
    this.ResetButton.OnEvent("Click", (*) => this.Controller.ResetMacroFile())

    this.SettingsTitle := this.Gui.Add("Text", "xm y+10 w188 h22", "Session")
    this.SettingsTitle.SetFont("s10 bold")
    this.ThemeChoice := this.Gui.Add("DropDownList", "xm y+4 w188", ["light", "dark"])
    this.ThemeChoice.Choose(this.Settings.AppTheme == "dark" ? 2 : 1)
    this.ThemeChoice.OnEvent("Change", (*) => this.QueueSaveSettings())

    this.MouseModeChoice := this.Gui.Add("DropDownList", "xm y+8 w188", ["screen", "window", "relative"])
    this.MouseModeChoice.Choose(this.Settings.MouseMode == "window" ? 2 : this.Settings.MouseMode == "relative" ? 3 : 1)
    this.MouseModeChoice.OnEvent("Change", (*) => this.QueueSaveSettings())
    this.UpdateStartupCheck := this.Gui.Add("CheckBox", "xm y+8 w188 h24", "Check updates at startup")
    this.UpdateStartupCheck.Value := this.Settings.CheckUpdatesOnStartup == "true"
    this.UpdateStartupCheck.OnEvent("Click", (*) => this.QueueSaveSettings())
    this.UpdateButton := this.Gui.Add("Button", "xm y+8 w188 h30", "Check for updates")
    this.UpdateButton.OnEvent("Click", (*) => this.Controller.CheckForUpdates(true))

    this.LoopDelayLabel := this.Gui.Add("Text", "xm y+8 w188 h18", "Loop pause (ms)")
    this.LoopDelayInput := this.Gui.Add("Edit", "xm y+2 w188 h26 Number", this.MacroFiles.GetCurrentLoopDelay())
    this.LoopDelayInput.OnEvent("Change", (*) => this.HandleLoopDelayChanged())
    this.LoopSpeedLabel := this.Gui.Add("Text", "xm y+2 w188 h18", "Loop speed")
    this.LoopSpeedChoice := this.Gui.Add("DropDownList", "xm y+2 w188", ["1x", "2x", "5x", "10x"])
    this.LoopSpeedChoice.Choose(1)
    this.LoopSpeedChoice.OnEvent("Change", (*) => this.HandleLoopSpeed())

    editorX := 222
    this.EditorTitle := this.Gui.Add("Text", "x" editorX " y54 w320 h28", "Macro queue")
    this.EditorTitle.SetFont("s16 bold")
    this.EditorToggleButton := this.Gui.Add("Button", "x+12 yp-4 w104 h30", "Hide editor")
    this.EditorToggleButton.OnEvent("Click", (*) => this.ToggleEditorRail())
    this.PathText := this.Gui.Add("Text", "x" editorX " y+2 w720 h22", "")
    this.MacroFolderText := this.Gui.Add("Text", "x" editorX " y+0 w720 h20", "")
    this.SaveStateText := this.Gui.Add("Text", "x" editorX " y+0 w720 h20", "")

    this.FileActionLabel := this.Gui.Add("Text", "x" editorX " y+12 w44 h22 0x200", "Files")
    this.FileActionChoice := this.Gui.Add("DropDownList", "x+8 yp w138", ["", "New", "Open", "Save", "Save As", "Choose Folder"])
    this.FileActionChoice.Choose(1)
    this.FileActionChoice.OnEvent("Change", (*) => this.HandleFileAction())
    this.ExternalButton := this.Gui.Add("Button", "x+8 yp w104 h28", "Open External")
    this.ExternalButton.OnEvent("Click", (*) => this.Controller.OpenExternalEditor())
    this.SaveButton := this.Gui.Add("Button", "x" editorX " y+8 w74 h28", "Save")
    this.SaveButton.OnEvent("Click", (*) => this.Controller.SaveEditorToFile())
    this.ReloadButton := this.Gui.Add("Button", "x+8 yp w74 h28", "Reload")
    this.ReloadButton.OnEvent("Click", (*) => this.ReloadEditorFromFile(true))
    this.AddActionLabel := this.Gui.Add("Text", "x" editorX " y+8 w112 h18", "Add action")
    this.AddActionChoice := this.Gui.Add("DropDownList", "x" editorX " y+8 w112", ["", "Send", "Sleep", "MouseClick L", "MouseClick R"])
    this.AddActionChoice.Choose(1)
    this.AddActionChoice.OnEvent("Change", (*) => this.HandleAddAction())
    this.EditorControl := this.Gui.Add("ListView", "x" editorX " y+10 w736 h472 Grid -Multi", ["#", "Macro line"])
    this.EditorControl.SetFont("s9", "Consolas")
    this.EditorControl.OnEvent("DoubleClick", (*) => this.EditSelectedLine())
    this.EditorControl.OnEvent("ItemFocus", (*) => this.UpdateEditorSelectionState())
    this.EditorControl.OnEvent("ContextMenu", ObjBindMethod(this, "ShowEditorContextMenu"))
    this.RobloxPlaceholder := this.Gui.Add("Text", "x" editorX " y178 w736 h472 Center 0x200 Hidden", "Roblox not detected")
    this.RobloxPlaceholder.SetFont("s14 bold")
    this.RobloxHost := this.Gui.Add("Text", "x" editorX " y178 w736 h472 Border Hidden", "")
    this.ResizeEditorColumns(736)
    OnMessage(0x4E, this.NotifyHandler)

    this.Gui.OnEvent("Size", ObjBindMethod(this, "Resize"))
    this.Gui.OnEvent("Close", (*) => this.CloseApplication())

    this.ApplyTheme()
    this.ReloadEditorFromFile(false)
    this.UpdateState()
    this.Gui.Show("Maximize")
    try {
      this.Gui.GetClientPos(,, &clientW, &clientH)
      this.LayoutControls(clientW, clientH)
    } catch {
      this.LayoutControls(980, 720)
    }
    this.SyncRobloxWorkspace()
    SetTimer(this.AttachHandler, 5000)
  }

  Resize(thisGui, minMax, width, height) {
    if (minMax == -1) {
      this.IsMinimized := true
      if (this.AttachedToRoblox) {
        this.Roblox.Restore()
        this.AttachedToRoblox := false
      }
      this.UpdateRobloxStatusText()
      return
    }
    wasMinimized := this.IsMinimized
    this.IsMinimized := false
    this.LayoutControls(width, height)
    if (wasMinimized)
      this.RedrawGui(true)
    this.SyncRobloxWorkspace()
  }

  LayoutControls(width, height) {
    leftX := this.PageMargin
    topY := 14
    leftW := this.SidebarWidth
    editorX := leftX + leftW + this.ContentGap
    contentW := Max(width - editorX - this.PageMargin, 360)
    workspaceTop := 178
    editorTop := 270
    workspaceH := Max(height - workspaceTop - this.PageMargin, 220)
    editorH := Max(height - editorTop - this.PageMargin, 160)
    railGap := 10
    railW := Max(150, Floor(contentW / 8))
    if (contentW < 840)
      railW := Max(140, Floor(contentW / 6))
    robloxW := this.EditorCollapsed ? contentW : Max(contentW - railW - railGap, 260)
    railX := editorX + robloxW + railGap
    railVisible := !this.EditorCollapsed

    try {
      this.BrandText.Move(leftX, topY, leftW, 26)
      headerW := this.EditorCollapsed ? Max(contentW - 126, 160) : Max(robloxW - 8, 160)
      this.RobloxText.Move(editorX, topY + 2, headerW, 22)
      this.StatusText.Move(leftX, 50, leftW, 32)
      this.RecordButton.Move(leftX, 96, leftW, 38)
      this.PlayButton.Move(leftX, 142, 90, 34)
      this.LoopButton.Move(leftX + 98, 142, 90, 34)
      this.ToggleButton.Move(leftX, 184, leftW, 34)
      this.ResetButton.Move(leftX, 226, leftW, 34)
      this.SettingsTitle.Move(leftX, 286, leftW, 22)
      this.ThemeChoice.Move(leftX, 312, leftW)
      this.MouseModeChoice.Move(leftX, 349, leftW)
      this.UpdateStartupCheck.Move(leftX, 386, leftW, 24)
      this.UpdateButton.Move(leftX, 418, leftW, 30)
      this.LoopDelayLabel.Move(leftX, height + 80, leftW, 18)
      this.LoopDelayInput.Move(leftX, height + 100, leftW, 26)
      this.LoopSpeedLabel.Move(leftX, height + 130, leftW, 18)
      this.LoopSpeedChoice.Move(leftX, height + 150, leftW, 26)

      infoW := Max(robloxW, 260)
      this.EditorTitle.Move(editorX, 54, Min(320, Max(infoW - 12, 180)), 28)
      this.PathText.Move(editorX, 84, infoW, 22)
      this.MacroFolderText.Move(editorX, 106, infoW, 20)
      this.SaveStateText.Move(editorX, 126, infoW, 20)

      y := 144
      x := editorX
      this.FileActionLabel.Move(x, y, 44, 28)
      x += 52
      this.FileActionChoice.Move(x, y, 138, 28)
      x += 146
      this.ExternalButton.Move(x, y, Min(96, Max(contentW - (x - editorX), 80)), 28)

      this.WorkspaceX := editorX
      this.WorkspaceY := workspaceTop
      this.WorkspaceW := robloxW
      this.WorkspaceH := workspaceH
      this.EditorX := railX
      this.EditorY := editorTop
      this.EditorW := railW
      this.EditorH := editorH
      toggleX := this.EditorCollapsed ? editorX + contentW - 116 : this.EditorX
      toggleW := this.EditorCollapsed ? 116 : this.EditorW
      this.EditorToggleButton.Move(toggleX, topY, toggleW, 28)
      inputW := Max(72, Floor((this.EditorW - 8) * 0.48))
      speedW := Max(70, this.EditorW - inputW - 8)
      this.LoopDelayLabel.Move(this.EditorX, 112, inputW, 20)
      this.LoopSpeedLabel.Move(this.EditorX + inputW + 8, 112, speedW, 20)
      this.LoopDelayInput.Move(this.EditorX, 142, inputW, 26)
      this.LoopSpeedChoice.Move(this.EditorX + inputW + 8, 142, speedW, 26)
      halfW := Max(62, Floor((this.EditorW - 8) / 2))
      this.SaveButton.Move(this.EditorX, 178, halfW, 28)
      this.ReloadButton.Move(this.EditorX + halfW + 8, 178, Max(62, this.EditorW - halfW - 8), 28)
      this.AddActionLabel.Move(this.EditorX, 220, this.EditorW, 18)
      this.AddActionChoice.Move(this.EditorX, 240, this.EditorW, 28)
      this.EditorControl.Move(this.EditorX, this.EditorY, this.EditorW, this.EditorH)
      this.RobloxPlaceholder.Move(this.WorkspaceX, this.WorkspaceY, this.WorkspaceW, this.WorkspaceH)
      this.RobloxHost.Move(this.WorkspaceX, this.WorkspaceY, this.WorkspaceW, this.WorkspaceH)
      this.ResizeEditorColumns(railW)
      this.ApplyWorkspaceVisibility()
      if (this.AttachedToRoblox)
        this.AttachRobloxToWorkspace()
      this.RedrawGui()
    }
  }

  ApplyTheme() {
    if (!IsObject(this.Gui))
      return
    if (this.Settings.AppTheme == "dark") {
      this.Gui.BackColor := "121212"
      this.Gui.SetFont("cFFFFFF", "Segoe UI")
      for ctrl in [this.BrandText, this.RobloxText, this.StatusText, this.SettingsTitle, this.UpdateStartupCheck, this.EditorTitle, this.PathText, this.MacroFolderText, this.SaveStateText, this.FileActionLabel, this.LoopDelayLabel, this.LoopSpeedLabel, this.AddActionLabel, this.RobloxPlaceholder]
        try ctrl.SetFont("cFFFFFF", "Segoe UI")
      try this.StatusText.SetFont("c1DB954 bold", "Segoe UI")
      try this.PathText.SetFont("cB3B3B3", "Segoe UI")
      try this.MacroFolderText.SetFont("cB3B3B3", "Segoe UI")
      try this.SaveStateText.SetFont("cB3B3B3", "Segoe UI")
      try this.EditorControl.Opt("cFFFFFF Background181818")
    } else {
      this.Gui.BackColor := "F7F8FA"
      this.Gui.SetFont("c1F2328", "Segoe UI")
      for ctrl in [this.BrandText, this.RobloxText, this.StatusText, this.SettingsTitle, this.UpdateStartupCheck, this.EditorTitle, this.PathText, this.MacroFolderText, this.SaveStateText, this.FileActionLabel, this.LoopDelayLabel, this.LoopSpeedLabel, this.AddActionLabel, this.RobloxPlaceholder]
        try ctrl.SetFont("c1F2328", "Segoe UI")
      try this.EditorControl.Opt("c1F2328 BackgroundFFFFFF")
    }
    try this.EditorControl.SetFont("s9", "Consolas")
    this.UpdateState()
  }

  UpdateState(message := "") {
    if (!IsObject(this.StatusText))
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

    this.StatusText.Text := "Status: " status
    this.PathText.Text := "Macro file: " this.Settings.CurrentMacroFile
    this.MacroFolderText.Text := "Macro folder: " this.Settings.MacroDir
    this.SaveStateText.Text := this.State.EditorDirty ? "Save state: Unsaved changes" : "Save state: " this.LastSavedText
    this.RecordButton.Text := this.State.Recording ? "Stop recording  " this.Settings.RecordKey : "Record  " this.Settings.RecordKey
    this.PlayButton.Text := "Play  " this.Settings.PlayKey
    this.LoopButton.Text := this.State.Looping ? "Stop  " this.Settings.LoopKey : "Loop  " this.Settings.LoopKey
    this.ToggleButton.Text := this.State.ScriptEnabled ? "Disable hotkeys  " this.Settings.ToggleKey : "Enable hotkeys  " this.Settings.ToggleKey
    this.EditorToggleButton.Text := this.EditorCollapsed ? "Show editor" : "Hide editor"
    this.UpdateRobloxStatusText()
  }

  UpdateRobloxStatusText() {
    if (!IsObject(this.RobloxText))
      return
    if (this.AttachedToRoblox)
      this.RobloxText.Text := this.EditorCollapsed ? "Roblox overlaying full workspace" : "Roblox overlaying workspace beside editor"
    else if (this.Roblox.IsAvailable())
      this.RobloxText.Text := "Roblox detected - overlaying..."
    else
      this.RobloxText.Text := "Roblox not detected - standalone mode"
  }

  SyncRobloxWorkspace() {
    if (!IsObject(this.Gui))
      return
    if (this.IsMinimized) {
      if (this.AttachedToRoblox) {
        this.Roblox.Restore()
        this.AttachedToRoblox := false
      }
      this.UpdateRobloxStatusText()
      this.ApplyWorkspaceVisibility()
      return
    }
    if (this.Roblox.IsAvailable())
      this.UseWindowMouseModeForRoblox()
    wasAttached := this.AttachedToRoblox
    this.AttachedToRoblox := this.AttachRobloxToWorkspace()
    if (this.AttachedToRoblox != wasAttached)
      this.UpdateState()
    else
      this.UpdateRobloxStatusText()
    this.ApplyWorkspaceVisibility()
  }

  ToggleEditorRail() {
    this.EditorCollapsed := !this.EditorCollapsed
    try {
      this.Gui.GetClientPos(,, &clientW, &clientH)
      this.LayoutControls(clientW, clientH)
    } catch {
    }
    this.SyncRobloxWorkspace()
    this.UpdateState()
  }

  ApplyWorkspaceVisibility() {
    if (!IsObject(this.EditorControl))
      return
    editorVisible := !this.EditorCollapsed
    robloxVisible := !this.AttachedToRoblox
    for ctrl in [this.FileActionLabel, this.FileActionChoice, this.ExternalButton]
      try ctrl.Visible := true
    for ctrl in [this.LoopDelayLabel, this.LoopDelayInput, this.LoopSpeedLabel, this.LoopSpeedChoice, this.SaveButton, this.ReloadButton, this.AddActionLabel]
      try ctrl.Visible := editorVisible
    try this.EditorToggleButton.Visible := true
    try this.AddActionChoice.Visible := editorVisible
    try this.EditorControl.Visible := editorVisible
    try this.EditorTitle.Visible := true
    try this.SaveStateText.Visible := true
    try this.RobloxHost.Visible := !this.AttachedToRoblox
    try this.RobloxPlaceholder.Visible := robloxVisible
  }

  AttachRobloxToWorkspace() {
    rect := this.GetWorkspaceScreenRect()
    if (!IsObject(rect))
      return false
    return this.Roblox.OverlayInRect(this.Gui.Hwnd, rect.X, rect.Y, rect.W, rect.H)
  }

  RedrawGui(showWindow := false) {
    if (!IsObject(this.Gui))
      return
    if (showWindow)
      try this.Gui.Show()
    try DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
  }

  GetWorkspaceScreenRect() {
    if (!IsObject(this.Gui))
      return ""
    try {
      point := Buffer(8, 0)
      NumPut("Int", this.WorkspaceX, point, 0)
      NumPut("Int", this.WorkspaceY, point, 4)
      DllCall("ClientToScreen", "Ptr", this.Gui.Hwnd, "Ptr", point)
      return { X: NumGet(point, 0, "Int"), Y: NumGet(point, 4, "Int"), W: this.WorkspaceW, H: this.WorkspaceH }
    } catch as err {
      this.Logger.Warn("Workspace screen bounds failed: " err.Message)
      return ""
    }
  }

  CloseApplication() {
    SetTimer(this.AttachHandler, 0)
    this.Roblox.Restore()
    this.Controller.ExitApplication()
  }

  MarkEditorDirty() {
    if (this.State.EditorLoading)
      return
    this.State.EditorDirty := true
    this.UpdateState()
  }

  HandleFileAction() {
    action := this.FileActionChoice.Text
    try this.FileActionChoice.Choose(1)
    if (action == "")
      return
    if (action == "New")
      this.Controller.NewMacroFile()
    else if (action == "Open")
      this.Controller.OpenMacroFile()
    else if (action == "Save")
      this.Controller.SaveEditorToFile()
    else if (action == "Save As")
      this.Controller.SaveEditorAs()
    else if (action == "Choose Folder")
      this.Controller.ChooseMacroFolder()
  }

  HandleAddAction() {
    action := this.AddActionChoice.Text
    try this.AddActionChoice.Choose(1)
    if (action == "")
      return
    if (action == "Send")
      this.InsertEditableLine("Send `"{Blind}{Enter}`"")
    else if (action == "Sleep")
      this.InsertEditableLine("Sleep(500)")
    else if (action == "MouseClick L")
      this.InsertEditableLine(this.BuildMouseClickLine("L"))
    else if (action == "MouseClick R")
      this.InsertEditableLine(this.BuildMouseClickLine("R"))
  }

  HandleLoopSpeed() {
    if (this.State.EditorLoading)
      return
    speed := this.LoopSpeedChoice.Text
    if (speed == "")
      return
    this.SyncLoopSpeedEditorRow(speed)
    this.MarkEditorDirty()
  }

  HandleLoopDelayChanged() {
    if (this.State.EditorLoading)
      return
    delayText := Trim(this.LoopDelayInput.Value)
    if (delayText != "" && !RegExMatch(delayText, "^\d+$")) {
      this.UpdateState("Loop delay must be a number")
      return
    }
    delay := delayText == "" ? 0 : Integer(delayText)
    this.SyncLoopDelayEditorRow(delay)
    this.MarkEditorDirty()
  }

  BuildMouseClickLine(button) {
    try {
      CoordMode("Mouse", this.Settings.MouseMode == "window" ? "Window" : "Screen")
      MouseGetPos(&x, &y)
      return "MouseClick(`"" button "`", " x ", " y ")"
    } catch {
      return "MouseClick(`"" button "`", 0, 0)"
    }
  }

  UseWindowMouseModeForRoblox() {
    if (this.Settings.MouseMode == "window")
      return
    this.Settings.MouseMode := "window"
    try this.MouseModeChoice.Choose(2)
    this.Settings.Normalize()
    ConfigManager.Save(this.Settings)
  }

  ReloadEditorFromFile(promptIfDirty := true) {
    if (!IsObject(this.EditorControl))
      return
    if (promptIfDirty && this.State.EditorDirty) {
      result := MsgBox("Reload and discard unsaved editor changes?", "Reload macro", "YesNo Icon?")
      if (result != "Yes")
        return
    }
    this.MacroFiles.EnsureEmptyMacroFile()
    this.State.EditorLoading := true
    text := this.MacroFiles.ReadCurrent()
    this.LoadEditorRows(text)
    this.LoadLoopControls(text)
    this.State.EditorLoading := false
    this.State.EditorDirty := false
    this.MarkSaved("Loaded")
    this.UpdateState()
  }

  LoadEditorRows(text) {
    this.EditorRows := []
    this.EditorControl.Delete()
    normalized := RegExReplace(text, "\R", "`n")
    lines := StrSplit(normalized, "`n")
    if (lines.Length > 0 && lines[lines.Length] == "")
      lines.RemoveAt(lines.Length)
    for index, line in lines {
      row := this.MakeEditorRow(line)
      this.EditorRows.Push(row)
      this.EditorControl.Add("", index, row.Text)
    }
  }

  LoadLoopControls(text) {
    this.LoadLoopDelayControls(this.MacroFiles.GetLoopDelayFromText(text))
    this.LoadLoopSpeedControl(this.MacroFiles.GetLoopSpeedFromText(text))
  }

  LoadLoopDelayControls(delay) {
    try this.LoopDelayInput.Value := delay
  }

  LoadLoopSpeedControl(speed) {
    if (!IsObject(this.LoopSpeedChoice))
      return
    if (speed == "1x")
      this.LoopSpeedChoice.Choose(1)
    else if (speed == "2x")
      this.LoopSpeedChoice.Choose(2)
    else if (speed == "5x")
      this.LoopSpeedChoice.Choose(3)
    else if (speed == "10x")
      this.LoopSpeedChoice.Choose(4)
    else
      this.LoopSpeedChoice.Choose(1)
  }

  SyncLoopDelayEditorRow(delay) {
    text := "; MacroRecorder.LoopDelay=" Max(0, Integer(delay))
    for index, row in this.EditorRows {
      if (RegExMatch(Trim(row.Text), "i)^;\s*MacroRecorder\.LoopDelay\s*=")) {
        this.EditorRows[index] := this.MakeEditorRow(text)
        this.RefreshEditorRows(index)
        return
      }
    }
    insertAt := this.EditorRows.Length > 0 ? this.EditorRows.Length : 1
    if (this.EditorRows.Length > 0 && RegExMatch(Trim(this.EditorRows[this.EditorRows.Length].Text), "i)^ExitApp\(\)?"))
      insertAt := this.EditorRows.Length
    this.EditorRows.InsertAt(insertAt, this.MakeEditorRow(text))
    this.RefreshEditorRows(insertAt)
  }

  SyncLoopSpeedEditorRow(speed) {
    if (speed != "2x" && speed != "5x" && speed != "10x")
      speed := "1x"
    text := "; MacroRecorder.LoopSpeed=" speed
    for index, row in this.EditorRows {
      if (RegExMatch(Trim(row.Text), "i)^;\s*MacroRecorder\.LoopSpeed\s*=")) {
        this.EditorRows[index] := this.MakeEditorRow(text)
        this.RefreshEditorRows(index)
        return
      }
    }
    insertAt := this.EditorRows.Length > 0 ? this.EditorRows.Length : 1
    for index, row in this.EditorRows {
      if (RegExMatch(Trim(row.Text), "i)^;\s*MacroRecorder\.LoopDelay\s*=")) {
        insertAt := index + 1
        break
      }
    }
    if (this.EditorRows.Length > 0 && insertAt > this.EditorRows.Length && RegExMatch(Trim(this.EditorRows[this.EditorRows.Length].Text), "i)^ExitApp\(\)?"))
      insertAt := this.EditorRows.Length
    this.EditorRows.InsertAt(insertAt, this.MakeEditorRow(text))
    this.RefreshEditorRows(insertAt)
  }

  MakeEditorRow(line) {
    trimmed := Trim(line)
    kind := this.GetEditorLineKind(trimmed)
    return { Text: line, Kind: kind, Editable: this.IsEditorKindEditable(kind) }
  }

  GetEditorLineKind(trimmed) {
    if (trimmed == "")
      return "Blank"
    if (SubStr(trimmed, 1, 1) == ";")
      return "Comment"
    if (RegExMatch(trimmed, "i)^(#Requires|SendMode\(|SetKeyDelay\(|SetTitleMatchMode\(|CoordMode\(|ExitApp\(\)?)"))
      return "Locked"
    if (RegExMatch(trimmed, "i)^(WinWait\(|if\s|WinActivate\()"))
      return "Window"
    if (RegExMatch(trimmed, "i)^tt\s*:="))
      return "Target"
    if (RegExMatch(trimmed, "i)^Sleep\("))
      return "Pause"
    if (RegExMatch(trimmed, "i)^Send\s"))
      return "Key"
    if (RegExMatch(trimmed, "i)^Mouse"))
      return "Mouse"
    return "Command"
  }

  IsEditorKindEditable(kind) {
    return kind == "Target" || kind == "Pause" || kind == "Key" || kind == "Mouse" || kind == "Command"
  }

  UpdateEditorSelectionState() {
    selected := this.EditorControl.GetNext()
    if (!selected || selected > this.EditorRows.Length) {
      this.UpdateState()
      return
    }
    row := this.EditorRows[selected]
    this.UpdateState(row.Editable ? "Editable " row.Kind " line selected" : row.Kind " line is protected")
  }

  EditSelectedLine() {
    selected := this.EditorControl.GetNext()
    if (!selected || selected > this.EditorRows.Length) {
      this.UpdateState("Select a macro line first")
      return
    }
    row := this.EditorRows[selected]
    if (!row.Editable) {
      this.UpdateState(row.Kind " line is protected")
      return
    }
    result := InputBox("Edit macro line:", row.Kind " line", "w720 h140", row.Text)
    if (result.Result != "OK")
      return
    this.SetEditorRow(selected, result.Value)
  }

  InsertEditableLine(text) {
    selected := this.EditorControl.GetNext()
    insertAt := selected ? selected + 1 : this.EditorRows.Length
    if (insertAt < 1)
      insertAt := 1
    if (this.EditorRows.Length > 0 && insertAt > this.EditorRows.Length) {
      lastRow := this.EditorRows[this.EditorRows.Length]
      if (RegExMatch(Trim(lastRow.Text), "i)^ExitApp\(\)?"))
        insertAt := this.EditorRows.Length
    }
    this.EditorRows.InsertAt(insertAt, this.MakeEditorRow(text))
    this.RefreshEditorRows(insertAt)
    this.MarkEditorDirty()
  }

  DeleteSelectedLine() {
    selected := this.EditorControl.GetNext()
    if (!selected || selected > this.EditorRows.Length) {
      this.UpdateState("Select a macro line first")
      return
    }
    row := this.EditorRows[selected]
    if (!row.Editable) {
      this.UpdateState(row.Kind " line is protected")
      return
    }
    this.EditorRows.RemoveAt(selected)
    this.RefreshEditorRows(Min(selected, this.EditorRows.Length))
    this.MarkEditorDirty()
  }

  ShowEditorContextMenu(ctrl, item := 0, isRightClick := true, x := "", y := "") {
    selected := item ? item : this.EditorControl.GetNext()
    if (!selected || selected > this.EditorRows.Length)
      return
    this.EditorControl.Modify(selected, "Select Focus")
    row := this.EditorRows[selected]
    contextMenu := Menu()
    contextMenu.Add("Edit line", (*) => this.EditSelectedLine())
    contextMenu.Add("Delete line", (*) => this.DeleteSelectedLine())
    if (!row.Editable) {
      contextMenu.Disable("Edit line")
      contextMenu.Disable("Delete line")
    }
    try contextMenu.Show(x, y)
    catch
      contextMenu.Show()
  }

  SetEditorRow(index, text) {
    this.EditorRows[index] := this.MakeEditorRow(text)
    this.RefreshEditorRows(index)
    this.MarkEditorDirty()
  }

  RefreshEditorRows(focusIndex := 0) {
    this.EditorControl.Delete()
    for index, row in this.EditorRows
      this.EditorControl.Add("", index, row.Text)
    this.ResizeEditorColumns()
    if (focusIndex > 0 && focusIndex <= this.EditorRows.Length)
      this.EditorControl.Modify(focusIndex, "Select Focus Vis")
  }

  ResizeEditorColumns(width := 0) {
    if (width <= 0) {
      try this.EditorControl.GetPos(,, &width)
      catch
        width := 736
    }
    this.EditorControl.ModifyCol(1, 48)
    this.EditorControl.ModifyCol(2, Max(width - 54, 240))
  }

  JoinEditorRows() {
    delayText := Trim(this.LoopDelayInput.Value)
    if (delayText == "" || !RegExMatch(delayText, "^\d+$"))
      delayText := "2000"
    this.SyncLoopDelayEditorRow(Integer(delayText))
    this.SyncLoopSpeedEditorRow(this.LoopSpeedChoice.Text)
    text := ""
    for index, row in this.EditorRows
      text .= (index == 1 ? "" : "`n") row.Text
    return text == "" ? this.MacroFiles.EmptyMacroTemplate() : text "`n"
  }

  MarkSaved(prefix := "Saved") {
    this.LastSavedText := prefix " " FormatTime(, "HH:mm:ss")
    this.UpdateState()
  }

  HandleNotify(wParam, lParam, msg, hwnd) {
    if (!IsObject(this.EditorControl) || NumGet(lParam, 0, "UPtr") != this.EditorControl.Hwnd)
      return
    code := NumGet(lParam, A_PtrSize * 2, "Int")
    if (code != -12)
      return
    stage := NumGet(lParam, A_PtrSize * 3, "UInt")
    if (stage == 1)
      return 0x20
    if (stage != 0x10001)
      return
    rowIndex := NumGet(lParam, A_PtrSize * 3 + 32, "UPtr") + 1
    row := rowIndex <= this.EditorRows.Length ? this.EditorRows[rowIndex] : ""
    if (!IsObject(row))
      return
    isDark := this.Settings.AppTheme == "dark"
    textColor := isDark ? 0x00EAE8 : 0x28231F
    lockedColor := isDark ? 0x888888 : 0x7A7170
    oddBack := isDark ? 0x302C2B : 0xFFFFFF
    evenBack := isDark ? 0x383331 : 0xF8F6F4
    NumPut("UInt", row.Editable ? textColor : lockedColor, lParam, A_PtrSize * 3 + 56)
    NumPut("UInt", Mod(rowIndex, 2) ? oddBack : evenBack, lParam, A_PtrSize * 3 + 60)
    return 2
  }

  SaveSettingsFromGui() {
    if (!IsObject(this.ThemeChoice))
      return
    this.Settings.AppTheme := this.ThemeChoice.Text
    this.Settings.MouseMode := this.MouseModeChoice.Text
    this.Settings.CheckUpdatesOnStartup := this.UpdateStartupCheck.Value ? "true" : "false"
    this.Settings.RecordSleep := "true"
    this.Settings.Normalize()
    this.ApplyTheme()
    ConfigManager.Save(this.Settings)
    this.UpdateState("Settings saved")
  }

  QueueSaveSettings() {
    SetTimer(this.SaveSettingsHandler, -350)
  }

  ShowAndFocusEditor() {
    this.EditorCollapsed := false
    try {
      this.Gui.GetClientPos(,, &clientW, &clientH)
      this.LayoutControls(clientW, clientH)
    } catch {
    }
    this.SyncRobloxWorkspace()
    this.ReloadEditorFromFile(false)
    this.Gui.Show()
    this.EditorControl.Focus()
  }

  EditorValue {
    get => this.JoinEditorRows()
  }
}
