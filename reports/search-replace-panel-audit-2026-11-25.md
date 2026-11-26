# «Search and replace» panel audit, 2026-11-25

Scope: `PanelSearchAndReplaceIndex()` (:47339) and the panel it builds: «Search for», «Replace with», «Apply
action to» with its four choices, «Modify folder paths only (do not modify file names)», «Perform» and «Cancel».
The audit also covers what those controls run, and the routes that open the panel. The handlers are:

- the button: `BTNperformIndexSearchReplace()` :47381, which holds the seed folders branch itself (:47408-47424);
- the files list and the database list: `SearchAndReplaceThroughIndex()` :99216;
- the seen images database: `SearchAndReplaceSeenDB()` :99421;
- the helpers, as far as the panel reaches them: `StrReplaceCaseless()` :99196, `repairPathSeparators()` :99189,
  `SQLfolderMatchClause()` :33260, `updateSQLdbEntryPath()` :34695, `remFilesListFilter()` :4216,
  `updateMainUnfilteredList()` :34035, `getDynamicFoldersList()` :35061, `cleanDynamicFoldersList()` :88104,
  `recreateDynaFoldersSQLdbList()` :34860, `addDynamicFolderSQLdb()` :65749, `zPlitPath()` :60681,
  `retrieveSeenImageDBentry()` :75995.

Line numbers are `quick-picto-viewer.ahk` on `development` at `bbc49e4`. The audit changed no code.

Ten findings, a list of small things (row 11 of the summary) and three things seen in passing. Each one says how
it was checked: **run** means the real application did it under headless Wine, on the stock AutoHotkey
1.1.37.02; **read** means it follows from the code and was not run. Nothing was run on Windows. Each run
carries a tag such as A1 or H3: the letter names its batch (listed under «How this was checked»), and the tag
marks its lines in the kit's logs.

**Status, 2026-11-26.** Before any fix, batches A, B, C, E, G, H, L and N were run again at `57d1f81`: they give the
outcomes of `bbc49e4`. Marius answered decision 1 with (a), decision 2 with the literal replace, and the folder-mode
half of decision 3 with «balance the separators without a word». Of four guards offered with the fix, he chose two.

- Findings 1 and 2 are fixed in folder mode in `474793a`. The same change fixes finding 3 in folder mode and H1 and
  H3 of finding 7; H5 now merges, which leaves decision 7 open.
- `c2fde82`: in folder mode and for the seed folders, an empty «Search for» or «Replace with» is refused.
- `12fc79d`: on a database list, «Replace with» goes to the pass in lower case, as the database stores it (X1, new).

Three new batches, X, Y and Z, run what A-N lacked: the letter case, entries of deleted files, network paths, drive
roots, a nested move, a filtered list in folder mode, and empty or identical strings in targets 1, 3 and 4 (see «How
this was checked»). Sections 1, 2, 3, 7 and 10 and small thing 11.5 end with what was run and a note on what the
code does now; those notes cite lines at `12fc79d`. The other line numbers stay those of `bbc49e4`.
The runs used the fix's text over `57d1f81`; the commits sit on Marius's `1fbbb4c` (see «How this was checked»).

## Terms

- **The panel**: panel 56, «Search and replace in the files index». Its routes: Ctrl+H (:1461-1464), «Search and
  re&place» in the Find menu (:69177) and in the files list menu (:72949), and a right-click on the toolbar's
  search button (`processToolbarFunctions()`, :106124-106125).
- **The target**: the «Apply action to» choice. 1 «Current files list», 2 «Selected files only», 3 «Entire seen
  images database», 4 «Main seed folders list».
- **Folder mode**: the checkbox «Modify folder paths only (do not modify file names)» ticked. **Whole-path mode**:
  the checkbox left clear.
- **A database list**: a files list opened from an `.SLDB` file (`SLDtypeLoaded=3`); the list on screen is a copy
  of its `images` table. A **plain list** is any other: a folder opened as a list, or an `.SLD` file.
- **The seen images database**: `seenImagesList.db`, where QPV records the images viewed, one row per full path.
- **The seed folders**: the folders a list is built from and scanned again from (`DynamicFoldersList`; the
  `dynamicfolders` table of a database list).
- **The folders list**: the folders a list's files sit in, with their dates, which the «Folders list» panel and
  the partial refreshes use (the `staticfolders` table of a database list; the `[Folders]` section of an `.SLD`).
- **The filled-in search text**: what «Search for» holds when the panel opens: the current file's folder, taken
  by `zPlitPath()` (:47367), without a trailing backslash.
- **A separator**: the backslash between two folder names. **A network path**: a path that starts with
  `\\server\share`.
- **«records were modified»**: the count in the panel's closing message, «Finished updating the files list | N
  records were modified».
- **`<work>`**: the kit's test folder; `Z:\…\work` in the messages quoted below.

## Summary

