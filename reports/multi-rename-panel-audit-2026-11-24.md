# «Rename multiple files» panel audit, 2026-11-24

Scope: `PanelMultiRenameFiles()` (:41091) and the panel it builds: the pattern box and its history, «Insert»,
«Examples», «Erase history», the preview list and its four page buttons, «Preserve original file date and
time», the collision drop-down, «Check all files», «Rename files», «Solo rename», «Help» and «Cancel». The
audit also covers what those controls run, and the routes that open the panel. The handlers are:

- the preview: `uiPopulateLVmultiRename()` :41782, `UIlvMultiRenameResponder()` :41736, `UImultiRenameChangeLVoffset()`
  :41163, `UImultiRenameCollisionAction()` :41223, `UIgenericComboAction()` :41519;
- the menus: `BtnMultiRenameMenus()` :41398, `MenuAddEditMultiRenameAction()` :41477;
- the checks: `BTNmultiRenameCheckAll()` :41267, `multiRenameFileStatus()` :41246, `multiRenameSummary()` :41227;
- the rename: `coreBatchMultiRenameFiles()` :41944, and `BTNdoSoloRename()` :41149, which hands over to
  `PanelRenameThisFile("single")` :44290;
- the history: `readRecentMultiRenameEntries()` :41076, `RecordUsedMultiRenamesQueriesManager()` :42189,
  `EraseMultiRenameHisto()` :42217;
- the helpers, as far as a panel action reaches them: `decideMultiRename()` :41537, `decideFinalMultiRename()` :41675,
  `askAboutFileCollision()` :44207, `lockDestinationFileName()` :38965, `isSameFileOtherCase()` :63543,
  `replaceFileByCopyMove()` :32945, `renameFileCaseOnly()` :32913, `markReplacedListEntry()` :34050.

Line numbers are `quick-picto-viewer.ahk` on `development` at `468aef9`. The audit changed no code.

Eight findings, a list of small things (row 9 of the summary) and four things seen in passing. Each one
says how it was checked: **run** means the real application did it under headless Wine, on the stock
AutoHotkey 1.1.37.02; **read** means it follows from the code and was not run. Nothing was run on Windows.
Each run carries a tag such as A1 or E3: the letter names its batch (listed under «How this was checked»),
and the tag marks its lines in the kit's logs.

