# Quick-action bar: more places to use it

Snapshot of 2026-10-29, commit 95c16dc on `development`. Line numbers refer to `quick-picto-viewer.ahk` at that commit; "module-interface.ahk" means `lib/module-interface.ahk`.

The quick-action bar shows one or more tappable buttons after an action, so the next step is one tap away. Today 11 calls show it. This report proposes **51 more spots in 12 patterns**. It also lists the rules a new call must follow, the candidates left out and why, and four bugs found along the way. Those four are fixed by the commits that follow this report.

Nothing in this report is implemented. The choices are yours.

## Terms

- **Bar**: the strip of tappable text buttons that `CreateTempGuiButton()` (module-interface.ahk 2104) shows at the bottom-left of the main window.
- **Touch mode**: the option «Split viewport into areas for touch-screen friendly actions» (`TouchScreenMode`, on by default). Outside touch mode the bar shows only when the call passes "force".
- **Timed bar**: hides after the time the call gives (callers use `msgDisplayTime//1.5 + 500`, about 2.5 s with the default 3 s message time). The pointer over the bar keeps it up.
- **Kept bar**: stays until the code removes it. The caller turns the `DestroyTempBtnGui` timer off right after the call, as `showQuickActionButtonsDrawingShape()` 49048 does.
- **No-argument function**: a function whose parameters all have default values. The bar calls each button's function with no arguments, and drops a button whose function needs one. Every target named below is a no-argument function, unless the entry says a wrapper is needed.
- **Wrapper**: a new small no-argument function that calls an existing one with the right arguments, or remembers a value in a `Static`. The project adds no new global variables.
- **Gate**: the condition under which a spot should show its bar.
- **Message tap**: in touch mode, a message shown with `showTOOLtip(msg, A_ThisFunc, 1)` is itself a tap target that runs the same function again (`CreateOSDinfoLine()` 96296-96300, `WinClickAction()` 9963-9967).

Each entry gives the trigger (keys, menus, toolbar), the place for the call, the buttons as "Label" → target, the gate and the caveats.

## How the bar behaves

- A second call with the same button list while the bar is visible only extends its timer (module-interface.ahk 2119-2124). A different list rebuilds it.
- What removes it: `HardResetImageView()` 11357, a non-panel `msgBoxWrapper()` 32771, `stopDrawingShape()` 48002, `turnOffViewportStuff()` 70485, `ToggleTouchMode()` 71936, a resize of the main window (`GuiGDIupdaterResize()` 85188), the kill call in `startDrawingShape()` 48526, and any call with a different button list.
- What does not remove it: another image, an opened panel, thumbnails mode.
- Clicks on the bar go to `WM_LBUTTONdown()` 99220, not to the viewer's click handler (the bar is not one of the windows `isUIrootWin()` lists, module-interface.ahk 72-75). So a tap on the bar does not stop a slideshow.
- `CreateTempGuiButton()` starts with `Critical, On`, which stays on in the caller's thread.

## Patterns already in use

| Pattern | Where | Buttons |
|---|---|---|
| Undo an applied edit | `applyIMGeditKeepWin()` 6070 (Shift+Enter in a live panel) | Undo action → `ImgUndoAction()` |
| Reopen the panel | same call | Reopen panel → `openPreviousPanel()` |
| Leave an altered view | `VPchangeLumos()` 11481; `RefreshImageFileAction()` 63014, `MenuOpenLastImg()` 63302, `OpenArgFile()` 63344 | Reset all adjustments / Display unaltered image → `HardResetImageView()` |
| Options for what was just toggled | `ToggleMultiLineStatus()` 70738, `ToggleEditImgSelection()` 82341, `dummyFullScreenButtons()` 70477, `dummyToggleTitleBarActionBtns()` 71370 | File options, Selection options, Interface options (+ Hide viewport elements) |
| Start the next step | `toggleEllipseSelection()` 71105 | Draw new form → `MenuStartDrawingSelectionArea()` |
| Cycle a sub-option | same call | Polygonal path / Bézier path / Points tension → `togglePathCurveTension()` |
| Controls while in a mode (kept bar) | `showQuickActionButtonsDrawingShape()` 49047 | Undo, Cancel, Done, Open/Closed path, path type |

Known weak spots of the bar at 6070:

- `ImgUndoAction()` undoes a *file* action when no edited image is in memory or in thumbnails mode (16913-16916). A late tap on "Undo action" after the user left the image can undo a rename or move instead.
- Panels 24 and 31 register as `PanelPasteInPlace()` and `PanelTransformSelectedArea()` (47278, 47283). After pasting an imported file (46924), "Reopen panel" opens a clipboard paste instead.

## New patterns

| # | Pattern | Spots |
|---:|---|---:|
| 1 | Undo a file action | 7 |
| 2 | Undo and reopen after the default Apply | 2 (one covers ten panels) |
| 3 | Undo and next step after edits made without a panel | 5 |
| 4 | Save an image that exists only in memory | 1 |
| 5 | Go to the result | 4 |
| 6 | Messages that tell the user to press a key | 6 |
| 7 | Toolbar right-click actions | 5 |
| 8 | Make a view change permanent | 2 |
| 9 | Controls for a mode just entered | 6 |
| 10 | Undo or step through a list change | 6 |
| 11 | Go back after a jump | 2 |
| 12 | Recover from an error | 5 |

### 1. Undo a file action

Delete to the Recycle Bin, rename, move and copy have a multi-level undo, `doUndoFileActsChronos()` 92357 (Ctrl+Shift+Z in the files list; «Undo previous file action(s)» in the menus). Nothing on screen offers it right after the action. Until v5.9.91 a rename showed an "Undo rename" button; this pattern brings it back for every file action.

`doUndoFileActsChronos()` undoes the latest group of actions, those with the same time stamp. One file is restored at once (`batchUndoFileActs("last")`); several open the multi-undo panel (`PanelMultiUndoFileActs()` 92292), which asks first. It does nothing while a panel is open (92358-92359). Every spot below closes its panel before the file work. Because the undo goes by time and not by the current image, it stays right after the viewer moves to the next image.

**1.1 Delete one file**
- Trigger: Delete, the toolbar's delete button, the menus → `DeletePicture()` 39738, message 39870 «File moved to recycle bin».
- Place: the end of `DeletePicture()`.
- Buttons: "Undo delete" → `doUndoFileActsChronos()` 92357.
- Gate: `canUndo=1`. Shift+Delete deletes for good and records nothing.
- Most useful when delete confirmation is off (`askDeleteFiles=0`): the bar is then the only safety net. When `deleteFileActAfter` moves to the next image (39876-39879), the bar stays and the undo still restores the deleted file.

