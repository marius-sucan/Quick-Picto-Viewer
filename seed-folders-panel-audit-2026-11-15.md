# Seed folders panel audit, 2026-11-15

Scope: `PanelDynamicFolderzWindow()` (:96427), the panel it builds («Manage seed folders
list», Alt+U), its six buttons (a seventh, «Back», is never shown: finding 6), its keys, its
context menu
`invokePanelDynaFoldersContextMenu()` (:94064), and every function those reach, as far as a
panel action reaches them. Line numbers are `quick-picto-viewer.ahk` on `development` at
`bf72416`. The audit changed no code.

Fifteen findings. Each one says how it was checked: **run** means the real application did
it under headless Wine, on AutoHotkey_H 1.1.33.10, with the source of `bf72416`; **read**
means it follows from the code and was not run. Nothing was run on Windows. The test kit is
described at the end.

**Status, 2026-11-16, at `d05e990`.** Findings 1 to 6 are fixed: 1 and 2 in `fe812ec` and
`32c435d`, 3 to 6 in `1e1c2b6`, `7c031cb`, `592628d` and `d05e990`, with Marius's choices
(decisions 1 and 3 to 7, settled below; decision 2 for «Remove» alone). The question that
fixes finding 2 also fixes finding 11 for this panel; the one that fixes finding 3 also fixes
finding 13. Findings 14 and 15 are partly fixed; the others are open. A fixed section ends
with a note on what the code does now, with its lines at the commit the note names
(`32c435d` for findings 1 and 2, `d05e990` for findings 3 to 6); every other line number is at
`bf72416`.

**Follow-ups, 2026-11-16, at `0ab5622`**, with Marius's answers: «Remove» answers «No» by
default (`ad55c7f`), and its «Yes» also drops the folder's rows from the folders list
(`0ab5622`); seen in passing D is fixed, for every mode of the search and replace through the
index (`9aecb75`); seen in passing E is partly fixed: a new instance, «Rename index entry» and
the refresh take a drive root (`08ae6f5`, `c68164c`, `905461a`), and the refresh after a single
image rescans its folder without the subfolders (decisions 8 and 9). The notes on them cite
lines at `0ab5622`. Then the Search and Replace panel's two other targets ignore case too, the
seen images list (`8cacdee`, decision 10) and the seed folders list (`cce29a6`), and the latter
takes a list of drive roots alone and marks the list as modified (`557c018`); lines at
`557c018`.

**Findings 7 to 9, 2026-11-17, at `78120a1`**, with Marius's answers: «Recursive folder scan»
marks the list as modified (`ce1b5f8`); «Rename index entry» carries the folders list along with
the files, in a database with their recorded dates, captions and audio notes and with the new
path in lower case, on a cached .SLD list too (`caa77ef`, decisions 11 and 12); on a seed folder
scanned without its subfolders the panel's actions reach the files placed directly in it, and
«With a new QPV instance» opens the folder alone (`78120a1`, decision 2). The notes on the three
cite lines at `78120a1`, those that name `ce1b5f8` and `caa77ef` too. One question is left
(decision 13).

**Findings 10 to 14, 2026-11-17, at `2400d23`**, with Marius's answers: a seed folder scanned
without its subfolders, added or rescanned on a cached .SLD list, gets its row in the folders
list (`20d9d3b`); the count columns cover the whole index while a files filter is on, keep their
values when a count is stopped, follow «Select files», «Deselect files» and «Deselect all
(files list)», leave «Difference» empty until the disk is counted, and sort «%» and «Size
(MB)» as decimals (`b55b247`, decisions 14 to 16); «Paste list» takes quoted paths, marks the
list as modified only when it changed, and says that the folders it adds need a rescan
(`2400d23`, decision 17). Finding 11 needed no change: the folders list panel's «Rescan
folder(s)» has asked first since `26c47e1` (2026-11-13), before this audit began, which the
note on finding 11 had missed. The notes on the four cite lines at `2400d23`.

Findings 1 to 4 lose data: seed folders vanish from the list for good; index entries and
database rows of folders the user did not touch are deleted; a protected folder's files can
be deleted from the disk. Each needs nothing unusual: a seed folder scanned without its
subfolders, a folder on a drive that is not plugged in, or a folder name with a letter such
as «É» or «Ș».

## Terms

- **Seed folders list**: what this panel shows, the folders the index is generated from. The
  code calls them «dynamic folders»: `DynamicFoldersList` in memory, the `[DynamicFolderz]`
  section of a .SLD file (`DF1=`, `DF2=`, …), the `dynamicfolders` table of a database.
  Every entry is stored in lower case; since `592628d`, without a trailing separator, a drive
  root as `d:`.
- **`|` entry**: a seed folder scanned without its subfolders. It is stored with a leading
  `|`; the panel shows it without the `R` in the «(?)» column.
- **Recursive entry**: a seed folder scanned with its subfolders (`R` in «(?)»). No other
  entry can sit inside one: `cleanDynamicFoldersList()` drops it. A `|` entry can have other
  entries inside it.
- **Index**: QPV's files list, `resultedFilesList`.
- **Folders list**: the list of the Ctrl+U panel, `PanelStaticFolderzManager()`, one row per
  folder that holds indexed files (`newStaticFoldersListCache`, the `[Folders]` section of a
  cached .SLD file, the `staticfolders` table of a database).
- **Plain list**: a folder opened in QPV, or a list never saved.
- **Cached .SLD list**: a plain-text list saved with its files. **Uncached .SLD list**: one
  saved without them; opening it scans the seed folders.
- **Database**: an .SLDB list.
- **Missing folder**: a seed folder that is not on the disk right now: a drive not plugged
  in, a share not reachable, a folder renamed or moved.
- **Row**: a row of the panel's table. **The folders list audit**:
  `static-folders-panel-audit-2026-11-10.md`, cited by its finding and note numbers.

## Summary

| # | Finding | Harm | Checked | Status at `2400d23` |
|---|---------|------|---------|---------------------|
| 1 | A .SLD list loses every `\|` entry: right after a save, and for good at the next save; an uncached list never scans them | high | run | **fixed**, `fe812ec` |
| 2 | A missing folder is dropped from the seed folders list by a save, by «Paste list» and by every rewrite of a database's list | high | run | **fixed**, `32c435d`: kept; «Rescan all» and «Rescan folder» ask to keep or purge it (decision 1) |
| 3 | «Remove» answered «Yes» on a `\|` entry also removes the files of the seed folders inside it, in a database for good | high | run | **fixed**, `1e1c2b6`: asked first; «Yes» spares what the seed folders inside it index (decisions 2, 3); «No» by default and the folders list rows dropped since `ad55c7f`, `0ab5622` |
| 4 | Plain and .SLD lists: a folder name with a capital letter outside A-Z defeats counting, selecting, jumping and removing; «Rescan folder» indexes its files twice; «Set as the protected folder» does not protect it: its files can be deleted from the disk | high | run (plain list), read (.SLD) | **fixed**, `7c031cb`: compared in lower case (decision 5) |
| 5 | A drive root as a seed folder: not listed, dropped by «Remove» and «Paste list», its files dropped by «Rescan all», not loaded from a .SLD list | medium | run | **fixed**, `fe812ec`, `32c435d` and `592628d`: kept as `p:` (decision 4) |
| 6 | The Save panel's «Manage folders» button does nothing; the panel's «Back» button is never shown | medium | run | **fixed**, `d05e990`: the panel opens, with «Back» (decision 6) |
| 7 | The actions on a `\|` entry reach into its subfolders; «Difference» compares two different things | medium | run | **fixed**, `78120a1`: the files placed directly in the folder (decision 2) |
| 8 | «Recursive folder scan» does not mark a .SLD list as modified: the change is lost without a question | medium | run | **fixed**, `ce1b5f8` |
| 9 | Database: «Rename index entry» from this panel leaves the `staticfolders` table and the captions on the old paths; the folders list marks every renamed folder as changed | medium | run | **fixed**, `caa77ef`: the folders list follows the files, on a cached .SLD list too (decisions 11, 12) |
| 10 | A `\|` folder added or rescanned on a cached .SLD list gets no row in the folders list | low | run | **fixed**, `20d9d3b` |
| 11 | «Rescan folder» on a missing folder deletes its entries, in a database with their cached data | medium, a decision | run | **fixed**, `32c435d`: it asks to keep or purge (decision 7); the folders list panel asks since `26c47e1` |
| 12 | The count columns: «Difference» 0 for a folder never counted on disk, counts that follow a files filter, «Selected» not refreshed, «%» and «Size (MB)» sorted as whole numbers | low | run, read | **fixed**, `b55b247`: the whole index, a stopped count kept, the row refreshed, decimals sorted (decisions 14 to 16) |
| 13 | «Remove»: the entry is gone before the question, which has no «Cancel»; the box shows the internal `\|` | low | run, read | **fixed** by `1e1c2b6`, with finding 3 |
| 14 | «Paste list»: a trailing separator makes an entry that matches none of its files; a quoted path is dropped without a word | low | run | **fixed**: a trailing separator trimmed (`592628d`); quoted paths taken, the list marked only when it changed, a message on the rescan (`2400d23`, decision 17) |
| 15 | Small things | low | run, read | **partly fixed**: the remove box is «Remove seed folder» (`1e1c2b6`) |

---

## 1. A .SLD list loses every `|` entry

`coreLoadDynaFolders()` :87654, `SaveFilesList()` :35182-35191 and :35235,
`getDynamicFoldersList()` :34801, `OpenSLD()` :2572-2573

```ahk
If (RegExMatch(line, "i)^(DF[0-9].*\=[a-z]\:\\..)") && !RegExMatch(line, RegExFilesPattern))
```

The line must have a letter right after `=`. A `|` entry is saved as `DF2=|d:\pics`, so it
never passes. The save writes the `|` entries (:35189), then sets `DynamicFoldersList :=
"|hexists|"` (:35235), which makes the next read of the list go through this loader.

What happens (run, batch C, plain list of `pv` with `|other` added):

- saved as a cached .SLD list: the file holds `DF1=pv` and `DF2=|other`, but the seed folders
  list read right afterwards is `pv` alone, and the panel lists one row (C1);
- saved again: the file holds `DF1=pv` alone; the entry is gone from the disk too (C2);
- the list opened again: `pv` alone, while the index still holds the two files of `other`,
  now covered by no seed folder (C3);
- an uncached .SLD list: opened, it never scans `other`; the index has no file of it (C4).

