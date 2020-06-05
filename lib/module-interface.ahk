#Persistent
#NoTrayIcon
SetWinDelay, 1
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3
     , PVhwnd, hGDIwin, hGDIthumbsWin, appTitle, WindowBgrColor, mainCompiledPath
     , winGDIcreated := 0, ThumbsWinGDIcreated := 0, MainExe := AhkExported()
     , RegExFilesPattern, AnyWindowOpen := 0, easySlideStoppage := 0, lastOtherWinClose := 1
     , slideShowRunning := 0, toolTipGuiCreated, editDummy, LbtnDwn := 0
     , mustAbandonCurrentOperations := 0, lastCloseInvoked := -1, allowGIFsPlayEntirely := 0
     , hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
     , hCursN := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
     , hCursMove := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
     , hCursFinger := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32649, "Ptr")
     , SlideHowMode := 1, lastWinDrag := 1, TouchScreenMode := 0, allowNextSlide := 1
     , isTitleBarHidden := 0, imageLoading := 0, hPicOnGui1, hotkeysSuspended := 0
     , slideShowDelay := 9000, scriptStartZeit := A_TickCount, prevFullIMGload := 1
     , maxFilesIndex := 0, thumbsDisplaying := 0, executingCanceableOperation := 1
     , runningLongOperation := 0, alterFilesIndex := 0, animGIFplaying := 0, prevOpenedFile := 0
     , canCancelImageLoad := 0, hGDIinfosWin, hGDIselectWin, hasAdvancedSlide := 1
     , imgEditPanelOpened := 0, showMainMenuBar := 1, undoLevelsRecorded := 0, UserMemBMP := 0
     , taskBarUI, hSetWinGui, panelWinCollapsed, groppedFiles

Global activateImgSelection, allowMultiCoreMode, allowRecordHistory, alwaysOpenwithFIM, animGIFsSupport, askDeleteFiles
, AutoDownScaleIMGs, autoPlaySNDs, autoRemDeadEntry, ColorDepthDithering, countItemz, currentFileIndex, CurrentSLD, defMenuRefreshItm, doSlidesTransitions
, DynamicFoldersList, easySlideStoppage, editingSelectionNow, EllipseSelectMode, enableThumbsCaching, filesFilter, FlipImgH, FlipImgV, hSNDmedia, imgFxMode
, IMGresizingMode, imgSelX2, imgSelY2, LimitSelectBoundsImg, markedSelectFile, maxFilesIndex, minimizeMemUsage, mustGenerateStaticFolders, MustLoadSLDprefs
, noTooltipMSGs, PrefsLargeFonts, RenderOpaqueIMG, resetImageViewOnChange, showHistogram, showImgAnnotations, showInfoBoxHUD, showSelectionGrid, skipDeadFiles
, skipSeenImagesSlider, SLDcacheFilesList, SLDhasFiles, sldsPattern, syncSlideShow2Audios, thumbnailsListMode, thumbsCacheFolder, thumbsDisplaying, totalFramesIndex
, TouchScreenMode, userHQraw, userimgQuality, UserMemBMP, usrTextureBGR, 

; OnMessage(0x388, "WM_PENEVENT")
; OnMessage(0x2a3, "ResetLbtn") ; WM_MOUSELEAVE
OnMessage(0x112, "WM_SYSMENU")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x202, "WM_LBUTTONUP")
OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x207, "WM_MBUTTONDOWN")
; OnMessage(0x203, "WM_LBUTTON_DBL") ; WM_LBUTTONDOWN double click
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
   mainCompiledPath := MainExe.ahkgetvar.mainCompiledPath
   isTitleBarHidden := MainExe.ahkgetvar.isTitleBarHidden
   RegExFilesPattern := MainExe.ahkgetvar.RegExFilesPattern
   TouchScreenMode := MainExe.ahkgetvar.TouchScreenMode
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialWh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3
   ; If !A_IsCompiled
     Try Menu, Tray, Icon, %mainCompiledPath%\quick-picto-viewer.ico

   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   Gui, 1: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
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

   addJournalEntry("DIALOG BOX: " msg "`n`nUser answered: " r)
   Return r
}

