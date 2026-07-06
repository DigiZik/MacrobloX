class RobloxWindowService {
  __New(logger) {
    this.Logger := logger
    this.WindowTitle := "ahk_exe RobloxPlayerBeta.exe"
    this.OverlayHwnd := 0
    this.OriginalStyle := 0
    this.OriginalExStyle := 0
    this.OriginalBounds := ""
    this.OriginalMinMax := 0
    this.LastRect := ""
  }

  FindWindow() {
    previousDetectHidden := A_DetectHiddenWindows
    try {
      DetectHiddenWindows(true)
      return WinExist(this.WindowTitle)
    } catch as err {
      this.Logger.Warn("Roblox lookup failed: " err.Message)
      return 0
    } finally {
      DetectHiddenWindows(previousDetectHidden)
    }
  }

  IsAvailable() {
    return this.HasOverlayWindow() || this.FindWindow() != 0
  }

  GetBounds(hwnd := 0) {
    if (!hwnd)
      hwnd := this.FindWindow()
    if (!hwnd)
      return ""
    try {
      WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
      return { Hwnd: hwnd, X: x, Y: y, W: w, H: h }
    } catch as err {
      this.Logger.Warn("Roblox bounds lookup failed: " err.Message)
      return ""
    }
  }

  OverlayInRect(ownerHwnd, x, y, width, height) {
    hwnd := this.HasOverlayWindow() ? this.OverlayHwnd : this.FindWindow()
    if (!hwnd)
      return false

    try {
      if (this.OverlayHwnd != hwnd) {
        this.Restore()
        this.OverlayHwnd := hwnd
        this.OriginalStyle := this.GetWindowLong(hwnd, -16)
        this.OriginalExStyle := this.GetWindowLong(hwnd, -20)
        this.OriginalMinMax := WinGetMinMax("ahk_id " hwnd)
        this.OriginalBounds := this.GetBounds(hwnd)
        if (this.OriginalMinMax != 0) {
          WinRestore("ahk_id " hwnd)
          Sleep(80)
        }
        this.ApplyOverlayStyle(hwnd)
        this.LastRect := ""
      }

      this.MoveOverlay(ownerHwnd, x, y, width, height)
      return true
    } catch as err {
      this.Logger.Warn("Roblox overlay failed: " err.Message)
      return false
    }
  }

  MoveOverlay(ownerHwnd, x, y, width, height) {
    if (!this.HasOverlayWindow())
      return false
    width := Max(width, 320)
    height := Max(height, 240)
    nextRect := x "," y "," width "," height
    try {
      if (WinGetMinMax("ahk_id " this.OverlayHwnd) != 0) {
        WinRestore("ahk_id " this.OverlayHwnd)
        Sleep(30)
        this.LastRect := ""
      }
      if (this.LastRect == nextRect && this.WindowHasRect(this.OverlayHwnd, x, y, width, height))
        return true
      this.SetOverlayOwner(ownerHwnd)
      this.MoveTopLevel(this.OverlayHwnd, x, y, width, height)
      this.LastRect := nextRect
      return true
    } catch as err {
      this.Logger.Warn("Roblox overlay resize failed: " err.Message)
      return false
    }
  }

  Restore() {
    if (!this.HasOverlayWindow()) {
      this.ResetOverlayState()
      return
    }
    hwnd := this.OverlayHwnd
    try {
      this.ClearOverlayOwner(hwnd)
      if (this.OriginalStyle)
        this.SetWindowLong(hwnd, -16, this.OriginalStyle)
      if (this.OriginalExStyle)
        this.SetWindowLong(hwnd, -20, this.OriginalExStyle)
      this.RefreshFrame(hwnd)
      if (IsObject(this.OriginalBounds))
        WinMove(this.OriginalBounds.X, this.OriginalBounds.Y, this.OriginalBounds.W, this.OriginalBounds.H, "ahk_id " hwnd)
      WinShow("ahk_id " hwnd)
      if (this.OriginalMinMax == 1)
        WinMaximize("ahk_id " hwnd)
      else if (this.OriginalMinMax == -1)
        WinMinimize("ahk_id " hwnd)
    } catch as err {
      this.Logger.Warn("Roblox restore failed: " err.Message)
    }
    this.ResetOverlayState()
  }

  FocusRoblox() {
    hwnd := this.HasOverlayWindow() ? this.OverlayHwnd : this.FindWindow()
    if (!hwnd)
      return false
    try {
      WinActivate("ahk_id " hwnd)
      return true
    } catch as err {
      this.Logger.Warn("Roblox focus failed: " err.Message)
      return false
    }
  }

  ApplyOverlayStyle(hwnd) {
    static WS_CHILD := 0x40000000
    static WS_POPUP := 0x80000000
    static WS_CAPTION := 0x00C00000
    static WS_THICKFRAME := 0x00040000
    static WS_MINIMIZEBOX := 0x00020000
    static WS_MAXIMIZEBOX := 0x00010000
    static WS_SYSMENU := 0x00080000
    static WS_MAXIMIZE := 0x01000000
    static WS_MINIMIZE := 0x20000000
    static WS_VISIBLE := 0x10000000
    static WS_EX_APPWINDOW := 0x00040000
    static WS_EX_TOOLWINDOW := 0x00000080
    style := this.OriginalStyle
    style := (style | WS_POPUP | WS_VISIBLE) & ~(WS_CHILD | WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU | WS_MAXIMIZE | WS_MINIMIZE)
    exStyle := (this.OriginalExStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
    this.SetWindowLong(hwnd, -16, style)
    this.SetWindowLong(hwnd, -20, exStyle)
    this.RefreshFrame(hwnd)
    WinShow("ahk_id " hwnd)
  }

  SetOverlayOwner(ownerHwnd) {
    if (!ownerHwnd)
      return
    fn := A_PtrSize == 8 ? "SetWindowLongPtr" : "SetWindowLong"
    DllCall(fn, "Ptr", this.OverlayHwnd, "Int", -8, "Ptr", ownerHwnd, "Ptr")
  }

  ClearOverlayOwner(hwnd) {
    fn := A_PtrSize == 8 ? "SetWindowLongPtr" : "SetWindowLong"
    DllCall(fn, "Ptr", hwnd, "Int", -8, "Ptr", 0, "Ptr")
  }

  RefreshFrame(hwnd) {
    static SWP_NOMOVE := 0x0002
    static SWP_NOSIZE := 0x0001
    static SWP_NOZORDER := 0x0004
    static SWP_NOACTIVATE := 0x0010
    static SWP_FRAMECHANGED := 0x0020
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED)
  }

  MoveTopLevel(hwnd, x, y, width, height) {
    static HWND_TOP := 0
    static SWP_SHOWWINDOW := 0x0040
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", HWND_TOP, "Int", x, "Int", y, "Int", width, "Int", height, "UInt", SWP_SHOWWINDOW)
  }

  WindowHasRect(hwnd, x, y, width, height) {
    try {
      WinGetPos(&currentX, &currentY, &currentW, &currentH, "ahk_id " hwnd)
      return Abs(currentX - x) <= 2 && Abs(currentY - y) <= 2 && Abs(currentW - width) <= 2 && Abs(currentH - height) <= 2
    } catch {
      return false
    }
  }

  HasOverlayWindow() {
    return this.OverlayHwnd && DllCall("IsWindow", "Ptr", this.OverlayHwnd, "Int")
  }

  ResetOverlayState() {
    this.OverlayHwnd := 0
    this.OriginalStyle := 0
    this.OriginalExStyle := 0
    this.OriginalBounds := ""
    this.OriginalMinMax := 0
    this.LastRect := ""
  }

  GetWindowLong(hwnd, index) {
    fn := A_PtrSize == 8 ? "GetWindowLongPtr" : "GetWindowLong"
    return DllCall(fn, "Ptr", hwnd, "Int", index, "Ptr")
  }

  SetWindowLong(hwnd, index, value) {
    fn := A_PtrSize == 8 ? "SetWindowLongPtr" : "SetWindowLong"
    return DllCall(fn, "Ptr", hwnd, "Int", index, "Ptr", value, "Ptr")
  }
}