Earlier work on this panel is not reported again: the 2026-11-08 menus, Status column and «Check all files»
(`aa90f56`, with Marius's corrections in `a20625d`); the history and paging fixes (`4714558`); the
2026-11-09 audit of `decideMultiRename()` and `decideFinalMultiRename()` (`2d250a0`..`6efe1a4`); the
2026-11-13 «Same new name as #N» outcome and the folder-held names (`95b29d8`, `25c77c6`); the RegEx work of
2026-11-13 (`854a97f`, `6ce1a90`, `38a9160`, `3d9f287`). The choices settled there stay as they are: see
«Settled earlier, not reported again». Finding 5 takes in the second of the two defects left open on
2026-11-13; the first one no longer holds («Seen in passing» D).

**Status, 2026-11-25.** Every batch was run again at `7ee44f5`, except E and E4. A new batch K replaces them:
it runs finding 1 with «Cancel» and «Discard» on each route, and «Save» on «Rename files».

- Finding 1 is fixed in `2663c62` («Rename files») and `1ce44b5` (the double-click and «Solo rename»), by
  Marius.
- Finding 2 is fixed in `0433cd3`, by Marius, for the batch, and in `7ee44f5` for the preview and «Check all
  files».
- Finding 8 is fixed in `2663c62`, by Marius.

Findings 3 to 7, small things 9.1 to 9.7 and «Seen in passing» A give the same outcomes as at `468aef9`.
Small things 9.8 and 9.9 and «Seen in passing» B and C were read again: their code is unchanged.

Sections 1, 2 and 8 end with what was run again and a note on what the code does now. Those notes cite
lines at `7ee44f5`; the other line numbers stay those of `468aef9`.

**Status, 2026-11-26.** Before any fix, the batches were run again at `6a66bf9`: findings 3 to 7 give the same
outcomes as at `7ee44f5`. Marius chose to fix findings 4 and 7 and to leave 3 and 5 open. Later that day, after
finding 5 was run again at `96feeef` with the same outcomes, he chose two of the six fixes offered for it
(decision 5).

- Finding 4 is fixed in `e06ea0a`: a plain name's number passes over the names in use.
- Finding 7 is fixed in `e88f125`: the «Invalid RegEx» row leaves # empty.
- Since `bccc022`, at Marius's word, a later preview page counts the files before it cheaply again: as fast as
  before, and its plain-name numbers can be lower than those the batch gives.
- Finding 5 is fixed in part in `82cdeeb`: under «Overwrite» a selected file still at its old name is no longer
  replaced, and the preview and «Check all files» follow the batch's order. Shifts and swaps still end skipped
  or with «[1]» names.

Three new batches, L, M and N, run renumberings, cycles, database lists, undo and plain names (see «How this was
checked»). Their runs at `6a66bf9` record more shapes of finding 5. Sections 4 and 7 end with what was run and a
note on what the code does now; those notes cite lines at `e06ea0a`. Section 5 ends the same way, with a new
batch Q, and cites lines at `82cdeeb`.

## Terms

- **The panel**: panel 8, «Rename multiple files». It opens from `PanelRenameThisFile()` when two or more files
  are selected (:44299-44303). Its routes: F2 (:2016-2018), the File menu's «Rename file(s)» (:68636), the files
  actions menu's «Rename file(s)» (:70752), the toolbar's «Rename file(s)» button (`BTNmodifyEntry`,
  :106544-106545), and «Multi-rename»
  in the single file rename box (:44327-44329).
- **The pattern**: the text in the box, as `decideMultiRename()` reads it. A **plain name** is a pattern with no
  `[this]`, no `[counter]`, no `trim{}`, no `//`, `\\` or `>>`: the files take that name with « (N)» added,
  counted per folder.
- **The preview**: the list under the box, filled one page at a time by `uiPopulateLVmultiRename()`. Its
  **status** is the third column («OK», «Name taken: …», «Same new name as #N: …» and the like).
- **«Check all files»**: the button that counts the statuses over all the selected files, and the **summary**
  line under the list where it writes them.
- **The batch**: `coreBatchMultiRenameFiles()`, run by «Rename files». It renames the selected files one after
  another, in list order.
- **The collision action**: the drop-down «Action on file name collisions»: «Skip files», «Auto-rename»,
  «Overwrite» or «Ask user». **The conflict box** is the question «Ask user» shows for each collision.
- **An edited image**: the image on screen with unsaved changes (`currentImgModified=1` and undo levels).
- **A database list**: a files list opened from an `.SLDB` file (`SLDtypeLoaded=3`); a **plain list** is any
  other.

## Summary

| # | Finding | Harm | Checked | Status |
|---|---------|------|---------|--------|
| 1 | An edited, unsaved image is discarded without the save question: by «Rename files» when it is among the renamed files, by a double-click on another row, by «Solo rename» on another row | high | run | **fixed**: «Rename files» in `2663c62`, the double-click and «Solo rename» in `1ce44b5`, by Marius |
| 2 | `case{U}`, `case{L}` and `case{T}` on a name with non-ASCII letters: the file collides with itself | medium | run (Wine) | **fixed**: the batch in `0433cd3`, by Marius; the preview and «Check all files» in `7ee44f5` |
| 3 | On a database list, the parts of the old name that the new name keeps come out in lowercase on disk, the extension too | medium | run | open |
| 4 | A plain name with «Overwrite», or «Ask user» answered «Overwrite», skips the file; the status and the summary say «overwrite» | medium | run | **fixed**, `e06ea0a`: the number passes over the names in use |
| 5 | The batch meets the names of the other selected files as they change, while the preview judges each file against the disk as it was: names freed earlier read «taken»; under «Overwrite» a selected file is recycled before its own turn | medium | run | **partly fixed**, `82cdeeb`: «Overwrite» no longer replaces a selected file, and the preview and «Check all files» follow the batch's order; shifts and swaps still end skipped or with «[1]» names |
| 6 | A renamed favourite keeps its mark on the new name, and the favourites keep the old path | low | run | open |
| 7 | The «Invalid RegEx» row acts as a file: a double-click sets the current index to «-», «Solo rename» offers the list's first file | low | run | **fixed**, `e88f125` |
| 8 | A preview timer that fires after the panel closed re-creates a hidden panel window, and empties the list of a list panel opened meanwhile | low, narrow | run | **fixed**, `2663c62`, by Marius |
| 9 | Small things, numbered 9.1 to 9.9 | low | run and read | open |

The rows give the status at `82cdeeb`.

Finding 1 loses work for good. Findings 2 and 3 rename files to names the user did not ask for, and say
nothing about it. Findings 4 and 5 do something else than the preview and the summary announce; in finding 5
that can mean a selected file in the Recycle Bin. Findings 6 to 8 leave stale state behind. Findings 1, 2, 4,
7 and 8 are fixed, and finding 5 in part.

---

## 1. An edited, unsaved image is discarded without the save question

`coreBatchMultiRenameFiles()` :41944-42187, its redisplay `dummyTimerDelayiedImageDisplay(100)` :42179;
`UIlvMultiRenameResponder()` «DoubleClick» :41768-41771; `BTNdoSoloRename()` :41149-41161

No route of this panel calls `askAboutFileSave()`. The single file rename asks it (:44348), and so do the two
copy/move panels (`BTNuiProceedStructuredOperation()` :61654, `BtnCopyMoveAction()` :62025) and «Remove filters»
(:33238).

- **«Rename files»**: the batch renames the files, then redisplays the current entry at its new path (:42179).
  Loading that path ends the editing.
- **A double-click on a row**: the handler sets `currentFileIndex` to the row's file and redisplays it
  (:41770-41771), while the panel stays open.
- **«Solo rename»**: the handler sets `currentFileIndex` to the highlighted row's file and redisplays it before
  it opens the rename box (:41155-41158). `PanelRenameThisFile()` asks the save question only after a name is
  typed (:44348), and by then the other image is on screen.

Runs, with the edited image simulated by its state (a bitmap, five undo levels, `currentImgModified=1`) on
file #1 of three, the pattern `[this]-x`:

- **E1**, «Rename files» with #1 among the renamed files: «Finished renaming 3 out of 3 selected files», then
  `IDshowImage(1)` loads a-x.png and `terminateIMGediting()` runs with the five undo levels. Afterwards there
  is no edited bitmap and no undo level. No save question was asked.
- **E2**, a double-click on row 2: b.png is shown and `terminateIMGediting()` runs with the five undo levels.
  The edits are gone; the panel is still open.
- **E3**, «Solo rename» with row 3 highlighted, the rename box then cancelled: c.png is shown before the box
  comes up, and the edits are gone.
- **E4**, the control: #1 edited and not selected, #2 and #3 renamed. The redisplay loads a.png again and the
  edits survive.

So «Rename files» loses the edits only when the edited image is among the renamed files; the double-click and
«Solo rename» lose them whenever the row is another file's.

Run again at `7ee44f5` (batch K: «Cancel» and «Discard» on each route, «Save» on «Rename files»): fixed.

- **«Rename files»**, #1 among the renamed files: «Cancel» (K1) renames nothing and keeps the edits, the current
  file and the open panel. «Discard» (K2) renames the three files and ends the editing. «Save» (K3) closes the
  panel, calls the save panel (a log line in the kit) and renames nothing.
- **A double-click on row 2**: «Cancel» (K4) keeps a.png and its edits on screen; «Discard» (K5) shows b.png.
- **«Solo rename»** with row 3 highlighted: «Cancel» (K7) keeps a.png, its edits and the panel; «Discard» (K8)
  shows c.png, and the rename box offers c.png.

**Fixed in `2663c62` and `1ce44b5`**, by Marius. `coreBatchMultiRenameFiles()` asks after the pattern checks,
before the panel closes (:41978). The double-click asks before it sets `currentFileIndex` (:41775), and
`BTNdoSoloRename()` before it reads the highlighted row (:41152). The question comes whenever the image is
modified, so it also comes where nothing would be lost: when the edited file is not among the renamed files
(K9, the layout of E4), and on a double-click on the edited file's own row (K6). There «Discard» leaves the
edits in place, because the image on screen does not change.

---

## 2. `case{…}` on a name with non-ASCII letters: the file collides with itself

`isSameFileOtherCase()` :63543-63557 (`If (fileA==fileB || !(fileA=fileB))` :63550); `multiRenameFileStatus()`
:41260; the batch :42076-42123

A change of letter case alone is recognized by `isSameFileOtherCase()`, and the status by `newPath=srcPath`.
Both use `=`, which folds the case of ASCII letters only: `été.png` and `ÉTÉ.png` are «different» for them. The
file system folds both, so `FileExist("…\ÉTÉ.png")` finds `été.png` itself, and the batch treats the file as
its own collision (:42084-42086). Romanian, French and German names are hit: ă, î, ș, ț, é, ü…

Runs, `case{U}` on été.png, ăîșț.png and abc.png, under each collision action (C1-C4). The probe line of each
run shows `FileExist(ÉTÉ.png)=A`, `isSameFileOtherCase()=0` and `"été"="ÉTÉ"` false.

- **Skip** (C1): the preview reads «Name taken: skip» for été.png and ăîșț.png, «Check all files» says «Will be
  renamed: 1. Names taken (skip): 2», and the batch renames abc.png alone: «Skipped files: 2».
- **Auto-rename** (C2): the two files become «ÉTÉ [1].png» and «ĂÎȘȚ [1].png».
- **Overwrite** (C3): `replaceFileByCopyMove(été.png, ÉTÉ.png)` moves the file to a temporary name and then
  recycles the destination, which is the file just moved away. Wine's shell asked «Confirm file deletion»
  for each (the kit answered No); the files then took their new names, and the message said «Overwritten
  files: 2» though nothing was overwritten. On Windows the recycle of a name that no longer exists most
  likely fails, and the function then moves the file back and reports a failure. Not run on Windows.
- **Ask user** (C4): one conflict box per file, showing the file as its own destination.
- abc.png is renamed through `renameFileCaseOnly()` in all four runs.

`Format("{:L}", …)` folds É and é and never changes a string's length (run under Wine on 2026-11-14, every BMP
character); `mapListPaths()` and `scanListPath()` compare paths that way. The single file rename
(`BTNrenameSoloFileAct()` :48328) and the undo of file actions (`corefileUndoAction()` :95966) call
`isSameFileOtherCase()` too, so they likely share this finding (read).

Run again at `7ee44f5` (C1-C4): fixed. Every row reads «OK», and «Check all files» says «Will be renamed: 3».
Under each collision action, été.png and ăîșț.png go through `renameFileCaseOnly()` and become ÉTÉ.png and
ĂÎȘȚ.png: «Finished renaming 3 out of 3 selected files», with nothing skipped, overwritten or recycled.

**Fixed in `0433cd3`**, by Marius, **and `7ee44f5`**. `isSameFileOtherCase()` compares the two paths lowered
by `Format("{:L}", …)` and asks `isSameIdentityFile()` whether they name one file (:63556). The status
compares the lowered new path with the lowered source path (:41265). The single file rename
(`BTNrenameSoloFileAct()` :48335) and the undo of file actions (`corefileUndoAction()` :95950) call the same
helper, so they are fixed with it (read, not run).

---

## 3. On a database list, the kept parts of the old name come out in lowercase

The list's paths: `SELECT imgidu, imgfolder||'\'||imgfile …` (:88507), stored lowered by `addSQLdbEntry()`
(:34352-34353) and `updateSQLdbEntryPath()`; the batch splits them with `zPlitPath()` (:42019)

On a database list every path in the list is the lowered one. The batch builds the new name from it: `[this]`,
the text around a found string, the text `trim{}` keeps, and the extension. All of them come out in lowercase,
and the file on disk is renamed to that spelling. The preview shows the lowered names in its Original column,
so nothing tells the user the spelling on disk will change.

Runs, the files IMG_0001.PNG and Photo Mixed.Png, once as a plain list and once saved and reopened as a
database list:

| Pattern | Plain list (B…plain) | Database list (B…db) |
|---------|----------------------|----------------------|
| `[this]-x` (B1) | IMG_0001-x.PNG, Photo Mixed-x.Png | img_0001-x.png, photo mixed-x.png |
| `$.jpeg` (B2) | IMG_0001.jpeg, Photo Mixed.jpeg | img_0001.jpeg, photo mixed.jpeg |
| `IMG_//Pic_` (B3) | Pic_0001.PNG | Pic_0001.png |

The extension change of B2 lowers the whole name, and the replacement of B3 lowers the extension. A file the
pattern leaves unchanged keeps its spelling (B3: Photo Mixed.Png).

---

## 4. A plain name with «Overwrite» skips the file

`coreBatchMultiRenameFiles()` :42098-42109 (`mustReplace := (performOverwrite=1 && objuTemp.renamingCount!=1 &&
thisFileExists=1)` :42100); the status :41918; the summary :41382

For a plain name, a destination that exists is never replaced: `mustReplace` wants `renamingCount!=1`, and the
file is then counted as skipped (:42105-42108). The rule dates from 2019 (`e0e1c6d`), when «Overwrite» removed the
old file with `FileDelete`; `4e9b180` (2023) carried it over. The preview, «Check all files» and the conflict box
all offer or announce «overwrite».

Runs, the plain name `holiday` on a.png and b.png, with holiday (1).png and holiday (2).png already on disk:

- **A1**, «Overwrite»: both rows read «Name taken: overwrite», and «Check all files» says «Names taken
  (overwrite): 2». The batch: «Finished renaming 0 out of 2 selected files | Skipped files: 2». The four files
  are unchanged.
- **A2**, «Ask user»: a conflict box for each file, both answered «Overwrite». The same result: «Skipped files:
  2», nothing replaced.
- **A3**, the control: `[this]-x` with a-x.png on disk, «Overwrite». The old a-x.png goes to the Recycle Bin and
  a.png takes its name: «Overwritten files: 1».

Run again at `6a66bf9` (A1-A3): the same outcomes. The new batches add plain names in more shapes, also run at
`6a66bf9` under each collision action:

- **L4**: c.png listed before holiday (1).png and holiday (2).png. Only holiday (2) is renamed, to (3); under
  «Auto-rename» the other two also become «holiday (1) [1]» and «holiday (2) [1]».
- **M1**: the layout of A1. Nothing is renamed, except under «Auto-rename», which gives the «[1]» names.
- **M4**, «Skip», holiday (2) held: a.png becomes holiday (1), b.png is skipped.

**Fixed in `e06ea0a`**, as Marius chose: a plain name never meets a taken name. At each file's turn,
`multiRenamePlainNext()` (:41753) moves the number up past every name in use, whoever holds it: a file outside the
selection, a selected file not renamed yet, a folder, an earlier file's new name. Names that earlier files freed
are used again, so the numbers still rise in list order. The batch reads the disk as it is at that turn (:42124).
The preview and «Check all files» count the same way (:41963, :41366), with the names that earlier files free and
take, which the disk does not show yet; their rows read «OK» (`multiRenameFileStatus()`, `nameFree`, :41263). A
later preview page counts the files before it by number only, for speed (`bccc022`), so its plain-name numbers
can be lower than the batch's (see the end of this section). The batch's `mustReplace`
(:42176) and its undo marker (:42218) no longer exempt plain names, as in the other tools: a plain name now meets
a taken name only when another program takes it during the batch.

Runs at `e06ea0a`, with no conflict box. M1 and L4 were run under all four collision actions and N1 under «Skip»,
«Overwrite» and «Ask user», each with the same outcome under all of them; M4, N2 and N3 were run under «Skip», N4
under «Overwrite»:

- **A1**, **A2**, **M1**: a.png and b.png become holiday (3) and holiday (4); holiday (1) and (2) stay.
- **M4**: a.png becomes holiday (1) and b.png holiday (3).
- **L4**: c.png becomes holiday (3), holiday (1) becomes (4), holiday (2) becomes (5). A selected file waiting for
  its turn still holds its number, as the batch keeps list order (finding 5).
- **N1**: holiday (1), (3) and (7) become (1), (2) and (3), as at `6a66bf9`; the row of holiday (7) now reads
  «OK» where it read «Name taken».
- **N2**: four files, holiday (1) held: holiday (2) to (5). The page after the first two files showed holiday (4)
  and (5) at `e06ea0a`, as the whole list does; since `bccc022` it shows holiday (3) and (4).
- **N3**: a missing file takes its number without the search, as the batch counts it: «Not found», then holiday
  (2) and (3), as at `6a66bf9`.
- **N4**: two folders. In the first, where holiday (2) is held, a.png and b.png become holiday (1) and (3); in
  the second, where a folder is named «holiday (1).png», c.png and d.png become holiday (2) and (3).
- **A3**, the control, is unchanged.

Batch P, «Skip», at `6a66bf9` and at `e06ea0a`, runs three shapes the batches above leave out:

- **P1**: `[pfdname]` alone, in folder trip, trip (1) held by a file outside the selection. At `6a66bf9`, a.png
  was skipped and b.png became trip (2); now a.png and b.png become trip (2) and (3).
- **P2**: `case{U} holiday`, HOLIDAY (1) held. At `6a66bf9`, a.png was skipped; now they become HOLIDAY (2) and
  (3).
- **P3**: a database list, a.png, b.png and holiday (1).png, all selected. At `6a66bf9`, a.png was skipped and
  the other two became holiday (2) and (3); now the three become holiday (2), (3) and (4). The database holds
  their three rows at the new paths.

**A later preview page: the cost, then the speed back.** At `e06ea0a`, a later page named a plain name's files
before it in full, with a disk check each, and the page's 1-second and 5-second limits did not reach that pass.
In P4, 3,000 files with holiday (1) held, under Wine, the page after 2,990 files took 2,855 ms, against 73 ms at
`6a66bf9`, and showed holiday (2992) for f2991, as the batch gives. Marius preferred the speed: since `bccc022`
the files before the page take their numbers by count again, as at `6a66bf9`, and that page takes 71 ms and
shows holiday (2991) for f2991, a number the batch then raises. The first page (1,015 to 1,020 ms) and «Check
all files» (2,815 to 2,896 ms) cost the same at the three revisions. Not measured on Windows.

---

## 5. The batch meets the other selected files' names as they change; the preview does not

The batch's loop :41998-42156, which checks each destination on disk when its turn comes (:42069, :42099);
the statuses :41246-41265, which check the disk as it is before the batch (:41263)

The batch renames in list order, so by the time a file's turn comes, earlier files have freed their old names
and taken new ones. The preview and «Check all files» test each new name against the disk as it is, plus the
new names of earlier rows. They miss the names that earlier files free, and they do not know that a name held
by a later selected file is about to be freed. Three outcomes follow, all run:

- **a. A name freed earlier reads «taken».** `[pfdname] [counter]` on «x 2.png», «x 3.png» in folder x (A4):
  #2's row reads «Name taken: skip» (or «overwrite», «ask»), «Check all files» says «Will be renamed: 1.
  Names taken: 1», and the batch renames both: «Finished renaming 2 out of 2». Under «Ask user» no box comes.
- **b. Under «Overwrite», an earlier file recycles a later selected file.** A swap: «x 2.png», then «x 1.png»
  in list order, renumbered (J1.3). #1 takes «x 1.png» and recycles #2's file; #2's entry is then marked
  deleted and never renamed. One file is left on disk, the other is in the Recycle Bin, and the message says
  «Finished renaming 1 out of 2 selected files | Overwritten files: 1». Under «Skip» (J1.1) nothing is renamed.
- **c. A later file whose own new name only changes the letter case** (the defect left open on 2026-11-13):
  `case{L} IMG_//` on IMG_photo.png and Photo.png (H2). Both want photo.png. #1 meets Photo.png, #2's file, on
  disk; #2 is a case-only rename and passes the collision check.
  - «Skip» (H2.1): #1 is skipped and #2 becomes photo.png; #2's row said «Same new name as #1: skip».
  - «Auto-rename» (H2.2): #1 becomes «photo [1].png» and #2 photo.png; #2's row said «…: auto-rename».
  - «Overwrite» (H2.3) and «Ask user» answered «Overwrite» (H2.4): #1 recycles Photo.png and takes its name;
    #2's entry is marked deleted. #2's row said «Same new name as #1: auto-rename».

The protection of 2026-11-08 (`7bb9721`, `lockDestinationFileName()`) covers the names the batch wrote
earlier, and the names of selected files the pattern leaves unchanged; it does not cover selected files still
waiting for their turn.

Plain names are outside this finding since `e06ea0a` (section 4): their numbers pass over the names in use at
each file's turn, and the preview and «Check all files» count them as the batch does, except on a later preview
page since `bccc022`.

Run again at `96feeef`, before the fix (A, H, J, L, M): the same outcomes. Batches L and M, first run at
`6a66bf9`, add two consequences of b:

- **The later numbers drop.** A downward shift, a.png, x 1, x 2 and x 3 renamed to x 1 to x 4 under «Overwrite»
  (L1.3): #1 recycles x 1.png, #2's entry counts as deleted, and `[counter]` (the selection position less the
  deleted entries) falls by one for #3 and #4, which get their own names back: «Finished renaming 1 out of 4
  selected files | Skipped files: 2 | Overwritten files: 1».
