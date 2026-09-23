; FreeImage v3.18+ library wrapper for AHK v1.1.
; Available at:
; https://github.com/marius-sucan/FreeImage-library/tree/qpv/Wrapper
; Dependency:
; AHK v1.1 GDI+ library wrapper: https://github.com/marius-sucan/AHK-GDIp-Library-Compilation
; Author: Marius Șucan
;
; Change log:
; =============================
;
; 23 September 2026 - v2.01
; - FreeImage_FillBackground() takes three parameters again, as in FreeImage 3.18; options 8 (FI_COLOR_SET_ALPHA) replaces applyAlpha
;
; 22 September 2026 - v2.00
; - implemented all the remaining functions, except the ANSI variants
; - bug fixes: FreeImage_Rotate(), the JPEG transforms, FreeImage_DeletePageEx(), FreeImage_SimpleGetPageCount(), the memory stream functions, and pointers truncated on x64
; - FreeImage_OpenMultiBitmap() takes Unicode paths; added FreeImage_GetFrameDelays() and the *PageEx() functions
; - AVIF, HEIF and APNG in FreeImage_GetFileType()
;
; 10 January 2025 - v1.91
; - improved ConvertFIMtoPBITMAP(); higher performance and more dynamic regarding pixel formats; added ConvertAdvancedFIMtoPBITMAP()
;
; 07 December 2024 - v1.90
; - implemented more functions ; FreeImage_AllocateEx() and FreeImage_FillBackground()
;
; 27 October 2023 - v1.80
; - implemented more functions
;
; 16 July 2022 - v1.70
; - implemented functions to access image metadata tags
;
; 26 February 2021 - v1.60
; - implemented the multi-page functions
;
; 14 January 2021 - v1.50
; - bug fixes - many thanks to TheArkive
;
; 30 June 2020 - v1.40
; - implemented additional functions.
;
; 21 September 2019 - v1.30
; - implemented additional functions.
;
; 11 August 2019 - v1.20
; - added ConvertFIMtoPBITMAP() and ConvertPBITMAPtoFIM() functions
; - implemented 32 bits support for AHK_L 32 bits and FreeImage 32 bits.
; - FreeImage_Save() now relies on FreeImage_GetFIFFromFilename() to get the file format code
; - bug fixes and more in-line comments/information
;
; 6 August 2019 - v1.10
; - it now works with FreeImage v3.18 and AHK_L v1.1.30+.
; - added many new functions and cleaned up the code. Fixed bugs.
;
; 29 March 2012 - v1.00
;  - original version by linpinger
;    source: http://www.autohotkey.net/~linpinger/index.html


