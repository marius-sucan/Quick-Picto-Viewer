#Persistent
#NoTrayIcon
SetWinDelay, 1
SetBatchLines, -1

Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3
     , PVhwnd, hGDIwin, hGDIthumbsWin, appTitle, WindowBgrColor
     , winGDIcreated := 0, ThumbsWinGDIcreated := 0, MainExe := AhkExported()
     , RegExFilesPattern, AnyWindowOpen := 0, easySlideStoppage
     , slideShowRunning := 0, toolTipGuiCreated, editDummy, LbtnDwn := 0
     , mustAbandonCurrentOperations := 0, lastCloseInvoked := 0
     , hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
     , hCursN := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
     , hCursMove := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
     , hCursFinger := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32649, "Ptr")
     , SlideHowMode := 1, lastWinDrag := 1, TouchScreenMode := 0
     , isTitleBarHidden := 0, imageLoading := 0, hPicOnGui1, hotkeysSuspended := 0
     , slideShowDelay := 9000, scriptStartZeit := A_TickCount, prevFullIMGload := 1
     , maxFilesIndex := 0, thumbsDisplaying := 0, executingCanceableOperation := 1
     , runningLongOperation := 0, alterFilesIndex := 0, animGIFplaying := 0
     , canCancelImageLoad := 0, hGDIinfosWin, hGDIselectWin, hasAdvancedSlide := 1
     , imgEditPanelOpened := 0, showMainMenuBar := 1

Global activateImgSelection, allowGIFsPlayEntirely, allowMultiCoreMode, allowRecordHistory, alwaysOpenwithFIM, animGIFsSupport, AnyWindowOpen, askDeleteFiles
, AutoDownScaleIMGs, autoPlaySNDs, autoRemDeadEntry, ColorDepthDithering, countItemz, currentFileIndex, CurrentSLD, defMenuRefreshItm, doSlidesTransitions
, DynamicFoldersList, easySlideStoppage, editingSelectionNow, EllipseSelectMode, enableThumbsCaching, filesFilter, FlipImgH, FlipImgV, hSNDmedia, imgFxMode
, IMGresizingMode, imgSelX2, imgSelY2, LimitSelectBoundsImg, markedSelectFile, maxFilesIndex, minimizeMemUsage, mustGenerateStaticFolders, MustLoadSLDprefs
, noTooltipMSGs, PrefsLargeFonts, RenderOpaqueIMG, resetImageViewOnChange, showHistogram, showImgAnnotations, showInfoBoxHUD, showSelectionGrid, skipDeadFiles
, skipSeenImagesSlider, SLDcacheFilesList, SLDhasFiles, sldsPattern, syncSlideShow2Audios, thumbnailsListMode, thumbsCacheFolder, thumbsDisplaying, totalFramesIndex
, TouchScreenMode, userHQraw, userimgQuality, UserMemBMP, usrTextureBGR, 

If !A_IsCompiled
   Try Menu, Tray, Icon, quick-picto-viewer.ico

; OnMessage(0x388, "WM_PENEVENT")
; OnMessage(0x2a3, "ResetLbtn") ; WM_MOUSELEAVE
OnMessage(0x112, "WM_SYSMENU")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x207, "WM_MBUTTONDOWN")
; OnMessage(0x203, "WM_LBUTTON_DBL") ; WM_LBUTTONDOWN double click
OnMessage(0x202, "ResetLbtn") ; WM_LBUTTONUP
OnMessage(0x216, "WM_MOVING")
; OnMessage(0x211, "WM_ENTERMENULOOP")
; OnMessage(0x212, "WM_EXITMENULOOP")
; OnMessage(0x125, "WM_EXITMENULOOP")
; OnMessage(0x126, "WM_EXITMENULOOP")

OnMessage(0x200, "WM_MOUSEMOVE")
; OnMessage(0x2A3, "WM_MOUSELEAVE")
OnMessage(0x06, "activateMainWin")   ; WM_ACTIVATE 
OnMessage(0x08, "activateMainWin")   ; WM_KILLFOCUS 

Loop, 9
    OnMessage(255+A_Index, "PreventKeyPressBeep")   ; 0x100 to 0x108

setPriorityThread(2)
; OnExit, doCleanup
Return