- **A database list loses a row.** `moveSQLdbEntry()` deletes the row that already holds the new path: the shift
  and the swap on a database list (M5, M6) end with 2 rows of 3 and 1 row of 2.

**Fixed in part in `82cdeeb`**, by the two fixes Marius chose of the six offered (decision 5):

- **The batch** (`coreBatchMultiRenameFiles()` :42089, :42185-42194): under «Overwrite», a new name held by a
  selected file still at its old name gets an auto-renamed name, as the batch's own outputs do since `7bb9721`.
  No selected file goes to the Recycle Bin, so the later numbers no longer drop and database lists keep their
  rows. Under «Ask user», the conflict box starts with «The destination is a selected file, not renamed yet.»,
  and its «Overwrite» is still honoured. «Skip files» and «Auto-rename» do as before.
- **The preview and «Check all files»** (`multiRenameFileStatus()` :41257) follow the batch's list order for every
  pattern. A name an earlier file leaves reads free (a). A name held by a selected file that has not moved by the
  file's turn reads «Name taken by #N: …», with what the batch will do (b, c); «Check all files» counts those rows
  as «Taken by selected files (…): N» (:41429). A file waiting on the conflict box is taken to keep its name. A
  later page looks for the holders among the 9,100 selected files from its first one and does not see the names
  that the files before it leave, so its rows can still differ from the batch, as since `bccc022`.

