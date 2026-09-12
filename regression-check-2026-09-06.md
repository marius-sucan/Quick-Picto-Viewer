# Regressions in the 2026-09-05/06 commit series (810ea89 → 38f9d65)

Scope: the 14 commits after `de4d387` on `interface-thread-merge-phase-c`:

| commit | author/time | what |
|---|---|---|
| `810ea89` `2ef1b3a` `f6d40e3` | Marius, 09-05 22:44–23:12 | flyout/menu rework and its fixes |
| `f00fbb2` | 09-05 | global-vars audit (doc only) |
| `9f102df` `099ead8` `b6cb261` `e129a02` `bd61f96` | the "-0700" session, 09-05 14:03–15:16 | Consolidate Step 1, slideshows/GIFs, mouse, keyboard |
| `2a7b58d` `2a888ff` `9a038bc` `38f9d65` | Marius, 09-06 00:08–14:28 | handleUIhwnd, MouseMoveResponder revert, menus clean-ups, more clean-ups |

## Status (2026-09-06, updated 2026-09-07)

By section number below. **§1** fixed in `12cdd35` (probe acknowledgement restored as the
`sentMsgProbeSeen` module global; Marius then removed the DLL-path trampoline in `bbe3505`),
then reworked 2026-09-07 in the working tree: the global is gone and the probe's lParam carries
the acknowledgement slot instead — a 4-byte local of `uiInstallSentMsgHook()` whose address is the
probe's lParam, written to 1 by the `0x85EE` branch of `uiCallWndProcWork()` inside the same
`SendMessageW` (the native procedure forwards `cwp->lParam` untouched; a DLL built from the old
argument order delivers wParam = 0 in the message slot, so the branch is never entered and the
probe still fails loudly). The header's callback typedef now names its parameters in the order the
procedure passes them. **§2** fixed in `12cdd35`, as *blocking*: while
`runningLongOperation=1 || imageLoading=1`, `uiCallWndProcWork()` calls `user32\EndMenu` on
`WM_ENTERMENULOOP`/`WM_INITMENUPOPUP`, ignores `WM_MENUSELECT`, still runs `uiMenuLoopExit()`
on `WM_EXITMENULOOP`; `showThisMenu()` returns early under the same condition. **§3** fixed by
Marius in `bbe3505` (`lastContextMenuZeit>300`). **§4** fixed in `29fa885`:
`drainUIinput()` blanks `hotkate` before handing a drained key-down to `uiWM_KEYDOWN()` and
runs `uiPreProcessKbdKey()` only when the handler stored a key, so a declined key can no
longer re-fire the last stored one; the `bd61f96` gate stays and now only ever sees a fresh
key. **§5** fixed in `12cdd35` (`tlbrResetPosition()` returns unless `TouchToolbarGUIcreated=1`).
**§7** fixed in `12cdd35` (comma). The native hook needs `qpvmain.dll` rebuilt from the current
sources (argument order changed in `38f9d65`); until then the install line in DebugView says
"did NOT deliver the probe" and the script hook stays in, by design.
Open: §6, §8 and the nits.

## Method

Read every diff in full and traced each removed relay, timer hop or guard against the
callers that remain at HEAD (not against the commit messages). Structural gates run on
every one of the 14 commits: the brace delta of `quick-picto-viewer.ahk` is 3 throughout
and `lib/module-interface.ahk` is balanced throughout (so nothing changed the parse
balance); none of the 22 symbols deleted in the series (`MT_post`, `IF_post`,
`uiWinClickAction`, `uiKeyboardResponder`, `slideshowsHandler`, `dummySlideshow`,
`menuFlyoutDisplay`, `miniGDIupdater`, `globalMenuOptions`, `menuCurrentIndex`,
`invokeSortListMenu`, …) is referenced anywhere outside `.claude/worktrees`; every
`SetTimer` target in both files still resolves to a function or label.

Seven regressions, one hazard, then the behaviour changes that are not defects but
need a Windows pass, then nits. Line numbers are HEAD (`38f9d65`).

---

## 1. The native CALLWNDPROC hook is never accepted — HIGH (`810ea89`, made worse by `38f9d65`)

