# Repeated code in quick-picto-viewer.ahk

Snapshot of 2026-10-28, commit 6b6a6e2 on `development`. It covers the 2,554 functions of `quick-picto-viewer.ahk` (85,290 code lines); the code outside functions is not included.

**153 blocks** of code repeat in at least three functions each, **1,231 copies** in all. Moving each block into a new function would remove about **2,870 lines**, 3.4% of the code lines in functions.

53 blocks are exact copies and 100 are near-copies. 42 have a note: a jump has to stay in the caller, or `A_ThisFunc` or a loop variable has to be passed in.

## How to read the entries

- **Copy**: one place where a block appears. A function can hold more than one copy. Each copy is listed by the line where it starts.
- **Lines**: code lines in one copy, not counting blank lines and comment-only lines.
- **Exact copies**: the same code in every copy. Only spacing, comments, letter case and the optional comma after a command name differ (AutoHotkey names are not case-sensitive).
- **Near-copies**: the same code except for 1 to 3 changing values (variable names, numbers or strings) that would become parameters of the new function. At least one line is identical in every copy, and when 2 or 3 values change they make up at most a quarter of the block's names and values. This keeps out lists such as three `INIaction()` calls with different setting names.
- **Labels**: each entry is named by the first lines of its block, as they read in the first copy. ⏎ separates the lines, … means more lines follow, and ‹1›, ‹2›, ‹3› mark the values that change between near-copies.
- **Saves**: the estimated net saving in lines: copies × lines, minus the new function (its lines + 2), minus one call line per copy (two where a `Break`, `Continue` or `Return` must stay in the caller).
- **Notes**:
  - *ends with Return*: the call can be written as `Return newFunc()`.
  - *Break inside* (also *Continue*, *Return*): the jump must stay in the caller, as `If newFunc()` followed by the jump on the next line.
  - *A_ThisFunc*: in a new function, `A_ThisFunc` holds the new function's name, so the caller's name has to be passed in.
  - *loop variable*: the block reads `A_Index` or `A_LoopField` of a loop outside it; pass the value in.
- **Contains #N**: copies of entry N sit inside this block. Their lines are counted once, under entry N.
- **Related #N**: the same code, possibly with other names or values, is part of entry N, or entry N is part of this one. One function could serve both.

A block is listed only when its braces balance and it does not start or end inside an `If`, `Else`, `Loop` or `Try`, so it can be moved out whole. Each source line belongs to one entry: blocks were taken in order of saving, and a copy that partly overlapped an earlier block was dropped. So the savings of different entries add up.

## Patterns spanning several entries

The entries of each group repeat the same calls, so one or two shared functions could shorten all of them.

| Pattern | Entries | Copies | Saves |
|---|---|---:|---:|
| Message tooltip with an error beep: `SoundBeep` and `SetTimer, RemoveTooltip`, usually after `showTOOLtip()` and often before `Return` | #1, #3, #5, #13, #15, #30, #45, #48, #54, #61, #78, #88, #98, #123, #147 | 305 | 700 |
| Abort check inside loops: `If (determineTerminateOperation()=1)` that sets `abandonAll` and breaks | #2, #22, #38, #122 | 103 | 289 |
| Wider controls for large fonts: width additions followed by `Gui, Font, s%LargeUIfontValue%` | #4, #8, #16, #31, #80, #82, #108, #133 | 117 | 229 |
| qpvmain.dll checks: `initQPVmainDLL()` and `If !qpvMainDll` with a journal entry and `Return` | #9, #32, #36, #46, #64, #110, #121, #132 | 40 | 131 |
| Saving over an existing file: overwrite, temporary-file and file-time handling around `file2save` | #6, #26, #42, #71, #85, #140, #141, #145 | 28 | 136 |

## Overview

Ordered by saving. Kind: *exact* copies, or *near*-copies followed by the number of changing values.

| # | Lines | Copies | Functions | Kind | Saves | Notes | Starts with |
|---:|---:|---:|---:|---|---:|---|---|
| 1 | 4 | 115 | 86 | near, 1 | 339 | ends with Return | `showTOOLtip(‹1›)` |
| 2 | 5 | 82 | 71 | exact | 239 | Break inside | `If (determineTerminateOperation()=1)` |
| 3 | 3 | 57 | 46 | near, 2 | 109 |  | `showTOOLtip(‹1›)` |
| 4 | 3 | 53 | 53 | near, 2 | 101 |  | `btnWid := btnWid + ‹1›` |
| 5 | 3 | 37 | 26 | exact | 69 | ends with Return | `SoundBeep, 300, 100` |
| 6 | 34 | 3 | 3 | near, 1 | 60 | Break/Continue inside | `If !file2save` |
| 7 | 4 | 20 | 20 | near, 3 | 54 | A_ThisFunc | `INIaction(1, ‹1›, "General")` |
| 8 | 7 | 14 | 14 | near, 3 | 49 |  | `If (PrefsLargeFonts=1)` |
| 9 | 8 | 9 | 9 | near, 2 | 44 | Return inside, A_ThisFunc | `initQPVmainDLL()` |
| 10 | 6 | 12 | 12 | near, 2 | 40 | Return inside | `If askAboutFileSave(‹1›)` |
| 11 | 4 | 15 | 4 | near, 3 | 39 |  | `For Key, Value in ‹1›` |
| 12 | 3 | 20 | 20 | exact | 35 |  | `uiPopulateCachesOverview("kill")` |
| 13 | 10 | 5 | 5 | near, 3 | 33 |  | `If (StrLen(textu)>‹1›)` |
| 14 | 4 | 12 | 12 | exact | 30 |  | `nImgSelX1 := min(imgSelX1, imgSelX2)` |
| 15 | 4 | 12 | 9 | near, 2 | 30 | ends with Return | `SoundBeep , 300, 100` |
| 16 | 4 | 32 | 32 | near, 3 | 28 |  | `EditWid := EditWid + ‹1›` |
| 17 | 16 | 3 | 3 | exact | 27 | A_ThisFunc | `trGdip_GetImageDimensions(plotBMP, imgW, imgH)` |
| 18 | 6 | 7 | 7 | near, 3 | 27 |  | `If validBMP(‹1›)` |
| 19 | 6 | 7 | 3 | near, 1 | 27 | ends with Return | `showTOOLtip("Operation abandoned by user")` |
| 20 | 3 | 16 | 16 | near, 3 | 27 |  | `winPos := (prevSetWinPosY && prevSetWinPosX &&…` |
| 21 | 17 | 3 | 3 | exact | 26 | Return inside, A_ThisFunc | `If !dbIndex` |
| 22 | 11 | 6 | 5 | near, 3 | 26 | Break inside, loop variable | `If (determineTerminateOperation()=1)` |
| 23 | 7 | 7 | 7 | exact | 26 | Return inside, A_ThisFunc | `whichBitmap := validBMP(UserMemBMP) ? UserMemBM…` |
| 24 | 5 | 8 | 7 | near, 1 | 25 |  | `If validBMP(‹1›)` |
| 25 | 5 | 8 | 8 | near, 3 | 25 |  | `Gui, ‹1›: Default` |
| 26 | 9 | 5 | 5 | near, 1 | 24 | Break/Continue inside | `If !‹1›` |
| 27 | 4 | 15 | 15 | near, 2 | 24 | Return inside | `If (AnyWindowOpen!=‹1›)` |
| 28 | 3 | 14 | 14 | exact | 23 |  | `Gui, fdTreeGuia: Default` |
| 29 | 3 | 14 | 3 | exact | 23 |  | `LV_ModifyCol(1, "Integer")` |
| 30 | 9 | 4 | 4 | near, 3 | 21 |  | `ForceRefreshNowThumbsList()` |
| 31 | 9 | 4 | 4 | near, 1 | 21 |  | `If (PrefsLargeFonts=1)` |
| 32 | 7 | 6 | 6 | near, 1 | 21 | Return inside, A_ThisFunc | `If (thumbsDisplaying=1)` |
| 33 | 5 | 7 | 5 | near, 1 | 21 |  | `If ‹1›` |
| 34 | 3 | 13 | 11 | near, 1 | 21 | ends with Return | `showTOOLtip(‹1›)` |
| 35 | 3 | 13 | 10 | near, 2 | 21 |  | `GetMouseCoord2wind(PVhwnd, mX, mY)` |
| 36 | 6 | 7 | 7 | near, 1 | 20 | Return inside, A_ThisFunc | `initQPVmainDLL()` |
| 37 | 13 | 3 | 3 | exact | 18 | Break/Continue inside, loop variable | `If A_LoopField` |
| 38 | 7 | 12 | 12 | exact | 18 | Break/Continue inside, loop variable | `If (resultedFilesList[A_Index, 2]!=1)` |
| 39 | 4 | 8 | 8 | near, 3 | 18 |  | `Gui, SettingsGUIA: Default` |
| 40 | 9 | 4 | 4 | near, 2 | 17 | Return inside, A_ThisFunc | `cornersBMP := trGdip_CreateBitmap(A_ThisFunc, ‹…` |
| 41 | 6 | 5 | 5 | near, 1 | 17 |  | `If (uiUseDarkMode=1)` |
| 42 | 6 | 5 | 5 | near, 1 | 17 |  | `Try FileSetAttrib, -R, % file2save` |
| 43 | 6 | 5 | 5 | near, 2 | 17 |  | `If (AnyWindowOpen=10 && imgEditPanelOpened=1)` |
| 44 | 5 | 6 | 6 | near, 2 | 17 | A_ThisFunc | `If (‹1›=‹2›)` |
| 45 | 3 | 11 | 10 | near, 1 | 17 | ends with Return | `SoundBeep 300, 100` |
| 46 | 12 | 3 | 3 | near, 1 | 16 | Return inside, A_ThisFunc | `initQPVmainDLL()` |
| 47 | 7 | 5 | 5 | exact | 16 | Return inside | `colNum := (AnyWindowOpen=3) ? 3 : 1` |
| 48 | 7 | 11 | 10 | near, 2 | 16 | Return inside | `If !‹1›` |
| 49 | 10 | 3 | 3 | near, 1 | 15 |  | `If (A_TickCount - prevSaveData>300100)` |
| 50 | 4 | 7 | 7 | exact | 15 |  | `Gui, SettingsGUIA: Default` |
| 51 | 4 | 7 | 7 | exact | 15 |  | `tx := (imgSelPx > prevDestPosX) ? prevDestPosX…` |
| 52 | 4 | 7 | 6 | near, 2 | 15 | ends with Return | `If InStr(msgResult, "reopen")` |
| 53 | 11 | 3 | 3 | exact | 14 | Return inside | `If warnHugeImageNotFIM()` |
| 54 | 7 | 10 | 10 | near, 3 | 14 | Return inside | `If (‹1›<‹2›)` |
| 55 | 5 | 5 | 5 | exact | 13 |  | `If !ResizeUseDestDir` |
| 56 | 5 | 5 | 5 | exact | 13 |  | `If (SLDtypeLoaded=3)` |
| 57 | 5 | 5 | 3 | near, 1 | 13 |  | `If pEffect` |
| 58 | 5 | 5 | 5 | near, 1 | 13 |  | `If (icoFile!=initialIcon)` |
| 59 | 5 | 5 | 5 | near, 2 | 13 |  | `Gui, SettingsGUIA: Default` |
| 60 | 3 | 9 | 5 | exact | 13 | ends with Return | `ResetImgLoadStatus()` |
| 61 | 3 | 9 | 9 | near, 1 | 13 |  | `SetTimer, ResetImgLoadStatus, -‹1›` |
| 62 | 10 | 3 | 3 | near, 3 | 12 | Continue inside, loop variable | `r := resultedFilesList[A_Index, 1]` |
| 63 | 6 | 4 | 4 | exact | 12 |  | `columnIndex++` |
| 64 | 6 | 5 | 5 | exact | 12 | Return inside, A_ThisFunc | `initQPVmainDLL()` |
| 65 | 6 | 5 | 5 | near, 1 | 12 | Return inside | `If (‹1›="kill")` |
| 66 | 6 | 5 | 5 | near, 1 | 12 | Break/Continue inside | `RowNumber := LV_GetNext(RowNumber)` |
| 67 | 6 | 4 | 4 | near, 1 | 12 |  | `If (AnyWindowOpen=31 \|\| AnyWindowOpen=24)` |
| 68 | 4 | 6 | 3 | near, 3 | 12 |  | `If (abandonAll=1)` |
| 69 | 4 | 6 | 4 | near, 2 | 12 |  | `If failedFiles` |
| 70 | 4 | 6 | 6 | near, 2 | 12 |  | `‹1› := A_TickCount` |
| 71 | 8 | 3 | 3 | near, 1 | 11 |  | `If (!r && tempFileExists=1) \|\| (!FileRexists(fi…` |
| 72 | 8 | 3 | 3 | near, 3 | 11 |  | `SQL := "SELECT imgfolder FROM dynamicfolders;"` |
| 73 | 5 | 6 | 3 | near, 2 | 11 | Return inside | `If !InStr(msgResult.btn, "Yes")` |
| 74 | 3 | 8 | 8 | exact | 11 |  | `doStartLongOpDance()` |
| 75 | 3 | 8 | 8 | near, 1 | 11 |  | `If AnyWindowOpen` |
| 76 | 3 | 8 | 8 | near, 2 | 11 |  | `GuiAddCloseOnApply("x+5 yp hp wp")` |
| 77 | 9 | 3 | 3 | near, 1 | 10 | Return inside | `If (msgResult="Yes")` |
| 78 | 7 | 8 | 8 | near, 2 | 10 | Return inside | `If (‹1›=1)` |
| 79 | 4 | 8 | 8 | near, 1 | 10 | Return inside, A_ThisFunc | `If !(thisBtnHeight := createSettingsGUI(‹1›, A_…` |
| 80 | 10 | 4 | 4 | exact | 9 |  | `btnWid := 100` |
| 81 | 10 | 3 | 3 | near, 2 | 9 |  | `If (!‹1› \|\| !‹2›)` |
| 82 | 10 | 4 | 4 | near, 3 | 9 |  | `‹1› := ‹2›` |
| 83 | 7 | 3 | 3 | exact | 9 |  | `aC++` |
| 84 | 7 | 4 | 4 | exact | 9 |  | `If (SLDtypeLoaded=3)` |
| 85 | 7 | 3 | 3 | exact | 9 |  | `updateDates := 1` |
| 86 | 7 | 3 | 3 | near, 2 | 9 |  | `etaTime := ETAinfos(countTFilez, filesElected,…` |
| 87 | 7 | 3 | 3 | near, 3 | 9 |  | `startOperation := A_TickCount` |
| 88 | 5 | 4 | 4 | exact | 9 |  | `killQPVscreenImgSection()` |
| 89 | 5 | 4 | 3 | exact | 9 |  | `If (inLoop!=1)` |
| 90 | 5 | 4 | 4 | exact | 9 |  | `If ((AnyWindowOpen=10 \|\| AnyWindowOpen=74) && i…` |
| 91 | 5 | 4 | 4 | exact | 9 |  | `discardSRCfileCaches()` |
| 92 | 5 | 4 | 4 | near, 3 | 9 |  | `etaTime := ETAinfos(countTFilez, ‹1›, startOper…` |
| 93 | 5 | 4 | 4 | near, 1 | 9 |  | `If validBMP(‹1›)` |
| 94 | 5 | 4 | 4 | near, 1 | 9 |  | `Gui, SettingsGUIA: Default` |
| 95 | 4 | 5 | 4 | near, 1 | 9 |  | `If (thumbsDisplaying=1)` |
| 96 | 4 | 5 | 3 | near, 3 | 9 |  | `LV_ModifyCol(1, "Integer")` |
| 97 | 4 | 5 | 3 | near, 1 | 9 |  | `If (dir=1)` |
| 98 | 3 | 7 | 6 | exact | 9 |  | `SoundBeep , 300, 100` |
| 99 | 3 | 7 | 6 | exact | 9 | ends with Return | `SetTimer, RemoveTooltip, % -msgDisplayTime` |
| 100 | 3 | 7 | 7 | near, 1 | 9 |  | `RegAction(1, ‹1›)` |
| 101 | 3 | 7 | 7 | near, 1 | 9 |  | `prevMSGdisplay := A_TickCount` |
| 102 | 8 | 3 | 3 | exact | 8 | Return inside, A_ThisFunc | `thisStartZeit := A_TickCount` |
| 103 | 5 | 5 | 4 | near, 1 | 8 | Continue inside | `If !validBMP(‹1›)` |
| 104 | 6 | 3 | 3 | exact | 7 |  | `If (EllipseSelectMode=1)` |
| 105 | 6 | 3 | 3 | exact | 7 |  | `GuiControlGet, closeEditPanelOnApply, SettingsG…` |
| 106 | 6 | 3 | 3 | exact | 7 |  | `Gdip_GetImageDimensions(pBitmap, w, h)` |
| 107 | 6 | 3 | 3 | exact | 7 |  | `thisu := max(maxValu, valu)` |
| 108 | 6 | 3 | 3 | exact | 7 |  | `Gui, Add, Text, x20 y20 w%gW% h%gH% Section -Bo…` |
| 109 | 6 | 3 | 3 | near, 1 | 7 |  | `If (‹1›=3)` |
| 110 | 6 | 3 | 3 | near, 1 | 7 |  | `initQPVmainDLL()` |
| 111 | 6 | 3 | 3 | near, 2 | 7 |  | `SelectedDir := openFoldersDialogWrapper(‹1›)` |
| 112 | 6 | 3 | 3 | near, 3 | 7 |  | `If (FillAreaCurveTension=1)` |
| 113 | 6 | 3 | 3 | near, 1 | 7 |  | `showTOOLtip(‹1›)` |
| 114 | 6 | 3 | 3 | near, 1 | 7 |  | `Try Run, "%folderPath%"` |
| 115 | 3 | 6 | 6 | exact | 7 |  | `vpWinClientSize(mainWidth, mainHeight)` |
| 116 | 3 | 6 | 6 | exact | 7 |  | `If !VisibleQuickMenuSearchWin` |
| 117 | 3 | 6 | 6 | exact | 7 |  | `backCurrentSLD := CurrentSLD` |
| 118 | 3 | 6 | 6 | exact | 7 |  | `pB := GetPathRelativeBounds(pPath, imgSelPx, im…` |
| 119 | 3 | 6 | 6 | near, 1 | 7 | ends with Return | `showTOOLtip(‹1›)` |
| 120 | 3 | 6 | 6 | near, 3 | 7 |  | `ml := (PrefsLargeFonts=1) ? 35 : 25` |
| 121 | 11 | 3 | 3 | exact | 6 | Return inside, A_ThisFunc | `initQPVmainDLL()` |
| 122 | 10 | 3 | 3 | exact | 6 | Break inside, loop variable | `If (determineTerminateOperation()=1)` |
| 123 | 7 | 6 | 5 | near, 1 | 6 | Return inside | `If ErrorLevel` |
| 124 | 6 | 6 | 6 | near, 1 | 6 | Return inside | `Gui, fdTreeGuia: Default` |
| 125 | 4 | 4 | 4 | exact | 6 |  | `If (act=0)` |
| 126 | 4 | 4 | 4 | near, 2 | 6 |  | `trGdip_GetImageDimensions(userAlphaMaskBmpPaint…` |
| 127 | 4 | 4 | 3 | near, 1 | 6 |  | `If ‹1›` |
| 128 | 4 | 4 | 4 | near, 1 | 6 | A_ThisFunc | `SetTimer, ResetImgLoadStatus, -100` |
| 129 | 4 | 4 | 4 | near, 1 | 6 |  | `userFilterInvertThis := ‹1› := 0` |
| 130 | 4 | 4 | 4 | near, 1 | 6 |  | `If (abandonAll=1)` |
| 131 | 4 | 4 | 4 | near, 1 | 6 |  | `If (AnyWindowOpen=14)` |
| 132 | 11 | 4 | 4 | near, 2 | 5 | Return inside, A_ThisFunc | `initQPVmainDLL()` |
| 133 | 7 | 3 | 3 | near, 1 | 5 |  | `If (PrefsLargeFonts=1)` |
| 134 | 5 | 3 | 3 | exact | 5 |  | `If (A_TickCount - prevMSGdisplay>100)` |
| 135 | 5 | 3 | 3 | exact | 5 |  | `If (SLDtypeLoaded=3)` |
| 136 | 5 | 3 | 3 | exact | 5 | A_ThisFunc | `If (actionu!="noPreview")` |
| 137 | 5 | 3 | 3 | exact | 5 |  | `prevVPselRotation := VPselRotation` |
| 138 | 5 | 4 | 4 | exact | 5 | Continue inside | `If !FileExist(file2rem)` |
| 139 | 5 | 3 | 3 | exact | 5 |  | `entriesD := []` |
| 140 | 5 | 3 | 3 | exact | 5 |  | `If (PreserveDateTimeOnSave=1 && !r && originalM…` |
| 141 | 5 | 3 | 3 | near, 1 | 5 |  | `If originalMtime` |
| 142 | 5 | 3 | 3 | near, 2 | 5 |  | `GuiAddSlider("BlurAreaHue", -180,180, 0, "Hue:…` |
| 143 | 5 | 4 | 4 | near, 1 | 5 | Return inside, A_ThisFunc | `If !validBMP(pBitmap)` |
| 144 | 5 | 4 | 4 | near, 1 | 5 | Continue inside | `If !RegExMatch(imgPath, ‹1›)` |
| 145 | 5 | 3 | 3 | near, 1 | 5 |  | `jso := GetFileAttributesEx(file2save)` |
| 146 | 5 | 3 | 3 | near, 1 | 5 | ends with Return | `lastOtherWinClose := 1` |
| 147 | 4 | 9 | 8 | near, 2 | 5 | ends with Return | `showTOOLtip(‹1›)` |
| 148 | 3 | 5 | 5 | exact | 5 |  | `backCurrentSLD := CurrentSLD` |
| 149 | 3 | 5 | 3 | exact | 5 |  | `CurrentSLD := backCurrentSLD` |
| 150 | 3 | 5 | 3 | near, 1 | 5 |  | `FreeImage_UnLoad(hFIFimgA)` |
| 151 | 3 | 5 | 3 | near, 1 | 5 |  | `rzb := DllCall("qpvmain.dll\NewDrawLinesOnMask"…` |
| 152 | 3 | 5 | 5 | near, 1 | 5 |  | `thisOpacity := (BrushToolUseSecondaryColor=1) ?…` |
| 153 | 3 | 5 | 5 | near, 2 | 5 |  | `objSel.dw := imgSelW, objSel.dh := imgSelH` |

