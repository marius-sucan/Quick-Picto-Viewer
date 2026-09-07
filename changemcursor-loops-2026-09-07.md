# changeMcursor() inside loops - quick-picto-viewer.ahk

Snapshot: branch `interface-thread-merge-phase-c` at `00ceb4d`, 2026-09-07.
Scope: `quick-picto-viewer.ahk` only (105,623 lines). Plain line numbers refer to that file;
"module N" means line N of `lib/module-interface.ahk`.

Nothing in the `.ahk` sources was changed for this report.

## How to read this report

A few words are used in one fixed sense throughout:

- **Bare call**: `changeMcursor()` with no argument. It asks for the busy (hourglass) cursor.
- **Named call**: `changeMcursor("normal")`, `changeMcursor("busy-img")` and so on. It asks for
  one specific cursor.
- **The 400 ms rule**: a bare call only does something if the last bare call that did something
  was more than 400 ms ago. Named calls ignore the rule. Details in section 2.2.
- **In-loop cursor call**: a bare call written inside a loop body, so it runs on every pass of
  the loop. The 400 ms rule turns those many calls into one real cursor change every 400 ms.
  Its purpose is to keep putting the busy cursor back, because Windows replaces the cursor with
  the arrow every time the mouse moves (section 2.6).
- **Busy flags**: the three global variables `whileLoopExec`, `runningLongOperation` and
  `imageLoading`. While one of them is 1 the mouse-move handler re-applies the busy cursor on
  every mouse move by itself, and menus are blocked.
- **Abort check**: a call to `determineTerminateOperation()`. It looks for Escape or a click on
  the viewport and, at most every 200 ms, offers to stop the operation. Loops usually place it
  next to the in-loop cursor call.
- **Restore**: what ends the busy state after a loop, either `SetTimer, ResetImgLoadStatus` or a
  direct `ResetImgLoadStatus()` call. That function calls `uiChangeMcursor("normal-extra")`,
  which puts the arrow back, switches the taskbar progress bar off and clears the busy flags.

Out of scope, noted so nobody has to re-check: `lib/module-interface.ahk` defines the callee
`uiChangeMcursor()` but never calls `changeMcursor()`; `lib/Class_screenQPVimage.ahk:133` has
one call, in `LoadFreeImageFile()`, not inside a loop.

## 1. The numbers

| What | Count |
|---|---|
| Lines mentioning `changeMcursor` (not counting `uiChangeMcursor`) | 91 |
| The definition | 1 (line 99477) |
| Calls that are commented out | 4 (lines 6094, 6120, 35237, 87044) |
| Live calls | 86 |
| Live calls written inside a loop of the same function | **24, in 21 functions** |
| Bare calls among the 86 | 83 |
| Named calls among the 86 | 3: `"normal"` at 17283 and 99531, `"busy-img"` at 73543 |
| Functions that contain at least one call | 60 |
| Loops that call one of those 60 functions (one call away) | 10 call lines in 9 functions |
| Loops two calls away | 21 call lines in 15 functions |
| Loops at any distance, found by reading the code (a listed loop may never take the branch that reaches the call) | 109 call lines, 68 loops, 60 functions |
| Functions from which `changeMcursor()` can be reached at all | 973 of 2,508 |

`changeMcursor()` itself contains no loop.

## 2. What happens inside changeMcursor()

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

### 2.1 The first line: when the call does nothing

The call returns at once when any of these is true: a shape is being drawn (`drawingShapeNow`),
a slideshow is running, an animated GIF is playing, `hasInitSpecialMode` is 1, or
`zeitSillyPrevent` was set to the current time less than 300 ms ago. None of that applies while
`imageLoading=1`, which `setImageLoading()` (73538) and `doStartLongOpDance()` (35278) set
before most long loops.

`zeitSillyPrevent` is set to the current time on every pass of the mouse-drag loops
(`panIMGonScrollBar` 5358, `ThumbsScrollbar` 5462, `simplePanIMGonClick` 5584,
`winSwipeAction` 5647, `rescaleSelectedVectorPoints` 8904, `moveOnePointInVectorPath` 9049,
`selectPathPointsInRect` 9176). Those loops reach `changeMcursor()` only through other
functions (section 4.2), and this is what stops the busy cursor from flashing while the user
drags.

### 2.2 The two kinds of call and the 400 ms rule

- A named call always goes through to `uiChangeMcursor()`. It records the name in
  `prevCursor` and does **not** touch `lastInvoked`.
