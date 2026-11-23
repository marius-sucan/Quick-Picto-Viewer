# Near-identical functions in quick-picto-viewer.ahk

Snapshot of 2026-11-23, commit b0a14d0 on `development`. Line numbers hold only for that commit.

The script has 2,664 functions. The 1,993 that have at least 5 code lines were compared with each other, pair by pair. No two of them are exact copies. **74 families** of near-copies hold **182 functions**. By the closeness of their first members: in 16 families (59 functions) only names and values differ, in 22 (48 functions) also up to 2 lines, and in 36 (75 functions) up to 3 lines in 10. Some families also hold looser members, marked by level.

Following the merge suggestions, and deleting the unused functions found on the way, would remove roughly **1,050 lines**. 25 entries suggest leaving the functions as they are. Eight functions have no reference anywhere in live code, and two more are reached only from those: see [Functions nothing calls](#unused).

[repeated-code-2026-10-28.md](repeated-code-2026-10-28.md) covers a different case: blocks repeated inside otherwise different functions.

## How the functions were compared

- **Code line**: a line of a function that is neither blank nor a comment. Comments at the end of a line, spacing, letter case and the optional comma after a command name are ignored (AutoHotkey names are not case-sensitive).
- **Names and values**: variable names, numbers and quoted strings. Function names and command names are not: a line that calls another function or runs another command counts as a different line.
- **Pairing lines**: the code lines of two functions are lined up in order, keeping as many pairs as possible. A pair is *identical* when both lines are the same, and *renamed* when they differ only in names and values. A line left without a partner is a *differing line*.
- **Levels** of closeness for two functions, from closest:
  1. only names and values differ: no differing lines;
  2. at most 2 differing lines in each function, and at most 1 in 5 lines of the longer one;
  3. at most 3 differing lines in 10 lines of the longer one.

  At every level the two functions share at least one identical line. Any number of names and values may change, so mirror twins such as `EditResizeWidth()` and `EditResizeHeight()` count.
- **Candidates**: a pair was lined up only when at least 7 in 10 of the longer function's lines, with names and values blanked out, also occur in the other function, and the two share one identical line. Every pair that reaches level 3 passes this test, so it drops none.
- **Family**: functions that are all within one level of *each other*, every pair, not a chain where A is like B and B is like C. Families were formed from the closest level outwards. A function that is within a looser level of every member of an existing family joins it, and its entry gives its level. Each function belongs to one family at most. A family's section is the level of its first members.

## How to read the entries

- **Base**: the function the others are compared with, marked *(base)*.
- **Reached through**: how the code refers to the function. This comes from a case-insensitive search of `quick-picto-viewer.ahk` and `lib/*.ahk`, comments and `/* */` blocks excluded. The kinds are:
  - *calls*: `name(`;
  - *menu*: `kMenu()` or `Menu, …, Add`;
  - *default key*: the `func2Call` table of `processDefaultKbdCombos()`;
  - *toolbar*: the `func2Call` table of `processToolbarFunctions()`;
  - *control*: a g-label, or a function named in `GuiAddSlider()`;
  - *button*: a temporary button made by `CreateTempGuiButton()` or `quickBarLater()`;
  - *timer*: `SetTimer`;
  - *string*: any other quoted name;
  - *mention*: the name inside a longer message, such as debug output. A mention does not call the function.
- **Differences**: `-` lines are the base's, `+` lines the other function's. `@@ 12345 / 12400 @@` gives the line where each side's part starts, with – for a side that has no lines there. In families of four or more, the functions that differ only in names and values are shown as a table of the changing values instead.
- **Saves**: the estimated net saving in lines, headers and closing braces included. It is the functions' lines now, minus the lines of the shared function and minus three lines for every function that has to keep its name. A one-for-one swap, where a name, value, operator or called function takes the place of another, becomes a parameter and costs nothing; the shared function is the base's lines plus about two lines for each place where the code differs in any other way. The three lines are a wrapper: header, call, closing brace.
  - A function keeps its name when anything other than a direct call reaches it. Menus, keys, the toolbar, g-labels, timers and buttons call functions by name, and custom keys and quick search store those names.
  - A menu passes the item name, position and menu name as the first three arguments, and a g-label passes the control's handle and event. A function reached that way cannot simply gain parameters.
  - When no function in a family is reached only by direct calls, one reached only by calls, timers, default keys or the toolbar can hold the shared code itself, because those call it without arguments.
  - Entries that suggest another shape, such as a helper for a shared frame or a deletion, give their own estimate.

## Overview

Ordered by section, then by size. *Lines* gives the code lines of each function, in the order listed. *Saves* is the estimated net saving in lines if the family is merged as suggested; a dash means the entry suggests leaving the functions as they are.

| # | Functions | Sec. | Lines | Saves | Suggestion |
|---:|---|:---:|---|---:|---|
| [1](#1) | `toggleQuickMoveActionKeys`, `toggleAutoReflectAnchors` and 21 more | 1 | 23 × 5–7 | 78 | one toggle helper; the 23 names stay as wrappers |
| [2](#2) | `getSQLdbPragmaValue`, `getMaxRowIDsqlDB`, `getTotalIMGsSQLdb` | 1 | 15, 14, 15 | 14 | one query helper |
| [3](#3) | `VPflipImgV`, `VPflipImgH` | 1 | 20, 20 | 16 | one function with an axis parameter |
| [4](#4) | `MenuSetVectAutoSymmetryX`, `MenuSetVectAutoSymmetryY` | 1 | 17, 17 | 19 | one function with an axis parameter |
| [5](#5) | `toggleErasePasteInPlace`, `togglePasteInPlaceColorsFX` and 3 more | 1 | 5 × 6–7 | 16 | one toggle helper for the paste panel |
| [6](#6) | `FirstPicture`, `LastPicture` | 1 | 13, 13 | 9 | one function, first or last |
| [7](#7) | `BtnCpyMvStrctrdChooseFilesDst`, `BtnCpyMvStrctrdChooseFilesSrc` | 1 | 13, 13 | 9 | one function, source or destination |
| [8](#8) | `BtnCollectImageInfos`, `BtnCollectHistoInfos` | 1 | 11, 11 | 7 | one function with two parameters |
| [9](#9) | `ActSortSize`, `ActSortModified`, `ActSortCreated` | 1 | 7, 7, 7 | 9 | one sort helper, also for [#13](#13) |
| [10](#10) | `ToggleColorProfileManage`, `ToggleRAWquality` | 1 | 10, 10 | 6 | one function, or the [#1](#1) helper |
| [11](#11) | `InvertSelectedArea`, `FlipSelectedAreaH`, `FlipSelectedAreaV` | 1 | 5, 5, 5 | 5 | one function with a mode |
| [12](#12) | `dummyResizeImageGDIwin`, `wrapResizeImageGDIwin` | 1 | 7, 7 | 6 | add a parameter |
| [13](#13) | `ActSortPath`, `ActSortFileName` | 1 | 7, 7 | 12 | the [#9](#9) helper |
| [14](#14) | `togglePasteInPlaceAdaptModes`, `togglePasteInPlaceCropShapes` | 1 | 6, 6 | – | leave as is |
| [15](#15) | `toggleAlphaGradientCenterReposition`, `toggleClrGradientCenterRepose` | 1 | 6, 6 | – | leave as is |
| [16](#16) | `MenuSelAllVectorPoints`, `MenuSelNoVectorPoints` | 1 | 5, 5 | – | leave as is |
| [17](#17) | `EditResizeWidth`, `EditResizeHeight` | 2 | 49, 49 | 45 | one function with a width/height switch |
| [18](#18) | `QPV_BlurBitmapFilters`, `QPV_DetectEdgesFilters` and 2 more | 2 | 19, 19, 19, 19 | 28 | a shared preamble for the DLL wrappers |
| [19](#19) | `QPV_ConvertToGrayscale`, `QPV_AdjustImageColors`, `QPV_ColorizeGrayImage` | 2 | 22, 22, 18 | 33 | the shared DLL preamble |
| [20](#20) | `readRecentOpenedFolderEntries`, `readRecentOpenedImagesEntries` | 2 | 25, 27 | 26 | one reader with a section parameter |
| [21](#21) | `decideIconBTNselectShape`, `decideIconBTNthumbsList`, `decideIconBTNpaintBrushSelect` | 2 | 16, 17, 15 | 19 | a shared icon setter |
| [22](#22) | `ImgVectorRedoAct`, `ImgVectorUndoAct` | 2 | 18, 18 | 14 | one function with a direction |
| [23](#23) | `omniBoxFolderCreateNew`, `omniBoxFolderRename` | 2 | 13, 13 | 9 | one function with the action |
| [24](#24) | `tlbrUndoAction`, `tlbrRedoAction` | 2 | 13, 13 | 12 | one function with a redo switch |
| [25](#25) | `PreviousPicture`, `NextPicture` | 2 | 11, 11 | 7 | one function with a direction |
| [26](#26) | `BtnNextImg`, `BtnPrevImg` | 2 | 11, 11 | 7 | one function with a direction |
| [27](#27) | `browseExternalApp`, `browseExternalEditApp` | 2 | 10, 10 | 6 | one function, viewer or editor |
| [28](#28) | `isVarEqualTo`, `varContains` | 2 | 10, 10 | – | leave as is |
| [29](#29) | `TglRszRotation`, `TglRszCropping` | 2 | 10, 10 | 6 | one function with a mode |
| [30](#30) | `ToggleWICloader`, `ToggleFIMloader` | 2 | 7, 7 | – | leave as is |
| [31](#31) | `UIfilterListKeywords`, `UIfilterListViewStaticFolderzList` | 2 | 7, 7 | 6 | one function with three parameters |
| [32](#32) | `extraDummyReloadThisPicture`, `extraDummyDelayiedImageDisplay` | 2 | 6, 6 | – | leave as is |
| [33](#33) | `coreReloadThisPicture`, `DelayiedImageDisplay` | 2 | 6, 6 | – | leave as is |
| [34](#34) | `GuiAddCloseOnApply`, `GuiAddToggleLivePreview` | 2 | 5, 5 | – | leave as is |
| [35](#35) | `updateLabelSlidesSpeed`, `updateLabelGIFdelay` | 2 | 5, 5 | – | leave as is |
| [36](#36) | `throwErrorAllSelectedInvert`, `throwWarningAlphaPaintMode` | 2 | 5, 5 | – | leave as is |
| [37](#37) | `BtnNextToneMapPic`, `BtnPrevToneMapPic` | 2 | 5, 5 | – | leave as is |
| [38](#38) | `CustomObjToString`, `CustomaObjToString` | 2 | 5, 5 | 14 | delete both |
| [39](#39) | `batchSimpleProcessing`, `batchSimpleColorsAdjusts` | 3 | 113, 97 | 77 | one batch loop with a per-file step |
| [40](#40) | `calcIMGcoordsInVP`, `simulateCalcImageCoordsInVP` | 3 | 95, 84 | 86 | delete the unused copy |
| [41](#41) | `PlotSeenHourStatsNow`, `PlotSeenMonthsStatsNow` | 3 | 67, 81 | 37 | one chart function with a mode |
| [42](#42) | `SearchIndexSelectAll`, `SelectFilesDead` | 3 | 58, 58 | 24 | one selection loop with a per-file test |
| [43](#43) | `QPV_PrepareAlphaChannelBlur`, `QPV_AlterAlphaChannel` and 2 more | 3 | 21, 23, 23, 21 | 61 | delete one; the shared DLL preamble |
| [44](#44) | `QPV_PolarTransformBitmap`, `QPV_ZoomBlurBitmap` | 3 | 38, 50 | 32 | one function, or the shared preamble |
| [45](#45) | `coreAutoColorsFileProcessing`, `coreAutoCropFileProcessing` | 3 | 42, 39 | 28 | a shared load-and-save frame |
| [46](#46) | `updateSQLdbEntryImgRes`, `updateSQLdbEntryFileInfos`, `updateSQLdbEntryImgHisto` | 3 | 25, 18, 24 | 30 | a shared update tail |
| [47](#47) | `testus`, `testus2` | 3 | 31, 27 | 62 | delete both |
| [48](#48) | `VPchangeSaturation`, `VPchangeRealGamma` | 3 | 25, 29 | 14 | one function with the value and its range |
| [49](#49) | `HSL_Hue`, `HSL_Sat` | 3 | 23, 23 | – | leave as is |
| [50](#50) | `trGdip_CloneBitmapArea`, `trGdip_CloneBitmap` | 3 | 23, 21 | 16 | one function with a mode, or a shared tail |
| [51](#51) | `RecordUsedFiltersManager`, `RecordUsedMultiRenamesQueriesManager` | 3 | 23, 20 | 13 | one recent-list writer |
| [52](#52) | `LoadPrefsFromSLD`, `WritePrefsIntoSLD` | 3 | 20, 19 | 10 | one function, load or save |
| [53](#53) | `tzGdip_DrawImageFast`, `tzGdip_DrawImage` | 3 | 17, 20 | 14 | a shared interpolation guard |
| [54](#54) | `QPV_SetColorAlphaChannel`, `QPV_FloodFill` | 3 | 16, 20 | 20 | the shared DLL preamble |
| [55](#55) | `ImgSelUndoAct`, `ImgSelRedoAct` | 3 | 17, 17 | 10 | one function with a direction |
| [56](#56) | `RecordFoldersOpenedManager`, `RecordImagesOpenedManager` | 3 | 16, 16 | 12 | one recent-list writer |
| [57](#57) | `BtnEraseSelectedArea`, `BtnGraySelectedArea` | 3 | 16, 16 | 15 | one function with three parameters |
| [58](#58) | `tlbrFillShape`, `tlbrDrawShapesContour` | 3 | 13, 15 | – | leave as is |
| [59](#59) | `initWorkLoadMultiCoresJpegLL`, `initWorkLoadMultiCoresSimpleImgProcessing` | 3 | 13, 13 | – | leave as is |
| [60](#60) | `decideIconBTNmainTooler`, `decideIconBTNvectToolModes` | 3 | 14, 12 | 26 | delete one; shared icon setter |
| [61](#61) | `clearAllFavedFolders`, `eraseAllFavedIMGs` | 3 | 10, 13 | – | leave as is |
| [62](#62) | `trGdip_BitmapConvertGray`, `trGdip_BlurBitmap` | 3 | 11, 11 | 13 | delete the unused one |
| [63](#63) | `OpenWithDefaultApp`, `OpenFileProperties` | 3 | 11, 10 | – | leave as is |
| [64](#64) | `trGdip_CreateBitmap`, `trGdip_CreateBitmapFromHBITMAP` | 3 | 10, 10 | – | leave as is |
| [65](#65) | `folderTreePasteFoldersInto`, `folderTreePasteClippy` | 3 | 9, 10 | – | leave as is |
| [66](#66) | `filterDelayiedImageDisplay`, `writeMainSettingsApp` | 3 | 9, 9 | – | leave as is |
| [67](#67) | `omniBoxFoldersPaste`, `omniBoxFolderPasteClippy` | 3 | 10, 8 | – | leave as is |
| [68](#68) | `ActSortHistogram`, `ActSortImageProperties` | 3 | 9, 9 | 7 | one function with a kind |
| [69](#69) | `ToggleToolBarValign`, `toggleToolbarTwoColumns` | 3 | 10, 8 | – | leave as is |
| [70](#70) | `RandomPicture`, `PrevRandyPicture` | 3 | 9, 8 | – | leave as is |
| [71](#71) | `BtnBlurSelectedArea`, `BtnZoomBlurSelectedArea` | 3 | 8, 8 | – | leave as is |
| [72](#72) | `defineListViewModes`, `defineHistogramMode` | 3 | 9, 7 | – | leave as is |
| [73](#73) | `testIsBezierAltViewPathClosed`, `testBezierFirstLastPointsCollapsed` | 3 | 7, 8 | 10 | delete the unused one |
| [74](#74) | `MenuRemNowFilesListFilter`, `BTNuiDiscardFilesFilter` | 3 | 6, 8 | – | leave as is |

## Section 1: only names and values differ

Every line of one function has a partner in the other: the functions differ only in names, numbers and strings.

<a id="1"></a>
### 1. `toggleQuickMoveActionKeys`, `toggleAutoReflectAnchors` and 21 more

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `toggleQuickMoveActionKeys()` | 47392–47398 | 5 | 2 | menu, toolbar |
| `toggleAutoReflectAnchors()` | 50944–50950 | 5 | 2 | menu ×3, default key, toolbar |
| `ToggleAllonTop()` | 73472–73479 | 6 | 2 | menu |
| `ToggleSlidesFXmode()` (base) | 73481–73487 | 5 | 1 | menu |
| `ToggleGIFsPlayEntirely()` | 73499–73506 | 6 | 2 | menu |
| `ToggleSkipSeenIMGs()` | 73522–73528 | 5 | 1 | menu |
| `ToggleAutoPlaySND()` | 73587–73593 | 5 | 1 | menu |
| `ToggleSyncSlide2sndDuration()` | 73595–73601 | 5 | 1 | menu |
| `ToggleSlidesTransitions()` | 73603–73609 | 5 | 1 | menu |
| `TglRvrSort()` | 73633–73639 | 5 | 1 | menu |
| `TglCheckDeadFilesSort()` | 73641–73647 | 5 | 1 | menu |
| `ToggleRecordOpenHistory()` | 74203–74211 | 5 | 1 | menu |
| `ToggleAnimGIFsupport()` | 74314–74320 | 5 | 1 | menu |
| `ToggleAutoRemEntries()` | 74355–74361 | 5 | 1 | menu ×2 |
| `TogglePromptDelete()` | 74363–74369 | 5 | 1 | menu |
| `ToggleCustomKBDsMode()` | 74470–74477 | 6 | 2 | 2 calls, menu |
| `ToggleThumbsCaching()` | 74675–74681 | 5 | 1 | menu |
| `ToggleSkipDeadFiles()` | 74690–74696 | 5 | 1 | menu |
| `ToggleFilesMap()` | 74698–74704 | 5 | 1 | menu, toolbar |
| `ToggleCycleFavesOpen()` | 74722–74728 | 5 | 2 | menu |
| `ToggleAutoPlaySlidesMusic()` | 74863–74869 | 5 | 1 | menu |
| `toggleLockZoom()` | 74871–74878 | 5 | 2 | menu |
| `ToggleImgColorDepthDithering()` | 74919–74928 | 7 | 3 | menu ×2 |

The code of `ToggleSlidesFXmode()`, with the changing values marked ‹1›, ‹2›, ‹3›:

```autohotkey
‹1› := !‹1›
INIaction(1, ‹2›, "General")
friendly := (‹1›=1) ? "ACTIVATED" : "DEACTIVATED"
showTOOLtip(‹3› friendly, A_ThisFunc, 1)
SetTimer, RemoveTooltip, % -msgDisplayTime
```

| Function | ‹1› | ‹2› | ‹3› |
|---|---|---|---|
| `ToggleSlidesFXmode()` | `slidesFXrandomize` | `"slidesFXrandomize"` | `` "Randomize colour FX during slideshows:`n" `` |
| `ToggleSkipSeenIMGs()` | `skipSeenImageSlides` | `"skipSeenImageSlides"` | `"Skip already seen images: "` |
| `ToggleAutoPlaySND()` | `autoPlaySNDs` | `"autoPlaySNDs"` | `"Auto-play associated sound file: "` |
| `ToggleSyncSlide2sndDuration()` | `syncSlideShow2Audios` | `"syncSlideShow2Audios"` | `` "Wait for complete playback of audio files during slideshows:`n" `` |
| `ToggleSlidesTransitions()` | `doSlidesTransitions` | `"doSlidesTransitions"` | `"Smooth slideshow transitions: "` |
| `TglRvrSort()` | `reverseOrderOnSort` | `"reverseOrderOnSort"` | `"Reverse order on files list sort: "` |
| `TglCheckDeadFilesSort()` | `OnSortdoFilesCheck` | `"OnSortdoFilesCheck"` | `"Auto-remove inexistent files on files list sort: "` |
| `ToggleRecordOpenHistory()` | `allowRecordHistory` | `"allowRecordHistory"` | `"Record history of opened files and folders: "` |
| `ToggleAnimGIFsupport()` | `animGIFsSupport` | `"animGIFsSupport"` | `"Automatically play animations: "` |
| `ToggleAutoRemEntries()` | `autoRemDeadEntry` | `"autoRemDeadEntry"` | `"Automatically remove entries to inexistent files: "` |
| `TogglePromptDelete()` | `askDeleteFiles` | `"askDeleteFiles"` | `"Prompt before deleting files: "` |
| `ToggleThumbsCaching()` | `enableThumbsCaching` | `"enableThumbsCaching"` | `"Image thumbnails caching on disk: "` |
| `ToggleSkipDeadFiles()` | `skipDeadFiles` | `"skipDeadFiles"` | `"Skip inexistent files in image view: "` |
| `ToggleFilesMap()` | `showFilesListMap` | `"showFilesListMap"` | `"Display selected files list map on scrollbar click: "` |
| `ToggleAutoPlaySlidesMusic()` | `autoPlaySlidesAudio` | `"autoPlaySlidesAudio"` | `"Automatically play music during slideshows: "` |

`toggleQuickMoveActionKeys()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 47393 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+allowUserQuickFileActions := !allowUserQuickFileActions
+friendly := (allowUserQuickFileActions=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Quick file action shortcuts: " friendly, A_ThisFunc, 1)
+IniAction(1, "allowUserQuickFileActions", "General")
```

`toggleAutoReflectAnchors()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 50945 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+autoReflectVectorAnchors := !autoReflectVectorAnchors
+RegAction(1, "autoReflectVectorAnchors")
+friendly := (autoReflectVectorAnchors=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Automatically reflect anchors: " friendly, A_ThisFunc, 1)
```

`ToggleAllonTop()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 73473 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+isAlwaysOnTop := !isAlwaysOnTop
+WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
+INIaction(1, "isAlwaysOnTop", "General")
+friendly := (isAlwaysOnTop=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Window always on top: " friendly, A_ThisFunc, 1)
```

`ToggleGIFsPlayEntirely()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 73500 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+GIFframesPlayied := 0
+allowGIFsPlayEntirely := !allowGIFsPlayEntirely
+INIaction(1, "allowGIFsPlayEntirely", "General")
+friendly := (allowGIFsPlayEntirely=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Allow animations play entirely during slideshows:`n" friendly, A_ThisFunc, 1)
```

`ToggleCustomKBDsMode()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 74471 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+allowCustomKeys := !allowCustomKeys
+INIaction(1, "allowCustomKeys", "General")
+friendly := (allowCustomKeys=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("User customized keyboard shortcuts: " friendly, A_ThisFunc, 1)
+loadCustomUserKbds()
```

`ToggleCycleFavesOpen()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 74723 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+cycleFavesOpenIMG := !cycleFavesOpenIMG
+INIaction(1, "cycleFavesOpenIMG", "General")
+friendly := (cycleFavesOpenIMG=1) ? "The favourites list will be opened when one of the 15 entries is opened." : "The containing folder of the favourite image will be opened."
+showTOOLtip(friendly, A_ThisFunc, 1)
```

`toggleLockZoom()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 74872 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+lockZoomLevel := !lockZoomLevel
+customZoomAdaptMode := 0
+friendly := (lockZoomLevel=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Lock to current zoom level: " friendly, A_ThisFunc, 1)
```

`ToggleImgColorDepthDithering()` against `ToggleSlidesFXmode()`:

```diff
@@ 73482 / 74920 @@
-slidesFXrandomize := !slidesFXrandomize
-INIaction(1, "slidesFXrandomize", "General")
-friendly := (slidesFXrandomize=1) ? "ACTIVATED" : "DEACTIVATED"
-showTOOLtip("Randomize colour FX during slideshows:`n" friendly, A_ThisFunc, 1)
+ColorDepthDithering := !ColorDepthDithering
+INIaction(1, "ColorDepthDithering", "General")
+If (thumbsDisplaying!=1)
+   RefreshImageFile()
+friendly := (ColorDepthDithering=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Color depth dithering: " friendly, A_ThisFunc, 1)
```

**Merge suggestion.** One helper, for example `toggleSettingTip(funcName, varName, label, store:="ini", onText:="ACTIVATED", offText:="DEACTIVATED")`. It flips the global named by `varName` (`%varName% := !%varName%`, the way `INIaction()` already reads it), saves it with `INIaction()`, with `RegAction()` when `store` is "reg" (`toggleAutoReflectAnchors()`) or not at all when it is "" (`toggleLockZoom()`, whose `INIaction()` line is commented out), and shows the tooltip. `funcName` carries the caller's `A_ThisFunc` for `showTOOLtip()`; `onText` and `offText` cover `ToggleCycleFavesOpen()`, which shows two sentences instead. The 23 functions stay, each as a three-line wrapper, because menus, default keys and the toolbar call them by name. Five wrappers keep their extra line: `WinSet, AlwaysOnTop` in `ToggleAllonTop()`, `GIFframesPlayied := 0` in `ToggleGIFsPlayEntirely()`, `loadCustomUserKbds()` in `ToggleCustomKBDsMode()`, `customZoomAdaptMode := 0` in `toggleLockZoom()`, and the image refresh in `ToggleImgColorDepthDithering()`. The same helper, with an `onText` that warns about speed, serves [#10](#10).

**Saves** about 78 lines.

<a id="2"></a>
### 2. `getSQLdbPragmaValue`, `getMaxRowIDsqlDB`, `getTotalIMGsSQLdb`

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `getSQLdbPragmaValue()` (base) | 88699–88718 | 15 | 1 | 1 call |
| `getMaxRowIDsqlDB()` | 88720–88738 | 14 | 3 | 17 calls |
| `getTotalIMGsSQLdb()` | 88740–88759 | 15 | 1 | 10 calls |

`getMaxRowIDsqlDB()` against `getSQLdbPragmaValue()`:

```diff
@@ 88701 / 88722 @@
-SQL := "PRAGMA " pragmau ";"
+SQL := "SELECT max(imgidu) FROM images;"
@@ 88708 / – @@
-value := 0
@@ 88713 / 88733 @@
-       value := Rowu[1]
+       sqlDBrowID := Rowu[1] + 1
@@ 88717 / 88737 @@
-Return value
+Return sqlDBrowID
```

`getTotalIMGsSQLdb()` against `getSQLdbPragmaValue()`:

```diff
@@ 88701 / 88742 @@
-SQL := "PRAGMA " pragmau ";"
+SQL := "SELECT COUNT(*) FROM images " morus ";"
```

**Merge suggestion.** Make `getSQLdbPragmaValue()` a general `getSQLdbNumber(SQL)` that runs any query and returns the numeric value of the first column. `getTotalIMGsSQLdb(morus)` then becomes a three-line wrapper around it (it has 10 callers), and the one caller of the pragma variant passes `"PRAGMA " x ";"`. `getMaxRowIDsqlDB()` (17 callers) can join with a five-line wrapper, about 10 lines more, but it differs in what it returns: it sets the global `sqlDBrowID` to the value + 1 and returns that, and when the query gives no number it returns the previous `sqlDBrowID`, not 0.

**Saves** about 14 lines.

<a id="3"></a>
### 3. `VPflipImgV`, `VPflipImgH`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `VPflipImgV()` (base) | 12573–12596 | 20 | menu, default key, toolbar ×2 |
| `VPflipImgH()` | 12618–12641 | 20 | menu, default key, toolbar ×2 |

`VPflipImgH()` against `VPflipImgV()`:

```diff
@@ 12584 / 12629 @@
-FlipImgV := !FlipImgV
-friendly := (FlipImgV=1) ? "ON" : "off"
-showTOOLtip("Vertical mirroring: " friendly, A_ThisFunc, 1)
+FlipImgH := !FlipImgH
+friendly := (FlipImgH=1) ? "ON" : "off"
+showTOOLtip("Horizontal mirroring: " friendly, A_ThisFunc, 1)
@@ 12588 / 12633 @@
-INIaction(1, "FlipImgV", "General")
+INIaction(1, "FlipImgH", "General")
@@ 12592 / 12637 @@
-   GuiControl, SettingsGUIA:, FlipImgV, % FlipImgV
+   GuiControl, SettingsGUIA:, FlipImgH, % FlipImgH
```

**Merge suggestion.** One `VPflipImage(funcName, axis)` with "V" or "H": the axis picks the variable (`FlipImgV`, `FlipImgH`) and the message. Both names stay as wrappers (menu, default keys). One behaviour change to weigh: the `Static lastInvoked` 50 ms guard would become shared, so a vertical flip right after a horizontal one would be dropped.

**Saves** about 16 lines: 44 now, 22 for the shared function, 6 for the named functions that stay.

<a id="4"></a>
### 4. `MenuSetVectAutoSymmetryX`, `MenuSetVectAutoSymmetryY`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `MenuSetVectAutoSymmetryX()` (base) | 79305–79328 | 17 | 1 call |
| `MenuSetVectAutoSymmetryY()` | 79330–79351 | 17 | 1 call |

`MenuSetVectAutoSymmetryY()` against `MenuSetVectAutoSymmetryX()`:

```diff
@@ 79326 / 79349 @@
-configVectorShapeSymmetryPoint("x", 0, pp, 1)
+configVectorShapeSymmetryPoint("y", 0, pp, 1)
```

**Merge suggestion.** One `MenuSetVectAutoSymmetry(axis)`; each of the two callers passes "x" or "y". The long comment at the top of the X variant then covers both.

**Saves** about 19 lines: 38 now, 19 for the shared function.

<a id="5"></a>
### 5. `toggleErasePasteInPlace`, `togglePasteInPlaceColorsFX` and 3 more

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `toggleErasePasteInPlace()` | 48908–48915 | 6 | 2 | menu, default key, toolbar ×2 |
| `togglePasteInPlaceColorsFX()` (base) | 48925–48932 | 6 | 1 | menu, default key, toolbar |
| `togglePasteInPlaceCropNone()` | 48943–48950 | 6 | 1 | menu |
| `FlipVtransformedIMGpanel()` | 48952–48959 | 6 | 1 | default key, toolbar |
| `FlipHtransformedIMGpanel()` | 48961–48969 | 7 | 2 | default key, toolbar |

The code of `togglePasteInPlaceColorsFX()`, with the changing values marked ‹1›, ‹2›, ‹3›:

```autohotkey
If (AnyWindowOpen=31 || AnyWindowOpen=24)
{
   ‹1› := !‹1›
   GuiControl, SettingsGUIA:, ‹1›, % ‹1›
   updateUIpastePanel()
}
```

| Function | ‹1› |
|---|---|
| `togglePasteInPlaceColorsFX()` | `PasteInPlaceApplyColorFX` |
| `togglePasteInPlaceCropNone()` | `PasteInPlaceCropDo` |
| `FlipVtransformedIMGpanel()` | `PasteInPlaceOrientFlipY` |

`toggleErasePasteInPlace()` against `togglePasteInPlaceColorsFX()`:

```diff
@@ 48926 / 48909 @@
-If (AnyWindowOpen=31 || AnyWindowOpen=24)
+If ((AnyWindowOpen=31 || AnyWindowOpen=24) && PasteInPlaceToolMode=1)
@@ 48928 / 48911 @@
-   PasteInPlaceApplyColorFX := !PasteInPlaceApplyColorFX
-   GuiControl, SettingsGUIA:, PasteInPlaceApplyColorFX, % PasteInPlaceApplyColorFX
+   PasteInPlaceEraseInitial := !PasteInPlaceEraseInitial
+   GuiControl, SettingsGUIA:, PasteInPlaceEraseInitial, % PasteInPlaceEraseInitial
```

`FlipHtransformedIMGpanel()` against `togglePasteInPlaceColorsFX()`:

```diff
@@ – / 48962 @@
+Static kl := {4:3, 3:4, 2:1, 1:2}
@@ 48928 / 48965 @@
-   PasteInPlaceApplyColorFX := !PasteInPlaceApplyColorFX
-   GuiControl, SettingsGUIA:, PasteInPlaceApplyColorFX, % PasteInPlaceApplyColorFX
+   PasteInPlaceOrientFlipX := !PasteInPlaceOrientFlipX
+   GuiControl, SettingsGUIA:, PasteInPlaceOrientFlipX, % PasteInPlaceOrientFlipX
```

**Merge suggestion.** One `togglePasteInPlaceOption(varName, onlyInToolMode:=0)` that flips the variable, updates its checkbox and calls `updateUIpastePanel()`; `onlyInToolMode` adds the `PasteInPlaceToolMode=1` test of `toggleErasePasteInPlace()`. The five names stay as wrappers (menus, default keys). `FlipHtransformedIMGpanel()` also declares a `Static kl` that it never reads.

**Saves** about 16 lines: 41 now, 13 for the shared function, 12 for the named functions that stay.

<a id="6"></a>
### 6. `FirstPicture`, `LastPicture`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `FirstPicture()` (base) | 4349–4365 | 13 | 1 call, menu ×2, default key, toolbar |
| `LastPicture()` | 4367–4383 | 13 | 1 call, menu ×2, default key, toolbar |

`LastPicture()` against `FirstPicture()`:

```diff
@@ 4354 / 4372 @@
-If (maxFilesIndex>1 && currentFileIndex!=1 && thumbsDisplaying!=1)
+If (maxFilesIndex>1 && currentFileIndex!=maxFilesIndex && thumbsDisplaying!=1)
@@ 4361 / 4379 @@
-currentFileIndex := 1
+currentFileIndex := maxFilesIndex
```

**Merge suggestion.** One `jumpToEdgePicture(which)` with "first" or "last". The target index has to be read inside the function, after `doOpenStartFolder()` may have changed `maxFilesIndex`, so the parameter names the end, not the index. Both names stay as wrappers (menus, default keys).

**Saves** about 9 lines: 30 now, 15 for the shared function, 6 for the named functions that stay.

<a id="7"></a>
### 7. `BtnCpyMvStrctrdChooseFilesDst`, `BtnCpyMvStrctrdChooseFilesSrc`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `BtnCpyMvStrctrdChooseFilesDst()` (base) | 60674–60690 | 13 | control |
| `BtnCpyMvStrctrdChooseFilesSrc()` | 60692–60708 | 13 | control |

`BtnCpyMvStrctrdChooseFilesSrc()` against `BtnCpyMvStrctrdChooseFilesDst()`:

```diff
@@ 60680 / 60698 @@
-p := FolderExist(destDir) ? destDir : srcDir
+p := FolderExist(srcDir) ? srcDir : destDir
@@ 60684 / 60702 @@
-SelectedDir := openFoldersDialogWrapper(p, "Select the destination folder")
+SelectedDir := openFoldersDialogWrapper(p, "Select the source folder")
@@ 60687 / 60705 @@
-   GuiControl, SettingsGUIA:, UsrEditFileDestination, % SelectedDir
+   GuiControl, SettingsGUIA:, UsrEditFileSource, % SelectedDir
```

**Merge suggestion.** One function with an `isSource` parameter that picks the folder tried first, the dialog title and the edit control to fill. Both names stay as wrappers, because they are control g-labels.

**Saves** about 9 lines: 30 now, 15 for the shared function, 6 for the named functions that stay.

<a id="8"></a>
### 8. `BtnCollectImageInfos`, `BtnCollectHistoInfos`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `BtnCollectImageInfos()` (base) | 37481–37494 | 11 | menu, control |
| `BtnCollectHistoInfos()` | 37496–37509 | 11 | menu, control |

`BtnCollectHistoInfos()` against `BtnCollectImageInfos()`:

```diff
@@ 37485 / 37500 @@
-   collectSQLFileInfosNow("imgmegapix", 0, 0)
+   collectSQLFileInfosNow("pixelzFsmall", 0, 0)
@@ 37487 / 37502 @@
-   collectImageInfosNow(0, 9, 1)
+   collectImageInfosNow(0, 11, 1)
```

**Merge suggestion.** One function taking the database column ("imgmegapix", "pixelzFsmall") and the `collectImageInfosNow()` mode (9, 11). Both names stay as wrappers (control g-labels, menus).

**Saves** about 7 lines: 26 now, 13 for the shared function, 6 for the named functions that stay.

<a id="9"></a>
### 9. `ActSortSize`, `ActSortModified`, `ActSortCreated`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ActSortSize()` (base) | 37649–37657 | 7 | menu, default key |
| `ActSortModified()` | 37688–37696 | 7 | menu, default key |
| `ActSortCreated()` | 37698–37706 | 7 | menu, default key |

`ActSortModified()` against `ActSortSize()`:

```diff
@@ 37652 / 37691 @@
-   dbSortingCached("fsize", 1)
+   dbSortingCached("fmodified", 1)
@@ 37654 / 37693 @@
-   SortFilesList("size", 1)
-etaTime := "Elapsed time to sort files list by file size: " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
+   SortFilesList("modified", 1)
+etaTime := "Elapsed time to sort files list by file modified date: " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
```

`ActSortCreated()` against `ActSortSize()`:

```diff
@@ 37652 / 37701 @@
-   dbSortingCached("fsize", 1)
+   dbSortingCached("fcreated", 1)
@@ 37654 / 37703 @@
-   SortFilesList("size", 1)
-etaTime := "Elapsed time to sort files list by file size: " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
+   SortFilesList("created", 1)
+etaTime := "Elapsed time to sort files list by file created date: " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
```

**Merge suggestion.** One `ActSortByField(dbColumn, sortKey, label, needsCache:=1)` serves these three and the two of [#13](#13). `needsCache` covers the one real difference between the two families: here the database sort runs only when `useCachedSLDdata=1`, there whenever `SLDtypeLoaded=3`. The names stay as wrappers (menus, default keys).

**Saves** about 9 lines: 27 now, 9 for the shared function, 9 for the named functions that stay.

<a id="10"></a>
### 10. `ToggleColorProfileManage`, `ToggleRAWquality`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ToggleColorProfileManage()` (base) | 74730–74742 | 10 | menu ×2 |
| `ToggleRAWquality()` | 74802–74814 | 10 | menu |

`ToggleRAWquality()` against `ToggleColorProfileManage()`:

```diff
@@ 74731 / 74803 @@
-userPerformColorManagement := !userPerformColorManagement
-INIaction(1, "userPerformColorManagement", "General")
+userHQraw := !userHQraw
+INIaction(1, "userHQraw", "General")
@@ 74735 / 74807 @@
-   GuiControl, SettingsGUIA:, userPerformColorManagement, % userPerformColorManagement
+   GuiControl, SettingsGUIA:, userHQraw, % userHQraw
@@ 74739 / 74811 @@
-friendly := (userPerformColorManagement=1) ? "ACTIVATED`nThe viewport performance may decrease." : "DEACTIVATED"
-showTOOLtip("Color management on image load: " friendly, A_ThisFunc, 1)
+friendly := (userHQraw=1) ? "ACTIVATED" : "DEACTIVATED"
+showTOOLtip("Load Camera RAW images at high quality: " friendly, A_ThisFunc, 1)
```

**Merge suggestion.** One function taking the variable name, the message and the «ACTIVATED» text (only the colour-management one warns about speed). Both names stay as wrappers (menus). It can also be the helper of [#1](#1) plus the panel 42 update.

**Saves** about 6 lines: 24 now, 12 for the shared function, 6 for the named functions that stay.

<a id="11"></a>
### 11. `InvertSelectedArea`, `FlipSelectedAreaH`, `FlipSelectedAreaV`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `InvertSelectedArea()` (base) | 19921–19927 | 5 | menu ×2, default key, toolbar |
| `FlipSelectedAreaH()` | 19933–19939 | 5 | menu ×3, default key, toolbar ×2 |
| `FlipSelectedAreaV()` | 19941–19947 | 5 | menu ×3, default key, toolbar ×2 |

`FlipSelectedAreaH()` against `InvertSelectedArea()`:

```diff
@@ 19923 / 19935 @@
-   HugeImagesFlipHVinvert("i")
+   HugeImagesFlipHVinvert("h")
@@ 19925 / 19937 @@
-   EraseOrInvertOrGraySelectedArea("invert", A_ThisFunc)
+   EraseOrInvertOrGraySelectedArea("flip-h", A_ThisFunc)
```

`FlipSelectedAreaV()` against `InvertSelectedArea()`:

```diff
@@ 19923 / 19943 @@
-   HugeImagesFlipHVinvert("i")
+   HugeImagesFlipHVinvert("v")
@@ 19925 / 19945 @@
-   EraseOrInvertOrGraySelectedArea("invert", A_ThisFunc)
+   EraseOrInvertOrGraySelectedArea("flip-v", A_ThisFunc)
```

**Merge suggestion.** One function taking the two mode strings ("i"/"invert", "h"/"flip-h", "v"/"flip-v") and the caller's name, because `A_ThisFunc` goes to `EraseOrInvertOrGraySelectedArea()`. The three names stay as wrappers (menus, default keys), so the gain is small.

**Saves** about 5 lines: 21 now, 7 for the shared function, 9 for the named functions that stay.

<a id="12"></a>
### 12. `dummyResizeImageGDIwin`, `wrapResizeImageGDIwin`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `dummyResizeImageGDIwin()` (base) | 12031–12039 | 7 | 10 calls, timer |
| `wrapResizeImageGDIwin()` | 79265–79273 | 7 | 1 call, timer ×6 |

`wrapResizeImageGDIwin()` against `dummyResizeImageGDIwin()`:

```diff
@@ 12036 / 79270 @@
-   r := ResizeImageGDIwin(imgPath, 0, 0)
+   r := ResizeImageGDIwin(imgPath, 2, 0)
```

**Merge suggestion.** Give `dummyResizeImageGDIwin()` a parameter for the second argument of `ResizeImageGDIwin()` (default 0, which also suits its `SetTimer` use) and reduce `wrapResizeImageGDIwin()` to a three-line wrapper that passes 2; it has to stay because six `SetTimer` lines name it.

**Saves** about 6 lines: 18 now, 9 for the shared function, 3 for the named functions that stay.

<a id="13"></a>
### 13. `ActSortPath`, `ActSortFileName`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ActSortPath()` (base) | 37659–37667 | 7 | menu, default key |
| `ActSortFileName()` | 37678–37686 | 7 | menu, default key |

`ActSortFileName()` against `ActSortPath()`:

```diff
@@ 37662 / 37681 @@
-   dbSortingCached("imgfolder", 1)
+   dbSortingCached("imgfile", 1)
@@ 37664 / 37683 @@
-   SortFilesList("name-folder", 1)
-etaTime := "Elapsed time to sort files list by folder name: " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
+   SortFilesList("name-file", 1)
+etaTime := "Elapsed time to sort files list by file name: " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
```

**Merge suggestion.** Both become wrappers of the helper suggested in [#9](#9), with `needsCache` set to 0. The saving assumes that helper exists.

**Saves** about 12 lines.

<a id="14"></a>
### 14. `togglePasteInPlaceAdaptModes`, `togglePasteInPlaceCropShapes`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `togglePasteInPlaceAdaptModes()` (base) | 48899–48906 | 6 | menu, default key, toolbar |
| `togglePasteInPlaceCropShapes()` | 48934–48941 | 6 | menu, default key, toolbar |

`togglePasteInPlaceCropShapes()` against `togglePasteInPlaceAdaptModes()`:

```diff
@@ 48902 / 48937 @@
-   PasteInPlaceAdaptMode := clampInRange(PasteInPlaceAdaptMode + 1, 1, 3, 1)
-   GuiControl, SettingsGUIA: Choose, PasteInPlaceAdaptMode, % PasteInPlaceAdaptMode
+   PasteInPlaceCropSel := clampInRange(PasteInPlaceCropSel + 1, 1, 7, 1)
+   GuiControl, SettingsGUIA: Choose, PasteInPlaceCropSel, % PasteInPlaceCropSel
```

**Merge suggestion.** The shared code is six lines and both names have to stay for their menus and default keys; a shared function saves about 2 lines. Leave as is.

<a id="15"></a>
### 15. `toggleAlphaGradientCenterReposition`, `toggleClrGradientCenterRepose`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `toggleAlphaGradientCenterReposition()` (base) | 71303–71310 | 6 | menu |
| `toggleClrGradientCenterRepose()` | 71325–71332 | 6 | menu ×2 |

`toggleClrGradientCenterRepose()` against `toggleAlphaGradientCenterReposition()`:

```diff
@@ 71304 / 71326 @@
-userAllowClrGradientRecenter := 0
-userAllowsGradientRecentering := !userAllowsGradientRecentering
-friendly := (userAllowsGradientRecentering=1) ? "ACTIVATED" : "DEACTIVATED"
-friendly2 := (userAllowsGradientRecentering=1) ? "`nClick and drag inside the selection area to adjust the center" : ""
-showTOOLtip("Alpha mask gradient center repositioning: " friendly friendly2, A_ThisFunc, 1)
+userAllowsGradientRecentering := 0
+userAllowClrGradientRecenter := !userAllowClrGradientRecenter
+friendly := (userAllowClrGradientRecenter=1) ? "ACTIVATED" : "DEACTIVATED"
+friendly2 := (userAllowClrGradientRecenter=1) ? "`nClick and drag inside the selection area to adjust the center" : ""
+showTOOLtip("Color gradient center repositioning: " friendly friendly2, A_ThisFunc, 1)
```

**Merge suggestion.** The two swap the same pair of variables; a shared function saves about 2 lines once both menu entries keep their names. Leave as is.

<a id="16"></a>
### 16. `MenuSelAllVectorPoints`, `MenuSelNoVectorPoints`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `MenuSelAllVectorPoints()` (base) | 7030–7038 | 5 | 1 call, menu |
| `MenuSelNoVectorPoints()` | 7040–7048 | 5 | 2 calls, menu ×2, default key, toolbar, timer |

`MenuSelNoVectorPoints()` against `MenuSelAllVectorPoints()`:

```diff
@@ 7032 / 7042 @@
-    customShapePropPoints[A_Index, 1] := 1
-customShapeHasSelectedPoints := 1
-msgBeepTimer("Selected all " groupDigits(customShapePoints.Count()) " path points", 0)
+    customShapePropPoints[A_Index, 1] := 0
+customShapeHasSelectedPoints := 0
+msgBeepTimer("Deselected all " groupDigits(customShapePoints.Count()) " path points", 0)
```

**Merge suggestion.** A shared function saves about 1 line: both names stay (menus; the «select none» one also has default keys and a timer). Leave as is.

## Section 2: up to 2 lines differ

Up to 2 lines in each function have no partner, and at most 1 in 5.

<a id="17"></a>
### 17. `EditResizeWidth`, `EditResizeHeight`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `EditResizeWidth()` (base) | 94748–94807 | 49 | 8 calls, control ×2 |
| `EditResizeHeight()` | 94809–94866 | 49 | control ×2 |

`EditResizeHeight()` against `EditResizeWidth()`:

```diff
@@ 94755 / 94816 @@
-If (A_TickCount - lastEditRHChange < 200)
+If (A_TickCount - lastEditRWChange < 200)
@@ 94764 / 94825 @@
-   Global lastEditRWChange := A_TickCount
-   GuiControl, SettingsGUIA:, userEditHeight, % Round(userEditWidth)
+   Global lastEditRHChange := A_TickCount
+   GuiControl, SettingsGUIA:, userEditWidth, % Round(userEditHeight)
@@ 94772 / 94833 @@
-If (userEditWidth<1 || !userEditWidth)
-   userEditWidth := 1
-If (AnyWindowOpen=73 || AnyWindowOpen=28)
+If (userEditHeight<1 || !userEditHeight)
+   userEditHeight := 1
+If (AnyWindowOpen=28 || AnyWindowOpen=73)
@@ 94782 / 94843 @@
-Global lastEditRWChange := A_TickCount
+Global lastEditRHChange := A_TickCount
@@ 94787 / 94848 @@
-   thisWidth := (ResizeInPercentage=1) ? (oImgW/100)*userEditWidth : userEditWidth
-   calcIMGdimensions(oImgW, oImgH, thisWidth, 90000*oImgH, newW, newH)
-   newValue := (ResizeInPercentage=1) ? Round((newH/oimgH)*100) : newH
-   GuiControl, SettingsGUIA:, userEditHeight, % Round(newValue)
+   thisHeight := (ResizeInPercentage=1) ? (oImgH/100)*userEditHeight : userEditHeight
+   calcIMGdimensions(oImgW, oImgH, 90000*oImgW, thisHeight, newW, newH)
+   newValue := (ResizeInPercentage=1) ? Round((newW/oimgW)*100) : newW
+   GuiControl, SettingsGUIA:, userEditWidth, % Round(newValue)
```

**Merge suggestion.** One `EditResizeDimension(isWidth)`. The switch picks which edit box is read and written, which timestamp is checked and which is set (`lastEditRWChange` and `lastEditRHChange` swap roles), and which side `calcIMGdimensions()` leaves free. Both names stay as wrappers, because they are control g-labels and a g-label function receives the control's handle and event as its first parameters.

**Saves** about 45 lines: 102 now, 51 for the shared function, 6 for the named functions that stay.

<a id="18"></a>
### 18. `QPV_BlurBitmapFilters`, `QPV_DetectEdgesFilters` and 2 more

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `QPV_BlurBitmapFilters()` (base) | 24823–24846 | 19 | 2 | 21 calls |
| `QPV_DetectEdgesFilters()` | 24848–24872 | 19 | 2 | 1 call |
| `QPV_DiffBlendBitmap()` | 24874–24899 | 19 | 3 | 1 call |
| `QPV_AddGaussianNoiseOnBitmap()` | 24934–24957 | 19 | 3 | 1 call |

`QPV_DetectEdgesFilters()` against `QPV_BlurBitmapFilters()`:

```diff
@@ 24838 / 24863 @@
-E1 := trGdip_LockBits(pBitmap, 0, 0, w, h, Stride, iScan, iData, 3)
+E1 := trGdip_LockBits(pBitmap, 0, 0, w, h, Stride, iScan, iData, 3, 0)
@@ 24841 / 24867 @@
-   r := DllCall("qpvmain.dll\openCVblurFilters", "UPtr", iScan, "Int", w, "Int", h, "Int", passesX, "Int", passesY, "Int", modus, "Int", circular, "int", Stride, "int", 32)
+   r := DllCall("qpvmain.dll\openCVedgeDetection", "UPtr", iScan, "Int", w, "Int", h, "Int", xa, "Int", ya, "Int", ksize, "Int", preblur, "Int", postblur, "int", invert, "float", prebrighten, "float", precontrast, "float", postbrighten, "float", postcontrast, "Int", modus, "int", Stride, "int", 24)
```

`QPV_DiffBlendBitmap()` against `QPV_BlurBitmapFilters()`:

```diff
@@ – / 24882 @@
+thisStartZeit := A_TickCount
@@ 24838 / 24890 @@
-E1 := trGdip_LockBits(pBitmap, 0, 0, w, h, Stride, iScan, iData, 3)
+E1 := trGdip_LockBits(pBitmap, 0, 0, w, h, stride, iScan, iData, 3, 0)
@@ 24840 / 24892 @@
-{
-   r := DllCall("qpvmain.dll\openCVblurFilters", "UPtr", iScan, "Int", w, "Int", h, "Int", passesX, "Int", passesY, "Int", modus, "Int", circular, "int", Stride, "int", 32)
+   r := DllCall("qpvmain.dll\openCVdiffBlendBitmap", "UPtr", iScan, "Int", w, "Int", h, "Int", stride, "Int", 24, "Int", offsetX, "int", offsetY, "Int", preblur, "Int", postblur, "int", invert, "float", prebrighten, "float", precontrast, "float", postbrighten, "float", postcontrast)
+If !E1
@@ 24843 / – @@
-}
```

`QPV_AddGaussianNoiseOnBitmap()` against `QPV_BlurBitmapFilters()`:

```diff
@@ 24828 / 24939 @@
-   Return 0
+   Return
@@ 24834 / 24945 @@
-   addJournalEntry(A_ThisFunc "(): ERROR - invalid bitmap dimensions")
-   Return 0
+   addJournalEntry(A_ThisFunc "(): invalid bitmap to process")
+   Return
@@ 24841 / 24952 @@
-   r := DllCall("qpvmain.dll\openCVblurFilters", "UPtr", iScan, "Int", w, "Int", h, "Int", passesX, "Int", passesY, "Int", modus, "Int", circular, "int", Stride, "int", 32)
+   r := DllCall("qpvmain.dll\addGaussianNoiseOnBitmap", "UPtr", iScan, "int", w, "int", h, "Int", intensity, "int", Stride, "int", 32)
@@ 24845 / 24956 @@
-Return r
+Return pBitmap
```

**Merge suggestion.** These differ mainly in the `DllCall()` and the `LockBits` format. Rather than one function with a mode, move the shared part into a helper (see the qpvmain.dll pattern below): the DLL check, the bitmap check and `LockBits`, returning 0 on failure. Each function keeps its own `DllCall()` and shrinks by about 12 lines. The saving counts that for the four, minus about 20 lines for the helper, which also serves [#19](#19), [#43](#43) and [#54](#54). `QPV_AddGaussianNoiseOnBitmap()` returns the bitmap, and an empty value on failure, where the others return the DLL result or 0.

**Saves** about 28 lines.

<a id="19"></a>
### 19. `QPV_ConvertToGrayscale`, `QPV_AdjustImageColors`, `QPV_ColorizeGrayImage`

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `QPV_ConvertToGrayscale()` (base) | 14721–14748 | 22 | 2 | 3 calls |
| `QPV_AdjustImageColors()` | 14750–14779 | 22 | 2 | 6 calls, mention |
| `QPV_ColorizeGrayImage()` | 15135–15159 | 18 | 3 | 7 calls |

`QPV_AdjustImageColors()` against `QPV_ConvertToGrayscale()`:

```diff
@@ 14739 / 14768 @@
-      QPV_PrepareHugeImgSelectionArea(0, 0, w, h, w, h, EllipseSelectMode, VPselRotation, 1, 0)
-   Else
+      QPV_PrepareHugeImgSelectionArea(0, 0, w, h, w, h, EllipseSelectMode, VPselRotation, 1, invertArea)
+   Else If (previewMode!=-1)
@@ 14742 / 14772 @@
-   r := DllCall("qpvmain.dll\ConvertToGrayScale", "UPtr", iScan, "Int", w, "Int", h, "int", modus, "int", intensity, "int", stride, "int", 32, "UPtr", 0, "int", 0)
+   r := DllCall("qpvmain.dll\AdjustImageColorsPrecise", "UPtr", iScan, "Int", w, "Int", h, "int", stride, "int", 32, "int", thisOpacity, "int", InvertColors, "int", AltSat, "int", Sat, "int", AltBright, "int", Bright, "int", AltContra, "int", Contra, "int", AltHiLows, "int", Shadows, "int", Highs, "int", Hue, "int", TintDeg, "int", TintAmount, "int", AltTint, "int", Gamma, "int", OffR, "int", OffG, "int", OffB, "int", OffA, "int", ThreR, "int", ThreG, "int", ThreB, "int", ThreA, "int", SeeThrough, "int", userimgGammaCorrect, "int", NoClamp, "int", WhitePoint, "int", BlackPoint, "int", NoisePoints, "UPtr", 0, "int", 0)
```

`QPV_ColorizeGrayImage()` against `QPV_ConvertToGrayscale()`:

```diff
@@ 14735 / 15150 @@
-E1 := trGdip_LockBits(pBitmap, 0, 0, w, h, stride, iScan, iData, 3)
+E1 := trGdip_LockBits(pBitmap, 0, 0, w, h, stride, nScan, nData, 3)
@@ 14738 / 15153 @@
-   If (previewMode=1)
-      QPV_PrepareHugeImgSelectionArea(0, 0, w, h, w, h, EllipseSelectMode, VPselRotation, 1, 0)
-   Else
-      QPV_PrepareHugeImgSelectionArea(0, 0, w, h, w, h, -1, 0, 0, 0)
-   r := DllCall("qpvmain.dll\ConvertToGrayScale", "UPtr", iScan, "Int", w, "Int", h, "int", modus, "int", intensity, "int", stride, "int", 32, "UPtr", 0, "int", 0)
-   Gdip_UnlockBits(pBitmap, iData)
+   r := DllCall("qpvmain.dll\ColorizeGrayImage", "UPtr", nScan, "int", w, "int", h, "int", stride, "int", 32, "int", linearu, "int", thisColorA, "int", thisColorB)
+   Gdip_UnlockBits(pBitmap, nData)
```

**Merge suggestion.** As in [#18](#18): each function keeps its `DllCall()` (and the selection-area set-up of the first two) and shrinks by about 11 lines.

**Saves** about 33 lines.

<a id="20"></a>
### 20. `readRecentOpenedFolderEntries`, `readRecentOpenedImagesEntries`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `readRecentOpenedFolderEntries()` (base) | 39379–39409 | 25 | 7 calls |
| `readRecentOpenedImagesEntries()` | 39411–39444 | 27 | 3 calls |

`readRecentOpenedImagesEntries()` against `readRecentOpenedFolderEntries()`:

```diff
@@ 39398 / 39430 @@
-    IniRead, newEntry, % mainRecentsFile, RecentFolderOpened, E%A_Index%, @
+    IniRead, newEntry, % mainRecentsFile, RecentImgOpened, E%A_Index%, @
@@ – / 39432 @@
+    If !RegExMatch(newEntry, RegExFilesPattern)
+       Continue
```

**Merge suggestion.** One `readRecentOpenedEntries(section, forceNewList:=0, doFiltering:=1)`; the images variant adds the `RegExFilesPattern` test. Each keeps a `Static` cache of its list, so the merged function needs one cache per section, for example `Static lists := {}` keyed by section. Both have only direct callers (7 and 3), which can call the new function. Related: [#56](#56), [#51](#51).

**Saves** about 26 lines: 56 now, 30 for the shared function.

<a id="21"></a>
### 21. `decideIconBTNselectShape`, `decideIconBTNthumbsList`, `decideIconBTNpaintBrushSelect`

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `decideIconBTNselectShape()` (base) | 106074–106093 | 16 | 2 | 3 calls |
| `decideIconBTNthumbsList()` | 106095–106115 | 17 | 2 | 1 call |
| `decideIconBTNpaintBrushSelect()` | 106136–106154 | 15 | 3 | 2 calls |

`decideIconBTNthumbsList()` against `decideIconBTNselectShape()`:

```diff
@@ 106075 / 106096 @@
-initialIcon := tlbrIconzList["BTNselectShape", 2]
-thisHwnd := tlbrIconzList["BTNselectShape", 1]
+initialIcon := tlbrIconzList["BTNthumbsList", 2]
+thisHwnd := tlbrIconzList["BTNthumbsList", 1]
@@ 106082 / 106103 @@
-icoFile := (EllipseSelectMode=1) ? "select-ellipse" : "select-rect"
-If (thumbsDisplaying=1)
-   icoFile := "select-rect"
-Else If (EllipseSelectMode=2)
-   icoFile := "select-freeform"
+If (thumbsListViewMode=1)
+   icoFile := "thumbs-list"
+Else If (thumbsListViewMode=2)
+   icoFile := "files-list-simple"
+Else
+   icoFile := "files-list-details"
@@ 106090 / 106112 @@
-   tlbrIconzList["BTNselectShape", 2] := icoFile
+   tlbrIconzList["BTNthumbsList", 2] := icoFile
```

`decideIconBTNpaintBrushSelect()` against `decideIconBTNselectShape()`:

```diff
@@ 106075 / 106137 @@
-initialIcon := tlbrIconzList["BTNselectShape", 2]
-thisHwnd := tlbrIconzList["BTNselectShape", 1]
+thisHwnd := tlbrIconzList["BTNpaintSelection", 1]
@@ – / 106141 @@
+initialIcon := tlbrIconzList["BTNpaintSelection", 2]
@@ 106082 / 106144 @@
-icoFile := (EllipseSelectMode=1) ? "select-ellipse" : "select-rect"
-If (thumbsDisplaying=1)
-   icoFile := "select-rect"
-Else If (EllipseSelectMode=2)
-   icoFile := "select-freeform"
+varu := (AnyWindowOpen=66) ? FloodFillSelectionMode : BrushToolOutsideSelection
+icoFile := (varu=1) ? "paint-any" : "paint-inside"
+If (varu=3)
+   icoFile := "paint-outside"
@@ 106090 / 106151 @@
-   tlbrIconzList["BTNselectShape", 2] := icoFile
+   tlbrIconzList["BTNpaintSelection", 2] := icoFile
```

**Merge suggestion.** The five `decideIconBTN*()` functions (this entry and [#60](#60)) repeat the same frame: look up the button's handle and size in `tlbrIconzList`, choose an icon, and set it if it changed. A helper `tlbrSetButtonIcon(btnName, icoFile)` keeps the frame; each function keeps only its choice of icon. The saving counts these three minus about 11 lines for the helper.

**Saves** about 19 lines.

<a id="22"></a>
### 22. `ImgVectorRedoAct`, `ImgVectorUndoAct`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ImgVectorRedoAct()` (base) | 17251–17272 | 18 | menu ×2, default key, toolbar |
| `ImgVectorUndoAct()` | 17274–17295 | 18 | menu ×2, default key, toolbar, button |

`ImgVectorUndoAct()` against `ImgVectorRedoAct()`:

```diff
@@ 17257 / 17280 @@
-If !IsObject(undoVectorShapesLevelsArray[currentVectorUndoLevel + 1])
+If !IsObject(undoVectorShapesLevelsArray[currentVectorUndoLevel - 1])
@@ 17260 / 17283 @@
-   showTOOLtip("Shape redo [ " currentVectorUndoLevel " / " totalUndos " ]", 0, 0, zz)
+   showTOOLtip("Shape undo [ " currentVectorUndoLevel " / " totalUndos " ]", 0, 0, zz)
@@ 17265 / 17288 @@
-currentVectorUndoLevel := clampInRange(currentVectorUndoLevel + 1, 1, totalUndos)
+currentVectorUndoLevel := clampInRange(currentVectorUndoLevel - 1, 1, totalUndos)
@@ 17267 / 17290 @@
-showTOOLtip("Shape redo [ " currentVectorUndoLevel " / " totalUndos " ]", A_ThisFunc, 1, currentVectorUndoLevel/totalUndos)
+showTOOLtip("Shape undo [ " currentVectorUndoLevel " / " totalUndos " ]", A_ThisFunc, 1, currentVectorUndoLevel/totalUndos)
```

**Merge suggestion.** One function with a direction of +1 or -1; the direction also picks «redo» or «undo» for the two messages. The caller's name is passed in for `showTOOLtip()`. Both names stay as wrappers (menus, default keys, a temporary button).

**Saves** about 14 lines: 40 now, 20 for the shared function, 6 for the named functions that stay.

<a id="23"></a>
### 23. `omniBoxFolderCreateNew`, `omniBoxFolderRename`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `omniBoxFolderCreateNew()` (base) | 27216–27232 | 13 | 2 calls, menu |
| `omniBoxFolderRename()` | 27259–27275 | 13 | 2 calls, menu |

`omniBoxFolderRename()` against `omniBoxFolderCreateNew()`:

```diff
@@ 27222 / 27265 @@
-r := UIcoreFolderNew(folderPath, newFileName)
+r := UIcoreFolderRename(folderPath, newFileName)
```

**Merge suggestion.** One function taking the core function to run (`UIcoreFolderNew` or `UIcoreFolderRename`, called as `%fn%(folderPath, newFileName)`, which keeps `ByRef`). Both names stay as wrappers (menus). [#67](#67) and [#65](#65) repeat the same frame with other actions.

**Saves** about 9 lines: 30 now, 15 for the shared function, 6 for the named functions that stay.

<a id="24"></a>
### 24. `tlbrUndoAction`, `tlbrRedoAction`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `tlbrUndoAction()` (base) | 106182–106197 | 13 | toolbar |
| `tlbrRedoAction()` | 106227–106242 | 13 | toolbar |

`tlbrRedoAction()` against `tlbrUndoAction()`:

```diff
@@ 106192 / 106237 @@
-   ImgUndoAction()
+   ImgRedoAction()
```

**Merge suggestion.** Give `tlbrUndoAction()` a `redo:=0` parameter that picks `ImgRedoAction()`; `tlbrRedoAction()` becomes a three-line wrapper. Its name stays, because the toolbar table in `processToolbarFunctions()` names it; that table calls without arguments, so the default keeps the undo button working.

**Saves** about 12 lines: 30 now, 15 for the shared function, 3 for the named functions that stay.

<a id="25"></a>
### 25. `PreviousPicture`, `NextPicture`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `PreviousPicture()` (base) | 12790–12805 | 11 | 8 calls, menu ×2, default key ×3, toolbar, control ×2 |
| `NextPicture()` | 12807–12822 | 11 | 9 calls, menu ×2, default key ×3, toolbar, control ×2 |

`NextPicture()` against `PreviousPicture()`:

```diff
@@ 12797 / 12814 @@
-If (GetKeyState("Shift", "P") && thumbsDisplaying!=1 && slideShowRunning!=1 && selForbidden!=1)
+If (GetKeyState("Shift", "P") && slideShowRunning!=1 && thumbsDisplaying!=1 && selForbidden!=1)
@@ 12800 / 12817 @@
-currentFileIndex := coreNextPrevImage(-1, prevFileIndex, 0)
+currentFileIndex := coreNextPrevImage(1, prevFileIndex, 0)
@@ 12802 / 12819 @@
-   thumbsSelector("Left", "+Left", prevFileIndex)
+   thumbsSelector("Right", "+Right", prevFileIndex)
```

**Merge suggestion.** One function with a direction of -1 or +1, which also picks «Left» or «Right» for `thumbsSelector()`; it takes the existing `dummy` and `selForbidden` too. Both names stay as wrappers: menus, default keys and g-labels call them, and the `dummy` parameter receives what those pass.

**Saves** about 7 lines.

<a id="26"></a>
### 26. `BtnNextImg`, `BtnPrevImg`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `BtnNextImg()` (base) | 93190–93203 | 11 | 2 calls, control ×5 |
| `BtnPrevImg()` | 93205–93218 | 11 | 2 calls, control ×5 |

`BtnPrevImg()` against `BtnNextImg()`:

```diff
@@ 93194 / 93209 @@
-NextPicture()
+PreviousPicture()
```

**Merge suggestion.** One function taking the direction, calling `NextPicture()` or `PreviousPicture()`; the panel refresh part stays shared. Both names stay as wrappers (control g-labels).

**Saves** about 7 lines: 26 now, 13 for the shared function, 6 for the named functions that stay.

<a id="27"></a>
### 27. `browseExternalApp`, `browseExternalEditApp`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `browseExternalApp()` (base) | 3086–3097 | 10 | menu |
| `browseExternalEditApp()` | 3099–3110 | 10 | menu |

`browseExternalEditApp()` against `browseExternalApp()`:

```diff
@@ 3093 / 3106 @@
-   UserExternalApp := imgPath
-   IniAction(1, "UserExternalApp", "General")
-   OpenImgWithUserExternApp()
+   UserExternalEditApp := imgPath
+   IniAction(1, "UserExternalEditApp", "General")
+   OpenImgWithUserEditExternApp()
```

**Merge suggestion.** One function with an `editor` switch that picks the variable (`UserExternalApp`, `UserExternalEditApp`) and the function that opens the image. Both names stay as wrappers, because `Menu, OpenWithMenu, Add` names them.

**Saves** about 6 lines: 24 now, 12 for the shared function, 6 for the named functions that stay.

<a id="28"></a>
### 28. `isVarEqualTo`, `varContains`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `isVarEqualTo()` (base) | 71334–71345 | 10 | 154 calls |
| `varContains()` | 71347–71358 | 10 | 13 calls |

`varContains()` against `isVarEqualTo()`:

```diff
@@ 71338 / 71351 @@
-    If (value=param)
+    If InStr(value, param)
```

**Merge suggestion.** Both are variadic (`vals*`) and called from 154 and 13 places; a mode parameter would have to come before `vals*`, changing every call. `isVarEqualTo()` is also called often in hot paths. Leave as is.

<a id="29"></a>
### 29. `TglRszRotation`, `TglRszCropping`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `TglRszRotation()` (base) | 94940–94952 | 10 | control |
| `TglRszCropping()` | 94954–94965 | 10 | control ×2 |

`TglRszCropping()` against `TglRszRotation()`:

```diff
@@ 94943 / 94957 @@
-decideUserImgRotationOption()
+GuiControlGet, ResizeCropAfterRotation
@@ 94951 / 94964 @@
-RegAction(1, "ResizeRotationUser")
+RegAction(1, "ResizeCropAfterRotation")
```

**Merge suggestion.** One function with a switch: the rotation slider calls `decideUserImgRotationOption()` and saves `ResizeRotationUser`; the crop checkbox reads and saves `ResizeCropAfterRotation`. Both names stay as wrappers (a slider and a checkbox g-label).

**Saves** about 6 lines: 24 now, 12 for the shared function, 6 for the named functions that stay.

<a id="30"></a>
### 30. `ToggleWICloader`, `ToggleFIMloader`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ToggleWICloader()` (base) | 74322–74330 | 7 | menu |
| `ToggleFIMloader()` | 74345–74353 | 7 | menu |

`ToggleFIMloader()` against `ToggleWICloader()`:

```diff
@@ 74323 / 74346 @@
-initQPVmainDLL()
-allowWICloader := (WICmoduleHasInit=1) ? !allowWICloader : 0
-friendly := (allowWICloader=1) ? "ACTIVATED" : "DEACTIVATED"
-If (WICmoduleHasInit!=1)
+initFIMGmodule()
+allowFIMloader := (wasInitFIMlib=1) ? !allowFIMloader : 0
+friendly := (allowFIMloader=1) ? "ACTIVATED" : "DEACTIVATED"
+If (wasInitFIMlib!=1)
@@ 74328 / 74351 @@
-showTOOLtip("Load images through WIC: " friendly, A_ThisFunc, 1)
+showTOOLtip("Allow images to load through FreeImage: " friendly, A_ThisFunc, 1)
```

**Merge suggestion.** All the differences are names (the init function, the init flag, the setting, the message), but both names must stay for their menus, so a shared function saves about 3 lines. Leave as is.

<a id="31"></a>
### 31. `UIfilterListKeywords`, `UIfilterListViewStaticFolderzList`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `UIfilterListKeywords()` (base) | 95377–95387 | 7 | control |
| `UIfilterListViewStaticFolderzList()` | 100012–100022 | 7 | timer ×2 |

`UIfilterListViewStaticFolderzList()` against `UIfilterListKeywords()`:

```diff
@@ 95378 / 100013 @@
-If (AnyWindowOpen!=71)
+If (AnyWindowOpen!=2)
@@ 95382 / 100017 @@
-GuiControlGet, keywrdLVfilter
+GuiControlGet, StaticListViewFilteru
@@ 95386 / 100021 @@
-UIpopulateKeywordsListPanel(keywrdLVfilter)
+PopulateStaticFolderzList(staticListViewFilteru)
```

**Merge suggestion.** One function taking the window ID, the filter edit control and the list function to call; `UIfilterListViewStaticFolderzList()` can be it, with parameters whose defaults keep its `SetTimer` use, and `UIfilterListKeywords()` becomes a three-line g-label wrapper.

**Saves** about 6 lines: 18 now, 9 for the shared function, 3 for the named functions that stay.

<a id="32"></a>
### 32. `extraDummyReloadThisPicture`, `extraDummyDelayiedImageDisplay`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `extraDummyReloadThisPicture()` (base) | 4242–4249 | 6 | timer ×2 |
| `extraDummyDelayiedImageDisplay()` | 25913–25920 | 6 | timer ×3 |

`extraDummyDelayiedImageDisplay()` against `extraDummyReloadThisPicture()`:

```diff
@@ 4245 / 25916 @@
-   SetTimer, extraDummyReloadThisPicture, -15
+   SetTimer, extraDummyDelayiedImageDisplay, -15
@@ 4248 / 25919 @@
-ReloadThisPicture()
+DelayiedImageDisplay()
```

**Merge suggestion.** Each one re-arms itself with `SetTimer, <its own name>, -15`, so each needs its own name as a timer target; a shared function would need a bound function object for the timer. Leave as is.

<a id="33"></a>
### 33. `coreReloadThisPicture`, `DelayiedImageDisplay`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `coreReloadThisPicture()` (base) | 4340–4347 | 6 | timer |
| `DelayiedImageDisplay()` | 25934–25941 | 6 | 4 calls |

`DelayiedImageDisplay()` against `coreReloadThisPicture()`:

```diff
@@ 4343 / 25937 @@
-   r := IDshowImage(currentFileIndex, 2)
+   r := IDshowImage(currentFileIndex)
```

**Merge suggestion.** They differ only in the second argument of `IDshowImage()`. `coreReloadThisPicture()` could become `DelayiedImageDisplay(2)` behind a three-line timer wrapper, which saves about 2 lines. Leave as is.

<a id="34"></a>
### 34. `GuiAddCloseOnApply`, `GuiAddToggleLivePreview`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `GuiAddCloseOnApply()` (base) | 26742–26748 | 5 | 10 calls |
| `GuiAddToggleLivePreview()` | 26750–26756 | 5 | 12 calls |

`GuiAddToggleLivePreview()` against `GuiAddCloseOnApply()`:

```diff
@@ 26743 / 26751 @@
-Static p := "Close window after the «Apply» button is clicked"
-Gui, %guiu%: Add, Checkbox, % options " gToggleClosePanelApply +hwndhTemp +0x1000 +0x8000 Checked" closeEditPanelOnApply " vcloseEditPanelOnApply", Close window on apply
+Static p := "Toggle Live Preview for the current tool [F12]"
+Gui, %guiu%: Add, Checkbox, % options " +hwndhTemp +0x1000 +0x8000 Checked" doImgEditLivePreview " vdoImgEditLivePreview", Live preview
@@ 26746 / 26754 @@
-SetImgButtonStyle(hTemp, mainExecPath "\resources\toolbar\go-back" pk ".png", 1, 0, guiu)
+SetImgButtonStyle(hTemp, mainExecPath "\resources\toolbar\view-2" pk ".png", 1, 0, guiu)
```

**Merge suggestion.** A shared «icon checkbox» function would need six parameters (tooltip, g-label, variable, caption, icon) for two five-line functions; it saves about 3 lines. Leave as is.

<a id="35"></a>
### 35. `updateLabelSlidesSpeed`, `updateLabelGIFdelay`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `updateLabelSlidesSpeed()` (base) | 46836–46842 | 5 | control |
| `updateLabelGIFdelay()` | 46844–46850 | 5 | control |

`updateLabelGIFdelay()` against `updateLabelSlidesSpeed()`:

```diff
@@ 46837 / 46845 @@
-If (slideShowDelay>=1000)
-   p := Round(slideShowDelay/1000, 1) " s"
+If (abs(UserGIFsDelayu)>=1000)
+   p := Round(UserGIFsDelayu/1000, 1) " s"
@@ 46840 / 46848 @@
-   p := slideShowDelay " ms"
-Return "Slides interval: " p
+   p := UserGIFsDelayu " ms"
+Return "GIF frames delay: " p
```

**Merge suggestion.** Both are slider label functions named in `GuiAddSlider()`, so both names stay. Only the milliseconds-to-text part is shared (three lines); leave as is.

<a id="36"></a>
### 36. `throwErrorAllSelectedInvert`, `throwWarningAlphaPaintMode`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `throwErrorAllSelectedInvert()` (base) | 57060–57066 | 5 | 6 calls |
| `throwWarningAlphaPaintMode()` | 85442–85448 | 5 | 5 calls |

`throwWarningAlphaPaintMode()` against `throwErrorAllSelectedInvert()`:

```diff
@@ 57061 / 85443 @@
-If (!testAllowSelInvert() && userBias=1)
+If isNowAlphaPainting()
@@ 57063 / 85445 @@
-   msgBeepTimer("WARNING: The entire canvas is selected,`nbut the option «Invert selection area» is activated.")
+   msgBeepTimer("WARNING: You are currently in alpha mask painting mode.`nThe selection area cannot be altered.")
```

**Merge suggestion.** Two five-line checks with different conditions and messages; a shared function would only move the `msgBeepTimer()` and `Return 1`. Leave as is.

<a id="37"></a>
### 37. `BtnNextToneMapPic`, `BtnPrevToneMapPic`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `BtnNextToneMapPic()` (base) | 59330–59336 | 5 | control |
| `BtnPrevToneMapPic()` | 59338–59344 | 5 | control |

`BtnPrevToneMapPic()` against `BtnNextToneMapPic()`:

```diff
@@ 59332 / 59340 @@
-BtnNextImg()
+BtnPrevImg()
```

**Merge suggestion.** They differ only in `BtnNextImg()` or `BtnPrevImg()`, and both are control g-labels whose names stay; a shared function saves about 1 line. Leave as is.

<a id="38"></a>
### 38. `CustomObjToString`, `CustomaObjToString`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `CustomObjToString()` (base) | 87217–87224 | 5 | no reference |
| `CustomaObjToString()` | 87226–87233 | 5 | 1 call |

`CustomaObjToString()` against `CustomObjToString()`:

```diff
@@ 87222 / 87231 @@
-  str .= "?" key "|" CustomaObjToString(value)
+  str .= "<" ObjToString(value) "@"
```

**Merge suggestion.** No live code calls `CustomObjToString()`; its only mention is a commented-out `MsgBox` at line 87249. `CustomaObjToString()` is called only by it. Deleting both also leaves `ObjToString()` (87208, 8 lines) with no caller other than these and itself; the saving does not count it.

**Saves** about 14 lines.

## Section 3: up to 3 lines in 10 differ

Up to 3 lines in 10 have no partner. Several of these are better left alone; the suggestions say which.

<a id="39"></a>
### 39. `batchSimpleProcessing`, `batchSimpleColorsAdjusts`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `batchSimpleProcessing()` (base) | 102382–102511 | 113 | 1 call |
| `batchSimpleColorsAdjusts()` | 102513–102624 | 97 | 1 call |

`batchSimpleColorsAdjusts()` against `batchSimpleProcessing()`:

```diff
@@ 102390 / 102521 @@
-      msgInfos .= "`n`nThe files will be OVERWRITTEN."
+      msgInfos .= "`n`nThe files will be will be OVERWRITTEN."
@@ 102402 / – @@
-mustDoMultiCore := (convertFormatUseMultiThreads=1 && systemCores>1 && filesPerCore>=2) ? 1 : 0
@@ 102406 / – @@
-If (mustDoMultiCore=1)
-{
-   setPriorityThread(-2)
-   addJournalEntry("Preparing " systemCores " threads to start. " filesPerCore " files per thread.")
-   infoResult := initWorkLoadMultiCoresSimpleImgProcessing(filesElected, losslessJpegs)
-   setPriorityThread(0)
-   If (infoResult!="single-core")
-      Return
-}
-If (infoResult="single-core")
-   addJournalEntry("Image processing in batch: falling back to single-threaded processing")
@@ 102424 / – @@
-thisRegEXsaveFmts := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
@@ 102441 / 102557 @@
-   If !RegExMatch(imgPath, thisRegEXsaveFmts)
+   If !RegExMatch(imgPath, saveTypesRegEX)
@@ 102461 / – @@
-   zPlitPath(imgPath, 0, OutFileName, OutDir)
-   destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
-   file2save := destImgPath "\" OutFileName
-   lockDestinationFileName(file2save, 2)
@@ – / 102579 @@
+      zPlitPath(imgPath, 0, OutFileName, OutDir)
+      file2save := ResizeDestFolder "\" OutFileName
+      lockDestinationFileName(file2save, 2)
@@ 102469 / 102584 @@
-   }
+   } Else
+      file2save := imgPath
@@ 102481 / 102597 @@
-   r := coreSimpleFileProcessing(imgPath, file2save, rotateAngle, XscaleImgFactor, YscaleImgFactor, 0, losslessJpegs)
-   If r
-   {
+   r := coreFreeImageSimpleColorsAdjust(imgPath, file2save)
+   If (r="skip")
+      skippedFiles++
+   Else If r
@@ 102485 / 102602 @@
-   } Else
-   {
+   Else
@@ 102488 / – @@
-      If (ResizeUseDestDir!=1)
-         resultedFilesList[A_Index, 4] := 1
-   }
```

**Merge suggestion.** Both run the same batch frame: the confirmation, the destination folder, the progress tooltip, the abort check, the collision prompt, the counters and the final message. They differ in the multi-core branch (only `batchSimpleProcessing()` has one), the eligible formats, how the destination path is built, and the per-file call (`coreSimpleFileProcessing()` or `coreFreeImageSimpleColorsAdjust()`, which can also report «skip»). One function with a mode parameter can hold both. Each has one caller.

**Saves** about 77 lines: 214 now, 137 for the shared function.

<a id="40"></a>
### 40. `calcIMGcoordsInVP`, `simulateCalcImageCoordsInVP`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `calcIMGcoordsInVP()` (base) | 88007–88127 | 95 | 4 calls |
| `simulateCalcImageCoordsInVP()` | 88129–88235 | 84 | no reference |

`simulateCalcImageCoordsInVP()` against `calcIMGcoordsInVP()`:

```diff
@@ 88012 / – @@
-If (mainWidth="setCenter")
-{
-   prevZoom := mainHeight
-   prevCX := newW
-   prevCY := newH
-   Return
-}
@@ 88098 / 88210 @@
-   If (DestPosY>minTopCornerY && newH>mainHeight || PrintPosX="D" && allowFreeIMGpanning=0 && FlipImgV=0)
+   If (DestPosY>minTopCornerY && newH>mainHeight)
@@ 88101 / – @@
-   If (PrintPosX="D" && allowFreeIMGpanning=0 && FlipImgV=1)
-      IMGdecY := DestPosY := LY
-   Else If (PrintPosX="U" && allowFreeIMGpanning=0)
-      IMGdecY := DestPosY := (FlipImgV=1) ? minTopCornerY : LY
@@ – / 88217 @@
+IMGdecX := Round(IMGdecX)
@@ 88110 / – @@
-IMGdecX := Round(IMGdecX)
```

**Merge suggestion.** Nothing calls `simulateCalcImageCoordsInVP()`. It is a copy of `calcIMGcoordsInVP()` without the «setCenter» mode, the `PrintPosX` "D" and "U" handling and the `ByRef` outputs. Delete it.

**Saves** about 86 lines.

<a id="41"></a>
### 41. `PlotSeenHourStatsNow`, `PlotSeenMonthsStatsNow`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `PlotSeenHourStatsNow()` (base) | 28746–28823 | 67 | control |
| `PlotSeenMonthsStatsNow()` | 28825–28918 | 81 | control |

`PlotSeenMonthsStatsNow()` against `PlotSeenHourStatsNow()`:

```diff
@@ 28748 / 28827 @@
-Gui, SettingsGUIA: ListView, LViewMetaH
+Gui, SettingsGUIA: ListView, LViewMetaM
@@ – / 28830 @@
+dataArray := []
+namesLabel:= []
@@ 28752 / 28833 @@
-If (totalz<3)
+If (totalz<2)
@@ 28755 / 28836 @@
-dataArray := []
-namesLabel:= new hashtable()
-Loop, 24
+LV_GetText(endPeriod, 1, 2)
+LV_GetText(startPeriod, totalz, 2)
+nYear := SubStr(startPeriod, 1, 4)
+nMon:= LTrim(SubStr(startPeriod, 6, 2), "0")
+If (startPeriod="date")
@@ 28759 / 28842 @@
-    dataArray[A_Index] := 1
-    namesLabel[A_Index] := (A_Index < 10) ? "0" . A_Index : A_Index
+   addJournalEntry(A_ThisFunc ": an error occurred processing data from the list view: LViewMetaM")
+   Return
@@ – / 28846 @@
+eYear := SubStr(endPeriod, 1, 4)
+eMon := LTrim(SubStr(endPeriod, 6, 2), "0")
+monthsRange := (eYear - nYear)*12 + (eMon - nMon) + 1
+counter := 0
@@ 28776 / – @@
-       oindexu := SubStr(oindexu, 1, 2)
-       indexu := (oindexu="00" || !oindexu) ? "24" : LTrim(oindexu, 0)
@@ – / 28871 @@
+       counter++
@@ 28786 / 28873 @@
-       dataArray[indexu] := valu ? valu : 1
+       dataArray[counter] := valu ? valu : 1
+       namesLabel[counter] := oindexu
@@ – / 28881 @@
+countSkipped := (monthsRange>counter) ? monthsRange - counter : 0
+lacking := (countSkipped>0) ? groupDigits(countSkipped) " months lack data." : ""
@@ 28795 / 28884 @@
-avgu := groupDigits(Floor(totalu/24))
+avgu := groupDigits(Floor(totalu/counter))
@@ 28798 / 28887 @@
-textu := "Seen images chart: HOURS.`nRange: 01:00 to 24:00.`nAverage: " avgu ". Peak at " maxKvalu "h: " groupDigits(maxValu)
+textu := "Seen images chart: MONTHS`nTotal: " groupDigits(counter) " months. " lacking "`nRange: " startPeriod " - " endPeriod "`nAverage: " avgu ". Peak on " maxKvalu "=" groupDigits(maxValu)
@@ 28803 / 28893 @@
-plotBMP := BarChart(dataArray, namesLabel, Round(196*Scale), 385, "", "DiagonBlackGreen", "DisplayValues:2, BarHeight:" Scale*3.5 ",BarHeightFactor:1, BarSpacing:" Scale/2 ",BarRoundness:0,AutoCalculateHeight:1, BarColorDirection:2, BgrStyle:3, BarBorderColor:0,TextSize:" OSDfontSize//2+1 " BarTextColor:ff999999, BarColorA:ff" OSDtextColor ", ChartBackColorA:00" OSDbgrColor)
+If (counter>20)
+   plotBMP := BarChart(dataArray, namesLabel, Round(106*Scale), 385, "", "DiagonBlackGreen", "DisplayValues:0, BarHeight:" Scale*5 ",BarHeightFactor:1, BarSpacing:" Scale/2 ",BarRoundness:0,AutoCalculateHeight:1, BarColorDirection:2, BgrStyle:3, BarBorderColor:0,TextSize:0, BarColorA:ff" OSDtextColor ", ChartBackColorA:00" OSDbgrColor)
+Else
+   plotBMP := BarChart(dataArray, namesLabel, Round(196*Scale), 385, "", "DiagonBlackGreen", "DisplayValues:2, BarHeight:" Scale*3.5 ",BarHeightFactor:1, BarSpacing:" Scale/2 ",BarRoundness:0,AutoCalculateHeight:1, BarColorDirection:2, BgrStyle:3, BarBorderColor:0,BarTextColor:ff999999, BarColorA:ff" OSDtextColor ", ChartBackColorA:00" OSDbgrColor)
@@ – / 28899 @@
+Gdip_ImageRotateFlip(plotBMP, 6)
```

**Merge suggestion.** Both read the seen-images list view, fill the chart arrays, find the peak and the total, draw a `BarChart()` and show it. They differ in the list view, the way rows become chart positions (24 fixed hours or a run of months), the summary text and the chart options. One function with a «hours» or «months» mode, or a shared helper for the drawing and display tail. Both names stay as wrappers (control g-labels).

**Saves** about 37 lines: 152 now, 109 for the shared function, 6 for the named functions that stay.

<a id="42"></a>
### 42. `SearchIndexSelectAll`, `SelectFilesDead`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `SearchIndexSelectAll()` (base) | 47756–47822 | 58 | 2 calls |
| `SelectFilesDead()` | 47824–47891 | 58 | menu |

`SelectFilesDead()` against `SearchIndexSelectAll()`:

```diff
@@ 47757 / 47825 @@
-thisFilter := processSearchIndexString(userSearchString)
-If !thisFilter
-{
-   thisSearchString := userSearchString := ""
-   SetTimer, PanelSearchIndex, -100
+If warnFramesActionPrevented("SELECT")
@@ 47763 / 47828 @@
-}
-showTOOLtip("Searching index for matching files:`n" userSearchString)
+showTOOLtip("Identifying inexistent files:`n" groupDigits(maxFilesIndex))
@@ 47769 / 47832 @@
-   msgResult := msgBoxWrapper(appTitle ": Confirmation", "Some files are already selected in the list. You can choose to add, substract the files selection based on the search criteria.", "&Replace|&Add|&Substract|&Cancel", 0, "question")
+   msgResult := msgBoxWrapper(appTitle ": Confirmation", "Some files are already selected in the list. You can choose to add, substract the files selection when the file is inexistent.", "&Replace|&Add|&Substract|&Cancel", 0, "question")
@@ 47773 / – @@
-      thisSearchString := userSearchString := ""
@@ 47778 / – @@
-thisSearchString := thisFilter
@@ – / 47853 @@
+startOperation := A_TickCount
+prevMSGdisplay := A_TickCount
+thisIndex := 0
@@ 47801 / 47865 @@
-   If coreSearchIndex(imgPath, thisSearchString, userSearchWhat)
+    If !FileRexists(imgPath)
@@ – / 47871 @@
+    If (A_TickCount - prevMSGdisplay>1000)
+    {
+       etaTime := ETAinfos(A_Index, maxFilesIndex, startOperation)
+       showTOOLtip("Identifying inexistent image files in the index`nMissing files: " groupDigits(thisIndex) etaTime, 0, 0, A_Index/maxFilesIndex)
+       prevMSGdisplay := A_TickCount
+    }
@@ 47809 / 47880 @@
-friendly := thisIndex ? "The files selection was altered." : "The files selection is unchanged."
+friendly := thisIndex ? "The files selection was altered.`nDead files found: " groupDigits(thisIndex) : "Found no inexistent files to select."
@@ 47814 / 47885 @@
-   showDelayedTooltip("User abandoned the search.`n" friendly)
-Else If !thisIndex
-   showDelayedTooltip("No matches found for:`n" userSearchString "`n" friendly)
-Else If (modus!="quick" && wasReplace=1)
-   navSelectedFiles(1)
+   showDelayedTooltip("User abandoned the operation.`n" friendly)
+Else
+   showDelayedTooltip(friendly)
@@ 47821 / 47890 @@
-SetTimer, RemoveTooltip, % -msgDisplayTime
+SetTimer, RemoveTooltip, % -msgDisplayTime//2
```

**Merge suggestion.** Both run the same frame: ask whether to replace, add to or subtract from the current selection, walk the files list, mark the files that pass a test, and report. The test is `coreSearchIndex()` in one and «the file does not exist» in the other; the dead-files variant adds a progress tooltip, and the messages differ. One function with a mode; `SelectFilesDead()` stays as a wrapper for its menu.

**Saves** about 24 lines: 120 now, 93 for the shared function, 3 for the named functions that stay.

<a id="43"></a>
### 43. `QPV_PrepareAlphaChannelBlur`, `QPV_AlterAlphaChannel` and 2 more

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `QPV_PrepareAlphaChannelBlur()` (base) | 15161–15192 | 21 | 3 | 8 calls |
| `QPV_AlterAlphaChannel()` | 15194–15224 | 23 | 3 | 4 calls |
| `QPV_ResizeSplitBlendChannels()` | 15226–15256 | 23 | 3 | no reference |
| `QPV_FillBitmapHoles()` | 15258–15286 | 21 | 3, to `QPV_PrepareAlphaChannelBlur()` only | 1 call |

`QPV_AlterAlphaChannel()` against `QPV_PrepareAlphaChannelBlur()`:

```diff
@@ – / 15196 @@
+If (givenLevel=0 && replaceAll=0)
+   Return 1
@@ 15185 / 15217 @@
-   r := DllCall("qpvmain.dll\PrepareAlphaChannelBlur", "UPtr", iScan, "Int", w, "Int", h, "Int", givenLevel, "Int", fillMissingOnly, "Int", threads)
+   r := DllCall("qpvmain.dll\AlterBitmapAlphaChannel", "UPtr", iScan, "Int", w, "Int", h, "int", stride, "int", 32, "Int", givenLevel, "int", replaceAll)
```

`QPV_ResizeSplitBlendChannels()` against `QPV_PrepareAlphaChannelBlur()`:

```diff
@@ 15171 / 15232 @@
-   Return
+   Return 0
@@ 15185 / 15246 @@
-   r := DllCall("qpvmain.dll\PrepareAlphaChannelBlur", "UPtr", iScan, "Int", w, "Int", h, "Int", givenLevel, "Int", fillMissingOnly, "Int", threads)
+   If (passesX>0 || passesY>0)
+      r := DllCall("qpvmain.dll\openCVblurFilters", "UPtr", iScan, "Int", w, "Int", h, "Int", passesX, "Int", passesY, "Int", 0, "Int", 0, "int", stride, "int", 32)
+   r := DllCall("qpvmain.dll\openCVresizeBlendEachChannel", "UPtr", iScan, "Int", w, "Int", h, "int", 32, "int", stride, "int", x, "int", y, "int", nw, "int", nh, "float", opacity)
```

`QPV_FillBitmapHoles()` against `QPV_PrepareAlphaChannelBlur()`:

```diff
@@ – / 15261 @@
+If isWinXP
+   Return
@@ 15170 / 15266 @@
-   addJournalEntry(A_ThisFunc "(): QPV .dll file is missing or failed to initialize: qpvMain.dll")
+   addJournalEntry(A_ThisFunc "(): QPV dll file is missing or failed to initialize: qpvMain.dll")
@@ 15184 / 15280 @@
-{
-   r := DllCall("qpvmain.dll\PrepareAlphaChannelBlur", "UPtr", iScan, "Int", w, "Int", h, "Int", givenLevel, "Int", fillMissingOnly, "Int", threads)
+   r := DllCall("qpvmain.dll\FillImageHoles", "UPtr", iScan, "Int", w, "Int", h, "UInt", newColor)
+If !E1
@@ 15187 / – @@
-} Else
-   addJournalEntry(A_ThisFunc "(): failed - unable to lock the bitmap bits")
```

**Merge suggestion.** Nothing calls `QPV_ResizeSplitBlendChannels()`; delete it. The other three use the helper of [#18](#18): each keeps its own extra test (`givenLevel=0 && replaceAll=0`, `isWinXP`) and its `DllCall()`. `QPV_FillBitmapHoles()` is close to `QPV_PrepareAlphaChannelBlur()` only; it does not log a failed `LockBits`, while the others do. The saving counts the deletion and about 12 lines for each of the three.

**Saves** about 61 lines.

<a id="44"></a>
### 44. `QPV_PolarTransformBitmap`, `QPV_ZoomBlurBitmap`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `QPV_PolarTransformBitmap()` (base) | 20634–20681 | 38 | 2 calls |
| `QPV_ZoomBlurBitmap()` | 20683–20749 | 50 | 2 calls |

`QPV_ZoomBlurBitmap()` against `QPV_PolarTransformBitmap()`:

```diff
@@ 20636 / – @@
-Static orbScale := 1, superSamples := 2
@@ – / 20714 @@
+If !quality
+{
+   quality := (modus>1 && modus!=4) ? 80 : clampInRange(intensity*2, 16, 70)
+   If (modus=4)
+      quality += 5
+   If (zoomBlurHighQuality=1)
+      quality := clampInRange(Ceil(quality*2.5), 32, 148)
+}
@@ – / 20726 @@
+dllFunc := (modus=4) ? "rotateBlurBitmap" : "zoomBlurBitmap"
@@ 20664 / 20728 @@
-   r := DllCall("qpvmain.dll\" dllFunc, "UPtr", iScan, "UPtr", mScan, "Int", w, "Int", h, "double", w/2, "double", h/2, "double", orbScale, "Int", superSamples, "Int")
+{
+   If (modus=4)
+      r := DllCall("qpvmain.dll\" dllFunc, "UPtr", iScan, "UPtr", mScan, "Int", w, "Int", h, "Int", stride, "Int", 32, "Int", cx, "Int", cy, "Int", intensity, "Int", quality, "Int")
@@ – / 20732 @@
+      r := DllCall("qpvmain.dll\" dllFunc, "UPtr", iScan, "UPtr", mScan, "Int", w, "Int", h, "Int", stride, "Int", 32, "Int", cx, "Int", cy, "Int", modus, "Int", intensity, "Int", quality, "Int")
+} Else
```

**Merge suggestion.** Both check the DLL and the bitmap, create a second bitmap, lock both, call a DLL function, unlock and dispose on failure. The zoom blur adds its quality rule and calls one of two DLL functions with other arguments. One function with a mode, or the helper of [#18](#18) extended to two bitmaps. Each has two callers.

**Saves** about 32 lines: 92 now, 60 for the shared function.

<a id="45"></a>
### 45. `coreAutoColorsFileProcessing`, `coreAutoCropFileProcessing`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `coreAutoColorsFileProcessing()` (base) | 101305–101356 | 42 | 1 call |
| `coreAutoCropFileProcessing()` | 101358–101406 | 39 | 1 call |

`coreAutoCropFileProcessing()` against `coreAutoColorsFileProcessing()`:

```diff
@@ 101318 / 101371 @@
-If (userAutoColorAdjustMode=3)
+kBitmap := AutoCropAction(oBitmap, usrAutoCropColorTolerance, usrAutoCropErrThreshold/100, silentMode, 0)
+trGdip_DisposeImage(oBitmap, 1)
+If !validBMP(kBitmap)
+   Return -1
+trGdip_GetImageDimensions(kBitmap, imgW, imgH)
+If (imgW>oImgW - 1) && (imgH>oImgH - 1)
@@ 101320 / 101379 @@
-   rz := QPV_autoContrastBitmap(oBitmap, 1)
-   If (rz=1)
-      QPV_autoContrastBitmap(oBitmap, 2)
-} Else
-   rz := QPV_autoContrastBitmap(oBitmap, userAutoColorAdjustMode)
-If !rz
-{
-   trGdip_DisposeImage(oBitmap)
-   Return -1
+   trGdip_DisposeImage(kBitmap, 1)
+   Return -2
@@ 101332 / – @@
-kBitmap := oBitmap
```

**Merge suggestion.** Both keep the file times, load the bitmap, reduce the colour depth and save over the file; only the middle step differs (`QPV_autoContrastBitmap()` or `AutoCropAction()`). One function with a mode parameter, or a shared «save with file times kept» helper, which the 10-28 report also lists as a pattern. Each has one caller.

**Saves** about 28 lines: 85 now, 57 for the shared function.

<a id="46"></a>
### 46. `updateSQLdbEntryImgRes`, `updateSQLdbEntryFileInfos`, `updateSQLdbEntryImgHisto`

| Function | Lines | Code lines | Level | Reached through |
|---|---|---:|:---:|---|
| `updateSQLdbEntryImgRes()` (base) | 34394–34425 | 25 | 3 | 8 calls |
| `updateSQLdbEntryFileInfos()` | 34427–34448 | 18 | 3, to `updateSQLdbEntryImgHisto()` only | 1 call |
| `updateSQLdbEntryImgHisto()` | 34533–34564 | 24 | 3 | 1 call |

`updateSQLdbEntryFileInfos()` against `updateSQLdbEntryImgHisto()`:

```diff
@@ 34536 / 34428 @@
-thisPart := A_Space getImgHistoValuesSet(indexu, obju)
-If (imgResu=1 || imgResu=2)
-   thisPart .= ", " getImgPropsValuesSet(indexu, imgResu)
-If (fileInfos=1 || fileInfos=2)
-   thisPart .= ", " getImgFileValuesSet(indexu, fileInfos)
-Else If IsObject(fileInfos)
-   thisPart .= ", fsize='" fileInfos.size "', fmodified='" SubStr(fileInfos.wTime, 1, 12) "', fcreated='" SubStr(fileInfos.cTime, 1, 12) "'"
+thisPart := " fsize='" fileInfos.size "', fmodified='" SubStr(fileInfos.wTime, 1, 12) "', fcreated='" SubStr(fileInfos.cTime, 1, 12) "'"
```

`updateSQLdbEntryImgHisto()` against `updateSQLdbEntryImgRes()`:

```diff
@@ – / 34536 @@
+thisPart := A_Space getImgHistoValuesSet(indexu, obju)
@@ 34396 / 34538 @@
-   thisPart := A_Space getImgPropsValuesSet(indexu, imgResu)
-Else
-   thisPart := " imgdpi='" imgResu.dpi "', imgpixfmt='" imgResu.pixFmt "', imgframes='" imgResu.frames "', imgwidth='" imgResu.w "', imgheight='" imgResu.h "'"
+   thisPart .= ", " getImgPropsValuesSet(indexu, imgResu)
```

**Merge suggestion.** The three build a different `SET` part and then share the rest: the `WHERE` clause, the retry by folder and file name, and the error log. Move that rest into a helper such as `execSQLdbImageUpdate(thisPart, fullPath, dbIndex)`, about 16 lines; each function keeps only its `SET` part and the call. `updateSQLdbEntryFileInfos()` is close to `updateSQLdbEntryImgHisto()` only. Each has direct callers only (8, 1, 1).

**Saves** about 30 lines.

<a id="47"></a>
### 47. `testus`, `testus2`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `testus()` (base) | 109228–109271 | 31 | no reference |
| `testus2()` | 109274–109303 | 27 | no reference |

`testus2()` against `testus()`:

```diff
@@ 109232 / – @@
-SendInput, {LButton}
-Sleep, 350
-SendInput, {LButton}
-Sleep, 50
@@ – / 109301 @@
+SendInput, ^{F4}
@@ 109263 / – @@
-SendInput, {Right}
```

**Merge suggestion.** Mouse and keyboard macros for a CapsLock hotkey. `testus()` is named only in a commented-out `SetTimer` line, and `testus2()` only in a hotkey inside the `/* … */` block at 109305–109393. Delete both, or move them out of the main script.

**Saves** about 62 lines.

<a id="48"></a>
### 48. `VPchangeSaturation`, `VPchangeRealGamma`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `VPchangeSaturation()` (base) | 12129–12158 | 25 | 2 calls |
| `VPchangeRealGamma()` | 12160–12193 | 29 | 2 calls |

`VPchangeRealGamma()` against `VPchangeSaturation()`:

```diff
@@ – / 12165 @@
+resetSlideshowTimer()
+prevColorAdjustZeit := A_TickCount
@@ 12135 / – @@
-resetSlideshowTimer()
-If (imgFxMode=4)
-   satAdjust := 0
@@ 12140 / 12169 @@
-prevColorAdjustZeit := A_TickCount
-stepu := (dir=1) ? 0.05 : -0.05
-satAdjust := clampInRange(satAdjust + stepu, 0, 3)
+If (realGammos>2)
+   stepu := 0.2
+Else If (realGammos<0.1)
+   stepu := 0.01
+Else
+   stepu := 0.05
@@ 12144 / 12177 @@
-showTOOLtip("Image saturation: " Round(satAdjust*100) "%", A_ThisFunc, 2, satAdjust/3)
+stepu := (dir=1) ? stepu : -stepu
+realGammos := clampInRange(realGammos + stepu, 0.01, 10)
+showTOOLtip("Image gamma: " Round(realGammos*100) "%", A_ThisFunc, 2, realGammos/8)
@@ 12146 / 12181 @@
-newValues := "a" satAdjust  ofx getIDimage(currentFileIndex) currentFileIndex zoomLevel imageAlignVPtopLeft allowFreeIMGpanning AnyWindowOpen
+newValues := "a" realGammos ofx getIDimage(currentFileIndex) currentFileIndex zoomLevel imageAlignVPtopLeft allowFreeIMGpanning AnyWindowOpen
@@ 12151 / 12186 @@
-INIaction(1, "satAdjust", "General")
+INIaction(1, "realGammos", "General")
```

**Merge suggestion.** One function taking the variable name, its range, the label and the scale of the progress bar (3 for saturation, 8 for gamma), with the step rule as a parameter or a branch: gamma uses a step that depends on its value, saturation a fixed 0.05, and only saturation resets itself when `imgFxMode` is 4. Both have only direct callers (2 each).

**Saves** about 14 lines: 58 now, 44 for the shared function.

<a id="49"></a>
### 49. `HSL_Hue`, `HSL_Sat`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `HSL_Hue()` (base) | 80471–80499 | 23 | 1 call |
| `HSL_Sat()` | 80501–80529 | 23 | 1 call |

`HSL_Sat()` against `HSL_Hue()`:

```diff
@@ 80485 / 80515 @@
-      Return 60 * ( blu - red ) / ( grn - red ) + 120
+      return ( grn - red ) / ( 255 - Abs( 255 - grn - red ) )
@@ 80487 / 80517 @@
-      Return 60 * ( grn - blu ) / ( red - blu )
+      return ( red - blu ) / ( 255 - Abs( 255 - red - blu ) )
@@ 80489 / 80519 @@
-      Return 60 * ( blu - red ) / ( grn - blu ) + 120
+      return ( grn - blu ) / ( 255 - Abs( 255 - grn - blu ) )
@@ 80493 / 80523 @@
-      Return 60 * ( red - grn ) / ( blu - red ) + 240
+      return ( blu - red ) / ( 255 - Abs( 255 - blu - red ) )
@@ 80495 / 80525 @@
-      Return 60 * ( grn - blu ) / ( red - grn ) + ( blu = grn ? 0 : 360 )
+      return ( red - grn ) / ( 255 - Abs( 255 - red - grn ) )
@@ 80497 / 80527 @@
-      Return 60 * ( red - grn ) / ( blu - grn ) + 240
+      return ( blu - grn ) / ( 255 - Abs( 255 - blu - grn ) )
```

**Merge suggestion.** They share the branching on which channel is largest, but every branch returns a different formula, and both are called together at 80391–80392. One function returning both values would be possible, but saves little and reads worse. Leave as is.

<a id="50"></a>
### 50. `trGdip_CloneBitmapArea`, `trGdip_CloneBitmap`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `trGdip_CloneBitmapArea()` (base) | 104987–105016 | 23 | 9 calls |
| `trGdip_CloneBitmap()` | 105018–105044 | 21 | 141 calls |

`trGdip_CloneBitmap()` against `trGdip_CloneBitmapArea()`:

```diff
@@ 104988 / 105019 @@
-If !validBMP(pBitmap)
+If (!validBMP(pBitmap) && forceIT=0)
@@ 104995 / 105026 @@
-fnOutputDebug("Clone BitmapArea: " k ". ID: " pBitmap ". Invoker: " funcu)
-If (PixelFormat="0xE200B")
-   PixelFormat := highDesiredPixFmt
-r := Gdip_CloneBitmapArea(pBitmap, x, y, w, h, PixelFormat, KeepPixelFormat)
+fnOutputDebug("BMP to clone: " k ". ID: " pBitmap ". Cloner invoked by: " funcu)
+r := Gdip_CloneBitmap(pBitmap)
```

**Merge suggestion.** They differ in the GDI+ call (`Gdip_CloneBitmapArea()` or `Gdip_CloneBitmap()`), the debug text, the pixel format fix-up and `forceIT`. Either one function where an empty area means a full clone, or a shared helper for the error check and `recordGdipBitmaps()` tail, which [#62](#62) and [#64](#64) repeat too. `trGdip_CloneBitmap()` has 141 callers, so its signature should stay.

**Saves** about 16 lines: 48 now, 32 for the shared function.

<a id="51"></a>
### 51. `RecordUsedFiltersManager`, `RecordUsedMultiRenamesQueriesManager`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `RecordUsedFiltersManager()` (base) | 33559–33587 | 23 | 1 call |
| `RecordUsedMultiRenamesQueriesManager()` | 42190–42216 | 20 | 1 call |

`RecordUsedMultiRenamesQueriesManager()` against `RecordUsedFiltersManager()`:

```diff
@@ 33560 / 42191 @@
-If (userPrivateMode=1)
+If (userPrivateMode=1 || StrLen(entry2add)<3)
@@ 33563 / 42194 @@
-entry2add := Trimmer(entry2add)
-mainListu := readRecentFiltersEntries()
-If (StrLen(entry2add)<3 || InStr(entry2add, "{ no filter }"))
-   Return
+mainListu := readRecentMultiRenameEntries()
@@ 33579 / 42206 @@
-    If (A_Index>20)
+    If (A_Index>35)
@@ 33585 / 42214 @@
-    IniWrite, % A_LoopField, % mainRecentsFile, RecentFilters, E%countItemz%
+    IniWrite, % """" A_LoopField """", % mainRecentsFile, RecentMultiRename, E%countItemz%
```

**Merge suggestion.** One function taking the read function, the INI section, the maximum count (20, 35) and whether to quote the entries; the filters variant also trims the entry and refuses «{ no filter }». Each has one caller. [#56](#56) writes its recent lists the same way.

**Saves** about 13 lines: 47 now, 34 for the shared function.

<a id="52"></a>
### 52. `LoadPrefsFromSLD`, `WritePrefsIntoSLD`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `LoadPrefsFromSLD()` (base) | 34812–34835 | 20 | menu |
| `WritePrefsIntoSLD()` | 34837–34859 | 19 | menu |

`WritePrefsIntoSLD()` against `LoadPrefsFromSLD()`:

```diff
@@ 34822 / 34847 @@
-      Return msgBeepTimer("WARNING: The .SLD file has no settings section, only the list of files")
+      Return msgBeepTimer("WARNING: The .SLD file has no settings section, only the list of files. Save the files list to give it one")
@@ 34825 / 34850 @@
-   INIreadSlideSettings(CurrentSLD)
-   showTOOLtip("Settings loaded from the files list")
+   writeSlideSettingsINI(CurrentSLD)
+   showTOOLtip("Settings saved into the files list")
@@ 34830 / 34855 @@
-   readSlideSettingsInDB("*")
-   showTOOLtip("Settings loaded from the database")
+   saveSlideSettingsInDB()
+   showTOOLtip("Settings saved into the database")
@@ 34833 / – @@
-dummyTimerDelayiedImageDisplay(50)
```

**Merge suggestion.** One function with a `save` switch: both share the checks, and differ in the function called (read or write, for .SLD and .SLDB) and the messages; only loading redraws the image. Both names stay as wrappers (menus).

**Saves** about 10 lines: 43 now, 27 for the shared function, 6 for the named functions that stay.

<a id="53"></a>
### 53. `tzGdip_DrawImageFast`, `tzGdip_DrawImage`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `tzGdip_DrawImageFast()` (base) | 18575–18596 | 17 | 6 calls |
| `tzGdip_DrawImage()` | 18598–18622 | 20 | 25 calls |

`tzGdip_DrawImage()` against `tzGdip_DrawImageFast()`:

```diff
@@ – / 18600 @@
+{
+   addJournalEntry(A_ThisFunc "(): error - invalid bitmap to draw.")
@@ – / 18603 @@
+}
@@ 18592 / 18618 @@
-r := Gdip_DrawImageFast(pGraphics, pBitmap, X, Y)
+r := Gdip_DrawImage(pGraphics, pBitmap, dx, dy, dw, dh, sx, sy, sw, sh, Matrix, Unit, ImageAttr)
```

**Merge suggestion.** Both wrap a GDI+ draw call in the same work-around: switch the interpolation mode away from 5 for bitmaps over 32,750 pixels, and back afterwards. One function with a mode, or two small helpers for the switch and the restore. `tzGdip_DrawImage()` also logs an invalid bitmap, the fast one does not.

**Saves** about 14 lines: 41 now, 27 for the shared function.

<a id="54"></a>
### 54. `QPV_SetColorAlphaChannel`, `QPV_FloodFill`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `QPV_SetColorAlphaChannel()` (base) | 14668–14690 | 16 | 3 calls |
| `QPV_FloodFill()` | 14692–14719 | 20 | 1 call |

`QPV_FloodFill()` against `QPV_SetColorAlphaChannel()`:

```diff
@@ 14679 / 14703 @@
-If (!w || !h || !validBMP(pBitmap))
+If (!w || !h || !validBMP(pBitmap) || !isInRange(x, 0, w) || !isInRange(y, 0, h))
@@ – / 14706 @@
+Gdip_FromARGB(newColor, A, R, G, B)
+newColor := Gdip_ToARGB(A, R, G, B)
@@ – / 14710 @@
+tolerance := (FloodFillAltToler=1) ? Ceil(FloodFillTolerance*0.7) + 1 : FloodFillTolerance
@@ 14684 / 14712 @@
-   r := DllCall("qpvmain.dll\SetColorAlphaChannel", "UPtr", iScan, "Int", w, "Int", h, "Int", newColor, "Int", invertAlphaMask, "Int")
+   r := DllCall("qpvmain.dll\FloodFillWrapper", "UPtr", iScan, "Int", FloodFillModus, "Int", w, "Int", h, "Int", x, "Int", y, "Int", newColor, "int", tolerance, "int", fillOpacity, "int", FloodFillDynamicOpacity, "int", blendMode, "int", cartoonMode, "int", FloodFillAltToler, "int", FloodFillEightWays, "int", userimgGammaCorrect, "int", BlendModesFlipped, "int", Stride, "int", 32, "int", 0, "int", 0, "int", BlendModesPreserveAlpha)
@@ – / 14717 @@
+zeitOperation := A_TickCount - thisStartZeit
```

**Merge suggestion.** As in [#18](#18); `QPV_FloodFill()` keeps its point and colour checks. Note that both log nothing for an invalid bitmap or a failed `LockBits`.

**Saves** about 20 lines.

<a id="55"></a>
### 55. `ImgSelUndoAct`, `ImgSelRedoAct`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ImgSelUndoAct()` (base) | 17203–17225 | 17 | menu ×4, default key, toolbar |
| `ImgSelRedoAct()` | 17227–17249 | 17 | menu ×4, default key, toolbar |

`ImgSelRedoAct()` against `ImgSelUndoAct()`:

```diff
@@ – / 17229 @@
+totalSelUndos := Round(undoSelLevelsArray.Count())
@@ 17206 / – @@
-totalSelUndos := Round(undoSelLevelsArray.Count())
@@ 17210 / 17234 @@
-If (StrLen(undoSelLevelsArray[currentSelUndoLevel - 1])<3 && totalSelUndos!=1 || imageLoading=1 || thumbsDisplaying=1)
+If (StrLen(undoSelLevelsArray[currentSelUndoLevel + 1])<3 && totalSelUndos!=1 || imageLoading=1 || thumbsDisplaying=1)
@@ 17212 / 17236 @@
-   showTOOLtip("Selection undo [ " currentSelUndoLevel " / " totalSelUndos " ]", 0, 0, currentSelUndoLevel/totalSelUndos)
+   showTOOLtip("Selection redo [ " currentSelUndoLevel " / " totalSelUndos " ]", 0, 0, currentSelUndoLevel/totalSelUndos)
@@ 17219 / 17243 @@
-currentSelUndoLevel := clampInRange(currentSelUndoLevel - howFar, 1, totalSelUndos)
+currentSelUndoLevel := clampInRange(currentSelUndoLevel + howFar, 1, totalSelUndos)
@@ 17223 / 17247 @@
-showTOOLtip("Selection undo [ " currentSelUndoLevel " / " totalSelUndos " ]", A_ThisFunc, 1, currentSelUndoLevel/totalSelUndos)
+showTOOLtip("Selection redo [ " currentSelUndoLevel " / " totalSelUndos " ]", A_ThisFunc, 1, currentSelUndoLevel/totalSelUndos)
```

**Merge suggestion.** One function with a direction of -1 or +1, as for the vector undo in [#22](#22); the direction also picks «undo» or «redo» and the neighbour level to test. Both names stay as wrappers (menus, default keys).

**Saves** about 10 lines: 38 now, 22 for the shared function, 6 for the named functions that stay.

<a id="56"></a>
### 56. `RecordFoldersOpenedManager`, `RecordImagesOpenedManager`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `RecordFoldersOpenedManager()` (base) | 39499–39520 | 16 | 4 calls |
| `RecordImagesOpenedManager()` | 39522–39543 | 16 | 10 calls |

`RecordImagesOpenedManager()` against `RecordFoldersOpenedManager()`:

```diff
@@ 39500 / 39523 @@
-If (StrLen(entry2add)<3 || !allowRecordHistory || userPrivateMode=1)
+If (StrLen(entry2add)<5 || !allowRecordHistory || userPrivateMode=1 || !FileRexists(entry2add) || !RegExMatch(entry2add, RegExFilesPattern))
@@ 39503 / 39526 @@
-historyList := readRecentOpenedFolderEntries()
+historyList := readRecentOpenedImagesEntries()
@@ 39511 / 39534 @@
-    If (StrLen(A_LoopField)<3 || !FileExist(StrReplace(A_LoopField, "|")))
+    If (StrLen(A_LoopField)<5 || !RegExMatch(A_LoopField, RegExFilesPattern))
@@ 39515 / 39538 @@
-    IniWrite, % A_LoopField, % mainRecentsFile, RecentFolderOpened, E%countItemz%
+    IniWrite, % A_LoopField, % mainRecentsFile, RecentImgOpened, E%countItemz%
@@ 39519 / 39542 @@
-readRecentOpenedFolderEntries(newHistoryList)
+readRecentOpenedImagesEntries(newHistoryList)
```

**Merge suggestion.** One function taking the read function, the INI section and the entry test (folders: exists; images: matches `RegExFilesPattern`). It pairs with the merged reader of [#20](#20), and [#51](#51) is the same pattern.

**Saves** about 12 lines: 36 now, 24 for the shared function.

<a id="57"></a>
### 57. `BtnEraseSelectedArea`, `BtnGraySelectedArea`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `BtnEraseSelectedArea()` (base) | 56448–56468 | 16 | 1 call |
| `BtnGraySelectedArea()` | 57068–57088 | 16 | 1 call |

`BtnGraySelectedArea()` against `BtnEraseSelectedArea()`:

```diff
@@ 56455 / 57075 @@
-updateUIerasePanel("noPreview")
+updateUIdesaturatePanel("noPreview")
@@ – / 57078 @@
+prevImgEditZeit := A_TickCount
@@ 56461 / – @@
-prevImgEditZeit := A_TickCount
@@ 56464 / 57084 @@
-   HugeImagesApplyGenericFilters("erase selected area")
+   HugeImagesApplyGenericFilters("grayscale filter")
@@ 56466 / 57086 @@
-   EraseSelectedArea()
+   GraySelectedArea()
```

**Merge suggestion.** One function taking the panel update function, the filter name for huge images and the action function; the only other difference is where `prevImgEditZeit` is stamped. Both have one caller, at 6182 and 6186.

**Saves** about 15 lines: 36 now, 21 for the shared function.

<a id="58"></a>
### 58. `tlbrFillShape`, `tlbrDrawShapesContour`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `tlbrFillShape()` (base) | 105942–105957 | 13 | menu ×2, default key, toolbar |
| `tlbrDrawShapesContour()` | 105959–105977 | 15 | menu ×2, default key, toolbar |

`tlbrDrawShapesContour()` against `tlbrFillShape()`:

```diff
@@ 105943 / 105960 @@
-If (isImgEditingNow()=1 && AnyWindowOpen=23)
+If (isImgEditingNow()=1 && AnyWindowOpen=65)
@@ 105946 / 105963 @@
-} Else If isImgEditingNow()
+} Else If (isImgEditingNow()=1)
@@ – / 105965 @@
+   If (editingSelectionNow!=1)
+      ToggleEditImgSelection()
@@ 105955 / 105975 @@
-   PanelFillSelectedArea("tlbr", FillAreaShape)
+   PanelDrawShapesInArea("tlbr", FillAreaShape)
```

**Merge suggestion.** Both names stay for their menus and default keys, and the differences (panel ID, the extra `ToggleEditImgSelection()`, the panel function) make the shared part small. Leave as is.

<a id="59"></a>
### 59. `initWorkLoadMultiCoresJpegLL`, `initWorkLoadMultiCoresSimpleImgProcessing`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `initWorkLoadMultiCoresJpegLL()` (base) | 38386–38400 | 13 | 1 call |
| `initWorkLoadMultiCoresSimpleImgProcessing()` | 38475–38489 | 13 | 1 call |

`initWorkLoadMultiCoresSimpleImgProcessing()` against `initWorkLoadMultiCoresJpegLL()`:

```diff
@@ 38389 / 38478 @@
-job.mode := "batch-jpegll"
-job.args := jpegDesiredOperation "=" relativeImgSelCoords "=" imgSelX1 "=" imgSelX2 "=" imgSelY1 "=" imgSelY2 "=" prcSelX1 "=" prcSelX2 "=" prcSelY1 "=" prcSelY2
-job.eligibleRegEx := "i)(.\.(jpeg|jpg|jpe))$"
-job.flagThumbs := 1
+job.mode := "batch-simpleimgproc"
+job.args := imgSelX1 "=" imgSelX2 "=" imgSelY1 "=" imgSelY2 "=" prcSelX1 "=" prcSelX2 "=" prcSelY1 "=" prcSelY2 "=" editingSelectionNow "=" simpleOpRotationAngle "=" losslessJpegs
+job.eligibleRegEx := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
+job.flagThumbs := (ResizeUseDestDir=1) ? 0 : 1
@@ 38394 / 38483 @@
-job.progressMsg := "Performing JPEG lossless operations, please wait"
+job.progressMsg := "Processing image files, please wait"
@@ 38396 / 38485 @@
-job.fatalMsg := "JPEG lossless processing aborted."
+job.fatalMsg := "Image processing aborted."
@@ 38398 / 38487 @@
-job.doneTail := "selected JPEG files were processed"
+job.doneTail := "selected files were processed"
```

**Merge suggestion.** These build the job description for `WorkLoadMultiCoreHandler()`, where the shared work already is; the lines are data. Leave as is.

<a id="60"></a>
### 60. `decideIconBTNmainTooler`, `decideIconBTNvectToolModes`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `decideIconBTNmainTooler()` (base) | 106117–106134 | 14 | no reference |
| `decideIconBTNvectToolModes()` | 106156–106170 | 12 | 2 calls |

`decideIconBTNvectToolModes()` against `decideIconBTNmainTooler()`:

```diff
@@ 106118 / 106157 @@
-thisHwnd := tlbrIconzList[2, 1]
+thisHwnd := tlbrIconzList["BTNvectTmodes", 1]
@@ 106122 / 106161 @@
-initialIcon := tlbrIconzList["BTNmainTooler", 2]
+initialIcon := tlbrIconzList["BTNvectTmodes", 2]
@@ 106125 / 106164 @@
-icoFile := (AnyWindowOpen && imgEditPanelOpened=1 || drawingShapeNow=1) ? "apply-tool" : "thumbs-mode"
-If isVarEqualTo(AnyWindowOpen, 10, 64, 66, 70)
-   icoFile := "main-tool"
+icoFile := "vector-mode-" defineVectToolMode()
@@ 106131 / 106167 @@
-   tlbrIconzList["BTNmainTooler", 2] := icoFile
+   tlbrIconzList["BTNvectTmodes", 2] := icoFile
```

**Merge suggestion.** Nothing calls `decideIconBTNmainTooler()` (and it reads the handle from `tlbrIconzList[2, 1]` where the others use the button name); delete it. `decideIconBTNvectToolModes()` uses the helper suggested in [#21](#21). The saving counts the deletion and the shortened function.

**Saves** about 26 lines.

<a id="61"></a>
### 61. `clearAllFavedFolders`, `eraseAllFavedIMGs`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `clearAllFavedFolders()` (base) | 27051–27064 | 10 | menu |
| `eraseAllFavedIMGs()` | 39975–39991 | 13 | menu |

`eraseAllFavedIMGs()` against `clearAllFavedFolders()`:

```diff
@@ 27054 / 39978 @@
-msgResult := msgBoxWrapper(appTitle ": Favourites", "Are you sure you want to remove all the entries pointing to folders and/or files lists from favourites?", 4, 0, "question")
+msgResult := msgBoxWrapper(appTitle ": Favourites", "Are you sure you want to remove all the entries from the favourites list?", 4, 0, "question")
@@ 27061 / 39985 @@
-FileDelete, % folderFavesFile
-msgBeepTimer("All the entries pointing to folders and/or files lists from favourites were removed.", 0, msgDisplayTime//2)
+FileDelete, % mainFavesFile
+FileDelete, % miniFavesFile
+userAddedFavesCount := 0
+IniAction(1, "userAddedFavesCount", "General")
+msgBeepTimer("All entries from the favourites list were removed.", 0, msgDisplayTime//2)
```

**Merge suggestion.** They share the confirmation with the «answered too quickly» guard; the rest differs. Both names stay for their menus. Leave as is, or move the confirmation into a helper if more places use it.

<a id="62"></a>
### 62. `trGdip_BitmapConvertGray`, `trGdip_BlurBitmap`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `trGdip_BitmapConvertGray()` (base) | 104972–104985 | 11 | 4 calls |
| `trGdip_BlurBitmap()` | 105046–105059 | 11 | no reference |

`trGdip_BlurBitmap()` against `trGdip_BitmapConvertGray()`:

```diff
@@ 104975 / 105049 @@
-   addJournalEntry(A_ThisFunc "(): ERROR. Invalid bitmap to process, function invoked by " funcu "(). pBitmap = " pBitmap)
+   addJournalEntry(A_ThisFunc "(). ERROR: invalid bitmap given to blur")
@@ 104979 / 105053 @@
-r := Gdip_BitmapConvertGray(pBitmap, hue, vibrance, brightness, contrast, KeepPixelFormat)
+r := Gdip_BlurBitmap(pBitmap, BlurAmount, usePARGB, quality)
@@ 104981 / 105055 @@
-   recordGdipBitmaps(r, A_ThisFunc "<-" funcu)
+   recordGdipBitmaps(r, A_ThisFunc)
@@ 104983 / 105057 @@
-   addJournalEntry(A_ThisFunc "(): failed to process pBitmap=" pBitmap)
+   addJournalEntry(A_ThisFunc "() failed, pBitmap = " pBitmap)
```

**Merge suggestion.** Nothing calls `trGdip_BlurBitmap()`; delete it.

**Saves** about 13 lines.

<a id="63"></a>
### 63. `OpenWithDefaultApp`, `OpenFileProperties`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `OpenWithDefaultApp()` (base) | 3013–3026 | 11 | 1 call, menu ×4 |
| `OpenFileProperties()` | 3028–3040 | 10 | menu ×4, control |

`OpenFileProperties()` against `OpenWithDefaultApp()`:

```diff
@@ 3014 / 3029 @@
-imgPath := getIDimage(currentFileIndex)
-imgPath := StrReplace(imgPath, "||")
+imgPath := StrReplace(getIDimage(currentFileIndex), "||")
@@ 3022 / 3036 @@
-   Try Run, "%imgPath%"
+   Try Run, Properties "%imgPath%"
@@ 3024 / 3038 @@
-         msgBoxWrapper(appTitle ": ERROR", "An unknown error occurred opening the default application.", 0, 0, "error")
+         msgBoxWrapper(appTitle ": ERROR", "An unknown error occurred opening the system file properties.", 0, 0, "error")
```

**Merge suggestion.** They differ in the `Run` target and the message, and both names stay for menus; nothing is saved. Leave as is.

<a id="64"></a>
### 64. `trGdip_CreateBitmap`, `trGdip_CreateBitmapFromHBITMAP`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `trGdip_CreateBitmap()` (base) | 104885–104899 | 10 | 77 calls |
| `trGdip_CreateBitmapFromHBITMAP()` | 104935–104949 | 10 | 8 calls |

`trGdip_CreateBitmapFromHBITMAP()` against `trGdip_CreateBitmap()`:

```diff
@@ 104886 / 104936 @@
-r := Gdip_CreateBitmap(Width, Height, PixelFormat, Stride, Scan0)
+r := Gdip_CreateBitmapFromHBITMAP(hBitmap, hPalette)
@@ 104891 / 104941 @@
-   addJournalEntry(A_ThisFunc "() called by " funcu "() has created possibly a faulty object: " Gdip_ErrorHandler(gdipLastError, 0))
+   addJournalEntry(A_ThisFunc "() has created possibly a faulty object: " Gdip_ErrorHandler(gdipLastError, 0) ". Function invoked by " funcu "().")
@@ 104896 / 104946 @@
-   addJournalEntry(A_ThisFunc "() called by " funcu "() using w" Width " - h" Height " - pixFmt" PixelFormat " failed: " Gdip_ErrorHandler(gdipLastError, 0))
+   addJournalEntry(A_ThisFunc "() failed, hBitmap = " hBitmap ": " Gdip_ErrorHandler(gdipLastError, 0))
```

**Merge suggestion.** Different GDI+ calls with different parameters; only the result check and `recordGdipBitmaps()` tail is shared (see [#50](#50)). Leave as is.

<a id="65"></a>
### 65. `folderTreePasteFoldersInto`, `folderTreePasteClippy`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `folderTreePasteFoldersInto()` (base) | 31863–31874 | 9 | menu |
| `folderTreePasteClippy()` | 32371–32384 | 10 | menu |

`folderTreePasteClippy()` against `folderTreePasteFoldersInto()`:

```diff
@@ – / 32375 @@
+If !c
+   Return
@@ 31871 / 32382 @@
-r := UIcoreFolderPasteFoldersInto(thisFolder)
-If (r=1 || r=2)
+r := PasteFilesIntoGivenFolder(thisFolder)
```

**Merge suggestion.** Both names stay for menus and the differences cancel the gain. See [#23](#23) for the same frame in the omnibox. Leave as is.

<a id="66"></a>
### 66. `filterDelayiedImageDisplay`, `writeMainSettingsApp`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `filterDelayiedImageDisplay()` (base) | 25922–25932 | 9 | 3 calls |
| `writeMainSettingsApp()` | 39143–39154 | 9 | 1 call |

`writeMainSettingsApp()` against `filterDelayiedImageDisplay()`:

```diff
@@ 25924 / 39145 @@
-If (A_tickcount - lastInvoked < 60)
+If (A_TickCount - lastInvoked < 350)
@@ 25926 / 39147 @@
-   SetTimer, extraDummyDelayiedImageDisplay, -50
+   lastInvoked := A_TickCount
+   SetTimer, writeMainSettingsApp, -500
@@ – / 39152 @@
+readMainSettingsApp(1)
@@ 25930 / – @@
-DelayiedImageDisplay()
-lastInvoked := A_TickCount
```

**Merge suggestion.** Different jobs that share a debounce frame (`Static lastInvoked`, a minimum interval, a timer). Leave as is.

<a id="67"></a>
### 67. `omniBoxFoldersPaste`, `omniBoxFolderPasteClippy`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `omniBoxFoldersPaste()` (base) | 27244–27257 | 10 | menu |
| `omniBoxFolderPasteClippy()` | 27308–27319 | 8 | menu |

`omniBoxFolderPasteClippy()` against `omniBoxFoldersPaste()`:

```diff
@@ 27250 / 27314 @@
-r := UIcoreFolderPasteFoldersInto(folderPath)
+r := PasteFilesIntoGivenFolder(folderPath)
@@ 27255 / – @@
-If (r=2)
-   uiPopulateQuickMenuSearch("resel")
```

**Merge suggestion.** Both names stay for menus; on its own a merge saves about 3 lines. It could join the function suggested in [#23](#23) if that one takes the post-action too.

<a id="68"></a>
### 68. `ActSortHistogram`, `ActSortImageProperties`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ActSortHistogram()` (base) | 37708–37720 | 9 | 9 calls |
| `ActSortImageProperties()` | 37722–37734 | 9 | 7 calls |

`ActSortImageProperties()` against `ActSortHistogram()`:

```diff
@@ 37709 / 37723 @@
-Static listuA := {1:"imgavg", 2:"imgmedian", 3:"imghpeak", 4:"imghlow", 5:"imghrange", 6:"imghmode", 7:"imghminu", 8:"imghrms"}
-     , listuB := {1:"avg", 2:"median", 3:"peak", 4:"low", 5:"range", 6:"mode", 7:"minu", 8:"hrms"}
+Static listuA := {1:"imgmegapix", 2:"imgwidth", 3:"imgheight", 4:"imgwhratio", 5:"imgdpi", 6:"imgframes"}
+     , listuB := {1:"resolution", 2:"width", 3:"height", 4:"wh-ratio", 5:"dpi", 6:"frames"}
@@ 37716 / 37730 @@
-   SortFilesList("histogram-" listuB[modus], 1)
-etaTime := "Elapsed time to sort files list by histogram mode " modus ": " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
+   SortFilesList("image-" listuB[modus], 1)
+etaTime := "Elapsed time to sort files list by image properties mode " modus ": " SecToHHMMSS(Round((A_TickCount - startOperation)/1000, 3)) ". Files: " maxFilesIndex
```

**Merge suggestion.** One function taking the kind ("histogram" or "image") and the mode; the two `Static` lookup tables and the label become one table keyed by kind. Both have only direct callers (9 and 7).

**Saves** about 7 lines: 22 now, 15 for the shared function.

<a id="69"></a>
### 69. `ToggleToolBarValign`, `toggleToolbarTwoColumns`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `ToggleToolBarValign()` (base) | 108968–108980 | 10 | menu, toolbar |
| `toggleToolbarTwoColumns()` | 108982–108991 | 8 | menu |

`toggleToolbarTwoColumns()` against `ToggleToolBarValign()`:

```diff
@@ 108969 / 108983 @@
-TLBRverticalAlign := !TLBRverticalAlign
-If (TLBRtwoColumns=1)
-   TLBRverticalAlign := 0
-TLBRtwoColumns := 0
+TLBRverticalAlign := 1
+TLBRtwoColumns := !TLBRtwoColumns
```

**Merge suggestion.** Only the saving and the redraw are shared (five lines), and both names stay for menus. Leave as is.

<a id="70"></a>
### 70. `RandomPicture`, `PrevRandyPicture`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `RandomPicture()` (base) | 39993–40007 | 9 | 20 calls, menu ×2, default key, toolbar, timer ×3 |
| `PrevRandyPicture()` | 40009–40020 | 8 | 1 call, menu ×2, default key, toolbar |

`PrevRandyPicture()` against `RandomPicture()`:

```diff
@@ 39999 / – @@
-If (modus="key")
@@ 40005 / 40018 @@
-currentFileIndex := coreNextPrevImage(1, RandyIMGnow, 1)
+currentFileIndex := coreNextPrevImage(-1, RandyIMGnow, 1)
```

**Merge suggestion.** `RandomPicture()` is reached in many ways (20 calls, timers, menus, keys) and the two differ in the direction and in when the slideshow timer resets; a merge saves nothing. Leave as is.

<a id="71"></a>
### 71. `BtnBlurSelectedArea`, `BtnZoomBlurSelectedArea`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `BtnBlurSelectedArea()` (base) | 57175–57185 | 8 | control |
| `BtnZoomBlurSelectedArea()` | 57207–57217 | 8 | control |

`BtnZoomBlurSelectedArea()` against `BtnBlurSelectedArea()`:

```diff
@@ 57179 / 57211 @@
-updateUIblurPanel("no-preview")
+updateUIzoomBlurPanel("no-preview")
@@ 57183 / 57215 @@
-BlurSelectedArea()
+zoomBlurSelectedArea()
```

**Merge suggestion.** They differ only in two function names, but both are control g-labels whose names stay; a shared function saves about 4 lines. Leave as is.

<a id="72"></a>
### 72. `defineListViewModes`, `defineHistogramMode`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `defineListViewModes()` (base) | 73573–73585 | 9 | 10 calls |
| `defineHistogramMode()` | 74664–74673 | 7 | 3 calls |

`defineHistogramMode()` against `defineListViewModes()`:

```diff
@@ 73575 / 74665 @@
-If (thumbsListViewMode=1)
-   friendly := "THUMBNAILS"
-Else If (thumbsListViewMode=2)
-   friendly := "COMPACT"
-Else If (thumbsListViewMode=3)
-   friendly := "FILE DETAILS"
-Else If (thumbsListViewMode=4)
-   friendly := "IMAGE DETAILS"
+If (histogramMode=1)
+   friendly := "LOWS"
+Else If (histogramMode=2)
+   friendly := "BALANCED"
+Else If (histogramMode=3)
+   friendly := "PEAKS"
```

**Merge suggestion.** Two lookup chains from a number to a label. Leave as is, or turn each into a small array lookup.

<a id="73"></a>
### 73. `testIsBezierAltViewPathClosed`, `testBezierFirstLastPointsCollapsed`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `testIsBezierAltViewPathClosed()` (base) | 50919–50929 | 7 | 2 calls |
| `testBezierFirstLastPointsCollapsed()` | 50931–50942 | 8 | no reference |

`testBezierFirstLastPointsCollapsed()` against `testIsBezierAltViewPathClosed()`:

```diff
@@ 50925 / 50937 @@
-xA := customShapePoints[1, 1],        yA := customShapePoints[1, 2]
-xB := customShapePoints[totalz, 1],   yB := customShapePoints[totalz, 2]
+f := (modus="first") ? 2 : totalz
+xA := customShapePoints[f - 1, 1],        yA := customShapePoints[f - 1, 2]
+xB := customShapePoints[f, 1],            yB := customShapePoints[f, 2]
```

**Merge suggestion.** Nothing calls `testBezierFirstLastPointsCollapsed()`; delete it.

**Saves** about 10 lines.

<a id="74"></a>
### 74. `MenuRemNowFilesListFilter`, `BTNuiDiscardFilesFilter`

| Function | Lines | Code lines | Reached through |
|---|---|---:|---|
| `MenuRemNowFilesListFilter()` (base) | 4206–4215 | 6 | 3 calls, menu ×2, default key, toolbar, button ×5 |
| `BTNuiDiscardFilesFilter()` | 33237–33248 | 8 | control |

`BTNuiDiscardFilesFilter()` against `MenuRemNowFilesListFilter()`:

```diff
@@ – / 33244 @@
+InitialFilterSettingsPanel(1)
+BtnCloseWindow()
```

**Merge suggestion.** `BTNuiDiscardFilesFilter()` is `MenuRemNowFilesListFilter()` with two lines inserted after the save prompt. A shared function would need a parameter that a menu cannot fill by mistake (a menu passes the item name as the first argument); it saves about 4 lines. Leave as is.

## Patterns spanning several entries

Some families share a shape with others, so one helper can serve them all. The savings in each entry already assume the shared helper.

| Pattern | Entries | Functions | Saves |
|---|---|---:|---:|
| Setting toggles: flip a global, save it, show «ACTIVATED» or «DEACTIVATED» | [#1](#1), [#10](#10) | 25 | 84 |
| qpvmain.dll bitmap wrappers: DLL check, bitmap check, `LockBits`, `DllCall()`, `UnlockBits` | [#18](#18), [#19](#19), [#43](#43), [#44](#44), [#54](#54) | 15 | 174 |
| Toolbar icon choosers, `decideIconBTN*()` | [#21](#21), [#60](#60) | 5 | 45 |
| Recent lists in the recents INI: read and record | [#20](#20), [#51](#51), [#56](#56) | 6 | 51 |
| Mirror twins: next and previous, undo and redo, first and last, H and V, X and Y, width and height | [#3](#3), [#4](#4), [#6](#6), [#16](#16), [#17](#17), [#22](#22), [#24](#24), [#25](#25), [#26](#26), [#37](#37), [#55](#55), [#70](#70) | 24 | 139 |
| Sort actions: database sort or list sort, then the elapsed time | [#9](#9), [#13](#13), [#68](#68) | 7 | 28 |
| Folder actions in the omnibox and the folders tree | [#23](#23), [#65](#65), [#67](#67) | 6 | 9 |
| `trGdip_*()` wrappers: GDI+ call, result check, `recordGdipBitmaps()` | [#50](#50), [#62](#62), [#64](#64) | 6 | 29 |

<a id="unused"></a>
## Functions nothing calls

A case-insensitive whole-word search of every file in the repository, outside `.git`, `.claude` and `reports/`, finds these names only at their definitions, in comment lines, or inside the `/* */` block at 109305–109393. A name built at run time (`%name%()`) cannot be found this way, but no string in the script holds these names or their prefixes.

| Function | Lines | Code lines | Entry | Where the name also appears |
|---|---|---:|---|---|
| `simulateCalcImageCoordsInVP()` | 88129–88235 | 84 | [#40](#40) | nowhere |
| `testus()` | 109228–109271 | 31 | [#47](#47) | a commented-out `SetTimer` inside itself |
| `QPV_ResizeSplitBlendChannels()` | 15226–15256 | 23 | [#43](#43) | nowhere |
| `testus2()` | 109274–109303 | 27 | [#47](#47) | a hotkey inside the `/* */` block |
| `decideIconBTNmainTooler()` | 106117–106134 | 14 | [#60](#60) | nowhere |
| `trGdip_BlurBitmap()` | 105046–105059 | 11 | [#62](#62) | nowhere |
| `testBezierFirstLastPointsCollapsed()` | 50931–50942 | 8 | [#73](#73) | nowhere |
| `CustomObjToString()` | 87217–87224 | 5 | [#38](#38) | a commented-out `MsgBox` at 87249 |
| `CustomaObjToString()` | 87226–87233 | 5 | [#38](#38) | called only by `CustomObjToString()` |
| `ObjToString()` | 87208–87215 | 6 | none | called only by `CustomaObjToString()` and itself |

## Left out after reading

`ReadSettingsThumbsSheetPanel()` (54493) and `ReadSettingsPrintPanel()` (54517) pass the level 3 test, but they are two different settings lists. Every line calls `RegAction(act, "<setting>", …)`, so 8 lines pair up as renamed although they save different settings. Only 6 lines are the same: the shared `TextInArea*` font settings.

## Seen in passing

- `batchSimpleColorsAdjusts()`, line 102521: the confirmation reads «The files will be will be OVERWRITTEN.»
- `FlipHtransformedIMGpanel()`, line 48962: `Static kl := {4:3, 3:4, 2:1, 1:2}` is never read.

## Regenerating

The scripts are in `.claude/scratch/near-identical-funcs-2026-11-23/` (excluded from git). From that folder:

1. `python3 -I candidates.py` picks the candidate pairs (about a second).
2. `python3 -I rescore.py 3` lines up the code lines of each candidate pair.
3. `python3 -I families.py` forms the families and collects the references.
4. `python3 -I report.py` writes this file.

The merge suggestions are written by hand in `suggestions.py`, keyed by each family's base function, so a new snapshot needs them checked again.
