# «Files list filtering» panel audit, 2026-11-20

Scope: `PanelEnableFilesFilter()` (:33147) and the panel it builds: its two tabs, the query box and its
five buttons, the keys and the right-click menu it answers, the routes that open it, and everything its
buttons run. «Apply filter» runs `BtnApplyFilesFilter()` (:33459), which builds the filter in
`updateUIFiltersPanel()` (:33269) and applies it through `coreSetFilesFilteru()` (:33687) and
`FilterFilesListuIndex()` (:33757). It also reaches `retrieveAlreadySeenImageFromCurrentList()` (:36213)
for «Already seen» and `BtnIndexStatsToList()` (:28509) on database lists. The other buttons: «Remove
filters» (`BTNuiremFilesListFilter()` :33228, `remFilesListFilter()` :4211), «Erase history»
(`EraseFilterzHisto()` :33106), «Stats» (`PanelWrapperFilesStats()` :28403), «Search» (`PanelSearchIndex()`
:47827) and «Cancel». The audit also covers the helpers they hand the work to, as far as a panel action
reaches them:

- the history: `readRecentFiltersEntries()` :33091, `RecordUsedFiltersManager()` :33505;
- the saved settings: `InitialFilterSettingsPanel()` :33113;
- the data collection: `collectFileInfosNow()` :29461, `collectImageInfosNow()` :29363;
- the save question: `askAboutFileSave()` :65778.

Line numbers are `quick-picto-viewer.ahk` on `development` at `0b6cb07`. The audit changed no code.

Fifteen findings and a list of small things. Each one says how it was checked: **run** means the real
application did it under headless Wine, on the stock AutoHotkey 1.1.37.02; **read** means it follows
from the code and was not run. Nothing was run on Windows. The test kit is described at the end. Each
run carries a tag such as C2 or B4b: the letter names its batch (listed under «How this was checked»),
and the tag marks its lines in the kit's logs.

The RegEx side of this panel was reviewed on 2026-11-13: answered in chat and fixed then (`b8a1c8a`,
`bf97624`), with no report. Two notes from that review come back here. The one-character pattern is
finding 6. The cut at `::` is small thing 16.8. Finding 10 is where this panel meets the unchecked result
of `createSettingsGUI()`, which most panels share (56 of 74 at `b4f374f`, counted for the 11-14 report).

**Status, 2026-11-23.** Findings 1 to 6 were run again at `60af1a0`, after Marius's own fixes of
2026-11-21. What still held was fixed on 2026-11-23, with his answers to decisions 2, 3 and 6.

- Finding 1 and route a of finding 2 are fixed in `68d5511`, by Marius.
- Routes b and c of finding 2 are fixed in `886cdfb`.
- Finding 3 is fixed in `ed7a1a1`.
- Finding 4 is fixed for «Cancel» in `35329bc`, by Marius. «Save» and the «Already seen» criterion
  stay as they are, at his choice (decision 4).
- Findings 5 and 6 are fixed in `35329bc`, by Marius, and completed in `bdc80f1`.

Findings 8 to 14 were run again at `8cdff2b`, later the same day. What still held was fixed, with
his answers to decisions 8, 9, 11 and 14.

- Finding 8 is fixed in `07fddfd`: an empty «Minimum» or «Maximum» is refused with a message.
- Finding 9 is fixed in `91c3834` for «Remove filters». «Apply filter» on database lists keeps its
  random image, at his choice (decision 9).
- Finding 10 raises no error since `79d0e05`, by Marius, and «Erase history» no longer closes the
  panel (`d2ae7c5`). «Stats» still ignores a press within that second.
- Finding 11 is fixed in `d2ae7c5` («Erase history») and in `08b5a01` (the two rebuilds).
- Finding 12 is fixed in `26363c7`.
- Finding 13 is fixed in `35329bc`, by Marius.
- Finding 14 is fixed in `25429a9`.

Findings 15 and 16 were not run again, and their status is the one at `0b6cb07`. Finding 7, small
thing 16.5 and «Seen in passing» B changed all the same, as the runs of findings 1 to 6 showed.
Small thing 16.11 and «Seen in passing» E are new, from the runs of findings 12 and 14.

Each of sections 1 to 14 ends with what was run again and, where fixed, a note on what the code does
now. Those additions cite lines at `bdc80f1` in sections 1 to 7 and at `25429a9` in sections 8 to 14;
the other line numbers stay those of `0b6cb07`. Two
functions were renamed on 2026-11-21 (`97aec41`, `ca44856`): `MenuRemFilesListFilter()` is now
`MenuRemNowFilesListFilter()`, and `BTNuiremFilesListFilter()` is `BTNuiDiscardFilesFilter()`.

## Terms

- **The panel**: panel 6, «Files list filtering». Its routes: Ctrl+F (:1876-1877), the Find menu's
  «Define index filter(s)» (:68921), the files list menu's «Index filters» (:72687), the toolbar's
  filter button (:106302-106303), «Files list filter» in the Statistics panel (:28439) and «Filter list»
  in the Search panel (:47952-47956).
- **Tab «Text»**:
  - the **string box**, «Filter files list with given string», with its text field and its history list;
  - «String filter matching mode»: «Anywhere», «Begins with», «Ends with», «RegEx» (no «RegEx» on
    database lists);
  - «Apply filter based on»: «Full paths», «Folder paths», «File names», «Parent folders»;
  - «Must not contain the given string»;
  - «Erase history».
- **Tab «File and image»**: the **criterion** list (file size, two dates, image properties, eight
  histogram values, «Selected files», «Already seen»), «Minimum», «Maximum», the size unit, two date
  pickers and «Invert filter».
- **Below the tabs**: the **query box** «Resulted files list filter query» (read-only,
  `InternalFilterString`), then «Apply filter», «Remove filters» (only while a filter is active),
  «Stats», «Search», «Cancel».
- **Index**: QPV's files list, `resultedFilesList`; `maxFilesIndex` is its count. **Plain list**: a
  folder or a text list. **Database list**: a list saved as .SLDB and opened from it; it filters with
  SQLite `LIKE` instead of AutoHotkey regular expressions.
- **Active filter**: the text in `filesFilter`. While a filter is active, the whole list waits in
  `bckpResultedFilesList`.
- **The settings**: the super-globals the panel reads and writes (`userFilterDoString`, `UsrEditFilter`,
  `userFilterStringPos`, `userFilterWhat`, `userFilterStringIsNot`, `userFilterProperty`,
  `FilteruMinRange`, `FilteruMaxRange`, `userFilterSizeProperty`, `userFilterInvertThis`, :296-303).
  `InitialFilterSettingsPanel(1)` keeps a copy when the panel opens, and `CloseWindow()` puts that copy
  back (`InitialFilterSettingsPanel(0)`, :99902-99903).
- **Save question**: `askAboutFileSave()`'s box «The currently modified image is about to be
  discarded… Would you like to save the current image?» with «Save», «Discard», «Cancel». «Save» and
  «Cancel» both return 1 (:65795-65803).
- **Edited image**: an image with unsaved edits. In the runs it is simulated by setting its state (an
  edited bitmap, five undo levels, «modified»), as in the earlier kits.
- **Ctrl+Space**: «Remove files list filter», `MenuRemFilesListFilter()` (:4205); it shares
  `remFilesListFilter()` with «Remove filters».

## Summary

