; Script Name: AHK Picture Viewer
; Language:       English
; Platform:       Windows XP or later
; Author:         sbc
; Script Version: 1.0.0 on Oct 4, 2010
; Script Function:
;   Displays images of jpeg, jpg, bmp, png, gif
; Author's website: http://sites.google.com/site/littlescripting/
; AHK forum address for this script:
; Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
;_________________________________________________________________________________________________________________Auto Execute Section____

#noenv
#notrayicon
#singleinstance, off
#Include, Gdip.ahk
Global PVhwnd, resultedFilesList, currentFileIndex, maxFilesIndex
     , ScriptTitle := "AHK Picture Viewer"
     , slideShowRunning := 0
     , slideShowDelay := 3000

DetectHiddenWindows On
CoordMode, Mouse, Screen
OnExit, Exit

; program settings
pattern = jpeg,jpg,bmp,png,gif
if !(GDIPToken := Gdip_Startup())
{
   Msgbox, 48, Error Occurred. Program Exits.
   ExitApp
}
;an image file is dropped onto the script icon
if %0%
{
   Loop, %0% 
   {
      Fetch := GetFileLongPath(%A_Index%)
      if IsImage(Fetch)
      {
         if (A_Index = 1)
            imgpath := Fetch
         else 
         {
            if IsCompiled()
               Run, "%A_ScriptFullPath%" "%Fetch%"
            else
               Run, %A_AhkPath% "%A_ScriptFullPath%" "%Fetch%"
         }
      }   
   }
}

BuildGUI()
if imgpath
{
   ShowImage(imgpath)
   ; ImgNum := ImageListfromFile(imgpath)   ;create an image list
}

OpenSLD("tv-only.sld")
Return
;_________________________________________________________________________________________________________________Hotkeys_________________

OpenSLD(fileNamu) {
  GenerateFilesList(fileNamu)
  SoundBeep
  Random, numy, 1, maxFilesIndex
  IDshowImage(numy)
  ToggleRandomPicture()
}

#If WinActive("ahk_id " PVhwnd)

    ~vkBD::
       slideShowDelay := slideShowDelay - 1000
       If (slideShowDelay<900)
          slideShowDelay := 500
       If (slideShowRunning=1)
          SetTimer, RandomPicture, %slideShowDelay%
       delayu := slideShowDelay//1000
       ToolTip, Slideshow speed: %delayu%
       SetTimer, RemoveTooltip, -2000
    Return

    ~vkBB::
       slideShowDelay := slideShowDelay + 1000
       If (slideShowDelay>12000)
          slideShowDelay := 12500
       If (slideShowRunning=1)
          SetTimer, RandomPicture, %slideShowDelay%
       delayu := slideShowDelay//1000
       ToolTip, Slideshow speed: %delayu%
       SetTimer, RemoveTooltip, -2000
    Return

    ~Space::
       ToggleRandomPicture()
    Return 

    ~vk52::
       RandomPicture()
    Return

    ~Del::
       DeletePicture()
    Return

    ~Right::
       NextPicture()
    Return

    ~Left::
       PreviousPicture()
    Return

    ~Home:: 
       FirstPicture()
    Return

    ~End:: 
       LastPicture()
    Return

    ~^vk4F::
       OpenFile()
    Return

    ~^w::
    ~Esc::
       Gosub, Exit
    Return
#If

;_________________________________________________________________________________________________________________Labels__________________

FirstPicture() { 
   currentFileIndex := 1
   IDshowImage(1)
}

LastPicture() { 
   currentFileIndex := maxFilesIndex
   IDshowImage(maxFilesIndex)
}



GuiClose:
Exit:
   Gdip_Shutdown( GDIPToken )  
ExitApp

OnlineHelp:
   Run, http://www.autohotkey.com/forum/topic62808.html
Return

GuiContextMenu:
   Menu, PVmenu, Show
Return 

GuiSize:
   If (A_EventInfo=1)   ;minimized
      Return
   SetTimer, updateImgSize, -60
Return

updateImgSize() {
   If (maxFilesIndex>0)
      IDshowImage(currentFileIndex)
}

