; Script Name: AHK Picture Viewer
; Language:       English
; Platform:       Windows XP or later
; Author:         sbc
; Script Version: 1.0.0 on Oct 4, 2010
; Script Function:
;	Displays images of jpeg, jpg, bmp, png, gif
; Author's website: http://sites.google.com/site/littlescripting/
; AHK forum address for this script:
; Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html


;_________________________________________________________________________________________________________________Auto Execute Section____
#noenv
#notrayicon
#singleinstance, off
DetectHiddenWindows On
CoordMode, Mouse, Screen
OnExit, Exit
; Uncomment if Gdip.ahk is not in your standard library
#Include, Gdip.ahk 


Loop 9
	OnMessage( 255+A_Index, "PreventKeyPressBeep" ) ; 0x100 to 0x108 
  
;program settings
ScriptTitle = AHK Picture Viewer
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
	ImgNum := ImageListfromFile(imgpath)	;create an image list
}
if (ImgList0 > 1)
{
	Menu, PVmenu, Enable, %MenuNameNextPicture%
	Menu, PVmenu, Enable, %MenuNamePrevPicture%
}
;SetTimer, RotateGUIColor, 60000 		;just for fun	;causes a flickering image
Return
;_________________________________________________________________________________________________________________Hotkeys_________________
~Right::
	Gosub, NextPicture
Return
~Left::
	Gosub, PreviousPicture
Return
~^o::
	Gosub, OpenFile
Return
~^w::
	Gosub, Exit
Return
;_________________________________________________________________________________________________________________Labels__________________
GuiClose:
Exit:
	Gdip_Shutdown( GDIPToken )  
ExitApp

OnlineHelp:
	Run, http://www.autohotkey.com/forum/topic62808.html
Return

GuiContextMenu:
	Menu, PVmenu, Show, %A_GuiX%, %A_GuiY%
	if (ImgList0 > 1)
	{
		Menu, PVmenu, Enable, %MenuNameNextPicture%
		Menu, PVmenu, Enable, %MenuNamePrevPicture%
	}

Return 

GuiSize:
	If A_EventInfo = 1	;minimized
		Return
	else if ImgActive
		ResizeImage("PicOnGUI", A_GuiWidth, A_GuiHeight)
	else 
		AlignText("ScriptMsg", A_GuiWidth, A_GuiHeight)
Return

NextPicture:
	Right := True
PreviousPicture:
	ifWinActive, ahk_group AHKPV
		if (ImgNum := ReturnImgNum(ImgNum, Right, ImgList0))
			if (imgpath := ImgList%imgnum%)
				ShowImage(imgpath)
	Right := False
Return

