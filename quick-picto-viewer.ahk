; Script Name:    AHK Picture Viewer
; Language:       English
; Platform:       Windows XP or later
; Author:         Marius Șucan
; Script Original Version: 1.0.0 on Oct 4, 2010 by SBC
; Script Current Version: 2.0.0 on vendredi 24 mai 2019
; Script Function:
; Display images and slideshows; jpeg, jpg, bmp, png, gif, tif, emf
;
; Website of SBC: http://sites.google.com/site/littlescripting/
; Website of Marius Șucan: http://marius.sucan.ro/
;
; AHK forum address for the original script:
; https://autohotkey.com/board/topic/58226-ahk-picture-viewer/
; Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
;_________________________________________________________________________________________________________________Auto Execute Section____

#NoEnv
#NoTrayIcon
#MaxHotkeysPerInterval, 500
#MaxMem, 1924
#Singleinstance, off
#Include, Gdip.ahk

Global PVhwnd, hGDIwin, resultedFilesList := []
   , currentFileIndex, maxFilesIndex := 0
   , appTitle := "AHK Picture Viewer", FirstRun := 1
   , bckpResultedFilesList := [], bkcpMaxFilesIndex := 0
   , DynamicFoldersList := "", historyList
   , hPicOnGui1, scriptStartTime := A_TickCount
   , RandyIMGids := [], SLDhasFiles := 0, IMGlargerViewPort := 0
   , IMGdecalageY := 1, IMGdecalageX := 1, imgQuality, usrFilesFilteru := ""
   , RandyIMGnow := 0, GDIPToken, Agifu, gdiBitmapSmall
   , gdiBitmapSmallView, gdiBitmapViewScale, msgDisplayTime := 3000
   , slideShowRunning := 0, CurrentSLD := "", winGDIcreated :=0
   , ResolutionWidth, ResolutionHeight
   , gdiBitmap, mainSettingsFile := "ahk-picture-viewer.ini"
   , RegExFilesPattern := "i)(.\\*\.(tif|emf|jpg|png|bmp|gif|tiff|jpeg))$"
   , LargeUIfontValue := 14, version := "2.0.0", AnyWindowOpen := 0, toolTipGuiCreated := 0
   , PrefsLargeFonts := 0, OSDbgrColor := "131209", OSDtextColor := "FFFEFA"
   , OSDfntSize := 14, OSDFontName := "Arial"
   , mustGenerateStaticFolders := 1, lastWinDrag := 1
   , prevFileMovePath := ""
 
 ; User settings
   , WindowBgrColor := "010101", slideShowDelay := 3000
   , IMGresizingMode := 1, SlideHowMode := 1, TouchScreenMode := 1
   , lumosAdjust := 1, GammosAdjust := 0, userimgQuality := 1
   , imgFxMode := 1, FlipImgH := 0, FlipImgV := 0
   , imageAligned := 5, filesFilter := "", isAlwaysOnTop := 0
   , noTooltipMSGs := 1, zoomLevel := 1, skipDeadFiles := 0
   , isTitleBarHidden := 0, lumosGrayAdjust := 0, GammosGrayAdjust := 0
   , MustLoadSLDprefs := 0

imgQuality := (userimgQuality=1) ? 7 : 5
DetectHiddenWindows, On
CoordMode, Mouse, Screen
OnExit, Cleanup

OnMessage(0x200, "WM_MOUSEMOVE")
OnMessage(0x06, "activateMainWin")
OnMessage(0x08, "activateMainWin")
Loop, 9
   OnMessage(255+A_Index, "PreventKeyPressBeep" )   ; 0x100 to 0x108

