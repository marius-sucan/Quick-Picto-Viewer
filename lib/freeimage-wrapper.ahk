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


FreeImage_FoxInit(isInit:=1, bonusPath:=0) {
   Static hFIDll
   ; if you change the dll name, getFIMfunc() needs to reflect this
   If RegExMatch(bonusPath, "i)(.\.dll)$")
      DllPath := bonusPath
   Else
      DllPath := FreeImage_FoxGetDllPath("freeimage.dll", bonusPath)

   If !DllPath
      Return "err - 404"

   If (isInit=1)
      hFIDll := DllCall("LoadLibraryW", "WStr", DllPath, "uptr")
   Else
      DllCall("FreeLibrary", "UInt", hFIDll)

   ; ToolTip, % DllPath "`n" hFIDll , , , 2
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
FreeImage_Initialise() {
   Return DllCall(getFIMfunc("Initialise"), "Int", 0, "Int", 0)
}

FreeImage_DeInitialise() {
   Return DllCall(getFIMfunc("DeInitialise"))
}

FreeImage_GetVersion() {
   Return DllCall(getFIMfunc("GetVersion"), "AStr")
}

FreeImage_GetLibVersion() {
   Return 1.91 ;  vendredi 10 janvier 2025
}

FreeImage_GetCopyrightMessage() {
   Return DllCall(getFIMfunc("GetCopyrightMessage"), "AStr")
}

; === Bitmap management functions ===
; missing functions: LoadFromHandle and SaveToHandle.

FreeImage_Allocate(width, height, bpp:=32, imageType:=1, red_mask:=0xFF000000, green_mask:=0x00FF0000, blue_mask:=0x0000FF00) {
; function useful to create a new / empty bitmap
; for imageType see FreeImage_GetImageType()
   Return DllCall(getFIMfunc("AllocateT"), "int", imageType, "int", width, "int", height, "int", bpp, "uint", red_mask, "uint", green_mask, "uint", blue_mask, "uptr")
}

FreeImage_AllocateEx(width, height, bpp:=32, RGBArray:="255,255,255,0", options:=1, red_mask:=0xFF000000, green_mask:=0x00FF0000, blue_mask:=0x0000FF00, hPalette:=0) {
; function useful to create a new / empty bitmap
   If (RGBArray!="")
   {
      RGBA := StrSplit(RGBArray, ",")
      VarSetCapacity(RGBQUAD, 4, 0)
      NumPut(RGBA[3], RGBQUAD, 0, "UChar")
      NumPut(RGBA[2], RGBQUAD, 1, "UChar")
      NumPut(RGBA[1], RGBQUAD, 2, "UChar")
      NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   } else RGBQUAD := 0

   Return DllCall(getFIMfunc("AllocateEx"), "int", width, "int", height, "int", bpp, "UInt", &RGBQUAD, "int", options, "uint", hPalette, "uint", red_mask, "uint", green_mask, "uint", blue_mask, "uptr")
}

FreeImage_Load(ImgPath, GFT:=-1, flag:=0, ByRef dGFT:=0) {
   If !ImgPath
      Return

   If (GFT=-1 || GFT="")
      dGFT := GFT := FreeImage_GetFileType(ImgPath)

   If (GFT="")
      Return

   Return DllCall(getFIMfunc("LoadU"), "Int", GFT, "WStr", ImgPath, "int", flag, "uptr")
}

FreeImage_Save(hImage, ImgPath, ImgArg:=0) {
; Return 0 = failed; 1 = success
; FIMfrmt := {"BMP":0, "JPG":2, "JPEG":2, "PNG":13, "TIF":18, "TIFF":18, "GIF":25}
   If (!hImage || !ImgPath)
      Return

   FormatID := FreeImage_GetFIFFromFilename(ImgPath)
   Return DllCall(getFIMfunc("SaveU"), "Int", FormatID, "uptr", hImage, "WStr", ImgPath, "int", ImgArg)
}

FreeImage_Clone(hImage) {
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Clone"), "uptr", hImage, "uptr")
}

FreeImage_UnLoad(hImage) {
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Unload"), "uptr", hImage)
}

; === Bitmap information functions ===
; missing functions: GetThumbnail and SetThumbnail.

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
   r := DllCall(getFIMfunc("GetImageType"), "uptr", hImage)
   If (humanReadable=1 && imgTypes.HasKey(r))
      r := imgTypes[r]
   Return r
}

FreeImage_GetColorsUsed(hImage) {
   Return DllCall(getFIMfunc("GetColorsUsed"), "uptr", hImage)
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
   E := DllCall(getFIMfunc("GetHistogram"), "uptr", hImage, "uptr", &histo, "int", channel)
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
   Return DllCall(getFIMfunc("GetBPP"), "uptr", hImage)
}

FreeImage_GetWidth(hImage) {
   Return DllCall(getFIMfunc("GetWidth"), "uptr", hImage)
}

FreeImage_GetHeight(hImage) {
   Return DllCall(getFIMfunc("GetHeight"), "uptr", hImage)
}

FreeImage_GetImageDimensions(hImage, ByRef imgW, ByRef imgH) {
   imgH := FreeImage_GetHeight(hImage)
   imgW := FreeImage_GetWidth(hImage)
}

FreeImage_GetLine(hImage) {
; Returns the width of the bitmap in bytes.
   Return DllCall(getFIMfunc("GetLine"), "uptr", hImage, "uint")
} 

FreeImage_GetStride(hImage) {
; Returns the width of the bitmap in bytes, rounded to the next 32-bit boundary, also known as
; pitch or stride or scan width.
; In FreeImage each scanline starts at a 32-bit boundary for performance reasons.
; This function is essential when using low level pixel manipulation functions.
   Return FreeImage_GetPitch(hImage)
}