## Entries

### 1. `showTOOLtip(‹1›) ⏎ SoundBeep 300, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

4 lines · 115 copies in 86 functions · near-copies, 1 changing value · saves about 339 lines · ends with Return

Related: #3, #5, #48, #54, #78, #123

`ViewAlphaMaskNow()` 3815 · `ResizeAlphaMask2sel()` 3845, 3855 · `coreFlipuAlphaMask()` 3893 · `CopyAlphaMask2clippy()` 3957 · `ToggleThumbsMode()` 4870 · `BtnSetBrushSymmetryCoords()` 5867 · `MenuSetStartVectorPoint()` 7982 · `splitPointGivenInPath()` 8531 · `ApplyVPcolorAdjustSelectedArea()` 17605 · `AdjustColorsLegacySelectedArea()` 17688 · `undoRedoHugeImagesAct()` 20818 · `convertImageIntoHugeImage()` 21151, 21165 · `MenuDisableKbdShortcut()` 26091 · `BtnApplyNewKbdShortcut()` 26242, 26248, 26254 · `removeDeadFavedFolders()` 27089 · `addFolderSldATfavorites()` 27183, 27195 · `PanelWrapperFilesStats()` 28361 · `PlotSeenHourStatsNow()` 28708 · `PlotSeenMonthsStatsNow()` 28794 · `PlotSeenDaysStatsNow()` 28922 · `FolderTreeFindActiveFile()` 31242 · `UIcoreFolderNew()` 31754 · `UIcoreFolderPasteFoldersInto()` 31926 · `UIcoreFolderRename()` 32081 · `PasteFilesIntoGivenFolder()` 32316 · `PanelEnableFilesFilter()` 33024 · `LoadPrefsFromSLD()` 34510 · `WritePrefsIntoSLD()` 34540 · `SaveFilesList()` 35033, 35093 · `PanelCachesOverview()` 36153 · `coreCachesOverviewIgnoredAct()` 36414 · `dbSortingCached()` 37243 · `ToggleImgFavourites()` 39212, 39278, 39295, 39348 · `saveFavesListBasedOnIndexList()` 39542, 39559, 39573 · `batchRemoveMetaData()` 40280 · `coreBatchMultiRenameFiles()` 41230, 41243, 41251 · `moveMarkedEntryNow()` 41604 · `PanelCombineImagesMultipage()` 44031 · `CombineImgsIntoPDF()` 44213 · `generateThumbsSheet()` 44629 · `PanelSearchAndReplaceIndex()` 46433 · `BTNperformIndexSearchReplace()` 46476, 46484, 46494, 46507, 46520 · `PanelSearchIndex()` 47081 · `importEditGivenImageFile()` 47941 · `importAlphaMaskGivenImageFile()` 47965 · `MainPanelTransformArea()` 48166 · `togglePathCurveTension()` 50120 · `PanelEditorImgResize()` 50256 · `BTNimgResizeEditor()` 50333, 50342 · `MenuSaveEditorVectorShape()` 51164 · `BtnAdjustColorsSimpleImgSelArea()` 56271 · `BtnPixelizeSelectedArea()` 56317 · `PanelPDFreadTexts()` 56762 · `BTNextractALLtextsCurrentPDF()` 57144 · `PanelOCRtextRecognition()` 57195 · `updateUIfimToneMappedIMG()` 58610 · `PanelJump2index()` 59369 · `BTNuiProceedStructuredOperation()` 60777, 60793, 60815, 60824 · `batchConvert2format()` 61552 · `combineImagesMultiTiffGDIp()` 63129, 63139, 63156 · `combineImagesFimMultiPage()` 63380, 63390 · `RefreshImageFileAction()` 64258 · `importSLDplainText()` 64702 · `importSLDBintoSLDB()` 64767, 64775 · `invokeFoldersListerMenu()` 72085 · `ToggleLargeUIfonts()` 72714, 72722 · `ToggleDarkModus()` 72777, 72785 · `toggleBrushAirMode()` 77569 · `toggleBrushSymmetryModes()` 77682 · `RegenerateEntireList()` 86827 · `PanelFindDupes()` 89644 · `BTNfindDupesNow()` 90097 · `PurgeCachedDataSelectedFiles()` 90392 · `PanelJpegPerformOperation()` 90511 · `BtnPerformJpegOp()` 90623, 90631 · `BtnBatchSimpleColorAdjuster()` 91277, 91286 · `PanelAdjustImageCanvasSize()` 91908 · `BTNadjustCanvasAction()` 92116 · `batchAdvIMGresizer()` 92320 · `filesListApplyColors()` 92530 · `BtnDoMultiUndoFileActs()` 93859 · `BTNhistoFileActsList()` 93966 · `PanelReviewSelectedFiles()` 94846 · `SearchAndReplaceThroughIndex()` 97044 · `SearchAndReplaceSeenDB()` 97234 · `AcquireWIAimage()` 101414

### 2. `If (determineTerminateOperation()=1) ⏎ abandonAll := 1 ⏎ …`

5 lines · 82 copies in 71 functions · exact copies · saves about 239 lines · Break inside

Related: #22, #38, #122

