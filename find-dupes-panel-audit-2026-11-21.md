# «Find image duplicates» panel audit, 2026-11-21

Scope: `PanelFindDupes()` (:91057) and the panel it builds: its four tabs, its 19 property checkboxes,
its hash preview, its dropdowns, edits and eleven buttons, the keys and right-click menu it answers,
the routes that open it, the non-database confirmation box, and everything its buttons run:

- «Find duplicates»: `BTNfindDupesNow()` (:91389), `retrieveDupesByProperties()` (:88992),
  `filterDupeResultsByHdist()` (:88724), `changeHdistLevelCached()` (:88841), `collectSQLFileInfosNow()`
  (:36649), `generateSQLimageFingerPrintHash()` (:37188), and the `qpvmain.dll` duplicates engine
  (`QPV DLL source code/lib/dupes-search.h`, `dupes-pixels.h`);
- «Auto-select dupes»: `BTNautoselectDupes()` (:91300), `PanelAutoSelectDupes()` (:47589),
  `autoSelectDupesInGroups()` (:89425);
- «Collect image pixels data»: `BtnCollectDupesData()` (:91217);
- «Purge cached data»: `BtnPurgeCachedSQLdata()` (:28461), `PanelPurgeCachedSQLdata()` (:91569),
  `corePurgeCachedSQLdata()` (:91627), `PurgeCachedDataModifiedFiles()` (:91696),
  `PurgeCachedDataSelectedFiles()` (:91793), `selectivePurgeCachedSQLdata()` (:91862);
- «Overview»: `PanelCachesOverview()` (:36356), `uiPopulateCachesOverview()` (:36407),
  `uiCachesOverviewSizeEstimate()` (:36537), `BTNignoredEntriesActs()` (:36392),
  `coreCachesOverviewIgnoredAct()` (:36609), `BTNlistDeadEntries()` (:36402);
- «Select all», the three Help buttons, Tab 4's `X` and `+`, «Cancel», and the follow-up actions that
  read the panel's state on a duplicates list: Ctrl+F (`PanelChangeHamDistThreshold()` :47079) and
  Sort → «Duplicates ID group» (`ActSortDupeGroups()` :37576).

Line numbers are `quick-picto-viewer.ahk` on `development` at `35329bc`. The audit changed no code.

Fifteen findings and a list of small things. Each one says how it was checked: **run** means the real
application did it under headless Wine, on the stock AutoHotkey 1.1.37.02; **read** means it follows
from the code and was not run. Nothing was run on Windows. The test kit is described at the end. Each
run carries a tag such as B1a or C1e: the letter names its batch (listed under «How this was checked»),
and the tag marks its lines in the kit's logs.

Two patterns noted in earlier reports meet this panel here: Finding 8 is where `PanelFindDupes()` hits
the unchecked result of `createSettingsGUI()` (counted across panels in
`structured-copy-move-panel-audit-2026-11-14.md`), and small thing 16.9 meets the same history
substring check as Finding 12 of `files-filter-panel-audit-2026-11-20.md`. The keyboard menu key's
250 ms gate (`move-copy-files-panel-audit-2026-11-20.md`, Seen in passing D) applies to this panel too
and is noted briefly under «Seen in passing».

