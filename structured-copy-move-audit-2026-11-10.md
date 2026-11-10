# Audit of Structured File Operations (`PanelStructuredCopyMoveWindow`)

Scope: `PanelStructuredCopyMoveWindow()` (`quick-picto-viewer.ahk:60736–60794`), `BtnHelpStructuredCopyMove()` (`:60796–60798`), `BTNuiProceedStructuredOperation()` (`:60800–60845`), `copyMoveStructuredFolders()` (`:3208–3404`), `BtnCpyMvStrctrdChooseFilesDst()` (`:59849–59867`), `BtnCpyMvStrctrdChooseFilesSrc()` (`:59869–59887`), `BtnIdentifyFileRoots()` (`:60109–60132`), `menuSetSourceStructuredOper()` (`:60134–60144`), `IdentifyFileFolderRoots()` (`:60146–60242`), all menu/search/reopen entry points (`InvokeMenuBarFile` `:67406–67461`, `createMenuCurrentFilesActs` `:69536–69548`, `buildQuickSearchMenus` `:42746–42788`, `openPreviousPanel` `:27537–27545`), and the shared GUI, keyboard, path, collision, SQLite, and Undo helpers they call (`quick-picto-viewer.ahk`, `lib/shell-stuff.ahk`, `lib/module-interface.ahk`), on branch `development` at `ab160cb`.

Every finding below was verified by static code inspection (`read`) against `ab160cb`. No code was changed.

---

## Terms

- **Structured file operations panel** (`PanelStructuredCopyMoveWindow`, `AnyWindowOpen = 77`): modeless `SettingsGUIA` dialog owned by `PVhwnd` that copies or moves all selected files located under a chosen **Source** root directory into a **Destination** root directory while recreating each file's relative subfolder path (`StrReplace(file2rem, srcDir "\", finalDest "\")`).
- **`UsrEditFileSource`**: global variable bound to the `Source:` `Edit` control (`:60737`, `:60769`), pre-populated on panel open with `OutDir` of `currentFileIndex` (`:60759`).
- **`UsrEditFileDestination`**: super-global variable (`:169`) bound to the `Destination:` `Edit` control (`:60774`); shared with the regular Copy/Move panel (`CopyMovePanelWindow`, `AnyWindowOpen = 9`) and quick-move hotkeys.
- **`userCopyMoveStructuredConflictMode`**: super-global (`:347`, default `4`) bound to the `On file name conflicts:` `DropDownList` (`AltSubmit`, `:60779`): `1` = `Skip files`, `2` = `Auto-rename`, `3` = `Overwrite`, `4` = `Ask user`.
- **`UsrCopyMoveOperation`**: super-global (`:398`) bound to the `Action to perform:` `DropDownList` (`AltSubmit`, `:60781`): `1` = `Choose...`, `2` = `Move file(s)`, `3` = `Copy file(s)`.
- **`Possible source paths` button & `Manna` menu** (`BtnIdentifyFileRoots` `:60109`, `IdentifyFileFolderRoots` `:60146`, `menuSetSourceStructuredOper` `:60134`): triangle-down icon button next to `&Browse` that scans selected files (`resultedFilesList[i, 2] = 1`) and pops up a Win32 menu (`Manna`) of up to 10 candidate root paths plus a disabled `"... and N folders more"` item.
- **`resultedFilesList`**: active 2D gallery array (`1..maxFilesIndex`), where `[i, 1]` is full path (or `path||frame` in multipage preview mode `QPV:PAGES:`), `[i, 2]` is selection flag (`1` = selected), `[i, 5]` is favourite flag, and `[i, 12]` is SQLite `imgidu` when `SLDtypeLoaded = 3` (`.SLDB` database).

---

## Summary

Ordered from highest harm (silent data destruction, unrecoverable overwrite, runtime error, index/database corruption) to lowest (UI polish and minor resource leaks).