ToggleRandomPicture() {
  If (slideShowRunning=1)
  {
     slideShowRunning := 0
     SetTimer, RandomPicture, Off
     ToolTip, Slideshow stopped.
     SetTimer, RemoveTooltip, -2000
  } Else 
  {
     slideShowRunning := 1
     SetTimer, RandomPicture, %slideShowDelay%
     delayu := slideShowDelay//1000
     ToolTip, Slideshow running at: %delayu%.
     SetTimer, RemoveTooltip, -2000
  }
}

NextPicture() {
   currentFileIndex++
   If (currentFileIndex<1)
      currentFileIndex := 1
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := maxFilesIndex
   IDshowImage(currentFileIndex)
}

RandomPicture() {
  Random, currentFileIndex, 1, %maxFilesIndex%
  IDshowImage(currentFileIndex)
}

DeletePicture() {
  file2rem := ST_ReadLine(resultedFilesList, currentFileIndex)
  ToolTip, File deleted...
  SoundBeep, 2, 2
  FileDelete, %file2rem%
  If ErrorLevel
  {
     ToolTip, File already deleted...
     SoundBeep
  }
  Sleep, 500
  Tooltip
}

PreviousPicture() {
   currentFileIndex--
   If (currentFileIndex<1)
      currentFileIndex := 1
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := maxFilesIndex
   IDshowImage(currentFileIndex)
}

OpenFile() {
   FileSelectFolder, SelectedDir, *%A_WorkingDir%, 0
   if (SelectedDir)
   {
      resultedFilesList := ""
      maxFilesIndex := 0
      currentFileIndex := 1
      resultedFilesList := GetFilesList(SelectedDir "\*")
      IDshowImage(1)
   }
}