setPriorityThread(level, handle:="A") {
  If (handle="A" || !handle)
     handle := DllCall("GetCurrentThread")
  Return DllCall("SetThreadPriority", "UPtr", handle, "Int", level)
}

updateWindowColor() {
     ; WindowBgrColor := MainExe.ahkgetvar.WindowBgrColor
     Gui, 1: Color, %WindowBgrColor%
}

BuildGUI() {
   Critical, on
   appTitle := MainExe.ahkgetvar.appTitle
   WindowBgrColor := MainExe.ahkgetvar.WindowBgrColor
   isAlwaysOnTop := MainExe.ahkgetvar.isAlwaysOnTop
   isTitleBarHidden := MainExe.ahkgetvar.isTitleBarHidden
   RegExFilesPattern := MainExe.ahkgetvar.RegExFilesPattern
   TouchScreenMode := MainExe.ahkgetvar.TouchScreenMode
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialWh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3

   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Add, Text, x0 y0 w1 h1 BackgroundTrans gWinClickAction vPicOnGui1 hwndhPicOnGui1,
   Gui, 1: Add, Edit, xp-100 yp-100 gUnlockKeys w1 h1 veditDummy,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2a,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2b,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2c,
   Gui, 1: Add, Text, x3 y3 w3 h3 BackgroundTrans gWinClickAction vPicOnGui3,
   If (isTitleBarHidden=1)
      Gui, 1: +Caption
   Else
      Gui, 1: -Caption

   Gui, 1: Show, Maximize Center %initialwh%, %appTitle%
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
   MainExe.ahkassign("PVhwnd", PVhwnd)
   MainExe.ahkassign("hGDIinfosWin", hGDIinfosWin)
   MainExe.ahkassign("hGDIwin", hGDIwin)
   MainExe.ahkassign("hGDIthumbsWin", hGDIthumbsWin)
   MainExe.ahkassign("hGDIselectWin", hGDIselectWin)
   MainExe.ahkassign("hPicOnGui1", hPicOnGui1)
   MainExe.ahkassign("winGDIcreated", winGDIcreated)
   MainExe.ahkassign("ThumbsWinGDIcreated", ThumbsWinGDIcreated)
   WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
   Sleep, 1
   WinActivate, ahk_id %PVhwnd%
   Return 1
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
   GetClientSize(GuiW, GuiH, PVhwnd)
   If (forceThis=1)
   {
      editingSelectionNow := MainExe.ahkgetvar.editingSelectionNow
      activateImgSelection := MainExe.ahkgetvar.activateImgSelection
      isAlwaysOnTop := MainExe.ahkgetvar.isAlwaysOnTop
      WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%   
   }
   ctrlW := (editingSelectionNow=1 && activateImgSelection=1) ? GuiW//8 : GuiW//7
   ctrlH2 := (editingSelectionNow=1 && activateImgSelection=1) ? GuiH//6 : GuiH//5
   ctrlH3 := GuiH - ctrlH2*2
   ctrlW2 := GuiW - ctrlW*2
   ctrlY1 := ctrlH2
   ctrlY2 := ctrlH2*2
   ctrlY3 := ctrlH2 + ctrlH3
   ctrlX1 := ctrlW
   ctrlX2 := ctrlW + ctrlW2
   GuiControl, 1: Move, PicOnGUI1, % "w" ctrlW " h" GuiH
   GuiControl, 1: Move, PicOnGUI2a, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1
   GuiControl, 1: Move, PicOnGUI2b, % "w" ctrlW2 " h" ctrlH3 " x" ctrlX1 " y" ctrlY1
   GuiControl, 1: Move, PicOnGUI2c, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" ctrlY3
   GuiControl, 1: Move, PicOnGUI3, % "w" ctrlW " h" GuiH " x" ctrlX2 " y0"
}

createGDIwin() {
   Critical, on
   ; WinGetPos, , , mainW, mainH, ahk_id %PVhwnd%
   Gui, 2: -DPIScale +E0x20 -Caption +E0x80000 +hwndhGDIwin +Owner1
   Gui, 2: Show, NoActivate, %appTitle%: Picture container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIwin)
   winGDIcreated := 1
}

