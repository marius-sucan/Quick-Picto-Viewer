# Folders list panel audit, 2026-11-10

Scope: `PanelStaticFolderzManager()` (:93984), the panel it builds (Ctrl+U; its title is
«Static folders list» or «Cached folders list»), its buttons, its filter box, its keys, its
context menu `invokePanelStaticFoldersContextMenu()` (:93419), and every function those
reach, as far as a panel action reaches them. Line numbers are `quick-picto-viewer.ahk` on
`development` at ab160cb. The audit changed no code.

Thirty findings. Each one says how it was checked: **run** means the real application did
it under headless Wine, on AutoHotkey_H 1.1.33.10 (three batches also on stock AutoHotkey
1.1.37.02, with the same log); **read** means it follows from the code and was not run.
Nothing was run on Windows. The test kit is described at the end.

The three high findings come down to two lines of `updateCachedStaticFolders()` and one
missing `Return`. A scratch copy with those three corrections was run through the same
batches; what it shows is under «A trial of the three main corrections».

**Status, 2026-11-11.** Marius fixed part of this in two commits of his own: `f88e4be`
on 2026-11-10 and `2c501dc` on 2026-11-11. Two commits made at his request sit between
them: `256a670` attaches the «Ignore all changes» button to the function `f88e4be` added
for it, and `1813ca9` makes the button act on the rows the table lists.

- **Fixed, 13:** findings 1, 2, 3, 4, 5, 6, 7, 8, 18, 22, 25, 26 and 27.
- **Partly fixed, 7:** findings 9, 17, 20, 21, 23, 28 and 30. Each note says what is left.
- **Open, 10:** findings 10, 11, 12, 13, 14, 15, 16, 19, 24 and 29.

`2c501dc` fixes 3, 18 and 25, completes 2, and fixes part of 9, 20, 21, 23, 28 and 30. It
also changes what some actions do besides: six points, N1 to N6 under «New with the
fixes». Three of them are of medium harm: «Erase files from the index» no longer
refreshes the viewport (N1) and no longer says that the index was left empty (N2), and a
folder that is not on the disk is now dropped from the folders list whenever another
folder is rescanned (N3).

A fixed or partly fixed section ends with a note on what the code does now. Each note
names the commit whose lines it cites: `54a0666` (the merge commit that follows
`f88e4be`), `1813ca9` or `2c501dc`. Everything else keeps its lines at ab160cb, and the
name `BTNignoreDateStaticFolder()`, which `f88e4be` changed to
`MenuIgnoreDateStaticFolder()`. Each note was checked by running the batches again: on
`54a0666`, on the text of `256a670`, on the text of `1813ca9`, and on `2c501dc`, where a
seventeenth batch, Q, was added.

## Terms

- **Index**: QPV's files list, `resultedFilesList`.
- **Folders list**: what this panel shows, one entry per folder that holds indexed files.
  It lives in `newStaticFoldersListCache`: path, recorded date, indexed files, selected
  files, files on disk, size.
- **Recorded date**: the folder's «modified» date as it was when the folder was last
  scanned. A cached .SLD list keeps it in its `[Folders]` section, a database in its
  `staticfolders` table.
- **Changed mark**: the «*» in the «(?)» column. A folder gets it when its date on the disk
  differs from the recorded date. Clearing the marks of the folders one has dealt with is
  what the panel is for («Update files list selectively»).
- **Plain list**: a folder opened in QPV, or a list that was never saved. Its folders list
  exists only in memory, generated on request.
- **Cached .SLD list**: a plain-text slideshow saved with its files and its folders
  (`SLDtypeLoaded=2`, `SLDcacheFilesList=1`).
- **Database**: an .SLDB list (`SLDtypeLoaded=3`).
- **Selected file**: a file marked in the index. **Highlighted row**: a row picked in the
  panel's table. **Focused row**: the one row with the keyboard focus (the dotted
  rectangle). The panel's actions first ask for a focused row, then work on the highlighted
  rows.
- **Seed folders**: the folders that generate the index, managed in the «Manage seed
  folders list» panel.
- **Stopping an operation**: a long loop asks `determineTerminateOperation()` at every
  step; the user stops it by clicking the main window and answering «Yes».
- **Test folders**: `Alpha` (3 images), `Alpha\Sub` (2), `Beta` (2), `Gamma` (1) and
  `Holiday One` (4), under one seed folder.

## Summary

| # | Finding | Harm | Checked | Status at `2c501dc` |
|---|---------|------|---------|---------------------|
| 1 | Database: «Regenerate this folders list» does not bring the panel back and leaves the main window deaf to keys, clicks and menus | high | run | **fixed**, `f88e4be` |
| 2 | «Rescan folder(s)» never clears the changed mark: the dates it gathers are not used | high | run | **fixed**, `f88e4be` and `2c501dc` |
| 3 | After any update, the folders list in memory starts at entry 2 and is thrown away: folders added to a cached .SLD list never reach it, ignored changes come back | high | run | **fixed**, `2c501dc` |
| 4 | «Ignore all changes» updates the highlighted rows only, and nothing without a focused row | medium | run | **fixed**, `f88e4be`, `256a670` and `1813ca9` |
| 5 | «Ignore date change» with a filter on: when every listed row is highlighted, the folders that are not listed are updated too | medium | run | **fixed**, `f88e4be` |
| 6 | On a cached .SLD list an ignored change is not saved, and the list is not marked as modified | medium | run | **fixed**, `f88e4be` |
| 7 | The filter cannot be removed after the panel reopened with it | medium | run | **fixed**, `f88e4be` |
| 8 | The «greater than» number filters keep every row at 0 | medium | run | **fixed**, `f88e4be` |
| 9 | «Selected» column: zeros at the first opening of a cached .SLD list or a database, stale after the selection changed | medium | run | **partly fixed**, `2c501dc`: a selection that moved to other files is counted; the first opening and a single selected file are as before |
| 10 | «Files» column and the folders themselves do not follow the index | medium | run | open |
| 11 | Ctrl+A on a freshly opened panel leaves every action dead | medium | run, Wine | open |
| 12 | F3 on two or more folders drops the files selection | medium | run | open |
| 13 | A stopped «Count files per folders» leaves zeros that pass as counts | medium | run | open |
| 14 | «Rescan folder(s)» on a folder that cannot be reached removes its entries, in a database with their cached data, without a word | medium, a decision | run | open |
| 15 | Database: after «Rescan folder(s)» the image in the viewport is no longer the current file | medium | run | open |
| 16 | F2 in a database opens the rename the menu leaves out; the folders list is not updated | medium | run | open |
| 17 | Private mode marks every folder as changed; a missing folder is dated today | medium | run | **partly fixed**, `f88e4be`: a missing folder is still dated today |
| 18 | «Regenerate entire index» leaves the marks of a cached .SLD list | medium | run | **fixed**, `2c501dc` |
| 19 | «Rename index entry» with «Propagate the change to subfolders» unticked still moves the files of the subfolders | low | run | open |
| 20 | A folder that was offline when the list was saved is dropped when the list is loaded; so are drive roots | low | run, read | **partly fixed**, `2c501dc`: a drive root is still dropped |
| 21 | A list that was never saved: marks that cannot be cleared | low | run | **partly fixed**, `2c501dc`: the menu item is no longer offered; the mark still comes and stays |
| 22 | «Count selected files» lists every folder again while the filter box keeps its text | low | run | **fixed**, `f88e4be` |
| 23 | «Erase files from the index» on N folders rebuilds the index, shuffles it, beeps and picks a random image N times | low | run | **partly fixed**, `2c501dc`: no shuffle, beep or random image; still one pass per folder, and nothing is refreshed (N1, N2) |
| 24 | «Rescan folder(s)» turns the folder part of the paths to lower case | low | run | open |
| 25 | «Count files in folders found on disk»: «Difference» is not updated for a folder with nothing indexed | low | run | **fixed**, `2c501dc` |
| 26 | «%» and «Size (MB)» are sorted as whole numbers | low | run | **fixed**, `f88e4be` |
| 27 | F3 on a row that was not counted yet needs two presses | low | run | **fixed**, `f88e4be` |
| 28 | Actions on a folder that is missing from the disk say nothing; «Set as the protected folder» protects another folder | low | run | **partly fixed**, `2c501dc`: three of the six actions answer; the refusal names the wrong folder |
| 29 | Alt+right-click deselects the files and opens the menu too | low | run | open |
| 30 | Small things | low | run, read | **partly fixed**, `2c501dc`: three of the fifteen points |

Findings 1, 2 and 3 defeat what the panel is for. Finding 1 needs a database and one menu
item. Findings 2 and 3 meet every user of a cached .SLD list or a database who rescans a
folder.

All three are fixed. A rescanned folder loses its mark on a cached .SLD list and in a
database, and the folders list in memory is kept after an update.

---

## 1. Database: «Regenerate this folders list» leaves the main window deaf

`regenerateStaticFoldersList()` :35105, `SQLdbGenerateStaticFolders()` :34535