if !(GDIPToken := Gdip_Startup())
{
   Msgbox, 48, %appTitle%, Error: unable to initialize GDI+... Program exits.
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
Return
;_________________________________________________________________________________________________________________Hotkeys_________________

#If (WinActive("ahk_id " PVhwnd) || WinActive("ahk_id " hGDIwin))
    ~^vk4F::    ; Ctrl+O
       OpenFiles()
    Return

    ~^1::
       Reload
    Return

    ~+vk4F::    ; Shift+O
       OpenFolders()
    Return

    !Space::
       Win_ShowSysMenu(PVhwnd)
    Return

    ~!F4::
    ~Esc::
       Gosub, Cleanup
    Return
#If

#If (WinActive("ahk_id " PVhwnd) && CurrentSLD && maxFilesIndex>1)
    ~^vk4A::    ; Ctrl+J
       Jump2index()
    Return

    ~^vk43::    ; Ctrl+C
       CopyImage2clip()
    Return

    ~k::    ; Ctrl+C
       r1 := resultedFilesList[currentFileIndex]
       r2 := testFileExists(r1)
       MsgBox, % "a" r2
    Return


    ~^+vk43::    ; Ctrl+Shift+C
    ~+vk43::    ; Shift+C
       CopyImagePath()
    Return

    ~vk4F::   ; O
      OpenThisFile()
    Return

    ~vk49::   ; I
      ShowImgInfos()
    Return

    ~vkDB::   ; [
      ChangeLumos(-1)
    Return

    ~vkDD::   ; ]
      ChangeLumos(1)
    Return

    ~+vkDB::   ; Shift + [
      ChangeGammos(-1)
    Return

    ~+vkDD::   ; Shift + ]
      ChangeGammos(1)
    Return

    ~vkDC::   ; \
      ResetImageView()
    Return

    ~^vk45::   ; Ctrl+E
      OpenThisFileFolder()
    Return

    ~^vk46::   ; Ctrl+F
      enableFilesFilter()
    Return

    ~vk53::   ; S
       SwitchSlideModes()
    Return

    ~vk54::   ; T
       ToggleImageSizingMode()
    Return

    ~vkBF::
    ~NumpadDiv::
       IMGresizingMode := 0
       ToggleImageSizingMode()
    Return

    ~NumpadMult::
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

    ~^BackSpace::
    ~+BackSpace::
    ~!BackSpace::
       RandomPicture()
    Return

    ~NumpadAdd::
    ~vkBB::    ; [=]
       ChangeZoom(1)
    Return

    ~NumpadSub::
    ~vkBD::   ; [-]
       ChangeZoom(-1)
    Return

    ~vkBE::    ; [,]
       IncreaseSlideSpeed()
    Return

    ~vkBC::   ; [.]
       DecreaseSlideSpeed()
    Return

    ~F5::
       RefreshFilesList()
    Return

    ~+F5::
       invertRecursiveness()
    Return

    ~vk48::    ; H
       TransformIMGh()
    Return

    ~vk56::    ; V
       TransformIMGv()
    Return

    ~Space::
       InfoToggleSlideShowu()
    Return 

    ~vk52::     ; R
       RandomPicture()
    Return

    ~F2::
       RenameThisFile()
    Return

    ~^vk4D::    ; Ctrl+M
       MoveFile2Dest()
    Return

    ~vk4D::     ; M
       QuickMoveFile2Dest()
    Return

    ~vk46::     ; F
       ToggleImgFX()
    Return

    ~+vk46::     ; Shift+F
       ToggleImgFX(2)
    Return

    ~vk41::     ; A
       ToggleIMGalign()
    Return

    ~F10::
    ~AppsKey::
       Gosub, GuiContextMenu
    Return

    ~Del::
       DeletePicture()
    Return

    ~Up::
       If (IMGlargerViewPort=1 && IMGresizingMode>=3)
          PanIMGonScreen("U")
    Return

    ~Down::
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("D")
    Return

    ~WheelUp::
    ~Right::
       If (slideShowRunning=1)
          ToggleSlideShowu()
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("R")
       Else
          NextPicture()
    Return

    ~WheelDown::
    ~Left::
       If (slideShowRunning=1)
          ToggleSlideShowu()
       If (IMGlargerViewPort=1 && IMGresizingMode=4)
          PanIMGonScreen("L")
       Else
          PreviousPicture()
    Return

    ~PgDn::
       resetSlideshowTimer(0)
       NextPicture()
    Return

    ~PgUp::
       resetSlideshowTimer(0)
       PreviousPicture()
    Return

    ~Home:: 
       FirstPicture()
    Return

    ~End:: 
       LastPicture()
    Return
#If

;_________________________________________________________________________________________________________________Labels__________________

OpenSLD(fileNamu, dontStartSlide:=0) {
  If !FileExist(fileNamu)
  {
     showTOOLtip("ERROR: Failed to load file...")
     SoundBeep 
     SetTimer, RemoveTooltip, % -msgDisplayTime
     Return
  }
  renewCurrentFilesList()
  DynamicFoldersList := CurrentSLD := ""
  filesFilter := usrFilesFilteru := ""
  SLDhasFiles := 0
  mustRemQuotes := 1
  showTOOLtip("Loading files, please wait...")
  WinSetTitle, ahk_id %PVhwnd%,, Loading files - please wait...
  FileReadLine, firstLine, % fileNamu, 1
  If InStr(firstLine, "[General]") 
  {
     mustRemQuotes := 0
     IniRead, UseCachedList, % fileNamu, General, UseCachedList, @
     IniRead, testStaticFolderz, % fileNamu, Folders, Fi1, @
     IniRead, testDynaFolderz, % fileNamu, DynamicFolderz, DF1, @
;     MsgBox, %testStaticFolderz%`n %testDynaFolderz%
     If StrLen(testDynaFolderz)>4
        DynamicFoldersList := "hexists"
  }

  mustGenerateStaticFolders := (InStr(firstLine, "[General]") && StrLen(testStaticFolderz)>8) ? 0 : 1
  If (UseCachedList="Yes" && InStr(firstLine, "[General]")) || !InStr(firstLine, "[General]")
     sldGenerateFilesList(fileNamu, 0, mustRemQuotes)

  If InStr(firstLine, "[General]") 
  {
     If (maxFilesIndex<3 || UseCachedList!="Yes") && (DynamicFoldersList="hexists" && InStr(firstLine, "[General]"))
        ReloadDynamicFolderz(fileNamu)

     IniRead, IgnoreThesePrefs, % fileNamu, General, IgnoreThesePrefs, @
     If (IgnoreThesePrefs="nope") && (MustLoadSLDprefs=1)
        readSlideSettings(fileNamu)
  }

  GenerateRandyList()
  currentFileIndex := 1
  CurrentSLD := fileNamu
  RecentFilesManager()
  If (dontStartSlide=1)
  {
     SetTimer, RemoveTooltip, % -msgDisplayTime
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
  SetTimer, RemoveTooltip, % -msgDisplayTime
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
    If (slideShowRunning=1)
       ToggleSlideShowu()
    resultu := resultedFilesList[currentFileIndex]
    If resultu
    {
       SplitPath, resultu, , dir2open
       Try Run, %dir2open%
    }
}

OpenThisFile() {
    If (slideShowRunning=1)
       ToggleSlideShowu()
    IDshowImage(currentFileIndex, 1)
}

IncreaseSlideSpeed() {
   slideShowDelay := slideShowDelay + 1000
   If (slideShowDelay>12000)
      slideShowDelay := 12500
   resetSlideshowTimer(1)
}

resetSlideshowTimer(showMsg) {
   If (slideShowRunning=1)
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
   slideShowDelay := slideShowDelay - 1000
   If (slideShowDelay<900)
      slideShowDelay := 500
   resetSlideshowTimer(1)
}

CopyImagePath() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  imgpath := resultedFilesList[currentFileIndex]
  If FileExist(imgpath)
  {
     Clipboard := imgpath
     showTOOLtip("File path copied to clipboard...")
     SetTimer, RemoveTooltip, % -msgDisplayTime
  }
}

CopyImage2clip() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  imgpath := resultedFilesList[currentFileIndex]
  FileGetSize, fileSizu, %imgpath%
  If (FileExist(imgpath) && fileSizu>500)
  {
     pBitmap := Gdip_CreateBitmapFromFile(imgpath)
     If !pBitmap
     {
        showTOOLtip("ERROR: Failed to copy image to clipboard...")
        SoundBeep 
        SetTimer, RemoveTooltip, % -msgDisplayTime
        Return
     }
     FlipImgV := FlipImgH := 0
     imgFxMode := 1
     Sleep, 2
     r1 := Gdip_SetBitmapToClipboard(pBitmap)
     Sleep, 2
     Gdip_DisposeImage(pBitmap)
     If r1
        showTOOLtip("Image copied to clipboard...")
     Else
        showTOOLtip("ERROR: Failed to copy the image to clipboard...")
     SetTimer, RemoveTooltip, % -msgDisplayTime
     r2 := IDshowImage(currentFileIndex)
     If !r2
        informUserFileMissing()
  } Else
  {
     showTOOLtip("ERROR: Failed to copy image to clipboard...")
     SoundBeep 
     SetTimer, RemoveTooltip, % -msgDisplayTime
  }
}

invertRecursiveness() {
   If (RegExMatch(CurrentSLD, "i)(\.sld)$") || !CurrentSLD)
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

ReloadThisPicture() {
  Settimer, DelayiedImageDisplay, Off
  If (CurrentSLD && maxFilesIndex>0)
  {
     If (GetKeyState("LButton", "P")=1)
     {
        Settimer, ReloadThisPicture, -550
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

SettingsGUIAGuiEscape:
   CloseWindow()
Return

GuiClose:
Cleanup:
   DestroyGDIbmp()
   ; Gdip_DisposeImage(gdiBitmapSmall)
   writeMainSettings()
   Gdip_Shutdown(GDIPToken)  
   ExitApp
Return

OnlineHelp:
   Try Run, http://www.autohotkey.com/forum/topic62808.html
Return

GuiContextMenu:
   If (slideShowRunning=1)
      ToggleSlideShowu()
   BuildMenu()
Return 

activateMainWin() {
   If (toolTipGuiCreated=1)
      TooltipCreator(1, 1)
}

WinClickAction() {
   Critical, on
   Static lastInvoked := 0
   MouseGetPos, , , OutputVarWin
   TooltipCreator(1, 1)
   If (OutputVarWin!=PVhwnd) || (A_TickCount - lastWinDrag>450) && (isTitleBarHidden=1)
      Return

   If (A_TickCount - lastInvoked<250) && (lastInvoked>1 && CurrentSLD && maxFilesIndex>0)
   {
      If (TouchScreenMode=0)
      {
         OpenFiles()
         lastInvoked := A_TickCount
         Return
      }
      If (slideShowRunning=1)
         InfoToggleSlideShowu()
      Sleep, 25
      ResetImageView()
   } Else If (maxFilesIndex>1 && CurrentSLD)
   {
      If (TouchScreenMode=0)
      {
         lastInvoked := A_TickCount
         Return
      }
      Sleep, 50
      If (A_GuiControl="PicOnGUI3")
         GoNextSlide()
      Else If (A_GuiControl="PicOnGUI1")
         GoPrevSlide()
      Else If (A_GuiControl="PicOnGUI2")
         ToggleViewModeTouch()
   } Else If (!CurrentSLD || maxFilesIndex<1)
   {
      Sleep, 50
      OpenFiles()
   }
   lastInvoked := A_TickCount
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

InfoToggleSlideShowu() {
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

preventScreenOff() {
  If (slideShowRunning=1 && WinActive("A")=PVhwnd)
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
  } Else 
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
  Sleep, 100
  If GetKeyState("LButton", "P")
  {
     SetTimer, GoNextSlide, -200
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
  Sleep, 100
  If GetKeyState("LButton", "P")
  {
     SetTimer, GoPrevSlide, -200
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

DefineFXmodes() {
   friendly := (imgFxMode=1) ? "ORIGINAL" : "GRAYSCALE"
   If (imgFxMode=3)
      friendly := "INVERTED"
   Else If (imgFxMode=4)
      friendly := "PERSONALIZED"
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

ToggleImgFX(dir:=0) {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (dir=2)
      imgFxMode--
   Else
      imgFxMode++

   If (imgFxMode>4)
      imgFxMode := 1
   Else If (imgFxMode<1)
      imgFxMode := 4

   friendly := DefineFXmodes()
   If (imgFxMode=2)
      friendly .= "`nBrightness: " Round(lumosGrayAdjust, 3) "`nGamma: " Round(GammosGrayAdjust, 3)
   Else If (imgFxMode=4)
      friendly .= "`nBrightness: " Round(lumosAdjust, 3) "`nGamma: " Round(GammosAdjust, 3)

   If (imgFxMode=2 || imgFxMode=4)
      friendly .= "`n `nYou can adjust brightness and gamma using`n [ and ] with or without Shift."
   showTOOLtip("Image colors: " friendly)
   SetTimer, RemoveTooltip, % -msgDisplayTime
   writeMainSettings()
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

defineImgAlign() {
   modes := {1:"Top-left corner", 2:"Top-center", 3:"Top-right corner", 4:"Left-center", 5:"Center", 6:"Right-center", 7:"Bottom-left corner", 8:"Bottom-center", 9:"Bottom-right corner"}
   r := modes[imageAligned]
   Return r
}

ToggleIMGalign() {
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

ResetImageView() {
    ChangeLumos(2)
}

ChangeLumos(dir) {
   Static prevValues
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   If (imgFxMode!=2 && imgFxMode!=4 && dir!=2)
      imgFxMode := 4

   If (imgFxMode=2)
   {
      If (dir=1)
         lumosGrayAdjust := lumosGrayAdjust + 0.1
      Else
         lumosGrayAdjust := lumosGrayAdjust - 0.1
      If (lumosGrayAdjust<-25)
         lumosGrayAdjust := -25
      Else If (lumosGrayAdjust>25)
         lumosGrayAdjust := 25
   } Else
   {
      If (dir=1)
         lumosAdjust := lumosAdjust + 0.2
      Else
         lumosAdjust := (lumosAdjust<1) ?  lumosAdjust - 0.1 : lumosAdjust - 0.25

      If (lumosAdjust<0)
         lumosAdjust := 0.001
      Else If (lumosAdjust>25)
         lumosAdjust := 25
   }

   If (dir=2)
   {
      If (imgFxMode=2)
      {
         lumosGrayAdjust := GammosGrayAdjust := 0
      } Else If (imgFxMode=4)
      {
         GammosAdjust := 0
         lumosAdjust := 1
      }

      FlipImgH := FlipImgV := 0
      imgFxMode := 1
      If (IMGresizingMode=4)
         IMGdecalageY := IMGdecalageX := zoomLevel := 1
   }

   value2show := (imgFxMode=2) ? Round(lumosGrayAdjust, 3) : Round(lumosAdjust, 3)
   If (dir=2)
      showTOOLtip("Image colors: UNALTERED")
   Else
      showTOOLtip("Image brightness: " value2show)

   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues)
      Return

   prevValues := newValues
   SetTimer, DelayiedImageDisplay, -10
}

ChangeZoom(dir) {
   Static prevValues

   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (dir=1)
      zoomLevel := (zoomLevel<1 || IMGlargerViewPort=0) ? zoomLevel + 0.05 : zoomLevel + 0.15
   Else
      zoomLevel := (zoomLevel<1 || IMGlargerViewPort=0) ? zoomLevel - 0.05 : zoomLevel - 0.15

   IMGresizingMode := 4
   imageAligned := 5
   If (zoomLevel<0.04)
      zoomLevel := 0.015

   If (zoomLevel>15)
      zoomLevel := 15

   showTOOLtip("Zoom level: " Round(zoomLevel*100) "%")
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues)
      Return

   prevValues := newValues
   SetTimer, DelayiedImageDisplay, -10
}

ChangeGammos(dir) {
   Static prevValues
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (imgFxMode!=2 && imgFxMode!=4)
      imgFxMode := 4

   value2Adjust := (imgFxMode=2) ? GammosGrayAdjust : GammosAdjust
   If (dir=1)
      value2Adjust := value2Adjust + 0.05
   Else
      value2Adjust := value2Adjust - 0.05

   If (value2Adjust<-25)
      value2Adjust := -25
   Else If (value2Adjust>1)
      value2Adjust := 1

   If (imgFxMode=2)
      GammosGrayAdjust := value2Adjust
   Else
      GammosAdjust := value2Adjust

   showTOOLtip("Image gamma: " Round(value2Adjust, 3))
   SetTimer, RemoveTooltip, % -msgDisplayTime
   newValues := "a" GammosGrayAdjust lumosGrayAdjust imageAligned IMGdecalageY IMGdecalageX zoomLevel currentFileIndex imgFxMode IMGresizingMode GammosAdjust lumosAdjust
   If (prevValues=newValues)
      Return

   prevValues := newValues
   SetTimer, DelayiedImageDisplay, -10
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
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

PreviousPicture(dummy:=0, inLoop:=0) {
   currentFileIndex--
   If (currentFileIndex<1)
      currentFileIndex := maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := 1

   r := IDshowImage(currentFileIndex)
   If (!r && inLoop<250)
   {
      inLoop++
      PreviousPicture(0, inLoop)
   } Else inLoop := 0
}

NextPicture(dummy:=0, inLoop:=0) {
   currentFileIndex++
   If (currentFileIndex<1)
      currentFileIndex := maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := 1
   r := IDshowImage(currentFileIndex)
   If (!r && inLoop<250)
   {
      inLoop++
      NextPicture(0, inLoop)
   } Else inLoop := 0
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
   If (direction="U" && FlipImgV=0) || (direction="D" && FlipImgV=1)
      IMGdecalageY := IMGdecalageY + Round(mainHeight*0.1)
   Else If (direction="D" && FlipImgV=0) || (direction="U" && FlipImgV=1)
      IMGdecalageY := IMGdecalageY - Round(mainHeight*0.1)
   Else If (direction="L" && FlipImgH=0) || (direction="R" && FlipImgH=1)
      IMGdecalageX := IMGdecalageX + Round(mainWidth*0.1)
   Else If (direction="R" && FlipImgH=0) || (direction="L" && FlipImgH=1)
      IMGdecalageX := IMGdecalageX - Round(mainWidth*0.1)

   SetTimer, DelayiedImageDisplay, -10
}

DelayiedImageDisplay() {
   r := IDshowImage(currentFileIndex)
   If !r
      informUserFileMissing()
}

ShowImgInfos() {
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

   SplitPath, resultu, OutFileName, OutDir
   Width := Gdip_GetImageWidth(gdiBitmap)
   Height := Gdip_GetImageHeight(gdiBitmap)
   Zoomu := Round(zoomLevel*100)
   MsgBox, 64, %appTitle%: File information, Name:`n%OutFileName%`n`nLocation:`n%OutDir%\`n`nFile size: %fileSizu% kilobytes`nFile created on: %FileDateC%`nFile modified on: %FileDateM%`n`nResolution (W x H): %Width% x %Height% (in pixels)`nCurrent zoom level: %zoomu%`%
}

Jump2index() {
   If (maxFilesIndex<3)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

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

; 3m 24s - GetFileAttributesW
; 26s

; 3m 25s    - PathFileExistsW
; 26 s

; 2m 43s - FindFirstFileW
; 30s

; 3m 25s - FileExist("")
; 25s

informUserFileMissing() {
   showTOOLtip("ERROR: File not found...")
   SoundBeep, 300, 50
   SetTimer, RemoveTooltip, % -msgDisplayTime
}

enableFilesFilter() {
   Static chars2escape := ".+[{()}-]"
   If (maxFilesIndex<3)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(filesFilter)>1
   {
      showTOOLtip("To exclude files matching the string, `nplease insert '&&' (and) into your string`n `nCurrent filter: " filesFilter)
      SetTimer, RemoveTooltip, -5000
   }

   InputBox, usrFilesFilteru, Files filter: %usrFilesFilteru%, Type the string to filter files. Files path and/or name must include the string you provide.,,,,,,,, %usrFilesFilteru%
   If !ErrorLevel
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      showTOOLtip("(Please wait) Applying files filter...")
      If StrLen(filesFilter)<2
      {
         bckpResultedFilesList := []
         bckpResultedFilesList := resultedFilesList.Clone()
         bkcpMaxFilesIndex := maxFilesIndex
      }
      filesFilter := usrFilesFilteru
      Loop, Parse, chars2escape
          filesFilter := StrReplace(filesFilter, A_LoopField, "\" A_LoopField)
      filesFilter := StrReplace(filesFilter, "&")
 ;    MsgBox, % "Z " filesFilter
      FilterFilesIndex()
      If (maxFilesIndex<1)
      {
         MsgBox,, %appTitle%, No files matched your filtering criteria:`n%usrFilesFilteru%`n`nThe application will now reload the full list of files.
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }
      If (maxFilesIndex>0)
         RandomPicture()
      SoundBeep, 950, 100
      SetTimer, RemoveTooltip, % -msgDisplayTime
      CurrentSLD := backCurrentSLD
   }
}

FilterFilesIndex() {
    newFilesList := []
    filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
    Loop, % bkcpMaxFilesIndex + 1
    {
        r := bckpResultedFilesList[A_Index]
        If (InStr(r, "||") || !r)
           Continue

        If StrLen(filesFilter)>1
        {
           z := filterCoreString(r, filterBehaviour, filesFilter)
           If (z=1)
              Continue
        }
        newFilesIndex++
        newFilesList[newFilesIndex] := r
   }
   renewCurrentFilesList()
   resultedFilesList := newFilesList.Clone()
   maxFilesIndex := newFilesIndex
   newFilesList := []
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

SaveFilesList() {
   Critical, on
   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(maxFilesIndex)>1
   {
      If StrLen(filesFilter)>1
         MsgBox, 64, %appTitle%: Save slideshow, The files list is filtered down to %maxFilesIndex% files from %bkcpMaxFilesIndex%.`n`nTo save as a slideshow the entire list of files, remove the filter.
      FileSelectFile, file2save, S2, % CurrentSLD, Save files list as Slideshow, Slideshow (*.sld)
   }

   If (!ErrorLevel && StrLen(file2save)>3)
   {
      If !RegExMatch(file2save, "i)(.\.sld)$")
         file2save .= ".sld"
      If FileExist(file2save)
      {
         SplitPath, file2save, OutFileName, OutDir
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
      IniWrite, Yes, % file2save, General, UseCachedList
      Sleep, 10
      writeSlideSettings(file2save)
      WinSetTitle, ahk_id %PVhwnd%,, Saving slideshow - please wait...
      showTOOLtip("Saving list of " maxFilesIndex " entries into...`n" file2save "`nPlease wait...")
      thisTmpFile := !newTmpFile ? backCurrentSLD : newTmpFile
      saveDynaFolders := (DynamicFoldersList="hexists") ? coreLoadDynaFolders(thisTmpFile) : DynamicFoldersList
      dynaFolderListu := "`n[DynamicFolderz]`n"
      Loop, Parse, saveDynaFolders, `n
      {
          If (StrLen(A_LoopField)<4 || !FileExist(A_LoopField))
             Continue
          countDynas++
          dynaFolderListu .= "DF" countDynas "=" A_LoopField "`n"
      }

      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r)
             Continue
          If (mustGenerateStaticFolders=1)
          {
             SplitPath, r,, OutDir
             foldersList .= OutDir "`n"
          }
          filesListu .= r "`n"
      }
      Sort, foldersList, U D`n
      foldersListu := "`n[Folders]`n"
      If (mustGenerateStaticFolders=1)
      {
         Loop, Parse, foldersList, `n
         {
             If !A_LoopField
                Continue
             FileGetTime, dirDate, % A_LoopField, M
             foldersListu .= "Fi" A_Index "=" dirDate "*&*" A_LoopField "`n"
         }
      } Else
      {
         thisTmpFile := !newTmpFile ? backCurrentSLD : newTmpFile
         foldersListu .= LoadStaticFoldersCached(thisTmpFile)
      }

      foldersListu .= "`n[FilesList]`n"
      Sleep, 10
      FileAppend, % dynaFolderListu, % file2save, UTF-16
      Sleep, 10
      FileAppend, % foldersListu, % file2save, UTF-16
      Sleep, 10
      FileAppend, % filesListu, % file2save, UTF-16
      throwMSGwriteError()
      FileDelete, % newTmpFile
      SetTimer, RemoveTooltip, % -msgDisplayTime
      CurrentSLD := file2save
      DynamicFoldersList := "hexists"
      mustGenerateStaticFolders := 0
      SoundBeep, 900, 100
      r := IDshowImage(currentFileIndex)
      If !r
         informUserFileMissing()
   }
}

LoadStaticFoldersCached(fileNamu) {
   Loop, 9876
   {
       IniRead, newFolder, % fileNamu, Folders, Fi%A_Index%, @
       If (StrLen(newFolder)>8 && InStr(newFolder, "*&*"))
          staticFoldersListCache .= "Fi" A_Index "=" newFolder "`n"
       Else countFails++
       If (countFails>3)
          Break
   }
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
      CurrentSLD := ""
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
      showTOOLtip("Checking files list, please wait...")
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r)
             Continue

          If StrLen(backfilesFilter)>1
          {
             z := filterCoreString(r, filterBehaviour, backfilesFilter)
             noFilesCheck := (z=1) ? 2 : WnoFilesCheck
          }

          If (noFilesCheck!="2")
          {
             If (testFileExists(r)>100)
;             If FileExist(r)
                filesListu .= r "`n"
          } Else filesListu .= r "`n"
      }
      showTOOLtip("(Please wait) Removing duplicates from the list...")
      Sort, filesListu, U D`n
      renewCurrentFilesList()
      Loop, Parse, filesListu,`n
      {
          If StrLen(A_LoopField)<2
             Continue

          maxFilesIndex++
          resultedFilesList[maxFilesIndex] := A_LoopField
      }

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
   MsgBox, 52, %appTitle%, This operation can take a lot of time. Each file will be read to identify its resolution in pixels. Are you sure you want to sort the list?
   IfMsgBox, Yes
        SortFilesList("resolution")
}

