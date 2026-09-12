# Analysis of 7f5d020 "moar work on keyboard input stuff"

Written 2026-09-12 against HEAD `7f5d020` on `interface-thread-merge-phase-c` (the commit
carries a +0300 timestamp of 2026-09-13 00:06). Static
analysis only; nothing was run on Windows. Line numbers are those of the committed files
(`quick-picto-viewer.ahk` = "main", `lib/module-interface.ahk` = "module"). Since phase C
both files are one interpreter, so functions moving between them is organisation only.

Shorthand used below: **the abort helper** = `determineTerminateOperation()` (main 35280),
the function every cancellable loop calls to learn whether the user asked it to stop; **the
busy flags** = `imageLoading` and `runningLongOperation`; **the load flag** =
`canCancelImageLoad`; **the stop keys** = the 15 keys the new playback branch (module 2314)
treats as "stop the GIF/slideshow".

## What the commit changes

1. **The phase-C liveness shim is gone.** `drainUIinput()` is deleted (module, 98 lines) and
   so are all eight of its call sites, the `abortImgLoad` snapshot locals that went with them,
   and the `alterFilesIndex` super-global. Loops now read the live globals directly.
2. **`ProcessCriticalKeys()` is rewritten** (module 2288). New shape: a `"give-back"` mode
   that hands its repeat counter to `PreProcessKbdKey()`, a 40 ms self-throttle, a
   `closeMode` escape hatch for the window-check, one playback branch that captures every
   key while a GIF or slideshow runs, and a default `Else callMain := 1` fall-through.
   `"win-close"` is no longer rewritten to `"Escape"` — it is matched alongside it, which
   fixes A1 of the 3d828e1 report (title-bar X in thumbs mode).
3. **The load flag is guarded.** All seven ui write sites became
   `canCancelImageLoad := (canCancelImageLoad=1) ? 4 : 0`, and it is now armed at the top of
   `CloneScreenMainBMP()` (main 75109) instead of past the cache-hit returns.
4. **Thumbnail paging** lost its scroll-abandon path (`alterFilesIndex`, `userScrolled`,
   the `ForceRefreshNowThumbsList` retry) and gained `doStartLongOpDance("no")` around the
   paint loop (main 84574) plus a direct `ResetImgLoadStatus()` instead of a -25 ms timer.
5. **Function moves.** The mouse-tooltip family (`mouseCreateOSDinfoLine`,
   `showOSDinfoLineNow`, `adjustWin2MonLimits`, `destroyMouseGuiTooltipu`,
   `mouseTurnOFFtooltip`) main → module; `stopGifORslidesPlayback()` and
   `theSlideShowCore()` module → main; the `mouseToolTipGuia` Close/Escape labels main-side.
6. Smaller items: wheel throttle 200 → 70 ms; the menu-cancels-the-picker call commented out;
   `showThisMenu()` stamps `lastOtherWinClose` without the +100; a busy tooltip on rejected
   drops; the HUD "usePrevious" indicator deleted; `Shit` → `Shift` typo fix.

## A. Defects certain from the code

### A1. The abort helper always returns blank — every cancellable loop is now un-stoppable

```ahk
determineTerminateOperation() {          ; main 35280
  Static lastInvoked := 1
  executingCanceableOperation := A_TickCount
  If (A_TickCount - lastInvoked < 200)
     Return 0
  lastInvoked := A_TickCount
  If mustAbandonCurrentOperations
     lastLongOperationAbort := A_TickCount
  Return theEnd                          ; main 35289
}
```

The commit deleted `theEnd := mustAbandonCurrentOperations` along with the `drainUIinput()`
call above it, but kept `Return theEnd`. `theEnd` now occurs exactly once in the whole tree
and is declared in no `Global` block, so it is a fresh empty function-local on every call:
the helper returns `""` whenever the 200 ms throttle lets it past, and `0` otherwise.

Blast radius: ~110 call sites, all of the form `If (determineTerminateOperation()=1)` or
`If determineTerminateOperation()`. `""=1` is false and `""` is falsy, so **no loop in the
application can be aborted any more**. `mustAbandonCurrentOperations` is read nowhere else —
only at main 35287 and at the two prompt guards that decide whether to *raise* the prompt
(module 1481, 2030) — so no loop that goes through the helper can stop. Nor does anything route around it: the
duplicates engine's SQLite interrupt (`dupesEngineCancel()` → `dupesProgressCB`, DLL
`dupes-search.h:1680`) is itself reached only from `If (determineTerminateOperation()=1)`
at main 86394, the rest of its call sites being error and shutdown paths.

