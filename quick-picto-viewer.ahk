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
;   Author:   Marius Șucan -  http://marius.sucan.ro/
;   GitHub:   https://github.com/marius-sucan/Quick-Picto-Viewer
;
; Script Main Functionalities:
; Display images and creates slideshows;
; using GDI+ supported formats: jpeg, jpg, bmp, png, gif, tif, emf
;
; Original Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
;_________________________________________________________________________________________________________________Auto Execute Section____

;@Ahk2Exe-SetName Quick Picto Viewer
;@Ahk2Exe-SetDescription Quick Picto Viewer
;@Ahk2Exe-SetVersion 3.6.0
;@Ahk2Exe-SetCopyright Marius Şucan (2019)
;@Ahk2Exe-SetCompanyName marius.sucan.ro
 
#NoEnv
#NoTrayIcon
#MaxHotkeysPerInterval, 500
#MaxThreads, 255
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#MaxMem, 1924
#IfTimeout, 25
#SingleInstance, off
#Include, Gdip.ahk
#Include, freeimage.ahk
SetWinDelay, 1

Global PVhwnd := 1, hGDIwin := 1, hGDIthumbsWin := 1, hGIFsGuiDummy := 1
   , hGuiTip := 1, hGuiThumbsHL := 1, hSetWinGui := 1
   , prevFullThumbsUpdate := 1, winGDIcreated := 0, ThumbsWinGDIcreated := 0
   , hPicOnGui1, scriptStartTime := A_TickCount, lastEditRHChange :=1
   , newStaticFoldersListCache := "", lastEditRWChange := 1
   , prevTooltipDisplayTime := 1, mainCompiledPath := "", wasInitFIMlib := 0
   , filteredMap2mainList := [], thumbsCacheFolder := A_ScriptDir "\thumbs-cache"
   , resultedFilesList := [], currentFileIndex, maxFilesIndex := 0
   , appTitle := "Quick Picto Viewer", FirstRun := 1
   , bckpResultedFilesList := [], bkcpMaxFilesIndex := 0
   , DynamicFoldersList := "", historyList, GIFsGuiCreated := 0
   , RandyIMGids := [], SLDhasFiles := 0, IMGlargerViewPort := 0
   , IMGdecalageY := 1, IMGdecalageX := 1, imgQuality, usrFilesFilteru := ""
   , RandyIMGnow := 0, GDIPToken, Agifu, gdiBitmapSmall
   , AprevGdiBitmap, BprevGdiBitmap, msgDisplayTime := 3000
   , slideShowRunning := 0, CurrentSLD := "", markedSelectFile := ""
   , ResolutionWidth, ResolutionHeight, prevStartIndex := -1
   , gdiBitmap, mainSettingsFile := "quick-picto-viewer.ini"
   , RegExFilesPattern := "i)(.\\*\.(dib|tif|tiff|emf|wmf|rle|png|bmp|gif|jpg|jpeg|jpe|DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|dng|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f))$"
   , RegExFIMformPtrn := "i)(.\\*\.(DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|dng|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f))$"
   , saveTypesRegEX := "i)(.\.(bmp|j2k|j2c|jp2|jxr|wdp|hdp|png|tga|tif|tiff|webp|gif|jng|jif|jfif|jpg|jpe|jpeg|ppm|xpm))$"
   , openFptrn1 := "*.png;*.bmp;*.gif;*.jpg;*.tif;*.tga;*.webp;*.jpeg"
   , openFptrn2 := "*.dds;*.emf;*.exr;*.g3;*.hdp;*.iff;*.j2c;*.j2k;*.jbg;*.jif;*.jng;*.jp2;*.jxr;*.koa;*.lbm;*.mng;*.pbm;*.pcd;*.pct;*.pcx;*.pfm;*.pgm;*.pic;*.ppm;*.psd;*.ras;*.sgi;*.wap;*.wbm;*.wbmp;*.wdp;*.wmf;*.xbm;*.xpm"
   , openFptrn3 := "*.3fr;*.arw;*.bay;*.bmq;*.cap;*.cine;*.cr2;*.crw;*.cs1;*.dc2;*.dcr;*.dng;*.drf;*.dsc;*.erf;*.fff;*.hdr;*.ia;*.iiq;*.k25;*.kc2;*.kdc;*.mdc;*.mef;*.mos;*.mrw;*.nef;*.nrw;*.orf;*.pef;*.ptx;*.pxn;*.qtk;*.raf;*.raw;*.rdc;*.rw2;*.rwz;*.sr2;*.srf;*.x3f"
   , openFptrn4 := "*.tiff;*.targa;*.jpe;*.dib;*.pict;*.rle"
   , LargeUIfontValue := 14, AnyWindowOpen := 0, toolTipGuiCreated := 0
   , PrefsLargeFonts := 0, OSDbgrColor := "131209", OSDtextColor := "FFFEFA"
   , OSDfntSize := 10, OSDFontName := "Arial", prevOpenFolderPath := ""
   , mustGenerateStaticFolders := 1, lastWinDrag := 1, img2resizePath := ""
   , prevFileMovePath := "", lastGIFdestroy := 1, prevAnimGIFwas := ""
   , thumbsW := 300, thumbsH := 300, thumbsDisplaying := 0
   , othumbsW := 300, othumbsH := 300, ForceRegenStaticFolders := 0
   , CountFilesFolderzList := 0, RecursiveStaticRescan := 0
   , UsrMustInvertFilter := 0, overwriteConflictingFile := 0
   , prevFileSavePath := "", imgHUDbaseUnit := 65, lastLongOperationAbort := 1
   , lastOtherWinClose := 1, UsrCopyMoveOperation := 2, editingSelectionNow := 0
   , ForceNoColorMatrix := 0, activateImgSelection := 0, prevFastDisplay := 1
   , imgSelX1 := 0, imgSelY1 := 0, imgSelX2 := -1, imgSelY2 := -1
   , selDotX, selDotY, selDotAx, selDotAy, selDotBx, selDotBy, selDotCx, selDotCy
   , dotsSize := imgHUDbaseUnit//4, ViewPortBMPcache, startZeitIMGload, LbtnDwn := 0
   , imageLoading := 0, PrevGuiSizeEvent := 0, imgSelOutViewPort := 0, prevGUIresize := 1
   , mPosCtrl, isThisHDRimg := 0, hCursBusy := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
   , hCursN := DllCall("user32\LoadCursorW", "Ptr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
   , remCacheOldDays := 0, jpegDoCrop := 0, jpegDesiredOperation := 1
   , rDesireWriteFMT := "", FIMfailed2init := 0
   , version := "3.6.0", vReleaseDate := "11/08/2019"

 ; User settings
   , askDeleteFiles := 1, enableThumbsCaching := 1
   , thumbsAratio := 3, thumbsZoomLevel := 1
   , WindowBgrColor := "010101", slideShowDelay := 3000
   , IMGresizingMode := 1, SlideHowMode := 1, TouchScreenMode := 1
   , lumosAdjust := 1, GammosAdjust := 0, userimgQuality := 0
   , imgFxMode := 1, FlipImgH := 0, FlipImgV := 0, satAdjust := 1
   , imageAligned := 5, filesFilter := "", isAlwaysOnTop := 0
   , noTooltipMSGs := 0, zoomLevel := 1, skipDeadFiles := 0, userHQraw  := 0
   , isTitleBarHidden := 0, lumosGrayAdjust := 0, GammosGrayAdjust := 0
   , MustLoadSLDprefs := 0, animGIFsSupport := 1, move2recycler := 1
   , SLDcacheFilesList := 1, autoRemDeadEntry := 1, ResizeWithCrop := 1
   , easySlideStoppage := 0, ResizeInPercentage := 0, usrAdaptiveThreshold := 1
   , ResizeKeepAratio := 1, ResizeQualityHigh := 1, ResizeRotationUser := 1
   , ResizeApplyEffects := 1, autoAdjustMode := 1, doSatAdjusts := 1
   , ResizeDestFolder, ResizeUseDestDir := 0, chnRdecalage := 0, chnGdecalage := 0
   , chnBdecalage := 0, alwaysOpenwithFIM := 0, bwDithering := 0
   , userUnsprtWriteFMT := 1, userDesireWriteFMT := 10

imgQuality := (userimgQuality=1) ? 7 : 5
DetectHiddenWindows, On
CoordMode, Mouse, Screen
OnExit, Cleanup

If (A_IsCompiled)
   initCompiled()

OnMessage(0x205, "WM_RBUTTONUP")
OnMessage(0x201, "WM_LBUTTONDOWN")
OnMessage(0x203, "WM_LBUTTONDOWN") ; WM_LBUTTONDOWN double click
OnMessage(0x202, "ResetLbtn") ; WM_LBUTTONUP
OnMessage(0x2a3, "ResetLbtn") ; WM_MOUSELEAVE
If (A_OSVersion="WIN_7")
   OnMessage(0x216, "WM_MOVING")
; OnMessage(0x388, "WM_PENEVENT")
OnMessage(0x200, "WM_MOUSEMOVE")
OnMessage(0x06, "activateMainWin")
OnMessage(0x08, "activateMainWin")
Loop, 9
   OnMessage(255+A_Index, "PreventKeyPressBeep")   ; 0x100 to 0x108

if !(GDIPToken := Gdip_Startup())
{
   Msgbox, 48, %appTitle%, Error: unable to initialize GDI+...`n`nProgram will now exit.
   ExitApp
}

IniRead, FirstRun, % mainSettingsFile, General, FirstRun, @
If (FirstRun!=0)
{
   writeMainSettings()
   FirstRun := 0
   IniWrite, % FirstRun, % mainSettingsFile, General, FirstRun
} Else loadMainSettings()

BuildTray()
BuildGUI()
If RegExMatch(A_Args[1], "i)(.\.sld)$")
   OpenSLD(A_Args[1])

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
    ~^vk4F::    ; Ctrl+O
       If AnyWindowOpen
       {
          WinActivate, ahk_id %hSetWinGui%
          Return
       }
       If (imageLoading!=1)
          OpenFiles()
    Return

    ~!vk4F::    ; Alt+O
       If AnyWindowOpen
       {
          WinActivate, ahk_id %hSetWinGui%
          Return
       }
       If (imageLoading!=1)
          OpenRawFiles()
    Return

    ~+vk4F::    ; Shift+O
       If AnyWindowOpen
       {
          WinActivate, ahk_id %hSetWinGui%
          Return
       }
       If (imageLoading!=1)
          OpenFolders()
    Return

    !Space::
       Win_ShowSysMenu(PVhwnd)
    Return

    ~F10::
    ~AppsKey::
       InitGuiContextMenu()
    Return

    ~Insert Up::
       If (imageLoading!=1)
          addNewFile2list()
    Return

    ~^vk56 Up::   ; Ctrl+V
       If (imageLoading!=1)
          PasteClipboardIMG()
    Return

    ~+Esc::
       restartAppu()
    Return

    ~!F4::
    ~Esc::
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
      editImgSelection()
    Return

    ~vk49 Up::   ; I
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

    vkDC Up::   ; \
      ResetImageView()
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
       ToggleImgFX()
    Return

    +vk46 Up::     ; Shift+F
       ToggleImgFX(2)
    Return

    vk41 Up::     ; A
       ToggleIMGalign()
    Return

    Up::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("U")
    Return

    Down::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("D")
    Return

    WheelUp::
    Right::
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(1)
          Return
       } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("R")
    Return

    WheelDown::
    Left::
       If (InStr(A_ThisHotkey, "wheel") && IMGresizingMode=4 && thumbsDisplaying!=1)
       {
          ChangeZoom(-1)
          Return
       } Else If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("L")
    Return
#If

#If (identifyThisWin()=1 && !AnyWindowOpen && CurrentSLD && maxFilesIndex>0)
    Space Up::
       If (thumbsDisplaying=1 || markedSelectFile)
          markThisFileNow()
       Else If (A_TickCount - lastOtherWinClose>300)
          InfoToggleSlideShowu()
    Return 

    Space::
       If (A_TickCount - lastOtherWinClose>300) && (slideShowRunning=1)
          InfoToggleSlideShowu()
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
       convert2jpeg()
    Return

    ~vk4B Up::    ; K
       imgpath := resultedFilesList[currentFileIndex]
       If RegExMatch(imgpath, "i)(.\.(jpg|jpeg))$") || markedSelectFile
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

    +vkDB::   ; Shift + [
      ChangeGammos(-1)
    Return

    +vkDD::   ; Shift + ]
      ChangeGammos(1)
    Return

    vkDC Up::   ; \
      ResetImageView()
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
      editImgSelection()
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
       GoNextSlide()
    Return

    ~^Space Up::
       If (slideShowRunning=1)
          ToggleSlideShowu()
       If StrLen(filesFilter)>1
       {
          usrFilesFilteru := ""
          coreEnableFiltru(usrFilesFilteru)
          Return
       }
       r := resultedFilesList[currentFileIndex]
       zPlitPath(r, 0, OutFileName, OutDir)
       coreEnableFiltru(SubStr(OutDir, 3) "\")
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

    ~F5 Up::
       RefreshImageFile()
    Return

    ~+F5 Up::
       RefreshFilesList()
    Return

    ~^F5 Up::
       invertRecursiveness()
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

    ~F2 Up::
       RenameThisFile()
    Return

    ~vk4D Up::     ; M
       InvokeMoveFiles()
    Return

    ~vk55 Up::  ;  U
       ColorsAdjusterPanelWindow()
    Return

    vk46 Up::     ; F
       ToggleImgFX()
    Return

    +vk46 Up::     ; Shift+F
       ToggleImgFX(2)
    Return

    vk41 Up::     ; A
       ToggleIMGalign()
    Return

    ~Del Up::
       DeletePicture()
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
          ChangeZoom(1)
          Return
       }
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("R")
       } Else
       {
          resetSlideshowTimer(0)
          If (thumbsDisplaying=1)
             thumbsSelector(A_ThisHotkey)
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
          ChangeZoom(-1)
          Return
       }
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
       {
          PanIMGonScreen("L")
       } Else
       {
          resetSlideshowTimer(0)
          If (thumbsDisplaying=1)
             thumbsSelector(A_ThisHotkey)
          PreviousPicture()
       }
    Return

    PgDn::
    +PgDn::
       resetSlideshowTimer(0)
       If (thumbsDisplaying=1)
          ThumbsNavigator("PgDn", A_ThisHotkey)
       Else
          NextPicture()
    Return

    PgUp::
    +PgUp::
       resetSlideshowTimer(0)
       If (thumbsDisplaying=1)
          ThumbsNavigator("PgUp", A_ThisHotkey)
       Else
          PreviousPicture()
    Return

    ~Home Up::
       FirstPicture()
    Return

    ~End Up::
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
     sldGenerateFilesList(fileNamu, 0, mustRemQuotes)

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

escRoutine() {
   If (A_TickCount - lastLongOperationAbort < 1500)
      Return

   If (AnyWindowOpen>0)
   {
      CloseWindow()
      showTOOLtip("Other window closed...")
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
    If (slideShowRunning=1)
       ToggleSlideShowu()
    IDshowImage(currentFileIndex, 1)
}

IncreaseSlideSpeed() {
   slideShowDelay := Round((slideShowDelay + 1000)/1000)*1000
   If (slideShowDelay>15000)
      slideShowDelay := 15500
   resetSlideshowTimer(1)
   writeMainSettings()
}

resetSlideshowTimer(showMsg) {
   If (easySlideStoppage=1 && slideShowRunning=1)
      ToggleSlideShowu()
   Else If (slideShowRunning=1)
   {
      ToggleSlideShowu()
      Sleep, 1
      ToggleSlideShowu()
   }

   If (showMsg=1)
   {
      delayu := Round(slideShowDelay/1000, 2)
      showTOOLtip("Slideshow speed: " delayu " second(s)")
      SetTimer, RemoveTooltip, % -msgDisplayTime
   }
}

DecreaseSlideSpeed() {
   slideShowDelay := (slideShowDelay<1100) ? slideShowDelay - 250 : Round((slideShowDelay - 1000)/1000)*1000
   If (slideShowDelay<950)
      slideShowDelay := (slideShowDelay<550) ? 250 : 500

   resetSlideshowTimer(1)
   writeMainSettings()
}

CopyImagePath() {
  If (currentFileIndex=0)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (markedSelectFile)
     filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

  If (markedSelectFile>0 && filesElected>1)
  {
     startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
     Loop, % filesElected
     {
        thisFileIndex := startPoint + A_Index - 1
        file2rem := resultedFilesList[thisFileIndex]
        file2rem := StrReplace(file2rem, "||")
        listu .= file2rem "`n"
     }
     Clipboard := listu
     showTOOLtip("The file paths of " filesElected " files were copied to clipboard...")
     SetTimer, RemoveTooltip, % -msgDisplayTime
     markedSelectFile := ""
     Return
  }

  imgpath := resultedFilesList[currentFileIndex]
  imgpath := StrReplace(imgpath, "||")
  Clipboard := imgpath
  showTOOLtip("File path copied to clipboard...`n" imgpath)
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

CopyImage2clip() {
  If (currentFileIndex=0)
     Return
  If (slideShowRunning=1)
     ToggleSlideShowu()

  imgpath := resultedFilesList[currentFileIndex]
  FileGetSize, fileSizu, %imgpath%
  If (FileExist(imgpath) && fileSizu>500)
  {
     r := coreResizeIMG(imgpath, 0, 0, "--", 1, 1, 0)
     If r
     {
        showTOOLtip("Image copied to clipboard...")
        SoundBeep, 900, 100
     } Else
     {
        showTOOLtip("ERROR: Failed to copy the image to clipboard...")
        SoundBeep, 300, 900
     }
     SetTimer, RemoveTooltip, % -msgDisplayTime
  } Else
  {
     showTOOLtip("ERROR: Failed to copy image to clipboard...")
     SoundBeep, 300, 900
     SetTimer, RemoveTooltip, % -msgDisplayTime
  }
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
   lastInvoked := A_TickCount
   RemoveTooltip()
   DestroyGIFuWin()
   Sleep, 2
   If (wasInitFIMlib=1)
      FreeImage_FoxInit(False) ; Unload Dll

   disposeCacheIMGs()
   If AprevGdiBitmap
      AprevGdiBitmap := Gdip_DisposeImage(AprevGdiBitmap)
   If BprevGdiBitmap
      BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap)
   Sleep, 2
   writeMainSettings()
   lastInvoked := A_TickCount
   Gdip_Shutdown(GDIPToken)  
}

GuiClose:
Cleanup:
   TrueCleanup()
   ExitApp
Return

disposeCacheIMGs() {
   If ViewPortBMPcache
      ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
   If gdiBitmapSmall
      gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)
   If gdiBitmap
      gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)
}

activateMainWin() {
   Static lastInvoked := 1
   LbtnDwn := 0
   If (A_TickCount - lastInvoked < 30)
      Return

   If (easySlideStoppage=1 && slideShowRunning=1)
      ToggleSlideShowu()

   If (toolTipGuiCreated=1)
      TooltipCreator(1, 1)
   lastInvoked := A_TickCount
}