createGDIwinThumbs() {
   Critical, on

   Gui, 3: -DPIScale +E0x20 -Caption +E0x80000 +hwndhGDIthumbsWin +Owner1
   Gui, 3: Show, NoActivate, %appTitle%: Thumbnails container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIthumbsWin)

   ThumbsWinGDIcreated := 1
}

createGDIinfosWin() {
   Critical, on

   Gui, 4: -DPIScale +E0x20 -Caption +E0x80000 +hwndhGDIinfosWin +Owner1
   Gui, 4: Show, NoActivate, %appTitle%: Infos container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIinfosWin)

   InfosWinGDIcreated := 1
}

createGDIselectorWin() {
   Critical, on

   Gui, 5: -DPIScale +E0x20 -Caption +E0x80000 +hwndhGDIselectWin +Owner1
   Gui, 5: Show, NoActivate, %appTitle%: Selector container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIselectWin)

   SelectWinGDIcreated := 1
}

SetParentID(Window_ID, theOther) {
  r := DllCall("SetParent", "uint", theOther, "uint", Window_ID) ; success = handle to previous parent, failure =null 
  Return r
}

miniGDIupdater() {
   updateUIctrl(0)
   r := MainExe.ahkPostFunction("GDIupdater")
}

detectLongOperation(timer) {
  if (mustAbandonCurrentOperations=1)
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
   Gui, 1: +OwnDialogs
   FileSelectFile, file2save, % optionz, % startPath, % msg, % pattern
   If (!ErrorLevel && StrLen(file2save)>2)
      r := file2save
   ; WinActivate, ahk_id %PVhwnd%
   Return r
}

openFoldersDialogWrapper(optionz, startPath, msg) {
   Gui, 1: +OwnDialogs
   FileSelectFolder, SelectedDir, % startPath, % optionz, % msg
   If (!ErrorLevel && StrLen(SelectedDir)>2)
      r := SelectedDir
   ; WinActivate, ahk_id %PVhwnd%
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
        Return "Yes"
   IfMsgBox, No
        Return "No"
   IfMsgBox, OK
        Return "OK"
   IfMsgBox, Cancel
        Return "Cancel"
   IfMsgBox, Abort
        Return "Abort"
   IfMsgBox, Ignore
        Return "Ignore"
   IfMsgBox, Retry
        Return "Retry"
   IfMsgBox, Continue
        Return "Continue"
   IfMsgBox, TryAgain
        Return "TryAgain"
   Else
        Return 0
}

WM_LBUTTONDOWN(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartZeit<500)
       Return

    LbtnDwn := 1
    If (hotkeysSuspended=1)
       UnlockKeys()

    If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900) && slideShowRunning!=1 && animGIFplaying!=1)
    {
       If (mustAbandonCurrentOperations!=1)
       {
          lastCloseInvoked := 0
          msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
          If (msgResult="yes")
             mustAbandonCurrentOperations := 1
       } ; Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
    }

    SetTimer, ResetLbtn, -55
}

WM_MBUTTONDOWN(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartZeit<500)
       Return

    LbtnDwn := 0
    UnlockKeys()
    canCancelImageLoad := 4
    If (slideShowRunning=1 || animGIFplaying=1)
    {
       turnOffSlideshow()
       Return
    }
    If (imgEditPanelOpened=1)
    {
       MainExe.ahkPostFunction("CloseWindow")
    } Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
    {
       If (mustAbandonCurrentOperations!=1)
       {
          lastCloseInvoked := 0
          msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
          If (msgResult="yes")
             mustAbandonCurrentOperations := 1
       } Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
       Return
    } Else If !AnyWindowOpen
       MainExe.ahkPostFunction("ToggleThumbsMode")
}

WM_LBUTTON_DBL(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartZeit<500)
       Return
    If (hotkeysSuspended=1)
       UnlockKeys()

    MainExe.ahkPostFunction("WinClickAction", "double-click", A_GuiControl)
}

