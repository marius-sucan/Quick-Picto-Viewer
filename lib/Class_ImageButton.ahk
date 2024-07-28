﻿; ======================================================================================================================
; Namespace:         ImageButton
; Function:          Create images and assign them to pushbuttons.
; Tested with:       AHK 1.1.33.02 (A32/U32/U64)
; Tested on:         Win 10 (x64)
; Change history:    1.7.10.00/2023-11-09/marius-sucan - ImageButton.Create() now returns the handle to the ImageList on success, to allow users to dispose them, and avoid memory leaks; fixed some memory leaks in the code
; Change history:    1.7.00.00/2023-03-21/marius-sucan - [new] ability to use bitmaps as button labels/captions or a text label for each state and it no longer rejects check-boxes with BS_PUSHLIKE style
;               :    1.6.00.00/2023-02-02/marius-sucan - It now allows to use & to underline the accelerator key for the button, and they are no longer broken, they work.. It breaks winxp compatiblity.
;                                                        Changed all PTR and PtrP to Uptr and Uptr*.

;                    1.5.00.00/2020-12-16/just me - increased script performance, added support for icons (HICON)
;                    1.4.00.00/2014-06-07/just me - fixed bug for button caption = "0", "000", etc.
;                    1.3.00.00/2014-02-28/just me - added support for ARGB colors
;                    1.2.00.00/2014-02-23/just me - added borders
;                    1.1.00.00/2013-12-26/just me - added rounded and bicolored buttons       
;                    1.0.00.00/2013-12-21/just me - initial release
; How to use:
;     1. Create a push button (e.g. "Gui, Add, Button, vMyButton hwndHwndButton, Caption") using the 'Hwnd' option
;        to get its HWND.
;     2. Call ImageButton.Create() passing two parameters:
;        HWND        -  Button's HWND.
;        Options*    -  variadic array containing up to 6 option arrays (see below).
;        ---------------------------------------------------------------------------------------------------------------
;        The index of each option object determines the corresponding button state on which the bitmap will be shown.
;        MSDN defines 6 states (http://msdn.microsoft.com/en-us/windows/bb775975):
;            PBS_NORMAL    = 1
;            PBS_HOT       = 2
;            PBS_PRESSED   = 3
;            PBS_DISABLED  = 4
;            PBS_DEFAULTED = 5
;            PBS_STYLUSHOT = 6 <- used only on tablet computers (that's false for Windows Vista and 7, see below)
;        If you don't want the button to be 'animated' on themed GUIs, just pass one option object with index 1.
;        On Windows Vista and 7 themed bottons are 'animated' using the images of states 5 and 6 after clicked.
;        ---------------------------------------------------------------------------------------------------------------
;        Each option array may contain the following values:
;           Index Value
;           1     Mode        mandatory:
;                             0  -  unicolored or bitmap
;                             1  -  vertical bicolored
;                             2  -  horizontal bicolored
;                             3  -  vertical gradient
;                             4  -  horizontal gradient
;                             5  -  vertical gradient using StartColor at both borders and TargetColor at the center
;                             6  -  horizontal gradient using StartColor at both borders and TargetColor at the center
;                             7  -  'raised' style
;           2     StartColor  mandatory for Option[1], higher indices will inherit the value of Option[1], if omitted:
;                             -  ARGB integer value (0xAARRGGBB) or HTML color name ("Red").
;                             -  Path of an image file or HBITMAP handle for mode 0.
;           3     TargetColor mandatory for Option[1] if Mode > 0. Higher indcices will inherit the color of Option[1],
;                             if omitted:
;                             -  ARGB integer value (0xAARRGGBB) or HTML color name ("Red").
;                             -  String "HICON" if StartColor contains a HICON handle.
;           4     TextColor   optional, if omitted, the default text color will be used for Option[1], higher indices 
;                             will inherit the color of Option[1]:
;                             -  ARGB integer value (0xAARRGGBB) or HTML color name ("Red").
;                                Default: 0xFF000000 (black)
;           5     Rounded     optional:
;                             -  Radius of the rounded corners in pixel; the letters 'H' and 'W' may be specified
;                                also to use the half of the button's height or width respectively.
;                                Default: 0 - not rounded
;           6     GuiColor    optional, needed for rounded buttons if you've changed the GUI background color:
;                             -  RGB integer value (0xRRGGBB) or HTML color name ("Red").
;                                Default: AHK default GUI background color
;           7     BorderColor optional, ignored for modes 0 (bitmap) and 7, color of the border:
;                             -  RGB integer value (0xRRGGBB) or HTML color name ("Red").
;           8     BorderWidth optional, ignored for modes 0 (bitmap) and 7, width of the border in pixels:
;                             -  Default: 1
;           9     DrawText    optional, set this to 0 to not draw the text
;                             -  Default: 1
;           10    NewLabel    optional, set the label to use; it can be a string, or a path to an image file, or a reference to a GDI+ bitmap - it has to be like PBMP:handle
;                             - BorderWidth is used as a margin
;                             -  Default: none
;        ---------------------------------------------------------------------------------------------------------------
;        If the the button has a caption it will be drawn above the bitmap.
; Credits:           THX tic     for GDIP.AHK     : http://www.autohotkey.com/forum/post-198949.html
;                    THX tkoi    for ILBUTTON.AHK : http://www.autohotkey.com/forum/topic40468.html
; ======================================================================================================================
; This software is provided 'as-is', without any express or implied warranty.
; In no event will the authors be held liable for any damages arising from the use of this software.
; ======================================================================================================================
; ======================================================================================================================
; CLASS ImageButton()
; ======================================================================================================================
Class ImageButton {
   ; ===================================================================================================================
   ; PUBLIC PROPERTIES =================================================================================================
   ; ===================================================================================================================
   Static DefGuiColor  := ""        ; default GUI color                             (read/write)
   Static DefTxtColor := "Black"    ; default caption color                         (read/write)
   Static LastError := ""           ; will contain the last error message, if any   (readonly)
   ; ===================================================================================================================
   ; PRIVATE PROPERTIES ================================================================================================
   ; ===================================================================================================================
   Static BitMaps := []
   Static MaxOptions := 10
   ; HTML colors
   Static HTML := {BLACK: 0x000000, GRAY: 0x808080, SILVER: 0xC0C0C0, WHITE: 0xFFFFFF, MAROON: 0x800000
                 , PURPLE: 0x800080, FUCHSIA: 0xFF00FF, RED: 0xFF0000, GREEN: 0x008000, OLIVE: 0x808000
                 , YELLOW: 0xFFFF00, LIME: 0x00FF00, NAVY: 0x000080, TEAL: 0x008080, AQUA: 0x00FFFF, BLUE: 0x0000FF}
   ; Initialize
   Static ClassInit := ImageButton.InitClass()
   ; ===================================================================================================================
   ; PRIVATE METHODS ===================================================================================================
   ; ===================================================================================================================
   __New(P*) {
      Return False
   }
   ; ===================================================================================================================
   InitClass() {
      ; ----------------------------------------------------------------------------------------------------------------
      ; Get AHK's default GUI background color
      GuiColor := DllCall("User32.dll\GetSysColor", "Int", 15, "UInt") ; COLOR_3DFACE is used by AHK as default
      This.DefGuiColor := ((GuiColor >> 16) & 0xFF) | (GuiColor & 0x00FF00) | ((GuiColor & 0xFF) << 16)
      Return True
   }
   ; ===================================================================================================================
   BitmapOrIcon(O2, O3) {
      ; OBJ_BITMAP = 7
      Return (This.IsInt(O2) && (O3 = "HICON")) || (DllCall("GetObjectType", "UPtr", O2, "UInt") = 7) || FileExist(O2)
   }
   ; ===================================================================================================================
   FreeBitmaps() {
      For I, HBITMAP In This.BitMaps
         DllCall("Gdi32.dll\DeleteObject", "UPtr", HBITMAP)
      This.BitMaps := []
   }
   ; ===================================================================================================================
   GetARGB(RGB) {
      ARGB := This.HTML.HasKey(RGB) ? This.HTML[RGB] : RGB
      Return (ARGB & 0xFF000000) = 0 ? 0xFF000000 | ARGB : ARGB
   }
   ; ===================================================================================================================
   IsInt(Val) {
      If Val Is Integer
         Return True
      Return False
   }
   ; ===================================================================================================================
   PathAddRectangle(Path, X, Y, W, H) {
      Return DllCall("Gdiplus.dll\GdipAddPathRectangle", "UPtr", Path, "Float", X, "Float", Y, "Float", W, "Float", H)
   }
   ; ===================================================================================================================
   PathAddRoundedRect(Path, X1, Y1, X2, Y2, R) {
      D := (R * 2), X2 -= D, Y2 -= D
      DllCall("Gdiplus.dll\GdipAddPathArc"
            , "UPtr", Path, "Float", X1, "Float", Y1, "Float", D, "Float", D, "Float", 180, "Float", 90)
      DllCall("Gdiplus.dll\GdipAddPathArc"
            , "UPtr", Path, "Float", X2, "Float", Y1, "Float", D, "Float", D, "Float", 270, "Float", 90)
      DllCall("Gdiplus.dll\GdipAddPathArc"
            , "UPtr", Path, "Float", X2, "Float", Y2, "Float", D, "Float", D, "Float", 0, "Float", 90)
      DllCall("Gdiplus.dll\GdipAddPathArc"
            , "UPtr", Path, "Float", X1, "Float", Y2, "Float", D, "Float", D, "Float", 90, "Float", 90)
      Return DllCall("Gdiplus.dll\GdipClosePathFigure", "UPtr", Path)
   }
   ; ===================================================================================================================
   SetRect(ByRef Rect, X1, Y1, X2, Y2) {
      VarSetCapacity(Rect, 16, 0)
      NumPut(X1, Rect, 0, "Int"), NumPut(Y1, Rect, 4, "Int")
      NumPut(X2, Rect, 8, "Int"), NumPut(Y2, Rect, 12, "Int")
      Return True
   }
   ; ===================================================================================================================
   SetRectF(ByRef Rect, X, Y, W, H) {
      VarSetCapacity(Rect, 16, 0)
      NumPut(X, Rect, 0, "Float"), NumPut(Y, Rect, 4, "Float")
      NumPut(W, Rect, 8, "Float"), NumPut(H, Rect, 12, "Float")
      Return True
   }
   ; ===================================================================================================================
   SetError(Msg) {
      If (This.Bitmap)
         DllCall("Gdiplus.dll\GdipDisposeImage", "UPtr", This.Bitmap)
      If (This.Graphics)
         DllCall("Gdiplus.dll\GdipDeleteGraphics", "UPtr", This.Graphics)
      If (This.Font)
         DllCall("Gdiplus.dll\GdipDeleteFont", "UPtr", This.Font)
      This.Delete("Bitmap")
      This.Delete("Graphics")
      This.Delete("Font")
      This.FreeBitmaps()
      ; This.GdiplusShutdown()
      This.LastError := Msg
      Return False
   }
   ; ===================================================================================================================
   ; PUBLIC METHODS ====================================================================================================
   ; ===================================================================================================================
   Create(HWND, Options*) {
      Critical, on
      ; Windows constants
      Static BCM_GETIMAGELIST := 0x1603, BCM_SETIMAGELIST := 0x1602
           , BS_CHECKBOX := 0x02, BS_RADIOBUTTON := 0x04, BS_GROUPBOX := 0x07, BS_AUTORADIOBUTTON := 0x09
           , BS_LEFT := 0x0100, BS_RIGHT := 0x0200, BS_CENTER := 0x0300, BS_TOP := 0x0400, BS_BOTTOM := 0x0800
           , BS_VCENTER := 0x0C00, BS_BITMAP := 0x0080, BS_PUSHLIKE := 0x1000
           , BUTTON_IMAGELIST_ALIGN_LEFT := 0, BUTTON_IMAGELIST_ALIGN_RIGHT := 1, BUTTON_IMAGELIST_ALIGN_CENTER := 4
           , ILC_COLOR32 := 0x20, OBJ_BITMAP := 7
           , RCBUTTONS := BS_CHECKBOX | BS_RADIOBUTTON | BS_AUTORADIOBUTTON
           , SA_LEFT := 0x00, SA_CENTER := 0x01, SA_RIGHT := 0x02
           , WM_GETFONT := 0x31
      ; ----------------------------------------------------------------------------------------------------------------
      This.LastError := ""
      HBITMAP := HFORMAT := PBITMAP := PBRUSH := PFONT := PPATH := 0
      ; ----------------------------------------------------------------------------------------------------------------
      ; Check HWND
      If !DllCall("User32.dll\IsWindow", "UPtr", HWND)
         Return This.SetError("Invalid parameter HWND!")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Check Options
      If !(IsObject(Options)) || (Options.MinIndex() <> 1) || (Options.MaxIndex() > This.MaxOptions)
         Return This.SetError("Invalid parameter Options!")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Get and check control's class and styles
      WinGetClass, BtnClass, ahk_id %HWND%
      ControlGet, BtnStyle, Style, , , ahk_id %HWND%
      pushLike := BtnStyle & BS_PUSHLIKE ? 1 : 0
      If (BtnClass != "Button") || (((BtnStyle & 0xF ^ BS_GROUPBOX) = 0) || ((BtnStyle & RCBUTTONS) > 1) && pushLike!=1)
         Return This.SetError("The control must be a pushbutton!")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Get the button's font
      HFONT := DllCall("User32.dll\SendMessage", "UPtr", HWND, "UInt", WM_GETFONT, "UPtr", 0, "UPtr", 0, "Ptr")
      DC := DllCall("User32.dll\GetDC", "UPtr", HWND, "Ptr")
      DllCall("Gdi32.dll\SelectObject", "UPtr", DC, "UPtr", HFONT)
      DllCall("Gdiplus.dll\GdipCreateFontFromDC", "UPtr", DC, "UPtr*", PFONT)
      DllCall("User32.dll\ReleaseDC", "UPtr", HWND, "UPtr", DC)
      If !(This.Font := PFONT) && (Options[1, 9]!=0)
         Return This.SetError("Couldn't get button's font!")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Get the button's rectangle
      VarSetCapacity(RECT, 16, 0)
      If !DllCall("User32.dll\GetWindowRect", "UPtr", HWND, "UPtr", &RECT)
         Return This.SetError("Couldn't get button's rectangle!")
      BtnW := NumGet(RECT,  8, "Int") - NumGet(RECT, 0, "Int")
      BtnH := NumGet(RECT, 12, "Int") - NumGet(RECT, 4, "Int")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Get the button's caption
      ControlGetText, BtnCaption, , ahk_id %HWND%
      If (ErrorLevel)
         Return This.SetError("Couldn't get button's caption!")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Create a GDI+ bitmap
      DllCall("Gdiplus.dll\GdipCreateBitmapFromScan0", "Int", BtnW, "Int", BtnH, "Int", 0
            , "UInt", 0x26200A, "UPtr", 0, "UPtr*", PBITMAP)
      If !(This.Bitmap := PBITMAP)
         Return This.SetError("Couldn't create the GDI+ bitmap!")

      ; Get the pointer to its graphics
      PGRAPHICS := 0
      DllCall("Gdiplus.dll\GdipGetImageGraphicsContext", "UPtr", PBITMAP, "UPtr*", PGRAPHICS)
      If !(This.Graphics := PGRAPHICS)
         Return This.SetError("Couldn't get the the GDI+ bitmap's graphics!")
      ; Quality settings
      DllCall("Gdiplus.dll\GdipSetSmoothingMode", "UPtr", PGRAPHICS, "UInt", 4)
      DllCall("Gdiplus.dll\GdipSetInterpolationMode", "UPtr", PGRAPHICS, "Int", 7)
      DllCall("Gdiplus.dll\GdipSetCompositingQuality", "UPtr", PGRAPHICS, "UInt", 4)
      DllCall("Gdiplus.dll\GdipSetRenderingOrigin", "UPtr", PGRAPHICS, "Int", 0, "Int", 0)
      DllCall("Gdiplus.dll\GdipSetPixelOffsetMode", "UPtr", PGRAPHICS, "UInt", 4)
      ; ----------------------------------------------------------------------------------------------------------------
      ; Create the bitmap(s)
      This.BitMaps := []
      For Idx, Opt In Options
      {
         If !IsObject(Opt)
            Continue

         BkgColor1 := BkgColor2 := TxtColor := Mode := Rounded := GuiColor := Image := ""
         ; Replace omitted options with the values of Options.1
         Loop, % This.MaxOptions
         {
            If (Opt[A_Index] = "")
               Opt[A_Index] := Options[1, A_Index]
         }
         ; -------------------------------------------------------------------------------------------------------------
         ; Check option values
         ; Mode
         Mode := SubStr(Opt[1], 1 ,1)
         If !InStr("0123456789", Mode)
            Return This.SetError("Invalid value for Mode in Options[" . Idx . "]!")
         ; StartColor & TargetColor
         If (Mode = 0) && This.BitmapOrIcon(Opt[2], Opt[3])
            Image := Opt[2]
         Else {
            If !This.IsInt(Opt[2]) && !This.HTML.HasKey(Opt[2])
               Return This.SetError("Invalid value for StartColor in Options[" . Idx . "]!")
            BkgColor1 := This.GetARGB(Opt[2])
            If (Opt[3] = "")
               Opt[3] := Opt[2]
            If !This.IsInt(Opt[3]) && !This.HTML.HasKey(Opt[3])
               Return This.SetError("Invalid value for TargetColor in Options[" . Idx . "]!")
            BkgColor2 := This.GetARGB(Opt[3])
         }
         ; TextColor
         If (Opt[4] = "")
            Opt[4] := This.DefTxtColor
         If !This.IsInt(Opt[4]) && !This.HTML.HasKey(Opt[4])
            Return This.SetError("Invalid value for TxtColor in Options[" . Idx . "]!")
         TxtColor := This.GetARGB(Opt[4])
         ; Rounded
         Rounded := Opt[5]
         If (Rounded = "H")
            Rounded := BtnH * 0.5
         If (Rounded = "W")
            Rounded := BtnW * 0.5
         If ((Rounded + 0) = "")
            Rounded := 0
         ; GuiColor
         If (Opt[6] = "")
            Opt[6] := This.DefGuiColor
         If !This.IsInt(Opt[6]) && !This.HTML.HasKey(Opt[6])
            Return This.SetError("Invalid value for GuiColor in Options[" . Idx . "]!")

         GuiColor := This.GetARGB(Opt[6])
         ; BorderColor
         BorderColor := ""
         If (Opt[7] <> "")
         {
            If !This.IsInt(Opt[7]) && !This.HTML.HasKey(Opt[7])
               Return This.SetError("Invalid value for BorderColor in Options[" . Idx . "]!")
            BorderColor := 0xFF000000 | This.GetARGB(Opt[7]) ; BorderColor must be always opaque
         }
         ; BorderWidth
         BorderWidth := Opt[8] ? Opt[8] : 1
         ; -------------------------------------------------------------------------------------------------------------
         ; Clear the background
         DllCall("Gdiplus.dll\GdipGraphicsClear", "UPtr", PGRAPHICS, "UInt", GuiColor)
         ; Create the image
         If (Image = "") { ; Create a BitMap based on the specified colors
            PathX := PathY := 0, PathW := BtnW, PathH := BtnH
            ; Create a GraphicsPath
            DllCall("Gdiplus.dll\GdipCreatePath", "UInt", 0, "UPtr*", PPATH)
            If (Rounded < 1) ; the path is a rectangular rectangle
               This.PathAddRectangle(PPATH, PathX, PathY, PathW, PathH)
            Else ; the path is a rounded rectangle
               This.PathAddRoundedRect(PPATH, PathX, PathY, PathW, PathH, Rounded)
            ; If BorderColor and BorderWidth are specified, 'draw' the border (not for Mode 7)
            If (BorderColor <> "") && (BorderWidth > 0) && (Mode <> 7) {
               ; Create a SolidBrush
               DllCall("Gdiplus.dll\GdipCreateSolidFill", "UInt", BorderColor, "UPtr*", PBRUSH)
               ; Fill the path
               DllCall("Gdiplus.dll\GdipFillPath", "UPtr", PGRAPHICS, "UPtr", PBRUSH, "UPtr", PPATH)
               ; Free the brush
               DllCall("Gdiplus.dll\GdipDeleteBrush", "UPtr", PBRUSH)
               ; Reset the path
               DllCall("Gdiplus.dll\GdipResetPath", "UPtr", PPATH)
               ; Add a new 'inner' path
               PathX := PathY := BorderWidth, PathW -= BorderWidth, PathH -= BorderWidth, Rounded -= BorderWidth
               If (Rounded < 1) ; the path is a rectangular rectangle
                  This.PathAddRectangle(PPATH, PathX, PathY, PathW - PathX, PathH - PathY)
               Else ; the path is a rounded rectangle
                  This.PathAddRoundedRect(PPATH, PathX, PathY, PathW, PathH, Rounded)
               ; If a BorderColor has been drawn, BkgColors must be opaque
               BkgColor1 := 0xFF000000 | BkgColor1
               BkgColor2 := 0xFF000000 | BkgColor2               
            }

            PathW -= PathX
            PathH -= PathY
            PBRUSH := 0
            If (Mode = 0) { ; the background is unicolored
               ; Create a SolidBrush
               DllCall("Gdiplus.dll\GdipCreateSolidFill", "UInt", BkgColor1, "UPtr*", PBRUSH)
               ; Fill the path
               DllCall("Gdiplus.dll\GdipFillPath", "UPtr", PGRAPHICS, "UPtr", PBRUSH, "UPtr", PPATH)
            }
            Else If (Mode = 1) || (Mode = 2) { ; the background is bicolored
               ; Create a LineGradientBrush
               This.SetRectF(RECTF, PathX, PathY, PathW, PathH)
               DllCall("Gdiplus.dll\GdipCreateLineBrushFromRect", "UPtr", &RECTF
                     , "UInt", BkgColor1, "UInt", BkgColor2, "Int", Mode & 1, "Int", 3, "UPtr*", PBRUSH)
               DllCall("Gdiplus.dll\GdipSetLineGammaCorrection", "UPtr", PBRUSH, "Int", 1)
               ; Set up colors and positions
               This.SetRect(COLORS, BkgColor1, BkgColor1, BkgColor2, BkgColor2) ; sorry for function misuse
               This.SetRectF(POSITIONS, 0, 0.5, 0.5, 1) ; sorry for function misuse
               DllCall("Gdiplus.dll\GdipSetLinePresetBlend", "UPtr", PBRUSH
                     , "UPtr", &COLORS, "UPtr", &POSITIONS, "Int", 4)
               ; Fill the path
               DllCall("Gdiplus.dll\GdipFillPath", "UPtr", PGRAPHICS, "UPtr", PBRUSH, "UPtr", PPATH)
            }
            Else If (Mode >= 3) && (Mode <= 6) { ; the background is a gradient
               ; Determine the brush's width/height
               W := Mode = 6 ? PathW / 2 : PathW  ; horizontal
               H := Mode = 5 ? PathH / 2 : PathH  ; vertical
               ; Create a LineGradientBrush
               This.SetRectF(RECTF, PathX, PathY, W, H)
               DllCall("Gdiplus.dll\GdipCreateLineBrushFromRect", "UPtr", &RECTF
                     , "UInt", BkgColor1, "UInt", BkgColor2, "Int", Mode & 1, "Int", 3, "UPtr*", PBRUSH)
               DllCall("Gdiplus.dll\GdipSetLineGammaCorrection", "UPtr", PBRUSH, "Int", 1)
               ; Fill the path
               DllCall("Gdiplus.dll\GdipFillPath", "UPtr", PGRAPHICS, "UPtr", PBRUSH, "UPtr", PPATH)
            }
            Else { ; raised mode
               DllCall("Gdiplus.dll\GdipCreatePathGradientFromPath", "UPtr", PPATH, "UPtr*", PBRUSH)
               ; Set Gamma Correction
               DllCall("Gdiplus.dll\GdipSetPathGradientGammaCorrection", "UPtr", PBRUSH, "UInt", 1)
               ; Set surround and center colors
               VarSetCapacity(ColorArray, 4, 0)
               NumPut(BkgColor1, ColorArray, 0, "UInt")
               DllCall("Gdiplus.dll\GdipSetPathGradientSurroundColorsWithCount", "UPtr", PBRUSH, "UPtr", &ColorArray, "IntP", 1)
               DllCall("Gdiplus.dll\GdipSetPathGradientCenterColor", "UPtr", PBRUSH, "UInt", BkgColor2)
               ; Set the FocusScales
               FS := (BtnH < BtnW ? BtnH : BtnW) / 3
               XScale := (BtnW - FS) / BtnW
               YScale := (BtnH - FS) / BtnH
               DllCall("Gdiplus.dll\GdipSetPathGradientFocusScales", "UPtr", PBRUSH, "Float", XScale, "Float", YScale)
               ; Fill the path
               DllCall("Gdiplus.dll\GdipFillPath", "UPtr", PGRAPHICS, "UPtr", PBRUSH, "UPtr", PPATH)
            }
            ; Free resources
            DllCall("Gdiplus.dll\GdipDeleteBrush", "UPtr", PBRUSH)
            DllCall("Gdiplus.dll\GdipDeletePath", "UPtr", PPATH)
         } Else { ; Create a bitmap from HBITMAP or file
            If This.IsInt(Image)
               If (Opt[3] = "HICON")
                  DllCall("Gdiplus.dll\GdipCreateBitmapFromHICON", "UPtr", Image, "UPtr*", PBM)
               Else
                  DllCall("Gdiplus.dll\GdipCreateBitmapFromHBITMAP", "UPtr", Image, "UPtr", 0, "UPtr*", PBM)
            Else
               DllCall("Gdiplus.dll\GdipCreateBitmapFromFile", "WStr", Image, "UPtr*", PBM)
            ; Draw the bitmap
            DllCall("Gdiplus.dll\GdipDrawImageRectI", "UPtr", PGRAPHICS, "UPtr", PBM, "Int", 0, "Int", 0, "Int", BtnW, "Int", BtnH)
            ; Free the bitmap
            DllCall("Gdiplus.dll\GdipDisposeImage", "UPtr", PBM)
         }
         ; -------------------------------------------------------------------------------------------------------------
         ; Draw the caption
         kCaption := (Opt[10]!="") ? Trim(Opt[10], A_Space) : BtnCaption
         thisCaption := (Opt[9]=0) ? "" : kCaption
         If (SubStr(Opt[10], 1, 5)="PBMP:") {
            ; the caller has to manage [create and destroy] the pBitmap
            ZPBM := SubStr(Opt[10], 6)
            DllCall("Gdiplus.dll\GdipDrawImage", "UPtr", PGRAPHICS, "UPtr", ZPBM, "Int", 0, "Int", 0)
         } Else If (FileExist(Opt[10]) && Opt[10]) {
            DllCall("Gdiplus.dll\GdipCreateBitmapFromFile", "WStr", Opt[10], "UPtr*", ZPBM)
            If StrLen(ZPBM)>1
            {
               ; fnOutputDebug(A_ThisFunc "=file=" ZPBM)
               iw := ih := 0
               DllCall("gdiplus\GdipGetImageDimension", "UPtr", ZPBM, "float*", iw, "float*", ih)
               calcIMGdimensions(iw, ih, BtnW - BorderWidth*2, BtnH - BorderWidth*2, nW, nH)
               px := BorderWidth + (BtnW - BorderWidth*2)/2 - nW//2
               py := BorderWidth + (BtnH - BorderWidth*2)/2 - nH//2
               ; ToolTip, % Round(iw) "|" Round(ih) "`n" Round(px) "|" Round(py) "`n" Round(BtnW) "|" Round(BtnH) , , , 2
               DllCall("Gdiplus.dll\GdipDrawImageRectI", "UPtr", PGRAPHICS, "UPtr", ZPBM, "Int", px, "Int", py, "Int", nW, "Int", nH)
               DllCall("Gdiplus.dll\GdipDisposeImage", "UPtr", ZPBM)
            }
         } Else If (thisCaption <> "") {
            ; Create a StringFormat object
            DllCall("Gdiplus.dll\GdipStringFormatGetGenericTypographic", "UPtr*", HFORMAT)
            ; Text color
            DllCall("Gdiplus.dll\GdipCreateSolidFill", "UInt", TxtColor, "UPtr*", PBRUSH)
            ; Horizontal alignment
            HALIGN := (BtnStyle & BS_CENTER) = BS_CENTER ? SA_CENTER
                    : (BtnStyle & BS_CENTER) = BS_RIGHT  ? SA_RIGHT
                    : (BtnStyle & BS_CENTER) = BS_Left   ? SA_LEFT
                    : SA_CENTER
            DllCall("Gdiplus.dll\GdipSetStringFormatAlign", "UPtr", HFORMAT, "Int", HALIGN)
            ; Vertical alignment
            VALIGN := (BtnStyle & BS_VCENTER) = BS_TOP ? 0
                    : (BtnStyle & BS_VCENTER) = BS_BOTTOM ? 2
                    : 1
            DllCall("Gdiplus.dll\GdipSetStringFormatLineAlign", "UPtr", HFORMAT, "Int", VALIGN)
            DllCall("gdiplus\GdipSetStringFormatHotkeyPrefix", "UPtr", HFORMAT, "uint", 1)
             ; Set render quality to system default
            DllCall("Gdiplus.dll\GdipSetTextRenderingHint", "UPtr", PGRAPHICS, "Int", 0)
            ; Set the text's rectangle
            VarSetCapacity(RECT, 16, 0)
            NumPut(BtnW, RECT,  8, "Float")
            NumPut(BtnH, RECT, 12, "Float")
            ; Draw the text
            DllCall("Gdiplus.dll\GdipDrawString", "UPtr", PGRAPHICS, "WStr", thisCaption, "Int", -1
                  , "UPtr", PFONT, "UPtr", &RECT, "UPtr", HFORMAT, "UPtr", PBRUSH)
         }
         ; -------------------------------------------------------------------------------------------------------------
         ; Create a HBITMAP handle from the bitmap and add it to the array
         DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "UPtr", PBITMAP, "UPtr*", HBITMAP, "UInt", 0X00FFFFFF)
         This.BitMaps[Idx] := HBITMAP
         ; Free resources
         DllCall("Gdiplus.dll\GdipDeleteBrush", "UPtr", PBRUSH)
         DllCall("Gdiplus.dll\GdipDeleteStringFormat", "UPtr", HFORMAT)
      }
      ; Now free remaining the GDI+ objects
      DllCall("Gdiplus.dll\GdipDisposeImage", "UPtr", PBITMAP)
      DllCall("Gdiplus.dll\GdipDeleteGraphics", "UPtr", PGRAPHICS)
      DllCall("Gdiplus.dll\GdipDeleteFont", "UPtr", PFONT)
      This.Delete("Bitmap")
      This.Delete("Graphics")
      This.Delete("Font")
      ; ----------------------------------------------------------------------------------------------------------------
      ; Create the ImageList
      HIL := DllCall("Comctl32.dll\ImageList_Create", "UInt", BtnW, "UInt", BtnH, "UInt", ILC_COLOR32, "Int", 6, "Int", 0, "UPtr")
      Loop, % (This.BitMaps.MaxIndex() > 1 ? 6 : 1) {
         HBITMAP := This.BitMaps.HasKey(A_Index) ? This.BitMaps[A_Index] : This.BitMaps.1
         DllCall("Comctl32.dll\ImageList_Add", "UPtr", HIL, "UPtr", HBITMAP, "UPtr", 0)
         DllCall("gdi32\DeleteObject", "UPtr", HBITMAP)
      }
      ; Create a BUTTON_IMAGELIST structure
      VarSetCapacity(BIL, 20 + A_PtrSize, 0)
      ; Get the currently assigned image list
      DllCall("User32.dll\SendMessage", "UPtr", HWND, "UInt", BCM_GETIMAGELIST, "UPtr", 0, "UPtr", &BIL)
      IL := NumGet(BIL, "UPtr")
      ; Create a new BUTTON_IMAGELIST structure
      VarSetCapacity(BIL, 20 + A_PtrSize, 0)
      NumPut(HIL, BIL, 0, "UPtr")
      NumPut(BUTTON_IMAGELIST_ALIGN_CENTER, BIL, A_PtrSize + 16, "UInt")
      Control, Style, +%BS_BITMAP%, , ahk_id %HWND%
      ; Remove the currently assigned image list, if any
      If (IL)
         DllCall("Comctl32.dll\ImageList_Destroy", "UPtr", IL)
      ; Assign the ImageList to the button
      DllCall("User32.dll\SendMessage", "UPtr", HWND, "UInt", BCM_SETIMAGELIST, "UPtr", 0, "UPtr", 0)
      DllCall("User32.dll\SendMessage", "UPtr", HWND, "UInt", BCM_SETIMAGELIST, "UPtr", 0, "UPtr", &BIL)
      ; Free the bitmaps
      BIL := ""
      RECT := ""
      This.FreeBitmaps()
      ; ----------------------------------------------------------------------------------------------------------------
      ; All done successfully
      Return HIL
   }
   ; ===================================================================================================================
   ; Set the default GUI color
   SetGuiColor(GuiColor) {
      ; GuiColor     -  RGB integer value (0xRRGGBB) or HTML color name ("Red").
      If !(GuiColor + 0) && !This.HTML.HasKey(GuiColor)
         Return False
      This.DefGuiColor := (This.HTML.HasKey(GuiColor) ? This.HTML[GuiColor] : GuiColor) & 0xFFFFFF
      Return True
   }
   ; ===================================================================================================================
   ; Set the default text color
   SetTxtColor(TxtColor) {
      ; TxtColor     -  RGB integer value (0xRRGGBB) or HTML color name ("Red").
      If !(TxtColor + 0) && !This.HTML.HasKey(TxtColor)
         Return False
      This.DefTxtColor := (This.HTML.HasKey(TxtColor) ? This.HTML[TxtColor] : TxtColor) & 0xFFFFFF
      Return True
   }
}