**1.2 Delete the selected files**
- Trigger: Delete with several files selected → `PanelMultiFileDelete()` → `batchFileDelete()` 39589, message 39725.
- Buttons: "Undo delete" → `doUndoFileActsChronos()` (opens the multi-undo panel).
- Gate: `move2recycler=1` and at least one file removed. Usually thumbnails mode.

**1.3 Rename one file**
- Trigger: F2 → `PanelRenameThisFile()` 42669 → `BTNrenameSoloFileAct()` 46384, message 46475.
- Place: the end of the success branch of `PanelRenameThisFile()` (42723-42731), after the favourites and thumbnail refresh.
- Buttons: "Undo rename" → `doUndoFileActsChronos()`.
- The rename dialog itself offers «Undo rename» when this file's last action was a rename (42692); the bar makes it one tap right after.

**1.4 Rename the selected files**
- Trigger: the multi-rename panel → `coreBatchMultiRenameFiles()` 40358, message 40569 (40567 when aborted).
- Buttons: "Undo rename" → `doUndoFileActsChronos()` (multi-undo panel).
- Gate: at least one file renamed.

**1.5 Move or copy one file, including the quick file action keys**
- Trigger: the copy/move panel (`BtnCopyMoveAction()` 59761) and the quick file action keys (`triggerQuickFileAction()` 45683) → `QuickMoveFile2Dest()` 59914, message 60038.
- Buttons: "Undo move" or "Undo copy" → `doUndoFileActsChronos()`; optionally "Open folder" (the wrapper of pattern 5).
- When the quick action then shows the next image (45770-45772), the undo still restores the moved file.

**1.6 Move or copy the selected files**
- Trigger: the copy/move panel with several files selected → `batchCopyMoveFile()` 60085, messages 60315 and 60321 (60313 and 60319 when aborted).
- Buttons: "Undo move" or "Undo copy" → `doUndoFileActsChronos()`.
- Gate: at least one file moved or copied.

**1.7 Paste files into a folder (lower value)**
- Trigger: paste in the folders tree (`folderTreePasteClippy()` 31658) or the omnibox (`omniBoxFolderPasteClippy()` 26988) → `PasteFilesIntoGivenFolder()` 31674, messages 31833 and 31839.
- Buttons: "Undo" → `doUndoFileActsChronos()`.
- Caveat: started from the folders tree window, which keeps focus afterwards (31671). Check that no panel is open.

Not checked: the structured copy/move (`copyMoveStructuredFolders()` 3199, messages 3382 and 3388), started from a panel by `BTNuiProceedStructuredOperation()` 59597; whether that panel closes first is open.

### 2. Undo and reopen after the default Apply

Enter, the panel's Apply button, the menu «Appl&y tool» (65629, 68511) and the toolbar call `applyIMGeditFunction()` 6075. `closeEditPanelOnApply` starts at 1 (286), so each apply function closes its panel, then edits, and nothing follows. Only the keep-panel route, Shift+Enter (`applyIMGeditKeepWin()` 6064), shows "Undo action | Reopen panel" today. The default route is the one most people use.

**2.1 Panels applied through `applyIMGeditFunction()`**
- Place: after the dispatch in `applyIMGeditFunction()` (6110).
- Buttons: "Undo action" → `ImgUndoAction()` 16896; "Reopen panel" → `openPreviousPanel()` 27304. The same string as 6070, so the keep-panel route only refreshes it.
- Gate:
  - the panel open at entry was one of 23, 24, 25, 30, 31, 32, 55, 65, 68, 74, 81, 89 (capture `AnyWindowOpen` first);
  - it is closed now (`AnyWindowOpen=0`);
  - the edit happened: the `UserMemBMP` handle changed (`wrapRecordUndoLevelNow()` swaps it, 16651-16653), or for huge images `viewportQPVimage.actions` grew. The undo counters do not show it: they stay put at the undo limit or with `minimizeMemUsage=1` (16740-16754).
- The final `Else BtnCloseWindow()` (6109-6110) closes other panels (10, 64, 66 …) without editing: no bar there.
- "Reopen panel" opens the right panel: `CloseWindow()` keeps `prevOpenedWindow` (96098) and `createSettingsGUI()` stores the panel and its opener (27612-27614). Panel openers do not hide an active selection.
- Image view only.

**2.2 Panels that always close, then edit (no message today)**
- `BtnBlurSelectedArea()` 55175, `BtnPixelizeSelectedArea()` 55185, `BtnZoomBlurSelectedArea()` 55203, `BTNdoSharpenFX()` 59524, `BtnIDedgesNow()` 52371, `BtnAddNoiseNow()` 52380, `BTNdoAutoImgColors()` 59365, `BTNadjustCanvasAction()` 90565, `BTNimgResizeEditor()` 49243, `BTNautoCropVP()` 97363.
- Buttons: the same "Undo action | Reopen panel", after the core call. These are tweak-and-retry tools (blur radius, size, canvas).
- Gate: the edit happened. The core functions can stop after a message box that offers its own «Reopen panel» (23745, 23788, 23795).
- The thumbnails batch branch of `BTNdoAutoImgColors()` returns first (59370-59379).
- One shared helper for patterns 2.1 and 2.2 is the obvious shape; its name and form are your call.

### 3. Undo and next step after edits made without a panel

**3.1 Crop to selection**
- Trigger: Shift+Enter outside panels (1801-1802), «&Crop image to selection» (65468, 65812), the toolbar (102415) → `CropImageInViewPortToSelection()` 24943. The message comes from `dummyInfoImgCropVP()` 25011, started by a timer at 25004.
- Place: after the message in `dummyInfoImgCropVP()`.
- Buttons: "Undo crop" → `ImgUndoAction()`; "Save image" → `PanelSaveImg()` 44072 (or "Copy" → `CopyImage2clip()` 3669).
- Gate: `!AnyWindowOpen && tempBtnVisible="null"`.
  - `BTNsaveAutoCroppedFile()` crops, then opens the save panel 5 ms later (97060-97062). Nothing removes the bar when a panel opens, and `ImgUndoAction()` has no panel check.
  - The `tempBtnVisible` test lets the bar of `BTNautoCropVP()` (2.2) win.