`copyMoveStructuredFolders()` 3271 · `CalculateSelectedFilesSizes()` 3453 · `CopyImagePath()` 3557 · `HugeImagesDrawParametricLines()` 21968 · `collectImageInfosNow()` 29369 · `collectFileInfosNow()` 29463 · `retrieveGroupSQLimgInfos()` 29824 · `PopulateIndexSQLFilesStatsInfos()` 30367, 30477 · `uiFileIndexStatsRetrieveSizeRangeDB()` 30587 · `getFolderInfos()` 31135 · `FolderTreeFindActiveFile()` 31349 · `PasteFilesIntoGivenFolder()` 32370 · `InListMultiEntriesRemover()` 33917 · `SaveDBfilesList()` 34955 · `countFilesDiskPerStaticFolders()` 35371 · `removeFilesListSeenImages()` 35791 · `findFavesInList()` 35948 · `retrieveAlreadySeenImageFromCurrentList()` 36082 · `uiPopulateCachesOverview()` 36253, 36262 · `collectSQLFileInfosNow()` 36682 · `generateSQLimageFingerPrintHash()` 37137 · `SortFilesList()` 37552 · `searchNextIndex()` 40016 · `batchRemoveMetaData()` 40336 · `batchFileDelete()` 40453 · `coreBatchMultiRenameFiles()` 41293 · `uiPopulateQuickMenuSearch()` 42737 · `CombineImgsIntoPDF()` 44274, 44326 · `generateThumbsSheet()` 44693 · `SearchIndexSelectAll()` 46916 · `SelectFilesDead()` 46980 · `batchImgPrinting()` 54052 · `BTNextractALLtextsCurrentPDF()` 57132 · `batchCopyMoveFile()` 61340 · `batchConvert2format()` 61612 · `batchExtractFramesFromImages()` 62302 · `coreExtractFramesFromTiff()` 62415 · `coreExtractFramesFromWEBP()` 62704 · `coreExtractBatchModeTextsFromGivenPDF()` 62806 · `coreExtractFramesFromImage()` 62917, 63005 · `combineImagesMultiTiffGDIp()` 63225 · `combineImagesFimMultiPage()` 63448, 63479 · `FileExploreUpDownLevel()` 63960, 63983 · `importSLDBintoSLDB()` 64816, 64888, 65011 · `coreAddNewFiles()` 65243 · `ToggleSeenIMGstatus()` 74161 · `CleanDeadFilesSeenImagesDB()` 74269, 74294 · `EraseThumbsCache()` 85473 · `filterDupeResultsByHdist()` 87294 · `retrieveDupesByProperties()` 87792 · `sldGenerateFilesList()` 88110 · `oldGetFilesList()` 88231, 88307 · `GetFilesList()` 88577 · `PurgeCachedDataModifiedFiles()` 90313 · `PurgeCachedDataSelectedFiles()` 90411 · `batchJpegLLoperations()` 90744 · `batchAdvIMGresizer()` 92385 · `UIpopulateKeywordsListPanel()` 93510 · `PopulateFileActsHistory()` 94106 · `batchUndoFileActs()` 94478 · `uiPopulateReviewSelectedFiles()` 95389 · `BTNselFilesStaticFolder()` 95869 · `BTNcountFilesDynaFolders()` 95947 · `BtnPanelStaticJumpFirst()` 96147 · `countAllFilesPerStaticFolders()` 96427, 96465 · `PopulateStaticFolderzList()` 97582 · `batchAutoCropFiles()` 98845 · `batchAutoColorsFiles()` 98950 · `batchSimpleProcessing()` 99831 · `batchSimpleColorsAdjusts()` 99945 · `printLargeStrArray()` 100068

### 3. `showTOOLtip(‹1›) ⏎ SoundBeep ‹2›, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime`

3 lines · 57 copies in 46 functions · near-copies, 2 changing values · saves about 109 lines

Related: #1, #48, #54, #78, #123, #147

`ResizeAlphaMask2sel()` 3876 · `MenuConvertShapeToPoly()` 7624 · `ToggleSlideShowu()` 11021 · `blockBrokenIMGrefresh()` 11803 · `ApplyVPcolorAdjustSelectedArea()` 17667 · `AdjustColorsLegacySelectedArea()` 17787 · `AdjustColorsSimpleSelectedArea()` 17886 · `InsertTextSelectedArea()` 18041 · `coreImageFillSelectedArea()` 19475 · `SymmetrySelectedArea()` 20382, 20396 · `undoRedoHugeImagesAct()` 20899 · `HugeImagesFlipHVinvert()` 21032 · `warnHugeImageNotFIM()` 21111 · `convertImageIntoHugeImage()` 21197 · `warnIncorrectColorDepthHugeImage()` 21349 · `HugeImagesApplyAutoColors()` 21400 · `HugeImagesApplyInsertText()` 21566 · `HugeImagesDrawParametricLines()` 21797, 21823, 21837, 21852 · `coreDrawParametricLinesTool()` 23563, 23608 · `ChangeImageCanvasSize()` 23931, 23941 · `detectEdgesSelectedArea()` 24499 · `addNoiseSelectedArea()` 24621 · `CropImageInViewPortToSelection()` 25313 · `MenuDisableKbdShortcut()` 26115 · `MenuRestoreDefaultKBD()` 26154 · `SaveDBfilesList()` 34998, 35010 · `retrieveAlreadySeenImageFromCurrentList()` 35992 · `collectSQLFileInfosNow()` 36597 · `dbSortingCached()` 37260 · `PanelAutoSelectDupes()` 46843, 46853 · `BtnPerformSearchNow()` 47190 · `BTNdeleteCaptionAction()` 47313 · `BTNsaveCaptionAction()` 47347 · `throwWarningHugeImagesFeatureNotAvailable()` 48118, 48126 · `BTNloadCustomShape()` 50909 · `BTNcopySelCoords()` 54222 · `throwErrorAllSelectedInvert()` 56182 · `BtnCopyMoveAction()` 60963 · `throwWarningAlphaPaintMode()` 83757 · `OpenSLDBdataBase()` 87060 · `PanelRenameStaticFolder()` 96955, 96964 · `AutoCropAction()` 98446, 98483 · `BtnPerformSimpleProcessing()` 99694 · `tlbrChangeStuffRotation()` 103056 · `tlbrZoomINout()` 103372 · `tlbrInvokeSortListMenu()` 103635

### 4. `btnWid := btnWid + ‹1› ⏎ txtWid := txtWid + ‹2› ⏎ Gui, Font, s%LargeUIfontValue%`

3 lines · 53 copies in 53 functions · near-copies, 2 changing values · saves about 101 lines

Related: #8, #16, #31, #80, #82, #133

`PanelIndexedImagesStats()` 28209 · `PanelIndexedFilesStats()` 28304 · `PanelWrapperFilesStats()` 28374 · `PanelImageInfos()` 30624 · `PanelFoldersTree()` 30708 · `PanelEnableFilesFilter()` 33037 · `PanelMultiFileDelete()` 40129 · `PanelMultiRenameFiles()` 40778 · `PanelQuickSearchMenuOptions()` 41942 · `PanelSaveSlideShowu()` 43768 · `PanelExtractFrames()` 43917 · `PanelCombineImagesMultipage()` 44044 · `PanelSetWallpaper()` 44946 · `PanelSaveImg()` 45042 · `PanelBrushTool()` 45273 · `PanelChangeHamDistThreshold()` 46341 · `PanelSearchAndReplaceIndex()` 46447 · `PanelQuickMoveConfigure()` 46590 · `PanelEditImgCaption()` 47225 · `MainPanelTransformArea()` 48366 · `PanelEditorImgResize()` 50270 · `PanelManageVectorShapes()` 50564 · `PanelDesatureSelectedArea()` 52019 · `PanelSymmetricaImage()` 52066 · `PanelEraseSelectedArea()` 52238 · `PanelDetectEdgesImage()` 53280 · `PanelAddNoiserImage()` 53402 · `PanelNewImage()` 53587 · `PanelPrintImage()` 53763 · `PanelIMGselProperties()` 54154 · `PanelInsertTextArea()` 57847 · `uiADDalphaMaskTabs()` 57970 · `PanelPreferencesWindow()` 58221 · `PanelAdjustToneMapping()` 58387 · `PanelDefineEntireSlideshowLength()` 59171 · `PanelAutoColors()` 60497 · `PanelSharpenImage()` 60607 · `PanelAboutWindow()` 89394 · `PanelHelpWindow()` 89450 · `PanelFindDupes()` 89676 · `PanelJpegPerformOperation()` 90548 · `coreColorsAdjusterWindow()` 90912 · `PanelAdjustColorsSimpleWindow()` 91121 · `PanelFileFormatConverter()` 91749 · `PanelAdjustImageCanvasSize()` 91944 · `PanelResizeImageWindow()` 92149 · `PanelKeywordsDetector()` 93325 · `PanelStaticFolderzManager()` 93697 · `PanelMultiUndoFileActs()` 93814 · `PanelFileUndoHistory()` 93898 · `PanelReviewSelectedFiles()` 94860 · `PanelDynamicFolderzWindow()` 95504 · `PanelSimpleResizeRotate()` 99476

### 5. `SoundBeep, 300, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

3 lines · 37 copies in 26 functions · exact copies · saves about 69 lines · ends with Return

Related: #1, #48, #54, #78, #123

`OpenSLD()` 2497 · `OpenQPVfileFolder()` 2827 · `setImageWallpaper()` 2855, 2881 · `OpenImgWithUserExternApp()` 3120, 3130 · `changeImgRotationInVP()` 12245 · `HugeImagesApplyPasteInPlace()` 22173 · `corePasteClipboardImg()` 25492 · `MenuDisableKbdShortcut()` 26078, 26099 · `PanelDefineKbdShortcut()` 26587 · `PanelImageInfos()` 30612 · `UIcoreFolderRename()` 32063 · `coreCachesOverviewIgnoredAct()` 36442 · `convertFocusedFileToPDF()` 44183, 44191 · `CombineImgsIntoPDF()` 44242 · `BTNperformExtractFrames()` 44510 · `PanelCreateIMGthumbsSheet()` 44819 · `BTNimgResizeEditor()` 50323 · `BTNrenameCustomShape()` 50705 · `BTNloadCustomShape()` 50872, 50896 · `BTNbatchExtractTextsPDFs()` 56914 · `combineImagesFimMultiPage()` 63411, 63428 · `importSLDBintoSLDB()` 64785 · `ActPaintBrushNow()` 79057, 79081, 79097, 79125 · `ActDrawAlphaMaskBrushNow()` 79784, 79804 · `BTNundoFileActu()` 94013 · `MenuPreviewFramesFilterList()` 96548, 96567

### 6. `If !file2save ⏎ skippedFiles++ ⏎ Continue ⏎ …`

34 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 60 lines · Break/Continue inside

Related: #26, #145

`copyMoveStructuredFolders()` 3324 · `PasteFilesIntoGivenFolder()` 32408 · `batchCopyMoveFile()` 61423

### 7. `INIaction(1, ‹1›, "General") ⏎ friendly := (‹2›=1) ? "ACTIVATED" : "DEACTIVATED" ⏎ …`

4 lines · 20 copies in 20 functions · near-copies, 3 changing values · saves about 54 lines · A_ThisFunc

`ToggleAllonTop()` 71797 · `ToggleSlidesFXmode()` 71805 · `ToggleGIFsPlayEntirely()` 71824 · `ToggleRecordSeenImages()` 71838 · `ToggleSkipSeenIMGs()` 71846 · `ToggleAutoPlaySND()` 71911 · `ToggleSyncSlide2sndDuration()` 71919 · `ToggleSlidesTransitions()` 71927 · `TglRvrSort()` 71957 · `TglCheckDeadFilesSort()` 71965 · `ToggleRecordOpenHistory()` 72495 · `ToggleAnimGIFsupport()` 72606 · `ToggleAutoRemEntries()` 72647 · `TogglePromptDelete()` 72655 · `ToggleThumbsCaching()` 72973 · `ToggleSkipDeadFiles()` 72988 · `ToggleFilesMap()` 72996 · `toggleImgEditGammaCorrect()` 73073 · `toggleFreeIMGpanning()` 73153 · `ToggleAutoPlaySlidesMusic()` 73161

### 8. `If (PrefsLargeFonts=1) ⏎ lstWid := lstWid + ‹1› ⏎ btnWid := btnWid + ‹2› ⏎ …`

7 lines · 14 copies in 14 functions · near-copies, 3 changing values · saves about 49 lines

Contains: #4 · Related: #16, #80, #133

`PanelIndexedImagesStats()` 28206 · `PanelIndexedFilesStats()` 28301 · `PanelWrapperFilesStats()` 28371 · `PanelImageInfos()` 30621 · `PanelFoldersTree()` 30705 · `PanelQuickSearchMenuOptions()` 41939 · `PanelManageVectorShapes()` 50561 · `PanelAboutWindow()` 89391 · `PanelHelpWindow()` 89447 · `PanelKeywordsDetector()` 93322 · `PanelStaticFolderzManager()` 93694 · `PanelFileUndoHistory()` 93895 · `PanelReviewSelectedFiles()` 94857 · `PanelDynamicFolderzWindow()` 95501

### 9. `initQPVmainDLL() ⏎ If !qpvMainDll ⏎ addJournalEntry(A_ThisFunc ‹1›) ⏎ …`

8 lines · 9 copies in 9 functions · near-copies, 2 changing values · saves about 44 lines · Return inside · A_ThisFunc

Related: #132

`QPV_SetBitmapAsAlphaChannel()` 14545 · `QPV_SetColorAlphaChannel()` 14584 · `QPV_FloodFill()` 14608 · `QPV_ConvertToGrayscale()` 14637 · `QPV_AdjustImageColors()` 14666 · `QPV_MergeBitmapsWithMask()` 14994 · `QPV_ColorizeGrayImage()` 15051 · `QPV_ResizeSplitBlendChannels()` 15142 · `QPV_DiffBlendBitmap()` 24893

### 10. `If askAboutFileSave(‹1›) ⏎ Return ⏎ If askAboutSlidesListSave() ⏎ …`

6 lines · 12 copies in 12 functions · near-copies, 2 changing values · saves about 40 lines · Return inside