```ahk
BtnCloseWindow()
owle := setWhileLoopBusy()          ; whileLoopExec := 1
If (SLDtypeLoaded=3)
{
   zr := SQLdbGenerateStaticFolders()
   If !zr
   {
      addJournalEntry("ERROR: Failed to regenerate the static folders list in the database")
      Return
   }
```

`SQLdbGenerateStaticFolders()` ends without a `Return` value, so `zr` is always empty and
the «failed» branch always runs. The table was in fact regenerated.

What happens (run, batch D):

- the panel is closed and does not come back; the journal gets the «ERROR: Failed to
  regenerate…» line;
- `whileLoopExec` stays 1. Nothing clears it by itself (it was still 1 after 2.5 s), and
  the application has no periodic timer that does.

`whileLoopExec=1` is the «busy» flag. While it is set, with no operation running:
`PreProcessKbdKey()` (:602) and `HKifs()` (:555) let no keyboard shortcut through; in
`lib/module-interface.ahk`, `WM_MOUSEWHEEL()`, `uiWM_LBUTTONDOWN()`, `WM_MBUTTONDOWN()`,
`WM_LBUTTON_DBL()` and `WM_RBUTTONUP()` do nothing, `uiCallWndProcWork()` cancels the menu
bar and the system menu, and dropped files are refused; the pointer shows the busy cursor.
Closing the window asks «The main window seems to be busy at the moment. Do you want to
force exit this application?» (`byeByeRoutine()`). The flag is cleared by the next
`ResetImgLoadStatus()`, which needs an action to run first. The toolbar, when it is shown,
still works: its handler does not test the flag.

The cache is not emptied either, so the next opening shows the list as it was.

Correction: `Return 1` at the end of `SQLdbGenerateStaticFolders()`, `Return 0` after a
failed commit, and `whileLoopExec := owle` before the early `Return` of the caller. Run on
the trial copy: the panel comes back and the flag is 0.

**Fixed in `f88e4be`** by the correction above, with one difference.
`SQLdbGenerateStaticFolders()` returns 1, or 0 after a failed query or a failed commit
(:34547, :34569, :34571). In `regenerateStaticFoldersList()` a failure no longer returns
early: it shows «ERROR: Failed to regenerate the static folders list in the database» as a
message (:35117) and goes on, so in both cases the folders list in memory is emptied
(:35120) and `whileLoopExec` is put back (:35121). The panel is opened again by a timer,
250 ms later (:35122; :35132 for the other kinds of list).

Run (batch D): `whileLoopExec` is 0 as soon as the function returns, the journal gets no
error line, the panel is back and the table holds the five folders. The failure branch was
not run.

## 2. «Rescan folder(s)» never clears the changed mark

`BTNupdateSelectedStaticFolder()` :97554, `updateCachedStaticFolders()` :96912

The button gathers the new date of every rescanned folder and hands them over as an
object:

```ahk
For foldar, indexu in foldersListArray
{
    FileGetTime, dirDate, % foldar, M
    foldersListArray[foldar] := dirDate
}
updateCachedStaticFolders(foldersListArray, 1)      ; :97619
```

The receiver builds its own `foldersListArray` only when it was given a folder path:

```ahk
If !IsObject(mainFolderu)       ; :96916
{
   foldersListArray := new hashtable()
   …
}
…
If foldersListArray[z]          ; always empty when an object was given
```

`foldersListArray` is a local of each function, not a super-global. With an object given it
is never assigned, so no date is updated and nothing is added.

What happens (run):

- cached .SLD list (batch C): `Beta` is marked, «Rescan folder(s)» on it, the panel comes
  back with `Beta` still marked;
- database (batch D): the same with `Gamma`; the `staticfolders` table keeps the old date.

The rescan itself works: the files are scanned back. Only the mark stays, so a rescanned
folder looks exactly like one that still waits. The user's way out is «Ignore date change».

Correction: `foldersListArray := mainFolderu` when an object is given. Run on the trial
copy: the mark is cleared and the date is written.

**Fixed in `f88e4be` and `2c501dc`.** `f88e4be` makes the correction above (:96940-96941
at `54a0666`): the dates the button gathers are used. That cleared the mark in a database
only: on a cached .SLD list the new date went into the list that finding 3 threw away.
`counter := 0` in `2c501dc` completes it.

Run on `2c501dc`:

- database (batch D): after «Rescan folder(s)» on `Gamma` the mark is gone and the
  `staticfolders` table holds the new date;
- cached .SLD list (batches C and P): the rescanned folder loses its mark (`Beta` in batch
  C, `Gamma` in batch P). Saved and loaded again, it has no mark: the `[Folders]` section
  of the saved file holds the new date.

## 3. After any update, the folders list in memory starts at entry 2 and is thrown away

`updateCachedStaticFolders()` :96932

```ahk
counter++                 ; counter was never assigned: this makes it 1
newArray := []
…
    counter++
    newArray[counter] := newStaticFoldersListCache[A_Index]     ; the first entry lands at 2
```

A `++` alone on a line treats an empty variable as zero. The rebuilt list therefore runs
from 2 to N+1 (run, batches C2 and M: `MinIndex=2`). Every «is the folders list loaded»
test reads entry 1:

```ahk
If (StrLen(newStaticFoldersListCache[1, 1])>1 && countStaticFolders>0 && ths>0)    ; :35028
   Return
```

so the next reader finds it «not loaded» and reads it again from where it is stored. The
function runs after «Rescan folder(s)», after a rescan in the seed folders panel, and after
«Add seed folder(s)».

What that does:

- **Cached .SLD list**: the stored copy is the file on the disk, which holds the list as it
  was when it was last saved. Every update made in memory is lost at the next opening of the
  panel, and at the next save, because `SaveFilesList()` reads the same way (:34971):
  - a folder added with its subfolders is listed in memory (two new entries), is gone when
    the panel opens, and is not in the `[Folders]` section the save writes (run, batch C2).
    Loaded again, the index holds 8 folders and the panel lists 5;
  - changes ignored earlier in the session come back: `Holiday One` and `Gamma`, cleared
    with «Ignore date change», are marked again after «Rescan folder(s)» on `Beta` (run,
    batch C);
  - a rescan of the seed folder writes the new dates in memory and the panel still shows
    the mark (run, batch M).
- **Database**: the stored copy is the `staticfolders` table, written by the same call, so
  the reload gives the right list. Each write also adds one row with an empty folder name
  and an empty date (run, batch D: `(<><>)` in the table). The readers skip it.

Correction: `counter := 0`. Three things then come to the surface, because the reload that
hid them no longer happens:

- database: the «Files» cell of a rescanned folder stays empty until the row is clicked
  (run on the trial copy). The button empties it before the rescan (:97604) and the reload
  from the database used to fill it;
- the folder given to the function becomes a row of its own even when no image sits
  directly in it (run on the trial copy: the seed folder, with no files);
- the two tests of the first loop start to matter (read):
  `If (!FolderExist(folderu) || hash[z]=1 || StrLen(folderu)<5)` (:96941) drops every
  folder that is not on the disk at that moment, and every path shorter than five
  characters (`c:\a`, a drive root). The second loop accepts two characters since e58bbb0.
  An unplugged drive would lose its folders from a cached .SLD list at the next rescan of
  any folder. See decision 9.

**Fixed in `2c501dc`** by the correction above: `counter := 0` (:96994 at `2c501dc`). Run
(batches C, C2, D, J, M and P): the rebuilt list runs from 1 (`MinIndex=1`) and is kept.

- Cached .SLD list: a folder added with its subfolders is in the panel (7 rows), in the
  `[Folders]` section the save writes, and in the panel after the saved list is loaded
  again (batch C2). `Gamma`, cleared with «Ignore date change», has no mark after «Rescan
  folder(s)» on `Beta` (batch C). A rescan of the seed folder clears the mark of `Beta`
  (batch M).
- Database: the `staticfolders` table gets no empty row (batches D and J).

The three things listed above did come to the surface with it. They are N3, N4 and N5
under «New with the fixes».

## 4. «Ignore all changes» updates the highlighted rows only

`BTNignoreDateStaticFolder()` :95837, the button at :94020

```ahk
RowNumber := LV_GetNext(0, "F")
…
If (StrLen(folderu)<2 || folderu="folder path" || !RowNumber)
   Return
…
doAll := (totalSelected>=total || dummy="update-all") ? 1 : 0     ; :95861
```

The button and the menu item «Ignore date change» call the same function. Nothing passes
"update-all": the button hands over its window handle, the menu its item name (the text is
found once in the script, at :95861).

What happens (run, batch C, three folders marked):

- the button with no focused row: nothing, no message;
- the button with the `Beta` row highlighted: `Beta` alone is cleared, the other two keep
  their mark, and the message reads «Folders list information updated».

Correction: a small function for the button that passes "update-all", and the focused-row
test skipped in that case. Decision 1 asks what «all» covers when a filter is on.