- Huge images take `HugeImagesCropResizeRotate()` (24970), which shows no message. They need their own call at that spot, gated on `viewportQPVimage.actions`. Not inside `HugeImagesCropResizeRotate()`, which also serves «new image» (20952).
- The crop clears the selection (25000), so selection buttons make no sense here.

**3.2 Rotate by ±90°**
- Trigger: Ctrl+Shift+R and the menus «Rotate image by 90°» / «Rotate image by -90°» (65465-65466) → `RotateEditedImage()` 24911; success at 24930-24933 is only a beep.
- Buttons: "Undo" → `ImgUndoAction()`; "Rotate again" → `MenuRotateEditImagePlus()` 24903, or `MenuRotateEditImageMinus()` 24907 after −90°.
- Caveats: huge images take `HugeImagesCropResizeRotate()` (24918-24921): gate on `viewportQPVimage.actions`. A memory warning can skip the undo level (20543-20547), and then "Undo" finds nothing. Image view only (24915).

**3.3 Cut**
- Trigger: Ctrl+X and «C&ut selected area» (65353, 65800, 68829, 68946) → `CutSelectedArea()` 17399.
- Buttons: "Undo" → `ImgUndoAction()`; "Paste in place" → `PanelPasteInPlace()` 47075. Cut, then paste in place, moves a region; the selection stays active, which the paste panel needs (47127).
- Gate: the copy worked (17403-17404) and the image is not huge (`wrapRecordUndoLevelNow()` returns at 16627).
- See bug 3 at the end: at this commit, Cut can erase outside the selection.

**3.4 Freeform selection finished**
- Trigger: "Done" on the drawing bar (49047), Enter while drawing (1811-1812), «&Done / apply changes» (6752) and «&Apply / done» (65496) → `stopDrawingShape()` 47946; the success branch is 48018-48026 when `drawingVectorLiveMode=3` (set at 48487).
- Place: after 48032-48036; the drawing bar is removed at 48002.
- Buttons: "Crop to selection" → `CropImageInViewPortToSelection()` 24943; "Selection options" → `invokeSelectionAreaMenu()` 70747.
- Gate: at least 3 points (48003) and mode 3. Modes 1 and 2 reopen a panel (48024-48025).
- If `postVectorWinOpen` held a panel number (read it before 48028 resets it), offer "Reopen panel" → `openPreviousPanel()` instead of the crop.
- Why: the drawing bar disappears at "Done" and leaves nothing behind.

**3.5 Flip, invert, resize to selection (low value)**
- Trigger: Shift+H / Shift+V (1465-1494), Shift+I (1428-1435) and their menus → `FlipSelectedAreaH()` 19676, `FlipSelectedAreaV()` 19683, `InvertSelectedArea()` 19665; Alt+R (1397-1400) → `ResizeIMGviewportSelection()` 22433, message in `dummyInfoImgResizeVP()` 22489.
- Buttons: "Undo action" → `ImgUndoAction()`.
- Low value: flips and invert undo themselves with the same key. Put the call in these small functions, never in `EraseOrInvertOrGraySelectedArea()` 19694, which panel applies and Cut share. With nothing selected they select the whole image first (19698-19699).

### 4. Save an image that exists only in memory

- Trigger: Ctrl+V in the image view (1069-1072), «P&aste clipboard» (65806, 68963), «&Paste image» (68832), and «Acquire image (WIA)» (`AcquireWIAimage()` 99705, which calls the paste at 99767) → `PasteClipboardIMG()` 25199. It ends with no message (25297-25301).
- A new paste is a «Q:\Temporary Memory Object\…» entry (25265) until it is saved.
- Place: the end of `PasteClipboardIMG()`.
- Buttons:
  - "Save as…" → `PanelSaveImg()` 44072, always. When the paste replaced a listed image (`isImgOpen=1`), a plain save writes over that file (45825), so the label says "Save as…".
  - "Undo" → `ImgUndoAction()` when pasted into an image being edited (`isImgOpen=2`, undo level at 25288-25289). Not for huge images (25252: no undo level).
  - "Scan again" → `AcquireWIAimage()` after a scan.
- Gate: none of the early exits happened: a panel open (25203), files in the clipboard (25214), the unsaved-image question (25240). In thumbnails mode Ctrl+V pastes files instead (1072).

### 5. Go to the result

After a save or a batch job, the next step is often to look at the output. Touch users have no quick way there.

All spots need one wrapper, for example `openLastResultPath(givenPath:="")`:
- called with a path, it keeps the path in a `Static` and returns;
- called with no argument (by the bar), it opens the folder in Explorer, with the file selected when the path is a file, and reports a path that is gone.

`OpenThisFileFolder()` 2793 cannot serve: it opens the folder of the current list entry, and after a Save As to a new path that entry is still the original file (the entry changes only when `imgPath=file2save`, 58628-58629).

**5.1 Save image**
- Trigger: Ctrl+S → `PanelSaveImg()` 44072 → `BTNsaveImgPanel()` 45802 → `SaveClipboardImage()` 58381, success message 58616. Huge images share this branch (58555).
- Place: after 58633, inside the success branch.
- Buttons: "Open folder" → the wrapper.
- Image view only: in thumbnails mode `PanelSaveImg()` saves the files list (44074-44077). All message boxes of the function come earlier (58428-58515); 58607 is the failure branch.

**5.2 Batch jobs with a destination folder**
- Spots (the finish message):
  - `batchConvert2format()` 60330, finish 60537 (single-core; the multi-core route returns at 60366-60367);
  - `batchAdvIMGresizer()` 90816, finish 90972;
  - batch rotate/flip/scale, finish 98255; batch colour adjustments, finish 98364; batch auto-crop, finish 97285;
  - the shared multi-core tail in `WorkLoadMultiCoreHandler()`, 37583, inside `Else If (fatalError!=1)`; skip `job.mode="batch-jpegll"`, which writes in place;
  - single-file versions: convert 61052, resize 91266, rotate/flip/scale 98125.
- Gate: `ResizeUseDestDir=1`. Otherwise files are written in place or next to each original (60421, 90890, 98213).
- Buttons: "Open folder" → the wrapper with `ResizeDestFolder`; optionally "Reopen panel" → `openPreviousPanel()` 27304, which works because the batch closed the panel (for example 60346) and nothing in between changes `prevOpenedWindow`.
- Not checked: the batch auto colours (97290, finish 97358) and where it writes.