`uiInstallSentMsgHook()` still runs the install-time self-test
(`lib/module-interface.ahk:206-208`): it zeroes `sentMsgProbeSeen`, sends `0x85EE` to the
script window and keeps the native hook only `If (sentMsgProbeSeen=1)`. But `810ea89`
deleted the only writer, `sentMsgProbeSeen := 1` in `uiCallWndProcWork()`, together with
the `Global` declaration and its init. The variable is now a function-local of
`uiInstallSentMsgHook()` that is set to 0 and compared to 1. The test cannot pass.

`38f9d65` added a second, independent reason. The new trampoline gate
(`lib/module-interface.ahk:239`, `uiDLLsentMenuMsg`) returns before `uiCallWndProcWork()`
while `runningLongOperation=1 || imageLoading=1`, and the DLL is initialized from
`LoadBitmapForScreen()`, `GetFilesList()`, `OpenFolders()`, `OpenDialogFiles()`,
`ToggleThumbsMode()` — i.e. while one of the two flags is set. The probe is dropped at
the trampoline even if the acknowledgement is restored.

Consequences, every session:

- DebugView prints `native CALLWNDPROC filter did NOT deliver the probe [hook=…] - removed,
  script hook procedure re-installed` at the first image/folder load, and the script
  procedure `uiCallWndProc` (every sent message of the thread) carries the menus for good.
- The clipboard defect fixed by `ad337d2` is back: `Try Clipboard := text` fails every
  other time (the script hook runs a line inside `EmptyClipboard`, see the 2026-09-05
  memory note). The "Copy path" test — two consecutive copies both succeeding — fails again.
- The callback argument-order change in `38f9d65` (`callwndproc-hook.h` now passes
  `message, wParam, lParam, hwnd`; `uiDLLsentMenuMsg(msg, wP, lP, hwnd)`) needs a DLL
  rebuild, and the always-failing probe masks a stale DLL: with either build you land on
  the fallback and see the same DebugView line.

Fix shape (both halves are needed): declare `sentMsgProbeSeen` in the module `Global`
block again and set it to 1 in the `msg=0x85EE` branch of `uiCallWndProcWork()`
(`:279`); move the busy gate out of both trampolines into `uiCallWndProcWork()` *after*
the probe branch — and see §2 for what it should gate.

One-line nit on the fallback (which is what actually runs today): the new `Return 0`
inside `uiCallWndProc` (`:257-258`) for the four menu messages during operations skips
`CallNextHookEx`, unlike every other exit of that procedure.

## 2. Menu messages are dropped for the whole of every image load and long operation — MEDIUM (`38f9d65`)

Both trampolines now drop `WM_INITMENUPOPUP`, `WM_MENUSELECT`, `WM_ENTERMENULOOP` and
`WM_EXITMENULOOP` while `runningLongOperation=1 || imageLoading=1`
(`lib/module-interface.ahk:239`, `:257`). Nothing disables the menu bar during operations
(`initAppBusyMode()` has its `setMenuBarState("Disable")` commented out) and
`WM_RBUTTONUP` does not check `imageLoading`, so these menus are reachable:

- A bar dropdown opened during a load (a big image, a PDF, a RAW) or during a batch, a
  dupes scan, a folder scan, gets no JIT rebuild: it shows whatever its HMENU last held —
  the `building the menu...` placeholder for a dropdown never opened since the last
  `UpdateMenuBar()`, otherwise the items built for the *previous* state.
- `uiMenuLoopEnter()` is skipped, so no `WH_MOUSE_LL` wheel hook, no TIMERPROC ticker,
  no S-T-M flyout and no reader tracking for those menus — bar and context menus alike.
- Hazard, not yet observed: the gate has no self-heal. A stuck `imageLoading=1` (a class the
  merge notes already record) now degrades every menu for the rest of the session, with
  no DebugView line saying why.

If the intent was to keep the JIT builders (they run `deleteMenus()`, `closeQuickSearch()`,
`mouseTurnOFFtooltip()`, file-list reads) out of a running operation, gate only
`uiMenuJITrebuild()` — the session bookkeeping, reader and wheel are harmless and must
keep seeing ENTER/EXIT in pairs.

Windows check: open a folder (bar rebuilt), press Right on a slow image, click `File`
during the load.

## 3. A left-click on the welcome screen no longer opens the file dialog — MEDIUM-HIGH (`f6d40e3`)

`quick-picto-viewer.ahk:10784`, the welcome-screen branch of `WinClickAction()`:

```ahk
If ((A_TickCount - lastWinDrag>300) && (A_TickCount - lastContextMenuZeit<300))
   OpenDialogFiles()
```

