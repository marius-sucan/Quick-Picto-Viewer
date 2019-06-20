; Script Name:    AHK Picture Viewer
; Language:       English
; Platform:       Windows XP or later
; Author:         sbc and Marius Șucan
; Script Original Version: 1.0.0 on Oct 4, 2010
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

#Noenv
#NoTrayIcon
#MaxMem, 1924
#Singleinstance, off
#Include, Gdip.ahk

Global PVhwnd, hGDIwin, resultedFilesList := []
   , currentFileIndex, maxFilesIndex := 0
   , appTitle := "AHK Picture Viewer", FirstRun := 1
   , hPicOnGui, scriptStartTime := A_TickCount
   , RandyIMGids := [], SLDhasFiles := 0, IMGlargerViewPort := 0
   , IMGdecalageY := 1, IMGdecalageX := 1, imgQuality
   , RandyIMGnow := 0, GDIPToken, Agifu, gdiBitmapSmall
   , slideShowRunning := 0, CurrentSLD := "", winGDIcreated :=0
   , LargeListCount := 1, usrFilesFilteru := ""
   , gdiBitmap, mainSettingsFile := "ahk-picture-viewer.ini"
   , RegExFilesPattern := "i)(.\\*\.(tif|emf|jpg|jpeg|png|bmp|gif))$"
; User settings
   , WindowBgrColor := "010101", slideShowDelay := 3000
   , IMGresizingMode := 1, SlideHowMode := 1
   , lumosAdjust := 1, GammosAdjust := 0, userimgQuality := 1
   , imgFxMode := 1, FlipImgH := 0, FlipImgV := 0
   , imageAligned := 5, filesFilter := ""
   , noTooltipMSGs := 1, zoomLevel := 1.5
imgQuality := (userimgQuality=1) ? 7 : 5
DetectHiddenWindows, On
CoordMode, Mouse, Screen
OnExit, Cleanup

; OnMessage(0x07, "activateMainWin")
; OnMessage(0x06, "activateMainWin")
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
   writeSlideSettings(mainSettingsFile)
   FirstRun := 0
   IniWrite, % FirstRun, % mainSettingsFile, General, FirstRun
} Else readSlideSettings(mainSettingsFile)

BuildTray()
BuildGUI()
; OpenSLD("E:\Sucan twins\photos test\tv-only.sld")
Return
;_________________________________________________________________________________________________________________Hotkeys_________________

OpenSLD(fileNamu, doFilesCheck:=0, dontStartSlide:=0) {
  If !FileExist(fileNamu)
  {
     showTOOLtip("ERROR: Failed to load file...")
     SoundBeep 
     SetTimer, RemoveTooltip, -2000
     Return
  }

  showTOOLtip("Loading files - please wait...")
  Gui, 1: Show,, Loading files - please wait...
  sldGenerateFilesList(fileNamu, doFilesCheck)
  GenerateRandyList()
  If (dontStartSlide=1)
  {
     SetTimer, RemoveTooltip, -2000
     Return
  }

  FileReadLine, firstLine, % fileNamu, 1
  If InStr(firstLine, "[General]")
     readSlideSettings(fileNamu)

  If (maxFilesIndex>2)
  {
     RandomPicture()
     InfoToggleSlideShowu()
  } Else
  {
     currentFileIndex := 1
     IDshowImage(1)
  }
  SetTimer, RemoveTooltip, -2000
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
       Run, %dir2open%
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
      delayu := slideShowDelay//1000
      showTOOLtip("Slideshow speed: " delayu)
      SetTimer, RemoveTooltip, -2000
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
     Clipboard := imgpath
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
        SetTimer, RemoveTooltip, -2000
        Return
     }
     FlipImgV := FlipImgH := 0
     imgFxMode := 1
     Sleep, 2
     r := Gdip_SetBitmapToClipboard(pBitmap)
     Sleep, 2
     Gdip_DisposeImage(pBitmap)
     If r
        showTOOLtip("Image copied to the clipboard...")
     Else
        showTOOLtip("ERROR: Failed to copy the image to the clipboard...")
     SetTimer, RemoveTooltip, -2000
     IDshowImage(currentFileIndex)
  } Else
  {
     showTOOLtip("ERROR: Failed to copy image to clipboard...")
     SoundBeep 
     SetTimer, RemoveTooltip, -2000
  }
}

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