| # | Finding | Harm | Checked | Status |
|---|---------|------|---------|--------|
| 1 | The search matches inside folder names, folder mode included: the filled-in «…\pics» also rewrites «pics 2024» and «picsold» | medium | run | **fixed** in folder mode, `474793a`; whole-path mode stays a literal replace, by Marius's choice |
| 2 | Database lists in folder mode: the database matches whole folders, the list matches text; the two disagree, the message counts the list, and the database's old paths come back at the next opening | high | run | **fixed**, `474793a`; the letter case of «Replace with» too, `12fc79d` |
| 3 | A separator at the end of one string only: folder mode glues each subfolder's name to the new folder («photossub»), while the folder's own files come out right | medium | run | folder mode **fixed** with finding 1, `474793a`, and an empty string refused there, `c2fde82`; whole-path mode open |
| 4 | «Current files list» on a filtered list: a database list loses its filter without a word and every record is rewritten; a plain list rewrites only what the filter shows | medium | run | open |
| 5 | A new path that another entry holds: on a database list the record keeps its old path while the list shows the new one, twice; a plain list gets the duplicate silently | medium | run | open |
| 6 | Database lists: the captions, the audio notes and the folders list stay at the old paths; the renamed images lose their captions | medium | run | open |
| 7 | «Main seed folders list»: no message whatever happens; every network path in the list loses its leading backslash; a list of network paths alone counts as empty; the result is not cleaned | medium | run | in part: H1 and H3 **fixed** with finding 1, `474793a`; H5 now merges (decision 7 open); no message and H4 open |
| 8 | Private mode: the two fields hide their text, then the on-screen message prints both strings in full | low | run (the message) + read (the display) | open |
| 9 | «Entire seen images database»: the progress and time-left display never appears | low | run | open |
| 10 | The «identical strings» check compares numbers: «01» and «1», «1» and «1.0» are refused | low | run | open |
| 11 | Small things: 11.1 to 11.6 | low | run / read | open |

The rows give the status at `12fc79d`.

## 1. The search matches inside folder names

Every target replaces the search text wherever it occurs:

- plain lists, «Selected files only» on any list, and the list half of a database list: `StrReplaceCaseless()` on
  the folder with its separator (:99355, folder mode) or on the whole path (:99360);
- the seen images database: :99470 (folder mode) and :99475;
- the seed folders: :47416, over the whole list as one text.

So «…\pics» also changes «…\pics 2024\» and «…\picsold\». The filled-in search text is exactly such a string: the
current folder with no separator at its end. `SearchAndReplaceThroughIndex()` states the opposite contract for
folder mode (:99218-99220): «whole folders are matched; d:\pics\old must never match d:\pics\oldies». Its two
folder-rename callers keep that contract by passing both paths with a trailing separator (:32117, :99006,
:99025); the panel passes the two fields as they are.

Run:

- **A1** (plain list, folder mode, the filled-in «<work>\pl\pics» replaced with «<work>\pl\photos»): «pics\a.png»
  and «pics\sub\c.png» changed, and so did «pics 2024\b.png» → «photos 2024\b.png» and «picsold\d.png» →
  «photosold\d.png». «4 records were modified».
- **A2** (the same in whole-path mode): the same four.
- **A3** (control: «<work>\pl\pics\» → «<work>\pl\photos\»): only «pics» and «pics\sub»; «2 records were
  modified».
- **G1** (the seen images database, folder mode, «<work>\s\old» → «<work>\s\new»): «oldies\c.png» became
  «newies\c.png».
- **H1** (seed folders «<work>\h\pics» and «<work>\h\pics 2024», «…\pics» → «…\photos»): both changed, the second
  to «photos 2024».
- **L1** («Selected files only» on a database list, folder mode, the filled-in text): «oldies\c.png» →
  «newies\c.png», in the list and in the database alike.

Harm: a user who keeps the filled-in folder and types the new one the same way moves the entries of every
neighbouring folder whose name begins the same way, to paths that do not exist. On a plain list only a second
replace by hand undoes it. On a database list the database half of folder mode does match whole folders; that
difference is finding 2.

Run again at `57d1f81` (A1-A3, G1, H1, L1): the same outcomes. Batch Y, new, adds three shapes, run at `57d1f81` too:

- **Y1** («…\pl\ÉTÉ» typed for the folder «Été», «Replace with» «…\pl\Summer»): «Étéx\c.png» became «Summerx\c.png».
- **Y2** (the new folder inside the old one, «…\pl\old» → «…\pl\old\sub»): «olds\c.png» became «old\subs\c.png».
- **Y7** («Selected files only», «oldies\c.png» among the selected entries): it became «newies\c.png».

**Fixed in `474793a`**, as Marius chose (decision 1, option (a)). In folder mode both strings get one trailing
separator (`SearchAndReplaceThroughIndex()` :99071-99072, `SearchAndReplaceSeenDB()` :99283-99285). Each entry's
folder is then matched from the start of the path by `movedFolderPath()` (:32078): the folder itself or a folder
inside it, whatever the case of its letters. The files list (:99207), the database's subfolder records (:99134)
and the seen images database (:99329) all take the new folder from it, and an entry of a file deleted from the
disk keeps its `||`. The seed folders go through `renameDynamicFoldersEntries()` (:32095, called at :47445), the
seed folders' own rename, which the folder renames already use (finding 7). A part of a folder name, such as
«old», now matches nothing in folder mode. Whole-path mode stays a literal replace (decision 2), so A2 is
unchanged.