`lastContextMenuZeit` is written only when the flyout is placed
(`uiTryPlaceFlyout`, module `:542`) and when a menu closes (`hideMenuFlyoutNow`,
`:69909`); it starts at 1. As written the dialog opens only for a click that lands within
300 ms of a menu closing, and the click that dismisses a popup menu is consumed by the
menu loop, so a plain click — the action the welcome text itself advertises ("Press O key
or Left-Click to open a file or folder") — does nothing. Pre-merge and up to `810ea89` the
condition was `lastWinDrag>300` alone. The other half of the same commit
(`hideMenuFlyoutNow()` added to `OpenDialogFiles()`, `:63502`) suggests the target was a
lingering flyout; if the comparison was meant to *suppress* the dialog right after a
menu, it is inverted (`>300`).

Windows check: start without arguments, left-click the viewport.

## 4. Stale-key abort prompts during long operations — MEDIUM (`bd61f96`)

The "latent bug fix" in `uiPreProcessKbdKey()` changed the dispatch gate
(`lib/module-interface.ahk:2426`) from the never-true `isVarEqualTo(givenKey, …)` to
`isVarEqualTo(hotkate, "Escape", "Enter", "!F4")`, which opens the gate during
`runningLongOperation=1` / `whileLoopExec=1` for those three values. The new branches
behind it — `Escape`/`!F4` → `preByeRoutine()`, `Enter && runningLongOperation=1` →
`preByeRoutine()` (`:2439`) — can only ever see a *stale* `hotkate`:

- `uiWM_KEYDOWN()` handles Escape itself and never stores it, and it returns before
  storing any key while an operation runs (`:2520-2526`), so no real key press during an
  operation writes `hotkate`.
- The panel handler `WM_KEYDOWN()` (`quick-picto-viewer.ahk:696-712`) does store
  `Escape`/`Enter` — closing a panel with Escape or confirming one with Enter leaves that
  value in the global for good.
- `drainUIinput()` calls `uiPreProcessKbdKey()` after *any* drained key-down (`:696-700`),
  and the checkpoints of every Critical loop drain.

Repro: close a panel with Escape (or start a batch from a panel with Enter), then during
the operation press any key with the main window focused → the abort prompt opens for a
key that is not Escape. Press Escape → two prompts in a row (`uiWM_KEYDOWN`'s own
`preByeRoutine()`, then the stale one; `byeByeRoutine`'s 250 ms guard does not cover the
operation branch and `askAboutStoppingOperations()` re-arms after each answer). Before
`bd61f96` the gate was closed during operations, so the stale value was harmless there.

Fix direction: either have `drainUIinput()` pass the drained key instead of relying on the
global, or clear `hotkate` in `uiWM_KEYDOWN()` on the paths that decline a key.

## 5. A blank "QPV toolbar" window flashes at start-up — MEDIUM (`38f9d65`)

`refreshUImainWinElements()` (`quick-picto-viewer.ahk:2679`, called unconditionally at
`:485`) calls `createGUItoolbar()`, which now defers itself in 150 ms steps until
`A_TickCount - scriptStartTime >= 350` (`:104539`), and then arms
`SetTimer, tlbrResetPosition, -100`. `tlbrResetPosition()` (`:104648`) has no
`TouchToolbarGUIcreated` guard and runs `Gui, OSDguiToolbar: Show, NoActivate …, QPV toolbar`
— on a GUI that does not exist yet AutoHotkey creates and shows an empty default window:
caption, sizable frame, taskbar button, titled "QPV toolbar", at the viewport's top-left,
until `CoreGUItoolbar()` destroys and recreates it (`:103681`).

`OpenArgFile()` resets `scriptStartTime` three times (`:63764-63780`), so a
file-association launch hits this almost always; a plain launch hits it when the
auto-execute section finishes within ~250 ms of start. This is the phantom-taskbar-button
class Marius already had fixed once (BuildGUI's `Show, Hide` note).

Fix direction: guard `tlbrResetPosition()` on `TouchToolbarGUIcreated=1`, or arm it from
the end of `createGUItoolbar()` instead of from `refreshUImainWinElements()`.

## 6. Every programmatic slideshow stop now shows the STOPPED tooltip and beeps — MEDIUM-LOW (`099ead8`)

`stopSlideshow()` (`quick-picto-viewer.ahk:10933`) is the single teardown and carries
what used to be split: the "Slideshow: STOPPED / Images seen…" tooltip lived in
`dummyInfoToggleSlideShowu()` (the user toggle) and the sub-950 ms `SoundBeep, 900, 100`
in the module's `turnOffSlideshow()` (viewport gestures). `ToggleSlideShowu()`'s stop
branch (`:11030`) now routes through it, so the ~75 silent `If (slideShowRunning=1)
ToggleSlideShowu()` sites — opening a panel, entering thumbnails mode
(`UpdateThumbsScreen`), `OpenThisFilePropFolder`, `resetSlideshowTimer()`, … — show the
tooltip and, for fast slideshows, block for the 100 ms beep. (Window resizes are
unchanged: `PVwinGuiSize` already went through `turnOffSlideshow()` before this series.)

Fix direction: a `quiet` parameter on `stopSlideshow()` (tooltip and beep only from
`stopPlayback()` and `dummyInfoToggleSlideShowu("stop")`).

## 7. Toolbar context menu placement typo — LOW (`9a038bc`)

`quick-picto-viewer.ahk:58410`: `showThisMenu("PvUItoolbarMenu", 0 givenCoords)` — the
missing comma concatenates, so `forceIT="0tlbr"` and `manubarMode=0`. The menu no longer
anchors under the toolbar button; it opens at the mouse, which for the keyboard toolbar
navigation (`func2Call := ["invokeTlbrContextMenu", "tlbr"]`, `:102699`) is wherever the
pointer happens to be. Every other invoker passes `0, givenCoords`.

## 8. Direct click/mouse-move dispatch from checkpoints — LOW (`e129a02`)

`uiWM_LBUTTONDOWN` and `WM_LBUTTON_DBL` now call `WinClickAction()` synchronously
(`lib/module-interface.ahk:1366`, `:1469-1471`) and `uiWM_MOUSEMOVE` calls
`MouseMoveResponder()` (`:1865`), where the relay used to post. The same four handlers are
what `drainUIinput()` feeds inline under Critical from the loop checkpoints, and the
merge's rule for those was "queued work stays queued until the operation unwinds".
The busy flags protect the common paths (`ResizeImageGDIwin` and `QPV_ShowThumbnails`
both call `setImageLoading()`, `determineTerminateOperation` has `runningLongOperation`,
the colour picker `whileLoopExec`), so the exposure is the modes where
`setImageLoading()` declines: `drawingShapeNow=1` and `liveDrawingBrushTool=1`. There a
click drained by the render's checkpoint (`quick-picto-viewer.ahk:74136`, `:75594`…) runs
`PerformVectorShapeActions()` or `ActFloodFillNow()` in the middle of `coreShowTheImage`
(a point mapped against the half-updated view; a nested `ShowTheImage` inside the render),
and a mouse-move draws the brush outline on `2NDglPG` while the HUD pass is using it.
`WinClickAction()` also opens with `Critical, on`, which now sticks to the monitor thread.

Marius already reverted the same shape once (`2a888ff`, `activateMainWin`). Keep the
direct calls for the OnMessage path and post when entered from a drain (a `draining`
static set by `drainUIinput()` is enough).

---

## Behaviour changes that are not defects — verify on Windows

- **Key repeat** (`bd61f96`): `KeyboardResponder()` runs inside the `uiPreProcessKbdKey`
  timer thread, so a held key launches one responder at a time and the timer cannot
  re-launch until it returns; repeats arriving meanwhile collapse to the last `hotkate`.
  Before, each repeat got its own relay thread. Rapid browsing feels different (no
  interleaved loads).
- **Nav key on a playing GIF** (`b6cb261`): `stopGiFsPlayback()` no longer stamps
  `lastOtherWinClose` (only `stopPlayback()` does), so the 300 ms keyboard lockout after
  the stop is gone: a *held* Right stops the GIF and moves to the next image on the next
  repeat; a tap still only stops it.
- **Flyout debounce** (`9f102df`): one shared 300 ms `lastFlyBtn` for S/T/M instead of one
  per button — S then T within 300 ms drops the second.
- **Post delay** (`9f102df`): the module's `MT_post` was `-10`, everything is `-5` now.
- **Cursor and flags synchronous** (`9a038bc`): `changeMcursor()` calls `uiChangeMcursor()`
  inline; `busy-img` / `normal` / `normal-extra` write `imageLoading`,
  `runningLongOperation`, `mustAbandonCurrentOperations` immediately instead of 5 ms later.
  The three `normal-extra` callers and `setImageLoading()` were checked: none reads the flag
  between the call and the old timer, so no ordering dependence was found.
- **`setMenuBarState()` synchronous** (`9a038bc`): the colour picker and the three
  brush-capture panels now really disable the bar for the capture (the posted Disable used
  to fire after the Critical capture loop, right before the posted Enable).
- **`InfoToggleSlideShowu()` inline** (`099ead8`): the whole start path (incl. the
  `Sleep, 550` for fast cadences and `coreGenerateRandomList()`) now runs under the
  caller's `Critical, on`.
- **`PVwinGuiSize` per event** (`38f9d65`): the `-5/-15 ms` coalescing timer and the
  `lastMenuBarUpdate < 150` guard are gone; `uiUpdateUIctrl(0)` + `GuiGDIupdaterResize()`
  run on every size event (the latter is cheap: timers and a 1950 ms start-up guard).
  `UpdateMenuBar()` detaches/attaches through the placeholder bar, which only sends
  `WM_SIZE` when the bar height changes (bar wrap, toggle) — when it does, the size event
  now also stops a running slideshow and sets `canCancelImageLoad := 4`.
- **Start-up under Critical** (`9f102df`): the module's centering variant was replaced by
  the main `repositionWindowCenter()`, whose first line is `Critical, on`; the rest of the
  auto-execute section (GDI+ init, argument loading, `refreshUImainWinElements`) now runs
  Critical, so GuiSize and timers are deferred to its end. Also its
  `SetTimer, highlightActiveCtrl, -100` draws a 1×1 halo at PVwin's hidden default button
  — invisible.

## Nits

- `showThisMenu()` (`:69861`): `items`, `klop`, `okay`, `idu` are now dead (`prevItems :=
  items` stores blank, `idu := klop[2]` indexes an empty string). The `manubarMode=1`
  branch and its 27 `showThisMenu(…, 0, 1, manuID)` callers are dead code: the builders are
  only entered with `justBuild=1` (JIT) or `"extern"`, and the Alt+letter path that used
  them is intercepted by `uiWM_KEYDOWN`'s SC_KEYMENU post.
- `restartEntireGui()` (`:73107-73113`): `If BuildGUI() handleUIhwnd()` — when a handle is
  missing, `BuildGUI()` returns 0 and the fatal handler in `handleUIhwnd()` is skipped;
  the old string return always reached it.
- `refreshUImainWinElements()` calls `uiAccessWelcomeView()` unconditionally; after a
  file-argument launch (`OpenArgFile` displays synchronously) it stamps the welcome text on
  the five accessibility labels and squashes the scrollbars to 1×1, undone 5 ms later by
  the `uiUpdateUIctrl` that `updateUIctrl()` posted. A flash, not a state.
- `createGUItoolbar()`'s start-up re-arm drops its argument: a `"refresh-later"` /
  `"forced"` / `"state"` call inside the first 350 ms is replaced by a plain call.

## Checked and found neutral

`animGIFplaying` is only ever 0 or 1 (`!=0` vs `=1` is the same test);
`isUIrootWin()` lists exactly the old `dispatchLButtonUp` roots; `uiGetMouseCoords()`
writing `lastLclickX/Y` from right/middle clicks is harmless (both readers run from
`WinClickAction`, which overwrites them first); `scheduleNextSlide()` and the
`SetTimer, theSlideShowCore, -1` force-advance are equivalent to the old post pairs
(`theSlideShowCore`'s `cadence//1.25` gate applied to the "force" call too, and the GIF
branch only fires with `allowNextSlide=1`); `uiTryPlaceFlyout()` inside `showThisMenu`
is a no-op before `Menu, Show` and the ticker is still started by the hook's
`WM_INITMENUPOPUP` branch, so the removal of `menuFlyoutDisplay()` is neutral —
except during loads, see §2; `PanelQuickSearchMenuOptions()` sets its own
`Gui, Default` before its unnamed Gui commands, so calling it from the flyout's
mouse-up thread is safe; `mustPreventMenus`/`simulateMenusMode` are only 1 while the
quick-search index is generated, so the new early return in `stopGiFsPlayback()` cannot
swallow a user click.