FreeImage_GetPitch(hImage) {
   Return DllCall(getFIMfunc("GetPitch"), "uptr", hImage, "uint")
}

FreeImage_GetDIBSize(hImage) {
; returns a value in bytes
   Return DllCall(getFIMfunc("GetDIBSize"), "uptr", hImage, "uint")
}

FreeImage_GetMemorySize(hImage) {
; returns a value in bytes
   Return DllCall(getFIMfunc("GetMemorySize"), "uptr", hImage, "uint")
}

FreeImage_GetPalette(hImage) {
   Return DllCall(getFIMfunc("GetPalette"), "uptr", hImage)
}

FreeImage_GetDPIresolution(hImage, ByRef dpiX, ByRef dpiY) {
   dpiX := FreeImage_GetDotsPerMeterX(hImage)
   dpiY := FreeImage_GetDotsPerMeterY(hImage)
}

FreeImage_GetDotsPerMeterX(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterX"), "uptr", hImage, "int")
}

FreeImage_GetDotsPerMeterY(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterY"), "uptr", hImage, "int")
}

FreeImage_SetDPIresolution(hImage, dpiX, dpiY) {
  FreeImage_SetDotsPerMeterX(hImage, dpiX)
  r := FreeImage_SetDotsPerMeterY(hImage, dpiY)
  Return r
}

FreeImage_SetDotsPerMeterX(hImage, dpiX) {
   Return DllCall(getFIMfunc("SetDotsPerMeterX"), "uptr", hImage, "uint", dpiX)
}

FreeImage_SetDotsPerMeterY(hImage, dpiY) {
   Return DllCall(getFIMfunc("SetDotsPerMeterY"), "uptr", hImage, "uint", dpiY)
}

FreeImage_GetInfoHeader(hImage) {
   Return DllCall(getFIMfunc("GetInfoHeader"), "uptr", hImage, "uptr")
}

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "uptr", hImage, "uptr")
}

FreeImage_GetColorType(hImage, humanReadable:=1) {
; FREE_IMAGE_COLOR_TYPE enumeration:
; 0 = MINISWHITE  - Monochrome bitmap (1-bit) : first palette entry is white. Palletised bitmap (4 or 8-bit) - the bitmap has an inverted greyscale palette
; 1 = MINISBLACK  - Monochrome bitmap (1-bit) : first palette entry is black. Palletised bitmap (4 or 8-bit) and single - channel non-standard bitmap: the bitmap has a greyscale palette
; 2 = RGB         - High-color bitmap (16, 24 or 32 bit), RGB16 or RGBF
; 3 = PALETTE     - Palettized bitmap (1, 4 or 8 bit)
; 4 = RGBALPHA    - High-color bitmap with an alpha channel (32 bit bitmap, RGBA16 or RGBAF)
; 5 = CMYK        - CMYK bitmap (32 bit only)

   Static ColorsTypes := {1:"MINISBLACK", 0:"MINISWHITE", 3:"PALETTIZED", 2:"RGB", 4:"RGBA", 5:"CMYK"}
   r := DllCall(getFIMfunc("GetColorType"), "uptr", hImage)
   If (ColorsTypes.HasKey(r) && humanReadable=1)
      r := ColorsTypes[r]

   Return r
}

FreeImage_GetRedMask(hImage) {
   Return DllCall(getFIMfunc("GetRedMask"), "uptr", hImage, "uint")
}

FreeImage_GetGreenMask(hImage) {
   Return DllCall(getFIMfunc("GetGreenMask"), "uptr", hImage, "uint")
}

FreeImage_GetBlueMask(hImage) {
   Return DllCall(getFIMfunc("GetBlueMask"), "uptr", hImage, "uint")
}

FreeImage_GetTransparencyCount(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyCount"), "uptr", hImage)
}

FreeImage_GetTransparencyTable(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyTable"), "uptr", hImage)
}

FreeImage_SetTransparencyTable(hImage, hTransTable, count:=256) {
   Return DllCall(getFIMfunc("SetTransparencyTable"), "uptr", hImage, "UintP", hTransTable, "Uint", count)
} ; Untested

FreeImage_SetTransparent(hImage, isEnabled) {
   Return DllCall(getFIMfunc("SetTransparent"), "uptr", hImage, "Int", isEnabled)
}

FreeImage_GetTransparentIndex(hImage) {
   Return DllCall(getFIMfunc("GetTransparentIndex"), "uptr", hImage)
}

FreeImage_SetTransparentIndex(hImage, index) {
   Return DllCall(getFIMfunc("SetTransparentIndex"), "uptr", hImage, "Int", index)
}

FreeImage_IsTransparent(hImage) {
   Return DllCall(getFIMfunc("IsTransparent"), "uptr", hImage)
}

FreeImage_HasPixels(hImage) {
   Return DllCall(getFIMfunc("HasPixels"), "uptr", hImage)
}

FreeImage_HasBackgroundColor(hImage) {
   Return DllCall(getFIMfunc("HasBackgroundColor"), "uptr", hImage)
}

FreeImage_GetBackgroundColor(hImage) {
   VarSetCapacity(RGBQUAD, 4, 0)
   RetValue := DllCall(getFIMfunc("GetBackgroundColor"), "uptr", hImage, "UInt", &RGBQUAD)
   If RetValue
      return NumGet(RGBQUAD, 2, "Uchar") "," NumGet(RGBQUAD, 1, "Uchar") "," NumGet(RGBQUAD, 0, "Uchar") "," NumGet(RGBQUAD, 3, "Uchar")
   else
      return RetValue
}

