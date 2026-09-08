# stopSlideshow() + stopGIFsPlayback() → stopGifORslidesPlayback() (2026-09-08)

Scope: every function in the live sources (`quick-picto-viewer.ahk`, `lib/module-interface.ahk`)
that called both `stopSlideshow()` and `stopGIFsPlayback()`. The stale copies under
`.claude/worktrees/` were ignored. Branch `interface-thread-merge-phase-c`, working tree on top
of `545573a`.

Result: **30 functions changed, all in `quick-picto-viewer.ahk`** (30 insertions, 60 deletions).
Two functions that call both were deliberately left alone (`GuiGDIupdaterResize` and the helper
itself); see "Not touched". No DLL change, no comment added.

## Why this is not a pure rename

The pairs are one day old. Commit `993d5b3` (2026-09-07, "more clean-ups") turned
`If (slideShowRunning=1) ToggleSlideShowu()` + `DestroyGIFuWin()` into the bare
`stopSlideshow()` + `stopGIFsPlayback()` pair at every site, and in the same commit renamed the
interface thread's `stopPlayback()` to `stopGifORslidesPlayback()`. The helper
(`lib/module-interface.ahk:2202`) is:

```
stopGifORslidesPlayback(loudly:=0) {
   wasPlaying := 0
   If (slideShowRunning=1)
   {
      stopSlideshow(0, !loudly)
      wasPlaying := 1
   }
   If (animGIFplaying!=0)
   {
      stopGIFsPlayback()
      wasPlaying := 1
   }
   If wasPlaying
      lastOtherWinClose := A_TickCount
   Return wasPlaying
}
```

Compared with the bare pair, a `stopGifORslidesPlayback()` call differs in five ways:

| # | difference | weight |
|---|---|---|
| 1 | **Stamps `lastOtherWinClose := A_TickCount` whenever anything was playing.** The pair never did. The stamp is the app-wide "a window just closed, debounce input" mark; its readers are listed below. | the only one that changes behaviour |
| 2 | Fixed order: slideshow first, GIF second. 12 of the 30 sites had GIF first. | none (see "Order") |
| 3 | `wasPlaying` (and so the stamp) is set for the GIF branch even when `stopGIFsPlayback()` bails on `mustPreventMenus=1` or `simulateMenusMode=1`. | edge case, recorded |
| 4 | Returns `wasPlaying`; the bare replacement discards it. | none |
| 5 | `stopSlideshow()` logs `"QPV: MERGE: stopSlideshow via " Exception("", -2).What`; that name is now `stopGifORslidesPlayback` at all 30 sites instead of the real caller. | DebugView trace loses one level; the helper was not changed (out of scope) |

`stopSlideshow()` with no arguments is `stopSlideshow(0, 1)` (silent, since `993d5b3` changed the
default) and the helper's default `loudly:=0` produces exactly `stopSlideshow(0, 1)`; the
silent-vs-loud behaviour is unchanged at every site. Both callees keep their own early-return
guards (`slideShowRunning!=1`, `animGIFplaying=0`), so the helper's outer `If`s add no condition.
`slideShowRunning`, `animGIFplaying` and `lastOtherWinClose` are all in the main super-global
block (`quick-picto-viewer.ahk:107/110/139`), so the helper's writes reach the real globals.

### Order

`animGIFplaying` only ever holds 0 or 1 (five assignments, all `:= 0` or `:= 1`: lines 107, 12244, 12262,
12273, 63479; the `<=0` test in `autoChangeDesiredFrame` is defensive). Neither stop disposes or
swaps a bitmap: `autoChangeDesiredFrame("stop")` only kills its timer, latches `prevAnimGIFwas`,
zeroes the flag and calls `ResetImgLoadStatus()`. The single order-dependent effect is inside
`ResetImgLoadStatus()`: it returns early while `slideShowRunning=1 || animGIFplaying=1`, so with
GIF-first and **both** playing, the synchronous call inside the GIF stop did nothing and the
work (`uiChangeMcursor("normal-extra")`, which zeroes `imageLoading`, `runningLongOperation`,
`whileLoopExec`, `lastCloseInvoked`, and re-arms `createGUItoolbar`) ran 15–50 ms later from the
timers both stops arm anyway. With the helper's slideshow-first order that work runs
synchronously inside the call, at a point where the function has not started loading or looping
yet. Same end state; the same timers are armed in both orders.