Runs with the fix, over `57d1f81`:

- **A1**: «pics\a.png» and «pics\sub\c.png» move; «pics 2024» and «picsold» stay; «2 records were modified». **A2**:
  the four, as before. **A3**: as before.
- **G1**: «oldies\c.png» stays. **H1**: «pics 2024» stays. **L1**: the selected «oldies\c.png» stays, in the list and
  in the database.
- **Y1**, **Y2**, **Y7**: «Étéx», «olds» and «oldies» stay. **Y3** (a plain list filtered to «\x», «…\pl\x» →
  «…\pl\z»): «x\a.png» and «x\b.png» move, in the list and behind the filter; «xy\c.png», shown, stays.
- **X5b** (entries on «\\nas\share», «\\nas\share\pics» → «\\nas\share\photos»): «pics» and «pics\sub» move, «pics
  2024» stays. **X6** («Z:» → «Y:»): every entry moves to «Y:».
- **X2**, **X3** (an entry marked `||`, on a plain list and on a database list): it moves and keeps its mark; on the
  database list its record moves too.

## 2. Database lists in folder mode: the database and the list follow different rules

On a database list, «Current files list» writes the database with SQL first and then the list in memory, and in
folder mode the two passes match differently:

- the database matches whole folders from the start of the path: `UPDATE … WHERE SQLfolderMatchClause("|" whatu)`
  (:99248) for the folder itself, then `SELECT … WHERE SQLfolderMatchClause(whatu)` (:99261) for its subfolders;
- the list matches text anywhere, as in finding 1 (:99355), over every entry (:99322-99384).

The closing message counts the list (`totalAffected`, :99379, shown at :99412). A database list has no save
question: `askAboutSlidesListSave()` asks only for `.SLD` files and the favourites (:66008-66009). So whatever the
database did not get is lost when the database is opened again.

Run:

- **B1** (the filled-in «<work>\db\old» → «<work>\db\new»): the list holds «new\a.png», «new\sub\c.png» and
  «newies\b.png»; the database holds «new\a.png», «new\sub\c.png» and «oldies\b.png». «3 records were modified».
  After the database was opened again, the list shows «oldies\b.png».
- **B2** (a part of a folder name, «old» → «new»): the list changed all three entries and the database none:
  `SQLfolderMatchClause("old")` matches no stored folder, since every one starts with its drive. «3 records were
  modified»; opened again, all three are back at «old».
- **B3** (control, whole-path mode): the database and the list agree. Both use the same substring rule there
  (`fullPath LIKE '%…%'`, :99263).

Harm: the panel reports the work done and the user sees the new paths, yet the database never got some or all
of them, and opening the list again brings the old paths back. Until then the list's entries carry paths the
database does not have, under the database's record numbers.

Run again at `57d1f81` (B1-B3): the same outcomes. Two new shapes, run at `57d1f81` too:

- **Y2b** (the new folder inside the old one, «…\db\old» → «…\db\old\sub»): the list holds «old\subs\c.png», the
  database «olds\c.png».
- **X1** («Replace with» typed with capitals, «…\db\New»): the list holds «…\db\New\a.png», the database
  «…\db\new\a.png»; opening the database again shows the lower case. X1b, in whole-path mode, gives the same.

**Fixed in `474793a`**: the list loop follows the database's rule (finding 1's fix), so the two passes change the
same entries, and the closing message counts them. In folder mode the count is now of entries: it counted the
replacements, 36 for three entries in Y5 at `57d1f81` (finding 3). **`12fc79d`**: on a database list «Replace with»
goes to the pass in lower case (:47429-47430), as `renameFolderInLists()` passes the new folder.

Runs with the fix, over `57d1f81`:

- **B1**: the list and the database hold «new\a.png», «new\sub\c.png» and «oldies\b.png»; «2 records were modified»;
  the same after opening the database again.
- **B2** («old» → «new»): nothing changes, in the list or in the database; «0 records were modified».
- **B3** (whole-path mode): as before; the list and the database agree.
- **X1**, **X1b**: the list holds «…\db\new\a.png», as the database does. **Y2b**: the list and the database agree,
  «olds\c.png» stays.
- **Z4** (batch Z, new; a change of letter case alone, «…\db\old» → «…\db\Old»): at `57d1f81` the list showed
  «…\db\Old\…» until the database was opened again; with the fix nothing changes, though the message says «2 records
  were modified». A database list cannot hold such a change: its records are in lower case.

## 3. A separator at the end of one string only glues folder names together

Folder mode adds a separator to each folder before the replace (:99285 for the database's subfolders, :99350 for
the list, :99470 for the seen images database), and `repairPathSeparators()` (:99189) collapses a doubled one
afterwards. Nothing restores a missing one. With «Search for» ending in «\» and «Replace with» not, the folder's
own files come out right, because their folder gained the separator before the replace; each subfolder's name,
though, is glued to the new folder's.