FreeImage_FoxInit(isInit:=1, bonusPath:=0, DllName:="FreeImage.dll") {
   Static hFIDll
   Static lastDllName
   If (isInit="lastDllName")
      Return lastDllName

   If !DllName
      DllName := "FreeImage.dll"

   ; if you change the dll name, getFIMfunc() needs to reflect this
   If RegExMatch(bonusPath, "i)(.\.dll)$")
      DllPath := bonusPath
   Else
      DllPath := FreeImage_FoxGetDllPath(DllName, Trim(bonusPath, "\"))

   If !DllPath
      Return "err - 404"

   lastDllName := SubStr(DllPath, InStr(DllPath, "\", 0, -1) + 1)
   If (isInit=1)
      hFIDll := DllCall("LoadLibraryW", "WStr", DllPath, "UPtr")
   Else
      DllCall("FreeLibrary", "UPtr", hFIDll)

   ; ToolTip, % lastDllName "|" DllPath "`n" hFIDll "|" FreeImage_GetVersion() , , , 2
   If (isInit=1 && !hFIDll)
      Return "err - " A_LastError

   Return hFIDll
}

FreeImage_FoxGetDllPath(DllName, bonusPath:="") {
   DirList := "|" A_WorkingDir "|" bonusPath "|" A_ScriptDir "|" A_ScriptDir "\bin|" A_ScriptDir "\lib|" bonusPath "\lib|"
   DllPath := ""
   Loop, Parse, DirList, |
   {
      If !A_LoopField
         Continue

      If FileExist(A_LoopField "\" DllName)
         DllPath := A_LoopField "\" DllName
   }

   Return DllPath
}

FreeImage_FoxPalleteIndex70White(hImage) {
   ; gif transparent color to white (indexNum 70)
   hPalette := FreeImage_GetPalette(hImage)
   FreeImage_FoxSetRGBi(hPalette, 71, "R", 255)
   FreeImage_FoxSetRGBi(hPalette, 71, "G", 255)
   FreeImage_FoxSetRGBi(hPalette, 71, "B", 255)
} ; untested

FreeImage_FoxGetTransIndexNum(hImage) {
   ; Mark Num 1 For the first Color, not 0
   hPalette := FreeImage_GetPalette(hImage)
   loop, 256 
   {
      If (FreeImage_FoxGetRGBi(hPalette, A_index, "G")>=254 && FreeImage_FoxGetRGBi(hPalette, A_index, "R")<254 && FreeImage_FoxGetRGBi(hPalette, A_index, "B")<254)
         return A_index
   }
} ; untested

FreeImage_FoxGetPallete(hImage) { ; GetPaletteList
   hPalette := FreeImage_GetPalette(hImage)
   Loop, 256
   {
      PalleteList .= FreeImage_FoxGetRGBi(hPalette, A_index, "R") . " "
         . FreeImage_FoxGetRGBi(hPalette, A_index, "G") . " "
         . FreeImage_FoxGetRGBi(hPalette, A_index, "B") . " "
         . FreeImage_FoxGetRGBi(hPalette, A_index, "i") . "`n"
   }
   return PalleteList
} ; untested

FreeImage_FoxGetRGBi(StartAdress:=2222, ColorIndexNum:=1, GetColor:="R") {
   If (GetColor="R")
      k := 0
   Else If (GetColor="G")
      k := 1
   Else If (GetColor="B")
      k := 2
   Else If (GetColor="i") ; RGB or BGR 
      k := 3

   return NumGet(StartAdress+0, 4*(ColorIndexNum-1)+k, "Uchar")
}

FreeImage_FoxSetRGBi(StartAdress:=2222, ColorIndexNum:=1, SetColor:="R", Value:=255) {
   If (SetColor="R")
      k := 0
   Else If (SetColor="G")
      k := 1
   Else If (SetColor="B")
      k := 2
   Else If (SetColor="i")
      k := 3

   return NumPut(Value, StartAdress+0, 4*(ColorIndexNum-1)+k, "Uchar")
}

GeneralW_StrToGBK(inStr) {
   VarSetCapacity(GBK, StrPut(inStr, "CP936"), 0)
   StrPut(inStr, &GBK, "CP936")
   Return GBK
}

; === General functions ===
FreeImage_Initialise(localPluginsOnly:=0) {
   Return DllCall(getFIMfunc("Initialise"), "Int", localPluginsOnly)
}

FreeImage_DeInitialise() {
   Return DllCall(getFIMfunc("DeInitialise"))
}

FreeImage_GetVersion() {
   Return DllCall(getFIMfunc("GetVersion"), "AStr")
}

FreeImage_GetLibVersion() {
   Return 2.01 ; mercredi 23 septembre 2026
}

FreeImage_GetCopyrightMessage() {
   Return DllCall(getFIMfunc("GetCopyrightMessage"), "AStr")
}

FreeImage_SetOutputMessageStdCall(pCallback) {
; pCallback := RegisterCallback("Func", "", 2): Func(fif, pMsg) gets StrGet(pMsg, "CP0"); JPEG 2000 may call it from a worker thread
   Return DllCall(getFIMfunc("SetOutputMessageStdCall"), "UPtr", pCallback)
}

FreeImage_SetOutputMessage(pCallback) {
; like FreeImage_SetOutputMessageStdCall(), for a cdecl callback: RegisterCallback("Func", "C", 2)
   Return DllCall(getFIMfunc("SetOutputMessage"), "UPtr", pCallback)
}

FreeImage_OutputMessageProc(FIF, message) {
; sends the message to the callbacks and the debugger output
   Return DllCall(getFIMfunc("OutputMessageProc"), "Int", FIF, "AStr", "%s", "AStr", message, "Cdecl")
}

FreeImage_IsLittleEndian() {
   Return DllCall(getFIMfunc("IsLittleEndian"))
}

FreeImage_LookupX11Color(colorName) {
; Returns "R,G,B", or 0 for an unknown name
   R := G := B := 0
   If DllCall(getFIMfunc("LookupX11Color"), "AStr", colorName, "UChar*", R, "UChar*", G, "UChar*", B)
      Return R "," G "," B
   Return 0
}

FreeImage_LookupSVGColor(colorName) {
; Returns "R,G,B", or 0 for an unknown name
   R := G := B := 0
   If DllCall(getFIMfunc("LookupSVGColor"), "AStr", colorName, "UChar*", R, "UChar*", G, "UChar*", B)
      Return R "," G "," B
   Return 0
}

; === Bitmap management functions ===

FreeImage_Allocate(width, height, bpp:=32, imageType:=1, red_mask:=0xFF000000, green_mask:=0x00FF0000, blue_mask:=0x0000FF00) {
; function useful to create a new / empty bitmap
; for imageType see FreeImage_GetImageType()
   Return DllCall(getFIMfunc("AllocateT"), "Int", imageType, "Int", width, "Int", height, "Int", bpp, "uint", red_mask, "uint", green_mask, "uint", blue_mask, "UPtr")
}

FreeImage_AllocateEx(width, height, bpp:=32, RGBArray:="255,255,255,0", options:=1, red_mask:=0xFF000000, green_mask:=0x00FF0000, blue_mask:=0x0000FF00, hPalette:=0) {
; function useful to create a new / empty bitmap
   pColor := 0
   If (RGBArray!="")
   {
      RGBA := StrSplit(RGBArray, ",")
      VarSetCapacity(RGBQUAD, 4, 0)
      NumPut(RGBA[3], RGBQUAD, 0, "UChar")
      NumPut(RGBA[2], RGBQUAD, 1, "UChar")
      NumPut(RGBA[1], RGBQUAD, 2, "UChar")
      NumPut(RGBA[4], RGBQUAD, 3, "UChar")
      pColor := &RGBQUAD
   }

   Return DllCall(getFIMfunc("AllocateEx"), "Int", width, "Int", height, "Int", bpp, "UPtr", pColor, "Int", options, "UPtr", hPalette, "uint", red_mask, "uint", green_mask, "uint", blue_mask, "UPtr")
}

FreeImage_AllocateExT(imageType, width, height, bpp, color:="", options:=0, red_mask:=0, green_mask:=0, blue_mask:=0, hPalette:=0) {
; color - "R,G,B,A" for a standard bitmap, else a pointer to a pixel of imageType; blank leaves it black
   pColor := FIMcolorPointer(color, colorBuf)
   Return DllCall(getFIMfunc("AllocateExT"), "Int", imageType, "Int", width, "Int", height, "Int", bpp, "UPtr", pColor, "Int", options, "UPtr", hPalette, "UInt", red_mask, "UInt", green_mask, "UInt", blue_mask, "UPtr")
}

FreeImage_AllocateHeader(headerOnly, width, height, bpp, red_mask:=0, green_mask:=0, blue_mask:=0) {
; not in FreeImage.h; headerOnly=1 allocates no pixels
   Return DllCall(getFIMfunc("AllocateHeader"), "Int", headerOnly, "Int", width, "Int", height, "Int", bpp, "UInt", red_mask, "UInt", green_mask, "UInt", blue_mask, "UPtr")
}

FreeImage_AllocateHeaderT(headerOnly, imageType, width, height, bpp:=8, red_mask:=0, green_mask:=0, blue_mask:=0) {
; not in FreeImage.h; headerOnly=1 allocates no pixels
   Return DllCall(getFIMfunc("AllocateHeaderT"), "Int", headerOnly, "Int", imageType, "Int", width, "Int", height, "Int", bpp, "UInt", red_mask, "UInt", green_mask, "UInt", blue_mask, "UPtr")
}

FreeImage_AllocateHeaderForBits(pBits, pitch, imageType, width, height, bpp, red_mask:=0, green_mask:=0, blue_mask:=0) {
; not in FreeImage.h; the bitmap uses pBits without copying them, and FreeImage_UnLoad() leaves them alone
   Return DllCall(getFIMfunc("AllocateHeaderForBits"), "UPtr", pBits, "UInt", pitch, "Int", imageType, "Int", width, "Int", height, "Int", bpp, "UInt", red_mask, "UInt", green_mask, "UInt", blue_mask, "UPtr")
}

FreeImage_Load(ImgPath, GFT:=-1, flag:=0, ByRef dGFT:=0) {
   If !ImgPath
      Return

   If (GFT=-1 || GFT="")
      dGFT := GFT := FreeImage_GetFileType(ImgPath)

   If (GFT="")
      Return

   Return DllCall(getFIMfunc("LoadU"), "Int", GFT, "WStr", ImgPath, "Int", flag, "UPtr")
}

FreeImage_LoadFromHandle(FIF, pIO, hHandle, flags:=0) {
; pIO - a FreeImageIO: pointers to the stdcall read, write, seek and tell procs, which get hHandle; FIF=-1 detects the format
   If (FIF=-1 || FIF="")
      FIF := FreeImage_GetFileTypeFromHandle(pIO, hHandle)
   Return DllCall(getFIMfunc("LoadFromHandle"), "Int", FIF, "UPtr", pIO, "UPtr", hHandle, "Int", flags, "UPtr")
}

FreeImage_Save(hImage, ImgPath, ImgArg:=0) {
; Return 0 = failed; 1 = success
; FIMfrmt := {"BMP":0, "JPG":2, "JPEG":2, "PNG":13, "TIF":18, "TIFF":18, "GIF":25}
   If (!hImage || !ImgPath)
      Return

   FormatID := FreeImage_GetFIFFromFilename(ImgPath)
   Return DllCall(getFIMfunc("SaveU"), "Int", FormatID, "UPtr", hImage, "WStr", ImgPath, "Int", ImgArg)
}

FreeImage_SaveToHandle(FIF, hImage, pIO, hHandle, flags:=0) {
; see FreeImage_LoadFromHandle()
   Return DllCall(getFIMfunc("SaveToHandle"), "Int", FIF, "UPtr", hImage, "UPtr", pIO, "UPtr", hHandle, "Int", flags)
}

FreeImage_Clone(hImage) {
   If (hImage="")
      Return 0

   Return DllCall(getFIMfunc("Clone"), "UPtr", hImage, "UPtr")
}

FreeImage_UnLoad(hImage) {
   If (hImage="")
      Return 

   Return DllCall(getFIMfunc("Unload"), "UPtr", hImage)
}

; === Bitmap information functions ===

FreeImage_GetPixelFormat(hImage, humanReadable:=0) {
   Return FreeImage_GetImageType(hImage, humanReadable)
}

FreeImage_GetImageType(hImage, humanReadable:=0) {
; Possible return values [FREE_IMAGE_TYPE enumeration]:
; 0 = FIT_UNKNOWN ;   Unknown format (returned value only, never use it as input value for other functions)
; 1 = FIT_BITMAP  ;   Standard image: 1-, 4-, 8-, 16-, 24-, 32-bit
; 2 = FIT_UINT16  ;   Array of unsigned short: unsigned 16-bit
; 3 = FIT_INT16   ;   Array of short: signed 16-bit
; 4 = FIT_UINT32  ;   Array of unsigned long: unsigned 32-bit
; 5 = FIT_INT32   ;   Array of long: signed 32-bit
; 6 = FIT_FLOAT   ;   Array of float: 32-bit IEEE floating point
; 7 = FIT_DOUBLE  ;   Array of double: 64-bit IEEE floating point
; 8 = FIT_COMPLEX ;   Array of FICOMPLEX: 2 x 64-bit IEEE floating point
; 9 = FIT_RGB16   ;   48-bit RGB image: 3 x unsigned 16-bit
; 10 = FIT_RGBA16 ;   64-bit RGBA image: 4 x unsigned 16-bit
; 11 = FIT_RGBF   ;   96-bit RGB float image: 3 x 32-bit IEEE floating point
; 12 = FIT_RGBAF  ;   128-bit RGBA float image: 4 x 32-bit IEEE floating point

   Static imgTypes := {0:"UNKNOWN", 1:"Standard Bitmap", 2:"UINT16 [16-bit]", 3:"INT16 [16-bit]", 4:"UINT32 [32-bit]", 5:"INT32 [32-bit]", 6:"FLOAT [32-bit]", 7:"DOUBLE [64-bit]", 8:"COMPLEX [2x64-bit]", 9:"RGB16 [48-bit]", 10:"RGBA16 [64-bit]", 11:"RGBF [96-bit]", 12:"RGBAF [128-bit]"}
   r := DllCall(getFIMfunc("GetImageType"), "UPtr", hImage)
   If (humanReadable=1 && imgTypes.HasKey(r))
      r := imgTypes[r]
   Return r
}

FreeImage_GetColorsUsed(hImage) {
   Return DllCall(getFIMfunc("GetColorsUsed"), "UPtr", hImage)
}

FreeImage_GetHistogram(hImage, channel, ByRef histoArray) {
   ; RGB    = 0 ; red, green and blue channels
   ; RED    = 1 ; red channel
   ; GREEN  = 2 ; green channel
   ; BLUE   = 3 ; blue channel
   ; ALPHA  = 4 ; alpha channel
   ; BLACK  = 5 ; black channel
   ; the function works only on 8, 24 and 32 bits images

   VarSetCapacity(histo, 1024, 0)
   E := DllCall(getFIMfunc("GetHistogram"), "UPtr", hImage, "UPtr", &histo, "Int", channel)
   histoArray := []
   Loop 256
   {
      i := A_Index - 1
      r := NumGet(&histo+0, i * 4, "UInt")
      histoArray[i] := r
   }

   Return E
}

FreeImage_GetBPP(hImage) {
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("GetBPP"), "UPtr", hImage)
}

FreeImage_GetWidth(hImage) {
   Return DllCall(getFIMfunc("GetWidth"), "UPtr", hImage)
}

FreeImage_GetHeight(hImage) {
   Return DllCall(getFIMfunc("GetHeight"), "UPtr", hImage)
}

FreeImage_GetImageDimensions(hImage, ByRef imgW, ByRef imgH) {
   If (hImage="")
      Return

   imgH := FreeImage_GetHeight(hImage)
   imgW := FreeImage_GetWidth(hImage)
}

FreeImage_GetLine(hImage) {
; Returns the width of the bitmap in bytes.
   Return DllCall(getFIMfunc("GetLine"), "UPtr", hImage, "uint")
} 

FreeImage_GetStride(hImage) {
; Returns the width of the bitmap in bytes, rounded to the next 32-bit boundary, also known as
; pitch or stride or scan width.
; In FreeImage each scanline starts at a 32-bit boundary for performance reasons.
; This function is essential when using low level pixel manipulation functions.
   Return FreeImage_GetPitch(hImage)
}

FreeImage_GetPitch(hImage) {
   Return DllCall(getFIMfunc("GetPitch"), "UPtr", hImage, "uint")
}

FreeImage_GetDIBSize(hImage) {
; returns a value in bytes
   Return DllCall(getFIMfunc("GetDIBSize"), "UPtr", hImage, "uint")
}

FreeImage_GetMemorySize(hImage) {
; returns a value in bytes; it is higher than DIB size
   Return DllCall(getFIMfunc("GetMemorySize"), "UPtr", hImage, "uint")
}

FreeImage_GetPalette(hImage) {
   Return DllCall(getFIMfunc("GetPalette"), "UPtr", hImage, "UPtr")
}

FreeImage_GetDPIresolution(hImage, ByRef dpiX, ByRef dpiY) {
; FreeImage stores the resolution in dots per METRE - GetDotsPerMeterX/Y is the whole of
; its resolution API - so it has to be converted, or a 72 DPI image reports 2835.
   dpiX := FreeImage_GetDotsPerMeterX(hImage) * 0.0254
   dpiY := FreeImage_GetDotsPerMeterY(hImage) * 0.0254
}

FreeImage_GetDotsPerMeterX(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterX"), "UPtr", hImage, "Int")
}

FreeImage_GetDotsPerMeterY(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterY"), "UPtr", hImage, "Int")
}

FreeImage_SetDPIresolution(hImage, dpiX, dpiY) {
  FreeImage_SetDotsPerMeterX(hImage, Round(dpiX / 0.0254))
  r := FreeImage_SetDotsPerMeterY(hImage, Round(dpiY / 0.0254))
  Return r
}

FreeImage_SetDotsPerMeterX(hImage, dpiX) {
   Return DllCall(getFIMfunc("SetDotsPerMeterX"), "UPtr", hImage, "uint", dpiX)
}

FreeImage_SetDotsPerMeterY(hImage, dpiY) {
   Return DllCall(getFIMfunc("SetDotsPerMeterY"), "UPtr", hImage, "uint", dpiY)
}

FreeImage_GetInfoHeader(hImage) {
   Return DllCall(getFIMfunc("GetInfoHeader"), "UPtr", hImage, "UPtr")
}

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "UPtr", hImage, "UPtr")
}

FreeImage_GetColorType(hImage, humanReadable:=1) {
; FREE_IMAGE_COLOR_TYPE enumeration:
; 0 = MINISWHITE  - Monochrome bitmap (1-bit) : first palette entry is white. Palletised bitmap (4 or 8-bit) - the bitmap has an inverted greyscale palette
; 1 = MINISBLACK  - Monochrome bitmap (1-bit) : first palette entry is black. Palletised bitmap (4 or 8-bit) and single channel non-standard bitmap: the bitmap has a greyscale palette
; 2 = RGB         - High-color bitmap (16, 24 or 32 bit), RGB16 or RGBF
; 3 = PALETTE     - Palettized bitmap (1, 4 or 8 bit)
; 4 = RGBALPHA    - High-color bitmap with an alpha channel (32 bit bitmap, RGBA16 or RGBAF)
; 5 = CMYK        - CMYK bitmap (32 bit only)

   r := DllCall(getFIMfunc("GetColorType"), "UPtr", hImage)
   If (humanReadable=1)
   {
      k := FIMcolorTypeNames("name", r)
      If (k!="")
         r := k
   }

   Return r
}

FIMcolorTypeNames(modus, indexu:=0) {
   Static ColorsTypes := {1:"MINISBLACK", 0:"MINISWHITE", 3:"PALETTIZED", 2:"RGB", 4:"RGBA", 5:"CMYK"}
   If (modus="name")
      Return ColorsTypes[indexu]

   packedu := ColorsTypes[0]
   Loop, % ColorsTypes.Count() - 1
       packedu .= "|" ColorsTypes[A_Index]

   Return packedu
}

FIMcolorPointer(color, ByRef buf) {
; "R,G,B[,A]" becomes an RGBQUAD in buf; any other value is taken as a pointer, blank as NULL
   If (color="")
      Return 0
   If !InStr(color, ",")
      Return color

   RGBA := StrSplit(color, ",")
   VarSetCapacity(buf, 4, 0)
   NumPut(RGBA[3], buf, 0, "UChar")
   NumPut(RGBA[2], buf, 1, "UChar")
   NumPut(RGBA[1], buf, 2, "UChar")
   NumPut(RGBA[4], buf, 3, "UChar")
   Return &buf
}

FIMcolorArray(colors, ByRef buf) {
; an array of "R,G,B[,A]" becomes RGBQUADs in buf; any other value is taken as a pointer
   If !IsObject(colors)
      Return colors ? colors : 0

   VarSetCapacity(buf, 4 * colors.Length() + 4, 0)
   For i, color in colors
   {
      RGBA := StrSplit(color, ",")
      NumPut(RGBA[3], buf, 4 * (i - 1), "UChar")
      NumPut(RGBA[2], buf, 4 * (i - 1) + 1, "UChar")
      NumPut(RGBA[1], buf, 4 * (i - 1) + 2, "UChar")
      NumPut(RGBA[4], buf, 4 * (i - 1) + 3, "UChar")
   }
   Return &buf
}

FIMpersistentAStr(str) {
; an ANSI copy that is never freed, for strings FreeImage keeps a pointer to; blank gives NULL
   If (str="")
      Return 0

   p := DllCall("GlobalAlloc", "UInt", 0, "UPtr", StrPut(str, "CP0"), "UPtr")
   If p
      StrPut(str, p, "CP0")
   Return p
}

FIMbyteArray(values, ByRef buf) {
; an array of numbers becomes bytes in buf; any other value is taken as a pointer
   If !IsObject(values)
      Return values ? values : 0

   VarSetCapacity(buf, values.Length() + 1, 0)
   For i, value in values
      NumPut(value, buf, i - 1, "UChar")
   Return &buf
}

FreeImage_GetRedMask(hImage) {
   Return DllCall(getFIMfunc("GetRedMask"), "UPtr", hImage, "uint")
}

FreeImage_GetGreenMask(hImage) {
   Return DllCall(getFIMfunc("GetGreenMask"), "UPtr", hImage, "uint")
}

FreeImage_GetBlueMask(hImage) {
   Return DllCall(getFIMfunc("GetBlueMask"), "UPtr", hImage, "uint")
}

FreeImage_HasRGBMasks(hImage) {
; not in FreeImage.h
   Return DllCall(getFIMfunc("HasRGBMasks"), "UPtr", hImage)
}

FreeImage_GetTransparencyCount(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyCount"), "UPtr", hImage)
}

FreeImage_GetTransparencyTable(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyTable"), "UPtr", hImage, "UPtr")
}

FreeImage_SetTransparencyTable(hImage, hTransTable, count:=256) {
; hTransTable - pointer to [count] alpha bytes
   Return DllCall(getFIMfunc("SetTransparencyTable"), "UPtr", hImage, "UPtr", hTransTable, "Int", count)
}

FreeImage_SetTransparent(hImage, isEnabled) {
   Return DllCall(getFIMfunc("SetTransparent"), "UPtr", hImage, "Int", isEnabled)
}

FreeImage_GetTransparentIndex(hImage) {
   Return DllCall(getFIMfunc("GetTransparentIndex"), "UPtr", hImage)
}

FreeImage_SetTransparentIndex(hImage, index) {
   Return DllCall(getFIMfunc("SetTransparentIndex"), "UPtr", hImage, "Int", index)
}

FreeImage_IsTransparent(hImage) {
   Return DllCall(getFIMfunc("IsTransparent"), "UPtr", hImage)
}

FreeImage_HasPixels(hImage) {
   Return DllCall(getFIMfunc("HasPixels"), "UPtr", hImage)
}

FreeImage_GetThumbnail(hImage) {
; Returns the embedded thumbnail, or 0; hImage owns it, do not unload it
   Return DllCall(getFIMfunc("GetThumbnail"), "UPtr", hImage, "UPtr")
}

FreeImage_SetThumbnail(hImage, hThumbnail) {
; Attaches a copy of hThumbnail; 0 removes the thumbnail
   Return DllCall(getFIMfunc("SetThumbnail"), "UPtr", hImage, "UPtr", hThumbnail)
}

FreeImage_HasBackgroundColor(hImage) {
   Return DllCall(getFIMfunc("HasBackgroundColor"), "UPtr", hImage)
}

FreeImage_GetBackgroundColor(hImage) {
   VarSetCapacity(RGBQUAD, 4, 0)
   RetValue := DllCall(getFIMfunc("GetBackgroundColor"), "UPtr", hImage, "UPtr", &RGBQUAD)
   If RetValue
      return NumGet(RGBQUAD, 2, "Uchar") "," NumGet(RGBQUAD, 1, "Uchar") "," NumGet(RGBQUAD, 0, "Uchar") "," NumGet(RGBQUAD, 3, "Uchar")
   else
      return RetValue
}

FreeImage_SetBackgroundColor(hImage, RGBArray:="255,255,255,0") {
; a blank RGBArray removes the background color
   pColor := 0
   If (RGBArray!="")
   {
      RGBA := StrSplit(RGBArray, ",")
      VarSetCapacity(RGBQUAD, 4, 0)
      NumPut(RGBA[3], RGBQUAD, 0, "UChar")
      NumPut(RGBA[2], RGBQUAD, 1, "UChar")
      NumPut(RGBA[1], RGBQUAD, 2, "UChar")
      NumPut(RGBA[4], RGBQUAD, 3, "UChar")
      pColor := &RGBQUAD
   }
   Return DllCall(getFIMfunc("SetBackgroundColor"), "UPtr", hImage, "UPtr", pColor)
}

FreeImage_FillBackground(hImage, RGBArray:="255,255,255,0", options:=1) {
; options     - it affect the color search process for palletized images.
;   FI_COLOR_IS_RGB_COLOR     = 0   // RGBQUAD color is a RGB color (contains no valid alpha channel)
;   FI_COLOR_IS_RGBA_COLOR    = 1   // RGBQUAD color is a RGBA color (contains a valid alpha channel)
;   FI_COLOR_FIND_EQUAL_COLOR = 2   // For palettized images: lookup equal RGB color from palette
;   FI_COLOR_ALPHA_IS_INDEX   = 4   // The color's rgbReserved member (alpha) contains the palette index to be used
;   FI_COLOR_SET_ALPHA        = 8   // No blending: a 32-bit image gets the color's alpha

   pColor := 0
   If (RGBArray!="")
   {
      RGBA := StrSplit(RGBArray, ",")
      VarSetCapacity(RGBQUAD, 4, 0)
      NumPut(RGBA[3], RGBQUAD, 0, "UChar")
      NumPut(RGBA[2], RGBQUAD, 1, "UChar")
      NumPut(RGBA[1], RGBQUAD, 2, "UChar")
      NumPut(RGBA[4], RGBQUAD, 3, "UChar")
      pColor := &RGBQUAD
   }
   Return DllCall(getFIMfunc("FillBackground"), "UPtr", hImage, "UPtr", pColor, "Int", options)
}

; === File type functions ===

FreeImage_GetFileType(ImgPath, humanReadable:=0) {
; the given ImgPath can be fictional / inexistent.
; returns FREE_IMAGE_FORMAT enumeration if humanReadable=0.

   Static fileTypes := {-1:"unknown", 0:"BMP", 1:"ICO", 2:"JPEG", 3:"JNG", 4:"KOALA", 5:"LBM", 5:"IFF", 6:"MNG", 7:"PBM", 8:"PBMRAW", 9:"PCD", 10:"PCX", 11:"PGM", 12:"PGMRAW", 13:"PNG", 14:"PPM", 15:"PPMRAW", 16:"RAS", 17:"TARGA", 18:"TIFF", 19:"WBMP", 20:"PSD", 21:"CUT", 22:"XBM", 23:"XPM", 24:"DDS", 25:"GIF", 26:"HDR", 27:"FAXG3", 28:"SGI", 29:"EXR", 30:"J2K", 31:"JP2", 32:"PFM", 33:"PICT", 34:"RAW", 35:"WEBP", 36:"JXR", 37:"AVIF", 38:"HEIF", 39:"APNG"}
   r := DllCall(getFIMfunc("GetFileTypeU"), "WStr", ImgPath, "Int", 0)
   If (r=-1)
      r := FreeImage_GetFIFFromFilename(ImgPath)
   If (humanReadable=1 && fileTypes.HasKey(r))
      r := fileTypes[r]

   Return r
}

FreeImage_FIFSupportsExportBPP(FIF, bpp) {
; FIF is the FREE_IMAGE_FORMAT enumeration
; see FreeImage_GetFileType()
   Return DllCall(getFIMfunc("FIFSupportsExportBPP"), "Int", FIF, "Int", bpp)
}

FreeImage_FIFSupportsExportType(FIF, pixelsDataType) {
; FIF is the FREE_IMAGE_FORMAT enumeration
; see FreeImage_GetFileType()
; pixelsDataType is FREE_IMAGE_TYPE enumeration
; see FreeImage_GetImageType()
   Return DllCall(getFIMfunc("FIFSupportsExportType"), "Int", FIF, "Int", pixelsDataType)
}

FreeImage_FIFSupportsICCProfiles(FIF) {
   Return DllCall(getFIMfunc("FIFSupportsICCProfiles"), "Int", FIF)
}

FreeImage_FIFSupportsNoPixels(FIF) {
   Return DllCall(getFIMfunc("FIFSupportsNoPixels"), "Int", FIF)
}

FreeImage_FIFSupportsReading(FIF) {
   Return DllCall(getFIMfunc("FIFSupportsReading"), "Int", FIF)
}

FreeImage_FIFSupportsWriting(FIF) {
   Return DllCall(getFIMfunc("FIFSupportsWriting"), "Int", FIF)
}

FreeImage_GetFIFFromFilename(ImgPath) {
   Return DllCall(getFIMfunc("GetFIFFromFilenameU"), "WStr", ImgPath)
}

FreeImage_Validate(ImgPath, FifFormat) {
   Return DllCall(getFIMfunc("ValidateU"), "Int", FifFormat, "WStr", ImgPath)
}

FreeImage_GetFileTypeFromHandle(pIO, hHandle, size:=0) {
; see FreeImage_LoadFromHandle(); the position is kept
   Return DllCall(getFIMfunc("GetFileTypeFromHandle"), "UPtr", pIO, "UPtr", hHandle, "Int", size)
}

FreeImage_GetFileTypeFromMemory(hMemory, size:=0) {
; the stream position is kept
   Return DllCall(getFIMfunc("GetFileTypeFromMemory"), "UPtr", hMemory, "Int", size)
}

FreeImage_ValidateFromHandle(FIF, pIO, hHandle) {
   Return DllCall(getFIMfunc("ValidateFromHandle"), "Int", FIF, "UPtr", pIO, "UPtr", hHandle)
}

FreeImage_ValidateFromMemory(FIF, hMemory) {
   Return DllCall(getFIMfunc("ValidateFromMemory"), "Int", FIF, "UPtr", hMemory)
}

; === Pixel access functions ===

FreeImage_GetBits(hImage) {
; Returns a pointer to the data-bits of the bitmap. It is up to you to interpret these bytes
; correctly, according to the results of FreeImage_GetBPP, FreeImage_GetRedMask,
; FreeImage_GetGreenMask and FreeImage_GetBlueMask.
; For performance reasons, the address returned by FreeImage_GetBits is aligned on
; a 16 bytes alignment boundary
; This function returns a pointer to the equivalent of Scan0
; when one locks the bits of a bitmap in GDI+.

   Return DllCall(getFIMfunc("GetBits"), "UPtr", hImage, "UPtr")
}

FreeImage_GetScanLine(hImage, iScanline) { ; Base 0
; Returns a pointer to the start of the given scanline in the bitmap’s data-bits.
; It is up to you to interpret these bytes correctly, according to the results of
; FreeImage_GetBPP and FreeImage_GetImageType (see the following sample).
   Return DllCall(getFIMfunc("GetScanLine"), "UPtr", hImage, "Int", iScanline, "UPtr")
}

FreeImage_GetPixelIndex(hImage, xPos, yPos) {
; It works only with 1, 4 and 8 bit images.
   VarSetCapacity(IndexNum, 1, 0)
   RetValue := DllCall(getFIMfunc("GetPixelIndex"), "UPtr", hImage, "Uint", xPos, "Uint", yPos, "UPtr", &IndexNum)
   If RetValue
      return NumGet(IndexNum, 0, "Uchar")
   else
      return RetValue
}

FreeImage_SetPixelIndex(hImage, xPos, yPos, nIndex) {
; It works only with 1, 4 and 8 bit images.
   VarSetCapacity(IndexNum, 1, 0)
   NumPut(nIndex, IndexNum, 0, "Uchar")
   Return DllCall(getFIMfunc("SetPixelIndex"), "UPtr", hImage, "Uint", xPos, "Uint", yPos, "UPtr", &IndexNum)
}

FreeImage_GetPixelColor(hImage, xPos, yPos, format:=0) {
; It works only with 16, 24 and 32 bit images.
   VarSetCapacity(RGBQUAD, 4, 0)
   RetValue := DllCall(getFIMfunc("GetPixelColor") , "UPtr", hImage, "Uint", xPos, "Uint", yPos, "UPtr", &RGBQUAD)
   If RetValue
   {
      R := NumGet(RGBQUAD, 2, "Uchar")
      G := NumGet(RGBQUAD, 1, "Uchar")
      B := NumGet(RGBQUAD, 0, "Uchar") 
      A := NumGet(RGBQUAD, 3, "Uchar")
      If format
         ARGBdec := (A << 24) | (R << 16) | (G << 8) | B
      If (format=1)  ; in ARGB [HEX; 00-FF] with 0x prefix
      {
         Return Format("{1:#x}", ARGBdec)
      } Else If (format=2)  ; in RGBA [0-255], returns an object
      {
         Return [R, G, B, A]
      } Else If (format=3)  ; in BGR [HEX; 00-FF] with 0x prefix
      {
         clr := Format("{1:#x}", ARGBdec)
         Return "0x" SubStr(clr, -1) SubStr(clr, 7, 2) SubStr(clr, 5, 2)
      } Else If (format=4)  ; in RGB [HEX; 00-FF] with no prefix
      {
         Return SubStr(Format("{1:#x}", ARGBdec), 5)
      } Else If (format=5)
      {
         Return ARGBdec
      } Else Return R "," G "," B "," A 
   } Else
      Return RetValue
}

FreeImage_SetPixelColor(hImage, xPos, yPos, RGBArray:="255,255,255,0") {
; It works only with 16, 24 and 32 bit images.
   RGBA := StrSplit(RGBArray, ",")
   VarSetCapacity(RGBQUAD, 4, 0)
   NumPut(RGBA[3], RGBQUAD, 0, "UChar")
   NumPut(RGBA[2], RGBQUAD, 1, "UChar")
   NumPut(RGBA[1], RGBQUAD, 2, "UChar")
   NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("SetPixelColor"), "UPtr", hImage, "Uint", xPos, "Uint", yPos, "UPtr", &RGBQUAD)
}

; === Conversion functions ===

FreeImage_ConvertTo(hImage, MODE) {
; This is a wrapper for multiple FreeImage functions.
; ATTENTION: the values for MODE are case sensitive!
; Possible values for the MODE parameter and the accepted input color types for the bitmap:
   ; "4Bits"         | 1-,4-,8-,16-,24-,32- bits
   ; "8Bits"         | 1-,4-,8-,16-,24-,32- bits, UINT16 array
   ; "16Bits"        | 1-,4-,8-,16-,24-,32- bits
   ; "16Bits555"     | 1-,4-,8-,16-,24-,32- bits
   ; "16Bits565"     | 1-,4-,8-,16-,24-,32- bits
   ; "24Bits"        | 1-,4-,8-,16-,24-,32- bits, 48-bits [RGB16], 64-bits [RGBA16]
   ; "32Bits"        | 1-,4-,8-,16-,24-,32- bits, 48-bits [RGB16], 64-bits [RGBA16]
   ; "Greyscale"     | 1-,4-,8-,16-,24-,32- bits, UINT16 array
   ; "Float"         | 1-,4-,8-,16-,24-,32- bits, UINT16 or Float array, 48-bits [RGB16], 64-bits [RGBA16], 96-bits [RGBF], 128-bits [RGBAF]
   ; "RGBF"          | 1-,4-,8-,16-,24-,32- bits, UINT16 or Float array, 48-bits [RGB16], 64-bits [RGBA16], 96-bits [RGBF], 128-bits [RGBAF]
   ; "RGBAF"         | 1-,4-,8-,16-,24-,32- bits, UINT16 or Float array, 48-bits [RGB16], 64-bits [RGBA16], 96-bits [RGBF], 128-bits [RGBAF]
   ; "UINT16"        | 1-,4-,8-,16-,24-,32- bits, UINT16 array, 48-bits [RGB16], 64-bits [RGBA16]
   ; "RGB16"         | 1-,4-,8-,16-,24-,32- bits, UINT16 array, 48-bits [RGB16], 64-bits [RGBA16]
   ; "RGBA16"        | 1-,4-,8-,16-,24-,32- bits, UINT16 array, 48-bits [RGB16], 64-bits [RGBA16]

   If !hImage
      Return

   If (mode="16bits")
      mode := "16Bits555"

   Return DllCall(getFIMfunc("ConvertTo" MODE), "UPtr", hImage, "UPtr")
}

FreeImage_ConvertTo32Bits(hImage) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("ConvertTo32Bits"), "UPtr", hImage, "UPtr")
}