FreeImage_SetBackgroundColor(hImage, RGBArray:="255,255,255,0") {
   If (RGBArray!="")
   {
      RGBA := StrSplit(RGBArray, ",")
      VarSetCapacity(RGBQUAD, 4, 0)
      NumPut(RGBA[3], RGBQUAD, 0, "UChar")
      NumPut(RGBA[2], RGBQUAD, 1, "UChar")
      NumPut(RGBA[1], RGBQUAD, 2, "UChar")
      NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   } else RGBQUAD := 0
   Return DllCall(getFIMfunc("SetBackgroundColor"), "uptr", hImage, "UInt", &RGBQUAD)
}

FreeImage_FillBackground(hImage, RGBArray:="255,255,255,0", options:=1, applyAlpha:=0) {
; applyAlpha  - for 32-bits RGBA, sets the alpha channel to specified value, must be above 0.
; options     - it affect the color search process for palletized images.
;   FI_COLOR_IS_RGB_COLOR     = 0   // RGBQUAD color is a RGB color (contains no valid alpha channel)
;   FI_COLOR_IS_RGBA_COLOR    = 1   // RGBQUAD color is a RGBA color (contains a valid alpha channel)
;   FI_COLOR_FIND_EQUAL_COLOR = 2   // For palettized images: lookup equal RGB color from palette
;   FI_COLOR_ALPHA_IS_INDEX   = 4   // The color's rgbReserved member (alpha) contains the palette index to be used

   If (RGBArray!="")
   {
      RGBA := StrSplit(RGBArray, ",")
      VarSetCapacity(RGBQUAD, 4, 0)
      NumPut(RGBA[3], RGBQUAD, 0, "UChar")
      NumPut(RGBA[2], RGBQUAD, 1, "UChar")
      NumPut(RGBA[1], RGBQUAD, 2, "UChar")
      NumPut(RGBA[4], RGBQUAD, 3, "UChar")
      If (applyAlpha=-1)
         applyAlpha := RGBA[4]
   } else RGBQUAD := 0
   Return DllCall(getFIMfunc("FillBackground"), "uptr", hImage, "UInt", &RGBQUAD, "int", options, "int", applyAlpha)
}

; === File type functions ===
; missing functions: GetFileTypeFromHandle, GetFileTypeFromMemory,
; ValidateFromHandle and ValidateFromMemory.

FreeImage_GetFileType(ImgPath, humanReadable:=0) {
; the given ImgPath can be fictional / inexistent.
; returns FREE_IMAGE_FORMAT enumeration if humanReadable=0.

   Static fileTypes := {-1:"unknown", 0:"BMP", 1:"ICO", 2:"JPEG", 3:"JNG", 4:"KOALA", 5:"LBM", 5:"IFF", 6:"MNG", 7:"PBM", 8:"PBMRAW", 9:"PCD", 10:"PCX", 11:"PGM", 12:"PGMRAW", 13:"PNG", 14:"PPM", 15:"PPMRAW", 16:"RAS", 17:"TARGA", 18:"TIFF", 19:"WBMP", 20:"PSD", 21:"CUT", 22:"XBM", 23:"XPM", 24:"DDS", 25:"GIF", 26:"HDR", 27:"FAXG3", 28:"SGI", 29:"EXR", 30:"J2K", 31:"JP2", 32:"PFM", 33:"PICT", 34:"RAW", 35:"WEBP", 36:"JXR"}
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
   Return DllCall(getFIMfunc("FIFSupportsExportBPP"), "Int", FIF, "int", bpp)
}

FreeImage_FIFSupportsExportType(FIF, pixelsDataType) {
; FIF is the FREE_IMAGE_FORMAT enumeration
; see FreeImage_GetFileType()
; pixelsDataType is FREE_IMAGE_TYPE enumeration
; see FreeImage_GetImageType()
   Return DllCall(getFIMfunc("FIFSupportsExportType"), "Int", FIF, "int", pixelsDataType)
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
   Return DllCall(getFIMfunc("ValidateU"), "Int", FifFormat, "WStr", ImgPath, "Int", 0)
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

   Return DllCall(getFIMfunc("GetBits"), "uptr", hImage, "uptr")
}

FreeImage_GetScanLine(hImage, iScanline) { ; Base 0
; Returns a pointer to the start of the given scanline in the bitmap’s data-bits.
; It is up to you to interpret these bytes correctly, according to the results of
; FreeImage_GetBPP and FreeImage_GetImageType (see the following sample).
   Return DllCall(getFIMfunc("GetScanLine"), "uptr", hImage, "Int", iScanline, "uptr")
}