SortFilesList(SortCriterion) {
   Critical, on

   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      If StrLen(filesFilter)>1
      {
         MsgBox, 64, %appTitle%: Sort operation, The files list is filtered down to %maxFilesIndex% files from %bkcpMaxFilesIndex%. Only the files matched by current filter will be sorted, not all the files.`n`nTo sort all files, remove the filter.
         filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
         showTOOLtip("(Please wait) Preparing the files list...")
         backfilesFilter := filesFilter
         backusrFilesFilteru := usrFilesFilteru
         usrFilesFilteru := filesFilter := ""
         FilterFilesIndex()
      }

      WinSetTitle, ahk_id %PVhwnd%,, Sorting files list - please wait...
      showTOOLtip("(Please wait) Gathering files information...")
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
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
             op := GetImgDimension(r, Wi, He)
             SortBy := (op=1) ? Round(Wi/100 * He/100) : 0
          }

          If StrLen(SortBy)>1
             filesListu .= SortBy " |!\!|" r "`n"
      }
      Sort, filesListu, N D`n
      showTOOLtip("Generating files index...")
      renewCurrentFilesList()
      Loop, Parse, filesListu,`n
      {
          If StrLen(A_LoopField)<2
             Continue
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
     IniRead, tstimageAligned, %readThisFile%, General, imageAligned, @
     IniRead, tstnoTooltipMSGs, %readThisFile%, General, noTooltipMSGs, @
     IniRead, tstuserimgQuality, %readThisFile%, General, userimgQuality, @
     IniRead, tstTouchScreenMode, %readThisFile%, General, TouchScreenMode, @
     IniRead, tstskipDeadFiles, %readThisFile%, General, skipDeadFiles, @
     IniRead, tstisAlwaysOnTop, %readThisFile%, General, isAlwaysOnTop, @
     IniRead, tstisTitleBarHidden, %readThisFile%, General, isTitleBarHidden, @

     If (tstslideshowdelay!="@" && tstslideshowdelay>300)
        slideShowDelay := tstslideShowDelay
     If (tstimgresizingmode!="@" && StrLen(tstIMGresizingMode)=1 && tstIMGresizingMode<5)
        IMGresizingMode := tstIMGresizingMode
     If (tstimgFxMode!="@" && StrLen(tstimgFxMode)=1 && tstimgFxMode<5)
        imgFxMode := tstimgFxMode
     If (tstnoTooltipMSGs=1 || tstnoTooltipMSGs=0)
        noTooltipMSGs := tstnoTooltipMSGs
     If (tstTouchScreenMode=1 || tstTouchScreenMode=0)
        TouchScreenMode := tstTouchScreenMode
     If (tstuserimgQuality=1 || tstuserimgQuality=0)
        userimgQuality := tstuserimgQuality
     If (tstFlipImgV=1 || tstFlipImgV=0)
        FlipImgV := tstFlipImgV
     If (tstskipDeadFiles=1 || tstskipDeadFiles=0)
        skipDeadFiles := tstskipDeadFiles
     If (tstFlipImgH=1 || tstFlipImgH=0)
        FlipImgV := tstFlipImgV
     If (tstisAlwaysOnTop=1 || tstisAlwaysOnTop=0)
        isAlwaysOnTop := tstisAlwaysOnTop
     If (tstisTitleBarHidden=1 || tstisTitleBarHidden=0)
        isTitleBarHidden := tstisTitleBarHidden
     If (tstslidehowmode!="@" && StrLen(tstSlideHowMode)=1 && tstSlideHowMode<4)
        SlideHowMode := tstSlideHowMode
     If (tstimageAligned!="@" && StrLen(tstimageAligned)=1 && tstimageAligned<10)
        imageAligned := tstimageAligned

     If (tstWindowBgrColor!="@" && StrLen(tstWindowBgrColor)=6)
     {
        WindowBgrColor := tstWindowBgrColor
        If (scriptInit=1)
           Gui, 1: Color, %tstWindowBgrColor%
     }
     If (tstfilesFilter!="@" && StrLen(Trim(tstfilesFilter))>2)
        usrFilesFilteru := tstfilesFilter

     If (tstlumosAdjust!="@")
        lumosAdjust := tstlumosAdjust
     If (tstGammosAdjust!="@")
        GammosAdjust := tstGammosAdjust

     If (tstlumosGrAdjust!="@")
        lumosGrayAdjust := tstlumosGrAdjust
     If (tstGammosGrAdjust!="@")
        GammosGrayAdjust := tstGammosGrAdjust

     If (isTitleBarHidden=1)
        Gui, 1: -Caption
     Else
        Gui, 1: +Caption

     imgQuality := (userimgQuality=1) ? 7 : 5
     WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
}

