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
; Display images and creates slideshows using GDI+ and FreeImage
; 85 supported image formats: jpeg, jpg, bmp, png, gif, tif, emf
; hdr, exr, webp, raw and many more...
;
; Original Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
;___________ Auto Execute Section ____

;@Ahk2Exe-AddResource LIB Lib\module-interface.ahk
;@Ahk2Exe-AddResource LIB Lib\module-fim-thumbs.ahk
;@Ahk2Exe-SetName Quick Picto Viewer
;@Ahk2Exe-SetDescription Quick Picto Viewer
;@Ahk2Exe-SetVersion 4.0.0
;@Ahk2Exe-SetCopyright Marius Şucan (2019)
;@Ahk2Exe-SetCompanyName marius.sucan.ro
;@Ahk2Exe-SetMainIcon quick-picto-viewer.ico

#NoEnv
#NoTrayIcon
#MaxHotkeysPerInterval, 500
#MaxThreads, 255
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#MaxMem, 9924
#IfTimeout, 35
#SingleInstance, off
#UseHook, Off
#Include Lib\Gdip_All.ahk
#Include Lib\freeimage.ahk
#Include Lib\MCI.ahk
#Include Lib\Class_SQLiteDB.ahk
SetWorkingDir, %A_ScriptDir%

SetWinDelay, 1
SetBatchLines, -1

Global PVhwnd := 1, hGDIwin := 1, hGDIthumbsWin := 1, pPen4
   , glPG, glOBM, glHbitmap, glHDC, pPen1, pPen1d, pPen2, pPen3, AmbientalTexBrush
   , pBrushHatch, pBrushWinBGR, pBrushA, pBrushB, pBrushC, pBrushD, currentPixFmt
   , pBrushE, pBrushHatchLow, hGuiTip := 1, hSetWinGui := 1
   , editDummy, prevFullThumbsUpdate := 1, winGDIcreated := 0, ThumbsWinGDIcreated := 0
   , hPicOnGui1, scriptStartTime := A_TickCount, lastEditRHChange :=1
   , newStaticFoldersListCache := "", lastEditRWChange := 1
   , mainCompiledPath := "", wasInitFIMlib := 0, hGDIselectWin
   , filteredMap2mainList := [], thumbsCacheFolder := A_ScriptDir "\thumbs-cache"
   , resultedFilesList := [], currentFileIndex := "", maxFilesIndex := 0
   , appTitle := "Quick Picto Viewer", FirstRun := 1, hSNDmediaFile
   , bckpResultedFilesList := [], bkcpMaxFilesIndex := 0
   , DynamicFoldersList := "", animGIFplaying := 0, startPageIndex := 0
   , RandyIMGids := [], SLDhasFiles := 0, IMGlargerViewPort := 0
   , IMGdecalageY := 1, IMGdecalageX := 1, imgQuality, usrFilesFilteru := ""
   , RandyIMGnow := 0, GDIPToken, gdiBitmapSmall, hSNDmedia, imgIndexEditing := 0
   , AprevGdiBitmap, BprevGdiBitmap, msgDisplayTime := 3000, gdiBitmapIDcall
   , slideShowRunning := 0, CurrentSLD := "", markedSelectFile := 0
   , ResolutionWidth, ResolutionHeight, prevStartIndex := 1, mustReloadThumbsList := 0
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
   , PasteFntSize := 35, OSDfntSize := 25, OSDFontName := "Arial", prevOpenFolderPath := ""
   , mustGenerateStaticFolders := 1, lastWinDrag := 1, img2resizePath := ""
   , prevFileMovePath := "", lastGIFdestroy := 1, prevAnimGIFwas := ""
   , thumbsW := 300, thumbsH := 300, thumbsDisplaying := 0, scrollAxis := 0
   , othumbsW := 300, othumbsH := 300, ForceRegenStaticFolders := 0, vPselRotation := 0
   , CountFilesFolderzList := 0, RecursiveStaticRescan := 0, imgSelLargerViewPort := 0
   , UsrMustInvertFilter := 0, overwriteConflictingFile := 0, LastPrevFastDisplay := 0
   , prevFileSavePath := "", imgHUDbaseUnit := Round(OSDfntSize*2.5), lastLongOperationAbort := 1
   , lastOtherWinClose := 1, UsrCopyMoveOperation := 2, editingSelectionNow := 0
   , ForceNoColorMatrix := 0, activateImgSelection := 0, prevFastDisplay := 1, hSNDmediaDuration
   , imgSelX1 := 0, imgSelY1 := 0, imgSelX2 := -1, imgSelY2 := -1, adjustNowSel := 0
   , prevImgSelX1 := 0, prevImgSelY1 := 0, prevImgSelX2 := -1, prevImgSelY2 := -1
   , selDotX, selDotY, selDotAx, selDotAy, selDotBx, selDotBy, selDotCx, selDotCy, selDotDx, selDotDy
   , prcSelX1, prcSelX2, prcSelY1, prcSelY2, PannedFastDisplay := 1, pBrushF
   , SelDotsSize := imgHUDbaseUnit//4, ViewPortBMPcache, startZeitIMGload
   , imageLoading := 0, PrevGuiSizeEvent := 0, imgSelOutViewPort := 0, prevGUIresize := 1
   , imgEditPanelOpened := 0, remCacheOldDays := 0, jpegDoCrop := 0, jpegDesiredOperation := 1
   , rDesireWriteFMT := "jpg", FIMfailed2init := 0, prevMaxSelX, prevMaxSelY, prevDestPosX, prevDestPosY
   , hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
   , CCLVO := "-E0x200 +Border -Hdr -Multi +ReadOnly Report AltSubmit gSetUIcolors", FontList := []
   , totalFramesIndex, pVwinTitle, AprevImgCall, BprevImgCall, prevSetWinPosX, prevSetWinPosY
   , FIMimgBPP, FIMformat, coreIMGzeitLoad, desiredFrameIndex := 0, prevDrawingMode := 0
   , diffIMGdecX := 0, diffIMGdecY := 0, prevGDIvpCache, oldZoomLevel := 0, fullPath2exe, hasMemThumbsCached := 0
   , hitTestSelectionPath, scrollBarHy := 0, scrollBarVx := 0, HistogramBMP, internalColorDepth := 0
   , drawModeBzeit := 1, drawModeAzeit := 1, drawModeCzeit := 1, prevColorAdjustZeit := 1, AutoCropBordersSize := 15
   , GDIfadeVPcache, executingCanceableOperation := 1, hCropCornersPic, UserMemBMP, userSearchString
   , systemCores := 1, realSystemCores := 1, hasInitSpecialMode := 0, CountGIFframes := 0, prevSlideShowStop := 1
   , prevTryThumbsUpdate := 1, thumbsSizeQuality := 245, prevFullIndexThumbsUpdate := -1, userClipBMPpaste, viewportStampBMP
   , ThumbsStatusBarH := 0, activeSQLdb, SLDtypeLoaded := 0, sldsPattern := "i)(.\.(sld|sldb))$"
   , imgThumbsCacheIDsArray := [], imgThumbsCacheArray := [], prevRealThumbsIndex := 1
   , GDIcacheSRCfileA, idGDIcacheSRCfileA, GDIcacheSRCfileB, idGDIcacheSRCfileB, prevOpenedWindow := []
   , startLongOperation := 1, thisIMGisDownScaled := 0, simpleOpRotationAngle := 1
   , simpleOPimgScaleFactor := 1, runningLongOperation := 0, externalThreadsArray := []
   , 2NDglHbitmap, 2NDglHDC, 2NDglOBM, 2NDglPG, mainThreadHwnd, imgDecLX, imgDecLY, hGDIinfosWin
   , QPVregEntry := "HKEY_CURRENT_USER\SOFTWARE\Quick Picto Viewer"
   , appVersion := "4.0.8", vReleaseDate := "10/02/2020"

 ; User settings
   , askDeleteFiles := 1, enableThumbsCaching := 1, OnConvertKeepOriginals := 1, userOverwriteFiles := 0
   , thumbsAratio := 3, thumbsZoomLevel := 1, zatAdjust := 0
   , WindowBgrColor := "010101", slideShowDelay := 3000, userMultiDelChoice := 2
   , IMGresizingMode := 1, SlideHowMode := 1, TouchScreenMode := 1
   , lumosAdjust := 1, GammosAdjust := 0, userimgQuality := 0
   , imgFxMode := 1, FlipImgH := 0, FlipImgV := 0, satAdjust := 1
   , imageAligned := 5, filesFilter := "", isAlwaysOnTop := 0
   , noTooltipMSGs := 0, zoomLevel := 1, skipDeadFiles := 0, userHQraw  := 0
   , isTitleBarHidden := 1, lumosGrayAdjust := 0, GammosGrayAdjust := 0
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
   , SimpleOperationsDoCrop := 0, SimpleOperationsRotateAngle := 1, SimpleOperationsScaleImgFactor := "100 %"
   , SimpleOperationsNoPromptOnSave := 0, SimpleOperationsFlipV := 0, SimpleOperationsFlipH := 0, doSlidesTransitions := 0
   , usrAutoCropDeviationPixels := 0, multilineStatusBar := 0, AutoCropAdaptiveMode := 1, allowGIFsPlayEntirely := 0
   , allowMultiCoreMode := 1, AutoDownScaleIMGs := 0, minimizeMemUsage := 0, GIFspeedDelay := 35
   , maxUserThreads := 30, maxMemThumbsCache := 300, resetImageViewOnChange := 0, FillAreaRemBGR := 0
   , FillAreaDoContour := 0, FillAreaContourThickness := 20, EraseAreaFader := 0, EraseAreaOpacity := 190
   , FillAreaOpacity := 250, FillAreaColor := OSDbgrColor, FillAreaShape := 1, FillAreaInverted := 0, FillAreaAngle := 0
   , FillAreaRoundedCaps := 1, FillAreaDoubleLine := 0, postSharpenAmount := 95, postSharpenRadius := 10
   , PasteInPlaceCentered := 1, PasteInPlaceOpacity := 255, PasteInPlaceMode := 1, PasteInPlaceQuality := 1, PasteInPlaceAngle := 0
   , PasteInPlaceOrientation := 1, showImgAnnotations := 0, mustApplySharpen := 0, blurAreaSoftEdges := 1, blurAreaInverted := 0
   , PasteInPlaceBlurAmount := 0, blurAreaOpacity := 250, blurAreaAmount := 10

Global PasteInPlaceGamma := 1, PasteInPlaceSaturation := 0, PasteInPlaceHue := 0, PasteInPlaceLight := 0
   , RotateAreaOpacity := 255, RotateAreaAngle := 45, RotateAreaWithinBounds := 0, thumbnailsListMode := 0
   , RotateAreaRemBgr := 1, RotateAreaQuality := 1, showSelectionGrid := 0, blurAreaTwice := 0, invertAreaOpacity := 255
   , EllipseSelectMode := 0, thumbsListViewMode := 1, FillAreaContourAlign := 2, FillAreaDashStyle := 1
   , adjustCanvasCentered := 1, adjustCanvasMode := 1, adjustCanvasNoBgr := 1, LimitSelectBoundsImg := 1
   , DrawLineAreaColor, DrawLineAreaDashStyle := 1, DrawLineAreaContourAlign := 1, DrawLineAreaAngle := 0
   , DrawLineAreaContourThickness := 20, DrawLineAreaOpacity := 255, DrawLineAreaBorderTop := 1, DrawLineAreaBorderBottom
   , DrawLineAreaBorderLeft, DrawLineAreaBorderRight, DrawLineAreaBorderCenter := 1, DrawLineAreaBorderArcA, DrawLineAreaBorderArcB
   , DrawLineAreaBorderArcC, DrawLineAreaBorderArcD, DrawLineAreaCapsStyle := 1, DrawLineAreaDoubles := 0
   , EraseAreaIgnoreRotation := 0, PasteInPlaceIgnoreRotation := 0

EnvGet, realSystemCores, NUMBER_OF_PROCESSORS
If (realSystemCores>100)
   realSystemCores := 100

RegRead, InitCheckReg, %QPVregEntry%, Running
RegRead, InitTimeReg, %QPVregEntry%, LastStartTime
If (Abs(A_TickCount - InitTimeReg)<600 && IsNumber(InitTimeReg) && InitCheckReg=1 && InitTimeReg>1)
{
   hasInitSpecialMode := 1
   ForceExitNow()
   ExitApp
}

If !A_IsCompiled
   Try Menu, Tray, Icon, quick-picto-viewer.ico

DetectHiddenWindows, On
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen
OnExit, doCleanup

If A_IsCompiled
   initCompiled()

thisGDIPversion := Gdip_LibrarySubVersion()
GDIPToken := Gdip_Startup()
If (!GDIPToken || thisGDIPversion<1.78)
{
   MsgBox, 48, %appTitle%, ERROR: Unable to initialize GDI+...`n`nThe program will now exit.`n`nRequired GDI+ library wrapper: v1.78 - extended compilation edition.
   hasInitSpecialMode := 1
   ForceExitNow()
   ExitApp
}

; RegRead, initArgu, %QPVregEntry%, initArgu
If (InitCheckReg=2)
{
   initExternalCoreMode()
   Return
}

RegWrite, REG_SZ, %QPVregEntry%, Running, 1
RegWrite, REG_SZ, %QPVregEntry%, LastStartTime, % A_TickCount
IniRead, FirstRun, % mainSettingsFile, General, FirstRun, @
If (FirstRun!=0)
{
   writeMainSettings()
   FirstRun := 0
   IniWrite, % FirstRun, % mainSettingsFile, General, FirstRun
} Else loadMainSettings()

Loop, 9
    OnMessage(255+A_Index, "PreventKeyPressBeep")   ; 0x100 to 0x108

Global interfaceThread
If !A_IsCompiled
   interfaceThread := ahkthread("#Include *i Lib\module-interface.ahk")
Else If (sz := GetRes(data, 0, "MODULE-INTERFACE.AHK", "LIB"))
   interfaceThread := ahkThread(StrGet(&data, sz, "utf-8"))

initGUI := interfaceThread.ahkFunction("BuildGUI")
If !initGUI
{
   MsgBox, 48, %appTitle%, ERROR: Unable to initialize the interface. The application will now exit...
   hasInitSpecialMode := 1
   ForceExitNow()
   Return
}

; BuildTray()
; BuildGUI()
InitStuff()

Loop, 6
{
   If (A_Index=6)
   {
      doWelcomeNow := 1
   } Else If RegExMatch(A_Args[A_Index], sldsPattern)
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

Global multiCoreThumbsInitGood := "n", thumbThread1,thumbThread2,thumbThread3,thumbThread4,thumbThread5,thumbThread6,thumbThread7,thumbThread8,thumbThread9,thumbThread10,thumbThread11
,thumbThread12,thumbThread13,thumbThread14,thumbThread15,thumbThread16,thumbThread17,thumbThread18,thumbThread19,thumbThread20,thumbThread21
,thumbThread22,thumbThread23,thumbThread24,thumbThread25,thumbThread26,thumbThread27,thumbThread28,thumbThread29,thumbThread30,thumbThread31
,thumbThread32,thumbThread33,thumbThread34,thumbThread35,thumbThread36,thumbThread37,thumbThread38,thumbThread39,thumbThread40,thumbThread41
,thumbThread42,thumbThread43,thumbThread44,thumbThread45,thumbThread46,thumbThread47,thumbThread48,thumbThread49,thumbThread50,thumbThread51
,thumbThread52,thumbThread53,thumbThread54,thumbThread55,thumbThread56,thumbThread57,thumbThread58,thumbThread59,thumbThread60,thumbThread61
,thumbThread62,thumbThread63,thumbThread64,thumbThread65,thumbThread66,thumbThread67,thumbThread68,thumbThread69,thumbThread70,thumbThread71
,thumbThread72,thumbThread73,thumbThread74,thumbThread75,thumbThread76,thumbThread77,thumbThread78,thumbThread79,thumbThread80,thumbThread81
,thumbThread82,thumbThread83,thumbThread84,thumbThread85,thumbThread86,thumbThread87,thumbThread88,thumbThread89,thumbThread90,thumbThread91
,thumbThread92,thumbThread93,thumbThread94,thumbThread95,thumbThread96,thumbThread97,thumbThread98,thumbThread99,thumbThread100,

; MsgBox, % A_TickCount - scriptStartTime
If (doWelcomeNow=1)
   SetTimer, drawWelcomeImg, -25

Return

;_____________________________________ Hotkeys _________________

identifyThisWin(noReact:=0) {
  Static prevR, lastInvoked := 1
  If (A_TickCount - lastInvoked < 60)
     Return prevR

  A := WinExist("A")
  If (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin || A=hGDIinfosWin)
     prevR := 1
  Else prevR := 0

  Return prevR
}

#If (identifyThisWin()=1)
    ^vk4F::    ; Ctrl+O
       OpenDialogFiles()
    Return

    w::   ; todo
       testResourcesMemoryLeaks()

      ; SaveDBfilesList()
    Return

    ^vk4E::    ; Ctrl+N
       If A_IsCompiled
          Run, "%fullPath2exe%"
       Else
          Run, "%A_ScriptFullPath%"
    Return

    F12::      ; Ctrl+P
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

    ^NumpadAdd::
    ^vkBB::    ; [=]
       changeOSDfontSize(1)
    Return

    ^NumpadSub::
    ^vkBD::   ; [-]
       changeOSDfontSize(-1)
    Return

    +vk4F::    ; Shift+O
       OpenFolders()
    Return

    ~F10::
    ~+F10::
    ~!F10::
    ^AppsKey::
    +AppsKey::
    #AppsKey::
    !AppsKey::
    AppsKey::
       Suspend, Permit
       InitGuiContextMenu()
    Return

    ~Insert Up::
       If AnyWindowOpen
          Return

       If (imageLoading!=1)
          addNewFile2list()
    Return

    ^vk56 Up::   ; Ctrl+V
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

#If (identifyThisWin()=1 && !AnyWindowOpen && currentFileIndex=0 && !CurrentSLD)
    ~vk44 Up::   ; D
      toggleImgSelection()
    Return

    +^vk56 Up::   ; Ctrl+Shift+V
       If (imageLoading!=1)
          PanelPasteInPlace()
    Return

    ~^vk44 Up::   ; Ctrl+D
       resetImgSelection()
    Return

    ~^vk43 Up::    ; Ctrl+C
       CopyImage2clip()
    Return

    ~vk45::   ; E
      ToggleEditImgSelection()
    Return

    ~+vk45 Up::   ; Shift+E
      toggleEllipseSelection()
    Return

    ~^vk53 Up::   ; Ctrl+S
       SaveClipboardImage()
    Return

    +Enter::
       CropImageViewPort()
    Return

    ~!BackSpace::
       PanelFillSelectedArea()
    Return


    ~vk59 Up::   ; Y
      PanelImgAutoCrop()
    Return

    ~vk49::   ; I
      If (thumbsDisplaying!=1)
         ToggleInfoBoxu()
      Else
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

    ~+vk48::    ; Shift+H
       ToggleImgHistogram()
    Return

    ~vk52 Up::     ; R
       makeSquareSelection()
    Return

    +vk42 Up::     ; Shift+B
       PanelBlurSelectedArea()
    Return

    ^vk54 Up::     ; Ctrl+T
       PanelTransformSelectedArea()
    Return

    +vk49 Up::     ; Shift+I
       InvertSelectedArea()
    Return

    +vk47 Up::     ; Shift+G
       GraySelectedArea()
    Return

    ~vk48::    ; H
       If (activateImgSelection=1 && editingSelectionNow=1) || (StrLen(UserMemBMP)>4 && activateImgSelection=1)
          FlipSelectedArea("h")
       Else
          TransformIMGh()
    Return

   ~vk56::    ; V
       If (activateImgSelection=1 && editingSelectionNow=1) || (StrLen(UserMemBMP)>4 && activateImgSelection=1)
          FlipSelectedArea("v")
       Else
          TransformIMGv()
    Return

    ~vk55 Up::  ;  U
       ColorsAdjusterPanelWindow()
    Return

    vk46::     ; F
       ToggleImgFX(-1)
    Return

    +vk46::     ; Shift+F
       ToggleImgFX(1)
    Return

    +vk51::  ;  Shift+Q-
       ToggleImgColorDepth(1)
    Return

    ~+vk55 Up::    ; Shift+U
       ApplyColorAdjustsSelectedArea()
    Return

    vk51::  ;   Q
       ToggleImgColorDepth(-1)
    Return

    Del Up::
       If (thumbsDisplaying!=1 && activateImgSelection=1 && editingSelectionNow=1)
          PanelEraseSelectedArea()
    Return

    vk41::     ; A
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

    !Left::
       arrowKeysAdjustSelectionArea(-1, 1)
    Return

    !Right::
       arrowKeysAdjustSelectionArea(1, 1)
    Return

    !Up::
       arrowKeysAdjustSelectionArea(-2, 1)
    Return

    !Down::
       arrowKeysAdjustSelectionArea(2, 1)
    Return

    ^+Left::
       arrowKeysAdjustSelectionArea(-1, 2)
    Return

    ^+Right::
       arrowKeysAdjustSelectionArea(1, 2)
    Return

    ^+Up::
       arrowKeysAdjustSelectionArea(-2, 2)
    Return

    ^+Down::
       arrowKeysAdjustSelectionArea(2, 2)
    Return

    F8::
       openPreviousPanel()
    Return
#If

#If (identifyThisWin()=1 && AnyWindowOpen && imgEditPanelOpened=1)
    Enter::
       If (AnyWindowOpen=24)
          BtnPasteInSelectedArea()
       Else If (AnyWindowOpen=30)
          BtnDrawLinesSelectedArea()
       Else If (AnyWindowOpen=23)
          BtnFillSelectedArea()
       Else If (AnyWindowOpen=25)
          BtnEraseSelectedArea()
       SetTimer, RemoveTooltip, -300
    Return


    vk39::    ; 9
    PgUp::
       changeSelRotation(-1)
    Return

    vk30::    ; 0
    PgDn::
       changeSelRotation(1)
    Return


    ~vk52 Up::     ; R
       makeSquareSelection()
    Return

    ^vk41 Up::     ; Ctrl+A
       selectEntireImage()
    Return

    ~+vk45 Up::   ; Shift+E
      toggleEllipseSelection()
    Return

    !Left::
       arrowKeysAdjustSelectionArea(-1, 1)
    Return

    !Right::
       arrowKeysAdjustSelectionArea(1, 1)
    Return

    !Up::
       arrowKeysAdjustSelectionArea(-2, 1)
    Return

    !Down::
       arrowKeysAdjustSelectionArea(2, 1)
    Return

    ^+Left::
       arrowKeysAdjustSelectionArea(-1, 2)
    Return

    ^+Right::
       arrowKeysAdjustSelectionArea(1, 2)
    Return

    ^+Up::
       arrowKeysAdjustSelectionArea(-2, 2)
    Return

    ^+Down::
       arrowKeysAdjustSelectionArea(2, 2)
    Return

    WheelDown::
    Left::
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(-1, "WheelDown")
       } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("L")
       } Else
       {
          arrowKeysAdjustSelectionArea(-1, 1)
          arrowKeysAdjustSelectionArea(-1, 2)
       }
    Return

    WheelUp::
    Right::
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(1, "WheelUp")
       } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("R")
       } Else
       {
          arrowKeysAdjustSelectionArea(1, 1)
          arrowKeysAdjustSelectionArea(1, 2)
       }
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

    NumpadAdd::
    vkBB::    ; [=]
       ChangeZoom(1)
    Return

    NumpadSub::
    vkBD::   ; [-]
       ChangeZoom(-1)
    Return

    Up::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("U")
       } Else
       {
          arrowKeysAdjustSelectionArea(-2, 1)
          arrowKeysAdjustSelectionArea(-2, 2)
       }
    Return

    Down::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("D")
       } Else
       {
          arrowKeysAdjustSelectionArea(2, 1)
          arrowKeysAdjustSelectionArea(2, 2)
       }
    Return

    ^WheelUp::
       IMGresizingMode := 4
       ChangeZoom(1, "WheelUp")
    Return

    ^WheelDown::
       IMGresizingMode := 4
       ChangeZoom(-1, "WheelDown")
    Return
#If

#If (identifyThisWin()=1 && !AnyWindowOpen && CurrentSLD && maxFilesIndex>0)
    F8::
       openPreviousPanel()
    Return

    Space::
       If (thumbsDisplaying=1 || markedSelectFile)
          markThisFileNow()
       Else If (imageLoading!=1 && IMGlargerViewPort=1 && IMGresizingMode=4 && slideShowRunning!=1)
          changeMcursor("move")
       Else If (slideShowRunning=1)
           dummyInfoToggleSlideShowu("stop")
       Else If (A_TickCount - lastOtherWinClose>350) && (A_TickCount - prevSlideShowStop>950)
           InfoToggleSlideShowu()
    Return 

    +^vk56 Up::   ; Ctrl+Shift+V
       If (imageLoading!=1)
          PanelPasteInPlace()
    Return

    +vk4E::    ; Shift+N
       PanelEditImgCaption()
    Return

    vk4E::    ; N
       If (thumbsDisplaying!=1)
          ToggleImgCaptions()
    Return

    +vk49 Up::     ; Shift+I
       InvertSelectedArea()
    Return

    +vk47 Up::     ; Shift+G
       GraySelectedArea()
    Return

    +vk42 Up::     ; Shift+B
       PanelBlurSelectedArea()
    Return

    ^vk31::   ; Ctrl+1
      SetTimer, ActSortName, -150
    Return

    ^vk32::   ; Ctrl+2
      SetTimer, ActSortPath, -150
    Return

    ^vk33::   ; Ctrl+3
      SetTimer, ActSortFileName, -150
    Return

    ^vk34::   ; Ctrl+4
      SetTimer, ActSortSize, -150
    Return

    ^vk35::   ; Ctrl+5
      SetTimer, ActSortModified, -150
    Return

    ^vk36::   ; Ctrl+6
      SetTimer, ActSortCreated, -150
    Return

    ^vk30::   ; Ctrl+0
      SetTimer, ReverseListNow, -150
    Return

    vk39::    ; 9
       changeImgRotationInVP(-1)
    Return

    vk30::    ; 0
       changeImgRotationInVP(1)
    Return

    ~vk59 Up::   ; Y
      PanelImgAutoCrop()
    Return

    ~vk4A Up::    ; J
       PanelJump2index()
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
       ToggleFullScreenMode()
    Return

    ~vk4C::     ; L
       toggleListViewModeThumbs()
    Return

    ~+vk4C::     ; Shift+L
       PanelDrawLines()
    Return

    ~Enter::
       If (A_TickCount - lastOtherWinClose>200)
          ToggleThumbsMode()
    Return

    !Enter::
       ShowImgInfosPanel()
    Return

    +Enter::
       CropImageViewPort()
    Return

    ~^vk43 Up::    ; Ctrl+C
       If (thumbsDisplaying=1)
          CopyImagePath()
       Else
          CopyImage2clip()
    Return

    ~vk43 Up::    ; C
       InvokeCopyFiles()
    Return

    ~^vk55 Up::    ; Ctrl+U
       ForceRegenStaticFolders := 0
       If (RegExMatch(CurrentSLD, sldsPattern) && mustGenerateStaticFolders!=1 && SLDcacheFilesList=1)
          PanelStaticFolderzManager()
    Return

    ~+vk55 Up::    ; Shift+U
       ApplyColorAdjustsSelectedArea()
    Return

    ~!vk55 Up::    ; Alt+U
       ForceRegenStaticFolders := 0
       PanelDynamicFolderzWindow()
    Return

    ~^vk4B Up::    ; Ctrl+K
       PanelFileFormatConverter()
    Return

    ~vk4B Up::    ; K
       imgPath := getIDimage(currentFileIndex)
       If RegExMatch(imgPath, "i)(.\.(jpg|jpeg))$") || markedSelectFile
          PanelJpegPerformOperation()
    Return

    ~^+vk43 Up::    ; Ctrl+Shift+C
    ~+vk43 Up::     ; Shift+C
       CopyImagePath()
    Return

    ~vk4F::   ; O
      OpenThisFileMenu()
    Return

    ~vk49::   ; I
      If (thumbsDisplaying!=1)
         ToggleInfoBoxu()
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

    +vk45::   ; Shift+E
      toggleEllipseSelection()
    Return

    vk45 Up::   ; E
      ToggleEditImgSelection()
    Return

    ~vk44 Up::   ; D
      toggleImgSelection()
    Return

    ~^vk44 Up::   ; Ctrl+D
      If (thumbsDisplaying=1) || (activateImgSelection!=1 && markedSelectFile)
         dropFilesSelection()
      Else
         resetImgSelection()
    Return

    ~^vk46 Up::   ; Ctrl+F
       PanelEnableFilesFilter()
    Return

    ~vk53::   ; S
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

    ~+Space::
       If (thumbsDisplaying=1 || markedSelectFile)
          dropFilesSelection()
       Else If (slideShowRunning=1)
          dummyInfoToggleSlideShowu("stop")
       Else If (A_TickCount - prevSlideShowStop>950)
          dummyInfoToggleSlideShowu()
    Return

    ~^Space Up::
       If (slideShowRunning=1)
       {
          dummyInfoToggleSlideShowu("stop")
       } Else If StrLen(filesFilter)>1
       {
          ; filesFilter := usrFilesFilteru := ""
          coreEnableFiltru("")
          Return
       } Else If (markedSelectFile>1)
       {
          coreEnableFiltru("||Prev-Files-Selection||")
       } Else
       {
          r := getIDimage(currentFileIndex)
          zPlitPath(r, 0, OutFileName, OutDir)
          thisFilter := SubStr(OutDir, 3) "\"
          coreEnableFiltru(thisFilter)
       }
    Return

    ~!BackSpace::
       PanelFillSelectedArea()
    Return

    ~BackSpace::
       PrevRandyPicture()
    Return

    ~+BackSpace::
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
       PanelDefineEntireSlideshowLength()
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

    ~+vk48::    ; Shift+H
       ToggleImgHistogram()
    Return

    ~vk48::    ; H
       If (activateImgSelection=1 && editingSelectionNow=1) || (StrLen(UserMemBMP)>4 && activateImgSelection=1)
          FlipSelectedArea("h")
       Else
          TransformIMGh()
    Return

   ~vk56::    ; V
       If (activateImgSelection=1 && editingSelectionNow=1) || (StrLen(UserMemBMP)>4 && activateImgSelection=1)
          FlipSelectedArea("v")
       Else
          TransformIMGv()
    Return

    ~vk52 Up::     ; R
       makeSquareSelection()
    Return

    ^vk54 Up::     ; Ctrl+T
       PanelTransformSelectedArea()
    Return

    ~^vk52 Up::     ; Ctrl+R
       PanelResizeImageWindow()
    Return

    ~+vk52 Up::     ; Shift+R
       PanelSimpleResizeRotate()
    Return

    ~F2 Up::
       PanelRenameThisFile()
    Return

    ~+F2 Up::
       SingularRenameFile()
    Return

    ~^F2 Up::
       PanelUpdateThisFileIndex()
    Return

    ~vk4D Up::     ; M
       InvokeMoveFiles()
    Return

    ~vk55 Up::  ;  U
       ColorsAdjusterPanelWindow()
    Return

    ^vk51::  ;  Ctrl+Q-
       ToggleImgDownScaling()
    Return

    +vk51::  ;  Shift+Q-
       ToggleImgColorDepth(1)
    Return

    vk51::  ;   Q
       ToggleImgColorDepth(-1)
    Return

    vk46::     ; F
       ToggleImgFX(-1)
    Return

    +vk46::     ; Shift+F
       ToggleImgFX(1)
    Return

    vk41::     ; A
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

    ^vk41::     ; Ctrl+A
       If (thumbsDisplaying=1)
          selectAllFiles()
       Else
          selectEntireImage()
    Return

    ~Del Up::
       If (thumbsDisplaying!=1 && activateImgSelection=1 && editingSelectionNow=1)
          PanelEraseSelectedArea()
       Else
          DeletePicture()
    Return

    ~+Del Up::
       If !markedSelectFile
       {
          DeletePicture()
          Sleep, 350
          InListMultiEntriesRemover()
       } Else DeletePicture("single")
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
          ThumbsNavigator("Upu", A_ThisHotkey)
          ThumbsNavigator("Upu", A_ThisHotkey)
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
             NextPicture("key-" A_ThisHotkey)
       }
    Return

    ^Left::
       navSelectedFiles(-1)
    Return

    ^Right::
       navSelectedFiles(1)
    Return

    F3::
       searchNextIndex(1)
    Return

    +F3::
       searchNextIndex(-1)
    Return

    ^F3::
       PanelSearchIndex()
    Return

    !Left::
       arrowKeysAdjustSelectionArea(-1, 1)
    Return

    !Right::
       arrowKeysAdjustSelectionArea(1, 1)
    Return

    !Up::
       arrowKeysAdjustSelectionArea(-2, 1)
    Return

    !Down::
       arrowKeysAdjustSelectionArea(2, 1)
    Return

    ^+Left::
       arrowKeysAdjustSelectionArea(-1, 2)
    Return

    ^+Right::
       arrowKeysAdjustSelectionArea(1, 2)
    Return

    ^+Up::
       arrowKeysAdjustSelectionArea(-2, 2)
    Return

    ^+Down::
       arrowKeysAdjustSelectionArea(2, 2)
    Return

    WheelDown::
    Left::
    +Left::
       If (InStr(A_ThisHotkey, "wheel") && thumbsDisplaying=1)
       {
          ThumbsNavigator("Down", A_ThisHotkey)
          ThumbsNavigator("Down", A_ThisHotkey)
          Return
       } Else If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
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
             PreviousPicture("key-" A_ThisHotkey)
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

    ~^Home Up::
       jumpToFilesSelBorder(-1)
    Return

    ~^End Up::
       jumpToFilesSelBorder(1)
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


;____________ Functions __________________

OpenSLD(fileNamu, dontStartSlide:=0) {
  If !FileExist(fileNamu)
  {
     showTOOLtip("ERROR: Failed to load file...")
     SoundBeep, 300, 100
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return
  }

  If (SLDtypeLoaded=3)
  {
     SLDtypeLoaded := 0
     activeSQLdb.CloseDB()
  }

  mustRemQuotes := 1
  setImageLoading()
  ForceRegenStaticFolders := 0
  renewCurrentFilesList()
  newStaticFoldersListCache := DynamicFoldersList := CurrentSLD := ""
  filesFilter := usrFilesFilteru := ""
  SLDhasFiles := 0
  zPlitPath(fileNamu, 0, OutFileName, OutDir)
  showTOOLtip("Loading slideshow, please wait...`n" OutFileName "`n" OutDir "\")
  setWindowTitle("Loading slideshow, please wait", 1)
  If RegExMatch(fileNamu, "i)(.\.sldb)$")
  {
     r := sldDataBaseOpen(fileNamu)
     If (maxFilesIndex>0 && r!=-1)
     {
        GenerateRandyList()
        SetTimer, ResetImgLoadStatus, -50
        CurrentSLD := fileNamu
        SLDtypeLoaded := 3
        prevOpenFolderPath := OutDir
        INIaction(1, "prevOpenFolderPath", "General")
        RandomPicture()
        InfoToggleSlideShowu()
     } Else resetMainWin2Welcome()
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return
  }

  FileReadLine, firstLine, % fileNamu, 1
  If InStr(firstLine, "[General]") 
  {
     mustRemQuotes := 0
     IniRead, UseCachedList, % fileNamu, General, UseCachedList, @
     IniRead, testStaticFolderz, % fileNamu, Folders, Fi1, @
     IniRead, testDynaFolderz, % fileNamu, DynamicFolderz, DF1, @
     If StrLen(testDynaFolderz)>4
        DynamicFoldersList := "|hexists|"
;        DynamicFoldersList := coreLoadDynaFolders(fileNamu)

     IniRead, tstSLDcacheFilesList, % fileNamu, General, SLDcacheFilesList, @
     If (tstSLDcacheFilesList=1 || tstSLDcacheFilesList=0)
        SLDcacheFilesList := tstSLDcacheFilesList
  }

  mustGenerateStaticFolders := (InStr(firstLine, "[General]") && StrLen(testStaticFolderz)>8) ? 0 : 1
  If (UseCachedList="Yes" && InStr(firstLine, "[General]")) || !InStr(firstLine, "[General]")
     res := sldGenerateFilesList(fileNamu, 0, mustRemQuotes)

  prevOpenFolderPath := OutDir
  INIaction(1, "prevOpenFolderPath", "General")
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
  SLDtypeLoaded := 2
  currentFileIndex := 1
  RecentFilesManager()
  If (dontStartSlide=1)
  {
     SetTimer, RemoveTooltip, % -msgDisplayTime
     SetTimer, ResetImgLoadStatus, -25
     Return
  }

  If (maxFilesIndex>2)
  {
     RandomPicture()
     InfoToggleSlideShowu()
  } Else If (maxFilesIndex>0)
  {
     currentFileIndex := 1
     IDshowImage(1)
  } Else resetMainWin2Welcome()

  SetTimer, ResetImgLoadStatus, -25
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

resetMainWin2Welcome() {
     ForceRegenStaticFolders := SLDhasFiles := SLDtypeLoaded := 0
     thumbsDisplaying := 0
     renewCurrentFilesList()
     newStaticFoldersListCache := DynamicFoldersList := CurrentSLD := ""
     filesFilter := usrFilesFilteru := ""
     setWindowTitle(appTitle, 1)
     clearGivenGDIwin(glPG, glHDC, hGDIthumbsWin)
     clearGivenGDIwin(glPG, glHDC, hGDIwin)
     ForceRefreshNowThumbsList()
     drawWelcomeImg()
     SetTimer, ResetImgLoadStatus, -50
}

escRoutine() {
  Sleep, -1
  Return
}

GenerateRandyList() {
   startZeit := A_TickCount
   RandyIMGids := []
   Loop, % maxFilesIndex
       RandyIMGids[A_Index] := A_Index
   RandyIMGids := Random_ShuffleArray(RandyIMGids)
   RandyIMGnow := 1
   ; MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000)
}

OpenThisFileFolder() {
    If (currentFileIndex=0)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    resultu := getIDimage(currentFileIndex)
    If resultu
    {
       zPlitPath(resultu, 0, fileNamu, folderu)
       Try Run, "%folderu%"
       Catch wasError
             msgBoxWrapper(appTitle ": ERROR", "An unknown error occured opening the folder...`n" folderu, 0, 0, "error")
    }
}

OpenThisFileMenu() {
  Static lastInvoked := 1

  imgPath := getIDimage(currentFileIndex)
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

  DestroyGIFuWin()
  isAssociated := (testA=1 && testB=1) ? 1 : 0
  newInstanceOption := (A_IsCompiled) ? 1 : 0
  InvokeOpenWithMenu(imgPath, newInstanceOption)
}

OpenNewQPVinstance() {
   imgPath := getIDimage(currentFileIndex)
   thisPath := A_IsCompiled ? fullPath2exe : A_ScriptFullPath
   Try Run, "%thisPath%" "%imgPath%"
   Catch wasError
         msgBoxWrapper(appTitle ": ERROR", "An unknown error occured opening a new instance of " appTitle "...", 0, 0, "error")
}

OpenWithDefaultApp() {
    imgPath := getIDimage(currentFileIndex)
    imgPath := StrReplace(imgPath, "||")
    If !FileRexists(imgPath)
       informUserFileMissing()
    Sleep, 25
    If imgPath
    {
       Try Run, "%imgPath%"
       Catch wasError
             msgBoxWrapper(appTitle ": ERROR", "An unknown error occured opening the default application...", 0, 0, "error")
    }
}

OpenFileProperties() {
    imgPath := getIDimage(currentFileIndex)
    imgPath := StrReplace(imgPath, "||")
    If !FileRexists(imgPath)
       informUserFileMissing()
    Sleep, 25
    If imgPath
    {
       Try Run, Properties "%imgPath%"
       Catch wasError
             msgBoxWrapper(appTitle ": ERROR", "An unknown error occured opening the system file properties...", 0, 0, "error")
    }
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
   ; DestroyGIFuWin()
   If (slideShowRunning!=1 && showMsg!=1)
      Return

   If (easySlideStoppage=1 && slideShowRunning=1 && ignoreEasyStop=0)
      ToggleSlideShowu("stop")
   Else If (slideShowRunning=1)
      ToggleSlideShowu("start")

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
   INIaction(1, "slideShowDelay", "General")
}

CopyImagePath() {
  If (currentFileIndex=0)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  showTOOLtip("Copying file path(s) to clipboard...")
  getSelectedFiles(0, 1)
  If (markedSelectFile>1)
  {
     Loop, % maxFilesIndex
     {
        isSelected := resultedFilesList[A_Index, 2]
        If (isSelected!=1)
           Continue
        file2rem := getIDimage(A_Index)
        file2rem := StrReplace(file2rem, "||")
        listu .= file2rem "`n"
        countTFilez++
     }

     If countTFilez
     {
        Try Clipboard := listu
        Catch wasError
            Sleep, 1

        infoText := wasError ? "ERROR: Failed to copy to clipoard the selected file paths...`nError code: " wasError : countTFilez " file paths were copied to clipboard..."
        showTOOLtip(infoText)
        SetTimer, RemoveTooltip, % -msgDisplayTime
        Return
     } Else markedSelectFile := 0
  }

  imgPath := getIDimage(currentFileIndex)
  imgPath := StrReplace(imgPath, "||")
  Try Clipboard := imgPath
  Catch wasError
      Sleep, 1

  zPlitPath(imgPath, 0, fileNamu, folderu)
  infoText := wasError ? "ERROR: Failed to copy to clipoard the file path...`nError code: " wasError "`n" : "File path copied to clipboard...`n"
  showTOOLtip(infoText fileNamu "`n" folderu "\")
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

CopyImage2clip() {
  If (thumbsDisplaying=1)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  friendly := (activateImgSelection=1) ? "selected area" : ""
  setImageLoading()
  imgPath := getIDimage(currentFileIndex)
  If gdiBitmap
  {
     Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
     showTOOLtip("Copying image " friendly " to clipboard, please wait...")
     dummyBMP := Gdip_CloneBitmap(gdiBitmap)
     r := coreResizeIMG(imgPath, imgW, imgH, "--", 1, 1, 0, dummyBMP, imgW, imgH, 0)
  } Else r := "err"

  SetTimer, ResetImgLoadStatus, -50
  If r
     showTOOLtip("Failed to copy the image to clipboard... Error code: " r)
  Else
     showTOOLtip("Image " friendly " copied to clipboard...")

  SoundBeep, % r ? 300 : 900, 100
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

invertRecursiveness() {
   If (RegExMatch(CurrentSLD, sldsPattern) || !CurrentSLD)
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

remFilesListFilter() {
   coreEnableFiltru("")
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

determineLClickstate() {
   LbtnDwn := interfaceThread.ahkgetvar.LbtnDwn
   If (GetKeyState("LButton") || LbtnDwn=1)
      Return 1
   Else
      Return 0
}

ReloadThisPicture() {
  SetTimer, dummyTimerDelayiedImageDisplay, Off

  If (CurrentSLD && maxFilesIndex>0) || StrLen(UserMemBMP)>2
  {
     If (determineLClickstate()=1 || GetKeyState("Space", "P"))
     {
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
  If (CurrentSLD && maxFilesIndex>0) || StrLen(UserMemBMP)>2
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
   dummyTimerDelayiedImageDisplay(50)
   showTOOLtip("Total images loaded: 1 / " maxFilesIndex)
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

LastPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()
   currentFileIndex := maxFilesIndex
   dummyTimerDelayiedImageDisplay(50)
   showTOOLtip("Total images loaded: " maxFilesIndex)
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

SettingsGUIAGuiClose:
SettingsGUIAGuiEscape:
   CloseWindow()
Return

doCleanup:
   TrueCleanup()
Return

TrueCleanup(mustExit:=1) {
   Critical, on
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 900) || (hasInitSpecialMode=1)
      Return

   activeSQLdb.Close()
   If AnyWindowOpen
   {
      CloseWindow()
      Sleep, 10
   }

   WinSet, Region, 0-0 w1 h1, ahk_id %PVhwnd%
   RegWrite, REG_SZ, %QPVregEntry%, Running, 0
   If hitTestSelectionPath
   {
      editingSelectionNow := activateImgSelection := 0
      Gdip_DeletePath(hitTestSelectionPath)
      hitTestSelectionPath := ""
   }

   lastInvoked := A_TickCount
   RemoveTooltip()
   DestroyGIFuWin()

   Sleep, 0
   If (wasInitFIMlib=1)
      FreeImage_FoxInit(0) ; Unload Dll

   disposeCacheIMGs()
   HistogramBMP := Gdip_DisposeImage(HistogramBMP, 1)
   destroyGDIfileCache()
   AprevGdiBitmap := Gdip_DisposeImage(AprevGdiBitmap, 1)
   BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
   GDIfadeVPcache := Gdip_DisposeImage(GDIfadeVPcache, 1)
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
   If pBrushF
      Gdip_DeleteBrush(pBrushF)
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
   GDIPToken := Gdip_Shutdown(GDIPToken)  
   lastInvoked := A_TickCount
   ; If (mustExit=1)
   ;    writeMainSettings()
   lastInvoked := A_TickCount
   ForceExitNow()
}

ForceExitNow() {
   If GDIPToken
      Gdip_Shutdown(GDIPToken)  
   Sleep, 5
   thisPID := GetCurrentProcessId()
   Process, Close, % thisPID
   ExitApp
}

setWindowTitle(msg, forceThis:=0) {
    infoSlideDelay := (slideShowRunning=1 && slideShowDelay<2950) ? 1 : 0
    If (runningLongOperation!=1 && infoSlideDelay=0 && animGIFplaying!=1 && hasInitSpecialMode!=1) || (forceThis=1)
       WinSetTitle, ahk_id %PVhwnd%,, % msg
}

MenuDummyToggleThumbsMode() {
   lastOtherWinClose := 5
   ToggleThumbsMode()
}

initAHKhThumbThreads() {
    Static multiCoreInit := 0

    If (multiCoreInit=1 || allowMultiCoreMode!=1 || minimizeMemUsage=1)
       Return

    initFIMGmodule()
    If (FIMfailed2init=1)
    {
       multiCoreThumbsInitGood := 0
    } Else
    {
       ; SoundBeep 300, 900
       If A_IsCompiled
          r := GetRes(dataFile, 0, "MODULE-FIM-THUMBS.AHK", "LIB")

       Loop, % realSystemCores + 1
       {
           If !A_IsCompiled
              thumbThread%A_Index% := ahkthread("#Include *i Lib\module-fim-thumbs.ahk")
           Else If r
              thumbThread%A_Index% := ahkThread(StrGet(&dataFile, r, "utf-8"))
           Sleep, 1
       }

       Loop, % realSystemCores + 1
       {
           thumbThread%A_Index%.ahkFunction("initThisThread")
           Sleep, 1
       }

       Sleep, 5
       Loop, % realSystemCores + 1
           goodInit += thumbThread%A_Index%.ahkgetvar.wasInitFIMlib

       multiCoreThumbsInitGood := (goodInit>=realSystemCores+1) ? 1 : 0
    }

    multiCoreInit := 1
}

ToggleThumbsMode() {
   Static multiCoreInit := 0, lastInvoked := 1, prevIndexu

   DestroyGIFuWin()
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (A_TickCount - lastInvoked<190) || (A_TickCount - lastOtherWinClose<190)
   {
      lastInvoked := A_TickCount
      Return
   }

   lastInvoked := A_TickCount
   If (maxFilesIndex>1)
   {
      Sleep, 1
   } Else Return

   interfaceThread.ahkassign("lastCloseInvoked", 0)
   thisIndexu := resultedFilesList[currentFileIndex, 1] currentFileIndex

   clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIselectWin)
   If (thumbsDisplaying=1)
   {
      If (thisIndexu!=prevIndexu)
         FadeMainWindow()

      thumbsDisplaying := 0
      ToggleVisibilityWindow("show", hGDIwin)
      interfaceThread.ahkassign("thumbsDisplaying", 0)
      interfaceThread.ahkassign("maxFilesIndex", maxFilesIndex)
      setTexHatchScale(zoomLevel)
      ToggleVisibilityWindow("hide", hGDIthumbsWin)
      dummyTimerDelayiedImageDisplay(50)
      If hSNDmediaFile
         MCI_Resume(hSNDmedia)
      lastInvoked := A_TickCount
      Return
   } Else If (CurrentSLD && maxFilesIndex>1)
   {
      If (prevIndexu!=thisIndexu && noTooltipMSGs=0 && thumbnailsListMode!=1)
         TooltipCreator("Generating thumbnails, please wait...", 0, 1)

      prevIndexu := resultedFilesList[currentFileIndex, 1] currentFileIndex
      If (thumbnailsListMode!=1)
         initAHKhThumbThreads()

      If (getCaptionStyle(PVhwnd)=1)
         ToggleTitleBaruNow()
      If hSNDmediaFile
         MCI_Pause(hSNDmedia)
      setTexHatchScale(thumbsZoomLevel/2)
      ToggleVisibilityWindow("hide", hGDIwin)
      ToggleVisibilityWindow("show", hGDIthumbsWin)
      recalculateThumbsSizes()
      UpdateThumbsScreen()
      clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
      RemoveTooltip()
   }

   lastInvoked := A_TickCount
}

defineThumbsAratio() {
  friendly := (thumbsAratio=1) ? "Wide (1.81)" : "Tall (0.48)"
  If (thumbsAratio=3)
     friendly := "Square (1.00)"

  Return friendly
}

recalculateThumbsSizes() {
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
  Else If (thumbsZoomLevel>3)
    thumbsZoomLevel := 3

  thumbsH := Round(othumbsH*thumbsZoomLevel)
  thumbsW := Round(othumbsW*thumbsZoomLevel)
  GetClientSize(mainWidth, mainHeight, PVhwnd)
  If (thumbsH>mainHeight || thumbsW>mainWidth)
  {
     calcIMGdimensions(thumbsW, thumbsH, mainWidth//2 - 16, mainHeight//2 - 16, ResizedW, ResizedH)
     If ResizedH
        thumbsH := ResizedH
     If ResizedW
        thumbsW := ResizedW
  }

  If valueBetween(max(thumbsW, thumbsH), 95, 150)
     thumbsSizeQuality := 125
  Else If (max(thumbsW, thumbsH)<290)
     thumbsSizeQuality := 245
  Else If (max(thumbsW, thumbsH)>650)
     thumbsSizeQuality := 755
  Else
     thumbsSizeQuality := 500


   If (thumbnailsListMode=1)
   {
      Static theString := "WAWAWAWAWAWAWAWAWAWAWAWAWAWAWAWAWAWAWAWAW", prevDimensions, columnsPossible
      theseDimensions := mainWidth "=" mainHeight "=" OSDfntSize "=" OSDFontName
      If (prevDimensions!=theseDimensions)
      {
         xBitmap := Gdip_CreateBitmap(30, 30)
         G := Gdip_GraphicsFromImage(xBitmap)
         borderSize := Floor(OSDfntSize*1.15)//4.5
         txtOptions := "x" borderSize " y" borderSize A_Space " Left cEE090909 r4 s" OSDfntSize
         dimensions := Gdip_TextToGraphics(G, theString, txtOptions, OSDFontName, mainWidth, mainHeight, 0, 0)
         txtRes := StrSplit(dimensions, "|")
         txtResW := Ceil(txtRes[3]) + borderSize*2
         Gdip_DeleteGraphics(G)
         Gdip_DisposeImage(xBitmap, 1)
         columnsPossible := Round(mainWidth/txtResW)
         prevDimensions := mainWidth "=" mainHeight "=" OSDfntSize "=" OSDFontName
      }

      thumbsW := mainWidth//columnsPossible - 15
      If (thumbsListViewMode=1)
         thumbsH := Round((OSDfntSize//1.25 + imgHUDbaseUnit//9) * 2.5)
      Else
         thumbsH := Round((OSDfntSize//1.25 + imgHUDbaseUnit//9) * 3.55)
   }
}


ChangeThumbsAratio() {
  If (thumbsDisplaying!=1 || thumbnailsListMode=1)
     Return

  thumbsAratio++
  If (thumbsAratio>3)
     thumbsAratio := 1

  recalculateThumbsSizes()
  showTOOLtip("Thumbnails aspect ratio: " defineThumbsAratio() "`nSize: " thumbsW " x " thumbsH " (pixels)")
  SetTimer, RemoveTooltip, % -msgDisplayTime
  INIaction(1, "thumbsAratio", "General")
  ForceRefreshNowThumbsList()
  dummyTimerDelayiedImageDisplay(90)
}

thumbsInfoYielder(ByRef maxItemsW, ByRef maxItemsH, ByRef maxItemsPage, ByRef maxPages, ByRef startIndex, ByRef mainWidth, ByRef mainHeight) {
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   maxItemsW := (mainWidth+15)//thumbsW
   maxItemsH := (mainHeight+15)//thumbsH
   If (maxItemsW<2)
      maxItemsW := 1
   If (maxItemsH<2)
      maxItemsH := 1

   maxItemsPage := maxItemsW*maxItemsH
   maxPages := Ceil(maxFilesIndex/maxItemsPage)
   maxItemsLine := maxItemsW ; *maxItemsH
   startIndex := Floor(currentFileIndex/maxItemsLine) * maxItemsLine
   If (startIndex<2)
      startIndex := 1

   ; ToolTip, % startIndex  " -- " prevRealThumbsIndex " || " maxItemsW " -- " maxItemsH , , , 2
   If valueBetween(startIndex, prevRealThumbsIndex + maxItemsPage + maxItemsW*maxItemsH, prevRealThumbsIndex - maxItemsW*maxItemsH)
   {
      If valueBetween(startIndex, prevRealThumbsIndex, prevRealThumbsIndex + maxItemsPage - maxItemsW)
         startIndex := prevRealThumbsIndex
      Else
         startIndex := (startIndex<prevRealThumbsIndex) ? startIndex : startIndex - maxItemsW*maxItemsH + maxItemsW
   } Else startIndex := Floor(currentFileIndex/maxItemsPage) * maxItemsPage

   If (startIndex<2)
      startIndex := 1
   If (startIndex>maxFilesIndex - 1)
      startIndex := maxFilesIndex - maxItemsW
   Return startIndex maxItemsW maxItemsH maxItemsPage
}

RefreshThumbsList() {
   mustReloadThumbsList := 1
   dummyTimerDelayiedImageDisplay(50)
}

ForceRefreshNowThumbsList() {
   ; mustReloadThumbsList := 1
   prevStartIndex := -1
   ; dummyTimerDelayiedImageDisplay(50)
}

UpdateThumbsScreen(forceReload:=0) {
   Critical, on
   Static lastInvoked := 1, lastInvokeReload := 1
   SetTimer, dummyTimerDelayiedImageDisplay, Off
   SetTimer, dummyTimerReloadThisPicture, Off
   thumbsDisplaying := 1
   interfaceThread.ahkassign("thumbsDisplaying", 1)
   interfaceThread.ahkassign("maxFilesIndex", maxFilesIndex)
   startPageIndex := thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
   createGDIPcanvas(mainWidth, mainHeight)
   Gdip_ResetWorldTransform(glPG)
   IMGlargerViewPort := 0
   If (slideShowRunning=1)
      ToggleSlideShowu()

   DestroyGIFuWin()
   mustShowNames := 0
   If (A_TickCount - prevTryThumbsUpdate<200) && (mustReloadThumbsList!=1 && thumbnailsListMode!=1 && startPageIndex!=prevFullIndexThumbsUpdate)
   {
      r := 1
      mustShowNames := 1
      ; If (startPageIndex!=prevFullIndexThumbsUpdate)
         prevFullThumbsUpdate := A_TickCount
      SetTimer, RefreshThumbsList, -300
   } Else If (prevStartIndex!=startPageIndex || mustReloadThumbsList=1 || forceReload=1)
   {
      r := QPV_ShowThumbnails(startIndex)
      If r
         prevFullIndexThumbsUpdate := startPageIndex
      mustReloadThumbsList := 0
   } Else r := 1
   prevStartIndex := startPageIndex
   prevRealThumbsIndex := startIndex
   mainGdipWinThumbsGrid(0, mustShowNames)
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
   While, (determineLClickstate()=1)
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
   }
   diffIMGdecX := diffIMGdecY := 0
}

ThumbsScrollbar() {
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   prevFileIndex := currentFileIndex
   While, (determineLClickstate()=1)
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
   }

   If (GetKeyState("Shift", "P"))
   {
      keyu := (currentFileIndex>prevFileIndex) ? "Down" : "Home"
      thumbsSelector(keyu, "+Shift", prevFileIndex)
   }

   dummyTimerDelayiedImageDisplay(250)
}

panIMGonClick() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   GetClientSize(mainWidth, mainHeight, PVhwnd)
   ; cW := mainWidth//2, cH := mainHeight//2
   ; JEE_ClientToScreen(PVhwnd, cW, cH, oX, oX)
   ; MouseMove, % oX, % oY, 0
   Sleep, 0
   GetPhysicalCursorPos(oX, oY)
   newPosZeit := A_TickCount
   oDx := IMGdecalageX, oDy := IMGdecalageY
   zX := oX, zY := oY
   thisZeit := A_TickCount
   While, (determineLClickstate()=1)
   {
      Sleep, 2
      GetPhysicalCursorPos(mX, mY)

      skipLoop := (valueBetween(mX, zX - 5, zX + 5) && valueBetween(mY, zY - 5, zY + 5)) ? 1 : 0
      diffIMGdecX := Dx := mX - oX + 2
      diffIMGdecY := Dy := mY - oY + 2
      IMGdecalageX := (FlipImgH=1) ? oDx - Dx : oDx + Dx
      IMGdecalageY := (FlipImgV=1) ? oDy - Dy : oDy + Dy
      ; ToolTip, % diffIMGdecX "--" diffIMGdecY " || " IMGdecalageX "--" IMGdecalageY " || " odX "--" odY , , , 2
      If (A_TickCount - newPosZeit>950) || (mX=oX && mY=oY)
      {
         newPosZeit := A_TickCount
         zX := mX, zY := mY
         If (skipLoop=1)
            Continue
      } Else If (skipLoop=1)
         Continue

      MouseMove, % oX, % oY, 0
      oDx := IMGdecalageX, oDy := IMGdecalageY
      If (oDx>0 && Abs(oDx)>Abs(imgDecLX//2))
         oDx := -imgDecLX//2
      Else If (oDx<0 && Abs(oDx)>Abs(imgDecLX//2))
         oDx := imgDecLX//2

      If (oDy>0 && Abs(oDy)>Abs(imgDecLY//2))
         oDy := -imgDecLY//2
      Else If (oDy<0 && Abs(oDy)>Abs(imgDecLY//2))
         oDy := imgDecLY//2

      If (A_TickCount - thisZeit>15)
      {
         If (LastPrevFastDisplay=1 || PannedFastDisplay=1)
            coreReloadThisPicture()
         Else
            filterDelayiedImageDisplay()
         thisZeit := A_TickCount
      }
   }
   diffIMGdecX := diffIMGdecY := 0
}

winSwipeAction(thisCtrlClicked) {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   didSomething := 1
   infoImgEditingMode := (StrLen(UserMemBMP)>2 && activateImgSelection=1) || (imgEditPanelOpened=1) ? 1 : 0
   GetPhysicalCursorPos(oX, oY)
   If (IMGlargerViewPort=1 && thumbsDisplaying!=1 && thisCtrlClicked="PicOnGUI2b")
   {
      SetTimer, panIMGonClick, -15
      Return
   }

   lowerLimitRatio := (IMGresizingMode=4) ? 0.4 : 0.2
   While, (determineLClickstate()=1)
   {
      GetPhysicalCursorPos(mX, mY)
      diffx := Abs(mX - oX)
      diffy := Abs(mY - oY)
      dirX := (mX - oX) < 0 ? -1 : 1
      dirY := (mY - oY) < 0 ? -1 : 1
      ratioDiffs := diffx/diffy
      If (diffx>45 || diffy>45) && (ratioDiffs<lowerLimitRatio || ratioDiffs>3)
      {
         Sleep, 5
         swipeAct := (ratioDiffs<lowerLimitRatio) ? 1 : 2
         If (ratioDiffs="")
            swipeAct := 0
         ; ToolTip, % swipeAct " - " thisCtrlClicked " - " ratioDiffs 
      } Else swipeAct := 0 ;  Tooltip
   }

   GetClientSize(mainWidth, mainHeight, PVhwnd)
   If !swipeAct
   {
      If (imgEditPanelOpened!=1 && thisCtrlClicked="PicOnGUI3" && infoImgEditingMode!=1)
      {
         GoNextSlide()
      } Else If (thisCtrlClicked="PicOnGUI1" && infoImgEditingMode!=1)
      {
         GoPrevSlide()
      } Else If (thisCtrlClicked="PicOnGUI2a" || thisCtrlClicked="PicOnGUI2c")
      {
         regSize := (editingSelectionNow=1 && activateImgSelection=1) ? 7 : 5
         If (oY<mainHeight//regSize)
            ChangeZoom(1)
         Else If (oY>mainHeight - mainHeight//regSize)
            ChangeZoom(-1)
      } Else didSomething := 0
   } Else If (swipeAct=1)
   {
      stepFactor := (diffy/mainHeight)*1.65 + 1.25
      ChangeZoom(dirY, 0, stepFactor)
   } Else If (swipeAct=2 && infoImgEditingMode!=1)
   {
      If (dirX=1)
         GoNextSlide()
      Else If (dirX=-1)
         GoPrevSlide()
      Else didSomething := 0
   } Else didSomething := 0
   Return didSomething
}

GetMouseCoord2wind(hwnd, ByRef nx, ByRef ny) {
    ; CoordMode, Mouse, Screen
    MouseGetPos, ox, oy
    JEE_ScreenToClient(hwnd, ox, oy, nx, ny)
}

dummyAutoClearSelectionHighlight() {
    GetMouseCoord2wind(hGDIwin, mX, mY)
    Gdip_SetPenWidth(pPen1d, SelDotsSize)
    hitB := Gdip_IsOutlineVisiblePathPoint(2NDglPG, hitTestSelectionPath, pPen1d, mX, mY)
    If !hitB
    {
       Gdip_GraphicsClear(2NDglPG, "0x00" WindowBgrColor)
       pathBounds := Gdip_GetPathWorldBounds(hitTestSelectionPath)
       Gdip_FillEllipse(2NDglPG, pBrushD, pathBounds.x + pathBounds.w//2 - SelDotsSize//3, pathBounds.y + pathBounds.h//2 - SelDotsSize//3, SelDotsSize*0.7, SelDotsSize*0.7)
       r2 := UpdateLayeredWindow(hGDIinfosWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
   }
}

MouseMoveResponder() {
  Static prevState := "C"

  If (hitTestSelectionPath && activateImgSelection=1 && editingSelectionNow=1 && adjustNowSel=0 && imgSelLargerViewPort!=1)
  {
     ; ToolTip, % SelDotsSize , , , 2
     GetClientSize(mainWidth, mainHeight, PVhwnd)
     GetMouseCoord2wind(hGDIwin, mX, mY)
     hitA := Gdip_IsVisiblePathPoint(hitTestSelectionPath, mX, mY, 2NDglPG)
     Gdip_SetPenWidth(pPen1d, SelDotsSize)
     hitB := Gdip_IsOutlineVisiblePathPoint(2NDglPG, hitTestSelectionPath, pPen1d, mX, mY)
     If (hitB=1)
        thisState := "B"
     Else If (hitA=1)
        thisState := "A"
     Else
        thisState := "C"

     If (thisState="B" && prevState!=thisState)
     {
        ; changeMcursor("finger")
        prevState := "B"
        Gdip_GraphicsClear(2NDglPG, "0x00" WindowBgrColor)
        Gdip_SetPenWidth(pPen1d, SelDotsSize//2)
        Gdip_DrawPath(2NDglPG, pPen1d, hitTestSelectionPath)
        r2 := UpdateLayeredWindow(hGDIinfosWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
     } Else If (thisState="A" && prevState!=thisState)
     {
        ; changeMcursor("move")
        prevState := "A"
        Gdip_GraphicsClear(2NDglPG, "0x00" WindowBgrColor)
        pathBounds := Gdip_GetPathWorldBounds(hitTestSelectionPath)
        Gdip_FillEllipse(2NDglPG, pBrushD, pathBounds.x + pathBounds.w//2 - SelDotsSize//3, pathBounds.y + pathBounds.h//2 - SelDotsSize//3, SelDotsSize*0.7, SelDotsSize*0.7)
        Gdip_FillPath(2NDglPG, pBrushF, hitTestSelectionPath)
        r2 := UpdateLayeredWindow(hGDIinfosWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
        SetTimer, dummyAutoClearSelectionHighlight, -150
     } Else If (thisState="C" && prevState!=thisState)
     {
        clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
        prevState := "C"
     }

     dotsSize := SelDotsSize
     If (imgEditPanelOpened=1 && thisState!="C")
     {
        Gdip_FillRectangle(2NDglPG, pBrushD, selDotX, selDotY, dotsSize, dotsSize)
        Gdip_FillRectangle(2NDglPG, pBrushD, SelDotAx, SelDotAy, dotsSize, dotsSize)
        Gdip_FillRectangle(2NDglPG, pBrushD, SelDotBx, SelDotBy, dotsSize, dotsSize)
        Gdip_FillRectangle(2NDglPG, pBrushD, SelDotCx, SelDotCy, dotsSize, dotsSize)
        r2 := UpdateLayeredWindow(hGDIinfosWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
     }
  } Else
  {
     If (prevState!="C")
        clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
     prevState := "C"
  }
}

livePreviewsImageEditing() {
   If (imgEditPanelOpened!=1)
      Return

   If (AnyWindowOpen=24 || AnyWindowOpen=31)
   {
      PasteInPlaceAngle := vPselRotation
      corePasteInPlaceActNow()
   } Else If (AnyWindowOpen=30)
   {
      DrawLineAreaAngle := vPselRotation
      coreDrawLinesSelectionArea()
   } Else If (AnyWindowOpen=23)
   {
      FillAreaAngle := vPselRotation
      coreFillSelectedArea()
   } Else If (AnyWindowOpen=25)
      liveEraserPreview()

   dotsSize := SelDotsSize
   Gdip_FillRectangle(2NDglPG, pBrushA, selDotX, selDotY, dotsSize, dotsSize)
   Gdip_FillRectangle(2NDglPG, pBrushA, SelDotAx, SelDotAy, dotsSize, dotsSize)
   Gdip_FillRectangle(2NDglPG, pBrushA, SelDotBx, SelDotBy, dotsSize, dotsSize)
   Gdip_FillRectangle(2NDglPG, pBrushA, SelDotCx, SelDotCy, dotsSize, dotsSize)
   If (imgEditPanelOpened=1)
   {
       Gdip_FillEllipse(2NDglPG, pBrushA, SelDotDx, SelDotDy, dotsSize*2, dotsSize*2)
       Gdip_FillEllipse(2NDglPG, pBrushE, SelDotDx + dotsSize//3, SelDotDy + dotsSize//3, dotsSize*1.33, dotsSize*1.33)
   }

   Gdip_SetPenWidth(pPen1d, SelDotsSize//4)
   If hitTestSelectionPath
      Gdip_DrawPath(2NDglPG, pPen1d, hitTestSelectionPath)
}

WinClickAction(mainParam:=0, thisCtrlClicked:=0) {
   Critical, on
   Static thisZeit := 1, prevTippu := 1, anotherZeit := 1
        , lastInvoked := 1, lastInvoked2 := 1, lastInvokedSwipe := 1

   ; ToolTip, % mainParam " -- " thisCtrlClicked,,,2
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
      If (AnyWindowOpen=10)
      {
         GetMouseCoord2wind(PVhwnd, mX, mY)
         GetClientSize(mainWidth, mainHeight, PVhwnd)
         If (mY<mainHeight//6)
         {
            ChangeZoom(1)
         } Else If (mY>mainHeight - mainHeight//6)
         {
            ChangeZoom(-1)
         } Else
         {
            If (mainParam="doubleclick" || IMGlargerViewPort!=1)
            {
               ForceNoColorMatrix := !ForceNoColorMatrix
               dummyTimerDelayiedImageDisplay(50)
            } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
               SetTimer, panIMGonClick, -25
            lastInvoked := A_TickCount
         }
      }

      If (imgEditPanelOpened!=1)
      {
         SoundPlay, *-1
         WinActivate, ahk_id %hSetWinGui%
         Return
      }
   }

   If (imageLoading=1 && thumbsDisplaying=1)
      Return

   MouseGetPos, , , OutputVarWin
   If (toolTipGuiCreated=1)
      RemoveTooltip()

   spaceState := GetKeyState("Space", "P") ? 1 : 0
   GetMouseCoord2wind(PVhwnd, mX, mY)
   If (mainParam="doubleclick" && thumbsDisplaying=1 && hitTestSelectionPath)
   {
      hitA := Gdip_IsVisiblePathPoint(hitTestSelectionPath, mX, mY, glPG)
      If (hitA=1)
         ToggleThumbsMode()
      Return
   }

   If (thumbsDisplaying=1 && maxFilesIndex>0 && mainParam!="doubleclick")
   {
      ; handle clicks on thumbnails and the vertical scrollbar
      GetClientSize(mainWidth, mainHeight, PVhwnd)
      scrollXpos := mainWidth - imgHUDbaseUnit//2
      statusBarYpos := mainHeight - ThumbsStatusBarH
      If (mX>scrollXpos)
      {
         SetTimer, ThumbsScrollbar, -25
         Return
      } Else If (mY>statusBarYpos && noTooltipMSGs=0)
      {
         If (mainParam="rclick")
         {
            deleteMenus()
            createMenuCurrentFile()
            showThisMenu("PVtFile")
         } Else ToggleMultiLineStatus()
         Return
      }

      thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
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
      If (maxWidu<mX || maxHeitu<mY) || (newIndex && newIndex>maxFilesIndex)
      {
         If (mainParam="rclick")
            SetTimer, InitGuiContextMenu, -10
         Return
      }

      If (newIndex=currentFileIndex) && (A_TickCount - lastInvoked>350) && (mainParam!="rClick")
      {
         ToggleThumbsMode()
         Return
      }

      If newIndex
      {
         If (GetKeyState("Ctrl", "P") && mainParam!="rClick")
         {
            markThisFileNow(newIndex)
         } Else If (GetKeyState("Shift", "P") && mainParam!="rClick")
         {
            keyu := (newIndex>currentFileIndex) ? "Down" : "Upu"
            prevFileIndex := currentFileIndex
            currentFileIndex := newIndex
            thumbsSelector(keyu, "+Shift", prevFileIndex)
         } Else currentFileIndex := newIndex

         If (mainParam="rClick")
            DelayiedImageDisplay()
         Else
            dummyTimerDelayiedImageDisplay(25)
      }

      If (mainParam="rclick")
         SetTimer, InitGuiContextMenu, -10

      lastInvoked := A_TickCount
      Return
   }

   GetClientSize(mainWidth, mainHeight, PVhwnd)
   displayingImageNow := (thumbsDisplaying!=1) && (StrLen(gdiBitmap)>2 || StrLen(UserMemBMP)>2) ? 1 : 0
   If (mainParam="normal" && displayingImageNow=1 && IMGlargerViewPort=1 && IMGresizingMode=4 && (scrollBarHy>1 || scrollBarVx>1) && thumbsDisplaying!=1)
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
   && (displayingImageNow=1 && getCaptionStyle(PVhwnd)!=1 && mainParam="normal" && GetKeyState("LButton") && GetKeyState("Shift", "P"))
   {
      ; activate selection on single click + shift
      imgSelX2 := imgSelY2 := (IMGlargerViewPort=1) ? "C" : -1
      activateImgSelection := editingSelectionNow := 1
      dummyTimerDelayiedImageDisplay(50)
      Return
   }

   If (mainParam="normal" && editingSelectionNow=1 && activateImgSelection=1 && spaceState!=1 && displayingImageNow=1)
   {
      ; handle clicks on the image selection rectangle in the viewport
      mXoT := mX, mYoT := mY, dotsSize := SelDotsSize
      JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
      MouseGetPos, mXo, mYo
      nSelDotX  := selDotX,  nSelDotAx := selDotAx
      nSelDotY  := selDotY,  nSelDotAy := selDotAy
      nSelDotBx := selDotBx, nSelDotCx := selDotCx
      nSelDotBy := selDotBy, nSelDotCy := selDotCy
      nSelDotDx := selDotDx, nSelDotDy := selDotDy

      If (FlipImgH=1)
      {
         nSelDotX := mainWidth - selDotX - dotsSize
         nSelDotAx := mainWidth - selDotAx - dotsSize
         nSelDotBx := mainWidth - selDotBx - dotsSize
         nSelDotCx := mainWidth - selDotCx - dotsSize
         nSelDotDx := mainWidth - selDotDx - dotsSize
      }

      If (FlipImgV=1)
      {
         nSelDotY := mainHeight - selDotY - dotsSize
         nSelDotAy := mainHeight - selDotAy - dotsSize
         nSelDotBy := mainHeight - selDotBy - dotsSize
         nSelDotCy := mainHeight - selDotCy - dotsSize
         nSelDotDy := mainHeight - selDotDy - dotsSize
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
      } Else If (valueBetween(mXoT, nselDotDx, nselDotDx + dotsSize*2) && valueBetween(mYoT, nselDotDy, nselDotDy + dotsSize*2) && imgEditPanelOpened=1)
      {
         dotActive := 10
         DotPosX := imgSelX1
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
      ovPselRotation := vPselRotation
      tDotPosX := DotPosX
      tDotPosY := DotPosY

      nImgSelX1 := tImgSelX1 := imgSelX1
      nImgSelY1 := tImgSelY1 := imgSelY1
      nImgSelX2 := tImgSelX2 := imgSelX2
      nImgSelY2 := tImgSelY2 := imgSelY2
      timgSelW := max(nImgSelX1, nImgSelX2) - min(nImgSelX1, nImgSelX2)
      timgSelH := max(nImgSelY1, nImgSelY2) - min(nImgSelY1, nImgSelY2)
      tavg := (timgSelW + timgSelH)//2
      timgSelX2 := tImgSelX1 + tavg
      timgSelY2 := tImgSelY1 + tavg

      thisZeit := zX := zY := adjustNowSel := 1
      o_imageLoading := imageLoading
      If dotActive
         drawImgSelectionOnWindow("init", 0, 0, 0, mainWidth, mainHeight)
      newPosZeit := A_TickCount
      ctrlState := (GetKeyState("Ctrl", "P") && dotActive=9) ? 1 : 0
      While, (determineLClickstate()=1 && o_imageLoading!=1 && dotActive && ctrlState=0)
      {
          MouseGetPos, mX, mY, thisWind
          skipLoop := (valueBetween(mX, zX - 5, zX + 5) && valueBetween(mY, zY - 5, zY + 5)) ? 1 : 0
          If (A_TickCount - newPosZeit>950) ; || (mX=oX && mY=oY)
          {
             newPosZeit := A_TickCount
             zX := mX, zY := mY
             If (skipLoop=1)
                Continue
          } Else If (skipLoop=1)
             Continue

          changePosX := (zoomLevel>1) ? Round((mX - mXo)/zL) : Round((mX - mXo)*zL)
          changePosY := (zoomLevel>1) ? Round((mY - mYo)/zL) : Round((mY - mYo)*zL)
          If (dotActive=10)
          {
             rotAmount := changePosX/(mainWidth/2)
             rotAmount := rotAmount * 360
             vPselRotation := Round(ovPselRotation + rotAmount, 2)
             If (vPselRotation<0 || vPselRotation>360)
                vPselRotation := 360 - Abs(vPselRotation)

             If GetKeyState("Shift", "P") 
                vPselRotation := ovPselRotation + 45
             Else If GetKeyState("Alt", "P") 
                vPselRotation := 0
             vPselRotation := capValuesInRange(vPselRotation, 0, 360)
          }

          If GetKeyState("Shift", "P") && (dotActive=1 || dotActive=2 || dotActive=9)
          {
             If (dotActive=9)
             {
                maxPos := max(Abs(changePosX), Abs(changePosY))
                If (maxPos=Abs(changePosX))
                   changePosY := 0
                Else If (maxPos=Abs(changePosY))
                   changePosX := 0
             } Else If (FlipImgH!=1 && FlipImgV!=1)
             {
                If (changePosX<0 && changePosY<0)
                   changePosX := changePosY := - (Abs(changePosX)+Abs(changePosY))//2
                Else
                   changePosX := changePosY := (Abs(changePosX)+Abs(changePosY))//2
             }
          }

          newSelDotX := (FlipImgH=1) ? tDotPosX - changePosX : tDotPosX + changePosX
          newSelDotY := (FlipImgV=1) ? tDotPosY - changePosY : tDotPosY + changePosY
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
          If (imgSelX1=imgSelX2)
             imgSelX2 += 2
          If (imgSelY1=imgSelY2)
             imgSelY2 += 2

          imgSelW := max(ImgSelX1, ImgSelX2) - min(ImgSelX1, ImgSelX2)
          imgSelH := max(ImgSelY1, ImgSelY2) - min(ImgSelY1, ImgSelY2)
          If GetKeyState("Alt", "P") && (dotActive=1 || dotActive=2 || dotActive=9)
          {
             avg := (imgSelW+imgSelH)//2
             If (dotActive=9)
             {
                cAvg := (changePosX+changePosY)//2
                imgSelX2 := timgSelX2 + cAvg
                imgSelY2 := timgSelY2 + cAvg
                imgSelX1 := timgSelX1 - cAvg
                imgSelY1 := timgSelY1 - cAvg
             } Else If (dotActive=2)
             {
                imgSelX2 := imgSelX1 + avg
                imgSelY2 := imgSelY1 + avg
             } Else
             {
                imgSelX1 := imgSelX2 - avg
                imgSelY1 := imgSelY2 - avg

             }
             imgSelW := max(ImgSelX1, ImgSelX2) - min(ImgSelX1, ImgSelX2)
             imgSelH := max(ImgSelY1, ImgSelY2) - min(ImgSelY1, ImgSelY2)
          }

          If (A_TickCount - thisZeit>25)
          {
             If (valueBetween(dotActive, 1, 4) && noTooltipMSGs=0 && minimizeMemUsage!=1)
             {
                ARGBdec := Gdip_GetPixel(gdiBitmap, newSelDotX, newSelDotY)
                Gdip_FromARGB(ARGBdec, cA, cR, cG, cB)
                pixelColor := cR ", " cG ", " cB ", " cA
                addMsg := "`n `nCorner coordinates:`nX / Y: " newSelDotX ", " newSelDotY "`nColor: " pixelColor

             }
             theRatio := "`nRatio: " Round(imgSelW/imgSelH, 2)
             If (imgEditPanelOpened=1)
                theRatio .= "`nRotation: " Round(vPselRotation, 2) "° "
             theMsg := "X / Y: " ImgSelX1 ", " ImgSelY1 "`nW / H: " imgSelW ", " imgSelH theRatio addMsg
             ; ToolTip, % theMsg, % mainX + 10, % mainY + 10
             drawImgSelectionOnWindow("live", theMsg, ARGBdec, dotActive, mainWidth, mainHeight)
             thisZeit := A_TickCount
          }
      }
      adjustNowSel := 0
      If dotActive
         drawImgSelectionOnWindow("end")

      ToolTip
      If (dotActive=9 && valueBetween(Abs(changePosY), 0, 2) && valueBetween(Abs(changePosX), 0, 2))
      {
         If (A_TickCount - anotherZeit<300) 
            thisZeit := dotActive := ctrlState := 0
         anotherZeit := A_TickCount
      }
      If (dotActive || (A_TickCount - thisZeit<150)) && (ctrlState=0)
         Return
   }

   If (mainParam="doubleclick" && thumbsDisplaying!=1 && displayingImageNow=1 && spaceState!=1 && imageLoading!=1) && (A_TickCount - lastInvokedSwipe>600)
   {
      ; handle double clicks in the viewport when an image is being displayed
      If (activateImgSelection=1 && imgEditPanelOpened!=1)
      {
         lastInvoked := A_TickCount
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
         Else
            ToggleViewModeTouch()
         lastInvoked := A_TickCount
         Return
      }
      lastInvoked := A_TickCount
      If (slideShowRunning=1)
         ToggleSlideShowu()
      Sleep, 1
      ToggleViewModeTouch()
   } Else If (maxFilesIndex>1 && CurrentSLD) && (A_TickCount - thisZeit>950)
   {
      ; handle single clicks in the viewport when multiple files are loaded
      didSomething := 1
      If (TouchScreenMode=0 || spaceState=1) && (IMGlargerViewPort=1 && thumbsDisplaying!=1)
         SetTimer, panIMGonClick, -25
      Else If (TouchScreenMode=1)
         didSomething := winSwipeAction(thisCtrlClicked)

      lastInvoked := A_TickCount
      If didSomething
         lastInvokedSwipe := A_TickCount
   } Else If (!CurrentSLD || maxFilesIndex<1) && (A_TickCount - thisZeit>950)
   {
      ; when no image is loaded, on click, open files dialog
      lastInvoked := A_TickCount
      If StrLen(UserMemBMP)>2
         Return

      SetTimer, drawWelcomeImg, Off
      Sleep, 5
      OpenDialogFiles()
   }
   lastInvoked := A_TickCount
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
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked < 50)
       Return

    lastInvoked := A_TickCount
    resetSlideshowTimer(0)
    IMGdecalageX := IMGdecalageX := 1
    IMGresizingMode++
    If (IMGresizingMode>4)
       IMGresizingMode := 1

    friendly := DefineImgSizing()
    showTOOLtip("Rescaling mode: " friendly)
    SetTimer, RemoveTooltip, % -msgDisplayTime
    INIaction(1, "IMGresizingMode", "General")
    dummyTimerDelayiedImageDisplay(50)
}

DefineImgSizing() {
   friendly := (IMGresizingMode=1) ? "ADAPT ALL INTO VIEW" : "ADAPT ONLY LARGE IMAGES"
   If (IMGresizingMode=3)
      friendly := "NONE (ORIGINAL SIZE)"
   Else If (IMGresizingMode=4)
      friendly := "CUSTOM ZOOM: " Round(zoomLevel * 100) "%"

   Return friendly
}

dummyInfoToggleSlideShowu(actu:=0) {
  Static lastInvoked := 1

  ToggleSlideShowu(actu)
  If (slideShowRunning!=1 || actu="stop")
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
  Return
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
     SetTimer, dummyInfoToggleSlideShowu, -80
  Return
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
     ; SendEvent, {Up}
  }
}

ToggleSlideShowu(actu:=0) {
  If (slideShowRunning=1 || actu="stop") && (actu!="start")
  {
     slideShowRunning := 0
     ; SetTimer, theSlideShowCore, Off
     prevSlideShowStop := A_TickCount
     interfaceThread.ahkFunction("slideshowsHandler", 0, "stop", SlideHowMode)
  } Else If (thumbsDisplaying!=1 || actu="start")
  {
     If (A_TickCount - prevSlideShowStop<500) && (actu!="start")
        Return

     activateImgSelection := editingSelectionNow := 0
     slideShowRunning := 1
     If (hSNDmediaFile && hSNDmediaDuration && hSNDmedia)
        milisec := MCI_Length(hSNDmedia) 

     thisSlideSpeed := (milisec>slideShowDelay) ? milisec : slideShowDelay
     interfaceThread.ahkFunction("slideshowsHandler", thisSlideSpeed, "start", SlideHowMode)
     ; SetTimer, theSlideShowCore, % thisSlideSpeed
  }
  Return
}

theSlideShowCore() {
  If (SlideHowMode=1)
     RandomPicture()
  Else If (SlideHowMode=2)
     PreviousPicture()
  Else If (SlideHowMode=3)
     NextPicture()
  Return
}

GoNextSlide() {
  Sleep, 15
  If GetKeyState("LButton")
  {
     SetTimer, GoNextSlide, -100
     Return
  }

  resetSlideshowTimer(0)
  If (SlideHowMode=1)
     RandomPicture()
  Else
     NextPicture()
}

GoPrevSlide() {
  Sleep, 15
  If GetKeyState("LButton")
  {
     SetTimer, GoPrevSlide, -100
     Return
  }

  resetSlideshowTimer(0)
  If (SlideHowMode=1)
     PrevRandyPicture()
  Else
     PreviousPicture()
}

coreSecToHHMMSS(Seco, ByRef Hrs, ByRef Min, ByRef Sec) {
  OldFormat := A_FormatFloat
  SetFormat, Float, 2.00
  Hrs := Seco//3600/1
  Min := Mod(Seco//60, 60)/1
  SetFormat, Float, %OldFormat%
  Sec := Round(Mod(Seco, 60), 2)
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
  r := StrReplace(r, ".00s", "s")
  If (min || hrs)
     r := RegExReplace(r, "\...s", "s")
  r := StrReplace(r, " 0s")
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
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50) || (thumbsDisplaying=1)
      Return

   lastInvoked := A_TickCount
   SlideHowMode++
   If (SlideHowMode>3)
      SlideHowMode := 1

   resetSlideshowTimer(0, 1)
   friendly := DefineSlideShowType() "`nCurrently "
   friendly .= (slideShowRunning=1) ? "running" : "stopped"
   showTOOLtip("Slideshow mode: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   INIaction(1, "SlideHowMode", "General")
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

   If (imgFxMode=1 && valueBetween(usrColorDepth, 2, 5))
      friendly := "ALTERED COLOR DEPTH"

   If (imgFxMode=1 && RenderOpaqueIMG=1 && InStr(currentPixFmt, "argb"))
      friendly .= "`nAlpha channel: REMOVED"

   Return friendly
}

ToggleImgColorDepth(dir:=0) {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked < 50) || (thumbsDisplaying=1 && thumbnailsListMode=1)
       Return

   lastInvoked := A_TickCount
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

   usrColorDepth := capValuesInRange(usrColorDepth, 1, 9, 1)
   ForceRefreshNowThumbsList()
   infoColorDepth := (usrColorDepth>1) ? defineColorDepth() : "NONE"
   showTOOLtip("Image color depth simulated: " infoColorDepth)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   INIaction(1, "usrColorDepth", "General")
   INIaction(1, "imgFxMode", "General")
   SetTimer, RefreshImageFile, -50
}

defineColorDepth() {
   Static bitsOptions := {0:0, 1:0, 2:2, 3:3, 4:4, 5:5, 6:6, 7:7, 8:8, 9:16}

   internalColorDepth := bitsOptions[usrColorDepth]
   r := internalColorDepth " bits [" 2**internalColorDepth " colors]"
   If (r<1)
      r := currentPixFmt
   Else If (ColorDepthDithering=1)
      r .= " | DITHERED"

   Return r
}

ToggleImgFX(dir:=0) {
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50) || (thumbsDisplaying=1 && thumbnailsListMode=1)
      Return

   lastInvoked := A_TickCount
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

   imgFxMode := capValuesInRange(imgFxMode, 1, 9, 1)
   friendly := DefineFXmodes()
   If (imgFxMode=4)
      friendly .= "`nBrightness: " Round(lumosGrayAdjust, 3) "`nContrast: " Round(GammosGrayAdjust, 3) "`nVibrance: " Round(zatAdjust) "%" "`nHue: " Round(hueAdjust) "°"
   Else If (imgFxMode=2)
      friendly .= "`nBrightness: " Round(lumosAdjust, 3) "`nContrast: " Round(GammosAdjust, 3) "`nSaturation: " Round(satAdjust*100) "%" "`nVibrance: " Round(zatAdjust) "%" "`nHue: " Round(hueAdjust) "°"
   Else If (imgFxMode=3 || imgFxMode=9)
      friendly .= "`nVibrance: " Round(zatAdjust) "%" "`nHue: " Round(hueAdjust) "°"
   If (usrColorDepth>1 && imgFxMode=1)
      friendly .= "`nSimulated color depth: " defineColorDepth()

   If (imgFxMode=4 || imgFxMode=3 || imgFxMode=2)
      friendly .= "`n `nPress U to adjust colors display options."
   showTOOLtip("Image colors: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   ForceRefreshNowThumbsList()

   If (imgFxMode=3 && thumbsDisplaying!=1)
   {
      imgPath := getIDimage(currentFileIndex)
      AdaptiveImgLight(gdiBitmap, imgPath, 1, 1)
   }

   INIaction(1, "imgFxMode", "General")
   If (o_bwDithering=0)
      o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0

   If (o_bwDithering=1 && thumbsDisplaying!=1)
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
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50)
      Return

   lastInvoked := A_TickCount
   If (thumbsDisplaying=1 || IMGresizingMode=4)
      Return

   resetSlideshowTimer(0)
   imageAligned++
   If (imageAligned>9)
      imageAligned := 1

   showTOOLtip("Image alignment: " defineImgAlign())
   SetTimer, RemoveTooltip, % -msgDisplayTime
   INIaction(1, "imageAligned", "General")
   dummyTimerDelayiedImageDisplay(50)
}

toggleColorAdjustments() {
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50)
      Return

  lastInvoked := A_TickCount
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

coreResetIMGview(dummy:=0) {
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
  If (dummy="k")
     vpIMGrotation := 0

  If (imgFxMode=2 || imgFxMode=3 || imgFxMode>4 || mustResetFxMode=1)
     imgFxMode := 1

  If (thumbsDisplaying=1)
  {
     thumbsZoomLevel := 1
     thumbsH := othumbsH + 1
     thumbsW := othumbsW + 1
     ForceRefreshNowThumbsList()
  }

  If (dummy="k")
     usrColorDepth := internalColorDepth := 1
}

ChangeLumos(dir, dummy:=0) {
   Static prevValues

   If (thumbsDisplaying=1 && thumbnailsListMode=1)
      Return

   resetSlideshowTimer(0)
   If (imgFxMode!=2 && imgFxMode!=4 && dir!=2)
      imgFxMode := 2

   prevColorAdjustZeit := A_TickCount
   o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
   If (dir=2)
   {
      coreResetIMGview(dummy)
      SetTimer, WriteSettingsColorAdjustments, -95
   } Else If (imgFxMode=4)
   {
      If (dir=1)
         lumosGrayAdjust += 0.05
      Else
         lumosGrayAdjust -= 0.05

      lumosGrayAdjust := capValuesInRange(lumosGrayAdjust, 0.001, 25)
   } Else
   {
      stepu := (lumosAdjust<=1) ? 0.05 : 0.1
      If (dir=1)
         lumosAdjust += stepu
      Else
         lumosAdjust -= stepu

      lumosAdjust := capValuesInRange(lumosAdjust, 0.001, 25)
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
      If (thisIMGisDownScaled=1)
         addMsg .= "`nImage dimensions DOWNSCALED to screen resolution."
      addMsg .= defineIMGmirroring()
      showTOOLtip("Image display: UNALTERED " addMsg " `n`nTo reset all adjustments to`ntheir defaults press Ctrl + \")
   } Else showTOOLtip("Image brightness: " value2show)

   ; If (thumbsDisplaying!=1)
      ForceRefreshNowThumbsList()
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust GammosAdjust lumosAdjust imgFxMode
   If (prevValues=newValues && dir!=2)
      Return

   If (dir!=2)
      SetTimer, dummySaveLumGammos, -70

   prevValues := newValues
   If (o_bwDithering=1 || otherFX=1) ; && (thumbsDisplaying!=1)
      SetTimer, RefreshImageFile, -50
   Else
      dummyTimerDelayiedImageDisplay(10)
}

WriteSettingsColorAdjustments() {
    INIaction(1, "userimgQuality", "General")
    INIaction(1, "usrTextureBGR", "General")
    INIaction(1, "autoAdjustMode", "General")
    INIaction(1, "doSatAdjusts", "General")
    INIaction(1, "usrAdaptiveThreshold", "General")
    INIaction(1, "showHistogram", "General")
    INIaction(1, "IMGresizingMode", "General")
    INIaction(1, "imgThreshold", "General")
    INIaction(1, "bwDithering", "General")
    INIaction(1, "usrColorDepth", "General")
    INIaction(1, "ColorDepthDithering", "General")
    INIaction(1, "imgFxMode", "General")
    INIaction(1, "chnBdecalage", "General")
    INIaction(1, "chnGdecalage", "General")
    INIaction(1, "chnRdecalage", "General")
    INIaction(1, "FlipImgH", "General")
    INIaction(1, "FlipImgV", "General")
    INIaction(1, "GammosAdjust", "General")
    INIaction(1, "GammosGrayAdjust", "General")
    INIaction(1, "hueAdjust", "General")
    INIaction(1, "lumosAdjust", "General")
    INIaction(1, "lumosGrayAdjust", "General")
    INIaction(1, "realGammos", "General")
    INIaction(1, "RenderOpaqueIMG", "General")
    INIaction(1, "satAdjust", "General")
    INIaction(1, "vpIMGrotation", "General")
    INIaction(1, "zatAdjust", "General")
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

ChangeZoom(dir, key:=0, stepFactor:=1) {
   Static prevValues, lastInvoked := 1

   If InStr(key, "wheel")
   {
      MouseGetPos, , , OutputVarWin
      If (OutputVarWin!=PVhwnd)
         Return
   }

   resetSlideshowTimer(0)
   If (thumbsDisplaying=1)
   {
      If (thumbnailsListMode=1)
      {
         changeOSDfontSize(dir)
         Return
      }
      If (dir=1)
         thumbsZoomLevel += 0.1
      Else
         thumbsZoomLevel -= 0.1

      thumbsZoomLevel := capValuesInRange(thumbsZoomLevel, 0.35, 3)
      ForceRefreshNowThumbsList()
      recalculateThumbsSizes()
      ; setTexHatchScale(thumbsZoomLevel/2)
      If (thumbnailsListMode=1)
         ForceRefreshNowThumbsList()
      INIaction(1, "thumbsZoomLevel", "General")
      showTOOLtip("Thumbnails zoom level: " Round(thumbsZoomLevel*100) "%`nDisplay size: " thumbsW " x " thumbsH " px`nThumbnails cache at: " thumbsSizeQuality " px")
      SetTimer, RemoveTooltip, % -msgDisplayTime
      dummyTimerDelayiedImageDisplay(95)
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
      zoomLevel += changeFactor * stepFactor
   Else
      zoomLevel -= changeFactor * stepFactor

   o_IMGresizingMode := IMGresizingMode
   IMGresizingMode := 4
   imageAligned := 5
   zoomLevel := capValuesInRange(zoomLevel, 0.01, 20)
   prevGDIvpCache := Gdip_DisposeImage(prevGDIvpCache, 1)

   If (zoomLevel>3 && thisIMGisDownScaled=1 && AutoDownScaleIMGs=1)
   {
      imgPath := getIDimage(currentFileIndex)
      op := GetImgFileDimension(imgPath, Wi, He)
      Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
      xu := (imgW*zoomLevel)/Wi
      hasThisChangedYo := 1
      zoomLevel := xu
      AutoDownScaleIMGs := 2
   }

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
   ; setTexHatchScale(zoomLevel)
   If (thisIMGisDownScaled=1)
      friendly := "`nThe image is downscaled.`nPress F5 or increase zoom above 300%`nto load the original file."

   showTOOLtip("Zoom level: " Round(zoomLevel*100) "%" friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime

   newValues := "a" zoomLevel thumbsZoomLevel IMGresizingMode imageAligned getIDimage(currentFileIndex)
   If (prevValues=newValues && hasThisChangedYo!=1)
      Return

   prevValues := newValues
   If (drawModeBzeit>150 && (A_TickCount - lastInvoked < 10) && (LastPrevFastDisplay!=1)) || (hasThisChangedYo=1)
      GdipCleanMain(6)

   lastInvoked := A_TickCount
   If (AutoDownScaleIMGs=2 && hasThisChangedYo=1)
      SetTimer, RefreshImageFileAction, -150
   Else If (o_IMGresizingMode=1 && enableThumbsCaching=1) || (LastPrevFastDisplay=1)
      SetTimer, coreReloadThisPicture, -10
   Else
      dummyTimerDelayiedImageDisplay(10)
}


setTexHatchScale(zL, forceIT:=0) {
   Static prevScaleTex
   If !pBrushHatch
      Return

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
      value2Adjust += 0.05
      value2AdjustB -= 0.05
   } Else
   {
      value2Adjust -= 0.05
      value2AdjustB += 0.05
   }

   value2Adjust := capValuesInRange(value2Adjust, -25, 1)
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
   ; If (thumbsDisplaying!=1)
      ForceRefreshNowThumbsList()
   showTOOLtip("Image contrast: " Round(value2Adjust, 3))
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust GammosAdjust lumosAdjust imgFxMode
   If (prevValues=newValues)
      Return

   SetTimer, dummySaveLumGammos, -70
   prevValues := newValues
   If (o_bwDithering=1)
      SetTimer, RefreshImageFile, -50
   Else
      dummyTimerDelayiedImageDisplay(10)
}

dummySaveLumGammos() {
   INIaction(1, "GammosAdjust", "General")
   INIaction(1, "GammosGrayAdjust", "General")
   INIaction(1, "lumosAdjust", "General")
   INIaction(1, "lumosGrayAdjust", "General")
   INIaction(1, "imgFxMode", "General")
}

ChangeSaturation(dir) {
   Static prevValues

   resetSlideshowTimer(0)
   If (imgFxMode=4)
      satAdjust := 0

   imgFxMode := 2
   prevColorAdjustZeit := A_TickCount
   value2Adjust := satAdjust
   If (dir=1)
      value2Adjust += 0.05
   Else
      value2Adjust -= 0.05

   value2Adjust := capValuesInRange(value2Adjust, 0, 3)
   satAdjust := value2Adjust
   ; If (thumbsDisplaying!=1)
      ForceRefreshNowThumbsList()
   showTOOLtip("Image saturation: " Round(value2Adjust*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" satAdjust imgFxMode
   If (prevValues=newValues)
      Return

   INIaction(1, "satAdjust", "General")
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
      value2Adjust += stepu
   Else
      value2Adjust -= stepu

   value2Adjust := capValuesInRange(value2Adjust, 0.01, 8)
   realGammos := value2Adjust
   ; If (thumbsDisplaying!=1)
      ForceRefreshNowThumbsList()
   showTOOLtip("Image gamma: " Round(value2Adjust*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" realGammos imgFxMode
   If (prevValues=newValues)
      Return

   INIaction(1, "realGammos", "General")
   prevValues := newValues
   dummyTimerDelayiedImageDisplay(10)
}

ChangeVolume(dir) {
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50)
      Return

   lastInvoked := A_TickCount
   If (thumbsDisplaying=1)
      Return

   resetSlideshowTimer(0, 1)
   value2Adjust := mediaSNDvolume
   If (dir=1)
      value2Adjust += 5
   Else
      value2Adjust -= 5

   value2Adjust := capValuesInRange(value2Adjust, 1, 100)
   If !hSNDmedia
      infoMedia := "`nNo audio is currently playing..."

   mediaSNDvolume := value2Adjust
   INIaction(1, "mediaSNDvolume", "General")
   SetVolume(mediaSNDvolume)
   showTOOLtip("Audio volume: " value2Adjust "%" infoMedia)
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

MenuChangeImgRotationInVP() {
   changeImgRotationInVP(1, 45)
}

changeSelRotation(dir) {
   If (thumbsDisplaying=1 || imgEditPanelOpened!=1)
      Return

   resetSlideshowTimer(0)
   value2Adjust := vPselRotation
   If (dir=1)
      value2Adjust += 2
   Else
      value2Adjust -= 2

   value2Adjust := capValuesInRange(value2Adjust, 0, 360 - 2, 1)
   vPselRotation := value2Adjust
   SetTimer, dummyRefreshImgSelectionWindow, -10
}

changeImgRotationInVP(dir, stepu:=15) {
   If (thumbsDisplaying=1)
      Return

   resetSlideshowTimer(0)
   value2Adjust := vpIMGrotation
   If (dir=1)
      value2Adjust += stepu
   Else
      value2Adjust -= stepu

   value2Adjust := capValuesInRange(value2Adjust, 0, 360 - stepu, 1)
   vpIMGrotation := value2Adjust
   SetTimer, dummyChangeVProtation, -10
   SetTimer, RefreshImageFile, -750
}

dummyChangeVProtation() {
   showTOOLtip("Image rotation: " vpIMGrotation "° ")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   INIaction(1, "vpIMGrotation", "General")
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

   DestroyGIFuWin()
   resetSlideshowTimer(0)
   value2Adjust := desiredFrameIndex
   If (dir=1)
      value2Adjust++
   Else
      value2Adjust--

   If (dir=-1 && value2Adjust<1)
      value2Adjust := 0

   value2Adjust := capValuesInRange(value2Adjust, 0, totalFramesIndex, 1)
   desiredFrameIndex := value2Adjust
   If (A_TickCount - lastInvoked > 350) || (dir-1)
   {
      showTOOLtip("Image frame index: " value2Adjust " / " totalFramesIndex)
      SetTimer, RemoveTooltip, % -msgDisplayTime
      lastInvoked := A_TickCount
   } Else SetTimer, showCurrentFrameIndex, -400

   newValues := value2Adjust currentFileIndex
   If (prevValues!=newValues)
   {
      SetTimer, RefreshImageFile, % (dir=-1) ? -95 : -5
      prevValues := newValues
   }
}

autoChangeDesiredFrame(act:=0, imgPath:=0) {
   Critical, on
   Static prevImgPath, lastInvoked := 1, lastFrameChange := 1

   If (thumbsDisplaying=1 || act="stop" || AnyWindowOpen || animGIFsSupport!=1)
   {
      If (animGIFplaying=1)
      {
         SetTimer, autoChangeDesiredFrame, Off
         SetTimer, ResetImgLoadStatus, -10
         prevAnimGIFwas := prevImgPath
         Global lastGIFdestroy := A_TickCount
         lastFrameChange := A_TickCount
         animGIFplaying := 0
         ; lastInvoked := A_TickCount
         interfaceThread.ahkassign("animGIFplaying", 0)
         ; dummyTimerDelayiedImageDisplay(50)
      }
      Return
   }
   
   If (prevImgPath!=imgPath && StrLen(imgPath)>2)
      lastInvoked := A_TickCount

   If (act="start" && imgPath && prevImgPath!=imgPath)
   {
      SetTimer, ResetImgLoadStatus, -15
      lastFrameChange := A_TickCount
      prevImgPath := imgPath
      animGIFplaying := 1
      interfaceThread.ahkassign("animGIFplaying", 1)
      Return
   } Else
   {
      Sleep, -1
      animGIFplaying := interfaceThread.ahkgetvar.animGIFplaying
      If !animGIFplaying
      {
         SetTimer, ResetImgLoadStatus, -10
         SetTimer, autoChangeDesiredFrame, Off
         animGIFplaying := 0
         prevAnimGIFwas := prevImgPath
         lastFrameChange := A_TickCount
         Global lastGIFdestroy := A_TickCount
         Return
      }
   }

   allowSkip := 0
   desiredFrameIndex++
   If (allowGIFsPlayEntirely=1 && desiredFrameIndex>totalFramesIndex-1) || (totalFramesIndex<3) || (allowGIFsPlayEntirely!=1)
      allowSkip := 1

   desiredFrameIndex := capValuesInRange(desiredFrameIndex, 0, totalFramesIndex, 1)
   prevAnimGIFwas := ""
   totalZeit := A_TickCount - startZeitIMGload
   thisFrameDelay := (totalZeit>25 && totalFramesIndex>20) ? GIFspeedDelay//2 : GIFspeedDelay
   If (totalZeit>70 && totalFramesIndex>15) || (totalZeit>25 && totalFramesIndex>180)
      thisFrameDelay := 1

   If (slideShowRunning=1) && (A_TickCount - lastInvoked>slideShowDelay) && (allowSkip=1)
   {
      allowSkip := 0
      lastInvoked := A_TickCount
      theSlideShowCore()
   } Else If (A_TickCount - lastFrameChange > thisFrameDelay)
   {
      lastFrameChange := A_TickCount
      SetTimer, RefreshImageFile, -2
   }
}

showCurrentFrameIndex() {
    showTOOLtip("Image frame index: " desiredFrameIndex " / " totalFramesIndex)
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

TransformIMGv() {
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50)
      Return

   lastInvoked := A_TickCount
   resetSlideshowTimer(0)
   ForceRefreshNowThumbsList()
   FlipImgV := !FlipImgV
   friendly := (FlipImgV=1) ? "ON" : "off"
   showTOOLtip("Vertical mirroring: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   INIaction(1, "FlipImgV", "General")
   dummyTimerDelayiedImageDisplay(50)
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
   Static lastInvoked := 1
   If (A_TickCount - lastInvoked < 50)
      Return

   lastInvoked := A_TickCount
   resetSlideshowTimer(0)
   ForceRefreshNowThumbsList()
   FlipImgH := !FlipImgH
   friendly := (FlipImgH=1) ? "ON" : "off"
   showTOOLtip("Horizontal mirroring: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   INIaction(1, "FlipImgH", "General")
   dummyTimerDelayiedImageDisplay(50)
}

PreviousPicture(dummy:=0, inLoop:=0, selForbidden:=0) {
   If (StrLen(UserMemBMP)>2 && activateImgSelection=1 && InStr(dummy, "key-wheel"))
      Return

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
   If (StrLen(UserMemBMP)>2 && activateImgSelection=1 && InStr(dummy, "key-wheel"))
      Return

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

drawTextInBox(theString, fntName, theFntSize, maxW, maxH, txtColor, bgrColor, NoWrap, flippable:=0, thisTextAlign:=0, units:=2) {
    hdc := CreateCompatibleDC()
    hbmp := CreateDIBSection(maxW + 1, maxH + 1, hdc)
    obm := SelectObject(hdc, hbmp)

    G := Gdip_GraphicsFromHDC(hdc, 7, 4)
    pBr0 := Gdip_BrushCreateSolid(bgrColor)
    Gdip_FillRectangle(G, pBr0, -2, -2, maxW + 4, maxH + 4)
    If (FontBolded=1)
       txtStyle .= " Bold"
    If (FontItalica=1 && NoWrap=0)
       txtStyle .= " Italic"
    Else If (NoWrap=1)
       txtStyle .= " NoWrap"

    If !thisTextAlign
       thisTextAlign := (flippable=1 && FlipImgH=1) ? "Right" : "Left"
    Else
       thisTextAlign := Trim(thisTextAlign)

    borderSize := (NoWrap=1) ? Floor(theFntSize*1.15) : Floor(theFntSize*1.45)
    borderSize := borderSize//3
    txtOptions := "x" borderSize " y" borderSize A_Space thisTextAlign " cEE" txtColor " r4 s" theFntSize txtStyle
    dimensions := Gdip_TextToGraphics(G, theString, txtOptions, fntName, maxW - borderSize*2, maxH - borderSize*2, 0, 0, units)
    txtRes := StrSplit(dimensions, "|")
    txtResW := Ceil(txtRes[3]) + borderSize*2
    If (txtResW>maxW)
       txtResW := maxW
    txtResH := Ceil(txtRes[4]) + borderSize*2
    If (txtResH>maxH)
       txtResH := maxH
    clipBMPa := Gdip_CreateBitmapFromHBITMAP(hbmp)
    clipBMP := Gdip_CloneBitmapArea(clipBMPa, 0, 0, txtResW, txtResH)
    txtRes := []

    Gdip_DisposeImage(clipBMPa, 1)
    If (flippable=1)
       flipBitmapAccordingToViewPort(clipBMP, 1)

    Gdip_DeleteGraphics(G)
    Gdip_DeleteBrush(pBr0)
    SelectObject(hdc, obm)
    DeleteObject(hbmp)
    DeleteDC(hdc)
    Return clipBMP
}

drawHistogram(dataArray, maxYlimit, LengthX, Scale, fgrColor, bgrColor, borderSize, infoBoxBMP) {
    graphPath := Gdip_CreatePath()
    graphHeight := 300 ; graph height
    barWidth := 2

    PointsList .= -1 "," graphHeight + 1 "|"
    Loop, % LengthX
    {
        skipThis := 0
        y1 := dataArray[A_Index - 1]/maxYlimit
        If !y1
        {
           y1 := 0
           skipThis := 1
        }

        y1 := graphHeight - Round(graphHeight * y1)
        If (y1<0)
           y1 := 0
        Else If (y1>graphHeight - 1) && (skipThis=0)
           y1 := graphHeight - 1
        thisIndex := A_Index * barWidth - barWidth
        PointsList .= thisIndex - 1 ","  y1 "|" thisIndex ","  y1 "|"
    }

    PointsList .= thisIndex + 1 "," graphHeight + 1
    Gdip_AddPathClosedCurve(graphPath, PointsList, 0.000001)
    pMatrix := Gdip_CreateMatrix()
    Gdip_ScaleMatrix(pMatrix, Scale/2, Scale/2, 1)
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

PasteInPlaceNow() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    If (UserMemBMP!=whichBitmap)
       whichBitmap := Gdip_CloneBitmapArea(whichBitmap)

    thisImgQuality := (PasteInPlaceQuality=1) ? 7 : 5
    G2 := Gdip_GraphicsFromImage(whichBitmap, thisImgQuality, 4)
    corePasteInPlaceActNow(G2, whichBitmap)
    Gdip_DeleteGraphics(G2)
    userClipBMPpaste := Gdip_DisposeImage(userClipBMPpaste, 1)
    UserMemBMP := whichBitmap
    SetTimer, RefreshImageFile, -25
}

corePasteInPlaceActNow(G2:=0, whichBitmap:=0) {
    Static prevImgCall, prevClipBMP
    If (G2)
    {
       clipBMP := userClipBMPpaste
       flipBitmapAccordingToViewPort(clipBMP, 1)
       Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
       calcImgSelection2bmp(1, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       thisImgQuality := (PasteInPlaceQuality=1) ? 7 : 5
       prevClipBMP := Gdip_DisposeImage(prevClipBMP, 1)
    } Else
    {
       G2 := 2NDglPG
       thisImgQuality := 5
       Gdip_SetInterpolationMode(2NDglPG, thisImgQuality)
       Gdip_GraphicsClear(2NDglPG, "0x00" WindowBGRcolor)
       ; Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
       ; calcImgSelection2bmp(1, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       imgSelPx := x1 := selDotX + SelDotsSize//2, x2 := selDotAx + SelDotsSize//2
       imgSelPy := y1 := selDotY + SelDotsSize//2, y2 := selDotAy + SelDotsSize//2
       imgSelW := max(X1, X2) - min(X1, X2)
       imgSelH := max(Y1, Y2) - min(Y1, Y2)
       thisImgCall := getIDimage(currentFileIndex) currentFileIndex viewportStampBMP PasteInPlaceBlurAmount PasteInPlaceOrientation PasteInPlaceAngle
       If (prevImgCall=thisImgCall)
       {
          hasCached := 1
          clipBMP := prevClipBMP
       } Else
       {
          prevClipBMP := Gdip_DisposeImage(prevClipBMP, 1)
          clipBMP := Gdip_CloneBitmap(viewportStampBMP)
       }
    }

    If (hasCached!=1)
    {
       If (PasteInPlaceOrientation=2)
          Gdip_ImageRotateFlip(clipBMP, 4)
       Else If (PasteInPlaceOrientation=3)
          Gdip_ImageRotateFlip(clipBMP, 6)
       Else If (PasteInPlaceOrientation=4)
          Gdip_ImageRotateFlip(clipBMP, 2)

       If (G2!=2NDglPG && !AnyWindowOpen && PasteInPlaceBlurAmount>0)
       {
          pEffect := Gdip_CreateEffect(1, PasteInPlaceBlurAmount, 0, 0)
          Gdip_BitmapApplyEffect(clipBmp, pEffect)
          Gdip_DisposeEffect(pEffect)
       }

       If (PasteInPlaceIgnoreRotation!=1 && PasteInPlaceAngle>0)
       {
          xBitmap := Gdip_RotateBitmapAtCenter(clipBMP, PasteInPlaceAngle,"", thisImgQuality)
          If (G2=2NDglPG && AnyWindowOpen)
             clipBMP := Gdip_DisposeImage(clipBMP, 1)
          clipBMP := xBitmap
       }
    }

    Gdip_GetImageDimensions(clipBMP, oImgW, oImgH)
    calcIMGdimensions(oImgW, oImgH, imgSelW, imgSelH, ResizedW, ResizedH)
    If (AnyWindowOpen && G2=2NDglPG)
    {
       Gdip_GetImageDimensions(userClipBMPpaste, qImgW, qImgH)
       isSmaller := (PasteInPlaceMode=1 && qImgW*zoomLevel<=imgSelW && qImgH*zoomLevel<=imgSelH) ? 1 : 0
    } Else isSmaller := (PasteInPlaceMode=1 && oImgW<=imgSelW && oImgH<=imgSelH) ? 1 : 0

    If (PasteInPlaceMode=4 || isSmaller=1)
    {
       ResizedW := oImgW
       ResizedH := oImgH
       If (AnyWindowOpen && G2=2NDglPG)
       {
          If (PasteInPlaceMode=4)
          {
             Gdip_GetImageDimensions(userClipBMPpaste, ResizedW, ResizedH)
             If (PasteInPlaceOrientation=5 && PasteInPlaceAngle>0)
                Gdip_GetRotatedDimensions(ResizedW, ResizedH, PasteInPlaceAngle, ResizedW, ResizedH)
          }
          ResizedW := ResizedW * zoomLevel
          ResizedH := ResizedH * zoomLevel
       }
    } Else If (PasteInPlaceMode=3)
    {
       ResizedW := imgSelW
       ResizedH := imgSelH
    }

    pPath := Gdip_CreatePath()
    Gdip_AddPathEllipse(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
    If (EllipseSelectMode=1)
       Gdip_SetClipPath(G2, pPath, 0)

    If (PasteInPlaceCentered=1)
    {
       If (ResizedW<imgSelW)
          imgSelPx += (imgSelW - ResizedW)//2
       If (ResizedH<imgSelH)
          imgSelPy += (imgSelH - ResizedH)//2
    }

    If (EllipseSelectMode!=1)
       Gdip_ResetClip(G2)

    thisOpacity := PasteInPlaceOpacity/255
    imageAttribs := Gdip_CreateImageAttributes()
    Gdip_SetImageAttributesColorMatrix("1|0|0|0|0|0|1|0|0|0|0|0|1|0|0|0|0|0|" thisOpacity "|0|0|0|0|0|1", imageAttribs)
    Gdip_SetImageAttributesGamma(imageAttribs, PasteInPlaceGamma/100)
    zEffect := Gdip_CreateEffect(6, PasteInPlaceHue, PasteInPlaceSaturation, PasteInPlaceLight)

    dhMatrix := Gdip_CreateMatrix()
    Gdip_ScaleMatrix(dhMatrix, ResizedW/oImgW, ResizedH/oImgH, 1)
    Gdip_TranslateMatrix(dhMatrix, imgSelPx, imgSelPy, 1)

    r1 := Gdip_DrawImageFX(G2, clipBMP, imgSelPx, imgSelPy, 0, 0, oImgW, oImgH,, zEffect, imageAttribs, dhMatrix)
    If (EllipseSelectMode=1)
       Gdip_ResetClip(G2)

    Gdip_DisposeImageAttributes(imageAttribs)
    Gdip_DisposeEffect(zEffect)
    Gdip_DeletePath(pPath)
    Gdip_DeleteMatrix(dhMatrix)
    If (g2!=2NDglPG)
    {
    SoundBeep 
    If (StrLen(userClipBMPpaste)<5 || StrLen(clipBMP)<5)
    MsgBox, lool
 }

    ; MsgBox, % userClipBMPpaste
    If (AnyWindowOpen && G2=2NDglPG)
    {
       thisImgQuality := (userimgQuality=1) ? 7 : 5
       Gdip_SetInterpolationMode(2NDglPG, thisImgQuality)
       prevImgCall := getIDimage(currentFileIndex) currentFileIndex viewportStampBMP PasteInPlaceBlurAmount PasteInPlaceOrientation PasteInPlaceAngle
       prevClipBMP := clipBMP
       ; Gdip_DisposeImage(clipBmp, 1)
       GetClientSize(mainWidth, mainHeight, PVhwnd)
       r2 := UpdateLayeredWindow(hGDIselectWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
    }
}

destroyGDIfileCache(remAll:=1, makeBackup:=0) {
    If (remAll=0)
    {
       imgPath := getIDimage(currentFileIndex)
       MD5name := generateThumbName(imgPath, 1)
       If InStr(gdiBitmapIDcall, "1" MD5name imgPath)
       {
          If (makeBackup=1)
          {
             mainCall := SubStr(gdiBitmapIDcall, 2)
             gdiBitmapIDcall := "0" . mainCall
             xBitmap := cloneGDItoMem(gdiBitmap)
             gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
             gdiBitmap := xBitmap
          } Else gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
       }

       If InStr(BprevImgCall, "1" MD5name imgPath)
       {
          BprevImgCall := ""
          BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
       }

       If InStr(AprevImgCall, "1" MD5name imgPath)
       {
          AprevImgCall := ""
          AprevGdiBitmap := Gdip_DisposeImage(AprevGdiBitmap, 1)
       }

       If (!AprevImgCall && mainCall && makeBackup=1)
       {
          AprevImgCall := gdiBitmapIDcall
          AprevGdiBitmap := Gdip_CloneBitmap(gdiBitmap)
       } Else If (!BprevImgCall && mainCall && makeBackup=1)
       {
          BprevImgCall := gdiBitmapIDcall
          BprevGdiBitmap := Gdip_CloneBitmap(gdiBitmap)
       }

       If InStr(idGDIcacheSRCfileA, "1" MD5name imgPath)
       {
          idGDIcacheSRCfileA := ""
          GDIcacheSRCfileA := Gdip_DisposeImage(GDIcacheSRCfileA, 1)
       }

       If InStr(idGDIcacheSRCfileB, "1" MD5name imgPath)
       {
          idGDIcacheSRCfileB := ""
          GDIcacheSRCfileB := Gdip_DisposeImage(GDIcacheSRCfileB, 1)
       }
    } Else
    {
       If (SubStr(idGDIcacheSRCfileA, 1, 1)=1)
          GDIcacheSRCfileA := Gdip_DisposeImage(GDIcacheSRCfileA, 1)
       If (SubStr(idGDIcacheSRCfileB, 1, 1)=1)
          GDIcacheSRCfileB := Gdip_DisposeImage(GDIcacheSRCfileB, 1)
       If (SubStr(BprevImgCall, 1, 1)=1)
          BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
       If (SubStr(AprevImgCall, 1, 1)=1)
          AprevGdiBitmap := Gdip_DisposeImage(AprevGdiBitmap, 1)
       If (SubStr(gdiBitmapIDcall, 1, 1)=1)
          gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)

       idGDIcacheSRCfileA := ""
       idGDIcacheSRCfileB := ""
       BprevImgCall := ""
       AprevImgCall := ""
       gdiBitmapIDcall := ""
    }
}

discardViewPortCaches() {
    ; GDIcacheSRCfileA := Gdip_DisposeImage(GDIcacheSRCfileA, 1)
    ; GDIcacheSRCfileB := Gdip_DisposeImage(GDIcacheSRCfileB, 1)
    BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
    AprevGdiBitmap := Gdip_DisposeImage(AprevGdiBitmap, 1)
    gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)
    prevGDIvpCache := Gdip_DisposeImage(prevGDIvpCache, 1)
}

disposeCacheIMGs() {
    ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
    prevGDIvpCache := Gdip_DisposeImage(prevGDIvpCache, 1)
    gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)
    gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
    GDIfadeVPcache := Gdip_DisposeImage(GDIfadeVPcache, 1)
}

MenuReturnIMGedit() {
   If (StrLen(UserMemBMP)>2 && imgIndexEditing>0)
      currentFileIndex := imgIndexEditing
   MenuDummyToggleThumbsMode()
}

mergeViewPortEffectsImgEditing() {
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    imgIndexEditing := currentFileIndex
    setImageLoading()
    showTOOLtip("Please wait, processing image...")
    discardViewPortCaches()
    If ((RenderOpaqueIMG=1 || imgFxMode>1 || usrColorDepth>1) && UserMemBMP=whichBitmap)
    {
       decideGDIPimageFX(matrix, imageAttribs, pEffect)
       ; flipBitmapAccordingToViewPort(whichBitmap, 1)
       thisImgQuality := (userimgQuality=1) ? 7 : 5
       G2 := Gdip_GraphicsFromImage(UserMemBMP, thisImgQuality, 4)
       Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
       r1 := Gdip_DrawImageFX(G2, gdiBitmap, 0, 0, 0, 0, imgW, imgH, matrix, pEffect, imageAttribs)
       Gdip_DeleteGraphics(G2)
       If imageAttribs
          Gdip_DisposeImageAttributes(imageAttribs)
       If pEffect
          Gdip_DisposeEffect(pEffect)
    } Else If ((RenderOpaqueIMG=1 || imgFxMode>1 || usrColorDepth>1) && gdiBitmap=whichBitmap)
    {
       Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
       xBitmap := Gdip_ResizeBitmap(gdiBitmap, imgW, imgH, 0)
       gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
       UserMemBMP := xBitmap

       decideGDIPimageFX(matrix, imageAttribs, pEffect)
       ; flipBitmapAccordingToViewPort(whichBitmap, 1)
       thisImgQuality := (userimgQuality=1) ? 7 : 5
       If (matrix || imageAttribs || pEffect)
       {
          G2 := Gdip_GraphicsFromImage(UserMemBMP, thisImgQuality, 4)
          Gdip_GetImageDimensions(UserMemBMP, imgW, imgH)
          r1 := Gdip_DrawImageFX(G2, UserMemBMP, 0, 0, 0, 0, imgW, imgH, matrix, pEffect, imageAttribs)
          Gdip_DeleteGraphics(G2)
          If imageAttribs
             Gdip_DisposeImageAttributes(imageAttribs)
          If pEffect
             Gdip_DisposeEffect(pEffect)
       }
    }

    usrColorDepth := imgFxMode := 1
    RenderOpaqueIMG := vpIMGrotation := 0 ; FlipImgH := FlipImgV := 0
}

EraseSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    calcImgSelection2bmp(!LimitSelectBoundsImg, imgW, imgH, imgW, imgH, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)

    pPath := Gdip_CreatePath()
    If (EllipseSelectMode=1)
       Gdip_AddPathEllipse(pPath, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH)
    Else
       Gdip_AddPathRectangle(pPath, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH)

    If (EraseAreaIgnoreRotation!=1 && vPselRotation>0)
       Gdip_RotatePathAtCenter(pPath, vPselRotation)

    If (EraseAreaIgnoreRotation!=1 && vPselRotation>0 && EraseAreaFader=1)
       xBitmap := Gdip_CloneBitmapArea(whichBitmap)
    Else If (EraseAreaFader=1)
       xBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)

    pBitmap := Gdip_CreateBitmap(imgW, imgH)
    G2 := Gdip_GraphicsFromImage(pBitmap, 7, 4)
    Gdip_SetClipPath(G2, pPath, 4)
    r1 := Gdip_DrawImage(G2, whichBitmap, 0, 0, imgW, imgH, 0, 0, imgW, imgH)
    Gdip_ResetClip(G2)
    If (UserMemBMP=whichBitmap)
       UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)

    thisOpacity := EraseAreaOpacity / 256
    If (EraseAreaFader=1)
    {
       If (EllipseSelectMode=1) || (EraseAreaIgnoreRotation!=1 && vPselRotation>0)
          Gdip_SetClipPath(G2, pPath, 0)
       If (EraseAreaIgnoreRotation!=1 && vPselRotation>0)
          r1 := Gdip_DrawImage(G2, xBitmap, 0, 0, imgW, imgH, 0, 0, imgW, imgH, thisOpacity)
       Else
          r1 := Gdip_DrawImage(G2, xBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH, 0, 0, imgSelW, imgSelH, thisOpacity)
    }

    Gdip_DeletePath(pPath)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(xBitmap, 1)
    UserMemBMP := pBitmap
    SetTimer, RefreshImageFile, -25
}

ApplyColorAdjustsSelectedArea() {
    Static prevFXmode := 2
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (imgFxMode=1)
       imgFxMode := prevFXmode

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    calcImgSelection2bmp(!LimitSelectBoundsImg, imgW, imgH, imgW, imgH, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    If (pEffect || imageAttribs)
    {
       xBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)
    } Else
    {
       imgFxMode := 1
       Return
    }

    If (slideShowRunning=1)
       ToggleSlideShowu()

    prevFXmode := imgFxMode
    imgFxMode := 1
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap

    pBitmap := Gdip_CreateBitmap(imgW, imgH)
    G2 := Gdip_GraphicsFromImage(pBitmap, 7, 4)
    r1 := Gdip_DrawImageFast(G2, whichBitmap)

    If (UserMemBMP=whichBitmap)
       UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)

    pPath := Gdip_CreatePath()
    Gdip_AddPathEllipse(pPath, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH)
    If (EllipseSelectMode=1)
       Gdip_SetClipPath(G2, pPath, 0)

    r1 := Gdip_DrawImageFX(G2, xBitmap, imgSelPx, imgSelPy, 0, 0, imgSelW, imgSelH, matrix, pEffect, imageAttribs, hMatrix)
    Gdip_DeletePath(pPath)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(xBitmap, 1)
    UserMemBMP := pBitmap
    SetTimer, RefreshImageFile, -25
}

FillSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    If (FillAreaDoContour=1)
       FillAreaRemBGR := 0

    mustRemBackground := (FillAreaRemBGR=1 && FillAreaOpacity<254) ? 1 : 0
    If (UserMemBMP!=whichBitmap && mustRemBackground!=1)
       whichBitmap := Gdip_CloneBitmapArea(whichBitmap)

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    If (mustRemBackground=1 && FillAreaDoContour!=1)
       pBitmap := Gdip_CreateBitmap(imgW, imgH)
    Else
       pBitmap := whichBitmap

    G2 := Gdip_GraphicsFromImage(pBitmap, 7, 4)
    pPath := coreFillSelectedArea(G2, whichBitmap)

    If (mustRemBackground=1 && FillAreaDoContour!=1)
    {
       Gdip_ResetClip(G2)
       modus := (FillAreaInverted=1) ? 0 : 4
       Gdip_SetClipPath(G2, pPath, modus)
       r1 := Gdip_DrawImageFast(G2, whichBitmap)
       If (UserMemBMP=whichBitmap)
          UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
    }

    Gdip_DeleteGraphics(G2)
    Gdip_DeletePath(pPath)
    UserMemBMP := pBitmap
    SetTimer, RefreshImageFile, -25
}

coreFillSelectedArea(G2:=0, whichBitmap:=0) {
    If !whichBitmap
       whichBitmap := gdiBitmap

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(1, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    maxLength := (imgSelW + imgSelH)//2
    thisThick := (FillAreaContourThickness>maxLength//1.5) ? maxLength//1.5 : FillAreaContourThickness
    If !G2
    {
       G2 := 2NDglPG
       Gdip_ResetClip(2NDglPG)
       Gdip_GraphicsClear(2NDglPG, "0x00" WindowBGRcolor)
       GetClientSize(mainWidth, mainHeight, PVhwnd)
       thisThick := thisThick*zoomLevel
       imgSelPx := x1 := selDotX + SelDotsSize//2, x2 := selDotAx + SelDotsSize//2
       imgSelPy := y1 := selDotY + SelDotsSize//2, y2 := selDotAy + SelDotsSize//2
       imgSelW := max(X1, X2) - min(X1, X2)
       imgSelH := max(Y1, Y2) - min(Y1, Y2)
       imgW := mainWidth
       imgH := mainHeight
    }

    dR := (FillAreaContourAlign=3) ? thisThick//2 : 0
    If (FillAreaContourAlign=1)
       dR := -thisThick//2

    If (FillAreaDoContour!=1)
    {
       dR := thisThick := 0
    } Else
    {
       imgSelPx -= dR
       imgSelPy -= dR
       imgSelW += dR*2
       imgSelH += dR*2
    }

    Gdip_FromARGB("0xFF" FillAreaColor, A, R, G, B)
    thisColor := Gdip_ToARGB(FillAreaOpacity, R, G, B)
    Brush := Gdip_BrushCreateSolid(thisColor)
    pPath := Gdip_CreatePath()
    If (FillAreaShape=1)
    {
       Gdip_AddPathRectangle(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
    } Else If (FillAreaShape=2)
    {
       radius := Round(((imgSelW + imgSelH)//2)*0.1) + 1
       Gdip_AddPathRoundedRectangle(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH, radius)
    } Else If (FillAreaShape=3)
    {
       Gdip_AddPathEllipse(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
    } Else If (FillAreaShape=4)
    {
       cX1 := imgSelPx + imgSelW//2
       cY1 := imgSelPy
       cX2 := imgSelPx
       cY2 := imgSelPy + imgSelH
       cX3 := imgSelPx + imgSelW
       cY3 := imgSelPy + imgSelH
       Gdip_AddPathPolygon(pPath, cX1 "," cY1 "|" cX2 "," cY2 "|" cX3 "," cY3)
    } Else If (FillAreaShape=5)
    {
       cX1 := imgSelPx
       cY1 := imgSelPy
       cX2 := imgSelPx
       cY2 := imgSelPy + imgSelH
       cX3 := imgSelPx + imgSelW
       cY3 := imgSelPy + imgSelH
       Gdip_AddPathPolygon(pPath, cX1 "," cY1 "|" cX2 "," cY2 "|" cX3 "," cY3)
    } Else If (FillAreaShape=6)
    {
       cX1 := imgSelPx + imgSelW//2
       cY1 := imgSelPy
       cX2 := imgSelPx
       cY2 := imgSelPy + imgSelH//2
       cX3 := imgSelPx + imgSelW//2
       cY3 := imgSelPy + imgSelH
       cX4 := imgSelPx + imgSelW
       cY4 := imgSelPy + imgSelH//2
       Gdip_AddPathPolygon(pPath, cX1 "," cY1 "|" cX2 "," cY2 "|" cX3 "," cY3 "|" cX4 "," cY4)
    }

    If (FillAreaAngle>0 && isNumber(FillAreaAngle))
       Gdip_RotatePathAtCenter(pPath, FillAreaAngle)

    mustRemBackground := (FillAreaRemBGR=1 && FillAreaOpacity<254) ? 1 : 0
    If (FillAreaInverted=1 && FillAreaDoContour!=1)
    {
       Gdip_SetClipPath(G2, pPath, 4)
       If (mustRemBackground=1 && AnyWindowOpen && G2=2NDglPG)
          Gdip_FillRectangle(G2, pBrushHatchLow, -2, -2, imgW + 2, imgH + 2)
       Gdip_FillRectangle(G2, Brush, -2, -2, imgW + 2, imgH + 2)
    } Else If (FillAreaDoContour=1)
    {
       thisPen := Gdip_CreatePen(thisColor, thisThick)
       If (FillAreaRoundedCaps=1)
          Gdip_SetPenLineCaps(thisPen, 2, 2, 2)

       compoundArray := "0.0|0.33|0.67|1.0"
       Gdip_SetPenDashStyle(thisPen, FillAreaDashStyle - 1)
       If (FillAreaDoubleLine=1)
          Gdip_SetPenCompoundArray(thisPen, compoundArray)

       If (FillAreaShape=2)
          Gdip_DrawRoundedRectangle2(G2, thisPen, imgSelPx - thisThick//2, imgSelPy - thisThick//2, imgSelW + thisThick, imgSelH + thisThick, radius, FillAreaAngle)
       Else
          Gdip_DrawPath(G2, thisPen, pPath)

       Gdip_DeletePen(thisPen)
    } Else
    {
       If (mustRemBackground=1 && AnyWindowOpen && G2=2NDglPG)
          Gdip_FillPath(G2, pBrushHatchLow, pPath)

       Gdip_FillPath(G2, Brush, pPath)
    }

    Gdip_DeleteBrush(Brush)
    If (AnyWindowOpen && G2=2NDglPG)
    {
       Gdip_ResetClip(2NDglPG)
       r2 := UpdateLayeredWindow(hGDIselectWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
    }

    Return pPath
}

MenuFlipSelectedAreaH() {
    FlipSelectedArea("h")
}

MenuFlipSelectedAreaV() {
    FlipSelectedArea("v")
}

FlipSelectedArea(flipAxis) {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (UserMemBMP!=whichBitmap)
       gdiBitmap := ""

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    capSelectionRelativeCoords()
    imgSelX1 := X1, imgSelY1 := Y1
    imgSelX2 := X2, imgSelY2 := Y2
    G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)
    zBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)
    If (flipAxis="H")
       Gdip_ImageRotateFlip(zBitmap, 4)
    Else If (flipAxis="V")
       Gdip_ImageRotateFlip(zBitmap, 6)

    pPath := Gdip_CreatePath()
    Gdip_AddPathEllipse(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
    If (EllipseSelectMode=1)
       Gdip_SetClipPath(G2, pPath, 0)

    r1 := Gdip_DrawImage(G2, zBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH, 0, 0, imgSelW, imgSelH)
    Gdip_DeletePath(pPath)
    Gdip_DisposeImage(zBitmap, 1)
    Gdip_DeleteGraphics(G2)
    UserMemBMP := whichBitmap
    SetTimer, RefreshImageFile, -25
}

getTransformToolSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    capSelectionRelativeCoords()
    imgSelX1 := X1, imgSelY1 := Y1
    imgSelX2 := X2, imgSelY2 := Y2
    zBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)
    Return zBitmap
}

DrawLinesInSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (UserMemBMP!=whichBitmap)
       gdiBitmap := ""

    If (slideShowRunning=1)
       ToggleSlideShowu()

    G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)
    coreDrawLinesSelectionArea(G2, whichBitmap)
    Gdip_DeleteGraphics(G2)
    UserMemBMP := whichBitmap
    SetTimer, RefreshImageFile, -25
}

coreDrawLinesSelectionArea(G2:=0, whichBitmap:=0) {
    If (G2)
    {
       Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
       calcImgSelection2bmp(1, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       maxLength := (imgSelW + imgSelH)//2
       thisThick := (DrawLineAreaContourThickness>maxLength//1.5) ? maxLength//1.5 : DrawLineAreaContourThickness
    } Else
    {
       G2 := 2NDglPG
       Gdip_GraphicsClear(2NDglPG, "0x00" WindowBGRcolor)
       Gdip_GetImageDimensions(gdiBitmap, qimgW, qimgH)
       calcImgSelection2bmp(1, qimgW, qimgH, qimgW, qimgH, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       imgSelPx := x1 := selDotX + SelDotsSize//2, x2 := selDotAx + SelDotsSize//2
       imgSelPy := y1 := selDotY + SelDotsSize//2, y2 := selDotAy + SelDotsSize//2
       imgSelW := max(X1, X2) - min(X1, X2)
       imgSelH := max(Y1, Y2) - min(Y1, Y2)
       maxLength := (qimgSelW + qimgSelH)//2
       thisThick := (DrawLineAreaContourThickness>maxLength//1.5) ? maxLength//1.5 : DrawLineAreaContourThickness
       thisThick := thisThick*zoomLevel
    }

    dR := (DrawLineAreaContourAlign=3) ? thisThick//2 : 0
    If (DrawLineAreaContourAlign=1)
       dR := -thisThick//2

    imgSelPx -= dR
    imgSelPy -= dR
    imgSelW += dR*2
    imgSelH += dR*2
    x1 -= dR
    y1 -= dR
    x2 += dR
    y2 += dR

    pPathArcs := Gdip_CreatePath()
    If (DrawLineAreaBorderArcA=1)
       Gdip_AddPathArc(pPathArcs, x1, y1, imgSelW, imgSelH, 180, 90)
    Gdip_StartPathFigure(pPathArcs)
    If (DrawLineAreaBorderArcB=1)
       Gdip_AddPathArc(pPathArcs, x1, y1, imgSelW, imgSelH, 270, 90)
    Gdip_StartPathFigure(pPathArcs)
    If (DrawLineAreaBorderArcC=1)
       Gdip_AddPathArc(pPathArcs, x1, y1, imgSelW, imgSelH, 90, 90)
    Gdip_StartPathFigure(pPathArcs)
    If (DrawLineAreaBorderArcD=1)
       Gdip_AddPathArc(pPathArcs, x1, y1, imgSelW, imgSelH, 0, 90)

    pPathBrders := Gdip_CreatePath()
    If (DrawLineAreaBorderTop=1)
       Gdip_AddPathLine(pPathBrders, x1, y1, x2, y1)

    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderBottom=1)
       Gdip_AddPathLine(pPathBrders, x1, y2, x2, y2)

    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderLeft=1)
       Gdip_AddPathLine(pPathBrders, x1, y1, x1, y2)

    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderRight=1)
       Gdip_AddPathLine(pPathBrders, x2, y1, x2, y2)

    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderCenter=2 || DrawLineAreaBorderCenter=7)
       Gdip_AddPathLine(pPathBrders, x1 + imgSelW//2, y1, x1 + imgSelW//2, y2)
    
    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderCenter=3 || DrawLineAreaBorderCenter=7)
       Gdip_AddPathLine(pPathBrders, x1, y1 + imgSelH//2, x2, y1 + imgSelH//2)

    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderCenter=4 || DrawLineAreaBorderCenter=6)
       Gdip_AddPathLine(pPathBrders, x1, y2, x2, y1)

    Gdip_StartPathFigure(pPathBrders)
    If (DrawLineAreaBorderCenter=5 || DrawLineAreaBorderCenter=6)
       Gdip_AddPathLine(pPathBrders, x1, y1, x2, y2)

    Gdip_FromARGB("0xFF" DrawLineAreaColor, A, R, G, B)
    thisColor := Gdip_ToARGB(DrawLineAreaOpacity, R, G, B)
    thisPen := Gdip_CreatePen(thisColor, thisThick)
    Gdip_SetPenDashStyle(thisPen, DrawLineAreaDashStyle - 1)
    If (DrawLineAreaCapsStyle=1)
       Gdip_SetPenLineCaps(thisPen, 2, 2, 2)

    compoundArray := "0.0|0.33|0.67|1.0"
    If (DrawLineAreaDoubles=1)
       Gdip_SetPenCompoundArray(thisPen, compoundArray)

    Gdip_RotatePathAtCenter(pPathBrders, DrawLineAreaAngle)
    Gdip_RotatePathAtCenter(pPathArcs, DrawLineAreaAngle)

    Gdip_DrawPath(G2, thisPen, pPathBrders)
    Gdip_DrawPath(G2, thisPen, pPathArcs)
 
    Gdip_DeletePath(pPathBrders)
    Gdip_DeletePath(pPathArcs)
    Gdip_DeletePen(thisPen)
    If (AnyWindowOpen && G2=2NDglPG)
    {
       GetClientSize(mainWidth, mainHeight, PVhwnd)
       r2 := UpdateLayeredWindow(hGDIselectWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
    }
}

ChangeImageCanvasSize(userW, userH, userAddT, userAddB, userAddL, userAddR, userAddC, vpMode) {
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    If (vpMode=1)
    {
       calcImgSelection2bmp(1, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       newW := imgSelW, newH := imgSelH
       If (valueBetween(imgSelW, imgW - 2, imgW + 2) && valueBetween(imgSelH, imgH - 2, imgH + 2) && !imgSelPx && !imgSelPy)
          Return

       imgSelPx := - imgSelPx
       imgSelPy := - imgSelPy
       activateImgSelection := editingSelectionNow := 0
    } Else If (adjustCanvasMode=1)
    {
       newW := userAddL + userAddR + userAddC + imgW
       newH := userAddT + userAddB + userAddC + imgH
       imgSelPx := userAddL + (userAddC + 1)//2
       imgSelPy := userAddT + (userAddC + 1)//2
    } Else
    {
       newW := userW
       newH := userH
       imgSelPx := (adjustCanvasCentered=1) ? newW//2 - imgW//2 : 0
       imgSelPy := (adjustCanvasCentered=1) ? newH//2 - imgH//2 : 0
    }

    xBitmap := Gdip_CreateBitmap(newW, newH)
    G2 := Gdip_GraphicsFromImage(xBitmap, 7, 4)
    If (adjustCanvasNoBgr!=1)
    {
       Gdip_FromARGB("0xFF" FillAreaColor, A, R, G, B)
       thisColor := Gdip_ToARGB(FillAreaOpacity, R, G, B)
       Brush := Gdip_BrushCreateSolid(thisColor)
       Gdip_SetClipRect(G2, imgSelPx, imgSelPy, imgW, imgH, 4)
       Gdip_FillRectangle(G2, Brush, -1, -1, newW, newH)
       Gdip_DeleteBrush(Brush)
       Gdip_ResetClip(G2)
    }
    ; MsgBox, % newW "--" newH "--" imgSelPx "--" imgSelPy
    ; r1 := Gdip_DrawImage(G2, whichBitmap, imgSelPx, imgSelPy, imgW, imgH, 0, 0, imgW, imgH)
    r1 := Gdip_DrawImageFast(G2, whichBitmap, imgSelPx, imgSelPy)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(whichBitmap, 1)
    UserMemBMP := xBitmap
    SetTimer, RefreshImageFile, -25
}

BlurSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (UserMemBMP!=whichBitmap)
       gdiBitmap := ""

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    capSelectionRelativeCoords()
    imgSelX1 := X1, imgSelY1 := Y1
    imgSelX2 := X2, imgSelY2 := Y2

    If (X1<5)
       X1MarginSnap := 1
    If (X2>imgW - 5)
       X2MarginSnap := 1
    If (Y1<5)
       Y1MarginSnap := 1
    If (Y2>imgH - 5)
       Y2MarginSnap := 1

    pPath := Gdip_CreatePath()
    modus := (blurAreaInverted=1) ? 4 : 0
    If (blurAreaSoftEdges=1)
    {
       countNoes := 0
       bRa := blurAreaAmount
       gImgselPx := imgSelPx - bRa
       If (gImgSelPx<3)
       {
          countNoes++
          gImgSelPx := 0
       }

       gImgselPy := imgSelPy - bRa
       If (gImgSelPy<3)
       {
          countNoes++
          gImgSelPy := 0
       }

       gImgSelW := imgSelW + bRa * 2
       If (gImgSelW>imgW - gImgselPx - 3)
       {
          countNoes++
          gImgSelW := imgW - gImgselPx
       }

       gImgselH := imgSelH + bRa * 2
       If (gImgSelH>imgH - gImgselPy - 3)
       {
          countNoes++
          gImgSelH := imgH - gImgselPy
       }

       If (EllipseSelectMode=1)
          countNoes := 0
    }

    If (blurAreaSoftEdges=1 && countNoes<3)
    {
       setWindowTitle("Preparing blur image effect, please wait", 1)
       pEffect := Gdip_CreateEffect(1, blurAreaAmount, 0, 0)
       kBitmap := Gdip_CloneBitmapArea(whichBitmap, gimgSelPx, gimgSelPy, gimgSelW, gimgSelH)
       If (blurAreaInverted=1)
       {
          If (blurAreaOpacity<253)
             primoBitmap := Gdip_CloneBitmapArea(whichBitmap)

          If (blurAreaTwice=1)
          {
             setWindowTitle("EXTRA BLUR - INVERTED AREA, please wait", 1)
             xBitmap := Gdip_ResizeBitmap(whichBitmap, imgW//2, imgH//2, 1, 3)
             Gdip_DisposeImage(whichBitmap, 1)
             Gdip_BitmapApplyEffect(xBitmap, pEffect)
             wBitmap := Gdip_ResizeBitmap(xBitmap, imgW, imgH, 1, 3)
             Gdip_DisposeImage(xBitmap, 1)
             whichBitmap := wBitmap
          }

          setWindowTitle("BLURRING IMAGE - INVERTED AREA, please wait", 1)
          Gdip_BitmapApplyEffect(whichBitmap, pEffect)
       }

       G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)
       Gdip_GetImageDimensions(kBitmap, kimgW, kimgH)

       pBitmap := Gdip_CreateBitmap(kImgW, kImgH)
       G3 := Gdip_GraphicsFromImage(pBitmap, 7, 1)
       BrushA := Gdip_BrushCreateSolid("0xFF000000")
       setWindowTitle("CALCULATING SOFT EDGE ALPHA MASK, please wait", 1)
       Gdip_FillRectangle(G3, BrushA, -2, -2, gImgselW + 2, gImgselH + 2)
       thisAmount := (min(gimgSelW, gimgSelH)<bRa*2.5) ? min(gimgSelW, gimgSelH)//2.5 : bRa
       thisAmountX1 := (X1MarginSnap=1) ? 0 : thisAmount
       thisAmountY1 := (Y1MarginSnap=1) ? 0 : thisAmount
       thisAmountX2 := (X2MarginSnap=1) ? gImgSelW + 2 : gImgSelW - thisAmount*2
       thisAmountY2 := (Y2MarginSnap=1) ? gImgSelH + 2 : gImgSelH - thisAmount*2
       If (EllipseSelectMode=1)
       {
          Gdip_AddPathEllipse(pPath, thisAmountX1, thisAmountY1, thisAmountX2, thisAmountY2)
          Gdip_SetClipPath(G3, pPath, 0)
       } Else Gdip_SetClipRect(G3, thisAmountX1, thisAmountY1, thisAmountX2, thisAmountY2, 0)

       BrushB := Gdip_BrushCreateSolid("0xFFFFFFFF")
       Gdip_FillRectangle(G3, BrushB, -2, -2, gImgselW + 2, gImgselH + 2)
       thisAmount := (min(imgSelW, imgSelH)<blurAreaAmount*2.5) ? min(imgSelW, imgSelH)//2.5 : blurAreaAmount
       pEffect2 := Gdip_CreateEffect(1, thisAmount, 0, 0)
       Gdip_BitmapApplyEffect(pBitmap, pEffect2) ; the alpha masked blurred
       If (min(imgSelW, imgSelH)>blurAreaAmount*4.5 && blurAreaTwice=1)
       {
          pEffect3 := Gdip_CreateEffect(1, thisAmount//2+1, 0, 0)
          Gdip_BitmapApplyEffect(pBitmap, pEffect3) ; the alpha masked blurred
          Gdip_DisposeEffect(pEffect3)
       }

       If (blurAreaInverted!=1)
       {
          setWindowTitle("BLURRING IMAGE, please wait", 1)
          thisOpacity := blurAreaOpacity/255
          Gdip_BitmapApplyEffect(kBitmap, pEffect) ; the actual image blurred
       } Else thisOpacity := 1

       bRa := (EllipseSelectMode=1) ? Round(blurAreaAmount*8.5) : Round(blurAreaAmount*4.25)
       noOptimisations := (bRa>gimgSelW - 5) || (bRa>gimgSelH - 5) ? 1 : 0
       ; msgbox, % bra "--" gImgSelW "--" gImgSelH "--" noOptimisations
       setWindowTitle("MERGING SOFT EDGE ALPHA MASK, please wait", 1)

       If (blurAreaInverted!=1)
       {
          kImgW := kImgW//2
          kImgH := kImgH//2
          bRa := (EllipseSelectMode=1) ? Round(blurAreaAmount*8.5) : Round(blurAreaAmount*4.25)
          noOptimisations := (bRa>gimgSelW//2 - 5) || (bRa>gimgSelH//2 - 5) ? 1 : 0
          gBitmap := Gdip_ResizeBitmap(pBitmap, kimgW, kImgH, 0, 3)
          Gdip_DisposeImage(pBitmap, 1)
          pBitmap := gBitmap 

          dBitmap := Gdip_ResizeBitmap(kBitmap, kimgW, kImgH, 0)
          Gdip_DisposeImage(kBitmap, 1)
          kBitmap := dBitmap
          If (blurAreaTwice=1)
             Gdip_BitmapApplyEffect(kBitmap, pEffect) ; the actual image blurred
       }

       kBitmap := SetBitmapAlphaChannel(kBitmap, pBitmap, bRa, noOptimisations)
       setWindowTitle("FINALISING BLUR, please wait", 1)
       r1 := Gdip_DrawImage(G2, kBitmap, gimgSelPx, gimgSelPy, gimgSelW, gimgSelH, 0, 0, kimgW, kimgH, thisOpacity)
       If (blurAreaOpacity<253)
       {
          thisOpacity := 1.01 - blurAreaOpacity/255
          r1 := Gdip_DrawImage(G2, primoBitmap, 0, 0, imgW, imgH,,,,,thisOpacity)
          primoBitmap := Gdip_CloneBitmapArea(whichBitmap)
          Gdip_DisposeImage(primoBitmap)
       }

       Gdip_DeleteGraphics(G2)
       Gdip_DeleteGraphics(G3)
       Gdip_DeletePath(pPath)
       Gdip_DeleteBrush(BrushA)
       Gdip_DeleteBrush(BrushB)
       Gdip_DisposeEffect(pEffect)
       Gdip_DisposeEffect(pEffect2)
       Gdip_DisposeImage(pBitmap)
       Gdip_DisposeImage(kBitmap)
       UserMemBMP := whichBitmap
       SoundBeep , 900, 100
       SetTimer, RefreshImageFile, -25
       Return
    } Else If (blurAreaSoftEdges=1)
    {
       imgSelPx := imgSelPy := 0
       imgSelW := imgW
       imgSelH := imgH
    }

    G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)
    Gdip_AddPathEllipse(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
    If (EllipseSelectMode=1)
       Gdip_SetClipPath(G2, pPath, modus)
    Else If (blurAreaInverted=1)
       Gdip_SetClipRect(G2, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)

    If (blurAreaInverted=1)
    {
       imgSelPx := imgSelPy := 0
       imgSelW := imgW
       imgSelH := imgH
    }

    zBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)
    thisOpacity := blurAreaOpacity/255
    pEffect := Gdip_CreateEffect(1, blurAreaAmount, 0, 0)
    If (blurAreaTwice=1)
    {
       setWindowTitle("EXTRA-BLURRING IMAGE, please wait", 1)
       xBitmap := Gdip_ResizeBitmap(zBitmap, imgSelW//2, imgSelH//2, 1, 3)
       Gdip_DisposeImage(zBitmap, 1)
       zBitmap := xBitmap
       dhMatrix := Gdip_CreateMatrix()
       Gdip_ScaleMatrix(dhMatrix, 2, 2, 1)
       Gdip_TranslateMatrix(dhMatrix, imgSelPx, imgSelPy, 1)
       Gdip_BitmapApplyEffect(zBitmap, pEffect)
    }

    setWindowTitle("BLURRING IMAGE, please wait", 1)
    r1 := Gdip_DrawImageFX(G2, zBitmap, imgSelPx, imgSelPy, 0, 0, imgSelW, imgSelH, thisOpacity, pEffect, 0, dhMatrix)
    If dhMatrix
       Gdip_DeleteMatrix(dhMatrix)
    Gdip_DisposeImage(zBitmap, 1)
    Gdip_DisposeEffect(pEffect)
    Gdip_DeletePath(pPath)
    Gdip_DeleteGraphics(G2)
    UserMemBMP := whichBitmap
    SetTimer, RefreshImageFile, -25
}

SetBitmapAlphaChannel(pBitmap, AlphaMaskBitmap, limitus, noOptimisations) {
; Replaces the alpha channel of the given pBitmap
; based on the AlphaMaskBitmap.
; AlphaMaskBitmap must be grayscale for optimal results.
; Both pBitmap and AlphaMaskBitmap must be in 32-ARGB PixelFormat.

   Gdip_GetImageDimensions(pBitmap, Width1, Height1)
   Gdip_GetImageDimensions(AlphaMaskBitmap, Width2, Height2)
   if (!Width1 || !Height1 || !Width2 || !Height2
   || Width1!=Width2 || Height1!=Height2)
      Return -1

   E1 := Gdip_LockBits(pBitmap, 0, 0, Width1, Height1, Stride1, Scan01, BitmapData1)
   E2 := Gdip_LockBits(AlphaMaskBitmap, 0, 0, Width2, Height2, Stride2, Scan02, BitmapData2)

   upperLx := width1 - limitus
   If (upperLx<2)
      upperLx := 1

   upperLy := height1 - limitus
   If (upperLy<2)
      upperLy := 1

   If (noOptimisations=1)
   {
       Loop, % Height1
       {
          y++
          Loop, % Width1
          {
             pX := A_Index-1, pY := y-1
             R2 := Gdip_RFromARGB(NumGet(Scan02+0, (pX*4)+(pY*Stride2), "UInt"))       ; Gdip_GetLockBitPixel()
             If (R2>254)
                Continue

             Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
             NumPut(Gdip_ToARGB(R2, R1, G1, B1), Scan01+0, (pX*4)+(pY*Stride1), "UInt")    ; Gdip_SetLockBitPixel()
          }
       }
   } Else
   {
       Loop, % limitus
       {
          y++
          Loop, % Width1
          {
             pX := A_Index-1, pY := y-1
             R2 := Gdip_RFromARGB(NumGet(Scan02+0, (pX*4)+(pY*Stride2), "UInt"))       ; Gdip_GetLockBitPixel()
             If (R2>254)
                Continue
             Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
             NumPut(Gdip_ToARGB(R2, R1, G1, B1), Scan01+0, (pX*4)+(pY*Stride1), "UInt")    ; Gdip_SetLockBitPixel()
          }
       }

       y := limitus
       Loop, % Height1 - limitus
       {
          y++
          Loop, % limitus
          {
             pX := A_Index-1, pY := y-1
             R2 := Gdip_RFromARGB(NumGet(Scan02+0, (pX*4)+(pY*Stride2), "UInt"))       ; Gdip_GetLockBitPixel()
             If (R2>254)
                Continue

             Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
             NumPut(Gdip_ToARGB(R2, R1, G1, B1), Scan01+0, (pX*4)+(pY*Stride1), "UInt")    ; Gdip_SetLockBitPixel()
          }
       }

       y := limitus
       Loop, % Height1 - limitus
       {
          y++
          Loop, % limitus
          {
             pX := upperLx + A_Index - 1, pY := y-1
             R2 := Gdip_RFromARGB(NumGet(Scan02+0, (pX*4)+(pY*Stride2), "UInt"))       ; Gdip_GetLockBitPixel()
             If (R2>254)
                Continue

             Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
             NumPut(Gdip_ToARGB(R2, R1, G1, B1), Scan01+0, (pX*4)+(pY*Stride1), "UInt")    ; Gdip_SetLockBitPixel()
          }
       }

       y := upperLy
       Loop, % limitus
       {
          y++
          Loop, % width1 - limitus*2
          {
             pX := limitus + A_Index - 1, pY := y-1
             R2 := Gdip_RFromARGB(NumGet(Scan02+0, (pX*4)+(pY*Stride2), "UInt"))       ; Gdip_GetLockBitPixel()
             If (R2>254)
                Continue

             Gdip_FromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"), A1, R1, G1, B1)
             NumPut(Gdip_ToARGB(R2, R1, G1, B1), Scan01+0, (pX*4)+(pY*Stride1), "UInt")    ; Gdip_SetLockBitPixel()
          }
       }
   }


   Gdip_UnlockBits(pBitmap, BitmapData1)
   Gdip_UnlockBits(AlphaMaskBitmap, BitmapData2)
   Return pBitmap
}

GraySelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (UserMemBMP!=whichBitmap)
       gdiBitmap := ""

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    calcImgSelection2bmp(!LimitSelectBoundsImg, imgW, imgH, imgW, imgH, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)
    zBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)

    matrix := GenerateColorMatrix(2)
    pEffect := Gdip_CreateEffect(6, 0, -40, 0)
    pPath := Gdip_CreatePath()
    Gdip_AddPathEllipse(pPath, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH)
    If (EllipseSelectMode=1)
       Gdip_SetClipPath(G2, pPath, 0)

    r1 := Gdip_DrawImageFX(G2, zBitmap, imgSelPx, imgSelPy, 0, 0, imgSelW, imgSelH, matrix, pEffect)
    Gdip_DisposeImage(zBitmap, 1)
    Gdip_DisposeEffect(pEffect)
    Gdip_DeletePath(pPath)
    Gdip_DeleteGraphics(G2)
    UserMemBMP := whichBitmap
    SetTimer, RefreshImageFile, -25
}

InvertSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (UserMemBMP!=whichBitmap)
       gdiBitmap := ""

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    calcImgSelection2bmp(!LimitSelectBoundsImg, imgW, imgH, imgW, imgH, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)
    zBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)

    pPath := Gdip_CreatePath()
    Gdip_AddPathEllipse(pPath, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH)
    matrix := GenerateColorMatrix(6)
    If (EllipseSelectMode=1)
       Gdip_SetClipPath(G2, pPath, 0)
    r1 := Gdip_DrawImageFX(G2, zBitmap, imgSelPx, imgSelPy, 0, 0, imgSelW, imgSelH, matrix, pEffect)
    Gdip_DisposeImage(zBitmap, 1)
    Gdip_DisposeEffect(pEffect)
    Gdip_DeletePath(pPath)
    Gdip_DeleteGraphics(G2)
    UserMemBMP := whichBitmap
    SetTimer, RefreshImageFile, -25
}

RotateSelectedArea() {
    mergeViewPortEffectsImgEditing()
    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (UserMemBMP!=whichBitmap)
       gdiBitmap := ""

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    capSelectionRelativeCoords()
    imgSelX1 := X1, imgSelY1 := Y1
    imgSelX2 := X2, imgSelY2 := Y2

    zBitmap := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)
    If (EllipseSelectMode=1)
    {
       xBitmap := Gdip_CreateBitmap(imgSelW, imgSelH)
       G3 := Gdip_GraphicsFromImage(xBitmap)
       pPath := Gdip_CreatePath()
       Gdip_AddPathEllipse(pPath, 0, 0, imgSelW, imgSelH)
       Gdip_SetClipPath(G3, pPath, 0)
       r1 := Gdip_DrawImage(G3, zBitmap, 0, 0, imgSelW, imgSelH, 0, 0, imgSelW, imgSelH)
       Gdip_DisposeImage(zBitmap, 1)
       Gdip_DeletePath(pPath)
       Gdip_DeleteGraphics(G3)
       zBitmap := xBitmap
    }

    thisOpacity := RotateAreaOpacity/255
    thisImgQuality := (RotateAreaQuality=1) ? 7 : 5
    xBitmap := Gdip_RotateBitmapAtCenter(zBitmap, RotateAreaAngle,"",thisImgQuality)
    Gdip_DisposeImage(zBitmap, 1)
    zBitmap := xBitmap

    Gdip_GetImageDimensions(zBitmap, imgW, imgH)
    If (RotateAreaWithinBounds=1)
    {
       If (EllipseSelectMode=1)
       {
          yPath := Gdip_CreatePath()
          Gdip_AddPathEllipse(yPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
          Gdip_RotatePathAtCenter(yPath, RotateAreaAngle)
          pathBounds := Gdip_GetPathWorldBounds(yPath)
          Gdip_DeletePath(yPath)
          gimgW := Round(pathBounds.w)
          gimgH := Round(pathBounds.h)
          gX := (imgW - gimgW)//2
          gY := (imgH - gimgH)//2
          imgW := Round(pathBounds.w)
          imgH := Round(pathBounds.h)
       }
       calcIMGdimensions(imgW, imgH, imgSelW, imgSelH, newW, newH)
    } Else
    {
       newW := imgW
       newH := imgH
    }
    newX := imgSelPx + imgSelW//2 - newW//2 
    newY := imgSelPy + imgSelH//2 - newH//2 

    If (RotateAreaRemBgr=1)
    {
       Gdip_GetImageDimensions(whichBitmap, zimgW, zimgH)
       pBitmap := Gdip_CreateBitmap(zimgW, zimgH)
       G2 := Gdip_GraphicsFromImage(pBitmap, 7, 4)
       If (EllipseSelectMode=1)
       {
          zPath := Gdip_CreatePath()
          Gdip_AddPathEllipse(zPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
          Gdip_SetClipPath(G2, zPath, 4)
       } Else Gdip_SetClipRect(G2, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
       r1 := Gdip_DrawImage(G2, whichBitmap, 0, 0, zimgW, zimgH, 0, 0, zimgW, zimgH)
       If zPath
          Gdip_DeletePath(zPath)

       If (UserMemBMP=whichBitmap)
          UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
    } Else G2 := Gdip_GraphicsFromImage(whichBitmap, 7, 4)

    Gdip_ResetClip(G2)
    r1 := Gdip_DrawImage(G2, zBitmap, newX, newY, newW, newH, gX, gY, imgW, imgH, thisOpacity)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(zBitmap, 1)
    UserMemBMP := (RotateAreaRemBgr=1) ? pBitmap : whichBitmap
    SetTimer, RefreshImageFile, -25
}

CropImageViewPort() {
    If (LimitSelectBoundsImg!=1)
    {
       ChangeImageCanvasSize(0, 0, 0, 0, 0, 0, 0, 1)
       Return
    }

    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    If (!whichBitmap || thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
    calcImgSelection2bmp(0, imgW, imgH, imgW - 1, imgH - 1, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    If (UserMemBMP=whichBitmap)
       xBitmap := UserMemBMP

    If (valueBetween(imgSelW, imgW - 2, imgW + 2) && valueBetween(imgSelH, imgH - 2, imgH + 2) && !imgSelPx && !imgSelPy)
    {
       MouseMoveResponder()
       SetTimer, RefreshImageFile, -25
       Return
    }

    UserMemBMP := Gdip_CloneBitmapArea(whichBitmap, imgSelPx, imgSelPy, imgSelW, imgSelH)
    activateImgSelection := editingSelectionNow := 0
    Gdip_DisposeImage(xBitmap, 1)
    MouseMoveResponder()
    SetTimer, RefreshImageFile, -25
}

corePasteClipboardImg(modus, imgW, imgH) {
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
          clipBMP := drawTextInBox(toPaste, OSDFontName, PasteFntSize, imgW, imgH, OSDtextColor, "0xFF" OSDbgrColor, 0, 0, usrTextAlign)
          If (modus=1)
             showTOOLtip("Text clipboard content rendered as image...`nOSD font and colors used")
          SetTimer, RemoveTooltip, % -msgDisplayTime
       } Else
       {
          Tooltip
          showTOOLtip("Unable to retrieve image from clipboard...")
          SetTimer, ResetImgLoadStatus, -25
          SoundBeep , 300, 100
          SetTimer, RemoveTooltip, % -msgDisplayTime
          Return
       }
    }

    ; disposeCacheIMGs()
    If (textMode!=1 && clipBMP)
    {
       isUniform := Gdip_TestBitmapUniformity(clipBMP, 7, maxLevelIndex)
       If (isUniform=1 && (valueBetween(maxLevelIndex, 0, 5) || valueBetween(maxLevelIndex, 250, 255)))
          Gdip_BitmapSetColorDepth(clipBMP, 24)
    }
    Return clipBMP
}

PasteClipboardIMG() {
    Static clippyCount := 0

    If (AnyWindowOpen || thumbsDisplaying=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    DestroyGIFuWin()
    showTOOLtip("Retrieving clipboard image, please wait...")
    changeMcursor()
    setImageLoading()
    calcScreenLimits()
    clipBMP := corePasteClipboardImg(1, ResolutionWidth*2, Round(ResolutionHeight*4.3))
    If !clipBMP
       Return

    UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
    clippyCount++
    If (activateImgSelection=1 || editingSelectionNow=1)
       toggleImgSelection()

    discardViewPortCaches()
    UserMemBMP := clipBMP
    If (!currentFileIndex || !CurrentSLD || !maxFilesIndex)
    {
       maxFilesIndex := currentFileIndex := 0
       resultedFilesList[currentFileIndex, 1] := "\Temporary Memory Object\Clipboard-" clippyCount ".img"
    }

    imgIndexEditing := currentFileIndex
    usrColorDepth := imgFxMode := 1
    vpIMGrotation := FlipImgH := FlipImgV := 0
    dropFilesSelection(1)
    RemoveTooltip()
    SetTimer, ResetImgLoadStatus, -50
    SetTimer, RefreshImageFile, -50
}

thumbsSelector(keyu, aKey, prevFileIndex) {
  Static lastInvoked := 1

  ; ToolTip, % prevFileIndex "--" markedSelectFile "`n" lola
  If (InStr(aKey, "+") && (keyu="Left" || keyu="Upu" || keyu="Home") && prevFileIndex<=1)
  || (InStr(aKey, "+") && (keyu="Right" || keyu="Down" || keyu="End") && prevFileIndex>=maxFilesIndex)
     Return

  selA := resultedFilesList[currentFileIndex, 2]
  selB := resultedFilesList[prevFileIndex, 2]
  If (InStr(aKey, "+") && (keyu="Left" || keyu="Right"))
  {
     testIndex := (keyu="Left") ? currentFileIndex : currentFileIndex
     selC := resultedFilesList[testIndex, 2]
     testIndex := (keyu="Left") ? prevFileIndex + 1 : prevFileIndex - 1
     selD := resultedFilesList[testIndex, 2]
     If (selA!=1 && selB!=1) || (selA=1 && selB!=1)
     || (selA=1 && selB=1 && selC=1 && selD=1)
     {
        selA := selB := 0
        dropFilesSelection(1)
        markedSelectFile++
     }

     If (selA!=1 && selB!=1) || (selA!=1 && selB=1) || (selA=1 && selB!=1)
     {
        resultedFilesList[currentFileIndex, 2] := 1
        resultedFilesList[prevFileIndex, 2] := 1
     } Else If (selA=1 && selB=1)
     {
        resultedFilesList[currentFileIndex, 2] := 1
        resultedFilesList[prevFileIndex, 2] := 0
        markedSelectFile -= 2
     }

     markedSelectFile++
  } Else If InStr(aKey, "+") ; && (keyu="Upu" || keyu="Down"))
  {
     direction := (keyu="Down" || keyu="PgDn" || keyu="End") ? 1 : 0
     testIndex := (direction!=1) ? currentFileIndex : currentFileIndex
     selC := resultedFilesList[testIndex, 2]
     testIndex := (direction!=1) ? prevFileIndex + 1 : prevFileIndex - 1
     selD := resultedFilesList[testIndex, 2]
     If (selA!=1 && selB!=1) || (selA=1 && selB!=1)
     || (selA=1 && selB=1 && selC=1 && selD=1)
     {
        selA := selB := 0
        dropFilesSelection(1)
     }

     If (selA!=1 && selB!=1) || (selA!=1 && selB=1) || (selA=1 && selB!=1)
     {
        selectFilesRange(currentFileIndex, prevFileIndex, 1)
     } Else If (selA=1 && selB=1)
     {
        selectFilesRange(currentFileIndex, prevFileIndex, 0)
        resultedFilesList[currentFileIndex, 2] := 1
        markedSelectFile++
     }
  }

  If (markedSelectFile=1 && InStr(aKey, "+"))
  {
     markedSelectFile := 0
     resultedFilesList[currentFileIndex, 2] := 0
  }
}

generateNumberRangeString(pA, pB) {
    mB := max(pA, pB)
    mA := min(pA, pB)
    rangeC := mB - mA + 1
    Loop, % rangeC
        stringRange .= "," mA + A_Index - 1 "|"

    Return stringRange
}

selectFilesRange(pA, pB, sel) {
    mB := max(pA, pB)
    mA := min(pA, pB)
    rangeC := mB - mA + 1
    Loop, % rangeC
    {
        oSel := resultedFilesList[mA + A_Index - 1, 2]
        resultedFilesList[mA + A_Index - 1, 2] := sel
        If (sel=1 && oSel!=1)
           markedSelectFile++
        Else If (sel!=1 && oSel=1)
           markedSelectFile--
    }

    Return rangeC
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
   If (CurrentSLD && maxFilesIndex>0) || StrLen(UserMemBMP)>2
   {
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
   }
}

openPreviousPanel() {
   thisFunc := prevOpenedWindow[2]
   If thisFunc
      %thisFunc%()
}

createSettingsGUI(IDwin, thisCaller:=0) {
    If (slideShowRunning=1)
       ToggleSlideShowu()

    If (editingSelectionNow=1 && imgEditPanelOpened!=1)
       ToggleEditImgSelection()

    If (imgEditPanelOpened=1)
    {
       If AnyWindowOpen
          Try WinGetPos, prevSetWinPosX, prevSetWinPosY,,, ahk_id %hSetWinGui%
       DestroyGIFuWin()
       Gui, SettingsGUIA: Destroy
       Sleep, 5
    } Else CloseWindow()
    Sleep, 15
    interfaceThread.ahkassign("AnyWindowOpen", IDwin)
    Gui, SettingsGUIA: Default
    Gui, SettingsGUIA: -MaximizeBox -MinimizeBox +Owner%PVhwnd% hwndhSetWinGui
    Gui, SettingsGUIA: Margin, 15, 15
    AnyWindowOpen := IDwin
    prevOpenedWindow := []
    prevOpenedWindow := [AnyWindowOpen, thisCaller]
}

ShowImgInfosPanel() {
    Global LViewMetaD
    If (thumbsDisplaying=1)
       MenuDummyToggleThumbsMode()

    imgPath := getIDimage(currentFileIndex)
    zPlitPath(imgPath, 0, fileNamu, folderu)
    If !FileRexists(imgPath)
    {
       showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
       SoundBeep, 300, 50
       Return
    }

    createSettingsGUI(5, "ShowImgInfosPanel")
    btnWid := 105
    txtWid := 360
    lstWid := 545
    If (PrefsLargeFonts=1)
    {
       lstWid := lstWid + 230
       btnWid := btnWid + 75
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    Gui, Add, ListView, x15 y15 w%lstWid% r12 Grid vLViewMetaD, Property|Data
    Gui, Add, Button, xs+0 y+20 h30 w40 gInfoBtnPrevImg, <<
    Gui, Add, Button, x+5 hp wp gInfoBtnNextImg, >>
    Gui, Add, Button, x+15 hp w%btnWid% gcopyIMGinfos2clip, &Copy to clipboard
    Gui, Add, Button, x+5 hp w%btnWid% gOpenThisFileFolder, &Open in folder
    Gui, Add, Button, x+5 hp w%btnWid% gOpenFileProperties, &File properties
    Gui, Add, Button, x+5 hp w90 Default gCloseWindow, C&lose
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Image metadata: %appTitle%
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
      Catch wasError
          Sleep, 1

      If wasError
      {
         showTOOLtip("ERROR: Unable to copy to clipboard file details...")
         SoundBeep , 300, 100
      } Else showTOOLtip("File details copied to the clipboard...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

PopulateImgInfos() {
   Gui, SettingsGUIA: ListView, LViewMetaD
   LV_Delete()
   resultu := getIDimage(currentFileIndex)
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

   zoomu := Round(zoomLevel*100)
   If (thisIMGisDownScaled=1)
      infoDownScale := " [DOWNSCALED] "

   generalInfos := "File name||" fileNamu "`nLocation||" folderu "\`nFile size||" fileSizu " kilobytes`nDate created||" FileDateC "`nDate modified||" FileDateM "`nResolution (W x H)||" Width " x " Height " (in pixels)`nCurrent zoom level||" zoomu " % (" DefineImgSizing() infoDownScale ")"
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
   diffRGBtotal := max(sumTotalR, sumTotalG, sumTotalB) - min(sumTotalR, sumTotalG, sumTotalB)
   diffRGBtotal := diffRGBtotal/max(sumTotalR, sumTotalG, sumTotalB)
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
   If (!fileAttribs || InStr(fileAttribs, "D") || fileSizu<120 || !FileSizu)
      Return 0
   Else
      Return 1
}

hFindIsFolder(ByRef fileInfos) {
   Static FILE_ATTRIBUTE_DIRECTORY := 0x10
   Return NumGet(&fileInfos,0,"UInt") & FILE_ATTRIBUTE_DIRECTORY
}

hFindGetName(ByRef fileInfos) {
   cFileName := StrGet(&fileInfos + 44, 260, "UTF-16")
   If (cFileName="." || cFileName="..")
      cFileName := ""
   Return cFileName
}


testGetFile(filePath) {
  ; SizeInBytes := 568 + 3 * 8 = 592
    VarSetCapacity(Win32FindData, 1512, 0)

    hFind := DllCall("FindFirstFileW", "WStr", filePath "\*", "Ptr", &Win32FindData, "Ptr")
    cFileName := hFindGetName(Win32FindData)
    If (hFindIsFolder(Win32FindData) && cFileName)
    {
    ;  MsgBox, folderrr
       testGetFile(filePath "\" cFileName)
    } Else If (RegExMatch(cFileName, RegExFilesPattern))
    {
       maxFilesIndex++
       resultedFilesList[maxFilesIndex] := [filePath "\" cFileName]
    }

   ; MsgBox, % filePath "`n" hFind "`n" cFileName "`n" cAlternateFileName "`n" ErrorLevel "`n" A_LastError


 ;   instance.nFileSizeHigh := NumGet(&Win32FindData, 28,  "UInt")
;    instance.nFileSizeLow := NumGet(&Win32FindData, 32,  "UInt")

    While (r := DllCall("FindNextFileW", "ptr", hFind, "ptr", &Win32FindData)) {
          cFileName := hFindGetName(Win32FindData)
          If hFindIsFolder(Win32FindData) && cFileName
          {
             testGetFile(filePath "\" cFileName)
          } Else If (RegExMatch(cFileName, RegExFilesPattern))
          {
             maxFilesIndex++
             resultedFilesList[maxFilesIndex] := [filePath "\" cFileName]
          }
    ; MsgBox, % filePath "`n" r "`n" hFind "`n" cFileName "`n" cAlternateFileName "`n" ErrorLevel "`n" A_LastError
    }

   ; maxFilesIndex := resultedFilesList.Length()
    ; SoundBeep 
    Return
}

testGetFile2(filePath) {
  ; SizeInBytes := 568 + 3 * 8 = 592
    VarSetCapacity(Win32FindData, 318+1024, 0)
    if (hFind := DllCall("FindFirstFileW", "WStr", filePath "\*", "Ptr", &Win32FindData, "Ptr")) {
        cFileName := StrGet(&Win32FindData + 44, 260, "UTF-16")
        cAlternateFileName := StrGet(&Win32FindData + 564, 14, "UTF-16")
        
        MsgBox, %  hFind "`n" cFileName "`n" cAlternateFileName "`n" ErrorLevel "`n" A_LastError
        While (r := DllCall("FindNextFileW", "ptr", hFind, "ptr", &Win32FindData)) {
            cFileNamea := StrGet(&Win32FindData + 44, 260, "UTF-16")
            cAlternateFileNamea := StrGet(&Win32FindData + 564, 14, "UTF-16")
            MsgBox, %  r "`n" cFileNameA "`n" cAlternateFileNameA "`n" ErrorLevel "`n" A_LastError
        }
    }
    Return
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
   imgPath := getIDimage(currentFileIndex)
   zPlitPath(imgPath, 0, fileNamu, folderu)
   showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
   winTitle := "[*] " currentFileIndex "/" maxFilesIndex " | " fileNamu " | " folderu
   setWindowTitle(winTitle, 1)
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
     BtnApplyFilesFilter()
}


readRecentFiltersEntries() {
   testFilteru := Trim(StrReplace(usrFilesFilteru, "&"))
   entriesList .= StrLen(usrFilesFilteru)>1 ? "--={ no filter }=--`n" : ""
   Loop, 20
   {
       IniRead, newEntry, % mainSettingsFile, RecentFilters, E%A_Index%, @
       newEntry := Trim(newEntry)
       If ((newEntry="--={ no filter }=--") || InStr(entriesList, newEntry "`n") || !newEntry)
          Continue

       addSel := (newEntry=testFilteru) ? "`n" : ""
       If StrLen(newEntry)>1
          entriesList .= newEntry "`n" addSel
   }
   Return entriesList
}

EraseFilterzHisto() {
  IniDelete, % mainSettingsFile, RecentFilters
  CloseWindow()
  Sleep, 50
  PanelEnableFilesFilter()
}

PanelEnableFilesFilter() {
    Global UsrEditFilter
    If (maxFilesIndex<3 && !usrFilesFilteru)
       Return

    createSettingsGUI(6, "PanelEnableFilesFilter")
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

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gBtnApplyFilesFilter, &Apply filter
    Gui, Add, Checkbox, x+5 hp Checked%UsrMustInvertFilter% vUsrMustInvertFilter, Invert filter
    Gui, Add, Button, x+35 hp w%btnWid% gEraseFilterzHisto, Erase &history
    Gui, Add, Button, x+5 hp w85 gCloseWindow, C&lose
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Files list filtering: %appTitle%
}

BtnApplyFilesFilter() {
   GuiControlGet, UsrEditFilter
   GuiControlGet, UsrMustInvertFilter
   CloseWindow()
   Sleep, 2
   UsrEditFilter := Trim(UsrEditFilter)
   UsrEditFilter := StrReplace(UsrEditFilter, "||", "|")
   UsrEditFilter := Trim(UsrEditFilter, "|")
   UsrEditFilter := StrReplace(UsrEditFilter, "&")
   If (!UsrEditFilter && !filesFilter)
      Return

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

   If AnyWindowOpen
   {
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
 
      Gui, SettingsGUIA: +OwnDialogs
      MsgBox, % theseOptionz, % winTitle, % msg
      lastLongOperationAbort := A_TickCount
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
   } Else
   {
      r := interfaceThread.ahkFunction("msgBoxWrapper", winTitle, msg, buttonz, defaultBTN, iconz, modality, optionz)
      lastLongOperationAbort := A_TickCount
      Return r
   }
}

coreEnableFiltru(stringu) {
  backCurrentSLD := CurrentSLD
  userSearchString := CurrentSLD := ""
  friendly := (StrLen(stringu)>1) ? "Applying filter on the list of files, please wait...`n" stringu : "Deactivating the files list filter, please wait..."
  showTOOLtip(friendly)
  setImageLoading()
  If StrLen(filesFilter)<2
  {
     thereWasFilter := 0
     bckpResultedFilesList := []
     bckpResultedFilesList := resultedFilesList.Clone()
     bkcpMaxFilesIndex := maxFilesIndex
  } Else thereWasFilter := 1

  usrFilesFilteru := stringu
  testRegEx := SubStr(stringu, 1, 2)
  If (testRegEx!="\>")
     filesFilter := JEE_StrRegExLiteral(stringu)
  Else
     filesFilter := SubStr(stringu, 3)

  filesFilter := StrReplace(filesFilter, "&")
  FilterFilesIndex(thereWasNoFilter)
  If (maxFilesIndex<1)
  {
     SoundBeep, 300, 100
     msgBoxWrapper(appTitle, "No files matched your filtering criteria:`n" usrFilesFilteru "`n`nThe application will now restore the complete list of files.", 0, 0, "ïnfo")
     usrFilesFilteru := filesFilter := ""
     FilterFilesIndex()
  } Else SoundBeep, 950, 100

  CurrentSLD := backCurrentSLD
  SetTimer, ResetImgLoadStatus, -50
  If (maxFilesIndex>0)
     RandomPicture()

  SetTimer, RemoveTooltip, % -msgDisplayTime
}

FilterFilesIndex(thereWasFilter:=0) {
   startZeit := A_TickCount
   newFilesIndex := 0
   newFilesList := []
   newMappingList := []
   filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
   If (filesFilter="||Prev-Files-Selection||")
   {
       Loop, % maxFilesIndex + 1
       {
            r := resultedFilesList[A_Index, 1]
            If (InStr(r, "||") || !r)
               Continue

            If (resultedFilesList[A_Index, 2]!=1)
               Continue

            newFilesIndex++
            newFilesList[newFilesIndex] := [r]
            If (thereWasFilter=1)
            {
               oldIndex := filteredMap2mainList[A_Index]
               newMappingList[newFilesIndex] := oldIndex
            } Else newMappingList[newFilesIndex] := A_Index
       }
   } Else
   {
       Loop, % bkcpMaxFilesIndex + 1
       {
            r := bckpResultedFilesList[A_Index, 1]
            If (InStr(r, "||") || !r)
               Continue

            thisIndex++
            If StrLen(filesFilter)>1
            {
               If filterCoreString(r, filterBehaviour, filesFilter)
                  Continue
            }

            newFilesIndex++
            newFilesList[newFilesIndex] := [r]
            If StrLen(filesFilter)>1
               newMappingList[newFilesIndex] := A_Index
       }
   }
   filteredMap2mainList := []
   renewCurrentFilesList()
   If StrLen(filesFilter)>1
      filteredMap2mainList := newMappingList.Clone()
   resultedFilesList := newFilesList.Clone()
   maxFilesIndex := newFilesIndex
   newFilesList := []
   newMappingList := []
   ; MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000)
   GenerateRandyList()
}

throwMSGwriteError() {
  Static lastInvoked := 1
  If (ErrorLevel=1) && (A_TickCount - lastInvoked>45100)
  {
     SoundBeep, 300, 900
     msgBoxWrapper(appTitle ": ERROR", "Unable to write or access the settings files: permission denied...", 0, 0, "error")
     lastInvoked := A_TickCount
  }
}

InListMultiEntriesRemover() {
   filesElected := getSelectedFiles(0, 1)
   If (markedSelectFile>1)
      itsMultiFiles := 1

   If (itsMultiFiles!=1)
   {
      remCurrentEntry(0, 0)
      Return
   }

   If (filesElected>500)
   {
      msgResult := msgBoxWrapper(appTitle, "Are you sure you want to remove " filesElected " entries from the slideshow files list?", 4, 0, "question")
      If (msgResult!="yes")
         Return
   }

   showTOOLtip("Removing " filesElected " index entries, please wait...")
   prevMSGdisplay := A_TickCount
   ForceRefreshNowThumbsList()
   prevMaxy := maxFilesIndex
   countTFilez := 0
   If (SLDtypeLoaded=3)
      activeSQLdb.Exec("BEGIN TRANSACTION;")

   Loop, % prevMaxy * 2 + 1
   {
      thisFileIndex := A_Index - countTFilez
      isSelected := resultedFilesList[thisFileIndex, 2]
      If (isSelected!=1)
         Continue

      countTFilez++
      executingCanceableOperation := A_TickCount
      If !startPoint
         startPoint := thisFileIndex

      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Removing " countTFilez "/" filesElected " index entries, please wait...")
         prevMSGdisplay := A_TickCount
      }
      ; ToolTip, % thisFileIndex " -- " A_Index , , , 2
      remCurrentEntry(dummy, 1, 1, thisFileIndex)
      changeMcursor()
   }

   If (SLDtypeLoaded=3)
      activeSQLdb.Exec("COMMIT TRANSACTION;")

   GenerateRandyList()
   showTOOLtip(countTFilez " index entries removed...")
   markedSelectFile := 0
   setImageLoading()
   If (maxFilesIndex<1)
   {
      FadeMainWindow()
      If StrLen(filesFilter)>1
      {
         changeMcursor()
         showTOOLtip("Removing files list index filter, please wait...")
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
         RandomPicture()
      } Else
      {
         msgBoxWrapper(appTitle, "No files left in the index of " appTitle ", please (re)open a file or folder...", 0, 0, "info")
         resetMainWin2Welcome()
      }
   } Else
   {
      startPoint--
      If (startPoint<2)
         startPoint := 1
      currentFileIndex := startPoint
      dummyTimerDelayiedImageDisplay(50)
   }
   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

remCurrentEntry(dummy, silentus:=0, batchMode:=0, whichIndex:=0) {
   Critical, on
   thisFileIndex := !whichIndex ? currentFileIndex : whichIndex
   file2remZ := resultedFilesList.RemoveAt(thisFileIndex)
   ; file2remA := file2remZ[1]
   If StrLen(filesFilter)>1
   {
      ; oldIndex :=  filteredMap2mainList[thisFileIndex]
      file2remC := filteredMap2mainList.RemoveAt(thisFileIndex)
      ; file2remB := bckpResultedFilesList[oldIndex, 1]
      bckpResultedFilesList[filteredMap2mainList[thisFileIndex], 1] := ""
      ; Sleep, 200
      ; ToolTip, % file2remC " b " oldIndex " a " file2remB "`n" file2remA, , , 2
   }

   If (SLDtypeLoaded=3 || batchMode!=1)
   {
      file2rem := StrReplace(file2remZ[1], "||")
      zPlitPath(file2rem, 1, OutFileName, OutDir)
      If (batchMode=1)
         deleteSQLdbEntry(OutFileName, OutDir)
    }

   maxFilesIndex--
   If (batchMode=1)
      Return

   ForceRefreshNowThumbsList()
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (silentus!=1)
      showTOOLtip("Index entry removed...`n" OutFileName "`n" OutDir "\")

   If (maxFilesIndex<1)
   {
      FadeMainWindow()
      If StrLen(filesFilter)>1
      {
         showTOOLtip("Removing files list index filter, please wait...")
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
         RandomPicture()
      } Else
      {
         msgBoxWrapper(appTitle, "No files left in the index of " appTitle ", please (re)open a file or folder...", 0, 0, "info")
         resetMainWin2Welcome()
      }
   } Else 
   {
      currentFileIndex--
      NextPicture()
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

addSQLdbEntry(fileNamu, imgPath, fileSizu, fileMdate, fileCdate) {
   SQLstr := "INSERT INTO images (imgfile, imgfolder, fsize, fmodified, fcreated) VALUES ('" fileNamu "', '" imgPath "', '" fileSizu "', '" fileMdate "', '" fileCdate "');"
   If !activeSQLdb.Exec(SQLStr)
   {
      stringA := fileNamu
      activeSQLdb.EscapeStr(stringA)
      stringB := imgPath
      activeSQLdb.EscapeStr(stringB)
      ; MsgBox, % stringA "--" stringB 
      SQLstr := "INSERT INTO images (imgfile, imgfolder, fsize, fmodified, fcreated) VALUES (" stringA ", " stringB ", '" fileSizu "', '" fileMdate "', '" fileCdate "');"
      activeSQLdb.Exec(SQLStr)
   }
}

updateSQLdbEntryImgRes(fileNamu, imgPath, imgW, imgH) {
   SQLstr := "UPDATE images SET imgwith='" imgW "', imgheight='" imgH "' WHERE (imgfile='" fileNamu "' AND imgfolder='" imgPath "');"
   If !activeSQLdb.Exec(SQLStr)
   {
      stringA := fileNamu
      activeSQLdb.EscapeStr(stringA)
      stringB := imgPath
      activeSQLdb.EscapeStr(stringB)
      ; MsgBox, % stringA "--" stringB 
      SQLstr := "UPDATE images SET imgwith='" imgW "', imgheight='" imgH "' WHERE (imgfile=" stringA " AND imgfolder=" stringB ");"
      activeSQLdb.Exec(SQLStr)
   }
}

deleteSQLdbEntry(fileNamu, imgPath) {
  SQLstr := "DELETE FROM images WHERE (imgfile='" fileNamu "' AND imgfolder='" imgPath "');"
  If !activeSQLdb.Exec(SQLStr)
  {
     stringA := fileNamu
     activeSQLdb.EscapeStr(stringA)
     stringB := imgPath
     activeSQLdb.EscapeStr(stringB)
     SQLstr := "DELETE FROM images WHERE (imgfile=" stringA " AND imgfolder=" stringB ");"
     activeSQLdb.Exec(SQLStr)
  }
}

openFileDialogWrapper(optionz, startPath, msg, pattern) {
   If AnyWindowOpen
   {
      Gui, SettingsGUIA: +OwnDialogs
      FileSelectFile, file2save, % optionz, % startPath, % msg, % pattern
      If (!ErrorLevel && StrLen(file2save)>2)
         r := file2save
      lastLongOperationAbort := A_TickCount
      Return r
   } Else
   {
      r := interfaceThread.ahkFunction("openFileDialogWrapper", optionz, startPath, msg, pattern)
      lastLongOperationAbort := A_TickCount
      Return r
   }
}

WritePrefsIntoSLD() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   startPath := !CurrentSLD ? prevOpenFolderPath : CurrentSLD
   file2save := openFileDialogWrapper("S3", startPath, "Save slideshow settings into file...", "Slideshow (*.sld)")
   If file2save
   {
      If !RegExMatch(file2save, sldsPattern)
         file2save .= ".sld"

      FileReadLine, firstLine, % file2save, 1
      If InStr(firstLine, "[General]")
      {
         IniWrite, % (SLDcacheFilesList=1) ? "Yes" : "Nope", % file2save, General, UseCachedList
         Sleep, 10
         writeSlideSettings(file2save)
      } Else 
      {
         zPlitPath(file2save, 0, OutFileName, OutDir)
         msgBoxWrapper(appTitle ": ERROR", "The selected file appears not to have the correct file format.`nPlease select a .SLD file already saved by this application.`n`n" OutFileName, 0, 0, "error")
      }
   }
}

SaveDBfilesList() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(maxFilesIndex)>1
   {
      If StrLen(filesFilter)>1
      {
         msgResult := msgBoxWrapper(appTitle ": Save slideshow", "The files list is filtered down to " maxFilesIndex " files from " bkcpMaxFilesIndex ".`n`nTo save as a slideshow the entire list of files, remove the filter by pressing Ctrl + F.", 1, 0, "info")
         If (msgResult="cancel")
            Return
      }
      file2save := openFileDialogWrapper("S2", CurrentSLD, "Save files list as Slideshow...", "Slideshow (*.sld)")
      If !RegExMatch(file2save, "i)(.\.sldb)$")
         file2save .= ".sldb"
   } Else Return

   If (SLDtypeLoaded=1 || SLDtypeLoaded=2) && file2save
   {
      setImageLoading()
      showTOOLtip("Saving list of " maxFilesIndex " entries into a database...`n" file2save "`nPlease wait...")

      initSQLdb(file2save)
      saveDynaFolders := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
      Sort, saveDynaFolders, UD`n
      activeSQLdb.Exec("BEGIN TRANSACTION;")
      Loop, Parse, saveDynaFolders, `n
      {
          If StrLen(A_LoopField)>1
             addDynamicFolderSQLdb(Trim(A_LoopField), 0, "dynamicfolders")
      }

      activeSQLdb.Exec("COMMIT TRANSACTION;")
      activeSQLdb.Exec("BEGIN TRANSACTION;")
      staticFoldersListu := ""
      If (SLDcacheFilesList=1 && SLDtypeLoaded=2)
      {
         populatedStaticFolders := 1
         rawstaticFoldersListu := LoadStaticFoldersCached(CurrentSLD, irrelevantVar)
         Loop, Parse, rawstaticFoldersListu, `n
         {
             If StrLen(A_LoopField)>2
                lineArru := StrSplit(A_LoopField, "*&*")
             Else
                Continue
             folderu := lineArru[2]
             oldDateu := lineArru[1]
             oldDateu := SubStr(oldDateu, InStr(oldDateu, "=")+1)
             staticFoldersListu .= folderu "`n"
             addStaticFolderSQLdb(folderu, oldDateu, 0)
         }
      }

      activeSQLdb.Exec("COMMIT TRANSACTION;")
      activeSQLdb.Exec("BEGIN TRANSACTION;")
      allFoldersList := saveDynaFolders "`n" staticFoldersListu
      Sort, allFoldersList, UD`n

      startZeit := A_TickCount
      Loop, Parse, allFoldersList, `n
      {
          If StrLen(A_LoopField)>2
             strDir := Trim(A_LoopField)
          Else
             Continue

          ; MsgBox, % strDir
          dig := "R"
          If InStr(strDir, "|")
          {
             strDir := StrReplace(strDir, "|")
             dig := ""
          }

          Loop, Files, %strDir%\*, %dig%
          {
              If RegExMatch(A_LoopFileName, RegExFilesPattern) && (A_LoopFileSize>120)
                 addSQLdbEntry(A_LoopFileName, A_LoopFileDir, A_LoopFileSize, A_LoopFileTimeModified, A_LoopFileTimeCreated)
          }
      }
      activeSQLdb.Exec("COMMIT TRANSACTION;")

      ; MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000)
      If (populatedStaticFolders!=1)
      {
         SQL := "SELECT DISTINCT imgfolder FROM images;"
         RecordSet := ""
         FoldersArray := []
         If !activeSQLdb.Query(SQL, RecordSet)
            SoundBeep, 300, 900
 
         activeSQLdb.Exec("BEGIN TRANSACTION;")
         Loop
         {
             FoldersArray[A_Index] := Row[1] ; Row[1]
             RC := RecordSet.Next(Row)
         } Until (RC < 1)
 
         RecordSet.Free()
         Loop, % FoldersArray.Count()
         {
             thisFolder := Trim(FoldersArray[A_Index])
             If StrLen(thisFolder)>1
                addDynamicFolderSQLdb(thisFolder, 0, "staticfolders")
         }
         activeSQLdb.Exec("COMMIT TRANSACTION;")
      }
      CurrentSLD := file2save
      SLDtypeLoaded := 3
      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, 900, 100
      RemoveTooltip()
   } Else If (CurrentSLD=file2save && SLDtypeLoaded=3)
   {
      showTOOLtip("Slideshow database saved.")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   } Else If (CurrentSLD!=file2save && SLDtypeLoaded=3)
   {
      FileCopy, % CurrentSLD, % file2save, 1
      activeSQLdb.CloseDB()
      activeSQLdb := new SQLiteDB
      If !activeSQLdb.OpenDB(file2save)
      {
         showTOOLtip("ERROR: Failed to save the slideshow database...")
         SoundBeep, 300, 100
         SetTimer, RemoveTooltip, % -msgDisplayTime
         Return -1
      }
      CurrentSLD := file2save
      showTOOLtip("Slideshow database saved.")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

SaveFilesList() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(maxFilesIndex)>1
   {
      If StrLen(filesFilter)>1
      {
         msgResult := msgBoxWrapper(appTitle ": Save slideshow", "The files list is filtered down to " maxFilesIndex " files from " bkcpMaxFilesIndex ".`n`nTo save as a slideshow the entire list of files, remove the filter by pressing Ctrl + F.", 1, 0, "info")
         If (msgResult="cancel")
            Return
      }
      file2save := openFileDialogWrapper("S2", CurrentSLD, "Save files list as Slideshow...", "Slideshow (*.sld)")
   } Else Return

   If file2save
   {
      msgResult := msgBoxWrapper(appTitle ": Save slideshow confirmation", "Do you want to store the current slideshow settings as well ?", 3, 0, "question")
      If (msgResult="Yes")
         IgnoreThesePrefs := "Nope"
      Else If (msgResult="No")
         IgnoreThesePrefs := "Yes"
      Else If (msgResult="Cancel")
         Return

      If FileExist(file2save)
      {
         zPlitPath(file2save, 0, OutFileName, OutDir)
         msgResult := msgBoxWrapper(appTitle ": Confirmation", "Are you sure you want to overwrite selected file?`n`n" OutFileName, 3, 0, "question")
         If (msgResult="Yes")
         {
            FileSetAttrib, -R, %file2save%
            Sleep, 1
            If (file2save=CurrentSLD)
            {
               newTmpFile := file2save "-bkcp"
               Try FileMove, %file2save%, %newTmpFile%, 1
               Catch wasErrorA
                     Sleep, 1
            } Else
            {
               Try FileDelete, %file2save%
               Catch wasErrorB
                     Sleep, 1
            }

            If (wasErrorA || wasErrorB)
            {
               msgBoxWrapper(appTitle ": ERROR", "Unable to write or access the file. Permission denied...", 0, 0, "error")
               Return
            }
         } Else If (msgResult="No")
         {
            SaveFilesList()
            Return
         } Else If (msgResult="Cancel")
            Return
      }

      Sleep, 2
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      setImageLoading()
      IniWrite, % IgnoreThesePrefs, % file2save, General, IgnoreThesePrefs
      IniWrite, % (SLDcacheFilesList=1) ? "Yes" : "Nope", % file2save, General, UseCachedList
      Sleep, 10
      writeSlideSettings(file2save)
      setWindowTitle("Saving slideshow, please wait", 1)
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

      If (mustGenerateStaticFolders=1 || ForceRegenStaticFolders=1) && (SLDcacheFilesList=1)
      {
         filesListu .= printLargeStrArray(resultedFilesList, maxFilesIndex + 1, "`n")
         Loop, % maxFilesIndex + 1
         {
              r := getIDimage(A_Index)
              If (InStr(r, "||") || !r)
                 Continue

              changeMcursor()
              zPlitPath(r, 1, irrelevantVar, OutDir)
              foldersList .= OutDir "`n"
         ;     filesListu .= r "`n"
         }
      } Else If (SLDcacheFilesList=1)
         filesListu .= printLargeStrArray(resultedFilesList, maxFilesIndex + 1, "`n")

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

      Try {
          FileAppend, % dynaFolderListu, % file2save, UTF-16
          Sleep, 10
          FileAppend, % foldersListu, % file2save, UTF-16
          Sleep, 10
          FileAppend, % filesListu, % file2save, UTF-16
      } Catch wasErrorC
          Sleep, 1
 
      FileDelete, % newTmpFile
      SetTimer, RemoveTooltip, % -msgDisplayTime//2
      CurrentSLD := file2save
      SLDtypeLoaded := 2
      DynamicFoldersList := "|hexists|"
      mustGenerateStaticFolders := 0
      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, % wasErrorC ? 300 : 900, 100
      If wasErrorC
         msgBoxWrapper(appTitle ": ERROR", "There were errors writing the slideshow file to disk. Permission denied or not enough disk space...", 0, 0, "error")
      dummyTimerDelayiedImageDisplay(50)
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

    changeMcursor("normal")
    Return staticFoldersListCache
}

determineTerminateOperation() {
  Static lastInvoked := 1
  If (A_TickCount - lastInvoked < 200)
     Return 0

  lastInvoked := A_TickCount
  theEnd := interfaceThread.ahkgetvar.mustAbandonCurrentOperations
  If theEnd
     lastLongOperationAbort := A_TickCount
  Return theEnd
  ; wasESC := GetKeyState("Esc", "P")
  ; If ((wasESC=1 || GetKeyState("LButton", "P")) && identifyThisWin()) || (theEnd>0)
  ; {
  ;    interfaceThread.ahkassign("mustAbandonCurrentOperations", 0)
  ;    interfaceThread.ahkassign("lastCloseInvoked", 0)
  ;    If (wasESC!=1 && theEnd!=2)
  ;       msgResult := msgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
  ;    If (msgResult="yes" || wasESC=1)
  ;    {
  ;       interfaceThread.ahkassign("runningLongOperation", 0)
  ;       lastLongOperationAbort := A_TickCount
  ;       Return 1
  ;    } Else Return 0
  ; } Else Return 0
}

doStartLongOpDance() {
     startLongOperation := A_TickCount
     imageLoading := runningLongOperation := 1
     interfaceThread.ahkassign("mustAbandonCurrentOperations", 0)
     interfaceThread.ahkassign("lastCloseInvoked", 0)
     interfaceThread.ahkassign("imageLoading", 1)
     interfaceThread.ahkassign("runningLongOperation", 1)
     interfaceThread.ahkassign("executingCanceableOperation", A_TickCount)
}

cleanFilesList(noFilesCheck:=0) {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   WnoFilesCheck := (noFilesCheck=2) ? 2 : 0
   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      markedSelectFile := 0
      filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
      If StrLen(filesFilter)>1
      {
         showTOOLtip("Preparing the files list index...")
         setWindowTitle("Preparing the files list index...", 1)
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      msgInfos := (noFilesCheck=2) ? "Sorting" : "Cleaning"
      setWindowTitle(msgInfos " files list, please wait", 1)
      showTOOLtip(msgInfos " files list, please wait")
      prevMSGdisplay := A_TickCount
      doStartLongOpDance()
      If (noFilesCheck=2)
         filesListu := printLargeStrArray(resultedFilesList, maxFilesIndex, "`n")

      Loop, % maxFilesIndex + 1
      {
          If (noFilesCheck=2)
             Break

          r := getIDimage(A_Index)
          If (InStr(r, "||") || !r)
             Continue

          executingCanceableOperation := A_TickCount
          changeMcursor()
          If StrLen(backfilesFilter)>1
          {
             z := filterCoreString(r, filterBehaviour, backfilesFilter)
             noFilesCheck := (z=1) ? 2 : WnoFilesCheck
          }

          If (determineTerminateOperation()=1)
          {
             abandonAll := 1
             Break
          }

          countTFilez++
          If (A_TickCount - prevMSGdisplay>3000)
          {
             showTOOLtip("Checking for dead files... " countTFilez "/" maxFilesIndex ", please wait...")
             prevMSGdisplay := A_TickCount
          }
          ; If (testFileExistence(r)>100)  ; If FileExist(r)
          If FileRexists(r)
             filesListu .= r "`n"
      }

      If (abandonAll=1)
      {
         showTOOLtip("Operation aborted. Files list unchanged.")
         SetTimer, RemoveTooltip, % -msgDisplayTime
         CurrentSLD := backCurrentSLD
         SetTimer, ResetImgLoadStatus, -50
         SoundBeep, 300, 100
         lastLongOperationAbort := A_TickCount
         Return
      }

      If (noFilesCheck=2)
         showTOOLtip("Sorting files list by folder path and file name, please wait...")
      Else If (A_TickCount - prevMSGdisplay>1500)
         showTOOLtip("Removing duplicates from the list, please wait...")

      changeMcursor()
      Sort, filesListu, U D`n
      renewCurrentFilesList()
      Loop, Parse, filesListu,`n
      {
          If StrLen(A_LoopField)<2
             Continue

          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := [A_LoopField]
      }

      ForceRefreshNowThumbsList()
      If StrLen(backfilesFilter)>1
      {
         bckpResultedFilesList := []
         bckpResultedFilesList := resultedFilesList.Clone()
         bkcpMaxFilesIndex := maxFilesIndex
         usrFilesFilteru := backusrFilesFilteru
         filesFilter := backfilesFilter
         FilterFilesIndex()
      } Else GenerateRandyList()

      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, 900, 100
      CurrentSLD := backCurrentSLD
      RandomPicture()
      SetTimer, RemoveTooltip, % -msgDisplayTime//2
   }
}

dbSortingCached(SortCriterion) {

   If (maxFilesIndex>1)
   {
      If AnyWindowOpen
         CloseWindow()
      setImageLoading()
      showTOOLtip("Gathering information for " maxFilesIndex " files, please wait...")
      setWindowTitle("Sorting files list, please wait", 1)
      RecordSet := ""
      SQL := "SELECT imgfolder||'\'||imgfile AS imgPath FROM images ORDER BY " SortCriterion ";"
      If !activeSQLdb.Query(SQL, RecordSet)
      {
         SetTimer, ResetImgLoadStatus, -50
         SoundBeep, 300, 100
         SetTimer, RemoveTooltip, -500
         Return -1
      }

      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      markedSelectFile := 0
      previmgPath := getIDimage(currentFileIndex)
      If StrLen(filesFilter)>1
      {
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         ; FilterFilesIndex()
      }

      showTOOLtip("Generating sorted files list index...")
      renewCurrentFilesList()
      startOperation := A_TickCount
      Loop
      {
          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := [Row[1]]
          RC := RecordSet.Next(Row)
      } Until (RC<1)
      RecordSet.Free()

      ForceRefreshNowThumbsList()
      If StrLen(backfilesFilter)>1
          coreEnableFiltru(backusrFilesFilteru)
      Else
          GenerateRandyList()

      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, 900, 100
      Sleep, 25
      SetTimer, RemoveTooltip, -500
      CurrentSLD := backCurrentSLD
      currentFileIndex := detectFileID(prevImgPath)
      IDshowImage(currentFileIndex)
  }

  ; MsgBox, % ("Files: " maxFilesIndex "Query: " . SQL . " done in " . (A_TickCount - Start) . " ms`n`n" resultedFilesList[10])
}


ActSortName() {
   cleanFilesList(2)
}

ActSortSize() {
   If (SLDtypeLoaded=3)
      dbSortingCached("fsize")
   Else
      SortFilesList("size")
}

ActSortPath() {
   If (SLDtypeLoaded=3)
      dbSortingCached("imgfolder")
   Else
      SortFilesList("name-folder")
}

ActSortFileName() {
   If (SLDtypeLoaded=3)
      dbSortingCached("imgfile")
   Else
      SortFilesList("name-file")
}

ActSortModified() {
   If (SLDtypeLoaded=3)
      dbSortingCached("fmodified")
   Else
      SortFilesList("modified")
}

ActSortCreated() {
   If (SLDtypeLoaded=3)
      dbSortingCached("fcreated")
   Else
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
   msgResult := msgBoxWrapper(appTitle ": Sort list", "Each file will be read to determine its luminance histogram average value.`n`nAre you sure you want to sort the list in this mode? It can take a lot of time...", 4, 0, "question")
   If (msgResult="yes")
      SortFilesList("histogramAvg")
}

ActSortHistogramMedian() {
   msgResult := msgBoxWrapper(appTitle ": Sort list", "Each file will be read to determine its luminance histogram median value.`n`nAre you sure you want to sort the list in this mode? It can take a lot of time...", 4, 0, "question")
   If (msgResult="yes")
      SortFilesList("histogramMedian")
}

ActSortSimilarity() {
   msgResult := msgBoxWrapper(appTitle ": Sort list", "This operation can take *A LOT* of time, because each image will be compared with the currently selected one.`n`nAre you sure you want to sort the list in this way?", 4, 0, "question")
   If (msgResult="yes")
      SortFilesList("similarity")
}

SortFilesList(SortCriterion) {
   Critical, on
   If AnyWindowOpen
      CloseWindow()

   If (maxFilesIndex>1)
   {
      filesToBeSorted := maxFilesIndex
      If StrLen(filesFilter)>1
      {
         msgResult := msgBoxWrapper(appTitle ": Sort operation", "The files list is filtered down to " maxFilesIndex " files from " bkcpMaxFilesIndex ".`n`nOnly the files matched by current filter will be sorted, not all the files.`n`nTo sort all files, remove the filter by pressing Ctrl + F.", 1, 0, "info")
         If (msgResult="cancel")
            Return
      }

      filesPerCore := maxFilesIndex//(realSystemCores + 1)
      If (filesPerCore<3 && realSystemCores>1)
      {
         systemCores := maxFilesIndex//3
         filesPerCore := maxFilesIndex//systemCores
      } Else systemCores := realSystemCores + 1

      mustDoMultiCore := (allowMultiCoreMode=1 && systemCores>1 && filesPerCore>3) ? 1 : 0
      previmgPath := getIDimage(currentFileIndex)
      setImageLoading()
      showTOOLtip("Gathering information for " maxFilesIndex " files, please wait...")
      If (SortCriterion="similarity" && mustDoMultiCore!=1)
      {
         img2Compare := getIDimage(currentFileIndex)
         oBitmap := LoadBitmapFromFileu(img2Compare)
         If !oBitmap
         {
            SetTimer, ResetImgLoadStatus, -50
            SoundBeep, 300, 100
            msgBoxWrapper(appTitle ": ERROR", "The selected file seems to not exist or it has an incorrect image file format. Please try again with another file...", 0, 0, "error")
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

      setWindowTitle("Sorting files list, please wait", 1)
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      markedSelectFile := 0

      If StrLen(filesFilter)>1
      {
         filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
         showTOOLtip("Preparing the files list, please wait...")
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
         Sleep, 10
         RemoveTooltip()
      }

      prevMSGdisplay := A_TickCount
      startOperation := A_TickCount
      If (mustDoMultiCore=1 && (SortCriterion="similarity" || InStr(SortCriterion, "histogram")))
      {
         createThumbsFolder()
         setPriorityThread(-2)
         multifilesListu := WorkLoadMultiCoresSortHisto(resultedFilesList, maxFilesIndex, SortCriterion, filterBehaviour, backfilesFilter, countTFilez, multinotSortedFilesListu)
         setPriorityThread(0)
         wasMultiThreaded := 1
         If (multifilesListu="abandoned")
            abandonAll := 1
         Else If (multifilesListu="error" || !multifilesListu)
            errorOccured := abandonAll := 1
         Else If (multifilesListu="single-core")
            wasMultiThreaded := multifilesListu := multinotSortedFilesListu := ""
      }

      sortPages := sortedFiles := 0
      unSortPages := unSortedFiles := 0
      If (wasMultiThreaded!=1)
      {
         countTFilez := 0
         doStartLongOpDance()
         Loop, % maxFilesIndex + 1
         {
             r := getIDimage(A_Index)
             If (InStr(r, "||") || !r)
                Continue
 
             changeMcursor()
             If StrLen(backfilesFilter)>1
             {
                z := filterCoreString(r, filterBehaviour, backfilesFilter)
                If (z=1)
                {
                   unSortedFiles++
                   notSortedFilesListu%unSortPages% .= r "`n"
                   If (unSortedFiles>12500)
                   {
                      unSortedFiles := 0
                      unSortPages++
                   }
                   Continue
                }
             }
 
             countTFilez++
             If (A_TickCount - prevMSGdisplay>3000)
             {
                zeitOperation := A_TickCount - startOperation
                percDone := " ( " Round((countTFilez / filesToBeSorted) * 100) "% )"
                percLeft := (1 - countTFilez / filesToBeSorted) * 100
                zeitLeft := (zeitOperation/countTFilez) * filesToBeSorted - zeitOperation
                etaTime := "`nEstimated time left: " SecToHHMMSS(Round(zeitLeft/1000, 3))
                etaTime .= "`nElapsed time: " SecToHHMMSS(Round(zeitOperation/1000, 3)) percDone
                If (failedFiles>0)
                   etaTime .= "`nOn " failedFiles " files encountered failure..."
 
                showTOOLtip("Gathering information for " countTFilez "/" filesToBeSorted " files, please wait..." etaTime)
                prevMSGdisplay := A_TickCount
             }
 
             If !InStr(SortCriterion, "name-")
             {
                If !FileRexists(r)
                {
                   failedFiles++
                   Continue
                }
             }
  
             If (SortCriterion="size")
             {
                FileGetSize, SortBy, %r%
             } Else If (SortCriterion="modified")
             {
                FileGetTime, SortBy, %r%, M
             } Else If (SortCriterion="created")
             {
                FileGetTime, SortBy, %r%, C
             } Else If (SortCriterion="name-folder")
             {
                zPlitPath(r, 1, OutFileName, OutDir)
                SortBy := OutDir
             } Else If (SortCriterion="name-file")
             {
                zPlitPath(r, 1, OutFileName, OutDir)
                SortBy := OutFileName
             } Else If InStr(SortCriterion, "image-")
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
                      xBitmap := Gdip_ResizeBitmap(oBitmap, rImgW, rImgH, 0, 3)
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
                   xBitmap := Gdip_ResizeBitmap(oBitmap, 300, 300, 1, 3)
                   SortBy := calcHistoAvgFile(xBitmap, SortCriterion, 3)
                   xBitmap := Gdip_DisposeImage(xBitmap, 1)
                   oBitmap := Gdip_DisposeImage(oBitmap, 1)
                } Else SortBy := 0
             }

             executingCanceableOperation := A_TickCount
             If (determineTerminateOperation()=1)
             {
                abandonAll := 1
                Break
             }
 
             If StrLen(SortBy)>1
             {
                sortedFiles++
                filesListu%sortPages% .= SortBy "|!\!|" r "`n"
                If (sortedFiles>12500)
                {
                   sortedFiles := 0
                   sortPages++
                }
             } Else failedFiles++
         }
      }

      If (SortCriterion="similarity")
      {
         Gdip_DisposeImage(zBitmap, 1)
         Gdip_DisposeImage(gBitmap, 1)
      }

      If (abandonAll=1)
      {
         If errorOccured
            msgInfos := "`nErrors occured. Multi-threading error."
         showTOOLtip("Operation aborted. Files list unchanged. " msgInfos)
         SetTimer, RemoveTooltip, % -msgDisplayTime
         CurrentSLD := backCurrentSLD
         lastLongOperationAbort := A_TickCount
         SetTimer, ResetImgLoadStatus, -50
         SoundBeep, 900, 100
         RandomPicture()
         Return
      }

      showTOOLtip("Preparing gathered data...`n" unSortPages " / " sortPages)
      prevMSGdisplay := A_TickCount
      changeMcursor()
      Loop, % sortPages + 1
      {
         thisIndex := A_Index - 1
         entireString .= filesListu%thisIndex%
      }

      Loop, % unSortPages + 1
      {
         thisIndex := A_Index - 1
         entireNotSortedString .= notSortedFilesListu%thisIndex%
      }

      If (wasMultiThreaded=1 && multifilesListu)
      {
         entireString := multifilesListu
         entireNotSortedString := multinotSortedFilesListu
      }

      showTOOLtip("Sorting gathered data...")
      If InStr(SortCriterion, "name-")
         Sort, entireString, D`n
      Else
         Sort, entireString, N D`n

      If (A_TickCount - prevMSGdisplay>1500)
         showTOOLtip("Generating sorted files list index...")

      renewCurrentFilesList()
      Loop, Parse, entireString,`n,`r
      {
          If StrLen(A_LoopField)<2
             Continue

          changeMcursor()
          line := StrSplit(A_LoopField, "|!\!|")
          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := [line[2]]
      }

      Loop, Parse, entireNotSortedString,`n
      {
          If StrLen(A_LoopField)<2
             Continue

          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := [A_LoopField]
      }

      ForceRefreshNowThumbsList()
      If StrLen(backfilesFilter)>1
      {
         bckpResultedFilesList := []
         bckpResultedFilesList := resultedFilesList.Clone()
         bkcpMaxFilesIndex := maxFilesIndex
         usrFilesFilteru := backusrFilesFilteru
         filesFilter := backfilesFilter
         FilterFilesIndex()
      } Else GenerateRandyList()

      entireString := entireNotSortedString := ""
      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, 900, 100
      Sleep, 5
      SetTimer, RemoveTooltip, -500
      CurrentSLD := backCurrentSLD
      currentFileIndex := detectFileID(prevImgPath)
      If (maxFilesIndex<1)
         resetMainWin2Welcome()
      Else
         IDshowImage(currentFileIndex)
   }
}

getSelectedFilesListString(maxList, ByRef countTFilez, ByRef filesListu) {
  trenchSize := maxList//systemCores
  countTFilez := 0
  filesListu := []
  selectedFilesArray := []
  showTOOLtip("Preparing workload for multi-threaded processing...")

  Loop, % maxFilesIndex
  {
      isSelected := resultedFilesList[A_Index, 2]
      If !isSelected
         Continue

      r := resultedFilesList[A_Index, 1]
      If (InStr(r, "||") || !r)
         Continue

      countTFilez++
      selectedFilesArray[countTFilez] := A_Index "?" r "`n"
  }

  maxList := selectedFilesArray.Length()
  trenchSize := maxList//systemCores
  r := 0
  Loop, % systemCores - 1
  {
      thisIndex := A_Index
      Loop, % trenchSize
      {
          realIndex := trenchSize*(thisIndex-1) + A_Index
          line := selectedFilesArray[realIndex]
          If !line
             Continue

          filesListu[thisIndex] .= line
      }
  }

  Loop, % maxList - trenchSize*(systemCores-1)
  {
      realIndex := trenchSize*(systemCores-1) + A_Index
      line := selectedFilesArray[realIndex]
      If !line
         Continue

      filesListu[systemCores] .= line
  }
}

WorkLoadMultiCoresJpegLL(maxList) {
  startOperation := A_TickCount
  backCurrentSLD := CurrentSLD
  CurrentSLD := ""

  prevMSGdisplay := A_TickCount
  getSelectedFilesListString(maxList, countTFilez, filesListu)
  If StrLen(filesListu[1])<3
  {
     CurrentSLD := backCurrentSLD
     Return "single-core"
  }

  RegWrite, REG_SZ, %QPVregEntry%\multicore, mustAbortAllOperations, 0
  RegWrite, REG_SZ, %QPVregEntry%\multicore, mainThreadHwnd, % PVhwnd
  RegWrite, REG_SZ, %QPVregEntry%, Running, 2
  Loop, % systemCores
  {
      thisList := filesListu%A_Index%
      argsToGive := "batch-jpegll||" jpegDesiredOperation "=" jpegDoCrop "=" relativeImgSelCoords "=" imgSelX1 "=" imgSelX2 "=" imgSelY1 "=" imgSelY2 "=" prcSelX1 "=" prcSelX2 "=" prcSelY1 "=" prcSelY2
      pidThread%A_Index% := OpenNewExternalCoreThread(A_Index, argsToGive, thisList)
      If !pidThread%A_Index%
      {
         fatalError := 1
         Break
      }
      Sleep, 1
  }

  RegWrite, REG_SZ, %QPVregEntry%, Running, 1
  If (fatalError=1)
  {
     CurrentSLD := backCurrentSLD
     Return "single-core"
  }

  Sleep, 500
  thisZeit := A_TickCount
  doStartLongOpDance()
  Loop
  {
      Loop, % systemCores
      {
         thisPIDdead := 0
         InitCheckReg := 1
         RegRead, InitCheckReg, %QPVregEntry%\multicore, ThreadRunning%A_Index%
         thisPIDcheck := pidThread%A_Index%
         Process, Exist, % thisPIDcheck
         thisPIDdead := ((!ErrorLevel && thisPIDcheck) && (A_TickCount - thisZeit > 2500)) || !thisPIDcheck ? 1 : 0
         If (InitCheckReg=1 && thisPIDdead!=1)
            jobsRunning++
         Else If (InitCheckReg=2)
            jobDone++
         Else ; If (thisPIDdead=1)
            threadsCrashed++
      }

      If (threadsCrashed>systemCores//2)
      {
         fatalError := abandonAll := 1
         Break
      }

      If (jobDone>systemCores-1)
      {
         Break
      } Else
      {
         Sleep, 300
         processedFiles := failedFiles := 0
         executingCanceableOperation := A_TickCount
         If (A_TickCount - prevMSGdisplay>2000)
         {
            Loop, % systemCores
            {
               InitCheckReg := 1
               RegRead, filesStatus, %QPVregEntry%\multicore, ThreadJob%A_Index%
               filesStatusArr := StrSplit(filesStatus, "/")
               If (filesStatusArr[1]>0)
                  processedFiles += filesStatusArr[1]
               If (filesStatusArr[2]>0)
                  failedFiles += filesStatusArr[2]
            }

            zeitOperation := A_TickCount - startOperation
            percDone := " ( " Round((processedFiles / countTFilez) * 100) "% )"
            percLeft := (1 - processedFiles / countTFilez) * 100
            zeitLeft := (zeitOperation/processedFiles) * countTFilez - zeitOperation
            etaTime := "`nEstimated time left: " SecToHHMMSS(Round(zeitLeft/1000, 3))
            etaTime .= "`nElapsed time: " SecToHHMMSS(Round(zeitOperation/1000, 3)) percDone
            etaTime .= "`nUsing " jobsRunning " / " systemCores " execution threads"
            If (threadsCrashed>0)
               etaTime .= "`n" threadsCrashed " threads have crashed..."
            If (failedFiles>0)
               etaTime .= "`n" failedFiles " files encountered failure..."
  
            showTOOLtip("Performing JPEG lossless operations on "  processedFiles "/" countTFilez " files, please wait..." etaTime)
            prevMSGdisplay := A_TickCount
         }
      }

      executingCanceableOperation := A_TickCount
      If (determineTerminateOperation()=1)
      {
         RegWrite, REG_SZ, %QPVregEntry%\multicore, mustAbortAllOperations, 1
         abandonAll := 1
         fatalError := 0
         lastLongOperationAbort := A_TickCount
         Break
      }
      jobDone := threadsCrashed := jobsRunning := 0
  }

  Loop, % systemCores
  {
      RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%A_Index%, 0
      Try FileDelete, %thumbsCacheFolder%\tempList%A_Index%.txt
  }

   processedFiles := failedFiles := 0
   Loop, % systemCores
   {
      InitCheckReg := 1
      RegRead, filesStatus, %QPVregEntry%\multicore, ThreadJob%A_Index%
      filesStatusArr := StrSplit(filesStatus, "/")
      If (filesStatusArr[1]>0)
         processedFiles += filesStatusArr[1]
      If (filesStatusArr[2]>0)
         failedFiles += filesStatusArr[2]
   }

  If (failedFiles>0)
     someErrors := "`n" failedFiles " files encountered failure..."

  If (fatalError=1)
  {
     RemoveTooltip()
     SoundBeep, 300, 100
     r := "error"
     msgBoxWrapper(appTitle ": ERROR", "Most execution threads have crashed. JPEG lossless processing aborted... `n`nPlease try again with multi-threading disabled.`n`n" processedFiles " out of " countFilez " selected files were processed until now..." someErrors, 0, 0, "error")
  }

  ForceRefreshNowThumbsList()
  dummyTimerDelayiedImageDisplay(100)
  If (abandonAll=1 && fatalError!=1)
     showTOOLtip("Operation aborted. " processedFiles " out of " countFilez " selected files were processed until now..." someErrors)
  Else If (fatalError!=1)
     showTOOLtip(processedFiles " out of " countTFilez " selected JPEG files were processed" someErrors)

  If (fatalError!=1)
     SoundBeep, % (abandonAll=1) ? 300 : 900, 100

  SetTimer, ResetImgLoadStatus, -50
  SetTimer, RemoveTooltip, % -msgDisplayTime*1.5
  If (abandonAll=1 && fatalError!=1)
     r := "abandoned"

  CurrentSLD := backCurrentSLD
  Return r
}

WorkLoadMultiCoresConvertFormat(maxList) {
  startOperation := A_TickCount
  prevMSGdisplay := A_TickCount
  backCurrentSLD := CurrentSLD
  CurrentSLD := ""
  skippedFiles := theseFailures := failedFiles := 0
  getSelectedFilesListString(maxList, countTFilez, filesListu)
  If StrLen(filesListu[1])<3
  {
     CurrentSLD := backCurrentSLD
     Return "single-core"
  }

  RegWrite, REG_SZ, %QPVregEntry%\multicore, mustAbortAllOperations, 0
  RegWrite, REG_SZ, %QPVregEntry%\multicore, mainWindowID, % hGDIwin
  RegWrite, REG_SZ, %QPVregEntry%\multicore, mainThreadHwnd, % PVhwnd
  RegWrite, REG_SZ, %QPVregEntry%, Running, 2
  Loop, % systemCores
  {
      thisList := filesListu[A_Index]
      argsToGive := "batch-fmtconv"
      pidThread%A_Index% := OpenNewExternalCoreThread(A_Index, argsToGive, thisList)
      If !pidThread%A_Index%
      {
         fatalError := 1
         Break
      }
      Sleep, 1
  }

  RegWrite, REG_SZ, %QPVregEntry%, Running, 1
  If (fatalError=1)
  {
     CurrentSLD := backCurrentSLD
     Return "single-core"
  }

  Sleep, 500
  thisZeit := A_TickCount
  doStartLongOpDance()
  Loop
  {
      Loop, % systemCores
      {
         thisPIDdead := 0
         InitCheckReg := 1
         RegRead, InitCheckReg, %QPVregEntry%\multicore, ThreadRunning%A_Index%
         thisPIDcheck := pidThread%A_Index%
         Process, Exist, % thisPIDcheck
         thisPIDdead := ((!ErrorLevel && thisPIDcheck) && (A_TickCount - thisZeit > 2500)) || !thisPIDcheck ? 1 : 0
         If (InitCheckReg=1 && thisPIDdead!=1)
            jobsRunning++
         Else If (InitCheckReg=2)
            jobDone++
         Else ; If (thisPIDdead=1)
            threadsCrashed++
      }

      If (threadsCrashed>systemCores//2)
      {
         fatalError := abandonAll := 1
         Break
      }

      If (jobDone>systemCores-1)
      {
         Break
      } Else
      {
         Sleep, 100
         processedFiles := skippedFiles := failedFiles := theseFailures := 0
         executingCanceableOperation := A_TickCount
         If (A_TickCount - prevMSGdisplay>2000)
         {
            Loop, % systemCores
            {
               InitCheckReg := 1
               RegRead, filesStatus, %QPVregEntry%\multicore, ThreadJob%A_Index%
               filesStatusArr := StrSplit(filesStatus, "/")
               If (filesStatusArr[1]>0)
                  processedFiles += filesStatusArr[1]
               If (filesStatusArr[2]>0)
                  failedFiles += filesStatusArr[2]
               If (filesStatusArr[3]>0)
                  theseFailures += filesStatusArr[3]
               If (filesStatusArr[4]>0)
                  skippedFiles += filesStatusArr[4]
            }

            zeitOperation := A_TickCount - startOperation
            percDone := " ( " Round((processedFiles / countTFilez) * 100) "% )"
            percLeft := (1 - processedFiles / countTFilez) * 100
            zeitLeft := (zeitOperation/processedFiles) * countTFilez - zeitOperation
            etaTime := "`nEstimated time left: " SecToHHMMSS(Round(zeitLeft/1000, 3))
            etaTime .= "`nElapsed time: " SecToHHMMSS(Round(zeitOperation/1000, 3)) percDone

            etaTime .= "`nUsing " jobsRunning " / " systemCores " execution threads"
            If (threadsCrashed>0)
               etaTime .= "`n" threadsCrashed " threads have crashed..."
            If (failedFiles>0)
               etaTime .= "`nFor " failedFiles " files, the format conversion failed..."
            If (theseFailures>0)
               etaTime .= "`nUnable to remove " theseFailures " original files after format conversion..."
            If (skippedFiles>0)
               etaTime .= "`n" skippedFiles " files were skipped..."

            showTOOLtip("Converting to ." rDesireWriteFMT A_Space processedFiles "/" countTFilez " files, please wait..." etaTime)
            prevMSGdisplay := A_TickCount
         }
      }

      executingCanceableOperation := A_TickCount
      If (determineTerminateOperation()=1)
      {
         RegWrite, REG_SZ, %QPVregEntry%\multicore, mustAbortAllOperations, 1
         abandonAll := 1
         fatalError := 0
         lastLongOperationAbort := A_TickCount
         Break
      }
      jobDone := threadsCrashed := jobsRunning := 0
  }

  thisZeit := A_TickCount
  Loop
  {
      Loop, % systemCores
      {
         InitCheckReg := 1
         RegRead, InitCheckReg, %QPVregEntry%\multicore, ThreadRunning%A_Index%
         thisPIDcheck := pidThread%A_Index%
         Process, Exist, % thisPIDcheck
         thisPIDdead := ((!ErrorLevel && thisPIDcheck) && (A_TickCount - thisZeit > 2500)) || !thisPIDcheck ? 1 : 0
         If (InitCheckReg=2 || thisPIDdead=1)
            jobDone++
      }
      If (jobDone>systemCores-1) || (A_TickCount - thisZeit > 12500)
         Break

      jobDone := 0
  }

  processedFiles := failedFiles := theseFailures := 0
  Loop, % systemCores
  {
     RegRead, filesStatus, %QPVregEntry%\multicore, ThreadJob%A_Index%
     filesStatusArr := StrSplit(filesStatus, "/")
     If (filesStatusArr[1]>0)
        processedFiles += filesStatusArr[1]
     If (filesStatusArr[2]>0)
        failedFiles += filesStatusArr[2]
     If (filesStatusArr[3]>0)
        theseFailures += filesStatusArr[3]
  }

  Loop, % systemCores
  {
        RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%A_Index%, 0
        If (fatalError!=1)
           Try FileRead, results, %thumbsCacheFolder%\tempList%A_Index%.txt
        theFinalList .= results
        Sleep, 0
        Try FileDelete, %thumbsCacheFolder%\tempList%A_Index%.txt
  }

  Loop, Parse, theFinalList,`n,`r
  {
       If StrLen(A_LoopField)>2
       {
          lineArr := StrSplit(A_LoopField, "?")
          thisIndex := lineArr[1]
          imgPath := lineArr[2]
          If (imgPath && thisIndex)
             resultedFilesList[thisIndex, 1] := imgPath
       }
  }

  If (failedFiles>0)
     someErrors .= "`nFor " failedFiles " files, the format conversion failed..."
  If (theseFailures>0)
     someErrors .= "`nUnable to remove " theseFailures " original files after format conversion..."
  If (skippedFiles>0)
     someErrors .= "`n" skippedFiles " files were skipped..."

  If (fatalError=1)
  {
     SoundBeep, 300, 100
     r := "error"
     RemoveTooltip()
     msgBoxWrapper(appTitle ": ERROR", "Most execution threads have crashed. JPEG lossless processing aborted... `n`nPlease try again with multi-threading disabled.`n`n" processedFiles " out of " countFilez " selected files were processed until now..." someErrors, 0, 0, "error")
  }

  ForceRefreshNowThumbsList()
  dummyTimerDelayiedImageDisplay(100)
  If (abandonAll=1 && fatalError!=1)
     showTOOLtip("Operation aborted. " processedFiles " out of " countFilez " selected files were converted to ." rDesireWriteFMT " until now..." someErrors)
  Else If (fatalError!=1)
     showTOOLtip(processedFiles " out of " countTFilez " selected files were converted to ." rDesireWriteFMT someErrors)

  If (fatalError!=1)
     SoundBeep, % (abandonAll=1) ? 300 : 900, 100

  SetTimer, ResetImgLoadStatus, -50
  SetTimer, RemoveTooltip, % -msgDisplayTime*1.5
  If (abandonAll=1 && fatalError!=1)
     r := "abandoned"

  CurrentSLD := backCurrentSLD
  Return r
}

WorkLoadMultiCoresSortHisto(whichArray, maxList, SortCriterion, filterBehaviour, backfilesFilter, ByRef countTFilez, ByRef notSortedFilesListu) {
  trenchSize := maxList//systemCores
  countTFilez := 0
  startOperation := A_TickCount
  prevMSGdisplay := A_TickCount

  showTOOLtip("Preparing workload for sorting the files list...")
  Loop, % systemCores - 1
  {
      thisIndex := A_Index
      Loop, % trenchSize
      {
          rA := whichArray[trenchSize*(thisIndex-1) + A_Index]
          r := rA[1]
          If (InStr(r, "||") || !r)
             Continue

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
          filesListu%thisIndex% .= r "`n"
      }
  }

  Loop, % maxList - trenchSize*(systemCores - 1)
  {
      rA := whichArray[trenchSize*(systemCores - 1) + A_Index]
      r := rA[1]
      If (InStr(r, "||") || !r)
         Continue

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
      filesListu%systemCores% .= r "`n"
  }

  If (SortCriterion="similarity")
  {
     img2Compare := getIDimage(currentFileIndex)
     RegWrite, REG_SZ, %QPVregEntry%\multicore, img2Compare, % img2Compare
  }

  RegWrite, REG_SZ, %QPVregEntry%\multicore, mustAbortAllOperations, 0
  RegWrite, REG_SZ, %QPVregEntry%\multicore, mainThreadHwnd, % PVhwnd
  RegWrite, REG_SZ, %QPVregEntry%, Running, 2
  Loop, % systemCores
  {
      thisList := filesListu%A_Index%
      argsToGive := "batch-sort-histo||" SortCriterion
      pidThread%A_Index% := OpenNewExternalCoreThread(A_Index, argsToGive, thisList)
      If !pidThread%A_Index%
      {
         fatalError := 1
         Break
      }
      Sleep, 1
  }

  RegWrite, REG_SZ, %QPVregEntry%, Running, 1
  If (fatalError=1)
     Return (SortCriterion="similarity") ? "error" : "single-core"

  Sleep, 500
  thisZeit := A_TickCount
  doStartLongOpDance()
  Loop
  {
      Loop, % systemCores
      {
         thisPIDdead := 0
         InitCheckReg := 1
         RegRead, InitCheckReg, %QPVregEntry%\multicore, ThreadRunning%A_Index%
         thisPIDcheck := pidThread%A_Index%
         Process, Exist, % thisPIDcheck
         thisPIDdead := ((!ErrorLevel && thisPIDcheck) && (A_TickCount - thisZeit > 2500)) || !thisPIDcheck ? 1 : 0
         If (InitCheckReg=1 && thisPIDdead!=1)
            jobsRunning++
         Else If (InitCheckReg=2)
            jobDone++
         Else ; If (thisPIDdead=1)
            threadsCrashed++
      }

      If (threadsCrashed>systemCores//2)
      {
         fatalError := abandonAll := 1
         Break
      }

      If (jobDone>systemCores-1)
      {
         Break
      } Else
      {
         Sleep, 300
         processedFiles := 0
         executingCanceableOperation := A_TickCount
         If (A_TickCount - prevMSGdisplay>3000)
         {
            Loop, % systemCores
            {
               InitCheckReg := 1
               RegRead, filesStatus, %QPVregEntry%\multicore, ThreadJob%A_Index%
               filesStatusArr := StrSplit(filesStatus, "/")
               If (filesStatusArr[1]>0)
                  processedFiles += filesStatusArr[1]
               If (filesStatusArr[2]>0)
                  failedFiles += filesStatusArr[2]
            }

            zeitOperation := A_TickCount - startOperation
            percDone := " ( " Round((processedFiles / countTFilez) * 100) "% )"
            percLeft := (1 - processedFiles / countTFilez) * 100
            zeitLeft := (zeitOperation/processedFiles) * countTFilez - zeitOperation
            etaTime := "`nEstimated time left: " SecToHHMMSS(Round(zeitLeft/1000, 3))
            etaTime .= "`nElapsed time: " SecToHHMMSS(Round(zeitOperation/1000, 3)) percDone
            If (failedFiles>0)
               etaTime .= "`nOn " failedFiles " files encountered failure..."
            etaTime .= "`nUsing " jobsRunning " / " systemCores " execution threads"
            If threadsCrashed
               etaTime .= "`n" threadsCrashed " threads have crashed..."
  
            showTOOLtip("Gathering information for "  processedFiles "/" countTFilez " files, please wait..." etaTime)
            prevMSGdisplay := A_TickCount
         }
      }

      executingCanceableOperation := A_TickCount
      If (determineTerminateOperation()=1)
      {
         RegWrite, REG_SZ, %QPVregEntry%\multicore, mustAbortAllOperations, 1
         abandonAll := 1
         fatalError := 0
         lastLongOperationAbort := A_TickCount
         Break
      }
      jobDone := threadsCrashed := jobsRunning := 0
  }

  Loop, % systemCores
  {
        RegRead, InitCheckReg, %QPVregEntry%\multicore, ThreadRunning%A_Index%
        RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%A_Index%, 0
        If (abandonAll!=1 && InitCheckReg=2 && fatalError!=1)
           Try FileRead, results, %thumbsCacheFolder%\tempList%A_Index%.txt
        theFinalList .= results
        Sleep, 0
        Try FileDelete, %thumbsCacheFolder%\tempList%A_Index%.txt
  }

  SetTimer, ResetImgLoadStatus, -50
  If (fatalError=1)
  {
     RemoveTooltip()
     SoundBeep, 300, 100
     r := (SortCriterion="similarity") ? "error" : "single-core"
     If (r="error")
        msgBoxWrapper(appTitle ": ERROR", "Most execution threads have crashed. List sorting aborted...", 0, 0, "error")
     Return r
  }

  If (abandonAll=1 && fatalError!=1)
     theFinalList := "abandoned"

  Return theFinalList
}

multiCoresListSorter(coreThread, SortCriterion, filesList) {
  resultsList := ""
  failedFiles := countFilez := operationDone := 0
  ; thisPID := DllCall("GetCurrentProcessId")
  ; RegWrite, REG_SZ, %QPVregEntry%, pidThread%coreThread%, % thisPID
  ; MsgBox, % SortCriterion " -- " coreThread "`n" filesList
  RegRead, img2Compare, %QPVregEntry%\multicore, img2Compare
  If (SortCriterion="similarity" && StrLen(img2Compare)>3 && InStr(img2Compare, ":\"))
  {
     oBitmap := LoadBitmapFromFileu(img2Compare)
     If oBitmap
     {
        Gdip_GetImageDimensions(oBitmap, oImgW, oImgH)
        o_picRatio := Round(oImgW/oImgH, 3)
        zBitmap := Gdip_ResizeBitmap(oBitmap, 250, 250, 1, 7)
        gBitmap := Gdip_BitmapConvertGray(zBitmap)
 
        o_thisHistoAvg := calcHistoAvgFile(zBitmap, "histogram", 3)
        oBitmap := Gdip_DisposeImage(oBitmap, 1)
        Gdip_GetImageDimensions(zBitmap, rImgW, rImgH)
     }
  }

  Loop, Parse, filesList,`n,`r
  {
       If A_LoopField
          r := A_LoopField
       Else
          Continue

       RegRead, mustAbortAllOperations, %QPVregEntry%\multicore, mustAbortAllOperations
       If (!WinExist("ahk_id" mainThreadHwnd) || mustAbortAllOperations=1)
       {
          abandonAll := 1
          Break
       }

       If (SortCriterion="similarity")
       {
          op := GetImgFileDimension(r, Wi, He)
          If (op!=1)
             failedFiles++

          PicRatio := Round(Wi/He, 3)
          If valueBetween(PicRatio, o_picRatio + 0.4, o_picRatio - 0.4)
          {
             thisHistoAvg := 0.001
             oBitmap := LoadBitmapFromFileu(r)
             If oBitmap
             {
                xBitmap := Gdip_ResizeBitmap(oBitmap, rImgW, rImgH, 0, 3)
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
             xBitmap := Gdip_ResizeBitmap(oBitmap, 300, 300, 1, 3)
             SortBy := calcHistoAvgFile(xBitmap, SortCriterion, 3)
             xBitmap := Gdip_DisposeImage(xBitmap, 1)
             oBitmap := Gdip_DisposeImage(oBitmap, 1)
          } Else
          {
             SortBy := 0
             failedFiles++
          }
       }
       If StrLen(SortBy)>1
          resultsList .= SortBy " |!\!|" r "`n"

       countFilez++
       RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadJob%coreThread%, % countFilez "/" failedFiles
   }

   If (SortCriterion="similarity")
   {
      Gdip_DisposeImage(zBitmap, 1)
      Gdip_DisposeImage(gBitmap, 1)
   }

   If (abandonAll!=1)
      Try FileAppend, % resultsList, %thumbsCacheFolder%\tempList%coreThread%.txt, utf-16
   Sleep, 1
   RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%coreThread%, 2
   RegWrite, REG_SZ, %QPVregEntry%\multicore, img2Compare, 0
   operationDone := 1
   ; cleanupThread()
}

multiCoresJpegLL(coreThread, arguments, filesList) {
  resultsList := ""
  argumentsArray := StrSplit(arguments, "=")
  jpegOperation := argumentsArray[1]
  mustCrop := argumentsArray[2]
  relativeImgSelCoords := argumentsArray[3]
  imgSelX1 := argumentsArray[4]
  imgSelX2 := argumentsArray[5]
  imgSelY1 := argumentsArray[6]
  imgSelY2 := argumentsArray[7]
  prcSelX1 := argumentsArray[8]
  prcSelX2 := argumentsArray[9]
  prcSelY1 := argumentsArray[10]
  prcSelY2 := argumentsArray[11]
  failedFiles := countFilez := operationDone := 0
  Loop, Parse, filesList,`n,`r
  {
       If A_LoopField
       {
          lineArr := StrSplit(A_LoopField, "?")
          imgPath := lineArr[2]
          If !imgPath
             Continue
       } Else Continue

       RegRead, mustAbortAllOperations, %QPVregEntry%\multicore, mustAbortAllOperations
       If (!WinExist("ahk_id" mainThreadHwnd) || mustAbortAllOperations=1)
       {
          abandonAll := 1
          Break
       }

       r := coreJpegLossLessAction(imgPath, jpegOperation, mustCrop)
       If !r
          failedFiles++
       Else
          countFilez++

       RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadJob%coreThread%, % countFilez "/" failedFiles
   }
   Sleep, 1
   RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%coreThread%, 2
   operationDone := 1
   ; cleanupThread()
}

ReadSettingsFormatConvert() {
    Static saveImgFormatsList := {1:"bmp", 2:"gif", 3:"hdp", 4:"j2c", 5:"j2k", 6:"jfif", 7:"jng", 8:"jp2", 9:"jpg", 10:"jxr", 11:"png", 12:"ppm", 13:"tga", 14:"tif", 15:"wdp", 16:"webp", 17:"xpm"}
    IniRead, tstOnConvertKeepOriginals, % mainSettingsFile, General, OnConvertKeepOriginals, @
    IniRead, tstuserOverwriteFiles, % mainSettingsFile, General, userOverwriteFiles, @
    IniRead, tstuserDesireWriteFMT, % mainSettingsFile, General, userDesireWriteFMT, @
    IniRead, tstResizeUseDestDir, % mainSettingsFile, General, ResizeUseDestDir, @
    IniRead, tstResizeDestFolder, % mainSettingsFile, General, ResizeDestFolder, @
    If (StrLen(tstResizeDestFolder)>3)
       ResizeDestFolder := tstResizeDestFolder
    If (tstResizeUseDestDir=1 || tstResizeUseDestDir=0)
       ResizeUseDestDir := tstResizeUseDestDir
    If (tstuserDesireWriteFMT!="@")
       userDesireWriteFMT := tstuserDesireWriteFMT
    If (tstOnConvertKeepOriginals=1 || tstOnConvertKeepOriginals=0)
       OnConvertKeepOriginals := tstOnConvertKeepOriginals
    If (tstuserOverwriteFiles=1 || tstuserOverwriteFiles=0)
       userOverwriteFiles := tstuserOverwriteFiles

    rDesireWriteFMT := saveImgFormatsList[userDesireWriteFMT]
}

ReadSettingsImageProcessing() {
    IniRead, tstResizeApplyEffects, % mainSettingsFile, General, ResizeApplyEffects, @
    IniRead, tstResizeCropAfterRotation, % mainSettingsFile, General, ResizeCropAfterRotation, @
    IniRead, tstResizeDestFolder, % mainSettingsFile, General, ResizeDestFolder, @
    IniRead, tstResizeInPercentage, % mainSettingsFile, General, ResizeInPercentage, @
    IniRead, tstResizeKeepAratio, % mainSettingsFile, General, ResizeKeepAratio, @
    IniRead, tstResizeQualityHigh, % mainSettingsFile, General, ResizeQualityHigh, @
    IniRead, tstResizeRotationUser, % mainSettingsFile, General, ResizeRotationUser, @
    IniRead, tstResizeUseDestDir, % mainSettingsFile, General, ResizeUseDestDir, @
    IniRead, tstResizeWithCrop, % mainSettingsFile, General, ResizeWithCrop, @
    IniRead, tstSimpleOperationsFlipV, % mainSettingsFile, General, SimpleOperationsFlipV, @
    IniRead, tstSimpleOperationsFlipH, % mainSettingsFile, General, SimpleOperationsFlipH, @
    IniRead, tstSimpleOperationsDoCrop, % mainSettingsFile, General, SimpleOperationsDoCrop, @
    IniRead, tstSimpleOperationsRotateAngle, % mainSettingsFile, General, SimpleOperationsRotateAngle, @
    IniRead, tstSimpleOperationsScaleImgFactor, % mainSettingsFile, General, SimpleOperationsScaleImgFactor, @
    If (tstResizeCropAfterRotation=1 || tstResizeCropAfterRotation=0)
       ResizeCropAfterRotation := tstResizeCropAfterRotation
    If (StrLen(tstResizeDestFolder)>3)
       ResizeDestFolder := tstResizeDestFolder
    If (tstResizeUseDestDir=1 || tstResizeUseDestDir=0)
       ResizeUseDestDir := tstResizeUseDestDir
    If (tstResizeInPercentage=1 || tstResizeInPercentage=0)
       ResizeInPercentage := tstResizeInPercentage
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
    If (tstSimpleOperationsFlipV=1 || tstSimpleOperationsFlipV=0)
       SimpleOperationsFlipV := tstSimpleOperationsFlipV
    If (tstSimpleOperationsFlipH=1 || tstSimpleOperationsFlipH=0)
       SimpleOperationsFlipH := tstSimpleOperationsFlipH
    If (tstSimpleOperationsDoCrop=1 || tstSimpleOperationsDoCrop=0)
       SimpleOperationsDoCrop := tstSimpleOperationsDoCrop
    If (valueBetween(tstSimpleOperationsRotateAngle, 1, 4) && tstSimpleOperationsRotateAngle!="@")
       SimpleOperationsRotateAngle := tstSimpleOperationsRotateAngle
    If (tstSimpleOperationsScaleImgFactor!="@")
       SimpleOperationsScaleImgFactor := tstSimpleOperationsScaleImgFactor

    cleanResizeUserOptionsVars()
}

multiCoresFormatConvert(coreThread, filesList) {
  resultsList := ""
  failedFiles := theseFailures := countFilez := operationDone := 0
  ; FileRead, filesList, %thumbsCacheFolder%\tempList%coreThread%.txt
  ReadSettingsFormatConvert()
  Loop, Parse, filesList,`n,`r
  {
       If A_LoopField
       {
          lineArr := StrSplit(A_LoopField, "?")
          imgPath := lineArr[2]
          If !imgPath
             Continue
       } Else Continue

       RegRead, mustAbortAllOperations, %QPVregEntry%\multicore, mustAbortAllOperations
       If (!WinExist("ahk_id" mainThreadHwnd) || mustAbortAllOperations=1)
       {
          abandonAll := 1
          Break
       }

      If (RegExMatch(imgPath, "i)(.\.(" rDesireWriteFMT "))$") || InStr(imgPath, "||") || !imgPath)
      {
         skippedFiles++
         Continue
      }

      zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
      destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
      file2save := destImgPath "\" OutNameNoExt "." rDesireWriteFMT
      If (FileExist(file2save) && userOverwriteFiles=0)
      {
         skippedFiles++
         Continue
      } Else If FileExist(file2save)
         FileSetAttrib, -R, %file2save%

      Sleep, 1
      pBitmap := LoadBitmapFromFileu(imgPath)
      If !pBitmap
      {
         failedFiles++
         Continue
      }

      rawFmt := Gdip_GetImageRawFormat(pBitmap)
      If (rawFmt="JPEG")
         RotateBMP2exifOrientation(pBitmap)

      r := Gdip_SaveBitmapToFile(pBitmap, file2save, 90)
      If (r=-2 || r=-1)
         r := SaveFIMfile(file2save, pBitmap)

      Gdip_DisposeImage(pBitmap, 1)
      If r
         failedFiles++
      Else
         countFilez++

      wasSucces := r ? 0 : 1
      If (OnConvertKeepOriginals!=1 && !r)
      {
         FileSetAttrib, -R, %imgPath%
         Sleep, 2
         FileRecycle, %imgPath%
         If ErrorLevel
            theseFailures++

         If (wasSucces=1)
            resultsList .= lineArr[1] "?" file2save "`n"
      }

      RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadJob%coreThread%, % countFilez "/" failedFiles "/" theseFailures "/" skippedFiles
   }

   If resultsList
      Try FileAppend, % resultsList, %thumbsCacheFolder%\tempList%coreThread%.txt, utf-16
   RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%coreThread%, 2
   operationDone := 1
   ; cleanupThread()
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
     IniRead, tstresetImageViewOnChange, %readThisFile%, General, resetImageViewOnChange, @
     IniRead, tstshowImgAnnotations, %readThisFile%, General, showImgAnnotations, @
     IniRead, tstallowGIFsPlayEntirely, %readThisFile%, General, allowGIFsPlayEntirely, @

     If (tstallowGIFsPlayEntirely=1 || tstallowGIFsPlayEntirely=0)
        allowGIFsPlayEntirely := tstallowGIFsPlayEntirely
     If (tstshowImgAnnotations=1 || tstshowImgAnnotations=0)
        showImgAnnotations := tstshowImgAnnotations
     If (tstresetImageViewOnChange=1 || tstresetImageViewOnChange=0)
        resetImageViewOnChange := tstresetImageViewOnChange
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
     If (IsNumber(tstSlideHowMode) && valueBetween(tstSlideHowMode, 1, 3))
        SlideHowMode := Trim(tstSlideHowMode)
     If (IsNumber(tstimageAligned) && valueBetween(tstimageAligned, 1, 9))
        imageAligned := Trim(tstimageAligned)
     If (IsNumber(tstthumbsAratio) && valueBetween(tstthumbsAratio, 1, 3))
        thumbsAratio := Trim(tstthumbsAratio)
     If (IsNumber(tstslideShowDelay) && tstslideShowDelay>90)
        slideShowDelay := Trim(tstslideShowDelay)
     If (IsNumber(tstIMGresizingMode) && valueBetween(tstIMGresizingMode, 1, 4))
        IMGresizingMode := Trim(tstIMGresizingMode)
     If (IsNumber(tstimgFxMode) && valueBetween(tstimgFxMode, 1, 8))
        imgFxMode := Trim(tstimgFxMode)
     If (IsNumber(tstautoAdjustMode) && valueBetween(tstautoAdjustMode, 1, 3))
        autoAdjustMode := Trim(tstautoAdjustMode)

     If (tstWindowBgrColor!="@" && StrLen(tstWindowBgrColor)=6)
     {
        WindowBgrColor := tstWindowBgrColor
        If (scriptInit=1)
           interfaceThread.ahkFunction("updateWindowColor")
     }
     If (tstfilesFilter!="@" && StrLen(Trim(tstfilesFilter))>2)
        usrFilesFilteru := tstfilesFilter

     If isNumber(tstchnRdecalage)
        chnRdecalage := Trim(tstchnRdecalage)
     If isNumber(tstchnGdecalage)
        chnGdecalage := Trim(tstchnGdecalage)
     If isNumber(tstchnBdecalage)
        chnBdecalage := Trim(tstchnBdecalage)
     If isNumber(tstlumosAdjust)
        lumosAdjust := Trim(tstlumosAdjust)
     If isNumber(tstGammosAdjust)
        GammosAdjust := Trim(tstGammosAdjust)
     If isNumber(tstrealGammos) && (realGammos>0)
        realGammos := Trim(tstrealGammos)
     If isNumber(tstimgThreshold)
        imgThreshold := Trim(tstimgThreshold)
     If isNumber(tstsatAdjust)
        satAdjust := Trim(tstsatAdjust)
     If isNumber(tstzatAdjust)
        zatAdjust := Trim(tstzatAdjust)
     If isNumber(tsthueAdjust)
        hueAdjust := Trim(tsthueAdjust)
     If isNumber(tstusrAdaptiveThreshold)
        usrAdaptiveThreshold := Trim(tstusrAdaptiveThreshold)
     If isNumber(tstlumosGrAdjust)
        lumosGrayAdjust := Trim(tstlumosGrAdjust)
     If isNumber(tstGammosGrAdjust)
        GammosGrayAdjust := Trim(tstGammosGrAdjust)
     If isNumber(tstthumbsZoomLevel)
        thumbsZoomLevel := Trim(tstthumbsZoomLevel)

     defineColorDepth()
     recalculateThumbsSizes()
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
    IniWrite, % ResizeDestFolder, % mainSettingsFile, General, ResizeDestFolder
    IniWrite, % userMultiDelChoice, % mainSettingsFile, General, userMultiDelChoice
    IniWrite, % usrAutoCropGenerateSelection, % mainSettingsFile, General, usrAutoCropGenerateSelection
    IniWrite, % usrAutoCropDeviationSnap, % mainSettingsFile, General, usrAutoCropDeviationSnap
    IniWrite, % usrAutoCropDeviationPixels, % mainSettingsFile, General, usrAutoCropDeviationPixels
    IniWrite, % doSlidesTransitions, % mainSettingsFile, General, doSlidesTransitions
    IniWrite, % multilineStatusBar, % mainSettingsFile, General, multilineStatusBar
    IniWrite, % AutoCropAdaptiveMode, % mainSettingsFile, General, AutoCropAdaptiveMode
    IniWrite, % minimizeMemUsage, % mainSettingsFile, General, minimizeMemUsage
    IniWrite, % showSelectionGrid, % mainSettingsFile, General, showSelectionGrid
    IniWrite, % EllipseSelectMode, % mainSettingsFile, General, EllipseSelectMode
    IniWrite, % thumbnailsListMode, % mainSettingsFile, General, thumbnailsListMode
    IniWrite, % thumbsListViewMode, % mainSettingsFile, General, thumbsListViewMode
    IniWrite, % LimitSelectBoundsImg, % mainSettingsFile, General, LimitSelectBoundsImg
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
    ; IniRead, tstrelativeImgSelCoords, % mainSettingsFile, General, relativeImgSelCoords, @
    IniRead, tstshowInfoBoxHUD, % mainSettingsFile, General, showInfoBoxHUD, @
    IniRead, tstshowHistogram, % mainSettingsFile, General, showHistogram, @
    IniRead, tstmediaSNDvolume, % mainSettingsFile, General, mediaSNDvolume, @
    IniRead, tstuserMultiDelChoice, % mainSettingsFile, General, userMultiDelChoice, @
    IniRead, tstusrAutoCropGenerateSelection, % mainSettingsFile, General, usrAutoCropGenerateSelection, @
    IniRead, tstusrAutoCropDeviationSnap, % mainSettingsFile, General, usrAutoCropDeviationSnap, @
    IniRead, tstusrAutoCropDeviationPixels, % mainSettingsFile, General, usrAutoCropDeviationPixels, @
    IniRead, tstdoSlidesTransitions, % mainSettingsFile, General, doSlidesTransitions, @
    IniRead, tstmultilineStatusBar, % mainSettingsFile, General, multilineStatusBar, @
    IniRead, tstAutoCropAdaptiveMode, % mainSettingsFile, General, AutoCropAdaptiveMode, @
    IniRead, tstAutoDownScaleIMGs, % mainSettingsFile, General, AutoDownScaleIMGs, @
    IniRead, tstallowMultiCoreMode, % mainSettingsFile, General, allowMultiCoreMode, @
    IniRead, tstminimizeMemUsage, % mainSettingsFile, General, minimizeMemUsage, @
    IniRead, tstResizeDestFolder, % mainSettingsFile, General, ResizeDestFolder, @
    IniRead, tstmaxUserThreads, % mainSettingsFile, Hidden, maxUserThreads, @
    IniRead, tstmaxMemThumbsCache, % mainSettingsFile, Hidden, maxMemThumbsCache, @
    IniRead, tstshowSelectionGrid, % mainSettingsFile, General, showSelectionGrid, @
    IniRead, tstEllipseSelectMode, % mainSettingsFile, General, EllipseSelectMode, @
    IniRead, tstthumbnailsListMode, % mainSettingsFile, General, thumbnailsListMode, @
    IniRead, tstthumbsListViewMode, % mainSettingsFile, General, thumbsListViewMode, @
    IniRead, tstLimitSelectBoundsImg, % mainSettingsFile, General, LimitSelectBoundsImg, @

    If (tstuserimgQuality=1 || tstuserimgQuality=0)
       userimgQuality := tstuserimgQuality
    imgQuality := (userimgQuality=1) ? 7 : 5

    If (tstthumbnailsListMode=1 || tstthumbnailsListMode=0)
       thumbnailsListMode := tstthumbnailsListMode
    If (tstthumbsListViewMode=1 || tstthumbsListViewMode=2 || tstthumbsListViewMode=3)
       thumbsListViewMode := tstthumbsListViewMode
    If (tstEllipseSelectMode=1 || tstEllipseSelectMode=0)
       EllipseSelectMode := tstEllipseSelectMode
    If (tstshowSelectionGrid=1 || tstshowSelectionGrid=0)
       showSelectionGrid := tstshowSelectionGrid
    If (tstLimitSelectBoundsImg=1 || tstLimitSelectBoundsImg=0)
       LimitSelectBoundsImg := tstLimitSelectBoundsImg
    If (tstallowMultiCoreMode=1 || tstallowMultiCoreMode=0)
       allowMultiCoreMode := tstallowMultiCoreMode
    If (tstminimizeMemUsage=1 || tstminimizeMemUsage=0)
       minimizeMemUsage := tstminimizeMemUsage
    If (tstAutoDownScaleIMGs=1 || tstAutoDownScaleIMGs=0)
       AutoDownScaleIMGs := tstAutoDownScaleIMGs
    If (tstusrTextAlign="Left" || tstusrTextAlign="Right" || tstusrTextAlign="Center")
       usrTextAlign := tstusrTextAlign
    If IsNumber(tstDisplayTimeUser) && tstDisplayTimeUser>0
       DisplayTimeUser := Trim(tstDisplayTimeUser)
    If IsNumber(tstOSDfntSize) && tstOSDfntSize>15
       OSDfntSize := Trim(tstOSDfntSize)
    If IsNumber(tstPasteFntSize) && tstPasteFntSize>15
       PasteFntSize := Trim(tstPasteFntSize)
    If IsNumber(tstmediaSNDvolume) && tstmediaSNDvolume>2
       mediaSNDvolume := Trim(tstmediaSNDvolume)
    If IsNumber(tstmaxMemThumbsCache) && tstmaxMemThumbsCache>10
       maxMemThumbsCache := Trim(tstmaxMemThumbsCache)
    If IsNumber(maxUserThreads) && maxUserThreads>2
       maxUserThreads := Trim(maxUserThreads)
    If (tstAutoCropAdaptiveMode=1 || tstAutoCropAdaptiveMode=0)
       AutoCropAdaptiveMode := tstAutoCropAdaptiveMode
    If (tstFontBolded=1 || tstFontBolded=0)
       FontBolded := tstFontBolded
    If (tstFontItalica=1 || tstFontItalica=0)
       FontItalica := tstFontItalica
    If (tstshowHistogram=1 || tstshowHistogram=0)
       showHistogram := tstshowHistogram
    If (tstmultilineStatusBar=1 || tstmultilineStatusBar=0)
       multilineStatusBar := tstmultilineStatusBar
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
    ; If (tstrelativeImgSelCoords=1 || tstrelativeImgSelCoords=0)
    ;    relativeImgSelCoords := tstrelativeImgSelCoords
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
    calcHUDsize()
    msgDisplayTime := DisplayTimeUser*1000
}

calcHUDsize() {
   imgHUDbaseUnit := (PrefsLargeFonts=1) ? Round(OSDfntSize*2.5) : Round(OSDfntSize*2)
}
writeSlideSettings(file2save) {
    IniWrite, % SLDcacheFilesList, %file2save%, General, SLDcacheFilesList
    IniWrite, % IMGresizingMode, %file2save%, General, IMGresizingMode
    IniWrite, % imgFxMode, %file2save%, General, imgFxMode
    IniWrite, % SlideHowMode, %file2save%, General, SlideHowMode
    IniWrite, % slideShowDelay, %file2save%, General, slideShowDelay
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
    IniWrite, % appVersion, %file2save%, General, appVersion
    IniWrite, % usrTextureBGR, %file2save%, General, usrTextureBGR
    IniWrite, % syncSlideShow2Audios, %file2save%, General, syncSlideShow2Audios
    IniWrite, % autoPlaySNDs, %file2save%, General, autoPlaySNDs
    IniWrite, % borderAroundImage, %file2save%, General, borderAroundImage
    IniWrite, % resetImageViewOnChange, %file2save%, General, resetImageViewOnChange
    IniWrite, % showImgAnnotations, %file2save%, General, showImgAnnotations
    IniWrite, % allowGIFsPlayEntirely, %file2save%, General, allowGIFsPlayEntirely
    throwMSGwriteError()
}

readRecentEntries(forceNewList:=0) {
   Static lastInvoked := 1, historyList

   If (StrLen(forceNewList)>4)
   {
      historyList := forceNewList
      lastInvoked := A_TickCount
      Return
   }

   If (StrLen(historyList)>4 && (A_TickCount - lastInvoked<5500))
   {
      lastInvoked := A_TickCount
      Return historyList
   }

   historyList := ""
   Loop, 15
   {
       IniRead, newEntry, % mainSettingsFile, Recents, E%A_Index%, @
       newEntry := Trim(newEntry)
       If StrLen(newEntry)>4 && !InStr(historyList, newEntry "`n")
          historyList .= newEntry "`n"
   }
   lastInvoked := A_TickCount
   Return historyList
}

RecentFilesManager(dummy:=0,addPrevMoveDest:=0) {
  entry2add := CurrentSLD
  If (addPrevMoveDest=2)
     entry2add := prevFileMovePath

  If StrLen(entry2add)<5
     Return

  historyList := readRecentEntries()
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

  readRecentEntries(newHistoryList)
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
   if (currentFileIndex>maxFilesIndex)
      Random, currentFileIndex, % maxFilesIndex/1.5, % maxFilesIndex

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
   Static firstItem, lastItem

   If (getItem=0 && forceSort=0)
      Return markedSelectFile

   If (getItem=1 && markedSelectFile)
      Return firstItem

   If (getItem="L" && markedSelectFile)
      Return lastItem

   If (forceSort=1 && getItem=0)
   {
      firstItem := lastItem := markedSelectFile := 0
      changeMcursor()
      startZeit := A_TickCount
      Loop, % maxFilesIndex
      {
         If (resultedFilesList[A_Index, 2]=1)
         {
            markedSelectFile++
            lastItem := A_Index
            If !firstItem
               firstItem := A_Index
         }
      }

      If (markedSelectFile=1)
      {
         markedSelectFile := 0
         resultedFilesList[firstItem, 2] := 0
         mainGdipWinThumbsGrid()
      }
      changeMcursor("normal")
      Return markedSelectFile
   }
}

filterToFilesSelection() {
  coreEnableFiltru("||Prev-Files-Selection||")
}

invertFilesSelection(silentMode:=0) {
   markedSelectFile := 0
   Loop, % maxFilesIndex
   {
       sel := resultedFilesList[A_Index, 2]
       resultedFilesList[A_Index, 2] := !sel
       If (!sel=1)
          markedSelectFile++
   }
   If (thumbsDisplaying=1)
      mainGdipWinThumbsGrid()
   Else
      dummyTimerDelayiedImageDisplay(50)

   showTOOLtip("Files selection inverted...`n" markedSelectFile " files are now selected")
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

dropFilesSelection(silentMode:=0) {
   If (!markedSelectFile && silentMode=1)
      Return

   markedSelectFile := 0
   startZeit := A_TickCount
   Loop, % maxFilesIndex
       resultedFilesList[A_Index, 2] := 0

   ; ToolTip, % A_TickCount - startZeit, , , 2
   If (silentMode!=1)
   {
      showTOOLtip("Files selection dropped...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
      If (thumbsDisplaying=1)
         mainGdipWinThumbsGrid()
      Else
         dummyTimerDelayiedImageDisplay(50)
   }
}

MenuMarkThisFileNow() {
   markThisFileNow()
}

markThisFileNow(thisFileIndex:=0) {
  If (currentFileIndex=0  || maxFilesIndex<2 || AnyWindowOpen>0)
     Return

  If !thisFileIndex
     thisFileIndex := currentFileIndex

  osel := resultedFilesList[thisFileIndex, 2]
  sel := osel ? 0 : 1
  resultedFilesList[thisFileIndex, 2] := sel
  sel := (osel && !sel) ? 0 : 1

  If sel
     markedSelectFile++
  Else
     markedSelectFile--

  If (markedSelectFile<0)
     getSelectedFiles(0, 1)
  Else If (thumbsDisplaying=1)
     mainGdipWinThumbsGrid()
  Else
     dummyTimerDelayiedImageDisplay(25)
}

jumpToFilesSelBorderFirst() {
   jumpToFilesSelBorder(-1)
}

jumpToFilesSelBorderLast() {
   jumpToFilesSelBorder(1)
}

jumpToFilesSelBorder(destination) {
  Static prevImgIndex, prevIndexu

  If (slideShowRunning=1)
     ToggleSlideShowu()

  totalCount := getSelectedFiles(0, 1)
  If !totalCount
  {
     RandyIMGnow := currentFileIndex := (destination=-1) ? RandyIMGids[1] : RandyIMGids[maxFilesIndex]
     dummyTimerDelayiedImageDisplay(50)
     Return
  }

  theFirst := getSelectedFiles(1)
  theLast := getSelectedFiles("L")
  currentFileIndex := (destination=-1) ? theFirst : theLast
  FriendlyName := (destination=-1) ? "First" : "Last"
  dummyTimerDelayiedImageDisplay(50)
  showTOOLtip(FriendlyName " selected element index: " currentFileIndex "`n" markedSelectFile " total images selected" )
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

navSelectedFilesNext() {
   navSelectedFiles(1)
}

navSelectedFilesPrev() {
   navSelectedFiles(1)
}

navSelectedFiles(direction) {
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   changeMcursor()

   If !markedSelectFile
   {
      getSelectedFiles(0, 1)
      If !markedSelectFile
      {
         changeMcursor("normal")
         CurrentSLD := backCurrentSLD
         showTOOLtip("No files are currently selected...")
         SetTimer, RemoveTooltip, % -msgDisplayTime
         Return
      }
   }

   startIndex := currentFileIndex
   newIndex := 0
   Loop, % maxFilesIndex
   {
        thisIndex := (direction=-1) ? currentFileIndex - A_Index : currentFileIndex + A_Index
        r := getIDimage(thisIndex)
        isSelected := resultedFilesList[thisIndex, 2]
        If (isSelected!=1 || !r || InStr(r, "||"))
           Continue

        If (skipDeadFiles=1)
        {
           If !FileRexists(r)
           {
              Continue
           } Else
           {
              newIndex := thisIndex
              Break
           }
        } Else
        {
           newIndex := thisIndex
           Break
        }
   }

   CurrentSLD := backCurrentSLD
   changeMcursor("normal")
   If (!newIndex && direction=-1)
   {
      jumpToFilesSelBorderLast()
      Return
   } Else If (!newIndex && direction=1)
   {
      jumpToFilesSelBorderFirst()
      Return
   }

   currentFileIndex := (newIndex) ? newIndex : startIndex
   dummyTimerDelayiedImageDisplay(25)
}

searchNextIndex(direction, inLoop:=0) {
   If !userSearchString
   {
      PanelSearchIndex()
      Return
   }

   showTOOLtip("Searching for...`n" userSearchString)
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   changeMcursor()
   originalIndex := startIndex := currentFileIndex
   If (inLoop=1)
      startIndex := (direction=1) ? 0 : maxFilesIndex

   newIndex := 0
   Loop, % maxFilesIndex
   {
        thisIndex := (direction=-1) ? startIndex - A_Index : startIndex + A_Index
        r := getIDimage(thisIndex)
        ; If !InStr(r, userSearchString)
        If filterCoreString(r, 2, userSearchString)
           Continue

        If (skipDeadFiles=1 && thumbsDisplaying!=1)
        {
           If !FileRexists(r)
           {
              Continue
           } Else
           {
              newIndex := thisIndex
              Break
           }
        } Else
        {
           newIndex := thisIndex
           Break
        }
   }

   changeMcursor("normal")
   CurrentSLD := backCurrentSLD
   If (!newIndex && inLoop!=1)
   {
      searchNextIndex(direction, 1)
      Return
   }

   If (!newIndex && inLoop=1)
   {
      showTOOLtip("No indexed file matched the search criteria:`n" userSearchString)
      SetTimer, RemoveTooltip, % -msgDisplayTime
      SoundBeep , 900, 100
      Return
   }

   SetTimer, RemoveTooltip, % -msgDisplayTime//2
   currentFileIndex := newIndex ? newIndex : originalIndex
   dummyTimerDelayiedImageDisplay(25)
}

MultiFileDeletePanel() {
    Static lastInvoked := 1

    createSettingsGUI(16)
    filesElected := getSelectedFiles(0, 1)
    btnWid := 120
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

    Gui, Add, Button, xs y+15 h30 w%btnWid% gBTNactiveFileDel, &Delete active file only
    Gui, Add, Button, x+5 hp w95 gBTNmultiDel Default, &Proceed
    Gui, Add, Button, x+5 hp wp gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Delete files: %appTitle%
}

BTNactiveFileDel() {
   CloseWindow()
   DeletePicture("single")
   getSelectedFiles(0, 1)
}

BTNmultiDel() {
   CloseWindow()
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

  INIaction(1, "userMultiDelChoice", "General")
  If (userMultiDelChoice=1 || userMultiDelChoice=3)
     GuiControl, SettingsGUIA: Enable, move2recycler
  Else
     GuiControl, SettingsGUIA: Disable, move2recycler
}

multiFileDelete() {
   filesElected := getSelectedFiles(0, 1)
   If (filesElected<2)
   {
      SoundBeep, 300, 100
      Return
   }

   showTOOLtip("Moving to recycle bin " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   destroyGDIfileCache()
   doStartLongOpDance()
   filesRemoved := abandonAll := 0
   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      executingCanceableOperation := A_TickCount
      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }

      countTFilez++
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Moving to recycle bin " filesRemoved "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      thisFileIndex := A_Index
      file2rem := getIDimage(thisFileIndex)
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
         resultedFilesList[thisFileIndex] := ["||" file2rem, 1]
         If StrLen(filesFilter)>1
            bckpResultedFilesList[filteredMap2mainList[thisFileIndex]] := ["||" file2rem, 1]
      } Else someErrors := "`nErrors occured during file operations..."
   }

   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(100)
   SetTimer, ResetImgLoadStatus, -50
   If (abandonAll=1)
   {
      SoundBeep, 300, 100
      showTOOLtip("Operation aborted. " filesRemoved " out of " countTFilez " selected files deleted until now..." someErrors)
   } Else
   {
      SoundBeep, 900, 100
      showTOOLtip(filesRemoved " out of " countTFilez " selected files deleted" someErrors)
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
   Return abandonAll
}

DeletePicture(dummy:=0) {
  getSelectedFiles(0, 1)
  If (markedSelectFile>1 && dummy!="single")
  {
      MultiFileDeletePanel()
      Return
  }

  If (slideShowRunning=1)
     ToggleSlideShowu()

  file2rem := getIDimage(currentFileIndex)
  file2rem := StrReplace(file2rem, "||")
  zPlitPath(file2rem, 0, OutFileName, OutDir)
  If (askDeleteFiles=1 && dummy!="single") || (activateImgSelection=1 && thumbsDisplaying!=1)
  {
     msgTimer := A_TickCount
     msgResult := msgBoxWrapper(appTitle ": Confirmation", "Are you sure you want to delete this image file ?`n`n" OutFileName "`n`n" OutDir "\", 5, 2, "question")
     If (msgResult="Yes")
        good2go := 1

     If (A_TickCount - msgTimer < 550)
     {
        showTOOLtip("Operation aborted. User answered ""Yes"" too fast.")
        SetTimer, RemoveTooltip, % -msgDisplayTime
        good2go := 0
        Return
     }
  } Else good2go := 1

  If (good2go!=1)
  {
     SetTimer, ResetImgLoadStatus, -50
     Return
  }

  Sleep, 2
  DestroyGIFuWin()
  destroyGDIfileCache(0, 1)
  Sleep, 2
  Try FileSetAttrib, -R, %file2rem%
  Sleep, 1
  FileRecycle, %file2rem%
  If ErrorLevel
  {
     If (thumbsDisplaying=1 && !FileExist(file2rem))
     {
        remCurrentEntry(0, 0)
     } Else
     {
        showTOOLtip("File already deleted or access denied...")
        SoundBeep, 300, 100
     }
  } Else
  {
     resultedFilesList[currentFileIndex] := ["||" file2rem]
     If StrLen(filesFilter)>1
        bckpResultedFilesList[filteredMap2mainList[currentFileIndex]] := ["||" file2rem]

     showTOOLtip("File moved to recycle bin...`n" OutFileName "`n" OutDir "\")
  }

  Sleep, 50
  SetTimer, RemoveTooltip, % -msgDisplayTime
  SetTimer, ResetImgLoadStatus, -50
  If (thumbsDisplaying=1)
     mainGdipWinThumbsGrid()
}

readRecentMultiRenameEntries() {
   entriesList := ""
   Loop, 35
   {
       IniRead, newEntry, % mainSettingsFile, RecentMultiRename, E%A_Index%, @
       newEntry := Trim(newEntry)
       If (StrLen(newEntry)>1 && !InStr(entriesList, newEntry "`n"))
          entriesList .= newEntry "`n"
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

    getSelectedFiles(0, 1)
    listu := readRecentMultiRenameEntries()
    overwriteConflictingFile := 0
    Gui, +Delimiter`n
    Gui, Add, Text, x15 y15 w%txtWid%, Selected files: %markedSelectFile%. Type a pattern to rename the files.
    Gui, Add, ComboBox, y+10 w%EditWid% gMultiRenameComboAction r12 Simple vUsrEditNewFileName, % listu
    Gui, Add, Checkbox, y+10 Checked%overwriteConflictingFile% voverwriteConflictingFile, In case of file name collisions, overwrite the other files with these ones

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gcoreMultiRenameFiles, &Rename files
    Gui, Add, Button, x+5 hp w%btnWid% gEraseMultiRenameHisto, Erase &history
    Gui, Add, Button, x+5 hp w85 gMultiRenameHelp, H&elp
    Gui, Add, Button, x+5 hp wp gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Rename multiple files: %appTitle%
}

MultiRenameHelp() {
    msgBoxWrapper(appTitle ": Help", "File extensions remain unchanged regardless of the pattern used.`nFile rename patterns possible:`n`na) Prefix [this] suffix`nThe token [this] is replaced with the file name.`n`nb) Replace string//with this`nUse // or \\ to perform search and replace in file names.`n`nc) any text`nFiles will be counted, to avoid naming conflicts.", 0, 0, 0)
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
     filesElected := getSelectedFiles(0, 1)
     If (filesElected>100)
     {
        msgResult := msgBoxWrapper(appTitle ": Confirmation", "Please confirm you want to rename the selected files.`n`nYou have selected " filesElected " files to be renamed...", 4, 0, "question")
        If (msgResult="Yes")
           good2go := 1
        Else
           Return
     }

     CloseWindow()
     overwriteFiles := overwriteConflictingFile
     showTOOLtip("Renaming " filesElected " files, please wait...`nPattern: " OriginalNewFileName)
     prevMSGdisplay := A_TickCount
     destroyGDIfileCache()
     RecentMultiRenamesManager(OriginalNewFileName)
     filezRenamed := countFilez := 0
     doStartLongOpDance()
     Loop, % maxFilesIndex
     {
         wasError := 0
         isSelected := resultedFilesList[A_Index, 2]
         If (isSelected!=1)
            Continue

         changeMcursor()
         thisFileIndex := A_Index
         file2rem := getIDimage(thisFileIndex)
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
            resultedFilesList[thisFileIndex] := [OutDir "\" newFileName, 1]
            If StrLen(filesFilter)>1
               bckpResultedFilesList[filteredMap2mainList[thisFileIndex]] := [OutDir "\" newFileName, 1]
         }

         If (determineTerminateOperation()=1)
         {
            abandonAll := 1
            Break
         }
     }

     ForceRefreshNowThumbsList()
     dummyTimerDelayiedImageDisplay(100)
     If (abandonAll=1)
        showTOOLtip("Operation aborted. "  filezRenamed " out of " filesElected " selected files were renamed" someErrors)
     Else
        showTOOLtip("Finished renaming "  filezRenamed " out of " filesElected " selected files" someErrors)
     SetTimer, ResetImgLoadStatus, -50
     SoundBeep, % (abandonAll=1) ? 300 : 900, 100
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
  Sleep, 1
  PanelRenameThisFile()
}

PanelOlderThanEraseThumbsCache() {
    createSettingsGUI(11, "PanelOlderThanEraseThumbsCache")
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
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Clean cached thumbnails: %appTitle%
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

PanelUpdateThisFileIndex() {
    Global newFileName
    If (currentFileIndex=0)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    createSettingsGUI(21, "PanelUpdateThisFileIndex")
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

    file2rem := getIDimage(currentFileIndex)
    Gui, Add, Text, x15 y15 w%txtWid%, Please type the new file path and name for index %currentFileIndex% ...
    Gui, Add, Edit, y+7 w%EditWid% r1 limit9925 -multi -wantTab -wrap vnewFileName, % file2rem

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gUpdateIndexBTNaction, &Update index
    Gui, Add, Button, x+5 hp w%btnWid% gBTNremCurrentEntry, &Erase index entry
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Update files list index: %appTitle%
}

BTNremCurrentEntry() {
  CloseWindow()
  Sleep, 1
  remCurrentEntry(currentFileIndex)
}

SingularRenameFile() {
   PanelRenameThisFile("single")
}

PanelRenameThisFile(dummy:=0) {
    Global newFileName
    If (currentFileIndex=0)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    getSelectedFiles(0, 1)
    If (markedSelectFile>1 && dummy!="single")
    {
       batchRenameFiles()
       Return
    }

    Sleep, 2
    file2rem := getIDimage(currentFileIndex)
    zPlitPath(file2rem, 0, OutFileName, OutDir)
    If !FileExist(file2rem)
    {
       showTOOLtip("File does not exist or access denied...`n" OutFileName "`n" OutDir)
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 300, 100
       Return
    }

    createSettingsGUI(7, "PanelRenameThisFile")
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
    Gui, Add, Button, x+5 hp w%btnWid% gInvokeUpdateIndexPanelBTNaction, &Modify index entry
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Rename file: %appTitle%
}

PanelSearchIndex() {
    Global newFileName
    If (currentFileIndex=0)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    createSettingsGUI(29, "PanelSearchIndex")
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

    Gui, Add, Text, x15 y15 w%txtWid%, Please type the text to search for...
    Gui, Add, Edit, y+7 w%EditWid% r1 limit9025 -multi -wantTab -wrap vuserSearchString, % userSearchString

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gSearchIndexBTNaction, &Search next [F3]
    Gui, Add, Button, x+5 hp w%btnWid% gOpenFilterPanelBTNaction, &Filter list panel
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Search indexed files: %appTitle%
}

OpenFilterPanelBTNaction() {
   userSearchString := ""
   CloseWindow()
   PanelEnableFilesFilter()
}

PanelEditImgCaption(dummy:=0) {
    Global newFileName
    If (currentFileIndex=0)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    imgPath := getIDimage(currentFileIndex)
    zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
    If !FileExist(imgPath)
    {
       showTOOLtip("File does not exist or access denied...`n" OutFileName "`n" OutDir)
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 300, 100
       Return
    }

    textFile := OutDir "\" OutNameNoExt ".txt"
    Try FileRead, textFileContent, % textFile

    createSettingsGUI(22, "PanelEditImgCaption")
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

    Gui, Add, Text, x15 y15 w%txtWid%, Please type the caption or annotation you want associated with this image file...
    Gui, Add, Edit, y+7 w%EditWid% r20 limit1024 -wantTab vnewFileName, % textFileContent

    Gui, Add, Button, xs+0 y+20 h30 w90 Default gSaveCaptionBTNaction, &Save
    Gui, Add, Button, x+5 hp wp gDeleteCaptionBTNaction, &Delete
    Gui, Add, Button, x+5 hp wp gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Edit image caption: %appTitle%
}

DeleteCaptionBTNaction() {
    CloseWindow()
    imgPath := getIDimage(currentFileIndex)
    zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
    textFile := OutDir "\" OutNameNoExt ".txt"
    If FileExist(textFile)
       mustShowError := 1

    Try FileDelete, % textFile
    Catch wasError
          Sleep, 2

    If (mustShowError && wasError)
    {
       showTOOLtip("Unable to delete text file:`n" OutNameNoExt ".txt`n" OutDir "\")
       SoundBeep , 300, 100
       SetTimer, RemoveTooltip, % -msgDisplayTime
    }

    If (thumbsDisplaying!=1)
       SetTimer, dummyRefreshImgSelectionWindow, -50
}

SaveCaptionBTNaction() {
    GuiControlGet, newFileName
    newFileName := Trim(newFileName)
    If !newFileName
       Return

    CloseWindow()
    imgPath := getIDimage(currentFileIndex)
    zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
    textFile := OutDir "\" OutNameNoExt ".txt"
    FileDelete, % textFile
    Sleep, 2
    Try FileAppend, % newFileName, % textFile, UTF-16
    Catch wasError
          msgBoxWrapper(appTitle ": ERROR", "Failed to write text file... Permission denied.`n" OutNameNoExt ".txt`n" OutDir "\", 0, 0, "error")

    showImgAnnotations := 1
    If (showImgAnnotations!=1)
       INIaction(1, "showImgAnnotations", "General")

    If (thumbsDisplaying!=1)
       SetTimer, dummyRefreshImgSelectionWindow, -50
}

InvokeUpdateIndexPanelBTNaction() {
   CloseWindow()
   Sleep, 1
   PanelUpdateThisFileIndex()
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

SearchIndexBTNaction() {
  GuiControlGet, userSearchString
  userSearchString := Trim(userSearchString)
  CloseWindow()
  If userSearchString
     searchNextIndex(1)
}

RenameBTNaction() {
  GuiControlGet, newFileName
  GuiControlGet, overwriteConflictingFile

  newFileName := filterFileName(newFileName)
  If (StrLen(newFileName)>2)
  {
     file2rem := getIDimage(currentFileIndex)
     zPlitPath(file2rem, 0, OutFileName, OutDir)
     If (!FileExist(file2rem) || Trim(OutFileName)=newFileName)
        Return

     destroyGDIfileCache(0)
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
        resultedFilesList[currentFileIndex, 1] := OutDir "\" newFileName
        If StrLen(filesFilter)>1
           bckpResultedFilesList[filteredMap2mainList[currentFileIndex]] := [OutDir "\" newFileName]
        dummyTimerDelayiedImageDisplay(50)
     }
  } Else SoundBeep, 300, 100
}

UpdateIndexBTNaction() {
  GuiControlGet, newFileName
  newFileName := Trim(newFileName)
  allGood := 1
  If !RegExMatch(newFileName, "i)^(.\:\\.)")
     allGood := 0

  strArr := StrSplit(newFileName, "\")
  Loop, % strArr.Length()
  {
      testThis := filterFileName(strArr[A_Index])
      If (!testThis && A_Index>1)
         allGood := 0
  }
  If !RegExMatch(newFileName, RegExFilesPattern)
     allGood := 0

  If !FileRexists(newFileName)
     allGood := 0

  If (StrLen(newFileName)>2 && allGood=1)
  {
     CloseWindow()
     resultedFilesList[currentFileIndex, 1] := newFileName
     If StrLen(filesFilter)>1
        bckpResultedFilesList[filteredMap2mainList[currentFileIndex]] := [OutDir "\" newFileName]
     dummyTimerDelayiedImageDisplay(50)
  } Else SoundBeep, 300, 100
}

updateUIpastePanel(actionu:=0) {
    GuiControlGet, PasteInPlaceMode
    GuiControlGet, PasteInPlaceCentered
    GuiControlGet, PasteInPlaceOpacity
    GuiControlGet, PasteInPlaceQuality
    GuiControlGet, PasteInPlaceOrientation
    GuiControlGet, PasteInPlaceIgnoreRotation
    GuiControlGet, PasteInPlaceBlurAmount
    GuiControlGet, PasteInPlaceHue
    GuiControlGet, PasteInPlaceSaturation
    GuiControlGet, PasteInPlaceLight
    GuiControlGet, PasteInPlaceGamma

    If (PasteInPlaceMode=3)
       GuiControl, SettingsGUIA: Disable, PasteInPlaceCentered
    Else
       GuiControl, SettingsGUIA: Enable, PasteInPlaceCentered

    PasteInPlaceAngle := vPselRotation
    thisOpacity := Round((PasteInPlaceOpacity / 255) * 100)
    thisGamma := Round(PasteInPlaceGamma / 100, 2)
    GuiControl, SettingsGUIA:, infoPasteOpacity, Opacity: %thisOpacity%`%
    GuiControl, SettingsGUIA:, infoPasteHue, Hue: %PasteInPlaceHue%°
    GuiControl, SettingsGUIA:, infoPasteSat, Saturation: %PasteInPlaceSaturation%`%
    GuiControl, SettingsGUIA:, infoPasteLight, Brightness: %PasteInPlaceLight%`%
    GuiControl, SettingsGUIA:, infoPasteGamma, Gamma: %thisGamma%
    GuiControl, SettingsGUIA:, infoPasteBlur, Image blur amount: %PasteInPlaceBlurAmount%
    If (actionu!="noPreview")
       SetTimer, corePasteInPlaceActNow, -50
    Else
       SetTimer, WriteSettingsPasteInPlacePanel, -350
}

WriteSettingsPasteInPlacePanel() {
    INIaction(1, "PasteInPlaceMode", "General")
    INIaction(1, "PasteInPlaceCentered", "General")
    INIaction(1, "PasteInPlaceOpacity", "General")
    INIaction(1, "PasteInPlaceQuality", "General")
    INIaction(1, "PasteInPlaceAngle", "General")
    INIaction(1, "PasteInPlaceOrientation", "General")
    INIaction(1, "PasteInPlaceBlurAmount", "General")
    INIaction(1, "PasteInPlaceHue", "General")
    INIaction(1, "PasteInPlaceSaturation", "General")
    INIaction(1, "PasteInPlaceLight", "General")
    INIaction(1, "PasteInPlaceGamma", "General")
}

BtnPasteInSelectedArea() {
    updateUIpastePanel("noPreview")
    Sleep, 1
    CloseWindow()
    activateImgSelection := editingSelectionNow := 1
    Sleep, 1
    viewportStampBMP := Gdip_DisposeImage(viewportStampBMP, 1)
    PasteInPlaceNow()
}

PanelPasteInPlace() {
    calcScreenLimits()
    userClipBMPpaste := Gdip_DisposeImage(userClipBMPpaste, 1)
    If (thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    DestroyGIFuWin()
    changeMcursor()
    showTOOLtip("Retrieving clipboard image, please wait...")
    setImageLoading()
    userClipBMPpaste := corePasteClipboardImg(1, ResolutionWidth*2, Round(ResolutionHeight*4.3))
    If StrLen(userClipBMPpaste)<3
       Return
       
    viewportStampBMP := Gdip_DisposeImage(viewportStampBMP, 1)
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    Gdip_GetImageDimensions(userClipBMPpaste, imgW, imgH)
    If (imgW>mainWidth || imgH>mainHeight)
       viewportStampBMP := Gdip_ResizeBitmap(userClipBMPpaste, mainWidth, mainHeight, 1, 3)
    Else
       viewportStampBMP := Gdip_CloneBitmap(userClipBMPpaste)

    flipBitmapAccordingToViewPort(viewportStampBMP)
    ResetImgLoadStatus()
    imgEditPanelOpened := 1
    interfaceThread.ahkassign("imgEditPanelOpened", 1)
    createSettingsGUI(24, "PanelPasteInPlace")
    INIaction(0, "PasteInPlaceMode", "General")
    INIaction(0, "PasteInPlaceCentered", "General")
    INIaction(0, "PasteInPlaceOpacity", "General")
    INIaction(0, "PasteInPlaceQuality", "General")
    INIaction(0, "PasteInPlaceAngle", "General")
    INIaction(0, "PasteInPlaceOrientation", "General")
    INIaction(0, "PasteInPlaceIgnoreRotation", "General")
    INIaction(0, "PasteInPlaceBlurAmount", "General")
    INIaction(0, "PasteInPlaceHue", "General")
    INIaction(0, "PasteInPlaceSaturation", "General")
    INIaction(0, "PasteInPlaceLight", "General")
    INIaction(0, "PasteInPlaceGamma", "General")
    vPselRotation := Round(PasteInPlaceAngle)
    btnWid := 100
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    If (PasteInPlaceOrientation!=5)
       friendly := " (does not apply)"

    Gdip_GetImageDimensions(gdiBitmap, oImgW, oImgH)
    thisOpacity := Round((PasteInPlaceOpacity / 255) * 100)
    thisGamma := Round(PasteInPlaceGamma / 255, 2)
    Global infoPasteBlur, infoPasteOpacity, infoPasteHue, infoPasteSat, infoPasteLight, infoPasteGamma
    Gui, Add, Tab3,, Main|Adjust colors
    Gui, Tab, 1 ; general
    Gui, Add, Text, x+15 y+15 Section w%txtWid%, Please choose how to paste the clipboard content.
    Gui, Add, Text, y+7 Section w%txtWid%, Canvas: %oImgW% x %oImgH% px.`nClipboard: %imgW% x %imgH% px.
    Gui, Add, DropDownList, xs y+10 wp gupdateUIpastePanel AltSubmit Choose%PasteInPlaceMode% vPasteInPlaceMode, Adjust to selection (only when larger)|Adjust to selection (any size)|Fill selection area entirely (ignore aspect ratio)|Original size (ignore selection boundaries)
    Gui, Add, DropDownList, xs y+10 gupdateUIpastePanel wp AltSubmit Choose%PasteInPlaceOrientation% vPasteInPlaceOrientation, No mirroring|Flip horizontal|Flip vertical|Flip horizontal and vertical
    Gui, Add, Checkbox, y+10 hp gupdateUIpastePanel Checked%PasteInPlaceIgnoreRotation% vPasteInPlaceIgnoreRotation, &Do not apply rotation
    Gui, Add, Checkbox, y+10 hp gupdateUIpastePanel Checked%PasteInPlaceCentered% vPasteInPlaceCentered, &Center pasted image when possible
    Gui, Add, Checkbox, y+10 hp gupdateUIpastePanel Checked%PasteInPlaceQuality% vPasteInPlaceQuality, &High quality image resampling
    Gui, Add, Text, xs y+10 w%txtWid% vinfoPasteBlur, Image blur amount: %PasteInPlaceBlurAmount%
    Gui, Add, Slider, xs y+1 gupdateUIpastePanel AltSubmit ToolTip w%txtWid% vPasteInPlaceBlurAmount Range0-255, % PasteInPlaceBlurAmount
    Gui, Add, Text, xs y+1 w%txtWid%, (no preview for image blur)

    Gui, Tab, 2 ; colors
    Gui, Add, Text, x+15 y+15 w%txtWid% vinfoPasteHue, Hue: %PasteInPlaceHue%°
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceHue Range-180-180, % PasteInPlaceHue
    Gui, Add, Text, y+7 wp vinfoPasteSat, Saturation: %PasteInPlaceSaturation%`%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceSaturation Range-100-100, % PasteInPlaceSaturation
    Gui, Add, Text, y+7 wp vinfoPasteLight, Brightness: %PasteInPlaceLight%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceLight Range-100-100, % PasteInPlaceLight
    Gui, Add, Text, y+7 wp vinfoPasteGamma, Gamma: %thisGamma%`%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceGamma Range0-300, % PasteInPlaceGamma
    Gui, Add, Text, y+7 wp vinfoPasteOpacity , Opacity: %thisOpacity%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceOpacity Range3-255, % PasteInPlaceOpacity

    Gui, Tab
    Gui, Add, Button, xm+0 y+20 h30 Default w%btnWid% gBtnPasteInSelectedArea, &Paste image
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    Gui, Add, Button, x+25 hp wp gBtnPasteResetOptions, &Reset
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Paste in place: %appTitle%
    SetTimer, updateUIpastePanel, -300
}

PanelTransformSelectedArea() {
    If (thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    DestroyGIFuWin()
    changeMcursor()
    userClipBMPpaste := Gdip_DisposeImage(userClipBMPpaste, 1)
    showTOOLtip("Retrieving selected area from the image, please wait...")
    setImageLoading()
    userClipBMPpaste := getTransformToolSelectedArea()
    If StrLen(userClipBMPpaste)<3
       Return

    viewportStampBMP := Gdip_DisposeImage(viewportStampBMP, 1)
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    Gdip_GetImageDimensions(userClipBMPpaste, imgW, imgH)
    If (imgW>mainWidth || imgH>mainHeight)
       viewportStampBMP := Gdip_ResizeBitmap(userClipBMPpaste, mainWidth, mainHeight, 1, 3)
    Else
       viewportStampBMP := Gdip_CloneBitmap(userClipBMPpaste)

    flipBitmapAccordingToViewPort(viewportStampBMP)
    ResetImgLoadStatus()
    imgEditPanelOpened := 1
    interfaceThread.ahkassign("imgEditPanelOpened", 1)
    createSettingsGUI(31, "PanelTransformSelectedArea")
    INIaction(0, "PasteInPlaceMode", "General")
    INIaction(0, "PasteInPlaceCentered", "General")
    INIaction(0, "PasteInPlaceOpacity", "General")
    INIaction(0, "PasteInPlaceQuality", "General")
    INIaction(0, "PasteInPlaceAngle", "General")
    INIaction(0, "PasteInPlaceOrientation", "General")
    INIaction(0, "PasteInPlaceHue", "General")
    INIaction(0, "PasteInPlaceSaturation", "General")
    INIaction(0, "PasteInPlaceLight", "General")
    INIaction(0, "PasteInPlaceGamma", "General")
    vPselRotation := Round(PasteInPlaceAngle)
    btnWid := 100
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    Gdip_GetImageDimensions(gdiBitmap, oImgW, oImgH)
    thisOpacity := Round((PasteInPlaceOpacity / 255) * 100)
    thisGamma := Round(PasteInPlaceGamma / 255, 2)
    Global infoPasteBlur, infoPasteOpacity, infoPasteHue, infoPasteSat, infoPasteLight, infoPasteGamma
    Gui, Add, Tab3,, Main|Adjust colors
    Gui, Tab, 1 ; general
    Gui, Add, Text,x+15 y+15 Section w%txtWid%, Canvas: %oImgW% x %oImgH% px.`nObject: %imgW% x %imgH% px.
    Gui, Add, DropDownList, xs y+10 wp gupdateUIpastePanel AltSubmit Choose%PasteInPlaceMode% vPasteInPlaceMode, Adjust to selection (only when larger)|Adjust to selection (any size)|Fill selection area entirely (ignore aspect ratio)|Original size (ignore selection boundaries)
    Gui, Add, DropDownList, xs y+10 gupdateUIpastePanel wp AltSubmit Choose%PasteInPlaceOrientation% vPasteInPlaceOrientation, No mirroring|Flip horizontal|Flip vertical|Flip horizontal and vertical
    Gui, Add, Checkbox, y+10 hp gupdateUIpastePanel Checked%PasteInPlaceIgnoreRotation% vPasteInPlaceIgnoreRotation, &Do not apply rotation
    Gui, Add, Checkbox, y+10 hp gupdateUIpastePanel Checked%PasteInPlaceCentered% vPasteInPlaceCentered, Center pasted image when possible
    Gui, Add, Checkbox, y+10 hp gupdateUIpastePanel Checked%PasteInPlaceQuality% vPasteInPlaceQuality, High quality image resampling
    Gui, Add, Text, xs y+10 w1 h1 vinfoPasteBlur, Image blur amount: %PasteInPlaceBlurAmount%
    Gui, Add, Slider, xs y+1 w1 h1 vPasteInPlaceBlurAmount Range0-255, % PasteInPlaceBlurAmount

    Gui, Tab, 2 ; colors
    Gui, Add, Text, x+15 y+15 w%txtWid% vinfoPasteHue, Hue: %PasteInPlaceHue%°
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceHue Range-180-180, % PasteInPlaceHue
    Gui, Add, Text, y+7 wp vinfoPasteSat, Saturation: %PasteInPlaceSaturation%`%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceSaturation Range-100-100, % PasteInPlaceSaturation
    Gui, Add, Text, y+7 wp vinfoPasteLight, Brightness: %PasteInPlaceLight%`%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceLight Range-100-100, % PasteInPlaceLight
    Gui, Add, Text, y+7 wp vinfoPasteGamma, Gamma: %thisGamma%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceGamma Range0-300, % PasteInPlaceGamma
    Gui, Add, Text, y+7 wp vinfoPasteOpacity , Opacity: %thisOpacity%
    Gui, Add, Slider, y+1 wp AltSubmit ToolTip gupdateUIpastePanel vPasteInPlaceOpacity Range3-255, % PasteInPlaceOpacity

    Gui, Tab
    Gui, Add, Button, xm+0 y+20 h30 Default w%btnWid% gBtnPasteInSelectedArea, &Paste image
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    Gui, Add, Button, x+25 hp wp gBtnPasteResetOptions, &Reset
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Transform selected area: %appTitle%
    SetTimer, updateUIpastePanel, -300
}

BtnPasteResetOptions() {
   PasteInPlaceBlurAmount := PasteInPlaceHue := PasteInPlaceSaturation := PasteInPlaceLight := 0
   PasteInPlaceGamma := 100
   PasteInPlaceOpacity := 255
   GuiControl, SettingsGUIA:, PasteInPlaceBlurAmount, % PasteInPlaceBlurAmount
   GuiControl, SettingsGUIA:, PasteInPlaceHue, % PasteInPlaceHue
   GuiControl, SettingsGUIA:, PasteInPlaceSaturation, % PasteInPlaceSaturation
   GuiControl, SettingsGUIA:, PasteInPlaceLight, % PasteInPlaceLight
   GuiControl, SettingsGUIA:, PasteInPlaceGamma, % PasteInPlaceGamma
   GuiControl, SettingsGUIA:, PasteInPlaceOpacity, % PasteInPlaceOpacity
   WriteSettingsPasteInPlacePanel()
   updateUIpastePanel()
}

PanelFillSelectedArea() {
    If (activateImgSelection!=1 || thumbsDisplaying=1)
       Return

    imgEditPanelOpened := 1
    interfaceThread.ahkassign("imgEditPanelOpened", 1)
    createSettingsGUI(23, "PanelFillSelectedArea")
    INIaction(0, "FillAreaColor", "General")
    INIaction(0, "FillAreaShape", "General")
    INIaction(0, "FillAreaAngle", "General")
    INIaction(0, "FillAreaOpacity", "General")
    INIaction(0, "FillAreaInverted", "General")
    INIaction(0, "FillAreaRemBGR", "General")
    INIaction(0, "FillAreaDoContour", "General")
    INIaction(0, "FillAreaDashStyle", "General")
    INIaction(0, "FillAreaRoundedCaps", "General")
    INIaction(0, "FillAreaDoubleLine", "General")
    INIaction(0, "FillAreaContourAlign", "General")
    INIaction(0, "FillAreaContourThickness", "General")
    vPselRotation := Round(FillAreaAngle)
    btnWid := 100
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    If (FillAreaDoContour=1)
       FillAreaRemBGR := 0

    thisOpacity := Round((FillAreaOpacity / 255) * 100)
    Global infoFillAreaOpacity, infoFillAreaContour
    Gui, Add, Text, x15 y15 Section w%txtWid%, Please configure how to fill the selected area.
    Gui, Add, DropDownList, xs y+10 AltSubmit Choose%FillAreaShape% vFillAreaShape gupdateUIfillPanel, Rectangle|Rounded rectangle|Ellipse|Triangle|Right triangle|Rhombus
    Gui, Add, ListView, x+5 hp w%editWid% %CCLVO% Background%FillAreaColor% vFillAreaColor hwndhLVfillColor,
    Gui, Add, Checkbox, x+5 hp Checked%FillAreaInverted% vFillAreaInverted gupdateUIfillPanel, &Invert area
    Gui, Add, Checkbox, xs y+10 hp Checked%FillAreaRemBGR% vFillAreaRemBGR gupdateUIfillPanel, &Erase background behind the new object
    Gui, Add, Checkbox, xs y+10 hp Checked%FillAreaDoContour% vFillAreaDoContour gupdateUIfillPanel, &Draw only an outline / a contour
    Gui, Add, DropDownList, xs+15 y+10 w%btnWid% AltSubmit Choose%FillAreaContourAlign% vFillAreaContourAlign gupdateUIfillPanel, Inside|Centered|Outside
    Gui, Add, DropDownList, x+5 wp AltSubmit Choose%FillAreaDashStyle% vFillAreaDashStyle gupdateUIfillPanel, Continous|Dashes|Dots|Dashes and dots
    Gui, Add, Checkbox, xs+15 y+6 wp Checked%FillAreaDoubleLine% vFillAreaDoubleLine gupdateUIfillPanel, &Double line
    Gui, Add, Checkbox, x+2 gupdateUIfillPanel Checked%FillAreaRoundedCaps% vFillAreaRoundedCaps, &Rounded caps
    Gui, Add, Text, xs y+10 w%txtWid% vinfoFillAreaOpacity, Opacity: %thisOpacity%`%
    Gui, Add, Slider, xs y+1 gupdateUIfillPanel ToolTip AltSubmit w%txtWid% vFillAreaOpacity Range3-255, % FillAreaOpacity
    Gui, Add, Text, xs y+10 wp vinfoFillAreaContour, Contour thickness: %FillAreaContourThickness% pixels
    Gui, Add, Slider, xs y+1 gupdateUIfillPanel ToolTip AltSubmit w%txtWid% vFillAreaContourThickness Range1-450, % FillAreaContourThickness
    If (FillAreaDoContour=1)
    {
       GuiControl, Disable, FillAreaRemBGR
       GuiControl, Disable, FillAreaInverted
       GuiControl, Enable, FillAreaContourThickness
       GuiControl, Enable, infoFillAreaContour
       GuiControl, Enable, FillAreaContourAlign
       GuiControl, Enable, FillAreaDashStyle
       GuiControl, Enable, FillAreaRoundedCaps
       GuiControl, Enable, FillAreaDoubleLine
    } Else
    {
       GuiControl, Enable, FillAreaRemBGR
       GuiControl, Enable, FillAreaInverted
       GuiControl, Disable, FillAreaRoundedCaps
       GuiControl, Disable, FillAreaDoubleLine
       GuiControl, Disable, FillAreaContourAlign
       GuiControl, Disable, FillAreaDashStyle
       GuiControl, Disable, FillAreaContourThickness
       GuiControl, Disable, infoFillAreaContour
    }

    If (FillAreaDoContour=1 && FillAreaDashStyle>1)
       GuiControl, Enable, FillAreaRoundedCaps
    Else
       GuiControl, Disable, FillAreaRoundedCaps

    Gui, Add, Button, xm+0 y+20 h30 Default w%btnWid% gBtnFillSelectedArea, &Apply
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Fill/draw shapes in selected area: %appTitle%
    SetTimer, coreFillSelectedArea, -50
}

PanelDrawLines() {
    If (activateImgSelection!=1 || thumbsDisplaying=1)
       Return

    imgEditPanelOpened := 1
    interfaceThread.ahkassign("imgEditPanelOpened", 1)
    createSettingsGUI(30, "PanelDrawLines")
    INIaction(0, "DrawLineAreaColor", "General")
    INIaction(0, "DrawLineAreaDashStyle", "General")
    INIaction(0, "DrawLineAreaCapsStyle", "General")
    INIaction(0, "DrawLineAreaContourAlign", "General")
    INIaction(0, "DrawLineAreaAngle", "General")
    INIaction(0, "DrawLineAreaContourThickness", "General")
    INIaction(0, "DrawLineAreaOpacity", "General")
    INIaction(0, "DrawLineAreaBorderTop", "General")
    INIaction(0, "DrawLineAreaBorderBottom", "General")
    INIaction(0, "DrawLineAreaBorderLeft", "General")
    INIaction(0, "DrawLineAreaBorderRight", "General")
    INIaction(0, "DrawLineAreaBorderCenter", "General")
    INIaction(0, "DrawLineAreaBorderArcA", "General")
    INIaction(0, "DrawLineAreaBorderArcB", "General")
    INIaction(0, "DrawLineAreaBorderArcC", "General")
    INIaction(0, "DrawLineAreaBorderArcD", "General")
    vPselRotation := Round(DrawLineAreaAngle)
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }
    btnWid := 165
    thisOpacity := Round((DrawLineAreaOpacity / 255) * 100)
    Global infoDrawLineAreaOpacity, infoDrawLineAreaContour
    Gui, Add, Text, x15 y15 Section w%txtWid%, Please configure what lines to draw and how.
    Gui, Add, Text, y+10 Section w%txtWid%, Line style. Alignment.
    Gui, Add, DropDownList, xs y+7 w%btnWid% gupdateUIDrawLinesPanel AltSubmit Choose%DrawLineAreaDashStyle% vDrawLineAreaDashStyle, Continous|Dashes|Dots|Dashes and dots
    Gui, Add, DropDownList, x+10 wp gupdateUIDrawLinesPanel AltSubmit Choose%DrawLineAreaContourAlign% vDrawLineAreaContourAlign, Inside|Centered|Outside

    Gui, Add, Checkbox, xs y+10 w55 h28 +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderArcA% vDrawLineAreaBorderArcA,○
    Gui, Add, Checkbox, x+1 wp hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderTop% vDrawLineAreaBorderTop,─
    Gui, Add, Checkbox, x+1 wp hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderArcB% vDrawLineAreaBorderArcB,○
    Gui, Add, Checkbox, x+10 w%btnWid% hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaCapsStyle% vDrawLineAreaCapsStyle, Rounded caps
    Gui, Add, Checkbox, xs y+1 w55 h28 +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderLeft% vDrawLineAreaBorderLeft,▏
    Gui, Add, Text, x+1 wp hp Center,.
    ; Gui, Add, Checkbox, x+1 wp hp +0x1000 Checked%DrawLineAreaBorderCenter% vDrawLineAreaBorderCenter,▏
    Gui, Add, Checkbox, x+1 wp hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderRight% vDrawLineAreaBorderRight,▏
    Gui, Add, Checkbox, x+10 w%btnWid% hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaDoubles% vDrawLineAreaDoubles, Double line
    Gui, Add, Checkbox, xs y+1 w55 h28 +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderArcC% vDrawLineAreaBorderArcC,○
    Gui, Add, Checkbox, x+1 wp hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderBottom% vDrawLineAreaBorderBottom,─
    Gui, Add, Checkbox, x+1 wp hp +0x1000 gupdateUIDrawLinesPanel Checked%DrawLineAreaBorderArcD% vDrawLineAreaBorderArcD,○
    Gui, Add, ListView, x+10 w%btnWid% hp %CCLVO% Background%DrawLineAreaColor% vDrawLineAreaColor,
    Gui, Add, DropDownList, xs y+0 w%btnWid% gupdateUIDrawLinesPanel AltSubmit Choose%DrawLineAreaBorderCenter% vDrawLineAreaBorderCenter,No center line|Vertical|Horizontal|Slash|Backslash|Both diagonals|Both H/V lines

    Gui, Add, Text, xs y+10 w%txtWid% vinfoDrawLineAreaOpacity, Opacity: %thisOpacity%`%
    Gui, Add, Slider, xs y+1 gupdateUIDrawLinesPanel AltSubmit ToolTip w%txtWid% vDrawLineAreaOpacity Range3-255, % DrawLineAreaOpacity
    Gui, Add, Text, xs y+10 wp vinfoDrawLineAreaContour, Contour thickness: %DrawLineAreaContourThickness% pixels
    Gui, Add, Slider, xs y+1 gupdateUIDrawLinesPanel AltSubmit ToolTip w%txtWid% vDrawLineAreaContourThickness Range1-450, % DrawLineAreaContourThickness

    Gui, Add, Button, xm+0 y+20 h30 Default w%btnWid% gBtnDrawLinesSelectedArea, &Apply
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Draw lines in selected area: %appTitle%
    SetTimer, coreDrawLinesSelectionArea, -50
}

PanelEraseSelectedArea() {
    If (activateImgSelection!=1 || thumbsDisplaying=1)
       Return

    imgEditPanelOpened := 1
    interfaceThread.ahkassign("imgEditPanelOpened", 1)
    createSettingsGUI(25, "PanelEraseSelectedArea")
    INIaction(0, "EraseAreaFader", "General")
    INIaction(0, "EraseAreaOpacity", "General")
    INIaction(0, "EraseAreaIgnoreRotation", "General")
    btnWid := 100
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    thisOpacity := Round((EraseAreaOpacity / 255) * 100)
    Global infoEraseOpacity
    Gui, Add, Text, x15 y15 Section w%txtWid%, Please decide how to erase or fade selected area:
    Gui, Add, Checkbox, xs y+10 hp Checked%EraseAreaIgnoreRotation% vEraseAreaIgnoreRotation gupdateUIerasePanel, &Do not apply rotation
    Gui, Add, Checkbox, xs y+10 hp Checked%EraseAreaFader% vEraseAreaFader gupdateUIerasePanel, &Fade selected area
    Gui, Add, Text, xs+15 y+10 wp hp vinfoEraseOpacity, Opacity: %thisOpacity%`%
    Gui, Add, Slider, xp y+5 AltSubmit gupdateUIerasePanel ToolTip w%txtWid% vEraseAreaOpacity Range5-250, % EraseAreaOpacity

    Gui, Add, Button, xs+0 y+20 h30 Default w%btnWid% gBtnEraseSelectedArea, &Erase area
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Erase selected area: %appTitle%
    updateUIerasePanel()
}

liveEraserPreview() {
      Gdip_GraphicsClear(2NDglPG, "0x00" WindowBGRcolor)
      Gdip_GetImageDimensions(gdiBitmap, qimgW, qimgH)
      calcImgSelection2bmp(1, qimgW, qimgH, qimgW, qimgH, qimgSelPx, qimgSelPy, qimgSelW, qimgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
      imgSelPx := x1 := selDotX + SelDotsSize//2, x2 := selDotAx + SelDotsSize//2
      imgSelPy := y1 := selDotY + SelDotsSize//2, y2 := selDotAy + SelDotsSize//2
      imgSelW := max(X1, X2) - min(X1, X2)
      imgSelH := max(Y1, Y2) - min(Y1, Y2)
      pPath := Gdip_CreatePath()
      If (EllipseSelectMode=1)
         Gdip_AddPathEllipse(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
      Else
         Gdip_AddPathRectangle(pPath, imgSelPx, imgSelPy, imgSelW, imgSelH)

      If (EraseAreaIgnoreRotation!=1)
         Gdip_RotatePathAtCenter(pPath, vPselRotation)

      thisOpacity := (EraseAreaFader=1) ? EraseAreaOpacity : 0
      Gdip_FromARGB("0xFF999999", A, R, G, B)
      thisColorA := Gdip_ToARGB(255 - thisOpacity, R, G, B)
      Gdip_FromARGB("0xFF111111", A, R, G, B)
      thisColorB := Gdip_ToARGB(255 - thisOpacity, R, G, B)
      thisBrush := Gdip_BrushCreateHatch(thisColorA, thisColorB, 50)
      Gdip_FillPath(2NDglPG, thisBrush, pPath)

      Gdip_DeletePath(pPath)
      Gdip_DeleteBrush(thisBrush)
      GetClientSize(mainWidth, mainHeight, PVhwnd)
      r2 := UpdateLayeredWindow(hGDIselectWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
}
PanelBlurSelectedArea() {
    If (activateImgSelection!=1 || thumbsDisplaying=1)
       Return

    createSettingsGUI(26, "PanelBlurSelectedArea")
    INIaction(0, "blurAreaAmount", "General")
    INIaction(0, "blurAreaInverted", "General")
    INIaction(0, "blurAreaSoftEdges", "General")
    INIaction(0, "blurAreaOpacity", "General")
    INIaction(0, "blurAreaTwice", "General")
    btnWid := 100
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    thisOpacity := Round((blurAreaOpacity / 255) * 100)
    Global infoBlurOpacity, infoBlurAmount
    Gui, Add, Checkbox, x15 y15 Section Checked%blurAreaSoftEdges% vblurAreaSoftEdges gupdateUIblurPanel, &Soft edges
    Gui, Add, Checkbox, xs y+10 Checked%blurAreaInverted% vblurAreaInverted gupdateUIblurPanel, &Invert selection area
    Gui, Add, Checkbox, xs y+10 hp Checked%blurAreaTwice% vblurAreaTwice gupdateUIblurPanel, &Blur twice in one go [for very large images]
    Gui, Add, Text, xs y+10 wp vinfoBlurAmount, Blur amount: %blurAreaAmount%
    Gui, Add, Slider, xp y+5 gupdateUIblurPanel ToolTip w%txtWid% vblurAreaAmount Range1-255, % blurAreaAmount
    Gui, Add, Text, xs y+10 wp vinfoBlurOpacity, Opacity: %thisOpacity%`%
    Gui, Add, Slider, xp y+5 gupdateUIblurPanel ToolTip w%txtWid% vblurAreaOpacity Range5-255, % blurAreaOpacity

    Gui, Add, Button, xs+0 y+20 h30 Default w%btnWid% gBtnBlurSelectedArea, &Blur area
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Blur selected area: %appTitle%
}

PanelRotateSelectedArea() {
    If (activateImgSelection!=1 || thumbsDisplaying=1)
       Return

    createSettingsGUI(27, "PanelRotateSelectedArea")
    INIaction(0, "RotateAreaAngle", "General")
    INIaction(0, "RotateAreaQuality", "General")
    INIaction(0, "RotateAreaOpacity", "General")
    INIaction(0, "RotateAreaWithinBounds", "General")
    INIaction(0, "RotateAreaRemBgr", "General")
    btnWid := 100
    txtWid := 350
    EditWid := 60
    If (PrefsLargeFonts=1)
    {
       EditWid := EditWid + 50
       btnWid := btnWid + 70
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }

    thisOpacity := Round((RotateAreaOpacity / 255) * 100)
    Global infoRotateOpacity, infoRotateAngle
    Gui, Add, Checkbox, x15 y15 Section Checked%RotateAreaRemBgr% vRotateAreaRemBgr, &Erase initial area
    Gui, Add, Checkbox, xs y+10 Checked%RotateAreaQuality% vRotateAreaQuality, &High quality image resampling
    Gui, Add, Checkbox, xs y+10 w%txtWid% Checked%RotateAreaWithinBounds% vRotateAreaWithinBounds, &Rotate within selection boundaries
    Gui, Add, Text, xs y+10 wp vinfoRotateAngle, Rotation angle: %RotateAreaAngle%°
    Gui, Add, Slider, xp y+5 gupdateUIrotatePanel ToolTip w%txtWid% vRotateAreaAngle Range1-360, % RotateAreaAngle
    Gui, Add, Text, xs y+10 wp vinfoRotateOpacity, Opacity: %thisOpacity%`%
    Gui, Add, Slider, xp y+5 gupdateUIrotatePanel ToolTip w%txtWid% vRotateAreaOpacity Range5-255, % RotateAreaOpacity

    Gui, Add, Button, xs+0 y+20 h30 Default w%btnWid% gBtnRotateSelectedArea, &Rotate area
    Gui, Add, Button, x+5 hp w90 gCloseWindow, &Cancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Rotate selected area: %appTitle%
}

updateUIrotatePanel() {
    GuiControlGet, RotateAreaAngle
    GuiControlGet, RotateAreaOpacity
    GuiControlGet, RotateAreaWithinBounds
    GuiControlGet, RotateAreaRemBgr
    GuiControlGet, RotateAreaQuality

    INIaction(1, "RotateAreaAngle", "General")
    INIaction(1, "RotateAreaRemBgr", "General")
    INIaction(1, "RotateAreaQuality", "General")
    INIaction(1, "RotateAreaWithinBounds", "General")
    INIaction(1, "RotateAreaOpacity", "General")

    thisOpacity := Round((RotateAreaOpacity / 255) * 100)
    GuiControl, SettingsGUIA:, infoRotateOpacity, Opacity: %thisOpacity%`%
    GuiControl, SettingsGUIA:, infoRotateAngle, Rotation angle: %RotateAreaAngle%°
}

BtnDrawLinesSelectedArea() {
  updateUIDrawLinesPanel("noPreview")
  If (DrawLineAreaBorderTop=0 && DrawLineAreaBorderBottom=0 && DrawLineAreaBorderLeft=0 && DrawLineAreaBorderRight=0
  && DrawLineAreaBorderCenter=1 && DrawLineAreaBorderArcA=0 && DrawLineAreaBorderArcB=0 && DrawLineAreaBorderArcC=0 && DrawLineAreaBorderArcD=0)
  {
     SoundBeep , 300, 100
     showTOOLtip("No lines to draw selected...")
     SetTimer, RemoveTooltip, % -msgDisplayTime//2
     Return
  }

  ; CloseWindow()
  activateImgSelection := editingSelectionNow := 1
  pPath := DrawLinesInSelectedArea()
  Gdip_DeletePath(pPath)
  SetTimer, RemoveTooltip, -250
}

updateUIDrawLinesPanel(actionu=0) {
    GuiControlGet, DrawLineAreaOpacity
    GuiControlGet, DrawLineAreaDashStyle
    GuiControlGet, DrawLineAreaCapsStyle
    GuiControlGet, DrawLineAreaContourAlign
    GuiControlGet, DrawLineAreaDoubles
    GuiControlGet, DrawLineAreaBorderTop
    GuiControlGet, DrawLineAreaBorderBottom
    GuiControlGet, DrawLineAreaBorderLeft
    GuiControlGet, DrawLineAreaBorderRight
    GuiControlGet, DrawLineAreaBorderCenter
    GuiControlGet, DrawLineAreaBorderArcA
    GuiControlGet, DrawLineAreaBorderArcB
    GuiControlGet, DrawLineAreaBorderArcC
    GuiControlGet, DrawLineAreaBorderArcD
    GuiControlGet, DrawLineAreaContourThickness

    thisOpacity := Round((DrawLineAreaOpacity / 255) * 100)
    GuiControl, SettingsGUIA:, infoDrawLineAreaOpacity, Opacity: %thisOpacity%`%
    GuiControl, SettingsGUIA:, infoDrawLineAreaContour, Contour thickness: %DrawLineAreaContourThickness% pixels
    activateImgSelection := editingSelectionNow := 1
    DrawLineAreaAngle := vPselRotation
    If (DrawLineAreaBorderTop=0 && DrawLineAreaBorderBottom=0 && DrawLineAreaBorderLeft=0 && DrawLineAreaBorderRight=0
    && DrawLineAreaBorderCenter=1 && DrawLineAreaBorderArcA=0 && DrawLineAreaBorderArcB=0 && DrawLineAreaBorderArcC=0 && DrawLineAreaBorderArcD=0)
       dummyRefreshImgSelectionWindow()
    Else If (actionu!="noPreview")
       coreDrawLinesSelectionArea()
    Else
       SetTimer, WriteSettingsDrawLinesPanel, -250
}

WriteSettingsDrawLinesPanel() {
    INIaction(1, "DrawLineAreaColor", "General")
    INIaction(1, "DrawLineAreaDashStyle", "General")
    INIaction(1, "DrawLineAreaCapsStyle", "General")
    INIaction(1, "DrawLineAreaContourAlign", "General")
    INIaction(1, "DrawLineAreaAngle", "General")
    INIaction(1, "DrawLineAreaContourThickness", "General")
    INIaction(1, "DrawLineAreaOpacity", "General")
    INIaction(1, "DrawLineAreaBorderTop", "General")
    INIaction(1, "DrawLineAreaBorderBottom", "General")
    INIaction(1, "DrawLineAreaBorderLeft", "General")
    INIaction(1, "DrawLineAreaBorderRight", "General")
    INIaction(1, "DrawLineAreaBorderCenter", "General")
    INIaction(1, "DrawLineAreaBorderArcA", "General")
    INIaction(1, "DrawLineAreaBorderArcB", "General")
    INIaction(1, "DrawLineAreaBorderArcC", "General")
    INIaction(1, "DrawLineAreaBorderArcD", "General")
}

updateUIblurPanel() {
    GuiControlGet, blurAreaAmount
    GuiControlGet, blurAreaInverted
    GuiControlGet, blurAreaSoftEdges
    GuiControlGet, blurAreaOpacity
    GuiControlGet, blurAreaTwice

    INIaction(1, "blurAreaOpacity", "General")
    INIaction(1, "blurAreaInverted", "General")
    INIaction(1, "blurAreaAmount", "General")
    INIaction(1, "blurAreaSoftEdges", "General")
    INIaction(1, "blurAreaTwice", "General")

    thisOpacity := Round((blurAreaOpacity / 255) * 100)
    GuiControl, SettingsGUIA:, infoBlurOpacity, Opacity: %thisOpacity%`%
    GuiControl, SettingsGUIA:, infoBlurAmount, Blur amount: %blurAreaAmount%
}

updateUIerasePanel(actionu:=0) {
    GuiControlGet, EraseAreaFader
    GuiControlGet, EraseAreaOpacity
    GuiControlGet, EraseAreaIgnoreRotation

    INIaction(1, "EraseAreaOpacity", "General")
    INIaction(1, "EraseAreaFader", "General")
    INIaction(1, "EraseAreaIgnoreRotation", "General")

    thisOpacity := Round((EraseAreaOpacity / 255) * 100)
    GuiControl, SettingsGUIA:, infoEraseOpacity, Opacity: %thisOpacity%`%
    If (EraseAreaFader=1)
    {
       GuiControl, SettingsGUIA: Enable, infoEraseOpacity
       GuiControl, SettingsGUIA: Enable, EraseAreaOpacity
    } Else
    {
       GuiControl, SettingsGUIA: Disable, infoEraseOpacity
       GuiControl, SettingsGUIA: Disable, EraseAreaOpacity
    }

    If (actionu!="noPreview")
       livePreviewsImageEditing()
}

BtnEraseSelectedArea() {
  updateUIerasePanel("noPreview")
  CloseWindow()
  activateImgSelection := editingSelectionNow := 1
  EraseSelectedArea()
}

BtnRotateSelectedArea() {
  updateUIrotatePanel()
  CloseWindow()
  activateImgSelection := editingSelectionNow := 1
  RotateSelectedArea()
}

BtnBlurSelectedArea() {
  updateUIblurPanel()
  CloseWindow()
  activateImgSelection := editingSelectionNow := 1
  BlurSelectedArea()
}

updateUIfillPanel(actionu:=0) {
    GuiControlGet, FillAreaOpacity
    GuiControlGet, FillAreaShape
    GuiControlGet, FillAreaInverted
    GuiControlGet, FillAreaRemBGR
    GuiControlGet, FillAreaDoContour
    GuiControlGet, FillAreaDashStyle
    GuiControlGet, FillAreaRoundedCaps
    GuiControlGet, FillAreaDoubleLine
    GuiControlGet, FillAreaContourAlign
    GuiControlGet, FillAreaContourThickness

    thisOpacity := Round((FillAreaOpacity / 255) * 100)
    GuiControl, SettingsGUIA:, infoFillAreaOpacity, Opacity: %thisOpacity%`%
    GuiControl, SettingsGUIA:, infoFillAreaContour, Contour thickness: %FillAreaContourThickness% pixels

    If (FillAreaDoContour=1)
    {
       GuiControl, SettingsGUIA: Disable, FillAreaRemBGR
       GuiControl, SettingsGUIA: Disable, FillAreaInverted
       GuiControl, SettingsGUIA: Enable, FillAreaContourThickness
       GuiControl, SettingsGUIA: Enable, FillAreaRoundedCaps
       GuiControl, SettingsGUIA: Enable, FillAreaDoubleLine
       GuiControl, SettingsGUIA: Enable, infoFillAreaContour
       GuiControl, SettingsGUIA: Enable, FillAreaContourAlign
       GuiControl, SettingsGUIA: Enable, FillAreaDashStyle
    } Else
    {
       GuiControl, SettingsGUIA: Enable, FillAreaRemBGR
       GuiControl, SettingsGUIA: Enable, FillAreaInverted
       GuiControl, SettingsGUIA: Disable, FillAreaDashStyle
       GuiControl, SettingsGUIA: Disable, FillAreaContourAlign
       GuiControl, SettingsGUIA: Disable, FillAreaContourThickness
       GuiControl, SettingsGUIA: Disable, FillAreaRoundedCaps
       GuiControl, SettingsGUIA: Disable, FillAreaDoubleLine
       GuiControl, SettingsGUIA: Disable, infoFillAreaContour
    }
    FillAreaAngle := vPselRotation
    If (FillAreaDoContour=1 && FillAreaDashStyle>1)
       GuiControl, Enable, FillAreaRoundedCaps
    Else
       GuiControl, Disable, FillAreaRoundedCaps

    activateImgSelection := editingSelectionNow := 1
    If (actionu!="noPreview")
       coreFillSelectedArea()
    Else
       SetTimer, WriteSettingsFillAreaPanel, -350
}

WriteSettingsFillAreaPanel() {
    INIaction(1, "FillAreaColor", "General")
    INIaction(1, "FillAreaOpacity", "General")
    INIaction(1, "FillAreaShape", "General")
    INIaction(1, "FillAreaAngle", "General")
    INIaction(1, "FillAreaInverted", "General")
    INIaction(1, "FillAreaRemBGR", "General")
    INIaction(1, "FillAreaDoContour", "General")
    INIaction(1, "FillAreaDashStyle", "General")
    INIaction(1, "FillAreaRoundedCaps", "General")
    INIaction(1, "FillAreaDoubleLine", "General")
    INIaction(1, "FillAreaContourAlign", "General")
    INIaction(1, "FillAreaContourThickness", "General")
}

BtnFillSelectedArea() {
    updateUIfillPanel("noPreview")
    Sleep, 1
    ; CloseWindow()
    activateImgSelection := editingSelectionNow := 1
    ; Sleep, 1
    FillSelectedArea()
    SetTimer, RemoveTooltip, -250
}

PrefsPanelWindow() {
    createSettingsGUI(14, "PrefsPanelWindow")
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
    Gui, Add, ListView, xs+0 yp+30 w%editWid% hp %CCLVO% Background%WindowBGRcolor% vWindowBGRcolor hwndhLV3,
    Gui, Add, Checkbox, x15 y+10 gupdateUIsettings Checked%borderAroundImage% vborderAroundImage, Highlight image borders in the viewport

    If !FontList._NewEnum()[k, v]
    {
       Fnt_GetListOfFonts()
       FontList := trimArray(FontList)
    }

    Loop, % FontList.Count()
    {
        fontNameInstalled := FontList[A_Index]
        If (fontNameInstalled ~= "i)(@|biz ud|ud digi kyo|oem|extb|symbol|marlett|wst_|glyph|reference specialty|system|terminal|mt extra|small fonts|cambria math|this font is not|fixedsys|emoji|hksc| mdl|wingdings|webdings)") || (fontNameInstalled=OSDFontName)
           Continue
        GuiControl, SettingsGUIA:, OSDFontName, %fontNameInstalled%
    }

    Gui, Add, Button, xm+0 y+20 h30 w%btnWid% gOpenUImenu, &More options
    Gui, Add, Button, x+5 hp w90 gPrefsCloseBTN Default, Clo&se
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Interface settings: %appTitle%
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

     calcHUDsize()
     msgDisplayTime := DisplayTimeUser*1000
     SetTimer, WriteSettingsUI, -90
}

WriteSettingsUI() {
  INIaction(1, "DisplayTimeUser", "General")
  INIaction(1, "OSDFontName", "General")
  INIaction(1, "WindowBgrColor", "General")
  INIaction(1, "OSDbgrColor", "General")
  INIaction(1, "OSDtextColor", "General")
  INIaction(1, "OSDfntSize", "General")
  INIaction(1, "PasteFntSize", "General")
  INIaction(1, "FontBolded", "General")
  INIaction(1, "FontItalica", "General")
  INIaction(1, "usrTextAlign", "General")
  INIaction(1, "borderAroundImage", "General")
}

PrefsCloseBTN() {
     updateUIsettings()
     interfaceThread.ahkFunction("updateWindowColor")
     CloseWindow()
}

SetUIcolors(hC, event, c, err=0) {
; Function by Drugwash
; Critical MUST be disabled below! If that's not done, script will enter a deadlock !
  Static
  oc := A_IsCritical
  Critical, Off
  If (event!="Normal")
     Return

  g := A_Gui, ctrl := A_GuiControl
  r := %ctrl% := hexRGB(Dlg_Color(%ctrl%, hC))
  Critical, %oc%
  GuiControl, %g%:+Background%r%, %ctrl%
  If (AnyWindowOpen=14)
  {
     interfaceThread.ahkFunction("updateWindowColor")
     updateUIsettings()
     refreshWinBGRbrush()
     dummyTimerDelayiedImageDisplay(50)
  }
}

hexRGB(c) {
; unknown source
  r := ((c&255)<<16)+(c&65280)+((c&0xFF0000)>>16)
  c := "000000"
  DllCall("msvcrt\sprintf", "AStr", c, "AStr", "%06X", "UInt", r, "CDecl")
  Return c
}

Hex2Str(val, len, x:=false, caps:=true) {
; Function by Drugwash
    VarSetCapacity(out, (len+1)*2, 32), c := caps ? "X" : "x"
    DllCall("msvcrt\sprintf", "AStr", out, "AStr", "%0" len "ll" c, "UInt64", val, "CDecl")
    Result := x ? "0x" out : out
    Return Result
}

getCustomColorsFromImage(whichBitmap) {
  Gdip_GetImageDimensions(whichBitmap, imgW, imgH)
  calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
  c := []
  c[1] := Gdip_GetPixelColor(whichBitmap, X1, Y1, 3)
  c[2] := Gdip_GetPixelColor(whichBitmap, X2, Y2, 3)
  c[3] := Gdip_GetPixelColor(whichBitmap, X1, Y2, 3)
  c[4] := Gdip_GetPixelColor(whichBitmap, X2, Y1, 3)
  c[5] := Gdip_GetPixelColor(whichBitmap, X1 + imgSelW//2, Y1 + imgSelH//2, 3)
  c[6] := Gdip_GetPixelColor(whichBitmap, X1 + imgSelW//2, Y1, 3)
  c[7] := Gdip_GetPixelColor(whichBitmap, X1, Y1 + imgSelH//2, 3)
  c[8] := Gdip_GetPixelColor(whichBitmap, X2, Y2 - imgSelH//2, 3)
  c[9] := Gdip_GetPixelColor(whichBitmap, X2 - imgSelW//2, Y2, 3)
  c[10] := Gdip_GetPixelColor(whichBitmap, X1 + imgSelW//4, Y1 + imgSelH//4, 3)
  c[11] := Gdip_GetPixelColor(whichBitmap, X1 + imgSelW//2 + imgSelW//4, Y1 + imgSelH//2 + imgSelH//4, 3)
  c[12] := Gdip_GetPixelColor(whichBitmap, 1, 1, 3)
  c[13] := Gdip_GetPixelColor(whichBitmap, 1, imgH - 1, 3)
  c[14] := Gdip_GetPixelColor(whichBitmap, imgW - 1, imgH - 1, 3)
  c[15] := Gdip_GetPixelColor(whichBitmap, imgW - 1, 1, 3)
  c[16] := Gdip_GetPixelColor(whichBitmap, imgW//2, imgH//2, 3)
  Return c
}

Dlg_Color(Color,hwnd) {
; Function by maestrith 
; from: [AHK 1.1] Font and Color Dialogs 
; https://autohotkey.com/board/topic/94083-ahk-11-font-and-color-dialogs/
; Modified by Marius Șucan and Drugwash


  VarSetCapacity(CUSTOM,64,0)
  size := VarSetCapacity(CHOOSECOLOR,9*A_PtrSize,0)

  cclrs := getCustomColorsFromImage(gdiBitmap)
  Loop, 16
  {
     ; BGR HEX
 ;    thisColor := "0x" SubStr(cclrs[A_Index], -1) SubStr(cclrs[A_Index], 7, 2) SubStr(cclrs[A_Index], 5, 2)
     NumPut(cclrs[A_Index], &CUSTOM, (A_Index-1)*4, "UInt")
  }

  oldColor := Color
  Color := "0x" hexRGB(InStr(Color, "0x") ? Color : Color ? "0x" Color : 0x0)
  NumPut(size,CHOOSECOLOR,0,"UInt")
  NumPut(hwnd,CHOOSECOLOR,A_PtrSize,"Ptr")
  NumPut(Color,CHOOSECOLOR,3*A_PtrSize,"UInt")
  NumPut(0x3,CHOOSECOLOR,5*A_PtrSize,"UInt")
  NumPut(&CUSTOM,CHOOSECOLOR,4*A_PtrSize,"Ptr")
  If !ret := DllCall("comdlg32\ChooseColorW","Ptr",&CHOOSECOLOR,"UInt")
     Exit

  SetFormat, Integer, H
  Color := NumGet(CHOOSECOLOR,3*A_PtrSize,"UInt")
  SetFormat, Integer, D
  Return Color
}

OpenUImenu() {
   deleteMenus()
   createMenuInterfaceOptions()
   showThisMenu("PvUIprefs")
}

PanelDefineEntireSlideshowLength() {
    Global userHourDur, userMinDur, userSecDur, infoLine, userDefinedSpeedSlideshow
    If (maxFilesIndex<3 || thumbsDisplaying=1)
       Return

    createSettingsGUI(19, "PanelDefineEntireSlideshowLength")
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
    Gui, Add, Button, x+5 hp w75 gTimeLapseInfoBox, Infos
    Gui, Add, Button, x+5 hp w95 gSetTimeLapseMode, Timelapse

    Gui, Add, Text, xs y+15 w%txtWid% vinfoLine, One image every: %infoSliSpeed%`nEstimated slideshow duration: %etaTime%

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gStartSlideINtotalTimeBTNaction, &Start slideshow
    Gui, Add, Button, x+5 hp w90 gResetSlideSpeed, De&fault
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&lose
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Define total slideshow time: %appTitle%
}

TimeLapseInfoBox() {
    msgBoxWrapper(appTitle ": Help", "The slideshow durations displayed in the panel include the time estimated to load each image. Based on previously loaded images it takes about " drawModeCzeit " [in milisec.]`n `nFor optimal timelapses [or very fast slideshows] set zoom at 100`% and disable color adjustments.", 0, 0, 0)
    coreResetSlideSpeed(33, 1)
    GuiControl, SettingsGUIA: Choose, userDefinedSpeedSlideshow, 2
}

SetTimeLapseMode() {
    msgResult := msgBoxWrapper(appTitle ": Confirmation", "Are you sure you want to set slideshow mode to timelapse? This will set zoom level to 100% and disable any image effect or adjustment.`n`nThe slideshow speed will be set at ~30 FPS [33 images/sec.].", 4, 0, "question")
    If (msgResult="Yes")
    {
       imgFxMode := usrColorDepth := zoomLevel := 1
       IMGresizingMode := 4
       vpIMGrotation := FlipImgH := FlipImgV := 0
       coreResetSlideSpeed(33, 1)
       GuiControl, SettingsGUIA: Choose, userDefinedSpeedSlideshow, 2
       dummyTimerDelayiedImageDisplay(50)
    }
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
   slidesDuration := slideShowDelay
   ; slidesDuration := (slideShowDelay<drawModeCzeit) ? Round((drawModeCzeit*0.7+slideShowDelay)//2) : slideShowDelay
  ; If (slidesDuration<1995 && slidesDuration!=1000)
  ;    miliSec := slidesDuration " milisec."
   ; Else
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

EstimateSlideShowLength(noPrecision:=0) {
    slidesDuration := (slideShowDelay<drawModeCzeit) ? (drawModeCzeit + slideShowDelay)/2 : drawModeCzeit*0.9 + slideShowDelay
    ; slidesDuration := (slideShowDelay<drawModeCzeit) ? drawModeCzeit : slideShowDelay
    approxMarker := (slideShowDelay<drawModeCzeit) ? "~" : ""
    infoFilesSel := (maxFilesIndex>0) ? maxFilesIndex : 1
    slidesDuration := Round(slidesDuration/1000, 3) * infoFilesSel
    ; MsgBox, % etaTime "--" slidesDuration "--" slideShowDelay "--" drawModeCzeit "--" maxFilesIndex
    etaTime := approxMarker SecToHHMMSS(slidesDuration)
    If (noPrecision=1)
       etaTime := RegExReplace(etaTime, "\...s", "s")
    Return etaTime
}

PanelJump2index() {
    Global newJumpIndex
    If (maxFilesIndex<3)
       Return

    createSettingsGUI(13, "PanelJump2index")
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
    If (totalFramesIndex>2)
       friendly := "`n`nAdd F to jump to a specific frame in the current image. Total frames: " totalFramesIndex ". "

    Gui, Add, Text, x15 y15 w%txtWid%, Please type the index number you want to jump to...`n`nAdd S to jump and select from the current index to the new index. %friendly%`n
    Gui, Add, Edit, y+10 w%EditWid% r1 limit9025 -multi -wantTab -wrap vnewJumpIndex, % currentFileIndex

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gJumpIndexBTNaction, &Jump to index
    Gui, Add, Button, x+5 hp w90 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Jump to index #: %appTitle%
}

jumpIndexBTNaction() {
  GuiControlGet, newJumpIndex
  newJumpIndex := Trim(newJumpIndex)
  If InStr(newJumpIndex, "s")
     selectionMode := 1
  Else If InStr(newJumpIndex, "f")
     framesMode := 1

  newJumpIndex := StrReplace(newJumpIndex, "s")
  newJumpIndex := StrReplace(newJumpIndex, "f")
  If IsNumber(newJumpIndex) && (newJumpIndex>=1)
  {
     CloseWindow()
     If (framesMode=1)
     {
        desiredFrameIndex := newJumpIndex
        RefreshImageFile()
        SoundBeep , 900, 100
        Return
     }

     If (newJumpIndex>maxFilesIndex)
        newJumpIndex := maxFilesIndex

     If (selectionMode=1)
     {
        dropFilesSelection(1)
        selectFilesRange(currentFileIndex, newJumpIndex, 1)
     }

     currentFileIndex := newJumpIndex
     dummyTimerDelayiedImageDisplay(50)
  }
}

SaveClipboardImage(dummy:=0) {
   Static lastInvoked := 1

   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (StrLen(UserMemBMP)>2) || (dummy="yay" && thumbsDisplaying!=1)
      good2go := 1

   If (good2go!=1 || thumbsDisplaying=1)
   {
      SaveFilesList()
      Return
   }

   initFIMGmodule()
   If (dummy="yay")
   {
      imgPath := getIDimage(currentFileIndex)
      imgPath := StrReplace(imgPath, "||")
   }

   defaultu := (dummy="yay") ? imgPath : prevFileSavePath
   If (A_TickCount - lastInvoked < 1200)
      defaultu := prevFileSavePath

   If (thisIMGisDownScaled=1 && AutoDownScaleIMGs=1)
      msgBoxWrapper(appTitle ": WARNING" , "PLEASE NOTE! The image you are about to save is downscaled by Quick Picto Viewer. Press F5 to reload the original and then save the modified image, at original dimensions.`n`nTo disabled altogether downscaling, press Ctrl+Q in the main window.", 0, 0, "exclamation")
   file2save := openFileDialogWrapper("S18", defaultu, "Save image as...", "Images (" dialogSaveFptrn ")")
   If file2save
   {
      zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
      zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, nExt)
      If !nExt
         file2save .= "." oExt

      If !RegExMatch(file2save, saveTypesRegEX)
      {
         msgBoxWrapper(appTitle ": ERROR", "Please save the file using one of the supported file format extensions: " saveTypesFriendly ". ", 0, 0, "error")
         Return
      }

      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "This format is currently unsupported, because the FreeImage library failed to properly initialize.`n`n" OutFileName, 0, 0, "error")
         Return
      }

      If (activateImgSelection=1)
      {
         msgResult := msgBoxWrapper(appTitle ": Crop image on save", "An area of the image is selected in the viewport. Would you like to save only the selected area? By answering no, the entire image will be saved.", 3, 0, "question")
         If (msgResult="Yes")
            allowCropping := 1
         Else If (msgResult="Cancel")
            Return

         If (allowCropping!=1)
            toggleImgSelection()
      }
      showTOOLtip("Please wait, saving image...`n" OutFileName)
      If (file2save=defaultu && defaultu=imgPath && gdiBitmap)
         destroyGDIfileCache(0, 1)

      If gdiBitmap
         dummyBMP := Gdip_CloneBitmap(gdiBitmap)

      prevFileSavePath := OutDir
      INIaction(1, "prevFileSavePath", "General")
      lastInvoked := A_TickCount
      If dummyBMP
      {
         Gdip_GetImageDimensions(dummyBMP, imgW, imgH)
         r := coreResizeIMG(imgPath, imgW, imgH, file2save, 1, 0, 0, dummyBMP, imgW, imgH, 0)
      } Else r := "err"

      If r
         showTOOLtip("Failed to save image file...`n" OutFileName "`n" OutDir "\")
      Else
         showTOOLtip("Image file saved...`n" OutFileName "`n" OutDir "\")

      SoundBeep, % r ? 300 : 900, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      SetTimer, ResetImgLoadStatus, -50
   }
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

   file2save := openFileDialogWrapper("S2", prevFileMovePath "\this-folder", "Please select destination folder...", "All files (*.*)")
   If file2save
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
       maxuIndex := lineArr.Count()
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
       newEntry := Trim(newEntry)
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

    createSettingsGUI(9, "CopyMovePanelWindow")
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
    setImageLoading()
    historyList := readRecentEntries()
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

    getSelectedFiles(0, 1)
    If (markedSelectFile>1)
       infoSelection := "Selected files: " markedSelectFile ". "

    overwriteConflictingFile := 0
    Gui, +Delimiter`n
    Gui, Add, Text, x15 y15 Section, %infoSelection%Please select or type destination folder...
    Gui, Add, ComboBox, xs y+10 w%EditWid% gCopyMoveComboAction r12 Simple vUsrEditFileDestination, % finalListu
    Gui, Add, Checkbox, y+10 Checked%overwriteConflictingFile% voverwriteConflictingFile, When file name(s) collide, overwrite file(s) found in selected folder

    ToolTip,,,,2
    SetTimer, ResetImgLoadStatus, -50
    btnName := (UsrCopyMoveOperation=2) ? "Move" : "Copy"
    Gui, Add, Button, xs y+20 h30 w%btnWid% gChooseFilesDest, &Choose a new folder
    Gui, Add, DropDownList, x+5 w%btnWid% gchangeCopyMoveAction AltSubmit Choose%UsrCopyMoveOperation% vUsrCopyMoveOperation, Action...`nMove file(s)`nCopy file(s)
    Gui, Add, Button, xs y+20 h30 w%btnWid% Default gOpenQuickItemDir vBtnCpyMv, &Proceed...
    Gui, Add, Button, x+5 hp w%btnWid% gEraseCopyMoveHisto, Erase &history
    Gui, Add, Button, x+5 hp w80 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, %btnName% file(s) to...: %appTitle%
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
  folderu := Trim(folderu, "\")
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

      folderu := Trim(A_LoopField)
      folderu := Trim(folderu, "\")
      If (StrLen(folderu)<4 || !FileExist(folderu) || !InStr(folderu, ":\"))
         Continue

      countItemz++
      IniWrite, % folderu, % mainSettingsFile, RecentFDestinations, E%countItemz%
  }
}

QuickMoveFile2Dest(finalDest) {
    If (slideShowRunning=1)
       ToggleSlideShowu()
 
    getSelectedFiles(0, 1)
    If (markedSelectFile>1)
    {
       batchCopyMoveFile(finalDest)
       Return
    }

    Sleep, 2
    file2rem := getIDimage(currentFileIndex)
    zPlitPath(file2rem, 0, OldOutFileName, OldOutDir)
    If !FileExist(file2rem)
    {
       showTOOLtip("File does not exist or access denied...`n" OldOutFileName "`n" OldOutDir "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 300, 100 
       SetTimer, ResetImgLoadStatus, -25
       Return
    }

    If (OldOutDir=finalDest)
    {
       showTOOLtip("Destination equals to initial location...`nOperation ignored.`n" finalDest "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SetTimer, ResetImgLoadStatus, -25
       Return
    }

    destroyGDIfileCache(0)
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
             SetTimer, ResetImgLoadStatus, -25
             Return
          }
       } Else
       {
          showTOOLtip("A file with the same name exists in the destination folder.`nOperation aborted...`n" OldOutFileName "`n" finalDest "\")
          SoundBeep, 300, 100
          SetTimer, RemoveTooltip, % -msgDisplayTime
          SetTimer, ResetImgLoadStatus, -25
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
       INIaction(1, "prevFileMovePath", "General")
       RecentCopyMoveManager(finalDest)
       actName := (UsrCopyMoveOperation=2) ? "moved" : "copied"
       showTOOLtip("File " actName " to...`n" OldOutFileName "`n" finalDest "\")
       If (UsrCopyMoveOperation=2)
          resultedFilesList[currentFileIndex] := [file2save]
       If (StrLen(filesFilter)>1 && UsrCopyMoveOperation=2)
          bckpResultedFilesList[filteredMap2mainList[currentFileIndex]] := [file2save]
       Sleep, 5
       ; RecentFilesManager(0, 2)
    } Else
    {
       actName := (UsrCopyMoveOperation=2) ? "move" : "copy"
       showTOOLtip(OldOutFileName "`nFailed to  " actName " file to...`n" finalDest "\")
       SoundBeep, 300, 100
    }

    SetTimer, RemoveTooltip, % -msgDisplayTime
    SetTimer, ResetImgLoadStatus, -25
}

batchCopyMoveFile(finalDest) {
   Static lastInvoked := 1
   filesElected := getSelectedFiles(0, 1)
   If (A_TickCount - lastInvoked > 29500) || (filesElected>100)
   {
      wording := (UsrCopyMoveOperation=2) ? "MOVE" : "COPY"
      msgResult := msgBoxWrapper(appTitle ": Confirmation", "Please confirm you want to " wording " the selected files.`n`nSelected " filesElected " files`nDestination: " finalDest "\", 4, 0, "question")
      If (msgResult="Yes")
         good2go := 1
      Else
         Return
   }

   lastInvoked := A_TickCount
   overwriteFiles := overwriteConflictingFile
   friendly := (UsrCopyMoveOperation=2) ? "Moving " : "Copying "
   showTOOLtip(friendly filesElected " files to`n" finalDest "\`nPlease wait...")
   prevFileMovePath := finalDest
   RecentCopyMoveManager(finalDest)
   destroyGDIfileCache()
   Sleep, 25
   prevMSGdisplay := A_TickCount
   doStartLongOpDance()
   countTFilez := filezMoved := 0
   ; RecentFilesManager(0, 2)
   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      changeMcursor()
      thisFileIndex := A_Index
      file2rem := getIDimage(thisFileIndex)
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

      If !wasError
      {
         filezMoved++
         If (UsrCopyMoveOperation=2)
            resultedFilesList[thisFileIndex] := [file2save, 1]

         If (StrLen(filesFilter)>1 && UsrCopyMoveOperation=2)
            bckpResultedFilesList[filteredMap2mainList[thisFileIndex]] := [file2save, 1]
      } Else If (skippedFile!=1)
         someErrors := "`nErrors occured during file operations..."

      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }
   }

   ForceRefreshNowThumbsList()
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

   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
   lastInvoked := A_TickCount
}

batchConvert2format() {
   If AnyWindowOpen
      CloseWindow()

   filesElected := getSelectedFiles(0, 1)
   setImageLoading()
   showTOOLtip("Converting to ." rDesireWriteFMT A_Space filesElected " files, please wait...")

   filesPerCore := filesElected//realSystemCores
   If (filesPerCore<2 && realSystemCores>1)
   {
      systemCores := filesElected//2
      filesPerCore := filesElected//systemCores
   } Else systemCores := realSystemCores

   destroyGDIfileCache()
   backCurrentSLD := CurrentSLD
   mustDoMultiCore := (allowMultiCoreMode=1 && systemCores>1 && filesPerCore>1) ? 1 : 0
   If (!FileExist(ResizeDestFolder) && ResizeUseDestDir=1)
      FileCreateDir, % ResizeDestFolder

   If (mustDoMultiCore=1)
   {
      setPriorityThread(-2)
      infoResult := WorkLoadMultiCoresConvertFormat(filesElected)
      setPriorityThread(0)
      If (infoResult!="single-core")
         Return
   }

   CurrentSLD := ""
   prevMSGdisplay := A_TickCount
   startOperation := A_TickCount
   doStartLongOpDance()
   skipDeadFiles := theseFailures := failedFiles := countTFilez := filesConverted := 0
   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      thisFileIndex := A_Index
      file2rem := getIDimage(thisFileIndex)
      If (RegExMatch(file2rem, "i)(.\.(" rDesireWriteFMT "))$") || InStr(file2rem, "||") || !file2rem)
      {
         skippedFiles++
         Continue
      }

      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         zeitOperation := A_TickCount - startOperation
         percDone := " ( " Round((countTFilez / filesElected) * 100) "% )"
         percLeft := (1 - countTFilez / filesElected) * 100
         zeitLeft := (zeitOperation/countTFilez) * filesElected - zeitOperation
         etaTime := "`nEstimated time left: " SecToHHMMSS(Round(zeitLeft/1000, 3))
         etaTime .= "`nElapsed time: " SecToHHMMSS(Round(zeitOperation/1000, 3)) percDone
         If (failedFiles>0)
            etaTime .= "`nFor " failedFiles " files, the format conversion failed..."
         If (theseFailures>0)
            etaTime .= "`nUnable to remove " theseFailures " original files after format conversion..."
         If (skippedFiles>0)
            etaTime .= "`n" skippedFiles " files were skipped..."

         showTOOLtip("Converting to ." rDesireWriteFMT A_Space countTFilez "/" filesElected " files, please wait..." etaTime)
         prevMSGdisplay := A_TickCount
      }

      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }

      countTFilez++
      zPlitPath(file2rem, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
      destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
      file2save := destImgPath "\" OutNameNoExt "." rDesireWriteFMT
      If (FileExist(file2save) && userOverwriteFiles=0)
      {
         skippedFiles++
         Continue
      } Else If FileExist(file2save)
         FileSetAttrib, -R, %file2save%

      Sleep, 0
      changeMcursor()
      pBitmap := LoadBitmapFromFileu(file2rem)
      If !pBitmap
      {
         failedFiles++
         Continue
      }

      rawFmt := Gdip_GetImageRawFormat(pBitmap)
      If (rawFmt="JPEG")
         RotateBMP2exifOrientation(pBitmap)

      changeMcursor()
      r := Gdip_SaveBitmapToFile(pBitmap, file2save, 90)
      If (r=-2 || r=-1)
         r := SaveFIMfile(file2save, pBitmap)

      If r
         failedFiles++
      Else
         filesConverted++

      Gdip_DisposeImage(pBitmap, 1)
      If (OnConvertKeepOriginals!=1 && !r)
      {
         FileSetAttrib, -R, %file2rem%
         Sleep, 2
         FileRecycle, %file2rem%
         If ErrorLevel
            theseFailures++

         resultedFilesList[thisFileIndex] := [file2save, 1]
         If StrLen(filesFilter)>1
            bckpResultedFilesList[filteredMap2mainList[thisFileIndex]] := [file2save, 1]
      }
   }
   If (failedFiles>0)
      someErrors := "`nFor " failedFiles " files, the format conversion failed..."
   If (theseFailures>0)
      someErrors .= "`nUnable to remove " theseFailures " original files after format conversion..."
   If (skippedFiles>0)
      someErrors .= "`n" skippedFiles " files were skipped..."

   CurrentSLD := backCurrentSLD
   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
      showTOOLtip("Operation aborted. " filesConverted " out of " filesElected " selected files were converted to ." rDesireWriteFMT " until now..." someErrors)
   Else
      showTOOLtip("Finished converting to ." rDesireWriteFMT A_Space filesConverted " out of " filesElected " selected files" someErrors)

   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

convert2format() {
  Critical, on
  If (currentFileIndex=0)
     Return "err"

  file2rem := getIDimage(currentFileIndex)
  If RegExMatch(file2rem, "i)(.\.(" rDesireWriteFMT "))$")
  {
     showTOOLtip("The image file seems to be already in the given file format: ." rDesireWriteFMT)
     SoundBeep, 300, 100
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return "err"
  }

  If (slideShowRunning=1)
     ToggleSlideShowu()

  destroyGDIfileCache(0)
  file2rem := StrReplace(file2rem, "||")
  zPlitPath(file2rem, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
  Sleep, 1
  setImageLoading()
  ToolTip, Please wait... converting file...
  If (!FileExist(ResizeDestFolder) && ResizeUseDestDir=1)
     FileCreateDir, % ResizeDestFolder

  destImgPath := (ResizeUseDestDir=1) ? ResizeDestFolder : OutDir
  file2save := destImgPath "\" OutNameNoExt "." rDesireWriteFMT
  If (FileExist(file2save) && userOverwriteFiles=0)
  {
     ToolTip
     showTOOLtip("A file with the same name already exists in the destination folder...")
     SoundBeep, 300, 100
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return "err"
  } Else If FileExist(file2save)
     FileSetAttrib, -R, %file2save%

  If AnyWindowOpen
     CloseWindow()

  pBitmap := LoadBitmapFromFileu(file2rem)
  rawFmt := Gdip_GetImageRawFormat(pBitmap)
  If (rawFmt="JPEG")
     RotateBMP2exifOrientation(pBitmap)

  r := Gdip_SaveBitmapToFile(pBitmap, file2save, 85)
  If (r=-2 || r=-1)
     r := SaveFIMfile(file2save, pBitmap)

  Gdip_DisposeImage(pBitmap, 1)
  ToolTip
  SetTimer, ResetImgLoadStatus, -50
  If r
  {
     showTOOLtip("Failed to convert file...`n" OutFileName "`n" OutDir "\")
     SoundBeep, 300, 100
  } Else
  {
     showTOOLtip("File converted succesfully to ." rDesireWriteFMT "...`n" OutNameNoExt "." rDesireWriteFMT "`n" destImgPath "\")
     SoundBeep, 900, 100
  }

  If (OnConvertKeepOriginals!=1 && !r)
  {
     Try FileSetAttrib, -R, %file2rem%
     Sleep, 1
     FileRecycle, %file2rem%
     If ErrorLevel
        showTOOLtip("Failed to remove original file. But the file was converted succesfully to ." rDesireWriteFMT "...`n" OutNameNoExt "." rDesireWriteFMT "`n" destImgPath "\")
     resultedFilesList[currentFileIndex] := [file2save]
     If StrLen(filesFilter)>1
        bckpResultedFilesList[filteredMap2mainList[currentFileIndex]] := [file2save]
  }
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

OpenFolders() {
   If (AnyWindowOpen || imageLoading=1)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

   SelectedDir := openFoldersDialogWrapper(2, "*" prevOpenFolderPath, "Select the folder with images. All images found in sub-folders will be loaded as well.")
   If (SelectedDir)
   {
      newStaticFoldersListCache := ""
      prevOpenFolderPath := SelectedDir
      INIaction(1, "prevOpenFolderPath", "General")
      coreOpenFolder(SelectedDir, 1, 1)
      If (maxFilesIndex>0)
         SLDtypeLoaded := 1
      Else
         resetMainWin2Welcome()
   }
}

openFoldersDialogWrapper(optionz, startPath, msg) {
   If AnyWindowOpen
   {
      Gui, SettingsGUIA: +OwnDialogs
      FileSelectFile, file2save, % optionz, % startPath, % msg, % pattern
      If (!ErrorLevel && StrLen(file2save)>2)
         r := file2save
      lastLongOperationAbort := A_TickCount
      Return r
   } Else
   {
      r := interfaceThread.ahkFunction("openFoldersDialogWrapper", optionz, startPath, msg)
      lastLongOperationAbort := A_TickCount
      Return r
   }
}

renewCurrentFilesList() {
  prevRandyIMGs := []
  markedSelectFile := maxFilesIndex := 0
  activateImgSelection := editingSelectionNow := prevRandyIMGnow := 0
  resultedFilesList := []
  ForceRefreshNowThumbsList()
  currentFileIndex := 1
  destroyGDIfileCache()
  discardViewPortCaches()
  userSearchString := ""
  UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
  If hSNDmedia
     StopMediaPlaying()
}

coreOpenFolder(thisFolder, doOptionals:=1, openFirst:=0) {
   testThis := StrReplace(thisFolder, "|")
   testThis := FileExist(testThis)
   If (StrLen(thisFolder)>3 && InStr(testThis, "D"))
   {
      If (A_TickCount - scriptStartTime>350)
         CloseWindow()

      usrFilesFilteru := filesFilter := CurrentSLD := ""
      setWindowTitle("Loading files, please wait", 1)
      renewCurrentFilesList()
      ; activeSQLdb.Exec("DELETE FROM images;")
      r := GetFilesList(thisFolder "\*", "-", openFirst)
      If (maxFilesIndex<1 || !maxFilesIndex)
      {
         If !CurrentSLD
            resetMainWin2Welcome()
         Else
            FadeMainWindow()

         showTOOLtip("ERROR: Found no recognized image files in the folder...`n" thisFolder "\")
         SoundBeep, 300, 100
         setWindowTitle(appTitle, 1)
         SetTimer, RemoveTooltip, % -msgDisplayTime
         Return
      }

      GenerateRandyList()
      mustGenerateStaticFolders := 1
      DynamicFoldersList := thisFolder "`n"
      ; addDynamicFolderSQLdb(thisFolder, 1, "dynamicfolders")
      CurrentSLD := thisFolder
      RecentFilesManager()
      If (r=1)
      {
         clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
         RemoveTooltip()
      } Else SetTimer, RemoveTooltip, % -msgDisplayTime

      If (doOptionals=1)
      {
         If (maxFilesIndex>0 && r!=1)
            RandomPicture()
         Else
            dummyTimerDelayiedImageDisplay(25)
      }
   } Else
   {
      setWindowTitle(appTitle, 1)
      If (!CurrentSLD || maxFilesIndex<2 || !maxFilesIndex)
         resetMainWin2Welcome()
      Else
         FadeMainWindow()

      showTOOLtip("ERROR: The folder seems to be inexistent...`n" thisFolder "\")
      SoundBeep, 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

addDynamicFolderSQLdb(whichFolder, renewList, whichTable) {
    If (renewList=1)
       activeSQLdb.Exec("DELETE FROM dynamicfolders;")

    FileGetTime, fileMdate, % StrReplace(whichFolder, "|"), M
    If !FileExist(whichFolder)
       Return

    SQLstr := "INSERT INTO " whichTable " (imgfolder, fmodified) VALUES ('" whichFolder "', '" fileMdate "');"
    If !activeSQLdb.Exec(SQLStr)
    {
       stringA := whichFolder
       activeSQLdb.EscapeStr(stringA)
       ; MsgBox, % stringA "--" stringB 
       SQLstr := "INSERT INTO " whichTable " (imgfolder, fmodified) VALUES (" stringA ", '" fileMdate "');"
       If !activeSQLdb.Exec(SQLStr)
          Sleep, 0
    }
}

addStaticFolderSQLdb(whichFolder, fileMdate, renewList) {
    If (renewList=1)
       activeSQLdb.Exec("DELETE FROM staticfolders;")

    SQLstr := "INSERT INTO staticfolders (imgfolder, fmodified) VALUES ('" whichFolder "', '" fileMdate "');"
    If !activeSQLdb.Exec(SQLStr)
    {
       stringA := whichFolder
       activeSQLdb.EscapeStr(stringA)
       ; MsgBox, % stringA "--" stringB 
       SQLstr := "INSERT INTO staticfolders (imgfolder, fmodified) VALUES (" stringA ", '" fileMdate "');"
       If !activeSQLdb.Exec(SQLStr)
          Sleep, 0
    }
}

RefreshImageFileAction() {
   If (thumbsDisplaying!=1)
   {
      discardViewPortCaches()
      UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
      If (AutoDownScaleIMGs=1)
         AutoDownScaleIMGs := 2
      RefreshImageFile()
      thisIMGisDownScaled := 0
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

  If RegExMatch(CurrentSLD, sldsPattern)
  {
     currentFileIndex := 1
     OpenSLD(CurrentSLD, 1)
     RandomPicture()
  } Else If StrLen(CurrentSLD)>3
     RegenerateEntireList()
     ; coreOpenFolder(CurrentSLD)
}

OpenRawFiles() {
   OpenDialogFiles("raws")
}

OpenDialogFiles(dummy:=0) {
    If (AnyWindowOpen || imageLoading=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    If (dummy="raws")
    {
       winTitle := "Open Camera RAW files..."
       pattern := "Camera RAW files (" openFptrn3 ";*.sti;*.sld)"
    } Else
    {
       winTitle := "Open image(s) or a slideshow file..."
       pattern := "Images (" openFptrn1 ";" openFptrn2 ";" openFptrn4 ";*.sld)"
    }
    SelectImg := openFileDialogWrapper("M2", prevOpenFolderPath, winTitle, pattern)
    If !SelectImg
       Return

    Loop, Parse, SelectImg, `n
    {
       If (A_Index=1)
          SelectedDir := A_LoopField
       Else If (A_Index=2)
          imgPath := SelectedDir "\" A_LoopField
       Else If (A_Index>2)
          Break
    }

   If SelectedDir
   {
      newStaticFoldersListCache := ""
      prevOpenFolderPath := SelectedDir
      INIaction(1, "prevOpenFolderPath", "General")
      If RegExMatch(imgPath, sldsPattern)
      {
         OpenSLD(imgPath)
         Return
      }

      If (SLDtypeLoaded=3)
      {
         SLDtypeLoaded := 0
         activeSQLdb.CloseDB()
      }

      coreOpenFolder("|" SelectedDir, 0, 0)
      If (RegExMatch(imgPath, RegExFilesPattern) && maxFilesIndex>0)
      {
         SLDtypeLoaded := 1
         currentFileIndex := detectFileID(imgPath)
         IDshowImage(currentFileIndex)
         Return
      } Else If (maxFilesIndex>0)
      {
         SLDtypeLoaded := 1
         RandomPicture()
      } Else resetMainWin2Welcome()
   }
}

OpenArgFile(inputu) {
    setImageLoading()
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
    setWindowTitle(winTitle, 1)
    SetTimer, RemoveTooltip, -250
    SetTimer, ResetImgLoadStatus, -50
    If (maxFilesIndex>0)
       SLDtypeLoaded := 1
    Else resetMainWin2Welcome()
    ; IDshowImage(currentFileIndex)
}

addNewFile2list() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    pattern := "Images (" openFptrn1 ";" openFptrn2 ";" openFptrn3 ")"
    SelectImg := openFileDialogWrapper("M3", prevOpenFolderPath, "Add image file(s) to the list...", pattern)
    If !SelectImg
       Return "cancel"

    If AnyWindowOpen
       CloseWindow()
    Sleep, 25
    showTOOLtip("Please wait, processing files list...")
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
      INIaction(1, "prevOpenFolderPath", "General")
      coreAddNewFiles(imgsListu, countFiles, SelectedDir)
      currentFileIndex := maxFilesIndex - 1
      dummyTimerDelayiedImageDisplay(50)
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

coreAddNewFiles(imgsListu, countFiles, SelectedDir) {
    If CurrentSLD
       dropFilesSelection(1)
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
          resultedFilesList[maxFilesIndex] := [line]
       }
    }

    If (!CurrentSLD && maxFilesIndex>0)
       CurrentSLD := SelectedDir "\newFile.SLD"

    SetTimer, RemoveTooltip, % -msgDisplayTime
}

addNewFolder2list() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   SelectImg := openFileDialogWrapper("S2", prevOpenFolderPath "\this-folder", "Add new folder(s) to the list", "All files (*.*)")
   If !SelectImg
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
   If SelectedDir
   {
      msgResult := msgBoxWrapper(appTitle, "Do you want to scan for files recursively, through all its subfolders?", 3, 0, "question")
      If (msgResult="no")
         isRecursive := "|"
      Else If (msgResult="cancel")
         Return "cancel"

      If AnyWindowOpen
         CloseWindow()
      Sleep, 1
      prevOpenFolderPath := SelectedDir
      coreAddNewFolder(isRecursive SelectedDir, 1)
      If RegExMatch(CurrentSLD, sldsPattern)
      {
         FileReadLine, firstLine, % CurrentSLD, 1
         If (!InStr(firstLine, "[General]") || SLDcacheFilesList!=1)
            good2go := "null"
      } Else good2go := "null"

      modus := isRecursive ? 1 : 0
      If (mustGenerateStaticFolders=0 && good2go!="null" && RegExMatch(CurrentSLD, sldsPattern))
         updateCachedStaticFolders(SelectedDir, modus)
      Else mustGenerateStaticFolders := 1

      listu := DynamicFoldersList "`n" isRecursive SelectedDir "`n"
      Sort, listu, UD`n
      DynamicFoldersList := listu
      INIaction(1, "prevOpenFolderPath", "General")
      If !CurrentSLD
      {
         CurrentSLD := SelectedDir "\newFile.SLD"
         RandomPicture()
      }
   }
}

coreAddNewFolder(SelectedDir, remAll, noRandom:=0) {
    backCurrentSLD := CurrentSLD
    CurrentSLD := ""
    markedSelectFile := 0
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
    SoundBeep, 900, 100
    CurrentSLD := backCurrentSLD
    If (noRandom=1)
    {
       currentFileIndex := maxFilesIndex - 1
       IDshowImage(currentFileIndex)
    } Else RandomPicture()
}

detectFileID(imgPath) {
    Loop, % maxFilesIndex + 1
    {
       r := getIDimage(A_Index)
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

GuiDroppedFiles(imgsListu, foldersListu, sldFile, countFiles) {
   If sldFile
   {
      OpenSLD(sldFile)
      Return
   }
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (CurrentSLD || maxFilesIndex>1)
      msgResult := msgBoxWrapper(appTitle, "Would you like to import dropped file(s)/folder(s) to the current files list? By answering no, a new files list will be created.", 3, 0, "question")

   If (msgResult="cancel")
   {
      Return
   } Else If (msgResult="no")
   {
      mainFoldersListu := CurrentSLD := DynamicFoldersList := ""
      renewCurrentFilesList()
      resetMainWin2Welcome()
   }

   If StrLen(foldersListu)>3
   {
      mainFoldersListu := InStr(DynamicFoldersList, "|hexists|") ? coreLoadDynaFolders(CurrentSLD) : DynamicFoldersList
      doStartLongOpDance()
      dropFilesSelection(1)
      showTOOLtip("Opening folders, please wait...")
      If StrLen(filesFilter)>1
      {
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      Loop, Parse, foldersListu,`n
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
          If (SLDtypeLoaded=3)
             addDynamicFolderSQLdb(linea, 0, "dynamicfolders")
      }

      If (stuffAdded=1)
      {
         newStaticFoldersListCache := ""
         mustGenerateStaticFolders := 1
         GenerateRandyList()
      }

      If !CurrentSLD
      {
         SLDtypeLoaded := 2
         CurrentSLD := lastOne "\newFile.SLD"
      }
      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, 900, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      RandomPicture()
   } Else If (imgsListu && countFiles=1)
   {
      imgPath := Trim(imgsListu)
      zPlitPath(imgPath, 0, OutFileName, OutDir)
      If !OutDir
         Return

      showTOOLtip("Opening file...`n" imgPath)
      newStaticFoldersListCache := ""
      dropFilesSelection(1)
      If StrLen(filesFilter)>1
      {
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      If (msgResult!="no")
      {
         prevMaxFilesIndex := maxFilesIndex
         prevFoldersDyna := DynamicFoldersList
         bckpResultedFilesList := resultedFilesList.Clone()
      }

      If (SLDtypeLoaded=3)
      {
         SLDtypeLoaded := 0
         activeSQLdb.CloseDB()
      }

      coreOpenFolder("|" OutDir, 0)
      If prevMaxFilesIndex
      {
         DynamicFoldersList .= prevFoldersDyna
         Loop, % prevMaxFilesIndex
         {
             r := bckpResultedFilesList[A_Index, 1]
             If (r && !InStr(r, "||"))
             {
                maxFilesIndex++
                resultedFilesList[maxFilesIndex, 1] := r
             }
         }
         bckpResultedFilesList := []
      }

      SetTimer, RemoveTooltip, % -msgDisplayTime
      If (maxFilesIndex>0)
      {
         SLDtypeLoaded := 1
         currentFileIndex := detectFileID(imgPath)
         IDshowImage(currentFileIndex)
      } Else resetMainWin2Welcome()
   } Else If (imgsListu && countFiles>1)
   {
      coreAddNewFiles(imgsListu, countFiles, prevOpenFolderPath)
      mustGenerateStaticFolders := 1
      GenerateRandyList()
      SetTimer, ResetImgLoadStatus, -50
      SoundBeep, 900, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      currentFileIndex := maxFilesIndex - 1
      dummyTimerDelayiedImageDisplay(50)
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

dummyShowToolTip() {
   showTOOLtip("nully")
}

showTOOLtip(msg) {
   Critical, on
   Static prevMsg
   If (msg="nully" && prevMsg)
      msg := prevMsg

   prevMsg := msg
   If (noTooltipMSGs=0 || thumbsDisplaying=1)
   {
      TooltipCreator(msg)
      If (AnyWindowOpen>0 && WinActive("A")=hSetWinGui)
      {
         GetPhysicalCursorPos(mX, mY)
         ToolTip, % msg, % mX + 25, % mY + 25
      } Else If (AnyWindowOpen>0)
         ToolTip
   } Else
   {
      msg := StrReplace(msg, "`n", "  ")
      setWindowTitle(msg, 1)
   }
}

RemoveTooltip() {
   Tooltip
   TooltipCreator(1, 1)
   If (noTooltipMSGs=1)
   {
      clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
      winTitle := (CurrentSLD) ? pVwinTitle : appTitle
      setWindowTitle(winTitle, 1)
   }
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
  RunWait, *RunAs "%mainCompiledPath%\regFiles\runThis.bat"
  Sleep, 5
  FileDelete, %mainCompiledPath%\regFiles\*.reg
  FileDelete, %mainCompiledPath%\regFiles\*.bat
  msgResult := msgBoxWrapper(appTitle, appTitle " was now associated with common image file formats. Would you like to associate it with all the 85 supported file formats?", 4, 0, "question")
  If (msgResult="yes")
  {
     Loop, Parse, allFormats, "|"
     {
         If !A_LoopField
            Continue
 
         FileAssociate("QPVimage." A_LoopField,"." A_LoopField, fullPath2exe,,1)
     }
 
     Sleep, 25
     RunWait, *RunAs "%mainCompiledPath%\regFiles\runThis.bat"
     Sleep, 5
     FileDelete, %mainCompiledPath%\regFiles\*.reg
     FileDelete, %mainCompiledPath%\regFiles\*.bat
  }
}

restartAppu() {
   ; writeMainSettings()
   If A_IsCompiled
      Run, "%fullPath2exe%"
   Else
      Run, "%A_ScriptFullPath%"

   TrueCleanup(0)
   Sleep, 5
   ExitApp
}

InitGuiContextMenu() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   DestroyGIFuWin()
   SetTimer, BuildMenu, -5
   ; WinActivate, ahk_id %PVhwnd%
}

createMenuCurrentFile() {
   If (thumbsDisplaying!=1)
      Menu, PVtFile, Add, &Save image as...`tCtrl+Shift+S, BtnSaveIMGadjustPanel
   If (thumbsDisplaying!=1 && activateImgSelection!=1)
      Menu, PVtFile, Add, &Copy image to clipboard`tCtrl+C, CopyImage2clip
   Menu, PVtFile, Add, &Copy file path(s) to clipboard`tShift+C, CopyImagePath
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, &Open with external app`tO, OpenThisFileMenu
   Menu, PVtFile, Add, &Explore containing folder`tCtrl+E, OpenThisFileFolder
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, Edit image caption`tShift+N, PanelEditImgCaption
   Menu, PVtFile, Add, Select / deselect file`tTab, MenuMarkThisFileNow

   file2rem := getIDimage(currentFileIndex)
   Menu, PVtFile, Add, &Convert file format(s) to...`tCtrl+K, PanelFileFormatConverter
   If (RegExMatch(file2rem, "i)(.\.(jpg|jpeg))$") || markedSelectFile)
      Menu, PVtFile, Add, &JPEG lossless operations`tK, PanelJpegPerformOperation
   Menu, PVtFile, Add, &Resize/rotate/crop image(s)`tCtrl+R, PanelResizeImageWindow
   Menu, PVtFile, Add, &Auto-crop image(s)`tY, PanelImgAutoCrop
   Menu, PVtFile, Add, &Delete file(s)`tDelete, DeletePicture
   Menu, PVtFile, Add, &Rename file(s)`tF2, PanelRenameThisFile
   If markedSelectFile
      Menu, PVtFile, Add, &Rename active file`tShift+F2, SingularRenameFile
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Move file(s) to...`tM, InvokeMoveFiles
   Menu, PVtFile, Add, &Copy file(s) to...`tC, InvokeCopyFiles
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Information`tAlt+Enter, ShowImgInfosPanel
}

BuildMenu() {
   Static lastInvoked := 1
   If AnyWindowOpen
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
   createMenuCurrentFile()
   Global lastWinDrag := A_TickCount
   ForceRegenStaticFolders := 0
   sliSpeed := Round(slideShowDelay/1000, 2) " sec."
   Menu, PVslide, Add, &Start slideshow`tSpace, dummyInfoToggleSlideShowu
   Menu, PVslide, Add, Smoot&h transitions, ToggleSlidesTransitions
   Menu, PVslide, Add, &Easy slideshow stopping, ToggleEasySlideStop
   Menu, PVslide, Add, &Wait for GIFs to play once, ToggleGIFsPlayEntirely
   Menu, PVslide, Add, De&fine slideshow duration`tShift+[`,], PanelDefineEntireSlideshowLength
   Menu, PVslide, Add, % EstimateSlideShowLength(1), dummy
   Menu, PVslide, Disable, % EstimateSlideShowLength(1)
   Menu, PVslide, Add,
   Menu, PVslide, Add, &Toggle slideshow mode`tS, SwitchSlideModes
   Menu, PVslide, Add, % DefineSlideShowType(), SwitchSlideModes
   Menu, PVslide, Disable, % DefineSlideShowType()
   Menu, PVslide, Add,
   Menu, PVslide, Add, &Increase speed`tComma [`,], IncreaseSlideSpeed
   Menu, PVslide, Add, &Decrease speed`tDot [.], DecreaseSlideSpeed
   Menu, PVslide, Add, Current speed: %sliSpeed%, DecreaseSlideSpeed
   Menu, PVslide, Disable, Current speed: %sliSpeed%
   If (allowGIFsPlayEntirely=1)
      Menu, PVslide, Check, &Wait for GIFs to play once
   If (doSlidesTransitions=1)
      Menu, PVslide, Check, Smoot&h transitions
   If (minimizeMemUsage=1)
      Menu, PVslide, Disable, Smoot&h transitions
   If (easySlideStoppage=1)
      Menu, PVslide, Check, &Easy slideshow stopping

   infolumosAdjust := (imgFxMode=2 || imgFxMode=3) ? Round(lumosAdjust, 2) : Round(lumosGrayAdjust, 2)
   infoGammosAdjust := (imgFxMode=2 || imgFxMode=3) ? Round(GammosAdjust, 2) : Round(GammosGrayAdjust, 2)
   infoSatAdjust := (imgFxMode=4) ? zatAdjust : Round(satAdjust*100)

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
      Try Menu, PVview, Disable, % defineImgAlign()
      Menu, PVview, Add,
      Menu, PVview, Add, &Toggle color depth`tQ, ToggleImgColorDepth
      Menu, PVview, Add, % defineColorDepth(), ToggleImgColorDepth
      Try Menu, PVview, Disable, % defineColorDepth()
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
      Menu, PVview, Add, Auto-reset image view, ToggleAutoResetImageView
      If (resetImageViewOnChange=1)
         Menu, PVview, Check, Auto-reset image view
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
      Menu, PVnav, Add, Previous &frame`tPage Down, prevDesiredFrame
      Menu, PVnav, Add, Ne&xt frame`tPage Up, nextDesiredFrame
   }

   If (markedSelectFile>1 && thumbsDisplaying!=1)
   {
      Menu, PVnav, Add,
      Menu, PVnav, Add, F&irst selected`tCtrl+Home, jumpToFilesSelBorderFirst
      Menu, PVnav, Add, Pr&evious selected`tCtrl+Left, navSelectedFilesPrev
      Menu, PVnav, Add, Nex&t selected`tCtrl+Right, navSelectedFilesNext
      Menu, PVnav, Add, L&ast selected`tCtrl+End, jumpToFilesSelBorderLast
   }
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Jump at #`tJ, PanelJump2index
   Menu, PVnav, Add, &Random`tShift+Bksp, RandomPicture
   Menu, PVnav, Add, Pre&v. random image`tBksp, PrevRandyPicture

   ; Menu, PVselv, Add, &Relative coordinates, toggleImgSelCoords
   ; Menu, PVselv, Add, 
   ; If (relativeImgSelCoords=1)
   ;    Menu, PVselv, Check, &Relative coordinates
   Menu, PVselv, Add, &Show selection`tD, toggleImgSelection
   If (activateImgSelection=1)
      Menu, PVselv, Check, &Show selection`tD
   Menu, PVselv, Add, &Edit selection`tE, ToggleEditImgSelection
   If (editingSelectionNow=1)
      Menu, PVselv, Check, &Edit selection`tE
   Menu, PVselv, Add, &Drop selection`tCtrl+D, resetImgSelection
   Menu, PVselv, Add, &Reset selection, newImgSelection
   Menu, PVselv, Add, &Select all`tCtrl+A, selectEntireImage
   Menu, PVselv, Add, 
   Menu, PVselv, Add, Transform to s&quare ratio (1:1)`tR, makeSquareSelection
   Menu, PVselv, Add, Ell&ipse selection`tShift+E, toggleEllipseSelection
   Menu, PVselv, Add, Limit selection to image boundaries, toggleLimitSelection
   Menu, PVselv, Add, 
   Menu, PVselv, Add, Sho&w grid, ToggleSelectGrid
   Menu, PVselv, Add, &Copy to clipboard`tCtrl+C, CopyImage2clip
   If (LimitSelectBoundsImg=1)
      Menu, PVselv, Check, Limit selection to image boundaries
   If (showSelectionGrid=1)
      Menu, PVselv, Check, Sho&w grid
   If (EllipseSelectMode=1)
      Menu, PVselv, Check, Ell&ipse selection`tShift+E

   Menu, PVedit, Add, &Paste in place`tCtrl+Shift+V, PanelPasteInPlace
   Menu, PVedit, Add, &Erase / fade area`tDelete, PanelEraseSelectedArea
   Menu, PVedit, Add, &Blur area`tShift+B, PanelBlurSelectedArea
   Menu, PVedit, Add, &Fill area / draw shapes`tAlt+Bksp, PanelFillSelectedArea
   Menu, PVedit, Add, &Draw lines / arcs / selection borders`tShift+L, PanelDrawLines
   Menu, PVedit, Add, &Flip selected horizontally`tH, MenuFlipSelectedAreaH
   Menu, PVedit, Add, &Flip selected vertically`tV, MenuFlipSelectedAreaV
   Menu, PVedit, Add, &Rotate selected area`tAlt+R, PanelRotateSelectedArea
   Menu, PVedit, Add, 
   Menu, PVedit, Add, &Invert colors`tShift+I, InvertSelectedArea
   Menu, PVedit, Add, &Desaturate colors`tShift+G, GraySelectedArea
   Menu, PVedit, Add, &Limit color effects to selection`tShift+U, ApplyColorAdjustsSelectedArea
   Menu, PVedit, Add, 
   Menu, PVedit, Add, &Crop image`tShift+Enter, CropImageViewPort
   Menu, PVedit, Add, &Adjust canvas size, PanelAdjustImageCanvasSize

   StringRight, infoPrevMovePath, prevFileMovePath, 25
   Menu, PVsort, Add, File details, dummy
   Menu, PVsort, Disable, File details
   Menu, PVsort, Add, &Path and name`tCtrl+1, ActSortName
   Menu, PVsort, Add, &Folder path`tCtrl+2, ActSortPath
   Menu, PVsort, Add, &File name`tCtrl+3, ActSortFileName
   Menu, PVsort, Add, &File size`tCtrl+4, ActSortSize
   Menu, PVsort, Add, &Modified date`tCtrl+5, ActSortModified
   Menu, PVsort, Add, &Created date`tCtrl+6, ActSortCreated
   Menu, PVsort, Add
   Menu, PVsort, Add, Image information (slow), dummy
   Menu, PVsort, Disable, Image information (slow)
   Menu, PVsort, Add, &Resolution, PanelResolutionSorting
   Menu, PVsort, Add, &Histogram average, ActSortHistogramAvg
   Menu, PVsort, Add, &Histogram median, ActSortHistogramMedian
   Menu, PVsort, Add, &Similarity (very slow), ActSortSimilarity
   Menu, PVsort, Add, 
   Menu, PVsort, Add, R&everse list`tCtrl+0, ReverseListNow
   Menu, PVsort, Add, R&andomize  list, RandomizeListNow

   defMenuRefresh := RegExMatch(CurrentSLD, sldsPattern) ? "&Reload .SLD file" : "&Refresh opened folder(s)"
   StringRight, defMenuRefreshItm, CurrentSLD, 30
   If defMenuRefreshItm
   {
      Menu, PVfList, Add, %defMenuRefresh%`tShift+F5, RefreshFilesList
      If RegExMatch(CurrentSLD, sldsPattern)
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
      Menu, PVfList, Add, Manage folder(s) list`tAlt+U, PanelDynamicFolderzWindow
   }

   If (maxFilesIndex>2)
   {
      Menu, PVfList, Add, Remove active index entry`tAlt+Delete, InListMultiEntriesRemover
      Menu, PVfList, Add, Modify active index entry`tCtrl+F2, PanelUpdateThisFileIndex
      Menu, PVfList, Add, Auto-remove entries of dead files, ToggleAutoRemEntries
      If (autoRemDeadEntry=1)
         Menu, PVfList, Check, Auto-remove entries of dead files
      Menu, PVfList, Add,
      Menu, PVfList, Add, Save list as slideshow (.SLD)`tCtrl+S, SaveFilesList
      Menu, PVfList, Add, Cache files list in .SLD file, ToggleSLDcache
      If (SLDcacheFilesList=1)
         Menu, PVfList, Check, Cache files list in .SLD file
      Menu, PVfList, Add,
      If (RegExMatch(CurrentSLD, sldsPattern) && SLDhasFiles=1)
         Menu, PVfList, Add, &Clean duplicate/inexistent entries, cleanFilesList
      If (RegExMatch(CurrentSLD, sldsPattern) && StrLen(DynamicFoldersList)>6)
         Menu, PVfList, Add, &Regenerate the entire list, RegenerateEntireList
      If (RegExMatch(CurrentSLD, sldsPattern) && mustGenerateStaticFolders!=1 && SLDcacheFilesList=1)
         Menu, PVfList, Add, &Update files list selectively`tCtrl+U, PanelStaticFolderzManager
      Menu, PVfList, Add, 
      Menu, PVfList, Add, &Search index`tCtrl+F3, PanelSearchIndex
      Menu, PVfList, Add, &Text filtering`tCtrl+F, PanelEnableFilesFilter
      If StrLen(filesFilter)>1
      {
         Menu, PVfList, Check, &Text filtering`tCtrl+F
         If (filesFilter!="||Prev-Files-Selection||")
            Menu, PVfList, Add, &Invert applied filter, invertFilesFilter
      }
      Menu, PVfList, Add,
      If (thumbsDisplaying!=1)
         Menu, PVfList, Add, &Sort by, :PVsort
   }

   Menu, PVperfs, Add, &Limit memory usage, ToggleLimitMemUsage
   Menu, PVperfs, Add, &Allow multi-threaded processing, ToggleMultiCoreSupport
   If (minimizeMemUsage=1)
      Menu, PVperfs, Disable, &Allow multi-threaded processing

   Menu, PVperfs, Add, &High quality image resampling, ToggleImgQuality
   If (thumbsDisplaying!=1)
   {
      Menu, PVperfs, Add, &Downscale images to viewport dimensions`tCtrl+Q, ToggleImgDownScaling
      If (AutoDownScaleIMGs=1)
         Menu, PVperfs, Check, &Downscale images to viewport dimensions`tCtrl+Q
   }
   Menu, PVperfs, Add, &Perform dithering on color depth changes, ToggleImgColorDepthDithering
   Menu, PVperfs, Add, &Load Camera RAW files in high quality, ToggleRAWquality
   If (minimizeMemUsage=1)
      Menu, PVperfs, Check, &Limit memory usage
   If (allowMultiCoreMode=1)
      Menu, PVperfs, Check, &Allow multi-threaded processing
   If (ColorDepthDithering=1)
      Menu, PVperfs, Check, &Perform dithering on color depth changes
   If (userimgQuality=1)
      Menu, PVperfs, Check, &High quality image resampling
   If (userHQraw=1)
      Menu, PVperfs, Check, &Load Camera RAW files in high quality


   Menu, PVprefs, Add, Save settings into a .SLD file, WritePrefsIntoSLD
   Menu, PVprefs, Add, &Never load settings from a .SLD, ToggleIgnoreSLDprefs
   If A_IsCompiled
   {
      Menu, PVprefs, Add, 
      Menu, PVprefs, Add, Associate with .SLD files, associateSLDsNow
      Menu, PVprefs, Add, Associate with image files, associateWithImages
   }

   Menu, PVprefs, Add, 
   Menu, PVprefs, Add, Load an&y image format using FreeImage, ToggleAlwaysFIMus
   ; If (thumbsDisplaying!=1 && CurrentSLD && maxFilesIndex>0)
   Menu, PVprefs, Add, Performance options, :PVperfs
   Menu, PVprefs, Add, 
   If (thumbsDisplaying!=1)
   {
      Menu, PVprefs, Add, Auto-play an&imated GIFs, ToggleAnimGIFsupport
      If (animGIFsSupport=1)
         Menu, PVprefs, Check, Auto-play an&imated GIFs
      If (alwaysOpenwithFIM=1)
         Menu, PVprefs, Disable, Auto-play an&imated GIFs
   }

   Menu, PVprefs, Add, &Prompt before file delete, TogglePromptDelete
   If (askDeleteFiles=1)
      Menu, PVprefs, Check, &Prompt before file delete
   If (MustLoadSLDprefs=0)
      Menu, PVprefs, Check, &Never load settings from a .SLD

   Menu, PVprefs, Add, 
   If InStr(FileExist(thumbsCacheFolder), "D")
      Menu, PVprefs, Add, Erase cached thumbnails, PanelOlderThanEraseThumbsCache
   Menu, PVprefs, Add, Cache / store generated thumbnails, ToggleThumbsCaching
   If (alwaysOpenwithFIM=1)
      Menu, PVprefs, Check, Load an&y image format using FreeImage
   If (enableThumbsCaching=1)
      Menu, PVprefs, Check, Cache / store generated thumbnails

   historyList := readRecentEntries()
   Menu, PVopenF, Add, &Image file(s) or slideshow`tCtrl+O, OpenDialogFiles
   Menu, PVopenF, Add, &Camera RAW file(s)`tAlt+O, OpenRawFiles
   Menu, PVopenF, Add, &Folder(s)`tShift+O, OpenFolders
   Menu, PVopenF, Add,
   If (maxFilesIndex<1 || !CurrentSLD)
      Menu, PVopenF, Add, Insert file(s)`tInsert, addNewFile2list

   If (thumbsDisplaying!=1)
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
      If InStr(A_LoopField, "|") && !RegExMatch(A_LoopField, sldsPattern)
         entryu .= "\" ; entryu
      If !InStr(A_LoopField, "|") && !RegExMatch(A_LoopField, sldsPattern)
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
   Menu, PVsounds, Add, Slideshow speed based on sound files duration, ToggleSyncSlide2sndDuration
   If (syncSlideShow2Audios=1)
      Menu, PVsounds, Check, Slideshow speed based on sound files duration
   If (autoPlaySNDs!=1)
      Menu, PVsounds, Disable, Slideshow speed based on sound files duration
   Menu, PVsounds, Add, 
   Menu, PVsounds, Add, Change audio volume`t1`,2, ChangeVolume
   Menu, PVsounds, Add, Audio volume: %mediaSNDvolume%`%, dummy
   Menu, PVsounds, Disable, Audio volume: %mediaSNDvolume%`%

   Menu, PVfileSel, Add, &First`tCtrl+Home, jumpToFilesSelBorderFirst
   Menu, PVfileSel, Add, &Previous`tCtrl+Left, navSelectedFilesPrev
   Menu, PVfileSel, Add, &Next`tCtrl+Right, navSelectedFilesNext
   Menu, PVfileSel, Add, &Last`tCtrl+End, jumpToFilesSelBorderLast
   Menu, PVfileSel, Add, 
   Menu, PVfileSel, Add, Select/deselect file`tTab / Space, MenuMarkThisFileNow
   Menu, PVfileSel, Add, Select all`tCtrl+A, selectAllFiles
   Menu, PVfileSel, Add, Select none`tCtrl+D, dropFilesSelection
   Menu, PVfileSel, Add, Invert selection, invertFilesSelection
   Menu, PVfileSel, Add, 
   Menu, PVfileSel, Add, Filter files list to selected`tCtrl+Space, filterToFilesSelection

; main menu
   Menu, PVmenu, Add, &Open..., :PVopenF
   If (StrLen(UserMemBMP)>2 && thumbsDisplaying!=1)
   {
      Menu, PVmenu, Add, &Save image as (prev. folder)`tCtrl+S, SaveClipboardImage
      If CurrentSLD
      {
         Menu, PVmenu, Add, &Save image as...`tCtrl+Shift+S, BtnSaveIMGadjustPanel
         Menu, PVmenu, Add, &Revert changes...`tF5, RefreshImageFileAction
      }
   } Else If (StrLen(UserMemBMP)>2 && thumbsDisplaying=1)
      Menu, PVmenu, Add, &Return to image editing, MenuReturnIMGedit

   Menu, PVmenu, Add,
   If (thumbsDisplaying!=1 && activateImgSelection!=1 && imgSelX2=-1 && imgSelY2=-1 && (CurrentSLD || StrLen(UserMemBMP)>2))
      Menu, PVmenu, Add, Create edit area`tE, newImgSelection
   Else If (thumbsDisplaying!=1 && activateImgSelection!=1  && (CurrentSLD || StrLen(UserMemBMP)>2))
      Menu, PVmenu, Add, Show selection area`tE, ToggleEditImgSelection

   If (maxFilesIndex>0 && CurrentSLD)
   {
      infoThisFile := markedSelectFile ? "S&elected files" : "C&urrent file"
      If (thumbsDisplaying!=1 && activateImgSelection=1)
      {
         Menu, PVmenu, Add, Selec&tion area, :PVselv
         Menu, PVmenu, Add, &Edit image, :PVedit
      }
      Menu, PVmenu, Add, % infoThisFile, :PVtFile
      If (thumbsDisplaying=1) || (thumbsDisplaying!=1 && activateImgSelection!=1)
         Menu, PVmenu, Add, Files index/l&ist, :PVfList

      If (thumbsDisplaying=1 && maxFilesIndex>1)
         Menu, PVmenu, Add, &Sort list by..., :PVsort

      If (thumbsDisplaying!=1) || (thumbsDisplaying=1 && thumbnailsListMode!=1)
         Menu, PVmenu, Add, Image vie&w, :PVview

      If (thumbsDisplaying!=1)
         Menu, PVmenu, Add, Au&dio annotation, :PVsounds

      If (maxFilesIndex>2)
      {
         Menu, PVmenu, Add, Navigation, :PVnav
         If (thumbsDisplaying!=1 && activateImgSelection!=1)
            Menu, PVmenu, Add, Slideshow, :PVslide
      }
      Menu, PVmenu, Add,
   } Else If StrLen(UserMemBMP)>2
   {
      If (activateImgSelection=1 && thumbsDisplaying!=1)
      {
         Menu, PVmenu, Add, Selec&tion, :PVselv
         Menu, PVmenu, Add, &Edit image, :PVedit
      }
      If (thumbsDisplaying!=1) || (thumbsDisplaying=1 && thumbnailsListMode!=1)
         Menu, PVmenu, Add, Image vie&w, :PVview
   }

   If (markedSelectFile && thumbsDisplaying!=1)
      Menu, PVmenu, Add, Dro&p files selection`tShift+Tab, dropFilesSelection
   Else If (markedSelectFile && thumbsDisplaying=1)
      Menu, PVmenu, Add, F&iles selection, :PVfileSel

   createMenuInterfaceOptions()
   If StrLen(filesFilter)>1
   {
      Menu, PVmenu, Add,
      Menu, PVmenu, Add, Remove files list filter`tCtrl+Space, remFilesListFilter
      Menu, PVmenu, Add,
   }

   If (thumbsDisplaying=1)
      Menu, PVmenu, Add, Toggle view modes`tL, toggleListViewModeThumbs
   Menu, PVmenu, Add, Inter&face, :PvUIprefs
   Menu, PVmenu, Add, Prefe&rences, :PVprefs
   Menu, PVmenu, Add, About`tF1, AboutWindow
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, Restart`tShift+Esc, restartAppu
   Menu, PVmenu, Add, Exit`tEsc, TrueCleanup
   showThisMenu("PVmenu")
}

showThisMenu(menarg) {
   If (A_TickCount - lastOtherWinClose<100)
      Return

   Suspend, On
   Menu, % menarg, Show
   Suspend, Off
   Global lastWinDrag := A_TickCount
   Global lastOtherWinClose := A_TickCount
}

deleteMenus() {
    Static menusList := "PVmenu|PVperfs|PVfileSel|PVslide|PVnav|PVview|PVfList|PVtFile|PVprefs|PvUIprefs|PVopenF|PVsort|PVedit|PVselv|PVsounds"
    Loop, Parse, menusList, |
        Try Menu, % A_LoopField, Delete
}

createMenuInterfaceOptions() {
   infoThumbsList := defineListViewModes()
   infoThumbsMode := (thumbsDisplaying=1) ? "Switch to image view" : "Switch to " infoThumbsList " list view"
   If (maxFilesIndex>1 && !AnyWindowOpen)
      Menu, PvUIprefs, Add, %infoThumbsMode%`tEnter/MClick, MenuDummyToggleThumbsMode
   If (maxFilesIndex>1 && !AnyWindowOpen && prevOpenedWindow[2])
      Menu, PvUIprefs, Add, Open pre&vious panel`tF8, openPreviousPanel

   If (thumbsDisplaying!=1 && !AnyWindowOpen)
      Menu, PvUIprefs, Add, &Toggle full-screen mode`tF11, ToggleFullScreenMode

   If (thumbsDisplaying!=1)
   {
      Menu, PvUIprefs, Add, &Touch screen mode, ToggleTouchMode
      If (TouchScreenMode=1)
         Menu, PvUIprefs, Check, &Touch screen mode
   }

   Menu, PvUIprefs, Add, &Large UI fonts, ToggleLargeUIfonts
   Menu, PvUIprefs, Add, &Always on top, ToggleAllonTop

   If (thumbsDisplaying!=1)
   {
      Menu, PvUIprefs, Add, &Hide title bar, ToggleTitleBaru
      If (getCaptionStyle(PVhwnd)=1)
         Menu, PvUIprefs, Check, &Hide title bar
   }

   Menu, PvUIprefs, Add,
   If (thumbsDisplaying!=1)
   {
      Menu, PvUIprefs, Add, &Show image captions`tN, ToggleImgCaptions
      If (showImgAnnotations=1)
         Menu, PvUIprefs, Check, &Show image captions`tN
   }

   If (maxFilesIndex>0 && CurrentSLD && thumbsDisplaying!=1)
   {
      Menu, PvUIprefs, Add, &OSD image info-box`tI, ToggleInfoBoxu
      Menu, PvUIprefs, Add, No OSD messages, ToggleInfoToolTips
      Menu, PvUIprefs, Add, I&mage luminance histogram`tShift+H, ToggleImgHistogram
      Menu, PvUIprefs, Add, &Ambiental textured background, ToggleTexyBGR
      If (noTooltipMSGs=1)
      Menu, PvUIprefs, Check, No OSD messages
      If (showHistogram=1)
         Menu, PvUIprefs, Check, I&mage luminance histogram`tShift+H
      If (showInfoBoxHUD=1)
         Menu, PvUIprefs, Check, &OSD image info-box`tI
 
      If (usrTextureBGR=1)
         Menu, PvUIprefs, Check, &Ambiental textured background
   }

   If !AnyWindowOpen
   {
      Menu, PvUIprefs, Add, 
      Menu, PvUIprefs, Add, Additional settings`tF12, PrefsPanelWindow
   }

   If (PrefsLargeFonts=1)
      Menu, PvUIprefs, Check, &Large UI fonts
   If (getTopMopStyle(PVhwnd)=1)
      Menu, PvUIprefs, Check, &Always on top
}

EraseHistory() {
   Loop, 15
       IniWrite, 0, % mainSettingsFile, Recents, E%A_Index%
}

OpenRecentEntry() {
  startZeit := A_TickCount
  testOs := A_ThisMenuItem
  If (SLDtypeLoaded=3)
  {
     SLDtypeLoaded := 0
     activeSQLdb.CloseDB()
  }

  If RegExMatch(testOs, "i)^(o1\. )")
     openThisu := prevFileSavePath
  Else If RegExMatch(testOs, "i)^(o2\. )")
     openThisu := prevFileMovePath
  Else If RegExMatch(testOs, "i)^(o3\. )")
     openThisu := prevOpenFolderPath

  If openThisu
  {
     coreOpenFolder("|" openThisu, 1)
     If (maxFilesIndex>0)
        SLDtypeLoaded := 1
     Else resetMainWin2Welcome()
     Return
  }

  openThisu := SubStr(testOs, 2, InStr(testOs, ". ")-2)
  IniRead, newEntry, % mainSettingsFile, Recents, E%openThisu%, @
; MsgBox, %openthisu% -- %newentry%
  newEntry := Trim(newEntry)
  If StrLen(newEntry)>4
  {
     If RegExMatch(newEntry, sldsPattern)
     {
        OpenSLD(newEntry)
     } Else
     {
        prevOpenFolderPath := StrReplace(newEntry, "|")
        INIaction(1, "prevOpenFolderPath", "General")
        coreOpenFolder(newEntry, 1)
        If (maxFilesIndex>0)
           SLDtypeLoaded := 1
        Else resetMainWin2Welcome()
     }
  }
  ; ToolTip, % (A_TickCount - startZeit) - (A_TickCount - startZeitIMGload) , , , 2
  ; SoundBeep 
}

INIaction(act, var, section, silentu:=0) {
  varValue := %var%
  If (act=1)
     IniWrite, %varValue%, % mainSettingsFile, %section%, %var%
  Else
     IniRead, %var%, % mainSettingsFile, %section%, %var%, %varValue%
  ; If (silentu=0 && ScriptInitialized!=1)
  ;    throwMSGwriteError()
}

ToggleFullScreenMode() {
   Static prevState := 0, o_TouchScreenMode := "a"
   If (thumbsDisplaying=1)
   {
      o_TouchScreenMode := TouchScreenMode
      ToggleThumbsMode()
      Return
   }

  prevState := !prevState
  If (prevState=0)
  {
     o_TouchScreenMode := TouchScreenMode
     TouchScreenMode := 0
     isTitleBarHidden := 0
     If (editingSelectionNow=1)
       ToggleEditImgSelection()
     WinSet, Style, -0xC00000, ahk_id %PVhwnd%
     WinMaximize, ahk_id %PVhwnd%
  } Else
  {
     If (o_TouchScreenMode!="a")
        TouchScreenMode := o_TouchScreenMode
     isTitleBarHidden := 1
     WinSet, Style, +0xC00000, ahk_id %PVhwnd%
     WinRestore, ahk_id %PVhwnd%
  }

  interfaceThread.ahkassign("isTitleBarHidden", isTitleBarHidden)
  interfaceThread.ahkassign("TouchScreenMode", TouchScreenMode)
  INIaction(1, "isTitleBarHidden", "General")
  INIaction(1, "TouchScreenMode", "General")


}

ToggleAllonTop() {
   isAlwaysOnTop := !isAlwaysOnTop
   If (isAlwaysOnTop=1)
      WinSet, AlwaysOnTop, On, ahk_id %PVhwnd%
   Else
      WinSet, AlwaysOnTop, Off, ahk_id %PVhwnd%

   INIaction(1, "isAlwaysOnTop", "General")
}

ToggleEasySlideStop() {
   easySlideStoppage := !easySlideStoppage
   INIaction(1, "easySlideStoppage", "General")
}

ToggleGIFsPlayEntirely() {
   allowGIFsPlayEntirely := !allowGIFsPlayEntirely
   INIaction(1, "allowGIFsPlayEntirely", "General")
}

ToggleAutoResetImageView() {
   resetImageViewOnChange := !resetImageViewOnChange
   INIaction(1, "resetImageViewOnChange", "General")
}

toggleListViewModeThumbs() {
   If (thumbsDisplaying!=1)
      Return

   If (thumbnailsListMode!=1)
   {
      thumbsListViewMode := 1
      thumbnailsListMode := 1
   } Else
   {
      thumbnailsListMode := 1
      thumbsListViewMode++
      If (thumbsListViewMode>=4)
         thumbsListViewMode := thumbnailsListMode := 0
   }

   INIaction(1, "thumbnailsListMode", "General")
   INIaction(1, "thumbsListViewMode", "General")
   recalculateThumbsSizes()
   If (thumbnailsListMode!=1)
      initAHKhThumbThreads()
   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(50)

   friendly := defineListViewModes()
   If (StrLen(userSearchString)>1 && thumbnailsListMode=1)
      friendly .= "`nHighlighting files matching search criteria:`n" userSearchString

   showTOOLtip("List view: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

defineListViewModes() {
   infoThumbsSize := (thumbsDisplaying=1) ? " (" thumbsW " x " thumbsH " px )" : ""
   If (thumbnailsListMode!=1)
      friendly := "THUMBNAILS"
   Else If (thumbnailsListMode=1 && thumbsListViewMode=1)
      friendly := "COMPACT"
   Else If (thumbnailsListMode=1 && thumbsListViewMode=2)
      friendly := "FILE DETAILS"
   Else If (thumbnailsListMode=1 && thumbsListViewMode=3)
      friendly := "IMAGE DETAILS"

   Return friendly
}

ToggleAutoPlaySND() {
   autoPlaySNDs := !autoPlaySNDs
   INIaction(1, "autoPlaySNDs", "General")
}

ToggleSyncSlide2sndDuration() {
   syncSlideShow2Audios := !syncSlideShow2Audios
   INIaction(1, "syncSlideShow2Audios", "General")
}

ToggleSlidesTransitions() {
   doSlidesTransitions := !doSlidesTransitions
   INIaction(1, "doSlidesTransitions", "General")
}

ToggleInfoBoxu() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked < 55) || (thumbsDisplaying=1)
       Return

    lastInvoked := A_TickCount
    showInfoBoxHUD := !showInfoBoxHUD
    INIaction(1, "showInfoBoxHUD", "General")
    SetTimer, dummyRefreshImgSelectionWindow, -50
    ; dummyTimerDelayiedImageDisplay(50)
}

ToggleImgCaptions() {
    Static lastInvoked := 1
    If (thumbsDisplaying=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    showImgAnnotations := !showImgAnnotations
    INIaction(1, "showImgAnnotations", "General")
    SetTimer, dummyRefreshImgSelectionWindow, -50
    If (showImgAnnotations=1)
    {
       imgPath := getIDimage(currentFileIndex)
       zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       textFile := OutDir "\" OutNameNoExt ".txt"
       If !FileExist(textFile)
          showTOOLtip("Display image captions: ACTIVATED`nNo image caption / annotation file associated...`nPress Shift+N to create/edit one.")
       Else
          showTOOLtip("Display image captions: ACTIVATED")
    } Else showTOOLtip("Display image captions: DEACTIVATED")
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

ToggleMultiLineStatus() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked < 55)
       Return

    lastInvoked := A_TickCount
    multilineStatusBar := !multilineStatusBar
    INIaction(1, "multilineStatusBar", "General")
    dummyTimerDelayiedImageDisplay(50)
}

toggleImgSelCoords() {
   relativeImgSelCoords := !relativeImgSelCoords
   calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)
   INIaction(1, "relativeImgSelCoords", "General")
}

ToggleRenderOpaque() {
   RenderOpaqueIMG := !RenderOpaqueIMG
   INIaction(1, "RenderOpaqueIMG", "General")
   If (InStr(currentPixFmt, "argb") && (thumbsDisplaying!=1))
      RefreshImageFile()
}

ToggleSelectGrid() {
   showSelectionGrid := !showSelectionGrid
   INIaction(1, "showSelectionGrid", "General")
   If (thumbsDisplaying!=1)
      dummyTimerDelayiedImageDisplay(25)
}

toggleEllipseSelection() {
   If (activateImgSelection!=1 || thumbsDisplaying=1)
      Return

   EllipseSelectMode := !EllipseSelectMode
   INIaction(1, "EllipseSelectMode", "General")
   If (thumbsDisplaying!=1)
      dummyTimerDelayiedImageDisplay(25)
}

toggleLimitSelection() {
   If (activateImgSelection!=1 || thumbsDisplaying=1)
      Return

   LimitSelectBoundsImg := !LimitSelectBoundsImg
   INIaction(1, "LimitSelectBoundsImg", "General")
   If (thumbsDisplaying!=1)
      dummyTimerDelayiedImageDisplay(25)
}

ToggleAlwaysFIMus() {
   alwaysOpenwithFIM := !alwaysOpenwithFIM
   r := initFIMGmodule()
   If InStr(r, "err - 126")
      friendly := "`n`nPlease install the Runtime Redistributable Packages of Visual Studio 2015."
   Else If InStr(r, "err - 404")
      friendly := "`n`nThe FreeImage.dll file seems to be missing..."

   INIaction(1, "alwaysOpenwithFIM", "General")
   If (FIMfailed2init=1)
      msgBoxWrapper(appTitle ": ERROR", "The FreeImage library failed to properly initialize. Various image file formats will no longer be supported. Error code: " r "." friendly, 0, 0, "error")
   Else If (thumbsDisplaying!=1)
      RefreshImageFile()
}

ToggleAnimGIFsupport() {
   animGIFsSupport := !animGIFsSupport
   INIaction(1, "animGIFsSupport", "General")
}

ToggleAutoRemEntries() {
   autoRemDeadEntry := !autoRemDeadEntry
   INIaction(1, "autoRemDeadEntry", "General")
}

ToggleSLDcache() {
   SLDcacheFilesList := !SLDcacheFilesList
   INIaction(1, "SLDcacheFilesList", "General")
}

TogglePromptDelete() {
   askDeleteFiles := !askDeleteFiles
   INIaction(1, "askDeleteFiles", "General")
}

ToggleTitleBaruNow(dummy:=0) {
   If (getCaptionStyle(PVhwnd)=0)
   {
      TouchScreenMode := 0
      isTitleBarHidden := 0
      If (editingSelectionNow=1)
         ToggleEditImgSelection()
      WinSet, Style, -0xC00000, ahk_id %PVhwnd%
   } Else
   {
      isTitleBarHidden := 1
      WinSet, Style, +0xC00000, ahk_id %PVhwnd%
   }
   interfaceThread.ahkassign("isTitleBarHidden", isTitleBarHidden)
   interfaceThread.ahkassign("TouchScreenMode", TouchScreenMode)
   INIaction(1, "isTitleBarHidden", "General")
   INIaction(1, "TouchScreenMode", "General")
}

ToggleTitleBaru() {
   SetTimer, ToggleTitleBaruNow, -150
}

ToggleInfoToolTips() {
    noTooltipMSGs := !noTooltipMSGs
    INIaction(1, "noTooltipMSGs", "General")
}

ToggleLargeUIfonts() {
    PrefsLargeFonts := !PrefsLargeFonts
    If (AnyWindowOpen=14)
       PrefsPanelWindow()

    calcHUDsize()
    INIaction(1, "PrefsLargeFonts", "General")
}

ToggleTexyBGR() {
    usrTextureBGR := !usrTextureBGR
    INIaction(1, "usrTextureBGR", "General")
    RefreshImageFile()
}

ToggleImgHistogram() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked < 50) || (thumbsDisplaying=1)
       Return

    lastInvoked := A_TickCount
    showHistogram := !showHistogram
    INIaction(1, "showHistogram", "General")
    dummyTimerDelayiedImageDisplay(50)
}

ToggleThumbsCaching() {
    enableThumbsCaching := !enableThumbsCaching
    INIaction(1, "enableThumbsCaching", "General")
}

ToggleSkipDeadFiles() {
    skipDeadFiles := !skipDeadFiles
    INIaction(1, "skipDeadFiles", "General")
}

ToggleIgnoreSLDprefs() {
    MustLoadSLDprefs := !MustLoadSLDprefs
    INIaction(1, "MustLoadSLDprefs", "General")
}

ToggleImgQuality(modus:=0) {
    userimgQuality := !userimgQuality
    If (modus="highu")
       userimgQuality := 1
    Else If (modus="lowu")
       userimgQuality := 0
    imgQuality := (userimgQuality=1) ? 7 : 5
    PixelMode := (userimgQuality=1) ? 2 : 0
    Gdip_SetInterpolationMode(glPG, imgQuality)
    Gdip_SetPixelOffsetMode(glPG, PixelMode)
    INIaction(1, "userimgQuality", "General")
}

ToggleRAWquality() {
    userHQraw := !userHQraw
    INIaction(1, "userHQraw", "General")
}

ToggleMultiCoreSupport() {
    allowMultiCoreMode := !allowMultiCoreMode
    INIaction(1, "allowMultiCoreMode", "General")
    If (thumbsDisplaying=1 && thumbnailsListMode!=1 && multiCoreThumbsInitGood="n")
       initAHKhThumbThreads()
}

ToggleLimitMemUsage() {
    minimizeMemUsage := !minimizeMemUsage
    INIaction(1, "minimizeMemUsage", "General")
    If (minimizeMemUsage=1)
    {
       msgBoxWrapper(appTitle ": WARNING", "By limiting memory usage, the performance of Quick Picto Viewer will likely be drastically reduced. Additionally, some functions might be disabled.", 0, 0, "exclamation")
       discardViewPortCaches()
    }
}

ToggleImgColorDepthDithering() {
    ColorDepthDithering := !ColorDepthDithering
    INIaction(1, "ColorDepthDithering", "General")
    If (thumbsDisplaying!=1)
       RefreshImageFile()
}

ToggleImgDownScaling() {
    If (thumbsDisplaying=1)
       Return

    If (slideShowRunning=1)
       ToggleSlideShowu()

    AutoDownScaleIMGs := !AutoDownScaleIMGs
    INIaction(1, "AutoDownScaleIMGs", "General")
    If (AutoDownScaleIMGs=1)
       showTOOLtip("Images larger than the screen resolution will be`ndownscaled prior to any potential any effect.")
    Else
       showTOOLtip("Downscaling: DISABLED")
    SetTimer, RemoveTooltip, % -msgDisplayTime
    SetTimer, RefreshImageFile, -300
}

ToggleTouchMode() {
    TouchScreenMode := !TouchScreenMode
    If (getCaptionStyle(PVhwnd)=1 && TouchScreenMode=1)
       ToggleTitleBaruNow()
    interfaceThread.ahkassign("isTitleBarHidden", isTitleBarHidden)
    interfaceThread.ahkassign("TouchScreenMode", TouchScreenMode)
    INIaction(1, "TouchScreenMode", "General")
    INIaction(1, "isTitleBarHidden", "General")
}

defineWinTitlePrefix() {
   Static FXmodesLabels := {2:"cP", 3:"cAUTO", 4:"cGR", 5:"cR", 6:"cG", 7:"cB", 8:"cA", 9:"cI"}

   If StrLen(UserMemBMP)>1
      winPrefix .= "IMAGE EDITING | "

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

   If (thisIMGisDownScaled=1)
      winPrefix .= "DWS "

   If FXmodesLabels.HasKey(imgFxMode)
      winPrefix .= FXmodesLabels[imgFxMode] A_Space

   If (IMGresizingMode=3)
      winPrefix .= "O "
   Else If (IMGresizingMode=4)
      winPrefix .= "Z "

   Return winPrefix
}

drawWelcomeImg() {
    Critical, on
    If StrLen(UserMemBMP)>2
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
       r1 := Gdip_DrawImageFX(glPG, BMPcache, 0, 0, 0, 0, mainWidth, mainHeight, matrix, pEffect)
       Gdip_DisposeImage(BMPcache, 1)
    }

    r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)
    Gdip_DisposeEffect(pEffect)
    Gdip_DeleteBrush(pBr1)
    Gdip_DeleteBrush(pBr2)
    Gdip_DeleteBrush(pBr3)
    Gdip_DeleteBrush(pBr4)
    Gdip_DeleteBrush(pBr5)
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

    SelectObject(2NDglHDC, 2NDglOBM)
    DeleteObject(2NDglHbitmap)
    DeleteDC(2NDglHDC)
    Gdip_DeleteGraphics(2NDglPG)
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

      imgQuality := (userimgQuality=1) ? 7 : 5
      PixelMode := (userimgQuality=1) ? 2 : 0
      glHbitmap := CreateDIBSection(W, H)
      glHDC := CreateCompatibleDC()
      glOBM := SelectObject(glHDC, glHbitmap)
      glPG := Gdip_GraphicsFromHDC(glHDC, imgQuality, 4)
      Gdip_SetPixelOffsetMode(glPG, PixelMode)

      2NDglHbitmap := CreateDIBSection(W, H)
      2NDglHDC := CreateCompatibleDC()
      2NDglOBM := SelectObject(2NDglHDC, 2NDglHbitmap)
      2NDglPG := Gdip_GraphicsFromHDC(2NDglHDC, imgQuality, 4)
      Gdip_SetPixelOffsetMode(2NDglPG, PixelMode)
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
   pBrushF := Gdip_BrushCreateSolid("0x44556666")

   ; createCheckersBrush(20)
   pBrushHatchLow := Gdip_BrushCreateHatch("0xff999999", "0xff111111", 50)
   pBrushWinBGR := Gdip_BrushCreateSolid("0xFF" WindowBgrColor)

   ; initSQLdb()
}

initSQLdb(fileNamu) {
   activeSQLdb.CloseDB()
   activeSQLdb := new SQLiteDB
   If !activeSQLdb.OpenDB(fileNamu)
      Return -1

   SQL := "CREATE TABLE images (imgfile TEXT, imgfolder TEXT, fsize NUMERIC, fmodified NUMERIC, fcreated NUMERIC, imgwidth NUMERIC, imgheight NUMERIC, imgavg NUMERIC, imgmedian NUMERIC, PRIMARY KEY(imgfolder ASC, imgfile ASC));"
   SQL .= "CREATE TABLE dynamicfolders (imgfolder TEXT, fmodified NUMERIC, PRIMARY KEY(imgfolder ASC));"
   SQL .= "CREATE TABLE staticfolders (imgfolder TEXT, fmodified NUMERIC, PRIMARY KEY(imgfolder ASC));"
   If !activeSQLdb.Exec(SQL)
      Return -1
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
   Gdip_DisposeImage(pBitmap, 1)
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

dummy() {
  Sleep, 0
}

setImageLoading() {
  imageLoading := 1
  If (slideShowRunning=1 || animGIFplaying=1)
     Return

  interfaceThread.ahkassign("imageLoading", 1)
  interfaceThread.ahkassign("lastCloseInvoked", 0)
  changeMcursor()
}

ResetImgLoadStatus() {
  If (slideShowRunning=1 && slideShowDelay<600) || (animGIFplaying=1)
     Return

  If !GetKeyState("LButton")
  {
     runningLongOperation := 0
     changeMcursor("normal")
     interfaceThread.ahkassign("imageLoading", 0)
     interfaceThread.ahkassign("mustAbandonCurrentOperations", 0)
     interfaceThread.ahkassign("runningLongOperation", 0)
     interfaceThread.ahkassign("lastCloseInvoked", 0)
     mustAbandonCurrentOperations := imageLoading := 0
  } Else If (imageLoading=1)
     SetTimer, ResetImgLoadStatus, -50
}

ShowTheImage(imgPath, usePrevious:=0, ForceIMGload:=0) {
  Static prevImgPath, lastInvoked := 1

  If (slideShowRunning=1)
  {
     slideShowRunning := interfaceThread.ahkgetvar.slideShowRunning
     If (slideShowRunning!=1)
        prevSlideShowStop := A_TickCount
  }

  doIT := ((A_TickCount - lastInvoked<125) && (drawModeAzeit>180 && LastPrevFastDisplay!=1 && prevDrawingMode=1)) || (drawModeBzeit>200 && prevDrawingMode=3 && LastPrevFastDisplay!=1) || ((A_TickCount - lastInvoked<65) && (prevImgPath!=imgPath && drawModeAzeit>50)) || ((A_TickCount - lastInvoked<10) && prevDrawingMode=1) ? 1 : 0
  If (A_TickCount - prevColorAdjustZeit<90) || (animGIFplaying=1 || slideShowRunning=1)
     doIT := 0

  If (usePrevious=0 && ForceIMGload=0 && AnyWindowOpen!=10
  && doIT=1 && !diffIMGdecX && !diffIMGdecY && thumbsDisplaying!=1)
  {
     ; If (noTooltipMSGs=1)
     ;   SetTimer, RemoveTooltip, Off
     ; ToolTip, % Exception("", -1).Line "`n" Exception("", -1).What, , , 2
     zPlitPath(imgPath, 0, OutFileName, OutDir)
     If (vpIMGrotation>0)
        zoomu := " @ " vpIMGrotation "°"
     If (IMGresizingMode=4)
        zoomu := " [" Round(zoomLevel * 100) "%" zoomu "]"
     winTitle := currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir "\"
     winPrefix := defineWinTitlePrefix()
     pVwinTitle := winPrefix winTitle
     setWindowTitle(pVwinTitle, 1)
     lastInvoked := A_TickCount
     dummyFastImageChangePlaceHolder(OutFileName, OutDir)
     ; SetTimer, dummyFastImageChangePlaceHolder, -15
     dummyTimerReloadThisPicture(550)
     prevImgPath := imgPath
  } Else
  {
     If (animGIFplaying=1)
        usePrevious := 0

     prevImgPath := imgPath
     If (thumbsDisplaying=1) && (A_TickCount - prevFullThumbsUpdate < 200) ; && (prevStartIndex!=prevFullIndexThumbsUpdate)
        prevTryThumbsUpdate := A_TickCount

     coreShowTheImage(imgPath, usePrevious, ForceIMGload)
     If (thumbsDisplaying=1) && (A_TickCount - prevFullThumbsUpdate < 200) ; && (prevStartIndex!=prevFullIndexThumbsUpdate)
        prevTryThumbsUpdate := A_TickCount
  }

  lastInvoked := A_TickCount
}

coreShowTheImage(imgPath, usePrevious:=0, ForceIMGload:=0) {
   Critical, on
   Static prevImgPath, lastInvoked2 := 1, counteru
        , lastInvoked := 1, prevPicCtrl := 1

   WinGet, winStateu, MinMax, ahk_id %PVhwnd%
   If (winStateu=-1)
   {
      DestroyGIFuWin()
      Return
   }

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

   zPlitPath(imgPath, 0, OutFileName, OutDir)
   If (vpIMGrotation>0)
      zoomu := " @ " vpIMGrotation "°"
   If (IMGresizingMode=4)
      zoomu := " [" Round(zoomLevel * 100) "%" zoomu "]"

   winTitle := currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir "\"
   If (thumbsDisplaying=1)
   {
      filesSelInfo := (markedSelectFile>0) ? "[ " markedSelectFile " ] " : ""
      SetTimer, UpdateThumbsScreen, -10
      pVwinTitle := filesSelInfo "THUMBS: " winTitle
      setWindowTitle(pVwinTitle, 1)
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
   If (InStr(AprevImgCall, imgPath) || InStr(BprevImgCall, imgPath)) && (ForceIMGload=0) || StrLen(UserMemBMP)>1
      ignoreFileCheck := 1

   If (!FileRexists(imgPath) && usePrevious=0 && ignoreFileCheck!=1)
   {
      destroyGDIfileCache()
      DestroyGIFuWin()
      If (hSNDmedia && autoPlaySNDs!=1)
         StopMediaPlaying()
      If (slideShowRunning=1)
         interfaceThread.ahkPostFunction("dummySlideshow")

      If (WinActive("A")=PVhwnd)
      {
         winTitle := "[*] " winTitle
         pVwinTitle := winTitle
         setWindowTitle(pVwinTitle, 1)
         showTOOLtip("ERROR: File not found or access denied...`n" OutFileName "`n" OutDir "\")
         SetTimer, RemoveTooltip, % -msgDisplayTime
      }

      If (imgPath!=prevImgPath)
      {
         UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
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
   || (slideShowRunning=1 || animGIFplaying=1 || usePrevious=1 || oldZoomLevel || ForceIMGload=1 || diffIMGdecX || diffIMGdecY || LastPrevFastDisplay=1)
   {
       lastInvoked := A_TickCount
       r2 := ResizeImageGDIwin(imgPath, usePrevious, ForceIMGload)
       If !r2
       {
          DestroyGIFuWin()
          destroyGDIfileCache()
          If (hSNDmedia && autoPlaySNDs!=1)
             StopMediaPlaying()
          If (slideShowRunning=1)
             interfaceThread.ahkPostFunction("dummySlideshow")

          If (WinActive("A")=PVhwnd)
          {
             showTOOLtip("ERROR: Unable to display the image...`nPossibly malformed image file format.")
             SetTimer, RemoveTooltip, % -msgDisplayTime
          }
          winTitle := "[*] " winTitle
          pVwinTitle := winTitle
          setWindowTitle(pVwinTitle, 1)
          SetTimer, ResetImgLoadStatus, -15
          SoundBeep, 300, 100
          Return "fail"
       } Else prevImgPath := imgPath
       lastInvoked := A_TickCount
   } Else
   {
      ; If (noTooltipMSGs=1)
      ;    SetTimer, RemoveTooltip, Off
      winPrefix := defineWinTitlePrefix()
      pVwinTitle := winPrefix winTitle
      setWindowTitle(pVwinTitle, 1)
      delayu := (A_TickCount - prevFastDisplay < 500) ? 110 : 325
      dummyFastImageChangePlaceHolder(OutFileName, OutDir)
      dummyTimerReloadThisPicture(delayu)
   }
   SetTimer, ResetImgLoadStatus, -15
   lastInvoked2 := A_TickCount
}

dummyFastImageChangePlaceHolder(OutFileName, OutDir) {
   Static lastInvoked := 1, prevImgPath
   If (A_TickCount - lastInvoked<50) || (noTooltipMSGs=1)
      Return

   lastInvoked := A_TickCount
   entireString := "[ " currentFileIndex " / " maxFilesIndex " ] " OutFileName "`n" OutDir "\"
   If (entireString=prevImgPath)
      Return

   prevImgPath := entireString
   TooltipCreator(entireString, 0, 1)
   SetTimer, RemoveTooltip, -500
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

ResizeImageGDIwin(imgPath, usePrevious, ForceIMGload) {
    Critical, on
    Static oImgW, oImgH, prevImgPath, lastTitleChange := 1
         , IDprevImgPath, tinyW, tinyH, wscale

    setImageLoading()
    setWindowTitle("Loading...")
    changeMcursor()
    calcScreenLimits()
    ; If (winGDIcreated!=1)
    ;   createGDIwin()
    interfaceThread.ahkassign("canCancelImageLoad", 0)
    ; o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
    o_AutoDownScaleIMGs := (AutoDownScaleIMGs>0) ? 1 : 0
    extraID := ColorDepthDithering o_AutoDownScaleIMGs vpIMGrotation RenderOpaqueIMG usrTextureBGR usrColorDepth bwDithering
    IDthisImgPath := imgPath "-" userHQraw extraID
    If (imgPath!=prevImgPath || IDthisImgPath!=IDprevImgPath || !gdiBitmap || ForceIMGload=1)
    {
       gdiBMPchanged := 1
       ; ToolTip, % ForceIMGload, , , 2
       If (imgPath!=prevImgPath) && (currentFileIndex!=0)
       {
          UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
          desiredFrameIndex := 0
          If (AutoDownScaleIMGs=2)
             AutoDownScaleIMGs := 1
       }

       mustReloadIMG := (IDthisImgPath!=IDprevImgPath && imgPath=prevImgPath) || (ForceIMGload=1) ? 1 : 0
       If (IDthisImgPath!=IDprevImgPath && imgPath=prevImgPath)
       {
          usePrevious := 0
          mustReloadIMG := ForceIMGload := 1
          If (currentFileIndex!=0)
             GdipCleanMain(6)
       }

       disposeCacheIMGs()
       changeMcursor()
       r1 := CloneMainBMP(imgPath, oImgW, oImgH, mustReloadIMG, hasFullReloaded)
       abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
       If (imgFxMode=3 && r1!="error" && abortImgLoad<3)
       {
          setWindowTitle("Calculating auto-color adjustments")
          AdaptiveImgLight(gdiBitmap, imgPath, oImgW, oImgH)
       }

       If (abortImgLoad>2)
       {
          o_ImgQuality := userimgQuality
          If (userimgQuality=1)
             ToggleImgQuality("lowu")
          If (desiredFrameIndex<1 && (usrColorDepth>1 || vpIMGrotation>0))
          {
             setWindowTitle("Image processing aborted...")
             showTOOLtip("Image processing aborted...")
             SetTimer, RemoveTooltip, % -msgDisplayTime//2
          }
       }
    }

    If (!gdiBitmap || r1="error")
    {
       If (o_ImgQuality=1)
          ToggleImgQuality("highu")
       If (AutoDownScaleIMGs=2)
          AutoDownScaleIMGs := 1

       prevImgPath := ""
       FadeMainWindow()
       SetTimer, ResetImgLoadStatus, -15
       Return 0
    }

   prevImgPath := imgPath
   IDprevImgPath := imgPath "-" userHQraw extraID
   GetClientSize(GuiW, GuiH, PVhwnd)
   If (usePrevious!=1)
   {
      imgW := oImgW
      imgH := oImgH
   } Else If (usePrevious=1 || mustReloadIMG=1 || ForceIMGload=1) && (animGIFplaying!=1)
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
      roImgW := oImgW
      roImgH := oImgH
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
   If (A_TickCount - lastTitleChange>300)
      setWindowTitle("Adapting image to viewport...")

   ResizedW := Round(ResizedW)
   ResizedH := Round(ResizedH)
   prevMaxSelX := roImgW ? roImgW : oImgW
   prevMaxSelY := roImgH ? roImgH : oImgH
   If (activateImgSelection=1 || editingSelectionNow=1) && (relativeImgSelCoords=1 && gdiBMPchanged=1)
      calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

   GDIfadeVPcache := Gdip_DisposeImage(GDIfadeVPcache, 1)
   If (minimizeMemUsage!=1 && slideShowRunning=1 && doSlidesTransitions=1 && animGIFplaying!=1 && slideShowDelay>950)
      GDIfadeVPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)

   changeMcursor()
   pVwinTitle := infoFilesSel infoFrames winTitle
   r := QPV_ShowImgonGui(oImgW, oImgH, ws, imgW, imgH, ResizedW, ResizedH, GuiW, GuiH, usePrevious, imgPath, ForceIMGload, hasFullReloaded, wasPrevious)
   delayu := (A_TickCount - prevFastDisplay < 300) ? 90 : 550
   If (wasPrevious=1 && animGIFplaying!=1)
      dummyTimerReloadThisPicture(delayu)

   infoFilesSel := (markedSelectFile>0) ? "[ " markedSelectFile " ] " : ""
   If (totalFramesIndex>0)
      infoFrames := "["  desiredFrameIndex "/" totalFramesIndex "] "

   setWindowTitle(pVwinTitle, 1)
   lastTitleChange := A_TickCount
   If (o_ImgQuality=1)
      ToggleImgQuality("highu")

   SetTimer, ResetImgLoadStatus, -15
   Return r
}

drawinfoBox(mainWidth, mainHeight, directRefresh:=0) {
    maxSelX := prevMaxSelX, maxSelY := prevMaxSelY
    imgPath := getIDimage(currentFileIndex)
    infoFilesSel := (markedSelectFile>0) ? "`nFiles selected: " markedSelectFile : ""
    If (totalFramesIndex>0)
       infoFrames := "`nMultiple pages: "  desiredFrameIndex " / " totalFramesIndex

    zPlitPath(imgPath, 0, fileNamu, folderu, OutNameNoExt)
    FileGetSize, fileSizu, % ImgPath, K
    FileGetTime, FileDateM, % ImgPath, M
    FormatTime, FileDateM, % FileDateM, dd/MM/yyyy, HH:mm
    If FileExist(imgPath)
       fileMsg := "`n" groupDigits(fileSizu) " Kb | " FileDateM
    Else
       fileMsg := "`nFile not found or access denied..."

    If (IMGresizingMode!=4)
       infoSizing := "`nRescaling mode: " DefineImgSizing() "`nViewport alignment: " defineImgAlign()
    If (vpIMGrotation>0)
       infoRotate := " @ " vpIMGrotation "°"

    infoRes := "`nResolution (W x H): " maxSelX " x " maxSelY " px [ " Round(zoomLevel*100) "%" infoRotate " ]"
    ; infoRes := "`nResolution (W x H): " thisW " x " thisH " px [ " Round(zoomLevel*100) "%" infoRotate " ]"
    If (thisIMGisDownScaled=1 && AutoDownScaleIMGs=1)
       infoRes .= " | DOWNSCALED"
    sliSpeed := Round(slideShowDelay/1000, 2) " sec."
    If (slideShowRunning=1)
       infoSlider := "`nSlideshow running: " DefineSlideShowType() " @ " sliSpeed

    infoMirroring := defineIMGmirroring()
    If (activateImgSelection=1)
    {
       imgSelW := max(ImgSelX1, ImgSelX2) - min(ImgSelX1, ImgSelX2)
       imgSelH := max(ImgSelY1, ImgSelY2) - min(ImgSelY1, ImgSelY2)
       If (relativeImgSelCoords=1)
       {
          x1 := " [ " Round(prcSelX1 * 100) "%, "
          y1 := Round(prcSelY1 * 100) "% ]"
          wP := " [ " Round((prcSelX2 - prcSelX1) * 100) "%, "
          hP := Round((prcSelY2 - prcSelY1) * 100) "% ]"
          ; moreSelInfo := "`nCoordinates relative to image size"
       }
       infoSelection := "`n `nSelection coordinates:`nX / Y: " ImgSelX1 ", " ImgSelY1 x1 y1 "`nW / H: " imgSelW ", " imgSelH wP hP moreSelInfo
    }
    If (usrColorDepth>1)
       infoColorDepth := "`nSimulated color depth: " defineColorDepth()

    If StrLen(usrFilesFilteru)>1
       infoFilteru := "`nFiles list filtered from " groupDigits(bkcpMaxFilesIndex) " down to " groupDigits(maxFilesIndex) ".`nFilter pattern: " usrFilesFilteru

    totalZeit := A_TickCount - startZeitIMGload + 2
    If (totalZeit>=10 && directRefresh=1)
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

    If StrLen(UserMemBMP)>1
       infoEditing := "IMAGE EDITING MODE`n"
    If (animGIFplaying=1)
       infoAnim := "`nGIF animation is now playing at " GIFspeedDelay " ms / frame."

    infoColors := "`nColors display mode: " DefineFXmodes() " [" currentPixFmt "]"
    fileRelatedInfos := (StrLen(folderu)>3) ? folderu "\`n[ " groupDigits(currentFileIndex) " / " groupDigits(maxFilesIndex) " ] " fileNamu fileMsg : ""
    entireString := infoEditing fileRelatedInfos infoRes infoSizing infoMirroring infoColors infoColorDepth infoFrames infoAnim InfoLoadTime infoFilesSel infoAudio infoSlider infoSelection infoFilteru
    infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.1, mainWidth//1.3, mainHeight//1.3, OSDtextColor, "0xFF" OSDbgrColor, 1, 1)
    Gdip_DrawImage(2NDglPG, infoBoxBMP, 0, 0,,,,,,, 0.85)
    infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
}

drawAnnotationBox(mainWidth, mainHeight) {
    maxSelX := prevMaxSelX, maxSelY := prevMaxSelY
    imgPath := getIDimage(currentFileIndex)

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
       If mediaDuration
          infoAudio := "Audio file associated" mediaDuration statusMedia "`n"
    } ; Else If (autoPlaySNDs=1)
      ;  infoAudio := "No audio file associated.`n"


    zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
    textFile := OutDir "\" OutNameNoExt ".txt"
    Try FileRead, textFileContent, % textFile
    If StrLen(textFileContent)<1
       textFileContent := ""

    entireString := infoAudio textFileContent
    If !entireString
       Return

    infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.1, mainWidth//1.2, mainHeight//1.2, OSDtextColor, "0xFF" OSDbgrColor, 0, 1, usrTextAlign)
    Gdip_GetImageDimensions(infoBoxBMP, imgW, imgH)
    thisPosY := (scrollBarHy>0) ? scrollBarHy - imgH : mainHeight - imgH
    thisPosX := (scrollBarVx>0) ? scrollBarVx - imgW : mainWidth - imgW
    If (usrTextAlign="Left")
       thisPosX := 0
    Else If (usrTextAlign="Center")
       thisPosX := (scrollBarVx>0) ? scrollBarVx//2 - imgW//2 : mainWidth//2 - imgW//2

    Gdip_DrawImage(2NDglPG, infoBoxBMP, thisPosX, thisPosY,,,,,,, 0.9)
    infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
}

capValuesInRange(value, min, max, reverse:=0) {
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

changeOSDfontSize(direction) {
  stepu := (OSDfntSize>30) ? 5 : 2
  If (direction=1)
     OSDfntSize += stepu
  Else
     OSDfntSize -= stepu

  OSDfntSize := capValuesInRange(OSDfntSize, 15, 350)
  INIaction(1, "OSDfntSize", "General")
  showTOOLtip("OSD font size: " OSDfntSize)
  SetTimer, RemoveTooltip, % -msgDisplayTime
  calcHUDsize()
  recalculateThumbsSizes()
  If (thumbnailsListMode=1 && thumbsDisplaying=1)
  {
     ForceRefreshNowThumbsList()
     dummyTimerDelayiedImageDisplay(25)
  } Else If (thumbsDisplaying=1)
     SetTimer, mainGdipWinThumbsGrid, -25
  Else If (CurrentSLD && maxFilesIndex>0)
     SetTimer, dummyRefreshImgSelectionWindow, -25
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

  gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)
  Size := ((imgW//10)*(imgH//10)>98765) ? 10 : 6
  If ((imgW//10)*(imgH//10)>234567)
     Size := 15
  If ((imgW//10)*(imgH//10)>345678)
     Size := 20
  If ((imgW//10)*(imgH//10)>678901)
     Size := 25
  If ((imgW//10)*(imgH//10)>1597654)
     Size := 30
  If ((imgW//10)*(imgH//10)<44765)
     Size := 3

  ResizedW := Round(imgW//Size) + 2
  ResizedH := Round(imgH//Size) + 2

  prevResizedW := ResizedW
  prevResizedH := ResizedH
  thisImgQuality := (userimgQuality=1) ? 3 : 5
  changeMcursor()
  gdiBitmapSmall := Gdip_ResizeBitmap(gdiBitmap, ResizedW, ResizedH, 0, thisImgQuality)
  prevImgPath := imgPath
}


setGIFframesDelay() {
   GIFspeedDelay := (totalFramesIndex>75) ? 35 : 45
   If (totalFramesIndex>195)
      GIFspeedDelay := 20
   Else If (totalFramesIndex<15)
      GIFspeedDelay := 60
   If (totalFramesIndex<8)
      GIFspeedDelay := 85
}

multiPageFileManaging(oBitmap) {
   rawFmt := Gdip_GetImageRawFormat(oBitmap)
   totalFramesIndex := Gdip_GetBitmapFramesCount(oBitmap) - 1
   If (totalFramesIndex<0)
      totalFramesIndex := 0

   If (desiredFrameIndex>=totalFramesIndex)
      desiredFrameIndex := totalFramesIndex

   setGIFframesDelay()
   If (totalFramesIndex>0 && slideShowRunning=1 && SlideHowMode=1 && animGIFsSupport!=1)
      Random, desiredFrameIndex, 0, % totalFramesIndex

   If RegExMatch(rawFmt, "i)(gif|tiff)$")
      Gdip_BitmapSelectActiveFrame(oBitmap, desiredFrameIndex)
}

LoadBitmapFromFileu(imgPath, noBPPconv:=0, forceGDIp:=0, allowCaching:=0, allowMemBMP:=0) {
  Static prevMD5nameA, prevMD5nameB

  GDIbmpFileConnected := 1
  totalFramesIndex := 0
  coreIMGzeitLoad := A_TickCount
  If (allowMemBMP=1 && StrLen(UserMemBMP)>2)
  {
     prevMD5nameA := prevMD5nameB := ""
     ; If (minimizeMemUsage=1)
        destroyGDIfileCache()
     Return Gdip_CloneBitmap(UserMemBMP)
  }

  If (allowCaching=1)
  {
     MD5name := generateThumbName(imgPath, 1)
     thisMD5name := MD5name imgPath userHQraw alwaysOpenwithFIM
     If (thisMD5name=prevMD5nameA && StrLen(GDIcacheSRCfileA)>2 && StrLen(prevMD5nameA)>2)
     {
        multiPageFileManaging(GDIcacheSRCfileA)
        Return Gdip_CloneBitmap(GDIcacheSRCfileA)
     } Else If (thisMD5name=prevMD5nameB && StrLen(GDIcacheSRCfileB)>2 && StrLen(prevMD5nameB)>2)
     {
        multiPageFileManaging(GDIcacheSRCfileB)
        Return Gdip_CloneBitmap(GDIcacheSRCfileB)
     }
  }

  If RegExMatch(imgPath, RegExFIMformPtrn) || (alwaysOpenwithFIM=1 && forceGDIp=0)
  {
     oBitmap := LoadFimFile(imgPath, noBPPconv)
     GDIbmpFileConnected := 0
  } Else
  {
     changeMcursor()
     oBitmap := Gdip_CreateBitmapFromFile(imgPath)
     If !oBitmap
     {
        GDIbmpFileConnected := 0
        oBitmap := LoadFimFile(imgPath, noBPPconv)
     } Else If (allowMemBMP=1)
        multiPageFileManaging(oBitmap)
  }

  If (allowCaching=1 && oBitmap)
  {
     prevMD5nameB := prevMD5nameA
     prevMD5nameA := thisMD5name
     idGDIcacheSRCfileB := idGDIcacheSRCfileA
     idGDIcacheSRCfileA := GDIbmpFileConnected MD5name imgPath
     GDIcacheSRCfileB := Gdip_DisposeImage(GDIcacheSRCfileB, 1)
     GDIcacheSRCfileB := GDIcacheSRCfileA
     GDIcacheSRCfileA := Gdip_CloneBitmap(oBitmap)
  }
  Return oBitmap
}

RotateBMP2exifOrientation(oBitmap) {
   exifOrientation := Gdip_GetPropertyItem(oBitmap, 0x112)
   orientation := exifOrientation.Value
   ; MsgBox, % orientation
   If (orientation=6)
      Gdip_ImageRotateFlip(oBitmap, 1)
   Else If (orientation=8)
      Gdip_ImageRotateFlip(oBitmap, 3)
   Else If (orientation=3)
      Gdip_ImageRotateFlip(oBitmap, 2)
   Else If (orientation=2)
      Gdip_ImageRotateFlip(oBitmap, 4)
   Else If (orientation=5)
      Gdip_ImageRotateFlip(oBitmap, 5)
   Else If (orientation=4)
      Gdip_ImageRotateFlip(oBitmap, 6)
   Else If (orientation=7)
      Gdip_ImageRotateFlip(oBitmap, 7)
}

CloneMainBMP(imgPath, ByRef imgW, ByRef imgH, mustReloadIMG, ByRef hasFullReloaded) {
  Critical, on
  Static AprevImgDownScaled := 0, BprevImgDownScaled := 0, lastInvoked := 1

  totalFramesIndex := 0
  GDIbmpFileConnected := 1
  hasFullReloaded := CountGIFframes := 0
  MD5name := generateThumbName(imgPath, 1)
  o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
  o_AutoDownScaleIMGs := (AutoDownScaleIMGs>0) ? 1 : 0
  thisImgCall := MD5name imgPath o_bwDithering ColorDepthDithering o_AutoDownScaleIMGs vpIMGrotation RenderOpaqueIMG
  If !FileRexists(imgPath) && (InStr(AprevImgCall, imgPath) || InStr(BprevImgCall, imgPath))
     thisImgCall := InStr(AprevImgCall, imgPath) ? SubStr(AprevImgCall, 2) : SubStr(BprevImgCall, 2)

  gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
  file2load := thumbsCacheFolder "\big-" alwaysOpenwithFIM userHQraw MD5name ".png"
  ignoreCache := (RegExMatch(imgPath, "i)(.\.gif)$") && animGIFsSupport=1) || (AnyWindowOpen=5) || (minimizeMemUsage=1) || StrLen(UserMemBMP)>2 ? 1 : mustReloadIMG
  If (SubStr(AprevImgCall, 2)=thisImgCall && StrLen(AprevGdiBitmap)>2 && ignoreCache=0)
  {
     UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
     thisIMGisDownScaled := AprevImgDownScaled
     Gdip_GetImageDimensions(AprevGdiBitmap, imgW, imgH)
     gdiBitmap := Gdip_CloneBitmap(AprevGdiBitmap)
     gdiBitmapIDcall := AprevImgCall
     extractAmbientalTexture()
     Return 
  } Else If (SubStr(BprevImgCall, 2)=thisImgCall && StrLen(BprevGdiBitmap)>2 && ignoreCache=0)
  {
     UserMemBMP := Gdip_DisposeImage(UserMemBMP, 1)
     thisIMGisDownScaled := BprevImgDownScaled
     Gdip_GetImageDimensions(BprevGdiBitmap, imgW, imgH)
     gdiBitmap := Gdip_CloneBitmap(BprevGdiBitmap)
     gdiBitmapIDcall := BprevImgCall
     extractAmbientalTexture()
     Return
  }

  If (slideShowRunning!=1 && desiredFrameIndex<1) && (A_TickCount - lastInvoked>250)
     GdipCleanMain(6)

  interfaceThread.ahkassign("canCancelImageLoad", 1)
  changeMcursor()
  setWindowTitle("Loading image file...")
  preventDownScaling := (IMGresizingMode=3) || (StrLen(UserMemBMP)>2) || (currentFileIndex=0) || (IMGresizingMode=4 && zoomLevel>1.5) ? 1 : 0
  thisImgPath := (preventDownScaling!=1 && FileExist(file2load) && AutoDownScaleIMGs=1) ? file2load : imgPath
  thisIMGisDownScaled := (thisImgPath!=imgPath && AutoDownScaleIMGs=1) ? 1 : 0
  allowCaching := !minimizeMemUsage
  If StrLen(UserMemBMP)>2
     thisIMGisDownScaled := allowCaching := 0

  oBitmap := LoadBitmapFromFileu(thisImgPath, 0, 0, allowCaching, 1)
  If !oBitmap
     Return "error"

  lastInvoked := A_TickCount
  slowFileLoad := (A_TickCount - coreIMGzeitLoad > 450) ? 1 : 0
  hasFullReloaded := 1

  rawFmt := Gdip_GetImageRawFormat(oBitmap)
  pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
  abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
  If RegExMatch(rawFmt, "i)(gif|tiff)$") && (totalFramesIndex>0)
     multiFrameImg := 1
  Else If (rawFmt="JPEG")
     RotateBMP2exifOrientation(oBitmap)

  If (rawFmt="gif" && totalFramesIndex>0)
  {
     gifLoaded := 1
     CountGIFframes := (animGIFsSupport=1) ? totalFramesIndex : 0
  }

  If (rawFmt="MEMORYBMP")
     GDIbmpFileConnected := 0

  If (AnyWindowOpen=17 && performAutoCropNow=1 && usrAutoCropGenerateSelection=0)
  {
     GDIbmpFileConnected := 0
     hasAutoCropped := 1
     setWindowTitle("Auto-cropping image...")
     xBitmap := Gdip_CloneBitmapArea(oBitmap)
     kBitmap := AutoCropAction(oBitmap, usrAutoCropColorTolerance, usrAutoCropImgThreshold)
     FlipImgV := FlipImgH := vpIMGrotation := performAutoCropNow := 0
     Gdip_DisposeImage(xBitmap, 1)
     If kBitmap
     {
        GDIbmpFileConnected := 0
        Gdip_DisposeImage(oBitmap, 1)
        oBitmap := kBitmap
     }
  }

  Gdip_GetImageDimensions(oBitmap, imgW, imgH)
  totalIMGres := imgW + imgH
  totalScreenRes := ResolutionWidth + ResolutionHeight
  thisImgQuality := (userimgQuality=1) ? 7 : 5
  preventDownScaling := (multiFrameImg=1) || (IMGresizingMode=3) || StrLen(UserMemBMP)>2 || (currentFileIndex=0) || (IMGresizingMode=4 && zoomLevel>1.5) ? 1 : 0
  If (hasAutoCropped!=1 && preventDownScaling!=1 && !FileExist(file2load) && AutoDownScaleIMGs=1 && totalIMGres/totalScreenRes>1.3)
  {
     setWindowTitle("Downscaling large image to viewport...")
     thisImgQuality := (userimgQuality=1) ? 4 : 5
     roImgW := imgW, roImgH := imgH
     calcIMGdimensions(imgW, imgH, ResolutionWidth, ResolutionHeight, newW, newH)
     imgW := newW, imgH := newH
     totalIMGres := newW + newH
     slowFileLoad := 0
     thisIMGisDownScaled := 1
     mustSaveFile := (multiFrameImg!=1 && enableThumbsCaching=1) ? 1 : 0
  } ; Else thisIMGisDownScaled := 0

  If !newW
     newW := imgW
  If !newH
     newH := imgH

  BprevImgDownScaled := AprevImgDownScaled
  AprevImgDownScaled := thisIMGisDownScaled
  oPixFmt := pixFmt := Gdip_GetImagePixelFormat(oBitmap, 2)
  If (!InStr(pixFmt, "argb") || gifLoaded=1)
     brushRequired := 1

  If (InStr(pixFmt, "index") || InStr(pixFmt, "16gray") || InStr(pixFmt, "16rgb") || gifLoaded=1)
     pixFmt := "0x21808"  ; 24-RGB
  Else If InStr(pixFmt, "16argb")
     pixFmt := "0x26200A" ; 32-ARGB
  Else
     pixFmt := Gdip_GetImagePixelFormat(oBitmap, 1)

  changeMcursor()
  If (thisIMGisDownScaled=1 || animGIFplaying=1 || gifLoaded=1 || minimizeMemUsage!=1)
  {
     GDIbmpFileConnected := 0
     rBitmap := Gdip_ResizeBitmap(oBitmap, newW, newH, 0, thisImgQuality, pixFmt)
     Gdip_DisposeImage(oBitmap, 1)
     If (mustSaveFile=1 && thisIMGisDownScaled=1)
        z := Gdip_SaveBitmapToFile(rBitmap, file2load, 90)
  } Else rBitmap := oBitmap

  abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
  If (abortImgLoad<3 && InStr(oPixFmt, "argb") && RenderOpaqueIMG=1 && gifLoaded!=1)
  {
     GDIbmpFileConnected := 0
     setWindowTitle("Removing alpha-channel")
     changeMcursor()
     nBitmap := Gdip_RenderPixelsOpaque(rBitmap, pBrushWinBGR)
     Gdip_DisposeImage(rBitmap, 1)
     rBitmap := nBitmap
     brushRequired := 1
  }

  abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
  If (abortImgLoad<3 && vpIMGrotation>0)
  {
     setWindowTitle("Rotating image at " vpIMGrotation "°...")
     brushRequired := (brushRequired=1) ? pBrushWinBGR : ""
     ; nBitmap := simpleFreeImgRotate(rBitmap, vpIMGrotation)
     changeMcursor()
     nBitmap := Gdip_RotateBitmapAtCenter(rBitmap, vpIMGrotation, brushRequired, imgQuality, pixFmt)
     Gdip_GetImageDimensions(nBitmap, imgW, imgH)
     newW := imgW, newH := imgH
     Gdip_DisposeImage(rBitmap, 1)
     rBitmap := nBitmap
  }

  abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
  If (abortImgLoad<3 && bwDithering=1 && imgFxMode=4)
  {
     GDIbmpFileConnected := 0
     setWindowTitle("Converting image to black and white with dithering...")
     zBitmap := Gdip_BitmapConvertGray(rBitmap, hueAdjust, zatAdjust, lumosGrayAdjust, GammosGrayAdjust)
     Gdip_DisposeImage(rBitmap, 1)
     rBitmap := zBitmap
     E := Gdip_BitmapSetColorDepth(rBitmap, "BW", 1)
  } Else If (usrColorDepth>1)
  {
     infoColorDepth := defineColorDepth()
     setWindowTitle("Converting image to " infoColorDepth)
     E := Gdip_BitmapSetColorDepth(rBitmap, internalColorDepth, ColorDepthDithering)
  }

  BprevImgCall := AprevImgCall
  AprevImgCall := GDIbmpFileConnected MD5name imgPath o_bwDithering ColorDepthDithering o_AutoDownScaleIMGs vpIMGrotation RenderOpaqueIMG
  gdiBitmapIDcall := AprevImgCall
  gdiBitmap := rBitmap
  abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
  extractAmbientalTexture(abortImgLoad)
  BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
  If (allowCaching=1)
  {
     BprevGdiBitmap := AprevGdiBitmap
     AprevGdiBitmap := Gdip_CloneBitmap(gdiBitmap)
  }
  imgW := newW, imgH := newH
}

extractAmbientalTexture(abortImgLoad:=0) {
    currentPixFmt := Gdip_GetImagePixelFormat(gdiBitmap, 2)
    confirmTexBGR := (vpIMGrotation=0 || vpIMGrotation=90 || vpIMGrotation=180 || vpIMGrotation=270) ? 1 : 0
    If (abortImgLoad<3 && usrTextureBGR=1 && confirmTexBGR=1)
    {
       setWindowTitle("Extracting image texture for the window background")
       decideGDIPimageFX(matrix, imageAttribs, pEffect)
       AmbientalTexBrush := Gdip_CreateTextureBrush(gdiBitmap, 3, 3, 3, 150, 150, matrix, 0, 0, 0, imageAttribs)
    }

    preventScreenOff()
    OnImgFileChangeActions(0)
    If (autoPlaySNDs=1)
    {
       AutoPlayAudioFileAssociated()
       identifyAudioMediaLength()
    }
}

OnImgFileChangeActions(forceThis) {
  Static prevImgPath := ""
  imgPath := currentFileIndex "=" getIDimage(currentFileIndex)
  If (imgPath=prevImgPath && forceThis=0)
  {
     Return
  } Else
  {
     SetTimer, RemoveTooltip, -200
     If (LimitSelectBoundsImg!=1 && activateImgSelection=1)
        correctActiveSelectionAreaViewPort()

     If (AutoDownScaleIMGs=2)
        AutoDownScaleIMGs := 1
     If (hSNDmedia && autoPlaySNDs!=1)
        StopMediaPlaying()
     If (slideShowRunning=1 && (animGIFplaying!=1 || totalFramesIndex<2))
        interfaceThread.ahkPostFunction("dummySlideshow")
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
    imgPath := getIDimage(currentFileIndex)
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
       imgPath := getIDimage(currentFileIndex)
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
   2ndMaxV := (2ndMaxVa + 2ndMaxVb)//2
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
   Scale := imgHUDbaseUnit/40
   If (rangeC<2)
      2ndMaxV := modePointK2[1] - 1

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

capSelectionRelativeCoords() {
   If (prcSelX1<0)
      prcSelX1 := 0
   Else If (prcSelX1>=1)
      prcSelX1 := 0.9

   If (prcSelY1<0)
      prcSelY1 := 0
   Else If (prcSelY1>=1)
      prcSelY1 := 0.9

   If (prcSelX2<0.001)
      prcSelX2 := 0.001
   Else If (prcSelX2>1)
      prcSelX2 := 1

   If (prcSelY2<0.001)
      prcSelY2 := 0.001
   Else If (prcSelY2>1)
      prcSelY2 := 1
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
   startZeit := A_TickCount
   If (Width=1 && Height=1)
      Gdip_GetImageDimensions(whichImg, Width, Height)

   If ((Width//10*Height//10)>16500)
   {
      calcIMGdimensions(Width, Height, 900, 900, newWidth, newHeight)
      rBitmap := Gdip_ResizeBitmap(whichImg, newWidth, newHeight, 0, 3)
      If !rBitmap
         Return -1

      whichImg := rBitmap
   }

   Gdip_GetImageDimensions(whichImg, Width, Height)
   xCrop := Width//11
   yCrop := Height//11
   wCrop := Width - xCrop*2 + 1
   hCrop := Height - yCrop*2 + 1

   cropBmp := Gdip_CloneBitmapArea(whichImg, xCrop, yCrop, wCrop, hCrop)
   If !cropBmp
      Return -1

   brLvlArray := [], ArrChR := [], ArrChG := [], ArrChB := []
   rMinBrLvl := minBrLvl := 256
   modePointV := lumosAdjust := 1
   maxBrLvl := sumTotalBr := countTotalPixelz := thisBrLvl := 0
   GammosAdjust := countBrightPixelz := countMidPixelz := countDarkPixelz := 0

   Gdip_GetHistogram(cropBmp, 2, ArrChR, ArrChG, ArrChB)
   pEffect := Gdip_CreateEffect(6, 0, -99, 0)
   rT := Gdip_BitmapApplyEffect(cropBmp, pEffect)
   Gdip_DisposeEffect(pEffect)
   Gdip_GetHistogram(cropBmp, 3, brLvlArray, 0, 0)
   If (cropBmp && wasOk=1)
      Gdip_DisposeImage(cropBmp, 1)

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
          BrLvlDifs := max(NrPixR, NrPixG, NrPixB) - min(NrPixR, NrPixG, NrPixB)
          If (BrLvlDifs<minMaxThreshold*2) || (nrPixR+nrPixB+nrPixB<minMaxThreshold*3)
             Continue
          tNrPixR += nrPixR
          tNrPixG += nrPixG
          tNrPixB += nrPixB
          tNrPixAll += max(NrPixR, NrPixG, NrPixB)
          AllBrLvlDifs += BrLvlDifs
      }
   }
   BrLvlDiffX := max(tNrPixR, tNrPixG, tNrPixB) - min(tNrPixR, tNrPixG, tNrPixB)
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
   ; hmmu := max(v1a, v2a, v3a) " -- " min(v1a, v2a, v3a) " -- " v1a "," v2a "," v3a

   BrLvlDiffA := max(v1a, v2a, v3a) - min(v1a, v2a, v3a)
   BrLvlDiffB := max(v1b, v2b, v3b) - min(v1b, v2b, v3b)
   BrLvlDiffE := max(v1e, v2e, v3e) - min(v1e, v2e, v3e)
   PrcLvlDiffA := Round((BrLvlDiffA/max(v1a, v2a, v3a))*100, 4)
   PrcLvlDiffB := Round((BrLvlDiffB/max(v1b, v2b, v3b))*100, 4)
   PrcLvlDiffE := Round((BrLvlDiffE/max(v1e, v2e, v3e))*100, 4)
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
   chnlDiffs := max(avgBrLvlR, avgBrLvlG, avgBrLvlB) - min(avgBrLvlR, avgBrLvlG, avgBrLvlB)
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

   ; execTime := A_TickCount - startZeit
   ; ToolTip, % redLevelu ",avgRGB=" avgBrLvlR ", " avgBrLvlG ", " avgBrLvlB ", ChnlDiff=" chnlDiffs  ", AvgLvlDif=" avgLvlsDiff " %, diffA=" PrcLvlDiffA " %, diffE=" PrcLvlDiffE " %, diffX=" PrcLvlDiffX "/" PrcLvlDiffXa "% `nTh=" minMaxThreshold ", min=" minBrLvl "/" rMinBrLvl ", max=" maxBrLvl ", A=" avgBrLvl ", mP=" modePointK " [" modePointV " / " percmodePx "% ]"  ",`nL=" percBrgPx "%, D=" percDrkPx "%, Dl=" percLowPx "%, Mr=" percMidPx "% / Mo=" percMidPixu "%, oAvg=" oPercAvgPx "%, fAvg=" percAvgPx "%`ncL=" lumosAdjust ", cG=" GammosAdjust ", cS=" satAdjust ", T=" execTime "ms",,, 2
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
       If (imgFxMode!=1 || IMGresizingMode!=1 || animGIFplaying=1 || desiredFrameIndex>0)
       {
          prevImgPath := 0
          HistogramBMP := Gdip_DisposeImage(HistogramBMP, 1)
          tempBMP := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
          thisPosX := (DestPosX<0) ? 0 : DestPosX
          thisPosY := (DestPosY<0) ? 0 : DestPosY
          thisW := (newW>mainWidth) ? mainWidth : newW
          thisH := (newH>mainHeight) ? mainHeight : newH
          thisVPimg := Gdip_CloneBitmapArea(tempBMP, thisPosX + 1, thisPosY + 1, thisW - 2, thisH - 2)
          createHistogramBMP(thisVPimg)
          Gdip_DisposeImage(thisVPimg, 1)
          Gdip_DisposeImage(tempBMP, 1)
       } Else If (prevImgPath!=thisImgCall) && (A_TickCount - lastInvoked>50)
       {
          lastInvoked := A_TickCount
          prevImgPath := thisImgCall
          HistogramBMP := Gdip_DisposeImage(HistogramBMP, 1)
          createHistogramBMP(gdiBitmap)
       }
    }

    If (mode=2 && IMGresizingMode=4 && IMGlargerViewPort=1)
    {
       thisX := (editingSelectionNow=1 && activateImgSelection=1) ? mainWidth//8 : mainWidth//7
       thisY := (editingSelectionNow=1 && activateImgSelection=1) ? mainHeight//6 : mainHeight//5
       thisW := mainWidth - thisX*2
       thisH := mainHeight - thisY*2
       thisThick := imgHUDbaseUnit/9.7
       Gdip_SetPenWidth(pPen1d, thisThick)
       Gdip_DrawRectangle(glPG, pPen1d, thisX, thisY, thisW, thisH)
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
              If (DestPosY>-newH+mainHeight+marginErr)
                 Gdip_FillRectangle(glPG, pBrush, 0, mainHeight - lineThickns2//2, mainWidth, lineThickns2//2)
          }

          If (newW>mainWidth)
          {
             If (DestPosX<-marginErr)
                Gdip_FillRectangle(glPG, pBrush, 0, 0, lineThickns2//2, mainHeight)
              If (DestPosX>-newW+mainWidth+marginErr)
                 Gdip_FillRectangle(glPG, pBrush, mainWidth - lineThickns2//2, 0, lineThickns2//2, mainHeight)
          }
       }

       imgPathArray := resultedFilesList[currentFileIndex]
       imgPathSelected := imgPathArray[2]
       If (imgPathSelected=1)
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
               whichBrush := (A_Index - 1 <= desiredFrameIndex) ? pBrushA : pBrushE
            Gdip_FillEllipse(glPG, whichBrush, centerPos + bulletSize * (A_Index - 1), mainHeight - bulletSize, bulletSize, bulletSize)
            If (A_index>maxBullets)
               Break
        }
    }

    If (adjustNowSel=1)
       Return

    If (showHistogram=1 && HistogramBMP)
    { 
       Gdip_GetImageDimensions(HistogramBMP, imgW, imgH)
       thisPosX := (scrollBarVx>0) ? scrollBarVx - imgW : mainWidth - imgW
       thisPosY := (scrollBarHy>0) ? scrollBarHy - imgH : mainHeight - imgH
       If (FlipImgH=1 || FlipImgV=1)
       {
          tempBMP := Gdip_CloneBitmap(HistogramBMP)
          flipBitmapAccordingToViewPort(tempBMP, 1)
          Gdip_DrawImage(glPG, tempBMP, thisPosX, thisPosY,,,,,,, 0.9)
          Gdip_DisposeImage(tempBMP, 1)
       } Else Gdip_DrawImage(glPG, HistogramBMP, thisPosX, thisPosY,,,,,,, 0.9)
    }

    additionalHUDelements(mode, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY, 1)
}

additionalHUDelements(mode:=0, mainWidth:=0, mainHeight:=0, newW:=0, newH:=0, DestPosX:=0, DestPosY:=0, directRefresh:=0) {
    Critical, on

    Gdip_GraphicsClear(2NDglPG, "0x00" WindowBGRcolor)
    setMainCanvasTransform(mainWidth, mainHeight, 2NDglPG)

    If (activateImgSelection=1 && mode=2)
    {
       drawImgSelectionOnWindow("prev", "-", "-", "-", mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    } Else If (activateImgSelection=1 && mode=1)
    {
       drawImgSelectionOnWindow("active", "-", "-", "-", mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    } Else If (activateImgSelection=1 && mode=3)
    {
       drawImgSelectionOnWindow("return", "-", "-", "-", mainWidth, mainHeight)
       livePreviewsImageEditing()
    }

    If (showImgAnnotations=1 && !AnyWindowOpen)
       drawAnnotationBox(mainWidth, mainHeight)

    If (showInfoBoxHUD=1 && !AnyWindowOpen)
       drawinfoBox(mainWidth, mainHeight, directRefresh)

    Gdip_ResetWorldTransform(2NDglPG)
    r2 := UpdateLayeredWindow(hGDIselectwin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
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

    ; If (imgFxMode>1)
    ;   pEffect := Gdip_CreateEffect(2, postSharpenRadius, postSharpenAmount, 0)
    If (thisFXapplies=1 && applyAdjusts=1 && o_bwDithering=0)
       pEffect := Gdip_CreateEffect(6, hueAdjust, thisZatAdjust, 0)
}

QPV_ShowImgonGuiPrev(oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgPath) {
    Critical, on
    Static prevUpdate, displayFastWas := 1
    If (A_TickCount - prevUpdate > 700)
       displayFastWas := 1

    prevUpdate := A_TickCount
    thisZeit := A_TickCount
    Gdip_GraphicsClear(glPG, "0x77" WindowBgrColor)
    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    whichImg := (usePrevious=1 && gdiBitmapSmall && imgFxMode!=8 && animGIFplaying!=1) ? gdiBitmapSmall : gdiBitmap
    Gdip_GetImageDimensions(whichImg, imgW, imgH)
    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    thisIMGres := imgW + imgH
    thisWinRes := mainWidth + mainHeight
    interpoImgQuality := (userimgQuality=1) ? 7 : 5
    If (displayFastWas=0 && userimgQuality=1)
    {
       thisLowMode := 1
       Gdip_SetInterpolationMode(glPG, 5)
    }

    zL := (zoomLevel<1) ? 1 : zoomLevel*2
    whichBrush := pBrushHatchLow
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
       Gdip_SetInterpolationMode(glPG, interpoImgQuality)

    ; ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
    prevDestPosX := DestPosX
    prevDestPosY := DestPosY
    whichMode := (imgFxMode=8 || animGIFplaying=1) ? 1 : 2
    drawHUDelements(whichMode, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY, imgPath)
    Gdip_ResetWorldTransform(glPG)
    If imageAttribs
       Gdip_DisposeImageAttributes(imageAttribs)
    If (thisLowMode!=1)
       displayFastWas := (A_TickCount - thisZeit < 150) ? 1 : 0

    prevDrawingMode := (thisLowMode=1 || userimgQuality=0) ? 3 : 2
    drawModeBzeit := A_TickCount - thisZeit
    If (CountGIFframes>1 && !AnyWindowOpen && animGIFsSupport=1 && prevAnimGIFwas!=imgPath)
    {
       setGIFframesDelay()
       autoChangeDesiredFrame("start", imgPath)
       SetTimer, autoChangeDesiredFrame, % GIFspeedDelay
       r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)
    } Else
    {
       autoChangeDesiredFrame("stop")
       r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)
    }

    r := (r1!=0 || !r2) ? 0 : 1
    Return r
}

drawImgSelectionOnWindow(operation, theMsg:="", colorBox:="", dotActive:="", mainWidth:=0, mainHeight:=0, newW:=0, newH:=0, DestPosX:=0, DestPosY:=0) {
     Static prevMsg, infoBoxBMP, lineThickns, infoW, infoH, pBr0, zPen
          , infoPosX, infoPosY, prevuDPx, prevuDPy, prevNewW, prevNewH

     SelDotsSize := dotsSize := (PrefsLargeFonts=1) ? imgHUDbaseUnit//3 : imgHUDbaseUnit//3.25
     maxSelX := prevMaxSelX, maxSelY := prevMaxSelY
     ; ForceRefreshNowThumbsList()
     If (operation="return")
     {
        infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        operation := "active"
        newW := prevNewW, newH := prevNewH
        ; DestPosX := prevuDPx, DestPosY := prevuDPy
        DestPosX := prevDestPosX, DestPosY := prevDestPosY
        ; clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
     }

     If !zPen
     {
        zPen := Gdip_CreatePen("0x99446644", imgHUDbaseUnit//10)
        ; Gdip_SetPenDashArray(zPen, "0.2,0.2")
     }

     If (operation="init")
     {
        clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
        If hitTestSelectionPath
        {
           Gdip_DeletePath(hitTestSelectionPath)
           hitTestSelectionPath := ""
        }

        infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        setMainCanvasTransform(mainWidth, mainHeight, 2NDglPG)
        InfoW := InfoH := ""
        lineThickns := imgHUDbaseUnit//9
        Gdip_SetPenWidth(zPen, imgHUDbaseUnit//13)
     } Else If (operation="prev")
     {
        createDefaultSizedSelectionArea(DestPosX, DestPosY, newW, newH, maxSelX, maxSelY, mainWidth, mainHeight)
        clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
        prevNewH := newH, prevNewW := newW
        prevuDPx := DestPosX, prevuDPy := DestPosY
        lineThickns :=  imgHUDbaseUnit//10
        Gdip_SetPenWidth(pPen1, lineThickns)
        nImgSelX1 := min(imgSelX1, imgSelX2)
        nImgSelY1 := min(imgSelY1, imgSelY2)
        nimgSelX2 := max(imgSelX1, imgSelX2)
        nimgSelY2 := max(imgSelY1, imgSelY2)
        If (editingSelectionNow!=1 && LimitSelectBoundsImg=1)
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
 
        imgSelW := max(zImgSelX1, zImgSelX2) - min(zImgSelX1, zImgSelX2)
        imgSelH := max(zImgSelY1, zImgSelY2) - min(zImgSelY1, zImgSelY2)
        If (imgSelW<35)
           imgSelW := 35
        If (imgSelH<35)
           imgSelH := 35
 
        imgSelPx := prevDestPosX + min(zImgSelX1, zImgSelX2)
        imgSelPy := prevDestPosY + min(zImgSelY1, zImgSelY2)
        If (editingSelectionNow=1)
        {
           If (imgSelPx>mainWidth - 40)
              imgSelPx := mainWidth - 40
           If (imgSelPy>mainHeight - 40)
              imgSelPy := mainHeight - 40
        }
        selDotX := imgSelPx - dotsSize//2
        selDotY := imgSelPy - dotsSize//2
        selDotAx := imgSelPx + imgSelW - dotsSize//2
        selDotAy := imgSelPy + imgSelH - dotsSize//2
        selDotBx := imgSelPx + imgSelW - dotsSize//2
        selDotBy := imgSelPy - dotsSize//2
        selDotCx := imgSelPx - dotsSize//2
        selDotCy := imgSelPy + imgSelH - dotsSize//2
        selDotDx := imgSelPx + imgSelW//2 - dotsSize
        selDotDy := imgSelPy + imgSelH//2 - dotsSize

        ; Gdip_FillRectangle(2NDglPG, pBrush, imgSelPx, imgSelPy, imgSelW, imgSelH)
        If (EllipseSelectMode=1)
           Gdip_DrawEllipse(2NDglPG, pPen1, imgSelPx, imgSelPy, imgSelW, imgSelH)
        Else
           Gdip_DrawRectangle(2NDglPG, pPen1, imgSelPx, imgSelPy, imgSelW, imgSelH)
        Gdip_SetClipRect(2NDglPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
        Gdip_FillRectangle(2NDglPG, pBrushF, 0, 0, mainWidth, mainHeight)
        Gdip_ResetClip(2NDglPG)
     } Else If (operation="active")
     {
        prevNewH := newH, prevNewW := newW
        prevuDPx := DestPosX, prevuDPy := DestPosY
        lineThickns := imgHUDbaseUnit//9
        If (editingSelectionNow=0)
           lineThickns :=  imgHUDbaseUnit//13
 
        Gdip_SetPenWidth(zPen, imgHUDbaseUnit//13)
        pPen := (editingSelectionNow=1) ? pPen1d : pPen1
        Gdip_SetPenWidth(pPen, lineThickns)
        createDefaultSizedSelectionArea(DestPosX, DestPosY, newW, newH, maxSelX, maxSelY, mainWidth, mainHeight)

        If (LimitSelectBoundsImg=1)
        {
           If (imgSelX1<0)
              imgSelX1 := 0
           If (imgSelY1<0)
              imgSelY1 := 0
    
           If (imgSelX2<0)
              imgSelX2 := 0
           If (imgSelY2<0)
              imgSelY2 := 0
        }
        nImgSelX1 := min(imgSelX1, imgSelX2)
        nImgSelY1 := min(imgSelY1, imgSelY2)
        nimgSelX2 := max(imgSelX1, imgSelX2)
        nimgSelY2 := max(imgSelY1, imgSelY2)
        imgSelX1 := nImgSelX1, imgSelY1 := nImgSelY1 
        imgSelX2 := nimgSelX2, imgSelY2 := nimgSelY2 
 
        prcSelX1 := imgSelX1/maxSelX
        prcSelY1 := imgSelY1/maxSelY
        prcSelX2 := imgSelX2/maxSelX
        prcSelY2 := imgSelY2/maxSelY
        If (LimitSelectBoundsImg=1)
           capSelectionRelativeCoords()

        If (editingSelectionNow!=1 && LimitSelectBoundsImg=1)
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
 
        imgSelW := max(zImgSelX1, zImgSelX2) - min(zImgSelX1, zImgSelX2)
        imgSelH := max(zImgSelY1, zImgSelY2) - min(zImgSelY1, zImgSelY2)
        If (imgSelW<35)
           imgSelW := 35
        If (imgSelH<35)
           imgSelH := 35
 
        imgSelPx := DestPosX + min(zImgSelX1, zImgSelX2)
        imgSelPy := DestPosY + min(zImgSelY1, zImgSelY2)
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
 
        ; Gdip_FillRectangle(2NDglPG, pBrushC, imgSelPx, imgSelPy, imgSelW, imgSelH)
        whichPen := (EllipseSelectMode=1) ? zPen : pPen
        Gdip_DrawRectangle(2NDglPG, whichPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
        ; If (EllipseSelectMode=1) || ((showSelectionGrid=1 || imgSelLargerViewPort=1) && (EllipseSelectMode!=1))
           ; Gdip_DrawEllipse(2NDglPG, zPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
        If (EllipseSelectMode=1)
           Gdip_DrawEllipse(2NDglPG, pPen, imgSelPx, imgSelPy, imgSelW, imgSelH)

        thisExterior := (editingSelectionNow=1) ? pBrushE : pBrushF
        Gdip_SetClipRect(2NDglPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
        Gdip_FillRectangle(2NDglPG, thisExterior, 0, 0, mainWidth, mainHeight)
        Gdip_ResetClip(2NDglPG)

        If (showSelectionGrid=1 || imgSelLargerViewPort=1)
        {
           If (imgSelLargerViewPort=1)
           {
              Gdip_DrawRectangle(2NDglPG, whichPen, 1, 1, mainWidth - 1, mainHeight - 1)
              Gdip_DrawRectangle(2NDglPG, whichPen, mainWidth*0.15, mainHeight*0.15, mainWidth - mainWidth*0.3, mainHeight - mainHeight*0.3)
           }
           Gdip_SetClipRect(2NDglPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 0)
           Gdip_DrawRectangle(2NDglPG, zPen, imgSelPx + Round(imgSelW * 0.33), imgSelPy - 900, imgSelW - Round(imgSelW * 0.33) * 2, imgSelH + 2000)
           Gdip_DrawRectangle(2NDglPG, zPen, imgSelPx - 900, imgSelPy + Round(imgSelH * 0.33), imgSelW + 2000, imgSelH - Round(imgSelH * 0.33) * 2)
           Gdip_ResetClip(2NDglPG)
        }

        selDotX := imgSelPx - dotsSize//2
        selDotY := imgSelPy - dotsSize//2
        selDotAx := imgSelPx + imgSelW - dotsSize//2
        selDotAy := imgSelPy + imgSelH - dotsSize//2
        selDotBx := imgSelPx + imgSelW - dotsSize//2
        selDotBy := imgSelPy - dotsSize//2
        selDotCx := imgSelPx - dotsSize//2
        selDotCy := imgSelPy + imgSelH - dotsSize//2
        selDotDx := imgSelPx + imgSelW//2 - dotsSize
        selDotDy := imgSelPy + imgSelH//2 - dotsSize
        If (editingSelectionNow=1)
        {
           If hitTestSelectionPath
              Gdip_DeletePath(hitTestSelectionPath)
           If (imgSelLargerViewPort!=1)
              hitTestSelectionPath := Gdip_CreatePath()
           If (FlipImgV=1)
              imgSelPy := mainHeight - imgSelPy - imgSelH
           If (FlipImgH=1)
              imgSelPx := mainWidth - imgSelPx - imgSelW
           If (imgSelLargerViewPort!=1)
              Gdip_AddPathRectangle(hitTestSelectionPath, imgSelPx, imgSelPy, imgSelW, imgSelH)
           Gdip_FillRectangle(2NDglPG, pBrushD, selDotX, selDotY, dotsSize, dotsSize)
           Gdip_FillRectangle(2NDglPG, pBrushD, SelDotAx, SelDotAy, dotsSize, dotsSize)
           Gdip_FillRectangle(2NDglPG, pBrushD, SelDotBx, SelDotBy, dotsSize, dotsSize)
           Gdip_FillRectangle(2NDglPG, pBrushD, SelDotCx, SelDotCy, dotsSize, dotsSize)
           If (imgEditPanelOpened=1)
           {
              Gdip_FillEllipse(2NDglPG, pBrushD, SelDotDx, SelDotDy, dotsSize*2, dotsSize*2)
              Gdip_FillEllipse(2NDglPG, pBrushE, SelDotDx + dotsSize//3, SelDotDy + dotsSize//3, dotsSize*1.33, dotsSize*1.33)
           }
        }
     } Else If (operation="live")
     {
        lineThickns := imgHUDbaseUnit/9
        Gdip_GraphicsClear(2NDglPG, "0x00" WindowBGRcolor)
        nImgSelX1 := min(imgSelX1, imgSelX2)
        nImgSelY1 := min(imgSelY1, imgSelY2)
        nimgSelX2 := max(imgSelX1, imgSelX2)
        nimgSelY2 := max(imgSelY1, imgSelY2)
        imgSelX1 := nImgSelX1 
        imgSelY1 := nImgSelY1 
        imgSelX2 := nimgSelX2 
        imgSelY2 := nimgSelY2 
        zImgSelX1 := (nImgSelX1*zoomLevel)
        zImgSelX2 := (nImgSelX2*zoomLevel)
        zImgSelY1 := (nImgSelY1*zoomLevel)
        zImgSelY2 := (nImgSelY2*zoomLevel)
   
        imgSelW := max(zImgSelX1, zImgSelX2) - min(zImgSelX1, zImgSelX2)
        imgSelH := max(zImgSelY1, zImgSelY2) - min(zImgSelY1, zImgSelY2)
        If (imgSelW<35)
           imgSelW := 35
        If (imgSelH<35)
           imgSelH := 35
   
        imgSelPx := prevuDPx + min(zImgSelX1, zImgSelX2)
        imgSelPy := prevuDPy + min(zImgSelY1, zImgSelY2)
        If (imgEditPanelOpened!=1)
        {
           Gdip_SetClipRect(2NDglPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 4)
           Gdip_FillRectangle(2NDglPG, pBrushC, 0, 0, mainWidth, mainHeight)
           Gdip_ResetClip(2NDglPG)
        }

        If (imgSelW>125 && imgSelH>125 && noTooltipMSGs=0 && minimizeMemUsage!=1 && dotActive!=10)
        {
           cornersPreview := coreCaptureImgCorners(gdiBitmap, 6, 100)
           Gdip_GetImageDimensions(cornersPreview, cImgW, cImgH)
           cX := imgSelPx + imgSelW//2 - cImgW//2
           cY := imgSelPy + imgSelH//2 - cImgH//2
           cX := capValuesInRange(cX, 0, mainWidth - cImgW)
           cY := capValuesInRange(cY, 0, mainHeight - cImgH)
           Gdip_DrawImageFast(2NDglPG, cornersPreview, cX, cY)
           Gdip_DisposeImage(cornersPreview, 1)
        }

        If (noTooltipMSGs=0 && minimizeMemUsage!=1)
        {
           infoBoxBMP := drawTextInBox(theMsg, OSDFontName, OSDfntSize//1.3, mainWidth//2, mainHeight//2, OSDtextColor, "0xFF" OSDbgrColor, 1, 1)
           colorBoxH := colorBox ? imgHUDbaseUnit//7 : 1
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
              Gdip_FillRectangle(2NDglPG, pBr0, infoPosX, infoPosY + infoH, infoW, colorBoxH)
              Gdip_DeleteBrush(pBr0)
           }
           Gdip_DrawImage(2NDglPG, infoBoxBMP, infoPosX, infoPosY,,,,,,, 0.8)
           infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        }

        ; Gdip_FillRectangle(2NDglPG, pBrushC, imgSelPx, imgSelPy, imgSelW, imgSelH)
        If (showSelectionGrid=1 || imgSelLargerViewPort=1 || EllipseSelectMode=1)
        {
           pPen := (editingSelectionNow=1) ? pPen1d : pPen1
           whichPen := (EllipseSelectMode=1) ? pPen : zPen
           ; Gdip_DrawEllipse(2NDglPG, zPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
           If (EllipseSelectMode=1)
           {
              Gdip_SetPenWidth(pPen, lineThickns)
              Gdip_DrawEllipse(2NDglPG, pPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
           }
        }

        If (showSelectionGrid=1 || imgSelLargerViewPort=1)
        {
           Gdip_SetClipRect(2NDglPG, imgSelPx, imgSelPy, imgSelW, imgSelH, 0)
           Gdip_DrawRectangle(2NDglPG, zPen, imgSelPx + Round(imgSelW * 0.33), imgSelPy - 900, imgSelW - Round(imgSelW * 0.33) * 2, imgSelH + 2000)
           Gdip_DrawRectangle(2NDglPG, zPen, imgSelPx - 900, imgSelPy + Round(imgSelH * 0.33), imgSelW + 2000, imgSelH - Round(imgSelH * 0.33) * 2)
           Gdip_ResetClip(2NDglPG)
        }

        Gdip_DrawLine(2NDglPG, zPen, zImgSelX1 + prevDestPosX, 0, zImgSelX1 + prevDestPosX, mainHeight)
        Gdip_DrawLine(2NDglPG, zPen, 0, zImgSelY1 + prevDestPosY, mainWidth, zImgSelY1 + prevDestPosY)
        Gdip_DrawLine(2NDglPG, zPen, zImgSelX2 + prevDestPosX, 0, zImgSelX2 + prevDestPosX, mainHeight)
        Gdip_DrawLine(2NDglPG, zPen, 0, zImgSelY2 + prevDestPosY, mainWidth, zImgSelY2 + prevDestPosY)
        Gdip_DrawRectangle(2NDglPG, zPen, imgSelPx, imgSelPy, imgSelW, imgSelH)
        selDotX := imgSelPx - dotsSize//2
        selDotY := imgSelPy - dotsSize//2
        selDotAx := imgSelPx + imgSelW - dotsSize//2
        selDotAy := imgSelPy + imgSelH - dotsSize//2
        selDotBx := imgSelPx + imgSelW - dotsSize//2
        selDotBy := imgSelPy - dotsSize//2
        selDotCx := imgSelPx - dotsSize//2
        selDotCy := imgSelPy + imgSelH - dotsSize//2
        selDotDx := imgSelPx + imgSelW//2 - dotsSize
        selDotDy := imgSelPy + imgSelH//2 - dotsSize
        Gdip_FillRectangle(2NDglPG, pBrushD, selDotX, selDotY, dotsSize, dotsSize)
        Gdip_FillRectangle(2NDglPG, pBrushD, SelDotAx, SelDotAy, dotsSize, dotsSize)
        Gdip_FillRectangle(2NDglPG, pBrushD, SelDotBx, SelDotBy, dotsSize, dotsSize)
        Gdip_FillRectangle(2NDglPG, pBrushD, SelDotCx, SelDotCy, dotsSize, dotsSize)
        If (imgEditPanelOpened=1 && dotActive=10)
        {
            Gdip_FillEllipse(2NDglPG, pBrushD, SelDotDx, SelDotDy, dotsSize*2, dotsSize*2)
            Gdip_FillEllipse(2NDglPG, pBrushE, SelDotDx + dotsSize//3, SelDotDy + dotsSize//3, dotsSize*1.33, dotsSize*1.33)
        }

        If (imgEditPanelOpened=1)
        {
           r2 := UpdateLayeredWindow(hGDIinfosWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
           livePreviewsImageEditing()
        } Else
           r2 := UpdateLayeredWindow(hGDIselectWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
     } Else If (operation="end")
     {
        InfoW := InfoH := ""
        ; Gdip_ResetWorldTransform(2NDglPG)
        infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
        If pBr0
        {
           Gdip_DeleteBrush(pBr0)
           pBr0 := ""
        }

        Gdip_ResetWorldTransform(2NDglPG)
        SetTimer, dummyRefreshImgSelectionWindow, -25
     }
}

dummyRefreshImgSelectionWindow() {
     If (imgSelX2=-1 && imgSelY2=-1 && activateImgSelection=1)
     {
        dummyTimerDelayiedImageDisplay(25)
        Return
     }
     GetClientSize(mainWidth, mainHeight, PVhwnd)
     additionalHUDelements(3, mainWidth, mainHeight)
}

QPV_ShowImgonGui(oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgPath, ForceIMGload, hasFullReloaded, ByRef wasPrevious) {
    Critical, on
    Static IDviewPortCache, PREVtestIDvPcache
    If (ForceIMGload=1)
       IDviewPortCache := PREVtestIDvPcache := ""

    createGDIPcanvas(mainWidth, mainHeight)
    testIDvPcache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight desiredFrameIndex
    If (CountGIFframes>1 && !AnyWindowOpen && animGIFsSupport=1 && prevAnimGIFwas!=imgPath)
       mustPlayAnim := 1
    Else
       DestroyGIFuWin()

    If (usePrevious=1 && testIDvPcache!=PREVtestIDvPcache) || (mustPlayAnim=1) || (imgFxMode=8 && InStr(currentPixFmt, "argb") && RenderOpaqueIMG!=1)
    {
       wasPrevious := usePrevious
       IDviewPortCache := PREVtestIDvPcache := ""
       r := QPV_ShowImgonGuiPrev(oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgPath)
       oldZoomLevel := ""
       Return r
    } Else wasPrevious := 0

    startZeit := A_TickCount  
    oldZoomLevel := matrix := ""
    prevDrawingMode := 1
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
    If (minimizeMemUsage=1)
       diffIMGdecX := diffIMGdecY := 0

    zL := (zoomLevel<1) ? 1 : zoomLevel*2
    whichBrush := pBrushHatchLow
    If (imgFxMode!=8)
    {
       If (InStr(currentPixFmt, "ARGB") && RenderOpaqueIMG!=1)
          Gdip_FillRectangle(glPG, whichBrush, DestPosX + 1, DestPosY + 1, newW - 2, newH - 2)
       Else
          Gdip_FillRectangle(glPG, pBrushWinBGR, DestPosX, DestPosY, newW, newH)
    }

    thisIDviewPortCache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight usePrevious desiredFrameIndex
    If (thisIDviewPortCache!=IDviewPortCache || !ViewPortBMPcache || CountGIFframes>1) && (usePrevious!=1)
    {
       prevDestPosX := DestPosX
       prevDestPosY := DestPosY
       canvasClipped := (diffIMGdecX || diffIMGdecY) && (IMGresizingMode=4) ? 1 : 0
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
             prevGDIvpCache := Gdip_DisposeImage(prevGDIvpCache, 1)
             prevGDIvpCache := Gdip_CloneBitmap(ViewPortBMPcache)
          }

          ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
          IDviewPortCache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight usePrevious desiredFrameIndex
          PREVtestIDvPcache := imgPath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight desiredFrameIndex
          ViewPortBMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
       }
    } Else mustDisplay := 1
    ; tooltip, % dontMove " - " diffIMGdecX " - " diffIMGdecY " - " r3

    If (diffIMGdecX || diffIMGdecY) && (prevGDIvpCache && canvasClipped=1)
    {
       r3 := Gdip_DrawImageFast(glPG, prevGDIvpCache, diffIMGdecX, diffIMGdecY)
       mustRecache := 1
    }

    diffIMGdecX := diffIMGdecY := 0
    If (mustRecache=1)
    {
       ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
       ViewPortBMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
    } Else prevGDIvpCache := Gdip_DisposeImage(prevGDIvpCache, 1)

    setMainCanvasTransform(mainWidth, mainHeight)
    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    If (pEffect || imageAttribs)
       r1 := Gdip_DrawImageFX(glPG, ViewPortBMPcache, 0, 0, 0, 0, mainWidth, mainHeight, matrix, pEffect, imageAttribs)
    Else
       r1 := Gdip_DrawImageFast(glPG, ViewPortBMPcache)

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
    Gdip_ResetWorldTransform(glPG)
    If (minimizeMemUsage!=1 && mustDisplay=1 && slideShowRunning=1 && doSlidesTransitions=1 && slideShowDelay>950 && GDIfadeVPcache && animGIFplaying!=1)
    {
       setWindowTitle(pVwinTitle, 1)
       ForceRefreshNowThumbsList()
       tempBMP := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
       Gdip_DrawImageFast(glPG, tempBMP)
       r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, 0, 0, mainWidth, mainHeight)
       ToggleVisibilityWindow("show", hGDIthumbsWin)

       Gdip_DrawImageFast(glPG, GDIfadeVPcache)
       r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)
       Loop, 255
       {
           opacity := 255 - A_Index*12
           If (opacity<2)
              Break

           r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight, opacity)
           Sleep, 1
       }
       Gdip_DrawImageFast(glPG, tempBMP)
       Gdip_DisposeImage(tempBMP, 1)
       Gdip_GraphicsClear(2NDglPG, "0xFF" WindowBGRcolor)
       imageHasFaded := 1
    }

    If (mustDisplay=1)
       r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)

    If (imageHasFaded=1)
       UpdateLayeredWindow(hGDIthumbsWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)

    If pEffect
       Gdip_DisposeEffect(pEffect)

    If imageAttribs
       Gdip_DisposeImageAttributes(imageAttribs)

    r := (r1!=0 || !r2) ? 0 : 1
    totalZeit := A_TickCount - startZeitIMGload
    thisZeit := A_TickCount - startZeit
    If (totalZeit<150)
       prevFastDisplay := A_TickCount

    ; prevFullIMGload := A_TickCount
    LastPrevFastDisplay := (totalZeit<125 && usePrevious=0) ? 1 : 0
    PannedFastDisplay := (thisZeit<100 && usePrevious=0 && canvasClipped=1) || (canvasClipped!=1 && minimizeMemUsage!=1) ? 1 : 0
    drawModeAzeit := A_TickCount - startZeit
    If (hasFullReloaded=1 && imageHasFaded!=1)
    {
       fullLoadZeit := A_TickCount - startZeitIMGload
       fullLoadZeit2 := (fullLoadZeit + drawModeCzeit)//2
       drawModeCzeit := max(fullLoadZeit, fullLoadZeit2)
    }

    ; ToolTip, % thisZeit ", " totalZeit ", " drawModeCzeit "==" prevGDIvpCache ,,,2
    Return r
}

getCaptionStyle(hwnd) {
  WinGet, Stylu, Style, ahk_id %hwnd%
  r := (Stylu & 0xC00000) ? 0 : 1
  Return r
}

getTopMopStyle(hwnd) {
  WinGet, Stylu, ExStyle, ahk_id %hwnd%
  r := (Stylu & 0x8) ? 1 : 0
  Return r
}

updateUIctrl() {
    interfaceThread.ahkFunction("updateUIctrl", 1)
}

selectAllFiles() {
    Static selMode := 0
    selMode := !selMode
    selectFilesRange(1, maxFilesIndex, selMode)
    markedSelectFile := (selMode=1) ? maxFilesIndex : 0
    SetTimer, mainGdipWinThumbsGrid, -10
}

ToggleEditImgSelection() {
  Critical, on
  If (thumbsDisplaying=1)
     Return

  If (activateImgSelection!=1)
     correctActiveSelectionAreaViewPort()

  If (relativeImgSelCoords=1)
     calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

  If (getCaptionStyle(PVhwnd)=1)
     ToggleTitleBaruNow()

  If (slideShowRunning=1)
     ToggleSlideShowu()

  editingSelectionNow := !editingSelectionNow
  activateImgSelection := 1
  updateUIctrl()
  clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
  SetTimer, dummyRefreshImgSelectionWindow, -25
  ; dummyTimerDelayiedImageDisplay(25)
}

selectEntireImage() {
   If (thumbsDisplaying=1)
      Return

   If (getCaptionStyle(PVhwnd)=1)
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
   clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
   ; SetTimer, MouseMoveResponder, -50
   SetTimer, dummyRefreshImgSelectionWindow, -25
   ; dummyTimerDelayiedImageDisplay(25)
}

arrowKeysAdjustSelectionArea(direction, modus) {
    factoru := (zoomLevel>2) ? 1 : 2 - zoomLevel
    stepu := Round(2 * (factoru + 0.1))
    If (stepu<2)
       stepu := 2

    If (modus=1) ; reposition selection
    {
       If (direction=1)
          imgSelX1 += stepu
       Else If (direction=-1)
          imgSelX1 -= stepu
       Else If (direction=2)
          imgSelY1 += stepu
       Else If (direction=-2)
          imgSelY1 -= stepu
    } Else If (modus=2)
    {
       If (direction=1)
          imgSelX2 += stepu
       Else If (direction=-1)
          imgSelX2 -= stepu
       Else If (direction=2)
          imgSelY2 += stepu
       Else If (direction=-2)
          imgSelY2 -= stepu
    }
    SetTimer, dummyRefreshImgSelectionWindow, -10
}

toggleImgSelection() {
  If (thumbsDisplaying=1)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (activateImgSelection!=1)
     correctActiveSelectionAreaViewPort()

  If (relativeImgSelCoords=1)
     calcRelativeSelCoords(0, prevMaxSelX, prevMaxSelY)

  editingSelectionNow := 0
  activateImgSelection := !activateImgSelection
  updateUIctrl()
  clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
  SetTimer, MouseMoveResponder, -90
  SetTimer, dummyRefreshImgSelectionWindow, -25
  ; dummyTimerDelayiedImageDisplay(25)
}

resetImgSelection() {
  If (thumbsDisplaying=1)
     Return

  If (slideShowRunning=1 && activateImgSelection!=1)
     Return

  imgSelX1 := imgSelY1 := 0
  imgSelX2 := imgSelY2 := -1
  editingSelectionNow := activateImgSelection := 0
  updateUIctrl()
  SetTimer, MouseMoveResponder, -90
  SetTimer, dummyRefreshImgSelectionWindow, -25
  ; dummyTimerDelayiedImageDisplay(50)
}

newImgSelection() {
  IMGdecalageX := IMGdecalageY := 0
  resetImgSelection()
  Sleep, -1
  ToggleEditImgSelection()
}

createDefaultSizedSelectionArea(DestPosX, DestPosY, newW, newH, maxSelX, maxSelY, mainWidth, mainHeight) {
    If (imgSelX2="C") && (imgSelY2="C")
    {
       GetMouseCoord2wind(PVhwnd, mX, mY)
       x1 := (DestPosX<0) ? Abs(DestPosX)/newW : 0
       imgSelX1 := Round(x1*maxSelX)
       y1 := (DestPosY<0) ? Abs(DestPosY)/newH : 0
       imgSelY1 := Round(y1*maxSelY)
       imgSelX2 := Round(imgSelX1 + (mX + Round(mainWidth*0.1))/zoomLevel) + 5
       imgSelY2 := Round(imgSelY1 + (mY + Round(mainHeight*0.1))/zoomLevel) + 5
       imgSelX1 := Round(imgSelX1 + (mX - Round(mainWidth*0.1))/zoomLevel) + 5
       imgSelY1 := Round(imgSelY1 + (mY - Round(mainHeight*0.1))/zoomLevel) + 5
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
}

correctActiveSelectionAreaViewPort() {
    Static prevDimensions
    If (imgSelX2=-1 && imgSelY2=-1)
       Return

    Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
    theseDimensions := imgW "," imgH
    If (theseDimensions=prevDimensions)
       Return

    capSelectionRelativeCoords()
    calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    ; msgbox, % x1 "--" x2 "--" y1 "--" y2
    imgSelX1 := X1, imgSelY1 := Y1
    imgSelX2 := X2, imgSelY2 := Y2
    prevDimensions := imgW "," imgH
}

makeSquareSelection() {
    If (thumbsDisplaying=1 || activateImgSelection!=1)
       Return

    Gdip_GetImageDimensions(gdiBitmap, imgW, imgH)
    calcImgSelection2bmp(1, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
    If (imgSelW=imgSelH)
       Return

    avg := (imgSelW+imgSelH)//2
    avg := capValuesInRange(avg, 5, min(imgW, imgH))
    imgSelX2 := X1 + avg
    imgSelY2 := Y1 + avg
    prcSelX2 := imgSelX2/prevMaxSelX
    If (prcSelX2>1)
       prcSelX2 := 1

    prcSelY2 := imgSelY2/prevMaxSelY
    If (prcSelY2>1)
       prcSelY2 := 1

    SetTimer, MouseMoveResponder, -90
    SetTimer, dummyRefreshImgSelectionWindow, -25
    ; dummyTimerDelayiedImageDisplay(25)
}

destroyBlacked() {
  If (imageLoading=1)
  {
     SetTimer, destroyBlacked, -50
     Return
  }
  BlackedCreator(1, 1)
}


ToggleVisibilityWindow(actu, winIDu) {
   Static prevState
   thisState := actu "-" winIDu
   If (thisState=prevState)
      Return

   If (actu="show")
      WinSet, Region,, ahk_id %winIDu%
   Else
      WinSet, Region, 0-0 w1 h1, ahk_id %winIDu%

   prevState := thisState
}

FadeMainWindow() {
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   yBrush := Gdip_BrushCreateSolid("0x88" WindowBgrColor)
   Gdip_FillRectangle(glPG, yBrush, 0, 0, mainWidth, mainHeight)
   Gdip_DeleteBrush(yBrush)
   r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)
}

GdipCleanMain(modus:=0) {
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
       ; BMPcache := Gdip_CreateBitmapFromHBITMAP(glHbitmap)
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

       ; Gdip_DrawImageFast(glPG, BMPcache)
       If (modus=5 || modus=6)
       {
          If (vpIMGrotation>0)
             zoomu := " @ " vpIMGrotation "°"
          zoomu := Round(zoomLevel * 100) "%" zoomu
          thisInfo := max(oldZoomLevel, zoomLevel) - min(oldZoomLevel, zoomLevel)
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
             imgPath := getIDimage(currentFileIndex)
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
       ; Gdip_DisposeImage(BMPcache)
    } Else Gdip_GraphicsClear(glPG, opacity WindowBgrColor)
    r2 := UpdateLayeredWindow(hGDIwin, glHDC, 0, 0, mainWidth, mainHeight)
}

clearGivenGDIwin(Gu, DCu, hwnd) {
    Gdip_GraphicsClear(Gu, "0x00" WindowBgrColor)
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    r := UpdateLayeredWindow(hwnd, DCu, 0, 0, mainWidth, mainHeight)
    Return r
}

listThumbnailsGridMode(startIndex) {
    Gdip_GraphicsClear(2NDglPG, "0xFF" WindowBgrColor)
    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
    zBru := Gdip_BrushCreateSolid("0x66994433")
    rowIndex := 0
    columnIndex := -1
    prevMSGdisplay := A_TickCount
    Loop, % maxItemsW*maxItemsH*2
    {
        thisFileIndex := startIndex + A_Index - 1
        imgPath := resultedFilesList[thisFileIndex, 1]
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
        ; Gdip_FillRectangle(2NDglPG, pBrushWinBGR, DestPosX, DestPosY, thumbsW, thumbsH)
        If (StrLen(imgPath)>1 && thumbsListViewMode<=1)
        {
           zPlitPath(imgPath, 0, fileNamu, folderu)
           entireString := fileNamu "`n" folderu "\"
           If (!filterCoreString(imgPath, 2, userSearchString) && userSearchString)
              Gdip_FillRectangle(2NDglPG, pBrushD, DestPosX + thumbsW - Ceil(thumbsW*0.05) - 4, DestPosY + 4, Ceil(thumbsW*0.05), thumbsH - 8)
        } Else If (StrLen(imgPath)>1 && thumbsListViewMode=2)
        {
           zPlitPath(imgPath, 0, fileNamu, folderu)
           Try FileGetSize, fileSizu, % imgPath, K
           Try FileGetTime, FileDateM, % imgPath, M
           Try FileGetTime, FileDateC, % imgPath, C
           Try FormatTime, FileDateM, % FileDateM, dd/MM/yyyy, HH:mm
           Try FormatTime, FileDateC, % FileDateC, dd/MM/yyyy, HH:mm
           If FileExist(imgPath)
           {
              fileMsg := FileDateC " | " FileDateM " | " groupDigits(fileSizu) " Kb"
              ; op := GetImgFileDimension(imgPath, Width, Height)
              ; mgpx := (op=1) ? Round((Width*Height)/1000000,2) " MPx | " : ""
           } Else fileMsg := "Error gathering data..."

           entireString := mgpx fileNamu "`n" folderu "\`n" fileMsg
           If (fileSizu<2 && !InStr(fileMsg, "error"))
              Gdip_FillRectangle(2NDglPG, zBru, DestPosX + thumbsW - Ceil(thumbsW*0.05) - 4, DestPosY + 4, Ceil(thumbsW*0.05), thumbsH - 8)
           Else If (!filterCoreString(imgPath, 2, userSearchString) && userSearchString)
              Gdip_FillRectangle(2NDglPG, pBrushD, DestPosX + thumbsW - Ceil(thumbsW*0.05) - 4, DestPosY + 4, Ceil(thumbsW*0.05), thumbsH - 8)
        } Else If (StrLen(imgPath)>1 && thumbsListViewMode=3)
        {
           thumbBMP := LoadBitmapFromFileu(imgPath, 1)
           rawFmt := Gdip_GetImageRawFormat(thumbBMP)
           imageLoadedWithFIF := (rawFmt="MEMORYBMP") ? 1 : 0
           Gdip_GetImageDimensions(thumbBMP, Width, Height)
           If RegExMatch(imgPath, "i)(.\.(gif|tif|tiff))$")
              CountFrames := Gdip_GetBitmapFramesCount(thumbBMP)

           CountFrames := (CountFrames>1) ? " | " CountFrames " frames" : ""
           pixFmt := (imageLoadedWithFIF=0) ? Gdip_GetImagePixelFormat(thumbBMP, 2) : FIMimgBPP
           zPlitPath(imgPath, 0, fileNamu, folderu)
           Try FileGetSize, fileSizu, % imgPath, K

           mgpx := StrLen(thumbBMP)>2 ? Round((Width*Height)/1000000,2) " MPx | " : ""
           If (FileExist(imgPath) && StrLen(thumbBMP)>2)
              fileMsg := groupDigits(Width) " x " groupDigits(Height) " | " pixFmt CountFrames " | " groupDigits(fileSizu) " Kb"
           Else
              fileMsg := "Error gathering data..."

           Gdip_DisposeImage(thumbBMP, 1)
           entireString := mgpx fileNamu "`n" folderu "\`n" fileMsg
           If ((Width<2 || Height<2 || fileSizu<2) && !InStr(fileMsg, "error"))
              Gdip_FillRectangle(2NDglPG, zBru, DestPosX + thumbsW - Ceil(thumbsW*0.05) - 4, DestPosY + 4, Ceil(thumbsW*0.05), thumbsH - 8)
           Else If (!filterCoreString(imgPath, 2, userSearchString) && userSearchString)
              Gdip_FillRectangle(2NDglPG, pBrushD, DestPosX + thumbsW - Ceil(thumbsW*0.05) - 4, DestPosY + 4, Ceil(thumbsW*0.05), thumbsH - 8)
        }

        If StrLen(entireString)>2
        {
           infoBoxBMP2 := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.25, thumbsW, thumbsH, OSDtextColor, "0xFF" OSDbgrColor, 1, 0)
           Gdip_DrawImageFast(2NDglPG, infoBoxBMP2, DestPosX, DestPosY)
           infoBoxBMP2 := Gdip_DisposeImage(infoBoxBMP2, 1)
           entireString := ""
        }

        If (A_TickCount - prevMSGdisplay > 450)
        {
           prevMSGdisplay := A_TickCount
           r2 := UpdateLayeredWindow(hGDIthumbsWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
        } Else If (determineTerminateOperation()=1)
        {
           abandonAll := 1
           Break
        }
    }

    Gdip_DeleteBrush(zBru)
    r2 := UpdateLayeredWindow(hGDIthumbsWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
    executingCanceableOperation := 0
    mainEndZeit := A_TickCount
    prevFullThumbsUpdate := A_TickCount
    SetTimer, ResetImgLoadStatus, -15
    prevFullThumbsUpdate := A_TickCount
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
    Gdip_GraphicsClear(2NDglPG, "0x00" WindowBgrColor)
    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
    rowIndex := 0
    columnIndex := -1
    If (startIndex=prevIndexu)
       prevIndexu := ""

    Loop, % maxItemsW*maxItemsH*2
    {
        thisFileIndex := startIndex + A_Index - 1
        imgPath := resultedFilesList[thisFileIndex, 1]
        imgPathSelected := resultedFilesList[thisFileIndex, 2]
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
           Gdip_FillRectangle(2NDglPG, pBrushE, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_DrawRectangle(2NDglPG, pPen3, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_FillRectangle(2NDglPG, pBrushE, DestPosX, DestPosY, thumbsW, thumbsH)
           If StrLen(imgPath)<4
              Gdip_FillRectangle(2NDglPG, pBrushE, DestPosX, DestPosY, thumbsW, thumbsH)
        }

        If (mustShowNames=1 && thisFileIndex=startIndex && StrLen(imgPath)>5)
        {
           mustDrawBoxNow := 1
           zPlitPath(imgPath, 0, fileNamu, folderu)
           entireString := groupDigits(thisFileIndex) " / " groupDigits(maxFilesIndex) " | " fileNamu "`n" folderu "\"
           infoBoxBMP := drawTextInBox(entireString, OSDFontName, OSDfntSize//1.1, mainWidth, mainHeight, OSDtextColor, "0xFF" OSDbgrColor, 0, 0)
        } Else If (mustShowNames=2 && StrLen(imgPath)>5)
        {
           Gdip_FillRectangle(2NDglPG, pBrushE, DestPosX + 1, DestPosY + 1, thumbsW - 2, thumbsH - 2)
        } Else If (StrLen(imgPath)>5 && !mustShowNames && thumbnailsListMode!=1)
        {
           If !FileRexists(imgPath)
           {
              infoBoxBMP2 := drawTextInBox("! " thisFileIndex, OSDFontName, OSDfntSize//1.5, thumbsW, thumbsH, OSDtextColor, "0xFF" OSDbgrColor, 0, 0)
              Gdip_DrawImageFast(2NDglPG, infoBoxBMP2, DestPosX, DestPosY)
              infoBoxBMP2 := Gdip_DisposeImage(infoBoxBMP2, 1)
           }
        }

        If (!mustShowNames && StrLen(ImgPath)>5)
        {
           If !FileRexists(imgPath)
              Gdip_FillRectangle(2NDglPG, pBrush4, DestPosX, DestPosY, thumbsW, thumbsH)
        }

        If (thisFileIndex=currentFileIndex)
        {
           Gdip_FillRectangle(2NDglPG, pBrush1, DestPosX, DestPosY, thumbsW, thumbsH)
           If (noTooltipMSGs=0 || mustShowNames=1)
           {
              Gdip_AddPathRectangle(hitTestSelectionPath, DestPosX, DestPosY, thumbsW, thumbsH)
              zPlitPath(imgPath, 0, fileNamu, folderu)
              Try FileGetSize, fileSizu, % ImgPath, K
              Try FileGetTime, FileDateM, % ImgPath, M
              Try FormatTime, FileDateM, % FileDateM, dd/MM/yyyy, HH:mm
              If FileExist(imgPath)
                 fileMsg := groupDigits(fileSizu) " Kb | " FileDateM
              Else
                 fileMsg := "File not found or access denied"
           }
           delim := (multilineStatusBar=1) ? "`n" : " | "
           theMsg := groupDigits(currentFileIndex) " / " groupDigits(maxFilesIndex) " | " fileNamu " | " fileMsg delim folderu "\"
        }

        If (imgPathSelected=1)
        {
           countSel++
           Gdip_DrawRectangle(2NDglPG, pPen3, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_FillRectangle(2NDglPG, pBrush3, DestPosX, DestPosY, thumbsW, thumbsH)
        }
    }

    If (countSel>markedSelectFile && countSel>1 && markedSelectFile>1)
       SetTimer, dummyRecountSelectedFiles, -100

    If (mustDrawBoxNow=1)
    {
       Gdip_DrawImageFast(2NDglPG, infoBoxBMP, 1, 1)
       infoBoxBMP := Gdip_DisposeImage(infoBoxBMP, 1)
    }

    prevIndexu := startIndex
    If markedSelectFile
    {
       Gdip_FillRectangle(2NDglPG, pBrush1, 0, 0, mainWidth, imgHUDbaseUnit//5)
       theMsg := markedSelectFile " selected | " theMsg
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

    If ((mustShowNames=1 || noTooltipMSGs=0) && StrLen(theMsg)>1)
    {
       infoBoxBMP := drawTextInBox(theMsg, OSDFontName, Round(OSDfntSize*0.9), mainWidth, mainHeight//3, OSDtextColor, "0xFF" OSDbgrColor, 1)
       Gdip_GetImageDimensions(infoBoxBMP, ThumbsStatusBarW, ThumbsStatusBarH)
       Gdip_DrawImage(2NDglPG, infoBoxBMP, -1, mainHeight - ThumbsStatusBarH,,,,,,, 0.85)
       Gdip_DisposeImage(infoBoxBMP, 1)
    }

    lineThickns := imgHUDbaseUnit//3.25
    If (scrollHeight<mainHeight)
    {
       Gdip_FillRectangle(2NDglPG, pBrushE, mainWidth - lineThickns, 0, lineThickns, mainHeight)
       Gdip_AddPathRectangle(hitTestSelectionPath, mainWidth - lineThickns, 0, lineThickns, mainHeight)
       Gdip_FillRectangle(2NDglPG, pBrushD, mainWidth - lineThickns + 5, scrollYpos, lineThickns, scrollHeight)
    }

    changeMcursor("normal")
    r2 := UpdateLayeredWindow(hGDIselectWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
}

dummyRecountSelectedFiles() {
   getSelectedFiles(0, 1)
}

EraseThumbsCache(dummy:=0) {
   startZeit := A_TickCount
   showTOOLtip("Emptying thumbnails cache, please wait...")
   prevMSGdisplay := A_TickCount
   doStartLongOpDance()
   countTFilez := countFilez := 0
   Loop, Files, %thumbsCacheFolder%\*.*
   {
      If !(A_LoopFileExt="tiff" || A_LoopFileExt="png" || A_LoopFileExt="jpg")
         Continue

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

      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }
   }

   If (dummy="daysITis")
      moreInfo := " out of " countTFilez

   remCacheOldDays := 0
   If (abandonAll=1)
      showTOOLtip("Operation aborted... Removed " countFilez " cached thumbnails...")
   Else If (A_TickCount - startZeit>1500) || (dummy="daysITis")
      showTOOLtip("Finished removing " countFilez moreInfo " cached thumbnails")
   
   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
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

setPriorityThread(level, handle:="A") {
  If (handle="A" || !handle)
     handle := DllCall("GetCurrentThread")
  Return DllCall("SetThreadPriority", "UPtr", handle, "Int", level)
}

ObjToString(obj) {
  if (!IsObject(obj))
    return obj
  str := "`n{"
  for key, value in obj
    str .= "`n" key ": " ObjToString(value) ","
  return str "`n}"
}

CustomObjToString(obj) {
  if (!IsObject(obj))
    return obj
;  str := "|&|"
  for key, value in obj
    str .= "?" key "|" CustomaObjToString(value)
  return str ; "|&|"
}

CustomaObjToString(obj) {
  if (!IsObject(obj))
    return obj
 ; str := "/&/"
  for key, value in obj
    str .= "<" ObjToString(value) "@"
  return str ; "/&/"
}

StrToObject(stringu) {
  newArrayu := []
  Loop, Parse, stringu, ?
  {
      If !A_LoopField
         Continue
      lineArrayu := StrSplit(A_LoopField, "|<")
      thisIndex := lineArrayu[1]
      preparedOther := StrReplace(lineArrayu[2], "@")
      otherLineArrayu := StrSplit(preparedOther, "<")
      ; MsgBox, % A_LoopField "`n" thisIndex "`n" preparedOther "`n" otherLineArrayu[1] "`n" lineArrayu[2] "`n" A_Index
      Loop, % otherLineArrayu.Length()
          newArrayu[thisIndex, A_Index] := otherLineArrayu[A_Index]
  }
  ; MsgBox, % CustomObjToString(newArrayu)
  Sleep, 50
  Return newArrayu
}

QPV_ShowThumbnails(startIndex) {
    Critical, on

    prevFullThumbsUpdate := A_TickCount
    mainStartZeit := A_TickCount
    If (thumbnailsListMode=1)
    {
       listThumbnailsGridMode(startIndex)
       Return
    }
    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, ignoreVaru, mainWidth, mainHeight)
    setImageLoading()
    thumbsBitmap := Gdip_CreateBitmap(mainWidth, mainHeight)
    G2 := Gdip_GraphicsFromImage(thumbsBitmap, 5, 4)
    hasUpdated := rowIndex := imgsListed := 0
    maxImgSize := maxZeit := columnIndex := -1

    setPriorityThread(-2)
    DestroyGIFuWin()
    createThumbsFolder()
    Gdip_GraphicsClear(glPG, "0xFF" WindowBgrColor)

    ; Gdip_FillRectangle(G2, pBrushWinBGR, -2, -2, mainWidth + 5, mainHeight + 5)
    prevGUIupdate := A_TickCount
    thisImgQuality := (userimgQuality=1) ? 7 : 5
    imgsListArrayThumbs := []
    imgsMustPaint := imgsNotCached := 0
    Loop, % maxItemsW*maxItemsH*2
    {
        thisFileIndex := startIndex + A_Index - 1
        columnIndex++
        If (columnIndex>=maxItemsW)
        {
           rowIndex++
           columnIndex := 0
        }

        If (rowIndex>=maxItemsH)
           Break

        imgPath := getIDimage(thisFileIndex)
        thisFileDead := (StrLen(imgPath)<5 || !FileRexists(imgPath)) ? 1 : 0
        DestPosX := thumbsW//2 + thumbsW*columnIndex
        DestPosY := thumbsH//2 + thumbsH*rowIndex
        memCached := wasThumbCached := 0
        MD5name := generateThumbName(imgPath, 1, 1)
        If (thisFileDead=1)
        {
           imgsListArrayThumbs[thisFileIndex] := ["x", 0, imgPath, MD5name, DestPosX, DestPosY, MD5name]
        } Else If StrLen(imgThumbsCacheIDsArray[MD5name])>0
        {
           memCached := 1
           imgsListArrayThumbs[thisFileIndex] := ["m", 0, imgPath, MD5name, DestPosX, DestPosY, MD5name]
        } Else
        {
           wasThumbCached := checkThumbExists(MD5name, imgPath, file2load)
           If (wasThumbCached=1)
              imgsListArrayThumbs[thisFileIndex] := ["f", 0, imgPath, file2load, DestPosX, DestPosY, MD5name]
        }

        If (currentFileIndex=thisFileIndex)
        {
           sizeSquare := 36 + zoomLevel*15
           Gdip_FillRectangle(glPG, pBrushA, DestPosX - sizeSquare//2, DestPosY - sizeSquare//2, sizeSquare, sizeSquare)
        }

        imgsMustPaint++
        If (memCached=1 || wasThumbCached=1 || thisFileDead=1)
           Continue

        imgsNotCached++
        ; Gdip_FillRectangle(glPG, pBrushE, DestPosX - 10, DestPosY - 10, 20, 20)
        file2save := thumbsCacheFolder "\" thumbsSizeQuality "-" MD5name ".jpg"
        imgsListArrayThumbs[thisFileIndex] := ["w", 0, imgPath, file2save, DestPosX, DestPosY, MD5name]
        ; msgbox, % imgPath "|" thisFileIndex "|" MD5name
    }

   limitCores := realSystemCores + 1
   filesPerCore := imgsNotCached//limitCores
   If (filesPerCore<2 && limitCores>1)
   {
      systemCores := imgsNotCached//2
      filesPerCore := imgsNotCached//systemCores
   } Else systemCores := limitCores
   mustDoMultiCore := (allowMultiCoreMode=1 && systemCores>1 && filesPerCore>1 && multiCoreThumbsInitGood=1) ? 1 : 0
   timePerImg := 1550//imgsNotCached
   If (timePerImg<22)
      timePerImg := 22
   Else If (timePerImg>300)
      timePerImg := 300
   timePerImgMultiCore := timePerImg*2 + limitCores*2
   If (timePerImgMultiCore>350)
      timePerImgMultiCore := 350

   If (mustDoMultiCore=1)
   {
      Loop, % limitCores
          thumbThread%A_Index%.ahkPostFunction("cleanMess")
   }

   thisFileIndex := MD5name := Bindex := hasUpdated := rowIndex := imgsListed := 0
   thisNonCachedImg := coreIndex := threadIndex := memCached := lapsOccured := 0
   maxImgSize := maxZeit := columnIndex := -1
   doStartLongOpDance()
    ; MsgBox, % filesPerCore "--" imgsMustPaint "--" imgsNotCached "--" imgsListArrayThumbs.Length()
   interfaceThread.ahkassign("alterFilesIndex", 0)
   Loop
   {
       alterFilesIndex := interfaceThread.ahkgetvar.alterFilesIndex
       If (alterFilesIndex>1 && lapsOccured>3)
          Break

       totalLoops++
       If (determineTerminateOperation()=1)
       {
          abandonAll := 1
          hasUpdated := 0
          Break
       }

       ; Sleep, 0
       Bindex++
       If (Bindex>imgsMustPaint)
       {
          lapsOccured++
          Bindex := 1
       }

       thisFileIndex := startIndex + Bindex - 1
       If (mustEndLoop=1)
       {
          hasUpdated := 0
          Break
       }

       If (imgsHavePainted>=imgsMustPaint)
          mustEndLoop := 1

       cacheType := imgsListArrayThumbs[thisFileIndex, 1]
       If (cacheType="d")
          Continue

       If (cacheType="x")
       {
          imgsListArrayThumbs[thisFileIndex, 1] := "d"
          imgsHavePainted++
          Continue
       }

       innerLoops++
       If (cacheType="w" && mustDoMultiCore=1)
       {
          ; Sleep, -1
          thisCoreDoneLine := ""
          thisCoreDoneArr := ""
          whichCoreBusy := imgsListArrayThumbs[thisFileIndex, 2]
          If (whichCoreBusy>0)
          {
             hasThumbFailed := thumbThread%whichCoreBusy%.AHKgetvar.operationFailed
             thisCoreDoneLine := thumbThread%whichCoreBusy%.AHKgetvar.resultsList
             thisCoreDoneArr := StrSplit(thisCoreDoneLine, "|")
             waitDataCollect := thumbThread%whichCoreBusy%.AHKgetvar.waitDataCollect
             If (thisCoreDoneArr[1]=1 && thisCoreDoneArr[4]=whichCoreBusy && thisCoreDoneArr[5]=Bindex && waitDataCollect=1)
             {
                thumbThread%whichCoreBusy%.ahkassign("waitDataCollect", 0)
                thisPBitmap := StrLen(thisCoreDoneArr[2])>2 ? thisCoreDoneArr[2] : 0
                imgsListArrayThumbs[thisCoreDoneArr[3], 1] := "fim"
                imgsListArrayThumbs[thisCoreDoneArr[3], 2] := thisPBitmap
                If (hasThumbFailed=1)
                {
                   thumbThread%whichCoreBusy%.ahkassign("operationFailed", 0)
                   imgsListArrayThumbs[thisCoreDoneArr[3], 1] := "x"
                }
             } Else If (thisCoreDoneArr[1]=1 && thisCoreDoneArr[4]=whichCoreBusy && waitDataCollect=1)
             {
                ; SoundBeep 
                thumbThread%whichCoreBusy%.ahkassign("waitDataCollect", 0)
                thisFileIndex := thisCoreDoneArr[3]
                Bindex := thisCoreDoneArr[5]
                thisPBitmap := StrLen(thisCoreDoneArr[2])>2 ? thisCoreDoneArr[2] : 0
                imgsListArrayThumbs[thisFileIndex, 1] := "fim"
                imgsListArrayThumbs[thisFileIndex, 2] := thisPBitmap
                If (hasThumbFailed=1)
                {
                   thumbThread%whichCoreBusy%.ahkassign("operationFailed", 0)
                   imgsListArrayThumbs[thisFileIndex, 1] := "x"
                }
             } Else Continue
          } Else If (preventNewThreads!=1)
          {
             coreIndex++
             If (coreIndex>limitCores)
                coreIndex := 1
             thisCoreDone := thumbThread%coreIndex%.AHKgetvar.operationDone
             waitDataCollect := thumbThread%coreIndex%.AHKgetvar.waitDataCollect
             hasThumbFailed := thumbThread%coreIndex%.AHKgetvar.operationFailed
             If (thisCoreDone=1 && waitDataCollect<1 && hasThumbFailed=0)
             {
                thumbThread%coreIndex%.ahkassign("operationDone", 0)
                thumbThread%coreIndex%.ahkassign("waitDataCollect", 0)
                thisPath := imgsListArrayThumbs[thisFileIndex, 3]
                thisSavePath := imgsListArrayThumbs[thisFileIndex, 4]
                thumbThread%coreIndex%.ahkPostFunction("MonoGenerateThumb", thisPath, thisSavePath, enableThumbsCaching, thumbsSizeQuality, timePerImgMultiCore, coreIndex, thisFileIndex, Bindex)
                imgsListArrayThumbs[thisFileIndex, 2] := coreIndex
             }
             Continue
          }
       }

       ; Sleep, 1
       changeMcursor()
       cacheType := imgsListArrayThumbs[thisFileIndex, 1]
       ; ToolTip, % thisCoreDoneLine " -- " cacheType " -- " whichCoreBusy " -- " A_Index " -- " imgsHavePainted " -- " imgsMustPaint " -- " reallyThreadsDone " --- " systemCores , , , 2
       fimCached := mustDisposeImgNow := 0
       wasCacheFile := thumbCachable := WasMemCached := hasNowMemCached := 0
       If (cacheType="w")
       {
          If (mustDoMultiCore=1)
             Continue

          ; mustDisposeImgNow := 1
          thumbCachable := 1
          imgsListArrayThumbs[thisFileIndex, 1] := "f"
          file2load := imgsListArrayThumbs[thisFileIndex, 3]
          oBitmap := LoadBitmapFromFileu(file2load, 0, 1)
       } Else If (cacheType="m")
       {
          WasMemCached := 1
          MD5name := imgsListArrayThumbs[thisFileIndex, 4]
          oBitmap := imgThumbsCacheArray[imgThumbsCacheIDsArray[MD5name], 1]
       } Else If (cacheType="f")
       {
          wasCacheFile := 1
          file2load := imgsListArrayThumbs[thisFileIndex, 4]
          oBitmap := LoadBitmapFromFileu(file2load, 0, 1)
       } Else If (cacheType="fim")
       {
          fimCached := 1
          oBitmap := imgsListArrayThumbs[thisFileIndex, 2]
          If !oBitmap
          {
             ; mustDisposeImgNow := 1
             cacheType := "f"
             wasCacheFile := 1
             fimCached := 0
             file2load := imgsListArrayThumbs[thisFileIndex, 4]
             If !FileRexists(file2load)
             {
                wasCacheFile := fimCached := 0
                thumbCachable := 1
                file2load := imgsListArrayThumbs[thisFileIndex, 3]
             }
             oBitmap := LoadBitmapFromFileu(file2load, 0)
          }
       }

       extendedLoops++
       imgsListArrayThumbs[thisFileIndex, 1] := "d"
       imgPath := imgsListArrayThumbs[thisFileIndex, 3]
       MD5name := imgsListArrayThumbs[thisFileIndex, 7]
       file2save := thumbsCacheFolder "\" thumbsSizeQuality "-" MD5name ".jpg"
       If oBitmap
          Gdip_GetImageDimensions(oBitmap, imgW, imgH)

       If (!oBitmap || !FileExist(imgPath) || !imgW || !imgH)
       {
          If (WasMemCached=1)
          {
             wasThumbCached := checkThumbExists(MD5name, imgPath, file2load)
             imgsListArrayThumbs[thisFileIndex, 1] := FileExist(file2load) ? "fim" : "w"
             imgsListArrayThumbs[thisFileIndex, 2] := 0
             imgsListArrayThumbs[thisFileIndex, 4] := file2load
          } Else imgsHavePainted++
          ; msgbox, % imgW "--" imgH "--" oBitmap
          Continue
       } Else imgsHavePainted++

       startZeit := A_TickCount
       If (thumbCachable=1)
       {
          zBitmap := Gdip_ResizeBitmap(oBitmap, thumbsW, thumbsH, 1, thisImgQuality)
          oBitmap := Gdip_DisposeImage(oBitmap, 1)
          oBitmap := zBitmap
       } Else If (WasMemCached!=1)
       {
          zBitmap := cloneGDItoMem(oBitmap, imgW, imgH)
          If (fimCached!=1)
             oBitmap := Gdip_DisposeImage(oBitmap, 1)
          oBitmap := zBitmap
       }
       thisZeit := A_TickCount - startZeit
       ; MsgBox, % "lol " memCached " -- " hasMemThumbsCached " -- " imgThumbsCacheIDsArray[MD5name]  "`n" file2save 

       Gdip_GetImageDimensions(oBitmap, newW, newH)
       If (!newW || !newH)
       {
          oBitmap := Gdip_DisposeImage(oBitmap, 1)
          Continue
       }

       If (WasMemCached!=1 && minimizeMemUsage!=1)
       {
          hasNowMemCached := 1
          hasMemThumbsCached++ 
          Gdip_DisposeImage(imgThumbsCacheArray[hasMemThumbsCached, 1], 1)
          imgThumbsCacheIDsArray[imgThumbsCacheArray[hasMemThumbsCached, 2]] := ""
          imgThumbsCacheArray[hasMemThumbsCached] := [oBitmap, MD5name]
          imgThumbsCacheIDsArray[MD5name] := hasMemThumbsCached
          If (hasMemThumbsCached>maxMemThumbsCache)
             hasMemThumbsCached := 0
       }

       calcIMGdimensions(newW, newH, thumbsW, thumbsH, fW, fH)
       DestPosX := imgsListArrayThumbs[thisFileIndex, 5] - fW//2
       DestPosY := imgsListArrayThumbs[thisFileIndex, 6] - fH//2
       If (fimCached!=1 && thumbCachable=1 && thisZeit>timePerImg && file2save!=file2load && enableThumbsCaching=1 && WasMemCached!=1)
       && ((newW<imgW//2) || (newH<imgH//2))
          Gdip_SaveBitmapToFile(oBitmap, file2save, 90)

       If (WasMemCached=1 || hasNowMemCached=1)
       {
          zBitmap := Gdip_CloneBitmap(oBitmap)
          oBitmap := zBitmap
       }

       If (bwDithering=1 && imgFxMode=4)
          nullu := ""
       Else If (usrColorDepth>1)
          E := Gdip_BitmapSetColorDepth(oBitmap, internalColorDepth, ColorDepthDithering)

       flipBitmapAccordingToViewPort(oBitmap)
       ; changeMcursor()
       hasUpdated := 0
       r1 := Gdip_DrawImageRect(G2, oBitmap, DestPosX, DestPosY, fW - 1, fH - 1)
       oBitmap := Gdip_DisposeImage(oBitmap, 1)

       If (A_TickCount - prevGUIupdate>350)
       {
          r1 := Gdip_DrawImageFast(glPG, thumbsBitmap)
          r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, 0, 0, mainWidth, mainHeight)
          prevGUIupdate := A_TickCount
          hasUpdated := 1
       }
   }

    If (alterFilesIndex>1 && mustEndLoop!=1 && lapsOccured>3)
    {
       mustReloadThumbsList := 1
       ; mainGdipWinThumbsGrid()
       SetTimer, ForceRefreshNowThumbsList, -350
       ; Return
    } Else If (mustDoMultiCore=1 && mustEndLoop=1 && abandonAll!=1)
    {
       Loop, % limitCores
           thumbThread%A_Index%.ahkPostFunction("cleanMess")
    }

    executingCanceableOperation := 0
    mainEndZeit := A_TickCount
    setPriorityThread(0)
    If (bwDithering=1 && imgFxMode=4)
    {
       zBitmap := Gdip_BitmapConvertGray(thumbsBitmap, hueAdjust, zatAdjust, lumosGrayAdjust, GammosGrayAdjust)
       Gdip_DisposeImage(thumbsBitmap, 1)
       thumbsBitmap := zBitmap
       E := Gdip_BitmapSetColorDepth(thumbsBitmap, "BW", 1)
    } 

    decideGDIPimageFX(matrix, imageAttribs, pEffect)
    If (pEffect || imageAttribs)
       r1 := Gdip_DrawImageFX(glPG, thumbsBitmap, 0, 0, 0, 0, mainWidth, mainHeight, matrix, pEffect, imageAttribs)
    Else If (hasUpdated=0)
       r1 := Gdip_DrawImageFast(glPG, thumbsBitmap)

    r2 := UpdateLayeredWindow(hGDIthumbsWin, glHDC, 0, 0, mainWidth, mainHeight)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(thumbsBitmap, 1)
    If pEffect
       Gdip_DisposeEffect(pEffect)
    If imageAttribs
       Gdip_DisposeImageAttributes(imageAttribs)
    ; ToolTip, %imgW% -- %imgH% == %newW% -- %newH%

    prevFullThumbsUpdate := A_TickCount
    If (abandonAll=1)
       lastLongOperationAbort := A_TickCount

    executingCanceableOperation := 0
    SetTimer, ResetImgLoadStatus, -25
    prevFullThumbsUpdate := A_TickCount
    ; ToolTip, % lapsOccured "|"  totalLoops " | " innerLoops " | " extendedLoops " | " imgsNotCached " | " A_TickCount - mainStartZeit , , , 2
    r := (r1!=0 || !r2 || abandonAll=1) ? 0 : 1
    Return r
}

cloneGDItoMem(pBitmap, W:=0, H:=0) {
    If (!W || !H)
       Gdip_GetImageDimensions(pBitmap, W, H)

    thisImgQuality := (userimgQuality=1) ? 3 : 5
    newBitmap := Gdip_CreateBitmap(W, H)
    G := Gdip_GraphicsFromImage(newBitmap, thisImgQuality)
    Gdip_DrawImageRect(G, pBitmap, 0, 0, W, H)
    Gdip_DeleteGraphics(G)
    Return newBitmap
}

calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, ByRef DestPosX, ByRef DestPosY) {
    Static orderu := {1:7, 2:8, 3:9, 4:4, 5:5, 6:6, 7:1, 8:2, 9:3}
         , prevW := 1, prevH := 1, prevZoom := 0

    imgDecLX := LX := mainWidth - newW
    imgDecLY := LY := mainHeight - newH
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

GDIupdater() {
   If (A_TickCount - scriptStartTime<450)
      Return

   If (toolTipGuiCreated=1)
      RemoveTooltip()

   SetTimer, dummyTimerReloadThisPicture, Off
   SetTimer, dummyTimerDelayiedImageDisplay, Off
   DestroyGIFuWin()
   resetSlideshowTimer(0)
   imgPath := getIDimage(currentFileIndex)
   If StrLen(UserMemBMP)>2
      thisClippyIMG := 1

   If (!imgPath || !maxFilesIndex || PrevGuiSizeEvent=1 || !CurrentSLD) && (thisClippyIMG!=1)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()

      ForceRefreshNowThumbsList()
      If (A_TickCount - lastWinDrag<350)
         Return

      If (thumbsDisplaying=1) && (!maxFilesIndex || !CurrentSLD)
         ToggleVisibilityWindow("hide", hGDIthumbsWin)
      Else
         FadeMainWindow()
      Return
   }

   If (maxFilesIndex>0 && PrevGuiSizeEvent!=1 && thumbsDisplaying!=1) && (A_TickCount - scriptStartTime>500) || (thisClippyIMG=1)
   {
      delayu := (A_TickCount - lastWinDrag<450) ? 450 : 15
      filterDelayiedImageDisplay()
      ; dummyTimerDelayiedImageDisplay(delayu)
      dummyTimerReloadThisPicture(750)
      ForceRefreshNowThumbsList()
   } Else If (thumbsDisplaying=1 && maxFilesIndex>1)
   {
      recalculateThumbsSizes()
      GetClientSize(mainWidth, mainHeight, PVhwnd)
      WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight% , ahk_id %hGDIthumbsWin%
      delayu := (A_TickCount - lastWinDrag<450) ? 550 : 325
      SetTimer, RefreshThumbsList, % -delayu
   }
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
          r := GetFilesList(line "\*")
       If (r="abandoned")
          Break
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
    If (RegExMatch(CurrentSLD, sldsPattern) && InStr(DynamicFoldersList, "|hexists|"))
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

       r := GetFilesList(line "\*")
       If (r="abandoned")
          Break
    }
    If (r="abandoned")
    {
       resetMainWin2Welcome()
       SoundBeep, 300, 100
       showTOOLtip("Operation aborted by user. The files list is now empty...")
       SetTimer, RemoveTooltip, % -msgDisplayTime
    } Else
    {
       GenerateRandyList()
       SoundBeep, 900, 100
       RandomPicture()
    }
}

sldDataBaseOpen(fileNamu) {
  activeSQLdb.CloseDB()
  activeSQLdb := new SQLiteDB
  If !activeSQLdb.OpenDB(fileNamu)
     Return -1

  SQL := "SELECT imgfolder||'\'||imgfile AS imgPath FROM images;"
  RecordSet := ""
  Start := A_TickCount
  If !activeSQLdb.Query(SQL, RecordSet)
     Return -1

  Loop
  {
      maxFilesIndex++
      resultedFilesList[maxFilesIndex] := [Row[1]] ; Row[1]
      RC := RecordSet.Next(Row)
  } Until (RC<1)
  RecordSet.Free()

  SQL := "SELECT imgfolder FROM dynamicfolders;"
  RecordSet := ""
  DynamicFoldersList := ""
  activeSQLdb.Query(SQL, RecordSet)
  Loop
  {
      DynamicFoldersList .= Row[1] "`n"
      RC := RecordSet.Next(Row)
  } Until (RC < 1)
  RecordSet.Free()
  ; MsgBox, % ("Files: " maxFilesIndex "Query: " . SQL . " done in " . (A_TickCount - Start) . " ms`n`n" resultedFilesList[10])
}

sldGenerateFilesList(readThisFile, doFilesCheck, mustRemQuotes) {
    startZeit := A_TickCount
    FileRead, tehFileVar, %readThisFile%
    If (mustRemQuotes=1)
    {
       StringReplace, tehFileVar, tehFileVar,"-,,All
       StringReplace, tehFileVar, tehFileVar,",,All
    }

    doStartLongOpDance()
    Loop, Parse, tehFileVar,`n,`r
    {
       line := Trim(A_LoopField)
       If InStr(line, "|")
       {
          doRecursive := 2
          line := StrReplace(line, "|")
       } Else doRecursive := 1

       If (determineTerminateOperation()=1)
       {
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
          resultedFilesList[maxFilesIndex] := [line]
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

    ; MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000)
    SetTimer, ResetImgLoadStatus, -50
    If (abandonAll=1)
       showTOOLtip("Operation aborted. The files list is now empty.")
    Else If (maxFilesIndex<1)
       showTOOLtip("Found no files or folders in the SLD...`nThe files list is empty.")

    executingCanceableOperation := 0
    If (abandonAll=1 || maxFilesIndex<1)
    {
       lastLongOperationAbort := A_TickCount
       SetTimer, RemoveTooltip, % -msgDisplayTime
       SoundBeep, 300, 100
       Return "abandoned"
    }
}

filterCoreString(stringu, behave, thisFilter) {
  r := RegExMatch(stringu, "i)(" thisFilter ")")
  z := r ? 1 : 0
  Return (behave=2) ? !z : z
}

GetFilesList(strDir, doRecursive:=1, openFirst:=0) {
  showTOOLtip("Loading files from...`n" strDir "`n")
  If InStr(strDir, "|")
  {
     doRecursive := 2
     strDir := StrReplace(strDir, "|")
  }

  dig := (doRecursive=2) ? "" : "R"
  addedNow := 0
  startOperation := A_TickCount
  prevMSGdisplay := A_TickCount
  prevDisplay := A_TickCount
  If (SLDtypeLoaded=3)
     activeSQLdb.Exec("BEGIN TRANSACTION;")

  doStartLongOpDance()
  Loop, Files, %strDir%, %dig%
  {
      If (RegExMatch(A_LoopFileName, RegExFilesPattern) && A_LoopFileSize>120)
      {
         addedNow++
         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := [A_LoopFileFullPath]
         ; If (minimizeMemUsage!=1 && A_Index>10 && maxFilesIndex>4 && loadedFirst!=1) && (A_TickCount - startOperation>1900)
         ; || (minimizeMemUsage!=1 && loadedFirst=1 && (A_TickCount - prevDisplay>19500))
         ; {
         ;    prevDisplay := A_TickCount
         ;    currentFileIndex := maxFilesIndex - 2
         ;    loadedFirst := 1
         ;    IDshowImage(currentFileIndex)
         ;    doStartLongOpDance()
         ; }

         If (SLDtypeLoaded=3) ; SQLite database 
            addSQLdbEntry(A_LoopFileName, A_LoopFileDir, A_LoopFileSize, A_LoopFileTimeModified, A_LoopFileTimeCreated)
      }

      If (A_TickCount - prevMSGdisplay>2000)
      {
         showTOOLtip("Loading files from...`n" strDir "`n" groupDigits(addedNow) " [" groupDigits(maxFilesIndex) "] files...")
         prevMSGdisplay := A_TickCount
      }

      changeMcursor()
      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }
  }

  If (SLDtypeLoaded=3)
     activeSQLdb.Exec("COMMIT TRANSACTION;")

  executingCanceableOperation := 0
  SetTimer, ResetImgLoadStatus, -50
  If (abandonAll=1)
  {
     showTOOLtip("Files list loading aborted...")
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return "abandoned"
  }
  SetTimer, RemoveTooltip, % -msgDisplayTime
  Return loadedFirst
}

getIDimage(imgID) {
    r := resultedFilesList[imgID, 1]
    Return r
}

IDshowImage(imgID, opentehFile:=0) {
    Static prevIMGid, prevImgPath, lastInvoked := 1
    imgPath := getIDimage(imgID)
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
          resultedFilesList[imgID] := [imgPath]
    }

    If (InStr(AprevImgCall, imgPath) || InStr(BprevImgCall, imgPath) || StrLen(UserMemBMP)>2 || thumbsDisplaying=1)
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

    If (AnyWindowOpen!=10 && resetImageViewOnChange=1 && thumbsDisplaying!=1)
    {
       newIMGid := generateThumbName(imgPath, 1)
       If (prevIMGid!=newIMGid)
       {
          usrColorDepth := imgFxMode := 1
          RenderOpaqueIMG := vpIMGrotation := FlipImgH := FlipImgV := 0
       }
    }

    prevImgPath := (opentehFile=0 || opentehFile=2) ? imgPath : 0
    If (opentehFile=2)
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

doSuspendu(act) {
  If (act=1)
     Suspend, On
  Else
     Suspend, Off
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
; Hash O(n) - function by errorseven from:
; https://stackoverflow.com/questions/46432447/how-do-i-remove-duplicates-from-an-autohotkey-array
    hash := {}
    newArr := []
    For e, v in arr
    {
        If (!hash.Haskey(v))
        {
           hash[(v)] := 1
           newArr.Push(v)
        }
    }
    Return newArr
}

ReverseListNow() {
    showTOOLtip("Reversing files list order...")
    backCurrentSLD := CurrentSLD
    CurrentSLD := ""
    resultedFilesList := reverseArray(resultedFilesList)
    ForceRefreshNowThumbsList()
    CurrentSLD := backCurrentSLD
    dummyTimerDelayiedImageDisplay(50)
    SoundBeep, 900, 100
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

RandomizeListNow() {
    showTOOLtip("Randomizing files list order...")
    backCurrentSLD := CurrentSLD
    CurrentSLD := ""
    resultedFilesList := Random_ShuffleArray(resultedFilesList)
    CurrentSLD := backCurrentSLD
    ForceRefreshNowThumbsList()
    dummyTimerDelayiedImageDisplay(50)
    SoundBeep, 900, 100
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
    Loop, % maxArray - 1
    {
        Random, J, % A_Index, % maxArray
        ; J             := Random(A_Index, Array.Count())
        Temp            := Result[A_Index]
        Result[A_Index] := Result[J]
        Result[J]       := Temp
    }
    Return Result
}

reverseArray(a) {
; function inspired by RHCP from https://autohotkey.com/board/topic/97722-some-array-functions/

    aStorage := []
    maxIndexu := a.Count()
    Loop, % maxIndexu
        aStorage[A_Index] := a[maxIndexu - A_Index + 1]

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
       calcImgSelection2bmp(0, imgW, imgH, newW, newH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
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
          Gdip_DisposeImage(rBitmap, 1)
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
;          flipBitmapAccordingToViewPort(thumbBMP, 1)
    }
    Return thumbBMP
}

flipBitmapAccordingToViewPort(whichBitmap, ignoreThis:=0) {
   imgOp := (FlipImgH=1) ? 4 : 0
   imgOp := (FlipImgV=1) ? 6 : imgOp
   imgOp := (FlipImgV=1 && FlipImgH=1) || (vpIMGrotation=180 && ignoreThis=0) ? 2 : imgOp
   If (imgOp>0 && whichBitmap)
      Gdip_ImageRotateFlip(whichBitmap, imgOp)
}

calcImgSelection2bmp(noLimits, imgW, imgH, newW, newH, ByRef imgSelPx, ByRef imgSelPy, ByRef imgSelW, ByRef imgSelH, ByRef zImgSelPx, ByRef zImgSelPy, ByRef zImgSelW, ByRef zImgSelH, ByRef nImgSelX1, ByRef nImgSelY1, ByRef nImgSelX2, ByRef nImgSelY2) {
   nImgSelX1 := min(imgSelX1, imgSelX2)
   nImgSelY1 := min(imgSelY1, imgSelY2)
   nImgSelX2 := max(imgSelX1, imgSelX2)
   nImgSelY2 := max(imgSelY1, imgSelY2)
   If (noLimits!=1)
   {
      If (nImgSelX1<0)
         nImgSelX1 := 0
      If (nImgSelY1<0)
         nImgSelY1 := 0

      If (nImgSelX2>imgW)
         nImgSelX2 := imgW
      If (nImgSelY2>imgH)
         nImgSelY2 := imgH
   }

   imgSelW := max(nImgSelX1, nImgSelX2) - min(nImgSelX1, nImgSelX2)
   imgSelH := max(nImgSelY1, nImgSelY2) - min(nImgSelY1, nImgSelY2)
   imgSelPx := min(nImgSelX1, nImgSelX2)
   imgSelPy := min(nImgSelY1, nImgSelY2)
   If (imgSelW<2)
   {
      imgSelW := 2
      imgSelPx := (imgSelPx>=2) ? imgSelPx - 2 : 0
      nImgSelX2 := imgSelPx + imgSelW
   }

   If (imgSelH<2)
   {
      imgSelH := 2
      imgSelPy := (imgSelPy>=2) ? imgSelPy - 2 : 0
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
   If (noLimits!=1)
   {
      If (zImgSelX2>newW)
         zImgSelX2 := newW
      If (zImgSelY2>newH)
         zImgSelY2 := newH
   }

   zImgSelW := max(zImgSelX1, zImgSelX2) - min(zImgSelX1, zImgSelX2)
   zImgSelH := max(zImgSelY1, zImgSelY2) - min(zImgSelY1, zImgSelY2)
   zImgSelPx := min(zImgSelX1, zImgSelX2)
   zImgSelPy := min(zImgSelY1, zImgSelY2)
   If (zImgSelW<2)
   {
      zImgSelW := 2
      zImgSelPx := (zImgSelPx>=2) ? zImgSelPx - 2 : 0
   }

   If (zImgSelH<2)
   {
      zImgSelH := 2
      zImgSelPy := (zImgSelPy>=2) ? zImgSelPy - 2 : 0
   }
}

ResizePanelHelpBoxInfo() {
    msgBoxWrapper(appTitle ": HELP", "In «Advanced mode» there is limited support for color depths other than 24 and 32 bits. All images will be converted to 24 bits per pixel. If the alpha channel is present, the resulted file will be in 32 bits, if the format allows. When saving images in formats that do not support an alpha channel, the window background color is used.`n`nUse «Simple mode» to better preserve color depths. It has full support for: 1-, 8-, 24-, 32-, 16- (UINT16), 48- (RGB16), 64- (RGBA16), 32- (FLOAT), 96- (RGBF) and 128- (RGBAF) bits images. High-dynamic range formats supported: .EXR, .HDR, .JXR, .HDP, .PFM and .TIFF.`n`nPlease also note, while there is full support for multi-frames/paged images [for GIFs and TIFFs only] in the viewport... on file (re)save or format conversion, only the first frame will be preserved.", 0, 0, 0)
}

OpenGitHub() {
  Static thisURL := "https://github.com/marius-sucan/Quick-Picto-Viewer"
  Try Run, % thisURL
  Catch wasError
        Sleep, 1

  If wasError
     msgBoxWrapper(appTitle ": ERROR", "An unknown error occured opening the URL...`n" %thisURL%, 0, 0, "error")

  CloseWindow()
}

AboutWindow() {
    createSettingsGUI(1)
    btnWid := 100
    txtWid := 360
    Gui, Add, Button, x1 y1 h1 w1 Default gCloseWindow, Close
    Gui, -DPIScale
    Gui, Font, s19 Bold, Arial, -wrap
    Gui, Add, Text, x20 y15 Section, %appTitle% v%appVersion%
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
    Gui, Add, Text, y+10 w%txtWid%, Current version: v%appVersion% from %vReleaseDate%. AHK version: %A_AhkVersion%.
    Gui, Add, Text, y+10 w%txtWid%, Dedicated to people with really large image collections and slideshow needs :-).
    Gui, Add, Text, y+10 w%txtWid%, This application contains code from various entities. You can find more details in the source code.
    Gui, Font, Bold
    Gui, Add, Link, y+15 w%txtWid%, To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> or <a href="mailto:marius.sucan@gmail.com?subject=%appTitle% v%appVersion%">send me feedback</a>.
    Gui, Add, Link, y+15 w%txtWid%, New and previous versions are available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">GitHub</a>.
    Gui, Font, Normal
    If !A_IsAdmin
    {
       Gui, Add, Button, xs y+25 w105 Default gCloseWindow, &Close
       Gui, Add, Button, x+15 gRunAdminMode, &Run in admin mode
    }
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, About %appTitle% v%appVersion%
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

   imgPath := getIDimage(currentFileIndex)
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

    createSettingsGUI(20, "PanelResolutionSorting")
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
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Choose sorting mode: %appTitle%
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

    createSettingsGUI(12, "PanelJpegPerformOperation")
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
       Gui, Add, Button, x+5 hp w%btnWid% gPanelImgAutoCrop, &Configure auto-crop
       Gui, Add, Button, xs+0 y+25 h30 w35 gPreviousPicture, <<
       Gui, Add, Button, x+5 hp wp gNextPicture, >>
       Gui, Add, Button, x+5 hp w%btnWid% Default gBtnPerformJpegOp vmainBtnACT, &Perform operation
    } Else
       Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gBtnPerformJpegOp, &Perform operation
    Gui, Add, Button, x+5 hp w80 gCloseWindow, C&lose
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, JPEG lossless operations: %appTitle%
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

    imgPath := getIDimage(currentFileIndex)
    initFIMGmodule()
    If !wasInitFIMlib
    {
       msgBoxWrapper(appTitle ": ERROR", "Unable to initialize the FreeImage library module...`n`nThis functionality is currently unavailable...", 0, 0, "error")
       Return
    }

    lastInvoked := A_TickCount
    ForceRefreshNowThumbsList()
    filesElected := getSelectedFiles(0, 1)
    If (filesElected>1)
    {
       CloseWindow()
       batchJpegLLoperations()
       Return
    } Else If !InStr(currentPixFmt, "argb")
    {
       destroyGDIfileCache(0)
       r := coreJpegLossLessAction(imgPath, jpegDesiredOperation, jpegDoCrop)
    }

    GuiControl, SettingsGUIA: Disable, mainBtnACT
    SetTimer, reactivateMainBtnACT, -800
    If r
    {
       FlipImgV := FlipImgH := vpIMGrotation := 0
       showTOOLtip("JPEG operation completed succesfully.")
       RefreshImageFile()
    } Else
    {
       SoundBeep, 300, 100
       msgBoxWrapper(appTitle ": ERROR", "The JPEG operation has failed. The file might not be a JPEG as the file extension suggests...", 0, 0, "error")
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
   filesElected := getSelectedFiles(0, 1)
   If (filesElected>1 && jpegDoCrop=1) || (filesElected>150)
   {
      msgInfos := (jpegDoCrop=1) ? "`n`nThe crop operation IS irreversible!" : ""
      msgResult := msgBoxWrapper(appTitle ": Confirmation", "Are you sure you want to perform the JPEG transformations on the selected files? There are currently " filesElected " selected files. " msgInfos, 4, 0, "question")
      If (msgResult="Yes")
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

   filesPerCore := filesElected//realSystemCores
   If (filesPerCore<2 && realSystemCores>1)
   {
      systemCores := filesElected//2
      filesPerCore := filesElected//systemCores
   } Else systemCores := realSystemCores

   destroyGDIfileCache()
   backCurrentSLD := CurrentSLD
   mustDoMultiCore := (allowMultiCoreMode=1 && systemCores>1 && filesPerCore>1) ? 1 : 0
   If (mustDoMultiCore=1)
   {
      setPriorityThread(-2)
      infoResult := WorkLoadMultiCoresJpegLL(filesElected)
      setPriorityThread(0)
      If (infoResult!="single-core")
         Return
   }

   doStartLongOpDance()
   CurrentSLD := ""
   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      executingCanceableOperation := A_TickCount
      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }

      thisFileIndex := A_Index
      file2rem := getIDimage(thisFileIndex)
      If (InStr(file2rem, "||") || !file2rem)
         Continue
 
      If (A_TickCount - prevMSGdisplay>3000)
      {
         If (failedFiles>0)
            someErrors := "`nFor " failedFiles " files, the operations failed..."

         showTOOLtip("Performing JPEG lossless operations on " countFilez "/" filesElected " files, please wait..." someErrors)
         prevMSGdisplay := A_TickCount
      }

      If !RegExMatch(file2rem, "i)(.\.(jpeg|jpg|jpe))$")
         Continue

      Try FileSetAttrib, -R, %file2rem%
      Sleep, 1
      countTFilez++
      changeMcursor()
      r := coreJpegLossLessAction(file2rem, jpegDesiredOperation, jpegDoCrop)
      If r
         countFilez++
      Else
         failedFiles++
   }

   If (failedFiles>0)
      someErrors := "`nFor " failedFiles " files, the operations failed..."

   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
      showTOOLtip("Operation aborted. " countFilez " out of " filesElected " selected files were processed until now..." someErrors)
   Else
      showTOOLtip(countFilez " out of " countTFilez " selected JPEG files were processed" someErrors)

   CurrentSLD := backCurrentSLD
   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
   Return
}

coreJpegLossLessAction(imgPath, jpegOperation, mustCrop) {
    If (mustCrop=1 && activateImgSelection=1) || (mustCrop=1 && hasInitSpecialMode=1)
    {
       changeMcursor()
       r1 := GetImgFileDimension(imgPath, imgW, imgH)
       If (relativeImgSelCoords=1)
          calcRelativeSelCoords("--", imgW, imgH)

       calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
       x1 := Round(X1), y1 := Round(Y1)
       x2 := Round(X2), y2 := Round(Y2)
       changeMcursor()
       r := FreeImage_JPEGTransformCombined(imgPath, imgPath, jpegOperation - 1, X1, Y1, X2, Y2)
    } Else
    {
       changeMcursor()
       r := FreeImage_JPEGTransform(imgPath, imgPath, jpegOperation - 1)
    }

    Return r
}

toggleColorsAdjusterPanelWindow(lastState) {
   If (AnyWindowOpen!=10 && imgEditPanelOpened=!=1)
      Return

   WinSet, Transparent, % (lastState=1) ? 255 : 190, ahk_id %hSetWinGui%
   thisHeight := imgHUDbaseUnit//10 + 2
   thisWidth := imgHUDbaseUnit//5 + 2
   If (lastState=0)
      Gui, SettingsGUIA: Show, w%thisWidth% h%thisHeight%
   Else
      Gui, SettingsGUIA: Show, AutoSize
}

ColorsAdjusterPanelWindow() {
    Global sliderBright, sliderContrst, sliderSatu, realTimePreview, CustomZoomCB, infoImgZoom
         , infoBright, infoContrst, infoSatu, BtnLumPlus, BtnLumMin, BtnFlipH, infoZatAdjust
         , BtnGammPlus, BtnGammMin, BtnSatPlus, BtnSatMin, ResizeModeDL, BtnFlipV, infohueAdjust
         , infoRGBchnls, RGBcbList := "-3.0|-2.0|-1.5|-1.0|-0.9|-0.8|-0.7|-0.6|-0.5|-0.4|-0.3|-0.2|-0.1|0.0|0.1|0.2|0.3|0.4|0.5|0.6|0.7|0.8|0.9|1.0|1.5|2.0|3.0"
         , infoRealGammos, infoThreshold, UIimgThreshold, UIrealGammos, infoImgRotation, UIdoubleZoom

    If (thumbsDisplaying=1)
       Return

    imgPath := getIDimage(currentFileIndex)
    If !FileRexists(imgPath)
    {
       showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
       SoundBeep, 300, 50
       Return
    }

    If (activateImgSelection=1)
       toggleImgSelection()

    setImageLoading()
    showTOOLtip("Please wait, opening panel...")
    createSettingsGUI(10, "ColorsAdjusterPanelWindow")
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
    Gui, Add, Slider, xs y+5 AltSubmit NoTicks ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vzatAdjust Range-100-100, % zatAdjust
    Gui, Add, Slider, x+5 AltSubmit NoTicks ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vhueAdjust Range-180-180, % hueAdjust
    Gui, Add, Text, xs y+8 w%slide2Wid% gBtnResetRealGamma vinfoRealGammos, Gamma: ----
    Gui, Add, Text, x+5 w%slide2Wid% gBtnResetThreshold vinfoThreshold, Threshold: ----
    Gui, Add, Slider, xs y+5 AltSubmit NoTicks ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vUIrealGammos Range0-800, % UIrealGammos
    Gui, Add, Slider, x+5 AltSubmit NoTicks ToolTip w%slide2Wid% gColorPanelTriggerImageUpdate vUIimgThreshold Range0-100, % UIimgThreshold
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
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Adjust image view: %appTitle%
    updatePanelColorsInfo()
    updatePanelColorSliderz()
    SetTimer, RemoveTooltip, -100
    SetTimer, ResetImgLoadStatus, -50
}

BtnResetBrightness() {
  lumosAdjust := lumosGrayAdjust := 1
  GuiControl, SettingsGUIA:, infoBright, Brightness: 1.000
  GuiControl, SettingsGUIA:, sliderBright, 1
  INIaction(1, "lumosAdjust", "General")
  INIaction(1, "lumosGrayAdjust", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetContrast() {
  GammosAdjust := GammosGrayAdjust := 0
  GuiControl, SettingsGUIA:, infoContrst, Contrast: 0.000
  GuiControl, SettingsGUIA:, sliderContrst, 0
  INIaction(1, "GammosAdjust", "General")
  INIaction(1, "GammosGrayAdjust", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetSaturation() {
  satAdjust := 1
  GuiControl, SettingsGUIA:, infoSatu, Saturation: 1.000
  GuiControl, SettingsGUIA:, sliderSatu, 0
  INIaction(1, "satAdjust", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetVibrance() {
  zatAdjust := 0
  GuiControl, SettingsGUIA:, infoZatAdjust, Vibrance: 0`%
  GuiControl, SettingsGUIA:, zatAdjust, 0
  INIaction(1, "zatAdjust", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetHue() {
  hueAdjust := 0
  GuiControl, SettingsGUIA:, infohueAdjust, Hue: 0° 
  GuiControl, SettingsGUIA:, hueAdjust, 0
  INIaction(1, "hueAdjust", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetRealGamma() {
  realGammos := 1
  GuiControl, SettingsGUIA:, infoRealGammos, Gamma: 1.000 
  GuiControl, SettingsGUIA:, UIrealGammos, 100
  INIaction(1, "realGammos", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetThreshold() {
  imgThreshold := 0
  GuiControl, SettingsGUIA:, infoThreshold, Threshold: 0
  GuiControl, SettingsGUIA:, UIimgThreshold, 0
  INIaction(1, "imgThreshold", "General")
  dummyTimerDelayiedImageDisplay(50)
}

BtnResetCHNdec() {
  chnRdecalage := chnGdecalage := chnBdecalage := 0
  GuiControl, SettingsGUIA: Choose, chnRdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnGdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnBdecalage, 14
  INIaction(1, "chnRdecalage", "General")
  INIaction(1, "chnGdecalage", "General")
  INIaction(1, "chnBdecalage", "General")
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
  INIaction(1, "vpIMGrotation", "General")
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
  SetTimer, WriteSettingsColorAdjustments, -90
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
      imgPath := getIDimage(currentFileIndex)
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
   SetTimer, WriteSettingsColorAdjustments, -150
}

PanelFileFormatConverter() {
    Global btnFldr, IDbtnConvert
    filesElected := getSelectedFiles(0, 1)
    createSettingsGUI(15, "PanelFileFormatConverter")
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
    ReadSettingsFormatConvert()
    Gui, Add, Text, x15 y15 Section, Destination format:
    Gui, Add, DropDownList, x+10 w85 gTglDesiredSaveFormat AltSubmit Choose%userDesireWriteFMT% vuserDesireWriteFMT, .BMP|.GIF|.HDP|.J2C|.J2K|.JFIF|.JNG|.JP2|.JPG|.JXR|.PNG|.PPM|.TGA|.TIF|.WDP|.WEBP|.XPM
    Gui, Add, Checkbox, xs y+10 gTglKeepOriginals Checked%OnConvertKeepOriginals% vOnConvertKeepOriginals, &Keep original file[s]
    Gui, Add, Checkbox, xs y+10 gTglOverwriteFiles Checked%userOverwriteFiles% vuserOverwriteFiles, On file name collision, overwrite existing file in the destination
    Gui, Add, Checkbox, y+10 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file[s] in the following folder: 
    Gui, Add, Edit, xp+10 y+5 wp r1 +0x0800 -wrap vResizeDestFolder, % ResizeDestFolder
    Gui, Add, Button, x+5 hp w90 gBTNchangeResizeDestFolder vbtnFldr, C&hoose
    If (filesElected>1)
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
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Convert image(s) format: %appTitle%
}

TglKeepOriginals() {
    GuiControlGet, OnConvertKeepOriginals
    INIaction(1, "OnConvertKeepOriginals", "General")
}

TglOverwriteFiles() {
    GuiControlGet, userOverwriteFiles
    INIaction(1, "userOverwriteFiles", "General")
}

TglDesiredSaveFormat() {
    GuiControlGet, userDesireWriteFMT
    INIaction(1, "userDesireWriteFMT", "General")
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
      msgBoxWrapper(appTitle ": ERROR", "The ." rDesireWriteFMT " format is currently unsupported. The FreeImage library failed to properly initialize...", 0, 0, "error")
      Return
   }

   INIaction(1, "ResizeDestFolder", "General")
   INIaction(1, "OnConvertKeepOriginals", "General")
   INIaction(1, "userOverwriteFiles", "General")
   INIaction(1, "userDesireWriteFMT", "General")
   If (markedSelectFile>1)
   {
      CloseWindow()
      batchConvert2format()
   } Else convert2format()
}

PanelAdjustImageCanvasSize() {
    Global userEditWidth, userEditHeight, ResultEditWidth, ResultEditHeight
         , userAddTop, userAddBottom, userAddLeft, userAddRight, userAddCenter

    createSettingsGUI(28, "PanelAdjustImageCanvasSize")
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

    INIaction(0, "ResizeKeepAratio", "General")
    INIaction(0, "ResizeInPercentage", "General")
    INIaction(0, "adjustCanvasMode", "General")
    INIaction(0, "adjustCanvasCentered", "General")
    INIaction(0, "adjustCanvasNoBgr", "General")
    INIaction(0, "FillAreaColor", "General")
    INIaction(0, "FillAreaOpacity", "General")

    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    r1 := Gdip_GetImageDimensions(whichBitmap, oImgW, oImgH)
    If r1
    {
       CloseWindow()
       SoundBeep, 300, 100
       showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Return
    }

    Gui, Add, Text, x15 y15 Section, Original image size: %oImgW% x %oImgH% pixels.
    Gui, Add, Edit, x15 y15 w1 r1 limit7 -multi -wrap, -
    Gui, Add, Text, xs y+10, Set new canvas dimensions (W x H):
    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 limit7 -multi number -wrap gEditResizeWidth vuserEditWidth, % (ResizeInPercentage=1) ? 100 : oImgW
    Gui, Add, Edit, x+5 w%editWid% r1 limit7 -multi number -wrap gEditResizeHeight vuserEditHeight, % (ResizeInPercentage=1) ? 100 : oImgH
    Gui, Add, Checkbox, x+5 hp gTglRszInPercentage Checked%ResizeInPercentage% vResizeInPercentage, Use `% percentages
    Gui, Add, Checkbox, xs+15 y+5 hp gTglRszKeepAratio Checked%ResizeKeepAratio% vResizeKeepAratio, Keep aspect ratio
    Gui, Add, Checkbox, x+5 hp Checked%adjustCanvasCentered% vadjustCanvasCentered, Centered image

    Gui, Add, Text, xs y+15, Resulted dimensions and background color:
    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 Disabled -wrap vResultEditWidth, % oImgW
    Gui, Add, Edit, x+5 wp r1 Disabled -wrap vResultEditHeight, % oImgH
    Gui, Add, ListView, x+5 wp hp %CCLVO% Background%FillAreaColor% vFillAreaColor hwndhLVfillColor,
    Gui, Add, ComboBox, x+5 wp vFillAreaOpacity, 25|50|75|100|150|200|255|%FillAreaOpacity%||

    Gui, Add, Checkbox, xs y+10 hp Checked%adjustCanvasNoBgr% vadjustCanvasNoBgr gupdateUIadjustCanvasPanel, Transparent background 
    Gui, Add, Checkbox, xs y+10 Section hp Checked%adjustCanvasMode% vadjustCanvasMode gupdateUIadjustCanvasPanel, Add margins to current image dimensions:
    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 Disabled +0x0800, -
    Gui, Add, Edit, x+5 wp r1 limit6 -multi number -wrap gEditCanvasMargins vuserAddTop, 0
    Gui, Add, Edit, x+5 wp r1 Disabled +0x0800, -

    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 limit6 -multi number -wrap gEditCanvasMargins vuserAddLeft, 0
    Gui, Add, Edit, x+5 wp r1 limit6 -multi number -wrap gEditCanvasMargins vuserAddCenter, 0
    Gui, Add, Edit, x+5 wp r1 limit6 -multi number -wrap gEditCanvasMargins vuserAddRight, 0

    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 Disabled +0x0800, -
    Gui, Add, Edit, x+5 w%editWid% r1 limit6 -multi number -wrap gEditCanvasMargins vuserAddBottom, 0
    Gui, Add, Edit, x+5 wp r1 Disabled +0x0800, -

    Gui, Add, Button, xs+0 y+20 h30 w%btnWid% gBTNadjustCanvasAction Default, &Adjust canvas
    Gui, Add, Button, x+5 hp w85 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Adjust image canvas size: %appTitle%
    updateUIadjustCanvasPanel()
}

EditCanvasMargins() {
   GuiControlGet, userAddTop
   GuiControlGet, userAddBottom
   GuiControlGet, userAddCenter
   GuiControlGet, userAddLeft
   GuiControlGet, userAddRight
   If (!userAddTop || userAddTop<0)
      userAddTop := 0
   If (!userAddBottom || userAddBottom<0)
      userAddBottom := 0
   If (!userAddCenter || userAddCenter<0)
      userAddCenter := 0
   If (!userAddLeft || userAddLeft<0)
      userAddLeft := 0
   If (!userAddRight || userAddRight<0)
      userAddRight := 0

   whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
   Gdip_GetImageDimensions(whichBitmap, oImgW, oImgH)
   thisWidth := oImgW + userAddLeft + userAddRight + userAddCenter
   thisHeight := oImgH + userAddTop + userAddBottom + userAddCenter
   GuiControl, SettingsGUIA:, ResultEditWidth, % Round(thisWidth)
   GuiControl, SettingsGUIA:, ResultEditHeight, % Round(thisHeight)
}

updateUIadjustCanvasPanel() {
    GuiControlGet, adjustCanvasNoBgr
    GuiControlGet, adjustCanvasMode

    If (adjustCanvasMode=1)
    {
       EditCanvasMargins()
       GuiControl, SettingsGUIA: Disable, ResizeKeepAratio
       GuiControl, SettingsGUIA: Disable, ResizeInPercentage
       GuiControl, SettingsGUIA: Disable, adjustCanvasCentered
       GuiControl, SettingsGUIA: Disable, userEditHeight
       GuiControl, SettingsGUIA: Disable, userEditWidth
       GuiControl, SettingsGUIA: Enable, userAddCenter
       GuiControl, SettingsGUIA: Enable, userAddTop
       GuiControl, SettingsGUIA: Enable, userAddBottom
       GuiControl, SettingsGUIA: Enable, userAddLeft
       GuiControl, SettingsGUIA: Enable, userAddRight
    } Else
    {
       EditResizeWidth()
       GuiControl, SettingsGUIA: Disable, userAddCenter
       GuiControl, SettingsGUIA: Disable, userAddTop
       GuiControl, SettingsGUIA: Disable, userAddBottom
       GuiControl, SettingsGUIA: Disable, userAddLeft
       GuiControl, SettingsGUIA: Disable, userAddRight
       GuiControl, SettingsGUIA: Enable, ResizeKeepAratio
       GuiControl, SettingsGUIA: Enable, ResizeInPercentage
       GuiControl, SettingsGUIA: Enable, adjustCanvasCentered
       GuiControl, SettingsGUIA: Enable, userEditHeight
       GuiControl, SettingsGUIA: Enable, userEditWidth
    }

    If (adjustCanvasNoBgr=1)
    {
       GuiControl, SettingsGUIA: Disable, FillAreaColor
       GuiControl, SettingsGUIA: Disable, FillAreaOpacity
    } Else
    {
       GuiControl, SettingsGUIA: Enable, FillAreaColor
       GuiControl, SettingsGUIA: Enable, FillAreaOpacity
    }

    INIaction(1, "adjustCanvasMode", "General")
    INIaction(1, "adjustCanvasNoBgr", "General")
}

BTNadjustCanvasAction() {
    GuiControlGet, adjustCanvasCentered
    GuiControlGet, adjustCanvasNoBgr
    GuiControlGet, adjustCanvasMode
    GuiControlGet, ResizeInPercentage
    GuiControlGet, ResizeKeepAratio
    GuiControlGet, FillAreaOpacity
    GuiControlGet, userAddTop
    GuiControlGet, userAddBottom
    GuiControlGet, userAddCenter
    GuiControlGet, userAddLeft
    GuiControlGet, userAddRight
    GuiControlGet, ResultEditHeight
    GuiControlGet, ResultEditWidth

    INIaction(1, "ResizeKeepAratio", "General")
    INIaction(1, "ResizeInPercentage", "General")
    INIaction(1, "adjustCanvasMode", "General")
    INIaction(1, "adjustCanvasCentered", "General")
    INIaction(1, "adjustCanvasNoBgr", "General")
    INIaction(1, "FillAreaColor", "General")
    FillAreaOpacity := Trim(FillAreaOpacity)
    FillAreaOpacity := StrReplace(FillAreaOpacity, "%")
    FillAreaOpacity := StrReplace(FillAreaOpacity, A_Space)
    If !isNumber(FillAreaOpacity)
       FillAreaOpacity := 255

    capValuesInRange(FillAreaOpacity, 5, 255)
    INIaction(1, "FillAreaOpacity", "General")
    If (!userAddTop || userAddTop<0)
       userAddTop := 0
    If (!userAddBottom || userAddBottom<0)
       userAddBottom := 0
    If (!userAddCenter || userAddCenter<0)
       userAddCenter := 0
    If (!userAddLeft || userAddLeft<0)
       userAddLeft := 0
    If (!userAddRight || userAddRight<0)
       userAddRight := 0

    whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
    Gdip_GetImageDimensions(whichBitmap, oImgW, oImgH)
    If (ResultEditWidth=oImgW && ResultEditHeight=oImgH)
    {
       SoundBeep , 300, 100
       showTOOLtip("The new dimension is equal with the initial one...")
       SetTimer, RemoveTooltip, % -msgDisplayTime//2
       Return
    }
  
    CloseWindow()
    activateImgSelection := editingSelectionNow := 1
    ChangeImageCanvasSize(ResultEditWidth, ResultEditHeight, userAddTop, userAddBottom, userAddLeft, userAddRight, userAddCenter, 0)
}

PanelResizeImageWindow() {
    Global userEditWidth, userEditHeight, ResultEditWidth, ResultEditHeight, btnFldr

    ToolTip, Please wait...
    filesElected := getSelectedFiles(0, 1)
    multipleFilesMode := (filesElected>1) ? 1 : 0
    If (multipleFilesMode=0 && !PanelsCheckFileExists())
    {
       ToolTip
       Return
    }

    createSettingsGUI(4, "PanelResizeImageWindow")
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

    ReadSettingsImageProcessing()
    img2resizePath := getIDimage(currentFileIndex)
    If (multipleFilesMode=0)
    {
       zPlitPath(img2resizePath, 0, fileNamu, folderu)
       r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
       FileGetSize, fileSizu, % img2resizePath, K
       If !r1
       {
          CloseWindow()
          showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
          SoundBeep, 300, 100
          img2resizePath := ""
          SetTimer, RemoveTooltip, % -msgDisplayTime
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

    If (resetImageViewOnChange=1)
       ResizeApplyEffects := 0

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
    If (resetImageViewOnChange=1)
       GuiControl, Disable, ResizeApplyEffects

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
       Gui, Add, Button, x+5 hp w%btnWid% gPanelSimpleResizeRotate, &Simple mode
       If (userUnsprtWriteFMT=1)
          GuiControl, SettingsGUIA: Disable, userDesireWriteFMT
    } Else
    {
       Gui, Add, Button, xs+0 y+20 h30 w%btnWid% gCopy2ClipResizedIMG, &Copy to clipboard
       Gui, Add, Button, x+5 hp wp Default gBTNsaveResizedIMG, &Save image as...
       Gui, Add, Button, xs y+5 hp w%btnWid% gPanelSimpleResizeRotate, &Simple mode
       Gui, Add, Button, x+5 hp w85 gResizePanelHelpBoxInfo, Help
    }
    ToolTip
    Gui, Add, Button, x+5 hp w85 gCloseWindow, C&ancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Resize/crop image(s): %appTitle%
}

BTNchangeResizeDestFolder() {
   SelectImg := openFileDialogWrapper("S2", ResizeDestFolder "\this-folder", "Add new folder(s) to the list", "All files (*.*)")
   If !SelectImg
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
      INIaction(1, "ResizeDestFolder", "General")
   }
}

batchIMGresizer(desiredW, desiredH, isPercntg) {

   cleanResizeUserOptionsVars()
   If (!desiredH || !desiredW
   || desiredW<1 || desiredH<1)
   {
      showTOOLtip("Incorrect values given...")
      SoundBeep, 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }

   If (desiredW<5 || desiredH<5) && (isPercntg!=1)
   {
      showTOOLtip("Incorrect values given...")
      SoundBeep, 300, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }

   overwriteWarning := (ResizeUseDestDir!=1) ? "`n`nWARNING: All the original files will be overwritten!" : ""
   filesElected := getSelectedFiles(0, 1)
   If (filesElected>1)
   {
      msgResult := msgBoxWrapper(appTitle ": Confirmation", "Please confirm you want to process multiple images in one go. There are " filesElected " selected files for this operation. " overwriteWarning, 4, 0, "question")
      If (msgResult="Yes")
         good2go := 1
      Else
         Return
   } Else Return

   CloseWindow()
   destroyGDIfileCache()
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   thisImgQuality := (ResizeQualityHigh=1) ? 7 : 5
   If (ResizeKeepAratio=1 && isPercntg=1)
      desiredW := desiredH

   showTOOLtip("Processing " filesElected " images, please wait...")
   prevMSGdisplay := A_TickCount
   countTFilez := countFilez := 0
   If (!FileExist(ResizeDestFolder) && ResizeUseDestDir=1)
      FileCreateDir, % ResizeDestFolder

   destroyGDIfileCache()
   doStartLongOpDance()
   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      thisFileIndex := A_Index
      imgPath := getIDimage(thisFileIndex)
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

      If (determineTerminateOperation()=1)
      {
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
   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
      showTOOLtip("Operation aborted. "  countFilez " out of " filesElected " selected files were processed until now..." someErrors)
   Else
      showTOOLtip("Finished processing "  countFilez " out of " filesElected " selected files" someErrors)

   interfaceThread.ahkassign("runningLongOperation", 0)
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

WriteSettingsResizePanel() {
  INIaction(1, "ResizeApplyEffects", "General")
  INIaction(1, "ResizeCropAfterRotation", "General")
  INIaction(1, "ResizeInPercentage", "General")
  INIaction(1, "ResizeKeepAratio", "General")
  INIaction(1, "ResizeRotationUser", "General")
  INIaction(1, "ResizeQualityHigh", "General")
  INIaction(1, "ResizeWithCrop", "General")
  INIaction(1, "ResizeDestFolder", "General")
  INIaction(1, "ResizeUseDestDir", "General")
}

WriteSettingsResizeSimplePanel() {
  INIaction(1, "SimpleOperationsFlipV", "General")
  INIaction(1, "SimpleOperationsFlipH", "General")
  INIaction(1, "SimpleOperationsDoCrop", "General")
  INIaction(1, "SimpleOperationsRotateAngle", "General")
  INIaction(1, "SimpleOperationsScaleImgFactor", "General")
  INIaction(1, "ResizeQualityHigh", "General")
  INIaction(1, "ResizeDestFolder", "General")
  INIaction(1, "ResizeUseDestDir", "General")
}

BTNsaveResizedIMG() {
    Static saveImgFormatsList := {1:"bmp", 2:"gif", 3:"hdp", 4:"j2c", 5:"j2k", 6:"jfif", 7:"jng", 8:"jp2", 9:"jpg", 10:"jxr", 11:"png", 12:"ppm", 13:"tga", 14:"tif", 15:"wdp", 16:"webp", 17:"xpm"}
    GuiControlGet, ResultEditWidth
    GuiControlGet, ResultEditHeight
    GuiControlGet, userEditWidth
    GuiControlGet, userEditHeight
    GuiControlGet, ResultEditHeight
    GuiControlGet, ResizeApplyEffects
    GuiControlGet, ResizeCropAfterRotation
    GuiControlGet, ResizeDestFolder
    GuiControlGet, ResizeInPercentage
    GuiControlGet, ResizeKeepAratio
    GuiControlGet, ResizeQualityHigh
    GuiControlGet, ResizeRotationUser
    GuiControlGet, ResizeUseDestDir
    GuiControlGet, ResizeWithCrop

    cleanResizeUserOptionsVars()
    filesElected := getSelectedFiles(0, 1)
    If (filesElected>1)
    {
       GuiControlGet, userDesireWriteFMT
       GuiControlGet, userUnsprtWriteFMT
       rDesireWriteFMT := saveImgFormatsList[userDesireWriteFMT]
       If (!RegExMatch(rDesireWriteFMT, "i)(bmp|png|tiff|tif|gif|jpg|jpeg)$") && wasInitFIMlib!=1)
       {
          SoundBeep, 300, 100
          msgBoxWrapper(appTitle ": ERROR", "The ." rDesireWriteFMT " format is currently unsupported. The FreeImage library failed to properly initialize...", 0, 0, "error")
          Return
       }

       If (ResizeUseDestDir=1)
          INIaction(1, "ResizeDestFolder", "General")

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
   If (!FileExist(ResizeDestFolder) && ResizeUseDestDir=1)
      FileCreateDir, % ResizeDestFolder

   file2save := openFileDialogWrapper("S18", startPath, "Save processed image as...", "Images (" dialogSaveFptrn ")")
   If file2save
   {
      zPlitPath(img2resizePath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
      zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, nExt)
      If !nExt
         file2save .= "." oExt

      If !RegExMatch(file2save, saveTypesRegEX)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "Please save the file using one of the supported file format extensions: " saveTypesFriendly ". ", 0, 0, "error")
         Return
      }

      zPlitPath(file2save, 0, OutFileName, OutDir)
      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "This format is currently unsupported, because the FreeImage library failed to properly initialize.`n`n" OutFileName, 0, 0, "error")
         Return
      }

      destroyGDIfileCache()
      r := coreResizeIMG(img2resizePath, ResultEditWidth, ResultEditHeight, file2save, 0, 0, ResizeRotationUser)
      If r
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "ERROR. Unable to save file... error code: " r ".`n`n" OutFileName "`n`n" OutDir "\", 0, 0, "error")
         Return
      }

      SetTimer, WriteSettingsResizePanel, -90
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
   cleanResizeUserOptionsVars()

   If (!ResultEditHeight || !ResultEditWidth
   || ResultEditWidth<5 || ResultEditHeight<5)
   {
      SoundBeep, 300, 900
      Return
   }

   r := coreResizeIMG(img2resizePath, ResultEditWidth, ResultEditHeight, "--", 0, 1, ResizeRotationUser)
   If !r
   {
      showTOOLtip("Processed image copied to clipboard")
      SoundBeep, 900, 100
   } Else 
   {
      SoundBeep, 300, 100
      msgBoxWrapper(appTitle ": ERROR", "Unable to copy the processed image to the clipboard... error code: " r, 0, 0, "error")
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

   If (AnyWindowOpen=28)
   {
      whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
      Gdip_GetImageDimensions(whichBitmap, oImgW, oImgH)
   } Else GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)

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

   If (AnyWindowOpen=28)
   {
      whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
      Gdip_GetImageDimensions(whichBitmap, oImgW, oImgH)
   } Else GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)

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
   } Else If (AnyWindowOpen=28)
   {
      whichBitmap := StrLen(UserMemBMP)>2 ? UserMemBMP : gdiBitmap
      Gdip_GetImageDimensions(whichBitmap, oImgW, oImgH)
   } Else GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)

   GuiControl, SettingsGUIA:, userEditWidth, % (ResizeInPercentage=1) ? 100 : oImgW
   GuiControl, SettingsGUIA:, userEditHeight, % (ResizeInPercentage=1) ? 100 : oImgH
   If (filesElected<2)
   {
      GuiControl, SettingsGUIA:, ResultEditWidth, % oImgW
      GuiControl, SettingsGUIA:, ResultEditHeight, % oImgH
   }
   INIaction(1, "ResizeInPercentage", "General")
}

TglRszKeepAratio() {
   GuiControlGet, userEditWidth
   GuiControlGet, ResizeKeepAratio
   If (!markedSelectFile || ResizeKeepAratio=1 && ResizeInPercentage=1)
      GuiControl, SettingsGUIA:, userEditWidth, % userEditWidth
   INIaction(1, "ResizeKeepAratio", "General")
}

TglRszUnsprtFrmt() {
   GuiControlGet, userUnsprtWriteFMT
   GuiControlGet, userDesireWriteFMT
   If (userUnsprtWriteFMT>1)
      GuiControl, SettingsGUIA: Enable, userDesireWriteFMT
   Else
      GuiControl, SettingsGUIA: Disable, userDesireWriteFMT
   INIaction(1, "userDesireWriteFMT", "General")
}

cleanResizeUserOptionsVars() {
    ResizeRotationUser := StrReplace(ResizeRotationUser, ":")
    ResizeRotationUser := StrReplace(ResizeRotationUser, "°")
    ResizeRotationUser := StrReplace(ResizeRotationUser, "rotate")
    ResizeRotationUser := Trim(ResizeRotationUser)

    If (SimpleOperationsRotateAngle=2)
       simpleOpRotationAngle := 90
    Else If (SimpleOperationsRotateAngle=3)
       simpleOpRotationAngle := 180
    Else If (SimpleOperationsRotateAngle=4)
       simpleOpRotationAngle := 270
    Else
       simpleOpRotationAngle := 0

    scaleImgFactor := StrReplace(SimpleOperationsScaleImgFactor, "%")
    scaleImgFactor := StrReplace(scaleImgFactor, A_Space)
    scaleImgFactor := StrReplace(scaleImgFactor, ",", ".")
    simpleOPimgScaleFactor := Round(scaleImgFactor)/100
}

TglRszRotation() {
   GuiControlGet, ResizeRotationUser
   GuiControlGet, ResizeWithCrop
   cleanResizeUserOptionsVars()
   If (ResizeRotationUser>0 && ResizeWithCrop=1 &&  activateImgSelection=1)
      GuiControl, SettingsGUIA: Enable, ResizeCropAfterRotation
   Else If (activateImgSelection=1)
      GuiControl, SettingsGUIA: Disable, ResizeCropAfterRotation

   INIaction(1, "ResizeWithCrop", "General")
   INIaction(1, "ResizeRotationUser", "General")
}

TglRszCropping() {
   GuiControlGet, ResizeWithCrop
   GuiControlGet, ResizeCropAfterRotation
   If (ResizeRotationUser>0 && ResizeWithCrop=1 && activateImgSelection=1)
      GuiControl, SettingsGUIA: Enable, ResizeCropAfterRotation
   Else If (activateImgSelection=1)
      GuiControl, SettingsGUIA: Disable, ResizeCropAfterRotation
   INIaction(1, "ResizeWithCrop", "General")
   INIaction(1, "ResizeCropAfterRotation", "General")
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
   INIaction(1, "ResizeUseDestDir", "General")
}

TglRszQualityHigh() {
   GuiControlGet, ResizeQualityHigh
   INIaction(1, "ResizeQualityHigh", "General")
}

TglRszApplyEffects() {
   GuiControlGet, ResizeApplyEffects
   INIaction(1, "ResizeApplyEffects", "General")
   If (ResizeApplyEffects=1)
   {
      infoMirroring := defineIMGmirroring()
      If (usrColorDepth>1)
         infoColorDepth := "`nSimulated color depth: " defineColorDepth()
      If (imgFxMode>1)
         infoColors := "`nColors display mode: " DefineFXmodes() " [" currentPixFmt "]"
      If (RenderOpaqueIMG=1)
         infoRenderOpaque .= "`nAlpha channel: REMOVED"
 
      entireString := infoMirroring infoColors infoColorDepth infoRenderOpaque
      entireString := (entireString) ?  "Effects currently activated: " entireString : "No effects currently activated."
      msgBoxWrapper(appTitle, entireString, 0, 0, "info")
   }
}

PanelStaticFolderzManager() {
    Static LViewOthers
    If !(RegExMatch(CurrentSLD, sldsPattern) && mustGenerateStaticFolders!=1 && SLDcacheFilesList=1)
       Return

    createSettingsGUI(2, "PanelStaticFolderzManager")
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
    CountFilesFolderzList := 0
    Gui, Add, Checkbox, xs+0 y+10 gToggleCountFilesFoldersList Checked%CountFilesFolderzList% vCountFilesFolderzList, &Count files in folders list (recursively)
    GuiControl, Disable, CountFilesFolderzList
    Gui, Add, Checkbox, x+10 gToggleForceRegenStaticFs Checked%ForceRegenStaticFolders% vForceRegenStaticFolders, &Force this list to be refreshed on .SLD save
    Gui, Add, Checkbox, xs+0 y+10 gToggleRecursiveStaticRescan vRecursiveStaticRescan Checked%RecursiveStaticRescan%, &Perform recursive (in sub-folders) folder scan
    Gui, Add, Button, xs+0 y+10 h30 w130 gUpdateSelectedStaticFolder, &Rescan folder
    Gui, Add, Button, x+5 hp w%btnWid% gIgnoreSelFolder, &Ignore changes
    Gui, Add, Button, x+5 hp w%btnWid% gRemFilesStaticFolder, Re&move files from list
    Gui, Add, Button, x+5 hp w%btnWid% gOpenDynaFolderBTN, &Open folder
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Cached folders list updater: %appTitle%
    Sleep, 25
    PopulateStaticFolderzList()
}

PanelDynamicFolderzWindow() {
    Static LViewDynas

    createSettingsGUI(3, "PanelDynamicFolderzWindow")
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
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Dynamic folders list: %appTitle%
    Sleep, 25
    LV_ModifyCol(1, "Integer")
    LV_ModifyCol(0, "Integer")
    PopulateDynamicFolderzList()
}

ToggleCountFilesFoldersList() {
  GuiControlGet, CountFilesFolderzList
  If (AnyWindowOpen=3)
     PanelDynamicFolderzWindow()
  Else If (AnyWindowOpen=2)
     PanelStaticFolderzManager()
}

ToggleForceRegenStaticFs() {
  GuiControlGet, ForceRegenStaticFolders
}

ToggleRecursiveStaticRescan() {
  GuiControlGet, RecursiveStaticRescan
}

BTNaddNewFolder2list() {
    CloseWindow()
    Sleep, 10
    r := addNewFolder2list()
    Sleep, 10
    SetTimer, PanelDynamicFolderzWindow, -50
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
       SoundBeep, 300, 100
       msgBoxWrapper(appTitle ": ERROR", "The loaded .SLD file does not seem to be in the correct format. Operation aborted.`n`n" CurrentSLD, 0, 0, "error")
       Return
    }
    Sleep, 25
    If AnyWindowOpen
       CloseWindow()
    Sleep, 50
    updateCachedStaticFolders(folderu, 1)
    showTOOLtip("Folders list information updated")
    SetTimer, RemoveTooltip, % -msgDisplayTime
    Sleep, 50
    PanelStaticFolderzManager()
}

RemFilesStaticFolder() {
    Gui, SettingsGUIA: ListView, LViewOthers
    RowNumber := LV_GetNext(0, "F")
    LV_GetText(folderu, RowNumber, 4)
    LV_GetText(indexSelected, RowNumber, 1)
    If (StrLen(folderu)<3 || folderu="folder path")
       Return

    Sleep, 25
    If AnyWindowOpen
       CloseWindow()
    Sleep, 50
    msgResult := msgBoxWrapper(appTitle ": Remove static folder", "Would you like to remove the files from the index/list pertaining to the static folder selected?`n`n" folderu "\", 4, 0, "question")
    If (msgResult="yes")
    {
       remFilesFromList("|" folderu)
       GenerateRandyList()
       SoundBeep, 900, 100
       RandomPicture()
    }
    Sleep, 550
    PanelStaticFolderzManager()
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
    msgResult := msgBoxWrapper(appTitle ": Remove dynamic folder", "Would you like to remove the files from the index/list pertaining to the removed dynamic folder as well ?`n`n" folderu "\", 4, 0, "question")
    If (msgResult="yes")
    {
       remFilesFromList(folderu)
       GenerateRandyList()
       SoundBeep, 900, 100
       RandomPicture()
    }
    Sleep, 500
    PanelDynamicFolderzWindow()
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
    Try Run, "%folderu%"
    Catch wasError
          Sleep, 1

    If wasError
       msgBoxWrapper(appTitle ": ERROR", "An unknown error occured opening the folder: `n" folderu, 0, 0, "error")
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
    PanelDynamicFolderzWindow()
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
    If RegExMatch(CurrentSLD, sldsPattern)
    {
       FileReadLine, firstLine, % CurrentSLD, 1
       IniRead, tstSLDcacheFilesList, % CurrentSLD, General, SLDcacheFilesList, @
       If (!InStr(firstLine, "[General]") || tstSLDcacheFilesList!=1 || InStr(folderu, "|"))
          good2go := "null"
    } Else good2go := "null"

    If (mustGenerateStaticFolders=0 && good2go!="null" && RegExMatch(CurrentSLD, sldsPattern))
       updateCachedStaticFolders(folderu, 0)

    Sleep, 550
    PanelDynamicFolderzWindow()
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
    CurrentSLD := ""
    markedSelectFile := 0
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
        r := getIDimage(A_Index)
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
        newArrayu[countFiles] := [r]
    }

    renewCurrentFilesList()
    maxFilesIndex := countFiles
    resultedFilesList := newArrayu.Clone()
    ForceRefreshNowThumbsList()
    filesRemoved := oldMaxy - maxFilesIndex
    If (filesRemoved<1)
       filesRemoved := 0
    If (silentus=0)
       showTOOLtip("Finished removing " filesRemoved " files from the list...")
    CurrentSLD := backCurrentSLD
    Sleep, 25
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

UpdateSelectedStaticFolder() {
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
       SoundBeep, 300, 100
       msgBoxWrapper(appTitle ": ERROR", "The loaded .SLD file does not seem to be in the correct format. Operation aborted.`n`n" CurrentSLD, 0, 0, "error")
       Return
    }

    If (RecursiveStaticRescan!=1)
       isRecursive := "|"

    If AnyWindowOpen
       CloseWindow()
    Sleep, 5
    showTOOLtip("Preparing files list... please wait.`n" isRecursive folderu "\")
    coreAddNewFolder(isRecursive folderu, 0, 1)
    modus := isRecursive ? 1 : 0
    updateCachedStaticFolders(folderu, modus)
    Sleep, 5
    SetTimer, RemoveTooltip, % -msgDisplayTime
    PanelStaticFolderzManager()
}

PopulateStaticFolderzList() {
    If (mustGenerateStaticFolders=1 || SLDcacheFilesList!=1)
       Return

    startOperation := A_TickCount
    setImageLoading()
    foldersListu := LoadStaticFoldersCached(CurrentSLD, irrelevantVar)
    Gui, SettingsGUIA: ListView, LViewOthers
    DllPath := FreeImage_FoxGetDllPath("hamming_distance.dll")
    lalala := DllCall("LoadLibraryW", "WStr", DllPath, "UPtr")
    startZeit := A_TickCount
    If (CountFilesFolderzList=1)
    {
       dropFilesSelection(1)
       Tooltip, Preparing the files list... please wait.
       If StrLen(filesFilter)>1
       {
          usrFilesFilteru := filesFilter := ""
          FilterFilesIndex()
       }

       theEntireListu := printLargeStrArray(resultedFilesList, maxFilesIndex, "`n")
       Loop, Parse, foldersListu, `n
       {
            If StrLen(A_LoopField)<2
               Continue
            lineArru := StrSplit(A_LoopField, "*&*")
            foldersListuza .= lineArru[2] "\`n"
       }
       Tooltip, Counting files in each folder... please wait.
       foldersListuza := Trim(foldersListuza)
       StrPutVar(foldersListuza, foldersListuzaUTF, "utf-8")
       StrPutVar(theEntireListu, theEntireListuUTF, "utf-8")
       r := DllCall("hamming_distance.dll\count_string_occurrances", "wstr", theEntireListuUTF, "wstr", foldersListuzaUTF)
       If r
       {
          z := StrGet(r, , "utf-8")
          DllCall("hamming_distance.dll\string_data_free", "uint", r)
          countedFilesArray := StrSplit(z, "`n")
       }
       z := foldersListuza := foldersListuzaUTF := theEntireListuUTF := 0
    }

    LV_ModifyCol(5, "Integer")
    LV_ModifyCol(1, "Integer")
    LV_ModifyCol(0, "Integer")
    doStartLongOpDance()
    startOperation := A_TickCount
    Loop, Parse, foldersListu, `n
    {
        If StrLen(A_LoopField)<2
           Continue

        If (determineTerminateOperation()=1)
        {
           abandonAll := 1
           CountFilesFolderzList := 0
           Break
        }

        countThese++
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
        countFiles :=(CountFilesFolderzList=1) ? countedFilesArray[countThese+1] : "-"

        LV_Add(A_Index, indexu, dirDate, statusu, folderu, countFiles)
        If (A_Index=5)
        {
           Loop, 5
               LV_ModifyCol(A_Index, "AutoHdr Left")
        }
    }
 ;  MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000) 

    executingCanceableOperation := 0
    Loop, 5
        LV_ModifyCol(A_Index, "AutoHdr Left")

    LV_ModifyCol(3, "Sort")
    SetTimer, ResetImgLoadStatus, -25
    If (CountFilesFolderzList=1)
    {
       SoundBeep, 900, 100
       CountFilesFolderzList := 0
       GuiControl, SettingsGUIA:, CountFilesFolderzList, 0
    }
    Tooltip
}

StrPutVar(string, ByRef var, encoding) {
    ; Ensure capacity.
    ; StrPut returns char count, but VarSetCapacity needs bytes.
    VarSetCapacity(var, StrPut(string, encoding) * ((encoding="utf-16"||encoding="cp1200") ? 2 : 1))
    ; Copy or convert the string.
    return StrPut(string, &var, encoding)
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

    ResetImgLoadStatus()
    If AnyWindowOpen
       Try WinGetPos, prevSetWinPosX, prevSetWinPosY,,, ahk_id %hSetWinGui%
    interfaceThread.ahkassign("AnyWindowOpen", 0)
    Global lastOtherWinClose := A_TickCount
    ForceNoColorMatrix := 0
    DestroyGIFuWin()
    Gui, SettingsGUIA: Destroy
    WinActivate, ahk_id %PVhwnd%
    If (imgEditPanelOpened=1)
    {
       viewportStampBMP := Gdip_DisposeImage(viewportStampBMP, 1)
       SetTimer, dummyRefreshImgSelectionWindow, -200
    }

    imgEditPanelOpened := AnyWindowOpen := 0
    interfaceThread.ahkassign("imgEditPanelOpened", 0)
}

TooltipCreator(msg:=0, killWin:=0, forceDarker:=0) {
    Critical, On
    Static prevMsg, lastInvoked := 1

    If (killWin=1 || StrLen(msg)<3)
    {
       If (A_TickCount - lastInvoked<350) && (killWin=1)
       {
          SetTimer, RemoveTooltip, -400
          Return
       }

       toolTipGuiCreated := 0
       interfaceThread.ahkassign("toolTipGuiCreated", 0)
       clearGivenGDIwin(2NDglPG, 2NDglHDC, hGDIinfosWin)
       Return
    }

    If (A_TickCount - lastInvoked<95) && (forceDarker!=1)
    {
       SetTimer, dummyShowToolTip, -200
       Return
    }

    If (!CurrentSLD && currentFileIndex!=0) || (forceDarker=1)
       Gdip_GraphicsClear(2NDglPG, "0x66" WindowBgrColor)
    Else
       Gdip_GraphicsClear(2NDglPG, "0x00" WindowBgrColor)

    GetClientSize(mainWidth, mainHeight, PVhwnd)
    BoxBMP := drawTextInBox(msg, OSDFontName, OSDfntSize, mainWidth*0.8, mainHeight*0.8, OSDtextColor, "0xFF" OSDbgrColor, 0)
    Gdip_GetImageDimensions(BoxBMP, imgW, imgH)
    Gdip_DrawImageRect(2NDglPG, BoxBMP, 0, 0, imgW, imgH)
    r2 := UpdateLayeredWindow(hGDIinfosWin, 2NDglHDC, 0, 0, mainWidth, mainHeight)
    Gdip_DisposeImage(BoxBMP, 1)

    toolTipGuiCreated := 1
    prevMsg := msg
    lastInvoked := A_TickCount
    If (forceDarker!=1)
       interfaceThread.ahkassign("toolTipGuiCreated", 1)
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
    Gui, BlackGuia: -DPIScale -Caption +Owner%PVhwnd% +ToolWindow +E0x80000 +E0x20 +hwndhGuiBlack
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

DestroyGIFuWin() {
    If (slideShowRunning=1 || animGIFplaying=1)
       SetTimer, ResetImgLoadStatus, -15

    autoChangeDesiredFrame("stop")
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
     RunWait, *RunAs "%mainCompiledPath%\regFiles\runThis.bat"
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
  imgPath := getIDimage(currentFileIndex)
  VarSetCapacity(OPENASINFO, A_PtrSize * 3, 0)
  NumPut(&imgPath, OPENASINFO, 0, "Ptr")
  NumPut(0x04, OPENASINFO, A_PtrSize * 2, "UInt")
  DllCall("Shell32.dll\SHOpenWithDialog", "Ptr", 0, "Ptr", &OPENASINFO)
}

PanelImgAutoCrop() {
    Global UIcropThreshold, btnFldr, infoCropTolerance, infoCropThreshold, infoCropDeviation, mainBtnACT
    If (thumbsDisplaying=1)
       ToggleThumbsMode()

    If (vpIMGrotation>0)
    {
       vpIMGrotation := 0
       showTOOLtip("Image rotation: 0°")
       RefreshImageFile()
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Sleep, 250
    }

    createSettingsGUI(17, "PanelImgAutoCrop")
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
    Gui, Add, Checkbox, x+1 gUpdateAutoCropParams Checked%usrAutoCropDeviationPixels% vusrAutoCropDeviationPixels, Deviation factor in pixels
    Gui, Add, Checkbox, xs y+10 w%slide2Wid% gUpdateAutoCropParams Checked%usrAutoCropGenerateSelection% vusrAutoCropGenerateSelection, Generate an image selection
    Gui, Add, Checkbox, x+1 gUpdateAutoCropParams Checked%AutoCropAdaptiveMode% vAutoCropAdaptiveMode, Adaptive color variations
    Gui, Add, Checkbox, xs y+10 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file[s] in the following folder: 
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
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Automatically crop image: %appTitle%
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
    GuiControlGet, AutoCropAdaptiveMode
    GuiControlGet, ResizeUseDestDir
    GuiControlGet, ResizeDestFolder

    usrAutoCropImgThreshold := UIcropThreshold/100
    measureUnit := (usrAutoCropDeviationPixels=1) ? " px" : " %"
    GuiControl, SettingsGUIA:, infoCropTolerance, Color variation tolerance: %usrAutoCropColorTolerance%
    GuiControl, SettingsGUIA:, infoCropThreshold, Image threshold: %UIcropThreshold%
    GuiControl, SettingsGUIA:, infoCropDeviation, Margins deviation factor: %usrAutoCropDeviation%%measureUnit%
    SetTimer, saveAutoCropSettings, -50
}

saveAutoCropSettings() {
   INIaction(1, "ResizeUseDestDir", "General")
   INIaction(1, "ResizeDestFolder", "General")
   INIaction(1, "AutoCropAdaptiveMode", "General")
   INIaction(1, "usrAutoCropDeviationPixels", "General")
   INIaction(1, "usrAutoCropDeviationSnap", "General")
   INIaction(1, "usrAutoCropGenerateSelection", "General")
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
   Gdip_DisposeImage(cornersBMP2, 1)
   DeleteObject(hBitmap)
}

coreCaptureImgCorners(whichBmp, thisSize:=0, thisBoxSize:=0) {
    boxSize := (thisBoxSize=0) ? 220 : thisBoxSize
    realSize := (thisSize=0) ? AutoCropBordersSize : thisSize
    cornersBMP := Gdip_CreateBitmap(boxSize, boxSize)
    G := Gdip_GraphicsFromImage(cornersBMP, 3)
    Gdip_GetImageDimensions(whichBmp, imgW, imgH)

    If (activateImgSelection=1)
    {
       calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
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
    Gdip_DisposeImage(cornersBMP, 1)
    Return cornersBMP2
}

AutoCropAction(zBitmap, varTolerance, threshold, silentMode:=0, forceNoSel:=0) {
   If (silentMode=0)
      showTOOLtip("Calculating auto-cropped region... step 0")

   aBitmap := Gdip_BitmapConvertGray(zBitmap)
   Gdip_GetImageDimensions(aBitmap, Width, Height)
   pBitmap := Gdip_ResizeBitmap(aBitmap, Width//2, Height//2, 0)
   Gdip_DisposeImage(aBitmap, 1)
   ; pBitmap := aBitmap
   alphaUniform := Gdip_TestBitmapUniformity(pBitmap, 3, maxLevelIndex, maxLevelPixels)
   If (alphaUniform=1)
   {
      If (silentMode=0)
      {
         SoundBeep, 900, 100
         showTOOLtip("The image seems to be uniformly colored.")
         SetTimer, RemoveTooltip, -900
      }
      Return
   }

   selCoords := CoreAutoCropAlgo(pBitmap, varTolerance, threshold)
   If (selCoords="error")
   {
      Gdip_DisposeImage(pBitmap, 1)
      SoundBeep, 300, 100
      showTOOLtip("Auto-crop processing aborted by user...")
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }
   selCoords := StrSplit(selCoords, ",")
   X1 := selCoords[1]
   Y1 := selCoords[2]
   X2 := selCoords[3]
   Y2 := selCoords[4]

   If (silentMode=0)
   {
      SoundBeep, 900, 100
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
   interfaceThread.ahkassign("canCancelImageLoad", 1)
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
   x := y := ToleranceHits := abortImgLoad := 0
   E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, Stride1, Scan01, BitmapData1)
   Loop %Height%
   {
      If (AnyWindowOpen>0)
         abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
      If (abortImgLoad>1)
         Break

      y++
      vX := 0, vY := y - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vX := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Width%
      {
         pX := A_Index-1, pY := y - 1
         R1 := Gdip_RFromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"))
     ;  sleep, 10
      ;    ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsW " [" varTolerance "]" "`n" firstR1 ", " primeR1a ", " primeR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         || (valueBetween(prevR1, R1 - varTolerance//1.2, R1 + varTolerance//1.2) && AutoCropAdaptiveMode=1)
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
      If (AnyWindowOpen>0)
         abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
      If (abortImgLoad>1)
         Break

      x++
      vY := 0, vX := x - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vY := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Height%
      {
         pY := A_Index-1, pX := x - 1
         R1 := Gdip_RFromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"))
         ; ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsH "`n" prevR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         || (valueBetween(prevR1, R1 - varTolerance//1.5, R1 + varTolerance//1.5) && AutoCropAdaptiveMode=1)
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
      If (AnyWindowOpen>0)
         abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
      If (abortImgLoad>1)
         Break

      y++
      vX := 0, vY := y - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vX := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Width%
      {
         pX := A_Index-1, pY := y - 1
         R1 := Gdip_RFromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"))
         ; ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsW "`n" prevR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         || (valueBetween(prevR1, R1 - varTolerance//1.5, R1 + varTolerance//1.5) && AutoCropAdaptiveMode=1)
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
      If (AnyWindowOpen>0)
         abortImgLoad := interfaceThread.ahkgetvar.canCancelImageLoad
      If (abortImgLoad>1)
         Break

      x++
      vY := 0, vX := x - 1
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1a, G1, B1)
      vY := 2
      Gdip_FromARGB(NumGet(Scan01+0, (vX*4)+(vY*Stride1), "UInt"), A1, primeR1b, G1, B1)
      primeR1 := Round((primeR1a + primeR1b)/2)
      Loop %Height%
      {
         pY := A_Index-1, pX := x - 1
         R1 := Gdip_RFromARGB(NumGet(Scan01+0, (pX*4)+(pY*Stride1), "UInt"))
         ; ToolTip, % px ", " py "`n" ToleranceHits "," maxThresholdHitsH "`n" prevR1 ", " R1,,, 2
         If (valueBetween(primeR1a, R1 - varTolerance//10, R1 + varTolerance//10) || valueBetween(primeR1, R1 - varTolerance, R1 + varTolerance))
         || (valueBetween(prevR1, R1 - varTolerance//1.5, R1 + varTolerance//1.5) && AutoCropAdaptiveMode=1)
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
   If (abortImgLoad>1)
      selCoords := "error"

   interfaceThread.ahkassign("canCancelImageLoad", 0)
   Return selCoords
}

BTNsaveAutoCroppedFile() {
    UpdateAutoCropParams()
    filesElected := getSelectedFiles(0, 1)
    If (filesElected>1)
    {
       batchAutoCropFiles()
       Return
    }

   imgPath := getIDimage(currentFileIndex)
   zPlitPath(imgPath, 0, OutFileName, OutDir)
   startPath := (ResizeUseDestDir=1) ? ResizeDestFolder "\" OutFileName : imgPath
   file2save := openFileDialogWrapper("S18", startPath, "Save processed image as...", "Images (" dialogSaveFptrn ")")
   If file2save
   {
      If !RegExMatch(file2save, saveTypesRegEX)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "Please save the file using one of the supported file format extensions: " saveTypesFriendly ". ", 0, 0, "error")
         Return
      }

      zPlitPath(file2save, 0, OutFileName, OutDir)
      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "This format is currently unsupported, because the FreeImage library failed to properly initialize.`n`n" OutFileName, 0, 0, "error")
         Return
      }

      r := coreAutoCropFileProcessing(imgPath, file2save, 0)
      If r
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "ERROR. Unable to save file... error code: " r ".`n`n" OutFileName "`n`n" OutDir "\", 0, 0, "error")
         Return
      }

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
   filesElected := getSelectedFiles(0, 1)
   If (filesElected>80)
   {
      msgInfos := "Are you sure you want to crop " filesElected " files? The auto-crop algorithm may take some time to finish going through all of them. Hold ESC to abandon it."
      msgResult := msgBoxWrapper(appTitle ": Confirmation", msgInfos, 4, 0, "question")
      If (msgResult="Yes")
         good2go := 1
   } Else good2go := 1
 
   If (good2go!=1)
      Return

   If AnyWindowOpen
      CloseWindow()

   Sleep, 25
   showTOOLtip("Performing image auto-crop on " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   doStartLongOpDance()
   countFilez := countTFilez := 0
   If (!FileExist(ResizeDestFolder) && ResizeUseDestDir=1)
      FileCreateDir, % ResizeDestFolder

   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      executingCanceableOperation := A_TickCount
      If (determineTerminateOperation()=1)
      {
         abandonAll := 1
         Break
      }

      thisFileIndex := A_Index
      imgPath := getIDimage(thisFileIndex)
      imgPath := StrReplace(imgPath, "||")
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

   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
      showTOOLtip("Operation aborted. " countFilez " out of " filesElected " selected files were processed until now..." someErrors)
   Else
      showTOOLtip(countFilez " out of " countTFilez " selected images were automatically cropped" someErrors)
   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
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
     resultu := getIDimage(currentFileIndex)
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

       calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
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
       resizeFilter := (ResizeQualityHigh=1) ? 7 : 5
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

simpleFreeImgRotate(pBitmap, rotateAngle) {
    hFIFimgA := ConvertPBITMAPtoFIM(pBitmap, hGDIwin)
    If (rotateAngle>0 && hFIFimgA)
    {
       changeMcursor()
       hFIFimgB := FreeImage_Rotate(hFIFimgA, rotateAngle)
       If hFIFimgB
       {
          FreeImage_UnLoad(hFIFimgA)
          hFIFimgA := hFIFimgB
       }
    }

    newBitmap := SimpleConvertFimToPBitmap(hFIFimgA)
    FreeImage_UnLoad(hFIFimgA)
    Return newBitmap
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

       calcImgSelection2bmp(0, imgW, imgH, imgW, imgH, imgSelPx, imgSelPy, imgSelW, imgSelH, zImgSelPx, zImgSelPy, zImgSelW, zImgSelH, X1, Y1, X2, Y2)
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
       resizeFilter := (ResizeQualityHigh=1) ? 4 : 0
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
       If !ErrorLevel
          tempFileExists := 1
       Sleep, 0
    }

    changeMcursor()
    r := FreeImage_Save(hFIFimgA, file2save)
    FreeImage_UnLoad(hFIFimgA)

    If (!r && tempFileExists=1)
    {
       FileDelete, % file2save
       Sleep, 0
       FileMove, % file2save "-tmp", % file2save
    } Else If (tempFileExists=1)
       FileDelete, % file2save "-tmp"

    Return !r
}

PanelSimpleResizeRotate() {
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

    imgPath := getIDimage(currentFileIndex)
    filesElected := getSelectedFiles(0, 1)
    thisRegEX := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
    If (!filesElected && !RegExMatch(imgPath, thisRegEX) && !AnyWindowOpen)
    {
       CloseWindow()
       Sleep, 5
       PanelResizeImageWindow()
       Return
    }

    createSettingsGUI(18, "PanelSimpleResizeRotate")
    ReadSettingsImageProcessing()

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
    Gui, Add, DropDownList, x+5 w100 Choose%SimpleOperationsRotateAngle% vSimpleOperationsRotateAngle, 0°|90°|180°|-90° [270°]
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

    Gui, Add, Button, xs y+5 h30 w%btnWid% gPanelResizeImageWindow, &Advanced mode
    Gui, Add, Button, x+5 hp w80 gResizePanelHelpBoxInfo, &Help
    Gui, Add, Button, x+5 hp wp gCloseWindow, &Cancel
    winPos := (prevSetWinPosY && prevSetWinPosX && thumbsDisplaying!=1) ? " x" prevSetWinPosX " y" prevSetWinPosY : ""
    Gui, SettingsGUIA: Show, AutoSize %winPos%, Resize/crop/rotate image [simple]: %appTitle%
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

    cleanResizeUserOptionsVars()
    If (simpleOPimgScaleFactor=1 || simpleOPimgScaleFactor<0 || !simpleOPimgScaleFactor) && (simpleOpRotationAngle=0 && SimpleOperationsFlipV=0 && SimpleOperationsFlipH=0 && SimpleOperationsDoCrop=0)
    {
        SoundBeep, 300, 100
        msgBoxWrapper(appTitle ": WARNING", "No image transformations selected or activated to perform...", 0, 0, "exclamation")
        Return
    }

    initFIMGmodule()
    filesElected := getSelectedFiles(0, 1)
    If (filesElected>1)
    {
       batchSimpleProcessing(simpleOpRotationAngle, simpleOPimgScaleFactor)
       Return
    }

    imgPath := getIDimage(currentFileIndex)
    thisRegEX := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
    zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
    If (!filesElected && !RegExMatch(imgPath, thisRegEX))
    {
       SoundBeep, 300, 100
       msgBoxWrapper(appTitle ": ERROR", "This file format (." oExt ") cannot be processed in «Simple mode». Please use the «Advanced mode» which allows file format conversions.", 0, 0, "exclamation")
       Return
    }

   startPath := (ResizeUseDestDir=1) ? ResizeDestFolder "\" OutFileName : imgPath
   If (SimpleOperationsNoPromptOnSave=1)
      file2save := imgPath
   Else
      file2save := openFileDialogWrapper("S18", startPath, "Save processed image as...", "Images (*." oExt ")")

   If file2save
   {
      zPlitPath(imgPath, 0, OutFileName, OutDir, OutNameNoExt, oExt)
      zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, nExt)
      If !nExt
         file2save .= "." oExt

      If !RegExMatch(file2save, thisRegEX)
      {
         SoundBeep, 300, 100
         If (SimpleOperationsNoPromptOnSave!=1)
            msgBoxWrapper(appTitle ": ERROR", "Please save the file using one of the supported file format extensions: .EXR, .HDR, .PFM, " saveTypesFriendly ". ", 0, 0, "error")
         Else
            msgBoxWrapper(appTitle ": ERROR", "Unsupported file write format. Please use one of the allowed image file formats: .EXR, .HDR, .PFM, " saveTypesFriendly ". ", 0, 0, "error")
         Return
      }

      If (nExt!=oExt && StrLen(nExt)>0)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "You cannot change the image file format from ." oExt " to ." nExt ". If you want to do this, please use the «Advanced mode».", 0, 0, "exclamation")
         Return
      }

      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "This format is currently unsupported, because the FreeImage library failed to properly initialize.`n`n" OutFileName, 0, 0, "error")
         Return
      }

      destroyGDIfileCache()
      GuiControl, SettingsGUIA: Disable, mainBtnACT
      SetTimer, reactivateMainBtnACT, -950
      r := coreSimpleFileProcessing(imgPath, file2save, simpleOpRotationAngle, simpleOPimgScaleFactor)
      If r
      {
         SoundBeep, 300, 100
         msgBoxWrapper(appTitle ": ERROR", "ERROR. Unable to save file... error code: " r ".`n`n" OutFileName "`n`n" OutDir "\", 0, 0, "error")
         Return
      }

      SetTimer, WriteSettingsResizeSimplePanel, -90
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

   filesElected := getSelectedFiles(0, 1)
   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   setImageLoading()
   showTOOLtip("Processing " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   thisRegEX := StrReplace(saveTypesRegEX, "|xpm))$", "|hdr|exr|pfm|xpm))$")
   countTFilez := filesConverted := 0
   destroyGDIfileCache()
   doStartLongOpDance()
   Loop, % maxFilesIndex
   {
      isSelected := resultedFilesList[A_Index, 2]
      If (isSelected!=1)
         Continue

      thisFileIndex := A_Index
      imgPath := getIDimage(thisFileIndex)
      If !RegExMatch(imgPath, thisRegEX)
         Continue

      countTFilez++
      executingCanceableOperation := A_TickCount
      If (A_TickCount - prevMSGdisplay>3000)
      {
         showTOOLtip("Processing " countTFilez "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If (determineTerminateOperation()=1)
      {
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
   ForceRefreshNowThumbsList()
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
      showTOOLtip("Operation aborted. "  filesConverted " out of " filesElected " selected files were processed." someErrors)
   Else
      showTOOLtip("Finished processing " filesConverted " out of " filesElected " selected files" someErrors)

   SetTimer, ResetImgLoadStatus, -50
   SoundBeep, % (abandonAll=1) ? 300 : 900, 100
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

printLargeStrArray(whichArray, maxList, delim) {
  startZeit := A_TickCount
  trenchSize := 25000
  changeMcursor()
  If (maxList<trenchSize)
  {
     Loop, % maxList
     {
          rA := whichArray[A_Index]
          r := rA[1]
          If (InStr(r, "||") || !r)
             Continue

          filesListu .= r delim
     }
     Return filesListu
  }

  doStartLongOpDance()
  splitParts := maxList//trenchSize
  Loop, % splitParts - 1
  {
      If (A_TickCount - startZeit>2500)
         executingCanceableOperation := A_TickCount

      changeMcursor()
      thisIndex := A_Index
      Loop, % trenchSize
      {
          rA := whichArray[trenchSize*(thisIndex-1) + A_Index]
          r := rA[1]
          If (InStr(r, "||") || !r)
             Continue

          filesListu%thisIndex% .= r delim
      }

      If (determineTerminateOperation()=1) ; && (A_TickCount - startZeit>2500)
      {
         abandonAll := 1
         Break
      }
  }

  If (abandonAll=1)
  {
     SoundBeep, 300, 100
     lastLongOperationAbort := A_TickCount
     Return
  }

  Loop, % maxList - trenchSize*(splitParts - 1)
  {
      rA := whichArray[trenchSize*(splitParts - 1) + A_Index]
      r := rA[1]
      If (InStr(r, "||") || !r)
         Continue

      filesListu%splitParts% .= r delim
  }

  filesListu%splitParts% := Trim(filesListu%splitParts%)
  Loop, % splitParts
      result .= filesListu%A_Index%

  ; MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000) 
  Return result
}

GetRes(ByRef bin, lib, res, type) {
  If !A_IsCompiled
     Return 0

  hL := 0
  If lib
     hM := DllCall("kernel32\GetModuleHandleW", "Str", lib, "Ptr")

  If !lib
  {
     hM := 0  ; current module
  } Else If !hM
  {
     If (!hL := hM := DllCall("kernel32\LoadLibraryW", "Str", lib, "Ptr"))
        Return
  }

  dt := (type+0 != "") ? "UInt" : "Str"
  hR := DllCall("kernel32\FindResourceW"
      , "Ptr" , hM
      , "Str" , res
      , dt , type
      , "Ptr")

  If !hR
  {
     OutputDebug, % appTitle ": " FormatMessage(A_ThisFunc "(" lib ", " res ", " type ", " l ")", A_LastError)
     Return
  }

  hD := DllCall("kernel32\LoadResource"
      , "Ptr" , hM
      , "Ptr" , hR
      , "Ptr")
  hB := DllCall("kernel32\LockResource"
      , "Ptr" , hD
      , "Ptr")
  sz := DllCall("kernel32\SizeofResource"
      , "Ptr" , hM
      , "Ptr" , hR
      , "UInt")
  If !sz
  {
     OutputDebug, %appTitle%: Error: resource size 0 in %A_ThisFunc%(%lib%, %res%, %type%)
     DllCall("kernel32\FreeResource", "Ptr" , hD)
     If hL
        DllCall("kernel32\FreeLibrary", "Ptr", hL)
     Return
  }

  VarSetCapacity(bin, 0), VarSetCapacity(bin, sz, 0)
  DllCall("ntdll\RtlMoveMemory", "Ptr", &bin, "Ptr", hB, "UInt", sz)
  DllCall("kernel32\FreeResource", "Ptr" , hD)

  If hL
     DllCall("kernel32\FreeLibrary", "Ptr", hL)

  Return sz
}

FormatMessage(ctx, msg, arg="") {
  Global
  Local txt, buf
  SetFormat, Integer, H
  msg+=0
  SetFormat, Integer, D
  frmMsg := DllCall("kernel32\FormatMessageW"
          , "UInt" , 0x1100 ; FORMAT_MESSAGE_FROM_SYSTEM/ALLOCATE_BUFFER
          , "Ptr"  , 0      ; lpSource
          , "UInt" , msg    ; dwMessageId
          , "UInt" , 0      ; dwLanguageId (0x0418=RO)
          , "PtrP" , buf    ; lpBuffer
          , "UInt" , 0      ; nSize
          , "Str"  , arg)   ; Arguments

  txt := StrGet(buf, "UTF-16")
  lF := DllCall("kernel32\LocalFree", "Ptr", buf)
  Result := "Error " msg " in " ctx ":`n" txt
  Return Result
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

SaveFIMfile(file2save, pBitmap) {
  initFIMGmodule()
  If !wasInitFIMlib
     Return 1

  hFIFimgA := ConvertPBITMAPtoFIM(pBitmap, hGDIwin)
  If !hFIFimgA
  {
     SoundBeep 
     Return 1
  }

  If FileExist(file2save)
  {
     Try FileSetAttrib, -R, % file2save
     Sleep, 0
     FileMove, % file2save, % file2save "-tmp"
     If !ErrorLevel
        tempFileExists := 1

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
  If (!r && tempFileExists=1)
  {
     FileDelete, % file2save
     Sleep, 0
     FileMove, % file2save "-tmp", % file2save
  } Else If (tempFileExists=1)
     FileDelete, % file2save "-tmp"

  Return !r
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
     If (firstTimer=1 && hasInitSpecialMode!=1)
     {
        SoundBeep, 300, 900
        msgBoxWrapper(appTitle ": ERROR", "The FreeImage library failed to properly initialize. Some image file formats will no longer be supported. Error code: " r "." friendly, 0, 0, "error")
     }
  } Else FIMfailed2init := 0

  firstTimer := 0
  Return r
}

LoadFimFile(imgPath, noBPPconv) {
  Critical, on
  sTime := A_tickcount  
  initFIMGmodule()
  If !wasInitFIMlib
     Return

  noPixels := (noBPPconv=1) ? -1 : 0
  GFT := FreeImage_GetFileType(ImgPath)
  If (GFT=34 && noPixels=0)
     noPixels := (userHQraw=1 && thumbsDisplaying=0) ? 0 : 5

  setWindowTitle("Loading file using FreeImage library")
  changeMcursor()
  hFIFimgA := FreeImage_Load(imgPath, -1, noPixels) ; load image
  If !hFIFimgA
     Return

  If (noBPPconv=0 && RenderOpaqueIMG!=1)
     alphaBitmap := FreeImage_GetChannel(hFIFimgA, 4)

  imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
  If (imgBPP>32 && noBPPconv=0)
  {
     setWindowTitle("Applying adaptive logarithmic tone mapping to display high color depth image")
     changeMcursor()
     hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)
  }

  If (noBPPconv=0) || (thumbsDisplaying=1 && thumbsListViewMode=3)
  {
     ColorsType := FreeImage_GetColorType(hFIFimgA)
     FIMimgBPP := imgBPP " bit [ " ColorsType " ] "
     FIMformat := GFT
  }

  ; If (bwDithering=1 && imgFxMode=4 && doBw=1)
  ;    hFIFimgZ := hFIFimgB ? FreeImage_Dither(hFIFimgB, 0) : FreeImage_Dither(hFIFimgA, 0)
  ; Else
     hFIFimgZ := hFIFimgB ? hFIFimgB : hFIFimgA

  hFIFimgC := hFIFimgZ ? hFIFimgZ : hFIFimgA
  FreeImage_GetImageDimensions(hFIFimgC, imgW, imgH)

  If (noBPPconv=0)
  {
     changeMcursor()
     setWindowTitle("Converting FreeImage object to GDI+ image object")
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
           Gdip_DisposeImage(testBMP, 1)
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
     ; bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgE)
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
     Gdip_DisposeImage(nBitmap, 1)
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

changeMcursor(whichCursor:=0) {
  Static lastInvoked := 1
  If (slideShowRunning=1 || animGIFplaying=1 || hasInitSpecialMode=1)
     Return

  If whichCursor
  {
     interfaceThread.ahkPostFunction("changeMcursor", whichCursor)
  } Else If (A_TickCount - lastInvoked > 500)
  {
     interfaceThread.ahkPostFunction("changeMcursor", "busy")
     interfaceThread.ahkassign("imageLoading", 1)
     Try DllCall("user32\SetCursor", "Ptr", hCursBusy)
     lastInvoked := A_TickCount
  }
}

GetImgFileDimension(imgPath, ByRef W, ByRef H, fastWay:=1) {
   Static prevImgPath, prevW, prevH
   thisImgPath := generateThumbName(imgPath, 1) fastWay
   If (prevImgPath=thisImgPath && prevH>1 && prevW>1)
   {
      W := prevW
      H := prevH
      Return 1
   }

   prevImgPath := thisImgPath
   changeMcursor()
   pBitmap := LoadBitmapFromFileu(imgPath, fastWay, 1)
   prevW := W := Gdip_GetImageWidth(pBitmap)
   prevH := H := Gdip_GetImageHeight(pBitmap)
   Gdip_DisposeImage(pBitmap, 1)

   changeMcursor("normal")
   r := (w>1 && h>1) ? 1 : 0
   Return r
}

min(val1, val2, val3:="null") {
  a := (val1<val2) ? val1 : val2
  If (val3!="null")
     a := (a<val3) ? a : val3
  Return a
}

max(val1, val2, val3:="null") {
  a := (val1>val2) ? val1 : val2
  If (val3!="null")
     a := (a>val3) ? a : val3
  Return a
}

valueBetween(value, inputA, inputB) {
    If (value=inputA || value=inputB)
       Return 1

    testRange := 0
    pointA := min(inputA, inputB)
    pointB := max(inputA, inputB)
    if value between %pointA% and %pointB%
       testRange := 1
    Return testRange
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

triggerOwnDialogs() {
  If AnyWindowOpen
     Gui, SettingsGUIA: +OwnDialogs
  Else
     Gui, 1: +OwnDialogs
}

checkThumbExists(MD5name, imgPath, ByRef file2load) {
   file2save := thumbsCacheFolder "\" thumbsSizeQuality "-" MD5name ".jpg"
   If FileExist(file2save)
   {
      FileGetSize, fileSizu, % file2save
      If (fileSizu<3)
         Return 0

      file2load := file2save
      Return 1
   } Else If (thumbsSizeQuality>755)
   {
      file2load := imgPath
      Return 0
   } Else If (thumbsSizeQuality>=500)
   {
      file2test := thumbsCacheFolder "\755-" MD5name ".jpg"
      file2load := FileExist(file2test) ? file2test : imgPath
   } Else If (thumbsSizeQuality>=245)
   {
      file2test := thumbsCacheFolder "\500-" MD5name ".jpg"
      file2load := FileExist(file2test) ? file2test : 0
      If !file2load
      {
         file2test := thumbsCacheFolder "\755-" MD5name ".jpg"
         file2load := FileExist(file2test) ? file2test : imgPath
      }
   } Else If (thumbsSizeQuality>124)
   {
      file2test := thumbsCacheFolder "\245-" MD5name ".jpg"
      file2load := FileExist(file2test) ? file2test : 0
      If !file2load
      {
         file2test := thumbsCacheFolder "\500-" MD5name ".jpg"
         file2load := FileExist(file2test) ? file2test : 0
         If !file2load
         {
            file2test := thumbsCacheFolder "\755-" MD5name ".jpg"
            file2load := FileExist(file2test) ? file2test : imgPath
         }
      }
   }
   FileGetSize, fileSizu, % file2load
   r := (imgPath=file2load || fileSizu<3) ? 0 : 1
   Return r
}

generateThumbName(imgPath, forceThis:=0, thumbsSizer:=0) {
   If (enableThumbsCaching!=1 && forceThis=0)
      Return

   FileGetSize, fileSizu, % imgPath
   FileGetTime, FileDateM, % imgPath, M
   fileInfos := imgPath fileSizu FileDateM
   MD5name := CalcStringHash(fileInfos, 0x8003)
   ; If (thumbsSizer=1)
   ;    MD5name := thumbsSizeQuality "-" MD5name

   Return MD5name
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









HammingDistance(stringA, stringB) {
    If (StrLen(stringA) != StrLen(stringB))
       Return -1

    countDiffs := 0
    Loop, % StrLen(stringA)
    {
       If (SubStr(stringA, A_Index, 1)!=SubStr(stringB, A_Index, 1))
          countDiffs++
    }
    Return countDiffs
}

HammingDistanceBugz(a,b) {
; by Bugz000
    loop % 17
      s.=(c:="0." substr(a,(A_index)*16-15,16))+(d:="0." substr(b,(A_index)*16-15,16))
    z:=strsplit(s,"1")
    return % z.count()-1
}


HammingDistance3(a,b) {
; by Bugz000
    Loop, Parse, a
    {
       If (A_loopfield!=SubStr(b, A_Index, 1))
          i += 1
    }
    return % i
}

HammingDistanceRust(a, b) {
     r := DllCall("hamming_distance.dll\harming_distance_bytes", "astr", a, "astr", b)
     Return r
}

testAlgoSingle() {
   imgPath := getIDimage(currentFileIndex)
     hashA := Gdip_ImageDhash(imgPath)
 imgPath := getIDimage(currentFileIndex + 1)
     hashB := Gdip_ImageDhash(imgPath)
r1 := HammingDistanceRust(hashA, hashB)
r2 := HammingDistance(hashA, hashB)

MsgBox, % r1 "--" r2 "`n" hashA "`n" hashB

}


Gdip_ImageDhash(imgPath) {
   Width := 9*2, Height := 8*2
   oBitmap := LoadBitmapFromFileu(imgPath)
   If oBitmap
   {
      xBitmap := Gdip_ResizeBitmap(oBitmap, Width, Height, 0, 3)
      lBitmap := Gdip_BitmapConvertGray(xBitmap, 0, -20)
      Gdip_DisposeImage(oBitmap, 1)
   }

   E1 := Gdip_LockBits(lBitmap, 0, 0, Width, Height, Stride, Scan0, BitmapData)
   dHash := z := 0
   Loop %Height%
   {
      y++
      Loop % Width - 1
      {
         pX := A_Index - 1, pY := y - 1
         Gdip_FromARGB(NumGet(Scan0+0, (pX*4)+(pY*Stride), "UInt"), A1, R1, G1, B1)
         Gdip_FromARGB(NumGet(Scan0+0, ((pX+1)*4)+(pY*Stride), "UInt"), A2, R2, G2, B2)
         dHash .= (R1<R2) ? 1 : 0
      }
   }

   Gdip_UnlockBits(lBitmap, BitmapData)
   Gdip_DisposeImage(lBitmap, 1)
   Gdip_DisposeImage(xBitmap, 1)
   return dHash
}

testAlgo() {
  SoundBeep 
  thisCounter := 0
  startZeit := A_TickCount
  hashesListArray := []
  ; create hashes for images in the resultedFilesList Array
  Loop, % maxFilesIndex
  {
      imgPath := getIDimage(A_Index)
      If !FileRexists(imgPath)
         Continue

      thisCounter++
      newHash := (cachedHashes[imgPath]!="") ? cachedHashes[imgPath] : Gdip_ImageDhash(imgPath)
      cachedHashes[imgPath] := newHash
      ; hashesList .= newHash "`n"
      hashesListArray[thisCounter] := newHash
      hashesListIDsArray[newHash] := imgPath
  }

  thresholdu := 1   
  countAll := countThese := newFilesIndex := 0
  hashesList := Trim(hashesList)
  newFilesList := []
  distCombinationsA := []
  distCombinationsB := []
  distCombinations := []
;  hashesListArray := []
 ; hashesListArray := StrSplit(hashesList, "`n")
;  MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000) "`n" hashesListArray.count()
 ; SoundBeep 

  DllPath := FreeImage_FoxGetDllPath("hamming_distance.dll")
  lalala := DllCall("LoadLibraryW", "WStr", DllPath, "UPtr")

  Loop, % hashesListArray.Count()
  {
      thisHash := hashesListArray[A_Index]
      If !thisHash
         Continue
      countAll++
      thisIndex := A_Index
      Loop, % thisIndex - 1
      {
          countThese++
    ;      distCombinations[A_Index] := hashesListArray[A_Index]
          hDistances := HammingDistanceRust(thisHash, hashesListArray[A_Index])
      }
  }

/*

  Loop, % hashesListArray.MaxIndex()
  {
    originalIndex := A_Index
    startPoint := StrSplit(hashesListArray[originalIndex], "|:|")
    startPointV := startPoint[1]


  Loop, % hashesListArray.MaxIndex() ; - originalIndex
  {
      thisThing := hashesListArray[originalIndex + A_Index - thresholdu]
      If !thisThing
         Continue

      thisIndex := StrSplit(thisThing, "|:|")
      If valueBetween(thisIndex[1], startPointV - thresholdu, startPointV + thresholdu)
      {
         newFilesIndex++
         newFilesList[newFilesIndex] := thisIndex[2]
 ;        tooltip, % newFilesIndex "--" thisIndex[1] "--" thisIndex[2]
      }
  }
}

   newFilesList := trimArray(newFilesList)
   filteredMap2mainList := []
   resultedFilesList := newFilesList.Clone()
   maxFilesIndex := newFilesIndex
   newFilesList := []
   newMappingList := []
   GenerateRandyList()
   ForceRefreshNowThumbsList()
*/

SoundBeep 
  MsgBox, % SecToHHMMSS((A_TickCount - startZeit)/1000) "`n" countThese "--" countAll "`n" hashesListArray.count()


  dummyTimerReloadThisPicture(50)
  
 ; Clipboard := hashesList
}

OpenNewExternalCoreThread(thisIndex, args, thisList) {
   pidThread := 0
   Try FileDelete, %thumbsCacheFolder%\tempList%thisIndex%.txt
   Try FileDelete, %thumbsCacheFolder%\tempFilesList.txt
   Sleep, 0
   Try FileAppend, % thisList, %thumbsCacheFolder%\tempFilesList.txt, utf-16
   Catch wasErrorA
         Sleep, 1

   If wasErrorA
      Return 0

   Sleep, 0
   RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadJob%thisIndex%, 0
   RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%thisIndex%, 0
   RegWrite, REG_SZ, %QPVregEntry%\multicore, threadParams, %thisIndex%||%args%
   thisPath := A_IsCompiled ? fullPath2exe : A_ScriptFullPath
   Try Run, "%thisPath%",,, pidThread
   Catch wasErrorB
       Sleep, 0

   If (wasErrorB || !pidThread)
   {
      Try FileDelete, %thumbsCacheFolder%\tempFilesList.txt
      Return 0
   } Else
   {
      WinWait, ahk_pid %pidThread%,,2
      WinGet, hwndThread, ID, ahk_pid %pidThread%
      Sleep, 10
      Loop, 500
      {
          RegRead, thisThreadStarted, %QPVregEntry%\multicore, ThreadRunning%thisIndex%
          If (thisThreadStarted=1 || thisThreadStarted=2 || thisThreadStarted=-1)
             Break
          Else
             Sleep, 10
      }

      allGood := (thisThreadStarted=1 || thisThreadStarted=2) ? 1 : 0
      If (allGood!=1)
      {
         Process, Close, % pidThread
         RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%thisIndex%, 0
         Try FileDelete, %thumbsCacheFolder%\tempFilesList.txt
         Return 0
      }
      Return pidThread
   }
}

initExternalCoreMode() {
  Critical, on
  hasInitSpecialMode := 1
  RegRead, mainThreadHwnd, %QPVregEntry%\multicore, mainThreadHwnd
  If !WinExist("ahk_id" mainThreadHwnd)
  {
     RegWrite, REG_SZ, %QPVregEntry%, Running, 0
     fatalError := 1
  }

  RegRead, threadParams, %QPVregEntry%\multicore, threadParams
  If !threadParams
     fatalError := 1

  args := StrSplit(threadParams, "||")
  coreThread := args[1]

  Try FileRead, filesList, %thumbsCacheFolder%\tempFilesList.txt
  If !filesList
     fatalError := 1

  If (fatalError=1)
  {
     RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%coreThread%, -1
     ForceExitNow()
     Return
  }

  RegWrite, REG_SZ, %QPVregEntry%\multicore, ThreadRunning%coreThread%, 1
  initFIMGmodule()
  If (args[2]="batch-sort-histo")
  {
     ; MsgBox, % args[1] "--" args[3]
     multiCoresListSorter(args[1], args[3], filesList)
  } Else If (args[2]="batch-jpegll")
  {
     multiCoresJpegLL(args[1], args[3], filesList)
  } Else If (args[2]="batch-fmtconv")
  {
     RegRead, hGDIwin, %QPVregEntry%\multicore, mainWindowID
     multiCoresFormatConvert(args[1], filesList)
  }
  ; msgbox, killaaaa
  ForceExitNow()
  Return
}



testResourcesMemoryLeaks() {
  Loop, 4500
  {
       pEffect3 := Gdip_CreateEffect(1, 20, 0, 0)
       Gdip_DisposeEffect(pEffect3)

       lolBrush := Gdip_BrushCreateSolid("0x77898898")
       Gdip_DeleteBrush(lolBrush)

       lolPen1 := Gdip_CreatePen("0xCCbbccbb", 5)
       Gdip_DeletePen(lolPen1)


       lolPath := Gdip_CreatePath()
       Gdip_AddPathEllipse(lolPath, 30, 30, 200, 200)
       Gdip_DeletePath(lolPath)



lola := drawTextInBox("loWooWol", "Arial", 99, 1500, 1500, "ff0099", "EEff0099", 0)


       pBitmap := Gdip_CreateBitmap(900, 900)
       G3 := Gdip_GraphicsFromImage(pBitmap, 7, 4)
    txtOptions := "x30 y30 center cEEff0099 r4 s10 Bold" 
    dimensions := Gdip_TextToGraphics(G3, "loooool", txtOptions, "Arial", 400, 400, 0, 0, 2)


       Gdip_DeleteGraphics(G3)
       Gdip_DisposeImage(pBitmap)
       Gdip_DisposeImage(lola)
  }
  MsgBox, lololol
}


GetInstalledPrinters(Delimiter="|",Default=True) {
;  Run, rundll32    shimgvw.dll    ImageView_PrintTo /pt   xxx.png   "printer name"
;  Run, mspaint /pt [image filename]


  if (Default = True)
  {
    regread,defaultPrinter,HKCU,Software\Microsoft\Windows NT\CurrentVersion\Windows,device
    stringsplit,defaultName,defaultPrinter,`,
    defaultName := defaultName1
    printerlist =
    loop,HKCU,Software\Microsoft\Windows NT\CurrentVersion\devices
    {
      if (A_LoopRegName = defaultname)
      printerlist = %printerlist%%A_loopRegName%%Delimiter%%Delimiter%
      else printerlist = %printerlist%%A_loopRegName%%Delimiter%
    }
  }
  else
  {
    printerlist =
    loop,HKCU,Software\Microsoft\Windows NT\CurrentVersion\devices
    {
      printerlist = %printerlist%%A_loopRegName%%Delimiter%
    }
  }
  StringTrimRight, printerlist, printerlist, StrLen(Delimiter)
  return %printerlist%
}