- A bare call goes through only if `lastInvoked` is more than 400 ms old, and then sets
  `lastInvoked` to now. This is what makes the call cheap inside loops: at most one real cursor
  change per 400 ms, every other pass costs one boolean expression.
- Because a named call does not touch `lastInvoked`, a `"normal"` call made inside the 400 ms
  window puts the arrow back, and the next bare call is still blocked until the window ends.
  `GetImgFileDimension()` (bare call at 99525, `"normal"` at 99531) and
  `downscaleHugeImagesForEditing()` (17283) do exactly this, so inside a busy loop the arrow can
  stay for up to 400 ms.
- A bare call made while the left mouse button is down still sets `lastInvoked`, but
  `uiChangeMcursor("busy")` refuses to change the cursor while `LbtnDwn=1` (module 1741). After
  the button is released the busy cursor comes back only at the next 400 ms window.

### 2.3 The two static variables

`lastInvoked` is written only by bare calls. `prevCursor` is written and never read anywhere:
dead code.

### 2.4 What the call leads to: uiChangeMcursor() and the taskbar

`uiChangeMcursor()` (module 1716):

- Loads five cursor handles once, into static variables, with `LoadCursorW` on the shared system
  cursors (wait, arrow, hand, cross, 32649). Shared system cursors are never freed, so nothing
  leaks however often the function runs.
- Returns at once while a slideshow or a GIF animation runs.
- Picks a cursor by name. `"normal-extra"` also sets `userPendingAbortOperations`,
  `imageLoading`, `mustAbandonCurrentOperations`, `runningLongOperation` and `lastCloseInvoked`
  to 0 and calls `setTaskbarIconState("normal")`; it is the **only** place in either file that
  clears `runningLongOperation`. `"busy-img"` and `"busy"` call `setTaskbarIconState("anim")`,
  and `"busy"` also requires `LbtnDwn!=1`. `"normal"` calls `setTaskbarIconState("normal")`.
  `"finger"`, `"move"` and `"cross"` only pick a handle. Any other name returns.
- Line 1726 pre-selects the hand cursor when `lastZeitPanCursor` is younger than 50 ms, but
  every branch below overwrites that choice or returns, so the line is dead code.
- Ends with one `DllCall("user32\SetCursor")`.

`setTaskbarIconState()` (module 863) turns `"anim"` into
`taskBarUI.SetProgressType("INDETERMINATE")` and `"normal"` into `SetProgressType("off")`.
`SetProgressType()` (`lib/Class_taskbarInterface.ahk:260`) always calls
`ITaskbarList3::SetProgressState`, a COM call into the Windows shell, without checking whether
the taskbar is already in that state. So every bare call that passes the 400 ms rule, and every
`"normal"`, `"normal-extra"` or `"busy-img"` call, costs one COM call.

### 2.5 What one call costs

| Situation | Work done |
|---|---|
| Bare call, stopped by the first line | one boolean expression |
| Bare call inside the 400 ms window | one boolean expression plus one subtraction |
| Bare call that passes the 400 ms rule | `SetCursor` + `SetProgressState` (COM) |
| `"normal"` / `"normal-extra"` / `"busy-img"` | `SetCursor` + `SetProgressState` (+ five global writes for `normal-extra`) |
| `"finger"` / `"move"` / `"cross"` | `SetCursor` only |

A loop of 100,000 bare calls therefore costs at most a few hundred real cursor changes.

### 2.6 Why loops keep calling it

`SetCursor` sets the cursor for the calling thread, and the setting lasts only until the next
WM_SETCURSOR message. Windows sends that message to the window under the pointer every time
the mouse moves. QPV has no handler for it (the only mention in either file is the comment at
module 214), so the default handler puts the window's arrow cursor back on every mouse move
that gets processed. The AutoHotkey interpreter processes pending messages between script
lines, even inside `Critical` loops, so this happens during the loops too. Two things put the
busy cursor back:

1. The mouse-move handler `uiWM_MOUSEMOVE()` (module 1788) re-applies `"busy"` on every mouse
   move while one of the busy flags is 1. The message reading done by the abort check
   (`drainUIinput()`, module 594) feeds the same handler.
2. The in-loop cursor calls listed in section 3.

So on this branch the in-loop call is what shows the busy cursor at the start of a loop, keeps
it up in the loops that set no busy flag (`GenerateStaticFoldersListNow`,
`GenerateKeywordsListNow`), and refreshes the taskbar progress state every 400 ms. In loops that
do set a flag it repeats what the mouse-move handler already does. With a stationary mouse
nothing resets the cursor, so nothing has to re-apply it.