writeMainSettings() {
    writeSlideSettings(mainSettingsFile)
    IniWrite, % MustLoadSLDprefs, % mainSettingsFile, General, MustLoadSLDprefs
    IniWrite, % prevFileMovePath, % mainSettingsFile, General, prevFileMovePath
}

loadMainSettings() {
    readSlideSettings(mainSettingsFile)
    IniRead, tstMustLoadSLDprefs, % mainSettingsFile, General, MustLoadSLDprefs, @
    IniRead, tstprevFileMovePath, % mainSettingsFile, General, prevFileMovePath, @
    If (tstMustLoadSLDprefs=1 || tstMustLoadSLDprefs=0)
       MustLoadSLDprefs := tstMustLoadSLDprefs

    If (tstprevFileMovePath!="@" || StrLen(tstprevFileMovePath)>3)
       prevFileMovePath := tstprevFileMovePath
}

writeSlideSettings(file2save) {
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
    IniWrite, % imageAligned, %file2save%, General, imageAligned
    IniWrite, % userimgQuality, %file2save%, General, userimgQuality
    IniWrite, % noTooltipMSGs, %file2save%, General, noTooltipMSGs
    IniWrite, % TouchScreenMode, %file2save%, General, TouchScreenMode
    IniWrite, % skipDeadFiles, %file2save%, General, skipDeadFiles
    IniWrite, % isAlwaysOnTop, %file2save%, General, isAlwaysOnTop
    IniWrite, % isTitleBarHidden, %file2save%, General, isTitleBarHidden
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

RecentFilesManager() {
  readRecentEntries()
  entry2add := CurrentSLD
  If StrLen(entry2add)<4
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

      If StrLen(A_LoopField)<4
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
   r := IDshowImage(currentFileIndex)
   If (!r && inLoop<250)
   {
      inLoop++
      RandomPicture(0, inLoop)
   } Else inLoop := 0
}

PrevRandyPicture(dummy:=0, inLoop:=0) {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   RandyIMGnow--
   If (RandyIMGnow<1)
      RandyIMGnow := maxFilesIndex
   If (RandyIMGnow>maxFilesIndex)
      RandyIMGnow := 1

   currentFileIndex := RandyIMGids[RandyIMGnow]
   r := IDshowImage(currentFileIndex)
   If (!r && inLoop<250)
   {
      inLoop++
      PrevRandyPicture(0, inLoop)
   } Else inLoop := 0
}

DeletePicture() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  Sleep, 5
  file2rem := resultedFilesList[currentFileIndex]
  file2rem := StrReplace(file2rem, "||")
  SplitPath, file2rem, OutFileName, OutDir
  FileSetAttrib, -R, %file2rem%
  Sleep, 5
  FileDelete, %file2rem%
  resultedFilesList[currentFileIndex] := "||" file2rem
  If ErrorLevel
  {
     showTOOLtip("File already deleted or access denied...")
     SoundBeep, 300, 900
  } Else showTOOLtip("File deleted...`n" OutFileName "`n" OutDir)

  If StrLen(filesFilter)>1
  {
     z := detectFileIDbkcpList(file2rem)
     If (z!="fail" && z>=1)
        bckpResultedFilesList[z] := "||" file2rem
  }
  Sleep, 50
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

RenameThisFile() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  Sleep, 2
  file2rem := resultedFilesList[currentFileIndex]
  SplitPath, file2rem, OutFileName, OutDir
  If !FileExist(file2rem)
  {
     showTOOLtip("File does not exist or access denied...`n" OutFileName "`n" OutDir)
     SetTimer, RemoveTooltip, % -msgDisplayTime
     SoundBeep 
     Return
  }

  InputBox, newFileName, Rename file, Please type the new file name.,,,,,,,, %OutFileName%
  If !ErrorLevel
  {
     If FileExist(OutDir "\" newFileName)
     {
        SoundBeep 
        MsgBox, 52, %appTitle%, A file with the name provided already exists.`nDo you want to overwrite it?`n`n%newFileName%
        IfMsgBox, Yes
        {
           FileSetAttrib, -R, %file2rem%
           Sleep, 2
           FileDelete, %OutDir%\%newFileName%
        } Else
        {
           showTOOLtip("Rename operation canceled...")
           SetTimer, RemoveTooltip, % -msgDisplayTime
           Return
        }
     }

     Sleep, 2
     FileMove, %file2rem%, %OutDir%\%newFileName%
     If ErrorLevel
     {
        showTOOLtip("ERROR: Access denied... File could not be renamed.")
        SoundBeep
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

MoveFile2Dest() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   Sleep, 2
   file2rem := resultedFilesList[currentFileIndex]
   SplitPath, file2rem, OldOutFileName, OldOutDir
   If !FileExist(file2rem)
   {
      showTOOLtip("File does not exist or access denied...`n" OldOutFileName "`n" OldOutDir)
      SetTimer, RemoveTooltip, % -msgDisplayTime
      SoundBeep 
      Return
   }

   FileSelectFile, file2save, S2, % file2rem, Move file to, select destination..., All files (*.*)
   If (!ErrorLevel && StrLen(file2save)>3)
   {
      SplitPath, file2save, NewOutFileName, NewOutDir
      If (NewOutDir=OldOutDir)
      {
         showTOOLtip("Destination equals to initial location...`nOperation ignored.")
         SetTimer, RemoveTooltip, % -msgDisplayTime
         Return
      }

      file2save := NewOutDir "\" OldOutFileName
      If FileExist(file2save)
      {
         MsgBox, 52, %appTitle%, A file with the same name already exists in the destination folder... Do you want to overwrite the file?`n`n%OldOutFileName%`n%NewOutDir%
         IfMsgBox, Yes
         {
            FileSetAttrib, -R, %file2save%
            Sleep, 5
            FileDelete, %file2save%
            Sleep, 5
            FileMove, %file2rem%, %file2save%, 1
            If !ErrorLevel
            {
               wasNoError := 1
               prevFileMovePath := NewOutDir
            }
            throwMSGwriteError()
         } Else Return
      } Else
      {
         FileMove, %file2rem%, %file2save%, 1
         If !ErrorLevel
         {
            wasNoError := 1
            prevFileMovePath := NewOutDir
         }
         throwMSGwriteError()
      }

      If (StrLen(prevFileMovePath)>3 && wasNoError=1)
      {
         writeMainSettings()
         showTOOLtip("File moved to...`n" NewOutDir "\")
         resultedFilesList[currentFileIndex] := file2save
         SetTimer, RemoveTooltip, % -msgDisplayTime
      }
   }
}

QuickMoveFile2Dest() {
   If (slideShowRunning=1)
      ToggleSlideShowu()
 
   Sleep, 2
   file2rem := resultedFilesList[currentFileIndex]
   SplitPath, file2rem, OldOutFileName, OldOutDir
   If !FileExist(file2rem)
   {
      showTOOLtip("File does not exist or access denied...`n" OldOutFileName "`n" OldOutDir)
      SetTimer, RemoveTooltip, % -msgDisplayTime
      SoundBeep 
      Return
   }

   If (OldOutDir=prevFileMovePath)
   {
      showTOOLtip("Destination equals to initial location...`nOperation ignored.")
      SetTimer, RemoveTooltip, % -msgDisplayTime
      Return
   }

   If StrLen(prevFileMovePath)>3
   {
      file2save := prevFileMovePath "\" OldOutFileName
      If FileExist(file2save)
      {
         MsgBox, 52, %appTitle%, A file with the same name already exists in the destination folder... Do you want to overwrite the file?`n`n%OldOutFileName%`n%NewOutDir%
         IfMsgBox, Yes
         {
            FileSetAttrib, -R, %file2save%
            Sleep, 5
            FileDelete, %file2save%
            Sleep, 5
            FileMove, %file2rem%, %file2save%, 1
            If ErrorLevel
               wasError := 1
            throwMSGwriteError()
         } Else Return
      } Else
      {
         FileMove, %file2rem%, %file2save%, 1
         If ErrorLevel
            wasError := 1
      }

      If (wasError!=1)
      {
         showTOOLtip("File moved to...`n" prevFileMovePath "\")
         resultedFilesList[currentFileIndex] := file2save
         SetTimer, RemoveTooltip, % -msgDisplayTime
      }
   } Else MoveFile2Dest()
}

OpenFolders() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   FileSelectFolder, SelectedDir, *%A_WorkingDir%, 2, Select the folder with images. All images found in sub-folders will be loaded as well.
   If (SelectedDir)
      coreOpenFolder(SelectedDir)
}

