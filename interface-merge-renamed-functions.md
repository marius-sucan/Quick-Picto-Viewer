# module-interface.ahk — functions renamed at the interface-thread merge

Branch `interface-thread-merge-phase-c`, compiled 2026-09-02 from git, not from memory:
the function sets of `lib/module-interface.ahk` on `master` (the AutoHotkey_H thread era),
at the phase-A commit `a850285` (where the renames happened) and at HEAD were parsed and
compared against every function defined in `quick-picto-viewer.ahk` and `lib/*.ahk`.
Body similarity = `difflib` ratio over comment- and whitespace-stripped bodies
(`identical` = byte-identical after that normalisation). Reference counts are bare-word
occurrences of the name in code (calls, `SetTimer` targets, `g`-labels, quoted names),
definition lines excluded.

Result: **58 function names existed on both sides**. 26 were resolved by renaming the
module's copy with a `ui` prefix (section 1); the other 32 were resolved without a rename
(section 2). Two more functions were renamed for a different reason (section 3).

## 1. The 26 renamed functions (module copy got the `ui` prefix)

Why a rename and not a merge: at phase A the app was still two-threaded and each side had to
keep every function it calls, so twins were either converged byte-identical (and deleted at
the flip) or renamed when the two bodies did different jobs. 18 pairs are genuinely different
jobs under one name (group A). 8 pairs are the same job that had drifted apart in the two
interpreters (group B) — those were renamed rather than converged to keep phase A
behaviour-neutral, and with a single interpreter they are now consolidation candidates.

### Group A — same name, different job (18): the rename was the right call; two of them are dead today (see §4)

| thread-era name | module name now | main twin lives in | what the two do | bodies at master | bodies now | refs ui / main |
|---|---|---|---|---|---|---|
| `addJournalEntry` | `uiAddJournalEntry` | quick-picto-viewer.ahk | main: the 37-line journal writer; module: a 4-line stub | 0.04 | 0.05 | **0** / 384 |
| `changeMcursor` | `uiChangeMcursor` | quick-picto-viewer.ahk | module: viewport cursor shapes (49 lines); main: panel/generic cursor (17) | 0.11 | 0.10 | 8 / 101 |
| `InitGuiContextMenu` | `uiInitGuiContextMenu` | quick-picto-viewer.ahk | main: the 85-line context-menu builder; module: 4-line trigger | 0.03 | 0.01 | 2 / 3 |
| `KeyboardResponder` | `uiKeyboardResponder` | quick-picto-viewer.ahk | module: 46-line PVwin pre-filter (nav-key stop, Space, Escape); main: the 233-line command dispatcher | 0.03 | 0.03 | 1 / 4 |
| `kMenu` | `uiKmenu` | quick-picto-viewer.ahk | main: the menu-item helper used 1707 times; module: bar-menu variant with a different signature | 0.02 | – | 1 / 1707 |
| `mouseTurnOFFtooltip` | `uiMouseTurnOFFtooltip` | quick-picto-viewer.ahk | module: hides the viewport tooltip GUI (15 lines); main: 5-line panel variant | 0.29 | 0.26 | 18 / 17 |
| `PanelQuickSearchMenuOptions` | `uiPanelQuickSearchMenuOptions` | quick-picto-viewer.ahk | main: the 81-line panel; module: 11-line opener | 0.02 | 0.02 | 1 / 25 |
| `RepositionTempBtnGui` | `uiRepositionTempBtnGui` | quick-picto-viewer.ahk | main: 35-line positioner; module: 3-line post | 0.03 | 0.03 | 1 / 2 | *(module copy deleted 2026-09-02, §7-A)*
| `repositionWindowCenter` | `uiRepositionWindowCenter` | quick-picto-viewer.ahk | main: 136-line general window centering; module: 42-line PVwin-family variant | 0.41 | 0.41 | 1 / 77 |
| `saveMainWinPos` | `uiSaveMainWinPos` | quick-picto-viewer.ahk | main: writes the INI; module: 3-line trigger | 0.18 | 0.18 | 1 / 1 | *(module copy deleted 2026-09-02, §7-A)*
| `toggleAppToolbar` | `uiToggleAppToolbar` | quick-picto-viewer.ahk | main: the 20-line toggle; module: 8-line trigger | 0.05 | 0.07 | 1 / 11 |
| `ToggleMenuBaru` | `uiToggleMenuBaru` | quick-picto-viewer.ahk | main: the 18-line toggle; module: 8-line trigger | 0.18 | 0.13 | 1 / 4 |
| `updateUIctrl` | `uiUpdateUIctrl` | quick-picto-viewer.ahk | module: 52-line viewport-controls layout; main: 7-line panel helper | 0.02 | 0.03 | 11 / 21 |
| `Win_ShowSysMenu` | `uiShowSysMenu` | lib/shell-stuff.ahk | both emulate Alt+Space with TrackPopupMenu; signatures differ (1 vs 3 params) | 0.10 | 0.10 | 1 / **0** |
| `WinClickAction` | `uiWinClickAction` | quick-picto-viewer.ahk | module: 22-line click pre-dispatcher; main: the 728-line click body | 0.01 | 0.01 | 3 / 2 |
| `WM_LBUTTONDOWN` | `uiWM_LBUTTONDOWN` | quick-picto-viewer.ahk | per-window message handlers: module = PVwin family, main = panels; the merged dispatcher branches by window root | 0.08 | 0.08 | 2 / 1 |
| `WM_LBUTTONUP` | `uiWM_LBUTTONUP` | quick-picto-viewer.ahk | same split as above | 0.07 | 0.04 | 2 / 1 |
| `WM_MOUSEMOVE` | `uiWM_MOUSEMOVE` | quick-picto-viewer.ahk | same split as above | 0.10 | 0.10 | 2 / 1 |

