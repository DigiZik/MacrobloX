class AppState {
  __New() {
    this.ScriptEnabled := true
    this.Recording := false
    this.Playing := false
    this.Looping := false
    this.EditorDirty := false
    this.EditorLoading := false
    this.LoopPid := 0
    this.IsPaused := false
  }
}