renewCurrentFilesList() {
  prevRandyIMGs := []
  prevRandyIMGnow := 0
  resultedFilesList := []
  maxFilesIndex := 0
  currentFileIndex := 1
}

coreOpenFolder(thisFolder, doOptionals:=1) {
   If StrLen(thisFolder)>3
   {
      usrFilesFilteru := filesFilter := CurrentSLD := ""
      WinSetTitle, ahk_id %PVhwnd%,, Loading files - please wait...
      renewCurrentFilesList()
      GetFilesList(thisFolder "\*")
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
   }
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
     coreOpenFolder(CurrentSLD)
}

OpenFiles() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    pattern := "Images (*.jpg; *.bmp; *.png; *.gif; *.tif; *.emf; *.sld; *.jpeg; *.tiff)"
    FileSelectFile, SelectImg, M1, %A_WorkingDir%, Open Image or Slideshow, %pattern%
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
      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      coreOpenFolder("|" SelectedDir, 0)
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
   }
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
   Loop, parse, A_GuiEvent, `n
   {
;     MsgBox, % A_LoopField
      If (A_Index>1500)
         Break
      Else If RegExMatch(A_LoopField, "i)(\.(jpg|emf|tiff|tif|jpeg|png|bmp|gif|sld))$")
         imgpath := A_LoopField
   }

   if (imgpath)
   {
      showTOOLtip("Opening file...")
      If (slideShowRunning=1)
         ToggleSlideShowu()

      SplitPath, imgpath,,imagedir
      If !imagedir
         Return

      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      coreOpenFolder("|" imagedir, 0)
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
   }
Return

showTOOLtip(msg) {
   If (WinActive("A")=PVhwnd) && (noTooltipMSGs=0)
   {
      ; Tooltip, %msg%
      TooltipCreator(msg)
   } Else
   {
      msg := StrReplace(msg, "`n", "  ")
      WinSetTitle, ahk_id %PVhwnd%,, % msg
      Sleep, 5
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