**Fixed in `f88e4be`, `256a670` and `1813ca9`**, by the correction above. `f88e4be` renames
the function to `MenuIgnoreDateStaticFolder()` (:95845) and adds the small function for
the button:

```ahk
BtnIgnoreDateStaticFolder() {                    ; :95841
   MenuIgnoreDateStaticFolder("update-all")
}
```

At `54a0666` nothing called it: the button was bound to the renamed function, as the menu
item is, and did what it did at ab160cb (run, real clicks). `256a670` attaches the button
to it and lets "update-all" pass the focused-row test:

```ahk
; :94024
Gui, Add, Button, x+5 hp w%btnWid% gBtnIgnoreDateStaticFolder, I&gnore all changes
; :95851
If ((StrLen(folderu)<2 || folderu="folder path" || !RowNumber) && dummy!="update-all")
```

`1813ca9` makes «all» the rows the table lists, which is Marius's answer to the first half
of decision 1. The function notes the «#» of every listed row (:95896-95902), closes the
panel and updates those folders alone (:95904-95913). With no row listed it does nothing
(:95852).

Run on the text of `1813ca9`, with real clicks on the button and no focused row (batches C
and P):

- no filter, three folders marked: the three marks are cleared, the message reads
  «Folders list information updated», the panel is opened again and the list counts as
  modified;
- no filter, two folders marked, a row with no mark highlighted: the two marks are
  cleared;
- a filter that lists one folder, which has no mark: a marked folder that is not listed
  keeps its mark. The panel comes back with the filter still applied;
- a filter that lists the marked folder: its mark is cleared;
- a filter that lists nothing: nothing happens, no message, the panel stays, and the list
  does not count as modified;
- a folder that is missing from the disk keeps its mark (the rest of finding 17).

Between `256a670` and `1813ca9` the button covered every folder of the list, listed or not
(run on the text of `256a670`, batch P).

The menu item «Ignore date change» is as it was: it asks for a focused row and works on
the highlighted rows.

## 5. «Ignore date change» with a filter on updates folders that are not listed

`BTNignoreDateStaticFolder()` :95861, :95888

`total` is the number of listed rows. When every listed row is highlighted, `doAll` is 1,
and that branch walks the whole folders list, not the rows:

```ahk
Loop, % newStaticFoldersListCache.MaxIndex()
```

What happens (run, batch C): three folders marked, the filter `gamma` lists one row, that
row is highlighted, «Ignore date change». With the filter removed, `Holiday One` and `Beta`
have lost their marks too.

Correction: walk the highlighted rows in both cases, or take the `doAll` branch only when
the table lists every folder.

**Fixed in `f88e4be`**: `doAll` is 1 for "update-all" alone (:95869), so the menu item
always walks the highlighted rows. Run (batch C): the same steps; with the filter removed,
`Holiday One` and `Beta` still have their marks. This settles the second half of
decision 1.

## 6. On a cached .SLD list an ignored change is not saved

`BTNignoreDateStaticFolder()` :95837

The new date goes into `newStaticFoldersListCache` and, for a database, into the table. For
a cached .SLD list nothing else happens: `currentFilesListModified` stays 0.

What happens (run, batch C): after «Ignore all changes» on `Beta`,
`askAboutSlidesListSave()` answers 0, so QPV closes the list without a question; loaded
again, `Beta` is marked.

Correction: `currentFilesListModified := 1` when a date was changed and the list is a
.SLD. With finding 3 uncorrected, a later rescan discards the change anyway.

**Fixed in `f88e4be`** by the correction above (:95908-95909): once the dates are written,
a list that is not a database is marked as modified. Run (batches C and P): after «Ignore
date change» on `Beta`, `askAboutSlidesListSave()` asks «Would like to save the currently
opened files list?»; saved and loaded again, `Beta` has no mark.

One thing is left: the flag is set whenever the function reaches its end, also when no
date was changed. On a folder that is missing from the disk the mark stays, the message
reads «Folders list information updated» and the list counts as modified (run, batch P,
the same on `2c501dc`).

Since `2c501dc` a later «Rescan folder(s)» keeps an ignored change that was not saved yet
(finding 3). Run (batch C): `Gamma`, cleared this way, has no mark after the rescan of
`Beta`.

## 7. The filter cannot be removed after the panel reopened with it

`createSettingsGUI()` :27979, `UIlvFilterEraseStaticPanel()` :93607,
`UIeditApplyStaticFolderFilter()` :97630

The panel remembers the filter text in `staticListViewFilteru` and applies it when it
opens. `createSettingsGUI()` empties `lastFilterEditSearch` on every opening. The eraser
then believes there is nothing to erase:

```ahk
GuiControlGet, OutputVar, SettingsGUIA:, StaticListViewFilteru
If (!OutputVar && !lastFilterEditSearch)
   Return
```

What happens (run, batch A): filter `holiday`, one row. The panel is closed and opened
again: the box holds `holiday`, one row. The box is emptied and «Apply» pressed: still one
row, the box is empty. «X»: the same. Typing something else, applying it and emptying the
box again does remove it. «X» pressed while the text is still in the box works (read).

The panel reopens by itself after «Rescan folder(s)», «Erase files from the index», «Count
files per folders», «Ignore all changes» on every row and a rename, so this state is the
usual one after any of them.

Correction: after `createSettingsGUI()`, in the panel,
`lastFilterEditSearch := Trimmer(staticListViewFilteru)`.

**Fixed in `f88e4be`** by the correction above (:94008). Run (batch A): the panel reopens
with `holiday` in the box and one row; the box emptied and «Apply» lists the five folders,
and so does «X».

## 8. The «greater than» number filters keep every row at 0

`PopulateStaticFolderzList()` :97875

```ahk
If ((thisValue>=givenLimit && limitMode=1) || (thisValue<=givenLimit && limitMode=2) && countFiles && thisValue)
   Continue
```

`&&` binds before `||`, so the last two conditions belong to the «greater than» half
alone, and `&& thisValue` exempts every row whose value is 0.

What happens (run, batch A; `Alpha` has 3 selected files of 3, `Beta` 1 of 2, the other
three folders none):

- `:>1` (more than one selected file) lists `Alpha` and the three folders with 0;
- `*>50` (more than 50 %) lists `Alpha` and the three folders at 0 %;
- `:<2`, `*<50`, `?>2`, `?<3` list what they should.

The same holds for `!>`, `#>` and `$>` (read): a folder never counted on the disk has 0 or
nothing there.

Also: a limit of 0 or below is not accepted (`givenLimit>0`), so `?>0` lists everything
and a negative «Difference» cannot be asked for (read). On a cached .SLD list the «Files»
cells are empty until a row is clicked, and `?>100` then lists every folder (read).

Correction, with decision 8:

```ahk
If (filterWhat && thisValue!="")
{
   If ((limitMode=1 && thisValue>=givenLimit) || (limitMode=2 && thisValue<=givenLimit))
      Continue
}
```

**Fixed in `f88e4be`** by the correction above (:97887-97891), which settles decision 8: a
row with no count is listed.

- Run (batch A): `:>1` and `*>50` list `Alpha` alone.
- Run (batch P, a cached .SLD list whose «Files» cells are still empty): `?>100` and
  `?<100` list the five folders, and so does `!>1`. Once `Alpha` was counted on the disk (3
  files), `!>5` leaves it out and lists the other four.
- «Difference» and «Size (MB)» are 0 for a folder that was never counted, not empty:
  `#>1` and `$>1` list nothing there (run, batch P).

As before: a limit of 0 or below is not accepted, so `?>0` lists everything (run, batch A).

## 9. «Selected» column: zeros at the first opening, stale afterwards

`PanelStaticFolderzManager()` :94026, `LoadStaticFoldersCached()` :35025,
`PopulateStaticSQLfolderzList()` :97698

```ahk
thisList := "a" maxFilesIndex markedSelectFile newStaticFoldersListCache.Count()
If (newStaticFoldersListCache.Count()>0 && markedSelectFile>1 && thisList!=iduStaticFoldersListCache)
   countAllFilesPerStaticFolders("start")
```

The selected files are counted per folder only when the folders list is already loaded, two
or more files are selected, and this text differs from the one stamped last time.

What happens (run):

- **cached .SLD list, files selected before the first opening** (batch L): «Selected» is 0
  for every folder. The list is loaded after the test, and `LoadStaticFoldersCached()`
  stamps the text without counting. The second opening shows 0 again. The numbers come once
  the selection changes size;
- **database, the same** (batch L): 0 everywhere at the first opening, right at the
  second. `PopulateStaticSQLfolderzList()` stamps nothing;
- **the selection moves to other files, its size stays the same** (batch B): two files of
  `Alpha`, then two files of `Beta` instead. The panel still shows `Alpha` 2, `Beta` 0;
- **one selected file** (batch B): the test asks for more than one, so the column keeps
  the numbers of the earlier selection;
- a plain folder at its first opening is right (batch L): the generation counts.

