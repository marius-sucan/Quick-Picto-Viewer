# Low-use globals: which can become parameters, locals or Statics

Snapshot of `development` at 62e83ad, 2026-11-23. Line numbers are in `quick-picto-viewer.ahk` unless a lib file is named, and hold only for that commit.

## Words used here

- **Super-global**: a name in one of the top-level `Global` blocks (`quick-picto-viewer.ahk` 96-396, `lib/module-interface.ahk` 7-17, `lib/msgbox2.ahk` 57). AutoHotkey makes it visible inside every function.
- **Function-level global**: a `Global x` line inside a function. Only the functions that declare it share that variable.
- **Courier**: a global whose only job is to carry a value from one function to another that it calls, directly or through a timer it starts. A parameter, a return value or a bound function can do the same job.
- **Event state**: a value that must outlive the call that set it, because a later message, click, timer or call reads it. It has to stay global, or become a `Static` when one function is its only user.
- **Function**, in the counts, also means the auto-exec section (the start-up code above the `Return` at line 500).

## How the globals were counted

- There are 1,239 super-globals: 1,169 in `quick-picto-viewer.ahk`, 66 in `module-interface.ahk`, 4 in `msgbox2.ahk`.
- Every use was located in `quick-picto-viewer.ahk` and `lib/*.ahk`, leaving out comments, `/* */` blocks and `.member` names. A function counts once, however many of its lines use the name. A function whose parameter, `Local` or `Static` has the same name works on its own variable and is not counted: `uiPopulateExifToolInfos()` has its own `Static firstRun` (32765), for example.
- Cross-check: a whole-word, case-insensitive search of every file found no use that the count missed; the extra hits are all comments.
- Names built at run time were checked. `Gdip_DeletePen(pPen%A_Index%)` (4468) frees `pPen1` to `pPen8` at exit. The other `name%x%` forms in the code are Gui options (`w%x%`, `g%labelu%`) or numbered tree items.

Used in 0 to 3 functions: 373 super-globals (0 functions: 1, one: 62, two: 120, three: 190).

**Left out: 238 settings and panel controls** (54 in one function, 65 in two, 119 in three). Each one's name is written in a string (`RegAction(act, "Name")`, `INIaction`, `GuiAddSlider("Name", ...)`, `uiSlidersArray["Name", ...]`, `GuiUpdateSliders("Name")`, `IniSLDBWrite("Name", ...)`, the `ctrlsList` table at `module-interface.ahk:1656`) or bound to a control. The settings loader and the `vName` option need the name as a global, so these stay global, even the ones a single function uses, such as `BrushToolRandomSize` in `ActPaintBrushNow()`. An `HwndName` option would accept a local, but each of the 19 names bound only that way is read outside the function that creates its control (`hPic0` to `hPic11` through `hPic%A_Index%` loops), so they stay as handles.

**Analysed:** the other 134, `CSmid` (used nowhere), and the 217 function-level globals (continuation lines included). Of those 217, 194 are panel controls (176 bound with `v` or `Hwnd`, 18 `Picku*` buttons that `GuiAddPickerColor()` creates as `"vPicku" name`), 2 belong to the third-party `Font_Library3.ahk`, and 21 are not controls (sections 2 and 3). A name bound to a control in any panel counted as a control; whether every panel that declares such a name also creates it was not checked.

## Result

| Verdict | Count | Globals |
|---|---|---|
| Courier → parameter | 1 | `forceProtectLoadedImg` |
| Computed by its reader | 2 | `combosDarkModus`, `AllowDarkModeForWindow` |
| One function → local | 3 | `menusList`, `startPageIndex`, `cmdExifTool` |
| One function → `Static` | 5 | `hCWPhook`, `hasMemThumbsCached`, `createdQuickMenuSearchWin`, `maxVectorUndoLevels`, `hasOpened` (function-level) |
| Start-up code only → drop the declaration | 1 | `FirstRun` |
| Delete | 22 | `dynamicThumbsColumns` (never assigned), `CSmid` (never used), `lastInvoked` in `CopyMovePanelWindow()` (never read), 19 dead function-level declarations |
| Stays | 122 | event state and shared constants, in six groups (section 4) |

Couriers are rare. Of the 134, only `forceProtectLoadedImg` is a clean "set, call, clear" hand-off. Nearly every low-use global carries a value from one event to a later one (a click, a timer, the next draw), which a parameter cannot do.

The mark ⁽⁰⁹⁻⁰⁵⁾ flags the 13 globals that `global-vars-audit-2026-09-05.md` proposes changing and that are still top-level globals at 62e83ad. The other globals it proposes changing no longer are (`InternalFilterString` is now a function-level panel control).

## 1. Couriers, and values the reader can compute

### 1.1 `forceProtectLoadedImg` → a parameter

Declared at 206 (`:= 0`).

| Line | Function | Use |
|---|---|---|
| 12658 | `doOpenStartFolder()` | `forceProtectLoadedImg := 1` |
| 12659 | `doOpenStartFolder()` | `coreOpenFolder("\|" mustOpenStartFolder, 0)` |
| 12673 | `doOpenStartFolder()` | `forceProtectLoadedImg := 0` |
| 65511 | `renewCurrentFilesList()` | `If (forceProtectLoadedImg!=1)`: skip discarding the image caches and ending image editing |

The value travels from the set to the read through `coreOpenFolder()`. That function calls `renewCurrentFilesList()` at 65762, and calls `resetMainWin2Welcome()` at 65768 (empty folder) and 65802 (missing folder); `resetMainWin2Welcome()` calls `renewCurrentFilesList()` at 2643.

Change:
1. `renewCurrentFilesList(protectLoadedImg:=0)`; line 65511 tests `protectLoadedImg`.
2. `resetMainWin2Welcome(protectLoadedImg:=0)`; line 2643 passes it on.
3. `coreOpenFolder(thisFolder, doOptionals:=1, openFirst:=0, doReset:=0, safeMode:=0, protectLoadedImg:=0)`; lines 65762, 65768 and 65802 pass it on.
4. Line 12659 becomes `coreOpenFolder("|" mustOpenStartFolder, 0, 0, 0, 0, 1)`; delete 12658, 12673 and the declaration.

