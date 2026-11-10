# «Review selected files» panel audit, 2026-11-09

Scope: `PanelReviewSelectedFiles()` (:95096), the panel it builds, its button actions, its
keys and its context menu, `invokePanelReviewSelContextMenu()` (:93515). That is every
function from :95096 to the end of `uiPopulateReviewSelectedFiles()` (:95723), and the helpers
those functions hand the work to, as far as a panel action reaches them. Line numbers are
`quick-picto-viewer.ahk` on `development` at 5af5eff. The audit itself changed no code.

Nineteen findings. Each one says how it was checked: **run** means the real application did it
under headless Wine, on AutoHotkey_H 1.1.33.10 (the two largest batches also on stock
AutoHotkey 1.1.37.02, with the same log); **read** means it follows from the code and was not
run. Nothing was run on Windows. The test kit is described at the end.

Two independent reads of the same code followed the first version of this report. They
confirmed every finding but 9, which neither raised, and narrowed finding 12. What they added
is marked **second read**. Six of those points were run (batch J); the others say «read».

**Status, 2026-11-10.** Marius fixed part of this in five commits: `ef705b0`, `16b35ff`,
`7f0e8cf`, `b302cc9` and `cc34faf`. Findings 7, 8 and 9 were fixed after them, in `ca918d3`,
`643541d` and `f6f9fb2`, with his answers to decisions 3 and 7. Findings 1 to 9, 13, 15, 16
and 18 are fixed; 14, 17 and 19 are partly fixed; 10 to 12 are open. A fixed or partly fixed
section ends with a note on what the code does now. Those notes cite lines at `07746da`, the
commit after `cc34faf`; the notes of findings 7, 8 and 9 cite lines at `ca918d3`. Everything
else keeps its lines at 5af5eff. Each note was checked by running the earlier batches again
on the commit it cites, with six new ones: K, L, N and O for the first five commits, P and Q
for the last three.

What the commits changed besides is under «New with the fixes». One narrow point is open
there: F3 closes the panel when the unsaved-image question stopped it.

## Terms

- **Index**: QPV's files list, `resultedFilesList`. A row's «#» column holds the file's
  position in it.
- **Selected file**: a file marked in the index (`resultedFilesList[i, 2]`). The panel's «S»
  column shows «S» for a selected file and «_» for one that is not. `markedSelectFile` counts
  them.
- **Highlighted row**: a row picked in the panel's table, the list view's own selection. The
  «Select», «Deselect» and «Copy» actions work on the highlighted rows.
- **Focused row**: the one row that has the keyboard focus, the row with the dotted
  rectangle. The «Open» actions, «Modify index entry», F2, F3 and F6 work on it.
- **Full table** and **filtered table**: the panel holds two list views in the same place,
  `LViewOthers` and `LViewFiltered`. The second one is shown while a filter is applied.
- **Page**: the full table is filled in portions. A portion ends once 3.5 s have passed and
  `LVitemsPerPage` rows were added (5100 when QPV starts); scrolling to the end of the table
  asks for the next one.
- **Stopping a listing**: a long loop asks `determineTerminateOperation()` at every step. The
  user stops it by clicking the main window and answering «Yes» to the prompt.
- **One-file rule**: `getSelectedFiles(0, 1)` deselects a selection of exactly one file
  (:39532). It is deliberate, and several findings meet it.

## Summary

| # | Finding | Harm | Checked | Status at `07746da` |
|---|---------|------|---------|---------------------|
| 1 | With no focused row, the column header «#» is used as the file index: Enter on a freshly opened panel breaks the view | high | run | **fixed**, `ef705b0` |
| 2 | F3 «Filter files list to selected path» drops the whole selection first, and may then do nothing else | high | run | **fixed**, `16b35ff` and `b302cc9` |
| 3 | «Select files in index in same folder» and F3 use the folder of the image in the viewport, not the row's | high | run | **fixed**, `ef705b0` |
| 4 | The «Open» actions and F6 move the viewport; with auto-remove on, index entries vanish under the open panel and its rows then point at the wrong files | high, needs an option | run | **fixed**, `ef705b0` |
| 5 | A failed «Modify index entry» leaves the panel on screen while QPV believes no panel is open | medium | run | **fixed**, `16b35ff` |
| 6 | F6 does nothing | medium | run | **fixed**, `ef705b0` |
| 7 | The «S» column is not kept in step with the index | medium | run | **fixed**, `ca918d3`, for the rows in view |
| 8 | «None» and «Deselect listed items in index» can select instead | medium | run | **fixed**, `643541d` |
| 9 | With 26 or more rows in view, the rest of a long table can never be listed | medium | run | **fixed**, `f6f9fb2` |
| 10 | A listing the user stopped: no notice, no way to resume, and a filter remembers the partial result as final | medium | run | open |
| 11 | «X» pressed while a filter is being listed puts the filtered rows into the full table | medium, rare | run | open |
| 12 | Network paths lose their leading `\\` in the folder column, in two copy actions and in «Folder properties»; such paths reach the index only through «Search and replace» | low, narrow | run | open |
| 13 | `*` is not a wildcard in the filter box | medium | run | **fixed**, `ef705b0` |
| 14 | «Filter table to selected path» also lists folders whose name begins the same; its tick never comes off | low | run | **partly fixed**, `ef705b0`: private mode is left |
| 15 | «Open image with an external app» removes the `\|` from the list's source name | medium | run | **fixed**, `ef705b0` |
| 16 | «Modify index entry»: three answers close the panel for good, two bring it back | low | run | **fixed**, `16b35ff` and `b302cc9` |
| 17 | A copy the user stopped is announced as done; equal file names are merged | low | run | **partly fixed**, `cc34faf`: equal names are still merged |
| 18 | Every changed row runs the list's event handler | low, large selections | run | **fixed**, `ef705b0` and `16b35ff`: Ctrl+A on 60 000 rows takes 12 s, not 21 s |
| 19 | Small things: a tooltip that stays, an unapplied filter applied by scrolling, a typed number changed by the arrow keys, memory kept, two items on the same Alt letter | low | run | **partly fixed**, `cc34faf`: four of its ten points |

Findings 1, 2 and 3 are the ones a user meets in ordinary use. All three are fixed. Finding 4
needed «Automatically remove index entries pointing to inexistent files» to be on, and a
selected file that is missing from the disk.

---

## 1. With no focused row, the column header «#» is used as the file index

`uiLVreviewSelFilesResponder()` :95510, `BtnReviewPaneOpenActs()` :95244,
`BTNreviewSelFilesInPath()` :95232, `BTNreviewFilterLVSelPath()` :95278

```ahk
RowNumber := LV_GetNext(0, "F")
LV_GetText(indexu, RowNumber, 4)
…
BtnCloseWindow()
currentFileIndex := indexu
dummyTimerDelayiedImageDisplay(50)
```

