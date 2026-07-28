class RobloxWindowService {
  __New(logger) {
    this.Logger := logger
    this.WindowTitle := "ahk_exe RobloxPlayerBeta.exe"
    this.OverlayHwnd := 0
    this.LastRect := ""
    this.LastOwnerHwnd := 0
  }

  FindWindow() {
    previousDetectHidden := A_DetectHiddenWindows
    try {
      DetectHiddenWindows(false)
      bestHwnd := 0
      bestArea := 0
      for hwnd in WinGetList(this.WindowTitle) {
        if (!this.IsUsableRobloxWindow(hwnd))
          continue
        bounds := this.GetBounds(hwnd)
        if (!IsObject(bounds))
          continue
        area := bounds.W * bounds.H
        if (area > bestArea) {
          bestHwnd := hwnd
          bestArea := area
        }
      }
      return bestHwnd
    } catch as err {
      this.Logger.Warn("Roblox lookup failed: " err.Message)
      return 0
    } finally {
      DetectHiddenWindows(previousDetectHidden)
    }
  }

  IsAvailable() {
    if (this.HasOverlayWindow())
      return true
    if (this.OverlayHwnd)
      this.ResetOverlayState()
    return this.FindWindow() != 0
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

  GetClientBounds(hwnd := 0) {
    if (!hwnd)
      hwnd := this.HasOverlayWindow() ? this.OverlayHwnd : this.FindWindow()
    if (!hwnd)
      return ""
    try {
      clientRect := Buffer(16, 0)
      if (!DllCall("GetClientRect", "Ptr", hwnd, "Ptr", clientRect, "Int"))
        return ""
      point := Buffer(8, 0)
      if (!DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", point, "Int"))
        return ""
      x := NumGet(point, 0, "Int")
      y := NumGet(point, 4, "Int")
      w := NumGet(clientRect, 8, "Int")
      h := NumGet(clientRect, 12, "Int")
      return { Hwnd: hwnd, X: x, Y: y, W: w, H: h }
    } catch as err {
      this.Logger.Warn("Roblox client bounds lookup failed: " err.Message)
      return ""
    }
  }

  EnsureRestoredWindowSize(width, height, hwnd := 0, x := "", y := "") {
    if (!hwnd)
      hwnd := this.HasOverlayWindow() ? this.OverlayHwnd : this.FindWindow()
    if (!hwnd || !this.IsWindow(hwnd))
      return ""

    width := Round(Max(width, 320))
    height := Round(Max(height, 240))
    try {
      if (WinGetMinMax("ahk_id " hwnd) != 0) {
        WinRestore("ahk_id " hwnd)
        Sleep(30)
        this.LastRect := ""
      }

      bounds := this.GetBounds(hwnd)
      if (!IsObject(bounds))
        return ""
      targetX := x == "" ? bounds.X : x
      targetY := y == "" ? bounds.Y : y
      target := this.ClampWindowRectToWorkArea(targetX, targetY, width, height)
      nextRect := target.X "," target.Y "," target.W "," target.H
      if (this.LastRect != nextRect || !this.WindowHasRect(hwnd, target.X, target.Y, target.W, target.H)) {
        WinMove(target.X, target.Y, target.W, target.H, "ahk_id " hwnd)
        this.LastRect := nextRect
      }
      return this.GetBounds(hwnd)
    } catch as err {
      this.Logger.Warn("Roblox restored window sizing failed: " err.Message)
      return ""
    }
  }

  EnsureRestoredClientRect(width, height, hwnd := 0, x := "", y := "") {
    if (!hwnd)
      hwnd := this.HasOverlayWindow() ? this.OverlayHwnd : this.FindWindow()
    if (!hwnd || !this.IsWindow(hwnd))
      return ""

    width := Round(Max(width, 320))
    height := Round(Max(height, 240))
    try {
      if (WinGetMinMax("ahk_id " hwnd) != 0) {
        WinRestore("ahk_id " hwnd)
        Sleep(30)
        this.LastRect := ""
      }

      clientBounds := this.GetClientBounds(hwnd)
      if (!IsObject(clientBounds))
        return ""
      targetX := x == "" ? clientBounds.X : x
      targetY := y == "" ? clientBounds.Y : y
      target := this.GetWindowTargetForClientRect(hwnd, targetX, targetY, width, height)
      target := this.ClampWindowRectToWorkArea(target.X, target.Y, target.W, target.H)
      nextRect := target.X "," target.Y "," target.W "," target.H
      if (this.LastRect != nextRect || !this.WindowHasRect(hwnd, target.X, target.Y, target.W, target.H)) {
        WinMove(target.X, target.Y, target.W, target.H, "ahk_id " hwnd)
        this.LastRect := nextRect
      }
      return this.GetClientBounds(hwnd)
    } catch as err {
      this.Logger.Warn("Roblox restored client sizing failed: " err.Message)
      return ""
    }
  }

  OverlayInRect(ownerHwnd, x, y, width, height) {
    if (!ownerHwnd || width < 320 || height < 240)
      return false

    hwnd := this.HasOverlayWindow() ? this.OverlayHwnd : this.FindWindow()
    if (!hwnd) {
      this.ResetOverlayState()
      return false
    }

    try {
      if (this.OverlayHwnd != hwnd)
        this.BeginOverlay(hwnd)
      return this.ApplyOverlayRect(ownerHwnd, { X: x, Y: y, W: width, H: height })
    } catch as err {
      this.Logger.Warn("Roblox positioning failed: " err.Message)
      this.ResetOverlayState()
      return false
    }
  }

  IsUsableRobloxWindow(hwnd) {
    if (!this.IsWindow(hwnd))
      return false
    if (!DllCall("IsWindowVisible", "Ptr", hwnd, "Int"))
      return false
    bounds := this.GetBounds(hwnd)
    return IsObject(bounds) && bounds.W >= 320 && bounds.H >= 240
  }

  BeginOverlay(hwnd) {
    if (!hwnd || !this.IsWindow(hwnd))
      return false
    this.OverlayHwnd := hwnd
    this.LastRect := ""
    this.LastOwnerHwnd := 0
    return true
  }

  ApplyOverlayRect(ownerHwnd, rect) {
    if (!IsObject(rect))
      return false
    return this.MoveOverlay(ownerHwnd, rect.X, rect.Y, rect.W, rect.H)
  }

  MoveOverlay(ownerHwnd, x, y, width, height) {
    if (!this.HasOverlayWindow() || !this.IsWindow(ownerHwnd))
      return false

    width := Max(width, 320)
    height := Max(height, 240)
    try {
      if (WinGetMinMax("ahk_id " this.OverlayHwnd) != 0) {
        WinRestore("ahk_id " this.OverlayHwnd)
        Sleep(30)
        this.LastRect := ""
      }
      target := this.GetWindowTargetForClientRect(this.OverlayHwnd, x, y, width, height)
      nextRect := target.X "," target.Y "," target.W "," target.H
      if (this.LastRect != nextRect || this.LastOwnerHwnd != ownerHwnd) {
        WinMove(target.X, target.Y, target.W, target.H, "ahk_id " this.OverlayHwnd)
        this.LastRect := nextRect
        this.LastOwnerHwnd := ownerHwnd
      }
      return this.PlaceBehindOwner(ownerHwnd)
    } catch as err {
      this.Logger.Warn("Roblox workspace positioning failed: " err.Message)
      return false
    }
  }

  GetWindowTargetForClientRect(hwnd, clientX, clientY, clientW, clientH) {
    metrics := this.GetWindowClientMetrics(hwnd)
    if (!IsObject(metrics))
      return { X: clientX, Y: clientY, W: clientW, H: clientH }
    return {
      X: clientX - metrics.Left,
      Y: clientY - metrics.Top,
      W: clientW + metrics.Left + metrics.Right,
      H: clientH + metrics.Top + metrics.Bottom
    }
  }

  GetWindowClientMetrics(hwnd) {
    try {
      windowRect := Buffer(16, 0)
      if (!DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", windowRect, "Int"))
        return ""

      clientRect := Buffer(16, 0)
      if (!DllCall("GetClientRect", "Ptr", hwnd, "Ptr", clientRect, "Int"))
        return ""

      point := Buffer(8, 0)
      if (!DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", point, "Int"))
        return ""

      windowX := NumGet(windowRect, 0, "Int")
      windowY := NumGet(windowRect, 4, "Int")
      windowW := NumGet(windowRect, 8, "Int") - windowX
      windowH := NumGet(windowRect, 12, "Int") - windowY
      clientW := NumGet(clientRect, 8, "Int")
      clientH := NumGet(clientRect, 12, "Int")
      clientScreenX := NumGet(point, 0, "Int")
      clientScreenY := NumGet(point, 4, "Int")

      left := Max(0, clientScreenX - windowX)
      top := Max(0, clientScreenY - windowY)
      right := Max(0, windowW - clientW - left)
      bottom := Max(0, windowH - clientH - top)
      return { Left: left, Top: top, Right: right, Bottom: bottom }
    } catch as err {
      this.Logger.Warn("Roblox client metrics failed: " err.Message)
      return ""
    }
  }

  ClampWindowRectToWorkArea(x, y, width, height) {
    workArea := this.GetWorkAreaForRect(x, y, width, height)
    if (!IsObject(workArea))
      return { X: x, Y: y, W: width, H: height }

    maxX := workArea.Right - width
    maxY := workArea.Bottom - height
    targetX := width >= workArea.Right - workArea.Left ? workArea.Left : Min(Max(x, workArea.Left), maxX)
    targetY := height >= workArea.Bottom - workArea.Top ? workArea.Top : Min(Max(y, workArea.Top), maxY)
    return { X: targetX, Y: targetY, W: width, H: height }
  }

  GetWorkAreaForRect(x, y, width, height) {
    try {
      centerX := x + (width // 2)
      centerY := y + (height // 2)
      monitorCount := MonitorGetCount()
      bestArea := ""
      bestDistance := ""
      Loop monitorCount {
        MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
        if (centerX >= left && centerX < right && centerY >= top && centerY < bottom)
          return { Left: left, Top: top, Right: right, Bottom: bottom }

        nearestX := Min(Max(centerX, left), right)
        nearestY := Min(Max(centerY, top), bottom)
        distance := ((centerX - nearestX) * (centerX - nearestX)) + ((centerY - nearestY) * (centerY - nearestY))
        if (bestDistance == "" || distance < bestDistance) {
          bestDistance := distance
          bestArea := { Left: left, Top: top, Right: right, Bottom: bottom }
        }
      }
      return bestArea
    } catch as err {
      this.Logger.Warn("Monitor work area lookup failed: " err.Message)
      return ""
    }
  }

  PlaceBehindOwner(ownerHwnd) {
    static SWP_NOMOVE := 0x0002
    static SWP_NOSIZE := 0x0001
    static SWP_NOACTIVATE := 0x0010
    static SWP_SHOWWINDOW := 0x0040
    DllCall("SetWindowPos", "Ptr", this.OverlayHwnd, "Ptr", ownerHwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW)
    return true
  }

  Restore() {
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

  WindowHasRect(hwnd, x, y, width, height) {
    try {
      WinGetPos(&currentX, &currentY, &currentW, &currentH, "ahk_id " hwnd)
      return Abs(currentX - x) <= 2 && Abs(currentY - y) <= 2 && Abs(currentW - width) <= 2 && Abs(currentH - height) <= 2
    } catch {
      return false
    }
  }

  HasOverlayWindow() {
    return this.OverlayHwnd && this.IsWindow(this.OverlayHwnd)
  }

  IsWindow(hwnd) {
    return hwnd && DllCall("IsWindow", "Ptr", hwnd, "Int")
  }

  ResetOverlayState() {
    this.OverlayHwnd := 0
    this.LastRect := ""
    this.LastOwnerHwnd := 0
  }
}
