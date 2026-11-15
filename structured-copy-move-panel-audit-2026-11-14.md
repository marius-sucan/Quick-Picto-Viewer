# «Structured file operations» panel audit, 2026-11-14

Scope: `PanelStructuredCopyMoveWindow()` (:60843), the panel it builds, its buttons, its menu,
its keys and the routes that open it, and everything «Proceed» runs: the handler
`BTNuiProceedStructuredOperation()` (:60907), the engine `copyMoveStructuredFolders()`
(:3208), and the helpers they hand the work to as far as a panel action reaches them (the
conflict box, the undo records, the database list, the files list). Line numbers are
`quick-picto-viewer.ahk` on `development` at `b4f374f`. The audit changed no code.

Fifteen findings. Each one says how it was checked: **run** means the real application did it
under headless Wine, on AutoHotkey_H 1.1.33.10; **read** means it follows from the code and
was not run. Nothing was run on Windows. The test kit is described at the end.

This report covers the same panel as `structured-copy-move-audit-2026-11-10.md`, which Gemini
4 Carbon wrote and which I checked on 2026-11-10. Every point of that report that holds is in
here, in other words and grouped by what the user sees; the table at the end gives Gemini's
number for each finding. The panel's nine functions are unchanged since the commit Gemini
read (`ab160cb`), and the twelve test batches of 2026-11-10 were run again on `b4f374f`: their
logs are the same, apart from time stamps, window handles and the current file of one
database list. Four batches are new.

**Status, 2026-11-15.** Finding 3 is fixed in `ed8848c`, by Marius. Findings 1 and 2 are fixed
in `88aa9fc`, with his answers to decisions 1 and 2. Finding 14 is fixed in `75e890d`, by
Marius, and completed in `87c699d`; finding 11 is partly fixed in `75e890d`..`cc45e03` and
`0ad345c`, by him, and `5410eed`. Findings 4, 5
and 6 are fixed in `3df8de3`, with his answers to decisions 3 and 7, in every tool that shares
them; finding 6 is completed in `86c89e1`, and since `eda5812` the tools that move one file find the
replaced entry by a scan. Since `215b243` no batch tool asks for an «Undo» quick-action bar (finding 4).
Seen in passing D, the count in the paste messages, is fixed in `def941f`. Findings 8, 9, 13 and 12
are fixed in `81cbbbe`, `f52eaac`, `a5855dc` and `6697b4c`, with his answers to decisions 9 to 12: finding 12 in
every tool that copies or moves a file into a folder, together with Seen in passing E. Findings 8, 9
and 14 narrow finding 7, which is fixed in `c5cbfe4` with his answers to decision 4: only full paths
with a drive letter. Finding 10 is fixed in `77b5d9c`, with his answers to decision 5. The small
things of finding 15 are numbered 15.1 to 15.14.
A fixed section ends with a note on what the code does now; those notes cite lines at
`88aa9fc` for findings 1-3, at `5410eed` for findings 11 and 14, at `3df8de3` for findings 4-6, at
`6697b4c` for the notes of 2026-11-15 (findings 7, 8, 9, 11, 12, 13, 14 and Seen in passing E), at
`c5cbfe4` for the last note of finding 7, and at `77b5d9c` for finding 10.
Since `75e890d` the folder test of findings 1 and 2 runs after the panel has closed (finding 11).
Everything else keeps its lines at `b4f374f`.

## Terms

- **Index**: QPV's files list, `resultedFilesList`.
- **Selected file**: a file marked in the index. The tool works on the selected files only.
  **One-file rule**: `getSelectedFiles(0, 1)` deselects a selection of exactly one file
  (:39547), so a count of selected files is 0 or at least 2.
- **Source** and **Destination**: the panel's two path fields. Each selected file under the
  Source folder goes to the same place under the Destination: `<Source>\a\b.png` becomes
  `<Destination>\a\b.png`. Selected files outside the Source are skipped.
- **The engine**: `copyMoveStructuredFolders()`, which «Proceed» runs once the panel is
  closed.
- **Conflict setting**: the «On file name conflicts» list: «Skip files», «Auto-rename»,
  «Overwrite», «Ask user» (the default).
- **Recycled**: sent to the recycle bin. In the runs this is Wine's recycle bin, redirected
  into the kit folder.
- **`<work>`**: the folder in which each test builds its files. Short paths in the runs, such
  as `st\a` or `out`, lie inside it.
- **Undo record**: what QPV keeps of each file action in `fileActsHistoryArray`, for «Undo
  file action» (one file) and the batch undo (all files of the last action).
- **Database list**: a files list saved as .SLDB and opened from it. It keeps its paths in
  lower case.
- **QPV's folder**: the folder QPV runs from. It is the working directory (`SetWorkingDir`
  :69, :98746), so a path without a drive letter is taken from there.
- **Regular Copy/Move panel**: «Move file(s) to...» and «Copy file(s) to...»
  (`CopyMovePanelWindow()` :60096). It shares the variable `UsrEditFileDestination` (:169)
  with this panel.

## Summary

| # | Finding | Harm | Checked | Status at `77b5d9c` |
|---|---------|------|---------|---------------------|
| 1 | The Destination names the Source folder in another way: with «Overwrite» the selected files are recycled and the tool reports success | high, needs «Overwrite» | run | **fixed**, `88aa9fc` |
| 2 | Destination inside the Source, or the reverse: on a move with «Overwrite» one selected file replaces another | high, needs «Overwrite» | run | **fixed**, `88aa9fc` |
| 3 | An edited, unsaved image among the moved files loses its edits without a question | high, narrow | run | **fixed**, `ed8848c` |
| 4 | Undo after a move that overwrote files never brings those files back | high | run | **fixed**, `3df8de3` |
| 5 | A file that cannot be copied or moved: with «Overwrite» the file at the destination is recycled anyway | medium | run | **fixed**, `3df8de3` |
| 6 | A database list: a move that overwrites a listed file leaves a database row for a file that is gone | medium, needs «Overwrite» | run | **fixed**, `3df8de3`, `86c89e1` |
| 7 | Destinations without a drive letter, the regular panel's patterns and network paths: the files land in QPV's folder | medium | run | **fixed**, `c5cbfe4` (narrowed in `81cbbbe`, `f52eaac`, `87c699d`) |
| 8 | A slash or a space at the end of a field: every file skipped, or doubled backslashes written into the index | medium | run | **fixed**, `81cbbbe` |
| 9 | A folder name with a letter outside A-Z in another case: every file is skipped | medium, narrow | run | **fixed**, `f52eaac` |
| 10 | «Possible source paths» rarely offers the folder that holds the selection | medium | run | **fixed**, `77b5d9c` |
| 11 | «Proceed» creates the destination and closes the panel before it checks the selection and asks the 150 files question | medium | run | **partly fixed**, `75e890d`..`5410eed`, `0ad345c` |
| 12 | A folder at the destination with a selected file's name receives the file; the index then names the folder | low, narrow | run | **fixed**, `6697b4c` |
| 13 | Missing files outside the Source are counted as failed, not as skipped | low | run | **fixed**, `a5855dc` |
| 14 | A destination of four characters that does not exist, such as `D:\a`, is refused | low | run | **fixed**, `75e890d`, `87c699d` |
| 15 | Small things, numbered 15.1 to 15.14: a window handle as a tooltip, the first text, «Proceed» on «Choose...», what the panel remembers | low | run and read | open |

Findings 10 and 11 are the ones a user meets in ordinary use. Findings 1 and 2 lose files
(to the recycle bin), but only with «Overwrite» and an unusual pair of paths; finding 3 loses
work for good, but needs an edited image among the moved files. All three are fixed.

---

## 1. The Destination names the Source folder in another way: «Overwrite» recycles the selected files

`BTNuiProceedStructuredOperation()` :60947, `copyMoveStructuredFolders()` :3312-3337

```ahk
If (dS=fS)
   Return msgBeepTimer("ERROR: The source and destination folders cannot be the same.")
…
thisFileExists := FileRexists(file2save, 0)
If (performOverwrite=1 && thisFileExists=1)
{
   …
   FileRecycle, %file2save%
…
FileCopy, %file2rem%, %file2save%, 1
If ErrorLevel
   wasError := 1
```

The only test for the same folder compares the two texts. When the Destination reaches the
Source folder by another way, each file's destination is the file itself. With «Overwrite»
the engine recycles it as the file to be replaced, then copies or moves a file that is no
longer there. AutoHotkey's `FileCopy` and `FileMove` leave `ErrorLevel` at 0 when their source
does not exist, so each file counts as done.

Run, «Overwrite», the selected files under `<work>\st\src`:

- **Destination `<work>\st\.\src`, copy**: the three files under the Source are in the recycle
  bin, the folder holds only its empty subfolders, and the message reads «Finished copying 3
  out of 4 files … Skipped files: 1» (the fourth file is outside the Source).
- **The same Destination, on a move** (two files selected): both are recycled and the message
  reads «Finished moving 2 out of 2 files». The index then names `<work>\st\.\src\imgA.png`,
  which does not exist, and QPV shows «File not found».
- **Destination `<work>\st\src\new\..`**, copy: both selected files recycled, «Finished
  copying 2 out of 2 files».
- **Destination: a link to the Source folder** (a Linux symbolic link under Wine, standing in
  for a Windows junction or symbolic link): both files recycled, «Finished copying 2 out of
  2 files».
- **A database list**, the Source spelled as the list keeps it, `…\st\școală`, the
  Destination as «Browse» returns it, `…\st\Școală`: three files recycled, «Finished copying
  3 out of 3 files». AutoHotkey ignores case only for A-Z (finding 9).

Read, not run: the 8.3 short name of the Source folder, and a drive letter given to one of its
parent folders with SUBST, go the same way. Wine could not make the SUBST drive.

Each recycled file also gets an undo record of a copy that never happened.

What does not lose files (run):