GetImgDimension(imgpath, ByRef w, ByRef h) {
   Static prevImgPath, prevW, prevH
   If (prevImgPath=imgpath && h>1 && w>1)
   {
      W := prevW
      H := prevH
      Return 1
   }

   pBM := Gdip_CreateBitmapFromFile(imgpath)
   w := Gdip_GetImageWidth( pBM )
   h := Gdip_GetImageHeight( pBM )
   Gdip_DisposeImage( pBM )
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

BuildMenu() {
   Static wasCreated
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
   }

   sliSpeed := Round(slideShowDelay/1000, 2) " sec."
   Menu, PVsliMenu, Add, &Start slideshow`tSpace, ToggleSlideShowu
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Toggle slideshow mode`tS, SwitchSlideModes
   Menu, PVsliMenu, Add, % DefineSlideShowType(), SwitchSlideModes
   Menu, PVsliMenu, Disable, % DefineSlideShowType()
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Increase speed`tMinus [-], IncreaseSlideSpeed
   Menu, PVsliMenu, Add, &Decrease speed`tEqual [=], DecreaseSlideSpeed
   Menu, PVsliMenu, Add, Current speed: %sliSpeed%, DecreaseSlideSpeed
   Menu, PVsliMenu, Disable, Current speed: %sliSpeed%

   infolumosAdjust := (imgFxMode=4) ? Round(lumosAdjust, 2) : Round(lumosGrayAdjust, 2)
   infoGammosAdjust := (imgFxMode=4) ? Round(GammosAdjust, 2) : Round(GammosGrayAdjust, 2)
   Menu, PVview, Add, Image &alignment: %imageAligned%`tA, ToggleIMGalign
   Menu, PVview, Add, % defineImgAlign(), ToggleIMGalign
   Menu, PVview, Disable, % defineImgAlign()
   Menu, PVview, Add,
   Menu, PVview, Add, &Toggle Resizing Mode`tT, ToggleImageSizingMode
   Menu, PVview, Add, % DefineImgSizing(), ToggleImageSizingMode
   Menu, PVview, Disable, % DefineImgSizing()
   Menu, PVview, Add,
   Menu, PVview, Add, &Switch colors display`tF, ToggleImgFX
   Menu, PVview, Add, % DefineFXmodes(), ToggleImgFX
   Menu, PVview, Disable, % DefineFXmodes()
   If (imgFxMode=4 || imgFxMode=2)
   {
      Menu, PVview, Add, Br: %infolumosAdjust% / Ga: %infoGammosAdjust%, ToggleImgFX
      Menu, PVview, Disable, Br: %infolumosAdjust% / Ga: %infoGammosAdjust%
   }
   Menu, PVview, Add,
   Menu, PVview, Add, Mirror &horizontally`tH, TransformIMGh
   Menu, PVview, Add, Mirror &vertically`tV, TransformIMGv
   Menu, PVview, Add,
   Menu, PVview, Add, Reset image vie&w`t\, ResetImageView
   If (FlipImgV=1)
      Menu, PVview, Check, Mirror &vertically`tV

   If (FlipImgH=1)
      Menu, PVview, Check, Mirror &horizontally`tH

   Menu, PVnav, Add, &First`tHome, FirstPicture
   Menu, PVnav, Add, &Previous`tRight, PreviousPicture
   Menu, PVnav, Add, &Next`tLeft, NextPicture
   Menu, PVnav, Add, &Last`tEnd, LastPicture
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Jump at #`tCtrl+J, Jump2index
   Menu, PVnav, Add, &Random`tR, RandomPicture
   Menu, PVnav, Add, &Prev. random image`tBackspace, PrevRandyPicture

   StringRight, infoPrevMovePath, prevFileMovePath, 25
   Menu, PVtFile, Add, &Copy image to Clipboard`tCtrl+C, CopyImage2clip
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, &Open (with external app)`tO, OpenThisFile
   Menu, PVtFile, Add, &Open containing folder`tCtrl+E, OpenThisFileFolder
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, &Delete`tDelete, DeletePicture
   Menu, PVtFile, Add, &Rename`tF2, RenameThisFile
   Menu, PVtFile, Add, &Move file to...`tCtrl+M, MoveFile2Dest
   If infoPrevMovePath
      Menu, PVtFile, Add, %infoPrevMovePath%`tM, QuickMoveFile2Dest
   Menu, PVtFile, Add,
   Menu, PVtFile, Add, &Information`tI, ShowImgInfos

   Menu, PVsort, Add, &Path and name, ActSortName
   Menu, PVsort, Add, &File size, ActSortSize
   Menu, PVsort, Add, &Modified date, ActSortModified
   Menu, PVsort, Add, &Created date, ActSortCreated
   Menu, PVsort, Add, &Resolution (very slow), ActSortResolution

   defMenuRefresh := RegExMatch(CurrentSLD, "i)(\.sld)$") ? "&Reload .SLD file" : "&Refresh opened folder(s)"
   StringRight, defMenuRefreshItm, CurrentSLD, 30
   If defMenuRefreshItm
   {
      Menu, PVfList, Add, %defMenuRefresh%`tF5, RefreshFilesList
      Menu, PVfList, Add, %defMenuRefreshItm%, RefreshFilesList
      Menu, PVfList, Disable, %defMenuRefreshItm%
   }
   Menu, PVfList, Add,
   If (maxFilesIndex>2)
   {
      Menu, PVfList, Add, Save list as slideshow, SaveFilesList
      Menu, PVfList, Add,
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && SLDhasFiles=1)
         Menu, PVfList, Add, &Clean duplicate/inexistent entries, cleanFilesList
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && StrLen(DynamicFoldersList)>6)
         Menu, PVfList, Add, &Regenerate the entire list, RegenerateEntireList
      Menu, PVfList, Add, &Text filtering`tCtrl+F, enableFilesFilter
      If StrLen(filesFilter)>1
         Menu, PVfList, Check, &Text filtering`tCtrl+F
      Menu, PVfList, Add,
      Menu, PVfList, Add, &Sort by, :PVsort
   }

   Menu, PVprefs, Add, &Always on top, ToggleAllonTop
   Menu, PVprefs, Add, &Hide title bar, ToggleTitleBaru
   Menu, PVprefs, Add, &No OSD information, ToggleInfoToolTips
   Menu, PVprefs, Add, &High quality resampling, ToggleImgQuality
   Menu, PVprefs, Add, &Touch screen mode, ToggleTouchMode
   Menu, PVprefs, Add, &Skip missing files, ToggleSkipDeadFiles
   Menu, PVprefs, Add, 
   Menu, PVprefs, Add, &Ignore stored SLD settings, ToggleIgnoreSLDprefs
   If (MustLoadSLDprefs=0)
      Menu, PVprefs, Check, &Ignore stored SLD settings
   If (userimgQuality=1)
      Menu, PVprefs, Check, &High quality resampling
   If (skipDeadFiles=1)
      Menu, PVprefs, Check, &Skip missing files
   If (isAlwaysOnTop=1)
      Menu, PVprefs, Check, &Always on top
   If (noTooltipMSGs=1)
      Menu, PVprefs, Check, &No OSD information
   If (TouchScreenMode=1)
      Menu, PVprefs, Check, &Touch screen mode
   If (isTitleBarHidden=1)
      Menu, PVprefs, Check, &Hide title bar


   readRecentEntries()
   Menu, PVopenF, Add, &Open File`tCtrl+O, OpenFiles
   Menu, PVopenF, Add, &Open Folders`tShift+O, OpenFolders
   Menu, PVopenF, Add,
   Loop, Parse, historyList, `n
   {
      If (A_Index>15)
         Break

      If StrLen(A_LoopField)<4
         Continue
      countItemz++
      StringRight, entryu, A_LoopField, 25
      Menu, PVopenF, Add, &%countItemz%. %entryu%, OpenRecentEntry
   }
   If (countItemz>0)
   {
      Menu, PVopenF, Add, 
      Menu, PVopenF, Add, &Erase history, EraseHistory
   }

   Menu, PVmenu, Add, &Open..., :PVopenF
   Menu, PVmenu, Add,
   If (maxFilesIndex>0 && CurrentSLD)
   {
      Menu, PVmenu, Add, C&urrent file, :PVtFile
      Menu, PVmenu, Add, Files l&ist, :PVfList
      Menu, PVmenu, Add, Vie&w, :PVview
      If (maxFilesIndex>1 && CurrentSLD)
      {
         Menu, PVmenu, Add, Navigation, :PVnav
         Menu, PVmenu, Add, Slideshow, :PVsliMenu
      }
      Menu, PVmenu, Add,
   }

   Menu, PVmenu, Add, Prefe&rences, :PVprefs
   Menu, PVmenu, Add, About, AboutWindow
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, &Exit`tEsc, Cleanup
   wasCreated := 1
   Menu, PVmenu, Show
}

EraseHistory() {
   historyList := ""
   Loop, 15
       IniWrite, 0, % mainSettingsFile, Recents, E%A_Index%
}

OpenRecentEntry() {
  openThisu := SubStr(A_ThisMenuItem, 2, InStr(A_ThisMenuItem, ". ")-2)
  IniRead, newEntry, % mainSettingsFile, Recents, E%openThisu%, @
; MsgBox, %openthisu% -- %newentry%
  newEntry := Trim(newEntry)
  If StrLen(newEntry)>4
  {
     If RegExMatch(newEntry, "i)(\.sld)$")
        OpenSLD(newEntry)
     Else
        coreOpenFolder(newEntry)
  }
}

ToggleAllonTop() {
   isAlwaysOnTop := !isAlwaysOnTop
   If (isAlwaysOnTop=1)
      WinSet, AlwaysOnTop, 1, ahk_id %PVhwnd%
   Else
      WinSet, AlwaysOnTop, 0, ahk_id %PVhwnd%
   writeMainSettings()
}

ToggleTitleBaru() {
   isTitleBarHidden := !isTitleBarHidden
   If (isTitleBarHidden=1)
      Gui, 1: -Caption
   Else
      Gui, 1: +Caption
   writeMainSettings()
}

ToggleInfoToolTips() {
    noTooltipMSGs := !noTooltipMSGs
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

ToggleTouchMode() {
    TouchScreenMode := !TouchScreenMode
    writeMainSettings()
}

defineWinTitlePrefix() {
   If StrLen(usrFilesFilteru)>1
      winPrefix .= "F "

   If (slideShowRunning=1)
   {
      winPrefix .= "S"
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

   If (imgFxMode=2)
      winPrefix .= "G "
   Else If (imgFxMode=3)
      winPrefix .= "I "
   Else If (imgFxMode=4)
      winPrefix .= "A "

   If (IMGresizingMode=3)
      winPrefix .= "O "
   Else If (IMGresizingMode=4)
      winPrefix .= "Z "

   Return winPrefix
}

SetParentID(Window_ID, theOther) {
  Return DllCall("SetParent", "uint", theOther, "uint", Window_ID) ; success = handle to previous parent, failure =null 
}

BuildGUI() {
   Global PicOnGUI1, PicOnGUI2, PicOnGUI3
   ; local MaxGUISize, MinGUISize, initialwh, guiw, guih
   MaxGUISize = -DPIScale
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialwh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3
   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MaxGUISize% %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Add, Text, x1 y1 w1 h1 BackgroundTrans gWinClickAction vPicOnGui1 hwndhPicOnGui1,
   Gui, 1: Add, Text, x2 y2 w2 h2 BackgroundTrans gWinClickAction vPicOnGui2,
   Gui, 1: Add, Text, x3 y3 w3 h3 BackgroundTrans gWinClickAction vPicOnGui3,

   Gui, 1: Show, Maximize Center %initialwh%, %appTitle%
   createGDIwin()
   updateUIctrl()
}

updateUIctrl() {
   GetClientSize(GuiW, GuiH, PVhwnd)
   ctrlW := GuiW//3
   ctrlX1 := ctrlW
   ctrlX2 := ctrlW * 2
   GuiControl, 1: Move, PicOnGUI1, % "w" ctrlW " h" GuiH
   GuiControl, 1: Move, PicOnGUI2, % "w" ctrlW " h" GuiH " x" ctrlX1
   GuiControl, 1: Move, PicOnGUI3, % "w" ctrlW " h" GuiH " x" ctrlX2
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
   Gui, 2: -DPIScale +E0x20 -Caption +E0x80000 +ToolWindow -OwnDialogs +hwndhGDIwin +Owner
   Gui, 2: Show, NoActivate, %appTitle%: Picture container
   SetParentID(PVhwnd, hGDIwin)
   Sleep, 5
   WinActivate, ahk_id %PVhwnd%
   Sleep, 5
   winGDIcreated := 1
}

ShowTheImage(imgpath, usePrevious:=0) {
   Critical, on

   Static prevImgPath, lastInvoked2 := 1, counteru
        , lastInvoked := 1, prevPicCtrl := 1

   If (imgpath=prevImgPath && StrLen(prevImgPath)>3 && usePrevious!=2)
      usePrevious := 1
   If (usePrevious=2)
   {
      wasForcedHigh := 1
      usePrevious := 0
   }

   FileGetSize, fileSizu, %imgpath%
   SplitPath, imgpath, OutFileName, OutDir
   If (IMGresizingMode=4)
      zoomu := " [" Round(zoomLevel * 100) "%]"
   winTitle := currentFileIndex "/" maxFilesIndex zoomu " | " OutFileName " | " OutDir
   If (!FileExist(imgpath) && !fileSizu && usePrevious=0)
   {
      If (WinActive("A")=PVhwnd)
      {
         winTitle := "[*] " winTitle
         WinSetTitle, ahk_id %PVhwnd%,, % winTitle
         showTOOLtip("ERROR: Unable to load file...`n" OutFileName "`n" OutDir)
         SetTimer, RemoveTooltip, % -msgDisplayTime
      }

      If (A_TickCount - lastInvoked2>125) && (A_TickCount - lastInvoked>95)
      {
         SoundBeep, 300, 50
         lastInvoked2 := A_TickCount
      }
      lastInvoked := A_TickCount
      Return "fail"
   }

   If (A_TickCount - lastInvoked>85) && (A_TickCount - lastInvoked2>85) || (usePrevious=1)
   {
       lastInvoked := A_TickCount
       r2 := ResizeImage(imgpath, usePrevious)
       If !r2
       {
          If (WinActive("A")=PVhwnd)
          {
             showTOOLtip("ERROR: Unable to display the image...")
             SetTimer, RemoveTooltip, % -msgDisplayTime
          }
          SoundBeep, 300, 100
          Return "fail"
       } Else prevImgPath := imgpath
       lastInvoked := A_TickCount
   } Else ; If (wasForcedHigh!=1)
   {
       If (noTooltipMSGs=1)
          SetTimer, RemoveTooltip, Off
       winPrefix := defineWinTitlePrefix()
       WinSetTitle, ahk_id %PVhwnd%,, % winPrefix winTitle
       SetTimer, ReloadThisPicture, -290
   }
   lastInvoked2 := A_TickCount
}

calcImgSize(modus, imgW, imgH, GuiW, GuiH, ByRef ResizedW, ByRef ResizedH) {
   PicRatio := Round(imgW/imgH, 5)
   GuiRatio := Round(GuiW/GuiH, 5)
   if (imgW <= GuiW) && (imgH <= GuiH)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio, 5)
      If (ResizedH>GuiH)
      {
         ResizedH := (imgH <= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
         ResizedW := Round(ResizedH * PicRatio, 5)
      }   

      If (modus=2)
      {
         ResizedW := imgW
         ResizedH := imgH
      }
   } else if (PicRatio > GuiRatio)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio, 5)
   } else
   {
      ResizedH := (imgH >= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
      ResizedW := Round(ResizedH * PicRatio, 5)
   }
}

ResizeImage(imgpath, usePrevious) {
    Static oImgW, oImgH, prevImgPath, prevImgW, prevImgH
         , mainX, mainY, tinyW, tinyH, wscale
    If (winGDIcreated!=1)
       createGDIwin()

    If (imgpath!=prevImgPath || !gdiBitmap)
    {
       DestroyGDIbmp()
       Sleep, 1
       CloneMainBMP(imgpath, oImgW, oImgH)
    }

    If (!gdiBitmap || ErrorLevel)
    {
       SoundBeep 
       Return 0
    }

   prevImgPath := imgpath
   GetClientSize(GuiW, GuiH, PVhwnd)
   If (usePrevious!=1)
   {
      WinGetPos, mainX, mainY,,, ahk_id %PVhwnd%
      prevImgW := imgW := oImgW
      prevImgH := imgH := oImgH
   } Else If (usePrevious=1) 
   {
      RescaleBMPtiny(imgpath, prevImgW, prevImgH, tinyW, tinyH)
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
      zoomLevel := Round(ResizedW / imgW, 3)
      ws := Round(ResizedW / oImgW * 100) "%"
   }

   If (usePrevious=1 && (IMGresizingMode>=3 || (imgW=ResizedW && imgH=ResizedH)))
   {
      ResizedW := ResizedW * wscale
      ResizedH := ResizedH * wscale
   }

   If (noTooltipMSGs=1)
      SetTimer, RemoveTooltip, Off
   IMGlargerViewPort := ((ResizedH-5>GuiH+1) || (ResizedW-5>GuiW+1)) ? 1 : 0
   SplitPath, imgpath, OutFileName, OutDir
   winPrefix := defineWinTitlePrefix()
   winTitle := winPrefix currentFileIndex "/" maxFilesIndex " [" ws "] " OutFileName " | " OutDir
   WinSetTitle, ahk_id %PVhwnd%,, % winTitle

   ResizedW := Round(ResizedW)
   ResizedH := Round(ResizedH)
   whichImg := (usePrevious=1 && gdiBitmapSmall) ? gdiBitmapSmall : gdiBitmap
   IDwhichImg := (usePrevious=1 && gdiBitmapSmall) ? 2 : 1
   If (IMGlargerViewPort!=1)
      CloneResizerBMP(imgpath, IDwhichImg, whichImg, ResizedW, ResizedH)
   Else
      useCaches := "no"
   r := Gdip_ShowImgonGui(imgW, imgH, ResizedW, ResizedH, GuiW, GuiH, usePrevious, useCaches)
   If (usePrevious=1)
      SetTimer, ReloadThisPicture, -550

   Return r
}

calcScreenLimits() {
; the function calculates screen boundaries for the user given X/Y position for the OSD
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
}

RescaleBMPtiny(imgpath, imgW, imgH, ByRef ResizedW, ByRef ResizedH) {
  Critical, on
  ; one quarter resolution
  Static prevImgPath, prevResizedW, prevResizedH
  If (imgpath=prevImgPath && gdiBitmapSmall)
  {
     ResizedW := prevResizedW
     ResizedH := prevResizedH
     Return
  }

  Gdip_DisposeImage(gdiBitmapSmall)
  calcScreenLimits()
  If (imgW//3>ResolutionWidth//2) || (imgH//3>ResolutionHeight//2)
  {
     calcImgSize(1, imgW, imgH, ResolutionWidth//2, ResolutionHeight//2, ResizedW, ResizedH)
  } Else
  {
     ResizedW := Round(imgW//3)
     ResizedH := Round(imgH//3)
  }
  prevResizedW := ResizedW
  prevResizedH := ResizedH
  gdiBitmapSmall := Gdip_CreateBitmap(ResizedW, ResizedH)
  G2 := Gdip_GraphicsFromImage(gdiBitmapSmall)
  thisImgQuality := (userimgQuality=1) ? 3 : 5
  Gdip_SetInterpolationMode(G2, thisImgQuality)
  Gdip_SetSmoothingMode(G2, 3)
  Gdip_DrawImage(G2, gdiBitmap, 0, 0, ResizedW, ResizedH, 0, 0, imgW, imgH)
  Gdip_DeleteGraphics(G2)
  prevImgPath := imgpath
}

CloneMainBMP(imgpath, ByRef width, ByRef height) {
  Critical, on
  Gdip_DisposeImage(gdiBitmap)
  oBitmap := Gdip_CreateBitmapFromFile(imgpath)
  Width := Gdip_GetImageWidth(oBitmap)
  Height := Gdip_GetImageHeight(oBitmap)
  gdiBitmap := Gdip_CreateBitmap(Width, Height)
  G3 := Gdip_GraphicsFromImage(gdiBitmap)
  Gdip_SetInterpolationMode(G3, 5)
  Gdip_SetSmoothingMode(G3, 3)
  Gdip_DrawImage(G3, oBitmap, 0, 0, Width, Height, 0, 0, Width, Height)
  Gdip_DeleteGraphics(G3)
  Gdip_DisposeImage(oBitmap)
}

CloneResizerBMP(imgpath, IDwhichImg, whichImg, newW, newH) {
  Critical, on
  Static prevWhichImgA, prevWhichImgB
  newImg := IDwhichImg imgpath newW newH
  If (IDwhichImg=1 && prevWhichImgA=newImg)
  || (IDwhichImg=2 && prevWhichImgB=newImg)
     Return

  Width := Gdip_GetImageWidth(whichImg)
  Height := Gdip_GetImageHeight(whichImg)
  If (IDwhichImg=1)
  {
     prevWhichImgA := IDwhichImg imgpath newW newH
     Gdip_DisposeImage(gdiBitmapViewScale)
     gdiBitmapViewScale := Gdip_CreateBitmap(newW, newH)
     G4 := Gdip_GraphicsFromImage(gdiBitmapViewScale)
  } Else
  {
     prevWhichImgB := IDwhichImg imgpath newW newH
     Gdip_DisposeImage(gdiBitmapSmallView)
     gdiBitmapSmallView := Gdip_CreateBitmap(newW, newH)
     G4 := Gdip_GraphicsFromImage(gdiBitmapSmallView)
  }
  Gdip_SetInterpolationMode(G4, imgQuality)
  Gdip_SetSmoothingMode(G4, 3)
  Gdip_DrawImage(G4, whichImg, 0, 0, newW, newH, 0, 0, Width, Height)
  Gdip_DeleteGraphics(G4)
}

Gdip_ShowImgonGui(imgW, imgH, newW, newH, mainWidth, mainHeight, usePrevious, useCaches) {
    Critical, on
    If (imgFxMode=2)       ; grayscale
    {
       Ra := 0.300 + lumosGrayAdjust
       Ga := 0.585 + lumosGrayAdjust
       Ba := 0.115 + lumosGrayAdjust
       matrix := Ra "|" Ra "|" Ra "|0|0|" Ga "|" Ga "|" Ga "|0|0|" Ba "|" Ba "|" Ba "|0|0|0|0|0|1|0|" GammosGrayAdjust "|" GammosGrayAdjust "|" GammosGrayAdjust "|0|1"
    }
;       matrix := "0.299|0.299|0.299|0|0|0.587|0.587|0.587|0|0|0.114|0.114|0.114|0|0|0|0|0|1|0|0|0|0|0|1"
    Else If (imgFxMode=3)  ; negative / invert
       matrix := "-1|0|0|0|0|0|-1|0|0|0|0|0|-1|0|0|0|0|0|1|0|1|1|1|0|1"
    Else If (imgFxMode=4) && (lumosAdjust!=1 || GammosAdjust!=0)
       matrix := lumosAdjust "|0|0|0|0|0|" lumosAdjust "|0|0|0|0|0|" lumosAdjust "|0|0|0|0|0|1|0|" GammosAdjust "|" GammosAdjust "|" GammosAdjust "|0|1"

    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    thisImgQuality := (useCaches="no") ? imgQuality : 5
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

    If (useCaches="no")
       whichImg := (usePrevious=1 && gdiBitmapSmall) ? gdiBitmapSmall : gdiBitmap
    Else
       whichImg := (usePrevious=1 && gdiBitmapSmallView) ? gdiBitmapSmallView : gdiBitmapViewScale
    imgW := Gdip_GetImageWidth(whichImg)
    imgH := Gdip_GetImageHeight(whichImg)

;   ToolTip, %imgW% -- %imgH% == %newW% -- %newH%
    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    r1 := Gdip_DrawImage(G, whichImg, DestPosX, DestPosY, newW, newH, 0, 0, imgW, imgH, matrix)
    Gdip_ResetWorldTransform(G)
    r2 := UpdateLayeredWindow(hGDIwin, hdc, 0, 0, mainWidth, mainHeight)

    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)

    Gui, 2: Show, NoActivate
    r := (r1!=0 || !r2) ? 0 : 1
    Return r
}

calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, ByRef DestPosX, ByRef DestPosY) {
    Static orderu := {1:7, 2:8, 3:9, 4:4, 5:5, 6:6, 7:1, 8:2, 9:3}
    modus := orderu[imageAligned]
    If (IMGresizingMode=4)
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
    } Else If (IMGresizingMode=4)
    {
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
}

GuiSize:
   GDIupdater()
Return

GDIupdater() {
   updateUIctrl()
   If (toolTipGuiCreated=1)
      TooltipCreator(1, 1)

   If (!CurrentSLD || !maxFilesIndex) || (A_TickCount - scriptStartTime<600)
      Return

   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   imgpath := resultedFilesList[currentFileIndex]
   If (!FileExist(imgpath) || A_EventInfo=1 || !CurrentSLD)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()
      SetTimer, DelayiedImageDisplay, Off
      SetTimer, ReloadThisPicture, Off
      If (!FileExist(imgpath) || !CurrentSLD)
         destroyGDIwin()
      Return
   }

   If (maxFilesIndex>0) && (A_TickCount - scriptStartTime>500)
   {
;      DelayiedImageDisplay()
      If !((A_TickCount - lastWinDrag>450) && (isTitleBarHidden=1))
         SetTimer, DelayiedImageDisplay, -15
      SetTimer, ReloadThisPicture, -750
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

DestroyGDIbmp() {
   Gdip_DisposeImage(gdiBitmap)
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
       If (RegExMatch(line, RegExFilesPattern) || StrLen(line)<4)
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
          listu .= newFolder "`n"
       Else countFails++
       If (countFails>3)
          Break
   }
   Sort, listu, U D'n
   Return listu
}