Runs of the fix against `96feeef`, every batch but E and E4 (outcomes not named here are the same):

- **A4**: #2's row reads «OK», and «Check all files» says «Will be renamed: 2». **A5**: «Name taken by #1:
  auto-rename», where the batch gives «a [1].png».
- **H2**: #1's row reads «Name taken by #2: …» and #2's «OK», under every action. H2.3 ends with «photo [1].png»
  and photo.png, nothing recycled; in H2.4 the box's «Overwrite» still recycles Photo.png.
- **J1.3, M2.3**: the swap ends with «x 1 [1].png» and x 2.png, as under «Auto-rename».
- **L1.3**: 4 of 4 renamed, to «x 1 [1]», «x 2 [1]», «x 3 [1]» and x 4, nothing recycled; **L2.3**: 3 of 3;
  **L3.3**: «x 1 [1]», «x 2 [1]», and #3 replaces x 3.png, the unselected file, as «Overwrite» does.
- **M5, M6**: «Finished renaming 3 out of 3» and «2 out of 2»; the database lists keep 3 and 2 rows.
- **Batch Q**, new: the H2 shape under «Ask user», the box answered «Overwrite» (Q1): the box's first line is the
  note, and Photo.png is recycled. A chain blocked by an unselected file under «Ask user» (Q2): the two boxes for
  selected files carry the note, the third does not. A rotation of five under «Overwrite» (Q3): 5 of 5 renamed,
  4 to «[1]» names; on the page after 2 files, #3 and #4 read «Name taken by #4» and «… by #5», and #5 «Name
  taken: overwrite», as its holder, #1, is before the page.
