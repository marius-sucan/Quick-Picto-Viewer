#Persistent
#NoTrayIcon
#MaxHotkeysPerInterval, 950
#HotkeyInterval, 50
#MaxThreads, 255
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#IfTimeout, 2000
SetWinDelay, 1
CoordMode, Mouse, Screen
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3, appTitle := "Quick Picto Viewer"
     , RegExFilesPattern := "i)^(.\:\\).*(\.(ico|dib|tif|tiff|emf|wmf|rle|png|bmp|gif|jpg|jpeg|jpe|DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f|jfif))$"
     , PVhwnd, hGDIwin, hGDIthumbsWin, WindowBgrColor, mainCompiledPath, hfdTreeWinGui
     , winGDIcreated := 0, ThumbsWinGDIcreated := 0, MainExe := AhkExported(), omniBoxMode := 0
     , AnyWindowOpen := 0, easySlideStoppage := 0, lastOtherWinClose := 1, wasMenuFlierCreated := 0
     , slideShowRunning := 0, toolTipGuiCreated, editDummy, LbtnDwn := 0, winCtrlsCoords := []
     , mustAbandonCurrentOperations := 0, lastCloseInvoked := -1, allowGIFsPlayEntirely := 0
     , hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
     , hCursN := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
     , hCursMove := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
     , hCursCross := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32515, "Ptr")  ; IDC_Cross
     , hCursFinger := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32649, "Ptr")
     , SlideHowMode := 1, lastWinDrag := 1, TouchScreenMode := 0, allowNextSlide := 1
     , isTitleBarVisible := 0, imageLoading := 0, hPicOnGui1, hotkeysSuspended := 0
     , slideShowDelay := 9000, scriptStartTime := A_TickCount, prevFullIMGload := 1
     , maxFilesIndex := 0, thumbsDisplaying := 0, executingCanceableOperation := 1
     , runningLongOperation := 0, alterFilesIndex := 0, animGIFplaying := 0, prevOpenedFile := 0
     , canCancelImageLoad := 0, hGDIinfosWin, hGDIselectWin, hasAdvancedSlide := 1
     , imgEditPanelOpened := 0, showMainMenuBar := 1, undoLevelsRecorded := 0, UserMemBMP := 0
     , taskBarUI, hSetWinGui, panelWinCollapsed, groppedFiles, tempBtnVisible := "null"
     , userAllowWindowDrag := 0, drawingShapeNow := 0, isAlwaysOnTop, lastMenuBarUpdate := 1
     , mainWinPos := 0, mainWinMaximized := 1, mainWinSize := 0, PrevGuiSizeEvent := 0, FontBolded := 1
     , isWinXP := (A_OSVersion="WIN_XP" || A_OSVersion="WIN_2003" || A_OSVersion="WIN_2000") ? 1 : 0
     , currentFilesListModified := 0, folderTreeWinOpen := 0, hStatusBaru, OSDFontName := "Arial"
     , OSDbgrColor := "001100", OSDtextColor := "FFeeFF", LargeUIfontValue := 14, allowMenuReader := 0
     , lastMenuInvoked := [], hQPVtoolbar := 0, ShowAdvToolbar := 0, whileLoopExec := 0
     , isToolbarActivated := 0, lockToolbar2Win := 1, lastZeitPanCursor := 1, VisibleQuickMenuSearchWin :=0
     , hquickMenuSearchWin, hGuiTip, lastTippyWin, lastMouseLeave := 1, colorPickerModeNow := 0
     , mustCaptureCloneBrush := 0, doNormalCursor := 1, hotkate, uiUseDarkMode := 0
     , menusflyOutVisible := 0, otherAscriptHwnd := "", lastLclickX := 0, lastLclickY := 0

Global allowMultiCoreMode, allowRecordHistory, alwaysOpenwithFIM, animGIFsSupport, askDeleteFiles, mouseToolTipWinCreated := 0
, AutoDownScaleIMGs, autoPlaySNDs, autoRemDeadEntry, ColorDepthDithering, countItemz, currentFileIndex, CurrentSLD, defMenuRefreshItm, doSlidesTransitions
, DynamicFoldersList, easySlideStoppage, editingSelectionNow, EllipseSelectMode, enableThumbsCaching, filesFilter, FlipImgH, FlipImgV, hSNDmedia, imgFxMode
, IMGresizingMode, imgSelX2, imgSelY2, LimitSelectBoundsImg, markedSelectFile, minimizeMemUsage, mustGenerateStaticFolders, MustLoadSLDprefs
, noTooltipMSGs, PrefsLargeFonts, RenderOpaqueIMG, resetImageViewOnChange, showHistogram, showImgAnnotations, showInfoBoxHUD, showSelectionGrid, skipDeadFiles
, skipSeenImagesSlider, SLDcacheFilesList, SLDhasFiles, sldsPattern, syncSlideShow2Audios, thumbnailsListMode, thumbsCacheFolder, thumbsDisplaying, totalFramesIndex
, TouchScreenMode, userHQraw, userimgQuality, UserMemBMP, usrTextureBGR, slidesFXrandomize, liveDrawingBrushTool := 0

; OnMessage(0x388, "WM_PENEVENT")
OnMessage(0x2a3, "WM_MOUSELEAVE")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x203, "WM_LBUTTON_DBL")
OnMessage(0x202, "WM_LBUTTONUP")
OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x207, "WM_MBUTTONDOWN")
OnMessage(0x047, "WM_WINDOWPOSCHANGED") ; window moving
OnMessage(0x20A, "WM_MOUSEWHEEL")
; OnMessage(0x24B, "WM_POINTERACTIVATE") 
; OnMessage(0x216, "WM_MOVING") ; window moving

Loop, 9
    OnMessage(255+A_Index, "PreventKeyPressBeep")   ; 0x100 to 0x108

OnMessage(0x100, "WM_KEYDOWN")
OnMessage(0x104, "WM_KEYDOWN")
; OnMessage(0x0247, "WM_POINTERUP") 
; OnMessage(0x20, "WM_SETCURSOR")
; OnMessage(0x211, "WM_ENTERMENULOOP")
; OnMessage(0x212, "WM_EXITMENULOOP")
; OnMessage(0x126, "WM_MENUCOMMAND")
; OnMessage(0x120, "WM_MENUCHAR")
; OnMessage(0x11Fb, "WM_MENUSELECT")

OnMessage(0x200, "WM_MOUSEMOVE")
OnMessage(0x06, "activateMainWin")   ; WM_ACTIVATE 
OnMessage(0x08, "activateMainWin")   ; WM_KILLFOCUS 

setPriorityThread(2)
lastMenuInvoked[1] := A_TickCount
; OnExit, doCleanup
Return

setPriorityThread(level, handle:="A") {
  If (handle="A" || !handle)
     handle := DllCall("GetCurrentThread")
  Return DllCall("SetThreadPriority", "UPtr", handle, "Int", level)
}

updateWindowColor() {
     Sleep, 1
     ; WindowBgrColor := MainExe.ahkgetvar.WindowBgrColor
     Gui, 1: Color, %WindowBgrColor%
}

destroyAllGUIs() {
   Gui, 1: Destroy
   Gui, 2: Destroy
   Gui, 3: Destroy
   Gui, 4: Destroy
   Gui, 5: Destroy
   taskBarUI.clearAll()
   Sleep, 50
}

BuildGUI(params:=0) {
   Critical, on
   If !InStr(params, "$")
   {
      mustAssignVarz := 1
      WindowBgrColor := MainExe.ahkgetvar.WindowBgrColor
      isAlwaysOnTop := MainExe.ahkgetvar.isAlwaysOnTop
      mainCompiledPath := MainExe.ahkgetvar.mainCompiledPath
      isTitleBarVisible := MainExe.ahkgetvar.isTitleBarVisible
      TouchScreenMode := MainExe.ahkgetvar.TouchScreenMode
      userAllowWindowDrag := MainExe.ahkgetvar.userAllowWindowDrag
      mainWinPos := MainExe.ahkgetvar.mainWinPos
      mainWinSize := MainExe.ahkgetvar.mainWinSize
      mainWinMaximized := MainExe.ahkgetvar.mainWinMaximized
   } Else
   {
      externObj := StrSplit(params, "$")
      WindowBgrColor := externObj[1]
      isAlwaysOnTop := externObj[2]
      mainCompiledPath := externObj[3]
      isTitleBarVisible := externObj[4]
      TouchScreenMode := externObj[5]
      userAllowWindowDrag := externObj[6]
      mainWinPos := externObj[7]
      mainWinSize := externObj[8]
      mainWinMaximized := externObj[9]
      IMGresizingMode := externObj[10]
      OSDbgrColor := externObj[11]
      OSDtextColor := externObj[12]
      LargeUIfontValue := externObj[13]
      PrefsLargeFonts := externObj[14]
      OSDFontName := externObj[15]
      FontBolded := externObj[16]
   }

   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialWh := "w" A_ScreenWidth//1.7 " h" A_ScreenHeight//1.5
   ; If !A_IsCompiled
     Try Menu, Tray, Icon, %mainCompiledPath%\qpv-icon.ico

   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   Gui, 1: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Font, s1
   Gui, 1: Add, Text, x0 y0 w1 h1 BackgroundTrans vPicOnGui1 hwndhPicOnGui1, Previous image
   Gui, 1: Add, Button, xp-100 yp-100 w1 h1 Default,a
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2a, Zoom in
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2b, Double-click to toggle view mode | Swipe to make gestures | Left-click and drag to pan image
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2c, Zoom out
   Gui, 1: Add, Text, x3 y3 w3 h3 BackgroundTrans vPicOnGui3, Next image
   If (isTitleBarVisible=1)
      Gui, 1: +Caption
   Else
      Gui, 1: -Caption

   Gui, 1: Show, Maximize Hide Center %initialwh%, %appTitle%
   Try taskBarUI := new taskbarInterface(PVhwnd)
   Sleep, 1
   createGDIwinThumbs()
   Sleep, 1
   createGDIwin()
   Sleep, 1
   createGDIselectorWin()
   Sleep, 1
   createGDIinfosWin()
   Sleep, 2
   updateUIctrl(1)
   If (mustAssignVarz=1)
   {
      MainExe.ahkassign("PVhwnd", PVhwnd)
      MainExe.ahkassign("hGDIinfosWin", hGDIinfosWin)
      MainExe.ahkassign("hGDIwin", hGDIwin)
      MainExe.ahkassign("hGDIthumbsWin", hGDIthumbsWin)
      MainExe.ahkassign("hGDIselectWin", hGDIselectWin)
      MainExe.ahkassign("hPicOnGui1", hPicOnGui1)
      MainExe.ahkassign("winGDIcreated", winGDIcreated)
      MainExe.ahkassign("ThumbsWinGDIcreated", ThumbsWinGDIcreated)
   }

   WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
   Sleep, 1
   WinActivate, ahk_id %PVhwnd%
   posu := StrSplit(mainWinPos, "|")
   sizeu := StrSplit(mainWinSize, "|")
   pX := posu[1], pY := posu[2]
   sW := sizeu[1], sH := sizeu[2]
   ; ToolTip, % mainWinPos "==" mainWinSize "==" mainWinMaximized , , , 2
   If (mainWinMaximized=2 || pX="" || pY="" || sW="" || sH="")
   {
      repositionWindowCenter(1, PVhwnd, "mouse", appTitle)
      Sleep, 50
      Gui, 1: Show, Maximize
   } Else
   {
      Gui, 1: Show, x%pX% y%pY% w%sW% h%sH%
      Sleep, 25
   }

   r := PVhwnd "|" hGDIinfosWin "|" hGDIwin "|" hGDIthumbsWin "|" hGDIselectWin "|" hPicOnGui1 "|" winGDIcreated "|" ThumbsWinGDIcreated
   Return r
}

setTaskbarIconState(mode) {
   If (mode="anim")
      taskBarUI.SetProgressType("INDETERMINATE")
   Else If (mode="normal")
      taskBarUI.SetProgressType("off")
   Else If (mode="error" )
      taskBarUI.setTaskbarIconColor("red")
   Else If (mode="exclamation" && runningLongOperation!=1)
      ; taskBarUI.flashTaskbarIcon("yellow", 6, 150, 150)
      taskBarUI.setTaskbarIconColor("yellow")
   Else If (mode="question" && runningLongOperation!=1)
      taskBarUI.flashTaskbarIcon("green", 3, 150, 150)
      ; taskBarUI.setTaskbarIconColor("green")
}

GetClientSize(ByRef w, ByRef h, hwnd) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
    Static prevW, prevH, lastInvoked := 1
    If (A_TickCount - lastInvoked<95)
    {
       W := prevW
       H := prevH
       Return
    }

    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    prevW := W := NumGet(rc, 8, "int")
    prevH := H := NumGet(rc, 12, "int")
    lastInvoked := A_TickCount
} 

updateUIctrl(forceThis:=0) {
   Static prevState
   If (forceThis="kill")
   {
      prevState := ""
      Return
   }

   GetWinClientSize(GuiW, GuiH, PVhwnd, 0)
   If (forceThis=1)
   {
      editingSelectionNow := MainExe.ahkgetvar.editingSelectionNow
      isAlwaysOnTop := MainExe.ahkgetvar.isAlwaysOnTop
   }

   ctrlW := (editingSelectionNow=1) ? GuiW//8 : GuiW//7
   ctrlH2 := (editingSelectionNow=1) ? GuiH//6 : GuiH//5
   ctrlH3 := GuiH - ctrlH2*2
   ctrlW2 := GuiW - ctrlW*2
   ctrlY1 := ctrlH2
   ctrlY2 := ctrlH2*2
   ctrlY3 := ctrlH2 + ctrlH3
   ctrlX1 := ctrlW
   ctrlX2 := ctrlW + ctrlW2
   winCtrlsCoords[1] := [0, 0, ctrlW, GuiH, "PicOnGUI1"]
   winCtrlsCoords[2] := [ctrlX1, 0, ctrlW2, ctrlH2, "PicOnGUI2a"]
   winCtrlsCoords[3] := [ctrlX1, ctrlY1, ctrlW2, ctrlH3, "PicOnGUI2b"]
   winCtrlsCoords[4] := [ctrlX1, ctrlY3, ctrlW2, ctrlH2, "PicOnGUI2c"]
   winCtrlsCoords[5] := [ctrlX2, 0, ctrlW, GuiH, "PicOnGUI3"]
   thisState := "a" GuiW GuiH ctrlW2 ctrlH2 ctrlY3 editingSelectionNow isAlwaysOnTop TouchScreenMode
   If (thisState!=prevState)
   {
      WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%   
      GuiControl, 1: Move, PicOnGUI1, % "w" ctrlW " h" GuiH " x0 y0"
      GuiControl, 1: Move, PicOnGUI2a, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y0"
      GuiControl, 1: Move, PicOnGUI2b, % "w" ctrlW2 " h" ctrlH3 " x" ctrlX1 " y" ctrlY1
      GuiControl, 1: Move, PicOnGUI2c, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" ctrlY3
      GuiControl, 1: Move, PicOnGUI3, % "w" ctrlW " h" GuiH " x" ctrlX2 " y0"
      setUIlabels()
      prevState := thisState
      UpdateUiStatusBar(0, 0, "kill", 0)
   }
}

setUIlabels() {
   GuiControl, 1:, PicOnGUI1, % (editingSelectionNow=1 || TouchScreenMode!=1) ? "Image view" : "Previous image"
   GuiControl, 1:, PicOnGUI2a, % (TouchScreenMode!=1) ? "Image view" : "Zoom in"
   GuiControl, 1:, PicOnGUI2b, % (editingSelectionNow=1 || TouchScreenMode!=1) ? "Image view | Double-click anywhere to toggle view mode" : "Double-click to toggle view mode | Swipe to make gestures | Left-click and drag to pan image"
   GuiControl, 1:, PicOnGUI2c, % (TouchScreenMode!=1) ? "Image view" : "Zoom out"
   GuiControl, 1:, PicOnGUI3, % (editingSelectionNow=1 || TouchScreenMode!=1) ? "Image view" : "Next image"
}

UpdateUiStatusBar(stringu:=0, heightu:=0, mustResize:=0, infos:=0) {
   Static prevState

   If (mustResize="kill")
   {
      prevState := mustResize
   } Else If (mustResize="list")
   {
      GetClientSize(GuiW, GuiH, PVhwnd)
      thisState := "a" mustResize GuiW GuiH heightu
      If (thisState!=prevState)
      {
         GuiControl, 1: Move, PicOnGUI1, % "w" GuiW " h" GuiH - heightu
         GuiControl, 1: Move, PicOnGUI2a, % "w" GuiW " h" heightu " x1 y" GuiH - heightu
         GuiControl, 1: Move, PicOnGUI2b, w1 h1 x1 y1
         GuiControl, 1: Move, PicOnGUI2c, w1 h1 x1 y1
         GuiControl, 1: Move, PicOnGUI3, w1 h1 x1 y1
         winCtrlsCoords[1] := [0, 0, GuiW, GuiH - heightu, "PicOnGUI1"]
         winCtrlsCoords[2] := [1, GuiH - heightu, GuiW, heightu, "PicOnGUI2a"]
         winCtrlsCoords[3] := [1, 1, 1, 1, "PicOnGUI2b"]
         winCtrlsCoords[4] := [1, 3, 1, 1, "PicOnGUI2c"]
         winCtrlsCoords[5] := [1, 1, 1, 1, "PicOnGUI3"]
         prevState := thisState
      }

      GuiControl, 1:, PicOnGUI1, Files list container
      GuiControl, 1:, PicOnGUI2a, Status bar
      updateUIctrl("kill")
   } Else If (mustResize="image")
   {
      prevState := mustResize
      updateUIctrl()
   } Else If (stringu && heightu)
   {
      updateUIctrl("kill")
      prevState := mustResize
      GetClientSize(GuiW, GuiH, PVhwnd)
      GuiControl, 1: Move, PicOnGUI1, % "w" GuiW " h" GuiH - heightu
      GuiControl, 1: Move, PicOnGUI2a, % "w" GuiW " h" heightu " x1 y" GuiH - heightu
      GuiControl, 1:, PicOnGUI2a, % stringu
      winCtrlsCoords[1] := [0, 0, GuiW, GuiH - heightu, "PicOnGUI1"]
      winCtrlsCoords[2] := [1, GuiH - heightu, GuiW, heightu, "PicOnGUI2a"]
      If infos
         GuiControl, 1:, PicOnGUI1, % "Files list container: " infos " elements in view"
   }
}

createGDIwin() {
   Critical, on
   ; WinGetPos, , , mainW, mainH, ahk_id %PVhwnd%
   Gui, 2: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIwin +Owner1
   Gui, 2: Show, NoActivate, %appTitle%: Picture container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIwin)
   winGDIcreated := 1
}

createGDIwinThumbs() {
   Critical, on

   Gui, 3: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIthumbsWin +Owner1
   Gui, 3: Show, NoActivate, %appTitle%: Thumbnails container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIthumbsWin)

   ThumbsWinGDIcreated := 1
}

createGDIinfosWin() {
   Critical, on

   Gui, 4: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIinfosWin +Owner1
   Gui, 4: Show, NoActivate, %appTitle%: Infos container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIinfosWin)

   InfosWinGDIcreated := 1
}

createGDIselectorWin() {
   Critical, on

   Gui, 5: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIselectWin +Owner1
   Gui, 5: Show, NoActivate, %appTitle%: Selector container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIselectWin)

   SelectWinGDIcreated := 1
}

SetParentID(Window_ID, theOther) {
   Return DllCall("SetParent", "uint", theOther, "uint", Window_ID) ; success = handle to previous parent, failure =null 
}

miniGDIupdater() {
   updateUIctrl(0)
   r := MainExe.ahkPostFunction("GuiGDIupdaterResize", PrevGuiSizeEvent)
}

detectLongOperation(timer) {
  If (mustAbandonCurrentOperations=1)
     Return 1

  executingCanceableOperation := MainExe.ahkgetvar.executingCanceableOperation
  If (A_TickCount - executingCanceableOperation<timer)
  {
     msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
     If (msgResult="yes")
     {
        executingCanceableOperation := mustAbandonCurrentOperations := 1
        lastLongOperationAbort := A_TickCount
        ; MainExe.ahkassign("executingCanceableOperation", executingCanceableOperation)
        ; MainExe.ahkassign("lastLongOperationAbort", lastLongOperationAbort)
        ; MainExe.ahkassign("mustAbandonCurrentOperations", mustAbandonCurrentOperations)
     } Else lastCloseInvoked := executingCanceableOperation := mustAbandonCurrentOperations := 0
     Return 1
  } Else Return 0
}

openFileDialogWrapper(optionz, startPath, msg, pattern) {
   prevOpenedFile := 0
   Gui, 1: +OwnDialogs
   FileSelectFile, file2save, % optionz, % startPath, % msg, % pattern
   If (!ErrorLevel && StrLen(file2save)>2)
      r := file2save
   ; WinActivate, ahk_id %PVhwnd%
   If !AnyWindowOpen
      lastOtherWinClose := A_TickCount
   prevOpenedFile := r ? r : 1
   Return r
}

openFoldersDialogWrapper(optionz, startPath, msg) {
   prevOpenedFile := 0
   Gui, 1: +OwnDialogs
   FileSelectFolder, SelectedDir, % startPath, % optionz, % msg
   If (!ErrorLevel && StrLen(SelectedDir)>2)
      r := SelectedDir
   ; WinActivate, ahk_id %PVhwnd%
   If !AnyWindowOpen
      lastOtherWinClose := A_TickCount
   prevOpenedFile := r ? r : 1
   Return r
}

msgBoxWrapper(winTitle, msg, buttonz:=0, defaultBTN:=1, iconz:=0, modality:=0, optionz:=0) {
   ; Buttonz options:
   ; 0 = OK (that is, only an OK button is displayed)
   ; 1 = OK/Cancel
   ; 2 = Abort/Retry/Ignore
   ; 3 - Yes/No/Cancel
   ; 4 = Yes/No
   ; 5 = Retry/Cancel
   ; 6 = Cancel/Try Again/Continue

   ; Iconz options:
   ; 16 = Icon Hand (stop/error)
   ; 32 = Icon Question
   ; 48 = Icon Exclamation
   ; 64 = Icon Asterisk (info)

   ; Modality options:
   ; 4096 = System Modal (always on top)
   ; 8192 = Task Modal
   ; 262144 = Always-on-top (style WS_EX_TOPMOST - like System Modal but omits title bar icon)

   If (defaultBTN=2)
      defaultBTN := 255
   Else If (defaultBTN=3)
      defaultBTN := 512
   Else
      defaultBTN := 0

   If (iconz=1 || iconz="hand" || iconz="error" || iconz="stop")
      iconz := 16
   Else If (iconz=2 || iconz="question")
      iconz := 32
   Else If (iconz=3 || iconz="exclamation")
      iconz := 48
   Else If (iconz=4 || iconz="info")
      iconz := 64
   Else
      iconz := 0

   theseOptionz := buttonz + iconz + defaultBTN + modality
   If optionz
      theseOptionz := optionz

   Gui, 1: +OwnDialogs
   MsgBox, % theseOptionz, % winTitle, % msg
   IfMsgBox, Yes
        r := "Yes"
   IfMsgBox, No
        r := "No"
   IfMsgBox, OK
        r := "OK"
   IfMsgBox, Cancel
        r := "Cancel"
   IfMsgBox, Abort
        r := "Abort"
   IfMsgBox, Ignore
        r := "Ignore"
   IfMsgBox, Retry
        r := "Retry"
   IfMsgBox, Continue
        r := "Continue"
   IfMsgBox, TryAgain
        r := "TryAgain"

   If (!AnyWindowOpen && !InStr(msg, "quit") && !InStr(msg, "exit"))
      lastOtherWinClose := A_TickCount

   ; addJournalEntry("DIALOG BOX: " msg "`n`nUser answered: " r)
   Return r
}