OpenFile:
	ifWinActive, ahk_group AHKPV
	{
		FilterString = Image (
		Loop, Parse, pattern , `,, %A_Space%
			FilterString = %FilterString%*.%A_LoopField%`;%A_Space%
		FilterString := SubStr(FilterString, 1, -1) . ")"
		FileSelectFile, SelectImg, M3, %A_ScriptDir%, Select Images, %FilterString%	
		if SelectImg =
			Return
		Loop, parse, SelectImg, `n
		{
			if a_index = 1
			{
				SelectedDir := A_LoopField
				Continue
			}
			if A_Index = 2
				imgpath = %SelectedDir%\%A_LoopField%
			else if A_LoopField
			{
				if IsCompiled()
					Run, "%A_ScriptFullPath%" "%SelectedDir%\%A_LoopField%"
				else
					Run, %A_AhkPath% "%A_ScriptFullPath%" "%SelectedDir%\%A_LoopField%"
			}
		}
		if(imgpath)
		{
			ShowImage(imgpath)
			ImgNum := ImageListfromFile(imgpath)	;create a imagelist
		}
	}
	if (ImgList0 > 1)
	{
		Menu, PVmenu, Enable, %MenuNameNextPicture%
		Menu, PVmenu, Enable, %MenuNamePrevPicture%
	}	
Return

GuiDropFiles:
	Loop, parse, A_GuiEvent, `n
	{
		if (A_Index = 1)
			imgpath := IsImage(A_LoopField) ? A_LoopField : False
		else
		{
			if IsCompiled()
				Run, "%A_ScriptFullPath%" "%A_LoopField%"
			else
				Run, %A_AhkPath% "%A_ScriptFullPath%" "%A_LoopField%"
		}
	}
	if(imgpath)
	{
		ShowImage(imgpath)
		ImgNum := ImageListfromFile(imgpath)	;create a imagelist
	}
	if (ImgList0 > 1)
	{
		Menu, PVmenu, Enable, %MenuNameNextPicture%
		Menu, PVmenu, Enable, %MenuNamePrevPicture%
	}	
Return 

RotateGuiColor:
	Loop, % random(20, 100)
	{
		Gui, 1: Color, % HSL_to_RGB( hue := (hue = 360) ? 0 : hue+2 , 0.2 , 0.9 )
		sleep 20
	}
Return

GdipShowImg:
	if !(GetKeyState("Right", "P") || GetKeyState("Left", "P"))
	{
		GuiControlGet, PicOnGUI, Pos
		wscale := PicOnGUIW / imgW,	hscale := PicOnGUIH / imgH 
;		hwnd_GdiPic := Gdip_ShowImgonGui("PicOnGUI", imgpath, wscale, hscale) 
		; if !(hwnd_GdiPic := Gdip_ShowImgonGui("PicOnGUI", imgpath, wscale, hscale))
		; {
		; 	GetClientSize(PVhwnd, GuiW, GuiH)
		; 	ShowText("ScriptMsg", "   File loading error.")
		; 	AlignText("ScriptMsg", GuiW, GuiH)
		; }
	}
Return

RemoveTooltip:
	tooltip
Return
;_________________________________________________________________________________________________________________Functions_______________
GetImgDimension(imgpath, ByRef w, ByRef h)	
{
	global GDIPToken
	IfNotExist, %imgpath%
		Return False
	Else
	{                                    
		pBM := Gdip_CreateBitmapFromFile(imgpath)                		 
		w := Gdip_GetImageWidth( pBM )
		h := Gdip_GetImageHeight( pBM )   								
		Gdip_DisposeImage( pBM )                                          
		Return True
	}
}

;creates an array which lists up images in the same directory to a given image file
;and returns the index number of it
ImageListfromFile(filepath)
{
	global 	;pattern, ImgList%n%
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
	SetTimer, RemoveTooltip, 2000
	Loop, %ImgList0%
		if (ImgList%a_index% = filepath)
			Return A_Index
	Imgs = 		;delete		
	
}

ReturnImgNum(currentNum, direction, indexNum)
{
	if indexNum 
	{
		indexNum--		;an array index includes the index element itself, so exlude it
		if direction	;means the user clicked Right, so it is plus
			currentNum := (currentNum >= indexNum) ? 1 : currentNum + 1
		else	;means the user clicked left, so it is minus
			currentNum := (currentNum <= 1) ? indexNum : currentNum - 1
	}
	return currentNum
}

BuildGUI()
{
	global ;PicOnGUI, PVhwnd, ScriptTitle, ScriptMsg , ScriptMsgW, ScriptMsgH, hue
	local MaxGUISize, MinGUISize, initialwh, guiw, guih
	MaxGUISize = +MaxSize%A_ScreenWidth%x%A_ScreenHeight%
	MinGUISize := "+MinSize" . round(A_ScreenWidth/13,2) . "x" . round(A_ScreenHeight/13, 2)
	initialwh := "w" . round(A_ScreenWidth/3,2) . " h" . round(A_ScreenHeight/3, 2)
;	hue := Random(0, 360)
	MenuNameNextPicture = &Next Picture
	MenuNamePrevPicture = &Previous Picture
	Menu, PVmenu, Add, %MenuNameNextPicture% , NextPicture
	Menu, PVmenu, Add, %MenuNamePrevPicture% , PreviousPicture
;	Menu, PVmenu, Add,
	Menu, PVfile, Add, &Open Picture, OpenFile
	Menu, PVfile, Add, &Exit, Exit
	Menu, PVmenu, Disable, %MenuNameNextPicture%
	Menu, PVmenu, Disable, %MenuNamePrevPicture%
	Menu, PVhelp, Add, Get Help, OnlineHelp
	
	Menu, MyMenuBar, Add, &File, :PVfile
	Menu, MyMenuBar, Add, &View, :PVmenu
	Menu, MyMenuBar, Add, &Help, :PVhelp
	Gui, Menu, MyMenuBar
	
	Gui, 1: Color, % HSL_to_RGB( hue := random(0, 360), 0.2, 0.9 )
	Gui, 1: Margin, 0, 0
	GUI, 1: +Resize %MaxGUISize% %MinGUISize% +LastFound
	Gui, 1: Font, s20 cC0C0C0, Times New Roman
	Gui, 1: Add, Text, vScriptMsg BackgroundTrans Wrap w280, Drop an image file here.
	Gui, 1: Add, Picture, vPicOnGUI	
	Gui, 1: Show, restore center %initialwh%, %ScriptTitle%: 
	WinGet, PVhwnd, IDLast
	GroupAdd, AHKPV, ahk_id %PVhwnd%
	GetClientSize(PVhwnd, guiw, guih) 
	GuiControlGet, ScriptMsg, Pos
	GuiControl, MoveDraw, ScriptMsg, % "x" . (guiw - ScriptMsgW)/2 . " y" . (guih - ScriptMsgH)/2 	
	;GuiControl, Disable, ScriptMsg
	GuiControl, Disable, PicOnGui	;disable the beep
}

ShowImage(imgpath)
{
	global PVhwnd, ScriptTitle
	SplitPath, imgpath, imgname
	Gui, 1: Show,, %ScriptTitle%: %imgname%	;update the title	
	GuiControl,, PicOnGUI, *h-1 %imgpath%	;display the image
	ImgActive := True
	ShowText("ScriptMsg", "")
	GetClientSize(PVhwnd, GuiW, GuiH)
	ResizeImage("PicOnGUI", GuiW, GuiH)
}

ShowText(control, texts="Drop an image file here.")
{
	global ImgActive
	GuiControl, Text, %control%, %texts%
	ImgActive := texts ? False : True
}

ResizeImage(control, GuiW, GuiH)
{
	;global imgW, imgH, PVhwnd, DistanceGuitoImg_X, DistanceGuitoImg_Y
	global
	static LastGuiwinX, LastGuiwinY

	SetTimer, GdipShowImg, Off
	if !GetImgDimension(imgpath, imgW, imgH)
	{
		ShowText("ScriptMsg", "Could not display the image.")
		if PVhwnd
		{
			GetClientSize(PVhwnd, GuiW, GuiH)
			AlignText("ScriptMsg", GuiW, GuiH)
		}
		ImgActive := False
		Return
	}		
		
	PicRatio := round(imgW/imgH, 5)
	GuiRatio := round(GuiW/GuiH, 5)
	if (imgW <= GuiW) && (imgH <= GuiH)
	{
		ResizedW := imgW
		ResizedH := imgH
	}
	else if (PicRatio > GuiRatio)
	{
		ResizedW := GuiW
		ResizedH := Round(ResizedW / PicRatio, 5)
	}
	else
	{
		ResizedH := (imgH >= GuiH) ? GuiH : imgH			;set the maximum picture height to the original height
		ResizedW := Round(ResizedH * PicRatio, 5)
	}	
;	GuiControl, Show, %control%
	GuiControl, MoveDraw, %control%, % "w" . ResizedW . " h" . ResizedH . " x" . (GuiW - ResizedW )/2 . " y" . (GuiH - ResizedH)/2
	; SetTimer, GdipShowImg, -500
	return
}

AlignText(control, GuiW, GuiH)
{
	if ImgActive
		Return
	GuiControlGet, %control%, Pos
	GuiControl, MoveDraw, %control%, % "x" . (GuiW - %control%W )/2 . " y" . (GuiH - %control%H)/2
	Return
}

GetClientSize(hwnd, ByRef w, ByRef h)	;by Lexikos http://www.autohotkey.com/forum/post-170475.html
{
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
} 

IsCompiled(path=False)
{
	if !path
		path := A_ScriptFullPath
	SplitPath, path,,, ext
	if (ext = "exe")
		Return True
	else
		Return False
}

IsImage(filepath)
{
	global pattern
	Loop, %filepath%
		If A_LoopFileExt in %pattern%
			Return True
}

GetFileLongPath(shortpath)
{
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

Gdip_ShowImgonGui(GuiVariable, imgfile, wscale=1, hscale=1)   
{
	pBitmap := Gdip_CreateBitmapFromFile(imgfile)
	If !pBitmap
		Return False
	GuiControlGet, hwnd_control, hwnd, %GuiVariable%
	If ErrorLevel
		Return False
	Width := Gdip_GetImageWidth(pBitmap)      
	Height := Gdip_GetImageHeight(pBitmap)   

	pBitmap2 := Gdip_CreateBitmap(Width * wscale, Height * hscale)
	G2 := Gdip_GraphicsFromImage(pBitmap2)
	Gdip_SetInterpolationMode(G2, 1)
	Gdip_SetSmoothingMode(G2, 1)
	Gdip_DrawImage(G2, pBitmap, 0, 0, Width * wscale, Height * hscale, 0, 0, Width, Height)

	hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap2)
	SetImage(hwnd_control, hBitmap)

	Gdip_DeleteGraphics(G), Gdip_DisposeImage(pBitmap), DeleteObject(hBitmap) 
	Gdip_DeleteGraphics(G2), Gdip_DisposeImage(pBitmap2)
	Return hwnd_control
}

;by SKAN http://www.autohotkey.com/forum/post-386538.html
PreventKeyPressBeep() 
{	
	IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}