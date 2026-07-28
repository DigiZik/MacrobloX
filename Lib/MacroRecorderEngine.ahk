class MacroRecorderEngine {
  __New(settings, state, macroFiles, logger) {
    this.Settings := settings
    this.State := state
    this.MacroFiles := macroFiles
    this.Logger := logger
    this.LogArr := []
    this.OldWindowId := ""
    this.OldWindowTitle := ""
    this.RelativeX := 0
    this.RelativeY := 0
    this.LastLogTime := 0
    this.ActiveKeys := Map()
    this.LogKeyHandler := ObjBindMethod(this, "LogKey")
    this.LogWheelHandler := ObjBindMethod(this, "LogWheel")
    this.LogWindowHandler := ObjBindMethod(this, "LogWindow")
  }

  Start() {
    if (this.State.Recording || this.State.Playing)
      return false
    this.Settings.Normalize()
    this.LogArr := []
    this.OldWindowId := ""
    this.OldWindowTitle := ""
    this.LastLogTime := 0
    this.ActiveKeys := Map()
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    this.RelativeX := x
    this.RelativeY := y
    this.State.Recording := true
    this.SetRecordingHotkeys(true)
    return true
  }

  Stop() {
    if (this.State.Recording) {
      if (this.LogArr.Length > 0)
        this.MacroFiles.WriteCurrent(this.BuildRecordedMacroScript())
      this.State.Recording := false
      this.LogArr := []
      this.ActiveKeys := Map()
      this.SetRecordingHotkeys(false)
    }
    Suspend(false)
    Pause(false)
    this.State.IsPaused := false
  }

  Reset() {
    this.SetRecordingHotkeys(false)
    this.State.Recording := false
    this.State.Playing := false
    this.LogArr := []
    this.ActiveKeys := Map()
    this.MacroFiles.WriteCurrent(this.MacroFiles.EmptyMacroTemplate())
    Suspend(false)
    Pause(false)
    this.State.IsPaused := false
  }

  BuildRecordedMacroScript() {
    script := "#Requires AutoHotkey v2.0`n"
    script .= "; Recorded by Macro Recorder`n"
    script .= "; MacroRecorder.LoopDelay=" this.MacroFiles.GetCurrentLoopDelay() "`n"
    script .= "; MacroRecorder.LoopSpeed=" this.MacroFiles.GetCurrentLoopSpeed() "`n"
    script .= "SendMode(`"Event`")`n"
    script .= "SetKeyDelay(30)`n"
    if (this.Settings.MouseMode == "window") {
      script .= "SetTitleMatchMode(2)`n"
      script .= "CoordMode(`"Mouse`", `"Window`")`n`n"
    } else {
      script .= "CoordMode(`"Mouse`", `"Screen`")`n`n"
    }

    for _, entry in this.LogArr {
      line := Trim(entry.Text)
      if (line == "" || SubStr(line, 1, 1) == ";")
        continue
      script .= entry.Text "`n"
    }
    script .= "`nExitApp()`n"
    return RegExReplace(script, "\R", "`n")
  }

  SetRecordingHotkeys(enabled := false) {
    mode := enabled ? "On" : "Off"
    Loop 254 {
      key := GetKeyName(vk := Format("vk{:X}", A_Index))
      if (!(key ~= "^(?i:|Control|Alt|Shift)$"))
        Hotkey("~*" vk, this.LogKeyHandler, mode)
    }
    for _, key in StrSplit("NumpadEnter|Home|End|PgUp|PgDn|Left|Right|Up|Down|Delete|Insert", "|") {
      sc := Format("sc{:03X}", GetKeySC(key))
      if (!(key ~= "^(?i:|Control|Alt|Shift)$"))
        Hotkey("~*" sc, this.LogKeyHandler, mode)
    }
    Hotkey("~*WheelUp", this.LogWheelHandler, mode)
    Hotkey("~*WheelDown", this.LogWheelHandler, mode)

    if (enabled) {
      SetTimer(this.LogWindowHandler)
      this.LogWindow()
    } else {
      SetTimer(this.LogWindowHandler, 0)
    }
  }

  LogKey(*) {
    Critical()
    key := GetKeyName(vksc := SubStr(A_ThisHotkey, 3))
    key := StrReplace(key, "Control", "Ctrl")
    suffix := SubStr(key, 2)
    if (suffix ~= "^(?i:Alt|Ctrl|Shift|Win)$")
      this.LogControlKey(key)
    else if (key ~= "^(?i:LButton|RButton|MButton)$")
      this.LogMouseKey(key)
    else {
      if (key = "NumpadLeft" || key = "NumpadRight") && !GetKeyState(key, "P")
        return
      this.LogStandardKey(key, vksc)
    }
  }

  LogStandardKey(key, vksc) {
    if (this.ActiveKeys.Has(vksc))
      return
    this.ActiveKeys[vksc] := true
    sendText := StrLen(key) > 1 ? "{" key "}" : key ~= "\w" ? key : "{" vksc "}"
    downName := StrLen(key) > 1 ? key : key ~= "\w" ? key : vksc
    downIndex := this.Log("{" downName " Down}", true, true, "key-down")
    t1 := A_TickCount
    Critical("Off")
    KeyWait(vksc)
    Critical()
    heldMs := A_TickCount - t1
    try this.ActiveKeys.Delete(vksc)
    if (heldMs <= 180 && downIndex > 0 && downIndex <= this.LogArr.Length) {
      this.LogArr[downIndex].Kind := "send"
      this.LogArr[downIndex].Text := "Send `"{Blind}" sendText "`""
      return
    }
    this.Log("{" downName " Up}", true, true, "key-up")
  }

  LogControlKey(key) {
    keyName := InStr(key, "Win") ? key : SubStr(key, 2)
    this.Log("{" keyName " Down}", true, true, "key-down")
    Critical("Off")
    KeyWait(key)
    Critical()
    this.Log("{" keyName " Up}", true, true, "key-up")
  }

  LogMouseKey(key) {
    button := SubStr(key, 1, 1)
    downPosition := this.CaptureMousePosition()
    relativeStartX := this.RelativeX
    relativeStartY := this.RelativeY
    downIndex := this.Log(this.BuildMouseClickText(button, downPosition, "D", relativeStartX, relativeStartY), false, true, "mouse-down")
    pressStarted := A_TickCount
    Critical("Off")
    KeyWait(key)
    Critical()
    upPosition := this.CaptureMousePosition()
    heldMs := A_TickCount - pressStarted
    isQuickClick := (heldMs <= 180) && (Abs(upPosition.ScreenX - downPosition.ScreenX) + Abs(upPosition.ScreenY - downPosition.ScreenY) < 5)
    if (isQuickClick) {
      this.LogArr[downIndex].Kind := "mouse-click"
      this.LogArr[downIndex].Text := this.BuildMouseClickText(button, downPosition, "", relativeStartX, relativeStartY, false)
      this.RelativeX := upPosition.ScreenX
      this.RelativeY := upPosition.ScreenY
      return
    }
    this.Log(this.BuildMouseClickText(button, upPosition, "U"), false, true, "mouse-up")
  }

  LogWheel(*) {
    Critical()
    button := InStr(A_ThisHotkey, "WheelDown") ? "WheelDown" : "WheelUp"
    this.Log(this.BuildMouseClickText(button, this.CaptureMousePosition()), false, true, "mouse-wheel")
  }

  CaptureMousePosition() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY)
    CoordMode("Mouse", "Window")
    MouseGetPos(&windowX, &windowY)
    CoordMode("Mouse", "Screen")
    return { ScreenX: screenX, ScreenY: screenY, WindowX: windowX, WindowY: windowY }
  }

  BuildMouseClickText(button, position, mode := "", relativeStartX := "", relativeStartY := "", updateRelative := true) {
    if (this.Settings.MouseMode == "window") {
      x := position.WindowX
      y := position.WindowY
      relative := false
    } else if (this.Settings.MouseMode == "relative") {
      baseX := relativeStartX == "" ? this.RelativeX : relativeStartX
      baseY := relativeStartY == "" ? this.RelativeY : relativeStartY
      x := position.ScreenX - baseX
      y := position.ScreenY - baseY
      relative := true
    } else {
      x := position.ScreenX
      y := position.ScreenY
      relative := false
    }
    if (updateRelative) {
      this.RelativeX := position.ScreenX
      this.RelativeY := position.ScreenY
    }
    if (relative)
      suffix := mode == "" ? ",,,, `"R`"" : ",,, `"" mode "`", `"R`""
    else
      suffix := mode == "" ? "" : ",,, `"" mode "`""
    return "MouseClick(`"" button "`", " x ", " y suffix ")"
  }

  LogWindow() {
    id := WinExist("A")
    if (!id)
      return
    title := WinGetTitle(id)
    className := WinGetClass(id)
    if (title = "" && className = "")
      return
    if (id = this.OldWindowId && title = this.OldWindowTitle)
      return
    this.OldWindowId := id
    this.OldWindowTitle := title
    title := SubStr(title, 1, 50)
    title .= className ? " ahk_class " className : ""
    title := RegExReplace(Trim(title), "[``%;]", "``$0")
    comment := this.Settings.MouseMode != "window" ? ";" : ""
    script := comment "tt := `"" title "`"`n" comment "WinWait(tt)`n" comment "if (!WinActive(tt))`n" comment "  WinActivate(tt)"
    i := this.LogArr.Length
    row := i = 0 ? "" : this.LogArr[i].Text
    if (InStr(row, "tt := ") = 1)
      this.LogArr[i].Text := script
    else
      this.Log(script, false, false, "window")
  }

  LogSleep(ms) {
    if (ms <= 0)
      return
    this.LogArr.Push({ Kind: "sleep", Text: "Sleep(" Round(ms) ")" })
    this.LastLogTime := A_TickCount
  }

  Log(text := "", keyboard := false, includeDelay := true, kind := "action") {
    t := A_TickCount
    if (text = "") {
      if (this.LastLogTime)
        this.LastLogTime := t
      return 0
    }
    trimmed := Trim(text)
    if (trimmed == "" || SubStr(trimmed, 1, 1) == ";") {
      this.LogArr.Push({ Kind: kind, Text: keyboard ? "Send `"{Blind}" text "`"" : text })
      return this.LogArr.Length
    }
    if (kind == "window") {
      this.LogArr.Push({ Kind: kind, Text: text })
      return this.LogArr.Length
    }
    delay := this.LastLogTime && includeDelay ? t - this.LastLogTime : 0
    this.LastLogTime := t
    if (delay > 200)
      this.LogArr.Push({ Kind: "sleep", Text: "Sleep(" delay ")" })
    this.LogArr.Push({ Kind: kind, Text: keyboard ? "Send `"{Blind}" text "`"" : text })
    return this.LogArr.Length
  }
}