**5.3 Extract frames**
- Trigger: `BTNperformExtractFrames()` 43560. One image: message 43600 (43592 when partly done). Several files: `batchExtractFramesFromImages()`, message 61170.
- The output always goes to `ResizeDestFolder` (61204, 61506, 61628, 61706, 61794), and the message at 43600 does not say where.
- Buttons: "Open folder" → the wrapper. The panel is closed at 43581; no message box follows.

**5.4 Joined file, thumbnails sheet or PDF text**
- Spots, each on its success branch: `CombineImgsIntoPDF()` 43290 (43461), multi-page TIFF (62128), `combineImagesFimMultiPage()` 62135 (GIF/APNG/WebP/MNG/JXL, 62334), the thumbnails sheet (43853), PDF text extraction (56029, a .txt file).
- Buttons: "Open file" → a sibling of the wrapper that runs the file; "Open folder" → the wrapper.
- Record the path inside those functions: `CombineImgsIntoPDF()` returns nothing on success, and `convertFocusedFileToPDF()` 43272 calls it directly.

### 6. Messages that tell the user to press a key

A touch user cannot press the key a message names. A button does the same thing.

**6.1 Captions shown, but no caption file**
- Trigger: N or «&Show image captions» (66881) → `ToggleImgCaptions()` 70703, message 70722 «Press Shift+N to create/edit one».
- Buttons: "Create caption" → `PanelEditImgCaption()` 46199; "Caption options" → `InvokeMenuBarCaptions()` 66440.
- Gate: the not-found branch only. With a caption, a tap on the caption box already opens the editor (10094-10099). Works in thumbnails mode too.

**6.2 Action blocked on frames or pages**
- Trigger: delete, rename, copy/move … while the list shows the frames of one file → `warnFramesActionPrevented()` 39730, message 39733 «You can deactivate this mode with Ctrl+Space».
- Buttons: "Exit frames mode" → `MenuRemFilesListFilter()` 4141 (the frames view is a list filter).

**6.3 No viewport colour adjustments to apply**
- Trigger: Ctrl+Shift+U, «Appl&y viewport color effects» (65432) → `ApplyVPcolorAdjustSelectedArea()` 17411, message 17454.
- Buttons: "Cycle colour modes" → `ToggleImgFX()` 11161; "Viewport colours" → `PanelColorsAdjusterVPwindow()` 89399.
- Image view only. See bug 1: at this commit the message names the wrong key.

**6.4 Paint or fill area set to inside or outside, with no selection**
- Trigger: Shift+K (1845-1847) → `toggleBrushDrawInOutModes()` 76779, messages 76809 and 76826, which say «Press E to create or display it» (76804, 76821).
- Buttons: "Show selection" → `ToggleEditImgSelection()` 82267.
- Gate: `editingSelectionNow!=1`. `ToggleEditImgSelection()` toggles; a "show only" button needs a wrapper that calls `ToggleEditImgSelection("show-edit")`.

**6.5 Brush symmetry cycle**
- Trigger: Y with a live brush (1229-1232), «&Cycle symmetry modes» (68633) → `toggleBrushSymmetryModes()` 76279, message 76361 with «Press Shift + Y to define the symmetry coordinates» (76358).
- Buttons: "Set symmetry centre" → `BtnSetBrushSymmetryCoords()` 5768.
- Gate: symmetry not NONE, brush panel only (`isPaintSymmetryModeAllowed()`). Lower value: the brush panel has its own «S&et center» button (44422).

**6.6 Colour change refused for the cloner brush**
- Trigger: any brush-colour action while the cloner brush is active → `preventColorChange()` 76917, message 76924.
- Buttons: "Define clone source" → `BtnSetClonerBrushSource()` 44702.
- See bug 2: at this commit the message names the wrong key.

The colour display mode hint (`ToggleImgFX()`, 11222) belongs here too; its bar is 8.1.

### 7. Toolbar right-click actions

Press-and-hold is turned off on every toolbar button (`tlbrAddNewIcon()`, 101030) and on the toolbar itself (102978). So a touch user cannot reach the right-click actions that the button tooltips list (`tlbrDecideTooltips()` 103962-104012). The bar can offer the right-click action after the left-click one.

**7.1 Histogram cycle**
- Trigger: G (1381-1382), Shift+G, the toolbar's histogram button (102704) → `ToggleImgHistogram()` 71559, messages 71573 and 71575 (not tappable).
- Buttons: "Histogram options" → `invokeHistoMenu()` 71537, the button's right-click action (102204).
- Gate: `showHistogram>1`; image view only.
- Other callers would get the bar too: a click on the histogram box (10090, inside the click handler), the `MenuSetVPhisto*` items (69559-69587), `ToggleHistoInfoBoxu()` (70675). Add the call on the key and toolbar route only; `ToggleImgHistogram(1)` cannot tell those callers apart.

**7.2 Fit-mode cycle**
- Trigger: T (1906), the toolbar's fit button (102680) → `ToggleImageSizingMode()` 10640, message 10702.
- Buttons: "Fit options" → `InvokeMenuImgSizeVP()` 71543, the button's right-click action (102190).
- Gate: called with `modus=0`. It is also called from the navigator (76041 → 76056) and by double-click (`ToggleImgSizeViewModes()` 85251 → 85256). Skip thumbnails mode (10645-10649) and drawing (10716-10724).

**7.3 Viewport grid turned on**
- Trigger: «Show viewport &grid» (65522, 67315), the toolbar's grid button → `tlbrViewPortGridu()` 101632 → `toggleViewPortGridu()` 50553, message 50559.
- Buttons: "Grid options" → `PanelConfigVPgrid()` 50590, the button's right-click action (102186).
- Gate: only when turned on; `AnyWindowOpen!=63`; not while drawing (G reaches this function only in the vector editor). From the toolbar, place it after the wait for the button release (50566-50575).

**7.4 Info box turned on**
- Trigger: I (1237-1241), the toolbar's info button (102567) → `ToggleInfoBoxu()` 70686 (no message).
- Buttons: "File information" → `PanelImageInfos()` 30031, the button's right-click action (102152).
- Gate: only when the box was turned on. Low to medium value.

**7.5 Thumbnail view cycle and navigator (low value)**
- Trigger: L in thumbnails mode → `toggleListViewModeThumbs()` 70560, message 70584; Z → `ToggleImgNavBox()` 71493.
- Buttons: "View options" → `invokeMenuNavBoxImgSizeVP()` 71549.
- Both messages can already be tapped to toggle back.

### 8. Make a view change permanent

