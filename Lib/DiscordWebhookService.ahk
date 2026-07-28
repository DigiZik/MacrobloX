class DiscordWebhookService {
  __New(settings, logger, screenshotService := "") {
    this.Settings := settings
    this.Logger := logger
    this.ScreenshotService := screenshotService
    this.LastError := ""
  }

  SendStatus(title, description := "", color := 3447003, includeScreenshot := false, settingsOverride := "", requireScreenshot := false) {
    this.LastError := ""
    settings := IsObject(settingsOverride) ? settingsOverride : this.Settings
    if (!this.IsEnabled(settings))
      return false
    url := Trim(settings.DiscordWebhookUrl)
    if (!this.IsValidWebhookUrl(url)) {
      this.SetLastError("Discord webhook skipped because the configured URL is invalid: " this.MaskWebhookUrl(url))
      return false
    }

    screenshotPath := ""
    if (includeScreenshot && settings.DiscordSendScreenshots == "true" && IsObject(this.ScreenshotService)) {
      screenshotPath := this.ScreenshotService.CaptureWebhook(settings)
      if (screenshotPath == "") {
        this.SetLastError("Discord webhook screenshot requested, but capture was unavailable.")
        if (requireScreenshot)
          return false
      }
      if (screenshotPath != "" && !this.IsRenderableImage(screenshotPath)) {
        this.SetLastError("Discord webhook screenshot was captured, but not in a Discord-renderable image format.")
        try FileDelete(screenshotPath)
        if (requireScreenshot)
          return false
        screenshotPath := ""
      }
    }

    try {
      attachmentName := screenshotPath != "" ? this.GetAttachmentName(screenshotPath) : ""
      payload := this.BuildPayload(title, description, color, attachmentName, settings)
      result := screenshotPath != "" ? this.PostMultipart(url, payload, screenshotPath) : this.PostJson(url, payload)
      try {
        if (screenshotPath != "" && FileExist(screenshotPath))
          FileDelete(screenshotPath)
      }
      return result
    } catch as err {
      this.SetLastError("Discord webhook send failed for " this.MaskWebhookUrl(url) ": " err.Message)
      try {
        if (screenshotPath != "" && FileExist(screenshotPath))
          FileDelete(screenshotPath)
      }
      return false
    }
  }

  IsEnabled(settings := "") {
    settings := IsObject(settings) ? settings : this.Settings
    return settings.DiscordEnabled == "true" && Trim(settings.DiscordWebhookUrl) != ""
  }

  IsValidWebhookUrl(url) {
    return RegExMatch(url, "i)^https://(discord(?:app)?\.com|canary\.discord\.com|ptb\.discord\.com)/api/webhooks/\d+/[A-Za-z0-9._~\-]+(?:\?.*)?$")
  }

  MaskWebhookUrl(url) {
    if (!RegExMatch(url, "i)^(https://(?:discord(?:app)?\.com|canary\.discord\.com|ptb\.discord\.com)/api/webhooks/\d+/).+", &match))
      return "<invalid webhook URL>"
    return match[1] "..."
  }

  BuildPayload(title, description, color, attachmentName := "", settings := "") {
    settings := IsObject(settings) ? settings : this.Settings
    mention := Trim(settings.DiscordUserId) != "" ? "<@" Trim(settings.DiscordUserId) ">" : ""
    imageJson := attachmentName != "" ? ',"image":{"url":"attachment://' this.JsonEscape(attachmentName) '"}' : ""
    return "{"
      . '"content":"' this.JsonEscape(mention) '",'
      . '"embeds":[{'
      . '"title":"' this.JsonEscape(title) '",'
      . '"description":"' this.JsonEscape(description) '",'
      . '"color":' Integer(color) ','
      . '"timestamp":"' FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ssZ") '"'
      . imageJson
      . "}]"
      . "}"
  }

  PostJson(url, payload) {
    request := ComObject("WinHttp.WinHttpRequest.5.1")
    request.Open("POST", url, false)
    request.SetRequestHeader("User-Agent", "MacrobloX/" AppVersion.Number)
    request.SetRequestHeader("Content-Type", "application/json")
    request.Send(ComValue(8, payload))
    return this.IsSuccessResponse(request, "JSON webhook")
  }

  PostMultipart(url, payload, screenshotPath) {
    boundary := "----MacrobloXBoundary" A_TickCount
    bodyPath := A_Temp "\MacrobloX-DiscordBody-" A_TickCount ".bin"
    if (FileExist(bodyPath))
      FileDelete(bodyPath)

    body := FileOpen(bodyPath, "w", "UTF-8-RAW")
    body.Write("--" boundary "`r`n")
    body.Write('Content-Disposition: form-data; name="payload_json"' "`r`n")
    body.Write("Content-Type: application/json`r`n`r`n")
    body.Write(payload "`r`n")
    body.Write("--" boundary "`r`n")
    attachmentName := this.GetAttachmentName(screenshotPath)
    body.Write('Content-Disposition: form-data; name="files[0]"; filename="' attachmentName '"' "`r`n")
    body.Write("Content-Type: " this.GetContentType(screenshotPath) "`r`n`r`n")
    screenshot := FileOpen(screenshotPath, "r")
    data := Buffer(screenshot.Length, 0)
    screenshot.RawRead(data, screenshot.Length)
    screenshot.Close()
    body.RawWrite(data, data.Size)
    body.Write("`r`n--" boundary "--`r`n")
    body.Close()

    request := ComObject("WinHttp.WinHttpRequest.5.1")
    request.Open("POST", url, false)
    request.SetRequestHeader("User-Agent", "MacrobloX/" AppVersion.Number)
    request.SetRequestHeader("Content-Type", "multipart/form-data; boundary=" boundary)
    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.LoadFromFile(bodyPath)
    request.Send(stream.Read())
    stream.Close()
    try FileDelete(bodyPath)
    return this.IsSuccessResponse(request, "multipart webhook")
  }

  IsSuccessResponse(request, label) {
    status := request.Status
    if (status >= 200 && status < 300)
      return true
    response := ""
    try response := Trim(request.ResponseText)
    if (StrLen(response) > 180)
      response := SubStr(response, 1, 180) "..."
    this.SetLastError("Discord " label " failed with HTTP " status (response != "" ? ": " response : "."))
    return false
  }

  SetLastError(message) {
    this.LastError := message
    this.Logger.Warn(message)
  }

  GetAttachmentName(path) {
    SplitPath(path, &name)
    return name != "" ? name : "screenshot.jpg"
  }

  GetContentType(path) {
    SplitPath(path,,, &ext)
    ext := StrLower(ext)
    if (ext == "jpg" || ext == "jpeg")
      return "image/jpeg"
    if (ext == "png")
      return "image/png"
    return "image/bmp"
  }

  IsRenderableImage(path) {
    SplitPath(path,,, &ext)
    ext := StrLower(ext)
    return ext == "png" || ext == "jpg" || ext == "jpeg"
  }

  JsonEscape(value) {
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, '"', '\"')
    value := StrReplace(value, "`r", "\r")
    value := StrReplace(value, "`n", "\n")
    value := StrReplace(value, "`t", "\t")
    return value
  }
}