FreeImage_ConvertTo24Bits(hImage) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("ConvertTo24Bits"), "UPtr", hImage, "UPtr")
}

FreeImage_ConvertTo4Bits(hImage) {
   Return FreeImage_ConvertTo(hImage, "4Bits")
}

FreeImage_ConvertTo8Bits(hImage) {
   Return FreeImage_ConvertTo(hImage, "8Bits")
}

FreeImage_ConvertTo16Bits555(hImage) {
   Return FreeImage_ConvertTo(hImage, "16Bits555")
}

FreeImage_ConvertTo16Bits565(hImage) {
   Return FreeImage_ConvertTo(hImage, "16Bits565")
}

FreeImage_ConvertToFloat(hImage) {
   Return FreeImage_ConvertTo(hImage, "Float")
}

FreeImage_ConvertToRGBF(hImage) {
   Return FreeImage_ConvertTo(hImage, "RGBF")
}

FreeImage_ConvertToRGBAF(hImage) {
   Return FreeImage_ConvertTo(hImage, "RGBAF")
}

FreeImage_ConvertToUINT16(hImage) {
   Return FreeImage_ConvertTo(hImage, "UINT16")
}

FreeImage_ConvertToRGB16(hImage) {
   Return FreeImage_ConvertTo(hImage, "RGB16")
}