**8.1 Colour display mode**
- Trigger: F / Shift+F (1514-1521), «C&ycle colors display modes» (67322, 68193), the `MenuSetColorMode*` items (69513-69556) → `ToggleImgFX()` 11161, message 11224 (not tappable).
- Buttons: "Apply to image" → `ApplyVPcolorAdjustSelectedArea()` 17411, otherwise reachable only with Ctrl+Shift+U; "Adjust colours" → `PanelColorsAdjusterVPwindow()` 89399. Alternative second button: "Display unaltered image" → `HardResetImageView()` 11355.
- Gate:
  - `imgFxMode>1`. With «None», the apply function falls back to the previous mode kept in its `Static` (17448-17451).
  - Image view only. The apply returns in thumbnails mode (17413-17418), and there Shift+U runs `filesListApplyColors()` 91013, which changes files.
  - Not for huge images (no huge-image route; `wrapRecordUndoLevelNow()` returns at 16627).
  - No panel open (the panel 10 branch, 11236); not while drawing (F works then, 1516).
- With part of the image selected, the apply works inside the selection only: label it "Apply to selection" then. Keep the labels fixed while cycling, so the bar is only refreshed.

**8.2 Simulated colour depth**
- Trigger: Q / Shift+Q (1522-1532), «C&ycle simulate color depths» (67321, 68151), the depth items (69624-69666) → `ToggleImgColorDepth()` 11111, message 11133.
- Buttons: "Apply to image" → a wrapper around `mergeViewPortRotationImgEditing()` 77501, which writes the colour depth and the rotation into the pixels but does not repaint. The wrapper returns in thumbnails mode, while an image loads or with a panel open, and repaints after a merge. "Display unaltered image" → `HardResetImageView()` 11355.
- Caveats: the depth reload runs from a −50 ms timer (11137), so the wrapper must wait while `imageLoading=1`. No Apply in thumbnails mode (11113). No effect on huge images (77502). Every edit already merges depth and rotation first (24913, 24945); the button only makes that a choice.

### 9. Controls for a mode just entered

**9.1 Slideshow started**
- Trigger: Space, the toolbar's play button, «&Start slideshow» → `MenuGoPlaySlidesNow()` 101245 → (timer) `ToggleSlideShowu()` 10882, message 10945 inside `If (silentModus!=1)`.
- Buttons: "Slower" → `DecreaseSlideSpeed()` 3162; "Faster" → `IncreaseSlideSpeed()` 3139. Alternative: "Slideshow options" → `InvokeMenuBarSlides()` 66447.
- Why: the toolbar hides during a slideshow (10909) and a tap on the viewport stops it (module-interface.ahk 1331). Without a keyboard there is no way to change the speed. A tap on the bar does not stop the show.
- Caveats: this route runs from a one-shot timer, not a message handler. The unsaved-image question comes earlier (10889). Menus refuse to open while an image loads (`showThisMenu()` 69368), so a menu button can do nothing during a slide load.

**9.2 Slideshow stopped**
- Trigger: a click, the wheel or a key during a slideshow; Space (1732) → `stopSlideshow()` 10801, message 10818.
- Buttons: "Resume" → `MenuGoPlaySlidesNow()` 101245; "Slideshow options" → `InvokeMenuBarSlides()` 66447.
- Why: an accidental tap ends the slideshow.
- Caveats: most stops come from mouse and key handlers (module-interface.ahk 1114, 1331, 1389, 1438, 1527, 2472), so the call needs a one-shot timer. A resume within 500 ms of the stop is ignored (10901). It may feel noisy after a deliberate Escape.

**9.3 Thumbnails: select all, invert the selection**
- Trigger: Ctrl+A (1583), «Select all» (69734) → `selectAllFiles()` 82249 (no message); Shift+I (1433) or the toolbar's invert button (102659) → `invertFilesSelection()` 38913, message 38935.
- Buttons: "File actions" → `invokeFileOptionsMenu()` 70741 (with a selection it builds the multi-file menu, 67764-67768); "Select none" → `dropFilesSelection()` 38942.
- Gate: `selectAllFiles()` clears the selection when everything is already selected (82254): show the bar only when it selected. Not in frame/page lists. Thumbnails mode only.

**9.4 Touch mode turned on**
- Trigger: «&Touch screen mode (viewport)» (70080) → `ToggleTouchMode()` 71935, message 71951 «See the Help menu for more details».
- Buttons: "Show touch areas" → `MenuDrawViewportHelpMap()` 87801, which draws the touch areas (87839), the same as Help → «&Viewport help map» (66702).
- The checkbox in the settings panel (57098) returns earlier, so it gets no bar. No "force" needed: touch mode has just been switched on.

**9.5 Menu bar and toolbar both hidden**
- Trigger: F10 / Shift+F10 (1053-1058), the menu flyout's buttons, the buttons of the collapsed panel (26194, 26195), the toolbar's close button (102233-102234) → `ToggleMenuBaru()` 71373 or `toggleAppToolbar()` 71891 (no message).
- Buttons: "Interface options" → `OpenUImenu()` 57886 with "force"; its menu has «Show &menu bar» (70136) and «Show &toolbar» (70147). Optional "Show menu bar" → `ToggleMenuBaru()` 71373.
- Why: it extends today's full-screen and title-bar bars to the state where all the interface is hidden.
- Caveats:
  - The flyout runs these two inside `uiWM_LBUTTONUP` (module-interface.ahk 1363, 1365): use a one-shot timer.
  - Hiding the menu bar resizes the window, which removes the bar: the timer must fire after that, 250-350 ms like `dummyFullScreenButtons()` (armed at 70468) and `dummyToggleTitleBarActionBtns()` (armed at 71362).
  - Leaving full screen calls `toggleAppToolbar()` itself (70435; 70464 at −300 ms): arm the bar only on the user's routes.
  - Both functions are g-labels: do not add parameters.

**9.6 Kept bar: picking a point with a click**
- Trigger: `BtnSetClonerBrushSource()` 44702 (S; message 44714), `BtnSetBrushSymmetryCoords()` 5768 (message 5777), `BtnSetTextureSource()` 44749 (message 44759).
- Buttons: "Cancel" → `StopCaptureClickStuff()` 68895, kept until the pick ends.
- Why: while picking, the toolbar is see-through and lets clicks pass (103918), the menu bar is disabled and the panel collapsed. The ways out are keys, a right-click (68914) or the collapsed panel's expand button (26192), which cancels without a word.
- Remove it in `endCaptureCloneBrush()` 2604, only when `mustCaptureCloneBrush=1`: every way out passes through it (a successful pick 77188, 5818, 10000; `StopCaptureClickStuff()`; `CloseWindow()` 96096; `createSettingsGUI()` 27551), and many brush toggles call it too.