Run:

- **C1** (plain list, folder mode, «<work>\pl\pics\» → «<work>\pl\photos»): «photos\a.png», «photos\e.png» and
  «photossub\c.png».
- **C2** (database list, the same): the database too holds «photossub\c.png», also after opening it again.
- **C3** (control, the separator on «Replace with» only): «photos\sub\c.png», right.
- **C4** (database list, whole-path mode, «…\pics\» → «…\photos»): «photosa.png», «photose.png» and
  «photossub\c.png»: every path.

C4 is what a literal replace does. Folder mode, though, gives two different results within one pass. The panel
checks neither string; an empty «Replace with» is accepted as well, and leaves relative paths such as «old\a.png»
in the list and in the database (read).

Run again at `57d1f81` (C1-C4): the same outcomes. Batch Y, new, runs the empty and identical strings in folder mode
at `57d1f81`:

- **Y4** (plain list, «…\pl\old\» → nothing): «\a.png» and «sub\b.png». **Y4b** (database list): the same, in the list
  and in the records.
- **Y5** («\» → «_»): every separator of the entries' folders became «_»; «36 records were modified».
- **Y6** («…\pl\old» → «…\pl\old\»): «2 records were modified», and nothing changed.

**Fixed in folder mode in `474793a`**, with finding 1: both strings end with one separator before the match, as
Marius chose (decision 3: balanced without a word). In folder mode and for the seed folders, the identical-strings
check compares the two without their trailing separators (:47409-47416). **`c2fde82`**: there, a «Search for» or
«Replace with» empty once its trailing separators are dropped is refused, and the panel stays open (:47413,
:47419). Whole-path mode is unchanged.

Runs with the fix, over `57d1f81`:

- **C1**, **C2**: «photos\a.png», «photos\e.png» and «photos\sub\c.png», in the list and in the database, also after
  opening it again. **C3**: as before. **C4** (whole-path mode): «photosa.png», «photose.png» and «photossub\c.png»,
  as before.
- **Y4**, **Y4b**: «WARNING: No replacement folder given»; nothing changes. **Y5**: «WARNING: No search criteria
  given». **Y6**: «WARNING: The search and replacement strings are identical».
- **Z3** (batch Z; the seen images database, folder mode, «Replace with» empty): at `57d1f81` the records became
  «\a.png» and «sub\b.png»; with the fix, «WARNING: No replacement folder given», and nothing changes. The seed
  folders' cases, Z1 and Z2, are under finding 7.

## 4. «Current files list» on a filtered list: two scopes, and a database list loses its filter

On a database list, `SearchAndReplaceThroughIndex()` removes the filter before the pass (:99237-99238,
`remFilesListFilter("simple")`) and never puts it back. A plain list keeps its filter, the loop walks only the
entries it shows, and each change is copied into the list behind the filter (`updateMainUnfilteredList()`,
:99376-99377).

Run:

- **D1** (plain list filtered to «\x\», «<work>\pl\» → «<work>\ql\»): the two entries shown changed, the two hidden
  ones kept «pl»; «2 records were modified»; the filter stays.
- **D2** (database list with the same filter, «<work>\db\» → «<work>\eb\»): the filter is gone (`filesFilter`
  blank, the four entries shown), all four entries and all four records changed; «4 records were modified». No
  message mentions the filter.

Harm: the same choice means «what the filter shows» on one kind of list and «every entry, with the filter
dropped» on the other. On a database list, a user who filtered the list to narrow the change gets it applied to
every record. The removal is needed by the database pass as it is written: its SQL takes every matching record,
so the list must hold them all to agree with it (decision 4).

## 5. A new path that another entry already holds

Run:

- **E1** (database list, whole-path mode, «<work>\db\a\» → «<work>\db\b\», with «b\img.png» listed already): «Failed
  to modify 1 entries in the files list | Finished updating the files list | 2 records were modified». The database
  refused record 1 (`UNIQUE (fullPath)`, :76170) and kept «a\img.png»; the list shows «b\img.png» twice. Opened
  again, the list shows «a\img.png».
- **E3** (plain list, the same): «2 records were modified»; the list holds «b\img.png» twice. No warning.
- **E2** (control, database list, folder mode): the single `UPDATE` of the folder fails as a whole, «Failed to
  update the files list database | UNIQUE constraint failed: images.fullPath», and nothing changes; the list and
  the database agree.

Cause: in the database pass a failed `updateSQLdbEntryPath()` is only counted (:99299-99300). The list loop after
it writes every entry anyway: `entryOK` is 1 (:99364) and changes only for «Selected files only» on a database
list. «records were modified» counts the list, so it says 2 where the database changed one record.

Harm: the panel exists for lists whose files moved. When the new folder has been indexed as well by then, every
moved file meets its own entry there, and each one ends as a duplicate.

## 6. Database lists: captions, audio notes and the folders list stay at the old paths