## Who reads the stamp

| reader | window | effect of a fresh stamp |
|---|---|---|
| `uiWM_KEYDOWN` (`lib/module-interface.ahk:2477`), `uiPreProcessKbdKey` (:2384), `WM_KEYDOWN` (:701), `PreProcessKbdKey` (:586) | 300 ms | on the main window and its viewport children (`dispatchKeyDown` → `isUIrootWin`) every key-down is swallowed (`uiWM_KEYDOWN` returns 0); on panels `WM_KEYDOWN` returns without a value, so the key still reaches the control and only QPV's own shortcut dispatch (`PreProcessKbdKey`) is skipped |
| `byeByeRoutine` (:2121) | 650 ms | the Escape-spam exit countdown (`lastCloseInvoked>3` → `TrueCleanup()`) is skipped |
| `activateMainWin` (:1890) | 500 ms | `colorPickerMustEnd` not raised |
| `ToggleThumbsMode` (:4792) | 190 ms | **the toggle itself returns early** |
| `processDefaultKbdCombos` (:1726, :1808) | 350 / 250 ms | Space → play-slides and Enter → thumbnails not dispatched |
| `decideBlockKbdKeys` (:654/:656), `KeyboardResponder` (:763/:858) | 150 / 300 ms | Ctrl+F4 / AppsKey / Enter inside a panel ignored |
| `tlbrInvokeFunction` (:101471) | 250 ms | toolbar click ignored |
| `selectFileLongTap` (:6494) | 350 ms | long-tap select in thumbnails ignored |
| `PerformVectorShapeActions` (:8036) | 250 ms | treated like `setStart` |
| `ActFloodFillNow` / `ActPaintBrushNow` / `ActDrawAlphaMaskBrushNow` (:77762/:77917/:78678) | 450 ms | paint stroke ignored |
| `fdTreeGuiaGuiEscape` (:30625), `QuickMenuSearchGUIAGuiEscape` (:42076) | 400 ms | Escape in those two panels ignored |
| `WM_MOUSEMOVE` (:104979), `DelayedToolbarTooltips` (:104901) | 350 ms | tooltips suppressed |

The stamp therefore only matters at a site if (a) playback can actually be active when the
function runs and (b) something within ~650 ms afterwards consults it. During playback the
interface layer already intercepts the gesture inputs before they reach any of these functions:
Escape/Enter/Space and Left/Right/Up/Down/PgUp/PgDn/Home/End/BackSpace/Delete stop the playback
and nothing else (`uiPreProcessKbdKey`), as do left/middle/double/right clicks and the wheel
(`uiWM_LBUTTONDOWN`, `WM_MBUTTONDOWN`, `WM_LBUTTON_DBL`, `WM_RBUTTONUP`, `WM_MOUSEWHEEL`). What
still reaches the functions below with playback running: menu-bar entries, modifier shortcuts
(Ctrl+C, Ctrl+V, Ctrl+A, Shift/Ctrl+Up/Down, AppsKey, …), programmatic callers, and slideshow
ticks. `DeletePicture()` (:40240) already used the helper as a gate before this change and was
not touched.

## Rule applied to split pairs

A pair was merged when both calls sit on the same control-flow path, and the merged call was
placed at the position of the **first** call. Four sites had the two calls apart:

- merged when the statements between them are independent of playback state
  (`ToggleEditImgSelection`), when the intervening early return is provably dead
  (`changeDesiredFrame`), when the only difference is that the second stop now also covers an
  error return (`MainPanelTransformArea`), or when the conditional second stop is made redundant
  by a mechanism that would stop the same playback within one timer tick anyway
  (`createSettingsGUI`);
- **not** merged when the two calls encode different conditions on purpose and the merge would
  alter a path (`GuiGDIupdaterResize`: the slideshow stop belongs to the no-image branch only).

