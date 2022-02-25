; Last update on: vendredi 26 février 2021 by Marius Șucan
; Original Date: 2012-03-29
; Original Author: linpinger
; Original URL : http://www.autohotkey.net/~linpinger/index.html
; This version is available on Github: https://github.com/marius-sucan/Quick-Picto-Viewer

; Change log:
; =============================
; 26 February 2021 by Marius Șucan
; - implemented the multi-page functions

; 14 January 2021 by Marius Șucan
; - bug fixes - many thanks to TheArkive
;
; 30 June 2020 by Marius Șucan
; - Implemented additional functions.
;
; 21 September 2019 by Marius Șucan
; - Implemented additional functions.
;
; 11 August 2019 by Marius Șucan
; - Added ConvertFIMtoPBITMAP() and ConvertPBITMAPtoFIM() functions
; - Implemented 32 bits support for AHK_L 32 bits and FreeImage 32 bits.
; - FreeImage_Save() now relies on FreeImage_GetFIFFromFilename() to get the file format code
; - Bug fixes and more in-line comments/information
;
; 6 August 2019 by Marius Șucan
; - It now works with FreeImage v3.18 and AHK_L v1.1.30+.
; - Added many new functions and cleaned up the code. Fixed bugs.

FreeImage_FoxInit(isInit:=1) {
   Static hFIDll
   DllPath := FreeImage_FoxGetDllPath("freeimage.dll")
   If !DllPath
      Return "err - 404"

   If (isInit=1)
      hFIDll := DllCall("LoadLibraryW", "WStr", DllPath, "UPtr")
   Else
      DllCall("FreeLibrary", "UInt", hFIDll)

   ; ToolTip, % DllPath "`n" hFIDll , , , 2
   If (isInit=1 && !hFIDll)
      Return "err - " A_LastError

   Return hFIDll
}

FreeImage_FoxGetDllPath(DllName) {
   DirList := "|" A_WorkingDir "|" mainCompiledPath "|" A_scriptdir "|" A_scriptdir "\bin|" A_scriptdir "\lib|" mainCompiledPath "\lib|"
   DllPath := ""
   Loop, Parse, DirList, |
   {
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

FreeImage_GetCopyrightMessage() {
   Return DllCall(getFIMfunc("GetCopyrightMessage"), "AStr")
}

; === Bitmap management functions ===
; missing functions: AllocateT, LoadFromHandle, SaveToHandle

FreeImage_Allocate(width, height, bpp:=32, red_mask:=0xFF000000, green_mask:=0x00FF0000, blue_mask:=0x0000FF00) {
; function useful to create a new / empty bitmap
   Return DllCall(getFIMfunc("Allocate"), "int", width, "int", height, "int", bpp, "uint", red_mask, "uint", green_mask, "uint", blue_mask, "uptr")
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

   OutExt := FreeImage_GetFIFFromFilename(ImgPath)
   Return DllCall(getFIMfunc("SaveU"), "Int", OutExt, "Uptr", hImage, "WStr", ImgPath, "int", ImgArg)
}

FreeImage_Clone(hImage) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("Clone"), "Uptr", hImage, "uptr")
}

FreeImage_UnLoad(hImage) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("Unload"), "Uptr", hImage)
}

; === Bitmap information functions ===
; missing functions: GetThumbnail SetThumbnail