- **The Source folder typed in the Destination with an ending slash, with a space after the
  last backslash, or with a doubled backslash inside it.** The destination paths then hold a
  doubled backslash. `FileRexists()` asks Windows through the `\\?\` prefix
  (`PathToExtendedPath()`, lib/shell-stuff.ahk:2454 leaves `\.\` and `\..\` paths without
  it, not this one), and there such a path names nothing, so nothing is recycled. The copy
  then fails for each file («Failed to perform action on 3 files»); the move «succeeds» in
  place and writes the doubled backslash into the index and the undo records (finding 8).
- **«Skip files»** skips every file; **«Auto-rename»** fills the Source folder with copies
  named `imgA [1].png`. «Ask user» shows the conflict box with the same file on both sides
  (read).

Fix direction: compare the folders, not their texts: resolve `.` and `..` (GetFullPathName)
and compare the two folders' file IDs (volume serial number and file index, from
GetFileInformationByHandle). In the engine, before anything is recycled, skip a file whose
destination is the same file as its source. Count a copy or a move as failed when the
destination file is not there afterwards. Decision 1.

**Fixed in `88aa9fc`** by decision 1: the two folders are compared by identity, and the engine
checks each file.

- «Proceed» asks `structuredFoldersClash()` (:60989, :61020) before the question that creates
  the destination folder. It compares the Destination, then each of its parent folders, with
  the Source by `getFileIdentity()` (:44149): the volume serial number and the file index,
  which every spelling of a folder shares. When the Destination itself is the Source, the
  message is «The source and destination folders cannot be the same» and the panel stays
  open.
- The engine skips a file whose destination is the file itself (:3299-3309): a spelling the
  folder test cannot see, such as a link to one subfolder of the Source.
- A copy or a move counts as failed when its destination is not there afterwards
  (:3344-3346).

Run, the cases above: `<work>\st\.\src` on a copy and on a move, `<work>\st\src\new\..`,
the link to the Source folder and the database list with `Școală` are refused; every file
stays where it was and the recycle bin stays empty. The spellings that lost nothing are
refused too: an ending slash, a space after the last backslash, a doubled backslash. So are
«Skip files» and «Auto-rename» with such a Destination, which no longer leave `imgA [1].png`
copies in the Source folder. The test of each file, with `<QPV's folder>\linkout\new` a link
to `<work>\st\src\new`: `imgA.png` is copied, `new\img01.png` is skipped («Finished copying 1
out of 2 files … Skipped files: 1»), nothing is recycled.

The third point was not run: no case is left where a source vanishes before its copy.

---

## 2. Destination inside the Source, or the reverse: one selected file replaces another

`BTNuiProceedStructuredOperation()` :60947, `copyMoveStructuredFolders()` :3283

```ahk
file2save := StrReplace(file2rem, srcDir "\", finalDest "\")
```

Nothing stops a Destination inside the Source, or a Source inside the Destination. A file's
destination can then be the place of another selected file that the loop has not reached.

Run, move with «Overwrite»:

- **Source `st\a`, Destination `st\a\sub`**, with `st\a\img.png` and `st\a\sub\img.png`
  selected. The first file takes the place of the second, which is recycled. The second
  index entry, whose file now holds the first picture, is then moved on to
  `st\a\sub\sub\img.png`. The first entry names `st\a\sub\img.png`, which no longer exists.
- **Source `st\a\sub`, Destination `st\a`**, the deeper file first in the index: the
  shallower file's picture is recycled the same way. With the shallower file first nothing
  collides.

A copy loses nothing, but it copies the files already under the Destination again, one level
deeper. Run: Source `Photos`, Destination `Photos\Backup`: `Photos\Backup\b.png` is copied to
`Photos\Backup\Backup\b.png`.

Fix direction: refuse both cases in «Proceed» once the paths are resolved (finding 1), or
leave out of the run the files that lie under the Destination. Decision 2.

**Fixed in `88aa9fc`** by decision 2: one folder may lie inside the other, unless a selected
file would be copied or moved onto another one. `structuredFoldersClash()` (:61020) finds the
nesting by identity as well, so a link or a SUBST drive counts, and it runs before the
destination folder is created.

- **Destination inside the Source**: refused when a selected file is already inside the
  Destination, «The destination folder lies inside the source folder and already holds 1 of
  the selected files».
- **Source inside the Destination**: refused when a file would land on another selected file,
  «The source folder lies inside the destination folder, where 1 of the selected files would
  land on other selected files».

Run:

- `st\a` → `st\a\sub`, and `Photos` → `Photos\Backup` with `b.png` already in it: refused with
  the first message, nothing moved.
- `st\a\sub` → `st\a`, with the deeper file first in the index and with the shallower one
  first: refused with the second message.
- Allowed and done: `Photos` → a new `Photos\Backup` (the three files copied into it);
  `st\a` → `st\a\sub` when `sub` holds only files that are not selected; `Photos\Inbox` →
  `Photos` (both files moved up); a new folder inside the Source, reached through a link.
- Refused: the Destination `<QPV's folder>\linkdir\new`, where `linkdir` is a link to the
  Source and `new` holds a selected file.

The test does not look at the conflict setting: `Photos` → `Photos\Backup` is refused with
«Skip files» too, where nothing would have been lost (run).

---

## 3. An edited, unsaved image among the moved files loses its edits

`copyMoveStructuredFolders()` :3355, :3385, `ResizeImageGDIwin()` :75426-75429

On a move, the index entry of the image on screen gets the new path. The redraw that the
engine asks for at the end (:3385) finds a path other than the one on screen, and
`ResizeImageGDIwin()` ends the editing (`terminateIMGediting()`). Nothing asks first: the engine
does not call `askAboutFileSave()`, as the rename does (:43828).

Run: an edited image on screen (its state set by the test: an edited bitmap, five undo
levels, the modified flag), the panel opened, the two files moved. The edits are gone and no
question came up. A copy keeps them (run): only the change of path ends the editing.

The regular Copy/Move panel's `batchCopyMoveFile()` (:61396) has no save question either
(read).

Fix direction: before the loop, when the image being edited (`imgIndexEditing`) is selected
and under the Source, call `askAboutFileSave()` and stop on «Cancel».

**Fixed in `ed8848c`** (Marius): «Proceed» calls `askAboutFileSave()` before the panel closes
(:61013 at `88aa9fc`). Run, the same move: «The currently modified image is about to be
discarded and the files operations will be executed. Would you like to save the current
image?»; «Cancel» moves nothing and the edits stay. The panel stays open (read).

The question comes whenever an edited image is open: for a copy as well (run), and when the
image is not among the selected files (read). A copy keeps the edits, so there the words
«about to be discarded» do not hold.

---

## 4. Undo after a move that overwrote files never brings them back

`recordUndoFileActs()` :95178

```ahk
fileActsHistoryArray[z] := (actu=2) ? onewPath "|" zeit "|" oldPath extraMarker : onewPath "|" zeit "|?" oldPath extraMarker "|" originalFileInfos
```

The condition's first value runs up to the `:`. So the record of a move ends with the
«overwritten» mark `*` and never gets the size and dates of the file the move replaced; the
record of a copy gets them. The undo needs the size to find the replaced file in the recycle
bin:

- **The batch undo** (`batchUndoFileActs()` :95003-95004) asks the recycle bin only when the
  size is above 0. Run: two files moved with «Overwrite», then the batch undo: the two files
  go back to the Source, the two files they replaced stay in the recycle bin, and the
  message reads «Failed to recover 2 overwritten files». After a copy the same undo asks the
  recycle bin with the size (run).
- **The single-file undo** (`corefileUndoAction()` :94787) asks the recycle bin with no size
  (run). With several recycled files of that path, it may bring back another one (read).

Every tool that records a move or a rename goes through this line: the regular Copy/Move
panel (:61350, :61585), pasting files into a folder (:32299), the multi-rename (:41632) and
the single rename (:47712).

Two more points on undo:

- No «Undo move» or «Undo copy» quick-action bar appears after this tool; the regular panel
  shows one (:61641) (read).
- Undoing a move fails once the emptied Source subfolder has been deleted (run: «Failed to
  perform UNDO for 2 files»). That holds for every undone move.

Fix direction: bracket the condition:
`onewPath "|" zeit "|" ((actu=2) ? "" : "?") oldPath extraMarker "|" originalFileInfos`.
`friendlyFileUndoInfos()` already reads the size from the fourth field of any record
(:95250). Decision 7.

**Fixed in `3df8de3`** by decision 7, for every tool: the record of a move or a rename keeps the size
and dates of the file it replaced, as the record of a copy did (:95561 at `3df8de3`).

- The batch undo asks the recycle bin for that file with its size, and brings it back.
- The one-file undo asks with the size too, and its message now says whether the file came back:
  it added an unset variable where that text belonged (:95143).
- Undoing a move or a rename creates the folder the file came from when that folder was deleted
  in the meantime (:95111, :95337).

Run, on `3df8de3`:

- Batch C, a move with «Overwrite», then the batch undo: the recycle bin is asked for each
  replaced file with its size, 861 bytes, and «Failed to recover 2 overwritten files» is gone.
  The one-file undo: the same question, and the message ends «The original file was restored
  succesfully.».
- Batches N and O: after a move or a rename with «Overwrite» (this panel, the regular panel's
  batch and one-file moves, the multi-rename, the single rename), the undo puts each replaced
  file back in its place and the recycle bin is empty. At `02046f3` the same undos leave it in
  the recycle bin.
- The undo after the emptied Source subfolder was deleted (batch C; batch O, with the batch and
  the one-file undo): the files are back in a new `st\src\new`. At `02046f3`: «Failed to perform
  UNDO for 2 files».

Under Wine, `restoreFileFromRecycleBin()` cannot take a file back out of the recycle bin. The kit
puts in its place a function that moves the file back out of Wine's trash, matched by path and
size. That the Windows recycle bin finds the file by its size was not run.

The quick-action bar of the first point was asked for after this tool's run, the way the regular
panel's batch asked for it, and so it did not appear either. Every batch tool (this panel, the
regular panel's batch, pasting, the batch delete, the multi-rename) asked for its bar while the
long operation was still flagged: `runningLongOperation` is cleared by `ResetImgLoadStatus()`
50 ms later, and `CreateTempGuiButton()` builds no bar before that (run, in touch mode, for this
panel and for `batchCopyMoveFile()`). Asked for from a 150 ms one-shot timer, the bar appears
(run).