FreeImage_GetPixelIndex(hImage, xPos, yPos) {
; It works only with 1, 4 and 8 bit images.
   VarSetCapacity(IndexNum, 1, 0)
   RetValue := DllCall(getFIMfunc("GetPixelIndex"), "uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &IndexNum)
   If RetValue
      return NumGet(IndexNum, 0, "Uchar")
   else
      return RetValue
}

FreeImage_SetPixelIndex(hImage, xPos, yPos, nIndex) {
; It works only with 1, 4 and 8 bit images.
   VarSetCapacity(IndexNum, 1, 0)
   NumPut(nIndex, IndexNum, 0, "Uchar")
   Return DllCall(getFIMfunc("SetPixelIndex"), "uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &IndexNum)
}

FreeImage_GetPixelColor(hImage, xPos, yPos) {
; It works only with 16, 24 and 32 bit images.

   VarSetCapacity(RGBQUAD, 4, 0)
   RetValue := DllCall(getFIMfunc("GetPixelColor") , "uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &RGBQUAD)
   If RetValue
      return NumGet(RGBQUAD, 2, "Uchar") "," NumGet(RGBQUAD, 1, "Uchar") "," NumGet(RGBQUAD, 0, "Uchar") "," NumGet(RGBQUAD, 3, "Uchar")
   else
      return RetValue
}

FreeImage_SetPixelColor(hImage, xPos, yPos, RGBArray:="255,255,255,0") {
; It works only with 16, 24 and 32 bit images.
   RGBA := StrSplit(RGBArray, ",")
   VarSetCapacity(RGBQUAD, 4, 0)
   NumPut(RGBA[3], RGBQUAD, 0, "UChar")
   NumPut(RGBA[2], RGBQUAD, 1, "UChar")
   NumPut(RGBA[1], RGBQUAD, 2, "UChar")
   NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("SetPixelColor"), "uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &RGBQUAD)
}

; === Conversion functions ===
; missing functions: ColorQuantizeEx, ConvertToType

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

   Return DllCall(getFIMfunc("ConvertTo" MODE), "uptr", hImage, "uptr")
}

FreeImage_ConvertTo32Bits(hImage) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("ConvertTo32Bits"), "uptr", hImage, "uptr")
}

FreeImage_ConvertTo24Bits(hImage) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("ConvertTo24Bits"), "uptr", hImage, "uptr")
}

FreeImage_ConvertToRawBits(pBits, hImage, scan_width, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   ; thanks to TheArkive for the help
   r := DllCall(getFIMfunc("ConvertToRawBits"), "uptr", pBits, "uint", hImage, "Int", scan_width, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "int", topDown)
   Return r
}

FreeImage_ConvertFromRawBits(pBits, imgW, imgH, PitchStride, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   r := DllCall(getFIMfunc("ConvertFromRawBits"), "uptr", pBits, "Int", imgW, "Int", imgH, "uInt", PitchStride, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "int", topDown, "uptr")
   Return r
}

FreeImage_ConvertFromRawBitsEx(copySource, pBits, FimType, imgW, imgH, PitchStride, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   r := DllCall(getFIMfunc("ConvertFromRawBitsEx"), "int", copySource, "uptr", pBits, "int", FimType, "Int", imgW, "Int", imgH, "uInt", PitchStride, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "int", topDown, "uptr")
   Return r
}

FreeImage_ConvertToStandardType(hImage, bScaleLinear:=1) {
   Return DllCall(getFIMfunc("ConvertToStandardType"), "uptr", hImage, "int", bScaleLinear, "uptr")
}

FreeImage_ConvertToGreyscale(hImage) {
   ; hImage - input must be a standard type, from 1-bit to 32 bits image, or an UINT16
   Return DllCall(getFIMfunc("ConvertToGreyscale"), "uptr", hImage, "uptr")
}

FreeImage_ColorQuantize(hImage, quantizeAlgo:=0) {
   ; hImage - input must be a 24 or a 32 bits image
   ; quantizeAlgo:
      ; 0 = FIQ_WUQUANT  - Xiaolin Wu color quantization algorithm
      ; 1 = FIQ_NNQUANT  - NeuQuant neural-net quantization algorithm by Anthony Dekker (24-bit only)
      ; 2 = FIQ_LFPQUANT - Lossless Fast Pseudo-Quantization Algorithm by Carsten Klein
   ; the function returns an 8 bit image
   Return DllCall(getFIMfunc("ColorQuantize"), "uptr", hImage, "int", quantizeAlgo, "uptr")
}

FreeImage_Threshold(hImage, TT:=0) { ; TT: 0 - 255
   Return DllCall(getFIMfunc("Threshold"), "uptr", hImage, "int", TT, "uptr")
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

   Return DllCall(getFIMfunc("Dither"), "uptr", hImage, "int", ditherAlgo, "uptr")
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

   Return DllCall(getFIMfunc("ToneMapping"), "uptr", hImage, "int", algo, "Double", p1, "Double", p2, "uptr")
}

FreeImage_TmoDrago(hImage, gamma, exposure) {
   ; Converts a High Dynamic Range image to a 24-bit RGB image, suitable for display.
   ; function required to properly display HDR and RAW images

   ; parameters intervals and meaning 
   ; Adaptive logarithmic mapping (F. Drago, 2003)
         ; gamma = from 0.0 to 9.9
         ; exposure = from -8 to 8

   Return DllCall(getFIMfunc("TmoDrago03"), "uptr", hImage, "Double", gamma, "Double", exposure, "uptr")
}

; === ICC profile functions ===
; missing functions: CreateICCProfile and DestroyICCProfile.

FreeImage_GetICCProfile(hImage) {
   Return DllCall(getFIMfunc("GetICCProfile"), "uptr", hImage) ; returns a pointer to it
}

; === Plugin functions ===
; none implemented
; 21 functions available in the FreeImage Library

; === Multipage bitmap functions ===
; Missing functions: FreeImage_GetLockedPageNumbers()

FreeImage_OpenMultiBitmap(ImgPath, imgFormat, create_new:=0, read_only:=1, keep_cache:=1, flags:=0) {
; ImgPath    - file to open or create
; create_new - when this is 1, the file will be created; please make sure 
;              the folder path already exists and there is no already
;              existing file with the given name; FIM may crash if
;              it already exists; use read_only=0 as param
; keep_cache - keep in memory the cache

; to save a newly created multi-page image, use FreeImage_CloseMultiBitmap()

/*
imgFormat parameter takes integer values from 0 to 36
relevant I/O image format identifiers.
   FIF_ICO      = 1,
   FIF_TIFF     = 18,
   FIF_GIF      = 25,
   FIF_WEBP     = 35,
*/

   Return DllCall(getFIMfunc("OpenMultiBitmap"), "int", imgFormat, "AStr", ImgPath, "int", create_new, "int", read_only, "int", keep_cache, "int", flags, "uptr")
}

