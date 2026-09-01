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
| `RepositionTempBtnGui` | `uiRepositionTempBtnGui` | quick-picto-viewer.ahk | main: 35-line positioner; module: 3-line post | 0.03 | 0.03 | 1 / 2 |
| `repositionWindowCenter` | `uiRepositionWindowCenter` | quick-picto-viewer.ahk | main: 136-line general window centering; module: 42-line PVwin-family variant | 0.41 | 0.41 | 1 / 77 |
| `saveMainWinPos` | `uiSaveMainWinPos` | quick-picto-viewer.ahk | main: writes the INI; module: 3-line trigger | 0.18 | 0.18 | 1 / 1 |
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
  `mouseToolTipWinCreated` flag and `lastTippyWin`): `mouseCreateOSDinfoLine` adopted the module's
  OSD font-name/bold preference and margin but keeps main's deliberate no-`Critical` choice and its
  click handler; `showOSDinfoLineNow` was already identical; `mouseTurnOFFtooltip` took the module's
  richer body (statusbar flag, `lastWinDrag` guard, timer disarm) and replaces `uiMouseTurnOFFtooltip`
  at its 14 module sites — one window needs one owner of the destroy, which is why that function
  joined the pass; `mouseClickTurnOFFtooltip`, `destroyTooltipu` and the `uiMouseTipGuia` close/escape
  labels are gone. `hGuiTip` finally has a single owner (both windows used to write it).
- Still open from section 4: the dead Alt+Space emulation trio.

## 5. Reproducing the numbers

Parse column-0 `name(...)` definitions (body to the next column-0 `}`) from
`git show master:lib/module-interface.ahk`, `git show a850285:lib/module-interface.ahk`,
HEAD's `lib/module-interface.ahk`, and from `quick-picto-viewer.ahk` + `lib/*.ahk` at master
and HEAD. Collisions = master module names ∩ master main/lib names (58). A collision is a
rename when the name is absent from the phase-A module and `ui` + name is present (26); the
rest kept their name (32). Similarities and reference counts as described at the top.