GuiDropFiles:
   Loop, parse, A_GuiEvent, `n
   {
;     MsgBox, % A_LoopField
      If (A_Index>1500)
         Break
      Else If RegExMatch(A_LoopField, "i)(\.(jpg|jpeg|png|bmp|gif))$")
         imgpath := A_LoopField
   }

   if (imgpath)
   {
      SplitPath, imgpath,, imagedir
      If !imagedir
         Return
      resultedFilesList := ""
      maxFilesIndex := 0
      currentFileIndex := 1
      resultedFilesList := GetFilesList(imagedir "\*")
      IDshowImage(1)
   }
Return 

RemoveTooltip() {
   tooltip
}

;_________________________________________________________________________________________________________________Functions_______________

GetImgDimension(imgpath, ByRef w, ByRef h) {
   If FileExist(imgpath)
   {
      pBM := Gdip_CreateBitmapFromFile(imgpath)
      w := Gdip_GetImageWidth( pBM )
      h := Gdip_GetImageHeight( pBM )
      Gdip_DisposeImage( pBM )
      Return 1
   } Else Return 0
}

;creates an array which lists up images in the same directory to a given image file
;and returns the index number of it
ImageListfromFile(filepath)
{
   global    ;pattern, ImgList%n%
   local imagedir, Imgs, ImgCount
   ;clear the last used array contents
   Loop, %ImgList0%
      ImgList%A_Index% =
   ImgList0 =
   SplitPath, filepath,, imagedir
   Loop %imagedir%\*   
   {
      If A_LoopFileExt in %pattern%
      {
         ImgCount++
         Imgs = %Imgs%%A_LoopFileLongPath%`n
         Tooltip, Reading Images: %ImgCount%`n 
      }
   
   }
   Sort Imgs, N D`n   
   StringSplit, ImgList, Imgs, `n
   SetTimer, RemoveTooltip, -2000
   Loop, %ImgList0%
      if (ImgList%a_index% = filepath)
         Return A_Index
   Imgs =       ;delete      
   
}


BuildGUI() {
   global ;PicOnGUI, PVhwnd, ScriptTitle, ScriptMsg , ScriptMsgW, ScriptMsgH, hue
   local MaxGUISize, MinGUISize, initialwh, guiw, guih
   MaxGUISize = -DPIScale +MaxSize%A_ScreenWidth%x%A_ScreenHeight%
   MinGUISize := "-DpiScale +MinSize" . round(A_ScreenWidth/3,2) . "x" . round(A_ScreenHeight/3, 2)
   initialwh := "w" . round(A_ScreenWidth/3,2) . " h" . round(A_ScreenHeight/3, 2)
   Menu, PVmenu, Add, &Open Folder`tCtrl+O, OpenFile
   Menu, PVmenu, Add,
   Menu, PVnav, Add, &First`tHome, FirstPicture
   Menu, PVnav, Add, &Previous`tRight, PreviousPicture
   Menu, PVnav, Add, &Next`tLeft, NextPicture
   Menu, PVnav, Add, &Last`tEnd, LastPicture
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Random`tR, RandomPicture
   Menu, PVnav, Add, &Delete File`tDelete, DeletePicture
   Menu, PVmenu, Add, Images Navigation, :PVnav
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, About / Help, OnlineHelp
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, &Exit`tEsc, Exit
   
   Gui, 1: Color, 020100
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MaxGUISize% %MinGUISize% +hwndPVhwnd +LastFound
;   Gui, 1: Font, s20 cC0C0C0, Times New Roman
;   Gui, 1: Add, Text, vScriptMsg BackgroundTrans Wrap w280, Drop an image file here.
   Gui, 1: Add, Picture, x1 y1 vPicOnGUI1
   Gui, 1: Add, Picture, x1 y1 vPicOnGUI2
   Gui, 1: Show, maximize center %initialwh%, %ScriptTitle%
   GuiControl, Disable, PicOnGui1
   GuiControl, Disable, PicOnGui2
   GuiControl, Hide, PicOnGui1
   GuiControl, Hide, PicOnGui2
}

ShowImage(imgpath) {
   Static prevPicCtrl
   SplitPath, imgpath, imgname
   Gui, 1: Show,, %imgpath%   ;update the title
   thisCtrl := (prevPicCtrl=1) ? 2 : 1
   GuiControl,, PicOnGUI%thisCtrl%, *h-1 %imgpath%   ;display the image
;  WinGetPos,,, mainWid, mainHeig, ahk_id %PVhwnd%
   GetClientSize(mainWid, mainHeig, PVhwnd)
   result := ResizeImage("PicOnGUI" thisCtrl, mainWid, mainHeig, imgpath)
   If (result=1)
   {
      GuiControl, Show, PicOnGUI%thisCtrl%
      GuiControl, Hide, PicOnGUI%prevPicCtrl%
   }
   prevPicCtrl := thisCtrl
}

ResizeImage(control, GuiW, GuiH, imgpath) {
   ;global imgW, imgH, PVhwnd, DistanceGuitoImg_X, DistanceGuitoImg_Y
   static LastGuiwinX, LastGuiwinY

   if !GetImgDimension(imgpath, imgW, imgH)
   {
      SoundBeep 
;     MsgBox, Could not display the image
      Return 0
   }

   PicRatio := round(imgW/imgH, 5)
   GuiRatio := round(GuiW/GuiH, 5)
   if (imgW <= GuiW) && (imgH <= GuiH)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio, 5)
      If (ResizedH>GuiH)
      {
         ResizedH := (imgH <= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
         ResizedW := Round(ResizedH * PicRatio, 5)
      }   

      ; ResizedW := imgW
      ; ResizedH := imgH
   } else if (PicRatio > GuiRatio)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio, 5)
   } else
   {
      ResizedH := (imgH >= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
      ResizedW := Round(ResizedH * PicRatio, 5)
   }
;   GuiControl, Show, %control%
   GuiControl, Move, %control%, % "w" . ResizedW . " h" . ResizedH . " x" . (GuiW - ResizedW )/2 . " y" . (GuiH - ResizedH)/2
   Return 1
}

GetClientSize(ByRef w, ByRef h, hwnd) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
} 

IsCompiled(path=False) {
   if !path
      path := A_ScriptFullPath
   SplitPath, path,,, ext
   if (ext = "exe")
      Return True
   else
      Return False
}

IsImage(filepath) {
   Loop, %filepath%
      If A_LoopFileExt in %pattern%
         Return True
}

GetFileLongPath(shortpath) {
   Loop, %shortpath%
      return A_LoopFileLongPath
}

;by [VxE] http://www.autohotkey.com/forum/post-200921.html
HSL_to_RGB( hue, sat, lum ) ; inputs should be [0,360) : [0,1) : [0,1), output = 24b hex BGR
{ ; Function by [VxE], formula from wikipedia.org/wiki/HSV_color_space
   OFF := A_FormatFloat
   SetFormat, Float, 0.16
   If ( lum < 0.5 )
     weight := Lum + Lum * Sat
   else
     weight := Lum + Sat - Lum * Sat
   size := 2 * Lum - weight
   value := hue / 360
   red := value + 1/3 - (value > 2/3)
   green := value
   blue := value - 1/3 + (value < 1/3)

   If (blue < 1/6)
     blue := (blue * 6 * (weight - size)) + size
   else if (blue < 1/2)
     blue := weight
   else if (blue < 2/3)
     blue := ((2/3 - blue) * 6 * (weight - size)) + size
   else
     blue := size

   If (green < 1/6)
     green := (green * 6 * (weight - size)) + size
   else if (green < 1/2)
     green := weight
   else if (green < 2/3)
     green := ((2/3 - green) * 6 * (weight - size)) + size
   else
     green := size

   If (red < 1/6)
     red := (red * 6 * (weight - size)) + size
   else if (red < 1/2)
     red := weight
   else if (red < 2/3)
     red := ((2/3 - red) * 6 * (weight - size)) + size
   else
     red := size

   OIF := A_FormatInteger
   SetFormat, Integer, Hex
   ret := (Round(blue*256) << 16) | (Round(green*256) << 8) | Round(red*256)
   SetFormat, Float, %OFF%
   SetFormat, Integer, %OIF%
   ret := "0x" SubStr( "00000" SubStr(ret, 3), -5 )
   StringUpper, ret, ret
   return ret
}

Random(min, max)
{
   random, num, min, max
   return num
}










GenerateFilesList(readThisFile:=0) {
    resultedFilesList := ""
    maxFilesIndex := 0
    If !readThisFile
       readThisFile := StrReplace(A_ScriptName, "-script.ahk", ".sld")
    FileRead, tehFileVar, %readThisFile%
    tehFileVar := RegExReplace(tehFileVar, "\x22", "+")
    Loop, Parse, tehFileVar,`n,`r
    {
       If RegExMatch(A_LoopField, "^\+.\:\\.*.\\\+\-.?.?")
       {
          folder := StrReplace(A_LoopField, "\+-", "\*")
          folder := StrReplace(folder, "+")
          resultedFilesList .= GetFilesList(folder)
       }
    }
    currentFileIndex := 1
}

GetFilesList(strDir) {
;  ToolTip, Level #%intLevel% %strDir%
  Loop, Files, %strDir%, R
  {
      If RegExMatch(A_LoopFileName, "i)(\.(jpg|jpeg|png|bmp|gif))$")
      {
         finalList .= A_LoopFileFullPath "`n"
         maxFilesIndex++
      }
  }

  Return finalList
}

IDshowImage(imgID) {
    resultu := ST_ReadLine(resultedFilesList, imgID)
    ShowImage(resultu)
}

ST_ReadLine(string, line, delim="`n", exclude="`r") {
   StringReplace, string, string, %delim%, %delim%, UseErrorLevel
   TotalLcount := ErrorLevel+1

   If (abs(line)>TotalLCount && (line!="L" || line!="R"))
      Return 0

   If (Line="R")
      Random, Rand, 1, %TotalLcount%
   Else If (line<=0)
      line := TotalLcount+line

   Loop, parse, String, %delim%, %exclude%
   {
      out := (Line="R" && A_Index==Rand) ? A_LoopField
           : (Line="L" && A_Index==TotalLcount) ? A_LoopField
           : (A_Index==Line) ? A_LoopField : -1
      If (out!=-1) ; Something was found so stop searching.
         Break
   }
   Return out
}