#If (WinActive("ahk_id " PVhwnd) && CurrentSLD)
    ~^vk4A::    ; Ctrl+J
       Jump2index()
    Return

    ~^vk43::    ; Ctrl+C
       CopyImage2clip()
    Return

    ~+vk43::    ; Shift+C
       CopyImagePath()
    Return

    ~vk4F::   ; O
      OpenThisFile()
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

    ~vkBB::    ; [=]
       ChangeZoom(1)
    Return

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

    ~^F5::
       If (RegExMatch(CurrentSLD, "i)(\.sld)$") && SLDhasFiles=1)
          cleanFilesList()
       Else
          RefreshFilesList()
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

    ~vk46::     ; F
       ToggleImgFX()
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


invertRecursiveness() {
   If (RegExMatch(CurrentSLD, "i)(\.sld)$") || !CurrentSLD)
      Return
   isPipe := InStr(CurrentSLD, "|") ? 1 : 0
   If (isPipe=1)
      CurrentSLD := StrReplace(CurrentSLD, "|")
   Else
      CurrentSLD := "|" CurrentSLD
   RefreshFilesList()
}

ReloadThisPicture() {
  If (CurrentSLD && maxFilesIndex>0)
  {
     If (GetKeyState("LButton", "P")=1)
     {
        Settimer, ReloadThisPicture, -550
        Return
     }
     IDshowImage(currentFileIndex, 2)
  }
}

FirstPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()

   currentFileIndex := 1
   IDshowImage(1)
   showTOOLtip("Total images loaded: " maxFilesIndex)
   SetTimer, RemoveTooltip, -2000
}

LastPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()
   currentFileIndex := maxFilesIndex
   IDshowImage(maxFilesIndex)
   showTOOLtip("Total images loaded: " maxFilesIndex)
   SetTimer, RemoveTooltip, -2000
}

GuiClose:
Cleanup:
   DestroyGDIbmp()
   ; Gdip_DisposeImage(gdiBitmapSmall)
   writeSlideSettings(mainSettingsFile)
   Gdip_Shutdown(GDIPToken)  
   ExitApp
Return

OnlineHelp:
   Run, http://www.autohotkey.com/forum/topic62808.html
Return

GuiContextMenu:
   If (slideShowRunning=1)
      ToggleSlideShowu()
   BuildMenu()
Return 

activateMainWin() {
   WinActivate, ahk_id %PVhwnd%
}

DblClickAction() {
   Critical, on
   Static lastInvoked := 0
   MouseGetPos, , , OutputVarWin
   If (OutputVarWin!=PVhwnd)
      Return

   If (A_TickCount - lastInvoked<250) && (lastInvoked>1)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()

      ; destroyGDIwin()
      Sleep, 25
      Gui, 1: Show, NoActivate Minimize, AHK Picture Viewer: %CurrentSLD%
   } Else If (maxFilesIndex>1 && CurrentSLD)
   {
      Sleep, 50
      GoNextSlide()
   } Else If (!CurrentSLD)
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
    SetTimer, RemoveTooltip, -2000
    IDshowImage(currentFileIndex)
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
     SetTimer, RemoveTooltip, -2000
  } Else 
  {
     delayu := slideShowDelay//1000
     friendly := DefineSlideShowType()
     etaTime := "Estimated time: " SecToHHMMSS(Round((slideShowDelay/1000)*maxFilesIndex))
     ToolTip, Started %friendly% slideshow (speed: %delayu%).`nTotal files: %maxFilesIndex%.`n%etaTime%
     SetTimer, RemoveTooltip, -2000
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
  Sleep, 200
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
   SetTimer, RemoveTooltip, -2000
}

ToggleImgFX() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   imgFxMode++
   If (imgFxMode>4)
      imgFxMode := 1

   friendly := DefineFXmodes()
   If (imgFxMode=4 && lumosAdjust=1 && GammosAdjust=0)
   {
      lumosAdjust := 1.3
      GammosAdjust := -0.3
      friendly .= "`nPlease adjust brightness and gamma...`nUse [ and ] with or without Shift."
   }

   showTOOLtip("Image colors: " friendly)
   SetTimer, RemoveTooltip, -2000
   IDshowImage(currentFileIndex)
}

ToggleIMGalign() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   imageAligned++
   If (imageAligned>9)
      imageAligned := 1

   showTOOLtip("Image alignment: " imageAligned)
   SetTimer, RemoveTooltip, -2000
   IDshowImage(currentFileIndex)
}

ResetImageView() {
    ChangeLumos(2)
}