`omniBoxFolderOpen()` 27248 · `folderTreeDefaultAction()` 30820 · `BtnViewedImages2List()` 56680 · `BtnALLviewedImages2List()` 56708 · `OpenFolders()` 63879 · `closeDocuments()` 66153 · `restartAppu()` 66179 · `exitAppu()` 66202 · `OpenRecentEntry()` 71529 · `OpenFavesEntry()` 71605 · `BTNhistoFileActsList()` 93972 · `BtnPanelManageFoldersActus()` 96231

### 11. `For Key, Value in ‹1› ⏎ LV_Add(A_Index, A_Index, Value[2], Value[1], Round((Value[1]/‹2›)*100,…`

4 lines · 15 copies in 4 functions · near-copies, 3 changing values · saves about 39 lines

`uiPopulateSeenStatsInfos()` 29224, 29234 · `PopulateIndexFilesStatsInfos()` 29769 · `PopulateImagesIndexStatsInfos()` 30186, 30199, 30212, 30224, 30236, 30248, 30258, 30269, 30279, 30291 · `PopulateIndexSQLFilesStatsInfos()` 30452, 30497

### 12. `uiPopulateCachesOverview("kill") ⏎ PopulateIndexFilesStatsInfos("kill") ⏎ …`

3 lines · 20 copies in 20 functions · exact copies · saves about 35 lines

Related: #84

`InListMultiEntriesRemover()` 33970 · `remCurrentEntry()` 34029 · `SQLdeleteEntriesMarked()` 34432 · `SQLrestoreEntriesMarked()` 34448 · `cleanDeadFilesList()` 35637 · `removeFilesListSeenImages()` 35824 · `collectSQLFileInfosNow()` 36577 · `generateSQLimageFingerPrintHash()` 37086 · `batchFileDelete()` 40552 · `DeletePicture()` 40707 · `switchIndexEntries()` 41730 · `coreAddNewFiles()` 65279 · `oldGetFilesList()` 88318 · `GetFilesList()` 88644 · `corePurgeCachedSQLdata()` 90274 · `PurgeCachedDataSelectedFiles()` 90451 · `BtnPerformJpegOp()` 90673 · `filesListApplyColors()` 92582 · `BTNsaveResizedIMG()` 92770 · `BtnPerformSimpleProcessing()` 99759

### 13. `If (StrLen(textu)>‹1›) ⏎ If !copyTextToClippy(textu) ⏎ …`

10 lines · 5 copies in 5 functions · near-copies, 3 changing values · saves about 33 lines

`BtnCopySeenStats()` 29073 · `BtnCopyFileStats()` 29128 · `BtnCopyImageFileStats()` 29168 · `copyIMGinfos2clip()` 32512 · `BTNcopyPDFtexts()` 56854

### 14. `nImgSelX1 := min(imgSelX1, imgSelX2) ⏎ nImgSelY1 := min(imgSelY1, imgSelY2) ⏎ …`

4 lines · 12 copies in 12 functions · exact copies · saves about 30 lines

Related: #81

`isVPselLarger()` 6350 · `endFreeHandModus()` 9965 · `testSelectionLargerThanGiven()` 18490 · `testEntireImgSelected()` 18503 · `isSelEntireVisible()` 18796 · `isSelEntireOutside()` 18820 · `CropImageInViewPortToSelection()` 25265 · `BTNpasteSelCoords()` 54271 · `UIoffsetSelProperPanel()` 54367 · `calcRelativeSelCoords()` 77018 · `ViewPortSelectionManageCoords()` 81814 · `calcImgSelection2bmp()` 89064

### 15. `SoundBeep , 300, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

4 lines · 12 copies in 9 functions · near-copies, 2 changing values · saves about 30 lines · ends with Return

Related: #98

`ApplyVPcolorAdjustSelectedArea()` 17626, 17638 · `AdjustColorsLegacySelectedArea()` 17711, 17724 · `AdjustColorsSimpleSelectedArea()` 17819, 17831 · `EraseOrInvertOrGraySelectedArea()` 19943 · `SymmetrySelectedArea()` 20373 · `PolarRectSelectedArea()` 20514 · `PopulateImagesIndexStatsInfos()` 29950 · `PanelBrowseAudioAnnotation()` 41855 · `QuickMoveFile2Dest()` 61199

### 16. `EditWid := EditWid + ‹1› ⏎ btnWid := btnWid + ‹2› ⏎ txtWid := txtWid + ‹3› ⏎ …`

4 lines · 32 copies in 32 functions · near-copies, 3 changing values · saves about 28 lines

Contains: #4 · Related: #8, #31, #80, #82, #133

`PanelEnableFilesFilter()` 33036 · `PanelMultiRenameFiles()` 40777 · `PanelSaveSlideShowu()` 43767 · `PanelExtractFrames()` 43916 · `PanelCombineImagesMultipage()` 44043 · `PanelSetWallpaper()` 44945 · `PanelSaveImg()` 45041 · `PanelBrushTool()` 45272 · `PanelSearchAndReplaceIndex()` 46446 · `PanelQuickMoveConfigure()` 46589 · `PanelEditImgCaption()` 47224 · `MainPanelTransformArea()` 48365 · `PanelEditorImgResize()` 50269 · `PanelDesatureSelectedArea()` 52018 · `PanelSymmetricaImage()` 52065 · `PanelEraseSelectedArea()` 52237 · `PanelDetectEdgesImage()` 53279 · `PanelAddNoiserImage()` 53401 · `PanelNewImage()` 53586 · `PanelPrintImage()` 53762 · `PanelIMGselProperties()` 54153 · `PanelInsertTextArea()` 57846 · `uiADDalphaMaskTabs()` 57969 · `PanelPreferencesWindow()` 58220 · `PanelAdjustToneMapping()` 58386 · `PanelDefineEntireSlideshowLength()` 59170 · `PanelAutoColors()` 60496 · `PanelSharpenImage()` 60606 · `PanelFindDupes()` 89675 · `PanelFileFormatConverter()` 91748 · `PanelAdjustImageCanvasSize()` 91943 · `PanelResizeImageWindow()` 92148

### 17. `trGdip_GetImageDimensions(plotBMP, imgW, imgH) ⏎ trGdip_GetImageDimensions(infoBoxBMP, boxW, b…`

16 lines · 3 copies in 3 functions · exact copies · saves about 27 lines · A_ThisFunc

`PlotSeenHourStatsNow()` 28764 · `PlotSeenMonthsStatsNow()` 28864 · `PlotSeenDaysStatsNow()` 29046

### 18. `If validBMP(‹1›) ⏎ showTOOLtip(‹2›) ⏎ Else ⏎ …`

6 lines · 7 copies in 7 functions · near-copies, 3 changing values · saves about 27 lines

`PasteInPlaceSelectedArea()` 14147 · `InsertTextSelectedArea()` 17928 · `DrawLinesInSelectedArea()` 22819 · `BlurSelectedArea()` 24102 · `ZoomBlurSelectedArea()` 24341 · `detectEdgesSelectedArea()` 24472 · `addNoiseSelectedArea()` 24601

### 19. `showTOOLtip("Operation abandoned by user") ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

6 lines · 7 copies in 3 functions · near-copies, 1 changing value · saves about 27 lines · ends with Return

`PopulateIndexFilesStatsInfos()` 29707 · `PopulateImagesIndexStatsInfos()` 30167 · `PopulateIndexSQLFilesStatsInfos()` 30381, 30415, 30440, 30460, 30504

### 20. `winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y"…`

3 lines · 16 copies in 16 functions · near-copies, 3 changing values · saves about 27 lines

`PanelBrushTool()` 45411 · `PanelFillSelectedArea()` 51434 · `PanelSoloAlphaMasker()` 51490 · `PanelDrawShapesInArea()` 51650 · `PanelConfigVPgrid()` 51739 · `PanelDrawParametricLines()` 51968 · `PanelDesatureSelectedArea()` 52048 · `PanelFloodFillTool()` 52216 · `PanelEraseSelectedArea()` 52265 · `PanelFillBehindBgrImage()` 52333 · `PanelZoomBlurSelectedArea()` 52947 · `PanelPixelizeSelectedArea()` 53062 · `PanelBlurSelectedArea()` 53180 · `PanelDetectEdgesImage()` 53334 · `PanelAddNoiserImage()` 53471 · `PanelInsertTextArea()` 57950

### 21. `If !dbIndex ⏎ activeSQLdb.EscapeStr(fullPath) ⏎ wherePart := dbIndex ? " WHERE imgidu=" dbInde…`

17 lines · 3 copies in 3 functions · exact copies · saves about 26 lines · Return inside · A_ThisFunc

`updateSQLdbEntryImgRes()` 34117 · `updateSQLdbEntryFileInfos()` 34141 · `updateSQLdbEntryImgHisto()` 34257

### 22. `If (determineTerminateOperation()=1) ⏎ abandonAll := 1 ⏎ …`

11 lines · 6 copies in 5 functions · near-copies, 3 changing values · saves about 26 lines · Break inside · loop variable

Contains: #2

`collectFileInfosNow()` 29463 · `searchNextIndex()` 40016 · `importSLDBintoSLDB()` 64816, 64888 · `UIpopulateKeywordsListPanel()` 93510 · `BTNselFilesStaticFolder()` 95869

### 23. `whichBitmap := validBMP(UserMemBMP) ? UserMemBMP : gdiBitmap ⏎ …`

7 lines · 7 copies in 7 functions · exact copies · saves about 26 lines · Return inside · A_ThisFunc

`InsertTextSelectedArea()` 17904 · `FillSelectedArea()` 18271 · `DrawLinesInSelectedArea()` 22796 · `BlurSelectedArea()` 24052 · `ZoomBlurSelectedArea()` 24323 · `detectEdgesSelectedArea()` 24458 · `addNoiseSelectedArea()` 24586

### 24. `If validBMP(‹1›) ⏎ trGdip_DisposeImage(zBitmap, 1) ⏎ …`

5 lines · 8 copies in 7 functions · near-copies, 1 changing value · saves about 25 lines

Related: #93

`getImgSelectedAreaEditMode()` 16553 · `AdjustColorsLegacySelectedArea()` 17763 · `AdjustColorsSimpleSelectedArea()` 17862 · `SymmetrySelectedArea()` 20422 · `livePreviewEraseArea()` 52485 · `livePreviewSymmetricaImgArea()` 55850, 55912 · `livePreviewSimpleColorsAdjustImage()` 56159

### 25. `Gui, ‹1›: Default ⏎ Gui, ‹1›: ListView, ‹2› ⏎ RowNumber := LV_GetFirstSelected(‹3›) ⏎ …`

5 lines · 8 copies in 8 functions · near-copies, 3 changing values · saves about 25 lines

`MenuDisableKbdShortcut()` 26063 · `MenuRestoreDefaultKBD()` 26138 · `PanelDefineKbdShortcut()` 26569 · `omniBoxFolderDelete()` 27351 · `updateUistatusLineQuickSearch()` 42252 · `filterListByKeywords()` 93373 · `BTNundoFileActu()` 93999 · `uiLVundoFileActsResponder()` 94048

### 26. `If !‹1› ⏎ skippedFiles++ ⏎ Continue ⏎ …`

9 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 24 lines · Break/Continue inside

Related: #6

`multiCoreThreadSimpleImgProcessing()` 38454 · `coreBatchMultiRenameFiles()` 41355 · `batchAdvIMGresizer()` 92406 · `batchUndoFileActs()` 94542 · `batchAutoCropFiles()` 98892

### 27. `If (AnyWindowOpen!=‹1›) ⏎ Return ⏎ Gui, SettingsGUIA: Default ⏎ …`

4 lines · 15 copies in 15 functions · near-copies, 2 changing values · saves about 24 lines · Return inside

`updateUIFiltersPanel()` 33141 · `UItoggleMultiDelProtectFolder()` 40104 · `printSettingsObj()` 53867 · `updateUIchangeSelectionType()` 54434 · `updateUInewImagePanel()` 54560 · `NewImageEditResponder()` 54665 · `BtnCreateNewImage()` 54686 · `DefineSlidesTotalTimeBTNaction()` 59306 · `BtnCollectDupesData()` 89796 · `updateUIimageHashPreview()` 89821 · `updateUIdupesPanel()` 89888 · `UIeditCanvasMargins()` 91989 · `updateUIadjustCanvasPanel()` 92020 · `UIfilterListKeywords()` 93434 · `UIfilterListViewStaticFolderzList()` 97412

### 28. `Gui, fdTreeGuia: Default ⏎ Gui, fdTreeGuia: TreeView, TVlistFolders ⏎ …`

3 lines · 14 copies in 14 functions · exact copies · saves about 23 lines

Related: #124

`folderTreeCopyPath()` 30737 · `folderTreeDefaultAction()` 30794 · `folderTreeInfoStatusLineUpdater()` 31158 · `folderTreeContextMenu()` 31646 · `folderTreeCreateFolder()` 31774 · `folderTreeDeleteFolder()` 31850 · `folderTreePasteFoldersInto()` 31875 · `folderTreeCutCopyFolder()` 32008 · `folderTreeRenameFolder()` 32038 · `fromFolderTreeToOmniBox()` 32128 · `folderTreeAppendFiles()` 32156 · `folderTreeScanSubbies()` 32208 · `folderTreePasteClippy()` 32296 · `triggerQuickFileAction()` 46702

### 29. `LV_ModifyCol(1, "Integer") ⏎ LV_ModifyCol(3, "Integer") ⏎ …`

3 lines · 14 copies in 3 functions · exact copies · saves about 23 lines

Related: #96

`PopulateIndexFilesStatsInfos()` 29722, 29739, 29753, 29764 · `PopulateImagesIndexStatsInfos()` 30232, 30244, 30254, 30265, 30276, 30287 · `PopulateIndexSQLFilesStatsInfos()` 30398, 30425, 30449, 30470

### 30. `ForceRefreshNowThumbsList() ⏎ dummyTimerDelayiedImageDisplay(100) ⏎ …`