One site needed the merged call moved (`ToggleThumbsMode`, below).

## Touched functions

"Playback possible" = can the function run while a slideshow or GIF is active, i.e. does the
helper ever return 1 (and stamp) there. Where it cannot, the edit is byte-identical at run time.
Old lines are HEAD (`545573a`) line numbers, new lines are the working tree. Line numbers elsewhere in this report are working-tree numbers unless marked old.

| # | function | old lines (order) | new line | playback possible when reached | stamp consequence |
|---|---|---|---|---|---|
| 1 | `OpenThisFileMenu` | 2911–2912 (S,G) | 2911 | yes, "Open with" menu entry | 300 ms key debounce before the native popup; harmless |
| 2 | `CalculateSelectedFilesSizes` | 3421–3422 (G,S) | 3420 | yes, menu, needs a selection | none reachable; the long loop follows |
| 3 | `CopyImagePath` | 3505–3506 (G,S) | 3503 | yes, menu/shortcut | none |
| 4 | `CopyMoveFilesExplorer` | 3633–3634 (G,S) | 3630 | yes, menu/shortcut | none |
| 5 | `CopyImage2clip` | 3725–3726 (G,S) | 3721 | yes, Ctrl+C / menu | none; `useGdiBitmap()` is read before the stop, bitmaps untouched |
| 6 | `CopyAlphaMask2clippy` | 3948–3949 (G,S) | 3943 | yes, menu | none |
| 7 | `SetImageAsAlphaMask` | 4123–4124 (G,S) | 4117 | yes, menu | none |
| 8 | `FirstPicture` | 4361–4362 (G,S) | 4354 | menu only (Home is intercepted) | none; the save prompt is human-timed |
| 9 | `LastPicture` | 4377–4378 (G,S) | 4369 | menu only (End is intercepted) | none |
| 10 | `TrueCleanup` | 4441–4442 (G,S) | 4432 | **no**: every caller (`exitAppu`, `restartAppu`, `byeByeRoutine` after its own stop and the 650 ms check, the `doCleanup` label) reaches it after a stop | byte-identical |
| 11 | `ToggleThumbsMode` | 4799–4800 (G,S) | 4798, **moved below the 190 ms guard** | yes, menu entry and programmatic callers (Enter/End/middle-click are intercepted) | see below |
| 12 | `UpdateThumbsScreen` | 5242–5243 (S,G) | 5231 | **no** in practice: thumbnails mode only; the GIF timer stops itself when `thumbsDisplaying=1`, and the slideshow starters (`MenuGoPlaySlidesNow`, `StartSlideINtotalTimeBTNaction`) leave thumbnails mode first | byte-identical |
| 13 | `changeDesiredFrame` | 12184 (S) … 12188 (G) | 12172 | yes, Shift/Ctrl+Up/Down, `PanIMGonScreen`, PDF panel buttons | **one-time 300 ms pause in held-key stepping**, see "Behaviour changes" |
| 14 | `PasteClipboardIMG` | 25275–25276 (S,G) | 25262 | yes, Ctrl+V | none |
| 15 | `createSettingsGUI` | 27838 (S) … 27877 (G, live-editor branch only) | 27824 | yes, every panel opener | stamp at panel open when something was playing; typing into the panel is unaffected (panel key-downs are not swallowed, see the readers table), only the app shortcuts and Ctrl+F4/AppsKey/Enter handling pause for 150–300 ms, before the panel is even visible |
| 16 | `PanelFoldersTree` | 30434–30435 (S,G) | 30419 | yes | the tree's own Escape guard is 400 ms after the stamp; not reachable |
| 17 | `PanelQuickSearchMenuOptions` | 41514–41515 (S,G) | 41498 | yes | same, 400 ms |
| 18 | `BrowseReplaceIndexEntry` | 42797–42798 (S,G) | 42780 | **no** in practice: only called from a button of the update-index panel, whose `createSettingsGUI` already stopped both | byte-identical |
| 19 | `fakeWinCreator` | 46176–46177 (S,G) | 46158 | yes, pseudo-panel opener | as 15; no real panel window here, so only the 300 ms main-window shortcut pause applies |
| 20 | `MainPanelTransformArea` | 47524 (S) … 47530 (G) | 47505 | yes, with an active selection | none; GIF now also stops on the out-of-bounds error path |
| 21 | `SaveClipboardImage` | 58623–58624 (G,S) | 58603 | yes, menu/shortcut | none, a file dialog follows |
| 22 | `addNewFile2list` | 63561–63562 (S,G) | 63540 | yes, menu | none, a file dialog follows |
| 23 | `GuiDroppedFiles` | 64534–64535 (S,G) | 64512 | **no**: `dummyTimerProcessDroppedFiles` ran the helper first; `initializeAppWithGivenArguments` runs at start-up | byte-identical |
| 24 | `closeDocuments` | 65078–65079 (S,G) | 65055 | yes, menu | none; the 700 ms re-entry sees nothing playing |
| 25 | `restartAppu` | 65105–65106 (S,G) | 65081 | yes, menu | none |
| 26 | `exitAppu` | 65129–65130 (S,G) | 65104 | yes, menu; from `byeByeRoutine` only after its own stop | none |
| 27 | `InitGuiContextMenu` | 65184–65185 (S,G) | 65158 | yes via AppsKey/Shift+F10 (`appsk`/`extern`/`forced`); right-click is intercepted | none; the popup menu is native and human-timed |
| 28 | `coreShowTheImage` (minimized-window branch) | 73594–73595 (S,G) | 73567 | yes, a slideshow tick while `PVhwnd` is minimized | 300 ms key debounce on a minimized window; harmless |
| 29 | `ToggleEditImgSelection` | 82612 (S) … 82619 (G) | 82584 | yes, shortcut/menu | paint-tool readers are 450 ms; a stroke needs a click first |
| 30 | `selectEntireImage` | 82705–82706 (G,S) | 82676 | yes, Ctrl+A / menu | none |