ChangeLumos(dir) {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (dir=1)
      lumosAdjust := lumosAdjust + 0.2
   Else
      lumosAdjust := (lumosAdjust<1) ?  lumosAdjust - 0.1 : lumosAdjust - 0.25

   imgFxMode := 4
   If (dir=2)
   {
      GammosAdjust := FlipImgH := FlipImgV := 0
      lumosAdjust := 1
      imgFxMode := 1
      If (IMGresizingMode=4)
         IMGdecalageY := IMGdecalageX := zoomLevel := 1
   }

   If (lumosAdjust<0)
      lumosAdjust := 0.001

   If (lumosAdjust>10)
      lumosAdjust := 10

   If (dir=2)
      showTOOLtip("Image colors: UNALTERED")
   Else
      showTOOLtip("Image brightness: " lumosAdjust)
   SetTimer, RemoveTooltip, -2000
   IDshowImage(currentFileIndex)
}

ChangeZoom(dir) {
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
   SetTimer, RemoveTooltip, -2000
   SetTimer, DelayiedImageDisplay, -5
}

ChangeGammos(dir) {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   If (dir=1)
      GammosAdjust := GammosAdjust + 0.05
   Else
      GammosAdjust := GammosAdjust - 0.05

   imgFxMode := 4
   If (GammosAdjust<-1)
      GammosAdjust := -1

   If (GammosAdjust>1)
      GammosAdjust := 1

   showTOOLtip("Image gamma: " GammosAdjust)
   SetTimer, RemoveTooltip, -2000
   IDshowImage(currentFileIndex)
}

TransformIMGv() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   FlipImgV := !FlipImgV
   If (FlipImgV=1)
   {
      showTOOLtip("Image mirrored vertically")
      SetTimer, RemoveTooltip, -2000
   }
   IDshowImage(currentFileIndex)
}

TransformIMGh() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   FlipImgH := !FlipImgH
   If (FlipImgH=1)
   {
      showTOOLtip("Image mirrored horizonatally")
      SetTimer, RemoveTooltip, -2000
   }
   IDshowImage(currentFileIndex)
}

NextPicture() {
   currentFileIndex++
   If (currentFileIndex<1)
      currentFileIndex := maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := 1
   IDshowImage(currentFileIndex)
}

PanIMGonScreen(direction) {
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

   SetTimer, DelayiedImageDisplay, -5
}

DelayiedImageDisplay() {
   IDshowImage(currentFileIndex)
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
      IDshowImage(currentFileIndex)
   }
}

enableFilesFilter() {
   Static chars2escape := ".+[{()}-]"
   If (maxFilesIndex<3)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(filesFilter)>1
   {
      showTOOLtip("To exclude files matching the string - `nplease insert '&' (and) into your string`n`nCurrent filter: " filesFilter)
      SetTimer, RemoveTooltip, -5000
   } Else LargeListCount := maxFilesIndex

   InputBox, usrFilesFilteru, Files filter: %usrFilesFilteru%, Type the string to filter files. Files path and/or name must include the string you provide.,,,,,,,, %usrFilesFilteru%
   If !ErrorLevel
   {
      showTOOLtip("Please wait... Filtering files...")
      doFilesCheck := (LargeListCount<2048) ? 2 : 10
      filesFilter := usrFilesFilteru
      Loop, Parse, chars2escape
          filesFilter := StrReplace(filesFilter, A_LoopField, "\" A_LoopField)
      filesFilter := StrReplace(filesFilter, "&")
      ; MsgBox, % filesFilter
      RefreshFilesList(doFilesCheck)
      If (maxFilesIndex<1)
      {
         MsgBox,, %appTitle%, No files matched your filtering criteria:`n%usrFilesFilteru%`n`nThe application will now reload the full list of files.
         usrFilesFilteru := filesFilter := ""
         RefreshFilesList(doFilesCheck)
      }
      SoundBeep, 950, 100
      SetTimer, RemoveTooltip, -2000
   }
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
   If StrLen(maxFilesIndex)>1
      FileSelectFile, file2save, S26,, Save files list as Slideshow, Slideshow (*.sld)

   If (!ErrorLevel && StrLen(file2save)>3)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
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
            FileDelete, %file2save%
            throwMSGwriteError()
         } Else
         {
            SaveFilesList()
            Return
         }
      }
      Sleep, 2
      MsgBox, 52, %appTitle%, Do you want to store the current slideshow settings as well ?
      IfMsgBox, Yes
      {
         writeSlideSettings(file2save)
         Sleep, 2
      }

      showTOOLtip("(Please wait) Saving files list into`n" file2save)
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If InStr(r, "||")
             Continue

          If (r && FileExist(r))
             filesListu .= r "`n"
      }
      FileAppend, %filesListu%, %file2save%, utf-16
      throwMSGwriteError()
      SetTimer, RemoveTooltip, -2000
      SoundBeep, 900, 100
      CurrentSLD := backCurrentSLD
   }
}

cleanFilesList(noFilesCheck:=0) {
   Critical, on

   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      showTOOLtip("(Please wait) Checking files list...")
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r)
             Continue

          If (noFilesCheck!="2")
          {
             If FileExist(r)
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
      GenerateRandyList()
      SoundBeep, 950, 100
      Sleep, 25
      RandomPicture()
      SetTimer, RemoveTooltip, -2000
      CurrentSLD := backCurrentSLD
   }
}

