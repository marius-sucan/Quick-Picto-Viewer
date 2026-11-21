# «Move file(s) to...» / «Copy file(s) to...» panel audit, 2026-11-20

Scope: `PanelMoveCopyFiles()` (:60597) and `InvokeCopyFiles()` (:60602), the panel both open, built by
`CopyMovePanelWindow()` (:60608), its field, list, two lists and six buttons, the keys and clicks it
answers, the routes that open it, and everything its buttons run: «Proceed» (`BtnCopyMoveAction()`
:61714, then `QuickMoveFile2Dest()` :61867 and `batchCopyMoveFile()` :62062), «Mark file(s)
(Explorer)» (`BtnMarkFilesExplorer()` :61694, `CopyMoveFilesExplorer()` :3650), «Erase history»
(:61688), «Browse» (:60461), «Help» (:61610), and the helpers they hand the work to as far as a panel
action reaches them (the conflict box, `replaceFileByCopyMove()`, the undo records, the recent
destinations). Line numbers are `quick-picto-viewer.ahk` on `development` at `e6c63fa`. The audit
changed no code.

Fifteen findings and a list of small things. Each one says how it was checked: **run** means the
real application did it under headless Wine, on the stock AutoHotkey 1.1.37.02; **read** means it
follows from the code and was not run. Nothing was run on Windows. The test kit is described at the
end.

