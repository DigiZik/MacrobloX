class MacroRecorderEngine {
  __New(settings, state, macroFiles, logger) {
    this.Settings := settings
    this.State := state
    this.MacroFiles := macroFiles
    this.Logger := logger
    this.LogArr := []
    this.OldWindowId := ""
    this.RelativeX := 0
    this.RelativeY := 0
    this.LastLogTime := 0
    this.ActiveKeys := Map()
    this.LogKeyHandler := ObjBindMethod(this, "LogKey")
    this.LogWindowHandler := ObjBindMethod(this, "LogWindow")
  }

  Start() {
    if (this.State.Recording || this.State.Playing)
      return false
    this.Settings.Normalize()
    this.LogArr := []
    this.OldWindowId := ""
    this.LastLogTime := 0
    this.ActiveKeys := Map()
    this.State.Recording := true
    this.SetRecordingHotkeys(true)
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    this.RelativeX := x
    this.RelativeY := y
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

    for _, value in this.LogArr {
      line := Trim(value)
      if (line == "" || SubStr(line, 1, 1) == ";")
        continue
      script .= RegExReplace(value, "\s+;(?:screen|window|relative)$") "`n"
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
    this.Log("{" downName " Down}", true)
    downIndex := this.LogArr.Length
    t1 := A_TickCount
    Critical("Off")
    KeyWait(vksc)
    Critical()
    heldMs := A_TickCount - t1
    try this.ActiveKeys.Delete(vksc)
    if (heldMs <= 180 && downIndex > 0 && downIndex <= this.LogArr.Length) {
      this.LogArr[downIndex] := "Send `"{Blind}" sendText "`""
      return
    }
    this.Log("{" downName " Up}", true)
  }

  LogControlKey(key) {
    keyName := InStr(key, "Win") ? key : SubStr(key, 2)
    this.Log("{" keyName " Down}", true)
    Critical("Off")
    KeyWait(key)
    Critical()
    this.Log("{" keyName " Up}", true)
  }

  LogMouseKey(key) {
    button := SubStr(key, 1, 1)

    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y, &id)
    this.Log((this.Settings.MouseMode == "window" || this.Settings.MouseMode == "relative" ? ";" : "") "MouseClick(`"" button "`", " x ", " y ",,, `"D`") `;screen")

    CoordMode("Mouse", "Window")
    MouseGetPos(&windowX, &windowY, &id)
    this.Log((this.Settings.MouseMode != "window" ? ";" : "") "MouseClick(`"" button "`", " windowX ", " windowY ",,, `"D`") `;window")

    CoordMode("Mouse", "Screen")
    MouseGetPos(&tempRelativeX, &tempRelativeY, &id)
    this.Log((this.Settings.MouseMode != "relative" ? ";" : "") "MouseClick(`"" button "`", " (tempRelativeX - this.RelativeX) ", " (tempRelativeY - this.RelativeY) ",,, `"D`", `"R`") `;relative")
    this.RelativeX := tempRelativeX
    this.RelativeY := tempRelativeY

    CoordMode("Mouse", "Screen")
    MouseGetPos(&x1, &y1)
    t1 := A_TickCount
    Critical("Off")
    KeyWait(key)
    Critical()
    t2 := A_TickCount
    if (t2 - t1 <= 200)
      x2 := x1, y2 := y1
    else
      MouseGetPos(&x2, &y2)
    isQuickClick := (t2 - t1 <= 180) && (Abs(x2 - x1) + Abs(y2 - y1) < 5)

    i := this.LogArr.Length - 2, row := this.LogArr[i]
    hasMouseDown := InStr(row, ",,, `"D`")")
    if (hasMouseDown && isQuickClick)
      this.LogArr[i] := SubStr(row, 1, -16) ") `;screen", this.Log()
    else
      this.Log((this.Settings.MouseMode == "window" || this.Settings.MouseMode == "relative" ? ";" : "") "MouseClick(`"" button "`", " (x + x2 - x1) ", " (y + y2 - y1) ",,, `"U`") `;screen")

    i := this.LogArr.Length - 1, row := this.LogArr[i]
    hasMouseDown := InStr(row, ",,, `"D`")")
    if (hasMouseDown && isQuickClick)
      this.LogArr[i] := SubStr(row, 1, -16) ") `;window", this.Log()
    else
      this.Log((this.Settings.MouseMode != "window" ? ";" : "") "MouseClick(`"" button "`", " (windowX + x2 - x1) ", " (windowY + y2 - y1) ",,, `"U`") `;window")

    i := this.LogArr.Length, row := this.LogArr[i]
    hasRelativeMouseDown := InStr(row, ",,, `"D`", `"R`")")
    if (hasRelativeMouseDown && isQuickClick)
      this.LogArr[i] := SubStr(row, 1, -23) ",,,, `"R`") `;relative", this.Log()
    else
      this.Log((this.Settings.MouseMode != "relative" ? ";" : "") "MouseClick(`"" button "`", " (x2 - x1) ", " (y2 - y1) ",,, `"U`", `"R`") `;relative")
  }

  LogWindow() {
    static oldTitle := ""
    id := WinExist("A")
    if (!id)
      return
    title := WinGetTitle(id)
    className := WinGetClass(id)
    if (title = "" && className = "")
      return
    if (id = this.OldWindowId && title = oldTitle)
      return
    this.OldWindowId := id
    oldTitle := title
    title := SubStr(title, 1, 50)
    title .= className ? " ahk_class " className : ""
    title := RegExReplace(Trim(title), "[``%;]", "``$0")
    comment := this.Settings.MouseMode != "window" ? ";" : ""
    script := comment "tt := `"" title "`"`n" comment "WinWait(tt)`n" comment "if (!WinActive(tt))`n" comment "  WinActivate(tt)"
    i := this.LogArr.Length
    row := i = 0 ? "" : this.LogArr[i]
    if (InStr(row, "tt := ") = 1)
      this.LogArr[i] := script, this.Log()
    else
      this.Log(script)
  }

  LogSleep(ms) {
    if (ms <= 0)
      return
    this.LogArr.Push("Sleep(" Round(ms) ")")
    this.LastLogTime := A_TickCount
  }

  Log(text := "", keyboard := false, includeDelay := true) {
    t := A_TickCount
    if (text = "") {
      if (this.LastLogTime)
        this.LastLogTime := t
      return
    }
    trimmed := Trim(text)
    if (trimmed == "" || SubStr(trimmed, 1, 1) == ";") {
      this.LogArr.Push(keyboard ? "Send `"{Blind}" text "`"" : text)
      return
    }
    delay := this.LastLogTime && includeDelay ? t - this.LastLogTime : 0
    this.LastLogTime := t
    i := this.LogArr.Length
    row := i = 0 ? "" : this.LogArr[i]
    if (delay > 200)
      this.LogArr.Push("Sleep(" delay ")")
    this.LogArr.Push(keyboard ? "Send `"{Blind}" text "`"" : text)
  }
}