ActSortName() {
   cleanFilesList(2)
}

ActSortSize() {
   SortFilesList("size")
}
   SortFilesList("resolution")

ActSortModified() {
   SortFilesList("modified")
}

ActSortCreated() {
   SortFilesList("created")
}

ActSortResolution() {

}

SortFilesList(SortCriterion) {
   Critical, on

   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      showTOOLtip("(Please wait) Gathering files information...")
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (InStr(r, "||") || !r || !FileExist(r))
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
      GenerateRandyList()
      SoundBeep, 950, 100
      Sleep, 25
      RandomPicture()
      SetTimer, RemoveTooltip, -2000
      CurrentSLD := backCurrentSLD
   }
}

readSlideSettings(readThisFile) {
     IniRead, tstslideShowDelay, %readThisFile%, General, slideShowDelay, @
     IniRead, tstIMGresizingMode, %readThisFile%, General, IMGresizingMode, @
     IniRead, tstSlideHowMode, %readThisFile%, General, SlideHowMode, @
     IniRead, tstimgFxMode, %readThisFile%, General, imgFxMode, @
     IniRead, tstWindowBgrColor, %readThisFile%, General, WindowBgrColor, @
     IniRead, tstfilesFilter, %readThisFile%, General, usrFilesFilteru, @
     IniRead, tstFlipImgH, %readThisFile%, General, FlipImgH, @
     IniRead, tstFlipImgV, %readThisFile%, General, FlipImgV, @
     IniRead, tstlumosAdjust, %readThisFile%, General, lumosAdjust, @
     IniRead, tstGammosAdjust, %readThisFile%, General, GammosAdjust, @
     IniRead, tstimageAligned, %readThisFile%, General, imageAligned, @

     If (tstslideshowdelay!="@" && tstslideshowdelay>300)
        slideShowDelay := tstslideShowDelay
     If (tstimgresizingmode!="@" && StrLen(tstIMGresizingMode)=1 && tstIMGresizingMode<5)
        IMGresizingMode := tstIMGresizingMode
     If (tstimgFxMode!="@" && StrLen(tstimgFxMode)=1 && tstimgFxMode<5)
        imgFxMode := tstimgFxMode
     If (tstFlipImgV!="@" && (tstFlipImgV=1 || tstFlipImgV=0))
        FlipImgV := tstFlipImgV
     If (tstFlipImgH!="@" && (tstFlipImgH=1 || tstFlipImgH=0))
        FlipImgV := tstFlipImgV
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
    IniWrite, % imageAligned, %file2save%, General, imageAligned
    throwMSGwriteError()
}

RandomPicture() {
   ; Static 

   RandyIMGnow++
   If (RandyIMGnow<1)
      RandyIMGnow := maxFilesIndex
   If (RandyIMGnow>maxFilesIndex)
      RandyIMGnow := 1

   currentFileIndex := RandyIMGids[RandyIMGnow]
   resultu := resultedFilesList[currentFileIndex]
   IDshowImage(currentFileIndex)
}

PrevRandyPicture() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   RandyIMGnow--
   If (RandyIMGnow<1)
      RandyIMGnow := maxFilesIndex
   If (RandyIMGnow>maxFilesIndex)
      RandyIMGnow := 1

   currentFileIndex := RandyIMGids[RandyIMGnow]
   resultu := resultedFilesList[currentFileIndex]
   IDshowImage(currentFileIndex)
}

DeletePicture() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  Sleep, 2
  file2rem := resultedFilesList[currentFileIndex]
  file2rem := StrReplace(file2rem, "||")
  showTOOLtip("File deleted... `n" file2rem)
  FileSetAttrib, -R, %file2rem%
  Sleep, 2
  FileDelete, %file2rem%
  resultedFilesList[currentFileIndex] := "||" file2rem
  If ErrorLevel
  {
     showTOOLtip("File already deleted or access denied...")
     SoundBeep
  }
  Sleep, 500
  SetTimer, RemoveTooltip, -2000
}

