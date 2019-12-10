#Persistent
#NoTrayIcon
SetWinDelay, 1
SetBatchLines, -1

Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3
     , PVhwnd, hGDIwin, hGDIthumbsWin, appTitle, WindowBgrColor
     , winGDIcreated := 0, ThumbsWinGDIcreated := 0, MainExe := AhkExported()
     , RegExFilesPattern, AnyWindowOpen := 0, easySlideStoppage
     , slideShowRunning, toolTipGuiCreated, editDummy, LbtnDwn := 0
     , mustAbandonCurrentOperations := 0, lastCloseInvoked := 0
     , hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
     , hCursN := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
     , hCursMove := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
     , hCursFinger := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32649, "Ptr")
     , SlideHowMode := 1, lastWinDrag := 1, TouchScreenMode := 0
     , isTitleBarHidden := 0, imageLoading := 0, hPicOnGui1, hotkeysSuspended := 0

; OnMessage(0x388, "WM_PENEVENT")
; OnMessage(0x2a3, "ResetLbtn") ; WM_MOUSELEAVE
OnMessage(0x112, "WM_SYSMENU")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x207, "WM_MBUTTONDOWN")
OnMessage(0x203, "WM_LBUTTON_DBL") ; WM_LBUTTONDOWN double click
OnMessage(0x202, "ResetLbtn") ; WM_LBUTTONUP
OnMessage(0x216, "WM_MOVING")

OnMessage(0x200, "WM_MOUSEMOVE")
OnMessage(0x06, "activateMainWin")   ; WM_ACTIVATE 
OnMessage(0x08, "activateMainWin")   ; WM_KILLFOCUS 

Loop, 9
    OnMessage(255+A_Index, "PreventKeyPressBeep")   ; 0x100 to 0x108

; OnExit, doCleanup
Return

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
   initialwh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3
   Gui, 1: Destroy
   Sleep, 30
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
   createGDIwinThumbs()
   Sleep, 2
   createGDIwin()
   updateUIctrl(1)
   Sleep, 1
   MainExe.ahkassign("PVhwnd", PVhwnd)
   MainExe.ahkassign("hGDIwin", hGDIwin)
   MainExe.ahkassign("hGDIthumbsWin", hGDIthumbsWin)
   MainExe.ahkassign("hPicOnGui1", hPicOnGui1)
   MainExe.ahkassign("winGDIcreated", winGDIcreated)
   MainExe.ahkassign("ThumbsWinGDIcreated", ThumbsWinGDIcreated)
   WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
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
   ctrlW := (editingSelectionNow=1 && activateImgSelection=1) ? GuiW//8 : GuiW//5
   ctrlH2 := (editingSelectionNow=1 && activateImgSelection=1) ? GuiH//6 : GuiH//3
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
   Sleep, 35
   WinGetPos, , , mainW, mainH, ahk_id %PVhwnd%
   Gui, 2: -DPIScale +hwndhGDIwin +E0x20 -Caption +E0x80000 +Owner1
   Gui, 2: Show, NoActivate, %appTitle%: Picture container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIwin)
   Sleep, 5
   WinActivate, ahk_id %PVhwnd%
   Sleep, 5
   winGDIcreated := 1
}

createGDIwinThumbs() {
   Critical, on
   Sleep, 15
   Gui, 3: Destroy
   Sleep, 35
   Gui, 3: -DPIScale +E0x20 -Caption +E0x80000 +hwndhGDIthumbsWin +Owner1
   Gui, 3: Show, NoActivate, %appTitle%: Thumbnails container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIthumbsWin)
   Sleep, 5
   WinActivate, ahk_id %PVhwnd%
   Sleep, 5
   ThumbsWinGDIcreated := 1
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
  LbtnDwn := 1
  If (hotkeysSuspended=1)
     UnlockKeys()
  Else
     detectLongOperation(600)
  SetTimer, ResetLbtn, -55
}

WM_MBUTTONDOWN(wP, lP, msg, hwnd) {
  LbtnDwn := 0
  MainExe.ahkPostFunction("ToggleThumbsMode")
}

WM_LBUTTON_DBL(wP, lP, msg, hwnd) {
    MainExe.ahkPostFunction("WinClickAction", "double-click", A_GuiControl)
}

WM_RBUTTONUP(wP, lP, msg, hwnd) {
  Static lastState := 0
  UnlockKeys()
  A := WinActive("A")
  thumbsDisplaying := MainExe.ahkgetvar.thumbsDisplaying
  AnyWindowOpen := MainExe.ahkgetvar.AnyWindowOpen
  maxFilesIndex := MainExe.ahkgetvar.maxFilesIndex
  okay := (A=PVhwnd || A=hGDIwin || hwndhGDIthumbsWin) ? 1 : 0
  If (okay!=1)
     Return

  GuiControl, 1:, editDummy, -
  If (thumbsDisplaying=1 && maxFilesIndex>0)
  {
     MainExe.ahkPostFunction("WinClickAction", "rclick", A_GuiControl)
  } Else If (AnyWindowOpen=10)
  {
     MainExe.ahkPostFunction("toggleColorsAdjusterPanelWindow", lastState)
     lastState := !lastState
     Return
  }

  delayu := (thumbsDisplaying=1) ? 90 : 2
  SetTimer, InitGuiContextMenu, % -delayu
}