FreeImage_GetImageType(hImage, humanReadable:=0) {
; Possible return values:
; 0 = FIT_UNKNOWN ;   Unknown format (returned value only, never use it as input value for other functions)
; 1 = FIT_BITMAP ;   Standard image: 1-, 4-, 8-, 16-, 24-, 32-bit
; 2 = FIT_UINT16 ;   Array of unsigned short: unsigned 16-bit
; 3 = FIT_INT16 ;   Array of short: signed 16-bit
; 4 = FIT_UINT32 ;   Array of unsigned long: unsigned 32-bit
; 5 = FIT_INT32 ;   Array of long: signed 32-bit
; 6 = FIT_FLOAT ;   Array of float: 32-bit IEEE floating point
; 7 = FIT_DOUBLE ;   Array of double: 64-bit IEEE floating point
; 8 = FIT_COMPLEX ;   Array of FICOMPLEX: 2 x 64-bit IEEE floating point
; 9 = FIT_RGB16 ;   48-bit RGB image: 3 x unsigned 16-bit
; 10 = FIT_RGBA16 ;   64-bit RGBA image: 4 x unsigned 16-bit
; 11 = FIT_RGBF ;   96-bit RGB float image: 3 x 32-bit IEEE floating point
; 12 = FIT_RGBAF ;   128-bit RGBA float image: 4 x 32-bit IEEE floating point

   Static imgTypes := {0:"UNKNOWN", 1:"Standard Bitmap", 2:"UINT16", 3:"INT16", 4:"UINT32", 5:"INT32", 6:"FLOAT [32-bit]", 7:"DOUBLE [64-bit]", 8:"COMPLEX [2x64-bit]", 9:"RGB16 [48-bit]", 10:"RGBA16 [64-bit]", 11:"RGBF [96-bit]", 12:"RGBAF [128-bit]"}
   r := DllCall(getFIMfunc("GetImageType"), "Uptr", hImage)
   If (humanReadable=1 && imgTypes.HasKey(r))
      r := imgTypes[r]
   Return r
}

FreeImage_GetColorsUsed(hImage) {
   Return DllCall(getFIMfunc("GetColorsUsed"), "Uptr", hImage)
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
   E := DllCall(getFIMfunc("GetHistogram"), "Uptr", hImage, "ptr", &histo, "int", channel)
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
   Return DllCall(getFIMfunc("GetBPP"), "Uptr", hImage)
}

FreeImage_GetWidth(hImage) {
   Return DllCall(getFIMfunc("GetWidth"), "Uptr", hImage)
}

FreeImage_GetHeight(hImage) {
   Return DllCall(getFIMfunc("GetHeight"), "Uptr", hImage)
}

FreeImage_GetImageDimensions(hImage, ByRef imgW, ByRef imgH) {
   imgH := FreeImage_GetHeight(hImage)
   imgW := FreeImage_GetWidth(hImage)
}

FreeImage_GetLine(hImage) {
   Return DllCall(getFIMfunc("GetLine"), "Uptr", hImage, "uint")
} ; Untested 

FreeImage_GetPitch(hImage) {
   Return DllCall(getFIMfunc("GetPitch"), "Uptr", hImage, "uint")
}

FreeImage_GetDIBSize(hImage) {
   Return DllCall(getFIMfunc("GetDIBSize"), "Uptr", hImage, "uint")
} ; Untested

FreeImage_GetMemorySize(hImage) {
   Return DllCall(getFIMfunc("GetMemorySize"), "Uptr", hImage, "uint")
} ; Untested

FreeImage_GetPalette(hImage) {
   Return DllCall(getFIMfunc("GetPalette"), "Uptr", hImage)
}

FreeImage_GetDPIresolution(hImage, ByRef dpiX, ByRef dpiY) {
   dpiX := FreeImage_GetDotsPerMeterX(hImage)
   dpiY := FreeImage_GetDotsPerMeterY(hImage)
}

FreeImage_GetDotsPerMeterX(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterX"), "Uptr", hImage, "int")
}

FreeImage_GetDotsPerMeterY(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterY"), "Uptr", hImage, "int")
}

FreeImage_SetDotsPerMeterX(hImage, dpiX) {
   Return DllCall(getFIMfunc("SetDotsPerMeterX"), "Uptr", hImage, "uint", dpiX)
}

FreeImage_SetDotsPerMeterY(hImage, dpiY) {
   Return DllCall(getFIMfunc("SetDotsPerMeterY"), "Uptr", hImage, "uint", dpiX)
}