The help text names this column as a way to see, per folder, the files selected by other
tools before the panel is opened. That is the first case.

The stamped text is three numbers written one after the other with nothing between them,
so different states can give the same text (12 files, 34 selected, 5 folders and 123
files, 4 selected, 5 folders both give `a12345`).

Correction: stamp a text that holds `lastZeitFileSelect` (it changes with every selection
change; `getSelectedFiles()` uses it the same way at :39514), with separators; count when
`markedSelectFile>0` and whenever the folders list was just loaded.

**Partly fixed in `2c501dc`**: the first half of the correction is in. The text is made
in one place, with separators, and holds `lastZeitFileSelect` and the kind of list:

```ahk
getStaticFoldersListID() {      ; :94064
   thisList := "a" maxFilesIndex "|" markedSelectFile "|" newStaticFoldersListCache.Count() "|" lastZeitFileSelect "|" SLDtypeLoaded
```

The test that decides whether to count is as it was (:94059 at `2c501dc`): the folders
list already loaded, and more than one selected file.

- **Fixed: the selection moves to other files, its size stays the same** (run, batch B):
  two files of `Alpha`, then two files of `Beta` instead. The panel shows `Alpha` 0,
  `Beta` 2.
- **As before: files selected before the first opening** (run, batch L). Cached .SLD
  list: 0 for every folder at the first opening and at the second; the numbers come once
  the selection changes. Database: 0 everywhere at the first opening, right at the second.
- **As before: one selected file** (run, batch B): with one file selected, in `Gamma`,
  the column still shows `Beta` 2 and `Gamma` 0.

## 10. «Files» column and the folders themselves do not follow the index

The folders list of a plain list is generated once and kept. Nothing regenerates it when
the index changes, and the count that the panel runs by itself needs a selection (finding
9).

What happens (run, batch B, plain folder, no selection):

- two entries of `Holiday One` are removed from the index («Remove focused index entry»,
  Alt+Delete): the panel still shows 4 files;
- a folder is added with «Add seed folder(s)»: its three files are in the index, the
  folder is not in the panel;
- «Count files per folders» corrects the 4 to 2 and does not bring the folder in.
  `countAllFilesPerStaticFolders()` looks the folder up, finds nothing, and writes its
  count under an empty key of the folders list (:96743-96748; `Count()` is then one more
  than `MaxIndex()`);
- «Regenerate this folders list» brings it in.

On a cached .SLD list, a folder added **without** its subfolders never reaches the folders
list (run, batch C2): `wrapperAddNewFolderToList()` answers "null" for an entry with the
`|` prefix (:65708), and the caller then skips `updateCachedStaticFolders()`.

In a database the counts come from the `images` table when the list is built, and are kept
until the list is emptied.

Correction: decision 5.

## 11. Ctrl+A on a freshly opened panel leaves every action dead

Every action starts with

```ahk
RowNumber := LV_GetNext(0, "F")
…
If (StrLen(folderu)<2 || folderu="folder path" || !RowNumber)
   Return
```

and then works on the highlighted rows. One ordinary state has highlighted rows and no
focused one: a freshly opened panel after Ctrl+A or «Select entire table».
`LV_Modify(0, "+Select")` focuses nothing.

What happens (run, batch A): the panel opens with the keyboard focus in the list and no
focused row. After Ctrl+A, 5 rows are highlighted and none is focused. «Rescan folder(s)»
does nothing, F5 does nothing, «Copy folder path(s) as text» copies nothing, and the menu
holds only its lower half: no «Rescan», «Select files», «Erase files», «Open folder». A
click on a row first, then Ctrl+A, works.

Seen under Wine only: whether a list view on Windows gives a row the focus by itself was
not run. The case to try: open the panel, press Ctrl+A, press F5.

Correction: when no row is focused, take the first highlighted one (`LV_GetNext(0)`); or
give row 1 the focus when the list is filled.

## 12. F3 on two or more folders drops the files selection

`UIfilterListToSelectStaticFolders()` :96652

```ahk
dropFilesSelection(1)
BTNselFilesStaticFolder()
BtnCloseWindow()
filterToFilesSelection()
dropFilesSelection(1)
```

With several folders highlighted, the filter is built by selecting their files and
filtering to the selection.

What happens (run, batch E): three files of `Holiday One` are selected. F3 on `Alpha` and
`Beta`: the list is filtered to their five files. With the files filter removed, no file
is selected. No question is asked. F3 on one folder keeps the selection (run): it goes
through `uiFilterListDynaFolder()`, which filters on the folder path.

Correction: decision 4. The one-folder filter is a regular expression on the folder path;
one made of the highlighted paths would keep the selection.

## 13. A stopped «Count files per folders» leaves zeros that pass as counts

`countAllFilesPerStaticFolders()` :96662

The function first writes 0 into the «Files» and «Selected» values of every folder, then
counts. When the user stops it, nothing is written back, and the list is stamped as counted
all the same (:96751).

What happens (run, batch A, the stop at the first step): every folder shows 0 files. The
panel closed and opened again shows the same. The count a click on a row runs does not
help: it runs for an empty cell, not for a 0 (:96608).

The same function runs by itself when the panel opens with files selected.

Correction: on a stop, empty the two values (an empty cell is counted on click) and do not
stamp the list.

## 14. «Rescan folder(s)» on a folder that cannot be reached removes its entries

`BTNupdateSelectedStaticFolder()` :97606, `coreAddNewFolder()` :65944,
`wrapperAddNewFolderToList()` :65723

A rescan removes the folder's entries, scans the folder and, in a database, purges what was
not found: `SQLdeleteEntriesMarked(2, …)` deletes the rows of `images` and their
`imagesPixels` rows. A folder that is not there scans as empty.

What happens (run, batch J, database): `Beta` is moved away. The panel shows it with the
changed mark and today's date (finding 17), like a folder with new files. «Rescan
folder(s)» on it: its two entries are gone from the index and from the database, and the
folder is gone from the panel. Nothing is said.

For a folder on an unplugged drive or an unreachable share this erases, with the entries,
the image properties and the fingerprints collected for them. «Regenerate entire index»
does the opposite for a seed folder that is not there: it skips it and keeps its entries
(:87230).

Correction: decision 2.

Open at `2c501dc`: the entries are removed as before (run, batches J and Q). The folder
itself now keeps a row with no date: in the `staticfolders` table since `f88e4be`, and
since `2c501dc` also in the panel and in the `[Folders]` section of a cached .SLD list.
See N6 under «New with the fixes».

## 15. Database: after «Rescan folder(s)» the viewport shows an image that is no longer current

`wrapperAddNewFolderToList()` :65733, `BTNupdateSelectedStaticFolder()` :97602-97627

```ahk
If (isInLoop!=1)
   SetTimer, RandomPicture, -100 ; coreAddNewFolder() left the display refresh to us
```

The button calls with `isInLoop=1` and does not refresh anything after its loop. The rescan
rebuilds the index, which sets `currentFileIndex` to 1.

What happens (run, batch D): the viewport is on file 10. After the rescan
`currentFileIndex` is 1 and no image was loaded (`IDshowImage()` ran 0 times), so the
window behind the panel keeps the image it had. Whatever acts on «the current file» next
acts on file 1.

On a plain or .SLD list the same rescan ends in `RandomPicture()`: a random image is shown
and it is the current one (run, batch C). With N folders it runs N times.

Correction: one refresh after the loop. Decision 3 asks which image it should be.

Open at `2c501dc` (run, batch D: `currentFileIndex` goes from 10 to 1 and `IDshowImage()`
ran 0 times). «Erase files from the index» now leaves the same state, on every kind of
list: see N1 under «New with the fixes».

## 16. F2 in a database opens the rename the menu leaves out

`invokePanelStaticFoldersContextMenu()` :93456, `uiLVfolderzFilterListBTN()` :96554-96559,
`PanelRenameStaticFolder()` :97230

The menu offers «Rename index entry» only when `SLDtypeLoaded!=3`. The F2 key tests the
cached-list condition alone, which a database meets.

What happens (run, batches D and D2): F2 on `Beta` opens «Rename static folder entry». A
new path and «Yes» to the search and replace: the two files are moved to the new folder in
the index and in the `images` table. The panel comes back with `Beta` and its 2 files, and
without the new folder; the `staticfolders` table keeps `Beta`. For a database the function
changes nothing in the folders list (`Sleep, 25` at :97232).

Correction: decision 6.

## 17. Private mode marks every folder as changed; a missing folder is dated today

`PopulateStaticFolderzList()` :97842-97854

```ahk
If (userPrivateMode=1)
   folderu := "*:\********\******\"
…
FileGetTime, dirDateO, % folderu, M
statusu := (dirDateO!=oldDateu && isUpdateList=1) ? "*" : ""
dirDate := SubStr(dirDateO, 1, StrLen(dirDate) - 2)
FormatTime, dirDate, % dirDate, yyyy/MM/dd
```

The path is replaced by the mask before the date is read. The read fails, `dirDateO` is
empty, and `FormatTime` given an empty time uses the present moment.

