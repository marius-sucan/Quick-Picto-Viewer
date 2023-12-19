#Persistent
#NoTrayIcon
#MaxHotkeysPerInterval, 950
#HotkeyInterval, 50
#MaxThreads, 255
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#IfTimeout, 2000
#UseHook, Off
#Hotstring NoMouse
SetWinDelay, 1
CoordMode, Mouse, Screen
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3, appTitle := "Quick Picto Viewer"
     , RegExFilesPattern := "i)^(.\:\\).*(\.(ico|dib|tif|tiff|emf|wmf|rle|png|bmp|gif|jpg|jpeg|jpe|DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f|jfif))$"
     , PVhwnd, hGDIwin, hGDIthumbsWin, WindowBgrColor, mainCompiledPath, hfdTreeWinGui
     , winGDIcreated := 0, ThumbsWinGDIcreated := 0, MainExe := AhkExported(), omniBoxMode := 0
     , AnyWindowOpen := 0, lastOtherWinClose := 1, wasMenuFlierCreated := 0, ImgAnnoBox
     , slideShowRunning := 0, toolTipGuiCreated, editDummy, LbtnDwn := 0
     , mustAbandonCurrentOperations := 0, lastCloseInvoked := -1, allowGIFsPlayEntirely := 0
     , hCursBusy := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
     , hCursN := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
     , hCursMove := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
     , hCursCross := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32515, "Ptr")  ; IDC_Cross
     , hCursFinger := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32649, "Ptr")
     , SlideHowMode := 1, lastWinDrag := 1, TouchScreenMode := 0, allowNextSlide := 1
     , isTitleBarVisible := 0, imageLoading := 0, hPicOnGui1, hotkeysSuspended := 0
     , slideShowDelay := 9000, scriptStartTime := A_TickCount, prevFullIMGload := 1
     , maxFilesIndex := 0, thumbsDisplaying := 0, executingCanceableOperation := 1
     , runningLongOperation := 0, alterFilesIndex := 0, animGIFplaying := 0, prevOpenedFile := 0
     , canCancelImageLoad := 0, hGDIinfosWin, hGDIselectWin, hasAdvancedSlide := 1
     , imgEditPanelOpened := 0, showMainMenuBar := 1, undoLevelsRecorded := 0, UserMemBMP := 0
     , taskBarUI, hSetWinGui, panelWinCollapsed, groppedFiles := [], tempBtnVisible := "null"
     , drawingShapeNow := 0, isAlwaysOnTop, lastMenuBarUpdate := 1, lastZeitStylus := 1
     , mainWinPos := 0, mainWinMaximized := 1, mainWinSize := 0, PrevGuiSizeEvent := 0, FontBolded := 1
     , isWinXP := (A_OSVersion="WIN_XP" || A_OSVersion="WIN_2003" || A_OSVersion="WIN_2000") ? 1 : 0
     , currentFilesListModified := 0, folderTreeWinOpen := 0, hStatusBaru, OSDFontName := "Arial"
     , OSDbgrColor := "001100", OSDtextColor := "FFeeFF", LargeUIfontValue := 14, allowMenuReader := 0
     , lastMenuInvoked := [], hQPVtoolbar := 0, ShowAdvToolbar := 0, whileLoopExec := 0
     , isToolbarActivated := 0, lockToolbar2Win := 1, lastZeitPanCursor := 1, VisibleQuickMenuSearchWin :=0
     , hquickMenuSearchWin, hGuiTip, lastTippyWin, lastMouseLeave := 1, colorPickerModeNow := 0
     , mustCaptureCloneBrush := 0, doNormalCursor := 1, hotkate, uiUseDarkMode := 0
     , menusflyOutVisible := 0, otherAscriptHwnd := "", lastLclickX := 0, lastLclickY := 0
     , mouseToolTipWinCreated := 0, editingSelectionNow, IMGresizingMode, markedSelectFile
     , PrefsLargeFonts := 0, slidesFXrandomize := 0, liveDrawingBrushTool := 0, ImgHistoBox
     , lastWinStatus, lastZeitToolTip := 1, OSDfontSize := 14, ImgNavBox, OSDmsgsLine, ImgInfoBox
     , imgHUDbaseUnit := 0, picVscroll, picHscroll, QPVpid := 0, menuArray := [], menuCurrentIndex := 0
     , menuTotalIndex := 0, hMenuBar, lastMenuZeit := 1, menusList, hFlyOut, menuHotkeys, lastMenuHoverZeit := 1
     , menusListView := "File:File|Edit:Edit|Selection:Selection|Image:Image|Captions:Captions|Slides:Slides|Find:Find|List:List|Navigate:Navigate|View:View|Interface:Interface|Settings:Settings|Help:Help"
     , menusListEditor := "File:EditorFile|Edit:Edit|Selection:EditorSelection|Image:Image|Live tools:EditorTools|View:View|Interface:Interface"
     , menusListAlphaMasking := "Alpha mask:AlphaMask|View:View|Interface:Interface"
     , menusListVector := "File:VectorFile|Edit:VectorEdit|Selection:VectorSelection|View:VectorView|Interface:VectorInterface"
     , menusListThumbs := "File:File|Edit:Edit|Selection:Selection|Image:Image|Slides:Slides|Find:Find|List:List|Sort:Sort|Navigate:Navigate|View:View|Interface:Interface|Settings:Settings|Help:Help"
     , menusListWelcome := "File:File|Edit:Edit|Interface:Interface|Settings:Settings|Help:Help"
     , prevMenuBarItem := 1, lastContextMenuZeit := 1, colorPickerMustEnd := 0, userPendingAbortOperations := 0
     , statusBarTooltipVisible := 0, FloodFillSelectionAdj := 0, isToolbarKBDnav := 0, TLBRtwoColumns := 1
     , lastALclickX := 0, lastALclickY := 0, lastDoubleClickZeit := 1, TLBRverticalAlign := 1
     , hPic0, hPic1, hPic2, hPic3, hPic4, hPic5, hPic6, hPic7, hPic8, hPic9, hPic10, hPic11
     , navKeysCounter := 0, lastSwipeZeitGesture := 1, hFlyBtn1, hFlyBtn2, hFlyBtn3, AllowDarkModeForWindow

If !A_IsCompiled
   Try Menu, Tray, Icon, %A_ScriptDir%\qpv-icon.ico

; OnMessage(0x388, "WM_PENEVENT")
OnMessage(0x2a3, "WM_MOUSELEAVE")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x203, "WM_LBUTTON_DBL")
OnMessage(0x202, "WM_LBUTTONUP")
OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x207, "WM_MBUTTONDOWN")
OnMessage(0x047, "WM_WINDOWPOSCHANGED") ; window moving
OnMessage(0x20A, "WM_MOUSEWHEEL")
OnMessage(0x20E, "WM_MOUSEWHEEL")
; OnMessage(0x024B, "WM_POINTERevents", 10)
; OnMessage(0x0246, "WM_POINTERevents", 10)
; OnMessage(0x0247, "WM_POINTERevents", 10)
; OnMessage(0x0249, "WM_POINTERevents", 10)
; OnMessage(0x024A, "WM_POINTERevents", 10)
; OnMessage(0x0239, "WM_POINTERevents", 10)
; OnMessage(0X023A, "WM_POINTERevents", 10)
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
; OnMessage(0x0A0, "WM_NCMOUSEMOVE")  ; mouse move into window area

    ; Hotkey, ~#F20, EraserBlah, UseErrorLevel
    ; Hotkey, ~#F19, EraserBlah, UseErrorLevel
    ; Hotkey, ~#F18, EraserBlah, UseErrorLevel


setPriorityThread(2)
lastMenuInvoked[1] := A_TickCount
QPVpid := DllCall("Kernel32.dll\GetCurrentProcessId")
; OnExit, doCleanup
Return

EraserBlah() {
  ToolTip, % A_ThisHotkey , , , 2
  SoundBeep 900, 100
}

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

infosUIAbtns(msgu) {
   Static lastu := 0, prevMsg
   If (prevMsg=msgu)
      Return

   lastu := !lastu
   GuiControl, 1:, UIAbtn%lastu%, % msgu
   Sleep, 1
   If (WinActive("A")=PVhwnd)
      GuiControl, 1: Focus, UIAbtn%lastu%
   prevMsg := msgu
}

UnregisterTouchWindow(hwnd) {
      Return DllCall("User32.dll\UnregisterTouchWindow", "UPtr", hwnd)
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
      ; userAllowWindowDrag := MainExe.ahkgetvar.userAllowWindowDrag
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
      ; userAllowWindowDrag := externObj[6]
      mainWinPos := externObj[7]
      mainWinSize := externObj[8]
      mainWinMaximized := externObj[9]
      IMGresizingMode := externObj[10]
      OSDbgrColor := externObj[11]
      OSDtextColor := externObj[12]
      OSDfontSize := externObj[13]
      PrefsLargeFonts := externObj[14]
      OSDFontName := externObj[15]
      FontBolded := externObj[16]
   }


   ; setMenusTheme(1)
   calcHUDsize()
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialWh := "w" A_ScreenWidth//1.7 " h" A_ScreenHeight//1.5
   ; If !A_IsCompiled
     Try Menu, Tray, Icon, %mainCompiledPath%\qpv-icon.ico
   Global UIAbtn0, UIAbtn1
   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   Gui, 1: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Font, s1
   Gui, 1: Add, Button, x1 y1 w1 h1 vUIAbtn0, Btn-A
   Gui, 1: Add, Button, x1 y1 w1 h1 vUIAbtn1, Btn-B
   Gui, 1: Add, Text, x3 y3 w2 h2 BackgroundTrans vOSDmsgsLine hwndhPic11, OSD messages.
   Gui, 1: Add, Text, x3 y3 w2 h2 BackgroundTrans vPicVscroll hwndhPic5, Vertical scrollbar
   Gui, 1: Add, Text, x3 y3 w2 h2 BackgroundTrans vPicHscroll hwndhPic6, Horizontal scrollbar
   Gui, 1: Add, Text, x3 y3 w2 h2 BackgroundTrans vImgInfoBox hwndhPic9, Image information box.
   Gui, 1: Add, Text, x3 y3 w3 h3 BackgroundTrans vImgNavBox hwndhPic7, Image navigation area.
   Gui, 1: Add, Text, x3 y3 w2 h2 BackgroundTrans vImgHistoBox hwndhPic8, Image histogram area.
   Gui, 1: Add, Text, x3 y3 w2 h2 BackgroundTrans vImgAnnoBox hwndhPic10, Image annotations box.
   Gui, 1: Add, Text, x0 y0 w1 h1 BackgroundTrans vPicOnGui1 hwndhPic0, Previous image
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2a hwndhPic1, Zoom in
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2b hwndhPic2, Image view. Center.
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2c hwndhPic3, Zoom out
   Gui, 1: Add, Text, x3 y3 w3 h3 BackgroundTrans vPicOnGui3 hwndhPic4, Next image
   Gui, 1: Add, Button, xp-100 yp-100 w1 h1 Default,a
   hPicOnGui1 := hPic0
   If (isTitleBarVisible=1)
      Gui, 1: +Caption
   Else
      Gui, 1: -Caption

   Gui, 1: Show, Maximize Hide Center %initialwh%, %appTitle%
   ; setDarkWinAttribs(PVhwnd, 1)
   Try taskBarUI := new taskbarInterface(PVhwnd)
   UnregisterTouchWindow(PVhwnd)
   Loop, 4
       UnregisterTouchWindow(hPic%A_Index%)
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
      Gui, 1: Show ; , x%pX% y%pY% w%sW% h%sH%
      WinMoveZ(PVhwnd, 0, pX, pY, sW, sH)
      Sleep, 2
   }

   r := PVhwnd "|" hGDIinfosWin "|" hGDIwin "|" hGDIthumbsWin "|" hGDIselectWin "|" hPicOnGui1 "|" winGDIcreated "|" ThumbsWinGDIcreated
   Return r
}

setMenuBarState(modus, mena:="PVmenu") {
  Critical, on 
  If (showMainMenuBar!=1)
     Return

  ; causes a lot of flickers
  Loop, % menuTotalIndex
  {
     labelu := menuArray[A_Index, 3]
     s := menuArray[A_Index, 4]
     If (s!=modus)
     {
        Try Menu, % mena, % modus, % labelu
        menuArray[A_Index, 4] := modus
        Sleep, -1
     }
  }
  ; ToolTip, % modus " s=" menuTotalIndex , , , 2
}