Watch:
- `renewCurrentFilesList()` (13 call sites), `resetMainWin2Welcome()` (13) and `coreOpenFolder()` (8) are only called directly, never by name from a menu, timer or g-label, so a trailing optional parameter changes no other call.
- The global also reaches any other `renewCurrentFilesList()` call made while `coreOpenFolder()` runs. The call graph finds longer routes, such as `resetMainWin2Welcome()` > `startDrawingShape()` > ... > `RefreshFilesList()` > `OpenSLD()`. They run through conditional branches that were not traced one by one, and the parameter would not reach them.
- A runtime error between 12658 and 12673 leaves the global at 1 for the next folder opened; a parameter cannot leak that way.

### 1.2 `combosDarkModus` → computed in `GuiAddDropDownList()`

Declared at 219 (`:= ""`).

| Line | Function | Use |
|---|---|---|
| 26596 | `PanelDefineKbdShortcut()` | `combosDarkModus := (uiUseDarkMode=1) ? "-theme -border " : ""` |
| 28072 | `createSettingsGUI()` | the same line |
| 26670 | `GuiAddDropDownList()` | `Gui, %guiu%: Add, DropDownList, % combosDarkModus " xp yp wp " ...` |
| 26673 | `GuiAddDropDownList()` | `Gui, %guiu%: Add, DropDownList, % combosDarkModus A_Space options ...` |

Both writers derive it from the super-global `uiUseDarkMode`, which `GuiAddDropDownList()` can read itself. Change: make it a local of `GuiAddDropDownList()`, set to `(uiUseDarkMode=1) ? "-theme -border " : ""` before line 26670; delete 26596, 28072 and the declaration.

Watch: `GuiAddDropDownList()` has 174 call sites. Each would read the dark-mode state when the drop-down is added, not when its panel opened; the two differ only if dark mode is toggled while a panel is being built.

### 1.3 `AllowDarkModeForWindow` ⁽⁰⁹⁻⁰⁵⁾ → a `Static` in `setDarkWinAttribs()`

Declared at 209 (`:= ""`).

| Line | Function | Use |
|---|---|---|
| `shell-stuff.ahk:1234` | `setMenusTheme()` | `global AllowDarkModeForWindow := DllCall("GetProcAddress", "uptr", uxtheme, "Uptr", 133, "uptr")` |
| `shell-stuff.ahk:1253` | `setDarkWinAttribs()` | `DllCall(AllowDarkModeForWindow, "UPtr", hwndGUI, "int", modus)` |

`setMenusTheme()` looks up an address that only `setDarkWinAttribs()` uses. Change:
- In `setDarkWinAttribs()`, add `Static AllowDarkModeForWindow := 0`.
- Before line 1253, add `If !AllowDarkModeForWindow` followed by `AllowDarkModeForWindow := DllCall("GetProcAddress", "uptr", DllCall("GetModuleHandle", "str", "uxtheme", "uptr"), "Uptr", 133, "uptr")`.
- Delete line 1234 and the declaration at 209.

Watch:
- Both functions return early on Windows 7 and XP, so nothing changes there.
- `setDarkWinAttribs()` is called only from dark-mode branches, after `setMenusTheme()` has run (start-up 496-497, toggle 74493). Only a message box shown in dark mode during start-up, before line 496, would behave differently: it would get the call it misses today.

## 2. One-function globals

### 2.1 → locals

Each is written before its first read on every path through its function, so the value never has to survive between calls. Change: drop the name from its `Global` block.

| Global | Declared | Uses | Why a local is enough |
|---|---|---|---|
| `menusList` | `module-interface.ahk:9`, `:= ""` | `BuildMenuBar()` (module-interface.ahk) 2391, 2393, 2395, 2397, 2399, 2401 write; 2408 read (`Loop, Parse, menusList, \|`) | The if/else chain at 2390-2401 assigns it on every branch and ends in `Else`. |
| `startPageIndex` | 108, `:= 0` | `UpdateThumbsScreen()` 5248 write (`thumbsInfoYielder(...)`); 5270, 5287, 5291, 5297 read | The only exit before 5248 is the `Return` at 5243. |
| `cmdExifTool` | 218, `:= ""` | `batchRemoveMetaData()` 40655 write (`new cli(...)`); 40703, 40730, 40748, 40749 read (`.Close()` last) | Every `Return` of the function before 40655 comes first, and the only later one (40764) follows `.Close()`. As a local, the `cli` object is released when the function returns, so its `__Delete()` (`cli-interface.ahk:47`) runs then instead of at the next call or at exit; see Seen in passing. |

### 2.2 → `Static`

| Global | Declared | Uses | Change |
|---|---|---|---|
| `hCWPhook` | `module-interface.ahk:16`, `:= 0` | `uiInstallSentMsgHook()` (module-interface.ahk) 155, 159, 160, 163, 164, 174, 177, 179, 188, 192 | The hook handle must survive between the calls from `initInterfaceModule()`, `initQPVmainDLL()` and the function itself, which unhook and re-install the hook. `Static hCWPhook := 0`. |
| `hasMemThumbsCached` | 153, `:= 0` | `QPV_ShowThumbnails()` 87807, 87810, 87811, 87812, 87818, 87819, 87820, 87821 | The next slot of the in-memory thumbnails cache, a ring that wraps at `maxMemThumbsCache`. `Static hasMemThumbsCached := 0`. `gdipObjectsTerminator()` empties the cache arrays (105233-105234) without resetting the slot, as it does now. |
| `createdQuickMenuSearchWin` | 195, `:= 0` | `PanelQuickSearchMenuOptions()` 42643, 42650, 42655 read; 42704 write | Remembers that the Quick search window exists; only this function destroys (42666) and rebuilds it. `Static createdQuickMenuSearchWin := 0`. |
| `maxVectorUndoLevels` | 323, `:= 30` | `recordVectorUndoLevels()` 17305, 17315 | Never assigned, so a constant. `Static maxVectorUndoLevels := 30`, or the literal 30. |
| `hasOpened` (function-level) | `PanelFindDupes()` 91518 | `PanelFindDupes()` 91522 read, 91526 write | Only this function declares it `Global` (`PanelCombineImagesMultipage()` has its own `Static hasOpened`, 44836). It makes the `UIcheck*` initializers at 91524 run once. Remove it from 91518 and add it to the `Static` line at 91519: `Static userWasWarned := 0, hasOpened := 0`. |