Worse than a plain no-op: line 35288 still stamps `lastLongOperationAbort`, so the guards that
test it (main 10146, 96399) believe an abort has just happened while the loop keeps running.

Repro: start any long operation (find duplicates, a large folder scan, a thumbnails page),
click in the viewport after 900 ms, answer **Yes** to "do you want to stop the current
operation?". `mustAbandonCurrentOperations` is set, the prompt closes, the operation runs to
completion.

Fix: `Return mustAbandonCurrentOperations`.

### A2. `isSpaceOkay` ternary is missing its colon — Space no longer shows the pan cursor

```ahk
isSpaceOkay := (!AnyWindowOpen || imgEditPanelOpened=1) ? 1 0     ; module 2302
```

This is not a load-time error. AHK v1 only reports `A ":" is missing its "?"`; an unmatched
`?` survives `ExpressionToPostfix` (`script.cpp`, the `SYM_INVALID` case falls through to
`standard_pop_into_postfix`). At run time `script_expression.cpp:730` catches it:

```c
if (this_token.symbol == SYM_IFF_THEN)
{
    if (!this_token.circuit_token) // ... syntax errors such as "1 ? 2" (no matching else)
        goto abnormal_end;
```

`abnormal_end` leaves `result_to_return` at its default `""` and assigns silently — no error
box, no `ErrorLevel`. So when the condition is true the variable gets `""`; when it is false
the THEN branch is discarded and the stack ends empty, which trips the `stack_count != 1`
test at `script_expression.cpp:1504` and also lands on `abnormal_end`. `isSpaceOkay` is `""`
either way.

Line 2303 then does `(thumbsDisplaying!=1 && isSpaceOkay=1 && ...)`, and `""=1` is false, so
`isSpaceOkay` is **always 0** and the Space branch at module 2323 is unreachable. Space now
falls through to `Else callMain := 1` and is handed to `KeyboardResponder()` instead of
setting the pan cursor.

Fix: `? 1 : 0`. (The added `isImgEditingNow()=1` test is not the problem — it is true
whenever a valid bitmap and path are displayed outside thumbs mode, so it barely narrows the
old condition. It does run `getIDimage()`, `useGdiBitmap()` and `validBMP()` inside a function
`uiWM_KEYDOWN` calls synchronously, which is the kind of lookup the 2026-09-09 rule keeps out
of the dispatchers; `&&` short-circuiting limits it to Space presses.)

### A3. Alt+F4 is dead while a GIF or a fast slideshow plays, and so is every other key

The new playback branch sits *above* the close branch:

```ahk
} Else If (slideShowRunning=1 || animGIFplaying=1)              ; module 2314
{
   If isVarEqualTo(keyu, "Escape","win-close","Enter","Space","Tab","Left","Right","Up","Down","PgUp","PgDn","Home","End","BackSpace","Delete")
      stopGifORslidesPlayback(1)
   Else If (slideShowCadence>=1000 && animGIFplaying=0)
      callMain := 1
} Else If (keyu="Escape" || keyu="win-close" || keyu="!F4" || keyu="Enter" && runningLongOperation=1)
   byeByeRoutine(keyu, 1)                                        ; module 2320-2321
```

`"!F4"` is not one of the stop keys, so during playback it never reaches the close branch.
With `animGIFplaying=1` or a slideshow cadence under 1000 ms it is dropped outright; with a
cadence of 1000 ms or more it takes `callMain := 1` into `KeyboardResponder()`, which has no
`!F4` entry — module 2320 is the **only** place in the tree that matches the string. And
`uiWM_KEYDOWN()` returns 0 for every key, so `DefWindowProc` never turns the WM_SYSKEYDOWN
into SC_CLOSE either. **Alt+F4 does nothing during any GIF or slideshow playback.**

The same branch swallows **every** non-stop key during playback: with an animated GIF on
screen (`animGIFplaying=1`, which is the state for the whole auto-play, main 12301), zoom
keys, rotate, Ctrl+S, the F-keys, letters, custom shortcuts — all return `callMain=0` and are
lost. The old code reached its generic branch for these and set `callMain := 1`.

Before the commit, `"!F4"` skipped the playback branch because that branch only tested
`isVarEqualTo(keyu, "Escape","Enter","Space","Tab")`, so it fell through to the close branch
in every state.

Fix: test `"!F4"` (and, if intended, `"win-close"`) before the playback branch, and let
non-stop keys fall through to `callMain := 1` instead of being dropped.

### A4. A double-click un-cancels a slow image load