9 lines · 4 copies in 4 functions · near-copies, 3 changing values · saves about 21 lines

Related: #61

`coreBatchMultiRenameFiles()` 41440 · `batchAdvIMGresizer()` 92469 · `batchSimpleProcessing()` 99896 · `batchSimpleColorsAdjusts()` 100007

### 31. `If (PrefsLargeFonts=1) ⏎ btnHeight := 30 ⏎ EditWid := EditWid + 50 ⏎ …`

9 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 21 lines

Related: #4, #16

`PanelFillSelectedArea()` 51324 · `PanelSoloAlphaMasker()` 51456 · `PanelDrawShapesInArea()` 51572 · `PanelConfigVPgrid()` 51705

### 32. `If (thumbsDisplaying=1) ⏎ Return ⏎ initQPVmainDLL() ⏎ …`

7 lines · 6 copies in 6 functions · near-copies, 1 changing value · saves about 21 lines · Return inside · A_ThisFunc

`PanelZoomBlurSelectedArea()` 52862 · `PanelPixelizeSelectedArea()` 52958 · `PanelBlurSelectedArea()` 53068 · `PanelDetectEdgesImage()` 53262 · `PanelAddNoiserImage()` 53384 · `PanelSharpenImage()` 60589

### 33. `If ‹1› ⏎ FreeImage_UnLoad(hFIFimgA) ⏎ hFIFimgA := ‹1›`

5 lines · 7 copies in 5 functions · near-copies, 1 changing value · saves about 21 lines

`HugeImagesApplyInsertText()` 21486 · `initializeFimPreviewIMG()` 58541 · `FIMapplyToneMapper()` 61867, 61878, 61906 · `LoadBitmapAsFreeImage()` 63656 · `LoadFimFile()` 100561

### 34. `showTOOLtip(‹1›) ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

3 lines · 13 copies in 11 functions · near-copies, 1 changing value · saves about 21 lines · ends with Return

`CalculateSelectedFilesSizes()` 3434 · `folderTreeCopyPath()` 30743 · `BtnApplyFilesFilter()` 33331, 33339 · `FilterFilesListuIndex()` 33679 · `navSelectedFiles()` 39843 · `DeletePicture()` 40625 · `UImultiRenameChangeLVoffset()` 40851 · `BtnViewedImages2List()` 56675 · `FileExploreSiblingsNav()` 64098, 64128 · `toggleAlphaPaintingMode()` 77789 · `PurgeCachedDataModifiedFiles()` 90293

### 35. `GetMouseCoord2wind(PVhwnd, mX, mY) ⏎ ‹1› := (FlipImgH=1) ? mainWidth - mX : mX ⏎ …`

3 lines · 13 copies in 10 functions · near-copies, 2 changing values · saves about 21 lines

`setNewBrushSymmetryPoints()` 5897 · `moveOnePointInVectorPath()` 9058 · `selectPathPointsInRect()` 9183 · `WinClickAction()` 10116, 10149 · `addFluidPointsCustomShape()` 49203 · `adjustAnchorPointsCustomShape()` 49241, 49272 · `ActFloodFillNow()` 78913 · `ActPaintBrushNow()` 79103 · `ActDrawAlphaMaskBrushNow()` 79793, 79918 · `drawLiveCreateCustomShape()` 80921

### 36. `initQPVmainDLL() ⏎ If !qpvMainDll ⏎ addJournalEntry(A_ThisFunc ‹1›) ⏎ …`

6 lines · 7 copies in 7 functions · near-copies, 1 changing value · saves about 20 lines · Return inside · A_ThisFunc

Related: #121

`QPV_PrepareAlphaChannelBlur()` 15081 · `QPV_AlterAlphaChannel()` 15113 · `QPV_DissolveBitmap()` 20116 · `QPV_SymmetricaBitmap()` 20159 · `QPV_autoContrastBitmap()` 20185 · `QPV_AddGaussianNoiseOnBitmap()` 24953 · `QPV_PixelateBitmap()` 24978

### 37. `If A_LoopField ⏎ lineArr := StrSplit(A_LoopField, "?") ⏎ …`

13 lines · 3 copies in 3 functions · exact copies · saves about 18 lines · Break/Continue inside · loop variable

`multiCoreThreadJpegLL()` 38368 · `multiCoreThreadSimpleImgProcessing()` 38423 · `multiCoreThreadFormatConvert()` 38553

### 38. `If (resultedFilesList[A_Index, 2]!=1) ⏎ Continue ⏎ If (determineTerminateOperation()=1) ⏎ …`

7 lines · 12 copies in 12 functions · exact copies · saves about 18 lines · Break/Continue inside · loop variable

Contains: #2

`CalculateSelectedFilesSizes()` 3450 · `batchFileDelete()` 40450 · `coreBatchMultiRenameFiles()` 41290 · `batchCopyMoveFile()` 61337 · `batchExtractFramesFromImages()` 62299 · `combineImagesFimMultiPage()` 63445 · `PurgeCachedDataSelectedFiles()` 90408 · `batchJpegLLoperations()` 90741 · `batchAutoCropFiles()` 98842 · `batchAutoColorsFiles()` 98947 · `batchSimpleProcessing()` 99828 · `batchSimpleColorsAdjusts()` 99942

### 39. `Gui, SettingsGUIA: Default ⏎ Gui, SettingsGUIA: ListView, ‹1› ⏎ …`

4 lines · 8 copies in 8 functions · near-copies, 3 changing values · saves about 18 lines

`countFilesDiskPerStaticFolders()` 35334 · `BTNdoSoloRename()` 40814 · `UIlvMultiRenameResponder()` 41075 · `BTNlvRecentFileDesties()` 60838 · `BTNignoreDateStaticFolder()` 95538 · `BTNremFilesStaticFolder()` 95757 · `BTNcountFilesDynaFolders()` 95930 · `BTNupdateSelectedStaticFolder()` 97317

### 40. `cornersBMP := trGdip_CreateBitmap(A_ThisFunc, ‹1›, ‹2›, coreDesiredPixFmt) ⏎ …`

9 lines · 4 copies in 4 functions · near-copies, 2 changing values · saves about 17 lines · Return inside · A_ThisFunc

`createLivePreviewBrush()` 46259 · `getTinyPreviewAreaBitmap()` 84449 · `updateUIimageHashPreview()` 89832 · `coreCaptureImgCorners()` 98346

### 41. `If (uiUseDarkMode=1) ⏎ Gui, Color, % darkWindowColor, % darkWindowColor ⏎ …`

6 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 17 lines

`PanelDefineKbdShortcut()` 26614 · `createSettingsGUI()` 28127 · `PanelFoldersTree()` 30693 · `PanelQuickSearchMenuOptions()` 41928 · `coreDialogConflictsMsgBox()` 43283

### 42. `Try FileSetAttrib, -R, % file2save ⏎ Sleep, ‹1› ⏎ FileMove, % file2save, % file2save "-tmp" ⏎ …`

6 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 17 lines

`coreConvertImgFormat()` 62043 · `coreWIAsimpleFileProcessing()` 99089 · `coreFreeImageSimpleFileProcessing()` 99271 · `coreFreeImageSimpleColorsAdjust()` 99392 · `SaveFIMfile()` 100244

### 43. `If (AnyWindowOpen=10 && imgEditPanelOpened=1) ⏎ GuiControl, SettingsGUIA: Choose, ‹1›, % ‹2› ⏎ …`

6 lines · 5 copies in 5 functions · near-copies, 2 changing values · saves about 17 lines

`ToggleImageSizingMode()` 10859 · `ToggleImgColorDepth()` 11276 · `dummyDisplayZoomImgInfo()` 11949 · `ToggleImgHistogram()` 72914 · `ToggleHistogramMode()` 72935

### 44. `If (‹1›=‹2›) ⏎ If !activeSQLdb.Exec("COMMIT TRANSACTION;") ⏎ …`

5 lines · 6 copies in 6 functions · near-copies, 2 changing values · saves about 17 lines · A_ThisFunc

`cleanDeadFilesList()` 35629 · `removeFilesListSeenImages()` 35754 · `applyMultiCoresConvertResults()` 38197 · `batchConvert2format()` 61722 · `oldGetFilesList()` 88272 · `GetFilesList()` 88633

### 45. `SoundBeep 300, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

3 lines · 11 copies in 10 functions · near-copies, 1 changing value · saves about 17 lines · ends with Return

Related: #147

`folderTreeIsDriveRoot()` 31640 · `PasteFilesIntoGivenFolder()` 32347 · `warnFramesActionPrevented()` 40579 · `BTNrenameSoloFileAct()` 47445, 47465 · `UpdateIndexBTNaction()` 47579 · `BtnCopyMoveAction()` 61034 · `MenuSetVectAutoSymmetryX()` 77601 · `MenuSetVectAutoSymmetryY()` 77626 · `preventColorChange()` 78298 · `PanelsCheckFileExists()` 89568

### 46. `initQPVmainDLL() ⏎ If !qpvMainDll ⏎ addJournalEntry(A_ThisFunc "(): QPV dll file is missing or…`

12 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 16 lines · Return inside · A_ThisFunc

`QPV_BlurBitmapFilters()` 24842 · `QPV_DetectEdgesFilters()` 24867 · `QPV_SharpenBitmap()` 24920

### 47. `colNum := (AnyWindowOpen=3) ? 3 : 1 ⏎ RowNumber := LV_GetNext(0, "F") ⏎ …`

7 lines · 5 copies in 5 functions · exact copies · saves about 16 lines · Return inside

`BTNcopyStaticFolderPath()` 95615 · `BTNcutCopyStaticFolders()` 95665 · `BTNselFilesStaticFolder()` 95821 · `BtnPanelStaticJumpFirst()` 96128 · `BtnPanelManageFoldersActus()` 96200

### 48. `If !‹1› ⏎ showTOOLtip(‹2›) ⏎ SoundBeep 300, 100 ⏎ …`

7 lines · 11 copies in 10 functions · near-copies, 2 changing values · saves about 16 lines · Return inside

Contains: #1 · Related: #3, #5

`convertImageIntoHugeImage()` 21163 · `UIcoreFolderNew()` 31752 · `UIcoreFolderRename()` 32079 · `PanelCombineImagesMultipage()` 44029 · `CombineImgsIntoPDF()` 44211 · `updateUIfimToneMappedIMG()` 58608 · `combineImagesMultiTiffGDIp()` 63137, 63154 · `combineImagesFimMultiPage()` 63388 · `PurgeCachedDataSelectedFiles()` 90390 · `PanelReviewSelectedFiles()` 94844

### 49. `If (A_TickCount - prevSaveData>300100) ⏎ prevSaveData := A_TickCount ⏎ …`

10 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 15 lines

`collectSQLFileInfosNow()` 36656 · `generateSQLimageFingerPrintHash()` 37110 · `PurgeCachedDataModifiedFiles()` 90333

### 50. `Gui, SettingsGUIA: Default ⏎ GuiControlGet, OutputVar, Visible, LViewFiltered ⏎ …`

4 lines · 7 copies in 7 functions · exact copies · saves about 15 lines

`BTNreviewDropFilesSelection()` 94902 · `BTNreviewSelFilesInPath()` 94976 · `BtnReviewPaneOpenActs()` 94987 · `BTNreviewFilterLVSelPath()` 95022 · `BTNreviewCopyPanel()` 95036 · `BTNreviewToggleSelection()` 95156 · `uiLVreviewSelFilesResponder()` 95252

### 51. `tx := (imgSelPx > prevDestPosX) ? prevDestPosX : max(imgSelPx, prevDestPosX) ⏎ …`

4 lines · 7 copies in 7 functions · exact copies · saves about 15 lines

`livePreviewHugeImageFillSelArea()` 18899 · `coreFillSelectedArea()` 19208 · `coreImageFillSelectedArea()` 19447 · `livePreviewEraseArea()` 52431 · `livePreviewFillBehindArea()` 52655 · `livePreviewSymmetricaImgArea()` 55860 · `livePreviewSimpleColorsAdjustImage()` 56049

### 52. `If InStr(msgResult, "reopen") ⏎ SetTimer, ‹1›, -‹2› ⏎ …`

4 lines · 7 copies in 6 functions · near-copies, 2 changing values · saves about 15 lines · ends with Return

`FillSelectedArea()` 18258 · `SharpenSelectedArea()` 20250 · `SymmetrySelectedArea()` 20350 · `BlurSelectedArea()` 24085, 24092 · `ZoomBlurSelectedArea()` 24315 · `detectEdgesSelectedArea()` 24450

### 53. `If warnHugeImageNotFIM() ⏎ Return ⏎ If (editingSelectionNow=1) ⏎ …`

11 lines · 3 copies in 3 functions · exact copies · saves about 14 lines · Return inside

`HugeImagesApplyAutoColors()` 21358 · `HugeImagesApplyInsertText()` 21446 · `HugeImagesDrawLineShapes()` 21629

### 54. `If (‹1›<‹2›) ⏎ showTOOLtip(‹3›) ⏎ SoundBeep 300, 100 ⏎ …`

7 lines · 10 copies in 10 functions · near-copies, 3 changing values · saves about 14 lines · Return inside

Contains: #1 · Related: #3, #5

`PlotSeenHourStatsNow()` 28706 · `PlotSeenMonthsStatsNow()` 28792 · `PlotSeenDaysStatsNow()` 28920 · `coreCachesOverviewIgnoredAct()` 36412 · `PanelSearchIndex()` 47079 · `BtnPixelizeSelectedArea()` 56315 · `PanelJump2index()` 59367 · `BtnBatchSimpleColorAdjuster()` 91284 · `BTNadjustCanvasAction()` 92114 · `BTNhistoFileActsList()` 93964

### 55. `If !ResizeUseDestDir ⏎ GuiControl, Disable, btnFldr ⏎ …`

5 lines · 5 copies in 5 functions · exact copies · saves about 13 lines

`PanelAdjustColorsSimpleWindow()` 91226 · `PanelFileFormatConverter()` 91794 · `PanelResizeImageWindow()` 92251 · `PanelImgAutoCrop()` 98255 · `PanelSimpleResizeRotate()` 99517