Two points of this report were noted in passing, read only, by the structured panel's report
(`structured-copy-move-panel-audit-2026-11-14.md`, its «Seen in passing» A): the Alt+P that two
buttons share and the missing save question. Both are run here (findings 12 and 1). Two items of that
report also concern this panel and are not repeated: 15.5 (the conflict setting is not kept across
restarts, open, decision 8 there) and 15.10 (an empty file at the destination; fixed in `b8d50ba`,
reverted in `9e0b88f` at Marius's request). Nor is the unchecked result of `createSettingsGUI()`
(:60615), which this panel shares with most panels (56 of 74 at `b4f374f`, counted for that report).

**Status, 2026-11-21.** Finding 1 is fixed in `db1cb15`, by Marius, with his answer to decision 1.
Finding 2 is fixed in `db1cb15`, by Marius, and `244b305`, with his answer to decision 2. Findings 4,
5, 6, 7 and 11 are fixed in `5735d4f`, `5ce0fe8`, `58c1f58`, `16745bf` and `a40adb4`, with his
answers to decisions 4 to 7 and 11; `e5713d0` completes the fix of finding 7. The other findings are open.
A fixed section ends with a note on what the code does now; the notes of findings 1 and 2 cite lines
at `244b305`, the others at `a40adb4`, which `e5713d0` leaves in place.

## Terms

- **The panel**: panel 9. «Move file(s) to...» (`PanelMoveCopyFiles()`, the M key) and «Copy file(s)
  to...» (`InvokeCopyFiles()`, the C key) open it with «Action to perform» on «Move file(s)» or «Copy
  file(s)». Its controls, top to bottom: the Destination field and «Browse»; the list «Recent
  destination folders»; «On file name conflicts» and «Erase history»; «Action to perform»; «Proceed»,
  «Mark file(s) (Explorer)», «Help» and «Cancel».
- **Index**: QPV's files list, `resultedFilesList`. **Selected file**: a file marked in the index.
  **One-file rule**: `getSelectedFiles(0, 1)` deselects a selection of exactly one file
  (:39980-39985), so the panel works on the selected files when two or more are selected, and on the
  current file otherwise.
- **Current file**: the index entry QPV points at (`currentFileIndex`): the image shown in image
  view, the focused one in thumbnails view.
- **One-file path** and **batch path**: «Proceed» runs `BtnCopyMoveAction()`, which reads the field
  and calls `QuickMoveFile2Dest()`. That function copies or moves the current file itself when fewer
  than two files are selected (the one-file path, :61876-62040) and otherwise hands the work to
  `batchCopyMoveFile()` (the batch path).
- **Patterns**: the three relative destinations the Help names: `.\` (each file's parent folder),
  `\name` (a folder `name` inside each file's folder) and `.\name` (a folder `name` beside each file's
  folder). **Grouping words**: `[group-by-month-year]`, `[group-by-years]`, `[group-by-file-types]`.
- **Conflict setting**: «On file name conflicts»: «Skip files», «Auto-rename», «Overwrite», «Ask user»
  (the default).
- **Quick file actions**: the keys 1 to 6 and the folders tree's and the omnibox's «Copy/Move selected
  file(s) into...». `triggerQuickFileAction()` (:47416) runs them through the same handler as
  «Proceed», `BtnCopyMoveAction("quick-actu")`.
- **Database list**: a files list saved as .SLDB and opened from it. It keeps its paths in lower case.
- **Recycled**: sent to the recycle bin. In the runs this is Wine's recycle bin, redirected into the
  kit folder.
- **`<work>`**: the folder in which each test builds its files; short paths in the runs, such as
  `st\src` or `out`, lie inside it. **`<app>`**: the scratch copy's folder, QPV's folder in the runs.

## Summary

| # | Finding | Harm | Checked | Status at `e5713d0` |
|---|---------|------|---------|---------------------|
| 1 | An edited, unsaved image loses its edits when it is moved, without a question | high, narrow | run | **fixed**, `db1cb15` |
| 2 | A «; » in the destination: the text before it is dropped, so an existing folder is refused and a pattern fills another, new folder | medium | run | **fixed**, `db1cb15`, `244b305` |
| 3 | A network path becomes a new folder inside each file's own folder | medium | run | open |
| 4 | A destination that ends in `\..` or `\.`, or a database list's folder in another case of a letter outside A-Z: the files go to the wrong folder, are recycled and replaced by copies of themselves, are renamed in place, or reach the index with a doubled backslash | medium, narrow | run | **fixed**, `5735d4f` |
| 5 | One file and a pattern to a folder that does not exist: «Failed to COPY/MOVE file», where two files get the folder | medium | run | **fixed**, `5ce0fe8` |
| 6 | A copy into the files' own folder: one file is duplicated, also with «Skip files»; two or more are skipped | low | run | **fixed**, `58c1f58` |
| 7 | A pattern or a grouping word is not remembered: the next opening offers one absolute folder, and the messages name one folder for files that went to many | medium | run | **fixed**, `16745bf`, `e5713d0` |
| 8 | A grouping word alone gathers the selected files of every folder under the current file's folder | low, maybe meant so | run | open |
| 9 | «Proceed» creates the destination before the 150 files question; «No» leaves the new folder behind | low | run | open |
| 10 | A drive root is refused, although «Browse» and the list offer one | low | run | open |
| 11 | The list: a click below the rows puts the column title in the field, a double-click there runs «Proceed», and the separator is a row | medium | run | **fixed**, `a40adb4` |
| 12 | «Proceed» and «Help» share Alt+P: from two buttons it presses «Help» | low | run (Wine) | open |
| 13 | «Erase history» erases only the saved destinations: the last destination and the other folders stay, with no question | low | run | open |
| 14 | A rebuilt panel forgets the typed destination and the conflict setting, and «Proceed» comes back enabled on «Choose...» | low | run | open |
| 15 | «Mark file(s) (Explorer)» puts deleted files on the clipboard and counts them | low | run | open |
| 16 | Small things, numbered 16.1 to 16.12 | low | run and read | open |

Finding 1 loses work for good. Findings 2 to 5 and 7 send files to a folder the user did not name,
or fail on a folder the Help promises; the files themselves stay whole. Finding 11 needs nothing more
than a click or a double-click in the empty part of the list. Findings 1, 2, 4 to 7 and 11 are
fixed.

---

## 1. An edited, unsaved image loses its edits when it is moved

`BtnCopyMoveAction()` :61714-61831; the panel closes in `QuickMoveFile2Dest()` :61932 and in
`batchCopyMoveFile()` :62075

Neither the handler nor the two engines call `askAboutFileSave()` (:65778), the question «The
currently modified image is about to be discarded… Would you like to save the current image?». The
structured panel asks it in «Proceed» before the panel closes since `ed8848c`
(`BTNuiProceedStructuredOperation()` :61448).

Run (batch E), an edited image simulated by setting its state (an edited bitmap, five undo levels,
«modified») on `<work>\st\src\imgA.png`, destination `<work>\out`, «Skip files»:

- **Move, the edited file alone** (E1): no question; «File MOVED to | imgA.png»; the image is then
  shown from its new place and the edits are discarded: `terminateIMGediting()` runs while the five
  undo levels are there, and after it there is no edited bitmap, no undo level, and the image counts
  as not modified.
- **Move, the edited file one of two selected** (E3): the same, after «Finished moving 2 out of 2
  files».
- **Copy, the edited file alone** (E2): no question, and the edits are kept.

**Fixed in `db1cb15`** (Marius), with his answer to decision 1: a move is asked, a copy is not.
«Proceed» calls `askAboutFileSave()` after the destination checks, before the folder question,
the conflict box and the engines (:61793 at `244b305`). Run at `db1cb15`, the same three cases:

- **Move, the edited file alone** (E1) and **one of two selected** (E3): «The currently modified
  image is about to be discarded and the files operations will be executed. Would you like to save
  the current image?»; «Cancel» moves nothing, the five undo levels stay, and the panel stays open.
- **Copy, the edited file alone** (E2): no question, and the edits are kept, as before.

«Save» moves nothing either, and `askAboutFileSave()` starts `PanelSaveImg` 150 ms later (read).
A quick file action that moves (Shift and the key) asks too, through the same lines (read). The
question comes whenever an edited image is open, also when it is not among the files to move
(read).

---

## 2. A «; » in the destination: the text before it is dropped

`BtnCopyMoveAction()` :61752-61753, :61766-61767, :61778-61779

```ahk
If (b := InStr(folderu, "; "))
   folderu := SubStr(folderu, b+2)
```

Three places cut the destination at its first «; » and keep what follows. In v3.3.0 (`eba32ba`,
2019) each entry of the destinations list started with its number and «; » (`A_Index - 1 "; "`), and
these lines took the number off again. Since v5.6.5 (`dfe4c8b`, 2022-03-11) the list is a list view
whose rows hold the bare path, so nothing writes a number any more, and the cut now falls inside a
folder name; Windows allows «; » in one.

Run, the folder `<work>\st\Trip; Paris` on the disk, two files of `<work>\st\src` selected, copy:

- **The folder typed in full** (A1): «WARNING: Incorrect file path given: | Paris»; the panel stays
  open and nothing is copied. «Browse» and the rows of the list give the field the same text (read).
- **The pattern `\Trip; Paris`** (A2): «Finished copying 2 out of 2 files to …\st\src\Paris\»: a new
  folder `Paris` inside the files' folder holds the copies. A move sends the files there (read: the
  same lines).
- **The same pattern, one file** (A3): «ERROR: Failed to COPY file: | a.png | Destination: |
  …\Paris\» (finding 5).

Read, not run: the quick file actions pass through the same lines, so a quick-action folder, or a
folder picked in the tree or the omnibox, whose path holds «; » is refused with the text after it.

**Fixed in `db1cb15`** (Marius) **and `244b305`**, with his answer to decision 2: `db1cb15` removes the
cut of the `\name` branch, `244b305` the two others, so the field reaches the tests as typed
(:61733-61774 at `244b305`). Run, batch F on both commits, the folder `<work>\st\Trip; Paris` on the
disk, a copy unless noted:

| Destination | Files | At `db1cb15` | At `244b305` |
|---|---|---|---|
| `<work>\st\Trip; Paris` | two (F1) | «Incorrect file path given: Paris» | copied into `st\Trip; Paris` |
| the same, a move | one (F6) | the same refusal | moved into `st\Trip; Paris` |
| `\Trip; Paris` | two (F2) | copied into a new `st\src\Trip; Paris`; the «Copying» tooltip names `Paris` | the same, and both tooltips name `st\src\Trip; Paris` |
| `\Trip; Paris` | one (F3) | «Failed to COPY file», the destination the bare word `Paris` | «Failed to COPY file», the destination `st\src\Trip; Paris` (finding 5) |
| `.\Trip; Paris` | two (F4) | copied into a new `st\Paris` | copied into `st\Trip; Paris` |
| `.\Trip; Paris` | one (F5) | «Failed to COPY file», the destination `st\Paris` | copied into `st\Trip; Paris` |

At `db1cb15` the bare `Paris` of F3 is a path relative to QPV's working folder (read: a `Paris`
folder there would receive the file). Batch A on `244b305` differs from its run on `db1cb15` only in
A1 to A3, as above, and in A4's recent destinations, which also hold folders saved by the cases
and batches before it (the INI is kept between batches).
The quick file actions pass through the same lines, so a folder whose path holds «; » is taken
as it is (read).

---

## 3. A network path becomes a new folder inside each file's own folder

`BtnCopyMoveAction()` :61735, :61747-61759

```ahk
folderu := RegExReplace(folderu, "\\{2,}", "\")
…
} Else If RegExMatch(folderu, "^(\\.)")
{
   ; move files to a given sub-folder
```

The handler first turns every run of backslashes into one. A network path, `\\nas\archive`, then
reaches the pattern test as `\nas\archive`, which is the pattern `\name` with the name `nas\archive`.

Run (A6), two files of `<work>\st\src` selected, copy to `\\nas\archive`: «Finished copying 2 out of
2 files to …\st\src\nas\archive\»: the folders `nas\archive` are created inside the files' own
folder and hold the copies; no network is asked. A move leaves the files in that new folder (read),
and one file fails as in finding 5 (read).

The structured panel refuses such a path since `c5cbfe4` («ERROR: The destination folder must be a
full path with a drive letter, such as C:\photos», :61443); Marius's decision 4 there: network paths
are not supported in QPV and are refused with a message that says why. Read, not run: «Browse» hands
a network folder to the field whenever `FolderExist()` sees it (the Wine prefix has no share to try).

---

## 4. A destination that ends in `\..` or `\.`, or a folder in another letter case in a database list

`BtnCopyMoveAction()` :61775-61777; the same-folder tests `QuickMoveFile2Dest()` :61909 and
`batchCopyMoveFile()` :62192

```ahk
folderu := StrReplace(folderu, "\\", "\")
folderu := Trimmer(folderu, "\")
folderu := Trimmer(folderu, ".")
…
If (OldOutDir=finalDest || !finalDest)
{
   skippedFiles++
```

The handler trims an ending dot as a character, after it trimmed the ending backslashes; it never
resolves `.` or `..` as folders. `C:\photos\sub\..` becomes `C:\photos\sub\`, the folder the path
leaves, and `C:\photos\.` becomes `C:\photos\` with an ending backslash. The tests for «the same
folder» compare texts, so `C:\photos\` is not `C:\photos`, and each file then meets itself as the
file in the way. A dot inside the path is refused (`filterFileName()` leaves nothing of `.` or `..`,
:61781-61787) (read).

Run, two files selected unless one is named:

| Destination | Action | Result |
|---|---|---|
| `<work>\st\src\new\..`, meaning `<work>\st\src`; one file in each of the two folders (A5-dotdot) | copy, «Skip files» | `a.png` is copied **into `<work>\st\src\new`**; `c.png`, already there, meets itself: «Finished copying 1 out of 2 files to `…\st\src\new\\` … Skipped files: 1». The undo record names `…\new\\a.png` |
| `<work>\st\src\.`, the files' own folder (A5-dot-copy-over) | copy, «Overwrite» | «Finished copying 0 out of 2 files … Failed to perform action on 2 files»; one file: «ERROR: Failed to COPY file». Nothing changes |
| the same (A5-dot-move-over) | move, «Overwrite» | «Finished moving 2 out of 2 files»; the files stay where they were, but the index now names `<work>\st\src\\a.png` with a doubled backslash and QPV answers «ERROR: File not found or access denied» for them. One file: «File MOVED to», then the same error |
| the same (A5-dot-move-rename) | move, «Auto-rename» | «Finished moving 2 out of 2 files»: both renamed in place, `a [1].png` and `b [1].png` |

Why «Overwrite» fails on a copy and moves on a move (read: the runs show the outcomes, the code gives
the cause): the conflict test `FileRexists()` looks through the `\\?\` prefix, where a doubled
backslash names nothing (as the structured report found), so the file in the way counts as absent;
`FileCopy` then copies the file onto itself and fails, `FileMove` moves it onto itself and succeeds.
Windows was not checked.

**A database list** (batch C): the list keeps `…\st\școală\a.png` and `…\st\școală\b.png`, in lower
case; the destination is the folder as the disk spells it, `<work>\st\Școală`, as «Browse» returns
it. AutoHotkey's `=` ignores the case of A-Z only, so the two texts differ (the structured report's
finding 9 is the same comparison). Run, both files selected:

| Action, setting | Result |
|---|---|
| copy, «Overwrite» | «Finished copying 2 out of 2 files»: both files are recycled and replaced by copies of themselves |
| move, «Overwrite» | «Finished moving 2 out of 2 files»: the files are where they were, nothing is recycled, and the index then holds the folder as typed. Wine's shell asked «Confirm file deletion» twice on the way, and the kit's second process answered «No»; without it the run waited for the timeout. By the code, `replaceFileByCopyMove()` moves each file to a temporary name and back to its own (read) |
| copy, «Auto-rename» | «Finished copying 2 out of 2 files»: duplicates `a [1].png` and `b [1].png` beside the files |
| move, «Auto-rename» | «Finished moving 2 out of 2 files»: both renamed in place, `a [1].png` and `b [1].png` |

A folder typed with another case of A-Z letters only is the same folder to that test, as it should be
(read).

Read, not run: other spellings of one folder are other texts too: an 8.3 short name, a link or a
junction, a SUBST drive. The structured panel's finding 1 was this; `88aa9fc` fixed it there by
comparing the folders' file IDs (`getFileIdentity()` :44581).

Run at `e38222f`, before the fix (batch G): the files' own folder reached through a link,
`<app>\linkdir` to `<work>\st\src`, does what the database list does. Copy with «Overwrite»: «Finished
copying 2 out of 2 files», and both originals are recycled and replaced by copies of themselves; copy
with «Auto-rename»: duplicates beside the files; move with «Auto-rename»: both renamed in place. A
quick file action reaches the same lines: `<work>\st\src\.` with «Overwrite», one file, gives «ERROR:
Failed to COPY file».

**Fixed in `5735d4f`**, with Marius's answer to decision 4. «Proceed» resolves a destination that is a full
path with `cleanFolderPath()` (:61793), as the structured panel does: `.` and `..` are read as Windows
reads them, and an ending dot goes. Both engines take a file whose destination is the file itself as a
file in its own folder (:61938, :62249). The new `isSameFile()` (:44612) compares `getFileIdentity()`
of the two paths, read only when a file of that name is at the destination, so any letter case, a
link, a junction, a SUBST drive and a short name count. The structured engine calls it where it had
the same test inline (:3336). What a copy into the own folder then does is decision 6 (finding 6). Run
on the fix (batches A, C, G):

- `<work>\st\src\new\..`, two files, copy: `c.png` is copied into `<work>\st\src`, and `a.png`, already
  there, is skipped.
- `<work>\st\src\.`, two files, copy or move with «Overwrite»: both skipped, and the index keeps its
  paths. One file, copy with «Overwrite» or move: the box «Illegal operation. The destination folder is
  the same with the initial location», and the panel stays open.
- The database list, `<work>\st\Școală`: copy or move with «Overwrite» skips both files, nothing is
  recycled, and the index keeps its paths; copy with «Auto-rename» makes duplicates, as decision 6
  wants; move with «Auto-rename» skips them.
- The link: copy with «Overwrite» skips both files, nothing is recycled; one file with «Skip files» gets
  the box above; copy with «Auto-rename» makes duplicates; move with «Auto-rename» skips them.
- The quick file action with `<work>\st\src\.` and «Overwrite», one file: the tip «WARNING: Illegal
  operation. The destination folder is the same with the initial location».

A junction, a SUBST drive and a short name were not run. The structured engine's copy of the test,
now a call to `isSameFile()`, was run in its own kit (batch M, `run-m.sh`) at `e38222f` and at
`2b2835f`: the same log, with M4's file, reached through a link to its own subfolder, skipped and
nothing recycled.

---

## 5. One file and a pattern to a folder that does not exist: «Failed»

`QuickMoveFile2Dest()` :61921, :61983-61986; `batchCopyMoveFile()` :62158-62167

The batch path creates each file's destination folder for a pattern before it copies or moves
(:62161-62166). The one-file path builds `finalDest "\" name` and calls `FileCopy` or `FileMove`
into it, and creates nothing; only a grouping word gets its folder there
(`determineCreateFileGroupFolder()` :62043, read). The Help offers «a new or existing sub-folder» and
«a new or existing folder within the parent folder» (:61617).

Run, nothing selected, the current file `<work>\st\src\a.png`:

- `\newsub`, copy (A4-sub-one): «ERROR: Failed to COPY file: | a.png | Destination: | …\newsub\»; no
  folder, nothing copied.
- `.\newsib`, move (A4-sib-one): «ERROR: Failed to MOVE file».
- The same two with two files selected (A4-sub-two, A4-sib-two): the folders are created and both
  files copied or moved: «Finished copying 2 out of 2 files».

Run at `e38222f`, before the fix (batch G): a quick file action with `\newquick`, one file, gives the
same «ERROR: Failed to COPY file»; with two files the folder is made.

**Fixed in `5ce0fe8`**, with Marius's answer to decision 5. «Proceed» makes the folder of a pattern for one
file without a question, as the batch path makes the folder of each file (:61824-61840); the quick file
actions take the same lines. It makes none for a current file missing from the disk, which the one-file
path then reports, and only a path with a drive letter is made: `.\` or `.\name` for a file at the root
of a drive (16.11) stops with «An unknown error occurred while creating the folder», and nothing is
created under QPV's folder. Run on the fix (batches A, F, G, H):

- One file, `\newsub` copy, `.\newsib` move, `\Trip; Paris` copy: the folder is made, and the file is
  copied or moved into it («File COPIED to», «File MOVED to»).
- A quick file action with `\newquick`, one file: the folder is made and the file copied.
- The current file deleted from the disk, `\newsub`: «Failed to perform action. File not found or access
  denied», and no `newsub` folder.
- `C:\qpvmc-root.png`, a file at the root of the Wine prefix's drive C:, with `.\` and `.\newsib`: «An
  unknown error occurred while creating the folder: C\», and «…: C\newsib\»; the panel stays open, and
  nothing is created in `<app>` or on C:. At `e38222f` both were «ERROR: Failed to COPY file», after a
  copy aimed at `C\` and at `C\newsib\` under QPV's folder, the working folder.

---

## 6. A copy into the files' own folder: one file is duplicated, two or more are skipped

`QuickMoveFile2Dest()` :61906-61907, :61935-61936; `batchCopyMoveFile()` :62192-62196

```ahk
If (OldOutDir=finalDest && UsrCopyMoveOperation=3 && dummy!="quick-actu")
   mustCreateDupe := 1
…
If (mustCreateDupe=1)
   forceConflictOption := 2
```

Run, copy into `<work>\st\src`, the files' own folder, «Skip files»:

- One file (A9-own-one): «File COPIED to | a [1].png»: a duplicate, although the setting says skip.
- Two files (A9-own-two): «Finished copying 0 out of 2 files … Skipped files: 2».

Read: a move into the own folder is refused both ways (one file: the box «Illegal operation. The
destination folder is the same with the initial location»; several: skipped). The quick file actions
refuse a copy of one file too (:61906, `dummy!="quick-actu"`).

Run at `e38222f`, before the fix (batch G): two files with «Auto-rename» are skipped, and one file with
«Overwrite» is duplicated. A move into the own folder: one file gets the box «Illegal operation…», two
are skipped. A quick file action: a copy of one file is refused with that line as a tip, two are
skipped, and a move of one file is refused.

**Fixed in `58c1f58`**, with Marius's answer to decision 6: a copy from the panel into the files' own folder
follows «On file name conflicts», for one file and several (:61935-61939, :62249-62250, and the
conflict box's answer at :61968 and :62270). «Auto-rename» makes duplicates. «Skip files» and
«Overwrite» skip the files, since a file cannot replace itself: one file gets the box «Illegal
operation. The destination folder is the same with the initial location» while the panel stays open,
several are counted skipped. «Ask user» shows the conflict box, and its «Overwrite» skips too, with the
same warning for one file. A move into the own folder and the quick file actions stay as they were.
Since `5735d4f` the own folder is found in any spelling (finding 4). Run on the fix (batches A, G, H):

- One file, «Skip files» or «Overwrite»: the box, and nothing is copied.
- Two files, «Auto-rename»: `a [1].png` and `b [1].png`. One file: `a [1].png` (batch I).
- «Ask user», one file: the conflict box shows the file against itself; «Overwrite» gives «WARNING:
  Illegal operation. The destination folder is the same with the initial location» and copies nothing,
  «Auto-rename» makes `a [1].png`. Two files: two boxes; «Overwrite» skips both, «Auto-rename» makes
  both duplicates.
- A move, and the quick file actions: as at `e38222f`.

---

## 7. A pattern or a grouping word is not remembered as typed

`batchCopyMoveFile()` :62079-62083; `QuickMoveFile2Dest()` :62001-62006; the field :60696

```ahk
If (dummy!="quick-actu")
{
   prevFileMovePath := finalDest
   RecentCopyMoveManager(finalDest)
}
```

What the next opening puts in the field is `prevFileMovePath`, and both paths store an absolute
folder there: the batch path the folder the pattern gives for the **current** file, the one-file path
the folder it used. The pattern itself is lost.

Run (A4-sub-two): two files copied with `\newsub`; then `prevFileMovePath` is `<work>\st\src\newsub`,
and the panel opened again shows that folder in the field. «Proceed», or Enter, then sends every
selected file into that one folder, where `\newsub` gave each file a folder of its own. The recent
destinations got nothing: `RecentCopyMoveManager()` runs before the copy (:62082), when the folder
does not exist yet, and it keeps only existing folders (:61859) (run: the list is empty after A4).

The messages name one folder for files that go to many (run, A10-group-rel, two files in two folders
with `\[group-by-years]`): the progress tip «Copying 2 files to `…\st\one\[group-by-years]\`», the final
one «Finished copying 2 out of 2 files to `…\st\two\2026\`», the last file's folder. With a grouping
word the batch path stores the word in the path, `…\st\one\[group-by-years]` (read, from the logged
call), and the 150 files question shows the current file's folder (read).

Run at `e38222f`, before the fix (batch G, the recent destinations emptied first): after `\newsub`
with two files the field holds `<work>\st\src\newsub`, and the list got nothing; after `\exist`, an
existing folder, with one file, the field, the INI and the list hold `<work>\st\src\exist`; after
`[group-by-years]` the field holds `<work>\st\one\[group-by-years]`. The 150 files question reads
«Destination: <work>\st\src\newsub\».

**Fixed in `16745bf`**, with Marius's answers to decision 7. «Proceed» keeps what was typed for a pattern or
a grouping word alone (:61756, :61788, :61796-61797), and both engines store it in `prevFileMovePath`
(:62032, :62115) for the session: only a folder goes to the INI and to the recent destinations, since
the INI's loader keeps `X:\…` paths only; the places that read it as a folder want a full path since
`e5713d0` (below). The batch tips and the 150 files question name a pattern as typed, followed by
«(relative to each file's folder)» (:62099); a grouping word alone is named in the folder that gathers
the files. Run on the fix (batches A, F, G, H):

- The field after `\newsub` (two files, and one), `.\newsib`, `.\`, `\exist` and `[group-by-years]`: the
  text as typed; the INI and the recent destinations unchanged. After `<work>\out`: that folder in the
  field, the INI and the list, as before.
- `\[group-by-years]`, two files in two folders: «Copying 2 files to | \[group-by-years] | (relative to
  each file's folder)», then «Finished copying 2 out of 2 files to | \[group-by-years] | (relative to
  each file's folder)». `[group-by-years]` alone: «Finished copying 2 out of 2 files to |
  …\st\one\[group-by-years]\».
- 152 files, `\newsub`: «Destination: \newsub | (relative to each file's folder)».

**Completed in `e5713d0`**, with Marius's answer. `FolderExist()` takes `.\` for QPV's own folder, the
working folder, and `.\name` or `\name` for a folder there when one exists. Run at `2b2835f` (batch I):
after `.\` the Recent menu listed «O2. .\», which opens QPV's folder, and the «Browse» buttons of
both panels started at `.\`; after `.\resources` the panel's list also had a `.\resources` row.
The six places that read `prevFileMovePath` as a folder now want a full path as well,
`InStr(prevFileMovePath, ":\")`, as
`RecentCopyMoveManager()` does: `readRecentFileDesties()` (:60587), the folders tree when no list is
open (:31445), the Recent menu (:72518), the panel's «Browse» (:60470) and the structured panel's two
(:60487, :60506). The file dialogs' «Recent folders» left a pattern out already, by their own test
(read). Run on the fix (batch I): after `.\` and `.\resources`, no «O2.» entry and no row; the panel's
«Browse» passes no start folder, and the structured panel's two start on the last opened folder, with
its Destination field empty, as it opens after a pattern; after `<work>\out`, all of them as before.
The folders tree when no list is open was read, not run.

---

## 8. A grouping word alone gathers every selected file under the current file's folder

`BtnCopyMoveAction()` :61737-61741

```ahk
If (folderu="[group-by-month-year]" || folderu="[group-by-years]" || folderu="[group-by-file-types]")
{
   ; group files by given criteria
   groupingMode := 1
   folderu := OutDir "\" folderu
```

`OutDir` is the current file's folder. Run (A10-group): `a.png` in `<work>\st\one` (the current file)
and `b.png` in `<work>\st\two`, both selected, copy with `[group-by-years]`: both copies land in
`<work>\st\one\2026`. With `\[group-by-years]` (A10-group-rel) each file goes to a year folder in its
own folder. The Help says «Use … as folder name to automatically group files in newly created
folders», right after «The destination folder for every selected file(s) will be calculated relative
to its own location path» (:61617). It may be meant to gather (decision 8).

---

## 9. «Proceed» creates the destination before the 150 files question

`BtnCopyMoveAction()` :61804-61811; `batchCopyMoveFile()` :62067-62073

Run (A11): 152 files selected, move to `<work>\made-new`, which does not exist. «Destination folder
does not seem to exist… Do you want to create the folder?» answered «Yes»: the folder is created;
then «Please confirm you want to MOVE the selected files. Selected: 152 files» answered «No»: the
panel stays open, as it should, and `made-new` stays on the disk, empty. The structured panel had the
same order; Marius's `0ad345c` moved its count question first.

---

## 10. A drive root is refused, although «Browse» and the list offer one

`BtnCopyMoveAction()` :61776, :61792

```ahk
If (!RegExMatch(folderu, "^(.\:\\.)") && !relativePath || wrongNames=1)
{
   msgBeepTimer("WARNING: Incorrect file path given:`n" folderu)
```

The ending backslash is trimmed first, so `C:\` reaches the test as `C:`, and the test wants a
character after `C:\`. Run: `C:\` typed (A7) and `C:\` returned by «Browse» (B4) both give «WARNING:
Incorrect file path given: | C:»; «Browse» put `C:\` in the field without a word. The structured
panel accepts a drive root since `c5cbfe4`. The folders tree's audit met the same refusal for a drive
picked in the tree (`folders-tree-panel-audit-2026-11-18.md`, the end of its finding 8: «what a drive
should accept is part of decision 5»).

---

## 11. The list: clicks that hit no row

`BTNlvRecentFileDesties()` :61597-61608

```ahk
RowNumber := LV_GetNext(0, "F")
LV_GetText(givenName, RowNumber, 1)
GuiControl, SettingsGUIA: , UsrEditFileDestination, % givenName
If (b="DoubleClick")
   BtnCopyMoveAction()
```

The handler takes the focused row, whatever the click hit. A list view sends its click also for a
click below the rows, where no row is hit, and `LV_GetNext()` then gives the row that has the focus.
Under Wine no row has it until one is clicked or reached with a key, and `LV_GetText()` of row 0
reads the column title. Whether the Windows list view gives its first row the focus when it receives
the focus was not checked; there the field would take that row's folder.

Run (B1), clicks posted to the list, the field holding «typed text»:

- **A click below the rows, no row focused yet** (Wine): the field reads «Recent destination
  folders», the column title.
- **A click on row 2**: the field gets row 2's folder (correct).
- **A click below the rows, row 2 focused**: the field gets row 2's folder again, over what was typed.
- **A double-click below the rows**, row 2 focused: «Proceed» runs: «File COPIED to | a.png |
  …\other\», the panel closes, and `a.png` is copied into `<work>\st\other`.
- **The separator «--={ other destinations }=--» is a row**: a click puts it in the field; a
  double-click answers «WARNING: Incorrect file path given: | --={ other destinations }=--».

Checked and fine: the arrow keys fill the field with the row they move to (run, B1g).

Run at `e38222f`, before the fix (batch G, the selected row logged beside the focused one): a click
below the rows leaves no row selected, while the focused row stays, and a right-click below the rows
fills the field as a click does. AutoHotkey passes the focused row with every click (NM_CLICK,
NM_DBLCLK and NM_RCLICK in its `script_gui.cpp`), so the click event cannot tell.

**Fixed in `a40adb4`**, with Marius's answer to decision 11. The list reads the selected row (:61612), which
a click below the rows clears, and does nothing without one; it leaves out the separator row (:61617),
from a click, a double-click, a right-click or the arrow keys. Whether Windows gives the first row the
focus no longer matters. Run on the fix (batches B, G, H):

- A click, a right-click and a double-click below the rows, with and without a focused row: the field
  keeps «typed text», «Proceed» does not run, and nothing is copied.
- A click and a double-click on the separator: the field keeps «typed text», and no «Incorrect file
  path given» warning.
- The arrow keys: each row fills the field, and on the separator the field keeps the folder before it.
- A click on a row fills the field, and a double-click on row 2 runs «Proceed» with its folder.

Windows was not checked; AutoHotkey's documentation gives a selected row of 0 after a double-click on
empty space.

---

## 12. «Proceed» and «Help» share Alt+P

`CopyMovePanelWindow()` :60721, :60723

```ahk
Gui, Add, Button, xs y+20 h%thisBtnHeight% w%btnWid2% Default gBtnCopyMoveAction vBtnCpyMv, &Proceed
Gui, Add, Button, x+5 hp wp+85 gBtnMarkFilesExplorer, &Mark file(s) (Explorer)
Gui, Add, Button, x+5 hp w70 gBtnHelpCopyMovePanel, Hel&p
```

Run (B2), Alt+P posted as key presses to the focused control, the field holding `zz` so that
«Proceed» only warns:

| Focus on | Alt+P pressed |
|---|---|
| the Destination field, «Browse», «Proceed», «Cancel» | «Proceed» («Incorrect file path given: zz») |
| «Mark file(s) (Explorer)», «Help» | «Help» (the help box) |

Wine's dialog manager looks from the focused control onward and presses the first button with the
letter, so under Wine Alt+P never reaches «Help» from the field and never reaches «Proceed» from
«Mark» or «Help». How Windows handles a letter that two buttons share was not checked. The
structured panel's Help is «&Help» (:61410); here H belongs to «Erase &history». The other letters,
B, H, M and A, are unique (read).

---

## 13. «Erase history» erases only the saved destinations, with no question

`EraseCopyMoveHisto()` :61688-61692; the list's sources `readRecentFileDesties()` :60575-60595 and
:60633-60672

```ahk
EraseCopyMoveHisto() {
  IniDelete, % mainRecentsFile, RecentFDestinations
  BtnCloseWindow()
  CopyMovePanelWindow()
}
```

The list is built from the saved recent destinations and from five other sources: the last
destination (`prevFileMovePath`), the last save folder, the last opened folder, ten recently opened
folders and fifteen folders of the current list. The button deletes the first source only.

Run (B3): six rows before, among them two saved destinations. «Erase history»: no question; the
settings section is gone; the rebuilt panel shows the last destination in the field and five of the
six rows, with the last destination first: only the saved destination that no other source named
went away.

---

## 14. A rebuilt panel forgets the typed destination and the conflict setting

`CopyMovePanelWindow()` :60696, :60701, :60721; `changeCopyMoveAction()` :61620-61628

The panel is rebuilt from `prevFileMovePath` and from the conflict setting of the last «Proceed»:
the list has no g-label, so a choice made in it is read only by «Proceed» and «Mark» (:61698,
:61723). Routes that rebuild it:

- **«Erase history»** (run, B3): the field held «typed by the user» and the setting «Overwrite»;
  after, the field shows the last destination and the setting «Skip files», its value before the
  panel opened.
- **«Cancel» in the conflict box** (run, B5): one file, a name conflict in `<work>\out`, «Ask user»;
  the panel comes back, as meant (:61952-61957), with the field on the last destination
  `<work>\st\src`, not on the typed `<work>\out`.
- **«Large UI fonts» and «Dark mode UI»** in the panel's right-click menu (read: `ToggleLargeUIfonts()`
  :74093 closes the panel and calls `openPreviousPanel("forced")`, :74120; the dark mode, :74175).

**«Proceed» comes back enabled on «Choose...».** `changeCopyMoveAction()` disables «Proceed» on
«Choose...» (:61626-61627), but the panel creates it enabled whatever the action (:60721). Run (B3b,
B3c): «Choose...» picked, «Proceed» disabled; after «Erase history», and after F8
(`openPreviousPanel()` :27624), the list still shows «Choose...» and «Proceed» is enabled; a click
says «Please choose an action to perform: copy or move». The structured panel had this; `3e985a2`
fixed it there (its 15.3).

---

## 15. «Mark file(s) (Explorer)» puts deleted files on the clipboard and counts them

`CopyMoveFilesExplorer()` :3670-3685

```ahk
imgPath := StrReplace(resultedFilesList[A_Index, 1], "||")
If (StrLen(imgPath)<4)
   Continue
…
countTFilez++
newFilesList[countTFilez] := imgPath
```

The `||` that marks a deleted file's entry is taken off, and the path joins the list. Run (B6): three
files selected, one of them deleted from the disk and its entry marked `||`; «Action to perform» on
«Move file(s)», «Mark file(s) (Explorer)»: the clipboard list holds all three paths, and the message
reads «CUT was applied on 3 files». «Delete selected files» leaves the deleted entries in the index,
marked and still selected (Seen in passing A), so «Mark» right after a delete puts only missing files
on the clipboard. A paste in a file manager then meets files that are not there (read). The current
file alone goes the same way (read, :3699).

---

## 16. Small things

✅ marks a fixed one.

- **16.1. The «#» column skips 2**: 1, 3, 4, … (run, B1). The rows are numbered by their line in a text
  that has an empty line after the first entry (:60682-60683).
- **16.2. A click on a column title sorts the rows** (run, B1h): the list has no `NoSort`, so
  AutoHotkey sorts it, and the separator moves to the top.
- **16.3. «Browse» starts in the last destination**, not in the folder the field shows, and its
  dialog has no title (run, B4: the field held `<work>\st\other`, the dialog opened on `<work>\out`)
  (:60462). The structured panel starts from its field and names both dialogs (its 15.7, 15.11).
- **16.4. `\.backup` creates `backup`**: the pattern `\name` trims dots at both ends of the name
  (:61751) (run, A8).
- **16.5. The title**: on «Choose...» it reads «Copy file(s) to...», and `changeCopyMoveAction()` sets
  it without the no-break space every panel title starts with (:61625; :28052, :28057) (run, B3b).
- **16.6. A quick file action sets the panel's conflict setting to «Ask user»** (:47510), and the
  panel next opens on it (read). The quick action itself uses its own setting, `QuickFileActConflict`.
- **16.7. The Help** names the button «Mark files (Explorer)»; it reads «Mark file(s) (Explorer)»
  (:61615, :60722). Its b) and c) promise new folders, which one file does not get (finding 5) (read).
  One file gets them since `5ce0fe8`.
- **16.8. An empty field** answers «WARNING: Incorrect file path given:» with nothing after it (read).
- **16.9. A destination used again keeps its place** in the recent destinations:
  `RecentCopyMoveManager()` returns when the folder is listed (:61839-61849), so the list is ordered
  by first use. The batch path adds the destination before the run, also when nothing is then copied
  or the run is cancelled (:62082) (read).
- **16.10. Unused**: the global `lastInvoked` set at every opening (:60609, :60657), the locals
  `prevCurrentSLD`, `btnWid`, `txtWid` (:60617-60626, :60656), and `imgPath`, `OutFileName`, `OutDir`
  of the Help (:61611-61612) (read). The structured panel lost the same global in its 15.14.
- **16.11. `.\` for a file at the root of a drive**: the parent of `C:` is computed as `C`
  (`SubStr(OutDir, 1, InStr(OutDir, "\", 0, -1) - 1)` with no backslash, :61746), a name without a
  drive; the one-file path then copies or moves into `C` under QPV's folder, the working directory,
  and fails when there is none; the batch path counts the file as failed (:62158, :62171) (read).
  Since `5ce0fe8` (finding 5) one file stops with «An unknown error occurred while creating the folder:
  C\» instead, and nothing reaches QPV's folder (run, batch H); `.\` still has no meaning there.
- **16.12. «Mark file(s) (Explorer)» writes the field's text into the shared
  `UsrEditFileDestination`** (:61696), though it does not use it; the structured panel's Destination
  opens with that text when it is a full path (:61394-61395) (read). The structured panel's «Browse»
  stopped doing the same in its 15.7.

---

## Seen in passing

✅ marks a fixed one.

- **A. «Delete selected files» leaves the deleted entries selected**: the multi-delete panel's first
  choice keeps the entries in the index, and `batchFileDelete()` marks each one `||` (:40794) without
  touching its selection mark (:40689-40833) (read). «Mark file(s) (Explorer)» after it offers only
  missing files (finding 15).
- **B. The quick file actions share findings 2 and 10**: the keys 1 to 6, and the tree's and the
  omnibox's «Copy/Move selected file(s) into...», reach the same lines through
  `BtnCopyMoveAction("quick-actu")` (read). They share findings 4 and 5 as well (run, batch G), and
  the fixes of 2, 4 and 5 reach them through the same lines.
- **C. The conflict box shows sizes in whole kilobytes**: «0 Kilobytes» for the 361-byte test files
  (run, B5) (`FileGetSize … K`, :44152-44153).
- **D. The keyboard's menu key opens the panel menu only when pressed twice within 250 ms**: for the
  Apps key or Shift+F10 (`IsRightClick=0`) `SettingsGUIAGuiContextMenu()` returns unless its last
  call was less than 250 ms before (:26023) (read). It is the same in every regular panel, and it may
  be meant so.

---

## Checked and found correct

- **The arrow keys in the list** fill the field with the row they move to (run, B1g): the list's key
  event reaches the handler after the focus has moved.
- **A click on a row** fills the field with its folder (run, B1b).
- **The patterns with two or more files**: `\name` and `.\name` create each file's folder and copy or
  move into it (run, A4-sub-two, A4-sib-two); `\[group-by-years]` groups each file in its own folder
  (run, A10-group-rel).
- **The 150 files question** keeps the panel open on «No» (run, A11).
- **«Cancel» in the conflict box** brings the panel back (run, B5), and the copy is not made.
- **«Proceed» on «Choose...»** refuses with a message, also when the button is enabled (run, B3c).
- **The panel's variables** `UsrCopyMoveOperation`, `copyMoveDoLastOption`, `UsrEditFileDestination`,
  `openingPanelNow`, `whileLoopExec` and `markedSelectFile` are super-globals (:111, :169, :172, :198,
  :398), so the panel functions do not write dead locals (read). The `whileLoopExec := 1` the panel
  leaves set is cleared 50 ms later by `ResetImgLoadStatus()` (:60714) through
  `uiChangeMcursor("normal-extra")` (lib/module-interface.ahk:1717-1720) (read).
- **The g-labels' arguments**: «Proceed» passes its button handle as `BtnCopyMoveAction()`'s `dummy`,
  which is never «quick-actu» there (read).
- **Ctrl+Backspace in the field**: `allowCtrlBkspEdit()` looks for the DEL character (0x7F) that
  Ctrl+Backspace types; the literal in the source is that character (read).
- **«Erase history», «Mark» and «Proceed» close the panel with `BtnCloseWindow()`**, which passes
  «yes» and skips the second during which `CloseWindow()` refuses after a dialog (read).
- **Right-clicks** (`SettingsGUIAGuiContextMenu()` :25990-26027, read): on a row of the list the
  field takes the row's folder and no menu opens; below the rows it is the click of finding 11; on
  another control QPV shows a line that describes it, with its text, type and Alt key
  (`SettingsToolTips()` :27465); on the panel's background the generic panel menu opens
  (`invokePrefsPanelsContextMenu()` :27379: «Close panel», «Dark mode UI», «Large UI fonts», the
  settings folder, «Restore ALL defaults», the site, a donation, a new instance, a restart). Its two
  toggles rebuild the panel (finding 14). The panel has no menu of its own.

---

## Decisions to make before fixing

Decisions 1, 2, 4 to 7 and 11 are settled; the others are open.

1. Finding 1: ask with `askAboutFileSave()` in «Proceed» before the panel closes, as `ed8848c` does for
   the structured panel? For a copy too, as `ed8848c` asks there, although a copy keeps the edits?
   **Settled in `db1cb15`**: a move only.
2. Finding 2: remove the three «; » cuts, since nothing writes a number into the list any more?
   **Settled in `db1cb15` and `244b305`**: yes.
3. Finding 3: refuse a destination that starts with `\\`, with the structured panel's message?
4. Finding 4: resolve the field with `cleanFolderPath()` (:61483) before the tests, as the structured
   panel does, and compare folders by file ID (`getFileIdentity()`), as `88aa9fc`, or by lower-cased
   text (`Format("{:L}")`), as `f52eaac`? **Settled in `5735d4f`**: resolve, and take a file whose
   destination is the file itself, by `getFileIdentity()`, as in its own folder (`isSameFile()`).
5. Finding 5: create the folder in the one-file path without a question, as the batch path does, or
   ask, as an absolute folder is asked? **Settled in `5ce0fe8`**: without a question.
6. Finding 6: a copy into the own folder: duplicate one and several, skip both, or follow the conflict
   setting? **Settled in `58c1f58`**: follow the setting; «Overwrite» skips, and the quick file actions
   keep refusing it.
7. Finding 7: keep the pattern or the grouping word as typed in `prevFileMovePath`, and name «each
   file's own folder» in the messages? **Settled in `16745bf`**: both; the typed text lasts for the
   session, and only a folder reaches the INI and the recent destinations. The places that read it as
   a folder want a full path since `e5713d0`.
8. Finding 8: a grouping word alone: the current file's folder, as now, or each file's own folder, as
   `\[group-by-…]`?
9. Finding 9: the count question before the folder question, as `0ad345c`?
10. Finding 10: accept a drive root as the destination?
11. Finding 11: ignore clicks and double-clicks that hit no row, and the separator? **Settled in
    `a40adb4`**: yes, and the separator stays in the list as a divider.
12. Finding 12: which of «Proceed» and «Help» gets another letter, and which one?
13. Finding 13: should «Erase history» also clear the field and the folders the list takes from other
    sources, and ask first?
14. Finding 14: carry the typed destination and the conflict setting into a rebuilt panel, and create
    «Proceed» disabled on «Choose...», as `3e985a2` for the structured panel?
15. Finding 15: leave out deleted entries and missing files, and count only what goes on the clipboard?

---

## How this was checked

- Static reading of `development` at `e6c63fa`: the panel, its handlers, the routes that open it (the
  M and C keys :2032 and :1834, the File menu :68348-68349 and :68377-68378, the files menu :70469-70470,
  the thumbnails context menu :71468-71469, the toolbar :105822 and :106009, F8, the right-click menu's
  font and theme items), both engines, and each helper before a call to it was judged.
- The real application under headless Wine, on the stock AutoHotkey 1.1.37.02, started on one image,
  with test functions appended to a scratch copy of the script. A test builds a folder tree, opens it
  as a files list, selects files, opens the panel through `PanelMoveCopyFiles()` or
  `InvokeCopyFiles()`, fills the field and the two lists, and posts a click to a button; the handler
  and the engines then run as they are. The log keeps the messages on screen, the files on the disk,
  the recycle bin, the index and the undo records.
- The scratch copy differs from the source in that messages, tooltips and a few calls are logged
  (`QuickMoveFile2Dest()`, `batchCopyMoveFile()`, `askAboutFileSave()`, `ClipboardSetFiles()`), and the
  folder dialog returns a set answer instead of waiting for the user.
- Four batches: A (destinations: «; », patterns with one and two files, `\.` and `\..`, a network path,
  a drive root, a dot name, the own folder, grouping words, 152 files), B (the list, keys and clicks,
  Alt+P, «Erase history», «Browse», «Cancel» in the conflict box, «Mark»), C (a database list and a
  folder name with «Ș»), E (an edited image).
- Aids, each named where it was used: an edited image simulated by setting its state (finding 1); a
  deleted file's entry marked by the test (finding 15); clicks and key presses posted to the list and
  the controls (findings 11, 12); the conflict box answered from a native timer (finding 14); a second
  process that answers dialogs Wine's shell shows during a recycle (batch C).
- Not run on Windows. Four points rest on Windows itself: how its dialog manager handles a letter two
  buttons share (finding 12); whether its list view gives the first row the focus when it receives
  the focus (finding 11); that a file moved onto itself under a doubled backslash stays whole and a
  copy fails (finding 4); and what Windows shows when the recycle bin is asked for a file that is not
  there (batch C). Since the fixes of findings 4 and 11, the second, third and fourth no longer arise
  in this panel: the list ignores the focus, and a file never meets itself. Two others take their
  place: that a click on the empty part of a single-selection list view leaves no row selected
  (AutoHotkey's documentation says so for a double-click), and that `GetFileInformationByHandle()`
  gives one file the same identity under each of its spellings.
- The fixes, on 2026-11-21: batches E and A were run on `db1cb15`; batch F («; » in each kind of
  destination, finding 2) on `db1cb15` and `244b305`; batch A again on `244b305`.
- The fixes of findings 4 to 7 and 11, on 2026-11-21: batches A, B and C, and the new batch G (the
  list's clicks with the selected row logged, a move and quick file actions into the own folder, a
  link, what the field keeps), run at `e38222f`; batches A, C, G and the new batch H (the fixes' cases)
  again at `e38222f`, with the test file of the fix runs; then A, B, C, E, F, G and H on the fixed
  text. Each of the five commits loads on the stock AutoHotkey 1.1.37.02 (`/iLib`, then in full).
- Finding 7's follow-up and two more checks, on 2026-11-21: batch I (what reads `prevFileMovePath`
  after `.\`, `.\resources` and a folder; one file with «Auto-rename» into its own folder) at `2b2835f`
  and on `e5713d0`; batches B and H again on `e5713d0`; the structured kit's batch M at `e38222f` and
  `2b2835f`. `e5713d0` loads as the others do.
- Kit: `.claude/scratch/move-copy-panel-2026-11-20/app/`: `run-mc.sh <tag> testMcA|testMcB|testMcC|testMcE|testMcF|testMcI
  [revision]` (stock interpreter by default; `QPV_SRC=<file>` runs a modified source), and
  `run-link.sh <tag> <revision | ""> testMcG|testMcH` for the two batches that need `<app>\linkdir`, a
  Linux symbolic link to `<work>\st\src` that Wine cannot make. The test functions are in
  `test-mc.ahk` on top of the structured kit's `test-wrappers-sc.ahk`; `patch.py` and `patch-mc.py` add
  the logging; `closer2.ahk` answers Wine's dialogs, and `mcAutoBoxArm()` (A, C, G, H, I) answers any box
  still up after 3 s, «OK» or a conflict box's «Cancel», and logs it. Logs in `results/` (`a-head`,
  `b-head`, `c-head`, `e-head`; for the fixes `e-db1cb15`, `a-db1cb15`, `f-db1cb15`, `f-fix`, `a-fix`;
  for findings 4 to 7 and 11 `a-e38`, `b-e38`, `c-e38`, `g-e38` and, with the fix runs' test file,
  `a-e38b`, `c-e38b`, `g-e38b`, `h-e38`, then `a-fx`, `b-fx`, `c-fx`, `e-fx`, `f-fx`, `g-fx`, `h-fx`;
  for the follow-up `i-2b2`, `i-fx`, `b-fx2`, `h-fx2`, then `i-2b2b`, `i-fx3` with the structured
  panel's two «Browse» as well, and `m-e38`, `m-2b2` in the structured kit). Batch I presses those
  with the Move/Copy panel open, and they read its Destination field as their own, so it empties the
  field first. The
  scripts that wrote the fixes and the report notes are in `../fix-2026-11-21/`.
  The recent destinations INI is kept from one batch to the next; G and H empty it where they read it.
