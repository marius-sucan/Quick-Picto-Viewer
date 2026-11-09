# «Review selected files» panel audit, 2026-11-09

Scope: `PanelReviewSelectedFiles()` (:95096), the panel it builds, its button actions, its
keys and its context menu, `invokePanelReviewSelContextMenu()` (:93515). That is every
function from :95096 to the end of `uiPopulateReviewSelectedFiles()` (:95723), and the helpers
those functions hand the work to, as far as a panel action reaches them. Line numbers are
`quick-picto-viewer.ahk` on `development` at 5af5eff. No code was changed.

Nineteen findings. Each one says how it was checked: **run** means the real application did it
under headless Wine, on AutoHotkey_H 1.1.33.10 (the two largest batches also on stock
AutoHotkey 1.1.37.02, with the same log); **read** means it follows from the code and was not
run. Nothing was run on Windows. The test kit is described at the end.

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

| # | Finding | Harm | Checked |
|---|---------|------|---------|
| 1 | With no focused row, the column header «#» is used as the file index: Enter on a freshly opened panel breaks the view | high | run |
| 2 | F3 «Filter files list to selected path» drops the whole selection first, and may then do nothing else | high | run |
| 3 | «Select files in index in same folder» and F3 use the folder of the image in the viewport, not the row's | high | run |
| 4 | The «Open» actions and F6 move the viewport; with auto-remove on, index entries vanish under the open panel and its rows then point at the wrong files | high, needs an option | run |
| 5 | A failed «Modify index entry» leaves the panel on screen while QPV believes no panel is open | medium | run |
| 6 | F6 does nothing | medium | run |
| 7 | The «S» column is not kept in step with the index | medium | run |
| 8 | «None» and «Deselect listed items in index» can select instead | medium | run |
| 9 | With 26 or more rows in view, the rest of a long table can never be listed | medium | run |
| 10 | A listing the user stopped: no notice, no way to resume, and a filter remembers the partial result as final | medium | run |
| 11 | «X» pressed while a filter is being listed puts the filtered rows into the full table | medium, rare | run |
| 12 | Network paths lose their leading `\\` in the folder column, in two copy actions and in «Folder properties» | medium | run |
| 13 | `*` is not a wildcard in the filter box | medium | run |
| 14 | «Filter table to selected path» also lists folders whose name begins the same; its tick never comes off | low | run |
| 15 | «Open image with an external app» removes the `\|` from the list's source name | medium | run |
| 16 | «Modify index entry»: three answers close the panel for good, two bring it back | low | run |
| 17 | A copy the user stopped is announced as done; equal file names are merged | low | run |
| 18 | Every changed row runs the list's event handler | low, large selections | run |
| 19 | Small things: a tooltip that stays, an unapplied filter applied by scrolling, memory kept, two items on the same Alt letter | low | run |

Findings 1, 2 and 3 are the ones a user meets in ordinary use. Finding 4 needs «Automatically
remove index entries pointing to inexistent files» to be on, and a selected file that is
missing from the disk.

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

Enter reaches this code through `decideBlockKbdKeys()` (:666-669), which keeps the key away
from the «Apply» button while the list has the focus, and `externalinvokedSettingsContextMenu()`
(:25909), which calls the responder with `"DoubleClick"`. Both were run.

The folder panels guard the same case in sixteen places: `folderu="folder path"` is the
header text of their column (:35136, :95785, :96057 and others). This panel has no such test.
AutoHotkey's ListView page says of the focused row «sometimes there is none at all», and its
example tests for it (`if not FocusedRowNumber  ; No row is focused.`).

Fix direction: return when `RowNumber` is 0 in the four functions.

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

Fix direction: give the «Open» actions the row's path instead of changing `currentFileIndex`,
or rebuild the panel whenever `maxFilesIndex` changed since it was filled.

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

«Refresh» and «Close» still work and put things right.

Fix direction: when the prompt is scheduled again, pass `"reviewer"` to it and do not arm the
panel's timer.

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

«Refresh» (F5) rebuilds the panel from the index, and loses the filter text and the place in
the table.

Fix direction: refresh the rows in view after every action that changes the selection and on
the list's end-of-scroll event, counting from the top row and over the rows actually in view;
make the filtered table's reuse depend on `lastZeitFileSelect` too.

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

Fix direction: turn Critical on for the whole listing, as the first listing has it, or name
the list view before every `LV_Add()` and leave the loop when the other table became visible.

---

## 12. Network paths lose their leading `\\`

`zPlitPath()` :59889-59910. In its fast mode it rebuilds the folder from the pieces between
backslashes and skips the empty ones, which are the two that open a `\\server\share` path.

The panel uses that mode for the «Folder path» column (:95668), for «Copy folder path(s) as
text» and both «containing folders (Explorer)» actions (:95325), and for «Folder properties»
(:95248).

Run, with `\\srv\share\dir\u1.png` in the list:

- the column shows `srv\share\dir`;
- «Copy folder path(s) as text» copies `srv\share\dir`;
- «Cut containing folders (Explorer)» puts `srv\share\dir` on the clipboard as a folder to
  paste;
- «Folder properties» is asked for `srv\share\dir`, and answers «The folder seems to no
  longer exist».

«Copy complete path(s)» and «Copy files (Explorer)» keep the path whole.

Fix direction: take the folder as the text before the last backslash, as
`BtnPanelStaticJumpFirst()` does.

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