### 2.3 Start-up code only: `FirstRun`

Declared at 106 (`:= 1`). Only the auto-exec section uses it: 453 (`IniRead, FirstRun, ...`), 454, 458, 459 (`IniWrite`). Auto-exec code runs in the global scope, so it keeps the same variable after the name leaves the `Global` block, and no function reads it. Change: drop `FirstRun := 1` from line 106. The 1 it holds before the `IniRead` is never read: `IniRead` overwrites it with the stored value or the `@` default.

## 3. Delete

- **`dynamicThumbsColumns`** (286, `:= 0`) is never assigned, and the `INIaction` line that saved it is commented out (11841). The test `thumbsColumns>0 && dynamicThumbsColumns=0` in `recalculateThumbsSizes()` (5004) is always just `thumbsColumns>0`. The two `If (dynamicThumbsColumns=1)` branches in `ChangeThumbsZoom()` never run: the zoom-level step at 11815-11821 and its tooltip at 11842-11843. Change: delete the global, the `&& dynamicThumbsColumns=0` test, both dead branches (keep their `Else` bodies) and the commented `INIaction` line.
- **`CSmid`** (151, `:= "▒"`): nothing uses it.
- **`lastInvoked` in `CopyMovePanelWindow()`**: `Global BtnCpyMv, LViewDynas, lastInvoked := 1` (60811) makes it a global for this function alone. It is written at 60837 and read nowhere. Change: remove it from 60811 and delete 60837. The `Static lastInvoked` of other functions are separate variables.
- **19 function-level declarations with no control and no use.** Each name was searched in `quick-picto-viewer.ahk` and `lib/*.ahk` as `name`, `vName` and `HwndName`, and against every `prefix%x%suffix` form and every quoted prefix followed by a concatenation; `GuiAddSlider()` names its controls `customSliders<var>` and `customLblSliders<var>`, so none comes from it. The names:
  - `realTimePreview` (92774; only the commented-out `GuiControlGet` lines 93396 and 93500 mention it)
  - `NewVProt` (55033; its ComboBox is commented out at 55052)
  - `editF10` (58698) and `editF12` (58699)
  - `BtnPosX1p`, `BtnPosY1p`, `BtnPosX2p`, `BtnPosY2p`, `BtnPosXp`, `BtnPosYp`, `BtnPosZp` (55034-55035; only the `BtnPos*m` names get a control, 55055-55061)
  - `infoBlurAmount` (53740, the whole line)
  - `infoDrawLineAreaOpacity` and `infoDrawLineAreaContour` (52731)
  - `infoResultRes` (54462)
  - `SliderA`, `SliderB`, `infoSliderA`, `infoSliderB` (59242, the whole line)

## 4. Stays

Each table lists every use (function: lines) at 62e83ad. A function that only shows reads may set the value through a ByRef output or a chained assignment on the listed line.

### Timestamps compared on a later event (13)

Each holds an `A_TickCount` (or, for `drawModeAzeit`, how long the last draw took) that a later message, click, timer or call compares against. A parameter cannot carry a value from one event to the next.

| Global | Declared | Used in (function: lines) | Note |
|---|---|---|---|
| `lastDoubleClickZeit` | module-interface.ahk:13 | `uiWM_LBUTTONDOWN()` (module-interface.ahk) 1353; `WM_LBUTTON_DBL()` (module-interface.ahk) 1464, 1477 |  |
| `lastZeitPanCursor` | module-interface.ahk:14 | `uiChangeMcursor()` (module-interface.ahk) 1753; `uiWM_MOUSEMOVE()` (module-interface.ahk) 1793 |  |
| `lastEditRHChange` | 101 | `EditResizeWidth()` 94755; `EditResizeHeight()` 94825, 94843 | Written with a redundant function-level `Global` (see Seen in passing). |
| `lastEditRWChange` | 102 | `EditResizeWidth()` 94764, 94782; `EditResizeHeight()` 94816 | Written with a redundant function-level `Global` (see Seen in passing). |
| `lastGIFdestroy` | 136 | `autoChangeDesiredFrame()` 12463, 12502; `OnImgFileChangeActions()` 78315 |  |
| `lastMenuBarUpdated` ⁽⁰⁹⁻⁰⁵⁾ | 143 | `TriggerMenuBarUpdate()` 4938; `createGDIPcanvas()` 75570 | Read by `createGDIPcanvas()`, which 11 functions call, to skip work for 500 ms after a menu-bar update. |
| `lastInfoBoxZeitToggle` ⁽⁰⁹⁻⁰⁵⁾ | 215 | `ToggleInfoBoxu()` 73679; `QPV_ListViewGridHUDoverlay()` 86731 | The reader runs from a timer (73683) and from 20 other places; it checks the time since the toggle. |
| `lastFastImgChangeHUDzeit` | 206 | `dummyFastImageChangePlaceHolder()` 76552, 76555, 76563; `IDshowImage()` 90527 |  |
| `lastMouseLeave` | module-interface.ahk:13 | `WM_LBUTTON_DBL()` (module-interface.ahk) 1484; `WM_MOUSELEAVE()` (module-interface.ahk) 1896; `activateMainWin()` (module-interface.ahk) 1903 |  |
| `lastSwipeZeitGesture` | module-interface.ahk:13 | `winSwipeAction()` 5745; `uiWM_LBUTTONDOWN()` (module-interface.ahk) 1348; `WM_LBUTTON_DBL()` (module-interface.ahk) 1469 |  |
| `prevFastDisplay` | 143 | `ReloadThisPicture()` 4327; `coreShowTheImage()` 76541; `QPV_ShowImgonGui()` 84991 |  |
| `drawModeAzeit` | 155 | `changeDesiredFrame()` 12402; `ShowTheImage()` 76331; `QPV_ShowImgonGui()` 84541, 84997 | How long the last draw took (84997), not a moment in time. |
| `prevTryThumbsUpdate` | 158 | `UpdateThumbsScreen()` 5266, 5270, 5278; `ShowTheImage()` 76378, 76382; `QPV_listThumbnailsGridMode()` 86662 |  |