**Status, 2026-11-21.** Finding 1 is partly fixed in `60f52cc` (by Marius): «Find duplicates» asks to
save an edited image before running, while Sort → «Duplicates ID group» (`ActSortDupeGroups()`) is
still open. Finding 2 is partly fixed: 2.1 is fixed in `60f52cc` (by Marius), and 2.2 and 2.4 are
fixed in `d94e991` (with Marius's answers to decisions 2(b) and 2(d), building on `60f52cc`'s
`"reopen"` cleanup); 2.3 (one selected file in Option 6) stays open. `d94e991` also adds Option 7's
missing `uiPopulateCachesOverview("kill")` from 16.10. Findings 4 (`ecddb73`), 6 (`6df9c63`) and 7
(`2227f02`) are fixed (with Marius's answers to decisions 4, 6 and 7); `ecddb73` also removes the dead
`gupdateUIFiltersPanel` bindings from 16.3. Findings 3, 5, and 8 to 16 are otherwise open. A fixed or
partly fixed section ends with a note on what the code does now; those notes cite lines at the
revision named in the note (`d94e991` for Findings 1–2, `2227f02` for Findings 4, 6 and 7).

## Terms

- **The panel**: panel 49, «Find image duplicates». Its routes: the Find menu's «Find duplicate images»
  (:68980), the files list menu's «Find duplicate images» (:72736), a right-click on the Statistics
  toolbar button (:105902), «Find duplicates panel» in Statistics (`OpenFileDupesPanel()` :28455, which
  opens Tab 3), «Find duplicates» in «Auto-select duplicate images» (:47621), «Main panel» in «Change
  hashes threshold» (:47154), and F8 (`openPreviousPanel()` :27634).
- **Tab 1, «General»**: the Presets list (`userFindDupePresets`, 1 to 6 plus 7 = «Custom mode»), «Select
  all», nineteen file/image/histogram checkboxes (`UIcheck*`), «Matching precision» (`Exact`, `Close`,
  `Loose`, with its ` ?` Help button).
- **Tab 2, «Image hashes»**: «Image hash type» (`Ignore`, `dHash 8x8`, `pHash DCT 32x32`, `lHash 8x8`),
  left and right hash bit-crops (`editF5` / `hamDistLBorderCrop`, `editF6` / `hamDistRBorderCrop`), the
  90×90 «Image hashing preview», «Threshold» (`editF7` / `userFindDupesHamDistLvl`, with its ` ?` Help
  button), «Identify images horizontally flipped» (`findFlippedDupes`), «Attempt to identify color
  inverted images» (`findInvertedDupes`), «Break the groups based on hamming distance [similarity]»
  (`BreakDupesGroups`), «Filter results using Mean-Squared Difference [32x32]» (`PerformMSDonDupes`)
  and its threshold (`editFr` / `userFindDupesMSElvl`).
- **Tab 3, «Collect data»**: «High-quality resampling (slower)» (`hamDistInterpolation`), «Blur images
  by 4x4 to weed out artefacts» (`dupesApplyBlur`), «pHashes based on averages, instead of the median
  values» (`userpHashMode`), «Compress gray levels by a factor of» (`editFc` / `graylevelCompressor`),
  «Purge cached data», «Collect image pixels data», «Overview».
- **Tab 4, «Filtering»**: the string field (`dupesStringFilter`), `X` (clear), `+` (copy the active
  files list text filter, shown only when one is active), «String filter matching mode»
  (`userFilterStringPos`: Anywhere, Begins with, Ends with), «Apply filter based on»
  (`userFilterWhat`: Full path, Folder path, File name), «Must not contain the given string»
  (`userFilterStringIsNot`), «Exclude the current list of results» (`excludePreviousDupesFromList`).
- **Bottom row**: «Find duplicates» (Default), «Auto-select dupes» (shown only while viewing a
  duplicates list, `testIsDupesList()`), «Help», «Cancel».
- **Database list (`.SLDB`)**: a files list saved as an SQLite database (`SLDtypeLoaded=3`, path in
  `CurrentSLD`). Paths are stored lower-cased.
- **Pairs cache**: the matched pairs held in `qpvmain.dll` after a hash search, queried by
  `dupesPairCount()` and re-filtered by Ctrl+F (`PanelChangeHamDistThreshold()` →
  `changeHdistLevelCached()`).
- **One-file rule**: `getSelectedFiles(0, 1)` deselects a selection of exactly one file (:39963-39966),
  so callers that rely on it treat one selected file as none.
- **Save question**: `askAboutFileSave()` (:65838), «The currently modified image is about to be
  discarded… Would you like to save the current image?».
- **Edited image**: an image with unsaved edits. In the runs it is simulated by setting its state (an
  edited bitmap, five undo levels, «modified»), as in the earlier kits.
- **`<work>`**: the folder in which each test builds its files and `.SLDB`. **`<app>`**: the scratch
  copy's folder, QPV's folder in the runs.

## Summary

| # | Finding | Harm | Checked | Status at `2227f02` |
|---|---------|------|---------|---------------------|
| 1 | «Find duplicates» discards an edited, unsaved image without a question — even when no duplicates are found | high | run | **partly fixed**, `60f52cc` («Find duplicates» fixed; `ActSortDupeGroups()` open) |
| 2 | «Purge cached data»: «All (modified files only)» clears `CurrentSLD` and ignores the active filter it promises; «All (selected files only)» refuses one selected file; the dialog reopens Statistics instead of this panel | high | run | **partly fixed**, `60f52cc`, `d94e991` (2.1, 2.2, 2.4 fixed; 2.3 open) |
| 3 | «Collect image pixels data» silently forces flipped-image detection on; Preset 1 runs disabled Tab 2 options, and Custom + dHash runs disabled inverted-image detection | high | run | open |
| 4 | «Cancel» does not cancel: live handlers mutate globals and write to the `.SLDB` on disk, corrupting Ctrl+F threshold filtering and sorting on an active duplicates list | medium | run | **fixed**, `ecddb73` |
| 5 | «Auto-select dupes» selects nothing on a single duplicate pair, and leaves `markedSelectFile=0` when re-run while files are already selected | high | run | open |
| 6 | Presets 2 to 6 (including «Identical file names») never collect missing data and report «Found no image duplicates» on a fresh database | medium | run | **fixed**, `6df9c63` |
| 7 | Tab 4's string filter and «Exclude the current list of results»: singletons in non-hash modes, `\|\|\|` matching every file, and «Exclude» enabled with no filter active | medium | run | **fixed**, `2227f02` |
| 8 | «Main panel» in «Change hashes threshold» within a second of a message box raises an AutoHotkey error; «Overview», Escape and context-menu «Close panel» silently fail for a second after Help | medium | run | open |
| 9 | The «Found N groups» count is wrong on every hash search, and a failed second search desyncs the selection count and breaks Ctrl+F on the restored list | medium | run, and read for filter globals | open |
| 10 | The non-SLDB dialog defaults to «Remove duplicate entries», and «Yes» opens «Save indexed files list» on `.SLD` instead of `.SLDB` | medium | run | open |
| 11 | After «Find duplicates» runs once, `qpvmain.dll` keeps the `.SLDB` open, so rebuilding or overwriting the database fails with «Permission denied» and leaves `SLDtypeLoaded=2` | medium | run | open |
| 12 | Aborting data collection or hash generation mid-run does not stop «Find duplicates» | medium | run, and read for hashing | open |
| 13 | Panel rebuilds («Collect image pixels data», «Overview» → «Back», «Dark mode UI», «Large UI fonts») lose unsaved settings, jump to Tab 1 from Statistics, and drop «Back» inside «Overview» | low | run | open |
| 14 | Numeric threshold edits (`editF7`, `editFr`, `editFc`) reject `0`, and typing an out-of-range number leaves it on screen while silently reading the old value | low | run | open |
| 15 | «Size (kilobytes)» goes stale when «Size (bytes)» is checked, and Tab 2's preview overlaps «Identify images horizontally flipped» in Large UI fonts | low | run | open |
| 16 | Small things, numbered 16.1 to 16.16 | low | run and read | open (16.3 fixed in `ecddb73`; 16.10 Option 7 overview kill fixed in `d94e991`) |

Finding 1 loses unsaved image edits for good (fixed for «Find duplicates» in `60f52cc`; Sort →
«Duplicates ID group» remains open). Finding 2 clears `CurrentSLD` (fixed in `60f52cc`), purges
cached data outside the active filter that its own confirmation box promised to respect and reopens
the wrong panel (both fixed in `d94e991`), and refuses a single selected file in Option 6 (open).
Findings 3 and 5 silently change which images match or get
selected for deletion: Preset 1 can group unrelated, flipped or inverted images under greyed-out
controls, while «Auto-select dupes» either clears its own selection on a single pair or leaves rows
selected with a selection count of zero. Findings 4 (`ecddb73`), 6 (`6df9c63`) and 7 (`2227f02`) are
fixed; Findings 9 to 12 still return wrong results, break follow-up actions (Ctrl+F, Sort, Rebuild), or
ignore an abort.

---

## 1. «Find duplicates» discards an edited, unsaved image without a question — even when no duplicates are found

`BTNfindDupesNow()` :91389-91543; `retrieveDupesByProperties()` :88992-89395; `renewCurrentFilesList()`
:65231-65259

Neither `BTNfindDupesNow()` nor `retrieveDupesByProperties()` calls `askAboutFileSave()`. Once the
candidate query returns at least two rows, `retrieveDupesByProperties()` calls `renewCurrentFilesList()`
(:89242), which sets `currentImgModified := 0` (:65251) and calls `terminateIMGediting()` (:65258)
**before** the Hamming sweep, MSD filter and string/exclude filters run. Even if those filters leave
zero duplicates and the old list is restored from `backupArray`, the edited bitmap and undo stack are
already gone.

Run (batch B), with an edited image simulated on index 1 (`undoLevelsRecorded=5`,
`currentImgModified=1`, `UserMemBMP=valid`), Preset 1:

- **Duplicates found** (B1a): no save question; `terminateIMGediting(0)` runs during
  `renewCurrentFilesList()`; «Found 1 groups of duplicate images | Total images: 2»; afterwards
  `undoLevelsRecorded=0`, `currentImgModified=0`, `UserMemBMP=none`.
- **No duplicates found after the Hamming sweep** (B1b): four distinct 64×64 images (so the aspect-ratio
  query yields 4 candidates, and the Hamming sweep drops all of them). No save question;
  `terminateIMGediting(0)` still runs; «Found no image duplicates after filtering the duplicates list»
  reopens the panel; afterwards `undoLevelsRecorded=0`, `currentImgModified=0`, `UserMemBMP=none`.

The same lines run for Sort → «Duplicates ID group» (`ActSortDupeGroups()` :37576, read).

**Partly fixed in `60f52cc`** (Marius). `BTNfindDupesNow()` now calls
`askAboutFileSave(" and the identification of duplicated images will begin")` (:91415-91416 at
`d94e991`) before closing the panel or running `retrieveDupesByProperties()`. Run at `d94e991`
(batch I):

- **Duplicates found, «Cancel»** (I1a) and **0 duplicates, «Cancel»** (I1d): asks «The currently
  modified image is about to be discarded and the identification of duplicated images will begin.
  Would you like to save the current image?»; «Cancel» leaves all 5 undo levels intact
  (`currentImgModified=1`, `UserMemBMP=valid`) and keeps panel 49 open (`AnyWindowOpen=49`).
- **Duplicates found, «Save»** (I1b): closes panel 49, opens `PanelSaveImg` (`AnyWindowOpen=35`), and
  keeps all 5 undo levels intact.
- **Duplicates found, «Discard»** (I1c): proceeds with the search (`maxFilesIndex=2`, `isDupes=1`,
  `pairs=1`) and discards the edits as confirmed.

**Still open:** Sort → «Duplicates ID group» (`ActSortDupeGroups()` :37574-37577) was not changed.
Run at `d94e991` (I1e): invoking `ActSortDupeGroups()` on an edited image while viewing a duplicates
list shows no save question and immediately runs `terminateIMGediting(0)` (`undoLevelsRecorded=0`,
`currentImgModified=0`, `UserMemBMP=none`).

---

## 2. «Purge cached data»: cleared `CurrentSLD`, ignored filter, one-file refusal, wrong panel reopened

`BtnPurgeCachedSQLdata()` :28461-28465; `PanelPurgeCachedSQLdata()` :91569-91625;
`PurgeCachedDataModifiedFiles()` :91696-91791; `PurgeCachedDataSelectedFiles()` :91793-91850

Four bugs sit on the «Pur&ge cached data» button of Tab 3:

1. **«All (modified files only)» clears `CurrentSLD` and never puts it back.**
   `PurgeCachedDataModifiedFiles()` saves `backCurrentSLD := CurrentSLD` (:91710) and clears
   `CurrentSLD := ""` (:91711) to guard long operations, and never restores `CurrentSLD` before returning
   (:91791). (Compare `PurgeCachedDataSelectedFiles()`, which restores it at :91837.) Run (C1e, C1e2):
   after purging modified files, `CurrentSLD` is empty; reopening `PanelFindDupes()` and clicking
   «Overview» then fails with «WARNING: A .SLDB files list database must be opened first to invoke this
   panel.». Every other feature that checks `CurrentSLD` (save, rebuild, database settings, window
   title) sees no open database until the `.SLDB` is opened again (read).

2. **«All (modified files only)» promises to respect the active filter and ignores it.** When a
   `SQL:query:WHERE` filter is active, `PanelPurgeCachedSQLdata()` appends «The purge will occur only
   for the files matching the current files list filter. To purge all the cached data, deactivate
   current filter.» to the confirmation box (:91585-91587). Yet `PurgeCachedDataModifiedFiles()` queries
   the whole `images` table without `extractSQLqueryFromFilter()` (:91697). Run (C1e): a 4-file database
   filtered to `dir1`, with `dir2\a2.png` modified on disk outside the filter. The confirmation box
   prints the promise above; answering «Yes» reports «Finished purging cached data for modified image
   files | Scanned files: 4 | Modified files identified: 1» and purges `dir2\a2.png` (`fsize` rows drop
   from 4 to 3). Read, not run: the same loop deletes missing or `< 3`-byte files from the database
   (`deleteSQLdbEntry()`, :91731-91733) across the entire database without removing them from
   `resultedFilesList`.

3. **«All (selected files only)» refuses one selected file and deselects it.**
   `PurgeCachedDataSelectedFiles()` calls `getSelectedFiles(0, 1)` (:91794), whose one-file rule clears
   a selection of one file. Run (C1d): one file selected, option 6 confirmed with «Yes»: «WARNING: No
   files are currently selected to perform given operation»; `markedSelectFile` becomes `0` and all 4
   rows keep their `fsize`.

4. **The dialog reopens Statistics instead of «Find image duplicates» — and reopens nothing after «No».**
   `BtnPurgeCachedSQLdata()` (:28461-28465) closes the current panel, sets `AnyWindowOpen := 49` as a
   flag, and calls `PanelPurgeCachedSQLdata()`, which unconditionally opens `PanelWrapperFilesStats()`
   (panel 58) at :91623-91624 — regardless of whether the user came from Statistics or from
   `PanelFindDupes()`. And if the user answers «No» at the second confirmation box (:91591-91592), the
   function returns early before :91623 and reopens neither panel. Run:
   - «Cancel» in the choice box (C1a): opens Statistics (`AnyWindowOpen=58`).
   - «Purge» → «No» at confirmation (C1b): no panel reopens (`AnyWindowOpen=0`).
   - «Purge» → «Yes» on «Image hashes» (C1c): purges `dHash` (4 → 0) and opens Statistics
     (`AnyWindowOpen=58`).

**Partly fixed in `60f52cc` (Marius) and `d94e991`** (with Marius's answers to decisions 2(b) and
2(d); lines at `d94e991`):

- **2.1 — Fixed in `60f52cc` (Marius):** `PurgeCachedDataModifiedFiles()` restores
  `CurrentSLD := backCurrentSLD` before returning (:91805).
- **2.2 — Fixed in `d94e991`:** `PurgeCachedDataModifiedFiles()` applies
  `extraFilter := extractSQLqueryFromFilter()` to its query (`WHERE (<filter>) AND ifnull(fsize, '')!='' AND isDeleted=0`,
  :91707-91709) and to `getTotalIMGsSQLdb(extraFilter)` (:91717), marks missing or `< 3`-byte files
  `isDeleted=1` via `markSQLdbEntryDeleted(Rowu[1], 1)` (:91748) instead of deleting rows out from
  under `resultedFilesList`, frees `RecordSet` on the 0-row early return (:91720), and calls
  `uiPopulateCachesOverview("kill")` (:91807).
- **2.4 — Fixed in `60f52cc` (Marius) and `d94e991`:** `BtnPurgeCachedSQLdata()` passes `"reopen"` to
  `PanelPurgeCachedSQLdata("reopen")` (:28461-28463); `PanelPurgeCachedSQLdata()` captures
  `hostPanel := getHostPanelFunc()` before closing the caller (:91571), wraps the purge execution in
  `If InStr(msgResultu, "yes")` instead of returning early on «No» (:91594-91623), and reopens
  `PanelFindDupes(3)` when invoked from `PanelFindDupes`, `%hostPanel%()` for another host panel (such
  as `PanelWrapperFilesStats`), or nothing when opened standalone from the Sort menu (:91626-91634).
- **2.3 — Still open:** `PurgeCachedDataSelectedFiles()` still calls `getSelectedFiles(0, 1)` (:91812).

Run at `d94e991` (batch I):

- **2.1 and 2.2** (I2a–I2d): on a 4-file database filtered to `dir1` (`dir1\a1.png` deleted,
  `dir1\b1.png` modified; `dir2\a2.png` modified, `dir2\c1.png` deleted outside the filter), Option 7
  scans only `dir1` («Scanned files: 2 | Modified files identified: 1 | Missing files: 1»), keeps
  `CurrentSLD` intact, leaves all 4 rows in `images`, marks `dir1\a1.png` `isDeleted=1`, purges
  `dir1\b1.png`'s `fsize`, leaves both `dir2` files untouched, and reopens panel 49 on Tab 3 (I2a).
  Clicking «Overview» immediately opens panel 91 with `Ignored or deleted file entries = 1` (I2b).
  Re-running Option 7 under the same `dir1` filter finds 0 eligible rows (I2c). Clearing the filter and
  running Option 7 scans the 2 remaining `dir2` rows, purges `dir2\a2.png`, marks `dir2\c1.png`
  `isDeleted=1`, and «Overview» updates to `2` (I2d).
- **2.4** (I3a–I3c): from `PanelFindDupes` opened via Statistics → «Find duplicates panel»
  (`TabsPerWindow[49]` empty), «Cancel», «Purge» → «No», and «Purge» → «Yes» (hashes `4 → 0`) all
  reopen `PanelFindDupes` on Tab 3 (`AnyWindowOpen=49`, `tab=3`, I3a). From Statistics
  (`PanelWrapperFilesStats()`), all three reopen Statistics (`AnyWindowOpen=58`, I3b). Opened
  standalone with no panel open (`PanelPurgeCachedSQLdata()`, as from the Sort menu), all three leave
  no panel open (`AnyWindowOpen=0`, I3c).
- **2.3** (I4): Option 6 with 1 selected file still refuses and deselects (`markedSelectFile=0`,
  `fsize=4`), and now reopens panel 49 on Tab 3.

---

## 3. «Collect image pixels data» forces flipped detection on; disabled Tab 2 options still run under Preset 1 and Custom + dHash

`BtnCollectDupesData()` :91217-91239; `updateUIdupesPanel()` :91309-91330; `UIfindDupesCheckboxes()`
:91361-91386; `BTNfindDupesNow()` :91389-91543

1. **«Collect image pixels data» silently forces `findFlippedDupes := 1` globally.**
   ```ahk
   BtnCloseWindow()
   Global findFlippedDupes := 1
   scu := (findFlippedDupes=1) ? "HpixelzFsmall" : "pixelzFsmall"
   ```
   (:91233-91235). Even when «Identify images horizontally flipped» is unchecked, clicking «Collect
   image pixels data» sets `findFlippedDupes := 1`, collects mirrored pixel blobs (`HpixelzFsmall`) for
   every file, and leaves the checkbox ticked when the panel reopens. Run (B3b, H4): `findFlippedDupes`
   was `0`; clicking «Collect image pixels data» calls `collectSQLFileInfosNow("HpixelzFsmall", ...)`
   and reopens the panel with `findFlippedDupes=1`.

2. **Preset 1 disables all of Tab 2, yet runs with every disabled Tab 2 option still live.**
   `updateUIdupesPanel()` disables every control on Tab 2 when Preset 1 («Image content fingerprint
   (dHash 8x8)») is chosen (:91315, :91368-91386), so the user cannot see or change them without
   switching tabs and switching back to «Custom mode». Yet `BTNfindDupesNow()` reads all of Tab 2's
   controls (:91402-91410) and for Preset 1 only overrides the hash type and border crops
   (:91478-91482):
   ```ahk
   If (userFindDupePresets=1)
   {
      userFindDupesFilterHamDist := 2
      hamDistLBorderCrop := hamDistRBorderCrop := 1
      columnus := "imgframes,imgwhratio"
   }
   ```
   The disabled `userFindDupesHamDistLvl`, `findFlippedDupes`, `findInvertedDupes`, `BreakDupesGroups`,
   `PerformMSDonDupes` and `userFindDupesMSElvl` all remain in effect:
   - **After «Collect image pixels data»** (B3c): Preset 1 has `findFlippedDupes` disabled (`enabled=0`),
     yet runs with `flip=1`, generates flipped dHashes, and matches `a_flip.png` into the `a1`/`a2`
     group (5 images instead of B3a's clean 4).
   - **With stale `findInvertedDupes=1`** (H1c, on a strict monotonic gradient `g1.png` and its exact
     inverse `g1_inv.png`): Preset 1 has `findInvertedDupes` disabled (`enabled=0`), yet runs with
     `inv=1` and matches `g1.png` with `g1_inv.png` (4 images instead of the H1a control's 2).
   - **With stale `PerformMSDonDupes=1`, `userFindDupesMSElvl=300`, `userFindDupesHamDistLvl=12`**
     (B3f): Preset 1 has both `PerformMSDonDupes` and the threshold edit disabled (`enabled=0`), yet
     runs with `thr=12 msd=1/300` and returns 7 images (`a_edit.png` at `h=4, m=45`; `c1.png` and
     `a_flip.png` at `h=9, m=128` grouped with `b1`/`b2`).
   - `BreakDupesGroups` passes through the same way (read).

3. **Custom mode + `dHash 8x8` disables «Attempt to identify color inverted images», yet still runs it.**
   `UIfindDupesCheckboxes()` disables `findInvertedDupes` whenever `userFindDupesFilterHamDist=2`
   (`dHash 8x8`, :91378). If the checkbox was ticked earlier under `pHash` or `lHash`, switching to
   `dHash 8x8` greys it out checked, and `BTNfindDupesNow()` still reads `findInvertedDupes=1` and
   passes it to `dupesScanStep()`. Run (H1b vs control H1a): with `findInvertedDupes` disabled
   (`enabled=0`), `dHash 8x8` matches `g1.png` with `g1_inv.png` (`maxFilesIndex=4`, `pairs=2`, vs
   control H1a `maxFilesIndex=2`, `pairs=1`).

4. **Running Preset 1 or Presets 2 to 6 overwrites Custom mode's saved hash type and crops.** Unlike
   `findDupesPrecision` (which :91539-91541 explicitly passes as a local parameter so presets do not
   clobber the user's choice), Preset 1 writes `userFindDupesFilterHamDist := 2` and
   `hamDistLBorderCrop := hamDistRBorderCrop := 1` directly into the globals (:91480-91481; run B3f:
   Custom's `ham=3 crop=4/4` becomes `ham=2 crop=1/1`), and Presets 2 to 6 overwrite
   `userFindDupesFilterHamDist := 1` («Ignore», :91497-91498; run B3g: `ham=2` becomes `1`).

---

## 4. «Cancel» does not cancel: live handlers mutate globals and write to the `.SLDB`

`PanelFindDupes()` :91111-91115; `UIeditHammingInterpolation()` :28396-28405; `updateUIdupesPanel()`
:91309-91330; `UIfindDupesCheckboxes()` :91362-91364; `updateUIimageHashPreview()` :91247-91252;
`BtnUIsetDupesCilterCurrentFilter()` :96695-96698; `UIstringEditFilterErase()` :96700-96705

Unlike `PanelEnableFilesFilter()`, which snapshots its settings on open and restores them in
`CloseWindow()` (`InitialFilterSettingsPanel()` :99913), `PanelFindDupes()` saves nothing on open and
restores nothing on «Cancel». Worse, its live `g`-labels write straight into the super-globals — and
even into the `.SLDB` on disk — as the user clicks around:

- **Opening and immediately clicking «Cancel» resets the Files Filter panel's shared globals** (D1):
  `PanelFindDupes()` shares `userFilterWhat` and `userFilterStringPos` with `PanelEnableFilesFilter()`,
  and clamps both to `1` on open when `>= 4` (:91111-91115). With `userFilterWhat=4` («Parent folders»)
  and `userFilterStringPos=4` («RegEx»), opening `PanelFindDupes()` and clicking «Cancel» leaves both
  at `1`.
- **Tab 4's `+` and `X` immediately mutate `dupesStringFilter`** (D1, D2): clicking `+` and then
  «Cancel» leaves `dupesStringFilter=<dirA>`; clicking `X` and then «Cancel» erases it.
- **Tab 1, Tab 2 and Tab 3 controls mutate super-globals and write to the `.SLDB` on «Cancel»** (D2):
  changing preset, hash type, threshold, crops, MSD, gray-level compression and ticking «High-quality
  resampling», then clicking «Cancel», leaves `preset=7`, `ham=3`, `thr=12`, `crop=3/2`, `msd=1`,
  `gray=5`, `interp=1` — and `UIeditHammingInterpolation()` (:28404) has already written
  `hamDistInterpolation=1` into the `.SLDB`'s `settings` table on disk.
- **Downstream corruption of Ctrl+F («Change hashes threshold»)** (D3): after a Preset 1 search with
  threshold 5, opening `PanelFindDupes()`, switching to Custom, raising threshold to 12 and clicking
  «Cancel», then pressing Ctrl+F (`PanelChangeHamDistThreshold()`), shows «Cached threshold range:
  0 - 12.» even though the DLL pairs cache was built at threshold 5 and holds no pairs above 5.
- **Downstream corruption of Sort → «Duplicates ID group»** (G2): after a Preset 2 (histogram,
  non-hash) search yields `g=1` and `g=2` (`pairs=0`), opening `PanelFindDupes()`, picking Custom +
  `pHash DCT 32x32` and clicking «Cancel», then invoking `ActSortDupeGroups()` (:37576, which calls
  `retrieveDupesByProperties(0, 1)` reading the live `userFindDupesFilterHamDist`), causes the sort
  action to collect pixels, generate pHashes and convert the histogram list into a pHash Hamming list
  (`g=1_0, 3_0`, `pairs=2`).

**Fixed in `ecddb73`** (lines at `2227f02`):

- Tab 4 now uses its own three super-globals (`dupesFilterWhat`, `dupesFilterStringPos`,
  `dupesFilterStringIsNot`, :182, :91335-91337, :91359-91361, :91536-91538, :89019, :89029-89031,
  :89244-89249, :89304) instead of sharing and clamping `PanelEnableFilesFilter()`'s `userFilter*`
  globals, and drops the dead `gupdateUIFiltersPanel` bindings (16.3).
- Live UI handlers (`updateUIdupesPanel()` :91445, `UIfindDupesCheckboxes()` :91498-91500,
  `updateUIimageHashPreview()` :91385-91388) read controls into local variables, and Tab 4's `+`
  (`BtnUIsetDupesCilterCurrentFilter()` :96861) and `X` (`UIstringEditFilterErase()` :96866-96868)
  update only the Edit control without touching `dupesStringFilter`.
- `InitialFindDupesSettingsPanel(modus)` (:91082-91187) snapshots all panel globals (including all 19
  `UIcheck*` globals) when `PanelFindDupes()` opens (:91224-91225), commits them right before
  `BtnCloseWindow()` in `BTNfindDupesNow()` (:91676) and `BtnCollectDupesData()` (:91370), and
  restores them in `CloseWindow()` (:100078-100079) as well as on early validation returns in
  `BTNfindDupesNow()` (:91659, :91667).
- Removed live `UIeditHammingInterpolation()`; `BTNfindDupesNow()` now reads `hamDistInterpolation`
  (:91548), and `IniSLDBWrite("hamDistInterpolation", hamDistInterpolation)` runs only on commit in
  `BTNfindDupesNow()` (:91674-91675) and `BtnCollectDupesData()` (:91368-91369).

Run under headless Wine at `2227f02` (`testF4`): opening `PanelFindDupes()`, clicking `+`, changing
Tab 4 and clicking «Cancel» leaves `userFilterWhat=4`, `userFilterStringPos=4`, `userFilterStringIsNot=1`
and `dupesFilter*` intact; editing Tabs 1–4 (including `hamDistInterpolation=1`, `UIcheckimgwidth=1` and
`X`) and clicking «Cancel» — or failing «Find duplicates» validation and clicking «Cancel» — restores
every global and leaves `hamDistInterpolation=0` in the `.SLDB`; Ctrl+F still shows `Cached threshold
range: 0 - 5.` after raising threshold to 12 and cancelling; `ActSortDupeGroups()` stays on histogram
mode (`pairs=0`) after cancelling Custom + pHash; committing via «Find duplicates» or «Collect image
pixels data» writes `hamDistInterpolation` to `.SLDB` without clobbering `userFilter*` or uncommitted
Tab 2 controls.

---

## 5. «Auto-select dupes» selects nothing on a single pair, and leaves `markedSelectFile=0` when re-run over an existing selection

`BTNautoselectDupes()` :91300-91303; `autoSelectDupesInGroups()` :89425-89580; `getSelectedFiles()`
:39929-39973; `dropFilesSelection()` :40016-40025

1. **One duplicate pair: the file is selected and immediately deselected.** At the end of
   `autoSelectDupesInGroups()`, line :89575 calls `getSelectedFiles(0, 1)` to recount the selection.
   With one duplicate pair (two images), `autoSelectDupesInGroups()` selects one image — and
   `getSelectedFiles()`'s one-file rule (:39963-39966) immediately unmarks it and resets
   `markedSelectFile := 0`. Run:
   - **1 pair** (`a_small.png` and `a_big.png`, E1a): «Auto-select dupes» → «Select files» finishes with
     `marked=0` and neither file selected.
   - **2 pairs** (control, E1c): the same click selects both smaller images (`marked=2`: `b_small.png`
     and `a_small.png`).

2. **Re-running «Auto-select dupes» while files are already selected leaves `markedSelectFile=0` while
   rows remain marked selected.**
   `getSelectedFiles()` caches its last key in `lastIDcount` (:39942-39948):
   ```ahk
   thisIDcount := "z" CurrentSLD DynamicFoldersList SLDtypeLoaded filesFilter maxFilesIndex bckpMaxFilesIndex markedSelectFile lastZeitFileSelect
   If (lastIDcount=thisIDcount)
      Return markedSelectFile
   ```
   When `autoSelectDupesInGroups()` starts while files are already selected (`markedSelectFile > 0`),
   line :89426 calls `dropFilesSelection(1)`, which clears `markedSelectFile := 0` (:40020) and calls
   `updateFilesSelectionInfos()` (:40024 → :85043) → `getSelectedFiles(0, 1)`. That sets `lastIDcount`
   with `markedSelectFile=0` and the current `lastZeitFileSelect` (the `A_TickCount` value from
   marking). Then `autoSelectDupesInGroups()` finishes marking the new duplicates in under a millisecond
   — inside the same 15.6 ms `A_TickCount` tick — and sets `lastZeitFileSelect := A_TickCount` (:89574)
   before calling `getSelectedFiles(0, 1)` (:89575). Because `markedSelectFile` is still `0` and
   `A_TickCount` has not advanced yet, `thisIDcount = lastIDcount` and `getSelectedFiles()` returns `0`
   without scanning the list. Run (H2): after running «Auto-select dupes» repeatedly on 2 pairs, two
   rows (`dirb\b2.png` and `dirb\g1_inv.png`) are marked selected (`*`) while `markedSelectFile=0`.
   Every action that checks `markedSelectFile` (Delete, Move, Copy, Purge selected) then sees zero
   selected files (read).

---

## 6. Presets 2 to 6 never collect missing data and report «Found no image duplicates» on a fresh database

`BTNfindDupesNow()` :91483-91498; `retrieveDupesByProperties()` :89007-89036

`retrieveDupesByProperties()` only calls `collectSQLFileInfosNow()` when a hash is active:
```ahk
If (InStr(thisNOTnullCol, "hash") || mustForceHashes>1 || userFindDupesFilterHamDist>1)
   rr := collectSQLFileInfosNow(...)
```
(:89025-89030). For Presets 2 to 6 (and Custom mode with hash set to «Ignore»), it neither collects
missing file/image/histogram data nor offers to do so; it immediately queries `WHERE images.isDeleted=0
AND ifnull(thisNOTnullCol, '')!=''` (:89148).

Even **Preset 5 («Identical file names»)** fails on a fresh database: `BTNfindDupesNow()` sets
`columnus := "imgfile,imgframes"` (:91490), and `imgframes` makes `retrieveDupesByProperties()` pick
`thisNOTnullCol := "imgwidth"` (:89015-89016), which is NULL until image details have been collected —
even though `imgfile` is already populated when the `.SLDB` is saved.

Run (batch B2), on a newly saved 4-file `.SLDB` containing two identical copies `dir1\same.png` and
`dir2\same.png` (no data collected yet):

- **Preset 2** («Image histogram data», B2-preset2): «Found no image duplicates».
- **Preset 3** («Image resolution and file size», B2-preset3): «Found no image duplicates».
- **Preset 4** («Image histogram, resolution and file size», B2-preset4): «Found no image duplicates».
- **Preset 5** («Identical file names», B2-preset5): «Found no image duplicates».
- **Preset 6** («Identical file names and file sizes», B2-preset6): «Found no image duplicates».

In every case the panel reopens with no hint that data has to be collected first (contrast `BTNhelpFindDupes()`,
which says «please ensure you allow Quick Picto Viewer to scan the image files», small thing 16.11).

**Fixed in `6df9c63`** (lines at `2227f02`):

- `BTNfindDupesNow()` drops `imgframes` from Preset 5 (`columnus := "imgfile"`, :91629-91630) and
  Preset 6 (`columnus := "fsize,imgfile"`, :91631-91632), so Preset 5 needs no file scan at all and
  Preset 6 runs fast file-stat collection (`fsize`) instead of decoding image headers.
- `retrieveDupesByProperties()` (:89011-89025) invokes `collectSQLFileInfosNow(scu, 0, 1, 2, 0, ...)`
  whenever `thisNOTnullCol != "imgfile"` (`HpixelzFsmall`/`pixelzFsmall` when a hash is active,
  otherwise `thisNOTnullCol`: `imgmedian`, `imgwidth`, or `fsize`).

Run under headless Wine at `2227f02` (`testF6`) on a fresh 4-file `.SLDB`: Preset 5 runs with no
`collectSQLFileInfosNow()` call and finds `dir1\same.png` + `dir2\same.png`; Preset 6 and Custom +
`kbfsize` call `collectSQLFileInfosNow("fsize", ...)` without touching `imgwidth` and return the
expected groups; Preset 3 calls `collectSQLFileInfosNow("imgwidth", ...)`, populates all 4 rows, and
finds all 4 duplicates; Presets 2 and 4 invoke `collectSQLFileInfosNow("imgmedian", ...)` on missing
data and match all 4 duplicates once histogram data is present.

---

## 7. Tab 4's string filter and «Exclude the current list of results»: singletons, `|||`, and «Exclude» on an unfiltered list

`PanelFindDupes()` :91103-91104, :91203; `retrieveDupesByProperties()` :89243, :89302-89333

1. **Non-hash modes return singletons as duplicate groups.** In hash modes, `dupesScanBuildFromQuery()`
   and `filterDupeResultsByHdist()` drop any group left with fewer than two surviving images after Tab 4's
   string filter or «Exclude». In non-hash modes (`userFindDupesFilterHamDist=1`),
   `retrieveDupesByProperties()` filters candidate rows one by one into `resultedFilesList`
   (:89302-89328) and never removes groups reduced to a single survivor. Run (D4): Preset 5 («Identical
   file names») on two pairs (`dira\same.png` / `dirb\same.png` and `dira\other.png` / `dirb\other.png`)
   with Tab 4 string filter `dirA` (matching one member of each pair). QPV reports «Found 2 groups of
   duplicate images | Total images: 2» and lists two unrelated singletons (`dira\other.png` g=1,
   `dira\same.png` g=2).

2. **A triple bar (`|||`) matches every candidate row while only collecting/hashing the named terms.**
   `retrieveDupesByProperties()` collapses doubled bars once:
   `thisString := StrReplace(dupesStringFilter, "||", "|")` (:89243). Three bars (`u1|||u2`) become
   `u1||u2` — an empty regex alternative — which matches every row in `coreSearchIndex()`, whereas
   `SQLlikeClauseFromFilter()` drops empty terms and builds
   `WHERE (fullPath LIKE '%u1%' ESCAPE '>' OR fullPath LIKE '%u2%' ESCAPE '>')`. Run (D5b): Preset 1
   with filter `u1|||u2` on a 6-file database (all pre-seeded with pixel blobs) leaks all 6 files
   (`dira\other.png`, `dirb\other.png`, `școală\u1.png`, `școală\u2.png`, `dira\same.png`,
   `dirb\same.png`) instead of just `u1.png` and `u2.png`. A leading or trailing `|` does the same via
   an empty alternative if not trimmed; `Trimmer(dupesStringFilter)` trims spaces, not bars (read).

3. **«Exclude the current list of results» is enabled even when no filter is active.** When `filesFilter`
   is empty, `PanelFindDupes()` clears `excludePreviousDupesFromList := 0` (:91103-91104) but leaves the
   checkbox enabled (:91203). Ticking it excludes every image in the database (`toBeExcludedIndexes`
   marks all rows at :91530-91534), runs the full collection, hashing and query, and then fails with
   «Found no image duplicates after filtering the duplicates list» (run, D6: `exclude checkbox enabled=1`).

**Fixed in `2227f02`** (lines at `2227f02`):

- **Singletons in non-hash modes:** `retrieveDupesByProperties()` counts survivors per group in
  `groupies[grpIDu]` (:89312) and, when hashes are not active, compacts `resultedFilesList` to drop
  groups with fewer than two survivors (:89332-89357) and reports `validGroups` in the completion
  tooltip (:89416-89417).
- **Empty `|` terms:** `retrieveDupesByProperties()` splits `dupesStringFilter` on `|`, strips `>`,
  drops empty terms without trimming spaces (matching `SQLlikeClauseFromFilter()`), and builds
  `givenRegEx` directly (:89232-89250).
- **«Exclude» when unfiltered:** `PanelFindDupes()` renders `excludePreviousDupesFromList` unchecked
  and `Disabled` whenever `StrLen(filesFilter) < 3` (:91237-91239, :91338), and `BTNfindDupesNow()`
  guards `toBeExcludedIndexes` with the same check (:91672-91673, :91679).

Run under headless Wine at `2227f02` (`testF7`): Preset 5 with filter `dirB` (leaving only singletons)
drops them and restores the previous list; Preset 5 with filter `dirA` or with Exclude on a `dirB`
filter drops the singletons and keeps only the surviving `pair.png` pair (`Found 1 groups | Total
images: 2`); Preset 1 with `u1|||u2` and `|u1|>|u2|` matches only `u1.png` + `u2.png`; `|||` with
«Must not» behaves as an empty filter; `Școală` matches `u1.png` + `u2.png`; and with `filesFilter`
empty, «Exclude» is disabled (`enabled=0 checked=0`) and ignored even if forced via `GuiControl`.

---

## 8. «Main panel» within a second of a box raises an AutoHotkey error; «Overview», Escape and «Close panel» silently fail for a second after Help

`PanelFindDupes()` :91091; `PanelChangeHamDistThreshold()` :47154; `PanelCachesOverview()` :36363;
`msgBoxWrapper()` :33598; `CloseWindow()` :99821

Closing any `msgBoxWrapper()` dialog sets `lastLongOperationAbort := A_TickCount` (:33598). For the
next 1000 ms, `CloseWindow()` without `"yes"` refuses to close the open panel (:99821), so
`createSettingsGUI()` (which calls `CloseWindow()`) returns `0` while leaving the previous panel open.

- **Crash from «Change hashes threshold» → «Main panel»** (F): `PanelFindDupes()` never checks
  `createSettingsGUI(49, A_ThisFunc, 1)`'s return value (:91091). Clicking «&Main panel» in panel 62
  within 1000 ms of a message box leaves panel 62 open and adds panel 49's controls onto it until
  `veditF6` collides with panel 62's own `veditF6`, throwing an AutoHotkey runtime error:
  «Error: The same variable cannot be used for more than one control. Specifically: veditF6 +hwndhTemp»
  at `GuiAddEdit()` (:26639), aborting the thread and leaving panel 62 corrupted with half of panel 49's
  controls layered on top. (Statistics' «Find duplicates panel» passes through `BtnCloseWindow()` first
  at :28457, which passes `"yes"`, so it is not affected — read.)
- **Silent refusal inside «Find image duplicates» after Help** (A4): closing any of the three Help
  boxes (`&Help` or either ` ?`) arms the 1000 ms guard. Immediately clicking «&Overview» (`dt=264 ms`),
  pressing Escape (`SettingsGUIAGuiEscape` → `CloseWindow()`), or choosing «Close panel» from the
  panel right-click menu all silently do nothing (`AnyWindowOpen` stays `49`). After 1.1 s, clicking
  «&Overview» opens panel 91 normally.

---

## 9. The «Found N groups» count is wrong on every hash search; a failed second search desyncs selection and breaks Ctrl+F

`retrieveDupesByProperties()` :89242, :89261, :89316, :89353-89392

1. **Wrong group count on every hash search.** `groupies` (:89261, :89316) counts the SQL pre-grouping
   buckets (e.g., distinct aspect ratios) **before** `filterDupeResultsByHdist()` runs the Hamming sweep
   and splits them into actual duplicate groups. Line :89392 then shows `groupies.Count()` as the number
   of duplicate groups. Run:
   - Two distinct duplicate pairs sharing the same 1:1 aspect ratio (B3a: `b1`/`b2` in `1_0` and
     `a1`/`a2` in `5_0`): tooltip reads «Found 1 groups of duplicate images | Total images: 4».
   - Three distinct duplicate pairs sharing 1:1 (D3: `other`, `u1`/`u2`, `same` in `1_0`, `3_0`, `5_0`):
     tooltip reads «Found 1 groups of duplicate images | Total images: 6».

2. **A failed second search desyncs the selection count and wipes the DLL pairs cache on the restored
   duplicates list.** When a user is viewing a Hamming duplicates list, selects two files, opens
   «Find image duplicates» and runs a second search that returns 0 duplicates (or is aborted),
   `renewCurrentFilesList()` resets `markedSelectFile := 0` (:65245) and `dupesClearPairs()` wipes
   `qpvmain.dll`'s pairs cache (:89354) before :89369-89376 restores `resultedFilesList` from
   `backupArray`. Run (D7):
   - Before Search #2: `maxFilesIndex=6`, `marked=2`, `pairs=3`, two rows marked `*`.
   - After Search #2 (filter `nomatch_zzz_999` → «Found no image duplicates after filtering the
     duplicates list»): the restored list still has 2 rows marked `*` (`selRows=2`), yet
     `markedSelectFile=0` and `pairs=0`.
   - Pressing Ctrl+F (`PanelChangeHamDistThreshold()`) on the restored duplicates list now fails with
     «WARNING: The files list does not seem to have cached data to allow changing the similarity
     threshold» and bounces back to `PanelFindDupes()`.
   - Read, not run: lines :89356-89357 also overwrite `userFilterInvertThis := userFilterDoString := 0`
     and `userFilterProperty := 1` before the failure return at :89386, losing the previous filter
     panel flags even when the search fails.

---

## 10. The non-SLDB dialog defaults to «Remove duplicate entries», and «Yes» opens «Save indexed files list» on `.SLD`

`PanelFindDupes()` :91072-91080; `PanelSaveSlideShowu()` :44418

```ahk
msgResult := msgBoxWrapper(appTitle ": Confirmation", "The files list is currently not saved as an SQLite database. ... Would you like to save it in the specified format?", "&Yes|&Remove duplicate entries|&Cancel", 2, "question")
If (msgResult="Yes")
   PanelSaveSlideShowu()
Else If InStr(msgResult, "remove")
   cleanDeadFilesList("noFilesCheck")
```

Run (batch A2), on a 4-file plain folder list (`SLDtypeLoaded=1`):

- **Default button is 2 («Remove duplicate entries»)** (A2a, A2b): `defaultBTN := 2` makes «&Remove
  duplicate entries» — which MsgBox2 itself flags as a «Destructive option» — the default button
  instead of «&Yes» (or «&Cancel»), even though the prompt asks «Would you like to save it in the
  specified format?». Pressing Enter runs `cleanDeadFilesList("noFilesCheck")` instead of saving.
- **Answering «Yes» pre-selects `.SLD`, not `.SLDB`** (A2a): `PanelSaveSlideShowu()` sets
  `userDesiredSlideFMT := (SLDtypeLoaded=3) ? 2 : 1` (:44418). Because the user arrived here precisely
  because `SLDtypeLoaded != 3`, the Save panel opens with `userDesiredSlideFMT=1` («.SLD - Plain-text
  format»), so clicking Save without manually changing the dropdown saves another plain-text `.SLD`
  that still cannot run «Find image duplicates».

---

## 11. After «Find duplicates» runs once, `qpvmain.dll` keeps the `.SLDB` open, breaking «Rebuild» with «Permission denied»

`retrieveDupesByProperties()` :89100, :89137, :89183, :89215, :89223; `BTNrebuildDBpanel()`
:44464-44496

`retrieveDupesByProperties()` opens a read-only SQLite connection inside `qpvmain.dll` via
`dupesEngineInit(activeSQLdb._Path)` (:89100) and only calls `dupesEngineRelease()` on error or
zero-row returns (:89137, :89183, :89215, :89223). On a successful search, the DLL keeps its handle on
the `.SLDB` file open until another `dupesEngineInit()` runs or QPV exits.

Run (G1): after running Preset 1 once on `<work>\list.sldb`, removing the duplicates filter and running
`BTNrebuildDBpanel()` (or overwriting the open `.SLDB` from «Save indexed files list»):

- `BTNrebuildDBpanel()` closes AHK's `activeSQLdb`, sets `SLDtypeLoaded := 2`, asks to overwrite
  `list.sldb`, and fails with «Unable to write or access the file: list.sldb. Permission denied.».
- It then opens `PanelSaveSlideShowu()` with `SLDtypeLoaded=2` (no longer a database list), leaving the
  database closed and broken until QPV restarts or `dupesEngineRelease` is called.

---

## 12. Aborting data collection or hash generation mid-run does not stop «Find duplicates»

`retrieveDupesByProperties()` :89030-89042; `collectSQLFileInfosNow()` :36782-36796;
`reportCollectSQLoutcome()` :36890-36910

```ahk
rr := collectSQLFileInfosNow(scu, 0, 1, 2, 0, dupesStringFilter, userFilterStringIsNot, userFilterStringPos, userFilterWhat)
If (rr=-3)
{
   RemoveTooltip()
   Return
}
```
(:89030-89035). Only choosing «Abort» at the pre-scan confirmation prompt returns `-3`. Aborting
mid-run (Escape / Cancel) returns `1` (`reportCollectSQLoutcome()` :36909), and a worker-pool failure
returns `-1` (:36789). Neither stops `retrieveDupesByProperties()`, which proceeds straight into
`generateSQLimageFingerPrintHash()` and the duplicate search on incomplete data.

Run (E6), with `determineTerminateOperation()` patched to abort during collection on a 4-file database
with missing pixels:

- `collectSQLFileInfosNow()` logs «Operation aborted. 4 / 4 ( 100.0% ) | Failed to collect data for 4
  files».
- `retrieveDupesByProperties()` does not return: it immediately runs `generateSQLimageFingerPrintHash()`
  («Preparing to generate image dHash hashes, please wait»), runs the candidate query, reports «Found no
  image duplicates», and reopens the panel.

Read, not run: lines :89040-89042 ignore the return value of `generateSQLimageFingerPrintHash()`
altogether, so aborting regular hash generation still launches flipped hash generation and the
duplicate search.

---

## 13. Panel rebuilds lose unsaved settings, jump to Tab 1 from Statistics, and drop «Back» inside «Overview»

`PanelFindDupes()` :91109-91110; `BtnCollectDupesData()` :91221-91238; `PanelCachesOverview()`
:36362, :36382-36383; `OpenFileDupesPanel()` :28455-28459; `ToggleDarkModus()` :74214;
`ToggleLargeUIfonts()` :74161

1. **Unsaved control values are dropped on rebuild.**
   - `BtnCollectDupesData()` reads only ten controls (:91222-91231) and ignores the preset, all 19
     property checkboxes, hash type, crops, threshold, `BreakDupesGroups`, `PerformMSDonDupes`, MSD
     threshold, and `excludePreviousDupesFromList`. Run (B3b): ticking `BreakDupesGroups` and
     `UIcheckimgwidth` and clicking «Collect image pixels data» reopens the panel with
     `BreakDupesGroups=0` and `UIcheckimgwidth=0`.
   - Clicking «Overview» → «Back», or toggling «Dark mode UI» / «Large UI fonts» from the panel
     right-click menu, saves none of the controls whose handlers do not live-write globals (all 19
     checkboxes, `findFlippedDupes`, `findInvertedDupes`, `BreakDupesGroups`, `dupesApplyBlur`,
     `userpHashMode`, `dupesStringFilter`, `userFilterStringIsNot`, `excludePreviousDupesFromList`,
     `UIfindDupePrecision`) (read; theme/font rebuilds run in E5b).

2. **Opening from Statistics jumps back to Tab 1 after «Overview» → «Back».**
   `OpenFileDupesPanel()` calls `PanelFindDupes(3)` (:28458), which sets local `thisPanelTab := 3`
   (:91109-91110) without updating `TabsPerWindow[49]`. Run (A3): opening from Statistics shows Tab 3
   (`TabsPerWindow[49]=<>`); clicking «Overview» and then «&Back» reopens `PanelFindDupes()` on Tab 1.
   Toggling Dark mode or Large UI fonts does the same (read).

3. **Inside «Overview», toggling «Dark mode UI» or «Large UI fonts» drops the «&Back» button.**
   `PanelCachesOverview()` reads `hostPanel := getHostPanelFunc()` (:36362) before `createSettingsGUI()`
   closes the caller. When Dark mode or Large UI fonts toggles while panel 91 is open, `ToggleDarkModus()`
   / `ToggleLargeUIfonts()` calls `BtnCloseWindow()` first and then `openPreviousPanel("forced")`, so
   `getHostPanelFunc()` sees no host panel (`""`) and omits «&Back». Run (C2b): «Overview» opened from
   `PanelFindDupes()` has `hasBack=1`; toggling Dark mode rebuilds panel 91 with `hasBack=0`.

---

## 14. Numeric threshold edits disallow `0`, and out-of-range typed numbers stay on screen while the old value is read

`PanelFindDupes()` :91167-91168, :91174-91175, :91187-91188; `BtnHelpDupesHashes()` :91556

The three UpDown controls on Tabs 2 and 3 use `Range1-15` (`userFindDupesHamDistLvl`), `Range1-400`
(`userFindDupesMSElvl`) and `Range1-9` (`graylevelCompressor`), while their buddy Edits are `editF7`,
`editFr` and `editFc`.

- **`0` is disallowed for both Hamming and MSD thresholds**, even though the panel's own « ?» Help says
  «Zero means identical hashes» (:91556), `dupesScanStep()` supports `0` (`diff < threshold + 1`), and
  Ctrl+F (`PanelChangeHamDistThreshold()`) allows `0` (`Range0-...`).
- **Typed out-of-range values are silently ignored.** `BTNfindDupesNow()` and `updateUIdupesPanel()`
  read the UpDown variable, not the buddy Edit. Because the UpDown rejects numbers outside its `Range`
  without rewriting the Edit text, whatever the user typed stays visibly on screen while the old value
  runs. Run (batch E3):
  - Typing `0` into `editF7` and `editFr` (E3a): the Edits display `0` and `0`, while the UpDowns read
    `1` and `50`.
  - Typing `99`, `999` and `99` into `editF7`, `editFr` and `editFc` (E3b): the Edits display `99`,
    `999` and `99`, while the UpDowns read `1`, `50` and `1`. (`editFc` also has `limit2` for a
    `Range1-9` control, inviting two-digit input.)

---

## 15. «Size (kilobytes)» goes stale when «Size (bytes)» is checked; Tab 2's preview overlaps a checkbox in Large UI fonts

`BTNfindDupesNow()` :91426-91433; `PanelFindDupes()` :91163-91170

1. **«Size (kilobytes)» is never read when «Size (bytes)» is ticked.**
   ```ahk
   If GuiCtrlGet("UIcheckfsize")
   {
      columnus .= "fsize,"
   } Else
   {
      If GuiCtrlGet("UIcheckkbfsize")
         columnus .= "kbfsize,"
   }
   ```
   (:91426-91433). `GuiCtrlGet()` is what syncs each checkbox's state back into its global `UIcheck*`
   variable. Placing `GuiCtrlGet("UIcheckkbfsize")` inside the `Else` branch means that whenever «Size
   (bytes)» is checked — including after clicking «&Select all» — `UIcheckkbfsize` is not updated. Run
   (E2): in Custom mode, clicking «&Select all» (all 19 checked, including `fsize=1` and `kbfsize=1`)
   and clicking «&Find duplicates» reopens the panel with 18 checkboxes ticked and «Size (kilobytes)»
   reverted to `0`.

2. **Large UI fonts overlap on Tab 2.** Under `PrefsLargeFonts=1`, the 90×90 «Image hashing preview»
   (`370,169`–`460,259`) overlaps «Identify images horizontally flipped» (`34,250`–`411,273`) by
   41×9 pixels. Run (E5b, H3): confirmed in both layouts (with and without Tab 4's `+` button); normal
   UI fonts have zero overlaps across all four tabs.

---

## 16. Small things

- **16.1. Wrong message on `< 3` files, and menu mismatch on 3 files.** Opening `PanelFindDupes()` with
  fewer than 3 files and no active filter prints «WARNING: Insufficient indexed files to activate the
  list view mode» (:91069-91070, run A1a) — a copy-pasted message from list view. Meanwhile the Find
  menu bar disables «Find duplicate images» when `maxFilesIndex < 4` (:68982), even on a 3-file `.SLDB`
  where `PanelFindDupes()` opens cleanly (run A1c) and even while a filter has narrowed a larger
  database to 2 or 3 files; the files list context menu (`PVfList`) leaves it enabled in all of those
  cases (run A1a–A1c).
- **16.2. Ctrl+F («Change hashes threshold») refuses a 1-pair duplicates list.**
  `PanelChangeHamDistThreshold()` checks `dupesPairCount() < 2` (:47090) instead of `< 1`. On a
  duplicates list with exactly one matched pair (`pairs=1`), pressing Ctrl+F answers «WARNING: The files
  list does not seem to have cached data to allow changing the similarity threshold» and bounces back to
  `PanelFindDupes()` (run G6).
- **16.3. Dead `gupdateUIFiltersPanel` on Tab 4's two dropdowns.** Lines :91200-91201 bind
  `gupdateUIFiltersPanel` to `userFilterStringPos` and `userFilterWhat`; `updateUIFiltersPanel()`
  immediately returns whenever `AnyWindowOpen != 6` (:33262) (read). *(Fixed in `ecddb73`.)*
- **16.4. `PanelFindDupes(dummy)` rejects Tab 4.** Line :91109 checks `isInRange(dummy, 1, 3)` even
  though the panel has 4 tabs (read).
- **16.5. 300 ms enable/disable race on open.** `PanelFindDupes()` delays `updateUIdupesPanel` via
  `SetTimer, updateUIdupesPanel, -300` (:91214). On Preset 1, Tab 1's 19 property checkboxes are enabled
  for the first 300 ms and only grey out afterwards (run E5: at 0 ms `UIcheckimgfile=1`, at 450 ms
  `UIcheckimgfile=0`).
- **16.6. Blank hash preview on Preset 1, and duplicate fill.** `updateUIimageHashPreview()` skips
  drawing all 64 dots whenever `userFindDupePresets != 7` (:91271), so Preset 1 shows an empty box even
  though it uses `dHash 8x8` with 1/1 crop. Line :91267 also repeats `Gdip_FillRectangle(G, pBrushA, 0,
  0, imgW, imgH)` identically after :91266 (read).
- **16.7. «Collect image pixels data» is silent for 0, 1 or 2 remaining files.**
  `reportCollectSQLoutcome()` only shows its completion message when `filesToBeSorted > 2` (:36912).
  Clicking «Collect image pixels data» when everything is already collected (or 1–2 files remain) closes
  and reopens the panel with no confirmation that nothing needed work (run H4, 0 remaining).
- **16.8. Inside «Overview» (`PanelCachesOverview()`):**
  - The «&Ignored entries» menu starts with a blank separator line (`Menu, ContextMenu, Add,` at :36395;
    run C2a: `4 items: [] [&Purge ignored entries] ...`).
  - The 1×1 host-panel carrier `EditF5` (:36386) is visible and has `WS_TABSTOP=1` (`-wantTab` controls
    inserting Tab characters, not keyboard tab order — `-TabStop +Hidden` was meant) (run C2a).
  - «List ignored entries in the viewport» (`BTNlistDeadEntries()` :36402 → `BtnIndexStatsToList(0, 0,
    "isDeleted", 0)` :28662-28665) displays «Gathering entries matching 0, please wait» and «Generating
    files list index for: | 0», and leaves bogus filter globals (`userFilterProperty=3`,
    `FilteruDateMinRange=2`, `FilteruDateMaxRange=1`) (run C2c).
  - «&Ignored entries» starts enabled while the background timer is still scanning, before row 1's
    ignored-file count arrives (read).
- **16.9. Inside «Auto-select dupes» (`PanelAutoSelectDupes()`):**
  - The history ComboBox always appends a trailing blank item (`SearchdStringz "`f`f"`, :47608-47610;
    run E1b, H2) and hides any search string that is a suffix of an earlier entry
    (`!InStr(SearchdStringz, thisString "`f")` at :47617; run H2: searching `folderA`, then `derA`,
    drops `derA` from the list — the same check as Finding 12 of `files-filter-panel-audit-2026-11-20.md`).
  - A malformed RegEx (e.g. `\>` followed by `(`) is not validated; `RegExMatch()` silently fails to
    match anything without warning the user (run H2).
- **16.10. Inside «Purge cached data» (`PanelPurgeCachedSQLdata()` and helpers):**
  - `selectivePurgeCachedSQLdata(dbIndex, batchMode:=0)` (:91862) only returns `"fail"` when
    `batchMode=1`; Options 6 (:91818) and 7 (:91737) call it without the second argument, so
    `If r failedFiles++` never counts SQL failures (read).
  - Option 7's progress tooltip prints `Files data available for: <totalImages> ( Round(totalFiles/totalImages, 1)% )`
    (:91765): it is missing `* 100` and displays `totalImages` where `totalFiles` belongs (read). Option 7
    also never called `uiPopulateCachesOverview("kill")` (fixed in `d94e991`, :91807).
  - Option 6's completion message reports `markedSelectFile` instead of `countFiles` (:91844, read).
  - Option 8 («File entries marked as dead or ignored») calls `SQLdeleteEntriesMarked()` with default
    `markValue=1` (:91610), skipping `isDeleted=2` rows (unreadable/corrupt files), whereas «Overview»'s
    «Purge ignored entries» passes `"ANY"` (:36625, read).
  - `corePurgeCachedSQLdata()` resets `UPDATE images SET isDeleted=0 WHERE isDeleted=1;` database-wide
    (:91685), ignoring `extraFilter` (read).
- **16.11. Help and error text mismatches.** `BTNhelpFindDupes()` (:91560) says «set «Matching» to
  «Close» and the dHash threshold to 3 in the image hashes tab»: the control reads «Matching precision:»,
  those controls are disabled unless the user first switches from Preset 1 to «Custom mode», and the
  line «please ensure you allow Quick Picto Viewer to scan the image files» implies QPV prompts to scan
  for all modes (false for Presets 2–6, Finding 6). The DLL failure box in `BTNfindDupesNow()` (:91524)
  has a sentence fragment («Searching for duplicates by fingerprint (Hamming distance).») and tells the
  user to set the fingerprint type to «Ignore» (which is disabled on Preset 1) (read).
- **16.12. 32-bit guard does not disable hashing.** On 32-bit AutoHotkey (`A_PtrSize != 8`, :91106),
  `PanelFindDupes()` resets `userFindDupesFilterHamDist := 1` on open, but does not disable the hash
  dropdown and does not stop Preset 1 from forcing `userFindDupesFilterHamDist := 2` in
  `BTNfindDupesNow()` (read).
- **16.13. `bckpCurrentFileIndex` is never saved before applying a duplicates filter.**
  `retrieveDupesByProperties()` never writes `bckpCurrentFileIndex := currentFileIndex` (unlike
  `coreSetFilesFilteru()` :33692), so removing the duplicates filter later jumps to a stale index from
  an earlier filter or to `1` (:4226, :33733) (read).
- **16.14. `editFc` on Tab 3 has no label or tooltip.** `GuiAddEdit()` at :91187 omits the third
  argument (unlike `editF5`, `editF6`, `editF7`, `editFr`), so `editFc` gets no cue banner or tooltip
  (read).
- **16.15. Unused variables and dead branches.** `editFd`, `txtline2` and `editFE` are declared global in
  `PanelFindDupes()` (:91058, :91065) and never used; `PanelPurgeCachedSQLdata()` has an unreachable
  `Else PopulateIndexFilesStatsInfos("kill")` (:91617-91618) and an always-true `SLDtypeLoaded=3` check
  (:91581) after :91576 already returned for `SLDtypeLoaded != 3`; `uiCachesOverviewSizeEstimate()`
  computes `perImage` (:36570) and never uses it (read).
- **16.16. Right-clicking empty space inside a tab page does not open the panel menu.** Inside the Tab3
  client area, `CtrlHwnd` is the `SysTabControl32` control, `SettingsToolTips()` filters it out, and
  `SettingsGUIAGuiContextMenu()` returns at :26033 (`If (CtrlHwnd && IsRightClick=1)`). Only
  right-clicking the outer margin around the tab strip opens the panel right-click menu (run G4; read).

---

## Seen in passing

- **A. `collectSQLFileInfosNow()` honours the «never ask again» checkbox even on «Collect data now».**
  Lines :36746-36747 set `noQuestion := msgResult.Check` unconditionally before checking which button
  was clicked. Ticking «Do not collect file data and never ask again in this session» and then clicking
  «Collect data now» still sets `noQuestion := 1`, causing every subsequent `asku=1` call (:36651) —
  including future «Find duplicates» searches — to skip data collection silently for the rest of the
  session (read).
- **B. `PanelChangeHamDistThreshold()` (Ctrl+F on a duplicates list) shares three issues with this
  panel.** Its two Tab-4-style dropdowns bind the same dead `gupdateUIFiltersPanel` (:47138-47139);
  opening the panel unconditionally resets `UserHamDistCacheFilterMonoGroups := 1` (:47115), discarding
  the user's choice; and `BtnChangeHamDistThreshold()` (:47159) never calls `askAboutFileSave()` before
  replacing the list (read).
- **C. `PanelFindDupes()` does not call `doOpenStartFolder()`.** Unlike `PanelWrapperFilesStats()` and
  `PanelEnableFilesFilter()`, opening `PanelFindDupes()` while `mustOpenStartFolder` is set does not
  open the startup folder first (read).
- **D. `uiPopulateCachesOverview()` treats an empty database (`totalz=0`) as still scanning forever.**
  Clicking the footer line calls `uiPopulateCachesOverview("estimate")`, which checks
  `If (busyu=1 || !totalz)` (:36418) and permanently answers that database information is still being
  gathered when the database has zero rows (read).
- **E. Keyboard menu key 250 ms gate.** `SettingsGUIAGuiContextMenu()` (:26033) gates `IsRightClick=0`
  behind a 250 ms double-press check (noted in `move-copy-files-panel-audit-2026-11-20.md`, Seen in
  passing D), though `externalinvokedSettingsContextMenu()` (:25961) handles the `AppsKey` hotkey
  directly (read).

---

## Checked and found correct

- **Uppercase non-ASCII characters in Tab 4's string filter** (D5a, D5a2): filtering a database list for
  `Școală` matches lower-cased `școală\u1.png` and `școală\u2.png` cleanly. AutoHotkey 1.1.37.02's PCRE
  `i)` flag folds `Ș` to `ș`, and `SQLlikeClauseFromFilter()` lower-cases the term for SQLite `LIKE`
  (run).
- **Shared `Alt+X` across Tab 3 and Tab 4** (E4a–E4c): Tab 3's «Collect image pi&xels data» and Tab 4's
  «E&xclude the current list of results» both use `&x`, but because Tab3 places each tab's controls on
  separate pages, pressing `Alt+X` on Tab 4 toggles «Exclude» (from both «Find duplicates» and «Must
  not») and pressing `Alt+X` on Tab 3 runs «Collect image pixels data» under Wine (run; Windows was not
  checked). All other accelerators (`S`, `G`, `O`, `M`, `F`, `A`, `H`, `C`) are unique (read).
- **Custom mode with zero checkboxes**: with hash set to «Ignore», `BTNfindDupesNow()` refuses cleanly
  («WARNING: Insufficient properties selected by which to identify duplicates.») and keeps the panel
  open (:91517-91518, read). With a hash selected, it falls back to `imgwhratio,imgframes` (:91503-91505,
  run H1a).
- **`GuiCtrlGet()` persistence**: 18 of the 19 `UIcheck*` checkboxes persist properly across reopens
  after «Find duplicates» (only `UIcheckkbfsize` fails, Finding 15) (run E2).
- **Hash preview bit-order mapping**: `updateUIimageHashPreview()`'s mapping (:91287-91288) matches
  `buildHamMask()` in `QPV DLL source code/lib/dupes-search.h` (:200-205) for both `pHash` and
  `dHash`/`lHash` (read).
- **Normal-font layout**: all four tabs (both with and without Tab 4's `+` button) have zero overlapping
  controls and stay inside the tab frame (run E5b, H3).
- **Buttons using `BtnCloseWindow()`**: «Cancel», «Find duplicates», «Auto-select dupes», «Collect image
  pixels data» and «Purge cached data» all pass `"yes"` to `CloseWindow()`, so the 1-second post-dialog
  guard of Finding 8 does not block them (read).
- **«Remove duplicate entries» on an edited image** (A2b, G5): `cleanDeadFilesList("noFilesCheck")`
  preserves the edited bitmap and undo levels when `currentFileIndex` stays on the same file (run).

---

## Decisions to make before fixing

1. Finding 1: ~~ask `askAboutFileSave()` in `BTNfindDupesNow()` before `BtnCloseWindow()`~~ (fixed in
   `60f52cc`); also ask in `ActSortDupeGroups()` (or inside `retrieveDupesByProperties()` before
   `renewCurrentFilesList()`)?
2. Finding 2: ~~(a) restore `CurrentSLD` in `PurgeCachedDataModifiedFiles()`~~ (fixed in `60f52cc`);
   ~~(b) honour the active filter and mark missing files `isDeleted=1`~~ (fixed in `d94e991`); (c) should
   «All (selected files only)» allow one selected file? ~~(d) reopen the invoking panel — also after
   «No»~~ (fixed in `d94e991`).
3. Finding 3: (a) should «Collect image pixels data» respect the current `findFlippedDupes` checkbox
   (or ask/collect flipped pixels without flipping the user's checkbox)? (b) should Preset 1 use fixed
   defaults (`thr`, `flip=0`, `inv=0`, `brk=0`, `msd=0`) instead of inheriting disabled Tab 2 values,
   and pass hash/crop as local parameters like `findDupesPrecision` so Presets 1–6 do not overwrite
   Custom mode's settings? (c) should `dHash 8x8` in Custom mode force `inv=0` when passing to the
   engine?
4. Finding 4: ~~snapshot and restore `PanelFindDupes()`'s settings on «Cancel» (like
   `InitialFilterSettingsPanel()`), give Tab 4 its own `dupesFilterWhat` / `dupesFilterStringPos` /
   `dupesFilterStringIsNot` instead of sharing `PanelEnableFilesFilter()`'s globals, read into locals
   in live handlers, and defer `IniSLDBWrite("hamDistInterpolation")` until «Find duplicates» or
   «Collect image pixels data» runs~~ (fixed in `ecddb73`).
5. Finding 5: (a) should `autoSelectDupesInGroups()` bypass the one-file rule (e.g., count selected rows
   directly or add a flag to `getSelectedFiles()`), so a single duplicate pair keeps its 1 selected
   image? (b) invalidate `getSelectedFiles()`'s `lastIDcount` cache in `autoSelectDupesInGroups()` (or
   key it by a monotonic selection counter instead of `A_TickCount`)?
6. Finding 6: ~~trigger `collectSQLFileInfosNow()` for Presets 2 to 6 and Custom + «Ignore» whenever
   `thisNOTnullCol != "imgfile"`, and drop `imgframes` from Preset 5 («Identical file names») and
   Preset 6 («Identical file names and file sizes»)~~ (fixed in `6df9c63`).
7. Finding 7: ~~(a) in non-hash modes, drop singleton groups left after Tab 4's string filter or
   «Exclude»; (b) split/clean empty `|` terms consistently with `SQLlikeClauseFromFilter()` without
   trimming spaces; (c) disable «Exclude the current list of results» when `filesFilter` is empty~~
   (fixed in `2227f02`).
8. Finding 8: check `createSettingsGUI()`'s return value in `PanelFindDupes()` (and have
   `PanelChangeHamDistThreshold()`'s «Main panel» and `PanelFindDupes()`'s «Overview» close via
   `BtnCloseWindow()`, or should Help boxes not arm `lastLongOperationAbort`)?
9. Finding 9: (a) count the actual post-sweep groups in `filterDupeResultsByHdist()` for the «Found N
   groups» tooltip? (b) on a failed/aborted second search, preserve `markedSelectFile` and the DLL pairs
   cache (or keep the existing pairs until the new sweep succeeds) and avoid clobbering the filter panel
   globals before the failure check?
10. Finding 10: change the non-SLDB dialog's default button from 2 («Remove duplicate entries») to 1
    («Yes») or 3 («Cancel»), and have `PanelSaveSlideShowu()` pre-select `.SLDB` when invoked from
    `PanelFindDupes()`?
11. Finding 11: call `dupesEngineRelease()` in `retrieveDupesByProperties()` once the query/sweep
    finishes (the pairs cache lives in memory, not on the SQLite handle), or release it inside
    `BTNrebuildDBpanel()` / database-close paths as well?
12. Finding 12: return early in `retrieveDupesByProperties()` when `collectSQLFileInfosNow()` is aborted
    or fails (not only `-3`), and check `generateSQLimageFingerPrintHash()`'s return value too?
13. Finding 13: (a) read all panel controls before rebuilding on «Collect image pixels data», «Overview»,
    Dark mode and Large UI fonts? (b) write `TabsPerWindow[49] := dummy` when `PanelFindDupes(dummy)` is
    given a tab? (c) keep `hostPanel` across theme/font rebuilds of «Overview» so «Back» does not
    disappear?
14. Finding 14: allow `0` in `editF7` and `editFr` (`Range0-15`, `Range0-400`), and read/clamp the Edit
    text on submit (or clamp on change) instead of silently taking the stale UpDown value?
15. Finding 15: (a) read `GuiCtrlGet("UIcheckkbfsize")` unconditionally (outside the `Else` of
    `UIcheckfsize`) so it persists cleanly? (b) move Tab 2's «Image hashing preview» or widen/push the
    row below it under `PrefsLargeFonts=1` so it no longer overlaps «Identify images horizontally
    flipped»?

---

## How this was checked

- **Static reading** of `development` at `35329bc`: `PanelFindDupes()`, all its tab controls and button
  handlers, the routes that open it (Find menu :68980, files list menu :72736, toolbar :105902,
  Statistics :28455, Auto-select :47621, Change threshold :47154, F8), the duplicate search engine
  (`retrieveDupesByProperties()`, `filterDupeResultsByHdist()`, `changeHdistLevelCached()`,
  `dupes-search.h`, `dupes-pixels.h`), `autoSelectDupesInGroups()`, `PanelPurgeCachedSQLdata()` and its
  purge helpers, `PanelCachesOverview()` and its helpers, `collectSQLFileInfosNow()`, and
  `ActSortDupeGroups()`.
- **The real application under headless Wine**, on the stock AutoHotkey 1.1.37.02, started on one image,
  with test functions appended to a scratch copy of the script. Each test builds a small folder of real
  PNGs, opens it in QPV (and saves/reopens it as `<work>\list.sldb`), opens `PanelFindDupes()` or one of
  its sub-panels, drives its controls and buttons, and records every message box, tooltip, list state,
  selection count, database row count and control geometry.
- **The scratch copy differs from the source** in that message boxes, tooltips, `showDelayedTooltip()`,
  and calls to `retrieveDupesByProperties()`, `collectSQLFileInfosNow()`,
  `generateSQLimageFingerPrintHash()`, `PanelPurgeCachedSQLdata()`, `corePurgeCachedSQLdata()`,
  `PurgeCachedDataModifiedFiles()`, `PurgeCachedDataSelectedFiles()`, `PanelCachesOverview()`,
  `PanelAutoSelectDupes()`, `autoSelectDupesInGroups()`, `PanelChangeHamDistThreshold()`,
  `PanelWrapperFilesStats()`, `PanelSaveSlideShowu()`, `cleanDeadFilesList()`, `askAboutFileSave()`,
  `terminateIMGediting()`, and `SettingsToolTips()` are logged.
- **Aids**, each named where it was used:
  - **Precomputed grayscale pixel blobs (`blobs.ini`)**: Wine's built-in `gdiplus.dll` does not
    implement GDI+ 1.1's `GdipBitmapApplyEffect` (`ColorMatrix`), so `collectImgDataViaPool()` fails
    with `DP_ERR_PROCESS` on real files under Wine. To test the real hashing and duplicate matching
    pipeline on real pixel data, tests that needed collected details seeded the `images` metadata and
    `imagesPixels` 9×8 and 32×32 grayscale blobs (computed from the exact test PNGs) directly into
    `activeSQLdb`, leaving all six hash columns `NULL` so `qpvmain.dll`'s real `dupesHashBegin/Step`,
    `dupesQueryBegin/Step`, `dupesScanBuildFromQuery`, `dupesScanStep` (Hamming + MSD) and
    `dupesApplyFilter` ran unmodified.
  - an edited image simulated by its state (Finding 1; Checked: `cleanDeadFilesList`);
  - `determineTerminateOperation()` patched to abort on demand (Finding 12, batch E6);
  - `Alt+X` posted as `WM_SYSKEYDOWN`/`WM_SYSCHAR` to focused controls (Checked, batch E4);
  - a second process (`closer2.ahk`) that captures and dismisses AutoHotkey's runtime error box
    (Finding 8, batch F).
- **Batches**:
  - **A** (`a2-head.txt`): opening preconditions, menus, non-SLDB dialog, Statistics → Tab 3 → Overview
    → Back, 1-second post-Help guard;
  - **B** (`b3-head.txt`): edited image (dupes found and 0 dupes), fresh-DB Presets 2–6, Preset 1
    inheriting disabled Tab 2 controls, «Collect image pixels data» forcing `findFlippedDupes`, group
    count tooltip, Preset 1/2 clobbering Custom settings;
  - **C** (`c2-head.txt`): «Purge cached data» (Cancel, No, Yes, 1-selected, Modified wiping
    `CurrentSLD` and ignoring filter), «Overview» (`EditF5`, leading blank menu separator, Dark mode
    dropping «Back», `BTNlistDeadEntries`);
  - **D** (`d2-head.txt`): Tab 4 shared globals clobbered on open, «Cancel» live mutations and `.SLDB`
    write, Ctrl+F range corruption, Preset 5 + Tab 4 singletons, `Școală` vs `școală`, `|||`, «Exclude»
    with no filter, failed 2nd search desyncing selection and wiping DLL pairs cache;
  - **E** (`e3-head.txt`): «Auto-select dupes» on 1 pair vs 2 pairs, ComboBox blank entry,
    `UIcheckkbfsize` stale bug, `editF7`/`editFr`/`editFc` out-of-range vs `0`, `Alt+X` on Tab 3 and
    Tab 4, 300 ms timer race, Normal vs Large UI fonts overlap, mid-run collection abort;
  - **F** (`f3-head.txt`): «Change hashes threshold» → «Main panel» within 1 s throwing the `veditF6`
    AutoHotkey error;
  - **G** (`g3-head.txt`): `BTNrebuildDBpanel()` failing with «Permission denied» after one search,
    «Cancel» corrupting `ActSortDupeGroups()`, right-click inside Tab3, `cleanDeadFilesList` on edited
    image, 1-pair `PanelChangeHamDistThreshold()` refusal;
  - **H** (`h3-head.txt`): strict monotonic gradient + inverse proving disabled `findInvertedDupes=1`
    matches in both Custom + dHash and Preset 1, `PanelAutoSelectDupes` suffix-hiding, invalid RegEx,
    `getSelectedFiles()` 15.6 ms cache collision (`marked=0` with 2 rows marked), Tab 4 `+` layout,
    0-file «Collect image pixels data» silent reopen;
  - **I** (`i1-fix.txt`, at `d94e991`): re-checks Finding 1 (`BTNfindDupesNow()` «Cancel»/«Save»/«Discard»
    and `ActSortDupeGroups()` on an edited image) and Finding 2 (2.1 `CurrentSLD` restored, 2.2 active
    filter + missing files marked `isDeleted=1` + «Overview» refresh, 2.4 reopening `PanelFindDupes(3)`,
    Statistics, or nothing across «Cancel»/«No»/«Yes», and 2.3 unchanged).
- **Not run on Windows**:
  - native Windows GDI+ 1.1 pixel collection inside `collectImgDataViaPool()`;
  - whether Windows' Tab3 dialog manager routes `Alt+X` across Tabs 3 and 4 the same way Wine did;
  - whether Windows differs on right-click hit-testing inside Tab3 (16.16).
- **Not run at all**:
  - 32-bit AutoHotkey (`A_PtrSize != 8`, 16.12);
  - `BreakDupesGroups=1` inherited into Preset 1 (Finding 3, read);
  - aborting `generateSQLimageFingerPrintHash()` mid-run (Finding 12, read);
  - `collectSQLFileInfosNow()`'s «never ask again» checkbox on «Collect data now» (Seen in passing A,
    read).
- **Kit**: `.claude/scratch/find-dupes-panel-2026-11-21/app/`.
  - `run-fd.sh <tag> testFdA|testFdB|testFdC|testFdD|testFdE|testFdF|testFdG|testFdH|testFdI [revision]`
    (stock interpreter; `QPV_SRC=<file>` runs a modified source).
  - Test functions are in `test-fd.ahk`, on top of `test-wrappers-sc.ahk`; `setup.sh` builds the test
    PNGs and `blobs.ini`; `patch.py` and `patch-fd.py` add logging; `closer2.ahk` answers AutoHotkey
    error boxes.
  - Logs are in `results/` (`a2-head.txt`, `b3-head.txt`, `c2-head.txt`, `d2-head.txt`, `e3-head.txt`,
    `f3-head.txt`, `g3-head.txt`, `h3-head.txt`, `i1-fix.txt`).