| # | Finding | Harm | Checked | Status |
|---|---------|------|---------|---------------------|
| 1 | «Remove filters» discards an edited, unsaved image: with no question on a plain list, and on a database list also after «Cancel» when another file ends up current | high | run | **fixed**, `68d5511`, by Marius |
| 2 | Three routes leave the list filtered while no filter is active, so files leave the index | medium | run | **fixed**: a in `68d5511`, by Marius; b and c in `886cdfb` |
| 3 | The panel, opened again, shows another filter than the active one, and «Apply filter» then replaces it | medium | run, and read for one case | **fixed**, `ed7a1a1` |
| 4 | «Save» or «Cancel» at the save question of «Apply filter» closes the panel and erases the typed filter | low | run | fixed for «Cancel», `35329bc`, by Marius; «Save» and «Already seen» left as they are (decision 4) |
| 5 | A bar at the start or the end of the text matches every file | medium | run | **fixed**, `35329bc`, by Marius, and `bdc80f1` |
| 6 | One character with «Begins with», «Ends with» or «RegEx» is matched anywhere | medium | run, and read for «RegEx» | **fixed**, `35329bc`, by Marius, and `bdc80f1` |
| 7 | A doubled bar joins the two words around it | low | run | **fixed**, `35329bc`, by Marius; five bars in a row still match every file |
| 8 | An empty «Minimum» or «Maximum» drops the criterion, silently when a string is ticked | low | run | **fixed**, `07fddfd` |
| 9 | «Remove filters» shows a random image; on a database list «Apply filter» does too | low | run | **fixed** for «Remove filters», `91c3834`; «Apply filter» on database lists left as it is (decision 9) |
| 10 | A button pressed within a second of a message box raises an AutoHotkey error | low, narrow | run | **fixed**: `79d0e05`, by Marius, and `d2ae7c5`; «Stats» ignores a press within that second |
| 11 | «Erase history» asks nothing, and the rebuilt panel loses the typed filter; the theme and font toggles too | low | run | **fixed**, `d2ae7c5` and `08b5a01` |
| 12 | The history list hides entries that end another entry's text, and lists the active text twice | low | run | **fixed**, `26363c7` |
| 13 | «Apply filter» and «Cancel» share Alt+A | low | run (Wine) | **fixed**, `35329bc`, by Marius |
| 14 | The scales of «Aspect ratio» and of the histogram criteria are not shown; a standard deviation of 0 cannot be reached | low | run | **fixed**, `25429a9` |
| 15 | «Selected files» with one selected file says none is selected, and drops that selection | low | run | open |
| 16 | Small things, numbered 16.1 to 16.11 | low | run and read | open; 16.5 fixed |

Rows 1 to 7 give the status at `bdc80f1`, and rows 8 to 14 at `25429a9`. Rows 15 and 16 give the status
at `0b6cb07`: they were not run again.

Finding 1 loses work for good. Finding 2 removes files from the index until the folder or the list is
opened again. Findings 3 and 5 to 8 filter by something the user did not ask for, and say nothing about
it. Findings 3 and 6 need nothing more than reopening the panel or typing one character. Findings 1,
2, 3, 5 and 6 are fixed, finding 4 for «Cancel», and finding 7 for a doubled bar. Findings 8 and 10
to 14 are fixed, and finding 9 for «Remove filters».

---

## 1. «Remove filters» discards an edited, unsaved image

`BTNuiremFilesListFilter()` :33228-33233, `remFilesListFilter()` :4211-4221, `renewCurrentFilesList()`
:65196; on a database list `BtnIndexStatsToList()` :28522 and `coreSetFilesFilteru()` :33739-33747

«Apply filter» asks the save question before the list changes (:33490). «Remove filters» does not.

- **Plain list.** `FilterFilesListuIndex()` rebuilds the list through `renewCurrentFilesList()`. That
  function sets `currentImgModified := 0` (:65196), so no later question can fire. Another image is then
  shown (finding 9).
- **Database list.** The list is read again from the database, and that step asks the question inside
  `BtnIndexStatsToList()` (:28522), with the wording «…and the files list will be filtered to given
  criteria». «Cancel» stops the reading. But `coreSetFilesFilteru()` still moves `currentFileIndex` to
  the index the current image had in the whole list before the first filter (:33746). The list stays
  filtered, so that index usually points at another file. The random jump of finding 9 then loads that
  file, and the edits go with it. In D1 it pointed at a02.png. What happens when it points at the edited
  file itself was not checked.

Runs, with the edited image simulated:

- **Plain list** (C2): filter `a01|a02|a03`, a01.png edited, «Remove filters». No question. Afterwards
  there is no edited bitmap and no undo level, the image counts as not modified, and another image is
  shown (a08.png in the kept log).
- **Ctrl+Space** (C2b) gives the same result: no question, the edits are gone.
- **Database list** (D1): filter `a01|a02`, a01.png edited, «Remove filters». The question comes and is
  answered «Cancel». Then a02.png, the other file listed, is loaded, and `terminateIMGediting()` runs
  while the five undo levels are there. Afterwards there is no edited bitmap and no undo level. The list
  stays filtered, with no filter (finding 2a).

Run again at `60af1a0`, with the edited image simulated (batches H1, HD):

- **Plain list, «Remove filters»** (H1): the question comes first, as «…and the files list filter will
  be removed».
  - «Cancel»: the panel stays open; the edits and the filter are kept.
  - «Save»: the panel closes and the save panel is started; the edits and the filter are kept.
  - «Discard»: the filter is removed, the edits are discarded, and another image is shown.
- **Ctrl+Space** (H1b): the same question; «Cancel» keeps everything, «Discard» removes the filter.
- **Database list** (HD, HDb): one question, with the same wording. After «Cancel», a01.png is still
  shown with its five undo levels and the filter is still active, from the button and from
  Ctrl+Space. After «Discard», all 6 files are listed.
- **No edited image** (H1c): no question.

**Fixed in `68d5511`**, by Marius. `BTNuiDiscardFilesFilter()` (:33209) and
`MenuRemNowFilesListFilter()` (:4206) ask before anything changes, and return on «Save» and on
«Cancel» (:33213, :4210). `BtnIndexStatsToList()` no longer asks when it reads the whole list back
(:28521), so no question can come after the filter was emptied. The toolbar's filter button, the
quick-action bar's «Remove filter» and the two menus go through `MenuRemNowFilesListFilter()`. The
case left unchecked above no longer arises: «Cancel» returns before `currentFileIndex` is touched.

---

## 2. Three routes leave the list filtered while no filter is active

An active filter has two parts: `filesFilter` (its text) and `bckpResultedFilesList` (the whole list
kept behind it). The three routes below empty `filesFilter` but do not put the whole list back, so QPV
believes no filter is active:

- the Find menu's «Remove files list filter» (:68924) and the panel's «Remove filters» are gone;
- the files list menu's «Index filters» is unticked (:72689);
- Ctrl+Space treats the shown list as the whole list (:33702-33706).

The files outside the shown list leave the index until the folder or the list is opened again. Saving
a plain list then saves only the part that is shown, without the warning a filtered list gets (read).

**a. Database list, «Cancel» at the save question of «Remove filters».**
`coreSetFilesFilteru("")` has already emptied `filesFilter` (:33715-33724). `BtnIndexStatsToList()`
returns -1 (:28522-28523), and `FilterFilesListuIndex()` ignores the result (:33758-33763). Then
`coreSetFilesFilteru()` drops the kept list (:33739-33747).

Run (D1, the case of finding 1): 2 of the 6 files are listed and `filesFilter` is empty. The panel then
refuses to open: «WARNING: Insufficient files are currently indexed» (:33160), because fewer than three
files are listed and no filter is active.

**b. «Already seen» when the seen images database holds fewer than two records.**
`retrieveAlreadySeenImageFromCurrentList()` empties `filesFilter` (:36251-36262) before it reaches the
line that removes the active filter (:36264-36265).

Run (P3): filter `a01|a02` active (2 of 5 files), no seen record, «Already seen», «Apply filter».
Message: «No records found matching the criteria». Afterwards 2 files are listed and `filesFilter` is
empty. After Ctrl+Space, still 2 files.

**c. The data collection aborted while a filter is active.**
A criterion of the «File and image» tab first collects the missing file details («Collecting file
details, please wait»). A click or a key press during that step asks «Do you want to stop the currently
executing operation?», and «Yes» aborts it (lib/module-interface.ahk:1520-1530, read). The abort branch
(:33802-33809) puts the whole list back into
`resultedFilesList`. It leaves `maxFilesIndex` at the filtered count and empties the filter. The index
then shows the first entries of the whole list, as many as the filter had matched.