ToggleThumbsMode() {
   Static lastInvoked := 1

   If (A_TickCount - lastInvoked<150) || (A_TickCount - lastOtherWinClose<150)
   {
      lastInvoked := A_TickCount
      Return
   }

   lastInvoked := A_TickCount
   GdipCleanMain(0)
   editingSelectionNow := 0
   If (thumbsDisplaying=1)
   {
      thumbsDisplaying := 0
      WinMove, ahk_id %hGDIthumbsWin%,, 1, 1, 1, 1
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
      lastInvoked := A_TickCount
      Return
   } Else If (CurrentSLD && maxFilesIndex>1)
      UpdateThumbsScreen()

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
  showTOOLtip("Thumbnails aspect ratio: " defineThumbsAratio())
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
   IMGlargerViewPort := 0
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If (GIFsGuiCreated=1)
      DestroyGIFuWin()

   thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
   If (prevStartIndex!=startIndex) || (forceThis=2)
   {
      If (A_TickCount - lastInvoked < 90)
      || ((A_TickCount - prevFullThumbsUpdate < 300) || (A_TickCount - lastInvoked < 150)) && (forceThis!=2)
      {
         SetTimer, RefreshThumbsList, -500
         lastInvoked := A_TickCount
      } Else
      {
         If (A_TickCount - prevTooltipDisplayTime > 1000)
         {
            showTOOLtip("Generating thumbnails, please wait...")
            SetTimer, RemoveTooltip, -500
         }
         GdipCleanMain(0)
         r := QPV_ShowThumbnails(startIndex)
      }
   } Else r := 1
   prevStartIndex := startIndex
   mainGdipWinThumbsGrid()
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

panIMGclick(oX:=0, oY:=0, oDx:=0, oDy:=0) {
   If (slideShowRunning=1)
      ToggleSlideShowu()
; ToolTip, % oX ", " oY ", " oDx ", " oDy
   If (!oX && !oY)
   {
      GetPhysicalCursorPos(oX, oY)
      oDx := IMGdecalageX
      oDy := IMGdecalageY
   }

   While, (GetKeyState("LButton", "P") || LbtnDwn=1)
   {
      GetPhysicalCursorPos(mX, mY)
      Dx := mX - oX
      Dy := mY - oY
      IMGdecalageX := oDx + Dx
      IMGdecalageY := oDy + Dy
      filterDelayiedImageDisplay()
      MouseGetPos,,, OutputVarWin
      If (OutputVarWin!=PVhwnd) && (LbtnDwn=1)
         Break
   }
   SetTimer, ResetLbtn, -25
}

WinClickAction(forceThis:=0) {
   Critical, on
   Static thisZeit := 1, prevTippu := 1, lastInvoked := 1, lastInvoked2 := 1
   If (AnyWindowOpen=1)
      CloseWindow()

   If AnyWindowOpen
   {
      If (AnyWindowOpen=10 && imgFxMode!=1)
      {
         ForceNoColorMatrix := !ForceNoColorMatrix
         dummyTimerDelayiedImageDisplay(50)
      }
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
   WinGetPos, winXu, winYu, winWidth, winHeight, ahk_id %PVhwnd%
   If (thumbsDisplaying=1 && maxFilesIndex>0)
   {
      CoordMode, Mouse, Window
      MouseGetPos, mX, mY
      CoordMode, Mouse, Screen
  ;   GetPhysicalCursorPos(mX, mY)
      thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
      decalageX := winWidth - mainWidth
      decalageY := winHeight - mainHeight
      rowIndex := 0
      columnIndex := -1
      Loop, % maxItemsPage*2
      {
         columnIndex++
         If (columnIndex>=maxItemsW)
         {
            rowIndex++
            columnIndex := 0
         }
         DestPosX := decalageX + thumbsW*columnIndex + thumbsW
         DestPosY := decalageY + thumbsH*rowIndex + thumbsH
         If (DestPosX>mX && DestPosY>mY)
         {
            newIndex := startIndex + A_Index - 1
            Break
         }
      }

      scrollXpos := mainWidth - imgHUDbaseUnit//2
      If (mX+decalageX>scrollXpos)
      {
         newIndexu := ((mY-decalageY)/mainHeight)*100
         newIndexu := Ceil((maxFilesIndex/100)*newIndexu)
         If (newIndexu<1)
            currentFileIndex := 1
         Else If (newIndexu>maxFilesIndex)
            currentFileIndex := maxFilesIndex-1
         Else
            currentFileIndex := newIndexu
         dummyTimerDelayiedImageDisplay(50)
         Return
      }

      maxWidu := maxItemsW*thumbsW + decalageX - 1
      maxHeitu := maxItemsH*thumbsH + decalageY - 1
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

         If (GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P"))
            markedSelectFile := (markedSelectFile=newIndex || markedSelectFile=currentFileIndex) ? "" : newIndex
         Else currentFileIndex := newIndex
         If (forceThis="rClick")
            DelayiedImageDisplay()
         Else
            dummyTimerDelayiedImageDisplay(25)
      }
      lastInvoked := A_TickCount
      Return
   } Else If (editingSelectionNow=1 && activateImgSelection=1 && spaceState!=1 && thumbsDisplaying!=1)
   {
      GetClientSize(mainWidth, mainHeight, PVhwnd)
      JEE_ClientToScreen(hPicOnGui1, 0, 0, tGuiX, tGuiY)
      decalageX := tGuiX - winXu
      decalageY := tGuiY - winYu
      nSelDotX  := selDotX,  nSelDotAx := selDotAx
      nSelDotBx := selDotBx, nSelDotCx := selDotCx
      nSelDotY  := selDotY,  nSelDotAy := selDotAy
      nSelDotBy := selDotBy, nSelDotCy := selDotCy

      If (FlipImgH=1)
      {
         nSelDotX := mainWidth - selDotX - decalageX - dotsSize
         nSelDotAx := mainWidth - selDotAx - decalageX - dotsSize
         nSelDotBx := mainWidth - selDotBx - decalageX - dotsSize
         nSelDotCx := mainWidth - selDotCx - decalageX - dotsSize
      }

      If (FlipImgV=1)
      {
         nSelDotY := mainHeight - selDotY - decalageY + dotsSize
         nSelDotAy := mainHeight - selDotAy - decalageY + dotsSize
         nSelDotBy := mainHeight - selDotBy - decalageY + dotsSize
         nSelDotCy := mainHeight - selDotCy - decalageY + dotsSize
      }

      CoordMode, Mouse, Window
      MouseGetPos, mXo, mYo
      GetPhysicalCursorPos(mXa, mYa)
      JEE_ScreenToWindow(hGDIwin, mXa, mYa, mXoT, mYoT)
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
      thisZeit := 1
      ctrlState := (GetKeyState("Ctrl", "P") && dotActive=9) ? 1 : 0
      While, ((GetKeyState("LButton", "P") || LbtnDwn=1) && dotActive && ctrlState=0)
      {
          MouseGetPos, mX, mY, thisWind
          changePosX := (zoomLevel>1) ? (mX - mXo)/zL : (mX - mXo)*zL
          changePosY := (zoomLevel>1) ? (mY - mYo)/zL : (mY - mYo)*zL
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
          If !(valueBetween(Abs(changePosY), 0, 2) && valueBetween(Abs(changePosX), 0, 2))
             filterDelayiedImageDisplay()

          zImgSelX1 := Round(imgSelX1*zoomLevel)
          zImgSelY1 := Round(imgSelY1*zoomLevel)
          zImgSelX2 := Round(imgSelX2*zoomLevel)
          zImgSelY2 := Round(imgSelY2*zoomLevel)
          imgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
          imgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
          If (dotActive=9)
             addMsg := "Dragging selection...`n"
          If (A_TickCount - prevTippu>90) && (LbtnDwn!=1)
          {
             ToolTip, % addMsg "X / Y: " zImgSelX1 ", " zImgSelY1 "`nW / H: " imgSelW ", " imgSelH, % decalageX + 10, % decalageY + 10
             prevTippu := A_TickCount
          }
          thisZeit := A_TickCount
          If (thisWind!=PVhwnd && LbtnDwn=1)
             Break
      }
      If (LbtnDwn!=1 && dotActive=9 && valueBetween(Abs(changePosY), 0, 2) && valueBetween(Abs(changePosX), 0, 2))
         thisZeit := dotActive := ctrlState := 0
      SetTimer, ResetLbtn, -50
      ToolTip
      CoordMode, Mouse, Screen
      If (dotActive || (A_TickCount - thisZeit<350)) && (ctrlState=0)
         Return
   }

   If (A_TickCount - lastInvoked<250) && (lastInvoked>1 && CurrentSLD && maxFilesIndex>0 && spaceState!=1)
   {
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
   } Else If (maxFilesIndex>1 && CurrentSLD)
   {
      If (TouchScreenMode=0 || spaceState=1)
      {
         If (IMGlargerViewPort=1 && thumbsDisplaying!=1)
            SetTimer, panIMGclick, -25
         lastInvoked := A_TickCount
         Return
      }
      Sleep, 5
      If (A_GuiControl="PicOnGUI3")
         winGoNextSlide()
      Else If (A_GuiControl="PicOnGUI1")
         winGoPrevSlide()
      Else If (A_GuiControl="PicOnGUI2a" || A_GuiControl="PicOnGUI2b" || A_GuiControl="PicOnGUI2c")
      {
         CoordMode, Mouse, Window
         MouseGetPos, mX, mY
         CoordMode, Mouse, Screen
         GetClientSize(mainWidth, mainHeight, PVhwnd)
         decalageY := winHeight - mainHeight

         If (mY - decalageY<winHeight//5)
         {
            ChangeZoom(1)
            Return
         }

         If (mY>winHeight-winHeight//5)
         {
            ChangeZoom(-1)
            Return
         }
         If (IMGlargerViewPort=1 && thumbsDisplaying!=1)
            SetTimer, panIMGclick, -25
         Else
            winGoSlide()
      }
   } Else If (!CurrentSLD || maxFilesIndex<1)
   {
      clippyTest := resultedFilesList[0]
      If (!CurrentSLD && currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
         Return
      Sleep, 25
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

  If (mPosCtrl="PicOnGUI3")
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
  If (mPosCtrl="PicOnGUI1")
     GoPrevSlide()
  Else If (mPosCtrl="PicOnGUI3")
     GoNextSlide()
  Else If (mPosCtrl="PicOnGUI2a")
     ThumbsNavigator("Upu", "-")
  Else If (mPosCtrl="PicOnGUI2c")
     ThumbsNavigator("Down", "-")
}

winGoPrevSlide() {
  If GetKeyState("LButton", "P") || (LbtnDwn=1)
  {
     SetTimer, winGoPrevSlide, -25
     Return
  }
  If (mPosCtrl="PicOnGUI1")
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


ToggleImageSizingMode() {
    If (slideShowRunning=1)
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
  ToggleSlideShowu()
  If (slideShowRunning!=1)
  {
     showTOOLtip("Slideshow stopped")
     SetTimer, RemoveTooltip, % -msgDisplayTime
  } Else 
  {
     delayu := Round(slideShowDelay/1000, 2)
     friendly := DefineSlideShowType()
     etaTime := "Estimated time: " SecToHHMMSS(Round((slideShowDelay/1000,2)*maxFilesIndex))
     showTOOLtip("Started " friendly " slideshow`nSpeed: " delayu " sec.`nTotal files: "  maxFilesIndex "`n" etaTime)
     SetTimer, RemoveTooltip, % -msgDisplayTime
  }
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
     SetTimer, RandomPicture, Off
     SetTimer, NextPicture, Off
     SetTimer, PreviousPicture, Off
     SetTimer, preventScreenOff, Off
  } Else If (thumbsDisplaying!=1)
  {
     slideShowRunning := 1
     imgQuality := 7
     SetTimer, preventScreenOff, 59520
     If (SlideHowMode=1)
        SetTimer, RandomPicture, %slideShowDelay%
     Else If (SlideHowMode=2)
        SetTimer, PreviousPicture, %slideShowDelay%
     Else If (SlideHowMode=3)
        SetTimer, NextPicture, %slideShowDelay%
  }
}

GoNextSlide() {
  Sleep, 15
  If GetKeyState("LButton", "P")
  {
     SetTimer, GoNextSlide, -100
     Return
  }

  If (slideShowRunning=1)
     resetSlideshowTimer(0)

  If (SlideHowMode=1)
     RandomPicture()
  Else If (SlideHowMode=2)
     PreviousPicture()
  Else If (SlideHowMode=3)
     NextPicture()
}

GoPrevSlide() {
  Sleep, 15
  If GetKeyState("LButton", "P")
  {
     SetTimer, GoPrevSlide, -100
     Return
  }

  If (slideShowRunning=1)
     resetSlideshowTimer(0)

  If (SlideHowMode=1)
     PrevRandyPicture()
  Else If (SlideHowMode=2)
     PreviousPicture()
  Else If (SlideHowMode=3)
     NextPicture()
}

SecToHHMMSS(Sec) {
  OldFormat := A_FormatFloat
  SetFormat, Float, 02.0
  Hrs  := Sec//3600/1
  Min := Mod(Sec//60, 60)/1
  Sec := Mod(Sec,60)/1
  SetFormat, Float, %OldFormat%
  Return (Hrs ? Hrs ":" : "") Min ":" Sec
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

   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   friendly := DefineSlideShowType()
   showTOOLtip("Slideshow mode: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   writeMainSettings()
}

DefineFXmodes() {
   Static FXmodesLabels := {1:"ORIGINAL", 2:"PERSONALIZED", 3:"AUTO-ADJUSTED", 4:"GRAYSCALE", 5:"GRAYSCALE RED CHANNEL", 6:"GRAYSCALE GREEN CHANNEL", 7:"GRAYSCALE BLUE CHANNEL", 8:"INVERTED"}
       , otherFXLabels := {1:"ADAPTIVE", 2:"BRIGHTNESS", 3:"CONTRAST"}
   If FXmodesLabels.HasKey(imgFxMode)
      friendly := FXmodesLabels[imgFxMode]
   Else
      friendly := "Colors FX: " imgFxMode
   If (imgFxMode=3)
      friendly .= A_Space otherFXLabels[autoAdjustMode]

   If (bwDithering=1 && imgFxMode=4)
      friendly := "BLACK/WHITE DITHERED"

   Return friendly
}

ToggleImgFX(dir:=0) {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
   If (dir=2)
      imgFxMode--
   Else
      imgFxMode++

   If (imgFxMode=3 && thumbsDisplaying=1)
   {
      If (dir=2)
         imgFxMode--
      Else
         imgFxMode++
   }

   If (imgFxMode>8)
      imgFxMode := 1
   Else If (imgFxMode<1)
      imgFxMode := 8

   friendly := DefineFXmodes()
   If (imgFxMode=4)
      friendly .= "`nBrightness: " Round(lumosGrayAdjust, 3) "`nContrast: " Round(GammosGrayAdjust, 3)
   Else If (imgFxMode=2)
      friendly .= "`nBrightness: " Round(lumosAdjust, 3) "`nContrast: " Round(GammosAdjust, 3) "`nSaturation: " Round(satAdjust*100) "%"

   If (imgFxMode=4)
      friendly .= "`n `nYou can adjust brightness and contrast using`n [ and ] with or without Shift."
   Else If (imgFxMode=2)
      friendly .= "`n `nYou can adjust brightness, contrast and saturation using`n [ and ] with or without Shift or Ctrl."
   showTOOLtip("Image colors: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   If (thumbsDisplaying=1)
      RefreshThumbsList()
   Else prevStartIndex := -1

   If (imgFxMode=3 && thumbsDisplaying!=1)
   {
      imgpath := resultedFilesList[currentFileIndex]
      AdaptiveImgLight(gdiBitmap, imgpath, 1, 1)
   }

   writeMainSettings()
   If (o_bwDithering=0)
      o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0

   If (o_bwDithering=1)
      IDshowImage(currentFileIndex, 4)
   Else
      dummyTimerDelayiedImageDisplay(10)
}

defineImgAlign() {
   modes := {1:"Top-left corner", 2:"Top-center", 3:"Top-right corner", 4:"Left-center", 5:"Center", 6:"Right-center", 7:"Bottom-left corner", 8:"Bottom-center", 9:"Bottom-right corner"}
   thisAlign := (IMGresizingMode=4) ? 5 : imageAligned
   r := modes[thisAlign]
   Return r
}

ToggleIMGalign() {
   If (thumbsDisplaying=1 || IMGresizingMode=4)
      Return

   If (slideShowRunning=1)
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
  If (imgFxMode!=1)
  {
     ForceNoColorMatrix := !ForceNoColorMatrix
     AnyWindowOpen := (ForceNoColorMatrix=1) ? 10 : 0
     dummyTimerDelayiedImageDisplay(50)
     SetTimer, resetClrMatrix, -1500
  }
}

resetClrMatrix() {
   AnyWindowOpen := ForceNoColorMatrix := 0
   dummyTimerDelayiedImageDisplay(50)
}

ResetImageView() {
   Critical, on
   ChangeLumos(2)
}

ChangeLumos(dir) {
   Static prevValues
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   If (imgFxMode!=2 && imgFxMode!=4 && dir!=2)
      imgFxMode := 2

   If (dir=2)
   {
      o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
      If (imgFxMode=4)
      {
         ; bwDithering := 0
         GammosGrayAdjust := 0
         lumosGrayAdjust := 1
      } Else If (imgFxMode=2)
      {
         satAdjust := lumosAdjust := 1
         GammosAdjust := 0
      }

      If (imgFxMode=2 || imgFxMode=3)
         chnRdecalage := chnGdecalage := chnBdecalage := 0

      FlipImgH := FlipImgV := 0
      imgFxMode := 1

      If (thumbsDisplaying=1)
      {
         thumbsZoomLevel := 1
         thumbsH := othumbsH + 1
         thumbsW := othumbsW + 1
         SetTimer, RefreshThumbsList, -250
      }

      If (IMGresizingMode=4)
         zoomLevel := 1
   } Else If (imgFxMode=4)
   {
      If (dir=1)
         lumosGrayAdjust := lumosGrayAdjust + 0.05
      Else
         lumosGrayAdjust := lumosGrayAdjust - 0.05
      If (lumosGrayAdjust<0)
         lumosGrayAdjust := 0
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
      showTOOLtip("Image colors: UNALTERED")
   Else
      showTOOLtip("Image brightness: " value2show)

   If (thumbsDisplaying!=1)
      prevStartIndex := -1
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues && dir!=2)
      Return

   prevValues := newValues
   If (o_bwDithering=1)
      IDshowImage(currentFileIndex, 4)
   Else
      dummyTimerDelayiedImageDisplay(10)
}

ChangeZoom(dir) {
   Static prevValues
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (thumbsDisplaying=1)
   {
      writeMainSettings()
      If (dir=1)
         thumbsZoomLevel := thumbsZoomLevel + 0.1
      Else
         thumbsZoomLevel := thumbsZoomLevel - 0.1
      thumbsH := Round(othumbsH*thumbsZoomLevel)
      thumbsW := Round(othumbsW*thumbsZoomLevel)
      If (thumbsZoomLevel<0.35)
         thumbsZoomLevel := 0.35
      Else If (thumbsZoomLevel>10)
         thumbsZoomLevel := 10
      showTOOLtip("Thumbnails zoom level: " Round(thumbsZoomLevel*100) "%")
      SetTimer, RemoveTooltip, % -msgDisplayTime
      SetTimer, RefreshThumbsList, -250
      Return
   }

   If (dir=1)
      zoomLevel := (zoomLevel<1 || IMGlargerViewPort=0) ? zoomLevel + 0.05 : zoomLevel + 0.15
   Else
      zoomLevel := (zoomLevel<1 || IMGlargerViewPort=0) ? zoomLevel - 0.05 : zoomLevel - 0.15

   IMGresizingMode := 4
   imageAligned := 5
   If (zoomLevel<0.04)
      zoomLevel := 0.015
   Else If (zoomLevel>15)
      zoomLevel := 15

   showTOOLtip("Zoom level: " Round(zoomLevel*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues)
      Return

   prevValues := newValues
   dummyTimerDelayiedImageDisplay(10)
}

ChangeGammos(dir) {
   Static prevValues
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (imgFxMode!=2 && imgFxMode!=4)
      imgFxMode := 2

   value2Adjust := (imgFxMode=4) ? GammosGrayAdjust : GammosAdjust
   If (dir=1)
      value2Adjust := value2Adjust + 0.05
   Else
      value2Adjust := value2Adjust - 0.05

   If (value2Adjust<-25)
      value2Adjust := -25
   Else If (value2Adjust>1)
      value2Adjust := 1

   If (imgFxMode=4)
      GammosGrayAdjust := value2Adjust
   Else
      GammosAdjust := value2Adjust

   If (thumbsDisplaying!=1)
      prevStartIndex := -1
   showTOOLtip("Image contrast: " Round(value2Adjust, 3))
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues)
      Return

   prevValues := newValues
   dummyTimerDelayiedImageDisplay(10)
}

ChangeSaturation(dir) {
   Static prevValues
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (imgFxMode=4)
      satAdjust := 0

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
   newValues := "a" satAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues)
      Return

   prevValues := newValues
   dummyTimerDelayiedImageDisplay(10)
}

TransformIMGv() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

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

TransformIMGh() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
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

PreviousPicture(dummy:=0, inLoop:=0) {
   currentFileIndex--
   If (currentFileIndex<1)
      currentFileIndex := (thumbsDisplaying=1) ? 1 : maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := (thumbsDisplaying=1) ? maxFilesIndex : 1

   endLoop := (inLoop=250) ? 250 : 0
   r := IDshowImage(currentFileIndex, endLoop)
   If (!r && inLoop<250)
   {
      inLoop++
      PreviousPicture(0, inLoop)
   } Else inLoop := 0
}

NextPicture(dummy:=0, inLoop:=0) {
   currentFileIndex++
   If (currentFileIndex<1)
      currentFileIndex := (thumbsDisplaying=1) ? 1 : maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := (thumbsDisplaying=1) ? maxFilesIndex : 1
   endLoop := (inLoop=250) ? 250 : 0
   r := IDshowImage(currentFileIndex, endLoop)
   If (!r && inLoop<250)
   {
      inLoop++
      NextPicture(0, inLoop)
   } Else inLoop := 0
}

PasteClipboardIMG() {
    changeMcursor()
    clipBMP := Gdip_CreateBitmapFromClipboard()
    If (InStr(clipBMP, "err-") || !clipBMP)
    {
       showTOOLtip("Unable to retrieve image from clipboard...")
       SetTimer, RemoveTooltip, % -msgDisplayTime
       Try DllCall("user32\SetCursor", "Ptr", hCursN)
       Return
    }
    If (activateImgSelection=1)
       toggleImgSelection()
    file2save := thumbsCacheFolder "\Current-Clipboard.png"
    changeMcursor()
    r := Gdip_SaveBitmapToFile(clipBMP, file2save)
    Gdip_DisposeImage(clipBMP, 1)
    If r
    {
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

    imgFxMode := 1
    markedSelectFile := ""
    FlipImgH := FlipImgV := currentFileIndex := 0
    resultedFilesList[0] := file2save
    ShowTheImage(file2save, 2)
}

thumbsSelector(aKey) {
  Static lastInvoked := 1
  If (!InStr(aKey, "+") && thumbsDisplaying=1 && (A_TickCount - lastInvoked<1900))
     markedSelectFile := ""
  IF (InStr(aKey, "+") && thumbsDisplaying=1)
  {
     lastInvoked := A_TickCount
     IF !markedSelectFile
        markedSelectFile := currentFileIndex
  }
}

ThumbsNavigator(keyu, aKey) {
  resetSlideshowTimer(0)
  thumbsSelector(aKey)
  thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
  If (keyu="Down")
  {
     currentFileIndex := currentFileIndex + maxItemsW - 1
     NextPicture()
  } Else If (keyu="Upu")
  {
     currentFileIndex := currentFileIndex - maxItemsW + 1
     PreviousPicture()
  } Else If (keyu="PgUp")
  {
     currentFileIndex := currentFileIndex - maxItemsPage + 1
     PreviousPicture()
  } Else If (keyu="PgDn")
  {
     currentFileIndex := currentFileIndex + maxItemsPage - 1
     NextPicture()
  }
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

   stepu := GetKeyState("Shift", "P") ? 0.3 : 0.1
   GetClientSize(mainWidth, mainHeight, PVhwnd)
   If (direction="U" && FlipImgV=0) || (direction="D" && FlipImgV=1)
      IMGdecalageY := IMGdecalageY + Round(mainHeight*stepu)
   Else If (direction="D" && FlipImgV=0) || (direction="U" && FlipImgV=1)
      IMGdecalageY := IMGdecalageY - Round(mainHeight*stepu)
   Else If (direction="L" && FlipImgH=0) || (direction="R" && FlipImgH=1)
      IMGdecalageX := IMGdecalageX + Round(mainWidth*stepu)
   Else If (direction="R" && FlipImgH=0) || (direction="L" && FlipImgH=1)
      IMGdecalageX := IMGdecalageX - Round(mainWidth*stepu)

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
       editImgSelection()

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
       ToggleThumbsMode()

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
       If !valu 
          delimu := ""
       textu .= valu delimu
       Sleep, 10
       ; ToolTip, %valu% -- %aC% -- %aR%
       If (!valu && A_Index>19)
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
   thumbBMP := LoadBitmapFromFileu(resultu, 0, 1)
   If thumbBMP
      Gdip_GetImageDimensions(thumbBMP, Width, Height)

   Zoomu := Round(zoomLevel*100)
   generalInfos := "File name||" fileNamu "`nLocation||" folderu "\`nFile size||" fileSizu " kilobytes`nDate created||" FileDateC "`nDate modified||" FileDateM "`nResolution (W x H)||" Width " x " Height " (in pixels)`nCurrent zoom level||" zoomu " % (" DefineImgSizing() ")"
   Loop, Parse, generalInfos, `n
   {
       lineArru := StrSplit(A_LoopField, "||")
       LV_Add(A_Index, lineArru[1], lineArru[2])
   }

   LV_Add(A_Index, "Colors display", DefineFXmodes())
   If !thumbBMP
      Return

   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   If (isThisHDRimg=0)
   {
      Gdip_GetHistogram(thumbBMP, 2, ArrChR, ArrChG, ArrChB)
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
   }

   If InStr(isThisHDRimg, "R")
      LV_Add(A_Index, "Camera RAW file format", 1)
   Else If (isThisHDRimg="H")
      LV_Add(A_Index, "HDR image", 1)

   If RegExMatch(resultu, "i)(.\.gif)$")
   {
      CountFrames := getGIFframesCount(thumbBMP)
      LV_Add(A_Index, "Animated GIF frames", CountFrames)
   } 

   MoreProperties := Gdip_GetAllPropertyItems(thumbBMP)
   For ID, Val In MoreProperties
   {
      If ID Is Integer
      {
         PropName := Gdip_GetPropertyTagName(ID)
         PropType := Gdip_GetPropertyTagType(Val.Type)
         If (val.value && StrLen(PropName)>1 && PropName!="unknown")
         {
            If (PropName="frame delay") || (PropName="bits per sample")
            {
               valu := SubStr(Val.Value, 1, InStr(Val.Value, A_Space))
               LV_Add(A_Index, PropName, valu)
            } Else LV_Add(A_Index, PropName, Val.Value)
         }
      }
   }

   If thumbBMP
      Gdip_DisposeImage(thumbBMP, 1)

   Loop, 2
       LV_ModifyCol(A_Index, "AutoHdr Left")
}

Jump2index() {
   If (maxFilesIndex<3)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

   GUI, 1: +OwnDialogs
   InputBox, jumpy, Jump at index #, Type the Type the index number you want to jump to.,,,,,,,, %currentFileIndex%
   If !ErrorLevel
   {
      If jumpy is not Number
         Return

      currentFileIndex := jumpy
      If (currentFileIndex<1)
         currentFileIndex := 1
      If (currentFileIndex>maxFilesIndex)
         currentFileIndex := maxFilesIndex
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
   }
}

testFileExists(imgpath) {
  ; https://docs.microsoft.com/en-us/windows/desktop/api/fileapi/nf-fileapi-getfilesize
  ; H := DllCall("kernel32\GetFileAttributesW", "Str", imgpath)
  ; H := DllCall("shlwapi.dll\PathFileExistsW", "Str", imgpath)
  ; If (h>0)
  ;    Return 256
  VarSetCapacity(dummy, 1024, 0)
  H := DllCall("kernel32\FindFirstFileW", "Str", imgpath, "Ptr", &dummy, "Ptr")
  Return H
}

informUserFileMissing() {
   Critical, on
   imgpath := resultedFilesList[currentFileIndex]
   zPlitPath(imgpath, 0, fileNamu, folderu)
   showTOOLtip("ERROR: File not found or access denied...`n" fileNamu "`n" folderu "\")
   winTitle := currentFileIndex "/" maxFilesIndex " | " OutFileName " | " OutDir
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
   UsrEditFilter := StrReplace(UsrEditFilter, "&")
   If !InStr(UsrEditFilter, "{ no filter }")
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
  If StrLen(entry2add)<3
     Return

  Loop, Parse, mainListu, `n
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
      If (A_Index>20)
         Break

      If StrLen(A_LoopField)<3
         Continue
      countItemz++
      IniWrite, % A_LoopField, % mainSettingsFile, RecentFilters, E%countItemz%
  }
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
     MsgBox, 16, %appTitle%: ERROR, Unable to write or access the files: permission denied...
     lastInvoked := A_TickCount
  }
}

InListMultiEntriesRemover() {
  If (markedSelectFile)
  {
     filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
     If (markedSelectFile>0 && filesElected>1)
        itsMultiFiles := 1
     Else remCurrentEntry(0, 0)
  } Else remCurrentEntry(0, 0)

   If (itsMultiFiles!=1)
      Return

   If (filesElected>90)
   {
      MsgBox, 52, %appTitle%, Are you sure you want to remove %filesElected% entries from the slideshow files list?
      IfMsgBox, Yes
        good2go := 1

      If (good2go!=1)
         Return
   }

   startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
   showTOOLtip("Removing " filesElected " index entries, please wait...")
   prevMSGdisplay := A_TickCount
   prevStartIndex := -1
   prevMaxy := maxFilesIndex
   Loop, % filesElected
   {
      If (A_TickCount - prevMSGdisplay>3500)
      {
         showTOOLtip("Removing " A_Index "/" filesElected " index entries, please wait...")
         prevMSGdisplay := A_TickCount
      }
      thisFileIndex := startPoint + A_Index - 1
      resultedFilesList[thisFileIndex] := ""
      changeMcursor()
      If StrLen(filesFilter)>1
      {
         z := filteredMap2mainList[thisFileIndex]
         bckpResultedFilesList[z] := ""
      }
   }

   If StrLen(filesFilter)>1
   {
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
      } Else MsgBox,, %appTitle%, No files left in the index, please (re)open a file or folder.
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

remCurrentEntry(dummy, silentus:=0) {
   Critical, on
   prevStartIndex := -1
   file2remA := resultedFilesList.RemoveAt(currentFileIndex)
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
      } Else MsgBox,, %appTitle%, No files left in the index, please (re)open a file or folder.
   } Else
   {
      currentFileIndex--
      If (slideShowRunning!=1 && silentus=0)
         r := IDshowImage(currentFileIndex)
      Else r := 1

      If !r
         informUserFileMissing()
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

WritePrefsIntoSLD() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   GUI, 1: +OwnDialogs
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
         MsgBox, 64, %appTitle%: Save slideshow settings error, The selected file appears not to have the correct file format.`nPlease select a .SLD file already saved by this application.
   }

}

SaveFilesList() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(maxFilesIndex)>1
   {
      GUI, 1: +OwnDialogs
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
            FileSetAttrib, -R, %file2save%
            Sleep, 2
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
      prevMSGdisplay := A_TickCount
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
      If (A_TickCount - prevMSGdisplay>3000)
         showTOOLtip("Saving list of " maxFilesIndex " entries into...`n" file2save "`nPlease wait, step 2...")
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

          If GetKeyState("Esc", "P")
          {
             lastLongOperationAbort := A_TickCount
             abandonAll := 1
             Break
          }

          countTFilez++
          If (noFilesCheck!="2")
          {
             If (A_TickCount - prevMSGdisplay>3500)
             {
                showTOOLtip("Checking for dead files... " countTFilez "/" maxFilesIndex ", please wait...")
                prevMSGdisplay := A_TickCount
             }
             If (testFileExists(r)>100)  ; If FileExist(r)
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
   MsgBox, 52, %appTitle%, This operation can take a lot of time. Each file will be read to identify its resolution in pixels.`n`nAre you sure you want to sort the list?
   IfMsgBox, Yes
        SortFilesList("resolution")
}

SortFilesList(SortCriterion) {
   Critical, on

   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      markedSelectFile := CurrentSLD := ""
      If StrLen(filesFilter)>1
      {
         MsgBox, 64, %appTitle%: Sort operation, The files list is filtered down to %maxFilesIndex% files from %bkcpMaxFilesIndex%. Only the files matched by current filter will be sorted, not all the files.`n`nTo sort all files, remove the filter.
         filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
         showTOOLtip("Preparing the files list, please wait...")
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      WinSetTitle, ahk_id %PVhwnd%,, Sorting files list - please wait...
      showTOOLtip("Gathering information for " maxFilesIndex "files, please wait...")
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
             If (z=1)
             {
                notSortedFilesListu .= r "`n"
                Continue
             }
          }
          countTFilez++
          If (A_TickCount - prevMSGdisplay>3500)
          {
             showTOOLtip("Gathering information for "  countFilez "/" maxFilesIndex " files, please wait...")
             prevMSGdisplay := A_TickCount
          }

          If !FileExist(r)
             Continue

          If (SortCriterion="size")
             FileGetSize, SortBy, %r%
          Else If (SortCriterion="modified")
             FileGetTime, SortBy, %r%, M
          Else If (SortCriterion="created")
             FileGetTime, SortBy, %r%, C
          Else If (SortCriterion="resolution")
          {
             op := GetImgFileDimension(r, Wi, He)
             SortBy := (op=1) ? Round(Wi/100 * He/100) : 0
          }

          If GetKeyState("Esc", "P")
          {
             lastLongOperationAbort := A_TickCount
             abandonAll := 1
             Break
          }

          If StrLen(SortBy)>1
             filesListu .= SortBy " |!\!|" r "`n"
      }

      If (abandonAll=1)
      {
         showTOOLtip("Operation aborted. Files list unchanged.")
         SetTimer, RemoveTooltip, % -msgDisplayTime
         CurrentSLD := backCurrentSLD
         SoundBeep, 950, 100
         RandomPicture()
         Try DllCall("user32\SetCursor", "Ptr", hCursN)
         Return
      }

      showTOOLtip("Sorting files list...")
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

      RandomPicture()
      SoundBeep, 950, 100
      Sleep, 25
      SetTimer, RemoveTooltip, % -msgDisplayTime
      CurrentSLD := backCurrentSLD
   }
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
     IniRead, tstuserimgQuality, %readThisFile%, General, userimgQuality, @
     IniRead, tstTouchScreenMode, %readThisFile%, General, TouchScreenMode, @
     IniRead, tstskipDeadFiles, %readThisFile%, General, skipDeadFiles, @
     IniRead, tstisAlwaysOnTop, %readThisFile%, General, isAlwaysOnTop, @
     IniRead, tstanimGIFsSupport, %readThisFile%, General, animGIFsSupport, @
     IniRead, tstisTitleBarHidden, %readThisFile%, General, isTitleBarHidden, @
     IniRead, tstthumbsAratio, %readThisFile%, General, thumbsAratio, @
     IniRead, tstthumbsZoomLevel, %readThisFile%, General, thumbsZoomLevel, @
     IniRead, tstSLDcacheFilesList, %readThisFile%, General, SLDcacheFilesList, @
     IniRead, tsteasySlideStoppage, %readThisFile%, General, easySlideStoppage, @
     IniRead, tstautoAdjustMode, %readThisFile%, General, autoAdjustMode, @
     IniRead, tstdoSatAdjusts, %readThisFile%, General, doSatAdjusts, @
     IniRead, tstchnRdecalage, %readThisFile%, General, chnRdecalage, @
     IniRead, tstchnGdecalage, %readThisFile%, General, chnGdecalage, @
     IniRead, tstchnBdecalage, %readThisFile%, General, chnBdecalage, @
     IniRead, tstusrAdaptiveThreshold, %readThisFile%, General, usrAdaptiveThreshold, @
     IniRead, tstbwDithering, %readThisFile%, General, bwDithering, @

     If (tstslideshowdelay!="@" && tstslideshowdelay>200)
        slideShowDelay := tstslideShowDelay
     If (tstimgresizingmode!="@" && StrLen(tstIMGresizingMode)=1 && tstIMGresizingMode<5)
        IMGresizingMode := tstIMGresizingMode
     If (tstimgFxMode!="@" && valueBetween(tstimgFxMode, 1, 7))
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
     If (tstuserimgQuality=1 || tstuserimgQuality=0)
        userimgQuality := tstuserimgQuality
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
     If (tstsatAdjust!="@")
        satAdjust := tstsatAdjust
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

     coreChangeThumbsAratio()
     imgQuality := (userimgQuality=1) ? 7 : 5
     WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
}

writeMainSettings() {
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
    IniWrite, % prevFileSavePath, % mainSettingsFile, General, prevFileSavePath
    IniWrite, % alwaysOpenwithFIM, % mainSettingsFile, General, alwaysOpenwithFIM
    IniWrite, % userHQraw, % mainSettingsFile, General, userHQraw
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
    If (tstalwaysOpenwithFIM=1 || tstalwaysOpenwithFIM=0)
       alwaysOpenwithFIM := tstalwaysOpenwithFIM
    If (tstuserHQraw=1 || tstuserHQraw=0)
       userHQraw := tstuserHQraw
    If (tstResizeInPercentage=1 || tstResizeInPercentage=0)
       ResizeInPercentage := tstResizeInPercentage
    If (tstResizeUseDestDir=1 || tstResizeUseDestDir=0)
       ResizeUseDestDir := tstResizeUseDestDir
    If (valueBetween(tstResizeRotationUser, 1, 4) && tstResizeRotationUser!="@")
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
    If (tstprevFileMovePath!="@" || StrLen(tstprevFileMovePath)>3)
       prevFileMovePath := tstprevFileMovePath
    If (tstprevFileSavePath!="@" || StrLen(tstprevFileSavePath)>3)
       prevFileSavePath := tstprevFileSavePath
    If (tstprevOpenFolderPath!="@" || StrLen(tstprevOpenFolderPath)>3)
       prevOpenFolderPath := tstprevOpenFolderPath
    If (tstResizeDestFolder!="@" || StrLen(tstResizeDestFolder)>3)
       ResizeDestFolder := tstResizeDestFolder

    If !prevOpenFolderPath
       prevOpenFolderPath := A_WorkingDir

    If !ResizeDestFolder
    {
       If prevOpenFolderPath
          ResizeDestFolder := prevOpenFolderPath
       Else
          ResizeDestFolder := A_WorkingDir
    }
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
    IniWrite, % lumosAdjust, %file2save%, General, lumosAdjust
    IniWrite, % GammosAdjust, %file2save%, General, GammosAdjust
    IniWrite, % lumosGrayAdjust, %file2save%, General, lumosGrayAdjust
    IniWrite, % GammosGrayAdjust, %file2save%, General, GammosGrayAdjust
    IniWrite, % satAdjust, %file2save%, General, satAdjust
    IniWrite, % imageAligned, %file2save%, General, imageAligned
    IniWrite, % userimgQuality, %file2save%, General, userimgQuality
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
    IniWrite, % isTitleBarHidden, %file2save%, General, isTitleBarHidden
    IniWrite, % animGIFsSupport, %file2save%, General, animGIFsSupport
    IniWrite, % thumbsAratio, %file2save%, General, thumbsAratio
    IniWrite, % thumbsZoomLevel, %file2save%, General, thumbsZoomLevel
    IniWrite, % easySlideStoppage, %file2save%, General, easySlideStoppage
    IniWrite, % version, %file2save%, General, version
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
      {
         isAddedAlready := 1
         Break
      }
  }
  If (isAddedAlready=1)
     Return

  historyList := entry2add "`n" historyList
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
      RandomPicture(0, inLoop)
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
      PrevRandyPicture(0, inLoop)
   } Else inLoop := 0
}

markThisFileNow() {
  If (currentFileIndex=0  || maxFilesIndex<2 || AnyWindowOpen>0)
     Return

  markedSelectFile := (markedSelectFile=currentFileIndex) ? "" : currentFileIndex
  If (thumbsDisplaying=1)
     mainGdipWinThumbsGrid()
  Else
     dummyTimerDelayiedImageDisplay(25)
}

CompareImagesAB() {
  Static prevImgIndex
  If (!markedSelectFile)
     Return
  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (markedSelectFile!=currentFileIndex)
  {
     prevImgIndex := currentFileIndex
     currentFileIndex := markedSelectFile
  } Else If (markedSelectFile=currentFileIndex)
  {
     If !prevImgIndex
        prevImgIndex := currentFileIndex++
     currentFileIndex := prevImgIndex
  }

  r := IDshowImage(currentFileIndex)
  If !r
     informUserFileMissing()
}

DeletePicture() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (markedSelectFile)
     filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

  If (askDeleteFiles=1 || filesElected)
  {
     msgTimer := A_TickCount
     msgInfos := (markedSelectFile>0 && filesElected>1) ? filesElected " files" : "the current file"
     MsgBox, 52, %appTitle%, Are you sure you want to delete %msgInfos% ?
     IfMsgBox, Yes
       good2go := 1

     delayu := filesElected ? 950 : 650
     If (A_TickCount - msgTimer < delayu)
     {
        showTOOLtip("Operation aborted. User answered ""Yes"" too fast.")
        SetTimer, RemoveTooltip, % -msgDisplayTime
        good2go := 0
     }
  } Else good2go := 1

  If (good2go!=1)
     Return

  Sleep, 5
  If (markedSelectFile>0 && filesElected>1)
  {
     showTOOLtip("Moving to recycle bin " filesElected " files, please wait...")
     prevMSGdisplay := A_TickCount
     startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
     Loop, % filesElected
     {
        If GetKeyState("Esc", "P")
        {
           lastLongOperationAbort := A_TickCount
           abandonAll := 1
           Break
        }

        If (A_TickCount - prevMSGdisplay>3500)
        {
           showTOOLtip("Moving to recycle bin " filesRemoved "/" filesElected " files, please wait...")
           prevMSGdisplay := A_TickCount
        }

        thisFileIndex := startPoint + A_Index - 1
        file2rem := resultedFilesList[thisFileIndex]
        file2rem := StrReplace(file2rem, "||")
        FileSetAttrib, -R, %file2rem%
        Sleep, 0
        changeMcursor()
        FileRecycle, %file2rem%
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
        If GetKeyState("Esc", "P")
        {
           lastLongOperationAbort := A_TickCount
           abandonAll := 1
           Break
        }
     }
     Try DllCall("user32\SetCursor", "Ptr", hCursN)
     markedSelectFile := ""
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
     Return
  }

  markedSelectFile := ""
  file2rem := resultedFilesList[currentFileIndex]
  file2rem := StrReplace(file2rem, "||")
  zPlitPath(file2rem, 0, OutFileName, OutDir)
  FileSetAttrib, -R, %file2rem%
  Sleep, 5
  If (move2recycler=1)
     FileRecycle, %file2rem%
  Else
     FileDelete, %file2rem%

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
     showTOOLtip("File deleted...`n" OutFileName "`n" OutDir "\")
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
    If (markedSelectFile)
       filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

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
     If (markedSelectFile)
        filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
     If (filesElected>100)
     {
        MsgBox, 52, %appTitle%, Are you sure you want to rename the selected files?`n`nYou have selected %filesElected% files to be renamed...
        IfMsgBox, Yes
          good2go := 1
   
        If (good2go!=1)
           Return
     }

     CloseWindow()
     overwriteFiles := overwriteConflictingFile
     startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
     showTOOLtip("Renaming " filesElected " files, please wait...`nPattern: " OriginalNewFileName)
     prevMSGdisplay := A_TickCount
     RecentMultiRenamesManager(OriginalNewFileName)
     filezRenamed := countFilez := 0
     Loop, % filesElected
     {
         wasError := 0
         changeMcursor()
         thisFileIndex := startPoint + A_Index - 1
         file2rem := resultedFilesList[thisFileIndex]
         zPlitPath(file2rem, 0, OutFileName, OutDir, fileNamuNoEXT, fileEXTu)
         If !FileExist(file2rem)
            Continue
         If (A_TickCount - prevMSGdisplay>3500)
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
               FileDelete, %OutDir%\%newFileName%
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

         If GetKeyState("Esc", "P")
         {
            lastLongOperationAbort := A_TickCount
            abandonAll := 1
            Break
         }
     }
     Try DllCall("user32\SetCursor", "Ptr", hCursN)
     markedSelectFile := ""
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

    If (markedSelectFile)
    {
       filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
       If (markedSelectFile>0 && filesElected>1)
       {
          batchRenameFiles()
          Return
       }
    }

    Sleep, 2
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
           FileDelete, %OutDir%\%newFileName%
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
      file2rem := resultedFilesList[currentFileIndex]
      file2rem := StrReplace(file2rem, "||")
   }

   defaultu := (dummy="yay") ? file2rem : prevFileSavePath
   If (A_TickCount - lastInvoked < 2500)
      defaultu := prevFileSavePath
   GUI, 1: +OwnDialogs
   FileSelectFile, file2save, S18, % defaultu, Save image as..., Images (*.BMP;*.GIF;*.HDP;*.J2C;*.J2K;*.JFIF;*.JIF;*.JNG;*.JP2;*.JPE;*.JPEG;*.JPG;*.JXR;*.PNG;*.PPM;*.TGA;*.TIF;*.TIFF;*.WDP;*.WEBP;*.XPM)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If !RegExMatch(file2save, saveTypesRegEX)
      {
         Msgbox, 48, %appTitle%, ERROR: Please use a supported file format. Allowed formats: .BMP, .GIF, .HDP, .J2C, .J2K, .JFIF, .JIF, .JNG, .JP2, .JPE, .JPEG, .JPG, .JXR, .PNG, .PPM, .TGA, .TIF, .TIFF, .WDP, .WEBP and .XPM.
         Return
      }

      zPlitPath(file2save, 0, OutFileName, OutDir)
      If (!RegExMatch(file2save, "i)(.\.(bmp|png|tif|tiff|gif|jpg|jpeg))$") && wasInitFIMlib!=1)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: This format is currently unsupported. The FreeImage library failed to properly initialize.`n`n%OutFileName%
         Return
      }

      showTOOLtip("Please wait, saving image...`n" OutFileName)
      If (dummy!="yay")
         file2rem := thumbsCacheFolder "\Current-Clipboard.png"

      prevFileSavePath := OutDir
      writeMainSettings()
      r := coreResizeIMG(file2rem, 0, 0, file2save, 1, 0, 0)
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

   GUI, 1: +OwnDialogs
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
       fileEXT := SubStr(fileNamu, fileEXTpos+1)
       fileNamuNoEXT := RegExReplace(fileNamu, "\.[^.\\/:*?<>|\r\n]+$")
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

    If (markedSelectFile)
       filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

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

   If (markedSelectFile)
   {
      filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
      If (markedSelectFile>0 && filesElected>1)
      {
         batchCopyMoveFile(finalDest)
         Return
      }
   }

   Sleep, 2
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
          FileDelete, %file2save%
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
   If (markedSelectFile)
      filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

   If (A_TickCount - lastInvoked > 29500) || (filesElected>100)
   {
      MsgBox, 52, %appTitle%, Are you sure you want to move the selected files?`n`nYou have selected %filesElected% files to be moved to`n%finalDest%
      IfMsgBox, Yes
        good2go := 1
 
      If (good2go!=1)
         Return
   }

   lastInvoked := A_TickCount
   overwriteFiles := overwriteConflictingFile
   startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
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
      thisFileIndex := startPoint + A_Index - 1
      file2rem := resultedFilesList[thisFileIndex]
      zPlitPath(file2rem, 0, OldOutFileName, OldOutDir)
      If !FileExist(file2rem)
         Continue

      If (OldOutDir=finalDest)
         Continue

      countTFilez++
      If (A_TickCount - prevMSGdisplay>3500)
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
            FileDelete, %file2save%
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

      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
      }
   }
   markedSelectFile := ""
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
   mustDeleteFile := 0
   If (markedSelectFile)
      filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

   If (filesElected>100)
   {
      MsgBox, 52, %appTitle%, Are you sure you want to convert to JPEG %filesElected% files?
      IfMsgBox, Yes
        good2go := 1

      If (good2go!=1)
         Return
   }

   MsgBox, 52, %appTitle%, Do you want to remove the original files after conversion to JPEG? %filesElected% files are marked for this operation.
   IfMsgBox, Yes
     mustDeleteFile := 1

   backCurrentSLD := CurrentSLD
   CurrentSLD := ""
   startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
   showTOOLtip("Converting to JPEG " filesElected " files, please wait...")
   prevMSGdisplay := A_TickCount
   countTFilez := filesConverted := 0
   Loop, % filesElected
   {
      thisFileIndex := startPoint + A_Index - 1
      file2rem := resultedFilesList[thisFileIndex]
      If RegExMatch(file2rem, "i)(.\.(gif|jpg|jpeg))$")
         Continue

      countTFilez++
      If (A_TickCount - prevMSGdisplay>3500)
      {
         showTOOLtip("Converting to JPEG " countTFilez "/" filesElected " files, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
      }
      file2rem := StrReplace(file2rem, "||")
      zPlitPath(file2rem, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)

      Sleep, 1
      changeMcursor()
      pBitmap := LoadBitmapFromFileu(file2rem)
      If !pBitmap
         Continue
      file2save := OutDir "\" OutNameNoExt ".jpg"
      changeMcursor()
      r := Gdip_SaveBitmapToFile(pBitmap, file2save, 80)
      If r
         someErrors := "`nErrors occured during file operations..."
      Else filesConverted++
      If pBitmap
         Gdip_DisposeImage(pBitmap, 1)
      If (mustDeleteFile=1 && !r)
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
      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
      }
   }
   CurrentSLD := backCurrentSLD
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   markedSelectFile := ""
   prevStartIndex := -1
   dummyTimerDelayiedImageDisplay(100)
   If (abandonAll=1)
   {
      showTOOLtip("Operation aborted. "  filesConverted " out of " filesElected " selected files were converted to JPEG" someErrors)
      SoundBeep , 300, 100
   } Else
   {
      showTOOLtip("Finished converting to JPEG "  filesConverted " out of " filesElected " selected files" someErrors)
      SoundBeep , 900, 100
   }
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