FreeImage_CloseMultiBitmap(hFIMULTIBITMAP, flags:=0) {
; If the multi-page image was opened with read_only=0, any modifications
; to the image will be saved to disk; do not use FreeImage_Save() to save a multi-page image.

   Return DllCall(getFIMfunc("CloseMultiBitmap"), "uptr", hFIMULTIBITMAP, "int", flags)
}

FreeImage_GetPageCount(hFIMULTIBITMAP) {
   Return DllCall(getFIMfunc("GetPageCount"), "uptr", hFIMULTIBITMAP)
}

FreeImage_SimpleGetPageCount(hImage) {
   r := DllCall(getFIMfunc("FreeImage_GetPageCount"), "uptr", hImage)
   If !r
      r := 1
   Return r
}

FreeImage_AppendPage(hFIMULTIBITMAP, hImage) {
   Return DllCall(getFIMfunc("AppendPage"), "uptr", hFIMULTIBITMAP, "uptr", hImage)
}

FreeImage_InsertPage(hFIMULTIBITMAP, PageNumber, hImage) {
   Return DllCall(getFIMfunc("InsertPage"), "uptr", hFIMULTIBITMAP, "Int", PageNumber, "uptr", hImage)
}

FreeImage_DeletePage(hFIMULTIBITMAP, PageNumber) {
   Return DllCall(getFIMfunc("DeletePage"), "uptr", hFIMULTIBITMAP, "Int", PageNumber)
}

FreeImage_MovePage(hFIMULTIBITMAP, Target, PageNumber) {
   ; Moves the source page to the position of the target page. Returns TRUE on success, FALSE on failure.
   Return DllCall(getFIMfunc("MovePage"), "uptr", hFIMULTIBITMAP, "Int", Target, "Int", PageNumber)
}

FreeImage_LockPage(hFIMULTIBITMAP, PageNumber) {
   ; Locks a page in memory for editing. The page can now be saved to a different file or inserted
   ; into another multi-page bitmap. When you are done with the bitmap you have to call
   ; FreeImage_UnlockPage to give the page back to the bitmap and/or apply any changes made
   ; in the page. It is forbidden to use FreeImage_Unload on a locked page: you must use
   ; FreeImage_UnlockPage() instead

   ; On succes, the function returns a common FIBITMAP.
   Return DllCall(getFIMfunc("LockPage"), "uptr", hFIMULTIBITMAP, "Int", PageNumber)
}

FreeImage_UnlockPage(hFIMULTIBITMAP, hImage, changed) {
   ; Unlocks a previously locked page and gives it back to the multi-page engine. When the last
   ; parameter is 1, the page is marked changed and the new page data is applied in the
   ; multi-page bitmap.

   Return DllCall(getFIMfunc("UnlockPage"), "uptr", hFIMULTIBITMAP, "uptr", hImage, "Int", changed)
}


; === Memory I/O functions ===
; missing functions: LoadFromMemory, ReadMemory, WriteMemory,
; LoadMultiBitmapFromMemory and SaveMultiBitmapFromMemory.

FreeImage_OpenMemory(hMemory, size) {
   Return DllCall(getFIMfunc("OpenMemory"), "int", hMemory, "int", size, "uptr")
} ; untested

FreeImage_CloseMemory(hMemory) {
   Return DllCall(getFIMfunc("CloseMemory"), "int", hMemory)
} ; untested

FreeImage_TellMemory(hMemory) {
   Return DllCall(getFIMfunc("TellMemory"), "int", hMemory)
} ; untested

FreeImage_SeekMemory(hMemory, offset, origin) {
   ; Moves the memory pointer to a specified location. A description of parameters follows:
   ; hMemory - Pointer to the target memory stream
   ; offset - Number of bytes from origin
   ; origin - Initial position
         ; 0 - SEEK_SET - Beginning of file.
         ; 1 - SEEK_CUR - Current position of file pointer.
         ; 2 - SEEK_END - End of file.
   ; The function returns TRUE if successful, returns FALSE otherwise

   Return DllCall(getFIMfunc("SeekMemory"), "int", hMemory, "int", offset, "int", origin)
} ; untested

FreeImage_AcquireMemory(hMemory, ByRef BufAdr, ByRef BufSize) {
   DataAddr := 0 , DataSizeAddr := 0
   bSucess := DllCall(getFIMfunc("AcquireMemory"), "int", hMemory, "Uint*", DataAddr, "Uint*", DataSizeAddr)
   BufAdr := NumGet(DataAddr, 0, "uint")
   BufSize := NumGet(DataSizeAddr, 0, "uint")
   Return bSucess
} ; untested

FreeImage_SaveToMemory(FIF, hImage, hMemory, Flags) {
; 0:BMP 2:JPG 13:PNG 18:TIF 25:GIF
   Return DllCall(getFIMfunc("SaveToMemory"), "int", FIF, "uptr", hImage, "int", hMemory, "int", Flags)
} ; untested

; === Compression functions ===
; none implemented
; 5 functions available in the FreeImage Library

; === Metadata functions ===
; 26 functions available in the FreeImage Library
; 17 functions implemented; 9 missing.

FreeImage_CreateTag() {
; Returns a new FITAG object. This object must be destroyed with a call to
; FreeImage_DeleteTag() when no longer required.

; Tag creation and destruction functions are only needed when you use the
; FreeImage_SetMetadata().
   Return DllCall(getFIMfunc("CreateTag"), "uptr")
}