addJournalEntry(msg) {
   If (!runningLongOperation && !imageLoading)
      MainExe.ahkPostFunction(A_ThisFunc, msg)
}

WM_MOUSEWHEEL(wParam, lP, msg, hwnd) {
   isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
   If !isOkay
      Return 0

   If preventSillyGui(A_Gui)
      Return

   If (slideShowRunning=1 || animGIFplaying=1)
   {
      turnOffSlideshow()
      Return 0
   }

   prefix := ""
   prefix .= (wParam & 0xffff=4) ? "+" : "" ; shift
   prefix .= (wParam & 0xffff=8) ? "^" : "" ; ctrl
   prefix .= GetKeyState("Alt", "P") ? "!" : ""
   ; HI := (Value >> 16) & 0xFFFF
   ; LO := Value & 0xFFFF
   result := (wParam >> 16)      ; return the HIWORD -  high-order word 
   ; TulTip(1, " == ", result, resultA, resultB, resultC, resultD, resultE)
   stepping := Round(Abs(result) / 120)
   direction := (result<0) ? "WheelUp" : "WheelDown"
   MainExe.ahkPostFunction("KeyboardResponder", prefix direction, PVhwnd, 0)
   Return 0
}

preventSillyGui(thisGui) {
  r := (thisGui="mouseToolTipGuia" || thisGui="menuFlier") ? 1 : 0
  Return r
}

WM_LBUTTONDOWN(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartTime<500)
       Return 0

    If preventSillyGui(A_Gui)
       Return

    lastLclickX := lP & 0xFFFF
    lastLclickY := lP >> 16
    LbtnDwn := 1
    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    SetTimer, ResetLbtn, -55
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1) ? 0 : 1
    If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900) && slideShowRunning!=1 && animGIFplaying!=1)
       askAboutStoppingOperations()
    Else If (slideShowRunning=1 || animGIFplaying=1)
       turnOffSlideshow()
    Else If isOkay
       WinClickAction()
    Return 0
}

WM_LBUTTONUP(wP, lP, msg, hwnd) {
    LbtnDwn := 0
    Return 0
}

WM_MBUTTONDOWN(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartTime<500)
       Return 0

    If preventSillyGui(A_Gui)
       Return

    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    LbtnDwn := 0
    canCancelImageLoad := 4
    If (slideShowRunning=1 || animGIFplaying=1)
    {
       turnOffSlideshow()
       Return 0
    }

    mX := lP & 0xFFFF
    mY := lP >> 16
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1) ? 0 : 1
    If (drawingShapeNow=1)
       sendWinClickAct("remClick", "n", mX, mY)
    Else If (imgEditPanelOpened=1 && AnyWindowOpen)
       MainExe.ahkPostFunction("toggleImgEditPanelWindow")
    Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
       askAboutStoppingOperations()
    Else If (!AnyWindowOpen && isOkay)
       MainExe.ahkPostFunction("ToggleThumbsMode")
    Return 0
}

WM_LBUTTON_DBL(wP, lP, msg, hwnd) {
    LbtnDwn := 0
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    If ((A_TickCount - scriptStartTime<500) || !isOkay)
       Return 0

    If preventSillyGui(A_Gui)
       Return 0

    If (slideShowRunning=1 || animGIFplaying=1)
    {
       turnOffSlideshow()
       Return 0
    }

    If (A_TickCount - lastMouseLeave>350)
       WinClickAction("DoubleClick")

    Return 0
}

askAboutStoppingOperations() {
     If (mustAbandonCurrentOperations!=1)
     {
        lastCloseInvoked := 0
        WinSet, Enable,, ahk_id %PVhwnd%
        msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
        If (msgResult="yes")
           mustAbandonCurrentOperations := 1
     } ; Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
}

WM_RBUTTONUP(wParam, lP, msg, hwnd) {
  Static lastState := 0
  LbtnDwn := 0
  If (A_TickCount - scriptStartTime<500)
     Return 0

  If preventSillyGui(A_Gui)
     Return

  If (slideShowRunning=1 || animGIFplaying=1)
  {
     turnOffSlideshow()
     Return 0
  }

  If (mouseToolTipWinCreated=1)
     mouseTurnOFFtooltip()

  ; thumbsDisplaying := MainExe.ahkgetvar.thumbsDisplaying
  ; AnyWindowOpen := MainExe.ahkgetvar.AnyWindowOpen
  ; maxFilesIndex := MainExe.ahkgetvar.maxFilesIndex
  If !identifyThisWin()
     Return 0

  ; GuiControl, 1:, editDummy, -
  If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
  {
     askAboutStoppingOperations()
     Return 0
  }

  prefix := ""
  prefix .= (wParam & 0xffff=4) ? "+" : "" ; shift
  prefix .= (wParam & 0xffff=8) ? "^" : "" ; ctrl
  mX := lP & 0xFFFF
  mY := lP >> 16
  If (whileLoopExec!=1 && runningLongOperation!=1)
  {
     If (prefix="^" && !AnyWindowOpen && drawingShapeNow!=1 && mustCaptureCloneBrush!=1 && thumbsDisplaying!=1)
        MainExe.ahkPostFunction("restartGIFplayback")
     Else If (prefix="+" && !AnyWindowOpen && drawingShapeNow!=1 && mustCaptureCloneBrush!=1)
        MainExe.ahkPostFunction("BuildSecondMenu")
     Else
        InitGuiContextMenu(mX, mY)
  }
  Return 0
}

InitMainContextMenu(mX, mY) {
   If mX is not Number
      GetPhysicalCursorPos(mX, mY)

   thisTick := Round(lastMenuInvoked[1])
   thisX := lastMenuInvoked[2]
   thisY := lastMenuInvoked[3]

   If ((A_TickCount - thisTick<350) && isDotInRect(mX, mY, 15, 15, thisX, thisY, 1))
   {
      SendInput, {Escape}
      Sleep, 1
      PanelQuickSearchMenuOptions()
      Return
   }

   lastMenuInvoked := [A_TickCount, mX, mY]
   InitGuiContextMenu(mX, mY)
   SetTimer, TimerMouseMove, -25
}

TimerMouseMove() {
   MouseMove, -2, -2, 1, R
}

PanelQuickSearchMenuOptions() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return

    MainExe.ahkPostFunction(A_ThisFunc)
    lastInvoked := A_TickCount
}

toggleAppToolbar() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return

    MainExe.ahkPostFunction(A_ThisFunc)
    lastInvoked := A_TickCount
}

InitGuiContextMenu(mX, mY) {
    MainExe.ahkPostFunction(A_ThisFunc, "extern", mX, mY)
}

slideshowsHandler(thisSlideSpeed, act, how) {
   SlideHowMode := how
   slideShowDelay := thisSlideSpeed
   prevFullIMGload := 1
   If (act="start")
   {
      setTaskbarIconState("Normal")
      slideShowRunning := 1
      SetTimer, theSlideShowCore, % -slideShowDelay
   } Else If (act="stop")
   {
      allowNextSlide := 1
      slideShowRunning := 0
      SetTimer, theSlideShowCore, Off
   }
}

dummySlideshow() {
   ; hasAdvancedSlide := (modus="gif") ? hasAdvancedSlide : 1
   ; thisAllowNextSlide := (animGIFplaying=1) ? 0 : allowNextSlide
   ; preventChange := (allowGIFsPlayEntirely=1 && animGIFplaying=1) ? 1 : 0
   If (slideShowRunning=1 && allowNextSlide=1)
   {
      setTaskbarIconState("Normal")
      hasAdvancedSlide := 0
      SetTimer, theSlideShowCore, % -slideShowDelay
   }
}

