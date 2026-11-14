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

| # | Finding | Harm | Checked |
|---|---------|------|---------|
| 1 | The Destination names the Source folder in another way: with «Overwrite» the selected files are recycled and the tool reports success | high, needs «Overwrite» | run |
| 2 | Destination inside the Source, or the reverse: on a move with «Overwrite» one selected file replaces another | high, needs «Overwrite» | run |
| 3 | An edited, unsaved image among the moved files loses its edits without a question | high, narrow | run |
| 4 | Undo after a move that overwrote files never brings those files back | high | run |
| 5 | A file that cannot be copied or moved: with «Overwrite» the file at the destination is recycled anyway | medium | run |
| 6 | A database list: a move that overwrites a listed file leaves a database row for a file that is gone | medium, needs «Overwrite» | run |
| 7 | Destinations without a drive letter, the regular panel's patterns and network paths: the files land in QPV's folder | medium | run |
| 8 | A slash or a space at the end of a field: every file skipped, or doubled backslashes written into the index | medium | run |
| 9 | A folder name with a letter outside A-Z in another case: every file is skipped | medium, narrow | run |
| 10 | «Possible source paths» rarely offers the folder that holds the selection | medium | run |
| 11 | «Proceed» creates the destination and closes the panel before it checks the selection and asks the 150 files question | medium | run |
| 12 | A folder at the destination with a selected file's name receives the file; the index then names the folder | low, narrow | run |
| 13 | Missing files outside the Source are counted as failed, not as skipped | low | run |
| 14 | A destination of four characters that does not exist, such as `D:\a`, is refused | low | run |
| 15 | Small things: a window handle as a tooltip, the first text, «Proceed» on «Choose...», what the panel remembers | low | run and read |

Findings 10 and 11 are the ones a user meets in ordinary use. Findings 1 and 2 lose files
(to the recycle bin), but only with «Overwrite» and an unusual pair of paths; finding 3 loses
work for good, but needs an edited image among the moved files.

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

---

## 15. Small things

- **The «Action to perform» list shows a window handle as its tooltip** (run: `0x2c0142`).
  `GuiAddDropDownList()` uses the third item of its label list both as the list to align
  with and as the tooltip text (:26604-26613). The regular Copy/Move panel has it too (run).
- **The first text** reads «This panels allows users…», and it was meant to start with the
  selection count: `infoSelection` is filled after the text is added (:60874, :60890) (run).
- **«Proceed» is enabled while «Action to perform» shows «Choose...»**, where the regular panel
  disables it; a click says «Please select action to perform: copy or move files» (run). It
  is also narrow: 60 pixels (read).
- **The action is «Choose...» at every opening** (:60865) (run). It may be meant so.
- **«On file name conflicts» is not kept across restarts** (read). The regular panel's list is
  not either.
- **The destination is not added to the recent destinations** of the regular panel (read:
  no `RecentCopyMoveManager()` call), and `prevFileMovePath` is not set (run).
- **«Browse», then «Cancel»**: at the next opening the Destination shows the text typed before
  «Browse», not the folder picked with it (run). «Browse» writes the field's text into the
  shared variable (:59958-59962).
- **The pre-filled Source** is the folder of the focused file, also when that file is not
  selected, or when it sits in a subfolder of the selection (run). For an index entry that
  names no file on the disk the field holds that entry's folder, and «Proceed» answers
  «Please choose an existing source folder» (read).
- **The destination folder is looked for again for each file** whose folder already exists:
  `prevuDir` is set only after a folder was created (:3285-3295) (read).
- **An empty file at the destination** is replaced without being recycled and without the
  «overwritten» mark in the undo record (run): `FileRexists(…, 0)` counts it as absent.
- **Both «Browse» dialogs have the same title** (read).
- **No Alt letters**: «Structured file operations» has none in either menu, and the labels
  «Source:», «Destination:», «On file name conflicts:» and «Action to perform:» have none, so
  the fields are reached from the keyboard with Tab alone. The menu bar's File menu offers
  the item only in thumbnails view (read).