### Group B — same job, drifted bodies (8): consolidation candidates now that there is one interpreter

> **Status 2026-09-02:** the first six rows were consolidated (section 6); the two keyboard rows stay split by window.

| thread-era name | module name now | bodies at master | bodies now | refs ui / main | what differs today | verdict |
|---|---|---|---|---|---|---|
| `constructKbdKey` | `uiConstructKbdKey` | identical | identical | 1 / 2 | nothing (only the line-wrapping of the `vkList` literal) | delete `uiConstructKbdKey`, point `uiWM_KEYDOWN` at `constructKbdKey`; zero risk |
| `identifyThisWin` | `uiIdentifyThisWin` | 0.88 | 0.88 | 2 / 7 | the module copy also accepts `otherAscriptHwnd`, which since the merge is always the script's own hidden window (`initInterfaceModule` seeds it with `A_ScriptHwnd`, and both callers of `menuFlyoutDisplay`, its only runtime setter, pass `A_ScriptHwnd`) — never the active window in practice | consolidate onto `identifyThisWin` |
| `isAlphaMaskWindow` | `uiIsAlphaMaskWindow` | 0.54 | 0.54 | 1 / 29 | main's ID set is `23,24,31,32,70,74,89` (+ a `m` param); the module's stopped at `70` — the thread copy was never updated when panels 74 and 89 appeared | consolidate onto `isAlphaMaskWindow()`; fixes a latent drift on the UI side |
| `isNowAlphaPainting` | `uiIsNowAlphaPainting` | 0.78 | 0.77 | 2 / 69 | main tests `isImgEditingNow()`; the module approximated it with mirrored flags (`imgEditPanelOpened=1 && editingSelectionNow=1`) because it could not call main | consolidate onto `isNowAlphaPainting()` after checking the two UI call sites accept `isImgEditingNow()` semantics |
| `mouseCreateOSDinfoLine` | `uiMouseCreateOSDinfoLine` | 0.90 | 0.83 | 2 / 9 | two tooltip GUIs: the module pair drives `uiMouseTipGuia` (newer: OSD font name/bold prefs, `Critical`), main's drives `mouseToolTipGuia` for the panels | possible, but it means unifying the two tooltip windows — a medium job, not a free win |
| `showOSDinfoLineNow` | `uiShowOSDinfoLineNow` | 0.98 | 0.88 | 2 / 5 | the placement half of the pair above; same two-GUI split | goes with the row above |
| `PreProcessKbdKey` | `uiPreProcessKbdKey` | 0.62 | 0.53 | 3 / 1 | main's serves the non-PVwin windows; the module's serves the PVwin family and carries the GIF/slideshow stop logic and the QPVMERGE dispatch log | keep both (they gate on different windows); a fold-in would need a window test at the top |
| `WM_KEYDOWN` | `uiWM_KEYDOWN` | 0.61 | 0.43 | 2 / 1 | per-window handlers again; the module's grew the SC_KEYMENU Alt+letter / Alt+Space entry in phase D | keep both |