What happens (run, batch C):

- private mode: every row has the mark and today's date, the unchanged folders too;
- a folder removed from the disk: its row has the mark and today's date.

Correction: read the date from the real path and mask the text of the row only; write «-»
or nothing when the date cannot be read.

**Partly fixed in `f88e4be`**: the path is masked after the date was read (:97865-97866).
Run (batch C): in private mode the three changed folders have the mark and their own
dates; the other two have no mark. A folder removed from the disk still has the mark and
today's date (run, batches C and P).

## 18. «Regenerate entire index» leaves the marks of a cached .SLD list

`RegenerateEntireList()` :87186

The function empties the folders list (:87205) and scans every seed folder. For a database
it then regenerates the `staticfolders` table (:87266). For a .SLD list nothing regenerates
the dates, so the next opening of the panel reads the folders list from the file.

What happens (run, batch M): `Beta` is marked. «Regenerate entire index», then the panel:
`Beta` is still marked. «Regenerate this folders list» clears it, and a save keeps that.

With findings 2 and 3, on a cached .SLD list the mark of a folder goes away in two ways
only: «Ignore date change» followed by a save, and «Regenerate this folders list» followed
by a save.

Correction: for a cached .SLD list, `GenerateStaticFoldersListNow()` once the scan ended.

**Fixed in `2c501dc`** by the correction above (:87307-87308 at `2c501dc`). Run (batch Q):
`Alpha` is marked. After «Regenerate entire index» the folders list in memory holds the
five folders with their dates on the disk and their file counts, and the panel shows no
mark. The list counts as modified, so closing it asks to save. Closed without a save and
loaded again, `Alpha` is marked, as after any change that was not saved.

With findings 2 and 3 fixed as well, the mark of a folder on a cached .SLD list now goes
away after «Rescan folder(s)», a rescan in the seed folders panel, «Ignore date change»,
«Regenerate this folders list» and «Regenerate entire index»; a save keeps it.

## 19. «Rename index entry» with «Propagate the change to subfolders» unticked

`PanelRenameStaticFolder()` :97235-97245, `SearchAndReplaceThroughIndex()` :97409

The tick decides which entries of the folders list are renamed. The search and replace that
follows always covers the subfolders (`folderMode=1`).

What happens (run, batch H, cached .SLD list): `Alpha` renamed with the box unticked,
«Yes» to the search and replace: «5 records were modified», the three files of `Alpha` and
the two of `Alpha\Sub`. The folders list then holds the new folder and the old `Alpha\Sub`,
which no file is in any more; the new subfolder is not listed.

Correction: decision 7.

## 20. Folders dropped when a cached .SLD list is loaded

`LoadStaticFoldersCached()` :35071

```ahk
If (RegExMatch(line, "i)^(Fi[0-9].*\=.{14}\*\&\*[a-z]\:\\..)") && !RegExMatch(line, RegExFilesPattern))
```

- The date must be 14 characters. `GenerateStaticFoldersListNow()` writes «-» for a folder
  it cannot reach (:35282), and `PopulateStaticFolderzList()` has a branch for that value
  (:97846). The line `Fi4=-*&*…\gamma` is saved and then skipped on load (run, batch H):
  the index holds the folder's file, the panel does not list the folder.
- The path must be a drive letter, `:\` and two more characters (read). A drive root,
  stored as `d:`, and a folder with a one-letter name do not pass.

Correction: accept «-» and an empty date, and a path of two characters or more.

**Partly fixed in `2c501dc`**: the test is now (:35077 at `2c501dc`)

```ahk
If (RegExMatch(line, "i)^(Fi[0-9].*\=(?:.{14}|.?)\*\&\*[a-z]\:\\.)") && !RegExMatch(line, RegExFilesPattern))
```

- **Fixed: the date «-».** Run (batch H): the line `Fi4=-*&*…\gamma` is loaded, and the
  panel lists the folder with «-» in the «Date» and «(?)» columns.
- **Fixed: an empty date, and a folder with a one-letter name under a drive root.** Run
  (batch Q, four lines written by hand into the `[Folders]` section of a saved list):
  `q:\a` with a date, `q:\bb` with no date and `q:\cc` with «-» are loaded.
- **As before: a drive root.** The line for `q:` is skipped (run, batch Q). The pattern
  still asks for `:\` and one more character.

A folder loaded this way does not stay for long. Since `2c501dc` the next «Rescan
folder(s)», of any folder, drops every folder that is not on the disk and every path under
five characters, `q:\a` among them (the first run in batch Q, the second read). See N3
under «New with the fixes».

## 21. A list that was never saved: marks that cannot be cleared

After «Add seed folder(s)» with no list loaded, the list is named `NewFilesList.SLD`, a
file that is not on the disk. The panel's own test asks for the file (`FileExist()` at
:93992): the title is «Static folders list» and there is no «Ignore all changes» button.
The row filler and the menu do not ask for it (:97788, :93420).

What happens (run, batch I): a folder that changed gets the mark, the menu offers «Ignore
date change», and choosing it answers «The loaded .SLD file does not seem to be in the
correct format. Operation aborted.» «Rescan folder(s)» runs and leaves the mark.

Correction: the same test in the three places.

**Partly fixed in `2c501dc`**: the menu now asks for the file before it adds «Ignore date
change» (:93462 at `2c501dc`), so the item is no longer offered on such a list (run, batch
I). The row filler still does not ask (:97851): the changed folder gets the mark, and
«Rescan folder(s)» runs and leaves it (run, batch I). The mark still cannot be cleared.

## 22. «Count selected files» lists every folder again

`SqlWrapPopulateStaticFolderzList()` :93481

It calls `PopulateStaticFolderzList()` with no filter text. Run (batch D): the filter
`alpha` lists 2 rows; after «Count selected files» the table lists 5 and the box still
holds `alpha`. The list is also filled without the opening's sort.

Correction: pass `staticListViewFilteru`.

**Fixed in `f88e4be`** by the correction above (:93485). Run (batch D): after «Count
selected files» the table still lists the 2 rows of `alpha`. The list is still filled
without the opening's sort (read).

## 23. «Erase files from the index» on N folders

`BTNremFilesStaticFolder()` :96082-96090, `coreRemFilesStaticFolder()` :96263

Each highlighted folder goes through `remFilesFromList()` (one pass over the whole index
and a 25 ms sleep), then `GenerateRandyList()`, a 100 ms beep and `RandomPicture()`, which
shuffles the whole index again. Run (batch D, two folders): 2 passes, 2 shuffles, 2 random
images. With a hundred folders highlighted that is a hundred of each, ten seconds of beeps
included.

Also (read): `If (maxFilesIndex>1)` at :96084 makes the action do nothing, silently, on an
index of one file, and the panel is opened again.

Correction: remove the files of every highlighted folder in one pass, then refresh once.

**Partly fixed in `2c501dc`**: each highlighted folder now goes straight to
`remFilesFromList()`, with its messages off (:96142 at `2c501dc`), and
`coreRemFilesStaticFolder()` is no longer called from here. Run (batch D, two folders): 2
passes over the index, no shuffle, no beep, no random image.

Left: the index is still walked once per highlighted folder, with a 5 ms sleep each, and
`If (maxFilesIndex>1)` (:96140) still makes the action do nothing on an index of one
file (read).

New: nothing is refreshed after the loop, and an index left empty is not handled. See N1
and N2 under «New with the fixes».

## 24. «Rescan folder(s)» turns the folder part of the paths to lower case

`BTNupdateSelectedStaticFolder()` :97588, :97606

The folders list holds lower-case paths, and the rescan scans that spelling. Run (batch C):
`…\pv\Beta\b1.png` becomes `…\pv\beta\b1.png` in the index, in everything that shows or
copies the path, and in the saved list. The files are also moved to the end of the index. A
database stores lower-case paths anyway.

Correction: decision 10.

## 25. «Count files in folders found on disk»: «Difference» stays for a folder with nothing indexed

`countFilesDiskPerStaticFolders()` :35193

```ahk
If newStaticFoldersListCache[indexu, 3]
   LV_Modify(RowNumber, "Col9", filez - newStaticFoldersListCache[indexu, 3])