WM_RBUTTONUP(wP, lP, msg, hwnd) {
  If (A_TickCount - scriptStartZeit<500)
     Return

  Static lastState := 0
  If (slideShowRunning=1 || animGIFplaying=1)
  {
     turnOffSlideshow()
     Return
  }

  UnlockKeys()
  A := WinActive("A")
  ; thumbsDisplaying := MainExe.ahkgetvar.thumbsDisplaying
  ; AnyWindowOpen := MainExe.ahkgetvar.AnyWindowOpen
  ; maxFilesIndex := MainExe.ahkgetvar.maxFilesIndex
  okay := (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin) ? 1 : 0
  If (okay!=1)
     Return

  If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
  {
     If (mustAbandonCurrentOperations!=1)
     {
        lastCloseInvoked := 0
        msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
        If (msgResult="yes")
           mustAbandonCurrentOperations := 1
     } ; Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
     Return
  }

  GuiControl, 1:, editDummy, -
  If (thumbsDisplaying=1 && maxFilesIndex>0)
  {
     canCancelImageLoad := 4
     MainExe.ahkPostFunction("WinClickAction", "rclick", A_GuiControl)
     Return
  } Else If (AnyWindowOpen=10 || imgEditPanelOpened=1)
  {
     MainExe.ahkPostFunction("toggleImgEditPanelWindow")
     Return
  }

  delayu := (thumbsDisplaying=1) ? 90 : 2
  SetTimer, InitGuiContextMenu, % -delayu
}

InitGuiContextMenu() {
    MainExe.ahkPostFunction(A_ThisFunc)
}

slideshowsHandler(thisSlideSpeed, act, how) {
   SlideHowMode := how
   slideShowDelay := thisSlideSpeed
   prevFullIMGload := 1
   If (act="start")
   {
      slideShowRunning := 1
      SetTimer, theSlideShowCore, % -slideShowDelay
   } Else If (act="stop")
   {
      slideShowRunning := 0
      SetTimer, theSlideShowCore, Off
   }
}

dummySlideshow() {
   ; hasAdvancedSlide := (modus="gif") ? hasAdvancedSlide : 1
   If (slideShowRunning=1 && hasAdvancedSlide=1)
   {
      hasAdvancedSlide := 0
      SetTimer, theSlideShowCore, % -slideShowDelay
   }
}