Runs, the abort simulated (the kit's `determineTerminateOperation()` answers «abort»):

- **B4**: filter `s-` active (s-mid.png, s-small.png), then «File size» 2-10 KB added and the collection
  aborted. Message: «Operation abandoned. The files list was not filtered, because data collection did
  not complete.» Listed afterwards: big.png and s-mid.png. big.png never matched; s-small.png, which
  did, is hidden. There are 3 entries behind a count of 2. Ctrl+Space put all 3 back, but only because
  its loop reads one entry past the count (:33874).
- **B4b**, six files, the same filter (2 files): after the abort, 6 entries behind a count of 2. After
  Ctrl+Space, 3 entries. t-d.png, t-e.png and t-f.png have left the index.

Run again at `60af1a0`:

- **a** (HD): gone. After «Cancel» the 2 files are listed and the filter is still active.
- **b** (P3): as before, 2 files listed and `filesFilter` empty. Ctrl+Space now does nothing there,
  because `MenuRemNowFilesListFilter()` returns when no filter is active (:4207).
- **c** (B4, B4b): as before, and for the same reason Ctrl+Space brings nothing back: 3 entries stay
  behind a count of 2 in B4, and 6 behind 2 in B4b.

**Route a fixed in `68d5511`**, by Marius: the question is asked before `coreSetFilesFilteru("")` runs
(finding 1), so «Cancel» changes nothing.

**Routes b and c fixed in `886cdfb`**, with Marius's answer to decision 2: the active filter, its list and
the panel's settings stay as they were before «Apply filter».

- **b.** The panel calls `retrieveAlreadySeenImageFromCurrentList(1)`. With that 1 the function no
  longer empties `filesFilter`: it says «No records found matching the criteria. The files list was
  left unchanged.» and returns -1 (:36267-36285). Without it the filter is emptied as before. That is
  the call of a database list's sorting, which reads the list again without its filter and then
  applies the filter anew (`dbSortingCached()`, through `coreSetFilesFilteru()`).
- **c.** When the collection is aborted, nothing has replaced the list yet. `FilterFilesListuIndex()`
  puts the previous filter's text back into `filesFilter`, says «Operation abandoned. The files list
  was left unchanged, because data collection did not complete.» and returns -1 (:33816-33824).
  `coreSetFilesFilteru()` hands that result to its caller (:33739, :33768).
- **The settings.** «Apply filter» stores the typed settings before the panel closes. On -1 it puts
  back the ones the panel opened with, `InitialFilterSettingsPanel(2)` (:33496-33497, :33512-33513).
  For that, `InitialFilterSettingsPanel()` (:33095-33116) keeps the copy that its last «remember»
  replaced.

Run on the fix (batches V1, V2, V3; B4, B4b and P3 again):

- **b**: filter `a01|a02` active, no seen record, «Already seen», «Apply filter». The 2 files stay
  listed and the filter stays active. The settings are the filter's own, and the reopened panel
  shows it. Ctrl+Space then lists all 5 files. Control, no filter active: the same message, 5 files,
  no filter.
- **c**: filter `s-` active (2 of 3 files), «File size» 2-10 KB added, the collection aborted. The 2
  files stay listed behind a count of 2, and the whole list of 3 waits behind them. The reopened
  panel shows `s-` with no criterion, and «Remove filters». Ctrl+Space then lists all 3 files (all 6
  in B4b). Control, no filter active: the abort leaves 3 files and no filter.
- **A database list sorted** (V3): «Already seen» active with 3 of 5 files, the seen records erased,
  then a sort by file name. As before the fix: «No records found matching the criteria», all 5 files,
  no filter.

---

## 3. The panel, opened again, shows another filter than the active one

`PanelEnableFilesFilter()` :33183-33184, :33208-33209, :33212, :33225; `updateUIFiltersPanel()` :33269

When the panel opens, the query box shows the active filter (`filesFilter`, :33212). 300 ms later
`updateUIFiltersPanel()` (:33225) rebuilds the query from the panel's fields. Those fields come from the
settings, which do not always describe the active filter. So the query box changes under the user's
eyes, and «Apply filter» (or Enter) puts the shown filter in place of the active one.

- **Dates** (B3). The two date pickers get no starting date (:33208-33209: no `Choose`), so they always
  open on today.
  - Applied: «Modified date» from 2019/01/01 to 2019/12/31, which lists s-small.png.
  - Reopened, the pickers show 2026/11/20. The query box reads `…fmodified::20190101000000::20191231235959`
    at opening and `…fmodified::20261120000000::20261120235959` 500 ms later.
  - «Apply filter», with nothing changed: big.png and s-mid.png (modified today). The 2019 filter is
    gone.
- **A search in between** (P1). The Search panel's text box uses the same variable, `UsrEditFilter`
  (:47865, :47896).
  - Filter `a0` active (4 files). «Search», then a search for `a03`.
  - Reopened, the text field shows `a03`. The query box reads `i)(a0)` at opening and `\>i)(a03)`
    500 ms later.
  - «Apply filter»: a03.png only.
- **After «Cancel» at the save question** (C3b, finding 4). Filter `a01|a02|a03` active.
  - Reopened, the string box is unticked and empty. The query box reads `i)(a01|a02|a03)` at opening
    and is empty 500 ms later.
  - «Apply filter»: «WARNING: No filter has been defined».
  - The active filter can no longer be seen or changed in the panel; only «Remove filters» acts on it.
- **Filters made elsewhere** (read). The Statistics panels set filters this panel has no field for:
  - the pixel format row sets only `userFilterDoString := 0` (:28584-28588);
  - the deleted entries row sets «Modified date» with the dates 2 and 1 (:28653-28659).

  The panel then shows whatever criterion it last had.

Run again at `60af1a0` (B3, P1, H4): the three run cases still hold.

- **Dates** (B3): 2019 applied, 2026/11/23 shown, and «Apply filter» lists the two files modified
  today.
- **A search in between** (P1): the field shows `a03`, and «Apply filter» lists a03.png.
- **After the save question** (H4): the case now comes from «Save», since «Cancel» keeps the panel
  open (finding 4). Filter `a01|a02|a03` active, «Apply filter», «Save»: reopened, the string box is
  ticked and the field is empty; the query box empties, and «Apply filter» says «No filter has been
  defined».
- **One more route** (H4): «Already seen», then «Cancel» at its save question, leaves the settings on
  «Already seen» while the string filter is active (finding 4).

**Fixed in `ed7a1a1`**, with Marius's answer to decision 3: the dates are kept with the settings, the
Search panel has a text of its own, and a filter the fields cannot rebuild stays in the query box
until a field is changed.

- **Dates.** `InitialFilterSettingsPanel()` remembers and puts back the two dates with the other
  settings (:33095-33116), and the pickers open on them when they hold a valid date (:33181-33190).
- **Search.** The Search panel's text box is `UsrEditSearch`, a global declared in the three functions
  that use it: `EraseSearchEdit()` (:47893), `PanelSearchIndex()` (:47909) and
  `BtnPerformSearchNow()` (:47971). `UsrEditFilter` holds the filter's text only.
- **The query box.** The panel builds its query when it opens, with `updateUIFiltersPanel("opened")`
  (:33206), not 300 ms later, so the box no longer changes after the panel is shown. That call
  compares the query the fields give with the active filter. When they differ, the box keeps the
  active filter until a field is changed (:33433-33451), and «Apply filter» then says «No filter
  option was changed. The active files list filter was left in place.» (:33474). The first changed
  field ends that for as long as the panel is open: the box shows the fields' query, and «Apply
  filter» applies it, also when the field is changed back.
- **Filters made elsewhere** still have no fields: the pixel format and the deleted entries rows of
  the Statistics panels, a duplicates list, a file's pages. The query box now shows them, and they
  are not replaced unasked. The same holds for the settings that «Save» and «Already seen» leave
  (above) and, read from the code, for a histogram row of the Statistics panels, which this panel
  would otherwise apply one level down (finding 14).

Run on the fix (batches V1, V2, V3; B3, P1 and H4 again):

- **Dates**: «Modified date» 2019 applied. Reopened, the pickers show 2019/01/01 and 2019/12/31, and
  the query box keeps the 2019 query. «Apply filter» lists s-small.png again. The dates changed to
  2020, then «Cancel»: reopened, 2019 again.
- **Search**: filter `a0` active, a search for `a03`. Reopened, the field shows `a0`, and «Apply
  filter» lists the 4 files of `a0`.
- **A filter the fields do not describe**, `i)(a0)` set by a call while the string box is unticked:
  - the box reads `i)(a0)` at opening and 500 ms later;
  - «Apply filter»: the message; the panel stays open and the filter stays;
  - «Invert filter» ticked: the box empties, since the fields define no filter; unticked again: it
    stays empty;
  - the string `a01` ticked: the box reads `\>i)(a01)`, and «Apply filter» lists a01.png.
- **The same filter while the fields describe `a01`** (V3): the box reads `i)(a0)`, and «Apply
  filter» gives the message. «Invert filter» ticked and unticked: the box reads `\>i)(a01)`, and
  «Apply filter» lists a01.png.
- **Filters the fields do describe** are applied again as before (V3): «Selected files» on a plain
  list, and `a01|a02` on a database list.
- **After «Save»** (H4 again): the reopened panel keeps `i)(a01|a02|a03)` in the box, and «Apply
  filter» gives the message.

---

## 4. «Save» or «Cancel» at the save question closes the panel and erases the typed filter

`BtnApplyFilesFilter()` :33488-33496

```ahk
InitialFilterSettingsPanel(1)
BtnCloseWindow()
If askAboutFileSave(" and the files list will be renewed based on the provided filter criteria")
{
   userFilterDoString := 0
   userFilterProperty := 1
   UsrEditFilter := ""
   Return
}
```

The panel closes before the question. «Save» and «Cancel» both return 1, and the branch then clears the
string box, the criterion and the text.

- **No filter active** (C3, run): a01.png edited; «Begins with» `a01|a02` on file names; «Apply filter»,
  then «Cancel». The panel closed and the edits were kept. The settings afterwards: string box 0, text
  empty, criterion 1. Reopened: the string box unticked, the field empty; «Begins with» was kept.
- **A filter active** (C3b, run): «Must not contain» ticked, then the same steps. The same result, and
  the active filter stays, which the panel no longer shows (finding 3).
- **«Save»** opens the save panel 150 ms later (:65798) and leaves the filter unapplied in the same way
  (read).
- **A database list sorted later** (read): `dbSortingCached()` applies an «Already seen» filter again
  (:37546-37547), through `retrieveAlreadySeenImageFromCurrentList()`, which reads these settings. After
  this reset, the string part of that filter is dropped.

The structured panel asks before it closes since `ed8848c`.

Run again at `60af1a0` (batch H4), a01.png edited:

- **«Cancel», no filter active**: the panel stays open with what was typed, and the edits are kept.
  When the panel is then closed, the settings it opened with come back.
- **«Cancel», a filter active**: the same; the reopened panel shows the active filter.
- **«Save», no filter active**: `askAboutFileSave()` closes the panel and starts the save panel
  (:66053; the kit replaces the save panel by a log line). The typed filter is not kept.
- **«Save», a filter active**: the same, and the line that remains of the branch, `UsrEditFilter :=
  ""` (:33503), runs after the close has put the settings back. The active filter's text is erased
  from them: reopened, the string box is ticked and the field is empty (finding 3).
- **«Already seen»**: this criterion has a branch of its own (:33492-33499), which still closes the
  panel before `retrieveAlreadySeenImageFromCurrentList()` asks (:36257). After «Cancel» the panel is
  closed, the edits are kept, and the settings stay on «Already seen» while the string filter is
  active.

**Fixed for «Cancel» in `35329bc`**, by Marius: the question is asked before
`InitialFilterSettingsPanel(1)` and `BtnCloseWindow()` (:33501-33508), and the branch no longer
resets the string box and the criterion. «Save» and «Already seen» stay as described, at Marius's
choice (decision 4). Since `ed7a1a1` the query box keeps the active filter in both cases (finding 3).

---

## 5. A bar at the start or the end of the text matches every file

`updateUIFiltersPanel()` :33352-33361, :33428-33430

In «Anywhere», «Begins with» and «Ends with» the typed text is escaped and put in parentheses, as in
`i)(x1|)`. The bar stays, and the empty choice after it matches every name. The `Trimmer(newFilter, "|")`
at :33430 trims bars at the two ends of the whole query. That query ends in `)`, so the trim removes
nothing here.

Runs on x1.png, 1x.png, y.png, z.png, «File names»:

- `x1|` (A4), `|x1` (A4b), and `x1|` with «Begins with» (A4d): all 4 files.
- `x1|` with «Must not contain» (A4c): no file. The box «No files matched your filtering criteria…
  QPV will now restore the complete list of files.» comes up.
- Control: `x1|y` (A3b) gives x1.png and y.png.

Database lists skip empty terms (`SQLlikeClauseFromFilter()` :40246) (read).

Run again at `60af1a0` (A4, A4b, A4c, A4d): fixed. `x1|` and `|x1` list x1.png; with «Must not
contain», the other three files; with «Begins with», x1.png. On a database list `x1|` lists x1.png
and x12.png (HD5). Three cases beside them still held (batches H5, H6):

- **«Already seen»** with `a0|`, and a01, a02 and b05 seen: all three were listed. That route builds
  a pattern of its own (:36239-36252) from the text as typed, which `Gui, Submit` had read again
  after the clean-up.
- **The history** and the settings kept `a01|`, as typed.
- **«RegEx» `a01\|`**: the query box said «Invalid regular expression provided.», but «Apply filter»
  checked the text as typed and applied `i)a01\`, which matched nothing.

**Fixed in `35329bc`**, by Marius: `updateUIFiltersPanel()` reads `||` as one bar and trims the bars
at the two ends of the text, in every matching mode (:33294-33295). **Completed in `bdc80f1`**:
`BtnApplyFilesFilter()` reads the fields first and builds the filter after (:33472-33473), so the
cleaned text is the one that is checked, recorded in the history and read by «Already seen».

Run on the fix (V2):

- `a01|` lists a01.png, and the history holds `a01`.
- «Already seen» with `a0|` lists a01.png and a02.png.
- «RegEx» `a01\|` is refused: «The regular expression you provided is invalid».

The clean-up applies in «RegEx» mode too, so a pattern cannot end in a bar or hold an empty choice:
`a01||b05` lists a01.png and b05.png, and `a01\||b05` becomes `a01\|b05` (H6). No file name holds a
bar, so only such patterns change.

---

## 6. One character with «Begins with», «Ends with» or «RegEx» is matched anywhere

`updateUIFiltersPanel()` :33352-33361; the same lines in `retrieveAlreadySeenImageFromCurrentList()`
:36226-36235

The three modes need at least two characters (`StrLen(UsrEditFilter)>1`). A single character falls
through to the last branch, which is «Anywhere».

- **«Begins with» `1` on file names** (A1): 1x.png and x1.png, query `i)(1)`. Control: `1x` (A1b) gives
  1x.png alone.
- **«Ends with» `1` on folder paths** (A2, folders `a1` and `1a`): all 4 files, query `i)(1)`. The
  kit's own path holds a 1 as well. Control: `a1` (A2b) gives the two files of a1.
- **«RegEx»** (read): a one-character pattern is taken literally, so `.` matches only a dot.

Database lists build the condition for any length (read).

Run again at `60af1a0` (A1, A2): fixed for the two modes. «Begins with» `1` lists 1x.png, and «Ends
with» `1` on folder paths lists the two files of a1. Two cases still held (batch H5):

- **«RegEx» `.`** on parent folders: taken as a dot, so no file matched (H6.4).
- **No text**, new with the fix: «Begins with» or «Ends with» with an empty field, or with a bar
  alone, built `i)^()` or `i)()$`. That filter lists every file and counts as active (H6.1, H6.2);
  with «Must not contain», no file matched (H6.3). On a database list the same fields give «No filter
  has been defined» (HD6).

**Fixed in `35329bc`**, by Marius, for «Begins with» and «Ends with»: the two modes no longer ask for
two characters. **Completed in `bdc80f1`**, with his answer to decision 6: «RegEx» takes one character as
a pattern, and no mode builds a pattern from an empty text, in `updateUIFiltersPanel()`
(:33342-33356) and in `retrieveAlreadySeenImageFromCurrentList()` (:36239-36252). The two checks of
the pattern follow (:33432, :33478).

Run on the fix (V2):

- «RegEx» `.` on parent folders lists all 5 files; `b` lists b05.png; `(` is refused as invalid.
- «Begins with» and no text, and «Ends with» and a bar alone: «No filter has been defined».
- «Already seen» with «RegEx» `.` lists the three seen files.
- «Begins with» `b` lists b05.png.

---

## 7. A doubled bar joins the two words around it

`updateUIFiltersPanel()` :33301 and :33429

Outside «RegEx», line :33301 deletes every `||` before the query is built, so `x1||y` becomes `x1y`.
The later line :33429, `StrReplace(newFilter, "||", "|")`, would read the pair as one bar, but by then
none is left.

Run (A3): `x1||y` gives the query `i)(x1y)`, no file matches, the box comes up and the whole list
returns. Database lists pass through the same line (read).

Run again at `60af1a0` (A3): `x1||y` gives `i)(x1|y)`, and x1.png and y.png are listed. `35329bc`, by
Marius, reads the pair as one bar (:33294). Five bars in a row still leave a pair: `a01|||||b05`
gives `i)(a01||b05)`, and all 5 files are listed (H5.2). That case was not fixed.

---

## 8. An empty «Minimum» or «Maximum» drops the criterion

`updateUIFiltersPanel()` :33365-33372

`min()` and `max()` return blank when one of their values is blank. The criterion is built only when
`minRange!=""`. Runs, «File size» in kilobytes:

- **Minimum 2, Maximum empty** (B2): «WARNING: No filter has been defined». The panel stays open and the
  query box is empty.
- **Minimum empty, Maximum 10** (B2b): the same.
- **The string `s-` ticked, Minimum 2, Maximum empty** (B2c): only the string is applied, with no
  message, so s-mid.png and s-small.png are listed although s-small.png is 361 bytes. The query box shows
  the string alone.

Run again at `8cdff2b` (B2, B2b, B2c): the three cases still hold, line for line.

**Fixed in `07fddfd`**, with Marius's answer to decision 8: an empty side is refused.
`BtnApplyFilesFilter()` looks at the two fields before it looks at the filter (:33511-33515). When
the criterion uses them («File size», and «Megapixels» to «Standard deviation») and one is empty,
«Apply filter» says «No maximum defined for the filter criteria. Please fill in both range fields
before applying the filter.», or «minimum», or «minimum and maximum». It applies nothing, and the
panel stays open. The query box still shows what the other fields give.

Run on the fix (the new batch W8; B again):

- **Minimum 2, Maximum empty**: the message names the maximum. **Minimum empty, Maximum 10**: the
  minimum. **Both empty**: both.
- **The string `s-` ticked, Minimum 2, Maximum empty**: the message. No filter is applied, and the
  list keeps its 3 files.
- **«Megapixels» 1 to empty**, and **«Standard deviation» empty to 10**: refused the same way.
- **The filter `s-` active, then «File size» 2 to empty**: the message, and `s-` stays active. With
  10 as the maximum, «Apply filter» lists s-mid.png.
- **Controls**: «File size» 2-10 lists s-mid.png. «Modified date» 2019, a string with no criterion
  and «Selected files» do not use the two fields, and are not held back when these are empty.

---

## 9. «Remove filters» shows a random image

`BTNuiremFilesListFilter()` :33232 (`SetTimer, RandomPicture, -90`); `BtnIndexStatsToList()` :28736

Ctrl+Space (`MenuRemFilesListFilter()` :4205-4209) goes back to the image that was current before the
first filter. Its own random jump was commented out in v4.7.7 (`5d309cd`, 2020-12-31), two days after
the filters arrived in v4.7.6 (`6a95534`). The button kept its jump.

- **Plain list** (C1, run): files a01 to a10, a10 current, filter `a0`, then a04 made current.
  - «Remove filters», run three times: a05, a02, a01 (an earlier run of the batch, whose log was not
    kept, landed on a06, a07, a03).
  - Ctrl+Space: a10.
- **Database list** (run): «Apply filter» calls `RandomPicture()` from `BtnIndexStatsToList()` (D2-db,
  D1). On a plain list the first match is shown. In D2-db the result held one file. A random file among
  several is read from the code.

Run again at `8cdff2b` (the new batch W9): files a01 to a10, a10 current, filter `a0`, then a04 made
current.

- **Plain list**: «Remove filters», three times: a07, a10, a05. Ctrl+Space: a10.
- **Database list**: «Remove filters», three times: a10, a03, a06. Ctrl+Space: a10.
- **«Apply filter» on the database list**, 9 matches, three times: a02, a06, a01. This is the first
  run with several matches. On the plain list it shows a01, the first match, each time.

**Fixed in `91c3834`** for «Remove filters», with Marius's answer to decision 9: the button shows the
image that was current before the first filter, as Ctrl+Space does
(`dummyTimerDelayiedImageDisplay(50)` :33244, in place of the timer for `RandomPicture()`). «Apply
filter» on database lists keeps its random image, at his choice. That call is in
`BtnIndexStatsToList()` (:28739), which the rows of the Statistics panels run as well.

Run on the fix (W9): «Remove filters» goes back to a10 in the six runs, three on each kind of list,
and `RandomPicture()` is not called on that route. «Apply filter» on the database list landed on a05,
a02, a04.

---

## 10. A button pressed within a second of a message box raises an AutoHotkey error

`EraseFilterzHisto()` :33106-33111; `PanelWrapperFilesStats()` :28410, :28426; `CloseWindow()`
:99809-99813; `createSettingsGUI()` :28105-28112

For one second after a message box closes (`lastLongOperationAbort`), `CloseWindow()` refuses to close
a panel unless it is called with «yes».

- «Erase history» calls `CloseWindow()` without «yes», then rebuilds the panel.
- The rebuild's `createSettingsGUI()` meets the same refusal and returns empty. The panel function then
  adds its controls to the panel that is still open.
- «Stats» goes through `createSettingsGUI()` as well.

The one box this panel shows while it stays open is «You currently have no selected image in the files
list…» («Selected files» with nothing selected, :33477).

Runs (E): that box, OK, and then at once:

- **«Erase history»**: AutoHotkey's error box «Error: The same variable cannot be used for more than
  one control. Specifically: vuserFilterDoString». The panel stays open with 34 controls instead of 32,
  from the tab control the rebuild added before the error.
- **«Stats»**: «Error: Invalid option. Specifically: h» (the button height is empty, :28426). The panel
  stays open with 34 controls: the Statistics panel's first two texts, which come before that button,
  were added to the filter panel (read from the code).
- **Control** (E3): «Erase history» more than a second after the box rebuilds the panel normally.

«Search» closes this panel with `BtnCloseWindow()` (:47838-47839), which passes «yes», so it is not
affected (read). The Move/Copy panel's «Erase history» does the same (yesterday's report, «Checked and
found correct»).

Run again at `8cdff2b` (the new batch W10; the history holds beach.png and a05): the two error boxes
are gone. `79d0e05`, by Marius, makes both panels return when `createSettingsGUI()` gives nothing
(:33154, :28412). What was left:

- **«Erase history»** within the second: the saved history was erased, and the panel stayed open
  with its 32 controls and with beach.png and a05 still in the list.
- **«Stats»** within the second: nothing happens, and nothing is said.
- **Controls**: more than a second after the box, «Erase history» rebuilt the panel, and «Stats»
  opened the Statistics panel.

**Fixed in `d2ae7c5`** for «Erase history», at Marius's request (2026-11-23: «make it update the user
interface without open/closing the window»): the button no longer closes the panel, so the refusal
does not reach it (finding 11). «Stats» still ignores a press within a second of a message box. That
is the refusal itself, which every panel shares, and it was left as it is.

Run on the fix (W10): «Erase history» pressed within the second asks its question and, after «Yes»,
empties the list in the panel; the fields stay. «Stats» is as before.

---

## 11. «Erase history» asks nothing, and the rebuilt panel loses the typed filter

`EraseFilterzHisto()` :33106-33111; `PanelEnableFilesFilter()` :33175-33179

`CloseWindow()` puts back the settings the panel opened with. `PanelEnableFilesFilter()` then unticks
the string box when no filter is active (:33175-33179).

- **«Erase history»** (C4, run): history beach.png, png, a05, ach.png; typed `typed` with «Ends with»,
  the string box ticked. No question. The history section is gone. The panel came back with the string
  box unticked, the text empty, and «Anywhere».
- **The right-click menu's «Dark mode UI» and «Large UI fonts»** rebuild the panel the same way
  (`openPreviousPanel("forced")` :74175, :74120). P4, run for «Dark mode UI»: typed `typed` with «Ends
  with», and «File size» 5-50. Afterwards every field was back to its default. «Large UI fonts» takes
  the same path (read).

Run again at `8cdff2b` (the new batch W11; P4):

- **«Erase history»**: as described. With the filter `a01|a02` active and `typed` in the field, the
  rebuilt panel showed `a01|a02` again.
- **«Dark mode UI»** and **«Large UI fonts»**: every field went back to what the panel opened with.
  This is the first run of «Large UI fonts».

**Fixed in `d2ae7c5` and `08b5a01`**, with Marius's answer to decision 11.

- **«Erase history»** (`EraseFilterzHisto()` :33088-33103) asks first: «Do you want to erase the
  history of the files list filters?», with «Yes» and «No». When no filter is saved it says «The
  files list filters history is already empty» and asks nothing. After «Yes» it deletes the saved
  filters and empties the list of the string box. The panel is not closed: the typed text and the
  other fields stay, and «Cancel» still puts back the settings the panel opened with.
- **The two rebuilds** keep the fields. `CloseWindow()` puts back the settings the panel opened
  with, as before, and `InitialFilterSettingsPanel(0)` now keeps a copy of the fields as they were
  (:33131). Each of the two toggles calls `PanelEnableFilesFilter("rebuild")` when this panel is the
  one that is open (:74440, :74500). A rebuild fills the fields from that copy (:33180, :33187) and
  leaves alone the settings that «Cancel» puts back. It does not start the query box anew
  (:33231): a filter the fields cannot rebuild stays in it until a field is changed, as before the
  rebuild (finding 3).

Run on the fix (W11; P and V3 again):

- **«No»**: nothing changes. **«Yes»**: the list is empty and the saved section is gone; the panel
  keeps its 32 controls and every field (`typed`, «Ends with», «File size» 5-50, «Invert filter»).
  **Pressed again**: «already empty». A filter applied afterwards is the first entry of a new
  history.
- **A filter active** (`a01|a02`), with `typed` and «Begins with» in the fields: after «Yes» the
  fields stay, the list is empty, the filter stays active and «Remove filters» is still there. After
  «Cancel», the reopened panel shows `a01|a02`.
- **«Dark mode UI»** and **«Large UI fonts»**, each pressed twice: the fields read the same after
  each rebuild (the string box ticked, `typed`, «Ends with», «Folder paths», «Must not contain»,
  «File size» 5-50 in megabytes, «Invert filter»). After «Cancel», the reopened panel shows what it
  showed before the typing.
- **A rebuild, then «Apply filter»**: `a01|a02` typed, «Dark mode UI», «Apply filter»: a01.png and
  a02.png are listed.
- **Typed over an active filter**: `a03` and a «Modified date» typed, then «Dark mode UI»: the
  fields stay, and the list still starts with the active filter's text. «Cancel» leaves the filter
  and its settings as they were.
- **A filter the fields cannot rebuild** (`i)(a0[12])`, set by a call): the query box keeps it across
  «Large UI fonts», and «Apply filter» says «No filter option was changed». With `a03` typed and the
  toggle pressed again, the box reads `\>i)(a03)`, and «Apply filter» lists a03.png.

A rebuilt panel opens on its first tab, as before (read).

---

## 12. The history list hides entries that end another entry's text

`readRecentFiltersEntries()` :33096; `PanelEnableFilesFilter()` :33183-33184

`InStr(entriesList, newEntry "`n")` tests for a substring, case-insensitively. An entry is therefore
skipped when an earlier entry ends with its text.

- **Run** (C4): the history beach.png, png, a05, ach.png gives the list beach.png, a05.
- **Read**: the next filter recorded rewrites the section from the shortened list
  (`RecordUsedFiltersManager()` :33505), so the hidden entries are overwritten or stay hidden.
- **Run** (C5): filter a05 active, history a05 and beach.png. The list reads a05, a05, beach.png: the
  active filter's text is put first (:33183-33184) even when the history already holds it.

Run again at `8cdff2b` (the new batch W12): the cases still hold.

- The history beach.png, png, a05, ach.png gives the list beach.png, a05.
- **The rewrite**, run for the first time: the filter `a01`, applied over that history, leaves the
  section a01, beach.png, a05, ach.png. «png» is overwritten, and ach.png stays hidden.
- Filter a05 active: a05, a05, beach.png.

**Fixed in `26363c7`**: `readRecentFiltersEntries()` compares whole entries (:33078), and the active
filter's text is taken out of the history part of the list before it is put first (:33176-33178).

Run on the fix (W12):

- The four entries are listed. After `a01` is applied, the section holds all five: a01, beach.png,
  png, a05, ach.png.
- Filter a05 active: a05, beach.png.
- Entries that differ only in letter case are listed once, as before (A05 and a05; Beach.PNG and
  beach.png). The filters do not tell them apart.

---

## 13. «Apply filter» and «Cancel» share Alt+A

`PanelEnableFilesFilter()` :33216, :33222

Run (K): Alt+A posted as key presses to the focused control, the string box ticked and empty, so that
«Apply filter» only warns:

| Focus on | Alt+A pressed |
|---|---|
| the string box, its text field, «Must not contain», «Erase history», «Apply filter» | «Apply filter» («No filter has been defined») |
| «Remove filters», «Stats», «Search», «Cancel» | «Cancel» (the panel closes) |

Wine's dialog manager looks from the focused control onward and presses the first button with the
letter. How Windows handles a letter that two buttons share was not checked. The other letters, M, H, I
(on the second tab), R, T and S, are unique (read).

Run again at `8cdff2b` (the new batch W13): fixed. `35329bc`, by Marius, renames «C&ancel» to
«&Cancel» (:33228). From each of the nine places of the table, Alt+A presses «Apply filter» and
Alt+C closes the panel. The panel's eight letters are unique: M, H, I, A, R, T, S, C. The keys are
posted under Wine, as before; Windows was not checked.

---

## 14. The criteria's scales are not shown

`updateUIFiltersPanel()` :33391-33399; `calcHistoAvgFile()` :102235-102242

The two fields take whole numbers (`number limit5`) and are labelled only «Minimum» and «Maximum».

- **«Aspect ratio»** divides them by 10 (:33393).
- **The eight histogram criteria** clamp them to 1-256 and divide by 256 (:33397). The histogram values
  are stored as (level + 1)/256, except the standard deviation, which is stored as deviation/256
  (:102239). A deviation of 0 needs a field value of 0, which the clamp turns into 1.

Runs, the stored values set by the test:

- **Aspect ratio** (B6), files with ratios 1.5, 1.33, 0.75:
  - criterion 1 to 2: no file («No files matched»);
  - criterion 10 to 20: the first two.
- **Standard deviation** (B5), files with deviations 0, 0.01 (2.56 on the 0-255 scale) and 0.2 (51.2),
  criterion 0-10: only the 0.01 file. The query reads `imghrms::0.00391::0.03906`.
- **Read**: a histogram row of the Statistics panels fills the fields with levels 0-255 (:28636), while
  this panel reads them as 1-256. Applied again from this panel, such a filter moves one level down.

Run again at `8cdff2b` (B5, B6, B6b; the new batch W14): the runs still hold. Two cases were run
for the first time, with the average levels 99.5, 120 and 150.5 set by the test:

- **«Average» 100 to 150** lists the files at 99.5 and 120: the fields are read as 1-256, one level
  below what is typed.
- **A row of the Statistics panel**: the row «100-150» of the averages, run through
  `BtnIndexStatsToList()`, lists the file at 120 and fills the fields with 100 and 150. This panel,
  opened on it, keeps that filter in the query box (finding 3). With one field changed and changed
  back, «Apply filter» lists the files at 99.5 and 120.

**Fixed in `25429a9`**, with Marius's answer to decision 14: the histogram criteria read the two fields
as levels, and the scale is shown.

- **Levels.** The two fields are clamped to 0-255. The seven criteria stored as (level + 1)/256 add
  the 1, and the standard deviation does not (:33419-33422). A typed number is that level, as in the
  rows of the Statistics panels, and a deviation of 0 can be asked for.
- **The scale.** The text beside the criterion list reads «Ratio x 10: 15 means 1.5» for «Aspect
  ratio», «Histogram levels: 0 to 255» for the histogram criteria, and «Histogram levels: 0 to 128»
  for the standard deviation (:33350, :33358). The other criteria keep «File property» and «Image
  property». The text takes the width that is free beside the list (:33202), and the panel keeps its
  size.
- **«Aspect ratio»** is still typed as ten times the ratio. The text now says so.

Run on the fix (W14 and the new batch W15; B again):

- **«Average» 100 to 150** lists the file at 120 alone. 101 to 151 lists the files at 120 and 150.5.
- **Deviation 0 to 10** lists the files at 0 and 0.01. **0 to 0** lists the file at 0.
- **The row of the Statistics panel**, then a field changed and changed back: the file at 120, which
  is what the row itself lists.
- **The texts fit**: they need 124 and 132 pixels of 200, and 241 and 256 of 330 with large fonts.
  The panel measures 358 by 354 pixels before and after the fix, and 611 by 464 with large fonts
  (under Wine).
- **«Aspect ratio»** 10 to 20 lists the two files, as before (B6b).

---

## 15. «Selected files» with one selected file says none is selected

`BtnApplyFilesFilter()` :33472-33478; `getSelectedFiles()` :39980-39985

QPV's rule: a selection of exactly one file does not count, and `getSelectedFiles(0, 1)` unselects it.

- **Run** (P2): a02.png selected, «Selected files», «Apply filter». The box says «You currently have no
  selected image in the files list. The filter is therefore inapplicable.», and a02.png is no longer
  selected.
- **Control**: two selected files (P2b) are filtered as expected.

---

## 16. Small things

✅ marks a fixed one.

- **16.1. «Selected files» ignores the string filter, «Already seen» applies it, and the query box shows
  neither** (run).
  - P2b: a01.png and b05.png selected, `a0` ticked: both files are listed.
  - P3c: a01, a02 and b05 recorded as seen, `a0` ticked: a01 and a02 are listed.
  - The query box read only `||Prev-Files-Selection||` and `||Already-Seen-Images||`.
- **16.2. `?` is one character or none on plain lists, and exactly one on database lists.**
  `JEE_StrRegExLiteral()` turns it into `.?` (:33058); `SQLlikeClauseFromFilter()` into `_` (:40251).
  D2, `x?.png` on x.png, x1.png, x12.png: the plain list gives x.png and x1.png, the database list gives
  x1.png alone (run). The panel's line «You can use | for OR and the *, ? wildcards» does not say which.
- **16.3. Megapixels are rounded differently.** Database lists compare `Round(imgmegapix)`, whole
  numbers (:33406); plain lists use `Round(…, 1)` (:33902). «Megapixels» 2 to 2 takes 1.5-2.49 MP on a
  database list and 1.95-2.04 MP on a plain one (read).
- **16.4. «Already seen» says the list is unchanged after it has removed the active filter.** With two
  records and none of them in the list (P3b): «No seen images identified. Files list left unchanged, no
  filter applied.», yet the filter `a01|a02` was removed before the check (:36264-36265), and all 5 files
  are listed (run).
- ✅ **16.5. The wrong wording when a filter is removed.** On a database list, the save question asked
  while removing a filter reads «…the files list will be filtered to given criteria» (:28522) (run, D1).
  Fixed in `68d5511`, by Marius: the two handlers ask, with «…and the files list filter will be
  removed» (run, HD).
- **16.6. Two save questions on a database list.** «Apply filter» asks in `BtnApplyFilesFilter()`
  (:33490) and again in `BtnIndexStatsToList()` (:28522). `askAboutFileSave()` repeats its last answer
  for 300 ms only (:65785), so the question comes back when collecting the data takes longer. «Cancel»
  at the second one then shows «No files matched the provided filter options» (:33831) (read).
- **16.7. «Already seen» with fewer than two files listed does nothing, with no message**
  (`If (maxFilesIndex>1)`, :36238) (read).
- **16.8. A pattern that travels with a criterion is cut at `::`** (`StrSplit(filesFilter, "::")`
  :33772), so a RegEx holding `::` loses its end (read; noted on 2026-11-13).
- **16.9. «Invert filter» takes in the files whose value could not be read.** A blank value fails
  `isInRange()` (:33933) and the inversion turns that into a match (read).
- **16.10. `FiltersComboAction()` (:33085) is not called anywhere** (read).
- **16.11. A filter of one or two characters is not recorded in the history.**
  `RecordUsedFiltersManager()` wants three characters (:33559), while the list shows saved entries
  from two characters on (:33081). W12: the filter `a0` is applied and leaves the section as it was
  (run; lines at `25429a9`).

---

## Seen in passing

✅ marks a fixed one.

- **A. The Search panel's «Filter list» drops the active search.** `OpenFilterPanelBTNaction()` empties
  `userSearchString` (:47953), so F3 has nothing to search for afterwards (read).
- ✅ **B. Ctrl+Space shares findings 1 and 2a**, through the same `remFilesListFilter()`. Finding 1 was
  run for it (C2b); 2a was read. Fixed in `68d5511`, by Marius, with the two findings; both were run
  for it (H1b, HDb).
- **C. The static folders routes remove the filter without the save question.**
  `LoadStaticFoldersCached()` (:35544) and `regenerateStaticFoldersList()` (:35571) call
  `remFilesListFilter()` themselves, so an edited image goes as in finding 1 (read; lines at `bdc80f1`).
- **D. The «already seen» quick actions share route b of finding 2.** `quickFindSeenImages()` (:33460)
  calls the same function, with the 1 since `886cdfb`. With fewer than two seen records the active
  filter now stays, but the settings the action wrote are not put back: «Already seen», and its own
  text in the string field. The panel's query box then keeps the active filter (finding 3) (read;
  lines at `bdc80f1`).
- **E. A histogram row of the Statistics panel rounds its two limits to three decimals**
  (`BtnIndexStatsToList()` :28643-28644), while the values are stored with five. The row «100-150»
  asks for 0.395 to 0.590, so an average between level 100 and 100.1 is left out (W14: the row's
  query; the gap is read from the numbers). This panel asks for 0.39453 to 0.58984 for the same two
  numbers (lines at `25429a9`).

---

## Checked and found correct

- **The control cases** (run): «Begins with» `1x` (A1b), «Ends with» `a1` on folder paths (A2b), `x1|y`
  (A3b), a `/` taken out of the text (A5), «File size» 2-10 KB (B1), «Modified date» 2019 at its first
  application (B3), «Aspect ratio» 10-20 (B6b), «Selected files» with two files (P2b), «Already seen»
  with records in the list (P3c).
- **«No files matched»** shows its box and brings the whole list back (A3, A4c, B6) (run).
- **«Cancel» at the save question of «Apply filter»** keeps the edits (C3) (run).
- **«Erase history» more than a second after a box** rebuilds the panel normally (E3) (run). Since
  `d2ae7c5` the button does not rebuild the panel at all (finding 11).
- **«Search»** closes this panel with `BtnCloseWindow()` (:47838-47839), so the refusal of finding 10
  does not reach it (read).
- **«Cancel» and Escape** put back the settings the panel opened with (`CloseWindow()` :99902-99903)
  (read). Since `ed7a1a1` the two dates are among them (run, V1).
- **The duplicates list**: on pairs filtered by Hamming distance the panel opens the threshold panel
  instead (:33152-33158), and the Find menu disables «Define index filter(s)» there (:68929) (read).
- **The panel's variables** are super-globals (:296-303); `FilterTypeu` and `InternalFilterString` are
  declared global in the function (:33148) (read).
- **Right-clicks** (`SettingsGUIAGuiContextMenu()` :25990, read). On a control, QPV shows a line that
  describes it (`SettingsToolTips()` :27465). On the panel's background, the generic panel menu opens
  (`invokePrefsPanelsContextMenu()` :27379), whose two toggles rebuild the panel (finding 11). The panel
  has no menu of its own.

---

## Decisions to make before fixing

Decisions 1 to 14 are settled; decision 15 is open.

1. Finding 1: should «Remove filters» ask the save question before the list changes, as «Apply filter»
   does? On a database list, should «Cancel» keep the image shown? And Ctrl+Space too?
   **Settled in `68d5511`**, by Marius: yes to the three.
2. Finding 2: on each of the three routes, should the active filter and its list stay as they were
   («Cancel» does nothing; «No records» keeps the filter; the abort puts the filtered list back)? Or
   should the filter be removed and the whole list put back?
   **Settled in `68d5511` and `886cdfb`**: they stay as they were, and the panel's settings with them.
3. Finding 3: should the panel open on the active filter? That needs the dates kept with the settings,
   and a text variable of its own for the Search panel. Or should the query box keep the active filter
   until a field changes?
   **Settled in `ed7a1a1`**: both. The dates are kept and the Search panel has its own text; the query box
   keeps a filter the fields cannot rebuild, and «Apply filter» with nothing changed leaves it in
   place.
4. Finding 4: should the question be asked before the panel closes, with the panel kept open on
   «Cancel», as the structured panel does since `ed8848c`? Should the typed filter be kept on «Save»?
   **Settled**: asked before the close, and the panel kept on «Cancel» (`35329bc`, by Marius). «Save»
   and the «Already seen» criterion are left as they are (his answer, 2026-11-23).
5. Finding 5: should empty terms be dropped, as the database lists do, or should the text be refused?
   **Settled in `35329bc`**, by Marius: dropped.
6. Finding 6: should «Begins with», «Ends with» and «RegEx» apply to one character too?
   **Settled in `35329bc`**, by Marius, for the first two, **and in `bdc80f1`** for «RegEx»: yes.
7. Finding 7: should `||` be read as one bar?
   **Settled in `35329bc`**, by Marius: yes.
8. Finding 8: should an empty side mean «no limit» on that side, or be refused with a message?
   **Settled in `07fddfd`**: refused with a message (his answer, 2026-11-23).
9. Finding 9: should the random jump go from «Remove filters», as from Ctrl+Space since 2020? Should it
   stay for «Apply filter» on database lists?
   **Settled in `91c3834`**: it goes from «Remove filters», and it stays for «Apply filter» on database
   lists (his answer).
10. Finding 10: should «Erase history» close with `BtnCloseWindow()`, and «Stats» check
    `createSettingsGUI()`'s result?
    **Settled**: «Stats» checks the result since `79d0e05`, by Marius. «Erase history» no longer closes
    the panel (`d2ae7c5`), at his request.
11. Finding 11: should «Erase history» ask first? Should the typed filter survive a rebuild?
    **Settled in `d2ae7c5` and `08b5a01`**: yes to both, and «Erase history» changes the list in the open
    panel (his answer and his request).
12. Finding 12: should the history compare whole entries?
    **Settled in `26363c7`**: yes.
13. Finding 13: which of «Apply filter» and «Cancel» gets another letter, and which one?
    **Settled in `35329bc`**, by Marius: «Cancel», with Alt+C.
14. Finding 14: how should the scales be shown? Should a standard deviation of 0 be allowed?
    **Settled in `25429a9`**: the histogram fields are levels from 0 to 255, so a deviation of 0 is
    allowed, and the text beside the criterion list shows the scale (his answer).
15. Finding 15: should «Selected files» accept one file, or say why one is not enough?

---

## How this was checked

- **Static reading** of `development` at `0b6cb07`: the panel, its handlers, the routes that open it
  (Ctrl+F, the Find menu, the files list menu, the toolbar, the Statistics and Search panels, the
  auto-select duplicates panel :47602), the filter engine, and each helper before a call to it was
  judged.
- **The real application under headless Wine**, on the stock AutoHotkey 1.1.37.02, started on one image,
  with test functions appended to a scratch copy of the script. A test builds a folder, opens it as a
  files list (or saves it and opens it as a database list), opens the panel through
  `PanelEnableFilesFilter()`, sets its fields and posts a click to a button; the handlers then run as
  they are. The log keeps the messages and boxes, the index, the active filter, the panel's fields and
  the settings.
- **The scratch copy differs from the source** in that messages and tooltips are logged, and so are the
  calls to `askAboutFileSave()`, `RandomPicture()`, `coreSetFilesFilteru()`, `PanelEnableFilesFilter()`,
  `PanelWrapperFilesStats()`, `BtnIndexStatsToList()` and `terminateIMGediting()`.
- **Aids**, each named where it was used:
  - an edited image simulated by its state (findings 1, 4);
  - the abort answered by a patched `determineTerminateOperation()` (2c);
  - histogram and aspect values set by the test (14);
  - seen-image records written by the test (2b, 16.1, 16.4);
  - key presses posted to the focused control (13);
  - a second process that answers AutoHotkey's error boxes (10).
- **Batches**: A (the string filter), B and B4 (the criteria, dates, the abort, the scales), C («Remove
  filters», the save question, «Erase history», the history list), E (one second after a box), K
  (Alt+A), P («Search», «Selected files», «Already seen», a rebuild), D (a database list).
- **Not run on Windows**: how Windows handles the letter two buttons share (finding 13) rests on Windows
  itself.
- **Not run at all**:
  - Quick search actions fired while the panel is open;
  - multi-page preview mode (a file's pages listed as a filter);
  - the data collection question on database lists (`collectSQLFileInfosNow()` with its question).
- **The check of findings 1 to 6, on 2026-11-23**, at `60af1a0`:
  - batches A, B, B4 and P as they were, with Ctrl+Space called under its new name;
  - the new batches H1 and HD: «Remove filters» and Ctrl+Space with an edited image and each answer
    to the save question, on a plain list and on a database list. HDb is the run of finding 2a
    through Ctrl+Space that the audit had left out;
  - H4: «Apply filter» with an edited image and each answer, and «Already seen»;
  - H5 and H6: bars, no text, one character, «RegEx» patterns.

  «Save» was run with the save panel replaced by a log line.
- **The fixes, on 2026-11-23**: the new batches V1, V2 and V3 (the fixes' cases; V3 also runs
  «Erase history» and the Search panel's «Erase search criteria», which pass through edited code),
  then A, B, B4, P, H1, HD, H4, H5 and H6 again, all on the text of `bdc80f1`. Against the runs at `60af1a0`, the logs of A, B,
  B4, P, H4, H5 and H6 differ only in what the fixes change; those of H1 and HD differ only in where
  the random jump lands. V1 and V2 were also run on `886cdfb` and on `ed7a1a1`: each shows its own finding
  fixed and the later ones as before. Each of the three commits loads on the stock AutoHotkey
  1.1.37.02 (`/iLib`, then in full).
- **Batches C, D, E and K** predate `68d5511` and were not run again: C and D leave its save question
  unanswered, and K looks for «C&ancel». The batches W9 to W13 take over their cases for findings 9
  to 13.
- **The check of findings 8 to 14, on 2026-11-23**, at `8cdff2b`:
  - batches B and P as they were;
  - W9: where «Remove filters», Ctrl+Space and «Apply filter» land, on a plain list and on a
    database list;
  - W10: batch E with a history, and the list and the saved section logged afterwards;
  - W11: «Erase history» with and without an active filter, and the two toggles;
  - W12: the history list, and the saved section after a filter is recorded;
  - W13: batch K with «&Cancel», Alt+A and Alt+C;
  - W14: averages set by the test, and a row of the Statistics panel run through
    `BtnIndexStatsToList()`, with the panel's number set by the test in place of the open panel.
- **The fixes of findings 8 to 14, on 2026-11-23**, all on the text of `25429a9`:
  - the new batch W8 (the refusal), and W9 to W14 again with the fixes' cases added: the answers to
    the question of «Erase history», a rebuild followed by «Cancel» and by «Apply filter», a filter
    the fields cannot rebuild, the deviation, the width of the texts;
  - the new batch W15: the panel's size and the place of the scale text, at both font sizes, before
    and after the fix;
  - A, B, B4, P, H1, HD, H4, H5, H6, V1, V2 and V3 again. Against the runs on `bdc80f1`, the logs of
    A, B4, H4, H6 and V1 are the same. Those of B, P and V3 differ only in what the fixes change.
    Those of H1 and HD differ only in the image shown after «Remove filters» and in where the random
    image of the database list lands. H5 and V2 differ by one line of the kit each (a display
    refresh logged at another place; a queued answer that found no box), with the cases' own lines
    the same.

  Each of the six commits loads on the stock AutoHotkey 1.1.37.02 (`/iLib`, then in full).
- **Kit**: `.claude/scratch/files-filter-panel-2026-11-20/app/`.
  - `run-ff.sh <tag> testFfA|testFfB|testFfB4|testFfC|testFfD|testFfE|testFfK|testFfP [revision]`
    (stock interpreter; `QPV_SRC=<file>` runs a modified source).
  - The test functions are in `test-ff.ahk`, on top of the structured kit's `test-wrappers-sc.ahk`.
  - `patch.py` and `patch-ff.py` add the logging; `closer2.ahk` answers the error boxes.
  - Logs are in `results/` (`a-head`, `b-head`, `b4-head`, `c-head`, `d-head`, `e-head`, `k-head`,
    `p-head`).
  - `test-ff-h.ahk` holds the batches of 2026-11-23 (`testFfH1`, `testFfHD`, `testFfH4`, `testFfH5`,
    `testFfH6`, `testFfV1`, `testFfV2`, `testFfV3`); `run-ff.sh` appends it. Its `ffNoSavePanel` makes
    `PanelSaveImg()` a log line (`patch-ff.py`).
  - Their logs: `a-head2`, `b-head2`, `b4-head2`, `p-head2`, `h1-head`, `hd-head`, `h4-head`,
    `h5-head`, `h6-head` (at `60af1a0`); `v1-fix`, `v2-fix`, `v3-fix` and the same names ending in
    `-fix` (the fixed text).
  - `test-ff-w.ahk` holds the batches for findings 8 to 14 (`testFfW8` to `testFfW15`). Their logs:
    `b-head3`, `p-head3` and `w9-head` to `w15-head` (at `8cdff2b`); `w8-fix` to `w15-fix`, and
    `a-fix2` to `v3-fix2` for the twelve earlier batches (the fixed text). `../commits2/stage.py`
    rebuilds the six fixes from the text of `8cdff2b`.