## 2. The other 32 collisions — resolved without a rename

At phase A each pair was converged to a byte-identical body (authoritative side = the most
recently fixed one), the module copy was tagged `; MERGEDEL`, and at the phase-C flip the
tagged copy was deleted. Where the module's body was the better one, its text was adopted by
the main side first (15 of them; e.g. `calcScreenLimits`' blank-coordinates mouse fallback
was backported into msgbox2.ahk, `GetWinClientSize` adopted shell-stuff's superset body).

| name | surviving copy | bodies at master | resolution |
|---|---|---|---|
| `adjustWin2MonLimits` | quick-picto-viewer.ahk | identical | module copy deleted |
| `calcHUDsize` | quick-picto-viewer.ahk | identical | module copy deleted |
| `calcScreenLimits` | lib/msgbox2.ahk | 0.95 | converged (module's mouse-pos fallback backported), module copy deleted |
| `clampInRange` | quick-picto-viewer.ahk | identical | module copy deleted |
| `dummy` | quick-picto-viewer.ahk | 0.82 | converged, module copy deleted |
| `GetMenuItemRect` | lib/shell-stuff.ahk | 0.99 | converged, module copy deleted |
| `GetPhysicalCursorPos` | lib/shell-stuff.ahk | 0.95 | converged, module copy deleted |
| `GetWinClientSize` | lib/shell-stuff.ahk | 0.46 | shell-stuff's superset body kept, module copy deleted |
| `GetWindowBounds` | lib/shell-stuff.ahk | 0.99 | converged, module copy deleted |
| `GetWindowFromPos` | lib/shell-stuff.ahk | identical | module copy deleted |
| `GetWindowPlacement` | lib/shell-stuff.ahk | identical | module copy deleted |
| `GetWinHwndAtPoint` | lib/shell-stuff.ahk | identical | module copy deleted |
| `isDotInRect` | quick-picto-viewer.ahk | 0.92 | converged, module copy deleted |
| `isInRange` | quick-picto-viewer.ahk | identical | module copy deleted |
| `IsNumber` | lib/Gdip_All.ahk | identical | module copy deleted |
| `isTlbrVertical` | quick-picto-viewer.ahk | identical | module copy deleted |
| `isVarEqualTo` | quick-picto-viewer.ahk | identical | module copy deleted |
| `JEE_ClientToScreen` | lib/shell-stuff.ahk | identical | module copy deleted |
| `JEE_ScreenToClient` | lib/shell-stuff.ahk | 1.00 | converged, module copy deleted |
| `MDMF_FromHWND` | lib/Gdip_All.ahk | 0.99 | converged, module copy deleted |
| `MDMF_FromPoint` | lib/Gdip_All.ahk | 1.00 | converged, module copy deleted |
| `MDMF_GetInfo` | lib/Gdip_All.ahk | 1.00 | converged, module copy deleted |
| `msgBoxWrapper` | quick-picto-viewer.ahk (14-param, msgbox2-based) | 0.04 | **absorbed**: the module's 7-param native-MsgBox version was dropped and its two callers retargeted to `simpleMsgBoxWrapper` |
| `MWAGetMonitorMouseIsIn` | lib/shell-stuff.ahk | identical | module copy deleted |
| `PreventKeyPressBeep` | **lib/module-interface.ahk** | identical | inverse case: main's copy was the dead one and was deleted |
| `SetMenuInfo` | lib/shell-stuff.ahk | 1.00 | converged, module copy deleted |
| `setMenusTheme` | lib/shell-stuff.ahk | 0.94 | converged, module copy deleted (with shell-stuff's forwarder line) |
| `SetParentID` | quick-picto-viewer.ahk | 0.93 | converged, module copy deleted |
| `setPriorityThread` | lib/shell-stuff.ahk | identical | module copy deleted |
| `Trimmer` | quick-picto-viewer.ahk | identical | module copy deleted |
| `UnregisterTouchWindow` | lib/shell-stuff.ahk | identical | module copy deleted |
| `WinMoveZ` | lib/shell-stuff.ahk | 1.00 | converged, module copy deleted |

## 3. Renamed for another reason: the numbered GUIs got names

The module's GUIs 1-5 became `PVwin`, `PVgdiPic`, `PVgdiThumbs`, `PVgdiInfos`, `PVgdiSelect`
(main has 1,059 bare `Gui, Add` lines that rely on named defaults, so two sets of numbered
GUIs could not coexist). AutoHotkey derives the implicit event handlers from the GUI name, so:

| thread-era name | name now | kind |
|---|---|---|
| `GuiSize()` | `PVwinGuiSize()` | implicit size handler of GUI 1 |
| `GuiDropFiles()` | `PVwinGuiDropFiles()` | implicit drop handler of GUI 1 |
| `1GuiClose:` | `PVwinGuiClose:` | label |
| GUI `mouseToolTipGuia` | `uiMouseTipGuia` | the viewport tooltip window (main keeps its own `mouseToolTipGuia` for panels) |
| menu `PVmenu` (the bar) | `PVbar` | main's `PVmenu` is the context menu — two different menus under one name |

## 4. Leftovers this inventory surfaced

- `uiConstructKbdKey` is a byte-for-byte duplicate of `constructKbdKey` (one caller).
- `uiAddJournalEntry` is dead: every reference to it is a commented-out line.
- The Alt+Space emulation chain is dead since Alt+Space rides `SC_KEYMENU`: `Win_ShowSysMenu`
  (shell-stuff, zero references), `uiShowSysMenu` (only reachable from the `!Space` branch of
  `uiKeyboardResponder`, which `uiWM_KEYDOWN` now intercepts first) and `coreShowSysMenu`.
  *Resolved 2026-09-02, see section 6 — `Win_ShowSysMenu` kept by request.*
- `uiIsAlphaMaskWindow` still carries the thread-era window-ID set without panels 74 and 89.
- The group-B rows are the natural next consolidation pass; group A stays as it is by design
  (each pair is two contracts that happened to share a name).

## 6. Consolidation pass — 2026-09-02 (per Marius)

- `uiConstructKbdKey` and `uiAddJournalEntry` deleted; `uiWM_KEYDOWN` calls `constructKbdKey`.
- `uiIdentifyThisWin` → `identifyThisWin` (the extra `otherAscriptHwnd` test dropped; that
  write-only global is gone with it).
- `uiIsAlphaMaskWindow` and `uiIsNowAlphaPainting` → `isAlphaMaskWindow` / `isNowAlphaPainting`,
  main's predicates winning as asked: panels 74 and 89 now count as alpha-mask windows on the
  UI side too, and `isImgEditingNow()` replaces the mirrored `imgEditPanelOpened`/`editingSelectionNow` pair.
- The tooltip pair → **one window**, `mouseToolTipGuia` (main's names for the GUI, the
  `mouseToolTipWinCreated` flag and `lastTippyWin`): `mouseCreateOSDinfoLine` keeps main's styling
  (Arial Bold, 1.25× margin — per Marius, tooltips never use the OSD font), main's deliberate
  no-`Critical` choice and its click handler; `showOSDinfoLineNow` was already identical; `mouseTurnOFFtooltip` took the module's
  richer body (statusbar flag, `lastWinDrag` guard, timer disarm) and replaces `uiMouseTurnOFFtooltip`
  at its 14 module sites — one window needs one owner of the destroy, which is why that function
  joined the pass; `mouseClickTurnOFFtooltip`, `destroyTooltipu` and the `uiMouseTipGuia` close/escape
  labels are gone. `hGuiTip` finally has a single owner (both windows used to write it).
- The dead Alt+Space emulation: `uiShowSysMenu` and `coreShowSysMenu` deleted together with the
  unreachable `!Space` branch of `uiKeyboardResponder`; `Win_ShowSysMenu` in shell-stuff.ahk is kept
  on purpose as the library helper for a programmatic system menu.

## 7. Useless wrappers — inventory of 2026-09-02

Criterion: a wrapper is useless when its body only forwards to another function — directly, or
through the `MT_post`/`IF_post` queue — and every caller could name the target itself with no
change in behaviour. Two facts decide most rows: a `SetTimer` target already runs as a queued
thread, so a *timer → wrapper → `MT_post`* chain defers twice for nothing; and `? 1 : 0` adds
nothing to a value that is only ever tested as a boolean. Method: every module function with
three or fewer code lines (23 of 111) was classified by body shape and by how it is referenced
(direct call, `SetTimer` target, quoted name, `g`-label); the 4–12-line relays were read by hand;
the main script was checked for the functions the merge added there.

### A. Pure forwards in module-interface.ahk — delete and retarget

> **Applied 2026-09-02:** all four deleted and their callers retargeted as listed.

| wrapper | body | referenced by | replacement |
|---|---|---|---|
| `identifyMenus()` | `Return uiVisibleMenuWin() ? 1 : 0` | 2 direct calls, both `!identifyMenus()` | `uiVisibleMenuWin()` — it returns the menu hwnd or 0, which is all a boolean test needs |
| `sendWinClickAct(ctrlEvent, guiCtrl, mX, mY)` | `MT_post("WinClickAction", ctrlEvent, guiCtrl, mX, mY)` | 2 direct calls (the LButton-up handler, `uiWinClickAction`) | `MT_post("WinClickAction", …)` written at the two sites |
| `uiRepositionTempBtnGui()` | `MT_post("RepositionTempBtnGui")` | 1 `SetTimer … -95` | `SetTimer, RepositionTempBtnGui, -95` — `RepositionTempBtnGui(mm:=0)` is timer-callable |
| `uiSaveMainWinPos()` | `MT_post("saveMainWinPos")` | 1 `SetTimer … -35` | `SetTimer, saveMainWinPos, -35` |

### B. Merge facades in quick-picto-viewer.ahk

> **Applied 2026-09-02, `IF_call` only:** the facade is deleted and its 11 sites are direct calls (every arity
> re-checked against the target's signature first — direct calls are load-time checked, the dynamic ones were not).
> `IF_post` and `MT_post` stay as they are, by request.

| facade | what it is today | sites | replacement |
|---|---|---|---|
| `IF_call(funcName, args*)` | a 23-line arity-dispatched dynamic call, `%funcName%(a1 … a9)` | 11, every one with a literal function name | the plain direct call `funcName(args)`. The facade exists because the target used to live in the other interpreter; now it is only a slower, arity-capped way to write a normal call |
| `IF_post` and `MT_post` | byte-identical bodies: `Func("IF_postRelay").Bind(funcName, args)` + `SetTimer, % fn, -1` | 41 + 32 | one name is enough — they were the two directions of a bridge that no longer has two sides. The queued semantics are real and stay; pick one name and rename the other's sites (a whole-word rename). `IF_postRelay` stays, it is the relay both use |

### C. Thin relays — not useless, but only a 300 ms debounce away from it

| relay | body | callers |
|---|---|---|
| `uiToggleAppToolbar()` | 300 ms debounce, then `MT_post("toggleAppToolbar")` | 1 |
| `uiToggleMenuBaru()` | 300 ms debounce, then `MT_post("ToggleMenuBaru")` | 1 |
| `uiPanelQuickSearchMenuOptions()` | 300 ms debounce, then `MT_post` of `closeQuickSearch` or `PanelQuickSearchMenuOptions` depending on `VisibleQuickMenuSearchWin` | 1 |
| `uiInitGuiContextMenu(mX, mY, oX, oY)` | `IdentifyCtrlUnderMouse(oX, oY)`, then `MT_post("InitGuiContextMenu", "extern", mX, mY, 0, ctrl)` | 2 |

If the three targets took over their own debounce, the first three relays would fall into group A.
The fourth is an argument adapter shared by two callers — cheap to inline, harmless to keep.

### D. Looked like wrappers, are not — keep

- Timer adapters that exist because `SetTimer` cannot pass arguments or run a bare command:
  `DestroyClickHalo` (`Gui, MclickH: Hide`; `ShowClickHalo` is still posted from the main script),
  `trackMouseDragging` (stamps `lastWinDrag`), `miniGDIupdater` (two actions).
- Real logic with a small body: the six `dispatch*` window-root dispatchers, `isUIrootWin`,
  `preventSillyGui`, `TestDraggableWindow`, `WM_MOUSELEAVE`, `PreventKeyPressBeep`,
  `updateWindowColor`, `destroyMenuFlyout`. `MenuBonusOptions` (a `SoundBeep` placeholder menu
  handler) was listed here until 2026-09-02, when it went with the dormant `applyFilter` branch of
  `BuildMenuBar` (see footnote 3). `stopDupesEngineNow` (a named DllCall of `dupesEngineCancel`
  with one caller, the abort prompt) was listed here until 2026-09-03: on one interpreter it could
  only ever run between step budgets, where the dupes loops already cancel themselves, so it was
  removed; the sort it once stopped from the other thread is now covered by an Escape poll inside
  the DLL's `dupesProgressCB`.
- The main script gained only five functions in the merge: the three facades above, plus
  `armSQLiteAbortHandler` and `sqliteAbortProgressCB` (the SQLite abort hook, real code).

## 8. Functions the merge added (no renames in this list)

Derived from git on 2026-09-02: the column-0 function sets of `quick-picto-viewer.ahk` and
`lib/*.ahk` on `master` versus HEAD give 43 names that did not exist before the branch; 17 of
them are the `ui`-prefixed collision renames and the two GUI-name renames (sections 1 and 3),
which are excluded here. The remaining **26** are genuinely new. Each was traced to the first
commit in which it appears; every one of those commits carries the merge's co-author trailer,
i.e. none came from Marius' own commits on this branch. Phase letters refer to the plan.

### Module bootstrap and message dispatch — lib/module-interface.ahk (phase C, `c629bc2`)

| function | lines | what it does |
|---|---|---|
| `initInterfaceModule()` | 78 | the module's auto-exec replacement: seeds the module-owned globals, registers the OnMessage dispatchers and the module-only messages, installs the WH_CALLWNDPROC hook |
| `isUIrootWin(hwnd)` | 4 | true when a window's root is PVwin, one of the four GDI windows, the tooltip or the flyout — the test every dispatcher branches on |
| `dispatchKeyDown()` | 5 | WM_KEYDOWN/WM_SYSKEYDOWN → `uiWM_KEYDOWN` for the PVwin family, main's `WM_KEYDOWN` for everything else |
| `dispatchMouseMove()` | 5 | same split for WM_MOUSEMOVE |
| `dispatchLButtonDown()` | 5 | same split for WM_LBUTTONDOWN |
| `dispatchLButtonUp()` | 8 | same split for WM_LBUTTONUP (plus the tooltip window) |
| `dispatchLButtonDbl()` | 5 | same split for WM_LBUTTONDBLCLK |
| `dispatchMouseWheel()` | 5 | WM_MOUSEWHEEL → `WM_MOUSEWHEEL` for the PVwin family, `adjustWheelNumbersEditFields` for panels |
| `uiVisibleMenuWin(ptX:="", ptY:="")` | 24 | the visibility-aware `#32768` probe: returns the menu hwnd filtering on visibility; when screen coordinates are passed, hit-tests all visible `#32768` windows of this process |
| `uiWM_NCLBUTTONDOWN()` | 10 | WM_NCLBUTTONDOWN monitor for the PVwin family: intercepts HTCLOSE (20) during busy states (`runningLongOperation`, `imageLoading`, `whileLoopExec`) to immediately invoke `preByeRoutine()` on mouse down and return 0; idle clicks pass through to DefWindowProc for standard caption tracking |
| `uiWM_SYSCOMMAND()` | 9 | WM_SYSCOMMAND monitor for the PVwin family: intercepts SC_CLOSE (`0xF060`) from sysmenu, taskbar close, or mouse-up release on caption [X], invokes `preByeRoutine()`, and returns 0 |
| `uiWM_CLOSE()` | 6 | WM_CLOSE monitor for the PVwin family: calls `preByeRoutine()` and returns 0 to prevent AHK from closing the window underneath worker loops; non-interface windows fall through to their own GuiClose labels |

### Liveness shims for Critical worker loops — lib/module-interface.ahk (phase C, `c629bc2`)

| function | lines | what it does |
|---|---|---|
| `drainUIinput()` | 93 | selective PeekMessage drain of the PVwin family's input while a loop holds Critical: abort gestures (Escape, viewport clicks, the title-bar ✗) reach their handlers inline, the keyboard tail runs only when a keydown was drained, everything else stays queued. The one checkpoint pump — the full pump was deleted (see the footnote) (2026-09-03: this is the click path for loops whose DLL step writes through the AHK SQLite connection — the progress fast-callback resets AHK's peek clock, so the per-line peek after the DllCall stays quiet; loops that only compute get their clicks as monitor threads) |
| `pumpPenMessages()` | 32 | pen message checkpoint for the brush loop: reads the queued WM_POINTER* through `readPenPointerMsg()` and hands each one to DefWindowProc for the mouse promotion — never DispatchMessage: the OnMessage launch it triggers resets the interpreter's peek clock, which starved the loop's 16 ms message check while a pen streamed updates and kept the brush painting 300–600 ms after the lift (fixed 2026-09-02, see the RULE in the function) |
| `readPenPointerMsg()` | 35 | the pressure reader shared by the `WM_PENpressure` monitor and the checkpoint above; touches no Critical state, so the checkpoint no longer switches Critical off on the brush thread (2026-09-02) |
| `uiNativeYesNoPrompt()` | 40 | the Yes/No box behind `askAboutStoppingOperations()` and the force-exit branch of `byeByeRoutine()`: a DllCall'd `MessageBoxW` owned by PVhwnd, shown with Critical held (saved/restored), so nothing queued runs while it is up. AHK's own `MsgBox` lifts Critical for its lifetime (`DIALOG_PREP`, window.cpp) and its pump runs every pending timer/MT_post relay/g-label - a queued `ResetImgLoadStatus` cleared the busy flags inside the first prompt and after a "No" the gates never reopened (2026-09-03). `askAboutStoppingOperations()` also refuses to nest while `userPendingAbortOperations=1` |

### Native menus and the hook-based menu reader — lib/module-interface.ahk (phase D, `138b6b0` and its fixes)

| function | lines | what it does |
|---|---|---|
| `uiCallWndProc()` | 44 | the WH_CALLWNDPROC callback: sees the SENT menu messages (WM_MENUSELECT, WM_INITMENUPOPUP, WM_ENTER/EXITMENULOOP) that no AHK pseudo-thread can see during a modal menu loop, and routes them to the four functions below |
| `uiMenuSelectTrack()` | 37 | tracks the highlighted item for the reader (announcements are track-only; RButton re-announces) and triggers flyout placement |
| `uiMenuJITrebuild()` | 30 | rebuilds a bar dropdown's content just-in-time at WM_INITMENUPOPUP via the `menuJITmap` (HMENU → builder); menu-bar sessions only, busy-guarded |
| `uiMenuLoopEnter()` | 35 | menu-session start: session type from the ENTERMENULOOP wParam, the two native TIMERPROC tickers, the WH_MOUSE_LL hook |
| `uiMenuLoopExit()` | 31 | menu-session end: kills the tickers and the hook, arms the 350 ms flyout grace, schedules the self-healing pass |
| `uiMenuMouseLL()` | 44 | the WH_MOUSE_LL callback active only during menus: eats wheel notches and posts the equivalent arrow keys, balanced RButton down/up re-announce with hit-testing, flyout placement |
| `uiMenuNativeTick()` | 15 | the TIMERPROC fired by the modal loop itself (AHK timers never tick there): calls flyout placement and auto-hides the reader OSD tooltip after its deadline |
| `uiTryPlaceFlyout()` | 48 | positions the S/T/M flyout beside the root popup, found by HMENU identity through MN_GETHMENU so a fading ghost window cannot capture it (`826986b`) |
| `uiRefreshBarAttachments()` | 41 | self-healing pass after every menu loop: re-resolves each bar attachment by name, repairs changed handles, rebuilds the JIT map (`f6a3b99`) |
| `uiMenuNameForBuilder()` | 12 | maps a menu-builder function name to the menu name it builds, for the attachment repair above |

### Queued-call facades — phase B/C

| function | file | lines | what it does |
|---|---|---|---|
| `MT_post(funcName, args*)` | lib/module-interface.ahk | 4 | module-side queued call: binds the target and its arguments to `IF_postRelay` on a one-shot timer, preserving the old cross-interpreter "runs when the receiver pumps" semantics (`5d32ff5`) |
| `IF_post(funcName, args*)` | quick-picto-viewer.ahk | 6 | the main-side twin of `MT_post` (kept by request, see section 7-B) (`5d32ff5`) |
| `IF_postRelay(funcName, args)` | quick-picto-viewer.ahk | 25 | the relay both posts run through: hoists the bound arguments into plain locals and dispatches on their count — the runtime rejects `args*` and `args[N]` inside call arguments (`c629bc2`) |

### SQLite abort hatch — quick-picto-viewer.ahk (phase D3, `2bc4cb1`)

| function | lines | what it does |
|---|---|---|
| `armSQLiteAbortHandler(dbObj)` | 14 | installed `sqlite3_progress_handler` on every connection `Class_SQLiteDB.OpenDB` opens. *Moved into the class on 2026-09-02 as `SQLiteDB.ArmAbortHandler(CallbackFunc, Opcodes)`; `OpenDB` arms the class-wide `SQLiteDB.AbortCallback`, which the main script sets to `sqliteAbortProgressCB` at startup* |
| `sqliteAbortProgressCB()` | 14 | the progress callback: during long operations, Escape or the abort flag makes SQLite interrupt the running statement — the hatch the interface thread used to provide |

Also on 2026-09-02, per Marius: the seven `SQLstmt*` raw-handle helpers that lived in the main
script next to `addSQLdbEntry()` (prepare / finalize / step / reset / bind int, double, text — not
merge additions, they predate it) were folded into the class's statement object: `Prepare()` +
`_Statement.BindInt64/BindDouble/BindText/Step/Reset/Free`. `SaveDBfilesList` and
`SQLdbStoreFilesListEntry` now go through that object; `CloseDB()` finalizes `Prepare()`'d
statements as well, `Free()` will not finalize a handle twice, `Bind()` can reach its Int64/Null
branches and binds Int64 as 64-bit, and `_ErrMsg()` reads the message at the pointer.

Footnotes. (1) Added on the branch and gone again: the variable facades `IF_set`, `IF_get`,
`MT_set`, `MT_get` (phase B, retired at phase E for plain globals), the direct-call facade
`IF_call` (retired in section 7), and `pumpUIevents` (the full Critical-off pump, deleted after it
let queued canvas rebuilds run inside the thumbnails loop). (2) `merge-probes/` holds thirteen
standalone probe scripts (p1–p13) with a README of verdicts; they established what runs during a
same-interpreter menu loop and are not part of the application. (3) Retired 2026-09-02,
pre-merge code rather than branch additions: the dormant `applyFilter` width-fit branch of
`BuildMenuBar` (it arrived in 6.0 alpha 2 and no caller ever enabled it) together with its
single-use helpers `simpleGetMenuItemRect` and `MenuBonusOptions`, the `hMenuBar` super-global
only that branch read, and the two pass-through parameters of `uiKmenu`.

## Appendix — reproducing the numbers

Parse column-0 `name(...)` definitions (body to the next column-0 `}`) from
`git show master:lib/module-interface.ahk`, `git show a850285:lib/module-interface.ahk`,
HEAD's `lib/module-interface.ahk`, and from `quick-picto-viewer.ahk` + `lib/*.ahk` at master
and HEAD. Collisions = master module names ∩ master main/lib names (58). A collision is a
rename when the name is absent from the phase-A module and `ui` + name is present (26); the
rest kept their name (32). Similarities and reference counts as described at the top.