### Handles and objects that live between calls (16)

GDI, GDI+, hook, COM and window handles created by one function and used or freed by others, sometimes much later (at exit, on the next resize).

| Global | Declared | Used in (function: lines) | Note |
|---|---|---|---|
| `glOBM` | 97 | `destroyGDIPcanvas()` 75541, 75544, 75545; `createGDIPcanvas()` 75593, 75606, 75607 |  |
| `2NDglHbitmap` | 167 | `destroyGDIPcanvas()` 75553, 75554, 75562; `createGDIPcanvas()` 75599, 75600, 75606, 75607 |  |
| `2NDglOBM` | 167 | `destroyGDIPcanvas()` 75552, 75555, 75556; `createGDIPcanvas()` 75600, 75606, 75607 |  |
| `hLLmouseHook` | module-interface.ahk:16 | `uiMenuLoopEnter()` (module-interface.ahk) 391, 396; `uiMenuLoopExit()` (module-interface.ahk) 407, 409, 410 |  |
| `pPen1` | 97 | `MouseMoveResponder()` 6088; `InitGDIpStuff()` 75663; `printImageNow()` 103942, 103944 | Also freed by the `Gdip_DeletePen(pPen%A_Index%)` loop in `TrueCleanup()` (4468). |
| `pPen2` | 97 | `MouseMoveResponder()` 6022, 6038; `InitGDIpStuff()` 75667; `QPV_ListViewGridHUDoverlay()` 86716, 86887, 86888 | Also freed by the `pPen%A_Index%` loop in `TrueCleanup()` (4468). |
| `pPen6` | 96 | `InitGDIpStuff()` 75671; `drawVisibleVectorPoints()` 82326, 82379, 82400, 82401; `QPV_ListViewGridHUDoverlay()` 86702, 86901 | Also freed by the `pPen%A_Index%` loop in `TrueCleanup()` (4468). |
| `pPen7` | 102 | `MouseMoveResponder()` 6070; `InitGDIpStuff()` 75672; `drawVisibleVectorPoints()` 82327, 82372 | Also freed by the `pPen%A_Index%` loop in `TrueCleanup()` (4468). |
| `thisBMPdummy` | 199 | `InitGDIpStuff()` 75660, 75661; `gdipObjectsTerminator()` 105211 | `gdipObjectsTerminator()` skips this bitmap when it frees leaked ones. |
| `dummyGu` | 199 | `InitGDIpStuff()` 75661; `getAccuratePathBounds()` 83986, 83987, 83988 | A Graphics object made once at start-up on `thisBMPdummy`. |
| `OSDwinFadedBrushBGR` | 187 | `TrueCleanup()` 4463; `refreshWinBGRbrush()` 75763, 75764, 75774; `drawinfoBox()` 77130 |  |
| `gdiAmbientalTexBrush` | 188 | `TrueCleanup()` 4464; `extractAmbientalTexture()` 78269, 78270, 78281; `QPV_ShowImgonGui()` 84882, 84943 |  |
| `GDIbrushWinBGR` | 188 | `TrueCleanup()` 4465; `refreshWinBGRbrush()` 75767, 75768, 75773; `useGdiHatchedBrush()` 75803 |  |
| `taskBarUI` | module-interface.ahk:11 | `destroyAllGUIs()` (module-interface.ahk) 645; `BuildGUI()` (module-interface.ahk) 695; `setTaskbarIconState()` (module-interface.ahk) 793, 795, 797, 800, 802 |  |
| `hLViconsu` | 170 | `PanelManageVectorShapes()` 51453, 51456; `getSelectedVectorShapeLVrow()` 51509 | The vector-shapes ListView handle, read by a later selection lookup. |
| `lastMsgBox2win` | msgbox2.ahk:57 | `MsgBox2()` (msgbox2.ahk) 455; `KillMsgbox2Win()` (msgbox2.ahk) 502, 506 | Read by `KillMsgbox2Win()`, a g-label of the box (`msgbox2.ahk:348`) with four direct callers. |

### Caches, lists and values found at start-up (22)

Data built once (or kept between calls) and read by other functions: journals, bitmap and thumbnail caches, menu maps, panel memories, format lists filled when a module initialises.

