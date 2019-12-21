; Original script details:
;   Name:     AHK Picture Viewer
;   Version:  1.0.0 on Oct 4, 2010 by SBC
;   Platform: Windows XP or later
;   Author:   SBC - http://sites.google.com/site/littlescripting/
;   Found on: https://autohotkey.com/board/topic/58226-ahk-picture-viewer/
;
; New script details:
;   Name:     Quick Picto Viewer
;   Version:  [see change logs file]
;   Platform: Windows 7 or later
;   Author:   Marius Șucan - http://marius.sucan.ro/
;   GitHub:   https://github.com/marius-sucan/Quick-Picto-Viewer
;
; Script main functionalities:
; Display images and creates slideshows using GDI+ 
; supported formats: jpeg, jpg, bmp, png, gif, tif, emf
;
; Original Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
;_________________________________________________________________________________________________________________Auto Execute Section____

;@Ahk2Exe-SetName Quick Picto Viewer
;@Ahk2Exe-SetDescription Quick Picto Viewer
;@Ahk2Exe-SetVersion 3.9.0
;@Ahk2Exe-SetCopyright Marius Şucan (2019)
;@Ahk2Exe-SetCompanyName marius.sucan.ro
;@Ahk2Exe-SetMainIcon quick-picto-viewer.ico

#NoEnv
#NoTrayIcon
#MaxHotkeysPerInterval, 500
#MaxThreads, 255
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#MaxMem, 1924
#IfTimeout, 35
#SingleInstance, off
#UseHook, Off
#Include, Gdip_All.ahk
#Include, freeimage.ahk
#Include, MCI.ahk
SetWinDelay, 1

Global PVhwnd := 1, hGDIwin := 1, hGDIthumbsWin := 1, hGIFsGuiDummy := 1, pPen4
   , glPG, glOBM, glHbitmap, glHDC, pPen1, pPen1d, pPen2, pPen3, AmbientalTexBrush
   , pBrushHatch, pBrushWinBGR, pBrushA, pBrushB, pBrushC, pBrushD, currentPixFmt
   , pBrushE, pBrushHatchLow, hGuiTip := 1, hGuiThumbsHL := 1, hSetWinGui := 1
   , editDummy, prevFullThumbsUpdate := 1, winGDIcreated := 0, ThumbsWinGDIcreated := 0
   , hPicOnGui1, scriptStartTime := A_TickCount, lastEditRHChange :=1
   , newStaticFoldersListCache := "", lastEditRWChange := 1
   , prevTooltipDisplayTime := 1, mainCompiledPath := "", wasInitFIMlib := 0
   , filteredMap2mainList := [], thumbsCacheFolder := A_ScriptDir "\thumbs-cache"
   , resultedFilesList := [], currentFileIndex, maxFilesIndex := 0
   , appTitle := "Quick Picto Viewer", FirstRun := 1, hSNDmediaFile
   , bckpResultedFilesList := [], bkcpMaxFilesIndex := 0
   , DynamicFoldersList := "", historyList, GIFsGuiCreated := 0
   , RandyIMGids := [], SLDhasFiles := 0, IMGlargerViewPort := 0
   , IMGdecalageY := 1, IMGdecalageX := 1, imgQuality, usrFilesFilteru := ""
   , RandyIMGnow := 0, GDIPToken, Agifu, gdiBitmapSmall, hSNDmedia
   , AprevGdiBitmap, BprevGdiBitmap, msgDisplayTime := 3000
   , slideShowRunning := 0, CurrentSLD := "", markedSelectFile := ""
   , ResolutionWidth, ResolutionHeight, prevStartIndex := -1
   , gdiBitmap, mainSettingsFile := "quick-picto-viewer.ini"
   , RegExFilesPattern := "i)(.\\*\.(dib|tif|tiff|emf|wmf|rle|png|bmp|gif|jpg|jpeg|jpe|DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f|jfif))$"
   , RegExFIMformPtrn := "i)(.\\*\.(DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f))$"
   , saveTypesRegEX := "i)(.\.(bmp|j2k|j2c|jp2|jxr|wdp|hdp|png|tga|tif|tiff|webp|gif|jng|jif|jfif|jpg|jpe|jpeg|ppm|xpm))$"
   , saveTypesFriendly := ".BMP, .GIF, .HDP, .J2C, .J2K, .JFIF, .JIF, .JNG, .JP2, .JPE, .JPEG, .JPG, .JXR, .PNG, .PPM, .TGA, .TIF, .TIFF, .WDP, .WEBP or .XPM"
   , saveAlphaTypesRegEX := "i)(.\.(j2k|j2c|jp2|jxr|wdp|hdp|png|tga|tif|tiff|webp))$"
   , openFptrn1 := "*.png;*.bmp;*.gif;*.jpg;*.tif;*.tga;*.webp;*.jpeg"
   , openFptrn2 := "*.dds;*.emf;*.exr;*.g3;*.hdp;*.iff;*.j2c;*.j2k;*.jbg;*.jif;*.jng;*.jp2;*.jxr;*.koa;*.lbm;*.mng;*.pbm;*.pcd;*.pct;*.pcx;*.pfm;*.pgm;*.pic;*.ppm;*.psd;*.ras;*.sgi;*.wap;*.wbm;*.wbmp;*.wdp;*.wmf;*.xbm;*.xpm"
   , openFptrn3 := "*.3fr;*.arw;*.bay;*.bmq;*.cap;*.cine;*.cr2;*.crw;*.cs1;*.dc2;*.dcr;*.drf;*.dsc;*.erf;*.fff;*.hdr;*.ia;*.iiq;*.k25;*.kc2;*.kdc;*.mdc;*.mef;*.mos;*.mrw;*.nef;*.nrw;*.orf;*.pef;*.ptx;*.pxn;*.qtk;*.raf;*.raw;*.rdc;*.rw2;*.rwz;*.sr2;*.srf;*.x3f"
   , openFptrn4 := "*.tiff;*.targa;*.jpe;*.dib;*.pict;*.rle"
   , dialogSaveFptrn := "*.bmp;*.gif;*.hdp;*.j2c;*.j2k;*.jfif;*.jif;*.jng;*.jp2;*.jpe;*.jpeg;*.jpg;*.jxr;*.png;*.ppm;*.tga;*.tif;*.tiff;*.wdp;*.webp;*.xpm"
   , LargeUIfontValue := 14, AnyWindowOpen := 0, toolTipGuiCreated := 0
   , PrefsLargeFonts := 0, OSDbgrColor := "131209", OSDtextColor := "FFFEFA"
   , PasteFntSize := 17, OSDfntSize := 13, OSDFontName := "Arial", prevOpenFolderPath := ""
   , mustGenerateStaticFolders := 1, lastWinDrag := 1, img2resizePath := ""
   , prevFileMovePath := "", lastGIFdestroy := 1, prevAnimGIFwas := ""
   , thumbsW := 300, thumbsH := 300, thumbsDisplaying := 0, scrollAxis := 0
   , othumbsW := 300, othumbsH := 300, ForceRegenStaticFolders := 0
   , CountFilesFolderzList := 0, RecursiveStaticRescan := 0, imgSelLargerViewPort := 0
   , UsrMustInvertFilter := 0, overwriteConflictingFile := 0, LastPrevFastDisplay := 0
   , prevFileSavePath := "", imgHUDbaseUnit := Round(OSDfntSize*3.5), lastLongOperationAbort := 1
   , lastOtherWinClose := 1, UsrCopyMoveOperation := 2, editingSelectionNow := 0
   , ForceNoColorMatrix := 0, activateImgSelection := 0, prevFastDisplay := 1, hSNDmediaDuration
   , imgSelX1 := 0, imgSelY1 := 0, imgSelX2 := -1, imgSelY2 := -1, adjustNowSel := 0
   , selDotX, selDotY, selDotAx, selDotAy, selDotBx, selDotBy, selDotCx, selDotCy
   , prcSelX1, prcSelX2, prcSelY1, prcSelY2, PannedFastDisplay := 1, thumbSelFileList
   , dotsSize := imgHUDbaseUnit//4, ViewPortBMPcache, startZeitIMGload, LbtnDwn := 0
   , imageLoading := 0, PrevGuiSizeEvent := 0, imgSelOutViewPort := 0, prevGUIresize := 1
   , mPosCtrl, hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
   , hCursN := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
   , hCursMove := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
   , hCursFinger := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32649, "Ptr")
   , remCacheOldDays := 0, jpegDoCrop := 0, jpegDesiredOperation := 1, prevMPosCtrl := ""
   , rDesireWriteFMT := "jpg", FIMfailed2init := 0, prevMaxSelX, prevMaxSelY, prevDestPosX, prevDestPosY
   , CCLVO := "-E0x200 +Border -Hdr -Multi +ReadOnly Report AltSubmit gSetColors", FontList := []
   , dummyPos := (A_OSVersion!="WIN_7") ? 0 : "" , totalFramesIndex, pVwinTitle, AprevImgCall, BprevImgCall
   , FIMimgBPP, FIMformat, coreIMGzeitLoad, desiredFrameIndex := 0, prevDrawingMode := 0
   , diffIMGdecX := 0, diffIMGdecY := 0, anotherVPcache, oldZoomLevel := 0, fullPath2exe
   , hitTestSelectionPath, scrollBarHy := 0, scrollBarVx := 0, HistogramBMP, internalColorDepth := 0
   , drawModeBzeit := 1, drawModeAzeit := 1, drawModeCzeit := 1, prevColorAdjustZeit := 1, AutoCropBordersSize := 15
   , yetAnotherVPcache, executingCanceableOperation := 1, mustAbandonCurrentOperations := 0, hCropCornersPic
   , usrAutoCropDeviationPixels := 0
   , QPVregEntry := "HKEY_CURRENT_USER\SOFTWARE\Quick Picto Viewer"
   , version := "3.9.8", vReleaseDate := "21/11/2019"

 ; User settings
   , askDeleteFiles := 1, enableThumbsCaching := 1, OnConvertKeepOriginals := 1, userOverwriteFiles := 0
   , thumbsAratio := 3, thumbsZoomLevel := 1, zatAdjust := 0
   , WindowBgrColor := "010101", slideShowDelay := 3000, userMultiDelChoice := 2
   , IMGresizingMode := 1, SlideHowMode := 1, TouchScreenMode := 1
   , lumosAdjust := 1, GammosAdjust := 0, userimgQuality := 0
   , imgFxMode := 1, FlipImgH := 0, FlipImgV := 0, satAdjust := 1
   , imageAligned := 5, filesFilter := "", isAlwaysOnTop := 0
   , noTooltipMSGs := 0, zoomLevel := 1, skipDeadFiles := 0, userHQraw  := 0
   , isTitleBarHidden := 0, lumosGrayAdjust := 0, GammosGrayAdjust := 0
   , MustLoadSLDprefs := 0, animGIFsSupport := 1, move2recycler := 1
   , SLDcacheFilesList := 1, autoRemDeadEntry := 1, ResizeWithCrop := 1
   , easySlideStoppage := 0, ResizeInPercentage := 0, usrAdaptiveThreshold := 1
   , ResizeKeepAratio := 1, ResizeQualityHigh := 1, ResizeRotationUser := "Rotate: 0°"
   , ResizeApplyEffects := 1, autoAdjustMode := 1, doSatAdjusts := 1
   , ResizeDestFolder, ResizeUseDestDir := 0, chnRdecalage := 0, chnGdecalage := 0
   , chnBdecalage := 0, alwaysOpenwithFIM := 0, bwDithering := 0, showHistogram := 0
   , userUnsprtWriteFMT := 1, userDesireWriteFMT := 9, hueAdjust := 0, syncSlideShow2Audios := 0
   , DisplayTimeUser := 3, FontBolded := 1, FontItalica := 0, showInfoBoxHUD := 0, usrAutoCropGenerateSelection := 0
   , usrTextureBGR := 0, realGammos := 1, imgThreshold := 0, relativeImgSelCoords := 1, usrAutoCropDeviation := 0
   , RenderOpaqueIMG := 1, vpIMGrotation := 0, usrTextAlign := "Left", autoPlaySNDs := 1, usrAutoCropDeviationSnap := 1
   , ResizeCropAfterRotation := 1, usrColorDepth := 1, ColorDepthDithering := 1, mediaSNDvolume := 80
   , borderAroundImage := 0, performAutoCropNow := 0, usrAutoCropColorTolerance := 5, usrAutoCropImgThreshold := 0.005 
   , SimpleOperationsDoCrop := 0, SimpleOperationsRotateAngle := "0°", SimpleOperationsScaleImgFactor := "100 %"
   , SimpleOperationsNoPromptOnSave := 0, SimpleOperationsFlipV := 0, SimpleOperationsFlipH := 0, doSlidesTransitions := 0

RegRead, InitCheckReg, %QPVregEntry%, Running
RegRead, InitTimeReg, %QPVregEntry%, LastStartTime
; MsgBox, % InitTimeReg " --- " InitCheckRes
If ((A_TickCount - InitTimeReg < 600)  && IsNumber(InitTimeReg) && (InitCheckReg=1) && InitTimeReg>0)
   ExitApp

If !A_IsCompiled
   Menu, Tray, Icon, quick-picto-viewer.ico


DetectHiddenWindows, On
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen
OnExit, Cleanup

If A_IsCompiled
   initCompiled()

thisGDIPversion := Gdip_LibrarySubVersion()
GDIPToken := Gdip_Startup()
if (!GDIPToken || thisGDIPversion<1.78)
{
   MsgBox, 48, %appTitle%, ERROR: unable to initialize GDI+...`n`nThe program will now exit.`n`nRequired GDI+ library wrapper: v1.78 - extended compilation edition.
   ExitApp
}

OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x203, "WM_LBUTTONDOWN") ; WM_LBUTTONDOWN double click
OnMessage(0x202, "ResetLbtn") ; WM_LBUTTONUP
OnMessage(0x2a3, "ResetLbtn") ; WM_MOUSELEAVE
If (A_OSVersion="WIN_7")
   OnMessage(0x216, "WM_MOVING")

; OnMessage(0x388, "WM_PENEVENT")
OnMessage(0x200, "WM_MOUSEMOVE")
OnMessage(0x06, "activateMainWin")   ; WM_ACTIVATE 
OnMessage(0x08, "activateMainWin")   ; WM_KILLFOCUS 
Loop, 9
    OnMessage(255+A_Index, "PreventKeyPressBeep")   ; 0x100 to 0x108

RegWrite, REG_SZ, %QPVregEntry%, Running, 1
RegWrite, REG_SZ, %QPVregEntry%, LastStartTime, % A_TickCount
IniRead, FirstRun, % mainSettingsFile, General, FirstRun, @
If (FirstRun!=0)
{
   writeMainSettings()
   FirstRun := 0
   IniWrite, % FirstRun, % mainSettingsFile, General, FirstRun
} Else loadMainSettings()

BuildTray()
BuildGUI()
InitStuff()

Loop, 6
{
   If (A_Index=6)
   {
      doWelcomeNow := 1
   } Else If RegExMatch(A_Args[A_Index], "i)(.\.sld)$")
   {
      OpenSLD(A_Args[A_Index])
      Global scriptStartTime := A_TickCount
      Break
   } Else If RegExMatch(A_Args[A_Index], RegExFilesPattern)
   {
      OpenArgFile(A_Args[A_Index])
      Break
   }
}

If (doWelcomeNow=1)
   Settimer, drawWelcomeImg, -100
Return

;_____________________________________Hotkeys_________________

identifyThisWin(noReact:=0) {
  Static prevR, lastInvoked := 1
  If (A_TickCount - lastInvoked < 60)
     Return prevR

  A := WinActive("A")
  If (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin || A=hGIFsGuiDummy || A=hGuiTip || A=hGuiThumbsHL)
  {
     If (A_OSVersion="WIN_7" && A!=PVhwnd && noReact!=2) && (A_TickCount - lastInvoked > 150)
     {
        lastInvoked := A_TickCount
        WinActivate, ahk_id %PVhwnd%
     }
     prevR := 1
  } Else prevR := 0
  Return prevR
}

#If (identifyThisWin()=1)
    ^vk4F::    ; Ctrl+O
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          OpenFiles()
    Return

    ^vk4E::    ; Ctrl+N
       If A_IsCompiled
          Run, % fullPath2exe
       Else
          Run, % A_ScriptFullPath
    Return

    F12::    ; Ctrl+P
    ^vk50::    ; Ctrl+P
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          PrefsPanelWindow()
    Return

    !vk4F::    ; Alt+O
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          OpenRawFiles()
    Return

    +vk4F::    ; Shift+O
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          OpenFolders()
    Return

    !Space::
       Win_ShowSysMenu(PVhwnd)
    Return

    ~F10::
    ~+F10::
    ~!F10::
    ^AppsKey::
    +AppsKey::
    #AppsKey::
    !AppsKey::
    AppsKey::
       InitGuiContextMenu()
    Return

    ~Insert Up::
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          addNewFile2list()
    Return

    ^vk56 Up::   ; Ctrl+V
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          PasteClipboardIMG()
    Return

    +Esc::
       restartAppu()
    Return

    F1::
       AboutWindow()
    Return

    !F4::
    Esc::
       escRoutine()
    Return
#If

#If (identifyThisWin()=1 && GIFsGuiCreated=1)
    ~LButton::
      extendedDestroyGIFuWin(0)
    Return

    ~RButton::
      MouseGetPos,,, OutputVarWin
      If (OutputVarWin!=PVhwnd && OutputVarWin!=hGIFsGuiDummy)
         extendedDestroyGIFuWin(1)
    Return
#If

#If (identifyThisWin()=1 && !AnyWindowOpen && currentFileIndex=0 && !CurrentSLD)
    ~vk44 Up::   ; D
      toggleImgSelection()
    Return

    ~^vk44 Up::   ; Ctrl+D
      resetImgSelection()
    Return

    ~vk45 Up::   ; E
      ToggleEditImgSelection()
    Return

    ~vk59 Up::   ; Y
      AutoCropPanelWindow()
    Return

    ~vk49 Up::   ; I
      If (thumbsDisplaying!=1)
         ToggleInfoBoxu()
      Else
         ShowImgInfosPanel()
    Return

    ~+vk49 Up::   ; Shift+I
      ShowImgInfosPanel()
    Return

    vkDB::   ; [
      ChangeLumos(-1)
    Return

    vkDD::   ; ]
      ChangeLumos(1)
    Return

    +vkDB::   ; Shift + [
      ChangeGammos(-1)
    Return

    +vkDD::   ; Shift + ]
      ChangeGammos(1)
    Return

    ^vkDB::   ; Ctrl + [
      ChangeSaturation(-1)
    Return

    ^vkDD::   ; Ctrl + ]
      ChangeSaturation(1)
    Return

    !vkDB::   ; Alt + [
      ChangeRealGamma(-1)
    Return

    !vkDD::   ; Alt + ]
      ChangeRealGamma(1)
    Return

    vkDC Up::   ; \
      ResetImageView()
    Return

    ^vkDC Up::   ; Ctrl+\
      HardResetImageView()
    Return

    +vkDC Up::   ; Shift+\
      toggleColorAdjustments()
    Return

    ~vkBF Up::
    ~NumpadDiv Up::
       IMGresizingMode := 0
       ToggleImageSizingMode()
    Return

    ~NumpadMult Up::
       IMGresizingMode := 3
       IMGdecalageX := IMGdecalageY := zoomLevel := 1
       ToggleImageSizingMode()
    Return

    NumpadAdd::
    vkBB::    ; [=]
       ChangeZoom(1)
    Return

    NumpadSub::
    vkBD::   ; [-]
       ChangeZoom(-1)
    Return

    ~+vk48 Up::    ; Shift+H
       ToggleImgHistogram()
    Return

    ~vk48 Up::    ; H
       TransformIMGh()
    Return

   ~vk56 Up::    ; V
       TransformIMGv()
    Return

    ~vk55 Up::  ;  U
       ColorsAdjusterPanelWindow()
    Return

    vk46 Up::     ; F
       ToggleImgFX(-1)
    Return

    +vk46 Up::     ; Shift+F
       ToggleImgFX(1)
    Return

    +vk51 Up::  ;  Shift+Q-
       ToggleImgColorDepth(1)
    Return

    vk51 Up::  ;   Q
       ToggleImgColorDepth(-1)
    Return

    vk41 Up::     ; A
       ToggleIMGalign()
    Return

    ^vk41 Up::     ; Ctrl+A
       selectEntireImage()
    Return

    vk39::    ; 9
       changeImgRotationInVP(-1)
    Return

    vk30::    ; 0
       changeImgRotationInVP(1)
    Return

    Up::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("U")
    Return

    Down::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("D")
    Return

    ^WheelUp::
       IMGresizingMode := 4
       ChangeZoom(1, "WheelUp")
    Return

    ^WheelDown::
       IMGresizingMode := 4
       ChangeZoom(-1, "WheelDown")
    Return

    WheelUp::
    Right::
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(1, "WheelUp")
          Return
       } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("R")
    Return

    WheelDown::
    Left::
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(-1, "WheelDown")
          Return
       } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("L")
    Return
#If

#If (identifyThisWin()=1 && !AnyWindowOpen && CurrentSLD && maxFilesIndex>0)
    Space::
       If (thumbsDisplaying=1 || markedSelectFile)
          markThisFileNow()
       Else If (imageLoading!=1 && IMGlargerViewPort=1 && IMGresizingMode=4 && slideShowRunning!=1)
          Try DllCall("user32\SetCursor", "Ptr", hCursMove)
       Else If (slideShowRunning=1)
          dummyInfoToggleSlideShowu()
       Else If (A_TickCount - lastOtherWinClose>300)
          InfoToggleSlideShowu()
    Return 

    vk39::    ; 9
       changeImgRotationInVP(-1)
    Return

    vk30::    ; 0
       changeImgRotationInVP(1)
    Return

    ~vk59 Up::   ; Y
      AutoCropPanelWindow()
    Return

    ~vk4A Up::    ; Ctrl+J
       Jump2index()
    Return

    ~+Insert Up::
       addNewFolder2list()
    Return

    ~Tab Up::
       markThisFileNow()
    Return

    ~+Tab Up::
    ~^Tab Up::
       dropFilesSelection()
    Return

    ~F11::
    ~Enter::
       If (A_TickCount - lastOtherWinClose>200)
          ToggleThumbsMode()
    Return

    ~^vk43 Up::    ; Ctrl+C
       CopyImage2clip()
    Return

    ~vk42 Up::    ; B
       CompareImagesAB()
    Return

    ~vk43 Up::    ; C
       InvokeCopyFiles()
    Return

    ~^vk55 Up::    ; Ctrl+U
       ForceRegenStaticFolders := 0
       If (RegExMatch(CurrentSLD, "i)(\.sld)$") && mustGenerateStaticFolders!=1 && SLDcacheFilesList=1)
          FolderzPanelWindow()
    Return

    ~!vk55 Up::    ; Alt+U
       ForceRegenStaticFolders := 0
       DynamicFolderzPanelWindow()
    Return

    ~^vk4B Up::    ; Ctrl+K
       converterPanelWindow()
    Return

    ~vk4B Up::    ; K
       imgPath := resultedFilesList[currentFileIndex]
       If RegExMatch(imgPath, "i)(.\.(jpg|jpeg))$") || markedSelectFile
          PanelJpegPerformOperation()
    Return

    ~^+vk43 Up::    ; Ctrl+Shift+C
    ~+vk43 Up::     ; Shift+C
       CopyImagePath()
    Return

    ~vk4F Up::   ; O
      OpenThisFile()
    Return

    ~vk49 Up::   ; I
      If (thumbsDisplaying!=1)
         ToggleInfoBoxu()
      Else
         ShowImgInfosPanel()
    Return

    ~+vk49 Up::   ; Shift+I
      ShowImgInfosPanel()
    Return

    vkDB::   ; [
      ChangeLumos(-1)
    Return

    vkDD::   ; ]
      ChangeLumos(1)
    Return

    ^vkDB::   ; Ctrl + [
      ChangeSaturation(-1)
    Return

    ^vkDD::   ; Ctrl + ]
      ChangeSaturation(1)
    Return

    !vkDB::   ; Alt + [
      ChangeRealGamma(-1)
    Return

    !vkDD::   ; Alt + ]
      ChangeRealGamma(1)
    Return

    +vkDB::   ; Shift + [
      ChangeGammos(-1)
    Return

    +vkDD::   ; Shift + ]
      ChangeGammos(1)
    Return

    vkDC Up::   ; \
      ResetImageView()
    Return

    ^vkDC Up::   ; Ctrl+\
      HardResetImageView()
    Return

    +vkDC Up::   ; Shift+\
      toggleColorAdjustments()
    Return

    ~^vk45 Up::   ; Ctrl+E
      OpenThisFileFolder()
    Return

    ~vk44 Up::   ; D
      toggleImgSelection()
    Return

    ~^vk44 Up::   ; Ctrl+D
      resetImgSelection()
    Return

    ~vk45 Up::   ; E
      ToggleEditImgSelection()
    Return

    ~^vk46 Up::   ; Ctrl+F
      enableFilesFilter()
    Return

    ~vk53 Up::   ; S
       SwitchSlideModes()
    Return

    ~^vk53 Up::   ; Ctrl+S
       SaveClipboardImage()
    Return

    ~+^vk53 Up::   ; Ctrl+Shift+S
       SaveClipboardImage("yay")
    Return

    vk54 Up::   ; T
       If (thumbsDisplaying=1)
          ChangeThumbsAratio()
       Else
          ToggleImageSizingMode()
    Return

    vkBF Up::     ; /
    NumpadDiv Up::
       IMGresizingMode := 0
       ToggleImageSizingMode()
    Return

    NumpadMult Up::
       IMGresizingMode := 3
       IMGdecalageX := IMGdecalageY := zoomLevel := 1
       ToggleImageSizingMode()
    Return

    ~BackSpace::
       PrevRandyPicture()
    Return

    ~+Space::
       If (thumbsDisplaying=1 || markedSelectFile)
          dropFilesSelection()
       Else
          dummyInfoToggleSlideShowu()
    Return

    ~^Space Up::
       If (thumbsDisplaying=1 || markedSelectFile)
          dropFilesSelection()
       Else If (slideShowRunning=1)
          ToggleSlideShowu()
       Else If StrLen(filesFilter)>1
       {
          usrFilesFilteru := ""
          coreEnableFiltru(usrFilesFilteru)
          Return
       } Else
       {
          r := resultedFilesList[currentFileIndex]
          zPlitPath(r, 0, OutFileName, OutDir)
          coreEnableFiltru(SubStr(OutDir, 3) "\")
       }
    Return

    ~^BackSpace::
    ~+BackSpace::
    ~!BackSpace::
       resetSlideshowTimer(0)
       RandomPicture()
    Return

    NumpadAdd::
    vkBB::    ; [=]
       ChangeZoom(1)
    Return

    NumpadSub::
    vkBD::   ; [-]
       ChangeZoom(-1)
    Return

    !Delete::
       InListMultiEntriesRemover()
    Return

    vkBE::    ; [,]
       IncreaseSlideSpeed()
    Return

    vkBC::   ; [.]
       DecreaseSlideSpeed()
    Return

    +vkBC Up::   ; Shift + [.]
    +vkBE Up::   ; Shift + [,]
       defineEntireSlideshowDurationPanel()
    Return

    ~F5 Up::
       RefreshImageFileAction()
    Return

    ~+F5 Up::
       RefreshFilesList()
    Return

    ~^F5 Up::
       invertRecursiveness()
    Return

    ~+vk48 Up::    ; Shift+H
       ToggleImgHistogram()
    Return

    ~vk48 Up::    ; H
       TransformIMGh()
    Return

   ~vk56 Up::    ; V
       TransformIMGv()
    Return

    ~vk52 Up::     ; R
       resetSlideshowTimer(0)
       RandomPicture()
    Return

    ~^vk52 Up::     ; Ctrl+R
       ResizeImagePanelWindow()
    Return

    ~+vk52 Up::     ; Shift+R
       SimpleResizeRotatePanel()
    Return

    ~F2 Up::
       RenameThisFile()
    Return

    ~vk4D Up::     ; M
       InvokeMoveFiles()
    Return

    ~vk55 Up::  ;  U
       ColorsAdjusterPanelWindow()
    Return

    +vk51 Up::  ;  Shift+Q-
       ToggleImgColorDepth(1)
    Return

    vk51 Up::  ;   Q
       ToggleImgColorDepth(-1)
    Return

    vk46 Up::     ; F
       ToggleImgFX(-1)
    Return

    +vk46 Up::     ; Shift+F
       ToggleImgFX(1)
    Return

    vk41 Up::     ; A
       ToggleIMGalign()
    Return
    
    vk58 Up::   ; X
       PlayAudioFileAssociatedNow()
    Return

    +vk58 Up::   ; Shift+X
       StopMediaPlaying()
    Return

    vk31::   ; 1
       ChangeVolume(-1)
    Return

    vk32::   ; 1
       ChangeVolume(1)
    Return

    ^vk41 Up::     ; Ctrl+A
       selectEntireImage()
    Return

    ~Del Up::
       DeletePicture()
    Return

    ~+Del Up::
       If !markedSelectFile
       {
           DeletePicture()
           Sleep, 350
           InListMultiEntriesRemover()
       }
    Return

    Up::
    +Up::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("U")
       Else ; If (thumbsDisplaying=1)
          ThumbsNavigator("Upu", A_ThisHotkey)
    Return

    Down::
    +Down::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("D")
       Else ; If (thumbsDisplaying=1)
          ThumbsNavigator("Down", A_ThisHotkey)
    Return

    ^WheelUp::
       IMGresizingMode := 4
       ChangeZoom(1, "WheelUp")
    Return

    ^WheelDown::
       IMGresizingMode := 4
       ChangeZoom(-1, "WheelDown")
    Return

    WheelUp::
    Right::
    +Right::
       If (InStr(A_ThisHotkey, "wheel") && thumbsDisplaying=1)
       {
          ThumbsNavigator("PgUp", A_ThisHotkey)
          Return
       }
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(1, "WheelUp")
          Return
       }
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("R")
       } Else
       {
          resetSlideshowTimer(0)
          If (thumbsDisplaying=1)
             ThumbsNavigator("Right", A_ThisHotkey)
          Else
             NextPicture()
       }
    Return

    WheelDown::
    Left::
    +Left::
       If (InStr(A_ThisHotkey, "wheel") && thumbsDisplaying=1)
       {
          ThumbsNavigator("PgDn", A_ThisHotkey)
          Return
       }
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(-1, "WheelDown")
          Return
       }
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("L")
       } Else
       {
          resetSlideshowTimer(0)
          If (thumbsDisplaying=1)
             ThumbsNavigator("Left", A_ThisHotkey)
          Else
             PreviousPicture()
       }
    Return

    PgDn::
    +PgDn::
       resetSlideshowTimer(0)
       If (totalFramesIndex>0)
          changeDesiredFrame(-1)
       Else If (thumbsDisplaying=1)
          ThumbsNavigator("PgDn", A_ThisHotkey)
       Else
          NextPicture()
    Return

    PgUp::
    +PgUp::
       resetSlideshowTimer(0)
       If (totalFramesIndex>0)
          changeDesiredFrame(1)
       Else If (thumbsDisplaying=1)
          ThumbsNavigator("PgUp", A_ThisHotkey)
       Else
          PreviousPicture()
    Return

    ~Home Up::
    ~+Home::
       If (thumbsDisplaying=1)
          ThumbsNavigator("Home", A_ThisHotkey)
       Else
          FirstPicture()
    Return

    ~End Up::
    ~+End::
       If (thumbsDisplaying=1)
          ThumbsNavigator("End", A_ThisHotkey)
       Else
          LastPicture()
    Return
#If


;____________Functions__________________

OpenSLD(fileNamu, dontStartSlide:=0) {
  If !FileExist(fileNamu)
  {
     showTOOLtip("ERROR: Failed to load file...")
     SoundBeep 
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return
  }

  imageLoading := mustRemQuotes := 1
  If (CurrentSLD && maxFilesIndex>0)
     GdipCleanMain(2)
  ForceRegenStaticFolders := 0
  renewCurrentFilesList()
  newStaticFoldersListCache := DynamicFoldersList := CurrentSLD := ""
  filesFilter := usrFilesFilteru := ""
  SLDhasFiles := 0
  zPlitPath(fileNamu, 0, OutFileName, OutDir)
  showTOOLtip("Loading slideshow, please wait...`n" OutFileName "`n" OutDir "\")
  WinSetTitle, ahk_id %PVhwnd%,, Loading slideshow - please wait...
  FileReadLine, firstLine, % fileNamu, 1
  If InStr(firstLine, "[General]") 
  {
     mustRemQuotes := 0
     IniRead, UseCachedList, % fileNamu, General, UseCachedList, @
     IniRead, testStaticFolderz, % fileNamu, Folders, Fi1, @
     IniRead, testDynaFolderz, % fileNamu, DynamicFolderz, DF1, @
     If StrLen(testDynaFolderz)>4
        DynamicFoldersList := "|hexists|"

     IniRead, tstSLDcacheFilesList, % fileNamu, General, SLDcacheFilesList, @
     If (tstSLDcacheFilesList=1 || tstSLDcacheFilesList=0)
        SLDcacheFilesList := tstSLDcacheFilesList
  }

  mustGenerateStaticFolders := (InStr(firstLine, "[General]") && StrLen(testStaticFolderz)>8) ? 0 : 1
  If (UseCachedList="Yes" && InStr(firstLine, "[General]")) || !InStr(firstLine, "[General]")
     res := sldGenerateFilesList(fileNamu, 0, mustRemQuotes)

  If (res="abandoned")
  {
     resetMainWin2Welcome()
     Return
  }

  If InStr(firstLine, "[General]") 
  {
     If (maxFilesIndex<3 || UseCachedList!="Yes") && (DynamicFoldersList="|hexists|")
        ReloadDynamicFolderz(fileNamu)

     IniRead, IgnoreThesePrefs, % fileNamu, General, IgnoreThesePrefs, @
     If (IgnoreThesePrefs="nope") && (MustLoadSLDprefs=1)
        readSlideSettings(fileNamu)
  }

  GenerateRandyList()
  CurrentSLD := fileNamu
  currentFileIndex := 1
  RecentFilesManager()
  If (dontStartSlide=1)
  {
     SetTimer, RemoveTooltip, % -msgDisplayTime
     SetTimer, ResetImgLoadStatus, -50
     Return
  }

  If (maxFilesIndex>2)
  {
     RandomPicture()
     InfoToggleSlideShowu()
  } Else
  {
     currentFileIndex := 1
     IDshowImage(1)
  }
  SetTimer, ResetImgLoadStatus, -50
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

resetMainWin2Welcome() {
     ForceRegenStaticFolders := SLDhasFiles := 0
     renewCurrentFilesList()
     newStaticFoldersListCache := DynamicFoldersList := CurrentSLD := ""
     filesFilter := usrFilesFilteru := ""
     WinSetTitle, ahk_id %PVhwnd%,, %appTitle%.
     SetTimer, ResetImgLoadStatus, -50
     GdipCleanMain()
     cleanThumbsWindow()
     drawWelcomeImg()
}

escRoutine() {
   If (slideShowRunning=1)
   {
      dummyInfoToggleSlideShowu()
      If (slideShowDelay<510)
         Global lastLongOperationAbort := A_TickCount
      Return
   }

   If (A_TickCount - lastLongOperationAbort < 1500)
      Return

   If (AnyWindowOpen>0)
   {
      CloseWindow()
      showTOOLtip("Other window closed...")
      Sleep, 350
      SetTimer, RemoveTooltip, % -msgDisplayTime
   } Else If (GIFsGuiCreated=1)
   {
      DestroyGIFuWin()
      Global lastGIFdestroy := A_TickCount
      prevAnimGIFwas := resultedFilesList[currentFileIndex]
      dummyTimerReloadThisPicture(2)
   } Else If (thumbsDisplaying=1)
   {
      ToggleThumbsMode()
   } Else
   {
      If (A_TickCount - lastOtherWinClose > 500)
         Gosub, Cleanup
   }
}

GenerateRandyList() {
   RandyIMGids := []
   Loop, % maxFilesIndex
       indexListu .= A_Index "+"
   Sort, indexListu, Random D+
   Loop, Parse, indexListu, +
       RandyIMGids[A_Index] := A_LoopField
   RandyIMGnow := 1
}

OpenThisFileFolder() {
    If (currentFileIndex=0)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    resultu := resultedFilesList[currentFileIndex]
    If resultu
    {
       zPlitPath(resultu, 0, fileNamu, folderu)
       Try Run, %folderu%
    }
}

OpenThisFile() {
  Static lastInvoked := 1

  imgPath := resultedFilesList[currentFileIndex]
  zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, Ext)
  labelu := "QPVimage." Ext

  RegRead, regEntryA, HKEY_CLASSES_ROOT\.%Ext%
  If (regEntryA=labelu)
     testA := 1

  RegRead, regEntryB, HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.%Ext%\UserChoice, ProgId
  If (regEntryB=labelu)
     testB := 1

  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (GIFsGuiCreated=1)
     DestroyGIFuWin()

  isAssociated := (testA=1 && testB=1) ? 1 : 0
  newInstanceOption := (A_IsCompiled) ? 1 : 0
  InvokeOpenWithMenu(imgPath, newInstanceOption)
}

OpenNewQPVinstance() {
   imgPath := resultedFilesList[currentFileIndex]
   Run, "%fullPath2exe%" "%imgPath%"
}

OpenWithDefaultApp() {
  IDshowImage(currentFileIndex, 1)
}

InvokeOpenWithMenu(imgPath, newInstanceOption) {
    CreateOpenWithMenu(imgPath)
    Menu, OpenWithMenu, Add,
    If (newInstanceOption=1)
       Menu, OpenWithMenu, Add, &0. Open file in a new instance, OpenNewQPVinstance
    Menu, OpenWithMenu, Add, &1. Open with default application, OpenWithDefaultApp
    Menu, OpenWithMenu, Add, &2. «Open with» dialog, invokeSHopenWith
    Menu, OpenWithMenu, Add,
    Menu, OpenWithMenu, Add, &Cancel, dummy
    showThisMenu("OpenWithMenu")
}

resetSlideshowTimer(showMsg, ignoreEasyStop:=0) {
   If (slideShowRunning!=1 && showMsg!=1)
      Return

   If (easySlideStoppage=1 && slideShowRunning=1 && ignoreEasyStop=0)
   {
      ToggleSlideShowu()
   } Else If (slideShowRunning=1)
   {
      ToggleSlideShowu()
      Sleep, 0
      ToggleSlideShowu()
   }

   If (showMsg=1)
   {
      friendly := (slideShowRunning=1) ? "RUNNING" : "STOPPED"
      delayu := DefineSlidesRate()
      etaTime := "Estimated time: " EstimateSlideShowLength()
      showTOOLtip("Slideshow speed: " delayu "`nTotal files: "  maxFilesIndex "`n" etaTime "`nSlideshow: " friendly)
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

IncreaseSlideSpeed() {
   If (slideShowDelay<1000)
   {
      slideShowDelay += 300
      SetTimer, dummyChangeSlideSpeed, -50
      Return
   }
   
   slideShowDelay += 1000
   If (slideShowDelay>20000)
      slideShowDelay := 20000

   SetTimer, dummyChangeSlideSpeed, -50
}

DecreaseSlideSpeed() {
   If (slideShowDelay<1001)
   {
      slideShowDelay -= 300
      If (slideShowDelay<200)
         slideShowDelay := 100

      SetTimer, dummyChangeSlideSpeed, -50
      Return
   }

   slideShowDelay -= 1000
   SetTimer, dummyChangeSlideSpeed, -50
}

dummyChangeSlideSpeed() {
   resetSlideshowTimer(1, 1)
   writeMainSettings()
}

CopyImagePath() {
  If (currentFileIndex=0)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  filesElected := getSelectedFiles()
  If (filesElected>0)
  {
     Loop, % filesElected
     {
        thisFileIndex := getSelectedFiles(A_Index)
        file2rem := resultedFilesList[thisFileIndex]
        file2rem := StrReplace(file2rem, "||")
        listu .= file2rem "`n"
     }
     Try Clipboard := listu
     showTOOLtip("The file paths of " filesElected " files were copied to clipboard...")
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return
  }

  imgPath := resultedFilesList[currentFileIndex]
  imgPath := StrReplace(imgPath, "||")
  Try Clipboard := imgPath
  showTOOLtip("File path copied to clipboard...`n" imgpath)
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

CopyImage2clip() {
  If (currentFileIndex=0 || thumbsDisplaying=1)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  imgPath := resultedFilesList[currentFileIndex]
  If gdiBitmap
  {
     Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
     dummyBMP := Gdip_CloneBitmap(gdiBitmap)
     r := coreResizeIMG(imgPath, imgW, imgH, "--", 1, 1, 0, dummyBMP, imgW, imgH, 0)
  } Else r := "Err"

  If r
  {
     showTOOLtip("Failed to copy the image to clipboard... Error code: " r)
     SoundBeep, 300, 900
  } Else
  {
     showTOOLtip("Image copied to clipboard...")
     SoundBeep, 900, 100
  }
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

invertRecursiveness() {
   If (RegExMatch(CurrentSLD, "i)(.\.sld)$") || !CurrentSLD)
      Return

   isPipe := InStr(CurrentSLD, "|") ? 1 : 0
   CurrentSLD := StrReplace(CurrentSLD, "|")
   DynamicFoldersList := StrReplace(DynamicFoldersList, "|")
   If (isPipe!=1)
   {
      CurrentSLD := "|" CurrentSLD
      DynamicFoldersList := "|" DynamicFoldersList
   }

   RefreshFilesList()
}

invertFilesFilter() {
   If (StrLen(filesFilter)<2 || !filesFilter)
      Return

   isThat := InStr(usrFilesFilteru, "&") ? 1 : 0
   usrFilesFilteru := StrReplace(usrFilesFilteru, "&")
   If (isThat!=1)
      usrFilesFilteru := "&" usrFilesFilteru

   coreEnableFiltru(usrFilesFilteru)
}

dummyTimerReloadThisPicture(timeru:=0) {
  SetTimer, dummyTimerDelayiedImageDisplay, Off
  If (timeru>1)
     SetTimer, extraDummyReloadThisPicture, % -timeru, 950
}

extraDummyReloadThisPicture() {
  If (imageLoading=1)
  {
     SetTimer, extraDummyReloadThisPicture, -15
     Return
  }
  ReloadThisPicture()
}

ReloadThisPicture() {
  SetTimer, dummyTimerDelayiedImageDisplay, Off
  clippyTest := resultedFilesList[0]
  If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
  {
     ShowTheImage(clippyTest, 2)
     Return
  }

  If (CurrentSLD && maxFilesIndex>0)
  {
     If (GetKeyState("LButton", "P") || GetKeyState("Space", "P") || LbtnDwn=1)
     {
        MouseGetPos,,, OutputVarWin
        If (OutputVarWin!=PVhwnd)
           LbtnDwn := 0

        delayu := (A_TickCount - prevFastDisplay < 500) ? 90 : 550
        dummyTimerReloadThisPicture(delayu)
        Return
     }
     r := IDshowImage(currentFileIndex, 2)
     If !r
        informUserFileMissing()
  }
}

coreReloadThisPicture() {
  clippyTest := resultedFilesList[0]
  If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
  {
     ShowTheImage(clippyTest, 2)
     Return
  }

  If (CurrentSLD && maxFilesIndex>0)
  {
     r := IDshowImage(currentFileIndex, 2)
     If !r
        informUserFileMissing()
  }
}

FirstPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()

   currentFileIndex := 1
   r := IDshowImage(1)
   showTOOLtip("Total images loaded: 1 / " maxFilesIndex)
   If !r
      informUserFileMissing()
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

LastPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()
   currentFileIndex := maxFilesIndex
   r := IDshowImage(maxFilesIndex)
   showTOOLtip("Total images loaded: " maxFilesIndex)
   If !r
      informUserFileMissing()
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

SettingsGUIAGuiClose:
SettingsGUIAGuiEscape:
   CloseWindow()
Return

TrueCleanup() {
   Critical, on
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 900)
      Return

   WinSet, Region, 0-0 w1 h1, ahk_id %PVhwnd%
   RegWrite, REG_SZ, %QPVregEntry%, Running, 0
   If hitTestSelectionPath
   {
      editingSelectionNow := activateImgSelection := 0
      Gdip_DeletePath(hitTestSelectionPath)
      hitTestSelectionPath := ""
   }

   Gui, 2: Destroy
   Gui, 3: Destroy
   lastInvoked := A_TickCount
   RemoveTooltip()
   DestroyGIFuWin()
   Sleep, 2
   If (wasInitFIMlib=1)
      FreeImage_FoxInit(0) ; Unload Dll

   disposeCacheIMGs()
   If HistogramBMP
      HistogramBMP := Gdip_DisposeImage(HistogramBMP, 1)
   If AprevGdiBitmap
      AprevGdiBitmap := Gdip_DisposeImage(AprevGdiBitmap, 1)
   If BprevGdiBitmap
      BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
   If yetAnotherVPcache
      yetAnotherVPcache := Gdip_DisposeImage(yetAnotherVPcache, 1)
   If pBrushWinBGR
      Gdip_DeleteBrush(pBrushWinBGR)
   If pBrushHatch
      Gdip_DeleteBrush(pBrushHatch)
   If pBrushHatchLow
      Gdip_DeleteBrush(pBrushHatchLow)
   If pBrushA
      Gdip_DeleteBrush(pBrushA)
   If pBrushB
      Gdip_DeleteBrush(pBrushB)
   If pBrushC
      Gdip_DeleteBrush(pBrushC)
   If pBrushD
      Gdip_DeleteBrush(pBrushD)
   If pBrushE
      Gdip_DeleteBrush(pBrushE)
   If AmbientalTexBrush
      Gdip_DeleteBrush(AmbientalTexBrush)
   If pPen1
      Gdip_DeletePen(pPen1)
   If pPen1d
      Gdip_DeletePen(pPen1d)
   If pPen2
      Gdip_DeletePen(pPen2)
   If pPen3
      Gdip_DeletePen(pPen3)
   If pPen4
      Gdip_DeletePen(pPen4)

   mainGdipWinThumbsGrid(1)
   destroyGDIPcanvas()
   Sleep, 1
   writeMainSettings()
   lastInvoked := A_TickCount
   Gdip_Shutdown(GDIPToken)  
}

1GuiClose:
GuiClose:
Cleanup:
   If AnyWindowOpen
   {
      CloseWindow()
      Sleep, 25
   }
   TrueCleanup()
   ExitApp
Return

disposeCacheIMGs() {
   If ViewPortBMPcache
      ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
   If anotherVPcache
      anotherVPcache := Gdip_DisposeImage(anotherVPcache, 1)
   If gdiBitmapSmall
      gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)
   If gdiBitmap
      gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
   If yetAnotherVPcache
      yetAnotherVPcache := Gdip_DisposeImage(yetAnotherVPcache, 1)
}

activateMainWin() {
   Static lastInvoked := 1
   LbtnDwn := 0
   If (A_TickCount - lastInvoked < 30)
      Return

   If (easySlideStoppage=1 && slideShowRunning=1)
      ToggleSlideShowu()

   If (A_TickCount - lastInvoked > 530)
      GuiControl, 1:, editDummy, -

   If (toolTipGuiCreated=1)
      TooltipCreator(1, 1)
   lastInvoked := A_TickCount
}

MenuDummyToggleThumbsMode() {
   lastOtherWinClose := 5
   ToggleThumbsMode()
}

ToggleThumbsMode() {
   Static lastInvoked := 1

   If (A_TickCount - lastInvoked<150) || (A_TickCount - lastOtherWinClose<150)
   {
      lastInvoked := A_TickCount
      Return
   }

   lastInvoked := A_TickCount
   If (maxFilesIndex>1)
   {
      GdipCleanMain(0)
      editingSelectionNow := 0
   }

   If (thumbsDisplaying=1)
   {
      thumbsDisplaying := 0
      setTexHatchScale(zoomLevel)
      WinMove, ahk_id %hGDIthumbsWin%,, 1, 1, 1, 1
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
      If hSNDmediaFile
         MCI_Resume(hSNDmedia)
      lastInvoked := A_TickCount
      Return
   } Else If (CurrentSLD && maxFilesIndex>1)
   {
      If hSNDmediaFile
         MCI_Pause(hSNDmedia)
      setTexHatchScale(thumbsZoomLevel/2)
      UpdateThumbsScreen()
   }

   lastInvoked := A_TickCount
}

defineThumbsAratio() {
  friendly := (thumbsAratio=1) ? "Wide (1.81)" : "Tall (0.48)"
  If (thumbsAratio=3)
     friendly := "Square (1.00)"

  Return friendly
}

coreChangeThumbsAratio() {
  If (thumbsAratio=1)
  {
     othumbsW := 300
     othumbsH := 165
  } Else If (thumbsAratio=2)
  {
     othumbsW := 144
     othumbsH := 300
  } Else If (thumbsAratio=3)
  {
     othumbsW := 300
     othumbsH := 300
  }
  If (thumbsZoomLevel<0.35)
    thumbsZoomLevel := 0.35

  thumbsH := Round(othumbsH*thumbsZoomLevel)
  thumbsW := Round(othumbsW*thumbsZoomLevel)
}

ChangeThumbsAratio() {
  thumbsAratio++
  If (thumbsAratio>3)
     thumbsAratio := 1

  coreChangeThumbsAratio()
  showTOOLtip("Thumbnails aspect ratio: " defineThumbsAratio() "`nSize: " thumbsW " x " thumbsH " (pixels)")
  SetTimer, RemoveTooltip, % -msgDisplayTime
  RefreshThumbsList()
  writeMainSettings()
}

thumbsInfoYielder(ByRef maxItemsW, ByRef maxItemsH, ByRef maxItemsPage, ByRef maxPages, ByRef startIndex, ByRef mainWidth, ByRef mainHeight) {
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   maxItemsW := Round((mainWidth+15)//thumbsW)
   maxItemsH := Round((mainHeight+15)//thumbsH)
   If (maxItemsW<2)
      maxItemsW := 1
   If (maxItemsH<2)
      maxItemsH := 1

   maxItemsPage := maxItemsW*maxItemsH
   maxPages := Ceil(maxFilesIndex/maxItemsPage)
   startIndex := Floor(currentFileIndex/maxItemsPage) * maxItemsPage
   If (startIndex<2)
      startIndex := 1
}

UpdateThumbsScreen(forceThis:=0) {
   Critical, on
   Static lastInvoked := 1
   SetTimer, dummyTimerDelayiedImageDisplay, Off
   SetTimer, dummyTimerReloadThisPicture, Off
   thumbsDisplaying := 1
   thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
   createGDIPcanvas(mainWidth, mainHeight)
   Gdip_ResetWorldTransform(glPG)
   IMGlargerViewPort := 0
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (GIFsGuiCreated=1)
      DestroyGIFuWin()

   mustShowNames := 0
   If (prevStartIndex!=startIndex) || (forceThis=2)
   {
      If (A_TickCount - lastInvoked < 90)
      || ((A_TickCount - prevFullThumbsUpdate < 300) || (A_TickCount - lastInvoked < 150)) && (forceThis!=2)
      {
         SetTimer, RefreshThumbsList, -600
         mustShowNames := 1
         lastInvoked := A_TickCount
      } Else
      {
         If (A_TickCount - prevTooltipDisplayTime > 1000)
         {
            showTOOLtip("Generating thumbnails, please wait...")
            SetTimer, RemoveTooltip, -600
         }
         GdipCleanMain(0)
         r := QPV_ShowThumbnails(startIndex)
      }
   } Else r := 1
   prevStartIndex := startIndex
   mainGdipWinThumbsGrid(0, mustShowNames)
   If !r
      prevStartIndex := -1

   JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
   If (A_OSVersion="WIN_7")
      WinMove, ahk_id %hGDIthumbsWin%,, %GuiX%, %GuiY%, %mainWidth%, %mainHeight%
   Else
      WinMove, ahk_id %hGDIthumbsWin%,, 1, 1, %mainWidth%, %mainHeight%
   WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight% , ahk_id %hGDIthumbsWin%
   lastInvoked := A_TickCount
}

panIMGonScrollBar() {
   If (IMGresizingMode!=4)
   {
      IMGdecalageX := IMGdecalageY := 1
      Return
   }

   If (slideShowRunning=1)
      ToggleSlideShowu()
   GetMouseCoord2wind(PVhwnd, oX, oY)
   oDx := IMGdecalageX
   oDy := IMGdecalageY

   GetClientSize(mainWidth, mainHeight, PVhwnd)
   Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
   While, (GetKeyState("LButton", "P") || LbtnDwn=1)
   {
      GetMouseCoord2wind(PVhwnd, mX, mY)
      prcW := mX/mainWidth
      prcH := mY/mainHeight
      prcW := (prcW>0.5) ? prcW - 0.5 : 0.5 - prcW
      prcH := (prcH>0.5) ? prcH - 0.5 : 0.5 - prcH
      decX := Round(((imgW)*prcW) * zoomLevel)
      decY := Round(((imgH)*prcH) * zoomLevel)
      prcW := mX/mainWidth
      prcH := mY/mainHeight
      If (prcW>0.5)
         decX := -decX
      If (prcH>0.5)
         decY := -decY
      If (scrollAxis=1)
      {
         newDecX := (FlipImgH=1) ? -decX : decX
         IMGdecalageX := (A_Index=1) ? (newDecX + oDx)//2 : newDecX
         diffIMGdecX := mX - oX + 2
      } Else
      {
         newDecY := (FlipImgV=1) ? -decY : decY
         IMGdecalageY := (A_Index=1) ? (newDecY + oDy)//2 : newDecY
         diffIMGdecY := mY - oY + 2
      }

      If (LastPrevFastDisplay=1 || PannedFastDisplay=1)
         coreReloadThisPicture()
      Else
         filterDelayiedImageDisplay()
      If (A_Index<3)
        Sleep, 50

      MouseGetPos,,, OutputVarWin
      If (OutputVarWin!=PVhwnd) && (LbtnDwn=1)
         Break
   }
   diffIMGdecX := diffIMGdecY := 0
   SetTimer, ResetLbtn, -25
}

ThumbsScrollbar() {
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   prevFileIndex := currentFileIndex
   While, (GetKeyState("LButton", "P") || LbtnDwn=1)
   {
      GetMouseCoord2wind(PVhwnd, mX, mY)
      newIndex := ((mY-15)/mainHeight)*100
      newIndex := Ceil((maxFilesIndex/100)*newIndex)
      If (newIndex<1)
         newIndex := 1
      Else If (newIndex>maxFilesIndex)
         newIndex := maxFilesIndex-1

      currentFileIndex := newIndex
      filterDelayiedImageDisplay()
      mainGdipWinThumbsGrid(0, 1)
      MouseGetPos,,, OutputVarWin
      If (OutputVarWin!=PVhwnd) && (LbtnDwn=1)
         Break
   }

   If (GetKeyState("Shift", "P"))
   {
      keyu := (currentFileIndex>prevFileIndex) ? "Down" : "Home"
      thumbsSelector(keyu, "+Shift", prevFileIndex)
   }

   dummyTimerDelayiedImageDisplay(250)
   SetTimer, ResetLbtn, -25
}

panIMGonClick() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   GetPhysicalCursorPos(oX, oY)
   oDx := IMGdecalageX
   oDy := IMGdecalageY

   While, (GetKeyState("LButton", "P") || LbtnDwn=1)
   {
      GetPhysicalCursorPos(mX, mY)
      diffIMGdecX := Dx := mX - oX + 2
      diffIMGdecY := Dy := mY - oY + 2
      IMGdecalageX := (FlipImgH=1) ? oDx - Dx : oDx + Dx
      IMGdecalageY := (FlipImgV=1) ? oDy - Dy : oDy + Dy
      If (LastPrevFastDisplay=1 || PannedFastDisplay=1)
         coreReloadThisPicture()
      Else
         filterDelayiedImageDisplay()
      MouseGetPos,,, OutputVarWin
      If (OutputVarWin!=PVhwnd) && (LbtnDwn=1)
         Break
   }
   diffIMGdecX := diffIMGdecY := 0
   SetTimer, ResetLbtn, -25
}

GetMouseCoord2wind(hwnd, ByRef nx, ByRef ny) {
    ; CoordMode, Mouse, Screen
    MouseGetPos, ox, oy
    JEE_ScreenToClient(hwnd, ox, oy, nx, ny)
}

WinClickAction(forceThis:=0) {
   Critical, on
   Static thisZeit := 1, prevTippu := 1, anotherZeit := 1
        , lastInvoked := 1, lastInvoked2 := 1

   If (A_TickCount - lastLongOperationAbort < 550) || (A_TickCount - executingCanceableOperation < 550)
      Return

   If (AnyWindowOpen=1)
   {
      CloseWindow()
      Return
   }

   If AnyWindowOpen
   {
      ; handle clicks in the viewport when another GUI is open
      ; notable exception is the ColorsAdjusterPanelWindow() [AnyWindowOpen=10]
      If (AnyWindowOpen=10 && imgFxMode!=1)
      {
         GetMouseCoord2wind(PVhwnd, mX, mY)
         GetClientSize(mainWidth, mainHeight, PVhwnd)
         If (mY<mainHeight//6)
            ChangeZoom(1)
         Else If (mY>mainHeight - mainHeight//6)
            ChangeZoom(-1)
         Else
         {
            If (A_TickCount - lastInvoked < 350) || (IMGlargerViewPort!=1)
            {
               ForceNoColorMatrix := !ForceNoColorMatrix
               dummyTimerDelayiedImageDisplay(50)
            } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
               SetTimer, panIMGonClick, -50
            lastInvoked := A_TickCount
         }
      } Else SoundPlay, *-1
      WinActivate, ahk_id %hSetWinGui%
      Return
   }

   If (imageLoading=1 && thumbsDisplaying=1) || (A_TickCount - lastGIFdestroy<400)
      Return

   MouseGetPos, , , OutputVarWin
   If (toolTipGuiCreated=1)
      TooltipCreator(1, 1)

   If (forceThis!=2)
   {
      If (OutputVarWin!=PVhwnd) || (A_TickCount - lastWinDrag>450) && (isTitleBarHidden=1 && thumbsDisplaying=0)
         Return
   }

   spaceState := GetKeyState("Space", "P") ? 1 : 0
   GetMouseCoord2wind(PVhwnd, mX, mY)
   If (thumbsDisplaying=1 && maxFilesIndex>0)
   {
      ; handle clicks on thumbnails and the vertical scrollbar
      thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
      scrollXpos := mainWidth - imgHUDbaseUnit//2
      If (mX>scrollXpos)
      {
         SetTimer, ThumbsScrollbar, -25
         Return
      }

      rowIndex := 0, columnIndex := -1
      Loop, % maxItemsPage*2
      {
         columnIndex++
         If (columnIndex>=maxItemsW)
         {
            rowIndex++
            columnIndex := 0
         }
         DestPosX := thumbsW*columnIndex + thumbsW
         DestPosY := thumbsH*rowIndex + thumbsH
         If (DestPosX>mX && DestPosY>mY)
         {
            newIndex := startIndex + A_Index - 1
            Break
         }
      }

      maxWidu := maxItemsW*thumbsW - 1
      maxHeitu := maxItemsH*thumbsH  - 1
      If (maxWidu<mX || maxHeitu<mY)
         Return

      If (newIndex=currentFileIndex) && (A_TickCount - lastInvoked>350) && (forceThis!="rClick")
      {
         ToggleThumbsMode()
         Return
      }

      If newIndex
      {
         If (newIndex>maxFilesIndex)
            Return

         If (GetKeyState("Ctrl", "P"))
         {
            markThisFileNow(newIndex)
         } Else If (GetKeyState("Shift", "P"))
         {
            keyu := (newIndex>currentFileIndex) ? "Down" : "Upu"
            prevFileIndex := currentFileIndex
            currentFileIndex := newIndex
            thumbsSelector(keyu, "+Shift", prevFileIndex)
         } Else currentFileIndex := newIndex

         If (forceThis="rClick")
            DelayiedImageDisplay()
         Else
            dummyTimerDelayiedImageDisplay(25)
      }
      lastInvoked := A_TickCount
      Return
   }

   GetClientSize(mainWidth, mainHeight, PVhwnd)
   If (maxFilesIndex>0 && CurrentSLD && IMGlargerViewPort=1 && IMGresizingMode=4 && (scrollBarHy>1 || scrollBarVx>1) && thumbsDisplaying!=1)
   {
      ; handle H/V scrollbars for images larger than the viewport
      If (scrollBarHy>1) && ((mY>scrollBarHy && FlipImgV=0)
      || (mY<(mainHeight - scrollBarHy) && FlipImgV=1))
      {
         scrollAxis := 1
         SetTimer, panIMGonScrollBar, -25
         Return
      } Else If (scrollBarVx>1) && ((mX>scrollBarVx && FlipImgH=0)
      || (mX<(mainWidth - scrollBarVx) && FlipImgH=1))
      {
         scrollAxis := 0
         SetTimer, panIMGonScrollBar, -25
         Return
      }
   }

   If ((activateImgSelection!=1) || (imgSelOutViewPort=1 && activateImgSelection=1) || (imgSelLargerViewPort=1 && activateImgSelection=1))
   && (CurrentSLD && GetKeyState("LButton", "P") && GetKeyState("Shift", "P"))
   {
      imgSelX2 := imgSelY2 := (IMGlargerViewPort=1) ? "C" : -1
      activateImgSelection := editingSelectionNow :=1
      dummyTimerDelayiedImageDisplay(50)
      Return
   }


   If (editingSelectionNow=1 && activateImgSelection=1 && spaceState!=1 && thumbsDisplaying!=1)
   {
      ; handle clicks on the image selection rectangle in the viewport
      mXoT := mX, mYoT := mY
      JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
      MouseGetPos, mXo, mYo
      nSelDotX  := selDotX,  nSelDotAx := selDotAx
      nSelDotBx := selDotBx, nSelDotCx := selDotCx
      nSelDotY  := selDotY,  nSelDotAy := selDotAy
      nSelDotBy := selDotBy, nSelDotCy := selDotCy

      If (FlipImgH=1)
      {
         nSelDotX := mainWidth - selDotX - dotsSize
         nSelDotAx := mainWidth - selDotAx - dotsSize
         nSelDotBx := mainWidth - selDotBx - dotsSize
         nSelDotCx := mainWidth - selDotCx - dotsSize
      }

      If (FlipImgV=1)
      {
         nSelDotY := mainHeight - selDotY - dotsSize
         nSelDotAy := mainHeight - selDotAy - dotsSize
         nSelDotBy := mainHeight - selDotBy - dotsSize
         nSelDotCy := mainHeight - selDotCy - dotsSize
      }

      zL := (zoomLevel>1) ? zoomLevel : 1/zoomLevel
      If (valueBetween(mXoT, nselDotX, nselDotX + dotsSize) && valueBetween(mYoT, nselDotY, nselDotY + dotsSize))
      {
         dotActive := 1
         DotPosX := imgSelX1
         DotPosY := imgSelY1
      } Else If (valueBetween(mXoT, nselDotAx, nselDotAx + dotsSize) && valueBetween(mYoT, nselDotAy, nselDotAy + dotsSize))
      {
         dotActive := 2
         DotPosX := imgSelX2
         DotPosY := imgSelY2
      } Else If (valueBetween(mXoT, nselDotBx, nselDotBx + dotsSize) && valueBetween(mYoT, nselDotBy, nselDotBy + dotsSize))
      {
         dotActive := 3
         DotPosX := imgSelX2
         DotPosY := imgSelY1
      } Else If (valueBetween(mXoT, nselDotCx, nselDotCx + dotsSize) && valueBetween(mYoT, nselDotCy, nselDotCy + dotsSize))
      {
         dotActive := 4
         DotPosX := imgSelX1
         DotPosY := imgSelY2
      } Else If (valueBetween(mXoT, nselDotX, nselDotBx) && valueBetween(mYoT, nselDotY, nselDotY + dotsSize))
      {
         dotActive := 5
         DotPosX := imgSelX1
         DotPosY := imgSelY1
      } Else If (valueBetween(mXoT, nselDotCx, nselDotBx) && valueBetween(mYoT, nselDotCy, nselDotCy + dotsSize))
      {
         dotActive := 6
         DotPosX := imgSelX1
         DotPosY := imgSelY2
      } Else If (valueBetween(mXoT, nselDotX, nselDotX + dotsSize) && valueBetween(mYoT, nselDotY, nselDotCy))
      {
         dotActive := 7
         DotPosX := imgSelX1
         DotPosY := imgSelY1
      } Else If (valueBetween(mXoT, nselDotBx, nselDotBx + dotsSize) && valueBetween(mYoT, nselDotBy, nselDotAy))
      {
         dotActive := 8
         DotPosX := imgSelX2
         DotPosY := imgSelY1
      } Else If (valueBetween(mXoT, nselDotX, nselDotBx) && valueBetween(mYoT, nselDotBy, nselDotAy))
      {
         dotActive := 9
         DotPosX := imgSelX1
         DotPosY := imgSelY1
      }
      If (dotActive && imgSelOutViewPort=1)
      {
         dotActive := 9
         DotPosX := imgSelX1
         DotPosY := imgSelY1
      }
      nImgSelX1 := imgSelX1
      nImgSelY1 := imgSelY1
      nImgSelX2 := imgSelX2
      nImgSelY2 := imgSelY2
      adjustNowSel := 1
      o_imageLoading := imageLoading
      cleanThumbsWindow()
      coreReloadThisPicture()
      ; r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
      drawImgSelectionOnWindow(1)
      ; thisZeit := A_TickCount
      ctrlState := (GetKeyState("Ctrl", "P") && dotActive=9) ? 1 : 0
      While, ((GetKeyState("LButton", "P") || LbtnDwn=1) && o_imageLoading!=1 && dotActive && ctrlState=0)
      {
          MouseGetPos, mX, mY, thisWind
          changePosX := (zoomLevel>1) ? Round((mX - mXo)/zL) : Round((mX - mXo)*zL)
          changePosY := (zoomLevel>1) ? Round((mY - mYo)/zL) : Round((mY - mYo)*zL)
          newSelDotX := (FlipImgH=1) ? DotPosX - changePosX : DotPosX + changePosX
          newSelDotY := (FlipImgV=1) ? DotPosY - changePosY : DotPosY + changePosY
          If (dotActive=1)
          {
             coords := 1
             nImgSelX1 := newSelDotX
             nImgSelY1 := newSelDotY
          } Else If (dotActive=2)
          {
             coords := 1
             nImgSelX2 := newSelDotX
             nImgSelY2 := newSelDotY
          } Else If (dotActive=3)
          {
             coords := 1
             nImgSelX2 := newSelDotX
             nImgSelY1 := newSelDotY
          } Else If (dotActive=4)
          {
             coords := 1
             nImgSelX1 := newSelDotX
             nImgSelY2 := newSelDotY
          } Else If (dotActive=5)
          {
             coords := 3
             nImgSelX1 := newSelDotX
             nImgSelY1 := newSelDotY
          } Else If (dotActive=6)
          {
             coords := 3
             nImgSelX1 := newSelDotX
             nImgSelY2 := newSelDotY
          } Else If (dotActive=7)
          {
             coords := 2
             nImgSelX1 := newSelDotX
             nImgSelY1 := newSelDotY
          } Else If (dotActive=8)
          {
             coords := 2
             nImgSelX2 := newSelDotX
             nImgSelY1 := newSelDotY
          } Else If (dotActive=9)
          {
             coords := 10
             imgSelX1 := (FlipImgH=1) ? nImgSelX1 - changePosX : nImgSelX1 + changePosX
             imgSelY1 := (FlipImgV=1) ? nImgSelY1 - changePosY : nImgSelY1 + changePosY
             imgSelX2 := (FlipImgH=1) ? nImgSelX2 - changePosX : nImgSelX2 + changePosX
             imgSelY2 := (FlipImgV=1) ? nImgSelY2 - changePosY : nImgSelY2 + changePosY
          }

          If (nImgSelX1>nImgSelX2 || nImgSelY1>nImgSelY2) && (coords!=10)
          {
             If (coords=1 || coords=2)
                imgSelX1 := nImgSelX2
             If (coords=1 || coords=3)
                imgSelY1 := nImgSelY2
             If (coords=1 || coords=2)
                imgSelX2 := nImgSelX1
             If (coords=1 || coords=3)
                imgSelY2 := nImgSelY1
          } Else If (coords!=10)
          {
             If (coords=1 || coords=2)
                imgSelX1 := nImgSelX1
             If (coords=1 || coords=3)
                imgSelY1 := nImgSelY1
             If (coords=1 || coords=2)
                imgSelX2 := nImgSelX2
             If (coords=1 || coords=3)
                imgSelY2 := nImgSelY2
          }

          imgSelW := maxU(ImgSelX1, ImgSelX2) - minU(ImgSelX1, ImgSelX2)
          imgSelH := maxU(ImgSelY1, ImgSelY2) - minU(ImgSelY1, ImgSelY2)
          If (A_TickCount - prevTippu>60) && (LbtnDwn!=1)
          {
             If valueBetween(dotActive, 1, 4)
             {
                ARGBdec := Gdip_GetPixel(gdiBitmap, newSelDotX, newSelDotY)
                Gdip_FromARGB(ARGBdec, cA, cR, cG, cB)
                pixelColor := cR ", " cG ", " cB ", " cA
                addMsg := "`n `nPixel coordinates:`nX / Y: " newSelDotX ", " newSelDotY "`nColor: " pixelColor 
             }
             theMsg := "Selection coordinates:`nX / Y: " ImgSelX1 ", " ImgSelY1 "`nW / H: " imgSelW ", " imgSelH addMsg
             ; ToolTip, % theMsg, % mainX + 10, % mainY + 10
             prevTippu := A_TickCount
          } Else theMsg := ""

          If (A_TickCount - thisZeit<150) ; || (A_TickCount - thisZeit<190)
             drawImgSelectionOnWindow(2, theMsg, ARGBdec, dotActive)

          If !(valueBetween(Abs(changePosY), 0, 1)) || !(valueBetween(Abs(changePosX), 0, 1))
              thisZeit := A_TickCount
          If (thisWind!=PVhwnd && LbtnDwn=1)
             Break
      }
      drawImgSelectionOnWindow(3)
      adjustNowSel := 0
      coreReloadThisPicture()
      cleanThumbsWindow()
      SetTimer, ResetLbtn, -50
      ToolTip
      If (LbtnDwn!=1 && dotActive=9 && valueBetween(Abs(changePosY), 0, 2) && valueBetween(Abs(changePosX), 0, 2))
      {
         If (A_TickCount - anotherZeit<300) 
            thisZeit := dotActive := ctrlState := 0
         anotherZeit := A_TickCount
      }
      If (dotActive || (A_TickCount - thisZeit<150)) && (ctrlState=0)
         Return
   }

   If (A_TickCount - lastInvoked<250) && (lastInvoked>1 && CurrentSLD && maxFilesIndex>0 && spaceState!=1)
   {
      ; handle double clicks in the viewport when an image is being displayied
      If (activateImgSelection=1)
      {
         If (valueBetween(mX, selDotX, selDotBx) && valueBetween(mY, selDotBy, selDotAy) && imgSelLargerViewPort=0)
            ToggleEditImgSelection()
         Else
            toggleImgSelection()
         Return
      }

      If (TouchScreenMode=0)
      {
         If (slideShowRunning=1)
            InfoToggleSlideShowu()
         Else If (IMGlargerViewPort=1)
            ToggleViewModeTouch()
         Else
            OpenFiles()
         lastInvoked := A_TickCount
         Return
      }
      If (slideShowRunning=1)
         ToggleSlideShowu()
      Sleep, 25
      ToggleViewModeTouch()
   } Else If (maxFilesIndex>1 && CurrentSLD) && (A_TickCount - thisZeit>950)
   {
      ; handle single clicks in the viewport when multiple files are loaded
      If (TouchScreenMode=0 || spaceState=1)
      {
         If (IMGlargerViewPort=1 && thumbsDisplaying!=1)
            SetTimer, panIMGonClick, -25
         lastInvoked := A_TickCount
         Return
      }
      Sleep, 5
      prevMPosCtrl := A_GuiControl
      If (A_GuiControl="PicOnGUI3")
         winGoNextSlide()
      Else If (A_GuiControl="PicOnGUI1")
         winGoPrevSlide()
      Else If (A_GuiControl="PicOnGUI2a" || A_GuiControl="PicOnGUI2b" || A_GuiControl="PicOnGUI2c")
      {
         regSize := (editingSelectionNow=1 && activateImgSelection=1) ? 7 : 5
         If (mY<mainHeight//regSize)
         {
            ChangeZoom(1)
            Return
         } Else If (mY>mainHeight - mainHeight//regSize)
         {
            ChangeZoom(-1)
            Return
         } Else If (IMGlargerViewPort=1 && thumbsDisplaying!=1)
            SetTimer, panIMGonClick, -25
         Else
            winGoSlide()
      }
   } Else If (!CurrentSLD || maxFilesIndex<1) && (A_TickCount - thisZeit>950)
   {
      ; when no image is loaded, on click, open files dialog
      clippyTest := resultedFilesList[0]
      If (!CurrentSLD && currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
         Return

      SetTimer, drawWelcomeImg, Off
      Sleep, 5
      OpenFiles()
   }
   lastInvoked := A_TickCount
}

winGoNextSlide() {
  If GetKeyState("LButton", "P") || (LbtnDwn=1)
  {
     SetTimer, winGoNextSlide, -25
     Return
  }

  If (mPosCtrl="PicOnGUI3" || editingSelectionNow=1)
     GoNextSlide()
  Else If (mPosCtrl="PicOnGUI2a" || mPosCtrl="PicOnGUI2b" || mPosCtrl="PicOnGUI2c" || mPosCtrl="PicOnGUI1") && (editingSelectionNow!=1)
     GoPrevSlide()
}

winGoSlide() {
  If (editingSelectionNow=1)
     Return

  If GetKeyState("LButton", "P") || (LbtnDwn=1)
  {
     SetTimer, winGoSlide, -25
     Return
  }
  If (mPosCtrl="PicOnGUI1" && prevMPosCtrl!="PicOnGUI1")
     GoPrevSlide()
  Else If (mPosCtrl="PicOnGUI3" && prevMPosCtrl!="PicOnGUI3")
     GoNextSlide()
  Else If (mPosCtrl="PicOnGUI2a" && prevMPosCtrl!="PicOnGUI2a")
     ThumbsNavigator("Upu", "-")
  Else If (mPosCtrl="PicOnGUI2c" && prevMPosCtrl!="PicOnGUI2c")
     ThumbsNavigator("Down", "-")
}

winGoPrevSlide() {
  If GetKeyState("LButton", "P") || (LbtnDwn=1)
  {
     SetTimer, winGoPrevSlide, -25
     Return
  }
  If (mPosCtrl="PicOnGUI1" || editingSelectionNow=1)
     GoPrevSlide()
  Else If (mPosCtrl="PicOnGUI2a" || mPosCtrl="PicOnGUI2b" || mPosCtrl="PicOnGUI2c" || mPosCtrl="PicOnGUI3") && (editingSelectionNow!=1)
     GoNextSlide()
}

JEE_ScreenToWindow(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472

  VarSetCapacity(RECT, 16)
  DllCall("user32\GetWindowRect", Ptr,hWnd, Ptr,&RECT)
  vWinX := NumGet(&RECT, 0, "Int")
  vWinY := NumGet(&RECT, 4, "Int")
  vPosX2 := vPosX - vWinX
  vPosY2 := vPosY - vWinY
}

JEE_ScreenToClient(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472
  VarSetCapacity(POINT, 8)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ScreenToClient", Ptr,hWnd, Ptr,&POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
}


ToggleImageSizingMode() {
    resetSlideshowTimer(0)
    IMGdecalageX := IMGdecalageX := 1
    IMGresizingMode++
    If (IMGresizingMode>4)
       IMGresizingMode := 1

    friendly := DefineImgSizing()
    showTOOLtip("Rescaling mode: " friendly)
    SetTimer, RemoveTooltip, % -msgDisplayTime
    writeMainSettings()
    r := IDshowImage(currentFileIndex)
    If !r
       informUserFileMissing()
}

DefineImgSizing() {
   friendly := (IMGresizingMode=1) ? "ADAPT ALL INTO VIEW" : "ADAPT ONLY LARGE IMAGES"
   If (IMGresizingMode=3)
      friendly := "NONE (ORIGINAL SIZE)"
   Else If (IMGresizingMode=4)
      friendly := "CUSTOM ZOOM: " Round(zoomLevel * 100) "%"

   Return friendly
}

dummyInfoToggleSlideShowu() {
  Static lastInvoked := 1

  ToggleSlideShowu()
  If (slideShowRunning!=1)
  {
     showTOOLtip("Slideshow stopped")
     SetTimer, RemoveTooltip, % -msgDisplayTime
     lastInvoked := A_TickCount
  } Else ;  If (A_TickCount - lastInvoked > 450)
  {
     delayu := DefineSlidesRate()
     friendly := DefineSlideShowType()
     etaTime := "Estimated time: " EstimateSlideShowLength()
     showTOOLtip("Started " friendly " slideshow`nSpeed: " delayu "`nTotal files: "  maxFilesIndex "`n" etaTime)
     SetTimer, RemoveTooltip, % -msgDisplayTime
  } ; Else  SetTimer, dummyInfoToggleSlideShowu, Off
}

InfoToggleSlideShowu() {
  Critical, on
  Static lastInvoked := 1
  If (A_TickCount - lastInvoked < 350) && (slideShowRunning!=1)
  {
     lastInvoked := A_TickCount
     Return
  }

  lastInvoked := A_TickCount
  If !(IMGlargerViewPort=1 && IMGresizingMode=4)
     SetTimer, dummyInfoToggleSlideShowu, -80, 900
}

preventScreenOff() {
  ; if the user is idle ;-)
  Static lastInvoked := 1
  If (A_TickCount - lastInvoked < 10500) || (slideShowRunning!=1)
     Return

  lastInvoked := A_TickCount
  If (!GetKeyState("Space", "P") && slideShowRunning=1 && WinActive("A")=PVhwnd)
  {
     MouseMove, 2, 0, 2, R
     MouseMove, -2, 0, 2, R
;     SendEvent, {Up}
  }
}

ToggleSlideShowu() {
  If (slideShowRunning=1)
  {
     slideShowRunning := 0
     imgQuality := (userimgQuality=1) ? 7 : 5
     Gdip_SetInterpolationMode(glPG, imgQuality)
     SetTimer, theSlideShowCore, Off
  } Else If (thumbsDisplaying!=1)
  {
     slideShowRunning := 1
     imgQuality := 7
     Gdip_SetInterpolationMode(glPG, imgQuality)
     If (hSNDmediaFile && hSNDmediaDuration && hSNDmedia)
        milisec := MCI_Length(hSNDmedia) 

     thisSlideSpeed := (milisec>slideShowDelay) ? milisec : slideShowDelay
     SetTimer, theSlideShowCore, % thisSlideSpeed
  }
}

theSlideShowCore() {
  If (SlideHowMode=1)
     RandomPicture()
  Else If (SlideHowMode=2)
     PreviousPicture()
  Else If (SlideHowMode=3)
     NextPicture()
}

GoNextSlide() {
  Sleep, 15
  If GetKeyState("LButton", "P")
  {
     SetTimer, GoNextSlide, -100
     Return
  }

  resetSlideshowTimer(0)
  theSlideShowCore()
}

GoPrevSlide() {
  Sleep, 15
  If GetKeyState("LButton", "P")
  {
     SetTimer, GoPrevSlide, -100
     Return
  }

  resetSlideshowTimer(0)
  If (SlideHowMode=1)
     PrevRandyPicture()
  Else If (SlideHowMode=2)
     PreviousPicture()
  Else If (SlideHowMode=3)
     NextPicture()
}

coreSecToHHMMSS(Seco, ByRef Hrs, ByRef Min, ByRef Sec) {
  OldFormat := A_FormatFloat
  SetFormat, Float, 2.00
  Hrs := Seco//3600/1
  Min := Mod(Seco//60, 60)/1
  Sec := Mod(Seco,60)/1
  SetFormat, Float, %OldFormat%
}

SecToHHMMSS(Seco) {
  coreSecToHHMMSS(Seco, Hrs, Min, Sec)
  If (hrs>26)
     dayz := Round(hrs/24, 2)
  If (dayz>=1.1)
  {
     If (dayz>32)
        Return "about " Round(dayz/30.5, 2) " months"
     r := dayz " days"
  } Else  r := (Hrs ? Hrs "h " : "") Min "m " Sec "s"

  If (!min && !hrs)
  {
     r := StrReplace(r, "0m ")
     r := Trim(r, "0")
  }
  r := StrReplace(r, "  ", A_Space)
  r := Trim(r)

  Return r
}

DefineSlideShowType() {
   friendly := (SlideHowMode=1) ? "RANDOM" : "BACKWARD"
   If (SlideHowMode=3)
      friendly := "FORWARD"
   Return friendly
}

SwitchSlideModes() {
   SlideHowMode++
   If (SlideHowMode>3)
      SlideHowMode := 1

   resetSlideshowTimer(0, 1)
   friendly := DefineSlideShowType() "`nCurrently "
   friendly .= (slideShowRunning=1) ? "running" : "stopped"
   showTOOLtip("Slideshow mode: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   writeMainSettings()
}

DefineFXmodes() {
   Static FXmodesLabels := {1:"ORIGINAL", 2:"PERSONALIZED", 3:"AUTO-ADJUSTED", 4:"GRAYSCALE", 5:"RED CHANNEL", 6:"GREEN CHANNEL", 7:"BLUE CHANNEL", 8:"ALPHA CHANNEL", 9:"INVERTED COLORS"}
        , otherFXLabels := {1:"ADAPTIVE", 2:"BRIGHTNESS", 3:"CONTRAST"}
   If FXmodesLabels.HasKey(imgFxMode)
      friendly := FXmodesLabels[imgFxMode]
   Else
      friendly := "Colors FX: " imgFxMode
   If (imgFxMode=3)
      friendly .= A_Space otherFXLabels[autoAdjustMode]

   If (bwDithering=1 && imgFxMode=4)
      friendly := "BLACK/WHITE DITHERED"

   If (imgFxMode=1 && RenderOpaqueIMG=1 && InStr(currentPixFmt, "argb"))
      friendly .= "`nAlpha channel: REMOVED"

   Return friendly
}

ToggleImgColorDepth(dir:=0) {
   If (thumbsDisplaying=1)
      Return

   resetSlideshowTimer(0)
   If (imgFxMode=4 && bwDithering=1)
   {
      imgFxMode := 1
      Return
   }

   good2go := (imgFxMode=1 || imgFxMode=2 || imgFxMode=3 || imgFxMode=8) ? 1 : 0
   If (good2go!=1)
      imgFxMode := 1

   If (dir=1)
      usrColorDepth--
   Else
      usrColorDepth++

   If (usrColorDepth>9)
      usrColorDepth := 1
   Else If (usrColorDepth<1)
      usrColorDepth := 9

   prevStartIndex := -1
   infoColorDepth := (usrColorDepth>1) ? defineColorDepth() : "NONE"
   showTOOLtip("Image color depth simulated: " infoColorDepth)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   writeMainSettings()
   SetTimer, RefreshImageFile, -50
}

defineColorDepth() {
   Static bitsOptions := {0:0, 1:0, 2:2, 3:3, 4:4, 5:5, 6:6, 7:7, 8:8, 9:16}

   internalColorDepth := bitsOptions[usrColorDepth]
   r := internalColorDepth " bits [" 2**internalColorDepth " colors]"
   If (r<1)
      r := currentPixFmt
   Return r
}

ToggleImgFX(dir:=0) {
   resetSlideshowTimer(0)
   o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
   If (dir=1)
      imgFxMode--
   Else
      imgFxMode++

  prevColorAdjustZeit := A_TickCount
   If (imgFxMode=3 && thumbsDisplaying=1)
   {
      If (dir=1)
         imgFxMode--
      Else
         imgFxMode++
   }

   ; If (InStr(currentPixFmt, "indexed") && dir!=1 && imgFxMode=5 && thumbsDisplaying!=1)
   ;    imgFxMode := 8
   ; Else If (InStr(currentPixFmt, "indexed") && dir=1 && imgFxMode=7 && thumbsDisplaying!=1)
   ;    imgFxMode := 4

   If (imgFxMode>9)
      imgFxMode := 1
   Else If (imgFxMode<1)
      imgFxMode := 9

   friendly := DefineFXmodes()
   If (imgFxMode=4)
      friendly .= "`nBrightness: " Round(lumosGrayAdjust, 3) "`nContrast: " Round(GammosGrayAdjust, 3) "`nVibrance: " Round(zatAdjust) "%" "`nHue: " Round(hueAdjust) "°"
   Else If (imgFxMode=2)
      friendly .= "`nBrightness: " Round(lumosAdjust, 3) "`nContrast: " Round(GammosAdjust, 3) "`nSaturation: " Round(satAdjust*100) "%" "`nVibrance: " Round(zatAdjust) "%" "`nHue: " Round(hueAdjust) "°"
   Else If (imgFxMode=3 || imgFxMode=9)
      friendly .= "`nVibrance: " Round(zatAdjust) "%" "`nHue: " Round(hueAdjust) "°"
   If (usrColorDepth>1 && imgFxMode=1)
      friendly .= "`nImage color depth: ALTERED [ " defineColorDepth() " ]"

   If (imgFxMode=4 || imgFxMode=3 || imgFxMode=2)
      friendly .= "`n `nPress U to adjust colors display options."
   showTOOLtip("Image colors: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   If (thumbsDisplaying=1)
      RefreshThumbsList()
   Else prevStartIndex := -1

   If (imgFxMode=3 && thumbsDisplaying!=1)
   {
      imgPath := resultedFilesList[currentFileIndex]
      AdaptiveImgLight(gdiBitmap, imgPath, 1, 1)
   }

   writeMainSettings()
   If (o_bwDithering=0)
      o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0

   If (o_bwDithering=1)
      RefreshImageFile()
   Else
      dummyTimerDelayiedImageDisplay(10)
}

defineImgAlign() {
   modes := {1:"Top-left corner", 2:"Top-center", 3:"Top-right corner", 4:"Left-center", 5:"Center", 6:"Right-center", 7:"Bottom-left corner", 8:"Bottom-center", 9:"Bottom-right corner"}
   thisAlign := (IMGresizingMode=4) ? 5 : imageAligned
   r := modes[thisAlign]
   StringUpper, r, r
   Return r
}

ToggleIMGalign() {
   If (thumbsDisplaying=1 || IMGresizingMode=4)
      Return

   resetSlideshowTimer(0)
   imageAligned++
   If (imageAligned>9)
      imageAligned := 1

   showTOOLtip("Image alignment: " defineImgAlign())
   SetTimer, RemoveTooltip, % -msgDisplayTime
   writeMainSettings()
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

toggleColorAdjustments() {
  If (imgFxMode!=1 && thumbsDisplaying!=1)
  {
     prevColorAdjustZeit := A_TickCount
     resetSlideshowTimer(0)
     ForceNoColorMatrix := !ForceNoColorMatrix
     AnyWindowOpen := (ForceNoColorMatrix=1) ? 10 : 0
     dummyTimerDelayiedImageDisplay(50)
     SetTimer, resetClrMatrix, -1500
  }
}

resetClrMatrix() {
   resetSlideshowTimer(0)
   AnyWindowOpen := ForceNoColorMatrix := 0
   dummyTimerDelayiedImageDisplay(50)
}

ResetImageView() {
   Critical, on
   ChangeLumos(2)
}

HardResetImageView() {
   Critical, on
   ChangeLumos(2, "k")
}

ChangeLumos(dir, dummy:=0) {
   Static prevValues
   resetSlideshowTimer(0)
   If (imgFxMode!=2 && imgFxMode!=4 && dir!=2)
      imgFxMode := 2

   prevColorAdjustZeit := A_TickCount
   o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
   If (dir=2)
   {
      
      If (imgFxMode=4 && lumosGrayAdjust=1 && GammosGrayAdjust=0)
         mustResetFxMode := 1

      otherFX := (vpIMGrotation>0 && thumbsDisplaying!=1) || (usrColorDepth>1 && dummy="k") ? 1 : 0
      If (dummy="k" && imgFxMode>1)
      {
         chnRdecalage := chnGdecalage := chnBdecalage := 0
         imgThreshold := bwDithering := hueAdjust := zatAdjust := 0
      }

      If (imgFxMode=4 || dummy="k")
      {
         ; bwDithering := 0
         GammosGrayAdjust := 0
         lumosGrayAdjust := 1
      } Else If (imgFxMode=2 || dummy="k")
      {
         satAdjust := lumosAdjust := 1
         GammosAdjust := 0
      }

      If (imgFxMode=2 || imgFxMode=3)
         chnRdecalage := chnGdecalage := chnBdecalage := 0

      realGammos := 1
      If (imgFxMode=1)
      {
         zoomLevel := 1
         FlipImgH := FlipImgV := 0
         If (thumbsDisplaying!=1)
           vpIMGrotation := 0
      }

      If (imgFxMode=2 || imgFxMode=3 || imgFxMode>4 || mustResetFxMode=1)
         imgFxMode := 1

      If (thumbsDisplaying=1)
      {
         thumbsZoomLevel := 1
         thumbsH := othumbsH + 1
         thumbsW := othumbsW + 1
         SetTimer, RefreshThumbsList, -250
      }

      If (dummy="k")
         usrColorDepth := internalColorDepth := 0
   } Else If (imgFxMode=4)
   {
      If (dir=1)
         lumosGrayAdjust := lumosGrayAdjust + 0.05
      Else
         lumosGrayAdjust := lumosGrayAdjust - 0.05
      If (lumosGrayAdjust<0)
         lumosGrayAdjust := 0.001
      Else If (lumosGrayAdjust>25)
         lumosGrayAdjust := 25
   } Else
   {
      If (dir=1)
         lumosAdjust := (lumosAdjust<=1) ? lumosAdjust + 0.05 : lumosAdjust + 0.1
      Else
         lumosAdjust := (lumosAdjust<=1) ? lumosAdjust - 0.05 : lumosAdjust - 0.1

      If (lumosAdjust<0)
         lumosAdjust := 0.001
      Else If (lumosAdjust>25)
         lumosAdjust := 25
   }

   value2show := (imgFxMode=4) ? Round(lumosGrayAdjust, 3) : Round(lumosAdjust, 3)
   If (dir=2)
   {
      If (imgFxMode=4)
         addMsg := DefineFXmodes()
      If (imgFxMode=1 && RenderOpaqueIMG=1 && InStr(currentPixFmt, "argb"))
         addMsg .= "`nAlpha channel: REMOVED"
      If (imgFxMode=1 && usrColorDepth>1)
         addMsg .= "`nImage color depth: ALTERED [ " defineColorDepth() " ]"
      If (vpIMGrotation>0)
         addMsg .= "`nImage rotated: " vpIMGrotation "° degrees."
      addMsg .= defineIMGmirroring()
      showTOOLtip("Image display: UNALTERED " addMsg " `n`nTo reset all the adjustments`nto their defaults press Ctrl + \")
   } Else showTOOLtip("Image brightness: " value2show)

   If (thumbsDisplaying!=1)
      prevStartIndex := -1
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust GammosAdjust lumosAdjust imgFxMode
   If (prevValues=newValues && dir!=2)
      Return

   prevValues := newValues
   If (o_bwDithering=1 || otherFX=1)
      SetTimer, RefreshImageFile, -50
   Else
      dummyTimerDelayiedImageDisplay(10)
}

defineIMGmirroring() {
    If (FlipImgH=1 || FlipImgV=1)
    {
       infoMirroring := "`nImage mirroring: "
       If (FlipImgV=1 && FlipImgH=0)
          infoMirroring :=  infoMirroring "VERTICAL"
       Else If (FlipImgV=0 && FlipImgH=1)
          infoMirroring := infoMirroring "HORIZONTAL"
       Else If (FlipImgV=1 && FlipImgH=1)
          infoMirroring := infoMirroring "VERTICAL, HORIZONTAL"
    }
    Return infoMirroring
}

ChangeZoom(dir, key:=0) {
   Static prevValues

   resetSlideshowTimer(0)
   If (thumbsDisplaying=1)
   {
      writeMainSettings()
      If (dir=1)
         thumbsZoomLevel := thumbsZoomLevel + 0.1
      Else
         thumbsZoomLevel := thumbsZoomLevel - 0.1

      newValues := "a" zoomLevel thumbsZoomLevel thumbsAratio
      If (prevValues=newValues)
         Return

      prevValues := newValues
      thumbsH := Round(othumbsH*thumbsZoomLevel)
      thumbsW := Round(othumbsW*thumbsZoomLevel)
      If (thumbsZoomLevel<0.35)
         thumbsZoomLevel := 0.35
      Else If (thumbsZoomLevel>10)
         thumbsZoomLevel := 10
      setTexHatchScale(thumbsZoomLevel/2)
      showTOOLtip("Thumbnails zoom level: " Round(thumbsZoomLevel*100) "%`nSize: " thumbsW " x " thumbsH " (pixels)")
      SetTimer, RemoveTooltip, % -msgDisplayTime
      SetTimer, RefreshThumbsList, -250
      Return
   }
   oldZoomLevel := zoomLevel

   If (zoomLevel>5)
      changeFactor := 0.50
   Else If (zoomLevel>1)
      changeFactor := 0.15
   Else If (zoomLevel<0.01)
      changeFactor := 0.005
   Else If (zoomLevel<=0.1)
      changeFactor := 0.01
   Else
      changeFactor := 0.05
      
   If (dir=1)
      zoomLevel := zoomLevel + changeFactor
   Else
      zoomLevel := zoomLevel - changeFactor

   o_IMGresizingMode := IMGresizingMode
   IMGresizingMode := 4
   imageAligned := 5
   If (zoomLevel<0.01)
      zoomLevel := 0.01
   Else If (zoomLevel>20)
      zoomLevel := 20
   If anotherVPcache
      anotherVPcache := Gdip_DisposeImage(anotherVPcache, 1)

   MouseGetPos, , , OutputVarWin
   If (OutputVarWin=PVhwnd && InStr(key, "wheel"))
   {
      GetMouseCoord2wind(PVhwnd, mX, mY)
      GetClientSize(mainWidth, mainHeight, PVhwnd)
      prcW := mX/mainWidth
      prcH := mY/mainHeight
      prcW := (prcW>0.5) ? prcW - 0.5 : 0.5 - prcW
      prcH := (prcH>0.5) ? prcH - 0.5 : 0.5 - prcH
      Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
      decX := Round(((imgW)*prcW) * zoomLevel)
      decY := Round(((imgH)*prcH) * zoomLevel)
      prcW := mX/mainWidth
      prcH := mY/mainHeight
      If (prcW>0.5)
         decX := -decX
      If (prcH>0.5)
         decY := -decY
      IMGdecalageX := IMGdecalageX + decX//10
      IMGdecalageY := IMGdecalageY + decY//10
   }

   ; tooltip, % IMGdecalageX " -- " IMGdecalageY "`n" decX " -- " decY "`n"prcW " -- " prcH
   setTexHatchScale(zoomLevel)
   showTOOLtip("Zoom level: " Round(zoomLevel*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" zoomLevel thumbsZoomLevel IMGresizingMode imageAligned resultedFilesList[currentFileIndex]
   If (prevValues=newValues)
      Return

   prevValues := newValues
   If (o_IMGresizingMode=1 && enableThumbsCaching=1) || (LastPrevFastDisplay=1)
      SetTimer, coreReloadThisPicture, -10
   Else
      dummyTimerDelayiedImageDisplay(10)
}

setTexHatchScale(zL, forceIT:=0) {
   Static prevScaleTex
   If (!InStr(currentPixFmt, "argb") || userimgQuality=0)
      Return

   ScaleTex := (zL>1) ? zL/2 + 0.5 : zL
   If (ScaleTex<0.50)
      ScaleTex := 0.50
   If (prevScaleTex!=ScaleTex || forceIT=1)
   {
      Gdip_ResetTextureTransform(pBrushHatch)
      Gdip_ScaleTextureTransform(pBrushHatch, ScaleTex, ScaleTex)
      prevScaleTex := ScaleTex
   }
}

ChangeGammos(dir) {
   Static prevValues

   resetSlideshowTimer(0)
   o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
   If (imgFxMode!=2 && imgFxMode!=4)
      imgFxMode := 2

   value2Adjust := (imgFxMode=4) ? GammosGrayAdjust : GammosAdjust
   value2AdjustB := (imgFxMode=4) ? lumosGrayAdjust : lumosAdjust
   If (dir=1)
   {
      value2Adjust := value2Adjust + 0.05
      value2AdjustB := value2AdjustB - 0.05
   } Else
   {
      value2Adjust := value2Adjust - 0.05
      value2AdjustB := value2AdjustB + 0.05
   }

   If (value2Adjust<-25)
      value2Adjust := -25
   Else If (value2Adjust>1)
      value2Adjust := 1

   If (imgFxMode=4)
   {
      GammosGrayAdjust := value2Adjust
      lumosGrayAdjust := value2AdjustB
   } Else
   {
      GammosAdjust := value2Adjust
      lumosAdjust := value2AdjustB
   }

   prevColorAdjustZeit := A_TickCount
   If (thumbsDisplaying!=1)
      prevStartIndex := -1
   showTOOLtip("Image contrast: " Round(value2Adjust, 3))
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust GammosAdjust lumosAdjust imgFxMode
   If (prevValues=newValues)
      Return

   prevValues := newValues
   If (o_bwDithering=1)
      SetTimer, RefreshImageFile, -50
   Else
      dummyTimerDelayiedImageDisplay(10)
}

ChangeSaturation(dir) {
   Static prevValues

   resetSlideshowTimer(0)
   If (imgFxMode=4)
      satAdjust := 0

   prevColorAdjustZeit := A_TickCount
   imgFxMode := 2
   value2Adjust := satAdjust
   If (dir=1)
      value2Adjust := value2Adjust + 0.05
   Else
      value2Adjust := value2Adjust - 0.05

   If (value2Adjust<0)
      value2Adjust := 0
   Else If (value2Adjust>3.00)
      value2Adjust := 3.00

   satAdjust := value2Adjust
   If (thumbsDisplaying!=1)
      prevStartIndex := -1
   showTOOLtip("Image saturation: " Round(value2Adjust*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" satAdjust imgFxMode
   If (prevValues=newValues)
      Return

   prevValues := newValues
   dummyTimerDelayiedImageDisplay(10)
}


ChangeRealGamma(dir) {
   Static prevValues

   resetSlideshowTimer(0)
   prevColorAdjustZeit := A_TickCount
   imgFxMode := 2
   value2Adjust := realGammos
   If (value2Adjust>2)
      stepu := 0.2
   Else If (value2Adjust<0.1)
      stepu := 0.01
   Else
      stepu := 0.05

   If (dir=1)
      value2Adjust := value2Adjust + stepu
   Else
      value2Adjust := value2Adjust - stepu

   If (value2Adjust<0)
      value2Adjust := 0.01
   Else If (value2Adjust>8)
      value2Adjust := 8

   realGammos := value2Adjust
   If (thumbsDisplaying!=1)
      prevStartIndex := -1
   showTOOLtip("Image gamma: " Round(value2Adjust*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" realGammos imgFxMode
   If (prevValues=newValues)
      Return

   prevValues := newValues
   dummyTimerDelayiedImageDisplay(10)
}

ChangeVolume(dir) {
   If (thumbsDisplaying=1)
      Return

   resetSlideshowTimer(0)
   value2Adjust := mediaSNDvolume
   If (dir=1)
      value2Adjust := value2Adjust + 5
   Else
      value2Adjust := value2Adjust - 5

   If (value2Adjust<1)
      value2Adjust := 1
   Else If (value2Adjust>100)
      value2Adjust := 100

   If !hSNDmedia
      infoMedia := "`nNo audio is currently playing..."

   mediaSNDvolume := value2Adjust
   SetVolume(mediaSNDvolume)
   showTOOLtip("Audio volume: " value2Adjust "%" infoMedia)
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

MenuChangeImgRotationInVP() {
   changeImgRotationInVP(1, 45)
}

changeImgRotationInVP(dir, rotStep:=15) {
   If (thumbsDisplaying=1)
      Return

   resetSlideshowTimer(0)
   value2Adjust := vpIMGrotation
   If (dir=1)
      value2Adjust := value2Adjust + rotStep
   Else
      value2Adjust := value2Adjust - rotStep

   If (value2Adjust<0)
      value2Adjust := 360 - rotStep
   Else If (value2Adjust>360 - rotStep)
      value2Adjust := 0

   vpIMGrotation := value2Adjust
   SetTimer, dummyChangeVProtation, -10
   SetTimer, RefreshImageFile, -750
}

dummyChangeVProtation() {
   showTOOLtip("Image rotation: " vpIMGrotation "° ")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   GdipCleanMain(4)
}

nextDesiredFrame() {
    changeDesiredFrame(1)
}

prevDesiredFrame() {
    changeDesiredFrame(-1)
}

changeDesiredFrame(dir:=1) {
   Static prevValues, lastInvoked := 1
   If (thumbsDisplaying=1)
      Return

   resetSlideshowTimer(0)
   value2Adjust := desiredFrameIndex
   If (dir=1)
      value2Adjust := value2Adjust + 1
   Else
      value2Adjust := value2Adjust - 1

   If (value2Adjust<0)
      value2Adjust := totalFramesIndex
   Else If (value2Adjust>totalFramesIndex)
      value2Adjust := 0

   desiredFrameIndex := value2Adjust
   If (GIFsGuiCreated=1)
      DestroyGIFuWin()

   prevAnimGIFwas := resultedFilesList[currentFileIndex]
   If (A_TickCount - lastInvoked > 350)
   {
      showTOOLtip("Image frame index: " value2Adjust " / " totalFramesIndex)
      SetTimer, RemoveTooltip, % -msgDisplayTime
      lastInvoked := A_TickCount
   } Else SetTimer, showCurrentFrameIndex, -400

   Global lastGIFdestroy := A_TickCount
   newValues := value2Adjust currentFileIndex
   If (prevValues!=newValues)
   {
      SetTimer, RefreshImageFile, -5
      prevValues := newValues
   }
}

showCurrentFrameIndex() {
    showTOOLtip("Image frame index: " desiredFrameIndex " / " totalFramesIndex)
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

TransformIMGv() {
   resetSlideshowTimer(0)
   prevStartIndex := -1
   FlipImgV := !FlipImgV
   If (FlipImgV=1)
   {
      showTOOLtip("Image mirrored vertically")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
   writeMainSettings()
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

setMainCanvasTransform(W, H, G:=0) {
    If (thumbsDisplaying=1)
       Return

    If !G
       G := glPG

    If (FlipImgH=1)
    {
       Gdip_ScaleWorldTransform(G, -1, 1)
       Gdip_TranslateWorldTransform(G, -W, 0)
    }

    If (FlipImgV=1)
    {
       Gdip_ScaleWorldTransform(G, 1, -1)
       Gdip_TranslateWorldTransform(G, 0, -H)
    }
}

TransformIMGh() {
   resetSlideshowTimer(0)
   prevStartIndex := -1
   FlipImgH := !FlipImgH
   If (FlipImgH=1)
   {
      showTOOLtip("Image mirrored horizontally")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }

   writeMainSettings()
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

PreviousPicture(dummy:=0, inLoop:=0, selForbidden:=0) {
   prevFileIndex := currentFileIndex
   If (GetKeyState("Shift", "P") && thumbsDisplaying!=1 && slideShowRunning!=1 && selForbidden!=1)
      shiftPressed := 1

   currentFileIndex--
   If (currentFileIndex<1)
      currentFileIndex := (thumbsDisplaying=1 || shiftPressed=1 || selForbidden=1) ? 1 : maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := (thumbsDisplaying=1 || shiftPressed=1 || selForbidden=1) ? maxFilesIndex : 1

   If (shiftPressed=1)
      thumbsSelector("Left", "+Left", prevFileIndex)

   endLoop := (inLoop=250) ? 250 : 0
   r := IDshowImage(currentFileIndex, endLoop)
   If (!r && inLoop<250)
   {
      inLoop++
      PreviousPicture(0, inLoop)
   } Else inLoop := 0
}

NextPicture(dummy:=0, inLoop:=0, selForbidden:=0) {
   prevFileIndex := currentFileIndex
   If (GetKeyState("Shift", "P") && slideShowRunning!=1 && thumbsDisplaying!=1 && selForbidden!=1)
      shiftPressed := 1

   currentFileIndex++
   If (currentFileIndex<1)
      currentFileIndex := (thumbsDisplaying=1 || shiftPressed=1 || selForbidden=1) ? 1 : maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := (thumbsDisplaying=1 || shiftPressed=1 || selForbidden=1) ? maxFilesIndex : 1

   If (shiftPressed=1)
      thumbsSelector("Right", "+Right", prevFileIndex)

   endLoop := (inLoop=250) ? 250 : 0
   r := IDshowImage(currentFileIndex, endLoop)
   If (!r && inLoop<250)
   {
      inLoop++
      NextPicture(0, inLoop)
   } Else inLoop := 0
}

drawTextInBox(theString, fntName, theFntSize, maxW, maxH, txtColor, bgrColor, NoWrap, flippable:=0) {
    hbm := CreateDIBSection(maxW, maxH)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc, 7, 4, 2)
    pBr0 := Gdip_BrushCreateSolid(bgrColor)
    Gdip_FillRectangle(G, pBr0, -2, -2, maxW + 4, maxH + 4)
    If (FontBolded=1)
       txtStyle .= " Bold"
    If (FontItalica=1 && NoWrap=0)
       txtStyle .= " Italic"
    Else If (NoWrap=1)
       txtStyle .= " NoWrap"
    txtOptions := "x1 y1 " usrTextAlign " cEE" txtColor " r4 s" theFntSize txtStyle
    dimensions := Gdip_TextToGraphics(G, theString, txtOptions, fntName, maxW, maxH, 0, 0,3)
    txtRes := StrSplit(dimensions, "|")
    txtX := Floor(txtRes[1]-1)
    txtY := Floor(txtRes[2]-1)
    txtResW := Ceil(txtRes[3]+2)
    If (txtResW>maxW)
       txtResW := maxW
    txtResH := Ceil(txtRes[4]+2)
    If (txtResH>maxH)
       txtResH := maxH
    clipBMPa := Gdip_CreateBitmapFromHBITMAP(hbm)
    clipBMPb := Gdip_CloneBitmapArea(clipBMPa, txtX + 1, txt + 1, txtResW - 1, txtResH - 1)
    Gdip_DisposeImage(clipBMPa, 1)

    borderSize := NoWrap ? Floor(theFntSize*1.1) : Floor(theFntSize*1.3)
    clipBMP := Gdip_CreateBitmap(txtResW + borderSize * 2, txtResH + borderSize*2, 0x21808)   ; 24-RGB
    G3 := Gdip_GraphicsFromImage(clipBMP)
    Gdip_GetImageDimensions(clipBMP, maxW, maxH)
    If (flippable=1)
       setMainCanvasTransform(maxW, maxH, G3)
    Gdip_FillRectangle(G3, pBr0, -2, -2, txtResW + borderSize*2+12, txtResH + borderSize*2+12)
    Gdip_DrawImageFast(G3, clipBMPb, borderSize, borderSize)
    Gdip_DeleteGraphics(G3)
    Gdip_DisposeImage(clipBMPb, 1)
    Gdip_DeleteBrush(pBr0)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Return clipBMP
}

drawHistogram(dataArray, maxYlimit, LengthX, Scale, fgrColor, bgrColor, borderSize, infoBoxBMP) {
    graphPath := Gdip_CreatePath()
    PointsList .= 0 "," 125 "|"
    Loop, % LengthX
    {
        y1 := 125 - ((dataArray[A_Index - 1]/maxYlimit) * 100)
        If (y1<0)
           y1 := 0
        PointsList .= A_Index - 1 ","  y1 "|"
    }
    PointsList .= LengthX + 1 "," 125
    Gdip_AddPathClosedCurve(graphPath, PointsList, 0.001)
    pMatrix := Gdip_CreateMatrix()
    Gdip_ScaleMatrix(pMatrix, Scale, Scale, 1)
    Gdip_TransformPath(graphPath, pMatrix)

    thisRect := Gdip_GetPathWorldBounds(graphPath)
    imgW := thisRect.w, imgH := thisRect.h
    hbm := CreateDIBSection(imgW, imgH)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc, 7, 4, 2)
    pBr0 := Gdip_BrushCreateSolid(bgrColor)
    pBr1 := Gdip_BrushCreateSolid(fgrColor)
    Gdip_FillRectangle(G, pBr0, -2, -2, imgW + 4, imgH + 4)
    Gdip_FillRectangle(G, pBrushE, -2, -2, imgW + 4, imgH + 4)

    Gdip_FillPath(G, pBr1, graphPath)
    Gdip_DeletePath(graphPath)
    Gdip_DeleteMatrix(pMatrix)
    Gdip_GetImageDimensions(infoBoxBMP, imgW2, imgH2)
    clipBMPa := Gdip_CreateBitmapFromHBITMAP(hbm)
    clipBMP := Gdip_CreateBitmap(imgW + borderSize * 2, imgH + imgH2 + Round(borderSize*1.5), 0x21808)   ; 24-RGB
    G3 := Gdip_GraphicsFromImage(clipBMP)
    Gdip_GetImageDimensions(clipBMP, maxW, maxH)
    lineThickns := borderSize//10
    Gdip_SetPenWidth(pPen1d, lineThickns)
    Gdip_FillRectangle(G3, pBr0, -2, -2, maxW + borderSize*2+12, maxH + borderSize*3)
    Gdip_DrawRectangle(G3, pPen1d, borderSize - lineThickns, borderSize - lineThickns, imgW + lineThickns*2, imgH + lineThickns*2)
    Gdip_DrawImageFast(G3, clipBMPa, borderSize, borderSize)
    Gdip_DrawImageFast(G3, infoBoxBMP, borderSize, imgH + borderSize*1.25)
    Gdip_DeleteGraphics(G3)
    Gdip_DisposeImage(clipBMPa, 1)
    Gdip_DeleteBrush(pBr0)
    Gdip_DeleteBrush(pBr1)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    ; tooltip, % maxYlimit ", " LengthX " || "  maxW "," maxH  ;  `n" PointsList
    Return clipBMP
}

PasteClipboardIMG() {
    changeMcursor()
    ToolTip, Pasting image...
    clipBMP := Gdip_CreateBitmapFromClipboard()
    If (valueBetween(Abs(clipBMP), 1, 5) || !clipBMP)
    {
       Try testClipType := DllCall("IsClipboardFormatAvailable", "uint", 15) ; do not paste file paths [CF_HDROP]
       If (testClipType!=1)
          Try toPaste := Trim(Clipboard)

       If StrLen(toPaste)>2
       {
          textMode := 1
          toPaste := SubStr(toPaste, 1, 9500)
          calcScreenLimits()
          clipBMP := drawTextInBox(toPaste, OSDFontName, PasteFntSize, ResolutionWidth*2, Ceil(ResolutionHeight*4.25), OSDtextColor, "0xFF" OSDbgrColor, 0)
          showTOOLtip("Text clipboard content rendered as image...`nOSD font and colors used")
          SetTimer, RemoveTooltip, % -msgDisplayTime
       } Else
       {
          Tooltip
          showTOOLtip("Unable to retrieve image from clipboard...")
          SetTimer, RemoveTooltip, % -msgDisplayTime
          Try DllCall("user32\SetCursor", "Ptr", hCursN)
          Return
       }
    }

    disposeCacheIMGs()
    If (textMode!=1)
    {
       isUniform := Gdip_TestBitmapUniformity(clipBMP, 7, maxLevelIndex)
       If (isUniform=1 && (valueBetween(maxLevelIndex, 0, 5) || valueBetween(maxLevelIndex, 250, 255)))
          Gdip_BitmapSetColorDepth(clipBMP, 24)
    }

    If (activateImgSelection=1 || editingSelectionNow=1)
       toggleImgSelection()
    file2save := thumbsCacheFolder "\Current-Clipboard.png"
    changeMcursor()
    r := Gdip_SaveBitmapToFile(clipBMP, file2save)
    Gdip_DisposeImage(clipBMP, 1)
    If r
    {
       Tooltip
       showTOOLtip("Failed to store image from clipboard...")
       SoundBeep , 300, 100
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Try DllCall("user32\SetCursor", "Ptr", hCursN)
       Return
    }

    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    If (slideShowRunning=1)
       ToggleSlideShowu()

    If (thumbsDisplaying=1)
       ToggleThumbsMode()

    imgFxMode := IMGresizingMode := 1
    markedSelectFile := thumbSelFileList := ""
    vpIMGrotation := FlipImgH := FlipImgV := currentFileIndex := 0
    resultedFilesList[0] := file2save
    ShowTheImage(file2save, 2)
    Tooltip
}

thumbsSelector(keyu, aKey, prevFileIndex) {
  Static lastInvoked := 1

  If (InStr(aKey, "+") || aKey="Shift")
  {
     totalCount := getSelectedFiles(0, 1)
     theFirst := getSelectedFiles(1)
     theLast := getSelectedFiles("L")
  }

  ; ToolTip, % prevFileIndex "--" markedSelectFile "`n" lola
  If (InStr(aKey, "+") && (keyu="Left" || keyu="Right"))
  {
     If (InStr(markedSelectFile, "," currentFileIndex - 2 "|") && prevFileIndex!=theLast && keyu="Right")
     || (InStr(markedSelectFile, "," currentFileIndex + 2 "|") && prevFileIndex!=theFirst && keyu="Left")
        mustReset := 1

     IF !InStr(markedSelectFile, "," prevFileIndex "|") || (mustReset=1)
     {
        thumbSelFileList := ""
        markedSelectFile := "," currentFileIndex "|," prevFileIndex "|"
     } Else
     {
        If (keyu="Left" && theLast=prevFileIndex && theLast!=theFirst)
        || (keyu="Right" && theFirst=prevFileIndex && theLast!=theFirst)
           markThisFileNow(prevFileIndex)
        Else If !InStr(markedSelectFile, "," currentFileIndex "|")
           markThisFileNow(currentFileIndex)
     }
  } Else If InStr(aKey, "+") ; && (keyu="Upu" || keyu="Down"))
  {
     direction := (keyu="Down" || keyu="PgDn" || keyu="End") ? 1 : 0
     If (InStr(markedSelectFile, "," prevFileIndex - 2 "|") && prevFileIndex!=theLast && direction=0)
     || (InStr(markedSelectFile, "," prevFileIndex + 2 "|") && prevFileIndex!=theFirst && direction=1)
        mustReset := 1

     IF (!InStr(markedSelectFile, "," prevFileIndex "|") || mustReset=1)
     {
        markedSelectFile := generateNumberRangeString(prevFileIndex, currentFileIndex)
     } Else
     {
        If (direction=0 && theLast=prevFileIndex && theLast!=theFirst && InStr(markedSelectFile, "," prevFileIndex "|") && InStr(markedSelectFile, "," prevFileIndex - 1 "|"))
           removeRangeSelection(prevFileIndex, currentFileIndex + 1)
        Else If (direction=1 && theFirst=prevFileIndex && theLast!=theFirst && InStr(markedSelectFile, "," prevFileIndex "|") && InStr(markedSelectFile, "," prevFileIndex + 1 "|"))
           removeRangeSelection(prevFileIndex, currentFileIndex - 1)
        Else If !InStr(markedSelectFile, "," currentFileIndex "|")
           markedSelectFile .= generateNumberRangeString(prevFileIndex, currentFileIndex)
        If !InStr(markedSelectFile, "," currentFileIndex "|")
           markedSelectFile .= "," currentFileIndex "|"
     }
  }

  If (InStr(aKey, "+") || aKey="Shift")
  {
     totalCount := getSelectedFiles(0)
     If (totalCount<2 || !totalCount)
        markedSelectFile := thumbSelFileList := ""
  }
}

removeRangeSelection(pA, pB) {
    mB := maxU(pA, pB)
    mA := minU(pA, pB)
    rangeC := mB - mA + 1
    Loop, % rangeC
    {
        stringu := "," mA + A_Index - 1 "|"
        If InStr(markedSelectFile, stringu)
           markedSelectFile := StrReplace(markedSelectFile, stringu)
        Else
           markedSelectFile .= stringu
    }
    thumbSelFileList := ""
    countFilez := getSelectedFiles()
    If !countFilez
       markedSelectFile := ""
}

generateNumberRangeString(pA, pB) {
    mB := maxU(pA, pB)
    mA := minU(pA, pB)
    rangeC := mB - mA + 1
    Loop, % rangeC
        stringRange .= "," mA + A_Index - 1 "|"

    thumbSelFileList := ""
    Return stringRange
}

ThumbsNavigator(keyu, aKey) {
  resetSlideshowTimer(0)
  prevFileIndex := currentFileIndex
  thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
  If (keyu="Down")
  {
     currentFileIndex := currentFileIndex + maxItemsW - 1
     NextPicture(0, 0, 1)
  } Else If (keyu="Upu")
  {
     currentFileIndex := currentFileIndex - maxItemsW + 1
     PreviousPicture(0, 0, 1)
  } Else If (keyu="PgUp")
  {
     currentFileIndex := currentFileIndex - maxItemsPage + 1
     PreviousPicture()
  } Else If (keyu="PgDn")
  {
     currentFileIndex := currentFileIndex + maxItemsPage - 1
     NextPicture()
  } Else If (keyu="Left")
     PreviousPicture()
  Else If (keyu="Right")
     NextPicture()
  Else If (keyu="End")
     LastPicture()
  Else If (keyu="Home")
     FirstPicture()

  thumbsSelector(keyu, aKey, prevFileIndex)
  If (thumbsDisplaying!=1 && InStr(aKey, "+"))
     dummyTimerDelayiedImageDisplay(50)
}

PanIMGonScreen(direction) {
   If (IMGresizingMode!=4)
   {
      IMGdecalageX := IMGdecalageY := 1
      Return
   }

   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (GetKeyState("Left", "P")!=1 && GetKeyState("Right", "P")!=1)
   && (GetKeyState("Down", "P")!=1 && GetKeyState("Up", "P")!=1)
      Return

   GetClientSize(mainWidth, mainHeight, PVhwnd)
   zL := (zoomLevel<0.7) ? 0.7 : zoomLevel
   If (zoomLevel>2)
      zL := 2
   stepu := GetKeyState("Shift", "P") ? 0.3 : 0.1 * zL
   stepu := (Round(mainHeight*stepu) + Round(mainWidth*stepu))//2 + 1
   If (direction="U" && FlipImgV=0) || (direction="D" && FlipImgV=1)
      IMGdecalageY := IMGdecalageY + stepu
   Else If (direction="D" && FlipImgV=0) || (direction="U" && FlipImgV=1)
      IMGdecalageY := IMGdecalageY - stepu
   Else If (direction="L" && FlipImgH=0) || (direction="R" && FlipImgH=1)
      IMGdecalageX := IMGdecalageX + stepu
   Else If (direction="R" && FlipImgH=0) || (direction="L" && FlipImgH=1)
      IMGdecalageX := IMGdecalageX - stepu

   If (direction="U" && FlipImgV=0) || (direction="D" && FlipImgV=1)
      diffIMGdecY := stepu
   Else If (direction="D" && FlipImgV=0) || (direction="U" && FlipImgV=1)
      diffIMGdecY := - stepu
   Else If (direction="L" && FlipImgH=0) || (direction="R" && FlipImgH=1)
      diffIMGdecX := stepu
   Else If (direction="R" && FlipImgH=0) || (direction="L" && FlipImgH=1)
      diffIMGdecX := - stepu

; ReloadThisPicture()
   If (LastPrevFastDisplay=1 || PannedFastDisplay=1)
      SetTimer, coreReloadThisPicture, -5
   Else
      dummyTimerDelayiedImageDisplay(10)
}

dummyTimerDelayiedImageDisplay(timeru:=0) {
  If (timeru>1)
     SetTimer, extraDummyDelayiedImageDisplay, % -timeru ; , 950
}

extraDummyDelayiedImageDisplay() {
  If (imageLoading=1)
  {
     SetTimer, extraDummyDelayiedImageDisplay, -15
     Return
  }
  DelayiedImageDisplay()
}

filterDelayiedImageDisplay() {
  Static lastInvoked := 1
  If (A_tickcount - lastInvoked < 60)
  {
     SetTimer, extraDummyDelayiedImageDisplay, -50
     Return
  }
  lastInvoked := A_TickCount
  DelayiedImageDisplay()
  lastInvoked := A_TickCount
}

DelayiedImageDisplay() {
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

createSettingsGUI(IDwin) {
    If (slideShowRunning=1)
       ToggleSlideShowu()

    If (editingSelectionNow=1)
       ToggleEditImgSelection()

    CloseWindow()
    Sleep, 15
    Gui, SettingsGUIA: Destroy
    Sleep, 15
    Gui, SettingsGUIA: Default
    Gui, SettingsGUIA: -MaximizeBox -MinimizeBox +Owner1 hwndhSetWinGui
    Gui, SettingsGUIA: Margin, 15, 15
    AnyWindowOpen := IDwin
}

ShowImgInfosPanel() {
    Global LViewMetaD
    If (thumbsDisplaying=1)
       MenuDummyToggleThumbsMode()

    imgPath := resultedFilesList[currentFileIndex]
    zPlitPath(imgPath, 0, fileNamu, folderu)
    If !FileRexists(imgPath)
    {
       showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
       SoundBeep, 300, 50
       Return
    }

    createSettingsGUI(5)
    btnWid := 130
    txtWid := 360
    lstWid := 545
    If (PrefsLargeFonts=1)
    {
       lstWid := lstWid + 230
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    Gui, Add, ListView, x15 y15 w%lstWid% r12 Grid vLViewMetaD, Property|Data
    Gui, Add, Button, xs+0 y+20 h30 w40 gInfoBtnPrevImg, <<
    Gui, Add, Button, x+5 hp wp gInfoBtnNextImg, >>
    Gui, Add, Button, x+15 hp w%btnWid% gcopyIMGinfos2clip, &Copy to clipboard
    Gui, Add, Button, x+5 hp w%btnWid% gOpenThisFileFolder, &Open in folder
    Gui, Add, Button, x+5 hp w90 Default gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, Image metadata: %appTitle%
    PopulateImgInfos()
}

InfoBtnNextImg() {
  If (maxFilesIndex<2 || !maxFilesIndex)
     Return

  NextPicture()
  Sleep, 1
  PopulateImgInfos()
}

InfoBtnPrevImg() {
  If (maxFilesIndex<2 || !maxFilesIndex)
     Return

  PreviousPicture()
  Sleep, 1
  PopulateImgInfos()
}

copyIMGinfos2clip() {
   Gui, SettingsGUIA: ListView, LViewMetaD
   aR := aC := 0
   Loop
   {
       aC++
       If (aC>2)
       {
          aR++
          aC := 1
       }
       LV_GetText(valu, aR, aC)
       delimu := (aC=1) ? ": " : "`n"
       textu .= valu delimu
       Sleep, 1
       ; ToolTip, %valu% -- %aC% -- %aR%
       If (valu="" && A_Index>95)
          Break
   }

   If StrLen(textu)>10
   {
      Try Clipboard := textu
      showTOOLtip("File details copied to the clipboard...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

PopulateImgInfos() {
   Gui, SettingsGUIA: ListView, LViewMetaD
   LV_Delete()
   resultu := resultedFilesList[currentFileIndex]
   If !FileExist(resultu)
   {
      informUserFileMissing()
      Return
   }
   FileGetSize, FileSizu, % resultu, K
   FileGetTime, FileDateM, % resultu, M
   FileGetTime, FileDateC, % resultu, C
   FormatTime, FileDateM, % FileDateM, dddd, d MMMM yyyy, HH:mm:ss
   FormatTime, FileDateC, % FileDateC, dddd, d MMMM yyyy, HH:mm:ss

   zPlitPath(resultu, 0, fileNamu, folderu)
   changeMcursor()
   thumbBMP := LoadBitmapFromFileu(resultu, 1)
   rawFmt := Gdip_GetImageRawFormat(thumbBMP)
   imageLoadedWithFIF := (rawFmt="MEMORYBMP") ? 1 : 0

   If thumbBMP
      Gdip_GetImageDimensions(thumbBMP, Width, Height)

   Zoomu := Round(zoomLevel*100)
   generalInfos := "File name||" fileNamu "`nLocation||" folderu "\`nFile size||" fileSizu " kilobytes`nDate created||" FileDateC "`nDate modified||" FileDateM "`nResolution (W x H)||" Width " x " Height " (in pixels)`nCurrent zoom level||" zoomu " % (" DefineImgSizing() ")"
   Loop, Parse, generalInfos, `n
   {
       lineArru := StrSplit(A_LoopField, "||")
       LV_Add(A_Index, lineArru[1], lineArru[2])
   }

   LV_Add(A_Index, "Colors display mode", DefineFXmodes())
   If !thumbBMP
      Return

   Gdip_GetHistogram(gdiBitmap, 2, ArrChR, ArrChG, ArrChB)
   Loop, 256
   {
       sumTotalR += ArrChR[A_Index] * A_Index
       sumTotalG += ArrChG[A_Index] * A_Index
       sumTotalB += ArrChB[A_Index] * A_Index
   }
   diffRGBtotal := maxU(sumTotalR, sumTotalG, sumTotalB) - minU(sumTotalR, sumTotalG, sumTotalB)
   diffRGBtotal := diffRGBtotal/maxU(sumTotalR, sumTotalG, sumTotalB)
   If (diffRGBtotal<0.0001 || diffRGBtotal="")
      LV_Add(A_Index, "Grayscale image", 1)
   Else
      LV_Add(A_Index, "Grayscale image", 0)

   If (imageLoadedWithFIF=0)
   {
      pixFmt := Gdip_GetImagePixelFormat(thumbBMP, 2)
      LV_Add(A_Index, "Image file format", rawFmt)
      LV_Add(A_Index, "Image pixel format", pixFmt)
 
      If RegExMatch(resultu, "i)(.\.(gif|tif|tiff))$")
      {
         CountFrames := Gdip_GetBitmapFramesCount(thumbBMP)
         LV_Add(A_Index, "Embedded frames", CountFrames)
      }

      MoreProperties := Gdip_GetAllPropertyItems(thumbBMP)
      For ID, Val In MoreProperties
      {
         If ID Is Integer
         {
            PropName := Gdip_GetPropertyTagName(ID)
            PropType := Gdip_GetPropertyTagType(Val.Type)
            If (val.value && StrLen(PropName)>1 && PropName!="unknown" && PropType!="undefined" && PropType!="byte")
            {
               If (InStr(PropName, "nancetable") || InStr(PropName, "jpeg") || InStr(PropName, "thumbnail")
               || InStr(PropName, "printflag") || InStr(PropName, "strip") || InStr(PropName, "chromatic"))
                  Continue
 
               If (PropName="frame delay") || (PropName="bits per sample")
               {
                  valu := SubStr(Val.Value, 1, InStr(Val.Value, A_Space))
                  LV_Add(A_Index, PropName, valu)
               } Else LV_Add(A_Index, PropName, Val.Value)
            }
         }
      }
      LV_Add(A_Index, "Image loaded with ", "GDI+")
   } Else
   {
      If (FIMformat=34)
         LV_Add(A_Index, "Camera RAW file format", 1)
      LV_Add(A_Index, "Image pixel format", FIMimgBPP)
      LV_Add(A_Index, "Image loaded with ", "FreeImage Library v" FreeImage_GetVersion())
   }

   If thumbBMP
      Gdip_DisposeImage(thumbBMP, 1)

   Loop, 2
       LV_ModifyCol(A_Index, "AutoHdr Left")
}

FileRexists(filePath) {
   FileGetSize, fileSizu, % filePath
   fileAttribs := FileExist(filePath)
   If (!fileAttribs || InStr(fileAttribs, "D") || fileSizu<512 || !FileSizu)
      Return 0
   Else
      Return 1

}

testFileExistence(imgPath) {
  ; https://docs.microsoft.com/en-us/windows/desktop/api/fileapi/nf-fileapi-getfilesize
  ; H := DllCall("kernel32\GetFileAttributesW", "Str", imgPath)
  ; H := DllCall("shlwapi.dll\PathFileExistsW", "Str", imgPath)
  ; If (h>0)
  ;    Return 256
  VarSetCapacity(dummy, 1024, 0)
  H := DllCall("kernel32\FindFirstFileW", "Str", imgPath, "Ptr", &dummy, "Ptr")
  Return H
}

informUserFileMissing() {
   Critical, on
   imgpath := resultedFilesList[currentFileIndex]
   zPlitPath(imgpath, 0, fileNamu, folderu)
   showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
   winTitle := "[*] " currentFileIndex "/" maxFilesIndex " | " fileNamu " | " folderu
   WinSetTitle, ahk_id %PVhwnd%,, % winTitle
   SoundBeep, 300, 50
   If (autoRemDeadEntry=1)
      remCurrentEntry(0, 1)
   If (thumbsDisplaying=1 && maxFilesIndex>0)
      mainGdipWinThumbsGrid()

   SetTimer, RemoveTooltip, % -msgDisplayTime
}

JEE_StrRegExLiteral(vText) {
  vOutput := ""
  VarSetCapacity(vOutput, StrLen(vText)*2*2)

  Loop, Parse, vText
  {
    If InStr("\.*?+[{()^$", A_LoopField)
      vOutput .= "\" A_LoopField
    Else
      vOutput .= A_LoopField
  }

  Return vOutput
}

FiltersComboAction() {
  If (A_GuiControlEvent="DoubleClick")
     ApplyPanelFilter()
}

readRecentFiltersEntries() {
   testFilteru := StrReplace(usrFilesFilteru, "&")
   entriesList .= StrLen(usrFilesFilteru)>1 ? "--={ no filter }=--`n" : ""
   Loop, 20
   {
       IniRead, newEntry, % mainSettingsFile, RecentFilters, E%A_Index%, @
       If (newEntry="--={ no filter }=--")
          Continue
       addSel := (Trim(newEntry)=Trim(testFilteru)) ? "`n" : ""
       If StrLen(newEntry)>1
          entriesList .= Trim(newEntry) "`n" addSel
   }
   Return entriesList
}

EraseFilterzHisto() {
  IniDelete, % mainSettingsFile, RecentFilters
  CloseWindow()
  Sleep, 50
  enableFilesFilter()
}

enableFilesFilter() {
    Global UsrEditFilter
    If (maxFilesIndex<3 && !usrFilesFilteru)
       Return

    createSettingsGUI(6)
    btnWid := 80
    txtWid := 360
    EditWid := 399
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 200
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    listu := readRecentFiltersEntries()
    If (!InStr(listu, "`n`n") && StrLen(usrFilesFilteru)>1)
       listu := usrFilesFilteru "`n`n" listu

    Gui, +Delimiter`n
    Gui, Add, Text, x15 y15 w%txtWid%, Type a string to filter file names and/or paths.
    Gui, Add, ComboBox, y+10 w%EditWid% r7 gFiltersComboAction Simple vUsrEditFilter, % listu
    Gui, Add, Text, y+7 w%txtWid%, Tip: you can begin the string with \> to use RegEx.

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gApplyPanelFilter, &Apply filter
    Gui, Add, Checkbox, x+5 hp Checked%UsrMustInvertFilter% vUsrMustInvertFilter, Invert filter
    Gui, Add, Button, x+35 hp w%btnWid% gEraseFilterzHisto, Erase &history
    Gui, Add, Button, x+5 hp w85 gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, Files list filtering: %appTitle%
}

ApplyPanelFilter() {
   GuiControlGet, UsrEditFilter
   GuiControlGet, UsrMustInvertFilter
   CloseWindow()
   Sleep, 2
   UsrEditFilter := Trim(UsrEditFilter)
   UsrEditFilter := Trim(UsrEditFilter, "|")
   UsrEditFilter := StrReplace(UsrEditFilter, "||", "|")
   UsrEditFilter := StrReplace(UsrEditFilter, "&")
   RecentFiltersManager(UsrEditFilter)

   If (UsrMustInvertFilter=1 && StrLen(UsrEditFilter)>0)
      UsrEditFilter := "&" UsrEditFilter

   If InStr(UsrEditFilter, "{ no filter }")
      UsrEditFilter := ""
   coreEnableFiltru(UsrEditFilter)
}

RecentFiltersManager(entry2add) {
  entry2add := Trim(entry2add)
  mainListu := readRecentFiltersEntries()
  If (StrLen(entry2add)<3 || InStr(entry2add, "{ no filter }"))
     Return

  Loop, Parse, mainListu, `n
  {
      If (A_LoopField=entry2add)
         Continue
      Else
         renewList .= A_LoopField "`n"
  }

  mainListu := entry2add "`n" renewList
  Loop, Parse, mainListu, `n
  {
      If (A_Index>20)
         Break

      If StrLen(A_LoopField)<3
         Continue
      countItemz++
      IniWrite, % A_LoopField, % mainSettingsFile, RecentFilters, E%countItemz%
  }
}

triggerOwnDialogs() {
  If AnyWindowOpen
     Gui, SettingsGUIA: +OwnDialogs
  Else
     Gui, 1: +OwnDialogs
}

coreEnableFiltru(stringu) {
  backCurrentSLD := CurrentSLD
  markedSelectFile := CurrentSLD := ""
  friendly := (StrLen(stringu)>1) ? "Applying filter on the list of files, please wait...`n" stringu : "Deactivating the files list filter, please wait..."
  showTOOLtip(friendly)
  If StrLen(filesFilter)<2
  {
     bckpResultedFilesList := []
     bckpResultedFilesList := resultedFilesList.Clone()
     bkcpMaxFilesIndex := maxFilesIndex
  }
  usrFilesFilteru := stringu
  testRegEx := SubStr(stringu, 1, 2)

  If (testRegEx!="\>")
     filesFilter := JEE_StrRegExLiteral(stringu)
  Else
     filesFilter := SubStr(stringu, 3)
  filesFilter := StrReplace(filesFilter, "&")
;    MsgBox, % "Z " filesFilter
  FilterFilesIndex()
  If (maxFilesIndex<1)
  {
     triggerOwnDialogs()
     MsgBox,, %appTitle%, No files matched your filtering criteria:`n%usrFilesFilteru%`n`nThe application will now restore the full list of files.
     usrFilesFilteru := filesFilter := ""
     FilterFilesIndex()
  }
  If (maxFilesIndex>0)
     RandomPicture()
  SoundBeep, 950, 100
  SetTimer, RemoveTooltip, % -msgDisplayTime
  CurrentSLD := backCurrentSLD
}

FilterFilesIndex() {
    newFilesList := []
    newMappingList := []
    filteredMap2mainList := []
    filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
    Loop, % bkcpMaxFilesIndex + 1
    {
        r := bckpResultedFilesList[A_Index]
        If (InStr(r, "||") || !r)
           Continue

        thisIndex++
        If StrLen(filesFilter)>1
        {
           z := filterCoreString(r, filterBehaviour, filesFilter)
           If (z=1)
              Continue
        }
        newFilesIndex++
        newFilesList[newFilesIndex] := r
        If StrLen(filesFilter)>1
           newMappingList[newFilesIndex] := thisIndex
   }
   renewCurrentFilesList()
   If StrLen(filesFilter)>1
      filteredMap2mainList := newMappingList.Clone()
   resultedFilesList := newFilesList.Clone()
   maxFilesIndex := newFilesIndex
   newFilesList := []
   newMappingList := []
   GenerateRandyList()
}

throwMSGwriteError() {
  Static lastInvoked := 1
  If (ErrorLevel=1)
  {
     SoundBeep, 300, 900
     triggerOwnDialogs()
     MsgBox, 16, %appTitle%: ERROR, Unable to write or access the files: permission denied...
     lastInvoked := A_TickCount
  }
}

InListMultiEntriesRemover() {
   filesElected := getSelectedFiles()
   If (filesElected>1)
      itsMultiFiles := 1
   Else
      remCurrentEntry(0, 0)

   If (itsMultiFiles!=1)
   {
      markedSelectFile := thumbSelFileList := ""
      Return
   }

   If (filesElected>500)
   {
      triggerOwnDialogs()
      MsgBox, 52, %appTitle%, Are you sure you want to remove %filesElected% entries from the slideshow files list?
      IfMsgBox, Yes
        good2go := 1

      If (good2go!=1)
         Return
   }

   startPoint := getSelectedFiles(1)
   showTOOLtip("Removing " filesElected " index entries, please wait...")
   prevMSGdisplay := A_TickCount
   prevStartIndex := -1
   prevMaxy := maxFilesIndex

   Loop, % filesElected
   {
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Removing " A_Index "/" filesElected " index entries, please wait...")
         prevMSGdisplay := A_TickCount
      }
      thisFileIndex := getSelectedFiles(A_Index)
      resultedFilesList[thisFileIndex] := ""
      changeMcursor()
      If StrLen(filesFilter)>1
      {
         z := filteredMap2mainList[thisFileIndex]
         bckpResultedFilesList[z] := ""
      }
   }

   markedSelectFile := thumbSelFileList := ""
   If StrLen(filesFilter)>1
   {
      showTOOLtip("Updating index for the applied filter, please wait...`n" usrFilesFilteru)
      FilterFilesIndex()
   } Else
   {
      dummy := resultedFilesList.Clone()
      renewCurrentFilesList()
      Loop, % prevMaxy
      {
         changeMcursor()
         line := dummy[A_Index]
         If (StrLen(line)<4 || InStr(line, "||"))
            Continue

         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := line
      }
      GenerateRandyList()
   }

   markedSelectFile := thumbSelFileList := ""
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   showTOOLtip(filesElected " index entries removed...")
   If (maxFilesIndex<1)
   {
      GdipCleanMain(1)
      If StrLen(filesFilter)>1
      {
         showTOOLtip("Removing files list index filter, please wait...")
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
         RandomPicture()
      } Else
      {
         triggerOwnDialogs()
         MsgBox,, %appTitle%, No files left in the index, please (re)open a file or folder.
         resetMainWin2Welcome()
      }
   } Else
   {
      startPoint--
      If (startPoint<2)
         startPoint := 1
      currentFileIndex := startPoint
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
   }

   SoundBeep , 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

remCurrentEntry(dummy, silentus:=0, batchMode:=0, whichIndex:=0) {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   prevStartIndex := -1
   thisFileIndex := !whichIndex ? currentFileIndex : whichIndex
   file2remA := resultedFilesList.RemoveAt(thisFileIndex)
   file2rem := StrReplace(file2remA, "||")
   maxFilesIndex--
   If StrLen(filesFilter)>1
   {
      z := detectFileIDbkcpList(file2remA)
      If (z="fail")
         z := detectFileIDbkcpList(file2rem)
      If (z!="fail" && z>=1)
      {
         y := bckpResultedFilesList.RemoveAt(z)
         bkcpMaxFilesIndex--
      }
   }

   If (batchMode=1)
      Return

   zPlitPath(file2rem, 0, OutFileName, OutDir)
   If (silentus!=1)
      showTOOLtip("Index entry removed...`n" OutFileName "`n" OutDir "\")

   If (maxFilesIndex<1)
   {
      GdipCleanMain(1)
      If StrLen(filesFilter)>1
      {
         showTOOLtip("Removing files list index filter, please wait...")
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
         RandomPicture()
      } Else
      {
         triggerOwnDialogs()
         MsgBox,, %appTitle%, No files left in the index, please (re)open a file or folder.
         resetMainWin2Welcome()
      }
   } Else 
   {
      currentFileIndex--
      NextPicture()
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

WritePrefsIntoSLD() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   triggerOwnDialogs()
   FileSelectFile, file2save, S3, % CurrentSLD, Save slideshow settings into file..., Slideshow (*.sld)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If !RegExMatch(file2save, "i)(.\.sld)$")
         file2save .= ".sld"

      FileReadLine, firstLine, % file2save, 1
      If InStr(firstLine, "[General]")
      {
         IniWrite, % (SLDcacheFilesList=1) ? "Yes" : "Nope", % file2save, General, UseCachedList
         Sleep, 10
         writeSlideSettings(file2save)
      } Else 
      {
         triggerOwnDialogs()
         MsgBox, 64, %appTitle%: Save slideshow settings error, The selected file appears not to have the correct file format.`nPlease select a .SLD file already saved by this application.
      }
   }

}

SaveFilesList() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(maxFilesIndex)>1
   {
      triggerOwnDialogs()
      If StrLen(filesFilter)>1
         MsgBox, 64, %appTitle%: Save slideshow, The files list is filtered down to %maxFilesIndex% files from %bkcpMaxFilesIndex%.`n`nTo save as a slideshow the entire list of files, remove the filter.
      FileSelectFile, file2save, S2, % CurrentSLD, Save files list as Slideshow, Slideshow (*.sld)
   } Else Return

   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If !RegExMatch(file2save, "i)(.\.sld)$")
         file2save .= ".sld"
      If FileExist(file2save)
      {
         zPlitPath(file2save, 0, OutFileName, OutDir)
         MsgBox, 52, %appTitle%, Are you sure you want to overwrite selected file?`n`n%OutFileName%
         IfMsgBox, Yes
         {
            Try FileSetAttrib, -R, %file2save%
            Sleep, 1
            If (file2save=CurrentSLD)
            {
               newTmpFile := file2save "-bkcp"
               FileMove, %file2save%, %newTmpFile%, 1
            } Else FileDelete, %file2save%
            throwMSGwriteError()
         } Else
         {
            SaveFilesList()
            Return
         }
      }
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      Sleep, 2
      triggerOwnDialogs()
      MsgBox, 52, %appTitle%, Do you want to store the current slideshow settings as well ?
      IfMsgBox, Yes
         IniWrite, Nope, % file2save, General, IgnoreThesePrefs
      Else
         IniWrite, Yes, % file2save, General, IgnoreThesePrefs
      
      IniWrite, % (SLDcacheFilesList=1) ? "Yes" : "Nope", % file2save, General, UseCachedList
      Sleep, 10
      writeSlideSettings(file2save)
      WinSetTitle, ahk_id %PVhwnd%,, Saving slideshow - please wait...
      showTOOLtip("Saving list of " maxFilesIndex " entries into...`n" file2save "`nPlease wait...")

      thisTmpFile := !newTmpFile ? backCurrentSLD : newTmpFile
      saveDynaFolders := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(thisTmpFile) : DynamicFoldersList
      Sort, saveDynaFolders, UD`n
      dynaFolderListu := "`n[DynamicFolderz]`n"
      Loop, Parse, saveDynaFolders, `n
      {
          fileTest := StrReplace(A_LoopField, "|")
          If (StrLen(A_LoopField)<4 || !FileExist(fileTest))
             Continue
          countDynas++
          dynaFolderListu .= "DF" countDynas "=" A_LoopField "`n"
          changeMcursor()
      }

      If (SLDcacheFilesList=0)
         ForceRegenStaticFolders := mustGenerateStaticFolders := 0

      Loop, % maxFilesIndex + 1
      {
          If (SLDcacheFilesList=0)
             Continue

          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r)
             Continue

          changeMcursor()
          If (mustGenerateStaticFolders=1 || ForceRegenStaticFolders=1)
          {
             zPlitPath(r, 1, irrelevantVar, OutDir)
             foldersList .= OutDir "`n"
          }
          filesListu .= r "`n"
      }

      changeMcursor()
      Sort, foldersList, U D`n
      foldersListu := "`n[Folders]`n"
      If (mustGenerateStaticFolders=1 || ForceRegenStaticFolders=1)
      {
         ForceRegenStaticFolders := 0
         Loop, Parse, foldersList, `n
         {
             If !A_LoopField
                Continue

             FileGetTime, dirDate, % A_LoopField, M
             foldersListu .= "Fi" A_Index "=" dirDate "*&*" A_LoopField "`n"
             changeMcursor()
         }
      } Else If (SLDcacheFilesList=1)
      {
         thisTmpFile := !newTmpFile ? backCurrentSLD : newTmpFile
         foldersListu .= LoadStaticFoldersCached(thisTmpFile, irrelevantVar)
      }
      foldersListu .= "`n[FilesList]`n"
      Sleep, 10
      changeMcursor()
      FileAppend, % dynaFolderListu, % file2save, UTF-16
      Sleep, 10
      changeMcursor()
      FileAppend, % foldersListu, % file2save, UTF-16
      Sleep, 10
      changeMcursor()
      FileAppend, % filesListu, % file2save, UTF-16
      throwMSGwriteError()
      FileDelete, % newTmpFile
      SetTimer, RemoveTooltip, % -msgDisplayTime
      CurrentSLD := file2save
      DynamicFoldersList := "|hexists|"
      mustGenerateStaticFolders := 0
      SoundBeep, 900, 100
      Try DllCall("user32\SetCursor", "Ptr", hCursN)
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
   }
}

LoadStaticFoldersCached(fileNamu, ByRef countStaticFolders) {
    countStaticFolders := 0
    If StrLen(newStaticFoldersListCache)>5
    {
       Loop, Parse, newStaticFoldersListCache,`n,`r
          countStaticFolders++
       Return newStaticFoldersListCache
    }

    FileRead, tehFileVar, %fileNamu%
    Loop, Parse, tehFileVar,`n,`r
    {
       line := Trim(A_LoopField)
       If (RegExMatch(line, "i)^(Fi[0-9].*\=.*\*\&\*[a-z]\:\\..)") && !RegExMatch(line, RegExFilesPattern))
       {
          countStaticFolders++
          staticFoldersListCache .= line "`n"
          changeMcursor()
       }
    }
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    Return staticFoldersListCache
}

cleanFilesList(noFilesCheck:=0) {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   WnoFilesCheck := (noFilesCheck=2) ? 2 : 0
   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      markedSelectFile := CurrentSLD := ""
      filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
      If StrLen(filesFilter)>1
      {
         showTOOLtip("Preparing the files list...")
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      WinSetTitle, ahk_id %PVhwnd%,, Cleaning files list - please wait...
      showTOOLtip("Preparing the files list, please wait...")
      prevMSGdisplay := A_TickCount
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r)
             Continue

          changeMcursor()
          If StrLen(backfilesFilter)>1
          {
             z := filterCoreString(r, filterBehaviour, backfilesFilter)
             noFilesCheck := (z=1) ? 2 : WnoFilesCheck
          }

          If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
          {
             lastLongOperationAbort := A_TickCount
             executingCanceableOperation := mustAbandonCurrentOperations := 0
             abandonAll := 1
             Break
          }

          countTFilez++
          executingCanceableOperation := A_TickCount
          If (noFilesCheck!="2")
          {
             If (A_TickCount - prevMSGdisplay>3000)
             {
                showTOOLtip("Checking for dead files... " countTFilez "/" maxFilesIndex ", please wait...")
                prevMSGdisplay := A_TickCount
             }
             If (testFileExistence(r)>100)  ; If FileExist(r)
                filesListu .= r "`n"
          } Else filesListu .= r "`n"
      }

      If (abandonAll=1)
      {
         showTOOLtip("Operation aborted. Files list unchanged.")
         SetTimer, RemoveTooltip, % -msgDisplayTime
         CurrentSLD := backCurrentSLD
         SoundBeep, 950, 100
         Try DllCall("user32\SetCursor", "Ptr", hCursN)
         RandomPicture()
         Return
      }
      If (A_TickCount - prevMSGdisplay>1500)
         showTOOLtip("Removing duplicates from the list, please wait...")
      changeMcursor()
      Sort, filesListu, U D`n
      renewCurrentFilesList()
      Loop, Parse, filesListu,`n
      {
          If StrLen(A_LoopField)<2
             Continue

          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := A_LoopField
      }

      prevStartIndex := -1
      If StrLen(backfilesFilter)>1
      {
         bckpResultedFilesList := []
         bckpResultedFilesList := resultedFilesList.Clone()
         bkcpMaxFilesIndex := maxFilesIndex
         usrFilesFilteru := backusrFilesFilteru
         filesFilter := backfilesFilter
         FilterFilesIndex()
      } Else GenerateRandyList()

      Try DllCall("user32\SetCursor", "Ptr", hCursN)
      RandomPicture()
      CurrentSLD := backCurrentSLD
      SoundBeep, 950, 100
      Sleep, 25
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

ActSortName() {
   cleanFilesList(2)
}

ActSortSize() {
   SortFilesList("size")
}

ActSortModified() {
   SortFilesList("modified")
}

ActSortCreated() {
   SortFilesList("created")
}

ActSortResolution() {
   SortFilesList("image-resolution")
}

ActSortimgW() {
   SortFilesList("image-width")
}

ActSortimgH() {
   SortFilesList("image-height")
}

ActSortImgWHratio() {
   SortFilesList("image-wh-ratio")
}


ActSortHistogramAvg() {
   triggerOwnDialogs()
   msgInfos := (userimgQuality=1) ? "`n`nFor faster processing, please disable «High-quality resampling»." : ""
   MsgBox, 52, %appTitle%, This operation can take a lot of time. Each file will be read to determine its luminance histogram average value.`n`nAre you sure you want to sort the list? %msgInfos%
   IfMsgBox, Yes
        SortFilesList("histogramAvg")
}

ActSortHistogramMedian() {
   triggerOwnDialogs()
   msgInfos := (userimgQuality=1) ? "`n`nFor faster processing, please disable «High-quality resampling»." : ""
   MsgBox, 52, %appTitle%, This operation can take a lot of time. Each file will be read to determine its luminance histogram median value.`n`nAre you sure you want to sort the list? %msgInfos%
   IfMsgBox, Yes
        SortFilesList("histogramMedian")
}

ActSortSimilarity() {
   triggerOwnDialogs()
   MsgBox, 52, %appTitle%, This operation can take *A LOT* of time. Each file will be compared with the currently selected one.`n`nAre you sure you want to sort the list?
   IfMsgBox, Yes
        SortFilesList("similarity")
}

SortFilesList(SortCriterion) {
   Critical, on
   If AnyWindowOpen
      CloseWindow()

   If (maxFilesIndex>1)
   {
      imageLoading := 1
      prevImgPath := resultedFilesList[currentFileIndex]
      WinSetTitle, ahk_id %PVhwnd%,, Sorting files list - please wait...
      showTOOLtip("Gathering information for " maxFilesIndex " files, please wait...")
      If (SortCriterion="similarity")
      {
         img2Compare := resultedFilesList[currentFileIndex]
         oBitmap := LoadBitmapFromFileu(img2Compare)
         If !oBitmap
         {
            imageLoading := 0
            MsgBox, 48, %appTitle%, ERROR: The selected file seems to not exist or it has an incorrect image format. Please try again with another file.
            Return -1
         }

         Gdip_GetImageDimensions(oBitmap, oImgW, oImgH)
         o_picRatio := Round(oImgW/oImgH, 3)
         zBitmap := Gdip_ResizeBitmap(oBitmap, 250, 250, 1, 7)
         gBitmap := Gdip_BitmapConvertGray(zBitmap)

         o_thisHistoAvg := calcHistoAvgFile(zBitmap, "histogram", 3)
         oBitmap := Gdip_DisposeImage(oBitmap, 1)
         Gdip_GetImageDimensions(zBitmap, rImgW, rImgH)
      }

      backCurrentSLD := CurrentSLD
      markedSelectFile := CurrentSLD := ""
      If StrLen(filesFilter)>1
      {
         triggerOwnDialogs()
         MsgBox, 64, %appTitle%: Sort operation, The files list is filtered down to %maxFilesIndex% files from %bkcpMaxFilesIndex%. Only the files matched by current filter will be sorted, not all the files.`n`nTo sort all files, remove the filter.
         filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
         showTOOLtip("Preparing the files list, please wait...")
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      thisImgQuality := (userimgQuality=1) ? 7 : 3
      prevMSGdisplay := A_TickCount
      startOperation := A_TickCount
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r)
             Continue

          changeMcursor()
          If StrLen(backfilesFilter)>1
          {
             z := filterCoreString(r, filterBehaviour, backfilesFilter)
             If (z=1)
             {
                notSortedFilesListu .= r "`n"
                Continue
             }
          }

          countTFilez++
          executingCanceableOperation := A_TickCount
          If (A_TickCount - prevMSGdisplay>3000)
          {
             zeitOperation := A_TickCount - startOperation
             percDone := Round((A_Index / maxFilesIndex) * 100) "% )"
             percLeft := (1 - A_Index / maxFilesIndex) * 100
             zeitLeft := (zeitOperation/A_Index) * maxFilesIndex - zeitOperation
             etaTime := "`nEstimated time left: " SecToHHMMSS(Round(zeitLeft/1000, 3))
             etaTime .= "`nElapsed time: " SecToHHMMSS(Round(zeitOperation/1000, 3)) " ( " percDone

             showTOOLtip("Gathering information for "  countTFilez "/" maxFilesIndex " files, please wait..." etaTime)
             prevMSGdisplay := A_TickCount
          }

          If !FileRexists(r)
             Continue

          If (SortCriterion="size")
             FileGetSize, SortBy, %r%
          Else If (SortCriterion="modified")
             FileGetTime, SortBy, %r%, M
          Else If (SortCriterion="created")
             FileGetTime, SortBy, %r%, C
          Else If InStr(SortCriterion, "image-")
          {
             op := GetImgFileDimension(r, Wi, He)
             If InStr(SortCriterion, "-resolution")
                SortBy := (op=1) ? Round(Wi/10 + He/10, 2) : 0
             Else If InStr(SortCriterion, "-width")
                SortBy := (op=1) ? Round(Wi/10, 2) : 0
             Else If InStr(SortCriterion, "-height")
                SortBy := (op=1) ? Round(He/10, 2) : 0
             Else If InStr(SortCriterion, "-wh-ratio")
                SortBy := (op=1) ? Round(Wi/He, 3) : 0
          } Else If (SortCriterion="similarity")
          {
             op := GetImgFileDimension(r, Wi, He)
             PicRatio := Round(Wi/He, 3)
             If valueBetween(PicRatio, o_picRatio + 0.4, o_picRatio - 0.4)
             {
                thisHistoAvg := 0.001
                oBitmap := LoadBitmapFromFileu(r)
                If oBitmap
                {
                   xBitmap := Gdip_ResizeBitmap(oBitmap, rImgW, rImgH, 0, thisImgQuality)
                   thisHistoAvg := calcHistoAvgFile(xBitmap, "histogram", 3)
                }

                ; ToolTip, % o_thisHistoAvg "--" thisHistoAvg, , , 2
                If !valueBetween(thisHistoAvg, o_thisHistoAvg + 45, o_thisHistoAvg - 45)
                {
                   oBitmap := Gdip_DisposeImage(oBitmap, 1)
                   xBitmap := Gdip_DisposeImage(xBitmap, 1)
                }
             }

             If oBitmap
             {
                oBitmap := Gdip_DisposeImage(oBitmap, 1)
                lBitmap := Gdip_BitmapConvertGray(xBitmap)
                SortByA := 100 - Gdip_CompareBitmaps(zBitmap, xBitmap, 100)
                SortByB := 100 - Gdip_CompareBitmaps(gBitmap, lBitmap, 100)
                SortBy := (SortByA + SortByB)/2
                Gdip_DisposeImage(xBitmap, 1)
                Gdip_DisposeImage(lBitmap, 1)
             } Else SortBy := (op=1) ? "0.01" thisHistoAvg : 0
          } Else If InStr(SortCriterion, "histogram")
          {
             oBitmap := LoadBitmapFromFileu(r)
             If oBitmap
             {
                xBitmap := Gdip_ResizeBitmap(oBitmap, 300, 300, 1, thisImgQuality)
                SortBy := calcHistoAvgFile(xBitmap, SortCriterion, thisImgQuality)
                xBitmap := Gdip_DisposeImage(xBitmap, 1)
                oBitmap := Gdip_DisposeImage(oBitmap, 1)
             } Else SortBy := 0
          }

          If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
          {
             lastLongOperationAbort := A_TickCount
             executingCanceableOperation := mustAbandonCurrentOperations := 0
             abandonAll := 1
             Break
          }

          If StrLen(SortBy)>1
             filesListu .= SortBy " |!\!|" r "`n"
      }
      If (SortCriterion="similarity")
      {
         Gdip_DisposeImage(zBitmap, 1)
         Gdip_DisposeImage(gBitmap, 1)
      }

      If (abandonAll=1)
      {
         showTOOLtip("Operation aborted. Files list unchanged.")
         SetTimer, RemoveTooltip, % -msgDisplayTime
         CurrentSLD := backCurrentSLD
         SoundBeep, 950, 100
         imageLoading := 0
         RandomPicture()
         Try DllCall("user32\SetCursor", "Ptr", hCursN)
         Return
      }

      showTOOLtip("Sorting gathered data...")
      prevMSGdisplay := A_TickCount
      changeMcursor()
      Sort, filesListu, N D`n

      If (A_TickCount - prevMSGdisplay>1500)
         showTOOLtip("Generating files index...")
      renewCurrentFilesList()
      Loop, Parse, filesListu,`n
      {
          If StrLen(A_LoopField)<2
             Continue
          changeMcursor()
          line := StrSplit(A_LoopField, "|!\!|")
          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := line[2]
      }

      Loop, Parse, notSortedFilesListu,`n
      {
          If StrLen(A_LoopField)<2
             Continue

          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := A_LoopField
      }

      prevStartIndex := -1
      If StrLen(backfilesFilter)>1
      {
         bckpResultedFilesList := []
         bckpResultedFilesList := resultedFilesList.Clone()
         bkcpMaxFilesIndex := maxFilesIndex
         usrFilesFilteru := backusrFilesFilteru
         filesFilter := backfilesFilter
         FilterFilesIndex()
      } Else GenerateRandyList()

      SoundBeep, 950, 100
      Sleep, 25
      SetTimer, RemoveTooltip, -500
      imageLoading := 0
      CurrentSLD := backCurrentSLD
      currentFileIndex := detectFileID(prevImgPath)
;      currentFileIndex := maxFilesIndex - 1
      IDshowImage(currentFileIndex)
   }
}

calcHistoAvgFile(xBitmap, SortCriterion, thisImgQuality) {
      Gdip_GetImageDimensions(xBitmap, cImgW, cImgH)
      Gdip_GetHistogram(xBitmap, 3, brLvlArray, 0, 0)
      TotalPixelz := cImgW * cImgH
      sumTotalBr := nrPixelz := medianValue := thisSum := 0
      lookValue := stringHistoArray := ""
      Loop, 256
      {
          thisIndex := A_Index - 1
          nrPixelz := brLvlArray[thisIndex]
          If (nrPixelz="")
             Continue

          If InStr(SortCriterion, "median")
             stringHistoArray .= (thisIndex+1) "." nrPixelz "`n"

          sumTotalBr += nrPixelz * (thisIndex+1)
      }

      If InStr(SortCriterion, "median")
      {
         Loop, 256
         {
             lookValue := ST_ReadLine(stringHistoArray, A_Index)
             lookValue := StrSplit(lookValue, ".")
             thisSum += lookValue[2]
             If (thisSum>TotalPixelz//2)
             {
                medianValue := lookValue[1] - 1
                Break
             }
         }
      }

      SortBy := InStr(SortCriterion, "median") ? medianValue ".01" : Round((sumTotalBr/TotalPixelz - 1)/2, 3)
   Return SortBy
}

readSlideSettings(readThisFile) {
     IniRead, tstslideShowDelay, %readThisFile%, General, slideShowDelay, @
     IniRead, tstIMGresizingMode, %readThisFile%, General, IMGresizingMode, @
     IniRead, tstSlideHowMode, %readThisFile%, General, SlideHowMode, @
     IniRead, tstimgFxMode, %readThisFile%, General, imgFxMode, @
     IniRead, tstWindowBgrColor, %readThisFile%, General, WindowBgrColor, @
     ; IniRead, tstfilesFilter, %readThisFile%, General, usrFilesFilteru, @
     IniRead, tstFlipImgH, %readThisFile%, General, FlipImgH, @
     IniRead, tstFlipImgV, %readThisFile%, General, FlipImgV, @
     IniRead, tstlumosAdjust, %readThisFile%, General, lumosAdjust, @
     IniRead, tstGammosAdjust, %readThisFile%, General, GammosAdjust, @
     IniRead, tstlumosGrAdjust, %readThisFile%, General, lumosGrayAdjust, @
     IniRead, tstGammosGrAdjust, %readThisFile%, General, GammosGrayAdjust, @
     IniRead, tstsatAdjust, %readThisFile%, General, satAdjust, @
     IniRead, tstimageAligned, %readThisFile%, General, imageAligned, @
     IniRead, tstnoTooltipMSGs, %readThisFile%, General, noTooltipMSGs, @
     IniRead, tstTouchScreenMode, %readThisFile%, General, TouchScreenMode, @
     IniRead, tstskipDeadFiles, %readThisFile%, General, skipDeadFiles, @
     IniRead, tstisAlwaysOnTop, %readThisFile%, General, isAlwaysOnTop, @
     IniRead, tstanimGIFsSupport, %readThisFile%, General, animGIFsSupport, @
     IniRead, tstisTitleBarHidden, %readThisFile%, General, isTitleBarHidden, @
     IniRead, tstthumbsAratio, %readThisFile%, General, thumbsAratio, @
     IniRead, tstthumbsZoomLevel, %readThisFile%, General, thumbsZoomLevel, @
     IniRead, tstSLDcacheFilesList, %readThisFile%, General, SLDcacheFilesList, @
     IniRead, tsteasySlideStoppage, %readThisFile%, General, easySlideStoppage, @
     IniRead, tstzatAdjust, %readThisFile%, General, zatAdjust, @
     IniRead, tsthueAdjust, %readThisFile%, General, hueAdjust, @
     IniRead, tstautoAdjustMode, %readThisFile%, General, autoAdjustMode, @
     IniRead, tstdoSatAdjusts, %readThisFile%, General, doSatAdjusts, @
     IniRead, tstrealGammos, %readThisFile%, General, realGammos, @
     IniRead, tstimgThreshold, %readThisFile%, General, imgThreshold, @
     IniRead, tstchnRdecalage, %readThisFile%, General, chnRdecalage, @
     IniRead, tstchnGdecalage, %readThisFile%, General, chnGdecalage, @
     IniRead, tstchnBdecalage, %readThisFile%, General, chnBdecalage, @
     IniRead, tstusrAdaptiveThreshold, %readThisFile%, General, usrAdaptiveThreshold, @
     IniRead, tstbwDithering, %readThisFile%, General, bwDithering, @
     IniRead, tstRenderOpaqueIMG, %readThisFile%, General, RenderOpaqueIMG, @
     IniRead, tstusrTextureBGR, %readThisFile%, General, usrTextureBGR, @
     IniRead, tstusrColorDepth, %readThisFile%, General, usrColorDepth, @
     IniRead, tstColorDepthDithering, %readThisFile%, General, ColorDepthDithering, @
     IniRead, tstautoPlaySNDs, %readThisFile%, General, autoPlaySNDs, @
     IniRead, tstsyncSlideShow2Audios, %readThisFile%, General, syncSlideShow2Audios, @
     IniRead, tstborderAroundImage, %readThisFile%, General, borderAroundImage, @

     If (tstsyncSlideShow2Audios=1 || tstsyncSlideShow2Audios=0)
        syncSlideShow2Audios := tstsyncSlideShow2Audios
     If (tstborderAroundImage=1 || tstborderAroundImage=0)
        borderAroundImage := tstborderAroundImage
     If (tstautoPlaySNDs=1 || tstautoPlaySNDs=0)
        autoPlaySNDs := tstautoPlaySNDs
     If (tstusrTextureBGR=1 || tstusrTextureBGR=0)
        usrTextureBGR := tstusrTextureBGR
     If (tstColorDepthDithering=1 || tstColorDepthDithering=0)
        ColorDepthDithering := tstColorDepthDithering
     If valueBetween(tstusrColorDepth, 0, 9)
        usrColorDepth := tstusrColorDepth
     If (tstRenderOpaqueIMG=1 || tstRenderOpaqueIMG=0)
        RenderOpaqueIMG := tstRenderOpaqueIMG
     If (tstslideshowdelay!="@" && tstslideshowdelay>90)
        slideShowDelay := tstslideShowDelay
     If (tstimgresizingmode!="@" && StrLen(tstIMGresizingMode)=1 && tstIMGresizingMode<5)
        IMGresizingMode := tstIMGresizingMode
     If (tstimgFxMode!="@" && valueBetween(tstimgFxMode, 1, 8))
        imgFxMode := tstimgFxMode
     If (tstautoAdjustMode!="@" && valueBetween(tstautoAdjustMode, 1, 3))
        autoAdjustMode := tstautoAdjustMode
     If (tstnoTooltipMSGs=1 || tstnoTooltipMSGs=0)
        noTooltipMSGs := tstnoTooltipMSGs
     If (tstSLDcacheFilesList=1 || tstSLDcacheFilesList=0)
        SLDcacheFilesList := tstSLDcacheFilesList
     If (tstbwDithering=1 || tstbwDithering=0)
        bwDithering := tstbwDithering
     If (tstTouchScreenMode=1 || tstTouchScreenMode=0)
        TouchScreenMode := tstTouchScreenMode
     If (tstdoSatAdjusts=1 || tstdoSatAdjusts=0)
        doSatAdjusts := tstdoSatAdjusts
     If (tsteasySlideStoppage=1 || tsteasySlideStoppage=0)
        easySlideStoppage := tsteasySlideStoppage
     If (tstFlipImgH=1 || tstFlipImgH=0)
        FlipImgH := tstFlipImgH
     If (tstFlipImgV=1 || tstFlipImgV=0)
        FlipImgV := tstFlipImgV
     If (tstskipDeadFiles=1 || tstskipDeadFiles=0)
        skipDeadFiles := tstskipDeadFiles
     If (tstanimGIFsSupport=1 || tstanimGIFsSupport=0)
        animGIFsSupport := tstanimGIFsSupport
     If (tstisAlwaysOnTop=1 || tstisAlwaysOnTop=0)
        isAlwaysOnTop := tstisAlwaysOnTop
     If (tstisTitleBarHidden=1 || tstisTitleBarHidden=0)
        isTitleBarHidden := tstisTitleBarHidden
     If (tstslidehowmode!="@" && valueBetween(tstSlideHowMode, 1, 3))
        SlideHowMode := tstSlideHowMode
     If (tstimageAligned!="@" && valueBetween(tstimageAligned, 1, 9))
        imageAligned := tstimageAligned
     If (tstthumbsAratio!="@" && valueBetween(tstthumbsAratio, 1, 3))
        thumbsAratio := tstthumbsAratio

     If (tstWindowBgrColor!="@" && StrLen(tstWindowBgrColor)=6)
     {
        WindowBgrColor := tstWindowBgrColor
        If (scriptInit=1)
           Gui, 1: Color, %tstWindowBgrColor%
     }
     If (tstfilesFilter!="@" && StrLen(Trim(tstfilesFilter))>2)
        usrFilesFilteru := tstfilesFilter

     If (tstchnRdecalage!="@")
        chnRdecalage := tstchnRdecalage
     If (tstchnGdecalage!="@")
        chnGdecalage := tstchnGdecalage
     If (tstchnBdecalage!="@")
        chnBdecalage := tstchnBdecalage
     If (tstlumosAdjust!="@")
        lumosAdjust := tstlumosAdjust
     If (tstGammosAdjust!="@")
        GammosAdjust := tstGammosAdjust
     If (tstrealGammos!="@" && realGammos>0)
        realGammos := tstrealGammos
     If (tstimgThreshold!="@")
        imgThreshold := tstimgThreshold
     If (tstsatAdjust!="@")
        satAdjust := tstsatAdjust
     If (tstzatAdjust!="@")
        zatAdjust := tstzatAdjust
     If (tsthueAdjust!="@")
        hueAdjust := tsthueAdjust
     If (tstusrAdaptiveThreshold!="@")
        usrAdaptiveThreshold := tstusrAdaptiveThreshold

     If (tstlumosGrAdjust!="@")
        lumosGrayAdjust := tstlumosGrAdjust
     If (tstGammosGrAdjust!="@")
        GammosGrayAdjust := tstGammosGrAdjust
     If (tstthumbsZoomLevel!="@")
        thumbsZoomLevel := tstthumbsZoomLevel

     If (isTitleBarHidden=1)
        Gui, 1: -Caption
     Else
        Gui, 1: +Caption

     defineColorDepth()
     coreChangeThumbsAratio()
     WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
}

writeMainSettings() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked < 450)
    {
       lastInvoked := A_TickCount
       SetTimer, writeMainSettings, -500
       Return
    }

    writeSlideSettings(mainSettingsFile)
    IniWrite, % MustLoadSLDprefs, % mainSettingsFile, General, MustLoadSLDprefs
    IniWrite, % prevFileMovePath, % mainSettingsFile, General, prevFileMovePath
    IniWrite, % PrefsLargeFonts, % mainSettingsFile, General, PrefsLargeFonts
    IniWrite, % prevOpenFolderPath, % mainSettingsFile, General, prevOpenFolderPath
    IniWrite, % autoRemDeadEntry, % mainSettingsFile, General, autoRemDeadEntry
    IniWrite, % askDeleteFiles, % mainSettingsFile, General, askDeleteFiles
    IniWrite, % enableThumbsCaching, % mainSettingsFile, General, enableThumbsCaching
    IniWrite, % ResizeInPercentage, % mainSettingsFile, General, ResizeInPercentage
    IniWrite, % ResizeKeepAratio, % mainSettingsFile, General, ResizeKeepAratio
    IniWrite, % ResizeQualityHigh, % mainSettingsFile, General, ResizeQualityHigh
    IniWrite, % ResizeApplyEffects, % mainSettingsFile, General, ResizeApplyEffects
    IniWrite, % ResizeRotationUser, % mainSettingsFile, General, ResizeRotationUser
    IniWrite, % ResizeCropAfterRotation, % mainSettingsFile, General, ResizeCropAfterRotation
    IniWrite, % prevFileSavePath, % mainSettingsFile, General, prevFileSavePath
    IniWrite, % alwaysOpenwithFIM, % mainSettingsFile, General, alwaysOpenwithFIM
    IniWrite, % userHQraw, % mainSettingsFile, General, userHQraw
    IniWrite, % OSDFontName, % mainSettingsFile, General, OSDFontName
    IniWrite, % FontBolded, % mainSettingsFile, General, FontBolded
    IniWrite, % FontItalica, % mainSettingsFile, General, FontItalica
    IniWrite, % OSDfntSize, % mainSettingsFile, General, OSDfntSize
    IniWrite, % PasteFntSize, % mainSettingsFile, General, PasteFntSize
    IniWrite, % OSDbgrColor, % mainSettingsFile, General, OSDbgrColor
    IniWrite, % OSDtextColor, % mainSettingsFile, General, OSDtextColor
    IniWrite, % DisplayTimeUser, % mainSettingsFile, General, DisplayTimeUser
    IniWrite, % userimgQuality, % mainSettingsFile, General, userimgQuality
    IniWrite, % usrTextAlign, % mainSettingsFile, General, usrTextAlign
    IniWrite, % relativeImgSelCoords, % mainSettingsFile, General, relativeImgSelCoords
    IniWrite, % showInfoBoxHUD, % mainSettingsFile, General, showInfoBoxHUD
    IniWrite, % showHistogram, % mainSettingsFile, General, showHistogram
    IniWrite, % mediaSNDvolume, % mainSettingsFile, General, mediaSNDvolume
    IniWrite, % OnConvertKeepOriginals, % mainSettingsFile, General, OnConvertKeepOriginals
    IniWrite, % userOverwriteFiles, % mainSettingsFile, General, userOverwriteFiles
    IniWrite, % userDesireWriteFMT, % mainSettingsFile, General, userDesireWriteFMT
    IniWrite, % ResizeUseDestDir, % mainSettingsFile, General, ResizeUseDestDir
    IniWrite, % userMultiDelChoice, % mainSettingsFile, General, userMultiDelChoice
    IniWrite, % usrAutoCropGenerateSelection, % mainSettingsFile, General, usrAutoCropGenerateSelection
    IniWrite, % usrAutoCropDeviationSnap, % mainSettingsFile, General, usrAutoCropDeviationSnap
    IniWrite, % usrAutoCropDeviationPixels, % mainSettingsFile, General, usrAutoCropDeviationPixels
    IniWrite, % doSlidesTransitions, % mainSettingsFile, General, doSlidesTransitions
    lastInvoked := A_TickCount
}

loadMainSettings() {
    readSlideSettings(mainSettingsFile)
    IniRead, tstMustLoadSLDprefs, % mainSettingsFile, General, MustLoadSLDprefs, @
    IniRead, tstprevFileMovePath, % mainSettingsFile, General, prevFileMovePath, @
    IniRead, tstprevOpenFolderPath, % mainSettingsFile, General, prevOpenFolderPath, @
    IniRead, tstPrefsLargeFonts, % mainSettingsFile, General, PrefsLargeFonts, @
    IniRead, tstaskDeleteFiles, % mainSettingsFile, General, askDeleteFiles, @
    IniRead, tstenableThumbsCaching, % mainSettingsFile, General, enableThumbsCaching, @
    IniRead, tstautoRemDeadEntry, % mainSettingsFile, General, autoRemDeadEntry, @
    IniRead, tstResizeApplyEffects, % mainSettingsFile, General, ResizeApplyEffects, @
    IniRead, tstResizeInPercentage, % mainSettingsFile, General, ResizeInPercentage, @
    IniRead, tstResizeKeepAratio, % mainSettingsFile, General, ResizeKeepAratio, @
    IniRead, tstResizeQualityHigh, % mainSettingsFile, General, ResizeQualityHigh, @
    IniRead, tstResizeRotationUser, % mainSettingsFile, General, ResizeRotationUser, @
    IniRead, tstResizeWithCrop, % mainSettingsFile, General, ResizeWithCrop, @
    IniRead, tstResizeUseDestDir, % mainSettingsFile, General, ResizeUseDestDir, @
    IniRead, tstResizeDestFolder, % mainSettingsFile, General, ResizeDestFolder, @
    IniRead, tstprevFileSavePath, % mainSettingsFile, General, prevFileSavePath, @
    IniRead, tstalwaysOpenwithFIM, % mainSettingsFile, General, alwaysOpenwithFIM, @
    IniRead, tstuserHQraw, % mainSettingsFile, General, userHQraw, @
    IniRead, tstOSDFontName, % mainSettingsFile, General, OSDFontName, @
    IniRead, tstFontBolded, % mainSettingsFile, General, FontBolded, @
    IniRead, tstFontItalica, % mainSettingsFile, General, FontItalica, @
    IniRead, tstOSDfntSize, % mainSettingsFile, General, OSDfntSize, @
    IniRead, tstPasteFntSize, % mainSettingsFile, General, PasteFntSize, @
    IniRead, tstOSDbgrColor, % mainSettingsFile, General, OSDbgrColor, @
    IniRead, tstOSDtextColor, % mainSettingsFile, General, OSDtextColor, @
    IniRead, tstDisplayTimeUser, % mainSettingsFile, General, DisplayTimeUser, @
    IniRead, tstuserimgQuality, % mainSettingsFile, General, userimgQuality, @
    IniRead, tstusrTextAlign, % mainSettingsFile, General, usrTextAlign, @
    IniRead, tstrelativeImgSelCoords, % mainSettingsFile, General, relativeImgSelCoords, @
    IniRead, tstshowInfoBoxHUD, % mainSettingsFile, General, showInfoBoxHUD, @
    IniRead, tstshowHistogram, % mainSettingsFile, General, showHistogram, @
    IniRead, tstResizeCropAfterRotation, % mainSettingsFile, General, ResizeCropAfterRotation, @
    IniRead, tstmediaSNDvolume, % mainSettingsFile, General, mediaSNDvolume, @
    IniRead, tstOnConvertKeepOriginals, % mainSettingsFile, General, OnConvertKeepOriginals, @
    IniRead, tstuserOverwriteFiles, % mainSettingsFile, General, userOverwriteFiles, @
    IniRead, tstuserDesireWriteFMT, % mainSettingsFile, General, userDesireWriteFMT, @
    IniRead, tstuserMultiDelChoice, % mainSettingsFile, General, userMultiDelChoice, @
    IniRead, tstusrAutoCropGenerateSelection, % mainSettingsFile, General, usrAutoCropGenerateSelection, @
    IniRead, tstusrAutoCropDeviationSnap, % mainSettingsFile, General, usrAutoCropDeviationSnap, @
    IniRead, tstusrAutoCropDeviationPixels, % mainSettingsFile, General, usrAutoCropDeviationPixels, @
    IniRead, tstdoSlidesTransitions, % mainSettingsFile, General, doSlidesTransitions, @

    If (tstuserDesireWriteFMT!="@")
       userDesireWriteFMT := tstuserDesireWriteFMT
    If (tstOnConvertKeepOriginals=1 || tstOnConvertKeepOriginals=0)
       OnConvertKeepOriginals := tstOnConvertKeepOriginals
    If (tstuserimgQuality=1 || tstuserimgQuality=0)
       userimgQuality := tstuserimgQuality
    imgQuality := (userimgQuality=1) ? 7 : 5

    If (tstusrTextAlign="Left" || tstusrTextAlign="Right" || tstusrTextAlign="Center")
       usrTextAlign := tstusrTextAlign
    If tstDisplayTimeUser is Number
       DisplayTimeUser := tstDisplayTimeUser
    If tstOSDfntSize is Number
       OSDfntSize := tstOSDfntSize
    If tstPasteFntSize is Number
       PasteFntSize := tstPasteFntSize
    If tstmediaSNDvolume is Number
       mediaSNDvolume := tstmediaSNDvolume
    If (tstResizeCropAfterRotation=1 || tstResizeCropAfterRotation=0)
       ResizeCropAfterRotation := tstResizeCropAfterRotation
    If (tstFontBolded=1 || tstFontBolded=0)
       FontBolded := tstFontBolded
    If (tstFontItalica=1 || tstFontItalica=0)
       FontItalica := tstFontItalica
    If (tstshowHistogram=1 || tstshowHistogram=0)
       showHistogram := tstshowHistogram
    If (tstshowInfoBoxHUD=1 || tstshowInfoBoxHUD=0)
       showInfoBoxHUD := tstshowInfoBoxHUD
    If (tstusrAutoCropGenerateSelection=1 || tstusrAutoCropGenerateSelection=0)
       usrAutoCropGenerateSelection := tstusrAutoCropGenerateSelection
    If (tstuserMultiDelChoice=1 || tstuserMultiDelChoice=2 || tstuserMultiDelChoice=3)
       userMultiDelChoice := tstuserMultiDelChoice
    If (tstdoSlidesTransitions=1 || tstdoSlidesTransitions=0)
       doSlidesTransitions := tstdoSlidesTransitions
    If (tstusrAutoCropDeviationSnap=1 || tstusrAutoCropDeviationSnap=0)
       usrAutoCropDeviationSnap := tstusrAutoCropDeviationSnap
    If (tstusrAutoCropDeviationPixels=1 || tstusrAutoCropDeviationPixels=0)
       usrAutoCropDeviationPixels := tstusrAutoCropDeviationPixels
    If (tstalwaysOpenwithFIM=1 || tstalwaysOpenwithFIM=0)
       alwaysOpenwithFIM := tstalwaysOpenwithFIM
    If (tstalwaysOpenwithFIM=1 || tstalwaysOpenwithFIM=0)
       alwaysOpenwithFIM := tstalwaysOpenwithFIM
    If (tstuserHQraw=1 || tstuserHQraw=0)
       userHQraw := tstuserHQraw
    If (tstrelativeImgSelCoords=1 || tstrelativeImgSelCoords=0)
       relativeImgSelCoords := tstrelativeImgSelCoords
    If (tstResizeInPercentage=1 || tstResizeInPercentage=0)
       ResizeInPercentage := tstResizeInPercentage
    If (tstResizeUseDestDir=1 || tstResizeUseDestDir=0)
       ResizeUseDestDir := tstResizeUseDestDir
    If (valueBetween(tstResizeRotationUser, 0, 359) && tstResizeRotationUser!="@")
       ResizeRotationUser := tstResizeRotationUser
    If (tstResizeKeepAratio=1 || tstResizeKeepAratio=0)
       ResizeKeepAratio := tstResizeKeepAratio
    If (tstResizeWithCrop=1 || tstResizeWithCrop=0)
       ResizeWithCrop := tstResizeWithCrop
    If (tstResizeQualityHigh=1 || tstResizeQualityHigh=0)
       ResizeQualityHigh := tstResizeQualityHigh
    If (tstResizeApplyEffects=1 || tstResizeApplyEffects=0)
       ResizeApplyEffects := tstResizeApplyEffects
    If (tstenableThumbsCaching=1 || tstenableThumbsCaching=0)
       enableThumbsCaching := tstenableThumbsCaching
    If (tstaskDeleteFiles=1 || tstaskDeleteFiles=0)
       askDeleteFiles := tstaskDeleteFiles
    If (tstautoRemDeadEntry=1 || tstautoRemDeadEntry=0)
       autoRemDeadEntry := tstautoRemDeadEntry
    If (tstPrefsLargeFonts=1 || tstPrefsLargeFonts=0)
       PrefsLargeFonts := tstPrefsLargeFonts
    If (tstMustLoadSLDprefs=1 || tstMustLoadSLDprefs=0)
       MustLoadSLDprefs := tstMustLoadSLDprefs
    If (StrLen(tstprevFileMovePath)>3)
       prevFileMovePath := tstprevFileMovePath
    If (StrLen(tstOSDFontName)>2)
       OSDFontName := tstOSDFontName
    If (StrLen(tstprevFileSavePath)>3)
       prevFileSavePath := tstprevFileSavePath
    If (StrLen(tstprevOpenFolderPath)>3)
       prevOpenFolderPath := tstprevOpenFolderPath
    If (StrLen(tstResizeDestFolder)>3)
       ResizeDestFolder := tstResizeDestFolder
    If (tstOSDbgrColor!="@" && StrLen(tstOSDbgrColor)=6)
       OSDbgrColor := tstOSDbgrColor
    If (tstOSDtextColor!="@" && StrLen(tstOSDtextColor)=6)
       OSDtextColor := tstOSDtextColor

    If !prevOpenFolderPath
       prevOpenFolderPath := A_WorkingDir

    If !ResizeDestFolder
    {
       If prevOpenFolderPath
          ResizeDestFolder := prevOpenFolderPath
       Else
          ResizeDestFolder := A_WorkingDir
    }

    If (OSDfntSize<9)
       OSDfntSize := 9

    SetVolume(mediaSNDvolume)
    imgHUDbaseUnit := (PrefsLargeFonts=1) ? Round(OSDfntSize*6.5) : Round(OSDfntSize*5.25)
    msgDisplayTime := DisplayTimeUser*1000
}

writeSlideSettings(file2save) {
    IniWrite, % SLDcacheFilesList, %file2save%, General, SLDcacheFilesList
    IniWrite, % IMGresizingMode, %file2save%, General, IMGresizingMode
    IniWrite, % imgFxMode, %file2save%, General, imgFxMode
    IniWrite, % SlideHowMode, %file2save%, General, SlideHowMode
    IniWrite, % slideShowDelay, %file2save%, General, slideShowDelay
    ; IniWrite, % filesFilter, %file2save%, General, filesFilter
    IniWrite, % WindowBgrColor, %file2save%, General, WindowBgrColor
    IniWrite, % FlipImgH, %file2save%, General, FlipImgH
    IniWrite, % FlipImgV, %file2save%, General, FlipImgV
    IniWrite, % usrColorDepth, %file2save%, General, usrColorDepth
    IniWrite, % ColorDepthDithering, %file2save%, General, ColorDepthDithering
    IniWrite, % lumosAdjust, %file2save%, General, lumosAdjust
    IniWrite, % GammosAdjust, %file2save%, General, GammosAdjust
    IniWrite, % lumosGrayAdjust, %file2save%, General, lumosGrayAdjust
    IniWrite, % GammosGrayAdjust, %file2save%, General, GammosGrayAdjust
    IniWrite, % satAdjust, %file2save%, General, satAdjust
    IniWrite, % imageAligned, %file2save%, General, imageAligned
    IniWrite, % doSatAdjusts, % mainSettingsFile, General, doSatAdjusts
    IniWrite, % autoAdjustMode, % mainSettingsFile, General, autoAdjustMode
    IniWrite, % chnRdecalage, % mainSettingsFile, General, chnRdecalage
    IniWrite, % chnGdecalage, % mainSettingsFile, General, chnGdecalage
    IniWrite, % chnBdecalage, % mainSettingsFile, General, chnBdecalage
    IniWrite, % usrAdaptiveThreshold, % mainSettingsFile, General, usrAdaptiveThreshold
    IniWrite, % noTooltipMSGs, %file2save%, General, noTooltipMSGs
    IniWrite, % TouchScreenMode, %file2save%, General, TouchScreenMode
    IniWrite, % skipDeadFiles, %file2save%, General, skipDeadFiles
    IniWrite, % isAlwaysOnTop, %file2save%, General, isAlwaysOnTop
    IniWrite, % bwDithering, %file2save%, General, bwDithering
    IniWrite, % RenderOpaqueIMG, %file2save%, General, RenderOpaqueIMG
    IniWrite, % zatAdjust, %file2save%, General, zatAdjust
    IniWrite, % hueAdjust, %file2save%, General, hueAdjust
    IniWrite, % realGammos, %file2save%, General, realGammos
    IniWrite, % imgThreshold, %file2save%, General, imgThreshold
    IniWrite, % isTitleBarHidden, %file2save%, General, isTitleBarHidden
    IniWrite, % animGIFsSupport, %file2save%, General, animGIFsSupport
    IniWrite, % thumbsAratio, %file2save%, General, thumbsAratio
    IniWrite, % thumbsZoomLevel, %file2save%, General, thumbsZoomLevel
    IniWrite, % easySlideStoppage, %file2save%, General, easySlideStoppage
    IniWrite, % version, %file2save%, General, version
    IniWrite, % usrTextureBGR, %file2save%, General, usrTextureBGR
    IniWrite, % syncSlideShow2Audios, %file2save%, General, syncSlideShow2Audios
    IniWrite, % autoPlaySNDs, %file2save%, General, autoPlaySNDs
    IniWrite, % borderAroundImage, %file2save%, General, borderAroundImage
    throwMSGwriteError()
}

readRecentEntries() {
   If StrLen(historyList)>4
      Return

   historyList := ""
   Loop, 15
   {
       IniRead, newEntry, % mainSettingsFile, Recents, E%A_Index%, @
       If StrLen(newEntry)>4
          historyList .= newEntry "`n"
   }
}

RecentFilesManager(dummy:=0,addPrevMoveDest:=0) {
  readRecentEntries()
  entry2add := CurrentSLD
  If (addPrevMoveDest=2)
     entry2add := prevFileMovePath

  If StrLen(entry2add)<5
     Return

  Loop, Parse, historyList, `n
  {
      If (A_LoopField=entry2add)
         Continue
      Else
         renewList .= A_LoopField "`n"
  }

  historyList := entry2add "`n" renewList
  Loop, Parse, historyList, `n
  {
      If (A_Index>15)
         Break

      If StrLen(A_LoopField)<5
         Continue
      countItemz++
      IniWrite, % A_LoopField, % mainSettingsFile, Recents, E%countItemz%
      newHistoryList .= A_LoopField "`n"
  }
  historyList := newHistoryList
}

RandomPicture(dummy:=0, inLoop:=0) {
   ; Static inLoop := 0
   If (maxFilesIndex=0 || maxFilesIndex="") && (!CurrentSLD)
      Return

   RandyIMGnow++
   If (RandyIMGnow<1)
      RandyIMGnow := maxFilesIndex
   If (RandyIMGnow>maxFilesIndex)
      RandyIMGnow := 1

   currentFileIndex := RandyIMGids[RandyIMGnow]
   endLoop := (inLoop=250) ? 250 : 0
   r := IDshowImage(currentFileIndex, endLoop)
   If (!r && inLoop<250)
   {
      inLoop++
      NextPicture(0, inLoop)
      ; RandomPicture(0, inLoop)
   } Else inLoop := 0
}

PrevRandyPicture(dummy:=0, inLoop:=0) {
   resetSlideshowTimer(0)
   RandyIMGnow--
   If (RandyIMGnow<1)
      RandyIMGnow := maxFilesIndex
   If (RandyIMGnow>maxFilesIndex)
      RandyIMGnow := 1

   currentFileIndex := RandyIMGids[RandyIMGnow]
   endLoop := (inLoop=250) ? 250 : 0
   r := IDshowImage(currentFileIndex, endLoop)
   If (!r && inLoop<250)
   {
      inLoop++
      NextPicture(0, inLoop)
      ; PrevRandyPicture(0, inLoop)
   } Else inLoop := 0
}

getSelectedFiles(getItem:=0, forceSort:=0) {
   Static prevSelFiles :="z", lastItem, totalCount, FilezArray := []

   If !markedSelectFile
      Return

   If (markedSelectFile=prevSelFiles && forceSort!=1)
   {
      If !getItem
         Return totalCount
      Else If (getItem="L")
         Return lastItem
      Else
         Return StrReplace(FilezArray[getItem], ",")
   }

   If (forceSort=1)
   {
      thumbSelFileList := ""
      changeMcursor()
      Sort, markedSelectFile, P2UND|
   }

   prevSelFiles := filesListu := markedSelectFile
   filesListu := Trim(filesListu, "|")
   FilezArray := []
   FilezArray := StrSplit(filesListu, "|")
   totalCount := FilezArray.Length()
   lastItem := StrReplace(FilezArray[FilezArray.Length()], ",")
   If (totalCount>maxFilesIndex && getItem=0 && forceSort=0)
      Return getSelectedFiles(0, 1) 

   ; ToolTip, % totalCount "--" lastItem "`n" markedSelectFile
   If !getItem
      Return totalCount
   Else If (getItem="L")
      Return lastItem
   Else
      Return StrReplace(FilezArray[getItem], ",")
}

dropFilesSelection() {
   markedSelectFile := ""
   showTOOLtip("Files selection dropped...")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   dummyTimerDelayiedImageDisplay(50)
}

MenuMarkThisFileNow() {
   markThisFileNow()
}

markThisFileNow(thisFileIndex:=0) {
  If (currentFileIndex=0  || maxFilesIndex<2 || AnyWindowOpen>0)
     Return

  If !thisFileIndex
     thisFileIndex := currentFileIndex

  thumbSelFileList := ""
  If InStr(markedSelectFile, "," thisFileIndex "|")
     markedSelectFile := StrReplace(markedSelectFile, "," thisFileIndex "|")
  Else
     markedSelectFile .=  "," thisFileIndex "|"

  If (thumbsDisplaying=1)
     mainGdipWinThumbsGrid()
  Else
     dummyTimerDelayiedImageDisplay(25)
}

CompareImagesAB() {
  Static prevImgIndex, prevIndexu
  If !markedSelectFile
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  totalCount := getSelectedFiles()
  If (!InStr(markedSelectFile, "," currentFileIndex "|") && totalCount=1)
     markedSelectFile .= "," currentFileIndex "|"
  theFirst := getSelectedFiles(1)
  theMid := getSelectedFiles(totalCount//2)
  theLast := getSelectedFiles("L")
  listu := theFirst "|" theLast
  If (totalCount>4)
     listu .= "|" theMid
  Sort, listu, UND|
  FilezArray := StrSplit(listu, "|")
  prevIndexu++
  If (prevIndexu>FilezArray.Length())
     prevIndexu := 1
  currentFileIndex := FilezArray[prevIndexu]

  r := IDshowImage(currentFileIndex)
  If !r
     informUserFileMissing()
}

MultiFileDeletePanel() {
    Static lastInvoked := 1

    filesElected := getSelectedFiles()
    createSettingsGUI(16)
    btnWid := 110
    txtWid := 280
    If (PrefsLargeFonts=1)
    {
       btnWid := btnWid + 70
       txtWid := txtWid + 155
       Gui, Font, s%LargeUIfontValue%
    }

    If (A_TickCount - lastInvoked>10500)
       move2recycler := 1 
    lastInvoked := A_TickCount
    Gui, Add, Text, x15 y15 Section w%txtWid%, Please choose what to remove:
    Gui, Add, DropDownList, y+10 wp gTglMultiDelChoice AltSubmit Choose%userMultiDelChoice% vuserMultiDelChoice, Delete selected files|Remove file entries from the list|Do both: remove files and the index entries
    Gui, Add, Checkbox, y+10 gTglOptionMove2recycler Checked%move2recycler% vmove2recycler, Do NOT delete files permanently`nMove to recycle bin deleted files
    Gui, Font, Bold
    Gui, Add, Text, xs y+15, Selected entries: %filesElected%.
    Gui, Font, Normal
    If (userMultiDelChoice=2)
       GuiControl, Disable, move2recycler

    Gui, Add, Button, xs y+15 h30 w95 gBTNmultiDel Default, &Proceed
    Gui, Add, Button, x+5 hp wp gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Delete files: %appTitle%

}

BTNmultiDel() {
   CloseWindow()
   writeMainSettings()
   Sleep, 50
   TglOptionMove2recycler()
   If (userMultiDelChoice=3 || userMultiDelChoice=1)
      r := multiFileDelete()
   Else r := 0

   If (userMultiDelChoice=3 || userMultiDelChoice=2) && (r=0)
   {
      If (userMultiDelChoice=3)
         Sleep, 500
      InListMultiEntriesRemover()
   }
}

TglMultiDelChoice() {
  TglOptionMove2recycler()
}

TglOptionMove2recycler() {
  GuiControlGet, move2recycler
  GuiControlGet, userMultiDelChoice
  If (userMultiDelChoice=1 || userMultiDelChoice=3)
     GuiControl, SettingsGUIA: Enable, move2recycler
  Else
     GuiControl, SettingsGUIA: Disable, move2recycler
}

multiFileDelete() {
   filesElected := getSelectedFiles(0, 1)
   If (filesElected<2)
   {
      SoundBeep , 300, 100
      Return
   }

   showTOOLtip("Moving to recycle bin " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   filesRemoved := abandonAll := 0
   Loop, % filesElected
   {
      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }

      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Moving to recycle bin " filesRemoved "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      thisFileIndex := getSelectedFiles(A_Index)
      file2rem := resultedFilesList[thisFileIndex]
      file2rem := StrReplace(file2rem, "||")
      Try FileSetAttrib, -R, %file2rem%
      Sleep, 0
      changeMcursor()
      If (move2recycler=1)
         FileRecycle, %file2rem%
      Else
         FileDelete, %file2rem%

      If !ErrorLevel
      {
         filesRemoved++
         resultedFilesList[thisFileIndex] := "||" file2rem
         If StrLen(filesFilter)>1
         {
            z := detectFileIDbkcpList(file2rem)
            If (z!="fail" && z>=1)
               bckpResultedFilesList[z] := "||" file2rem
         }
      } Else someErrors := "`nErrors occured during file operations..."
   }

   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   thumbSelFileList := ""
   prevStartIndex := -1
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. " filesRemoved " out of " filesElected " selected files deleted until now..." someErrors)
   } Else
   {
      SoundBeep, 900, 100
      showTOOLtip(filesRemoved " out of " filesElected " selected files deleted" someErrors)
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
   Return abandonAll
}

DeletePicture() {
  filesElected := getSelectedFiles()
  If (filesElected>1)
  {
      MultiFileDeletePanel()
      Return
  }

  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (askDeleteFiles=1)
  {
     msgTimer := A_TickCount
     msgInfos := "the current file"
     triggerOwnDialogs()
     MsgBox, 52, %appTitle%, Are you sure you want to delete %msgInfos% ?
     IfMsgBox, Yes
       good2go := 1

     If (A_TickCount - msgTimer < 550)
     {
        showTOOLtip("Operation aborted. User answered ""Yes"" too fast.")
        SetTimer, RemoveTooltip, % -msgDisplayTime
        good2go := 0
     }
  } Else good2go := 1

  If (good2go!=1)
     Return

  Sleep, 5
  markedSelectFile := thumbSelFileList := ""
  file2rem := resultedFilesList[currentFileIndex]
  file2rem := StrReplace(file2rem, "||")
  zPlitPath(file2rem, 0, OutFileName, OutDir)
  Try FileSetAttrib, -R, %file2rem%
  Sleep, 1
  FileRecycle, %file2rem%
  If ErrorLevel
  {
     showTOOLtip("File already deleted or access denied...")
     SoundBeep, 300, 100
  } Else
  {
     resultedFilesList[currentFileIndex] := "||" file2rem
     If StrLen(filesFilter)>1
     {
        z := detectFileIDbkcpList(file2rem)
        If (z!="fail" && z>=1)
           bckpResultedFilesList[z] := "||" file2rem
     }
     showTOOLtip("File moved to recycle bin...`n" OutFileName "`n" OutDir "\")
  }
  Sleep, 50
  SetTimer, RemoveTooltip, % -msgDisplayTime
  If (thumbsDisplaying=1)
     mainGdipWinThumbsGrid()
}

readRecentMultiRenameEntries() {
   entriesList := ""
   Loop, 35
   {
       IniRead, newEntry, % mainSettingsFile, RecentMultiRename, E%A_Index%, @
       If StrLen(newEntry)>1
          entriesList .= Trim(newEntry) "`n"
   }
   Return entriesList
}

batchRenameFiles() {
    Global UsrEditNewFileName
    If (maxFilesIndex<2)
       Return

    createSettingsGUI(8)
    btnWid := 100
    txtWid := 360
    EditWid := 395
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 220
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    filesElected := getSelectedFiles()
    listu := readRecentMultiRenameEntries()
    overwriteConflictingFile := 0
    Gui, +Delimiter`n
    Gui, Add, Text, x15 y15 w%txtWid%, Selected files: %filesElected%. Type a pattern to rename the files.
    Gui, Add, ComboBox, y+10 w%EditWid% gMultiRenameComboAction r12 Simple vUsrEditNewFileName, % listu
    Gui, Add, Checkbox, y+10 Checked%overwriteConflictingFile% voverwriteConflictingFile, In case of file name collisions, overwrite the other files with these ones

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gcoreMultiRenameFiles, &Rename files
    Gui, Add, Button, x+5 hp w%btnWid% gEraseMultiRenameHisto, Erase &history
    Gui, Add, Button, x+5 hp w85 gMultiRenameHelp, H&elp
    Gui, Add, Button, x+5 hp wp gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Rename multiple files: %appTitle%
}

MultiRenameHelp() {
    triggerOwnDialogs()
    MsgBox,, Help multi-rename: %appTitle%, File extensions remain unchanged regardless of the pattern used.`nFile rename patterns possible:`n`na) Prefix [this] suffix`nThe token [this] is replaced with the file name.`n`nb) Replace string//with this`nUse "//" or "\\" to perform search and replace in file names.`n`nc) any text`nFiles will be counted, to avoid naming conflicts.
}

MultiRenameComboAction() {
  If (A_GuiControlEvent="DoubleClick")
     coreMultiRenameFiles()
}

coreMultiRenameFiles() {
  Critical, on
  GuiControlGet, UsrEditNewFileName
  GuiControlGet, overwriteConflictingFile

  OriginalNewFileName := Trim(UsrEditNewFileName)
  If InStr(OriginalNewFileName, "//")
     strArr := StrSplit(OriginalNewFileName, "//")
  Else If InStr(OriginalNewFileName, "\\")
     strArr := StrSplit(OriginalNewFileName, "\\")
  Else If !InStr(OriginalNewFileName, "[this]")
     renamingCount := 1

  If (InStr(OriginalNewFileName, "//") || InStr(OriginalNewFileName, "\\")) && (renamingCount!=1)
  {
     strArrA := filterFileName(strArr[1])
     strArrB := filterFileName(strArr[2])
     If !strArrA
        Return

     If (!strArrB && StrLen(strArr[2])>0)
        Return
  } Else OriginalNewFileName := filterFileName(UsrEditNewFileName)

  If (StrLen(OriginalNewFileName)>1)
  {
     filesElected := getSelectedFiles()
     If (filesElected>100)
     {
        triggerOwnDialogs()
        MsgBox, 52, %appTitle%, Are you sure you want to rename the selected files?`n`nYou have selected %filesElected% files to be renamed...
        IfMsgBox, Yes
          good2go := 1
   
        If (good2go!=1)
           Return
     }

     CloseWindow()
     overwriteFiles := overwriteConflictingFile
     showTOOLtip("Renaming " filesElected " files, please wait...`nPattern: " OriginalNewFileName)
     prevMSGdisplay := A_TickCount
     RecentMultiRenamesManager(OriginalNewFileName)
     filezRenamed := countFilez := 0
     Loop, % filesElected
     {
         wasError := 0
         changeMcursor()
         thisFileIndex := getSelectedFiles(A_Index)
         file2rem := resultedFilesList[thisFileIndex]
         zPlitPath(file2rem, 0, OutFileName, OutDir, fileNamuNoEXT, fileEXTu)
         If !FileExist(file2rem)
            Continue

         executingCanceableOperation := A_TickCount
         If (A_TickCount - prevMSGdisplay>3000)
         {
            showTOOLtip("Renaming " filezRenamed "/" filesElected " files, please wait...`nPattern: " OriginalNewFileName)
            prevMSGdisplay := A_TickCount
         }

         OutDirAsc := StringToASC(OutDir)
         countFilez%OutDirAsc%++
         If InStr(OriginalNewFileName, "[this]")
            newFileName := StrReplace(OriginalNewFileName, "[this]", fileNamuNoEXT) "." fileEXTu
         Else If (InStr(OriginalNewFileName, "//") || InStr(OriginalNewFileName, "\\"))
            newFileName := StrReplace(fileNamuNoEXT, strArrA, strArrB) "." fileEXTu
         Else
            newFileName := OriginalNewFileName  " (" countFilez%OutDirAsc% ")." fileEXTu

         If FileExist(OutDir "\" newFileName)
         {
            If (overwriteFiles=1 && renamingCount!=1)
            {
               FileSetAttrib, -R, %file2rem%
               Sleep, 1
               FileRecycle, %OutDir%\%newFileName%
               If ErrorLevel
                  wasError++
               Sleep, 1
            } Else Continue
         }

         Sleep, 1
         FileMove, %file2rem%, %OutDir%\%newFileName%
         If ErrorLevel
         {
            wasError++
         } Else
         {
            filezRenamed++
            resultedFilesList[thisFileIndex] := OutDir "\" newFileName
            If StrLen(filesFilter)>1
            {
               z := detectFileIDbkcpList(file2rem)
               If (z!="fail" && z>=1)
                  bckpResultedFilesList[z] := OutDir "\" newFileName
            }
         }

         If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
         {
            lastLongOperationAbort := A_TickCount
            executingCanceableOperation := mustAbandonCurrentOperations := 0
            abandonAll := 1
            Break
         }
     }
     Try DllCall("user32\SetCursor", "Ptr", hCursN)
     thumbSelFileList := ""
     prevStartIndex := -1
     dummyTimerDelayiedImageDisplay(100)
     If (abandonAll=1)
        showTOOLtip("Operation aborted. "  filezRenamed " out of " filesElected " selected files were renamed" someErrors)
     Else
        showTOOLtip("Finished renaming "  filezRenamed " out of " filesElected " selected files" someErrors)
     SoundBeep , 900, 100
     SetTimer, RemoveTooltip, % -msgDisplayTime
  }
}

RecentMultiRenamesManager(entry2add) {
  entry2add := Trim(entry2add)
  mainListu := readRecentMultiRenameEntries()
  If StrLen(entry2add)<3
     Return

  Loop, Parse, mainListu, `n
  {
      If (A_LoopField=entry2add)
         Continue
      Else
         renewList .= A_LoopField "`n"
  }

  mainListu := entry2add "`n" renewList
  Loop, Parse, mainListu, `n
  {
      If (A_Index>35)
         Break

      If StrLen(A_LoopField)<3
         Continue
      countItemz++
      IniWrite, % A_LoopField, % mainSettingsFile, RecentMultiRename, E%countItemz%
  }
}

EraseMultiRenameHisto() {
  IniDelete, % mainSettingsFile, RecentMultiRename
  CloseWindow()
  RenameThisFile()
}

OlderThanEraseThumbsCache() {
    createSettingsGUI(11)
    btnWid := 110
    txtWid := 230
    If (PrefsLargeFonts=1)
    {
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       Gui, Font, s%LargeUIfontValue%
    }
    EditWid := btnWid
    remCacheOldDays := 0
    Gui, Add, Text, x15 y15 w%txtWid%, Erase thumbnails cache older than... (days)
    Gui, Add, Edit, y+7 w%EditWid% r1 limit3 +number -multi -wantTab -wrap vremCacheOldDays, % remCacheOldDays
    Gui, Add, Button, x+5 hp w%btnWid% gCleanCachedThumbs, &Clean old cache
    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% gBtnEraseThumbsCache, &Empty entire cache
    Gui, Add, Button, x+5 hp w90 Default gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Clean cached thumbnails: %appTitle%
}

BtnEraseThumbsCache() {
    CloseWindow()
    Sleep, 2
    EraseThumbsCache()
}

CleanCachedThumbs() {
    GuiControlGet, remCacheOldDays
    If (remCacheOldDays<0 || !remCacheOldDays)
       Return

    CloseWindow()
    EraseThumbsCache("daysITis")
    remCacheOldDays := 0
}

RenameThisFile() {
    Global newFileName
    If (slideShowRunning=1)
       ToggleSlideShowu()
    If (currentFileIndex=0)
       Return

    filesElected := getSelectedFiles(0, 1)
    If (filesElected>1)
    {
       batchRenameFiles()
       Return
    }

    Sleep, 2
    markedSelectFile := thumbSelFileList := ""
    file2rem := resultedFilesList[currentFileIndex]
    zPlitPath(file2rem, 0, OutFileName, OutDir)
    If !FileExist(file2rem)
    {
       showTOOLtip("File does not exist or access denied...`n" OutFileName "`n" OutDir)
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 300, 100
       Return
    }

    createSettingsGUI(7)
    btnWid := 100
    txtWid := 360
    EditWid := 395
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 230
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    overwriteConflictingFile := 0
    Gui, Add, Text, x15 y15 w%txtWid%, Please type the new file name...
    Gui, Add, Edit, y+7 w%EditWid% r1 limit9025 -multi -wantTab -wrap vnewFileName, % OutFileName
    Gui, Add, Checkbox, y+10 Checked%overwriteConflictingFile% voverwriteConflictingFile, In case of file name collision, overwrite the other file with this one

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gRenameBTNaction, &Rename file
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Rename file: %appTitle%
}

filterFileName(string) {
  Static forbiddenCharsREGex := "\<|\>|\:|\""|\/|\\|\||\?|\*"
  Static forbiddenNames := "CON|PRN|AUX|NUL|COM1|COM2|COM3|COM4|COM5|COM6|COM7|COM8|COM9|LPT1|LPT2|LPT3|LPT4|LPT5|LPT6|LPT7|LPT8|LPT9"
  string := Trim(string)
  If RegExMatch(string, forbiddenCharsREGex)
     Return

  Loop, Parse, forbiddenNames, |
  {
     If (A_LoopField=string)
        Return
  }
  Return string
}

RenameBTNaction() {
  GuiControlGet, newFileName
  GuiControlGet, overwriteConflictingFile

  newFileName := filterFileName(newFileName)
  If (StrLen(newFileName)>2)
  {
     file2rem := resultedFilesList[currentFileIndex]
     zPlitPath(file2rem, 0, OutFileName, OutDir)
     If (!FileExist(file2rem) || Trim(OutFileName)=newFileName)
        Return

     CloseWindow()
     If FileExist(OutDir "\" newFileName)
     {
        If (overwriteConflictingFile=1)
        {
           FileSetAttrib, -R, %file2rem%
           Sleep, 2
           FileRecycle, %OutDir%\%newFileName%
           Sleep, 2
        } Else
        {
           showTOOLtip("Rename operation abandoned.`nFile names conflict...`n" newFileName)
           SetTimer, RemoveTooltip, % -msgDisplayTime
           Return
        }
     }

     Sleep, 2
     FileMove, %file2rem%, %OutDir%\%newFileName%, 1
     If ErrorLevel
     {
        showTOOLtip("ERROR: Access denied... File could not be renamed.")
        SoundBeep, 300, 100
        SetTimer, RemoveTooltip, % -msgDisplayTime
     } Else
     {
        resultedFilesList[currentFileIndex] := OutDir "\" newFileName
        r := IDshowImage(currentFileIndex)
        If !r
        {
           informUserFileMissing()
        } Else If StrLen(filesFilter)>1
        {
           z := detectFileIDbkcpList(file2rem)
           If (z!="fail" && z>=1)
              bckpResultedFilesList[z] := OutDir "\" newFileName
        }
     }
  }
}

PrefsPanelWindow() {
    createSettingsGUI(14)
    btnWid := 100
    txtWid := 350
    columnBpos1 := 125
    columnBpos2 := 205
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       columnBpos1 := columnBpos1 + 50
       columnBpos2 := columnBpos2 + 50
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    Global editF4, editF5, editF6
    Gui, Add, Text, x15 y15 w%txtWid%, The text style options apply to the On-Screen Display in the viewport. The same text style is used to render as images texts pasted from the clipboard.
    Gui, Add, Text, y+15 Section, Font name
    Gui, Add, Text, xs yp+30, Font size (OSD / clipboard)
    Gui, Add, Text, xs yp+30, Text color and style
    Gui, Add, Text, xs yp+30, Text alignment on paste
    Gui, Add, Text, xs yp+30, OSD background color
    Gui, Add, Text, xs yp+30, Display time (in sec.)
    Gui, Add, Text, xs yp+30, Window background color

    Gui, Add, DropDownList, xs+%columnBpos2% ys+0 Section w190 gupdateUIsettings Sort Choose1 vOSDFontName, %OSDFontName%
    Gui, Add, Edit, xs+0 yp+30 w%editWid% r1 gupdateUIsettings limit3 -multi number -wantCtrlA -wantReturn -wantTab -wrap veditF5, %OSDfntSize%
    Gui, Add, UpDown, vOSDfntSize Range10-350, %OSDfntSize%
    Gui, Add, Edit, x+2 w%editWid% r1 gupdateUIsettings limit3 -multi number -wantCtrlA -wantReturn -wantTab -wrap veditF4, %PasteFntSize%
    Gui, Add, UpDown, vPasteFntSize Range12-350, %PasteFntSize%

    Gui, Add, ListView, xs yp+30 w%editWid% h28 %CCLVO% Background%OSDtextColor% vOSDtextColor hwndhLV1,
    Gui, Add, Checkbox, x+2 yp hp w27 +0x1000 gupdateUIsettings Checked%FontBolded% vFontBolded, B
    Gui, Add, Checkbox, x+2 yp hp w27 +0x1000 gupdateUIsettings Checked%FontItalica% vFontItalica, I
    Gui, Add, DropDownList, xs yp+30 w%editWid% gupdateUIsettings vusrTextAlign, %usrTextAlign%||Left|Right|Center
    Gui, Add, ListView,  xs+0 yp+30 gupdateUIsettings w%editWid% hp %CCLVO% Background%OSDbgrColor% vOSDbgrColor hwndhLV2,
    Gui, Add, Edit, xs+0 yp+30 gupdateUIsettings w%editWid% hp r1 limit2 -multi number -wantCtrlA -wantReturn -wantTab -wrap veditF6, %DisplayTimeUser%
    Gui, Add, UpDown, vDisplayTimeUser Range1-99, %DisplayTimeUser%
    Gui, Add, ListView, xs+0 yp+30 w%editWid% hp %CCLVO% Background%WindowBgrColor% vWindowbgrColor hwndhLV3,
    Gui, Add, Checkbox, x15 y+10 gupdateUIsettings Checked%borderAroundImage% vborderAroundImage, Highlight image borders in the viewport

    If !FontList._NewEnum()[k, v]
    {
       Fnt_GetListOfFonts()
       FontList := trimArray(FontList)
    }

    Loop, % FontList.MaxIndex()
    {
        fontNameInstalled := FontList[A_Index]
        If (fontNameInstalled ~= "i)(@|biz ud|ud digi kyo|oem|extb|symbol|marlett|wst_|glyph|reference specialty|system|terminal|mt extra|small fonts|cambria math|this font is not|fixedsys|emoji|hksc| mdl|wingdings|webdings)") || (fontNameInstalled=OSDFontName)
           Continue
        GuiControl, SettingsGUIA:, OSDFontName, %fontNameInstalled%
    }

    Gui, Add, Button, xm+0 y+20 h30 w%btnWid% gOpenUImenu, &More options
    Gui, Add, Button, x+5 hp w90 gPrefsCloseBTN Default, Clo&se
    Gui, SettingsGUIA: Show, AutoSize, Interface settings: %appTitle%
}

updateUIsettings() {
     If (AnyWindowOpen!=14)
        Return

     GuiControlGet, DisplayTimeUser
     GuiControlGet, OSDFontName
     GuiControlGet, OSDfntSize
     GuiControlGet, PasteFntSize
     GuiControlGet, FontBolded
     GuiControlGet, FontItalica
     GuiControlGet, usrTextAlign
     GuiControlGet, borderAroundImage

     imgHUDbaseUnit := (PrefsLargeFonts=1) ? Round(OSDfntSize*6.5) : Round(OSDfntSize*5.25)
     msgDisplayTime := DisplayTimeUser*1000
     writeMainSettings()
}

PrefsCloseBTN() {
     updateUIsettings()
     Gui, 1: Color, %WindowBgrColor%
     CloseWindow()
}

setColors(hC, event, c, err=0) {
; Function by Drugwash
; Critical MUST be disabled below! If that's not done, script will enter a deadlock !
  Static
  oc := A_IsCritical
  Critical, Off
  If (event != "Normal")
     Return
  g := A_Gui, ctrl := A_GuiControl
  r := %ctrl% := hexRGB(Dlg_Color(%ctrl%, hC))
  Critical, %oc%
  GuiControl, %g%:+Background%r%, %ctrl%
  Gui, 1: Color, %WindowBgrColor%
  updateUIsettings()
  refreshWinBGRbrush()
}

hexRGB(c) {
; unknown source
  r := ((c&255)<<16)+(c&65280)+((c&0xFF0000)>>16)
  c := "000000"
  DllCall("msvcrt\sprintf", "AStr", c, "AStr", "%06X", "UInt", r, "CDecl")
  Return c
}

Dlg_Color(Color,hwnd) {
; Function by maestrith 
; from: [AHK 1.1] Font and Color Dialogs 
; https://autohotkey.com/board/topic/94083-ahk-11-font-and-color-dialogs/
; Modified by Marius Șucan and Drugwash

  Static
  If !cpdInit {
     VarSetCapacity(CUSTOM,64,0), cpdInit:=1, size:=VarSetCapacity(CHOOSECOLOR,9*A_PtrSize,0)
  }

  Color := "0x" hexRGB(InStr(Color, "0x") ? Color : Color ? "0x" Color : 0x0)
  NumPut(size,CHOOSECOLOR,0,"UInt"),NumPut(hwnd,CHOOSECOLOR,A_PtrSize,"Ptr")
  ,NumPut(Color,CHOOSECOLOR,3*A_PtrSize,"UInt"),NumPut(3,CHOOSECOLOR,5*A_PtrSize,"UInt")
  ,NumPut(&CUSTOM,CHOOSECOLOR,4*A_PtrSize,"Ptr")
  If !ret := DllCall("comdlg32\ChooseColorW","Ptr",&CHOOSECOLOR,"UInt")
     Exit

  SetFormat, Integer, H
  Color := NumGet(CHOOSECOLOR,3*A_PtrSize,"UInt")
  SetFormat, Integer, D
  Return Color
}

OpenUImenu() {
   deleteMenus()
   createInterfaceMenuOptions()
   showThisMenu("PvUIprefs")
}

defineEntireSlideshowDurationPanel() {
    Global userHourDur, userMinDur, userSecDur, infoLine, userDefinedSpeedSlideshow
    If (maxFilesIndex<3 || thumbsDisplaying=1)
       Return

    createSettingsGUI(19)
    btnWid := 130
    txtWid := 350
    EditWid := 35
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 2
       btnWid := btnWid + 75
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    coreSecToHHMMSS((slideShowDelay/1000)*maxFilesIndex, Hrs, Min, Sec)
    infoSliSpeed := DefineSlidesRate()
    etaTime := EstimateSlideShowLength()

    Gui, Add, Text, x15 y15 Section w%txtWid%, Define the total time of the slideshow`nfor %maxFilesIndex% images.
    Gui, Add, Text, y+15 w80, Hours
    Gui, Add, Edit, x+5 wp gUpdateSlideshowPanel r1 limit2 Number -multi -wantTab -wrap vuserHourDur, % Round(Hrs)
    Gui, Add, Text, xs y+5 wp, Minutes
    Gui, Add, Edit, x+5 wp gUpdateSlideshowPanel r1 limit2 Number -multi -wantTab -wrap vuserMinDur, % Round(Min)
    Gui, Add, Text, xs y+5 wp, Seconds
    Gui, Add, Edit, x+5 wp gUpdateSlideshowPanel r1 limit2 Number -multi -wantTab -wrap vuserSecDur, % Round(Sec)
    Gui, Add, Text, xs y+5 wp, Speed
    Gui, Add, DropDownList, x+5 wp gChooseSlideSpeed AltSubmit vuserDefinedSpeedSlideshow, ---||30 FPS|15 FPS|7 FPS|2 FPS|1 sec.|2 sec.|4 sec.|8 sec.|16 sec.
    Gui, Add, Button, x+5 hp w95 gTimeLapseInfoBox, Timelapse

    Gui, Add, Text, xs y+15 w%txtWid% vinfoLine, One image every: %infoSliSpeed%`nEstimated slideshow duration: %etaTime%

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gStartSlideINtotalTimeBTNaction, &Start slideshow
    Gui, Add, Button, x+5 hp w90 gResetSlideSpeed, De&fault
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, Define total slideshow time: %appTitle%
}

TimeLapseInfoBox() {
    MsgBox,, %appTitle%, The slideshow durations displayied in the panel include the time estimated to load each image. Based on previously loaded images it takes about %drawModeCzeit% [in milisec.]`n `nFor optimal timelapses [or very fast slideshows] set zoom at 100`% and disable color adjustments.`n`nThe slideshow is now set to run at ~30 FPS [33 images/sec.] based on the amount of loaded images: %maxFilesIndex%.
    coreResetSlideSpeed(33, 1)
    GuiControl, SettingsGUIA: Choose, userDefinedSpeedSlideshow, 2
}

ResetSlideSpeed() {
    coreResetSlideSpeed(4000, 1)
    GuiControl, SettingsGUIA: Choose, userDefinedSpeedSlideshow, 8
}

ChooseSlideSpeed() {
    GuiControlGet, userDefinedSpeedSlideshow
    If (userDefinedSpeedSlideshow=2)
       coreResetSlideSpeed(33, 1)
    Else If (userDefinedSpeedSlideshow=3)
       coreResetSlideSpeed(67, 1)
    Else If (userDefinedSpeedSlideshow=4)
       coreResetSlideSpeed(143, 1)
    Else If (userDefinedSpeedSlideshow=5)
       coreResetSlideSpeed(500, 1)
    Else If (userDefinedSpeedSlideshow=6)
       coreResetSlideSpeed(1000, 1)
    Else If (userDefinedSpeedSlideshow=7)
       coreResetSlideSpeed(2000, 1)
    Else If (userDefinedSpeedSlideshow=8)
       coreResetSlideSpeed(4000, 1)
    Else If (userDefinedSpeedSlideshow=9)
       coreResetSlideSpeed(8000, 1)
    Else If (userDefinedSpeedSlideshow=10)
       coreResetSlideSpeed(16000, 1)
}

coreResetSlideSpeed(varu, noDDLjump:=0) {
    slideShowDelay := varu
    coreSecToHHMMSS((slideShowDelay/1000)*maxFilesIndex, Hrs, Min, Sec)
    GuiControl, SettingsGUIA:, userHourDur, % Round(Hrs)
    GuiControl, SettingsGUIA:, userMinDur, % Round(Min)
    GuiControl, SettingsGUIA:, userSecDur, % Round(Sec)
    If (noDDLjump!=1)
       GuiControl, SettingsGUIA: Choose, userDefinedSpeedSlideshow, 1
    DefineSlidesTotalTimeBTNaction(0)
}

DefineSlidesRate() {
   slidesDuration := (slideShowDelay<drawModeCzeit) ? drawModeCzeit : slideShowDelay
   If (slidesDuration<990)
      miliSec := slidesDuration " milisec."
   Else
      duration := SecToHHMMSS(Round(slidesDuration/1000, 3))
   Return miliSec ? miliSec : duration
}

StartSlideINtotalTimeBTNaction() {
   DefineSlidesTotalTimeBTNaction(0)
   CloseWindow()
   dummyInfoToggleSlideShowu()
}

UpdateSlideshowPanel() {
    Static lastInvoked := 1
    DefineSlidesTotalTimeBTNaction()
    GuiControlGet, WhatsFocused, SettingsGUIA: FocusV
    If (WhatsFocused="userHourDur" || WhatsFocused="userMinDur" || WhatsFocused="userSecDur")
       GuiControl, SettingsGUIA: Choose, userDefinedSpeedSlideshow, 1
    lastInvoked := A_TickCount
}

DefineSlidesTotalTimeBTNaction(doDDLjump:=1) {
    GuiControlGet, userHourDur
    GuiControlGet, userMinDur
    GuiControlGet, userSecDur
    slideShowDelay := 0    
    slideShowDelay += userSecDur*1000
    slideShowDelay += (userMinDur*60)*1000
    slideShowDelay += ((userHourDur*60)*60)*1000
    slideShowDelay := Round(slideShowDelay/maxFilesIndex)
    If (slideShowDelay<16)
       slideShowDelay := 16

    etaTime := EstimateSlideShowLength()
    infoSliSpeed := DefineSlidesRate()
    GuiControl, SettingsGUIA:, InfoLine, One image every: %approxMarker%%infoSliSpeed%`nEstimated slideshow duration: %approxMarker%%etaTime%
}

EstimateSlideShowLength() {
    slidesDuration := (slideShowDelay<drawModeCzeit) ? drawModeCzeit : slideShowDelay
    approxMarker := (slideShowDelay<drawModeCzeit) || (slideShowDelay<100) ? "~" : ""
    slidesDuration := Round(slidesDuration/1000, 3)*maxFilesIndex
    etaTime := SecToHHMMSS(slidesDuration)
    Return etaTime
}

Jump2index() {
    Global newJumpIndex
    If (maxFilesIndex<3)
       Return

    createSettingsGUI(13)
    btnWid := 100
    txtWid := 350
    EditWid := 355
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 230
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    Gui, Add, Text, x15 y15 w%txtWid%, Please type the index number you want to jump to...`n Add S to jump and select from the current index to the new index.
    Gui, Add, Edit, y+7 w%EditWid% r1 limit9025 -multi -wantTab -wrap vnewJumpIndex, % currentFileIndex

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gJump2indexBTNaction, &Jump to index
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Jump to index #: %appTitle%
}

jump2indexBTNaction() {
  GuiControlGet, newJumpIndex
  newJumpIndex := Trim(newJumpIndex)
  If InStr(newJumpIndex, "s")
     selectionMode := 1

  newJumpIndex := StrReplace(newJumpIndex, "s")
  If newJumpIndex is Number
  {
     If (newJumpIndex<1)
        Return

     CloseWindow()
     If (newJumpIndex>maxFilesIndex)
        newJumpIndex := maxFilesIndex

     If (selectionMode=1)
     {
        markedSelectFile := generateNumberRangeString(currentFileIndex, newJumpIndex)
        thumbSelFileList := ""
     }

     currentFileIndex := newJumpIndex
     r := IDshowImage(currentFileIndex)
     If !r
        informUserFileMissing()
  }
}

SaveClipboardImage(dummy:=0) {
   Static lastInvoked := 1

   If (slideShowRunning=1)
      ToggleSlideShowu()

   clippyTest := resultedFilesList[0]
   If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
      good2go := 1

   If (dummy="yay" && thumbsDisplaying!=1)
      good2go := 1

   If (good2go!=1)
   {
      SaveFilesList()
      Return
   }

   If (dummy="yay")
   {
      imgPath := resultedFilesList[currentFileIndex]
      imgPath := StrReplace(imgPath, "||")
   }

   defaultu := (dummy="yay") ? imgPath : prevFileSavePath
   If (A_TickCount - lastInvoked < 2500)
      defaultu := prevFileSavePath
   triggerOwnDialogs()
   FileSelectFile, file2save, S18, % defaultu, Save image as..., Images (%dialogSaveFptrn%)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If (dummy!="yay")
         imgPath := thumbsCacheFolder "\Current-Clipboard.png"

      zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
      zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, nExt)
      If !nExt
         file2save .= "." oExt

      If !RegExMatch(file2save, saveTypesRegEX)
      {
         Msgbox, 48, %appTitle%, ERROR: Please use a supported file format extention: %saveTypesFriendly%.
         Return
      }

      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: This format is currently unsupported. The FreeImage library failed to properly initialize.`n`n%OutFileName%
         Return
      }

      If (activateImgSelection=1)
      {
         MsgBox, 52, %appTitle%, An area of the image is selected in the viewport. Would you like to save only the selected area? By answering no, the entire image will be saved.
         IfMsgBox, Yes
            allowCropping := 1
         If (allowCropping!=1)
            toggleImgSelection()
      }

      showTOOLtip("Please wait, saving image...`n" OutFileName)
      prevFileSavePath := OutDir
      writeMainSettings()
      If gdiBitmap
      {
         Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
         dummyBMP := Gdip_CloneBitmap(gdiBitmap)
         r := coreResizeIMG(imgPath, imgW, imgH, file2save, 1, 0, 0, dummyBMP, imgW, imgH, 0)
      } Else r := "Err"

      If r
      {
         showTOOLtip("Failed to save image file...`n" OutFileName "`n" OutDir "\")
         SoundBeep, 300, 900
      } Else
      {
         showTOOLtip("Image file saved...`n" OutFileName "`n" OutDir "\")
         SoundBeep, 900, 100
      }
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
   lastInvoked := A_TickCount
}

ChooseFilesDest() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (currentFileIndex=0)
      Return

   If (AnyWindowOpen>0)
   {
      CloseWindow()
      wasOpen := 1
   }

   triggerOwnDialogs()
   FileSelectFile, file2save, S2, %prevFileMovePath%\this-folder, Please select destination folder..., All files (*.*)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      zPlitPath(file2save, 0, OldOutFileName, OldOutDir)
      If (wasOpen=1)
      {
         prevFileMovePath := OldOutDir
         RecentCopyMoveManager(OldOutDir)
         Sleep, 25
         CopyMovePanelWindow()
      } Else Return
   }
}

zPlitPath(inputu, fastMode, ByRef fileNamu, ByRef folderu, ByRef fileNamuNoEXT:=0, ByRef fileEXT:=0) {
    If (fastMode=0)
    {
       inputu := Trim(StrReplace(inputu, "|"))
       FileGetAttrib, OutputVar, %inputu%
    } Else StringRight, OutputVar, inputu, 1

    If InStr(OutputVar, "D") || (OutputVar="\")
    {
       folderu := inputu
       fileEXT := fileNamuNoEXT := fileNamu := ""
       Return
    } Else
    {
       lineArr := StrSplit(inputu, "\")
       maxuIndex := lineArr.MaxIndex()
       fileNamu := lineArr[maxuIndex]
       folderu := SubStr(inputu, 1, StrLen(inputu) - StrLen(fileNamu) - 1)
       fileEXTpos := RegExMatch(fileNamu, "\.[^.\\/:*?<>|\r\n]+$")
       If fileEXTpos
          fileEXT := SubStr(fileNamu, fileEXTpos+1)
       fileNamuNoEXT := fileEXTpos ? RegExReplace(fileNamu, "\.[^.\\/:*?<>|\r\n]+$") : fileNamu
    }
}

StringToASC(String) {
  If !String
     Return
  
  Loop, Parse, String 
    AscString .= Asc(A_LoopField)
  
  Return AscString
}

readRecentFileDesties(modus:=0) {
   listu := ""
   If (modus!=1)
   {
      If FileExist(prevFileMovePath)
         listu .= prevFileMovePath "`n"
      If FileExist(prevFileSavePath)
         listu .= prevFileSavePath "`n"
      If FileExist(prevOpenFolderPath)
         listu .= prevOpenFolderPath "`n"
   }

   Loop, 15
   {
       IniRead, newEntry, % mainSettingsFile, RecentFDestinations, E%A_Index%, @
       If (StrLen(newEntry)>4 && FileExist(newEntry) && !InStr(listu, newEntry "`n"))
          listu .= newEntry "`n"
   }
   Return listu
}

InvokeMoveFiles() {
   UsrCopyMoveOperation := 2
   CopyMovePanelWindow()
}

InvokeCopyFiles() {
   UsrCopyMoveOperation := 3
   CopyMovePanelWindow()
}

CopyMovePanelWindow() {
    Global UsrEditFileDestination, BtnCpyMv
    Static prevmainDynaFoldersListu, prevCurrentSLD, lastInvoked := 1

    createSettingsGUI(9)
    btnWid := 125
    txtWid := 360
    EditWid := 395
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 220
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    ToolTip, Please wait...,,, 2
    listu := readRecentFileDesties()
    listu .= "--={ other destinations }=--`n"

    readRecentEntries()
    Loop, Parse, historyList, `n
    {
       If (A_Index>15)
          Break 

       If StrLen(A_LoopField<4)
          Continue 

       changeMcursor()
       zPlitPath(A_LoopField, 0, fileNamu, OutDir)
       If InStr(listu, OutDir "`n") || !FileExist(OutDir)
          Continue
       listu .= OutDir "`n"
    } 

    If (prevmainDynaFoldersListu && prevCurrentSLD=CurrentSLD) && (A_TickCount - lastInvoked<45670)
    {
       mainDynaFoldersListu := prevmainDynaFoldersListu
    } Else
    {
       prevmainDynaFoldersListu := mainDynaFoldersListu := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
       prevCurrentSLD := CurrentSLD
       lastInvoked := A_TickCount
    }

    Loop, Parse, mainDynaFoldersListu, `n
    {
        If (A_Index>15)
           Break

        If StrLen(A_LoopField)<4
           Continue

        changeMcursor()
        folderu := StrReplace(A_LoopField, "|")
        If InStr(listu, folderu "`n") || !FileExist(folderu)
           Continue
        listu .= folderu "`n"
    }

    Loop, Parse, listu, `n
    {
        If !A_LoopField
           Continue

        changeMcursor()
        indexu := InStr(A_LoopField, "{ other dest") ? "" : A_Index - 1 "; "
        finalListu .= indexu A_LoopField "`n"
        If (A_Index=1)
           finalListu .= "`n"
    }

    filesElected := getSelectedFiles(0, 1)
    If (filesElected>1)
       infoSelection := "Selected files: " filesElected ". "

    overwriteConflictingFile := 0
    Gui, +Delimiter`n
    Gui, Add, Text, x15 y15 Section, %infoSelection%Please select or type destination folder...
    Gui, Add, ComboBox, xs y+10 w%EditWid% gCopyMoveComboAction r12 Simple vUsrEditFileDestination, % finalListu
    Gui, Add, Checkbox, y+10 Checked%overwriteConflictingFile% voverwriteConflictingFile, When file name(s) collide, overwrite file(s) found in selected folder

    ToolTip,,,,2
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    btnName := (UsrCopyMoveOperation=2) ? "Move" : "Copy"
    Gui, Add, Button, xs y+20 h30 w%btnWid% gChooseFilesDest, &Choose a new folder
    Gui, Add, DropDownList, x+5 w%btnWid% gchangeCopyMoveAction AltSubmit Choose%UsrCopyMoveOperation% vUsrCopyMoveOperation, Action...`nMove file(s)`nCopy file(s)
    Gui, Add, Button, xs y+20 h30 w%btnWid% Default gOpenQuickItemDir vBtnCpyMv, &Proceed...
    Gui, Add, Button, x+5 hp w%btnWid% gEraseCopyMoveHisto, Erase &history
    Gui, Add, Button, x+5 hp w80 gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, %btnName% file(s) to...: %appTitle%
}

changeCopyMoveAction() {
  GuiControlGet, UsrCopyMoveOperation
  btnName := (UsrCopyMoveOperation=2) ? "Move" : "Copy"
  ; GuiControl, SettingsGUIA:, BtnCpyMv, &%btnName% file(s)
  Gui, SettingsGUIA: Show,, %btnName% file(s) to...: %appTitle%
  If (UsrCopyMoveOperation=1)
     GuiControl, SettingsGUIA: Disable, BtnCpyMv
  Else
     GuiControl, SettingsGUIA: Enable, BtnCpyMv
}

CopyMoveComboAction() {
  Static lastInvoked := 1
  GuiControlGet, UsrEditFileDestination
  If (A_GuiControlEvent="DoubleClick")
  {
     OpenQuickItemDir()
  } Else If (A_GuiControlEvent="Normal") && (A_TickCount - lastInvoked > 50) && StrLen(UsrEditFileDestination)<5
    && !InStr(UsrEditFileDestination, ":\") && InStr(UsrEditFileDestination, ";")
  {
     SendInput, {Up}
     lastInvoked := A_TickCount
  }
}

EraseCopyMoveHisto() {
  IniDelete, % mainSettingsFile, RecentFDestinations
  CloseWindow()
  CopyMovePanelWindow()
}

OpenQuickItemDir() {
  GuiControlGet, UsrEditFileDestination
  GuiControlGet, UsrCopyMoveOperation
  GuiControlGet, overwriteConflictingFile

  If (UsrCopyMoveOperation=1)
     Return

  folderu := Trim(UsrEditFileDestination)
  If (b := InStr(folderu, "; "))
     folderu := SubStr(folderu, b+2)

  If !InStr(folderu, ":\")
     Return

  If (StrLen(folderu)>4 && FileExist(folderu))
  {
     CloseWindow()
     Sleep, 2
     QuickMoveFile2Dest(folderu)
  } Else SoundBeep, 300, 100

 ; MsgBox, %folderu% -- %newentry%
}

RecentCopyMoveManager(entry2add) {
  entry2add := Trim(entry2add)
  mainListu := readRecentFileDesties(1)

  If StrLen(entry2add)<3
     Return

  Loop, Parse, mainListu,`n
  {
      If (A_LoopField=entry2add)
      {
         isAddedAlready := 1
         Break
      }
  }

  If (isAddedAlready=1)
     Return

  mainListu := entry2add "`n" mainListu
  Loop, Parse, mainListu, `n
  {
      If (A_Index>15)
         Break

      If StrLen(A_LoopField)<4
         Continue
      countItemz++
      IniWrite, % A_LoopField, % mainSettingsFile, RecentFDestinations, E%countItemz%
  }
}

QuickMoveFile2Dest(finalDest) {
    If (slideShowRunning=1)
       ToggleSlideShowu()
 
    filesElected := getSelectedFiles()
    If (filesElected>1)
    {
       batchCopyMoveFile(finalDest)
       Return
    }
 
    Sleep, 2
    markedSelectFile := thumbSelFileList := ""
    file2rem := resultedFilesList[currentFileIndex]
    zPlitPath(file2rem, 0, OldOutFileName, OldOutDir)
    If !FileExist(file2rem)
    {
       showTOOLtip("File does not exist or access denied...`n" OldOutFileName "`n" OldOutDir "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 300, 100 
       Return
    }

    If (OldOutDir=finalDest)
    {
       showTOOLtip("Destination equals to initial location...`nOperation ignored.`n" finalDest "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Return
    }

    file2save := finalDest "\" OldOutFileName
    If FileExist(file2save)
    {
       If (overwriteConflictingFile=1)
       {
          FileSetAttrib, -R, %file2save%
          Sleep, 5
          FileRecycle, %file2save%
          Sleep, 5
          If (UsrCopyMoveOperation=2)
             FileMove, %file2rem%, %file2save%, 1
          Else
             FileCopy, %file2rem%, %file2save%, 1
          If ErrorLevel
          {
             actName := (UsrCopyMoveOperation=2) ? "move" : "copy"
             showTOOLtip(OldOutFileName "`nFailed to  " actName " file to...`n" finalDest "\")
             SoundBeep, 300, 100
             SetTimer, RemoveTooltip, % -msgDisplayTime
             Return
          }
       } Else
       {
          showTOOLtip("A file with the same name exists in the destination folder.`nOperation aborted...`n" OldOutFileName "`n" finalDest "\")
          SoundBeep, 300, 100
          SetTimer, RemoveTooltip, % -msgDisplayTime
          Return
       }
    } Else
    {
       If (UsrCopyMoveOperation=2)
          FileMove, %file2rem%, %file2save%
       Else
          FileCopy, %file2rem%, %file2save%
       If ErrorLevel
          wasError := 1
    }

    If (wasError!=1)
    {
       prevFileMovePath := finalDest
       RecentCopyMoveManager(finalDest)
       actName := (UsrCopyMoveOperation=2) ? "moved" : "copied"
       showTOOLtip("File " actName " to...`n" OldOutFileName "`n" finalDest "\")
       If (UsrCopyMoveOperation=2)
          resultedFilesList[currentFileIndex] := file2save
       If (StrLen(filesFilter)>1 && UsrCopyMoveOperation=2)
       {
          z := detectFileIDbkcpList(file2rem)
          If (z!="fail" && z>=1)
             bckpResultedFilesList[z] := file2save
       }
       Sleep, 25
       ; RecentFilesManager(0, 2)
       SetTimer, RemoveTooltip, % -msgDisplayTime
    } Else
    {
       actName := (UsrCopyMoveOperation=2) ? "move" : "copy"
       showTOOLtip(OldOutFileName "`nFailed to  " actName " file to...`n" finalDest "\")
       SoundBeep, 300, 100
       SetTimer, RemoveTooltip, % -msgDisplayTime
    }
}

batchCopyMoveFile(finalDest) {
   Static lastInvoked := 1
   filesElected := getSelectedFiles()
   If (A_TickCount - lastInvoked > 29500) || (filesElected>100)
   {
      triggerOwnDialogs()
      wording := (UsrCopyMoveOperation=2) ? "MOVE" : "COPY"
      MsgBox, 52, %appTitle%, Are you sure you want to %wording% the selected files?`n`nSelected %filesElected% files`nDestination: %finalDest%
      IfMsgBox, Yes
        good2go := 1
 
      If (good2go!=1)
         Return
   }

   lastInvoked := A_TickCount
   overwriteFiles := overwriteConflictingFile
   friendly := (UsrCopyMoveOperation=2) ? "Moving " : "Copying "
   showTOOLtip(friendly filesElected " files to`n" finalDest "\`nPlease wait...")
   prevFileMovePath := finalDest
   RecentCopyMoveManager(finalDest)
   Sleep, 25
   prevMSGdisplay := A_TickCount
   countTFilez := filezMoved := 0
   ; RecentFilesManager(0, 2)
   Loop, % filesElected
   {
      changeMcursor()
      thisFileIndex := getSelectedFiles(A_Index)
      file2rem := resultedFilesList[thisFileIndex]
      zPlitPath(file2rem, 0, OldOutFileName, OldOutDir)
      If !FileExist(file2rem)
         Continue

      If (OldOutDir=finalDest)
         Continue

      countTFilez++
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip(friendly countTFilez "/" filesElected " files to`n" finalDest "\`nPlease wait...")
         prevMSGdisplay := A_TickCount
      }

      wasError := skippedFile := 0
      file2save := finalDest "\" OldOutFileName
      If FileExist(file2save)
      {
         changeMcursor()
         If (overwriteFiles=1)
         {
            FileSetAttrib, -R, %file2save%
            Sleep, 2
            FileRecycle, %file2save%
            Sleep, 2
            If (UsrCopyMoveOperation=2)
               FileMove, %file2rem%, %file2save%, 1
            Else
               FileCopy, %file2rem%, %file2save%, 1
            If ErrorLevel
               wasError++
         } Else
         {
            skippedFile := 1
            Continue
         }
      } Else
      {
         If (UsrCopyMoveOperation=2)
            FileMove, %file2rem%, %file2save%, 1
         Else
            FileCopy, %file2rem%, %file2save%, 1
         If ErrorLevel
            wasError++
      }

      If (!wasError)
      {
         filezMoved++
         If (UsrCopyMoveOperation=2)
            resultedFilesList[thisFileIndex] := file2save
         If (StrLen(filesFilter)>1 && UsrCopyMoveOperation=2)
         {
            z := detectFileIDbkcpList(file2rem)
            If (z!="fail" && z>=1)
               bckpResultedFilesList[z] := file2save
         }
      } Else If (skippedFile!=1)
         someErrors := "`nErrors occured during file operations..."

      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }
   }
   thumbSelFileList := ""
   prevStartIndex := -1
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   dummyTimerDelayiedImageDisplay(100)
   If (UsrCopyMoveOperation=2)
   {
      If (abandonAll=1)
         showTOOLtip("Operation aborted. " filezMoved " out of " filesElected " selected files were moved to`n" finalDest "\" someErrors)
      Else
         showTOOLtip("Finished moving " filezMoved " out of " filesElected " files to`n" finalDest "\" someErrors)
   } Else
   {
      If (abandonAll=1)
         showTOOLtip("Operation aborted. " filezMoved " out of " filesElected " selected files were copied to`n" finalDest "\" someErrors)
      Else
         showTOOLtip("Finished copying " filezMoved " out of " filesElected " files to`n" finalDest "\" someErrors)
   }

   If (abandonAll=1)
      SoundBeep, 900, 100
   Else
      SoundBeep, 300, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
   lastInvoked := A_TickCount
}

batchConvert2jpeg() {
   If AnyWindowOpen
      CloseWindow()

   filesElected := getSelectedFiles()
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   imageLoading := 1
   showTOOLtip("Converting to ." rDesireWriteFMT A_Space filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   countTFilez := filesConverted := 0
   Loop, % filesElected
   {
      thisFileIndex := getSelectedFiles(A_Index)
      file2rem := resultedFilesList[thisFileIndex]
      If RegExMatch(file2rem, "i)(.\.(" rDesireWriteFMT "))$")
         Continue

      countTFilez++
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Converting to ." rDesireWriteFMT A_Space countTFilez "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }

      file2rem := StrReplace(file2rem, "||")
      zPlitPath(file2rem, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
      destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
      file2save := destImgPath "\" OutNameNoExt "." rDesireWriteFMT
      If (FileExist(file2save) && userOverwriteFiles=0)
         Continue
      Else If FileExist(file2save)
         FileSetAttrib, -R, %file2save%

      Sleep, 0
      changeMcursor()
      pBitmap := LoadBitmapFromFileu(file2rem)
      If !pBitmap
         Continue

      changeMcursor()
      r := Gdip_SaveBitmapToFile(pBitmap, file2save, 90)
      If (r=-2 || r=-1)
         r := SaveFIMfile(file2save, pBitmap)

      If r
         someErrors := "`nErrors occured during file operations..."
      Else filesConverted++

      If pBitmap
         Gdip_DisposeImage(pBitmap, 1)

      If (OnConvertKeepOriginals!=1 && !r)
      {
         FileSetAttrib, -R, %file2rem%
         FileRecycle, %file2rem%
         If ErrorLevel
            someErrors := "`nErrors occured during file operations..."
         resultedFilesList[thisFileIndex] := file2save
         If StrLen(filesFilter)>1
         {
            z := detectFileIDbkcpList(file2rem)
            If (z!="fail" && z>=1)
               bckpResultedFilesList[z] := file2save
         }
      }
   }

   CurrentSLD := backCurrentSLD
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   thumbSelFileList := ""
   prevStartIndex := -1
   imageLoading := 0
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. "  filesConverted " out of " filesElected " selected files were converted to ." rDesireWriteFMT someErrors)
      SoundBeep , 300, 100
   } Else
   {
      showTOOLtip("Finished converting to ." rDesireWriteFMT A_Space filesConverted " out of " filesElected " selected files" someErrors)
      SoundBeep , 900, 100
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

convert2format() {
  Critical, on
  If (currentFileIndex=0)
     Return "err"

  file2rem := resultedFilesList[currentFileIndex]
  If RegExMatch(file2rem, "i)(.\.(" rDesireWriteFMT "))$")
  {
     showTOOLtip("The image file seems to be already in the given file format: ." rDesireWriteFMT)
     SoundBeep , 300, 100
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return "err"
  }

  If (slideShowRunning=1)
     ToggleSlideShowu()

  markedSelectFile := thumbSelFileList := ""
  file2rem := StrReplace(file2rem, "||")
  zPlitPath(file2rem, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
  Sleep, 1
  changeMcursor()
  ToolTip, Please wait... converting file...
  destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
  file2save := destImgPath "\" OutNameNoExt "." rDesireWriteFMT
  If (FileExist(file2save) && userOverwriteFiles=0)
  {
     ToolTip
     showTOOLtip("A file with the same name already exists in the destination folder...")
     SoundBeep , 300, 100
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return "err"
  } Else If FileExist(file2save)
     FileSetAttrib, -R, %file2save%

  pBitmap := LoadBitmapFromFileu(file2rem)
  changeMcursor()
  r := Gdip_SaveBitmapToFile(pBitmap, file2save, 85)
  If (r=-2 || r=-1)
     r := SaveFIMfile(file2save, pBitmap)

  If AnyWindowOpen
     CloseWindow()

  If pBitmap
     Gdip_DisposeImage(pBitmap, 1)

  ToolTip
  If r
  {
     showTOOLtip("Failed to convert file...`n" OutFileName "`n" OutDir "\")
     SoundBeep , 300, 100
  } Else showTOOLtip("File converted succesfully to ." rDesireWriteFMT "...`n" OutNameNoExt "." rDesireWriteFMT "`n" destImgPath "\")

  Try DllCall("user32\SetCursor", "Ptr", hCursN)
  SetTimer, RemoveTooltip, % -msgDisplayTime

  If (OnConvertKeepOriginals!=1 && !r)
  {
     Try FileSetAttrib, -R, %file2rem%
     Sleep, 0
     FileRecycle, %file2rem%
     resultedFilesList[currentFileIndex] := file2save
     If StrLen(filesFilter)>1
     {
        z := detectFileIDbkcpList(file2rem)
        If (z!="fail" && z>=1)
           bckpResultedFilesList[z] := file2save
     }
  }
}

OpenFolders() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   triggerOwnDialogs()
   startPath := prevOpenFolderPath
   FileSelectFolder, SelectedDir, *%startPath%, 2, Select the folder with images. All images found in sub-folders will be loaded as well.
   If (SelectedDir)
   {
      newStaticFoldersListCache := ""
      prevOpenFolderPath := SelectedDir
      writeMainSettings()
      coreOpenFolder(SelectedDir)
   }
}

renewCurrentFilesList() {
  prevRandyIMGs := []
  markedSelectFile := thumbSelFileList := ""
  prevRandyIMGnow := 0
  resultedFilesList := []
  maxFilesIndex := 0
  prevStartIndex := -1
  currentFileIndex := 1
  If hSNDmedia
     StopMediaPlaying()
}

coreOpenFolder(thisFolder, doOptionals:=1) {
   testThis := StrReplace(thisFolder, "|")
   testThis := FileExist(testThis)
   If (StrLen(thisFolder)>3 && InStr(testThis, "D"))
   {
      If (A_TickCount - scriptStartTime>350)
         CloseWindow()
      usrFilesFilteru := filesFilter := CurrentSLD := ""
      WinSetTitle, ahk_id %PVhwnd%,, Loading files - please wait...
      renewCurrentFilesList()
      GetFilesList(thisFolder "\*")
      If (maxFilesIndex=0)
      {
         GdipCleanMain(1)
         showTOOLtip("ERROR: Found no recognized image files in the folder...`n" thisFolder "\")
         SoundBeep , 300, 100
         WinSetTitle, ahk_id %PVhwnd%,, %appTitle%
         SetTimer, RemoveTooltip, % -msgDisplayTime
         Return
      }

      GenerateRandyList()
      mustGenerateStaticFolders := 1
      DynamicFoldersList := thisFolder "`n"
      CurrentSLD := thisFolder
      RecentFilesManager()
      SetTimer, RemoveTooltip, % -msgDisplayTime
      If (doOptionals=1)
      {
         If (maxFilesIndex>0)
            RandomPicture()
         Else
            Gosub, GuiSize
      }
   } Else
   {
      GdipCleanMain(0)
      WinSetTitle, ahk_id %PVhwnd%,, %appTitle%
      showTOOLtip("ERROR: The folder seems to be inexistent...`n" thisFolder "\")
      SoundBeep , 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

RefreshImageFileAction() {
   If (thumbsDisplaying!=1)
   {
      RefreshImageFile()
      showTOOLtip("Image file reloaded...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   } Else RefreshFilesList()
}

RefreshImageFile() {
   ; disposeCacheIMGs()
   r := IDshowImage(currentFileIndex, 3)
   If !r
      informUserFileMissing()
}

RefreshFilesList() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  If RegExMatch(CurrentSLD, "i)(\.sld)$")
  {
     currentFileIndex := 1
     OpenSLD(CurrentSLD, 1)
     RandomPicture()
  } Else If StrLen(CurrentSLD)>3
     RegenerateEntireList()
     ; coreOpenFolder(CurrentSLD)
}

OpenRawFiles() {
   OpenFiles("raws")
}

OpenFiles(dummy:=0) {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    triggerOwnDialogs()
    If (dummy="raws")
    {
       winTitle := "Open Camera RAW files..."
       pattern := "Camera RAW files (" openFptrn3 ";*.sti;*.sld)"
    } Else
    {
       winTitle := "Open image(s) or a slideshow file..."
       pattern := "Images (" openFptrn1 ";" openFptrn2 ";" openFptrn4 ";*.sld)"
    }
    startPath := prevOpenFolderPath
    FileSelectFile, SelectImg, M2, % startPath, % winTitle, %pattern%
    if (!SelectImg || ErrorLevel)
       Return

    Loop, Parse, SelectImg, `n
    {
       If (A_Index=1)
          SelectedDir := A_LoopField
       Else if (A_Index=2)
          imgPath = %SelectedDir%\%A_LoopField%
       Else if (A_Index>2)
          Break
    }

   if (SelectedDir)
   {
      newStaticFoldersListCache := ""
      prevOpenFolderPath := SelectedDir
      writeMainSettings()
      If RegExMatch(imgPath, "i)(.\.sld)$")
      {
         OpenSLD(imgPath)
         Return
      }

      coreOpenFolder("|" SelectedDir, 0)
      If RegExMatch(imgPath, RegExFilesPattern)
      {
         currentFileIndex := detectFileID(imgPath)
         IDshowImage(currentFileIndex)
         Return
      } Else If (maxFilesIndex>0)
         RandomPicture()
      Else
         resetMainWin2Welcome()
   }
}

OpenArgFile(inputu) {
    imageLoading := 1
    Global scriptStartTime := A_TickCount
    currentFileIndex := 0
    ShowTheImage(inputu, 2)
    Global scriptStartTime := A_TickCount
    zPlitPath(inputu, 0, OutFileName, OutDir)
    If (vpIMGrotation>0)
       zoomu := " @ " vpIMGrotation "°"
    zoomu := " [" Round(zoomLevel * 100) "%" zoomu "]"
    winPrefix := defineWinTitlePrefix()

    SetTimer, GDIupdater, Off
    coreOpenFolder("|" OutDir, 0)
    Global scriptStartTime := A_TickCount
    currentFileIndex := detectFileID(inputu)
    winTitle := winPrefix currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir "\"
    WinSetTitle, ahk_id %PVhwnd%,, % winTitle
    RemoveTooltip()
    ; IDshowImage(currentFileIndex)
    imageLoading := 0
}

addNewFile2list() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    triggerOwnDialogs()
    pattern := "Images (" openFptrn1 ";" openFptrn2 ";" openFptrn3 ")"
    startPath := prevOpenFolderPath
    FileSelectFile, SelectImg, M3, % startPath, Add image file to list, %pattern%
    If (!SelectImg || ErrorLevel)
       Return "cancel"

    CloseWindow()
    Sleep, 50
    showTOOLtip("Please wait...")
    Loop, Parse, SelectImg, `n
    {
       changeMcursor()
       If (A_Index=1)
       {
          SelectedDir := A_LoopField
       } Else
       {
          countFiles++
          imgsListu .= SelectedDir "\" A_LoopField "`n"
       }
    }

   If StrLen(imgsListu)>3
   {
      prevOpenFolderPath := SelectedDir
      writeMainSettings()
      markedSelectFile := ""
      If StrLen(filesFilter)>1
      {
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }
      showTOOLtip("Adding " countFiles " files into the current files list...")
      Loop, Parse, imgsListu, `n
      {
         line := Trim(A_LoopField)
         If StrLen(line)<3
            Continue

         changeMcursor()
         If RegExMatch(line, RegExFilesPattern)
         {
            SLDhasFiles := 1
            maxFilesIndex++
            resultedFilesList[maxFilesIndex] := line
         }
      }
      If (!CurrentSLD && maxFilesIndex>0)
      {
         CurrentSLD := SelectedDir "\newFile.SLD"
         RandomPicture()
      }
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

addNewFolder2list() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    triggerOwnDialogs()
    pattern := "All files (*.*;)"
    startPath := prevOpenFolderPath
    FileSelectFile, SelectImg, S2, %startPath%\this.folder, Add new folder(s) to the list, %pattern%
    if (!SelectImg || ErrorLevel)
       Return "cancel"

   Loop, Parse, SelectImg, `n
   {
       If (A_Index=1)
          SelectedDir := Trim(A_LoopField)
       Else If (A_Index>2)
          Break
   }

   zPlitPath(SelectedDir, 0, OutFileName, OutDir)
   SelectedDir := OutDir
   If (SelectedDir)
   {
      CloseWindow()
      Sleep, 1
      prevOpenFolderPath := SelectedDir
      triggerOwnDialogs()
      MsgBox, 52, %appTitle%, Do you want to scan for files recursively, in all subfolders?
      IfMsgBox, No
        isRecursive := "|"
      coreAddNewFolder(isRecursive SelectedDir, 1)
      If RegExMatch(CurrentSLD, "i)(.\.sld)$")
      {
         FileReadLine, firstLine, % CurrentSLD, 1
         If (!InStr(firstLine, "[General]") || SLDcacheFilesList!=1)
            good2go := "null"
      } Else good2go := "null"

      modus := isRecursive ? 1 : 0
      If (mustGenerateStaticFolders=0 && good2go!="null" && RegExMatch(CurrentSLD, "i)(.\.sld)$"))
         updateCachedStaticFolders(SelectedDir, modus)
      Else mustGenerateStaticFolders := 1

      listu := DynamicFoldersList "`n" isRecursive SelectedDir "`n"
      Sort, listu, UD`n
      DynamicFoldersList := listu
      writeMainSettings()
      If !CurrentSLD
      {
         CurrentSLD := SelectedDir "\newFile.SLD"
         RandomPicture()
      }
   }
}

coreAddNewFolder(SelectedDir, remAll) {
    backCurrentSLD := CurrentSLD
    CurrentSLD := markedSelectFile := ""
    If StrLen(filesFilter)>1
    {
       usrFilesFilteru := filesFilter := ""
       FilterFilesIndex()
    }
    If (remAll=1)
       thisFolder := StrReplace(SelectedDir, "|")
    Else
       thisFolder := SelectedDir
    remFilesFromList(thisFolder, 1)
    GetFilesList(SelectedDir "\*")
    GenerateRandyList()
    SoundBeep , 900, 100
    CurrentSLD := backCurrentSLD
    RandomPicture()
}

detectFileID(imgPath) {
    Loop, % maxFilesIndex + 1
    {
       r := resultedFilesList[A_Index]
       If (r=imgPath)
       {
          good := A_Index
          Break
       }
    }
    If !good
       good := 1

    Return good
}

detectFileIDbkcpList(imgpath) {
    Loop, % bkcpMaxFilesIndex + 1
    {
       r := bckpResultedFilesList[A_Index]
       If (r=imgpath)
       {
          good := A_Index
          Break
       }
    }
    If !good
       good := "fail"

    Return good
}

GuiDropFiles:
   imgpath := folderu := ""
   Loop, Parse, A_GuiEvent, `n
   {
      changeMcursor()
      line := Trim(A_LoopField)
;     MsgBox, % A_LoopField
      If (A_Index>9500)
         Break
      Else If RegExMatch(line, RegExFilesPattern) || RegExMatch(line, "i)(.\.sld)$")
         imgpath := line
      Else If InStr(FileExist(line), "D")
         folderu .= line "`n"
   }

   if (imgPath)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()
      zPlitPath(imgPath, 0, OutFileName, OutDir)
 
      If !OutDir
         Return

      CloseWindow()
      showTOOLtip("Opening file...`n" imgPath)
      newStaticFoldersListCache := markedSelectFile := ""
      If StrLen(filesFilter)>1
      {
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      coreOpenFolder("|" OutDir, 0)
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
      SetTimer, RemoveTooltip, % -msgDisplayTime
   } Else If StrLen(folderu)>3
   {
      mainFoldersListu := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
      CloseWindow()
      If (slideShowRunning=1)
         ToggleSlideShowu()
      markedSelectFile := ""
      showTOOLtip("Opening folders, please wait...")
      If StrLen(filesFilter)>1
      {
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      Loop, Parse, folderu, `n
      {
          linea := Trim(A_LoopField)
          If StrLen(linea)<4
             Continue
          changeMcursor()
          warningMsg := 0
          Loop, Parse, mainFoldersListu, `n
          {
              line := Trim(A_LoopField)
              If StrLen(line)<4
                 Continue
              If (line=linea)
                 warningMsg := 1
          }

          If (warningMsg=1)
             Continue

          stuffAdded := 1
          GetFilesList(linea "\*")
          DynamicFoldersList .= linea "`n" 
          lastOne := linea
      }
      If (stuffAdded=1)
      {
         newStaticFoldersListCache := ""
         mustGenerateStaticFolders := 1
         GenerateRandyList()
      }
      If !CurrentSLD
         CurrentSLD := lastOne "\newFile.SLD"
      Try DllCall("user32\SetCursor", "Ptr", hCursN)
      SoundBeep , 900, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      RandomPicture()
   }
Return

dummyShowToolTip() {
   showTOOLtip("nully")
}

showTOOLtip(msg) {
   Critical, on
   Static prevMsg
   If (msg="nully" && prevMsg)
      msg := prevMsg

   prevMsg := msg
   If (AnyWindowOpen>0 && WinActive("A")=hSetWinGui)
   {
      Tooltip, %msg%
   } Else If (identifyThisWin()=1 && noTooltipMSGs=0)
   {
      TooltipCreator(msg)
   } Else
   {
      msg := StrReplace(msg, "`n", "  ")
      WinSetTitle, ahk_id %PVhwnd%,, % msg
   }
}

RemoveTooltip() {
   Tooltip
   TooltipCreator(1, 1)

   If (noTooltipMSGs=1)
   {
      If (CurrentSLD)
         winTitle := appTitle ": " currentFileIndex "/" maxFilesIndex " | " CurrentSLD
      Else
         winTitle := appTitle " v" version
      WinSetTitle, ahk_id %PVhwnd%,, % winTitle 
   }
}

GetImgFileDimension(imgPath, ByRef W, ByRef H, fastWay:=1) {
   Static prevImgPath, prevW, prevH
   thisImgPath := generateThumbName(imgpath, 1) fastWay
   If (prevImgPath=thisImgPath && prevH>1 && prevW>1)
   {
      W := prevW
      H := prevH
      Return 1
   }

   prevImgPath := thisImgPath
   changeMcursor()
   pBitmap := LoadBitmapFromFileu(imgPath, fastWay)
   prevW := W := Gdip_GetImageWidth(pBitmap)
   prevH := H := Gdip_GetImageHeight(pBitmap)
   If pBitmap
      Gdip_DisposeImage(pBitmap, 1)
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   r := (w>1 && h>1) ? 1 : 0
   Return r
}

BuildTray() {
   Menu, Tray, NoStandard
   Menu, Tray, Add, &Open File`tShift+O, OpenFiles
   Menu, Tray, Add, &Open Folders`tCtrl+O, OpenFolders
   Menu, Tray, Add,
   Menu, Tray, Add, &More options, BuildMenu
   Menu, Tray, Add,
   Menu, Tray, Add, &About, AboutWindow
   Menu, Tray, Add,
   Menu, Tray, Add, &Exit`tEsc, Cleanup
}

associateSLDsNow() {
  FileAssociate("QPVslideshow",".sld", fullPath2exe)
}

associateWithImages() {
  Static FileFormatsCommon := "png|bmp|gif|jpg|tif|tga|webp|jpeg|tiff|exr|hdr|psd"
       , allFormats := "dib|tif|tiff|emf|wmf|rle|png|bmp|gif|jpg|jpeg|jpe|DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f|jfif"

  Loop, Parse, FileFormatsCommon, "|"
  {
      If !A_LoopField
         Continue

      FileAssociate("QPVimage." A_LoopField,"." A_LoopField, fullPath2exe,,1)
  }
  Sleep, 25
  RunWait, *RunAs %mainCompiledPath%\regFiles\runThis.bat
  Sleep, 5
  FileDelete, %mainCompiledPath%\regFiles\*.reg
  FileDelete, %mainCompiledPath%\regFiles\*.bat

  MsgBox, 36, %appTitle%, %appTitle% was now associated with common image file formats. Would you like to associate it with all the 85 supported file formats?
  IfMsgBox, Yes
  {
    Loop, Parse, allFormats, "|"
    {
        If !A_LoopField
           Continue

        FileAssociate("QPVimage." A_LoopField,"." A_LoopField, fullPath2exe,,1)
    }

    Sleep, 25
    RunWait, *RunAs %mainCompiledPath%\regFiles\runThis.bat
    Sleep, 5
    FileDelete, %mainCompiledPath%\regFiles\*.reg
    FileDelete, %mainCompiledPath%\regFiles\*.bat
  }

}

restartAppu() {
   TrueCleanup()
   Try Reload
   Sleep, 50
   ExitApp
}

InitGuiContextMenu() {
   If (slideShowRunning=1)
      ToggleSlideShowu()
   If (GIFsGuiCreated=1)
      DestroyGIFuWin()

   SetTimer, BuildMenu, -5
   ; WinActivate, ahk_id %PVhwnd%
}

BuildMenu() {
   Static lastInvoked := 1
   If (AnyWindowOpen)
   {
      If (A_TickCount - lastInvoked < 950)
         CloseWindow()
      Else
         WinActivate, ahk_id %hSetWinGui%
      lastInvoked := A_TickCount
      Return
   }

   SetTimer, drawWelcomeImg, Off
   deleteMenus()
   Global lastWinDrag := A_TickCount
   ForceRegenStaticFolders := 0
   sliSpeed := Round(slideShowDelay/1000, 2) " sec."
   Menu, PVsliMenu, Add, &Start slideshow`tSpace, dummyInfoToggleSlideShowu
   Menu, PVsliMenu, Add, Smoot&h transitions, ToggleSlidesTransitions
   Menu, PVsliMenu, Add, &Easy slideshow stopping, ToggleEasySlideStop
   Menu, PVsliMenu, Add, De&fine slideshow duration`tShift+[`,], defineEntireSlideshowDurationPanel
   Menu, PVsliMenu, Add, % EstimateSlideShowLength(), dummy
   Menu, PVsliMenu, Disable, % EstimateSlideShowLength()
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Toggle slideshow mode`tS, SwitchSlideModes
   Menu, PVsliMenu, Add, % DefineSlideShowType(), SwitchSlideModes
   Menu, PVsliMenu, Disable, % DefineSlideShowType()
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Increase speed`tComma [`,], IncreaseSlideSpeed
   Menu, PVsliMenu, Add, &Decrease speed`tDot [.], DecreaseSlideSpeed
   Menu, PVsliMenu, Add, Current speed: %sliSpeed%, DecreaseSlideSpeed
   Menu, PVsliMenu, Disable, Current speed: %sliSpeed%
   If (doSlidesTransitions=1)
      Menu, PVsliMenu, Check, Smoot&h transitions
   If (easySlideStoppage=1)
      Menu, PVsliMenu, Check, &Easy slideshow stopping

   infolumosAdjust := (imgFxMode=2 || imgFxMode=3) ? Round(lumosAdjust, 2) : Round(lumosGrayAdjust, 2)
   infoGammosAdjust := (imgFxMode=2 || imgFxMode=3) ? Round(GammosAdjust, 2) : Round(GammosGrayAdjust, 2)
   infoSatAdjust := (imgFxMode=4) ? zatAdjust : Round(satAdjust*100)
   infoThumbsMode := (thumbsDisplaying=1) ? "Switch to image view" : "Switch to thumbnails list"
   If (maxFilesIndex>1)
      Menu, PVview, Add,  %infoThumbsMode%`tEnter/MClick, MenuDummyToggleThumbsMode

   If (thumbsDisplaying=1)
   {
      infoThumbZoom := thumbsW "x" thumbsH " (" Round(thumbsZoomLevel*100) "%)"
      Menu, PVview, Add,
      Menu, PVview, Add, &Toggle aspect ratio`tT, ChangeThumbsAratio
      Menu, PVview, Add, % defineThumbsAratio(), ChangeThumbsAratio
      Menu, PVview, Disable, % defineThumbsAratio()
      Menu, PVview, Add,
      Menu, PVview, Add, Thumbnails size:, ChangeThumbsAratio
      Menu, PVview, Disable, Thumbnails size:
      Menu, PVview, Add, % infoThumbZoom, ChangeThumbsAratio
      Menu, PVview, Disable, % infoThumbZoom
   } Else
   {
      Menu, PVview, Add, Image view panel`tU, ColorsAdjusterPanelWindow
      Menu, PVview, Add, &Show selection`tD, ToggleEditImgSelection
      If (activateImgSelection=1)
         Menu, PVview, Check, &Show selection`tD
      Menu, PVview, Add,
      Menu, PVview, Add, Remove alpha channel, ToggleRenderOpaque
      Menu, PVview, Add, Image &rotation: %vpIMGrotation%°`t9`, 0, MenuChangeImgRotationInVP
      Menu, PVview, Add, Image &alignment: %imageAligned%`tA, ToggleIMGalign
      Menu, PVview, Add, % defineImgAlign(), ToggleIMGalign
      Menu, PVview, Disable, % defineImgAlign()
      Menu, PVview, Add,
      Menu, PVview, Add, &Toggle color depth`tQ, ToggleImgColorDepth
      Menu, PVview, Add, % defineColorDepth(), ToggleImgColorDepth
      Menu, PVview, Disable, % defineColorDepth()
      Menu, PVview, Add, &Toggle resizing mode`tT, ToggleImageSizingMode
      Menu, PVview, Add, % DefineImgSizing(), ToggleImageSizingMode
      Menu, PVview, Disable, % DefineImgSizing()
      If !InStr(currentPixFmt, "argb")
         Menu, PVview, Disable, Remove alpha channel
      If (RenderOpaqueIMG=1)
         Menu, PVview, Check, Remove alpha channel

      If (IMGresizingMode=4)
         Menu, PVview, Disable, Image &alignment: %imageAligned%`tA
   }
   Menu, PVview, Add,
   Menu, PVview, Add, &Toggle colors display mode`tF, ToggleImgFX
   Menu, PVview, Add, % DefineFXmodes(), ToggleImgFX
   Menu, PVview, Disable, % DefineFXmodes()
   If (imgFxMode=2 || imgFxMode=3 || imgFxMode=4)
   {
      Menu, PVview, Add, Br: %infolumosAdjust% / Ctr: %infoGammosAdjust% / dS: %infoSatAdjust%, ToggleImgFX
      Menu, PVview, Disable, Br: %infolumosAdjust% / Ctr: %infoGammosAdjust% / dS: %infoSatAdjust%
   }

   Menu, PVview, Add,
   If (thumbsDisplaying!=1)
   {
      Menu, PVview, Add, Mirror &horizontally`tH, TransformIMGh
      Menu, PVview, Add, Mirror &vertically`tV, TransformIMGv
      Menu, PVview, Add,
      Menu, PVview, Add, Reset image vie&w`t\, ResetImageView
      If (FlipImgV=1)
         Menu, PVview, Check, Mirror &vertically`tV
 
      If (FlipImgH=1)
         Menu, PVview, Check, Mirror &horizontally`tH
   }

   Menu, PVnav, Add, &Skip missing files, ToggleSkipDeadFiles
   If (skipDeadFiles=1)
      Menu, PVnav, Check, &Skip missing files

   Menu, PVnav, Add,
   Menu, PVnav, Add, &First`tHome, FirstPicture
   Menu, PVnav, Add, &Previous`tRight, PreviousPicture
   Menu, PVnav, Add, &Next`tLeft, NextPicture
   Menu, PVnav, Add, &Last`tEnd, LastPicture
   If (totalFramesIndex>0)
   {
      Menu, PVnav, Add,
      Menu, PVnav, Add, &Next frame`tPage Up, nextDesiredFrame
      Menu, PVnav, Add, &Previous frame`tPage Down, prevDesiredFrame
   }
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Jump at #`tCtrl+J, Jump2index
   Menu, PVnav, Add, &Random`tR, RandomPicture
   Menu, PVnav, Add, &Prev. random image`tBackspace, PrevRandyPicture

   Menu, PVselv, Add, &Relative coordinates, toggleImgSelCoords
   Menu, PVselv, Add, 
   Menu, PVselv, Add, &Show selection`tD, toggleImgSelection
   If (relativeImgSelCoords=1)
      Menu, PVselv, Check, &Relative coordinates
   If (activateImgSelection=1)
      Menu, PVselv, Check, &Show selection`tD
   Menu, PVselv, Add, &Edit selection`tE, ToggleEditImgSelection
   If (editingSelectionNow=1)
      Menu, PVselv, Check, &Edit selection`tE
   Menu, PVselv, Add, &Drop selection`tCtrl+D, resetImgSelection
   Menu, PVselv, Add, &Reset selection, newImgSelection
   Menu, PVselv, Add, &Select all`tCtrl+A, selectEntireImage
   Menu, PVselv, Add, 
   Menu, PVselv, Add, &Copy to Clipboard`tCtrl+C, CopyImage2clip

   StringRight, infoPrevMovePath, prevFileMovePath, 25
   Menu, PVtFile, Add, &Save image as...`tCtrl+Shift+S, BtnSaveIMG
   If (activateImgSelection!=1)
      Menu, PVtFile, Add, &Copy image to clipboard`tCtrl+C, CopyImage2clip
   Menu, PVtFile, Add, &Copy file path to clipboard`tShift+C, CopyImagePath
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, &Open with external app`tO, OpenThisFile
   Menu, PVtFile, Add, &Explore containing folder`tCtrl+E, OpenThisFileFolder
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, Select/deselect file`tTab, MenuMarkThisFileNow
   If markedSelectFile
      Menu, PVtFile, Add, Compare images`tB, CompareImagesAB

   file2rem := resultedFilesList[currentFileIndex]
   Menu, PVtFile, Add, &Convert format to...`tCtrl+K, converterPanelWindow
   If RegExMatch(file2rem, "i)(.\.(jpg|jpeg))$")
      Menu, PVtFile, Add, &JPEG lossless operations`tK, PanelJpegPerformOperation
   Menu, PVtFile, Add, &Resize/rotate/crop image`tCtrl+R, ResizeImagePanelWindow
   Menu, PVtFile, Add, &Auto-crop image`tY, AutoCropPanelWindow
   Menu, PVtFile, Add, &Delete file`tDelete, DeletePicture
   Menu, PVtFile, Add, &Rename file`tF2, RenameThisFile
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Move file to...`tM, InvokeMoveFiles
   Menu, PVtFile, Add, &Copy file to...`tC, InvokeCopyFiles
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Information`tShift+I, ShowImgInfosPanel

   Menu, PVsort, Add, File details, dummy
   Menu, PVsort, Disable, File details
   Menu, PVsort, Add, &Path and name, ActSortName
   Menu, PVsort, Add, &File size, ActSortSize
   Menu, PVsort, Add, &Modified date, ActSortModified
   Menu, PVsort, Add, &Created date, ActSortCreated
   Menu, PVsort, Add
   Menu, PVsort, Add, Image information (slow), dummy
   Menu, PVsort, Disable, Image information (slow)
   Menu, PVsort, Add, &Resolution, PanelResolutionSorting
   Menu, PVsort, Add, &Histogram average, ActSortHistogramAvg
   Menu, PVsort, Add, &Histogram median, ActSortHistogramMedian
   Menu, PVsort, Add, &Similarity (very slow), ActSortSimilarity
   Menu, PVsort, Add, 
   Menu, PVsort, Add, R&everse list, ReverseListNow
   Menu, PVsort, Add, R&andomize  list, RandomizeListNow

   defMenuRefresh := RegExMatch(CurrentSLD, "i)(\.sld)$") ? "&Reload .SLD file" : "&Refresh opened folder(s)"
   StringRight, defMenuRefreshItm, CurrentSLD, 30
   If defMenuRefreshItm
   {
      Menu, PVfList, Add, %defMenuRefresh%`tShift+F5, RefreshFilesList
      If RegExMatch(CurrentSLD, "i)(\.sld)$")
      {
         Menu, PVfList, Add, %defMenuRefreshItm%, RefreshFilesList
         Menu, PVfList, Disable, %defMenuRefreshItm%
      }
   }
   Menu, PVfList, Add,
   If (maxFilesIndex>1)
   {
      Menu, PVfList, Add, Insert file(s)`tInsert, addNewFile2list
      Menu, PVfList, Add, Add folder(s)`tShift+Insert, addNewFolder2list
      Menu, PVfList, Add, Manage folder(s) list`tAlt+U, DynamicFolderzPanelWindow
   }

   If (maxFilesIndex>2)
   {
      Menu, PVfList, Add, Remove current file entry`tAlt+Delete, InListMultiEntriesRemover
      Menu, PVfList, Add, Auto-remove entries of dead files, ToggleAutoRemEntries
      If (autoRemDeadEntry=1)
         Menu, PVfList, Check, Auto-remove entries of dead files
      Menu, PVfList, Add,
      Menu, PVfList, Add, Save list as slideshow (.SLD)`tCtrl+S, SaveFilesList
      Menu, PVfList, Add, Cache files list in .SLD file, ToggleSLDcache
      If (SLDcacheFilesList=1)
         Menu, PVfList, Check, Cache files list in .SLD file
      Menu, PVfList, Add,
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && SLDhasFiles=1)
         Menu, PVfList, Add, &Clean duplicate/inexistent entries, cleanFilesList
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && StrLen(DynamicFoldersList)>6)
         Menu, PVfList, Add, &Regenerate the entire list, RegenerateEntireList
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && mustGenerateStaticFolders!=1 && SLDcacheFilesList=1)
         Menu, PVfList, Add, &Update files list selectively`tCtrl+U, FolderzPanelWindow
      Menu, PVfList, Add, &Text filtering`tCtrl+F, enableFilesFilter
      If StrLen(filesFilter)>1
      {
         Menu, PVfList, Check, &Text filtering`tCtrl+F
         Menu, PVfList, Add, &Invert applied filter, invertFilesFilter
      }
      Menu, PVfList, Add,
      If (thumbsDisplaying!=1)
         Menu, PVfList, Add, &Sort by, :PVsort
   }

   Menu, PVprefs, Add, Save settings into a .SLD file, WritePrefsIntoSLD
   Menu, PVprefs, Add, &Never load settings from a .SLD, ToggleIgnoreSLDprefs
   If A_IsCompiled
   {
      Menu, PVprefs, Add, 
      Menu, PVprefs, Add, Associate with .SLD files, associateSLDsNow
      Menu, PVprefs, Add, Associate with image files, associateWithImages
   }

   Menu, PVprefs, Add, 
   Menu, PVprefs, Add, &High quality image resampling, ToggleImgQuality
   Menu, PVprefs, Add, &Load Camera RAW files in high quality, ToggleRAWquality
   Menu, PVprefs, Add, Load an&y image format using FreeImage, ToggleAlwaysFIMus
   Menu, PVprefs, Add, 
   If (thumbsDisplaying!=1)
   {
      Menu, PVprefs, Add, An&imated GIFs support (experimental), ToggleAnimGIFsupport
      If (animGIFsSupport=1)
         Menu, PVprefs, Check, An&imated GIFs support (experimental)
   }
   Menu, PVprefs, Add, 
   If InStr(FileExist(thumbsCacheFolder), "D")
      Menu, PVprefs, Add, Erase cached thumbnails, OlderThanEraseThumbsCache
   Menu, PVprefs, Add, Cache / store generated thumbnails, ToggleThumbsCaching
   If (userHQraw=1)
      Menu, PVprefs, Check, &Load Camera RAW files in high quality
   If (alwaysOpenwithFIM=1)
      Menu, PVprefs, Check, Load an&y image format using FreeImage
   If (enableThumbsCaching=1)
      Menu, PVprefs, Check, Cache / store generated thumbnails
   Menu, PVprefs, Add, &Prompt before file delete, TogglePromptDelete
   If (askDeleteFiles=1)
      Menu, PVprefs, Check, &Prompt before file delete
   If (MustLoadSLDprefs=0)
      Menu, PVprefs, Check, &Never load settings from a .SLD
   If (userimgQuality=1)
      Menu, PVprefs, Check, &High quality image resampling

   readRecentEntries()
   Menu, PVopenF, Add, &Image file(s) or slideshow`tCtrl+O, OpenFiles
   Menu, PVopenF, Add, &Camera RAW file(s)`tAlt+O, OpenRawFiles
   Menu, PVopenF, Add, &Folder(s)`tShift+O, OpenFolders
   Menu, PVopenF, Add,
   If (maxFilesIndex<1 || !CurrentSLD)
      Menu, PVopenF, Add, Insert file(s)`tInsert, addNewFile2list
   Menu, PVopenF, Add, Paste clipboard`tCtrl+V, PasteClipboardIMG
   Menu, PVopenF, Add,
   Loop, Parse, historyList, `n
   {
      If (A_Index>15)
         Break

      If !A_LoopField
         Continue

      countItemz++
      testThis := StrReplace(A_LoopField, "|")
      entryu := SubStr(A_LoopField, -30)
      If InStr(A_LoopField, "|") && !RegExMatch(A_LoopField, "i)(\.sld)$")
         entryu .= "\" ; entryu
      If !InStr(A_LoopField, "|") && !RegExMatch(A_LoopField, "i)(\.sld)$")
         entryu .= " (*)"
      If FileExist(testThis)
         Menu, PVopenF, Add, &%countItemz%. %entryu%, OpenRecentEntry
   }

   If (countItemz>0)
   {
      Menu, PVopenF, Add, 
      Menu, PVopenF, Add, &Erase history, EraseHistory
   }

   Menu, PVopenF, Add, 
   If (StrLen(prevFileSavePath)>3 && FileExist(prevFileSavePath))
      aListu := prevFileSavePath "`n"
   If (StrLen(prevFileMovePath)>3 && FileExist(prevFileMovePath) && !InStr(aListu, prevFileMovePath "`n"))
      aListu .= prevFileMovePath "`n"
   If (StrLen(prevOpenFolderPath)>3 && FileExist(prevOpenFolderPath) && !InStr(aListu, prevOpenFolderPath "`n"))
      aListu .= prevOpenFolderPath "`n"
   Loop, Parse, aListu, `n
   {
      If !A_LoopField
         Continue
      Menu, PVopenF, Add, % "O" A_Index ". " SubStr(A_LoopField, -30), OpenRecentEntry
   }

   Menu, PVsounds, Add, Play associated sound file`tX, PlayAudioFileAssociatedNow
   Menu, PVsounds, Add, Stop playing`tShift+X, StopMediaPlaying
   If !hSNDmedia
      Menu, PVsounds, Disable, Stop playing`tShift+X
   Menu, PVsounds, Add, 
   Menu, PVsounds, Add, Auto-play sound files, ToggleAutoPlaySND
   If (autoPlaySNDs=1)
      Menu, PVsounds, Check, Auto-play sound files
   Menu, PVsounds, Add, Slideshow speed based on sound files duration, ToggleAutoPlaySNDslideDuration
   If (syncSlideShow2Audios=1)
      Menu, PVsounds, Check, Slideshow speed based on sound files duration
   If (autoPlaySNDs!=1)
      Menu, PVsounds, Disable, Slideshow speed based on sound files duration
   Menu, PVsounds, Add, 
   Menu, PVsounds, Add, Change audio volume`t1`,2, ChangeVolume
   Menu, PVsounds, Add, Audio volume: %mediaSNDvolume%`%, dummy
   Menu, PVsounds, Disable, Audio volume: %mediaSNDvolume%`%

; the main menu
   clippyTest := resultedFilesList[0]
   Menu, PVmenu, Add, &Open..., :PVopenF
   If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
      Menu, PVmenu, Add, &Save image...`tCtrl+S, SaveClipboardImage
   Menu, PVmenu, Add,
   If (thumbsDisplaying!=1 && activateImgSelection!=1 && imgSelX2=-1 && imgSelY2=-1 && CurrentSLD)
      Menu, PVmenu, Add, Create selection`tE, newImgSelection
   Else If (thumbsDisplaying!=1 && activateImgSelection!=1 && CurrentSLD)
      Menu, PVmenu, Add, Edit selection`tE, ToggleEditImgSelection
   If (maxFilesIndex>0 && CurrentSLD)
   {
      infoThisFile := markedSelectFile ? "C&urrent files" : "C&urrent file"
      If (thumbsDisplaying!=1 && activateImgSelection=1)
         Menu, PVmenu, Add, Selec&tion, :PVselv
      Menu, PVmenu, Add, % infoThisFile, :PVtFile
      Menu, PVmenu, Add, Files index/l&ist, :PVfList
      If (thumbsDisplaying=1 && maxFilesIndex>1)
         Menu, PVmenu, Add, &Sort by, :PVsort
      Menu, PVmenu, Add, Image vie&w, :PVview
      If (thumbsDisplaying!=1)
         Menu, PVmenu, Add, Sounds, :PVsounds
      If (maxFilesIndex>1 && CurrentSLD)
      {
         Menu, PVmenu, Add, Navigation, :PVnav
         If (thumbsDisplaying!=1)
            Menu, PVmenu, Add, Slideshow, :PVsliMenu
      }
      Menu, PVmenu, Add,
   } Else If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
   {
      If (activateImgSelection=1 && thumbsDisplaying!=1)
         Menu, PVmenu, Add, Selec&tion, :PVselv
      Menu, PVmenu, Add, Image vie&w, :PVview
   }

   createInterfaceMenuOptions()
   Menu, PVmenu, Add, Inter&face, :PvUIprefs
   Menu, PVmenu, Add, Prefe&rences, :PVprefs
   If markedSelectFile
      Menu, PVmenu, Add, Dro&p files selections`tShift+Tab, dropFilesSelection
   Menu, PVmenu, Add, About`tF1, AboutWindow
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, Restart`tShift+Esc, restartAppu
   Menu, PVmenu, Add, &Exit`tEsc, Cleanup
   showThisMenu("PVmenu")
}

showThisMenu(menarg) {
   o_isTitleBarHidden := isTitleBarHidden
   isTitleBarHidden := 0
   Suspend, On
   Menu, % menarg, Show
   Suspend, Off
   Global lastWinDrag := A_TickCount
   Global lastOtherWinClose := A_TickCount
   isTitleBarHidden := o_isTitleBarHidden
}

deleteMenus() {
    Static menusList := "PVmenu|PVsliMenu|PVnav|PVview|PVfList|PVtFile|PVprefs|PvUIprefs|PVopenF|PVsort|PVselv|PVsounds"
    Loop, Parse, menusList, |
    {
        If !A_LoopField
           Continue

        Menu, % A_LoopField, UseErrorLevel
        Menu, % A_LoopField, Delete
    }
}

createInterfaceMenuOptions() {
   Menu, PvUIprefs, Add, &Touch screen mode, ToggleTouchMode
   Menu, PvUIprefs, Add, &Large UI fonts, ToggleLargeUIfonts
   Menu, PvUIprefs, Add, &Always on top, ToggleAllonTop
   Menu, PvUIprefs, Add, &Hide title bar, ToggleTitleBaru
   Menu, PvUIprefs, Add, &No OSD information, ToggleInfoToolTips
   If (maxFilesIndex>0 && CurrentSLD && thumbsDisplaying!=1)
   {
      Menu, PvUIprefs, Add, &OSD image info-box`tI, ToggleInfoBoxu
      Menu, PvUIprefs, Add, I&mage luminance histogram`tShift+H, ToggleImgHistogram
      Menu, PvUIprefs, Add, &Ambiental textured background, ToggleTexyBGR
      If (showHistogram=1)
         Menu, PvUIprefs, Check, I&mage luminance histogram`tShift+H
      If (showInfoBoxHUD=1)
         Menu, PvUIprefs, Check, &OSD image info-box
 
      If (usrTextureBGR=1)
         Menu, PvUIprefs, Check, &Ambiental textured background
   }

   If !AnyWindowOpen
   {
      Menu, PvUIprefs, Add, 
      Menu, PvUIprefs, Add, Additional settings`tF12, PrefsPanelWindow
   }

   If (TouchScreenMode=1)
      Menu, PvUIprefs, Check, &Touch screen mode
   If (PrefsLargeFonts=1)
      Menu, PvUIprefs, Check, &Large UI fonts
   If (isAlwaysOnTop=1)
      Menu, PvUIprefs, Check, &Always on top
   If (noTooltipMSGs=1)
      Menu, PvUIprefs, Check, &No OSD information
   If (getCaptionStyle()=1)
      Menu, PvUIprefs, Check, &Hide title bar
}

EraseHistory() {
   historyList := ""
   Loop, 15
       IniWrite, 0, % mainSettingsFile, Recents, E%A_Index%
}

OpenRecentEntry() {
  testOs := A_ThisMenuItem
  If RegExMatch(testOs, "i)^(o1\. )")
  {
     coreOpenFolder("|" prevFileSavePath)
     Return
  } Else If RegExMatch(testOs, "i)^(o2\. )")
  {
     coreOpenFolder("|" prevFileMovePath)
     Return
  } Else If RegExMatch(testOs, "i)^(o3\. )")
  {
     coreOpenFolder("|" prevOpenFolderPath)
     Return
  }

  openThisu := SubStr(testOs, 2, InStr(testOs, ". ")-2)
  IniRead, newEntry, % mainSettingsFile, Recents, E%openThisu%, @
; MsgBox, %openthisu% -- %newentry%
  newEntry := Trim(newEntry)
  If StrLen(newEntry)>4
  {
     If RegExMatch(newEntry, "i)(\.sld)$")
     {
        OpenSLD(newEntry)
     } Else
     {
        prevOpenFolderPath := StrReplace(newEntry, "|")
        coreOpenFolder(newEntry)
     }
  }
}

ToggleAllonTop() {
   isAlwaysOnTop := !isAlwaysOnTop
   If (isAlwaysOnTop=1)
      WinSet, AlwaysOnTop, On, ahk_id %PVhwnd%
   Else
      WinSet, AlwaysOnTop, Off, ahk_id %PVhwnd%
   writeMainSettings()
}

ToggleEasySlideStop() {
   easySlideStoppage := !easySlideStoppage
   writeMainSettings()
}

ToggleAutoPlaySND() {
   autoPlaySNDs := !autoPlaySNDs
   writeMainSettings()
}

ToggleAutoPlaySNDslideDuration() {
   syncSlideShow2Audios := !syncSlideShow2Audios
   writeMainSettings()
}

ToggleSlidesTransitions() {
   doSlidesTransitions := !doSlidesTransitions
   writeMainSettings()
}

ToggleInfoBoxu() {
   showInfoBoxHUD := !showInfoBoxHUD
   writeMainSettings()
   dummyTimerDelayiedImageDisplay(50)
}

toggleImgSelCoords() {
   relativeImgSelCoords := !relativeImgSelCoords
   calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)
   writeMainSettings()
}

ToggleRenderOpaque() {
   RenderOpaqueIMG := !RenderOpaqueIMG
   writeMainSettings()
   If InStr(currentPixFmt, "argb")
      RefreshImageFile()
}

ToggleAlwaysFIMus() {
   alwaysOpenwithFIM := !alwaysOpenwithFIM
   r := initFIMGmodule()
   If InStr(r, "err - 126")
      friendly := "`n`nPlease install the Runtime Redistributable Packages of Visual Studio 2015."
   Else If InStr(r, "err - 404")
      friendly := "`n`nThe FreeImage.dll file seems to be missing..."
   writeMainSettings()

   If (FIMfailed2init=1)
   {
      triggerOwnDialogs()
      Msgbox, 48, %appTitle%, ERROR: The FreeImage library failed to properly initialize. Various image file formats will no longer be supported. Error code: %r%.%friendly%
   } Else RefreshImageFile()
}

ToggleAnimGIFsupport() {
   animGIFsSupport := !animGIFsSupport
   writeMainSettings()
}

ToggleAutoRemEntries() {
   autoRemDeadEntry := !autoRemDeadEntry
   writeMainSettings()
}

ToggleSLDcache() {
   SLDcacheFilesList := !SLDcacheFilesList
   writeMainSettings()
}

TogglePromptDelete() {
   askDeleteFiles := !askDeleteFiles
   writeMainSettings()
}

ToggleTitleBaruNow() {
   If (getCaptionStyle()=0)
   {
      isTitleBarHidden := 1
      If (editingSelectionNow=1)
        ToggleEditImgSelection()
      Gui, 1: -Caption
   } Else
   {
      isTitleBarHidden := 0
      Gui, 1: +Caption
   }
   writeMainSettings()
}

ToggleTitleBaru() {
   SetTimer, ToggleTitleBaruNow, -150
}

ToggleInfoToolTips() {
    noTooltipMSGs := !noTooltipMSGs
    writeMainSettings()
}

ToggleLargeUIfonts() {
    PrefsLargeFonts := !PrefsLargeFonts
    If (AnyWindowOpen=14)
       PrefsPanelWindow()

    imgHUDbaseUnit := (PrefsLargeFonts=1) ? Round(OSDfntSize*6.5) : Round(OSDfntSize*5.25)
    writeMainSettings()
}

ToggleTexyBGR() {
    usrTextureBGR := !usrTextureBGR
    RefreshImageFile()
    writeMainSettings()
}

ToggleImgHistogram() {
    showHistogram := !showHistogram
    writeMainSettings()
    dummyTimerDelayiedImageDisplay(50)
}

ToggleThumbsCaching() {
    enableThumbsCaching := !enableThumbsCaching
    writeMainSettings()
}

ToggleSkipDeadFiles() {
    skipDeadFiles := !skipDeadFiles
    writeMainSettings()
}

ToggleIgnoreSLDprefs() {
    MustLoadSLDprefs := !MustLoadSLDprefs
    writeMainSettings()
}

ToggleImgQuality() {
    userimgQuality := !userimgQuality
    imgQuality := (userimgQuality=1) ? 7 : 5
    Gdip_SetInterpolationMode(glPG, imgQuality)
    writeMainSettings()
}

ToggleRAWquality() {
    userHQraw := !userHQraw
    writeMainSettings()
}

ToggleTouchMode() {
    TouchScreenMode := !TouchScreenMode
    writeMainSettings()
}

defineWinTitlePrefix() {
   Static FXmodesLabels := {2:"cP", 3:"cAUTO", 4:"cGR", 5:"cR", 6:"cG", 7:"cB", 8:"cA", 9:"cI"}

   If StrLen(usrFilesFilteru)>1
      winPrefix .= "F "

   If hSNDmedia
      winPrefix .= "(A) "

   If (activateImgSelection=1)
      winPrefix .= "SEL "

   If (slideShowRunning=1)
   {
      winPrefix .= "s"
      If (SlideHowMode=1)
         winPrefix .= "R "
      Else If (SlideHowMode=2)
         winPrefix .= "B "
      Else If (SlideHowMode=3)
         winPrefix .= "F "
   }
   If (usrColorDepth>1)
      winPrefix .= internalColorDepth  " bits "

   If (FlipImgV=1)
      winPrefix .= "V "
   If (FlipImgH=1)
      winPrefix .= "H "

   If FXmodesLabels.HasKey(imgFxMode)
      winPrefix .= FXmodesLabels[imgFxMode] A_Space

   If (IMGresizingMode=3)
      winPrefix .= "O "
   Else If (IMGresizingMode=4)
      winPrefix .= "Z "

   Return winPrefix
}

SetParentID(Window_ID, theOther) {
  r := DllCall("SetParent", "uint", theOther, "uint", Window_ID) ; success = handle to previous parent, failure =null 
  Return r
}

drawWelcomeImg() {
    Critical, on
    clippyTest := resultedFilesList[0]
    If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
       thisClippyIMG := 1

    If (maxFilesIndex>0 || thisClippyIMG=1 || StrLen(CurrentSLD)>1 || AnyWindowOpen>0)
       Return

    If (A_TickCount - scriptStartTime>450)
    {
       If (identifyThisWin()!=1)
          Return
    }

    thisZeit := A_TickCount
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    pBr1 := Gdip_BrushCreateSolid(0x33882211)
    pBr2 := Gdip_BrushCreateSolid(0x33112288)
    pBr3 := Gdip_BrushCreateSolid(0x33118822)
    pBr4 := Gdip_BrushCreateSolid(0x66030201)
    pBr5 := Gdip_BrushCreateSolid(0x88939291)
    Gdip_FillRectangle(glPG, pBrushWinBGR, 0, 0, mainWidth, mainHeight)
    If GetKeyState("CapsLock", "T")
       Gdip_FillRectangle(glPG, pBr5, 0, 0, mainWidth, mainHeight)

    Random, modelu, 1, 6
    Random, iterations, 10, 30
    If (modelu=1)
    {
       Loop, % iterations
       {  
          Random, xPos, 5, % mainWidth
          Random, yPos, 5, % mainHeight
          Random, w, 5, % mainWidth
          Random, h, 5, % mainHeight
          w += 10
          h += 10
          Random, tBrsh, 1, 3
          Gdip_FillRectangle(glPG, pBr%tBrsh%, xPos, yPos, w, h)
       }
    } Else If (modelu=2)
    {
       Loop, % iterations
       {  
          Random, xPos, 5, % mainWidth
          Random, yPos, 5, % mainHeight
          Random, w, 5, % mainWidth//2 + mainHeight//2
          w += 5
          h := w
          Random, tBrsh, 1, 3
          Gdip_FillEllipse(glPG, pBr%tBrsh%, xPos, yPos, w, h)
       }
    } Else If (modelu=3 || modelu=5)
    {
       Random, moduz, 1, 9
       Loop, % iterations
       {  
          Random, w, 5, % mainWidth//1.5 + mainHeight//1.5
          w += 5
          h := w
          Random, deviation, -25, 25
          If (modelu=5)
             Random, moduz, 1, 9

          If (moduz=1)
          {
             xPos := mainWidth//2 - w//2 + deviation
             yPos := mainHeight//2 - h//2 + deviation
          } Else If (moduz=2)
          {
             xPos := 1 - w//2 + deviation
             yPos := mainHeight//2 - h//2 + deviation
          } Else If (moduz=3)
          {
             xPos := 1 - w//2 + deviation
             yPos := 1 - h//2 + deviation
          } Else If (moduz=4)
          {
             xPos := mainWidth//2 - w//2 + deviation
             yPos := 1 - h//2 + deviation
          } Else If (moduz=5)
          {
             xPos := mainWidth - w//2 + deviation
             yPos := 1 - h//2 + deviation
          } Else If (moduz=6)
          {
             xPos := mainWidth - w//2 + deviation
             yPos := mainHeight - h//2 + deviation
          } Else If (moduz=7)
          {
             xPos := mainWidth//2 - w//2 + deviation
             yPos := mainHeight - h//2 + deviation
          } Else If (moduz=8)
          {
             xPos := mainWidth - w//2 + deviation
             yPos := mainHeight//2 - h//2 + deviation
          } Else
          {
             xPos := 1 - w//2 + deviation
             yPos := mainHeight - h//2 + deviation
          }
          Random, tBrsh, 1, 3
          Gdip_FillEllipse(glPG, pBr%tBrsh%, xPos, yPos, w, h)
       }
    } Else If (modelu=4)
    {
       Loop, % iterations
       {  
          Random, xPos, 5, % mainWidth
          y := 0
          Random, w, 5, % mainWidth//2
          w += 5
          h := mainHeight
          Random, tBrsh, 1, 3
          Gdip_FillRectangle(glPG, pBr%tBrsh%, xPos, yPos, w, h)
       }
    } Else ; If (modelu=6)
    {
       Loop, % iterations
       {  
          x := 0
          Random, yPos, 5, % mainHeight
          w := mainWidth
          Random, h, 5, % mainHeight//2
          h += 5
          Random, tBrsh, 1, 3
          Gdip_FillRectangle(glPG, pBr%tBrsh%, xPos, yPos, w, h)
       }
    }
    If !GetKeyState("Shift", "P")
       Gdip_FillRectangle(glPG, pBr4, 0, 0, mainWidth, mainHeight)

    matrix := getColorMatrix()
    If (imgFxMode=3 || imgFxMode=8)
       matrix := ""

    Gdip_AddPathGradient(glPG, 0, 0, mainWidth, mainHeight, mainWidth//2, mainHeight//2, "0x00000000", "0x55000000", 1, 0, 0, 1)
    pEffect := Gdip_CreateEffect(1, 20, 0, 0)
    If pEffect
    {
       BMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
       r1 := Gdip_DrawImageFX(glPG, BMPcache, 0, 0, mainWidth, mainHeight, matrix, pEffect)
    }

    r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %hGDIwin%,, %mainX%, %mainY%
    }

    Gdip_DisposeEffect(pEffect)
    Gdip_DeleteBrush(pBr1)
    Gdip_DeleteBrush(pBr2)
    Gdip_DeleteBrush(pBr3)
    Gdip_DeleteBrush(pBr4)
    Gdip_DeleteBrush(pBr5)
    Gdip_DisposeImage(BMPcache, 1)
    If (A_TickCount - thisZeit<250)
       SetTimer, drawWelcomeImg, -3500
    Else
       SetTimer, drawWelcomeImg, Off
}

destroyGDIPcanvas() {
    SelectObject(glHDC, glOBM)
    DeleteObject(glHbitmap)
    DeleteDC(glHDC)
    Gdip_DeleteGraphics(glPG)
}

createGDIPcanvas(W:=0, H:=0) {
   Static prevDimensions, hasInit
   If (W=0 && H=0)
      GetClientSize(W, H, PVhwnd)

   newDimensions := "a" W "." H
   If (prevDimensions!=newDimensions)
   {
      If (hasInit=1)
         destroyGDIPcanvas()

      glHbitmap := CreateDIBSection(W, H)
      glHDC := CreateCompatibleDC()
      glOBM := SelectObject(glHDC, glHbitmap)
      glPG := Gdip_GraphicsFromHDC(glHDC, imgQuality, 4, 2)
      prevDimensions := "a" W "." H
      hasInit := 1
   }
}

InitStuff() {
; the main canvas
   createGDIPcanvas()

; create pens and brushes
   pPen1 := Gdip_CreatePen("0xCCbbccbb", 3)
   pPen1d := Gdip_CreatePen("0xCCbbccbb", 3)
   Gdip_SetPenDashArray(pPen1d, "1.1,1.1")
   pPen2 := Gdip_CreatePen("0xBBffccbb", 3)
   pPen3 := Gdip_CreatePen("0x66334433", imgHUDbaseUnit//8)
   pPen4 := Gdip_CreatePen("0x88998899", imgHUDbaseUnit//11.5)
   Gdip_SetPenDashArray(pPen4, "0.5,0.5")
   pBrushA := Gdip_BrushCreateSolid("0x90898898")
   pBrushB := Gdip_BrushCreateSolid("0xBB898898")
   pBrushC := Gdip_BrushCreateSolid("0x77898898")
   pBrushD := Gdip_BrushCreateSolid("0xDDbbccFF")
   pBrushE := Gdip_BrushCreateSolid("0x77333333")

   createCheckersBrush(20)
   pBrushHatchLow := Gdip_BrushCreateHatch("0xff999999", "0xff111111", 50)
   pBrushWinBGR := Gdip_BrushCreateSolid("0xFF" WindowBgrColor)
}

createCheckersBrush(size) {
   pBr1 := Gdip_BrushCreateSolid("0x99ffFFff")
   pBr2 := Gdip_BrushCreateSolid("0x99515151")
   pBr3 := Gdip_BrushCreateHatch("0xff999999", "0xff111111", 50)
   pBitmap := Gdip_CreateBitmap(size, size)
   G := Gdip_GraphicsFromImage(pBitmap)
   Gdip_FillRectangle(G, pBr3, 0, 0, size, size)
   Gdip_FillRectangle(G, pBr2, 0, 0, size, size)
   Gdip_FillRectangle(G, pBr1, 0, 0, size//2, size//2)
   Gdip_FillRectangle(G, pBr1, size//2, size//2, size//2, size//2)
   Gdip_DeleteGraphics(G)
   pBrushHatch := Gdip_CreateTextureBrush(pBitmap, 0, 0, 0, size, size)
   Gdip_DisposeImage(pBitmap)
   Gdip_DeleteBrush(pBr1)
   Gdip_DeleteBrush(pBr2)
   Gdip_DeleteBrush(pBr3)
   setTexHatchScale(zoomLevel)
}

refreshWinBGRbrush() {
   If pBrushWinBGR
      Gdip_DeleteBrush(pBrushWinBGR)
   Sleep, 0
   pBrushWinBGR := Gdip_BrushCreateSolid("0xFF" WindowBgrColor)
}

BuildGUI() {
   Critical, on
   Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialwh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3
   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Add, Text, x0 y0 w1 h1 BackgroundTrans gWinClickAction vPicOnGui1 hwndhPicOnGui1,
   Gui, 1: Add, Edit, xp-100 yp-100 w1 h1 veditDummy,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2a,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2b,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2c,
   Gui, 1: Add, Text, x3 y3 w3 h3 BackgroundTrans gWinClickAction vPicOnGui3,

   Gui, 1: Show, Maximize Center %initialwh%, %appTitle%
   createGDIwinThumbs()
   Sleep, 2
   createGDIwin()
   updateUIctrl()
   Sleep, 1
}

updateUIctrl() {
   GetClientSize(GuiW, GuiH, PVhwnd)
   ctrlW := (editingSelectionNow=1 && activateImgSelection=1) ? GuiW//8 : GuiW//5
   ctrlH2 := GuiH//3
   ctrlW2 := GuiW - ctrlW*2
   ctrlY1 := ctrlH2
   ctrlY2 := ctrlH2*2
   ctrlX1 := ctrlW
   ctrlX2 := ctrlW + ctrlW2
   GuiControl, 1: Move, PicOnGUI1, % "w" ctrlW " h" GuiH
   GuiControl, 1: Move, PicOnGUI2a, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1
   GuiControl, 1: Move, PicOnGUI2b, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" ctrlY1
   GuiControl, 1: Move, PicOnGUI2c, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" ctrlY2
   GuiControl, 1: Move, PicOnGUI3, % "w" ctrlW " h" GuiH " x" ctrlX2 " y0"
   WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%   
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

dummy() {
  Sleep, 0
}

ResetImgLoadStatus() {
  Try DllCall("user32\SetCursor", "Ptr", hCursN)
  If !GetKeyState("LButton", "P")
     mustAbandonCurrentOperations := imageLoading := 0
  Else If (imageLoading=1)
     SetTimer, ResetImgLoadStatus, -50
}

ShowTheImage(imgPath, usePrevious:=0, ForceIMGload:=0) {
  Static prevImgPath, lastInvoked := 1

  doIT := ((A_TickCount - lastInvoked<125) && (drawModeAzeit>180 && LastPrevFastDisplay!=1 && prevDrawingMode=1)) || (drawModeBzeit>200 && prevDrawingMode=3 && LastPrevFastDisplay!=1) || ((A_TickCount - lastInvoked<65) && (prevImgPath!=imgPath && drawModeAzeit>50)) || ((A_TickCount - lastInvoked<10) && prevDrawingMode=1) ? 1 : 0
  If (A_TickCount - prevColorAdjustZeit<90) || (slideShowRunning=1)
     doIT := 0

  If (doIT=1 && usePrevious=0 && ForceIMGload=0 && AnyWindowOpen!=10
  && !diffIMGdecX && !diffIMGdecY && thumbsDisplaying!=1)
  {
     If (noTooltipMSGs=1)
        SetTimer, RemoveTooltip, Off
     ; ToolTip, % Exception("", -1).Line "`n" Exception("", -1).What, , , 2
     zPlitPath(imgPath, 0, OutFileName, OutDir)
     If (vpIMGrotation>0)
        zoomu := " @ " vpIMGrotation "°"
     If (IMGresizingMode=4)
        zoomu := " [" Round(zoomLevel * 100) "%" zoomu "]"
     winTitle := currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir "\"
     winPrefix := defineWinTitlePrefix()
     WinSetTitle, ahk_id %PVhwnd%,, % winPrefix winTitle
     lastInvoked := A_TickCount
     SetTimer, dummyFastImageChangePlaceHolder, -15
     dummyTimerReloadThisPicture(550)
     prevImgPath := imgPath
  } Else
  {
     prevImgPath := imgPath
     coreShowTheImage(imgPath, usePrevious, ForceIMGload)
  }

  lastInvoked := A_TickCount
}

coreShowTheImage(imgPath, usePrevious:=0, ForceIMGload:=0) {
   Critical, on
   Static prevImgPath, lastInvoked2 := 1, counteru
        , lastInvoked := 1, prevPicCtrl := 1

   WinGet, winStateu, MinMax, ahk_id %PVhwnd%
   If (winStateu=-1)
      Return

   startZeitIMGload := A_TickCount
   SetTimer, ResetImgLoadStatus, Off
   ThisPrev := (ForceIMGload=1 || usePrevious=2) ? 1 : 0
   If (imgPath=prevImgPath && StrLen(prevImgPath)>3 && ThisPrev!=1)
      usePrevious := 1

   If (usePrevious=2 || ForceIMGload=1)  ; force no caching
   {
      If (ForceIMGload=1)
         prevImgPath := 1
      usePrevious := 0
   }

   If (usePrevious!=1 && thumbsDisplaying!=1)
   {
      If (A_TickCount - prevGUIresize<900)
         GdipCleanMain(2)
   }

   zPlitPath(imgPath, 0, OutFileName, OutDir)
   If (vpIMGrotation>0)
      zoomu := " @ " vpIMGrotation "°"
   If (IMGresizingMode=4)
      zoomu := " [" Round(zoomLevel * 100) "%" zoomu "]"

   winTitle := currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir "\"
   If (thumbsDisplaying=1)
   {
      filesElected := getSelectedFiles()
      filesSelInfo := (filesElected>0) ? "[ " filesElected " ] " : ""

      SetTimer, UpdateThumbsScreen, -10
      WinSetTitle, ahk_id %PVhwnd%,, % filesSelInfo "THUMBS: " winTitle
      If (imageLoading=1)
         SetTimer, ResetImgLoadStatus, -15
      Return
   }

   If !gdiBitmap
   {
      usePrevious := 0
      ForceIMGload := 1
   }
   ; ToolTip, % AprevImgCall "`n" BprevImgCall "`n" imgPath,,,2
   If (InStr(AprevImgCall, imgPath) || InStr(BprevImgCall, imgPath)) && (ForceIMGload=0)
      ignoreFileCheck := 1

   If (!FileRexists(imgPath) && usePrevious=0 && ignoreFileCheck!=1)
   {
      If (WinActive("A")=PVhwnd)
      {
         winTitle := "[*] " winTitle
         WinSetTitle, ahk_id %PVhwnd%,, % winTitle
         showTOOLtip("ERROR: File not found or access denied...`n" OutFileName "`n" OutDir "\")
         SetTimer, RemoveTooltip, % -msgDisplayTime
      }

      If (imgPath!=prevImgPath)
      { 
         If (A_TickCount - lastInvoked2>125) && (A_TickCount - lastInvoked>95)
         {
            SoundBeep, 300, 50
            lastInvoked2 := A_TickCount
         }
 
         If (autoRemDeadEntry=1)
            remCurrentEntry(0, 1)
         lastInvoked := A_TickCount
         SetTimer, ResetImgLoadStatus, -15
         Return "fail"
      }
   }

   If (A_TickCount - lastInvoked>85) && (A_TickCount - lastInvoked2>85)
   || (slideShowRunning=1 || usePrevious=1 || ForceIMGload=1 || diffIMGdecX || diffIMGdecY || LastPrevFastDisplay=1)
   {
       lastInvoked := A_TickCount
       r2 := ResizeImageGDIwin(imgPath, usePrevious, ForceIMGload)
       If !r2
       {
          If (WinActive("A")=PVhwnd)
          {
             showTOOLtip("ERROR: Unable to display the image...`nPossibly malformed image file format.")
             SetTimer, RemoveTooltip, % -msgDisplayTime
          }
          winTitle := "[*] " winTitle
          WinSetTitle, ahk_id %PVhwnd%,, % winTitle
          SoundBeep, 300, 100
          SetTimer, ResetImgLoadStatus, -15
          Return "fail"
       } Else prevImgPath := imgPath
       lastInvoked := A_TickCount
   } Else
   {
      If (noTooltipMSGs=1)
         SetTimer, RemoveTooltip, Off
      winPrefix := defineWinTitlePrefix()
      WinSetTitle, ahk_id %PVhwnd%,, % winPrefix winTitle
      delayu := (A_TickCount - prevFastDisplay < 500) ? 110 : 325
      ; SetTimer, dummyFastImageChangePlaceHolder, -10
      dummyTimerReloadThisPicture(delayu)
   }
   SetTimer, ResetImgLoadStatus, -15
   lastInvoked2 := A_TickCount
}

dummyFastImageChangePlaceHolder() {
   GdipCleanMain(5)
}

calcImgSize(modus, imgW, imgH, GuiW, GuiH, ByRef ResizedW, ByRef ResizedH) {
   PicRatio := Round(imgW/imgH, 5)
   GuiRatio := Round(GuiW/GuiH, 5)
   If (imgW <= GuiW) && (imgH <= GuiH)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio)
      If (ResizedH>GuiH)
      {
         ResizedH := (imgH <= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
         ResizedW := Round(ResizedH * PicRatio)
      }   

      If (modus=2)
      {
         ResizedW := imgW
         ResizedH := imgH
      }
   } Else If (PicRatio > GuiRatio)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio)
   } Else
   {
      ResizedH := (imgH >= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
      ResizedW := Round(ResizedH * PicRatio)
   }
}

changeMcursor() {
  Static lastInvoked := 1
  If (slideShowRunning!=1) && (A_TickCount - lastInvoked > 300)
  {
     DllCall("user32\SetCursor", "Ptr", hCursBusy)
     lastInvoked := A_TickCount
  }
}

ResizeImageGDIwin(imgPath, usePrevious, ForceIMGload) {
    Critical, on
    Static oImgW, oImgH, prevImgPath, lastTitleChange := 1
         , IDprevImgPath, tinyW, tinyH, wscale

    imageLoading := 1
    If (slideShowRunning=1)
       lastTitleChange := A_TickCount + 2000

    If (A_TickCount - lastTitleChange>400)
    {
       changeMcursor()
       WinSetTitle, ahk_id %PVhwnd%,, Loading... (%appTitle%)
    }

    calcScreenLimits()
    If (winGDIcreated!=1)
       createGDIwin()

    o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
    If ((IMGresizingMode=1 || IMGresizingMode=2) && enableThumbsCaching=1)
    {
       MD5name := generateThumbName(imgPath)
       file2load := thumbsCacheFolder "\big-" alwaysOpenwithFIM userHQraw MD5name ".png"
       cachedImgFile := FileExist(file2load) ? 1 : 0
    } Else cachedImgFile := 0

    extraID := ColorDepthDithering vpIMGrotation RenderOpaqueIMG usrTextureBGR usrColorDepth bwDithering
    IDthisImgPath := imgPath "-" cachedImgFile userHQraw extraID
    If (imgPath!=prevImgPath || IDthisImgPath!=IDprevImgPath || !gdiBitmap || ForceIMGload=1)
    {
       gdiBMPchanged := 1
       ; ToolTip, % ForceIMGload, , , 2
       If (imgPath!=prevImgPath)
          desiredFrameIndex := 0
       mustReloadIMG := (IDthisImgPath!=IDprevImgPath && cachedImgFile=1 && imgPath=prevImgPath) || (ForceIMGload=1) ? 1 : 0
       If (IDthisImgPath!=IDprevImgPath && imgPath=prevImgPath)
       {
          usePrevious := 0
          mustReloadIMG := ForceIMGload := 1
          GdipCleanMain(6)
       }
       disposeCacheIMGs()
       If (A_TickCount - lastTitleChange>400)
          changeMcursor()

       thisImgPath := (cachedImgFile=1) ? file2load : imgPath
       r1 := CloneMainBMP(thisImgPath, cachedImgFile, oImgW, oImgH, CountFrames, mustReloadIMG, hasFullReloaded)
       If (CountFrames=0 && imgFxMode=3 && r1!="error")
          AdaptiveImgLight(gdiBitmap, imgPath, oImgW, oImgH)
    }

    If ((IMGresizingMode=1 || IMGresizingMode=2) && enableThumbsCaching=1)
    {
       cachedImgFile := FileExist(file2load) ? 1 : 0
       IDthisImgPath := imgPath "-" cachedImgFile
    }

    If (!gdiBitmap || r1="error")
    {
       prevImgPath := ""
       GdipCleanMain(1)
       SetTimer, ResetImgLoadStatus, -15
       Return 0
    }

   prevImgPath := imgPath
   IDprevImgPath := imgPath "-" cachedImgFile userHQraw extraID
   GetClientSize(GuiW, GuiH, PVhwnd)
   If (usePrevious!=1)
   {
      imgW := oImgW
      imgH := oImgH
   } Else If (usePrevious=1 || mustReloadIMG=1 || ForceIMGload=1)
   {
      actionu := (mustReloadIMG=1 || ForceIMGload=1) ? 1 : 0
      If (usePrevious!=1 && actionu=1)
         actionu := 2

      tinyR := RescaleBMPtiny(imgPath, oImgW, oImgH, tinyW, tinyH, actionu)
      If (tinyR!="null")
      {
         imgW := tinyW
         imgH := tinyH
         wscale := oImgW / tinyW
      }
   }

   calcImgSize(IMGresizingMode, oimgW, oimgH, GuiW, GuiH, ResizedW, ResizedH)
   If (IMGresizingMode=3)
   {
      lGuiW := (GuiW>imgW) ? imgW : GuiW
      lGuiH := (GuiH>imgH) ? imgH : GuiH
      ws := Round(ResizedW / imgW * 100)
      If (ws<100)
      {
         ws := Round(((lGuiW*lGuiH) / (imgW*imgH)) * 100)
         ws .= "% visible"
      } Else If (ws>100)
      {
         ws := "100%"
      } Else ws .= "%"
      zoomLevel := 1
      ResizedW := imgW
      ResizedH := imgH
   } Else If (IMGresizingMode=4)
   {
      ResizedW := Round(imgW * zoomLevel, 3)
      ResizedH := Round(imgH * zoomLevel, 3)
      ws := Round(zoomLevel * 100) "%"
   } Else
   {
      If (cachedImgFile=1)
      {
         GetImgFileDimension(imgPath, roImgW, roImgH)
      } Else
      {
         roImgW := oImgW
         roImgH := oImgH
      }
      zoomLevel := Round(ResizedW / roImgW, 3)
      ws := Round(ResizedW / roImgW * 100) "%"
   }

; ToolTip, % imgW ", " oImgW ", " roImgW ", " ResizedW ,,, 2
   If (usePrevious=1 && (IMGresizingMode>=3 || (imgW=ResizedW && imgH=ResizedH)))
   {
      ResizedW := ResizedW * wscale
      ResizedH := ResizedH * wscale
   }

   setTexHatchScale(zoomLevel)
   IMGlargerViewPort := ((ResizedH-5>GuiH+1) || (ResizedW-5>GuiW+1)) ? 1 : 0
   If (noTooltipMSGs=1)
      SetTimer, RemoveTooltip, Off
   If (vpIMGrotation>0)
      zoomu := " @ " vpIMGrotation "°"

   zPlitPath(imgPath, 0, OutFileName, OutDir)
   winPrefix := defineWinTitlePrefix()
   winTitle := winPrefix currentFileIndex "/" maxFilesIndex " [" ws zoomu "] " OutFileName " | " OutDir "\"
   If (A_TickCount - lastTitleChange>400)
      WinSetTitle, ahk_id %PVhwnd%,, % "Please wait... "  OutFileName " | " OutDir "\" 

   ResizedW := Round(ResizedW)
   ResizedH := Round(ResizedH)
   If (A_TickCount - lastTitleChange>400)
      changeMcursor()

   prevMaxSelX := roImgW ? roImgW : oImgW
   prevMaxSelY := roImgH ? roImgH : oImgH
   If (activateImgSelection=1 || editingSelectionNow=1) && (relativeImgSelCoords=1 && gdiBMPchanged=1)
      calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

   If (slideShowRunning=1 && doSlidesTransitions=1 && slideShowDelay>900)
   {
      If yetAnotherVPcache
         yetAnotherVPcache := Gdip_DisposeImage(yetAnotherVPcache, 1)

      yetAnotherVPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
   }
   r := QPV_ShowImgonGui(oImgW, oImgH, ws, imgW, imgH, ResizedW, ResizedH, GuiW, GuiH, usePrevious, imgpath, CountFrames, ForceIMGload, hasFullReloaded)
   delayu := (A_TickCount - prevFastDisplay < 300) ? 90 : 550
   If (usePrevious=1)
      dummyTimerReloadThisPicture(delayu)

   filesElected := getSelectedFiles()
   infoFilesSel := (filesElected>0) ? "[ " filesElected " ] " : ""
   If (totalFramesIndex>0)
      infoFrames := "["  desiredFrameIndex "/" totalFramesIndex "] "
   pVwinTitle := infoFilesSel infoFrames winTitle
   WinSetTitle, ahk_id %PVhwnd%,, % pVwinTitle
   lastTitleChange := A_TickCount
   SetTimer, ResetImgLoadStatus, -15
   Return r
}

drawinfoBox(mainWidth, mainHeight, imgPath) {
    maxSelX := prevMaxSelX, maxSelY := prevMaxSelY
    filesElected := getSelectedFiles()
    infoFilesSel := (filesElected>0) ? "`nFiles selected: " filesElected : ""

    If (totalFramesIndex>0)
       infoFrames := "`nMultiple pages: "  desiredFrameIndex " / " totalFramesIndex

    zPlitPath(imgPath, 0, fileNamu, folderu, OutNameNoExt)
    FileGetSize, fileSizu, % ImgPath, K
    FileGetTime, FileDateM, % ImgPath, M
    FormatTime, FileDateM, % FileDateM, dd/MM/yyyy, HH:mm
    If FileExist(imgPath)
       fileMsg := "`n" fileSizu " Kb | " FileDateM
    Else
       fileMsg := "`nFile not found or access denied..."

    If (IMGresizingMode!=4)
       infoSizing := "`nRescaling mode: " DefineImgSizing() "`nViewport alignment: " defineImgAlign()
    If (vpIMGrotation>0)
       infoRotate := " @ " vpIMGrotation "°"

    infoRes := "`nResolution (W x H): " maxSelX " x " maxSelY " px [ " Round(zoomLevel*100) "%" infoRotate " ]"
;    infoRes := "`nResolution (W x H): " thisW " x " thisH " px [ " Round(zoomLevel*100) "%" infoRotate " ]"
    sliSpeed := Round(slideShowDelay/1000, 2) " sec."
    If (slideShowRunning=1)
       infoSlider := "`nSlideshow running: " DefineSlideShowType() " @ " sliSpeed

    infoMirroring := defineIMGmirroring()
    If (activateImgSelection=1)
    {
       imgSelW := maxU(ImgSelX1, ImgSelX2) - minU(ImgSelX1, ImgSelX2)
       imgSelH := maxU(ImgSelY1, ImgSelY2) - minU(ImgSelY1, ImgSelY2)
       If (relativeImgSelCoords=1)
       {
          x1 := " [ " Round(prcSelX1 * 100) "%, "
          y1 := Round(prcSelY1 * 100) "% ]"
          wP := " [ " Round((prcSelX2 - prcSelX1) * 100) "%, "
          hP := Round((prcSelY2 - prcSelY1) * 100) "% ]"
          moreSelInfo := "`nCoordinates relative to the image resolution."
       }
       infoSelection := "`n `nSelection coordinates:`nX / Y: " ImgSelX1 ", " ImgSelY1 x1 y1 "`nW / H: " imgSelW ", " imgSelH wP hP moreSelInfo
    }
    If (usrColorDepth>1)
       infoColorDepth := "`nImage color depth: ALTERED [ " defineColorDepth() " ]"

    If StrLen(usrFilesFilteru)>1
       infoFilteru := "`nFiles list filtered from " bkcpMaxFilesIndex " to " maxFilesIndex ".`nFilter pattern: " usrFilesFilteru
    totalZeit := A_TickCount - startZeitIMGload
    If (totalZeit>=10)
       InfoLoadTime := "`nViewport refresh speed: ~" totalZeit " milisec."

    thisSNDfile := IdentifyAudioFileAssociated()
    If thisSNDfile
    {
       zPlitPath(thisSNDfile, 0, OutFileName, null)
       If hSNDmedia
          statusMedia := " - " MCI_Status(hSNDmedia)

       If hSNDmediaDuration
       {
          If hSNDmedia
          {
             sndMediaPos := MCI_Position(hSNDmedia)
             sndMediaPos := (sndMediaPos>3500) ? MCI_ToHHMMSS(sndMediaPos) " / " : ""
             If (sndMediaPos=hSNDmediaDuration)
                sndMediaPos := ""
          }
          mediaDuration := " (" sndMediaPos hSNDmediaDuration  ")"
       }
       infoAudio := "`nAudio file associated: " OutFileName mediaDuration statusMedia
    }

    infoColors := "`nColors display mode: " DefineFXmodes() " [" currentPixFmt "]"
    fileRelatedInfos := (StrLen(folderu)>3) ? folderu "\`n[ " currentFileIndex " / " maxFilesIndex " ] " fileNamu fileMsg : ""
    entireString := fileRelatedInfos infoRes infoSizing infoMirroring infoColors infoColorDepth infoFrames InfoLoadTime infoFilesSel infoAudio infoSlider infoSelection infoFilteru
    infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.1, mainWidth//1.3, mainHeight//1.3, OSDtextColor, "0xFF" OSDbgrColor, 1, 1)
    Gdip_DrawImage(glPG, infoBoxBMP, 0, 0,,,,,,, 0.85)
    infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
}

calcScreenLimits() {
    Static lastInvoked := 1

; the function calculates screen boundaries for the user given X/Y position for the OSD
    If (A_TickCount - lastInvoked<950)
       Return

    WinGetPos, mainX, mainY,,, ahk_id %PVhwnd%
    ActiveMon := MWAGetMonitorMouseIsIn(mainX, mainY)
    If !ActiveMon
    {
       ActiveMon := MWAGetMonitorMouseIsIn()
       If !ActiveMon
          Return
    }

    SysGet, mCoord, MonitorWorkArea, %ActiveMon%
    ResolutionWidth := Abs(max(mCoordRight, mCoordLeft) - min(mCoordRight, mCoordLeft))
    ResolutionHeight := Abs(max(mCoordTop, mCoordBottom) - min(mCoordTop, mCoordBottom)) 
    lastInvoked := A_TickCount
}

RescaleBMPtiny(imgPath, imgW, imgH, ByRef ResizedW, ByRef ResizedH, actionu) {
  Critical, on
  ; one quarter resolution
  Static prevImgPath, prevResizedW, prevResizedH
  If (actionu!=0)
     prevImgPath := prevResizedW := prevResizedH := ""

  If (actionu=1)
     Return "null"

  If (imgPath=prevImgPath && gdiBitmapSmall && actionu!=1)
  {
     ResizedW := prevResizedW
     ResizedH := prevResizedH
     Return
  }

  If gdiBitmapSmall
     gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)

  If (imgW//2>ResolutionWidth//2) || (imgH//2>ResolutionHeight//2)
  {
     calcIMGdimensions(imgW, imgH, ResolutionWidth//2, ResolutionHeight//2, ResizedW, ResizedH)
  } Else
  {
     ResizedW := Round(imgW//2) + 2
     ResizedH := Round(imgH//2) + 2
  }
  prevResizedW := ResizedW
  prevResizedH := ResizedH
  thisImgQuality := (userimgQuality=1) ? 3 : 5
  changeMcursor()
  gdiBitmapSmall := Gdip_ResizeBitmap(gdiBitmap, ResizedW, ResizedH, 0, thisImgQuality)
  prevImgPath := imgPath
}

SaveFIMfile(file2save, pBitmap) {
  initFIMGmodule()
  If !wasInitFIMlib
     Return 1

  hFIFimgA := ConvertPBITMAPtoFIM(pBitmap, hGDIwin)
  If !hFIFimgA
     Return 1

/*
  alphaBitmap := Gdip_RetrieveBitmapChannel(pBitmap, "A")
  If alphaBitmap
  {
     alphaFIFimg := ConvertPBITMAPtoFIM(alphaBitmap, hGDIwin)
     Gdip_DisposeImage(alphaBitmap)
  }

  If alphaFIFimg
  {
     hFIFimgD := FreeImage_ConvertTo(alphaFIFimg, "Greyscale")
     If hFIFimgD
     {
        FreeImage_SetChannel(hFIFimgA, hFIFimgD, 4)
        FreeImage_UnLoad(hFIFimgD)
     }
     FreeImage_UnLoad(alphaFIFimg)
  }
*/

  If FileExist(file2save)
  {
     Try FileSetAttrib, -R, % file2save
     Sleep, 0
     FileMove, % file2save, % file2save "-tmp"
     Sleep, 0
  }

  If RegExMatch(file2save, "i)(.\.(gif|jng|jif|jfif|jpg|jpe|jpeg|ppm|wbm|xpm))$")
  {
     changeMcursor()
     hFIFimgB := FreeImage_ConvertTo(hFIFimgA, "24Bits")
     changeMcursor()
     r := FreeImage_Save(hFIFimgB, file2save)
     FreeImage_UnLoad(hFIFimgB)
  } Else r := FreeImage_Save(hFIFimgA, file2save)

  FreeImage_UnLoad(hFIFimgA)
  If !r
  {
     FileDelete, % file2save
     Sleep, 0
     FileMove, % file2save "-tmp", % file2save
  } Else FileDelete, % file2save "-tmp"

  Return !r3
}

initFIMGmodule() {
  Static firstTimer := 1
  If (wasInitFIMlib!=1)
  {
     r := FreeImage_FoxInit(1) ; Load the FreeImage Dll
     wasInitFIMlib := r ? 1 : 0
  }

  If InStr(r, "err - ")
  {
     alwaysOpenwithFIM := 0
     FIMfailed2init := 1
     If InStr(r, "err - 126")
        friendly := "`n`nPlease install the Rubntime Redistributable Packages of Visual Studio 2013 included in the Quick Picto Viewer ZIP compiled package."
     Else If InStr(r, "err - 404")
        friendly := "`n`nThe FreeImage.dll file seems to be missing..."
     If (firstTimer=1)
     {
        SoundBeep, 300, 900
        triggerOwnDialogs()
        Msgbox, 48, %appTitle%, ERROR: The FreeImage library failed to properly initialize. Some image file formats will no longer be supported. Error code: %r%.%friendly%
     }
  } Else FIMfailed2init := 0

  firstTimer := 0
  Return r
}

FreeImageLoader(imgPath, noBPPconv) {
  Critical, on
  sTime := A_tickcount  
  initFIMGmodule()
  If !wasInitFIMlib
     Return

  noPixels := (noBPPconv=1) ? -1 : 0
  GFT := FreeImage_GetFileType(ImgPath)
  If (GFT=34 && noPixels=0)
     noPixels := (userHQraw=1 && thumbsDisplaying=0) ? 0 : 5

  changeMcursor()
  hFIFimgA := FreeImage_Load(imgPath, -1, noPixels) ; load image
  If !hFIFimgA
     Return

  If (noBPPconv=0 && RenderOpaqueIMG!=1)
     alphaBitmap := FreeImage_GetChannel(hFIFimgA, 4)

  imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
  If (imgBPP>32)
  {
     changeMcursor()
     If (noBPPconv=0)
        hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)
  }

  If (noBPPconv=0)
  {
     ColorsType := FreeImage_GetColorType(hFIFimgA)
     FIMimgBPP := imgBPP " bit [ " ColorsType " ] "
     FIMformat := GFT
  }

  changeMcursor()
  ; If (bwDithering=1 && imgFxMode=4 && doBw=1)
  ;    hFIFimgZ := hFIFimgB ? FreeImage_Dither(hFIFimgB, 0) : FreeImage_Dither(hFIFimgA, 0)
  ; Else
     hFIFimgZ := hFIFimgB ? hFIFimgB : hFIFimgA

  hFIFimgC := hFIFimgZ ? hFIFimgZ : hFIFimgA
  FreeImage_GetImageDimensions(hFIFimgC, imgW, imgH)

  If (noBPPconv=0)
  {
     If alphaBitmap
     {
        hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "32Bits")
        ; ensure the alpha channel does not get lost - reapply it
        ; it sometimes gets lost, I do not know why...
        ; the previously retrieved Alpha channel must 
        ; be converted to Greyscale...
        hFIFimgR := FreeImage_ConvertTo(alphaBitmap, "Greyscale")
        pixelsColorTest1 := FreeImage_GetPixelIndex(hFIFimgR, 2, 2)
        pixelsColorTest2 := FreeImage_GetPixelIndex(hFIFimgR, imgW//2, imgH//2)
        pixelsColorTest3 := FreeImage_GetPixelIndex(hFIFimgR, imgW - 2, imgH - 2)
        If (pixelsColorTest1<20 && pixelsColorTest2<20 && pixelsColorTest3<20)
           mustTestThis := 1
        Else If (pixelsColorTest1>240 && pixelsColorTest2>240 && pixelsColorTest3>240)
           mustTestThis := 2

        If (mustTestThis=1 || mustTestThis=2)
        {
           ; ensure the alpha channel does not render the entire image transparent...
           pvBits := FreeImage_GetBits(hFIFimgR)
           bitmapInfo2 := FreeImage_GetInfo(hFIFimgR)
           testBMP := Gdip_CreateBitmapFromGdiDib(bitmapInfo2, pvBits)
           isUniform := Gdip_TestBitmapUniformity(testBMP, 3, maxLevelIndex, maxLevelPixels)
           If (isUniform=1 && maxLevelIndex<6)
              FreeImage_Invert(hFIFimgR)
           Gdip_DisposeImage(testBMP)
        }
        ; ToolTip, % maxLevelIndex ", " testUniformity " | " pixelsColorTest
        r := FreeImage_SetChannel(hFIFimgD, hFIFimgR, 4)
        FreeImage_PreMultiplyWithAlpha(hFIFimgD)
        FreeImage_UnLoad(hFIFimgR)
        FreeImage_UnLoad(alphaBitmap)
        If (isUniform=1 && mustTestThis=2 && maxLevelIndex>249)
           alphaBitmap := ""
     } Else hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "24Bits")

     hFIFimgE := hFIFimgD ? hFIFimgD : hFIFimgC
;     bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgE)
     bitmapInfo := FreeImage_GetInfo(hFIFimgE)
     pBits := FreeImage_GetBits(hFIFimgE)
     If alphaBitmap
     {
        nBitmap := Gdip_CreateBitmap(imgW, imgH, 0, imgW*4, pBits)
        Gdip_ImageRotateFlip(nBitmap, 6)
        ; for some reason, nBitmap causes crashes on drawing with Gdip_DrawImage()
        ; in a pGraphics based on a CreateCompatibleDC.
 
        ; the solution I found is to create a new pBitmap
        ; and create a pGraphics based on it and draw into
        ; it the seemingly malformed nBitmap.
        pBitmap := Gdip_CreateBitmap(imgW, imgH)    ; 32-ARGB
     } Else
     {
        nBitmap := Gdip_CreateBitmapFromGdiDib(bitmapInfo, pBits)
        pBitmap := Gdip_CreateBitmap(imgW, imgH, 0x21808)    ; 24-RGB
     }
     G := Gdip_GraphicsFromImage(pBitmap,,,2)
     Gdip_DrawImageFast(G, nBitmap)
     Gdip_DeleteGraphics(G)
     Gdip_DisposeImage(nBitmap)
  } Else pBitmap := Gdip_CreateBitmap(imgW, imgH)

  ; Gdip_GetImageDimensions(pBitmap, imgW2, imgH2)
  imgIDs := hFIFimgA "|" hFIFimgB "|" hFIFimgC "|" hFIFimgD "|" hFIFimgE "|" hFIFimgZ
  Sort, imgIDs, UD|
  Loop, Parse, imgIDs, |
  {
      If A_LoopField
         FreeImage_UnLoad(A_LoopField)
  }

  eTime := A_tickcount - sTime
  ; ToolTip, % imgW ", " imgW2,,,2
  ; Tooltip, % etime "; " noPixels "; " GFT
  ; Tooltip, %r1% -- %r2% -- %pBits% ms ---`n %pbitmap% -- %hbitmap% -- %hfifimg%

  Return pBitmap
}

LoadBitmapFromFileu(imgPath, noBPPconv:=0, forceGDIp:=0) {
  coreIMGzeitLoad := A_TickCount
  If RegExMatch(imgPath, RegExFIMformPtrn) || (alwaysOpenwithFIM=1 && forceGDIp=0)
  {
     oBitmap := FreeImageLoader(imgPath, noBPPconv)
  } Else
  {
     changeMcursor()
     oBitmap := Gdip_CreateBitmapFromFile(imgPath)
     If !oBitmap
        oBitmap := FreeImageLoader(imgPath, noBPPconv)
  }
  Return oBitmap
}

CloneMainBMP(imgPath, cachedImgFile, ByRef imgW, ByRef imgH, ByRef CountFrames, mustReloadIMG, ByRef hasFullReloaded) {
  Critical, on
  Static prevMD5name, lastInvoked := 1

  hasFullReloaded := CountFrames := 0
  MD5name := generateThumbName(imgPath, 1)
  mustNotReloadFile := (prevMD5name=MD5name) ? 1 : 0
  o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
  thisImgCall := MD5name o_bwDithering vpIMGrotation RenderOpaqueIMG cachedImgFile imgPath
  If !FileRexists(imgPath) && (InStr(AprevImgCall, imgPath) || InStr(BprevImgCall, imgPath))
     thisImgCall := InStr(AprevImgCall, imgPath) ? AprevImgCall : BprevImgCall

  If gdiBitmap
     gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)

  file2load := thumbsCacheFolder "\big-" alwaysOpenwithFIM userHQraw MD5name ".png"
  ignoreCache := (RegExMatch(imgPath, "i)(.\.gif)$") && animGIFsSupport=1) || (AnyWindowOpen=5) ? 1 : mustReloadIMG
  If (AprevImgCall=thisImgCall && AprevGdiBitmap && ignoreCache=0)
  {
     Gdip_GetImageDimensions(AprevGdiBitmap, imgW, imgH)
     gdiBitmap := Gdip_CloneBitmap(AprevGdiBitmap)
     extractAmbientalTexture()
     Return 
  } Else If (BprevImgCall=thisImgCall && BprevGdiBitmap && ignoreCache=0)
  {
     Gdip_GetImageDimensions(BprevGdiBitmap, imgW, imgH)
     gdiBitmap := Gdip_CloneBitmap(BprevGdiBitmap)
     extractAmbientalTexture()
     Return
  }

  If (slideShowRunning!=1 && desiredFrameIndex<1) && (A_TickCount - lastInvoked>250)
     GdipCleanMain(6)

  changeMcursor()
  oBitmap := LoadBitmapFromFileu(imgPath)
  If !oBitmap
     Return "error"

  lastInvoked := A_TickCount
  hasFullReloaded := 1
  slowFileLoad := (A_TickCount - coreIMGzeitLoad > 450) ? 1 : 0
  totalFramesIndex := Gdip_GetBitmapFramesCount(oBitmap) - 1
  If (totalFramesIndex<0)
     totalFramesIndex := 0

  If (desiredFrameIndex>=totalFramesIndex)
     desiredFrameIndex := totalFramesIndex

  rawFmt := Gdip_GetImageRawFormat(oBitmap)
  pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
  If (rawFmt="png" && RenderOpaqueIMG!=1 && InStr(pixFmt, "argb"))
  {
     isUniform := Gdip_TestBitmapUniformity(oBitmap, 7, maxLevelIndex)
     If (isUniform=1 && (valueBetween(maxLevelIndex, 0, 5) || valueBetween(maxLevelIndex, 250, 255)))
        Gdip_BitmapSetColorDepth(oBitmap, 24)
  }

  If RegExMatch(rawFmt, "i)(gif|tiff)$")
  {
     If (totalFramesIndex>1 && slideShowRunning=1 && SlideHowMode=1)
        Random, desiredFrameIndex, 0, % totalFramesIndex

     If (totalFramesIndex>0)
        multiFrameImg := 1
     Gdip_BitmapSelectActiveFrame(oBitmap, desiredFrameIndex)
  }

  If (performAutoCropNow=1 && usrAutoCropGenerateSelection=0)
  {
     kBitmap := AutoCropAction(oBitmap, usrAutoCropColorTolerance, usrAutoCropImgThreshold)
     FlipImgV := FlipImgH := vpIMGrotation := performAutoCropNow := 0
     If kBitmap
     {
        Gdip_DisposeImage(oBitmap, 1)
        oBitmap := kBitmap
     }
  }

  Gdip_GetImageDimensions(oBitmap, imgW, imgH)
  totalIMGres := imgW + imgH
  totalScreenRes := ResolutionWidth + ResolutionHeight

  If (rawFmt="gif")
  {
     gifLoaded := 1
     If (animGIFsSupport=1)
        CountFrames := totalFramesIndex
  } Else If (totalIMGres/totalScreenRes>3 || slowFileLoad=1) && (enableThumbsCaching=1 
    && !FileExist(file2load) && multiFrameImg!=1 && cachedImgFile!=1 && (IMGresizingMode=1 || IMGresizingMode=2))
  {
     er := createThumbsFolder()
     If (er="error")
        skippedBeats := 1

     If (skippedBeats!=1)
     {
        calcIMGdimensions(imgW, imgH, ResolutionWidth, ResolutionHeight, newW, newH)
        cachedImgFile := mustSaveFile := 1
     }
  }
  If !newW
     newW := imgW
  If !newH
     newH := imgH

  BprevImgCall := AprevImgCall
  AprevImgCall := MD5name o_bwDithering vpIMGrotation RenderOpaqueIMG cachedImgFile imgPath
  thisImgQuality := (userimgQuality=1 && mustSaveFile) ? 7 : 5
  changeMcursor()
  pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
  If (!InStr(pixFmt, "argb") || gifLoaded=1)
     brushRequired := 1

  If (InStr(pixFmt, "index") || InStr(pixFmt, "16gray") || InStr(pixFmt, "16rgb") || gifLoaded=1)
     pixFmt := "0x21808"  ; 24-RGB
  Else If InStr(pixFmt, "16argb")
     pixFmt := "0x26200A" ; 32-ARGB
  Else
     pixFmt := Gdip_GetImagePixelFormat(oBitmap, 1)

  rBitmap := Gdip_ResizeBitmap(oBitmap, newW, newH, 0, thisImgQuality, pixFmt)
  Gdip_DisposeImage(oBitmap, 1)

  If (mustSaveFile=1 && multiFrameImg!=1)
     z := Gdip_SaveBitmapToFile(rBitmap, file2load, 90)

  If (RenderOpaqueIMG=1 && brushRequired!=1)
  {
     nBitmap := Gdip_RenderPixelsOpaque(rBitmap, pBrushWinBGR)
     Gdip_DisposeImage(rBitmap, 1)
     rBitmap := nBitmap
     brushRequired := 1
  }

  If (vpIMGrotation>0)
  {
     brushRequired := (brushRequired=1) ? pBrushWinBGR : ""
     nBitmap := Gdip_RotateBitmapAtCenter(rBitmap, vpIMGrotation, brushRequired, imgQuality, pixFmt)
     Gdip_GetImageDimensions(nBitmap, imgW, imgH)
     newW := imgW, newH := imgH
     Gdip_DisposeImage(rBitmap, 1)
     rBitmap := nBitmap
  }

  If (bwDithering=1 && imgFxMode=4)
  {
     zBitmap := Gdip_BitmapConvertGray(rBitmap, hueAdjust, zatAdjust, lumosGrayAdjust, GammosGrayAdjust)
     Gdip_DisposeImage(rBitmap)
     rBitmap := zBitmap
     E := Gdip_BitmapSetColorDepth(rBitmap, "BW", 1)
  } Else If (usrColorDepth>1)
     E := Gdip_BitmapSetColorDepth(rBitmap, internalColorDepth, ColorDepthDithering)

  gdiBitmap := rBitmap
  extractAmbientalTexture()
  If BprevGdiBitmap
     BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
  BprevGdiBitmap := AprevGdiBitmap
  AprevGdiBitmap := Gdip_CloneBitmap(gdiBitmap)
  imgW := newW, imgH := newH
}

extractAmbientalTexture() {
    currentPixFmt := Gdip_GetImagePixelFormat(gdiBitmap, 2)
    confirmTexBGR := (vpIMGrotation=0 || vpIMGrotation=90 || vpIMGrotation=180 || vpIMGrotation=270) ? 1 : 0
    If (usrTextureBGR=1 && confirmTexBGR=1)
    {
       decideGDIPimageFX(matrix, imageAttribs, pEffect)
       AmbientalTexBrush := Gdip_CreateTextureBrush(gdiBitmap, 3, 3, 3, 150, 150, matrix, 0, 0, 0, imageAttribs)
    }

    preventScreenOff()
    OnImgChangeRemoveTooltip()
    If (autoPlaySNDs=1)
    {
       AutoPlayAudioFileAssociated()
       identifyAudioMediaLength()
    }
}

OnImgChangeRemoveTooltip() {
  Static prevImgPath := ""
  imgPath := currentFileIndex "="  resultedFilesList[currentFileIndex]
  If (imgPath=prevImgPath)
  {
     Return
  } Else
  {
     RemoveTooltip()
     If (hSNDmedia && autoPlaySNDs!=1)
        StopMediaPlaying()
  }

  prevImgPath := imgPath
}

identifyAudioMediaLength() {
   If hSNDmedia
   {
      milisec := MCI_Length(hSNDmedia)
      hSNDmediaDuration := MCI_ToHHMMSS(milisec)
      If (syncSlideShow2Audios=1 && slideShowRunning=1)
         resetSlideshowTimer(0, 1)
   } Else If (syncSlideShow2Audios=1 && slideShowRunning=1)
         resetSlideshowTimer(0, 1)
}

IdentifyAudioFileAssociated() {
    imgPath := resultedFilesList[currentFileIndex]
    zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
    audioFile1 := OutDir "\" OutNameNoExt ".WAv"
    audioFile2 := OutDir "\" OutNameNoExt ".WMA"
    audioFile3 := OutDir "\" OutNameNoExt ".MP3"

    If FileRexists(audioFile1)
       thisSNDfile := audioFile1
    Else If FileRexists(audioFile2)
       thisSNDfile := audioFile2
    Else If FileRexists(audioFile3)
       thisSNDfile := audioFile3
    Else
       thisSNDfile := 0
    Return thisSNDfile
}

PlayAudioFileAssociatedNow() {
    If (thumbsDisplaying=1)
       Return

    ohSNDmediaFile := hSNDmediaFile
    ohSNDmedia := hSNDmedia
    StopMediaPlaying()
    If (ohSNDmediaFile && ohSNDmedia)
    {
       zPlitPath(ohSNDmediaFile, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       showTOOLtip("Media file stopped: `n" OutFileName "`n" OutDir "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       dummyTimerDelayiedImageDisplay(50)
       Return
    }

    thisSNDfile := IdentifyAudioFileAssociated()
    If thisSNDfile
    {
       hSNDmediaFile := thisSNDfile
       hSNDmedia := MCI_Open(hSNDmediaFile,,,0)
       E := MCI_Play(hSNDmedia)
       identifyAudioMediaLength()
       zPlitPath(hSNDmediaFile, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       thisMsg := (E || !hSNDmedia) ? "ERROR: " E " - " hSNDmedia ". Unable to play media file: `n" : "Media file now playing: `n(" hSNDmediaDuration ") " 
       showTOOLtip(thisMsg OutFileName "`n" OutDir "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime

       If (E || !hSNDmedia)
          StopMediaPlaying()
       dummyTimerDelayiedImageDisplay(50)
    } Else
    {
       imgPath := resultedFilesList[currentFileIndex]
       zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       showTOOLtip("No media file found to play...`n" OutNameNoExt " (.WAV / .WMA / .MP3)`n" OutDir "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
    }
}

AutoPlayAudioFileAssociated() {
    Static prevAudioFile
    thisSNDfile := IdentifyAudioFileAssociated()
    If (thisSNDfile=prevAudioFile && StrLen(thisSNDfile)>3)
       Return

    StopMediaPlaying()
    If thisSNDfile
    {
       hSNDmediaFile := thisSNDfile
       hSNDmedia := MCI_Open(hSNDmediaFile,,,0)
       E := MCI_Play(hSNDmedia)
       If (E || !hSNDmedia)
          StopMediaPlaying()
       Else
          prevAudioFile := hSNDmediaFile
    } Else prevAudioFile := ""
}

StopMediaPlaying() {
    If hSNDmedia
    {
       MCI_Stop(hSNDmedia)
       hSNDmediaDuration := hSNDmedia := hSNDmediaFile := ""
    }
}

ST_ReadLine(String, line, delim="`n", exclude="`r") {
   String := Trim(String, delim)
   StringReplace, String, String, %delim%, %delim%, UseErrorLevel
   TotalLcount := ErrorLevel + 1

   If (abs(line)>TotalLCount && (line!="L" || line!="R" || line!="M"))
      Return 0

   If (Line="R")
      Random, Rand, 1, %TotalLcount%
   Else If (line<=0)
      line := TotalLcount + line

   Loop, Parse, String, %delim%, %exclude%
   {
      out := (Line="R" && A_Index=Rand) ? A_LoopField
           : (Line="M" && A_Index=TotalLcount//2) ? A_LoopField
           : (Line="L" && A_Index=TotalLcount) ? A_LoopField
           : (A_Index=Line) ? A_LoopField : -1
      If (out!=-1) ; Something was found so stop searching.
         Break
   }
   Return out
}

createHistogramBMP(whichBmp) {
   Gdip_GetHistogram(whichBmp, 3, brLvlArray, 0, 0)
   Gdip_GetImageDimensions(whichBmp, imgW, imgH)
   ; Gdip_GetHistogram(whichBmp, 2, ArrChR, ArrChG, ArrChB)

   minBrLvlV := TotalPixelz := imgW * imgH
   Loop, 256
   {
       thisIndex := A_Index - 1
       nrPixelz := brLvlArray[thisIndex]
       If (nrPixelz="")
          Continue

       stringArray .= nrPixelz "." (thisIndex+1) "`n"
       If (nrPixelz>0)
          stringArray2 .= (thisIndex+1) "." nrPixelz "`n"
       If (nrPixelz>1)
          stringArray3 .= (thisIndex+1) "." nrPixelz "`n"
       sumTotalBr += nrPixelz * (thisIndex+1)
       SimpleSumTotalBr += nrPixelz
       If (nrPixelz>modePointV)
       {
          modePointV := nrPixelz
          modePointK := thisIndex
       }
       If (nrPixelz<modePointV && nrPixelz>2ndMaxV)
          2ndMaxV := nrPixelz

       If (nrPixelz<minBrLvlV && nrPixelz>2)
       {
          minBrLvlV := nrPixelz
          minBrLvlK := thisIndex
       }
   }

   Sort, stringArray, ND`n
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   avgBrLvlK := Round(sumTotalBr/TotalPixelz - 1, 1)
   avgBrLvlV := brLvlArray[Round(avgBrLvlK)]
   modePointK2 := ST_ReadLine(stringArray, "L")
   modePointK2 := StrSplit(modePointK2, ".")
   2ndMaxVa := (2ndMaxV + avgBrLvlV)//2 + minBrLvlV
   rangeA := ST_ReadLine(stringArray3, 1)
   rangeA := StrSplit(rangeA, ".")
   rangeB := ST_ReadLine(stringArray3, "L")
   rangeB := StrSplit(rangeB, ".")
   Loop, 256
   {
       minBrLvlK2 := ST_ReadLine(stringArray, A_Index)
       minBrLvlK2 := StrSplit(minBrLvlK2, ".")
       If (minBrLvlK2[1]=0)
          Continue
       If (minBrLvlK2[2]>0)
          Break
   }
   rangeC := rangeB[1] - rangeA[1] + 1
   meanValue := SimpleSumTotalBr/rangeC
   meanValuePrc := Round(meanValue/TotalPixelz * 100)
   meanValuePrc := (meanValuePrc>0) ? " (" meanValuePrc "%) " : ""
   
   2ndMaxVb := (2ndMaxV + meanValue)//2 + minBrLvlV
   2ndMaxV := minU(2ndMaxVa, 2ndMaxVb)
   Loop, 256
   {
       lookMean := ST_ReadLine(stringArray, A_Index)
       lookMean := StrSplit(lookMean, ".")
       thisMean := lookMean[1]
       If (thisMean>meanValue)
       {
          meanValueK := Round((prevMean + lookMean[2] - 1)/2, 1)
          Break
       } prevMean := lookMean[2]
   }
   meanValueK := !meanValueK ? "" : " | Mean: " meanValueK meanValuePrc

   Loop, 256
   {
       lookValue := ST_ReadLine(stringArray2, A_Index)
       lookValue := StrSplit(lookValue, ".")
       thisSum += lookValue[2]
       If (thisSum>TotalPixelz//2)
       {
          medianValue := lookValue[1] - 1
          Break
       }
   }
   
   peakPrc := Round(modePointK2[1]/TotalPixelz * 100)
   peakPrc := (peakPrc>0) ? " (" peakPrc "%)" : ""
   minPrc := Round(minBrLvlK2[1]/TotalPixelz * 100)
   minPrc := (minPrc>0) ? " (" minPrc "%)" : ""
   medianPrc := Round(lookValue[2]/TotalPixelz * 100)
   medianPrc := (medianPrc>0) ? " (" medianPrc "%)" : ""
   avgPrc := Round(avgBrLvlV/TotalPixelz * 100)
   avgPrc := (avgPrc>0) ? " (" avgPrc "%)" : ""
   TotalPixelzSpaced := groupDigits(TotalPixelz)

   infoRange := "Range: " rangeA[1] - 1 " - " rangeB[1] - 1 " (" rangeC ")"
   infoPeak := "`nMode: " modePointK2[2] - 1 peakPrc
   infoAvg := " | Avg: " avgBrLvlK avgPrc " | Min: " minBrLvlK2[2] - 1 minPrc
   infoMin := "`nMedian: " medianValue medianPrc meanValueK
   entireString := infoRange infoPeak infoAvg infoMin "`nTotal pixels: " TotalPixelzSpaced
   infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.5, mainWidth//1.3, mainHeight//1.3, OSDtextColor, "0xFF" OSDbgrColor, 1, 0)
   ; tooltip, % "|" TotalPixelz "|" modePointV ", " 2ndMaxV ", " avgBrLvlV " || "  maxW "," maxH  ;  `n" PointsList
   Scale := (PrefsLargeFonts=1) ? 2.6 : 1.7
   HistogramBMP := drawHistogram(brLvlArray, 2ndMaxV, 256, Scale, "0xFF" OSDtextColor, "0xFF" OSDbgrColor, imgHUDbaseUnit//3, infoBoxBMP)
   Gdip_DisposeImage(infoBoxBMP, 1)
}

groupDigits(nrIn, delim:=" ") {
   nrOut := nrIn
   If StrLen(nrOut)>3
      nrOut := ST_Insert(delim, nrOut, StrLen(nrOut) - 2)
   If StrLen(nrOut)>7
      nrOut := ST_Insert(delim, nrOut, StrLen(nrOut) - 6)
   If StrLen(nrOut)>11
      nrOut := ST_Insert(delim, nrOut, StrLen(nrOut) - 10)
   If StrLen(nrOut)>15
      nrOut := ST_Insert(delim, nrOut, StrLen(nrOut) - 14)
   Return nrOut
}

calcRelativeSelCoords(whichBitmap, imgW:=0, imgH:=0) {
   If (imgSelX1=0 && imgSelY1=0 && imgSelX2=-1 && imgSelY2=-1)
      Return

   If (!imgW || !imgH)
      Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
   imgSelX1 := Round(prcSelX1*imgW)
   imgSelY1 := Round(prcSelY1*imgH)
   imgSelX2 := Round(prcSelX2*imgW)
   imgSelY2 := Round(prcSelY2*imgH)
}

AdaptiveImgLight(whichImg, imgPath, Width, Height) {
   brLvlArray := [], ArrChR := [], ArrChG := [], ArrChB := []
   startZeit := A_TickCount
   rMinBrLvl := minBrLvl := 256
   modePointV := lumosAdjust := 1
   maxBrLvl := sumTotalBr := countTotalPixelz := thisBrLvl := 0
   GammosAdjust := countBrightPixelz := countMidPixelz := countDarkPixelz := 0
   If (Width=1 && Height=1)
      Gdip_GetImageDimensions(whichImg, Width, Height)

   xCrop := Width//11
   yCrop := Height//11
   wCrop := Width - xCrop*2 + 1
   hCrop := Height - yCrop*2 + 1
   
   wasOk := 1
   cropBmp := Gdip_CloneBitmapArea(whichImg, xCrop, yCrop, wCrop, hCrop)
   If !cropBmp
   {
      wasOk := 0
      cropBmp := whichImg
   }

   Gdip_GetHistogram(cropBmp, 2, ArrChR, ArrChG, ArrChB)
   pEffect := Gdip_CreateEffect(6, 0, -99, 0)
   rT := Gdip_BitmapApplyEffect(cropBmp, pEffect)
   Gdip_DisposeEffect(pEffect)
   Gdip_GetHistogram(cropBmp, 3, brLvlArray, 0, 0)

   rTotalPixelz := Width*Height
   TotalPixelz := wCrop*hCrop
   otherThreshold := (usrAdaptiveThreshold>0) ? usrAdaptiveThreshold : 2
   minMaxThreshold := Floor(rTotalPixelz*0.000015) + usrAdaptiveThreshold
   If (minMaxThreshold<1)
      minMaxThreshold := 1

; gather image histogram statistics

   Loop, 256
   {
       thisIndex := A_Index - 1
       nrPixelz := brLvlArray[thisIndex]
       If !nrPixelz
          Continue

       sumTotalBr += nrPixelz * thisIndex
       If (nrPixelz>modePointV)
       {
          modePointV := nrPixelz
          modePointK := thisIndex
       }

       If (thisIndex>maxBrLvl && nrPixelz>minMaxThreshold)
          maxBrLvl := thisIndex

       If (thisIndex<minBrLvl && nrPixelz>minMaxThreshold)
          minBrLvl := thisIndex

       If (thisIndex<rMinBrLvl && nrPixelz>otherThreshold)
          rMinBrLvl := thisIndex

       If (valueBetween(thisIndex, 4, 40))
          countDarkPixelz += nrPixelz
       Else If (valueBetween(thisIndex, 170, 253))
          countBrightPixelz += nrPixelz
       Else If (valueBetween(thisIndex, 50, 165))
          countMidPixelz += nrPixelz
   }

   avgBrLvl := Round(sumTotalBr/TotalPixelz)
   Loop, 23
   {
       nrPixelz := brLvlArray[avgBrLvl - 11 + A_Index]
       If nrPixelz
          countFlatties += nrPixelz
   }

   Loop, 11
   {
       nrPixelz := brLvlArray[modePointK - 6 + A_Index]
       If nrPixelz
          countModies += nrPixelz
   }

   aMinBrLvl := (rMinBrLvl + minBrLvl)//2
   Loop, 10
   {
       nrPixelz := brLvlArray[aMinBrLvl + A_Index]
       If nrPixelz
          countLowestPx += nrPixelz
   }
   percmodePx := Round((countModies/TotalPixelz)*100, 4)
   percBrgPx := Round((countBrightPixelz/TotalPixelz) * 100, 4)
   percLowPx := Round((countLowestPx/TotalPixelz) * 100, 4)
   percDrkPx := Round((countDarkPixelz/TotalPixelz) * 100, 4)
   percMidPixu := Round((countMidPixelz/TotalPixelz) * 100, 4)
   oPercAvgPx := Round((countFlatties/TotalPixelz) * 100, 4)
   If (percmodePx<=0.00015)
      percmodePx += 0.000156
   If (percMidPixu<=0.00015)
      percMidPixu += 0.000156
   If (percBrgPx<=0.00025)
      percBrgPx += 0.000256
   If (percDrkPx<=0.001)
      percDrkPx += 0.01512
   percAvgPx := Round((oPercAvgPx + percmodePx + percMidPixu)/3, 4)
   percMidPx := 100 - percBrgPx - percDrkPx
   If (percMidPx<=0.00025)
      percMidPx += 0.000256

   If (cropBmp && wasOk=1)
      Gdip_DisposeImage(cropBmp, 1)

; make the image brighter if max. luminance [maxBrLvl] is less than 255

   multiplieruA := 255.1/maxBrLvl + (percDrkPx + (255.1 - avgBrLvl)/3 + (255.1 - (modePointK+avgBrLvl)/2)/3)/(500 + maxBrLvl*2 + avgBrLvl*10)
   If (percBrgPx>1.25)
      multiplieruA := multiplieruA - Round(percMidPx/450, 4)

   multiplieruB := 255.1/maxBrLvl + (percDrkPx/8 + (255.1 - avgBrLvl)/15 + (255.1 - modePointK)/10)/50 - percBrgPx/25 - ((percMidPixu + percMidPx)/2)/40
   multiplieru := (multiplieruA + multiplieruB)/2

   If (multiplieru<=1)
      multiplieru := 1.0002
   If (multiplieru<=1.15)
   {
      multiplieruC := 255.1/maxBrLvl + (percDrkPx + (255.1 - avgBrLvl)/3 + (255.1 - (modePointK+avgBrLvl)/2)/3)/(500 + maxBrLvl*2 + avgBrLvl*10)
      If (percBrgPx>1.25)
         multiplieruC := multiplieruC - Round(percMidPx/450, 4)
      multiplieru := multiplieruC/1.25
      If (multiplieru<=1)
         multiplieru := 1.0002
   }

   lumosAdjust := multiplieru
   GammosAdjust := - lumosAdjust/40 + 0.025 + ((percDrkPx + percAvgPx)/(900 + percBrgPx*100 + avgBrLvl*2))/3.25
   realGammos := Round(1 - ((percDrkPx + percAvgPx)/(900 + percBrgPx*100 + avgBrLvl*2))/1.25, 3)

; make the image darker when lacking contrast or min. luminance level [minBrLvl] is higher than 1
   darkerOffsetA := rMinBrLvl*multiplieru
   darkerOffsetA := (darkerOffsetA - 3)/105
   darkerOffsetB := (aMinBrLvl/multiplieru/(200 - percBrgPx/4) + percBrgPx/percDrkPx/avgBrLvl/300)/1.5
   darkerOffsetC := (minBrLvl/multiplieru)/250 + avgBrLvl/(600 - avgBrLvl/10)
   darkerOffset := (darkerOffsetA + darkerOffsetB)/2 - percLowPx/700
   testGammosAdjust := GammosAdjust - darkerOffset/1.1
   If (testGammosAdjust>-0.02 && aMinBrLvl>3)
      darkerOffset := darkerOffsetC/1.5
   If (darkerOffset<=0)
      darkerOffset := 0.00001

   lumosAdjust := lumosAdjust + darkerOffset
   GammosAdjust := GammosAdjust - darkerOffset/1.1

   If (autoAdjustMode=2)
   {
      lumosAdjust := multiplieru := 255.1/maxBrLvl
      GammosAdjust := - lumosAdjust/40 + 0.025
   } Else If (autoAdjustMode=3)
   {
      darkerOffset := rMinBrLvl/255
      lumosAdjust := 1 + darkerOffset*1.1
      GammosAdjust := 0 - darkerOffset*1.3
   }

; adjust saturation
   If (doSatAdjusts=1)
   {
      Loop, 256
      {
          thisIndex := A_Index
          nrPixR := ArrChR[thisIndex]
          nrPixG := ArrChG[thisIndex]
          nrPixB := ArrChB[thisIndex]
          If (nrPixR="" || nrPixG="" || nrPixB="")
             Continue
 
          sumTotalR += nrPixR * thisIndex
          sumTotalG += nrPixG * thisIndex
          sumTotalB += nrPixB * thisIndex
          BrLvlDifs := maxU(NrPixR, NrPixG, NrPixB) - minU(NrPixR, NrPixG, NrPixB)
          If (BrLvlDifs<minMaxThreshold*2) || (nrPixR+nrPixB+nrPixB<minMaxThreshold*3)
             Continue
          tNrPixR += nrPixR
          tNrPixG += nrPixG
          tNrPixB += nrPixB
          tNrPixAll += maxU(NrPixR, NrPixG, NrPixB)
          AllBrLvlDifs += BrLvlDifs
      }
   }
   BrLvlDiffX := maxU(tNrPixR, tNrPixG, tNrPixB) - minU(tNrPixR, tNrPixG, tNrPixB)
   PrcLvlDiffX := Round((BrLvlDiffX/tNrPixAll)*100, 4)
   PrcLvlDiffXa := Round((AllBrLvlDifs/tNrPixAll)*100, 4)

   v1a := ArrChR[maxBrLvl]
   v2a := ArrChG[maxBrLvl]
   v3a := ArrChB[maxBrLvl]
   v1b := ArrChR[maxBrLvl - 1]
   v2b := ArrChG[maxBrLvl - 1]
   v3b := ArrChB[maxBrLvl - 1]
   v1e := ArrChR[modePointK]
   v2e := ArrChG[modePointK]
   v3e := ArrChB[modePointK]
   ; hmmu := maxU(v1a, v2a, v3a) " -- " minU(v1a, v2a, v3a) " -- " v1a "," v2a "," v3a

   BrLvlDiffA := maxU(v1a, v2a, v3a) - minU(v1a, v2a, v3a)
   BrLvlDiffB := maxU(v1b, v2b, v3b) - minU(v1b, v2b, v3b)
   BrLvlDiffE := maxU(v1e, v2e, v3e) - minU(v1e, v2e, v3e)
   PrcLvlDiffA := Round((BrLvlDiffA/maxU(v1a, v2a, v3a))*100, 4)
   PrcLvlDiffB := Round((BrLvlDiffB/maxU(v1b, v2b, v3b))*100, 4)
   PrcLvlDiffE := Round((BrLvlDiffE/maxU(v1e, v2e, v3e))*100, 4)
   avgLvlsDiff := (PrcLvlDiffA + PrcLvlDiffB + PrcLvlDiffE)/3

   satAdjust := 1
   satLevel := (lumosAdjust - GammosAdjust - 1)/15 - percDrkPx/50
   If (satLevel<0)
      satLevel := 0
   satAdjust := 1 - satLevel
   If (satAdjust<0.5)
      satAdjust := 0.5
   Else If (PrcLvlDiffX>0.5)
      satAdjust := satAdjust - PrcLvlDiffX/50 + 0.02

   If (PrcLvlDiffX<0.2)
   {
      PrcLvlDiffX := Round((3*BrLvlDiffX/TotalPixelz)*100, 4)
      satAdjust := satAdjust + PrcLvlDiffX/40 + 0.02
   }

   If (avgLvlsDiff>95)
      satAdjust := satAdjust - (avgLvlsDiff - 95)/100 + 0.02
   Else If (avgLvlsDiff<20)
      satAdjust := satAdjust + (20 - avgLvlsDiff)/100

   If (PrcLvlDiffXa>50)
      satAdjust -= PrcLvlDiffXa/1000
   Else
      satAdjust += PrcLvlDiffXa/700

   avgBrLvlR := Round(sumTotalR/TotalPixelz)
   avgBrLvlG := Round(sumTotalG/TotalPixelz)
   avgBrLvlB := Round(sumTotalB/TotalPixelz)
   chnlDiffs := maxU(avgBrLvlR, avgBrLvlG, avgBrLvlB) - minU(avgBrLvlR, avgBrLvlG, avgBrLvlB)
   chnlDiffs := Round((chnlDiffs/maxBrLvl)*100, 4)
   If (avgBrLvlR>240 || avgBrLvlG>240 || avgBrLvlB>240) && (avgBrLvlR!=avgBrLvlB || avgBrLvlR!=avgBrLvlG ||  avgBrLvlB!=avgBrLvlG)
      satAdjust -= 0.05

   If (satAdjust<0.86)
      satAdjust += percDrkPx/800
   If (satAdjust<0.70)
      satAdjust := 0.70

   If (satAdjust>0.8 && chnlDiffs>=20)
      satAdjust -= chnlDiffs>50 ? chnlDiffs/825 : chnlDiffs/950
   Else If (chnlDiffs<11)
      satAdjust += (100 - chnlDiffs)/950

   otherz := (avgBrLvlG + avgBrLvlB)//1.5
   rLevelu := (avgBrLvlR>otherz+5 && avgBrLvlR<100 && otherz/avgBrLvlR<0.5) ? 1 - otherz/avgBrLvlR : 0
   satAdjust -= rLevelu/11
   otherz := (avgBrLvlR + avgBrLvlB)//1.5
   gLevelu := (avgBrLvlG>otherz+5 && avgBrLvlG<100 && otherz/avgBrLvlG<0.5) ? 1 - otherz/avgBrLvlG : 0
   satAdjust -= gLevelu/11
   otherz := (avgBrLvlG + avgBrLvlR)//1.5
   bLevelu := (avgBrLvlB>otherz+5 && avgBrLvlB<100 && otherz/avgBrLvlB<0.5) ? 1 - otherz/avgBrLvlB : 0
   satAdjust -= bLevelu/11
   If (doSatAdjusts!=1)
      satAdjust := 1

   execTime := A_TickCount - startZeit
;   ToolTip, % redLevelu ",avgRGB=" avgBrLvlR ", " avgBrLvlG ", " avgBrLvlB ", ChnlDiff=" chnlDiffs  ", AvgLvlDif=" avgLvlsDiff " %, diffA=" PrcLvlDiffA " %, diffE=" PrcLvlDiffE " %, diffX=" PrcLvlDiffX "/" PrcLvlDiffXa "% `nTh=" minMaxThreshold ", min=" minBrLvl "/" rMinBrLvl ", max=" maxBrLvl ", A=" avgBrLvl ", mP=" modePointK " [" modePointV " / " percmodePx "% ]"  ",`nL=" percBrgPx "%, D=" percDrkPx "%, Dl=" percLowPx "%, Mr=" percMidPx "% / Mo=" percMidPixu "%, oAvg=" oPercAvgPx "%, fAvg=" percAvgPx "%`ncL=" lumosAdjust ", cG=" GammosAdjust ", cS=" satAdjust ", T=" execTime "ms",,, 2
}

minU(val1, val2, val3:="null") {
  a := (val1<val2) ? val1 : val2
  If (val3!="null")
     a := (a<val3) ? a : val3
  Return a
}

maxU(val1, val2, val3:="null") {
  a := (val1>val2) ? val1 : val2
  If (val3!="null")
     a := (a>val3) ? a : val3
  Return a
}

valueBetween(value, inputA, inputB) {
    If (value=inputA || value=inputB)
       Return 1

    testRange := 0
    pointA := minU(inputA, inputB)
    pointB := maxU(inputA, inputB)
    if value between %pointA% and %pointB%
       testRange := 1
    Return testRange
}

drawHUDelements(mode, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY, imgPath) {
    Static prevImgPath, lastInvoked := 1

    maxSelX := prevMaxSelX, maxSelY := prevMaxSelY
    pBrush := (mode=2) ? pBrushB : pBrushA
    indicWidth := 150
    lineThickns := imgHUDbaseUnit
    lineThickns2 := lineThickns//4
    If (showHistogram=1)
    {
       thisImgCall := imgPath currentFileIndex zoomLevel IMGresizingMode imgFxMode
       If (imgFxMode!=1 || IMGresizingMode!=1)
       {
          prevImgPath := 0
          HistogramBMP := Gdip_DisposeImage(HistogramBMP, 1)
          tempBMP := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
          thisPosX := (DestPosX<0) ? 0 : DestPosX
          thisPosY := (DestPosY<0) ? 0 : DestPosY
          thisW := (newW>mainWidth) ? mainWidth : newW
          thisH := (newH>mainHeight) ? mainHeight : newH
          thisVPimg := Gdip_CloneBitmapArea(tempBMP, thisPosX, thisPosY, thisW, thisH)
          createHistogramBMP(thisVPimg)
          Gdip_DisposeImage(thisVPimg)
       } Else If (prevImgPath!=thisImgCall) && (A_TickCount - lastInvoked>50)
       {
          lastInvoked := A_TickCount
          prevImgPath := thisImgCall
          HistogramBMP := Gdip_DisposeImage(HistogramBMP, 1)
          createHistogramBMP(gdiBitmap)
       }
    }

; visual markers for image viewing conditions

    If (markedSelectFile || FlipImgV=1 || FlipImgH=1 || IMGlargerViewPort=1 || imgFxMode>1)
    {
       If (FlipImgH=1 && mode=2)
          Gdip_FillRoundedRectangle2(glPG, pBrush, mainWidth//2 - indicWidth//2, mainHeight//2 - lineThickns2//2, indicWidth, lineThickns2, lineThickns2//2)
       If (FlipImgV=1 && mode=2)
          Gdip_FillRoundedRectangle2(glPG, pBrush, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//2, lineThickns2, indicWidth, lineThickns2//2)
       If (imgFxMode>1 && mode=2)
       {
          Gdip_FillPie(glPG, pBrush, mainWidth//2 - indicWidth//4, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2, 0, 180)
          Gdip_FillPie(glPG, pBrush, mainWidth//2 - indicWidth//8, mainHeight//2 - indicWidth//8, indicWidth//4, indicWidth//4, 180, 360)
       }

       If (IMGlargerViewPort=1)
       {
          marginErr := (mode=2) ? 12 : 25
          lineThickns2 := (mode=2) ? lineThickns : lineThickns//3
          If (newH>mainHeight)
          {
             If (DestPosY<-marginErr)
                Gdip_FillRectangle(glPG, pBrush, 0, 0, mainWidth, lineThickns2//2)
             ; If (DestPosY>-newH+mainHeight+marginErr)
             ;    Gdip_FillRectangle(glPG, pBrush, 0, mainHeight - lineThickns2//2, mainWidth, lineThickns2//2)
          }

          If (newW>mainWidth)
          {
             If (DestPosX<-marginErr)
                Gdip_FillRectangle(glPG, pBrush, 0, 0, lineThickns2//2, mainHeight)
             ; If (DestPosX>-newW+mainWidth+marginErr)
             ;    Gdip_FillRectangle(glPG, pBrush, mainWidth - lineThickns2//2, 0, lineThickns2//2, mainHeight)
          }
       }

       If InStr(markedSelectFile, "," currentFileIndex "|")
       {
          thisThick := (mode=2) ? lineThickns//2.5 : lineThickns//4.2
          Gdip_SetPenWidth(pPen1d, thisThick)
          Gdip_DrawRectangle(glPG, pPen3, 0, 0, mainWidth, mainHeight)
          Gdip_DrawRectangle(glPG, pPen1d, 0, 0, mainWidth, mainHeight)
       } Else If (markedSelectFile)
       {
          sqSize := (mode=2) ? lineThickns + lineThickns2 : lineThickns
          sqPosX := mainWidth - sqSize
          Gdip_FillRectangle(glPG, pBrush, sqPosX, 0, sqSize, sqSize)
          thisThick := lineThickns//9
          Gdip_SetPenWidth(pPen1d, thisThick)
          Gdip_DrawRectangle(glPG, pPen1d, sqPosX, 0, sqSize, sqSize)
       }
    }

    lineThickns := imgHUDbaseUnit//9
    If (mode=2)
       lineThickns :=  imgHUDbaseUnit//10

; highlight usePrevious=1 mode

    If (mode=2 && imgFxMode=1)
    {
       indicWidth := (zoomLevel<1) ? Round(120 * zoomLevel) : 110
       If (indicWidth<50)
          indicWidth := 50
       Gdip_SetPenWidth(pPen2, lineThickns)
       Gdip_FillRectangle(glPG, pBrush, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2)
       Gdip_DrawRectangle(glPG, pPen2, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2)
    }

; draw the scrollbar indicators

    prcVisX := mainWidth/newW
    prcVisY := mainHeight/newH
    knobW := Round(mainWidth*prcVisX)
    knobH := Round(mainHeight*prcVisY)
    If (knobH<15)
       knobH := 15
    If (knobW<15)
       knobW := 15

    Ax := (DestPosX<0) ? Abs(DestPosX)/newW : 0
    Ax := Round(Ax*maxSelX)
    Ay := (DestPosY<0) ? Abs(DestPosY)/newH : 0
    Ay := Round(Ay*maxSelY)
    knobX := Round((Ax/maxSelX)*mainWidth)
    knobY := Round((Ay/maxSelY)*mainHeight) 
    knobSize := (mode=2) ? imgHUDbaseUnit//2 : imgHUDbaseUnit//3.5
    If (knobW<mainWidth - 5) && (IMGresizingMode=4)
    {
       ; Gdip_FillRectangle(glPG, pBrushA, knobX, 0, knobW, knobSize)
       scrollBarHy := mainHeight - knobSize
       Gdip_FillRectangle(glPG, pBrushE, 0, scrollBarHy, mainWidth, knobSize)
       Gdip_FillRectangle(glPG, pBrushD, knobX, scrollBarHy + 5, knobW, knobSize)
    } Else scrollBarHy := 0

    If (knobH<mainHeight - 5) && (IMGresizingMode=4)
    {
       ; Gdip_FillRectangle(glPG, pBrushA, 0, knobY, knobSize, knobH)
       scrollBarVx := mainWidth - knobSize
       Gdip_FillRectangle(glPG, pBrushE, scrollBarVx, 0, knobSize, mainHeight)
       Gdip_FillRectangle(glPG, pBrushD, scrollBarVx + 5, knobY, knobSize, knobH)
    } Else scrollBarVx := 0


; highlight number of frames and the current frame in multi-frame images [tiff and gif]

    If (totalFramesIndex>0)
    {
        bulletSize := imgHUDbaseUnit//3
        totalBulletsWidth := bulletSize * totalFramesIndex
        If (totalBulletsWidth>mainWidth)
           bulletsPerc := Round(desiredFrameIndex/totalFramesIndex, 3)
        maxBullets := Round(mainWidth/bulletSize)
        centerPos := bulletsPerc ? 0 : mainWidth//2 - totalBulletsWidth//2
        If (centerPos<0)
           centerPos := 0
        Loop, % totalFramesIndex + 1
        {
            If bulletsPerc
               whichBrush := (A_Index/maxBullets<bulletsPerc) || (desiredFrameIndex=totalFramesIndex) ? pBrushA : pBrushE
            Else
               whichBrush := (A_Index - 1 = desiredFrameIndex) ? pBrushA : pBrushE
            Gdip_FillEllipse(glPG, whichBrush, centerPos + bulletSize * (A_Index - 1), mainHeight - bulletSize, bulletSize, bulletSize)
            If (A_index>maxBullets)
               Break
        }
    }

    If (adjustNowSel=1)
       Return

    If (showHistogram=1)
    {
       Gdip_GetImageDimensions(HistogramBMP, imgW, imgH)
       thisPosX := (scrollBarVx>0) ? scrollBarVx  - imgW : mainWidth - imgW
       thisPosY := (scrollBarHy>0) ? scrollBarHy - imgH : mainHeight - imgH
       If (FlipImgH=1 || FlipImgV=1)
       {
          tempBMP := Gdip_CloneBitmap(HistogramBMP)
          flipBitmap(tempBMP, 1)
          Gdip_DrawImage(glPG, tempBMP, thisPosX, thisPosY,,,,,,, 0.85)
          Gdip_DisposeImage(tempBMP)
       } Else Gdip_DrawImage(glPG, HistogramBMP, thisPosX, thisPosY,,,,,,, 0.85)
    }

; draw the image selection rectangle and its dots

    If (activateImgSelection=1 && mode=2)
    {
       Gdip_SetPenWidth(pPen1, lineThickns)
       nImgSelX1 := minU(imgSelX1, imgSelX2)
       nImgSelY1 := minU(imgSelY1, imgSelY2)
       nimgSelX2 := maxU(imgSelX1, imgSelX2)
       nimgSelY2 := maxU(imgSelY1, imgSelY2)
       If (editingSelectionNow!=1)
       {
          If (nImgSelX1>maxSelX)
             nImgSelX1 := maxSelX - 10
          If (nImgSelY1>maxSelY)
             nImgSelY1 := maxSelY - 10
          If (nImgSelX2>maxSelX)
             nImgSelX2 := maxSelX
          If (nImgSelY2>maxSelY)
             nImgSelY2 := maxSelY
       }
       zImgSelX1 := Round(nImgSelX1*zoomLevel)
       zImgSelX2 := Round(nImgSelX2*zoomLevel)
       zImgSelY1 := Round(nImgSelY1*zoomLevel)
       zImgSelY2 := Round(nImgSelY2*zoomLevel)

       imgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
       imgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
       If (imgSelW<35)
          imgSelW := 35
       If (imgSelH<35)
          imgSelH := 35

       imgSelPx := DestPosX + minU(zImgSelX1, zImgSelX2)
       imgSelPy := DestPosY + minU(zImgSelY1, zImgSelY2)
       If (editingSelectionNow=1)
       {
          If (imgSelPx>mainWidth - 40)
             imgSelPx := mainWidth - 40
          If (imgSelPy>mainHeight - 40)
             imgSelPy := mainHeight - 40
       }

       ; Gdip_FillRectangle(glPG, pBrush, imgSelPx, imgSelPy, imgSelW, imgSelH)
       Gdip_DrawRectangle(glPG, pPen1, imgSelPx, imgSelPy, imgSelW, imgSelH)
       Gdip_SetClipRect(glPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
       Gdip_FillRectangle(glPG, pBrushE, 0, 0, mainWidth, mainHeight)
       
       Gdip_ResetClip(glPG)
    } Else If (activateImgSelection=1 && adjustNowSel!=1 && mode=1)
    {
       lineThickns := imgHUDbaseUnit//9
       If (editingSelectionNow=0)
          lineThickns :=  imgHUDbaseUnit//13

       pPen := (editingSelectionNow=1) ? pPen1d : pPen1
       Gdip_SetPenWidth(pPen, lineThickns)
       If (imgSelX2="C") && (imgSelY2="C" && IMGlargerViewPort=1)
       {
          GetMouseCoord2wind(PVhwnd, mX, mY)
          x1 := (DestPosX<0) ? Abs(DestPosX)/newW : 0
          imgSelX1 := Round(x1*maxSelX)
          y1 := (DestPosY<0) ? Abs(DestPosY)/newH : 0
          imgSelY1 := Round(y1*maxSelY)
          imgSelX2 := Round(imgSelX1 + mX/zoomLevel) + 5
          imgSelY2 := Round(imgSelY1 + mY/zoomLevel) + 5
          imgSelX1 := imgSelX2 - 15
          imgSelY1 := imgSelY2 - 15
       } Else If (imgSelX2=-1 && imgSelY2=-1)
       {
          x1 := (DestPosX<0) ? Abs(DestPosX)/newW : 0
          imgSelX1 := Round(x1*maxSelX)
          y1 := (DestPosY<0) ? Abs(DestPosY)/newH : 0
          imgSelY1 := Round(y1*maxSelY)
          imgSelX2 := Round(imgSelX1 + (mainWidth/2)/zoomLevel) + 5
          imgSelY2 := Round(imgSelY1 + (mainHeight/2)/zoomLevel) + 5
          If (imgSelX2>maxSelX/2 && newW<mainWidth)
             imgSelX2 := maxSelX//2
          If (imgSelY2>maxSelY/2 && newH<mainHeight)
             imgSelY2 := maxSelY//2
       }

       If (imgSelX1<0)
          imgSelX1 := 0
       If (imgSelY1<0)
          imgSelY1 := 0

       If (imgSelX2<0)
          imgSelX2 := 0
       If (imgSelY2<0)
          imgSelY2 := 0
       nImgSelX1 := minU(imgSelX1, imgSelX2)
       nImgSelY1 := minU(imgSelY1, imgSelY2)
       nimgSelX2 := maxU(imgSelX1, imgSelX2)
       nimgSelY2 := maxU(imgSelY1, imgSelY2)
       imgSelX1 := nImgSelX1, imgSelY1 := nImgSelY1 
       imgSelX2 := nimgSelX2, imgSelY2 := nimgSelY2 

       prcSelX1 := imgSelX1/maxSelX
       If (prcSelX1>=1)
          prcSelX1 := 0.9

       prcSelY1 := imgSelY1/maxSelY
       If (prcSelY1>=1)
          prcSelY1 := 0.9

       prcSelX2 := imgSelX2/maxSelX
       If (prcSelX2>1)
          prcSelX2 := 1

       prcSelY2 := imgSelY2/maxSelY
       If (prcSelY2>1)
          prcSelY2 := 1

       If (editingSelectionNow!=1)
       {
          If (nImgSelX1>maxSelX)
             nImgSelX1 := maxSelX - 10
          If (nImgSelY1>maxSelY)
             nImgSelY1 := maxSelY - 10
          If (nImgSelX2>maxSelX)
             nImgSelX2 := maxSelX
          If (nImgSelY2>maxSelY)
             nImgSelY2 := maxSelY
       }
       zImgSelX1 := Round(nImgSelX1*zoomLevel)
       zImgSelX2 := Round(nImgSelX2*zoomLevel)
       zImgSelY1 := Round(nImgSelY1*zoomLevel)
       zImgSelY2 := Round(nImgSelY2*zoomLevel)

       imgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
       imgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
       If (imgSelW<35)
          imgSelW := 35
       If (imgSelH<35)
          imgSelH := 35

       imgSelPx := DestPosX + minU(zImgSelX1, zImgSelX2)
       imgSelPy := DestPosY + minU(zImgSelY1, zImgSelY2)
       minMargin := (mainWidth*0.05 + mainHeight*0.05)//2
       imgSelLargerViewPort := (imgSelPx<minMargin && imgSelPy<minMargin) && (imgSelPx + imgSelW>mainWidth - minMargin) && (imgSelPy + imgSelH>mainHeight - minMargin) ? 1 : 0
       imgSelOutViewPort := 0
       If (editingSelectionNow=1)
       {
          If (imgSelPx>mainWidth - 45)
          {
             imgSelPx := mainWidth - 45
             imgSelOutViewPort := 1
          }
          If (imgSelPy>mainHeight - 45)
          {
             imgSelPy := mainHeight - 45
             imgSelOutViewPort := 1
          }
       }

       ; Gdip_FillRectangle(glPG, pBrushC, imgSelPx, imgSelPy, imgSelW, imgSelH)
       Gdip_DrawRectangle(glPG, pPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
       Gdip_SetClipRect(glPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
       Gdip_FillRectangle(glPG, pBrushE, 0, 0, mainWidth, mainHeight)
       Gdip_ResetClip(glPG)
       dotsSize := imgHUDbaseUnit//3.25
       selDotX := imgSelPx - dotsSize//2
       selDotY := imgSelPy - dotsSize//2
       selDotAx := imgSelPx + imgSelW - dotsSize//2
       selDotAy := imgSelPy + imgSelH - dotsSize//2
       selDotBx := imgSelPx + imgSelW - dotsSize//2
       selDotBy := imgSelPy - dotsSize//2
       selDotCx := imgSelPx - dotsSize//2
       selDotCy := imgSelPy + imgSelH - dotsSize//2
       If (editingSelectionNow=1)
       {
          If hitTestSelectionPath
             Gdip_DeletePath(hitTestSelectionPath)
          hitTestSelectionPath := Gdip_CreatePath()
          If (FlipImgV=1)
             imgSelPy := mainHeight - imgSelPy - imgSelH
          If (FlipImgH=1)
             imgSelPx := mainWidth - imgSelPx - imgSelW
          Gdip_AddPathRectangle(hitTestSelectionPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
          Gdip_FillRectangle(glPG, pBrushD, selDotX, selDotY, dotsSize, dotsSize)
          Gdip_FillRectangle(glPG, pBrushD, SelDotAx, SelDotAy, dotsSize, dotsSize)
          Gdip_FillRectangle(glPG, pBrushD, SelDotBx, SelDotBy, dotsSize, dotsSize)
          Gdip_FillRectangle(glPG, pBrushD, SelDotCx, SelDotCy, dotsSize, dotsSize)
       }
    }

    If (showInfoBoxHUD=1 && !AnyWindowOpen)
       drawinfoBox(mainWidth, mainHeight, imgPath)
}

generateThumbName(imgPath, forceThis:=0) {
   If (enableThumbsCaching!=1 && forceThis=0)
      Return

   FileGetSize, fileSizu, % imgPath
   FileGetTime, FileDateM, % imgPath, M
   fileInfos := imgPath fileSizu FileDateM
   MD5name := CalcStringHash(fileInfos, 0x8003)
   Return MD5name
}

getColorMatrix() {
    matrix := ""
    If (ForceNoColorMatrix=1 && AnyWindowOpen=10) || (imgFxMode=1)
       Return matrix

    If (imgFxMode=4 && bwDithering=0)       ; grayscale
       matrix := GenerateColorMatrix(2, lumosGrayAdjust, GammosGrayAdjust)
    Else If (imgFxMode=5)       ; grayscale R
       matrix := GenerateColorMatrix(3)
    Else If (imgFxMode=6)       ; grayscale G
       matrix := GenerateColorMatrix(4)
    Else If (imgFxMode=7)       ; grayscale B
       matrix := GenerateColorMatrix(5)
    Else If (imgFxMode=8)  ; alpha channel
       matrix := GenerateColorMatrix(7)
    Else If (imgFxMode=9)  ; negative / invert
       matrix := GenerateColorMatrix(6)
    Else If (imgFxMode=2 || imgFxMode=3) ; personalized
       matrix := GenerateColorMatrix(1, lumosAdjust, GammosAdjust, satAdjust, 1, chnRdecalage, chnGdecalage, chnBdecalage)
    Return matrix
}

decideGDIPimageFX(ByRef matrix, ByRef imageAttribs, ByRef pEffect) {
    matrix := imageAttribs := pEffect := ""
    matrix := getColorMatrix()
    If (thumbsDisplaying=1 && (imgFxMode=3 || imgFxMode=8))
       matrix := ""

    thisFXapplies := (imgFxMode=2 || imgFxMode=3 || imgFxMode=4 || imgFxMode=9) ? 1 : 0
    mustCreateAttribs := (realGammos!=1 && imgThreshold=0 && !matrix) || (ForceNoColorMatrix=1 || imgFxMode=1) ? 0 : 1
    If (mustCreateAttribs=1)
    {
       imageAttribs := Gdip_CreateImageAttributes()
       Gdip_SetImageAttributesColorMatrix(Matrix, imageAttribs)
       If (imgThreshold>0 && thisFXapplies=1 && ForceNoColorMatrix=0)
          Gdip_SetImageAttributesThreshold(imageAttribs, imgThreshold)
       If (realGammos!=1 && thisFXapplies=1 && ForceNoColorMatrix=0)
          Gdip_SetImageAttributesGamma(imageAttribs, realGammos)
    }

    o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
    applyAdjusts := (ForceNoColorMatrix=1) ? 0 : 1
    thisZatAdjust := (imgFxMode=4 && bwDithering=0 && zatAdjust=0) ? -40 : zatAdjust
    If (thisZatAdjust=0 && hueAdjust=0)
       applyAdjusts := 0

    If (thisFXapplies=1 && applyAdjusts=1 && o_bwDithering=0)
       pEffect := Gdip_CreateEffect(6, hueAdjust, thisZatAdjust, 0)
}

QPV_ShowImgonGuiPrev(oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgpath, CountFrames) {
    Critical, on
    Static prevUpdate, displayFastWas := 1
    If (A_TickCount - prevUpdate > 700)
       displayFastWas := 1

    prevUpdate := A_TickCount
    thisZeit := A_TickCount
    Gdip_GraphicsClear(glPG, "0x77" WindowBgrColor)
    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    whichImg := (usePrevious=1 && gdiBitmapSmall && imgFxMode!=8) ? gdiBitmapSmall : gdiBitmap
    Gdip_GetImageDimensions(whichImg, imgW, imgH)
    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    thisIMGres := imgW + imgH
    thisWinRes := mainWidth + mainHeight
    If (displayFastWas=0 && userimgQuality=1)
    {
       thisLowMode := 1
       Gdip_SetInterpolationMode(glPG, 5)
    }

    zL := (zoomLevel<1) ? 1 : zoomLevel*2
    whichBrush := (userimgQuality=1) ? pBrushHatch : pBrushHatchLow
    Gdip_SetClipRect(glPG, 0, 0, mainWidth, mainHeight)
    If (imgFxMode!=8)
    {
       If (InStr(currentPixFmt, "ARGB") && RenderOpaqueIMG!=1)
          Gdip_FillRectangle(glPG, whichBrush, DestPosX + 1, DestPosY + 1, newW - 2, newH - 2)
       Else
          Gdip_FillRectangle(glPG, pBrushWinBGR, DestPosX, DestPosY, newW, newH)
    }

    setMainCanvasTransform(mainWidth, mainHeight)
    bonus := 0
    If (newW>mainWidth || newH>mainHeight)
    {
       bonus := Round(5*zoomLevel)
       newW += bonus, newH += bonus
       mainWidth += bonus, mainHeight += bonus

       x1 := (DestPosX<0) ? Abs(DestPosX)/newW : 0
       PointX1 := Round(x1*imgW)
       y1 := (DestPosY<0) ? Abs(DestPosY)/newH : 0
       PointY1 := Round(y1*imgH)
       prcW := mainWidth/newW
       prcH := mainHeight/newH
       PointX2 := Round(PointX1 + imgW*prcW)
       PointY2 := Round(PointY1 + imgH*prcH)
       If (PointX2>imgW)
          PointX2 := imgW
       If (PointY2>imgH)
          PointY2 := imgH
       ; tooltip, % PointX1 "," pointY1 " | " PointX2 "," PointY2 " | " thisW "," thisH
    } ; Else r1 := Gdip_DrawImage(glPG, whichImg, DestPosX, DestPosY, newW, newH, 0, 0, imgW, imgH, matrix, 2, imageAttribs)
    dPosX := (newW>mainWidth) ? 0 : DestPosX
    dPosY := (newH>mainHeight) ? 0 : DestPosY
    dW := (newW>mainWidth) ? mainWidth : newW
    dH := (newH>mainHeight) ? mainHeight : newH
    sPosX := (newW>mainWidth) ? PointX1 : 0
    sPosY := (newH>mainHeight) ? PointY1 : 0
    sW := (newW>mainWidth) ? PointX2 - PointX1 : imgW
    sH := (newH>mainHeight) ? PointY2 - PointY1 : imgH
    ; ToolTip, % mainHeight "--" dH "--" sH ,,,2
    r1 := Gdip_DrawImage(glPG, whichImg, dPosX, dPosY, dW, dH, sPosX, sPosY, sW, sH, matrix, 2, imageAttribs)
    newW -= bonus, newH -= bonus
    mainWidth -= bonus, mainHeight -= bonus

    If (GIFsGuiCreated=1)
       GIFguiCreator(1, 1)

    confirmTexBGR := (vpIMGrotation=0 || vpIMGrotation=90 || vpIMGrotation=180 || vpIMGrotation=270) ? 1 : 0
    If (usrTextureBGR=1 && confirmTexBGR=1)
    {
       Gdip_SetClipRect(glPG, DestPosX, DestPosY, newW, newH, 4)
       Gdip_FillRectangle(glPG, AmbientalTexBrush, 0, 0, mainWidth, mainHeight)
       pBrush := Gdip_BrushCreateSolid("0x22000000")
       Gdip_FillRectangle(glPG, pBrush, 0, 0, mainWidth, mainHeight)
       Gdip_DeleteBrush(pBrush)
       Gdip_ResetClip(glPG)
    }

    diffIMGdecX := diffIMGdecY := 0
    If (thisLowMode=1)
       Gdip_SetInterpolationMode(glPG, imgQuality)

    ; ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
    prevDestPosX := DestPosX
    prevDestPosY := DestPosY
    whichMode := (imgFxMode=8) ? 1 : 2
    drawHUDelements(whichMode, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY, imgPath)
    Gdip_ResetWorldTransform(glPG)
    If imageAttribs
       Gdip_DisposeImageAttributes(imageAttribs)
    If (thisLowMode!=1)
       displayFastWas := (A_TickCount - thisZeit < 125) ? 1 : 0

    prevDrawingMode := (thisLowMode=1 || userimgQuality=0) ? 3 : 2
    drawModeBzeit := A_TickCount - thisZeit
    If (CountFrames>1 && AnyWindowOpen=0 && animGIFsSupport=1 && (prevAnimGIFwas!=imgPath || (A_TickCount - lastGIFdestroy > 9500)))
    {
       Sleep, 15
       prevAnimGIFwas := imgPath
       r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, 1, 1)
       GIFguiCreator(imgPath, 0, DestPosX, DestPosY, newW, newH, mainWidth, mainHeight)
    } Else
    {
       whichWin := (adjustNowSel=1) ? hGDIthumbsWin : hGDIwin
       r2 := UpdateLayeredWindow(whichWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    }

    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %hGDIwin%,, %mainX%, %mainY%
    }
    r := (r1!=0 || !r2) ? 0 : 1
    Return r
}

cleanThumbsWindow() {
    prevStartIndex := -1
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    Gdip_GraphicsClear(glPG, "0xFF" WindowBGRcolor)
    r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %hGDIthumbsWin%,, %mainX%, %mainY%
    }
}

drawImgSelectionOnWindow(operation, theMsg:="", colorBox:="", dotActive:="") {
     Static mainHeight, mainWidth, dummyPos, prevMsg, infoBoxBMP
          , lineThickns, pPen, dotsSize, infoW, infoH, pBr0
          , infoPosX, infoPosY

     prevStartIndex := -1
     If (operation=1)
     {
        dotsSize := imgHUDbaseUnit//3.25
        GetClientSize(mainWidth, mainHeight, PVhwnd)
        lineThickns := imgHUDbaseUnit//9
        pPen := Gdip_CreatePen("0x77223322", lineThickns)
        InfoW := InfoH := ""
        setMainCanvasTransform(mainWidth, mainHeight)
        If (editingSelectionNow=1)
           Gdip_SetPenDashArray(pPen, "0.8,0.8")
     } Else If (operation=2)
     {
        Gdip_GraphicsClear(glPG, "0x00" WindowBGRcolor)
        nImgSelX1 := minU(imgSelX1, imgSelX2)
        nImgSelY1 := minU(imgSelY1, imgSelY2)
        nimgSelX2 := maxU(imgSelX1, imgSelX2)
        nimgSelY2 := maxU(imgSelY1, imgSelY2)
        imgSelX1 := nImgSelX1 
        imgSelY1 := nImgSelY1 
        imgSelX2 := nimgSelX2 
        imgSelY2 := nimgSelY2 
        zImgSelX1 := Round(nImgSelX1*zoomLevel)
        zImgSelX2 := Round(nImgSelX2*zoomLevel)
        zImgSelY1 := Round(nImgSelY1*zoomLevel)
        zImgSelY2 := Round(nImgSelY2*zoomLevel)
   
        imgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
        imgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
        If (imgSelW<35)
           imgSelW := 35
        If (imgSelH<35)
           imgSelH := 35
   
        imgSelPx := prevDestPosX + minU(zImgSelX1, zImgSelX2)
        imgSelPy := prevDestPosY + minU(zImgSelY1, zImgSelY2)
        Gdip_SetClipRect(glPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
        Gdip_FillRectangle(glPG, pBrushC, 0, 0, mainWidth, mainHeight)
        Gdip_ResetClip(glPG)
        If (imgSelW>125 && imgSelH>125)
        {
           cornersPreview := coreCaptureImgCorners(gdiBitmap, 6, 100)
           Gdip_GetImageDimensions(cornersPreview, cImgW, cImgH)
           cX := imgSelPx + imgSelW//2 - cImgW//2
           cY := imgSelPy + imgSelH//2 - cImgH//2
           If (cX<1)
              cX := 0
           If (cX>mainWidth - cImgW)
              cX := mainWidth - cImgW
           If (cY<1)
              cY := 0
           If (cY>mainHeight - cImgH)
              cY := mainHeight - cImgH

           Gdip_DrawImageFast(glPG, cornersPreview, cX, cY)
           Gdip_DisposeImage(cornersPreview)
        }

        If (noTooltipMSGs=0)
        {
           If (infoBoxBMP && StrLen(theMsg)>2)
              infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
           If StrLen(theMsg)>2
              infoBoxBMP := drawTextInBox(theMsg, OSDFontName, OSDfntSize//1.3, mainWidth//2, mainHeight//2, OSDtextColor, "0xFF" OSDbgrColor, 1, 1)

           colorBoxH := colorBox ? Round(OSDfntSize*1.5) : 1
           Gdip_GetImageDimensions(infoBoxBMP, infoW, infoH)
           If (imgSelPy + imgSelH + 5 < mainHeight - infoH)
           {
              infoPosY := (imgSelPy + imgSelH<5) ? 5 : imgSelPy + imgSelH + 20
              If (infoPosY + infoH + colorBoxH>mainHeight)
                 infoPosY := mainHeight - infoH - colorBoxH
           } Else
           {
              otherPos := 1
              infoPosY := (imgSelPy - infoH - colorBoxH <20) ? 5 : imgSelPy - infoH - colorBoxH - 20
              If (infoPosY + infoH + colorBoxH>mainHeight)
                 infoPosY := mainHeight - infoH - colorBoxH
           }
 
           If (dotActive=4 || otherPos=1) && (dotActive!=3)
           {
              infoPosX := imgSelPx  + imgSelW - infoW - 25
              If (infoPosX + infoW>mainWidth)
                 infoPosX := mainWidth - infoW
           } Else
           { 
              infoPosX := (imgSelPx<5) ? 5 : imgSelPx + 25
              If (infoPosX + infoW>mainWidth)
                 infoPosX := mainWidth - infoW
           }
 
           If colorBox
           {
              pBr0 := Gdip_BrushCreateSolid(colorBox)
              Gdip_FillRectangle(glPG, pBr0, infoPosX, infoPosY + infoH, infoW, colorBoxH)
              Gdip_DeleteBrush(pBr0)
           }
           Gdip_DrawImage(glPG, infoBoxBMP, infoPosX, infoPosY,,,,,,, 0.8)
        }

        ; Gdip_FillRectangle(glPG, pBrushC, imgSelPx, imgSelPy, imgSelW, imgSelH)
        Gdip_DrawLine(glPG, pPen, zImgSelX1 + prevDestPosX, 0, zImgSelX1 + prevDestPosX, mainHeight)
        Gdip_DrawLine(glPG, pPen, 0, zImgSelY1 + prevDestPosY, mainWidth, zImgSelY1 + prevDestPosY)
        Gdip_DrawLine(glPG, pPen, zImgSelX2 + prevDestPosX, 0, zImgSelX2 + prevDestPosX, mainHeight)
        Gdip_DrawLine(glPG, pPen, 0, zImgSelY2 + prevDestPosY, mainWidth, zImgSelY2 + prevDestPosY)
        Gdip_DrawRectangle(glPG, pPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
        selDotX := imgSelPx - dotsSize//2
        selDotY := imgSelPy - dotsSize//2
        selDotAx := imgSelPx + imgSelW - dotsSize//2
        selDotAy := imgSelPy + imgSelH - dotsSize//2
        selDotBx := imgSelPx + imgSelW - dotsSize//2
        selDotBy := imgSelPy - dotsSize//2
        selDotCx := imgSelPx - dotsSize//2
        selDotCy := imgSelPy + imgSelH - dotsSize//2
        Gdip_FillRectangle(glPG, pBrushD, selDotX, selDotY, dotsSize, dotsSize)
        Gdip_FillRectangle(glPG, pBrushD, SelDotAx, SelDotAy, dotsSize, dotsSize)
        Gdip_FillRectangle(glPG, pBrushD, SelDotBx, SelDotBy, dotsSize, dotsSize)
        Gdip_FillRectangle(glPG, pBrushD, SelDotCx, SelDotCy, dotsSize, dotsSize)
        r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
     } Else
     {
        InfoW := InfoH := ""
        Gdip_ResetWorldTransform(glPG)
        If infoBoxBMP
           infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        Gdip_DeletePen(pPen)
        If pBr0
        {
           Gdip_DeleteBrush(pBr0)
           pBr0 := ""
        }
     }
}

QPV_ShowImgonGui(oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgPath, CountFrames, ForceIMGload, hasFullReloaded) {
    Critical, on
    Static IDviewPortCache, PREVtestIDvPcache
    If (ForceIMGload=1)
       IDviewPortCache := PREVtestIDvPcache := ""

    createGDIPcanvas(mainWidth, mainHeight)
    testIDvPcache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight desiredFrameIndex
    If (CountFrames>1 && AnyWindowOpen=0 && animGIFsSupport=1 && (prevAnimGIFwas!=imgPath || (A_TickCount - lastGIFdestroy > 9500)))
       mustPlayAnim := 1

    If (usePrevious=1 && testIDvPcache!=PREVtestIDvPcache) || (mustPlayAnim=1) || (imgFxMode=8 && InStr(currentPixFmt, "argb") && RenderOpaqueIMG!=1)
    {
       IDviewPortCache := PREVtestIDvPcache := ""
       r := QPV_ShowImgonGuiPrev(oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgPath, CountFrames)
       Return r
    }

    startZeit := A_TickCount  
    oldZoomLevel := matrix := ""
    prevDrawingMode := 1
    If (GIFsGuiCreated=1)
       GIFguiCreator(1, 1)

    whichImg := (usePrevious=1 && gdiBitmapSmall) ? gdiBitmapSmall : gdiBitmap
    Gdip_GetImageDimensions(whichImg, imgW, imgH)

    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    remDestPosX := DestPosX - prevDestPosX
    remDestPosY := DestPosY - prevDestPosY
    If (diffIMGdecX || diffIMGdecY) && (remDestPosX || remDestPosY)
    {
       diffIMGdecX := remDestPosX
       diffIMGdecY := remDestPosY
    } Else diffIMGdecX := diffIMGdecY := 0

    zL := (zoomLevel<1) ? 1 : zoomLevel*2
    whichBrush := (userimgQuality=1) ? pBrushHatch : pBrushHatchLow
    If (imgFxMode!=8)
    {
       If (InStr(currentPixFmt, "ARGB") && RenderOpaqueIMG!=1)
          Gdip_FillRectangle(glPG, whichBrush, DestPosX + 1, DestPosY + 1, newW - 2, newH - 2)
       Else
          Gdip_FillRectangle(glPG, pBrushWinBGR, DestPosX, DestPosY, newW, newH)
    }

    thisIDviewPortCache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight usePrevious desiredFrameIndex
    If (thisIDviewPortCache!=IDviewPortCache || !ViewPortBMPcache || CountFrames>1) && (usePrevious!=1)
    {
       prevDestPosX := DestPosX
       prevDestPosY := DestPosY
       If (diffIMGdecX || diffIMGdecY) && (IMGresizingMode=4)
          canvasClipped := 1

       nZL := (zoomLevel<1) ? 1 : zoomLevel / 2
       marginErr := (canvasClipped=1) ? 1.25*nZL : 0
       thisMainWidth := (canvasClipped=1 && diffIMGdecX) ? Abs(diffIMGdecX) + 1 : mainWidth
       thisMainHeight := (canvasClipped=1 && diffIMGdecY) ? Abs(diffIMGdecY) + marginErr : mainHeight
       If (thisMainWidth<mainWidth && thisMainHeight<mainHeight)
       {
          ignoreSomeOptimizations := 1
          thisMainWidth := mainWidth
          thisMainHeight := mainHeight
       }

       If ((newW>thisMainWidth) || (newH>thisMainHeight))
       {
          x1 := (DestPosX<0) ? Abs(DestPosX)/newW : 0
          PointX1 := (x1*imgW)
          y1 := (DestPosY<0) ? Abs(DestPosY)/newH : 0
          PointY1 := (y1*imgH)
          prcW := thisMainWidth/newW
          prcH := thisMainHeight/newH
          oPrcW := (mainWidth - thisMainWidth)/newW
          oPrcH := (mainHeight - thisMainHeight)/newH
          If (diffIMGdecX<0 && canvasClipped=1 && ignoreSomeOptimizations!=1)
             PointX1 := (PointX1 + imgW*oPrcW)
          If (diffIMGdecY<0 && canvasClipped=1 && ignoreSomeOptimizations!=1)
             PointY1 := (PointY1 + imgH*oPrcH)
          PointX2 := (PointX1 + imgW*prcW)
          PointY2 := (PointY1 + imgH*prcH)
          If (PointX2>imgW)
             PointX2 := imgW
          If (PointY2>imgH)
             PointY2 := imgH
       } ; Else r1 := Gdip_DrawImage(glPG, whichImg, DestPosX, DestPosY, newW, newH, 0, 0, imgW, imgH, matrix, 2, imageAttribs)
       dPosX := (newW>thisMainWidth) ? 0 : DestPosX
       If (canvasClipped=1 && thisMainWidth!=mainWidth && diffIMGdecX<0)
          dPosX := mainWidth - thisMainWidth
 
       dPosY := (newH>thisMainHeight) ? 0 : DestPosY
       If (canvasClipped=1 && thisMainHeight!=mainHeight && diffIMGdecY<0)
          dPosY := mainHeight - thisMainHeight 
 
       dW := (newW>thisMainWidth) ? thisMainWidth : newW
       dH := (newH>thisMainHeight) ? thisMainHeight : newH
       If (canvasClipped=1 && thisMainHeight!=mainHeight && userimgQuality=0)
          dH += nZL

       sPosX := (newW>thisMainWidth) ? (PointX1) : 0
       sPosY := (newH>thisMainHeight) ? (PointY1) : 0
       sW := (newW>thisMainWidth) ? (PointX2 - PointX1) : imgW
       sH := (newH>thisMainHeight) ? (PointY2 - PointY1) : imgH
       If (canvasClipped=1 && ignoreSomeOptimizations=1)
       {
          If ViewPortBMPcache
             r0 := Gdip_DrawImageFast(glPG, ViewPortBMPcache)
          Gdip_SetClipRect(glPG, diffIMGdecX, diffIMGdecY, mainWidth, mainHeight, 4)
       }
       r1 := Gdip_DrawImage(glPG, whichImg, dPosX, dPosY, dW, dH, sPosX, sPosY, sW, sH,,2)
       ; Tooltip, % dPosX "," dPosY "|" dW "," dH "`n" sPosX "," sPosY "|" sW "," sH "`n" newW "," newH "|" thisMainWidth "," thisMainHeight "|" mainWidth "," mainHeight "`n" diffIMGdecX "," diffIMGdecY " || " canvasClipped "," ignoreSomeOptimizations
       If (canvasClipped=1 && ignoreSomeOptimizations=1)
          Gdip_ResetClip(glPG)

       ; ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
       mustDisplay := 1
       If (usePrevious!=1)
       {
          If (IMGresizingMode=4 && canvasClipped=1 && ViewPortBMPcache)
          {
             anotherVPcache := Gdip_DisposeImage(anotherVPcache, 1)
             anotherVPcache := Gdip_CloneBitmap(ViewPortBMPcache)
          }

          ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
          IDviewPortCache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight usePrevious desiredFrameIndex
          PREVtestIDvPcache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight desiredFrameIndex
          ViewPortBMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
          ; r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
       }
    } Else mustDisplay := 1
    ; tooltip, % dontMove " - " diffIMGdecX " - " diffIMGdecY " - " r3

    If (diffIMGdecX || diffIMGdecY) && (anotherVPcache && canvasClipped=1)
    {
       r3 := Gdip_DrawImageFast(glPG, anotherVPcache, diffIMGdecX, diffIMGdecY)
       mustRecache := 1
    }

    diffIMGdecX := diffIMGdecY := 0
    If (mustRecache=1)
    {
       ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
       ViewPortBMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
    } Else anotherVPcache := Gdip_DisposeImage(anotherVPcache, 1)

    setMainCanvasTransform(mainWidth, mainHeight)
    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    If pEffect
    {
       r1 := Gdip_DrawImageFX(glPG, ViewPortBMPcache, 0, 0, mainWidth, mainHeight, matrix, pEffect, 2, imageAttribs)
       Gdip_DisposeEffect(pEffect)
    } Else If imageAttribs
    {
       r1 := Gdip_DrawImage(glPG, ViewPortBMPcache, 0, 0, mainWidth, mainHeight, 0, 0, mainWidth, mainHeight, matrix, 2, imageAttribs)
    } Else r1 := Gdip_DrawImageFast(glPG, ViewPortBMPcache)

    Gdip_SetClipRect(glPG, DestPosX, DestPosY, newW, newH, 4)
    confirmTexBGR := (vpIMGrotation=0 || vpIMGrotation=90 || vpIMGrotation=180 || vpIMGrotation=270) ? 1 : 0
    If (usrTextureBGR=1 && confirmTexBGR=1)
    {
       Gdip_FillRectangle(glPG, AmbientalTexBrush, 0, 0, mainWidth, mainHeight)
       pBrush := Gdip_BrushCreateSolid("0x11000000")
       Gdip_FillRectangle(glPG, pBrush, 0, 0, mainWidth, mainHeight)
       Gdip_DeleteBrush(pBrush)
    } Else Gdip_FillRectangle(glPG, pBrushWinBGR, -1, -1, mainWidth+2, mainHeight+2)
    Gdip_ResetClip(glPG)

    thisThick := imgHUDbaseUnit//11.5
    If (borderAroundImage=1)
       Gdip_DrawRectangle(glPG, pPen4, DestPosX - thisThick/2, DestPosY - thisThick/2, newW + thisThick, newH + thisThick)
    drawHUDelements(1, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY, imgPath)
    whichWin := (adjustNowSel=1) ? hGDIthumbsWin : hGDIwin
    Gdip_ResetWorldTransform(glPG)
    If imageAttribs
       Gdip_DisposeImageAttributes(imageAttribs)

    If (mustDisplay=1 && slideShowRunning=1 && doSlidesTransitions=1 && slideShowDelay>900 && yetAnotherVPcache)
    {
       prevStartIndex := -1
       tempBMP := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
       Gdip_DrawImageFast(glPG, tempBMP)
       r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
       Gdip_DrawImageFast(glPG, yetAnotherVPcache)
       r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
       Loop, 255
       {
           opacity := 255 - A_Index*15
           If (opacity<2)
              Break

           r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, opacity)
           Sleep, 1
       }
       Gdip_DrawImageFast(glPG, tempBMP)
       imageHasFaded := 1
    }

    If (mustDisplay=1)
       r2 := UpdateLayeredWindow(whichWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)

    If (imageHasFaded=1)
    {
       Gdip_GraphicsClear(glPG, "0xFF" WindowBGRcolor)
       UpdateLayeredWindow(hGDIthumbsWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
       Gdip_DrawImageFast(glPG, tempBMP)
       Gdip_DisposeImage(tempBMP, 1)
    }

    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %whichWin%,, %mainX%, %mainY%
    }

    r := (r1!=0 || !r2) ? 0 : 1
    totalZeit := A_TickCount - startZeitIMGload
    thisZeit := A_TickCount - startZeit
    If (totalZeit<150)
       prevFastDisplay := A_TickCount

    LastPrevFastDisplay := (totalZeit<125 && usePrevious=0) ? 1 : 0
    PannedFastDisplay := (thisZeit<100 && usePrevious=0 && canvasClipped=1) || (canvasClipped!=1) ? 1 : 0
    drawModeAzeit := A_TickCount - startZeit
    If (hasFullReloaded=1 && imageHasFaded!=1)
    {
       fullLoadZeit := A_TickCount - startZeitIMGload
       fullLoadZeit2 := (fullLoadZeit + drawModeCzeit)//2
       drawModeCzeit := maxU(fullLoadZeit, fullLoadZeit2)
    }

    ; ToolTip, % thisZeit ", " totalZeit ", " drawModeCzeit ,,,2
    Return r
}

getCaptionStyle() {
  WinGet, Stylu, Style, ahk_id %PVhwnd%
  r := (Stylu & 0xC00000) ? 0 : 1
  Return r
}

ToggleEditImgSelection() {
  Critical, on
  If (thumbsDisplaying=1)
     Return

  If (relativeImgSelCoords=1)
     calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

  If (getCaptionStyle()=1)
     ToggleTitleBaruNow()

  If (slideShowRunning=1)
     ToggleSlideShowu()

  editingSelectionNow := !editingSelectionNow
  activateImgSelection := 1
  updateUIctrl()
  dummyTimerDelayiedImageDisplay(25)
}

selectEntireImage() {
   If (thumbsDisplaying=1)
      Return

   If (getCaptionStyle()=1)
      ToggleTitleBaruNow()

   If (slideShowRunning=1)
      ToggleSlideShowu()

   Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
   If (ImgSelX2=imgW && imgSelY2=imgH
   && imgSelX1=0 && imgSelY1=0)
   {
      resetImgSelection()
   } Else
   {
      ImgSelX2 := imgW, imgSelY2 := imgH
      imgSelX1 := imgSelY1 := 0
   }

   editingSelectionNow := activateImgSelection := 1
   updateUIctrl()
   dummyTimerDelayiedImageDisplay(25)
}

toggleImgSelection() {
  If (thumbsDisplaying=1)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (relativeImgSelCoords=1)
     calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

  editingSelectionNow := 0
  activateImgSelection := !activateImgSelection
  updateUIctrl()
  dummyTimerDelayiedImageDisplay(25)
}

resetImgSelection() {
  If (thumbsDisplaying=1) || (activateImgSelection!=1 && markedSelectFile)
  {
     dropFilesSelection()
     Return
  }

  If (slideShowRunning=1 && activateImgSelection!=1)
     Return

  imgSelX1 := imgSelY1 := 0
  imgSelX2 := imgSelY2 := -1
  editingSelectionNow := activateImgSelection := 0
  updateUIctrl()
  dummyTimerDelayiedImageDisplay(25)
}

newImgSelection() {
  IMGdecalageX := IMGdecalageY := 0
  resetImgSelection()
  Sleep, 1
  ToggleEditImgSelection()
}

destroyBlacked() {
  If (imageLoading=1)
  {
     SetTimer, destroyBlacked, -50
     Return
  }
  BlackedCreator(1, 1)
}

GdipCleanMain(modus:=0) {
    ; If (A_OSVersion="WIN_7")
    ;    JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
    ; Else GuiX := GuiY := 1
    ; WinMove, ahk_id %hGDIwin%,, %GuiX%, %GuiY%, 1, 1
    ; ToolTip, % Exception("", -1).Line "`n" Exception("", -1).What, , , 2

    If (modus=2)
    {
       BlackedCreator(128)
       SetTimer, destroyBlacked, -100
       Return
    }

    GetClientSize(mainWidth, mainHeight, PVhwnd)
    opacity := (modus=1) ? "0xFF" : "0x50"
    If (modus=4 || modus=5 || modus=6)
    {
       BMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
       If (modus=4)
       {
          graphPath := Gdip_CreatePath()
          x1 := mainWidth//2 - 45
          x2 := mainWidth//2 + 45
          x3 := mainWidth//2
          y1 := mainHeight//2
          y2 := mainHeight//2
          y3 := mainHeight//2 - 200
          PointsList := x1 "," y1 "|" x2 "," y2 "|" x3 "," y3
          Gdip_AddPathPolygon(graphPath, PointsList)
          Gdip_RotatePathAtCenter(graphPath, vpIMGrotation)
       }

       Gdip_DrawImageFast(glPG, BMPcache)
       If (modus=5 || modus=6)
       {
          If (vpIMGrotation>0)
             zoomu := " @ " vpIMGrotation "°"
          zoomu := Round(zoomLevel * 100) "%" zoomu
          thisInfo := maxU(oldZoomLevel, zoomLevel) - minU(oldZoomLevel, zoomLevel)
          If (modus=6)
             thisInfo := zoomu := "( - )"

          If thisInfo
          {
             thisFntSize := (modus!=6) ? OSDfntSize*1.25 : OSDfntSize*0.75
             infoBoxBMP := drawTextInBox(zoomu, OSDFontName, thisFntSize, mainWidth//1.25, mainHeight//1.25, OSDtextColor, "0xFF" OSDbgrColor, 1, 0)
             Gdip_GetImageDimensions(infoBoxBMP, Wi, He)
             If (modus=5)
                Gdip_DrawImageFast(glPG, infoBoxBMP, mainWidth//2 - Wi//2, mainHeight//2 - He//2)
             Else
                Gdip_DrawImage(glPG, infoBoxBMP, mainWidth//2 - Wi//2, mainHeight//2 - He//2,,,,,,, 0.35)
             Gdip_DisposeImage(infoBoxBMP, 1)
          } Else
          {
             imgPath := resultedFilesList[currentFileIndex]
             zPlitPath(imgPath, 0, OutFileName, OutDir)
             entireString := "[ " currentFileIndex " / " maxFilesIndex " ] " OutFileName "`n" OutDir "\"
             infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize, mainWidth//1.25, mainHeight//1.25, OSDtextColor, "0xFF" OSDbgrColor, 1, 0)
             Gdip_DrawImageFast(glPG, infoBoxBMP)
             Gdip_DisposeImage(infoBoxBMP, 1)
             oldZoomLevel := zoomLevel
          }
       }

       If (modus=4)
       {
          Gdip_FillPath(glPG, pBrushD, graphPath)
          Gdip_DeletePath(graphPath)
       }
       thisOpacity := (modus!=6) ? "0x22" : "0x08"
       yBrush := Gdip_BrushCreateSolid(thisOpacity WindowBgrColor)
       Gdip_FillRectangle(glPG, yBrush, 0, 0, mainWidth, mainHeight)
       If (modus=6)
          Gdip_DrawRectangle(glPG, pPen3, 0, 0, mainWidth, mainHeight)
       Gdip_DeleteBrush(yBrush)
       Gdip_DisposeImage(BMPcache)
    } Else Gdip_GraphicsClear(glPG, opacity WindowBgrColor)
    r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
}

mainGdipWinThumbsGrid(mustDestroyBrushes:=0, mustShowNames:=0) {
    Critical, on
    Static pBrush1, pBrush2, pBrush3, pBrush4, pBrush5
         , brushesCreated, prevIndexu

    If (mustDestroyBrushes=1 && brushesCreated=1)
    {
       Gdip_DeleteBrush(pBrush1)
       Gdip_DeleteBrush(pBrush2)
       Gdip_DeleteBrush(pBrush3)
       Gdip_DeleteBrush(pBrush4)
       Gdip_DeleteBrush(pBrush5)
       brushesCreated := 0
       Return
    } Else If (mustDestroyBrushes=1)
       Return

    If (brushesCreated!=1)
    {
       pBrush1 := Gdip_BrushCreateSolid("0x88999999")
       pBrush2 := Gdip_BrushCreateSolid("0x55999999")
       pBrush3 := Gdip_BrushCreateSolid("0x39999922")
       pBrush4 := Gdip_BrushCreateSolid("0x55404040")
       pBrush5 := Gdip_BrushCreateSolid("0x66334433")
       brushesCreated := 1
    }
    If hitTestSelectionPath
       Gdip_DeletePath(hitTestSelectionPath)
    hitTestSelectionPath := Gdip_CreatePath()
    Gdip_GraphicsClear(glPG, "0x00" WindowBgrColor)
    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
    rowIndex := 0
    columnIndex := -1
    If (startIndex=prevIndexu && !thumbSelFileList)
       prevIndexu := ""

    If (startIndex!=prevIndexu)
       thumbSelFileList := ""

    If !markedSelectFile
    {
       thumbSelFileList := ""
       selectionDoesNotExist := 1
    }

    Loop, % maxItemsW*maxItemsH*2
    {
        thisFileIndex := startIndex + A_Index - 1
        imgPath := resultedFilesList[thisFileIndex]
        columnIndex++
        If (columnIndex>=maxItemsW)
        {
           rowIndex++
           columnIndex := 0
        }

        If (rowIndex>=maxItemsH)
           Break

        DestPosX := thumbsW*columnIndex
        DestPosY := thumbsH*rowIndex
        If (mustShowNames=1)
        {
           
           Gdip_FillRectangle(glPG, pBrushE, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_DrawRectangle(glPG, pPen3, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_FillRectangle(glPG, pBrushE, DestPosX, DestPosY, thumbsW, thumbsH)
           If StrLen(ImgPath)<4
              Gdip_FillRectangle(glPG, pBrushE, DestPosX, DestPosY, thumbsW, thumbsH)
        }

        If (mustShowNames=1 && StrLen(ImgPath)>5) || (!FileRexists(imgPath) && StrLen(imgPath)>3)
        {
           zPlitPath(imgPath, 0, fileNamu, folderu)
           entireString := thisFileIndex " | " fileNamu "`n" folderu "\"
           infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.4, thumbsW - 5, thumbsH, OSDtextColor, "0xFF" OSDbgrColor, 0, 0)
           Gdip_DrawImage(glPG, infoBoxBMP, DestPosX, DestPosY,,,,,,, 0.8)
           infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        }

        If (!FileRexists(imgPath) && StrLen(ImgPath)>5)
           Gdip_FillRectangle(glPG, pBrush4, DestPosX, DestPosY, thumbsW, thumbsH)

        If (thisFileIndex=currentFileIndex)
        {
           Gdip_FillRectangle(glPG, pBrush1, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_AddPathRectangle(hitTestSelectionPath, DestPosX, DestPosY, thumbsW, thumbsH)
           If (noTooltipMSGs=0)
           {
              zPlitPath(imgPath, 0, fileNamu, folderu)
              FileGetSize, fileSizu, % ImgPath, K
              FileGetTime, FileDateM, % ImgPath, M
              FormatTime, FileDateM, % FileDateM, dd/MM/yyyy, HH:mm
              If FileExist(imgPath)
                 fileMsg := fileSizu " Kb | " FileDateM
              Else
                 fileMsg := "File not found or access denied"
           }
           theMsg := currentFileIndex "/" maxFilesIndex " | " fileNamu " | " fileMsg " | " folderu "\"
        }

        If (thumbSelFileList && prevIndexu=startIndex)
        {
           selectedu := InStr(thumbSelFileList, "," thisFileIndex "|") ? 1 : 0
        } Else If (prevIndexu!=startIndex)
        {
           selectedu := InStr(markedSelectFile, "," thisFileIndex "|") ? 1 : 0
           If (selectedu=1)
              thumbSelFileList .= "," thisFileIndex "|"
        }

        If (selectedu=1)
        {
           Gdip_DrawRectangle(glPG, pPen3, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_FillRectangle(glPG, pBrush3, DestPosX, DestPosY, thumbsW, thumbsH)
        }
    }

    prevIndexu := startIndex
    If !selectionDoesNotExist
    {
       Gdip_FillRectangle(glPG, pBrush1, 0, 0, mainWidth, imgHUDbaseUnit//5)
       filesElected := getSelectedFiles()
       If (filesElected>0)
          theMsg := filesElected " images selected || " theMsg
    }

    scrollYpos := startIndex/maxFilesIndex
    scrollYpos := Round(mainHeight*scrollYpos)
    thisFileIndex := currentFileIndex
    If (thisFileIndex>maxFilesIndex - maxItemsPage)
       thisFileIndex := maxFilesIndex - maxItemsPage

    scrollHeight := (maxItemsPage/maxFilesIndex)*100
    scrollHeight := Ceil((mainHeight/100)*scrollHeight)
    If (scrollHeight<15)
       scrollHeight := 15

    If (noTooltipMSGs=0 && StrLen(theMsg)>1)
    {
       infoBoxBMP := drawTextInBox(theMsg, OSDFontName, Round(OSDfntSize*0.9), mainWidth, mainHeight//3, OSDtextColor, "0xFF" OSDbgrColor, 1)
       Gdip_GetImageDimensions(infoBoxBMP, infoW, infoH)
       Gdip_DrawImage(glPG, infoBoxBMP, -1, mainHeight - infoH,,,,,,, 0.85)
       Gdip_DisposeImage(infoBoxBMP, 1)
    }

    lineThickns := imgHUDbaseUnit//3.25
    If (scrollHeight<mainHeight)
    {
       Gdip_FillRectangle(glPG, pBrushE, mainWidth - lineThickns, 0, lineThickns, mainHeight)
       Gdip_AddPathRectangle(hitTestSelectionPath, mainWidth - lineThickns, 0, lineThickns, mainHeight)
       Gdip_FillRectangle(glPG, pBrushD, mainWidth - lineThickns + 5, scrollYpos, lineThickns, scrollHeight)
    }

    r2 := UpdateLayeredWindow(hGDIwin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight, 255)
}

EraseThumbsCache(dummy:=0) {
   startZeit := A_TickCount
   showTOOLtip("Emptying thumbnails cache, please wait...")
   prevMSGdisplay := A_TickCount
   countTFilez := countFilez := 0
   Loop, Files, %thumbsCacheFolder%\*.jpg
   {
      changeMcursor()
      timeNow := %A_Now%
      EnvSub, timeNow, %A_LoopFileTimeCreated%, Days
      mustRem := (timeNow>remCacheOldDays && dummy="daysITis") ? 1 : 0
      countTFilez++
      If (mustRem=1 || dummy!="daysITis")
      {
         FileDelete, % A_LoopFileFullPath
         If !ErrorLevel
            countFilez++
      }

      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Emptying thumbnails cache, please wait... " countFilez " removed until now .")
         prevMSGdisplay := A_TickCount
      }

      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }
   }

   Loop, Files, %thumbsCacheFolder%\*.png
   {
      changeMcursor()
      timeNow := %A_Now%
      EnvSub, timeNow, %A_LoopFileTimeCreated%, Days
      mustRem := (timeNow>remCacheOldDays && dummy="daysITis") ? 1 : 0
      countTFilez++
      If (mustRem=1 || dummy!="daysITis")
      {
         FileDelete, % A_LoopFileFullPath
         If !ErrorLevel
            countFilez++
      }

      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Emptying thumbnails cache, please wait... " countFilez " removed until now .")
         prevMSGdisplay := A_TickCount
      }
   }

   If (dummy="daysITis")
      moreInfo := " out of " countTFilez

   remCacheOldDays := 0
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted... Removed " countFilez " cached thumbnails...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   } Else If (A_TickCount - startZeit>1500) || (dummy="daysITis")
      showTOOLtip("Finished removing " countFilez moreInfo " cached thumbnails")
   SoundBeep, 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

createThumbsFolder() {
    If !InStr(FileExist(thumbsCacheFolder), "D")
    {
       FileCreateDir, %thumbsCacheFolder%
       If ErrorLevel
          Return "error"
    }
}

generateImgThumbCache(imgPath, newImgSize) {
    Critical, on
    r := createThumbsFolder()
    If (r="error")
       Return r

    MD5name := generateThumbName(imgPath)
    file2save := thumbsCacheFolder "\" MD5name ".jpg"
    thisImgFile := FileExist(file2save) ? file2save : imgPath
    whichLIB := (thisImgFile=file2save) ? 1 : 0
    changeMcursor()
    oBitmap := LoadBitmapFromFileu(thisImgFile, 0, whichLIB)
    If !oBitmap
       Return "error"

    Gdip_GetImageDimensions(oBitmap, imgW, imgH)
    calcIMGdimensions(imgW, imgH, newImgSize, newImgSize, ResizedW, ResizedH)
    If (valueBetween(imgW, ResizedW - 15, ResizedW + 15) && valueBetween(imgH, ResizedH - 15, ResizedH + 15))
    {
       cacheUsed := 1
       ResizedW -= 50
       ResizedH -= 50
    }
    changeMcursor()
    thisImgQuality := (userimgQuality=1) ? 3 : 5
    thumbBMP := Gdip_ResizeBitmap(oBitmap, ResizedW, ResizedH, 0, thisImgQuality)
    Gdip_DisposeImage(oBitmap, 1)
    If (cacheUsed=1)
       Sleep, 1
    changeMcursor()
    r := Gdip_SaveBitmapToFile(thumbBMP, file2save)
    Gdip_DisposeImage(thumbBMP, 1)
}

QPV_ShowThumbnails(startIndex) {
    Critical, on

    prevFullThumbsUpdate := A_TickCount
    mainStartZeit := A_TickCount
    imageLoading := 1
    changeMcursor()

    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, ignoreVaru, mainWidth, mainHeight)
    thumbsBitmap := Gdip_CreateBitmap(mainWidth, mainHeight)
    G2 := Gdip_GraphicsFromImage(thumbsBitmap, 5, 4, 2)
    hasUpdated := rowIndex := imgsListed := 0
    maxImgSize := maxZeit := columnIndex := -1

    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %hGDIthumbsWin%,, %mainX%, %mainY%
    }
    If (GIFsGuiCreated=1)
       DestroyGIFuWin()

    createThumbsFolder()
    Gdip_GraphicsClear(glPG, "0xFF" WindowBgrColor)
    ; Gdip_FillRectangle(G2, pBrushWinBGR, -2, -2, mainWidth + 5, mainHeight + 5)
    prevGUIupdate := A_TickCount
    Loop, % maxItemsW*maxItemsH*2
    {
        hasUpdated := 0
        If (A_TickCount - prevGUIupdate > 2000)
           executingCanceableOperation := A_TickCount
        If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
        {
           lastLongOperationAbort := A_TickCount
           executingCanceableOperation := mustAbandonCurrentOperations := 0
           abandonAll := 1
           Break
        }
        startZeit := A_TickCount
        thisFileIndex := startIndex + A_Index - 1
        columnIndex++
        If (columnIndex>=maxItemsW)
        {
           rowIndex++
           columnIndex := 0
        }

        If (rowIndex>=maxItemsH)
           Break

        imgPath := resultedFilesList[thisFileIndex]
        MD5name := generateThumbName(imgPath)
        file2save := thumbsCacheFolder "\" MD5name ".jpg"
        thisImgFile := FileExist(file2save) ? file2save : imgPath
        whichLIB := (thisImgFile=file2save) ? 1 : 0
        changeMcursor()
        oBitmap := LoadBitmapFromFileu(thisImgFile, 0, whichLIB)
        If oBitmap
           Gdip_GetImageDimensions(oBitmap, imgW, imgH)
        calcIMGdimensions(imgW, imgH, thumbsW, thumbsH, newW, newH)
        DestPosX := thumbsW//2 - newW//2 + thumbsW*columnIndex
        DestPosY := thumbsH//2 - newH//2 + thumbsH*rowIndex
        If (!imgW || !imgH || !oBitmap || !FileExist(imgPath))
           Continue

        pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
        If InStr(pixFmt, "ARGB")
           Gdip_FillRectangle(G2, pBrushHatchLow, DestPosX, DestPosY, newW, newH)

        If (bwDithering=1 && imgFxMode=4)
           nullu := ""
        Else If (usrColorDepth>1 && (file2save=thisImgFile || enableThumbsCaching=0))
           E := Gdip_BitmapSetColorDepth(oBitmap, internalColorDepth, ColorDepthDithering)

        flipBitmap(oBitmap)
        changeMcursor()
        r1 := Gdip_DrawImageRect(G2, oBitmap, DestPosX, DestPosY, newW, newH)
        totalFrames := Gdip_GetBitmapFramesCount(oBitmap) - 1
        If (totalFrames>1)
        {
           infoBoxBMP := drawTextInBox(totalFrames " F", OSDFontName, OSDfntSize//1.4, thumbsW, thumbsH, OSDtextColor, "0xFF" OSDbgrColor, 0, 0)
           Gdip_DrawImage(G2, infoBoxBMP, DestPosX, DestPosY,,,,,,, 0.85)
           infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        }

        oBitmap := Gdip_DisposeImage(oBitmap, 1)
        endZeit := A_TickCount
        thisZeit := endZeit - startZeit
        If (A_TickCount - prevGUIupdate > 350)
        {
           r1 := Gdip_DrawImageFast(glPG, thumbsBitmap)
           r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight)
           prevGUIupdate := A_TickCount
           hasUpdated := 1
        }
        If (thisZeit>maxZeit)
           maxZeit := thisZeit
        If (imgW>maxImgSize || imgH>maxImgSize)
           maxImgSize := maxU(imgW, imgH)

        imgsListed++
        If (thisZeit>160 && file2save!=thisImgFile && enableThumbsCaching=1
        && valueBetween(newW, 115, 395) && valueBetween(newW, 110, 395))
        {
           tmpBMP := Gdip_CloneBitmapArea(thumbsBitmap, DestPosX, DestPosY, newW, newH)
           Gdip_SaveBitmapToFile(tmpBMP, file2save, 90)
           Gdip_DisposeImage(tmpBMP, 1)
        } Else If (enableThumbsCaching=1 && (imgW>130 || imgH>130))   ; images still worth bothering to cache
           ListAllIMGs .= imgpath "`n"
    }
    executingCanceableOperation := 0
    mainEndZeit := A_TickCount
    Sleep, 0
    If oBitmap
       Gdip_DisposeImage(oBitmap, 1)

    If (bwDithering=1 && imgFxMode=4)
    {
       zBitmap := Gdip_BitmapConvertGray(thumbsBitmap, hueAdjust, zatAdjust, lumosGrayAdjust, GammosGrayAdjust)
       Gdip_DisposeImage(thumbsBitmap)
       thumbsBitmap := zBitmap
       E := Gdip_BitmapSetColorDepth(thumbsBitmap, "BW", 1)
    } 

    If pEffect
    {
       r1 := Gdip_DrawImageFX(glPG, thumbsBitmap, 0, 0, mainWidth, mainHeight, matrix, pEffect, 2, imageAttribs)
       Gdip_DisposeEffect(pEffect)
    } Else If imageAttribs
       r1 := Gdip_DrawImage(glPG, thumbsBitmap, 0, 0, mainWidth, mainHeight, 0, 0, mainWidth, mainHeight, matrix, 2, imageAttribs)
    Else If (hasUpdated=0)
       r1 := Gdip_DrawImageFast(glPG, thumbsBitmap)

    r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, dummyPos, dummyPos, mainWidth, mainHeight)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(thumbsBitmap, 1)
    If imageAttribs
       Gdip_DisposeImageAttributes(imageAttribs)
;   ToolTip, %imgW% -- %imgH% == %newW% -- %newH%

    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    prevFullThumbsUpdate := A_TickCount
    loopZeit := mainEndZeit - mainStartZeit
    If (abandonAll=1)
       Return 0

    If (maxImgSize<135)
       listHasCached := 1

    If (loopZeit>1500)
       maxImgSize := 250

    If (maxImgSize>260)
    {
       good2go := 1
       newSize := 250
    } Else If (maxImgSize<259)
    {
       good2go := 1
       newSize := 120
    }

    If (listHasCached!=1 && good2go=1 && loopZeit>400 && imgsListed>3)
    {
       showTOOLtip("Caching "  newSize "px thumbnails, please wait...")
       Loop, Parse, ListAllIMGs, `n
       {
           If (A_TickCount - prevFullThumbsUpdate>2500)
              executingCanceableOperation := A_TickCount
           generateImgThumbCache(A_LoopField, newSize)
           If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
           {
              lastLongOperationAbort := A_TickCount
              executingCanceableOperation := mustAbandonCurrentOperations := 0
              abandonAll := 1
              Break
           }
       }
       SetTimer, RemoveTooltip, -500
    }
    executingCanceableOperation := 0
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    SetTimer, ResetImgLoadStatus, -50
    prevFullThumbsUpdate := A_TickCount
    r := (r1!=0 || !r2 || abandonAll=1) ? 0 : 1
    Return r
}

calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, ByRef DestPosX, ByRef DestPosY) {
    Static orderu := {1:7, 2:8, 3:9, 4:4, 5:5, 6:6, 7:1, 8:2, 9:3}
         , prevW := 1, prevH := 1, prevZoom := 0

    LX := mainWidth - newW
    LY := mainHeight - newH
    CX := mainWidth//2 - newW//2
    CY := mainHeight//2 - newH//2
    modus := orderu[imageAligned]
    If (IMGresizingMode=4) || (thumbsDisplaying=1)
       modus := 5

    If (modus=1)
    {
       DestPosX := 0
       DestPosY := LY
    } Else If (modus=2)
    {
       DestPosX := CX
       DestPosY := LY
    } Else If (modus=3)
    {
       DestPosX := LX
       DestPosY := LY
    } Else If (modus=4)
    {
       DestPosX := 0
       DestPosY := CY
    } Else If (modus=5)
    {
       DestPosX := CX
       DestPosY := CY
    } Else If (modus=6)
    {
       DestPosX := LX
       DestPosY := CY
    } Else If (modus=7)
    {
       DestPosX := DestPosY := 0
    } Else If (modus=8)
    {
       DestPosX := CX
       DestPosY := 0
    } Else If (modus=9)
    {
       DestPosX := LX
       DestPosY := 0
    } Else DestPosX := DestPosY := 0

    If (IMGlargerViewPort!=1)
    {
       IMGdecalageY := IMGdecalageY := 1
    } Else If (IMGresizingMode=4) && (thumbsDisplaying!=1)
    {
       If (prevZoom!=zoomLevel && prevZoom!=0)
       {
          scaleu := newH/prevH ; prevH/newH
          IMGdecalageX := Round(IMGdecalageX*scaleu)
          IMGdecalageY := Round(IMGdecalageY*scaleu)
       } 

       If (IMGdecalageX<LX//2) && (newW>mainWidth)
          IMGdecalageX := LX//2
       If (IMGdecalageY<LY//2) && (newH>mainHeight)
          IMGdecalageY := LY//2

       If (newW-5>mainWidth)
          DestPosX := DestPosX + IMGdecalageX
       Else
          IMGdecalageX := 0

        If (newH-5>mainHeight)
          DestPosY := DestPosY + IMGdecalageY
       Else
          IMGdecalageY := 0

       If (DestPosX>0) && (newW>mainWidth)
       {
          DestPosX := 0
          IMGdecalageX := - LX//2
       }

       If (DestPosY>0) && (newH>mainHeight)
       {
          DestPosY := 0
          IMGdecalageY := - LY//2
       }
    }

    prevW := newW
    prevH := newH
    prevZoom := zoomLevel
}

GuiSize:
   PrevGuiSizeEvent := A_EventInfo
   prevGUIresize := A_TickCount
  ; If (imageLoading!=1) ; && (A_TickCount - startZeitIMGload>130)
   thisZeit := A_TickCount - scriptStartTime
   If (thisZeit>450)
      SetTimer, GDIupdater, -25
Return

GDIupdater() {
   updateUIctrl()
   thisZeit := A_TickCount - scriptStartTime
   If (thisZeit<450)
      Return

   If (toolTipGuiCreated=1)
      TooltipCreator(1, 1)

   SetTimer, dummyTimerReloadThisPicture, Off
   SetTimer, dummyTimerDelayiedImageDisplay, Off
   If (GIFsGuiCreated=1) ; || (A_TickCount - lastGIFdestroy<300)
   {
      If (PrevGuiSizeEvent=1)
         prevStartIndex := -1
      Else
         extendedDestroyGIFuWin(0)
      Return 1
   }

   If (thisZeit<600) ;  || (imageLoading=1)
      Return 1

   resetSlideshowTimer(0)
   imgPath := resultedFilesList[currentFileIndex]
   clippyTest := resultedFilesList[0]
   If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
      thisClippyIMG := 1

   If (!imgPath || !maxFilesIndex || PrevGuiSizeEvent=1 || !CurrentSLD) && (thisClippyIMG!=1)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()

      prevStartIndex := -1
      If (A_TickCount - lastWinDrag<350)
         Return
      If (thumbsDisplaying=1) && (!maxFilesIndex || !CurrentSLD)
         WinMove, ahk_id %hGDIthumbsWin%,, 1, 1, 1, 1
      Else GdipCleanMain(0)
      Return
   }

   If (maxFilesIndex>0 && PrevGuiSizeEvent!=1 && thumbsDisplaying!=1) && (A_TickCount - scriptStartTime>500) || (thisClippyIMG=1)
   {
      delayu := (A_TickCount - lastWinDrag<450) ? 450 : 15
      filterDelayiedImageDisplay()
      ; dummyTimerDelayiedImageDisplay(delayu)
      dummyTimerReloadThisPicture(750)
      prevStartIndex := -1
   } Else If (thumbsDisplaying=1 && maxFilesIndex>1)
   {
      GetClientSize(mainWidth, mainHeight, PVhwnd)
      WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight% , ahk_id %hGDIthumbsWin%
      delayu := (A_TickCount - lastWinDrag<450) ? 550 : 325
      SetTimer, RefreshThumbsList, % -delayu
   }
}

RefreshThumbsList() {
   UpdateThumbsScreen(2)
}

ToggleViewModeTouch() {
   zoomLevel := IMGdecalageY := IMGdecalageX := 1
   If (IMGresizingMode=1)
   {
      IMGresizingMode := 3
      ToggleImageSizingMode()
   } Else
   {
      IMGresizingMode := 0
      ToggleImageSizingMode()
   }
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

ReloadDynamicFolderz(fileNamu) {
    showTOOLtip("Refreshing files list, please wait...")
    bckpResultedFilesList := []
    bkcpMaxFilesIndex := 0
    listu := coreLoadDynaFolders(fileNamu)
    Loop, Parse, listu,`n
    {
       line := Trim(A_LoopField)
       fileTest := StrReplace(line, "|")
       If (RegExMatch(line, RegExFilesPattern) || StrLen(line)<4 || !FileExist(fileTest))
          Continue
       Else
          GetFilesList(line "\*")
    }
}

coreLoadDynaFolders(fileNamu) {
   Loop, 987
   {
       IniRead, newFolder, % fileNamu, DynamicFolderz, DF%A_Index%, @
       If StrLen(newFolder)>3
          listu .= Trim(newFolder) "`n"
       Else countFails++
       changeMcursor()
       If (countFails>3)
          Break
   }
   listu := listu "`n" Trim(DynamicFoldersList) "`n"
   changeMcursor()
   Sort, listu, UD`n
   Return listu
}

RegenerateEntireList() {
    If (AnyWindowOpen>0)
       CloseWindow()

    newStaticFoldersListCache := ""
    showTOOLtip("Refreshing files list, please wait...")
    If (RegExMatch(CurrentSLD, "i)(\.sld)$") && InStr(DynamicFoldersList, "|hexists|"))
       listu := coreLoadDynaFolders(CurrentSLD)
    Else If (StrLen(DynamicFoldersList)>3)
       listu := DynamicFoldersList

    listu := StrReplace(listu, "|hexists|")
    If StrLen(listu)<4
    {
       showTOOLtip("No list of dynamic folders found...")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Return
    }

    If StrLen(filesFilter)>1
    {
       usrFilesFilteru := filesFilter := ""
       FilterFilesIndex()
    }
    bckpResultedFilesList := []
    bkcpMaxFilesIndex := 0
    renewCurrentFilesList()
    mustGenerateStaticFolders := 1
    Loop, Parse, listu,`n
    {
       line := Trim(A_LoopField)
       fileTest := StrReplace(line, "|")
       If (RegExMatch(line, RegExFilesPattern) || StrLen(line)<4 || !FileExist(fileTest))
          Continue
       GetFilesList(line "\*")
    }
    GenerateRandyList()
    SoundBeep , 900, 100
    RandomPicture()
}

sldGenerateFilesList(readThisFile, doFilesCheck, mustRemQuotes) {
    FileRead, tehFileVar, %readThisFile%
    If (mustRemQuotes=1)
    {
       StringReplace, tehFileVar, tehFileVar,"-,,All
       StringReplace, tehFileVar, tehFileVar,",,All
    }

    startOperation := A_TickCount
    Loop, Parse, tehFileVar,`n,`r
    {
       line := Trim(A_LoopField)
       If InStr(line, "|")
       {
          doRecursive := 2
          line := StrReplace(line, "|")
       } Else doRecursive := 1

       If (A_TickCount - startOperation>1500)
          executingCanceableOperation := A_TickCount

       If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
       {
          lastLongOperationAbort := A_TickCount
          executingCanceableOperation := mustAbandonCurrentOperations := 0
          abandonAll := 1
          Break
       }

       changeMcursor()
       If (RegExMatch(line, RegExFilesPattern) && RegExMatch(line, "i)^(.\:\\.)"))
       {
          If (doFilesCheck=1)
          {
             If !FileRexists(line)
                Continue
          }
          maxFilesIndex++
          SLDhasFiles := 1
          resultedFilesList[maxFilesIndex] := line
       } Else If RegExMatch(line, "i)^(.\:\\.).*(\\)$")
       {
          line := Trim(line, "\")
          FileGetAttrib, OutputVar, %line%
          If InStr(OutputVar, "D")
          {
             isRecursive := (doRecursive=2) ? "|" : ""
             DynamicFoldersList .= "`n" isRecursive line "`n"
             GetFilesList(line "\*", doRecursive)
          }
       }
    }
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    executingCanceableOperation := 0
    If (abandonAll=1)
    {
       showTOOLtip("Operation aborted. Files list empty.")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 950, 100
       Try DllCall("user32\SetCursor", "Ptr", hCursN)
       Return "abandoned"
    }
}

filterCoreString(stringu, behave, thisFilter) {
  If (behave=2)
  {
     If !RegExMatch(stringu, "i)(" thisFilter ")")
        mustSkip := 1
  } Else
  {
     If RegExMatch(stringu, "i)(" thisFilter ")")
        mustSkip := 1
  }
  Return mustSkip
}

GetFilesList(strDir, doRecursive:=1) {
  showTOOLtip("Loading files from...`n" strDir "`n")
  prevMSGdisplay := A_TickCount
  If InStr(strDir, "|")
  {
     doRecursive := 2
     strDir := StrReplace(strDir, "|")
  }

  dig := (doRecursive=2) ? "" : "R"
  addedNow := 0
  startOperation := A_TickCount
  Loop, Files, %strDir%, %dig%
  {
      If RegExMatch(A_LoopFileName, RegExFilesPattern) && (A_LoopFileSize>512)
      {
         addedNow++
         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := A_LoopFileFullPath
      }

      If (A_TickCount - startOperation>1000)
         executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Loading files from...`n" strDir "`n" addedNow "/" A_Index " files...")
         prevMSGdisplay := A_TickCount
      }

      changeMcursor()
      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }
  }
  executingCanceableOperation := 0
  Try DllCall("user32\SetCursor", "Ptr", hCursN)
  If (abandonAll=1)
     showTOOLtip("Files list loading aborted...")
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

IDshowImage(imgID, opentehFile:=0) {
    Static prevImgPath, lastInvoked := 1
    imgPath := resultedFilesList[imgID]
    If !imgPath
    {
       If (A_TickCount - lastInvoked>1050)
          SoundBeep, 300, 50
       lastInvoked := A_TickCount
       Return 0
    }

    isPipe := InStr(imgPath, "||")
    imgPath := StrReplace(imgPath, "||")
    If isPipe                  ; remove «deleted file» marker if somehow the file is back
    {
       If FileRexists(imgPath)
          resultedFilesList[imgID] := imgPath
    }
    If (InStr(AprevImgCall, imgPath) || InStr(BprevImgCall, imgPath))
       ignoreFileCheck := 1

    If (ignoreFileCheck!=1 && skipDeadFiles=1)
    {
       If (!FileRexists(imgPath) && opentehFile!=250 && imgPath!=prevImgPath)
       {
          If (autoRemDeadEntry=1 && imgID=currentFileIndex)
             remCurrentEntry(0, 1)
          Return 0
       }
    }

    prevImgPath := (opentehFile=0 || opentehFile=2) ? imgPath : 0
    If (opentehFile=1)
    {
       If !FileRexists(imgPath)
          informUserFileMissing()
       Try Run, %imgPath%
    } Else If (opentehFile=2)
    {
        ShowTheImage(imgPath, 2)  ; prevent down-scaled display
    } Else If (opentehFile=3)
    {
        ShowTheImage(imgPath, 2, 1)  ; force image reload
    } Else ShowTheImage(imgPath)
    Return 1
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND := 0x112, TPM_RETURNCMD := 0x100

  h := WinExist("ahk_id " hwnd)
  JEE_ClientToScreen(hPicOnGui1, 1, 1, X, Y)
  Suspend, on
  SetTimer, unSuspendu, -250
  hSysMenu := DllCall("GetSystemMenu", "Uint", Hwnd, "int", False) 
  r := DllCall("TrackPopupMenu", "uint", hSysMenu, "uint", TPM_RETURNCMD, "int", X, "int", Y, "int", 0, "uint", h, "uint", 0)
  If (r=0)
     Return

  SendMessage, WM_SYSCOMMAND, r,,,ahk_id %Hwnd%
  Return 1
}

unSuspendu() {
  Suspend, Off
}

AddAnimatedGIF(imagefullpath , x="", y="", w="", h="", guiname = "1") {
  global AG1
  static AGcount := 1, pic
  Static jsCode := "oncontextmenu=""return false"" onselectstart=""return false"" ondragstart=""return false"""
  ; Static jsCode := "<script>  var client = {  init: function() {  var o=this`;   $(""img"").mousedown(function(e){  e.preventDefault()  })`;  $(""body"").on(""contextmenu"",function(e){  return false`;  })`;}}`;   </script>"
  html := "<html><body " jsCode " style='background-color: transparent' style='overflow:hidden' leftmargin='0' topmargin='0'><img src='" imagefullpath "' width=" w " height=" h " border=0 padding=0></body></html>"
; Clipboard := html
  Gui, AnimGifxx:Add, Picture, vpic, %imagefullpath%
  GuiControlGet, pic, AnimGifxx:Pos
  Gui, AnimGifxx:Destroy
  Gui, %guiname%:Add, ActiveX, % (x = "" ? " " : " x" x ) . (y = "" ? " " : " y" y ) . (w = "" ? " w" picW : " w" w ) . (h = "" ? " h" picH : " h" h ) " gDestroyGIFuWin vAG" AGcount, Shell.Explorer
  AG%AGcount%.navigate("about:blank")
  AG%AGcount%.document.write(html)
  Return "AG" AGcount
}

extendedDestroyGIFuWin(showNow) {
    If (GIFsGuiCreated!=1)
       Return
    DestroyGIFuWin()
    Global lastGIFdestroy := A_TickCount
    prevAnimGIFwas := resultedFilesList[currentFileIndex]
    If (showNow=1)
       IDshowImage(currentFileIndex, 2)
    Else
       dummyTimerReloadThisPicture(90)
}

DestroyGIFuWin() {
   If (easySlideStoppage=1 && slideShowRunning=1)
      ToggleSlideShowu()
   GIFguiCreator(1, 1)
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
    If (A_OSVersion="WIN_XP")
    {
       MouseGetPos, mX, mY
       lastMx := mX
       lastMy := mY
       Return
    }

    Static POINT
         , init := VarSetCapacity(POINT, 8, 0) && NumPut(8, POINT, "Int")
    GPC := DllCall("user32.dll\GetPhysicalCursorPos", "Ptr", &POINT)
    If !GPC
    {
       MouseGetPos, mX, mY
       Return
;      Return DllCall("kernel32.dll\GetLastError")
    }

    lastMx := mX := NumGet(POINT, 0, "Int")
    lastMy := mY := NumGet(POINT, 4, "Int")
    Return
}

trimArray(arr) {
; Hash O(n) 
; Function by errorseven from:
; https://stackoverflow.com/questions/46432447/how-do-i-remove-duplicates-from-an-autohotkey-array
    hash := {}
    newArr := []
    For e, v in arr
    {
        If (!hash.Haskey(v))
        {
           hash[(v)] := 1
           newArr.push(v)
        }
    }
    Return newArr
}

ReverseListNow() {
    showTOOLtip("Reversing files list order...")
    backCurrentSLD := CurrentSLD
    CurrentSLD := ""
    resultedFilesList := reverseArray(resultedFilesList)
    prevStartIndex := -1
    CurrentSLD := backCurrentSLD
    dummyTimerDelayiedImageDisplay(50)
    SoundBeep , 900, 100
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

RandomizeListNow() {
    showTOOLtip("Randomizing files list order...")
    backCurrentSLD := CurrentSLD
    CurrentSLD := ""
    resultedFilesList := Random_ShuffleArray(resultedFilesList)
    CurrentSLD := backCurrentSLD
    prevStartIndex := -1
    dummyTimerDelayiedImageDisplay(50)
    SoundBeep , 900, 100
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

Random_ShuffleArray(Array) {
; function from "Facade Functional Programming Suite"
; by Shambles, from https://github.com/Shambles-Dev/AutoHotkey-Facade
; modified by Marius Șucan

    ; This is the Fisher–Yates shuffle.
    ; local
    ; Sig := "Random_Shuffle(Array)"
    ; _Validate_ArrayArg(Sig, "Array", Array)
    Result := Array.Clone()
    maxArray := Array.Count()
    Loop % maxArray - 1
    {
        Random, J, % A_Index, % maxArray
        ; J               := Random(A_Index, Array.Count())
        Temp            := Result[A_Index]
        Result[A_Index] := Result[J]
        Result[J]       := Temp
    }
    Return Result
}

reverseArray(a) {
; function inspired by RHCP from https://autohotkey.com/board/topic/97722-some-array-functions/

    aStorage := []
    maxIndexu := a.maxIndex()
    Loop, % maxIndexu
       aStorage[A_Index] := a[maxIndexu - A_index + 1]

    Return aStorage
}

coreResizeIMG(imgPath, newW, newH, file2save, goFX, toClippy, rotateAngle, soloMode:=1, imgW:=0, imgH:=0, batchMode:=0) {
    If (soloMode=1)
    {
        oBitmap := LoadBitmapFromFileu(imgPath)
        Gdip_GetImageDimensions(oBitmap, imgW, imgH)
        rr := (toClippy=1) ? "" : "error"
        If !newW
           newW := imgW
        If !newH
           newH := imgH
        If (rotateAngle>0 && ResizeWithCrop=1 && activateImgSelection=1 && ResizeCropAfterRotation=1)
           Gdip_GetRotatedDimensions(newW, newH, rotateAngle, newW, newH)

        If !oBitmap
           Return rr
    } Else oBitmap := soloMode

    If (ResizeApplyEffects=1 || goFX=1)
    {
       mustDoBw := (bwDithering=1 && imgFxMode=4) ? 1 : 0
       If (imgFxMode=3 && toClippy!=1)
          AdaptiveImgLight(oBitmap, imgPath, 1, 1)
       decideGDIPimageFX(matrix, imageAttribs, pEffect)
    }

    oPixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
    brushRequired := !InStr(oPixFmt, "argb") ? 1 : 0

    If (InStr(oPixFmt, "argb") && RenderOpaqueIMG=1 && (goFX=1 || ResizeApplyEffects=1))
    {
       nBitmap := Gdip_RenderPixelsOpaque(oBitmap, pBrushWinBGR)
       Gdip_DisposeImage(rBitmap, 1)
       oBitmap := nBitmap
       brushRequired := must24bits := 1
    }

    pixFmt := (must24bits=1) ? "0x21808" : "0x26200A"     ; 24-RGB  //  32-ARGB
    thisImgQuality := (ResizeQualityHigh=1) ? 7 : 5
    If (activateImgSelection=1 && ResizeCropAfterRotation=1 && ResizeWithCrop=1 && rotateAngle>0)
    {
       oBitmap := coreRotateBMP(oBitmap, rotateAngle, goFX, thisImgQuality, pixFmt, brushRequired)
       Gdip_GetImageDimensions(oBitmap, imgW, imgH)
    }

    If (relativeImgSelCoords=1 && activateImgSelection=1 && ResizeWithCrop=1 && soloMode=1)
       calcRelativeSelCoords(oBitmap, imgW, imgH)

    If (activateImgSelection=1 && (goFX=1 || ResizeWithCrop=1))
    {
       calcImgSelection2bmp(imgW, imgH, newW, newH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    } Else
    {
       imgSelW := Round(imgW), imgSelH := Round(imgH)
       imgSelPx := 0, imgSelPy := 0

       zImgSelW := Round(newW), zImgSelH := Round(newH)
       zImgSelPx := 0, zImgSelPy := 0
    }

    thumbBMP := Gdip_CreateBitmap(zImgSelW, zImgSelH, pixFmt)
    G2 := Gdip_GraphicsFromImage(thumbBMP, thisImgQuality, 4, 2)
    If (userUnsprtWriteFMT=3 && batchMode=1)
    {
       zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       file2save := OutDir "\" OutNameNoExt "." rDesireWriteFMT
    } Else If (userUnsprtWriteFMT=2 && !RegExMatch(file2save, saveTypesRegEX) && batchMode=1)
    {
       zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       file2save := OutDir "\" OutNameNoExt "." rDesireWriteFMT
    }

    If (brushRequired=1) || (!RegExMatch(file2save, saveAlphaTypesRegEX) && toClippy!=1)
       Gdip_FillRectangle(G2, pBrushWinBGR, -2, -2, imgW + 4, imgH + 4)

    If (goFX=1 || ResizeApplyEffects=1)
    {
       setMainCanvasTransform(zImgSelW, zImgSelH, G2)
       If (bwDithering=1 && imgFxMode=4)
       {
          zBitmap := Gdip_BitmapConvertGray(oBitmap, hueAdjust, zatAdjust, lumosGrayAdjust, GammosGrayAdjust)
          Gdip_DisposeImage(rBitmap)
          oBitmap := zBitmap
          E := Gdip_BitmapSetColorDepth(oBitmap, "BW", 1)
       } Else If (usrColorDepth>1)
          E := Gdip_BitmapSetColorDepth(oBitmap, internalColorDepth, ColorDepthDithering)
 
       If pEffect
       {
          Gdip_BitmapApplyEffect(oBitmap, pEffect)
          Gdip_DisposeEffect(pEffect)
       }
    }

    changeMcursor()
    Gdip_DrawImage(G2, oBitmap, 0, 0, zImgSelW, zImgSelH, imgSelPx, imgSelPy, imgSelW, imgSelH, matrix, 2, imageAttribs)
    Gdip_DisposeImage(oBitmap, 1)
    Sleep, 0

    If (activateImgSelection=1 && ResizeCropAfterRotation=0 && ResizeWithCrop=1 && rotateAngle>0) || (rotateAngle>0 && activateImgSelection!=1) || (rotateAngle>0 && ResizeWithCrop!=1)
       thumbBMP := coreRotateBMP(thumbBMP, rotateAngle, goFX, thisImgQuality, pixFmt, brushRequired)

    If (toClippy!=1 && FileExist(file2save))
       Try FileSetAttrib, -R, %file2save%

    Sleep, 0
    changeMcursor()
    If (toClippy=1)
       r := Gdip_SetBitmapToClipboard(thumbBMP)
    Else
       r := Gdip_SaveBitmapToFile(thumbBMP, file2save, 90)

    If (toClippy!=1) && (r=-2 || r=-1)
       r := SaveFIMfile(file2save, thumbBMP)

    Gdip_DeleteGraphics(G2)
    If thumbBMP
       Gdip_DisposeImage(thumbBMP, 1)
    Return r
}

coreRotateBMP(whichBitmap, rotateAngle, goFX, thisImgQuality, pixFmt, brushRequired) {
    Static imgOrientOpt := {"i000":0, "i100":1, "i200":2, "i300":3, "i010":4, "i110":5, "i210":6, "i310":7, "i001":6, "i101":7, "i201":4, "i301":5, "i011":2, "i111":3, "i211":0, "i311":1}

    confirmSimpleRotation := (rotateAngle=0 || rotateAngle=90 || rotateAngle=180 || rotateAngle=270) ? 1 : 0
    If (confirmSimpleRotation=1)
    {
       imgFoperation := (rotateAngle=90) ? 1 : 0
       imgFoperation := (rotateAngle=180) ? 2 : imgFoperation
       imgFoperation := (rotateAngle=270) ? 3 : imgFoperation
;       If (goFX=1 || ResizeApplyEffects=1)
;          imgFoperation := imgOrientOpt["i" imgFoperation FlipImgH FlipImgV]
       If (imgFoperation>0)
          Gdip_ImageRotateFlip(whichBitmap, imgFoperation)
       thumbBMP := whichBitmap
    } Else
    {
       whichBrush := (brushRequired=1) ? pBrushWinBGR : ""
       zBitmap := Gdip_RotateBitmapAtCenter(whichBitmap, rotateAngle, whichBrush, thisImgQuality, pixFmt)
       Gdip_DisposeImage(whichBitmap, 1)
       thumbBMP := zBitmap
;       If (goFX=1 || ResizeApplyEffects=1) && (ResizeCropAfterRotation=1)
;          flipBitmap(thumbBMP, 1)
    }
    Return thumbBMP
}

flipBitmap(whichBmp, ignoreThis:=0) {
   imgFoperation := (FlipImgH=1) ? 4 : 0
   imgFoperation := (FlipImgV=1) ? 6 : imgFoperation
   imgFoperation := (FlipImgV=1 && FlipImgH=1) || (vpIMGrotation=180 && ignoreThis=0) ? 2 : imgFoperation
   If (imgFoperation>0)
      Gdip_ImageRotateFlip(whichBmp, imgFoperation)
}

calcImgSelection2bmp(imgW, imgH, newW, newH, ByRef imgSelPx, ByRef imgSelPy, ByRef imgSelW, ByRef imgSelH, ByRef zImgSelPx, ByRef zImgSelPy, ByRef zImgSelW, ByRef zImgSelH, ByRef nImgSelX1, ByRef nImgSelY1, ByRef nImgSelX2, ByRef nImgSelY2) {
   nImgSelX1 := minU(imgSelX1, imgSelX2)
   nImgSelY1 := minU(imgSelY1, imgSelY2)
   nImgSelX2 := maxU(imgSelX1, imgSelX2)
   nImgSelY2 := maxU(imgSelY1, imgSelY2)
   If (nImgSelX1<0)
      nImgSelX1 := 0
   If (nImgSelY1<0)
      nImgSelY1 := 0

   If (nImgSelX2>imgW)
      nImgSelX2 := imgW
   If (nImgSelY2>imgH)
      nImgSelY2 := imgH

   imgSelW := maxU(nImgSelX1, nImgSelX2) - minU(nImgSelX1, nImgSelX2)
   imgSelH := maxU(nImgSelY1, nImgSelY2) - minU(nImgSelY1, nImgSelY2)
   imgSelPx := minU(nImgSelX1, nImgSelX2)
   imgSelPy := minU(nImgSelY1, nImgSelY2)
   If (imgSelW<5)
   {
      imgSelW := 5
      imgSelPx := (imgSelPx>=5) ? imgSelPx - 5 : 0
      nImgSelX2 := imgSelPx + imgSelW
   }

   If (imgSelH<5)
   {
      imgSelH := 5
      imgSelPy := (imgSelPy>=5) ? imgSelPy - 5 : 0
      nImgSelY2 := imgSelPy + imgSelH
   }

   nImgSelX1 := imgSelPx
   nImgSelY1 := imgSelPy

   zLv := newH/imgH
   zLh := newW/imgW
   zImgSelX1 := Floor(nImgSelX1*zLh)
   zImgSelY1 := Floor(nImgSelY1*zLv)
   zImgSelX2 := Floor(nImgSelX2*zLh)
   zImgSelY2 := Floor(nImgSelY2*zLv)
   If (zImgSelX2>newW)
      zImgSelX2 := newW
   If (zImgSelY2>newH)
      zImgSelY2 := newH

   zImgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
   zImgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
   zImgSelPx := minU(zImgSelX1, zImgSelX2)
   zImgSelPy := minU(zImgSelY1, zImgSelY2)
   If (zImgSelW<5)
   {
      zImgSelW := 5
      zImgSelPx := (zImgSelPx>=5) ? zImgSelPx - 5 : 0
   }

   If (zImgSelH<5)
   {
      zImgSelH := 5
      zImgSelPy := (zImgSelPy>=5) ? zImgSelPy - 5 : 0
   }
}

ResizePanelHelpBoxInfo() {
    triggerOwnDialogs()
    MsgBox,, %appTitle%, In «Advanced mode» there is limited support for color depths other than 24 and 32 bits. All images will be converted to 24 bits per pixel. If the alpha channel is present, the resulted file will be in 32 bits, if the format allows. When saving images in formats that do not support an alpha channel, the window background color is used.`n`nUse «Simple mode» to better preserve color depths. It has full support for: 1-, 8-, 24-, 32-, 16- (UINT16), 48- (RGB16), 64- (RGBA16), 32- (FLOAT), 96- (RGBF) and 128- (RGBAF) bits images. High-dynamic range formats supported: .EXR, .HDR, .JXR, .HDP, .PFM and .TIFF.`n`nPlease also note, while there is full support for multi-frames/paged images [for GIFs and TIFFs only] in the viewport... on file (re)save or format conversion, only the first frame will be preserved.
}

OpenGitHub() {
  Try Run, https://github.com/marius-sucan/Quick-Picto-Viewer
  CloseWindow()
}

AboutWindow() {
    createSettingsGUI(1)
    btnWid := 100
    txtWid := 360
    Gui, Add, Button, x1 y1 h1 w1 Default gCloseWindow, Close
    Gui, -DPIScale
    Gui, Font, s19 Bold, Arial, -wrap
    Gui, Add, Text, x20 y15 Section, %appTitle% v%Version%
    Gui, Add, Picture, x+60 w130 h-1 +0x3 gOpenGitHub, quick-picto-viewer.ico
    Gui, Font, s10 Bold, Arial, -wrap
    Gui, Add, Link, xs yp+55, Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a>.
    Gui, Font
    Gui, Add, Link, y+15 w410, Based on the prototype image viewer by <a href="http://sites.google.com/site/littlescripting/">SBC</a> from October 2010 published on <a href="https://autohotkey.com/board/topic/58226-ahk-picture-viewer/">AHK forums</a>.
    If (PrefsLargeFonts=1)
    {
       btnWid := btnWid + 50
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }
    Gui, +DPIScale
    Gui, Add, Text, y+10 w%txtWid%, Current version: v%Version% from %vReleaseDate%. AHK version: %A_AhkVersion%.
    Gui, Add, Text, y+10 w%txtWid%, Dedicated to people with really large image collections and slideshow needs :-).
    Gui, Add, Text, y+10 w%txtWid%, This application contains code from various entities. You can find more details in the source code.
    Gui, Font, Bold
    Gui, Add, Link, y+15 w%txtWid%, To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> or <a href="mailto:marius.sucan@gmail.com?subject=%appTitle% v%Version%">send me feedback</a>.
    Gui, Add, Link, y+15 w%txtWid%, New and previous versions are available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">GitHub</a>.
    Gui, Font, Normal
    If !A_IsAdmin
    {
       Gui, Add, Button, xs y+25 w105 Default gCloseWindow, &Close
       Gui, Add, Button, x+15 gRunAdminMode, &Run in admin mode
    }
    Gui, SettingsGUIA: Show, AutoSize, About %appTitle% v%Version%
}

BtnChangeSatPlus() {
  ChangeSaturation(1)
  updatePanelColorsInfo()
  updatePanelColorSliderz()
}

BtnChangeSatMin() {
  ChangeSaturation(-1)
  updatePanelColorsInfo()
  updatePanelColorSliderz()
}

BtnChangeLumPlus() {
  ChangeLumos(1)
  updatePanelColorsInfo()
  updatePanelColorSliderz()
}

BtnChangeLumMin() {
  ChangeLumos(-1)
  updatePanelColorsInfo()
  updatePanelColorSliderz()
}

BtnChangeGammPlus() {
  ChangeGammos(1)
  updatePanelColorsInfo()
  updatePanelColorSliderz()
}

BtnChangeGammMin() {
  ChangeGammos(-1)
  updatePanelColorsInfo()
  updatePanelColorSliderz()
}

PanelsCheckFileExists() {
   If (currentFileIndex=0)
      Return 0

   imgPath := resultedFilesList[currentFileIndex]
   zPlitPath(imgPath, 0, fileNamu, folderu)
   If !FileRexists(imgPath)
   {
      showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
      SoundBeep, 300, 50
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return 0
   } Else Return 1
}

PanelResolutionSorting() {
    Global sortResMode

    createSettingsGUI(20)
    btnWid := 100
    txtWid := slideWid := 280

    If (PrefsLargeFonts=1)
    {
       slideWid := slideWid + 135
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       Gui, Font, s%LargeUIfontValue%
    }

    Gui, Add, Text, x15 y15 Section, This operation can take a lot of time.`nEach file will be read to identify its resolution in pixels.
    Gui, Add, Button, xs y+10 h30 w%btnWid% Default gActSortResolution, &Resolution
    Gui, Add, Button, x+5 hp wp gActSortimgW, &Image width
    Gui, Add, Button, xs y+10 hp wp gActSortimgH, Image &height
    Gui, Add, Button, x+5 hp wp  gActSortImgWHratio, A&spect ratio [W/H]
    Gui, Add, Button, xs y+10 hp w80 gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Choose sorting mode: %appTitle%
}

PanelJpegPerformOperation() {
    Global mainBtnACT

    If !PanelsCheckFileExists()
       Return

    filesElected := getSelectedFiles(0, 1)
    If (vpIMGrotation>0)
    {
       FlipImgV := FlipImgH := vpIMGrotation := 0
       showTOOLtip("Image rotation: 0°")
       RefreshImageFile()
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Sleep, 250
    } Else If (FlipImgH=1 || FlipImgV=1)
    {
       FlipImgV := FlipImgH := 0
       dummyTimerDelayiedImageDisplay(50)
    } 

    createSettingsGUI(12)
    btnWid := 100
    txtWid := slideWid := 280

    If (PrefsLargeFonts=1)
    {
       slideWid := slideWid + 135
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       Gui, Font, s%LargeUIfontValue%
    }

    If (activateImgSelection!=1)
       jpegDoCrop := 0

    Gui, Add, Text, x15 y15 Section, Please choose a JPEG lossless operation...
    Gui, Add, DropDownList, y+10 Section w%txtWid% AltSubmit Choose%jpegDesiredOperation% vjpegDesiredOperation, None|Flip Horizontally|Flip Vertically|Transpose|Transverse|Rotate 90°|Rotate 180°|Rotate -90° [270°]
    Gui, Add, Checkbox, y+10 Checked%jpegDoCrop% vjpegDoCrop, Crop image(s) to selected area (irreversible)
    If (filesElected>1)
       Gui, Add, Text, y+20, %filesElected% files are selected.
    If (activateImgSelection!=1)
       GuiControl, Disable, jpegDoCrop

    If (filesElected<2)
    {
       Gui, Add, Button, xs y+10 h30 w%btnWid% gBTNautoCropRealtime, &Auto-crop selection
       Gui, Add, Button, x+5 hp w%btnWid% gAutoCropPanelWindow, &Configure auto-crop
       Gui, Add, Button, xs+0 y+25 h30 w35 gPreviousPicture, <<
       Gui, Add, Button, x+5 hp wp gNextPicture, >>
       Gui, Add, Button, x+5 hp w%btnWid% Default gBtnPerformJpegOp vmainBtnACT, &Perform operation
    } Else
       Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gBtnPerformJpegOp, &Perform operation
    Gui, Add, Button, x+5 hp w80 gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, JPEG lossless operations: %appTitle%
}

BtnPerformJpegOp() {
    Static lastInvoked := 1
    GuiControlGet, jpegDesiredOperation
    GuiControlGet, jpegDoCrop
    GuiControlGet, mainBtnACT
    If (A_TickCount - lastInvoked < 150) || (jpegDesiredOperation=1 && jpegDoCrop=0)
    {
       showTOOLtip("No operations selected to perform...")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Return
    }

    imgPath := resultedFilesList[currentFileIndex]
    initFIMGmodule()
    If !wasInitFIMlib
    {
       triggerOwnDialogs()
       Msgbox, 48, %appTitle%, ERROR: Unable to initialize Free Image library module...`n`nThis functionality is currently unavailable.
       Return
    }

    lastInvoked := A_TickCount
    prevStartIndex := -1
    filesElected := getSelectedFiles()
    If (filesElected>1)
    {
       batchJpegLLoperations()
       Return
    } Else If !InStr(currentPixFmt, "argb")
       r := coreJpegLossLessAction(imgPath)

    GuiControl, SettingsGUIA: Disable, mainBtnACT
    SetTimer, reactivateMainBtnACT, -800
    If r
    {
       FlipImgV := FlipImgH := vpIMGrotation := 0
       showTOOLtip("JPEG operation completed succesfully.")
       RefreshImageFile()
    } Else
    {
       SoundBeep , 300, 100
       Msgbox, 48, %appTitle%, ERROR: The JPEG operation has failed. The filew might not be a JPEG as the file extension suggests.
    }
    lastInvoked := A_TickCount
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

reactivatemainBtnACT() {
    If (AnyWindowOpen=12 || AnyWindowOpen=18 || AnyWindowOpen=17)
    {
       If (imageLoading=1)
          SetTimer, reactivatemainBtnACT, -600
       Else
          GuiControl, SettingsGUIA: Enable, mainBtnACT
    }
}

batchJpegLLoperations() {
   filesElected := getSelectedFiles()
   If (filesElected>1)
   {
      msgInfos := (jpegDoCrop=1) ? "`n`nThe crop operation IS irreversible!" : ""
      triggerOwnDialogs()
      MsgBox, 52, %appTitle%, Are you sure you want to perform the JPEG transformations on the selected files? There are currently %filesElected% selected files.%msgInfos%
      IfMsgBox, Yes
        good2go := 1
   } Else good2go := 1
 
   If (good2go!=1)
      Return

   If AnyWindowOpen
      CloseWindow()
   Sleep, 25
   showTOOLtip("Performing JPEG lossless operations on " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   countFilez := countTFilez := 0
   Loop, % filesElected
   {
      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }

      thisFileIndex := getSelectedFiles(A_Index)
      file2rem := resultedFilesList[thisFileIndex]
      file2rem := StrReplace(file2rem, "||")
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Performing JPEG lossless operations on " countFilez "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If !RegExMatch(file2rem, "i)(.\.(jpeg|jpg|jpe))$")
         Continue

      Try FileSetAttrib, -R, %file2rem%
      Sleep, 1
      countTFilez++
      changeMcursor()
      r := coreJpegLossLessAction(file2rem)
      If r
         countFilez++
      Else
         someErrors := "`nErrors occured during file operations..."
   }
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   prevStartIndex := -1
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. " countFilez " out of " filesElected " selected files were processed until now..." someErrors)
   } Else
   {
      SoundBeep, 900, 100
      showTOOLtip(countFilez " out of " countTFilez " selected JPEG files were processed" someErrors)
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
   Return
}

coreJpegLossLessAction(imgPath) {
    If (jpegDoCrop=1 && activateImgSelection=1)
    {
       changeMcursor()
       r1 := GetImgFileDimension(imgPath, imgW, imgH)
       If (relativeImgSelCoords=1)
          calcRelativeSelCoords(hFIFimgA, imgW, imgH)

       calcImgSelection2bmp(imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       x1 := Round(X1), y1 := Round(Y1)
       x2 := Round(X2), y2 := Round(Y2)
       changeMcursor()
       r := FreeImage_JPEGTransformCombined(imgPath, imgPath, jpegDesiredOperation - 1, X1, Y1, X2, Y2)
    } Else
    {
       changeMcursor()
       r := FreeImage_JPEGTransform(imgPath, imgPath, jpegDesiredOperation - 1)
    }

    Return r
}

ColorsAdjusterPanelWindow() {
    Global sliderBright, sliderContrst, sliderSatu, realTimePreview, CustomZoomCB, infoImgZoom
         , infoBright, infoContrst, infoSatu, BtnLumPlus, BtnLumMin, BtnFlipH, infoZatAdjust
         , BtnGammPlus, BtnGammMin, BtnSatPlus, BtnSatMin, ResizeModeDL, BtnFlipV, infohueAdjust
         , infoRGBchnls, RGBcbList := "-3.0|-2.0|-1.5|-1.0|-0.9|-0.8|-0.7|-0.6|-0.5|-0.4|-0.3|-0.2|-0.1|0.0|0.1|0.2|0.3|0.4|0.5|0.6|0.7|0.8|0.9|1.0|1.5|2.0|3.0"
         , infoRealGammos, infoThreshold, UIimgThreshold, UIrealGammos, infoImgRotation, UIdoubleZoom

    If (thumbsDisplaying=1)
       Return

    imgPath := resultedFilesList[currentFileIndex]
    If !FileRexists(imgPath)
    {
       showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
       SoundBeep, 300, 50
       Return
    }

    If (activateImgSelection=1)
       toggleImgSelection()

    changeMcursor()
    ToolTip, Please wait...,,, 2
    createSettingsGUI(10)
    ForceNoColorMatrix := 0
    If (usrColorDepth=0)
       usrColorDepth := 1

    btnWid := 100
    txtWid := slideWid := 280
    slide2Wid := 180
    If (PrefsLargeFonts=1)
    {
       slideWid := slideWid + 135
       slide2Wid := slide2Wid + 65
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       Gui, Font, s%LargeUIfontValue%
    }

    thisZL := Round(zoomLevel*100) "%"
    UIdoubleZoom := (zoomLevel>4.99) ? 1 : 0
    UIimgThreshold := imgThreshold*100
    UIrealGammos := realGammos*100
    Gui, Add, Tab3,, Main|Others

    Gui, Tab, 1 ; general
    Gui, Add, DropDownList, x+15 y+15 Section w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%imgFxMode% vimgFxMode, Original image colors|Personalized colors|Auto-adjusted colors|Grayscale|Red channel|Green channel|Blue channel|Alpha channel|Inverted colors
    Gui, Add, DropDownList, xs y+5 w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%autoAdjustMode% vAutoAdjustMode, Adaptive mixed mode|Increase brightness|Increase contrast
    Gui, Add, ComboBox, x+1 w90 gColorPanelTriggerImageUpdate vusrAdaptiveThreshold, -2000|-100|-50|-2|1|2|50|1000|2000|%usrAdaptiveThreshold%||
    Gui, Add, Checkbox, xs y+5 w%txtWid% gColorPanelTriggerImageUpdate Checked%doSatAdjusts% vdoSatAdjusts, Auto-adjust image saturation level
    Gui, Add, Checkbox, x+5 w90 gColorPanelTriggerImageUpdate Checked%bwDithering% vbwDithering, B/W
    Gui, Add, Text, xs y+15 w%txtWid% gBtnResetBrightness vinfoBright, Brightness: ----
    Gui, Add, Slider, y+5 AltSubmit ToolTip NoTicks w%slideWid% gColorPanelTriggerImageUpdate vsliderBright Range-100-100, 1
    Gui, Add, Button, x+1 hp w45 gBtnChangeLumPlus vBtnLumPlus, +
    Gui, Add, Button, x+1 hp w45 gBtnChangeLumMin vBtnLumMin, -
    Gui, Add, Text, xs y+8 w%txtWid% gBtnResetContrast vinfoContrst, Contrast: ----
    Gui, Add, Slider, y+5 AltSubmit ToolTip NoTicks w%slideWid% gColorPanelTriggerImageUpdate vsliderContrst Range-100-100, 1
    Gui, Add, Button, x+1 hp w45 gBtnChangeGammPlus vBtnGammPlus, -
    Gui, Add, Button, x+1 hp w45 gBtnChangeGammMin vBtnGammMin, +
    Gui, Add, Text, xs y+8 w%txtWid% gBtnResetSaturation vinfoSatu, Saturation: ----
    Gui, Add, Slider, y+5 AltSubmit ToolTip NoTicks w%slideWid% gColorPanelTriggerImageUpdate vsliderSatu Range-100-100, 1
    Gui, Add, Button, x+1 hp w45 gBtnChangeSatPlus vBtnSatPlus, +
    Gui, Add, Button, x+1 hp w45 gBtnChangeSatMin vBtnSatMin, -
    Gui, Add, Text, xs y+8 w%slide2Wid% gBtnResetVibrance vinfoZatAdjust, Vibrance: ----
    Gui, Add, Text, x+5 w%slide2Wid% gBtnResetHue vinfohueAdjust, Hue: ----
    Gui, Add, Slider, xs y+5 AltSubmit ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vzatAdjust Range-100-100, % zatAdjust
    Gui, Add, Slider, x+5 AltSubmit ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vhueAdjust Range-180-180, % hueAdjust
    Gui, Add, Text, xs y+8 w%slide2Wid% gBtnResetRealGamma vinfoRealGammos, Gamma: ----
    Gui, Add, Text, x+5 w%slide2Wid% gBtnResetThreshold vinfoThreshold, Threshold: ----
    Gui, Add, Slider, xs y+5 AltSubmit ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vUIrealGammos Range0-800, % UIrealGammos
    Gui, Add, Slider, x+5 AltSubmit ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vUIimgThreshold Range0-100, % UIimgThreshold
    ; Gui, Add, Checkbox, xs y+15 gColorPanelTriggerImageUpdate Checked%realTimePreview% vrealTimePreview, Update image in real time
    Gui, Add, Text, xs y+15 gBtnResetCHNdec vinfoRGBchnls, RGB channels balance:
    Gui, Add, ComboBox, x+5 w65 gColorPanelTriggerImageUpdate vchnRdecalage, %RGBcbList%|%chnRdecalage%||
    Gui, Add, ComboBox, x+5 wp gColorPanelTriggerImageUpdate vchnGdecalage, %RGBcbList%|%chnGdecalage%||
    Gui, Add, ComboBox, x+5 wp gColorPanelTriggerImageUpdate vchnBdecalage, %RGBcbList%|%chnBdecalage%||

    Gui, Tab, 2 ; others
    Gui, Add, DropDownList, x+15 y+15 Section w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%IMGresizingMode% vIMGresizingMode, Adapt all images into view|Adapt only large images into view|Original resolution (100`%)|Custom zoom level
    Gui, Add, DropDownList, y+10 w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%usrColorDepth% vusrColorDepth, Simulate color depth|2 bits [4 colors]|3 bits [8 colors]|4 bits [16 colors]|5 bits [32 colors]|6 bits [64 colors]|7 bits [128 colors]|8 bits [256 colors]|16 bits [65536 colors]
    Gui, Add, Checkbox, x+5 gColorPanelTriggerImageUpdate Checked%ColorDepthDithering% vColorDepthDithering, Dithering
    Gui, Add, Text, xs y+10 w%slide2Wid% gBtnResetRotation vinfoImgRotation, Image rotation: ----
    Gui, Add, Checkbox, x+5 gColorPanelTriggerImageUpdate Checked%UIdoubleZoom% vUIdoubleZoom, 2x
    Gui, Add, Text, x+1 w%slide2Wid% gBtnResetZoom vinfoImgZoom, Image zoom: ----
    Gui, Add, Slider, xs y+10 ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vvpIMGrotation Range0-360, % Round(vpIMGrotation)
    Gui, Add, Slider, x+5 ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vCustomZoomCB Range1-500, % thisZL
    Gui, Add, Text, xs y+10, Flip image
    Gui, Add, Checkbox, x+10 gColorPanelTriggerImageUpdate Checked%FlipImgV% vFlipImgV, vertically
    Gui, Add, Checkbox, x+10 gColorPanelTriggerImageUpdate Checked%FlipImgH% vFlipImgH, horizontally
    Gui, Add, Checkbox, xs y+10 gColorPanelTriggerImageUpdate Checked%RenderOpaqueIMG% vRenderOpaqueIMG, Remove alpha channel [for RGBA images]
    Gui, Add, Checkbox, xs y+10 gColorPanelTriggerImageUpdate Checked%userimgQuality% vuserimgQuality, High quality image resampling
    Gui, Add, Checkbox, xs y+10 gColorPanelTriggerImageUpdate Checked%usrTextureBGR% vusrTextureBGR, Auto-generated ambiental textured viewport background
    Gui, Add, Checkbox, xs y+10 gColorPanelTriggerImageUpdate Checked%showHistogram% vshowHistogram, Display the image luminance histogram
    Gui, Add, Text, xs y+10, Right click on the viewport to collapse this panel.
    Gui, Add, Button, xs y+15 h30 w%btnWid% gBtnResetImageView, &Reset all options

    Gui, Tab
    Gui, Add, Button, xs-10 y+20 h30 w35 gBtnPrevImg, <<
    Gui, Add, Button, x+5 hp wp gBtnNextImg, >>
    Gui, Add, Button, x+5 hp wp gBtnResetImageView, [R]
    Gui, Add, Button, x+5 hp w%btnWid% gCopyImage2clip, &Copy to clipboard
    Gui, Add, Button, x+5 hp w%btnWid% gBtnSaveIMGadjustPanel, &Save image as
    Gui, Add, Button, x+5 hp w80 Default gCloseWindow, C&lose
    changeMcursor()
    Gui, SettingsGUIA: Show, AutoSize, Adjust image view: %appTitle%
    updatePanelColorsInfo()
    updatePanelColorSliderz()
    ToolTip,,,, 2
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
}

BtnResetBrightness() {
  lumosAdjust := lumosAdjust := 1
  GuiControl, SettingsGUIA:, infoBright, Brightness: 1.000
  GuiControl, SettingsGUIA:, sliderBright, 1
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetContrast() {
  GammosAdjust := GammosGrayAdjust := 0
  GuiControl, SettingsGUIA:, infoContrst, Contrast: 0.000
  GuiControl, SettingsGUIA:, sliderContrst, 0
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetSaturation() {
  satAdjust := 1
  GuiControl, SettingsGUIA:, infoSatu, Saturation: 1.000
  GuiControl, SettingsGUIA:, sliderSatu, 0
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetVibrance() {
  zatAdjust := 0
  GuiControl, SettingsGUIA:, infoZatAdjust, Vibrance: 0`%
  GuiControl, SettingsGUIA:, zatAdjust, 0
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetHue() {
  hueAdjust := 0
  GuiControl, SettingsGUIA:, infohueAdjust, Hue: 0° 
  GuiControl, SettingsGUIA:, hueAdjust, 0
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetRealGamma() {
  realGammos := 1
  GuiControl, SettingsGUIA:, infoRealGammos, Gamma: 1.000 
  GuiControl, SettingsGUIA:, UIrealGammos, 100
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetThreshold() {
  imgThreshold := 0
  GuiControl, SettingsGUIA:, infoThreshold, Threshold: 0
  GuiControl, SettingsGUIA:, UIimgThreshold, 0
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetCHNdec() {
  chnRdecalage := chnGdecalage := chnBdecalage := 0
  GuiControl, SettingsGUIA: Choose, chnRdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnGdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnBdecalage, 14
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetZoom() {
  zoomLevel := 1
  GuiControl, SettingsGUIA:, UIdoubleZoom, 0
  GuiControl, SettingsGUIA:, infoImgZoom, Image zoom: 100 `%
  GuiControl, SettingsGUIA:, CustomZoomCB, 100
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetRotation() {
  If (vpIMGrotation=0)
     Return

  vpIMGrotation := 0
  GuiControl, SettingsGUIA:, vpIMGrotation, 0
  GuiControl, SettingsGUIA:, infoImgRotation, Image rotation: 0°
  GuiControl, SettingsGUIA: Enable, usrTextureBGR
  writeMainSettings()
  RefreshImageFile()
}

BtnSaveIMGadjustPanel() {
   ForceNoColorMatrix := 0
   SaveClipboardImage("yay")
}

BtnNextImg() {
  If (maxFilesIndex<2 || !maxFilesIndex)
     Return

  ForceNoColorMatrix := 0
  NextPicture()
  If (imgFxMode=3)
  {
     updatePanelColorsInfo()
     updatePanelColorSliderz()
  }
}

BtnPrevImg() {
  If (maxFilesIndex<2 || !maxFilesIndex)
     Return

  ForceNoColorMatrix := 0
  PreviousPicture()
  If (imgFxMode=3)
  {
     updatePanelColorsInfo()
     updatePanelColorSliderz()
  }
}

updatePanelColorSliderz() {
   If (imgFxMode=1 || imgFxMode=2 || imgFxMode=3)
   {
      infoSliderBright := (lumosAdjust>1) ? Floor((lumosAdjust - 1)/14*100) : - Floor((1 - lumosAdjust)*100)
      infoSliderContrst := (GammosAdjust<0) ? Floor(Abs(GammosAdjust)/15*100) : - Floor((Abs(GammosAdjust))*100)
      infoSliderSatu := (satAdjust>1) ? Floor((satAdjust - 1)/2*100) : - Floor((1 - satAdjust)*100)
      realGammosInfo := realGammos*100
      GuiControl, SettingsGUIA:, sliderSatu, % infoSliderSatu 
      GuiControl, SettingsGUIA:, sliderBright, % infoSliderBright
      GuiControl, SettingsGUIA:, sliderContrst, % infoSliderContrst
      GuiControl, SettingsGUIA:, UIrealGammos, % realGammosInfo
   } Else If (imgFxMode=4)
   {
      infoSliderBright := (lumosGrayAdjust>1) ? Floor((lumosGrayAdjust - 1)/14*100) :  - Floor((1 - lumosGrayAdjust)*100)
      infoSliderContrst := (GammosGrayAdjust<0) ? Floor(Abs(GammosGrayAdjust)/15*100) : - Floor((Abs(GammosGrayAdjust))*100)
      GuiControl, SettingsGUIA:, sliderBright, % infoSliderBright
      GuiControl, SettingsGUIA:, sliderContrst, % infoSliderContrst
      GuiControl, SettingsGUIA:, sliderSatu, 0
   }
}

updatePanelColorsInfo() {
   GuiControlGet, imgFxMode
   GuiControlGet, IMGresizingMode
   GuiControlGet, bwDithering

   infolumosAdjust := (imgFxMode=4) ? Round(lumosGrayAdjust, 3) : Round(lumosAdjust, 3)
   infoGammosAdjust := (imgFxMode=4) ? Round(GammosGrayAdjust, 3) : Round(GammosAdjust, 3)
   infoSatAdjust := Round(satAdjust, 3)
   infoZoom := Round(zoomLevel*100)
   GuiControl, SettingsGUIA:, infoBright, % "Brightness: " infolumosAdjust
   GuiControl, SettingsGUIA:, infoContrst, % "Contrast: " infoGammosAdjust
   GuiControl, SettingsGUIA:, infoSatu, % "Saturation: " infoSatAdjust
   GuiControl, SettingsGUIA:, infoZatAdjust, % "Vibrance: " zatAdjust "%"
   GuiControl, SettingsGUIA:, infohueAdjust, % "Hue: " hueAdjust "°"
   GuiControl, SettingsGUIA:, infoRealGammos, % "Gamma: " realGammos
   GuiControl, SettingsGUIA:, infoThreshold, % "Threshold: " imgThreshold
   GuiControl, SettingsGUIA:, infoImgZoom, % "Image zoom: " infoZoom " %"
   GuiControl, SettingsGUIA:, infoImgRotation, % "Image rotation: " vpIMGrotation "° "

   If (vpIMGrotation=0 || vpIMGrotation=90 || vpIMGrotation=180 || vpIMGrotation=270)
      GuiControl, SettingsGUIA: Enable, usrTextureBGR
   Else
      GuiControl, SettingsGUIA: Disable, usrTextureBGR

   If (usrColorDepth>1)
   {
      GuiControl, SettingsGUIA: Disable, RenderOpaqueIMG
      GuiControl, SettingsGUIA: Enable, ColorDepthDithering
   } Else
   {
      GuiControl, SettingsGUIA: Enable, RenderOpaqueIMG
      GuiControl, SettingsGUIA: Disable, ColorDepthDithering
   }

   If (IMGresizingMode=4)
   {
      GuiControl, SettingsGUIA: Enable, CustomZoomCB
      GuiControl, SettingsGUIA: Enable, UIdoubleZoom
      GuiControl, SettingsGUIA: Enable, infoImgZoom
   } Else
   {
      GuiControl, SettingsGUIA: Disable, UIdoubleZoom
      GuiControl, SettingsGUIA: Disable, infoImgZoom
      GuiControl, SettingsGUIA: Disable, CustomZoomCB
   }

   o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
   If (imgFxMode=2) || (imgFxMode=4 && o_bwDithering=0) || (imgFxMode=9)
   {
      GuiControl, SettingsGUIA: Enable, infoRealGammos
      GuiControl, SettingsGUIA: Enable, UIrealGammos
   } Else
   {
      GuiControl, SettingsGUIA: Disable, infoRealGammos
      GuiControl, SettingsGUIA: Disable, UIrealGammos
   }

   If (imgFxMode=2)
   {
      GuiControl, SettingsGUIA: Enable, sliderSatu
      GuiControl, SettingsGUIA: Enable, sliderBright
      GuiControl, SettingsGUIA: Enable, sliderContrst
      GuiControl, SettingsGUIA: Enable, BtnLumPlus
      GuiControl, SettingsGUIA: Enable, BtnLumMin
      GuiControl, SettingsGUIA: Enable, BtnGammPlus
      GuiControl, SettingsGUIA: Enable, BtnGammMin
      GuiControl, SettingsGUIA: Enable, BtnSatPlus
      GuiControl, SettingsGUIA: Enable, BtnSatMin
      GuiControl, SettingsGUIA: Enable, infoBright
      GuiControl, SettingsGUIA: Enable, infoContrst
      GuiControl, SettingsGUIA: Enable, infoSatu
   } Else If (imgFxMode=4 && o_bwDithering=0)
   {
      GuiControl, SettingsGUIA: Enable, infoBright
      GuiControl, SettingsGUIA: Enable, infoContrst
      GuiControl, SettingsGUIA: Disable, infoSatu
      GuiControl, SettingsGUIA: Enable, sliderBright
      GuiControl, SettingsGUIA: Enable, sliderContrst
      GuiControl, SettingsGUIA: Disable, sliderSatu
      GuiControl, SettingsGUIA: Enable, BtnLumPlus
      GuiControl, SettingsGUIA: Enable, BtnLumMin
      GuiControl, SettingsGUIA: Enable, BtnGammPlus
      GuiControl, SettingsGUIA: Enable, BtnGammMin
      GuiControl, SettingsGUIA: Disable, BtnSatPlus
      GuiControl, SettingsGUIA: Disable, BtnSatMin
   } Else
   {
      GuiControl, SettingsGUIA: Disable, infoBright
      GuiControl, SettingsGUIA: Disable, infoContrst
      GuiControl, SettingsGUIA: Disable, infoSatu
      GuiControl, SettingsGUIA: Disable, BtnLumPlus
      GuiControl, SettingsGUIA: Disable, BtnLumMin
      GuiControl, SettingsGUIA: Disable, BtnGammPlus
      GuiControl, SettingsGUIA: Disable, BtnGammMin
      GuiControl, SettingsGUIA: Disable, BtnSatPlus
      GuiControl, SettingsGUIA: Disable, BtnSatMin
      GuiControl, SettingsGUIA: Disable, sliderSatu
      GuiControl, SettingsGUIA: Disable, sliderBright
      GuiControl, SettingsGUIA: Disable, sliderContrst
   }

   If (imgFxMode=4)
      GuiControl, SettingsGUIA: Enable, bwDithering
   Else
      GuiControl, SettingsGUIA: Disable, bwDithering

   If (imgFxMode=2 || imgFxMode=3 || imgFxMode=4 || imgFxMode=9) && (o_bwDithering=0)
   {
      GuiControl, SettingsGUIA: Enable, zatAdjust
      GuiControl, SettingsGUIA: Enable, infoZatAdjust
      GuiControl, SettingsGUIA: Enable, hueAdjust
      GuiControl, SettingsGUIA: Enable, infohueAdjust
      GuiControl, SettingsGUIA: Enable, UIimgThreshold
      GuiControl, SettingsGUIA: Enable, infoThreshold
   } Else
   {
      GuiControl, SettingsGUIA: Disable, zatAdjust
      GuiControl, SettingsGUIA: Disable, infoZatAdjust
      GuiControl, SettingsGUIA: Disable, hueAdjust
      GuiControl, SettingsGUIA: Disable, infohueAdjust
      GuiControl, SettingsGUIA: Disable, UIimgThreshold
      GuiControl, SettingsGUIA: Disable, infoThreshold
   }

   If (imgFxMode=2 || imgFxMode=3)
   {
      GuiControl, SettingsGUIA: Enable, infoRGBchnls
      GuiControl, SettingsGUIA: Enable, chnRdecalage
      GuiControl, SettingsGUIA: Enable, chnGdecalage
      GuiControl, SettingsGUIA: Enable, chnBdecalage
   } Else
   {
      GuiControl, SettingsGUIA: Disable, infoRGBchnls
      GuiControl, SettingsGUIA: Disable, chnRdecalage
      GuiControl, SettingsGUIA: Disable, chnGdecalage
      GuiControl, SettingsGUIA: Disable, chnBdecalage
   }

   If (imgFxMode=3)
   {
      GuiControl, SettingsGUIA: Enable, autoAdjustMode
      GuiControl, SettingsGUIA: Enable, usrAdaptiveThreshold
      GuiControl, SettingsGUIA: Enable, doSatAdjusts
   } Else
   {
      GuiControl, SettingsGUIA: Disable, autoAdjustMode
      GuiControl, SettingsGUIA: Disable, usrAdaptiveThreshold
      GuiControl, SettingsGUIA: Disable, doSatAdjusts
   }
}

btnResetImageView() {
  ; GuiControlGet, realTimePreview
  ForceNoColorMatrix := 0
  GuiControl, SettingsGUIA: Choose, imgFxMode, 1
  GuiControl, SettingsGUIA: Choose, usrColorDepth, 1
  GuiControl, SettingsGUIA: Choose, usrAdaptiveThreshold, 5
  GuiControl, SettingsGUIA: Choose, chnRdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnGdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnBdecalage, 14
  GuiControl, SettingsGUIA: Choose, IMGresizingMode, 1
  GuiControl, SettingsGUIA:, bwDithering, 0
  ColorDepthDithering := usrColorDepth := IMGresizingMode := imgFxMode := satAdjust := lumosAdjust := lumosGrayAdjust := 1
  vpIMGrotation := zatAdjust := hueAdjust := chnRdecalage := chnGdecalage := chnBdecalage := GammosAdjust := GammosGrayAdjust := 0
  updatePanelColorsInfo()
  UIrealGammos := realGammos := usrAdaptiveThreshold := infoBright := infoSatu := 1
  bwDithering := infoContrst := sliderSatu := sliderBright := sliderContrst := 0
  FlipImgV := FlipImgH := usrTextureBGR := vpIMGrotation := UIimgThreshold := imgThreshold := 0

  GuiControl, SettingsGUIA:, infoBright, Brightness: 1.009
  GuiControl, SettingsGUIA:, infoContrst, Contrast: 0.000
  GuiControl, SettingsGUIA:, infoSatu, Saturation: 1.000
  GuiControl, SettingsGUIA:, infoThreshold, Threshold: 0.00
  GuiControl, SettingsGUIA:, infoRealGammos, Gamma: 1.00
  GuiControl, SettingsGUIA:, hueAdjust, 0
  GuiControl, SettingsGUIA:, zatAdjust, 0
  GuiControl, SettingsGUIA:, UIrealGammos, 100
  GuiControl, SettingsGUIA:, UIimgThreshold, 0
  GuiControl, SettingsGUIA:, sliderSatu, 0
  GuiControl, SettingsGUIA:, sliderBright, 0
  GuiControl, SettingsGUIA:, sliderContrst, 0
  GuiControl, SettingsGUIA:, vpIMGrotation, 0
  GuiControl, SettingsGUIA:, usrTextureBGR, 0
  GuiControl, SettingsGUIA:, RenderOpaqueIMG, 0
  GuiControl, SettingsGUIA:, FlipImgV, 0
  GuiControl, SettingsGUIA:, FlipImgH, 0
  GuiControl, SettingsGUIA:, ColorDepthDithering, 1
  defineColorDepth()
  writeMainSettings()
  dummyTimerDelayiedImageDisplay(50)
}

ColorPanelTriggerImageUpdate() {
   Critical, On

   GuiControlGet, imgFxMode
   GuiControlGet, usrAdaptiveThreshold
   GuiControlGet, doSatAdjusts
   GuiControlGet, autoAdjustMode
   GuiControlGet, showHistogram
   GuiControlGet, sliderBright
   GuiControlGet, sliderContrst
   GuiControlGet, sliderSatu
   GuiControlGet, bwDithering
   GuiControlGet, RenderOpaqueIMG
   GuiControlGet, FlipImgV
   GuiControlGet, FlipImgH
   GuiControlGet, CustomZoomCB
   GuiControlGet, IMGresizingMode
   GuiControlGet, chnRdecalage
   GuiControlGet, chnGdecalage
   GuiControlGet, chnBdecalage
   GuiControlGet, zatAdjust
   GuiControlGet, hueAdjust
   GuiControlGet, UIimgThreshold
   GuiControlGet, UIrealGammos
   GuiControlGet, userimgQuality
   GuiControlGet, vpIMGrotation
   GuiControlGet, UIdoubleZoom
   GuiControlGet, usrTextureBGR
   GuiControlGet, usrColorDepth
   GuiControlGet, ColorDepthDithering
   ; GuiControlGet, realTimePreview

   defineColorDepth()
   ForceNoColorMatrix := 0
   zoomLevel := (UIdoubleZoom=1) ? (2*CustomZoomCB)/100 + 2 : CustomZoomCB/100
   If (vpIMGrotation=1 || vpIMGrotation>358)
      vpIMGrotation := 0

   imgThreshold := Round(UIimgThreshold/100, 3)
   If (imgFxMode!=3 && imgFxMode!=1)
      realGammos := Round(UIrealGammos/100, 3)

   If (imgFxMode=2)
   {
      lumosAdjust := (sliderBright>0) ? 0.14*sliderBright + 1 : 0.01*Abs(sliderBright + 100)
      GammosAdjust := (sliderContrst>0) ? -0.14*sliderContrst : 0.01*Abs(sliderContrst)
      satAdjust := (sliderSatu>0) ? 0.02*sliderSatu + 1 : 0.01*Abs(sliderSatu + 100)
   } Else If (imgFxMode=4)
   {
      lumosGrayAdjust := (sliderBright>0) ? 0.14*sliderBright + 1 : 0.01*Abs(sliderBright + 100)
      GammosGrayAdjust := (sliderContrst>0) ? -0.14*sliderContrst : 0.01*Abs(sliderContrst)
   }

   If (imgFxMode=3)
   {
      imgPath := resultedFilesList[currentFileIndex]
      AdaptiveImgLight(gdiBitmap, imgPath, 1, 1)
      updatePanelColorSliderz()
   }

   If (imgFxMode!=4)
   {
      GuiControl, SettingsGUIA:, bwDithering, 0
      bwDithering := 0
   }
   If (prevvpIMGrotation!=vpIMGrotation)
   {
      mustReloadIMG := 1
      prevvpIMGrotation := vpIMGrotation
   }

   updatePanelColorsInfo()
   filterDelayiedImageDisplay()
   SetTimer, writeMainSettings, -150
}

converterPanelWindow() {
    Global btnFldr, IDbtnConvert
    filesElected := getSelectedFiles(0, 1)
    createSettingsGUI(15)
    btnWid := 110
    txtWid := 280
    editWid := 45
    If (PrefsLargeFonts=1)
    {
       editWid := editWid + 30
       btnWid := btnWid + 70
       txtWid := txtWid + 155
       Gui, Font, s%LargeUIfontValue%
    }

    initFIMGmodule()
    Gui, Add, Text, x15 y15 Section, Destination format:
    Gui, Add, DropDownList, x+10 w85 gTglDesiredSaveFormat AltSubmit Choose%userDesireWriteFMT% vuserDesireWriteFMT, .BMP|.GIF|.HDP|.J2C|.J2K|.JFIF|.JNG|.JP2|.JPG|.JXR|.PNG|.PPM|.TGA|.TIF|.WDP|.WEBP|.XPM
    Gui, Add, Checkbox, xs y+10 gTglKeepOriginals Checked%OnConvertKeepOriginals% vOnConvertKeepOriginals, &Keep original file[s]
    Gui, Add, Checkbox, xs y+10 gTglOverwriteFiles Checked%userOverwriteFiles% vuserOverwriteFiles, On file name collision, overwrite existing file in the destination
    Gui, Add, Checkbox, y+10 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file[s] in the following folder: 
    Gui, Add, Edit, xp+10 y+5 wp r1 +0x0800 -wrap vResizeDestFolder, % ResizeDestFolder
    Gui, Add, Button, x+5 hp w90 gBTNchangeResizeDestFolder vbtnFldr, C&hoose
    If (filesElected=1)
    {
       Gui, Font, Bold
       Gui, Add, Text, xs y+15 Section, Files selected to convert: %filesElected%.
       Gui, Font, Normal
    } 

    If !ResizeUseDestDir
    {
       GuiControl, Disable, btnFldr
       GuiControl, Disable, ResizeDestFolder
    }

    Gui, Add, Button, xs y+15 h30 w90 gBTNconvertNow Default vIDbtnConvert, &Convert
    Gui, Add, Button, x+5 hp wp gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Convert image(s) format: %appTitle%
}

TglKeepOriginals() {
  GuiControlGet, OnConvertKeepOriginals
  writeMainSettings()
}

TglOverwriteFiles() {
  GuiControlGet, userOverwriteFiles
  writeMainSettings()
}

TglDesiredSaveFormat() {
  GuiControlGet, userDesireWriteFMT
  writeMainSettings()
}

BTNconvertNow() {
   Static saveImgFormatsList := {1:"bmp", 2:"gif", 3:"hdp", 4:"j2c", 5:"j2k", 6:"jfif", 7:"jng", 8:"jp2", 9:"jpg", 10:"jxr", 11:"png", 12:"ppm", 13:"tga", 14:"tif", 15:"wdp", 16:"webp", 17:"xpm"}

   GuiControlGet, ResizeDestFolder
   GuiControlGet, OnConvertKeepOriginals
   GuiControlGet, userOverwriteFiles
   GuiControlGet, userDesireWriteFMT
   rDesireWriteFMT := saveImgFormatsList[userDesireWriteFMT]
   If (!RegExMatch(rDesireWriteFMT, "i)(bmp|png|tiff|tif|gif|jpg|jpeg)$") && wasInitFIMlib!=1)
   {
      SoundBeep, 300, 100
      triggerOwnDialogs()
      Msgbox, 48, %appTitle%, ERROR: The "%rDesireWriteFMT%" format is currently unsupported. The FreeImage library failed to properly initialize.
      Return
   }

   If (ResizeUseDestDir=1)
      prevFileSavePath := ResizeDestFolder

   writeMainSettings()
   filesElected := getSelectedFiles()
   If (filesElected>1)
      batchConvert2jpeg()
   Else 
      convert2format()
}

ResizeImagePanelWindow() {
    Global userEditWidth, userEditHeight, ResultEditWidth, ResultEditHeight, btnFldr

    ToolTip, Please wait...
    filesElected := getSelectedFiles(0, 1)
    multipleFilesMode := (filesElected>1) ? 1 : ""
    If (!multipleFilesMode && !PanelsCheckFileExists())
    {
       ToolTip
       Return
    }

    createSettingsGUI(4)
    btnWid := 110
    txtWid := 265
    editWid := 45
    If (PrefsLargeFonts=1)
    {
       editWid := editWid + 30
       btnWid := btnWid + 70
       txtWid := txtWid + 170
       Gui, Font, s%LargeUIfontValue%
    }

    img2resizePath := resultedFilesList[currentFileIndex]
    If (multipleFilesMode!=1)
    {
       zPlitPath(img2resizePath, 0, fileNamu, folderu)
       r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
       FileGetSize, fileSizu, % img2resizePath, K
       If !r1
       {
          showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
          SoundBeep, 300, 50
          img2resizePath := ""
          CloseWindow()
          Return
       }
    } Else
    {
       oImgW := ResolutionWidth
       oImgH := ResolutionHeight
    }

    initFIMGmodule()
    If (activateImgSelection!=1)
       ResizeWithCrop := 0

    If (multipleFilesMode=1)
    {
       Gui, Add, Text, x15 y15 Section, Resize image to (W x H)
    } Else
    {
       Gui, Add, Text, x15 y15 Section, Original image dimensions:
       Gui, Add, Text, xs+15 y+5, %oImgW% x %oImgH% pixels. %fileSizu% kilobytes.
       Gui, Add, Text, xs y+10, Resize image to (W x H)
    }

    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 limit9 -multi number -wantCtrlA -wantReturn -wantTab -wrap gEditResizeWidth vuserEditWidth, % (ResizeInPercentage=1) ? 100 : oImgW
    Gui, Add, Edit, x+5 w%editWid% r1 limit9 -multi number -wantCtrlA -wantReturn -wantTab -wrap gEditResizeHeight vuserEditHeight, % (ResizeInPercentage=1) ? 100 : oImgH
    Gui, Add, Checkbox, x+5 wp+30 hp +0x1000 gTglRszInPercentage Checked%ResizeInPercentage% vResizeInPercentage, in `% perc.
    If (multipleFilesMode!=1)
       Gui, Add, Text, xs y+15, Result (W x H) in pixels
    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 Disabled -wrap vResultEditWidth, % (multipleFilesMode=1) ? "--" : oImgW
    Gui, Add, Edit, x+5 w%editWid% r1 Disabled -wrap vResultEditHeight, % (multipleFilesMode=1) ? "--" : oImgH
    thisRotation := (vpIMGrotation=0) ? ResizeRotationUser : vpIMGrotation
    otherRotation := (vpIMGrotation=thisRotation) ? ResizeRotationUser : vpIMGrotation
    Gui, Add, ComboBox, x+5 wp+30 gTglRszRotation vResizeRotationUser, Rotate: 0°|45°|90°|135°|180°|225°|270°|315°|%thisRotation%°||%otherRotation%°
    Gui, Add, Checkbox, xs y+10 hp +0x1000 gTglRszKeepAratio Checked%ResizeKeepAratio% vResizeKeepAratio, Keep aspect ratio
    Gui, Add, Checkbox, x+5 hp +0x1000 gTglRszQualityHigh Checked%ResizeQualityHigh% vResizeQualityHigh, High quality resampling
    Gui, Add, Checkbox, xs y+10 gTglRszCropping Checked%ResizeWithCrop% vResizeWithCrop, Crop image(s) to the viewport selection
    Gui, Add, Checkbox, xp+10 y+10 gTglRszCropping Checked%ResizeCropAfterRotation% vResizeCropAfterRotation, Perform image crop after image rotation (as in the viewport)
    Gui, Add, Checkbox, xs y+10 gTglRszApplyEffects Checked%ResizeApplyEffects% vResizeApplyEffects, Apply color adjustments and image mirroring`nactivated in the main window
    Gui, Add, Checkbox, y+10 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file(s) in the following folder
    Gui, Add, Edit, xp+15 y+5 wp r1 +0x0800 -wrap vResizeDestFolder, % ResizeDestFolder
    Gui, Add, Button, x+5 hp w90 gBTNchangeResizeDestFolder vbtnFldr, C&hoose
    If (activateImgSelection!=1)
    {
       GuiControl, Disable, ResizeWithCrop
       GuiControl, Disable, ResizeCropAfterRotation
    }

    If !ResizeUseDestDir
    {
       GuiControl, Disable, btnFldr
       GuiControl, Disable, ResizeDestFolder
    }

    If (multipleFilesMode=1)
    {
       Gui, Font, Bold
       Gui, Add, Text, xs y+15, %filesElected% files are selected for processing.
       Gui, Font, Normal
       Gui, Add, DropDownList, xs y+10 w%txtWid% gTglRszUnsprtFrmt AltSubmit Choose%userUnsprtWriteFMT% vuserUnsprtWriteFMT, Skip files in unsupported write formats|Try to preserve file formats, convert unsupported to...|Convert all the files to...
       Gui, Add, DropDownList, xs y+5 w85 AltSubmit Choose%userDesireWriteFMT% vuserDesireWriteFMT, .BMP|.GIF|.HDP|.J2C|.J2K|.JFIF|.JNG|.JP2|.JPG|.JXR|.PNG|.PPM|.TGA|.TIF|.WDP|.WEBP|.XPM
       Gui, Add, Button, x+5 hp w85 gResizePanelHelpBoxInfo, Help
       Gui, Add, Button, xs+0 y+25 h30 w%btnWid% Default gBTNsaveResizedIMG, &Process images
       Gui, Add, Button, x+5 hp w%btnWid% gSimpleResizeRotatePanel, &Simple mode
       If (userUnsprtWriteFMT=1)
          GuiControl, SettingsGUIA: Disable, userDesireWriteFMT
    } Else
    {
       Gui, Add, Button, xs+0 y+20 h30 w%btnWid% gCopy2ClipResizedIMG, &Copy to clipboard
       Gui, Add, Button, x+5 hp wp Default gBTNsaveResizedIMG, &Save image as...
       Gui, Add, Button, xs y+5 hp w%btnWid% gSimpleResizeRotatePanel, &Simple mode
       Gui, Add, Button, x+5 hp w85 gResizePanelHelpBoxInfo, Help
    }
    ToolTip
    Gui, Add, Button, x+5 hp w85 gCloseWindow, C&ancel
    Gui, SettingsGUIA: Show, AutoSize, Resize/crop image(s): %appTitle%
}

BTNchangeResizeDestFolder() {
    triggerOwnDialogs()
    pattern := "All files (*.*;)"
    startPath := ResizeDestFolder
    FileSelectFile, SelectImg, S2, %startPath%\this.folder, Add new folder(s) to the list, %pattern%
    If (!SelectImg || ErrorLevel)
    {
       WinActivate, ahk_id %hSetWinGui%
       Return
    }

   Loop, Parse, SelectImg, `n
   {
       If (A_Index=1)
          SelectedDir := Trim(A_LoopField)
       Else If (A_Index>2)
          Break
   }

   zPlitPath(SelectedDir, 0, OutFileName, OutDir)
   If OutDir
   {
      GuiControl, , ResizeDestFolder, % OutDir
      ResizeDestFolder := OutDir
      writeMainSettings()
   }
}

batchIMGresizer(desiredW, desiredH, isPercntg) {

   cleanResizeRotationUserVar()
   If (!desiredH || !desiredW
   || desiredW<1 || desiredH<1)
   {
      showTOOLtip("Incorrect values given...")
      SoundBeep , 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }

   If (desiredW<5 || desiredH<5) && (isPercntg!=1)
   {
      showTOOLtip("Incorrect values given...")
      SoundBeep , 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }

   overwriteWarning := (ResizeUseDestDir!=1) ? "`n`nWARNING: All the original files will be overwritten." : ""
   filesElected := getSelectedFiles()
   If (filesElected>1)
   {
      triggerOwnDialogs()
      MsgBox, 52, %appTitle%, Are you sure you want to process multiple images in one go? There are %filesElected% selected files for this operation.%overwriteWarning%
      IfMsgBox, Yes
        good2go := 1

      If (good2go!=1)
         Return
   } Else Return

   CloseWindow()
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   thisImgQuality := (ResizeQualityHigh=1) ? 7 : 5
   If (ResizeKeepAratio=1 && isPercntg=1)
      desiredW := desiredH

   showTOOLtip("Processing " filesElected " images, please wait...")
   prevMSGdisplay := A_TickCount
   countTFilez := countFilez := 0
   Loop, % filesElected 
   {
      thisFileIndex := getSelectedFiles(A_Index)
      imgPath := resultedFilesList[thisFileIndex]
      imgPath := StrReplace(imgPath, "||")
      If (!FileExist(imgPath) || !imgPath)
      || (!RegExMatch(imgPath, saveTypesRegEX) && userUnsprtWriteFMT=1)
         Continue

      countTFilez++
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Processing " countTFilez "/" filesElected " images, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }

      oBitmap := LoadBitmapFromFileu(imgPath)
      If !oBitmap
      {
         someErrors := "`nErrors occured during file operations..."
         Continue
      }

      Gdip_GetImageDimensions(oBitmap, imgW, imgH)
      If (ResizeRotationUser>0 && ResizeWithCrop=1 && activateImgSelection=1 && ResizeCropAfterRotation=1)
         Gdip_GetRotatedDimensions(imgW, imgH, ResizeRotationUser, imgW, imgH)

      If (relativeImgSelCoords=1 && activateImgSelection=1 && ResizeWithCrop=1)
         calcRelativeSelCoords(oBitmap, imgW, imgH)

      If (isPercntg=1)
      {
         newW := Round((imgW/100)*desiredW)
         newH := Round((imgH/100)*desiredH)
         If (newW<10 && newH<10)
            Continue
      } Else If (ResizeKeepAratio=1)
      {
         calcIMGdimensions(imgW, imgH, desiredW, desiredH, newW, newH)
         If (newW<10 && newH<10)
            Continue
      } Else
      {
         newW := desiredW
         newH := desiredH
      }

      If (ResizeUseDestDir=1)
      {
         zPlitPath(imgPath, 0, OutFileName, OutDir)
         destImgPath := ResizeDestFolder "\" OutFileName
         If FileExist(destImgPath)
         {
            MD5name := generateThumbName(imgPath, 1)
            destImgPath := ResizeDestFolder "\" MD5name "-" OutFileName
         }
      } Else destImgPath := imgPath

      r := coreResizeIMG(imgPath, newW, newH, destImgPath, 0, 0, ResizeRotationUser, oBitmap, imgW, imgH, 1)
      If !r
         countFilez++
      Else
         someErrors := "`nErrors occured during file operations..."
   }
   If (activateImgSelection=1 || editingSelectionNow=1) && (relativeImgSelCoords=1)
      calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

   CurrentSLD := backCurrentSLD
   thumbSelFileList := ""
   prevStartIndex := -1
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. "  countFilez " out of " filesElected " selected files were processed until now..." someErrors)
      SoundBeep, 300, 100
   } Else
   {
      showTOOLtip("Finished processing "  countFilez " out of " filesElected " selected files" someErrors)
      SoundBeep, 900, 100
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

BTNsaveResizedIMG() {
    Static saveImgFormatsList := {1:"bmp", 2:"gif", 3:"hdp", 4:"j2c", 5:"j2k", 6:"jfif", 7:"jng", 8:"jp2", 9:"jpg", 10:"jxr", 11:"png", 12:"ppm", 13:"tga", 14:"tif", 15:"wdp", 16:"webp", 17:"xpm"}
    GuiControlGet, ResultEditWidth
    GuiControlGet, ResultEditHeight
    GuiControlGet, userEditWidth
    GuiControlGet, userEditHeight
    GuiControlGet, ResultEditHeight
    GuiControlGet, ResizeQualityHigh
    GuiControlGet, ResizeApplyEffects
    GuiControlGet, ResizeInPercentage
    GuiControlGet, ResizeRotationUser
    GuiControlGet, ResizeWithCrop
    GuiControlGet, ResizeCropAfterRotation
    GuiControlGet, ResizeUseDestDir
    GuiControlGet, ResizeDestFolder

    cleanResizeRotationUserVar()
    filesElected := getSelectedFiles()
    If (filesElected>1)
    {
       GuiControlGet, userDesireWriteFMT
       GuiControlGet, userUnsprtWriteFMT
       rDesireWriteFMT := saveImgFormatsList[userDesireWriteFMT]
       If (!RegExMatch(rDesireWriteFMT, "i)(bmp|png|tiff|tif|gif|jpg|jpeg)$") && wasInitFIMlib!=1)
       {
          SoundBeep, 300, 100
          triggerOwnDialogs()
          Msgbox, 48, %appTitle%, ERROR: The "%rDesireWriteFMT%" format is currently unsupported. The FreeImage library failed to properly initialize.
          Return
       }

       If (ResizeUseDestDir=1)
       {
          prevFileSavePath := ResizeDestFolder
          writeMainSettings()
       }

       batchIMGresizer(userEditWidth, userEditHeight, ResizeInPercentage)
       Return
    }

   If (!ResultEditHeight || !ResultEditWidth
   || ResultEditWidth<5 || ResultEditHeight<5)
   {
      showTOOLtip("Incorrect values given...")
      SoundBeep, 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }

   zPlitPath(img2resizePath, 0, OutFileName, OutDir)
   startPath := (ResizeUseDestDir=1) ? ResizeDestFolder "\" OutFileName : img2resizePath

   triggerOwnDialogs()
   FileSelectFile, file2save, S18, % startPath, Save processed image as..., Images (%dialogSaveFptrn%)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      zPlitPath(img2resizePath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
      zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, nExt)
      If !nExt
         file2save .= "." oExt

      If !RegExMatch(file2save, saveTypesRegEX)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: Please use a supported file format extension: %saveTypesFriendly%.
         Return
      }

      zPlitPath(file2save, 0, OutFileName, OutDir)
      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: This format is currently unsupported. The FreeImage library failed to properly initialize.`n`n%OutFileName%
         Return
      }

      r := coreResizeIMG(img2resizePath, ResultEditWidth, ResultEditHeight, file2save, 0, 0, ResizeRotationUser)
      If r
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: Unable to save file. Error code: %r%.`n`n%OutFileName%
         Return
      }

      If (ResizeUseDestDir=1)
         prevFileSavePath := ResizeDestFolder

      writeMainSettings()
      SoundBeep, 900, 100
      showTOOLtip("Processed image saved...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

Copy2ClipResizedIMG() {
   GuiControlGet, ResultEditWidth
   GuiControlGet, ResultEditHeight
   GuiControlGet, ResizeQualityHigh
   GuiControlGet, ResizeApplyEffects
   GuiControlGet, ResizeRotationUser
   GuiControlGet, ResizeWithCrop
   GuiControlGet, ResizeCropAfterRotation
   cleanResizeRotationUserVar()

   If (!ResultEditHeight || !ResultEditWidth
   || ResultEditWidth<5 || ResultEditHeight<5)
   {
      SoundBeep, 300, 900
      Return
   }

   r := coreResizeIMG(img2resizePath, ResultEditWidth, ResultEditHeight, "--", 0, 1, ResizeRotationUser)
   If !r
   {
      showTOOLtip("Resized image copied to clipboard")
      SoundBeep, 900, 100
   } Else 
   {
      triggerOwnDialogs()
      Msgbox, 48, %appTitle%, ERROR: Unable to copy resized image to clipboard... Error code: %r%.
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

EditResizeWidth() {
   GuiControlGet, userEditWidth
   GuiControlGet, userEditHeight
   GuiControlGet, ResizeKeepAratio
   GuiControlGet, ResizeInPercentage
   
   If (A_TickCount - lastEditRHChange < 200)
      Return

   filesElected := getSelectedFiles()
   If (filesElected>1 && ResizeKeepAratio=1 && ResizeInPercentage=1)
   {
      Global lastEditRWChange := A_TickCount
      GuiControl, SettingsGUIA:, userEditHeight, % Round(userEditWidth)
      Return
   }

   If (filesElected>1)
      Return

   If (userEditWidth<1 || !userEditWidth)
      userEditWidth := 1

   r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
   Global lastEditRWChange := A_TickCount
   Sleep, 5
   If (ResizeKeepAratio=1)
   {
      thisWidth := (ResizeInPercentage=1) ? (oImgW/100)*userEditWidth : userEditWidth
      calcIMGdimensions(oImgW, oImgH, thisWidth, 90000*oImgH, newW, newH)
      GuiControl, SettingsGUIA:, ResultEditWidth, % Round(newW)
      GuiControl, SettingsGUIA:, ResultEditHeight, % Round(newH)
      newValue := (ResizeInPercentage=1) ? Round((newH/oimgH)*100) : newH
      GuiControl, SettingsGUIA:, userEditHeight, % Round(newValue)
   } Else
   {
      thisHeight := (ResizeInPercentage=1) ? (oImgH/100)*userEditHeight : userEditHeight
      thisWidth := (ResizeInPercentage=1) ? (oImgW/100)*userEditWidth : userEditWidth
      GuiControl, SettingsGUIA:, ResultEditWidth, % Round(thisWidth)
      GuiControl, SettingsGUIA:, ResultEditHeight, % Round(thisHeight)
   }
}

EditResizeHeight() {
   GuiControlGet, userEditWidth
   GuiControlGet, userEditHeight
   GuiControlGet, ResizeKeepAratio
   GuiControlGet, ResizeInPercentage
   
   If (A_TickCount - lastEditRWChange < 200)
      Return

   filesElected := getSelectedFiles()
   If (filesElected>1 && ResizeKeepAratio=1 && ResizeInPercentage=1)
   {
      Global lastEditRHChange := A_TickCount
      GuiControl, SettingsGUIA:, userEditWidth, % Round(userEditHeight)
      Return
   }

   If (filesElected>1)
      Return

   If (userEditHeight<1 || !userEditHeight)
      userEditHeight := 1

   r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
   Global lastEditRHChange := A_TickCount
   Sleep, 5
   If (ResizeKeepAratio=1)
   {
      thisHeight := (ResizeInPercentage=1) ? (oImgH/100)*userEditHeight : userEditHeight
      calcIMGdimensions(oImgW, oImgH, 90000*oImgW, thisHeight, newW, newH)
      GuiControl, SettingsGUIA:, ResultEditWidth, % Round(newW)
      GuiControl, SettingsGUIA:, ResultEditHeight, % Round(newH)
      newValue := (ResizeInPercentage=1) ? Round((newW/oimgW)*100) : newW
      GuiControl, SettingsGUIA:, userEditWidth, % Round(newValue)
   } Else
   {
      thisHeight := (ResizeInPercentage=1) ? (oImgH/100)*userEditHeight : userEditHeight
      thisWidth := (ResizeInPercentage=1) ? (oImgW/100)*userEditWidth : userEditWidth
      GuiControl, SettingsGUIA:, ResultEditWidth, % Round(thisWidth)
      GuiControl, SettingsGUIA:, ResultEditHeight, % Round(thisHeight)
   }
}

TglRszInPercentage() {
   GuiControlGet, ResizeInPercentage
   filesElected := getSelectedFiles()
   If (filesElected>1)
   {
      oImgW := ResolutionWidth
      oImgH := ResolutionHeight
   } Else r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)

   GuiControl, SettingsGUIA:, userEditWidth, % (ResizeInPercentage=1) ? 100 : oImgW
   GuiControl, SettingsGUIA:, userEditHeight, % (ResizeInPercentage=1) ? 100 : oImgH
   If (filesElected<2)
   {
      GuiControl, SettingsGUIA:, ResultEditWidth, % oImgW
      GuiControl, SettingsGUIA:, ResultEditHeight, % oImgH
   }
   writeMainSettings()
}

TglRszKeepAratio() {
   GuiControlGet, userEditWidth
   GuiControlGet, ResizeKeepAratio
   If (!markedSelectFile || ResizeKeepAratio=1 && ResizeInPercentage=1)
      GuiControl, SettingsGUIA:, userEditWidth, % userEditWidth
   writeMainSettings()
}

TglRszUnsprtFrmt() {
   GuiControlGet, userUnsprtWriteFMT
   GuiControlGet, userDesireWriteFMT
   If (userUnsprtWriteFMT>1)
      GuiControl, SettingsGUIA: Enable, userDesireWriteFMT
   Else
      GuiControl, SettingsGUIA: Disable, userDesireWriteFMT
   writeMainSettings()
}

cleanResizeRotationUserVar() {
   ResizeRotationUser := StrReplace(ResizeRotationUser, ":")
   ResizeRotationUser := StrReplace(ResizeRotationUser, "°")
   ResizeRotationUser := StrReplace(ResizeRotationUser, "rotate")
   ResizeRotationUser := Trim(ResizeRotationUser)
}

TglRszRotation() {
   GuiControlGet, ResizeRotationUser
   GuiControlGet, ResizeWithCrop
   cleanResizeRotationUserVar()
   If (ResizeRotationUser>0 && ResizeWithCrop=1 &&  activateImgSelection=1)
      GuiControl, SettingsGUIA: Enable, ResizeCropAfterRotation
   Else If (activateImgSelection=1)
      GuiControl, SettingsGUIA: Disable, ResizeCropAfterRotation

   writeMainSettings()
}

TglRszCropping() {
   GuiControlGet, ResizeWithCrop
   GuiControlGet, ResizeCropAfterRotation
   If (ResizeRotationUser>0 && ResizeWithCrop=1 && activateImgSelection=1)
      GuiControl, SettingsGUIA: Enable, ResizeCropAfterRotation
   Else If (activateImgSelection=1)
      GuiControl, SettingsGUIA: Disable, ResizeCropAfterRotation
   writeMainSettings()
}

TglRszDestFoldr() {
   GuiControlGet, ResizeUseDestDir
   If !ResizeUseDestDir
   {
      GuiControl, SettingsGUIA: Disable, btnFldr
      GuiControl, SettingsGUIA: Disable, ResizeDestFolder
   } Else
   {
      GuiControl, SettingsGUIA: Enable, btnFldr
      GuiControl, SettingsGUIA: Enable, ResizeDestFolder
   }
   writeMainSettings()
}

TglRszQualityHigh() {
   GuiControlGet, ResizeQualityHigh
   writeMainSettings()
}

TglRszApplyEffects() {
   GuiControlGet, ResizeApplyEffects
   writeMainSettings()
   If (ResizeApplyEffects=1)
   {
      infoMirroring := defineIMGmirroring()
      If (usrColorDepth>1)
         infoColorDepth := "`nImage color depth: ALTERED [ " defineColorDepth() " ]"
      If (imgFxMode>1)
         infoColors := "`nColors display mode: " DefineFXmodes() " [" currentPixFmt "]"
      If (RenderOpaqueIMG=1)
         infoRenderOpaque .= "`nAlpha channel: REMOVED"
 
      entireString := infoMirroring infoColors infoColorDepth infoRenderOpaque
      entireString := (entireString) ?  "Effects currently activated: " entireString : "No effects currently activated."
      triggerOwnDialogs()
      MsgBox,, %appTitle%, % entireString
   }
}

FolderzPanelWindow() {
    Static LViewOthers

    createSettingsGUI(2)
    btnWid := 115
    txtWid := 360
    lstWid := 545
    If (PrefsLargeFonts=1)
    {
       lstWid := lstWid + 230
       btnWid := btnWid + 75
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }
    Gui, Add, Text, x15 y15, Please select the folder you want updated.`nFolders marked with (*) are changed since the last scan.`nThis folders list was generated based on the indexed files.
    Gui, Add, ListView, y+10 w%lstWid% gFolderzFilterListBTN r12 Grid vLViewOthers, #|Date|(?)|Folder path|Files

    Gui, Add, Checkbox, xs+0 y+10 gToggleCountFilesFoldersList Checked%CountFilesFolderzList% vCountFilesFolderzList, &Count files in folders list (recursively)
    Gui, Add, Checkbox, x+10 gToggleForceRegenStaticFs Checked%ForceRegenStaticFolders% vForceRegenStaticFolders, &Force this list to be refreshed on .SLD save
    Gui, Add, Checkbox, xs+0 y+10 gToggleRecursiveStaticRescan vRecursiveStaticRescan Checked%RecursiveStaticRescan%, &Perform recursive (in sub-folders) folder scan
    Gui, Add, Button, xs+0 y+10 h30 w130 gUpdateSelFolder, &Rescan folder
    Gui, Add, Button, x+5 hp w%btnWid% gIgnoreSelFolder, &Ignore changes
    Gui, Add, Button, x+5 hp w%btnWid% gRemFilesStaticFolder, Re&move files from list
    Gui, Add, Button, x+5 hp w%btnWid% gOpenDynaFolderBTN, &Open folder
    Gui, SettingsGUIA: Show, AutoSize, Folders updater: %appTitle%
    Sleep, 25
    PopulateStaticFolderzList()
}

DynamicFolderzPanelWindow() {
    Static LViewDynas

    createSettingsGUI(3)
    btnWid := 120
    txtWid := 360
    lstWid := 535
    If (PrefsLargeFonts=1)
    {
       lstWid := lstWid + 175
       btnWid := btnWid + 65
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }
    Gui, Add, Text, x15 y15,This folders list is used to generate the files list index.
    Gui, Add, ListView, y+10 w%lstWid% gFolderzFilterListBTN r12 Grid vLViewDynas, #|(?)|Folder path

    btnWid2 := (PrefsLargeFonts=1) ? 85 : 45
    Gui, Add, Button, xs+0 y+5  h30 w70 gBTNaddNewFolder2list, &Add
    Gui, Add, Button, x+5 hp w%btnWid2% gRemDynaSelFolder, &Remove
    Gui, Add, Button, x+5 hp wp gRescanDynaFolder, Re&scan
    Gui, Add, Button, x+5 hp wp+30 gRegenerateEntireList, R&escan all
    Gui, Add, Button, x+5 hp w%btnWid% gInvertRecurseDynaFolder, &Invert recursive state
    Gui, Add, Button, x+5 hp w115 gOpenDynaFolderBTN, &Open folder
    Gui, SettingsGUIA: Show, AutoSize, Dynamic folders list: %appTitle%
    Sleep, 25
    LV_ModifyCol(1, "Integer")
    LV_ModifyCol(0, "Integer")
    PopulateDynamicFolderzList()
}

ToggleCountFilesFoldersList() {
  GuiControlGet, CountFilesFolderzList
  If (AnyWindowOpen=3)
     DynamicFolderzPanelWindow()
  Else If (AnyWindowOpen=2)
     FolderzPanelWindow()
}

ToggleForceRegenStaticFs() {
  GuiControlGet, ForceRegenStaticFolders
}

ToggleRecursiveStaticRescan() {
  GuiControlGet, RecursiveStaticRescan
}

BTNaddNewFolder2list() {
    r := addNewFolder2list()
    Sleep, 25
    If (r="cancel")
       WinActivate, ahk_id %hSetWinGui%
}

IgnoreSelFolder() {
    Gui, SettingsGUIA: ListView, LViewOthers
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 4)
    LV_GetText(indexSelected, RowNumber, 1)
    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    FileReadLine, firstLine, % CurrentSLD, 1
    IniRead, tstSLDcacheFilesList, % CurrentSLD, General, SLDcacheFilesList, @
    If (!InStr(firstLine, "[General]") || tstSLDcacheFilesList!=1)
    {
       triggerOwnDialogs()
       Msgbox, 48, %appTitle%, ERROR: The loaded .SLD file does not seem to be in the correct format. Operation aborted.
       Return
    }
    Sleep, 25
    CloseWindow()
    Sleep, 50
    updateCachedStaticFolders(folderu, 1)
    showTOOLtip("Folders list information updated")
    SetTimer, RemoveTooltip, % -msgDisplayTime
    Sleep, 50
    FolderzPanelWindow()
}

RemFilesStaticFolder() {
    Gui, SettingsGUIA: ListView, LViewOthers
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 4)
    LV_GetText(indexSelected, RowNumber, 1)
    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    Sleep, 25
    CloseWindow()
    Sleep, 50
    triggerOwnDialogs()
    MsgBox, 52, %appTitle%, Would you like to remove the files from the index/list pertaining to the static folder selected?`n`n%folderu%
    IfMsgBox, Yes
    {
      remFilesFromList("|" folderu)
      GenerateRandyList()
      SoundBeep, 950, 100
      RandomPicture()
    }
    Sleep, 550
    FolderzPanelWindow()
}

RemDynaSelFolder() {
    Gui, SettingsGUIA: ListView, LViewDynas
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 3)
    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    CloseWindow()
    Sleep, 50
    foldersListu := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
    Loop, Parse, foldersListu, `n
    {
        line := Trim(A_LoopField)
        fileTest := StrReplace(line, "|")
        If (StrLen(line)<2 || !FileExist(fileTest) || line="|hexists|" || folderu=line)
           Continue
        newFoldersList .= line "`n"
    }

    DynamicFoldersList := newFoldersList
    triggerOwnDialogs()
    MsgBox, 52, %appTitle%, Would you like to remove the files from the index/list pertaining to the removed folder as well ?`n`n%folderu%
    IfMsgBox, Yes
    {
      remFilesFromList(folderu)
      GenerateRandyList()
      SoundBeep, 950, 100
      RandomPicture()
    }
    Sleep, 500
    DynamicFolderzPanelWindow()
}

OpenDynaFolderBTN() {
    whichLV := (AnyWindowOpen=3) ? "LViewDynas" : "LViewOthers"
    Gui, SettingsGUIA: ListView, % whichLV
    RowNumber := LV_GetNext(0, "F")
    colNum := (AnyWindowOpen=3) ? 3 : 4
    LV_GetText(folderu, RowNumber, colNum)
    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    folderu := StrReplace(folderu, "|")
    Try Run, % folderu
}

FolderzFilterListBTN() {
    whichLV := (AnyWindowOpen=3) ? "LViewDynas" : "LViewOthers"
    Gui, SettingsGUIA: ListView, % whichLV
    RowNumber := LV_GetNext(0, "F")
    colNum := (AnyWindowOpen=3) ? 3 : 4
    LV_GetText(folderu, RowNumber, colNum)
    If (StrLen(folderu)<3 || folderu="folder path") || (A_GuiEvent!="DoubleClick")
       Return

    CloseWindow()
    folderu := StrReplace(folderu, "|")
    coreEnableFiltru(folderu)
}

InvertRecurseDynaFolder() {
    Gui, SettingsGUIA: ListView, LViewDynas
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 3)

    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    CloseWindow()
    Sleep, 25
    foldersListu := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
    Loop, Parse, foldersListu, `n
    {
        line := Trim(A_LoopField)
        fileTest := StrReplace(line, "|")
        If (StrLen(line)<2 || !FileExist(fileTest) || line="|hexists|" || line=folderu)
           Continue
        newFoldersList .= line "`n"
    }
    isPipe := InStr(folderu, "|") ? 1 : 0
    folderu := StrReplace(folderu, "|")
    If (isPipe!=1)
       folderu := "|" folderu
    newFoldersList .= folderu "`n"

    Sort, newFoldersList, UD`n
    DynamicFoldersList := newFoldersList
    Sleep, 25
    DynamicFolderzPanelWindow()
}

rescanDynaFolder() {
    Gui, SettingsGUIA: ListView, LViewDynas
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 3)

    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    CloseWindow()
    Sleep, 25
    ; msgbox, % folderu

    coreAddNewFolder(folderu, 1)
    If RegExMatch(CurrentSLD, "i)(.\.sld)$")
    {
       FileReadLine, firstLine, % CurrentSLD, 1
       IniRead, tstSLDcacheFilesList, % CurrentSLD, General, SLDcacheFilesList, @
       If (!InStr(firstLine, "[General]") || tstSLDcacheFilesList!=1 || InStr(folderu, "|"))
          good2go := "null"
    } Else good2go := "null"

    If (mustGenerateStaticFolders=0 && good2go!="null" && RegExMatch(CurrentSLD, "i)(.\.sld)$"))
       updateCachedStaticFolders(folderu, 0)

    Sleep, 550
    DynamicFolderzPanelWindow()
}

updateCachedStaticFolders(mainFolderu, onlyMainFolder) {
   thisIndex := 0
   foldersListu := LoadStaticFoldersCached(CurrentSLD, countStaticFolders) "`n"

   FileGetTime, dirDate, % mainFolderu, M
   newEntry := dirDate "*&*" mainFolderu "`n"

   showTOOLtip("Updating static folders list...")
   If (onlyMainFolder!=1)
   {
      Loop, Files, %mainFolderu%\*, RD
      {
          FileGetTime, dirDate, %A_LoopFileFullPath%, M
          MoreNewFileFolders .= dirDate "*&*" A_LoopFileFullPath "`n"
   ;       Tooltip, % MoreNewFileFolders
      }
   }

   Loop, Parse, foldersListu, `n
   {
       lineArru := StrSplit(A_LoopField, "*&*")
       folderu := lineArru[2], oldDateu := lineArru[1]
       If !FileExist(folderu) || (folderu=mainFolderu) || InStr(MoreNewFileFolders, "*&*" folderu "`n")
          Continue
       oldDateu := SubStr(oldDateu, InStr(oldDateu, "=")+1)
       newFoldersList .= oldDateu "*&*" folderu "`n"
   }

   FinalStaticFoldersList := newFoldersList "`n" MoreNewFileFolders "`n" newEntry
   Sort, FinalStaticFoldersList, U D`n
   thisIndex := 0
   newStaticFoldersListCache := ""
   Loop, Parse, FinalStaticFoldersList, `n
   {
        If StrLen(A_LoopField)<5
           Continue
        thisIndex++
        newStaticFoldersListCache .= "Fi" thisIndex "=" A_LoopField "`n"
   }
}

remFilesFromList(SelectedDir, silentus:=0) {
    If (silentus=0)
       showTOOLtip("Removing files from the list pertaining to...`n" SelectedDir "\`n")
    backCurrentSLD := CurrentSLD
    markedSelectFile := CurrentSLD := ""
    If StrLen(filesFilter)>1
    {
       usrFilesFilteru := filesFilter := ""
       FilterFilesIndex()
    }

    oldMaxy := maxFilesIndex
    isPipe := InStr(SelectedDir, "|") ? 1 : 0
    SelectedDir := StrReplace(SelectedDir, "|")
    newArrayu := []
    Loop, % maxFilesIndex + 1
    {
        r := resultedFilesList[A_Index]
        If (InStr(r, "||") || !r)
           Continue
        If !isPipe
        {
           If InStr(r, SelectedDir "\")
              Continue
        } Else If (isPipe=1)
        {
           rT := StrReplace(r, SelectedDir "\")
           If !InStr(rT, "\")
              Continue
        }
        countFiles++
        newArrayu[countFiles] := r
    }

    renewCurrentFilesList()
    maxFilesIndex := countFiles
    resultedFilesList := newArrayu.Clone()
    prevStartIndex := -1
    filesRemoved := oldMaxy - maxFilesIndex
    If (filesRemoved<1)
       filesRemoved := 0
    If (silentus=0)
       showTOOLtip("Finished removing " filesRemoved " files from the list...")
    CurrentSLD := backCurrentSLD
    Sleep, 25
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

UpdateSelFolder() {
    Gui, SettingsGUIA: ListView, LViewOthers
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 4)
    LV_GetText(indexSelected, RowNumber, 1)
    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    FileReadLine, firstLine, % CurrentSLD, 1
    IniRead, tstSLDcacheFilesList, % CurrentSLD, General, SLDcacheFilesList, @
    If (!InStr(firstLine, "[General]") || tstSLDcacheFilesList!=1)
    {
       triggerOwnDialogs()
       Msgbox, 48, %appTitle%, ERROR: The loaded .SLD file does not seem to be in the correct format. Operation aborted.
       Return
    }

    If (RecursiveStaticRescan!=1)
       isRecursive := "|"

    CloseWindow()
    Sleep, 25
    coreAddNewFolder(isRecursive folderu, 0)
    modus := isRecursive ? 1 : 0
    updateCachedStaticFolders(folderu, modus)
    Sleep, 25
    SetTimer, RemoveTooltip, % -msgDisplayTime
    FolderzPanelWindow()
}

PopulateStaticFolderzList() {
    If (mustGenerateStaticFolders=1 || SLDcacheFilesList!=1)
       Return

    startOperation := A_TickCount
    foldersListu := LoadStaticFoldersCached(CurrentSLD, irrelevantVar)
    Gui, SettingsGUIA: ListView, LViewOthers
    If (CountFilesFolderzList=1)
    {
       markedSelectFile := ""
       If StrLen(filesFilter)>1
       {
          usrFilesFilteru := filesFilter := ""
          FilterFilesIndex()
       }

       Tooltip, Preparing files list... please wait.
       Loop, % maxFilesIndex + 1
       {
           r := resultedFilesList[A_Index]
           If (InStr(r, "||") || !r)
              Continue

           If (A_TickCount - startOperation>2500)
              executingCanceableOperation := A_TickCount
           If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
           {
              lastLongOperationAbort := A_TickCount
              executingCanceableOperation := mustAbandonCurrentOperations := 0
              abandonAll := 1
              CountFilesFolderzList := 0
              Break
           }
           theEntireListu .= r "`n"
       }
       Tooltip, Counting files in each folder... please wait.
    }

    LV_ModifyCol(5, "Integer")
    LV_ModifyCol(1, "Integer")
    LV_ModifyCol(0, "Integer")
    startOperation := A_TickCount
    Loop, Parse, foldersListu, `n
    {
        If StrLen(A_LoopField)<2
           Continue

        If (A_TickCount - startOperation>2500)
           executingCanceableOperation := A_TickCount
        If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
        {
           lastLongOperationAbort := A_TickCount
           executingCanceableOperation := mustAbandonCurrentOperations := 0
           abandonAll := 1
           CountFilesFolderzList := 0
           Break
        }

        lineArru := StrSplit(A_LoopField, "*&*")
        folderu := lineArru[2]
        oldDateu := lineArru[1]
        indexu := SubStr(oldDateu, 3, InStr(oldDateu, "=")-3)
        oldDateu := SubStr(oldDateu, InStr(oldDateu, "=")+1)
        FileGetTime, dirDate, % folderu, M
        statusu := (dirDate!=oldDateu) ? "(*)" : "_"
;        If !dirDate
 ;          Continue
        dirDate := SubStr(dirDate, 1, StrLen(dirDate)-2)
        FormatTime, dirDate, % dirDate, yyyy/MM/dd-HH:mm
        If (CountFilesFolderzList=1)
        {
           ; matchThis := JEE_StrRegExLiteral(folderu "\")
           ; nonae := RegExReplace(theEntireListu, matchThis,, countFiles)
           nonae := StrReplace(theEntireListu, folderu "\",, countFiles)
        } Else countFiles := "-"

        LV_Add(A_Index, indexu, dirDate, statusu, folderu, countFiles)
        If (A_Index=5)
        {
           Loop, 5
               LV_ModifyCol(A_Index, "AutoHdr Left")
        }
    }

    executingCanceableOperation := 0
    Loop, 5
        LV_ModifyCol(A_Index, "AutoHdr Left")
    LV_ModifyCol(3, "Sort")
    If (CountFilesFolderzList=1)
       SoundBeep , 900, 100
    Tooltip
}

PopulateDynamicFolderzList() {
    foldersListu := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
    Gui, SettingsGUIA: ListView, LViewDynas
    Loop, Parse, foldersListu, `n
    {
        line := Trim(A_LoopField)
        If (StrLen(line)<2 || line="|hexists|")
           Continue
        counteru++
        statusu := InStr(line, "|") ? "_" : "[R]"
        LV_Add(A_Index, counteru, statusu, line)
    }
    Loop, 3
        LV_ModifyCol(A_Index, "AutoHdr Left")
}

CloseWindow() {
    If (A_TickCount - lastLongOperationAbort < 1000)
       Return

    Global lastOtherWinClose := A_TickCount
    ForceNoColorMatrix := 0
    Gui, SettingsGUIA: Destroy
    If (GIFsGuiCreated=1)
       DestroyGIFuWin()

    AnyWindowOpen := 0
    WinActivate, ahk_id %PVhwnd%
}

TooltipCreator(msg:=0,killWin:=0) {
    Critical, On
    Static prevMsg, lastInvoked := 1
    If (killWin=1)
    {
       Gui, ToolTipGuia: Destroy
       toolTipGuiCreated := 0
       Return
    }

    If (StrLen(msg)<3)
       Return

    If (A_TickCount-lastInvoked<150)
    {
       SetTimer, dummyShowToolTip, -200
       Return
    }

    lastInvoked := A_TickCount
    Gui, ToolTipGuia: Destroy
    thisFntSize := OSDfntSize
    Sleep, 5
    Gui, ToolTipGuia: -DPIScale -Caption +Owner1 +ToolWindow +E0x80000 +E0x20 +hwndhGuiTip
    Gui, ToolTipGuia: Margin, % thisFntSize + 5, % thisFntSize + 3
    Gui, ToolTipGuia: Color, c%OSDbgrColor%
    Gui, ToolTipGuia: Font, s%thisFntSize% Bold Q5, %OSDFontName%
    Gui, ToolTipGuia: Add, Text, +0x80 c%OSDtextColor% gRemoveTooltip, %msg%
;    Gui, ToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, GuiTipsWin

    GetClientSize(mainWidth, mainHeight, PVhwnd)
    JEE_ClientToScreen(hPicOnGui1, -1, -1, GuiX, GuiY)
    thisOpacity := (PrefsLargeFonts=1) ? 235 : 195
    WinSet, Transparent, %thisOpacity%, ahk_id %hGuiTip%
    toolTipGuiCreated := 1
    prevTooltipDisplayTime := A_TickCount
    prevMsg := msg
    WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight%, ahk_id %hGuiTip%
    Gui, ToolTipGuia: Show, NoActivate AutoSize x%GuiX% y%GuiY%, GuiTipsWin
}

BlackedCreator(thisOpacity, killWin:=0) {
    Critical, On
    Static lastInvoked := 1
    If (killWin=1)
    {
       Gui, BlackGuia: Destroy
       Return
    }

    If (A_TickCount-lastInvoked<250)
       Return

    lastInvoked := A_TickCount
    Gui, BlackGuia: Destroy
    Sleep, 5
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    Gui, BlackGuia: -DPIScale -Caption +Owner1 +ToolWindow +E0x80000 +E0x20 +hwndhGuiBlack
    Gui, BlackGuia: Color, c%OSDbgrColor%
    Gui, BlackGuia: Margin, 0, 0
    Gui, BlackGuia: Add, Text,+0x80 c%OSDtextColor% w%mainWidth% h%mainHeight% gRemoveTooltip, %msg%
    JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
    WinSet, Transparent, %thisOpacity%, ahk_id %hGuiBlack%
    WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight%, ahk_id %hGuiBlack%
    ; GuiX := GuiY := 0
    Gui, BlackGuia: Show, NoActivate AutoSize x%GuiX% y%GuiY%, GuiBlackedWin
    ; SetParentID(PVhwnd, hGuiBlack)
}

GIFguiCreator(imgpath:=1, killWin:=0, xPos:=1, yPos:=1, imgW:=1, imgH:=1, mainWidth:=1, mainHeight:=1) {
    Critical, On
    Static lastInvoked := 1
    If (killWin=1)
    {
       Gui, GIFsGuia: Destroy
       GIFsGuiCreated := 0
       Return
    }

    If (StrLen(imgpath)<3) || (A_TickCount-lastInvoked<200)
    {
       GIFguiCreator(1,1)
       Return
    }
    SetTimer, dummyTimerReloadThisPicture, Off
    SetTimer, dummyTimerDelayiedImageDisplay, Off
    lastInvoked := A_TickCount
    Gui, GIFsGuia: Destroy
    bgrColor := OSDbgrColor
    Sleep, 5
    Gui, GIFsGuia: -DPIScale -Caption +Owner +ToolWindow +E0x20 +hwndhGIFsGuiDummy
    Gui, GIFsGuia: Margin, 0, 0
    Gui, GIFsGuia: Color, c%bgrColor%
    AddAnimatedGIF(imgpath , xPos, yPos, imgW, imgH, "GIFsGuia")
    JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
    WinSet, Region, %xPos%-%yPos% R6-6 w%imgW% h%imgH%, ahk_id %hGIFsGuiDummy%
    Gui, GIFsGuia: Show, NoActivate x%GuiX% y%GuiY% h%mainWidth% h%mainHeight%, GIFsAnimWindow
    ; WinSet, AlwaysOnTop, 1, ahk_id %hGIFsGuiDummy%
    ; SetParentID(PVhwnd, hGIFsGuiDummy)
    GIFsGuiCreated := 1
}

WM_PENEVENT() {
   MouseGetPos, PmXo, PmYo
}

WM_LBUTTONDOWN(wP, lP, msg, hwnd) {
  If (A_TickCount - executingCanceableOperation<600)
  {
     triggerOwnDialogs()
     MsgBox, 52, %appTitle%, Do you want to stop the currently executing operation?
     IfMsgBox, Yes
     {
        executingCanceableOperation := mustAbandonCurrentOperations := 1
        lastLongOperationAbort := A_TickCount
     }
  }

  If !GetKeyState("LButton", "P")
     LbtnDwn := 1
  SetTimer, ResetLbtn, -50
}

WM_RBUTTONUP(wP, lP, msg, hwnd) {
  Static lastState := 0

  A := WinActive("A")
  okay := (A=PVhwnd || A=hGDIwin || A=hGIFsGuiDummy) ? 1 : 0
  If (okay!=1)
     Return

  GuiControl, 1:, editDummy, -
  If (thumbsDisplaying=1 && maxFilesIndex>0)
  {
     WinClickAction("rClick")
  } Else If (AnyWindowOpen=10)
  {
;     WinSet, Transparent, % (lastState=1) ? 255 : 10, ahk_id %hSetWinGui%
     GetClientSize(mainWidth, mainHeight, hSetWinGui)
     WinGetPos,,, Width, Height, ahk_id %hSetWinGui%
     thisHeight := (Height - mainHeight)//1.5
     thisWidth := mainWidth//3
     If (lastState=0)
        Gui, SettingsGUIA: Show, w%thisWidth% h%thisHeight%
     Else
        Gui, SettingsGUIA: Show, AutoSize
     lastState := !lastState
     Return
  }

  delayu := (thumbsDisplaying=1 || GIFsGuiCreated=1) ? 90 : 2
  If (GIFsGuiCreated=1)
     extendedDestroyGIFuWin(1)
  SetTimer, InitGuiContextMenu, % -delayu
}

updateGDIwinPos() {
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

ResetLbtn() {
  LbtnDwn := 0
}

WM_MOVING() {
  Global lastWinDrag := A_TickCount
  SetTimer, updateGDIwinPos, -5
}

WM_MOUSEMOVE(wP, lP, msg, hwnd) {
  Static oX, oY, oDx, oDy
  If (imageLoading=1)
     changeMcursor()

  A := WinActive("A")
  okay := (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin) ? 1 : 0
  If (okay!=1 || imageLoading=1) || (A_TickCount - lastWinDrag<45)
  {
     LbtnDwn := mPosCtrl := 0
     Return
  }

  If StrLen(A_GuiControl)>2
     mPosCtrl := A_GuiControl
  ; tooltip, % mPosCtrl
  LbtnDwn := (wP&0x1) && !(GetKeyState("LButton", "P")) ? 1 : 0
  If (LbtnDwn=1)
     SetTimer, ResetLbtn, -25

  If (hitTestSelectionPath && activateImgSelection=1 && editingSelectionNow=1 && adjustNowSel=0)
  {
     GetMouseCoord2wind(PVhwnd, mX, mY)
     hitA := Gdip_IsVisiblePathPoint(hitTestSelectionPath, mX, mY, glPG)
     Gdip_SetPenWidth(pPen1d, dotsSize)
     hitB := Gdip_IsOutlineVisiblePathPoint(glPG, hitTestSelectionPath, pPen1d, mX, mY)

     If (hitB=1)
       Try DllCall("user32\SetCursor", "Ptr", hCursFinger)
     Else If (hitA=1)
       ;Try DllCall("user32\SetCursor", "Ptr", hCursMove)
       Try DllCall("SetClassLong" . (A_PtrSize=8 ? "Ptr" : ""), "Ptr", hWnd, "Int", -12, "Ptr", hCursMove)
  } Else If (hitTestSelectionPath && thumbsDisplaying=1 && CurrentSLD && imageLoading!=1 && maxFilesIndex>1)
  {
     GetMouseCoord2wind(PVhwnd, mX, mY)
     hitA := Gdip_IsVisiblePathPoint(hitTestSelectionPath, mX, mY, glPG)
     If (hitA=1)
       Try DllCall("user32\SetCursor", "Ptr", hCursFinger)
  }

  ; ToolTip, % mPosCtrl
  If (isTitleBarHidden=1 && (wP&0x1) && thumbsDisplaying=0)
  && (A_TickCount - lastWinDrag>45) 
  {
     PostMessage, 0xA1, 2,,, ahk_id %PVhwnd%
     lastWinDrag := A_TickCount
     SetTimer, trackMouseDragging, -55
     Return
  } Else If (wP&0x10)
     ToggleThumbsMode()
}

trackMouseDragging() {
    lastWinDrag := A_TickCount
}

CalcStringHash(string, algid, encoding = "UTF-8", byref hash = 0, byref hashlength = 0) {
; function by jNizM and Bentschi
; taken from https://github.com/jNizM/HashCalc
; this calculates the MD5 hash
; function under MIT License: https://raw.githubusercontent.com/jNizM/AHK_Network_Management/master/LICENSE

    chrlength := (encoding = "CP1200" || encoding = "UTF-16") ? 2 : 1
    length := (StrPut(string, encoding) - 1) * chrlength
    VarSetCapacity(data, length, 0)
    StrPut(string, &data, floor(length / chrlength), encoding)
    Result := CalcAddrHash(&data, length, algid, hash, hashlength)
    Return Result
}

CalcAddrHash(addr, length, algid, byref hash = 0, byref hashlength = 0) {
; function by jNizM and Bentschi
; taken from https://github.com/jNizM/HashCalc
; function under MIT License: https://raw.githubusercontent.com/jNizM/AHK_Network_Management/master/LICENSE

    Static h := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "a", "b", "c", "d", "e", "f"]
         , b := h.minIndex()
    hProv := hHash := o := ""
    CAC := DllCall("advapi32\CryptAcquireContext", "Ptr*", hProv, "Ptr", 0, "Ptr", 0, "UInt", 24, "UInt", 0xf0000000)
    If CAC
    {
       CCH := DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", algid, "UInt", 0, "UInt", 0, "Ptr*", hHash)
       If CCH
       {
          CHD := DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", addr, "UInt", length, "UInt", 0)
          If CHD
          {
             CGP := DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", 0, "UInt*", hashlength, "UInt", 0)
             If CGP
             {
                VarSetCapacity(hash, hashlength, 0)
                CGHP := DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", &hash, "UInt*", hashlength, "UInt", 0)
                If CGHP
                {
                   Loop, %hashlength%
                   {
                      v := NumGet(hash, A_Index - 1, "UChar")
                      o .= h[(v >> 4) + b] h[(v & 0xf) + b]
                   }
                }
             }
          }
          CDH := DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
       }
       CRC := DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
    }
    Return o
}

; =================================================================================================
; Function......: GetModuleFileNameEx
; DLL...........: Kernel32.dll / Psapi.dll
; Library.......: Kernel32.lib / Psapi.lib
; U/ANSI........: GetModuleFileNameExW (Unicode) and GetModuleFileNameExA (ANSI)
; Author........: jNizM
; Modified......:
; Links.........: http://msdn.microsoft.com/en-us/library/windows/desktop/ms683198(v=vs.85).aspx
; =================================================================================================
GetModuleFileNameEx(PID) {
; found on: https://autohotkey.com/board/topic/109557-processid-a-scriptfullpath/

    hProcess := DllCall("Kernel32.dll\OpenProcess", "UInt", 0x001F0FFF, "UInt", 0, "UInt", PID)
    If (ErrorLevel || hProcess = 0)
       Return
    Static lpFilename, nSize := 260, int := VarSetCapacity(lpFilename, nSize, 0)
    DllCall("Psapi.dll\GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", lpFilename, "UInt", nSize)
    DllCall("Kernel32.dll\CloseHandle", "Ptr", hProcess)
    Return lpFilename
}

GetCurrentProcessId() {
    Return DllCall("Kernel32.dll\GetCurrentProcessId")
}

Fnt_GetListOfFonts() {
; function stripped down from Font Library 3.0 by jballi
; from https://autohotkey.com/boards/viewtopic.php?t=4379

    Static Dummy65612414
          ,HWND_DESKTOP := 0   ;-- Device constants
          ,LF_FACESIZE  := 32  ;-- In TCHARS - LOGFONT constants

    ;-- Initialize and populate LOGFONT structure
    Fnt_EnumFontFamExProc_List := ""
    p_CharSet := 1
    p_Flags := 0x800
    VarSetCapacity(LOGFONT,A_IsUnicode ? 92:60,0)
    NumPut(p_CharSet,LOGFONT,23,"UChar")                ;-- lfCharSet

    ;-- Enumerate fonts
    EFFEP := RegisterCallback("Fnt_EnumFontFamExProc","F")
    hDC := GetDC(HWND_DESKTOP)
    DllCall("gdi32\EnumFontFamiliesExW"
       ,"Ptr", hDC                                      ;-- hdc
       ,"Ptr", &LOGFONT                                 ;-- lpLogfont
       ,"Ptr", EFFEP                                    ;-- lpEnumFontFamExProc
       ,"Ptr", p_Flags                                  ;-- lParam
       ,"UInt", 0)                                      ;-- dwFlags (must be 0)

    DllCall("user32\ReleaseDC","Ptr",HWND_DESKTOP,"Ptr",hDC)
    DllCall("GlobalFree", "Ptr", EFFEP)
    Return Fnt_EnumFontFamExProc_List
}

Fnt_EnumFontFamExProc(lpelfe,lpntme,FontType,p_Flags) {
    Fnt_EnumFontFamExProc_List := 0
    Static Dummy62479817
          ,LF_FACESIZE := 32     ;-- In TCHARS - LOGFONT constants

    l_FaceName := StrGet(lpelfe+28,LF_FACESIZE)
    FontList.Push(l_FaceName)    ;-- Append the font name to the list
    Return 1                     ;-- Continue enumeration
}

ST_Insert(insert,input,pos=1) {
  Length := StrLen(input)
  ((pos > 0) ? (pos2 := pos - 1) : (((pos = 0) ? (pos2 := StrLen(input),Length := 0) : (pos2 := pos))))
  output := SubStr(input, 1, pos2) . insert . SubStr(input, pos, Length)
  If (StrLen(output) > StrLen(input) + StrLen(insert))
     ((Abs(pos) <= StrLen(input)/2) ? (output := SubStr(output, 1, pos2 - 1) . SubStr(output, pos + 1, StrLen(input)))
     : (output := SubStr(output, 1, pos2 - StrLen(insert) - 2) . SubStr(output, pos - StrLen(insert), StrLen(input))))
  Return output
}

SetVolume(val:=100, r:="") {
; Function by Drugwash
  v := Round(val*655.35)
  vr := r="" ? v : Round(r*655.35)
  Try DllCall("winmm\waveOutSetVolume", "UInt", 0, "UInt", (v|vr<<16))
}

initCompiled() {
   Current_PID := GetCurrentProcessId()
   fullPath2exe := GetModuleFileNameEx(Current_PID)
   zPlitPath(fullPath2exe, 0, OutFileName, OutDir)
   mainCompiledPath := OutDir
   thumbsCacheFolder := OutDir "\thumbs-cache"
   mainSettingsFile := OutDir "\" mainSettingsFile
}

RunAdminMode() {
  If !A_IsAdmin
  {
      Try {
         If A_IsCompiled
            Run *RunAs "%fullPath2exe%" /restart
         Else
            Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"

         ExitApp
      }
  }
}

FileAssociate(Label,Ext,Cmd,Icon:="", batchMode:=0) {
; by Ħakito: https://autohotkey.com/boards/viewtopic.php?f=6&t=55638 
; modified by Marius Șucan to AHK v1.1

  ; Weeds out faulty extensions, which must start with a period, and contain more than 1 character
  iF (SubStr(Ext,1,1)!="." || StrLen(Ext)<=1)
     Return 0

  ; Weeds out faulty labels such as ".exe" which is an extension and not a label
  iF (SubStr(Label,1,1)=".")
     Return 0

  If Label
     RegRead, CheckLabel, HKEY_CLASSES_ROOT\%Label%, FriendlyTypeName

  ; Do not allow the modification of some important registry labels
  iF (Cmd!="" && CheckLabel)
     Return 0

  regFile := "Windows Registry Editor Version 5.00`n`n"
  ; Note that "HKEY_CLASSES_ROOT" actually writes to "HKEY_LOCAL_MACHINE\SOFTWARE\Classes"
  ; If the command is just a simple path, then convert it into a proper run command
  iF (SubStr(Cmd,2,2)=":\" && FileExist(Cmd))
     Cmd := """" Cmd """" A_Space """" "%1" """"
  Else
     Return 0

  Cmd := StrReplace(Cmd, "\", "\\")
  Cmd := StrReplace(Cmd, """", "\""")
  regFile .= "[HKEY_CLASSES_ROOT\" Ext "]`n@=" """" Label """" "`n"
  regFile .= "`n[HKEY_CLASSES_ROOT\" Label "]`n@=" """" Label """" "`n"
  regFile .= "`n[HKEY_CLASSES_ROOT\" Label "\Shell\Open\Command]`n@=" """" Cmd """" "`n"
  regFile .= "`n[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" Ext "\UserChoice]`n""ProgId""=" """" Label """" "`n"
  regFile .= "`n[-HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" Ext "\OpenWithProgids]`n"
  regFile .= "`n[-HKEY_CLASSES_ROOT\" Ext "\OpenWithProgids]`n`n"

  If Icon
     regFile .= "`n[HKEY_CLASSES_ROOT\" QPVslideshow "\DefaultIcon]`n@=" Icon "`n`n"

  If !InStr(FileExist(mainCompiledPath "\regFiles"), "D")
  {
     FileCreateDir, %mainCompiledPath%\regFiles
     Sleep, 1
  }

  iExt := StrReplace(Ext, ".")
  FileDelete, %mainCompiledPath%\regFiles\RegFormat%iExt%.reg
  Sleep, 1
  FileAppend, % regFile, %mainCompiledPath%\regFiles\RegFormat%iExt%.reg
  runTarget := "Reg Import """ mainCompiledPath "\regFiles\RegFormat" iExt ".reg" """" "`n"
  If !InStr("|WIN_7|WIN_8|WIN_8.1|WIN_VISTA|WIN_2003|WIN_XP|WIN_2000|", "|" A_OSVersion "|")
     runTarget .= """" mainCompiledPath "\SetUserFTA.exe""" A_Space Ext A_Space Label "`n"
  FileAppend, % runTarget, %mainCompiledPath%\regFiles\runThis.bat
  If (batchMode!=1)
  {
     Sleep, 1
     RunWait, *RunAs %mainCompiledPath%\regFiles\runThis.bat
     FileDelete, %mainCompiledPath%\regFiles\RegFormat%iExt%.reg
     FileDelete, %mainCompiledPath%\regFiles\runThis.bat
  }

  return 1
}

; ==================================================================================================================================
; function by «just me», source https://www.autohotkey.com/boards/viewtopic.php?t=18081
;
; Creates an 'open with' menu for the passed file.
; Parameters:
;     FilePath    -  Fully qualified path of a single file.
;     Recommended -  Show only recommended apps (True/False).
;                    Default: True
;     ShowMenu    -  Immediately show the menu (True/False).
;                    Default: False
;     MenuName    -  The name of the menu.
;                    Default: OpenWithMenu
;     Others      -  Name of the submenu holding not recommended apps (if Recommended has been set to False).
;                    Default: Others
; Return values:
;     On success the function returns the menu's name unless ShowMenu has been set to True.
;     If the menu couldn't be created, the function returns False.
; Remarks:
;     Requires AHK 1.1.23.07+ and Win Vista+!!!
;     The function registers itself as the menu handler.
; Credits:
;     Based on code by querty12 -> autohotkey.com/boards/viewtopic.php?p=86709#p86709.
;     I hadn't even heard anything about the related API functions before.
; MSDN:
;     SHAssocEnumHandlers -> msdn.microsoft.com/en-us/library/bb762109%28v=vs.85%29.aspx
;     SHCreateItemFromParsingName -> msdn.microsoft.com/en-us/library/bb762134%28v=vs.85%29.aspx
; ==================================================================================================================================
CreateOpenWithMenu(FilePath, Recommended := 1, ShowMenu := 0, MenuName := "OpenWithMenu", Others := "Others") {
   Static RecommendedHandlers := []
        , OtherHandlers := []
        , HandlerID := A_TickCount
        , HandlerFunc := 0
        , ThisMenuName := ""
        , ThisOthers := ""
   ; -------------------------------------------------------------------------------------------------------------------------------
   Static IID_IShellItem := 0, BHID_DataObject := 0, IID_IDataObject := 0
        , Init := VarSetCapacity(IID_IShellItem, 16, 0) . VarSetCapacity(BHID_DataObject, 16, 0)
          . VarSetCapacity(IID_IDataObject, 16, 0)
          . DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
          . DllCall("Ole32.dll\IIDFromString", "WStr", "{B8C0BD9F-ED24-455c-83E6-D5390C4FE8C4}", "Ptr", &BHID_DataObject)
          . DllCall("Ole32.dll\IIDFromString", "WStr", "{0000010e-0000-0000-C000-000000000046}", "Ptr", &IID_IDataObject)
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; Handler call
   If (Recommended = HandlerID) {
      AssocHandlers := A_ThisMenu = ThisMenuName ? RecommendedHandlers : OtherHandlers
      If (AssocHandler := AssocHandlers[A_ThisMenuItemPos]) && FileExist(FilePath) {
         AssocHandlerInvoke := NumGet(NumGet(AssocHandler + 0, "UPtr"), A_PtrSize * 8, "UPtr")
         If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", FilePath, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", Item) {
            BindToHandler := NumGet(NumGet(Item + 0, "UPtr"), A_PtrSize * 3, "UPtr")
            If !DllCall(BindToHandler, "Ptr", Item, "Ptr", 0, "Ptr", &BHID_DataObject, "Ptr", &IID_IDataObject, "PtrP", DataObj) {
               DllCall(AssocHandlerInvoke, "Ptr", AssocHandler, "Ptr", DataObj)
               ObjRelease(DataObj)
            }
            ObjRelease(Item)
         }
      }
      Try Menu, %ThisMenuName%, DeleteAll
      For Each, AssocHandler In RecommendedHandlers
         ObjRelease(AssocHandler)
      For Each, AssocHandler In OtherHandlers
         ObjRelease(AssocHandler)
      RecommendedHandlers := []
      OtherHandlers := []
      Return
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; User call
   If !FileExist(FilePath)
      Return 0

   ThisMenuName := MenuName
   ThisOthers := Others
   SplitPath, FilePath, , , Ext
   For Each, AssocHandler In RecommendedHandlers
      ObjRelease(AssocHandler)
   For Each, AssocHandler In OtherHandlers
      ObjRelease(AssocHandler)
   RecommendedHandlers:= []
   OtherHandlers:= []
   Try Menu, %ThisMenuName%, DeleteAll
   Try Menu, %ThisOthers%, DeleteAll
   ; Try to get the default association
   Size := VarSetCapacity(FriendlyName, 520, 0) // 2
   DllCall("Shlwapi.dll\AssocQueryString", "UInt", 0, "UInt", 4, "Str", "." . Ext, "Ptr", 0, "Str", FriendlyName, "UIntP", Size)
   HandlerID := A_TickCount
   HandlerFunc := Func(A_ThisFunc).Bind(FilePath, HandlerID)
   Filter := !!Recommended ; ASSOC_FILTER_NONE = 0, ASSOC_FILTER_RECOMMENDED = 1
   ; Enumerate the apps and build the menu
   If DllCall("Shell32.dll\SHAssocEnumHandlers", "WStr", "." . Ext, "UInt", Filter, "PtrP", EnumHandler)
      Return 0

   EnumHandlerNext := NumGet(NumGet(EnumHandler + 0, "UPtr"), A_PtrSize * 3, "UPtr")
   While (!DllCall(EnumHandlerNext, "Ptr", EnumHandler, "UInt", 1, "PtrP", AssocHandler, "UIntP", Fetched) && Fetched)
   {
      VTBL := NumGet(AssocHandler + 0, "UPtr")
      AssocHandlerGetUIName := NumGet(VTBL + 0, A_PtrSize * 4, "UPtr")
      AssocHandlerGetIconLocation := NumGet(VTBL + 0, A_PtrSize * 5, "UPtr")
      AssocHandlerIsRecommended := NumGet(VTBL + 0, A_PtrSize * 6, "UPtr")
      UIName := ""
      If !DllCall(AssocHandlerGetUIName, "Ptr", AssocHandler, "PtrP", StrPtr, "UInt")
      {
         UIName := StrGet(StrPtr, "UTF-16")
         DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
      } Else UIName := AssocHandler

      If (UIName!="")
      {
         If !DllCall(AssocHandlerGetIconLocation, "Ptr", AssocHandler, "PtrP", StrPtr, "IntP", IconIndex := 0, "UInt")
         {
            IconPath := StrGet(StrPtr, "UTF-16")
            DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
         }

         If (SubStr(IconPath, 1, 1) = "@")
         {
            VarSetCapacity(Resource, 4096, 0)
            If !DllCall("Shlwapi.dll\SHLoadIndirectString", "WStr", IconPath, "Ptr", &Resource, "UInt", 2048, "PtrP", 0)
               IconPath := StrGet(&Resource, "UTF-16")
         }
         ItemName := StrReplace(UIName, "&", "&&")
         If (Recommended || !DllCall(AssocHandlerIsRecommended, "Ptr", AssocHandler, "UInt"))
         {
            If (UIName=FriendlyName)
            {
               If RecommendedHandlers.Length()
               {
                  Menu, %ThisMenuName%, Insert, 1&, %ItemName%, % HandlerFunc
                  RecommendedHandlers.InsertAt(1, AssocHandler)
               } Else
               {
                  Menu, %ThisMenuName%, Add, %ItemName%, % HandlerFunc
                  RecommendedHandlers.Push(AssocHandler)
               }
         ;      Menu, %ThisMenuName%, Default, %ItemName%
            } Else
            {
               Menu, %ThisMenuName%, Add, %ItemName%, % HandlerFunc
               RecommendedHandlers.Push(AssocHandler)
            }
            Try Menu, %ThisMenuName%, Icon, %ItemName%, %IconPath%, %IconIndex%
         } Else
         {
            Menu, %ThisOthers%, Add, %ItemName%, % HandlerFunc
            OtherHandlers.Push(AssocHandler)
            Try Menu, %ThisOthers%, Icon, %ItemName%, %IconPath%, %IconIndex%
         }
      } Else ObjRelease(AssocHandler)
   }

   ObjRelease(EnumHandler)
   ; All done
   If !RecommendedHandlers.Length() && !OtherHandlers.Length()
      Return 0

   If OtherHandlers.Length()
      Menu, %ThisMenuName%, Add, %ThisOthers%, :%ThisOthers%

   If (ShowMenu=1)
      Menu, %ThisMenuName%, Show
   Else
      Return ThisMenuName
}

invokeSHopenWith() {
; function by zcooler
; source:  https://www.autohotkey.com/boards/viewtopic.php?t=17850

  ; msdn.microsoft.com/en-us/library/windows/desktop/bb762234(v=vs.85).aspx
  ; OAIF_ALLOW_REGISTRATION   0x00000001 - Enable the "always use this program" checkbox. If not passed, it will be disabled.
  ; OAIF_REGISTER_EXT         0x00000002 - Do the registration after the user hits the OK button.
  ; OAIF_EXEC                 0x00000004 - Execute file after registering.
  OAIF := {ALLOW_REGISTRATION: 0x00000001, REGISTER_EXT: 0x00000002, EXEC: 0x00000004}
  imgPath := resultedFilesList[currentFileIndex]
  VarSetCapacity(OPENASINFO, A_PtrSize * 3, 0)
  NumPut(&imgPath, OPENASINFO, 0, "Ptr")
  NumPut(0x04, OPENASINFO, A_PtrSize * 2, "UInt")
  DllCall("Shell32.dll\SHOpenWithDialog", "Ptr", 0, "Ptr", &OPENASINFO)
}

AutoCropPanelWindow() {
    Global UIcropThreshold, btnFldr, infoCropTolerance, infoCropThreshold, infoCropDeviation, mainBtnACT

    If (vpIMGrotation>0)
    {
       vpIMGrotation := 0
       showTOOLtip("Image rotation: 0°")
       RefreshImageFile()
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Sleep, 250
    }

    createSettingsGUI(17)
    btnWid := 100
    txtWid := slideWid := 280
    slide2Wid := 220

    If (PrefsLargeFonts=1)
    {
       slideWid := slideWid + 135
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       slide2Wid := slide2Wid + 65
       Gui, Font, s%LargeUIfontValue%
    }

    measureUnit := (usrAutoCropDeviationPixels=1) ? " px" : " %"
    filesElected := getSelectedFiles(0, 1)
    UIcropThreshold := Round(usrAutoCropImgThreshold * 100)
    Gui, Add, Text, x15 y15 Section, Please adjust the following parameters for best results.
    Gui, Add, Text, xs y+8 w%slide2Wid% vinfoCropTolerance, Color variation tolerance: %usrAutoCropColorTolerance%
    Gui, Add, Text, x+1 yp, Image corners preview
    Gui, -DPIScale
    Gui, Add, Text, xp+1 y+1 w220 h220 +0xE gTglAutoCropBorderzSize +hwndhCropCornersPic, -
    Gui, +DPIScale
    Gui, Add, Slider, xs yp+1 AltSubmit gUpdateAutoCropParams ToolTip w%slide2Wid% vusrAutoCropColorTolerance Range0-254, % usrAutoCropColorTolerance
    Gui, Add, Text, xs y+8 w%slide2Wid% vinfoCropThreshold, Image threshold: %UIcropThreshold%
    Gui, Add, Slider, xs y+5 AltSubmit gUpdateAutoCropParams ToolTip w%slide2Wid% vUIcropThreshold Range0-99, % UIcropThreshold
    Gui, Add, Text, xs y+8 w%slide2Wid% gresetAutoCropDeviation vinfoCropDeviation, Margins deviation factor: %usrAutoCropDeviation%%measureUnit%
    Gui, Add, Slider, xs y+5 AltSubmit gUpdateAutoCropParams ToolTip w%slide2Wid% vusrAutoCropDeviation Range-50-50, %usrAutoCropDeviation%

    Gui, Add, Checkbox, y+10 w%slide2Wid% gUpdateAutoCropParams Checked%usrAutoCropDeviationSnap% vusrAutoCropDeviationSnap, Snap to original image edges
    Gui, Add, Checkbox, x+1  gUpdateAutoCropParams Checked%usrAutoCropDeviationPixels% vusrAutoCropDeviationPixels, Deviation factor in pixels
    Gui, Add, Checkbox, xs y+10 gUpdateAutoCropParams Checked%usrAutoCropGenerateSelection% vusrAutoCropGenerateSelection, Generate an image selection
    Gui, Add, Checkbox, y+10 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file[s] in the following folder: 
    Gui, Add, Edit, xp+10 y+5 wp r1 +0x0800 -wrap vResizeDestFolder, % ResizeDestFolder
    Gui, Add, Button, x+5 hp w90 gBTNchangeResizeDestFolder vbtnFldr, C&hoose
    If (filesElected>1)
    {
       Gui, Font, Bold
       Gui, Add, Text, xs y+15 Section, Files selected to process: %filesElected%.
       Gui, Font, Normal
    } 
    If !ResizeUseDestDir
    {
       GuiControl, Disable, btnFldr
       GuiControl, Disable, ResizeDestFolder
    }

    Gui, Add, Button, xs y+20 h30 w35 gBtnPrevImg, <<
    Gui, Add, Button, x+5 hp wp gBtnNextImg, >>
    Gui, Add, Button, x+5 hp w%btnWid% Default gBTNautoCropRealtime vmainBtnACT, &Viewport preview

    friendly := (filesElected>1) ? "&Process files..." : "&Save file as..."
    Gui, Add, Button, x+5 hp w%btnWid% gBTNsaveAutoCroppedFile, % friendly
    Gui, Add, Button, x+5 hp w80 gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, Automatically crop image: %appTitle%
    captureImgCorners(gdiBitmap)
}

resetAutoCropDeviation() {
    GuiControl, SettingsGUIA:, usrAutoCropDeviation, 0
    UpdateAutoCropParams()
}

UpdateAutoCropParams() {
    GuiControlGet, UIcropThreshold
    GuiControlGet, usrAutoCropColorTolerance
    GuiControlGet, usrAutoCropGenerateSelection
    GuiControlGet, usrAutoCropDeviation
    GuiControlGet, usrAutoCropDeviationSnap
    GuiControlGet, usrAutoCropDeviationPixels
    GuiControlGet, ResizeUseDestDir
    GuiControlGet, ResizeDestFolder

    usrAutoCropImgThreshold := UIcropThreshold/100
    measureUnit := (usrAutoCropDeviationPixels=1) ? " px" : " %"
    GuiControl, SettingsGUIA:, infoCropTolerance, Color variation tolerance: %usrAutoCropColorTolerance%
    GuiControl, SettingsGUIA:, infoCropThreshold, Image threshold: %UIcropThreshold%
    GuiControl, SettingsGUIA:, infoCropDeviation, Margins deviation factor: %usrAutoCropDeviation%%measureUnit%
    SetTimer, writeMainSettings, -15
}

TglAutoCropBorderzSize() {
    Static lastInvoked := 1

    If (A_TickCount - lastInvoked < 900) && (AutoCropBordersSize!=5)
       AutoCropBordersSize := 5
    Else
       AutoCropBordersSize := (AutoCropBordersSize=15) ? 30 : 15
    captureImgCorners(gdiBitmap)
    lastInvoked := A_TickCount
}

captureImgCorners(whichBmp) {
   cornersBMP2 := coreCaptureImgCorners(whichBmp)
   hBitmap := Gdip_CreateHBITMAPFromBitmap(cornersBMP2)
   SetImage(hCropCornersPic, hBitmap)
   Gdip_DisposeImage(cornersBMP2)
}

coreCaptureImgCorners(whichBmp, thisSize:=0, thisBoxSize:=0) {
    boxSize := (thisBoxSize=0) ? 220 : thisBoxSize
    realSize := (thisSize=0) ? AutoCropBordersSize : thisSize
    cornersBMP := Gdip_CreateBitmap(boxSize, boxSize)
    G := Gdip_GraphicsFromImage(cornersBMP, 3)
    Gdip_GetImageDimensions(whichBmp, imgW, imgH)

    If (activateImgSelection=1)
    {
       calcImgSelection2bmp(imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    } Else
    {
       X1 := Y1 := 0
       X2 := ImgSelW := imgW
       Y2 := ImgSelH := imgH
    }

    Loop, 3
    {
        r1 := Gdip_DrawImage(G, whichBmp, 0, 0, boxSize//2, boxSize//2, X1, Y1, realSize, realSize)
        r1 := Gdip_DrawImage(G, whichBmp, boxSize//2, 0, boxSize//2, boxSize//2, X2 - realSize, Y1, realSize, realSize)
        r1 := Gdip_DrawImage(G, whichBmp, 0, boxSize//2, boxSize//2, boxSize//2, X1, Y2 - realSize, realSize, realSize)
        r1 := Gdip_DrawImage(G, whichBmp, boxSize//2, boxSize//2, boxSize//2, boxSize//2, X2 - realSize, Y2 - realSize, realSize, realSize)
    }

    borderSize := 8
    cornersBMP2 := Gdip_CreateBitmap(boxSize+borderSize, boxSize+borderSize)
    G2 := Gdip_GraphicsFromImage(cornersBMP2, 3)
    Gdip_FillRectangle(G2, pBrushE, 0, 0, boxSize*2, boxSize*2)
    Gdip_FillRectangle(G2, pBrushE, 0, 0, boxSize*2, boxSize*2)
    r1 := Gdip_DrawImageFast(G2, cornersBMP, borderSize//2, borderSize//2)

    Gdip_DeleteGraphics(G)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(cornersBMP)
    Return cornersBMP2
}

AutoCropAction(zBitmap, varTolerance, threshold, silentMode:=0, forceNoSel:=0) {
   If (silentMode=0)
      showTOOLtip("Calculating auto-cropped region... step 0")

   aBitmap := Gdip_BitmapConvertGray(zBitmap)
   Gdip_GetImageDimensions(aBitmap, Width, Height)
   pBitmap := Gdip_ResizeBitmap(aBitmap, Width//2, Height//2, 0)
   Gdip_DisposeImage(aBitmap)
   ; pBitmap := aBitmap
   alphaUniform := Gdip_TestBitmapUniformity(pBitmap, 3, maxLevelIndex, maxLevelPixels)
   If (alphaUniform=1)
   {
      If (silentMode=0)
      {
         SoundBeep , 900, 100
         showTOOLtip("The image seems to be uniformly colored.")
      }
      Return
   }

   selCoords := CoreAutoCropAlgo(pBitmap, varTolerance, threshold)
   selCoords := StrSplit(selCoords, ",")
   X1 := selCoords[1]
   Y1 := selCoords[2]
   X2 := selCoords[3]
   Y2 := selCoords[4]
   Gdip_DisposeImage(pBitmap)

   If (silentMode=0)
   {
      SoundBeep , 900, 100
      SetTimer, RemoveTooltip, -500
   }

   If (usrAutoCropGenerateSelection=0 || forceNoSel=1)
   {
      newW := X2 - X1
      newH := Y2 - Y1
      kBitmap := Gdip_CloneBitmapArea(zBitmap, X1, Y1, newW, newH)
      return kBitmap
   } Else
   {
      ImgSelX1 := X1
      ImgSelY1 := Y1
      ImgSelX2 := X2
      ImgSelY2 := Y2
      prcSelX1 := X1/Width
      prcSelY1 := Y1/Height
      prcSelX2 := X2/Width
      prcSelY2 := Y2/Height
   }
}

CoreAutoCropAlgo(pBitmap, varTolerance, threshold, silentMode:=0) {
   Gdip_GetImageDimensions(pBitmap, Width, Height)
   maxThresholdHitsW := Round(Width*threshold) + 1
   If (maxThresholdHitsW>Width//2)
      maxThresholdHitsW := Width//2

   maxThresholdHitsH := Round(Height*threshold) + 1
   If (maxThresholdHitsH>Height//2)
      maxThresholdHitsH := Height//2

   If (threshold=0)
      maxThresholdHitsW := maxThresholdHitsH := 1

   If (silentMode=0)
      showTOOLtip("Calculating auto-cropped region... step 1 - Y1")
   c := Gdip_GetPixelColor(pBitmap, 1, 1, 2)
   c := StrSplit(c, ",")
   prevR1 := firstR1 := c[1]
   x := y := ToleranceHits := 0
   E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, Stride1, Scan01, BitmapData1)
   Loop %Height%
   {
      y++
      vX := 0, vY := y - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vX := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Width%
      {
         pX := A_Index-1, pY := y - 1
         Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
     ;  sleep, 10
      ;    ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsW " [" varTolerance "]" "`n" firstR1 ", " primeR1a ", " primeR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         {
            prevR1 := R1
         } Else If (ToleranceHits<maxThresholdHitsW)
         {
            ToleranceHits++
         } Else
         {
            Y1 := "ok"
            Break
         }
      }
      ToleranceHits := 0
      If Y1
      {
         Y1 := y - 1
         Break
      }
   }

   If (silentMode=0)
      showTOOLtip("Calculating auto-cropped region... step 2 - X1")
   prevR1 := firstR1
   x := y := ToleranceHits := 0
   Loop %Width% 
   {
      x++
      vY := 0, vX := x - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vY := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Height%
      {
         pY := A_Index-1, pX := x - 1
         Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
         ; ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsH "`n" prevR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         {
            prevR1 := R1
         } Else If (ToleranceHits<maxThresholdHitsH)
         {
            ToleranceHits++
         } Else
         {
            X1 := "ok"
            Break
         }
      }
      ToleranceHits := 0
      If X1
      {
         X1 := x - 1
         Break
      }
   }

   If (silentMode=0)
      showTOOLtip("Calculating auto-cropped region... step 3 - Y2")
   Gdip_UnlockBits(pBitmap, BitmapData1)
   Gdip_ImageRotateFlip(pBitmap, 2)
   c := Gdip_GetPixelColor(pBitmap, 1, 1, 2)
   c := StrSplit(c, ",")
   prevR1 := firstR1 := c[1]
   x := y := ToleranceHits := 0
   E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, Stride1, Scan01, BitmapData1)

   Loop %Height%
   {
      y++
      vX := 0, vY := y - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vX := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Width%
      {
         pX := A_Index-1, pY := y - 1
         Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
         ; ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsW "`n" prevR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         {
            prevR1 := R1
         } Else If (ToleranceHits<maxThresholdHitsW)
         {
            ToleranceHits++
         } Else
         {
            Y2 := "ok"
            Break
         }
      }
      ToleranceHits := 0
      If Y2
      {
         Y2 := Height - y - 1
         Break
      }
   }

   If (silentMode=0)
      showTOOLtip("Calculating auto-cropped region... step 4 - X2")
   prevR1 := firstR1
   x := y := ToleranceHits := 0
   Loop %Width% 
   {
      x++
      vY := 0, vX := x - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vY := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Height%
      {
         pY := A_Index-1, pX := x - 1
         Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
         ; ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsH "`n" prevR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         {
            prevR1 := R1
         } Else If (ToleranceHits<maxThresholdHitsH)
         {
            ToleranceHits++
         } Else
         {
            X2 := "ok"
            Break
         }
      }
      ToleranceHits := 0
      If X2
      {
         X2 := Width - x - 1
         Break
      }
   }

   deviationW := (usrAutoCropDeviationPixels=1) ? usrAutoCropDeviation : Round((Width/100)*usrAutoCropDeviation)
   deviationH := (usrAutoCropDeviationPixels=1) ? usrAutoCropDeviation : Round((Height/100)*usrAutoCropDeviation)
   If (usrAutoCropDeviationSnap=1 && X1>2) || (usrAutoCropDeviationSnap=0)
      X1 -= deviationW
   If (usrAutoCropDeviationSnap=1 && Y1>2) || (usrAutoCropDeviationSnap=0)
      Y1 -= deviationH
   If (usrAutoCropDeviationSnap=1 && X2<Width-3) || (usrAutoCropDeviationSnap=0)
      X2 += deviationW
   If (usrAutoCropDeviationSnap=1 && Y2<Height-3) || (usrAutoCropDeviationSnap=0)
      Y2 += deviationH

   ; ToolTip, % X1 "," Y1 "--" X2 "," Y2 "`n" maxThresholdHitsW "--" maxThresholdHitsH "--" firstR1, , , 2
   If (X1="" || X1>Width - 2)
      X1 := Width - 3
   If (Y1="" || Y1>Height - 2)
      Y1 := Height - 3
   If (X2="" || X2<3)
      X2 := 3
   If (Y2="" || Y2<3)
      Y2 := 3

   X2 := X2*2, Y2 := Y2*2
   X1 := X1*2, Y1 := Y1*2
   If (X2 < X1 - 2)
      X2 := X1 + 2
   If (Y2 < Y1 - 2)
      Y2 := Y1 + 2

   selCoords := x1 "," y1 "," x2 "," y2
   Gdip_UnlockBits(pBitmap, BitmapData1)
   Return selCoords
}

BTNsaveAutoCroppedFile() {
    UpdateAutoCropParams()
    filesElected := getSelectedFiles()
    If (filesElected>1)
    {
       batchAutoCropFiles()
       Return
    }

   imgPath := resultedFilesList[currentFileIndex]
   zPlitPath(imgPath, 0, OutFileName, OutDir)
   startPath := (ResizeUseDestDir=1) ? ResizeDestFolder "\" OutFileName : imgPath
   triggerOwnDialogs()
   FileSelectFile, file2save, S18, % startPath, Save processed image as..., Images (%dialogSaveFptrn%)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If !RegExMatch(file2save, saveTypesRegEX)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: Please use a supported file format extension: %saveTypesFriendly%.
         Return
      }

      zPlitPath(file2save, 0, OutFileName, OutDir)
      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: This format is currently unsupported. The FreeImage library failed to properly initialize.`n`n%OutFileName%
         Return
      }

      r := coreAutoCropFileProcessing(imgPath, file2save, 0)
      If r
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: Unable to save file. Error code: %r%.`n`n%OutFileName%
         Return
      }

      If (ResizeUseDestDir=1)
         prevFileSavePath := ResizeDestFolder

      writeMainSettings()
      SoundBeep, 900, 100
      showTOOLtip("Processed image saved...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

coreAutoCropFileProcessing(imgPath, file2save, silentMode) {
    oBitmap := LoadBitmapFromFileu(imgPath)
    If !oBitmap
       Return -3

    Gdip_GetImageDimensions(oBitmap, oImgW, oImgH)
    pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
    kBitmap := AutoCropAction(oBitmap, usrAutoCropColorTolerance, usrAutoCropImgThreshold, silentMode, 1)
    Gdip_DisposeImage(oBitmap, 1)
    If !kBitmap
       Return -1

    Gdip_GetImageDimensions(kBitmap, imgW, imgH)
    If (imgW>oImgW-1) && (imgH>oImgH-1)
       Return -2

    If InStr(pixFmt, "argb")
    {
       isUniform := Gdip_TestBitmapUniformity(kBitmap, 7, maxLevelIndex)
       If (isUniform=1 && (valueBetween(maxLevelIndex, 0, 5) || valueBetween(maxLevelIndex, 250, 255)))
          Gdip_BitmapSetColorDepth(kBitmap, 24)
    } Else Gdip_BitmapSetColorDepth(kBitmap, 24)

    If FileExist(file2save)
    {
       Try FileSetAttrib, -R, % file2save
       Sleep, 1
    }

    r := Gdip_SaveBitmapToFile(kBitmap, file2save, 90)
    If (r=-2 || r=-1)
       r := SaveFIMfile(file2save, kBitmap)

    Gdip_DisposeImage(kBitmap, 1)
    Return r
}

batchAutoCropFiles() {
   filesElected := getSelectedFiles()
   If (filesElected>80)
   {
      msgInfos := "Are you sure you want to crop " filesElected " files? The auto-crop algorithm may take some time to finish going through all of them. Hold ESC to abandon it."
      triggerOwnDialogs()
      MsgBox, 52, %appTitle%, %msgInfos%
      IfMsgBox, Yes
        good2go := 1
   } Else good2go := 1
 
   If (good2go!=1)
      Return

   If AnyWindowOpen
      CloseWindow()
   Sleep, 25
   showTOOLtip("Performing image auto-crop on " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   countFilez := countTFilez := 0
   Loop, % filesElected
   {
      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }

      thisFileIndex := getSelectedFiles(A_Index)
      imgPath := resultedFilesList[thisFileIndex]
      imgPath := StrReplace(imgPath, "||")
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Performing image auto-crop on " countFilez "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If (!RegExMatch(imgPath, saveTypesRegEX) || StrLen(imgPath)<2)
         Continue

      If (ResizeUseDestDir=1)
      {
         zPlitPath(imgPath, 0, OutFileName, OutDir)
         destImgPath := ResizeDestFolder "\" OutFileName
         If FileExist(destImgPath)
         {
            MD5name := generateThumbName(imgPath, 1)
            destImgPath := ResizeDestFolder "\" MD5name "-" OutFileName
         }
      } Else destImgPath := imgPath

      countTFilez++
      changeMcursor()
      r := coreAutoCropFileProcessing(imgPath, destImgPath, 0)
      If !r
         countFilez++
      Else
         someErrors := "`nErrors occured during file operations..."
   }

   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   prevStartIndex := -1
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. " countFilez " out of " filesElected " selected files were processed until now..." someErrors)
   } Else
   {
      SoundBeep, 900, 100
      showTOOLtip(countFilez " out of " countTFilez " selected images were automatically cropped" someErrors)
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

BTNautoCropRealtime() {
  Static wasAutoCropped := 0

  GuiControl, SettingsGUIA: Disable, mainBtnACT
  SetTimer, reactivateMainBtnACT, -350
  If (AnyWindowOpen=17)
     UpdateAutoCropParams()
  Else If (AnyWindowOpen=12)
     usrAutoCropGenerateSelection := 1

  If (usrAutoCropGenerateSelection=0)
  {
     activateImgSelection := editingSelectionNow := 0
     wasAutoCropped := performAutoCropNow := 1
     RefreshImageFile()
  } Else
  {
     resultu := resultedFilesList[currentFileIndex]
     If FileExist(resultu)
     {
        thumbBMP := LoadBitmapFromFileu(resultu)
        FlipImgV := FlipImgH := vpIMGrotation := performAutoCropNow := 0
        If thumbBMP
        {
           AutoCropAction(thumbBMP, usrAutoCropColorTolerance, usrAutoCropImgThreshold)
           Gdip_DisposeImage(thumbBMP, 1)
        }

        activateImgSelection := performAutoCropNow := 1
        If (wasAutoCropped=0)
           dummyTimerDelayiedImageDisplay(50)
        Else
           RefreshImageFile()
     }
  }

  If (AnyWindowOpen=17)
  {
     captureImgCorners(gdiBitmap)
  } Else If (activateImgSelection=1 && AnyWindowOpen=12)
  {
     GuiControl, SettingsGUIA: Enable, jpegDoCrop
     GuiControl, SettingsGUIA: , jpegDoCrop, 1
  }
}

coreGdipRotateFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor) {
    Static imgOrientOpt := {"i000":0, "i100":1, "i200":2, "i300":3, "i010":4, "i110":5, "i210":6, "i310":7, "i001":6, "i101":7, "i201":4, "i301":5, "i011":2, "i111":3, "i211":0, "i311":1}
    oBitmap := LoadBitmapFromFileu(imgPath)
    If !oBitmap
       Return -2

    If (SimpleOperationsDoCrop=1 && activateImgSelection=1)
    {
       pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
       newPixFmt := InStr(pixFmt, "argb") ? "0x26200A" : "0x21808"   ; 32-bits // 24-bits
       Gdip_GetImageDimensions(oBitmap, imgW, imgH)
       If (relativeImgSelCoords=1 && activateImgSelection=1)
          calcRelativeSelCoords(oBitmap, imgW, imgH)

       calcImgSelection2bmp(imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       zBitmap := Gdip_CloneBitmapArea(oBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH, newPixFmt)
       If zBitmap
       {
          Gdip_DisposeImage(oBitmap, 1)
          oBitmap := zBitmap
       }
    }

    imgFoperation := (rotateAngle=90) ? 1 : 0
    imgFoperation := (rotateAngle=180) ? 2 : imgFoperation
    imgFoperation := (rotateAngle=270) ? 3 : imgFoperation
    imgFoperation := imgOrientOpt["i" imgFoperation SimpleOperationsFlipH SimpleOperationsFlipV]

    If (imgFoperation>0)
       Gdip_ImageRotateFlip(oBitmap, imgFoperation)

    If FileExist(file2save)
    {
       Try FileSetAttrib, -R, % file2save
       Sleep, 1
    }

    If (scaleImgFactor>0 && scaleImgFactor!=1)
    {
       Gdip_GetImageDimensions(oBitmap, imgW, imgH)
       pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
       newPixFmt := InStr(pixFmt, "argb") ? "0x26200A" : "0x21808"   ; 32-bits // 24-bits
       resizeFilter := (ResizeQualityHigh=1) ? 7 : 3
       zBitmap := Gdip_ResizeBitmap(oBitmap, Round(imgW*scaleImgFactor), Round(imgH*scaleImgFactor), 0, resizeFilter, newPixFmt)
       If zBitmap
       {
          Gdip_DisposeImage(oBitmap, 1)
          oBitmap := zBitmap
       }
    }

    r := Gdip_SaveBitmapToFile(oBitmap, file2save, 90)
    If (r=-2 || r=-1)
       r := SaveFIMfile(file2save, oBitmap)

    Gdip_DisposeImage(oBitmap, 1)
    Return r
}

coreSimpleFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor) {
  If (RegExMatch(imgPath, RegExFIMformPtrn) || (RegExMatch(imgPath, "i)(.\.(png|tiff|tif))$") && (wasInitFIMlib=1)))
     r := coreFreeImgRotateFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor)
  Else
     r := coreGdipRotateFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor)
  Return r
}

coreFreeImgRotateFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor) {
    hFIFimgA := FreeImage_Load(imgPath, -1)
    If !hFIFimgA
       Return -1

    If (SimpleOperationsDoCrop=1 && activateImgSelection=1)
    {
       FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
       If (relativeImgSelCoords=1 && activateImgSelection=1)
          calcRelativeSelCoords(hFIFimgA, imgW, imgH)

       calcImgSelection2bmp(imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       x1 := Round(X1), y1 := Round(Y1)
       x2 := Round(X2), y2 := Round(Y2)
       changeMcursor()
       hFIFimgB := FreeImage_Copy(hFIFimgA, X1, Y1, X2, Y2)
       If hFIFimgB
       {
          FreeImage_UnLoad(hFIFimgA)
          hFIFimgA := hFIFimgB
       }
    }

    If (rotateAngle>0)
    {
       changeMcursor()
       hFIFimgB := FreeImage_Rotate(hFIFimgA, rotateAngle)
       If hFIFimgB
       {
          FreeImage_UnLoad(hFIFimgA)
          hFIFimgA := hFIFimgB
       }
    }

    If (SimpleOperationsFlipH=1)
       FreeImage_FlipHorizontal(hFIFimgA)
    If (SimpleOperationsFlipV=1)
       FreeImage_FlipVertical(hFIFimgA)

    If (scaleImgFactor>0 && scaleImgFactor!=1)
    {
       FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
       resizeFilter := (ResizeQualityHigh=1) ? 1 : 4
       changeMcursor()
       hFIFimgB := FreeImage_Rescale(hFIFimgA, Round(imgW*scaleImgFactor), Round(imgH*scaleImgFactor), resizeFilter)
       If hFIFimgB
       {
          FreeImage_UnLoad(hFIFimgA)
          hFIFimgA := hFIFimgB
       }
    }

    If FileExist(file2save)
    {
       Try FileSetAttrib, -R, % file2save
       Sleep, 0
       FileMove, % file2save, % file2save "-tmp"
       Sleep, 0
    }

    changeMcursor()
    r := FreeImage_Save(hFIFimgA, file2save)
    FreeImage_UnLoad(hFIFimgA)

    If !r
    {
       FileDelete, % file2save
       Sleep, 0
       FileMove, % file2save "-tmp", % file2save
    } Else FileDelete, % file2save "-tmp"

    Return !r
}

SimpleResizeRotatePanel() {
    Global mainBtnACT, btnFldr
    If !PanelsCheckFileExists()
       Return

    If (vpIMGrotation>0)
    {
       FlipImgV := FlipImgH := vpIMGrotation := 0
       showTOOLtip("Image rotation: 0°")
       RefreshImageFile()
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Sleep, 250
    } Else If (FlipImgH=1 || FlipImgV=1)
    {
       FlipImgV := FlipImgH := 0
       dummyTimerDelayiedImageDisplay(50)
    } 

    imgPath := resultedFilesList[currentFileIndex]
    filesElected := getSelectedFiles(0, 1)
    thisRegEX := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
    If (!filesElected && !RegExMatch(imgPath, thisRegEX) && !AnyWindowOpen)
    {
       CloseWindow()
       Sleep, 5
       ResizeImagePanelWindow()
       Return
    }

    createSettingsGUI(18)
    btnWid := 100
    txtWid := slideWid := 280
    If (activateImgSelection!=1)
       SimpleOperationsDoCrop := 0

    If (PrefsLargeFonts=1)
    {
       slideWid := slideWid + 135
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       Gui, Font, s%LargeUIfontValue%
    }

    Gui, Add, Text, x15 y15 Section, Rotate:
    Gui, Add, DropDownList, x+5 w100 vSimpleOperationsRotateAngle, 0°|90°|180°|-90° [270°]|%SimpleOperationsRotateAngle%||
    Gui, Add, Text, x+10, Scale:
    Gui, Add, ComboBox, x+5 w100 vSimpleOperationsScaleImgFactor, 5 `%|10 `%|20 `%|50 `%|75 `%|100 `%|200 `%|500 `%|950 `%|%SimpleOperationsScaleImgFactor%||
    Gui, Add, Text, xs y+10, Image flip/mirror:
    Gui, Add, Checkbox, x+5 Checked%SimpleOperationsFlipV% vSimpleOperationsFlipV, Vertical
    Gui, Add, Checkbox, x+5 Checked%SimpleOperationsFlipH% vSimpleOperationsFlipH, Horizontal
    Gui, Add, Checkbox, xs y+10 Checked%SimpleOperationsDoCrop% vSimpleOperationsDoCrop, Crop image(s) to selected area
    Gui, Add, Checkbox, xs y+10 Checked%ResizeQualityHigh% vResizeQualityHigh, High quality image resampling
    Gui, Add, Checkbox, xs y+15 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file(s) in the following folder
    Gui, Add, Edit, xp+15 y+5 wp r1 +0x0800 -wrap vResizeDestFolder, % ResizeDestFolder
    Gui, Add, Button, x+5 hp w90 gBTNchangeResizeDestFolder vbtnFldr, C&hoose

    If !ResizeUseDestDir
    {
       GuiControl, Disable, btnFldr
       GuiControl, Disable, ResizeDestFolder
    }


    ; Gui, Add, Checkbox, xs y+10 Checked%SimpleOperationsNoPromptOnSave% vSimpleOperationsNoPromptOnSave, Do not prompt on file save
    If (activateImgSelection!=1)
       GuiControl, Disable, SimpleOperationsDoCrop

    If (filesElected>1)
    {
       msgFriendly := filesElected " files are selected for processing."
       Gui, Font, Bold
       Gui, Add, Text, xs y+20 w%txtWid%, % msgFriendly
       Gui, Font, Normal
       Gui, Add, Text, xs y+10 w%txtWid%, Files in unsupported write formats will be skipped.
    }

    If (filesElected<2)
    {
       Gui, Add, Button, xs+0 y+25 h30 w35 gPreviousPicture, <<
       Gui, Add, Button, x+5 hp wp gNextPicture, >>
       Gui, Add, Button, x+5 hp w%btnWid% Default gBtnSaveNowSimpleProcessing vmainBtnACT, &Save image
       Gui, Add, Button, x+5 hp w%btnWid% gBtnSaveAsSimpleProcessing, &Browse to save...
    } Else
       Gui, Add, Button, xs+0 y+20 h30 wp Default gBtnPerformSimpleProcessing, &Perform operations on the files

    Gui, Add, Button, xs y+5 h30 w%btnWid% gResizeImagePanelWindow, &Advanced mode
    Gui, Add, Button, x+5 hp w80 gResizePanelHelpBoxInfo, &Help
    Gui, Add, Button, x+5 hp wp gCloseWindow, &Cancel
    Gui, SettingsGUIA: Show, AutoSize, Resize/crop/rotate image [simple]: %appTitle%
}

BtnSaveAsSimpleProcessing() {
    SimpleOperationsNoPromptOnSave := 0
    BtnPerformSimpleProcessing()
}

BtnSaveNowSimpleProcessing() {
    SimpleOperationsNoPromptOnSave := 1
    BtnPerformSimpleProcessing()
}

BtnPerformSimpleProcessing() {
    GuiControlGet, SimpleOperationsFlipV
    GuiControlGet, SimpleOperationsFlipH
    GuiControlGet, SimpleOperationsDoCrop
    GuiControlGet, SimpleOperationsRotateAngle
    GuiControlGet, SimpleOperationsScaleImgFactor
    GuiControlGet, ResizeQualityHigh
    GuiControlGet, ResizeDestFolder
    GuiControlGet, ResizeUseDestDir

    rotateAngle := StrReplace(SimpleOperationsRotateAngle, "°")
    rotateAngle := StrReplace(rotateAngle, A_Space)
    scaleImgFactor := StrReplace(SimpleOperationsScaleImgFactor, "%")
    scaleImgFactor := StrReplace(scaleImgFactor, A_Space)
    scaleImgFactor := StrReplace(scaleImgFactor, ",", ".")
    scaleImgFactor := Round(scaleImgFactor)/100

    initFIMGmodule()
    If (scaleImgFactor=1 || scaleImgFactor<0 || !scaleImgFactor) && (rotateAngle=0 && SimpleOperationsFlipV=0 && SimpleOperationsFlipH=0 && SimpleOperationsDoCrop=0)
    {
        writeMainSettings()
        SoundBeep, 900, 100
        Msgbox, 48, %appTitle%, WARNING: No image transformations selected...
        Return
    }

    filesElected := getSelectedFiles()
    If (filesElected>1)
    {
       batchSimpleProcessing(rotateAngle, scaleImgFactor)
       Return
    }

    imgPath := resultedFilesList[currentFileIndex]
    thisRegEX := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
    If (!filesElected && !RegExMatch(imgPath, thisRegEX))
    {
       Msgbox, 48, %appTitle%, ERROR: This file format cannot be processed in «Simple mode». Please use the «Advanced mode» which allows file format conversions.
       Return
    }

   zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
   startPath := (ResizeUseDestDir=1) ? ResizeDestFolder "\" OutFileName : imgPath
   If (SimpleOperationsNoPromptOnSave=1)
   {
      ErrorLevel := 0
      file2save := imgPath
   } Else
   {
      triggerOwnDialogs()
      FileSelectFile, file2save, S18, % startPath, Save processed image as..., Images (*.%oExt%)
   }

   If (!ErrorLevel && StrLen(file2save)>3)
   {
      zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
      zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, nExt)
      If !nExt
         file2save .= "." oExt

      If !RegExMatch(file2save, thisRegEX)
      {
         SoundBeep, 300, 100
         If (SimpleOperationsNoPromptOnSave!=1)
            Msgbox, 48, %appTitle%, ERROR: Please use a supported file format. Allowed formats: .EXR, .HDR, .PFM, %saveTypesFriendly%.
         Else
            Msgbox, 48, %appTitle%, ERROR: Unsupported file write format. Please choose an allowed format: .EXR, .HDR, .PFM, %saveTypesFriendly%.
         Return
      }

      If (nExt!=oExt && StrLen(nExt)>0)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: You cannot change the file format from .%oExt% to .%nExt%. For this, please use the «Advanced mode».
         Return
      }

      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: This format is currently unsupported. The FreeImage library failed to properly initialize.`n`n%OutFileName%
         Return
      }

      GuiControl, SettingsGUIA: Disable, mainBtnACT
      SetTimer, reactivateMainBtnACT, -950
      r := coreSimpleFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor)
      If r
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: Unable to save file. Error code: %r%.`n`n%OutFileName%
         Return
      }

      If (ResizeUseDestDir=1)
         prevFileSavePath := ResizeDestFolder

      writeMainSettings()
      SoundBeep, 900, 100
      showTOOLtip("Processed image saved...")
      If (SimpleOperationsNoPromptOnSave=1)
         SetTimer, RefreshImageFile, -150
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

batchSimpleProcessing(rotateAngle, scaleImgFactor) {
   If AnyWindowOpen
      CloseWindow()

   filesElected := getSelectedFiles()
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   imageLoading := 1
   showTOOLtip("Processing " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   thisRegEX := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
   countTFilez := filesConverted := 0
   Loop, % filesElected
   {
      thisFileIndex := getSelectedFiles(A_Index)
      imgPath := resultedFilesList[thisFileIndex]
      If !RegExMatch(imgPath, thisRegEX)
         Continue

      countTFilez++
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Processing " countTFilez "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If (GetKeyState("Esc", "P") && identifyThisWin()) || (mustAbandonCurrentOperations=1)
      {
         lastLongOperationAbort := A_TickCount
         executingCanceableOperation := mustAbandonCurrentOperations := 0
         abandonAll := 1
         Break
      }

      imgPath := StrReplace(imgPath, "||")
      zPlitPath(imgPath, 0, OutFileName, OutDir)

      destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
      file2save := destImgPath "\" OutFileName

      r := coreSimpleFileProcessing(imgPath, file2save, rotateAngle, scaleImgFactor)
      If r
         someErrors := "`nErrors occured during file operations..."
      Else filesConverted++

      If pBitmap
         Gdip_DisposeImage(pBitmap, 1)
   }
   executingCanceableOperation := 0
   CurrentSLD := backCurrentSLD
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   thumbSelFileList := ""
   imageLoading := 0
   prevStartIndex := -1
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. "  filesConverted " out of " filesElected " selected files were processed." someErrors)
      SoundBeep , 300, 100
   } Else
   {
      showTOOLtip("Finished processing " filesConverted " out of " filesElected " selected files" someErrors)
      SoundBeep , 900, 100
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}