`uiWM_LBUTTONDOWN` (module 1312), `WM_MBUTTONDOWN` (1371), `WM_LBUTTON_DBL` (1428),
`PVwinGuiSize` (1872), `PVwinGuiDropFiles` (1891) and `byeByeRoutine` (2009, 2016) all now do

```ahk
canCancelImageLoad := (canCancelImageLoad=1) ? 4 : 0
```

The guard is right in intent — only arm the cancel when a load is actually in flight — but it
also **clears a cancel that is already armed**, because 4 is not 1. Windows delivers
WM_LBUTTONDOWN and then WM_LBUTTONDBLCLK for a double click: the first sets 4, the second
sees 4, takes the `: 0` arm and writes 0. `ResizeImageGDIwin` (main 73709) and
`CloneScreenMainBMP` (75224, 75250) then see 0 and finish the load. Two separate single
clicks a few hundred ms apart do the same.

Fix: `canCancelImageLoad := (canCancelImageLoad>=1) ? 4 : 0`, or leave a 4 alone.

### A5. Thumbnail paging lost its only escape hatch and gained a prompt that does nothing

`doStartLongOpDance("no")` (main 84574) sets `imageLoading := runningLongOperation := 1` for
the whole paint loop. `imageLoading` was already 1 there — `QPV_ShowThumbnails()` calls
`setImageLoading()` at main 84366 — so the page was already deaf to the wheel (module 1092),
to keys (the old final gate tested `imageLoading=1`) and to menus (the hook's busy gate,
module 232). Those three are not new. What `runningLongOperation` adds is:

* `uiWM_LBUTTONDOWN` (module 1314) now raises `askAboutStoppingOperations()` once the page has
  run past 900 ms, and answering **Yes** does nothing, per A1. Before, a click on a
  half-painted grid did nothing at all; now it offers a stop that never arrives.
* `initAppBusyMode()` (module 724) runs per page: it clears `mustAbandonCurrentOperations`,
  `userPendingAbortOperations` and `lastCloseInvoked`, restamps `lastLongOperationStart`, and
  calls `setTaskbarIconState("anim")`, so the taskbar progress indicator drops into
  indeterminate mode on every page turn.
* `ProcessCriticalKeys` ends with `If (runningLongOperation=1 && callMain=1) callMain := 0`
  (module 2334), which is now the only thing blocking keys during a page — see B9.

Separately, the same commit removed the page's only escape hatch: `alterFilesIndex`, the
`lapsOccurred>3` break and the `ForceRefreshNowThumbsList` retry that let a user scroll away
from a slow page. Nothing replaces it, and with A1 unfixed there is no way to leave a page
that is grinding through uncached thumbnails.

The busy-flag pairing itself is sound — `ResetImgLoadStatus()` at main 84955 reaches
`uiChangeMcursor("normal-extra")`, which is what clears both flags (module 1676) — but only
when the left button is up and no playback is running; otherwise it re-arms a -70 ms timer
and the flags stay set a while longer.

### A6. Dead branch in the load-flag test

```ahk
} Else If (canCancelImageLoad=1 && runningLongOperation=0 && !AnyWindowOpen)   ; module 2326
{
   If isVarEqualTo(keyu, "Left","Right","Up","Down","PgUp","PgDn","Home","End","BackSpace","Delete","Enter")
      canCancelImageLoad := 4
   Else If (canCancelImageLoad=0)       ; module 2330 - cannot be true here
      callMain := 1
}
```

The outer test already pins the flag to 1, so the inner `=0` never holds and a non-navigation
key inside this window returns `callMain=0`.

Mostly this reproduces the old behaviour rather than regressing it: the old code's final gate
forced `callMain := 0` whenever `imageLoading=1 && animGIFplaying!=1`, which normally covers
the same window. The exception is `setImageLoading()` (main 73349), which bails without
setting `imageLoading` when `drawingShapeNow=1`, `hasInitSpecialMode=1` or
`liveDrawingBrushTool=1` — in those states the load flag can be 1 while `imageLoading` is 0,
and a key that used to reach the main handler is now dropped. Worth deciding what the branch
was meant to say; `Else callMain := 1` is the likely intent.

## B. Behaviour changes to confirm as intended

**B1. Wheel throttle 200 → 70 ms** (module 1093). Roughly 14 accepted notches per second
instead of 5. This answers B1 of the 3d828e1 report.

**B2. A 40 ms gate on all key dispatch** (module 2294). Keys arriving inside 40 ms of the
previous one return blank and are dropped. Windows' fastest auto-repeat is about 31 chars/s
(~32 ms), so a held navigation key now advances at most 25 times a second and loses roughly
every other repeat at the fastest setting.