- **The cost**, under Wine, 3,000 files shifted down under «Skip» (Q4, and Qt: three rounds in one session). The
  first page stops after one second at both revisions; it shows 2,730 to 2,853 rows (median 2,772), against
  2,487 to 2,897 (median 2,855). The page after 2,990 files takes 19 to 29 ms, against 18 to 21 (one round
  156). «Check all files» takes 224 to 232 ms, against 202 to 211. A plain name (P4, one round): 752 rows on the
  first page against 775, 79 ms against 71 for the later page, 2,866 ms against 2,889 for «Check all files». Not
  measured on Windows.

Left open: a shift or a swap within the selection still does not complete. Under «Skip» and under «Ask user»
answered «Skip file», its files keep their names; under «Auto-rename» and «Overwrite», they take «[1]» names.
Renaming each file after the selected file that holds its new name, with or without one temporary name per
cycle, would complete them (decision 5).

---

## 6. A renamed favourite keeps its mark, and the favourites keep the old path

The batch's bookkeeping :42140-42154; the single file rename's `ToggleImgFavourites(file2rem, "rem")`
:44362-44363

The favourites are a list of paths (`mainFavesFile`, `miniFavesFile`). The single file rename takes a renamed
file out of them and clears its mark. The batch does neither: the list entry keeps `[5]=1` on the new path,
and the favourites keep the old one.

Run (F1): a.png added to favourites, then `[this]-x`. Afterwards the entry a-x.png carries the mark, and the
favourites still hold a.png. Toggling the mark on a-x.png says «Image REMOVED from favourites … Total
entries: 1»; the mark goes, the dead a.png entry stays, and the count stays at 1.

---

## 7. The «Invalid RegEx» row acts as a file

The row: `LV_Add("", "Invalid", "RegEx", "-", "-", "-")` :41810; the double-click :41768-41771; `BTNdoSoloRename()`
:41152-41155

An invalid `\>…` pattern fills the list with one row whose «#» column holds «-». The handlers read that column
as a file's index. The other placeholder row, «No new name in files …» (:41930), leaves «#» empty and is
handled as no file (:41741).

Runs, `\>(img//x` with file #2 current (D1, D2), and a file row as the control (D3):

- **D1**, a double-click on the row: `currentFileIndex` becomes «-», `IDshowImage("-")` logs «Index entry error:
  incorrect file path», and the OSD shows «ERROR: File not found or access denied». `NextPicture()` afterwards
  goes to #3.
- **D2**, «Solo rename» with the row highlighted: `clampInRange("-", 1, maxFilesIndex)` gives 1, and the rename
  box offers a.png, the list's first file, instead of b.png, the current one.
- **D3**, «Solo rename» on row 3: the box offers c.png, as it should.

Run again at `6a66bf9` (D1-D3): the same outcomes.

**Fixed in `e88f125`**: the row leaves «#» empty (:41859 at `e06ea0a`), as the other placeholder row does, so
both handlers take it for no file. Run at `e88f125` and at `e06ea0a` (D1-D3):

- **D1**: the double-click does nothing; `currentFileIndex` stays 2, and no «Index entry error» comes.
  `NextPicture()` afterwards goes to #3.