theSlideShowCore(paramu:=0) {
  thisZeit :=  A_TickCount - prevFullIMGload
  ; MsgBox, % thisZeit "--" slideShowDelay
  If (thisZeit < slideShowDelay//1.25) || (allowNextSlide!=1 && paramu!="force") ; || (allowGIFsPlayEntirely=1 && animGIFplaying=1)
     Return

  mouseTurnOFFtooltip()
  prevFullIMGload := A_TickCount
  If (slideShowRunning=1 && slidesFXrandomize=1)
     MainExe.ahkPostFunction("VPimgFXrandomizer")

  If (SlideHowMode=1)
     MainExe.ahkPostFunction("RandomPicture")
  Else If (SlideHowMode=2)
     MainExe.ahkPostFunction("PreviousPicture")
  Else If (SlideHowMode=3)
     MainExe.ahkPostFunction("NextPicture")
  hasAdvancedSlide := 1
}

WM_POINTERACTIVATE() {
    lastPointerUseZeit := A_TickCount
    MouseGetPos, , , OutputVarWin
    GetMouseCoord2wind(PVhwnd, mX, mY, mXo, mYo)
    canCancelImageLoad := 4
    LbtnDwn := 1
    ctrlName := "unknown"
/*
    Loop, 5
    {
         xu := winCtrlsCoords[A_Index, 1]
         yu := winCtrlsCoords[A_Index, 2]
         wu := winCtrlsCoords[A_Index, 3]
         hu := winCtrlsCoords[A_Index, 4]
         ctrlName := winCtrlsCoords[A_Index, 5]
         If isDotInRect(mX, mY, xu, xu + wu, yu, yu + hu)
            Break
    }
*/
    ; ToolTip, % mX "=" mY "==" ctrlName , , , 3
    If (slideShowRunning=1)
       turnOffSlideshow()
    ; Else
    ;    sendWinClickAct("normal-pen-down", ctrlName, mX, mY, mXo, mYo)
    lastPointerUseZeit := A_TickCount
}

WM_POINTERUP(wP, lP, msg, hwnd) {
  SoundBeep, 400, 90 
  ; Return DllCall("DefWindowProc", "Ptr", hwnd, "uint", msg, "UPtr", wP, "Ptr", lP, "Ptr")
  ; ToolTip, % "r=" r , , , 2
  Return 1
}

updateGDIwinPos() {
  ; thumbsDisplaying := MainExe.ahkgetvar.thumbsDisplaying
  ; If (A_OSVersion="WIN_7")
  JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
  ; Else GuiX := GuiY := 1

  GetClientSize(mainWidth, mainHeight, PVhwnd)
  If (thumbsDisplaying=1)
  {
     WinMove, ahk_id %hGDIthumbsWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
     WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight% , ahk_id %hGDIthumbsWin%
  }
  WinMove, ahk_id %hGDIWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
  WinMove, ahk_id %hGDIselectWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
  WinMove, ahk_id %hGDIinfosWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
}

triggerOwnDialogs() {
  ; AnyWindowOpen := MainExe.ahkgetvar.AnyWindowOpen
  ; If AnyWindowOpen
  ;    Gui, SettingsGUIA: +OwnDialogs
  ; Else
     Gui, 1: +OwnDialogs
}

JEE_ClientToScreen(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472

  VarSetCapacity(POINT, 8)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ClientToScreen", "Ptr", hWnd, "Ptr", &POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
}

WinClickAction(thisEvent:="normal") {
    Static lastInvoked := 1, lastEvent
    If (A_TickCount - lastInvoked<25)
       Return

    ; GetMouseCoord2wind(PVhwnd, mX, mY, mXo, mYo)
    mX := lastLclickX,    mY := lastLclickY
    ; ToolTip, % mX "=" mY "`n" lastLclickX "=" lastLclickY , , , 2
    canCancelImageLoad := 4
    ctrlName := A_GuiControl
    Loop, 5
    {
         xu := winCtrlsCoords[A_Index, 1]
         yu := winCtrlsCoords[A_Index, 2]
         wu := winCtrlsCoords[A_Index, 3]
         hu := winCtrlsCoords[A_Index, 4]
         ctrlName := winCtrlsCoords[A_Index, 5]
         If isDotInRect(mX, mY, xu, xu + wu, yu, yu + hu)
            Break
    }

    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    ; ToolTip, % mX "=" mY "=" param "==" ctrlName "--" A_GuiControl "--" A_GuiControlEvent , , , 2
    lastInvoked := A_TickCount
    If (slideShowRunning=1)
       turnOffSlideshow()
    Else If (A_TickCount - lastZeitPanCursor<350) && (thumbsDisplaying=0)
       MainExe.ahkPostFunction("simplePanIMGonClick", 0, 1, 1)
    Else
       sendWinClickAct(thisEvent, ctrlName, mX, mY)
}

sendWinClickAct(ctrlEvent, guiCtrl, mX, mY) {
     MainExe.ahkPostFunction("WinClickAction", ctrlEvent, guiCtrl, mX, mY)
}

GetMouseCoord2wind(hwnd, ByRef nx, ByRef ny, ByRef ox, ByRef oy) {
    ; CoordMode, Mouse, Screen
    MouseGetPos, ox, oy
    JEE_ScreenToClient(hwnd, ox, oy, nx, ny)
}

JEE_ScreenToClient(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472
  VarSetCapacity(POINT, 8)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ScreenToClient", "UPtr", hWnd, "UPtr", &POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
  POINT := ""
}

ResetLbtn() {
  LbtnDwn := 0
}

WM_MOVING() {
  ; If (toolTipGuiCreated=1)
  ;    MainExe.ahkPostFunction("TooltipCreator", 1, 1)
}

WM_WINDOWPOSCHANGED() {
   Static b
   WinGet, winStateu, MinMax, ahk_id %PVhwnd%
   If (winStateu=-1)
      Return

   WinGetPos, winX, winY, winWidth, winHeight, ahk_id %PVhwnd%
   a := "a" winX winY winWidth winHeight
   If (a!=b)
   {
      ; Random, z, -900, 900
      ; ToolTip, % z , , , 2
      If (tempBtnVisible!="null")
         SetTimer, RepositionTempBtnGui, -95

      SetTimer, saveMainWinPos, -35
      Global lastWinDrag := A_TickCount
      If (A_OSVersion="WIN_7" || isWinXP=1)
         SetTimer, updateGDIwinPos, -5
      If (ShowAdvToolbar=1 && lockToolbar2Win=1)
         SetTimer, tlbrResetPosition, -90
      b := a
  }
}

RepositionTempBtnGui() {
     MainExe.ahkPostFunction(A_ThisFunc)
}

saveMainWinPos() {
     MainExe.ahkPostFunction(A_ThisFunc)
}

tlbrResetPosition() {
     MainExe.ahkPostFunction(A_ThisFunc)
}

changeMcursor(whichCursor) {
  Static lastInvoked := 1
  ; If (whichCursor="normal")
  ;    SetTimer, ResetLoadStatus, -20

  If (slideShowRunning=1 || animGIFplaying=1)
     Return

  If (A_TickCount - lastZeitPanCursor<50)
     thisCursor := hCursMove

  If (whichCursor="normal-extra")
  {
     imageLoading := mustAbandonCurrentOperations := 0
     runningLongOperation := lastCloseInvoked := 0
     setTaskbarIconState("normal")
     thisCursor := hCursN
  } Else If (whichCursor="busy-img")
  {
     imageLoading := 1
     lastCloseInvoked := 0
     setTaskbarIconState("anim")
     thisCursor := hCursBusy
  } Else If (whichCursor="busy" && LbtnDwn!=1)
  {
     setTaskbarIconState("anim")
     thisCursor := hCursBusy
  } Else If (whichCursor="normal")
  {
     imageLoading := 0
     setTaskbarIconState("normal")
     thisCursor := hCursN
  } Else If (whichCursor="finger")
  {
     thisCursor := hCursFinger
  } Else If (whichCursor="move")
  {
     lastZeitPanCursor := A_TickCount
     thisCursor := hCursMove
  } Else If (whichCursor="cross")
  {
     thisCursor := hCursCross
  } Else Return

  Try DllCall("user32\SetCursor", "Ptr", thisCursor)
  lastInvoked := A_TickCount
}

ResetLoadStatus() {
   imageLoading := 0
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
}

isInRange(value, inputA, inputB) {
    If (value=inputA || value=inputB)
       Return 1

    Return (value>=min(inputA, inputB) && value<=max(inputA, inputB)) ? 1 : 0
}

WM_SETCURSOR() {
  r := 0
  If (slideShowRunning=1 && isSamePos=1)
     r := 1
  Else If (drawingShapeNow=1 || liveDrawingBrushTool=1)
     r := 1
  Else If ((runningLongOperation=1 || imageLoading=1) && slideShowRunning!=1)
     r := 1

  Return r
}

isDotInRect(mX, mY, x1, x2, y1, y2, modus:=0) {
   If (modus=1)
      r := (isInRange(mX, y1 - x1, y1 + x2) && isInRange(mY, y2 - x1, y2 + x2)) ? 1 : 0
   Else
      r := (isInRange(mX, x1, x2) && isInRange(mY, y1, y2)) ? 1 : 0
   Return r
}

isQPVactive() {
    Static lastInvoked := 1, last := 1
    If (A_TickCount - lastInvoked<450) && (last=0)
       Return last

    A := WinActive("A")
    lastInvoked := A_TickCount
    last := (A=hSetWinGui && AnyWindowOpen || A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin || A=hGDIinfosWin || A=hGuiTip && mouseToolTipWinCreated=1 || A=hquickMenuSearchWin && VisibleQuickMenuSearchWin=1 || A=hQPVtoolbar && ShowAdvToolbar=1 || A=hfdTreeWinGui && folderTreeWinOpen=1) ? 1 : 0
    Return last
}

WM_MOUSEMOVE(wP, lP, msg, hwnd) {
  Static lastInvoked := 1, prevPos, prevArrayPos := [], prevState
  If ((A_TickCount - lastZeitPanCursor < 300) || !isQPVactive())
     Return

  MouseGetPos, mX, mY, OutputVarWin
  isSamePos := (isInRange(mX, prevArrayPos[1] + 3, prevArrayPos[1] - 3) && isInRange(mY, prevArrayPos[2] + 3, prevArrayPos[2] - 3)) ? 1 : 0
  If (slideShowRunning=1 && isSamePos=1)
     Try DllCall("user32\SetCursor", "Ptr", 0)
  Else If (drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1) && (OutputVarWin=PVhwnd)
     changeMcursor("cross")
  Else If ((runningLongOperation=1 || imageLoading=1) && slideShowRunning!=1)
     changeMcursor("busy")

  If (A_TickCount - scriptStartTime < 900)
     Return

  thisPos := mX "-" mY
  prevArrayPos := [mX, mY]
  If (A_TickCount - lastInvoked > 55) && (thisPos!=prevPos)
  {
     ; isThisWin :=(OutputVarWin=PVhwnd) ? 1 : 0
     thisPrefsWinOpen := (imgEditPanelOpened=1) ? 0 : AnyWindowOpen
     lastInvoked := A_TickCount
     If (slideShowRunning!=1 && !thisPrefsWinOpen && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1)
        MainExe.ahkPostFunction("MouseMoveResponder")
     prevPos := mX "-" mY
  }
  ; actif := WinActive("A")
  ; WinGetTitle, title, ahk_id %actif%
  ; WinShow, ahk_id %actif%

  If (wP&0x1)
  {
     LbtnDwn := 1
     SetTimer, ResetLbtn, -55
     ; DllCall("DestroyWindow", "uptr", actif)
     ; SoundBeep 
  }

  ; ToolTip, % title "= " isTitleBarVisible " - " TouchScreenMode " = " OutputVarWin " = " actif
  If (isTitleBarVisible=0 && userAllowWindowDrag=1 && TouchScreenMode=0 && (wP&0x1))
  && (A_TickCount - lastWinDrag>45) 
  {
     PostMessage, 0xA1, 2,,, ahk_id %PVhwnd%
     lastWinDrag := A_TickCount
     ; MainExe.ahkassign("lastWinDrag", lastWinDrag)
     SetTimer, trackMouseDragging, -55
  } 
}

trackMouseDragging() {
    lastWinDrag := A_TickCount
}

WM_MOUSELEAVE(wP, lP, msg, hwnd) {
    lastMouseLeave := A_TickCount
}

dummyCheckWin() {
   thisHwnd := WinActive("A")
   drawingOkay := (thisHwnd=hGuiTip && mouseToolTipWinCreated=1 || thisHwnd=hQPVtoolbar && ShowAdvToolbar=1 || thisHwnd=PVhwnd || thisHwnd=tempBtnVisible || thisHwnd=hSetWinGui) ? 1 : 0
   ; ToolTip, % hSetWinGui "`n" thisHwnd , , , 2
   ; If (imgEditPanelOpened=1 && AnyWindowOpen>0 && panelWinCollapsed=1 && thisHwnd=hSetWinGui)
   ;    MainExe.ahkPostFunction("toggleImgEditPanelWindow")
   If (drawingShapeNow=1 && drawingOkay!=1)
      MainExe.ahkPostFunction("stopDrawingShape")
}

activateMainWin() {
   Static lastInvoked := 1
   If (A_TickCount - scriptStartTime<2000)
      Return

   lastMouseLeave := A_TickCount
   LbtnDwn := 0
   Sleep, -1
   z := identifyThisWin()
   If (editingSelectionNow=1 && slideShowRunning!=1 && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1)
      MainExe.ahkPostFunction("MouseMoveResponder", "krill")

   ; If (mouseToolTipWinCreated=1 && !z && !identifyParentWind())
   If (mouseToolTipWinCreated=1)
      SetTimer, mouseTurnOFFtooltip, -150

   ; If (A_TickCount - lastInvoked > 530)
   ;    GuiControl, 1:, editDummy, -

   ; If (drawingShapeNow=1) || (imgEditPanelOpened=1 && AnyWindowOpen>0 && panelWinCollapsed=1)
   ;    SetTimer, dummyCheckWin, -150

   lastInvoked := A_TickCount
}

dummyCheckActiveWin() {
  hwndu := WinActive("A")
  If (hwndu=hQPVtoolbar && ShowAdvToolbar=1)
     WinActivate, ahk_id %PVhwnd%
}

GuiSize(GuiHwnd, EventInfo, Width, Height) {
    If (A_TickCount - lastMenuBarUpdate < 150)
       Return

    PrevGuiSizeEvent := EventInfo
    ; ToolTip, % "l=" EventInfo , , , 2
    prevGUIresize := A_TickCount
    turnOffSlideshow()
    canCancelImageLoad := 4
    delayu := (isWinXP=1 || thumbsDisplaying=1) ? -15 : -5
    SetTimer, miniGDIupdater, % delayu
}

GuiDropFiles(GuiHwnd, FileArray, CtrlHwnd, X, Y) {
   Static lastInvoked := 1
   If (AnyWindowOpen>0 || mustCaptureCloneBrush=1 || whileLoopExec=1 || drawingShapeNow=1 || imageLoading=1 || runningLongOperation=1 || groppedFiles) || (A_TickCount - lastInvoked<300)
      Return

   lastInvoked := A_TickCount
   GuiHwnd := Format("{1:#x}", GuiHwnd)
   ; ToolTip, % GuiHwnd "`n" PVhwnd "`n" hGDIwin "`n" hGDIthumbsWin "`n" hGDIselectWin "`n" hGDIinfosWin, , , 2
   For i, file in FileArray
          groppedFiles .= file "`n"

   SetTimer, dummyTimerProccessDroppedFiles, -200
   lastInvoked := A_TickCount
   Return
}

Trimmer(string, whatTrim:="") {
   If (whatTrim!="")
      string := Trim(string, whatTrim)
   Else
      string := Trim(string, "`r`n `t`f`v`b")
      ; string := RegExReplace(string, "i)^([\R\p{Z}\p{C}]{0,})|([\R\p{Z}\p{C}]{0,})$")
   Return string
}

dummyTimerProccessDroppedFiles() {
   Static lastInvoked := 1
   groppedFiles := Trimmer(groppedFiles)
   If (!groppedFiles || (A_TickCount - lastInvoked<400))
      Return

   isCtrlDown := GetKeyState("Ctrl", "P")
   lastInvoked := A_TickCount
   imgFiles := foldersList := sldFile := ""
   turnOffSlideshow()
   canCancelImageLoad := 4
   countFiles := 0
   Loop, Parse, groppedFiles, `n,`r
   {
      changeMcursor("busy")
      ToolTip, % Please wait - processing dropped files list , , , 2
      line := Trimmer(A_LoopField)
      ; MsgBox, % A_LoopField
      If (A_Index>9900)
      {
         Break
      } Else If RegExMatch(line, "i)(.\.sld|.\.sldb)$")
      {
         sldFile := line
         Break
      } Else If InStr(FileExist(line), "D")
      {
         foldersList .= line "`n"
      } Else If RegExMatch(line, RegExFilesPattern)
      {
         countFiles++
         imgFiles .= line "`n"
      }
   }
   ToolTip, , , , 2
   If !isCtrlDown
      isCtrlDown := GetKeyState("Ctrl", "P")
   MainExe.ahkPostFunction("GuiDroppedFiles", imgFiles, foldersList, sldFile, countFiles, isCtrlDown)
   groppedFiles := ""
   lastInvoked := A_TickCount
}

1GuiClose:
GuiClose:
doCleanup:
   byeByeRoutine()
Return

byeByeRoutine() {
   Static lastInvoked := 1, lastInvokedThis := 1

   If (A_TickCount - lastInvokedThis < 250)
      Return

   If (runningLongOperation!=1 && imageLoading=1 && animGIFplaying!=1)
   {
      ; SoundBeep , % 250 + 100*lastCloseInvoked, 100
      canCancelImageLoad := 4
      WinSet, Enable,, ahk_id %PVhwnd%
      msgResult := msgBoxWrapper(appTitle, "The main window seems to be busy at the moment. Do you want to force exit this application ?", 4, 0, "question")
      If (msgResult="yes")
         SetTimer, TimerExit, -10
      Else lastCloseInvoked := -1
      lastCloseInvoked++
   } Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
   {
      If (mustAbandonCurrentOperations!=1)
         askAboutStoppingOperations()
      Else
         lastCloseInvoked++
   } Else If (drawingShapeNow=1)
   {
       drawingShapeNow := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MainExe.ahkPostFunction("stopDrawingShape", "cancel")
   } Else If (colorPickerModeNow=1)
   {
       colorPickerModeNow := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MainExe.ahkPostFunction("StopColorPicker")
   } Else If (omniBoxMode=1)
   {
       omniBoxMode := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MainExe.ahkPostFunction("closeQuickSearch")
   } Else If (mustCaptureCloneBrush=1)
   {
       mustCaptureCloneBrush := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MainExe.ahkPostFunction("StopCaptureClickStuff", "Escape")
   } Else If (folderTreeWinOpen=1)
   {
       folderTreeWinOpen := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MainExe.ahkPostFunction("fdTreeClose")
   } Else If ((AnyWindowOpen || thumbsDisplaying=1 || slideShowRunning=1) && (imageLoading!=1 && runningLongOperation!=1)) || (animGIFplaying=1)
   {
      lastInvokedThis := A_TickCount
      lastInvoked := A_TickCount
      If AnyWindowOpen
      {
         lastOtherWinClose := A_TickCount
         AnyWindowOpen := 0
         MainExe.ahkPostFunction("CloseWindow")
      } Else If (animGIFplaying=1)
      {
         lastOtherWinClose := A_TickCount
         If (slideShowRunning=1)
            turnOffSlideshow()

         stopGiFsPlayback()
      } Else If (slideShowRunning=1)
      {
         lastOtherWinClose := A_TickCount
         turnOffSlideshow()
      } Else If (thumbsDisplaying=1)
      {
         thumbsDisplaying := 0
         lastOtherWinClose := A_TickCount
         MainExe.ahkPostFunction("MenuReturnIMGedit")
      } Else lastCloseInvoked++
   } Else If (StrLen(UserMemBMP)>3 && undoLevelsRecorded>1) || (currentFilesListModified=1)
   {
      MainExe.ahkPostFunction("exitAppu", "external")
      ;  lastCloseInvoked++
   } Else If (markedSelectFile>50 && maxFilesIndex>100)
   {
      MainExe.ahkPostFunction("exitAppu", "select-external")
      ;  lastCloseInvoked++
   } Else lastCloseInvoked := 10

   If (A_TickCount - lastOtherWinClose < 450)
      Return

   If (lastCloseInvoked>3)
   {
      ; SoundBeep , 500, 2000
      SetTimer, TimerExit, % (lastCloseInvoked=10) ? -950 : -10
      MainExe.ahkPostFunction("TrueCleanup", 1)
   }
   lastInvoked := A_TickCount
}

dummyTimerExit() {
   SetTimer, TimerExit, -550
}

TimerExit() {
   ; SoundBeep , 900, 2000
   thisPID := GetCurrentProcessId()
   OutputDebug, QPV: forced exit. Secondary thread. PID=%thisPID%
   Process, Close, % thisPID
   ExitApp
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

identifyPanelWin() {
    r := (WinActive("A")=hSetWinGui) ? 1 : 0
    Return r
}

identifyOtherPanelsWin() {
    A := WinActive("A")
    r := (A=hGuiTip && mouseToolTipWinCreated=1 || A=hquickMenuSearchWin && VisibleQuickMenuSearchWin=1 || A=hQPVtoolbar && ShowAdvToolbar=1 || A=hfdTreeWinGui && folderTreeWinOpen=1) ? 1 : 0
    Return r
}

identifyParentWind() {
    uz := WinActive("A")
    Az := DllCall("GetParent", "UPtr", uz, "UPtr")
    r := (Az=A_ScriptHwnd || Az=otherAscriptHwnd || Az=hSetWinGui || Az=PVhwnd || Az=hGDIwin || Az=hGDIthumbsWin || Az=hGDIinfosWin) ? 1 : 0
    ; ToolTip, % uz "=" A_ScriptHwnd "=" otherAscriptHwnd , , , 2
    If (uz=PVhwnd || uz=hQPVtoolbar && ShowAdvToolbar=1)
       r := 0
    Return r
}

identifyThisWin() {
  Static prevR, lastInvoked := 1
  If (A_TickCount - lastInvoked < 50)
     Return prevR

  Az := WinActive("A")
  prevR := (Az=PVhwnd || Az=hGDIwin || Az=hGDIthumbsWin || Az=hGDIinfosWin || Az=hGDIselectWin) ? 1 : 0
  lastInvoked := A_TickCount
  Return prevR
}

kbdkeybcallKeysResponder(givenKey, thisWin) {
   Static lastInvoked := 1, counter := 0, prevKey

   If (A_TickCount - lastInvoked>350)
      counter := 0

   If (animGIFplaying=1)
      animGIFplaying := -1

   ; addJournalEntry(A_ThisFunc "(): " thisWin "|" givenKey)
   If (A_TickCount - lastInvoked>50) && (whileLoopExec=0 && runningLongOperation=0)
   {
      lastInvoked := A_TickCount
      abusive := (counter>25) ? 1 : 0
      MainExe.ahkPostFunction("KeyboardResponder", givenKey, thisWin, abusive)
      If (givenKey=prevKey)
         counter++
      Else 
         counter := 0

      prevKey := givenKey
   } Else If (givenKey=prevKey)
      counter++
   Else 
      counter := 0
}

guiCreateMenuFlyout() {
   m := LargeUIfontValue // 2 + 1
   h := LargeUIfontValue * 2 + 1
   Gui, menuFlier: +AlwaysOnTop -MinimizeBox -SysMenu -Caption +ToolWindow
   Gui, menuFlier: Color, %OSDbgrColor%
   Gui, menuFlier: Font, s%LargeUIfontValue% Bold c%OSDtextColor%
   Gui, menuFlier: Margin, 0, 0
   Gui, menuFlier: Add, Text, Border Center +0x200 x0 y0 w%h% h%h% gPanelQuickSearchMenuOptions hwndhBtn1 +TabStop, S
   Gui, menuFlier: Add, Text, Border Center +0x200 x+%m% yp+0 w%h% h%h% gtoggleAppToolbar hwndhBtn2 +TabStop, T
   AddTooltip2Ctrl(hBtn1, "Search through menus [ `; ]",, uiUseDarkMode)
   AddTooltip2Ctrl(hBtn2, "Toggle the toolbar [ F10 ]",, uiUseDarkMode)
   ; AddTooltip2Ctrl("AutoPop", 0.5)
   wasMenuFlierCreated := 1
}

menuFlyoutDisplay(actu, mX, mY, isOkay, darkMode:=0, thisHwnd:=0) {
   lastOtherWinClose := A_TickCount
   uiUseDarkMode := darkMode
   otherAscriptHwnd := thisHwnd
   allowMenuReader := actu
   If (!isOkay && actu="yes")
      Return

   If (wasMenuFlierCreated!=1)
      guiCreateMenuFlyout()

   ; GetPhysicalCursorPos(mX, mY)
   fn := Func("dummyMenuFlyoutDisplay").Bind(actu, mX, mY)
   SetTimer, % fn, -50
}

dummyMenuFlyoutDisplay(actu, mX, mY) {
   If (actu="yes" && allowMenuReader="yes")
   {
      ; GetPhysicalCursorPos(mX, mY)
      menusflyOutVisible := 1
      h := GetMenuWinHwnd(mX, mY, "32768")
      a := h[1]
      If !InStr(h[2], "32768")
      {
          menusflyOutVisible := 0
          Gui, menuFlier: Hide
          Return
      }

      WinGetPos, mX, mY, Width, Height, ahk_id %a%
      ; ToolTip, % z "=" a "=" mY " = " height "=" h , , , 2
      x := mX
      y := mY + Round(Height) + 2
      Gui, menuFlier: Show, AutoSize x%x% y%y% NoActivate
   } Else
   {
      menusflyOutVisible := 0
      Gui, menuFlier: Hide
   }
}

GetMenuWinHwnd(mX, mY, n) {
    ; side note; I know it is dumb but I do not know a better solution
    h := GetWinHwndAtPoint(mX, mY)
    If !InStr(h[2], n) ; menu window class
    {
       h := GetWinHwndAtPoint(mX + 2, mY)
       If !InStr(h[2], n)
       {          
          h := GetWinHwndAtPoint(mX + 2, mY + 2)
          If !InStr(h[2], n)
          {
             h := GetWinHwndAtPoint(mX, mY + 2)
             If !InStr(h[2], n)
             {
                 h := GetWinHwndAtPoint(mX - 2, mY)
                 If !InStr(h[2], n)
                 {
                     h := GetWinHwndAtPoint(mX - 2, mY - 2)
                     If !InStr(h[2], n)
                     {
                        h := GetWinHwndAtPoint(mX, mY - 2)
                        If !InStr(h[2], n)
                        {
                           h := GetWinHwndAtPoint(mX - 2, mY + 2)
                           If !InStr(h[2], n)
                           {
                              h := GetWinHwndAtPoint(mX + 2, mY - 2)
                              If !InStr(h[2], n)
                                 Return
                           }
                        }
                     }
                 }
             }
          }
       }
    }
    Return h
}

GetWinHwndAtPoint(nX, nY) {
    a := DllCall("WindowFromPhysicalPoint", "Uint64", nX|(nY << 32), "Ptr")
    a := Format("{1:#x}", a)
    WinGetClass, h, ahk_id %a%
    Return [a, h]
}

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND := 0x112, TPM_RETURNCMD := 0x100
  turnOffSlideshow()
  MainExe.ahkPostFunction("doSuspendu", 1)
  h := WinExist("ahk_id " hwnd)
  JEE_ClientToScreen(hPicOnGui1, 1, 1, X, Y)
  hSysMenu := DllCall("GetSystemMenu", "Uint", Hwnd, "int", False) 
  r := DllCall("TrackPopupMenu", "uint", hSysMenu, "uint", TPM_RETURNCMD, "int", X, "int", Y, "int", 0, "uint", h, "uint", 0)
  If (r=0)
     Return

  SendMessage, WM_SYSCOMMAND, r,,,ahk_id %Hwnd%
  Return 1
}

stopGiFsPlayback() {
   If (animGIFplaying!=0)
   {
      animGIFplaying := 0
      MainExe.ahkPostFunction("autoChangeDesiredFrame", "stop")
      changeMcursor("normal-extra")
   }
}

turnOffSlideshow() {
   stopGiFsPlayback()
   If (slideShowRunning!=1)
      Return

   slideShowRunning := 0
   SetTimer, theSlideShowCore, Off
   MainExe.ahkPostFunction("dummyInfoToggleSlideShowu", "stop")
   If (slideShowDelay<950)
      SoundBeep , 900, 100
}

BuildFakeMenuBar(modus:=0) {

   ; main menu
   If (modus="freeform" || drawingShapeNow=1)
   {
      kMenu("CANCEL", "byeByeRoutine")
      kMenu("-", "-")
      kMenu("Freeform drawing mode", "dummy")
      Return
   }

   kMenu("MENU", "InitMainContextMenu")
   kMenu("-", "-")

   If (modus="welcome")
   {
      kMenu("OPEN FILE", "OpenDialogFiles")
      kMenu("OPEN FOLDER", "OpenFolders")
      kMenu("RECENTS", "InvokeRecentMenu")
      kMenu("FAVORITES", "invokeFavesMenu")
      kMenu("-", "-")
      kMenu("NEW IMAGE", "PanelNewImage")
      kMenu("ACQUIRE", "AcquireWIAimage")
      kMenu("PASTE CLIPBOARD", "tlbrPasteClipboardIMG")
      Return
   }

   If (imgEditPanelOpened=1)
   {
      kMenu("HIDE PANEL", "toggleImgEditPanelWindow")
      kMenu("-", "-")
      If (AnyWindowOpen=10)
         kMenu("APPLY TO SELECTION", "ApplyColorAdjustsSelectedArea")
      Else
         kMenu("APPLY", "applyIMGeditFunction")

      If (AnyWindowOpen=10)
         kMenu("CLOSE", "tlbrCloseWindow")
      Else
         kMenu("CANCEL", "tlbrCloseWindow")

      kMenu("-", "-")
      kMenu("UNDO", "ImgUndoAction")
      kMenu("REDO", "ImgRedoAction")
      kMenu("-", "-")
      If (AnyWindowOpen=10)
         kMenu("SELECT", "ToggleEditImgSelection")
      ; Else
      ;    kMenu("SELECT ALL", "MenuSelectAllAction")
      kMenu("SQUARE", "makeSquareSelection")
      kMenu("FLIP", "flipSelectionWH")
      kMenu("IMAGE LIMITS", "toggleLimitSelection")
      kMenu("-", "-")
      If (AnyWindowOpen!=10)
         kMenu("ROTATE 45°", "MenuSelRotation")
      If (AnyWindowOpen=10)
         kMenu("RESET VIEW", "BtnResetImageView")
      Else
         kMenu("RESET", "resetSelectionRotation")
      kMenu("-", "-")
      kMenu("ADAPT IMAGE", "ToggleImageSizingMode")
      If (AnyWindowOpen=10)
         kMenu("TOGGLE FX", "MenuToggleColorAdjustments")
      Else
         kMenu("HIDE OBJECT", "toggleLiveEditObject")
      Return
   }

   isImgEditMode := (thumbsDisplaying!=1 && StrLen(UserMemBMP)>3 && undoLevelsRecorded>1) ? 1 : 0
   infoThumbsMode := (thumbsDisplaying=1) ? "IMAGE VIEW" : "LIST VIEW"
   If (isImgEditMode=1)
      kMenu("NEW", "PanelNewImage")

   kMenu("OPEN", "OpenDialogFiles")
   kMenu("SAVE", "PanelSaveImg")
   If (isImgEditMode=1)
   {
      kMenu("-", "-")
      kMenu("UNDO", "ImgUndoAction")
      kMenu("REDO", "ImgRedoAction")
      kMenu("-", "-")
   } Else
   {
      kMenu("REFRESH", "RefreshImageFileAction")
      kMenu("-", "-")
   }

   kMenu(infoThumbsMode, "MenuDummyToggleThumbsMode")
   kMenu("-", "-")
   kMenu("SELECT", "MenuSelectAction")
   kMenu("ALL/NONE", "MenuSelectAllAction")
   kMenu("-", "-")
   kMenu("COPY", "MenuCopyAction")
   If (thumbsDisplaying!=1)
      kMenu("PASTE", "tlbrPasteClipboardIMG")
   Else
      kMenu("MOVE", "PanelMoveCopyFiles")
   kMenu("ERASE", "deleteKeyAction")
   kMenu("-", "-")

   If (maxFilesIndex>1)
   {
      kMenu("SEARCH", "PanelSearchIndex")
      kMenu("JUMP TO", "PanelJump2index")
   } Else If (thumbsDisplaying!=1)
   {
      kMenu("ACQUIRE", "AcquireWIAimage")
      kMenu("PRINT", "PanelPrintImage")
   }

   kMenu("RESET", "ResetImageView")
   If (thumbsDisplaying=1)
   {
      kMenu("-", "-")
      kMenu("MODES", "toggleListViewModeThumbs")
      kMenu("-", "-")
      kMenu("[ + ]", "changeZoomPlus")
      kMenu("[ - ]", "changeZoomMinus")
      kMenu("-", "-")
   } Else
   {
      kMenu("-", "-")
      If (maxFilesIndex>1 && !isImgEditMode)
         kMenu("PLAY", "dummyInfoToggleSlideShowu")
      kMenu("INFO", "ToggleHistoInfoBoxu")
      kMenu("PREV PANEL", "openPreviousPanel")
   }
}

kMenu(labelu, funcu, mena:="PVmenu", actu:="add") {
   Static menuArray := [], indexu := 2
   If (actu="add")
   {
      If (funcu="-")
         Menu, % mena, % actu
      Else
         Menu, % mena, % actu, % labelu, % funcu

      indexu++
      menuArray[indexu] := labelu
   }
}

dummy() {
   Sleep, -1
}

MenuSelRotation() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

ToggleImageSizingMode() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

BtnResetImageView() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelNewImage() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}


PanelPrintImage() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

OpenFolders() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

AcquireWIAimage() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

invokeFavesMenu() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

InvokeRecentMenu() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

ApplyColorAdjustsSelectedArea() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

applyIMGeditFunction() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

MenuToggleColorAdjustments() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

toggleLiveEditObject() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

tlbrCloseWindow() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction("CloseWindow")
}

makeSquareSelection() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

toggleLimitSelection() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

flipSelectionWH() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

changeZoomMinus() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction("changeZoom", -1)
}

changeZoomPlus() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction("changeZoom", 1)
}

CopyImage2clip() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

CopyImagePath() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

dummyInfoToggleSlideShowu() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelMoveCopyFiles() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

MenuMarkThisFileNow() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

OpenDialogFiles() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelJump2index() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

InvokeCopyFiles() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

deleteKeyAction() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelPasteInPlace() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelSearchIndex() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

tlbrPasteClipboardIMG() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

RefreshFilesList() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

RefreshImageFileAction() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

RegenerateEntireList() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelSaveImg() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelSaveSlideShowu() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

selectAllFiles() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

ResetImageView() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

toggleListViewModeThumbs() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

MenuDummyToggleThumbsMode() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

openPreviousPanel() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

ToggleHistoInfoBoxu() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

ToggleEditImgSelection() {
  If !determineMenuBTNsOKAY()
     Return
  MainExe.ahkPostFunction(A_ThisFunc)
}

selectEntireImage(arg) {
   If !determineMenuBTNsOKAY()
      Return
   MainExe.ahkPostFunction(A_ThisFunc, arg)
}

dropFilesSelection() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

ImgUndoAction() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

ImgRedoAction() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

resetSelectionRotation() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

toggleImgEditPanelWindow() {
  If !determineMenuBTNsOKAY()
     Return

  MainExe.ahkPostFunction(A_ThisFunc)
}

deleteMenus() {
    Static menusList := "PVmenu|"
    Loop, Parse, menusList, |
        Try Menu, % A_LoopField, Delete
}

UpdateMenuBar(modus:=0) {
   Static hasRan := 0, prevState
   If !hasRan
   {
      Menu, PVmanu, Add, MENU, dummy
      hasRan := 1
   }

   thisState := "a" imgEditPanelOpened AnyWindowOpen thumbsDisplaying maxFilesIndex drawingShapeNow modus UserMemBMP undoLevelsRecorded showMainMenuBar
   If !showMainMenuBar
      prevState := thisState

   ; ToolTip, % thisState "`n" prevState , , , 2
   If (prevState=thisState)
      Return

   ; ToolTip, % "l = " modus , , , 2
   If (thumbsDisplaying=1)
      UpdateUiStatusBar(0, 0, "list", 0)
   Else 
      updateUIctrl()

   lastMenuBarUpdate := A_TickCount
   Gui, 1: Menu, PVmanu
   ; kMenu("-", "-", "PVmenu", "delete")

   deleteMenus()
   If (showMainMenuBar!=1)
   {
      Sleep, -1
      Gui, 1: Menu
      Return
   }

   Sleep, -1
   BuildFakeMenuBar(modus)
   ; SetMenuInfo(MenuGetHandle("PVmenu"), 2, 1, 0, 1)
   Sleep, -1
   Gui, 1: Menu, PVmanu
   Gui, 1: Menu, PVmenu
   lastMenuBarUpdate := A_TickCount
   prevState := thisState
}