FreeImage_ConvertToRGBA16(hImage) {
   Return FreeImage_ConvertTo(hImage, "RGBA16")
}

FreeImage_ConvertLine(conversion, pTarget, pSource, widthInPixels, pPalette:=0, pTable:=0, transparentPixels:=0) {
; conversion - the ConvertLine* suffix, e.g. "8To32" or "16_555_To16_565"; palettized sources to 16/24/32 bits and "8To4" use pPalette, *MapTransparency pTable too
   If InStr(conversion, "MapTransparency")
      Return DllCall(getFIMfunc("ConvertLine" conversion), "UPtr", pTarget, "UPtr", pSource, "Int", widthInPixels, "UPtr", pPalette, "UPtr", pTable, "Int", transparentPixels)
   If RegExMatch(conversion, "^([148]To(16_555|16_565|24|32)|8To4)$")
      Return DllCall(getFIMfunc("ConvertLine" conversion), "UPtr", pTarget, "UPtr", pSource, "Int", widthInPixels, "UPtr", pPalette)
   Return DllCall(getFIMfunc("ConvertLine" conversion), "UPtr", pTarget, "UPtr", pSource, "Int", widthInPixels)
}

FreeImage_ConvertToRawBits(pBits, hImage, scan_width, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   ; thanks to TheArkive for the help
   r := DllCall(getFIMfunc("ConvertToRawBits"), "UPtr", pBits, "UPtr", hImage, "Int", scan_width, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "Int", topDown)
   Return r
}

FreeImage_ConvertFromRawBits(pBits, imgW, imgH, PitchStride, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   r := DllCall(getFIMfunc("ConvertFromRawBits"), "UPtr", pBits, "Int", imgW, "Int", imgH, "uInt", PitchStride, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "Int", topDown, "UPtr")
   Return r
}

FreeImage_ConvertFromRawBitsEx(copySource, pBits, FimType, imgW, imgH, PitchStride, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   r := DllCall(getFIMfunc("ConvertFromRawBitsEx"), "Int", copySource, "UPtr", pBits, "Int", FimType, "Int", imgW, "Int", imgH, "uInt", PitchStride, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "Int", topDown, "UPtr")
   Return r
}

FreeImage_ConvertToStandardType(hImage, bScaleLinear:=1) {
   Return DllCall(getFIMfunc("ConvertToStandardType"), "UPtr", hImage, "Int", bScaleLinear, "UPtr")
}

FreeImage_ConvertToType(hImage, imgType, bScaleLinear:=1) {
; imgType is the FREE_IMAGE_TYPE enumeration, see FreeImage_GetImageType().
; There is no conversion from floating point RGB [11, 12] to FIT_BITMAP [1]; tone map those.
   Return DllCall(getFIMfunc("ConvertToType"), "UPtr", hImage, "Int", imgType, "Int", bScaleLinear, "UPtr")
}

FreeImage_ConvertToGreyscale(hImage) {
   ; hImage - input must be a standard type, from 1-bit to 32 bits image, or an UINT16
   Return DllCall(getFIMfunc("ConvertToGreyscale"), "UPtr", hImage, "UPtr")
}

FreeImage_ColorQuantize(hImage, quantizeAlgo:=0) {
   ; hImage - input must be a 24 or a 32 bits image
   ; quantizeAlgo:
      ; 0 = FIQ_WUQUANT  - Xiaolin Wu color quantization algorithm
      ; 1 = FIQ_NNQUANT  - NeuQuant neural-net quantization algorithm by Anthony Dekker (24-bit only)
      ; 2 = FIQ_LFPQUANT - Lossless Fast Pseudo-Quantization Algorithm by Carsten Klein
   ; the function returns an 8 bit image
   Return DllCall(getFIMfunc("ColorQuantize"), "UPtr", hImage, "Int", quantizeAlgo, "UPtr")
}

FreeImage_ColorQuantizeEx(hImage, quantizeAlgo:=0, paletteSize:=256, reserveSize:=0, reservePalette:=0) {
; reservePalette - an array of "R,G,B" colors the palette must keep, or a pointer to [reserveSize] RGBQUADs
   pReserve := FIMcolorArray(reservePalette, reserveBuf)
   If (IsObject(reservePalette) && !reserveSize)
      reserveSize := reservePalette.Length()
   Return DllCall(getFIMfunc("ColorQuantizeEx"), "UPtr", hImage, "Int", quantizeAlgo, "Int", paletteSize, "Int", reserveSize, "UPtr", pReserve, "UPtr")
}

FreeImage_Threshold(hImage, TT:=0) { ; TT: 0 - 255
   Return DllCall(getFIMfunc("Threshold"), "UPtr", hImage, "Int", TT, "UPtr")
}

FreeImage_Dither(hImage, ditherAlgo:=0) {
   ; ditherAlgo parameter: dithering method
   ; FID_FS           = 0   // Floyd & Steinberg error diffusion
   ; FID_BAYER4x4     = 1   // Bayer ordered dispersed dot dithering (order 2 dithering matrix)
   ; FID_BAYER8x8     = 2   // Bayer ordered dispersed dot dithering (order 3 dithering matrix)
   ; FID_CLUSTER6x6   = 3   // Ordered clustered dot dithering (order 3 - 6x6 matrix)
   ; FID_CLUSTER8x8   = 4   // Ordered clustered dot dithering (order 4 - 8x8 matrix)
   ; FID_CLUSTER16x16 = 5   // Ordered clustered dot dithering (order 8 - 16x16 matrix)
   ; FID_BAYER16x16   = 6   // Bayer ordered dispersed dot dithering (order 4 dithering matrix)
   ; it returns an 1-bit image

   Return DllCall(getFIMfunc("Dither"), "UPtr", hImage, "Int", ditherAlgo, "UPtr")
}

FreeImage_ToneMapping(hImage, algo:=0, p1:=0, p2:=0) {
   ; Converts a High Dynamic Range image (48-bit RGB or 96-bit RGBF) to a 24-bit RGB image, suitable for display.
   ; function required to properly display HDR and RAW images

   ; algo parameter and p1/p2 intervals and meaning 
   ; 0 = FITMO_DRAGO03    ; Adaptive logarithmic mapping (F. Drago, 2003)
         ; p1 = gamma [0.0, 9.9]; p2 = exposure [-8, 8]
   ; 1 = FITMO_REINHARD05 ; Dynamic range reduction inspired by photoreceptor physiology (E. Reinhard, 2005)
         ; p1 = intensity [-8, 8]; p2 = contrast [0.3, 1.0]
   ; 2 = FITMO_FATTAL02   ; Gradient domain High Dynamic Range compression (R. Fattal, 2002)
         ; p1 = saturation [0.4, 0.6]; p2 = attenuation [0.8, 0.9]

   Return DllCall(getFIMfunc("ToneMapping"), "UPtr", hImage, "Int", algo, "Double", p1, "Double", p2, "UPtr")
}

FreeImage_TmoDrago(hImage, gamma, exposure) {
   ; Converts a High Dynamic Range image to a 24-bit RGB image, suitable for display.
   ; function required to properly display HDR and RAW images

   ; parameters intervals and meaning 
   ; Adaptive logarithmic mapping (F. Drago, 2003)
         ; gamma = from 0.0 to 9.9
         ; exposure = from -8 to 8

   Return DllCall(getFIMfunc("TmoDrago03"), "UPtr", hImage, "Double", gamma, "Double", exposure, "UPtr")
}

FreeImage_TmoReinhard05(hImage, intensity:=0, contrast:=0) {
; intensity [-8, 8]; contrast [0.3, 1), 0 picks it from the image
   Return DllCall(getFIMfunc("TmoReinhard05"), "UPtr", hImage, "Double", intensity, "Double", contrast, "UPtr")
}

FreeImage_TmoReinhard05Ex(hImage, intensity:=0, contrast:=0, adaptation:=1, colorCorrection:=0) {
; adaptation and colorCorrection [0, 1]; see FreeImage_TmoReinhard05()
   Return DllCall(getFIMfunc("TmoReinhard05Ex"), "UPtr", hImage, "Double", intensity, "Double", contrast, "Double", adaptation, "Double", colorCorrection, "UPtr")
}

FreeImage_TmoFattal02(hImage, colorSaturation:=0.5, attenuation:=0.85) {
; colorSaturation [0.4, 0.6], attenuation [0.8, 0.9]
   Return DllCall(getFIMfunc("TmoFattal02"), "UPtr", hImage, "Double", colorSaturation, "Double", attenuation, "UPtr")
}

; === ICC profile functions ===

FreeImage_GetICCProfile(hImage) {
; FIICCPROFILE: flags UShort at 0, size UInt at 4, data pointer at 8
   Return DllCall(getFIMfunc("GetICCProfile"), "UPtr", hImage, "UPtr") ; returns a pointer to it
}

FreeImage_CreateICCProfile(hImage, pData, size) {
; copies [size] bytes at pData into the image; returns its FIICCPROFILE
   Return DllCall(getFIMfunc("CreateICCProfile"), "UPtr", hImage, "UPtr", pData, "Int", size, "UPtr")
}

FreeImage_DestroyICCProfile(hImage) {
   Return DllCall(getFIMfunc("DestroyICCProfile"), "UPtr", hImage)
}

; === Plugin functions ===

FreeImage_GetFIFCount() {
   Return DllCall(getFIMfunc("GetFIFCount"))
}

FreeImage_SetPluginEnabled(FIF, enable) {
; Returns the previous state, or -1 if there is no such plugin
   Return DllCall(getFIMfunc("SetPluginEnabled"), "Int", FIF, "Int", enable)
}

FreeImage_IsPluginEnabled(FIF) {
   Return DllCall(getFIMfunc("IsPluginEnabled"), "Int", FIF)
}

FreeImage_GetFIFFromFormat(format) {
; format - a plugin's short name, e.g. "PNG"
   Return DllCall(getFIMfunc("GetFIFFromFormat"), "AStr", format)
}

FreeImage_GetFIFFromMime(mime) {
   Return DllCall(getFIMfunc("GetFIFFromMime"), "AStr", mime)
}

FreeImage_GetFormatFromFIF(FIF) {
   Return DllCall(getFIMfunc("GetFormatFromFIF"), "Int", FIF, "AStr")
}

FreeImage_GetFIFExtensionList(FIF) {
; Returns the extensions separated by commas, e.g. "jpg,jif,jpeg,jpe"
   Return DllCall(getFIMfunc("GetFIFExtensionList"), "Int", FIF, "AStr")
}