RenameThisFile() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  Sleep, 2
  file2rem := resultedFilesList[currentFileIndex]
  If !FileExist(file2rem)
  {
     showTOOLtip("File does not exist...`n" file2rem)
     SetTimer, RemoveTooltip, -2000
     SoundBeep 
     Return
  }

  SplitPath, file2rem, OutFileName, OutDir
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
           SetTimer, RemoveTooltip, -2000
           Return
        }
     }

     Sleep, 2
     FileMove, %file2rem%, %OutDir%\%newFileName%
     If ErrorLevel
     {
        showTOOLtip("ERROR: Access denied... File could not be renamed.")
        SoundBeep
        SetTimer, RemoveTooltip, -2000
     } Else
     {
        resultedFilesList[currentFileIndex] := OutDir "\" newFileName
        IDshowImage(currentFileIndex)
     }
  }
}

PreviousPicture() {
   currentFileIndex--
   If (currentFileIndex<1)
      currentFileIndex := maxFilesIndex
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := 1
   IDshowImage(currentFileIndex)
}

OpenFolders() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   FileSelectFolder, SelectedDir, *%A_WorkingDir%, 2, Select the folder with images. All images found in sub-folders will be loaded as well.
   If (SelectedDir)
   {
      usrFilesFilteru := filesFilter := CurrentSLD := ""
      Gui, 1: Show,, Loading files - please wait...
      coreOpenFolder(SelectedDir)
      CurrentSLD := SelectedDir
   }
}

renewCurrentFilesList() {
  prevRandyIMGs := []
  prevRandyIMGnow := 0
  resultedFilesList := []
  maxFilesIndex := 0
  currentFileIndex := 1
}

coreOpenFolder(thisFolder) {
   If StrLen(thisFolder)>3
   {
      renewCurrentFilesList()
      GetFilesList(thisFolder "\*")
      GenerateRandyList()
      If (maxFilesIndex>0)
         IDshowImage(1)
      Else
         Gosub, GuiSize
   }
}

RefreshFilesList(mustDoFilesCheck:=0) {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (StrLen(filesFilter)<3)
     LargeListCount := maxFilesIndex

  If RegExMatch(CurrentSLD, "i)(\.sld)$")
  {
     currentFileIndex := 1
     doFilesCheck := (LargeListCount<2048) ? 1 : 0
     If (mustDoFilesCheck=10)
        doFilesCheck := 0

     OpenSLD(CurrentSLD, 0, 1)
     If (doFilesCheck=1)
        cleanFilesList()
     Else
        RandomPicture()
  } Else If StrLen(CurrentSLD)>3
     coreOpenFolder(CurrentSLD)
}

OpenFiles() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    pattern := "Images (*.jpg; *.bmp; *.png; *.gif; *.tif; *.emf; *.sld; *.jpeg)"
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
      showTOOLtip("Opening file...")
      usrFilesFilteru := filesFilter := CurrentSLD := ""
      renewCurrentFilesList()
      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      Gui, 1: Show,, Loading files - please wait...
      GetFilesList(SelectedDir "\*|")
      GenerateRandyList()
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
      SetTimer, RemoveTooltip, -2000
      CurrentSLD := "|" SelectedDir
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

