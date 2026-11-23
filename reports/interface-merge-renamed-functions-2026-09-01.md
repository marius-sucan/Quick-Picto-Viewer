# module-interface.ahk — function inventory after the interface-thread merge

Snapshot: branch `interface-thread-merge-phase-c` at `993d5b3` plus the 2026-09-07 working-tree
edit of `uiInstallSentMsgHook()` / `uiCallWndProcWork()` (the probe acknowledgement moved from the
`sentMsgProbeSeen` module global to a slot passed as the probe's lParam; the global is gone),
compiled 2026-09-07 from the sources, not from memory. Every function defined at
column 0 in `quick-picto-viewer.ahk` and `lib/*.ahk` was parsed. The 58-name set that §1 and §2
partition is the set of names that `lib/module-interface.ahk` and the other source files both
define on `master`; that branch is the comparison baseline and nothing else is taken from it.
`lines` = lines between a function's braces. `refs` = case-insensitive bare-word occurrences of
the name in code (comments stripped: calls, `SetTimer` targets, quoted names for `OnMessage`,
`QPV_post` and `RegisterCallback`), definition lines excluded, split into `module`
(`lib/module-interface.ahk`) / `rest` (every other source file).

Result: `lib/module-interface.ahk` defines 100 functions, 38 of them `ui`-prefixed. **8 names
exist twice** (§1: the module's copy carries the `ui` prefix). **50 baseline names exist once**
(§2). §3 lists the windows and menus the module owns, §4 what the inventory surfaced, §5 the
wrapper check, §6 the 59 functions that exist on this branch and not on `master`.

## 1. Names defined on both sides: the eight `ui` pairs

The main script owns the plain name; the module's copy carries the `ui` prefix. Each pair is
reached differently, and that is what keeps both alive.

### A. Different jobs under one name (3)

| module function | main-script twin | what each does | lines ui / main | refs ui / main |
|---|---|---|---|---|
| `uiChangeMcursor(whichCursor)` | `changeMcursor(whichCursor:=0)` | module: the viewport cursor setter (`SetCursor` with cached `LoadCursor` handles for normal, busy, finger, move, cross); `"normal-extra"` also clears the busy flags (`imageLoading`, `runningLongOperation`, `mustAbandonCurrentOperations`, `userPendingAbortOperations`, `lastCloseInvoked`) and resets the taskbar icon, `"busy"` / `"busy-img"` start the taskbar animation; inert while a slideshow or a GIF plays. Main: a gated, throttled entry onto the module's function: unless an image is loading it returns while a shape is being drawn, playback runs, `hasInitSpecialMode=1` or `zeitSillyPrevent` is fresh; with a name it forwards it, without one it asks for `"busy"` at most every 400 ms. 6 main-script sites call `uiChangeMcursor` directly, 88 go through `changeMcursor` | 46 / 13 | 13 / 88 |
| `uiKmenu(labelu, funcu, mena:="PVbar", actu:="Add")` | `kMenu(mena, actu, labelu, funcu:=0, keywords:="", altLabel:="", keepUp:=0)` | module: adds one bar item with its `:submenu` attachment to `PVbar` and records it in `menuArray` by index and by label; `BuildMenuBar()` is its only caller. Main: the general menu-item helper (add, separators, reset, the searchable registry behind the quick search) | 12 / 196 | 1 / 1707 |
| `uiUpdateUIctrl(forceThis:=0)` | `updateUIctrl()` | module: lays out the five screen-reader/hit-test zones and the two scrollbar strips over the painted viewport, in PVwin client space (viewport origin + viewport coordinates), state-diffed; `"kill"` clears the memo; bows out while the thumbnails list is displayed. Main: decides between the welcome layout and the image layout and posts `uiAccessWelcomeView` or `uiUpdateUIctrl` through `QPV_post` | 48 / 5 | 12 / 22 |

### B. Same message, one handler per window family (5)

`initInterfaceModule()` registers one `dispatch*` composer per message number (§6); each routes
on `isUIrootWin()` — the message's window root is PVwin, one of the four GDI containers, the
tooltip or the flyout — to the `ui` handler, and to the plain one for panels, the toolbar and
every other window. `drainUIinput()` calls the `ui` handlers directly for queued PVwin input.

| module function | main-script twin | what each does | lines ui / main | refs ui / main |
|---|---|---|---|---|
| `uiWM_KEYDOWN` | `WM_KEYDOWN` | module: Alt+letter posts `SC_KEYMENU` with the mnemonic so the bar opens as native keyboard tracking, Alt+Space posts `SC_KEYMENU` with a space for the system menu; counts navigation keys, hides the status-bar tooltip, Escape → `preByeRoutine("Escape")`, other keys are dropped while busy (unless a GIF or a slideshow plays) and for 300 ms after a window close; else `hotkate := constructKbdKey(...)` and `uiPreProcessKbdKey` is armed on a 3 ms timer. Main: while a MsgBox2 conflict prompt waits the key goes to `MsgBoxConflictKeysResponder`; returns for PVwin, busy states (Escape excepted) and the 300 ms after a window close; else builds `hotkate`, records `vk_hwnd`, arms `PreProcessKbdKey` on a 25 ms timer and lets `decideBlockKbdKeys()` swallow the keys that edit fields, sliders, the quick search or the toolbar own | 59 / 25 | 2 / 1 |
| `uiPreProcessKbdKey` | `PreProcessKbdKey` | module: the keyboard tail of the PVwin family (also run inline by the drain): 30 ms rate limit and the abusive-repeat counter; Escape/Enter/Space first stop playback through `stopGifORslidesPlayback(1)`; Escape, Alt+F4 and Enter-while-busy go to `preByeRoutine`; Space sets the pan cursor in zoom mode; navigation keys stop a slideshow or cancel a running image load (`alterFilesIndex`, `canCancelImageLoad`, `stopGIFsPlayback()`); everything else reaches `KeyboardResponder(hotkate, PVhwnd, abusive, navKeysCounter)`. Main: the tail for every other window: returns when PVwin is active or the active window changed since the key-down (`vk_hwnd`); same rate limit and counter, then `KeyboardResponder(hotkate, parent-or-active hwnd, abusive, "n")` | 60 / 30 | 3 / 1 |
| `uiWM_LBUTTONDOWN` | `WM_LBUTTONdown` | module: viewport button-down: the drag-window test, the silly-GUI and active-window gates, the 25 ms / start-up / window-drag / double-click debounce, `LbtnDwn` with its `ResetLbtn` timer, `canCancelImageLoad := 4`, coordinates through `uiGetMouseCoords()`, tooltip off; while busy for more than 900 ms → `askAboutStoppingOperations()`, else stop playback, else `WinClickAction("normal", IdentifyCtrlUnderMouse(...), adjX, adjY)`. Main: panels and toolbar: closes the solo slider widget, fires toolbar buttons from `tlbrIconzList` through `tlbrInvokeFunction`, expands a collapsed edit panel, and a click into a numeric edit field arms `adjustNumbersEditFields` | 39 / 41 | 2 / 1 |
| `uiWM_LBUTTONUP` | `WM_LBUTTONup` | module: tooltip off, `LbtnDwn := 0`, `colorPickerMustEnd := 1`; the three flyout buttons (300 ms debounce): S opens or closes the quick search, T `toggleAppToolbar()`, M `ToggleMenuBaru()`. Main: resolves a waiting MsgBox2 button, `colorPickerMustEnd`, settings panel → `GuiUpdateFocusedSliders()` + `highlightActiveCtrl("click")`, toolbar → `decideWinReactivation()` | 30 / 24 | 2 / 1 |
| `uiWM_MOUSEMOVE` | `WM_MOUSEMOVE` | module: viewport hover: the pan-cursor hold, the `isQPVactive()` gate, `LbtnDwn` from the button state, the cursor shape (cross while drawing, busy, finger over the thumbnails status bar), the status-bar tooltip timer, the flyout button tooltips and their dark-mode theming, `MouseMoveResponder()` at most every 55 ms, and the Shift+Ctrl window drag (a `WM_NCLBUTTONDOWN` post plus `trackMouseDragging`) when the title bar is hidden. Main: panels and toolbar: busy cursor while busy, finger cursor over tab-stop statics and colour list views, toolbar hover tooltips (`tlbrDecideTooltips`, `DelayedToolbarTooltips`), the dragger cursor, and the accessible name pushed into the hovered button | 90 / 80 | 2 / 1 |

## 2. Names defined once

The 58 baseline names minus the 8 pairs above: each has exactly one definition today.
`refs` = module / rest. Notes only where they add something.

| name | defined in | lines | refs | note |
|---|---|---|---|---|
| `addJournalEntry` | quick-picto-viewer.ahk | 35 | 0 / 384 | the module writes no journal entries |
| `adjustWin2MonLimits` | quick-picto-viewer.ahk | 16 | 0 / 3 | |
| `calcHUDsize` | quick-picto-viewer.ahk | 1 | 3 / 4 | |
| `calcScreenLimits` | lib/msgbox2.ahk | 59 | 0 / 11 | |
| `clampInRange` | quick-picto-viewer.ahk | 15 | 1 / 506 | |
| `constructKbdKey` | quick-picto-viewer.ahk | 23 | 1 / 2 | called by both `uiWM_KEYDOWN` and `WM_KEYDOWN` |
| `dummy` | quick-picto-viewer.ahk | 1 | 3 / 344 | |
| `GetMenuItemRect` | lib/shell-stuff.ahk | 13 | 0 / 1 | |
| `GetPhysicalCursorPos` | lib/shell-stuff.ahk | 26 | 1 / 31 | |
| `GetWinClientSize` | lib/shell-stuff.ahk | 30 | 0 / 10 | |
| `GetWindowBounds` | lib/shell-stuff.ahk | 22 | 0 / 1 | |
| `GetWindowFromPos` | lib/shell-stuff.ahk | 6 | 1 / 0 | module-only caller (`uiWM_MOUSEMOVE`, dark-mode theming of the flyout tooltip) |
| `GetWindowPlacement` | lib/shell-stuff.ahk | 16 | 1 / 9 | |
| `GetWinHwndAtPoint` | lib/shell-stuff.ahk | 4 | 0 / 0 | no caller anywhere (§4) |
| `identifyThisWin` | quick-picto-viewer.ahk | 7 | 2 / 7 | the active window is one of the five PVwin-family windows, memoised for 50 ms |
| `InitGuiContextMenu` | quick-picto-viewer.ahk | 81 | 2 / 2 | called from `WM_RBUTTONUP` and `WM_LBUTTON_DBL` with `IdentifyCtrlUnderMouse()` |
| `isAlphaMaskWindow` | quick-picto-viewer.ahk | 2 | 0 / 29 | the module reaches it only through `isNowAlphaPainting()` |
| `isDotInRect` | quick-picto-viewer.ahk | 4 | 2 / 56 | |
| `isInRange` | quick-picto-viewer.ahk | 4 | 5 / 209 | |
| `isNowAlphaPainting` | quick-picto-viewer.ahk | 1 | 2 / 69 | `isAlphaMaskWindow()` + `liveDrawingBrushTool` + `isImgEditingNow()`; used by `BuildMenuBar` and `UpdateMenuBar` |
| `IsNumber` | lib/Gdip_All.ahk | 4 | 0 / 96 | |
| `isTlbrVertical` | quick-picto-viewer.ahk | 4 | 1 / 1 | |
| `isVarEqualTo` | quick-picto-viewer.ahk | 10 | 11 / 120 | |
| `JEE_ClientToScreen` | lib/shell-stuff.ahk | 9 | 3 / 11 | |
| `JEE_ScreenToClient` | lib/shell-stuff.ahk | 9 | 2 / 5 | |
| `KeyboardResponder` | quick-picto-viewer.ahk | 231 | 2 / 2 | called by both keyboard tails (`uiPreProcessKbdKey`, `PreProcessKbdKey`) and posted by `WM_MOUSEWHEEL` |
| `MDMF_FromHWND` | lib/Gdip_All.ahk | 1 | 0 / 1 | |
| `MDMF_FromPoint` | lib/Gdip_All.ahk | 9 | 0 / 1 | |
| `MDMF_GetInfo` | lib/Gdip_All.ahk | 14 | 0 / 2 | |
| `mouseCreateOSDinfoLine` | quick-picto-viewer.ahk | 35 | 2 / 9 | one tooltip window for the viewport and the panels (`mouseToolTipGuia`, §3) |
| `mouseTurnOFFtooltip` | quick-picto-viewer.ahk | 22 | 11 / 18 | the hide path of that window (`mouseCreateOSDinfoLine` destroys and recreates it); 11 module sites |
| `msgBoxWrapper` | quick-picto-viewer.ahk | 74 | 0 / 292 | the module shows no MsgBox2 dialog; its two prompts use `uiNativeYesNoPrompt()` |
| `MWAGetMonitorMouseIsIn` | lib/shell-stuff.ahk | 22 | 0 / 3 | |
| `PanelQuickSearchMenuOptions` | quick-picto-viewer.ahk | 75 | 1 / 28 | module-side reach: the flyout S button in `uiWM_LBUTTONUP` |
| `PreventKeyPressBeep` | lib/module-interface.ahk | 1 | 1 / 0 | the one name whose single copy lives in the module; registered by `initInterfaceModule()` |
| `RepositionTempBtnGui` | quick-picto-viewer.ahk | 33 | 1 / 1 | module-side reach: `SetTimer` from `WM_WINDOWPOSCHANGED` |
| `repositionWindowCenter` | quick-picto-viewer.ahk | 134 | 1 / 77 | module-side reach: `BuildGUI()` centres PVwin with it |
| `saveMainWinPos` | quick-picto-viewer.ahk | 5 | 1 / 0 | module-only caller (`SetTimer` from `WM_WINDOWPOSCHANGED`) |
| `SetMenuInfo` | lib/shell-stuff.ahk | 29 | 0 / 1 | |
| `setMenusTheme` | lib/shell-stuff.ahk | 11 | 0 / 2 | |
| `SetParentID` | lib/shell-stuff.ahk | 2 | 4 / 0 | module-only callers (the four GDI containers) |
| `setPriorityThread` | lib/shell-stuff.ahk | 3 | 0 / 8 | |
| `showOSDinfoLineNow` | quick-picto-viewer.ahk | 62 | 1 / 5 | the placement half of the tooltip pair |
| `toggleAppToolbar` | quick-picto-viewer.ahk | 18 | 1 / 10 | module-side reach: the flyout T button in `uiWM_LBUTTONUP` |
| `ToggleMenuBaru` | quick-picto-viewer.ahk | 16 | 1 / 3 | module-side reach: the flyout M button in `uiWM_LBUTTONUP` |
| `Trimmer` | quick-picto-viewer.ahk | 5 | 1 / 292 | |
| `UnregisterTouchWindow` | lib/shell-stuff.ahk | 1 | 6 / 2 | called for PVwin, four of its hit-test controls and the four GDI containers |
| `Win_ShowSysMenu` | lib/shell-stuff.ahk | 12 | 0 / 0 | no caller anywhere (§4) |
| `WinClickAction` | quick-picto-viewer.ahk | 725 | 4 / 1 | the module hands it every viewport click (`uiWM_LBUTTONDOWN`, `WM_LBUTTON_DBL`, `WM_MBUTTONDOWN`) |
| `WinMoveZ` | lib/shell-stuff.ahk | 20 | 1 / 1 | |

## 3. Windows and menus the module owns

- GUIs: `PVwin` (the main window), `PVgdiPic`, `PVgdiThumbs`, `PVgdiInfos`, `PVgdiSelect` (the
  layered containers `BuildGUI()` creates; reparented into PVwin except on Windows 7),
  `menuFlier` (the S/T/M flyout, `hFlyOut`) and `MclickH` (the click halo).
- AutoHotkey derives implicit handlers from the GUI name: `PVwinGuiSize()` and
  `PVwinGuiDropFiles()` are those handlers for PVwin, so their zero textual references are by
  design. There is no `PVwinGuiClose` label: `WM_CLOSE` on the PVwin family is answered by the
  `uiWM_CLOSE` monitor (§6), which returns 0 after `preByeRoutine("win-close")`.
- Menus: `PVbar` is the menu bar; `BuildMenuBar()` fills it through `uiKmenu`, every item
  carrying its real dropdown as an attached submenu, and `UpdateMenuBar()` rebuilds it behind the
  placeholder menu `PVmanu`. `PVmenu` is the main script's context menu.
- Tooltip: one window, `mouseToolTipGuia`, owned by the main script's `mouseCreateOSDinfoLine()`,
  `showOSDinfoLineNow()` and `mouseTurnOFFtooltip()`; the module uses it for the thumbnails
  status-bar tooltip and the menu reader's announcements.

## 4. What the inventory surfaced

- `GetWinHwndAtPoint()` in `lib/shell-stuff.ahk` has no caller anywhere.
- `Win_ShowSysMenu()` in `lib/shell-stuff.ahk` has no caller; the comment in `uiWM_KEYDOWN`
  names it as the library helper for a programmatic system menu. Alt+Space itself goes through
  `SC_KEYMENU`.
- `changeMcursor` / `uiChangeMcursor` are one mechanism with two entry points (§1-A): the gate
  and the throttle live under the main-script name, the cursor work under the module's, and 6
  main-script sites bypass the gate. The other seven pairs are separated by window family or by
  job.
- The module has no dead function: each of its 100 functions is referenced, or is an implicit GUI
  handler.

## 5. Wrapper check

Criterion: a wrapper is useless when its body only forwards to another function, directly or
through a queued post, and every caller could name the target itself with no change in
behaviour. Every module function with three or fewer code lines (18 of 100; code lines =
non-blank, non-comment) was classified by body shape and by how it is referenced (direct call,
`SetTimer` target, quoted name); the 4–12-line functions were read; the main-script functions
of §6 were checked the same way.

Result: **no pure forward exists.** The 18 small functions are:

- the six `dispatch*` composers (they route by window root, §1-B) and `isUIrootWin` (the root
  test they share, 13 callers);
- timer adapters, needed because `SetTimer` passes no arguments and runs no bare command:
  `DestroyClickHalo` (`Gui, MclickH: Hide`), `trackMouseDragging` (stamps `lastWinDrag`), and
  `uiStopMenuTimer` (the `KillTimer` of the menu ticker, three callers);
- small predicates and handlers: `preventSillyGui`, `TestDraggableWindow`, `WM_MOUSELEAVE`,
  `PreventKeyPressBeep`, `updateWindowColor`, `destroyMenuFlyout`, `uiAccessViewportOrigin`
  (three assignments derived from `adjustCanvas2Toolbar()`) and `WM_PENpressure`
  (`Critical, off` plus the shared pressure reader).

Main-script functions that look like wrappers and are not: `QPV_post` (the queued-call facade,
§6), `updateUIctrl` and `changeMcursor` (§1-A: a mode choice, a gate and a throttle),
`hideMenuFlyoutNow` (two stamps, then `coreHideMenuFlyout()`), `setWhileLoopBusy` (returns the
previous flag) and `scheduleNextSlide` (a gated timer arm).

## 6. Functions that exist on this branch and not on `master`

59 names: 8 are the `ui` pairs of §1 and 2 the implicit handlers of §3. The remaining **49**,
grouped by role.

### Module bootstrap and message dispatch — lib/module-interface.ahk (12)

| function | lines | what it does |
|---|---|---|
| `initInterfaceModule()` | 57 | called once from the main script's start-up before `BuildGUI()` (the module-owned globals are declared and seeded by the module's top-level `Global` line, which runs when the file is included in the auto-exec section): registers the module-only `OnMessage` handlers (`WM_MOUSELEAVE`, `WM_RBUTTONUP`, `WM_MBUTTONDOWN`, `WM_WINDOWPOSCHANGED`, `WM_ACTIVATE` / `WM_KILLFOCUS` → `activateMainWin`, `uiWM_NCLBUTTONDOWN`, `uiWM_SYSCOMMAND`, `uiWM_CLOSE`), the four `WM_POINTER*` numbers → `WM_PENpressure` when `GetPointerPenInfo` exists, and the keystroke-beep suppression (0x101–0x103, 0x105–0x108 → `PreventKeyPressBeep`); installs the sent-message hook (`uiInstallSentMsgHook()`) and the composed dispatchers for 0x100/0x104, 0x200–0x203 and 0x20A/0x20E |
| `isUIrootWin(hwnd)` | 2 | true when the window's `GA_ROOT` is PVwin, one of the four GDI containers, the tooltip or the flyout; the test the dispatchers and most module-only monitors branch on (13 callers) |
| `dispatchKeyDown()` | 3 | `WM_KEYDOWN` / `WM_SYSKEYDOWN` → `uiWM_KEYDOWN` or `WM_KEYDOWN` |
| `dispatchMouseMove()` | 3 | `WM_MOUSEMOVE` → `uiWM_MOUSEMOVE` or `WM_MOUSEMOVE` |
| `dispatchLButtonDown()` | 3 | `WM_LBUTTONDOWN` → `uiWM_LBUTTONDOWN` or `WM_LBUTTONdown` |
| `dispatchLButtonUp()` | 3 | `WM_LBUTTONUP` → `uiWM_LBUTTONUP` or `WM_LBUTTONup` |
| `dispatchLButtonDbl()` | 3 | `WM_LBUTTONDBLCLK` → `WM_LBUTTON_DBL` or `OnLButtonDblClk` |
| `dispatchMouseWheel()` | 3 | `WM_MOUSEWHEEL` / `WM_MOUSEHWHEEL` → `WM_MOUSEWHEEL` or `adjustWheelNumbersEditFields` (called with its three declared parameters: the loader arity-checks direct calls) |
| `uiVisibleMenuWin(ptX:="", ptY:="")` | 15 | the first visible `#32768` window of this process, or the one under the given screen point; 0 when none |
| `uiWM_NCLBUTTONDOWN()` | 10 | the title-bar ✗ (`HTCLOSE`) on the PVwin family while `runningLongOperation`, `imageLoading` or `whileLoopExec` is set → `preByeRoutine("win-close")` and 0; idle clicks fall through to the default caption handling |
| `uiWM_SYSCOMMAND()` | 7 | `SC_CLOSE` (system menu, taskbar, or the ✗ release) on the PVwin family → `preByeRoutine("win-close")` and 0 |
| `uiWM_CLOSE()` | 4 | `WM_CLOSE` on the PVwin family → `preByeRoutine("win-close")` and 0, so the window never closes underneath a worker loop; every other window keeps its own `GuiClose` label |

### Liveness for loops that hold Critical — lib/module-interface.ahk (4)

| function | lines | what it does |
|---|---|---|
| `drainUIinput()` | 91 | the one checkpoint pump, 8 call sites in the main script's long loops: removes up to 40 queued key and mouse messages of PVwin and its children and hands them to the `ui` handlers inline (`uiWM_KEYDOWN` with `hotkate` blanked first, `uiWM_MOUSEMOVE`, `uiWM_LBUTTONDOWN` / `UP`, `WM_LBUTTON_DBL`, `WM_RBUTTONUP`, `WM_MBUTTONDOWN`, `WM_MOUSEWHEEL`), so the abort and cancel flags keep working while Critical is held; a queued ✗ click, `SC_CLOSE` or `WM_CLOSE` becomes `preByeRoutine("win-close")`; the keyboard tail `uiPreProcessKbdKey()` runs only when a drained key-down produced a `hotkate`, and its pending timer is then disarmed; input for other windows stays queued; re-entrancy-guarded; restores the caller's Critical state; nothing is dispatched to a window procedure |
| `pumpPenMessages()` | 30 | the brush loop's checkpoint: removes up to 20 queued `WM_POINTER*` messages, reads each through `readPenPointerMsg()` and hands it to `DefWindowProc` so Windows keeps promoting the pen to mouse messages; never `DispatchMessage` (its `OnMessage` launches reset the interpreter's peek clock and starve the loop's 16 ms message check) |
| `readPenPointerMsg(wp, msg)` | 33 | `penPressureRaw` from `GetPointerPenInfo` (0 on up / leave and while hovering); shared by the `WM_PENpressure` monitor and the checkpoint; touches no Critical state |
| `uiNativeYesNoPrompt(msg)` | 38 | the Yes/No box behind `askAboutStoppingOperations()` and the force-exit branch of `byeByeRoutine()`: a DllCall'd `MessageBoxW` (`MB_YESNO` \| `MB_ICONQUESTION` \| `MB_SETFOREGROUND`) owned by PVhwnd and shown with Critical held, so nothing queued (timers, posts, g-labels) runs while it is up; when Critical was off before, it is left on afterwards on purpose; returns `"yes"` or `"no"` |

### Native menus: the sent-message hook and the menu session — lib/module-interface.ahk (16)

The menu bar carries real attached submenus. During a modal menu loop no AutoHotkey thread
launches, so the machinery rides the messages Windows SENDS to the menu owner, seen through a
`WH_CALLWNDPROC` hook.

| function | lines | what it does |
|---|---|---|
| `uiInstallSentMsgHook()` | 62 | installs the `WH_CALLWNDPROC` hook and picks its procedure. With `qpvmain.dll` loaded: registers `uiCallWndProcWork` with `qpvHookSentMessages` for `WM_INITMENUPOPUP`, `WM_MENUSELECT`, `WM_ENTERMENULOOP`, `WM_EXITMENULOOP` and the `0x85EE` probe, sends the probe to the script's own window with the address of a 4-byte local as lParam and keeps the native procedure only when that slot came back set to 1 (otherwise it unhooks and logs). Without the DLL, or when the probe fails: `SetWindowsHookEx` with the script procedure `uiCallWndProc`. Called from `initInterfaceModule()`, where the DLL is not loaded yet, and again from `initQPVmainDLL()`, which swaps the native procedure in |
| `uiCallWndProc(nCode, wP, lP)` | 13 | the fallback script hook procedure, in place only until the DLL loads: a numeric trampoline that decodes the `CWPSTRUCT` and calls `uiCallWndProcWork` for the four menu messages, then `CallNextHookEx`; every other sent message of the thread passes through untouched |
| `uiCallWndProcWork(msg, wP, lP, hwnd:=0)` | 69 | the worker for the four menu messages, entered from the native procedure or the trampoline: saves and restores Critical; acknowledges the install probe by writing 1 into the slot its lParam points at; while `runningLongOperation` or `imageLoading` is set, `WM_INITMENUPOPUP` and `WM_ENTERMENULOOP` end the menu with `EndMenu`, `WM_MENUSELECT` is ignored and `WM_EXITMENULOOP` still runs its exit; `WM_MENUSELECT` → `uiMenuSelectTrack`; `WM_INITMENUPOPUP` → infers the session type when no loop is active yet (a mapped HMENU is a bar dropdown), records the flyout anchor, `uiMenuJITrebuild(hMenu)`, `uiStartMenuTimer()`; `WM_ENTERMENULOOP` → `uiMenuLoopEnter(wP)`; `WM_EXITMENULOOP` → `uiMenuLoopExit()`; returns 0 |
| `uiMenuJITrebuild(hMenu)` | 31 | rebuilds a bar dropdown's content in place at `WM_INITMENUPOPUP` through `menuJITmap` (HMENU → `InvokeMenuBar*` builder, `justBuild=1`); bar sessions only, busy-guarded; closes the quick search and the tooltip first |
| `uiMenuSelectTrack(mwParam, hMenuSel)` | 39 | tracks the highlighted item for the menu reader: reads the item text with `GetMenuStringW` (by position for `MF_POPUP`, by command id otherwise), appends the submenu / unavailable / checked state and the accelerator, and keeps it in `uiMenuReaderLastMsg` for the on-demand announcement; also triggers the flyout placement while the flyout is not visible |
| `uiMenuLoopEnter(fromPopup:=0)` | 15 | menu-session start: `menuLoopActive`, the session type from the `WM_ENTERMENULOOP` wParam (0 = bar tracking, 1 = popup), the reader and flyout state reset, and the `WH_MOUSE_LL` hook (`uiMenuMouseLL`) installed |
| `uiMenuLoopExit()` | 19 | menu-session end: clears the state, stops the menu timer, removes the mouse hook, calls `hideMenuFlyOut()` and, with the reader on, `mouseTurnOFFtooltip()`, and arms `uiRefreshBarAttachments` on a 50 ms timer |
| `uiMenuMouseLL(nCode, wP, lP)` | 55 | the `WH_MOUSE_LL` procedure, active only inside a menu session: expires the reader OSD; a wheel notch over a visible menu window is eaten and replaced by three posted arrow key-downs to PVwin; right button down over a menu window shows the tracked item text as a 1500 ms OSD and eats the click (and the matching button-up); Critical saved and restored |
| `uiStartMenuTimer()` | 4 | arms the native 20 ms `TIMERPROC` timer (`0xF17E` on PVhwnd) → `uiMenuTimerProc`; the modal loop dispatches `WM_TIMER`, unlike AutoHotkey timers |
| `uiStopMenuTimer()` | 1 | its `KillTimer`; called from the loop exit, the timer procedure and `coreHideMenuFlyout` |
| `uiMenuTimerProc()` | 7 | the timer procedure: retries `uiTryPlaceFlyout()` until the flyout is visible, then stops the timer; Critical saved and restored |
| `uiTryPlaceFlyout(anchor:=0)` | 46 | positions the S/T/M flyout below the anchored popup: the anchor is an HMENU resolved to its visible `#32768` window through `MN_GETHMENU` (or a window handle, or the first visible menu window when there is no anchor); creates `menuFlier` on first use; one main-script caller, `showThisMenu()` |
| `uiRefreshBarAttachments()` | 39 | the self-healing pass after every menu loop: re-resolves each bar attachment by name through `uiMenuNameForBuilder`, re-adds to `PVbar` the ones whose handle changed, rebuilds `menuJITmap`; a no-op when nothing changed |
| `uiMenuNameForBuilder(suffix)` | 10 | the static map from an `InvokeMenuBar<suffix>` builder to the menu name it builds |
| `coreHideMenuFlyout()` | 7 | the flyout hide itself: clears the visible flag and the anchor, stops the menu timer, hides `menuFlier` and the click halo, disarms `hideMenuFlyOut` |
| `hideMenuFlyoutNow()` — quick-picto-viewer.ahk | 3 | stamps `lastOtherWinClose` and `lastContextMenuZeit`, then `coreHideMenuFlyout()`: the immediate variant `showThisMenu()` uses when the mouse is not over the flyout (`hideMenuFlyOut` is the deferred, mouse-position-gated one) |

### Queued calls — quick-picto-viewer.ahk (2)

| function | lines | what it does |
|---|---|---|
| `QPV_post(funcName, args*)` | 4 | queued execution: binds `QPV_postRelay(funcName, args)` to a 5 ms one-shot timer, so the target runs when the thread next pumps messages, never inline; 25 call sites (22 in the main script, 3 in the module) |
| `QPV_postRelay(funcName, args)` | 23 | the relay: hoists `args[1..9]` into plain locals and calls the target by name with the matching arity (the parser accepts neither `args*` nor `args[N]` inside a call's argument list) |

### Input coordinates — lib/module-interface.ahk (1)

| function | lines | what it does |
|---|---|---|
| `uiGetMouseCoords(lParam, ByRef rawX, ByRef rawY, ByRef adjX, ByRef adjY)` | 8 | splits a mouse message's `lParam` into PVwin client coordinates, stamps `lastLclickX/Y`, and when the toolbar is docked (`detectToolbar()`) converts them into the GDI container's client space; four callers (`uiWM_LBUTTONDOWN`, `WM_MBUTTONDOWN`, `WM_LBUTTON_DBL`, `WM_RBUTTONUP`) |

### Slideshow and GIF playback (4)

| function | file | lines | what it does |
|---|---|---|---|
| `stopSlideshow(resetMode:=0, silentModus:=1)` | quick-picto-viewer.ahk | 25 | the single slideshow teardown, 73 call sites: clears the flag, stops the `theSlideShowCore` timer and the music (unless `resetMode=1`), restores the toolbar region and redraws it, relayouts the accessibility controls, schedules `ResetImgLoadStatus`, updates the seen-images counter, and when not silent shows the "STOPPED" tooltip (plus a beep for sub-second cadences) |
| `scheduleNextSlide()` | quick-picto-viewer.ahk | 5 | after an image load completes while a slideshow runs: `allowNextSlide := 1` and `theSlideShowCore` armed at `-slideShowCadence` |
| `stopGifORslidesPlayback(loudly:=0)` | lib/module-interface.ahk | 14 | the user-gesture stop the module's handlers share (11 call sites: viewport clicks, wheel, keys, resize, drop, close, plus the main script's delete-file action): stops a running slideshow (`stopSlideshow(0, !loudly)`) and a playing GIF (`stopGIFsPlayback()`), stamps `lastOtherWinClose`, returns whether anything was playing |
| `InformToggledSlideShowu(actu:=0)` | quick-picto-viewer.ahk | 10 | the menu and toolbar entry: resets `GIFframesPlayied`; `"stop"` → a loud `stopSlideshow(0, 0)`; otherwise opens a pending start folder and `ToggleSlideShowu(actu)` |

### SQLite abort hatch — quick-picto-viewer.ahk (1)

| function | lines | what it does |
|---|---|---|
| `sqliteAbortProgressCB(unusedArg)` | 16 | the `sqlite3_progress_handler` callback: `Class_SQLiteDB.OpenDB()` arms it on every connection through the class-wide `SQLiteDB.AbortCallback` (set to this name at start-up) and `ArmAbortHandler()`; runs inside the querying thread about every 9,000 opcodes, saves and restores Critical, and returns 1 (interrupt the statement) when a long operation or `allowSQLiteAbort=1` coincides with `mustAbandonCurrentOperations=1` |

### Screen-reader / hit-test control placement (3)

| function | file | lines | what it does |
|---|---|---|---|
| `uiAccessViewportOrigin(ByRef oX, ByRef oY)` | lib/module-interface.ahk | 10 | the PVwin client-space origin of the viewport, read from the painter's own `adjustCanvas2Toolbar()` (toolbar width or height when it is docked), so the controls land on the painted elements |
| `uiAccessListViewLayout(heightu, ByRef prevState)` | lib/module-interface.ahk | 25 | thumbnails / list view: the files-list container above the status bar, the status bar along the bottom edge (stopping where the scrollbar starts) and the scrollbar strip down the right edge, all shifted by the viewport origin; state-diffed; the only path that follows a resize while the list is displayed |
| `infoBoxAccessCtrlPos(...)` | quick-picto-viewer.ahk | 8 | PVwin client coordinates of the info box for its screen-reader control: applies the canvas mirroring (`FlipImgH` / `FlipImgV`, image view only) and the docked-toolbar offset |

### Other names that exist only on this branch (6)

Outside the merge machinery; listed so the count reconciles.

| function | file | lines | what it does |
|---|---|---|---|
| `copyTextToClippy(textu)` | quick-picto-viewer.ahk | 6 | `Clipboard := textu` under `Try`; returns 1 on success, 0 on failure; 15 call sites |
| `setWhileLoopBusy()` | quick-picto-viewer.ahk | 3 | sets `whileLoopExec := 1` and returns the previous value; 9 call sites |
| `refreshUImainWinElements()` | quick-picto-viewer.ahk | 5 | menu bar update, toolbar re-creation, the welcome-view controls, and the toolbar reposition timer when it is docked |
| `tlbrInvokeSortListMenu()` | quick-picto-viewer.ahk | 16 | the toolbar's sort button: shows `PVsort` at the button, opens a pending start folder first and retries, or warns when fewer than three files are indexed |
| `UIoffsetSelProperPanel(dummy:=0)` | quick-picto-viewer.ahk | 102 | the selection-properties panel's nudge buttons: steps the selection coordinates or size, Ctrl+click prompts for a value, `&align` opens the alignment menu |
| `dummyUIoffsetSelProperPanel()` | quick-picto-viewer.ahk | 5 | repeats the nudge every 25 ms while the button stays pressed |

Not functions of the application: `merge-probes/` holds thirteen standalone probe scripts
(p1–p13) with a README of verdicts on what runs during a same-interpreter menu loop.

## Appendix — reproducing the numbers

- Definitions: a column-0 `name(` line followed by a column-0 `{` (on the same line or the next
  non-blank one); the body runs to the next column-0 `}`. Parsed from `quick-picto-viewer.ahk`
  and `lib/*.ahk` at HEAD, and from the same files at `master` for the baseline.
- Baseline set: the `master` names defined in `lib/module-interface.ahk` ∩ the `master` names
  defined in the other files = 58. Today a baseline name with `ui<name>` in the module and
  `<name>` elsewhere is a §1 pair (8); one with a single definition is a §2 row (50); none is
  undefined.
- §6: HEAD names − `master` names = 59.
- `lines`: between the braces, blank and comment lines included. Code lines (§5): non-blank,
  non-comment lines between the braces.
- `refs`: case-insensitive whole-word matches in code after stripping `;` comments (at line
  start or preceded by whitespace, outside double quotes) and column-0 `/* */` blocks,
  definition lines excluded. The comment stripping is approximate: a `;` inside a string that
  follows a space cuts that line early.