```

Run (batch D): `Alpha` has 0 indexed files and 3 on the disk. The row shows 3 and a
difference of 0; the panel closed and opened again shows 3 and 3.

The item sits in the part of the menu that is always shown, next to «Count files per
folders», which counts every folder. This one counts the highlighted rows, asks for a
focused row first, and passes over a folder that is not on the disk without a word (run,
batch H). A count that was stopped writes the part it reached (read).

Correction: drop the test, or write `filez` when the value is empty.

**Fixed in `2c501dc`** by dropping the test (:35196 at `2c501dc`):

```ahk
LV_Modify(RowNumber, "Col9", filez - Round(newStaticFoldersListCache[indexu, 3]))
```

Run (batch D): `Alpha`, with 0 indexed files and 3 on the disk, shows a difference of 3
at once, and the same after the panel is closed and opened again.

On a row whose «Files» cell is still empty (a cached .SLD list before a click on the
row), the cell now shows the whole disk count as the difference; when the table is filled
again, the row filler writes 0 for such a row (:97923; read).

The menu now offers the item only when the table lists a row (:93477). The action still
asks for a focused row and still passes over a folder that is not on the disk without a
word (run, batch H).

## 26. «%» and «Size (MB)» are sorted as whole numbers

`PopulateStaticFolderzList()` :97779-97783

Every column but 2, 3 and 4 is declared `Integer`. Columns 7 and 10 hold one decimal. Run
(batch E): 33.3, 33.7, 33.5, 90 and 10.9 sorted with the highest first give 90, 33.3,
33.7, 33.5, 10.9.

Correction: `Float` for columns 7 and 10.

**Fixed in `f88e4be`** by the correction above (:97795-97796). Run (batch E): the same
values give 90, 33.7, 33.5, 33.3, 10.9. «Size (MB)» with 1.5, 10.2, 2.7, 0.9 and 33.1 gives
33.1, 10.2, 2.7, 1.5, 0.9.

## 27. F3 on a row that was not counted yet needs two presses

`uiLVfolderzFilterListBTN()` :96564-96567, :96608

F3 calls `MenuFilterListSelectedFolder()`, which calls the handler again. `A_GuiEvent` is
still «K» in that second call, so the branch that counts the files of a row with an empty
«Files» cell runs and returns:

```ahk
} Else If ((A_GuiEvent="Normal" || A_GuiEvent="K") && files="" && whichLV="LViewOthers")
```

Run (batch I, a real key message, cached .SLD list): the first F3 fills the «Files» cell
and nothing else; the second one filters. A row has an empty cell when it got the focus
without a click or an arrow key, for instance through a right-click.

Correction: test the event the handler was given (`b`), not `A_GuiEvent`.

**Fixed in `f88e4be`** by the correction above (:96618). Run (batch I, a real key
message): the first F3 filters the files list. A key the list view reports by itself still
counts a row with an empty «Files» cell (run, batch P: a Down key on such a row fills it).

## 28. Actions on a folder that is missing from the disk

`BtnPanelManageFoldersActus()` :96462, `setContaintFolderAsProtected()` :39915

Run (batch H, the highlighted folder was removed from the disk):

- «Open folder now», «In Explorer» (F6), «Copy folder (Explorer mode)» and «Count files in
  folders found on disk» do nothing and say nothing; «Cut folder» is the same function.
  The Explorer error message is shown only `If !AnyWindowOpen` (:96492), and the panel is
  open;
- «Set as the protected folder» answers «The protected folder path is now: …\Holiday One\»:
  the folder of the image in the viewport, by the fallback at :39923.

Also (read): «Open folder now» closes the panel before its three questions (unsaved image,
unsaved list, selection); «Cancel» at any of them leaves no panel.

Correction: one message for a missing folder, before the action.

**Partly fixed in `2c501dc`.** Run (batch H, the same steps):

- «In Explorer» (F6) answers «ERROR: An unknown error occurred opening the folder:» and
  the path. The message is now shown while a panel is open too (:96548-96549 at
  `2c501dc`);
- «Open folder now» answers «ERROR: Folder not found or access denied:» and the path, and
  the panel stays open (:96564-96565);
- «Set as the protected folder» is refused with «WARNING: The folder selected no longer
  exists. Action refused.» (`setContaintFolderAsProtected()` :39926-39927), and no other
  folder is protected in its place. The second line of the message is not the folder that
  was refused: it is the folder protected until then, or a lone `\` when there is none.
  Run (batch Q): with `Alpha` protected, the refusal for `Gamma` reads `…\pv\Alpha\`. The
  message prints `protectedFolderPath` where `givenPath` is meant;
- «Copy folder (Explorer mode)», «Cut folder» and «Count files in folders found on disk»
  still do nothing and say nothing.

As before (read): «Open folder now» on a folder that exists closes the panel before its
three questions (:96567).

## 29. Alt+right-click deselects the files and opens the menu too

`uiLVfolderzFilterListBTN()` :96604, `SettingsGUIAGuiContextMenu()` :25932

A right-click on a row reaches the list's handler as «RightClick» and, after it, the
window's context-menu handler. Run (batch N, the pointer moved onto a row and a right-click
posted): both ran, in that order. With Alt held the first one deselects the folder's
files; the second one has no Alt test, so the menu opens afterwards.

Correction: return from the context-menu handler while Alt is down.

## 30. Small things

- **The filter row is 17 pixels wider than the table** (run, batch J): the box is the
  table's width less 90, «Apply» is 60 and «X» is 45, with two gaps of 1 (:94012-94016).
  With large fonts the sum is the same 17 over.
- **«Deselect all (files list)»** leaves the «Selected» and «%» cells as they were until
  the panel is opened again (run, batch J).
- **«View list as a folders tree» on an empty list** closes the panel and opens nothing
  (run, batch G). The list is empty when the generation question was answered «No».
- **The menu begins with a separator** when no row is focused (run, batch A).
- **Alt letters used twice in the menu**: S («Select files», «Set as the protected
  folder») and C («Copy folder path(s) as text», «Count files per folders», «Count files
  in folders found on disk», «Copy entire list as text»).
- **Order**: a plain list comes in no order a user can read (the order of the hash table,
  run). After «Apply» or «X» the changed folders are no longer first and the columns keep
  the widths of the opening (read).
- **A stopped listing** shows the rows it reached, and the box reads «Filter folders list:
  N entries» (read).
- **Generating or regenerating the folders list removes the files-list filter**, without
  saying so (:35095, :35124; read).
- **The unsaved-image question is asked again** at every reopening of the panel, for as
  long as the image stays unsaved (:93986; read).
- **`createSettingsGUI()` can refuse** and return nothing. The panel does not test it, as
  58 of its 75 callers do not, and goes on adding controls (read).
- **While a folder is rescanned** the message shows the path with the `|` prefix, and in
  private mode the real path (`wrapperAddNewFolderToList()` :65702; read).
- **«Files on disk» counts files above 120 bytes** (:31048), as the fallback scanner does
  (:88592); `GetFilesList()` indexes files above 42 (:88896; read).
- **`SQLdbGenerateStaticFolders()` empties the table before its query**, outside the
  transaction; a failed query leaves it empty (:34540; read).
- **Two parameters that nothing passes**: "update-all" (finding 4) and `updateAllDates` of
  `updateCachedStaticFolders()`.
- **The first line of the panel** says the list «was generated based on the indexed
  files»; for a cached .SLD list it is read from the file.

**Partly fixed.** Three points are fixed in `2c501dc`, and half of one since `f88e4be`.
The others are as they were. Lines are at `2c501dc`.

- **«View list as a folders tree» on an empty list: fixed.** The menu offers the item only
  when the table lists a row (:93489), and the function returns when it lists none
  (:96071). Run (batch G): the panel stays open.
- **The menu begins with a separator: fixed.** The separator is added with the items of
  the focused row (:93468). Run (batches A and G).
- **`createSettingsGUI()` can refuse: fixed for this panel**, which now returns
  (:94021-94022; read).
- **Two parameters that nothing passes**: "update-all" is passed since `f88e4be`, by
  `BtnIgnoreDateStaticFolder()` (finding 4). `updateAllDates` is still passed by nothing.
- **«Deselect all (files list)»: as before.** `2c501dc` gives the menu item a function of
  its own, `MenuStaticFoldersDropFilesSelection()` (:93496), whose loop over the rows
  holds a to-do comment and no code yet. Run (batch Q): the «Selected» and «%» cells keep
  `Alpha` 3 and 100.0 until the panel is opened again.

One small thing more, with `2c501dc`: the menu also leaves out «Count files in folders
found on disk» and «Copy entire list as text» when the table lists no row (:93477-93481;
run, batch G). The number tested is that of the listed rows, so a filter that lists
nothing hides them, and «View list as a folders tree» with them, though the folders list
is not empty and the last two work on the whole list (read).

---

## A trial of the three main corrections

A scratch copy with three changes, kept as `trial-three-corrections.diff` in the kit
folder, was run through batches C, C2, D and M:

```ahk
; updateCachedStaticFolders()
If IsObject(mainFolderu)
{
   foldersListArray := mainFolderu
} Else
{
   foldersListArray := new hashtable()
   …
}
counter := 0