FreeImage_CloneTag(fiTag) {
   Return DllCall(getFIMfunc("CloneTag"), "uptr", fiTag, "uptr")
}

FreeImage_DeleteTag(fiTag) {
   Return DllCall(getFIMfunc("DeleteTag"), "uptr", fiTag)
}

FreeImage_GetTagKey(fiTag) {
   Return DllCall(getFIMfunc("GetTagKey"), "uptr", fiTag, "astr")
}

FreeImage_GetTagLength(fiTag) {
   Return DllCall(getFIMfunc("GetTagLength"), "uptr", fiTag)
}

FreeImage_GetTagCount(fiTag) {
   Return DllCall(getFIMfunc("GetTagCount"), "uptr", fiTag)
}

FreeImage_GetTagType(fiTag) {
   Return DllCall(getFIMfunc("GetTagType"), "uptr", fiTag)
}

FreeImage_GetTagDescription(fiTag) {
   Return DllCall(getFIMfunc("GetTagDescription"), "uptr", fiTag, "astr")
}

FreeImage_SetTagKey(fiTag, key) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagKey"), "uptr", fiTag, "astr", key)
}

FreeImage_SetTagDescription(fiTag, desc) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagDescription"), "uptr", fiTag, "astr", desc)
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

   Return DllCall(getFIMfunc("SetTagType"), "uptr", fiTag, "int", mdType)
}

FreeImage_SetTagCount(fiTag, tCount) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagCount"), "uptr", fiTag, "int", tCount)
}

FreeImage_SetTagLength(fiTag, length) {
; Set the length of the tag value, in bytes (always required).
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagLength"), "uptr", fiTag, "int", length)
}

FreeImage_SetTagValue(fiTag, value) {
; The function returns TRUE if successful and returns FALSE otherwise.
   Return DllCall(getFIMfunc("SetTagValue"), "uptr", fiTag, "uint*", value)
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

   Return DllCall(getFIMfunc("SetMetadata"), "int", metaModel, "uptr", hImage, "astr", key, "uptr", fiTag)
}

FreeImage_CloneMetadata(srcImg, destImg) {
; Copy all metadata contained in src into dst, with the exception of FIMD_ANIMATION
; metadata (these metadata are not copied because this may cause problems when saving to
; GIF). When a src metadata model already exists in dst, the dst metadata model is first erased
; before copying the src one. When a metadata model already exists in dst and not in src, it is
; left untouched.
; Horizontal and vertical resolution info (returned by FreeImage_GetDotsPerMeterX and by
; FreeImage_GetDotsPerMeterY) is also copied from src to dst.
; The function returns TRUE on success and returns FALSE otherwise (e.g. when src or dst
; are invalid).

   Return DllCall(getFIMfunc("CloneMetadata"), "uptr", srcImg, "uptr", destImg)
}

FreeImage_GetMetadataCount(metaModel, hImage) {
; Returns the number of tags contained in the metadata model attached to the input hImage.
   Return DllCall(getFIMfunc("GetMetadataCount"), "int", metaModel, "uptr", hImage)
}


; === Toolkit functions ===
; 34 functions available in the FreeImage Library
; only 15 implemented

FreeImage_Rotate(hImage, angle) {
   ; missing color parameter
   ; returns a new hImage
   Return DllCall(getFIMfunc("Rotate"), "uptr", hImage, "Double", angle, "uptr")
}

FreeImage_FlipHorizontal(hImage) {
   ; returns 1 if success
   Return DllCall(getFIMfunc("FlipHorizontal"), "uptr", hImage)
}

FreeImage_FlipVertical(hImage) {
   ; returns 1 if success
   Return DllCall(getFIMfunc("FlipVertical"), "uptr", hImage)
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

   Return DllCall(getFIMfunc("Rescale"), "uptr", hImage, "Int", w, "Int", h, "Int", filter, "uptr")
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

   Return DllCall(getFIMfunc("RescaleRect"), "uptr", hImage, "Int", dstW, "Int", dstH, "Int", x, "Int", y, "Int", x + w, "Int", y + h, "Int", filter, "Int", flags, "uptr")
}

FreeImage_RescaleRawBits(srcBits, dstBits, FimType, imgW, imgH, srcStride, dstStride, BPP, dstW, dstH, filter) {
   Return FreeImage_RescaleRectRawBits(srcBits, dstBits, FimType, imgW, imgH, srcStride, dstStride, BPP, dstW, dstH, 0, 0, imgW, imgH, filter)
}

FreeImage_RescaleRectRawBits(srcBits, dstBits, FimType, imgW, imgH, srcStride, dstStride, BPP, dstW, dstH, srcX1, srcY1, srcX2, srcY2, filter) {
   r := DllCall(getFIMfunc("RescaleRawBits"), "uptr", srcBits, "uptr", dstBits, "Int", FimType, "Int", imgW, "Int", imgH, "uInt", srcStride, "uInt", dstStride, "Int", BPP, "Int", dstW, "Int", dstH, "Int", srcX1, "int", srcY1, "Int", srcX2, "int", srcY2, "int", filter)
   Return r
}

FreeImage_MakeThumbnail(hImage, squareSize, convert:=1) {
; Filter parameter options
; 0 = FILTER_BOX;        Box, pulse, Fourier window, 1st order (constant) B-Spline
; 1 = FILTER_BICUBIC;    Mitchell and Netravali's two-param cubic filter
; 2 = FILTER_BILINEAR;   Bilinear filter
; 3 = FILTER_BSPLINE;    4th order (cubic) B-Spline
; 4 = FILTER_CATMULLROM; Catmull-Rom spline, Overhauser spline
; 5 = FILTER_LANCZOS3;   Lanczos-windowed sinc filter

   Return DllCall(getFIMfunc("MakeThumbnail"), "uptr", hImage, "Int", squareSize, "Int", convert)
}

