#Requires AutoHotkey v2.0+
;#NoTrayIcon
#SingleInstance Force
#Include Lib\AppLogger.ahk
#Include Lib\AppVersion.ahk
#Include Lib\ConfigManager.ahk
#Include Lib\AppState.ahk
#Include Lib\MacroFileService.ahk
#Include Lib\NotificationService.ahk
#Include Lib\MacroRecorderEngine.ahk
#Include Lib\PlaybackController.ahk
#Include Lib\RobloxWindowService.ahk
#Include Lib\ScreenshotService.ahk
#Include Lib\DiscordWebhookService.ahk
#Include Lib\UpdateService.ahk
#Include Lib\AppGui.ahk
#Include Lib\WebViewAppGui.ahk
#Include Lib\MacroController.ahk

Main()

Main() {
  Persistent()
  Thread("NoTimers")
  CoordMode("ToolTip")
  SetTitleMatchMode(2)
  DetectHiddenWindows(true)
  DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")  ; Fix mouse coords on scaled monitors (>100%).

  settings := ConfigManager.Load(A_ScriptDir, A_Args)
  logger := AppLogger(A_ScriptDir "\MacroRecorder.log")
  state := AppState()
  macroFiles := MacroFileService(settings, logger)
  notifier := NotificationService()
  roblox := RobloxWindowService(logger)
  screenshot := ScreenshotService(roblox, logger)
  discord := DiscordWebhookService(settings, logger, screenshot)
  updater := UpdateService(settings, logger, A_ScriptDir)
  recorder := MacroRecorderEngine(settings, state, macroFiles, logger)
  playback := PlaybackController(settings, state, macroFiles, logger)
  guiApp := WebViewAppGui(settings, state, macroFiles, logger, roblox, screenshot)
  controller := MacroController(settings, state, recorder, playback, guiApp, macroFiles, notifier, logger, updater, discord)

  guiApp.SetController(controller)
  controller.RegisterHotkeys()
  guiApp.Build()
  controller.ScheduleStartupUpdateCheck()
}