### 2.7 Where the 400 ms rule comes from

`git log -S'lastInvoked > 400'` finds one commit: `2e5293b`, v5.4.1, 2021-11-28. The function
already had today's first line and the 400 ms rule, but the bare call was
`interfaceThread.ahkPostFunction("changeMcursor", "busy")`, a message posted to the old
interface thread, and `master` still has that form (`master:quick-picto-viewer.ahk:100401`).
The 400 ms was chosen to limit those cross-thread posts. On phase-c it limits a direct
`SetCursor` plus one COM call, and it is still worth keeping because of the COM call.

## 3. The 24 calls written inside loops

How they were found: a parser written for this report follows the structure of the script
(braces, one-true-brace, bodies without braces, `Else`/`Until` chains, comments, continuation
sections) and resolved 2,508 functions with no structural warnings. An independent check based
on indentation agreed on all 24. For every loop, the loop header, the cursor call, the abort
check, every `Continue`, `Break` and `Return`, and the restore after the loop were read in
context; the 349-line thumbnails loop was not read line by line.

### 3.1 Where they are

| # | Line | Function | Loop | What the loop goes through |
|---|---|---|---|---|
| 1 | 34912 | `SaveFilesList` | `Loop, Parse, saveDynaFolders` @34903 | the dynamic folders being written to the SLD file |
| 2 | 35033 | `LoadStaticFoldersCached` | `Loop, Parse, tehFileVar` @35015 | the SLD file text, up to `[FilesList]` |
| 3 | 35206 | `GenerateStaticFoldersListNow` | `Loop, % maxFilesIndex + 1` @35200 | the files list |
| 4 | 35582 | `removeFilesListSeenImages` | `Loop, % maxFilesIndex + 1` @35548 | the files list |
| 5 | 35724 | `findFavesInList` | `Loop, % maxFilesIndex + 1` @35693 | the files list |
| 6 | 35864 | `retrieveAlreadySeenImageFromCurrentList` | `Loop, % maxFilesIndex + 1` @35828 | the files list |
| 7 | 37287 | `SortFilesList` | `Loop, % maxFilesIndex + 1` @37270 | the files list, collecting the sort keys (may read image properties per file) |
| 8 | 37512 | `SortFilesList` | `Loop, Parse, entireString` @37496 | the sorted keys |
| 9 | 40990 | `coreBatchMultiRenameFiles` | `Loop, % maxFilesIndex` @40985 | the selected files |
| 10 | 44220 | `generateThumbsSheet` | `Loop, % maxFilesIndex` @44214 | the selected files (all frames in `QPV:PAGES:` mode) |
| 11 | 59092 | `CopyMovePanelWindow` | `Loop, Parse, historyList` @59084 | the recently opened folders, at most 10 |
| 12 | 59112 | `CopyMovePanelWindow` | `Loop, Parse, thisDynaList` @59104 | the dynamic folders, at most 15 |
| 13 | 59126 | `CopyMovePanelWindow` | `Loop, Parse, listu` @59121 | the merged destinations list |
| 14 | 60437 | `batchCopyMoveFile` | `Loop, % maxFilesIndex` @60432 | the selected files |
| 15 | 60806 | `batchConvert2format` | `Loop, % maxFilesIndex` @60691 | the selected files |
| 16 | 64238 | `coreAddNewFiles` | `Loop, Parse, imgsListu` @64218 | the file paths being added |
| 17 | 64743 | `GuiDroppedFiles` | `Loop, Parse, foldersListu` @64697 | the dropped folders |
| 18 | 84395 | `EraseThumbsCache` | `Loop, Files, %thumbsCacheFolder%\*.*` @84390 | the cached thumbnail files |
| 19 | 84920 | `QPV_ShowThumbnails` | `Loop` (no count, ends with `Break`) @84799 | the thumbnails of the current page, as the DLL pool delivers them |
| 20 | 92522 | `GenerateKeywordsListNow` | `Loop, % maxFilesIndex + 1` @92515 | the files list |
| 21 | 96010 | `SearchAndReplaceThroughIndex` | `Loop, % maxFilesIndex + 1` @95998 | the files list, all or selected |
| 22 | 97782 | `batchAutoCropFiles` | `Loop, % maxFilesIndex` @97719 | the selected files |
| 23 | 97862 | `batchAutoColorsFiles` | `Loop, % maxFilesIndex` @97827 | the selected files |
| 24 | 98935 | `printLargeStrArray` | `Loop, % splitParts - 1` @98930 | an array, in chunks of 15,000 entries |

