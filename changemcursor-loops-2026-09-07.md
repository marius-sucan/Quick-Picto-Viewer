# changeMcursor() inside loops - quick-picto-viewer.ahk

Snapshot: branch `interface-thread-merge-phase-c` at `00ceb4d`, 2026-09-07.
Scope: `quick-picto-viewer.ahk` only (105,623 lines). Line numbers below refer to that file
unless a path is given.

Out of scope, noted so nobody has to re-check: `lib/module-interface.ahk` defines the callee
`uiChangeMcursor()` but contains no `changeMcursor()` call; `lib/Class_screenQPVimage.ahk:133`
holds one call, in `LoadFreeImageFile()`, not inside a loop. Nothing in the `.ahk` sources was
changed for this report.

## 1. Headline numbers

| What | Count |
|---|---|
| Lines mentioning `changeMcursor` (excluding `uiChangeMcursor`) | 91 |
| Definition | 1 (line 99477) |
| Commented-out calls | 4 (lines 6094, 6120, 35237, 87044) |
| Live call sites | 86 |
| Live call sites that sit inside a loop of the same function | **24, in 21 functions** |
| Bare `changeMcursor()` (throttled "busy") among the 86 | 83 |
| Named calls among the 86 | 3: `"normal"` at 17283 and 99531, `"busy-img"` at 73543 |
| Functions containing at least one call | 60 |
| Loops that call one of those 60 functions directly (depth 1) | 10 sites, 9 functions |
| Loops two calls away (depth 2) | 21 sites, 15 functions |
| Loops at any depth (static reachability, over-approximate) | 109 sites, 68 loops, 60 functions |
| Functions that can reach `changeMcursor()` at all | 973 of 2,508 |

The function itself contains no loop.

## 2. Inside changeMcursor()

```ahk
changeMcursor(whichCursor:=0) {                                                  ; 99477
  Static lastInvoked := 1, prevCursor := "none"
  If ((drawingShapeNow=1 || slideShowRunning=1 || animGIFplaying=1
      || (A_TickCount - zeitSillyPrevent<300) || hasInitSpecialMode=1) && imageLoading!=1)
     Return

  If (whichCursor)
  {
     prevCursor := whichCursor
     uiChangeMcursor(whichCursor)
  } Else If (A_TickCount - lastInvoked > 400)
  {
     uiChangeMcursor("busy")
     lastInvoked := A_TickCount
  }
}
```

### 2.1 The guard

Five conditions mute the call: a shape is being drawn, a slideshow runs, an animated GIF plays,
`hasInitSpecialMode`, or fewer than 300 ms passed since `zeitSillyPrevent` was stamped. The
mute is lifted whenever `imageLoading=1`, which `setImageLoading()` (73538) and
`doStartLongOpDance()` (35278) set before most long loops. `zeitSillyPrevent` is stamped on
every iteration of the interactive drag loops (`panIMGonScrollBar` 5358, `ThumbsScrollbar` 5462,
`simplePanIMGonClick` 5584, `winSwipeAction` 5647, `rescaleSelectedVectorPoints` 8904,
`moveOnePointInVectorPath` 9049, `selectPathPointsInRect` 9176): those loops reach
`changeMcursor()` only indirectly (section 4, depth 2) and the stamp is what keeps the busy
cursor from flashing while the user drags.

### 2.2 Two paths and the 400 ms throttle

- A named cursor (`"normal"`, `"busy-img"`, ...) always goes through to `uiChangeMcursor()`.
  It writes `prevCursor` and does **not** touch `lastInvoked`.
- The bare call asks for `"busy"` but only if more than 400 ms passed since the last bare call
  that went through. Inside a loop this is what makes the call cheap: at most one real cursor
  change per 400 ms, every other iteration costs one boolean expression.
- Consequence of the asymmetry: a `"normal"` call inside the 400 ms window (the pattern of
  `GetImgFileDimension()`, 99525/99531, and of `downscaleHugeImagesForEditing()`, 17283) puts
  the arrow back and the next bare call is still suppressed until the window ends, so the arrow
  can stay up to 400 ms inside an otherwise busy loop.
- A bare call made while the left button is down still stamps `lastInvoked`, but
  `uiChangeMcursor("busy")` refuses to change the cursor while `LbtnDwn=1` (module 1741), so
  after the button is released the busy cursor returns only at the next window.

### 2.3 Statics

`lastInvoked` is written only by the bare path. `prevCursor` is written and never read: a
write-only static, dead since the throttle was written.