| Global | Declared | Used in (function: lines) | Note |
|---|---|---|---|
| `QPVerrJournal` | 100 | `PanelJournalWindow()` 58514, 58515; `addJournalEntry()` 75515, 75519 |  |
| `QPVjournal` | 102 | `PanelJournalWindow()` 58504, 58505; `addJournalEntry()` 75525, 75529 |  |
| `FontList` | 140 | `uiPopulateFontsList()` 58893, 58896, 58899, 58901; `CallBack_EnumFontFamExProc()` 100691 | Filled once by `CallBack_EnumFontFamExProc()`, a native callback, then reused for every panel. |
| `userCustomAltKeys` | 204 | `forbiddenAltKeys()` 26427, 26428; `loadCustomUserKbds()` 39159, 39191, 39192 |  |
| `menuCustomNames` | 220 | `kMenu()` 72153, 72201, 72215, 72219, 72220; `deleteMenus()` 72398 |  |
| `cachedAllSessionsSeen` | 135 | `ToggleSeenIMGstatus()` 75839, 75876; `retrieveSeenImageDBentry()` 76071, 76101, 76107; `recordSeenIMGdbEntry()` 76131 |  |
| `imgThumbsCacheArray` | 161 | `QPV_ListViewGridHUDoverlay()` 86797; `QPV_ShowThumbnails()` 87405, 87687, 87810, 87811, 87814, 87815, 87818; `gdipObjectsTerminator()` 105233 |  |
| `imgThumbsCacheIDsArray` | 161 | `QPV_ListViewGridHUDoverlay()` 86796, 86797; `QPV_ShowThumbnails()` 87405, 87687, 87806, 87811, 87819; `gdipObjectsTerminator()` 105234 |  |
| `infoBoxGdiCached` | 174 | `disposeCacheIMGs()` 16826; `downscaleHugeImagesForEditing()` 17528; `drawinfoBox()` 76956, 76959, 76960, 76964, 76966, 76967 |  |
| `prevHistoBoxString` ⁽⁰⁹⁻⁰⁵⁾ | 215 | `createHistogramBMP()` 78668; `drawHUDelements()` 82040 | Kept with `HistogramBMP`. `createHistogramBMP()` runs from two branches (81854, 81864), the second only when the image or view changed; a draw that runs neither reuses the string. |
| `lastSlidersPainted` | 204 | `createSettingsGUI()` 28131; `CloseWindow()` 100361; `GuiRefreshSliders()` 107870, 107874 |  |
| `menuJITlist` | module-interface.ahk:16 | `uiRefreshBarAttachments()` (module-interface.ahk) 428, 433, 435; `invokeGivenMenuBarPopup()` (module-interface.ahk) 2368; `BuildMenuBar()` (module-interface.ahk) 2406, 2429 |  |
| `menuHotkeys` | 215 | `KeyboardResponder()` 952, 955; `BuildMenuBar()` (module-interface.ahk) 2405, 2414, 2434, 2435, 2437; `uiWM_KEYDOWN()` (module-interface.ahk) 2596 |  |
| `SearchedStringz` | 200 | `EraseSearchEdit()` 47946; `PanelSearchIndex()` 47970, 47993; `BtnPerformSearchNow()` 48061, 48063, 48064 |  |
| `TabsPerWindow` | 202 | `createSettingsGUI()` 28190; `BtnTabsInfoUpdate()` 51047; `selectGivenPanelTab()` 92755 |  |
| `LVitemsPerPage` | 103 | `uiLVreviewSelFilesResponder()` 97262; `uiPopulateReviewSelectedFiles()` 97450, 97452 | Lowered at run time when a page takes over 3.5 s to fill (97452). |
| `openFptrnWIC` | 127 | `initQPVmainDLL()` 2422, 2424, 2425; `fileImgFormatsOpenDialog()` 43917, 43918 | Built when the WIC module initialises (2422-2424). |
| `RegExAllFilesPattern` | 115 | (auto-exec) 116; `initQPVmainDLL()` 2411, 2414; `GetFilesList()` 90273, 90276, 90281 | Extended when the WIC module initialises (2414). |
| `GDIcacheSRCfileA` | 164 | `destroyGDIfileCache()` 16757, 16770; `discardSRCfileCaches()` 16802, 16805; `LoadBitmapForScreen()` 77545, 77552, 77554, 77555, 77558, 77670, 77671 |  |
| `GDIcacheSRCfileB` | 164 | `destroyGDIfileCache()` 16763, 16776; `discardSRCfileCaches()` 16803, 16805; `LoadBitmapForScreen()` 77546, 77559, 77561, 77562, 77565, 77569, 77669, 77670 |  |
| `idGDIcacheSRCfileA` | 164 | `destroyGDIfileCache()` 16754, 16756, 16767, 16769; `discardSRCfileCaches()` 16804; `LoadBitmapForScreen()` 77667, 77668 |  |
| `idGDIcacheSRCfileB` | 164 | `destroyGDIfileCache()` 16760, 16762, 16773, 16775; `discardSRCfileCaches()` 16804; `LoadBitmapForScreen()` 77568, 77667 |  |

### Modes, flags and counters read on a later event (32)

State that one event sets and a later event, timer or call reads: menu-loop and hook state, undo limits, viewer modes, paging positions, the pending keyboard key.