FreeImage_GetFIFDescription(FIF) {
   Return DllCall(getFIMfunc("GetFIFDescription"), "Int", FIF, "AStr")
}

FreeImage_GetFIFRegExpr(FIF) {
   Return DllCall(getFIMfunc("GetFIFRegExpr"), "Int", FIF, "AStr")
}

FreeImage_GetFIFMimeType(FIF) {
   Return DllCall(getFIMfunc("GetFIFMimeType"), "Int", FIF, "AStr")
}

FreeImage_RegisterLocalPlugin(pInitProc, format:="", description:="", extension:="", regexpr:="") {
; pInitProc - a stdcall Init(Plugin*, format_id) that fills the Plugin procs; returns the new FIF, or -1
   Return DllCall(getFIMfunc("RegisterLocalPlugin"), "UPtr", pInitProc, "UPtr", FIMpersistentAStr(format), "UPtr", FIMpersistentAStr(description), "UPtr", FIMpersistentAStr(extension), "UPtr", FIMpersistentAStr(regexpr))
}

FreeImage_RegisterExternalPlugin(path, format:="", description:="", extension:="", regexpr:="") {
; path is an ANSI string; the DLL must export "_Init@8"; returns the new FIF, or -1
   Return DllCall(getFIMfunc("RegisterExternalPlugin"), "AStr", path, "UPtr", FIMpersistentAStr(format), "UPtr", FIMpersistentAStr(description), "UPtr", FIMpersistentAStr(extension), "UPtr", FIMpersistentAStr(regexpr))
}

; === Multipage bitmap functions ===

FreeImage_OpenMultiBitmap(ImgPath, imgFormat, create_new:=0, read_only:=1, keep_cache:=1, flags:=0) {
; ImgPath    - file to open or create
; create_new - when this is 1, the file will be created; please make sure 
;              the folder path already exists and there is no already
;              existing file with the given name; FIM may crash if
;              it already exists; use read_only=0 as param
; keep_cache - keep in memory the cache
;
; On file open, pass one of these flags to retrieve the composited frames:
;     WEBP_PLAYBACK = 1
;     GIF/APNG/MNG/HEIF/AVIF_PLAYBACK = 2
; Alternatively, to retrieve only the animation properties: 
;     FIF_LOAD_NOPIXELS = 0x8000
;
; To save a newly created multi-page image, use FreeImage_CloseMultiBitmap().
/*
imgFormat parameter takes integer values from 0 to 39 relevant I/O image format identifiers.
   FIF_ICO      = 1,
   FIF_MNG      = 6,  (read, write, anim)
   FIF_TIFF     = 18, (read, write)
   FIF_GIF      = 25, (read, write, anim)
   FIF_WEBP     = 35, (read, write, anim)
   FIF_AVIF     = 37, (read-only)
   FIF_HEIF     = 38, (read-only)
   FIF_APNG     = 39, (read, write, anim)
*/

   Return DllCall(getFIMfunc("OpenMultiBitmapU"), "Int", imgFormat, "WStr", ImgPath, "Int", create_new, "Int", read_only, "Int", keep_cache, "Int", flags, "UPtr")
}

FreeImage_OpenMultiBitmapFromHandle(FIF, pIO, hHandle, flags:=0) {
; see FreeImage_LoadFromHandle(); hHandle must stay valid until FreeImage_CloseMultiBitmap(), which discards edits: save them with FreeImage_SaveMultiBitmapToHandle()
   Return DllCall(getFIMfunc("OpenMultiBitmapFromHandle"), "Int", FIF, "UPtr", pIO, "UPtr", hHandle, "Int", flags, "UPtr")
}

FreeImage_CloseMultiBitmap(hFIMULTIBITMAP, flags:=0) {
; If the multi-page image was opened with read_only=0, any modifications
; to the image will be saved to disk; do not use FreeImage_Save() to save a multi-page image.
   If (hFIMULTIBITMAP="")
      Return

   Return DllCall(getFIMfunc("CloseMultiBitmap"), "UPtr", hFIMULTIBITMAP, "Int", flags)
}

FreeImage_SaveMultiBitmapToHandle(FIF, hFIMULTIBITMAP, pIO, hHandle, flags:=0) {
; see FreeImage_LoadFromHandle()
   Return DllCall(getFIMfunc("SaveMultiBitmapToHandle"), "Int", FIF, "UPtr", hFIMULTIBITMAP, "UPtr", pIO, "UPtr", hHandle, "Int", flags)
}

FreeImage_GetPageCount(hFIMULTIBITMAP) {
   Return DllCall(getFIMfunc("GetPageCount"), "UPtr", hFIMULTIBITMAP)
}

FreeImage_AppendPage(hFIMULTIBITMAP, hImage) {
   DllCall(getFIMfunc("AppendPage"), "UPtr", hFIMULTIBITMAP, "UPtr", hImage)
}

FreeImage_AppendPageEx(hFIMULTIBITMAP, hImage) {
   ; Returns TRUE when the page was added. It is refused when the format cannot encode the
   ; bitmap, and FreeImage_CloseMultiBitmap() then returns FALSE, although it saves the other pages.
   Return DllCall(getFIMfunc("AppendPageEx"), "UPtr", hFIMULTIBITMAP, "UPtr", hImage, "Int")
}

FreeImage_InsertPage(hFIMULTIBITMAP, PageNumber, hImage) {
   DllCall(getFIMfunc("InsertPage"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber, "UPtr", hImage)
}

FreeImage_InsertPageEx(hFIMULTIBITMAP, PageNumber, hImage) {
   ; Returns TRUE when the page was inserted.
   Return DllCall(getFIMfunc("InsertPageEx"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber, "UPtr", hImage, "Int")
}

FreeImage_DeletePage(hFIMULTIBITMAP, PageNumber) {
   DllCall(getFIMfunc("DeletePage"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber)
}

FreeImage_DeletePageEx(hFIMULTIBITMAP, PageNumber) {
   ; Returns TRUE when the page was deleted.
   Return DllCall(getFIMfunc("DeletePageEx"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber, "Int")
}

FreeImage_MovePage(hFIMULTIBITMAP, Target, PageNumber) {
   ; Moves the source page to the position of the target page. Returns TRUE on success, FALSE on failure.
   Return DllCall(getFIMfunc("MovePage"), "UPtr", hFIMULTIBITMAP, "Int", Target, "Int", PageNumber)
}

FreeImage_LockPage(hFIMULTIBITMAP, PageNumber) {
   ; Locks a page in memory for editing. The page can now be saved to a different file or inserted
   ; into another multi-page bitmap. When you are done with the bitmap you have to call
   ; FreeImage_UnlockPage to give the page back to the bitmap and/or apply any changes made
   ; in the page. It is forbidden to use FreeImage_Unload on a locked page: you must use
   ; FreeImage_UnlockPage() instead

   ; On succes, the function returns a common FIBITMAP.
   Return DllCall(getFIMfunc("LockPage"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber, "UPtr")
}

FreeImage_UnlockPage(hFIMULTIBITMAP, hImage, changed) {
   ; Unlocks a previously locked page and gives it back to the multi-page engine. When the last
   ; parameter is 1, the page is marked changed and the new page data is applied in the
   ; multi-page bitmap.

   Return DllCall(getFIMfunc("UnlockPage"), "UPtr", hFIMULTIBITMAP, "UPtr", hImage, "Int", changed)
}

FreeImage_GetLockedPageNumbers(hFIMULTIBITMAP) {
; Returns an array of the locked page numbers, or 0 on failure
   count := 0
   If !DllCall(getFIMfunc("GetLockedPageNumbers"), "UPtr", hFIMULTIBITMAP, "UPtr", 0, "Int*", count)
      Return 0

   pages := []
   If (count < 1)
      Return pages

   VarSetCapacity(buf, 4 * count, 0)
   If !DllCall(getFIMfunc("GetLockedPageNumbers"), "UPtr", hFIMULTIBITMAP, "UPtr", &buf, "Int*", count)
      Return 0

   Loop, % count
      pages.Push(NumGet(buf, 4 * (A_Index - 1), "Int"))
   Return pages
}


; === Memory I/O functions ===

FreeImage_OpenMemory(pData:=0, size:=0) {
; pData=0 opens an empty stream to write to; otherwise the stream reads [size] bytes at pData
   Return DllCall(getFIMfunc("OpenMemory"), "UPtr", pData, "UInt", size, "UPtr")
}

FreeImage_CloseMemory(hMemory) {
   Return DllCall(getFIMfunc("CloseMemory"), "UPtr", hMemory)
}

FreeImage_TellMemory(hMemory) {
   Return DllCall(getFIMfunc("TellMemory"), "UPtr", hMemory)
}

FreeImage_SeekMemory(hMemory, offset, origin) {
   ; Moves the memory pointer to a specified location. A description of parameters follows:
   ; hMemory - Pointer to the target memory stream
   ; offset - Number of bytes from origin
   ; origin - Initial position
         ; 0 - SEEK_SET - Beginning of file.
         ; 1 - SEEK_CUR - Current position of file pointer.
         ; 2 - SEEK_END - End of file.
   ; The function returns TRUE if successful, returns FALSE otherwise

   Return DllCall(getFIMfunc("SeekMemory"), "UPtr", hMemory, "Int", offset, "Int", origin)
}

FreeImage_AcquireMemory(hMemory, ByRef BufAdr, ByRef BufSize) {
; BufAdr receives a pointer owned by the stream, valid until it is closed or written to
   BufAdr := 0, BufSize := 0
   Return DllCall(getFIMfunc("AcquireMemory"), "UPtr", hMemory, "UPtr*", BufAdr, "UInt*", BufSize)
}

FreeImage_SaveToMemory(FIF, hImage, hMemory, Flags:=0) {
; 0:BMP 2:JPG 13:PNG 18:TIF 25:GIF
   Return DllCall(getFIMfunc("SaveToMemory"), "Int", FIF, "UPtr", hImage, "UPtr", hMemory, "Int", Flags)
}

FreeImage_LoadFromMemory(FIF, hMemory, flags:=0) {
; FIF=-1 detects the format
   If (FIF=-1 || FIF="")
      FIF := FreeImage_GetFileTypeFromMemory(hMemory)
   Return DllCall(getFIMfunc("LoadFromMemory"), "Int", FIF, "UPtr", hMemory, "Int", flags, "UPtr")
}

FreeImage_ReadMemory(pBuffer, size, count, hMemory) {
; reads up to [count] items of [size] bytes into pBuffer; returns the number of items read
   Return DllCall(getFIMfunc("ReadMemory"), "UPtr", pBuffer, "UInt", size, "UInt", count, "UPtr", hMemory, "UInt")
}

FreeImage_WriteMemory(pBuffer, size, count, hMemory) {
; returns the number of items written
   Return DllCall(getFIMfunc("WriteMemory"), "UPtr", pBuffer, "UInt", size, "UInt", count, "UPtr", hMemory, "UInt")
}

FreeImage_LoadMultiBitmapFromMemory(FIF, hMemory, flags:=0) {
; FIF=-1 detects the format; hMemory must stay open until FreeImage_CloseMultiBitmap(), which discards edits: save them with FreeImage_SaveMultiBitmapToMemory()
   If (FIF=-1 || FIF="")
      FIF := FreeImage_GetFileTypeFromMemory(hMemory)
   Return DllCall(getFIMfunc("LoadMultiBitmapFromMemory"), "Int", FIF, "UPtr", hMemory, "Int", flags, "UPtr")
}

FreeImage_SaveMultiBitmapToMemory(FIF, hFIMULTIBITMAP, hMemory, flags:=0) {
   Return DllCall(getFIMfunc("SaveMultiBitmapToMemory"), "Int", FIF, "UPtr", hFIMULTIBITMAP, "UPtr", hMemory, "Int", flags)
}

; === Compression functions ===

FreeImage_ZLibCompress(pTarget, targetSize, pSource, sourceSize) {
; Returns the compressed size, or 0; sourceSize + sourceSize // 1000 + 64 bytes of target are always enough
   Return DllCall(getFIMfunc("ZLibCompress"), "UPtr", pTarget, "UInt", targetSize, "UPtr", pSource, "UInt", sourceSize, "UInt")
}

FreeImage_ZLibUncompress(pTarget, targetSize, pSource, sourceSize) {
; Returns the uncompressed size, or 0; the target must hold all of it
   Return DllCall(getFIMfunc("ZLibUncompress"), "UPtr", pTarget, "UInt", targetSize, "UPtr", pSource, "UInt", sourceSize, "UInt")
}

FreeImage_ZLibGZip(pTarget, targetSize, pSource, sourceSize) {
; like FreeImage_ZLibCompress(), with a gzip header and trailer
   Return DllCall(getFIMfunc("ZLibGZip"), "UPtr", pTarget, "UInt", targetSize, "UPtr", pSource, "UInt", sourceSize, "UInt")
}

FreeImage_ZLibGUnzip(pTarget, targetSize, pSource, sourceSize) {
   Return DllCall(getFIMfunc("ZLibGUnzip"), "UPtr", pTarget, "UInt", targetSize, "UPtr", pSource, "UInt", sourceSize, "UInt")
}

FreeImage_ZLibCRC32(crc, pSource, sourceSize) {
; crc - 0, or the result for the previous chunk
   Return DllCall(getFIMfunc("ZLibCRC32"), "UInt", crc, "UPtr", pSource, "UInt", sourceSize, "UInt")
}

; === Metadata functions ===

FreeImage_CreateTag() {
; Returns a new FITAG object. This object must be destroyed with a call to
; FreeImage_DeleteTag() when no longer required.

; Tag creation and destruction functions are only needed when you use the
; FreeImage_SetMetadata().
   Return DllCall(getFIMfunc("CreateTag"), "UPtr")
}

FreeImage_CloneTag(fiTag) {
   Return DllCall(getFIMfunc("CloneTag"), "UPtr", fiTag, "UPtr")
}

FreeImage_DeleteTag(fiTag) {
   Return DllCall(getFIMfunc("DeleteTag"), "UPtr", fiTag)
}

FreeImage_GetTagKey(fiTag) {
   Return DllCall(getFIMfunc("GetTagKey"), "UPtr", fiTag, "astr")
}

FreeImage_GetTagLength(fiTag) {
   Return DllCall(getFIMfunc("GetTagLength"), "UPtr", fiTag)
}

FreeImage_GetTagCount(fiTag) {
   Return DllCall(getFIMfunc("GetTagCount"), "UPtr", fiTag)
}

FreeImage_GetTagType(fiTag) {
   Return DllCall(getFIMfunc("GetTagType"), "UPtr", fiTag)
}

FreeImage_GetTagID(fiTag) {
   Return DllCall(getFIMfunc("GetTagID"), "UPtr", fiTag, "UShort")
}

FreeImage_GetTagValue(fiTag) {
; Returns a pointer owned by the tag, or 0; read it with NumGet().

   Return DllCall(getFIMfunc("GetTagValue"), "UPtr", fiTag, "UPtr")
}

FreeImage_GetTagDescription(fiTag) {
   Return DllCall(getFIMfunc("GetTagDescription"), "UPtr", fiTag, "astr")
}

FreeImage_SetTagKey(fiTag, key) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagKey"), "UPtr", fiTag, "astr", key)
}

FreeImage_SetTagDescription(fiTag, desc) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagDescription"), "UPtr", fiTag, "astr", desc)
}

FreeImage_SetTagType(fiTag, mdType) {
; The function returns TRUE if successful and returns FALSE otherwise.
; mdType parameter can take integer values from 0 to 18, 
; see below to learn what they mean.

/*
  Tag data type information (based on TIFF specifications)
  Note: RATIONALs are the ratio of two 32-bit integer values.

ENUM(mdType)
   FIDT_NOTYPE     = 0,   // placeholder 
   FIDT_BYTE       = 1,   // 8-bit unsigned integer 
   FIDT_ASCII      = 2,   // 8-bit bytes w/ last byte null 
   FIDT_SHORT      = 3,   // 16-bit unsigned integer 
   FIDT_LONG       = 4,   // 32-bit unsigned integer 
   FIDT_RATIONAL   = 5,   // 64-bit unsigned fraction 
   FIDT_SBYTE      = 6,   // 8-bit signed integer 
   FIDT_UNDEFINED  = 7,   // 8-bit untyped data 
   FIDT_SSHORT     = 8,   // 16-bit signed integer 
   FIDT_SLONG      = 9,   // 32-bit signed integer 
   FIDT_SRATIONAL  = 10,  // 64-bit signed fraction 
   FIDT_FLOAT      = 11,  // 32-bit IEEE floating point 
   FIDT_DOUBLE     = 12,  // 64-bit IEEE floating point 
   FIDT_IFD        = 13,  // 32-bit unsigned integer (offset) 
   FIDT_PALETTE    = 14,  // 32-bit RGBQUAD 
   FIDT_LONG8      = 16,  // 64-bit unsigned integer 
   FIDT_SLONG8     = 17,  // 64-bit signed integer
   FIDT_IFD8       = 18   // 64-bit unsigned integer (offset)
*/

   Return DllCall(getFIMfunc("SetTagType"), "UPtr", fiTag, "Int", mdType)
}

FreeImage_SetTagID(fiTag, tagID) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagID"), "UPtr", fiTag, "UShort", tagID)
}

FreeImage_SetTagCount(fiTag, tCount) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagCount"), "UPtr", fiTag, "Int", tCount)
}

FreeImage_SetTagLength(fiTag, length) {
; Set the length of the tag value, in bytes (always required).
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagLength"), "UPtr", fiTag, "Int", length)
}

FreeImage_SetTagValue(fiTag, value) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagValue"), "UPtr", fiTag, "uint*", value)
}