### 2.4 The callee chain: uiChangeMcursor() -> setTaskbarIconState() -> COM

`uiChangeMcursor()` (`lib/module-interface.ahk:1716`):

- Five cursor handles are loaded once into statics with `LoadCursorW` on the shared system
  cursors (IDC_WAIT, IDC_ARROW, IDC_HAND, IDC_CROSS, 32649). Shared cursors are never destroyed,
  so nothing leaks no matter how often the function runs.
- Its own guard returns while a slideshow or GIF animation runs.
- Branches: `"normal-extra"` zeroes `userPendingAbortOperations`, `imageLoading`,
  `mustAbandonCurrentOperations`, `runningLongOperation`, `lastCloseInvoked` and calls
  `setTaskbarIconState("normal")`; this is the **only** place in either file that clears
  `runningLongOperation`. `"busy-img"` and `"busy"` call `setTaskbarIconState("anim")`;
  `"busy"` additionally requires `LbtnDwn!=1`. `"normal"` calls `setTaskbarIconState("normal")`.
  `"finger"`, `"move"`, `"cross"` only pick a handle. Anything else returns.
- The pre-assignment `thisCursor := hCursMove` when `lastZeitPanCursor` is younger than 50 ms
  is overwritten by every branch that reaches `SetCursor` (and the remaining branch returns), so
  it is dead code.
- The visible effect is one `DllCall("user32\SetCursor")`.

`setTaskbarIconState()` (module 863) maps `"anim"` to `taskBarUI.SetProgressType("INDETERMINATE")`
and `"normal"` to `SetProgressType("off")`; `SetProgressType()`
(`lib/Class_taskbarInterface.ahk:260`) always calls `ITaskbarList3::SetProgressState` through the
COM vtable. There is no "already in this state" short-circuit anywhere in that chain, so every
un-throttled busy/normal call is one COM call into the shell.

### 2.5 Cost per call

| Situation | Work done |
|---|---|
| Bare call, guard trips | one boolean expression |
| Bare call inside the 400 ms window | one boolean expression plus one tick subtraction |
| Bare call outside the window | `SetCursor` + `ITaskbarList3::SetProgressState` |
| Named `"normal"` / `"normal-extra"` / `"busy-img"` | `SetCursor` + `SetProgressState` (+ five global writes for `normal-extra`) |
| Named `"finger"` / `"move"` / `"cross"` | `SetCursor` only |

A loop of 100,000 bare calls therefore costs at most a few hundred real cursor changes.

### 2.6 Why loops call it at all

`SetCursor` is per thread and lasts only until the next `WM_SETCURSOR`, which Windows sends to
the window under the pointer whenever the mouse moves. QPV installs no `WM_SETCURSOR` handler
(the only mention in either file is the hook comment at module 214), so `DefWindowProc` puts the
class arrow back on every mouse move that gets pumped, and the interpreter pumps messages
between script lines even inside `Critical` loops. Two things fight that:

1. The mouse-move monitor `uiWM_MOUSEMOVE()` (module 1788) re-asserts `"busy"` on every move
   while `whileLoopExec=1`, `runningLongOperation=1` or `imageLoading=1`. `drainUIinput()`
   (module 594), the abort checkpoint's selective pump, feeds it too.
2. The in-loop heartbeat: the bare `changeMcursor()` calls catalogued in section 3.

So on this branch the heartbeat is what puts the busy cursor up at the start of a loop, keeps it
up in loops that set none of the three flags (`GenerateStaticFoldersListNow`,
`GenerateKeywordsListNow`), and refreshes the taskbar progress state every 400 ms. In loops that
set a flag it duplicates what the monitor already does while the mouse moves; with a stationary
mouse nothing resets the cursor, so nothing needs re-asserting.

### 2.7 History of the throttle

`git log -S'lastInvoked > 400'` finds one commit: `2e5293b`, v5.4.1, 2021-11-28. The function
had exactly today's guard and throttle then, but the bare path was
`interfaceThread.ahkPostFunction("changeMcursor", "busy")`, a cross-thread post to the old
interface interpreter, and `master` still carries that form (`master:quick-picto-viewer.ahk:100401`).
The 400 ms window was sized for a queued cross-thread call; on phase-c it bounds a direct
`SetCursor` plus one COM call. It is still worth keeping for the COM call.

## 3. The 24 direct in-loop call sites