FreeImage_GetInfoHeader(hImage) {
   Return DllCall(getFIMfunc("GetInfoHeader"), "Uptr", hImage, "uptr")
}

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "Uptr", hImage, "uptr")
}

FreeImage_GetColorType(hImage, humanReadable:=1) {
; 0 = MINISWHITE  - Monochrome bitmap (1-bit) : first palette entry is white. Palletised bitmap (4 or 8-bit) - the bitmap has an inverted greyscale palette
; 1 = MINISBLACK - Monochrome bitmap (1-bit) : first palette entry is black. Palletised bitmap (4 or 8-bit) and single - channel non-standard bitmap: the bitmap has a greyscale palette
; 2 = RGB  - High-color bitmap (16, 24 or 32 bit), RGB16 or RGBF
; 3 = PALETTE - Palettized bitmap (1, 4 or 8 bit)
; 4 = RGBALPHA - High-color bitmap with an alpha channel (32 bit bitmap, RGBA16 or RGBAF)
; 5 = CMYK - CMYK bitmap (32 bit only)

   Static ColorsTypes := {1:"MINISBLACK", 0:"MINISWHITE", 3:"PALETTIZED", 2:"RGB", 4:"RGBA", 5:"CMYK"}
   r := DllCall(getFIMfunc("GetColorType"), "Uptr", hImage)
   If (ColorsTypes.HasKey(r) && humanReadable=1)
      r := ColorsTypes[r]

   Return r
}

FreeImage_GetRedMask(hImage) {
   Return DllCall(getFIMfunc("GetRedMask"), "Uptr", hImage, "uint")
}

FreeImage_GetGreenMask(hImage) {
   Return DllCall(getFIMfunc("GetGreenMask"), "Uptr", hImage, "uint")
}

FreeImage_GetBlueMask(hImage) {
   Return DllCall(getFIMfunc("GetBlueMask"), "Uptr", hImage, "uint")
}

FreeImage_GetTransparencyCount(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyCount"), "Uptr", hImage)
}

FreeImage_GetTransparencyTable(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyTable"), "Uptr", hImage)
}

FreeImage_SetTransparencyTable(hImage, hTransTable, count:=256) {
   Return DllCall(getFIMfunc("SetTransparencyTable"), "Uptr", hImage, "UintP", hTransTable, "Uint", count)
} ; Untested

FreeImage_SetTransparent(hImage, isEnabled) {
   Return DllCall(getFIMfunc("SetTransparent"), "Uptr", hImage, "Int", isEnabled)
}

FreeImage_GetTransparentIndex(hImage) {
   Return DllCall(getFIMfunc("GetTransparentIndex"), "Uptr", hImage)
}

FreeImage_SetTransparentIndex(hImage, index) {
   Return DllCall(getFIMfunc("SetTransparentIndex"), "Uptr", hImage, "Int", index)
}

FreeImage_IsTransparent(hImage) {
   Return DllCall(getFIMfunc("IsTransparent"), "Uptr", hImage)
}

FreeImage_HasPixels(hImage) {
   Return DllCall(getFIMfunc("HasPixels"), "Uptr", hImage)
}

FreeImage_HasBackgroundColor(hImage) {
   Return DllCall(getFIMfunc("HasBackgroundColor"), "Uptr", hImage)
}

FreeImage_GetBackgroundColor(hImage) {
   VarSetCapacity(RGBQUAD, 4, 0)
   RetValue := DllCall(getFIMfunc("GetBackgroundColor"), "Uptr", hImage, "UInt", &RGBQUAD)
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
   Return DllCall(getFIMfunc("SetBackgroundColor"), "Uptr", hImage, "UInt", &RGBQUAD)
}

; === File type functions ===
; missing functions: GetFileTypeFromHandle, GetFileTypeFromMemory,
; and ValidateFromHandle, ValidateFromMemory