InitGuiContextMenu() {
    MainExe.ahkPostFunction("InitGuiContextMenu")
}

slideshowsHandler(thisSlideSpeed, act, how) {
   SlideHowMode := how
   If (act="start")
   {
      slideShowRunning := 1
      SetTimer, theSlideShowCore, % thisSlideSpeed
   } Else If (act="stop")
   {
      slideShowRunning := 0
      SetTimer, theSlideShowCore, Off
   }
}

theSlideShowCore() {
  If (SlideHowMode=1)
     MainExe.ahkPostFunction("RandomPicture")
  Else If (SlideHowMode=2)
     MainExe.ahkPostFunction("PreviousPicture")
  Else If (SlideHowMode=3)
     MainExe.ahkPostFunction("NextPicture")
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
    MainExe.ahkPostFunction("WinClickAction", 0, A_GuiControl)
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
  If (whichCursor="busy" && LbtnDwn!=1)
     thisCursor := hCursBusy
  Else If (whichCursor="normal")
     thisCursor := hCursN
  Else If (whichCursor="finger")
     thisCursor := hCursFinger
  Else If (whichCursor="move")
     thisCursor := hCursMove
  Else Return

  If (whichCursor="normal")
     SetTimer, ResetLoadStatus, -20

  Try DllCall("user32\SetCursor", "Ptr", thisCursor)
  lastInvoked := A_TickCount
}

ResetLoadStatus() {
   imageLoading := 0
}

WM_MOUSEMOVE(wP, lP, msg, hwnd) {
  Static lastInvoked := 1
  If (imageLoading=1 && slideShowRunning!=1)
  {
     changeMcursor("busy")
     SetTimer, ResetLoadStatus, -700
  }

  ; A := WinActive("A")
  ; okay := (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin) ? 1 : 0
  If (wP&0x1)
  {
     LbtnDwn := 1
     SetTimer, ResetLbtn, -55
  }

  MainExe.ahkPostFunction("MouseMoveResponder")
  ; ToolTip, % isTitleBarHidden " - " TouchScreenMode
  If (isTitleBarHidden=0 && TouchScreenMode=0 && (wP&0x1))
  && (A_TickCount - lastWinDrag>45) 
  {
     PostMessage, 0xA1, 2,,, ahk_id %PVhwnd%
     lastWinDrag := A_TickCount
     ; MainExe.ahkassign("lastWinDrag", lastWinDrag)
     SetTimer, trackMouseDragging, -55
     Return
  } 
  lastInvoked := A_TickCount
}

trackMouseDragging() {
    lastWinDrag := A_TickCount
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
   SetTimer, miniGDIupdater, -5
Return


GuiDropFiles:
   imgPath := folderu := ""
   Loop, Parse, A_GuiEvent, `n,`r
   {
      changeMcursor("busy")
      MainExe.ahkPostFunction("showTOOLtip", "Scanning for images...")
      line := Trim(A_LoopField)
;     MsgBox, % A_LoopField
      If (A_Index>9500)
         Break
      Else If RegExMatch(line, RegExFilesPattern) || RegExMatch(line, "i)(.\.sld)$")
         imgPath := line
      Else If InStr(FileExist(line), "D")
         folderu .= line "`n"
   }
   MainExe.ahkPostFunction("GuiDroppedFiles", imgPath, folderu)
Return

1GuiClose:
GuiClose:
doCleanup:
   byeByeRoutine()
Return

byeByeRoutine() {
   If (mustAbandonCurrentOperations!=1)
      AnyWindowOpen := MainExe.ahkgetvar.AnyWindowOpen
   Else AnyWindowOpen := 0

   If (detectLongOperation(650)=1 || AnyWindowOpen) && (lastCloseInvoked<3)
   {
      lastCloseInvoked++
      If AnyWindowOpen
         MainExe.ahkPostFunction("CloseWindow")
      Return
   } Else lastInvoked := 0

   SetTimer, TimerExit, -950
   MainExe.ahkPostFunction("TrueCleanup", 1)
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


#If, (identifyThisWin()=1)
  !Space::
     Win_ShowSysMenu(PVhwnd)
  Return
#If

identifyThisWin() {
  A := WinActive("A")
  If (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin)
     Return 1
  Else
     Return 0
}

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND := 0x112, TPM_RETURNCMD := 0x100

  MainExe.ahkPostFunction("doSuspendu", 1)
  h := WinExist("ahk_id " hwnd)
  JEE_ClientToScreen(hPicOnGui1, 1, 1, X, Y)
  SetTimer, unSuspendu, -250
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