Verified twice: a structural parser (braces, one-true-brace, braceless bodies, Else/Until
chains, comments, continuation sections; 2,508 functions, zero warnings) and an independent
indentation-based check agreed on all 24, and for every loop the header, the heartbeat, the
checkpoint, every `Continue`/`Break`/`Return` and the restore after the loop were read in
context (the 349-line thumbnails loop was not read line by line).

"Flags" = which of `whileLoopExec` / `runningLongOperation` / `imageLoading` are on when the loop
runs, and where they are set. "Restore" = the `ResetImgLoadStatus` (-> `uiChangeMcursor("normal-extra")`)
that ends the busy state.

| # | Call | Function | Loop header | Iterates over | Heartbeat fires | Flags | Restore |
|---|---|---|---|---|---|---|---|
| 1 | 34912 | `SaveFilesList` | `Loop, Parse, saveDynaFolders` @34903 | dynamic-folder entries written to the SLD | every existing folder | `imageLoading` via `setImageLoading()` 34887; `Critical` | timer -50 @34961 |
| 2 | 35033 | `LoadStaticFoldersCached` | `Loop, Parse, tehFileVar` @35015 | the SLD text up to `[FilesList]` | only on a new unique folder (35028) | `whileLoopExec` via `setWhileLoopBusy()` 34984 | none here; `whileLoopExec := owle` only |
| 3 | 35206 | `GenerateStaticFoldersListNow` | `Loop, % maxFilesIndex + 1` @35200 | the files list | every non-blank entry | none set here (callers set `whileLoopExec`) | none |
| 4 | 35582 | `removeFilesListSeenImages` | `Loop, % maxFilesIndex + 1` @35548 | the files list | only entries **not** already seen (`Continue` at 35571 skips it) | `imageLoading` 35513, `doStartLongOpDance()` 35540 | timers @35612/35627/35646 |
| 5 | 35724 | `findFavesInList` | `Loop, % maxFilesIndex + 1` @35693 | the files list | every non-blank entry | `setImageLoading()` 35669/35678, `doStartLongOpDance()` 35692 | timers @35739/35753 |
| 6 | 35864 | `retrieveAlreadySeenImageFromCurrentList` | `Loop, % maxFilesIndex + 1` @35828 | the files list | every non-blank entry | `setImageLoading()` 35802, `doStartLongOpDance()` 35824 | timers @35886/35911 |
| 7 | 37287 | `SortFilesList` | `Loop, % maxFilesIndex + 1` @37270 | the files list, gathering sort keys (may load image properties/histograms per file) | every entry that will be sorted | `setImageLoading()` 37229, `doStartLongOpDance()` 37269 | timers @37468/37551 |
| 8 | 37512 | `SortFilesList` | `Loop, Parse, entireString` @37496 | the sorted key list | only every 1,500 ms, with the tooltip (37510) | same as #7 | same as #7 |
| 9 | 40990 | `coreBatchMultiRenameFiles` | `Loop, % maxFilesIndex` @40985 | selected files | every selected file, first statement | `doStartLongOpDance()` 40972, `whileLoopExec` 40984; `Critical` | timer -50 @41147 |
| 10 | 44220 | `generateThumbsSheet` | `Loop, % maxFilesIndex` @44214 | selected files (all frames in `QPV:PAGES:` mode) | every selected file, before `LoadBitmapFromFileu()` | `doStartLongOpDance()` 44200, `whileLoopExec` 44209 | timer -50 @44336, **not** on the all-failed `Return` @44305 |
| 11 | 59092 | `CopyMovePanelWindow` | `Loop, Parse, historyList` @59084 | recently opened folders, max 10 | **never**: `If (StrLen(A_LoopField<4))` at 59089 always continues | `imageLoading` via `setImageLoading()` 59082 | timer -50 @59161 |
| 12 | 59112 | `CopyMovePanelWindow` | `Loop, Parse, thisDynaList` @59104 | dynamic folders, max 15 | every entry of 4+ chars | same | same |
| 13 | 59126 | `CopyMovePanelWindow` | `Loop, Parse, listu` @59121 | the de-duplicated destinations | every non-blank entry | same | same |
| 14 | 60437 | `batchCopyMoveFile` | `Loop, % maxFilesIndex` @60432 | selected files | every selected file, first statement | `doStartLongOpDance()` 60410, `whileLoopExec` 60431 | timer -50 @60622 |
| 15 | 60806 | `batchConvert2format` | `Loop, % maxFilesIndex` @60691 | selected files | every file that reaches `coreConvertImgFormat()` (which holds three more bare calls) | `setImageLoading()` 60658, `doStartLongOpDance()` 60683 | timer -50 @60852 |
| 16 | 64238 | `coreAddNewFiles` | `Loop, Parse, imgsListu` @64218 | file paths being added | every line of 3+ chars, after the checkpoint | `doStartLongOpDance()` 64208 | timer -150 @64287 |
| 17 | 64743 | `GuiDroppedFiles` | `Loop, Parse, foldersListu` @64697 | dropped folders | once per accepted folder, before `wrapperAddNewFolderToList()` (a full folder scan) | `doStartLongOpDance()` 64671, `whileLoopExec` 64673; `Critical` | timers @64763/64801/64818/... |
| 18 | 84395 | `EraseThumbsCache` | `Loop, Files, %thumbsCacheFolder%\*.*` @84390 | cached thumbnail files | every tiff/png/jpg, before its `FileDelete` | `doStartLongOpDance()` 84388 | timer -50 @84434 |
| 19 | 84920 | `QPV_ShowThumbnails` | `Loop` (unbounded, exits by `Break`) @84799 | the thumbnails of the current page, waiting on the DLL pool | once per painted thumbnail, after the pool-wait `Continue`s | `setImageLoading()` 84583, `doStartLongOpDance("no")` 84595; `Critical` | timer -25 @85202 unless `modus="all"` (then `generateAllThumbsNow` restores) |
| 20 | 92522 | `GenerateKeywordsListNow` | `Loop, % maxFilesIndex + 1` @92515 | the files list | every non-blank entry | none | direct `ResetImgLoadStatus()` @92546 |
| 21 | 96010 | `SearchAndReplaceThroughIndex` | `Loop, % maxFilesIndex + 1` @95998 | the files list (all or selected) | only when `writeSQLrows=1` (SLDB and selected-only), 96007 | `whileLoopExec` via `setWhileLoopBusy()` 95919-95997 | timer -100 @96090 |
| 22 | 97782 | `batchAutoCropFiles` | `Loop, % maxFilesIndex` @97719 | selected files | every processed file, before `coreAutoCropFileProcessing()` | `doStartLongOpDance()` 97712 | timer -50 @97803 |
| 23 | 97862 | `batchAutoColorsFiles` | `Loop, % maxFilesIndex` @97827 | selected files | every processed file, before `coreAutoColorsFileProcessing()` | `doStartLongOpDance()` 97824 | timer -50 @97881 |
| 24 | 98935 | `printLargeStrArray` | `Loop, % splitParts - 1` @98930 | 15,000-entry chunks of an array | every chunk | `doStartLongOpDance()` 98928 | none |