- **D2**: «Solo rename» offers b.png, the current file.
- **D3**: unchanged.

In D1 the kit logs a redisplay of b.png after the double-click. It comes from the batch's own setup, which makes
b.png current: a control run, D0, with the same setup and no double-click, logs it too.

---

## 8. A preview timer that fires after the panel closed

The delayed starts of `uiPopulateLVmultiRename()`: :41214 (page buttons, 250 ms), :41224 (collision drop-down,
150 ms), :41516 (menus, 350 ms), :41526 (typing in the box, 450 ms); its head :41783-41784

Each change in the panel starts the preview 150-450 ms later, and nothing stops that timer when the panel
closes. The function then runs `Gui, SettingsGUIA: Default` and `Gui, SettingsGUIA: ListView, LViewOthers`.
On a destroyed window, AutoHotkey's `Gui, ListView` creates the window again, hidden and empty. The pattern box
is gone, so the pattern reads blank, and the blank-pattern branch runs `LV_Delete()` (:41797) on whatever
`LViewOthers` list is there: another panel's, when one opened meanwhile. The only check of the open panel,
`AnyWindowOpen!=8` (:41924), sits inside the page loop, which a blank pattern never reaches.

Runs:

- **G0**, «Cancel» within 450 ms of a typed change: right after «Cancel» there is no SettingsGUIA window; once
  the timer has run, there is one, hidden.
- **G1**, the same: the timer runs with `AnyWindowOpen=0`, the hidden window is there afterwards, and the panel
  then opens again normally.
- **G2**, «Rename files» within 450 ms of a typed change (Enter right after typing): the same hidden window,
  after the batch.
- **G3**, the file actions history panel opened within the 450 ms: its list had 3 rows before the timer and
  0 after.

The hidden window did no visible harm in G1 and G2. G3 needs another panel opened within half a second.

Run again at `7ee44f5` (G0 to G3): fixed. The late timer still runs, and the function returns at once.
No SettingsGUIA window is there afterwards, after «Cancel» (G0, G1) or after «Rename files» (G2), and the
file actions history keeps its 3 rows (G3). The kit's line «CALL uiPopulateLVmultiRename() with
AnyWindowOpen=…» still shows, because the kit logs the call before the function's own check.

**Fixed in `2663c62`**, by Marius: `uiPopulateLVmultiRename()` returns when panel 8 is not open
(:41790-41792).

---

## 9. Small things

✅ marks a fixed one.

- **9.1. «Large UI fonts» and «Dark mode UI» rebuild the panel with an empty box.** The toggles call the panel's
  function again (`ToggleLargeUIfonts()` :74393), which builds the box empty (:41118). I1: `[this]-x` typed,
  «Large UI fonts»: the panel opens again with an empty box and an empty list (run; «Dark mode UI» read). The
  files filter panel keeps its typed fields through these toggles since `08b5a01`.
- **9.2. The page buttons ask for a pattern that is there.** With a valid pattern that renames nothing on the
  page, «<<», «<», «>» and «>>» say «Nothing to preview at the moment. Please ensure you provided a renaming
  pattern.» (:41187-41192). I2: `zzz//y`, then «>», with the summary showing «No selected file name would
  change» (run).
- **9.3. A two-character pattern is never recorded in the history.** The batch accepts two characters
  (:41961), the history lists entries from two characters (:41085), but `RecordUsedMultiRenamesQueriesManager()`
  wants three (:42190). I3: `ab` renames the three files and leaves the history empty; `abc` is recorded (run).
- **9.4. «Overwrite» replaces an empty file without recycling it.** `FileRexists(file2save, 0)` reads a 0-byte
  file as absent (:32907), so `mustReplace` stays 0 and `FileMove …, 1` replaces it (:42121): no Recycle Bin,
  no «Overwritten files», no undo record of the replaced file. J2: an empty a-x.png on disk, `[this]-x`: the
  message says «Finished renaming 2 out of 2 selected files» and the Recycle Bin holds nothing new (run). No
  content is lost; the list entry of such a file, if listed, keeps its path.
- **9.5. A file renamed onto a selected file the pattern leaves unchanged reads «Name taken: overwrite».** The
  batch protects that file on purpose (`7bb9721`: its name is taken before the unchanged-name skip, :42054,
  and «Overwrite» auto-renames onto a taken name, :44264). A5: `IMG_//` on a.png and IMG_a.png, «Overwrite»:
  the row and «Check all files» say overwrite, and IMG_a.png becomes «a [1].png» (run). Only the status word
  is wrong.
- **9.6. The closing message counts unchanged files as skipped.** A file the pattern leaves unchanged adds to
  `skippedFiles` (:42055-42058). A5, B3: «Finished renaming 1 out of 2 selected files | Skipped files: 1»,
  while «Check all files» calls the same file «Unchanged» (run).
- **9.7. The single file rename box gives Alt+M to two buttons.** «&Multi-rename» and «&Modify index entry»
  (:44323, :44326) both appear when several files are selected, as they are when «Solo rename» opens the box
  (D2 shows both buttons; what the key does was read, not run). The files filter audit found Wine pressing the
  first of two buttons that share a letter (its finding 13); Windows behaviour was not checked.
- **9.8. Leftovers.** `BtnMultiRenameMenus()` reads the highlighted row's «#» into `idu`, under the comment «sample
  values from the highlighted file», and never uses it (:41423-41426); the sample values went in `a20625d`.
  `PanelMultiRenameFiles()` sets `thisu` for the commented-out line under it (:41111, :41116) (read).
- **9.9. «Help» leaves out two rules.** `\\` works as the find-and-replace separator in place of `//`
  (:41592-41593), and the matching of `//`, `>>` and `\>` ignores letter case (`StrReplace()`; the `i)` merged
  into a RegEx, :41617-41618). The Help text names neither (:41220) (read).

---

## Seen in passing

✅ marks a fixed one.

- **A. `zPlitPath()` drops the leading `\\` of a network path.** It splits at every backslash and skips the empty
  parts (:60710), in both modes. I4: `\\server\share\dir\a.jpg` gives the folder `server\share\dir`, a relative
  path, so the batch's target `OutDir "\" newFileName "." ext` (:42053) would point under the working folder
  (run for the split; no network share was available under Wine, so a rename on one was not run). The helper
  has 186 calls in the script and its lib; whatever else rebuilds a path from its folder is likely hit the
  same way (read).