; SQLdbGenerateStaticFolders(), its last lines
If !activeSQLdb.Exec("COMMIT TRANSACTION;")
{
   throwSQLqueryDBerror(A_ThisFunc)
   Return 0
}
Return 1
```

With them:

- «Rescan folder(s)» clears the mark on a cached .SLD list and in a database; the changes
  ignored earlier stay ignored; the table gets no empty row;
- a folder added with its subfolders is in the panel and in the saved `[Folders]` section;
- a rescan of the seed folder clears the mark;
- database: «Regenerate this folders list» brings the panel back with `whileLoopExec` 0.

Still as before, each with its own cause: a folder added without its subfolders (finding
10), «Regenerate entire index» (18), the viewport after a database rescan (15). The three
things the counter correction brings to the surface are listed under finding 3.

**At `54a0666`** two of the three corrections are in the code: the `Return` values (finding
1) and `foldersListArray := mainFolderu` (finding 2). `counter := 0` is not (:96943). Of the
four results above, the last one holds. The first holds in a database, and for the mark
alone: the table still gets its empty row. On a cached .SLD list the first three are as
they were without the trial (run, batches C, C2, D, M and P).

**At `2c501dc`** the third correction is in the code too (:96994), and the four results
all hold (run, batches C, C2, D, M and P). Of the three points listed as «still as
before», «Regenerate entire index» is fixed (finding 18); the other two are open. The
three things the counter correction brings to the surface are now what the application
does: N3, N4 and N5 below.

## New with the fixes

What the commits changed besides the findings they fix. The points are numbered N1 to N7
so that the notes above can name them.

### With `2c501dc`

Run on `2c501dc`. Where it says so, the same steps were run on `1813ca9` too, to tell
what is new. Lines are at `2c501dc`.

**N1. «Erase files from the index» leaves the viewport on an image that is no longer the
current file** (medium; run, batch Q).
`BTNremFilesStaticFolder()` :96142, `remFilesFromList()` :97210,
`renewCurrentFilesList()` :64387

Each call of `remFilesFromList()` rebuilds the index through `renewCurrentFilesList()`,
which sets `currentFileIndex` to 1. The random image that followed it went away with the
correction of finding 23, and nothing took its place.

What happens (plain folder, file 10 is the current one, `Gamma` erased):
`currentFileIndex` is 1, no image was loaded (`IDshowImage()` ran 0 times), and the panel
is back. The window behind the panel keeps the image it had; whatever acts on «the current
file» next acts on file 1. On `1813ca9` the same step loads one image, which becomes the
current file.

This is the state finding 15 describes for a database rescan. It was run on a plain list;
a cached .SLD list and a database go through the same lines (read). Correction: one
refresh after the loop; decision 3 asks which image.

**N2. «Erase files from the index» on every folder leaves an empty index, and says
nothing** (medium; run, batch Q).
`BTNremFilesStaticFolder()` :96138-96152, `remFilesFromList()` :97211

What happens (plain folder, every row highlighted): 5 passes. `maxFilesIndex` is then
empty, not 0: `remFilesFromList()` gives it a counter that was never set when no file is
kept. The panel comes back with 0 files in every row, `CurrentSLD` still names the folder,
and no image was loaded. No message.

On `1813ca9` the same step ends with the box «No files left in the index of Quick Picto
Viewer, please load a files list or folder.», with «Begin from scratch», «Reload current
list» and «Ignore». That box came from `handleEmptyFilesList()`, which
`coreRemFilesStaticFolder()` called and the panel no longer reaches.

Correction: after the loop, when `maxFilesIndex<1`, call
`handleEmptyFilesList(CurrentSLD, "", 2)`, as `coreRemFilesStaticFolder()` does.

**N3. A folder that is not on the disk is dropped from the folders list when any folder
is rescanned** (medium, decision 9; run, batch Q).
`updateCachedStaticFolders()` :97003

```ahk
If (!FolderExist(folderu) || hash[z]=1 || StrLen(folderu)<5)
   Continue