## The non-adjacent merges, before and after

### ToggleThumbsMode (moved)

The function reads the stamp itself four lines after the pair. Left in place, the merged call
would stamp whenever playback was active and the guard would return before toggling, so a menu
"list view" during a slideshow would stop the show and never open the thumbnails. Seven
programmatic callers (`PanelPrintImage`, `StartSlideINtotalTimeBTNaction`, `PanelAutoColors`,
`MenuPreviewFramesFilterList` ×2, `PanelImgAutoCrop`, `MenuGoPlaySlidesNow`) and
`MenuDummyToggleThumbsMode()` reset `lastOtherWinClose` to 1 or 5 right before calling it, which
confirms the guard's purpose and that a fresh stamp defeats them.

```
before                                              after
   stopGIFsPlayback()                                  If (soloSliderWinVisible=1)
   stopSlideshow()                                        destroySoloSliderWidget()
   If (soloSliderWinVisible=1)
      destroySoloSliderWidget()                        If (A_TickCount - lastInvoked<190) || (A_TickCount - lastOtherWinClose<190)
                                                       {
   If (A_TickCount - lastInvoked<190) || (…<190)          lastInvoked := A_TickCount
   {                                                      Return
      lastInvoked := A_TickCount                       }
      Return
   }                                                   stopGifORslidesPlayback()
                                                       mouseTurnOFFtooltip()
   mouseTurnOFFtooltip()
```

`destroySoloSliderWidget()` does not write the stamp (checked), so the guard sees the same
values as before. Residual difference: when the guard trips (a second call within 190 ms, or a
call within 190 ms of a window close) the playback is no longer stopped; before, it was stopped
and the toggle still did not happen. Whenever the toggle happened before, it happens now.

### changeDesiredFrame

```
before                                                     after
   stopSlideshow()                                            stopGifORslidesPlayback()
   If askAboutFileSave(" and the current image frame…")       If askAboutFileSave(" and the current image frame…")
      Return                                                     Return
                                                              resetSlideshowTimer()
   stopGIFsPlayback()
   resetSlideshowTimer()
```