initAppBusyMode() {
     mustAbandonCurrentOperations := 0
     userPendingAbortOperations := 0
     lastCloseInvoked := 0
     imageLoading := 1
     runningLongOperation := 1
     executingCanceableOperation := A_TickCount
     setTaskbarIconState("anim")
     ; setMenuBarState("Disable")
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

updateUIctrlFromOutside(paramA) {
    p := StrSplit(paramA, "|")
    editingSelectionNow := p[1]
    isAlwaysOnTop := p[2]
    drawingShapeNow := p[3]
    IMGresizingMode := p[4]
    updateUIctrl(0)
}

detectToolbar(ByRef ToolbarWinW:=0, ByRef ToolbarWinH:=0) {
    Static lastX := 0, lastY := 0, lW, lH
    If (ShowAdvToolbar!=1 || slideShowRunning=1 || lockToolbar2Win!=1)
       Return 0

    hasTrans := 0
    WinGetPos, thisX, thisY, ToolbarWinW, ToolbarWinH, ahk_id %hQPVtoolbar%
    If (!ToolbarWinW || !ToolbarWinH)
    {
       ToolbarWinW := lW
       ToolbarWinH := lH
    }

    If (!ToolbarWinW || !ToolbarWinH)
       Return 0

    lW := ToolbarWinW
    lH := ToolbarWinH
    If (thisX="" && ToolbarWinW && ToolbarWinH)
       thisX := lastX
    If (thisY="" && ToolbarWinW && ToolbarWinH)
       thisY := lastY

    JEE_ScreenToClient(PVhwnd, thisX, thisY, thisX, thisY)
    positionOk := (isInRange(thisX, -5, 5) && isInRange(thisY, -5, 5)) ? 1 : 0
    ; ToolTip, % "p=" positionOk "||" thisX "|" thisY , , , 2
    If (positionOk=1 && (TLBRverticalAlign=1 || TLBRtwoColumns=1))
       hasTrans := 1
    Else If (positionOk=1 && TLBRverticalAlign=0)
       hasTrans := 2

    If hasTrans
    {
       lastX := thisX
       lastY := thisY
    }

    ; ToolTip, % hasTrans "|" thisX "|" ToolbarWinW "|" hQPVtoolbar , , , 2
    Return hasTrans
}

updateUIctrl(forceThis:=0) {
   Static prevState
   If (forceThis="kill" || thumbsDisplaying=1 && maxFilesIndex>0)
   {
      prevState := ""
      Return
   }

   GetWinClientSize(GuiW, GuiH, PVhwnd, 0)
   If (ShowAdvToolbar=1 && lockToolbar2Win=1)
      hasTrans := detectToolbar(tW, tH)

   tX := (hasTrans=1) ? tW : 0
   tY := (hasTrans=2) ? tH : 0
   If (hasTrans=1)
      GuiW -= tW
   If (hasTrans=2)
      GuiH -= tH

   If (forceThis=1)
      editingSelectionNow := MainExe.ahkgetvar.editingSelectionNow

   lastWinStatus := ""
   ctrlW := (editingSelectionNow=1) ? GuiW//8 : GuiW//7
   ctrlH2 := (editingSelectionNow=1) ? GuiH//6 : GuiH//5
   ctrlH3 := GuiH - ctrlH2*2
   ctrlW2 := GuiW - ctrlW*2
   ctrlY1 := tY + ctrlH2
   ctrlY2 := tY + ctrlH2*2
   ctrlY3 := tY + ctrlH2 + ctrlH3
   ctrlX1 := tX + ctrlW
   ctrlX2 := tX + ctrlW + ctrlW2
   calcHUDsize()
   thisState := "a" GuiW GuiH ctrlW2 ctrlH2 ctrlY3 editingSelectionNow isAlwaysOnTop TouchScreenMode drawingShapeNow IMGresizingMode OSDfontSize imgHUDbaseUnit
   If (thisState!=prevState)
   {
      k := imgHUDbaseUnit//3 ; the thickness of scrollbars
      WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%   
      GuiControl, 1: Move, PicOnGUI1, % "w" ctrlW " h" GuiH " x" tX " y" tY
      GuiControl, 1: Move, PicOnGUI2a, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" tY
      GuiControl, 1: Move, PicOnGUI2b, % "w" ctrlW2 " h" ctrlH3 " x" ctrlX1 " y" ctrlY1
      GuiControl, 1: Move, PicOnGUI2c, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" ctrlY3
      GuiControl, 1: Move, PicOnGUI3, % "w" ctrlW " h" GuiH " x" ctrlX2 " y" tY
      If (IMGresizingMode=4)
      {
         GuiControl, 1: Move, picVscroll, % "w" k " h" GuiH " x" GuiW - k + tX " y" tY
         GuiControl, 1: Move, picHscroll, % "w" GuiW " h" k " x " tX " y" GuiH - k + tY
      } Else
      {
         GuiControl, 1: Move, picVscroll, w1 h1 x1 y1
         GuiControl, 1: Move, picHscroll, w1 h1 x1 y1
      }
      uiAccessImgViewSetUIlabels()
      prevState := thisState
      uiAccessUpdateUiStatusBar(0, 0, "kill", 0)
   }
}

calcHUDsize() {
   imgHUDbaseUnit := (PrefsLargeFonts=1) ? Round(OSDfontSize*2.5) : Round(OSDfontSize*2)
}

uiAccessUpdateHistoBox(msgu, tW, tH, tX, tY) {
   If (msgu="hide" || !tW || !tH)
   {
      GuiControl, 1: Move, ImgHistoBox, x1 y1 w1 h1
      Return
   }

   msgu := StrReplace(msgu, "`n", ".`n")
   msgu := StrReplace(msgu, " | ", ".`n")
   Gui, 1: Default
   GuiControl, 1:, ImgHistoBox, % "Image histogram box:`nGraph focus: " msgu "`nClick to cycle modes. Right-click for histogram options."
   GuiControl, 1: Move, ImgHistoBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessUpdateAnnoBox(msgu, tW, tH, tX, tY) {
   If (msgu="hide" || !tW || !tH || msgu="")
   {
      GuiControl, 1: Move, ImgAnnoBox, x1 y1 w1 h1
      Return
   }

   Gui, 1: Default
   GuiControl, 1:, ImgAnnoBox, % "Image caption:`n" msgu "`nThis viewport area is click-through. The action performed on click will be that as if this box is not visible."
   GuiControl, 1: Move, ImgAnnoBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessUpdateNavBox(msgu, tW, tH, tX, tY) {
   If (msgu="hide" || !tW || !tH)
   {
      GuiControl, 1: Move, ImgNavBox, x1 y1 w1 h1
      Return
   }

   Gui, 1: Default
   GuiControl, 1:, ImgNavBox, % msgu
   GuiControl, 1: Move, ImgNavBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessUpdateInfoBox(msgu, tW, tH, flipV, flipH, bonusX:=0, bonusY:=0, scrollX:=0, scrollY:=0) {
   If (msgu="hide" || !tW || !tH)
   {
      GuiControl, 1: Move, ImgInfoBox, x1 y1 w1 h1
      Return
   }

   msgu := "Info-box. Image in view:`n" StrReplace(msgu, "`n", ".`n") ".`nThis viewport area is click-through."
   Gui, 1: Default
   GuiControl, 1:, ImgInfoBox, % msgu
   GetClientSize(GuiW, GuiH, PVhwnd)
   tX := (flipH=1 && thumbsDisplaying!=1) ? GuiW - tW : 0
   tY := (flipV=1 && thumbsDisplaying!=1) ? GuiH - tH : 0
   If (flipH!=1 || thumbsDisplaying=1)
      tX += Round(bonusX)
   If (flipV!=1 || thumbsDisplaying=1)
      tY += Round(bonusY)

   tX -= Round(scrollX)
   tY -= Round(scrollY)
   GuiControl, 1: Move, ImgInfoBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessWelcomeView() {
   Static msgu := "Random predefined pattern-based image generated in the viewport. No image loaded. No indexed image files. Press O key or Left-Click to open a file or folder. Right-click for the context menu and more options."
        , lastInvoked := 1, runz := 0
   If (thumbsDisplaying=1 && maxFilesIndex>0)
      Return

   If (A_TickCount - lastInvoked<150)
   {
      SetTimer, uiAccessWelcomeView, -300
      Return
   }

   runz++
   ; ToolTip, % runz "=p" , , , 2
   updateUIctrl()
   uiAccessUpdateHistoBox("hide", 1, 1, 0, 0)
   uiAccessUpdateInfoBox("hide", 1, 1, 0, 0)
   uiAccessUpdateNavBox("hide", 1, 1, 0, 0)
   uiAccessUpdateAnnoBox("hide", 1, 1, 0, 0)
   Gui, 1: Default
   GuiControl, 1:, PicOnGUI1, % msgu
   GuiControl, 1:, PicOnGUI2a, % msgu
   GuiControl, 1:, PicOnGUI2b, % msgu
   GuiControl, 1:, PicOnGUI2c, % msgu
   GuiControl, 1:, PicOnGUI3, % msgu
   GuiControl, 1: Move, picVscroll, w1 h1 x1 y1
   GuiControl, 1: Move, picHscroll, w1 h1 x1 y1
   updateUIctrl("kill")
   lastInvoked := A_TickCount
}

uiAccessImgViewSetUIlabels() {
   Gui, 1: Default
   zr := (IMGresizingMode=4) ? " Hold the Space key plus left-click and drag to pan the image. Use the mouse wheel to change the zoom level." : " Use Control + mouse wheel to change the image zoom level."
   If (drawingShapeNow=1 || AnyWindowOpen)
   {
      msgu := AnyWindowOpen ? "Image view. A panel window is opened. " : "Image view. Drawing vector shape mode is activated. " zr " Press Escape to cancel. Press Enter to accept defined path or modifications. Swipe gestures are not allowed."
      If (imgEditPanelOpened=1)
         msgu := "Image view. An image editing live tool is currently in use. " zr " Swipe gestures are not allowed."

      GuiControl, 1:, PicOnGUI1, % msgu
      GuiControl, 1:, PicOnGUI2a, % msgu
      GuiControl, 1:, PicOnGUI2b, % msgu
      GuiControl, 1:, PicOnGUI2c, % msgu
      GuiControl, 1:, PicOnGUI3, % msgu
      Return
   }

   If (TouchScreenMode=1)
   {
      dr := (editingSelectionNow=1) ? " Double click outside selection area to deactivate it. " : " Press Shift + Left-Click anywhere to create a new selection area. "
      ; gr := " Otherwise, the movement is considered as a zoom in/out swipe gesture."
      fr := " `nIf the image is not larger than the viewport, swipe gestures are allowed."
      msgu := "Image view. Left. Click for previous image. Swipe gestures allowed." zr dr
      If (editingSelectionNow=1)
      {
         msgu := "Image view. " dr zr
         If (IMGresizingMode=4)
            msgu .= fr
      }

      GuiControl, 1:, PicOnGUI1, % msgu
      msgu := "Image view. Top. Click to zoom in. Swipe gestures allowed." zr 
      If (editingSelectionNow!=1)
         msgu .= dr

      GuiControl, 1:, PicOnGUI2a, % msgu
      msgu := "Image view. Center. Double-click to toggle view mode in this area. " zr dr
      If (editingSelectionNow=1)
         msgu := "Image view. " dr zr
      If (IMGresizingMode=4)
         msgu .= fr

      GuiControl, 1:, PicOnGUI2b, % msgu
      msgu := "Image view. Bottom. Click to zoom out. Swipe gestures allowed." zr
      If (editingSelectionNow!=1)
         msgu .= dr

      GuiControl, 1:, PicOnGUI2c, % msgu
      msgu := "Image view. Right. Click for next image. Swipe gestures allowed." zr dr
      If (editingSelectionNow=1)
      {
         msgu := "Image view. " dr zr 
         If (IMGresizingMode=4)
            msgu .= fr
      }

      GuiControl, 1:, PicOnGUI3, % msgu
   } Else
   {
      zr := (IMGresizingMode=4) ? " Left-click outside selection area and drag to pan the image. Use the mouse wheel to change the zoom level." : " Use Control + mouse wheel to change the image zoom level."
      dr := (editingSelectionNow=1) ? "Double click outside selection area to deactivate it." : "Double-click anywhere to toggle view mode. Press Shift + Left-Click anywhere to create a new selection area. "
      msgu := "Image view. " dr zr
      GuiControl, 1:, PicOnGUI1, % msgu
      GuiControl, 1:, PicOnGUI2a, % msgu
      GuiControl, 1:, PicOnGUI2b, % msgu
      GuiControl, 1:, PicOnGUI2c, % msgu
      GuiControl, 1:, PicOnGUI3, % msgu
   }
}

uiAccessUpdateOSDmsg(stringu, tW, tH) {
    If (stringu="-" || !tW || !tH)
    {
       GuiControl, 1: Move, OSDmsgsLine, x1 y1 w1 h1
       Return
    }

    Gui, 1: Default
    GetClientSize(GuiW, GuiH, PVhwnd)
    GuiControl, 1:, OSDmsgsLine, % "OSD: " stringu
    GuiControl, 1: Move, OSDmsgsLine, % " x1 y1 w" GuiW " h" tH 
}

uiAccessUpdateUiStatusBar(stringu:=0, heightu:=0, mustResize:=0, infos:=0, fntSize:="n", itemz:="n") {
   Critical, on
   Static prevState
   If itemz is Number
      maxFilesIndex := itemz

   If fntSize is Number
   {
      OSDfontSize := fntSize
      calcHUDsize()
   }

   lastWinStatus := ""
   If (mustResize="kill")
   {
      prevState := mustResize
   } Else If (mustResize="list")
   {
      thumbsDisplaying := 1
      GetClientSize(GuiW, GuiH, PVhwnd)
      thisState := "a" mustResize GuiW GuiH heightu imgHUDbaseUnit
      If (thisState!=prevState)
      {
         k := imgHUDbaseUnit//3 ; the thickness of scrollbars
         GuiControl, 1: Move, picVscroll, % "w" k " h" GuiH " x" GuiW - k " y0"
         GuiControl, 1: Move, PicOnGUI1, % "w" GuiW " h" GuiH - heightu
         GuiControl, 1: Move, PicOnGUI2a, % "w" GuiW - heightu//2 " h" heightu " x1 y" GuiH - heightu
         GuiControl, 1: Move, PicOnGUI2b, w1 h1 x1 y1
         GuiControl, 1: Move, PicOnGUI2c, w1 h1 x1 y1
         GuiControl, 1: Move, PicOnGUI3, w1 h1 x1 y1
         GuiControl, 1: Move, picHscroll, w1 h1 x1 y1
         prevState := thisState
      }

      GuiControl, 1:, PicOnGUI1, Files list container
      GuiControl, 1:, PicOnGUI2a, Status bar
      uiAccessUpdateHistoBox("hide", 1, 1, 0, 0)
      uiAccessUpdateAnnoBox("hide", 1, 1, 0, 0)
      updateUIctrl("kill")
   } Else If (mustResize="image")
   {
      thumbsDisplaying := 0
      prevState := mustResize
      updateUIctrl()
   } Else If (stringu && heightu)
   {
      updateUIctrl("kill")
      prevState := mustResize
      GetClientSize(GuiW, GuiH, PVhwnd)
      GuiControl, 1: Move, PicOnGUI1, % "w" GuiW " h" GuiH - heightu
      GuiControl, 1: Move, PicOnGUI2a, % "w" GuiW - heightu//2 " h" heightu " x1 y" GuiH - heightu
      stringu := StrReplace(stringu, " | ", "`n")
      GuiControl, 1:, PicOnGUI2a, % "Status bar:`n" stringu
      lastWinStatus := stringu
      GuiControl, 1:, PicOnGUI1, % infos
   }
}

createGDIwin() {
   Critical, on
   ; WinGetPos, , , mainW, mainH, ahk_id %PVhwnd%
   Gui, 2: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIwin +Owner1
   Gui, 2: Show, NoActivate, %appTitle%: Picture container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIwin)

   UnregisterTouchWindow(hGDIwin)
   winGDIcreated := 1
}

createGDIwinThumbs() {
   Critical, on

   Gui, 3: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIthumbsWin +Owner1
   Gui, 3: Show, NoActivate, %appTitle%: Thumbnails container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIthumbsWin)

   UnregisterTouchWindow(hGDIthumbsWin)
   ThumbsWinGDIcreated := 1
}

createGDIinfosWin() {
   Critical, on

   Gui, 4: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIinfosWin +Owner1
   Gui, 4: Show, NoActivate, %appTitle%: Infos container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIinfosWin)
   UnregisterTouchWindow(hGDIinfosWin)
}

createGDIselectorWin() {
   Critical, on

   Gui, 5: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIselectWin +Owner1
   Gui, 5: Show, NoActivate, %appTitle%: Selector container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIselectWin)
   UnregisterTouchWindow(hGDIselectWin)
}

PanelOpenCloseEvent(a) {
    b := StrSplit(a, "|")
    panelWinCollapsed := b[1]
    liveDrawingBrushTool := b[2]
    imgEditPanelOpened := b[3]
    AnyWindowOpen := b[4]
    hSetWinGui := b[5]
    editingSelectionNow := b[6]
    maxFilesIndex := b[7]
    UserMemBMP := b[8]
    undoLevelsRecorded := b[9]
    currentFilesListModified := b[10]
    lastOtherWinClose := b[11]
    IMGresizingMode := b[12]
    thumbsDisplaying := b[13]
    updateUIctrl()
    uiAccessImgViewSetUIlabels()
}

SetParentID(Window_ID, theOther) {
   Return DllCall("SetParent", "uint", theOther, "uint", Window_ID) ; success = handle to previous parent, failure =null 
}

miniGDIupdater() {
   updateUIctrl(0)
   MainExe.ahkPostFunction("GuiGDIupdaterResize", PrevGuiSizeEvent)
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
        ; MainExe.ahkassign("executingCanceableOperation", executingCanceableOperation)
        ; MainExe.ahkassign("mustAbandonCurrentOperations", mustAbandonCurrentOperations)
     } Else lastCloseInvoked := executingCanceableOperation := mustAbandonCurrentOperations := 0
     Return 1
  } Else Return 0
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