SetMenuInfo(hMenu, maxHeight:=0, autoDismiss:=0, modeLess:=0, noCheck:=0) {
   cbSize := (A_PtrSize=8) ? 40 : 28
   VarSetCapacity(MENUINFO, cbSize)
   fMaskFlags := 0x80000000         ; MIM_APPLYTOSUBMENUS
   cyMax := maxHeight ? maxHeight : 0
   If maxHeight
      fMaskFlags |= 0x00000001      ; MIM_MAXHEIGHT

   If (autoDismiss=1 || modeLess=1 || noCheck=1)
      fMaskFlags |= 0x00000010      ; MIM_STYLE

   dwStyle := 0
   If (autoDismiss=1)
      dwStyle |= 0x10000000         ; MNS_AUTODISMISS

   If (modeLess=1)
      dwStyle |= 0x40000000         ; MNS_MODELESS

   If (noCheck=1)
      dwStyle |= 0x80000000         ; MNS_NOCHECK

   NumPut(cbSize, MENUINFO, 0, "UInt") ; DWORD
   NumPut(fMaskFlags, MENUINFO, 4, "UInt") ; DWORD
   NumPut(dwStyle, MENUINFO, 8, "UInt") ; DWORD
   NumPut(cyMax, MENUINFO, 12, "UInt") ; UINT
   ; NumPut(hbrBack, MENUINFO, 16, "Ptr") ; HBRUSH
   ; NumPut(dwContextHelpID, MENUINFO, 20, "UInt") ; DWORD
   ; NumPut(dwMenuData, MENUINFO, 24, "UPtr") ; ULONG_PTR

   Return DllCall("User32\SetMenuInfo","Ptr", hMenu, "Ptr", &MENUINFO)
}


determineMenuBTNsOKAY() {
   If (imageLoading=1 || runningLongOperation=1) || (AnyWindowOpen && imgEditPanelOpened!=1)
      Return 0
   Else
      Return 1
}

MenuCopyAction() {
   If !determineMenuBTNsOKAY()
      Return

   MainExe.ahkPostFunction(A_ThisFunc)
}

MenuSelectAction() {
   If !determineMenuBTNsOKAY()
      Return

   MainExe.ahkPostFunction(A_ThisFunc)
}

MenuSelectAllAction() {
   Static prevState := 0
   If !determineMenuBTNsOKAY()
      Return

   If (thumbsDisplaying=1)
   {
      If prevState
         dropFilesSelection()
      Else
         selectAllFiles()
      prevState := !prevState
   } Else selectEntireImage("rm")
}

TulTip(debugger, sep, params*) {
    str := ""
    For index,param in params
        str .= "[" A_Index "]" param . sep

    Random, OutputVar, -220, 200
    ; ToolTip, [ Text, X, Y, WhichToolTip]
    ToolTip, % OutputVar "===" str , ,, 3
}

KeyboardResponder(givenKey, abusive) {
    ; ToolTip, % givenKey "=" abusive "=" animGIFplaying , , , 2
    If (givenKey="Left" || givenKey="Right" || givenKey="Up" || givenKey="Down" || givenKey="PgUp" || givenKey="PgDn" || givenKey="Home" || givenKey="End" || givenKey="BackSpace" || givenKey="Delete" || givenKey="Enter")
    {
       If (slideShowRunning=1)
       {
          turnOffSlideshow()
       } Else If (animGIFplaying!=0 || canCancelImageLoad=1) || (thumbsDisplaying=1 && imageLoading=1)
       {
          alterFilesIndex++
          canCancelImageLoad := 4
          If (givenKey!="PLUS" && givenKey!="MINUS")   ; plus/minus
             stopGiFsPlayback()

       } Else callMain := 1
    } Else If (givenKey="Escape" || givenKey="!F4")
    {
       canCancelImageLoad := 4
       If (AnyWindowOpen || animGIFplaying=1 || slideShowRunning=1)
          lastOtherWinClose := A_TickCount
       byeByeRoutine()
    } Else If (givenKey="!Space")
    {
       Win_ShowSysMenu(PVhwnd)
    } Else If (givenKey="Space")
    {
       isOkay := AnyWindowOpen ? 0 : 1
       If (AnyWindowOpen && imgEditPanelOpened=1)
          isOkay := 1

       stopGiFsPlayback()
       If (slideShowRunning=1)
          turnOffSlideshow()
       Else If (thumbsDisplaying!=1 && isOkay && maxFilesIndex>0 && slideShowRunning!=1 && IMGresizingMode=4)
          changeMcursor("move")
       Else callMain := 1
    } Else callMain := 1

    isOkay := (imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    If (callMain=1 && isOkay=1 && runningLongOperation!=1 && whileLoopExec!=1 && givenKey)
    {
       ; addJournalEntry(A_ThisFunc "(): " WinActive("A") "==" givenKey)
       MainExe.ahkPostFunction("KeyboardResponder", givenKey, PVhwnd, abusive)
    }
}

PreProcessKbdKey() {
   Static lastInvoked := 1, counter := 0, prevKey
   If (!identifyThisWin() || (A_TickCount - lastOtherWinClose<300))
      Return

   ; ToolTip, % hotkate , , , 2
   If (A_TickCount - lastInvoked>250)
      counter := 0

   ; addJournalEntry(A_ThisFunc "(): " thisWin "|" hotkate)
   If (A_TickCount - lastInvoked>30) && (whileLoopExec=0 && runningLongOperation=0)
   {
      lastInvoked := A_TickCount
      abusive := (counter>25) ? 1 : 0
      KeyboardResponder(hotkate, abusive)
      ; MainExe.ahkPostFunction("KeyboardResponder", hotkate, PVhwnd, abusive)
      If (hotkate=prevKey)
         counter++
      Else 
         counter := 0

      prevKey := hotkate
   } Else If (hotkate=prevKey)
      counter++
   Else 
      counter := 0
}

constructKbdKey(vk_shift, vk_ctrl, vk_alt, vk_code) {
   Static vkList := {8:"BACKSPACE", 9:"TAB", C:"NUMPADCLEAR", D:"ENTER", 14:"CAPSLOCK", 1B:"ESCAPE", 20:"SPACE", 21:"PGUP", 22:"PGDN", 23:"END", 24:"HOME", 25:"LEFT", 26:"UP", 27:"RIGHT", 28:"DOWN", 2D:"INSERT", 2E:"DELETE", 5B:"SCROLLLOCK", 5D:"APPSKEY", 60:"NUMPAD0", 61:"NUMPAD1", 62:"NUMPAD2", 63:"NUMPAD3", 64:"NUMPAD4", 65:"NUMPAD5", 66:"NUMPAD6", 67:"NUMPAD7", 68:"NUMPAD8", 69:"NUMPAD9", 6A:"NUMPADMULT", 6B:"NUMPADADD", 6D:"NUMPADSUB", 6E:"NUMPADDOT", 6F:"NUMPADDIV", 70:"F1", 71:"F2", 72:"F3", 73:"F4", 74:"F5", 75:"F6", 76:"F7", 77:"F8", 78:"F9", 79:"F10", 7A:"F11", 7B:"F12", 90:"NUMLOCK", AD:"VOLUME_MUTE", AE:"VOLUME_DOWN", AF:"VOLUME_UP", B0:"MEDIA_NEXT", B1:"MEDIA_PREV", B2:"MEDIA_STOP", B3:"MEDIA_PLAY_PAUSE", FF:"PAUSE", 1:"LBUTTON", 2:"RBUTTON", 3:"BREAK", 4:"MBUTTON", 5:"XBUTTON1", 6:"XBUTTON2", 10:"SHIFT", 11:"CONTROL", 12:"ALT", 13:"PAUSE", 15:"KANA/HANGUL", 17:"JUNJA", 18:"IME_FINAL", 19:"HANJA/KANJI", 16:"IME_ON", 1A:"IME_OFF", 1C:"IME_CONVERT", 1D:"IME_NON_CONVERT", E5:"IME_PROCESSKEY", 1E:"IME_ACCEPT", 1F:"IME_MODECHANGE", 2F:"HELP", 29:"SELECT", 2A:"PRINT", 2B:"EXECUTE", 2C:"PRINT_SCREEN", 5F:"SLEEP", 7C:"F13", 7D:"F14", 7E:"F15", 7F:"F16", 80:"F17", 81:"F18", 82:"F19", 83:"F20", 84:"F21", 85:"F22", 86:"F23", 87:"F24", A6:"BROWSER_BACK", A7:"BROWSER_FORWARD", A8:"BROWSER_REFRESH", A9:"BROWSER_STOP", AA:"BROWSER_SEARCH", AB:"BROWSER_FAVORITES", AC:"BROWSER_HOME", B4:"LAUNCH_MAIL", B5:"LAUNCH_MEDIA_SELECT", B6:"LAUNCH_APP1", B7:"LAUNCH_APP2", F6:"ATTN", F7:"CrSEL", F8:"ExSEL", F9:"ERASE_EOF", FA:"PLAY", FB:"ZOOM", FD:"PA1", A0:"LSHIFT", A1:"RSHIFT", A2:"LCTRL", A3:"RCTRL", A4:"LALT", A5:"RALT", 5B:"LWIN", 5C:"RWIN"}
        , vkExtraList := {30:"00.1", 31:"1", 32:"2", 33:"3", 34:"4", 35:"5", 36:"6", 37:"7", 38:"8", 39:"9", 41:"A", 42:"B", 43:"C", 44:"D", 45:"E", 46:"F", 47:"G", 48:"H", 49:"I", 4A:"J", 4B:"K", 4C:"L", 4D:"M", 4E:"N", 4F:"O", 50:"P", 51:"Q", 52:"R", 53:"S", 54:"T", 55:"U", 56:"V", 57:"W", 58:"X", 59:"Y", 5A:"Z", BB:"PLUS", BC:"COMMA", BD:"MINUS", BE:"PERIOD"}
        ; , BA:"OEM_1", BF:"OEM_2", C0:"OEM_3", DB:"OEM_4", DC:"OEM_5", DD:"OEM_6", DE:"OEM_7", DF:"OEM_8", E2:"OEM_102", E1:"OEM_9", E3:"OEM_11", E4:"OEM_12", E6:"OEM_13", FE:"OEM_CLEAR", 92:"OEM_14", 93:"OEM_15", 94:"OEM_16", 95:"OEM_17", 96:"OEM_18"}
   ; vk list based on https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

   newkate := ""
   If vk_shift
      newkate .= "+"
   If vk_ctrl
      newkate .= "^"
   If vk_alt
      newkate .= "!"
   If (vkExtraList[vk_code]!="")
      newkate .= vkExtraList[vk_code]
   Else
      newkate .= vkList[vk_code] ? vkList[vk_code] : "vk" vk_code
   Return newkate
}

WM_KEYDOWN(wParam, lParam, msg, hwnd) {
    vk_code := Format("{1:x}", wParam)
    If (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) && (vk_code!="1B")
    || (A_TickCount - lastOtherWinClose<300)
       Return 0

    vk_shift := DllCall("GetKeyState","Int", 0x10, "short") >> 16
    vk_ctrl := DllCall("GetKeyState","Int", 0x11, "short") >> 16
    vk_alt := (msg=260) ? -1 : DllCall("GetKeyState","Int", 0x12, "short") >> 16
    hotkate := constructKbdKey(vk_shift, vk_ctrl, vk_alt, vk_code)
    If (vk_code!=10 && vk_code!=11 && vk_code!=12)
    {
       SetTimer, PreProcessKbdKey, -3
       Return 0
    }
    ; TulTip(0, "|   ", wParam, vk_shift, vk_ctrl, vk_alt, msg, "ui thread")
}

SendMenuTabKey() {
   Static prevState := 0
   prevState := !prevState
   keyu := prevState ? "{Right}" : "{Left}"
   SendInput, % keyu
}

#If, (allowMenuReader="yes")
   ~RButton::
      constantMenuReader()
   Return

   ~WheelDown::
   ~PgDn::
      SendInput, {Down 3}
   Return

   ~WheelUp::
   ~PgUp::
      SendInput, {Up 3}
   Return

   ~Space::
      SendInput, {Enter}
   Return

   ~BackSpace::
      SendInput, {Left}
   Return

   F1::
      If (!AnyWindowOpen && drawingShapeNow!=1)
      {
         SendInput, {F10}
         MainExe.ahkPostFunction("HelpWindow")
      }
   Return

   F10::
      If (menusflyOutVisible=1 || drawingShapeNow=1)
      {
         SendInput, {F10}
         toggleAppToolbar()
      }
   Return

   vkBA::
      If (menusflyOutVisible=1)
      {
         SendInput, {F10}
         PanelQuickSearchMenuOptions()
      }
   Return

   ~Tab::
      SendMenuTabKey()
   Return
#If

GetPhysicalCursorPos(ByRef mX, ByRef mY) {
; function from: https://github.com/jNizM/AHK_DllCall_WinAPI/blob/master/src/Cursor%20Functions/GetPhysicalCursorPos.ahk
; by jNizM, modified by Marius Șucan
    Static lastMx, lastMy, lastInvoked := 1
    If (A_TickCount - lastInvoked<70)
    {
       mX := lastMx
       mY := lastMy
       Return
    }

    lastInvoked := A_TickCount
    Static POINT
         , init := VarSetCapacity(POINT, 8, 0) && NumPut(8, POINT, "Int")
    If !isWinXP
       GPC := DllCall("user32.dll\GetPhysicalCursorPos", "Ptr", &POINT)

    If (!GPC || isWinXP=1)
    {
       MouseGetPos, mX, mY
       lastMx := mX
       lastMy := mY
       Return
     ; Return DllCall("kernel32.dll\GetLastError")
    }

    lastMx := mX := NumGet(POINT, 0, "Int")
    lastMy := mY := NumGet(POINT, 4, "Int")
    Return
}

calcScreenLimits(whichHwnd:="main") {
    Static lastInvoked := 1, prevHwnd, prevActiveMon := []

    ; the function calculates screen boundaries for the user given X/Y position for the OSD
    If (A_TickCount - lastInvoked<350) && (prevHwnd=whichHwnd)
       Return prevActiveMon

    whichHwnd := (whichHwnd="main") ? PVhwnd : whichHwnd
    If (whichHwnd="mouse")
    {
       MouseGetPos, OutputVarX, OutputVarY
       GetPhysicalCursorPos(mainX, mainY)
       If !mainX
          mainX := OutputVarX
       If !mainY
          mainY := OutputVarY
       hMon := MDMF_FromPoint(mainX, mainY, 2)
    } Else 
    {
       hMon := MDMF_FromHWND(whichHwnd, 2)
       WinGetPos, mainX, mainY,, , ahk_id %whichHwnd%
    }

    If hMon
       MonitorInfos := MDMF_GetInfo(hMon)

    If !IsObject(MonitorInfos)
    {
       ActiveMon := MWAGetMonitorMouseIsIn(mainX, mainY)
       If !ActiveMon
       {
          ActiveMon := MWAGetMonitorMouseIsIn()
          If !ActiveMon
             Return prevActiveMon
       }
       SysGet, mCoord, MonitorWorkArea, %ActiveMon%
       prevActiveMon.mCRight := mCoordRight, prevActiveMon.mCLeft := mCoordLeft
       prevActiveMon.mCTop := mCoordTop, prevActiveMon.mCBottom := mCoordBottom
    } Else
    {
       ActiveMon := MonitorInfos.Num
       mCoordRight := MonitorInfos.WARight, mCoordLeft := MonitorInfos.WALeft
       mCoordTop := MonitorInfos.WATop, mCoordBottom := MonitorInfos.WABottom
       prevActiveMon.mCRight := MonitorInfos.WARight, prevActiveMon.mCLeft := MonitorInfos.WALeft
       prevActiveMon.mCTop := MonitorInfos.WATop, prevActiveMon.mCBottom := MonitorInfos.WABottom
    }

    prevActiveMon.w := ResolutionWidth := Abs(max(mCoordRight, mCoordLeft) - min(mCoordRight, mCoordLeft))
    prevActiveMon.h := ResolutionHeight := Abs(max(mCoordTop, mCoordBottom) - min(mCoordTop, mCoordBottom)) 
    If !ResolutionWidth
       prevActiveMon.w := ResolutionWidth := 800
    If !ResolutionHeight
       prevActiveMon.h := ResolutionHeight := 600

    prevActiveMon.m := ActiveMon
    prevActiveMon.hMon := hMon
    lastInvoked := A_TickCount
    prevHwnd := whichHwnd
    ; ToolTip, % ActiveMon "`n" pActiveMon "`n" hMon , , , 2
    Return prevActiveMon
}

constantMenuReader(modus:=0) {
   Static prevLabel := "z"
   GetPhysicalCursorPos(x, y)
   ; winID := WinActive("A")
   Try MouseGetPos, ,, WinID
   ; ToolTip, % winID "`n" OutputVarWin , , , 2
   If (modus="focused")
      AccAccFocus(OutputVarWin, accFocusName, accFocusValue, accRole, accIRole)
   Else
      AccInfoUnderMouse(x, y, winID, accFocusValue, accFocusName, accIRole, accRole, styleu, strstyles, shortcut)

   goodText := accFocusValue ? accFocusValue : accFocusName
   goodRoles := (accIRole=41 || accIRole=42 || accIRole=46) ? 1 : 0
   If (accIRole=12 && accFocusName && (prevLabel!=accFocusName || mouseToolTipWinCreated!=1))
   {
      prevLabel := accFocusName
      msgu := StrReplace(accFocusName, "`t", "`n[ ")
      If InStr(accFocusName, "`t")
         msgu .= " ]"

      If InStr(strstyles, "0x00000001")
         msgu .= "`nITEM DISABLED"
      Else If shortcut
         msgu := "&" Format("{:U}", shortcut) ": " msgu

      If InStr(strstyles, "0x00000010")
         msgu .= InStr(msgu, "item disabled") ? "AND CHECKED" : "`nITEM CHECKED"
      If InStr(strstyles, "0x40000000")
         msgu .= "`nSUBMENU CONTAINER"

      mouseCreateOSDinfoLine(msgu, PrefsLargeFonts)
      ; ToolTip, % accFocusName , , , 2
      ; MainExe.ahkPostFunction("showtooltip", accFocusName)
   }
   SetTimer, repeatMenuInfosPopup, -150
}

repeatMenuInfosPopup() {
   If GetKeyState("RButton", "P")
      constantMenuReader()
}

mouseClickTurnOFFtooltip(mode:=0) {
    mouseTurnOFFtooltip(2)
}

mouseTurnOFFtooltip(mode:=0) {
   Sleep, 10
   If (mouseToolTipWinCreated!=1)
      Return

   Gui, mouseToolTipGuia: Destroy
   ; WinActive("ahk_id" PVhwnd)
   Global mouseToolTipWinCreated := 0
   SetTimer, mouseTurnOFFtooltip, Off
   ; ToolTip, % mode , , , 2
   ; If (AnyWindowOpen && mode!=1 || mode=2)
   ;    SetTimer, delayedWinActivateToolTipDeath, -150
}

delayedWinActivateToolTipDeath() {
   WinActivate, ahk_id %lastTippyWin%
}

mouseCreateOSDinfoLine(msg:=0, largus:=0, unClickable:=0) {
    Critical, On
    Static prevMsg, lastInvoked := 1
    Global TippyMsg

    ; ToolTip, % largus "==" msg , , , 2
    thisHwnd := PVhwnd
    If (StrLen(msg)<3) || (prevMsg=msg && mouseToolTipWinCreated=1) || (A_TickCount - lastInvoked<100) || !thisHwnd
       Return

    lastInvoked := A_TickCount
    Gui, mouseToolTipGuia: Destroy
    thisFntSize := (largus=1) ? Round(LargeUIfontValue*1.55) : LargeUIfontValue
    If (thisFntSize<5)
       thisFntSize := 5
    If (largus>5)
       thisFntSize := largus

    bgrColor := OSDbgrColor
    txtColor := OSDtextColor
    isBold := (FontBolded=1) ? " Bold" : ""
    lastTippyWin := WinActive("A")
    Sleep, 25
    Gui, mouseToolTipGuia: -Caption -DPIScale +Owner%thisHwnd% +ToolWindow +hwndhGuiTip
    Gui, mouseToolTipGuia: Margin, % thisFntSize, % thisFntSize
    Gui, mouseToolTipGuia: Color, c%bgrColor%
    Gui, mouseToolTipGuia: Font, s%thisFntSize% %isBold% Q5, %OSDFontName%
    Gui, mouseToolTipGuia: Add, Text, c%txtColor% gmouseClickTurnOFFtooltip vTippyMsg, %msg%
    Gui, mouseToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, QPVOguiTipsWin
    prevMsg := msg
    MainExe.ahkassign("hGuiTip", hGuiTip)
    If (unClickable=1)
      WinSet, ExStyle, +0x20, ahk_id %hGuiTip%
    mouseToolTipWinCreated := 1
    delayu := StrLen(msg) * 75 + 950
    showOSDinfoLineNow(delayu)
}

showOSDinfoLineNow(delayu) {
    If !mouseToolTipWinCreated
       Return

    GetPhysicalCursorPos(mX, mY)
    If !isWinXP
    {
       GetWinClientSize(Wid, Heig, hGuiTip, 1)
       k := WinMoveZ(hGuiTip, 15, mX, mY, Wid, Heig, 2)
       Final_x := k[1], Final_y := k[2]
    } Else
    {
       tipX := mX + 15
       tipY := mY + 15
       ResWidth := adjustWin2MonLimits(hGuiTip, tipX, tipY, Final_x, Final_y, Wid, Heig)
       MaxWidth := Floor(ResWidth*0.85)
       If (MaxWidth<Wid && MaxWidth>10)
       {
          GuiControl, mouseToolTipGuia: Move, TippyMsg, w1 h1
          GuiControl, mouseToolTipGuia:, TippyMsg,
          Gui, mouseToolTipGuia: Add, Text, xp yp c%txtColor% gmouseClickTurnOFFtooltip w%MaxWidth%, %msg%
          Gui, mouseToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, QPVguiTipsWin
          ResWidth := adjustWin2MonLimits(hGuiTip, tipX, tipY, Final_x, Final_y, Wid, Heig)
       }
    }

    Gui, mouseToolTipGuia: Show, NoActivate AutoSize x%Final_x% y%Final_y%, QPVguiTipsWin
    WinSet, Transparent, 225, ahk_id %hGuiTip%
    If (delayu<msgDisplayTime/2)
       delayu := msgDisplayTime//2 + 1
    WinSet, AlwaysOnTop, On, ahk_id %hGuiTip%
    ; WinSet, ExStyle, +0x20, ahk_id %hGuiTip%
    SetTimer, mouseTurnOFFtooltip, % -delayu
}

adjustWin2MonLimits(winHwnd, winX, winY, ByRef rX, ByRef rY, ByRef Wid, ByRef Heig) {
   GetWinClientSize(Wid, Heig, winHwnd, 1)
   ActiveMon := MWAGetMonitorMouseIsIn(winX, winY)
   If ActiveMon
   {
      SysGet, bCoord, Monitor, %ActiveMon%
      rX := max(bCoordLeft, min(winX, bCoordRight - Wid))
      rY := max(bCoordTop, min(winY, bCoordBottom - Heig*1.2))
      ResWidth := Abs(max(bCoordRight, bCoordLeft) - min(bCoordRight, bCoordLeft))
      ; ResHeight := Abs(max(bCoordTop, bCoordBottom) - min(bCoordTop, bCoordBottom))
   } Else
   {
      rX := winX
      rY := winY
   }

   Return ResWidth
}