**B3. Menus no longer cancel the colour picker or the clone-brush capture** (module 234-235,
commented out). The busy gate still `EndMenu`s the menu, so the menu simply refuses to open
during picking instead of cancelling it. This reverts item 4 of the 3d828e1 change.

**B4. `showThisMenu()` drops the +100** (main 69497): `lastOtherWinClose := A_TickCount`
instead of `A_TickCount + 100`, so the post-menu deaf window is 300 ms rather than ~400 ms.
This answers the second half of A3 in the 3d828e1 report. Dropping the `Global` keyword from
these three assignments is safe — `lastMenuZeit` (main 212), `lastWinDrag` and
`lastOtherWinClose` are all declared super-global already.

**B5. The playback stop-key list grew** from Escape/Enter/Space/Tab to fifteen keys including
every navigation key (module 2316). Pressing Right during a slideshow now stops the show
instead of advancing it.

**B6. Dropped files are refused loudly** (module 1886) and the drop handler, not its timer,
now stops playback and arms the load flag.

**B7. The "usePrevious" HUD indicator is deleted** (main, `drawHUDelements`, the
`mode=2 && imgFxMode=1` centre rectangle), and the touch-margin outline's pen width is
hardcoded `Gdip_SetPenWidth(pPen1d, 0.7)` instead of scaling with `imgHUDbaseUnit//10`. The
outline no longer grows with the HUD size setting.

**B8. `canCancelImageLoad := 1` moved to the top of `CloneScreenMainBMP()`** (main 75109),
ahead of the two cache-hit `Return`s. A click landing in the short window between a cache hit
and `QPV_ShowImgonGui()` (which zeroes the flag, main 81668) now arms a 4, which makes
`ResizeImageGDIwin` take its abort branch at main 73709 — forcing low image quality and
possibly showing "Image processing aborted" on a load that was instant.

**B9. `imageLoading` no longer gates keyboard dispatch.** The old final gate was
`isOkay := (imageLoading=1 && animGIFplaying!=1) ? 0 : 1` combined with `runningLongOperation!=1`
and `whileLoopExec!=1`; the new one (module 2334) tests `runningLongOperation` alone.
`whileLoopExec` is still covered downstream by `PreProcessKbdKey()` (main 598), but
`imageLoading` is checked nowhere in the chain. A key pressed during the rendering half of a
single-image load — `QPV_ShowImgonGui()` zeroes the load flag at main 81668, so A6's branch
does not catch it either — is no longer dropped. It is deferred instead: `PreProcessKbdKey` is
a timer and the load runs under Critical, so the key fires once the load unwinds, and several
keys pressed during one load collapse to the last (one `hotkate` global).

**B10. The abort snapshot is gone.** The loops that read `abortImgLoad` (a value captured right
after a drain) now read `canCancelImageLoad` live, so the value can change between two tests
in the same function. `abortImgLoad>2` became `canCancelImageLoad=4`, which is equivalent —
only 0, 1 and 4 are ever written.

## C. Leftovers and cleanups

* **main 84943** — `pageIsWhole := (!userScrolled && !abandonAll && alterFilesIndex!=1) ? 1 : 0`
  still names two variables that no longer exist. `alterFilesIndex` was dropped from the
  module's `Global` block, so it is now a blank function-local; `userScrolled` is never
  assigned. Both read as blank, so the line is effectively `pageIsWhole := !abandonAll`, which
  is probably what was wanted — but the expression should say so.
* **main 78985** — `thisThick := imgHUDbaseUnit//20` is dead; the next line hardcodes 0.7 and
  the two sibling branches reassign `thisThick` themselves.
* **module 1252** — `destroyMouseGuiTooltipu()` does `WinActivate, ahk_id %lastTippyWin%`, but
  `lastTippyWin` is a `Static` of `mouseCreateOSDinfoLine()`; here it is a blank local. The
  handle it wants is already in `hh` on the line above. Pre-existing, carried over by the
  move, not introduced here.
* The `drainUIinput()` removal itself is not a defect. Its header comment claimed queued input
  had to be hand-fed because a Critical main thread would not process it, but OnMessage
  monitors do launch under Critical (verified earlier against the 1.1 source), so the shim was
  redundant. The problem is that A1 broke the abort path that remained.

## D. Suggested order of fixes

1. A1 — one line, restores every cancel button in the application.
2. A3 — Alt+F4 and all keyboard control during GIF playback.
3. A2 — one character.
4. A4 — one character.
5. A5 — decide whether a thumbnails page should claim `runningLongOperation` at all; if it
   should, the wheel handler needs a path that still advances the page.
6. A6, C — say what was meant.