FreeImage_AdjustColors(hImage, bright, contrast, gamma, invert) {
; bright and contrast interval: [-100, 100]
; gamma interval: [0.0, 2.0]
; invert: 1 or 0
; return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("AdjustColors"), "uptr", hImage, "Double", bright, "Double", contrast, "Double", gamma, "Int", invert)
}

FreeImage_Crop(hImage, x, y, w, h) {
   Return FreeImage_Copy(hImage, x, y, x + w, y + h)
}

FreeImage_Copy(hImage, nLeft, nTop, nRight, nBottom) {
; use this function to crop images
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Copy"), "uptr", hImage, "int", nLeft, "int", nTop, "int", nRight, "int", nBottom, "uptr")
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

   Return DllCall(getFIMfunc("CreateView"), "uptr", hImage, "int", nLeft, "int", nTop, "int", nRight, "int", nBottom, "uptr")
}

FreeImage_Paste(hImageDst, hImageSrc, nLeft, nTop, nAlpha) {
   Return DllCall(getFIMfunc("Paste"), "uptr", hImageDst, "uptr", hImageSrc, "int", nLeft, "int", nTop, "int", nAlpha)
}

FreeImage_Composite(hImage, useFileBkg:=0, RGBArray:="255,255,255", hImageBkg:=0) {
   RGBA := StrSplit(RGBArray, ",")
   VarSetCapacity(RGBQUAD, 4, 0)
   NumPut(RGBA[3], RGBQUAD, 0, "UChar")
   NumPut(RGBA[2], RGBQUAD, 1, "UChar")
   NumPut(RGBA[1], RGBQUAD, 2, "UChar")
   NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("Composite"), "uptr", hImage, "int", useFileBkg, "Uint", &RGBQUAD, "uptr", hImageBkg, "uptr")
} ; untested

FreeImage_PreMultiplyWithAlpha(hImage) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("PreMultiplyWithAlpha"), "uptr", hImage)
}

FreeImage_Invert(hImage) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("Invert"), "uptr", hImage)
}

FreeImage_JPEGTransform(SrcImPath, DstImPath, ImgOperation) {
; ImgOperation parameter options:
; 0 = NONE                1 = Flip Horizontally
; 2 = Flip Vertically     3 = Transpose
; 4 = Transverse          5 = Rotate 90
; 6 = Rotate 180          7 = Rotate -90 [270]
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("JPEGTransformU"), "WStr", SrcImPath, "WStr", DstImPath, "int", ImgOperation)
}

FreeImage_JPEGCrop(SrcImgPath, DstImgPath, x1, y1, x2, y2) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("JPEGCropU"), "WStr", SrcImgPath, "WStr", DstImgPath, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2)
}

FreeImage_JPEGTransformCombined(SrcImgPath, DstImgPath, ImgOperation, x1, y1, x2, y2) {
   Return DllCall(getFIMfunc("JPEGTransformCombinedU"), "WStr", SrcImgPath, "WStr", DstImgPath, "Int*", ImgOperation, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2)
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

   Return DllCall(getFIMfunc("GetChannel"), "uptr", hImage, "Int", channel, "uptr")
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

   Return DllCall(getFIMfunc("SetChannel"), "uptr", hImage, "uptr", hImageGrey, "Int", channel)
}