### 10. Undo or step through a list change

**10.1 Filter applied**
- Trigger: every user filter ends in `coreSetFilesFilteru()` 32895:
  - the filters panel and Ctrl+F (`BtnApplyFilesFilter()` 32668 → 32709);
  - Shift+E, filter to the image's folder (2680, message 2693);
  - Ctrl+Tab, filter to the selection (`filterToFilesSelection()` 38905);
  - F3 in the folder panels (94908), keywords (91861), statistics rows (27928, 27970), «Preview all pages» (94931).
- Buttons: "Remove filter" → `MenuRemFilesListFilter()` 4141 (Ctrl+Space).
- Place: after 32960. Gate: `StrLen(filesFilter)>1 && noStringProcessing!=1 && maxFilesIndex>0`.
  - The «No files matched» message box (32940) clears the filter first, so the gate fails there.
  - `noStringProcessing=1` comes only from a sort that re-applies the filter (36609).
  - Removing the filter goes through `coreSetFilesFilteru("")` (4156) and fails the gate.
- Also `retrieveAlreadySeenImageFromCurrentList()`: it sets a filter (35407) but returns before the tail (32917-32921); place a call at 35419.
- Caveats: mostly thumbnails mode. `MenuRemFilesListFilter()` has no check of its own (4141-4145), while the key and the menu test `StrLen(filesFilter)>1` (1924, 69116); a second tap on the bar re-runs the removal on an unfiltered list. Add the check.

**10.2 Files list sorted**
- Trigger: Ctrl+1 … Ctrl+6 (`ActSortName()` 36626 … `ActSortCreated()` 36682), Ctrl+7/8 (36692, 36706), duplicate groups (36653) → `SortFilesList()` 36728 (end 37072-37081) or `dbSortingCached()` 36497 (end 36616-36620). Both end with a beep and no text.
- Buttons: "Reverse order" → `ReverseListNow()` 87375 (Ctrl+0); "Sort options" → `InvokeMenuBarSort()` 66454.
- Place: the success ends of those two functions; the `ActSort*` wrappers cannot tell when a sort gave up.
- Open question: `SortFilesList()` also runs for the automatic sort after a list rebuild (85506). Leaving that out needs a flag parameter.
- `ReverseListNow()` returns with fewer than 3 files and may ask to save first.

**10.3 Index search hit**
- Trigger: F3 / Shift+F3 (2069-2076), «S&earch next» (66273), the search panel (`PanelSearchIndex()` 46077, Ctrl+F3; its button at 46183) → `searchNextIndex()` 39175. A hit jumps with no message (39261-39263).
- Buttons: "Previous match" → `MenuSearchPrevIndex()` 65276; "Next match" → `MenuSearchNextIndex()` 65272. Alternative: "Next match | Go back" (`jumpPreviousImage()` 58177; not in thumbnails mode, see 11).
- No match (message 39256): "Search again" → `PanelSearchIndex()` 46077. The function empties `userSearchString` there (39257).
- Repeated taps keep the same button list, so they only extend the bar. Works in thumbnails mode.

**10.4 Duplicates found**
- Trigger: `PanelFindDupes()` 88204 → its search button (closes the panel, 88675) → `retrieveDupesByProperties()` 86085, message 86485.
- Buttons: "Auto-select duplicates" → `PanelAutoSelectDupes()` 45849; "Remove filter" → `MenuRemFilesListFilter()` 4141 (the duplicates list is a filter, 86456).
- Gate: `!SortCriterion`. Sorting by duplicate group re-runs this function (36531, 36656); its failure path uses the same test (86477-86478).
- The same bar fits the Hamming-threshold change (`BtnChangeHamDistThreshold()`, success 45457-45460).

**10.5 Entries removed from a saved list**
- Trigger: Alt+Delete → `remCurrentEntry()` 33340, message 33376; removal of several entries (33313-33315); `cleanDeadFilesList()` 34826 (34947-34949); removing seen images (35172).
- Buttons: "Save list" → `BTNsaveCurrentSlideshow()` 42948.
- Gate: the menu's own condition (66339-66340, 69128-69132): `SLDtypeLoaded=2 && currentFilesListModified=1 && CurrentSLD && maxFilesIndex>1`. An .SLDB database removes the row at once (33358), and a folder list has no file to save.
- A removed entry cannot be brought back (33348 keeps it only in a local variable).

**10.6 Favourite toggled (low value)**
- Trigger: B (1452), the toolbar (102578), the menus (67857, 69938) → `ToggleImgFavourites()` 38402, messages 38435, 38465, 38495, 38587.
- Buttons: "Favourites" → `InvokeFavesMenu()` 69764. When the limit is reached (38444): "Manage favourites" → `retrieveFavesAsList()` 38624.
- Not "Undo": the toggle reads the current entry (38404, 38415), so after the viewer moves on it would toggle another image.
- Gate: no path given; internal callers pass one (39859, 42729, 70325). B is pressed often while browsing.

### 11. Go back after a jump

`jumpPreviousImage()` 58177 (Ctrl+Backspace, «&Previously displayed image») shows the image seen before the current one.
- It does nothing while the current image has unsaved edits (58179-58181).
- It goes by the stored list index, not the path (58186).
- The stored index moves on every image load, reloads of the same image included (74989); a frame change or colour-depth reload in between makes "back" point at the same image.
- In thumbnails mode it moves only when a full image loads (74989-74990).

**11.1 Skip to index**
- Trigger: J (1770-1775), «&Skip to index» (66547) → `PanelJump2index()` 58190, jump at 58266-58267.
- Buttons: "Go back" → `jumpPreviousImage()` 58177.
- The list=2 and list=4 branches return earlier: no bar there.

**11.2 First or last image (low value)**
- Trigger: Home / End (2255-2289), «&First» / «&Last» (66495, 66506) → `FirstPicture()` 4272, `LastPicture()` 4287.
- Buttons: "Go back" → `jumpPreviousImage()`. Image view only: thumbnails mode uses its own navigation (2267-2270).

The search hit (10.3) can use "Go back" as well.

### 12. Recover from an error

