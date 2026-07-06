class PlaybackController {
  __New(settings, state, macroFiles, logger) {
    this.Settings := settings
    this.State := state
    this.MacroFiles := macroFiles
    this.Logger := logger
    this.LoopPlaybackHandler := ObjBindMethod(this, "LoopPlaybackTick")
    this.PlaybackWatchHandler := ""
  }

  ReleaseModifiers() {
    Send("{Shift up}{Ctrl up}{Alt up}{LWin up}{RWin up}")
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
    return true
  }

  StartLoop() {
    this.State.Looping := true
    SetTimer(this.LoopPlaybackHandler, -10)
  }

  LoopPlaybackTick() {
    if (!this.State.Looping)
      return
    if (!this.RunMacroFile(true)) {
      this.State.Looping := false
      this.State.LoopPid := 0
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
    try onComplete.Call()
  }
}