getFIMfunc(funct) {
; for some crazy reason, in the 32 bits DLL of FreeImage
; each function name ends with a number preceded by @
; this function is meant to enable 32 bits compatibility

   Static fList0 := "|CreateTag|DeInitialise|GetCopyrightMessage|GetFIFCount|GetVersion|IsLittleEndian|"
        , fList4 := "|Clone|CloneTag|CloseMemory|ConvertTo16Bits555|ConvertTo16Bits565|ConvertTo24Bits|ConvertTo32Bits|ConvertTo4Bits|ConvertTo8Bits|ConvertToFloat|ConvertToGreyscale|ConvertToRGB16|ConvertToRGBA16|ConvertToRGBAF|ConvertToRGBF|ConvertToUINT16|DeleteTag|DestroyICCProfile|FIFSupportsICCProfiles|FIFSupportsNoPixels|FIFSupportsReading|FIFSupportsWriting|FindCloseMetadata|FlipHorizontal|FlipVertical|GetBits|GetBlueMask|GetBPP|GetColorsUsed|GetColorType|GetDIBSize|GetDotsPerMeterX|GetDotsPerMeterY|GetFIFDescription|GetFIFExtensionList|GetFIFFromFilename|GetFIFFromFilenameU|GetFIFFromFormat|GetFIFFromMime|GetFIFMimeType|GetFIFRegExpr|GetFormatFromFIF|GetGreenMask|GetHeight|GetICCProfile|GetImageType|GetInfo|GetInfoHeader|GetLine|GetMemorySize|GetPageCount|GetPalette|GetPitch|GetRedMask|GetTagCount|GetTagDescription|GetTagID|GetTagKey|GetTagLength|GetTagType|GetTagValue|GetThumbnail|GetTransparencyCount|GetTransparencyTable|GetTransparentIndex|GetWidth|HasBackgroundColor|HasPixels|HasRGBMasks|Initialise|Invert|IsPluginEnabled|IsTransparent|PreMultiplyWithAlpha|SetOutputMessage|SetOutputMessageStdCall|TellMemory|Unload|"
        , fList8 := "|AppendPage|CloneMetadata|CloseMultiBitmap|ColorQuantize|ConvertToStandardType|DeletePage|Dither|FIFSupportsExportBPP|FIFSupportsExportType|FindNextMetadata|GetBackgroundColor|GetChannel|GetComplexChannel|GetFileType|GetFileTypeFromMemory|GetFileTypeU|GetMetadataCount|GetScanLine|LockPage|MultigridPoissonSolver|OpenMemory|SetBackgroundColor|SetDotsPerMeterX|SetDotsPerMeterY|SetPluginEnabled|SetTagCount|SetTagDescription|SetTagID|SetTagKey|SetTagLength|SetTagType|SetTagValue|SetThumbnail|SetTransparent|SetTransparentIndex|Threshold|Validate|ValidateFromMemory|ValidateU|"
        , fList12 := "|AcquireMemory|AdjustBrightness|AdjustContrast|AdjustCurve|AdjustGamma|ConvertLine16_555_To16_565|ConvertLine16_565_To16_555|ConvertLine16To24_555|ConvertLine16To24_565|ConvertLine16To32_555|ConvertLine16To32_565|ConvertLine16To4_555|ConvertLine16To4_565|ConvertLine16To8_555|ConvertLine16To8_565|ConvertLine1To4|ConvertLine1To8|ConvertLine24To16_555|ConvertLine24To16_565|ConvertLine24To32|ConvertLine24To4|ConvertLine24To8|ConvertLine32To16_555|ConvertLine32To16_565|ConvertLine32To24|ConvertLine32To4|ConvertLine32To8|ConvertLine4To8|ConvertToType|CreateICCProfile|FillBackground|FindFirstMetadata|GetFileTypeFromHandle|GetHistogram|GetLockedPageNumbers|InsertPage|Load|LoadFromMemory|LoadMultiBitmapFromMemory|LoadU|MakeThumbnail|MovePage|SeekMemory|SetChannel|SetComplexChannel|SetTransparencyTable|SwapPaletteIndices|TagToString|UnlockPage|ValidateFromHandle|ZLibCRC32|"
        , fList16 := "|Composite|ConvertLine1To16_555|ConvertLine1To16_565|ConvertLine1To24|ConvertLine1To32|ConvertLine4To16_555|ConvertLine4To16_565|ConvertLine4To24|ConvertLine4To32|ConvertLine8To16_555|ConvertLine8To16_565|ConvertLine8To24|ConvertLine8To32|ConvertLine8To4|GetMetadata|GetPixelColor|GetPixelIndex|JPEGTransform|JPEGTransformU|LoadFromHandle|LookupSVGColor|LookupX11Color|OpenMultiBitmapFromHandle|ReadMemory|Rescale|Rotate|Save|SaveMultiBitmapToMemory|SaveToMemory|SaveU|SetMetadata|SetMetadataKeyValue|SetPixelColor|SetPixelIndex|SwapColors|WriteMemory|ZLibCompress|ZLibGUnzip|ZLibGZip|ZLibUncompress|"
        , fList20 := "|ApplyPaletteIndexMapping|ColorQuantizeEx|Copy|CreateView|Paste|RegisterExternalPlugin|RegisterLocalPlugin|SaveMultiBitmapToHandle|SaveToHandle|TmoDrago03|TmoFattal02|TmoReinhard05|"
        , fList24 := "|Allocate|ApplyColorMapping|ConvertLine1To32MapTransparency|ConvertLine4To32MapTransparency|ConvertLine8To32MapTransparency|JPEGCrop|JPEGCropU|OpenMultiBitmap|ToneMapping|"
        , fList28 := "|AllocateHeader|AllocateT|EnlargeCanvas|"
        , fList32 := "|AdjustColors|AllocateHeaderT|ConvertToRawBits|GetAdjustColorsLookupTable|JPEGTransformCombined|JPEGTransformCombinedFromMemory|JPEGTransformCombinedU|"
        , fList36 := "|AllocateEx|AllocateHeaderForBits|ConvertFromRawBits|RescaleRect|TmoReinhard05Ex|"

   fPrefix := (A_PtrSize=8) ? "FreeImage_" : "_FreeImage_"
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
   }
   funct := "FreeImage\" fPrefix funct fSuffix
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

ConvertPBITMAPtoFIM(pBitmap, do24bits:=0) {
; Please provide a 32 RGBA image format GDI+ object.
; To provide a 24-RGB image, use do24bits=1.
; This function relies on the GDI+ AHK library.
;
; If succesful, the function returns a FreeImage image object
; created from pBitmap [GDI+ image object].

  Static redMASK   := "0x00FF0000" ; FI_RGBA_RED_MASK;
       , greenMASK := "0x0000FF00" ; FI_RGBA_GREEN_MASK;
       , blueMASK  := "0x000000FF" ; FI_RGBA_BLUE_MASK;

  Gdip_GetImageDimensions(pBitmap, imgW, imgH)
  pixelFormat := (do24bits=1) ? "0x21808" : "0x26200A"
  bitsDepth := (do24bits=1) ? 24 : 32
  E := Gdip_LockBits(pBitmap, 0, 0, imgW, imgH, Stride, Scan0, BitmapData, 1, pixelFormat)
  ; fnOutputDebug(A_ThisFunc "|" pixelFormat "|" bitsDepth "|" do24bits)
  IF !E
  {
     hFIFimgA := FreeImage_ConvertFromRawBits(Scan0, imgW, imgH, Stride, bitsDepth, redMASK, greenMASK, blueMASK, 1)
     Gdip_UnlockBits(pBitmap, BitmapData)
     Gdip_BitmapGetDPIresolution(pBitmap, dpiX, dpiY)
     FreeImage_SetDPIresolution(hFIFimgA, dpiX, dpiY)
  }
  Return hFIFimgA
}