| Global | Declared | Used in (function: lines) | Note |
|---|---|---|---|
| `popupRootSeen` | module-interface.ahk:15 | `uiCallWndProcWork()` (module-interface.ahk) 275, 277; `uiMenuLoopEnter()` (module-interface.ahk) 390 |  |
| `menuRButtonEaten` | module-interface.ahk:17 | `uiMenuLoopEnter()` (module-interface.ahk) 390; `uiMenuLoopExit()` (module-interface.ahk) 402; `uiMenuMouseLL()` (module-interface.ahk) 580, 583, 586, 588 |  |
| `uiMenuReaderLastMsg` | module-interface.ahk:16 | `uiMenuSelectTrack()` (module-interface.ahk) 379; `uiMenuLoopExit()` (module-interface.ahk) 404; `uiMenuMouseLL()` (module-interface.ahk) 575, 577 |  |
| `wasMenuFlierCreated` | module-interface.ahk:10 | `uiTryPlaceFlyout()` (module-interface.ahk) 524; `destroyMenuFlyout()` (module-interface.ahk) 2319; `guiCreateMenuFlyout()` (module-interface.ahk) 2345 |  |
| `hasReachedMaxUndoLevels` | 166 | `recordUndoLevelNow()` 16965, 16968; `terminateIMGediting()` 17076, 17101 |  |
| `maxUndoLevels` | 168 | (auto-exec) 477; `recordUndoLevelNow()` 16966, 16968, 16983, 16998; `decideMaximumUndoLevels()` 17014, 17019, 17021, 17024 | Set at start-up (477) and adjusted by memory checks. |
| `maxMemUndoLevels` | 180 | `TogglePreventUndos()` 74912; `generalInternalErrorMsgBox()` 77871, 77872 |  |
| `allImagesWereSeen` | 166 | `coreNextPrevImage()` 12740, 12765; `renewCurrentFilesList()` 65510 |  |
| `screenSaverMode` | 233 | `toggleScreenSaverMode()` 74792, 74793, 74794; `drawWelcomeImg()` 75057, 75065, 75103, 75133 |  |
| `dynamicLiveObjVisible` | 139 | `corelivePreviewsImageEditing()` 6273; `additionalHUDelements()` 83281; `toggleLiveEditObject()` 83346, 83348, 83351 |  |
| `LastWasFastDisplay` | 140 | `ShowTheImage()` 76331; `coreShowTheImage()` 76500; `QPV_ShowImgonGui()` 84996 |  |
| `lastWasLowQuality` | 147 | `ImageNavBoxClickResponder()` 79210; `ActPaintBrushNow()` 81246; `QPV_ShowImgonGui()` 84645, 84976, 84985 |  |
| `mustReloadThumbsList` | 112 | `RefreshThumbsList()` 5217; `UpdateThumbsScreen()` 5270, 5287, 5293; `QPV_ShowThumbnails()` 87923, 87948 |  |
| `prevStartIndex` | 112 | `ForceRefreshNowThumbsList()` 5223; `UpdateThumbsScreen()` 5287, 5297 |  |
| `prevFullIndexThumbsUpdate` | 158 | `UpdateThumbsScreen()` 5270, 5291; `QPV_listThumbnailsGridMode()` 86660; `QPV_ShowThumbnails()` 87924 |  |
| `qpvCanvasHasInit` | 175 | (auto-exec) 483, 487; `destroyGDIPcanvas()` 75540; `createGDIPcanvas()` 75579, 75609, 75615 |  |
| `preventHUDelements` | 187 | `ShowTheImage()` 76318; `drawHUDelements()` 81820, 81822; `GuiGDIupdaterResize()` 88322 | A one-shot "skip the HUD on the next draw" set by a window resize (88322); the next draw may come from a timer. |
| `hasDrawnAnnoBox` | 222 | `WinClickAction()` 10268; `drawAnnotationBox()` 77235, 77240; `additionalHUDelements()` 83304 |  |
| `userPendingAbortOperations` | module-interface.ahk:12 | `initAppBusyMode()` (module-interface.ahk) 782; `askAboutStoppingOperations()` (module-interface.ahk) 1531, 1536, 1542, 1543; `uiChangeMcursor()` (module-interface.ahk) 1723 |  |
| `prevFolderSortMode` | 191 | `SortFilesList()` 37793, 37795, 38085; `RegenerateEntireList()` 88676, 88679 |  |
| `lastSelPrinterName` | 138 | `BtnOpenPrinterOptions()` 54712, 54716; `BtnSetPrinterDefault()` 54723, 54726; `printSettingsObj()` 54762, 54791 |  |
| `uiLVoffset` | 213 | `UImultiRenameChangeLVoffset()` 41169, 41196, 41201, 41204, 41206, 41211, 41212; `uiPopulateLVmultiRename()` 41789, 41858, 41865, 41875, 41930, 41931, 41935 |  |
| `repositionedWindow` ⁽⁰⁹⁻⁰⁵⁾ | 213 | `repositionWindowCenter()` 27938; `CloseWindow()` 100357 | See Seen in passing: `MsgBox2()` resets it. |
| `adjustingSelDotNow` | 289 | `WinClickAction()` 10406, 10775; `ViewPortSelectionManageCoords()` 83518 | Set during a selection-dot drag in `WinClickAction()`, read by `ViewPortSelectionManageCoords()`, which 20 functions call; a parameter would have to run through the whole repaint path. |
| `simulateMenusMode` | 205 | `stopGIFsPlayback()` 12411; `testFuncIsInMenus()` 43292, 43294; `kMenu()` 72182, 72223, 72234, 72278, 72290, 72296, 72311, 72317 | Courier-shaped: set to 1 around `buildQuickSearchMenus()` (43292-43294) so menu building only records. The reader `kMenu()` has 1,722 call sites spread over every menu builder, and `stopGIFsPlayback()` reads it too, so a parameter would have to pass through all of them. |
| `hasPenPressureAPI` | module-interface.ahk:11 | `initInterfaceModule()` (module-interface.ahk) 34, 35; `pumpPenMessages()` (module-interface.ahk) 615 | Found at start-up; `initInterfaceModule()` uses it to register the pen handlers and `pumpPenMessages()` checks it on every brush stroke. |
| `penPressureRaw` | module-interface.ahk:11 | `getBrushPenPressure()` 4269; `readPenPointerMsg()` (module-interface.ahk) 1613, 1631, 1639 | `readPenPointerMsg()` also runs from the `WM_PENpressure()` message handler; the brush reads the latest value. |
| `groppedFiles` | module-interface.ahk:11 | `PVwinGuiDropFiles()` (module-interface.ahk) 1935, 1948; `dummyTimerProcessDroppedFiles()` (module-interface.ahk) 1957, 1969, 2007 | Carries the dropped files to the timer `dummyTimerProcessDroppedFiles()` (1950) and is also the "drop pending" guard of the next drop (1935). A bound timer function would lose the guard. See Seen in passing. |
| `hotkate` | 211 | `PreProcessKbdKey()` 603, 606, 611, 612, 618, 619, 620; `WM_KEYDOWN()` 718, 724; `uiWM_KEYDOWN()` (module-interface.ahk) 2629 | Hands the key to `PreProcessKbdKey()`, started by `SetTimer` (723, 2630). Re-arming the same timer folds fast key repeats into one run; a bound function per key would start one timer per key. |
| `vk_hwnd` ⁽⁰⁹⁻⁰⁵⁾ | 211 | `PreProcessKbdKey()` 592; `WM_KEYDOWN()` 719; `uiWM_KEYDOWN()` (module-interface.ahk) 2621 | Same as `hotkate`: the window that had the key, for the same timer. |
| `GIFspeedDelay` | 252 | `animPlaybackDelay()` 12439; `setGIFframesDelay()` 77382, 77383; `LoadFimFile()` 103119, 103127 | The frame delay of the loaded animation. |
| `desiredSelAspectRatio` | 289 | `WinClickAction()` 10401, 10749; `defineSelectionAspectRatios()` 74173, 74175, 74177, 74179, 74181, 74183, 74185, 74187, 74189, 74191, 74194; `ViewPortSelectionManageCoords()` 83518, 83521 |  |

### Positions and sizes from the last draw (27)

Coordinates and sizes worked out while painting, read later by a click hit-test, a mouse move or the next draw.