The 21 functions: SaveFilesList, LoadStaticFoldersCached, GenerateStaticFoldersListNow,
removeFilesListSeenImages, findFavesInList, retrieveAlreadySeenImageFromCurrentList,
SortFilesList (two loops), coreBatchMultiRenameFiles, generateThumbsSheet, CopyMovePanelWindow
(three loops), batchCopyMoveFile, batchConvert2format, coreAddNewFiles, GuiDroppedFiles,
EraseThumbsCache, QPV_ShowThumbnails, GenerateKeywordsListNow, SearchAndReplaceThroughIndex,
batchAutoCropFiles, batchAutoColorsFiles, printLargeStrArray.

### 3.2 How they behave

"Timer at N" means `SetTimer, ResetImgLoadStatus` on line N.

| # | Function | When the cursor call runs | Busy flags set before the loop | Restore after the loop |
|---|---|---|---|---|
| 1 | `SaveFilesList` | on every folder that still exists | `imageLoading` (`setImageLoading()` 34887); runs under `Critical` | timer at 34961 |
| 2 | `LoadStaticFoldersCached` | only when a new, unique folder is found (35028) | `whileLoopExec` (`setWhileLoopBusy()` 34984) | none in the function (only `whileLoopExec := owle`) |
| 3 | `GenerateStaticFoldersListNow` | on every non-blank entry | none set here (its callers set `whileLoopExec`) | none |
| 4 | `removeFilesListSeenImages` | only for entries that are **not** already seen (the `Continue` at 35571 skips it) | `imageLoading` 35513, `doStartLongOpDance()` 35540 | timers at 35612, 35627, 35646 |
| 5 | `findFavesInList` | on every non-blank entry | `setImageLoading()` 35669 and 35678, `doStartLongOpDance()` 35692 | timers at 35739, 35753 |
| 6 | `retrieveAlreadySeenImageFromCurrentList` | on every non-blank entry | `setImageLoading()` 35802, `doStartLongOpDance()` 35824 | timers at 35886, 35911 |
| 7 | `SortFilesList`, loop 1 | on every entry that will be sorted | `setImageLoading()` 37229, `doStartLongOpDance()` 37269 | timers at 37468, 37551 |
| 8 | `SortFilesList`, loop 2 | only every 1,500 ms, together with the progress tooltip (37510) | same as #7 | same as #7 |
| 9 | `coreBatchMultiRenameFiles` | on every selected file, as the first statement | `doStartLongOpDance()` 40972, `whileLoopExec` 40984; `Critical` | timer at 41147 |
| 10 | `generateThumbsSheet` | on every selected file, before `LoadBitmapFromFileu()` | `doStartLongOpDance()` 44200, `whileLoopExec` 44209 | timer at 44336; **none** on the `Return` at 44305 |
| 11 | `CopyMovePanelWindow`, loop 1 | **never**: line 59089 makes every pass `Continue` (finding F1) | `imageLoading` (`setImageLoading()` 59082) | timer at 59161 |
| 12 | `CopyMovePanelWindow`, loop 2 | on every entry of 4 or more characters | same | same |
| 13 | `CopyMovePanelWindow`, loop 3 | on every non-blank entry | same | same |
| 14 | `batchCopyMoveFile` | on every selected file, as the first statement | `doStartLongOpDance()` 60410, `whileLoopExec` 60431 | timer at 60622 |
| 15 | `batchConvert2format` | on every file that reaches `coreConvertImgFormat()` (that function holds three more bare calls) | `setImageLoading()` 60658, `doStartLongOpDance()` 60683 | timer at 60852 |
| 16 | `coreAddNewFiles` | on every line of 3 or more characters, after the abort check | `doStartLongOpDance()` 64208 | timer at 64287 |
| 17 | `GuiDroppedFiles` | once per accepted folder, before `wrapperAddNewFolderToList()` scans it | `doStartLongOpDance()` 64671, `whileLoopExec` 64673; `Critical` | timers at 64763, 64801, 64818 and later |
| 18 | `EraseThumbsCache` | on every tiff/png/jpg file, before its `FileDelete` | `doStartLongOpDance()` 84388 | timer at 84434 |
| 19 | `QPV_ShowThumbnails` | once per thumbnail about to be painted; the passes that wait for the pool skip it | `setImageLoading()` 84583, `doStartLongOpDance("no")` 84595; `Critical` | timer at 85202, except when called with `modus="all"` (then `generateAllThumbsNow` restores) |
| 20 | `GenerateKeywordsListNow` | on every non-blank entry | none | direct `ResetImgLoadStatus()` at 92546 |
| 21 | `SearchAndReplaceThroughIndex` | only when `writeSQLrows=1`, that is an SLDB list with "selected only" (96007) | `whileLoopExec` (`setWhileLoopBusy()` 95919 to 95997) | timer at 96090 |
| 22 | `batchAutoCropFiles` | on every processed file, before `coreAutoCropFileProcessing()` | `doStartLongOpDance()` 97712 | timer at 97803 |
| 23 | `batchAutoColorsFiles` | on every processed file, before `coreAutoColorsFileProcessing()` | `doStartLongOpDance()` 97824 | timer at 97881 |
| 24 | `printLargeStrArray` | on every chunk | `doStartLongOpDance()` 98928 | none |