RegenerateEntireList() {
    showTOOLtip("Refreshing files list, please wait...")
    If (DynamicFoldersList="hexists")
       listu := coreLoadDynaFolders(CurrentSLD)
    Else If (StrLen(DynamicFoldersList)>6)
       listu := DynamicFoldersList
    Else Return

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
       If (RegExMatch(line, RegExFilesPattern) || StrLen(line)<4)
          Continue
       Else
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
       If RegExMatch(line, "i)^(df.*\=|fi.*\=)")
          Continue

       If InStr(line, "|")
       {
          doRecursive := 2
          line := StrReplace(line, "|")
       } Else doRecursive := 1

       SplitPath, line, OutFileName, OutDir,, OutDrive
       If InStr(OutDrive, "p://")
          Continue

       If (StrLen(OutDir)>2 && RegExMatch(line, RegExFilesPattern))
       {
          If (doFilesCheck=1)
          {
             If !FileExist(line)
                Continue
          }
          maxFilesIndex++
          SLDhasFiles := 1
          resultedFilesList[maxFilesIndex] := line
       } Else If (StrLen(OutDir)>2 && StrLen(OutFileName)<2)
       {
          isRecursive := (doRecursive=2) ? "|" : ""
          DynamicFoldersList .= "`n" isRecursive OutDir "`n"
          GetFilesList(OutDir "\*", doRecursive)
       }
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
  If InStr(strDir, "|")
  {
     doRecursive := 2
     strDir := StrReplace(strDir, "|")
  }

  dig := (doRecursive=2) ? "" : "R"
  Loop, Files, %strDir%, %dig%
  {
      If RegExMatch(A_LoopFileName, RegExFilesPattern)
      {
         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := A_LoopFileFullPath
      }
  }
  SetTimer, RemoveTooltip, % -msgDisplayTime
}