| Global | Declared | Used in (function: lines) | Note |
|---|---|---|---|
| `prevSelDotX` ⁽⁰⁹⁻⁰⁵⁾ | 139 | `PasteInPlaceEraseArea()` 53625; `prevModeViewPortSelectionManager()` 83699 | A snapshot of the selection taken when the transform panel opens (49252), read by later paste-in-place previews. The four `prevSelDot*` could be one array `[x1, y1, x2, y2]` without the `-dotsSize//2` / `+SelDotsSize//2` round trip. |
| `prevSelDotY` ⁽⁰⁹⁻⁰⁵⁾ | 139 | `PasteInPlaceEraseArea()` 53626; `prevModeViewPortSelectionManager()` 83700 | See `prevSelDotX`. |
| `prevSelDotAx` ⁽⁰⁹⁻⁰⁵⁾ | 139 | `PasteInPlaceEraseArea()` 53625; `prevModeViewPortSelectionManager()` 83701 | See `prevSelDotX`. |
| `prevSelDotAy` ⁽⁰⁹⁻⁰⁵⁾ | 139 | `PasteInPlaceEraseArea()` 53626; `prevModeViewPortSelectionManager()` 83702 | See `prevSelDotX`. |
| `selDotCx` | 146 | `determineSelAreaClickRect()` 6561, 6574; `ViewPortSelectionManageCoords()` 83629; `drawImgSelectionOnWindow()` 84175, 84191, 84364 |  |
| `selDotCy` | 145 | `determineSelAreaClickRect()` 6561, 6587; `ViewPortSelectionManageCoords()` 83630; `drawImgSelectionOnWindow()` 84175, 84191, 84364 |  |
| `selDotMaX` | 214 | `determineSelAreaClickRect()` 6563, 6576; `ViewPortSelectionManageCoords()` 83633, 83643; `drawImgSelectionOnWindow()` 84181 |  |
| `selDotMaY` | 214 | `determineSelAreaClickRect()` 6563, 6589; `ViewPortSelectionManageCoords()` 83634, 83643; `drawImgSelectionOnWindow()` 84181 |  |
| `selDotMbX` | 214 | `determineSelAreaClickRect()` 6564, 6577; `ViewPortSelectionManageCoords()` 83635, 83643; `drawImgSelectionOnWindow()` 84182 |  |
| `selDotMbY` | 214 | `determineSelAreaClickRect()` 6564, 6590; `ViewPortSelectionManageCoords()` 83636, 83643; `drawImgSelectionOnWindow()` 84182 |  |
| `selDotMcX` | 214 | `determineSelAreaClickRect()` 6565, 6578; `ViewPortSelectionManageCoords()` 83637, 83643; `drawImgSelectionOnWindow()` 84183 |  |
| `selDotMcY` | 214 | `determineSelAreaClickRect()` 6565, 6591; `ViewPortSelectionManageCoords()` 83638, 83643; `drawImgSelectionOnWindow()` 84183 |  |
| `selDotMdX` | 214 | `determineSelAreaClickRect()` 6566, 6579; `ViewPortSelectionManageCoords()` 83639, 83643; `drawImgSelectionOnWindow()` 84180 |  |
| `selDotMdY` | 214 | `determineSelAreaClickRect()` 6566, 6592; `ViewPortSelectionManageCoords()` 83640, 83643; `drawImgSelectionOnWindow()` 84180 |  |
| `HUDobjHistoBoxu` | 177 | `MouseMoveResponder()` 6028; `drawHistogram()` 14107, 14108; `drawHUDelements()` 82036, 82037, 82038 |  |
| `lastInfoBoxBMP` | 211 | `drawinfoBox()` 76968, 77126; `QPV_ListViewGridHUDoverlay()` 86732; `CreateOSDinfoLine()` 100602, 100604, 100606, 100608, 100610 |  |
| `ThumbsStatusBarH` | 160 | `thumbsListClickResponder()` 9648; `drawAnnotationBox()` 77199; `QPV_ListViewGridHUDoverlay()` 86962, 86965, 86973, 86980, 86988, 87000, 87005 | Filled as a ByRef output of `trGdip_GetImageDimensions()` (86962). |
| `imgDecLX` | 167 | `limitPanningDist()` 5599, 5600; `calcIMGcoordsInVP()` 88025; `simulateCalcImageCoordsInVP()` 88137 | Also written by `simulateCalcImageCoordsInVP()`, which nothing calls. |
| `imgDecLY` | 167 | `limitPanningDist()` 5604, 5605; `calcIMGcoordsInVP()` 88026; `simulateCalcImageCoordsInVP()` 88138 | See `imgDecLX`. |
| `hudBTNtypeFuncu` ⁽⁰⁹⁻⁰⁵⁾ | 190 | `WinClickAction()` 10138, 10141; `CreateOSDinfoLine()` 100536, 100537, 100554, 100640 | The OSD button's hit rectangle, kept while the OSD message shows. With `hudBTNfuncu` (5 functions) these could be one object. |
| `hudBTNheightFuncu` ⁽⁰⁹⁻⁰⁵⁾ | 190 | `WinClickAction()` 10138; `CreateOSDinfoLine()` 100618, 100639 | See `hudBTNtypeFuncu`. |
| `hudBTNwidthFuncu` ⁽⁰⁹⁻⁰⁵⁾ | 190 | `WinClickAction()` 10138; `CreateOSDinfoLine()` 100619 | See `hudBTNtypeFuncu`. |
| `prevPasteInPlaceVPcoords` | 212 | `testAllowOutsidePasteInPlace()` 14174, 14182; `corePasteInPlaceActNow()` 16178 |  |
| `prevAlphaMaskCoordsPreview` | 223 | `getPrevAlphaMaskCoords()` 15976, 15977, 15978, 15979; `recordPrevAlphaMaskCoords()` 15992 |  |
| `lastSymmetryCoords` | 211 | `PanelSymmetricaImage()` 52932, 52933; `livePreviewSymmetricaImgArea()` 56644 |  |
| `VPstampBMPx` | 184 | `performAutoExpandCanvas()` 14149; `realtimePasteInPlaceBlurrator()` 14495; `MainPanelTransformArea()` 49177 |  |
| `VPstampBMPy` | 184 | `performAutoExpandCanvas()` 14150; `realtimePasteInPlaceBlurrator()` 14496; `MainPanelTransformArea()` 49177 |  |

