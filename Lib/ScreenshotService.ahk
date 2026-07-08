class ScreenshotService {
  __New(roblox, logger) {
    this.Roblox := roblox
    this.Logger := logger
  }

  CaptureRoblox(path := "") {
    hwnd := this.Roblox.FindWindow()
    if (!hwnd)
      return ""
    if (path == "")
      path := A_Temp "\MacrobloX-Roblox-" A_TickCount ".png"
    try {
      capturePath := this.CaptureWindowToBmp(hwnd, path)
      if (capturePath != "")
        return capturePath
    } catch as err {
      this.Logger.Warn("Roblox screenshot capture failed: " err.Message)
    }
    return ""
  }

  CaptureWebhook(settings, path := "") {
    if (IsObject(settings) && this.HasConfiguredCrop(settings))
      return this.CaptureScreenRect(settings.DiscordScreenshotCropX, settings.DiscordScreenshotCropY, settings.DiscordScreenshotCropW, settings.DiscordScreenshotCropH, path)
    if (this.Roblox.IsAvailable()) {
      robloxPath := this.CaptureRoblox(path)
      if (robloxPath != "")
        return robloxPath
    }
    rect := this.GetCurrentMonitorRect()
    return this.CaptureScreenRect(rect.X, rect.Y, rect.W, rect.H, path)
  }

  HasConfiguredCrop(settings) {
    try {
      return settings.DiscordScreenshotCropEnabled == "true"
        && Integer(settings.DiscordScreenshotCropW) >= 16
        && Integer(settings.DiscordScreenshotCropH) >= 16
    } catch {
      return false
    }
  }

  PickScreenCrop() {
    rect := this.GetCurrentMonitorRect()
    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow", "MacrobloX screenshot crop")
    overlay.BackColor := "000000"
    overlay.MarginX := 0
    overlay.MarginY := 0
    tip := overlay.Add("Text", "x16 y16 w520 h28 cFFFFFF BackgroundTrans", "Drag the screenshot area. Press Esc to cancel.")
    tip.SetFont("s12 bold")
    selection := overlay.Add("Progress", "x0 y0 w1 h1 c2F7DF6 BackgroundFFFFFF Hidden")
    result := ""
    CoordMode("Mouse", "Screen")
    try {
      overlay.Show("x" rect.X " y" rect.Y " w" rect.W " h" rect.H " NoActivate")
      WinSetTransparent(92, "ahk_id " overlay.Hwnd)
      KeyWait("LButton")
      while !GetKeyState("LButton", "P") {
        if (GetKeyState("Escape", "P"))
          return ""
        Sleep(20)
      }
      MouseGetPos(&startX, &startY)
      while GetKeyState("LButton", "P") {
        if (GetKeyState("Escape", "P"))
          return ""
        MouseGetPos(&currentX, &currentY)
        x := Min(startX, currentX)
        y := Min(startY, currentY)
        w := Abs(currentX - startX)
        h := Abs(currentY - startY)
        selection.Move(x - rect.X, y - rect.Y, Max(1, w), Max(1, h))
        selection.Visible := true
        Sleep(16)
      }
      MouseGetPos(&endX, &endY)
      x := Max(rect.X, Min(startX, endX))
      y := Max(rect.Y, Min(startY, endY))
      right := Min(rect.X + rect.W, Max(startX, endX))
      bottom := Min(rect.Y + rect.H, Max(startY, endY))
      w := right - x
      h := bottom - y
      if (w < 16 || h < 16)
        return ""
      result := { X: x, Y: y, W: w, H: h }
    } catch as err {
      this.Logger.Warn("Screenshot crop picker failed: " err.Message)
    } finally {
      try overlay.Destroy()
    }
    return result
  }

  CaptureScreenRect(x, y, width, height, path := "") {
    if (width <= 0 || height <= 0)
      return ""
    if (path == "")
      path := A_Temp "\MacrobloX-Screen-" A_TickCount ".png"
    try {
      capturePath := this.CaptureRectToBmp(x, y, width, height, path)
      if (capturePath != "") {
        this.Logger.Info("Screenshot captured to " capturePath " (" FileGetSize(capturePath) " bytes).")
        return capturePath
      }
    } catch as err {
      this.Logger.Warn("Screen screenshot capture failed: " err.Message)
    }
    return ""
  }

  CaptureRectToBmp(x, y, width, height, path) {
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    if (!hdcScreen)
      return ""
    hdcMem := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbm := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
    oldObj := DllCall("gdi32\SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
    try {
      if (!DllCall("gdi32\BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020, "Int")) {
        this.Logger.Warn("Screen BitBlt capture failed.")
        return ""
      }
      return this.SaveImage(hdcMem, hbm, width, height, path)
    } finally {
      if (oldObj)
        DllCall("gdi32\SelectObject", "Ptr", hdcMem, "Ptr", oldObj, "Ptr")
      if (hbm)
        DllCall("gdi32\DeleteObject", "Ptr", hbm)
      if (hdcMem)
        DllCall("gdi32\DeleteDC", "Ptr", hdcMem)
      DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    }
  }

  GetCurrentMonitorRect() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    point := Buffer(8, 0)
    NumPut("Int", x, point, 0)
    NumPut("Int", y, point, 4)
    monitor := DllCall("MonitorFromPoint", "Int64", NumGet(point, 0, "Int64"), "UInt", 2, "Ptr")
    info := Buffer(40, 0)
    NumPut("UInt", 40, info, 0)
    if (monitor && DllCall("GetMonitorInfo", "Ptr", monitor, "Ptr", info, "Int")) {
      left := NumGet(info, 4, "Int")
      top := NumGet(info, 8, "Int")
      right := NumGet(info, 12, "Int")
      bottom := NumGet(info, 16, "Int")
      return { X: left, Y: top, W: right - left, H: bottom - top }
    }
    return { X: 0, Y: 0, W: A_ScreenWidth, H: A_ScreenHeight }
  }

  CaptureWindowToBmp(hwnd, path) {
    rect := Buffer(16, 0)
    if (!DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int"))
      return ""
    x := NumGet(rect, 0, "Int")
    y := NumGet(rect, 4, "Int")
    width := NumGet(rect, 8, "Int") - x
    height := NumGet(rect, 12, "Int") - y
    if (width <= 0 || height <= 0)
      return ""

    hdcWindow := DllCall("GetWindowDC", "Ptr", hwnd, "Ptr")
    if (!hdcWindow)
      return ""
    hdcMem := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdcWindow, "Ptr")
    hbm := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdcWindow, "Int", width, "Int", height, "Ptr")
    oldObj := DllCall("gdi32\SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
    try {
      if (!DllCall("gdi32\BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", hdcWindow, "Int", 0, "Int", 0, "UInt", 0x00CC0020, "Int")) {
        this.Logger.Warn("Window BitBlt capture failed.")
        return ""
      }
      return this.SaveImage(hdcMem, hbm, width, height, path)
    } finally {
      if (oldObj)
        DllCall("gdi32\SelectObject", "Ptr", hdcMem, "Ptr", oldObj, "Ptr")
      if (hbm)
        DllCall("gdi32\DeleteObject", "Ptr", hbm)
      if (hdcMem)
        DllCall("gdi32\DeleteDC", "Ptr", hdcMem)
      DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdcWindow)
    }
  }

  SaveImage(hdc, hbm, width, height, path) {
    SplitPath(path,,, &ext)
    ext := StrLower(ext)
    if (ext == "jpg" || ext == "jpeg" || ext == "png") {
      try {
        if (this.SaveHBitmapWithGdiPlus(hbm, path, ext))
          return path
      } catch as err {
        this.Logger.Warn("Compressed screenshot save failed: " err.Message)
      }
      bmpPath := RegExReplace(path, "\.[^\\.]+$", ".bmp")
      this.Logger.Warn("Compressed screenshot save failed; trying BMP fallback.")
      if (!this.SaveBitmap(hdc, hbm, width, height, bmpPath))
        return ""
      convertedPath := this.ConvertBitmapWithWia(bmpPath, path)
      if (convertedPath != "")
        return convertedPath
      return bmpPath
    }
    return this.SaveBitmap(hdc, hbm, width, height, path) ? path : ""
  }

  SaveHBitmapWithGdiPlus(hbm, path, ext) {
    token := 0
    input := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
    NumPut("UInt", 1, input, 0)
    status := DllCall("gdiplus\GdiplusStartup", "PtrP", &token, "Ptr", input, "Ptr", 0, "UInt")
    if (status != 0) {
      this.Logger.Warn("GDI+ startup failed with status " status ".")
      return false
    }
    bitmap := 0
    try {
      status := DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "PtrP", &bitmap, "UInt")
      if (status != 0) {
        this.Logger.Warn("GDI+ bitmap creation failed with status " status ".")
        return false
      }
      encoder := Buffer(16, 0)
      encoderId := (ext == "png")
        ? "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
        : "{557CF401-1A04-11D3-9A73-0000F81EF32E}"
      status := DllCall("ole32\CLSIDFromString", "WStr", encoderId, "Ptr", encoder, "Int")
      if (status != 0) {
        this.Logger.Warn("Screenshot encoder lookup failed with status " status ".")
        return false
      }
      if (FileExist(path))
        FileDelete(path)
      status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", path, "Ptr", encoder, "Ptr", 0, "UInt")
      if (status != 0)
        this.Logger.Warn("Compressed screenshot save failed with GDI+ status " status ".")
      return status == 0 && FileExist(path)
    } finally {
      if (bitmap)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
      if (token)
        DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
    }
  }

  ConvertBitmapWithWia(bmpPath, outputPath) {
    if (!FileExist(bmpPath))
      return ""
    try {
      if (FileExist(outputPath))
        FileDelete(outputPath)
      image := ComObject("WIA.ImageFile")
      image.LoadFile(bmpPath)
      process := ComObject("WIA.ImageProcess")
      process.Filters.Add(process.FilterInfos.Item("Convert").FilterID)
      process.Filters.Item(1).Properties.Item("FormatID").Value := "{B96B3CAF-0728-11D3-9D7B-0000F81EF32E}"
      converted := process.Apply(image)
      converted.SaveFile(outputPath)
      if (FileExist(outputPath) && FileGetSize(outputPath) > 0) {
        try FileDelete(bmpPath)
        this.Logger.Info("Screenshot converted to PNG for Discord with WIA.")
        return outputPath
      }
    } catch as err {
      this.Logger.Warn("WIA screenshot conversion failed: " err.Message)
    }
    return ""
  }

  SaveBitmap(hdc, hbm, width, height, path) {
    stride := width * 4
    imageSize := stride * height
    headerSize := 14 + 40
    pixels := Buffer(imageSize, 0)
    info := Buffer(40, 0)
    NumPut("UInt", 40, info, 0)
    NumPut("Int", width, info, 4)
    NumPut("Int", -height, info, 8)
    NumPut("UShort", 1, info, 12)
    NumPut("UShort", 32, info, 14)
    NumPut("UInt", 0, info, 16)
    NumPut("UInt", imageSize, info, 20)
    if (!DllCall("gdi32\GetDIBits", "Ptr", hdc, "Ptr", hbm, "UInt", 0, "UInt", height, "Ptr", pixels, "Ptr", info, "UInt", 0, "Int"))
      return false

    fileHeader := Buffer(14, 0)
    NumPut("UChar", 0x42, fileHeader, 0)
    NumPut("UChar", 0x4D, fileHeader, 1)
    NumPut("UInt", headerSize + imageSize, fileHeader, 2)
    NumPut("UInt", 0, fileHeader, 6)
    NumPut("UInt", headerSize, fileHeader, 10)

    if (FileExist(path))
      FileDelete(path)
    file := FileOpen(path, "w")
    file.RawWrite(fileHeader, fileHeader.Size)
    file.RawWrite(info, info.Size)
    file.RawWrite(pixels, pixels.Size)
    file.Close()
    return FileExist(path)
  }
}