```

The rebuilt list is now the one that is kept, so this test decides what stays.

- **Cached .SLD list.** `Gamma` is moved away, as the folders of an unplugged drive would
  be, and `Beta` is rescanned. `Gamma` is gone from the panel and from the folders list in
  memory; its file is still in the index. Saved, the `[Folders]` section has no line for
  it. With `Gamma` back on the disk and the saved list loaded again, the index holds its
  file and the panel does not list the folder. «Regenerate this folders list» brings it
  back (read: it builds the list from the index). On `1813ca9` the same steps keep `Gamma`
  listed, in the panel and in the saved file.
- **Database.** `Beta` is moved away and `Alpha` is rescanned. `Beta` is gone from the
  panel and from the `staticfolders` table; its two rows stay in `images`. With `Beta`
  back and the database opened again, the panel lists it with the changed mark: its
  recorded date went with the table row. On `1813ca9` the table row was lost the same way,
  since the table is written from the rebuilt list, and the panel went on listing the
  folder.
- **Paths under five characters** (`c:\a`, a drive root) are dropped by the same test at
  every rescan (read).

Correction: decision 9. To keep such folders, take `!FolderExist(folderu)` out of the
test and lower the length to 2, which the second loop already uses (:97023).

**N4. Database: the «Files» cell of a rescanned folder stays empty** (low; run, batches D
and Q).
`BTNupdateSelectedStaticFolder()` :97666

The button empties the folder's count before the rescan, and nothing fills it now that the
list is no longer read again from the database.

What happens: after «Rescan folder(s)» on `Gamma` and `Beta`, both rows have an empty
«Files» cell. It is still empty after the panel is closed and opened again, and after
«Count selected files». The count that a click or a key on the row runs fills it
(:96669; called by hand in the run: `Gamma` 1). Until then «%» is 0 and the number filters
list the row whatever the limit: `?>1` lists `Gamma`, which has one file. On `1813ca9`
both cells are filled when the panel comes back.

Correction: count the files of each rescanned folder after the rescan, or leave the old
count in place until then.

**N5. The folder given to a rescan becomes a row of its own** (low; run, batch M).
`updateCachedStaticFolders()` :96980-96988, :97020-97028

When it is handed a folder path, the function notes that folder and every subfolder found
on the disk, and adds each one the folders list does not have yet, whether the index
holds a file of it or not.

What happens (cached .SLD list): after the seed folder `pv` is rescanned from the seed
folders panel, the folders list holds a sixth entry, `pv`, though no image sits directly
in it, and the panel lists it with no files. «Regenerate entire index» removes it (run).
A save before that writes it into `[Folders]` (read). A subfolder with no image in it
gets a row the same way, and so do the folders that «Add seed folder(s)» walks (read).

Correction: add a folder only when the index holds a file placed directly in it.

**N6. A rescanned folder that cannot be reached keeps a row with no date** (low; run,
batches J and Q).
`updateCachedStaticFolders()` :97003, :97020-97028

Its entries are removed as before (finding 14). The first loop drops the folder (N3); the
second one adds it again as a new folder, with the empty date the button read for it.

- **Database** (batch J): the panel lists `Beta` with no files, today's date and no mark.
  The row goes when the folders list is built again from the database, which lists the
  folders that have images (read). The `staticfolders` table keeps the row
  `(<pv\beta><>)`, as it does since `f88e4be`; before `2c501dc` the panel did not show it.
- **Cached .SLD list** (batch Q): the same row in the panel. The save writes
  `Fi4=*&*…\holiday one`, which the loader now accepts (finding 20), so the row is there
  after the list is loaded again. Once the folder is back on the disk the row has the
  changed mark (run); a rescan then scans its files back (read).

### With `f88e4be`

Run on `54a0666`, and again on `2c501dc`.

**N7. «Ignore date change» marks the list as modified when it changed nothing** (low; run,
batch P): on a folder that is missing from the disk (finding 6's note). The «Ignore all
changes» button does the same when none of the listed folders is marked.

The other point recorded here for `f88e4be`, the dateless row of a rescanned folder that
cannot be reached, is now N6.

## Seen in passing

Not part of the panel's own code.

- **A.** `ClipboardSetFiles()` (`lib/shell-stuff.ahk` :1668), with `foldersMode=1`, hands
  the same memory block to the clipboard under two formats («DropEffectFolderList» and
  «Preferred DropEffect»). The clipboard owns a block once it is set (read).
- **B.** `RegenerateEntireList()` starts at once, without a question. On a plain or .SLD
  list the index is emptied first, so a stop leaves a shortened index (read).
- **C.** After the rename of finding 16 the index holds the new folder as it was typed
  (`pv\BetaNew`) while the database holds it in lower case (run, batch D2).

## Checked and found correct

- The handlers shared with the seed folders panel (`BTNcopyStaticFolderPath()`,
  `BTNselFilesStaticFolder()`) name `LViewOthers`, which that panel does not have. They
  work there all the same: the panel's own list view stays the current one (run, batch F).
- The menu hands the item's name to its function, so «Cut folder» and «Copy folder» are
  told apart (run, batch J).
- Every action reads the «#» column, the position in the folders list, never the row
  number, so sorting the table does not mislead them (run, batches C and D).
- «Select files» and «Deselect files» keep `markedSelectFile` right and update their rows;
  «Erase files from the index» removes the files placed directly in the folder and leaves
  its subfolders; «Jump to first indexed file in folder», «Copy folder path(s) as text»
  and «Copy entire list as text» do what they say (run, batches D and J).
- A database's index holds every row of `images`, the ignored ones included, so the
  per-folder counts of the table match it (read).
- «Set as the protected folder» on a folder that exists protects that folder (read:
  `zPlitPath()` recognises a folder path), and the menu ticks the protected folder (run,
  batch N).
- Enter in the list jumps to the folder's first file and Ctrl+A highlights every row: the
  key routing keeps both away from the default button (read).
- The text filter: `|` separates alternatives, `*` and `?` are wildcards
  (`JEE_StrRegExLiteral()` :32758; read).

## Decisions to make before fixing

1. **«Ignore all changes»**: every folder of the list, or every listed row when a filter
   is on? And «Ignore date change» with every listed row highlighted: the highlighted rows
   alone? **Both are settled.** «Ignore all changes» covers every listed row: with a
   filter on, the folders that are not listed are left alone (`1813ca9`, Marius's answer).
   «Ignore date change» covers the highlighted rows alone (`f88e4be`).
2. **A rescanned folder that cannot be reached**: skip it, ask first, or remove its
   entries as now?
3. **After a rescan**, which image: the one that was shown, when it is still in the index;
   a random one, as the other lists do now; or the first? Since `2c501dc` the same
   question holds after «Erase files from the index», which no longer shows a random one
   (N1).
4. **F3 on several folders**: ask before the selection is dropped, or a filter that keeps
   it?
5. **A plain list's folders list**: regenerate it by itself when the index changed, or
   keep it as generated until «Regenerate this folders list»?
6. **F2 in a database**: take the key out, as the menu does, or make the rename update
   the folders list there?
7. **«Propagate the change to subfolders» unticked**: should the files of the subfolders
   keep their paths?
8. **Number filters on a row with no count**: list it, as now, or count first? **Settled
   by `f88e4be`: listed.**
9. **Folders that are not on the disk** when `updateCachedStaticFolders()` runs: keep
   them in the folders list? The counter correction makes the test at :96941 effective.
   **Not answered, and in effect since `2c501dc`**: the counter correction is in, so such
   folders are dropped at every rescan (N3). Whether that is wanted is still the question.
10. **Lower-case paths after a rescan**: acceptable, or should the index keep the spelling
    it had?

Suggested order, at `2c501dc`: N1 and N2 first, in `BTNremFilesStaticFolder()` (one
refresh after the loop, and the empty-index box back); then decision 9 with N3, the
«Files» cell of N4, and the folder named by the refusal message of finding 28; then what
is left of 9 (the first opening, one selected file), 13 and the rest of 17; the others
wait for the decisions.

## How this was checked

- Static reading of `development` at ab160cb: the panel, its menu builder, the key and
  right-click routing, and each helper before a call to it was judged.
- The real application under headless Wine, started on one image, with a test function
  appended to a scratch copy of the script. The copy differs from the source in this:
  popup menus, clipboard writes, «Folder properties» and the new-instance launch write a
  log line instead; `msgBeepTimer()` and `addJournalEntry()` log their text;
  `RandomPicture()`, `coreGenerateRandomList()`, `IDshowImage()` and `remFilesFromList()`
  count their calls; the list's handler can log its events.
- The three kinds of list were made by the application itself: a folder opened with
  `coreOpenFolder()`, then `SaveFilesList()` or `SaveDBfilesList()` and `OpenSLD()`.
- Fifteen batches, 20 to 40 s each. Handlers were called from a `Critical` thread, as the
  application's own threads are; «Ignore all changes» was pressed with a real button
  click, F3 and the right-click were posted as messages to the list view. Batches A, C2
  and D gave the same log on stock AutoHotkey 1.1.37.02, but for the number of a random
  image and a menu tick left by a setting an earlier batch had saved.
- Aids, each named where it was used: a folder's date set with `FileSetTime`; a folder
  removed or moved away to make it unreachable; a stop simulated by making the next call
  of `determineTerminateOperation()` answer 1, which is what it answers once the user
  confirms the prompt; message boxes answered from a timer.
- The fixes of `f88e4be` were checked on `54a0666`: the fifteen batches again, and a new
  one, P. Batches B, C2, D2, F, G, H, L and M log what they logged at ab160cb. A, C, D, E
  and I differ where the notes say. J and N did what they did before: J logs two more
  lines, and N differs by a menu tick that a setting saved by an earlier batch decides.
  The «Ignore all changes» button was pressed with real clicks. Four changes to the kit
  went with it: the wrappers call the menu item's function under its new name; batch C
  answers «Discard» to the save question it now gets; batch E also sorts «Size (MB)»;
  batch J also logs the `staticfolders` table, and was run once more on ab160cb for that
  table.
- `256a670` was checked the same way, on its text before it was committed: the sixteen
  batches, with one more step in batch P (the button pressed with a filter on and no
  focused row). The logs differ from those of `54a0666` in what the button does, in
  batches C and P, and in the number of a random image, in batches C and D; nowhere else.
- `1813ca9` was checked the same way, on its text before it was committed: the sixteen
  batches, with two more steps in batch P (the button with a filter that lists the marked
  folder, and with one that lists nothing). The logs differ from those of `256a670` in
  what the button does with a filter on, in batch P, and in the number of a random image;
  nowhere else.
- `2c501dc` was checked on the commit itself: the sixteen batches again, and a new one,
  Q. Batches D2, E, F, L and N log what they logged on `1813ca9`. A, B, C, C2, D, G, H,
  I, J, M and P differ where the notes say, and in the number of a random image. One step
  of batch P no longer tests what it did: by then the rescan and the save of an earlier
  step have cleared the mark of `Gamma` for good, so the button pressed with the filter
  `gamma` finds no mark to clear. The commit does not touch the button's function.
- Batch Q was run on `2c501dc` and on `1813ca9`, so that each of its results could be
  told as new or as already there. It opens its lists through `coreOpenFolder()`, which
  keeps the folders list of the list opened before; the batch empties that list first, as
  the application's own «open» functions do. The folder that «cannot be reached» is a
  folder moved away and, where the step says so, moved back.
- Not run on Windows. One finding rests on how Windows behaves: that a freshly filled
  list view has no focused row (11). The layout figures of finding 30 come from widths the
  script sets itself.
- Not checked: lists of thousands of folders and the timings that come with them; network
  paths; the panel with an edited, unsaved image in the viewport; a duplicates list; large
  fonts and the dark mode.
- Kit: `.claude/scratch/static-folders-panel-2026-11-10/app/`: `setup.sh` once, then
  `run-app.sh <tag> <test function> [revision]`; `patch.py`; `test-wrappers-static.ahk`
  (testStaticA to testStaticQ, named as in the table below); `results/` (the logs ending
  in `-stock` are the stock interpreter's, those ending in `-trial` the trial copy's, run
  with `QPV_SRC=<file>`; those ending in `-f88` are the ones of `54a0666`, those ending in
  `-fix4` the ones of `256a670`, those ending in `-flt` the ones of `1813ca9`, those
  ending in `-2c5` the ones of `2c501dc`, and `j-ab1` is batch J on ab160cb with the table
  logged).

| Batch | What it runs |
|-------|--------------|
| A | plain folder: first opening, Ctrl+A, the filter box across a reopening, the number filters, a stopped count |
| B | plain folder: the panel after the selection and the index changed |
| C | cached .SLD: marks, «Ignore all changes», a filter with every row highlighted, «Rescan folder(s)», private mode, a missing folder |
| C2 | cached .SLD: folders added, the list saved and loaded again |
| D | database: the menu, F2, «Regenerate this folders list», «Rescan folder(s)», «Count selected files», «Erase files» on two folders, the disk count |
| D2 | database: F2 carried through |
| E | plain folder: F3 on two folders and on one, the sort of «%» |
| F | the shared handlers in the seed folders panel |
| G | the panel with an empty folders list |
| H | cached .SLD: an offline folder saved and loaded, a rename without propagation, actions on a missing folder |
| I | a list that was never saved; F3 on a row that was not counted |
| J | plain folder: the everyday actions, the filter row's width; database: a folder that cannot be reached |
| L | files selected before the first opening, on the three kinds of list |
| M | cached .SLD: a seed-folder rescan, «Regenerate entire index», «Regenerate this folders list» |
| N | what one right-click on a row raises |
| P | cached .SLD, after the fixes: the number filters on rows with no count; «Ignore date change», then saved and loaded again; the function added for the button, called by hand, and the button itself; «Rescan folder(s)», then saved and loaded again; a Down key on a row not yet counted; «Ignore date change» on a missing folder; the button with no focused row and a filter that lists an unmarked folder, the marked folder, nothing |
| Q | after `2c501dc`. Plain folder: «Deselect all (files list)»; «Set as the protected folder» on a missing folder while another one is protected; «Erase files from the index» on one folder and on every folder. Cached .SLD: a folder that cannot be reached while another one is rescanned, and rescanned itself, each saved and loaded again; four lines written by hand into `[Folders]`; «Regenerate entire index» with a marked folder. Database: the «Files» cell after a rescan; a folder that cannot be reached while another one is rescanned |