theSlideShowCore() {
  thisZeit :=  A_TickCount - prevFullIMGload
  ; MsgBox, % thisZeit "--" slideShowDelay
  If (thisZeit < slideShowDelay//1.25)
     Return

  If (SlideHowMode=1)
     MainExe.ahkPostFunction("RandomPicture")
  Else If (SlideHowMode=2)
     MainExe.ahkPostFunction("PreviousPicture")
  Else If (SlideHowMode=3)
     MainExe.ahkPostFunction("NextPicture")
  hasAdvancedSlide := 1
}

updateGDIwinPos() {
  ; thumbsDisplaying := MainExe.ahkgetvar.thumbsDisplaying
  If (A_OSVersion="WIN_7")
     JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
  Else GuiX := GuiY := 1

  GetClientSize(mainWidth, mainHeight, PVhwnd)
  If (thumbsDisplaying=1)
  {
     WinMove, ahk_id %hGDIthumbsWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
     WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight% , ahk_id %hGDIthumbsWin%
  }
  WinMove, ahk_id %hGDIWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
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

WinClickAction(param:=0) {
    canCancelImageLoad := 4
    If (A_GuiControlEvent="DoubleClick")
       turnOffSlideshow()

    ; ToolTip, % param "--" A_GuiControl "--" A_GuiControlEvent , , , 2
    If (slideShowRunning=1)
       turnOffSlideshow()
    Else
       MainExe.ahkPostFunction("WinClickAction", A_GuiControlEvent, A_GuiControl)
}

ResetLbtn() {
  LbtnDwn := 0
}

WM_MOVING() {
  If (toolTipGuiCreated=1)
     MainExe.ahkPostFunction("TooltipCreator", 1, 1)

  Global lastWinDrag := A_TickCount
  If (A_OSVersion="WIN_7")
     SetTimer, updateGDIwinPos, -5
}

changeMcursor(whichCursor) {
  Static lastInvoked := 1
  If (whichCursor="normal")
     SetTimer, ResetLoadStatus, -20

  If (slideShowRunning=1 || animGIFplaying=1)
     Return

  If (whichCursor="busy" && LbtnDwn!=1)
     thisCursor := hCursBusy
  Else If (whichCursor="normal")
     thisCursor := hCursN
  Else If (whichCursor="finger")
     thisCursor := hCursFinger
  Else If (whichCursor="move")
     thisCursor := hCursMove
  Else Return


  Try DllCall("user32\SetCursor", "Ptr", thisCursor)
  lastInvoked := A_TickCount
}

ResetLoadStatus() {
   imageLoading := 0
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
}

WM_MOUSEMOVE(wP, lP, msg, hwnd) {
  Static lastInvoked := 1, prevPos
  If (A_TickCount - scriptStartZeit < 900)
     Return

  MouseGetPos, mX, mY
  thisPos := mX "-" mY
  If (A_TickCount - lastInvoked > 55) && (thisPos!=prevPos)
  {
     thisPrefsWinOpen := (imgEditPanelOpened=1) ? 0 : AnyWindowOpen
     lastInvoked := A_TickCount
     If (slideShowRunning!=1 && !thisPrefsWinOpen && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1)
        MainExe.ahkPostFunction("MouseMoveResponder")
     prevPos := mX "-" mY
  }

  If ((runningLongOperation=1 || imageLoading=1) && slideShowRunning!=1)
  {
     changeMcursor("busy")
     SetTimer, ResetLoadStatus, -500
  }

  ; A := WinActive("A")
  ; okay := (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin) ? 1 : 0
  If (wP&0x1)
  {
     LbtnDwn := 1
     SetTimer, ResetLbtn, -55
  }

  ; ToolTip, % isTitleBarHidden " - " TouchScreenMode
  If (isTitleBarHidden=0 && TouchScreenMode=0 && (wP&0x1))
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

WM_MOUSELEAVE() {
  SoundBeep 
}
activateMainWin() {
   Static lastInvoked := 1
   LbtnDwn := 0
   UnlockKeys()
   If (A_TickCount - lastInvoked > 530)
      GuiControl, 1:, editDummy, -

   lastInvoked := A_TickCount

/*
   If (A_TickCount - lastInvoked < 30)
      Return

   ; easySlideStoppage := MainExe.ahkgetvar.easySlideStoppage
   ; slideShowRunning := MainExe.ahkgetvar.slideShowRunning
   ; toolTipGuiCreated := MainExe.ahkgetvar.toolTipGuiCreated
   If (easySlideStoppage=1 && slideShowRunning=1)
      MainExe.ahkPostFunction("ToggleSlideShowu")

   If (toolTipGuiCreated=1)
      MainExe.ahkPostFunction("TooltipCreator", 1, 1)
*/
}

GuiSize:
    PrevGuiSizeEvent := A_EventInfo
    prevGUIresize := A_TickCount
    turnOffSlideshow()
    canCancelImageLoad := 4
    SetTimer, miniGDIupdater, -5
Return


GuiDropFiles:
   If (AnyWindowOpen>0 || runningLongOperation=1)
      Return

   imgFiles := foldersList := sldFile := ""
   turnOffSlideshow()
   canCancelImageLoad := 4
   UnlockKeys()
   countFiles := 0
   Loop, Parse, A_GuiEvent, `n,`r
   {
      changeMcursor("busy")
      MainExe.ahkPostFunction("showTOOLtip", "Scanning for images...")
      line := Trim(A_LoopField)
;     MsgBox, % A_LoopField
      If (A_Index>9900)
      {
         Break
      } Else If RegExMatch(line, "i)(.\.sld)$")
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

   MainExe.ahkPostFunction("GuiDroppedFiles", imgFiles, foldersList, sldFile, countFiles)
Return

1GuiClose:
GuiClose:
doCleanup:
   byeByeRoutine()
Return

byeByeRoutine() {
   Static lastInvoked := 1, lastInvokedThis := 1

   If (A_TickCount - lastInvokedThis < 350)
      Return

   If (runningLongOperation!=1 && imageLoading=1 && animGIFplaying!=1)
   {
      ; SoundBeep , % 250 + 100*lastCloseInvoked, 100
      canCancelImageLoad := 4
      msgResult := msgBoxWrapper(appTitle, "The main window is busy at the moment, do you want to force exit?", 4, 0, "question")
      If (msgResult="yes")
         SetTimer, TimerExit, -10
      Else lastCloseInvoked := 0
      lastCloseInvoked++
      Return
   } Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
   {
      If (mustAbandonCurrentOperations!=1)
      {
         lastCloseInvoked := 0
         msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
         If (msgResult="yes")
            mustAbandonCurrentOperations := 1
      } Else lastCloseInvoked++
      Return
   } Else If (AnyWindowOpen || thumbsDisplaying=1 || slideShowRunning=1) && (imageLoading!=1 && runningLongOperation!=1) || (animGIFplaying=1)
   {
      lastInvokedThis := A_TickCount
      lastInvoked := A_TickCount
      If AnyWindowOpen
      {
         AnyWindowOpen := 0
         MainExe.ahkPostFunction("CloseWindow")
      } Else If (animGIFplaying=1)
      {
         If (slideShowRunning=1)
            turnOffSlideshow()
         animGIFplaying := 0
         MainExe.ahkPostFunction("autoChangeDesiredFrame", "stop")
      } Else If (slideShowRunning=1)
      {
         turnOffSlideshow()
      } Else If (thumbsDisplaying=1)
      {
         thumbsDisplaying := 0
         MainExe.ahkPostFunction("MenuReturnIMGedit")
      } Else lastCloseInvoked++
      Return
   } Else lastCloseInvoked := 10

   If (lastCloseInvoked>2)
   {
      SetTimer, TimerExit, % (lastCloseInvoked=10) ? -950 : -10
      MainExe.ahkPostFunction("TrueCleanup", 1)
   }
   lastInvoked := A_TickCount
}

TimerExit() {
   ; SoundBeep 
   thisPID := GetCurrentProcessId()
   Process, Close, % thisPID
   ExitApp
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

identifyThisWin() {
  A := WinActive("A")
  If (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin)
     Return 1
  Else
     Return 0
}

WM_ENTERMENULOOP() {
  If (runningLongOperation!=1 && imageLoading!=1)
  {
     hotkeysSuspended := 1
     MainExe.ahkPostFunction("doSuspendu", 1)
  }
}

WM_EXITMENULOOP() {
; it does not work; why ? ^_^ 
  SetTimer, unSuspendu, -150
}

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND := 0x112, TPM_RETURNCMD := 0x100
  turnOffSlideshow()
  MainExe.ahkPostFunction("doSuspendu", 1)
  h := WinExist("ahk_id " hwnd)
  JEE_ClientToScreen(hPicOnGui1, 1, 1, X, Y)
  SetTimer, unSuspendu, -150
  hSysMenu := DllCall("GetSystemMenu", "Uint", Hwnd, "int", False) 
  r := DllCall("TrackPopupMenu", "uint", hSysMenu, "uint", TPM_RETURNCMD, "int", X, "int", Y, "int", 0, "uint", h, "uint", 0)
  If (r=0)
     Return

  SendMessage, WM_SYSCOMMAND, r,,,ahk_id %Hwnd%
  Return 1
}

unSuspendu() {
  MainExe.ahkPostFunction("doSuspendu", 0)
}

WM_SYSMENU(wParam, lParam, lol) {
  If (wParam=61587)
  {
     hotkeysSuspended := 1
     MainExe.ahkPostFunction("doSuspendu", 1)
  } Else UnlockKeys()
  ; ToolTip, % wParam "--" lParam "--" lol
}

UnlockKeys() {
  If (hotkeysSuspended=1)
  {
     hotkeysSuspended := 0
     MainExe.ahkPostFunction("doSuspendu", 0)
  }
}

turnOffSlideshow() {
   If (animGIFplaying=1)
   {
      animGIFplaying := 0
      MainExe.ahkPostFunction("autoChangeDesiredFrame", "stop")
   }

   If (slideShowRunning!=1)
      Return

   slideShowRunning := 0
   SetTimer, theSlideShowCore, Off
   If (slideShowDelay<950)
      SoundBeep , 900, 100
   MainExe.ahkPostFunction("dummyInfoToggleSlideShowu", "stop")
}

#If, (identifyThisWin()=1)
  ~Esc::
  ~!F4::
     canCancelImageLoad := 4
     byeByeRoutine()
  Return

  ~F11::
     If (imgEditPanelOpened=1)
        MainExe.ahkPostFunction("toggleImgEditPanelWindow")
  Return

  !Space::
     Win_ShowSysMenu(PVhwnd)
  Return
#If

#If, (((animGIFplaying=1) || (canCancelImageLoad=1) || (thumbsDisplaying=1 && imageLoading=1)) && identifyThisWin()=1)
  ~Left::
  ~Up::
  ~PgUp::
  ~Right::
  ~Down::
  ~PgDn::
  ~Home::
  ~End::
     alterFilesIndex++
     canCancelImageLoad := 4
     If (animGIFplaying=1)
        animGIFplaying := 0
  Return
#If

#If, (thumbsDisplaying=1 && imageLoading=1 && identifyThisWin()=1)
  ~vkBB::   ; plus
  ~vkBD::   ; minus
     alterFilesIndex++
  Return
#If

#If, ((animGIFplaying=1 || slideShowRunning=1) && (identifyThisWin()=1))
  ~Space::
     turnOffSlideshow()
  Return
#If












MenuCopyAction() {
   If (thumbsDisplaying=1)
      InvokeCopyFiles()
   Else
      CopyImage2clip()
}

MenuSelectAction() {
   If (thumbsDisplaying=1)
      MenuMarkThisFileNow()
   Else
      ToggleEditImgSelection()
}

MenuSelectAllAction() {
   If (thumbsDisplaying=1)
      MenuMarkThisFileNow()
   Else
      ToggleEditImgSelection()
}

MenuRefreshAction() {
   If (thumbsDisplaying=1)
      RefreshFilesList()
   Else
      RefreshImageFileAction()
}

MenuSaveAction() {
   If (thumbsDisplaying=1)
      SaveFilesList()
   Else
      SaveClipboardImage("yay")
}

BuildFakeMenu() {

; main menu
   infoThumbsMode := (thumbsDisplaying=1) ? "IMAGE VIEW" : "LIST VIEW"
   Menu, PVmenu, Add, MENU, InitGuiContextMenu
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, OPEN, OpenDialogFiles
   Menu, PVmenu, Add, SAVE, MenuSaveAction
   Menu, PVmenu, Add, REFRESH, MenuRefreshAction
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, %infoThumbsMode%, MenuDummyToggleThumbsMode
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, SELECT, MenuSelectAction
   Menu, PVmenu, Add, ALL/NONE, dummy
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, COPY, MenuCopyAction
   If (thumbsDisplaying!=1)
      Menu, PVmenu, Add, PASTE, MenuCopyAction
   Menu, PVmenu, Add, ERASE, MenuCopyAction
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, SEARCH, PanelSearchIndex
   Menu, PVmenu, Add, JUMP TO, PanelJump2index
   Menu, PVmenu, Add, RESET, ResetImageView
   If (thumbsDisplaying=1)
   {
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, [ + ], dummy
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, [ - ], dummy
      Menu, PVmenu, Add, 
   } Else
   {
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, PLAY, dummyInfoToggleSlideShowu
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, INFO, ToggleHistoInfoBoxu
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, PREV. PANEL, openPreviousPanel
      Menu, PVmenu, Add, 
   }
}

CopyImage2clip() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

CopyImagePath() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

dummy() {
   Sleep, -1
}

dummyInfoToggleSlideShowu() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

MenuMarkThisFileNow() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

OpenDialogFiles() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelJump2index() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

InvokeCopyFiles() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelPasteInPlace() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

PanelSearchIndex() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

PasteClipboardIMG() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

RefreshFilesList() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

RefreshImageFileAction() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

RegenerateEntireList() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

SaveClipboardImage(arg) {
  MainExe.ahkPostFunction(A_ThisFunc, arg)
}

SaveFilesList() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

selectAllFiles() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

ResetImageView() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

toggleListViewModeThumbs() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

MenuDummyToggleThumbsMode() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

openPreviousPanel() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

ToggleHistoInfoBoxu() {
  MainExe.ahkPostFunction(A_ThisFunc)
}

ToggleEditImgSelection() {
  MainExe.ahkPostFunction(A_ThisFunc)
}


deleteMenus() {
    Static menusList := "PVmenu|"
    Loop, Parse, menusList, |
        Try Menu, % A_LoopField, Delete
}

UpdateMenuBar() {
   Gui, 1: Menu
   deleteMenus()
   If (showMainMenuBar!=1)
      Return
   Sleep, 1
   BuildFakeMenu()
   Sleep, 0
   Gui, 1: Menu, PVmenu
}