**12.1 File missing**
- Trigger: `informUserFileMissing()` 32239, messages 32246 and 32252. Called from `DelayiedImageDisplay()` 25638, `ReloadThisPicture()` 4259 and 4268, `RefreshImageFileAction()` 63008, `RefreshImageFile()` 63023, `OpenWithDefaultApp()` 2991, `OpenFileProperties()` 3004, `uiPopulateImgInfos()` 31883.
- Buttons: "Remove entry" → wrapper needed; "Clean dead entries" → `cleanDeadFilesList()` 34826, which removes missing files (34837).
- Gate: `autoRemDeadEntry!=1` (otherwise the entry is already gone, 32258-32259) and no slideshow running.
- The wrapper: `singleInListEntriesRemover()` 33201 removes the *current* entry, and the bar survives a change of image. Keep the path in a `Static` and act only while the current entry still matches it, or a late tap removes a healthy entry.

**12.2 File present but not readable**
- Trigger: `coreShowTheImage()`, 73469-73475.
- Buttons: "Remove entry" (the wrapper of 12.1); "Open with default app" → `OpenWithDefaultApp()` 2987, which may hand the file back to QPV when QPV is the default viewer.

**12.3 Save failed**
- Trigger: the failure branch of `SaveClipboardImage()` (tooltip 58605, error box 58607).
- Place: after the error box.
- Buttons: "Save as…" → `PanelSaveImg()` 44072, which the save closed at 58503-58504.
- Image view only.

**12.4 No image loaded**
- Trigger: `throwErrorNoImageLoaded()` 3657, message 3664. It is the shared check of Ctrl+C (3673), Save (44080, 58384), Extract frames (43002), `ResetImageView()` 11349, the alpha-mask actions (3868, 4025), `RefreshImageFileAction()` 62985, and every image-editing panel through `createSettingsGUI()` 27510.
- Buttons: "Open image" → `OpenDialogFiles()` 63059 (Ctrl+O); "New image" → `PanelNewImage()` 52461 (Ctrl+N).
- Gate: `noMSG=0` and nothing open (no `CurrentSLD`, or `maxFilesIndex<1`). With a list open this warning means the image failed to load. `OpenDialogFiles()` returns while a panel is open or an image loads (63061).

**12.5 Undo refused because undo levels are off (low value)**
- Trigger: `ImgUndoAction()` 16896 (16921-16922), `undoRedoHugeImagesAct()` 20605 (20607).
- Buttons: "Record undo levels" → `TogglePreventUndos()` 71871.
- Gate: `preventUndoLevels=1`. It does not bring back the lost undo.

### Smaller ideas, not examined in depth

- After «Select dead files» (45952): "Remove entries" → `InListMultiEntriesRemover()` 33205.
- After selecting all search results (45884): "Filter to selection" → `filterToFilesSelection()` 38905.
- After `CopyImage2clip()` 3669 with a selection: "Paste in place" → `PanelPasteInPlace()` 47075.
- After an undo (16932): "Redo" → `ImgRedoAction()` 17133; after a redo (17161): "Undo".
- Select all in the image view (`selectEntireImage()` 82358, Ctrl+A): "Selection options" → `invokeSelectionAreaMenu()` 70747. It needs a wrapper or a new argument value: internal callers (17430, 22481, 53342) would show the bar in the middle of an edit. `selectEntireImage()` deselects when everything is selected (82388-82392).

## Rules for a new call

1. Make the call the last statement of its function: `CreateTempGuiButton()` leaves `Critical` on in the caller's thread.
2. Never while a vector shape is being drawn (`drawingShapeNow=1`). The new bar replaces the drawing bar, and `showQuickActionButtonsDrawingShape()` 49032 does not rebuild it while the menu bar or toolbar is visible (49033). F and G still reach `ToggleImgFX()` and `toggleViewPortGridu()` while drawing (1516-1517, 1379-1380).
3. Never inside a window-message handler: the `WM_*` and `uiWM_*` functions and what they call. `WinClickAction()` runs inside `uiWM_LBUTTONDOWN` (module-interface.ahk 1333); the menu flyout calls `toggleAppToolbar()` and `ToggleMenuBaru()` inside `uiWM_LBUTTONUP` (1363, 1365). Use a one-shot timer, as `dummyFullScreenButtons()` and `dummyToggleTitleBarActionBtns()` do, or call it on the key and menu route only, as `ToggleEditImgSelection()` does with `modus="key"` (82341).
4. Create the bar after any message box: a non-panel `msgBoxWrapper()` removes it (32771). Resizing the main window removes it too (85188), so a toggle that resizes the window needs a later timer.
5. The bar survives a change of image and an opened panel. A button that acts on "the current image" needs the path kept in a `Static` and a check that the current entry still matches. `ImgUndoAction()` undoes a file action when no edited image is in memory or in thumbnails mode (16913-16916).
6. After a toggle whose message can be tapped (message tap), offer a follow-up, not "toggle back". Messages shown with type 2 (`ToggleImgFX()`, `ToggleImgHistogram()`, `ToggleImgColorDepth()`) cannot be tapped.
7. Keep the labels fixed for actions that cycle or repeat: the same button list only extends the timer, a different one rebuilds the bar.
8. Check the target's own guards: `doUndoFileActsChronos()` returns while a panel is open (92358-92359); `jumpPreviousImage()` with unsaved edits (58179-58181); every menu button goes through `showThisMenu()` 69366, which returns while an image loads (69368).
9. A menu target called with no argument (`InvokeMenuBar*()`, `invoke*Menu()`) opens the menu at the pointer, which after a tap is on the bar.
10. In thumbnails mode the bar sits over the bottom-left of the grid, and most image targets do nothing there. Decide per spot.

## Considered and left out