convert2jpeg() {
  Critical, on
  Static asku := "a", mustDeleteFile := 0
  If (currentFileIndex=0)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (markedSelectFile)
  {
     filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
     If (markedSelectFile>0 && filesElected>1)
     {
        batchConvert2jpeg()
        Return
     }
  }

  file2rem := resultedFilesList[currentFileIndex]
  If RegExMatch(file2rem, "i)(.\.(gif|jpg|jpeg))$")
     Return

  file2rem := StrReplace(file2rem, "||")
  zPlitPath(file2rem, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
  Sleep, 1
  changeMcursor()
  pBitmap := LoadBitmapFromFileu(file2rem)
  file2save := OutDir "\" OutNameNoExt ".jpg"
  changeMcursor()
  r := Gdip_SaveBitmapToFile(pBitmap, file2save, 80)
  If pBitmap
     Gdip_DisposeImage(pBitmap, 1)

  If r
  {
     showTOOLtip("Failed to convert file...`n" OutFileName "`n" OutDir "\")
     SoundBeep , 300, 100
  } Else showTOOLtip("File converted succesfully to JPEG...`n" OutNameNoExt ".jpg`n" OutDir)

  Try DllCall("user32\SetCursor", "Ptr", hCursN)
  SetTimer, RemoveTooltip, % -msgDisplayTime
  If (asku="a" && !r)
  {
     asku := 1
     MsgBox, 52, %appTitle%, File converted succesfully.`n`nDo you want to remove original file?`n`n%OutFileName%`n`nThis question will be asked once in this session. The same answer will be assumed through-out this session.
     IfMsgBox, Yes
       mustDeleteFile := 1
  }

  If (mustDeleteFile=1 && !r)
  {
     FileSetAttrib, -R, %file2rem%
     If (move2recycler=1)
        FileRecycle, %file2rem%
     Else
        FileDelete, %file2rem%
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

   GUI, 1: +OwnDialogs
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
  markedSelectFile := ""
  prevRandyIMGnow := 0
  resultedFilesList := []
  maxFilesIndex := 0
  prevStartIndex := -1
  currentFileIndex := 1
}

coreOpenFolder(thisFolder, doOptionals:=1) {
   testThis := StrReplace(thisFolder, "|")
   testThis := FileExist(testThis)
   If (StrLen(thisFolder)>3 && InStr(testThis, "D"))
   {
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

RefreshImageFile() {
   disposeCacheIMGs()
   r := IDshowImage(currentFileIndex)
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

    GUI, 1: +OwnDialogs
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
    FileSelectFile, SelectImg, M1, % startPath, % winTitle, %pattern%
    if (!SelectImg || ErrorLevel)
       Return

    Loop, Parse, SelectImg, `n
    {
       If (A_Index=1)
          SelectedDir := A_LoopField
       Else if (A_Index=2)
          imgpath = %SelectedDir%\%A_LoopField%
       Else if (A_Index>2)
          Break
    }

   if (SelectedDir)
   {
      newStaticFoldersListCache := ""
      prevOpenFolderPath := SelectedDir
      writeMainSettings()
      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      If !RegExMatch(imgpath, RegExFilesPattern)
         Return
      coreOpenFolder("|" SelectedDir, 0)
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
   }
}

addNewFile2list() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    GUI, 1: +OwnDialogs
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

    GUI, 1: +OwnDialogs
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

detectFileID(imgpath) {
    Loop, % maxFilesIndex + 1
    {
       r := resultedFilesList[A_Index]
       If (r=imgpath)
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

   if (imgpath)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()
      zPlitPath(imgpath, 0, OutFileName, OutDir)
 
      If !OutDir
         Return

      CloseWindow()
      showTOOLtip("Opening file...`n" imgpath)
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

GetImgFileDimension(imgpath, ByRef W, ByRef H, fastWay:=1) {
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
   pBitmap := LoadBitmapFromFileu(imgpath, 0, fastWay)
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
    lol := "`%`%1"
    batch =
    (Ltrim
       assoc .sld=SlideShow
       ftype SlideShow="%A_ScriptFullPath%" "%lol%"
    )

    FileAppend, %batch%, %A_ScriptDir%\assocu.bat
    RunWait, *RunAs %A_ScriptDir%\assocu.bat
    Sleep, 50
    FileDelete, %A_ScriptDir%\assocu.bat
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
   Static wasCreated, lastInvoked := 1
   If (AnyWindowOpen)
   {
      If (A_TickCount - lastInvoked < 950)
         CloseWindow()
      Else
         WinActivate, ahk_id %hSetWinGui%
      lastInvoked := A_TickCount
      Return
   }

   Global lastWinDrag := A_TickCount
   ForceRegenStaticFolders := 0
   If (wasCreated=1)
   {
      Menu, PVmenu, Delete
      Menu, PVsliMenu, Delete
      Menu, PVnav, Delete
      Menu, PVview, Delete
      Menu, PVfList, Delete
      Menu, PVtFile, Delete
      Menu, PVprefs, Delete
      Menu, PVopenF, Delete
      Menu, PVsort, Delete
      Menu, PVselv, Delete
   }

   sliSpeed := Round(slideShowDelay/1000, 2) " sec."
   Menu, PVsliMenu, Add, &Start slideshow`tSpace, ToggleSlideShowu
   Menu, PVsliMenu, Add, &Easy slideshow stopping, ToggleEasySlideStop
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Toggle slideshow mode`tS, SwitchSlideModes
   Menu, PVsliMenu, Add, % DefineSlideShowType(), SwitchSlideModes
   Menu, PVsliMenu, Disable, % DefineSlideShowType()
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Increase speed`tComma [`,], IncreaseSlideSpeed
   Menu, PVsliMenu, Add, &Decrease speed`tDot [.], DecreaseSlideSpeed
   Menu, PVsliMenu, Add, Current speed: %sliSpeed%, DecreaseSlideSpeed
   Menu, PVsliMenu, Disable, Current speed: %sliSpeed%
   If (easySlideStoppage=1)
      Menu, PVsliMenu, Check, &Easy slideshow stopping

   infolumosAdjust := (imgFxMode=2 || imgFxMode=3) ? Round(lumosAdjust, 2) : Round(lumosGrayAdjust, 2)
   infoGammosAdjust := (imgFxMode=2 || imgFxMode=3) ? Round(GammosAdjust, 2) : Round(GammosGrayAdjust, 2)
   infoSatAdjust := Round(satAdjust*100)
   infoThumbsMode := (thumbsDisplaying=1) ? "Switch to image view" : "Switch to thumbnails list"
   If (maxFilesIndex>1)
   {
      Menu, PVview, Add,  %infoThumbsMode%`tEnter/MClick, ToggleThumbsMode
      Menu, PVview, Add,
   }

   If (thumbsDisplaying=1)
   {
      infoThumbZoom := thumbsW "x" thumbsH " (" Round(thumbsZoomLevel*100) "%)"
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
      Menu, PVview, Add, Image &alignment: %imageAligned%`tA, ToggleIMGalign
      Menu, PVview, Add, % defineImgAlign(), ToggleIMGalign
      Menu, PVview, Disable, % defineImgAlign()
      Menu, PVview, Add,
      Menu, PVview, Add, &Toggle Resizing Mode`tT, ToggleImageSizingMode
      Menu, PVview, Add, % DefineImgSizing(), ToggleImageSizingMode
      Menu, PVview, Disable, % DefineImgSizing()
      If (IMGresizingMode=4)
         Menu, PVview, Disable, Image &alignment: %imageAligned%`tA
   }
   Menu, PVview, Add,
   Menu, PVview, Add, &Switch colors display`tF, ToggleImgFX
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
      Menu, PVview, Add, Image view panel`tU, ColorsAdjusterPanelWindow
      Menu, PVview, Add, Reset image vie&w`t\, ResetImageView
      Menu, PVview, Add,
      Menu, PVview, Add, &Show selection`tD, toggleImgSelection
      If (activateImgSelection=1)
         Menu, PVview, Check, &Show selection`tD
      If (FlipImgV=1)
         Menu, PVview, Check, Mirror &vertically`tV
 
      If (FlipImgH=1)
         Menu, PVview, Check, Mirror &horizontally`tH
   }
   Menu, PVnav, Add, &First`tHome, FirstPicture
   Menu, PVnav, Add, &Previous`tRight, PreviousPicture
   Menu, PVnav, Add, &Next`tLeft, NextPicture
   Menu, PVnav, Add, &Last`tEnd, LastPicture
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Jump at #`tCtrl+J, Jump2index
   Menu, PVnav, Add, &Random`tR, RandomPicture
   Menu, PVnav, Add, &Prev. random image`tBackspace, PrevRandyPicture

   Menu, PVselv, Add, &Show selection`tD, toggleImgSelection
   If (activateImgSelection=1)
      Menu, PVselv, Check, &Show selection`tD
   Menu, PVselv, Add, &Edit selection`tE, editImgSelection
   If (editingSelectionNow=1)
      Menu, PVselv, Check, &Edit selection`tE
   Menu, PVselv, Add, &Drop selection`tCtrl+D, resetImgSelection
   Menu, PVselv, Add, &Reset selection, newImgSelection
   Menu, PVselv, Add, 
   Menu, PVselv, Add, &Copy to Clipboard`tCtrl+C, CopyImage2clip

   StringRight, infoPrevMovePath, prevFileMovePath, 25
   If (activateImgSelection!=1)
   {
      Menu, PVtFile, Add, &Copy image to Clipboard`tCtrl+C, CopyImage2clip
      Menu, PVtFile, Add, 
   }
   Menu, PVtFile, Add, &Open (with external app)`tO, OpenThisFile
   Menu, PVtFile, Add, &Open containing folder`tCtrl+E, OpenThisFileFolder
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, Mar&k this file`tTab, markThisFileNow
   If (markedSelectFile=currentFileIndex)
      Menu, PVtFile, Check, Mar&k this file`tTab

   If markedSelectFile
      Menu, PVtFile, Add, Compare this file with marked file`tB, CompareImagesAB

   file2rem := resultedFilesList[currentFileIndex]
   If !RegExMatch(file2rem, "i)(.\.(gif|jpg|jpeg))$")
      Menu, PVtFile, Add, &Convert to JPEG`tCtrl+K, convert2jpeg
   If RegExMatch(file2rem, "i)(.\.(jpg|jpeg))$")
      Menu, PVtFile, Add, &JPEG lossless operations`tK, PanelJpegPerformOperation
   Menu, PVtFile, Add, &Resize/crop image`tCtrl+R, ResizeImagePanelWindow
   Menu, PVtFile, Add, &Delete`tDelete, DeletePicture
   Menu, PVtFile, Add, &Rename`tF2, RenameThisFile
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Move file to...`tM, InvokeMoveFiles
   Menu, PVtFile, Add, &Copy file to...`tC, InvokeCopyFiles
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Information`tI, ShowImgInfosPanel

   Menu, PVsort, Add, &Path and name, ActSortName
   Menu, PVsort, Add, &File size, ActSortSize
   Menu, PVsort, Add, &Modified date, ActSortModified
   Menu, PVsort, Add, &Created date, ActSortCreated
   Menu, PVsort, Add, &Resolution (very slow), ActSortResolution
   Menu, PVsort, Add, 
   Menu, PVsort, Add, R&everse, ReverseListNow
   Menu, PVsort, Add, R&andomize, RandomizeListNow

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
   If (maxFilesIndex>2)
   {
      Menu, PVfList, Add, Insert file(s)`tInsert, addNewFile2list
      Menu, PVfList, Add, Add folder(s)`tShift+Insert, addNewFolder2list
      Menu, PVfList, Add, Manage folder(s) list`tAlt+U, DynamicFolderzPanelWindow
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

   Menu, PVprefs, Add, Save settings into .SLD, WritePrefsIntoSLD
   If A_IsCompiled
      Menu, PVprefs, Add, Associate with .SLD files, associateSLDsNow

   Menu, PVprefs, Add, 
   Menu, PVprefs, Add, &Always on top, ToggleAllonTop
   Menu, PVprefs, Add, &Hide title bar, ToggleTitleBaru
   Menu, PVprefs, Add, &No OSD information, ToggleInfoToolTips
   Menu, PVprefs, Add, &Large UI fonts, ToggleLargeUIfonts
   Menu, PVprefs, Add, &High quality resampling, ToggleImgQuality
   Menu, PVprefs, Add, &Load Camera RAW files in high quality, ToggleRAWquality
   Menu, PVprefs, Add, &Load any image format using FreeImage, ToggleAlwaysFIMus
   Menu, PVprefs, Add, 
   If (thumbsDisplaying!=1)
   {
      Menu, PVprefs, Add, An&imated GIFs support (experimental), ToggleAnimGIFsupport
      Menu, PVprefs, Add, &Touch screen mode, ToggleTouchMode
      If (animGIFsSupport=1)
         Menu, PVprefs, Check, An&imated GIFs support (experimental)
      If (TouchScreenMode=1)
         Menu, PVprefs, Check, &Touch screen mode
   }
   Menu, PVprefs, Add, 
   If InStr(FileExist(thumbsCacheFolder), "D")
      Menu, PVprefs, Add, Erase cached thumbnails, OlderThanEraseThumbsCache
   Menu, PVprefs, Add, Cache / store generated thumbnails, ToggleThumbsCaching
   If (userHQraw=1)
      Menu, PVprefs, Check, &Load Camera RAW files in high quality
   If (alwaysOpenwithFIM=1)
      Menu, PVprefs, Check, &Load any image format using FreeImage
   If (enableThumbsCaching=1)
      Menu, PVprefs, Check, Cache / store generated thumbnails
   Menu, PVprefs, Add, &Skip missing files, ToggleSkipDeadFiles
   Menu, PVprefs, Add, 
   Menu, PVprefs, Add, &Prompt before file delete, TogglePromptDelete
   Menu, PVprefs, Add, &Ignore stored SLD settings, ToggleIgnoreSLDprefs
   If (askDeleteFiles=1)
      Menu, PVprefs, Check, &Prompt before file delete
   If (MustLoadSLDprefs=0)
      Menu, PVprefs, Check, &Ignore stored SLD settings
   If (PrefsLargeFonts=1)
      Menu, PVprefs, Check, &Large UI fonts
   If (userimgQuality=1)
      Menu, PVprefs, Check, &High quality resampling
   If (skipDeadFiles=1)
      Menu, PVprefs, Check, &Skip missing files
   If (isAlwaysOnTop=1)
      Menu, PVprefs, Check, &Always on top
   If (noTooltipMSGs=1)
      Menu, PVprefs, Check, &No OSD information
   If (getCaptionStyle()=1)
      Menu, PVprefs, Check, &Hide title bar

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
      If !InStr(A_LoopField, "|") && !RegExMatch(A_LoopField, "i)(\.sld)$")
         entryu := "(R) " entryu
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

   clippyTest := resultedFilesList[0]
   Menu, PVmenu, Add, &Open..., :PVopenF
   If (currentFileIndex=0 && InStr(clippyTest, "Current-Clipboard"))
      Menu, PVmenu, Add, &Save image...`tCtrl+S, SaveClipboardImage
   Menu, PVmenu, Add,
   If (thumbsDisplaying!=1 && activateImgSelection!=1 && imgSelX2=-1 && imgSelY2=-1 && CurrentSLD)
      Menu, PVmenu, Add, Create selection`tE, newImgSelection
   Else If (thumbsDisplaying!=1 && activateImgSelection!=1 && CurrentSLD)
      Menu, PVmenu, Add, Edit selection`tE, editImgSelection
   If (maxFilesIndex>0 && CurrentSLD)
   {
      If (thumbsDisplaying!=1 && activateImgSelection=1 && thumbsDisplaying!=1)
         Menu, PVmenu, Add, Selec&tion, :PVselv
      Menu, PVmenu, Add, C&urrent file, :PVtFile
      Menu, PVmenu, Add, Files l&ist, :PVfList
      If (thumbsDisplaying=1 && maxFilesIndex>1)
         Menu, PVmenu, Add, &Sort by, :PVsort
      Menu, PVmenu, Add, Vie&w, :PVview
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
      Menu, PVmenu, Add, Vie&w, :PVview
   }

   Menu, PVmenu, Add, Prefe&rences, :PVprefs
   If markedSelectFile
      Menu, PVmenu, Add, Dro&p files selections, dropFilesSelect
   Menu, PVmenu, Add, About, AboutWindow
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, Restart`tShift+Esc, restartAppu
   Menu, PVmenu, Add, &Exit`tEsc, Cleanup
   wasCreated := 1

   o_isTitleBarHidden := isTitleBarHidden
   isTitleBarHidden := 0
   Suspend, On
   Menu, PVmenu, Show
   Suspend, Off
   Global lastWinDrag := A_TickCount
   Global lastOtherWinClose := A_TickCount
   isTitleBarHidden := o_isTitleBarHidden
}

dropFilesSelect() {
   markedSelectFile := ""
   dummyTimerDelayiedImageDisplay(50)
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

ToggleAlwaysFIMus() {
   alwaysOpenwithFIM := !alwaysOpenwithFIM
   initFIMGmodule()
   If (FIMfailed2init=1)
      Msgbox, 48, %appTitle%, ERROR: The FreeImage library failed to properly initialize. Various image file formats will no longer be supported.
   writeMainSettings()
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
        editImgSelection()
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
    writeMainSettings()
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
   Static FXmodesLabels := {2:"cP", 3:"cA", 4:"cG", 5:"cR", 6:"cG", 7:"cB", 8:"cI"}

   If StrLen(usrFilesFilteru)>1
      winPrefix .= "F "

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

drawWelcomeImg(goAgain:=0) {
    If (maxFilesIndex>0 || StrLen(CurrentSLD)>1 || AnyWindowOpen>0)
       Return

    If (A_TickCount - scriptStartTime>3000)
    {
       If (identifyThisWin()!=1)
          Return
    }

    GetClientSize(mainWidth, mainHeight, PVhwnd)
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetInterpolationMode(G, 5)
    Gdip_SetSmoothingMode(G, 5)
    pBr1 := Gdip_BrushCreateSolid(0x33882211)
    pBr3 := Gdip_BrushCreateSolid(0x33118822)
    pBr2 := Gdip_BrushCreateSolid(0x33112288)
    pBr4 := Gdip_BrushCreateSolid(0x77030201)
    pBr5 := Gdip_BrushCreateSolid(0x88939291)
    If GetKeyState("CapsLock", "T")
       Gdip_FillRectangle(G, pBr5, 0, 0, mainWidth, mainHeight)
    dummyPos := (A_OSVersion!="WIN_7") ? 1 : ""
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
          Gdip_FillRectangle(G, pBr%tBrsh%, xPos, yPos, w, h)
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
          Gdip_FillEllipse(G, pBr%tBrsh%, xPos, yPos, w, h)
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
          Gdip_FillEllipse(G, pBr%tBrsh%, xPos, yPos, w, h)
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
          Gdip_FillRectangle(G, pBr%tBrsh%, xPos, yPos, w, h)
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
          Gdip_FillRectangle(G, pBr%tBrsh%, xPos, yPos, w, h)
       }
    }
    If !GetKeyState("Shift", "P")
       Gdip_FillRectangle(G, pBr4, 0, 0, mainWidth, mainHeight)
    r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    Gdip_DeleteBrush(pBr1)
    Gdip_DeleteBrush(pBr2)
    Gdip_DeleteBrush(pBr3)
    Gdip_DeleteBrush(pBr4)
    Gdip_DeleteBrush(pBr5)
    SetTimer, drawWelcomeImg, -3000
}

BuildGUI() {
   Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialwh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3
   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Add, Text, x1 y1 w1 h1 BackgroundTrans gWinClickAction vPicOnGui1 hwndhPicOnGui1,
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
   drawWelcomeImg("yay")
}

updateUIctrl() {
   GetClientSize(GuiW, GuiH, PVhwnd)
   ctrlW := GuiW//5
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

destroyGDIwin() {
   DestroyGDIbmp()
   Gui, 2: Destroy
   winGDIcreated := 0
}

createGDIwin() {
   Critical, on
   Sleep, 15
   ; destroyGDIwin()
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
     imageLoading := 0
  Else If (imageLoading=1)
     SetTimer, ResetImgLoadStatus, -50
}

ShowTheImage(imgpath, usePrevious:=0) {
   Critical, on
   Static prevImgPath, lastInvoked2 := 1, counteru
        , lastInvoked := 1, prevPicCtrl := 1

   WinGet, winStateu, MinMax , ahk_id %PVhwnd%
   If (winStateu=-1)
      Return

   startZeitIMGload := A_TickCount
   SetTimer, ResetImgLoadStatus, Off
   ThisPrev := (usePrevious=2 || usePrevious=4) ? 1 : 0
   If (imgpath=prevImgPath && StrLen(prevImgPath)>3 && ThisPrev!=1)
      usePrevious := 1

   If (usePrevious=2 || usePrevious=4)  ; force no caching
   {
      If (usePrevious=4)
         prevImgPath := wasForcedHigh := 1
      usePrevious := 0
   }

   If (usePrevious!=1 && thumbsDisplaying!=1)
   {
      If (A_TickCount - prevGUIresize<900)
         GdipCleanMain(2)
   }

   FileGetSize, fileSizu, %imgpath%
   zPlitPath(imgpath, 0, OutFileName, OutDir)
   If (IMGresizingMode=4)
      zoomu := " [" Round(zoomLevel * 100) "%]"
   winTitle := currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir "\"

   If (thumbsDisplaying=1)
   {
      If (markedSelectFile)
         filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
      If (filesElected>1)
         filesSelInfo := "[ " filesElected " ] "

      SetTimer, UpdateThumbsScreen, -10
      WinSetTitle, ahk_id %PVhwnd%,, % filesSelInfo "THUMBS: " winTitle
      If (imageLoading=1)
         SetTimer, ResetImgLoadStatus, -15
      Return
   }

   If !gdiBitmap
   {
      usePrevious := 0
      wasForcedHigh := 1
   }

   If (!FileExist(imgpath) && !fileSizu && usePrevious=0)
   {
      If (WinActive("A")=PVhwnd)
      {
         winTitle := "[*] " winTitle
         WinSetTitle, ahk_id %PVhwnd%,, % winTitle
         showTOOLtip("ERROR: Unable to load file...`n" OutFileName "`n" OutDir "\")
         SetTimer, RemoveTooltip, % -msgDisplayTime
      }

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

   If (A_TickCount - lastInvoked>85) && (A_TickCount - lastInvoked2>85) || (usePrevious=1) || (wasForcedHigh=1)
   {
       lastInvoked := A_TickCount
       r2 := ResizeImageGDIwin(imgpath, usePrevious, wasForcedHigh)
       If !r2
       {
          If (WinActive("A")=PVhwnd)
          {
             showTOOLtip("ERROR: Unable to display the image...")
             SetTimer, RemoveTooltip, % -msgDisplayTime
          }
          SoundBeep, 300, 100
          SetTimer, ResetImgLoadStatus, -15
          Return "fail"
       } Else prevImgPath := imgpath
       lastInvoked := A_TickCount
   } Else ; If (wasForcedHigh!=1)
   {
       If (noTooltipMSGs=1)
          SetTimer, RemoveTooltip, Off
       winPrefix := defineWinTitlePrefix()
       WinSetTitle, ahk_id %PVhwnd%,, % winPrefix winTitle
       delayu := (A_TickCount - prevFastDisplay < 500) ? 90 : 290
       dummyTimerReloadThisPicture(delayu)
   }
   SetTimer, ResetImgLoadStatus, -15
   lastInvoked2 := A_TickCount
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
  If (slideShowRunning!=1) && (A_TickCount - lastInvoked > 100)
  {
     DllCall("user32\SetCursor", "Ptr", hCursBusy)
     lastInvoked := A_TickCount
  }
}

ResizeImageGDIwin(imgpath, usePrevious, wasForcedHigh) {
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
       MD5name := generateThumbName(imgpath)
       file2load := thumbsCacheFolder "\big-" o_bwDithering userHQraw MD5name ".jpg"
       cachedImgFile := FileExist(file2load) ? 1 : 0
    } Else cachedImgFile := 0

    IDthisImgPath := imgpath "-" cachedImgFile o_bwDithering userHQraw
    If (imgpath!=prevImgPath || IDthisImgPath!=IDprevImgPath || !gdiBitmap || wasForcedHigh=1)
    {
       mustReloadIMG := (IDthisImgPath!=IDprevImgPath && cachedImgFile=1 && imgpath=prevImgPath) ? 1 : 0
       If (IDthisImgPath!=IDprevImgPath && cachedImgFile=0 && imgpath=prevImgPath)
          GdipCleanMain(2)
       disposeCacheIMGs()
       If (A_TickCount - lastTitleChange>400)
          changeMcursor()
       r1 := CloneMainBMP(imgpath, oImgW, oImgH, CountFrames, mustReloadIMG)
       If (CountFrames=0 && imgFxMode=3 && r1!="error")
          AdaptiveImgLight(gdiBitmap, imgpath, oImgW, oImgH)
    }

    If ((IMGresizingMode=1 || IMGresizingMode=2) && enableThumbsCaching=1)
    {
       cachedImgFile := FileExist(file2load) ? 1 : 0
       IDthisImgPath := imgpath "-" cachedImgFile
    }

    If (!gdiBitmap || ErrorLevel || r1="error")
    {
       prevImgPath := ""
       GdipCleanMain(1)
       SetTimer, ResetImgLoadStatus, -15
       SoundBeep, 300, 900
       Return 0
    }

   prevImgPath := imgpath
   IDprevImgPath := imgpath "-" cachedImgFile o_bwDithering userHQraw
   GetClientSize(GuiW, GuiH, PVhwnd)
   If (usePrevious!=1)
   {
      imgW := oImgW
      imgH := oImgH
   } Else If (usePrevious=1 || mustReloadIMG=1 || wasForcedHigh=1)
   {
      actionu := (mustReloadIMG=1 || wasForcedHigh=1) ? 1 : 0
      RescaleBMPtiny(imgpath, oImgW, oImgH, tinyW, tinyH, actionu)
      imgW := tinyW
      imgH := tinyH
      wscale := oImgW / tinyW
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
         GetImgFileDimension(imgpath, roImgW, roImgH)
      } Else
      {
         roImgW := oImgW, roImgH := oImgH
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

   IMGlargerViewPort := ((ResizedH-5>GuiH+1) || (ResizedW-5>GuiW+1)) ? 1 : 0
   If (noTooltipMSGs=1)
      SetTimer, RemoveTooltip, Off

   zPlitPath(imgpath, 0, OutFileName, OutDir)
   winPrefix := defineWinTitlePrefix()
   winTitle := winPrefix currentFileIndex "/" maxFilesIndex " [" ws "] " OutFileName " | " OutDir "\"
   If (A_TickCount - lastTitleChange>400)
      WinSetTitle, ahk_id %PVhwnd%,, % "Please wait... "  OutFileName " | " OutDir "\" 

   ResizedW := Round(ResizedW)
   ResizedH := Round(ResizedH)
   If (A_TickCount - lastTitleChange>400)
      changeMcursor()

   r := QPV_ShowImgonGui(roImgW, roImgH, oImgW, oImgH, ws, imgW, imgH, ResizedW, ResizedH, GuiW, GuiH, usePrevious, imgpath, CountFrames, wasForcedHigh)
   delayu := (A_TickCount - prevFastDisplay < 300) ? 90 : 550
   If (usePrevious=1)
      dummyTimerReloadThisPicture(delayu)

   If (markedSelectFile)
      filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
   If (filesElected>1)
      filesSelInfo := "[ " filesElected " ] "

   WinSetTitle, ahk_id %PVhwnd%,, % filesSelInfo winTitle
   lastTitleChange := A_TickCount
   SetTimer, ResetImgLoadStatus, -15
   Return r
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

RescaleBMPtiny(imgpath, imgW, imgH, ByRef ResizedW, ByRef ResizedH, wasForcedHigh) {
  Critical, on
  ; one quarter resolution
  Static prevImgPath, prevResizedW, prevResizedH
  If (imgpath=prevImgPath && gdiBitmapSmall && wasForcedHigh!=1)
  {
     ResizedW := prevResizedW
     ResizedH := prevResizedH
     Return
  }

  If gdiBitmapSmall
     gdiBitmapSmall := Gdip_DisposeImage(gdiBitmapSmall, 1)

  If (imgW//3>ResolutionWidth//2) || (imgH//3>ResolutionHeight//2)
  {
     calcImgSize(1, imgW, imgH, ResolutionWidth//2, ResolutionHeight//2, ResizedW, ResizedH)
  } Else
  {
     ResizedW := Round(imgW//3) + 2
     ResizedH := Round(imgH//3) + 2
  }
  prevResizedW := ResizedW
  prevResizedH := ResizedH
  gdiBitmapSmall := Gdip_CreateBitmap(ResizedW, ResizedH)
  G2 := Gdip_GraphicsFromImage(gdiBitmapSmall)
  thisImgQuality := (userimgQuality=1) ? 3 : 5
  Gdip_SetInterpolationMode(G2, thisImgQuality)
  Gdip_SetSmoothingMode(G2, 3)
  changeMcursor()
  Gdip_DrawImage(G2, gdiBitmap, 0, 0, ResizedW, ResizedH, 0, 0, imgW, imgH)
  Gdip_DeleteGraphics(G2)
  prevImgPath := imgpath
}

getGIFframesCount(whichImg) {
    DllCall("gdiplus\GdipImageGetFrameDimensionsCount", "UInt", whichImg, "UInt*", Countu)
    VarSetCapacity(dIDs,16,0)
    DllCall("gdiplus\GdipImageGetFrameDimensionsList", "UInt", whichImg, "Uint", &dIDs, "UInt", Countu)
    DllCall("gdiplus\GdipImageGetFrameCount", "UInt", whichImg, "Uint", &dIDs, "UInt*", CountFrames)
    Return CountFrames
}

SaveFIMfile(file2save, pBitmap) {
  initFIMGmodule()
  If !wasInitFIMlib
     Return 1

  hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
  Gdip_GetImageDimensions(pBitmap, imgW, imgH)
  hFIFimgA := FreeImage_Allocate(imgW, imgH, 32)
  pBits := FreeImage_GetBits(hFIFimgA)
  bitmapInfo := FreeImage_GetInfo(hFIFimgA)
  hdc := DllCall("GetDC", "UInt", hGDIwin)
  bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgA)
  r1 := Gdip_GetDIBits(hdc, hBitmap, 0, imgH, pBits, bitmapInfo, 2)
  DeleteDC(hdc)
  r2 := DeleteObject(hBitmap)
  If RegExMatch(file2save, "i)(.\.(gif|jng|jif|jfif|jpg|jpe|jpeg|ppm|wbm|xpm))$")
  {
     hFIFimgB := FreeImage_ConvertTo(hFIFimgA, "24Bits")
     r3 := FreeImage_Save(hFIFimgB, file2save)
     FreeImage_UnLoad(hFIFimgB)
  } Else r3 := FreeImage_Save(hFIFimgA, file2save)

  FreeImage_UnLoad(hFIFimgA)
  Return !r3
}

initFIMGmodule() {
  If (wasInitFIMlib!=1)
  {
     r := FreeImage_FoxInit(True) ; Load the FreeImage Dll
     wasInitFIMlib := r ? 1 : 0
  }

  If !wasInitFIMlib
     bwDithering := alwaysOpenwithFIM := 0
  FIMfailed2init := (wasInitFIMlib=1) ? 0 : 1
}

FreeImageLoader(imgpath, doBw, noBPPconv) {
  sTime := A_tickcount  
  initFIMGmodule()
  If !wasInitFIMlib
     Return

  noPixels := (noBPPconv=1) ? -1 : 0
  GFT := FreeImage_GetFileType(ImgPath)
  If (GFT=34 && noPixels=0)
     noPixels := (userHQraw=1 && thumbsDisplaying=0) ? 0 : 5

  changeMcursor()
  hFIFimgA := FreeImage_Load(imgpath, GFT, noPixels) ; load image
  imgBPP := FreeImage_GetBPP(hFIFimgA)
  imgBPP2 := Trim(StrReplace(imgBPP, "-"))
  If (imgBPP2>32)
  {
     isThisHDRimg := (GFT=34) ? "R" userHQraw : "H"
     changeMcursor()
     If (noBPPconv=0)
        hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)
  } Else isThisHDRimg := 0

  changeMcursor()
  If (bwDithering=1 && imgFxMode=4 && doBw=1)
     hFIFimgZ := hFIFimgB ? FreeImage_Dither(hFIFimgB, 0) : FreeImage_Dither(hFIFimgA, 0)
  Else
     hFIFimgZ := hFIFimgB ? hFIFimgB : hFIFimgA

  hFIFimgC := hFIFimgZ ? hFIFimgZ : hFIFimgA
  If (noBPPconv=0)
  {
     pBits := FreeImage_GetBits(hFIFimgC)
     bitmapInfo := FreeImage_GetInfo(hFIFimgC)
     bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgC)
     hdc := DllCall("GetDC", "UInt", hGDIwin)
     changeMcursor()
     hBITMAP := Gdip_CreateDIBitmap(hDC, bmpInfoHeader, 4, pBits, bitmapInfo, 0)
     pBitmap := Gdip_CreateBitmapFromHBITMAP(hBitmap)
     DeleteDC(hdc)
     r2 := DeleteObject(hBitmap)
  } Else
  {
     imgW := FreeImage_GetWidth(hFIFimgC)
     imgH := FreeImage_GetHeight(hFIFimgC)
     pBitmap := Gdip_CreateBitmap(imgW, imgH)
  }
  ; Gdip_GetImageDimensions(pBitmap, imgW2, imgH2)
  imgIDs := hFIFimgA "|" hFIFimgB "|" hFIFimgC "|" hFIFimgZ
  Sort, imgIDs, UD|
  Loop, Parse, imgIDs, |
      If A_LoopField
         FreeImage_UnLoad(A_LoopField)

  eTime := A_tickcount - sTime
  ; ToolTip, % imgW ", " imgW2,,,2
  ; Tooltip, % etime "; " noPixels "; " GFT
  ; Tooltip, %r1% -- %r2% -- %pBits% ms ---`n %pbitmap% -- %hbitmap% -- %hfifimg%

  Return pBitmap
}

LoadBitmapFromFileu(imgpath, doBw:=0, noBPPconv:=0) {
  If RegExMatch(imgpath, RegExFIMformPtrn) || (alwaysOpenwithFIM=1)
  || (bwDithering=1 && imgFxMode=4 && doBw=1)
  {
     oBitmap := FreeImageLoader(imgpath, doBw, noBPPconv)
  } Else
  {
     oBitmap := Gdip_CreateBitmapFromFile(imgpath)
     isThisHDRimg := 0
  }
  Return oBitmap
}

CloneMainBMP(imgpath, ByRef imgW, ByRef imgH, ByRef CountFrames, mustReloadIMG) {
  Critical, on
  Static AprevImgCall, BprevImgCall

  CountFrames := 0
  cachedImgFile := 0
  FileGetSize, fileSizu, % imgpath, K
  FileGetTime, FileDateM, % imgpath, M
  o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
  thisImgCall := imgpath o_bwDithering fileSizu FileDateM cachedImgFile
  If gdiBitmap
     gdiBitmap := Gdip_DisposeImage(gdiBitmap, 1)

  ignoreCache := (RegExMatch(imgpath, "i)(.\.gif)$") && animGIFsSupport=1) ? 1 : mustReloadIMG
  If (AprevImgCall=thisImgCall && AprevGdiBitmap && ignoreCache=0)
  {
     Gdip_GetImageDimensions(AprevGdiBitmap, imgW, imgH)
     gdiBitmap := Gdip_CloneBitmapArea(AprevGdiBitmap, 0, 0, imgW, imgH)
     Return 
  } Else If (BprevImgCall=thisImgCall && BprevGdiBitmap && ignoreCache=0)
  {
     Gdip_GetImageDimensions(BprevGdiBitmap, imgW, imgH)
     gdiBitmap := Gdip_CloneBitmapArea(BprevGdiBitmap, 0, 0, imgW, imgH)
     Return
  }

  If ((IMGresizingMode=1 || IMGresizingMode=2) && enableThumbsCaching=1)
  {
     o_bwDithering := (imgFxMode=4 && bwDithering=1) ? 1 : 0
     MD5name := generateThumbName(imgpath)
     file2load := thumbsCacheFolder "\big-" o_bwDithering userHQraw MD5name ".jpg"
     cachedImgFile := FileExist(file2load) ? 1 : 0
     If (cachedImgFile=1)
        imgpath := file2load
  } Else cachedImgFile := 0

  changeMcursor()
  oBitmap := LoadBitmapFromFileu(imgpath, 1)
  If !oBitmap
     Return "error"

  factoru := (isThisHDRimg!=0) ? 1.45 : 2.45
  slowLoaded := (A_TickCount - startZeitIMGload>1500) ? 1 : 0
  Gdip_GetImageDimensions(oBitmap, imgW, imgH)
  If RegExMatch(imgpath, "i)(.\.gif)$") && (animGIFsSupport=1)
  {
     CountFrames := getGIFframesCount(oBitmap)
  } Else If (slowLoaded=1 || imgW>ResolutionWidth*factoru || imgH>ResolutionHeight*factoru) && (enableThumbsCaching=1 
    && !FileExist(file2load) && (IMGresizingMode=1 || IMGresizingMode=2))
  {
     If !InStr(FileExist(thumbsCacheFolder), "D")
     {
        FileCreateDir, %thumbsCacheFolder%
        If ErrorLevel
           skippedBeats := 1
     }
     If (skippedBeats!=1)
     {
        calcImgSize(1, imgW, imgH, ResolutionWidth, ResolutionHeight, newW, newH)
        cachedImgFile := mustSaveFile := 1
     }
  }
  If !newW
     newW := imgW
  If !newH
     newH := imgH

  BprevImgCall := AprevImgCall
  AprevImgCall := imgpath o_bwDithering fileSizu FileDateM cachedImgFile
  gdiBitmap := Gdip_CreateBitmap(newW, newH)
  G3 := Gdip_GraphicsFromImage(gdiBitmap)
  thisImgQuality := (userimgQuality=1 && mustSaveFile) ? 7 : 5
  Gdip_SetInterpolationMode(G3, thisImgQuality)
  Gdip_SetSmoothingMode(G3, 3)
  changeMcursor()
  Gdip_DrawImage(G3, oBitmap, 0, 0, newW, newH, 0, 0, imgW, imgH)
  Gdip_DeleteGraphics(G3)
  Gdip_DisposeImage(oBitmap, 1)
  If BprevGdiBitmap
     BprevGdiBitmap := Gdip_DisposeImage(BprevGdiBitmap, 1)
  BprevGdiBitmap := AprevGdiBitmap
  AprevGdiBitmap := Gdip_CloneBitmapArea(gdiBitmap, 0, 0, newW, newH)
  If (mustSaveFile=1)
  {
     z := Gdip_SaveBitmapToFile(gdiBitmap, file2load, 85)
     Sleep, 1
  }

  imgW := newW, imgH := newH
}

AdaptiveImgLight(whichImg, imgpath, Width, Height) {
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
  ; Gu := Gdip_GraphicsFromImage(cropBmp)
   Gdip_GetHistogram(cropBmp, 3, brLvlArray, 0, 0)
   Gdip_GetHistogram(cropBmp, 2, ArrChR, ArrChG, ArrChB)
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
   If (avgBrLvlR>250 || avgBrLvlG>250 || avgBrLvlB>250) && (avgBrLvlR!=avgBrLvlB || avgBrLvlR!=avgBrLvlG ||  avgBrLvlB!=avgBrLvlG)
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
   redLevelu := (avgBrLvlR>otherz+5 && avgBrLvlR<100 && otherz/avgBrLvlR<0.4) ? 1 - otherz/avgBrLvlR : 0
   newLumAdjust := redLevelu*4 - avgBrLvlR/255 - percBrgPx/100
   If (redLevelu>0 && newLumAdjust>0) && (lumosAdjust - newLumAdjust>0.999) && (autoAdjustMode=1)
   {
      lumosAdjust -= newLumAdjust
      satAdjust -= redLevelu/10
   }
   satAdjust -= redLevelu/15
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

generateThumbName(imgpath, forceThis:=0) {
   If (enableThumbsCaching!=1 && forceThis=0)
      Return

   FileGetSize, fileSizu, % imgpath
   FileGetTime, FileDateM, % imgpath, M
   fileInfos := imgpath fileSizu FileDateM
   MD5name := CalcStringHash(fileInfos, 0x8003)
   Return MD5name
}

getColorMatrix() {
; infos from http://www.graficaobscura.com/matrix/index.html
;   Static NTSCr := 0.300, NTSCg := 0.587, NTSCb := 0.115
    Static NTSCr := 0.308, NTSCg := 0.650, NTSCb := 0.095   ; personalized values

    matrix := ""
    If (ForceNoColorMatrix=1 && AnyWindowOpen=10)
       Return matrix

    If (imgFxMode=4)       ; grayscale
    {
       LGA := (lumosGrayAdjust<=1) ? lumosGrayAdjust/1.5 - 0.6666 : lumosGrayAdjust - 1
       Ra := NTSCr + LGA
       If (Ra<0)
          Ra := 0
       Ga := NTSCg + LGA
       If (Ga<0)
          Ga := 0
       Ba := NTSCb + LGA
       If (Ba<0)
          Ba := 0
       matrix := Ra "|" Ra "|" Ra "|0|0|" Ga "|" Ga "|" Ga "|0|0|" Ba "|" Ba "|" Ba "|0|0|0|0|0|1|0|" GammosGrayAdjust "|" GammosGrayAdjust "|" GammosGrayAdjust "|0|1"
    } Else If (imgFxMode=5)       ; grayscale R
    {
       Ga := 0, Ba := 0, GGA := 0
       Ra := 1
       matrix := Ra "|" Ra "|" Ra "|0|0|" Ga "|" Ga "|" Ga "|0|0|" Ba "|" Ba "|" Ba "|0|0|0|0|0|1|0|" GGA+0.01 "|" GGA "|" GGA "|0|1"
    } Else If (imgFxMode=6)       ; grayscale G
    {
       Ra := 0, Ba := 0, GGA := 0
       Ga := 1
       matrix := Ra "|" Ra "|" Ra "|0|0|" Ga "|" Ga "|" Ga "|0|0|" Ba "|" Ba "|" Ba "|0|0|0|0|0|1|0|" GGA "|" GGA+0.01 "|" GGA "|0|1"
    } Else If (imgFxMode=7)       ; grayscale B
    {
       Ra := 0, Ga := 0, GGA := 0
       Ba := 1
       matrix := Ra "|" Ra "|" Ra "|0|0|" Ga "|" Ga "|" Ga "|0|0|" Ba "|" Ba "|" Ba "|0|0|0|0|0|1|0|" GGA "|" GGA "|" GGA+0.01 "|0|1"
    } Else If (imgFxMode=8)  ; negative / invert
    {
       matrix := "-1|0|0|0|0|0|-1|0|0|0|0|0|-1|0|0|0|0|0|1|0|1|1|1|0|1"
    } Else If (imgFxMode=2 || imgFxMode=3) ; && (lumosAdjust!=1 || GammosAdjust!=0)
    {
       G := GammosAdjust
       sL := satAdjust
       sLi := 1 - satAdjust
       bLa := lumosAdjust - 1
       bL := lumosAdjust
       If (sL>1)
       {
          z := (bL<1) ? bL : 1
          sL := sL*z
          If (sL<0.98)
             sL := 0.98

          y := z*(1 - sL)
          mA := z*(y*NTSCr + sL + bLa + chnRdecalage)
          mB := z*(y*NTSCr)
          mC := z*(y*NTSCr)
          mD := z*(y*NTSCg)
          mE := z*(y*NTSCg + sL + bLa + chnGdecalage)
          mF := z*(y*NTSCg)
          mG := z*(y*NTSCb)
          mH := z*(y*NTSCb)
          mI := z*(y*NTSCb + sL + bLa + chnBdecalage)
          mtrx = %mA%|%mB%|%mC%|0|0
                |%mD%|%mE%|%mF%|0|0
                |%mG%|%mH%|%mI%|0|0
                |0   |0   |0   |1|0
                |%G% |%G% |%G% |0|1
       } Else
       {
          z := (bL<1) ? bL : 1
          tR := NTSCr - 0.5 + bL/2
          tG := NTSCg - 0.5 + bL/2
          tB := NTSCb - 0.5 + bL/2
          rB := z*(tR*sLi+bL*(1 - sLi) + chnRdecalage)
          gB := z*(tG*sLi+bL*(1 - sLi) + chnGdecalage)
          bB := z*(tB*sLi+bL*(1 - sLi) + chnBdecalage)     ; Formula used: A*w + B*(1 – w)
          rF := z*(NTSCr*sLi + (bL/2 - 0.5)*sLi)
          gF := z*(NTSCg*sLi + (bL/2 - 0.5)*sLi)
          bF := z*(NTSCb*sLi + (bL/2 - 0.5)*sLi)

          rB := rB*z+rF*(1 - z)
          gB := gB*z+gF*(1 - z)
          bB := bB*z+bF*(1 - z)     ; Formula used: A*w + B*(1 – w)
          If (rB<0)
             rB := 0
          If (gB<0)
             gB := 0
          If (bB<0)
             bB := 0
          If (rF<0)
             rF := 0
 
          If (gF<0)
             gF := 0
 
          If (bF<0)
             bF := 0

          ; ToolTip, % rB " - " rF " --- " gB " - " gF
          mtrx = %rB%|%rF%|%rF%|0|0
                |%gF%|%gB%|%gF%|0|0
                |%bF%|%bF%|%bB%|0|0
                |0   |0   |0   |1|0
                |%G% |%G% |%G% |0|1
          ; matrix adjusted for lisibility
       }
       matrix := StrReplace(mtrx, A_Space)
    }
    Return matrix
}

QPV_ShowImgonGuiPrev(roImgW, roImgH, oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgpath, CountFrames) {
    Critical, on

    matrix := getColorMatrix()
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    thisImgQuality := imgQuality
    Gdip_SetInterpolationMode(G, thisImgQuality)
    Gdip_SetSmoothingMode(G, 3)

    If (FlipImgH=1)
    {
       Gdip_ScaleWorldTransform(G, -1, 1)
       Gdip_TranslateWorldTransform(G, -mainWidth, 0)
    }

    If (FlipImgV=1)
    {
       Gdip_ScaleWorldTransform(G, 1, -1)
       Gdip_TranslateWorldTransform(G, 0, -mainHeight)
    }

    whichImg := (usePrevious=1 && gdiBitmapSmall) ? gdiBitmapSmall : gdiBitmap
    Gdip_GetImageDimensions(whichImg, imgW, imgH)
    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    r1 := Gdip_DrawImage(G, whichImg, DestPosX, DestPosY, newW, newH, 0, 0, imgW, imgH, matrix)
    If (GIFsGuiCreated=1)
       GIFguiCreator(1, 1)

;   ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
    pBrush := Gdip_BrushCreateSolid("0xAA898898")
    indicWidth := 150
    lineThickns := imgHUDbaseUnit
    lineThickns2 := lineThickns//4
    If (markedSelectFile || FlipImgV=1 || FlipImgH=1 || IMGlargerViewPort=1 || imgFxMode>1)
    {
       sqPosX := (markedSelectFile<currentFileIndex) ? 0 : mainWidth - lineThickns
       If (FlipImgH=1 && usePrevious=1)
          Gdip_FillRoundedRectangle(G, pBrush, mainWidth//2 - indicWidth//2, mainHeight//2 - lineThickns2//2, indicWidth, lineThickns2, lineThickns2//2)
       If (FlipImgV=1 && usePrevious=1)
          Gdip_FillRoundedRectangle(G, pBrush, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//2, lineThickns2, indicWidth, lineThickns2//2)
       If (imgFxMode>1 && usePrevious=1)
       {
          Gdip_FillPie(G, pBrush, mainWidth//2 - indicWidth//4, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2, 0, 180)
          Gdip_FillPie(G, pBrush, mainWidth//2 - indicWidth//8, mainHeight//2 - indicWidth//8, indicWidth//4, indicWidth//4, 180, 360)
       }
       If (IMGlargerViewPort=1)
       {
          marginErr := (usePrevious=1) ? 12 : 25
          lineThickns2 := (usePrevious=1) ? lineThickns : lineThickns//3
          If (newH>mainHeight)
          {
             If (DestPosY<-marginErr)
                Gdip_FillRectangle(G, pBrush, 0, 0, mainWidth, lineThickns2//2)
             If (DestPosY>-newH+mainHeight+marginErr)
                Gdip_FillRectangle(G, pBrush, 0, mainHeight - lineThickns2//2, mainWidth, lineThickns2//2)
          }
          If (newW>mainWidth)
          {
             If (DestPosX<-marginErr)
                Gdip_FillRectangle(G, pBrush, 0, 0, lineThickns2//2, mainHeight)
             If (DestPosX>-newW+mainWidth+marginErr)
                Gdip_FillRectangle(G, pBrush, mainWidth - lineThickns2//2, 0, lineThickns2//2, mainHeight)
          }
       }
       If (currentFileIndex=markedSelectFile)
       {
          Gdip_FillRectangle(G, pBrush, 0, 0, mainWidth, lineThickns//2)
          Gdip_FillRectangle(G, pBrush, 0, 0, lineThickns//2, mainHeight)
       } Else If (markedSelectFile)
          Gdip_FillRectangle(G, pBrush, sqPosX, 0, lineThickns, lineThickns)
    }

    lineThickns := (PrefsLargeFonts=1) ? imgHUDbaseUnit//8 : imgHUDbaseUnit//11
    If (usePrevious=1)
       lineThickns :=  imgHUDbaseUnit//13

    If (usePrevious=1 && imgFxMode=1)
    {
       indicWidth := (zoomLevel<1) ? Round(120 * zoomLevel) : 110
       If (indicWidth<50)
          indicWidth := 50
       pBrush2 := Gdip_BrushCreateSolid("0x77995555")
       pPen2 := Gdip_CreatePen("0xBBffccbb", lineThickns)
       Gdip_FillRectangle(G, pBrush2, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2)
       Gdip_DrawRectangle(G, pPen2, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2)
       Gdip_DeleteBrush(pBrush2)
       Gdip_DeletePen(pPen2)
    }

    If (activateImgSelection=1)
    {
       pPen1 := Gdip_CreatePen("0xCCbbccbb", lineThickns)
       nImgSelX1 := minU(imgSelX1, imgSelX2)
       nImgSelY1 := minU(imgSelY1, imgSelY2)
       nimgSelX2 := maxU(imgSelX1, imgSelX2)
       nimgSelY2 := maxU(imgSelY1, imgSelY2)
       If (editingSelectionNow!=1)
       {
          maxSelX :=  roImgW ? roImgW : oImgW
          maxSelY :=  roImgH ? roImgH : oImgH
          If (nImgSelX1>maxSelX)
             nImgSelX1 := maxSelX - 10
          If (nImgSelY1>maxSelY)
             nImgSelY1 := maxSelY - 10
          If (nImgSelX2>maxSelX)
             nImgSelX2 := maxSelX
          If (nImgSelY2>maxSelY)
             nImgSelY2 := maxSelY
       }
       zImgSelX1 := nImgSelX1*zoomLevel
       zImgSelX2 := nImgSelX2*zoomLevel
       zImgSelY1 := nImgSelY1*zoomLevel
       zImgSelY2 := nImgSelY2*zoomLevel

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

       Gdip_FillRectangle(G, pBrush, imgSelPx, imgSelPy, imgSelW, imgSelH)
       Gdip_DrawRectangle(G, pPen1, imgSelPx, imgSelPy, imgSelW, imgSelH)
       If (editingSelectionNow=1)
       {
          dotsSize := imgHUDbaseUnit//7
          If (usePrevious!=1)
             dotsSize := (PrefsLargeFonts=1) ? imgHUDbaseUnit//2.5 : imgHUDbaseUnit//4
          pBrush2 := Gdip_BrushCreateSolid("0xFFbbccFF")
          selDotX := imgSelPx - dotsSize//2
          selDotY := imgSelPy - dotsSize//2
          selDotAx := imgSelPx + imgSelW - dotsSize//2
          selDotAy := imgSelPy + imgSelH - dotsSize//2
          selDotBx := imgSelPx + imgSelW - dotsSize//2
          selDotBy := imgSelPy - dotsSize//2
          selDotCx := imgSelPx - dotsSize//2
          selDotCy := imgSelPy + imgSelH - dotsSize//2
          Gdip_FillRectangle(G, pBrush2, selDotX, selDotY, dotsSize, dotsSize)
          Gdip_FillRectangle(G, pBrush2, SelDotAx, SelDotAy, dotsSize, dotsSize)
          Gdip_FillRectangle(G, pBrush2, SelDotBx, SelDotBy, dotsSize, dotsSize)
          Gdip_FillRectangle(G, pBrush2, SelDotCx, SelDotCy, dotsSize, dotsSize)
          Gdip_DeleteBrush(pBrush2)
       }
       Gdip_DeletePen(pPen1)
    }

    Gdip_DeleteBrush(pBrush)
    dummyPos := (A_OSVersion!="WIN_7") ? 1 : ""
    If (CountFrames>1 && animGIFsSupport=1 && (prevAnimGIFwas!=imgpath || (A_TickCount - lastGIFdestroy > 9500)))
    {
       Sleep, 15
       prevAnimGIFwas := imgpath
       r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, 1, 1)
       GIFguiCreator(imgpath, 0, DestPosX, DestPosY, newW, newH, mainWidth, mainHeight)
    } Else
    {
       r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    }

    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %hGDIwin%,, %mainX%, %mainY%
    }
    r := (r1!=0 || !r2) ? 0 : 1
    Return r
}

QPV_ShowImgonGui(roImgW, roImgH, oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgpath, CountFrames, wasForcedHigh) {
    Critical, on
    Static IDviewPortCache, PREVtestIDvPcache
    If (wasForcedHigh=1)
       IDviewPortCache := PREVtestIDvPcache := ""

    testIDvPcache := imgpath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight
    If (usePrevious=1 && testIDvPcache!=PREVtestIDvPcache) || (CountFrames>1)
    {
       r := QPV_ShowImgonGuiPrev(roImgW, roImgH, oImgW, oImgH, wscale, imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, imgpath, CountFrames)
       Return r
    }

    startZeit := A_TickCount  
    matrix := ""
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    thisImgQuality := imgQuality
    Gdip_SetInterpolationMode(G, thisImgQuality)
    Gdip_SetSmoothingMode(G, 3)
    If (GIFsGuiCreated=1)
       GIFguiCreator(1, 1)

    whichImg := (usePrevious=1 && gdiBitmapSmall) ? gdiBitmapSmall : gdiBitmap
    Gdip_GetImageDimensions(whichImg, imgW, imgH)
    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    thisIDviewPortCache := imgpath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight usePrevious
    If (thisIDviewPortCache!=IDviewPortCache || !ViewPortBMPcache || CountFrames>1) && (usePrevious!=1)
    {
       r1 := Gdip_DrawImage(G, whichImg, DestPosX, DestPosY, newW, newH, 0, 0, imgW, imgH, matrix)
   ;   ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
       dummyPos := (A_OSVersion!="WIN_7") ? 1 : ""
       mustDisplay := 1
       If (usePrevious!=1)
       {
          If ViewPortBMPcache
             ViewPortBMPcache := Gdip_DisposeImage(ViewPortBMPcache, 1)
          IDviewPortCache := imgpath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight usePrevious
          PREVtestIDvPcache := imgpath zoomLevel IMGresizingMode imageAligned IMGdecalageX IMGdecalageY mainWidth mainHeight
          ViewPortBMPcache := Gdip_CreateBitmapFromHBITMAP(hbm)
        }
        ;   r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    } Else mustDisplay := 1

    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    If (cachedImgFile=1)
       Gdip_DisposeImage(whichImg, 1)

    matrix := getColorMatrix()
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G2 := Gdip_GraphicsFromHDC(hdc)
    thisImgQuality := imgQuality
    Gdip_SetInterpolationMode(G2, thisImgQuality)
    Gdip_SetSmoothingMode(G2, 3)

    If (FlipImgH=1)
    {
       Gdip_ScaleWorldTransform(G2, -1, 1)
       Gdip_TranslateWorldTransform(G2, -mainWidth, 0)
    }

    If (FlipImgV=1)
    {
       Gdip_ScaleWorldTransform(G2, 1, -1)
       Gdip_TranslateWorldTransform(G2, 0, -mainHeight)
    }

    r1 := Gdip_DrawImage(G2, ViewPortBMPcache, 0, 0, mainWidth, mainHeight, 0, 0, mainWidth, mainHeight, matrix)
    pBrush := Gdip_BrushCreateSolid("0x99898898")
    If (markedSelectFile || FlipImgV=1 || FlipImgH=1 || IMGlargerViewPort=1 || imgFxMode>1)
    {
       indicWidth := 150
       lineThickns := imgHUDbaseUnit
       lineThickns2 := lineThickns//4
       sqPosX := (markedSelectFile<currentFileIndex) ? 0 : mainWidth - lineThickns
       If (FlipImgH=1 && usePrevious=1)
          Gdip_FillRoundedRectangle(G2, pBrush, mainWidth//2 - indicWidth//2, mainHeight//2 - lineThickns2//2, indicWidth, lineThickns2, lineThickns2//2)
       If (FlipImgV=1 && usePrevious=1)
          Gdip_FillRoundedRectangle(G2, pBrush, mainWidth//2 - lineThickns2//2, mainHeight//2 - indicWidth//2, lineThickns2, indicWidth, lineThickns2//2)
       If (imgFxMode>1 && usePrevious=1)
       {
          Gdip_FillPie(G2, pBrush, mainWidth//2 - indicWidth//4, mainHeight//2 - indicWidth//4, indicWidth//2, indicWidth//2, 0, 180)
          Gdip_FillPie(G2, pBrush, mainWidth//2 - indicWidth//8, mainHeight//2 - indicWidth//8, indicWidth//4, indicWidth//4, 180, 360)
       }
       If (IMGlargerViewPort=1)
       {
          marginErr := (usePrevious=1) ? 12 : 25
          lineThickns2 := (usePrevious=1) ? lineThickns : lineThickns//3
          If (newH>mainHeight)
          {
             If (DestPosY<-marginErr)
                Gdip_FillRectangle(G2, pBrush, 0, 0, mainWidth, lineThickns2//2)
             If (DestPosY>-newH+mainHeight+marginErr)
                Gdip_FillRectangle(G2, pBrush, 0, mainHeight - lineThickns2//2, mainWidth, lineThickns2//2)
          }
          If (newW>mainWidth)
          {
             If (DestPosX<-marginErr)
                Gdip_FillRectangle(G2, pBrush, 0, 0, lineThickns2//2, mainHeight)
             If (DestPosX>-newW+mainWidth+marginErr)
                Gdip_FillRectangle(G2, pBrush, mainWidth - lineThickns2//2, 0, lineThickns2//2, mainHeight)
          }
       }
       If (currentFileIndex=markedSelectFile)
       {
          Gdip_FillRectangle(G2, pBrush, 0, 0, mainWidth, lineThickns//2)
          Gdip_FillRectangle(G2, pBrush, 0, 0, lineThickns//2, mainHeight)
       } Else If (markedSelectFile)
          Gdip_FillRectangle(G2, pBrush, sqPosX, 0, lineThickns, lineThickns)
    }

    If (activateImgSelection=1)
    {
       maxSelX := roImgW ? roImgW : oImgW
       maxSelY := roImgH ? roImgH : oImgH
       lineThickns := (PrefsLargeFonts=1) ? imgHUDbaseUnit//8 : imgHUDbaseUnit//11
       If (usePrevious=1)
          lineThickns :=  imgHUDbaseUnit//13
       pPen1 := Gdip_CreatePen("0xCCbbccbb", lineThickns)
       If (imgSelX2=-1)
       {
          imgSelX1 := maxSelX//2
          imgSelX2 := imgSelX1 + mainWidth//3 + 2
          If (imgSelX2>maxSelX)
             imgSelX2 := Round(maxSelX*0.9)
          If (IMGresizingMode=1)
          {
             imgSelX1 := 0
             imgSelX2 := maxSelX//2
          }
       }

       If (imgSelY2=-1)
       {
          imgSelY1 := maxSelY//2
          imgSelY2 := imgSelY1 + mainHeight//3 + 2
          If (imgSelY2>maxSelY)
             imgSelY2 := Round(maxSelY*0.9)
          If (IMGresizingMode=1)
          {
             imgSelY1 := 0
             imgSelY2 := maxSelY//2
          }
       }

       If (imgSelX1<0 && usePrevious!=1)
          imgSelX1 := 0
       If (imgSelY1<0 && usePrevious!=1)
          imgSelY1 := 0

       If (imgSelX2<0 && usePrevious!=1)
          imgSelX2 := 0
       If (imgSelY2<0 && usePrevious!=1)
          imgSelY2 := 0
       nImgSelX1 := minU(imgSelX1, imgSelX2)
       nImgSelY1 := minU(imgSelY1, imgSelY2)
       nimgSelX2 := maxU(imgSelX1, imgSelX2)
       nimgSelY2 := maxU(imgSelY1, imgSelY2)
       imgSelX1 := nImgSelX1 
       imgSelY1 := nImgSelY1 
       imgSelX2 := nimgSelX2 
       imgSelY2 := nimgSelY2 
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
       zImgSelX1 := nImgSelX1*zoomLevel
       zImgSelX2 := nImgSelX2*zoomLevel
       zImgSelY1 := nImgSelY1*zoomLevel
       zImgSelY2 := nImgSelY2*zoomLevel

       imgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
       imgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
       If (imgSelW<35)
          imgSelW := 35
       If (imgSelH<35)
          imgSelH := 35

       imgSelPx := DestPosX + minU(zImgSelX1, zImgSelX2)
       imgSelPy := DestPosY + minU(zImgSelY1, zImgSelY2)
       imgSelOutViewPort := 0
       If (editingSelectionNow=1)
       {
          If (imgSelPx>mainWidth - 45)
          {
             imgSelPx := (IMGlargerViewPort=1) ? DestPosX + oImgW*zoomLevel - 45 : mainWidth - 45
             imgSelOutViewPort := 1
          }
          If (imgSelPy>mainHeight - 45)
          {
             imgSelPy := (IMGlargerViewPort=1) ? DestPosY + oImgH*zoomLevel - 45 : mainHeight - 45
             imgSelOutViewPort := 1
          }
       }
       Gdip_FillRectangle(G2, pBrush, imgSelPx, imgSelPy, imgSelW, imgSelH)
       Gdip_DrawRectangle(G2, pPen1, imgSelPx, imgSelPy, imgSelW, imgSelH)
       If (editingSelectionNow=1)
       {
          dotsSize := (PrefsLargeFonts=1) ? imgHUDbaseUnit//2.5 : imgHUDbaseUnit//4
          If (usePrevious=1)
             dotsSize := imgHUDbaseUnit//6
          pBrush2 := Gdip_BrushCreateSolid("0xFFbbccFF")
          selDotX := imgSelPx - dotsSize//2
          selDotY := imgSelPy - dotsSize//2
          selDotAx := imgSelPx + imgSelW - dotsSize//2
          selDotAy := imgSelPy + imgSelH - dotsSize//2
          selDotBx := imgSelPx + imgSelW - dotsSize//2
          selDotBy := imgSelPy - dotsSize//2
          selDotCx := imgSelPx - dotsSize//2
          selDotCy := imgSelPy + imgSelH - dotsSize//2
          Gdip_FillRectangle(G2, pBrush2, selDotX, selDotY, dotsSize, dotsSize)
          Gdip_FillRectangle(G2, pBrush2, SelDotAx, SelDotAy, dotsSize, dotsSize)
          Gdip_FillRectangle(G2, pBrush2, SelDotBx, SelDotBy, dotsSize, dotsSize)
          Gdip_FillRectangle(G2, pBrush2, SelDotCx, SelDotCy, dotsSize, dotsSize)
          Gdip_DeleteBrush(pBrush2)
       }
       Gdip_DeletePen(pPen1)
    }

    If (mustDisplay=1)
       r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G2)
    Gdip_DeleteBrush(pBrush)

    If (A_OSVersion="WIN_7")
    {
       JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
       WinMove, ahk_id %hGDIwin%,, %mainX%, %mainY%
    }
    r := (r1!=0 || !r2) ? 0 : 1
    totalZeit := A_TickCount - startZeitIMGload
    thisZeit := A_TickCount - startZeit
    If (totalZeit<150)
       prevFastDisplay := A_TickCount
    ; ToolTip, % thisZeit ", " totalZeit "|" ViewPortCache,,,2
    Return r
}

getCaptionStyle() {
  WinGet, Stylu, Style, ahk_id %PVhwnd%
  r := (Stylu & 0xC00000) ? 0 : 1
  Return r
}

editImgSelection() {
  Critical, on
  If (thumbsDisplaying=1)
     Return

  If (getCaptionStyle()=1)
     ToggleTitleBaruNow()

  If (slideShowRunning=1)
     ToggleSlideShowu()

  editingSelectionNow := !editingSelectionNow
  activateImgSelection := 1
  dummyTimerDelayiedImageDisplay(25)
}

toggleImgSelection() {
  If (thumbsDisplaying=1)
     Return

  If (slideShowRunning=1)
     ToggleSlideShowu()
  editingSelectionNow := 0
  activateImgSelection := !activateImgSelection
  dummyTimerDelayiedImageDisplay(25)
}

resetImgSelection() {
  If (thumbsDisplaying=1 || slideShowRunning=1)
     Return

  imgSelX1 := imgSelY1 := 0
  imgSelX2 := imgSelY2 := -1
  editingSelectionNow := activateImgSelection := 0
  dummyTimerDelayiedImageDisplay(25)
}

newImgSelection() {
  IMGdecalageX := IMGdecalageY := 0
  resetImgSelection()
  Sleep, 2
  editImgSelection()
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

    If (modus=2)
    {
       BlackedCreator(128)
       SetTimer, destroyBlacked, -100
       Return
    }
    dummyPos := (A_OSVersion!="WIN_7") ? 1 : ""
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    opacity := (modus=1) ? "0xFF" : "0x50"
    pBrush := Gdip_BrushCreateSolid(opacity WindowBgrColor)
    Gdip_FillRectangle(G, pBrush, 0, 0, mainWidth+2, mainHeight+2)
    r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    Gdip_DeleteBrush(pBrush)
}

valueBetween(value, inputA, inputB) {
    testRange := 0
    pointA := (inputA>inputB) ? inputB : inputA
    pointB := (inputA>inputB) ? inputA : inputB
    if value between %pointA% and %pointB%
       testRange := 1
    Return testRange
}

mainGdipWinThumbsGrid() {
    Critical, on
    GetClientSize(mainWidth, mainHeight, PVhwnd)
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G10 := Gdip_GraphicsFromHDC(hdc)
    pBrush1 := Gdip_BrushCreateSolid("0x88999999")
    pBrush2 := Gdip_BrushCreateSolid("0x55999999")
    pBrush3 := Gdip_BrushCreateSolid("0x39999922")
    pBrush4 := Gdip_BrushCreateSolid("0xaa" WindowBgrColor)
    pBrush5 := Gdip_BrushCreateSolid("0x66334433")

    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, startIndex, mainWidth, mainHeight)
    rowIndex := 0
    columnIndex := -1
    Loop, % maxItemsW*maxItemsH*2
    {
        thisFileIndex := startIndex + A_Index - 1
        imgpath := resultedFilesList[thisFileIndex]
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
        If !FileExist(imgpath)
           Gdip_FillRectangle(G10, pBrush4, DestPosX, DestPosY, thumbsW, thumbsH)

        If (thisFileIndex=currentFileIndex)
           Gdip_FillRectangle(G10, pBrush1, DestPosX, DestPosY, thumbsW, thumbsH)

        testRange := valueBetween(thisFileIndex, currentFileIndex, markedSelectFile)
        If (testRange=1 && markedSelectFile>0)
           Gdip_FillRectangle(G10, pBrush3, DestPosX, DestPosY, thumbsW, thumbsH)

        If (thisFileIndex=markedSelectFile)
        {
           Gdip_FillRectangle(G10, pBrush2, DestPosX, DestPosY, thumbsW, thumbsH)
           Gdip_FillRectangle(G10, pBrush2, DestPosX, DestPosY, thumbsW, imgHUDbaseUnit//2)
           Gdip_FillRectangle(G10, pBrush2, DestPosX, DestPosY, imgHUDbaseUnit//2, thumbsH)
        }
    }

    If (markedSelectFile)
    {
       sqPosX := (markedSelectFile<currentFileIndex) ? 0 : mainWidth - imgHUDbaseUnit
       Gdip_FillRectangle(G10, pBrush1, sqPosX, 0, imgHUDbaseUnit, imgHUDbaseUnit)
    }

    thisFileIndex := currentFileIndex
    If (thisFileIndex>maxFilesIndex - maxItemsPage)
       thisFileIndex := maxFilesIndex - maxItemsPage

    scrollYpos := (thisFileIndex/maxFilesIndex)*100
    scrollYpos := Round((mainHeight/100)*scrollYpos)
    scrollHeight := (maxItemsPage/maxFilesIndex)*100
    scrollHeight := Ceil((mainHeight/100)*scrollHeight)
    If (scrollHeight<10)
       scrollHeight := 10

    lineThickns := imgHUDbaseUnit
    Gdip_FillRectangle(G10, pBrush5, mainWidth - lineThickns//2, 0, lineThickns//2, mainHeight)
    Gdip_FillRectangle(G10, pBrush2, mainWidth - lineThickns//2 + 4, scrollYpos, lineThickns//2, scrollHeight)

    dummyPos := (A_OSVersion!="WIN_7") ? 1 : ""
    r2 := UpdateLayeredWindow(hGDIwin, hdc, dummyPos, dummyPos, mainWidth, mainHeight, 255)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G10)
    Gdip_DeleteBrush(pBrush1)
    Gdip_DeleteBrush(pBrush2)
    Gdip_DeleteBrush(pBrush3)
    Gdip_DeleteBrush(pBrush4)
    Gdip_DeleteBrush(pBrush5)
}

EraseThumbsCache(dummy:=0) {
   startZeit := A_TickCount
   showTOOLtip("Emptying thumbnails cache, please wait...")
   IniDelete, % mainSettingsFile, AutoLevels
   FileDelete, % thumbsCacheFolder "\colorsinfo.ini"
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
      If (A_TickCount - prevMSGdisplay>3500)
      {
         showTOOLtip("Emptying thumbnails cache, please wait... " countFilez " removed until now .")
         prevMSGdisplay := A_TickCount
      }

      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
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

generateImgThumbCache(imgpath, newImgSize) {
    Critical, on
    If !InStr(FileExist(thumbsCacheFolder), "D")
    {
       FileCreateDir, %thumbsCacheFolder%
       If ErrorLevel
          Return
    }
    MD5name := generateThumbName(imgpath)
    changeMcursor()
    oBitmap := LoadBitmapFromFileu(imgpath)
    If !oBitmap
       Return

    Gdip_GetImageDimensions(oBitmap, imgW, imgH)
    calcImgSize(1, imgW, imgH, newImgSize, newImgSize, ResizedW, ResizedH)
    thumbBMP := Gdip_CreateBitmap(ResizedW, ResizedH)
    G2 := Gdip_GraphicsFromImage(thumbBMP)
    thisImgQuality := (userimgQuality=1) ? 3 : 5
    Gdip_SetInterpolationMode(G2, thisImgQuality)
    Gdip_SetSmoothingMode(G2, 3)
    changeMcursor()
    Gdip_DrawImage(G2, oBitmap, 0, 0, ResizedW, ResizedH, 0, 0, imgW, imgH)
    file2save := thumbsCacheFolder "\" MD5name ".jpg"
    r := Gdip_SaveBitmapToFile(thumbBMP, file2save, 85)
    Gdip_DeleteGraphics(G2)
    Gdip_DisposeImage(oBitmap, 1)
    Gdip_DisposeImage(thumbBMP, 1)
}

QPV_ShowThumbnails(startIndex) {
    Critical, on

    prevFullThumbsUpdate := A_TickCount
    mainStartZeit := A_TickCount
    imageLoading := 1
    changeMcursor()
    If (imgFxMode!=3)
       matrix := getColorMatrix()

    thumbsInfoYielder(maxItemsW, maxItemsH, maxItemsPage, maxPages, ignoreVaru, mainWidth, mainHeight)
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetInterpolationMode(G, imgQuality)
    Gdip_SetSmoothingMode(G, 3)
    pBrush := Gdip_BrushCreateSolid("0x77" WindowBgrColor)
    rowIndex := imgsListed := 0
    maxImgSize := maxZeit := columnIndex := -1
    dummyPos := (A_OSVersion!="WIN_7") ? 1 : ""

    If (A_OSVersion="WIN_7")
    {
      JEE_ClientToScreen(hPicOnGui1, 1, 1, mainX, mainY)
      WinMove, ahk_id %hGDIthumbsWin%,, %mainX%, %mainY%
    }
    If (GIFsGuiCreated=1)
       DestroyGIFuWin()

    Gdip_FillRectangle(G, pBrush, 0, 0, mainWidth, mainHeight)
    Loop, % maxItemsW*maxItemsH*2
    {
        If GetKeyState("Esc", "P")
        {
           lastLongOperationAbort := A_TickCount
           abandonAll := 1
           Break
        }
        startZeit := A_TickCount
        thisFileIndex := startIndex + A_Index - 1
        imgpath := resultedFilesList[thisFileIndex]
        MD5name := generateThumbName(imgpath)
        file2save := thumbsCacheFolder "\" MD5name ".jpg"
        thisImgFile := FileExist(file2save) ? file2save : imgpath
        changeMcursor()
        oBitmap := LoadBitmapFromFileu(thisImgFile)
        If oBitmap
           Gdip_GetImageDimensions(oBitmap, imgW, imgH)
        calcImgSize(1, imgW, imgH, thumbsW, thumbsH, newW, newH)
        columnIndex++
        If (columnIndex>=maxItemsW)
        {
           rowIndex++
           columnIndex := 0
        }

        If (rowIndex>=maxItemsH)
           Break

        DestPosX := thumbsW//2 - newW//2 + thumbsW*columnIndex
        DestPosY := thumbsH//2 - newH//2 + thumbsH*rowIndex
        If (!imgW || !imgH || !oBitmap || !FileExist(imgpath))
           Continue

        changeMcursor()
        r1 := Gdip_DrawImage(G, oBitmap, DestPosX, DestPosY, newW, newH, 0, 0, imgW, imgH, matrix)
        oBitmap := Gdip_DisposeImage(oBitmap, 1)
        r2 := UpdateLayeredWindow(hGDIthumbsWin, hdc, dummyPos, dummyPos, mainWidth, mainHeight)
        endZeit := A_TickCount
        thisZeit := endZeit - startZeit
        If (thisZeit>maxZeit)
           maxZeit := thisZeit
        If (imgW>maxImgSize)
           maxImgSize := imgW
        If (imgH>maxImgSize)
           maxImgSize := imgH

        imgsListed++
        If (thisZeit>150 && file2save!=thisImgFile)
           ListImg2Cache .= imgpath "`n"

        If (imgW>130 || imgH>130)   ; images still worth bothering to cache
           ListAllIMGs .= imgpath "`n"

        If GetKeyState("Esc", "P")
        {
           lastLongOperationAbort := A_TickCount
           abandonAll := 1
           Break
        }
    }
    mainEndZeit := A_TickCount
    Sleep, 1
    If oBitmap
       Gdip_DisposeImage(oBitmap, 1)

;   ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    Gdip_DeleteBrush(pBrush)
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    prevFullThumbsUpdate := A_TickCount
    loopZeit := mainEndZeit - mainStartZeit
    If (abandonAll=1)
       Return 0

    If (StrLen(ListImg2Cache)>1 && enableThumbsCaching=1)
    {
       listHasCached := 1
       thumbsCacheSize := (maxZeit>350 || loopZeit>700) ? 350 : 600
       showTOOLtip("Caching " thumbsCacheSize "px thumbnails, please wait...")
       Loop, Parse, ListImg2Cache, `n
       {
           changeMcursor()
           generateImgThumbCache(A_LoopField, thumbsCacheSize)
           If GetKeyState("Esc", "P")
           {
              lastLongOperationAbort := A_TickCount
              abandonAll := 1
              Break
           }
       }
       SetTimer, RemoveTooltip, -500
    }

    If (maxImgSize<135)
       listHasCached := 1

    If (loopZeit>1500)
       maxImgSize := 250

    If (maxImgSize>260)
    {
       good2go := 1
       newSize := 250
    } Else If (maxImgSize<255)
    {
       good2go := 1
       newSize := 120
    }

    If (listHasCached!=1 && good2go=1 && loopZeit>400 && imgsListed>3)
    {
       showTOOLtip("Caching "  newSize "px thumbnails, please wait...")
       Loop, Parse, ListAllIMGs, `n
       {
           generateImgThumbCache(A_LoopField, newSize)
           If GetKeyState("Esc", "P")
           {
              lastLongOperationAbort := A_TickCount
              abandonAll := 1
              Break
           }
       }
       SetTimer, RemoveTooltip, -500
    }
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
    SetTimer, ResetImgLoadStatus, -50
    prevFullThumbsUpdate := A_TickCount
    r := (r1!=0 || !r2 || abandonAll=1) ? 0 : 1
    Return r
}

calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, ByRef DestPosX, ByRef DestPosY) {
    Static orderu := {1:7, 2:8, 3:9, 4:4, 5:5, 6:6, 7:1, 8:2, 9:3}
         , prevW := 1, prevH := 1, prevZoom := 0

    modus := orderu[imageAligned]
    If (IMGresizingMode=4) || (thumbsDisplaying=1)
       modus := 5

    LY := mainHeight - newH
    LX := mainWidth - newW
    If (modus=1)
    {
       DestPosX := 0
       DestPosY := LY
    } Else If (modus=2)
    {
       DestPosX := mainWidth//2 - newW//2
       DestPosY := LY
    } Else If (modus=3)
    {
       DestPosX := LX
       DestPosY := LY
    } Else If (modus=4)
    {
       DestPosX := 0
       DestPosY := mainHeight//2 - newH//2
    } Else If (modus=5)
    {
       DestPosX := mainWidth//2 - newW//2
       DestPosY := mainHeight//2 - newH//2
    } Else If (modus=6)
    {
       DestPosX := LX
       DestPosY := mainHeight//2 - newH//2
    } Else If (modus=7)
    {
       DestPosX := DestPosY := 0
    } Else If (modus=8)
    {
       DestPosX := mainWidth//2 - newW//2
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
      SetTimer, GDIupdater, -25
Return

GDIupdater() {
   updateUIctrl()
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

   If (A_TickCount - scriptStartTime<600) ;  || (imageLoading=1)
      Return 1

   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   imgpath := resultedFilesList[currentFileIndex]
   If (!FileExist(imgpath) || !imgpath || !maxFilesIndex || PrevGuiSizeEvent=1 || !CurrentSLD)
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

   If (maxFilesIndex>0 && PrevGuiSizeEvent!=1 && thumbsDisplaying!=1) && (A_TickCount - scriptStartTime>500)
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

DestroyGDIbmp() {
   Gdip_DisposeImage(gdiBitmap, 1)
   gdiBitmap := ""
}

JEE_ClientToScreen(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472

  VarSetCapacity(POINT, 8)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ClientToScreen", Ptr,hWnd, Ptr,&POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
}

GetClientSize(ByRef w, ByRef h, hwnd) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
    Static prevW, prevH, lastInvoked := 1
    If (A_TickCount - lastInvoked<50)
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

    Loop, Parse, tehFileVar,`n,`r
    {
       line := Trim(A_LoopField)
       If InStr(line, "|")
       {
          doRecursive := 2
          line := StrReplace(line, "|")
       } Else doRecursive := 1

       changeMcursor()
       If (RegExMatch(line, RegExFilesPattern) && RegExMatch(line, "i)^(.\:\\.)"))
       {
          If (doFilesCheck=1)
          {
             If !FileExist(line)
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
  Loop, Files, %strDir%, %dig%
  {
      If RegExMatch(A_LoopFileName, RegExFilesPattern)
      {
         addedNow++
         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := A_LoopFileFullPath
      }
      If (A_TickCount - prevMSGdisplay>3500)
      {
         showTOOLtip("Loading files from...`n" strDir "`n" A_Index "/" addedNow " files...")
         prevMSGdisplay := A_TickCount
      }

      changeMcursor()
      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
      }
  }
  Try DllCall("user32\SetCursor", "Ptr", hCursN)
  If (abandonAll=1)
     showTOOLtip("Operation aborted...")
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

IDshowImage(imgID, opentehFile:=0) {
    Static lastInvoked := 1
    resultu := resultedFilesList[imgID]
    If !resultu
    {
       If (A_TickCount - lastInvoked>1050)
          SoundBeep, 300, 50
       lastInvoked := A_TickCount
       Return 0
    }

    FileGetSize, fileSizu, %resultu%
    isPipe := InStr(resultu, "||")
    resultu := StrReplace(resultu, "||")
    If (!fileSizu && !FileExist(resultu) && skipDeadFiles=1 && opentehFile!=250)
    {
       If (autoRemDeadEntry=1 && imgID=currentFileIndex)
          remCurrentEntry(0, 1)
       Return 0
    }

    If isPipe                  ; remove «deleted file» marker if somehow the file is back
       If FileExist(resultu)
          resultedFilesList[imgID] := resultu

    If (opentehFile=1)
    {
       If !FileExist(resultu)
          informUserFileMissing()
       Try Run, %resultu%
    } Else If (opentehFile=2)
    {
        ShowTheImage(resultu, 2)  ; force no down-scaling
    } Else If (opentehFile=4)
    {
        ShowTheImage(resultu, 4)  ; force no cache at all
    } Else ShowTheImage(resultu)
    Return 1
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND = 0x112, TPM_RETURNCMD=0x100
  oldDetect := A_DetectHiddenWindows
  DetectHiddenWindows, on
  Process, Exist
  h := WinExist("ahk_pid " ErrorLevel)
  DetectHiddenWindows, %oldDetect%
  JEE_ClientToScreen(hPicOnGui1, 1, 1, X, Y)
  hSysMenu := DllCall("GetSystemMenu", "Uint", Hwnd, "int", False) 
  r := DllCall("TrackPopupMenu", "uint", hSysMenu, "uint", TPM_RETURNCMD, "int", X, "int", Y, "int", 0, "uint", h, "uint", 0)
  IfEqual, r, 0, return
  PostMessage, WM_SYSCOMMAND, r,,,ahk_id %Hwnd%
  Return 1
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

trimArray(arr) { ; Hash O(n) 
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

coreResizeIMG(imgpath, newW, newH, file2save, goFX, toClippy, rotateMode, soloMode:=1, imgW:=0, imgH:=0, batchMode:=0) {
     If (soloMode=1)
     {
        changeMcursor()
        doBw := (ResizeApplyEffects=1 || goFX=1) ? 1 : 0
        oBitmap := LoadBitmapFromFileu(imgpath, doBw)
        Gdip_GetImageDimensions(oBitmap, imgW, imgH)
        rr := (toClippy=1) ? "" : "error"
        If !newW
           newW := imgW
        If !newH
           newH := imgH
        If !oBitmap
           Return rr
    } Else oBitmap := soloMode

    Angle := 0
    If (rotateMode=2)
       Angle := 90
    Else If (rotateMode=3)
       Angle := 180
    Else If (rotateMode=4)
       Angle := -90

    If (ResizeApplyEffects=1 || goFX=1)
    {
       If (imgFxMode=3 && toClippy!=1)
          AdaptiveImgLight(oBitmap, imgpath, imgW, imgH)
       matrix := getColorMatrix()
    }

    If (activateImgSelection=1 && (goFX=1 || ResizeWithCrop=1))
    {
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

       imgSelW := maxU(nImgSelX1, nImgSelX2) - minU(nImgSelX1, nImgSelX2)
       imgSelH := maxU(nImgSelY1, nImgSelY2) - minU(nImgSelY1, nImgSelY2)
       imgSelPx := minU(nImgSelX1, nImgSelX2)
       imgSelPy := minU(nImgSelY1, nImgSelY2)
       If (imgSelW<5)
       {
          imgSelW := 5
          If (imgSelPx>=5)
             imgSelPx -= 5
          Else
             imgSelPx := 0
       }

       If (imgSelH<5)
       {
          imgSelH := 5
          If (imgSelPy>=5)
             imgSelPy -= 5
          Else
             imgSelPy := 0
       }

       zImgSelW := maxU(zImgSelX1, zImgSelX2) - minU(zImgSelX1, zImgSelX2)
       zImgSelH := maxU(zImgSelY1, zImgSelY2) - minU(zImgSelY1, zImgSelY2)
       zImgSelPx := minU(zImgSelX1, zImgSelX2)
       zImgSelPy := minU(zImgSelY1, zImgSelY2)
       If (zImgSelW<5)
       {
          zImgSelW := 5
          If (zImgSelPx>=5)
             zImgSelPx -= 5
          Else
             zImgSelPx := 0
       }
       If (zImgSelH<5)
       {
          zImgSelH := 5
          If (zImgSelPy>=5)
             zImgSelPy -= 5
          Else
             zImgSelPy := 0
       }
    } Else
    {
       imgSelW := imgW, imgSelH := imgH
       imgSelPx := 0, imgSelPy := 0

       zImgSelW := newW, zImgSelH := newH
       zImgSelPx := 0, zImgSelPy := 0
    }

    thumbBMP := Gdip_CreateBitmap(zImgSelW, zImgSelH)
    G2 := Gdip_GraphicsFromImage(thumbBMP)
    thisImgQuality := (ResizeQualityHigh=1) ? 7 : 5
    Gdip_SetInterpolationMode(G2, thisImgQuality)
    Gdip_SetSmoothingMode(G2, 3)

    changeMcursor()
    Gdip_DrawImage(G2, oBitmap, 0, 0, zImgSelW, zImgSelH, imgSelPx, imgSelPy, imgSelW, imgSelH, matrix)
    fImgW := zImgSelW
    fImgH := zImgSelH

    ; Gdip_GetImageDimensions(thumbBMP, fImgW, fImgH)
    ; MsgBox, % fimgW " x " fimgH "`n" imgSelW " x " imgSelH "`n" zLv ", " zLh
    Gdip_GetRotatedDimensions(fImgW, fImgH, Angle, RWidth, RHeight)
    Gdip_GetRotatedTranslation(fImgW, fImgH, Angle, xTranslation, yTranslation)
    RWidth := Floor(RWidth) - 1, RHeight := Floor(RHeight) - 1
    xTranslation := Round(xTranslation) - 1, yTranslation := Round(yTranslation) - 1
    If (rotateMode=2)
       RWidth := RWidth - 2, xTranslation := xTranslation - 2
    Else If (rotateMode=3 || rotateMode=4)
       RHeight := RHeight - 2, yTranslation := yTranslation - 2

    zBitmap := Gdip_CreateBitmap(RWidth, RHeight)
    G3 := Gdip_GraphicsFromImage(zBitmap)
    Gdip_SetInterpolationMode(G3, thisImgQuality)
    Gdip_SetSmoothingMode(G3, 3)
    Gdip_TranslateWorldTransform(G3, xTranslation, yTranslation)
    Gdip_RotateWorldTransform(G3, Angle)
    pBrush := Gdip_BrushCreateSolid(0xFF555555)
    Gdip_FillRectangle(G3, pBrush, 0, 0, fImgW+5, fImgH+5)
    Gdip_DeleteBrush(pBrush)
    If (ResizeApplyEffects=1 || goFX=1)
    {
       If (FlipImgH=1)
       {
          Gdip_ScaleWorldTransform(G3, -1, 1)
          Gdip_TranslateWorldTransform(G3, -fImgW, 0)
       }

       If (FlipImgV=1)
       {
          Gdip_ScaleWorldTransform(G3, 1, -1)
          Gdip_TranslateWorldTransform(G3, 0, -fImgH)
       }
    }

    changeMcursor()
    Gdip_DrawImage(G3, thumbBMP, 0, 0, fImgW, fImgH, 0, 0, fImgW, fImgH, "")
    Gdip_DisposeImage(oBitmap, 1)
    Sleep, 1

    If (userUnsprtWriteFMT=3 && batchMode=1)
    {
       zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       file2save := OutDir "\" OutNameNoExt "." rDesireWriteFMT
    } Else If (userUnsprtWriteFMT=2 && !RegExMatch(file2save, saveTypesRegEX) && batchMode=1)
    {
       zPlitPath(file2save, 0, OutFileName, OutDir, OutNameNoExt, fileEXT)
       file2save := OutDir "\" OutNameNoExt "." rDesireWriteFMT
    }

    changeMcursor()
    If (toClippy=1)
       r := Gdip_SetBitmapToClipboard(zBitmap)
    Else
       r := Gdip_SaveBitmapToFile(zBitmap, file2save, 90)
    If (toClippy!=1) && (r=-2 || r=-1)
       r := SaveFIMfile(file2save, zBitmap)
    Gdip_DeleteGraphics(G2)
    Gdip_DeleteGraphics(G3)
    If zBitmap
       Gdip_DisposeImage(zBitmap, 1)
    If thumbBMP
       Gdip_DisposeImage(thumbBMP, 1)
    Return r
}

AboutWindow() {
    createSettingsGUI(1)
    btnWid := 100
    txtWid := 360
    Gui, Font, s19 Bold, Arial, -wrap
    Gui, Add, Button, x1 y1 h1 w1 Default gCloseWindow, Close
    Gui, Add, Text, x10 y15 Section, %appTitle% v%Version%
    Gui, Font
    If (PrefsLargeFonts=1)
    {
       btnWid := btnWid + 50
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }
    Gui, Add, Link, xs y+5, Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a>.
    Gui, Add, Link, y+10 w%txtWid%, Based on the prototype image viewer by <a href="http://sites.google.com/site/littlescripting/">SBC</a> from October 2010 published on <a href="https://autohotkey.com/board/topic/58226-ahk-picture-viewer/">AHK forums</a>.
    Gui, Add, Text, y+10 w%txtWid%, Current version: v%Version% from %vReleaseDate%. 
    Gui, Add, Text, y+10 w%txtWid%, Dedicated to people with really large image collections and slideshow needs :-).
    Gui, Add, Text, y+10 w%txtWid%, This application contains code from various entities. You can find more details in the source code.
    Gui, Font, Bold
    Gui, Add, Link, y+15 w%txtWid%, To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> or <a href="mailto:marius.sucan@gmail.com?subject=%appTitle% v%Version%">send me feedback</a>.
    Gui, Add, Link, y+15 w%txtWid%, New and previous versions are available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">GitHub</a>.
    Gui, Font, Normal
    Gui, Add, Button, xs+5 y+25 h30 w105 Default gCloseWindow, Close
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

PanelJpegPerformOperation() {
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
    If (markedSelectFile)
       filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

    Gui, Add, Text, x15 y15 Section, Please choose a JPEG lossless operation...
    Gui, Add, DropDownList, y+10 Section w%txtWid% AltSubmit Choose%jpegDesiredOperation% vjpegDesiredOperation, None|Flip Horizontally|Flip Vertically|Transpose|Transverse|Rotate 90|Rotate 180|Rotate -90
    Gui, Add, Checkbox, y+10 Checked%jpegDoCrop% vjpegDoCrop, Crop image(s) to selected area (irreversible)
    If (filesElected>1)
       Gui, Add, Text, y+20, %filesElected% files are selected.
    If (activateImgSelection!=1)
       GuiControl, Disable, jpegDoCrop
    If !filesElected
    {
       Gui, Add, Button, xs+0 y+25 h30 w35 gPreviousPicture, <<
       Gui, Add, Button, x+5 hp wp gNextPicture, >>
       Gui, Add, Button, x+5 hp w%btnWid% Default gBtnPerformJpegOp, &Perform operation
    } Else
       Gui, Add, Button, xs+0 y+20 h30 w%btnWid% Default gBtnPerformJpegOp, &Perform operation
    Gui, Add, Button, x+5 hp w80 gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, JPEG lossless operations: %appTitle%
}

BtnPerformJpegOp() {
    Static lastInvoked := 1
    GuiControlGet, jpegDesiredOperation
    GuiControlGet, jpegDoCrop
    If (A_TickCount - lastInvoked < 150) || (jpegDesiredOperation=1 && jpegDoCrop=0)
       Return

    imgpath := resultedFilesList[currentFileIndex]
    initFIMGmodule()
    If !wasInitFIMlib
    {
       Msgbox, 48, %appTitle%, ERROR: Unable to initialize Free Image library module...`n`nThis functionality is currently unavailable.
       Return
    }

    lastInvoked := A_TickCount
    prevStartIndex := -1
    If (markedSelectFile)
       filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

    If (filesElected>1)
    {
       batchJpegLLoperations()
       Return
    } Else r := coreJpegLossLessAction(imgpath)

    If r
    {
       showTOOLtip("JPEG operation completed succesfully.")
       IDshowImage(currentFileIndex, 4)
    } Else
    {
       showTOOLtip("JPEG operation has failed...")
       SoundBeep , 300, 100
    }
    lastInvoked := A_TickCount
    SetTimer, RemoveTooltip, % -msgDisplayTime
}

batchJpegLLoperations() {
  If (markedSelectFile)
     filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

  If (filesElected>1)
  {
     msgInfos := (jpegDoCrop=1) ? "`n`nThe crop operation IS irreversible!" : ""
     MsgBox, 52, %appTitle%, Are you sure you want to perform the JPEG transformations on the selected files? There are currently %filesElected% selected files.%msgInfos%
     IfMsgBox, Yes
       good2go := 1
  } Else good2go := 1

  If (good2go!=1)
     Return

  If (markedSelectFile>0 && filesElected>1)
  {
     If AnyWindowOpen
        CloseWindow()
     Sleep, 25
     showTOOLtip("Performing JPEG lossless operations on " filesElected " files, please wait...")
     prevMSGdisplay := A_TickCount
     startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
     countFilez := countTFilez := 0
     Loop, % filesElected
     {
        If GetKeyState("Esc", "P")
        {
           lastLongOperationAbort := A_TickCount
           abandonAll := 1
           Break
        }

        thisFileIndex := startPoint + A_Index - 1
        file2rem := resultedFilesList[thisFileIndex]
        file2rem := StrReplace(file2rem, "||")
        If (A_TickCount - prevMSGdisplay>3500)
        {
           showTOOLtip("Performing JPEG lossless operations on " countFilez "/" filesElected " files, please wait...")
           prevMSGdisplay := A_TickCount
        }

        If !RegExMatch(file2rem, "i)(.\.(jpeg|jpg|jpe))$")
           Continue

        FileSetAttrib, -R, %file2rem%
        Sleep, 0
        countTFilez++
        changeMcursor()
        r := coreJpegLossLessAction(file2rem)
        If r
           countFilez++
        Else
           someErrors := "`nErrors occured during file operations..."
     }
     Try DllCall("user32\SetCursor", "Ptr", hCursN)
     markedSelectFile := ""
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
}

coreJpegLossLessAction(imgpath) {
    If (jpegDoCrop=1 && activateImgSelection=1)
    {
       changeMcursor()
       r1 := GetImgFileDimension(imgpath, imgW, imgH)
       Sleep, 1
       x1 := imgSelX1, y1 := imgSelY1
       x2 := imgSelX2, y2 := imgSelY2
       If (x1>imgW-5)
          x1 := imgW - 10
       If (y1>imgH-5)
          y1 := imgH - 10
       If (x2>imgW)
          x2 := imgW
       If (y2>imgH)
          y2 := imgH
       changeMcursor()
       r := FreeImage_JPEGTransformCombined(imgpath, imgpath, jpegDesiredOperation - 1, x1, y1, x2, y2)
    } Else
    {
       changeMcursor()
       r := FreeImage_JPEGTransform(imgpath, imgpath, jpegDesiredOperation - 1)
    }

    Return r
}

ColorsAdjusterPanelWindow() {
    Global sliderBright, sliderContrst, sliderSatu, realTimePreview, CustomZoomCB
         , infoBright, infoContrst, infoSatu, BtnLumPlus, BtnLumMin, BtnFlipH
         , BtnGammPlus, BtnGammMin, BtnSatPlus, BtnSatMin, ResizeModeDL, BtnFlipV
         , infoRGBchnls, RGBcbList := "-3.0|-2.0|-1.5|-1.0|-0.9|-0.8|-0.7|-0.6|-0.5|-0.4|-0.3|-0.2|-0.1|0.0|0.1|0.2|0.3|0.4|0.5|0.6|0.7|0.8|0.9|1.0|1.5|2.0|3.0"

    If (thumbsDisplaying=1)
       Return

    changeMcursor()
    ToolTip, Please wait...,,, 2
    createSettingsGUI(10)
    ForceNoColorMatrix := 0
    btnWid := 100
    txtWid := slideWid := 280
    initFIMGmodule()
    If !wasInitFIMlib
       bwDithering := 0

    If (PrefsLargeFonts=1)
    {
       slideWid := slideWid + 135
       btnWid := btnWid + 70
       txtWid := txtWid + 135
       Gui, Font, s%LargeUIfontValue%
    }

    thisZL := Round(zoomLevel*100) "%"
    Gui, Add, DropDownList, x15 y15 Section w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%IMGresizingMode% vIMGresizingMode, Adapt all images into view|Adapt only large images|Original resolution (100`%)|Custom zoom level
    Gui, Add, ComboBox, x+1 w90 gColorPanelTriggerImageUpdate vCustomZoomCB, 10`%|25`%|50`%|75`%|125`%|150`%|200`%|300`%|500`%|%thisZL%||
    Gui, Add, DropDownList, xs y+5 w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%imgFxMode% vimgFxMode, Original image colors|Personalized colors|Auto-adjusted colors|Grayscale|Red channel|Green channel|Blue channel
    Gui, Add, Checkbox, x+1 hp w45 +0x1000 gColorPanelTriggerImageUpdate Checked%FlipImgV% vFlipImgV, V
    Gui, Add, Checkbox, x+1 hp w45 +0x1000 gColorPanelTriggerImageUpdate Checked%FlipImgH% vFlipImgH, H
    Gui, Add, DropDownList, xs y+5 w%txtWid% gColorPanelTriggerImageUpdate AltSubmit Choose%autoAdjustMode% vAutoAdjustMode, Adaptive mixed mode|Increase brightness|Increase contrast
    Gui, Add, ComboBox, x+1 w90 gColorPanelTriggerImageUpdate vusrAdaptiveThreshold, -2000|-100|-50|-2|1|2|50|1000|2000|%usrAdaptiveThreshold%||
    Gui, Add, Checkbox, xs y+5 w%txtWid% gColorPanelTriggerImageUpdate Checked%doSatAdjusts% vdoSatAdjusts, Auto-adjust image saturation level
    Gui, Add, Checkbox, x+5 w90 gColorPanelTriggerImageUpdate Checked%bwDithering% vbwDithering, B/W
    Gui, Add, Text, xs y+15 w%txtWid% vinfoBright, Brightness: ----
    Gui, Add, Slider, y+5 AltSubmit ToolTip NoTicks w%slideWid% gColorPanelTriggerImageUpdate vsliderBright Range-100-100, 1
    Gui, Add, Button, x+1 hp w45 gBtnChangeLumPlus vBtnLumPlus, +
    Gui, Add, Button, x+1 hp w45 gBtnChangeLumMin vBtnLumMin, -
    Gui, Add, Text, xs y+8 w%txtWid% vinfoContrst, Contrast: ----
    Gui, Add, Slider, y+5 AltSubmit ToolTip NoTicks w%slideWid% gColorPanelTriggerImageUpdate vsliderContrst Range-100-100, 1
    Gui, Add, Button, x+1 hp w45 gBtnChangeGammPlus vBtnGammPlus, -
    Gui, Add, Button, x+1 hp w45 gBtnChangeGammMin vBtnGammMin, +
    Gui, Add, Text, xs y+8 w%txtWid% vinfoSatu, Saturation: ----
    Gui, Add, Slider, y+5 AltSubmit ToolTip NoTicks w%slideWid% gColorPanelTriggerImageUpdate vsliderSatu Range-100-100, 1
    Gui, Add, Button, x+1 hp w45 gBtnChangeSatPlus vBtnSatPlus, +
    Gui, Add, Button, x+1 hp w45 gBtnChangeSatMin vBtnSatMin, -
    ; Gui, Add, Checkbox, xs y+15 gColorPanelTriggerImageUpdate Checked%realTimePreview% vrealTimePreview, Update image in real time
    Gui, Add, Text, xs y+15 vinfoRGBchnls, RGB channels balance:
    Gui, Add, ComboBox, x+5 w65 gColorPanelTriggerImageUpdate vchnRdecalage, %RGBcbList%|%chnRdecalage%||
    Gui, Add, ComboBox, x+5 wp gColorPanelTriggerImageUpdate vchnGdecalage, %RGBcbList%|%chnGdecalage%||
    Gui, Add, ComboBox, x+5 wp gColorPanelTriggerImageUpdate vchnBdecalage, %RGBcbList%|%chnBdecalage%||

    Gui, Add, Button, xs+0 y+20 h30 w35 gBtnPrevImg, <<
    Gui, Add, Button, x+5 hp wp gBtnNextImg, >>
    Gui, Add, Button, x+5 hp w%btnWid% gBtnResetImageView, &Reset image view
    Gui, Add, Button, x+5 hp w%btnWid% gBtnSaveIMG, &Save image as
    Gui, Add, Button, x+5 hp w80 Default gCloseWindow, C&lose
    changeMcursor()
    Gui, SettingsGUIA: Show, AutoSize, Adjust image view: %appTitle%
    updatePanelColorsInfo()
    updatePanelColorSliderz()
    ToolTip,,,, 2
    Try DllCall("user32\SetCursor", "Ptr", hCursN)
}

BtnSaveIMG() {
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
      GuiControl, SettingsGUIA:, sliderSatu, % infoSliderSatu 
      GuiControl, SettingsGUIA:, sliderBright, % infoSliderBright
      GuiControl, SettingsGUIA:, sliderContrst, % infoSliderContrst
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
   GuiControlGet, usrAdaptiveThreshold
   infolumosAdjust := (imgFxMode=4) ? Round(lumosGrayAdjust, 3) : Round(lumosAdjust, 3)
   infoGammosAdjust := (imgFxMode=4) ? Round(GammosGrayAdjust, 3) : Round(GammosAdjust, 3)
   infoSatAdjust := Round(satAdjust, 3)
   GuiControl, SettingsGUIA:, infoBright, % "Brightness: " infolumosAdjust
   GuiControl, SettingsGUIA:, infoContrst, % "Contrast: " infoGammosAdjust
   GuiControl, SettingsGUIA:, infoSatu, % "Saturation: " infoSatAdjust
   If (IMGresizingMode=4)
      GuiControl, SettingsGUIA: Enable, CustomZoomCB
   Else
      GuiControl, SettingsGUIA: Disable, CustomZoomCB

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
   } Else If (imgFxMode=4)
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

   If (imgFxMode=4 && wasInitFIMlib=1)
      GuiControl, SettingsGUIA: Enable, bwDithering
   Else
      GuiControl, SettingsGUIA: Disable, bwDithering

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
  o_bwDithering := bwDithering
  GuiControl, SettingsGUIA: Choose, imgFxMode, 1
  GuiControl, SettingsGUIA: Choose, usrAdaptiveThreshold, 5
  GuiControl, SettingsGUIA: Choose, chnRdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnGdecalage, 14
  GuiControl, SettingsGUIA: Choose, chnBdecalage, 14
  GuiControl, SettingsGUIA: Choose, IMGresizingMode, 1
  GuiControl, SettingsGUIA:, bwDithering, 0
  IMGresizingMode := imgFxMode := satAdjust := lumosAdjust := lumosGrayAdjust := 1
  chnRdecalage := chnGdecalage := chnBdecalage := GammosAdjust := GammosGrayAdjust := 0
  updatePanelColorsInfo()
  usrAdaptiveThreshold := infoBright := infoSatu := 1
  bwDithering := infoContrst := sliderSatu := sliderBright := sliderContrst := 0

  GuiControl, SettingsGUIA:, infoBright, Brightness: 1.009
  GuiControl, SettingsGUIA:, infoContrst, Contrast: 0.000
  GuiControl, SettingsGUIA:, infoSatu, Saturation: 1.000
  GuiControl, SettingsGUIA:, sliderSatu, 0
  GuiControl, SettingsGUIA:, sliderBright, 0
  GuiControl, SettingsGUIA:, sliderContrst, 0
  writeMainSettings()
  If (o_bwDithering=1)
     IDshowImage(currentFileIndex, 4)
  Else
     dummyTimerDelayiedImageDisplay(50)
}

ColorPanelTriggerImageUpdate() {
   Critical, On
   Static prevbwDithering := "null"
   If (prevbwDithering="null")
      prevbwDithering := bwDithering

   GuiControlGet, imgFxMode
   GuiControlGet, usrAdaptiveThreshold
   GuiControlGet, doSatAdjusts
   GuiControlGet, autoAdjustMode
   GuiControlGet, sliderBright
   GuiControlGet, sliderContrst
   GuiControlGet, sliderSatu
   GuiControlGet, bwDithering
   GuiControlGet, FlipImgV
   GuiControlGet, FlipImgH
   GuiControlGet, CustomZoomCB
   GuiControlGet, IMGresizingMode
   GuiControlGet, chnRdecalage
   GuiControlGet, chnGdecalage
   GuiControlGet, chnBdecalage
   ; GuiControlGet, realTimePreview

   ForceNoColorMatrix := 0
   zoomLevel := StrReplace(CustomZoomCB, "%")
   zoomLevel := StrReplace(zoomLevel, A_Space)/100
   If (imgFxMode=2)
   {
      lumosAdjust := (sliderBright>0) ? 0.14*sliderBright + 1 : 0.01*Abs(sliderBright + 100)
      GammosAdjust := (sliderContrst>0) ? -0.15*sliderContrst : 0.01*Abs(sliderContrst)
      satAdjust := (sliderSatu>0) ? 0.02*sliderSatu + 1 : 0.01*Abs(sliderSatu + 100)
   } Else If (imgFxMode=4)
   {
      lumosGrayAdjust := (sliderBright>0) ? 0.14*sliderBright + 1 : 0.01*Abs(sliderBright + 100)
      GammosGrayAdjust := (sliderContrst>0) ? -0.15*sliderContrst : 0.01*Abs(sliderContrst)
   }

   If (imgFxMode=3)
   {
      imgpath := resultedFilesList[currentFileIndex]
      AdaptiveImgLight(gdiBitmap, imgpath, 1, 1)
      updatePanelColorSliderz()
   }

   If (imgFxMode!=4)
   {
      GuiControl, SettingsGUIA:, bwDithering, 0
      bwDithering := 0
   }

   updatePanelColorsInfo()
   If (prevbwDithering!=bwDithering)
   {
      prevbwDithering := bwDithering
      IDshowImage(currentFileIndex, 4)
   } Else filterDelayiedImageDisplay()
}

ResizeImagePanelWindow() {
    Global userEditWidth, userEditHeight, ResultEditWidth, ResultEditHeight, btnFldr
    If (markedSelectFile)
    {
       filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
       If (markedSelectFile>0 && filesElected>1)
          multipleFilesMode := 1
       Else markedSelectFile := ""
    }

    createSettingsGUI(4)
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

    img2resizePath := resultedFilesList[currentFileIndex]
    If (multipleFilesMode!=1)
    {
       r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
       FileGetSize, fileSizu, % img2resizePath, K
    } Else
    {
       oImgW := ResolutionWidth
       oImgH := ResolutionHeight
    }

    initFIMGmodule()
    If (multipleFilesMode=1)
    {
       Gui, Font, Bold
       Gui, Add, Text, x15 y15 Section, Files selected to process: %filesElected%.
       Gui, Font, Normal
    } Else
    {
       Gui, Add, Text, x15 y15 Section, Original image dimensions:
       Gui, Add, Text, xs+15 y+5, %oImgW% x %oImgH% pixels. %fileSizu% kilobytes.
    }
    Gui, Add, Text, xs y+15, Resize image to (W x H)
    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 limit9 -multi number -wantCtrlA -wantReturn -wantTab -wrap gEditResizeWidth vuserEditWidth, % (ResizeInPercentage=1) ? 100 : oImgW
    Gui, Add, Edit, x+5 w%editWid% r1 limit9 -multi number -wantCtrlA -wantReturn -wantTab -wrap gEditResizeHeight vuserEditHeight, % (ResizeInPercentage=1) ? 100 : oImgH
    Gui, Add, Checkbox, x+5 wp+30 hp +0x1000 gTglRszInPercentage Checked%ResizeInPercentage% vResizeInPercentage, in `% perc.
    If (multipleFilesMode!=1)
       Gui, Add, Text, xs y+15, Result (W x H) in pixels
    Gui, Add, Edit, xs+15 y+5 w%editWid% r1 Disabled -wrap vResultEditWidth, % (multipleFilesMode=1) ? "--" : oImgW
    Gui, Add, Edit, x+5 w%editWid% r1 Disabled -wrap vResultEditHeight, % (multipleFilesMode=1) ? "--" : oImgH
    Gui, Add, DropDownList, x+5 wp+30 gTglRszRotation AltSubmit Choose%ResizeRotationUser% vResizeRotationUser, Rotate: 0°|90° [CW]|180° [CW]|-90° [CCW]
    Gui, Add, Checkbox, xs y+15 gTglRszKeepAratio Checked%ResizeKeepAratio% vResizeKeepAratio, Keep aspect ratio
    Gui, Add, Checkbox, y+5 gTglRszCropping Checked%ResizeWithCrop% vResizeWithCrop, Crop image(s) to the viewport selection
    Gui, Add, Checkbox, y+5 gTglRszQualityHigh Checked%ResizeQualityHigh% vResizeQualityHigh, High quality resampling
    Gui, Add, Checkbox, y+5 gTglRszApplyEffects Checked%ResizeApplyEffects% vResizeApplyEffects, Apply effects activated in main window`n(eg. grayscale or flip image H/V)
    Gui, Add, Checkbox, y+5 gTglRszDestFoldr Checked%ResizeUseDestDir% vResizeUseDestDir, Save file(s) in the following folder
    Gui, Add, Edit, xp+15 y+5 wp r1 +0x0800 -wrap vResizeDestFolder, % ResizeDestFolder
    Gui, Add, Button, x+5 hp w90 gChngRszDestFldr vbtnFldr, C&hoose
    If (activateImgSelection!=1)
       GuiControl, Disable, ResizeWithCrop
    If !ResizeUseDestDir
    {
       GuiControl, Disable, btnFldr
       GuiControl, Disable, ResizeDestFolder
    }

    If (multipleFilesMode=1)
    {
       Gui, Add, DropDownList, xs y+5 w%txtWid% gTglRszUnsprtFrmt AltSubmit Choose%userUnsprtWriteFMT% vuserUnsprtWriteFMT, Skip files in unsupported write formats|Try to preserve file formats, convert unsupported to...|Convert all the files to...
       Gui, Add, Button, xs+0 y+15 h30 w%btnWid% Default gBTNsaveResizedIMG, &Process images
       Gui, Add, DropDownList, x+5 w75 AltSubmit Choose%userDesireWriteFMT% vuserDesireWriteFMT, .BMP|.GIF|.HDP|.J2C|.J2K|.JFIF|.JIF|.JNG|.JP2|.JPG|.JXR|.PNG|.PPM|.TGA|.TIF|.WDP|.WEBP|.XPM
       If (userUnsprtWriteFMT=1)
          GuiControl, SettingsGUIA: Disable, userDesireWriteFMT
    } Else
    {
       Gui, Add, Button, xs+0 y+15 h30 w%btnWid% gCopy2ClipResizedIMG, &Copy to clipboard
       Gui, Add, Button, x+5 hp w%btnWid% Default gBTNsaveResizedIMG, &Save image as...
    }
    Gui, Add, Button, x+5 hp w85 gCloseWindow, C&lose
    Gui, SettingsGUIA: Show, AutoSize, Resize/crop image(s): %appTitle%
}

ChngRszDestFldr() {
    GUI, 1: +OwnDialogs
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
   If (!desiredH || !desiredW
   || desiredW<1 || desiredH<1)
   {
      SoundBeep , 300, 100
      Return
   }

   If (desiredW<5 || desiredH<5) && (isPercntg!=1)
   {
      SoundBeep , 300, 100
      Return
   }

   If (markedSelectFile)
      filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1

   overwriteWarning := (ResizeUseDestDir!=1) ? "`n`nWARNING: All the original files will be overwritten." : ""
   If (filesElected>0)
   {
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
   startPoint := (currentFileIndex<markedSelectFile) ? currentFileIndex : markedSelectFile
   Loop, % filesElected 
   {
      thisFileIndex := startPoint + A_Index - 1
      imgpath := resultedFilesList[thisFileIndex]
      imgpath := StrReplace(imgpath, "||")
      If (!FileExist(imgpath) || !imgpath)
      || (!RegExMatch(imgpath, saveTypesRegEX) && userUnsprtWriteFMT=1)
         Continue

      countTFilez++
      If (A_TickCount - prevMSGdisplay>3500)
      {
         showTOOLtip("Processing " countTFilez "/" filesElected " images, please wait...")
         prevMSGdisplay := A_TickCount
      }

      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
      }

      oBitmap := LoadBitmapFromFileu(imgpath, ResizeApplyEffects)
      If !oBitmap
      {
         someErrors := "`nErrors occured during file operations..."
         Continue
      }

      Gdip_GetImageDimensions(oBitmap, imgW, imgH)
      If (isPercntg=1)
      {
         newW := Round((imgW/100)*desiredW)
         newH := Round((imgH/100)*desiredH)
         If (newW<10 && newH<10)
            Continue
      } Else If (ResizeKeepAratio=1)
      {
         calcImgSize(1, imgW, imgH, desiredW, desiredH, newW, newH)
         If (newW<10 && newH<10)
            Continue
      } Else
      {
         newW := desiredW
         newH := desiredH
      }

      If (ResizeUseDestDir=1)
      {
         zPlitPath(imgpath, 0, OutFileName, OutDir)
         destImgPath := ResizeDestFolder "\" OutFileName
         If FileExist(destImgPath)
         {
            MD5name := generateThumbName(imgpath, 1)
            destImgPath := ResizeDestFolder "\" MD5name "-" OutFileName
         }
      } Else destImgPath := imgpath

      r := coreResizeIMG(imgpath, newW, newH, destImgPath, 0, 0, ResizeRotationUser, oBitmap, imgW, imgH, 1)
      If !r
         countFilez++
      Else someErrors := "`nErrors occured during file operations..."

      If GetKeyState("Esc", "P")
      {
         lastLongOperationAbort := A_TickCount
         abandonAll := 1
         Break
      }
   }
   CurrentSLD := backCurrentSLD
   markedSelectFile := ""
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
   Static saveImgFormatsList := {1:"bmp", 2:"gif", 3:"hdp", 4:"j2c", 5:"j2k", 6:"jfif", 7:"jif", 8:"jng", 9:"jp2", 10:"jpg", 11:"jxr", 12:"png", 13:"ppm", 14:"tga", 15:"tif", 16:"wdp", 17:"webp", 18:"xpm"}
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
   GuiControlGet, ResizeUseDestDir
   GuiControlGet, ResizeDestFolder
   If (markedSelectFile)
   {
      filesElected := (currentFileIndex>markedSelectFile) ? currentFileIndex - markedSelectFile + 1 : markedSelectFile - currentFileIndex + 1
      If (markedSelectFile>0 && filesElected>1)
      {
         GuiControlGet, userDesireWriteFMT
         GuiControlGet, userUnsprtWriteFMT
         rDesireWriteFMT := saveImgFormatsList[userDesireWriteFMT]
         If (!RegExMatch(rDesireWriteFMT, "i)(bmp|png|tif|gif|jpg)$") && wasInitFIMlib!=1)
         {
            SoundBeep, 300, 100
            Msgbox, 48, %appTitle%, ERROR: The "%rDesireWriteFMT%" format is currently unsupported. The FreeImage library failed to properly initialize.
            Return
         }

         batchIMGresizer(userEditWidth, userEditHeight, ResizeInPercentage)
         Return
      }
   }

   If (!ResultEditHeight || !ResultEditWidth
   || ResultEditWidth<5 || ResultEditHeight<5)
   {
      SoundBeep , 300, 100
      Return
   }

   zPlitPath(img2resizePath, 0, OutFileName, OutDir)
   startPath := (ResizeUseDestDir=1) ? ResizeDestFolder "\" OutFileName : img2resizePath

   GUI, SettingsGUIA: +OwnDialogs
   FileSelectFile, file2save, S18, % startPath, Save processed image as..., Images (*.BMP;*.GIF;*.HDP;*.J2C;*.J2K;*.JFIF;*.JIF;*.JNG;*.JP2;*.JPE;*.JPEG;*.JPG;*.JXR;*.PNG;*.PPM;*.TGA;*.TIF;*.TIFF;*.WDP;*.WEBP;*.XPM)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If !RegExMatch(file2save, saveTypesRegEX)
      {
         SoundBeep, 300, 100
         Msgbox, 48, %appTitle%, ERROR: Please use a supported file format. Allowed formats: .BMP, .GIF, .HDP, .J2C, .J2K, .JFIF, .JIF, .JNG, .JP2, .JPE, .JPEG, .JPG, .JXR, .PNG, .PPM, .TGA, .TIF, .TIFF, .WDP, .WEBP and .XPM.
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

   If (!ResultEditHeight || !ResultEditWidth
   || ResultEditWidth<5 || ResultEditHeight<5)
   {
      SoundBeep, 300, 900
      Return
   }

   r := coreResizeIMG(img2resizePath, ResultEditWidth, ResultEditHeight, "--", 0, 1, ResizeRotationUser)
   If r
   {
      showTOOLtip("Resized image copied to clipboard")
      SoundBeep, 900, 100
   } Else Msgbox, 48, %appTitle%, ERROR: Unable to copy resized image to clipboard... Error code: %r%.
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

EditResizeWidth() {
   GuiControlGet, userEditWidth
   GuiControlGet, userEditHeight
   GuiControlGet, ResizeKeepAratio
   GuiControlGet, ResizeInPercentage
   
   If (A_TickCount - lastEditRHChange < 200)
      Return

   If (markedSelectFile>0 && ResizeKeepAratio=1 && ResizeInPercentage=1)
   {
      Global lastEditRWChange := A_TickCount
      GuiControl, SettingsGUIA:, userEditHeight, % Round(userEditWidth)
      Return
   }

   If (markedSelectFile>0)
      Return

   If (userEditWidth<1 || !userEditWidth)
      userEditWidth := 1

   r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
   Global lastEditRWChange := A_TickCount
   Sleep, 5
   If (ResizeKeepAratio=1)
   {
      thisWidth := (ResizeInPercentage=1) ? (oImgW/100)*userEditWidth : userEditWidth
      calcImgSize(1, oImgW, oImgH, thisWidth, 90000*oImgH, newW, newH)
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

   If (markedSelectFile>0 && ResizeKeepAratio=1 && ResizeInPercentage=1)
   {
      Global lastEditRHChange := A_TickCount
      GuiControl, SettingsGUIA:, userEditWidth, % Round(userEditHeight)
      Return
   }

   If (markedSelectFile>0)
      Return

   If (userEditHeight<1 || !userEditHeight)
      userEditHeight := 1
   r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
   Global lastEditRHChange := A_TickCount
   Sleep, 5
   If (ResizeKeepAratio=1)
   {
      thisHeight := (ResizeInPercentage=1) ? (oImgH/100)*userEditHeight : userEditHeight
      calcImgSize(1, oImgW, oImgH, 90000*oImgW, thisHeight, newW, newH)
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
   If !markedSelectFile
   {
      r1 := GetImgFileDimension(img2resizePath, oImgW, oImgH, 0)
   } Else
   {
      oImgW := ResolutionWidth
      oImgH := ResolutionHeight
   }

   GuiControl, SettingsGUIA:, userEditWidth, % (ResizeInPercentage=1) ? 100 : oImgW
   GuiControl, SettingsGUIA:, userEditHeight, % (ResizeInPercentage=1) ? 100 : oImgH
   If !markedSelectFile
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

TglRszRotation() {
   GuiControlGet, ResizeRotationUser
   writeMainSettings()
}

TglRszCropping() {
   GuiControlGet, ResizeWithCrop
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

           If GetKeyState("Esc", "P")
           {
              lastLongOperationAbort := A_TickCount
              abandonAll := 1
              Break
           }
           theEntireListu .= r "`n"
       }
       Tooltip, Counting files in each folder... please wait.
    }

    LV_ModifyCol(5, "Integer")
    LV_ModifyCol(1, "Integer")
    LV_ModifyCol(0, "Integer")
    Loop, Parse, foldersListu, `n
    {
        If StrLen(A_LoopField)<2
           Continue

        If GetKeyState("Esc", "P")
        {
           lastLongOperationAbort := A_TickCount
           abandonAll := 1
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

    Loop, 5
        LV_ModifyCol(A_Index, "AutoHdr Left")
    LV_ModifyCol(3, "Sort")
    If (CountFilesFolderzList=1)
    {
       SoundBeep , 900, 100
       Tooltip
    }
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
    imgQuality := (userimgQuality=1) ? 7 : 5
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
    thisFntSize := (PrefsLargeFonts=1) ? Round(OSDfntSize*1.5) : OSDfntSize
    Sleep, 5
    Gui, ToolTipGuia: -DPIScale -Caption +Owner1 +ToolWindow +E0x80000 +E0x20 +hwndhGuiTip
    Gui, ToolTipGuia: Margin, % thisFntSize + 5, % thisFntSize + 3
    Gui, ToolTipGuia: Color, c%OSDbgrColor%
    Gui, ToolTipGuia: Font, s%thisFntSize% Bold Q5, %OSDFontName%
    Gui, ToolTipGuia: Add, Text,+0x80 c%OSDtextColor% gRemoveTooltip, %msg%
;    Gui, ToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, GuiTipsWin

    GetClientSize(mainWidth, mainHeight, PVhwnd)
    JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
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
  A := WinActive("A")
  okay := (A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin) ? 1 : 0
  If (okay!=1 || imageLoading=1) || (A_TickCount - lastWinDrag<45)
  {
     LbtnDwn := mPosCtrl := 0
     Return
  }

  mPosCtrl := A_GuiControl
  LbtnDwn := (wP&0x1) && !(GetKeyState("LButton", "P")) ? 1 : 0
  If (LbtnDwn=1)
     SetTimer, ResetLbtn, -25
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

initCompiled() {
   Current_PID := GetCurrentProcessId()
   fullPath2exe := GetModuleFileNameEx(Current_PID)
   zPlitPath(fullPath2exe, 0, OutFileName, OutDir)
   mainCompiledPath := OutDir "\"
   thumbsCacheFolder := OutDir "\thumbs-cache"
   mainSettingsFile := OutDir "\" mainSettingsFile
}