Functions containing a loop with a call (21): SaveFilesList, LoadStaticFoldersCached,
GenerateStaticFoldersListNow, removeFilesListSeenImages, findFavesInList,
retrieveAlreadySeenImageFromCurrentList, SortFilesList (2 loops), coreBatchMultiRenameFiles,
generateThumbsSheet, CopyMovePanelWindow (3 loops), batchCopyMoveFile, batchConvert2format,
coreAddNewFiles, GuiDroppedFiles, EraseThumbsCache, QPV_ShowThumbnails, GenerateKeywordsListNow,
SearchAndReplaceThroughIndex, batchAutoCropFiles, batchAutoColorsFiles, printLargeStrArray.

### 3.1 Notes per loop

- **#1 SaveFilesList.** The loop writes the `[DynamicFolderz]` section; a second bare call at
  34915 follows the loop immediately, so the second one is always inside the throttle window
  and does nothing. Runs under `Critical`.
- **#2 LoadStaticFoldersCached.** The heartbeat only fires when a folder is added to
  `newStaticFoldersListCache`, so a large SLD whose folders are all known runs the whole parse
  without a single cursor change; `whileLoopExec` covers it while the mouse moves. The function
  restores only `whileLoopExec`, never the cursor or the taskbar. Its callers: `SaveDBfilesList`
  (34638), `SaveFilesList` (34922) and `PopulateStaticFolderzList` (96397) restore through
  their own `ResetImgLoadStatus` timers; `updateCachedStaticFolders` (95523) does not itself,
  but each of its three callers ends in a restore (`addNewFolder2list` 64523,
  `BTNupdateSelectedStaticFolder` 96250, and `coreRescanDynaFolder` through
  `PanelDynamicFolderzWindow` -> `uiPopulateDynamicFolderzList` 96559). The SQL failure path
  `Return 0` at 34991 leaves `whileLoopExec=1`.