GuiDropFiles:
   Loop, parse, A_GuiEvent, `n
   {
;     MsgBox, % A_LoopField
      If (A_Index>1500)
         Break
      Else If RegExMatch(A_LoopField, "i)(\.(jpg|emf|tif|jpeg|png|bmp|gif|sld))$")
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

      usrFilesFilteru := filesFilter := CurrentSLD := ""
      renewCurrentFilesList()
      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      GetFilesList(imagedir "\*|")
      GenerateRandyList()
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
      CurrentSLD := "|" imagedir
      SetTimer, RemoveTooltip, -2000
   }
Return

RemoveTooltip() {
   Tooltip
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
   Menu, Tray, Add, &About / Help, OnlineHelp
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
   }

   sliMode := DefineSlideShowType()
   sliSpeed := slideShowDelay//1000
   Menu, PVsliMenu, Add, &Start slideshow`tSpace, ToggleSlideShowu
   Menu, PVsliMenu, Add, Next &slide`tL-Click, GoNextSlide
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Toggle slideshow mode`tS, SwitchSlideModes
   Menu, PVsliMenu, Add, %sliMode%, SwitchSlideModes
   Menu, PVsliMenu, Disable, %sliMode%
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Increase speed`tMinus [-], IncreaseSlideSpeed
   Menu, PVsliMenu, Add, &Decrease speed`tEqual [=], DecreaseSlideSpeed
   Menu, PVsliMenu, Add, Current speed: %sliSpeed%, DecreaseSlideSpeed
   Menu, PVsliMenu, Disable, Current speed: %sliSpeed%

   infoImgResize := DefineImgSizing()
   infoImgFX := DefineFXmodes()
   infolumosAdjust := Round(lumosAdjust, 2)
   infoGammosAdjust := Round(GammosAdjust, 2)
   Menu, PVview, Add, Image &alignment: %imageAligned%`tA, ToggleIMGalign
   Menu, PVview, Add,
   Menu, PVview, Add, &Toggle Resizing Mode`tT, ToggleImageSizingMode
   Menu, PVview, Add, %infoImgResize%, ToggleImageSizingMode
   Menu, PVview, Disable, %infoImgResize%
   Menu, PVview, Add,
   Menu, PVview, Add, &Switch colors display`tF, ToggleImgFX
   Menu, PVview, Add, %infoImgFX%, ToggleImgFX
   If (imgFxMode=4)
   {
      Menu, PVview, Add, B: %infolumosAdjust% / G: %infoGammosAdjust%, ToggleImgFX
      Menu, PVview, Disable, B: %infolumosAdjust% / G: %infoGammosAdjust%
   }
   Menu, PVview, Disable, %infoImgFX%
   Menu, PVview, Add,
   Menu, PVview, Add, Mirror &horizontally`tH, TransformIMGh
   Menu, PVview, Add, Mirror &vertically`tV, TransformIMGv
   Menu, PVview, Add,
   Menu, PVview, Add, Reset image vie&w`t\, ResetImageView
   If (FlipImgV=1)
      Menu, PVview, Check, Mirror &vertically`tV

   If (FlipImgH=1)
      Menu, PVview, Check, Mirror &horizontally`tH

   imgpath := prevRandyIMGs[prevRandyIMGnow]
   Menu, PVnav, Add, &First`tHome, FirstPicture
   Menu, PVnav, Add, &Previous`tRight, PreviousPicture
   Menu, PVnav, Add, &Next`tLeft, NextPicture
   Menu, PVnav, Add, &Last`tEnd, LastPicture
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Jump at #`tCtrl+J, Jump2index
   Menu, PVnav, Add, &Random`tR, RandomPicture
   If imgpath
      Menu, PVnav, Add, &Prev. random image`tBackspace, PrevRandyPicture

   Menu, PVtFile, Add, &Copy image to Clipboard`tCtrl+C, CopyImage2clip
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, &Open (with external app)`tO, OpenThisFile
   Menu, PVtFile, Add, &Open containing folder`tCtrl+E, OpenThisFileFolder
   Menu, PVtFile, Add, &Rename`tF2, RenameThisFile
   Menu, PVtFile, Add, &Delete`tDelete, DeletePicture

   Menu, PVsort, Add, &Path and name, ActSortName
   Menu, PVsort, Add, &File size, ActSortSize
   Menu, PVsort, Add, &Modified date, ActSortModified
   Menu, PVsort, Add, &Created date, ActSortCreated
   Menu, PVsort, Add, &Resolution (very slow), ActSortResolution

   Menu, PVfList, Add, &Refresh opened folder(s)`tF5, RefreshFilesList
   If (maxFilesIndex>2)
   {
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && SLDhasFiles=1)
         Menu, PVfList, Add, &Clean duplicate/inexistent entries, cleanFilesList
      Menu, PVfList, Add, &Text filtering`tCtrl+F, enableFilesFilter
      If StrLen(filesFilter)>1
         Menu, PVfList, Check, &Text filtering`tCtrl+F
      Menu, PVfList, Add,
      Menu, PVfList, Add, &Sort by, :PVsort
   }

   Menu, PVmenu, Add, &Open File`tCtrl+O, OpenFiles
   Menu, PVmenu, Add, &Open Folders`tShift+O, OpenFolders
   Menu, PVmenu, Add,
   If (maxFilesIndex>0 && CurrentSLD)
   {
      Menu, PVmenu, Add, File, :PVtFile
      Menu, PVmenu, Add, Files list, :PVfList
      Menu, PVmenu, Add, View, :PVview
      If (maxFilesIndex>1 && CurrentSLD)
      {
         Menu, PVmenu, Add, Navigation, :PVnav
         Menu, PVmenu, Add, Slideshow, :PVsliMenu
      }
      Menu, PVmenu, Add,
   }

   Menu, PVmenu, Add, About / Help, OnlineHelp
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, &Exit`tEsc, Cleanup
   wasCreated := 1
   Menu, PVmenu, Show
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

   Return winPrefix
}


SetParentID(Window_ID, theOther) {
  Return DllCall("SetParent", "uint", theOther, "uint", Window_ID) ; success = handle to previous parent, failure =null 
}

BuildGUI() {
   global ;PicOnGUI, PVhwnd, appTitle, ScriptMsg , ScriptMsgW, ScriptMsgH, hue
   local MaxGUISize, MinGUISize, initialwh, guiw, guih
   MaxGUISize = -DPIScale
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialwh := "w" A_ScreenWidth//3 " h" A_ScreenHeight//3
   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MaxGUISize% %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Add, Text, x1 y1 w2 h2 BackgroundTrans gDblClickAction vPicOnGui hwndhPicOnGui,
   Gui, 1: Show, Maximize Center %initialwh%, %appTitle%
   createGDIwin()
   GetClientSize(GuiW, GuiH, PVhwnd)
   GuiControl, 1: Move, PicOnGUI, % "w" GuiW " h" GuiH
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
         Gui, 1: Show,, % winTitle
         showTOOLtip("ERROR: Unable to load the file...`n" imgpath)
         SetTimer, RemoveTooltip, -2000
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
             SetTimer, RemoveTooltip, -2000
          }
          SoundBeep, 300, 100
          Return "fail"
       } Else prevImgPath := imgpath
       If (usePrevious=1)
          SetTimer, ReloadThisPicture, -550
       lastInvoked := A_TickCount