`LV_GetNext(0, "F")` answers 0 when no row has the focus, and `LV_GetText()` for row 0 gives
the column's header text, here «#». Two ordinary states have no focused row:

- **A freshly opened panel.** The list view has the keyboard focus, but none of its rows has
  it until the user clicks a row or presses an arrow key.
- **After Ctrl+A.** `BTNreviewLVselAll()` highlights every row with `LV_Modify(0, "+Select")`
  and focuses none.

What happens (run):

- **Open the panel and press Enter**, or double-click the empty space under the rows. The
  panel closes and `currentFileIndex` is «#». The viewport is cleared, the message reads
  «ERROR: File not found or access denied» with no file name, the title reads `[*] #/8`, and
  the journal gets «Index entry error: incorrect file path». The next «next image» or
  «previous image» key lands on the last file of the list, so the place in the list is lost.
- **Ctrl+A, then «More», «Open», «Folder properties»**: the properties call gets an empty
  folder, `currentFileIndex` is «#», and the panel stays open. F2 then asks «Current index:
  # / 8».
- The other focused-row actions fail quietly in that state: «Open folder in Explorer» finds
  no path, «Filter table to selected path» empties the filter box, «Select files in index in
  same folder» falls back to the image in the viewport (finding 3).
- **F2 in that state, then a real path and «Update entry»** (second read, run): the files
  list gets an entry under the key «#». The list object then holds six entries against a
  `maxFilesIndex` of 5.
- F3 in that state drops the selection and takes the viewport's folder (findings 2 and 3,
  read).
- A double-click on empty space while a row is focused opens that row, because the handler
  never looks at the row the event names (read). The same goes for an empty filtered table.

Enter reaches this code through `decideBlockKbdKeys()` (:666-669), which keeps the key away
from the «Apply» button while the list has the focus, and `externalinvokedSettingsContextMenu()`
(:25909), which calls the responder with `"DoubleClick"`. Both were run.

The folder panels guard the same case in sixteen places: `folderu="folder path"` is the
header text of their column (:35136, :95785, :96057 and others). This panel has no such test.
AutoHotkey's ListView page says of the focused row «sometimes there is none at all», and its
example tests for it (`if not FocusedRowNumber  ; No row is focused.`).

Fix direction: return when `RowNumber` is 0 in the four functions.

**Fixed in `ef705b0`** by the fix direction (:95238, :95254, :95291, :95552). Run:

- Enter on a fresh panel does nothing. The panel stays open, the current file stays the
  current one, and the «next image» key goes on from it.
- After Ctrl+A, «Folder properties» and «Filter table to selected path» do nothing, and F2
  shows no prompt, so no entry can be written under the key «#».
- «Select files in index in same folder» does nothing in that state (read).
- F1 and F5 work with no focused row (run). `ef705b0` had put the return above their tests;
  `7f0e8cf` moved the two tests above it (:95541-95549).

Left as it was: a double-click on empty space opens the focused row (read).

The menu's F3 item does nothing with no focused row (run; `cc34faf`, :95228).

---

## 2. F3 «Filter files list to selected path» drops the whole selection first

`BTNreviewFilterListSelPath()` :95216

```ahk
dropFilesSelection()
BTNreviewSelFilesInPath()
If (markedSelectFile>1)
{
   BtnCloseWindow()
   filterToFilesSelection()
}
```

The action filters the files list by selecting the folder's files and then filtering to the
selection. So the selection the user is reviewing is dropped at the first line, with the
message «Files selection dropped».

- **When fewer than two files come back selected, nothing else happens.** The folder holds a
  single indexed file (the one-file rule deselects it), or the list has fewer than three
  files (`QuickSelectFilesSameFolder()` returns at :47155). Run: four files selected, F3 on a
  row, the image in the viewport alone in its folder. Afterwards no file is selected, the
  panel is still open, and its four rows still show «S».
- **When it works**, the panel closes and the list is filtered, but the selection is now the
  folder's files (run: a1, a2, b1, b2 selected before; b1, b2, b3 after). The earlier
  selection cannot be brought back.

Finding 3 decides which folder that is.

Fix direction: filter by the folder path without going through the selection, or put the
flags back when the filter is in place. Decision 1.

**Fixed in `16b35ff`** by the first fix direction, which settles decision 1. F3 no longer
goes through the selection. `BTNreviewSelFilesInPath("filter")` hands the row's index to
`activateFilesListFilterBasedOnFolder()` (:95243, :2685), the function behind Shift+E in
thumbnails view. The panel closes once the filter is on (:95228).

Run: nine files, a1, a2, b1, b2 and `pv\B\sub\s1.png` selected, F3 on the b1 row.

- The list holds b1, b2 and b3: the row's folder alone, without `pv\B\sub` and `pv\B2`.
- Nothing is deselected. Once the filter is removed, the same five files are selected.
- The viewport's file plays no part: the result is the same with the viewport on
  `pv\C\c1.png`, on b1 and on a1.
- A row alone in its folder gives a list of that one file.
- The panel closes each time. At `16b35ff` it stayed open over the filtered list, because
  the test asked for `currentFileIndex>1`; `b302cc9` asks for `maxFilesIndex>0`.

`ef705b0` had taken a first step, a `"drop-sel"` argument for `QuickSelectFilesSameFolder()`.
Nothing passes it any more (`bonusAct`, :47175).

What the same test does when the unsaved-image question stops F3 is under «New with the
fixes».

---

## 3. «Select files in index in same folder» and F3 use the folder of the image in the viewport

`BTNreviewSelFilesInPath()` :95234, `QuickSelectFilesSameFolder()` :47153

```ahk
QuickSelectFilesSameFolder(resultedFilesList[thisFileIndex, 1], "aye")
…
imgPath := (isNumber(modus) && modus>0 && external="aye") ? modus : getIDimage(currentFileIndex)
```

The panel passes the row's file path. The callee accepts its first argument only when it is
a number, and a path is not, so it always takes the current image. Both lines date from
e0b347a (2022-03-31).

Run: files in `pv\A`, `pv\B` and `pv\C`; a1 and b1 selected; the viewport on `pv\C\c1.png`;
the action on the `pv\B` row. Result: the three `pv\C` files are selected and a1 and b1 are
not. The two rows of the panel still show «S» (finding 7).

With more than two files selected, `SearchIndexSelectAll()` first asks «Replace», «Add» or
«Substract» (:47025); the folder is the wrong one in every case.

Fix direction: `(external="aye" && modus!="") ? modus : getIDimage(currentFileIndex)`.

**Fixed in `ef705b0`** by the fix direction (:47167). Run, the same files: the action on the
`pv\B` row selects the three `pv\B` files. The panel's two rows still showed «S» then;
since `ca918d3` the row of a1, which the action deselects, shows «_» (finding 7).

---