### 56. `If (SLDtypeLoaded=3) ⏎ SLDtypeLoaded := 0 ⏎ activeSQLdb.CloseDB()`

5 lines · 5 copies in 5 functions · exact copies · saves about 13 lines

`OpenSLD()` 2503 · `retrieveFavesAsList()` 39487 · `OpenDialogFiles()` 64397 · `MenuOpenLastImg()` 64543 · `OpenRecentEntry()` 71560

### 57. `If pEffect ⏎ Gdip_BitmapApplyEffect(‹1›, pEffect) ⏎ Gdip_DisposeEffect(pEffect)`

5 lines · 5 copies in 3 functions · near-copies, 1 changing value · saves about 13 lines

`applyVPeffectsOnBMP()` 25036, 25045 · `applyVPeffectsAdvOnBMP()` 25101, 25110 · `printImageNow()` 101241

### 58. `If (icoFile!=initialIcon) ⏎ tlbrIconzList[‹1›, 2] := icoFile ⏎ …`

5 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 13 lines

`decideIconBTNselectShape()` 103466 · `decideIconBTNthumbsList()` 103488 · `decideIconBTNmainTooler()` 103507 · `decideIconBTNpaintBrushSelect()` 103527 · `decideIconBTNvectToolModes()` 103543

### 59. `Gui, SettingsGUIA: Default ⏎ Gui, SettingsGUIA: ListView, LViewDynas ⏎ …`

5 lines · 5 copies in 5 functions · near-copies, 2 changing values · saves about 13 lines

`BTNcountFilesDiskDynaFolder()` 35407 · `invokePanelDynaFoldersContextMenu()` 93183 · `BTNremDynaSelFolder()` 96055 · `BtnToggleRecurseDynaFolder()` 96586 · `BTNrescanDynaFolder()` 96637

### 60. `ResetImgLoadStatus() ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

3 lines · 9 copies in 5 functions · exact copies · saves about 13 lines · ends with Return

`FillSelectedArea()` 18309 · `undoRedoHugeImagesAct()` 20855, 20871, 20918 · `HugeImagesApplyGenericFilters()` 22446, 22539 · `PasteHDropFiles()` 25355 · `importSLDBintoSLDB()` 64862, 64876

### 61. `SetTimer, ResetImgLoadStatus, -‹1› ⏎ SoundBeep, % (abandonAll=1) ? 300 : 900, 100 ⏎ …`

3 lines · 9 copies in 9 functions · near-copies, 1 changing value · saves about 13 lines

Related: #30

`copyMoveStructuredFolders()` 3422 · `PasteFilesIntoGivenFolder()` 32486 · `batchImgPrinting()` 54129 · `batchCopyMoveFile()` 61523 · `batchConvert2format()` 61744 · `batchExtractFramesFromImages()` 62381 · `ToggleSeenIMGstatus()` 74185 · `EraseThumbsCache()` 85509 · `batchJpegLLoperations()` 90795

### 62. `r := resultedFilesList[A_Index, 1] ⏎ If (InStr(r, "||") || !r) ⏎ …`

10 lines · 3 copies in 3 functions · near-copies, 3 changing values · saves about 12 lines · Continue inside · loop variable

`removeFilesListSeenImages()` 35779 · `findFavesInList()` 35920 · `retrieveAlreadySeenImageFromCurrentList()` 36049

### 63. `columnIndex++ ⏎ If (columnIndex>=maxItemsW) ⏎ rowIndex++ ⏎ …`

6 lines · 4 copies in 4 functions · exact copies · saves about 12 lines

`thumbsListClickResponder()` 9731 · `QPV_listThumbnailsGridMode()` 84850 · `QPV_ListViewGridHUDoverlay()` 85058 · `QPV_ShowThumbnails()` 85693

### 64. `initQPVmainDLL() ⏎ If (!qpvMainDll || isWinXP=1) ⏎ addJournalEntry(A_ThisFunc "(): QPV dll fil…`

6 lines · 5 copies in 5 functions · exact copies · saves about 12 lines · Return inside · A_ThisFunc

`QPV_BlendBitmaps()` 15208 · `OpenCV_FimResizeBitmap()` 15293 · `OpenCV_FimToneMapping()` 15357 · `QPV_CreateBitmapNoise()` 15434 · `createPlasmaNoiseBitmap()` 15462

### 65. `If (‹1›="kill") ⏎ prevState := 0 ⏎ prevBMPu := trGdip_DisposeImage(prevBMPu, 1) ⏎ …`

6 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 12 lines · Return inside

`realtimePasteInPlaceRotator()` 14277 · `realtimePasteInPlaceBlurrator()` 14361 · `realtimePasteInPlaceAlphaMaskRotator()` 14442 · `LoadCachableBitmapFromFile()` 14505 · `drawFillSelGradient()` 19580

### 66. `RowNumber := LV_GetNext(RowNumber) ⏎ If !RowNumber ⏎ …`

6 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 12 lines · Break/Continue inside

`countFilesDiskPerStaticFolders()` 35349 · `filterListByKeywords()` 93390 · `BTNignoreDateStaticFolder()` 95567 · `BTNremFilesStaticFolder()` 95777 · `BTNupdateSelectedStaticFolder()` 97342

### 67. `If (AnyWindowOpen=31 || AnyWindowOpen=24) ⏎ ‹1› := !‹1› ⏎ …`

6 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 12 lines

`togglePasteInPlaceColorsFX()` 48062 · `togglePasteInPlaceCropNone()` 48080 · `FlipVtransformedIMGpanel()` 48089 · `FlipHtransformedIMGpanel()` 48099

### 68. `If (abandonAll=1) ⏎ showTOOLtip("Operation aborted. " groupDigits(filezMoved) " out of " group…`

4 lines · 6 copies in 3 functions · near-copies, 3 changing values · saves about 12 lines

`copyMoveStructuredFolders()` 3410, 3416 · `PasteFilesIntoGivenFolder()` 32474, 32480 · `batchCopyMoveFile()` 61511, 61517

### 69. `If failedFiles ⏎ ‹1› := ‹2› groupDigits(failedFiles) " files" ⏎ …`

4 lines · 6 copies in 4 functions · near-copies, 2 changing values · saves about 12 lines

`batchAutoCropFiles()` 98911 · `batchAutoColorsFiles()` 98986 · `batchSimpleProcessing()` 99848, 99889 · `batchSimpleColorsAdjusts()` 99962, 100000

### 70. `‹1› := A_TickCount ⏎ ‹2› := A_TickCount ⏎ backCurrentSLD := CurrentSLD ⏎ …`

4 lines · 6 copies in 6 functions · near-copies, 2 changing values · saves about 12 lines

`removeFilesListSeenImages()` 35737 · `findFavesInList()` 35899 · `retrieveAlreadySeenImageFromCurrentList()` 36016 · `WorkLoadMultiCoreHandler()` 38227 · `generateThumbsSheet()` 44672 · `retrieveDupesByProperties()` 87765

### 71. `If (!r && tempFileExists=1) || (!FileRexists(file2save, 0) && tempFileExists=1) ⏎ …`

8 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 11 lines

`coreConvertImgFormat()` 62146 · `coreWIAsimpleFileProcessing()` 99101 · `SaveFIMfile()` 100294

### 72. `SQL := "SELECT imgfolder FROM dynamicfolders;" ⏎ ‹1›.GetTable(SQL, ‹2›) ⏎ …`

8 lines · 3 copies in 3 functions · near-copies, 3 changing values · saves about 11 lines

`importSLDBintoSLDB()` 65146 · `coreLoadDynaFolders()` 86688 · `OpenSLDBdataBase()` 87071

### 73. `If !InStr(msgResult.btn, "Yes") ⏎ SetTimer, ‹1›, -‹2› ⏎ …`

5 lines · 6 copies in 3 functions · near-copies, 2 changing values · saves about 11 lines · Return inside

`thumbsListClickResponder()` 9874, 9897 · `FolderTreeResponder()` 31052, 31086 · `LVquickSearchMenusResponder()` 42139, 42160

### 74. `doStartLongOpDance() ⏎ prevMSGdisplay := A_TickCount ⏎ …`

3 lines · 8 copies in 8 functions · exact copies · saves about 11 lines

`CopyImagePath()` 3550 · `countFilesDiskPerStaticFolders()` 35365 · `searchNextIndex()` 40004 · `CleanDeadFilesSeenImagesDB()` 74232 · `BTNreviewCopyPanel()` 95045 · `BTNreviewToggleSelection()` 95160 · `BTNselFilesStaticFolder()` 95864 · `BtnPanelStaticJumpFirst()` 96142

### 75. `If AnyWindowOpen ⏎ BtnCloseWindow() ⏎ Sleep, ‹1›`

3 lines · 8 copies in 8 functions · near-copies, 1 changing value · saves about 11 lines

`TrueCleanup()` 4437 · `SQLdbGenerateStaticFolders()` 34717 · `SaveDBfilesList()` 34823 · `BTNmultiDel()` 40245 · `PanelBrowseAudioAnnotation()` 41874 · `PanelSetSlidesMusic()` 43133 · `BrowseReplaceIndexEntry()` 43192 · `addNewFile2list()` 64646

### 76. `GuiAddCloseOnApply("x+5 yp hp wp") ⏎ GuiAddToggleLivePreview(‹1›) ⏎ …`

3 lines · 8 copies in 8 functions · near-copies, 2 changing values · saves about 11 lines

`PanelFillSelectedArea()` 51428 · `PanelDrawShapesInArea()` 51644 · `PanelDrawParametricLines()` 51962 · `PanelDesatureSelectedArea()` 52043 · `PanelSymmetricaImage()` 52117 · `PanelEraseSelectedArea()` 52260 · `PanelFillBehindBgrImage()` 52327 · `PanelInsertTextArea()` 57945

### 77. `If (msgResult="Yes") ⏎ FileCreateDir, %‹1›% ⏎ If ErrorLevel ⏎ …`

9 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 10 lines · Return inside

`folderTreeCreateFolder()` 31786 · `UIcoreFolderPasteFoldersInto()` 31906 · `BTNuiProceedStructuredOperation()` 60804

### 78. `If (‹1›=1) ⏎ showTOOLtip(‹2›) ⏎ SoundBeep , 300, 100 ⏎ …`

7 lines · 8 copies in 8 functions · near-copies, 2 changing values · saves about 10 lines · Return inside

Contains: #1 · Related: #3, #5

`ApplyVPcolorAdjustSelectedArea()` 17603 · `undoRedoHugeImagesAct()` 20816 · `FolderTreeFindActiveFile()` 31240 · `BTNextractALLtextsCurrentPDF()` 57142 · `BTNuiProceedStructuredOperation()` 60775 · `invokeFoldersListerMenu()` 72083 · `filesListApplyColors()` 92528 · `SearchAndReplaceSeenDB()` 97232

### 79. `If !(thisBtnHeight := createSettingsGUI(‹1›, A_ThisFunc, 1, 1)) ⏎ …`

4 lines · 8 copies in 8 functions · near-copies, 1 changing value · saves about 10 lines · Return inside · A_ThisFunc

`PanelFillSelectedArea()` 51296 · `PanelDrawShapesInArea()` 51552 · `PanelDrawParametricLines()` 51849 · `PanelDesatureSelectedArea()` 52006 · `PanelSymmetricaImage()` 52054 · `PanelEraseSelectedArea()` 52222 · `PanelInsertTextArea()` 57830 · `PanelAdjustColorsSimpleWindow()` 91102

### 80. `btnWid := 100 ⏎ txtWid := 330 ⏎ EditWid := 395 ⏎ …`

10 lines · 4 copies in 4 functions · exact copies · saves about 9 lines

Contains: #4, #16 · Related: #8, #133

`PanelExtractFrames()` 43911 · `PanelCombineImagesMultipage()` 44038 · `PanelSetWallpaper()` 44940 · `PanelSaveImg()` 45036

### 81. `If (!‹1› || !‹2›) ⏎ vpWinClientSize(‹1›, ‹2›) ⏎ nImgSelX1 := min(imgSelX1, imgSelX2) ⏎ …`

10 lines · 3 copies in 3 functions · near-copies, 2 changing values · saves about 9 lines

Contains: #14

`isVPselLarger()` 6347 · `isSelEntireVisible()` 18793 · `isSelEntireOutside()` 18817

### 82. `‹1› := ‹2› ⏎ EditWid := 60 ⏎ If (PrefsLargeFonts=1) ⏎ …`

10 lines · 4 copies in 4 functions · near-copies, 3 changing values · saves about 9 lines

Contains: #4, #16

`PanelDetectEdgesImage()` 53274 · `PanelAddNoiserImage()` 53396 · `PanelAutoColors()` 60491 · `PanelSharpenImage()` 60601

### 83. `aC++ ⏎ If (aC>3) ⏎ aR++ ⏎ …`

7 lines · 3 copies in 3 functions · exact copies · saves about 9 lines

`PlotSeenHourStatsNow()` 28724 · `PlotSeenMonthsStatsNow()` 28816 · `PlotSeenDaysStatsNow()` 28979

### 84. `If (SLDtypeLoaded=3) ⏎ selectivePurgeCachedSQLdata(resultedFilesList[currentFileIndex, 12]) ⏎ …`

7 lines · 4 copies in 4 functions · exact copies · saves about 9 lines

Contains: #12

`BtnPerformJpegOp()` 90670 · `filesListApplyColors()` 92579 · `BTNsaveResizedIMG()` 92767 · `BtnPerformSimpleProcessing()` 99756

### 85. `updateDates := 1 ⏎ If (originalMtime) ⏎ FileSetTime, % originalMtime, % file2save, M ⏎ …`

7 lines · 3 copies in 3 functions · exact copies · saves about 9 lines

`copyMoveStructuredFolders()` 3363 · `QuickMoveFile2Dest()` 61218 · `batchCopyMoveFile()` 61462

### 86. `etaTime := ETAinfos(countTFilez, filesElected, startOperation) ⏎ …`

