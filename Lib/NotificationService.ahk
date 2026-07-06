class NotificationService {
  __New() {
    this.Backup := ""
    this.Index := 0
    this.TipGui := Gui()
    this.Control := ""
    this.ChangeColorHandler := ObjBindMethod(this, "ChangeColor")
    this.HideHandler := ObjBindMethod(this, "Hide")
  }

  Show(message := "", pos := "y35", color := "Red|00FFFF") {
    if (this.Backup = color "," pos "," message)
      return
    this.Backup := color "," pos "," message
    SetTimer(this.ChangeColorHandler, 0)
    this.TipGui.Destroy()
    if (message = "")
      return

    this.TipGui := Gui("+LastFound +AlwaysOnTop +ToolWindow -Caption +E0x08000020", "ShowTip")
    WinSetTransColor("FFFFF0 150")
    this.TipGui.BackColor := "cFFFFF0"
    this.TipGui.MarginX := 10
    this.TipGui.MarginY := 5
    this.TipGui.SetFont("q3 s20 bold cRed")
    this.Control := this.TipGui.Add("Text", , message)
    this.TipGui.Show("NA " pos)
    SetTimer(this.ChangeColorHandler, 1000)
  }

  Timed(message, pos := "y35", color := "Green|00FF00", ms := 700) {
    this.Show(message, pos, color)
    SetTimer(this.HideHandler, -ms)
  }

  Hide() {
    this.Show()
  }

  ChangeColor() {
    if (!IsObject(this.Control))
      return
    colors := StrSplit(SubStr(this.Backup, 1, InStr(this.Backup, ",") - 1), "|")
    this.Index := Mod(Round(this.Index), colors.Length) + 1
    this.Control.SetFont("q3 c" colors[this.Index])
  }
}