Beside the paths in `images`, a database list keeps the captions and audio notes in `imagesData`, keyed by the
image's full path (:76172), and the folders list in `staticfolders` (:76174). `SearchAndReplaceThroughIndex()`
writes `images` only. The two folder renames call it and then move the rest: `renameFolderInLists()`
(:32113-32133) and `PanelRenameStaticFolder()` (:99006-99009) go on to `renameStaticFolderSQLdb()` (:99129), which
moves the folders list rows, the captions, the audio notes and the paths of the audio files. The panel calls
nothing after it.

Run **J1** (database list, folder mode, «<work>\db\old\» → «<work>\db\new\», with a caption on «old\a.png»):
`images` holds the three files at «new»; `imagesData` still holds «old\a.png» with its caption; `staticfolders`
still names «<work>\db\old»; the caption read for the entry now at «new\a.png» is empty.

Harm: the images lose their captions and audio notes, which stay in the file under paths nothing points to. The
folders list names a folder that no longer holds the files and lacks the one that does, until «Regenerate this
folders list».

Read, not run: an `.SLD` list that keeps its own folders list (`SLDcacheFilesList=1`) leaves
`newStaticFoldersListCache` as it was too, and `SaveFilesList()` writes it back unchanged (:35454-35462). The
captions of plain lists are `.txt` files next to the images, which the panel rightly leaves alone.

## 7. «Main seed folders list»: no word, network paths cut, the result not cleaned