7 lines · 3 copies in 3 functions · near-copies, 2 changing values · saves about 9 lines

`batchRemoveMetaData()` 40344 · `batchAutoCropFiles()` 98855 · `batchAutoColorsFiles()` 98960

### 87. `startOperation := A_TickCount ⏎ If (SLDtypeLoaded=3 && useCachedSLDdata=1) ⏎ …`

7 lines · 3 copies in 3 functions · near-copies, 3 changing values · saves about 9 lines

`ActSortSize()` 37387 · `ActSortModified()` 37426 · `ActSortCreated()` 37436

### 88. `killQPVscreenImgSection() ⏎ setHugeImageActionsCount(viewportQPVimage.actions + 1) ⏎ …`

5 lines · 4 copies in 4 functions · exact copies · saves about 9 lines

`HugeImagesApplyAutoColors()` 21392 · `HugeImagesApplyInsertText()` 21593 · `HugeImagesDrawLineShapes()` 21739 · `HugeImagesApplyGenericFilters()` 22577

### 89. `` If (inLoop!=1) ⏎ showTOOLtip("Extracting " groupDigits(tFrames) " frames from:`n" OutFileName) ⏎ … ``

5 lines · 4 copies in 3 functions · exact copies · saves about 9 lines

`coreExtractFramesFromTiff()` 62404 · `coreExtractFramesFromWEBP()` 62688 · `coreExtractFramesFromImage()` 62903, 62996

### 90. `If ((AnyWindowOpen=10 || AnyWindowOpen=74) && imgEditPanelOpened=1) ⏎ …`

5 lines · 4 copies in 4 functions · exact copies · saves about 9 lines

`VPchangeLumos()` 11640 · `VPchangeGammos()` 12018 · `VPchangeSaturation()` 12060 · `VPchangeRealGamma()` 12095

### 91. `discardSRCfileCaches() ⏎ destroyGDIfileCache() ⏎ discardViewPortCaches() ⏎ …`

5 lines · 4 copies in 4 functions · exact copies · saves about 9 lines

`doOpenStartFolder()` 12576 · `PasteClipboardIMG()` 25565 · `BtnCreateNewImage()` 54725 · `renewCurrentFilesList()` 63931

### 92. `etaTime := ETAinfos(countTFilez, ‹1›, startOperation) ⏎ …`

5 lines · 4 copies in 4 functions · near-copies, 3 changing values · saves about 9 lines

`copyMoveStructuredFolders()` 3295 · `PasteFilesIntoGivenFolder()` 32393 · `batchJpegLLoperations()` 90757 · `batchAdvIMGresizer()` 92375

### 93. `If validBMP(‹1›) ⏎ trGdip_DisposeImage(pBitmap, 1) ⏎ …`

5 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 9 lines

Related: #24

`LoadCachableBitmapFromFile()` 14525 · `resizeBitmapToGivenRef()` 14983 · `pdfAddBitmapPage()` 44474 · `createGradientBrushBitmap()` 78526

### 94. `Gui, SettingsGUIA: Default ⏎ Gui, SettingsGUIA: ListView, LViewMetaD ⏎ …`

5 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 9 lines

`uiPopulateSeenStatsInfos()` 29216 · `PopulateIndexFilesStatsInfos()` 29715 · `PopulateImagesIndexStatsInfos()` 30175 · `PopulateIndexSQLFilesStatsInfos()` 30390

### 95. `If (thumbsDisplaying=1) ⏎ QPV_ListViewGridHUDoverlay() ⏎ …`

4 lines · 5 copies in 4 functions · near-copies, 1 changing value · saves about 9 lines

`invertFilesSelection()` 39734, 39740 · `dropFilesSelection()` 39761 · `ToggleImgNavSizeBox()` 72847 · `autoSelectDupesInGroups()` 88085

### 96. `LV_ModifyCol(1, "Integer") ⏎ LV_ModifyCol(‹1›, "Float") ⏎ …`

4 lines · 5 copies in 3 functions · near-copies, 3 changing values · saves about 9 lines

Related: #29

`PopulateIndexFilesStatsInfos()` 29775 · `PopulateImagesIndexStatsInfos()` 30182, 30207, 30220 · `PopulateIndexSQLFilesStatsInfos()` 30515

### 97. `If (dir=1) ⏎ ‹1›++ ⏎ Else ⏎ …`

4 lines · 5 copies in 3 functions · near-copies, 1 changing value · saves about 9 lines

`ToggleImgColorDepth()` 11263 · `ToggleImgFX()` 11310, 11318, 11326 · `changeBrushWetness()` 78447

### 98. `SoundBeep , 300, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

3 lines · 7 copies in 6 functions · exact copies · saves about 9 lines

Related: #15

`BtnIndexStatsToList()` 28654 · `collectSQLFileInfosNow()` 36501 · `reportCollectSQLoutcome()` 36720 · `generateSQLimageFingerPrintHash()` 37080, 37176 · `dbSortingCached()` 37311 · `QuickMoveFile2Dest()` 61167

### 99. `SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ ResetImgLoadStatus() ⏎ …`

3 lines · 7 copies in 6 functions · exact copies · saves about 9 lines · ends with Return

`OpenSLD()` 2591 · `HugeImagesConvertClrDepth()` 21228 · `MainPanelTransformArea()` 48298 · `BTNimgResizeEditor()` 50361, 50372 · `importSLDBintoSLDB()` 64849 · `BTNreviewCopyPanel()` 95112

### 100. `RegAction(1, ‹1›) ⏎ If (drawingShapeNow=1) ⏎ showQuickActionButtonsDrawingShape()`

3 lines · 7 copies in 7 functions · near-copies, 1 changing value · saves about 9 lines

`MenuRemSelVectorPoints()` 7460 · `MenuToggleBezierMode()` 8035 · `autoDeactivateClosedBezier()` 8340 · `splitPointGivenInPath()` 8522 · `moveOnePointInVectorPath()` 9157 · `removeGivenPointInVectorPath()` 9345 · `toggleOpenClosedLineEditorCustomShape()` 49665

### 101. `prevMSGdisplay := A_TickCount ⏎ ‹1› := A_TickCount ⏎ …`

3 lines · 7 copies in 7 functions · near-copies, 1 changing value · saves about 9 lines

`copyMoveStructuredFolders()` 3251 · `CalculateSelectedFilesSizes()` 3440 · `coreAddNewFiles()` 65227 · `oldGetFilesList()` 88207 · `GetFilesList()` 88450 · `batchJpegLLoperations()` 90735 · `GenerateKeywordsListNow()` 93635

### 102. `thisStartZeit := A_TickCount ⏎ trGdip_GetImageDimensions(pBitmap, w, h) ⏎ …`

8 lines · 3 copies in 3 functions · exact copies · saves about 8 lines · Return inside · A_ThisFunc

`QPV_PrepareAlphaChannelBlur()` 15088 · `QPV_AlterAlphaChannel()` 15120 · `QPV_FillBitmapHoles()` 15184

### 103. `If !validBMP(‹1›) ⏎ failedFiles++ ⏎ Continue`

5 lines · 5 copies in 4 functions · near-copies, 1 changing value · saves about 8 lines · Continue inside

`generateThumbsSheet()` 44712 · `batchImgPrinting()` 54090 · `combineImagesMultiTiffGDIp()` 63211, 63232 · `batchAdvIMGresizer()` 92417

### 104. `If (EllipseSelectMode=1) ⏎ FillAreaShape := 3 ⏎ Else If (EllipseSelectMode=0) ⏎ …`

6 lines · 3 copies in 3 functions · exact copies · saves about 7 lines

`PanelFillSelectedArea()` 51305 · `PanelDrawShapesInArea()` 51559 · `PanelFillBehindBgrImage()` 52285

### 105. `GuiControlGet, closeEditPanelOnApply, SettingsGUIA:, closeEditPanelOnApply ⏎ …`

6 lines · 3 copies in 3 functions · exact copies · saves about 7 lines

`BtnGraySelectedArea()` 56197 · `BtnSymmetrySelectedArea()` 56219 · `BtnAdjustColorsSimpleImgSelArea()` 56286

### 106. `Gdip_GetImageDimensions(pBitmap, w, h) ⏎ If (max(w, h)>32750 && w && h) ⏎ …`

6 lines · 3 copies in 3 functions · exact copies · saves about 7 lines

`tzGdip_DrawImageFast()` 18523 · `tzGdip_DrawImage()` 18549 · `trGdip_DrawImageFX()` 18637

### 107. `thisu := max(maxValu, valu) ⏎ If (thisu!=maxValu) ⏎ maxValu := thisu ⏎ …`

6 lines · 3 copies in 3 functions · exact copies · saves about 7 lines

`PlotSeenHourStatsNow()` 28737 · `PlotSeenMonthsStatsNow()` 28828 · `PlotSeenDaysStatsNow()` 28991

### 108. `Gui, Add, Text, x20 y20 w%gW% h%gH% Section -Border +0xE gUIresponderPanelsLivePreview +hwndhC…`

6 lines · 3 copies in 3 functions · exact copies · saves about 7 lines

`PanelDetectEdgesImage()` 53295 · `PanelAddNoiserImage()` 53417 · `PanelSharpenImage()` 60624

### 109. `If (‹1›=3) ⏎ EllipseSelectMode := 1 ⏎ Else If (‹1›=7) ⏎ …`

6 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 7 lines

`HugeImagesApplyPasteInPlace()` 22209 · `updateUIdrawShapesPanel()` 54992 · `CloseWindow()` 97788

### 110. `initQPVmainDLL() ⏎ If (dupesDCTcoeffsInit!=1 && userWasWarned=0) ⏎ …`

6 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 7 lines

`PanelBrushTool()` 45255 · `PanelFloodFillTool()` 52164 · `PanelFindDupes()` 89662

### 111. `SelectedDir := openFoldersDialogWrapper(‹1›) ⏎ SelectedDir := Trimmer(SelectedDir) ⏎ …`

6 lines · 3 copies in 3 functions · near-copies, 2 changing values · saves about 7 lines

`BtnCpyMvChooseFilesDest()` 59814 · `BtnCpyMvStrctrdChooseFilesDst()` 59834 · `BtnCpyMvStrctrdChooseFilesSrc()` 59854

### 112. `If (FillAreaCurveTension=1) ⏎ ll := ‹1› ⏎ Else If (FillAreaCurveTension=5) ⏎ …`

6 lines · 3 copies in 3 functions · near-copies, 3 changing values · saves about 7 lines

`showQuickActionButtonsDrawingShape()` 50089 · `togglePathCurveTension()` 50129 · `toggleEllipseSelection()` 72406

### 113. `showTOOLtip(‹1›) ⏎ mustCaptureCloneBrush := 1 ⏎ setMenuBarState("Disable", "PVbar") ⏎ …`

6 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 7 lines

`BtnSetBrushSymmetryCoords()` 5878 · `BtnSetClonerBrushSource()` 45667 · `BtnSetTextureSource()` 45715

### 114. `Try Run, "%folderPath%" ⏎ Catch wasError ⏎ If !AnyWindowOpen ⏎ …`

6 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 7 lines

`omniBoxFolderExplorerOpen()` 27235 · `folderTreeDefaultAction()` 30800 · `BtnPanelManageFoldersActus()` 96213

### 115. `vpWinClientSize(mainWidth, mainHeight) ⏎ trGdip_GetImageDimensions(useGdiBitmap(), thisW, this…`

3 lines · 6 copies in 6 functions · exact copies · saves about 7 lines

`corePasteInPlaceActNow()` 15975 · `livePreviewHugeImageFillSelArea()` 18891 · `livePreviewHugeImageDrawLineShapes()` 19021 · `livePreviewEraseArea()` 52424 · `livePreviewFillBehindArea()` 52650 · `livePreviewSimpleColorsAdjustImage()` 56043

### 116. `If !VisibleQuickMenuSearchWin ⏎ PanelQuickSearchMenuOptions() ⏎ …`

3 lines · 6 copies in 6 functions · exact copies · saves about 7 lines

`omniBoxFolderImport()` 27054 · `omniBoxFolderOpen()` 27261 · `omniBoxFolderCreateNew()` 27292 · `omniBoxFoldersPaste()` 27320 · `omniBoxFolderRename()` 27335 · `omniBoxFolderPasteClippy()` 27384

### 117. `backCurrentSLD := CurrentSLD ⏎ CurrentSLD := "" ⏎ startOperation := A_TickCount`

3 lines · 6 copies in 6 functions · exact copies · saves about 7 lines

`cleanDeadFilesList()` 35531 · `collectSQLFileInfosNow()` 36468 · `generateSQLimageFingerPrintHash()` 37011 · `CombineImgsIntoPDF()` 44256 · `countAllFilesPerStaticFolders()` 96402 · `SearchAndReplaceSeenDB()` 97240

### 118. `pB := GetPathRelativeBounds(pPath, imgSelPx, imgSelPy) ⏎ …`

3 lines · 6 copies in 6 functions · exact copies · saves about 7 lines

`AdjustColorsLegacySelectedArea()` 17730 · `AdjustColorsSimpleSelectedArea()` 17837 · `BlurSelectedArea()` 24113 · `ZoomBlurSelectedArea()` 24352 · `coreDetectEdgesSelectedArea()` 24526 · `coreAddNoiseSelectedArea()` 24642

### 119. `showTOOLtip(‹1›) ⏎ SoundBeep 300, 100 ⏎ Return`

3 lines · 6 copies in 6 functions · near-copies, 1 changing value · saves about 7 lines · ends with Return

`clearAllFavedFolders()` 27115 · `rebuildDBfilesList()` 34767 · `eraseAllFavedIMGs()` 39619 · `batchFileDelete()` 40427 · `DeletePicture()` 40647 · `PanelPrintImage()` 53743

### 120. `ml := (PrefsLargeFonts=1) ? 35 : 25 ⏎ GuiAddButton(‹1› thisBtnHeight " w" ml ‹2›, "<<", "Previ…`