The same test drops a seed folder with a one-letter name under a drive root (`d:\a` needs
two characters after the `\`; read) and a drive root (finding 5).

The loader replaced, in `b5c853e` (v4.6.5, 2020-10-28), an `IniRead` loop that took any
value of four characters or more. The folders list's loader had the same kind of test and
was widened for the folders list audit's finding 20; it now ends at the colon (:35301).

Correction: accept an optional `|` and end the pattern at the colon, e.g.
`i)^(DF[0-9]+=\|?[a-z]\:)`. A database keeps its `|` entries (run, batch E0).

**Fixed in `fe812ec`** (:87657 and :2548 at `32c435d`): the line test takes an optional `|`
and ends at the colon; the value is trimmed; `OpenSLD()` takes the seed folders list as
present when `DF1` has two characters or more, as the .SLD import already did (:65707).

```ahk
If (RegExMatch(line, "i)^DF[0-9]+\s*=\s*\|?[a-z]:") && !RegExMatch(line, RegExFilesPattern))
```

Run on the text of `32c435d` (batches C and K):

- right after the save the seed folders list is `pv` and `|other`, and the panel lists two
  rows (C1); saved again, the file keeps `DF2=|other` (C2); opened again, `|other` is listed
  (C3);
- the uncached list opened scans `|other`: its two files are in the index (C4);
- a list of the drive root alone saves `DF1=p:` and opens with `p:` (K3); a list of `P:\a`
  saves `DF1=p:\a` and opens with it (K3).

The second test of the line, against `RegExFilesPattern`, can never match a `DFn=` line: that
pattern is anchored on a drive letter at the start. It is left as it was.

## 2. A missing folder is dropped from the seed folders list

`SaveFilesList()` :35185, `addDynamicFolderSQLdb()` :65213 (through
`recreateDynaFoldersSQLdbList()` :34606), `BTNpasteDynaFoldersList()` :96976

Three places keep an entry only `If FolderExist(…)`:

- saving a .SLD list (:35185);
- every rewrite of a database's `dynamicfolders` table: «Add», «Remove», «Paste list»,
  «Recursive folder scan», «Rename index entry», «Rescan all», a save as .SLDB (:65213);
- «Paste list», for every entry of the list, not only the pasted ones (:96976).

What happens (run):

- batch C5: `third` moved away, the list saved: the file holds `DF1=pv` alone; with `third`
  back the list opened lists `pv` alone, while its index holds the two files of `third`;
- batch C6: `other` moved away, `fourth` pasted: the list becomes `pv`, `fourth`, `third`;
  with `other` back it is still gone;
- batch E3, database: `fifth` moved away, «Recursive folder scan» run on another row (its menu
  function called): the table keeps `other\sub`, `third` and `|pv`; the database opened
  again, with `fifth` back, has no `fifth`.

A seed folder on an unplugged drive or an unreachable share leaves the list the first time
the list is saved or edited, without a word. Its files stay in the index, with nothing left
to rescan them. «Copy list» (:96951) and «View list as a folders tree» (:96704) leave missing
folders out as well; «Copy list» then says «Dynamic folders list copied to clipboard»
(run, batch C7: `third` away, the clipboard holds `pv` and `fourth`).

For the folders list, Marius chose to keep such folders (decision 9 of the folders list
audit, `17d90dd`). Correction: decision 1.

**Fixed in `32c435d`**, by Marius's answers to decision 1. What the code does now, lines at
`32c435d`:

- a seed folder that is not on the disk stays: in a saved .SLD list (:35184), in every
  rewrite of a database's `dynamicfolders` table (:65213), and in «Paste list», which keeps
  the listed entries as they are (:97026). «Copy list» copies it too (:97007).
  `addDynamicFolderSQLdb()` dates such a folder «-»; it also writes the folders list's
  `staticfolders` table, so a database's folders list keeps the rows of such folders when it
  is rebuilt («Rescan all», «Regenerate this folders list», a save as .SLDB);
- a pasted folder that is not on the disk is skipped, and the panel then says how many lines
  were skipped (:97063);
- «Rescan all» asks once, without listing them, when seed folders are missing: «Keep»,
  «Purge» or «Cancel» (`RegenerateEntireList()` :87764-87786, `getMissingSeedFolders()`
  :97864). «Keep» carries their indexed files over to the rebuilt index, after the scanned
  files (:87795-87804, :87848-87853); in a database their rows were never touched. Their
  folders list rows stay, dated «-». «Purge» removes them from the seed folders list
  (`dropSeedFolders()` :97879), with every file indexed under them, subfolders included (in
  a database `images` and `imagesPixels` rows, inside the rescan's transaction), and the
  folders list, rebuilt by the rescan, has no row for them. «Cancel» stops before anything
  changes;
- «Rescan folder» on a missing seed folder asks «Keep» or «Purge», with the folder's path
  (`BTNrescanDynaFolder()` :97650-97668). «Purge» goes through `purgeSeedFolder()` (:97674):
  the entry and the entries inside it leave the seed folders list, its rows leave the folders
  list (loaded first on a cached list, so a save cannot bring them back) and the
  `staticfolders` table, and `remFilesFromList()` removes its files.

Run on the text of `32c435d`, with every earlier batch run again and compared line by line
with the logs before the fix (batches A, B, G and I give the same lines):

- batch C: `third` away while saving: the file keeps `DF2=third`, the list opened again has
  it (C5); `other` away during «Paste list»: kept (C6); «Copy list» copies `other` and `third`
  while `third` is away (C7); `fifth\` and a quoted path pasted: «1 pasted line(s) skipped»
  (C8);
- batch E3, database: «Recursive folder scan» with `fifth` away keeps `fifth` in the table,
  and the database opened again lists it;
- batch J, «Rescan all» with `other` away (one seed folder missing), on a plain list:
  «Cancel» changes nothing; «Keep» keeps the three files of `other` and `other\sub`, at the
  end of the index; «Purge» drops the entry and the three files. On a cached .SLD list:
  «Keep», then a save, gives `DF2=other` and the rows `Fi3=-*&*other`, `Fi8=-*&*other\sub`;
  «Purge», then a save, gives neither. In a database: «Keep» leaves the three rows, the
  `dynamicfolders` row and two `staticfolders` rows dated «-»; «Purge» deletes all of them;
- batch K, F5 on the missing `other`, on a cached .SLD list and in a database: «Keep»
  changes nothing; «Purge» removes the entry, the three files, the folders list rows and,
  in a database, the rows of the three tables; the list saved afterwards has neither the
  entry nor the rows;
- batch L, two seed folders missing at once, `|other` and `other\sub` inside it: the box says
  «2 seed folders are not on the disk now…», without their paths. Plain list: «Keep» keeps
  the four files, after the scanned ones; «Purge» drops both entries and the four files. In a
  database: «Keep» leaves the rows of both folders in `images`, both entries in
  `dynamicfolders` and two `staticfolders` rows dated «-»; «Purge» deletes all of them.

Three things to know. Under «Keep» the index holds files that are not on the disk: viewing
one gives QPV's «File not found» message, as for any missing file. «Purge» leaves the
captions and audio notes of the purged images in a database's `imagesData` table, as
«Remove» answered «Yes» does. «Rescan folder» → «Purge» goes through `remFilesFromList()`,
which finding 4 describes: on a plain or .SLD list, a folder whose name has a capital outside
A-Z leaves the seed folders list but its files stay in the index (run, batch M: `été` purged,
the two files of `Été` still indexed; fixed with finding 4 in `7c031cb`). «Rescan all» →
«Purge» is not affected: it rebuilds the index.

## 3. «Remove» answered «Yes» on a `|` entry also removes the files of the seed folders inside it

`BTNremDynaSelFolder()` :97036, `remFilesFromList()` :97800-97803

```ahk
remFilesFromList(StrReplace(folderu, "|"))
```

The `|` is dropped, so the removal covers the whole subtree, and no list of the other seed
folders inside it is passed. A rescan does pass one: `coreAddNewFolder()` hands
`getDynaFoldersInside()` to `remFilesFromList()` (:66514), which spares them.

What happens (seed folders `pv`, `|other` and `other\sub`; «Remove» on `|other`, «Yes»):

- plain list (run, batch B6): the seed folders list keeps `other\sub`, the index loses its
  three files with the two of `other`;
- database (run, batch E1): the same, and the `images` table loses the three rows of
  `other\sub`, with whatever was cached for them.

A recursive entry cannot hold another entry, so it does not meet this.

Correction: keep the `|` and pass `getDynaFoldersInside()`, as the rescan does; see also
decision 2.

**Fixed in `1e1c2b6`**, by Marius's answers (decision 3, and decision 2 for «Remove»): one
question before anything changes; «Yes» removes the folder's files with its subfolders, except
the files another seed folder covers. What the code does now, lines at `d05e990`:

- «Remove» asks every time, also when the index holds one file or none
  (`BTNremDynaSelFolder()` :97095): «The seed folder will be removed from the list, with every
  file indexed from it, subfolders included», the path without the `|`, «Do you want to
  continue?», «Yes» / «No». When seed folders sit inside it, the box adds «The files of the
  seed folders placed inside it stay in the index.» «No» changes nothing.
- «Yes» removes the entry, then every file indexed under the folder, subfolders included, for a
  `|` entry as for a recursive one, except what the seed folders inside it index: a recursive
  one its whole subtree, a `|` one the files placed directly in it. `getDynaFoldersInside()`
  (:97869) takes them from the seed folders list the panel shows, and `remFilesFromList()`
  (:97958) spares them, as a rescan does. A file no seed folder covers goes, also when it sits
  in a subfolder of a seed folder placed inside. In a database the rows go with their cached
  data.

Run on the text of `d05e990` (batch N; plain list with the seed folders `pv`, `|other`, the
recursive `other\rec` and `|other\pipe`; the index also holds `other\orphan\x1.png` and
`other\pipe\deeper\p2.png`, which no seed folder covers):

- «No» on `|other`: the list and the index unchanged (N1; at `e62ea25` the entry went, its
  files stayed);
- «Yes» on `|other`: `other\o1.png`, `other\o2.png`, `other\orphan\x1.png` and
  `other\pipe\deeper\p2.png` go; `other\pipe\p1.png`, `other\rec\r1.png` and
  `other\rec\deep\r2.png` stay, with the entries `|other\pipe` and `other\rec` (N2; at `e62ea25`
  all seven went). In a database the same rows go and the same stay (N5);
- `|Été` holding the recursive `Été\sub`: «Yes» on `|été` removes `Été\e1.png` and keeps the two
  files of `Été\sub` (N3). On the text of `1e1c2b6` alone nothing goes: that is finding 4, fixed
  by the next commit;
- an index of one file: the question comes; «No» keeps everything; «Yes» empties the index,
  then QPV's «No files left in the index» box comes, as after any removal that empties it
  (N4);
- batches B6 and E1 again: `other\sub` keeps its three files, and in the database its rows.

**Follow-up** (`ad55c7f`, `0ab5622`, Marius's answers), lines at `0ab5622`:

- «No» is the default answer of the question, so Enter answers «No»
  (`BTNremDynaSelFolder()` :97095). Run: in every batch that removes, the box shows the
  default mark under «No».
- «Yes» also drops the folder's rows from the folders list, as «Purge» does: in memory, in a
  cached .SLD list's next save, and in a database's `staticfolders` table. The rows of the
  folders that the seed folders inside it still index stay, by the rule that spares their
  files. «Remove» and «Purge» share `dropFoldersListRows()` (:97717), called once the files
  are removed: `remFilesFromList()` drops a files filter first, so a folders list built from
  the index, for a list that stores none, is complete. On such a list «Remove» now builds the
  folders list, one pass over the index.

Run on the text of `0ab5622` (batch R, on batch N's seed folders, and batch V):

- plain list, its folders list generated first: 11 rows; after «Yes» on `|other`, 8: `other`,
  `other\orphan` and `other\pipe\deeper` go, `other\pipe`, `other\rec` and `other\rec\deep`
  stay (R1; at `89840b5` the 11 rows stayed);
- a cached .SLD list: the same 8 rows in the `[Folders]` section of the next save (R2); a
  database: the same 8 in `staticfolders` (R3); batch E's database: `staticfolders` loses the row
  of `other` and keeps `other\sub` (E4);
- an uncached .SLD list with a files filter on (F3 on `third`), «Yes» on `other`: the folders
  list holds the six folders still indexed, not the filtered one alone (V1; with the function
  called before the removal it held `third` alone);
- «Purge», which shares the function: batches J to M give the same results (J and L differ only
  in which file the random display meets).

## 4. Plain and .SLD lists: a folder name with a capital letter outside A-Z

`cleanDynamicFoldersList()` :87672; `BTNcountFilesDynaFolders()` :96926;
`BTNselFilesStaticFolder()` :96857; `BtnPanelStaticJumpFirst()` :97111;
`remFilesFromList()` :97801; `setContaintFolderAsProtected()` :40162 with
`batchFileDelete()` :40529-40536

Every seed folder is stored in lower case: `Format("{:L}", …)` turns `Été` into `été` and
`Ștefan` into `ștefan`. The index keeps the spelling found on the disk. The actions compare
the two with `InStr()`, which ignores case for A to Z only: the script sets no
`StringCaseSense`. Measured in the run: `InStr(…\Été\e1.png, …\été\)` gives 0, the same
call on `Alpha` gives 1 (batch A4).

What happens (run, plain list, `Été` and `Ștefan` added as seed folders):

- «Set as the protected folder» on `été` stores `…\été` as the protected folder. The delete
  then compares it with each file's folder, `…\Été`, by `=` (:40536): no match. Run (batch
  I1): both files of `Été` selected, «delete selected files»: «2 out of 2 selected files
  deleted», and they are gone from the disk. The same steps on a folder `Ascii`: «Skipped
  files: 2», both kept;
- F11 («Count indexed files in folder») on `été`: «Files» 0; F10 then gives 2 on disk and
  «Difference» 2;
- «Select files»: nothing is selected;
- «Jump to first indexed file»: «WARNING: No file found to be indexed from the selected
  folder»;
- F5 («Rescan folder»): the index holds `Été\e1.png`, `Été\e2.png`, `été\e1.png` and
  `été\e2.png`, 19 entries for 17 files. The removal misses the old entries and the scan adds
  the files again under the lower-case spelling. A save would keep both (read);
- Delete («Remove folder from this list»), «Yes», on `ștefan`: the entry goes, its three
  files stay in the index.

The F11 to Delete steps are batch A4. Since `32c435d` the same goes for «Rescan folder» →
«Purge» on such a folder when it is missing: the entry goes, its files stay (run, batch M).

F3 works: it filters with a case-insensitive regular expression. «Rescan all» works too: it
empties the index first (read). A .SLD list builds its index the same way as a plain list
and meets the same (read). A database is not affected: the index takes its paths from the
database, in lower case (run, batch E5: F11 counts 2, F5 leaves 2).

Correction: compare lower case with lower case, as the folders list panel does
(`Format("{:L}", …)` on both sides, :96821 and :96855), in the functions above and in the
two protected-folder tests: `InListMultiEntriesRemover()` :33957-33961 (index entries) and
`batchFileDelete()` :40532-40536 (files); see decision 5.

**Fixed in `7c031cb`**, by Marius's answer to decision 5: the seed folders list stays in lower
case, and both sides are compared in lower case. Lines at `d05e990`:

- F11 (`BTNcountFilesDynaFolders()` :96983), «Select files» and «Deselect files»
  (`BTNselFilesStaticFolder()` :96871), «Jump to first indexed file»
  (`BtnPanelStaticJumpFirst()` :97164, which the folders list panel shares: its jump missed
  such a folder too);
- the removal under F5, «Remove» and «Purge» (`remFilesFromList()` :97958), and the seed
  folders it spares (`isPathInGivenFolders()` :97935, `getDynaFoldersInside()` :97869);
- the protected folder: «delete selected files» (`batchFileDelete()` :40485), «Remove file
  entries from the list» (`InListMultiEntriesRemover()` :33912), the on/off test of «Set as the
  protected folder» (`setContaintFolderAsProtected()` :40160), and its check mark in the menus
  of both folder panels, of the folders tree and of the omnibox's folders. The protected folder
  is stored as given: in lower case from the two panels, in the spelling of the disk from the
  folders tree and the omnibox.

F5 on `Été` now replaces its two entries with `été\e1.png` and `été\e2.png`: the folder part in
lower case, as for every rescanned folder (seen in passing A).

Run on the text of `d05e990`:

- batch A4 again: F11 on `été` counts 2, and F10 then gives a difference of 0; «Select files»
  selects its two files; «Jump» shows `Été\e1.png`; F5 leaves 17 entries for 17 files; Delete +
  «Yes» on `ștefan` removes its three files;
- batch I1 again: «Set as the protected folder» on `été`, then «delete selected files» on its
  two files: «Skipped files: 2», both kept;
- batch M again: «Rescan folder» → «Purge» on the missing `été` removes its two files;
- batch O (folders `Ăla`, `Îna`, `Été`, `Ștefan`, `Ûnu`): `ăla` protected from this panel,
  sub-paths off: its two files kept, the one in `Ăla\Sub` deleted (O1); `îna` protected,
  sub-paths on: both kept (O2), and «Remove file entries from the list» keeps their entries
  (O3); protected with the disk spelling `Îna`, as the folders tree gives it: the check mark
  shows in this panel's menu, and «Set as the protected folder» from this panel turns the
  protection off (O4; at `e62ea25`, no mark, and the protection was set again in lower case);
  F11, «Select files» and «Jump» on `été` (O5); the folders list panel's «Jump to first indexed
  file» on `ștefan` shows `Ștefan\s1.png` (O6; at `e62ea25` «No file found»); «Rescan all»
  with `Ștefan` missing, «Keep»: its three files stay, as before (O7); in a database, `Ûnu`
  protected with the disk spelling: both files kept (O9; at `e62ea25` deleted).

Left: F2 from this panel renames the index through a search and replace that ignores the case
of A to Z only (seen in passing D).

## 5. A drive root as a seed folder

`uiPopulateDynamicFolderzList()` :98808; `BTNremDynaSelFolder()` :97021;
`BTNpasteDynaFoldersList()` :96976; `BTNcopyDynaFoldersList()` :96951;
`BTNshowDynamicFoldersInTreeView()` :96704; `RegenerateEntireList()` :87766, :87787;
`coreLoadDynaFolders()` :87654; `OpenSLD()` :2548

«Open folder» stores a drive root as `P:`: `OpenFolders()` trims the separator (:64889).
«Add» stores it as `P:\`: the folder dialog gives the root that way (`lib/shell-stuff.ahk`
:331, read) and `addNewFolder2list()` keeps it.

What happens (run, batch D, a scratch folder mapped as drive P:, five images in it):

- P: opened: the seed folders list is `p:`, and the panel lists no row: it skips lines under
  three characters (:98808). With `other` added, the panel lists `other` alone (D1);
- «Copy list» copies `other` alone (D2, :96951);
- «Rescan all»: the index keeps the two files of `other` and loses the five of P:. It empties
  the index first, then skips every line under four characters (:87787) (D3);
- «Remove» on `other`, answered «No»: the seed folders list is empty. «Remove» keeps only the
  lines that match `^(.\:\\.)` (:97021) (D4);
- `P:\` added with «Add»: listed as `p:\`; «Rescan all» drops its files again; «Paste list»
  drops the entry (:96976) (D5);
- saved as a .SLD list: `DF1=p:`; opened again: an empty seed folders list (D6). Also in the
  folders list audit, note D: `OpenSLD()` takes the list as present only when `DF1` is longer
  than two characters (:2548).

A whole camera card or external drive opened as a folder is a drive root.

Correction: decision 4, then the same form accepted in the eight places above.

**Partly fixed** by `fe812ec` and `32c435d`: a drive root loads from a .SLD list, also as its
first entry (run, batch K3; D6 now opens with `p:`), and «Paste list» keeps the listed
entries as they are, `p:\` included (run, batch D5).

**Fixed in `592628d`**, by Marius's answer to decision 4: a drive root is kept as `p:`. Lines at
`d05e990`:

- `cleanDynamicFoldersList()` (:87691), which every list goes through when it is read, drops
  the trailing separators of every entry: `p:\`, as «Add» stored it and older lists hold it,
  becomes `p:`, and `d:\pics\` becomes `d:\pics`. «Add» (`addNewFolder2list()` :66437) and
  «Paste list» (:97052) trim them too;
- the tests that wanted a character after `:\`, or three or four characters, take `p:`: the
  panel's rows (`uiPopulateDynamicFolderzList()` :98981), «Remove» (:97095), «Copy list»
  (:97030), «Paste list», also its test for a list without a file name yet, «View list as a
  folders tree» (:96784), «Rescan all» (`RegenerateEntireList()` :87769: the empty-list test,
  and the scan, which now asks `FolderExist()`), the missing seed folders question
  (`getMissingSeedFolders()` :97893), and the database's `dynamicfolders` table, which left
  `p:` out at every rewrite, the save as .SLDB included (`recreateDynaFoldersSQLdbList()`
  :34616).

Run on the text of `d05e990` (batches D and P, drive P: mapped):

- the root opened: the panel lists `p:` (D1, P1); F11 counts its five files and F5 rescans them
  (P1); «Copy list» copies `p:` (D2, P2), and «View list as a folders tree» is handed it (P2);
  «Rescan all» keeps its files (D3, P2);
- «Remove» on another seed folder keeps `p:` (P3, «Yes»; D4, «No», now changes nothing);
  «Remove» on `p:`, «Yes»: its files go (P7);
- `P:\` added with «Add»: kept as `p:`; «Rescan all» keeps its files (D5, P4);
- «Paste list» of `P:\a\`, `P:\Sub` and `third\`: `p:\a`, `p:\sub` and `third`; then of `P:\`:
  `p:`, which takes in the two entries inside it (P5);
- a .SLD list holding `DF1=p:\`, `DF2=…\third\` and `DF3=q:`, with no drive Q:: it opens with
  `p:`, `third` and `q:`, all three listed; «Rescan all» asks about `q:`, and «Keep» keeps it
  (P6; at `e62ea25` `q:` was not listed, nothing was asked, and the files of P: were dropped);
- an uncached .SLD list of `p:` and `other` scans both, as it did before (P8);
- a database of `p:` and `other`: its `dynamicfolders` table holds `p:` after the save and
  after «Recursive folder scan» wrote the table again; opened again, it lists `p:` (P9; at
  `e62ea25` the save already left it out); then, with `P:\n1.png` new and `P:\r1.png` deleted,
  «Rescan all» gives the row of `n1.png` and drops the row of `r1.png`; F5 on `p:` adds the new
  `n2.png` without a second row for the others; «Remove» on `p:`, «Yes», deletes every row of
  P: and its entry, `|other` stays (P10, log `p-f2`).

The index then holds the root's files as `p:\…`, the drive letter in lower case, as for any
rescanned folder (seen in passing A). The places outside this panel that do not take a drive
root are seen in passing E.

## 6. The Save panel's «Manage folders» button does nothing

`PanelSaveSlideShowu()` :44243, `BTNopenPanelDynamicFolderzWindow()` :44281,
`PanelDynamicFolderzWindow()` :96429-96430, :96457-96462

```ahk
PanelDynamicFolderzWindow(dummy:=0) {
    Static LViewDynas, hasWarned := 0
    If AnyWindowOpen
       Return
```

The button calls `PanelDynamicFolderzWindow("reopen")` while the Save panel is open, so the
function returns at once.

What happens (run, batch A1): a click on «Manage folders» leaves `AnyWindowOpen` at 36 and
the Save panel on screen. Nothing is said.

The test came with `d88e930` (v5.8.8, 2023-02-21, customizable keyboard shortcuts). The
panel's «Back» button exists only in the «reopen» mode (:96457-96460), so it has not been
shown since. Opened from the menu, the panel has no «Back» (run, batch A2).

Correction: decision 6.

**Fixed in `d05e990`**, by Marius's answer to decision 6: «Manage folders» closes the Save
panel, then opens this one with «Back» (`BTNopenPanelDynamicFolderzWindow()` :44295); the `If
AnyWindowOpen` test stays for every other route. «Back» closes this panel, then opens the Save
panel (`BTNdynaFoldersBack()` :96561), as the caches overview's «Back» does: left to
`createSettingsGUI()`, the close goes through `CloseWindow()`, which refuses for a second after
a message box closes, and the Save panel's controls would then land on this one. «Back» is gone
once an action opens the panel again («Add», «Remove», «Paste list», F5…): those open it the
plain way.

Run on the text of `d05e990` (batch Q, and A1 again): «Manage folders» opens this panel, with
«Back» among its buttons (Q1, A1); «Back» opens the Save panel (Q2); «Paste list» opens the
panel again, without «Back» (Q3); opened from the menu, it has no «Back» (Q4).

## 7. The actions on a `|` entry reach into its subfolders

`BTNcountFilesDynaFolders()` :96926, `BTNcountFilesDiskDynaFolder()` :35453-35454,
`BTNselFilesStaticFolder()` :96857, `BtnPanelStaticJumpFirst()` :97111,
`uiFilterListDynaFolder()` :97445-97450

Every index test is `InStr(path "\", folder "\")`: the folder and all its subfolders. A `|`
entry indexes the files placed directly in the folder only, and its subfolders may be seed
folders of their own.

What happens (run, batch B, plain list, seed folders `pv`, `|other` with 2 files,
`other\sub` with 3):

- F11 on `|other`: «Files» 5. F10 counts on disk without the subfolders, as the entry does:
  2, and «Difference» -3 (B1);
- «Select files»: 5 files, the 3 of `other\sub` among them (B2);
- «Jump to first indexed file»: `other\sub\s1.png` (B3);
- F3: the files list filtered to 5 files, `other\sub` included (B4).

«Remove» answered «Yes» is finding 3. «With a new QPV instance» opens the folder with its
subfolders (`OpenNewQPVinstance()` :2984, read).

Correction: decision 2.

**Fixed in `78120a1`**, by Marius's answers to the rest of decision 2: on a `|` entry, F11
(«Files», «Selected», «%», and so «Difference»), «Select files», «Deselect files», «Jump to
first indexed file» and F3 reach the files placed directly in the folder, as the entry indexes
them and as F10 counts the disk; F3 applies the folder filter of the folders list panel's F3
(`uiFilterListDynaFolder()` with mode 2, «Ends with» on «Folder paths», :97431-97437); «With a
new QPV instance» passes `fd=|`, through a new optional parameter of `OpenNewQPVinstance()`
(:2981, :97280): the function as committed, its launch turned into an output line, gives
`fd=|C:\windows` for `C:\windows\` and `fd=|C:` for a root (run alone; the kit's batches log
the call and start nothing). The functions read the «(?)» column in this panel alone
(:96891, :97005, :97196); a recursive entry, and the folders list panel, which shares them,
behave as before. A file indexed in a subfolder that no seed folder covers now belongs to no
row of this panel; the folders list panel lists its folder.

Run on the text of `78120a1` (batch Y7; at `803a668` in parentheses), plain list, the seed
folders `|other` (2 files), `other\sub` (3) and `|été` (1; `été\sub` a seed folder of its own),
and `other\orphan\x1.png` indexed under no seed folder:

- `|other`: F11 and F10 give 2 and 2, «Difference» 0 (6, 2 and -4); «Select files» selects 2
  (6); the jump lands on `other\o1.png` (`other\sub\s1.png`); F3 leaves 2 files (6); the new
  instance is called for the folder alone (the kit logs the call instead of starting it);
- `|été`: F11, «Select files» and F3 give 1 file, F10 1 (2, 2, 2 and 1); the jump lands on
  `Été\e1.png` (`Été\Sub\e2.png`);
- the recursive `other\sub`, and the folders list panel's «Select files», jump and F3 on
  `other`: the lines they gave;
- in a database, `|other` and `|été`: the same counts; F3 filters with
  `imgfolder LIKE '%other'` (`fullPath LIKE 'other\%'`, 6 files), as the log shortens them: the
  clauses hold the full path of the folder;
- the drive root as `|p:`: 2 files each, F3 `i)(p:)$` (5).

Batch B differs at B1 to B4 alone: 2 files where it counted, selected and filtered 5, and the
jump on `other\o1.png`.

## 8. «Recursive folder scan» does not mark a .SLD list as modified

`BtnToggleRecurseDynaFolder()` :97521-97550

«Remove» (:97016), «Paste list» (:96994) and «Rename index entry» (:97966) set
`currentFilesListModified := 1`. This one does not.

What happens (run, batch G1, cached .SLD list just saved): «Recursive folder scan» on `pv`
turns the entry into `|pv`; the list stays unmodified; `askAboutSlidesListSave()` asks
nothing; the list opened again has `pv` recursive. The change is gone, and nothing told the
user it would be.

In a database the change is written at once (:97544-97545).

Correction: set `currentFilesListModified := 1` there.

**Fixed in `ce1b5f8`**, as the correction says, when the toggle changed the list (:97658,
:97665-97666): a row that matches no entry, as in private mode, marks nothing. Run on its text
(batches Y8 and G; at `803a668` in parentheses): after «Recursive folder scan» on `pv` the
cached .SLD list is marked and `askAboutSlidesListSave()` asks (nothing); «Discard», then the
list opened again: `pv` is recursive, as saved; a save keeps `|pv`; in private mode nothing
changes and nothing is marked (the same); in a database the list is marked, as «Remove» and
«Paste list» mark it. Batch G differs at G1 alone, where the question now comes.

## 9. Database: «Rename index entry» from this panel leaves the `staticfolders` table and the captions behind

`PanelRenameStaticFolder()` :97948-97969, `renameStaticFolderSQLdb()` :98021

In this panel the rename rewrites the seed folders list and offers the search and replace
(:97967-97969). `renameStaticFolderSQLdb()`, which carries the folders list's rows, the
captions and the audio notes, runs for the folders list panel only (:97934-97941).

What happens (run, database, `pv` renamed `pvNew` on the disk, then F2 on `pv` with
«Propagate the change to subfolders» ticked, «Yes» to the search and replace):

- the twelve files move to `pvnew\…` in the `images` table (batches E4, H1);
- the `staticfolders` table keeps its rows for `pv\alpha`, `pv\beta` and the others;
- the caption of `pv\Alpha\a1.png` stays in `imagesData` under the old path; none is
  recorded for the new one;
- the folders list panel lists the `pvnew` folders, each one with the changed mark «*», in
  the session (E4) and after the database is opened again (H1, I2);
- the `staticfolders` table still holds the five `pv` rows after the database is opened
  again and after the folders list panel was opened (I2).

The index holds the new folder as typed (`pvNew\alpha`), the database in lower case
(`pvnew\alpha`), as in note C of the folders list audit. Note F there lists the other routes
that leave captions behind.

Correction: in a database, run `renameStaticFolderSQLdb()` here too, for the seed folder and
its subfolders, after the search and replace succeeded.

The same rename on a cached .SLD list leaves the folders list's rows on the old paths, in
memory and in the next save, a case of the folders list audit's finding 10 (read, then run in
batch Y9 below).

**Fixed in `caa77ef`**, with Marius's answers (decisions 11 and 12): once «Yes» was answered
and the search and replace succeeded, the folders list follows the files (:98199-98208). Its
rows of the folder and of its subfolders are renamed, whatever the tick, since the search and
replace moves the subfolders' files in any case; on a cached .SLD list the rows are read from
the file first when they are not in memory yet, so the next save writes the new paths; in a
database `renameStaticFolderSQLdb()` moves the `staticfolders` rows with their recorded dates,
the captions and the audio notes, and the new path reaches the index in lower case, as the
folders list panel's rename writes it (:98147-98148). «No» renames the seed folder entry alone,
as before. On a cached .SLD or plain list the rows take the new path in lower case, as the
folders list is kept, while the index keeps the spelling typed (`pvNew\Alpha`); the folders list
panel's own rename writes its row as typed there. A plain list's folders list, once generated,
follows too: it is the same list in memory. `renameStaticFoldersEntries()` (:98246), which both
folder panels call, compares the paths in lower case, as decision 5 has it, and matches a
subfolder from the start of its path only. The audio notes are not run from this panel: the
folders list kit's batch SG2 runs them through the same `renameStaticFolderSQLdb()`.

Run on the text of `caa77ef` (batch Y9; at `803a668` in parentheses), `pv` renamed `pvNew` on
the disk, then F2 on the seed folder `pv`:

- database, «Yes»: the index holds `pvnew\alpha` (`pvNew\alpha`); `staticfolders` holds the
  five `pvnew` rows, `pvnew\beta` with the date set apart for the run, so the folders list
  panel marks that row alone, also after the database is opened again (five rows marked, the
  table on `pv`); the caption of `a1.png` follows (stays on `pv\alpha\a1.png`);
- «Propagate» unticked, with the seed folder `pv\alpha` inside `|pv`: that entry keeps its path,
  the five rows move with the files (they stay);
- a files filter on (F3 on `pv`): the search and replace drops it, the rows and the caption
  move (they stay);
- «No»: nothing moves but the seed folder entry (the same);
- an image of the same name indexed in the new folder already: «UNIQUE constraint failed»,
  nothing moves (the same);
- cached .SLD list, its folders list loaded: the rows become `pvnew\…` with their dates,
  unmarked, and the save and the list opened again keep them (`pv\…`, marked, saved so); its
  folders list not loaded yet: read from the file and renamed, saved so (saved on `pv\…`);
  «No»: the rows stay;
- plain list with its folders list generated: the rows follow (they stay).

Batches E, H and I differ at E4, E5, H1 and I2 alone, as above. The folders list kit's rename
batches D2, H, Y, Z, SG2 and SG3 give the same lines on this text, but for which image, if any,
the display then fails to find on the disk in Y, SG2 and SG3; its step Z4, this panel's rename on
a cached .SLD list, logs the files alone.

Two cases:

- a rename onto a folder that has rows already, as after two folders were merged on the disk
  (run, Y9.6): the moved rows replace them, with their own dates, so that folder's recorded
  date is lost (at `803a668` neither row set changed). The folders list panel's rename refuses
  a path listed already (`findTakenStaticFolderPath()`); this panel's does not. Decision 13;
- a search and replace that fails for some files only: the rows and the captions follow (run,
  Y9.5b), seen in passing G.

## 10. A `|` folder added or rescanned on a cached .SLD list gets no row in the folders list

`wrapperAddNewFolderToList()` :66264, `addNewFolder2list()` :66477-66478,
`coreRescanDynaFolder()` :97565-97566

```ahk
If (!InStr(firstLine, "[General]") || tstSLDcacheFilesList!=1 || InStr(folderu, "|"))
   good2go := "null"
```

For a `|` folder the function answers «null», and both callers then leave the folders list
alone.

What happens (run, batch G, cached .SLD list of `pv`):

- `|other` and `third` added: the folders list gains `third`, not `other`, though the index
  holds the two files of `other` (G2);
- both get another date on the disk: the folders list panel marks `third`; both rescanned
  from this panel: the mark of `third` clears, `other` is still not listed (G3).

The folders list audit's finding 10 (open) is about rows that do not follow the index; this
is one of its causes.

Correction: let a `|` folder through and pass `onlyMainFolder=1`, as `coreRescanDynaFolder()`
already computes (:97564).

**Fixed in `20d9d3b`** by that correction: `wrapperAddNewFolderToList()` (:66283) no longer
answers «null» for a `|` folder on a cached .SLD list (:66290), and both callers already hand
`updateCachedStaticFolders()` the folder without its `|` and with `onlyMainFolder=1`
(`addNewFolder2list()` :66504, `coreRescanDynaFolder()` :97775). The test dates from
`d56cc93` (2019), when the wrapper itself updated the folders list with the folder as it was
given, `|` included, and with its subfolders. Run (batch Z10, a cached .SLD list of `pv`; at
`98ea716` in parentheses):

- `|other` and `third` added: the folders list in memory gains `other` and `third` (`third`
  alone); saved, the `[Folders]` section holds both; the list opened again, the folders list
  panel lists both (Z10.1, Z10.2);
- both get another date on the disk: the folders list panel marks both (`third` alone); F5 on
  each from this panel clears both marks (Z10.3; batch G gives the same);
- `other\sub` added inside `|other`, `other` dated again, F5 on `|other`: the row of `other`
  takes the new date (no row), and the file of `other\sub` stays indexed (Z10.4);
- in a database a `|` folder added gets its row on both texts (Z10.7): that path never had the
  test.

Not changed: an entry turned non-recursive and rescanned drops the files of its subfolders
from the index, and their rows stay in the folders list (Z10.5, `third\deep`, on both texts),
one more case of the folders list audit's finding 10.

## 11. «Rescan folder» on a missing folder deletes its entries

`BTNrescanDynaFolder()` :97571-97587, `coreRescanDynaFolder()` :97563,
`wrapperAddNewFolderToList()` :66279

The folders list audit's finding 14 (open), reached from this panel by F5 or the menu.

What happens (run, batch E2, database): `third` moved away, F5 on it: the two rows of
`third` are gone from the `images` table, with their cached data. Nothing is said. The seed
folder stays in the list.

«Rescan all» does otherwise: it skips a missing folder (:87787). In a database the entries
stay; in a plain or .SLD list they go, since the index is emptied first (read).

Correction: decision 7 (decision 2 of the folders list audit, still open).

**Fixed for this panel in `32c435d`**, by Marius's answer to decision 7: «Rescan folder» on a
missing seed folder asks «Keep» or «Purge» (finding 2's note). Run (batch E2): F5 on the
missing `third`, «Keep»: its two rows stay in `images`.

**Fixed for the folders list panel too**, and before this audit: that panel's «Rescan
folder(s)» (`BTNupdateSelectedStaticFolder()` :98759 at `2400d23`) asks first since `26c47e1`
(2026-11-13, Marius's answer to decision 2 of the folders list audit): «Yes» or «No» when
every selected folder is missing, «Rescan all», «Skip missing» or «Cancel» when some are
(:98820). The entries of a missing folder go only after «Yes» or «Rescan all». The sentence
written here at `32c435d`, that the folders list panel «still removes the entries of a folder
it cannot reach», missed it. Run on `98ea716` (that kit's batch RP, the lines of its run on
`26c47e1`): «No», «Cancel» and «Skip missing» keep the entries, in a database their `images`
rows too; «Rescan all» and «Yes» remove them. Nothing was changed for this finding on
2026-11-17.

## 12. The count columns

- **«Difference» 0 for a folder never counted on disk.** F11 writes `diffu := (onDisk!="" &&
  thisIndex!="") ? onDisk - thisIndex : 0` (:96937): with «Files on disk» blank it writes 0
  (run, batches A4 and C8). Correction: leave the cell blank.
- **Counts that follow a files filter.** With a filter on, F11 counts the filtered index.
  Run (batch B5): F3 on `|other`, then F11 and F10 on `pv`: «Files» 0, «Difference» 12. The
  panel does not say a filter is on.
- **«Selected» not refreshed.** «Select files» and «Deselect files» update the rows of the
  folders list panel only (:96873-96888). Run (batch B2): 5 files selected, the row's
  «Selected» stays 0.
- **«%» and «Size (MB)» sorted as whole numbers.** Every column but 2 and 3 is declared
  `Integer` (:98798-98802); columns 6 and 9 hold one decimal. The folders list panel had the
  same, its finding 26, fixed with `Float` in `f88e4be` (read here).
- **A stopped count.** Escape during F11 or F10 writes the partial count as if complete
  (:96916-96920, `getFolderInfos()` :31064-31068; read). As the folders list audit's finding
  13.
- **Two rows for one action.** F10 counts the disk on the first selected row (:35435) and
  the index through F11's function, which reads the focused row (:96901). In a list that
  allows one selection they are the same row in practice (read).

**Fixed in `b55b247`**, with Marius's answers (decisions 14 to 16), lines at `2400d23`:

- «Difference» stays empty until «Files on disk» is counted (`uiDynaRowCounts()` :97097).
- While a files filter is on, F11, F10 and the refreshes below count the whole index
  (`countDynaFolderFiles()` :97060): in a plain or .SLD list the unfiltered list kept in
  memory, whose entries the filtered list shares, selection marks included; in a database
  filtered by a query, as F3 filters it there, «Files» comes from the `images` table and
  «Selected» from the filtered list, the only place where files can be selected then.
- «Select files» and «Deselect files» write the row from their own pass over the index:
  «Files», «Selected», «%», and «Difference» once the disk is counted (:97016); with a filter
  on, the row is counted again over the whole index. «Deselect all (files list)» has its own
  function in this panel's menu (`MenuDynaFoldersDropFilesSelection()` :94144, :94222): every
  counted row gets «Selected» 0 and «%» 0, or, with a filter on, is counted again, since the
  files the filter hides keep their selection.
- «%» and «Size (MB)» sort as numbers with decimals (:99191).
- A stopped count leaves the row as it was and says so: «Counting stopped: the row keeps its
  previous values» (F11 :97038, F10 :35464); F10 does not scan the disk after its index count
  was stopped (:35453). A stopped «Select files» or «Deselect files» leaves the row too, with
  «Selection stopped» (:97035); the files it reached stay selected, as before.
- F10 counts the row F11 counts, the focused one or else the first selected
  (`getFocusedOrFirstSelectedRow()`, :35446).

Run (batch Z12, a plain list of `pv`, `other\sub` and `|other`; at `98ea716` in parentheses):

- F11 on `other`: «Difference» empty (0); F10: 2 on disk, «Difference» 0 (Z12.1, Z12.2);
- «Select files» on `other`: 2 selected, 100.0 % (the row unchanged, 0 selected); «Deselect
  files»: 0; «Select files» on `other\sub`, never counted: 3 files, 3 selected, «Difference»
  empty (nothing written) (Z12.3);
- two files of `pv\Alpha` selected, F11 on `pv`: 12 files, 2 selected; «Deselect all»:
  «Selected» 0 on the three counted rows (unchanged) (Z12.4);
- 33.3, 90 and 33.7 in «%», sorted highest first: 90, 33.7, 33.3 (90, 33.3, 33.7); 1.5, 10.2
  and 1.9 in «Size (MB)»: 10.2, 1.9, 1.5 (10.2, 1.5, 1.9) (Z12.5);
- `pv` counted, 12 files and 12 on the disk, then two files of `pv\Beta` selected; each stop
  forced at the third check the Escape key feeds (the kit's `tsAbortAfter`): F11 stopped, the
  row keeps 12 files and 0 selected, with the message (2 files, «Difference» 10); F10 stopped in
  its index count, the same, the disk not scanned (2 files, then the disk scanned); F10 stopped
  in its disk scan, the index count written, 2 selected, the disk cells kept (0 on the disk,
  «Difference» −12); «Select files» stopped, the row kept, «Selection stopped» (the row kept,
  nothing said) (Z12.6);
- three files of `pv\Alpha` selected, then F3 on `|other`: F11 and F10 on `pv` give 12 files,
  3 selected, 25.0 %, «Difference» 0 (0, 0, 12); «Select files» on `other`: 2 files, 2 selected
  (the row unchanged); «Deselect all»: `other` 0 selected, `pv` still 3, the filter hiding them;
  with the filter removed, those 3 files are selected (the same, the rows unchanged) (Z12.7);
- a database, F3 on `|other`, a query filter: F11 and F10 on `pv` give 12 files from the
  database, «Difference» 0 (0 and 12); «Select files» on `other`: 2 and 2; «Deselect all»: 0
  selected on both rows (the rows unchanged) (Z12.8);
- a folder pasted and not scanned yet, F10 on it: 0 files, 1 on the disk, «Difference» 1, as
  before: the 0 that F11 hands to F10 is not taken for a stop (batch Z12B).

Batch B gives the lines of `98ea716` but at B1 («Difference» empty), B2 (the row follows
«Select files») and B5 (12 files with the filter on, «Difference» 0).

## 13. «Remove»: no way back

`BTNremDynaSelFolder()` :97012-97032

- The entry leaves the list, and in a database the table, before the question (:97027-97029);
  the question has «Yes» and «No» only (:97032). «No» keeps the files, not the entry.
- With one file in the index there is no question at all (`If (maxFilesIndex>1)`, :97031):
  the entry goes and its file stays (read).
- The box shows the stored form, `|other\`, and calls it a «dynamic folder» (run, batches
  B6 and E1).

Correction: decision 3; strip the `|` from the text.

**Fixed in `1e1c2b6`**, with finding 3 (decision 3): the question comes before anything
changes, also with one file or none in the index; «No» changes nothing; the box is titled
«Remove seed folder» and shows the folder without the `|`.

## 14. «Paste list»

`BTNpasteDynaFoldersList()` :96967-96998

- **A trailing separator** is kept: `fifth\` becomes the entry `fifth\` (run, batch C8). F5
  then indexes its file, and F11 counts 0 for it: the tests look for `fifth\\`. Correction:
  trim trailing separators, as `getDynaFolderCoverage()` does (:97689).
- **A quoted path**, as Explorer's «Copy as path» gives it, is dropped without a word (run,
  batch C8).
- Pasted folders are only listed; nothing says they must be rescanned. «Recursive folder
  scan» does say so (:97548).
- The list is marked as modified even when nothing changed (:96994; read).

**Partly fixed**: since `32c435d` a quoted path is counted among the lines skipped; since
`592628d` a trailing separator is trimmed, from the pasted lines and from every entry when a
list is read (finding 5; run, batch C8: `fifth\` is listed as `fifth`).

**Fixed in `2400d23`**, with Marius's answers (decision 17), lines at `2400d23`: «Paste list»
(`BTNpasteDynaFoldersList()` :97127) removes every quotation mark from the pasted text before
it reads the lines (:97133), as he asked: a path cannot hold one, and Explorer's «Copy as
path» puts each path between two. The list is marked as modified, and a database's
`dynamicfolders` table written again, only when its entries differ from those listed before
(:97179). A message says how many seed folders were added and that «Rescan folder» (F5) on
each, or «Rescan all», indexes their files (:97190), in one message with the count of the
lines skipped.

Run (batch Z14, a plain list of `pv`; at `98ea716` in parentheses):

- `"…\fifth\"`, `"…\sixth"`, `"|…\seventh"`, `|"…\eighth"` and `…\ninth` pasted: `fifth`,
  `sixth`, `ninth`, `|seventh` and `|eighth` listed, «5 seed folder(s) added to the list…»
  (`ninth` alone, «4 pasted line(s) skipped»); F5 on `fifth` indexes its file and F11 counts
  it (no row `fifth`, its line skipped) (Z14.1, Z14.2). Batch C8 still picks `fifth\`, which
  no row holds since `592628d`: its F5 and F11 act on nothing, on both texts; Z14.2 does what
  they meant to do;
- the same lines pasted again: the list is not marked, no message (marked, «4 pasted line(s)
  skipped») (Z14.3);
- two quoted folders and a quoted path that is no folder: both listed, one message with both
  counts (all three skipped) (Z14.4); a line that is no folder, alone: «1 pasted line(s)
  skipped», the list not marked (marked) (Z14.5);
- a database, its own seed folder pasted: the list not marked (marked); a quoted new folder:
  it joins the `dynamicfolders` table (skipped) (Z14.6).

Batch C gives the lines of `98ea716` but at C6 (the message about the folder added) and C8
(`"sixth"` listed, «2 seed folder(s) added…»).

## 15. Small things

- **Menu letters** (run, batch A3, the menu's labels): `&R` on «Rescan folder», «Recursive
  folder scan» and «Remove folder from this list»; `&C` on «Copy this folder path as text» and
  both «Count…» items. The letter then moves between the items instead of choosing one.
- **Names.** The rename box is titled «Rename static folder entry» (run, batch E4, :97887);
  «Copy list» says «Dynamic folders list copied to clipboard» (:96962); the remove box was
  «Remove dynamic folder» (:97032), «Remove seed folder» since `1e1c2b6`. The panel calls them
  seed folders.
- **F1** does nothing in this panel; the folders list panel opens its help (:97220-97224;
  read).
- **Insert** («Add») is refused when no row is selected: the row test comes before the keys
  (:97217; read). An empty seed folders list cannot be filled by key.
- **The add dialog** says «Add new folder(s) to the list» (:66423) and takes one folder
  (read).
- **«Rescan all»** starts at once, next to «Remove» (the folders list audit, note B).
- **Private mode** lists one more row than there are seed folders: the masking replaces the
  path before the test that skips empty lines (:98807-98808). Run (batch H2): one seed folder,
  two rows. F5 and Delete + «Yes» there change nothing; the panel warns that it malfunctions
  in private mode.
- **After «Recursive folder scan»** the table is filled again and no row is selected (read,
  :98796).
- **Alt+right-click** deselects the folder's files and opens the menu too: the window's
  right-click handler has no Alt test (:25954), as the folders list audit's finding 29 found
  for that panel; the handler is shared (read).

## Seen in passing

Not part of the panel's own code.

- **A.** «Rescan folder» writes the folder part of the rescanned paths in lower case (`été\…`
  in batch A4), as the folders list audit's finding 24 (open): the seed folders list is
  stored in lower case.
- **B.** The folders list panel's «Set as the protected folder» hands over its own lower-case
  path as well (`BtnPanelManageFoldersActus()` :97145-97146; the folders list is stored in
  lower case), so finding 4's protection failure applies there too (read). Fixed with finding
  4 in `7c031cb`: the tests compare in lower case, whichever menu set the folder.
- **C.** `cleanDynamicFoldersList()` (:87694) drops every entry inside a recursive one. After
  «Recursive folder scan» makes `|d:\pics` recursive, the entry `d:\pics\sub` disappears from
  the list, and making `d:\pics` a `|` entry again does not bring it back (read).
- **D.** F2 («Rename index entry») from this panel, on a plain or .SLD list, renames the paths
  of the index through `SearchAndReplaceThroughIndex()` (:98277 at `d05e990`), whose
  `StrReplace()` (:98414) ignores the case of A to Z only: for a folder named `Été` the entry
  is renamed and the index keeps the old paths (read). Finding 4's fix covers the comparisons,
  not this replacement. **Fixed in `9aecb75`**, by Marius's answer to decision 9: every match
  of `SearchAndReplaceThroughIndex()` (:98314 at `0ab5622`) ignores the case of every letter,
  through `StrReplaceCaseless()` (:98294), which finds the matches in lower case and replaces
  them in the original; the folder-alone mode compares in lower case. In a database the
  subfolder rows follow as well, so after the folders tree's «Rename folder» the rows and the
  index agree. Run on the text of `0ab5622` (batch U): F2 on `été` renamed `Été2` on the disk
  moves both files (2 records; at `89840b5` 0; U2); the folders list panel's F2 on a cached .SLD list,
  «Propagate» unticked, moves the folder's own file (U3); the panel's normal mode replaces
  `ÉTÉ3\` in both entries, the one marked missing included, and a partial string in folder mode
  still replaces in the middle of the paths (U4); in a database the folders tree's rename of
  `Ûna` moves the subfolder's row too, and the normal mode with `ÛNA2\SUB\` moves the row and
  the index entry together (U5, U6; at `89840b5` the subfolder's row and the index stayed on the
  old path). The panel's other two targets ignore case too since `8cacdee` and `cce29a6`
  (Marius's answer), lines at `557c018`: the seen images list (`SearchAndReplaceSeenDB()`
  :98522) selects its records with LIKE, which folds A to Z only, so every other character of
  the searched text now matches any character there, and `StrReplaceCaseless()` keeps the true
  matches and replaces them; the list can hold one file under two spellings, one viewed from a
  plain list and one from a database, and the column skipped without a word an update to a path
  recorded already, leaving the record on the old path while counting it: the two records now
  merge under the new path, with the later view date, and the count tells the records really
  changed (decision 10). The seed folders list (`BTNperformIndexSearchReplace()` :47026)
  replaces through `StrReplaceCaseless()`. Run on the text of `557c018` (batches W and X; at
  `8cbe643` in parentheses): `été\` replaced on the records `Été\a.png` and `été\a.png` gives
  one record, with the later date, «2 records were modified» (one renamed, the other left on the
  old path); `Ätä\b.png`, which the wildcards select, stays untouched and uncounted; folder mode
  with `ÉTÉ` renames the folder and keeps the file name `Été.png` (nothing); the needles
  `pics_1\` and `100%\` and an A to Z one give the same records as before; through the panel,
  `ÄTÄ\` renames the record (nothing); the seed folders list, `ÉTÉ` renames `été` (nothing).
  `8cacdee` merged a record at once into the one holding its new path, also when that one was
  about to move on in the same pass: `photos\` → `photos\old\` on `photos\a.png` and
  `photos\old\a.png` kept one record, as the order of the rows had it, and the chain `zq`,
  `zqq`, `zqqqq` with `q` → `qq` kept one of three (run, batch W9). Since `ffccbb3` (:98522)
  such a record waits: the waiting records are tried again after the pass until none moves,
  and only those still colliding merge. Run: both orders keep the two records, the chain its
  three, each with its own date; batch W gives the lines of `557c018`.
- **E.** A drive root on routes that finding 5's places did not include (read at `d05e990`,
  found by a search for the tests that want more than two characters; not run): renaming an entry to a
  root is refused (`PanelRenameStaticFolder()` :98091); «With a new QPV instance» on a root
  passes `fd=p:`, which the new instance's argument test refuses
  (`initializeAppWithGivenArguments()` :2437), so it opens nothing; the main window's refresh
  of a list opened from a root does nothing (`RefreshFilesList()` :65342,
  `StrLen(CurrentSLD)>3`); the copy and move panel does not offer `p:` among its destinations
  (`CopyMovePanelWindow()` :60440); the search and replace on the seed folders list calls a
  list of roots alone empty (`BTNperformIndexSearchReplace()` :47056); the folder lines of a
  legacy plain-text list skip roots (`sldGenerateFilesList()` :89142); a dropped drive root is
  skipped (`GuiDroppedFiles()` :66689); a root kept as the last opened folder is reset at the
  next start (`INIaction()` :72700, type 6). Open. **Partly fixed**, lines at `0ab5622`:
  - «With a new QPV instance» (`08ae6f5`): the argument test takes `fd=p:`, `fd=p:\` and
    `fd=|p:` (:2437); `OpenNewQPVinstance()` (:2981) passes a folder without its trailing
    separator, since `"fd=p:\"` reaches the new instance as `fd=p:"` (run: a second AutoHotkey
    started that way receives that). Run (batch S, the app started with the argument):
    `fd=P:` and `fd=P:\` open the root with its subfolders, five files; `fd=|P:` the root alone,
    two; at `89840b5` each was ignored. The function itself is not run: the kit replaces it
    with a log line.
  - «Rename index entry» (`c68164c`, :98108, both folder panels): a drive root is taken as the
    new path. Run: F2 on `other` → `P:\` gives the entry `p:` and, after «Yes», the paths
    `P:\r1.png` and `P:\r2.png` (U1; at `89840b5` «Incorrect folder path provided»). The folders
    list panel's way is read, not run.
  - The refresh (`905461a`): `RefreshFilesList()` (:65342) takes `p:` and `|p:`. Opening a
    single image (`OpenArgFile()` :65611, «Open last image» :65562, a clipboard image saved
    :60219) wrote its folder with its subfolders in the seed folders list while naming the list
    «the folder alone»; with a root the refresh would scan the whole drive. They write the
    folder alone, as moving to another image already does (decision 8). Run (batch T, and R0):
    one image of the root opened, F5 indexes its two files (T1; at `89840b5` nothing); one image
    of `pv\Alpha`, F5 indexes `pv\Alpha` alone (T2; at `89840b5` `pv\Alpha\Sub` too); the root
    opened as a folder and a file added there, F5 adds it, subfolders included (T3); «with
    subfolders» toggled after one image of the root, the refresh scans the drive (T4, as asked
    by the toggle); the kit's own start, one image, F5 gives the folder's two files instead of
    ten with the subfolders (R0). Of the three single-image places only `OpenArgFile()` is run.
  - The Search and Replace panel's seed folders list (`557c018`, :47056): a list of drive roots
    alone is a list, no longer «empty»; and a replacement that changed the list marks it as
    modified, which it never did: closing a .SLD list asked nothing and lost the change
    (Marius's choices). Run (batch X): the list `p:` alone, `P:\` → `P:\Sub\` gives `p:\sub`
    (at `8cbe643` «The seed folders list is empty»); `\PV` → `\pvX` changes the list and marks
    it (at `8cbe643` the same change, unmarked); a text that matches nothing marks nothing.
  - Still open: the copy and move panel, legacy list lines, a dropped root, and the last opened
    folder.
- **F.** `remFilesFromList()` leaves the count of indexed files blank, not 0, when it removes
  every file: its `countFiles` is never set (run, batch N4: `maxFilesIndex` is blank after
  «Yes» on the only seed folder). Not followed further. Open.
- **G.** In a database, `SearchAndReplaceThroughIndex()` in folder mode moves the files of the
  subfolders one by one; a file whose new path is held already fails alone, is counted
  («Failed to modify 1 entries») and the function still reports success, while the index
  takes the new path for every file, that one included: the index and the database disagree
  on it. Run (batch Y9, step Y9.5b, an image of the same name indexed in a subfolder of the new
  folder): `pv\beta\b1.png` stays in the `images` table, the index lists it under `pvnew\beta`.
  The renames of both folder panels then carry the folders list along, as for a success (run for
  this panel, Y9.5b; read for the folders list panel). Open.

## Checked and found correct

- F3 on a folder whose name has a capital outside A-Z (run, batch A4).
- A database: folder names with such letters (run, batch E5); `|` entries kept across a save
  and an opening (run, batch E0).
- «Paste list» reads clipboard text with CR LF line ends (run, batch C6).
- The «Recursive folder scan» tick follows the «(?)» column (run, batch A3).
- The keys F2, F3, F5, F10, F11 and Delete reach their actions through the list's handler
  (run, key messages posted to the list); Enter and the Menu key go through
  `externalinvokedSettingsContextMenu()` (:25928, :25934; read).
- The functions shared with the folders list panel act on this panel's list (run, batches B2
  and B3), as the folders list audit found.
- With no row selected, the menu offers «View list as a folders tree» alone (run, batch A3).
- «Rescan folder» on a reachable recursive entry clears its changed mark in the folders list
  of a cached .SLD list (run, batch G3).
- Private mode: F5 and Delete + «Yes» change neither the index nor the seed folders list
  (run, batch H2).
- «Set as the protected folder» on a folder named in A-Z letters protects it: the delete
  skips its files (run, batch I1).

## Decisions to make before fixing

1. **A missing seed folder**: keep it in the list, as decision 9 of the folders list audit
   does for the folders list, drop it as now, or ask? **Settled** (`32c435d`, Marius's
   answers): kept everywhere without a question; «Rescan all» and «Rescan folder» ask once,
   without listing the folders, «Keep» (its indexed files stay, its folders list rows stay,
   dated «-», in a database too) or «Purge» (it goes, with every file indexed under it,
   subfolders included, and its folders list rows); a pasted folder that is not on the disk
   is skipped and counted; «Copy list» copies every entry.
2. **The reach of a `|` entry's actions**: the files placed directly in the folder, as the
   entry indexes them, or the subfolders too, as now? It covers «Remove» + «Yes», the two
   counts, «Select files», «Deselect files», «Jump to first indexed file», F3 and «With a new
   QPV instance». **Settled for «Remove»** (`1e1c2b6`, Marius's answer): the subfolders too,
   except the files another seed folder covers. **Settled for the other actions** (`78120a1`,
   Marius's answers): the files placed directly in the folder, as the entry indexes them;
   «With a new QPV instance» opens the folder alone.
3. **«Remove»**: ask first, with «Cancel», before the entry goes, or keep «Yes» / «No» about
   the files only? **Settled** (`1e1c2b6`, Marius's answers): one question before anything
   changes, «Yes» / «No», asked every time; «No» changes nothing; «Yes» removes the entry with
   its files.
4. **A drive root**: `d:` (as «Open folder» stores it and as the folders list keeps it) or
   `d:\` (as «Add» stores it)? **Settled** (`592628d`, Marius's answer): `d:`; no entry keeps
   a trailing separator.
5. **Letter case**: keep the seed folders list in lower case and compare in lower case
   everywhere, or keep the spelling of the disk (which would also settle decision 10 of the
   folders list audit for this panel)? **Settled** (`7c031cb`, Marius's answer): lower case,
   both sides compared in lower case.
6. **The Save panel's «Manage folders»**: close the Save panel and open this one, with
   «Back», or take the button out? The `If AnyWindowOpen` test was presumably added for the
   custom shortcuts; it could stay for every other route. **Settled** (`d05e990`, Marius's
   answer): the Save panel closes and this one opens, with «Back»; the test stays for every
   other route.
7. **«Rescan folder» on a missing folder**: skip it, ask first, or remove its entries as
   now? Same as decision 2 of the folders list audit. **Settled for this panel**
   (`32c435d`, Marius's answer): ask, «Keep» or «Purge», as in decision 1. Decision 2 of the
   folders list audit was settled for that panel before this audit, in `26c47e1`: ask first
   (finding 11's note).
8. **The refresh right after a single image**: the folder alone, with its subfolders (a root:
   the whole drive), or roots opened as folders only? **Settled** (`905461a`, Marius's answer):
   the folder alone, a root or not; this changes the refresh of any folder in that state.
9. **The reach of the case-blind search and replace** (seen in passing D): the folder modes, the
   panel's normal mode too, or F2 alone? **Settled** (`9aecb75`, Marius's answer): every mode of
   the search and replace through the index; then the panel's seen images and seed folders
   targets too (`8cacdee`, `cce29a6`, Marius's answer).
10. **Two seen records of one file**, which a case-blind replacement gives the same path: merge
    them, delete the duplicate, or leave it on the old path? **Settled** (`8cacdee`, Marius's
    answer): merge them, under the new path, with the later view date.
11. **The spelling a database's index gets from this panel's rename** (finding 9): as typed,
    or in lower case, as the folders list panel's rename writes it (note C of the folders list
    audit)? **Settled** (`caa77ef`, Marius's answer): lower case.
12. **The folders list after this panel's rename on a cached .SLD list**: databases alone, as
    finding 9 is worded, or cached .SLD lists too, whose rows stayed on the old paths in memory
    and in the next save? **Settled** (`caa77ef`, Marius's answer): cached .SLD lists too.
13. **This panel's rename onto a folder that has rows already** (finding 9, run Y9.6): keep it,
    the moved rows replacing that folder's rows and recorded dates, or refuse the new path as
    the folders list panel's rename does? Open.
14. **The counts while a files filter is on** (finding 12): the whole index, the filtered
    files with a line in the panel that says so, or as they were? **Settled** (`b55b247`,
    Marius's answer): the whole index.
15. **A stopped count** (finding 12): empty the cells, or keep what they showed? **Settled**
    (`b55b247`, Marius's answer): keep them, with a message; F10 then does not scan the disk.
16. **The table after «Select files», «Deselect files» and «Deselect all»** (finding 12): the
    counts of their own pass, «Selected» and «%» alone, or F11 run again? **Settled**
    (`b55b247`, Marius's answer): the counts of their own pass.
17. **The folders «Paste list» adds** (finding 14): ask to scan them, say they need a scan, or
    scan them at once? **Settled** (`2400d23`, Marius's answer): say it; the quotation marks
    are removed from the pasted text, as he asked.

Suggested order at `2400d23`: decision 13; what is left of 15; seen in passing F and G.

## How this was checked

Kit: `.claude/scratch/seed-folders-panel-2026-11-15/app/`, built from the folders list
audit's kit. `setup.sh` links the repo DLLs once; `build-wrappers.sh` joins
`helpers-static.ahk` (that kit's helpers) and `seed-part.ahk` (the batches) into
`test-wrappers-seed.ahk`; `run-app.sh <tag> testSeed<X> ""` runs one batch on the working
tree; `run-all.sh <suffix> "" "B C D E G"` runs several, with drive P: mapped for batch D.
Logs in `results/`: `a-1` to `i-1` are the runs on the source of `bf72416`; `a-2` to `k-2`
are every batch run again on the fixed text, before two last changes (the wording of the
«Rescan all» question for one folder, the kept files placed after the scanned ones);
`j-3`, `k-3`, `l-3` and `m-3` are batches J to M on the text committed as `32c435d`. Compared line by
line, after the dates and the random current image are blanked out, `a-2`, `b-2`, `g-2` and
`i-2` give the lines of `a-1`, `b-1`, `g-1` and `i-1`; `c-2`, `d-2`, `e-2` and `h-2` differ
where the fixes act. In `d-2`, `P:\a` holds two images because batch K, run first, added
one. The script `loadcheck.sh` (next to `app/`) load-checks the working tree with
AutoHotkey_H and stock AutoHotkey 1.1.37.02; `split-finding1.py` made the text of `fe812ec`
from `bf72416` and the tested text.

The app runs under the private Wine of the FreeImage fork, on AutoHotkey_H 1.1.33.10.
`patch.py` adds the test functions to a scratch copy and turns menus, clipboard writes and
external launches into log lines. Keys reach the list as `WM_KEYDOWN` / `WM_KEYUP` posted to
it, so the list's handler gets real «K» events; buttons are clicked with `BM_CLICK`; message
boxes are answered from a timer. «Paste list» reads a clipboard set through the Windows
clipboard functions. A folder is made missing with `FileMoveDir` and put back afterwards.

Clicked: «Manage folders» on the Save panel, «Remove», «Rescan all», «Copy list», «Paste
list». Pressed: F2, F3, F5, F10, F11, Delete. Run by calling their functions, not by a click:
the context menu (built, its items logged), «Select files», «Deselect files», «Jump to first
indexed file», «Recursive folder scan», «Set as the protected folder», «Add» (with the folder
given as the dialog returns it). Not exercised at all: the folder dialog itself, the «More»
click, Enter, the Menu key, Insert, Space, the Alt+clicks, the «Open folder» submenu,
«View list as a folders tree», «Copy this folder path as text» (the folders list audit ran
that one in this panel, its batch F).

| Batch | List | What it does |
|-------|------|--------------|
| A | plain | the Save panel's «Manage folders»; the panel from the menu; its context menu with and without a row; `Été` and `Ștefan` added: F11, F10, «Select files», «Jump», F3, F5, Delete + «Yes» |
| B | plain | seed folders `pv`, `\|other`, `other\sub`: F11 and F10, «Select files» and «Deselect files», «Jump», F3, F11 and F10 with a files filter on, «Remove» + «Yes» |
| C | .SLD | `\|other` saved, saved again, opened; an uncached list; a missing folder at save time; «Paste list» with a missing folder; «Copy list» with a missing folder; a pasted trailing separator and a quoted path |
| D | plain, .SLD | drive P:: opened, «Copy list», «Rescan all», «Remove» of another entry; `P:\` added, «Rescan all», «Paste list»; saved and opened |
| E | database | the seed folders kept; «Remove» + «Yes» on `\|other`; F5 on a missing folder; «Recursive folder scan» with a missing folder, the database opened again; «Rename index entry» of `pv`; `Été` added, F11, F5 |
| G | cached .SLD | «Recursive folder scan» and the save question; `\|other` and `third` added; both re-dated and rescanned |
| H | database, plain | the rename of batch E, then the database opened again; private mode, F5, Delete + «Yes» |
| I | plain, database | «Set as the protected folder» on `ascii`, then on `été`, each followed by «delete selected files» on that folder's files; the rename of batch E, the `staticfolders` table read after the database is opened again and after the folders list panel |
| J | plain, cached .SLD, database | after `32c435d`: «Rescan all» with `other` moved away, answered «Cancel», «Keep» (the index order logged), «Purge»; on the cached list a save after «Keep» and after «Purge»; in the database the three tables after each |
| K | cached .SLD, database, drive P: | after `32c435d`: F5 on the missing `other`, «Keep» then «Purge», the cached list saved afterwards, the database's tables; a list of the drive root alone and a list of `P:\a`, each saved and opened |
| L | plain, database | after `32c435d`: «Rescan all» with `\|other` and `other\sub` both missing, «Keep» then «Purge»; its step L3 opens a plain folder after the database and is not valid (the kit's known trap), batch M repeats it |
| M | plain | after `32c435d`: F5 on the missing `été`, «Purge» |
| N | plain, database | for `1e1c2b6`: «Remove» on `\|other` holding the recursive `other\rec` and `\|other\pipe`, with files no seed folder covers: «No», «Yes»; `\|Été` holding `Été\sub`; an index of one file; the same «Yes» in a database |
| O | plain, database | for `7c031cb`: folders `Ăla`, `Îna`, `Été`, `Ștefan`, `Ûnu`: the protected folder set from this panel, sub-paths off and on, then «delete selected files» and «Remove file entries from the list»; set with the disk spelling: the check mark, the toggle; F11, «Select files», «Jump»; the folders list panel's «Jump»; «Rescan all» with a missing folder, «Keep»; F5; Delete; a database |
| P | plain, .SLD, database, drive P: | for `592628d`: the root opened, F11, F5, «Copy list», «Rescan all», «View list as a folders tree», «Remove» on another entry and on the root; `P:\` added; «Paste list» of entries with a trailing separator, then of `P:\`; a .SLD list holding `p:\`, `third\` and the missing `q:`; an uncached list; a database: its table, «Rescan all», F5 and «Remove» on the root |
| Q | plain | for `d05e990`: the Save panel's «Manage folders», «Back», «Paste list» after it, the panel from the menu |
| R0 | one image | for `905461a`: F5 in the kit's own start state, one image opened |
| R | plain, cached .SLD, database | for `ad55c7f` and `0ab5622`: «Remove» + «Yes» on batch N's `\|other`: the box, the folders list in memory, in the next save, in `staticfolders` |
| S | drive P: | for `08ae6f5`: the app started with `fd=P:`, `fd=P:\`, `fd=\|P:` (`run-fd.sh`) |
| T | one image, plain, drive P: | for `905461a`: F5 after one image of the root, of `pv\Alpha`; the root opened as a folder; «with subfolders» toggled |
| U | plain, cached .SLD, database, drive P: | for `c68164c` and `9aecb75`: F2 to `P:\`; F2 on `Été`, the folders list panel's F2 unpropagated; the normal and folder modes; the folders tree's rename and the normal mode in a database |
| V | uncached .SLD | for `0ab5622`: «Remove» + «Yes» while a files filter is on; the length of a lower-cased string |
| W0 | seen images list | probe at `8cbe643`: one file's two spellings replaced in two passes |
| W | seen images list | for `8cacdee`: two spellings of one file, a look-alike, folder mode, needles with `_` and `%`, an A to Z one, the panel |
| X | cached .SLD, drive P: | for `cce29a6` and `557c018`: the panel's seed folders list: a capital outside A-Z, an A to Z change and the modified mark, no match, the root alone |
| W9 | seen images list | for `ffccbb3`: a new path held by a record the same pass moves on, in both orders; a chain of three |
| Y7 | plain, database, drive P: | for `78120a1`: `\|other` over `other\sub` and an orphan subfolder, `\|été` over `été\sub`, the recursive `other\sub`: F11 and F10, «Select files», «Deselect files», «With a new QPV instance», «Jump», F3; the folders list panel's «Select files», «Jump», F3 on `other`; the same in a database; the root as `\|p:` |
| Y8 | cached .SLD, database | for `ce1b5f8`: «Recursive folder scan» and the save question answered «Discard»; then a save; private mode; a database |
| Y9 | database, cached .SLD, plain | for `caa77ef`: F2 on `pv` renamed `pvNew` on the disk: «No», «Yes» and the database opened again, unticked with `pv\alpha` inside `\|pv`, a files filter on, an image of the same name in the new folder and in a subfolder of it, a new folder that has rows already; a cached .SLD list with its folders list loaded, not loaded, «No»; a plain list |
| Z10 | cached .SLD, database | for `20d9d3b`: `\|other` and `third` added, the folders list in memory, saved, opened again; both re-dated and rescanned; `other\sub` added inside `\|other`, F5; `third` turned non-recursive, F5; `\|fourth` added in a database |
| Z12 | plain, database | for `b55b247`: F11 before F10; «Select files», «Deselect files», on a row never counted; «Deselect all»; «%» and «Size (MB)» sorted; F11, F10 in each of its two parts and «Select files» stopped; F3 with files selected outside the filter, then F11, F10, «Select files», «Deselect all»; the same in a database, its filter a query; Z12B: F10 on a pasted folder not scanned yet |
| Z14 | plain, database | for `2400d23`: quoted paths, one with a trailing separator, a `\|` inside or outside the quotes; F5 and F11 on the pasted `fifth`; the same lines again; two quoted folders and a path that is no folder; a line that is no folder; a database: its own folder, then a quoted new one |

Not run after `32c435d`: a rescan stopped after «Keep» or «Purge», «Rescan all» with a files
filter on, a purge that leaves the index empty, the question on stock AutoHotkey (only its
load check), and anything on Windows.

**Runs of 2026-11-16**, for findings 3 to 6. The kit was copied to
`.claude/scratch/seed-folders-fixes-2026-11-16/`: `app/` as before, plus `seed-part2.ahk` for
batches N to Q (joined by `build-wrappers.sh`), and `patch.py` turns the folders tree that
«View list as a folders tree» opens into a log line. Every batch ran on `e62ea25`, before the
fixes (logs `*-h`), and on the text of `d05e990` (logs `*-f`); batch N also ran on the text of
`1e1c2b6` alone (`n-f3`). `compare.sh h f` compares the logs line by line, after the dates and
the random current image are blanked out: G, J and K give the same lines; the others differ
where the fixes act, and nowhere else. Batch L stops at its last step, L3, the step known not
to be valid: «Purge» now removes the two files of `Été`, the index is left empty, and QPV's «No
files left» box waits for an answer the batch does not give; batch M repeats the step in a
valid state. `snap/` holds the texts tested: `head.ahk` is `e62ea25`, `f3.ahk` to `f6.ahk` are
`1e1c2b6` to `d05e990`, each committed as tested (sha256 compared). `loadcheck2.sh <file>`
load-checks a text with AutoHotkey_H (`/iLib`, and a full load) and stock AutoHotkey 1.1.37
(`/iLib`): all four commits load. Not run: the folder dialog, the folders tree itself, an .SLD
list for finding 4, Windows.

**Runs of the follow-ups**, 2026-11-16, in the same kit: `seed-part2.ahk` gained batches R0 and
R to V, `run-fd.sh` starts the app with each `fd=` argument. Batches R to U ran on `89840b5`
(logs `*-h2`; R0's is `r0-h`) and every batch on the text of `0ab5622` (logs `*-g`); `compare.sh
f g` compares batches A to Q with the logs of `d05e990`'s text, which `89840b5` carries
unchanged: C, G, I, K, M and Q give the same lines; A, B, D, H, N, O and P differ only in the
default mark of the «Remove» box; E also in its `staticfolders` (the row of `other` gone, R
above); J and L only in which file the random display meets, and L stops at its known last
step. Step U6 and batch V were added after a check, V after a first version of `0ab5622`
built the folders list before the removal (V1 then held `third` alone). `snap2/` holds the six
texts committed (`g1.ahk` to `g6.ahk` = `ad55c7f` to `0ab5622`, sha256 compared); all six
load with AutoHotkey_H and stock AutoHotkey 1.1.37. `argtest/` is the check of a quoted
argument that ends with `\`. Lower case kept the length of every string tried (`İ` stays one
character, unchanged under Wine).

**Runs of the panel's two other targets**, 2026-11-16: batches W0, W and X ran on `8cbe643`
(logs `*-h3`) and W, X and U on the text of `557c018` (logs `*-k`); U gives the lines of `u-g`
but for the random display. The seen images list lives in the kit's folder
(`seenImagesList.db`), emptied at the start of W0, W and W9. `snap3/` holds the four texts
committed (`k1.ahk` to `k4.ahk` = `8cacdee`, `cce29a6`, `557c018`, `ffccbb3`, sha256
compared), all four loaded with AutoHotkey_H and stock AutoHotkey 1.1.37. W9 ran on
`557c018` (log `w9-k`), on `8cbe643` (`w9-h3`) and on `ffccbb3` (`w9-k4`, with W in `w-k4`).

**Runs of findings 7 to 9**, 2026-11-17. The kit was copied to
`.claude/scratch/seed-folders-7-9-2026-11-17/`: `app/` as before, plus `seed-part3.ahk` for
batches Y7, Y8 and Y9 (joined by `build-wrappers.sh`); `patch.py` logs the new parameter of
`OpenNewQPVinstance()`, and the folders list kit's `patch.py` takes it too. Each fix ran on its
own text against `803a668` (logs `*-h`): Y8 and G on the text of `ce1b5f8` (`*-f8`), Y9, E, H
and I on that of `caa77ef` (`*-f9`), Y7 and B on that of `78120a1` (`*-f7`); `snap/` holds the
three texts, each committed as tested (compared byte for byte). Then every batch ran on
`803a668` and on the text of `78120a1`, and `compare-all.sh` compared them batch by batch, the
dates, the random current image and the window-update journal lines blanked out, the jump
lines compared as they are, since the blanking hides the file a jump lands on:

- A, C, D, K, M, N, O, P, Q, R0, R, T, V, W, X and W9 give the same lines;
- B, E, G, H and I differ at B1 to B4, E4, E5, G1, H1 and I2 alone, as the notes above say;
- J, L and U differ only in which image the random display then fails to find on the disk; L
  stops at its known last step, L3, on both;
- Y8 and Y9 give, on the text of `78120a1`, the lines they gave on the text of their own fix.

The folders list kit (`.claude/scratch/static-folders-panel-2026-11-10/`) ran D2, E, F, H, I,
Q, T, U, Y, Z, SG2 and SG3 on `803a668` (logs `*-s17h`) and on the text of `78120a1`
(`*-s17f`), the six rename batches also on that of `caa77ef` (`*-s17f9`): D2, E, F, H, I, T, U
and Z give the same lines; Y, SG2 and SG3 differ in the random display alone; Q stops on both
at the same question, added after the batch was written. `argcheck/` runs
`OpenNewQPVinstance()` as committed, its launch turned into an output line. The three texts load
with AutoHotkey_H and stock AutoHotkey 1.1.37 (`/iLib`); AutoHotkey_H ran every batch on the
text of `78120a1`, and each fix's own batches on its own text. Batch S, the new instance's arguments, was not run again: its code did not change. The
logs of the 2026-11-16 kit were made in another folder, where the seed folders lists sort in
another order: only logs of one kit are compared. Not run: Windows; the new instance's launch;
F3 on a drive root in a database; a rename onto a folder that has rows, on a cached .SLD list.

**Runs of findings 10, 12 and 14**, 2026-11-17. The kit was copied to
`.claude/scratch/seed-folders-10-14-2026-11-17/`: `app/` as before, plus `seed-part4.ahk` for
batches Z10, Z12 and Z14 (joined by `build-wrappers.sh`); `snap4/` holds `head.ahk`
(`98ea716`) and the three texts committed, `f10.ahk`, `f12.ahk` and `f14.ahk`, made from it by
`mkfix.py` (next to `app/`), each committed as tested (compared byte for byte). Every batch ran
on `98ea716` (logs `*-b`); each fix's batches ran on its own text: Z10 and G on that of
`20d9d3b` (`*-f10`), Z12 and B on that of `b55b247` (`*-f12`), Z14 and C on that of `2400d23`
(`*-f14`). Then every batch ran on the text of `2400d23` (`*-z`), and `compare-all.sh` compared
the two sets batch by batch:

- H, I, J, K, M, N, Q, R0, R, T, V, W, W9, X, Y8 and Y9 give the same lines;
- B, C, G and the three new batches differ where the fixes act, as the notes above say;
- A4, E5, O5, P1 and Y7.5 differ in «Difference» alone, left empty by F11 before F10; D and P
  also in the message of «Paste list»;
- L and U differ only in the image the random display then fails to find on the disk; L stops
  at its known last step, L3, on both.

Batch Z12B, added after the commits, gives the lines of `98ea716` on the text of `2400d23` but
for the message of «Paste list» (logs `z12b-b`, `z12b-z`). The kit's `results/` also holds the
logs copied with it from `seed-folders-7-9-2026-11-17`, made in that folder: only `*-b`,
`*-f10`, `*-f12`, `*-f14` and `*-z` are this kit's. Batch S was not run: its code did not
change. The folders list kit ran its batch RP on
`98ea716` (`rp-b17`): the lines of `rp-fix4`, its run on the text of `26c47e1`. It also ran F,
T, U, W, X and Z, the batches that reach this panel or the functions the fixes changed, on
`98ea716` (`*-b17`) and on the text of `2400d23` (`*-z17`): F, T, U, W and Z give the same
lines; X differs only in the random image shown after each rescan. The three texts load with
AutoHotkey_H and stock AutoHotkey 1.1.37 (`/iLib`), and AutoHotkey_H loads each in full. Not
run: Windows; the Escape key and its prompt during a count (the kit stops a count from inside
the check the key feeds); the menu items themselves, the kit calling their functions.

Batches E and H queue an answer for the question added by `32c435d` («Keep», steps E2 and
H2); on `bf72416` that answer finds no box and expires.

Traps met: a space followed by `;` starts a comment even inside an AutoHotkey string, write
`` `; ``; `run-all.sh` must be executable before it is started in the background. Since
2026-11-16: a queued answer that finds no box leaves the answers queued after it waiting,
never scheduled, so the next box of the batch is not answered (batch N clears the queue after
N4); adding a folder whose files are indexed already asks «Do you want to add it to the list?»;
the folders list panel of a plain list first asks to generate it; the kit opens folders through
`coreOpenFolder()`, which keeps the folders list in memory where `OpenFolders()` clears it, so
batch R clears it before each step. Since 2026-11-17: a plain folder opened over a database (the
kit's `tsOpenPlain()`) leaves the database open, and the next database cannot be written («file
is not a database»): `tsFresh()` closes the list first, through `resetMainWin2Welcome()`; batch
P deletes `P:\r1.png`, so T, U and X need a `run-all.sh` of their own. A stop forced through
`tsAbortAfter` stamps the time of the stop, and for one second the panel refuses to close:
batch Z12 waits 1.1 s after each stop.
