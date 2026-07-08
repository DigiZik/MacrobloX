# MacrobloX

## About

An AHKv2 task that can macro a specific game.

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download the latest `MacrobloX-vX.Y.Z-source.zip` from [GitHub Releases](https://github.com/DigiZik/MacrobloX/releases/latest).
3. Extract the zip, keeping `MacroRecorder.ahk`, the `Lib/` folder, and the `Gui/` folder together.
4. Double-click `MacroRecorder.ahk`.

MacrobloX uses a local HTML/CSS application shell hosted by Windows' embedded browser control. A clean WebView2 host can replace that thin shell later without changing recorder/playback internals; the current package does not vendor GPL WebView helper code from other macros.

## Usage

Double-clicking `MacroRecorder.ahk` opens MacrobloX in a modern Roblox-focused control window. By default, macros are saved as `.txt` files in a `Macros` folder next to `MacroRecorder.ahk`, so the normal workflow is still just launching that one script.

The GUI opens maximized by default and uses a dark/light themed web shell with Dashboard and Settings views plus a top menu bar. The left panel owns navigation, transport controls, lightweight status/debug details, and current macro info. The Dashboard itself stays focused on the Roblox workspace and a structured macro editor rail that takes about one seventh of the workspace and can be hidden when you want Roblox wider.

The GUI is resizable and includes:

- Record/Stop, Play, Loop/Stop Loop, Reset, Open External, Enable/Disable, and an `Add action` dropdown for common macro events
- Toolbar file actions for New, Open, Save, Save As, and Macro Folder
- A status area showing Roblox detection, the current macro path, recording/looping/disabled state, and editor save state
- Light/dark appearance selection
- Beginner-friendly settings for mouse positions plus per-macro loop pause and loop speed controls on one compact editor row
- A `Check for updates` button and startup update checks that prompt before downloading from GitHub Releases
- A compact Dashboard macro editor rail with zebra-striped rows and editable `Event`, `Key`, `X`, and `Y` columns
- Optional Discord webhook notifications with status embeds and optional screenshots/crops

Recorded `.txt` macros are intentionally small. The file includes the selected mouse mode, the per-macro loop delay metadata, the recorded actions, and the minimal AutoHotkey setup needed to run them. Loop playback is handled by the recorder app, so saved macros do not need loop boilerplate.

MacrobloX checks GitHub Releases for updates on startup by default. When a newer stable release is available, it prompts before downloading `MacrobloX-vX.Y.Z-source.zip`, updates the app files, preserves `MacroRecorder.ini`, `Macros/`, and `MacroRecorder.log`, then restarts the recorder. You can disable startup checks from the Session area and still use `Check for updates` manually.

While one-shot playback or loop playback is running, the recorder asks Windows to keep the system and display awake. This helps long loop runs continue instead of being interrupted by idle sleep or display power-off behavior. The request is released when playback stops or finishes.

Settings are saved in `MacroRecorder.ini` next to `MacroRecorder.ahk` only when you click `Save Settings`. This includes the selected theme, recording options, Discord webhook options, default macro folder, and current macro file. Runtime errors are written to `MacroRecorder.log`. The Discord webhook URL is visible in Settings so it can be copied and pasted normally, but it is not written to the log.

Discord webhooks are optional. When enabled, MacrobloX can send status embeds for recording, playback, loop start/stop, reset, update installation, and manual test events. Screenshots are disabled by default. If screenshot sending is enabled, Settings shows lightweight crop controls: `Set crop` lets you drag a visible current-screen rectangle, and `Clear crop` returns to the full current-screen fallback. Screenshots are uploaded as Discord-renderable image attachments, preferring PNG and falling back through a one-shot local PNG conversion if direct encoding is unavailable. With Roblox running and no crop configured, MacrobloX keeps the Roblox-window screenshot behavior where available. Only enable screenshots for channels where visible gameplay or desktop content is safe to share.

The Reset button safely stops recording/playback/looping, releases held modifiers, resets mouse mode to `screen`, switches back to `Macros\DefaultMacro.txt`, recreates it as an empty valid AutoHotkey v2 script, and restarts the recorder.

Closing the main window exits the recorder and stops active recording, playback, and loop processes. Minimizing the window leaves the recorder running.

When Roblox is not detected, starting a recording, playback, or loop playback minimizes MacrobloX so standalone desktop automation has a clear workspace. Stopping recording, finishing playback, or stopping loop playback restores and activates the app. When Roblox is detected, Roblox remains an independent window positioned behind the dashboard workspace, while MacrobloX clips the hosted browser around a native transparent workspace gap so Roblox shows through without changing the app's native titlebar. In restore-down mode, MacrobloX treats the restored Roblox client area as the workspace size source: entering restored mode first normalizes the independent Roblox play area to 800x600 at the current dashboard workspace position, fixes the dashboard workspace element to that client size so Roblox fills the workspace without showing its own titlebar, follows later Roblox resizes, and lets dragging the MacrobloX titlebar move the workspace while Roblox follows after a short debounce. MacrobloX does not embed, own, or restyle the Roblox window, which avoids extra blank Roblox game-client thumbnails in the Windows taskbar.

### Hotkeys

- `F1` - Play recorded macro once
- `F2` - Start/Stop recording macro
- `F4` - Toggle enable/disable script
- `F6` - Play macro in a loop

## Project Layout

- `MacroRecorder.ahk` wires the app together with `#Include` statements, dependency construction, and hotkey setup.
- `Gui/` contains the local HTML, CSS, and JavaScript for the modern app shell.
- `Lib/WebViewAppGui.ahk` hosts the web shell, bridges it to the controller, and keeps the Roblox workspace as a native transparent gap instead of a top-level window region.
- `Lib/AppGui.ahk` keeps the previous native GUI implementation for reference/fallback.
- `Lib/MacroController.ahk` coordinates hotkeys, buttons, and app actions.
- `Lib/MacroRecorderEngine.ahk` records keyboard/mouse actions and builds macro output.
- `Lib/PlaybackController.ahk` runs macros and loop playback.
- `Lib/RobloxWindowService.ahk` detects the Roblox player window and positions it as an independent window behind the native GUI workspace gap.
- `Lib/ConfigManager.ahk` reads/writes `MacroRecorder.ini`.
- `Lib/MacroFileService.ahk` manages macro paths and file content.
- `Lib/DiscordWebhookService.ahk` sends optional Discord notifications.
- `Lib/ScreenshotService.ahk` captures the Roblox window or selected screen crop for optional webhook screenshots.
- `Lib/AppLogger.ahk` and `Lib/NotificationService.ahk` provide logging and transient status messages.

### Recording Modes
The script supports three mouse position modes (configurable in the GUI):
- `screen` - Absolute screen coordinates
- `window` - Window-relative coordinates, only for Roblox window
- `relative` - Relative to starting position

Recorded timing gaps are saved as `Sleep(...)` lines automatically, starting from the first real recorded action so startup focus checks do not create leading sleep rows. `Loop pause (ms)` controls the delay between repeated loop playback runs for the current `.txt` macro. The adjacent speed dropdown can quickly set common loop speeds: `1x`, `2x`, `5x`, or `10x`.

### Structured Macro Editor

The Dashboard editor shows recognized macro events as compact rows instead of exposing every AutoHotkey setup line. Each visible row has four columns:

- `Event` - the macro action type, such as `Send`, `Sleep`, `MouseClick`, `MouseDown`, `MouseUp`, `KeyDown`, or `KeyUp`
- `Key` - the keyboard key/text for keyboard events or `L`, `R`, or `M` for mouse events
- `X` - the delay for `Sleep` or the mouse X coordinate for mouse events
- `Y` - the mouse Y coordinate when the event needs one

Fields that do not apply to the selected event are visibly locked to reduce accidental edits. Hover over `Key`, `X`, or `Y` cells to see what the selected event expects, such as Sleep duration in milliseconds in `X`. Unsupported or custom AutoHotkey lines are hidden to save space, but they are preserved when the macro is saved. Use `Open External` from the toolbar when you need to edit the raw file.

Right-click editor rows to move or delete the selection. The browser's normal right-click menu is disabled inside the app shell. Use Ctrl-click or Shift-click to select multiple rows for multi-delete or multi-move. Hold-style actions are represented as explicit down/up rows, for example `MouseDown` with key `L` followed by `MouseUp` with key `L`, or `KeyDown` with key `W` followed by `KeyUp` with key `W`. Quick stationary clicks are compacted to `MouseClick`; held mouse presses remain as down/up actions.

### Customization

You can customize defaults from the GUI. Changes are saved to `MacroRecorder.ini`:

```ini
[Hotkeys]
Play=F1
Record=F2
Edit=F3
Toggle=F4
Loop=F6

[Recording]
MouseMode=screen
RecordSleep=true

[Ui]
Theme=light

[Discord]
Enabled=false
WebhookUrl=
UserId=
SendScreenshots=false
ScreenshotCropEnabled=false
ScreenshotCropX=0
ScreenshotCropY=0
ScreenshotCropW=0
ScreenshotCropH=0

[Updates]
CheckOnStartup=true

[Files]
MacroDir=C:\Path\To\Macros
CurrentMacroFile=C:\Path\To\Macros\DefaultMacro.txt
```

## Release Process

Maintainers publish MacrobloX through GitHub Releases:

1. Update the app version in `Lib/AppVersion.ahk`.
2. Commit the release changes.
3. Tag the commit, for example `v1.0.0`.
4. Push the tag to GitHub.
5. GitHub Actions creates the release and uploads `MacrobloX-v1.0.0-source.zip`.

Release source zips must include `MacroRecorder.ahk`, `Lib/`, `Gui/`, `README.md`, and `LICENSE`. They must continue to exclude `MacroRecorder.ini`, `MacroRecorder.log`, `Macros/`, `.git/`, `.github/`, `dist/`, generated `.exe` files, and local backup files.

## How to Record

1. Pressing F1 will also force to stop the recording process
2. Quick keyboard input is recorded as compact `Send` commands. Held keys such as `W` and held mouse buttons use explicit down/up actions with real delays preserved as `Sleep(...)` lines. In a text editor this may look like one typed character; in games it preserves the actual held-key state.
3. The recorded macro is saved as the selected `.txt` file and shown in the embedded editor.
4. Edit generated actions directly in the Dashboard editor rail.
5. Use the editor rail's `Loop pause (ms)` and `Loop speed` controls to store loop timing inside the current `.txt` macro.
6. Saving `DefaultMacro.txt` prompts you to save as a named macro instead of overwriting the reset template.
7. Use `Open External` for full raw-file editing in Notepad.
8. Use the toolbar's file actions to create, open, save, or save as `.txt` macros.
9. Use `Macro Folder` to change where future new macro files are created; the selected folder opens in File Explorer.

## Credits

- Original AHK1 Macro Recorder by FeiYue
- [Raeleus's AHK Macro Recorder](https://github.com/raeleus/AHK-Macro-Recorder) for the v2 adaptation
- Forked from [ArtyMcLabin](https://github.com/ArtyMcLabin/AHK2-Macro-Recorder).