## 4. The «Open» actions and F6 move the viewport; index entries can vanish under the open panel

`BtnReviewPaneOpenActs()` :95246, :95250

```ahk
currentFileIndex := thisFileIndex
…
dummyTimerDelayiedImageDisplay(25)
```

These two lines run before the action is even chosen. So «Open folder in Explorer», «Open
image with a new QPV instance», «Open image with an external app», «Folder properties» and
the F6 key all make the row's file the current one and schedule a redraw. In image view the
main window loads that image; in thumbnails view the list moves to it.

That alone is a side effect to decide on (decision 2). It becomes harmful with **«Automatically
remove index entries pointing to inexistent files»** on (`autoRemDeadEntry`, off by default),
in image view, when the row's file is missing from the disk:

- The redraw removes the entry from the index (`ShowTheImage()` :75167). Every file after it
  moves up one position.
- The panel stays open. Its «#» column and `reviewSelectedIndexes` still hold the old
  positions, so each later row now points one file further.

Run, that option alone: six files selected, the second one missing; F6 on its row. The index
has five entries; the panel still lists six, with their old numbers.

Run, with **«Automatically skip inexistent files»** on as well: «Folder properties» on the
same row removed two entries, the missing file and the healthy `d3.png` after it (see «Seen
in passing», A). Then «Deselect» on the row that shows `d3.png` deselected `d5.png`.

A row whose number is now past the end of the list does more (second read, run): «Deselect»
on it writes a flag at that position, which creates an entry with no path. The list object
then holds six entries against a `maxFilesIndex` of 5.

Fix direction: give the «Open» actions the row's path instead of changing `currentFileIndex`,
or rebuild the panel whenever `maxFilesIndex` changed since it was filled.

**Fixed in `ef705b0`**, in two ways.

- **The «Open» actions and F6 get the row's path** and leave `currentFileIndex` alone
  (:95266-95281). Only «Modify index entry» sets it, once the panel is closed (:95274). Run:
  F6 and the four menu items on rows other than the viewport's file; that file stays the
  current one. The redraw is still scheduled (:95261); it now repaints the same image.
- **No entry is removed while a panel is open.** The three places where auto-remove acts
  now ask for `!AnyWindowOpen` (:32748, :75184, :89119). Run, six files
  selected, the second one missing: with auto-remove alone, F6 on its row leaves six entries;
  with both options on, «Folder properties» leaves six, and «Deselect» on the `d3.png` row
  deselects `d3.png`.

«Modify index entry» gained from the second change. Before the commit, with auto-remove on,
the menu item on a missing file's row lost the entry it was about to edit (run on c5a32d3:
six entries when the prompt came up, five after «Cancel»). Now the six entries stay (run).
A row whose number is past the end of the list no longer comes about this way (run).

Finding 5's state, where that test would not hold, is no longer reached (`16b35ff`).

---

## 5. A failed «Modify index entry» leaves the panel on screen with no panel registered

`PanelUpdateThisFileIndex()` :41936-41939, :41959-41960

```ahk
If (!r && newFileName!=imgPath && newFileName)
{
   Sleep, 150
   SetTimer, PanelUpdateThisFileIndex, -150
} …
If (dummy="reviewer" && !preventer)
   SetTimer, PanelReviewSelectedFiles, -100
```

When the typed path does not exist or is not a valid image name, both timers are armed. The
review panel comes back first. Then the prompt comes up again, without the `"reviewer"`
argument: `fakeWinCreator()` sets `AnyWindowOpen := 21` over the real panel, and when the
prompt closes `msgBoxWrapper()` sets `AnyWindowOpen := 0` (:33304).

Run: «Modify index entry» on a row, a path that does not exist, «Update entry», then «Cancel»
in the second prompt. The review panel is on screen and `AnyWindowOpen` is 0. In that state:

- «Apply» and «X» do nothing: `uiPopulateReviewSelectedFiles()` leaves at :95572 and
  `UIstringEditFilterErase()` finds no branch (run: «IMG_1» typed, «Apply», the full table
  stays).
- Right-click and the Apps key show no menu: `SettingsGUIAGuiContextMenu()` (:25933) and
  `externalinvokedSettingsContextMenu()` (:25903) ask for `AnyWindowOpen=60` (read).
- The main window's keys and clicks are live again while the panel is open, because their
  gates test `AnyWindowOpen` (`HKifs()` :543). The list can then be sorted, filtered or
  shortened under a panel that still holds the old positions (read).
- **Another panel is built inside this window** (second read, run). `createSettingsGUI()`
  closes the open panel only when `AnyWindowOpen` is set (:28015). «Manage seed folders»
  opened in that state: the same window, 18 controls before and 28 after, under the new
  panel's title.
- «Erase entry» in the second prompt removes an index entry under the panel that just came
  back, with finding 4's effect (read).

«Refresh» and «Close» still work and put things right.

Fix direction: when the prompt is scheduled again, pass `"reviewer"` to it and do not arm the
panel's timer.

**Fixed in `16b35ff`**, the other way round: a prompt opened from the panel is not scheduled
again (:41952), and the panel's timer brings the panel back (:41973). Run: «Modify index
entry» on a row, a path that does not exist, «Update entry»:

- the message reads «ERROR: The file index entry was not updated. File not found or access
  denied», and no second prompt comes up;
- the panel is back and `AnyWindowOpen` is 60; «Apply» filters the table.

With the second prompt gone, so is its «Erase entry». Opened from the main window, the
prompt still comes up again after a failed update.

`createSettingsGUI()` is as it was: it closes the open panel only when `AnyWindowOpen` is
set (:28018). Nothing in this panel leads there any more.

---

## 6. F6 does nothing

`uiLVreviewSelFilesResponder()` :95532

```ahk
} Else If (b="K" && c=117) ; F6
{
   BtnReviewPaneOpenActs()
```

`BtnReviewPaneOpenActs()` picks its action from the menu item's name. Called with no
argument, none of its six tests matches. The menu shows F6 next to «Open folder in Explorer».

Run: F6 on a focused row calls nothing; the same menu item calls `OpenThisFileFolder()`. F6
still has the side effects of finding 4.

Fix direction: `BtnReviewPaneOpenActs("in explorer")`.

**Fixed in `ef705b0`** by the fix direction (:95569). Run: F6 on a focused row calls
`OpenThisFileFolder()` with the row's path, as the menu item does.

---

## 7. The «S» column is not kept in step with the index

The column is the panel's purpose, and five things let it go stale.

- **Three actions never refresh it**: «Deselect all in index» (`dropFilesSelection`, :93560),
  «Select files in index in same folder» (:93556) and an F3 that stopped half-way (finding 2).
  Run: 40 files, «Deselect all in index»; no file is selected and all 40 rows show «S».
