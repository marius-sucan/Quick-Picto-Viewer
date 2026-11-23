# Analysis of 3d828e1 "worked on keyboard input handlers"

Written 2026-09-12 against HEAD `3d828e1` on `interface-thread-merge-phase-c`. Static analysis only; nothing was run on Windows. Line numbers refer to the committed files.

## What the commit changes

1. **Main-window key dispatch.** `uiPreProcessKbdKey()` and its 3 ms timer are gone. `uiWM_KEYDOWN()` (module 2359) now calls `ProcessCriticalKeys(keyu)` synchronously inside the monitor. Only when that returns 1 does it store `hotkate := keyu` and arm the main script's `PreProcessKbdKey` timer (-15 ms), which lost its `Awin=PVhwnd` early return (main 587) so it serves both the panels and the main window. `KeyboardResponder()` dropped its fourth parameter (main 726).
2. **Close routine.** `preByeRoutine()` is folded into `byeByeRoutine(eventu, keyMode)` (module 1964). Every close entry (`uiWM_CLOSE`, `uiWM_SYSCOMMAND`, `uiWM_NCLBUTTONDOWN`, the three drain peeks, the hook's busy gate) calls `byeByeRoutine("win-close")`, which first runs `ProcessCriticalKeys("win-close", 1)`.
3. **Color picker state machine.** `colorPickerMustEnd` is deleted. `colorPickerModeNow` now holds 1 = picking, 2 = accept, 3 = cancel. The loop in `StartPickingColor()` (main 48315) no longer calls `drainUIinput()`; the loop pumps through `Sleep` and OnMessage monitors launch even under Critical, so they run and set the state. It also cancels when `WinActive("A")!=PVhwnd`.
4. **Hook busy gate** (module 232): menus are now also blocked while `whileLoopExec=1`, `mustCaptureCloneBrush=1` or `colorPickerModeNow>=1`, and a menu message during capture/picking runs `byeByeRoutine("win-close")` to cancel them.
5. Smaller items: `WM_MOUSEWHEEL` gained a 200 ms throttle; `WM_MBUTTONDOWN` and the thumbs Escape defer `ToggleThumbsMode` to a timer; the collapsed widget always has its four extra buttons; four brush-panel tooltips; `GuiGDIupdaterResize()` uses the stop helper; `isQPVactive()` refactor; `PVwinGuiDropFiles()` rejects drops while picking.

## A. Regressions certain from the code

### A1. Title-bar X in thumbnails mode leaves thumbnails mode instead of exiting
`byeByeRoutine("win-close")` → `ProcessCriticalKeys("win-close", 1)` rewrites the key to `"Escape"` (module 2290) and branch 3 (module 2309) recurses into `byeByeRoutine("Escape", 1)`. The real close work therefore always runs with `eventu="Escape"`, and the thumbs branch (module 2022) picks `SetTimer, ToggleThumbsMode, -25` instead of `exitAppu()`. The outer call then returns because `ProcessCriticalKeys` returned 0.

Before the commit `preByeRoutine("win-close")` reached `exitAppu()` in thumbs mode. Alt+F4 is unaffected (its `eventu` stays `"!F4"`). Repro: open thumbnails, click the X: the grid closes, the app stays. A second X click exits.

Same root cause: the force-exit prompt (A2) and every other `eventu` comparison inside `byeByeRoutine` now see `"Escape"` for a window close.

### A2. Force-exit prompt text is prefixed with the event name
Module 1992: `uiNativeYesNoPrompt(eventu "The main window seems to be busy at the moment. ...")`. The user sees `EscapeThe main window seems to be busy...` (or `!F4The...`, `EnterThe...`). Debug leftover.

### A3. Close requests are ignored while a QPV viewport window is not active
`ProcessCriticalKeys` opens with `If (!identifyThisWin() || (A_TickCount - lastOtherWinClose<300)) Return` (module 2281), and `byeByeRoutine` returns when that call returns blank (module 1975). The gate was written for keyboard input (the old `uiPreProcessKbdKey` had it); it now also filters `WM_CLOSE`, `SC_CLOSE` and the drain's HTCLOSE path.

`identifyThisWin()` (main 529) is true only when the foreground window is PVhwnd or one of the viewport windows, cached for 50 ms. A close request that arrives while another application is in the foreground is dropped: the taskbar thumbnail's close button and the taskbar "Close window" item, `taskkill` without `/F`, Task Manager's graceful attempt before it terminates the process. Before the commit `preByeRoutine` had no such gate.

The second half of the gate adds a debounce the close path never had: `showThisMenu()` ends with `lastOtherWinClose := A_TickCount + 100` (main 69613), so the X is ignored for roughly 400 ms after any menu closes, and for 300 ms after a panel close or a playback stop.

Needs a Windows run to confirm which shell paths arrive while inactive; the code path itself is certain.

### A4. Tooltip typo
Main 44786: `"Shortcut in viewport: Shit + Y"`. The other three shortcut claims check out against `processDefaultKbdCombos()`: `S` → `BtnSetClonerBrushSource` (cloner type only, main 1861), `Shift+S` → `toggleBrushDoubleSize` (1880), `Shift+K` → `toggleBrushDrawInOutModes` (1836), `Y` → `toggleBrushSymmetryModes` (1220), `Shift+Y` → `BtnSetBrushSymmetryCoords` (1224).

## B. Behaviour changes to confirm as intended

### B1. Mouse wheel limited to one event per 200 ms
Module 1191-1193 and 1215: events arriving within 200 ms of the last accepted one are dropped. Wheel zoom (`VPchangeZoom`, main 1645), thumbnails scrolling and every modifier variant now run at most five steps per second; a fast spin loses most notches. If the aim was to stop the `QPV_post` timers from piling up, coalescing the pending direction would keep the responsiveness.

### B2. Escape and Alt+F4 during viewport drag loops open the force-exit prompt
Module 1988: the prompt condition gained `|| whileLoopExec=1`, and branch 3 of `ProcessCriticalKeys` no longer requires an idle app. Keys from panels and the toolbar are still filtered by the main `WM_KEYDOWN` gate, so the affected loops are the ones running with the main window active and `whileLoopExec=1` without `runningLongOperation`: the `WinClickAction` drags (main 10073), `simplePanIMGonClick`, `panIMGonScrollBar`, `ThumbsScrollbar`, `winSwipeAction`, the five vector point movers, `ActPaintBrushNow`, `ActDrawAlphaMaskBrushNow`, `ImageNavBoxClickResponder`, plus `SaveFilesList`, `selectSeenFilesSession` and the tail of `SortFilesList` (it clears `runningLongOperation` before raising `whileLoopExec`, main 37440). Operations that go through `doStartLongOpDance()` keep `runningLongOperation=1` and still reach `askAboutStoppingOperations()`. Before the commit Escape there went down the exit ladder (close the panel, or quit when nothing was open). The modal box is answerable and "No" resumes the loop, but a stray Escape mid-pan now asks about force-exiting the application.

### B3. Toolbar and widget clicks during the picker cancel instead of accepting
The loop tests `WinActive("A")!=PVhwnd` (main 48320) before `colorPickerModeNow=2` (48326). The toolbar (`OSDguiToolbar`, main 103349) and the collapse widget (26256) are owned tool windows without `WS_EX_NOACTIVATE`, so a click activates them; the main `WM_LBUTTONdown` writes 2 (main 99618) but the loop sees the activation first and restores the initial color. Before the commit any left button-down accepted. The two writers now disagree about what a toolbar click means; one of them should go. Needs a Windows run to confirm the activation order.

The four buttons the collapse widget used to omit while picking or capturing (main 26283-26286) are now present, so "Cancel tool and close panel" can run `BtnCloseWindow()` while `StartPickingColor()` is still on the stack; the tail of that function tolerates a closed panel, but it is a new path.

### B4. All keys are swallowed during clone-source, symmetry-center and texture capture
Branch 1 of `ProcessCriticalKeys` (module 2292) is entered for every key while `mustCaptureCloneBrush=1` and never sets `callMain`. Escape, Enter, Space, Tab, Delete and BackSpace cancel the capture through `StopCaptureClickStuff(keyu)`; the non-Escape keys also re-expand the collapsed panel because of its `dummy!="escape"` test (main 69108). Before the commit only Escape cancelled and every other shortcut kept working.

### B5. Other picker differences
Numpad5 no longer accepts (old loop polled it); Delete and BackSpace now cancel; keys are ignored for the first 300 ms of a pick because `StartPickingColor()` stamps `lastOtherWinClose` right before the loop and `uiWM_KEYDOWN` gates on it (the old loop polled `GetKeyState` immediately); a menu entry (Alt, Alt+letter, Alt+Space) cancels the pick and closes the menu.

### B6. Escape in thumbnails mode with a panel open closes the panel first
Old `preByeRoutine` toggled thumbnails before looking at `AnyWindowOpen` and before the 250 ms `lastInvokedThis` guard; now both apply (module 1983, 2016). Arguably better, but it is a change.

### B7. The busy early return in uiWM_KEYDOWN is gone
Old code returned 0 for every non-Escape key while `whileLoopExec`, `runningLongOperation` or `imageLoading` was set (unless playback ran). Now branch 4 runs for them: Space swaps the busy cursor for the pan cursor during operations (`uiChangeMcursor("move")`, module 2323), and the navigation keys run `alterFilesIndex++ / canCancelImageLoad := 4 / stopGIFsPlayback()` whenever `canCancelImageLoad=1`. `alterFilesIndex` is read only by the thumbnails page loop (main 84728-85109) and `stopGIFsPlayback()` returns at once when nothing plays, so no functional regression was found; noted because the gate is gone. Tab was added to the playback-stop keys (module 2304).

### B8. GuiGDIupdaterResize
Now a `stopGifORslidesPlayback()` call (main 85483). Neutral on its only live path because `PVwinGuiSize()` runs the same helper first; the earlier note that this function was a deliberate non-pair no longer applies.

## C. Hazard: byeByeRoutine runs inside the CALLWNDPROC hook
Module 234-235: while `mustCaptureCloneBrush=1`, any of the four menu messages runs `byeByeRoutine("win-close")` → `ProcessCriticalKeys` → `StopCaptureClickStuff()` (main 69103) from inside the hook callback, before `EndMenu`. That helper does `SoundBeep, 300, 100` (a blocking 100 ms beep inside WM_ENTERMENULOOP processing), `setMenuBarState("Enable")` with a `Sleep, -1` per changed bar item (module 815, a nested pump), and creates the tooltip GUI. The 6c64199 clean-up removed exactly this class of nested pump from hook-reachable paths. Whether it is reachable with the bar disabled needs a Windows run: the expectation is that Alt alone still enters the menu loop and sends WM_ENTERMENULOOP. For the color picker the same path only writes the state and stamps, which is safe.

## D. Low-likelihood races
- **30 ms hole in ProcessCriticalKeys.** The throttle `(A_TickCount - lastInvoked>30)` is part of branch 1's condition (module 2292), so a cancel key pressed within 30 ms of any other key during picking or capture skips branch 1 and lands in branch 3: during the picker that is the force-exit prompt (`whileLoopExec=1`); during capture it is `CloseWindow()` on the brush panel. Gate the handling inside branch 1 instead of the branch selection.
- **Main WM_LBUTTONdown resets a pending state** (main 99618): `(colorPickerModeNow=1) ? 2 : 0` turns a pending 3 (cancel) into 0, which the loop then treats as accept. Only when a left click on a panel or toolbar lands within ~20 ms of a right or middle click.
- **uiWM_LBUTTONUP overrides a pending cancel** (module 1282): a left button-up arriving after a right/middle cancel writes 2. Needs the left button held across the cancel click.

## E. Dead code and nits
- `lastInvokedThis := A_TickCount` in `ProcessCriticalKeys` (module 2298) is a local; the static it targets lives in `byeByeRoutine`.
- `abusive`, `counter`, `prevKey` in `ProcessCriticalKeys` are computed and never used; `PreProcessKbdKey` keeps its own copies.
- `closeMode` never reaches branch 4: with `closeMode=1` the key is always `"Escape"`, caught by branch 3. The `If (closeMode=0)` block (module 2336) is always entered.
- `QPV_post("KeyboardResponder", ..., 0, navKeysCounter)` (module 1214) still passes four arguments to a three-parameter function. Safe: AHK 1.1.37.02 `script_expression.cpp:1866` drops surplus arguments of a dynamic call ("Omit any actuals that lack formals"). Vestigial.
- `fnOutputDebug(A_ThisFunc "(): " eventu " | " keyMode)` at module 1972 is unindented; looks like a leftover.
- `iF` at module 234.
- Main 44756 passes the shortcut line as the third argument of `GuiAddDropDownList()`, which is the hidden label control (main 26435), not the tooltip (fourth argument). The tooltip still shows it because the helper falls back to the label, but the label text now carries a newline and the shortcut.
- `CreateCollapsedPanelWidget()` still keys its rebuild on `colorPickerModeNow` and `mustCaptureCloneBrush` (main 26252) although the layout no longer depends on them.

## F. What the commit gets right
- `hotkate` is written only for keys that will actually dispatch (module 2400-2403), and the drain no longer re-fires the pre-processor, so the stale-key prompts of the 09-06 check cannot recur.
- The picker loop stopped calling `drainUIinput()`: the loop pumps through `Sleep` and OnMessage monitors launch even under Critical, so the drain was redundant whichever thread state a caller brings in (main 77204 calls it directly from another function).
- `ToggleThumbsMode` no longer runs inside a message monitor (module 1342, 2026).
- `PreProcessKbdKey` moving `lastInvoked` after the responder call adds a 30 ms cooldown after each key action; re-entrancy exposure is unchanged in practice.

## Suggested repros on Windows
1. Thumbnails mode, click the X (A1).
2. Any image loading, press Escape: read the prompt text (A2).
3. Put another app in the foreground, hover QPV's taskbar button, click the thumbnail's X (A3).
4. Start a color pick, click a toolbar button: expect the initial color restored (B3).
5. Spin the wheel fast over an image: count zoom steps (B1).
6. Drag-pan an image and press Escape while dragging (B2).