| Candidate | Why not |
|---|---|
| Animated GIF/WebP playback | No single toggle with a result message; any click stops it; its speed control fires on every step. |
| Screen-saver mode (`toggleScreenSaverMode()` 71748) | Welcome screen only, just a beep; a bar would sit on top of it. |
| Colour picker (`StartPickingColor()` 47726) | Runs a blocking loop and stops when the active window changes (47762). |
| Alpha-mask painting (`toggleAlphaPaintingMode()` 76414) | Exits exist on the toolbar (102236-102238), the panel and «E&xit tool» (66419); a message box sits mid-flow (76472). |
| Brush and flood-fill tool on/off | The message can be tapped; the panel's list covers Shift+K. |
| Mirroring (`VPflipImgV()` 12340, `VPflipImgH()` 12385) | Tappable message; `HardResetImageView()` resets far more than the flip; nothing makes a mirror permanent. |
| Alignment, free panning, zoom lock, slideshow modes, thumbnail aspect ratio, private mode, preference toggles | Tappable messages; mostly flipped from a menu already open. |
| Gradient and spiral centre repositioning (68345, 68354, 68367) | The mode outlives a timed bar and has no single exit function for a kept one. |
| Collapse panel (F11) | The collapsed panel already shows expand and cancel buttons (26192-26197). |
| Thumbnails mode on/off | No message. |
| "Toolbar options" after showing the toolbar | Reachable by touch: the settings button opens `OpenUImenu()` (101998), and a tap on the drag handle works (104722). |
| Viewport rotation (`changeImgRotationInVP()` 12086) | Moves in 5° or 1° steps; the permanent route is the wrapper of 8.2, better as a menu item. |
| Lossless JPEG rotation | Only through `PanelJpegPerformOperation()` (Shift+J, 67730), a panel with an operation list that resets rotation and flips when it opens (89064). |
| Brightness, contrast, saturation, gamma, GIF delay, frame and wheel-zoom steps (11426, 11824, 11896, 11927, 11999, 11675) | Many small steps; the reset already has a bar (11481). |
| Random, next and previous image | Too frequent; Backspace already goes back in random order. |
| Sibling and parent folder navigation (`FileExploreSiblingsNav()` 62792) | `jumpPreviousImage()` keeps an index into the old list; there is no "previous folder" function. |
| Deselect (Ctrl+D → `resetImgSelection()` 82747) | Clears the coordinates (82754-82760); nothing can restore them. |
| Undo a selection change (`ImgSelUndoAct()` 16967) | Does nothing unless the image is being edited (16969-16972). |
| Shift+click selection, flood-fill clicks (77514), brush strokes (77666) | Inside click and drag handlers. |
| Huge-image colour depth (`HugeImagesConvertClrDepth()` 20961) | Discards its undo level (21052): nothing to undo. |
| Polar transforms (20280, 20284); the simplex crop (13911) | Rare; an internal step. |
| «Review errors» after a batch | `PanelJournalWindow()` cannot open its Errors tab (its tab argument opens tab 3, 56513-56514), and the batch loops rarely journal per-file failures. |
| Set wallpaper (2889) | The previous wallpaper is not recorded; removing it needs the panel's controls (44037-44040). |
| Print (53016); OCR (56033) | No follow-up action; OCR results stay in its panel. |
| Copy to the clipboard (3669, 91296) | No follow-up beyond "Paste in place" (smaller ideas). |
| Fingerprint collection (35969); index update | The collection end is shared by sorts and filters, and its finish message is commented out (36441); the index update shows no finish message. |
| Unsaved image or list blocks an action (63180, 63198) | Already a Save / Discard / Cancel box. |
| Empty list (34973) | Already a box with three choices. |
| Hamming threshold finds nothing (45454) | The panel reopens (45455). |
| A folder opened | Too frequent. |
| «Insufficient files selected to join» (43130) | `selectAllFiles()` is a toggle, and the panel must be reopened anyway. |
| JPEG crop without a selection (89161) | `ToggleEditImgSelection()` does nothing in thumbnails mode (82270). |
| Unsupported format when reopening the last image (63307) | `OpenWithDefaultApp()` acts on the current entry, not on that file. |

## Bugs found during the survey

Each is fixed by its own commit after this report.

**1. Wrong key in two hints for the viewport colours panel**
- `ToggleImgFX()` 11222: «Press U to adjust colors display options».
- `ApplyVPcolorAdjustSelectedArea()` 17454: «…or press U to open color adjustments panel».
- Since v5.7.3, U in the image view opens «Adjust image colors» (`PanelAdjustColorsSimpleWindow()` 89613); the viewport colours panel is Shift+U (`PanelColorsAdjusterVPwindow()` 89399; key map 1495-1509; `resources/help-keyboard-shortcuts.txt`). In the files list, U still opens the viewport colours. Both hints predate v5.7.3.
- Fix: `ToggleImgFX()` names U in the files list and Shift + U in the image view; the message of `ApplyVPcolorAdjustSelectedArea()`, shown in the image view only, names Shift + U.
- Left as is: `AdjustColorsLegacySelectedArea()` 17526 («Press U to open the color adjustments panel»). It came with v5.7.3 and points to the U panel on purpose.

**2. Wrong key in the cloner hint**
- `preventColorChange()` 76924: «To define the source pattern, press D».
- The cloner source key is S (key map 1878-1879; «Define cloner &source» 68630; help file). With a live brush, D sets the brush colours to black and white (1096-1099 → `ResetColorsToBW()` 44677).
- Fix: the message names S.

**3. Cut (Ctrl+X) can erase outside the selection**
- `CutSelectedArea()` 17399 copies the selection, then erases it through `EraseOrInvertOrGraySelectedArea("erase")` 19694. The erase reads three settings of the Erase panel:
  - `EraseAreaInvert`: erase outside the selection (19760);
  - `EraseAreaFader` with `EraseAreaOpacity`: fade instead of erase (19769);
  - `EraseAreaUseAlpha`: erase through the alpha mask (19824).
- `CutSelectedArea()` resets only `EraseAreaFader` (17407). The other two keep, for the rest of the session, what a panel left in them:
  - «Invert selection area» in the Erase panel (51143), the Desaturate panel (50934) and the viewport colours panel in its apply-to-image mode (89488); the Erase and Desaturate panels also load it from the registry when they open (51128, 50900);
  - «Apply alpha mask» in the Erase (51146) and Desaturate (50936) panels.
- Result: after one of those panels was used with «Invert selection area» ticked, Ctrl+X copies the inside of the selection and erases the outside. With «Apply alpha mask» ticked and an alpha mask defined, it erases only through the mask. Traced in the code, not run.
- Only the Erase panel's Apply (`BtnEraseSelectedArea()` 54458) and Cut run this erase.
- Fix: `CutSelectedArea()` turns the three settings off for its erase and restores them afterwards, so the panels keep theirs.

**4. Flood fill reports the brush's area mode**
- `toggleAlphaPaintingMode()` 76414 builds «Fill mode: …» from `BrushToolOutsideSelection` for both tools (76427-76429). The flood-fill tool keeps its own mode in `FloodFillSelectionMode`, with a fourth value, alpha mask; the toolbar and `toggleBrushDrawInOutModes()` read it for flood fill (101853, 76790).
- Fix: with the flood-fill panel open (66), the message reads `FloodFillSelectionMode` and names its four modes as `toggleBrushDrawInOutModes()` does.