---

## 14. «Filter table to selected path»: folders that begin the same, and a tick that stays

`BTNreviewFilterLVSelPath()` :95280-95283, `invokePanelReviewSelContextMenu()` :93566-93568

- **The folder path is searched anywhere in the full path** (:95649). Run: the action on a
  `pv\A` row also lists `pv\A2\x1.png`. It lists `pv\A\sub\s1.png` too; subfolders may be
  wanted (decision 5), a neighbour folder is not.
- **The item is drawn as a tick box** (`Add/UnCheck`), and is ticked when the box's text
  occurs in the focused row's folder (run: «(checked)»). Choosing it again applies the same
  filter; nothing unticks it (read). Any typed text that occurs in the folder ticks it too.
- **Private mode**: the rows show `*:\****\***\`, and the action writes the real folder into
  the filter box (run).

Fix direction: put `OutDir "\"` in the box; when the item is ticked, make it erase the
filter; in private mode, do not offer it or mask the box.

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

---

## 16. «Modify index entry»: three answers close the panel for good

`PanelUpdateThisFileIndex()` :41906, :41909, :41929

The panel is closed before the prompt and comes back through the timer at :41960. Three
exits leave before that line:

- «Update entry» with the path left as it is (run: no panel afterwards);
- «Update entry» with the path emptied, which erases the entry (run: no panel afterwards);
- «Cancel» at the unsaved-image question (read).

«Cancel» in the prompt and «Erase entry» bring the panel back (both run), so erasing an entry
has two outcomes, and so has leaving it alone.

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

---

## Seen in passing

**A. Two index entries removed for one missing file.** `DelayiedImageDisplay()` :25853-25855
calls `informUserFileMissing(1)` when `IDshowImage()` answers 0. With «Automatically skip
inexistent files» on, `IDshowImage()` has by then removed the missing entry itself (:89102)
and moved to the next image. `informUserFileMissing()` then reports the new current file as
«File not found» and, with auto-remove on, removes it as well (:32745). Run: six entries, one
missing, both options on: four entries left, and the message names the healthy `d3.png`. The
same happens on any direct jump to a missing file, not only from this panel.

**B.** `PopulateFileActsHistory()` :94364 has finding 13's line.

## Checked and found correct

- **Enter in the filter box** presses «Apply». **Enter on the list** is kept from the Default
  button (`decideBlockKbdKeys()` answers 1, run), so it does one thing only.
- **«Copy complete path(s) as text»** is the one menu item wired straight to
  `BTNreviewCopyPanel()`. The item's name and position arrive as `modus` and `extras`, match
  nothing, and the complete paths are copied (run).
- **`dropFilesSelection()` from the menu** gets the item's name as `silentMode`, which is not
  1, so it behaves as the loud form.
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

1. F3: should it keep the user's selection, and filter the list by the folder path alone?
2. The «Open» actions: should they move the viewport to the row's file? If not, F6 and the
   menu need the row's path, and finding 4 goes away with it.
3. «None»: a toggle, or always «deselect»? The listed rows only, or every file the panel was
   opened with? Should the filter box's text count before it is applied?
4. «Copy file name(s) as text»: one line per file, or each name once?
5. «Filter table to selected path»: the folder alone, or its subfolders too?
6. A stopped listing: a line in the info text and a way to go on, or leave it to «Refresh»?
7. Finding 7: is a refresh of the rows in view enough, or should the «S» column be rewritten
   for the whole table after each action? The second is slow on large selections unless
   finding 18 is fixed first.
8. «Seen in passing» A is outside the panel. Fix it with this work or apart?

Suggested order: 1, 3, 6 and 13 are one-line fixes; then 2 and 4 with their decisions; then 5,
9, 10, 12, 15; then 7, 8 and 18 together; the rest last.

## How this was checked

- Static reading of `development` at 5af5eff: the panel's functions, the menu builder, the
  key and right-click routing, and each helper before a call to it was judged.
- The real application under headless Wine, started on one image, with a test function
  appended to a scratch copy of the script. The copy differs from the source in three ways:
  popup menus, clipboard writes and the Explorer and new-instance launches write a log line
  instead; `msgBeepTimer()` and `addJournalEntry()` log their text; the list's handler
  counts its calls.
- Eight batches, about 25 s each. Batches A and B gave the same log on AutoHotkey_H
  1.1.33.10 and on stock AutoHotkey 1.1.37.02.
- Three aids, each named where it was used:
  - the 3.5 s page limit shortened to 30 ms in the scratch copy, for the paging runs
    (findings 8, 9, 10 and 19);
  - a stop simulated by making the Nth call of `determineTerminateOperation()` answer 1,
    which is what it answers once the user confirms the prompt (findings 10 and 17);
  - the list control resized to bring 21 and 29 rows into view (finding 9), because Wine's
    rows are taller than Windows's.
- Not run on Windows. Two things rest on how Windows behaves and were only seen under Wine:
  a fresh list view has no focused row (finding 1), and the timings of finding 18.
- Not checked: the panel on an .SLDB list, on a duplicates list (the «Dupe ID» column), and
  with an edited, unsaved image in the viewport.
- Kit: `.claude/scratch/review-selected-panel-2026-11-09/app/`: `run-app.sh <tag> <test
  function>`, `patch.py`, `test-wrappers-review.ahk` (testReviewA to testReviewH),
  `results/`.