### Constants shared by two or three functions (12)

Never assigned after the declaration. Each is read by more than one function, so a `Static` would have to be repeated; keeping one global is the simpler choice.

| Global | Declared | Used in (function: lines) | Note |
|---|---|---|---|
| `multiPageAllTypesRegEx` | 120 | `InvokeMenuBarImage()` 69134, 69136, 69184, 69186; `createMenuCurrentFilesActs()` 70755, 70764 |  |
| `maxMemLimitMultiPage` | 216 | `combineImagesFimMultiPage()` 64902, 64905; `coreConvertImgToMultiPage()` 65224, 65226 |  |
| `maxMultiPagesAllowed` | 216 | `PanelCombineImagesMultipage()` 44922, 44923; `combineImagesFimMultiPage()` 64902, 64905; `coreConvertImgToMultiPage()` 65198, 65201 |  |
| `maxFavesEntries` | 178 | `ToggleImgFavourites()` 39592, 39600, 39602, 39627, 39657, 39703, 39749; `retrieveFavesAsList()` 39861, 39862; `saveFavesListBasedOnIndexList()` 39952 |  |
| `saveTypesFriendly` | 122 | `SaveClipboardImage()` 60449; `BTNsaveResizedIMG()` 94610; `BtnPerformSimpleProcessing()` 102301, 102302 |  |
| `saveAlphaTypesRegEX` | 123 | `SaveClipboardImage()` 60514; `coreConvertImgFormat()` 63299; `coreResizeIMG()` 90735 |  |
| `openFptrn3` | 126 | `initQPVmainDLL()` 2418; `fileImgFormatsOpenDialog()` 43908; `addNewFile2list()` 66267 |  |
| `verType` | 225 | `setWindowTitle()` 4523; `PanelAboutWindow()` 91161, 91209 | Its initializer depends on `A_IsCompiled`. |
| `vReleaseDate` | 226 | `checkForUpdatesNow()` 69725; `PanelAboutWindow()` 91164 |  |
| `CSdrk` | 150 | `BTNmultiRenameCheckAll()` 41320; `uiPopulateLVmultiRename()` 41850 | Used only by the multi-rename panel; literals would do as well. |
| `CSthin` | 151 | `PanelMultiRenameFiles()` 41134; `BTNmultiRenameCheckAll()` 41304, 41320, 41372; `uiPopulateLVmultiRename()` 41794, 41837, 41850, 41940 | Used only by the multi-rename panel; literals would do as well. |
| `defaultTempBtnDisplay` | module-interface.ahk:10 | `CreateTempGuiButton()` (module-interface.ahk) 2185; `tempBtnGuiClick()` (module-interface.ahk) 2275, 2280; `DestroyTempBtnGui()` (module-interface.ahk) 2308 |  |

## Seen in passing (read only, not run)

- **A drop can be refused until restart.** `dummyTimerProcessDroppedFiles()` returns without clearing `groppedFiles` when it fires less than 400 ms after its previous run finished (`module-interface.ahk:1958-1959`), and nothing starts the timer again. `PVwinGuiDropFiles()` then refuses every later drop as "busy", because `groppedFiles.Count()>0` (1935). It takes a second drop within about 200 ms of the first one finishing (the timer is started 200 ms after the drop, 1950).
- **A message box resets `repositionedWindow`.** `MsgBox2()` calls `repositionWindowCenter()` without `winPos` (`msgbox2.ahk:440`), which sets `repositionedWindow := 0` (27938). After a message box shown while a position-remembering panel is open, `CloseWindow()` skips `WinGetPos` for the panel (100357-100358), so the panel may next open where it was before the user moved it.
- **30 redundant function-level `Global` lines** re-declare 8 super-globals; plain assignments do the same. They are: `lastOtherWinClose` 17 times (3045, 4877, 9764, 26330, 30950, 42800, 43206, 49001, 49005, 49647, 49662, 49680, 49958, 69956, 71854, 72351, 100373), `scriptStartTime` (66228, 66234, 66243), `lastWinDrag` (3044, 71896), `zeitSillyPrevent` (49957, 109002), `lastEditRWChange` (94764, 94782), `lastEditRHChange` (94825, 94843), `findFlippedDupes` (91704), `AllowDarkModeForWindow` (`shell-stuff.ahk:1234`).
- **The ExifTool pipe handles are closed twice.** `cli.close()` (`cli-interface.ahk:51-56`) does not clear `hStdInWr`/`hStdOutRd`, and `__Delete()` calls it again, so `batchRemoveMetaData()`'s explicit `.Close()` (40749) is followed by a second `CloseHandle` on the same two values when the object is released. If Windows has reused a value by then, the second call closes someone else's handle.
- `imgDecLX` and `imgDecLY` are also written by `simulateCalcImageCoordsInVP()` (88137-88138), which nothing calls (also listed in `near-identical-functions-2026-11-23.md`).

## Regenerating the lists

The scripts are in `.claude/scratch/low-use-globals-2026-11-23/` (not in git). Run them from the repository root; `scan.json`, `rows2.json` and `report_head.md` live next to the scripts.

```
K=.claude/scratch/low-use-globals-2026-11-23
python3 -I $K/scan.py . $K/scan.json                         # globals, functions, every use
python3 -I $K/stats2.py $K/rows2.json                         # per-global counts, shadowing, grep cross-check
python3 -I $K/dump.py . $K/scan.json $K/rows2.json $K/dump2.txt 3   # candidates with code and call paths
python3 -I $K/report.py reports/low-use-globals-2026-11-23.md   # this report; asserts the verdicts cover all 134
```

The verdicts and notes are written by hand in `report.py` (the `GROUPS`, `NOTES` and `ACTION` tables) and in `report_head.md`.