;       counteru++
;       ToolTip, a %counteru%
   } Else ; If (wasForcedHigh!=1)
   {
       winPrefix := defineWinTitlePrefix()
       Gui, 1: Show,, % winPrefix winTitle
       SetTimer, ReloadThisPicture, -290
   }
   lastInvoked2 := A_TickCount
}

ResizeImage(imgpath, usePrevious) {
    Static oImgW, oImgH, prevImgPath, prevImgW, prevImgH, mainX, mainY
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
      imgH := prevImgH // 4
      imgW := prevImgW // 4
   }

   If (usePrevious=1)
      RescaleBMPtiny(imgpath, prevImgW, prevImgH)

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

      If (IMGresizingMode=2)
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
      ws := Round(ResizedW / imgW * 100) "%"
   }

   If (usePrevious=1 && IMGresizingMode=4)
   {
      ResizedW := ResizedW * 4
      ResizedH := ResizedH * 4
   }

   IMGlargerViewPort := ((ResizedH-5>GuiH+1) || (ResizedW-5>GuiW+1)) ? 1 : 0
   SplitPath, imgpath, OutFileName, OutDir
   winPrefix := defineWinTitlePrefix()
   winTitle := winPrefix currentFileIndex "/" maxFilesIndex " [" ws "] " OutFileName " | " OutDir
   If (WinActive("A")!=PVhwnd && slideShowRunning=1)
      Gui, 1: Show, NoActivate x%mainX% y%mainY% w%GuiW% h%GuiH%, % winTitle
   Else ; If (usePrevious!=1)
      Gui, 1: Show, , % winTitle

   r := Gdip_ShowImgonGui(ResizedW, ResizedH, GuiW, GuiH, usePrevious)
   Return r
}