FreeImage_SetMetadata(hImage, fiTag, metaModel, key) {
; If fiTag is NULL then the metadata is deleted.
; If both key and fiTag are NULL then the metadata model is deleted.
; The function returns TRUE on success and returns FALSE otherwise.
; metaModel parameter can take integer values from -1 to 11. See below what
; these represent.

/*
Metadata models [metaModel] supported by FreeImage
   FIMD_NODATA         = -1,
   FIMD_COMMENTS       = 0,   // single comment or keywords
   FIMD_EXIF_MAIN      = 1,   // Exif-TIFF metadata
   FIMD_EXIF_EXIF      = 2,   // Exif-specific metadata
   FIMD_EXIF_GPS       = 3,   // Exif GPS metadata
   FIMD_EXIF_MAKERNOTE = 4,   // Exif maker note metadata
   FIMD_EXIF_INTEROP   = 5,   // Exif interoperability metadata
   FIMD_IPTC           = 6,   // IPTC/NAA metadata
   FIMD_XMP            = 7,   // Abobe XMP metadata
   FIMD_GEOTIFF        = 8,   // GeoTIFF metadata
   FIMD_ANIMATION      = 9,   // Animation metadata
   FIMD_CUSTOM         = 10,  // Used to attach other metadata types to a dib
   FIMD_EXIF_RAW       = 11   // Exif metadata as a raw buffer
*/

; To delete an entire metadata model, pass a blank key AND a blank fiTag. The blank key
; must reach FreeImage as a real NULL pointer; DllCall marshals a blank "astr" as a pointer
; to an empty string, which FreeImage reads as a request to delete the tag named "" and so
; leaves the model untouched.

   If (key="")
      Return DllCall(getFIMfunc("SetMetadata"), "Int", metaModel, "UPtr", hImage, "UPtr", 0, "UPtr", 0)

   Return DllCall(getFIMfunc("SetMetadata"), "Int", metaModel, "UPtr", hImage, "astr", key, "UPtr", fiTag)
}

FreeImage_CloneMetadata(destImg, srcImg) {
; Copy all metadata contained in src into dst, with the exception of FIMD_ANIMATION
; metadata (these metadata are not copied because this may cause problems when saving to
; GIF). When a src metadata model already exists in dst, the dst metadata model is first erased
; before copying the src one. When a metadata model already exists in dst and not in src, it is
; left untouched.
; Horizontal and vertical resolution info (returned by FreeImage_GetDotsPerMeterX and by
; FreeImage_GetDotsPerMeterY) is also copied from src to dst.
; The function returns TRUE on success and returns FALSE otherwise (e.g. when src or dst
; are invalid).

   Return DllCall(getFIMfunc("CloneMetadata"), "UPtr", destImg, "UPtr", srcImg)
}

FreeImage_GetMetadataCount(metaModel, hImage) {
; Returns the number of tags contained in the metadata model attached to the input hImage.
   Return DllCall(getFIMfunc("GetMetadataCount"), "Int", metaModel, "UPtr", hImage)
}

FreeImage_GetMetadata(hImage, metaModel, key, ByRef fiTag) {
; fiTag receives a FITAG owned by hImage; returns TRUE if the key was found.

   fiTag := 0
   Return DllCall(getFIMfunc("GetMetadata"), "Int", metaModel, "UPtr", hImage, "astr", key, "uptr*", fiTag)
}

FreeImage_FindFirstMetadata(metaModel, hImage, ByRef fiTag) {
; Returns a search handle for FreeImage_FindNextMetadata(), or 0 if the model has no tags; fiTag receives a FITAG owned by hImage
   fiTag := 0
   Return DllCall(getFIMfunc("FindFirstMetadata"), "Int", metaModel, "UPtr", hImage, "UPtr*", fiTag, "UPtr")
}

FreeImage_FindNextMetadata(hFind, ByRef fiTag) {
; Returns FALSE after the last tag
   fiTag := 0
   Return DllCall(getFIMfunc("FindNextMetadata"), "UPtr", hFind, "UPtr*", fiTag)
}

FreeImage_FindCloseMetadata(hFind) {
   Return DllCall(getFIMfunc("FindCloseMetadata"), "UPtr", hFind)
}

FreeImage_SetMetadataKeyValue(metaModel, hImage, key, value) {
; Attaches value as an FIDT_ASCII tag; returns TRUE on success
   Return DllCall(getFIMfunc("SetMetadataKeyValue"), "Int", metaModel, "UPtr", hImage, "AStr", key, "AStr", value)
}

FreeImage_TagToString(metaModel, fiTag, make:="") {
; make - the camera maker, which FIMD_EXIF_MAKERNOTE tags need
   Return DllCall(getFIMfunc("TagToString"), "Int", metaModel, "UPtr", fiTag, (make="") ? "UPtr" : "AStr", (make="") ? 0 : make, "AStr")
}

; === Animation helpers ===
; Not FreeImage API functions.

FreeImage_GetFrameTime(hImage) {
; Frame duration in milliseconds.
;
; GIF, APNG, MNG, animated WebP, HEIF and AVIF image sequences all describe
; a frame with the same FIMD_ANIMATION tags, in the "FrameTime" value.
;
; It returns 0 when the page declares no duration.

   Static FIMD_ANIMATION := 9
        , FIDT_LONG := 4

   If (!FreeImage_GetMetadata(hImage, FIMD_ANIMATION, "FrameTime", fiTag) || !fiTag)
      Return 0

   pValue := FreeImage_GetTagValue(fiTag)
   If (!pValue || FreeImage_GetTagType(fiTag)!=FIDT_LONG)
      Return 0

   Return NumGet(pValue+0, 0, "UInt")
}

FreeImage_GetFrameDelays(ImgPath, ByRef delaysArray, ByRef totalTime:=0) {
; Every frame's duration, to tell the animation's length and
; which frame belongs to a moment.
;
; delaysArray[1] is the first frame; totalTime is one pass, in ms.
; Returns the frame count, or -1 if the file cannot be read.

   Static FIF_LOAD_NOPIXELS := 0x8000

   delaysArray := [] , totalTime := 0
   FIF := FreeImage_GetFileType(ImgPath)
   If (FIF=-1 || !FreeImage_FIFSupportsReading(FIF))
      Return -1

   ; pass create_new=0, read_only=1, keep_cache=1
   hMultiImg := FreeImage_OpenMultiBitmap(ImgPath, FIF, 0, 1, 1, FIF_LOAD_NOPIXELS)
   If !hMultiImg
      Return -1

   frameCount := FreeImage_GetPageCount(hMultiImg)
   Loop, % frameCount
   {
      hImage := FreeImage_LockPage(hMultiImg, A_Index - 1)
      thisDelay := hImage ? FreeImage_GetFrameTime(hImage) : 0
      delaysArray[A_Index] := thisDelay
      totalTime += thisDelay
      If hImage
         FreeImage_UnlockPage(hMultiImg, hImage, 0) ; 0: unchanged
   }

   FreeImage_CloseMultiBitmap(hMultiImg, 0)
   Return frameCount
}

; === Toolkit functions ===

FreeImage_Rotate(hImage, angle, bkColor:="") {
   ; bkColor - "R,G,B,A" for 24/32-bit images, else a pointer to a pixel of the image type; blank is black
   ; returns a new hImage
   pColor := FIMcolorPointer(bkColor, colorBuf)
   Return DllCall(getFIMfunc("Rotate"), "UPtr", hImage, "Double", angle, "UPtr", pColor, "UPtr")
}

FreeImage_RotateEx(hImage, angle, xShift, yShift, xOrigin, yOrigin, useMask) {
; 8, 24 and 32-bit images, rotated about (xOrigin, yOrigin), shifted, same size; useMask=1 blacks out the uncovered area, 0 mirrors the image into it
   Return DllCall(getFIMfunc("RotateEx"), "UPtr", hImage, "Double", angle, "Double", xShift, "Double", yShift, "Double", xOrigin, "Double", yOrigin, "Int", useMask, "UPtr")
}

FreeImage_FlipHorizontal(hImage) {
   ; returns 1 if success
   Return DllCall(getFIMfunc("FlipHorizontal"), "UPtr", hImage)
}

FreeImage_FlipVertical(hImage) {
   ; returns 1 if success
   Return DllCall(getFIMfunc("FlipVertical"), "UPtr", hImage)
}