FreeImage_GetFileType(ImgPath, humanReadable:=0) {
   Static fileTypes := {0:"BMP", 1:"ICO", 2:"JPEG", 3:"JNG", 4:"KOALA", 5:"LBM", 5:"IFF", 6:"MNG", 7:"PBM", 8:"PBMRAW", 9:"PCD", 10:"PCX", 11:"PGM", 12:"PGMRAW", 13:"PNG", 14:"PPM", 15:"PPMRAW", 16:"RAS", 17:"TARGA", 18:"TIFF", 19:"WBMP", 20:"PSD", 21:"CUT", 22:"XBM", 23:"XPM", 24:"DDS", 25:"GIF", 26:"HDR", 27:"FAXG3", 28:"SGI", 29:"EXR", 30:"J2K", 31:"JP2", 32:"PFM", 33:"PICT", 34:"RAW", 35:"WEBP", 36:"JXR"}
   r := DllCall(getFIMfunc("GetFileTypeU"), "WStr", ImgPath, "Int", 0)
   If (r=-1)
      r := FreeImage_GetFIFFromFilename(ImgPath)
   If (humanReadable=1 && fileTypes.HasKey(r))
      r := fileTypes[r]

   Return r
}

FreeImage_GetFIFFromFilename(ImgPath) {
   Return DllCall(getFIMfunc("GetFIFFromFilename"), "AStr", ImgPath)
}

FreeImage_Validate(ImgPath, FifFormat) {
   Return DllCall(getFIMfunc("ValidateU"), "Int", FifFormat, "WStr", ImgPath, "Int", 0)
}

; === Pixel access functions ===

FreeImage_GetBits(hImage) {
   Return DllCall(getFIMfunc("GetBits"), "Uptr", hImage, "uptr")
}

FreeImage_GetScanLine(hImage, iScanline) { ; Base 0
   Return DllCall(getFIMfunc("GetScanLine"), "Uptr", hImage, "Int", iScanline, "uptr")
}