addJournalEntry(msg) {
   If (!runningLongOperation && !imageLoading)
      MainExe.ahkPostFunction(A_ThisFunc, msg)
}

WM_LBUTTONDOWN(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartZeit<500)
       Return

    LbtnDwn := 1
    If (hotkeysSuspended=1)
       UnlockKeys()

    SetTimer, ResetLbtn, -55
    If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900) && slideShowRunning!=1 && animGIFplaying!=1)
       askAboutStoppingOperations()
}

WM_LBUTTONUP(wP, lP, msg, hwnd) {
    LbtnDwn := 0
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
       MainExe.ahkPostFunction("toggleImgEditPanelWindow")
    } Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
    {
       askAboutStoppingOperations()
       Return
    } Else If !AnyWindowOpen
       MainExe.ahkPostFunction("ToggleThumbsMode")
}

WM_LBUTTON_DBL(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartZeit<500)
       Return

    If (hotkeysSuspended=1)
       UnlockKeys()

    If (slideShowRunning=1)
    {
       turnOffSlideshow()
       Return
    }

    MainExe.ahkPostFunction("WinClickAction", "double-click", A_GuiControl)
}

askAboutStoppingOperations() {
     If (mustAbandonCurrentOperations!=1)
     {
        lastCloseInvoked := 0
        msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
        If (msgResult="yes")
           mustAbandonCurrentOperations := 1
     } ; Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
}

