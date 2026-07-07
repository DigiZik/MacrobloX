class PlaybackController {
  __New(settings, state, macroFiles, logger) {
    this.Settings := settings
    this.State := state
    this.MacroFiles := macroFiles
    this.Logger := logger
    this.LoopPlaybackHandler := ObjBindMethod(this, "LoopPlaybackTick")
    this.PlaybackWatchHandler := ""
    this.PowerRequestActive := false
  }

  ReleaseModifiers() {
    Send("{Shift up}{Ctrl up}{Alt up}{LWin up}{RWin up}")
  }

  KeepSystemAwake() {
    if (this.PowerRequestActive)
      return
    ; Prevent Windows idle sleep/display power-off while playback automation is active.
    flags := 0x80000000 | 0x1 | 0x2
    result := DllCall("SetThreadExecutionState", "UInt", flags, "UInt")
    if (!result)
      this.Logger.Warn("Could not request Windows awake state during playback.")
    this.PowerRequestActive := true
  }

  AllowSystemSleep() {
    if (!this.PowerRequestActive)
      return
    DllCall("SetThreadExecutionState", "UInt", 0x80000000, "UInt")
    this.PowerRequestActive := false
  }

  RunMacroFile(waitForExit := false) {
    ahk := A_AhkPath
    if (!FileExist(ahk)) {
      this.Logger.ShowError("Playback failed", "Can't find AutoHotkey at " ahk ".")
      return false
    }

    try {
      this.MacroFiles.EnsureEmptyMacroFile()
      this.ReleaseModifiers()
      playbackFile := this.MacroFiles.WritePlaybackCopy()
      command := A_IsCompiled ? ahk " /script /restart `"" playbackFile "`"" : ahk " /restart `"" playbackFile "`""
      this.KeepSystemAwake()
      Run(command, , , &pid)
      if (waitForExit) {
        this.State.LoopPid := pid
        ProcessWaitClose(pid)
      } else {
        this.State.Playing := true
        this.State.LoopPid := pid
      }
      return true
    } catch as err {
      if (!this.State.Looping && !this.State.Playing)
        this.AllowSystemSleep()
      this.Logger.ShowError("Playback failed", "Could not run the current macro.", err)
      return false
    }
  }

  StopLoop() {
    if (!this.State.LoopPid && !this.State.Looping)
      return false
    this.State.Looping := false
    SetTimer(this.LoopPlaybackHandler, 0)
    if (IsObject(this.PlaybackWatchHandler))
      SetTimer(this.PlaybackWatchHandler, 0)
    try ProcessClose(this.State.LoopPid)
    this.State.LoopPid := 0
    this.State.Playing := false
    this.AllowSystemSleep()
    return true
  }

  StartLoop() {
    this.KeepSystemAwake()
    this.State.Looping := true
    SetTimer(this.LoopPlaybackHandler, -10)
  }

  LoopPlaybackTick() {
    if (!this.State.Looping)
      return
    if (!this.RunMacroFile(true)) {
      this.State.Looping := false
      this.State.LoopPid := 0
      this.AllowSystemSleep()
      return
    }
    this.State.LoopPid := 0
    if (this.State.Looping)
      SetTimer(this.LoopPlaybackHandler, -Max(1, this.MacroFiles.GetCurrentLoopDelay()))
  }

  WatchPlayback(onComplete) {
    this.PlaybackWatchHandler := ObjBindMethod(this, "PlaybackWatchTick", onComplete)
    SetTimer(this.PlaybackWatchHandler, 100)
  }

  PlaybackWatchTick(onComplete) {
    if (!this.State.Playing || !this.State.LoopPid) {
      SetTimer(this.PlaybackWatchHandler, 0)
      return
    }
    if (ProcessExist(this.State.LoopPid))
      return
    SetTimer(this.PlaybackWatchHandler, 0)
    this.State.Playing := false
    this.State.LoopPid := 0
    this.AllowSystemSleep()
    try onComplete.Call()
  }
}