WM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
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
   mouseData := (wParam >> 16)      ; return the HIWORD -  high-order word 
   ; TulTip(" == ", result, resultA, resultB, resultC, resultD, resultE)
   ; stepping := Round(Abs(mouseData) / 120)
   ; ToolTip, % prefix , , , 2
   If (msg=526) ; horizontal mouse wheel
      direction := (mouseData>0 && mouseData<51234) ? "Right" : "Left"
   Else
      direction := (mouseData>0 && mouseData<51234) ? "WheelUp" : "WheelDown"

   MainExe.ahkPostFunction("KeyboardResponder", prefix direction, PVhwnd, 0)
   Return 0
}

preventSillyGui(thisGui) {
  r := (thisGui="mouseToolTipGuia" || thisGui="menuFlier") ? 1 : 0
  Return r
}

WM_LBUTTONDOWN(wP, lP, msg, hwnd) {
    Static lastInvoked := 1
    If TestDraggableWindow()
       Return

    pp := 0
    thisWin := isVarEqualTo(WinActive("A"), PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin)
    If (preventSillyGui(A_Gui) || !thisWin)
       Return

    ; If (runningLongOperation=1 || imageLoading=1 || whileLoopExec=1)
    ;    Return
 
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    If (A_TickCount - lastSwipeZeitGesture<350)
       pp := 0
    Else If ((drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0) && (thisWin=1 && isOkay=1))
       pp := 1

    If ((A_TickCount - scriptStartTime<500) || (A_TickCount - lastWinDrag<400) || (A_TickCount - lastDoubleClickZeit<400) && pp=1)
       Return 0

    LbtnDwn := 1
    lastInvoked := A_TickCount
    lastALclickX := lastLclickX := lP & 0xFFFF
    lastALclickY := lastLclickY := lP >> 16
    If detectToolbar()
    {
       whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
       JEE_ClientToScreen(PVhwnd, lastLclickX, lastLclickY, mXo, mYo)
       JEE_ScreenToClient(whichWin, mXo, mYo, lastALclickX, lastALclickY)
    }

    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    SetTimer, ResetLbtn, -55
    ; ToolTip, % OutputVarControl "|" hFlyBtn1 , , , 2
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
    If (statusBarTooltipVisible=1)
       mouseTurnOFFtooltip()

    LbtnDwn := 0
    colorPickerMustEnd := 1
    If (menusflyOutVisible=1)
    {
       MouseGetPos, , , OutputVarWin, hwnd, 2
       If (hwnd=hFlyBtn1)
          PanelQuickSearchMenuOptions()
       Else If (hwnd=hFlyBtn2)
          toggleAppToolbar()
       Else If (hwnd=hFlyBtn3)
          ToggleMenuBaru()
    }
    Return 0
}

WM_MBUTTONDOWN(wP, lP, msg, hwnd) {
    If (A_TickCount - scriptStartTime<500)
       Return 0

    If (statusBarTooltipVisible=1)
       mouseTurnOFFtooltip()

    colorPickerMustEnd := -1
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
    If detectToolbar()
    {
       whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
       JEE_ClientToScreen(PVhwnd, mX, mY, mXo, mYo)
       JEE_ScreenToClient(whichWin, mXo, mYo, mX, mY)
    }

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
    Static lastInvoked := 1, thisX, thisY
    LbtnDwn := 0
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    thisWin := isVarEqualTo(WinActive("A"), PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin)
    oX := mX := lP & 0xFFFF
    oY := mY := lP >> 16
    If (!thisX || !thisY || (A_TickCount - lastInvoked>500))
       mm := 0
    Else
       mm := isDotInRect(mX, mY, 15, 15, thisX, thisY, 1)

    thisX := mX, thisY := mY
    If ((drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0) && (thisWin=1 && isOkay=1 && mm=1))
    {
       If detectToolbar()
       {
          whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
          JEE_ClientToScreen(PVhwnd, mX, mY, mXo, mYo)
          JEE_ScreenToClient(whichWin, mXo, mYo, mX, mY)
       }

       Sleep, 1
       lastDoubleClickZeit := A_TickCount
       InitGuiContextMenu(mX, mY, oX, oY)
       Return 0
    }

    zz := (A_TickCount - lastSwipeZeitGesture<350) ? 1 : 0
    If ((A_TickCount - scriptStartTime<500) || !isOkay || (A_TickCount - lastInvoked<350) && zz=0)
       Return 0

    If (preventSillyGui(A_Gui) || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0)
       Return 0

    lastInvoked := A_TickCount
    lastDoubleClickZeit := A_TickCount
    If (slideShowRunning=1 || animGIFplaying=1)
    {
       turnOffSlideshow()
       Return 0
    }
    ; ToolTip, % "z=" zz , , , 2
    If (zz=1)
       WinClickAction()
    Else If (A_TickCount - lastMouseLeave>350)
       WinClickAction("DoubleClick")

    Return 0
}

askAboutStoppingOperations() {
     If (mustAbandonCurrentOperations!=1)
     {
        userPendingAbortOperations := 1
        lastCloseInvoked := 0
        WinSet, Enable,, ahk_id %PVhwnd%
        msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
        If (msgResult="yes")
        {
           mustAbandonCurrentOperations := 1
           userPendingAbortOperations := 0
        } Else
           userPendingAbortOperations := 0
     } Else userPendingAbortOperations := 0
      ; Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
}

WM_RBUTTONUP(wParam, lP, msg, hwnd) {
  LbtnDwn := 0
  If (A_TickCount - scriptStartTime<500)
     Return 0

  If (statusBarTooltipVisible=1)
     mouseTurnOFFtooltip()

  colorPickerMustEnd := -1
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
  oX := mX := lP & 0xFFFF
  oY := mY := lP >> 16
  If (whileLoopExec!=1 && runningLongOperation!=1)
  {
     If detectToolbar()
     {
        whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
        JEE_ClientToScreen(PVhwnd, mX, mY, mXo, mYo)
        JEE_ScreenToClient(whichWin, mXo, mYo, mX, mY)
     }

     If (prefix="^" && !AnyWindowOpen && drawingShapeNow!=1 && mustCaptureCloneBrush!=1 && thumbsDisplaying!=1)
        MainExe.ahkPostFunction("restartGIFplayback")
     Else If (prefix="+" && !AnyWindowOpen && drawingShapeNow!=1 && mustCaptureCloneBrush!=1)
        MainExe.ahkPostFunction("BuildSecondMenu")
     Else
        InitGuiContextMenu(mX, mY, oX, oY)
  }
  Return 0
}