- **B. The single file rename on a database list** offers the lowered name in its box (:44307-44308), and a
  typed name without an extension takes the lowered extension (:44341-44343); finding 3 in another panel (read).
- **C. The collision action is kept for the session only.** `onConflictMultiRenameAct` is set at start-up to 4
  (:347) and has no `RegAction()` or `INIaction()`, so «Ask user» comes back at every start (read). Maybe on
  purpose.
- **D. The first defect left open on 2026-11-13 no longer holds.** «Ask user», each box answered «Overwrite»,
  three files onto photo.jpg (H1): the list now marks the two replaced entries deleted (`||…\photo.jpg`) and
  keeps one live entry, where on 2026-11-13 it held the live path three times. `markReplacedListEntry()` does
  it, called from the batch since `3df8de3` (2026-11-14) (run).

---

## Checked and found correct

- **A token pattern onto a taken name under «Overwrite»** recycles the old file and takes its name, with
  «Overwritten files: 1» (A3) (run).
- **ASCII case changes** go through `renameFileCaseOnly()` and a temporary name under every collision action
  (abc.png in C1-C4) (run).
- **The edited image when it is not renamed** keeps its edits through the redisplay (E4) (run). At `7ee44f5`
  the save question comes first, and the edits survive its «Discard» (K9).
- **«Check all files»** gives the same counts as the preview's statuses in every case run (A1, A4, A5, C1),
  so its numbers inherit findings 4 and 5, nothing more (run). Since `82cdeeb` both follow the batch's order,
  and the summary counts the names that selected files hold apart (A, H, J, L, M, Q).
- **The page buttons** carry the texts «First», «Previous», «Next» and «Last», which
  `UImultiRenameChangeLVoffset()` reads and compares (:41181); `GuiAddButton()` gives the button that text and
  shows «<<» and the rest through `SetImgButtonStyle()` (:26782-26785) (read).
- **`listPathsMap`** in the batch is not a super-global, on purpose: `markReplacedListEntry()` builds that map
  on its first call and keeps it current for the rest of the batch (:34050-34072) (read).
- **The pattern box**, read with `GuiControlGet` into each handler's own `UsrEditNewFileName`, works in every
  handler run (A-J) (run).
- **A right-click on the list** opens one menu: the list's handler opens the panel menu (:41772-41774), and
  `SettingsGUIAGuiContextMenu()` returns without one for a right-click on a control (:26029-26032) (read).
- **The menus**: «Insert» disables its tokens for `$.` patterns (:41451-41457); a `case{…}` token replaces the
  one already in the box (:41494-41499) (read).

---

## Settled earlier, not reported again

- Marius's corrections of `a20625d`: the static Help, no sample values, tokens disabled only for `$.`, no column
  cap, the summary line and its wording, the Examples list and its labels.
- The 2026-11-09 choices: `case{x}` kept as text, a plain pattern's edge dots and commas dropped, `//` and `>>`
  folding ASCII case only, no extension added to a typed solo name with a dot; device names and long names left
  to Windows.
- «Erase history» without a question; one summary count for names taken (folder-held names inside it); `\>i)
  //_` replacing spaces.

---

## Decisions to make before fixing

Decisions 1, 2, 4, 7 and 8 are settled, with one question left under 1, and decision 5 in part. Marius left 3
open on 2026-11-26; the others are open too.

1. Finding 1: should «Rename files» ask the save question when the edited image is among the selected files?
   Should the double-click and «Solo rename» ask before they change the image, or should «Solo rename» rename
   the highlighted file without showing it first?
   **Settled in `2663c62` and `1ce44b5`**, by Marius: the three routes ask before they change the image, and
   «Solo rename» still shows the highlighted file before the rename box. Open: the question also comes where
   nothing would be lost (finding 1, K6 and K9).
2. Finding 2: should `isSameFileOtherCase()` and the status compare with `Format("{:L}", …)`, as
   `mapListPaths()` does? The single file rename and the undo of file actions would change with it.
   **Settled in `0433cd3`**, by Marius, **and `7ee44f5`**: yes, and the single file rename and the undo of file
   actions changed with it.
3. Finding 3: should the batch take each name's spelling from the disk (as `isSameFileOtherCase()` reads it with
   `Loop, Files`) before it builds the new name? Or should database lists keep the spelling (a schema change)?
   **Left open on 2026-11-26**, by Marius.
4. Finding 4: should a plain name overwrite under «Overwrite», as other patterns do? Or should the rule stay,
   with the status, the summary and the conflict box saying «skip»?
   **Settled in `e06ea0a`**, by Marius: neither. A plain name takes the next free number at each file's turn,
   passing over every name in use, those of selected files not renamed yet included, as the batch keeps list
   order. The 2019 rule went with it.
5. Finding 5: should the preview and «Check all files» follow the batch's order, with names freed and taken as
   they go? Should the batch rename in two passes, through temporary names, so that swaps and shifts work under
   any collision action? Or should a selected file waiting for its turn never be overwritten?
   **Settled in part in `82cdeeb`**, by Marius. Six fixes were offered, from the least work to the most: a line
   in Help; «Overwrite» never replacing a selected file; the preview and «Check all files» following the batch's
   order; renaming each file after the selected file that holds its new name; the same, with one temporary name
   per cycle (swaps, rotations); every renamed file through a temporary name, in two passes. He chose the second
   and the third, with these answers: under «Overwrite» the file gets a «[1]» name rather than being skipped; the
   conflict box warns, and its «Overwrite» is honoured; the rows read «Name taken by #N: …»; «Check all files»
   counts them apart. Open: the fourth or the fifth, so that shifts and swaps complete.
6. Finding 6: should the batch move a favourite to its new path, or take it out as the single file rename does?
7. Finding 7: should the «Invalid RegEx» row leave «#» empty, as the other placeholder row does?
   **Settled in `e88f125`**, by Marius: yes.
8. Finding 8: should closing the panel stop the timer, or should `uiPopulateLVmultiRename()` return at once when
   panel 8 is not open?
   **Settled in `2663c62`**, by Marius: the function returns at once when panel 8 is not open.
9. The 5-second cut of the preview (`selCounter>A_Year`, :41857, `428fcca`): it applies only past file 2,026
   of the selection, a number that grows each year. Is a fixed count meant there?
10. Small things 9.1 to 9.9 and «Seen in passing» A to C: which to fix.