### 3.3 Notes per loop

- **#1 SaveFilesList.** The loop writes the `[DynamicFolderz]` section. A second bare call at
  34915 follows the loop directly; it only does something when the loop body never ran (no
  dynamic folders, or none of them still exist). Runs under `Critical`.
- **#2 LoadStaticFoldersCached.** The cursor call runs only when a folder is added to
  `newStaticFoldersListCache`, so a large SLD whose folders are all known goes through the
  whole parse without a single cursor change; `whileLoopExec` covers it while the mouse moves.
  The function restores only `whileLoopExec`, never the cursor or the taskbar. Its callers
  `SaveDBfilesList` (34638), `SaveFilesList` (34922) and `PopulateStaticFolderzList` (96397)
  restore with their own timers. `updateCachedStaticFolders` (95523) does not itself, but each
  of its three callers ends in a restore: `addNewFolder2list` 64523,
  `BTNupdateSelectedStaticFolder` 96250, and `coreRescanDynaFolder` through
  `PanelDynamicFolderzWindow` and `uiPopulateDynamicFolderzList` 96559. The SQL failure path
  `Return 0` at 34991 leaves `whileLoopExec=1`.
- **#3 GenerateStaticFoldersListNow.** No busy flag is set in the function, so the cursor call
  is the only thing showing the busy cursor during the first pass: while the mouse moves the
  arrow returns and the busy cursor comes back at most every 400 ms. The second loop
  (`For folderu ... in foldersListArray` @35226) does one `FileGetTime` per folder, the slow
  part on network shares, and its cursor call is the commented-out line 35237. No restore in
  the function; `regenerateStaticFoldersList` (35057) restores `whileLoopExec` only and then
  opens `PanelStaticFolderzManager`, whose `PopulateStaticFolderzList` ends in a timer (96528).