TimerMouseMove() {
   MouseMove, -2, -2, 1, R
}

PanelQuickSearchMenuOptions() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return
 
    If (VisibleQuickMenuSearchWin=1)
       MainExe.ahkPostFunction("closeQuickSearch")
    Else
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

ToggleMenuBaru() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return

    MainExe.ahkPostFunction(A_ThisFunc)
    lastInvoked := A_TickCount
}

InitGuiContextMenu(mX, mY, oX, oY) {
    ctrl := IdentifyCtrlUnderMouse(oX, oY)
    MainExe.ahkPostFunction(A_ThisFunc, "extern", mX, mY, 0, ctrl)
}

infosSlideShow(a, b, c, d, e) {
   slideShowRunning := a,  SlideHowMode := b
   animGIFplaying := c,    allowNextSlide := d
   runningLongOperation := e
}

initSlidesModes(paramA, paramB, paramC, paramD) {
    animGIFplaying := paramA
    allowNextSlide := paramB
    maxFilesIndex := paramC
    slidesFXrandomize := paramD
}

slideshowsHandler(thisSlideSpeed, act, how, msgu:=0) {
   SlideHowMode := how
   slideShowDelay := thisSlideSpeed
   prevFullIMGload := 1
   If (act="start")
   {
      setTaskbarIconState("normal")
      slideShowRunning := 1
      SetTimer, theSlideShowCore, % -slideShowDelay
      Gui, 1: Default
      If msgu
      {
         GuiControl, 1:, PicOnGUI1, % msgu
         GuiControl, 1:, PicOnGUI2a, % msgu
         GuiControl, 1:, PicOnGUI2b, % msgu
         GuiControl, 1:, PicOnGUI2c, % msgu
         GuiControl, 1:, PicOnGUI3, % msgu
      }
   } Else If (act="stop")
   {
      allowNextSlide := 1
      slideShowRunning := 0
      SetTimer, theSlideShowCore, Off
      updateUIctrl()
      uiAccessImgViewSetUIlabels()
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

WM_POINTERevents(wp, lp, msg, hwnd) {
  lastZeitStylus := A_TickCount
  If (msg=0x024B)
     m := "WM_POINTERACTIVATE"
  Else If (msg=0x0246)
  {
     m := "WM_POINTERDOWN"
     counter := (wP & 0xffff)
     la := (wP & 0x00ff)
     lb := ((wP >> 8) & 0xffffff)
     ; ToolTip, % flags , , , 2
  } Else If (msg=0x0247)
  {
     m := "WM_POINTERUP"
     counter := (wP & 0xffff)
     la := (wP & 0x000f)
     lb := (wP & 0x0004)
  } Else If (msg=0x0249)
  {
     m := "WM_POINTERENTER"
     counter := (wP & 0xffff)
     la := (wP & 0x000f)
     lb := (wP & 0x0004)
  } Else If (msg=0x024A)
  {
     m := "WM_POINTERLEAVE"
     counter := (wP & 0xffff)
     la := (wP & 0x000f)
     lb := (wP & 0x0004)
  } Else If (msg=0x0239)
     m := "WM_POINTERDEVICEINRANGE"
  Else If (msg=0x023A)
     m := "WM_POINTERDEVICEOUTOFRANGE"

   ; fnOutDebug(A_ThisFunc "|" msg "|" m "|" counter "|" la "|" lb)
}

updateGDIwinPos() {
  ; thumbsDisplaying := MainExe.ahkgetvar.thumbsDisplaying
  ; If (A_OSVersion="WIN_7")
  JEE_ClientToScreen(hPicOnGui1, 0, 0, GuiX, GuiY)
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

IdentifyCtrlUnderMouse(mX, mY) {
  Static ctrlsList := {11:"OSDmsgsLine", 5:"PicVscroll", 6:"PicHscroll", 9:"ImgInfoBox", 7:"ImgNavBox", 8:"ImgHistoBox", 10:"ImgAnnoBox", 0:"PicOnGui1", 1:"PicOnGui2a", 2:"PicOnGui2b", 3:"PicOnGui2c", 4:"PicOnGui3"}

  ctrlName := A_GuiControl
  Loop, 12
  {
      a := A_Index - 1
      r := GetWindowPlacement(hPic%a%)
      ; fnOutDebug(a "=" mX "|" mY "=" r.x "|" r.y)
      If isDotInRect(mX, mY, r.x, r.x + r.w, r.y, r.y + r.h)
      {
         ctrlName .= "|" ctrlsList[a]
         ; Break
      }
  }
  ; ToolTip, % ctrlName , , , 2
  Return ctrlName "|"
}

WinClickAction(thisEvent:="normal") {
    Static lastInvoked := 1
    MouseGetPos, ,, OutputVarWin
    If ((A_TickCount - lastInvoked<25) || (OutputVarWin=hGuiTip))
       Return

    ; GetMouseCoord2wind(PVhwnd, mX, mY, mXo, mYo)
    mX := lastALclickX,    mY := lastALclickY
    ; ToolTip, % mX "=" mY "`n" lastLclickX "=" lastLclickY , , , 2
    canCancelImageLoad := 4
    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    ; ToolTip, % mX "=" mY "=" param "==" ctrlName "--" A_GuiControl "--" A_GuiControlEvent , , , 2
    lastInvoked := A_TickCount
    If (slideShowRunning=1)
       turnOffSlideshow()
    ; Else If (A_TickCount - lastZeitPanCursor<350) && (thumbsDisplaying=0)
    ;    MainExe.ahkPostFunction("simplePanIMGonClick", 0, 1, 1)
    Else
       sendWinClickAct(thisEvent, IdentifyCtrlUnderMouse(lastLclickX, lastLclickY), mX, mY)
}

sendWinClickAct(ctrlEvent, guiCtrl, mX, mY) {
   ; ToolTip, % guiCtrl "|" mX "|" mY , , , 2
   ; fnOutDebug("UI event: " ctrlEvent "==" guiCtrl "|" mX "|" mY)
   MainExe.ahkPostFunction("WinClickAction", ctrlEvent, guiCtrl, mX, mY)
}

GetMouseCoord2wind(hwnd, ByRef nx, ByRef ny, ByRef ox, ByRef oy) {
    ; CoordMode, Mouse, Screen
    MouseGetPos, ox, oy
    JEE_ScreenToClient(hwnd, ox, oy, nx, ny)
}

ResetLbtn() {
  If GetKeyState("LButton", "P")
     SetTimer, ResetLbtn, -60
  Else
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
         SetTimer, updateTlbrPosition, -10
      b := a
  }
}

RepositionTempBtnGui() {
     MainExe.ahkPostFunction(A_ThisFunc)
}

saveMainWinPos() {
     MainExe.ahkPostFunction(A_ThisFunc)
}

changeMcursor(whichCursor) {
  ; If (whichCursor="normal")
  ;    SetTimer, ResetLoadStatus, -20

  If (slideShowRunning=1 || animGIFplaying=1)
     Return

  If (A_TickCount - lastZeitPanCursor<50)
     thisCursor := hCursMove

  If (whichCursor="normal-extra")
  {
     userPendingAbortOperations := imageLoading := mustAbandonCurrentOperations := 0
     runningLongOperation := lastCloseInvoked := 0
     setTaskbarIconState("normal")
     ; setMenuBarState("Enable")
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

  Try DllCall("user32\SetCursor", "UPtr", thisCursor)
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

showMouseTooltipStatusbar() {
    MouseGetPos, ,, OutputVarWin
    If (LbtnDwn=1 || !lastWinStatus || !thumbsDisplaying) || (A_TickCount - lastZeitToolTip<1000) || (OutputVarWin!=PVhwnd)
       Return

    thisSize := OSDfontSize//3.5 + 2
    statusBarTooltipVisible := 1
    mouseCreateOSDinfoLine(lastWinStatus, thisSize)
    SetTimer, mouseTurnOFFtooltip, -4500
}

WM_MOUSEMOVE(wP, lP, msg, hwnd) {
  Static lastInvoked := 1, prevPos, prevArrayPos := []
  If ((A_TickCount - lastZeitPanCursor < 300) || !isQPVactive())
     Return

  If (wP&0x1)
  {
     LbtnDwn := 1
     SetTimer, ResetLbtn, -55
  }

  mX := lP & 0xFFFF
  mY := lP >> 16
  ; MouseGetPos, mX, mY, OutputVarWin
  isSamePos := (isInRange(mX, prevArrayPos[1] + 3, prevArrayPos[1] - 3) && isInRange(mY, prevArrayPos[2] + 3, prevArrayPos[2] - 3)) ? 1 : 0
  thisWin := isVarEqualTo(hwnd, PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin) ? 1 : 0
  If (slideShowRunning=1 && isSamePos=1)
     Try DllCall("user32\SetCursor", "Ptr", 0)
  Else If (drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0) && (thisWin=1)
     changeMcursor("cross")
  Else If ((runningLongOperation=1 || imageLoading=1) && slideShowRunning!=1)
     changeMcursor("busy")
  Else If (thumbsDisplaying=1 && !AnyWindowOpen && runningLongOperation!=2 && imageLoading!=1 && lastWinStatus)
  {
     ctrlu := IdentifyCtrlUnderMouse(mX, mY) 
     If VarContainsThis(ctrlu, "|PicOnGUI2a|", "|picVscroll|", "|ImgNavBox|")
     {
        changeMcursor("finger")
        If (isSamePos=0 && (A_TickCount - lastZeitToolTip>1000) && InStr(ctrlu, "|PicOnGUI2a|"))
           SetTimer, showMouseTooltipStatusbar, -500
     } Else If (isSamePos=0)
        SetTimer, showMouseTooltipStatusbar, Off
  }

  If (A_TickCount - scriptStartTime < 900)
     Return

  thisPos := mX "-" mY
  prevArrayPos := [mX, mY]
  If (A_TickCount - lastInvoked > 55) && (thisPos!=prevPos)
  {
     ; isThisWin :=(OutputVarWin=PVhwnd) ? 1 : 0
     thisPrefsWinOpen := (imgEditPanelOpened=1) ? 0 : AnyWindowOpen
     lastInvoked := A_TickCount
     If (slideShowRunning!=1 && !thisPrefsWinOpen && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1 && whileLoopExec!=1)
        MainExe.ahkPostFunction("MouseMoveResponder")
 
     prevPos := mX "-" mY
  }

  ; ToolTip, % title "= " isTitleBarVisible " - " TouchScreenMode " = " OutputVarWin " = " actif
  ; If (isTitleBarVisible=0 && userAllowWindowDrag=1 && TouchScreenMode=0 && (wP&0x1))
  specials := TestDraggableWindow()
  If (specials=1 && (wP&0x1) && (A_TickCount - lastWinDrag>45))
  {
     PostMessage, 0xA1, 2,,, ahk_id %PVhwnd%
     Global lastWinDrag := A_TickCount
     ; MainExe.ahkassign("lastWinDrag", lastWinDrag)
     SetTimer, trackMouseDragging, -55
  } 
}

TestDraggableWindow() {
   If (isTitleBarVisible=0 && slideShowRunning!=1 && imageLoading!=1 && runningLongOperation!=1 && whileLoopExec!=1)
      specials := (GetKeyState("Shift", "T") && GetKeyState("Ctrl", "P")) ? 1 : 0
   Return specials
}

trackMouseDragging() {
    Global lastWinDrag := A_TickCount
}

WM_MOUSELEAVE(wP, lP, msg, hwnd) {
    lastMouseLeave := A_TickCount
}

activateMainWin() {
   If (A_TickCount - scriptStartTime<2000)
      Return

   lastMouseLeave := A_TickCount
   If (A_TickCount - lastOtherWinClose>500)
      colorPickerMustEnd := 1

   LbtnDwn := 0
   Sleep, -1
   MouseGetPos, ,, winu
   ; z := identifyThisWin()
   If (winu!=hQPVtoolbar && editingSelectionNow=1 && slideShowRunning!=1 && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1
   && (A_TickCount - lastMenuHoverZeit>300) && (A_TickCount - lastMenuZeit>300) && (A_TickCount - lastContextMenuZeit>200))
      MainExe.ahkPostFunction("MouseMoveResponder", "krill")

   If (menusflyOutVisible=1 && !identifyMenus())
      SetTimer, hideMenuFlyOut, -50

   ; If (mouseToolTipWinCreated=1 && !z && !identifyParentWind())
   If (mouseToolTipWinCreated=1)
      SetTimer, mouseTurnOFFtooltip, -150
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
    turnOffSlideshow()
    canCancelImageLoad := 4
    delayu := (isWinXP=1 || thumbsDisplaying=1) ? -15 : -5
    SetTimer, miniGDIupdater, % delayu
}

GuiDropFiles(GuiHwnd, FileArray, CtrlHwnd, X, Y) {
   Static lastInvoked := 1
   If (AnyWindowOpen>0 || mustCaptureCloneBrush=1 || whileLoopExec=1 || drawingShapeNow=1 || imageLoading=1 || runningLongOperation=1 || groppedFiles.Count()>0) || (A_TickCount - lastInvoked<300)
      Return

   lastInvoked := A_TickCount
   GuiHwnd := Format("{1:#x}", GuiHwnd)
   ; ToolTip, % GuiHwnd "`n" PVhwnd "`n" hGDIwin "`n" hGDIthumbsWin "`n" hGDIselectWin "`n" hGDIinfosWin, , , 2
   For i, file in FileArray
       groppedFiles[A_Index] := Trimmer(file)

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
   totalGroppy := groppedFiles.Count()
   If (!totalGroppy || (A_TickCount - lastInvoked<400))
      Return

   isCtrlDown := GetKeyState("Ctrl", "P")
   lastInvoked := A_TickCount
   vectorShape := imgFiles := foldersList := sldFile := ""
   turnOffSlideshow()
   canCancelImageLoad := 4
   countD := countV := countF := countFiles := 0
   ToolTip, Please wait - processing dropped files list , , , 2
   Loop, % totalGroppy
   {
      changeMcursor("busy")
      line := groppedFiles[A_Index]
      If !line
         Continue

      ; MsgBox, % A_LoopField
      If (A_Index>29900)
      {
         Break
      } Else If RegExMatch(line, "i)(.\.sld|.\.sldb)$")
      {
         countD++
         If !sldFile
            sldFile := line
      } Else If RegExMatch(line, "i)(.\.vqpv)$")
      {
         countV++
         vectorShape := line
      } Else If InStr(FileExist(line), "D")
      {
         countF++
         foldersList .= line "`n"
      } Else If RegExMatch(line, RegExFilesPattern)
      {
         countFiles++
         imgFiles .= line "`n"
      }
   }

   If (countFiles>1 || countF>1)
      sldFile := ""

   ToolTip, , , , 2
   If !isCtrlDown
      isCtrlDown := GetKeyState("Ctrl", "P")
   If (!imgFiles && !sldFile && vectorShape)
      sldFile := vectorShape

   groppedFiles := []
   MainExe.ahkPostFunction("GuiDroppedFiles", imgFiles, foldersList, sldFile, countFiles, isCtrlDown)
   lastInvoked := A_TickCount
}

1GuiClose:
GuiClose:
doCleanup:
   byeByeRoutine()
Return

byeByeRoutine() {
   Static lastInvokedThis := 1
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
       colorPickerMustEnd := -1
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
   } Else If (VisibleQuickMenuSearchWin=1)
   {
       VisibleQuickMenuSearchWin := omniBoxMode := 0
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
   } Else lastCloseInvoked := 5

   If (A_TickCount - lastOtherWinClose < 650)
      Return

   If (lastCloseInvoked>3)
   {
      ; SoundBeep , 500, 2000
      SetTimer, TimerExit, % (lastCloseInvoked>5) ? -550 : -10
      MainExe.ahkPostFunction("TrueCleanup", 1)
   }
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
    hwnd := DllCall("GetParent", "UPtr", uz, "UPtr")
    r := isVarEqualTo(hwnd, A_ScriptHwnd, otherAscriptHwnd, hSetWinGui, PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin)
    ; ToolTip, % uz "=" A_ScriptHwnd "=" otherAscriptHwnd , , , 2
    If (uz=PVhwnd || uz=hQPVtoolbar && ShowAdvToolbar=1)
       r := 0
    Return r
}

identifyThisWin() {
  Static prevR, lastInvoked := 1
  If (A_TickCount - lastInvoked < 50)
     Return prevR

  hwnd := WinActive("A")
  prevR := isVarEqualTo(hwnd, otherAscriptHwnd, PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin)
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

destroyMenuFlyout() {
   wasMenuFlierCreated := 0
   Gui, menuFlier: Destroy
}

guiCreateMenuFlyout() {
   Critical, on
   Static m := 2
   h := LargeUIfontValue * 2 + 1
   Gui, menuFlier: +AlwaysOnTop -MinimizeBox -SysMenu -Caption +ToolWindow +hwndhFlyOut
   If (uiUseDarkMode=1)
   {
      brd := "+border"
      Gui, menuFlier: Color, 212121
      Gui, menuFlier: Font, s12 Bold cFFffFF
   } Else
   {
      brd := ""
      Gui, menuFlier: Color, EEeeEE
      Gui, menuFlier: Font, s12 Bold c111111
   }

   Gui, menuFlier: Margin, 0, 0
   Gui, menuFlier: Add, Text, %brd% Center +0x200 x0 y0 w%h% h%h% hwndhFlyBtn1 +TabStop, S
   Gui, menuFlier: Add, Text, %brd% Center +0x200 x+%m% wp hp hwndhFlyBtn2 +TabStop, T
   Gui, menuFlier: Add, Text, %brd% Center +0x200 x+%m% wp hp hwndhFlyBtn3 +TabStop, M
   AddTooltip2Ctrl(hFlyBtn1, "Search through ther available options [ `; ]",, uiUseDarkMode)
   AddTooltip2Ctrl(hFlyBtn2, "Toggle app toolbar [ Shift+F10 ]",, uiUseDarkMode)
   AddTooltip2Ctrl(hFlyBtn3, "Toggle menu bar [ F10 ]",, uiUseDarkMode)
   ; AddTooltip2Ctrl("AutoPop", 0.5)
   wasMenuFlierCreated := 1
}

IsNumber(Var) {
   Static number := "number"
   If Var Is number
      Return 1
   Return 0
}

highLightMenuBar() {
    hMenuBar := DllCall("GetMenu", "UPtr", PVhwnd, "UPtr")
    If !hMenuBar
       addJournalEntry("ERROR: Failed to get menu bar handle, from the main window.")

    hMenuBar := "0x" Format("{:x}", hMenuBar)
    rect := GetMenuItemRect(PVhwnd, hMenuBar, menuCurrentIndex - 1)
    mX := Trim(rect.left)
    mY := Trim(rect.bottom)
    mYz := Trim(rect.top)
    mH := max(rect.bottom, rect.top) - min(rect.bottom, rect.top)
    mW := max(rect.left, rect.right) - min(rect.left, rect.right)
    ShowClickHalo(mX, mYz, mW, mH, 1, menarg, 1)
}

menuFlyoutDisplay(actu, mX, mY, isOkay, darkMode:=0, thisHwnd:=0, idu:=0) {
   Critical, on
   lastOtherWinClose := A_TickCount
   lastContextMenuZeit := A_TickCount
   uiUseDarkMode := (darkMode="yes") ? 1 : 0
   otherAscriptHwnd := thisHwnd
   allowMenuReader := actu
   ; ToolTip, % "d=" darkMode , , , 2
   If (IsNumber(idu) && idu>0)
      menuCurrentIndex := idu

   If (idu="reset")
      menuCurrentIndex := 0
   Else
     SetTimer, highLightMenuBar, -50

   If (!isOkay && actu="yes")
      Return

   If (wasMenuFlierCreated!=1)
      guiCreateMenuFlyout()

   ; GetPhysicalCursorPos(mX, mY)
   fn := Func("dummyMenuFlyoutDisplay").Bind(actu, mX, mY)
   SetTimer, % fn, -25
}

dummyMenuFlyoutDisplay(actu, mX, mY) {
   If (actu="yes" && allowMenuReader="yes")
   {
      ; GetPhysicalCursorPos(mX, mY)
      a := WinExist("ahk_class #32768 ahk_pid " QPVpid)
      If !a
      {
         h := GetMenuWinHwnd(mX, mY, "32768")
         a := h[1]
      }
      If (!InStr(h[2], "32768") && !a)
      {
          menusflyOutVisible := 0
          Gui, menuFlier: Hide
          Gui, MclickH: Hide
          Return
      }

      menusflyOutVisible := 1
      WinGetPos, mX, mY, , Height, ahk_id %a%
      ; ToolTip, % z "=" a "=" mY " = " height "=" h , , , 2
      x := mX
      y := mY + Round(Height) + 2
      If (x!="" && y!="")
         Gui, menuFlier: Show, AutoSize x%x% y%y% NoActivate
   } Else
   {
      SetTimer, hideMenuFlyOut, -35
   }
}

hideMenuFlyOut() {
    MouseGetPos,,, OutputVarWin
    ; WinGetClass, glassu, ahk_id %OutputVarWin%
    ; WinGetTitle, titlu, ahk_id %OutputVarWin%
    ; ToolTip, % OutputVarWin "==" hFlyOut "`n" glassu "==" titlu , , , 2
    If (OutputVarWin!=hFlyOut && !identifyMenus())
    {
       menusflyOutVisible := 0
       Gui, menuFlier: Hide
       Gui, MclickH: Hide
       SetTimer, hideMenuFlyOut, Off
    } Else If (menusflyOutVisible=1)
       SetTimer, hideMenuFlyOut, -35
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

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  turnOffSlideshow()
  JEE_ClientToScreen(PVhwnd, 1, 1, x, y)
  ; MainExe.ahkPostFunction("Win_ShowSysMenu", hwnd, x, y)
  coreShowSysMenu(Hwnd, x, y)
  Return 1
}

coreShowSysMenu(Hwnd, x, y) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND := 0x112, TPM_RETURNCMD := 0x100
  h := WinExist("ahk_id " hwnd)
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
      lastOtherWinClose := A_TickCount
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
   lastOtherWinClose := A_TickCount
}

getMenuCoords(menuLabel) {
   JEE_ClientToScreen(PVhwnd, 1, 1, mX, mY)
   GetPhysicalCursorPos(x, y)
   ; Try MouseGetPos, ,, WinID
   AccInfoUnderMouse(x, y, accFocusValue, accFocusName, accIRole, accRole, styleu, strstyles, shortcut, coords)
   ; ToolTip, % coords.x "==" coords.y , , , 2
   If (coords.x && coords.y)
      coords := menuLabel "|" coords.x "|" coords.y + coords.h
   Else
      coords := menuLabel "|" mX "|" mY
   Return coords
}

GetMenuItemRect(hwnd, hMenu, nPos) {
    VarSetCapacity(RECT, 16, 0)
    if DllCall("User32.dll\GetMenuItemRect", "Ptr", hwnd, "Ptr", hMenu, "UInt", nPos, "Ptr", &RECT)
    {
       objRect := { left   : numget( RECT,  0, "UInt" )
                  , top    : numget( RECT,  4, "UInt" )
                  , right  : numget( RECT,  8, "UInt" )
                  , bottom : numget( RECT, 12, "UInt" ) }
       rect := ""
       return objRect
    }
    rect := ""
    return 0
}

changeMenusBarKbd(keyu) {
   ; Static lastItem := 1
   If ((A_TickCount - lastMenuHoverZeit<300) || (menuCurrentIndex))
   {
      Sleep, 25
      msgu := constantMenuReader("focused", 1)
      WinGet, menus, List , % "ahk_class #32768 ahk_pid " QPVpid
      If (keyu="left" && menus>1)
      {
         SendInput, {%keyu%}
      } Else If (InStr(msgu, "submenu container") && keyu="right")
      {
         SendInput, {%keyu%}
      } ELse
      {
         If menuCurrentIndex
            thisu := (keyu="Right") ? menuCurrentIndex + 1 : menuCurrentIndex - 1
         Else
            thisu := (keyu="Right") ? prevMenuBarItem + 1 : prevMenuBarItem - 1

         n := clampInRange(thisu, 1, menuTotalIndex, 1)
         ; ToolTip, % keyu "==" funcu "=" n "|" menuCurrentIndex "|" lastItem , , , 2
         prevMenuBarItem := n
         funcu := menuArray[n, 2]
         If IsFunc(funcu)
         {
            lastMenuZeit := A_TickCount
            SendInput, {F10}
            Sleep, 15
            %funcu%(0, n)
         } Else
            SendInput, {%keyu%}
      }
   } Else
   {
      SendInput, {%keyu%}
      ; SoundBeep , 300, 100
      ; ToolTip, % keyu "==" menuCurrentIndex , , , 2
   }
}

invokeGivenMenuBarPopup(n) {
   n := clampInRange(n, 1, menuTotalIndex, 1)
   funcu := menuArray[n, 2]
   If IsFunc(funcu)
   {
      ; ToolTip, % keyu "==" funcu , , , 2
      lastMenuZeit := A_TickCount
      SendInput, {F10}
      Sleep, 15
      %funcu%(0, n)
   }
}

uiAlphaMaskTrigger(a, b, c, d, e) {
  AnyWindowOpen := a
  liveDrawingBrushTool := b
  editingSelectionNow := c
  UserMemBMP := d
  showMainMenuBar := e
  thumbsDisplaying := 0
  UpdateMenuBar()
}

isAlphaMaskWindow() {
   Return isVarEqualTo(AnyWindowOpen, 23, 24, 31, 32, 70)
}

isNowAlphaPainting() {
   Return (imgEditPanelOpened=1 && isAlphaMaskWindow()=1 && liveDrawingBrushTool=1 && editingSelectionNow=1) ? 1 : 0
}

BuildMenuBar(modus:=0, applyFilter:=0) {
   If (modus="welcome")
      menusList := menusListWelcome
   Else If (modus="freeform" || drawingShapeNow=1)
      menusList := menusListVector
   Else If isNowAlphaPainting()
      menusList := menusListAlphaMasking
   Else If (imgEditPanelOpened=1 && AnyWindowOpen)
      menusList := menusListEditor
   Else If (thumbsDisplaying=1)
      menusList := menusListThumbs
   Else
      menusList := menusListView

   menuArray := []
   menuTotalIndex := 0
   menuHotkeys := "|"

   If (applyFilter=1)
   {
      Menu, PVmenu, Add, >>, dummy
      Gui, 1: Menu, PVmenu
      ; GetClientSize(mainWidth, mainHeight, PVhwnd)
   }

   rr := 0
   hMenuBar := DllCall("GetMenu", "UPtr", PVhwnd, "UPtr")
   hMenuBar := "0x" Format("{:x}", hMenuBar)
   Loop, Parse, menusList, |
   {
      ; generate the list of hotkeys for the menu bar items: eg. alt + f
      k := StrSplit(A_LoopField, ":")
      n := SubStr(k[1], 1, 1)
      n2 := SubStr(k[1], 2, 1)
      lbl := (forbiddenAltKeys(n) || InStr(menuHotkeys, "!" n "|")) ? k[1] : "&" k[1]
      rr := kMenu(lbl, "invokeMenuBarItem", hMenuBar, applyFilter)
      If (rr=-1)
         Break

      If !InStr(lbl, "&")
      {
         lbl := (forbiddenAltKeys(n2) || InStr(menuHotkeys, "!" n2 "|")) ? k[1] : n "&" SubStr(k[1], 2)
         menuHotkeys .= (!InStr(menuHotkeys, "!" n2 "|") && InStr(lbl, "&")) ? "!" n2 "|" : ".|"
      } Else
         menuHotkeys .= (!InStr(menuHotkeys, "!" n "|") && InStr(lbl, "&")) ? "!" n "|" : ".|"
   }

   If (applyFilter=1)
      Menu, PVmenu, Delete, >>

   If (rr=-1)
      Menu, PVmenu, Add, >>, MenuBonusOptions
}

MenuBonusOptions() {
  SoundBeep 
}

forbiddenAltKeys(n) {
   If (thumbsDisplaying=1)
      Return isVarEqualTo(n, "e","u")
   Else
      Return isVarEqualTo(n, "a","e","u","p","r","y","g")
}

invokeMenuBarItem(a,b) {
   Static lastInvoked, lastItem
   If (runningLongOperation!=1 && imageLoading=1 && animGIFplaying!=1)
   || (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
   {
      Sleep, -1
      Return
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
   }

   ; ToolTip, % a "\" b "\" menuCurrentIndex , , , 2
   If (!determineMenuBTNsOKAY() || menuCurrentIndex=b)
      Return

   lastMenuZeit := A_TickCount
   funcu := "InvokeMenuBar"
   Loop, Parse, menusList, |
   {
      If (A_Index!=b)
         Continue

      k := StrSplit(A_LoopField, ":")
      funcu .= k[2]
   }

   If (lastItem=b && (A_TickCount - lastInvoked<125))
      Return
 
   lastItem := b
   Global menuCurrentIndex := b
   lastInvoked := A_TickCount
   MainExe.ahkPostFunction(funcu, b)
   SetTimer, findMenuBarItemUnderMouse, 60
}

simpleGetMenuItemRect(hwnd, hMenuBar, indexu, ByRef mX, ByRef mY, ByRef mW, ByRef mH) {
    rect := GetMenuItemRect(hwnd, hMenuBar, indexu - 1)
    mX := Trim(rect.left)
    mY := Trim(rect.bottom)
    mYz := Trim(rect.top)
    mH := max(rect.bottom, rect.top) - min(rect.bottom, rect.top)
    mW := max(rect.left, rect.right) - min(rect.left, rect.right)
}

kMenu(labelu, funcu, hMenuBar, applyFilter, mena:="PVmenu", actu:="Add") {
   If (actu="add")
   {
      If (funcu="-")
         Menu, % mena, % actu
      Else
         Menu, % mena, % actu, % labelu, % funcu

      menuTotalIndex++
      If (applyFilter=1)
      {
          simpleGetMenuItemRect(PVhwnd, hMenuBar, menuTotalIndex, mX, mY, mW, mH)
          JEE_ScreenToClient(PVhwnd, mX, mY, mX, mY)
          If (abs(mY)>3)
          {
             menuTotalIndex--
             Menu, % mena, Delete, % labelu
             Return -1
          }
      }

      t := StrReplace(labelu, "&")
      menuArray[menuTotalIndex] := [t, funcu, labelu, "Enable"]
      menuArray[t] := [funcu, menuTotalIndex, labelu]
      ; fnOutDebug(A_ThisFunc "(" menuTotalIndex "): " mX + mW "|" mY "||" mW "|" mH "||" mainWidth)
   }
}

dummy() {
   Sleep, -1
}

clampInRange(value, min, max, reverse:=0) {
   If (reverse=1)
   {
      If (value>max)
         value := min
      Else If (value<min)
         value := max
   } Else
   {
      If (value>max)
         value := max
      Else If (value<min)
         value := min
   }

   Return value
}

findMenuBarItemUnderMouse() {
   Static prevLabel, lastH := 1, lastY := 1
   If (!identifyMenus() && (A_TickCount - lastMenuZeit>700))
   {
      ; ToolTip, % "killed" , , , 3
      menuCurrentIndex := 0
      prevMenuBarItem := 1
      SetTimer, findMenuBarItemUnderMouse, Off
      Return
   }

   lastMenuHoverZeit := A_TickCount
   Try MouseGetPos, ,, WinID
   If (WinID!=PVhwnd)
      Return

   GetPhysicalCursorPos(x, y)
   AccInfoUnderMouse(x, y, accFocusValue, accFocusName, accIRole, accRole, styleu, strstyles, shortcut, coords)
   If !(accIRole=12 && accFocusName)
   {
      If isInRange(y, lastY - lastH, lastY + lastH)
      {
         y := lastY
         AccInfoUnderMouse(x, y, accFocusValue, accFocusName, accIRole, accRole, styleu, strstyles, shortcut, coords)
      }
   }

   If (accIRole=12 && accFocusName && prevLabel!=accFocusName)
   {
      lastY := coords.y + coords.h//2
      lastH := coords.h
      prevLabel := accFocusName
      t := StrReplace(accFocusName, "&")
      funcu := menuArray[t, 1]
      idu := menuArray[t, 2]
      ; ToolTip, % accFocusName "==" funcu "==" t , , , 2
      If (IsFunc(funcu) && idu!=menuCurrentIndex)
      {
         prevMenuBarItem := idu
         lastMenuZeit := A_TickCount
         SendInput, {F10}
         Sleep, 15
         ; ToolTip, % idu "=l" , , , 2
         %funcu%(0, idu)
      }
   }
}

WM_NCMOUSEMOVE(wP, lP, msg, hwnd) {
  ; unused
   Static prevLP, prevMenuID
   If (prevLP!=lP && allowMenuReader="yes" && menuCurrentIndex>0)
   {
      winMX := lP & 0xFFFF
      winMY := lP >> 16

      ; ToolTip, % "lol=" winMX "=" winMY, , , 2
      prevLP := lP
   }
}

tlbrInitPrefs(paramA) {
  p := StrSplit(paramA, "|")
  hQPVtoolbar := p[1]
  ShowAdvToolbar := p[2]
  lockToolbar2Win := p[3]
  TLBRverticalAlign := p[4]
  TLBRtwoColumns := p[5]
}

updateTlbrPosition() {
  If (lockToolbar2Win!=1 || ShowAdvToolbar!=1)
     Return

  JEE_ClientToScreen(PVhwnd, 0, 0, UserToolbarX, UserToolbarY)
  ; fnOutDebug(UserToolbarX "|" UserToolbarY)
  tX := Round(UserToolbarX),    tY := Round(UserToolbarY)
  WinMove, ahk_id %hQPVtoolbar%, , % tX, % tY
  SetTimer, updateUIctrl, -100
  ; Gui, OSDguiToolbar: Show, NoActivate x%tX% y%tY%, QPV toolbar
}

fnOutDebug(msg) {
      OutputDebug, % "QPV: " Trim(msg)
}

UpdateMenuBar(modus:=0) {
   Static hasRan := 0, prevState
   If !hasRan
   {
      Menu, PVmanu, Add, MENU, dummy
      hasRan := 1
   }

   thisState := "a" imgEditPanelOpened AnyWindowOpen thumbsDisplaying maxFilesIndex drawingShapeNow modus undoLevelsRecorded showMainMenuBar isNowAlphaPainting()
   ; ToolTip, % "lol"  isNowAlphaPainting() isAlphaMaskWindow()  , , , 2
   If !showMainMenuBar
      prevState := thisState

   ; ToolTip, % thisState "`n" prevState , , , 2
   If (prevState=thisState)
   {
      ; updateTlbrPosition()
      SetTimer, updateTlbrPosition, -300
      Return
   }

   ; ToolTip, % "l = " modus , , , 2
   ; If (thumbsDisplaying=1)
   ;    uiAccessUpdateUiStatusBar(0, 0, "list", 0)
   ; Else 
   ;    updateUIctrl()

   lastMenuBarUpdate := A_TickCount
   Gui, 1: Menu, PVmanu
   Try Menu, PVmenu, Delete
   If (showMainMenuBar!=1)
   {
      Sleep, -1
      Gui, 1: Menu
      Return
   }

   ; Sleep, -1
   BuildMenuBar(modus, 0)
   MainExe.ahkassign("menuHotkeys", menuHotkeys)
   ; SetMenuInfo(MenuGetHandle("PVmenu"), 2, 1, 0, 1)
   ; Sleep, -1
   ; Gui, 1: Menu, PVmanu
   Gui, 1: Menu, PVmenu
   lastMenuBarUpdate := A_TickCount

   prevState := thisState
   ; updateTlbrPosition()
   SetTimer, updateTlbrPosition, -300
}

determineMenuBTNsOKAY() {
   ; ToolTip, % imageLoading "==" runningLongOperation "==" AnyWindowOpen "==" menuCurrentIndex , , , 2
   If (imageLoading=1 || runningLongOperation=1) || (AnyWindowOpen && imgEditPanelOpened!=1)
      Return 0
   Else
      Return 1
}

TulTip(sep, params*) {
    str := ""
    For index,param in params
        str .= "[" A_Index "]" param . sep

    Random, OutputVar, -220, 200
    ; ToolTip, [ Text, X, Y, WhichToolTip]
    ToolTip, % OutputVar "===" str , ,, 3
}

isVarEqualTo(value, vals*) {
   yay := 0
   for index, param in vals
   {
       If (value=param)
       {
          yay := 1
          Break
       }
   }
   Return yay
}

VarContainsThis(value, vals*) {
   yay := 0
   for index, param in vals
   {
       If InStr(value, param)
       {
          yay := 1
          Break
       }
   }
   Return yay
}

preByeRoutine() {
    canCancelImageLoad := 4
    If (AnyWindowOpen || animGIFplaying=1 || slideShowRunning=1 || thumbsDisplaying=1)
       lastOtherWinClose := A_TickCount
    byeByeRoutine()
}

KeyboardResponder(givenKey, abusive) {
    ; ToolTip, % givenKey "=" abusive "=" runningLongOperation "|" mustAbandonCurrentOperations , , , 2
    If isVarEqualTo(givenKey, "Left","Right","Up","Down","PgUp","PgDn","Home","End","BackSpace","Delete","Enter")
    {
       If (runningLongOperation=1 && givenKey="Enter")
       {
          preByeRoutine()
       } Else If (slideShowRunning=1)
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
       preByeRoutine()
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
    ; ToolTip, % callMain "=" isOkay "(" imageLoading "|" animGIFplaying ")=" runningLongOperation "=" whileLoopExec "=" givenKey , , , 2
    If (callMain=1 && isOkay=1 && runningLongOperation!=1 && whileLoopExec!=1 && givenKey)
    {
       ; addJournalEntry(A_ThisFunc "(): " WinActive("A") "==" givenKey)
       MainExe.ahkPostFunction("KeyboardResponder", givenKey, PVhwnd, abusive, navKeysCounter)
    }
}

PreProcessKbdKey() {
   Static lastInvoked := 1, counter := 0, prevKey
   If (!identifyThisWin() || (A_TickCount - lastOtherWinClose<300))
      Return

   ; ToolTip, % hotkate , , , 2
   If (A_TickCount - lastInvoked>250)
      counter := 0

   If isVarEqualTo(hotkate, "Escape","Enter","Space")
   {
       pp := (slideShowRunning=1 || slideShowRunning=1) ? 1 : 0
       If (animGIFplaying=1)
          stopGiFsPlayback()
       If (slideShowRunning=1)
          turnOffSlideshow()
       If pp
          Return
   }

   ; addJournalEntry(A_ThisFunc "(): " thisWin "|" hotkate)
   If ((A_TickCount - lastInvoked>30) && (whileLoopExec=0 && runningLongOperation=0 || isVarEqualTo(givenKey, "Escape", "Enter","!F4")))
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
   Static vkList := {8:"BACKSPACE", 9:"TAB", C:"NUMPADCLEAR", D:"ENTER", 14:"CAPSLOCK", 1B:"ESCAPE", 20:"SPACE", 21:"PGUP", 22:"PGDN", 23:"END", 24:"HOME", 25:"LEFT", 26:"UP", 27:"RIGHT", 28:"DOWN", 2D:"INSERT", 2E:"DELETE", 5B:"SCROLLLOCK", 5D:"APPSKEY", 60:"NUMPAD0", 61:"NUMPAD1", 62:"NUMPAD2", 63:"NUMPAD3", 64:"NUMPAD4", 65:"NUMPAD5", 66:"NUMPAD6", 67:"NUMPAD7"
                  , 68:"NUMPAD8", 69:"NUMPAD9", 6A:"NUMPADMULT", 6B:"NUMPADADD", 6D:"NUMPADSUB", 6E:"NUMPADDOT", 6F:"NUMPADDIV", 70:"F1", 71:"F2", 72:"F3", 73:"F4", 74:"F5", 75:"F6", 76:"F7", 77:"F8", 78:"F9", 79:"F10", 7A:"F11", 7B:"F12", 90:"NUMLOCK", AD:"VOLUME_MUTE", AE:"VOLUME_DOWN", AF:"VOLUME_UP", B0:"MEDIA_NEXT", B1:"MEDIA_PREV", B2:"MEDIA_STOP", B3:"MEDIA_PLAY_PAUSE"
                  , FF:"PAUSE", 1:"LBUTTON", 2:"RBUTTON", 3:"BREAK", 4:"MBUTTON", 5:"XBUTTON1", 6:"XBUTTON2", 10:"SHIFT", 11:"CONTROL", 12:"ALT", 13:"PAUSE", 15:"KANA/HANGUL", 17:"JUNJA", 18:"IME_FINAL", 19:"HANJA/KANJI", 16:"IME_ON", 1A:"IME_OFF", 1C:"IME_CONVERT", 1D:"IME_NON_CONVERT", E5:"IME_PROCESSKEY", 1E:"IME_ACCEPT", 1F:"IME_MODECHANGE", 2F:"HELP", 29:"SELECT", 2A:"PRINT"
                  , 2B:"EXECUTE", 2C:"PRINT_SCREEN", 5F:"SLEEP", 7C:"F13", 7D:"F14", 7E:"F15", 7F:"F16", 80:"F17", 81:"F18", 82:"F19", 83:"F20", 84:"F21", 85:"F22", 86:"F23", 87:"F24", A6:"BROWSER_BACK", A7:"BROWSER_FORWARD", A8:"BROWSER_REFRESH", A9:"BROWSER_STOP", AA:"BROWSER_SEARCH", AB:"BROWSER_FAVORITES", AC:"BROWSER_HOME", B4:"LAUNCH_MAIL", B5:"LAUNCH_MEDIA_SELECT"
                  , B6:"LAUNCH_APP1", B7:"LAUNCH_APP2", F6:"ATTN", F7:"CrSEL", F8:"ExSEL", F9:"ERASE_EOF", FA:"PLAY", FB:"ZOOM", FD:"PA1", A0:"LSHIFT", A1:"RSHIFT", A2:"LCTRL", A3:"RCTRL", A4:"LALT", A5:"RALT", 5B:"LWIN", 5C:"RWIN", BF:"SLASH", DC:"BSLASH", C0:"TILDA", DE:"QUOTES"}
        , vkExtraList := {30:"00.1", 31:"1", 32:"2", 33:"3", 34:"4", 35:"5", 36:"6", 37:"7", 38:"8", 39:"9", 41:"A", 42:"B", 43:"C", 44:"D", 45:"E", 46:"F", 47:"G", 48:"H", 49:"I", 4A:"J", 4B:"K", 4C:"L", 4D:"M", 4E:"N", 4F:"O", 50:"P", 51:"Q", 52:"R", 53:"S", 54:"T", 55:"U", 56:"V", 57:"W", 58:"X", 59:"Y", 5A:"Z", BB:"EQUAL", BC:"COMMA", BD:"MINUS", BE:"PERIOD", BA:"COLON", DB:"LBRACKET", DD:"RBRACKET"}
        ; DF:"OEM_8", E2:"OEM_102", E1:"OEM_9", E3:"OEM_11", E4:"OEM_12", E6:"OEM_13", FE:"OEM_CLEAR", 92:"OEM_14", 93:"OEM_15", 94:"OEM_16", 95:"OEM_17", 96:"OEM_18"}
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
    If (isInRange(vk_code, 21, 28) || isVarEqualTo(vk_code, "6B", "6D", "BB", "BD", "D"))
       navKeysCounter++

    If (statusBarTooltipVisible=1)
       mouseTurnOFFtooltip()

    If (A_TickCount - lastOtherWinClose<300)
       Return 0

    If (vk_code!="1B")
    {
       If ((whileLoopExec=1 || runningLongOperation=1 || imageLoading=1) && animGIFplaying!=1 && slideShowRunning!=1)
          Return 0
    } Else
    {
       preByeRoutine()
       Return 0
    }

    vk_shift := DllCall("GetKeyState","Int", 0x10, "short") >> 16
    vk_ctrl := DllCall("GetKeyState","Int", 0x11, "short") >> 16
    vk_alt := (msg=260) ? -1 : DllCall("GetKeyState","Int", 0x12, "short") >> 16
    hotkate := constructKbdKey(vk_shift, vk_ctrl, vk_alt, vk_code)
    ; ToolTip, % vk_code "|" whileLoopExec "|" runningLongOperation "|" imageLoading "|" animGIFplaying "|" hotkate , , , 2
    If (vk_code!=10 && vk_code!=11 && vk_code!=12)
    {
       SetTimer, PreProcessKbdKey, -3
       Return 0
    }

    ; TulTip("|   ", wParam, vk_shift, vk_ctrl, vk_alt, msg, "ui thread")
}

SendMenuTabKey() {
   Static prevState := 0
   prevState := !prevState
   keyu := prevState ? "{Right}" : "{Left}"
   SendInput, % keyu
}

identifyMenus(){
   ; WinGet, OutputVar, List , % "ahk_class #32768 ahk_pid " QPVpid
   ; ToolTip, % OutputVar "=l" , , , 2
   r := WinExist("ahk_class #32768 ahk_pid " QPVpid) ? 1 : 0
   Return r
}

#If, (identifyMenus() && allowMenuReader="yes")
   RButton::
      constantMenuReader("rbutton")
   Return

   ~WheelDown::
   ~PgDn::
      SendInput, {Down 3}
   Return

   ~WheelUp::
   ~PgUp::
      SendInput, {Up 3}
   Return

   Left::
   Right::
      changeMenusBarKbd(A_ThisHotkey)
   Return

   Space::
      constantMenuReader("focused")
      ; SendInput, {Enter}
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

   +F10::
      If (menusflyOutVisible=1 || drawingShapeNow=1)
      {
         SendInput, {F10}
         toggleAppToolbar()
      }
   Return

   vkBA::    ;  [ ; ]
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

constantMenuReader(modus:=0, externMode:=0) {
   Static prevLabel := "z"
   If (mouseToolTipWinCreated=1)
   {
      mouseTurnOFFtooltip()
      Return
   }

   GetPhysicalCursorPos(x, y)
   ; ToolTip, % winID "`n" OutputVarWin , , , 2
   If (modus="focused")
   {
      ; WinID := WinActive("A")
      ; WinID := DllCall("GetFocus", "ptr")
      ; If !WinID
      ;    WinID := DllCall("GetForegroundWindow", "ptr")
      ; WinID := "0x" Format("{:x}", WinID)
      ; winChild := WinEnumChild(WinID)

      WinID := WinExist("ahk_class #32768 ahk_pid " QPVpid)
      AccFromFocused(WinID, accFocusValue, accFocusName, accIRole, accRole, styleu, strstyles, shortcut, coords)
   } Else
   {
      AccInfoUnderMouse(x, y, accFocusValue, accFocusName, accIRole, accRole, styleu, strstyles, shortcut, coords)
   }

   ; goodText := accFocusValue ? accFocusValue : accFocusName
   ; goodRoles := (accIRole=41 || accIRole=42 || accIRole=46) ? 1 : 0
   ; ToolTip, % goodText "=" goodRoles "==" WinID "==" winChild.count() , , , 2
   If (accIRole=12 && accFocusName && (prevLabel!=accFocusName || mouseToolTipWinCreated!=1 || externMode=1))
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
         msgu .= InStr(msgu, "item disabled") ? " AND CHECKED" : "`nITEM CHECKED"
      If InStr(strstyles, "0x40000000")
         msgu .= "`nSUBMENU CONTAINER"

      If !externMode
         ShowClickHalo(coords.x, coords.y, coords.w, coords.h, 1, accFocusName)

      If !externMode
         mouseCreateOSDinfoLine(msgu, PrefsLargeFonts, 0, coords)
      Else
         Return msgu
      ; ToolTip, % accFocusName , , , 2
      ; MainExe.ahkPostFunction("showtooltip", accFocusName)
   } Else If (modus="RButton")
   {
      Try MouseGetPos, ,, WinID
      WinGetClass, OutputVar, ahk_id %WinID%
      If !InStr(OutputVar, "#32768")
         SendInput, {F10}
   }

   SetTimer, repeatMenuInfosPopup, -150
}

repeatMenuInfosPopup() {
   If GetKeyState("RButton", "P")
      constantMenuReader()
}

mouseClickTurnOFFtooltip() {
    SetTimer, mouseTurnOFFtooltip, -50
}

mouseTurnOFFtooltip() {
   Global statusBarTooltipVisible := 0
   If (mouseToolTipWinCreated!=1)
      Return

   MouseGetPos, ,, OutputVarWin
   If (OutputVarWin=hGuiTip)
      Global lastWinDrag := A_TickCount - 125
   Sleep, 10
   Gui, mouseToolTipGuia: Destroy
   Global mouseToolTipWinCreated := 0
   Global statusBarTooltipVisible := 0
   Global lastZeitToolTip := A_TickCount
   SetTimer, mouseTurnOFFtooltip, Off
}

delayedWinActivateToolTipDeath() {
   WinActivate, ahk_id %lastTippyWin%
}

destroyTooltipu() {
   mouseTurnOFFtooltip()
   Sleep, 1
   MouseGetPos, ,, OutputVarWin
   If (OutputVarWin=hQPVtoolbar && ShowAdvToolbar=1)
      MouseClick, Left
}

mouseCreateOSDinfoLine(msg:=0, largus:=0, unClickable:=0, givenCoords:=0) {
    Critical, On
    Static prevMsg, lastInvoked := 1
    Global TippyMsg

    ; ToolTip, % givenCoords "===" largus "==" msg , , , 2
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
    ; Gui, mouseToolTipGuia: Margin, 0, 0
    Gui, mouseToolTipGuia: Margin, % thisFntSize, % thisFntSize
    Gui, mouseToolTipGuia: Color, c%bgrColor%
    Gui, mouseToolTipGuia: Font, s%thisFntSize% %isBold% Q5, %OSDFontName%
    Gui, mouseToolTipGuia: Add, Text, c%txtColor% gdestroyTooltipu vTippyMsg, %msg%
    Gui, mouseToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, QPV tooltip window
    prevMsg := msg
    MainExe.ahkassign("hGuiTip", hGuiTip)
    If (unClickable=1)
      WinSet, ExStyle, +0x20, ahk_id %hGuiTip%

    mouseToolTipWinCreated := 1
    delayu := StrLen(msg) * 75 + 950
    lastZeitToolTip := A_TickCount
    showOSDinfoLineNow(delayu, givenCoords)
}

showOSDinfoLineNow(delayu, givenCoords:=0) {
    If !mouseToolTipWinCreated
       Return

    GetPhysicalCursorPos(mX, mY)
    If IsObject(givenCoords)
    {
       If (givenCoords.x && givenCoords.y)
       {
          forced := 1
          mX := givenCoords.x 
          mY := givenCoords.y + givenCoords.h
       }
    } Else If InStr(givenCoords, "|")
    {
       pk := StrSplit(givenCoords, "|")
       mX := pk[1], mY := pk[2]
    }

    If (!isWinXP && forced!=1)
    {
       GetWinClientSize(Wid, Heig, hGuiTip, 1)
       k := WinMoveZ(hGuiTip, 0, mX + 20, mY + 29, Wid, Heig, 2)
       Final_x := k[1], Final_y := k[2]
    } Else
    {
       tipX := (forced=1) ?  mX : mX + 20
       tipY := (forced=1) ?  mY : mY + 20
       ResWidth := adjustWin2MonLimits(hGuiTip, tipX, tipY, Final_x, Final_y, Wid, Heig)
       MaxWidth := Floor(ResWidth*0.85)
       If (MaxWidth<Wid && MaxWidth>10)
       {
          GuiControl, mouseToolTipGuia: Move, TippyMsg, w1 h1
          GuiControl, mouseToolTipGuia:, TippyMsg,
          Gui, mouseToolTipGuia: Add, Text, xp yp c%txtColor% gmouseClickTurnOFFtooltip w%MaxWidth%, %msg%
          Gui, mouseToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, QPV tooltip window
          ResWidth := adjustWin2MonLimits(hGuiTip, tipX, tipY, Final_x, Final_y, Wid, Heig)
       }
    }

    If (Final_x!="" && Final_y!="")
       Gui, mouseToolTipGuia: Show, NoActivate AutoSize x%Final_x% y%Final_y%, QPV tooltip window
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

ShowClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu:="", stay:=0) {
    Static lastInvoked := 1, wasCreated := 0, hClickHalo

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

    If (wasCreated=1)
    {
       displayClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu, hClickHalo, stay)
       Return
    }

    Gui, MclickH: Destroy
    Sleep, 20
    modus := msgu ? "" : "+E0x20 +E0x8000000"
    Gui, MclickH: +AlwaysOnTop -DPIScale -Caption +ToolWindow +Owner %modus% +hwndhClickHalo
    Gui, MclickH: Color, 0099FF
    ; Gui, MclickH: Show, NoActivate Hide x%mX% y%mY% w%BoxW% h%BoxH%, WinMouseClick
    ; WinSet, ExStyle, 0x20, WinMouseClick
    If !msgu
       msgu := "QPV blip"

    ; fnOutDebug(msgu "|" stay)
    displayClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu, hClickHalo, stay)
    WinSet, Transparent, 128, ahk_id %hClickHalo%
}

displayClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu, hwnd, stay) {
    If (mX!="" && mY!="")
       Gui, MclickH: Show, NoActivate x%mX% y%mY% w%BoxW% h%BoxH%, %msgu% ; ahk_id %hClickHalo%

    If (boxMode=0)
       WinSet, Region, 0-0 W%BoxW% H%BoxH% E, ahk_id %hwnd%
    Else
       WinSet, Region,, ahk_id %hwnd%

    WinSet, AlwaysOnTop, On, ahk_id %hwnd%
    If !stay
       SetTimer, DestroyClickHalo, -300
}