FreeImage_Rescale(hImage, w, h, filter:=3) {
; Filter parameter options
; 0 = FILTER_BOX;        Box, pulse, Fourier window, 1st order (constant) B-Spline
; 1 = FILTER_BICUBIC;    Mitchell and Netravali's two-param cubic filter
; 2 = FILTER_BILINEAR;   Bilinear filter
; 3 = FILTER_BSPLINE;    4th order (cubic) B-Spline
; 4 = FILTER_CATMULLROM; Catmull-Rom spline, Overhauser spline
; 5 = FILTER_LANCZOS3;   Lanczos-windowed sinc filter
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Rescale"), "UPtr", hImage, "Int", w, "Int", h, "Int", filter, "UPtr")
}

FreeImage_RescaleRect(hImage, dstW, dstH, x, y, w, h, filter:=0, flags:=2) {
; Filter parameter options
; see FreeImage_Rescale()

; Flags options:
; FI_RESCALE_DEFAULT         0x00   // default options; none of the following other options apply
; FI_RESCALE_TRUE_COLOR      0x01   // for non-transparent greyscale images, convert to 24-bit if src bitdepth <= 8 (default is a 8-bit greyscale image). 
; FI_RESCALE_OMIT_METADATA   0x02   // do not copy metadata to the rescaled image

   If (hImage="")
      Return

   Return DllCall(getFIMfunc("RescaleRect"), "UPtr", hImage, "Int", dstW, "Int", dstH, "Int", x, "Int", y, "Int", x + w, "Int", y + h, "Int", filter, "Int", flags, "UPtr")
}

FreeImage_RescaleRawBits(srcBits, dstBits, FimType, imgW, imgH, srcStride, dstStride, BPP, dstW, dstH, filter) {
   Return FreeImage_RescaleRectRawBits(srcBits, dstBits, FimType, imgW, imgH, srcStride, dstStride, BPP, dstW, dstH, 0, 0, imgW, imgH, filter)
}

FreeImage_RescaleRectRawBits(srcBits, dstBits, FimType, imgW, imgH, srcStride, dstStride, BPP, dstW, dstH, srcX1, srcY1, srcX2, srcY2, filter) {
   Return DllCall(getFIMfunc("RescaleRawBits"), "UPtr", srcBits, "UPtr", dstBits, "Int", FimType, "Int", imgW, "Int", imgH, "uInt", srcStride, "uInt", dstStride, "Int", BPP, "Int", dstW, "Int", dstH, "Int", srcX1, "Int", srcY1, "Int", srcX2, "Int", srcY2, "Int", filter)
}

FreeImage_MakeThumbnail(hImage, squareSize, convert:=1) {
; Filter parameter options
; 0 = FILTER_BOX;        Box, pulse, Fourier window, 1st order (constant) B-Spline
; 1 = FILTER_BICUBIC;    Mitchell and Netravali's two-param cubic filter
; 2 = FILTER_BILINEAR;   Bilinear filter
; 3 = FILTER_BSPLINE;    4th order (cubic) B-Spline
; 4 = FILTER_CATMULLROM; Catmull-Rom spline, Overhauser spline
; 5 = FILTER_LANCZOS3;   Lanczos-windowed sinc filter

   Return DllCall(getFIMfunc("MakeThumbnail"), "UPtr", hImage, "Int", squareSize, "Int", convert, "UPtr")
}

FreeImage_AdjustColors(hImage, bright, contrast, gamma, invert) {
; bright and contrast interval: [-100, 100]
; gamma interval: [0.0, 2.0]
; invert: 1 or 0
; return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("AdjustColors"), "UPtr", hImage, "Double", bright, "Double", contrast, "Double", gamma, "Int", invert)
}

FreeImage_AdjustBrightness(hImage, percentage) {
; percentage [-100, 100]; 8, 24 and 32-bit images
   Return DllCall(getFIMfunc("AdjustBrightness"), "UPtr", hImage, "Double", percentage)
}

FreeImage_AdjustContrast(hImage, percentage) {
; percentage [-100, 100]; 8, 24 and 32-bit images
   Return DllCall(getFIMfunc("AdjustContrast"), "UPtr", hImage, "Double", percentage)
}

FreeImage_AdjustGamma(hImage, gamma) {
; gamma > 0; 1.0 leaves the image unchanged
   Return DllCall(getFIMfunc("AdjustGamma"), "UPtr", hImage, "Double", gamma)
}

FreeImage_AdjustCurve(hImage, pLUT, channel:=0) {
; pLUT - 256 bytes mapping each channel value; channel - see FreeImage_GetChannel()
   Return DllCall(getFIMfunc("AdjustCurve"), "UPtr", hImage, "UPtr", pLUT, "Int", channel)
}

FreeImage_GetAdjustColorsLookupTable(pLUT, bright, contrast, gamma, invert) {
; fills the 256 bytes at pLUT for FreeImage_AdjustCurve(); returns how many adjustments it holds
   Return DllCall(getFIMfunc("GetAdjustColorsLookupTable"), "UPtr", pLUT, "Double", bright, "Double", contrast, "Double", gamma, "Int", invert)
}

FreeImage_ApplyColorMapping(hImage, srcColors, dstColors, count:=0, ignoreAlpha:=1, swap:=0) {
; srcColors and dstColors - arrays of "R,G,B,A" or pointers to RGBQUADs; swap=1 also maps dst to src; returns the number of pixels changed
   pSrc := FIMcolorArray(srcColors, srcBuf)
   pDst := FIMcolorArray(dstColors, dstBuf)
   If (!count && IsObject(srcColors))
      count := srcColors.Length()
   Return DllCall(getFIMfunc("ApplyColorMapping"), "UPtr", hImage, "UPtr", pSrc, "UPtr", pDst, "UInt", count, "Int", ignoreAlpha, "Int", swap, "UInt")
}

FreeImage_SwapColors(hImage, colorA, colorB, ignoreAlpha:=1) {
; colorA and colorB - "R,G,B,A" or pointers to RGBQUADs; returns the number of pixels changed
   pA := FIMcolorPointer(colorA, bufA)
   pB := FIMcolorPointer(colorB, bufB)
   Return DllCall(getFIMfunc("SwapColors"), "UPtr", hImage, "UPtr", pA, "UPtr", pB, "Int", ignoreAlpha, "UInt")
}

FreeImage_ApplyPaletteIndexMapping(hImage, srcIndices, dstIndices, count:=0, swap:=0) {
; srcIndices and dstIndices - arrays of palette indices or pointers to bytes; returns the number of pixels changed
   pSrc := FIMbyteArray(srcIndices, srcBuf)
   pDst := FIMbyteArray(dstIndices, dstBuf)
   If (!count && IsObject(srcIndices))
      count := srcIndices.Length()
   Return DllCall(getFIMfunc("ApplyPaletteIndexMapping"), "UPtr", hImage, "UPtr", pSrc, "UPtr", pDst, "UInt", count, "Int", swap, "UInt")
}

FreeImage_SwapPaletteIndices(hImage, indexA, indexB) {
; Returns the number of pixels changed
   Return DllCall(getFIMfunc("SwapPaletteIndices"), "UPtr", hImage, "UChar*", indexA, "UChar*", indexB, "UInt")
}

FreeImage_Crop(hImage, x, y, w, h) {
   Return FreeImage_Copy(hImage, x, y, x + w, y + h)
}

FreeImage_CroppedView(hImage, x, y, w, h) {
   Return FreeImage_CreateView(hImage, x, y, x + w, y + h)
}

FreeImage_Copy(hImage, nLeft, nTop, nRight, nBottom) {
; use this function to crop images
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Copy"), "UPtr", hImage, "Int", nLeft, "Int", nTop, "Int", nRight, "Int", nBottom, "UPtr")
}

FreeImage_CreateView(hImage, nLeft, nTop, nRight, nBottom) {
; Creates a dynamic read/write view into a FreeImage bitmap.
; A dynamic view is a FreeImage bitmap with its own width and height, that, however, shares
; its bits with another FreeImage bitmap. Typically, views are used to define one or more
; rectangular sub-images of an existing bitmap. All FreeImage operations, like saving,
; displaying and all the toolkit functions, when applied to the view, only affect the view's
; rectangular area.
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("CreateView"), "UPtr", hImage, "Int", nLeft, "Int", nTop, "Int", nRight, "Int", nBottom, "UPtr")
}

FreeImage_Paste(hImageDst, hImageSrc, nLeft, nTop, nAlpha) {
   Return DllCall(getFIMfunc("Paste"), "UPtr", hImageDst, "UPtr", hImageSrc, "Int", nLeft, "Int", nTop, "Int", nAlpha)
}

FreeImage_Composite(hImage, useFileBkg:=0, RGBArray:="255,255,255", hImageBkg:=0) {
   RGBA := StrSplit(RGBArray, ",")
   VarSetCapacity(RGBQUAD, 4, 0)
   NumPut(RGBA[3], RGBQUAD, 0, "UChar")
   NumPut(RGBA[2], RGBQUAD, 1, "UChar")
   NumPut(RGBA[1], RGBQUAD, 2, "UChar")
   NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("Composite"), "UPtr", hImage, "Int", useFileBkg, "UPtr", &RGBQUAD, "UPtr", hImageBkg, "UPtr")
}

FreeImage_EnlargeCanvas(hImage, left, top, right, bottom, color:="", options:=0) {
; Returns a new image with the margins added, negative ones crop; color - as in FreeImage_AllocateExT(), required unless it only crops
   pColor := FIMcolorPointer(color, colorBuf)
   Return DllCall(getFIMfunc("EnlargeCanvas"), "UPtr", hImage, "Int", left, "Int", top, "Int", right, "Int", bottom, "UPtr", pColor, "Int", options, "UPtr")
}

FreeImage_PreMultiplyWithAlpha(hImage) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("PreMultiplyWithAlpha"), "UPtr", hImage)
}

FreeImage_Invert(hImage) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("Invert"), "UPtr", hImage)
}

FreeImage_MultigridPoissonSolver(hLaplacian, ncycle:=3) {
; hLaplacian - a FIT_FLOAT image; returns the FIT_FLOAT solution
   Return DllCall(getFIMfunc("MultigridPoissonSolver"), "UPtr", hLaplacian, "Int", ncycle, "UPtr")
}

FreeImage_JPEGTransform(SrcImPath, DstImPath, ImgOperation, perfect:=0) {
; ImgOperation parameter options:
; 0 = NONE                1 = Flip Horizontally
; 2 = Flip Vertically     3 = Transpose
; 4 = Transverse          5 = Rotate 90
; 6 = Rotate 180          7 = Rotate -90 [270]
; perfect=1 fails when the image size is not a multiple of the MCU size; 0 trims the partial edge blocks
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("JPEGTransformU"), "WStr", SrcImPath, "WStr", DstImPath, "Int", ImgOperation, "Int", perfect)
}

FreeImage_JPEGCrop(SrcImgPath, DstImgPath, x1, y1, x2, y2) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("JPEGCropU"), "WStr", SrcImgPath, "WStr", DstImgPath, "Int", x1, "Int", y1, "Int", x2, "Int", y2)
}

FreeImage_JPEGTransformCombined(SrcImgPath, DstImgPath, ImgOperation, ByRef x1, ByRef y1, ByRef x2, ByRef y2, perfect:=0) {
; x1, y1, x2, y2 receive the crop rectangle applied, aligned to the MCU grid; a blank DstImgPath only computes it
   Return DllCall(getFIMfunc("JPEGTransformCombinedU"), "WStr", SrcImgPath, (DstImgPath="") ? "UPtr" : "WStr", (DstImgPath="") ? 0 : DstImgPath, "Int", ImgOperation, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2, "Int", perfect)
}

FreeImage_JPEGTransformFromHandle(pSrcIO, hSrc, pDstIO, hDst, ImgOperation, ByRef x1:=0, ByRef y1:=0, ByRef x2:=0, ByRef y2:=0, perfect:=0) {
; see FreeImage_JPEGTransformCombined() and FreeImage_LoadFromHandle(); a 0,0,0,0 rectangle does not crop
   Return DllCall(getFIMfunc("JPEGTransformFromHandle"), "UPtr", pSrcIO, "UPtr", hSrc, "UPtr", pDstIO, "UPtr", hDst, "Int", ImgOperation, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2, "Int", perfect)
}

FreeImage_JPEGTransformCombinedFromMemory(hMemSrc, hMemDst, ImgOperation, ByRef x1:=0, ByRef y1:=0, ByRef x2:=0, ByRef y2:=0, perfect:=0) {
; hMemDst - a stream from FreeImage_OpenMemory() without data, or 0 to only compute the rectangle; see FreeImage_JPEGTransformCombined()
   Return DllCall(getFIMfunc("JPEGTransformCombinedFromMemory"), "UPtr", hMemSrc, "UPtr", hMemDst, "Int", ImgOperation, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2, "Int", perfect)
}

; === Other functions ===

FreeImage_GetChannel(hImage, channel) {
; Return value: 0 = failed.
; Channel to retrieve:
; 0 - RGB
; 1 - RED
; 2 - GREEN
; 3 - BLUE
; 4 - ALPHA
; 5 - BLACK 

   Return DllCall(getFIMfunc("GetChannel"), "UPtr", hImage, "Int", channel, "UPtr")
}

