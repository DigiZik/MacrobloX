# MacrobloX

## About

An AHKv2 task that can macro a specific game.

## Installation

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download the repository, keeping `MacroRecorder.ahk` and the `Lib/` folder together.
3. Double-click `MacroRecorder.ahk`.

## Usage

Double-clicking `MacroRecorder.ahk` opens the native Roblox-focused control window. By default, macros are saved as `.txt` files in a `Macros` folder next to `MacroRecorder.ahk`, so the normal workflow is still just launching that one script.

The GUI opens maximized by default and uses a dark, Spotify-inspired console layout with transport controls on the left and a Roblox-first workspace on the right. The layout follows the window border when resized, keeping the sidebar controls, file actions, Roblox area, and editor rail aligned. If Roblox is running as `RobloxPlayerBeta.exe`, the recorder places a borderless Roblox overlay in the main workspace so you can build macros against it while the macro editor stays available as a narrow side rail.

The GUI is resizable and includes:

- Record/Stop, Play, Loop/Stop Loop, Reset, Open External, Enable/Disable, and an `Add action` dropdown for common macro lines
- A `Files` dropdown in the editor panel for New, Open, Save, Save As, and Choose Folder
- A status area showing Roblox detection, the current macro path, recording/looping/disabled state, and editor save state
- Light/dark appearance selection
- Beginner-friendly settings for mouse positions plus per-macro loop pause and loop speed controls
- A collapsible structured macro editor rail that uses about one eighth of the workspace, protects generated setup/exit lines, zebra-stripes rows, and lets recorded action lines be edited directly

Recorded `.txt` macros are intentionally small. The file includes the selected mouse mode, the per-macro loop delay metadata, the recorded actions, and the minimal AutoHotkey setup needed to run them. Loop playback is handled by the recorder app, so saved macros do not need loop boilerplate.

While one-shot playback or loop playback is running, the recorder asks Windows to keep the system and display awake. This helps long loop runs continue instead of being interrupted by idle sleep or display power-off behavior. The request is released when playback stops or finishes.

Settings are saved in `MacroRecorder.ini` next to `MacroRecorder.ahk`. This includes the selected theme, recording options, default macro folder, and current macro file. Runtime errors are written to `MacroRecorder.log`.

The Reset button safely stops recording/playback/looping, releases held modifiers, resets mouse mode to `screen`, switches back to `Macros\DefaultMacro.txt`, recreates it as an empty valid AutoHotkey v2 script, and restarts the recorder.

Closing the main window exits the recorder and stops active recording, playback, and loop processes. Minimizing the window leaves the recorder running.

### Hotkeys

- `F1` - Play recorded macro once
- `F2` - Start/Stop recording macro
- `F4` - Toggle enable/disable script
- `F6` - Play macro in a loop

## Project Layout

- `MacroRecorder.ahk` wires the app together with `#Include` statements, dependency construction, and hotkey setup.
- `Lib/AppGui.ahk` contains the native GUI and embedded editor.
- `Lib/MacroController.ahk` coordinates hotkeys, buttons, and app actions.
- `Lib/MacroRecorderEngine.ahk` records keyboard/mouse actions and builds macro output.
- `Lib/PlaybackController.ahk` runs macros and loop playback.
- `Lib/RobloxWindowService.ahk` detects the Roblox player window and overlays/restores it above the GUI workspace.
- `Lib/ConfigManager.ahk` reads/writes `MacroRecorder.ini`.
- `Lib/MacroFileService.ahk` manages macro paths and file content.
- `Lib/AppLogger.ahk` and `Lib/NotificationService.ahk` provide logging and transient status messages.

### Recording Modes
The script supports three mouse position modes (configurable in the GUI):
- `screen` - Absolute screen coordinates
- `window` - Window-relative coordinates, only for Roblox window
- `relative` - Relative to starting position

Recorded timing gaps are saved as `Sleep(...)` lines automatically. `Loop pause (ms)` controls the delay between repeated loop playback runs for the current `.txt` macro. The adjacent speed dropdown can quickly set common loop pauses: `1x`, `2x`, `5x`, or `10x`.

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
Theme=dark

[Files]
MacroDir=C:\Path\To\Macros
CurrentMacroFile=C:\Path\To\Macros\DefaultMacro.txt
```

## How to Record

1. Pressing F1 will also force to stop the recording process
2. Keyboard input is recorded as one `Send` command per keystroke, with real delays preserved as `Sleep(...)` lines.
3. The recorded macro is saved as the selected `.txt` file and shown in the embedded editor.
4. Right-click an editable macro row to edit or delete it; generated setup and exit rows are protected inside the app.
5. Use the editor rail's `Loop pause (ms)` and `Loop speed` controls to store loop timing inside the current `.txt` macro.
6. Saving `DefaultMacro.txt` prompts you to save as a named macro instead of overwriting the reset template.
7. Use `Open External` for full raw-file editing in Notepad.
8. Use the editor panel's `Files` dropdown to create, open, save, or save as `.txt` macros.
9. Use `Files` > `Choose Folder` to change where future new macro files are created; the selected folder opens in File Explorer.

## Credits

- Original AHK1 Macro Recorder by FeiYue
- [Raeleus's AHK Macro Recorder](https://github.com/raeleus/AHK-Macro-Recorder) for the v2 adaptation
- Forked from [ArtyMcLabin](https://github.com/ArtyMcLabin/AHK2-Macro-Recorder).