**Removed in `215b243`**, at Marius's request: none of these five tools asks for the bar now. In the
thumbnails list, Ctrl+Shift+Z (`doUndoFileActsChronos()`, also in the menus) opens the undo panel
with «Undo last action(s)» chosen. The one-file delete, rename and move keep their bar.

---

## 5. A file that cannot be copied or moved: «Overwrite» recycles the file at the destination anyway

`copyMoveStructuredFolders()` :3313-3337

The file at the destination is recycled first, and only then is the copy or the move tried.
If that fails, the destination file is gone from its folder and nothing has taken its place.
The message counts the file as failed and does not say a file was recycled; no undo record is
written. A failed `FileRecycle` is not looked at either (read).

Run: «Overwrite», `out\imgA.png` (861 bytes) present, the Source file `st\src\imgA.png` held
open by the test with no sharing. Afterwards `out\imgA.png` is in the recycle bin, `out`
holds only `imgB.png`, the message reads «Finished copying 1 out of 2 files … Failed to
perform action on 1 files», and the undo records name imgB alone. A move: the same.

The regular Copy/Move panel has the same order (:61306 before :61321, :61553 before :61566)
(read).

Fix direction: copy or move to a temporary name in the destination folder, then recycle the
old file and rename the new one; or make sure the source can be read and deleted before
anything is recycled. Decision 3.

**Fixed in `3df8de3`** by decision 3, in every tool that recycled first: this panel, the regular
Copy/Move panel (several files and one file), pasting files, the multi-rename, the single rename
and both undos. They hand the replacement to `replaceFileByCopyMove()` (:32746), which:

1. copies or moves the source next to the old file, as `<name>-tmp`;
2. only then recycles the old file, under its own name, where undo looks for it;
3. gives the new file the name, trying again for half a second, as a virus scanner may hold a
   new file for a moment.

When a step fails, the old file stays, or comes back from the recycle bin; after a move the
source goes back where it was; no temporary file is left; the file counts as failed. The
one-file undo deleted the file in its way with `FileDelete`; it now recycles it. A recycle that
failed was not looked at, and `FileCopy` or `FileMove` with their overwrite flag could then
replace the old file without the recycle bin; now both files stay and the file counts as failed.

Run, on `3df8de3`:

- The source held open (batch I, I3): `out\imgA.png` (861 bytes) stays, only `imgB.png` goes to
  the recycle bin, «Finished copying 1 out of 2 files … Failed to perform action on 1 files»; the
  same on a move, and the source stays where it was.
- The destination held open with no sharing (batch N): the copy and the move leave
  `out\imgA.png` and the source as they were, with no `-tmp` file; `imgB.png` is replaced. Wine
  asks «Confirm file deletion» inside `FileRecycle` for a file it cannot recycle; the test
  answers «No».
- The recycle refused, and the last rename refused, both simulated in the test's copy of the
  script (batch N): the old files stay or come back, the sources stay, no `-tmp` file, «Failed to
  perform action on 2 files».
- The undo of a move whose old place now holds another file, with «Overwrite» (batch O): that
  file goes to the recycle bin, in the batch undo and in the one-file undo. At `02046f3` the
  one-file undo deleted it.
- The copy and rename kit of 2026-11-08 (`batchCopyMoveFile()` and the multi-rename with
  «Overwrite», with files there from before the batch): the same files and the same recycle bin
  as at `02046f3`.

Where paths are limited to 260 characters, a destination within four characters of the limit
now fails where it was replaced: the temporary name is four characters longer (read).

---

## 6. A database list: a move that overwrites a listed file leaves a row for a file that is gone

`copyMoveStructuredFolders()` :3355-3360, `updateSQLdbEntry()` :34194

When the file a move replaces is in the list as well, the moved entry gets the path the other
entry already holds. The database refuses the update (its path column is unique),
`updateSQLdbEntry()` returns 0, and the engine does not look at it.

Run, a database list of `st\a\img.png`, `st\a\x.png`, `st\b\img.png` and `st\b\y.png`; the
`st\a` files moved to `st\b` with «Overwrite»:

- the database row of the moved `st\a\img.png` keeps that path, a file that no longer exists;
- the row of `st\b\img.png` keeps the replaced file's size: 861 bytes, where the file now has
  361;
- the index holds `st\b\img.png` twice.

A plain list gets the duplicate entry as well (read).

Fix direction: when the destination is in the list, drop its entry and its row before the
moved entry takes the path; report a failed update.

**Fixed in `3df8de3`**, in every tool that moves or renames an index entry: this panel, the regular
Copy/Move panel (several files and one file), the multi-rename, the single rename and both undos.

- **The database row:** when the database refuses the update, `moveSQLdbEntry()` (:34360)
  deletes the row that holds the new path, with its pixels row, and updates again. Any row at
  that path goes, also the row of a file deleted earlier, which kept the moved file's row on its
  old path as well. A row that still fails is journaled, and the batch tools count it: «Failed to
  update the database entries of N files».
- **The index entry:** when a move replaced a file, or a row was in the way,
  `markReplacedListEntry()` (:33778) gives the other entry with the new path the mark «Delete»
  leaves (`||` before the path), also in the list behind a filter. It looks the path up in a map
  of the list, made the first time a run needs it and given every new path the run gives an
  entry (since `86c89e1`). The regular panel's one-file move, the single rename and the one-file
  undo scan the lists instead (`scanListPath()`, since `eda5812`) and take the last entry with the
  path, the one a map gives.