IDshowImage(imgID,opentehFile:=0) {
    Static lastInvoked := 1
    resultu := resultedFilesList[imgID]
    If !resultu
    {
       If ( A_TickCount - lastInvoked>1050)
          SoundBeep, 300, 50
       lastInvoked := A_TickCount
       Return 0
    }

    FileGetSize, fileSizu, %resultu%
    resultu := StrReplace(resultu, "||")
    If (!fileSizu && !FileExist(resultu) && skipDeadFiles=1)
       Return 0

    If (opentehFile=1)
    {
       If !FileExist(resultu)
          informUserFileMissing()
       Try Run, %resultu%
    } Else If (opentehFile=2)
    {
        ShowTheImage(resultu, 2)
    } Else ShowTheImage(resultu)
    Return 1
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

Win_ShowSysMenu(Hwnd) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk

  static WM_SYSCOMMAND = 0x112, TPM_RETURNCMD=0x100
  oldDetect := A_DetectHiddenWindows
  DetectHiddenWindows, on
  Process, Exist
  h := WinExist("ahk_pid " ErrorLevel)
  DetectHiddenWindows, %oldDetect%
;  if X=mouse
;    VarSetCapacity(POINT, 8), DllCall("GetCursorPos", "uint", &POINT), X := NumGet(POINT), Y := NumGet(POINT, 4)
  ; WinGetPos, X, Y, ,, ahk_id %Hwnd%
  JEE_ClientToScreen(hPicOnGui1, 1, 1, X, Y)
  hSysMenu := DllCall("GetSystemMenu", "Uint", Hwnd, "int", False) 
  r := DllCall("TrackPopupMenu", "uint", hSysMenu, "uint", TPM_RETURNCMD, "int", X, "int", Y, "int", 0, "uint", h, "uint", 0)
  ifEqual, r, 0, return
  PostMessage, WM_SYSCOMMAND, r,,,ahk_id %Hwnd%
  return 1
}

AddAnimatedGIF(imagefullpath , x="", y="", w="", h="", guiname = "1") {
  global AG1
  static AGcount:=0, controlAdded, pic
  AGcount := 1
  html := "<html><body style='background-color: transparent' style='overflow:hidden' leftmargin='0' topmargin='0'><img src='" imagefullpath "' width=" w " height=" h " border=0 padding=0></body></html>"
  Gui, AnimGifxx:Add, Picture, vpic, %imagefullpath%
  GuiControlGet, pic, AnimGifxx:Pos
  Gui, AnimGifxx:Destroy
  If (controlAdded!=1)
  {
     controlAdded := 1
     Gui, %guiname%: Add, ActiveX, % (x = "" ? " " : " x" x ) . (y = "" ? " " : " y" y ) . (w = "" ? " w" picW : " w" w ) . (h = "" ? " h" picH : " h" h ) " vAG" AGcount, Shell.Explorer
  }
  AG%AGcount%.navigate("about:blank")
  AG%AGcount%.document.write(html)
  return "AG" AGcount
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

reverseArray(Byref a) {
; function by RHCP from https://autohotkey.com/board/topic/97722-some-array-functions/
    aIndices := []
    For index, in a
        aIndices.insert(index)
    aStorage := []
    Loop, % aIndices.maxIndex() 
       aStorage.insert(a[aIndices[aIndices.maxIndex() - A_index + 1]]) 
    a := aStorage
    Return aStorage
}

AboutWindow() {
    If (AnyWindowOpen=1)
    {
       CloseWindow()
       Return
    }
    AnyWindowOpen := 1
    Gui, SettingsGUIA: Destroy
    Sleep, 15
    Gui, SettingsGUIA: Default
    Gui, SettingsGUIA: -MaximizeBox -MinimizeBox hwndhSetWinGui
    Gui, SettingsGUIA: Margin, 15, 15
    btnWid := 100
    txtWid := 360
    Gui, Font, s19 Bold, Arial, -wrap
    Gui, Add, Text, x10 y15, %appTitle%
    Gui, Font
    If (PrefsLargeFonts=1)
    {
       btnWid := btnWid + 50
       txtWid := txtWid + 105
       Gui, Font, s%LargeUIfontValue%
    }
    Gui, Add, Link, xp y+5, Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a>.
    Gui, Add, Link, xp y+10 w%txtWid%, Based on the prototype image viewer by <a href="http://sites.google.com/site/littlescripting/">SBC</a> from October 2010 published on <a href="https://autohotkey.com/board/topic/58226-ahk-picture-viewer/">AHK forums</a>.
    Gui, Add, Text, xp y+10, Current version released on: jeudi 6 juin 2019.
    Gui, Add, Text, xp y+10, Dedicated to people with large image collections :-).

    Gui, Font, Normal
    Gui, Add, Button, xs+5 y+25 h30 w105 Default gCloseWindow, Close
    Gui, SettingsGUIA: Show, AutoSize, About %appTitle% v%Version%
}

CloseWindow() {
    Gui, SettingsGUIA: Destroy
    AnyWindowOpen := 0
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

    If (A_TickCount-lastInvoked<200)
    {
       If (prevMsg!=msg) && !RegExMatch(msg, "i)(show speed\: |zoom level\: |image brightness\: |image gamma\: )")
       {
          minLen := StrLen(msg) + 150
          msg := prevMsg "`n" msg
          StringRight, msg, msg, % minLen
       } Else Return
    }

    lastInvoked := A_TickCount
    Gui, ToolTipGuia: Destroy
    thisFntSize := (PrefsLargeFonts=1) ? OSDfntSize*2 : OSDfntSize
    bgrColor := OSDbgrColor
    txtColor := OSDtextColor
    isBold :=  " Bold"
    Sleep, 5
    Gui, ToolTipGuia: -DPIScale -Caption +Owner +ToolWindow +E0x80000 +E0x20 +hwndhGuiTip
    Gui, ToolTipGuia: Margin, % thisFntSize + 5, % thisFntSize + 3
    Gui, ToolTipGuia: Color, c%bgrColor%
    Gui, ToolTipGuia: Font, s%thisFntSize% %isBold% Q5, %OSDFontName%
    Gui, ToolTipGuia: Add, Text, c%txtColor% gRemoveTooltip, %msg%
;    Gui, ToolTipGuia: Show, NoActivate AutoSize Hide x1 y1, GuiTipsWin

    GetClientSize(mainWidth, mainHeight, PVhwnd)
    JEE_ClientToScreen(hPicOnGui1, 1, 1, GuiX, GuiY)
    thisOpacity := (PrefsLargeFonts=1) ? 235 : 195
    WinSet, Transparent, %thisOpacity%, ahk_id %hGuiTip%
    toolTipGuiCreated := 1
    prevMsg := msg
    WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight%, ahk_id %hGuiTip%
    Gui, ToolTipGuia: Show, NoActivate AutoSize x%GuiX% y%GuiY%, GuiTipsWin
}


WM_MOUSEMOVE(wP, lP, msg, hwnd) {
; Function by Drugwash
  Global
  Local A
  A := WinActive("A")
  If (isTitleBarHidden=1 && A=PVhwnd && (wP&0x1))
  {
     ; ToolTip, looooooool
     PostMessage, 0xA1, 2,,, ahk_id %PVhwnd%
     lastWinDrag := A_TickCount
     SetTimer, trackMouseDragging, -50
  }
}

trackMouseDragging() {
    lastWinDrag := A_TickCount
}