FreeImage_SetChannel(hImage, hImageGrey, channel) {
; hImageGrey must be in Greyscale format.
;
; Return value: 0 = failed.
; Channel to set:
; 0 - RGB
; 1 - RED
; 2 - GREEN
; 3 - BLUE
; 4 - ALPHA
; 5 - BLACK 

   Return DllCall(getFIMfunc("SetChannel"), "UPtr", hImage, "UPtr", hImageGrey, "Int", channel)
}

FreeImage_GetComplexChannel(hImage, channel) {
; hImage - a FIT_COMPLEX image; channel: 6 - REAL, 7 - IMAG, 8 - MAG, 9 - PHASE; returns a FIT_DOUBLE image
   Return DllCall(getFIMfunc("GetComplexChannel"), "UPtr", hImage, "Int", channel, "UPtr")
}

FreeImage_SetComplexChannel(hImage, hImageDouble, channel) {
; hImage - a FIT_COMPLEX image; hImageDouble - a FIT_DOUBLE image; channel: 6 - REAL, 7 - IMAG
   Return DllCall(getFIMfunc("SetComplexChannel"), "UPtr", hImage, "UPtr", hImageDouble, "Int", channel)
}

getFIMfunc(funct) {
; for some crazy reason, in the 32 bits DLL of FreeImage
; each function name ends with a number preceded by @
; this function is meant to enable 32 bits compatibility

   Static fList0 := "|CreateTag|DeInitialise|GetCopyrightMessage|GetFIFCount|GetVersion|IsLittleEndian|"
        , fList4 := "|Clone|CloneTag|CloseMemory|ConvertTo16Bits555|ConvertTo16Bits565|ConvertTo24Bits|ConvertTo32Bits|ConvertTo4Bits|ConvertTo8Bits|ConvertToFloat|ConvertToGreyscale|ConvertToRGB16|ConvertToRGBA16|ConvertToRGBAF|ConvertToRGBF|ConvertToUINT16|DeleteTag|DestroyICCProfile|FIFSupportsICCProfiles|FIFSupportsNoPixels|FIFSupportsReading|FIFSupportsWriting|FindCloseMetadata|FlipHorizontal|FlipVertical|GetBits|GetBlueMask|GetBPP|GetColorsUsed|GetColorType|GetDIBSize|GetDotsPerMeterX|GetDotsPerMeterY|GetFIFDescription|GetFIFExtensionList|GetFIFFromFilename|GetFIFFromFilenameU|GetFIFFromFormat|GetFIFFromMime|GetFIFMimeType|GetFIFRegExpr|GetFormatFromFIF|GetGreenMask|GetHeight|GetICCProfile|GetImageType|GetInfo|GetInfoHeader|GetLine|GetMemorySize|GetPageCount|GetPalette|GetPitch|GetRedMask|GetTagCount|GetTagDescription|GetTagID|GetTagKey|GetTagLength|GetTagType|GetTagValue|GetThumbnail|GetTransparencyCount|GetTransparencyTable|GetTransparentIndex|GetWidth|HasBackgroundColor|HasPixels|HasRGBMasks|Initialise|Invert|IsPluginEnabled|IsTransparent|PreMultiplyWithAlpha|SetOutputMessage|SetOutputMessageStdCall|TellMemory|Unload|"
        , fList8 := "|AppendPage|AppendPageEx|CloneMetadata|CloseMultiBitmap|ColorQuantize|ConvertToStandardType|DeletePage|DeletePageEx|Dither|FIFSupportsExportBPP|FIFSupportsExportType|FindNextMetadata|GetBackgroundColor|GetChannel|GetComplexChannel|GetFileType|GetFileTypeFromMemory|GetFileTypeU|GetMetadataCount|GetScanLine|LockPage|MultigridPoissonSolver|OpenMemory|SetBackgroundColor|SetDotsPerMeterX|SetDotsPerMeterY|SetPluginEnabled|SetTagCount|SetTagDescription|SetTagID|SetTagKey|SetTagLength|SetTagType|SetTagValue|SetThumbnail|SetTransparent|SetTransparentIndex|Threshold|Validate|ValidateFromMemory|ValidateU|"
        , fList12 := "|AcquireMemory|AdjustBrightness|AdjustContrast|AdjustCurve|AdjustGamma|ConvertLine16_555_To16_565|ConvertLine16_565_To16_555|ConvertLine16To24_555|ConvertLine16To24_565|ConvertLine16To32_555|ConvertLine16To32_565|ConvertLine16To4_555|ConvertLine16To4_565|ConvertLine16To8_555|ConvertLine16To8_565|ConvertLine1To4|ConvertLine1To8|ConvertLine24To16_555|ConvertLine24To16_565|ConvertLine24To32|ConvertLine24To4|ConvertLine24To8|ConvertLine32To16_555|ConvertLine32To16_565|ConvertLine32To24|ConvertLine32To4|ConvertLine32To8|ConvertLine4To8|ConvertToType|CreateICCProfile|FillBackground|FindFirstMetadata|GetFileTypeFromHandle|GetHistogram|GetLockedPageNumbers|InsertPage|InsertPageEx|Load|LoadFromMemory|LoadMultiBitmapFromMemory|LoadU|MakeThumbnail|MovePage|SeekMemory|SetChannel|SetComplexChannel|SetTransparencyTable|SwapPaletteIndices|TagToString|UnlockPage|ValidateFromHandle|ZLibCRC32|"
        , fList16 := "|Composite|ConvertLine1To16_555|ConvertLine1To16_565|ConvertLine1To24|ConvertLine1To32|ConvertLine4To16_555|ConvertLine4To16_565|ConvertLine4To24|ConvertLine4To32|ConvertLine8To16_555|ConvertLine8To16_565|ConvertLine8To24|ConvertLine8To32|ConvertLine8To4|GetMetadata|GetPixelColor|GetPixelIndex|JPEGTransform|JPEGTransformU|LoadFromHandle|LookupSVGColor|LookupX11Color|OpenMultiBitmapFromHandle|ReadMemory|Rescale|Rotate|Save|SaveMultiBitmapToMemory|SaveToMemory|SaveU|SetMetadata|SetMetadataKeyValue|SetPixelColor|SetPixelIndex|SwapColors|WriteMemory|ZLibCompress|ZLibGUnzip|ZLibGZip|ZLibUncompress|"
        , fList20 := "|ApplyPaletteIndexMapping|ColorQuantizeEx|Copy|CreateView|Paste|RegisterExternalPlugin|RegisterLocalPlugin|SaveMultiBitmapToHandle|SaveToHandle|TmoDrago03|TmoFattal02|TmoReinhard05|"
        , fList24 := "|Allocate|ApplyColorMapping|ConvertLine1To32MapTransparency|ConvertLine4To32MapTransparency|ConvertLine8To32MapTransparency|JPEGCrop|JPEGCropU|OpenMultiBitmap|OpenMultiBitmapU|ToneMapping|"
        , fList28 := "|AllocateHeader|AllocateT|EnlargeCanvas|"
        , fList32 := "|AdjustColors|AllocateHeaderT|ConvertToRawBits|GetAdjustColorsLookupTable|JPEGTransformCombined|JPEGTransformCombinedFromMemory|JPEGTransformCombinedU|"
        , fList36 := "|AllocateEx|AllocateHeaderForBits|ConvertFromRawBits|RescaleRect|TmoReinhard05Ex|"

   ; the variadic OutputMessageProc is cdecl, exported undecorated
   fPrefix := (A_PtrSize=8 || funct="OutputMessageProc") ? "FreeImage_" : "_FreeImage_"
   fSuffix := ""
   If (A_PtrSize!=8)
   {
      If InStr(fList0, "|" funct "|")
         fSuffix := "@0"
      Else If InStr(fList4, "|" funct "|")
         fSuffix := "@4"
      Else If InStr(fList8, "|" funct "|")
         fSuffix := "@8"
      Else If InStr(fList12, "|" funct "|")
         fSuffix := "@12"
      Else If InStr(fList16, "|" funct "|")
         fSuffix := "@16"
      Else If InStr(fList20, "|" funct "|")
         fSuffix := "@20"
      Else If InStr(fList24, "|" funct "|")
         fSuffix := "@24"
      Else If InStr(fList28, "|" funct "|")
         fSuffix := "@28"
      Else If InStr(fList32, "|" funct "|")
         fSuffix := "@32"
      Else If InStr(fList36, "|" funct "|")
         fSuffix := "@36"
      Else If (funct="AllocateExT" || funct="JPEGTransformFromHandle")
         fSuffix := "@40"
      Else If (funct="ConvertFromRawBitsEx")
         fSuffix := "@44"
      Else If (funct="RotateEx")
         fSuffix := "@48"
      Else If (funct="RescaleRawBits")
         fSuffix := "@60"
   }

   funct := FreeImage_FoxInit("lastDllName") "\" fPrefix funct fSuffix
   Return funct
}

ConvertFIMtoPBITMAP(hFIFimgA, pixelFormat:="0xE200B") {
; only the FreeImage Standard Bitmap type is supported

  type := FreeImage_GetImageType(hFIFimgA)
  If (type!=1)
     Return

  pBits := FreeImage_GetBits(hFIFimgA)
  If !pBits
     Return

  FreeImage_GetImageDimensions(hFIFimgA, w, h)
  bpp := FreeImage_GetBPP(hFIFimgA)
  If (bpp=32)
  {
     FreeImage_FlipVertical(hFIFimgA)
     Stride := FreeImage_GetPitch(hFIFimgA)
     nBitmap := Gdip_CreateBitmap(w, h, "0x26200A", Stride, pBits)
  } Else
  {
     bitmapInfo := FreeImage_GetInfo(hFIFimgA)
     nBitmap := Gdip_CreateBitmapFromGdiDib(bitmapInfo, pBits) ; this does not retain alpha channel :(
  }
  
  If !nBitmap
     Return

  FreeImage_GetDPIresolution(hFIFimgA, dpiX, dpiY)
  pBitmap := Gdip_CloneBitmapArea(nBitmap, 0, 0, w, h, pixelFormat)
  If pBitmap
     Gdip_BitmapSetResolution(pBitmap, Round(dpiX), Round(dpiY))

  Gdip_DisposeImage(nBitmap)
  Return pBitmap
}

ConvertAdvancedFIMtoPBITMAP(hFIFimgA, doFlip) {
; this function wraps a GDI+ bitmap object around the FreeImage bitmap data 
; it will return on success the GDI+ bitmap and the FreeImage bitmap initially given 
; the memory data will be shared
; when you want to discard the gdi+ bitmap, you may also discard the FreeImage bitmap 
; to completely free the memory

  type := FreeImage_GetImageType(hFIFimgA)
  If (type!=1)
     Return

  bpp := FreeImage_GetBPP(hFIFimgA)
  If (bpp!=24 && bpp!=32)
     Return

  pixelFormat := (bpp=32) ? "0x26200A" : "0x21808"
  Stride := FreeImage_GetPitch(hFIFimgA)
  pBits := FreeImage_GetBits(hFIFimgA)
  FreeImage_GetDPIresolution(hFIFimgA, dpiX, dpiY)
  FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
  ; ToolTip, % bpp "|" pixelFormat , , , 2
  If (doFlip=1)
     FreeImage_FlipVertical(hFIFimgA)

  pBitmap := Gdip_CreateBitmap(imgW, imgH, pixelFormat, Stride, pBits)
  If pBitmap
  {
     Gdip_BitmapSetResolution(pBitmap, Round(dpiX), Round(dpiY))
     Return [pBitmap, hFIFimgA]
  }
}

ConvertPBITMAPtoFIM(pBitmap, doLowerbits:=0) {
; Please provide a 32 RGBA image format GDI+ object.
; To provide a 24-RGB image, use doLowerbits=1.
; This function relies on the GDI+ AHK library.
; For a 16 bits (16-RGB-555) image, use doLowerbits=2.

; If succesful, the function returns a FreeImage image object
; created from pBitmap [GDI+ image object].

  Static redMASK   := "0x00FF0000" ; FI_RGBA_RED_MASK;
       , greenMASK := "0x0000FF00" ; FI_RGBA_GREEN_MASK;
       , blueMASK  := "0x000000FF" ; FI_RGBA_BLUE_MASK;

  Gdip_GetImageDimensions(pBitmap, imgW, imgH)
  pixelFormat := (doLowerbits=1) ? "0x21808" : "0x26200A"
  bitsDepth := (doLowerbits=1) ? 24 : 32
  If (doLowerbits=2)
  {
     pixelFormat := "0x21005"
     bitsDepth := 16
  }

  E := Gdip_LockBits(pBitmap, 0, 0, imgW, imgH, Stride, Scan0, BitmapData, 1, pixelFormat)
  ; fnOutputDebug(A_ThisFunc "|" pixelFormat "|" bitsDepth "|" doLowerbits)
  IF !E
  {
     hFIFimgA := FreeImage_ConvertFromRawBits(Scan0, imgW, imgH, Stride, bitsDepth, redMASK, greenMASK, blueMASK, 1)
     Gdip_UnlockBits(pBitmap, BitmapData)
     Gdip_BitmapGetDPIresolution(pBitmap, dpiX, dpiY)
     FreeImage_SetDPIresolution(hFIFimgA, dpiX, dpiY)
  }
  Return hFIFimgA
}