WM_RBUTTONUP(wP, lP, msg, hwnd) {
  Static lastState := 0
  If (A_TickCount - scriptStartZeit<500)
     Return

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
     askAboutStoppingOperations()
     Return
  }

  GuiControl, 1:, editDummy, -
  If (thumbsDisplaying=1 && maxFilesIndex>0)
  {
     canCancelImageLoad := 4
     MainExe.ahkPostFunction("WinClickAction", "rclick", A_GuiControl)
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
      setTaskbarIconState("Normal")
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

  prevFullIMGload := A_TickCount
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

WinClickAction(param:=0) {
    canCancelImageLoad := 4
    ; If (A_GuiControlEvent="DoubleClick")
    ;    turnOffSlideshow()

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
  If (A_OSVersion="WIN_7" || A_OSVersion="WIN_XP")
     SetTimer, updateGDIwinPos, -5
}

changeMcursor(whichCursor) {
  Static lastInvoked := 1
  ; If (whichCursor="normal")
  ;    SetTimer, ResetLoadStatus, -20

  If (slideShowRunning=1 || animGIFplaying=1)
     Return

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
     ; SetTimer, ResetLoadStatus, -500
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

dummyCheckWin() {
   thisHwnd := WinActive("A")
   ; ToolTip, % hSetWinGui "`n" thisHwnd , , , 2
   If (imgEditPanelOpened=1 && AnyWindowOpen>0 && panelWinCollapsed=1 && thisHwnd=hSetWinGui)
      MainExe.ahkPostFunction("toggleImgEditPanelWindow")
}

activateMainWin() {
   Static lastInvoked := 1
   LbtnDwn := 0
   UnlockKeys()
   If (A_TickCount - lastInvoked > 530)
      GuiControl, 1:, editDummy, -

   If (imgEditPanelOpened=1 && AnyWindowOpen>0 && panelWinCollapsed=1)
      SetTimer, dummyCheckWin, -100

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

GuiSize(GuiHwnd, EventInfo, Width, Height) {
    PrevGuiSizeEvent := EventInfo
    prevGUIresize := A_TickCount
    turnOffSlideshow()
    canCancelImageLoad := 4
    delayu := (A_OSVersion="WIN_XP") ? -15 : -5
    SetTimer, miniGDIupdater, % delayu
}

GuiDropFiles(GuiHwnd, FileArray, CtrlHwnd, X, Y) {
   Static lastInvoked := 1
   If (AnyWindowOpen>0 || runningLongOperation=1 || groppedFiles) || (A_TickCount - lastInvoked<300)
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

   lastInvoked := A_TickCount
   imgFiles := foldersList := sldFile := ""
   turnOffSlideshow()
   canCancelImageLoad := 4
   UnlockKeys()
   countFiles := 0
   Loop, Parse, groppedFiles, `n,`r
   {
      changeMcursor("busy")
      MainExe.ahkPostFunction("showTOOLtip", "Scanning for images...")
      line := Trimmer(A_LoopField)
      ; MsgBox, % A_LoopField
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
   } Else If ((AnyWindowOpen || thumbsDisplaying=1 || slideShowRunning=1) && (imageLoading!=1 && runningLongOperation!=1)) || (animGIFplaying=1)
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
   } Else If (StrLen(UserMemBMP)>3 && undoLevelsRecorded>1)
   {
      MainExe.ahkPostFunction("exitAppu", "external")
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
   Process, Close, % thisPID
   ExitApp
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

identifyThisWin() {
  Static prevR, lastInvoked := 1
  If (A_TickCount - lastInvoked < 150)
     Return prevR

  Az := WinActive("A")
  prevR := (Az=PVhwnd || Az=hGDIwin || Az=hGDIthumbsWin) ? 1 : 0
  lastInvoked := A_TickCount
  Return prevR
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
   MainExe.ahkPostFunction("dummyInfoToggleSlideShowu", "stop")
   If (slideShowDelay<950)
      SoundBeep , 900, 100
}

identifySettingsWindow() {
     A := WinActive("A")
     If (A=hSetWinGui || A=PVhwnd)
        Return 1
     Else
        Return 0
}

BuildFakeMenuBar() {
   ; main menu
   If (imgEditPanelOpened=1)
   {
      Menu, PVmenu, Add, HIDE PANEL, toggleImgEditPanelWindow
      Menu, PVmenu, Add, 
      If (AnyWindowOpen=10)
         Menu, PVmenu, Add, APPLY TO SELECTION, ApplyColorAdjustsSelectedArea
      Else
         Menu, PVmenu, Add, APPLY, applyIMGeditFunction
      Menu, PVmenu, Add, % (AnyWindowOpen=10) ? "CLOSE" : "CANCEL", tlbrCloseWindow
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, UNDO, ImgUndoAction
      Menu, PVmenu, Add, REDO, ImgRedoAction
      Menu, PVmenu, Add, 
      If (AnyWindowOpen=10)
         Menu, PVmenu, Add, SELECT, tlbrToggleImgSelection
      Else
         Menu, PVmenu, Add, SELECT ALL, MenuSelectAllAction
      Menu, PVmenu, Add, SQUARE, makeSquareSelection
      Menu, PVmenu, Add, FLIP, flipSelectionWH
      Menu, PVmenu, Add, IMAGE LIMITS, toggleLimitSelection
      Menu, PVmenu, Add, 
      If (AnyWindowOpen!=10)
         Menu, PVmenu, Add, ROTATE 45°, MenuSelRotation
      If (AnyWindowOpen=10)
         Menu, PVmenu, Add, RESET VIEW, BtnResetImageView
      Else
         Menu, PVmenu, Add, RESET, resetSelectionRotation
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, ADAPT IMAGE, ToggleImageSizingMode
      If (AnyWindowOpen=10)
         Menu, PVmenu, Add, TOGGLE FX, MenuToggleColorAdjustments
      Else
         Menu, PVmenu, Add, HIDE OBJECT, livePreviewsImageEditing
      Return
   }

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
   Menu, PVmenu, Add, ALL/NONE, MenuSelectAllAction
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, COPY, MenuCopyAction
   If (thumbsDisplaying!=1)
      Menu, PVmenu, Add, PASTE, tlbrPasteClipboardIMG
   Else
      Menu, PVmenu, Add, MOVE, PanelMoveCopyFiles
   Menu, PVmenu, Add, ERASE, deleteKeyAction
   Menu, PVmenu, Add, 
   Menu, PVmenu, Add, SEARCH, PanelSearchIndex
   Menu, PVmenu, Add, JUMP TO, PanelJump2index
   Menu, PVmenu, Add, RESET, ResetImageView
   If (thumbsDisplaying=1)
   {
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, MODES, toggleListViewModeThumbs
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, [ + ], changeZoomPlus
      Menu, PVmenu, Add, [ - ], changeZoomMinus
      Menu, PVmenu, Add, 
   } Else
   {
      Menu, PVmenu, Add, 
      Menu, PVmenu, Add, PLAY, dummyInfoToggleSlideShowu
      Menu, PVmenu, Add, INFO, ToggleHistoInfoBoxu
      Menu, PVmenu, Add, PREV. PANEL, openPreviousPanel
   }
}

dummy() {
   Sleep, -1
}

MenuSelRotation() {
  If !determineMenuBTNsOKAY()
     Return
  VPselRotation := MainExe.ahkgetvar.VPselRotation
  VPselRotation := Round(VPselRotation) + 45
  If (VPselRotation>350)
     VPselRotation := 0
  MainExe.ahkassign("VPselRotation", VPselRotation)
  MainExe.ahkPostFunction("dummyRefreshImgSelectionWindow")
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

livePreviewsImageEditing() {
  Static prevState := 0
  If !determineMenuBTNsOKAY()
     Return
  thisState := prevState + 1
  MainExe.ahkPostFunction(A_ThisFunc, 1, thisState)
  prevState := !prevState
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

tlbrToggleImgSelection() {
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

UpdateMenuBar() {
   Gui, 1: Menu
   deleteMenus()
   If (showMainMenuBar!=1)
      Return
   Sleep, 0
   BuildFakeMenuBar()
   Sleep, 0
   Gui, 1: Menu, PVmenu
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

   If (thumbsDisplaying=1)
      InvokeCopyFiles()
   Else
      CopyImage2clip()
}

MenuSelectAction() {
   If !determineMenuBTNsOKAY()
      Return

   If (thumbsDisplaying=1)
      MenuMarkThisFileNow()
   Else
      tlbrToggleImgSelection()
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
   } Else
      selectEntireImage("r")
}

MenuRefreshAction() {
   If !determineMenuBTNsOKAY()
      Return

   If (thumbsDisplaying=1)
      RefreshFilesList()
   Else
      RefreshImageFileAction()
}

MenuSaveAction() {
   If !determineMenuBTNsOKAY()
      Return

   If (thumbsDisplaying=1)
      PanelSaveSlideShowu()
   Else
      PanelSaveImg()
}

#If, (imgEditPanelOpened=1 || AnyWindowOpen>0) ; && (identifySettingsWindow()=1)
  ~^F4::
     If (identifySettingsWindow()=1)
        MainExe.ahkPostFunction("CloseWindow")
  Return

  ~F8::
  ~F11::
     If (identifySettingsWindow()=1)
        MainExe.ahkPostFunction("toggleImgEditPanelWindow")
  Return
#If

#If, (identifyThisWin()=1)
  ~Esc::
  ~!F4::
     canCancelImageLoad := 4
     If (AnyWindowOpen || animGIFplaying=1 || slideShowRunning=1)
        lastOtherWinClose := A_TickCount
     byeByeRoutine()
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
  ~BackSpace::
  ~Delete::
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
   /*
   ; URL:
   ;   - https://msdn.microsoft.com/en-us/library/windows/desktop/dd391559(v=vs.85).aspx (THUMBBUTTON structure)
   ;
   ;                           offsets:                     Contribution to size (bytes):   
   THUMBBUTTONMASK  dwMask            0                  ...         4
   UINT             iId            4                  ...         4
   UINT             iBitmap         8                  ...         4
   ;                                             ...         64-bit: add 4 bytes spacing, pointer address, adr, needs to be mod(adr,A_PtrSize)=0
   HICON            hIcon            8+A_PtrSize            ...         A_PtrSize
   WCHAR            szTip[260]         8+2*A_PtrSize         ...         260*2
   THUMBBUTTONFLAGS dwFlags         8+2*A_PtrSize+260*2      ...         4
   ;                                                      Sum: 32-bit: 4+4+4+0+A_PtrSize+260*2+4=540, 540/A_PtrSize=135, no spacing needed. EDIT: FIXED miscalculation thumbuttonSize = 540, not 544 ...
   ;                                                      Sum: 64-bit: 4+4+4+4+A_PtrSize+260*2+4=548, 548/A_PtrSize=68.5 -> add 4 bytes, 552/A_PtrSize=69 (mod(552,A_Ptrsize)=0).
   ;                                                      64-bit: add 4 bytes spacing to next struct in array
   ;                                                      Summary: size:= A_PtrSize=4?544:552
   
   */
   ;
   ; NOTE:
   ;
   ;          <   >   <   >   <   >   <   >   <   >   <   >               Context:                  <   >   <   >   <   >   <   >   <   >   <   >
   ;          <   >   <   >   <   >   <   >   <   >   <   >          this = taskbarInterface            <   >   <   >   <   >   <   >   <   >   <   >
   ;          <   >   <   >   <   >   <   >   <   >   <   >                                       <   >   <   >   <   >   <   >   <   >   <   >
   ;
   ;
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

   min(x,y){
      return (x<y)*x+(y<=x)*y
   }
   ; Additional reference:
   ; ShObjIdl.h:
   /*
    typedef struct ITaskbarList3Vtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE *QueryInterface )(                            (0)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in REFIID riid,
             [annotation][iid_is][out]  
            _COM_Outptr_  void **ppvObject);
        
        ULONG ( STDMETHODCALLTYPE *AddRef )(                                  (1)
            __RPC__in ITaskbarList3 * This);
        
        ULONG ( STDMETHODCALLTYPE *Release )(                                 (2) 
            __RPC__in ITaskbarList3 * This);
        
        HRESULT ( STDMETHODCALLTYPE *HrInit )(                                  (3)
            __RPC__in ITaskbarList3 * This);
        
        HRESULT ( STDMETHODCALLTYPE *AddTab )(                                  (4)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd);
        
        HRESULT ( STDMETHODCALLTYPE *DeleteTab )(                               (5)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd);
        
        HRESULT ( STDMETHODCALLTYPE *ActivateTab )(                            (6)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd);
        
        HRESULT ( STDMETHODCALLTYPE *SetActiveAlt )(                           (7)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd);
        
        HRESULT ( STDMETHODCALLTYPE *MarkFullscreenWindow )(                      (8)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  BOOL fFullscreen);
        
        HRESULT ( STDMETHODCALLTYPE *SetProgressValue )(                         (9)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  ULONGLONG ullCompleted,
             [in]  ULONGLONG ullTotal);
        
        HRESULT ( STDMETHODCALLTYPE *SetProgressState )(                         (10)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  TBPFLAG tbpFlags);
        
        HRESULT ( STDMETHODCALLTYPE *RegisterTab )(                            (11)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwndTab,
             [in]  __RPC__in HWND hwndMDI);
        
        HRESULT ( STDMETHODCALLTYPE *UnregisterTab )(                            (12)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwndTab);
        
        HRESULT ( STDMETHODCALLTYPE *SetTabOrder )(                            (13)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwndTab,
             [in]  __RPC__in HWND hwndInsertBefore);
        
        HRESULT ( STDMETHODCALLTYPE *SetTabActive )(                            (14)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwndTab,
             [in]  __RPC__in HWND hwndMDI,
             [in]  DWORD dwReserved);
        
        HRESULT ( STDMETHODCALLTYPE *ThumbBarAddButtons )(                         (15)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  UINT cButtons,
             [size_is][in]  __RPC__in_ecount_full(cButtons) LPTHUMBBUTTON pButton);    
        
        HRESULT ( STDMETHODCALLTYPE *ThumbBarUpdateButtons )(                      (16)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  UINT cButtons,
             [size_is][in]  __RPC__in_ecount_full(cButtons) LPTHUMBBUTTON pButton);
        
        HRESULT ( STDMETHODCALLTYPE *ThumbBarSetImageList )(                      (17)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  __RPC__in_opt HIMAGELIST himl);
        
        HRESULT ( STDMETHODCALLTYPE *SetOverlayIcon )(                            (18)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  __RPC__in HICON hIcon,
             [string][unique][in]  __RPC__in_opt_string LPCWSTR pszDescription);
        
        HRESULT ( STDMETHODCALLTYPE *SetThumbnailTooltip )(                      (19)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [string][unique][in]  __RPC__in_opt_string LPCWSTR pszTip);
        
        HRESULT ( STDMETHODCALLTYPE *SetThumbnailClip )(                         (20)
            __RPC__in ITaskbarList3 * This,
             [in]  __RPC__in HWND hwnd,
             [in]  __RPC__in RECT *prcClip);
        
        END_INTERFACE
    } ITaskbarList3Vtbl;
   */
}