DestroyClickHalo() {
    Gui, MclickH: Hide
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
      rc := ""
   }
}

repositionWindowCenter(whichGUI, hwndGUI, referencePoint, winTitle:="", winPos:="") {
    If !winPos
    {
       SysGet, MonitorCount, 80
       ActiveMonDetails := calcScreenLimits(referencePoint)
       ResWidth := ActiveMonDetails.w, ResHeight:= ActiveMonDetails.h
       mCoordLeft := ActiveMonDetails.mCLeft
       mCoordTop := ActiveMonDetails.mCTop
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
   ; modified by Marius Șucan to return an array

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

AccFromFocused(hwnd, byref val, byref name, byref RoleChild, byref RoleParent, byref styleu, byref strstyles, byref shortcut, byref coords) {
  Static WM_GETOBJECT := 0x003D, hLibrary := 0
  If !hLibrary
     hLibrary := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")

  SendMessage, WM_GETOBJECT, 0, 1, Chrome_RenderWidgetHostHWND1, % "ahk_id " hwnd
  AccObj := Acc_ObjectFromWindow(hwnd)
  Try While IsObject(AccObj.accFocus)
  {
    AccObj := AccObj.accFocus
  }

  Try
  {
     child := AccObj.accFocus
     ; ChildCount := AccObj.accChildCount
     Name := AccObj.accName(child)
     Val := AccObj.accValue(child)
     RoleChild := AccObj.accRole(child)
     shortcut := AccObj.accKeyboardShortCut(child)
     AccState(AccObj, child, styleu, strstyles)
     coords := AccGetLocation(AccObj, child)
     ; ToolTip, % coords.x "==" coords.y , , , 2
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

AccInfoUnderMouse(mx, my, byref val, byref name, byref RoleChild, byref RoleParent, byref styleu, byref strstyles, byref shortcut, byref coords) {
  Static hLibrary, WM_GETOBJECT := 0x003D  
  If !hLibrary
     hLibrary := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")

  AccObj := Acc_ObjectFromPoint(child, mx, my)
  If !IsObject(AccObj)
     Return

  ; SendMessage, WM_GETOBJECT, 0, 1, Chrome_RenderWidgetHostHWND1, % "ahk_id " WinID
  Try
  {
     ; ChildCount := AccObj.accChildCount
     Name := AccObj.accName(child)
     Val := AccObj.accValue(child)
     RoleChild := AccObj.accRole(child)
     shortcut := AccObj.accKeyboardShortCut(child)
     AccState(AccObj, child, styleu, strstyles)
     coords := AccGetLocation(AccObj, child)
     ; ToolTip, % coords.x "==" coords.y , , , 2
  }
  ; RoleParent := AccObj.accRole()
  Return ; ChildCount name val RoleChild RoleParent
}

AccGetLocation(Acc, ChildId=0) {
  Static x := 0, y := 0, w := 0, h := 0
  coord := []
  try Acc.accLocation(ComObj(0x4003,&x), ComObj(0x4003,&y), ComObj(0x4003,&w), ComObj(0x4003,&h), ChildId)
  coord.x := NumGet(x,0,"int"),  coord.y := NumGet(y,0,"int")
  coord.w := NumGet(w,0,"int"),  coord.h := NumGet(h,0,"int")
  ; AccCoord[1]:=NumGet(x,0,"int"), AccCoord[2]:=NumGet(y,0,"int"), AccCoord[3]:=NumGet(w,0,"int"), AccCoord[4]:=NumGet(h,0,"int")
  Return coord
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
   If (A_OSVersion="WIN_7" || A_OSVersion="WIN_XP")
      Return

   uxtheme := DllCall("GetModuleHandle", "str", "uxtheme", "uptr")
   SetPreferredAppMode := DllCall("GetProcAddress", "uptr", uxtheme, "ptr", 135, "uptr")
   global AllowDarkModeForWindow := DllCall("GetProcAddress", "uptr", uxtheme, "ptr", 133, "uptr")
   FlushMenuThemes := DllCall("GetProcAddress", "uptr", uxtheme, "ptr", 136, "uptr")
   DllCall(SetPreferredAppMode, "int", modus) ; Dark
   DllCall(FlushMenuThemes)
   interfaceThread.ahkPostFunction("setMenusTheme", modus)
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
  ; modified by Marius Șucan

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

JEE_ClientToScreen(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472

  VarSetCapacity(POINT, 8)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ClientToScreen", "UPtr", hWnd, "UPtr", &POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
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

GetWindowPlacement(hWnd) {
    Local WINDOWPLACEMENT, Result := {}
    NumPut(VarSetCapacity(WINDOWPLACEMENT, 44, 0), WINDOWPLACEMENT, 0, "UInt")
    r := DllCall("GetWindowPlacement", "UPtr", hWnd, "UPtr", &WINDOWPLACEMENT)
    If (r=0)
    {
       WINDOWPLACEMENT := ""
       Return 0
    }
    Result.x := NumGet(WINDOWPLACEMENT, 28, "Int")
    Result.y := NumGet(WINDOWPLACEMENT, 32, "Int")
    Result.w := NumGet(WINDOWPLACEMENT, 36, "Int") - Result.x
    Result.h := NumGet(WINDOWPLACEMENT, 40, "Int") - Result.y
    Result.flags := NumGet(WINDOWPLACEMENT, 4, "UInt") ; 2 = WPF_RESTORETOMAXIMIZED
    Result.showCmd := NumGet(WINDOWPLACEMENT, 8, "UInt") ; 1 = normal, 2 = minimized, 3 = maximized
    WINDOWPLACEMENT := ""
    Return Result
}

GetWinHwndAtPoint(nX, nY) {
    a := DllCall("WindowFromPhysicalPoint", "Uint64", nX|(nY << 32), "Ptr")
    a := Format("{1:#x}", a)
    WinGetClass, h, ahk_id %a%
    Return [a, h]
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


setDarkWinAttribs(hwndGUI, modus:=2) {
   If (A_OSVersion="WIN_7" || A_OSVersion="WIN_XP")
      Return

   if (A_OSVersion >= "10.0.17763" && SubStr(A_OSVersion, 1, 4)>=10)
   {
       DWMWA_USE_IMMERSIVE_DARK_MODE := 19
       if (A_OSVersion >= "10.0.18985")
          DWMWA_USE_IMMERSIVE_DARK_MODE := 20
       DllCall("dwmapi\DwmSetWindowAttribute", "UPtr", hwndGUI, "int", DWMWA_USE_IMMERSIVE_DARK_MODE, "int*", modus, "int", 4)
   }
   DllCall(AllowDarkModeForWindow, "UPtr", hwndGUI, "int", modus) ; Dark
}