- **The «Source:» label** is not centred on the field's height as «Destination:» is (read).
- **Unused**: the global `lastInvoked` set at every opening (:60844), and `btnWid`, `txtWid`,
  `lstWid` (read).

---

## Seen in passing

**A. The regular Copy/Move panel** shares two findings: `batchCopyMoveFile()` has no save
question (finding 3), and both its engines recycle before they copy (finding 5) (read). Its
«&Proceed» and «Hel&p» buttons share Alt+P (:60209, :60211) (read).

**B. `recordUndoFileActs()`** drops the size for every move and rename tool (finding 4).

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
  letters outside A-Z do not match (finding 9).
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

1. The same folder (finding 1): compare the folders' file IDs, or only resolve the text
   (`.`, `..`) and leave links, short names and SUBST drives to the per-file test?
2. Nested folders (finding 2): refuse them, or leave out the files under the Destination?
3. «Overwrite» (finding 5): copy to a temporary name first, or keep the order and list the
   recycled files in the message?
4. Destinations (finding 7): drive-letter paths only? Network paths supported or refused with
   a message? Should the Destination start from the regular panel's text, from
   `prevFileMovePath`, or from this panel's last folder?
5. «Possible source paths» (finding 10): offer the deepest folder that holds the whole
   selection, the selected files' own folders, or their parents? A parent recreates the
   top folder in the Destination, which may be what the code meant.
6. Fewer than two files (finding 11): work on one file, refuse to open, or say why nothing is
   done?
7. The undo record (finding 4) changes the records of every move and rename tool. Change it
   for all of them?
8. Finding 15: keep «On file name conflicts» across restarts? Add the Destination to the recent
   destinations? Start «Action to perform» on the last action?

Suggested order: 1, 2, 4 and 5 together (the engine); then 3, 6 and 12; then 7, 8, 9 and 11
(the handler); then 10; then the rest.

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
- Not checked: a read-only file moved to another volume, and a folder name ending in a dot.
- Kit: `.claude/scratch/structured-copy-move-2026-11-14/app/`: `run-app.sh <tag> <test
  function>`, `run-k.sh <tag>` (makes the link batch K needs), `run-all-old.sh` (the twelve
  old batches), `norm.sh` (compares logs), `test-wrappers-sc.ahk` (testScA to testScL),
  `results/` (`<batch>-hd.txt` for the old batches on `b4f374f`, `i1`, `j1`, `k1`, `l1`),
  `results-1110/` (the logs of 2026-11-10).

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
| 10 | 5, 15 | (10.2) is in finding 15; (10.3) not checked; (10.4), (10.5) found correct |
| 11 | 10 | (11.4) in finding 10 |
| 12 | 10 | (12.3) found correct |
| 13 | 11, 15 | (13.1) not reachable |
| 14 | 11 | |
| 15 | 6 | (15.2), (15.3) generic; (15.4) false |
| 16 | 7, 15 | |
| 17 | 15 | (17.4) generic |
| 18 | 15 | (18.4) in finding 15; (18.3) false |
| 19 | 13 | |
| 20 | 14 | |
| 21 | 15 | |
| 22 | 10 | (22.4): the menu follows the dark theme, found correct |
| 23 | Checked and found correct | false: the fields open Windows' menu |
| 24, 25 | Checked and found correct | generic; (24.3) not a defect |
| 26 | 15 | (26.2) in finding 15; (26.1b) false; (26.3) found correct |
| 27 | 15 | |
| 28 | 15 | (28.2), (28.3) generic |
| S1 | 4 | |
| S2 | 15 | |
| S3, S4 | 15, 7 | |
| S5 | Checked and found correct | generic |
| «Checked and found correct» | Checked and found correct | agreed; the Ctrl+Backspace item was not checked |

New here: the link to the Source folder (finding 1), the file that cannot be read under
«Overwrite» (finding 5, run where Gemini read it), the regular panel's patterns `\folder` and
`.\folder` (finding 7), the library case and the time of «Possible source paths» (finding 10),
the folder left after «No» at the 150 files question (finding 11), and the shared Alt+P of the
regular panel («Seen in passing» A).