The `Return` between the two calls is dead: `askAboutFileSave()` only prompts (and only returns
non-zero) when `currentImgModified=1`, and `changeDesiredFrame()` returns four lines earlier on
`currentImgModified=1 || undoLevelsRecorded>0`. So both stops always ran, in the S,G order the
helper uses.

### createSettingsGUI

```
before                                       after
    setLVrowsCount()                             setLVrowsCount()
    stopSlideshow()                              stopGifORslidesPlayback()
    mouseTurnOFFtooltip()                        mouseTurnOFFtooltip()
    …                                            …
    If (imgEditPanelOpened=1)                    If (imgEditPanelOpened=1)
    {                                            {
       …                                            …
       stopGIFsPlayback()                           Gui, SettingsGUIA: Destroy
       Gui, SettingsGUIA: Destroy
```

Before the rename, that second call was `DestroyGIFuWin()`, placed next to the panel's own
`Gui, Destroy` for window-ordering reasons that no longer exist (it is a flag/timer stop now).
For every panel type `AnyWindowOpen := IDwin` is set at the end of this function and the first
branch of `autoChangeDesiredFrame()` stops the GIF at its next tick when `AnyWindowOpen` is
truthy, latching `prevAnimGIFwas` exactly as `stopGIFsPlayback()` does. Concrete deltas: the GIF
now stops synchronously at panel open for every panel instead of within one frame delay, and
the stamp fires at panel open when something was playing.

### MainPanelTransformArea

```
before                                       after
    calcScreenLimits()                           calcScreenLimits()
    stopSlideshow()                              stopGifORslidesPlayback()
    If throwErrorSelectionOutsideBounds()        If throwErrorSelectionOutsideBounds()
       Return                                       Return
                                                 PasteInPlaceRevealOriginal := 0
    PasteInPlaceRevealOriginal := 0              openingPanelNow := 1
    openingPanelNow := 1                         changeMcursor()
    stopGIFsPlayback()
    changeMcursor()
```

The GIF now also stops when the selection is outside the image bounds (the error tooltip path);
before, only the slideshow stopped there. The GIF stop path does not read `openingPanelNow`, so
running it before that assignment changes nothing.

### ToggleEditImgSelection

```
before                                                  after
  stopSlideshow()                                         stopGifORslidesPlayback()
  vpWinClientSize(mainWidth, mainHeight)                  vpWinClientSize(mainWidth, mainHeight)
  trGdip_GetImageDimensions(useGdiBitmap(), imgW, imgH)   trGdip_GetImageDimensions(useGdiBitmap(), imgW, imgH)
  If (!imgW || !imgH)                                     If (!imgW || !imgH)
     r := -1                                                 r := -1
  ; fnOutputDebug(…)                                      ; fnOutputDebug(…)
  stopGIFsPlayback()                                      If (editingSelectionNow!=1 && r!=-1)
  If (editingSelectionNow!=1 && r!=-1)
```

`useGdiBitmap()` returns `gdiBitmap` or `UserMemBMP`; the GIF stop touches neither, so the
dimensions read between the two old calls are the same either way. `selectEntireImage()` already
stopped both before its own `useGdiBitmap()` read.

## Not touched

| where | why |
|---|---|
| `GuiGDIupdaterResize` (:85444; calls at :85464 and :85471, old 85494/85501) | not a pair: `stopGIFsPlayback()` is unconditional, `stopSlideshow()` sits in the no-image / welcome-screen branch only, and `resetSlideshowTimer()` between them exists so a running slideshow survives a resize when an image is loaded. Its only live caller, `PVwinGuiSize()` (`lib/module-interface.ahk:1912`), already calls `stopGifORslidesPlayback()` first, so both calls are no-ops on that path; the `SetTimer, GuiGDIupdaterResize, Off` lines at :63468/:63515 never arm it. Merging would only change a path that nothing reaches today. |
| `uiPreProcessKbdKey` (`lib/module-interface.ahk:2415/2420`) | calls the helper in one branch and `stopGIFsPlayback()` alone in the else-branch; never `stopSlideshow()` |
| `coreShowTheImage` error branches (:73624, :73670) | GIF-only stops; the slideshow is deliberately kept alive there with `scheduleNextSlide()` |
| `stopGifORslidesPlayback` itself | the definition |
| `DeletePicture` (:40240) | already used the helper (as a gate: stop and return) |
| `processDefaultKbdCombos` (:2026/:2037) | dispatch-table strings `["stopGIFsPlayback"]`, not calls; no slideshow entry pairs with them |
| the 40 other functions with a lone `stopSlideshow()` call (two of them with explicit arguments) and the 6 with a lone `stopGIFsPlayback()` (`BtnCreateNewImage`, `BuildSecondMenu`, `CloseWindow`, `markThisFileNow`, `QPV_ShowImgonGui`, `QPV_ShowThumbnails`) | out of scope |