ShowClickHalo(mX, mY, BoxW, BoxH, boxMode) {
    Static
    Static lastInvoked := 1
    Critical, On
    If ((A_TickCount - lastInvoked < 100) || !BoxW || !BoxH)
       Return

    lastInvoked := A_TickCount
    If (!mX && !mY)
       GetPhysicalCursorPos(mX, mY)

    If (boxMode=0)
    {
       mX := mX - BoxW//2
       mY := mY - BoxW//2
    }

    Gui, MclickH: Destroy
    Sleep, 30
    Gui, MclickH: +AlwaysOnTop -DPIScale -Caption +ToolWindow +Owner +E0x20 +E0x8000000 +hwndhClickHalo
    Gui, MclickH: Color, 0099FF
    ; Gui, MclickH: Show, NoActivate Hide x%mX% y%mY% w%BoxW% h%BoxH%, WinMouseClick
    ; WinSet, ExStyle, 0x20, WinMouseClick
    Gui, MclickH: Show, NoActivate x%mX% y%mY% w%BoxW% h%BoxH%, ahk_id %hClickHalo%
    If (boxMode=0)
       WinSet, Region, 0-0 W%BoxW% H%BoxH% E, ahk_id %hClickHalo%
    WinSet, Transparent, 128, ahk_id %hClickHalo%
    WinSet, AlwaysOnTop, On, ahk_id %hClickHalo%
    SetTimer, DestroyClickHalo, -300
}

DestroyClickHalo() {
    Gui, MclickH: Destroy
}


