FreeImage_GetPixelIndex(hImage, xPos, yPos) {
; It works only with 1, 4 and 8 bit images.
   VarSetCapacity(IndexNum, 1, 0)
   RetValue := DllCall(getFIMfunc("GetPixelIndex"), "Uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &IndexNum)
   If RetValue
      return NumGet(IndexNum, 0, "Uchar")
   else
      return RetValue
}

FreeImage_SetPixelIndex(hImage, xPos, yPos, nIndex) {
; It works only with 1, 4 and 8 bit images.
   VarSetCapacity(IndexNum, 1, 0)
   NumPut(nIndex, IndexNum, 0, "Uchar")
   Return DllCall(getFIMfunc("SetPixelIndex"), "Uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &IndexNum)
}

FreeImage_GetPixelColor(hImage, xPos, yPos) {
; It works only with 16, 24 and 32 bit images.

   VarSetCapacity(RGBQUAD, 4, 0)
   RetValue := DllCall(getFIMfunc("GetPixelColor") , "Uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &RGBQUAD)
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
   Return DllCall(getFIMfunc("SetPixelColor"), "Uptr", hImage, "Uint", xPos, "Uint", yPos, "Uint", &RGBQUAD)
}

; === Conversion functions ===
; missing functions: ColorQuantizeEx, ConvertToType,
; ConvertFromRawBitsEx

FreeImage_ConvertTo(hImage, MODE) {
; This is a wrapper for multiple FreeImage functions.
; Possible parameters for MODE: "4Bits", "8Bits", "16Bits555", "16Bits565", "24Bits",
; "32Bits", "Greyscale", "Float", "RGBF", "RGBAF", "UINT16", "RGB16", "RGBA16"
; ATTENTION: these are case sensitive!
   If !hImage
      Return

   If (mode="16bits")
      mode := "16Bits565"

   Return DllCall(getFIMfunc("ConvertTo" MODE), "Uptr", hImage, "uptr")
}

FreeImage_ConvertToRawBits(pBits, hImage, scan_width, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   ; thanks to TheArkive for the help
   r := DllCall(getFIMfunc("ConvertToRawBits"), "ptr", pBits, "uint", hImage, "Int", scan_width, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "int", topDown)
   Return r
}

FreeImage_ConvertFromRawBits(pBits, imgW, imgH, PitchStride, BPP, redMASK, greenMASK, blueMASK, topDown:=1) {
   r := DllCall(getFIMfunc("ConvertFromRawBits"), "ptr", pBits, "Int", imgW, "Int", imgH, "uInt", PitchStride, "Int", BPP, "uInt", redMASK, "uInt", greenMASK, "uInt", blueMASK, "int", topDown, "uptr")
   Return r
}

FreeImage_ConvertToStandardType(hImage, bScaleLinear:=1) {
   Return DllCall(getFIMfunc("ConvertToStandardType"), "Uptr", hImage, "int", bScaleLinear, "uptr")
}

FreeImage_ColorQuantize(hImage, quantizeAlgo:=0) {
; hImage - a 24 or 32 bits image
; quantizeAlgo:
   ; 0 = FIQ_WUQUANT - Xiaolin Wu color quantization algorithm
   ; 1 = FIQ_NNQUANT - NeuQuant neural-net quantization algorithm by Anthony Dekker (24-bit only)
   ; 2 = FIQ_LFPQUANT - Lossless Fast Pseudo-Quantization Algorithm by Carsten Klein
; it returns an 8 bit image
   Return DllCall(getFIMfunc("ColorQuantize"), "Uptr", hImage, "int", quantizeAlgo, "uptr")
}

FreeImage_Threshold(hImage, TT:=0) { ; TT: 0 - 255
   Return DllCall(getFIMfunc("Threshold"), "Uptr", hImage, "int", TT, "uptr")
}

FreeImage_Dither(hImage, ditherAlgo:=0) {
; ditherAlgo parameter: dithering method
; FID_FS           = 0   //! Floyd & Steinberg error diffusion
; FID_BAYER4x4     = 1   //! Bayer ordered dispersed dot dithering (order 2 dithering matrix)
; FID_BAYER8x8     = 2   //! Bayer ordered dispersed dot dithering (order 3 dithering matrix)
; FID_CLUSTER6x6   = 3   //! Ordered clustered dot dithering (order 3 - 6x6 matrix)
; FID_CLUSTER8x8   = 4   //! Ordered clustered dot dithering (order 4 - 8x8 matrix)
; FID_CLUSTER16x16 = 5   //! Ordered clustered dot dithering (order 8 - 16x16 matrix)
; FID_BAYER16x16   = 6   //! Bayer ordered dispersed dot dithering (order 4 dithering matrix)
; it returns an 1-bit image

   Return DllCall(getFIMfunc("Dither"), "Uptr", hImage, "int", ditherAlgo, "uptr")
}

FreeImage_ToneMapping(hImage, algo:=0, p1:=0, p2:=0) {
; Converts a High Dynamic Range image (48-bit RGB or 96-bit RGBF) to a 24-bit RGB image, suitable for display.
; function required to display HDR and RAW images

; algo parameter and p1/p2 intervals and meaning 
; 0 = FITMO_DRAGO03    ; Adaptive logarithmic mapping (F. Drago, 2003)
      ; p1 = gamma [0.0, 9.9]; p2 = exposure [-8, 8]
; 1 = FITMO_REINHARD05 ; Dynamic range reduction inspired by photoreceptor physiology (E. Reinhard, 2005)
      ; p1 = intensity [-8, 8]; p2 = contrast [0.3, 1.0]
; 2 = FITMO_FATTAL02   ; Gradient domain High Dynamic Range compression (R. Fattal, 2002)
      ; p1 = saturation [0.4, 0.6]; p2 = attenuation [0.8, 0.9]

   Return DllCall(getFIMfunc("ToneMapping"), "Uptr", hImage, "int", algo, "Double", p1, "Double", p2, "uptr")
}

; === ICC profile functions ===
; missing functions: CreateICCProfile, DestroyICCProfile
FreeImage_GetICCProfile(hImage) {
   Return DllCall(getFIMfunc("GetICCProfile"), "Uptr", hImage) ; returns a pointer to it
}

; === Plugin functions ===
; none implemented
; 21 functions available in the FreeImage Library

; === Multipage bitmap functions ===
; Missing functions: FreeImage_GetLockedPageNumbers()

FreeImage_OpenMultiBitmap(ImgPath, imgFormat, create_new:=0, read_only:=1, keep_cache:=1, flags:=0) {
   Return DllCall(getFIMfunc("OpenMultiBitmap"), "int", imgFormat, "aStr", ImgPath, "int", create_new, "int", read_only, "int", keep_cache, "int", flags, "uptr")
}

FreeImage_CloseMultiBitmap(hFIMULTIBITMAP, flags:=0) {
   Return DllCall(getFIMfunc("CloseMultiBitmap"), "UPtr", hFIMULTIBITMAP, "int", flags)
}

FreeImage_GetPageCount(hFIMULTIBITMAP) {
   Return DllCall(getFIMfunc("GetPageCount"), "UPtr", hFIMULTIBITMAP)
}

FreeImage_SimpleGetPageCount(hImage) {
   r := DllCall(getFIMfunc("FreeImage_GetPageCount"), "UPtr", hImage)
   If !r
      r := 1
   Return r
}

FreeImage_AppendPage(hFIMULTIBITMAP, hImage) {
   Return DllCall(getFIMfunc("AppendPage"), "UPtr", hFIMULTIBITMAP, "UPtr", hImage)
}

FreeImage_InsertPage(hFIMULTIBITMAP, PageNumber, hImage) {
   Return DllCall(getFIMfunc("InsertPage"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber, "UPtr", hImage)
}

FreeImage_DeletePage(hFIMULTIBITMAP, PageNumber) {
   Return DllCall(getFIMfunc("DeletePage"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber)
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
   ; FreeImage_UnlockPage instead

   ; On succes, the function returns a common FIBITMAP.
   Return DllCall(getFIMfunc("LockPage"), "UPtr", hFIMULTIBITMAP, "Int", PageNumber)
}

FreeImage_UnlockPage(hFIMULTIBITMAP, hImage, changed) {
   ; Unlocks a previously locked page and gives it back to the multi-page engine. When the last
   ; parameter is TRUE, the page is marked changed and the new page data is applied in the
   ; multi-page bitmap.

   Return DllCall(getFIMfunc("UnlockPage"), "UPtr", hFIMULTIBITMAP, "UPtr", hImage, "Int", changed)
}


; === Memory I/O functions ===
; missing functions: LoadFromMemory, ReadMemory, WriteMemory,
; LoadMultiBitmapFromMemory, SaveMultiBitmapFromMemory

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

FreeImage_SaveToMemory(FIF, hImage, hMemory, Flags) { ; 0:BMP 2:JPG 13:PNG 18:TIF 25:GIF
   Return DllCall(getFIMfunc("SaveToMemory"), "int", FIF, "Uptr", hImage, "int", hMemory, "int", Flags)
} ; untested

; === Compression functions ===
; none implemented
; 5 functions available in the FreeImage Library

; === Metadata functions ===
; none implemented
; 26 functions available in the FreeImage Library

; === Toolkit functions ===
; 34 functions available in the FreeImage Library
; only 15 implemented

FreeImage_Rotate(hImage, angle) {
   ; missing color parameter
   ; returns a new hImage
   Return DllCall(getFIMfunc("Rotate"), "Uptr", hImage, "Double", angle, "uptr")
}

FreeImage_FlipHorizontal(hImage) {
   ; returns 1 if success
   Return DllCall(getFIMfunc("FlipHorizontal"), "Uptr", hImage)
}

FreeImage_FlipVertical(hImage) {
   ; returns 1 if success
   Return DllCall(getFIMfunc("FlipVertical"), "Uptr", hImage)
}

FreeImage_Rescale(hImage, w, h, filter:=3) {
; Filter parameter options
; 0 = FILTER_BOX;        Box, pulse, Fourier window, 1st order (constant) B-Spline
; 1 = FILTER_BICUBIC;    Mitchell and Netravali's two-param cubic filter
; 2 = FILTER_BILINEAR;   Bilinear filter
; 3 = FILTER_BSPLINE;    4th order (cubic) B-Spline
; 4 = FILTER_CATMULLROM; Catmull-Rom spline, Overhauser spline
; 5 = FILTER_LANCZOS3;   Lanczos-windowed sinc filter
   If !hImage
      Return

   Return DllCall(getFIMfunc("Rescale"), "Uptr", hImage, "Int", w, "Int", h, "Int", filter, "uptr")
}

FreeImage_MakeThumbnail(hImage, squareSize, convert:=1) {
; Filter parameter options
; 0 = FILTER_BOX;        Box, pulse, Fourier window, 1st order (constant) B-Spline
; 1 = FILTER_BICUBIC;    Mitchell and Netravali's two-param cubic filter
; 2 = FILTER_BILINEAR;   Bilinear filter
; 3 = FILTER_BSPLINE;    4th order (cubic) B-Spline
; 4 = FILTER_CATMULLROM; Catmull-Rom spline, Overhauser spline
; 5 = FILTER_LANCZOS3;   Lanczos-windowed sinc filter

   Return DllCall(getFIMfunc("MakeThumbnail"), "Uptr", hImage, "Int", squareSize, "Int", convert)
}

FreeImage_AdjustColors(hImage, bright, contrast, gamma, invert) {
; bright and contrast interval: [-100, 100]
; gamma interval: [0.0, 2.0]
; invert: 1 or 0
; return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("AdjustColors"), "Uptr", hImage, "Double", bright, "Double", contrast, "Double", gamma, "Int", invert)
}

FreeImage_Copy(hImage, nLeft, nTop, nRight, nBottom) {
   If !hImage
      Return

   Return DllCall(getFIMfunc("Copy"), "Uptr", hImage, "int", nLeft, "int", nTop, "int", nRight, "int", nBottom, "uptr")
}

FreeImage_Paste(hImageDst, hImageSrc, nLeft, nTop, nAlpha) {
   Return DllCall(getFIMfunc("Paste"), "Uptr", hImageDst, "Uptr", hImageSrc, "int", nLeft, "int", nTop, "int", nAlpha)
}

FreeImage_Composite(hImage, useFileBkg:=0, RGBArray:="255,255,255", hImageBkg:=0) {
   RGBA := StrSplit(RGBArray, ",")
   VarSetCapacity(RGBQUAD, 4, 0)
   NumPut(RGBA[3], RGBQUAD, 0, "UChar")
   NumPut(RGBA[2], RGBQUAD, 1, "UChar")
   NumPut(RGBA[1], RGBQUAD, 2, "UChar")
   NumPut(RGBA[4], RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("Composite"), "Uptr", hImage, "int", useFileBkg, "Uint", &RGBQUAD, "Uptr", hImageBkg, "uptr")
}

FreeImage_PreMultiplyWithAlpha(hImage) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("PreMultiplyWithAlpha"), "Uptr", hImage)
}

FreeImage_Invert(hImage) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("Invert"), "Uptr", hImage)
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

   Return DllCall(getFIMfunc("GetChannel"), "Uptr", hImage, "Int", channel, "uptr")
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

   Return DllCall(getFIMfunc("SetChannel"), "Uptr", hImage, "Uptr", hImageGrey, "Int", channel)
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

ConvertFIMtoPBITMAP(hFIFimgA) {
; hFIFimgA - provide a 32 bits Standard RGBA FBITMAP.
; this function relies on GDI+ AHK library 
; If succesful, the function returns a 32-bit RGBA pBitmap.

  FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
  Pitch := FreeImage_GetPitch(hFIFimgA)
  pBitmap := Gdip_CreateBitmap(imgW, imgH, "0xE200B")
  redMASK := FreeImage_GetRedMask(hFIFimgA)
  greenMASK := FreeImage_GetGreenMask(hFIFimgA)
  blueMASK := FreeImage_GetBlueMask(hFIFimgA)
  E := Gdip_LockBits(pBitmap, 0, 0, imgW, imgH, Stride, Scan0, BitmapData)
  R := FreeImage_ConvertToRawBits(Scan0, hFIFimgA, pitch, 32, redMASK, greenMASK, blueMASK, 1)
  Gdip_UnlockBits(pBitmap, BitmapData)
  FreeImage_GetDPIresolution(hFIFimgA, dpiX, dpiY)
  Gdip_BitmapSetResolution(pBitmap, dpiX, dpiY)
  Return pBitmap
}

ConvertPBITMAPtoFIM(pBitmap) {
; please provide a 32 RGBA image format GDI+ object.
; this function relies on GDI+ AHK library 

   Static redMASK := "0x00FF0000" ; FI_RGBA_RED_MASK;
        , greenMASK := "0x0000FF00" ; FI_RGBA_GREEN_MASK;
        , blueMASK := "0x000000FF" ; FI_RGBA_BLUE_MASK;

  Gdip_GetImageDimensions(pBitmap, imgW, imgH)
  E := Gdip_LockBits(pBitmap, 0, 0, imgW, imgH, Stride, Scan0, BitmapData)
  hFIFimgA := FreeImage_ConvertFromRawBits(Scan0, imgW, imgH, Stride, 32, redMASK, greenMASK, blueMASK, 1)
  Gdip_UnlockBits(pBitmap, BitmapData)
  Gdip_BitmapGetDPIresolution(pBitmap, dpiX, dpiY)
  FreeImage_SetDotsPerMeterX(hFIFimgA, dpiX)
  FreeImage_SetDotsPerMeterY(hFIFimgA, dpiY)
  Return hFIFimgA
}

/*
   ; inspiration for adding multi-paged bitmaps support
   public void SelectActiveFrame(int frameIndex)
   {
      EnsureNotDisposed();
      if ((frameIndex < 0) || (frameIndex >= frameCount))
      {
         throw new ArgumentOutOfRangeException("frameIndex");
      }

      if (frameIndex != this.frameIndex)
      {
         if (stream == null)
         {
            throw new InvalidOperationException("No source available.");
         }

         FREE_IMAGE_FORMAT format = originalFormat;
         FIMULTIBITMAP mdib = FreeImage.OpenMultiBitmapFromStream(stream, ref format, saveInformation.loadFlags);
         if (mdib.IsNull)
            throw new Exception(ErrorLoadingBitmap);

         try
         {
            if (frameIndex >= FreeImage.GetPageCount(mdib))
            {
               throw new ArgumentOutOfRangeException("frameIndex");
            }

            FIBITMAP newDib = FreeImage.LockPage(mdib, frameIndex);
            if (newDib.IsNull)
            {
               throw new Exception(ErrorLoadingFrame);
            }

            try
            {
               FIBITMAP clone = FreeImage.Clone(newDib);
               if (clone.IsNull)
               {
                  throw new Exception(ErrorCreatingBitmap);
               }
               ReplaceDib(clone);
            }
            finally
            {
               if (!newDib.IsNull)
               {
                  FreeImage.UnlockPage(mdib, newDib, false);
               }
            }
         }
         finally
         {
            if (!FreeImage.CloseMultiBitmapEx(ref mdib))
            {
               throw new Exception(ErrorUnloadBitmap);
            }
         }

         this.frameIndex = frameIndex;
      }
   }
*/