RescaleBMPtiny(imgpath, width, height) {
  Critical, on
  ; one quarter resolution
  Static prevImgPath
  If (imgpath=prevImgPath && gdiBitmapSmall)
     Return

  Gdip_DisposeImage(gdiBitmapSmall)
  gdiBitmapSmall := Gdip_CreateBitmap(Width // 4, Height // 4)
  G2 := Gdip_GraphicsFromImage(gdiBitmapSmall)
  Gdip_DrawImage(G2, gdiBitmap, 0, 0, Width // 4, Height // 4, 0, 0, Width, Height)
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
  Gdip_DrawImage(G3, oBitmap, 0, 0, Width, Height, 0, 0, Width, Height)
  Gdip_DeleteGraphics(G3)
  Gdip_DisposeImage(oBitmap)
}

Gdip_ShowImgonGui(newW, newH, mainWidth, mainHeight, usePrevious) {
    Critical, on
    If (imgFxMode=2)       ; grayscale
       matrix := "0.299|0.299|0.299|0|0|0.587|0.587|0.587|0|0|0.114|0.114|0.114|0|0|0|0|0|1|0|0|0|0|0|1"
    Else If (imgFxMode=3)  ; negative / invert
       matrix := "-1|0|0|0|0|0|-1|0|0|0|0|0|-1|0|0|0|0|0|1|0|1|1|1|0|1"
    Else If (imgFxMode=4) && (lumosAdjust!=1 || GammosAdjust!=0)
       matrix := lumosAdjust "|0|0|0|0|0|" lumosAdjust "|0|0|0|0|0|" lumosAdjust "|0|0|0|0|0|1|0|" GammosAdjust "|" GammosAdjust "|" GammosAdjust "|0|1"

    thisImgQuality := (usePrevious=1 && userimgQuality=1) ? 3 : imgQuality
    hbm := CreateDIBSection(mainWidth, mainHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
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
    Width := Gdip_GetImageWidth(whichImg)
    Height := Gdip_GetImageHeight(whichImg)
    calcIMGcoord(usePrevious, mainWidth, mainHeight, newW, newH, DestPosX, DestPosY)
    r1 := Gdip_DrawImage(G, whichImg, DestPosX, DestPosY, newW, newH, 0, 0, Width, Height, matrix)
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
   If (!CurrentSLD || !maxFilesIndex) || (A_TickCount - scriptStartTime<600)
      Return

   If (slideShowRunning=1)
      resetSlideshowTimer(0)

   GetClientSize(GuiW, GuiH, PVhwnd)
   GuiControl, 1: Move, PicOnGUI, % "w" GuiW " h" GuiH
   imgpath := resultedFilesList[currentFileIndex]
   If (!FileExist(imgpath) || A_EventInfo=1 || !CurrentSLD)
   {
      If (slideShowRunning=1)
         ToggleSlideShowu()
      Sleep, 25
      destroyGDIwin()
      Return
   }

   If (maxFilesIndex>0) && (A_TickCount - scriptStartTime>500)
   {
      DelayiedImageDisplay()
      SetTimer, ReloadThisPicture, -550
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
    prevW := w := NumGet(rc, 8, "int")
    prevH := h := NumGet(rc, 12, "int")
    lastInvoked := A_TickCount
} 

sldGenerateFilesList(readThisFile, doFilesCheck) {
    renewCurrentFilesList()
    CurrentSLD := ""
    SLDhasFiles := 0
    FileRead, tehFileVar, %readThisFile%
    FileReadLine, firstLine, %readThisFile%, 1
    If InStr(firstLine, "[General]")
       properFormat := 1
    Else
       tehFileVar := RegExReplace(tehFileVar, "\x22", "@")

    filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
    Loop, Parse, tehFileVar,`n,`r
    {
       line := Trim(A_LoopField)
       If (properFormat!=1)
       {
          line := StrReplace(line, "@-")
          line := StrReplace(line, "@")
       }

       If InStr(A_LoopField, "|")
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

          If StrLen(filesFilter)>1
          {
             If (!RegExMatch(line, "i)(" filesFilter ")") && filterBehaviour=2)
                Continue
             Else If (RegExMatch(line, "i)(" filesFilter ")") && filterBehaviour=1)
                Continue
          }
          maxFilesIndex++
          SLDhasFiles := 1
          resultedFilesList[maxFilesIndex] := line
       } Else If (StrLen(OutDir)>2 && StrLen(OutFileName)<2)
       {
          GetFilesList(OutDir "\*", doRecursive)
       }
    }
    currentFileIndex := 1
    CurrentSLD := readThisFile
}

GetFilesList(strDir, doRecursive:=1) {
  showTOOLtip("Loading the list of files... please wait.`n" strDir)
  filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2

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
         If StrLen(filesFilter)>1
         {
            If (!RegExMatch(A_LoopFileFullPath, "i)(" filesFilter ")") && filterBehaviour=2)
               Continue
            Else If (RegExMatch(A_LoopFileFullPath, "i)(" filesFilter ")") && filterBehaviour=1)
               Continue
         }
         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := A_LoopFileFullPath
      }
  }
  SetTimer, RemoveTooltip, -2000
}

IDshowImage(imgID,opentehFile:=0) {
    resultu := resultedFilesList[imgID]
    If !resultu
    {
       SoundBeep 
       Return
    }

    resultu := StrReplace(resultu, "||")
    If (opentehFile=1)
    {
       If !FileExist(resultu)
       {
          showTOOLtip("ERROR: The file is missing...`n" resultu)
          SoundBeep 
          SetTimer, RemoveTooltip, -2000
          Sleep, 900
       }
       Run, %resultu%
    } Else If (opentehFile=2)
    {
        ShowTheImage(resultu, 2)
    } Else ShowTheImage(resultu)
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
  JEE_ClientToScreen(hPicOnGui, 1, 1, X, Y)
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

showTOOLtip(msg) {
   If (WinActive("A")=PVhwnd) && (noTooltipMSGs=0)
      Tooltip, %msg%
}