---

## How this was checked

- **Static reading** of `development` at `468aef9`: the panel, its handlers, the routes that open it, the
  single file rename it hands over to, and each helper before a call to it was judged. The memories of the
  earlier work on the panel were read first, so that settled choices are not reported again.
- **The real application under headless Wine**, on the stock AutoHotkey 1.1.37.02, started on one image, with
  test functions appended to a scratch copy of the script. A test makes the files, sets the list (directly,
  or, for batch B, a folder opened as a list and saved and reopened as a database list), opens the panel
  through `PanelMultiRenameFiles()`, types the pattern, picks the collision action, and posts a click
  (`BM_CLICK`) to «Rename files», «Check all files», «Solo rename» or «>». The handlers then run as they are.
  The log keeps the messages and boxes, the preview rows and the summary, the files on disk with their sizes,
  the list's paths and the Recycle Bin.
- **The scratch copy differs from the source** in that messages, tooltips and journal errors are logged, and so
  are the calls to `askAboutFileSave()`, `terminateIMGediting()`, `uiPopulateLVmultiRename()` outside the
  panel, `ToggleImgFavourites()`, `PanelRenameThisFile()`, `IDshowImage()` (batches D, E),
  `replaceFileByCopyMove()` and `renameFileCaseOnly()`.
- **Aids**, each named where it was used:
  - an edited image simulated by its state (finding 1);
  - the row double-click made by calling `UIlvMultiRenameResponder(…, "DoubleClick", row)` (findings 1, 7);
  - the conflict box answered from a native timer, since it waits under Critical where the script's timers do
    not run; other boxes answered from a script timer; Wine's shell boxes answered «No» by a second process
    (finding 2);
  - the late preview timer started as the box's g-label starts it, `SetTimer, uiPopulateLVmultiRename, -450`
    (finding 8).
- **Batches**: A (collisions against the preview), B (database lists), C (non-ASCII case), D (the «Invalid RegEx»
  row), E and E4 (an edited image), F (favourites), G and G0 (the late timer), H (the defects left open on
  2026-11-13),
  I (the font toggle, the page buttons, the history, a network path), J (a swap, an empty file), and K
  (finding 1 run again at `7ee44f5`: the save question answered «Cancel» and «Discard» on each route, «Save»
  on «Rename files»).
- **Batches added on 2026-11-26**, L, M and N each run at `6a66bf9` first:
  - L, under each collision action: a downward shift (a.png, x 1, x 2, x 3 renamed to x 1 to x 4), a rotation of
    three, a chain whose last new name is held by a file outside the selection, and a plain name over its own
    numbered files (L4);
  - M: a plain name onto numbers held by files outside the selection (M1, M4), a swap (M2), the shape of H2 with
    the box answered «Overwrite» (M3), two database lists (M5, a shift; M6, a swap made by reordering the list's
    first two entries), «undo last» of a rotation (M7) and a one-file undo after a swap (M8);
  - N: plain names: gaps closed (N1), a later preview page (N2, with `uiLVoffset` set as the page buttons set
    it), a missing file (N3), two folders (N4);
  - D0: the setup of D1 without the double-click, the control for a redisplay seen in D1;
  - P, at `6a66bf9`, `e06ea0a` and `bccc022`: plain names with a token (P1), with `case{U}` (P2), on a database
    list (P3),
    and the time a long selection takes (P4: 3,000 files; the preview's first page, a page after 2,990 files,
    and «Check all files», timed with `A_TickCount` around the calls);
  - Q, at `96feeef` and on the fix: the H2 shape under «Ask user», the box answered «Overwrite» and its first
    line logged (Q1); a chain blocked by a file outside the selection, under «Ask user» (Q2); a rotation of five
    under «Overwrite», on a later page and on the first (Q3); 3,000 files shifted down, timed as in P4 (Q4); and
    Qt, Q4's timings three times in one session.
- **The fixes** were checked on their committed text, compared by sha256: batch D at `e88f125`, and every batch
  but E and E4 at `e06ea0a`, against the runs at `6a66bf9`; then A, L, M, N and P at `bccc022`, against those at
  `e06ea0a`, where only the later page of N2 and P4 changed. Finding 5's fix: every batch but E and E4 on
  its text over `96feeef` (sha256 `c01ce28f…`), against runs at `96feeef`, with Q and Qt at both; `82cdeeb`
  makes the same change over `d1c7c83`, which only removes `simulateCalcImageCoordsInVP()`, and was
  load-checked only. Lines that differ between
  two runs of the same text were left out of those comparisons: the conflict box shown before or after the
  destination's image size is read, which file the app shows at start, the order of the start-up image's load
  in the log, the order of hash-named files in the Recycle Bin, and in G3 whether the file actions history list
  is filled 100 ms after it opens (empty in one of two runs at `96feeef`).
- **Read, not run, at this revision**: «Insert», «Examples», «Erase history», «Help», «<<», «<», «>>», «Preserve
  original file date and time» and «Dark mode UI». The 2026-11-08 kits ran the menus, «Erase history» and the
  paging at earlier revisions; no finding about them here means none was found by reading.
- **Not run on Windows**: how NTFS and the Recycle Bin handle the «Overwrite» case of finding 2, which the
  batch no longer reaches since its fix; what Alt+M does in 9.7; a rename on a network share (A).
- **Not run at all**: Escape during «Check all files»; private mode; multi-page preview mode; a selection
  longer than one page, except that N2, Q3 and Q4 show a later page by setting its offset; Quick search actions
  or user-defined shortcuts fired while the panel is open.
- **The kit**: `.claude/scratch/multi-rename-panel-2026-11-24/` (README.txt). `app/run-mr.sh <tag> <test
  function> [revision]` runs one batch, about a minute each, and writes `app/results/<tag>.txt`; the logs of
  this report are kept there, those of the runs at `7ee44f5` under the tags `<batch>-7ee44f5`, at `6a66bf9`
  under `<batch>-6a66bf9`, and at the fixes under `D-fix7`, `<batch>-fix4` (`P-e06ea0a` for P) and
  `<batch>-page` (`bccc022`); finding 5's runs under `<batch>-96feeef` and `<batch>-fix5`, with the fix's script
  in `fix-2026-11-26/patch5.py`. It reuses the files filter kit's
  `patch.py`, `patch-ff.py` and helpers, and adds `patch-mr.py` and `test-mr.ahk`.