- **The refresh skips the top row.** `UIupdateReviewLVinView()` :95384-95394 starts from the
  top row's number, which `LV_EX_GetTopIndex()` already gives counted from 1, and adds one
  before the first use. Run: after the step above, opening the context menu refreshed rows 2
  to 19; row 1 still shows «S».
- **The refresh covers 18 rows.** The list shows `uLVr` rows (:28108): 17 by default, 20 or
  more from «Additional list view rows» = 4 (9 with large fonts). The rows beyond the 19th in
  view keep their old mark (read).
- **The refresh runs at three moments only**: when the context menu opens (:93551), when a
  filter is erased (:95603) and after a later page (:95706). It does not run on scrolling, so
  rows scrolled into view show the old mark. It never runs for the filtered table (:95380).
- **The filtered table is reused.** When the same text is applied again, the table filled the
  first time is shown as it is (:95591-95596). Run: filter `\A\`, erase it, deselect three of
  those files in the full table, apply `\A\` again: the three rows show «S».
- **A stale «S» cannot be cleared with «Deselect»** (second read, run). A row is rewritten
  only when its flag changes (:95428), and the flag is already 0. Run: every file deselected
  in the index, then «Deselect» on three rows: they still show «S».

«Refresh» (F5) rebuilds the panel from the index, and loses the filter text and the place in
the table.

Fix direction: refresh the rows in view after every action that changes the selection and on
the list's end-of-scroll event, counting from the top row and over the rows actually in view;
make the filtered table's reuse depend on `lastZeitFileSelect` too.

**Fixed in `ca918d3`** for the rows in view, which settles decision 7. A row's mark is the
«S» or «_» in its first column.

- **The refresh** (`UIupdateReviewLVinView()` :95405-95428) works on the table that is
  shown, the filtered one too. It starts at the top row and covers the rows the list reports
  as in view (LVM_GETCOUNTPERPAGE) and one more, for a row cut by the lower edge. It writes
  a mark only where the mark differs, and it leaves when this panel is not the open one.
- **It runs at four more moments**: when the list reports the end of a scroll or a pressed
  key (:95538), after «Deselect all in index» (the menu item calls
  `BTNreviewDropAllSelection()` :95186), after «Select files in index in same folder»
  (:95244), and when a filtered table is shown again for the same text (:95644). The table
  filled the first time is still reused; its rows in view are refreshed.
- **«Select» and «Deselect»** rewrite the mark of a row whose flag did not change
  (:95461).

Run, with the list resized to 21 rows in view: 40 files, «Deselect all in index»: rows 1 to
22 show «_» at once, and all 40 after a scroll to the end. Opening the context menu
refreshes the top row too. 400 files deselected from outside the panel, row 200 scrolled
into view: the 11 rows from the top row on show «_», the three above and the three below
still «S»; a key refreshes the rows in view the same way. «Select files in index in same
folder»: the row of the file it deselected shows «_». Filter `\A\`, erase it, deselect
three of those files, apply `\A\` again: the three rows show «_». The context menu opened
on a filtered table refreshes it. Every file deselected in the index, then «Deselect» on
three rows: they show «_».

Left as it is, by decision 7: a row that was never in view keeps its old mark until it is
scrolled to, so a click on the «S» header sorts by marks that may be old. «Refresh» (F5)
rewrites them all. The whole column is not rewritten after each action because of its cost:
on 60 000 rows under Wine, checking it took 3.8 s and rewriting it 11 to 13 s (batch P).

In these runs the scroll and the key were passed to the list's handler by hand. That
Windows reports each of them to the handler was not seen; the paging relies on the same two
events.

---

## 8. «None» and «Deselect listed items in index» can select instead

`BTNreviewDropFilesSelection()` :95159-95163

```ahk
modus := markedSelectFile ? 0 : 1
If listViewReviewFilteru
{
   LV_GetText(thisFileIndex, RowNumber + 1, 4)
   modus := resultedFilesList[thisFileIndex, 2] ? 0 : 1
}
```

The action is a toggle. With any text in the filter box, the first listed row decides the
direction, whether or not that text was applied.

- **The menu item selects.** A filter is applied and the first listed file is not selected:
  «Deselect listed items in index» selects every listed file. Run: 9 files selected before,
  12 after.
- **Text typed but not applied.** The full table is shown, «zz» is in the box, the first row
  was deselected: «None» selects every listed file (run).
- **Nothing selected in the index**: «None» selects every listed file (run). This may be the
  intended toggle; the button's name says otherwise.
- **A partly listed table**: only the listed rows are touched. Run: 400 files selected, 98
  listed, «None»: 302 files stay selected, and a second press changes nothing, because the
  counter is not zero.

Decision 3.

**Fixed in `643541d`**, which settles decision 3 (`BTNreviewDropFilesSelection()`
:95162-95184). «None» and «Deselect listed items in index» always deselect. The table
that is shown decides what: the rows of the filtered table, or, for the full table, every
file the panel was opened with, the pages not listed yet included. The text in the filter
box is not looked at.

Run, the same cases. The menu item on a filtered table whose first file is not selected: 9
files selected before, 6 after, none of them among the six listed. «zz» typed and not
applied, 6 files selected: «None» leaves none selected. Nothing selected in the index:
«None» selects nothing. 400 files selected, 91 listed: «None» leaves none selected.

---

## 9. With 26 or more rows in view, the rest of a long table can never be listed

`uiLVreviewSelFilesResponder()` :95503

```ahk
If (whichLV="LViewOthers" && (topIndex>totalListed - 25) && totalIndex>LVitemsPerPage && isInputOkay=1 && …
```

Scrolled to the very end, the top row is `totalListed - rows in view + 1`. The test asks for
a top row above `totalListed - 25`, which no list of 26 or more rows can reach. The list has
`uLVr` rows (:28108): 27 from «Additional list view rows» = 9, and 26 at 15 with large fonts.

Run, with the list control resized: 21 rows in view, the next page loads; 29 rows in view, top
row 74 of 102, the test wants more than 77, nothing loads. The info line stays at «Entries
listed: 102 / 400 (25.50%)».

It matters only for selections larger than one page.

Fix direction: ask the list for its rows per page (LVM_GETCOUNTPERPAGE, 0x1028) and test
`topIndex + rowsInView > totalListed - 5`.

**Fixed in `f6f9fb2`** by the fix direction, with a margin of 8 rows instead of 5 (:95546,
:95549): `topIndex + rowsInView + 8>totalListed`. With 17 rows in view the test passes at
the same top row as before. Run, with the list control resized: 21 rows in view, the next
page loads; 29 rows in view, top row 70 of 98, the next page loads too (204 rows listed).

---

## 10. A listing the user stopped

`uiPopulateReviewSelectedFiles()` :95631-95635. `abandonAll := 1` is set and never read.

- **No notice.** The info line reads as after a page, «Entries listed: 1 499 / 3 000
  (49.97%)», or as a finished filter, «Filtered table: 999 / 3 000 (33.30%)» (run).
- **The full table cannot be resumed** when the selection is smaller than a page: the scroll
  test at :95503 also asks for `totalIndex>LVitemsPerPage`. Run: 3000 files, stopped at the
  1500th; scrolling to the end adds nothing.
- **`LVitemsPerPage` only grows.** Each page break sets it to the number of rows that fitted
  in 3.5 s (:95686-95689; run: 5100, then 12 839, then 13 279) and it keeps that value until
  QPV closes. So the case above widens with use.
- **A stopped filter is remembered as the result.** `lastSearch` is stored after the loop
  whether or not it finished (:95716). Applying the same text again shows the partial table
  at once (run: 999 of 3000, twice). Another text that matches the same files lists all 3000.

Fix direction: on a stop, leave `lastSearch` empty and say «Listing stopped» in the info line;
let the scroll test pass whenever `reviewSelectedIndexes[1, 2]` is not 2.

---

## 11. «X» pressed while a filter is being listed puts the filtered rows into the full table

`uiPopulateReviewSelectedFiles()` :95629-95691, `UIstringEditFilterErase()` :95479-95484

A filter is listed from a timer, and that thread can be interrupted until its first progress
message at 1.5 s (`showTOOLtip()` turns Critical on). «X» starts a second call 250 ms later.
That call shows the full table and makes it the window's current list view (:95585). The
interrupted loop goes on, and its `LV_Add()` calls now land in the full table.

Run: 60 000 selected files, a filter that matches 33 000 of them, «X» 124 ms into the
listing. The full table grew from 60 000 to 92 018 rows, the filtered table stopped at 982,
and the info line reads «Filtered table: 92 018 / 60 000 (153.36%)» over an empty filter box.

The second call starts 250 ms after the click, so the listing must still be running then and
be less than 1.5 s old. That takes tens of thousands of selected files. «Apply» with fewer
than two characters in the box takes the same path.

«Refresh» (F5) during such a listing leaves the interrupted loop adding rows to the new
panel. A «Select», «Deselect» or «None» loop interrupted the same way goes on over the other
table (second read; both read, not run).

Fix direction: turn Critical on for the whole listing, as the first listing has it, or name
the list view before every `LV_Add()` and leave the loop when the other table became visible.

---

## 12. Network paths lose their leading `\\`

`zPlitPath()` :59889-59910. In its fast mode it rebuilds the folder from the pieces between
backslashes and skips the empty ones, which are the two that open a `\\server\share` path.

The panel uses that mode for the «Folder path» column (:95668), for «Copy folder path(s) as
text» and both «containing folders (Explorer)» actions (:95325), and for «Folder properties»
(:95248).

**How such a path gets into the index** (second read): folder scans and list files admit
drive-letter paths only (`RegExFilesPattern` :116, `requireDriveLetter` :88748). «Search and
replace» in the index can write one, and `repairPathSeparators()` keeps its `\\` on purpose
(:97224). So the finding concerns that route, or a build with `requireDriveLetter` set to 0.
A network share mapped to a drive letter is not affected.

Run, with `\\srv\share\dir\u1.png` in the list:

- the column shows `srv\share\dir`;
- «Copy folder path(s) as text» copies `srv\share\dir`;
- «Cut containing folders (Explorer)» puts `srv\share\dir` on the clipboard as a folder to
  paste;
- «Folder properties» is asked for `srv\share\dir`, and answers «The folder seems to no
  longer exist»;
- «Open folder in Explorer» fails on it and says nothing: `OpenThisFileFolder()` shows its
  error only when no panel is open (:2810) (read).

«Copy complete path(s)» and «Copy files (Explorer)» keep the path whole.

Fix direction: take the folder as the text before the last backslash, as
`BtnPanelStaticJumpFirst()` does.

Open at `07746da`. One thing changed: a failed «Open folder in Explorer» now shows an error
message while a panel is open (`cc34faf`, finding 19).

---

## 13. `*` is not a wildcard in the filter box

`uiPopulateReviewSelectedFiles()` :95582

```ahk
FilterSimple := (InStr(thisString, "|") || InStr(thisString, "/") || InStr(thisString, ">") || InStr(thisString, "?")) ? 0 : 1
```

A «simple» text is searched as it is. `*` does not make the text leave that route, so it is
looked for as a character, which no path holds. The keywords and folders panels test for it
(:93785, :97753).

Run, five files named IMG_1.png to IMG_5.png and one other:

| Filter text | Rows |
|---|---|
| `IMG` | 5 of 6 |
| `IMG*` | 0 of 6 |
| `IMG_*.png` | 0 of 6 |
| `IMG*\|zzz` | 5 of 6 |
| `IMG_?.png` | 5 of 6 |

Fix direction: add `InStr(thisString, "*")` to the test. `PopulateFileActsHistory()` has the
same line (:94364).

**Fixed in `ef705b0`**: `*` is among the characters the test looks for, through
`varContains()` (:95617). Run, the same files: `IMG*` and `IMG_*.png` list 5 of 6, and the
other three rows of the table are as before. `PopulateFileActsHistory()` has the same new
line (:94381, read).

---

## 14. «Filter table to selected path»: folders that begin the same, and a tick that stays

`BTNreviewFilterLVSelPath()` :95280-95283, `invokePanelReviewSelContextMenu()` :93566-93568

- **The folder path is searched anywhere in the full path** (:95649). Run: the action on a
  `pv\A` row also lists `pv\A2\x1.png`. It lists `pv\A\sub\s1.png` too; subfolders may be
  wanted (decision 5), a neighbour folder is not. A file at a drive root gives `C:` as its
  folder, which matches the whole drive (second read, read).
- **The item is drawn as a tick box** (`Add/UnCheck`), and is ticked when the box's text
  occurs in the focused row's folder (run: «(checked)»). Choosing it again applies the same
  filter; nothing unticks it (read). Any typed text that occurs in the folder ticks it too.
- **Private mode**: the rows show `*:\****\***\`, and the action writes the real folder into
  the filter box (run).

Fix direction: put `OutDir "\"` in the box; when the item is ticked, make it erase the
filter; in private mode, do not offer it or mask the box.

**Partly fixed in `ef705b0`**, by the first two parts of the fix direction.

- **The box gets the folder with a closing backslash** (:95297). Run: the action on a `pv\A`
  row lists a1, a2 and `pv\A\sub\s1.png`, and no longer `pv\A2\x1.png`. Subfolders are still
  listed (decision 5). On a file at a drive root the box gets `Q:\`, which lists the whole
  drive (run).
- **The tick**: the item is ticked only when the box holds exactly the focused row's folder
  (:93583), and choosing it then erases the filter (run: the full table is back).
- **Private mode** is as it was: the real folder is written into the filter box (run).

---

## 15. «Open image with an external app» removes the `|` from the list's source name

`InvokeOpenWithMenu()` :3026

```ahk
CurrentSLD := Trimmer(StrReplace(CurrentSLD, "|"))
```

`CurrentSLD` is the super-global, not a copy, and the line is there only for the comparison
at :3046. The `|` carries meaning in two kinds of list:

- **A folder opened without its subfolders** is `|C:\folder`. Without the `|`,
  `defineFilesListType()` (:11708) says «FOLDER RECURSIVELY», the «See all» item is ticked
  (:72541), and `invertCurrentFolderRecursiveness()` (:4139) reads the list as recursive.
- **A seen-images list** is `\QPV\viewed-images-history|…`. Without the `|`,
  `cleanDeadFilesList()` no longer recognises it (:35336) and skips the purge of the
  seen-images records.

Run: `CurrentSLD` was `|…\pv\A` before the action and `…\pv\A` after.

The same line runs for the «O» key's menu (`OpenThisFileMenu()` :2898), so the defect is not
the panel's alone.

Fix direction: compare against a local copy.

**Fixed in `ef705b0`** by the fix direction (:3029, :3049). Run: `CurrentSLD` is `|…\pv\A`
before the action and after it.

---

## 16. «Modify index entry»: three answers close the panel for good

`PanelUpdateThisFileIndex()` :41906, :41909, :41929

The panel is closed before the prompt and comes back through the timer at :41960. Three
exits leave before that line:

- «Update entry» with the path left as it is (run: no panel afterwards);
- «Update entry» with the path emptied, which erases the entry (run: no panel afterwards);
- «Cancel» at the unsaved-image question (read).

«Cancel» in the prompt and «Erase entry» bring the panel back (both run), so erasing an entry
has two outcomes, and so has leaving it alone. «Browse file» does not bring it back either;
that one is written so (`preventer`, :41950).

**Fixed in `16b35ff` and `b302cc9`.** Opened from the panel, the prompt now brings the panel
back after each of the three answers (all run):

- **«Update entry» with the path emptied** no longer erases the entry (`16b35ff`, :41940):
  the five entries stay. So an entry is erased from the panel by «Erase entry» alone.
- **«Update entry» with the path as it is** (`b302cc9`, :41911).
- **«Cancel» at the unsaved-image question** (`b302cc9`, :41918): the entry keeps its path.
  The unsaved image was simulated for this run, by setting its variables while the prompt
  was up. At `7f0e8cf` the same run ended with no panel.

---

## 17. A copy the user stopped is announced as done; equal file names are merged

`BTNreviewCopyPanel()` :95304-95308, :95329-95336

- **Stopped copy.** `abandonAll := 1` is never read. Run: six rows, stopped at the third: two
  paths reach the clipboard and the message reads «2 selected complete paths copied to
  clipboard as text». «Select» and «Deselect» stop the same way, with no message.
- **«Copy file name(s) as text»** drops names it has seen, without regard to case. Run: six
  rows, among them `pv\A\IMG_1.png`, `pv\B\IMG_1.png` and `pv\B\img_1.PNG`: four names are
  copied and the message counts four. For folders that is the point; for names it may not be
  (decision 4).

**Partly fixed in `cc34faf`.** A copy the user stops now says «WARNING: User abandoned the
operation. Nothing was copied to the clipboard», and nothing reaches the clipboard (:95366).
Run: six rows, stopped at the third.

Left:

- **A stopped «Select» or «Deselect»** still says nothing (run).
- **«Copy file name(s) as text»** still gives each name once (run: four names for the six
  rows). `07746da` takes the count in the message from the lines of the copied text
  (:95373); that is the same number as before. Decision 4.

---

## 18. Every changed row runs the list's event handler

Both list views are `AltSubmit` with `uiLVreviewSelFilesResponder()` as their handler. Each
row whose text or highlight changes posts one event, and the handler runs about ten lines,
five of them calls to the list view, before it finds it has nothing to do (:95494-95511,
return at :95536).

Run, 60 000 rows, Wine's timings:

| Action | Time | Handler calls |
|---|---|---|
| Ctrl+A | 21.8 s | 60 000 |
| «Deselect» on all rows | 15.8 s, then 10.6 s more before the panel answers | 60 000 |

Windows will be faster, and it caps a queue at 10 000 posted messages, so a burst cannot run
the handler more often than that. After its first 1.5 s the «Select»/«Deselect» loop is
Critical, and the events wait in the queue up to that cap. That is the state that stalled the
keywords panel (d8a4a6f). No positive `Sleep` runs in this loop today, so here it is a
slowdown, not a stall.

Fix direction: make the handler's first line return for every event but `DoubleClick`, `K`,
`S` and `s`.

**Fixed in `ef705b0` and `16b35ff`.** The handler returns for every event but `DoubleClick`,
`K`, `S`, `s` and `RightClick` (:95523). `ef705b0` put that return on the fifth line, after
three GUI commands; `16b35ff` moved it to the second, after `Gui, Default` alone.

Run, 60 000 rows, the revisions in turns, Wine's timings:

| Action | c5a32d3 | `ef705b0` | `7f0e8cf` |
|---|---|---|---|
| Ctrl+A | 21.2 s, 21.6 s | 12.1 s, 12.4 s, 12.3 s | 11.9 s, 11.9 s |
| «Deselect» on all rows | 15.9 s, 15.6 s | 15.1 s, 15.0 s, 15.2 s | 15.4 s, 15.2 s |
| the wait after «Deselect», before the panel answers | 10.6 s, 10.6 s | 1.9 s, 1.9 s, 1.8 s | 1.5 s, 1.4 s |

The handler is still entered once for each changed row, 60 000 times in every run. Little
is left to gain from it. Run, Ctrl+A alone on the 60 000 rows of `7f0e8cf`, three passes
each:

| The handler | Ctrl+A |
|---|---|
| as it is at `7f0e8cf` | 12.2 s, 11.9 s, 11.7 s |
| with the event test on its very first line | 11.6 s, 11.6 s, 11.5 s |
| none: the list views get no handler | 10.2 s, 10.1 s, 10.1 s |

So about 10 s are the list view's own work under Wine, and the handler adds under 2 s.
«Deselect» took the same 15 s on all three revisions: that time is not spent in the handler.
The commits after `7f0e8cf` did not touch this part of the handler.

---

## 19. Small things

- **A tooltip stays.** Scrolling to the end of a partly listed table shows «List view will
  further be populated» (:95506). If the panel is closed in the next 0.6 s, the listing
  leaves at :95572, before the line that removes the tooltip. Run: still on screen 2.5 s
  after the panel closed.
- **Scrolling applies an unapplied filter.** The next page is requested through the same
  function that reads the filter box. Run: «IMG_3» typed and not applied, a scroll to the end
  of a partly listed table: the filtered table appears.
- **Memory.** `reviewSelectedIndexes` is emptied by the «Close» button alone. Escape, the
  title bar's X, a double-click, F2, F3 and «Open folder now» leave it filled until the next
  opening (run: 2000 entries kept).
- **Two items on Alt+L** in the context menu: «Deselect &listed items in index» and «Filter
  files &list to selected path».
- **«Select» and «Deselect» with no highlighted row** do nothing and say nothing (run).
- **Filter text `a|||b`** matches every file (run): one `||` becomes `|`, and the remaining
  empty alternative matches anything.
- **Up and Down change a number typed in the filter box** (second read, run): «0042» becomes
  «43». The panels' numeric edit fields answer to the arrow keys (:649-661, :842-859), and
  only names that begin with `editF` are left out.
- **A `\>` filter retyped in another letter case shows the earlier table** (second read,
  run). `thisSearch=lastSearch` compares without regard to case; the expression does not.
  `\>IMG_1` lists one file, and `\>img_1` right after it lists the same one, where it
  matches none.
- **«Open folder in Explorer» says nothing when it fails** while a panel is open (:2810,
  read).
- **A listing goes on after the panel is closed.** Its loop runs to the end with nowhere to
  add rows, and closing the panel has cleared the busy state, so it can no longer be stopped
  (second read, read).

**Partly fixed in `cc34faf`**: four of the ten points.

- **The tooltip** is removed one second after it comes up (:95537). Run: none on screen
  2.5 s after the panel closed.
- **Memory.** `CloseWindow()` empties `reviewSelectedIndexes` for this panel (:98043), so
  every way of closing does it. Run: no entries kept after Escape and after «Close». The
  «Close» button now calls `BtnCloseWindow()`; `BtnReviewSelClose()` is gone.
- **«Open folder in Explorer» that fails** while a panel is open shows «ERROR: An unknown
  error occurred opening the folder» (:2812). Run: a row whose folder is on a drive that
  does not exist.
- **A listing stops once the panel is closed** (:95665, :95727). Run: 30 000 selected files,
  a filter being listed, the panel closed 0.3 s in: the listing returns 0.1 s later, with
  the busy state cleared. At `b302cc9` it went on for 0.5 s. It does not stop when a panel
  is open again by then, as after F5 (finding 11, read).

Left as they were: scrolling applies an unapplied filter, the two items on Alt+L, «Select»
and «Deselect» with no highlighted row, the `a|||b` filter, a typed number changed by Up and
Down, and a `\>` filter retyped in another case (all six run again).

---

## New with the fixes

What the commits changed besides the fixes. One narrow point is open at `07746da`; five
others came with one commit and were put right by a later one.

### Open: F3 closes the panel when the unsaved-image question stopped it

`BTNreviewFilterListSelPath()` :95226

```ahk
rr := BTNreviewSelFilesInPath("filter")
If (maxFilesIndex>0 && filesFilter && rr!=-1)
   BtnCloseWindow()
```

`rr` is -1 only when no row is focused (:95239). `activateFilesListFilterBasedOnFolder()`
also leaves without filtering when the question «Would you like to save the current image?»
is answered «Save» or «Cancel» (:2686), and it returns nothing then. If a files-list filter
was already on, the test passes and the panel closes.

Run: the list filtered to `pv\B`, an edited, unsaved image simulated in the viewport, F3 on
a row, «Cancel» at the question: the panel closes and the list is as it was. With no filter
on, the panel stays (run). «Save» takes the same path (read).

It needs an unsaved image and a filter already on, and nothing is lost.

Fix direction: let `activateFilesListFilterBasedOnFolder()` return 1 once it has applied the
filter, pass that on, and close the panel on it.

### Put right

- **The menu's F3 item closed the panel when it did nothing**: no focused row, a files-list
  filter already on (`16b35ff`; `b302cc9` made it independent of the viewport's file).
  `cc34faf` reads the -1. Run: the panel stays, with the viewport on the first file and on
  the second.
- **F3 left the panel open over the filtered list** (`16b35ff`): its rows kept the numbers
  of the unfiltered list, and «Deselect» acted on other files. `b302cc9` closes the panel
  (finding 2; run on both).
- **«Open containing folder in QPV» was always offered in the «O» key's menu** (`16b35ff`,
  which dropped the line that fills `OutDir`). `b302cc9` put the line back (:3028). Run: with
  the list's source being the image's own folder, the item is not offered.
- **F1 and F5 with no focused row** did nothing at `ef705b0`; `7f0e8cf` restored them
  (finding 1; run).
- **The «Open with» menu for a missing file** did not come up at `ef705b0`, in the panel and
  for the «O» key; `16b35ff` restored it (run).

---

## Seen in passing

**A. Two index entries removed for one missing file.** `DelayiedImageDisplay()` :25853-25855
calls `informUserFileMissing(1)` when `IDshowImage()` answers 0. With «Automatically skip
inexistent files» on, `IDshowImage()` has by then removed the missing entry itself (:89102)
and moved to the next image. `informUserFileMissing()` then reports the new current file as
«File not found» and, with auto-remove on, removes it as well (:32745). Run: six entries, one
missing, both options on: four entries left, and the message names the healthy `d3.png`. The
same happens on any direct jump to a missing file, not only from this panel. On an .SLDB
list `remCurrentEntry()` also deletes the healthy file's database record (:33850, read).

Open at `07746da`. The panel's «Open» actions no longer lead to it (finding 4). A jump with
no panel open still removes two entries, and so does a double-click on the missing file's
row, which closes the panel first (both run: six entries, four left, the message names
`d3.png`).

**B.** `PopulateFileActsHistory()` :94364 has finding 13's line. **Fixed in `ef705b0`**
(:94381, read).

## Checked and found correct

- **Enter in the filter box** presses «Apply». **Enter on the list** is kept from the Default
  button (`decideBlockKbdKeys()` answers 1, run), so it does one thing only.
- **«Copy complete path(s) as text»** is the one menu item wired straight to
  `BTNreviewCopyPanel()`. The item's name and position arrive as `modus` and `extras`, match
  nothing, and the complete paths are copied (run).
- **`dropFilesSelection()` from the menu** got the item's name as `silentMode`, which is not
  1, so it behaved as the loud form. Since `ca918d3` the menu item calls it through
  `BTNreviewDropAllSelection()`, with no argument: the loud form again.
- **The counter stays in step with the flags** in «Select» and «Deselect»: the rows' flags
  are 0 or 1, never blank, so `oSel=sel` compares numbers (run after every action).
- **One file left selected**: «Refresh» then says «There are no selected files to review»
  and the panel does not come back. That is the one-file rule.
- **A filter looks at every selected file**, also at those not yet listed in the full table
  (run: 111 matches of 400 with 98 listed).
- **Paging itself**: 60 000 files came in five pages (run).
- **A broken regular expression after `\>`** gives an empty table and no error box (run).
- **The busy state is always cleared.** The two returns in `BTNreviewCopyPanel()` that skip
  `ResetImgLoadStatus()` need a copy with no highlighted row, and the «Copy» submenu exists
  only with one. Both flags read 0 after every copy (run).
- **`LV_Add(A_Index, …)`** is a plain add; the number is not an option.
- **No division by zero** in the info lines: the panel opens with two files or more.
- **`lastOtherWinClose`** in `BtnReviewPaneOpenActs()` is a super-global (:142), so the
  assignment at :95258 is live.
- **The panel's menu actions are not offered by the quick-search palette**:
  `buildQuickSearchMenus()` does not run this menu's builder.
- **`BTNreviewLVselAll()`** is shared with the folders panel and picks the right list by
  `AnyWindowOpen`.

## Decisions to make before fixing

Decisions 1, 2, 3 and 7 are settled by the commits; in 5 the code kept what it did. The
others are open.

1. F3: should it keep the user's selection, and filter the list by the folder path alone?
   **Settled in `16b35ff`**: yes to both.
2. The «Open» actions: should they move the viewport to the row's file? If not, F6 and the
   menu need the row's path, and finding 4 goes away with it. **Settled in `ef705b0`**: they
   do not move it.
3. «None»: a toggle, or always «deselect»? The listed rows only, or every file the panel was
   opened with? Should the filter box's text count before it is applied?
   **Settled in `643541d`**: always «deselect»; the files of the table that is shown, which
   for the full table is every file the panel was opened with; the text does not count.
4. «Copy file name(s) as text»: one line per file, or each name once?
5. «Filter table to selected path»: the folder alone, or its subfolders too? At `07746da`
   the subfolders are listed. F3, on the files list, takes the folder alone.
6. A stopped listing: a line in the info text and a way to go on, or leave it to «Refresh»?
7. Finding 7: is a refresh of the rows in view enough, or should the «S» column be rewritten
   for the whole table after each action? The second is slow on large selections unless
   finding 18 is fixed first.
   **Settled in `ca918d3`**: the rows in view. With finding 18 fixed, the whole column still
   takes 11 to 13 s on 60 000 rows under Wine.
8. «Seen in passing» A is outside the panel. Fix it with this work or apart?

Suggested order for what is left: 10 and 12; then 11; then what is left of 14, 17 and 19,
and the open point under «New with the fixes».

## How this was checked

- Static reading of `development` at 5af5eff: the panel's functions, the menu builder, the
  key and right-click routing, and each helper before a call to it was judged.
- The real application under headless Wine, started on one image, with a test function
  appended to a scratch copy of the script. The copy differs from the source in three ways:
  popup menus, clipboard writes and the Explorer and new-instance launches write a log line
  instead; `msgBeepTimer()` and `addJournalEntry()` log their text; the list's handler
  counts its calls.
- Ten batches, about 25 s each. Batches A and B gave the same log on AutoHotkey_H
  1.1.33.10 and on stock AutoHotkey 1.1.37.02.
- Two independent reads of the same code, made without the findings above. Batch J ran the
  points they added.
- The fix commits, on 2026-11-10: each diff was read against every finding. Batches A to J
  were run again on `ef705b0`, on `7f0e8cf`, on `b302cc9` and on `07746da`, and each log was
  compared with the one before it.
- Four batches were added for the fixes, each run on the revision before a fix and on the
  one after it. Batch K: F1, F5 and the menu's F3 item with no focused row, F3 on a row alone
  in its folder, «Modify index entry» and the «Open with» menus on a missing file, a jump to
  a missing file with no panel open, and «Filter table to selected path» chosen twice. Batch
  L: F3 with the viewport on three different files, the selection before and after the
  filter is removed, the panel's actions if F3 leaves it open, the menu's F3 item with a
  files-list filter already on, and the «O» key's menu on a list that is the image's own
  folder. Batch N: «Cancel» at the unsaved-image question, the menu's F3 item with a filter
  on and the viewport on the first file, and F3 on a row of an already filtered list. Batch
  O: F3 with «Cancel» at the unsaved-image question, with and without a filter on, a failed
  «Open folder in Explorer» through the real function, and the panel closed while a filter
  is being listed.
- The fixes of findings 7, 8 and 9: batches A to D, F to L, N and O were run again on
  `ca918d3`, and each log was compared with the one of `07746da`. Apart from page sizes,
  which depend on timing, they differ in the lines of these three findings alone. Batch G
  was also run on `f6f9fb2`, and batch B on `643541d`. Two batches were added. Batch P
  times the «S» column of 60 000 rows: checked, rewritten, and rewritten while the list
  reports no item changes to its handler (AltSubmit off). Batch Q: «Deselect all in index»
  followed by a scroll, a selection changed from outside the panel followed by a scroll and
  by a key, «Select files in index in same folder», a filtered table shown again, and the
  context menu on a filtered table.
- Batch N's first case depends on timing. After «Modify index entry» the viewport is
  redrawn about 0.2 s later in some runs and about 0.6 s later in others, on `07746da` as
  on `ca918d3` (batch R traces it). The case sets up its unsaved image at 0.75 s, where it
  used 0.45 s.
- Batch E, the 60 000 rows, ran several times on c5a32d3, `ef705b0` and `7f0e8cf`, in turns;
  the later commits did not touch that part of the handler.
  Batch M times Ctrl+A alone; `QPV_RESP_VARIANT=first` or `none` moves the handler's event
  test to its first line, or leaves the list views without a handler, in the scratch copy.
- Three aids, each named where it was used:
  - the 3.5 s page limit shortened to 30 ms in the scratch copy, for the paging runs
    (findings 8, 9, 10 and 19);
  - a stop simulated by making the Nth call of `determineTerminateOperation()` answer 1,
    which is what it answers once the user confirms the prompt (findings 10 and 17);
  - the list control resized to bring 21 and 29 rows into view (findings 7 and 9), because
    Wine's rows are taller than Windows's.
- Not run on Windows. Three things rest on how Windows behaves. Two were only seen under
  Wine: a fresh list view has no focused row (finding 1), and the timings of findings 7 and
  18. One was not seen at all: that the list reports the end of every scroll and every key
  to its handler, which the fix of finding 7 relies on.
- Not checked: the panel on an .SLDB list, on a duplicates list (the «Dupe ID» column), and
  with an edited, unsaved image in the viewport.
- Kit: `.claude/scratch/review-selected-panel-2026-11-09/app/`: `run-app.sh <tag> <test
  function> [revision]`, `patch.py`, `test-wrappers-review.ahk` (testReviewA to
  testReviewR), `results/` (the logs of `ef705b0` end in `-ef7`, those of `7f0e8cf` in
  `-7f0`, those of `b302cc9` in `-885`, after its merge commit 8851855, those of `07746da`
  in `-077`, and those of `ca918d3` in `-fix`).