- **#4 removeFilesListSeenImages.** Entries that are already seen take the `Continue` at 35571,
  which skips both the cursor call and the abort check at 35584. With an SLDB list and
  `remFromDb=1` each such entry is a `deleteSQLdbEntry()`, so a long run of seen files (the
  normal case for this command) can neither be aborted nor refresh the cursor until a kept file
  comes by. `findFavesInList` (#5) and `retrieveAlreadySeenImageFromCurrentList` (#6) place the
  same two calls at the end of every pass.
- **#7 and #8 SortFilesList.** Loop 1 calls on every file to be sorted; its abort check is at
  37402, after the per-file property reading. Loop 2 calls only together with the 1.5 s
  progress tooltip, so the cursor and taskbar refresh at most every 1.5 s there.
- **#9 and #14 rename, copy/move.** The cursor call is the first statement after the selection
  test and the abort check is the last statement of the pass; every `Continue` in between
  (missing file, skipped conflict, ...) skips the abort check but has already refreshed the
  cursor.
- **#10 generateThumbsSheet.** The cursor call precedes each `LoadBitmapFromFileu()`, whose own
  chain (`LoadFileWithGDIp` 74946, `LoadFimFile` 99291 and 99436, `LoadFileWithWIA` 74715 and
  74728) calls again; the 400 ms rule merges them. The `Return` at 44305 (every selected image
  failed to load) skips the restore, see finding F2.
- **#11 to #13 CopyMovePanelWindow.** Three short parses while the panel is built. Loop 1 is
  dead in practice (finding F1). Loops 2 and 3 are small (15 entries, then the merged list).
- **#15 batchConvert2format.** Abort check at the top (60713), cursor call right before
  `coreConvertImgFormat()` at the bottom. `coreConvertImgFormat()` holds three more bare calls
  (61019, 61139, 61159); whichever of the four comes first after a 400 ms window is the one that
  does the work.
- **#16 coreAddNewFiles.** Abort check first, cursor call second, then the SQL insert for the
  line.
- **#17 GuiDroppedFiles.** One cursor call per dropped folder; the folder scan it precedes is
  the long part and has its own loops inside `wrapperAddNewFolderToList()`.
- **#18 EraseThumbsCache.** `Loop, Files` over the cache folder, one `FileDelete` per file.
- **#19 QPV_ShowThumbnails.** The cursor call is reached only when a thumbnail is about to be
  painted; the passes that wait for the pool (`Continue` at 84845, 84853, 84895, 84914, `Sleep,
  1` at 84910) skip it, so while the workers are decoding the busy cursor is kept by
  `imageLoading` and the mouse-move handler instead. `generateAllThumbsNow` (84508) calls the
  function in a loop with `modus="all"` and restores once at its own end.
- **#20 GenerateKeywordsListNow.** No busy flag; restores with a direct `ResetImgLoadStatus()`
  call, which also zeroes `runningLongOperation` and `imageLoading` for whoever called it. Its
  only caller is `BtnUiKeywordsLister` (92361).
- **#21 SearchAndReplaceThroughIndex.** The cursor call and the progress tooltip exist only in
  the `writeSQLrows=1` branch; for plain lists the loop runs without either, covered by
  `whileLoopExec` while the mouse moves.
- **#22 and #23 auto-crop, auto-colors.** Abort check at the top, cursor call right before the
  per-file processor, whose chain (`coreAutoCropFileProcessing` -> `LoadBitmapFromFileu`) calls
  again.
- **#24 printLargeStrArray.** Dead code: no caller anywhere (finding F3). It would also leave
  the busy flags on: `doStartLongOpDance()` at 98928 and no restore on any of its three returns.

## 4. Loops that reach changeMcursor() through other functions

These were found by following function calls in the source text, so a listed loop reaches the
call only if the branch that holds it is actually taken. Lists 4.1 and 4.2 are complete for the
main file; further away only the main routes are given.

### 4.1 One call away: the loop calls a function that contains a changeMcursor() call

| Line | Function | Loop | Function called (its own calls) |
|---|---|---|---|
| 38117 | `multiCoreThreadJpegLL` | `Loop, Parse, filesList` @38094 | `coreJpegLossLessAction` (89737, 89749) |
| 38356 | `multiCoreThreadFormatConvert` | `Loop, Parse, filesList` @38267 | `coreConvertImgFormat` (61019, 61139, 61159) |
| 60807 | `batchConvert2format` | `Loop, % maxFilesIndex` @60691 | `coreConvertImgFormat` |
| 61509, 61515 | `coreExtractFramesFromTiff` | `Loop, % tFrames` @61439 | `coreConvertImgFormat` |
| 62464 | `combineImagesFimMultiPage` | `Loop, % maxFilesIndex` @62435 | `coreImgCombinerLoadFimFile` (62727) |
| 84514 | `generateAllThumbsNow` | `Loop, % loopTimes` @84508 | `QPV_ShowThumbnails` (84920, loop #19) |
| 89706 | `batchJpegLLoperations` | `Loop, % maxFilesIndex` @89670 | `coreJpegLossLessAction` |
| 91376 | `batchAdvIMGresizer` | `Loop, % maxFilesIndex` @91287 | `coreResizeIMG` (87908, 87928) |
| 98866 | `batchSimpleColorsAdjusts` | `Loop, % maxFilesIndex` @98814 | `coreFreeImageSimpleColorsAdjust` (98188, 98281) |

All of these called functions use bare calls, so per file they add nothing beyond what the
400 ms rule allows.

### 4.2 Two calls away

| Line | Function | Loop | Route to changeMcursor() |
|---|---|---|---|
| 5394 | `panIMGonScrollBar` | `While, (determineLClickState()=1)` @5356 | `dummyResizeImageGDIwin` -> `ResizeImageGDIwin` (73863, 73896, 74074) |
| 5481 | `ThumbsScrollbar` | `While, (determineLClickState()=1 \|\| A_Index<3)` @5452 | `QPV_listThumbnailsGridMode` -> `setImageLoading` (73543, `"busy-img"`) |
| 5549, 5585 | `simplePanIMGonClick` | `While, (determineLClickState()=1)` @5526 | `dummyResizeImageGDIwin` -> `ResizeImageGDIwin` |
| 9679, 9690 | `thumbsListClickResponder` | `While, determineLClickState()` @9675, @9686 | `UpdateThumbsScreen` -> `QPV_ShowThumbnails` |
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

The six `While determineLClickState()` loops are the mouse-drag loops. They would ask for the
busy cursor on every repaint during a drag, and two things prevent that: they set
`zeitSillyPrevent` to the current time on every pass (section 2.1), which makes
`changeMcursor()` return at once unless `imageLoading=1`, and `uiChangeMcursor("busy")` refuses
while `LbtnDwn=1`.

### 4.3 Three or more calls away (78 call lines through 32 different functions)

The functions most of these loops go through, with the number of loop call lines each one
accounts for:

| Function called by the loop | Calls away | Loop call lines | Route to changeMcursor() |
|---|---|---|---|
| `askAboutFileCollision` | 5 | 19 | `coreDialogConflictsMsgBox` -> `uiPopulateConflictImgThumbs` -> `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| `dummyRefreshImgSelectionWindow` | 5 | 9 | `additionalHUDelements` -> `VPnavBoxWrapper` -> `createVPnavBox` -> `coreCreateVPnavBox` |
| `arrowKeysAdjustSelectionArea` | 6 | 8 | `dummyRefreshImgSelectionWindow` -> as above |
| `GetCachableImgFileDetails` | 3 | 6 | `LoadBitmapFromFileu` -> `LoadFileWithGDIp` |
| `GetFilesList` | 3 | 3 | `uiPopulateCachesOverview` -> `setImageLoading` |
| 27 others | 3 to 6 | 1 or 2 each | mostly through `LoadBitmapFromFileu`, `setImageLoading`, `coreCreateVPnavBox` or `realtimePasteInPlaceAlphaMaskRotator` (14342) |

Every one of these routes ends in a bare call, so the 400 ms rule applies, except two kinds:
the routes through `setImageLoading()` end in `"busy-img"`, which ignores the rule and costs
one COM call each time, and the routes through `GetImgFileDimension()` end in a bare call
followed by `"normal"`. `GetImgFileDimension()` is reachable from a loop only through
`coreJpegLossLessAction()` with `jpegOperation=9` (crop to selection, 89740), that is from
`batchJpegLLoperations`, `multiCoreThreadJpegLL` and the two `coreSimpleFileProcessing` loops.
There, for every file, the cursor goes busy, then back to the arrow with the taskbar progress
switched off, then busy again at the next 400 ms window.

## 5. Other ways the call could repeat

- **Recursion.** None of the 21 functions calls itself. What looks like a self-call at 85235
  is the closing comment `} ; QPV_ShowThumbnails()`.
- **Timers.** Of the 60 functions containing a call, only `PanelIndexedFilesStats` is a
  `SetTimer` target (a one-shot `-250` at 29493), and its call at 28099 is not in a loop.
  `ResetImgLoadStatus` runs from timers but calls `uiChangeMcursor("normal-extra")` directly.
- **Message handlers.** `uiWM_MOUSEMOVE()` calls `uiChangeMcursor()` directly, never
  `changeMcursor()`. There is no `OnMessage(0x20)` (WM_SETCURSOR) anywhere.
- **Buttons.** `coreBatchMultiRenameFiles` and `generateThumbsSheet` have no caller in the
  text: they are button g-labels (40502, 44435). Every other listed function has 1 to 10
  callers, except `printLargeStrArray` (none).
- **Commented-out calls inside loops.** 35237, in the `FileGetTime` loop of
  `GenerateStaticFoldersListNow`, and 87044, in the `Loop, Parse` @87029 of
  `sldGenerateFilesList`, which keeps its abort check at 87037. 6094 and 6120 are not in loops.
- **Goto loops.** None in the file.

## 6. Findings (observations only, nothing was changed)

Ordered by how visible they are to a user.

- **F1. The recent-folders section of the Copy/Move panel is dead.** `CopyMovePanelWindow`,
  line 59089: `If (StrLen(A_LoopField<4))`. The comparison sits inside `StrLen()`, so the
  argument is `0` or `1`, whose length is 1, and every pass hits `Continue`. The cursor call at
  59092 and the `listu .= OutDir` at 59097 can never run; the panel never offers the recently
  opened folders, only the recent destinations and the dynamic folders. The typo dates from
  v3.3.0 (`eba32ba`, 2019-07-09) and master has it too (master line 59338). The loop below it
  (59109) has the intended `If (StrLen(A_LoopField)<4)`.
- **F2. `generateThumbsSheet` leaves the app busy when every selected image fails to load.**
  After `doStartLongOpDance()` (44200) the all-failed branch returns at 44305 without a restore.
  `runningLongOperation` is cleared nowhere but in `uiChangeMcursor("normal-extra")`, so the
  busy cursor, the taskbar progress bar and everything that tests `runningLongOperation` stay
  engaged until the next image display or welcome-screen render runs a reset. That includes the
  menus: module 248 cancels every menu with `EndMenu` while `runningLongOperation=1` or
  `imageLoading=1`.
- **F3. `printLargeStrArray()` (98909 to 98978) is dead code.** No caller in any file of the
  repository (`.ahk` and otherwise; the only other hits are the same definition in old
  worktrees). If it were revived it would need a restore: it sets the busy flags and never
  clears them.
- **F4. `removeFilesListSeenImages` cannot be aborted while it is removing.** The seen-entry
  branch continues before the cursor call and the abort check (35571 versus 35582 to 35588); on
  an SLDB list with `remFromDb=1` that branch does a database delete per file. The sibling loops
  in `findFavesInList` and `retrieveAlreadySeenImageFromCurrentList` check on every pass.
- **F5. The static-folders passes rely entirely on their callers to restore.**
  `GenerateStaticFoldersListNow` and `LoadStaticFoldersCached` set the busy cursor and the
  taskbar bar through the cursor call but restore nothing themselves, and neither does the chain
  `updateCachedStaticFolders` (95523) -> `LoadStaticFoldersCached` ->
  `GenerateStaticFoldersListNow`. Every caller chain checked does end in a restore (section 3.3,
  #2 and #3), so no lingering busy state was found on a reachable path; a new caller that
  forgets the restore would leave the taskbar bar on until the next `"normal"` call. The one
  real leak is the SQL-failure `Return 0` at 34991, which leaves `whileLoopExec=1`; the
  mouse-move handler then forces the busy cursor on every move until some later operation
  zeroes the flag.
- **F6. Conditional cursor calls can leave a loop without a busy cursor.** #2 (new folders
  only), #8 (every 1.5 s), #21 (`writeSQLrows=1` only) and #19 (only when a thumbnail is
  painted) depend on the mouse-move handler for the cursor; with the mouse still, whatever cursor
  was showing when the loop began stays.
- **F7. Busy and arrow alternate per file in the JPEG crop batch.** Through
  `GetImgFileDimension()` (section 4.3) each cropped file switches the taskbar progress off and
  the cursor to the arrow; because `"normal"` does not touch `lastInvoked`, the next busy cursor
  can be up to 400 ms late.
- **F8. Dead code inside the chain.** `prevCursor` in `changeMcursor()` is written and never
  read; the hand-cursor pre-selection in `uiChangeMcursor()` (module 1726) is always
  overwritten.
- **F9. A nearly useless call.** `SaveFilesList` 34915 directly follows the loop that just
  called it, so it only does something when the loop body never ran (no dynamic folders, or
  none of them still exist).
- **F10. Design note, not a defect.** Since the interface merge a bare call is synchronous and
  cheap inside the 400 ms window, but every bare call that passes the rule, and every
  busy/normal named call, is still one COM call to the taskbar that nobody caches. The 400 ms
  rule is what keeps the batch loops from hammering that call. Any change to the rule should
  keep the taskbar call in mind, not just `SetCursor`.

## 7. Method and limits

- Parser: a purpose-built AutoHotkey v1.1 structure parser (Python, kept in the job scratch
  directory, not committed). It tracks function bodies, `{}` blocks, bodies without braces,
  `If`/`Else`/`Try`/`Catch`/`Finally`/`Until`/`Switch` chains, `;` and `/* */` comments,
  continuation sections and operator-continuation lines. It resolved 2,508 function definitions
  with zero structural warnings; the one definition a plain regex finds and the parser does not
  (`preventCtrlA`, 105498) is inside a block comment.
- Cross-check: an indentation-based check agreed on all 24 direct loop calls and on the
  enclosing function of all 86 calls.
- Call graph: textual `name(` matches inside function bodies, case-insensitive (AutoHotkey
  names are). Dynamic dispatch (`Func()`, `%name%()`, g-labels, `SetTimer`,
  `ahkFunction("...")`) is not followed, which is why the two button entry points show no
  caller. A loop listed in section 4 reaches `changeMcursor()` only when the branch holding the
  call actually runs.
- The statements about the cursor being reset on mouse movement follow from the Win32
  WM_SETCURSOR contract and the absence of a handler; they were not observed on a running
  build.