- **#3 GenerateStaticFoldersListNow.** No flag is set in the function: the heartbeat is the only
  busy indicator during the string pass, so while the mouse moves the arrow returns and the busy
  cursor comes back at most every 400 ms. The second loop (`For folderu ... in foldersListArray`
  @35226) does one `FileGetTime` per folder, the slow part on network shares, and its heartbeat
  is the commented-out call at 35237. No restore in the function; `regenerateStaticFoldersList`
  (35057) restores `whileLoopExec` only and then opens `PanelStaticFolderzManager`, whose
  `PopulateStaticFolderzList` ends in a `ResetImgLoadStatus` timer (96528).
- **#4 removeFilesListSeenImages.** Entries that are already seen take the `Continue` at 35571,
  which skips both the heartbeat and the `determineTerminateOperation()` checkpoint at 35584.
  With an SLDB list and `remFromDb=1` each such entry is a `deleteSQLdbEntry()`, so a long run of
  seen files (the normal case for this command) is neither abortable nor cursor-refreshed until a
  kept file comes by. `findFavesInList` (#5) and `retrieveAlreadySeenImageFromCurrentList` (#6)
  place the same pair at the end of every iteration.
- **#7/#8 SortFilesList.** Loop 1 fires for every file to be sorted; the checkpoint sits at
  37402, after the per-file property gathering. Loop 2 gates the heartbeat behind the 1.5 s
  tooltip timer, so the taskbar/cursor refresh runs at most every 1.5 s there.
- **#9, #14 rename / copy-move.** Heartbeat is the first statement after the selection filter,
  checkpoint is the last statement of the iteration; every `Continue` in between (missing file,
  skipped conflict, ...) skips the checkpoint but has already refreshed the cursor.
- **#10 generateThumbsSheet.** Heartbeat before each `LoadBitmapFromFileu()`, whose own chain
  (`LoadFileWithGDIp` 74946 / `LoadFimFile` 99291/99436 / `LoadFileWithWIA` 74715/74728) also
  calls it, all throttled together. The early `Return` at 44305 (every selected image failed to
  load) does not run `ResetImgLoadStatus`, see finding F2.
- **#11-#13 CopyMovePanelWindow.** Three short parses while the panel is built. Loop 1 is dead
  in practice (finding F1). Loops 2 and 3 are bounded (15 entries, then the merged list).
- **#15 batchConvert2format.** Checkpoint at the top (60713), heartbeat right before
  `coreConvertImgFormat()` at the bottom; `coreConvertImgFormat()` holds three more bare calls
  (61019, 61139, 61159) so the effective heartbeat is the first of the four each 400 ms.
- **#16 coreAddNewFiles.** Checkpoint first, heartbeat second, then the per-line SQL insert.
- **#17 GuiDroppedFiles.** One heartbeat per dropped folder; the folder scan it precedes is the
  long part and runs its own loops inside `wrapperAddNewFolderToList()`.
- **#18 EraseThumbsCache.** `Loop, Files` over the cache folder, one `FileDelete` per file.
- **#19 QPV_ShowThumbnails.** The heartbeat is reached only when a thumbnail is about to be
  painted; the pool-wait branches (`Continue` at 84845/84853/84895/84914, `Sleep, 1` at 84910)
  bypass it, so while the workers are decoding the cursor is kept by `imageLoading`/the monitor
  instead. `generateAllThumbsNow` (84508) calls the function in a loop with `modus="all"` and
  restores once at its own end (timer -25).
- **#20 GenerateKeywordsListNow.** Heartbeat-only loop (no flag); restores with a direct
  `ResetImgLoadStatus()` call, which also zeroes `runningLongOperation`/`imageLoading` for
  whoever called it. Its only caller is `BtnUiKeywordsLister` (92361).
- **#21 SearchAndReplaceThroughIndex.** Heartbeat and progress tooltip exist only in the
  `writeSQLrows=1` branch; for plain lists the loop runs without either, covered by
  `whileLoopExec` while the mouse moves.
- **#22/#23 auto-crop / auto-colors.** Checkpoint at the top, heartbeat right before the per-file
  processor, whose chain (`coreAutoCropFileProcessing` -> `LoadBitmapFromFileu`) calls again.
- **#24 printLargeStrArray.** Dead code: no caller in the main tree (finding F3). Would also
  leave the busy flags on: `doStartLongOpDance()` at 98928 and no restore on any of its three
  returns.

## 4. Loops that reach changeMcursor() through another function

The static call graph over-approximates: a listed loop reaches the call only if the branch that
holds it is taken. Depth 1 and 2 are exhaustive for the main file; deeper levels are summarised.

### 4.1 Depth 1: the loop calls a function that calls changeMcursor() itself

| Call | Function | Loop | Callee (its own calls) |
|---|---|---|---|
| 38117 | `multiCoreThreadJpegLL` | `Loop, Parse, filesList` @38094 | `coreJpegLossLessAction` (89737, 89749) |
| 38356 | `multiCoreThreadFormatConvert` | `Loop, Parse, filesList` @38267 | `coreConvertImgFormat` (61019, 61139, 61159) |
| 60807 | `batchConvert2format` | `Loop, % maxFilesIndex` @60691 | `coreConvertImgFormat` |
| 61509/61515 | `coreExtractFramesFromTiff` | `Loop, % tFrames` @61439 | `coreConvertImgFormat` |
| 62464 | `combineImagesFimMultiPage` | `Loop, % maxFilesIndex` @62435 | `coreImgCombinerLoadFimFile` (62727) |
| 84514 | `generateAllThumbsNow` | `Loop, % loopTimes` @84508 | `QPV_ShowThumbnails` (84920, itself #19) |
| 89706 | `batchJpegLLoperations` | `Loop, % maxFilesIndex` @89670 | `coreJpegLossLessAction` |
| 91376 | `batchAdvIMGresizer` | `Loop, % maxFilesIndex` @91287 | `coreResizeIMG` (87908, 87928) |
| 98866 | `batchSimpleColorsAdjusts` | `Loop, % maxFilesIndex` @98814 | `coreFreeImageSimpleColorsAdjust` (98188, 98281) |

All of these callees use bare calls, so per file they add throttled heartbeats and nothing else.

### 4.2 Depth 2

| Call | Function | Loop | Chain |
|---|---|---|---|
| 5394 | `panIMGonScrollBar` | `While, (determineLClickState()=1)` @5356 | `dummyResizeImageGDIwin` -> `ResizeImageGDIwin` (73863/73896/74074) |
| 5481 | `ThumbsScrollbar` | `While, (determineLClickState()=1 \|\| A_Index<3)` @5452 | `QPV_listThumbnailsGridMode` -> `setImageLoading` (73543, `"busy-img"`) |
| 5549, 5585 | `simplePanIMGonClick` | `While, (determineLClickState()=1)` @5526 | `dummyResizeImageGDIwin` -> `ResizeImageGDIwin` |
| 9679, 9690 | `thumbsListClickResponder` | `While, determineLClickState()` @9675/@9686 | `UpdateThumbsScreen` -> `QPV_ShowThumbnails` |
| 31241 | `FolderTreeRepopulate` | `Loop, Parse, bListu` @31238 | `FolderTreeFindActiveFile` -> `setImageLoading` |
| 38192 | `multiCoreThreadSimpleImgProcessing` | `Loop, Parse, filesList` @38149 | `coreSimpleFileProcessing` -> `coreJpegLossLessAction` |
| 43870, 43895 | `CombineImgsIntoPDF` | `Loop, % maxFilesIndex` @43862, `Loop, % totalFlames` @43891 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` (74946) |
| 44232 | `generateThumbsSheet` | `Loop, % maxFilesIndex` @44214 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| 53677 | `batchImgPrinting` | `Loop` @53637 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| 62243, 62264 | `combineImagesMultiTiffGDIp` | `Loop, % maxFilesIndex` @62214, `Loop, % totalFlames` @62254 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| 76442 | `ImageNavBoxClickResponder` | `While, (determineLClickState()=1 \|\| A_Index<2)` @76404 | `dummyResizeImageGDIwin` -> `ResizeImageGDIwin` |
| 78511, 78513 | `ActPaintBrushNow` | `While, (determineLClickState()=1 \|\| A_Index<2)` @78257 | `killQPVscreenImgSection` -> `coreCreateVPnavBox` (76270); `dummyResizeImageGDIwin` -> `ResizeImageGDIwin` |
| 84938, 84971 | `QPV_ShowThumbnails` | `Loop` @84799 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| 91346 | `batchAdvIMGresizer` | `Loop, % maxFilesIndex` @91287 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| 98751 | `batchSimpleProcessing` | `Loop, % maxFilesIndex` @98699 | `coreSimpleFileProcessing` -> `coreJpegLossLessAction` |

The six `While determineLClickState()` drag loops are the interesting ones: they would request
the busy cursor on every repaint during a drag, and two things stop that. They stamp
`zeitSillyPrevent` each iteration (section 2.1), which mutes `changeMcursor()` unless
`imageLoading=1`, and `uiChangeMcursor("busy")` refuses while `LbtnDwn=1`.

### 4.3 Depth 3 and deeper (78 sites, 32 first-hop callees)

The hubs, with the number of in-loop sites whose first hop is that function:

| First hop | Depth | Sites | Route to changeMcursor() |
|---|---|---|---|
| `askAboutFileCollision` | 5 | 19 | `coreDialogConflictsMsgBox` -> `uiPopulateConflictImgThumbs` -> `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| `dummyRefreshImgSelectionWindow` | 5 | 9 | `additionalHUDelements` -> `VPnavBoxWrapper` -> `createVPnavBox` -> `coreCreateVPnavBox` |
| `arrowKeysAdjustSelectionArea` | 6 | 8 | `dummyRefreshImgSelectionWindow` -> ... as above |
| `GetCachableImgFileDetails` | 3 | 6 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| `GetFilesList` | 3 | 3 | `uiPopulateCachesOverview` -> `setImageLoading` |
| 27 others | 3-6 | 1-2 each | mostly through `LoadBitmapFromFileu`, `setImageLoading`, `coreCreateVPnavBox`, `realtimePasteInPlaceAlphaMaskRotator` (14342) |

Every one of these routes ends in a bare, throttled call except the ones through
`setImageLoading()` (`"busy-img"`, un-throttled, one COM call each) and through
`GetImgFileDimension()` (busy then `"normal"`). `GetImgFileDimension()` is reachable from a loop
only through `coreJpegLossLessAction()` with `jpegOperation=9` (crop to selection, 89740), that
is from `batchJpegLLoperations`, `multiCoreThreadJpegLL` and the two `coreSimpleFileProcessing`
loops: per file the cursor goes busy, then `"normal"` (taskbar progress switched off), then busy
again at the next 400 ms window.

## 5. Other forms of repetition checked

- **Recursion.** None of the 21 functions calls itself; the apparent self-call at 85235 is the
  closing comment `} ; QPV_ShowThumbnails()`.
- **Timers.** Of the 60 functions with a call, only `PanelIndexedFilesStats` is a `SetTimer`
  target (one-shot `-250` at 29493) and its call (28099) is not in a loop. `ResetImgLoadStatus`
  is timer-driven but calls `uiChangeMcursor("normal-extra")` directly.
- **Message monitors.** `uiWM_MOUSEMOVE()` calls `uiChangeMcursor()` directly, never
  `changeMcursor()`; there is no `OnMessage(0x20)` (WM_SETCURSOR) anywhere.
- **GUI entry points.** `coreBatchMultiRenameFiles` and `generateThumbsSheet` have no textual
  caller: they are button g-labels (40502, 44435). Every other listed function has 1-10 callers
  except `printLargeStrArray` (none).
- **Commented-out calls inside loops.** 35237 (the `FileGetTime` loop of
  `GenerateStaticFoldersListNow`) and 87044 (the `Loop, Parse` @87029 of `sldGenerateFilesList`,
  which keeps its checkpoint at 87037 but no heartbeat). 6094 and 6120 are not in loops.
- **Goto loops.** None in the file.

## 6. Findings (observations only, nothing was changed)

Ordered by how visible they are to a user.

- **F1. The recent-folders section of the Copy/Move panel is dead.** `CopyMovePanelWindow`,
  line 59089: `If (StrLen(A_LoopField<4))`. The comparison is inside `StrLen()`, so the argument
  is `0` or `1`, whose length is 1, and every iteration hits `Continue`. The heartbeat at 59092
  and the `listu .= OutDir` at 59097 are unreachable; the panel never offers the recently opened
  folders, only the recent destinations and the dynamic folders. The typo dates from v3.3.0
  (`eba32ba`, 2019-07-09) and master has it too (master line 59338). The loop below it (59109)
  has the intended `If (StrLen(A_LoopField)<4)`.
- **F2. `generateThumbsSheet` leaves the app busy when every selected image fails to load.**
  After `doStartLongOpDance()` (44200) the all-failed branch returns at 44305 without
  `ResetImgLoadStatus`. `runningLongOperation` is cleared nowhere but in
  `uiChangeMcursor("normal-extra")`, so the busy cursor, the taskbar indeterminate bar and every
  gate on `runningLongOperation` stay engaged until the next image display or welcome-screen
  render runs a reset; that includes the menu block (module 248 cancels every menu with
  `EndMenu` while `runningLongOperation=1 || imageLoading=1`).
- **F3. `printLargeStrArray()` (98909-98978) is dead code.** Zero callers in the main tree
  (the only other hits are the same definition in old worktrees). If it were revived it would
  need a restore: it sets the busy flags and never clears them.
- **F4. `removeFilesListSeenImages` cannot be aborted while it is removing.** The seen-entry
  branch continues before the heartbeat/checkpoint pair (35571 vs 35582-35588); on an SLDB list
  with `remFromDb=1` that branch does a database delete per file. The sibling loops in
  `findFavesInList` and `retrieveAlreadySeenImageFromCurrentList` poll on every iteration.
- **F5. The static-folders passes rely entirely on their callers to restore.**
  `GenerateStaticFoldersListNow` and `LoadStaticFoldersCached` set the busy cursor and the
  taskbar bar through the heartbeat but restore nothing themselves, and neither does the chain
  `updateCachedStaticFolders` (95523) -> `LoadStaticFoldersCached` -> `GenerateStaticFoldersListNow`.
  Every caller chain checked does end in a `ResetImgLoadStatus` (section 3.1, #2 and #3), so no
  lingering busy state was found on a reachable path; a new caller that forgets the restore
  would leave the taskbar bar on until the next `"normal"` call. The one real leak is the
  SQL-failure `Return 0` at 34991, which leaves `whileLoopExec=1` (the mouse-move monitor then
  forces the busy cursor on every move until some later operation zeroes the flag).
- **F6. Gated heartbeats can leave a loop without a busy cursor.** #2 (new folders only), #8
  (every 1.5 s), #21 (`writeSQLrows=1` only) and #19 (only when a thumbnail is painted) rely on
  the mouse-move monitor for the cursor; with the mouse still, whatever cursor was current when
  the loop began stays.
- **F7. Busy/normal alternation per file in the JPEG crop batch.** Through
  `GetImgFileDimension()` (section 4.3) each cropped file switches the taskbar progress off and
  the cursor to the arrow; because `"normal"` does not stamp `lastInvoked`, the next busy can be
  up to 400 ms late.
- **F8. Dead code inside the chain.** `prevCursor` in `changeMcursor()` is write-only; the
  `lastZeitPanCursor` pre-assignment in `uiChangeMcursor()` (module 1726) is always overwritten.
- **F9. Near-redundant heartbeat.** `SaveFilesList` 34915 immediately follows the loop that
  just called it, so it only does anything when the loop body never fired (no dynamic folders,
  or none of them still exist).
- **F10. Design note, not a defect.** Since the interface merge the bare call is synchronous and
  cheap inside the window, but each un-throttled busy/normal is still an uncached COM call to the
  taskbar; the 400 ms window is what keeps the batch loops from hammering that. Any change to the
  throttle should keep the taskbar call in mind, not just `SetCursor`.

## 7. Method and limits

- Parser: a purpose-built AutoHotkey v1.1 structural parser (Python, kept in the job scratch
  directory, not committed) that tracks function bodies, `{}` blocks, braceless single-statement
  bodies, `If`/`Else`/`Try`/`Catch`/`Finally`/`Until`/`Switch` chains, `;` and `/* */` comments,
  continuation sections and operator-continuation lines. It resolved 2,508 function definitions
  with zero structural warnings; the one regex-found definition it "missed" (`preventCtrlA`,
  105498) is inside a block comment.
- Cross-check: an indentation-based enclosure check agreed on all 24 direct sites and on the
  enclosing function of all 86 calls.
- Call graph: textual `name(` matches inside function bodies, case-insensitive (AHK names are).
  Dynamic dispatch (`Func()`, `%name%()`, g-labels, `SetTimer`, `ahkFunction("...")`) is not
  followed, which is why the two g-label entry points show no caller. Reachability is static:
  a listed indirect loop reaches `changeMcursor()` only when the branch holding the call runs.
- Behaviour statements about the cursor reset on mouse movement follow from the Win32
  `WM_SETCURSOR` contract and the absence of a handler; they were not observed on a running
  build.
