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

| # | Finding | Harm | Checked | Status at `0b6cb07` |
|---|---------|------|---------|---------------------|
| 1 | «Remove filters» discards an edited, unsaved image: with no question on a plain list, and on a database list also after «Cancel» when another file ends up current | high | run | open |
| 2 | Three routes leave the list filtered while no filter is active, so files leave the index | medium | run | open |
| 3 | The panel, opened again, shows another filter than the active one, and «Apply filter» then replaces it | medium | run, and read for one case | open |
| 4 | «Save» or «Cancel» at the save question of «Apply filter» closes the panel and erases the typed filter | low | run | open |
| 5 | A bar at the start or the end of the text matches every file | medium | run | open |
| 6 | One character with «Begins with», «Ends with» or «RegEx» is matched anywhere | medium | run, and read for «RegEx» | open |
| 7 | A doubled bar joins the two words around it | low | run | open |
| 8 | An empty «Minimum» or «Maximum» drops the criterion, silently when a string is ticked | low | run | open |
| 9 | «Remove filters» shows a random image; on a database list «Apply filter» does too | low | run | open |
| 10 | A button pressed within a second of a message box raises an AutoHotkey error | low, narrow | run | open |
| 11 | «Erase history» asks nothing, and the rebuilt panel loses the typed filter; the theme and font toggles too | low | run | open |
| 12 | The history list hides entries that end another entry's text, and lists the active text twice | low | run | open |
| 13 | «Apply filter» and «Cancel» share Alt+A | low | run (Wine) | open |
| 14 | The scales of «Aspect ratio» and of the histogram criteria are not shown; a standard deviation of 0 cannot be reached | low | run | open |
| 15 | «Selected files» with one selected file says none is selected, and drops that selection | low | run | open |
| 16 | Small things, numbered 16.1 to 16.10 | low | run and read | open |

Finding 1 loses work for good. Finding 2 removes files from the index until the folder or the list is
opened again. Findings 3 and 5 to 8 filter by something the user did not ask for, and say nothing about
it. Findings 3 and 6 need nothing more than reopening the panel or typing one character.

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

---

## 7. A doubled bar joins the two words around it

`updateUIFiltersPanel()` :33301 and :33429

Outside «RegEx», line :33301 deletes every `||` before the query is built, so `x1||y` becomes `x1y`.
The later line :33429, `StrReplace(newFilter, "||", "|")`, would read the pair as one bar, but by then
none is left.

Run (A3): `x1||y` gives the query `i)(x1y)`, no file matches, the box comes up and the whole list
returns. Database lists pass through the same line (read).

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
- **16.5. The wrong wording when a filter is removed.** On a database list, the save question asked
  while removing a filter reads «…the files list will be filtered to given criteria» (:28522) (run, D1).
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

---

## Seen in passing

✅ marks a fixed one.

- **A. The Search panel's «Filter list» drops the active search.** `OpenFilterPanelBTNaction()` empties
  `userSearchString` (:47953), so F3 has nothing to search for afterwards (read).
- **B. Ctrl+Space shares findings 1 and 2a**, through the same `remFilesListFilter()`. Finding 1 was
  run for it (C2b); 2a was read.

---

## Checked and found correct

- **The control cases** (run): «Begins with» `1x` (A1b), «Ends with» `a1` on folder paths (A2b), `x1|y`
  (A3b), a `/` taken out of the text (A5), «File size» 2-10 KB (B1), «Modified date» 2019 at its first
  application (B3), «Aspect ratio» 10-20 (B6b), «Selected files» with two files (P2b), «Already seen»
  with records in the list (P3c).
- **«No files matched»** shows its box and brings the whole list back (A3, A4c, B6) (run).
- **«Cancel» at the save question of «Apply filter»** keeps the edits (C3) (run).
- **«Erase history» more than a second after a box** rebuilds the panel normally (E3) (run).
- **«Search»** closes this panel with `BtnCloseWindow()` (:47838-47839), so the refusal of finding 10
  does not reach it (read).
- **«Cancel» and Escape** put back the settings the panel opened with (`CloseWindow()` :99902-99903)
  (read).
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

1. Finding 1: should «Remove filters» ask the save question before the list changes, as «Apply filter»
   does? On a database list, should «Cancel» keep the image shown? And Ctrl+Space too?
2. Finding 2: on each of the three routes, should the active filter and its list stay as they were
   («Cancel» does nothing; «No records» keeps the filter; the abort puts the filtered list back)? Or
   should the filter be removed and the whole list put back?
3. Finding 3: should the panel open on the active filter? That needs the dates kept with the settings,
   and a text variable of its own for the Search panel. Or should the query box keep the active filter
   until a field changes?
4. Finding 4: should the question be asked before the panel closes, with the panel kept open on
   «Cancel», as the structured panel does since `ed8848c`? Should the typed filter be kept on «Save»?
5. Finding 5: should empty terms be dropped, as the database lists do, or should the text be refused?
6. Finding 6: should «Begins with», «Ends with» and «RegEx» apply to one character too?
7. Finding 7: should `||` be read as one bar?
8. Finding 8: should an empty side mean «no limit» on that side, or be refused with a message?
9. Finding 9: should the random jump go from «Remove filters», as from Ctrl+Space since 2020? Should it
   stay for «Apply filter» on database lists?
10. Finding 10: should «Erase history» close with `BtnCloseWindow()`, and «Stats» check
    `createSettingsGUI()`'s result?
11. Finding 11: should «Erase history» ask first? Should the typed filter survive a rebuild?
12. Finding 12: should the history compare whole entries?
13. Finding 13: which of «Apply filter» and «Cancel» gets another letter, and which one?
14. Finding 14: how should the scales be shown? Should a standard deviation of 0 be allowed?
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
  - the data collection question on database lists (`collectSQLFileInfosNow()` with its question);
  - finding 2a through Ctrl+Space;
  - finding 1 when the index left after «Cancel» points at the edited file itself.
- **Kit**: `.claude/scratch/files-filter-panel-2026-11-20/app/`.
  - `run-ff.sh <tag> testFfA|testFfB|testFfB4|testFfC|testFfD|testFfE|testFfK|testFfP [revision]`
    (stock interpreter; `QPV_SRC=<file>` runs a modified source).
  - The test functions are in `test-ff.ahk`, on top of the structured kit's `test-wrappers-sc.ahk`.
  - `patch.py` and `patch-ff.py` add the logging; `closer2.ahk` answers the error boxes.
  - Logs are in `results/` (`a-head`, `b-head`, `b4-head`, `c-head`, `d-head`, `e-head`, `k-head`,
    `p-head`).