3 lines · 6 copies in 6 functions · near-copies, 3 changing values · saves about 7 lines

`PanelImageInfos()` 30639 · `PanelEditImgCaption()` 47244 · `PanelPDFreadTexts()` 56820 · `PanelJpegPerformOperation()` 90576 · `PanelImgAutoCrop()` 98261 · `PanelSimpleResizeRotate()` 99537

### 121. `initQPVmainDLL() ⏎ If !qpvMainDll ⏎ addJournalEntry(A_ThisFunc "(): QPV dll file is missing or…`

11 lines · 3 copies in 3 functions · exact copies · saves about 6 lines · Return inside · A_ThisFunc

Contains: #36

`QPV_DissolveBitmap()` 20116 · `QPV_SymmetricaBitmap()` 20159 · `QPV_autoContrastBitmap()` 20185

### 122. `If (determineTerminateOperation()=1) ⏎ abandonAll := 1 ⏎ …`

10 lines · 3 copies in 3 functions · exact copies · saves about 6 lines · Break inside · loop variable

Contains: #2

`coreExtractFramesFromTiff()` 62415 · `coreExtractFramesFromWEBP()` 62704 · `coreExtractFramesFromImage()` 63005

### 123. `If ErrorLevel ⏎ showTOOLtip(‹1›) ⏎ SoundBeep 300, 100 ⏎ …`

7 lines · 6 copies in 5 functions · near-copies, 1 changing value · saves about 6 lines · Return inside

Contains: #1 · Related: #3, #5

`addFolderSldATfavorites()` 27193 · `ToggleImgFavourites()` 39210, 39346 · `batchConvert2format()` 61550 · `combineImagesMultiTiffGDIp()` 63127 · `combineImagesFimMultiPage()` 63378

### 124. `Gui, fdTreeGuia: Default ⏎ Gui, fdTreeGuia: TreeView, TVlistFolders ⏎ …`

6 lines · 6 copies in 6 functions · near-copies, 1 changing value · saves about 6 lines · Return inside

Contains: #28

`folderTreeCreateFolder()` 31774 · `folderTreeDeleteFolder()` 31850 · `folderTreePasteFoldersInto()` 31875 · `folderTreeCutCopyFolder()` 32008 · `folderTreeRenameFolder()` 32038 · `triggerQuickFileAction()` 46702

### 125. `If (act=0) ⏎ loadSimplifiedPreviousVectorShape() ⏎ Else If (act=1) ⏎ …`

4 lines · 4 copies in 4 functions · exact copies · saves about 6 lines

`ReadSettingsPasteInPlace()` 48002 · `ReadSettingsFillBehindAreaPanel()` 48557 · `ReadSettingsFillAreaPanel()` 48571 · `ReadSettingsDrawShapeAreaPanel()` 48614

### 126. `trGdip_GetImageDimensions(userAlphaMaskBmpPainted, ‹1›, ‹2›) ⏎ …`

4 lines · 4 copies in 4 functions · near-copies, 2 changing values · saves about 6 lines

`livePreviewInsertTextinArea()` 18203 · `coreFillSelectedArea()` 19389 · `livePreviewAlphaMasking()` 52555 · `livePreviewSimpleColorsAdjustImage()` 56139

### 127. `If ‹1› ⏎ failedFrames++ ⏎ Else ⏎ …`

4 lines · 4 copies in 3 functions · near-copies, 1 changing value · saves about 6 lines

`coreExtractFramesFromTiff()` 62492 · `coreExtractFramesFromWEBP()` 62758 · `coreExtractFramesFromImage()` 62967, 63062

### 128. `SetTimer, ResetImgLoadStatus, -100 ⏎ dummyTimerDelayiedImageDisplay(50) ⏎ …`

4 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 6 lines · A_ThisFunc

`BlurSelectedArea()` 24305 · `ZoomBlurSelectedArea()` 24434 · `detectEdgesSelectedArea()` 24504 · `addNoiseSelectedArea()` 24626

### 129. `userFilterInvertThis := ‹1› := 0 ⏎ thisFilter := updateUIFiltersPanel("external") ⏎ …`

4 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 6 lines

`filterToFilesSelection()` 39711 · `filterListByKeywords()` 93410 · `uiFilterListDynaFolder()` 96509 · `MenuPreviewFramesFilterList()` 96575

### 130. `If (abandonAll=1) ⏎ showTOOLtip("Operation aborted. " groupDigits(countFilez) " out of " group…`

4 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 6 lines

`batchExtractFramesFromImages()` 62374 · `batchJpegLLoperations()` 90788 · `batchAutoCropFiles()` 98918 · `batchAutoColorsFiles()` 98993

### 131. `If (AnyWindowOpen=14) ⏎ GuiControlGet, ‹1› ⏎ Else ⏎ …`

4 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 6 lines

`ToggleIMGalign()` 11400 · `toggleCustomaToolbara()` 73113 · `toggleFreeIMGpanning()` 73142 · `ToggleTouchMode()` 73273

### 132. `initQPVmainDLL() ⏎ If !qpvMainDll ⏎ addJournalEntry(A_ThisFunc "(): QPV dll file is missing or…`

11 lines · 4 copies in 4 functions · near-copies, 2 changing values · saves about 5 lines · Return inside · A_ThisFunc

Contains: #9

`QPV_SetColorAlphaChannel()` 14584 · `QPV_ConvertToGrayscale()` 14637 · `QPV_AdjustImageColors()` 14666 · `QPV_ColorizeGrayImage()` 15051

### 133. `If (PrefsLargeFonts=1) ⏎ slideWid := slideWid + 135 ⏎ …`

7 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 5 lines

Contains: #4 · Related: #8, #16, #80

`PanelJpegPerformOperation()` 90545 · `PanelMultiUndoFileActs()` 93811 · `PanelSimpleResizeRotate()` 99473

### 134. `If (A_TickCount - prevMSGdisplay>100) ⏎ externToolTiput(info friendly) ⏎ …`

5 lines · 3 copies in 3 functions · exact copies · saves about 5 lines

`thumbsListClickResponder()` 9847 · `FolderTreeResponder()` 31031 · `LVquickSearchMenusResponder()` 42116

### 135. `If (SLDtypeLoaded=3) ⏎ If !activeSQLdb.Exec("COMMIT TRANSACTION;") ⏎ …`

5 lines · 3 copies in 3 functions · exact copies · saves about 5 lines

`copyMoveStructuredFolders()` 3391 · `batchCopyMoveFile()` 61490 · `batchUndoFileActs()` 94712

### 136. `If (actionu!="noPreview") ⏎ GuiRefreshSliders() ⏎ livePreviewsImageEditing(0, A_ThisFunc, acti…`

5 lines · 3 copies in 3 functions · exact copies · saves about 5 lines · A_ThisFunc

`updateUIerasePanel()` 55482 · `updateUIdesaturatePanel()` 55509 · `UpdateUIsimpleAdjustColors()` 55569

### 137. `prevVPselRotation := VPselRotation ⏎ prevrotateSelBoundsKeepRatio := rotateSelBoundsKeepRatio ⏎ …`

5 lines · 3 copies in 3 functions · exact copies · saves about 5 lines

`undoRedoHugeImagesAct()` 20825 · `HugeImagesApplyPasteInPlace()` 22069 · `MainPanelTransformArea()` 48305

### 138. `If !FileExist(file2rem) ⏎ failedFiles++ ⏎ Continue`

5 lines · 4 copies in 4 functions · exact copies · saves about 5 lines · Continue inside

`copyMoveStructuredFolders()` 3278 · `PasteFilesIntoGivenFolder()` 32376 · `coreBatchMultiRenameFiles()` 41307 · `batchCopyMoveFile()` 61350

### 139. `entriesD := [] ⏎ entriesM := [] ⏎ entriesY := [] ⏎ …`

5 lines · 3 copies in 3 functions · exact copies · saves about 5 lines

`PopulateIndexFilesStatsInfos()` 29538 · `PopulateImagesIndexStatsInfos()` 29904 · `PopulateIndexSQLFilesStatsInfos()` 30320

### 140. `If (PreserveDateTimeOnSave=1 && !r && originalMtime) ⏎ …`

5 lines · 3 copies in 3 functions · exact copies · saves about 5 lines

`SaveClipboardImage()` 59717 · `coreAutoColorsFileProcessing()` 98746 · `coreAutoCropFileProcessing()` 98796

### 141. `If originalMtime ⏎ FileSetTime, % originalMtime, % ‹1›, M ⏎ …`

5 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 5 lines

`multiCoreThreadFormatConvert()` 38605 · `batchConvert2format()` 61664 · `corefileUndoAction()` 94357

### 142. `GuiAddSlider("BlurAreaHue", -180,180, 0, "Hue: $€°", ‹1›, 2, ‹2› txtWid " hp") ⏎ …`

5 lines · 3 copies in 3 functions · near-copies, 2 changing values · saves about 5 lines

`PanelSymmetricaImage()` 52110 · `PanelZoomBlurSelectedArea()` 52938 · `PanelBlurSelectedArea()` 53171

### 143. `If !validBMP(pBitmap) ⏎ addJournalEntry(A_ThisFunc ‹1› funcu "(). pBitmap = " pBitmap) ⏎ …`

5 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 5 lines · Return inside · A_ThisFunc

`trGdip_BitmapConvertGray()` 102337 · `trGdip_CloneBitmapArea()` 102352 · `trGdip_ResizeBitmap()` 102426 · `trGdip_RotateBitmapAtCenter()` 102469

### 144. `If !RegExMatch(imgPath, ‹1›) ⏎ skippedFiles++ ⏎ Continue`

5 lines · 4 copies in 4 functions · near-copies, 1 changing value · saves about 5 lines · Continue inside

`multiCoreThreadSimpleImgProcessing()` 38439 · `batchExtractFramesFromImages()` 62328 · `batchSimpleProcessing()` 99838 · `batchSimpleColorsAdjusts()` 99952

### 145. `jso := GetFileAttributesEx(file2save) ⏎ originalFileInfos := jso.size "|" jso.wtime "|" jso.ct…`

5 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 5 lines

Related: #6

`coreBatchMultiRenameFiles()` 41371 · `BTNrenameSoloFileAct()` 47436 · `QuickMoveFile2Dest()` 61188

### 146. `lastOtherWinClose := 1 ⏎ ToggleThumbsMode() ⏎ SetTimer, ‹1›, -150 ⏎ …`

5 lines · 3 copies in 3 functions · near-copies, 1 changing value · saves about 5 lines · ends with Return

`PanelAutoColors()` 60478 · `PanelAdjustColorsSimpleWindow()` 91094 · `PanelImgAutoCrop()` 98166

### 147. `showTOOLtip(‹1›) ⏎ SoundBeep 300, 100 ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

4 lines · 9 copies in 8 functions · near-copies, 2 changing values · saves about 5 lines · ends with Return

Contains: #3 · Related: #45

`blockBrokenIMGrefresh()` 11803 · `warnHugeImageNotFIM()` 21111 · `warnIncorrectColorDepthHugeImage()` 21349 · `retrieveAlreadySeenImageFromCurrentList()` 35992 · `throwWarningHugeImagesFeatureNotAvailable()` 48118, 48126 · `throwErrorAllSelectedInvert()` 56182 · `BtnCopyMoveAction()` 60963 · `throwWarningAlphaPaintMode()` 83757

### 148. `backCurrentSLD := CurrentSLD ⏎ CurrentSLD := "" ⏎ whileLoopExec := 1`

3 lines · 5 copies in 5 functions · exact copies · saves about 5 lines

`copyMoveStructuredFolders()` 3261 · `CalculateSelectedFilesSizes()` 3445 · `batchFileDelete()` 40445 · `batchCopyMoveFile()` 61331 · `GuiDroppedFiles()` 65705

### 149. `CurrentSLD := backCurrentSLD ⏎ SetTimer, RemoveTooltip, % -msgDisplayTime ⏎ …`

3 lines · 5 copies in 3 functions · exact copies · saves about 5 lines

`collectSQLFileInfosNow()` 36531, 36540 · `generateSQLimageFingerPrintHash()` 37021, 37068 · `dbSortingCached()` 37300

### 150. `FreeImage_UnLoad(hFIFimgA) ⏎ hFIFimgA := ‹1› ⏎ FimBuffer := DestroyMemoryBuffer(FimBuffer)`

3 lines · 5 copies in 3 functions · near-copies, 1 changing value · saves about 5 lines

`coreConvertImgFormat()` 62062 · `coreFreeImageSimpleFileProcessing()` 99199, 99219, 99255 · `coreFreeImageSimpleColorsAdjust()` 99358

### 151. `rzb := DllCall("qpvmain.dll\NewDrawLinesOnMask", "UPtr", &PointsF, "int", PointsCount, "int",…`

3 lines · 5 copies in 3 functions · near-copies, 1 changing value · saves about 5 lines

`livePreviewHugeImageDrawLineShapes()` 19116, 19131 · `HugeImagesDrawLineShapes()` 21706, 21715 · `HugeImagesDrawParametricLines()` 21947

### 152. `thisOpacity := (BrushToolUseSecondaryColor=1) ? BrushToolBopacity : BrushToolAopacity ⏎ …`

3 lines · 5 copies in 5 functions · near-copies, 1 changing value · saves about 5 lines

`toggleBrushDeformers()` 78033 · `toggleBrushTypeEraser()` 78052 · `toggleBrushTypeFX()` 78077 · `togglePresetsBrushes()` 78134 · `toggleBrushTypeCloner()` 78216

### 153. `objSel.dw := imgSelW, objSel.dh := imgSelH ⏎ objSel.dx := imgSelPx, objSel.dy := imgSelPy ⏎ …`

3 lines · 5 copies in 5 functions · near-copies, 2 changing values · saves about 5 lines

`livePreviewHugeImageFillSelArea()` 18914 · `coreFillSelectedArea()` 19239 · `livePreviewEraseArea()` 52467 · `livePreviewSymmetricaImgArea()` 55875 · `livePreviewSimpleColorsAdjustImage()` 56100