; by helgef 
; https://github.com/HelgeffegleH/taskbarInterface
; #include ../../classes/threadFunc/threadFunc.ahk
class taskbarInterface {
   static hookWindowClose:=true                     ; Use SetWinEventHook to automatically clear the interface when its window is destroyed. 
   static manualClearInterface:=false                  ; Set to false to automatically clear com interface when the last reference to an object derived from the taskbarInterface class is released. call taskbarInterface.clearInterface()
   __new(hwnd,onButtonClickFunction:="",mute:=false){
      this.mute:=mute                              ; By default, errors are thrown. Set mute:=true to suppress exceptions.
      if taskbarInterface.allInterfaces.HasKey(hwnd){
         this.lastError:=Exception("There is already an interface for this window.",-1)
         if mute
            Exit
         else
            throw this.lastError
      }
      this.dim:=this.queryButtonIconSize()            ; this is used by addToImageList.
      taskbarInterface.allInterfaces[hwnd]:=this         ; allInterfaces array is used for routing the callbacks.
      this.hwnd:=hwnd                              ; Handle to the window whose taskbar preview will recieve the buttons
      if !taskbarInterface.init                     ; On first call here, initialise the com object and turn on button messages. (WM_COMMAND)
         taskbarInterface.initInterface()            ; Note, must init com before any interface functions are called.
      this.setButtonCallback(onButtonClickFunction)      
      if taskbarInterface.hookWindowClose
         this.allowHooking:=true
   }
   ; Context: this = "new taskbarInterface(...)"
   ; Note, further down the context switches to this=taskbarInterface, for convenience. The switch is clearly marked.
   ;
   ; User methods.
   ;
   ; Button methods,
   ;   Creates a toolbar with up to seven buttons,
   ;   thee toolbar itself cannot be removed without re-creating the window itself.
   ;
   ;   - in the following n is the button number, n ∈ [1,7]⊂ℤ
   showButton(n){
      ; Show button n
      static THBF_HIDDEN:=0x8
      this.updateThumbButtonFlags(n,0,THBF_HIDDEN)      ; Add flag 0, remove 0x8 (THBF_HIDDEN)
      return this.ThumbBarUpdateButtons(n)            ; Update
   }
   hideButton(n){
      ; Hide button n
      static THBF_HIDDEN:=0x8
      this.updateThumbButtonFlags(n,THBF_HIDDEN,0)      ; Update flag THBF_HIDDEN:=0x8
      return this.ThumbBarUpdateButtons(n)            ; Update
   }
   disableButton(n){
      ; disable button n
      ; The button becomes unclickable and grays out.
      static THBF_DISABLED:=0x1
      this.updateThumbButtonFlags(n,THBF_DISABLED,0)      ; Update flag, add THBF_DISABLED:=0x8
      return this.ThumbBarUpdateButtons(n)            ; Update
   }
   enableButton(n){
      ; reenable button n
      ; the button becomes clickable and regains its
      ; color.
      static THBF_DISABLED:=0x1
      this.updateThumbButtonFlags(n,0,THBF_DISABLED)      ; Update flag, remove THBF_DISABLED:=0x8
      return this.ThumbBarUpdateButtons(n)            ; Update
   }
   setButtonImage(n,nIL){
      ; Set image for button n.
      ; nIL is the index of the image to set in the image list, you can add images to the image list via the addToImageList() method
      
      static THB_BITMAP:=0x1
      this.updateThumbButtonMask(n,THB_BITMAP,0)
      this.setThumbButtoniBitmap(n,nIL)
      this.ThumbBarSetImageList()
      return this.ThumbBarUpdateButtons(n)            ; Update
   }
   addToImageList(bitmap,bitmapIsHandle:=false){
      ; Add bitmaps to the imagelist for the buttons
      ; bitmap, a handle to a bitmap or a path to an image, or and object on the form: [path,iconNumber], eg, bitmap:=[shell32.dll, 37]. Path is relative to script directory if not full.
      ; specify bitmapIsHandle:=true if bitmap is a handle to a bitmap.
      ; Returns the added images index in the imagelist. The first image has index 1, second 2 and so on...
      ; When specifying a handle, call queryButtonIconSize() to obtain the required size of the bitmap. See queryButtonIconSize() below.
      local file, iconNumber,hBmp, index
      if !this.hImageList
         this.hImageList:=IL_Create(7,1)
      if bitmapIsHandle {
         index:=IL_Add(this.hImageList,"hBitmap:" . bitmap)
      } else {
         if IsObject(bitmap)
            file:=bitmap[1], iconNumber:="Icon" . bitmap[2]
         else
            file:=bitmap, iconNumber:=""
         hBmp:=LoadPicture(file, iconNumber . " Gdi+ w" this.dim.w  " h" this.dim.h)
         if !hBmp {
            this.lastError:=Exception("Invalid file name")
            if this.mute
               return this.lastError
            else
               throw this.lastError
         }
         index:=IL_Add(this.hImageList, "hBitmap:" . hBmp)
      }
      return index
   }
   destroyImageList(){
      ; Destroys the image list for the button images.
      ; return 1 on success, throws exception or returns exception on failure (depends on mute), returns blank if no imagelist exists.
      if (this.hImageList && IL_Destroy(this.hImageList)) {
         this.hImageList:=""
         return 1
      } else if this.hImageList {
         this.lastError:=Exception("ImageList destroy failed.") 
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      return
   }
   setButtonIcon(n,hIcon){
      ; Set button icon for button n
      ; Call queryButtonIconSize() to obtain the required size of the icon. See queryButtonIconSize() below.
      static THB_ICON:=0x2               
      this.updateThumbButtonMask(n,THB_ICON,0)         ; Update mask THB_ICON
      this.setThumbButtonhIcon(n,hIcon)               ; Set the icon handle
      return this.ThumbBarUpdateButtons(n)            ; Update
   }
   queryButtonIconSize(){   ; Moved here for convenience
      ; Returns the required pixel width and height for the button icons.
      ; Example:
      ; sz:=taskbarInterface.queryButtonIconSize()
      ; Msgbox, % "The icon width must be: " sz.w  "`nThe icon height must be: " sz.h
      local SM_CXICON,SM_CYICON
      SysGet, SM_CXICON, 11
      SysGet, SM_CYICON, 12
      return {w:SM_CXICON, h:SM_CYICON}
   }
   setButtonToolTip(n,text:=""){
      ; Sets the tooltip for button n, that is shown when the
      ; mouse cursors hover over the button for a few seconds.
      ; Omit text to remove tooltip.
      static THB_TOOLTIP:=0x4
      if (text!="")
         this.updateThumbButtonMask(n,THB_TOOLTIP,0)      ; Update mask THB_TOOLTIP, add
      this.setThumbButtonToolTipText(n,text)            ; Update the text
      this.ThumbBarUpdateButtons(n)                  ; Update the buttons
      if (text="")
         this.updateThumbButtonMask(n,0,THB_TOOLTIP)      ; Update mask THB_TOOLTIP, remove
      return 
   }
   dismissPreviewOnButtonClick(n,dismiss:=true){   
        ; Call with dismiss:=true to make button  n's  click
        ; to  cause  the thumbnail preview to be dismissed
        ; (close). To show again, hover mouse on taskbar icon.
        ; Call with  dismiss:=false  to  invoke  the  default
      ; behaviour, i.e, no dismiss on click.
      static THBF_DISMISSONCLICK  := 0x2
      if dismiss
         this.updateThumbButtonFlags(n,THBF_DISMISSONCLICK,0)      ; Update flag, add THBF_DISMISSONCLICK:=0x2
      else
         this.updateThumbButtonFlags(n,0,THBF_DISMISSONCLICK)      ; Update flag, remove THBF_DISMISSONCLICK:=0x2
      return this.ThumbBarUpdateButtons(n)                     ; Update
   }
   removeButtonBackground(n){
      ; Remove the background (and/or border) of button n.
      ; The button has a background by default
      static THBF_NOBACKGROUND  := 0x4
      this.updateThumbButtonFlags(n,THBF_NOBACKGROUND,0)            ; Update flag, add THBF_NOBACKGROUND:=0x4
      return this.ThumbBarUpdateButtons(n)                     ; Update
   }
   reAddButtonBackground(n){
      ; Readd the background (and/or) border of button n.
      ; Only needed to call if removeButtonBackground(n) was
      ; previously called
      static THBF_NOBACKGROUND  := 0x4
      this.updateThumbButtonFlags(n,0,THBF_NOBACKGROUND)            ; Update flag, remove THBF_NOBACKGROUND:=0x4
      return this.ThumbBarUpdateButtons(n)                     ; Update
   }
   setButtonNonInteractive(n){
      ; Set button n to be non-interactive,
      ; similar to disableButton(n), but the button doesn't gray out.
      static THBF_NONINTERACTIVE  := 0x10
      this.updateThumbButtonFlags(n,THBF_NONINTERACTIVE,0)         ; Update flag, add THBF_NONINTERACTIVE:=0x10
      return this.ThumbBarUpdateButtons(n)                     ; Update
   }
   setButtonInteractive(n){
      ; Set button n to be interactive again.
      static THBF_NONINTERACTIVE  := 0x10
      this.updateThumbButtonFlags(n,0,THBF_NONINTERACTIVE)         ; Update flag, remove THBF_NONINTERACTIVE:=0x10
      return this.ThumbBarUpdateButtons(n)                     ; Update
   }
   ;
   ; End Button methods
   ;
   
   ; Misc interface methods:
   setTaskbarIcon(smallIconHandle,bigIconHandle:=""){
      ; Url:
      ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/ms632643(v=vs.85).aspx (WM_SETICON message)
      ;   Associates a new large or small icon with a window. The system displays the large icon in the ALT+TAB dialog box, and the small icon in the window caption.
      static:=WM_SETICON:=0x80,ICON_SMALL:=0,ICON_BIG:=1
      if !bigIconHandle
         bigIconHandle:=smallIconHandle
      this.smallIconHandle:=smallIconHandle
      this.bigIconHandle:=bigIconHandle
      this.PostMessage(this.hWnd,WM_SETICON,ICON_SMALL,smallIconHandle)
      this.PostMessage(this.hWnd,WM_SETICON,ICON_BIG,bigIconHandle)
      return
   }
   ; setProgress - The underlying function is called SetProgressValue, but
   ;   I think the word Type is more descriptive of its function.
   ; Displays or updates a progress bar hosted in  a  taskbar  button  to  show  the
   ; specific percentage completed of the full operation.
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391698(v=vs.85).aspx (ITaskbarList3::SetProgressValue method)
   setProgress(value:=0){
      ; value in range (0,100)
      this.progressValue:=value
      if !this.flashTimer
         this.preFlashSettings[1]:=value
      return this.SetProgressValue(value)
   }

   ; SetProgressType(type) - The underlying function is called SetProgressState, but
   ;   I think the word Type is more descriptive of its function.
   ; 
   ; Sets the type and state of the progress indicator displayed on a taskbar button.
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391697(v=vs.85).aspx (ITaskbarList3::SetProgressState)
   ; HWND    hwnd,
   ; TBPFLAG tbpFlags
   ; Flags that control the current state of the progress button. Specify  only  one
   ; of the following flags; all states are mutually exclusive of all others.
   ;
   ; TBPF_NOPROGRESS (0x00000000)
   ;    Stops displaying progress and returns the button to its normal state. Call this
   ;    method with this flag to dismiss  the  progress  bar  when  the  operation  is
   ;    complete or canceled.

   ; TBPF_INDETERMINATE (0x00000001)
   ;   The progress indicator does not grow in size, but cycles repeatedly  along  the
   ;   length  of the taskbar button. This indicates activity without specifying what
   ;   proportion of the progress is complete. Progress is taking place, but there is
   ;   no prediction as to how long the operation will take.

   ; TBPF_NORMAL (0x00000002)
   ;   The progress indicator grows in size from left to right in  proportion  to  the
   ;    estimated  amount  of  the operation completed. This is a determinate progress
   ;   indicator; a prediction is being made as to the duration of the operation.

   ; TBPF_ERROR (0x00000004)
   ;    The progress indicator turns red to show that an error has occurred in  one  of
   ;    the windows that is broadcasting progress. This is a determinate state. If the
   ;    progress  indicator  is  in  the  indeterminate  state,  it  switches to a red
   ;    determinate display of a generic percentage not indicative of actual progress.

   ; TBPF_PAUSED (0x00000008)
   ;   The progress indicator turns yellow to show that progress is currently  stopped
   ;   in  one  of  the  windows  but  can be resumed by the user. No error condition
   ;    exists and nothing is preventing the  progress  from  continuing.  This  is  a
   ;    determinate state. If the progress indicator is in the indeterminate state, it
   ;    switches  to  a  yellow  determinate  display  of  a  generic  percentage  not
   ;    indicative of actual progress.

   SetProgressType(type:="Normal"){
      static dictionary:={Off:0,INDETERMINATE:1,Normal:2, Green:2, Error:4, Red:4,Paused:8,Pause:8,Yellow:8}
      local p
      this.progressType:= (p:=dictionary[type]) ? p : 0
      if !this.flashTimer
         this.preFlashSettings[2]:=type
      return this.setProgressState()
   }
   preFlashSettings:=[] ; For restoring taskbar progress / color after flash
   flashTaskbarIcon(color:="off", nFlashes:=5, flashTime:=250, offTime:=250){
      ; Flash the background of the taskbar icon by setting it to progress 100 for  flashTime  ms  every
      ;  offTime  ms, nFlashes times. Valid colors are green,red,yellow. (translates to
      ;  normal, error, paused progresstype)
      ; Uses a timer to let script run "in parallel"
      this.stopTimer()                   ; Stop any currently running timer.
      this.flashParams:=[color, nFlashes, flashTime, offTime]
      if (color="Off" || color="")
         return
      this.flashesRemaining:=nFlashes
      this.flashOn(color,flashTime,offTime)
      return
   }
   setTaskbarIconColor(color:="off"){
      ; Set the background color of the taskbar icon (sets progress to 100 with appropriate progressState)
      ; Color, "green", "yellow" or "red"
      this.SetProgressType(color)
      if (color!="off" || color="")
         this.setProgress(100)
      return
   }
   ; setThumbnailToolTip(text)
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391702(v=vs.85).aspx (ITaskbarList3::SetThumbnailTooltip method)
   ; Specifies or updates the text of the tooltip that is displayed when  the  mouse
   ; pointer rests on an individual preview thumbnail in a taskbar button flyout.

   ; Input:
   ; Text, string specifying the new text to show as tooltip when 
   ; mouse cursor hovers the thumbnail preview in the taskbar
   ; Specify an empty strin, text:="" to remove the tooltip.
   setThumbnailToolTip(text:=""){
      this.tooltipText:=text
      return this._setThumbnailToolTip()
   }
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391696(v=vs.85).aspx (ITaskbarList3::SetOverlayIcon method)
   ; HWND    hwnd,
   ; HICON   hIcon,         (opt)
   ; LPCWSTR pszDescription   (opt)
   ; Notes:
   ;   - To display an overlay icon, the taskbar must be  in  the  default  large
   ;       icon  mode. If the taskbar is configured through Taskbar and Start Menu
   ;       Properties to show small icons, overlays cannot be applied and calls to
   ;       this method are ignored.
   ;    - The handle of an icon to use as the overlay. This  should  be  a  small  icon,
   ;        measuring  16x16  pixels  at 96 dpi. If an overlay icon is already applied to
   ;        the taskbar button, that existing overlay is replaced.
   ;
   ;   Omit the handle paramter to remove the icon. 
   ;
   ;   To use a bitmap as the overlay icon, you can use LoadPictureType to load a bitmap as an icon, see https://github.com/HelgeffegleH/LoadPictureType
   setOverlayIcon(hIcon:=0,text:=""){
      this.overlayIconHandle:=hIcon, this.overlayIconDescription:=text
      return this._SetOverlayIcon()
   }
   ; setThumbnailClip()
   ; Selects a portion of a window's client area to display as that window's thumbnail in the taskbar
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391701(v=vs.85).aspx (ITaskbarList3::SetThumbnailClip method)
   ; rect:
   ; The RECT structure defines the coordinates of the upper-left and lower-right corners of a rectangle
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd162897(v=vs.85).aspx (RECT structure)
   ; LONG left;
   ; LONG top;
   ; LONG right;
   ; LONG bottom;
   ; Input
   ; left       (x1)
   ;   - The x-coordinate of the upper-left corner of the rectangle.
   ; top        (y1)
   ;   - The y-coordinate of the upper-left corner of the rectangle.
   ; right      (x2)
   ;    - The x-coordinate of the lower-right corner of the rectangle.
   ; bottom   (y2)
   ;   - The y-coordinate of the lower-right corner of the rectangle.
   ; Call without any parameters to reset to default
   setThumbnailClip(left:="",top:="",right:="",bottom:=""){
      local rect
      if (left="" || top="" || right="" || bottom=""){
         this.thumbnailClipRect:=""
         return this._setThumbnailClip(0)
      }
      this.thumbnailClipRect:=[left,top,right,bottom] ; For restoring
      VarSetCapacity(rect,16,0)
      Numput(left,rect,0,"Int") , Numput(top,rect,4,"Int")
      Numput(right,rect,8,"Int"),   Numput(bottom,rect,12,"Int")
      return this._setThumbnailClip(&rect)
   }
   static nCustomPreviews:=0      ; Number of custom thumbnail previews enabled. Used for tracking when to turn on / off message handling.
   static nCustomPeekPreviews:=0   ; Number of custom peek previews enabled. Used for tracking when to turn on / off message handling.

   disableCustomThumbnailPreview(){
      static WM_DWMSENDICONICTHUMBNAIL:=0x323
      local tf
      if (!this.CustomThumbnailPreviewEnabled || !taskbarInterface.nCustomPreviews)
         return
      if (tf:=this.invalidateThumbTimerFn){
         SetTimer, % tf, Delete
         this.invalidateThumbTimerFn:=""
      }
      taskbarInterface.nCustomPreviews--
      if !taskbarInterface.nCustomPreviews                                          ; Turn off message handler when the last custom preview has been disabled
         OnMessage(WM_DWMSENDICONICTHUMBNAIL,taskbarInterface.WM_DWMSENDICONICTHUMBNAILfn,0), taskbarInterface.WM_DWMSENDICONICTHUMBNAILfn:=""
      this.CustomThumbnailPreviewEnabled:=0
      this.bitmapFunc:=""
      if !this.CustomPeekPreviewEnabled {
         this.Dwm_SetWindowAttributeHasIconicBitmap(this.hwnd,0)                           ; Restores the default preview, provided by the OS.
         this.Dwm_SetWindowAttributeForceIconicRepresentaion(this.hwnd,0)
      }
      this.freeThumbnailPreviewBMP() ; Conditionally
      return
   }

   disallowPeek(){   ; See dwm lib for details (Dwm_SetWindowAttributeDisallowPeek)
      return this.Dwm_SetWindowAttributeDisallowPeek(this.hwnd,true)                           ; Disallow peek if no custom peekpreview
   }
   allowPeek(){   ; See dwm lib for details (Dwm_SetWindowAttributeDisallowPeek)
      return this.Dwm_SetWindowAttributeDisallowPeek(this.hwnd,false)                           ; Do not disallow peek.
   }
   excludeFromPeek(){  ; See dwm lib for details (Dwm_SetWindowAttributeExcludeFromPeek)
      return this.Dwm_SetWindowAttributeExcludeFromPeek(this.hwnd,true)
   }
   unexcludeFromPeek(){ ; See dwm lib for details (Dwm_SetWindowAttributeExcludeFromPeek)
      return this.Dwm_SetWindowAttributeExcludeFromPeek(this.hwnd,false)
   }
   ; Misc
   refreshButtons(){
      ;
      ; https://msdn.microsoft.com/en-us/library/windows/hardware/ff561808(v=vs.85).aspx
      ;
      ; Misnomer. refreshInterface might be more accurate. Leave for now...
      if this.THUMBBUTTON {
         if this.hImageList
            this.ThumbBarSetImageList()
         this.ThumbBarAddButtons()
         this.ThumbBarUpdateButtons(1,7)
      }
      this._SetOverlayIcon()
      if this.thumbnailClipRect
         this.setThumbnailClip(this.thumbnailClipRect*)
      if (this.tooltipText!="")
         this._setThumbnailToolTip()
      ; The following handles flashTimers and progress
      if (this.progressValue!="" && !this.flashTimer)
         this.SetProgressValue()
      if (this.progressType!="" && !this.flashTimer)
         this.setProgressState()
      if this.flashesRemaining && IsObject(this.flashParams) {
         this.flashParams[2]:=this.flashesRemaining
         this.flashtaskbaricon(this.flashParams*)
      }
      return
   }
   restoreTaskbar(){
      ; Restores the taskbar for the window. 
      this.deleteTab()
      Sleep,50
      this.addTab()
      this.disableCustomPeekPreview()
      this.disableCustomThumbnailPreview()
   }
   stopThisButtonMonitor(){
      ; This will dismiss the callback, the message monitor is still on. To turn off message monitor use stopAllButtonMonitor()
      ; Default is message monitoring on
      return this.isDisabled:=true
   }
   restartThisButtonMonitor(){
      ; This will reenable the button click callbacks. 
      ; If all message monitor is off, i.e., stopAllButtonMonitor() was called,
      ; restart by calling restartAllButtonMonitor()
      ; Default is message monitoring on
      return this.isDisabled:=false
   }
   exemptFromHook(){
      return this.allowHooking:=false
   }
   unexemptFromHook(){
      return this.allowHooking:=true
   }
   getLastError(){
      ; Returns the last error object from exception(...)
      return this.lastError
   }
   ; Moved queryButtonIconSize to button method section, for convenience
   ; Class methods, affects all interfaces
   refreshAllButtons(){
      local k, interface
      for k, interface in taskbarInterface.allInterfaces
         interface.refreshButtons()
      return
   }
   clearAll(exiting:=false){
      local k, interface
      if !IsObject(taskbarInterface.allInterfaces)
         return
      for k, interface in taskbarInterface.allInterfaces
         interface.clear()
      if exiting
         taskbarInterface.clearInterface()
      return
   }
   static allDisabled:=true       ; All message monitor is disabled before any objects has been derived from this class.
   stopAllButtonMonitor(){
      ; turns off button message monitor, default is on.
      if taskbarInterface.allDisabled
         return
      return taskbarInterface.turnOffButtonMessages(), taskbarInterface.allDisabled:=true
   }
   restartAllButtonMonitor(){
      ; turns on button message monitor, deafult is on, hence no need to call if you didn't turn it off
      if taskbarInterface.allDisabled
         return taskbarInterface.turnOnButtonMessages(), taskbarInterface.startTaskbarMsgMonitor(), taskbarInterface.allDisabled:=false
   }
   static templates:=[] ; Holds all templates
   static hasTemplates:=0

   ;
   ; End user methods
   ;
   ;
   ; Internal methods
   ; Meta functions 
   ;
   __Call(fn,p*){
      ; For verifying correct input. maybe change this.
      if InStr(      ",showButton,hideButton,setButtonImage,setButtonIcon,enableButton,disableButton"
               . ",setButtonToolTip,dismissPreviewOnButtonClick,removeButtonBackground"
               . ",reAddButtonBackground,setButtonNonInteractive,setButtonInteractive,", "," . fn . ",") {
         if this.isFreed {
            this.lastError:=Exception("This interface has freed its memory, it cannot be used.",-1) 
            if this.mute
               return this.lastError
            else
               throw this.lastError               ; If the user tries to alter the apperance or function of the interface after memory was free, throw an exception.
         } else if (!this.THUMBBUTTON && taskbarInterface.init) {
            this.createButtons()
         }
         this.verifyId(p[1])
      }
   }
   __Delete(){
      local bool
      if !IsObject(taskbarInterface) ; We are probably exiting the script.
         return
      if (bool:=(!taskbarInterface.manualClearInterface && taskbarInterface.arrayIsEmpty(taskbarInterface.allInterfaces))) && !taskbarInterface.hasTemplates      ; If the last interface is released and no templates, release com.
         taskbarInterface.clearInterface()
      else if bool 
         taskbarInterface.turnOffButtonMessages(), taskbarInterface.stopTaskbarMsgMonitor()
      return
   }
   arrayIsEmpty(arr){
      return !arr._NewEnum().next()
   }
   ; Internal methods for flashtaskbaricon():
   ; flashOn(), flashOff()
   flashOn(type,flashTime,offTime){
      local fn
      this.SetProgressType(type)                           ; Set progresstype according to color choise
      this.setProgress(100)                              ; Set 100 progress to fill taskbar icon with the color
      fn:=ObjBindMethod(this,"flashOff",type,flashTime,offTime)   ; Make a timer for turning off the color
      this.flashTimer:=fn                                 ;
      SetTimer, % fn, % -flashTime                        ;   
      return
   }
   flashOff(type,flashTime,offTime){
      local fn
      this.SetProgressType("Off")                           ; Turn off the progress/color
      if !(--this.flashesRemaining){                        ; Decrement flash count, return if appropriate
         this.setProgressType(this.preFlashSettings[2])         ; For reference: this.preFlashSettings:=[this.progressValue,this.unmappedProgressType] 
         this.setProgress(this.preFlashSettings[1])      
         this.preFlashSettings:=""                               
         return this.flashTimer:=""
      }
      fn:=ObjBindMethod(this,"flashOn",type,flashTime,offTime)   ; Make a timer for turning on the color
      this.flashTimer:=fn                                 ;
      SetTimer, % fn, % -offTime                           ;
      return
   }
   stopTimer(){
      ; Terminates the flashTimer when appropriate. 
      ; Typically from refreshButtons() or clear()
      local fn
      if this.flashTimer {
         fn:=this.flashTimer
         SetTimer, % fn, Delete
         this.flashTimer:=""
         this.flashParams:=""
         this.progressValue:=""
         this.progessType:=""
      }
      return
   }
   ; End internal methods for flashTaskbarIcon()
   clear(){
      ; Edit: There is no need to manually call this. The taskbarInterface class will clear every thing for you.
      ; Hence, this is developer notes:
      ; Call this function before clearing your last reference to any object derived from this class.
      ; Turn off timer if on.
      this.stopTimer()
      ; Disable (and free) custom preview bitmaps
      this.disableCustomThumbnailPreview()
      this.disableCustomPeekPreview()
      this.destroyImageList()
      ; Free memory
      this.freeMemory()
      ; Free thumbnail/peek preview bitmaps, if needed
      this.freeThumbnailPreviewBMP()
      this.freePeekPreviewBMP()
      ; Remove from allInterfaces array
      taskbarInterface.allInterfaces.Delete(this.hwnd)
      return
   }
   freeMemory(){
      if this.THUMBBUTTON
         this.GlobalFree(this.THUMBBUTTON)
      this.isFreed:=true, this.THUMBBUTTON:=""
      return
   }
   ; Help functions for freeing preview bitmaps, called by clear and disable peek/thumb preview functions
   freeThumbnailPreviewBMP(){
      if (this.deleteBMPThumbnailPreview && this.thumbHbm)
         this.freeBitmap(this.thumbHbm), this.thumbHbm:=""
      return 
   }
   freePeekPreviewBMP(){
      if (this.deleteBMPPeekPreview && this.peekHbm)
         this.freeBitmap(this.peekHbm), this.peekHbm:=""
      return
   }
   PostMessage(hWnd,Msg,wParam,lParam){
      ; Url:
      ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/ms644944(v=vs.85).aspx
      ; Used by setTaskbarIcon()
      return DllCall("User32.dll\PostMessage", "Ptr", hWnd, "Uint", Msg, "Uptr", wParam, "Ptr", lParam)
   }
   verifyId(iId){
   ; Ensures the button number iId, is in the correct range.
   ; Avoids unexpected behaviour by passing an address outside of allocated memory in this.THUMBBUTTON
   ; This is called when appropriate form __Call()
      if (iId<1 || iId>7 || round(iId)!=iId) {
         this.lastError:=Exception("Button number must be an integer in the in range 1 to 7 (inclusive)",-2)
         if this.mute
            Exit
         else
            throw this.lastError
      }
      return 1
   }
   createButtons(){
      ; Creates 7 buttons. All hidden. This is because ThumbBarAddButtons() can only be called once, it seems. This is for convenience.
      ; All buttons will have the THB_FLAGS mask.
      static THB_FLAGS:=0x00000008
      static THBF_HIDDEN:=0x8
      local structOffset
      if this.THUMBBUTTON {
         this.lastError:=Exception("Buttons already created, clear this instance or make a refresh")
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      this.THUMBBUTTON:=this.GlobalAlloc(this.thumbButtonSize*7)
      
      loop, 7 {
         structOffset:=this.thumbButtonSize*(A_Index-1)
         NumPut(A_Index,this.THUMBBUTTON+structOffset, 4, "Uint")               ; Specify the ids: 1,...,7
         this.updateThumbButtonMask(A_Index,THB_FLAGS,0)                        ; update the mask: THB_FLAGS
         this.updateThumbButtonFlags(A_Index,THBF_HIDDEN,0)                     ; Update flag: THBF_HIDDEN:=0x8
      }
      this.ThumbBarAddButtons()
      return
   }
   ; Update/get/set methods for the THUMBBUTTON struct array.
   ; The update functions call the get functions, modifies the values and then set.
   ; The caller of update() then calls ThumbBarUpdateButtons() when finished

   ; Update
   /* 
   Masks:
   THB_BITMAP   = 0x00000001,
   THB_ICON     = 0x00000002,
   THB_TOOLTIP  = 0x00000004,
   THB_FLAGS    = 0x00000008
   */
   updateThumbButtonMask(iId,add:=0,remove:=0){
      local dwMask
      dwMask:=this.getThumbButtonMask(iId)
      dwMask&remove?dwMask-=remove:""
      dwMask|=add
      return this.setThumbButtonMask(iId,dwMask)
   }
   /*
   Flags:
   THBF_ENABLED         = 0x00000000,
   THBF_DISABLED        = 0x00000001,
   THBF_DISMISSONCLICK  = 0x00000002,
   THBF_NOBACKGROUND    = 0x00000004,
   THBF_HIDDEN          = 0x00000008,
   THBF_NONINTERACTIVE  = 0x00000010
   */
   updateThumbButtonFlags(iId,add:=0,remove:=0){
      local dwFlags
      dwFlags:=this.getThumbButtonFlags(iId)
      dwFlags&remove?dwFlags-=remove:""
      dwFlags|=add
      return this.setThumbButtonFlags(iId,dwFlags)
   }
   ; Item and struct offsets are specified for maintainabillity
   ; Write values to adress at this.THUMBBUTTON + structOffset + itemOffset
   ; Get
   getThumbButtonMask(iId){
      static   itemOffset      :=   0                                                      ; dwMask
      local   structOffset   :=   this.thumbButtonSize*(iId-1)
      return NumGet(this.THUMBBUTTON+itemOffset+structOffset, "Uint")
   }
   getThumbButtonFlags(iId){
      static   itemOffset      :=   8+2*A_PtrSize+260*2                                          ; dwFlags
      local   structOffset   :=   this.thumbButtonSize*(iId-1)   
      return NumGet(this.THUMBBUTTON+itemOffset+structOffset,0,"Uint")
   }
   ; Set
   setThumbButtonMask(iId,dwMask){
      static   itemOffset      :=   0                                                      ; dwMask
      local   structOffset   :=   this.thumbButtonSize*(iId-1)
      return NumPut(dwMask, this.THUMBBUTTON+itemOffset+structOffset, "Uint")
   }
   setThumbButtoniBitmap(iId,iBitmap){
      ; The imagelist index is zero base, hence iBitmap-1. User should supply 1-based index
      static   itemOffset      :=   8                                                      ; iBitmap
      local   structOffset   :=   this.thumbButtonSize*(iId-1)
      return NumPut(iBitmap-1, this.THUMBBUTTON+itemOffset+structOffset, "Ptr")
   }
   setThumbButtonhIcon(iId,hIcon){
      static   itemOffset      :=   8+A_PtrSize                                                ; hIcon
      local   structOffset   :=   this.thumbButtonSize*(iId-1)
      return NumPut(hIcon, this.THUMBBUTTON+itemOffset+structOffset, "Ptr")
   }
   
   setThumbButtonToolTipText(iId,text:=""){
      static   itemOffset      :=   8+2*A_PtrSize                                             ; szTip
      local   structOffset   :=   this.thumbButtonSize*(iId-1)
      return StrPut(SubStr(text,1,259), this.THUMBBUTTON+structOffset+itemOffset, 260, "UTF-16")         ; Make sure tooltip text isn't too long
   }
   setThumbButtonFlags(iId,dwFlags){
      static   itemOffset      :=   8+2*A_PtrSize+260*2                                          ; dwFlags
      local   structOffset   :=   this.thumbButtonSize*(iId-1)   
      return NumPut(dwFlags, this.THUMBBUTTON+structOffset+itemOffset, "Uint")
   }
   
   ;
   ; Com Interface wrapper functions
   ; The bound funcs are made in initInterface()
   addTab(){
      return taskbarInterface.vTable.addTabFn.Call("Ptr", this.hWnd) ; return 0 is ok!
   }
   deleteTab(){
      return taskbarInterface.vTable.deleteTabFn.Call("Ptr", this.hWnd) ; return 0 is ok!
   }
   activateTab(){
      return taskbarInterface.vTable.activateTabFn.Call("Ptr", this.hWnd) ; return 0 is ok!
   }
   setActiveAlt(){
      return taskbarInterface.vTable.setActiveAltFn.Call("Ptr", this.hWnd) ; return 0 is ok!
   }
   clearActiveAlt(){
      return taskbarInterface.vTable.setActiveAltFn.Call("Ptr", 0) ; return 0 is ok!
   }
   registerTab(){
      return taskbarInterface.vTable.RegisterTabFn.Call("Ptr", this.hWnd, "Ptr", this.hWnd) ; return 0 is ok!
   }
   ThumbBarAddButtons(){
      ; This function can only be called once it seems. Make one call and add all buttons hidden. Then use ThumbBarUpdateButtons() to "add" and "remove" buttons via the THBF_HIDDEN flag
      ; Max buttons is 7
      return taskbarInterface.vTable.ThumbBarAddButtonsFn.Call("Ptr", this.hWnd, "Uint", 7, "Ptr", this.THUMBBUTTON) ; return 0 is ok!
   }
   ThumbBarUpdateButtons(iId,n:=1){
      return taskbarInterface.vTable.ThumbBarUpdateButtonsFn.Call("Ptr", this.hWnd, "Uint", 1*n, "Ptr", this.THUMBBUTTON+this.thumbButtonSize*(iId-1)) ; return 0 is ok!
   }
   ThumbBarSetImageList(){
      return taskbarInterface.vTable.ThumbBarSetImageListFn.Call("Ptr", this.hWnd, "Ptr", this.hImageList)
   }
   _setThumbnailToolTip(){
      return taskbarInterface.vTable.ThumbnailToolTipFn.Call("Ptr", this.hWnd, "Str", this.tooltipText)
   }
   setProgressState(){
      return taskbarInterface.vTable.SetProgressStateFn.Call("Ptr", this.hWnd, "Uint", this.progressType)
   }
   setProgressValue(){
      return taskbarInterface.vTable.SetProgressValueFn.Call("Ptr", this.hWnd, "Int64", this.progressValue, "Int64", 100) ; 100 is max progress (done)
   }
   _setOverlayIcon(){
      return taskbarInterface.vTable.setOverlayIconFn.Call("Ptr", this.hWnd, "Ptr", this.overlayIconHandle, "Str", this.overlayIconDescription) 
   }
   _setThumbnailClip(rect){
      return taskbarInterface.vTable.ThumbnailClipFn.Call("Ptr", this.hWnd, "Ptr", rect)
   }
                
   ;
   ; Static variables
   ;
   static allInterfaces:=[]                   ; Tracks all interfaces, for callbacks.
   static init:=0                           ; For first time use initialising of the com object.
   
   ; THUMBBUTTON  struct:
   static thumbButtonSize:=A_PtrSize=4?540:552      ; Size calculations according to:

   initInterface(){
      ; Url:
      ;   -  https://msdn.microsoft.com/en-us/library/windows/desktop/bb774652(v=vs.85).aspx (ITaskbarList interface)
      ; Initilises the com object.
      static CLSID_TaskbarList := "{56FDF344-FD6D-11d0-958A-006097C9A090}"
      static IID_ITaskbarList3 := "{EA1AFB91-9E28-4B86-90E9-9E9F8A5EEFAF}"
      local hr
      Try this.hComObj := ComObjCreate(CLSID_TaskbarList, IID_ITaskbarList3)
      if !this.hComObj {
         this.lastError:=Exception("ComObjCreate failed",-2)
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      ; Get the address to the vTable.
      this.vTablePtr:=NumGet(this.hComObj+0,0,"Ptr")
      ; Create function objects for the interface, for convenience and clarity
         
                                                                                                                        ; Name:                Number:
      ; For convenience when freeing the interface, add all bound funcs to one array                                                                                                               
       ;this.vTable:={}
      this.vTable:=[]                                                                                                                                
      this.vTable["HrInitFn"]               := Func("DllCall").Bind(NumGet(this.vTablePtr+ 3*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; HrInit               ( 3)
      this.vTable["addTabFn"]               := Func("DllCall").Bind(NumGet(this.vTablePtr+ 4*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; AddTab               ( 4)
      this.vTable["deleteTabFn"]            := Func("DllCall").Bind(NumGet(this.vTablePtr+ 5*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; DeleteTab               ( 5)
      this.vTable["activateTabFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+ 6*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; ActivateTab            ( 6)
      this.vTable["setActiveAltFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+ 7*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetActiveAlt            ( 7)
      this.vTable["SetProgressValueFn"]      := Func("DllCall").Bind(NumGet(this.vTablePtr+ 9*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetProgressValue         ( 9)
      this.vTable["SetProgressStateFn"]      := Func("DllCall").Bind(NumGet(this.vTablePtr+10*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetProgressState         (10)
      this.vTable["RegisterTabFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+11*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; RegisterTab            (11)
      this.vTable["UnregisterTabFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+12*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; UnregisterTab            (12)
      this.vTable["SetTabOrderFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+13*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetTabOrder            (13)
      this.vTable["SetTabActiveFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+14*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetTabActive            (14)
      this.vTable["ThumbBarAddButtonsFn"]      := Func("DllCall").Bind(NumGet(this.vTablePtr+15*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; ThumbBarAddButtons      (15)
      this.vTable["ThumbBarUpdateButtonsFn"]   := Func("DllCall").Bind(NumGet(this.vTablePtr+16*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; ThumbBarUpdateButtons      (16)
      this.vTable["ThumbBarSetImageListFn"]   := Func("DllCall").Bind(NumGet(this.vTablePtr+17*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; ThumbBarSetImageList      (17)
      this.vTable["SetOverlayIconFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+18*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetOverlayIcon         (18)
      this.vTable["ThumbnailToolTipFn"]      := Func("DllCall").Bind(NumGet(this.vTablePtr+19*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetThumbnailTooltip      (19)
      this.vTable["ThumbnailClipFn"]         := Func("DllCall").Bind(NumGet(this.vTablePtr+20*A_PtrSize,0,"Ptr"), "Ptr", this.hComObj)                  ; SetThumbnailClip         (20)
      
      hr:=this.vTable.HrInitFn.Call()   ; Init the interface.
      if hr {
         this.lastError:=Exception("Com failed to initialise.",-2)
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      this.CoInitialize()                                                      ; This might not be needed, it calls CoUnInitialize if needed.
      this.startTaskbarMsgMonitor()
      
      ; Hook
      this.SetWinEventHook()
      this.init:=1   ; Success!
      return   
   }
   clearInterface(){
      local hr
      this.turnOffButtonMessages()
      hr := ObjRelease(this.hComObj)
      if hr {
         this.lastError:=Exception("Com realease failed",-2)
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      ; Remove message handling
      this.stopTaskbarMsgMonitor()
      ; Clear all boundFuncs
      this.vTable:=""
      
      this.hComObj:=""
      this.vTablePtr:=""
      if this.hHook   ; unHook
         this.UnhookWinEvent()
      if this.CoInitialised
         this.CoUnInitialize()
      this.init:=0            ; Indicate com is not initialised
      return hr               ; returns 0 on success (released)
      
   }
   ; CoInitialize/CoUnInitialize
   ; Url:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/ms678543(v=vs.85).aspx (CoInitialize function)
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/ms688715(v=vs.85).aspx (CoUninitialize function)
   CoInitialize(){
      static S_OK:=0      ; The COM library was initialized successfully on this thread.
      static S_FALSE:=1   ; The COM library is already initialized on this thread.
      local hr
      hr:=DllCall("Ole32.dll\CoInitialize","Int",0)
      if (hr == S_FALSE)
         this.CoUnInitialize(false)
      else if (hr == S_OK)
         this.CoInitialised:=true
      return
   }
   CoUnInitialize(count:=true){
      DllCall("Ole32.dll\CoUninitialize")
      if count
         this.CoInitialised:=false
      return
   }
   RegisterWindowMessage(msgName){
      ; Url:
      ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/ms644947(v=vs.85).aspx (RegisterWindowMessage function)
      ;  If the function fails, the return value is zero. To get extended error information, call GetLastError.
      local msgn
      if !(msgn:=DllCall("User32.dll\RegisterWindowMessage", "Str", msgName)){
         this.lastError:=Exception("RegisterWindowMessage failed to register " msgName ".`nAdditional info: " A_LastError ".",-1)
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      return msgn
   }
   taskbarButtonCreatedMsgHandler(wParam,lParam,msg,hwnd){   ; for message: "TaskbarCreated" -> this.taskbarButtonCreatedMsgId, set in initInterface()
      Critical on
      if this.allInterfaces.Haskey(hwnd)
         return this.allInterfaces[hwnd].refreshButtons()
      return
   }
   ; Hook functions
   /*
   SetWinEventHook function
   Url:
      - https://msdn.microsoft.com/en-us/library/windows/desktop/dd373640(v=vs.85).aspx
   Sets an event hook function for a range of events.
   HWINEVENTHOOK WINAPI SetWinEventHook(
     _In_ UINT         eventMin,
     _In_ UINT         eventMax,
     _In_ HMODULE      hmodWinEventProc,
     _In_ WINEVENTPROC lpfnWinEventProc,
     _In_ DWORD        idProcess,
     _In_ DWORD        idThread,
     _In_ UINT         dwflags
   )
   ; For future reference and debug
   EVENT_OBJECT_UNCLOAKED:=0x8018 
   EVENT_OBJECT_SHOW:=0x8002
   EVENT_OBJECT_HIDE:=0x8003
   EVENT_OBJECT_CREATE:=0x8000
   ;static min:=0x00000001, max:=0x7FFFFFFF
   */
   SetWinEventHook(){
      static EVENT_OBJECT_DESTROY:=0x8001
      static EVENT_OBJECT_SHOW:=0x8002
      static idThread := DllCall("User32.dll\GetWindowThreadProcessId", "Ptr", A_ScriptHwnd, "Ptr", 0) ; Url: - https://msdn.microsoft.com/en-us/library/windows/desktop/ms633522(v=vs.85).aspx
      if this.hHook
         this.UnhookWinEvent()
      if !(this.hookWindowClose || this.hasTemplates)
         return
      this.WinEventProcFn:=RegisterCallback(this.WinEventProc)
      this.CoInitialize()
      this.hHook:=DllCall("User32.dll\SetWinEventHook", "Uint", this.hookWindowClose ? EVENT_OBJECT_DESTROY : EVENT_OBJECT_SHOW, "Uint", this.hasTemplates ? EVENT_OBJECT_SHOW : EVENT_OBJECT_DESTROY, "Ptr", 0, "Ptr", this.WinEventProcFn, "Uint", this.ProcessExist(), "Uint", idThread, "Uint", 0, "Ptr")
      if !this.hHook {
         this.lastError:=Exception("SetWinEventHook failed",-1)
         if this.mute
            return
         else
            throw this.lastError
      }
      return
   }
   ProcessExist() { ; Used by SetWinEventHook(). Note: In v2 ProcessExist() is built-in, remove this then.
      ; Url:
      ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/ms683180(v=vs.85).aspx (GetCurrentProcessId function)
      return DllCall("Kernel32.dll\GetCurrentProcessId")
   }
   UnhookWinEvent(){
      if !this.hHook
         return
      if !DllCall("User32.dll\UnhookWinEvent", "Ptr", this.hHook){
         this.lastError:=Exception("UnhookWinEvent failed",-1)
         if this.mute
            return
         else
            throw this.lastError
      }
      this.GlobalFree(this.WinEventProcFn) ; Free callback function after hook is removed.
      if !this.hComObj
         this.CoUnInitialize(true)
      return this.hHook:=""
   }
   WinEventProc(params*) {
      ;(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime)
      /*
      Url:
         - https://msdn.microsoft.com/en-us/library/windows/desktop/dd373885(v=vs.85).aspx (WinEventProc callback function)
      void CALLBACK WinEventProc(
         HWINEVENTHOOK hWinEventHook,
         DWORD         event,
         HWND          hwnd,
         LONG          idObject,
         LONG          idChild,
         DWORD         dwEventThread,
         DWORD         dwmsEventTime
      );
      */
      static EVENT_OBJECT_DESTROY:=0x8001   
      static EVENT_OBJECT_SHOW:=0x8002   
      static OBJID_WINDOW:=0
      local hWinEventHook,event,hwnd,idObject,idChild,dwEventThread,dwmsEventTime,i,template,cls ; Awkward.
      local WinExistIncludeParams,WinExistExcludeParams
      Critical, On
      hWinEventHook   :=   NumGet(params+0,  -A_PtrSize, "Ptr" )
      ,event         :=   NumGet(params+0,         0, "Uint")
      ,hwnd         :=   NumGet(params+0,   A_PtrSize, "Ptr" )
      ,idObject      :=   NumGet(params+0, 2*A_PtrSize, "Int" )
      ,idChild      :=   NumGet(params+0, 3*A_PtrSize, "Int" )
      ,dwEventThread   :=   NumGet(params+0, 4*A_PtrSize, "Uint")
      ,dwmsEventTime   :=   NumGet(params+0, 5*A_PtrSize, "Uint")
      if (idObject!=OBJID_WINDOW)
         return
      WinGetClass, cls, % "ahk_id" hwnd
      if (cls = "tooltips_class32")      ; Do not consider tooltips created by the script.
         return
      if (event == EVENT_OBJECT_DESTROY) {
         if taskbarInterface.allInterfaces.HasKey(hwnd)
            taskbarInterface.allInterfaces[hwnd].clear()
         return 
      } else if (event == EVENT_OBJECT_SHOW && taskbarInterface.hasTemplates) {   ; Templates 
         if taskbarInterface.allInterfaces.HasKey(hwnd) ; If the hwnd alredy has an interface, return
            return
         ; For reference:
         ; template: {include:WinTitle,exclude:excludeWinTitle,templateFunction:templateFunction}
         for i, template in taskbarInterface.templates {
            WinExistIncludeParams:="",WinExistExcludeParams:="" ; For peace of mind
            if template.include  {
               WinExistIncludeParams:=template.include.clone()
               WinExistIncludeParams[1]:=WinExistIncludeParams[1] . " ahk_id " hwnd
            }
            if template.exclude  {
               WinExistExcludeParams:=template.exclude.clone()
               WinExistExcludeParams[1]:=WinExistExcludeParams[1] . " ahk_id " hwnd
            }
            if (!template.include && !template.exclude) {                                                                            ; There is no include/exclude criteria, hence match any.
               template.templateFunction.call(hwnd)
               return
            } else if (!template.include && !(template.exclude && hwnd == WinExist(WinExistExcludeParams*))) {                                    ; There is no include criteria and no match for an exclude criteria.
               template.templateFunction.call(hwnd)
               return
            } else if (template.include && hwnd == WinExist(WinExistIncludeParams*)) && !(template.exclude && hwnd == WinExist(WinExistExcludeParams*)){   ; There is  an include  criteria and no match for an exclude criteria.
               template.templateFunction.call(hwnd)
               return
            }
         }
      }
      return
   }
   
   ; Click on button message handling:
   ; URL:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391703(v=vs.85).aspx (ITaskbarList3::ThumbBarAddButtons method, remarks)
   ;      When a button in a thumbnail toolbar is clicked, the window associated with that thumbnail is sent a WM_COMMAND
   ;      message with the HIWORD of its wParam parameter set to THBN_CLICKED and the LOWORD to the button ID.
   ;
   turnOffButtonMessages(){
      static WM_COMMAND := 0x111
      if this.buttonMessageFn
         OnMessage(WM_COMMAND,this.buttonMessageFn,0)            ;   Turn off button message monitoring. 
      return this.buttonMessageFn:=""
   }
   turnOnButtonMessages(){
      static WM_COMMAND := 0x111
      if this.buttonMessageFn
         return
      this.buttonMessageFn:=ObjBindMethod(this,"onButtonClick")   ;   The monitor function is kept for 
      OnMessage(WM_COMMAND,this.buttonMessageFn)                   ;   When the buttons are clicked, a WM_COMMAND message is sent.
      return
   }
   onButtonClick(wParam,lParam,msg,hWnd){
      ; HIWORD of wParam is THBN_CLICKED when a button was clicked.     (wParam>>16)
      ; LOWORD of wParam is the button number.                  (wParam&0xffff)
      static THBN_CLICKED := 0x1800
      local ref,buttonNumber
      Critical, On
      if (wParam >> 16 = THBN_CLICKED) && taskbarInterface.allInterfaces.HasKey(hWnd) {
         ref:=taskbarInterface.allInterfaces[hWnd]                ;   The reference to the interface whose button was clicked
         if (ref.isDisabled || !ref.callback)                  ;   If the reference is disabled of has no callback function. Return.
            return 1
         buttonNumber:= wParam&0xffff
         ref.callback.Call(buttonNumber,ref)                   ;   The callback includes the button number and a reference to the interface. (Called in new thread)
         return 1                                       ;   No further handling of this message is needed, assumption.
      }
      return
   }
   ; Taskbar messages - this is for restoring the interface in case the taskbar is destroyed or the 
   ; taskbar icon is destroyed and remade. For example when a window is hidden and then shown.
   startTaskbarMsgMonitor(){
      if !this.taskbarCreatedMsgId
         this.taskbarCreatedMsgId:=this.RegisterWindowMessage("TaskbarCreated")            ; This might be rarly needed. In case the taskbar is destroyed and created, the interface needs to be refreshed.
      if !this.taskbarCreatedMsgFn
         this.taskbarCreatedMsgFn:=ObjBindMethod(this,"refreshAllButtons")                  ; This is a misnomer, refreshAllButtons that is.
      OnMessage(this.taskbarCreatedMsgId,this.taskbarCreatedMsgFn)                     ; Register the message callback.
      if !this.taskbarButtonCreatedMsgId
         this.taskbarButtonCreatedMsgId:=this.RegisterWindowMessage("TaskbarButtonCreated")   ; For keeping the interface "alive". Buttons, progress overlay icon, maybe more, are removed when the taskbar icon is removed, eg, if the window is hidden.
      if !this.taskbarButtonCreatedMsgFn
         this.taskbarButtonCreatedMsgFn:=ObjBindMethod(this,"taskbarButtonCreatedMsgHandler")   ; Monitor this message to automatically restore the interface when needed.
      OnMessage(this.taskbarButtonCreatedMsgId,this.taskbarButtonCreatedMsgFn)
      return
   }
   stopTaskbarMsgMonitor(){
      if this.taskbarCreatedMsgFn
         OnMessage(this.taskbarCreatedMsgId,this.taskbarCreatedMsgFn,0)
      this.taskbarCreatedMsgFn:=""
      if this.taskbarButtonCreatedMsgFn
         OnMessage(this.taskbarButtonCreatedMsgId,this.taskbarButtonCreatedMsgFn,0)
      this.taskbarButtonCreatedMsgFn:=""
      return
   }
   ; Custom preview message handling
   WM_DWMSENDICONICTHUMBNAIL(wParam, lParam, msg, hWnd) {
      ;   Instructs a window to provide a static bitmap to use as a thumbnail representation of that window
      ;   DWM sends this message to a window if all of the following situations are true:
      ;      - DWM is displaying an iconic representation of the window.
      ;      - The DWMWA_HAS_ICONIC_BITMAP attribute is set on the window.
      ;      - The window did not set a cached bitmap.
      ;      - There is room in the cache for another bitmap.
      ;   Url:
      ;      https://msdn.microsoft.com/en-us/library/windows/desktop/dd938875(v=vs.85).aspx
      ;   Notes:
      ;       Requested size of thumbnail, can be smaller, not bigger
      local ref,w,h,tf
      Critical, On
      ref:=taskbarInterface.allInterfaces[hWnd]
      if !ref
         return
      w:= lParam >> 16, h:= lParam & 0xFFFF                                                   ; Get the max width and height of the bitmap
      if (ref.saveThumbBitmap && ref.thumbHbm) || (ref.thumbHbm && A_TickCount-ref.pThumbTic<ref.thumbrate)
         return this.Dwm_SetIconicThumbnail(hWnd,ref.thumbHbm,false,ref.dwSITFlagsThumbnailPreview)         ; Set the old bitmap                                                               
      ref.freeThumbnailPreviewBMP()                                                         ; Conditional: if (ref.thumbHbm && ref.deleteBMPThumbnailPreview)
      ref.thumbHbm:=ref.bitmapFunc.call(w,h,ref)                                                ; Call the bitmapFunc to get the new bitmap
      if !ref.thumbHbm
         return
      this.Dwm_SetIconicThumbnail(hWnd,ref.thumbHbm, false,ref.dwSITFlagsThumbnailPreview)               ; Set the new bitmap
      if !ref.thumbrate                                                                  ; If rate is 0, the bitmap will not be invalidated, no more calls here will be made.
         return         
      ref.pThumbTic:=A_TickCount
      tf:=ref.invalidateThumbTimerFn:=ObjBindMethod(ref,"InvalidateIconicBitmaps")                     ; The bitmap will be invalidated after rate ms.
      SetTimer, % tf, % -abs(ref.thumbrate)
      return
   }
   WM_DWMSENDICONICLIVEPREVIEWBITMAP(wParam, lParam, msg, hwnd){
      ;   Instructs a window to provide a static bitmap to use as a live preview (also known as a Peek preview) of that window.
      ;   Desktop Window Manager (DWM) sends this message to a window if all of the following situations are true:
      ;      - Live preview has been invoked on the window.
      ;      - The DWMWA_HAS_ICONIC_BITMAP attribute is set on the window.
      ;      - An iconic representation is the only one that exists for this window.
      ;   wParam,lParam not used.
      ;    
      ;   Url:
      ;      https://msdn.microsoft.com/en-us/library/windows/desktop/dd938874(v=vs.85).aspx
      ;
      ;   Notes: The size of the bitmap should (perhaps must) fit the client rectangle.
      ;
      local ref,w,h,tf
      Critical, On
      ref:=taskbarInterface.allInterfaces[hWnd]
      if !ref
         return
      this.GetClientRect(hwnd,w,h)                                                                     ; Get the max width and height of the bitmap
      if (ref.savePeekBitmap && ref.peekHbm) || (ref.peekHbm && A_TickCount-ref.ppeekTic<ref.peekrate)
         return this.Dwm_SetIconicLivePreviewBitmap(hWnd,ref.peekHbm,ref.peekX,ref.peekY, false,ref.dwSITFlagsPeekPreview)   ; Set the new bitmap
      ref.freePeekPreviewBMP()                                                                        ; Conditional: if (ref.peekHbm && ref.deleteBMPPeekPreview)
      ref.peekhbm:=ref.peekbitmapFunc.call(w,h,ref)                                                         ; Call the bitmapFunc to get the new bitmap
      if !ref.peekhbm
         return
      this.Dwm_SetIconicLivePreviewBitmap(hWnd,ref.peekhbm,ref.peekX,ref.peekY,false,ref.dwSITFlagsPeekPreview)            ; Set the new bitmap
      if !ref.peekrate                                                                              ; If rate is 0, the bitmap will not be invalidated, no more calls here will be made.
         return
      ref.ppeekTic:=A_TickCount
      tf:=ref.invalidatePeekTimerFn:=ObjBindMethod(ref,"InvalidateIconicBitmaps")                                    ; The bitmap will be invalidated after rate ms.
      SetTimer, % tf, % -abs(ref.peekrate)
      return
   }

   ;   NOTE: End context: this=taskbarInterface
   ;       
   ;
   InvalidateIconicBitmaps(){
      taskbarInterface.Dwm_InvalidateIconicBitmaps(this.hWnd)
      return
   }
   ; DWM library
   Dwm_SetWindowAttributeHasIconicBitmap(hwnd,onOff){
      ;   DWMWA_HAS_ICONIC_BITMAP=10
      ;   Use with DwmSetWindowAttribute. The window will provide a bitmap for use by DWM as an iconic thumbnail or peek representation
      ;   (a static bitmap) for the window. DWMWA_HAS_ICONIC_BITMAP can be specified with DWMWA_FORCE_ICONIC_REPRESENTATION.
      ;   DWMWA_HAS_ICONIC_BITMAP normally is set during a window's creation and not changed throughout the window's lifetime.
      ;   Some scenarios, however, might require the value to change over time. The pvAttribute parameter points to a value of TRUE
      ;   to inform DWM that the window will provide an iconic thumbnail or peek representation; otherwise, it points to FALSE.
      ;   Windows Vista and earlier:  This value is not supported.
      ;
      static dwAttribute:=10
      static cbAttribute:=4
      local pvAttribute, hr
      VarSetCapacity(pvAttribute,4,0)
      NumPut(onOff,pvAttribute,0,"Int")
      hr:=DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", hwnd, "Uint", dwAttribute, "Ptr", &pvAttribute, "Uint", cbAttribute)
      return hr
   }
   Dwm_SetWindowAttributeForceIconicRepresentaion(hwnd,onOff){
      ;
      ;   DWMWA_FORCE_ICONIC_REPRESENTATION=7
      ;   Use with DwmSetWindowAttribute. Forces the window to display an iconic thumbnail or peek representation (a static bitmap),
      ;   even if a live or snapshot representation of the window is available. This value normally is set during a window's creation 
      ;   and not changed throughout the window's lifetime. Some scenarios, however, might require the value to change over time.
      ;   The pvAttribute parameter points to a value of TRUE to require a iconic thumbnail or peek representation; otherwise, it points to FALSE.
      ;
      static dwAttribute:=7
      static cbAttribute:=4
      local pvAttribute, hr
      VarSetCapacity(pvAttribute,4,0)
      NumPut(onOff,pvAttribute,0,"Int")
      hr:=DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", hwnd, "Uint", dwAttribute, "Ptr", &pvAttribute, "Uint", cbAttribute)
      return hr
   }
   Dwm_SetWindowAttributeDisallowPeek(hwnd,disallow:=1){
      ;
      ;   DWMWA_DISALLOW_PEEK=11
      ;   Do not show peek preview for the window. The peek view shows a full-sized preview of the window when the mouse hovers over the window's thumbnail in the taskbar.
      ;   If this attribute is set, hovering the mouse pointer over the window's thumbnail dismisses peek (in case another window in the group has a peek preview showing).
      ;   The pvAttribute parameter points to a value of TRUE to prevent peek functionality or FALSE to allow it.
      ;   Windows Vista and earlier:  This value is not supported.
      ;   Input:
      ;         disallow, 1 to disallow peek preview, 0 to allow
      ;   Output:
      ;         hresult, error msg. 0 is ok!
      ;   Url:
      ;         https://msdn.microsoft.com/en-us/library/windows/desktop/aa969530(v=vs.85).aspx - DWMWINDOWATTRIBUTE enumeration
      static dwAttribute:=11
      static cbAttribute:=4
      local pvAttribute, hr
      VarSetCapacity(pvAttribute,4,0)
      NumPut(disallow,pvAttribute,0,"Int")
      hr:=DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", hwnd, "Uint", dwAttribute, "Ptr", &pvAttribute, "Uint", cbAttribute)
      return hr ; 0 is ok!
   }
   Dwm_SetWindowAttributeExcludeFromPeek(hwnd,exclude:=1){
      ;
      ;   DWMWA_EXCLUDED_FROM_PEEK=12
      ;   Use with DwmSetWindowAttribute. Prevents a window from fading to a glass sheet when peek is invoked.
      ;   The pvAttribute parameter points to a value of TRUE to prevent the window from fading during another window's peek or FALSE for normal behavior.
      ;   Windows Vista and earlier:  This value is not supported.
      ;   Input:
      ;         exclude, 1 to prevent window from fading to a glass sheet when peek is invoked, 0 from normal behavior
      ;   Output:
      ;         hresult, error msg. 0 is ok!
      ;   Url:
      ;         https://msdn.microsoft.com/en-us/library/windows/desktop/aa969530(v=vs.85).aspx - DWMWINDOWATTRIBUTE enumeration
      static dwAttribute:=12
      static cbAttribute:=4
      local pvAttribute, hr
      VarSetCapacity(pvAttribute,4,0)
      NumPut(exclude,pvAttribute,0,"Int")
      hr:=DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", hwnd, "Uint", dwAttribute, "Ptr", &pvAttribute, "Uint", cbAttribute)
      return hr ; 0 is ok!
   }
   ;   Note, the deleteBMP function is not used here, but it is handled in the message functions, clear() and disableCustomXPreview
   Dwm_SetIconicThumbnail(hwnd,hBITMAP,deleteBMP:=true,dwSITFlags:=0){
      ;   Sets a static, iconic bitmap on a window or tab to use as a thumbnail representation.
      ;   The taskbar can use this bitmap as a thumbnail switch target for the window or tab.
      ;
      ;   Input:
      ;         hwnd, A handle to the window or tab. This window must belong to the calling process.
      ;         hBITMAP, A handle to the bitmap to represent the window that hwnd specifies.
      ;         deleteBMP, option to delete the bitmap after it's been set as thumbnail, 1 - delete, 0 - don't delete.
      ;         dwSITFlags, The display options for the thumbnail. One of the following values:
      ;                  0, No frame is displayed around the provided thumbnail.
      ;                  1, Displays a frame around the provided thumbnail.      
      ;    Output:
      ;         hr, if this function succeeds, it returns S_OK. Otherwise, it returns an HRESULT error code.
      ;   Url:
      ;         https://msdn.microsoft.com/en-us/library/windows/desktop/dd389411(v=vs.85).aspx
      ;   Notes:
      ;         The bitmap must not be bigger than the requested size from DWM, the requested size is in x=HIWORD(lParam) (sic!), y=LOWORD(lParam) (sic!) from WM_DWMSENDICONICTHUMBNAIL=0x0323.
      ;         Yes, the x,y are unconventinally stored in lParam. See example message monitor functions.
      local hr
      hr:=DllCall("Dwmapi.dll\DwmSetIconicThumbnail", "Ptr", hwnd, "Ptr", hBITMAP, "Uint", dwSITFlags)
      ; Clean up
      if deleteBMP
         DllCall("Gdi32.dll\DeleteObject", "Ptr", hBITMAP)
      return hr ; 0 is ok.
   }
   Dwm_SetIconicLivePreviewBitmap(hwnd,hBITMAP,x:="",y:="",deleteBMP:=true,dwSITFlags:=0){
      ;   Sets a static, iconic bitmap to display a live preview (also known as a Peek preview) of a window or tab.
      ;   The taskbar can use this bitmap to show a full-sized preview of a window or tab.
      ;
      ;   Input:
      ;         hwnd, A handle to the window or tab. This window must belong to the calling process.
      ;         hBITMAP, A handle to the bitmap to represent the window that hwnd specifies.
      ;         x,y, The offset of a tab window's client region (the content area inside the client window frame) from the host window's frame.
      ;             This offset enables the tab window's contents to be drawn correctly in a live preview when it is drawn without its frame.
      ;         deleteBMP, option to delete the bitmap after it's been set as thumbnail, 1 - delete, 0 - don't delete. DWM doesn't need it after it's been set, so delete if you don't need it anymore.
      ;         dwSITFlags, The display options for the thumbnail. One of the following values:
      ;                  0, No frame is displayed around the provided thumbnail.
      ;                  1, Displays a frame around the provided thumbnail.      
      ;    Output:
      ;         hr, if this function succeeds, it returns S_OK. Otherwise, it returns an HRESULT error code.
      ;   Url:
      ;         https://msdn.microsoft.com/en-us/library/windows/desktop/dd389410(v=vs.85).aspx
      ;   Notes:
      ;         The size of the bitmap should (perhaps must) fit the (hwnds) client rectangle.
      
      ; offset point from x,y
      local ppt,pt,hr
      if (x="" || y="") {
         ppt:=0
      } else {
         VarSetCapacity(pt,8,0)
         NumPut(x,pt,0,"Int")
         NumPut(y,pt,4,"Int")
         ppt:=&pt
      }
      hr:=DllCall("Dwmapi.dll\DwmSetIconicLivePreviewBitmap", "Ptr", hwnd, "Ptr", hBITMAP, "Ptr", ppt, "Uint", dwSITFlags)
      ; Clean up
      if deleteBMP
         DllCall("Gdi32.dll\DeleteObject", "Ptr", hBITMAP)
      return hr ; 0 is ok.
   }
   Dwm_InvalidateIconicBitmaps(hwnd){
      ;   Called by an application to indicate that all previously provided iconic bitmaps from a window,
      ;   both thumbnails and peek representations, should be refreshed.
      ;
      ;   Input:
      ;         hwnd, A handle to the window or tab whose bitmaps are being invalidated through this call. 
      ;              This window must belong to the calling process.
      ;    Output:
      ;         hr, if this function succeeds, it returns S_OK. Otherwise, it returns an HRESULT error code.
      ;   Url:
      ;         https://msdn.microsoft.com/en-us/library/windows/desktop/dd389409(v=vs.85).aspx - DwmInvalidateIconicBitmaps function
      return DllCall("Dwmapi.dll\DwmInvalidateIconicBitmaps", "Ptr", hwnd) ; 0 is ok
   }
   ; Memory allocation/free methods.
   GlobalAlloc(dwBytes){
      ; URL:
      ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/aa366574(v=vs.85).aspx (GlobalAlloc function)
      static GMEM_ZEROINIT:=0x0040   ; Zero fill memory
      static uFlags:=GMEM_ZEROINIT   ; For clarity.
      local h
      h:=DllCall("Kernel32.dll\GlobalAlloc", "Uint", uFlags, "Ptr", dwBytes, "Ptr")
      if !h {
         this.lastError:=Exception("Memory alloc failed.",-1)
         if this.mute
            return this.lastError
         else
            throw this.lastError
      }
      
      return h
   }
   GlobalFree(hMem){
      ; URL:
      ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/aa366579(v=vs.85).aspx (GlobalFree function)
      local h
      h:=DllCall("Kernel32.dll\GlobalFree", "Ptr", hMem, "Ptr")
      if h {
         this.lastError:=Exception("Memory free failed",-1)
         if this.mute
            return
         else
            throw this.lastError
      }
      return h
   }
   freeBitmap(hbm){
      return DllCall("Gdi32.dll\DeleteObject", "Ptr", hbm)
   }

   ; Misc:
   GetClientRect(hwnd,ByRef X2, ByRef Y2){
      local rc
      VarSetCapacity(rc,16)
      DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rc)
      X2:=NumGet(rc,8,"Int")
      Y2:=NumGet(rc,12,"Int")
   }
}


repositionWindowCenter(whichGUI, hwndGUI, referencePoint, winTitle:="", winPos:="") {
    Static lastAsked := 1
    If !winPos
    {
       SysGet, MonitorCount, 80
       ActiveMonDetails := calcScreenLimits(referencePoint)
       ActiveMon := ActiveMonDetails.m
       ResWidth := ActiveMonDetails.w, ResHeight:= ActiveMonDetails.h
       mCoordRight := ActiveMonDetails.mCRight, mCoordLeft := ActiveMonDetails.mCLeft
       mCoordTop := ActiveMonDetails.mCTop, mCoordBottom := ActiveMonDetails.mCBottom
    }

    If (MonitorCount>1 && !winPos && A_OSVersion!="WIN_XP")
    {
       ; center window on the monitor/screen where the mouse cursor is
       semiFinal_x := mCoordLeft + 2
       semiFinal_y := mCoordTop + 2
       If !semiFinal_y
          semiFinal_y := 1
       If !semiFinal_x
          semiFinal_x := 1

       Gui, %whichGUI%: Show, Hide AutoSize x%semiFinal_x% y%semiFinal_y%, % winTitle
       Sleep, 25
       GetWinClientSize(msgWidth, msgHeight, hwndGUI, 1)
       If !msgWidth
          msgWidth := 1
       If !msgHeight
          msgHeight := 1

       Final_x := Round(mCoordLeft + ResWidth/2 - msgWidth/2)
       Final_y := Round(mCoordTop + ResHeight/2 - msgHeight/2)
       If (!Final_x) || (Final_x + 1<mCoordLeft)
          Final_x := mCoordLeft + 1
       If (!Final_y) || (Final_y + 1<mCoordTop)
          Final_y := mCoordTop + 1
       If !Final_y
          Final_y := A_ScreenHeight//3
       If !Final_x
          Final_x := A_ScreenWidth//3
       Gui, %whichGUI%: Show, x%Final_x% y%Final_y%, % Chr(160) winTitle
    } Else Gui, %whichGUI%: Show, AutoSize %winPos%, % Chr(160) winTitle

}

MWAGetMonitorMouseIsIn(coordX:=0,coordY:=0) {
; function from: https://autohotkey.com/boards/viewtopic.php?f=6&t=54557
; by Maestr0

  ; get the mouse coordinates first
  If (coordX && coordY)
  {
     Mx := coordX
     My := coordY
  } Else GetPhysicalCursorPos(mX, mY)

  SysGet, MonitorCount, 80  ; monitorcount, so we know how many monitors there are, and the number of loops we need to do
  Loop, %MonitorCount%
  {
    SysGet, mon%A_Index%, Monitor, %A_Index%  ; "Monitor" will get the total desktop space of the monitor, including taskbars
    If (Mx>=mon%A_Index%left) && (Mx<mon%A_Index%right)
    && (My>=mon%A_Index%top) && (My<mon%A_Index%bottom)
    {
       ActiveMon := A_Index
       Break
    }
  }
  Return ActiveMon
}

GetWindowBounds(hWnd) {
   ; function by GeekDude: https://gist.github.com/G33kDude/5b7ba418e685e52c3e6507e5c6972959
   ; W10 compatible function to find a window's visible boundaries
   ; modified by Marius Șucanto return an array
   size := VarSetCapacity(rect, 16, 0)
   er := DllCall("dwmapi\DwmGetWindowAttribute"
      , "UPtr", hWnd  ; HWND  hwnd
      , "UInt", 9     ; DWORD dwAttribute (DWMWA_EXTENDED_FRAME_BOUNDS)
      , "UPtr", &rect ; PVOID pvAttribute
      , "UInt", size  ; DWORD cbAttribute
      , "UInt")       ; HRESULT

   If er
      DllCall("GetWindowRect", "UPtr", hwnd, "UPtr", &rect, "UInt")

   r := []
   r.x1 := NumGet(rect, 0, "Int"), r.y1 := NumGet(rect, 4, "Int")
   r.x2 := NumGet(rect, 8, "Int"), r.y2 := NumGet(rect, 12, "Int")
   r.w := Abs(max(r.x1, r.x2) - min(r.x1, r.x2))
   r.h := Abs(max(r.y1, r.y2) - min(r.y1, r.y2))
   ; ToolTip, % r.w " --- " r.h , , , 2
   Return r
}

GetWinClientSize(ByRef w, ByRef h, hwnd, mode) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
; modified by Marius Șucan
    Static prevW, prevH, prevHwnd, lastInvoked := 1
    If (A_TickCount - lastInvoked<95) && (prevHwnd=hwnd)
    {
       W := prevW, H := prevH
       Return
    }

    prevHwnd := hwnd
    VarSetCapacity(rc, 16, 0)
    If (mode=1)
    {
       r := GetWindowBounds(hwnd)
       prevW := W := r.w
       prevH := H := r.h
       lastInvoked := A_TickCount
       Return
    } Else DllCall("GetClientRect", "uint", hwnd, "uint", &rc)

    prevW := W := NumGet(rc, 8, "int")
    prevH := H := NumGet(rc, 12, "int")
    lastInvoked := A_TickCount
} 

MDMF_FromHWND(HWND, Flag := 0) {
   Return DllCall("User32.dll\MonitorFromWindow", "Ptr", HWND, "UInt", Flag, "Ptr")
}

MDMF_FromPoint(ByRef X := "", ByRef Y := "", Flag := 0) {
   If (X = "") || (Y = "") {
      VarSetCapacity(PT, 8, 0)
      DllCall("User32.dll\GetCursorPos", "Ptr", &PT, "Int")
      If (X = "")
         X := NumGet(PT, 0, "Int")
      If (Y = "")
         Y := NumGet(PT, 4, "Int")
   }
   Return DllCall("User32.dll\MonitorFromPoint", "Int64", (X & 0xFFFFFFFF) | (Y << 32), "UInt", Flag, "Ptr")
}

MDMF_GetInfo(HMON) {
   NumPut(VarSetCapacity(MIEX, 40 + (32 << !!A_IsUnicode)), MIEX, 0, "UInt")
   If DllCall("User32.dll\GetMonitorInfo", "Ptr", HMON, "Ptr", &MIEX, "Int")
      Return {Name:      (Name := StrGet(&MIEX + 40, 32))  ; CCHDEVICENAME = 32
            , Num:       RegExReplace(Name, ".*(\d+)$", "$1")
            , Left:      NumGet(MIEX, 4, "Int")    ; display rectangle
            , Top:       NumGet(MIEX, 8, "Int")    ; "
            , Right:     NumGet(MIEX, 12, "Int")   ; "
            , Bottom:    NumGet(MIEX, 16, "Int")   ; "
            , WALeft:    NumGet(MIEX, 20, "Int")   ; work area
            , WATop:     NumGet(MIEX, 24, "Int")   ; "
            , WARight:   NumGet(MIEX, 28, "Int")   ; "
            , WABottom:  NumGet(MIEX, 32, "Int")   ; "
            , Primary:   NumGet(MIEX, 36, "UInt")} ; contains a non-zero value for the primary monitor.
   Return False
}

Acc_ObjectFromWindow(hWnd, idObject = 0) {
  SendMessage, WM_GETOBJECT, 0, 1, Chrome_RenderWidgetHostHWND1, % "ahk_id " hwnd
  If DllCall("oleacc\AccessibleObjectFromWindow", "Ptr", hWnd, "UInt", idObject&=0xFFFFFFFF
    , "Ptr", -VarSetCapacity(IID,16)+NumPut(idObject==0xFFFFFFF0?0x46000000000000C0:0x719B3800AA000C81
    ,NumPut(idObject==0xFFFFFFF0?0x0000000000020400:0x11CF3C3D618736E0,IID,"Int64"),"Int64"), "Ptr*", pacc)=0
    Return ComObjEnwrap(9,pacc,1)
}

AccAccFocus(hwnd, byref name, byref value, byref role, byref irole) {
  Static WM_GETOBJECT := 0x003D  
  SendMessage, WM_GETOBJECT, 0, 1, Chrome_RenderWidgetHostHWND1, % "ahk_id " hwnd
  Acc := Acc_ObjectFromWindow(hwnd)
  Try While IsObject(Acc.accFocus)
  {
    Acc := Acc.accFocus
  }

  Try 
  {
    child := Acc.accFocus
    name := Acc.accName(child)
    value := Acc.accValue(child)
    ; role := AccRole(Acc, child) 
    irole := Acc.accRole(0) 
    shortcut := Acc.accKeyboardShortCut(child)
    AccState(Acc, child, styleu, strstyles)
  }
}

Acc_ObjectFromPoint(ByRef idChild:="", mx:="", my:="") {
    Try z := DllCall("oleacc\AccessibleObjectFromPoint", "Int64", mx & 0xFFFFFFFF | my << 32, "Ptr*", pacc, "Ptr", VarSetCapacity(varChild,8+2*A_PtrSize,0)*0+&varChild)
    If (z=0)
    {
       Try g := ComObjEnwrap(9,pacc,1)
       idChild := NumGet(varChild,8,"UInt")
    }
    Return g
}

AccInfoUnderMouse(mx, my, WinID, byref val, byref name, byref RoleChild, byref RoleParent, byref styleu, byref strstyles, byref shortcut) {
  Static hLibrary, WM_GETOBJECT := 0x003D  
  If !hLibrary
     hLibrary := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")

  AccObj := Acc_ObjectFromPoint(child, mx, my)
  If !IsObject(AccObj)
     Return

  ; SendMessage, WM_GETOBJECT, 0, 1, Chrome_RenderWidgetHostHWND1, % "ahk_id " WinID
  Try
  {
     ChildCount := AccObj.accChildCount
     Name := AccObj.accName(child)
     Val := AccObj.accValue(child)
     RoleChild := AccObj.accRole(child)
     shortcut := AccObj.accKeyboardShortCut(child)
     AccState(AccObj, child, styleu, strstyles)
  }
  ; RoleParent := AccObj.accRole()
  Return ; ChildCount name val RoleChild RoleParent
}

AccState(Acc, child, byref style, byref str, i := 1) {
  ;;  https://docs.microsoft.com/ru-ru/windows/desktop/WinAuto/object-state-constants
  ;;  http://forum.script-coding.com/viewtopic.php?pid=130762#p130762
  style := Format("0x{1:08X}", Acc.accState(child))
  If (style=0)
     Return AccGetStateText(0)

  While (i <= style)
  {
    if (i & style)
      str .= AccGetStateText(i) "=" Format("0x{1:08X}", i) "`n"
    i <<= 1
  }
}

AccGetStateText(nState) {
  nSize := DllCall("oleacc\GetStateText", "UInt", nState, "Ptr", 0, "UInt", 0)
  VarSetCapacity(sState, (A_IsUnicode?2:1)*nSize)
  DllCall("oleacc\GetStateText", "UInt", nState, "str", sState, "UInt", nSize+1)
  Return sState
}

setMenusTheme(modus) {
   uxtheme := DllCall("GetModuleHandle", "str", "uxtheme", "ptr")
   SetPreferredAppMode := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 135, "ptr")
   ; AllowDarkModeForWindow := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 133, "ptr")
   FlushMenuThemes := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 136, "ptr")
   DllCall(SetPreferredAppMode, "int", modus) ; Dark
   DllCall(FlushMenuThemes)
}

AddTooltip2Ctrl(p1, p2:="", p3="", darkMode:=0) {
; Description: AddTooltip v2.0
;   Add/Update tooltips to GUI controls.
;
; Parameters:
;   p1 - Handle to a GUI control.  Alternatively, set to "Activate" to enable
;       the tooltip control, "AutoPopDelay" to set the autopop delay time,
;       "Deactivate" to disable the tooltip control, or "Title" to set the
;       tooltip title.
;
;   p2 - If p1 contains the handle to a GUI control, this parameter should
;       contain the tooltip text.  Ex: "My tooltip".  Set to null to delete the
;       tooltip attached to the control.  If p1="AutoPopDelay", set to the
;       desired autopop delay time, in seconds.  Ex: 10.  Note: The maximum
;       autopop delay time is ~32 seconds.  If p1="Title", set to the title of
;       the tooltip.  Ex: "Bob's Tooltips".  Set to null to remove the tooltip
;       title.  See the *Title & Icon* section for more information.
;
;   p3 - Tooltip icon.  See the *Title & Icon* section for more information.
;
; RETURNS: The handle to the tooltip control.
; REQUIREMENTS: AutoHotkey v1.1+ (all versions).
;
; TITLE AND ICON:
;   To set the tooltip title, set the p1 parameter to "Title" and the p2
;   parameter to the desired tooltip title.  Ex: AddTooltip("Title","Bob's
;   Tooltips"). To remove the tooltip title, set the p2 parameter to null.  Ex:
;   AddTooltip("Title","").
;
;   The p3 parameter determines the icon to be displayed along with the title,
;   if any.  If not specified or if set to 0, no icon is shown.  To show a
;   standard icon, specify one of the standard icon identifiers.  See the
;   function's static variables for a list of possible values.  Ex:
;   AddTooltip("Title","My Title",4).  To show a custom icon, specify a handle
;   to an image (bitmap, cursor, or icon).  When a custom icon is specified, a
;   copy of the icon is created by the tooltip window so if needed, the original
;   icon can be destroyed any time after the title and icon are set.
;
;   Setting a tooltip title may not produce a desirable result in many cases.
;   The title (and icon if specified) will be shown on every tooltip that is
;   added by this function.
;
; REMARKS:
;   The tooltip control is enabled by default.  There is no need to "Activate"
;   the tooltip control unless it has been previously "Deactivated".
;
;   This function returns the handle to the tooltip control so that, if needed,
;   additional actions can be performed on the Tooltip control outside of this
;   function.  Once created, this function reuses the same tooltip control.
;   If the tooltip control is destroyed outside of this function, subsequent
;   calls to this function will fail.
;
; CREDIT AND HISTORY:
;   Original author: Superfraggle
;   * Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/>
;
;   Updated to support Unicode: art
;   * Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/page-2#entry431059>
;
;   Additional: jballi.
;   Bug fixes.  Added support for x64.  Removed Modify parameter.  Added
;   additional functionality, constants, and documentation.

    Static hTT
          ;-- Misc. constants
          ,CW_USEDEFAULT:=0x80000000
          ,HWND_DESKTOP :=0

          ;-- Tooltip delay time constants
          ,TTDT_AUTOPOP:=2
                ;-- Set the amount of time a tooltip window remains visible if
                ;   the pointer is stationary within a tool's bounding
                ;   rectangle.

          ;-- Tooltip styles
          ,TTS_ALWAYSTIP:=0x1
                ;-- Indicates that the tooltip control appears when the cursor
                ;   is on a tool, even if the tooltip control's owner window is
                ;   inactive.  Without this style, the tooltip appears only when
                ;   the tool's owner window is active.

          ,TTS_NOPREFIX:=0x2
                ;-- Prevents the system from stripping ampersand characters from
                ;   a string or terminating a string at a tab character.
                ;   Without this style, the system automatically strips
                ;   ampersand characters and terminates a string at the first
                ;   tab character.  This allows an application to use the same
                ;   string as both a menu item and as text in a tooltip control.

          ;-- TOOLINFO uFlags
          ,TTF_IDISHWND:=0x1
                ;-- Indicates that the uId member is the window handle to the
                ;   tool.  If this flag is not set, uId is the identifier of the
                ;   tool.

          ,TTF_SUBCLASS:=0x10
                ;-- Indicates that the tooltip control should subclass the
                ;   window for the tool in order to intercept messages, such
                ;   as WM_MOUSEMOVE.  If this flag is not used, use the
                ;   TTM_RELAYEVENT message to forward messages to the tooltip
                ;   control.  For a list of messages that a tooltip control
                ;   processes, see TTM_RELAYEVENT.

          ;-- Tooltip icons
          ,TTI_NONE         :=0
          ,TTI_INFO         :=1
          ,TTI_WARNING      :=2
          ,TTI_ERROR        :=3
          ,TTI_INFO_LARGE   :=4
          ,TTI_WARNING_LARGE:=5
          ,TTI_ERROR_LARGE  :=6

          ;-- Extended styles
          ,WS_EX_TOPMOST:=0x8

          ;-- Messages
          ,TTM_ACTIVATE      :=0x401                    ;-- WM_USER + 1
          ,TTM_ADDTOOLA      :=0x404                    ;-- WM_USER + 4
          ,TTM_ADDTOOLW      :=0x432                    ;-- WM_USER + 50
          ,TTM_DELTOOLA      :=0x405                    ;-- WM_USER + 5
          ,TTM_DELTOOLW      :=0x433                    ;-- WM_USER + 51
          ,TTM_GETTOOLINFOA  :=0x408                    ;-- WM_USER + 8
          ,TTM_GETTOOLINFOW  :=0x435                    ;-- WM_USER + 53
          ,TTM_SETDELAYTIME  :=0x403                    ;-- WM_USER + 3
          ,TTM_SETMAXTIPWIDTH:=0x418                    ;-- WM_USER + 24
          ,TTM_SETTITLEA     :=0x420                    ;-- WM_USER + 32
          ,TTM_SETTITLEW     :=0x421                    ;-- WM_USER + 33
          ,TTM_UPDATETIPTEXTA:=0x40C                    ;-- WM_USER + 12
          ,TTM_UPDATETIPTEXTW:=0x439                    ;-- WM_USER + 57

    ; if (DisableTooltips=1)
    ;    return 

    ;-- Save/Set DetectHiddenWindows
    l_DetectHiddenWindows:=A_DetectHiddenWindows
    DetectHiddenWindows On

    ;-- Tooltip control exists?
    if !hTT
    {
        ;-- Create Tooltip window
        hTT:=DllCall("CreateWindowEx"
            ,"UInt",WS_EX_TOPMOST                       ;-- dwExStyle
            ,"Str","TOOLTIPS_CLASS32"                   ;-- lpClassName
            ,"Ptr",0                                    ;-- lpWindowName
            ,"UInt",TTS_ALWAYSTIP|TTS_NOPREFIX          ;-- dwStyle
            ,"UInt",CW_USEDEFAULT                       ;-- x
            ,"UInt",CW_USEDEFAULT                       ;-- y
            ,"UInt",CW_USEDEFAULT                       ;-- nWidth
            ,"UInt",CW_USEDEFAULT                       ;-- nHeight
            ,"Ptr",HWND_DESKTOP                         ;-- hWndParent
            ,"Ptr",0                                    ;-- hMenu
            ,"Ptr",0                                    ;-- hInstance
            ,"Ptr",0                                    ;-- lpParam
            ,"Ptr")                                     ;-- Return type

        ;-- Disable visual style
        ;   Note: Uncomment the following to disable the visual style, i.e.
        ;   remove the window theme, from the tooltip control.  Since this
        ;   function only uses one tooltip control, all tooltips created by this
        ;   function will be affected.
        ;   DllCall("uxtheme\SetWindowTheme","Ptr",hTT,"Ptr",0,"UIntP",0)

        ;-- Set the maximum width for the tooltip window
        ;   Note: This message makes multi-line tooltips possible
        SendMessage, TTM_SETMAXTIPWIDTH, 0, A_ScreenWidth,, ahk_id %hTT%
    }

    ;-- Other commands
    if p1 is not Integer
    {
        if (p1="Activate")
            SendMessage, TTM_ACTIVATE, True, 0,, ahk_id %hTT%

        if (p1="Deactivate")
            SendMessage, TTM_ACTIVATE, False, 0,, ahk_id %hTT%

        if (InStr(p1,"AutoPop")=1)  ;-- Starts with "AutoPop"
            SendMessage, TTM_SETDELAYTIME, TTDT_AUTOPOP, p2*1000,, ahk_id %hTT%

        if (p1="Title")
        {
            ;-- If needed, truncate the title
            if (StrLen(p2)>99)
                p2 := SubStr(p2,1,99)

            ;-- Icon
            if p3 is not Integer
                p3 := TTI_NONE

            ;-- Set title
            SendMessage A_IsUnicode ? TTM_SETTITLEW : TTM_SETTITLEA, p3, &p2,, ahk_id %hTT%
        }

        ;-- Restore DetectHiddenWindows
        DetectHiddenWindows %l_DetectHiddenWindows%
    
        ;-- Return the handle to the tooltip control
        Return hTT
    }

    ;-- Create/Populate the TOOLINFO structure
    uFlags := TTF_IDISHWND | TTF_SUBCLASS
    cbSize := VarSetCapacity(TOOLINFO,(A_PtrSize=8) ? 64:44,0)
    NumPut(cbSize,      TOOLINFO,0,"UInt")              ;-- cbSize
    NumPut(uFlags,      TOOLINFO,4,"UInt")              ;-- uFlags
    NumPut(HWND_DESKTOP,TOOLINFO,8,"Ptr")               ;-- hwnd
    NumPut(p1,          TOOLINFO,(A_PtrSize=8) ? 16:12,"Ptr")
        ;-- uId

    ;-- Check to see if tool has already been registered for the control
    SendMessage, A_IsUnicode ? TTM_GETTOOLINFOW : TTM_GETTOOLINFOA
               , 0, &TOOLINFO,, ahk_id %hTT%

    l_RegisteredTool := ErrorLevel

    ;-- Update the TOOLTIP structure
    NumPut(&p2, TOOLINFO, (A_PtrSize=8) ? 48 : 36,"Ptr")
        ;-- lpszText

    ;-- Add, Update, or Delete tool
    if l_RegisteredTool
    {
        if StrLen(p2)
            SendMessage, A_IsUnicode ? TTM_UPDATETIPTEXTW : TTM_UPDATETIPTEXTA, 0, &TOOLINFO,, ahk_id %hTT%
        else
            SendMessage, A_IsUnicode ? TTM_DELTOOLW : TTM_DELTOOLA, 0, &TOOLINFO,, ahk_id %hTT%
    } else if StrLen(p2)
    {
        SendMessage, A_IsUnicode ? TTM_ADDTOOLW : TTM_ADDTOOLA, 0, &TOOLINFO,, ahk_id %hTT%
    }

    If (darkMode=1)
       DllCall("uxtheme\SetWindowTheme", "ptr", HTT, "str", "DarkMode_Explorer", "ptr", 0)

    ;-- Restore DetectHiddenWindows
    DetectHiddenWindows %l_DetectHiddenWindows%

    ;-- Return the handle to the tooltip control
    Return hTT
}

WinMoveZ(hWnd, C, X, Y, W, H, Redraw:=0) {
  ; WinMoveZ v0.5 by SKAN on D35V/D361 - https://www.autohotkey.com/boards/viewtopic.php?f=6&t=76745
  ; If Redraw=2, the new coordinates will be returned
  ; Moves a window to given coordinates, but confines the window within the work area of the target monitor.
  ; Which target monitor? : Whichever monitor POINT (X, Y) belongs to
  ; What if POINT doesn't belong to any monitor? : The monitor nearest to the POINT will house the window.

  Local V := VarSetCapacity(R, 48, 0), TPM_WORKAREA := 0x10000
      , A := &R + 16, S := &R + 24, E := &R, NR := &R + 32

  C := ( C:=Abs(C) ) ? DllCall("SetRect", "Ptr",&R, "Int",X-C, "Int",Y-C, "Int",X+C, "Int",Y+C) : 0
  DllCall("SetRect", "Ptr",&R+16, "Int",X, "Int",Y, "Int",W, "Int",H)
  DllCall("CalculatePopupWindowPosition", "Ptr",A, "Ptr",S, "UInt",TPM_WORKAREA, "Ptr",E, "Ptr",NR)
  X := NumGet(NR+0,"Int")
  Y := NumGet(NR+4,"Int")
  If (Redraw=2)
     Return [X, Y]
  Else 
     Return DllCall("MoveWindow", "Ptr",hWnd, "Int",X, "Int",Y, "Int",W, "Int",H, "Int",Redraw)
}