The branch (:47408-47424) joins the seed folders into one text, adds a separator to each line, replaces, collapses
`\\` into `\`, takes the added separators off, and stores the result; on a database list it also rewrites the
`dynamicfolders` table. Run on a database list whose seed folders were written into that table:

- **H1** («<work>\h\pics» → «<work>\h\photos», over «pics» and «pics 2024»): both changed (finding 1). No
  message; the panel closes.
- **H2** (a search that matches nothing): no message either; the panel closes and the table is written again,
  unchanged.
- **H3** (seed folders «\\nas\share\pics» and «<work>\h\other»; «<work>\h\other» → «<work>\h\else»): the network
  folder, not searched for, came out as «\nas\share\pics», in `DynamicFoldersList` and in the table. Cause:
  `StrReplace(listu, "\\", "\")` (:47417) collapses every doubled backslash, the leading pair of a network path
  included. `repairPathSeparators()` (:99189) is the helper that leaves that pair alone.
- **H4** (only network paths): «WARNING: The seed folders list is empty». The test `!InStr(listu, ":")` (:47411)
  looks for a drive letter's colon.
- **H5** («<work>\h\pics» → «<work>\h\other», with «|<work>\h\other» listed already, the same folder scanned without
  its subfolders): both «<work>\h\other» and «|<work>\h\other» stay. The seed folders panel's own rename refuses
  such a rename (`findTakenDynamicFolderPath()`, :98986-98997), and the result here never goes through
  `cleanDynamicFoldersList()`.

The branch never reads folder mode either; see 11.4.

Run again at `57d1f81` (H1-H5): the same outcomes.

**In part fixed in `474793a`**, with finding 1. The branch hands the two strings, without their trailing separators,
to `renameDynamicFoldersEntries()` (:47445), the seed folders' own rename. That function matches whole folders from
the start of the path, keeps the `|` mark and leaves a network path whole. Its result goes through
`cleanDynamicFoldersList()`, so H5 now merges the two entries, where the seed folders panel's rename refuses such a
rename. The merge comes with the helper: whether to refuse or to merge (decision 7) was not put to Marius, and is
still his to answer. The function writes the table only when an entry changed. Still open: no message (H1, H2), H4,
and decision 7.

Runs with the fix, over `57d1f81`:

- **H1**: «pics» becomes «photos», «pics 2024» stays; no message.
- **H2**: no message; the table is no longer written.
- **H3**: «\\nas\share\pics» keeps its leading «\\», in `DynamicFoldersList` and in the table.
- **H4**: as before.
- **H5**: «<work>\h\other» and «|<work>\h\other» merge into «<work>\h\other», scanned with its subfolders.
- **Z1** (batch Z, new; «Replace with» empty): at `57d1f81` the seed folder «pics» was dropped from the list and from
  the table; with the fix, «WARNING: No replacement folder given», and nothing changes (`c2fde82`). **Z2** («…\h\pics»
  → «…\h\pics\»): at `57d1f81` nothing changed, yet the table was written again and the list marked modified; with
  the fix, «WARNING: The search and replacement strings are identical».

## 8. Private mode shows what the fields hide

In private mode both fields are password fields (`doPwd`, :47366). The first message of the pass then prints both
strings in full: «Performing search and replace in the files list index:» with the two strings (:99227), and the
same for the seen images database (:99432). QPV's other messages leave paths out in private mode, for example
:27746, :30613 and :41026.

Run: **I1** (private mode, «Current files list»): both fields have `ES_PASSWORD`; the message handed to the
on-screen display is «Performing search and replace in the files list index: | Z:\…\work\pl\pics |
Z:\…\work\pl\photos». The image loader's message right after it follows the convention: «ERROR: File not found or
access denied |  | \». **I2**: the same for «Entire seen images database».

Read: the display draws the message as it is given. `CreateOSDinfoLine()` (:100217-100340) has no private-mode
branch and hands `msg` to `drawTextInBox()` (:100278). The kit logs the message handed over; it did not capture
what was painted. The message stays on screen while the pass runs.

## 9. «Entire seen images database»: the progress display never appears

`SearchAndReplaceSeenDB()` tests `A_TickCount - prevMSGdisplay>1500` at each record (:99454), but nothing sets
`prevMSGdisplay` before the loop; the files list pass does (:99253, :99316). In AutoHotkey v1 arithmetic on a blank
variable gives a blank, and a blank is not greater than 1500, so the branch never runs and `prevMSGdisplay` is
never set inside it either.

Run: the kit logged the test's value at the first record: blank (G1, G2, G4, I2). **G2**: 60,000 records, a pass of
3.5 s; the screen showed only the opening message and the final one, with no progress bar and no time left.

## 10. The «identical strings» check compares numbers

`If (editF5==editF6)` (:47390) compares the two fields as numbers when both look like numbers.

Run: **F1** («01» → «1»): «WARNING: The search and replacement strings are identical»; nothing changes and the
panel stays open. **F3** («1» → «1.0»): the same. **F2** (control, «\01\» → «\1\»): done, «01\a.png» →
«1\a.png».

Folder names are often numbers: days, months, years.

Since `474793a` the check compares the two strings without their trailing separators in folder mode and for the
seed folders (:47416); the comparison is still `==`, so this finding stands. Run with the fix (F1-F3, whole-path
mode): as before.

## 11. Small things

✅ marks a fixed one.

11.1. **Two files: the panel is offered, then refuses.** Ctrl+H (:1463) and the Find menu (:69166) offer the panel
from two files up; the panel wants three (:47347), so it answers «WARNING: Insufficient files are currently
indexed.». The Find menu disables «Find duplicate images» on that same condition (:69180-69181), but not this item.
The seen images database and the seed folders need no files list at all, yet below three files no route reaches
them. Run **K1**: with two files the Find menu lists «Search and re&place» enabled and «&Find duplicate images»
disabled; the panel refuses.

11.2. **The seen images database is refused while recording is off.** «WARNING: The option to record seen images
is currently deactivated.» (:47403-47404), though the database is there and the replace works on it. Run **G3**,
with 60,000 records in the database: refused, the panel stays open.

11.3. **The thumbnails view keeps the old seen state.** After «Entire seen images database» moved the records, the
entries already looked up stay «not seen» in the thumbnails view, since `resultedFilesList[i, 3]=0` answers there
before the database is asked (:76001-76004). The image view asks the database and is right. Run **G4**: before the
move 0 0 0; after it, 0 0 0 as the thumbnails view asks (the kit set `thumbsDisplaying=1` around the calls) and 1 1
1 as the image view asks.

11.4. **Folder mode stays offered for «Main seed folders list»,** where nothing reads it (the branch at
:47408-47424). Read.

11.5. **The filled-in search text of a file on a network path lacks the leading `\\`**: `zPlitPath()` skips the
empty parts before the server's name and trims the rest (:60715-60720). This is the shared defect of the multi-rename audit's «Seen in passing» A (2026-11-24).
Run **L3**: the current entry «\\nas\share\pics\b.png»; «Search for» opens with «nas\share\pics».
Since `474793a` that text matches nothing in folder mode, which matches from the start of the path. Run **X5**, at
`57d1f81`: the filled-in «nas\share\pics» → «nas\share\photos» moved all three entries, «pics 2024» included, the text
being found inside each path; with the fix, «0 records were modified». Marius left this item open when he chose the
fix of findings 1 and 2.

11.6. **A folder-mode collision names no file.** On a database list the message is SQLite's own: «Failed to update
the files list database | UNIQUE constraint failed: images.fullPath» (E2). Nothing changes, so no harm is done, but
the user is not told which path is taken.

## Seen in passing

✅ marks a fixed one.

- **A. An `.SLD` file drops its network-path seed folders and folders list entries when it is opened.**
  `coreLoadDynaFolders()` (:88091) and `LoadStaticFoldersCached()` (:35559) keep only the lines whose path starts
  with a drive letter, while `SaveFilesList()` writes every seed folder (:35439-35449). Read.
- **B. The 350 ms throttle of `retrieveSeenImageDBentry()` never engages.** Its `lastInvoked := A_TickCount`
  (:76048) sits after the two branches that both return, so the static stays 1. Read.
- **C. The on-screen display's own timing never acts.** `CreateOSDinfoLine()` sets `prevMsg := msg` and only then
  tests `If (prevMsg!=msg)` before `lastInvoked := A_TickCount` (:100335-100337), so `lastInvoked` stays 1. Three
  checks hang on it and never act: the hold that keeps an error message on screen when it is about to be removed
  (:100229-100237), the 95 ms merge of messages in quick succession (:100247), and the box that shows an error a new
  message would cover (:100254). The panel's own failure messages (E1, E2) get no hold either. Read.

## Checked and found correct

- «Cancel» closes the panel and changes nothing (M1); Enter in «Replace with» runs «Perform» (M2); Alt+A cancels and
  Alt+P performs (M3).
- «Selected files only» with nothing selected: «WARNING: There are no files selected in the QPV list», and the
  panel stays open (L2).
- «Selected files only» changes the selected entries only: with «old\a.png» and «x\d.png» selected, «old\b.png»
  stays, on a plain list and on a database list (N1, N2). On a database list each record is written from the list's
  new path, by its record number, so the list and the database agree (N1; L1, where the filled-in text also
  reached «oldies», shares the matching rule of finding 1).
- Whole-path mode on a database list: the database and the list agree (B3).
- With both strings ending in a separator, folder mode moves exactly the folder and its subfolders (A3).
- A folder-mode collision on a database list refuses the whole folder and says so; nothing changes (E2).

## Settled earlier, not reported again

- `e5315dc` (2026-07-31): folder mode renames only the folders.
- 2026-08-27: «Selected files only» on database lists, which writes the records by their numbers; the folder renames
  no longer inherit the checkbox; folder mode reaching the seen images database. Left as they were then: entries
  marked `||` (files deleted from the disk) are rewritten in the list but not in the database by «Selected files
  only». Finding 3 takes in the unbalanced pair of separators noted then as left alone.
- `9aecb75`, `8cacdee`, `cce29a6`, `ffccbb3` (2026-11-16): the search ignores the case of every letter in
  the three passes; two records of one file in the seen images database merge, and a record waits its turn while
  another still holds its new path.
- A selection of one file does not exist: `getSelectedFiles(0, 1)` clears it when the panel opens, so «Selected
  files only» needs two files or more. QPV's rule for every batch tool.

## Decisions to make before fixing

1. **Findings 1 and 2, the matching rule of folder mode.** (a) Whole folders from the start of the path, in every
   target: a separator added to both strings before the replace, and the list loop matching the start of the
   folder only, as the database pass does; (b) whole folder names anywhere in the path (`\pics\` matched at any
   depth); (c) keep the text rule and make only the database pass follow it. My recommendation: (a), which is the
   contract `SearchAndReplaceThroughIndex()` already states and the one its rename callers rely on. **Answered
   2026-11-26: (a)**, in all four targets, the seed folders through `renameDynamicFoldersEntries()` (`474793a`).
2. **Whole-path mode and finding 1.** Keep the literal replace (a part of a name can be fixed), or match whole
   names there too? **Answered 2026-11-26: the literal replace stays.**
3. **Finding 3.** In folder mode, balance the separators silently (both strings end with one), or refuse a pair
   that is unbalanced, with a message? In whole-path mode, warn when the replace would change the number of
   separators, or leave it literal? Should an empty «Replace with» be refused? **Answered 2026-11-26 for folder
   mode**: balanced silently (`474793a`); an empty string is refused there and for the seed folders (`c2fde82`).
   Whole-path mode is still open.
4. **Finding 4, a filtered database list.** (a) Put the filter back after the pass; (b) limit «Current files list»
   to the entries the filter shows and write their records by number, as «Selected files only» does; (c) ask
   first. And on a plain list: keep «what the filter shows», or rewrite the list behind the filter too?
5. **Finding 5, a new path that is taken.** (a) Skip the entry and count it as failed, so the list stays in step
   with the database; (b) merge the two entries, dropping the moved one; (c) ask. On a plain list: the same, or
   keep the duplicate?
6. **Finding 6.** Move the captions, the audio notes and the folders list as `renameStaticFolderSQLdb()` does: in
   folder mode only, or in whole-path mode too (the captions are keyed by full path)? And the folders list of an
   `.SLD` file?
7. **Finding 7.** The wording of a closing message for the seed folders (a count, and «nothing matched»); whether a
   replace onto a folder already listed is refused, as the seed folders panel's rename refuses it, or merged by
   `cleanDynamicFoldersList()`. Since `474793a` it is merged, a consequence of `renameDynamicFoldersEntries()` (H5).
   This question was not put to Marius and is still open, as is the closing message.
8. **Finding 8.** In private mode, leave the two strings out of the messages, or show them masked?
9. **11.1 and 11.2.** Should the panel open with fewer than three files, for targets 3 and 4 or for all of them?
   Should target 3 work while recording of seen images is off?

With decisions 1 to 3, Marius was offered four guards on 2026-11-26. He took two: the empty folder strings refused
(`c2fde82`), and «Replace with» in lower case on a database list (`12fc79d`). He left two aside: filling «Search for»
with the leading «\\» of a network path (11.5), and refusing, in folder mode, a «Search for» that is not a full
folder path. Such a text now ends with «0 records were modified».

## How this was checked

- **Static reading** of `development` at `bbc49e4`: the panel, its button, the three passes, the routes that open
  the panel, the folder renames that share `SearchAndReplaceThroughIndex()`, and each helper before a call to it
  was judged. The memories of the earlier work on the panel were read first.
- **The real application under headless Wine**, on the stock AutoHotkey 1.1.37.02, started on one image, with test
  functions appended to a scratch copy of the script. A test makes the files under `<work>`, opens their folder as
  a list (for a database list it saves that list as an `.SLDB` and opens it), opens the panel through
  `PanelSearchAndReplaceIndex()`, sets the fields with `GuiControl`, and posts a click (`BM_CLICK`) to «Perform»
  or «Cancel», or Enter, Alt+A or Alt+P to the panel. The handlers then run as they are. The log keeps the
  messages, the list before and after, and the database rows.
- **The scratch copy differs from the source** in that messages, tooltips and journal errors are logged, and so
  are the calls to `BTNperformIndexSearchReplace()` and `recreateDynaFoldersSQLdbList()`. In
  `SearchAndReplaceSeenDB()` it also logs the value of the progress test at the first record and the time the
  pass took (finding 9).
- **Aids**, each named where it was used: the seen images database and the seed folders of a database list
  written straight with SQL (findings 7, 9, 11.2, 11.3); a network path put into the list directly (11.5); the
  thumbnails view's lookup simulated with `thumbsDisplaying=1` (11.3); the caption written through
  `updateSQLdbEntryCaption()` (finding 6).
- **Batches**: A (plain list, folder mode, the filled-in text), B (database list, folder mode), C (one separator),
  D (filtered lists), E (taken paths), F (the identical check), G (the seen images database), H (the seed folders),
  I (private mode), J (captions and the folders list), K (two files), L («Selected files only» with the filled-in
  text and with nothing selected, a network path), M (the buttons and keys), N («Selected files only» with one
  matching entry left unselected).
- **Read, not run**: the folders list of an `.SLD` file (finding 6), what the display paints (finding 8), 11.4 and
  «Seen in passing». An empty «Replace with» (finding 3), read at first, was run on 2026-11-26 (Y4, Y4b).
- **Not run on Windows**, and not run at all: real network shares; Quick search actions or user-defined shortcuts
  fired while the panel is open; collisions inside the seen images database; very large plain lists.
- **Every plain list run was a folder opened as a list.** No `.SLD` file was run, so the save question and
  `currentFilesListModified` after a replace are read only. The seed folders target ran on a database list only.
- **The network-path seed folders of H3 and H4 were written with SQL.** That the app's own «add seed folder»
  (`addNewFolder2list()`) stores such a path is read only (:67078-67086).
- **Not run either**: the panel under «Large UI fonts» or the dark mode; no screenshot was taken.
- **The kit**: `.claude/scratch/search-replace-panel-2026-11-25/` (README.txt). `app/run-sr.sh <tag> <test
  function> [revision]` runs one batch, under a minute each, and writes `app/results/<tag>.txt`; the logs of this
  report are kept there. It reuses the files filter kit's `patch.py`, `patch-ff.py` and shared helpers, and adds
  `patch-sr.py` and `test-sr.ahk`.
- **The fix of findings 1 and 2, 2026-11-26**: the kit `.claude/scratch/search-replace-1-2-2026-11-26/`
  (README.txt), on the stock AutoHotkey 1.1.37.02.
  - **The texts.** `head.ahk` is `57d1f81`. `mkfix.py` builds `s1.ahk`, `s2.ahk` and `s3.ahk`, the fix's three
    steps over `57d1f81`: the texts every run of the fix used, each loaded by `loadcheck.sh`. On Marius's choice
    the commits were then rebased onto his `1fbbb4c`, which re-braces `VPflipImage()` and so adds five lines above
    every line cited here. `mkfix.py` on `1fbbb4c` (`rebase/`) gives the texts of `474793a`, `c2fde82` and
    `12fc79d`, identical to the commits (SHA-256) and loaded too; they differ from the run texts by his edit alone.
  - **The panel's batches.** Every batch, A to N, ran on `57d1f81` and on `s3.ahk` (`run-panel.sh`). X (the letter
    case, entries marked `||`, network paths, drive roots), Y (letters outside A-Z, a nested move, a filtered list,
    empty and identical strings) and Z (empty and identical strings for the seed folders and the seen images
    database, a change of letter case alone on a database list) are new, and also ran on both texts
    (`test-fix.ahk`, `run-x.sh`). Their logs print paths with their letter case; those of A-N do not.
  - **The other callers.** The rest of the code that calls `SearchAndReplaceThroughIndex()` ran on both texts
    (`run-callers.sh`): the folders tree's folder rename (T6 and T15 of the folders tree kit), the folders list
    panel's rename (static H) and the seed folders panel's rename (MG, U, Y9, D13, S85 of the seed folders kit).
    These tags name those kits' batches, not this report's. Their logs are the same on both texts (`compare.sh`
    leaves out the display noise those kits record), except U4: a direct call with the part of a name «lpha\»,
    which now matches nothing in folder mode.
  - **The differential.** `run-diff.sh` cuts the old and the new folder-mode branches out of the two texts and
    compares them. Inputs shaped as the folder renames pass them (absolute folders, both strings ending in «\»): they
    agree on 15,840 files list cases in each of the three modes, on 504 database records and on 7,920 seen images
    paths. The shapes the fix changes on purpose (no trailing «\», one only, a part of a path) differ.
