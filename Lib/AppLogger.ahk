class AppLogger {
  __New(logPath) {
    this.LogPath := logPath
  }

  Info(message) {
    this.Write("INFO", message)
  }

  Warn(message) {
    this.Write("WARN", message)
  }

  Error(message, err := "") {
    detail := message
    if (err != "")
      detail .= " | " this.FormatError(err)
    this.Write("ERROR", detail)
  }

  ShowError(title, message, err := "") {
    this.Error(message, err)
    detail := message
    if (err != "")
      detail .= "`n`n" this.FormatError(err)
    MsgBox(detail, title, 4096)
  }

  Write(level, message) {
    try {
      line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" level "] " message "`n"
      FileAppend(line, this.LogPath, "UTF-8")
    }
  }

  FormatError(err) {
    if (!IsObject(err))
      return err
    return err.Message
  }
}
