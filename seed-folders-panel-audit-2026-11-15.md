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

**Status, 2026-11-15, at `32c435d`.** Findings 1 and 2 are fixed, in `fe812ec` and
`32c435d`, with Marius's choices (decisions 1 and 7, settled below). The question that fixes
finding 2 also fixes finding 11 for this panel. Finding 5 is partly fixed: a drive root loads
from a .SLD list and «Paste list» keeps it. The other findings are open. A fixed section ends
with a note on what the code does now, with its lines at `32c435d`; every other line number
is at `bf72416`.

Findings 1 to 4 lose data: seed folders vanish from the list for good; index entries and
database rows of folders the user did not touch are deleted; a protected folder's files can
be deleted from the disk. Each needs nothing unusual: a seed folder scanned without its
subfolders, a folder on a drive that is not plugged in, or a folder name with a letter such
as «É» or «Ș».

## Terms

- **Seed folders list**: what this panel shows, the folders the index is generated from. The
  code calls them «dynamic folders»: `DynamicFoldersList` in memory, the `[DynamicFolderz]`
  section of a .SLD file (`DF1=`, `DF2=`, …), the `dynamicfolders` table of a database.
  Every entry is stored in lower case.
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

| # | Finding | Harm | Checked | Status at `32c435d` |
|---|---------|------|---------|---------------------|
| 1 | A .SLD list loses every `\|` entry: right after a save, and for good at the next save; an uncached list never scans them | high | run | **fixed**, `fe812ec` |
| 2 | A missing folder is dropped from the seed folders list by a save, by «Paste list» and by every rewrite of a database's list | high | run | **fixed**, `32c435d`: kept; «Rescan all» and «Rescan folder» ask to keep or purge it (decision 1) |
| 3 | «Remove» answered «Yes» on a `\|` entry also removes the files of the seed folders inside it, in a database for good | high | run | open |
| 4 | Plain and .SLD lists: a folder name with a capital letter outside A-Z defeats counting, selecting, jumping and removing; «Rescan folder» indexes its files twice; «Set as the protected folder» does not protect it: its files can be deleted from the disk | high | run (plain list), read (.SLD) | open |
| 5 | A drive root as a seed folder: not listed, dropped by «Remove» and «Paste list», its files dropped by «Rescan all», not loaded from a .SLD list | medium | run | **partly fixed**, `fe812ec` and `32c435d`: loaded from a .SLD list, kept by «Paste list» |
| 6 | The Save panel's «Manage folders» button does nothing; the panel's «Back» button is never shown | medium | run | open |
| 7 | The actions on a `\|` entry reach into its subfolders; «Difference» compares two different things | medium | run | open |
| 8 | «Recursive folder scan» does not mark a .SLD list as modified: the change is lost without a question | medium | run | open |
| 9 | Database: «Rename index entry» from this panel leaves the `staticfolders` table and the captions on the old paths; the folders list marks every renamed folder as changed | medium | run | open |
| 10 | A `\|` folder added or rescanned on a cached .SLD list gets no row in the folders list | low | run | open |
| 11 | «Rescan folder» on a missing folder deletes its entries, in a database with their cached data | medium, a decision | run | **fixed for this panel**, `32c435d`: it asks to keep or purge (decision 7) |
| 12 | The count columns: «Difference» 0 for a folder never counted on disk, counts that follow a files filter, «Selected» not refreshed, «%» and «Size (MB)» sorted as whole numbers | low | run, read | open |
| 13 | «Remove»: the entry is gone before the question, which has no «Cancel»; the box shows the internal `\|` | low | run, read | open |
| 14 | «Paste list»: a trailing separator makes an entry that matches none of its files; a quoted path is dropped without a word | low | run | open; since `32c435d` the quoted path is counted among the lines skipped |
| 15 | Small things | low | run, read | open |

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
the two files of `Été` still indexed). «Rescan all» → «Purge» is not affected: it rebuilds
the index.

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
entries as they are, `p:\` included (run, batch D5). The panel still hides `p:`, «Remove»
still drops a root, «Copy list» and the tree view still leave it out, and «Rescan all» still
skips it and drops its files.

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
missing `third`, «Keep»: its two rows stay in `images`. The folders list panel's «Rescan
folder(s)» still removes the entries of a folder it cannot reach (its finding 14).

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

## 13. «Remove»: no way back

`BTNremDynaSelFolder()` :97012-97032

- The entry leaves the list, and in a database the table, before the question (:97027-97029);
  the question has «Yes» and «No» only (:97032). «No» keeps the files, not the entry.
- With one file in the index there is no question at all (`If (maxFilesIndex>1)`, :97031):
  the entry goes and its file stays (read).
- The box shows the stored form, `|other\`, and calls it a «dynamic folder» (run, batches
  B6 and E1).

Correction: decision 3; strip the `|` from the text.

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

## 15. Small things

- **Menu letters** (run, batch A3, the menu's labels): `&R` on «Rescan folder», «Recursive
  folder scan» and «Remove folder from this list»; `&C` on «Copy this folder path as text» and
  both «Count…» items. The letter then moves between the items instead of choosing one.
- **Names.** The rename box is titled «Rename static folder entry» (run, batch E4, :97887);
  «Copy list» says «Dynamic folders list copied to clipboard» (:96962); the remove box is
  «Remove dynamic folder» (:97032). The panel calls them seed folders.
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
  lower case), so finding 4's protection failure applies there too (read).
- **C.** `cleanDynamicFoldersList()` (:87694) drops every entry inside a recursive one. After
  «Recursive folder scan» makes `|d:\pics` recursive, the entry `d:\pics\sub` disappears from
  the list, and making `d:\pics` a `|` entry again does not bring it back (read).

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
   QPV instance».
3. **«Remove»**: ask first, with «Cancel», before the entry goes, or keep «Yes» / «No» about
   the files only?
4. **A drive root**: `d:` (as «Open folder» stores it and as the folders list keeps it) or
   `d:\` (as «Add» stores it)?
5. **Letter case**: keep the seed folders list in lower case and compare in lower case
   everywhere, or keep the spelling of the disk (which would also settle decision 10 of the
   folders list audit for this panel)?
6. **The Save panel's «Manage folders»**: close the Save panel and open this one, with
   «Back», or take the button out? The `If AnyWindowOpen` test was presumably added for the
   custom shortcuts; it could stay for every other route.
7. **«Rescan folder» on a missing folder**: skip it, ask first, or remove its entries as
   now? Same as decision 2 of the folders list audit. **Settled for this panel**
   (`32c435d`, Marius's answer): ask, «Keep» or «Purge», as in decision 1. Decision 2 of the
   folders list audit stays open for that panel.

Suggested order at `32c435d`: findings 8 and 9 need no decision, nor does sparing the other
seed folders in finding 3; then 10, 12, 13 and 14; the rest once the decisions are taken.

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

Not run after `32c435d`: a rescan stopped after «Keep» or «Purge», «Rescan all» with a files
filter on, a purge that leaves the index empty, the question on stock AutoHotkey (only its
load check), and anything on Windows.

Batches E and H queue an answer for the question added by `32c435d` («Keep», steps E2 and
H2); on `bf72416` that answer finds no box and expires.

Traps met: a space followed by `;` starts a comment even inside an AutoHotkey string, write
`` `; ``; `run-all.sh` must be executable before it is started in the background.