## Behaviour changes to be aware of, ranked

1. **`changeDesiredFrame` with a held key.** Shift+Up/Down and Ctrl+Up/Down are not in the
   interface layer's intercept list, so during GIF playback the first auto-repeat press reaches
   the function, stops the GIF and now stamps; `uiWM_KEYDOWN` then swallows the repeats for
   300 ms before stepping resumes. Before the change, stepping continued without the pause. Once
   only, and only when a GIF (or slideshow) was actually running. Plain Up/Down are intercepted
   and unaffected. The delta is smaller than 300 ms: the first step's `RefreshImageFile` reload
   raises `imageLoading` (`setImageLoading()` in `ResizeImageGDIwin`, no longer short-circuited
   once nothing plays) and `uiWM_KEYDOWN` already drops key-downs while `imageLoading=1` with
   nothing playing, so held-key stepping was already gated per frame load; what is new is the
   300 ms window minus that first reload.
2. **`createSettingsGUI`:** GIF stops synchronously for every panel type (was: at the next
   frame tick for non-live-editor panels); stamp at panel open when something was playing.
3. **`MainPanelTransformArea`:** the GIF also stops on the selection-out-of-bounds error return.
4. **`ToggleThumbsMode`:** when its 190 ms guard trips, playback is no longer stopped as a side
   effect of a toggle that did not happen.
5. **Both playing at once** (slideshow over an animated GIF): the busy-flag reset in
   `ResetImgLoadStatus()` runs synchronously inside the helper instead of 15–50 ms later from the
   timers; the timers are still armed as before.
6. **DebugView:** `stopSlideshow via stopGifORslidesPlayback` at all 30 sites; the real caller
   is one frame further up. Fixing that means changing the helper, which was out of scope.
7. `mustPreventMenus=1` or `simulateMenusMode=1` with a GIF flagged as playing: the helper
   reports `wasPlaying` and stamps although `stopGIFsPlayback()` returned without stopping.
   Same as at the helper's pre-existing interface-side callers.

## Verification (no AHK runtime on this machine)

- Brace delta of `quick-picto-viewer.ahk` unchanged (1 before, 1 after); file keeps its UTF-8
  BOM and LF endings; 30 insertions, 60 deletions.
- `stopGifORslidesPlayback(` occurrences: 1 → 31 in `quick-picto-viewer.ahk` (+30, one per
  function); `lib/module-interface.ahk` untouched.
- A function-boundary scan of both files after the edit finds exactly two functions still
  calling both names: the helper's own body and `GuiGDIupdaterResize`.
- Every replaced line was content-checked before replacement, and each pair was checked to have
  no column-0 line between its two calls (same function).
- `git diff quick-picto-viewer.ahk` is the full change set.

## Out of scope, noticed on the way

The `SetTimer, ResetImgLoadStatus, -15/-50` arms in `stopSlideshow()` and in the GIF stop fire
during whatever the calling function does next; in a non-`Critical` function that then starts a
long loop, `uiChangeMcursor("normal-extra")` zeroes `runningLongOperation`, `whileLoopExec` and
`imageLoading` ~15 ms in. This is identical with the pair and with the helper and was not traced
further (the loops may re-assert those flags through their own `changeMcursor()` calls).