- **Undo:** when an undo brings the replaced file back, its entry loses the mark, and a database
  list gives the file a new row, whose cached image data starts empty (Marius's choice).
- A selected entry with the mark counts as skipped in this panel and in the regular panel's
  batch, where it counted as failed (his choice).

Run, on `3df8de3`:

- Batch H again: the database rows are 1 `st\b\img.png` (361 bytes), 2 `st\b\x.png` and 4
  `st\b\y.png`; row 3 is gone; the index holds `||…\st\b\img.png` for the replaced file.
- Batch N, a plain list and a database list, then the batch undo: the replaced entry is marked;
  after the undo `st\b\img.png` (861 bytes) is back on the disk and in the index, and the
  database has a new row 5 for it.
- Batch P, a list filtered to `st\a` («filter to this folder»): the replaced file, filtered out,
  is marked in the list behind the filter. At `02046f3` the list showed `st\b\img.png` twice once
  the filter was removed. A marked entry leaves the list when the filter is removed, as the
  entries of deleted files do.
- The same mark after the regular panel's batch and one-file moves, the multi-rename and the
  single rename (batches N and O); the undos that bring the files back take it off.
- A selected entry with the mark: «Finished copying 2 out of 3 files … Skipped files: 1» in this
  panel and in the regular panel's batch. At `02046f3`: «Failed to perform action on 1 files».
- Batch R, database lists: the regular panel's one-file and batch moves, the single rename and
  the multi-rename delete the row of the replaced file and move the other; their undos give the
  file a new row. A row of a file deleted earlier, at the path a move takes without a conflict,
  is deleted the same way. Making the map of a list of 100 000 entries takes 0.7 s under Wine.

**Completed in `86c89e1`**: at `3df8de3` the map learnt only the entries of replaced files. When a
batch overwrote its own earlier output («Ask user», then «Overwrite» in the box), the second of
three entries of one name stayed live beside the third (run, batch R: the regular panel's batch
and the multi-rename). Every moved or renamed entry now gives the map its new path.

**Since `eda5812`** the tools that move one file look the path up by a scan of the lists: for their
single lookup, making the map costs more. On 100 000 entries under Wine the scan takes about
0.1 s and the map 0.7 s. The scan and a map made for each call gave the same entries on
12 000 random lists (filters, marked entries, É and é, restores, database rows). Batch S (a
filtered list, names in another case, ASCII and É/é, the single rename, a filtered database
list) and batches R, N, O, C, M, P and H give the same logs before and after. One difference,
which only the harness reaches: a one-file undo run on an entry that already carries the mark,
when the undo itself overwrites a file, could leave a second entry with the same mark marked
although its file came back; the scan takes that mark off.

Not covered: in a plain list, the entry of a file already missing from the disk at the new path
is not looked for; nothing signals it, and a lookup on every move would cost a pass over the
list (read). The format converter and «Modify index entry» write a new path into the database
the same way, and were not changed (read). A database list filtered by an SQL query keeps no
list behind the filter, so the entry of a replaced file that the filter hides is not in memory:
an undo that brings the file back gives it no row, and the file leaves the index once the filter
is removed (run, batch S5, on `824cf63` and on `eda5812`; at `02046f3` the replaced file's row was
never deleted, and the file stayed). The batch undo takes the same path (read).

---

## 7. Destinations without a drive letter, the regular panel's patterns, network paths: the files land in QPV's folder

`BTNuiProceedStructuredOperation()` :60916-60945, `PanelStructuredCopyMoveWindow()` :60881

```ahk
fS := Trim(UsrEditFileSource, "\")
dS := Trim(UsrEditFileDestination, "\")
…
If !FolderExist(dS)
{
   If (StrLen(dS)>4)
   {
      msgResult := msgBoxWrapper(appTitle ": Confirmation", "The destination folder seems to not exist.`n`n" dS "\`n`nWould you like to create it now?", …)
```

Nothing asks for a drive letter, so a path without one is taken from QPV's folder. The regular
Copy/Move panel refuses such paths (:61149).

The Destination field starts with `UsrEditFileDestination`, the variable into which the
regular Copy/Move panel reads its own field. That panel accepts patterns relative to each
file: `\folder` (a subfolder), `.\folder` (a sibling folder), `.\` (the parent folder),
`[group-by-years]` and two more. Left in the field, they mean something else here.

Run:

- **The regular panel used with `\subfolder`** on two files, then this panel: the Destination
  shows `\subfolder`. «Proceed» asks «The destination folder seems to not exist. subfolder\
  Would you like to create it now?». After «Yes» the four selected files are in
  `<QPV's folder>\subfolder\…`, and the undo records hold the relative path
  `subfolder\imgA.png`.
- **`.\given-folder`**: the question shows `.\given-folder\`; the files go to
  `<QPV's folder>\given-folder\`.
- **`relout`, on a move**: the files are moved to `<QPV's folder>\relout\` and the index holds
  `relout\imgA.png`.
- **`..`** exists, so no question comes: the files go to the folder above QPV's.
- **`.\` alone** is refused, «Please choose an existing destination folder»: `FolderExist()`
  wants two characters at least.
- **`\\nas\archive`**: `Trim(…, "\")` takes away the two leading backslashes. The question
  shows `nas\archive\`, and after «Yes» the files are in `<QPV's folder>\nas\archive`.
- **A network Source**, `\\nas\photos`, is refused: «Please choose an existing source folder».
- **A Source without a drive letter that exists in QPV's folder** (`lib`) is searched anywhere
  in the files' paths. Here every file then failed and nothing was written.

A Destination with characters a folder name cannot hold, or on a drive that does not exist,
gets the question as well, and after «Yes» the box «An unknown error occurred while creating
the folder» (read).

The pre-filled Source loses the `\\` of a network path too (`zPlitPath()` in its fast mode,
:60866), and «Browse» does not start in such a folder (`Trimmer(…, "\")` :59960, :59980)
(read). Were a network path let through, the engine's own `zPlitPath()` call (:3284) would take
the `\\` away again (read). A network path reaches the index only through «Search and
replace», so this part is rare.

Fix direction: accept only `X:\…` and `\\server\share\…`, as the regular panel does at :61149,
and keep the leading `\\`; start the Destination from this panel's last folder. Decision 4.

**Partly fixed by findings 8, 9 and 14** (`81cbbbe`, `f52eaac`, `87c699d`). «Proceed» resolves each field to a
full path (finding 8), so a path without a drive letter names its folder in QPV's folder in full, in
the questions, the messages, the index and the undo records; the files go where they went. Only a
path under the root of an existing drive is offered for creation (finding 14), and a Source matches
a file's path from its first character (finding 9). Run, batches A and I:

- `relout`, `\\nas\archive`, and the regular panel's `\subfolder` and `.\given-folder` left in the
  field, none of which exists: «ERROR: Please choose an existing destination folder», the panel stays
  open, nothing is made in QPV's folder.
- `..` exists, so no question comes: the files go to the folder above QPV's, as before; the messages
  and the undo records name it in full.
- The Source `lib`: «Finished copying 0 out of 2 files … Skipped files: 2», where every file failed.
- `.\` alone is still refused (finding 8).

Still open: an existing folder without a drive letter, network paths, and the Destination pre-filled
from the regular panel's field (decision 4).

**Fixed in `c5cbfe4`** by decision 4: both fields take only a full path with a drive letter.
`cleanFolderPath()` (:61241) tells from the text, before Windows resolves it, whether it starts with
`X:` or `X:\`, and resolves only such a text. «Proceed» (:61183) refuses any other text before the
save question and the 150 files question, with the panel open: «ERROR: The source folder must be a
full path with a drive letter, such as C:\photos», and the same for the destination (:61195,
:61201). This covers a folder relative to QPV's folder, whether it exists or not (`\folder\sub`,
`.\folder\sub`, `folder`, `..`), a path relative to a drive's current folder (`C:folder`) and
network paths (`\\nas\archive`, which the trim turned into `nas\archive`). A drive root, typed as `C:`
or `C:\`, is still accepted, and an empty field still gets «Please choose an existing … folder». The
Destination field starts empty when `UsrEditFileDestination` holds no full path (:61156), so the
regular panel's patterns no longer show up in it.

Checked by reading only. The script loads with AutoHotkey_H (with and without `/iLib`) and with
stock AutoHotkey 1.1.37 (`/iLib`). Batch W, added to the kit for this fix, did not run, and neither
did the fixed copy: the runs were stopped at Marius's request. The cases of batches A and I that
named such paths (A8-rel, A9-rel, A9-dots, A10-unc, A10-unc-src, A11, I1, I1b, I1c) should now get
the new message, and I1, I1b and I1c should open with an empty Destination.

---

## 8. A slash or a space at the end of a field

`BTNuiProceedStructuredOperation()` :60916-60921, `copyMoveStructuredFolders()` :3262, :3283

```ahk
fS := Trim(UsrEditFileSource, "\")
dS := Trim(UsrEditFileDestination, "\")
fS := StrReplace(fS, "/", "\")
dS := StrReplace(dS, "/", "\")
fS := Trimmer(fS)
dS := Trimmer(dS)
```

The ending backslash is taken away before a `/` becomes `\` and before the spaces are taken
away. So `C:\temp\imgs/` and `C:\temp\imgs\ ` both keep an ending backslash, and a doubled
backslash typed inside a path stays as it is. The regular panel collapses doubled backslashes
(:61092).

Run:

- **The Source with an ending slash, or with a space after the last backslash**: the engine
  looks for `…\imgs\\` in each path, finds it nowhere, and skips every file: «Finished copying
  0 out of 4 files … Skipped files: 4».
- **The Destination with an ending slash, on a move**: the files are moved, and the index and
  the undo records hold `…\out\\imgA.png`. On a database list the database gets the same
  path (read).

Fix direction: take away the spaces first, then turn `/` into `\`, collapse doubled
backslashes, and take away the ending backslash last.

**Fixed in `81cbbbe`** by decision 9: «Proceed» hands each field to `cleanFolderPath()` (:61233). It
trims the spaces at both ends, reads `/` as `\` and trims the backslashes at both ends (a leading
`\\` too, as before: finding 7), then lets Windows resolve the path (`resolveFullPath()`,
GetFullPathNameW): `.` and `..`, repeated backslashes, an ending dot or space. The result has no
ending backslash. A single character stays as typed, so `.\` is still refused: resolved, `.` would
name QPV's folder.

Run, at `0ad345c` and on `6697b4c`:

| Field | At `0ad345c` | On `6697b4c` |
|---|---|---|
| Source `<work>\st\src/` or `<work>\st\src\ ` (A2, A3) | «Finished copying 0 out of 4 files … Skipped files: 4» | «Finished copying 3 out of 4 files … Skipped files: 1» |
| Source `<work>\st\\src`, `<work>\st\.\src`, `<work>\st\src.` (V8) | «0 out of 4», every file skipped | «3 out of 4» |
| Destination `<work>\out/` on a move (A6) | index and undo records `<work>\out\\imgA.png` | `<work>\out\imgA.png` |
| Destination `<work>\\out`, `<work>\st\nothing\..\..\out`, `<work>\out.` on a move (V8) | index `<work>\\out\…`, `<work>\st\nothing\..\..\out\…`, `<work>\out.\…` | `<work>\out\…` |
| Destination `<work>\out \ ` on a move (V8) | «The destination folder seems to not exist.» for `<work>\out \\` | moved into `<work>\out` |
| The Source folder typed in the Destination with `/`, `\.\`, `\\`, an ending space, or as `new\..` (A4, A5, B4) | refused by the folder test, after the panel closed | refused by «Proceed», «The source and destination folders cannot be the same», the panel open |

Under Wine, GetFullPathNameW drops an ending dot or space; that Windows does the same was not run.

---

## 9. A letter outside A-Z in another case: every file is skipped

`IdentifyFileFolderRoots()` :60273, `copyMoveStructuredFolders()` :3262

```ahk
OutDir := Format("{:L}", SubStr(imgPath, 1, InStr(imgPath, "\", 0, -1) - 1))
…
If !InStr(file2rem, srcDir "\")
```

AutoHotkey compares without regard to case for A-Z only: `"Ș"="ș"` is false (run). Two routes
put a Source in lower case against paths that have capitals:

- the «Possible source paths» menu lowers every letter of every folder (`Format("{:L}")`);
- a database list keeps its paths in lower case, while «Browse» returns the disk's spelling.

Run, files under `st\Școală\…`:

- a folder list, the Source taken from the menu (`…\st\școală`): «Finished copying 0 out of 3
  files … Skipped files: 3»; typed as on the disk, the copy works;
- a database list, the Source from «Browse» (`…\st\Școală`): the same three skipped files;
- the database list with «Overwrite», the Source as the list spells it and the Destination as
  «Browse» gives it: finding 1.

Fix direction: compare both sides after the same full case folding (`Format("{:L}")` on both,
or `CompareStringOrdinal` with its ignore-case flag), and give the menu the disk's spelling.

**Fixed in `f52eaac`**: the engine (:3254) and `testStructuredFoldersClash()` (:61313) take the part of a
file's path below the Source from one helper, `pathBelowFolder()` (:61341). It lowers both sides with
`Format("{:L}")`, as a database list lowers its paths, and compares from the first character. The
destination is the Destination with that part of the file's own path after it (:3284):
`StrReplace()` folded A-Z alone as well, and replaced every place the text was found. «Possible source
paths» shows each folder as the index spells it (:60548, decision 11): the disk's spelling in a folder
list, lower case in a database list.

Run, at `0ad345c` and on `6697b4c`:

- E1, a folder list, the Source from the menu: the menu offers `…\st\Școală` and the copy reads
  «Finished copying 3 out of 3 files», where it offered `…\st\școală` and skipped the three.
- E2, a database list, the Source from «Browse»: three files copied, where none were.
- V9: the Source typed `…\st\școală` over `st\Școală\…` copies both files. With the Destination
  `…\st\Școală\sub`, which holds a selected file, on a move with «Overwrite»: «The destination folder
  lies inside the source folder and already holds 1 of the selected files». With the Source
  `…\st\ș\inner` inside the Destination `…\st\Ș`, where one file would land on the other: «The
  source folder lies inside the destination folder, where 1 of the selected files would land on
  other selected files». At `0ad345c` the folder test found no file in either case, and the engine
  skipped every file.
- D: the menu entries keep their capitals (`C:\Temp\Imgs`), with the same folders and count.

A Source no longer matches in the middle of a path: the relative `lib` of finding 7 skips the files
it made fail. An index that spells one folder in two ways, which differ in a letter outside A-Z, may
show both spellings in the menu (read; run at `5398a53`, X10: both shown; one since `77b5d9c`,
finding 10). That `Format("{:L}")` folds letters as NTFS compares names was
not run on Windows; the two differ for a few letters whose capital and small forms do not pair one to
one (read).

---

## 10. «Possible source paths» rarely offers the folder that holds the selection

`IdentifyFileFolderRoots()` :60253-60349, `BtnIdentifyFileRoots()` :60216

The button promises «possible source paths based on the selected files». What it lists:

1. for the folder of each selected file, its parent folder (:60301);
2. of those, the ones on the shallowest level and on the next one (:60325-60328);
3. less any that sorts right after another one and lies inside it (:60340).

So a selected file's own folder is never offered, and a parent that is a drive is dropped.

Run, with index entries written by the test:

| The selected files are in | Offered | A folder holding them all |
|---|---|---|
| `C:\imgs` | nothing: no menu, no message | `C:\imgs` |
| `C:\dir1` and `C:\dir2` | nothing | `C:\` |
| the root of `C:` | nothing | `C:\` |
| `C:\work\imgs` | `c:\work` | `C:\work\imgs` |
| `C:\work\imgs` and `C:\work\imgs\new` | `c:\work` | `C:\work\imgs` |
| the files of the «Help» example | `c:\temp` | the «Help» names `c:\temp\imgs\` as the Source |
| `D:\work\pics` and `C:\Users\…\2026\Trips\Rome` | `d:\work` | one for each drive |
| `c:\work\proj\x`, `c:\work\proj-2\y`, `c:\work\proj\sub\z` | `c:\work\proj`, `c:\work\proj-2`, `c:\work\proj\sub` | `c:\work` |
| `C:\photos\yearN\eventM`: 60 000 files, 3 000 folders | 150 entries, `c:\photos\year0` … «and 140 folders more» | `c:\photos` |

In the last case, any entry picked as the Source copies one year and skips the files of the
other 149 (read).

More (run unless marked):

- The paths are in lower case (finding 9).
- An `&` in a folder name is not doubled: the item text holds a single `&`, which a menu
  shows as an underline under the next letter, so `c:\r&d\` reads `c:\rd\` (read).
- For files on a network share the list holds `\\server` alone (with index entries written by
  the test; finding 7).
- «Please wait...» stays next to the pointer while the menu is open (read).
- Pressed with the keyboard, the button opens the menu at the mouse pointer, wherever that is
  (read).
- The first press reads the whole index, with no way to stop it, and its time grows with the
  square of the number of separate parent folders, because each new parent is looked for in
  a growing text (:60302). Under Wine: 60 000 files in 3 000 folders, 0.5 s; files each in a
  folder with a parent of its own, 2 500 files 0.5 s, 5 000 files 1.9 s, 10 000 files 6.8 s,
  20 000 files 29 s.
- The list is kept while the panel is open. A selection changed meanwhile, which only Quick
  search can do, is not seen.

Fix direction: offer first the deepest folder that holds every selected file of a drive, then
the folders one level below it; keep the disk's spelling; double the `&`; keep the seen
parents in a hash table. Decision 5.

**Fixed in `77b5d9c`** by decision 5: the menu offers, for each drive, the deepest folder that holds
every selected file of that drive, then each folder above it up to the drive root. Every entry of a
drive keeps all its selected files; a higher one recreates more of the path in the Destination.
`IdentifyFileFolderRoots()` (:60537) builds this in one pass over the index: it keeps, for each
drive, the common folder in lower case and shortens it until it holds the next folder, so its time
grows with the number of files, no longer with the square of the number of folders. The
drive with the most selected files comes first, a tie in the drive letters' order. An entry that holds only part of the selection ends with «N of M files»,
where M counts every selected file (:60491). Folders without a drive letter are left out, as
«Proceed» refuses them (finding 7). Each entry keeps the index's spelling of the drive's first
selected file (decision 11). An `&` in a folder name is doubled so that the menu shows it. The
menu opens under the button, through `showThisMenu()` as the multi-rename panel's menus do, and
«Please wait...» is removed before it opens. When nothing can be offered, a message says why. A
chosen root fills the Source as `C:\` (:60522). The button's tooltip describes the new list (:61145).

Run with index entries written by the test (batches D and X), at `5398a53` and on `77b5d9c`:

| The selected files are in | Offered at `5398a53` | Offered on `77b5d9c` |
|---|---|---|
| `C:\imgs` (D2) | nothing: no menu, no message | `C:\imgs`, `C:\` |
| `C:\dir1` and `C:\dir2` (D2b), or the root of `C:` (D2c) | nothing | `C:\` |
| `C:\work\imgs`, with or without `C:\work\imgs\new` (D3, D3b) | `C:\work` | `C:\work\imgs`, `C:\work`, `C:\` |
| the files of the «Help» example (D1) | `c:\temp` | `c:\`: one of its files is in `c:\other-files` |
| the same without its two skipped files (D1b) | `c:\temp` | `c:\temp\imgs`, `c:\temp`, `c:\` |
| `D:\work\pics` and `C:\Users\…\2026\Trips\Rome` (D4) | `D:\work` | the seven folders from `C:\Users\…\Rome` up to `C:\`, each «2 of 3 files», then `D:\work\pics`, `D:\work`, `D:\`, each «1 of 3 files» |
| `c:\work\proj\x`, `c:\work\proj-2\y`, `c:\work\proj\sub\z` (D5) | `c:\work\proj`, `c:\work\proj-2`, `c:\work\proj\sub` | `c:\work`, `c:\` |
| thirteen trees `C:\setN\imgs` (D9) | ten `C:\setN` and «… and 3 folders more» | `C:\` |
| `C:\photos\yearN\eventM`, 60 000 files (J1) | 150 entries, `C:\photos\year0` first | `C:\photos`, `C:\` |
| `C:\r&d\imgs` and `C:\r&d\other` (D6) | `C:\r&d\`, which the menu shows as `C:\rd\` (read) | `C:\r&d\`, `C:\` |
| two files on `C:\a\b`, one on `\\server\share` (X4) | `\\server`, `C:\a` | `C:\a\b`, `C:\a`, `C:\`, each «2 of 3 files» |
| one file on `E:\x`, one on `D:\y` (X8) | nothing | `D:\y`, `D:\`, `E:\x`, `E:\`, each «1 of 2 files» |
| one folder spelled `C:\Școală` and `c:\școală` (X10) | both spellings | `C:\Școală`, `C:\` |
| `\\server\share` and a subfolder (D8) | `\\server` | no menu: «WARNING: None of the selected files is on a drive with a letter; network paths are not supported» |
| listed, none selected (X7) | nothing | no menu: «WARNING: Insufficient files selected for the operations» |

Run in the panel (batch X, a tree under `<work>\st\a&b`): the button hands its own handle to the
handler, and «Please wait...» is gone when the menu opens, where it was still shown (X1). With the
pointer at 3,3, the real menu opened at 705,359, under the button at 705,338, which is 21 pixels
high; at `5398a53` it opened at 3,3 (X3). Each of the twelve entries, chosen, fills the Source with
its folder, the last one as `Z:\` (X2). A Source picked from the menu copies the same files as
before (E1).

The first press, under Wine (batch J):

| Selected files | At `5398a53` | On `77b5d9c` |
|---|---|---|
| 60 000 in 3 000 folders under 150 parents | 546 ms | 138 ms |
| 2 500, each in a folder of its own | 510 ms | 29 ms |
| 5 000 | 1 823 ms | 33 ms |
| 10 000 | 6 811 ms | 59 ms |
| 20 000 | 29 093 ms | 110 ms |

Left as it was: the list is kept while the panel is open (his choice), so a selection changed
through Quick search still gets the first list (D7b). The menu still shows at most ten entries
and «… and N folders more». A deep tree fills them with its own folders, the ones nearest the root
left out (X1, X6). A second drive's entries come after the first drive's whole chain, so a deep
first tree can hide them (read).

---

## 11. «Proceed» acts before it checks

`BTNuiProceedStructuredOperation()` :60929-60951, `copyMoveStructuredFolders()` :3210-3222

```ahk
FileCreateDir, %dS%             ; after «Yes» to «Would you like to create it now?»
…
BtnCloseWindow()
copyMoveStructuredFolders(fS, dS)
…
filesElected := getSelectedFiles(0, 1)
If (srcDir=finalDest || !srcDir || !finalDest || filesElected<2)
   Return
If (filesElected>150)
{
   msgResult := msgBoxWrapper(appTitle ": Confirmation", "Please confirm you want to " wording " the selected files.…
   If (msgResult!="Yes")
      Return 0
```

The destination folder is created and the panel closed before the engine looks at the
selection and asks its question.

Run:

- **Fewer than two files selected**: after «Yes» the folder is created, the panel closes, and
  nothing else happens, with no message. The panel can be open in that state: F8 reopens the
  last panel whatever the selection (`openPreviousPanel()` :27537; run: «Selected files:
  0.»), and Quick search can drop the selection under the open panel (run). The main window
  refuses its other commands while a panel is open.
- **More than 150 files**: «No» at «Please confirm you want to COPY the selected files» finds
  the panel already closed, with what was typed in it, and the destination folder created a
  moment before stays, empty (run: 152 files).

Fix direction: in «Proceed», test the selection and ask the 150 files question before the
folder question; close the panel last. Decision 6.

**Partly fixed in `75e890d`..`cc45e03`** (Marius) **and `5410eed`**. «Proceed» counts the
selected files and asks the 150 files question itself, after the save question and before the
panel closes (:61004-61010 at `5410eed`), and hands the count to the engine (:3208). With
nothing selected it says «WARNING: Insufficient files selected for the operations» and stays
open (:61011-61012).

Run:

- 152 files, «No» at the 150 files question: the panel stays open, with what was typed in it,
  and nothing is moved.
- 152 files and a Destination that does not exist, «Yes» to create it, then «No» at the 150
  files question: the panel stays open.
- Three files selected when the panel opened and one when «Proceed» is clicked (so none, by
  the one-file rule), the Destination missing: «Yes» to create it, then the warning, and the
  panel stays open. At `cc45e03` the panel closed after the warning.

**Fixed in `0ad345c`** (Marius): «Proceed» counts the selection and asks the 150 files question
before it looks at the Destination, so no folder is made before both are answered. Run at `0ad345c`
(in batch K, I7 answers the 150 files question first, as it now comes first):

- A12, one file selected when «Proceed» is clicked (so none), the Destination missing: «WARNING:
  Insufficient files selected for the operations», no folder question, no folder; the panel stays open.
- I7, 152 files, «No» at the 150 files question: no folder. I7b, «Yes» there, then «No» at «Would you
  like to create it now?»: no folder, nothing copied, the panel open.
- V11, an edited image among the files: the save question comes before the Destination is looked at.
  «Discard» only answers it; the move itself drops the edits. So when the Destination is then refused
  («No» at the folder question), the edits stay and the panel stays open; at the next «Proceed» the
  save question comes again (V11b, «Cancel»).

Still open:

- The folder test of findings 1 and 2, now `testStructuredFoldersClash()` (:61018), runs in
  the engine (:3211), after the panel has closed. Its refusals no longer leave the panel open
  (run: the cases of findings 1 and 2; every file stays where it was). It never refuses a
  folder made a moment before, which holds neither a selected file nor the Source (read).
- The folder test lets the operation go ahead when it runs out of time: after 5 s on each walk
  up the parent folders (:61045, :61069), and after 95 s on the selected files (:61095)
  (read). A walk takes as many steps as the path has folders, so the 5 s limits are met only
  on a slow network path.

---

## 12. A folder at the destination with a selected file's name receives the file

`copyMoveStructuredFolders()` :3299, :3312

```ahk
If (FileExist(file2save) && !FolderExist(file2save))
   file2save := askAboutFileCollision(file2rem, file2save, 1, 0, forceConflictOption, performOverwrite)
…
thisFileExists := FileRexists(file2save, 0)
```

A folder named like the file is no conflict here, and `FileRexists()` answers 0 for a folder.
`FileMove` and `FileCopy` then put the file inside that folder and report success.

Run: `out\imgA.png` is a folder. The move puts the file at `out\imgA.png\imgA.png`, and the
index entry names the folder `out\imgA.png`. The same with «Overwrite», right after a file
whose destination was replaced: the folder is not recycled, the file goes inside it.

A file with no extension goes the same way (run, with an index entry written by the test:
no loader admits such a file). `zPlitPath()` in its fast mode (:3284) takes the name for a
folder, the engine creates the folder `out\rawfile`, and the file ends up at
`out\rawfile\rawfile`.

Fix direction: treat such a folder as a conflict that cannot be overwritten: skip the file
and count it.

**Fixed in `6697b4c`** by decision 10, in every tool that copies or moves a file into a folder: a folder
with the file's name at the destination counts as failed, under every conflict setting, as in the
multi-rename since `25c77c6`; a source that is a folder counts as failed as well (Seen in passing E).

- This panel (:3301). It takes the destination folder as the text before the last backslash
  (:3285), where `zPlitPath()` in its fast mode took a name with no extension for a folder.
- The regular Copy/Move panel, several files (:61963) and one file (:61672). The one-file move says
  «WARNING: Operation aborted. A folder with the same name already exists in the destination folder.»
  before the panel closes.
- Pasting files (:32284).
- The one-file undo of a move or a rename (:95191), «ERROR: Undo MOVE failed. A folder has the name of
  the file», and the batch undo (:95418).
- `zPlitPath()` gives no name to a file with no extension, so in the regular panel and in pasting the
  destination was the folder itself: `FileCopy` dropped the file in it, and the index and the undo
  record named the folder. These tools now take the name and the folder from the last backslash
  (:32240, :61629, :61876), and so does the message of the one-file move (:61758).

Run, at `0ad345c` and on `6697b4c` (batches B, K and V):

| Case | At `0ad345c` | On `6697b4c` |
|---|---|---|
| This panel, `out\imgA.png` a folder, move (B1), also with «Ask user» (V12) | the file in `out\imgA.png\imgA.png`, the index names the folder | «Failed to perform action on 1 files», the file stays, no conflict box |
| The same with «Overwrite», after a file that was replaced (I6) | the file in the folder | the first file replaced, the second failed |
| A file with no extension (B2) | `out\rawfile\rawfile` | `out\rawfile` |
| The same, `out\rawfile` a folder (V12) | `out\rawfile\rawfile` | failed |
| The regular panel, several files: a folder in the way, a file with no extension (V12) | in the folder; the index entry `<work>\out\` | failed; `out\rawfile`, the entry `<work>\out\rawfile` |
| The regular panel, one file: a folder in the way; a file with no extension (V12) | «File MOVED to», in the folder; the entry `<work>\out\` | the warning above, nothing moved; «File MOVED to rawfile», the entry `<work>\out\rawfile` |
| Pasting: `out\imgA.png` a folder; `LICENSE` (V12) | in the folder; copied, undo record `<work>\out\` | failed; copied, undo record `<work>\out\LICENSE` |
| Undo of a move, a folder made at the old place (V12, one file and batch) | «Undo MOVE succeded», the file in the folder | the error above / «Failed to perform UNDO for 1 files», the file stays |

---

## 13. Missing files outside the Source are counted as failed

`copyMoveStructuredFolders()` :3256-3266

```ahk
If !FileExist(file2rem)
{
   failedFiles++
   Continue
}
If !InStr(file2rem, srcDir "\")
{
   skippedFiles++
```

The existence test comes first. A selected file that lies outside the Source and is missing
from the disk counts as a failure (run: «Failed to perform action on 1 files»). On a drive
that is offline, each such file waits for the drive (read).

Fix direction: swap the two tests.

**Fixed in `a5855dc`**: the Source test comes first (:3254). Run: B6 reads «Finished copying 2 out of 3
files … Skipped files: 1», where it read «Failed to perform action on 1 files»; in V13 a missing file
inside the Source still fails and one outside is skipped.

---

## 14. `D:\a` is refused

`BTNuiProceedStructuredOperation()` :60931

```ahk
If (StrLen(dS)>4)
```

A destination that does not exist is offered for creation only when it is longer than four
characters. Run: `C:\q` gets «Please choose an existing destination folder»; `C:\qq` gets the
question.

Fix direction: test for a path under a drive root (finding 7) instead of the length.

**Fixed in `75e890d`** (Marius): the test is `StrLen(dS)>2` (:60982 at `5410eed`). Run: `C:\q`
gets «The destination folder seems to not exist. C:\q\ Would you like to create it now?».

The drive-root test of the fix direction was not made, so shorter paths without a drive letter
get the question as well: `rel`, which does not exist, was refused and is now offered for
creation (run). After «Yes» it would be made in QPV's folder, as `relout` is (finding 7).

**Completed in `87c699d`** by decision 12: the question comes only for a path under the root of an
existing drive (:61213), told from the text before it is resolved (finding 8), which completes any
path. Run: `C:\q` and `C:\qq` get the question; `rel`, `relout`, `B:\made` (Wine has no drive B:),
`Q:\src` (no drive Q:), `\\nas\archive`, `\subfolder` and `.\given-folder` get «ERROR: Please choose an
existing destination folder», with the panel open (A8-A10, I1, I1c, I4b). A network path is refused
that way too, where it was made as `nas\archive` in QPV's folder; whether to support network paths
stays open (decision 4). Settled in `c5cbfe4`: refused, as is every path without a drive letter
(finding 7).

---

## 15. Small things

- **15.1. The «Action to perform» list shows a window handle as its tooltip** (run: `0x2c0142`).
  `GuiAddDropDownList()` uses the third item of its label list both as the list to align
  with and as the tooltip text (:26604-26613). The regular Copy/Move panel has it too (run).
- **15.2. The first text** reads «This panels allows users…», and it was meant to start with the
  selection count: `infoSelection` is filled after the text is added (:60874, :60890) (run).
- **15.3. «Proceed» is enabled while «Action to perform» shows «Choose...»**, where the regular panel
  disables it; a click says «Please select action to perform: copy or move files» (run). It
  is also narrow: 60 pixels (read).
- **15.4. The action is «Choose...» at every opening** (:60865) (run). It may be meant so.
- **15.5. «On file name conflicts» is not kept across restarts** (read). The regular panel's list is
  not either.
- **15.6. The destination is not added to the recent destinations** of the regular panel (read:
  no `RecentCopyMoveManager()` call), and `prevFileMovePath` is not set (run).
- **15.7. «Browse», then «Cancel»**: at the next opening the Destination shows the text typed before
  «Browse», not the folder picked with it (run). «Browse» writes the field's text into the
  shared variable (:59958-59962).
- **15.8. The pre-filled Source** is the folder of the focused file, also when that file is not
  selected, or when it sits in a subfolder of the selection (run). For an index entry that
  names no file on the disk the field holds that entry's folder, and «Proceed» answers
  «Please choose an existing source folder» (read).
- **15.9. The destination folder is looked for again for each file** whose folder already exists:
  `prevuDir` is set only after a folder was created (:3285-3295) (read).
- **15.10. An empty file at the destination** is replaced without being recycled and without the
  «overwritten» mark in the undo record (run): `FileRexists(…, 0)` counts it as absent.
- **15.11. Both «Browse» dialogs have the same title** (read).
- **15.12. No Alt letters**: «Structured file operations» has none in either menu, and the labels
  «Source:», «Destination:», «On file name conflicts:» and «Action to perform:» have none, so
  the fields are reached from the keyboard with Tab alone. The menu bar's File menu offers
  the item only in thumbnails view (read).
- **15.13. The «Source:» label** is not centred on the field's height as «Destination:» is (read).
- **15.14. Unused**: the global `lastInvoked` set at every opening (:60844), and `btnWid`, `txtWid`,
  `lstWid` (read).

---

## Seen in passing

**A. The regular Copy/Move panel** shares two findings: `batchCopyMoveFile()` has no save
question (finding 3), and both its engines recycled before they copied (finding 5, fixed in
`3df8de3`) (read). Its «&Proceed» and «Hel&p» buttons share Alt+P (:60209, :60211) (read).

**B. `recordUndoFileActs()`** dropped the size for every move and rename tool (finding 4, fixed
in `3df8de3`).

**C. No batch tool shows its «Undo» quick-action bar**: the regular panel's batch, pasting, the
batch delete and the multi-rename asked for it while the long operation was still flagged (run for
`batchCopyMoveFile()`, read for the others). The calls are removed in `215b243` (see finding 4).

**D. Pasting files** reported «Finished moving 2 out of 1 files»: it counted the line breaks of
the clipboard text, one fewer than its files (run, batch N). **Fixed in `def941f`**: the total is the
number of lines once the line breaks at both ends are trimmed, so a path counts with or without a
drive letter (a network share gives `\\server\share\…`); the same total drives the progress bar
and the time left shown during a long paste (read). An empty line between two paths still counts
as a file (T3). Run, batch T:

| Clipboard text | At `c088d5d` | On `def941f` |
|---|---|---|
| T1: two files, no line break at the end | «2 out of 1» | «2 out of 2» |
| T2: one file | «1 out of 0» | «1 out of 1» |
| T3: three files, an empty line between, a line break at the end (move) | «3 out of 4» | «3 out of 4» |
| T4: a path with no file, then one file | «1 out of 1», one failed | «1 out of 2», one failed |
| T5: two files, one path without a drive letter | «2 out of 1» | «2 out of 2» |
| T6: two files, neither path with a drive letter | «2 out of 1» | «2 out of 2» |

**E. A folder as the source of a copy or a move.** `FileCopy` and `FileMove` take a folder as the
files inside it (run, a probe on AutoHotkey_H 1.1.33 under Wine). Onto an existing folder they copy or
move those files, without the subfolders, and replace files of the same name without the recycle bin.
Onto a name that does not exist they write every file in turn onto that one name: a copy leaves one
file with the last file's content, a move keeps only the last file. Run at `0ad345c` (batch V):

- A folder in the clipboard, pasted into `out`: its files are copied into `out`, `out\f1.png` is
  replaced (861 bytes, now 361, nothing recycled), `sub\` is left behind.
- An index entry that names a folder, `album.2024`: the regular panel moves its files into the
  Destination the same way; this panel writes them onto `out\album.2024`, and on a move `f1.png` is
  lost.

**Fixed in `6697b4c`** with finding 12 (decision 10): in this panel, the regular panel and pasting, a
source that is a folder counts as failed (:3261, :61635, :61889, :32252). Nothing is copied or moved
(run, the same cases).

## Checked and found correct

- **«Proceed» closes the panel right after a question.** `BtnCloseWindow()` passes "yes",
  which skips the one second during which `CloseWindow()` refuses after a dialog
  (:98358-98362). Run: the panel is closed after every «Proceed» that went through.
- **The overwrite answer kept from the file before**, when the next destination is a folder:
  nothing is recycled (run, finding 12).
- **`UsrCopyMoveOperation` is set to 1 at every opening**: every other user of the variable sets
  it before reading it (read).
- **The panel's Alt letters** B, R, P, H and A are five different letters, and the main
  window's menu bar does not take them: keys pressed in a panel go to `WM_KEYDOWN()`, not to
  the menu bar's letter test (`dispatchKeyDown()`, lib/module-interface.ahk:77) (read).
- **The same folder in the same spelling**, or with only an ending backslash more, is refused
  (run). So is `.\` (run, finding 7).
- **A copy keeps the unsaved edits** of the image on screen (run, finding 3).
- **A right-click in the two fields** opens Windows' own edit menu (run).
- **«Possible source paths» on a usual library**: 60 000 files in 3 000 folders take 0.5 s
  (run); a second press uses the kept list (3 ms).
- **No `lockDestinationFileName()`**: each selected file has a destination of its own; the only
  collisions are those of finding 2 (read).
- **Multi-page preview mode**: both menu items need a selection, which that mode does not
  allow (read).
- **`createSettingsGUI()`'s result is not tested** (:60849). 56 of the 74 panels do the same
  (counted at `b4f374f`). Called within one second of a dialog while a panel is open, the
  panel function adds its controls to the open panel and AutoHotkey shows an error box
  (run); with a panel open, only a user-defined shortcut can call it then (read). Not a
  defect of this panel.
- **Escape and the title bar's X refuse for one second after a dialog**, F1 has no help in
  panels, Quick search opens beside the panel, and private mode hides no paths in any copy
  or move tool: the same in every panel.
- **Switching the dark mode or the large fonts** closes and reopens the open panel, which
  empties the fields: the same in every panel (read).
- **Up and Down** change a field's text only when the whole field is a number (:853), which a
  path never is (read).
- **The conflict box starts afresh**: the engine clears the «Do not prompt again» answer of an
  earlier run (:3228) (read).
- **A-Z in another case**: `InStr()` finds `c:\scoala\` in `C:\Scoala\2026\a.jpg` (run); only
  letters outside A-Z do not match (finding 9, fixed in `f52eaac`).
- **A stopped run on a database list** commits what was done, which keeps the database in step
  with the files already moved (read).
- **The file dates** are copied onto each copy (:3268-3270, :3342-3346) (read).
- **The menu's item number** is read from the text before the first dot, so the `...` of a
  shortened path does not disturb it (read).
- **The two lists line up**: «Action to perform» is created over its label and then moved under
  the other list by `GuiAddDropDownList()` (read).
- **The menu follows the dark theme**, as every menu of QPV does (read).
- **The «Possible source paths» search** cannot match in the middle of a path: every line
  starts with a drive letter; its loop reads one entry past the end, which is empty (read).
- **`FolderExist("C:")`** means the drive's root (:44111-44112), so a bare drive letter behaves
  (read).
- **`getSelectedFiles(0, 1)` twice at opening**: the second call returns the kept count (read).
- **The folder watch is reset** after a copy as after every file action; it is needed when the
  Destination lies inside the open folder (read).
- **A database list asks no needless save question** after a move: every such question asks
  for `SLDtypeLoaded=2`, a list opened from a text list file (read).
- **Captions, audio links, the folders table and the favourites** are not updated by a move,
  as by no other move or rename of QPV (read).
- **The `ResetImgLoadStatus` timer** at the end of building, and the buttons' image list kept
  until the next clean-up, are the same in every panel (read).

## Decisions to make before fixing

Decisions 1 to 7 and 9 to 12 are settled; 8 is open.

1. The same folder (finding 1): compare the folders' file IDs, or only resolve the text
   (`.`, `..`) and leave links, short names and SUBST drives to the per-file test?
   **Settled in `88aa9fc`**: file IDs, and a test of each file in the engine.
2. Nested folders (finding 2): refuse them, or leave out the files under the Destination?
   **Settled in `88aa9fc`**: allowed, unless a selected file is already inside the
   Destination or would land on another selected file.
3. «Overwrite» (finding 5): copy to a temporary name first, or keep the order and list the
   recycled files in the message?
   **Settled in `3df8de3`**: a temporary name first, in every tool that recycled first.
4. Destinations (finding 7): drive-letter paths only? Network paths supported or refused with
   a message? Should the Destination start from the regular panel's text, from
   `prevFileMovePath`, or from this panel's last folder?
   **Settled in `c5cbfe4`**: only full paths with a drive letter, in both fields; network paths
   refused, as in the rest of QPV, with a message that says why; the Destination starts from the
   shared text only when that is such a path, and empty otherwise.
5. «Possible source paths» (finding 10): offer the deepest folder that holds the whole
   selection, the selected files' own folders, or their parents? A parent recreates the
   top folder in the Destination, which may be what the code meant.
   **Settled in `77b5d9c`**: the deepest folder that holds every selected file of a drive, then each
   folder above it; «N of M files» only on entries that hold part of the selection; the menu under
   the button, «Please wait...» removed first, folders without a drive letter left out with a message
   when nothing is left; the list still kept while the panel is open.
6. Fewer than two files (finding 11): work on one file, refuse to open, or say why nothing is
   done?
   **Settled in `cc45e03` and `5410eed`**: «Proceed» says why, and the panel stays open.
7. The undo record (finding 4) changes the records of every move and rename tool. Change it
   for all of them?
   **Settled in `3df8de3`**: yes, for all of them.
8. Finding 15: keep «On file name conflicts» across restarts (15.5)? Add the Destination to the recent
   destinations (15.6)? Start «Action to perform» on the last action (15.4)?
9. The two paths (finding 8): clean up the text alone, or also let Windows resolve it?
   **Settled in `81cbbbe`**: clean up, then resolve.
10. A folder at the destination (finding 12): failed or skipped, and in which tools? With the name of
    a file with no extension taken after the last backslash, and a folder as the source refused?
    **Settled in `6697b4c`**: failed, in every tool that has the test; yes to both.
11. The spelling of «Possible source paths» (finding 9)?
    **Settled in `f52eaac`**: the index's.
12. Which destinations may «Proceed» offer to create (finding 14)?
    **Settled in `87c699d`**: a path under the root of an existing drive. Since `c5cbfe4` an existing
    folder without a drive letter is refused as well (decision 4).

What is left: 11 (the handler), 15 (decision 8).

## How this was checked

- Static reading of `development` at `b4f374f`: the panel, its buttons, its menu, the routes
  that open it, the handler, the engine, and each helper before a call to it was judged.
- The real application under headless Wine, started on one image, with test functions appended
  to a scratch copy of the script. A test builds a folder tree, opens it as a files list,
  selects files, opens the panel, fills its four controls and posts a click to «Proceed»;
  the handler and the engine then run as they are. The log keeps the messages on screen, the
  files on the disk, the recycle bin, the index and the undo records. The scratch copy
  differs from the source in that messages, tooltips set on controls and a few calls are
  logged, and the folder dialog and the «Possible source paths» menu return or log a set
  answer instead of waiting for the user.
- The twelve batches of 2026-11-10 (A to H, F3, F5, F7, F8) were run again on `b4f374f`. Their
  logs match those of `ab160cb` but for time stamps, window handles, and the current file of
  the database list in batch H.
- Four new batches, run on `b4f374f`: I (the regular panel's patterns in the Destination, a
  Source file that cannot be read with «Overwrite»), K (a link to the Source folder, a SUBST
  drive, a folder at the destination after an overwritten file, more than 150 files with a
  destination to create), J (the time of «Possible source paths» on large selections) and L
  (an edited image and a copy).
- Aids, each named where it was used: index entries written by the test (finding 10, the
  file without an extension in finding 12); an edited image simulated by setting its state
  (finding 3); a Source file held open with no sharing (finding 5); a Linux symbolic link
  standing in for a Windows junction (finding 1).
- Not run on Windows. Four points rest on Windows itself: that a doubled backslash names
  nothing through the `\\?\` prefix (it decides which spellings in finding 1 lose files);
  that a junction, a short name and a SUBST drive behave as the Linux link did; that two
  spellings of a folder that differ in the case of «Ș» name one folder (finding 1); and the
  timings of finding 10.
- The fixes, on 2026-11-14: batches A to H, F3, F5, F7, F8, I, K and L were run on `ed8848c`
  and again on `88aa9fc`, and each log was compared with the one before it. They differ in
  the cases of findings 1 and 2 alone, apart from the line numbers an error box quotes, a
  window handle, and the current file of the reopened database list in batch H. Batch M was
  added: the nestings that are allowed, a collision and a new folder through a link, and the
  test of each file through a linked subfolder. Batch G, run on `ed8848c`, checks finding 3.
- The fix of findings 4-6, on 2026-11-14 (`86c89e1` completes it: batch R, then N, O, P, H and C
  again, as on `3df8de3` but for the marks of batch R and the current file of batch H): batches A
  to H, F3, F5, F7, F8, I, K, L and M were run
  at `02046f3` and on `3df8de3`. Their logs differ only where findings 4-6 change them (undo records
  that hold the replaced file's size or `|0`, the undos of batch C, I3, batch H), apart from the
  line numbers an error box quotes and the current file of the reopened database list in batch
  H. Three new batches, run at `02046f3` and on `3df8de3`: N (plain and database lists, the
  destination held open, the refused recycle and rename, the regular panel's two engines, a
  marked entry, pasting), O (the multi-rename, the single rename, undos onto a listed file, a
  deleted Source subfolder) and P (a filtered list). Batch Q (the quick-action bar) ran on
  `3df8de3` and on a copy that asks for the bar from a timer. The copy and rename kit of
  2026-11-08 gives the same files and the same recycle bin on `3df8de3` as at `02046f3`.
- The scan of the one-file tools (`eda5812`): batch S was added; batches S, R, N, O, C, M, P and H
  were run on `824cf63` and on `eda5812`, and their logs are the same, apart from the image reloads
  a timer makes, the image details the conflict box shows when they load in time, the names
  Wine's trash gives, a device context, the times and the current file of the reopened database
  list in batch H. A harness under Wine ran the old and the new `markReplacedListEntry()` side
  by side on 12 000 random lists, per call and through a run's map. A copy that logs each call
  (batches R and N) shows the batch tools and the batch undo with the map, and the one-file
  tools and the one-file undo with the scan.
- The paste count (`def941f`): batch T was added (six pastes into a new folder; in T5 and T6
  Wine's `\\?\unix\…` paths stand in for a network share's, which have no drive letter either).
  Run at `c088d5d` and on `cfed87c` (a loop over the non-empty lines: every count right),
  `cccc913` (a count of `:\`, which leaves out T5 and T6: «2 out of 1», «2 out of 0») and `def941f`;
  the logs differ only in the «out of» messages.
- The fixes of 2026-11-15 (findings 8, 9, 12, 13 and 14; finding 11 at `0ad345c`): batches A to
  E, G, H, I, K, L, M, N, O and T were run at `0ad345c` and on the fix. In batches A, I and K the
  cases where a question may or may not come now wait 7 s, so that an answer nobody took expires
  before the next case, and I7 answers the 150 files question first. Batch V was added: the spellings
  of finding 8, the letter case of finding 9 with both folder tests, a folder at the destination in
  the six tools, a file with no extension, a folder as the source, finding 13, and the save question
  of finding 11. Batches C, G, H, L, M, O and T give the same logs; the others differ where the fixes
  change them, as the fixed sections list. Batch N differs only in run-to-run noise: the current
  file of the reopened database list and the image loads that follow from it, a device context, and
  in one run one more «Confirm file deletion» line from `closer.ahk` (another run gives the same log
  as `0ad345c`). The batches ran on the text of `6697b4c`
  but for the message of the one-file move (:61758); batches V and N, which reach it, ran again on
  `6697b4c` itself. Each of the five commits loads with AutoHotkey_H (with and without `/iLib`) and with
  stock AutoHotkey 1.1.37 (`/iLib`).
- Not checked: a read-only file moved to another volume, and a folder name ending in a dot.
- The fix of finding 10 (`77b5d9c`): batches D, E, F8, J and X were run at `5398a53` and on
  `77b5d9c`. Batch X was added: the button pressed in the open panel, each entry chosen, where the
  real menu opens (a native timer reads the menu window and closes it with `EndMenu`), and more
  index entries written by the test. In the scratch copy the stubbed menu now also logs the control
  it opens under and whether «Please wait...» is shown. Batches D, F8, J and X differ where the fix
  changes them. Batch E differs in its menu and in the current file of the reopened database list,
  run-to-run noise; E1 copies the same files. `77b5d9c` loads with AutoHotkey_H (with and without
  `/iLib`) and with stock AutoHotkey 1.1.37 (`/iLib`).
- Kit: `.claude/scratch/structured-copy-move-2026-11-14/app/`: `run-app.sh <tag> <test
  function>`, `run-k.sh <tag>` and `run-m.sh <tag>` (make the links batches K and M need),
  `run-all-old.sh [tag]` (the twelve old batches), `norm.sh` (compares logs),
  `test-wrappers-sc.ahk` (testScA to testScX; batch W, the paths of finding 7's last note, has not
  run yet; `test-wrappers-sc.before-0ad345c.ahk` is the one
  the logs up to `def941f` ran), `run-set.sh <tag> <source> <batches>`, `results/` (`<batch>-hd.txt` on `b4f374f`,
  `-ed8` on `ed8848c`, `-fix` on `88aa9fc`, `-b46` on `02046f3`, `-f46` on `3df8de3`, `r-3df`, `-f2` on `86c89e1`, `-h3` on `824cf63`, `-s3` on `eda5812`; `i1`, `j1`,
  `k1`, `l1` on `b4f374f`; `t-c08` on `c088d5d`, `t-pst` on `cfed87c`, `t-ccc` on `cccc913`, `t-trm` on `def941f`; `-b15` at `0ad345c`, `-f15` and `n-f15b` on the fix but for the one-file move's message, `v-f15c` and `n-f15c` on `6697b4c`; `-b10` at `5398a53` and `-x10` on `77b5d9c`, batches D, E, F8, J and X), `results-1110/` (the logs of 2026-11-10). For batches N to S:
  `closer.ahk`, a second process that answers Wine's «Confirm file deletion» with «No»; in
  `patch.py`, `scRecycleFail` and `scRenameFail` (the simulated refusals) and
  `scRestoreAnswer=2` (the restore from Wine's trash); the conflict box is answered from a
  native timer (`scArmBoxAnswer()`), as it waits in a Critical loop. `../fix46/apply.py` made
  `3df8de3` from `02046f3`. `../scan/`: `apply3.py` (made `eda5812`), `run-scan.sh` (both sides),
  `norm2.sh` (also drops the run-to-run noise), `b46-stub.ahk` (`02046f3` with a stub
  `mapListPaths()`, which batch R calls), and the harness (`build-parity.py`,
  `parity-driver.ahk`, `runahk.sh`), `fixed3-trace.ahk` (logs each call; `r-tr`, `n-tr`), the
  timing and the interpreter probes. `../fix15/`: `apply.py` (makes the five commits' files from
  `0ad345c`), `report.py` (this status), `probe-copy.ahk` (`FileCopy` and `FileMove` with folders,
  Seen in passing E) and `check-stages.sh` (the load checks). `../fix07/apply.py` makes `c5cbfe4`
  from `4bda394`; `../fix10/apply.py` makes `77b5d9c` from `5398a53`. `patch.py` stubs the
  «Possible source paths» menu in both its forms, before and after `77b5d9c`.

## Gemini's findings in this report

The numbers are those of `structured-copy-move-audit-2026-11-10.md`; the row ids in brackets
are those of its «Every claim» table.

| Gemini | Here | Note |
|---|---|---|
| 1 | 1, 8 | scenario A is finding 1 (only `.`, `..`, links and letter case lose files); scenarios B and C are finding 8 |
| 2 | 2 | |
| 3 | 4 | (3.3) quick-action bar and (3.2) emptied subfolder are in finding 4 |
| 4 | 3 | a copy keeps the edits |
| 5 | 7 | (5.5) in finding 7 |
| 6 | 7 | (6.3) in finding 7 |
| 7 | 9, 1 | (7.2) is finding 1 |
| 8 | 12 | (8.1) is in finding 12; no loader admits a file with no extension |
| 9 | Checked and found correct | |
| 10 | 5, 15.10 | (10.2) is 15.10; (10.3) not checked; (10.4), (10.5) found correct |
| 11 | 10 | (11.4) in finding 10 |
| 12 | 10 | (12.3) found correct |
| 13 | 11, 15.12 | (13.1) not reachable; (13.3) is in 15.12 |
| 14 | 11 | |
| 15 | 6 | (15.2), (15.3) generic; (15.4) false |
| 16 | 7, 15.7 | (16.2) is 15.7 |
| 17 | 15.4, 15.5, 15.6 | (17.1) is 15.5, (17.2) 15.4, (17.3) 15.6; (17.4) generic |
| 18 | 15.8 | (18.4) in 15.8; (18.3) false |
| 19 | 13 | |
| 20 | 14 | |
| 21 | 15.1 | |
| 22 | 10 | (22.4): the menu follows the dark theme, found correct |
| 23 | Checked and found correct | false: the fields open Windows' menu |
| 24, 25 | Checked and found correct | generic; (24.3) not a defect |
| 26 | 15.2, 15.9 | (26.2) is 15.9; (26.1b) false; (26.3) found correct |
| 27 | 15.3, 15.12, 15.13, 15.14 | (27.1) and (27.5) are 15.14 |
| 28 | 15.11 | (28.2), (28.3) generic |
| S1 | 4 | |
| S2 | 15.1 | |
| S3, S4 | 15.10, 7 | |
| S5 | Checked and found correct | generic |
| «Checked and found correct» | Checked and found correct | agreed; the Ctrl+Backspace item was not checked |

New here: the link to the Source folder (finding 1), the file that cannot be read under
«Overwrite» (finding 5, run where Gemini read it), the regular panel's patterns `\folder` and
`.\folder` (finding 7), the library case and the time of «Possible source paths» (finding 10),
the folder left after «No» at the 150 files question (finding 11), and the shared Alt+P of the
regular panel («Seen in passing» A).