| # | Severity | Area | Short description | Verification |
|---|---|---|---|---|
| 1 | **High** | `BTNuiProceedStructuredOperation` / `copyMoveStructuredFolders` | Wrong trim/slash/whitespace order (`:60809–60814`) + raw `dS=fS` string check (`:60840`): silently skips 100% of files on Source, injects `\\` on Destination, or **recycles the source files themselves** under Overwrite | read |
| 2 | **High** | `BTNuiProceedStructuredOperation` / `copyMoveStructuredFolders` | No guard when Destination is inside Source (`C:\a` → `C:\a\sub`) or Source is inside Destination (`C:\a\sub` → `C:\a`): recursive nesting and **intra-batch file destruction** under Overwrite | read |
| 3 | **High** | `copyMoveStructuredFolders` / `recordUndoFileActs` / `batchUndoFileActs` | Move + Overwrite drops `originalFileInfos` (`:95033`), so **batch Undo fails 100% of overwritten-file recoveries** (`:94858`) and single-file Undo skips size matching (`:94642`); Undo Move also fails if source subfolders were removed and `quickBarFileUndo` is never shown | read |
| 4 | **High** | `copyMoveStructuredFolders` / `ResizeImageGDIwin` | Missing `askAboutFileSave()` guard: moving the currently edited image (`currentImgModified = 1`) changes its path and triggers `terminateIMGediting()` 100 ms later (`:75321`), **silently discarding unsaved pixel edits** | read |
| 5 | **High** | `BTNuiProceedStructuredOperation` / Browse / `zPlitPath` | `Trim(..., "\")` and `Trimmer(..., "\")` strip **leading** `\\`, breaking UNC network paths (`\\server\share\...`) everywhere and creating local `%A_ScriptDir%\server\share\...` folders | read |
| 6 | **High** | `BTNuiProceedStructuredOperation` / `copyMoveStructuredFolders` | No absolute-path, illegal-char, or anchored-prefix validation: relative `dS` or polluted `[group-by-...]` creates folders in `%A_ScriptDir%` and writes relative paths into `resultedFilesList`/`.SLDB`; relative `fS` matches mid-path | read |
| 7 | **High** | `IdentifyFileFolderRoots` / `.SLDB` / `copyMoveStructuredFolders` | Non-ASCII Unicode case mismatch (`Format("{:L}", ...)` vs AHK's ASCII-only `StringCaseSense, Off`): silently skips 100% of files on paths like `C:\Școală\...` or bypasses `dS=fS` and triggers **Overwrite self-deletion** | read |
| 8 | **High** | `copyMoveStructuredFolders` / `zPlitPath` | Extensionless files (`Makefile`, `README`) or pre-existing folders matching `file2save` move/copy the file **into** a subdirectory (`...\name\name`) while pointing `resultedFilesList`, `.SLDB`, and Undo at the folder | read |
| 9 | **High** | `PanelStructuredCopyMoveWindow` / `createSettingsGUI` | Unchecked `createSettingsGUI(77, A_ThisFunc)` abort (`""` at `:60742`) causes an **unhandled AHK duplicate-control-variable error** or dumps controls onto GUI `1:` | read |
| 10 | **Medium** | `copyMoveStructuredFolders` / `FileRexists` / `lockDestinationFileName` | Premature `FileRecycle` before `FileMove`/`FileCopy`, 0-byte file blind spot (`FileRexists(..., 0)`), cross-drive `+R` partial move, unreset `performOverwrite`, and missing `lockDestinationFileName(..., 2)` batch lock | read |
| 11 | **Medium** | `IdentifyFileFolderRoots` / `BtnIdentifyFileRoots` | Unconditional parent-stripping (`:60194`) + child-prefix culling (`:60233`): **dead button** on depth-1 (`C:\imgs`) / root (`C:\`) folders, suggests parent of single folder, and **contradicts QPV's own Help example** (`:60797`) | read |
| 12 | **Medium** | `IdentifyFileFolderRoots` | Global shallowest-depth `Break` (`:60220`) hides deeper trees on other drives, ASCII sort (`'-'`, `' '`, `'0'–'9'` < `'\'`) breaks deduplication (`:60233`), unanchored `InStr(nList, p "`n")` (`:60195`), `+1` loop bound (`:60160`), and stale `"cached"` roots if selection changes (`:60113`) | read |
| 13 | **Medium** | Menus / `openPreviousPanel` (`F8`) | Missing `QPV:PAGES:` virtual-frame guard in `pvMenuBarFile` (`:67430`) and panel/engine; `F8` reopens panel with `< 2` selected files or closed gallery; `pvMenuBarFile` omits item when `thumbsDisplaying = 0` (`:67434–67461`) | read |
| 14 | **Medium** | `BTNuiProceedStructuredOperation` / `copyMoveStructuredFolders` | `FileCreateDir` (`:60829`) and `BtnCloseWindow()` (`:60843`) run *before* `filesElected < 2` check (`:3211`) and `> 150`-file confirmation (`:3217`), silently no-oping or destroying panel inputs when user clicks `"No"` | read |
| 15 | **Medium** | `.SLDB` SQLite / Favourites | Move + Overwrite onto an indexed `.SLDB` path fails `UNIQUE(fullPath)` silently (`:3358`), leaves `imagesData` captions/audio (`:74933`), `staticfolders`, and Favourites (`:39088`) pointing at old paths, and sets `currentFilesListModified := 1` unconditionally (`:3382`) | read |
| 16 | **Medium** | `UsrEditFileDestination` / Browse | Shared super-global `UsrEditFileDestination` leaks `CopyMovePanelWindow` tokens (`.\`, `[group-by-...]`, `--={ other destinations }=--`) into `Destination:`, while `BtnCpyMvStrctrdChooseFilesDst` mutates/desyncs the global | read |
| 17 | **Medium** | Persistence / Theme & Font toggles | `userCopyMoveStructuredConflictMode` has zero `INIaction`/`RegAction` persistence; `UsrCopyMoveOperation` resets to `1` every open; `RecentCopyMoveManager`/`prevFileMovePath` are omitted; toggling Dark Mode or Large Fonts wipes all typed fields | read |
| 18 | **Medium** | `PanelStructuredCopyMoveWindow` (`Source:` pre-fill) | `Source:` (`OutDir` `:60759`) is taken from `currentFileIndex` even when unselected, soft-deleted (`"||"`), in a deep leaf subfolder, at a drive root (`"C:"`), or virtual (`Q:\Temporary Memory Object`) | read |
| 19 | **Medium** | `copyMoveStructuredFolders` | `!FileExist(file2rem)` (`:3256`) runs *before* `!InStr(file2rem, srcDir "\")` (`:3262`), stalling on offline drives for out-of-scope files and miscounting them as `failedFiles` instead of `skippedFiles` | read |
| 20 | **Medium** | `BTNuiProceedStructuredOperation` | `If (StrLen(dS)>4)` (`:60824`) falsely rejects valid 4-character new destination folders like `D:\a` (`StrLen = 4`) | read |
| 21 | **Medium** | `PanelStructuredCopyMoveWindow` / `GuiAddDropDownList` | Passing `[hTemp, hTempu, zh]` (`:60781`) sets raw hex HWND `zh` (e.g. `0x1909ca`) as the hover tooltip on `"Action to perform:"` | read |
| 22 | **Medium** | `BtnIdentifyFileRoots` / `Menu, Manna` | `"Please wait..."` (ToolTip #1) stays stuck onscreen while `Menu, Manna, Show` blocks (`:60110–60131`); `&` in folder names is unescaped; paths are lowercased; keyboard `Space` opens menu at mouse cursor; menu ignores dark mode | read |
| 23 | **Medium** | `SettingsGUIAGuiContextMenu` / `SettingsToolTips` | Right-clicking `Source:` or `Destination:` `Edit` controls suppresses Windows' native Cut/Copy/Paste context menu and shows internal variable names (`UsrEditFileSource` / `UsrEditFileDestination`) | read |
| 24 | **Medium** | Close / Keyboard / Hotkeys | `Escape`, `X`, and `&Close panel` fail for 1,000 ms after Browse/Help/MsgBox (`:97971`) and 450 ms after open (`:4323`); `F1` fails or shows thumbs help (`:89688`); `Up`/`Down` mutate digits in path `Edit`s (`:853`); `:` opens Quick Search over panel (`:1035`) | read |
| 25 | **Low** | Privacy (`userPrivateMode`) | `userPrivateMode = 1` is ignored in `Source:`, `Destination:`, `Manna` root menu, Browse start paths, conflict dialogs, and progress/completion OSD tooltips | read |
| 26 | **Low** | `PanelStructuredCopyMoveWindow` / `copyMoveStructuredFolders` | `%infoSelection%` evaluated before assignment (`:60767` vs `:60783`); `getSelectedFiles(0, 1)` called twice (`:60763, :60782`); `"This panels"` typo (`:60767`); `prevuDir` never cached when `OutDir` exists (`:3294`); `watchFolderDetails` cleared on Copy (`:3380`) | read |
| 27 | **Low** | `PanelStructuredCopyMoveWindow` layout & scope | `Global ... lastInvoked := 1` scope leak (`:60737`); `"Source: "` missing `hp +0x200` (`:60768`); missing `+BackgroundTrans`; `&Proceed` width `60px` cramped & enabled on `"Choose..."`; missing `&` mnemonics on menu item & labels; dead locals | read |
| 28 | **Low** | Browse wrappers / `ResetImgLoadStatus` / `CloseWindow` | Identical generic `"Select Folder"` titles on both Browse buttons (`:59861, :59881`), `/` not normalized before `Trimmer`, missing `WinActivate` on XP fallback; spurious `ResetImgLoadStatus` timer (`:60787`); `HIMAGELIST` leak when `ShowAdvToolbar != 1` (`:97991`) | read |

---

## 1. Wrong path normalization order and raw string check (`dS=fS`) cause silent 100% file skip or catastrophic self-deletion to Recycle Bin

**Where:** `BTNuiProceedStructuredOperation()` (`:60809–60814`, `:60840`) and `copyMoveStructuredFolders()` (`:3211`, `:3262`, `:3283`, `:3312–3337`).

```ahk
; quick-picto-viewer.ahk:60809-60814
fS := Trim(UsrEditFileSource, "\")
dS := Trim(UsrEditFileDestination, "\")
fS := StrReplace(fS, "/", "\")
dS := StrReplace(dS, "/", "\")
fS := Trimmer(fS)
dS := Trimmer(dS)
...
; quick-picto-viewer.ahk:60840
If (dS=fS)
   Return msgBeepTimer("ERROR: The destination folder must not be identical with the source.")
```

Three compounding defects sit in these ten lines:

1. **Reversed sanitization order:** `Trim(..., "\")` runs *before* `StrReplace(..., "/", "\")` and *before* `Trimmer(...)` (whitespace strip).
   - Any trailing forward slash (`C:/temp/imgs/` or `C:\temp\imgs/`) is not touched by `Trim(..., "\")` at `:60809–60810`, and is then turned into a trailing backslash (`"C:\temp\imgs\"`) at `:60811–60812`.
   - Any trailing space after a backslash (`"C:\temp\imgs\ "`, common after copy-paste) prevents `Trim(..., "\")` from stripping `\`; `:60813–60814` then strips the space, again leaving `"C:\temp\imgs\"`.
2. **Repeated internal backslashes (`\\`), `.` / `..` segments, 8.3 short names, junctions/symlinks/`SUBST` drives, and non-ASCII case differences are never normalized:** unlike `BtnCopyMoveAction()` (`:60985`, `:61025`), `BTNuiProceedStructuredOperation` never collapses `\\` → `\`, never resolves full paths (`GetFullPathNameW`), and `copyMoveStructuredFolders` never checks `isSameFilePath(file2rem, file2save)` (`:62479`) or Win32 file identity before recycling `file2save`.
3. **Destructive overwrite sequence when `fS` and `dS` name the same folder via different strings:**

**Concrete scenarios:**

- **Scenario A — Catastrophic self-deletion under Overwrite (even when copying!):**
  Suppose `Source:` is `C:\temp\imgs` and `Destination:` is `C:/temp/imgs/`, `C:\temp\imgs\ `, `C:\temp\\imgs`, or `C:\temp\.\imgs`, with `On file name conflicts: Overwrite` (`3`) (or `Ask user` where the user clicks `Overwrite`), and `Action to perform:` set to **either `Copy file(s)` or `Move file(s)`**.
  1. `FolderExist(fS)` and `FolderExist(dS)` both return non-empty `"D"`.
  2. `If (dS=fS)` (`:60840`) and `If (srcDir=finalDest ...)` (`:3211`) both evaluate **false** (`"C:\temp\imgs\" != "C:\temp\imgs"`).
  3. At `:3283`, `file2save := StrReplace("C:\temp\imgs\imgA.png", "C:\temp\imgs\", "C:\temp\imgs\\")` produces `"C:\temp\imgs\\imgA.png"`, which Win32 resolves to the **exact same physical file** as `file2rem`.
  4. At `:3299–3300`, `FileExist(file2save)` is true; `askAboutFileCollision` sets `performOverwrite := 1` and returns `file2save`.
  5. At `:3317–3319`, QPV clears `-R` and executes `FileRecycle, %file2save%` — **sending the user's original source file into the Recycle Bin**!
  6. At `:3332` / `:3334`, `FileMove` / `FileCopy` from `file2rem` to `file2save` fails with `ErrorLevel = 1` because `file2rem` no longer exists (`wasError := 1`).
  7. Because `wasError = 1`, `:3339` (`If (wasError!=1 && ...)`) is skipped: **`recordUndoFileActs` (`:3351`) is never called**, `failedFiles++` increments for every selected image, and QPV ends with `"Finished copying 0 out of N files ... Failed to perform action on N files"` while every selected source file has been deleted to the Recycle Bin (or permanently lost on network shares / `NoRecycleBin` volumes where `FileRecycle` deletes directly or fails).

- **Scenario B — Silent 100% file skip on Source:**
  User types or pastes `C:/temp/imgs/` or `C:\temp\imgs\ ` into `Source:` and `D:\ordered` into `Destination:`. `fS` becomes `"C:\temp\imgs\"`. `FolderExist(fS)` succeeds. At `:3262`, `If !InStr(file2rem, srcDir "\")` searches for `"C:\temp\imgs\\"` (double backslash), fails on every selected file (`"C:\temp\imgs\imgA.png"`), and skips 100% of the batch (`Finished copying 0 out of N files ... Skipped files: N`).

- **Scenario C — Double-backslash path corruption in index, `.SLDB`, and Undo:**
  User sets `Source:` to `C:\temp\imgs` and `Destination:` to `D:/ordered/` (`dS = "D:\ordered\"`). Every `file2save` becomes `"D:\ordered\\sub\img.jpg"`. Win32 creates and writes the file, and on Move (`:3351–3360`) QPV stores `"D:\ordered\\sub\img.jpg"` verbatim in `resultedFilesList`, `mainUnfilteredList`, `.SLDB`, and `fileActsHistoryArray`.

---

## 2. No guard when Destination is inside Source (`C:\a` → `C:\a\sub`) or Source is inside Destination (`C:\a\sub` → `C:\a`)

**Where:** `BTNuiProceedStructuredOperation()` (`:60840`) and `copyMoveStructuredFolders()` (`:3262`, `:3283`, `:3313–3335`).

`:60840` checks only `If (dS=fS)`. Neither `InStr(dS "\", fS "\") = 1` (Destination is a subfolder of Source) nor `InStr(fS "\", dS "\") = 1` (Source is a subfolder of Destination) is checked or handled.

1. **Recursive subfolder nesting (`C:\Photos` → `C:\Photos\Backup`):**
   If a user loads `C:\Photos` recursively (containing `C:\Photos\2025\a.jpg` and an earlier `C:\Photos\Backup\b.jpg`), selects all (`Ctrl+A`), and copies/moves from `C:\Photos` to `C:\Photos\Backup`, `b.jpg` matches `InStr(file2rem, "C:\Photos\")` (`:3262`) and is copied/moved to `C:\Photos\Backup\Backup\b.jpg` (and `Backup\Backup\Backup\...` on subsequent runs).
2. **Intra-batch data destruction under Overwrite (`C:\a` → `C:\a\sub` or `C:\a\sub` → `C:\a`):**
   Suppose `resultedFilesList` has selected items `[1] C:\a\img.jpg` and `[2] C:\a\sub\img.jpg`, `Source:` = `C:\a`, `Destination:` = `C:\a\sub`, `Action:` = `Move file(s)`, `Conflict:` = `Overwrite`:
   - **Iteration 1 (`[1] C:\a\img.jpg`):** `file2save` is `C:\a\sub\img.jpg` — which is selected item `[2]`! `:3319` recycles `[2]`'s original file, and `:3332` moves `[1]` onto `C:\a\sub\img.jpg`.
   - **Iteration 2 (`[2] C:\a\sub\img.jpg`):** `FileExist("C:\a\sub\img.jpg")` (`:3256`) is still true — **but it now contains `[1]`'s image, not `[2]`'s**! Iteration 2 moves `[1]`'s bytes to `C:\a\sub\sub\img.jpg`, leaving `C:\a\sub\img.jpg` non-existent (breaking `[1]`'s just-updated `resultedFilesList[1, 1]`!) while `[2]`'s content is in the Recycle Bin under a path that `[2]`'s own Undo entry no longer points to.
   - The mirror-image collision happens for `Source: C:\a\sub` → `Destination: C:\a` whenever `[1] C:\a\sub\img.jpg` is processed before `[2] C:\a\sub\sub\img.jpg`.

---

## 3. Broken Undo recovery for overwritten files on Move, missing subfolder recreation on Undo, and missing `quickBarFileUndo`

**Where:** `copyMoveStructuredFolders()` (`:3315–3316`, `:3350–3351`, `:3380–3403`), `recordUndoFileActs()` (`:95019–95034`), `friendlyFileUndoInfos()` (`:95064–95108`), `batchUndoFileActs()` (`:94840–94862`), `corefileUndoAction()` (`:94627–94644`), and `restoreFileFromRecycleBin()` (`lib/shell-stuff.ahk:2571–2634`).

1. **`recordUndoFileActs` drops `originalFileInfos` on every Move (`actu = 2`):**
   In `copyMoveStructuredFolders`, `:3315–3316` captures the overwritten destination file's metadata before recycling it:
   ```ahk
   ; quick-picto-viewer.ahk:3315-3316, 3350-3351
   jso := GetFileAttributesEx(file2save)
   originalFileInfos := jso.size "|" jso.wtime "|" jso.ctime
   ...
   extraMarker := (thisFileExists=1 && performOverwrite=1) ? "*" : ""
   recordUndoFileActs(file2save, resultedFilesList[thisFileIndex, 1], extraMarker, UsrCopyMoveOperation, startZeit, originalFileInfos)
   ```
   Inside `recordUndoFileActs()` (`:95030–95033`):
   ```ahk
   If (actu=1)
      fileActsHistoryArray[z] := onewPath "|" zeit "|Recycle-Bin|" extraMarker "|" originalFileInfos
   Else
      fileActsHistoryArray[z] := (actu=2) ? onewPath "|" zeit "|" oldPath extraMarker : onewPath "|" zeit "|?" oldPath extraMarker "|" originalFileInfos
   ```
   When `actu = 2` (`Move file(s)`), the true branch of the ternary **omits `"|" originalFileInfos` completely**!
   - When `friendlyFileUndoInfos()` (`:95066–95107`) parses the entry, `o.ovr` is `"Yes"` (from `*`), but `o.fsize := ju[3]` (`:95105`), `o.mfdate := ju[4]`, and `o.cfdate := ju[5]` are all `""`.
   - In **batch Undo** (`batchUndoFileActs` `:94854–94862`), `If (obj.fsize>0)` (`"" > 0`) is **always false**, so `restoreFileFromRecycleBin()` is **never called** and `failedRecoverFiles++` increments for **100% of overwritten files**!
   - In **single-file Undo** (`corefileUndoAction` `:94642`), `restoreFileFromRecycleBin(imgPath, obj.fsize)` is called with `userFileSize = ""`, bypassing the byte-size check (`lib/shell-stuff.ahk:2627`) and restoring whichever recycled file with that path happens to appear first in the Recycle Bin.
2. **Undo Move fails if emptied source subfolders were removed (`:94627`, `:94840`):**
   Structured Move relocates files out of nested source subfolders (`C:\src\2024\05\a.jpg`). If the user deletes the empty `C:\src\2024\05` directory tree afterward and invokes Undo, neither `corefileUndoAction` (`:94627`) nor `batchUndoFileActs` (`:94840`) calls `FileCreateDir` on the parent of `otherFile` before `FileMove, % imgPath, % otherFile, 1`, causing Undo Move to fail (`ErrorLevel = 1`). Conversely, Undo Move/Copy never cleans up the newly created empty directory tree under `finalDest`.
3. **Missing Undo quick-bar prompt (`:3380–3403` vs `:61534`):**
   `QuickMoveFile2Dest()` (`:61534`) calls `quickBarFileUndo((UsrCopyMoveOperation=2) ? "Undo move" : "Undo copy")` after a batch finishes so the user gets an immediate Undo button; `copyMoveStructuredFolders()` never calls `quickBarFileUndo()`.

---

## 4. Unsaved viewport image edits are silently destroyed when Structured Move relocates the active image

**Where:** `PanelStructuredCopyMoveWindow()` (`:60736`), `BTNuiProceedStructuredOperation()` (`:60800`), `copyMoveStructuredFolders()` (`:3355`, `:3385`), and `ResizeImageGDIwin()` (`:75318–75321`).

Unlike navigation and gallery-reload commands that call `askAboutFileSave()` (`:64909`) when `currentImgModified = 1`, Structured Copy/Move never checks `askAboutFileSave()` at panel open, on `&Proceed`, or inside `copyMoveStructuredFolders()`.

**Trace when `thumbsDisplaying = 0` and the user has unsaved pixel/vector edits on the current image (`currentImgModified = 1`, `undoLevelsRecorded > 1`) while `markedSelectFile > 1`:**
1. User opens `Structured file operations` (via `Right-click → File actions → Structured file operations` `:69548`, Quick Search `:`, or `F8`), chooses `Move file(s)`, and clicks `&Proceed`.
2. When `thisFileIndex == currentFileIndex`, `:3355` updates `resultedFilesList[currentFileIndex, 1] := file2save` without calling `updateViewportCachesID()` (contrast `:94659`).
3. At `:3385`, `dummyTimerDelayiedImageDisplay(100)` schedules a viewport refresh.
4. 100 ms later, `ResizeImageGDIwin()` (`:75318–75321`) compares the new `thisImgPath` (`file2save`) against `prevImgPath` (`file2rem`), sees they differ while `undoLevelsRecorded > 1`, and calls `terminateIMGediting()` — **silently discarding all unsaved image edits and undo levels without prompting**.

---

## 5. UNC network paths (`\\server\share\...`) are broken across Proceed, Browse, pre-fill, and `zPlitPath`

**Where:** `BTNuiProceedStructuredOperation()` (`:60809–60810`), `BtnCpyMvStrctrdChooseFilesDst()` (`:59853`, `:59855`), `BtnCpyMvStrctrdChooseFilesSrc()` (`:59873`, `:59875`), `PanelStructuredCopyMoveWindow()` (`:60759`), `copyMoveStructuredFolders()` (`:3284`), and `zPlitPath()` (`:59906–59928`).

Every path-trimming site uses two-sided `Trim(path, "\")` or `Trimmer(path, "\")` (`Trim(inputString, trimChars)` at `:32663`) instead of `RTrim(path, "\")`, stripping the **leading `\\`** that defines a UNC path:

1. **Panel open (`:60759`):** `zPlitPath` splits by `\` skipping empty tokens (`:59908`) and runs `Trim(folderu, "\")` (`:59928`), turning `\\nas\photos\2026\a.jpg` into `OutDir = "nas\photos\2026"` in `Source:`.
2. **`&Browse` and `B&rowse` (`:59853–59857`, `:59873–59877`):** `Trimmer(..., "\")` strips `\\` from both `p` and `UsrEditFileDestination`/`UsrEditFileSource`, so `FolderExist(p)` fails and the folder dialog falls back to `prevFileMovePath` or Desktop instead of starting in the UNC folder.
3. **`&Proceed` (`:60809–60810`):** even when the user picks `\\nas\photos` via `&Browse` (which puts `"\\nas\photos"` into the `Edit`), `:60809` `fS := Trim(UsrEditFileSource, "\")` turns it into `"nas\photos"`, immediately failing `FolderExist(fS)` (`:60816`) with `"ERROR: Please choose an existing source folder."`!
4. **Local Source → UNC Destination creates folders inside `%A_ScriptDir%`:** if `Source:` is `C:\imgs` and `Destination:` is `\\nas\archive`, `:60810` turns `dS` into `"nas\archive"` (`StrLen = 11 > 4`). `:60826` asks `"The destination folder seems to not exist. nas\archive\ Would you like to create it now?"`; clicking `Yes` creates `%A_ScriptDir%\nas\archive` inside QPV's own installation directory and moves/copies the files there!
5. **`copyMoveStructuredFolders` (`:3284` → `zPlitPath`):** even if `dS` preserved `\\`, `zPlitPath(file2save, 1, ..., OutDir, ...)` strips `\\` from `OutDir`, so `:3289` (`FileCreateDir, % OutDir`) would still create local `nas\archive\sub` directories under `%A_WorkingDir%`.

---

## 6. Missing absolute-path, illegal-character, and anchored-prefix validation corrupts `%A_ScriptDir%` and `resultedFilesList`

**Where:** `BTNuiProceedStructuredOperation()` (`:60816–60838`), `copyMoveStructuredFolders()` (`:3262`, `:3283`, `:3355–3360`), `SetWorkingDir, %A_ScriptDir%` (`:69`); compare `BtnCopyMoveAction()` (`:61027–61046`).

Unlike `BtnCopyMoveAction()` — which checks `SubStr(dS, 2, 2) = ":\"` (`:61032`) and sanitizes path segments via `filterFileName()` (`:61027–61031`) — `BTNuiProceedStructuredOperation()` performs **zero** syntax or absolute-path validation on `fS` or `dS`:

1. **Relative `Destination:` paths (including `..` and cross-panel `[group-by-...]` tokens):**
   - Typing `..` (`StrLen = 2`) passes `FolderExist("..")` (`:60822`) without even prompting, moving/copying files into the parent directory of `%A_ScriptDir%` and recording `"..\sub\img.jpg"` in `resultedFilesList`!
   - Typing `sorted_imgs` — or leaving a polluted token like `[group-by-month-year]` or `--={ other destinations }=--` in `UsrEditFileDestination` from `CopyMovePanelWindow` (see **#16**) — has `StrLen > 4`, prompts `"Would you like to create it now?"`, creates `%A_ScriptDir%\sorted_imgs` (or `%A_ScriptDir%\[group-by-month-year]`), and on Move writes relative paths into `resultedFilesList` (`:3355`) and `.SLDB` (`:3358`), violating `RegExFilesPattern` (`^(.\:\\).*`, `:116`).
2. **Relative `Source:` matching mid-path (`:3262`, `:3283`):**
   If the user enters a relative name that happens to exist under `%A_ScriptDir%` (such as `resources` or `lib`), `FolderExist("resources")` (`:60816`) succeeds! Then `:3262` checks unanchored `If !InStr(file2rem, srcDir "\")` (not `InStr(...) != 1`) and `:3283` runs `StrReplace(file2rem, srcDir "\", finalDest "\")` without `Limit := 1`. Any selected file at `D:\art\resources\pic.png` matches `"resources\"` mid-string, corrupting `file2save` into `"D:\art\E:\dest\pic.png"`! (Even with an absolute `srcDir = "C:\a"`, if a path somehow contained `"C:\a\"` twice, omitting `Limit := 1` replaces every occurrence.)
3. **Illegal characters, trailing dots, and unmounted drives (`:60824–60835`):**
   Entering `D:\bad?folder*` or `Z:\missing_drive_folder` (`StrLen > 4`) prompts `"Would you like to create it now?"` before failing `FileCreateDir` with `"Possibly access denied."`. Entering `D:\sub.` creates `"D:\sub"` on Win32 (Win32 strips trailing dots) while `file2save` retains `"D:\sub.\..."` or mismatches path strings.

---

## 7. Non-ASCII Unicode case mismatch silently skips 100% of files or bypasses `dS=fS` into Overwrite self-deletion

**Where:** `IdentifyFileFolderRoots()` (`:60166`), `menuSetSourceStructuredOper()` (`:60142`), `updateSQLdbEntry()` (`:34195`), `BTNuiProceedStructuredOperation()` (`:60840`), and `copyMoveStructuredFolders()` (`:3262`, `:3283`).

QPV never calls `StringCaseSense`, so AutoHotkey v1's default `StringCaseSense, Off` is in effect everywhere. In AHK v1, `StringCaseSense, Off` (`=`, `InStr`, `StrReplace` with default `CaseSense`) folds **only ASCII `A–Z` / `a–z`** — non-ASCII Unicode letters (`Ș`/`ș`, `Ă`/`ă`, `É`/`é`, `Ü`/`ü`, Cyrillic, Greek, etc.) are compared **case-sensitively** unless `StringCaseSense, Locale` is active!

Meanwhile, two subsystems explicitly lowercase full Unicode strings via `Format("{:L}", ...)`:
- `IdentifyFileFolderRoots()` (`:60166`): `OutDir := Format("{:L}", OutDir)` — turning `"C:\Școală\2026"` into `"c:\școală\2026"` (`"Ș"` U+0218 → `"ș"` U+0219).
- `.SLDB` SQLite databases (`:34195`): paths loaded from `.SLDB` are stored lowercased (`"c:\școală\2026\img.jpg"`).

**Two severe consequences on non-ASCII folder names:**
1. **100% silent file skip:**
   - Normal folder gallery (`resultedFilesList` has `"C:\Școală\2026\a.jpg"`): user clicks `Possible source paths` and picks item `1` (`"c:\școală"`). At `:3262`, `InStr("C:\Școală\2026\a.jpg", "c:\școală\")` returns **`0`** (`"Ș" != "ș"` under `StringCaseSense, Off`) — **every file is skipped**!
   - `.SLDB` gallery (`resultedFilesList` has `"c:\școală\2026\a.jpg"`): user clicks `&Browse` (`ShellFileDialog` returns filesystem case `"C:\Școală"`). `InStr("c:\școală\2026\a.jpg", "C:\Școală\")` returns **`0`** — **every file is skipped**!
2. **Overwrite self-deletion when `Source` and `Destination` differ only in Unicode case:**
   In an `.SLDB` gallery, `Source:` is `"c:\școală"` (from pre-fill or `Possible source paths`) and the user picks the *same* folder `"C:\Școală"` for `Destination:` via `B&rowse`, with `Overwrite` enabled.
   - `:60840` `If (dS=fS)` compares `"C:\Școală" = "c:\școală"` → **false**!
   - `:3262` `InStr("c:\școală\a.jpg", "c:\școală\")` → **true**!
   - `:3283` `file2save` becomes `"C:\Școală\a.jpg"`, which NTFS resolves case-insensitively to the **same file** `"c:\școală\a.jpg"`!
   - `:3319` `FileRecycle, %file2save%` **recycles the source file itself**, and `:3332`/`3334` fails!

---

## 8. Extensionless files or pre-existing folders at `file2save` silently move/copy files inside a subdirectory while corrupting index paths

**Where:** `copyMoveStructuredFolders()` (`:3284–3360`) and `zPlitPath()` (`:59916`).

1. **Extensionless files (`zPlitPath` `:59916`):**
   If a selected image has no `.ext` (e.g. `D:\src\photo_raw` opened via raw/header sniffing or renamed without extension), `zPlitPath(file2save, 1, ..., OutDir, ...)` checks `If (InStr(A_LoopField, ".") && A_Index=max)` (`:59916`), treats the filename itself as a directory segment, and sets `OutDir := file2save` (`"E:\dst\photo_raw"`). `:3289` (`FileCreateDir, % OutDir`) **creates a folder** named `E:\dst\photo_raw`!
2. **What happens next whenever `FolderExist(file2save)` is true** (either from step 1, or because `E:\dst\sub\photo.jpg\` already exists as a directory on disk):
   - `:3299` `If (FileExist(file2save) && !FolderExist(file2save))` skips `askAboutFileCollision`!
   - `:3312` `FileRexists(file2save, 0)` returns `0` for folders (`:32671` `!InStr(obju.attr, "D")`), so `:3326` sets `mustPerformOperation := 1`!
   - `:3332` / `:3334` executes `FileMove, %file2rem%, %file2save%, 1` (or `FileCopy`). In AutoHotkey v1, when the destination path of `FileMove` / `FileCopy` is an **existing directory**, AHK moves/copies the source file **inside** that directory (`E:\dst\sub\photo.jpg\photo.jpg`) and sets `ErrorLevel := 0`!
   - `:3351–3360` then records `E:\dst\sub\photo.jpg` (the **folder** path, not `...\photo.jpg\photo.jpg`) into `resultedFilesList`, `.SLDB`, and `fileActsHistoryArray`! The image immediately becomes unreadable in QPV and un-undoable.

---

## 9. Unchecked `createSettingsGUI(77, A_ThisFunc)` return value crashes the thread or adds controls onto GUI `1:`

**Where:** `PanelStructuredCopyMoveWindow()` (`:60742`), `createSettingsGUI()` (`:28011–28026`), and `CloseWindow()` (`:97955`, `:97971`).

`:60742` calls `thisBtnHeight := createSettingsGUI(77, A_ThisFunc)` without checking `If !thisBtnHeight Return` (compare `coreColorsAdjusterWindow()` at `:91205`, which checks `If !thisBtnHeight Return`).

`createSettingsGUI` returns `""` early without destroying or recreating `SettingsGUIA` when:
- `AnyWindowOpen` is non-zero and `CloseWindow()` returns `1` (`:28020–28025`) — which happens whenever `isNowFakeWinOpen = 1` (`:97955`) or `A_TickCount - lastLongOperationAbort < 1000` (`:97971`, i.e., within 1,000 ms of dismissing `&Help`, `&Browse`, or any `msgBoxWrapper` dialog!), **or**
- `isNowAlphaPainting()` is truthy (`:28011`).

**Concrete crash scenario:**
Open `CopyMovePanelWindow` (`M` / `C`, `AnyWindowOpen = 9`) or `PanelStructuredCopyMoveWindow` (`AnyWindowOpen = 77`), click `&Help` or `&Browse`, dismiss that dialog (`lastLongOperationAbort := A_TickCount` at `:33311` / `:64359`), and within 1 second invoke `PanelStructuredCopyMoveWindow` (e.g. via custom shortcut or menu). `CloseWindow()` returns `1`, `createSettingsGUI` returns `""` while `SettingsGUIA` still holds `vUsrEditFileDestination`, `vUsrCopyMoveOperation`, and `vBtnCpyMv`, and `:60769–60789` immediately throw an **unhandled AutoHotkey runtime error dialog**: `"Error: The same variable cannot be used for more than one control."` And if `AnyWindowOpen = 0` while `isNowAlphaPainting() = 1`, `Gui, SettingsGUIA: Default` is never executed, so all controls are added onto default GUI `1:`!

---

## 10. File-engine edge cases: premature `FileRecycle`, 0-byte `FileRexists` blind spot, `+R` cross-drive partial move, stale `performOverwrite`, and missing `lockDestinationFileName`

**Where:** `copyMoveStructuredFolders()` (`:3298–3337`), `FileRexists()` (`:32669–32676`), and `askAboutFileCollision()` (`:43652–43656`) / `lockDestinationFileName()` (`:38454–38485`).

1. **Premature `FileRecycle` before `FileMove`/`FileCopy` (`:3319` vs `:3332–3336`):**
   - `:3319` recycles `file2save` *before* attempting `FileMove`/`FileCopy`. If `FileMove`/`FileCopy` subsequently fails (locked source file, network drop, disk full), `wasError := 1` skips `recordUndoFileActs` (`:3351`) while the pre-existing destination file has already been removed!
   - Conversely, `:3319` ignores `ErrorLevel` on `FileRecycle, %file2save%`. If `FileRecycle` fails (e.g. Recycle Bin unavailable/corrupt or path too long) and `:3332`/`3334` (`FileMove`/`FileCopy ..., 1`) succeeds by **permanently overwriting** `file2save` in place, `:3350` still sets `extraMarker := "*"` (claiming the original file is recoverable from the Recycle Bin when it was permanently overwritten).
2. **0-byte destination files treated as non-existent (`:3312` → `FileRexists` `:32672`):**
   `FileRexists(file, AllowZeroSize:=1)` checks `(obju.size>0 || AllowZeroSize=1)` (`:32672`). Because `:3312` passes `AllowZeroSize = 0` (`FileRexists(file2save, 0)`), any existing **0-byte** destination file returns `thisFileExists = 0`! Consequently:
   - `-R` is not stripped (`:3317`), so overwriting a read-only 0-byte placeholder fails;
   - `FileRecycle` (`:3319`) is skipped and `extraMarker` is `""`;
   - The TOCTOU non-overwrite safety branch (`Else If (thisFileExists=1)` `:3322`) is bypassed, so `:3332`/`3334` (`..., 1`) silently overwrites a 0-byte file!
3. **Read-Only (`+R`) source files on cross-volume Move (`:3332`):**
   `:3317` strips `-R` on `file2save`, never on `file2rem`. In AHK/Win32, moving a `+R` file across different volumes (`C:\` → `D:\`) copies the file to `file2save`, fails to delete `+R` `file2rem`, and sets `ErrorLevel = 1`. QPV sets `wasError := 1` and counts `failedFiles++`, leaving an unrecorded duplicate copy at `file2save`!
4. **`performOverwrite` is not reset at `:3298`:**
   `:3298` resets `originalFileInfos := mustPerformOperation := wasError := operationExecuted := 0`, omitting `performOverwrite := 0` (unlike `QuickMoveFile2Dest` `:61423`). When `:3299` is false on iteration `k`, `performOverwrite` retains `1` from an earlier overwrite; if `file2save` appears before `:3312` (TOCTOU race), `:3313` recycles and overwrites it without asking even when `forceConflictOption = 4` (`Ask user`).
5. **Missing `lockDestinationFileName(file2save, 2)` batch lock (`:3283` vs `:61424`, `:61533`):**
   `askAboutFileCollision()` (`:43652–43653`) explicitly checks `forceOption=3 && lockDestinationFileName(destFile, 3)` so a batch with `Overwrite` auto-renames rather than overwriting a file **written earlier in the same batch**! Because `copyMoveStructuredFolders` never calls `lockDestinationFileName(file2save, 2)` inside its loop (nor `lockDestinationFileName("", 2)` on exit), `lockDestinationFileName(..., 3)` always returns `0` (`:38459`). Thus duplicate entries in an `.SLD` list, case-sensitive WSL/NTFS siblings (`a.jpg` + `A.jpg`), or a file auto-renamed to `img_1.jpg` followed by an existing `img_1.jpg` in the same batch will overwrite the batch's own earlier output.

---

## 11. `IdentifyFileFolderRoots()` fails on depth-1 and drive-root folders (dead button), suggests parent of single folder, and contradicts QPV's own Help example

**Where:** `IdentifyFileFolderRoots()` (`:60181–60241`), `BtnIdentifyFileRoots()` (`:60113–60130`), and `BtnHelpStructuredCopyMove()` (`:60797`).

```ahk
; quick-picto-viewer.ahk:60181-60208
Loop, Parse, listu, `n
{
   If (ST_Count(A_LoopField, "\")>0)
      mList .= A_LoopField "`n"
}
...
Loop, Parse, mList, `n
{
   ...
   p := SubStr(A_LoopField, k, InStr(A_LoopField, "\", 0, -1) - k)
   If (p && !InStr(nList, p "`n"))
      nList .= p "`n"
}
...
Loop, Parse, nList, `n
{
   c := ST_Count(A_LoopField, "\")
   If (c>0)
      flist .= c "|" A_LoopField "`n"
}
```

Loop 3 (`:60194`) **unconditionally strips the leaf folder segment** from every directory containing selected files, and Loop 4 (`:60206`) discards any result with `0` backslashes (`"c:"`), before Loop 6 (`:60233`) discards any path whose ancestor is already present:

1. **Dead button on top-level folders (`C:\imgs\a.jpg`, `C:\imgs\b.jpg`) and drive roots (`C:\a.jpg`):**
   - Drive root `"c:"` has `0` backslashes → dropped at `:60182`.
   - Any 1-level folder (`"c:\imgs"`, or `"c:\dir1"` + `"c:\dir2"`) is stripped to `"c:"` at `:60194`, then dropped at `:60206` (`c = 0`)!
   - `IdentifyFileFolderRoots` returns `["", 0]`. In `BtnIdentifyFileRoots()` (`:60116–60130`), `Menu, Manna, Delete` deletes the menu, zero items are added, and `Try Menu, Manna, Show` silently fails! Clicking the `"Possible source paths"` button **does nothing at all** — no menu, no tooltip, no beep.
2. **Single folder at depth ≥ 2 (`C:\work\imgs\a.jpg`, `b.jpg`) suggests its parent (`c:\work\`):**
   `"c:\work\imgs"` is stripped to `"c:\work"`. Picking `1. c:\work\` creates an unwanted extra `imgs\` wrapper subfolder inside `Destination:`!
3. **Fails QPV's own `&Help` example (`:60797`):**
   `BtnHelpStructuredCopyMove()` gives the example of selected files:
   - `c:\temp\imgs\imgA.png` (`OutDir = "c:\temp\imgs"` → stripped to `"c:\temp"`)
   - `c:\temp\imgs\new\img01.jpg` (`OutDir = "c:\temp\imgs\new"` → stripped to `"c:\temp\imgs"`)
   - `c:\temp\imgs\old\img02.jpg` (`OutDir = "c:\temp\imgs\old"` → stripped to `"c:\temp\imgs"`)
   - `c:\temp\CRW0292303.tga` (`OutDir = "c:\temp"` → stripped to `"c:"` → dropped)

   Loop 6 (`:60233`) keeps `"c:\temp"` (`prevu := "c:\temp"`) and **discards `"c:\temp\imgs"`** because `InStr("c:\temp\imgs", "c:\temp\")` is truthy! Thus the menu **only** offers `1. c:\temp\` — never `c:\temp\imgs\` as required by the Help text — which fails to skip `c:\temp\CRW0292303.tga` and nests everything under an extra `imgs\` folder!
4. **UNC paths (`\\server\share\a.jpg`):** `:60194` strips `\share`, leaving `"\\server"` (a bare server name, not even a valid share root).

---

## 12. Four additional bugs inside `IdentifyFileFolderRoots()`: global shallowest-depth `Break`, ASCII sort `< '\'` bug, unanchored `InStr`, and stale `"cached"` list

**Where:** `IdentifyFileFolderRoots()` (`:60150–60153`, `:60160`, `:60195`, `:60218–60238`) and `BtnIdentifyFileRoots()` (`:60113`, `:60120–60128`).

1. **Global minimum-depth `Break` hides deeper folder trees on other drives/branches (`:60218–60221`):**
   ```ahk
   If (p=0)
      p := k[1]
   if (k[1]>p + 1)
      Break
   ```
   `flist` is sorted globally by backslash count `k[1]`. If *one* selected file sits in `D:\work\pics\1.jpg` (stripped parent `d:\work`, `k[1] = 1` → `p = 1`), Loop 5 `Break`s before reaching `C:\Users\Marius\Pictures\2026\Trips\Rome\*.jpg` (`k[1] = 5 > 2`), omitting the entire `C:\Users\...` branch from the menu AND undercounting `"folders more"` (`:60127`).
2. **ASCII sort order breaks `prevu` ancestor deduplication (`:60225–60238`):**
   `Sort, nList, D`n` sorts by codepoint, where `' '` (32), `'&'` (38), `'('` (40), `'-'` (45), `'.'` (46), and `'0'–'9'` (48–57) all sort **before** `'\'` (92). Given candidates `c:\work\proj`, `c:\work\proj-2`, and `c:\work\proj\sub`:
   - `c:\work\proj` sets `prevu := "c:\work\proj"`;
   - `c:\work\proj-2` sorts *next* (`'-'` 45 < `'\'` 92) and overwrites `prevu := "c:\work\proj-2"`;
   - `c:\work\proj\sub` checks `InStr("c:\work\proj\sub", "c:\work\proj-2\")` → `0`, so `c:\work\proj\sub` is **not** culled despite `c:\work\proj` already being in `gList`!
3. **Unanchored deduplication in `listu` (`:60167`) and `nList` (`:60195`):**
   `:60195` checks `!InStr(nList, p "`n")` without a leading delimiter (`"`n" nList`). If `"d:\backup\c:\work\n"` or a suffix match were present (or for relative/UNC-stripped strings like `"nas\share"` matching `"xnas\share\n"`), `p` is falsely treated as already present. (Also `:60160` runs `Loop, % maxFilesIndex + 1`, 1 past `maxFilesIndex`.)
4. **Stale `"cached"` roots when selection changes while panel is open (`:60113`, `:60150–60153`, `:60760`):**
   `PanelStructuredCopyMoveWindow` is **modeless** (`PVhwnd` is not disabled) and clears `IdentifyFileFolderRoots("cleanup")` only once on panel open (`:60760`). If the user clicks `Possible source paths` once (populating `Static prevList`), then changes thumbnail selection in `PVhwnd` and clicks `Possible source paths` again, `IdentifyFileFolderRoots("cached")` (`:60113`) returns the **stale** `prevList` from the old selection! And if `> 10` roots exist, items `11..N` are permanently unreachable (`"... and N folders more"` is disabled at `:60128`).

---

## 13. Missing `QPV:PAGES:` virtual-frame guard, `< 2`-selection bypass via `F8`, and menu bar inconsistency

**Where:** `InvokeMenuBarFile()` (`:67406–67461`), `createMenuCurrentFilesActs()` (`:69536–69548`), `openPreviousPanel()` (`:27537–27545`), `PanelStructuredCopyMoveWindow()` (`:60736`), and `BTNuiProceedStructuredOperation()` (`:60800`).

1. **Multipage preview mode (`QPV:PAGES:`) exposed in `File` menu bar and unguarded in panel/engine:**
   Right-click `File actions` (`PVfilesActs` `:69536`) hides `"Structured file operations"` when `InStr(filesFilter, "i)(QPV:PAGES:") = 1`, **but** main menu bar `File` (`InvokeMenuBarFile` `:67430–67431`) checks only `If (thumbsDisplaying=1 && maxFilesIndex>0)` → `If (markedSelectFile>1)` — completely omitting the `QPV:PAGES:` guard! And unlike `BtnCopyMoveAction()` (`:60965`), none of `PanelStructuredCopyMoveWindow()`, `BTNuiProceedStructuredOperation()`, or `copyMoveStructuredFolders()` calls `warnFramesActionPrevented("COPY/MOVE")`.
   - Selecting 2+ virtual page frames (`C:\doc.pdf||0`, `C:\doc.pdf||1`) and choosing `File → Structured file operations` (or pressing `F8`) opens the panel, leaves `"Possible source paths"` dead (`:60163` skips `"||"`), pre-fills `Source:` as `"C:"`, and on `&Proceed` fails every page at `FileExist("C:\doc.pdf||0")` (`:3256`) with `"Failed to perform action on N files"`.
2. **`F8` (`openPreviousPanel` `:27537`) bypasses `< 2` selection and open-gallery guards:**
   `createSettingsGUI(77, A_ThisFunc)` records `prevOpenedWindow := ["PanelStructuredCopyMoveWindow", ...]` with `allowReopen = 1` (`:28027`). Pressing `F8` later reopens `PanelStructuredCopyMoveWindow()` directly even when `0` or `1` files are selected or after `closeDocuments()` (`Ctrl+F4`, `maxFilesIndex = 0`) — displaying `"Selected files: 0. "`. (Even while the panel stays open, the user can deselect thumbnails in the modeless main window so `markedSelectFile` drops below `2` while the panel's static `"Selected files: N."` label remains stale.)
3. **Menu inconsistency when `thumbsDisplaying = 0` and `markedSelectFile > 1` (`:67434–67461` vs `:69548`):**
   In single-image view (`thumbsDisplaying = 0`) with 2+ files selected, `"Structured file operations"` is present in right-click `File actions` (`:69548`) and Quick Search (`:`), yet omitted from the `Else If (thumbsDisplaying=0 && maxFilesIndex>0)` branch of main menu bar `File` (`:67434–67461`).

---

## 14. `FileCreateDir` and `BtnCloseWindow()` run before `filesElected < 2` and `> 150`-file confirmation

**Where:** `BTNuiProceedStructuredOperation()` (`:60822–60844`) and `copyMoveStructuredFolders()` (`:3210–3222`).

```ahk
; quick-picto-viewer.ahk:60829, 60843-60844
FileCreateDir, %dS%
...
BtnCloseWindow()
copyMoveStructuredFolders(fS, dS)
```
Inside `copyMoveStructuredFolders()` (`:3210–3222`):
```ahk
filesElected := markedSelectFile
If (srcDir=finalDest || !srcDir || !finalDest || filesElected<2)
   Return

If (filesElected>150)
{
   ...
   msgResult := msgBoxWrapper(appTitle ": Confirmation", ..., 4, 0, "question")
   If (msgResult!="yes")
      Return 0
}
BtnCloseWindow()
```
Notice `:3222` *already* has `BtnCloseWindow()` placed *after* both checks! Calling `BtnCloseWindow()` early at `:60843` causes two user-facing bugs:
1. **`filesElected < 2` silent failure with side effect:** If `< 2` files are selected (via `F8` or deselecting in `PVhwnd`), `:60829` creates `dS` on disk, `:60843` closes the panel, and `:3211` silently returns with **zero files processed and zero feedback**.
2. **`> 150` files `"No"` loses all panel inputs:** If 200 files are selected and the user realizes on the `> 150` confirmation dialog (`:3217`, `"Please confirm you want to MOVE the selected files"`) that they picked `Move` instead of `Copy` and clicks `"No"`, the panel has **already been destroyed** (`:60843`), wiping their typed `Source:`, `Destination:`, and conflict mode (and leaving `dS` already created on disk).

---

## 15. `.SLDB` SQLite database desynchronization on Move + Overwrite, orphaned `imagesData` / `staticfolders`, and broken Favourites

**Where:** `copyMoveStructuredFolders()` (`:3357–3360`, `:3381–3382`), `updateSQLdbEntry()` (`:34189–34216`), `SLDBinitSQLdb()` (`:74931–74935`), and `ToggleImgFavourites()` (`:39088–39108`).

1. **`UNIQUE(fullPath)` violation silently ignored on Move + Overwrite (`:3358` → `:34207–34214`):**
   In `.SLDB` schema v3 (`:74931`), `images` has `fullPath TEXT AS (imgfolder||'\'||imgfile), ..., UNIQUE (fullPath)`. When `SLDtypeLoaded = 3` and a Structured Move overwrites a `file2save` that is *also* a row in `images`:
   - `updateSQLdbEntry(file2rem, file2save, ...)` executes `UPDATE images SET imgfile=..., imgfolder=... WHERE imgidu=...;` (`:34207`).
   - SQLite aborts that statement with `UNIQUE constraint failed: images.fullPath` and returns `0` (`:34213`), **which `:3358` ignores**!
   - `:3371` (`COMMIT TRANSACTION;`) succeeds, committing all non-colliding updates while leaving the colliding moved rows at their **old** `file2rem` path in SQLite (and leaving the overwritten row's `imgidu` alive in SQLite) — permanently desynchronizing `.SLDB` from `resultedFilesList`!
2. **`imagesData` captions/audio (`:74933`, `:34107`) and `staticfolders` (`:74935`, `:35036`) never updated on Move:**
   `imagesData` is keyed by `PRIMARY KEY(imgfile ASC)` where `imgfile` stores the **full image path** (`updateSQLdbEntryCaption(imgPath, ...)` `:34108–34113`), NOT `imgidu`. `updateSQLdbEntry()` updates only `images`, so moving annotated images orphans all their captions and audio links in `imagesData`, and leaves `staticfolders` / `newStaticFoldersListCache` pointing at emptied source folders.
3. **Favourites (`mainFavesFile` / `miniFavesFile` `:39088`) broken on Move:**
   Moving a favourited image (`resultedFilesList[thisFileIndex, 5] = 1`) updates `resultedFilesList[thisFileIndex, 1]` to `file2save` while leaving `[thisFileIndex, 5] = 1` in RAM, yet never updates `mainFavesFile` / `miniFavesFile` on disk — so the badge appears active in the current session while the saved favourites file still points to dead `file2rem`.
4. **`currentFilesListModified := 1` set unconditionally even when `.SLDB` committed (`:3381–3382`):**
   When `SLDtypeLoaded = 3` and `COMMIT TRANSACTION` succeeds, `.SLDB` is already saved on disk, yet `currentFilesListModified := 1` triggers a redundant save prompt on exit (`:2101`).

---

## 16. Cross-panel pollution and desynchronization of shared super-global `UsrEditFileDestination`

**Where:** `:169`, `PanelStructuredCopyMoveWindow()` (`:60774`), `BtnCpyMvStrctrdChooseFilesDst()` (`:59851`, `:59855`, `:59864`), `BtnCpyMvStrctrdChooseFilesSrc()` (`:59871`, `:59875`), `BTNlvRecentFileDesties()` (`:60855`), and `BtnMarkFilesExplorer()` (`:60946`).

1. **Invalid tokens leaked from `CopyMovePanelWindow`:**
   `PanelStructuredCopyMoveWindow` binds `Destination:` directly to `UsrEditFileDestination` (`:60774`). In `CopyMovePanelWindow` (`AnyWindowOpen = 9`), `UsrEditFileDestination` routinely receives relative patterns (`.\`, `\subfolder`, `.\sibling`), grouping tokens (`[group-by-month-year]`, `[group-by-years]`, `[group-by-file-types]`), and even the ListView header separator `--={ other destinations }=--` (`:60015`, `:60855`). Opening `PanelStructuredCopyMoveWindow` afterward pre-fills `Destination:` with those raw tokens — which `PanelStructuredCopyMoveWindow` does **not** interpret, and which **#6** then offers to create as literal subdirectories inside `%A_ScriptDir%`!
2. **`BtnCpyMvStrctrdChooseFilesDst` fails to update `UsrEditFileDestination` (`:59851–59864`):**
   - `:59851` `GuiControlGet, UsrEditFileDestination` reads the *pre-Browse* `Edit` value and `:59855` mutates it via `Trimmer(..., "\")`.
   - When the user picks `SelectedDir`, `:59864` updates **only** the GUI control (`GuiControl, SettingsGUIA:, UsrEditFileDestination, % SelectedDir`), leaving the super-global `UsrEditFileDestination` holding the *old* pre-Browse value! If the user then toggles Dark Mode / Large Fonts or cancels and reopens via `F8`, `SelectedDir` is lost.

---

## 17. Missing settings persistence, clobbered `UsrCopyMoveOperation`, omitted `RecentCopyMoveManager`, and input wipe on Dark Mode / Large Fonts toggle

**Where:** `:347`, `:398`, `PanelStructuredCopyMoveWindow()` (`:60758`, `:60779`), `BTNuiProceedStructuredOperation()` (`:60804`), `copyMoveStructuredFolders()` (`:3380–3403`), `ToggleLargeUIfonts()` (`:73150–73155`), and `ToggleDarkModus()` (`:73205–73210`).

1. **`userCopyMoveStructuredConflictMode` is never persisted across restarts:**
   Declared at `:347` (`userCopyMoveStructuredConflictMode := 4`), it has **zero** `INIaction()` or `RegAction()` calls anywhere in QPV, so every restart resets it to `Ask user` (`4`).
2. **`UsrCopyMoveOperation` is clobbered to `1` (`Choose...`) on every panel open (`:60758`):**
   Not only must the user re-select `Copy file(s)` or `Move file(s)` every single time they open `PanelStructuredCopyMoveWindow`, `:60758` also mutates the shared global `UsrCopyMoveOperation` even if the user immediately clicks `C&ancel`.
3. **Structured destinations are never recorded in `prevFileMovePath` or `RecentCopyMoveManager(finalDest)`:**
   Unlike `BtnCopyMoveAction` (`:61099`) and `QuickMoveFile2Dest` (`:61308–61309`), `copyMoveStructuredFolders` never updates `prevFileMovePath` or `RecentCopyMoveManager(finalDest)` — even though `BtnCpyMvStrctrdChooseFilesDst()` (`:59859`) explicitly falls back to `prevFileMovePath`!
4. **Toggling `Use dark mode` or `Use large fonts` from the panel's right-click menu wipes all user edits:**
   `SettingsGUIAGuiContextMenu` → `invokePrefsPanelsContextMenu()` (`:27292`) offers `Use dark mode` (`ToggleDarkModus` `:73209`) and `Use large fonts` (`ToggleLargeUIfonts` `:73154`). Both call `BtnCloseWindow()` followed by `openPreviousPanel("forced")` without reading the panel's controls first, resetting `Source:`, `Destination:`, `Conflict mode`, and `Action to perform:`!

---

## 18. `Source:` pre-fill (`OutDir`) uses `currentFileIndex` even when unselected, soft-deleted, in a leaf subfolder, at a drive root, or virtual

**Where:** `PanelStructuredCopyMoveWindow()` (`:60759`).

```ahk
zPlitPath(getIDimage(currentFileIndex), 1, OldOutFileName, OutDir, OutFileNameNoExt, OutFileExt)
```
`OutDir` (used to pre-fill `Source:` at `:60769`) is derived solely from `currentFileIndex`, without checking `resultedFilesList[currentFileIndex, 2]`:

1. **Unselected `currentFileIndex` in another existing folder:** Select 20 files in `D:\TripA\...`, move focus (without selecting) to `E:\Other\x.jpg`, and open the panel. `Source:` pre-fills `E:\Other`, which passes `FolderExist(fS)` and **silently skips all 20 selected files** (`0 out of 20`).
2. **Focused file in a deep leaf subfolder:** Select `c:\temp\imgs\imgA.png` and `c:\temp\imgs\new\img01.jpg` while `currentFileIndex` is on `img01.jpg`. `Source:` pre-fills `c:\temp\imgs\new`, silently skipping `imgA.png` unless edited.
3. **Drive-root file (`C:\a.jpg`):** `zPlitPath` returns `OutDir = "C:"` (no backslash). On Windows, `FileExist("C:")` queries the **process current directory on drive `C:`** (`%A_ScriptDir%` when QPV runs from `C:`), and `:3262` (`"C:\"`) happens to work only if `C:` exists, whereas if `C:`'s CWD were invalid or `dS = "D:"` (`StrLen = 2 <= 4`), behavior is inconsistent with `D:\`.
4. **Soft-deleted (`"||"`) or virtual clipboard/memory item (`Q:\Temporary Memory Object\...`):** If `currentFileIndex` was soft-deleted in `.SLDB` or is an unsaved memory bitmap, `Source:` is pre-filled with a mangled `"||"` directory or non-existent `"Q:\Temporary Memory Object"`.

---

## 19. `!FileExist(file2rem)` runs before `!InStr(file2rem, srcDir "\")` in `copyMoveStructuredFolders`

**Where:** `copyMoveStructuredFolders()` (`:3256–3266`).

```ahk
If !FileExist(file2rem)
{
   failedFiles++
   Continue
}

If !InStr(file2rem, srcDir "\")
{
   skippedFiles++
   Continue
}
```
Checking `!FileExist(file2rem)` *before* checking whether `file2rem` is even inside `srcDir` causes two problems in multi-folder `.SLD` / `.SLDB` galleries:
1. **Multi-second UI freezes on disconnected network shares / spun-down drives:** Selected files on an offline NAS or unmounted drive outside `srcDir` should be instantaneously skipped by string prefix, yet `FileExist(file2rem)` hits Win32 SMB timeouts on every single one.
2. **Wrong `failedFiles` vs `skippedFiles` accounting:** Any missing, soft-deleted (`"||"`), or virtual (`Q:\Temporary Memory Object\...`) selected entry outside `srcDir` is reported as `"Failed to perform action on N files"` instead of `"Skipped files: N"`.

---

## 20. Valid 4-character non-existent destination paths (`D:\a`) are falsely rejected

**Where:** `BTNuiProceedStructuredOperation()` (`:60822–60838`).

```ahk
If !FolderExist(dS)
{
   If (StrLen(dS)>4)
   {
      msgResult := msgBoxWrapper(..., "The destination folder seems to not exist.`n`n" dS "\`n`nWould you like to create it now?", 4, 0, "question")
      ...
   } Else
      Return msgBeepTimer("ERROR: Please choose an existing destination folder.")
}
```
A 1-character folder on a drive root — such as `D:\a` or `E:\1` — has `StrLen("D:\a") = 4`. Because `:60824` checks strict `> 4` instead of `>= 4` (paired with drive-prefix validation), `D:\a` is rejected with `"ERROR: Please choose an existing destination folder."` while `D:\ab` (`StrLen = 5`) offers folder creation!

---

## 21. Raw hex HWND (`zh`) is displayed as the hover tooltip on `"Action to perform:"`

**Where:** `PanelStructuredCopyMoveWindow()` (`:60779–60781`) and `GuiAddDropDownList()` (`:26604–26613`).

```ahk
; quick-picto-viewer.ahk:60779-60781
zh := GuiAddDropDownList("x+5 w" thisW " vuserCopyMoveStructuredConflictMode AltSubmit", "Skip files`nAuto-rename`nOverwrite`nAsk user", [hTempu])
Gui, Add, Text, xs y+10 hp +0x200 +hwndhTemp, Action to perform:
GuiAddDropDownList("xp yp w" thisW " vUsrCopyMoveOperation AltSubmit", "Choose...`nMove file(s)`nCopy file(s)", [hTemp, hTempu, zh])
```
`zh` is the HWND of the conflict `DropDownList` returned by `:60779` (passed in `[hTemp, hTempu, zh]` so `GuiAddDropDownList` aligns the second dropdown's X coordinate with `zh` at `:26576–26586`). However, `:60781` omits the 4th parameter (`tipu`), and `GuiAddDropDownList` ends with:
```ahk
; quick-picto-viewer.ahk:26604-26612
If IsObject(labelu)
{
   If labelu[3]
      labelu := labelu[3]
}
...
tipu := tipu ? tipu : labelu
ToolTip2ctrl(hTemp, tipu)
```
`labelu` is overwritten with `zh` (e.g. `0x1909ca`), and `ToolTip2ctrl` registers that raw hexadecimal handle string as the hover tooltip of `"Action to perform:"`!

---

## 22. `BtnIdentifyFileRoots` / `Menu, Manna` UI bugs: stuck `"Please wait..."` tooltip, unescaped `&`, lowercased paths, cursor-positioned keyboard popup, and unstyled menu

**Where:** `BtnIdentifyFileRoots()` (`:60109–60132`), `menuSetSourceStructuredOper()` (`:60134–60144`), and `IdentifyFileFolderRoots()` (`:60166`).

1. **`"Please wait..."` ToolTip #1 stays stuck onscreen while the menu is open (`:60110`, `:60130–60131`):**
   `ToolTip, Please wait...` is shown at `:60110`, and `ToolTip` (clear) is placed at `:60131` *after* `Try Menu, Manna, Show` (`:60130`). Because Win32 `TrackPopupMenu` is modal and blocks `:60130` until the user clicks an item or dismisses the menu, `"Please wait..."` stays hovering next to the cursor on top of the open menu the entire time! (It also uses ToolTip #1 instead of ToolTip #2 used at `:60757`.)
2. **Unescaped `&` in folder names (`:60121–60122`):**
   `Menu, Manna, Add, % A_Index ". " thisItem "\"` passes `PathCompact(A_LoopField, 35)` without `StrReplace(..., "&", "&&")` (contrast `ShellFileDialog` at `lib/shell-stuff.ahk:187`). A path like `c:\r&d\imgs` renders as `1. c:\r_d\imgs\` with `d` underlined as a menu mnemonic!
3. **All-lowercase path written into `Source:` (`:60142`, `:60166`):**
   `IdentifyFileFolderRoots` converts `OutDir` via `Format("{:L}", OutDir)` (`:60166`), and `menuSetSourceStructuredOper` writes that lowercased string directly into `UsrEditFileSource` (`:60142`), losing true filesystem casing (and triggering **#7** on non-ASCII characters).
4. **Menu opens at mouse cursor on keyboard activation and ignores dark-mode styling (`:60130`):**
   Using raw `Menu, Manna, Show` (`CoordMode, Menu, Screen` `:68`) instead of `kMenu` / `showThisMenu(..., "hwnd", buttonHwnd)` (`:71109–71118`) pops up an unstyled light-mode Win32 menu at the mouse cursor — even on another monitor — when the user focuses `"Possible source paths"` via `Tab` and presses `Space`.

---

## 23. Right-clicking `Source:` or `Destination:` `Edit` boxes blocks Windows' native Cut/Copy/Paste context menu

**Where:** `SettingsGUIAGuiContextMenu` (`:25922–25945`) and `SettingsToolTips()` (`:27378–27504`).

Because `SettingsGUIAGuiContextMenu:` is defined on `SettingsGUIA`, AutoHotkey intercepts `WM_CONTEXTMENU` (right-click and `AppsKey` / `Shift+F10`) on every control in `SettingsGUIA`, including `Edit` controls (`:25937`). Instead of allowing Win32's standard `Undo | Cut | Copy | Paste | Delete | Select All` `Edit` menu on `Source:` and `Destination:`, `SettingsToolTips()` displays a debug-style OSD tooltip (`"<value> = UsrEditFileSource\n[Edit field]"`) exposing internal variable names and preventing mouse-driven paste!

---

## 24. Close dead-zones (`Escape` / `X`), broken `F1` help, `Up`/`Down` digit mutation in path `Edit`s, and unguarded `:` Quick Search hotkey

**Where:** `SettingsGUIAGuiClose` / `Escape` (`:4321–4324`), `CloseWindow()` (`:97971`), `openFoldersDialogWrapper()` (`:64359`), `msgBoxWrapper()` (`:33311`), `KeyboardResponder()` (`:768–884`), `ShowContextualHelp()` (`:89688–89718`), and `processDefaultKbdCombos()` (`:1035–1040`).

1. **1,000 ms `Escape` / titlebar `X` / context-menu `&Close panel` dead zone after sub-dialogs (`:97971`) + 450 ms after open (`:4323`):**
   Closing `&Browse` (`:64359`) or `&Help` / any `msgBoxWrapper` (`:33311`) sets `lastLongOperationAbort := A_TickCount`. Pressing `Escape`, clicking `X`, or choosing right-click `&Close panel` (`:27315`) calls `CloseWindow()` with `forceIT = 0`, which aborts at `If ((A_TickCount - lastLongOperationAbort < 1000) && !forceIT) Return 1` (`:97971`)! Similarly, `:4323` ignores `Escape` and `X` for 450 ms after opening the panel, whereas clicking `C&ancel` (`BtnCloseWindow` → `CloseWindow(1)`) works immediately.
2. **`F1` does nothing inside the panel and shows the wrong help from `PVhwnd` (`:768–884`, `:89688–89697`):**
   - When `SettingsGUIA` is focused (`thisWin = "parentu"`), `KeyboardResponder()` (`:768–884`) has no `F1` branch, so pressing `F1` does nothing at all.
   - When `PVhwnd` is focused with `thumbsDisplaying = 1` and `AnyWindowOpen = 77`, `ShowContextualHelp()` checks `If (thumbsDisplaying=1)` (`:89688`) *before* `Else If (AnyWindowOpen>0)` (`:89692`), showing thumbnail shortcuts instead of `BtnHelpStructuredCopyMove()` (and even `:89692` shows generic panel help rather than `BtnHelpStructuredCopyMove()`).
3. **`Up` / `Down` arrow keys mutate numeric folder names inside `Source:` and `Destination:` (`:853–857`):**
   In `KeyboardResponder()` (`:853–857`), pressing `Up` or `Down` inside any `Edit` on `SettingsGUIA` calls `editFieldSetNewVal()`, which increments or decrements numbers when the text is numeric or matches its numeric parser — unexpected inside file-path `Edit` controls.
4. **`:` (`COLON`) hotkey opens Quick Search on top of the panel (`:1035–1037`, `:42027`):**
   Clicking modeless `PVhwnd` and pressing `:` invokes `PanelQuickSearchMenuOptions` without checking `!AnyWindowOpen` or `HKifs(...)`, opening Quick Search concurrently alongside `PanelStructuredCopyMoveWindow` (and `;` / `+COLON` at `:1038` similarly calls `invokeOmniBoxCurrentFile` without an `HKifs` check at `:1039`).

---

## 25. `userPrivateMode = 1` is ignored across all Structured Copy/Move UI, menus, dialogs, and OSD tooltips

**Where:** `PanelStructuredCopyMoveWindow()` (`:60769`, `:60774`), `BtnIdentifyFileRoots()` (`:60121`), `BtnCpyMvStrctrdChooseFilesDst`/`Src` (`:59850–59885`), `copyMoveStructuredFolders()` (`:3279`, `:3300`, `:3389–3398`).

Compare `ToggleImgFavourites()` (`:39100–39104`) and `friendlyFileUndoInfos()` (`:95102–95103`), which mask paths as `*:\******\*****` when `userPrivateMode = 1`. In Structured Copy/Move, `userPrivateMode` is never checked: full folder and file paths are displayed in plain text in `Source:`, `Destination:`, the `Manna` popup menu, conflict dialogs (`askAboutFileCollision` `:43629–43635`), and progress/completion OSD tooltips (`:3279`, `:3389–3398`).

---

## 26. Uninitialized `%infoSelection%`, duplicate O(N) `getSelectedFiles(0, 1)`, `"This panels"` typo, `prevuDir` cache miss, and `watchFolderDetails` reset on Copy

**Where:** `PanelStructuredCopyMoveWindow()` (`:60763`, `:60767`, `:60782–60783`, `:60792`) and `copyMoveStructuredFolders()` (`:3285–3296`, `:3380`).

1. **`%infoSelection%` used before assignment + duplicate `getSelectedFiles(0, 1)` + grammar typo (`:60763–60783`):**
   - `:60763` calls `getSelectedFiles(0, 1)` (an O(`maxFilesIndex`) scan), and `:60782` calls `getSelectedFiles(0, 1)` a **second time** 19 lines later.
   - `:60767` interpolates `%infoSelection%This panels allows users...` while `infoSelection` is still `""` because `infoSelection := "Selected files: " groupDigits(markedSelectFile) ". "` was moved down to `:60783` (used at `:60792`).
   - `:60767` contains a typo: `"This panels allows"` → `"This panel allows"`.
2. **`prevuDir` cache never updated when `OutDir` already exists (`:3285–3296`):**
   ```ahk
   If (prevuDir!=OutDir)
   {
      If !FolderExist(OutDir)
      {
         FileCreateDir, % OutDir
         If ErrorLevel
         {
            failedFiles++
            Continue
         } Else prevuDir := OutDir
      }
   }
   ```
   Because `prevuDir := OutDir` sits inside `If !FolderExist(OutDir)`, whenever `OutDir` **already exists** on disk `prevuDir` remains `""` (or the previous newly created dir), causing `FolderExist(OutDir)` to hit the filesystem on every single file in existing folders instead of caching `prevuDir := OutDir`.
3. **`watchFolderDetails := ""` cleared even on Copy (`:3380` vs `:4784`):**
   Copying files to an external destination never modifies the currently opened source folder (`CurrentSLD`), yet `:3380` unconditionally clears `watchFolderDetails := ""`, suppressing the next external folder-change check (`:4784–4794`).

---

## 27. Scope leak (`Global ... lastInvoked := 1`), layout misalignment, cramped `&Proceed` enabled on `"Choose..."`, missing mnemonics, and dead locals

**Where:** `PanelStructuredCopyMoveWindow()` (`:60737`, `:60743–60755`, `:60766`, `:60768`, `:60773`, `:60781`, `:60786–60792`), `InvokeMenuBarFile()` (`:67431`), and `createMenuCurrentFilesActs()` (`:69548`).

1. **Accidental `Global ... lastInvoked := 1` (`:60737`):**
   `Global BtnCpyMv, UsrEditFileSource, lastInvoked := 1` declares `lastInvoked` as **global** (instead of `Static`, unlike `:3209` `Static lastInvoked := 1`), creating/overwriting global `lastInvoked := 1` on every call while never reading it.
2. **Vertical misalignment on `Source:` label (`:60768` vs `:60773`, `:60778`, `:60780`) & missing `+BackgroundTrans`:**
   `:60768` (`Gui, Add, Text, xs y+10 w%ml%, Source: `) omits `h%thisBtnHeight%` / `hp` and `+0x200` (`SS_CENTERIMAGE`), so `"Source:"` is top-aligned while `"Destination:"` (`:60773`, `hp +0x200`) is vertically centered; none of the `Text` controls specify `+BackgroundTrans` (unlike `CopyMovePanelWindow` `:60081`, `:60097`, `:60100`).
3. **`&Proceed` cramped (`60px`) and stays enabled while `"Choose..."` (`1`) is selected (`:60745`, `:60781`, `:60789`):**
   - When `PrefsLargeFonts = 0`, `btnWid2 := 60` makes `&Proceed` narrower than `&Help` (`72`) and `C&ancel` (`72`), cramping `"Proceed"` with custom padding/DPI.
   - `:60737` declares `Global BtnCpyMv` and `:60789` binds `vBtnCpyMv`, clearly intending to hook `gchangeCopyMoveAction` (like `CopyMovePanelWindow` `:60098`, `:60876–60877`), yet `:60781` omits any `g`-label (note: `changeCopyMoveAction` `:60875` also rewrites the window title to `"%btnName% file(s) to..."`, so sharing it directly without checking `AnyWindowOpen = 77` would clobber `"Structured file operations"`'s title!). As a result, `&Proceed` starts enabled as the `Default` button (`Enter`) when `UsrCopyMoveOperation = 1` (`"Choose..."`), guaranteed to error out at `:60807`.
4. **Missing `&` mnemonics:**
   `"Structured file operations"` has no `&` accelerator in either `pvMenuBarFile` (`:67431`) or `PVfilesActs` (`:69548`), and none of the four panel labels (`Source:`, `Destination:`, `On file name conflicts:`, `Action to perform:`) define `&` mnemonics to focus their paired inputs.
5. **Dead local variables (`:60743–60755`, `:60766`, `:60786`):**
   `sml` is assigned three times (`:60743`, `:60766`, `:60786`) before first use at `:60789`, and `btnWid`, `txtWid`, and `lstWid` (`:60744–60755`) are never referenced.

---

## 28. Folder Browse dialog quirks, spurious `ResetImgLoadStatus` timer, and `HIMAGELIST` leak on panel close

**Where:** `BtnCpyMvStrctrdChooseFilesDst()` (`:59849–59867`), `BtnCpyMvStrctrdChooseFilesSrc()` (`:59869–59887`), `openFoldersDialogWrapper()` (`:64353–64361`), `PanelStructuredCopyMoveWindow()` (`:60787`), `CloseWindow()` (`:97990–97991`, `:98071`), and `trackImageListButtons()` (`:26742`).

1. **Both `&Browse` and `B&rowse` open identical generic `"Select Folder"` dialogs (`:59861`, `:59881`):**
   Both call `openFoldersDialogWrapper(p)` with `msg = ""`, giving the user no window-title cue whether they are picking the **Source** root or **Destination** root. Neither normalizes `/` → `\` before `Trimmer(..., "\")`, both omit `Gui, SettingsGUIA: Default` before `GuiControlGet`, and `:59866` / `:59886` only call `WinActivate, ahk_id %hSetWinGui%` on cancel (`Else`), leaving `SettingsGUIA` unfocused after selecting a folder on the `FileSelectFolder` fallback path (`lib/shell-stuff.ahk:48`).
2. **Spurious `SetTimer, ResetImgLoadStatus, -50` (`:60787`):**
   Copied from `CopyMovePanelWindow` (`:60016` / `:60095`), `PanelStructuredCopyMoveWindow` never calls `setImageLoading()`, so firing `ResetImgLoadStatus` 50 ms after panel open can prematurely clear `imageLoading := 0` on an unrelated asynchronous load.
3. **`HIMAGELIST` leak on `SettingsGUIA` close when `ShowAdvToolbar != 1` (`:97990–97991` vs `:98071`):**
   `GuiAddButton` (`:60772`, `"Possible source paths"`) registers a 5-state button `HIMAGELIST` tagged `"SettingsGUIA"` in `trackImageListButtons("record", ...)`. Inside `CloseWindow()`, `trackImageListButtons("kill")` runs at `:97991` while `AnyWindowOpen` is still `77` (reset to `0` later at `:98071`). Inside `trackImageListButtons` (`:26742`), `If (AnyWindowOpen && Value[3]="SettingsGUIA") Continue` skips `ImageList_Destroy`, leaking the `HIMAGELIST` until a later `"kill"` call happens while `AnyWindowOpen = 0`.

---

## Seen in passing

These bugs live in shared helpers audited while tracing `PanelStructuredCopyMoveWindow()` and affect other QPV features as well:

- **`recordUndoFileActs()` (`:95033`) drops `"|" originalFileInfos` for `actu = 2` (all Moves/Renames):** affects `QuickMoveFile2Dest()` (`:61214`) and `batchCopyMoveFile()` (`:61472`) identically — batch Undo (`batchUndoFileActs` `:94858`) can **never** recover any file overwritten by a Move anywhere in QPV.
- **`GuiAddDropDownList()` (`:26604–26613`) raw HWND tooltip when `labelu` is a 3-element array and `tipu` is omitted:** also affects `CopyMovePanelWindow()` (`:60098`), showing raw hex `zh` on its `"Action to perform:"` dropdown.
- **`FileRexists(file, 0)` (`:32672`) returning `0` on valid 0-byte files:** also affects `QuickMoveFile2Dest()` (`:61183`), `batchCopyMoveFile()` (`:61439`), and `batchUndoFileActs()` (`:94825`, `:94882`).
- **`zPlitPath()` (`:59906–59928`) stripping leading `\\`:** breaks `OutDir` extraction for UNC paths across any caller relying on `zPlitPath` for network paths.
- **`CloseWindow()` (`:97990–97991` vs `:98071`) `trackImageListButtons("kill")` ordering:** affects every `SettingsGUIA` panel containing `GuiAddButton` icon buttons whenever `ShowAdvToolbar != 1`.

---

## Checked and found correct

- **`askAboutFileCollision` state reset before batch (`:3228`):** `copyMoveStructuredFolders` properly calls `askAboutFileCollision(0, 0, 1, 3, 0, nullvar)` at `:3228` to clear any sticky `"Do not prompt again"` choice (`useLastOption` / `lastOption`) from prior batches, and passes `allowSkip = 1` at `:3300` so `"Do not prompt again"` works across subsequent conflicts within the same structured run.
- **ASCII case-insensitive path matching and replacement (`:3262`, `:3283`, `:60840`):** for pure ASCII drive letters and folder names (`C:\Temp\Imgs` vs `c:\temp\imgs`), AHK's default `StringCaseSense, Off` matches `InStr` and `StrReplace` case-insensitively and preserves the relative tail's original filesystem casing after `finalDest "\"`.
- **`.SLDB` transaction commit on user abort (`:3235`, `:3249–3253`, `:3358`, `:3371`):** when the user aborts mid-batch (`Escape` or `Cancel` on a conflict), committing the SQLite transaction (`COMMIT TRANSACTION;`) is intentional and keeps `.SLDB` synchronized with the files that were already physically moved and updated in `resultedFilesList` during iterations `1..k-1`.
- **Alt-key button mnemonics inside the panel (`:60771`, `:60776`, `:60789–60791`):** `&Browse` (`Alt+B`), `B&rowse` (`Alt+R`), `&Proceed` (`Alt+P`), `&Help` (`Alt+H`), and `C&ancel` (`Alt+A`) have five distinct letters with no internal mnemonic collision.
- **`menuSetSourceStructuredOper(menuItem)` index extraction (`:60135`):** `SubStr(menuItem, 1, InStr(menuItem, ".") - 1)` parses the leading `1..10` index before the first `.`, so `...` ellipses inserted by `PathCompact(A_LoopField, 35)` do not corrupt item lookup.
- **`GuiAddDropDownList` horizontal alignment (`:60781` → `:26576–26586`):** although `:60781` initially creates the `"Action to perform:"` dropdown at `xp yp` on top of its `Text` label, `GuiAddDropDownList` reads `zh`'s placement via `GetWindowPlacement` and shifts the second dropdown to align with the conflict dropdown's left edge via `SetWindowPlacement`.
- **`Ctrl+Backspace` word deletion in `Source:` and `Destination:` (`:60769`, `:60774` → `UIeditsGenericAllowCtrlBksp` `:46726` → `allowCtrlBkspEdit` `:60880–60936`):** `0x7F` (`DEL`) interception and `EM_SETSEL` cursor placement accurately delete path segments back to `\`, `/`, `-`, `.`, or space (only side effect: `ControlSetText` at `:60930` clears the single-level Win32 `Edit` `Ctrl+Z` undo buffer).
- **Timestamp preservation (`:3269–3270`, `:3342–3347`):** `originalMtime` and `originalCtime` are read from `file2rem` before moving/copying and applied to `file2save` via `FileSetTime`, and `updateDates := 0` avoids unnecessary timestamp re-queries in `updateSQLdbEntry`.

---

## Decisions to make before fixing

1. **Separate destination variable vs shared `UsrEditFileDestination` (#16, #17):**
   Should `PanelStructuredCopyMoveWindow` have its own persisted `UsrEditStructuredDestination` (and `UsrEditStructuredSource`?) in `preferences.ini` so `[group-by-...]` / `.\` patterns from `CopyMovePanelWindow` never pollute it, while still pushing confirmed structured destinations into `RecentCopyMoveManager(finalDest)` and `prevFileMovePath`?
2. **Persisting `userCopyMoveStructuredConflictMode` and `UsrCopyMoveOperation` (#17, #27):**
   Should `userCopyMoveStructuredConflictMode` be saved via `INIaction` in `preferences.ini`? And should `Action to perform:` remember the last structured action (Copy vs Move) or intentionally always start on `"Choose..."` with `&Proceed` disabled until `2` or `3` is chosen?
3. **Intended root-finding algorithm for `IdentifyFileFolderRoots()` (#11, #12):**
   Should `"Possible source paths"` compute:
   - the **Longest Common Directory Prefix (LCA)** of all selected files first (so selecting `c:\temp\imgs\imgA.png` + `c:\temp\imgs\new\img01.jpg` offers `c:\temp\imgs\`, and selecting files in `C:\imgs\` offers `C:\imgs\` rather than a dead button), followed by distinct per-drive/per-branch top-level selected directories (e.g. `c:\temp\` when `c:\temp\CRW0292303.tga` is also selected)?
4. **Overlapping `Source` and `Destination` trees (#2):**
   When `Destination` is a subfolder inside `Source` (`C:\Photos` → `C:\Photos\Backup`) or `Source` is a subfolder inside `Destination` (`C:\Photos\Backup` → `C:\Photos`), should `BTNuiProceedStructuredOperation` **block** the operation outright with a clear error message (safest), or allow `Destination` inside `Source` while automatically excluding selected files already under `Destination`?
5. **UNC network paths (`\\server\share\...`) and drive roots (`C:\`) (#5, #6, #18):**
   Should Structured Copy/Move support both standard drive paths (`X:\...`, including bare drive roots `X:\`) and UNC share roots (`\\server\share\...`), resolved via Win32 `GetFullPathNameW` so `.`, `..`, `/`, `\\`, and trailing spaces/slashes are canonicalized in one step?
6. **Unsaved image edits on Structured Move (#4):**
   When `currentImgModified = 1` and the edited image is among the files being **moved** (not copied), should QPV prompt `askAboutFileSave()` before starting the batch, or update the active editor session's path/caches (`updateViewportCachesID` + `prevImgPath`) so unsaved pixel edits stay intact at the new path?
