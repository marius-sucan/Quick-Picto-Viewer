﻿; Original Date: 2012-3-29
; Original Author: linpinger
; Original URL : http://www.autohotkey.net/~linpinger/index.html
; This version available on Github: https://github.com/marius-sucan/Quick-Picto-Viewer

; Change log:
; =============================
; 11th of August 2019
; - Added ConvertFIMtoPBITMAP() and ConvertPBITMAPtoFIM() functions
; - Implemented 32 bits support for AHK_L 32 bits and FreeImage 32 bits.
; - FreeImage_Save() now relies on FreeImage_GetFIFFromFilename() to get the file format code
; - Bug fixes and more in-line comments/information
;
; 6th of August 2019 by Marius Șucan
; - It now works with FreeImage v3.18 and AHK_L v1.1.30.
; - Added many new functions and cleaned up the code. Fixed bugs.

FreeImage_FoxInit(isInit:=1) {
   Static hFIDll
   DllPath := FreeImage_FoxGetDllPath()
   If !DllPath
      Return "err - 404"

   If (isInit=1)
      hFIDll := DllCall("LoadLibraryW", "WStr", DllPath, "UPtr")
   Else
      DllCall("FreeLibrary", "UInt", hFIDll)

   If (isInit=1 && !hFIDll)
      Return "err - " A_LastError

   Return hFIDll
}

FreeImage_FoxGetDllPath(DllName:="FreeImage.dll") {
   DirList := "|" A_WorkingDir "|" mainCompiledPath "|" A_scriptdir "|" A_scriptdir "\bin32|" A_scriptdir "\lib|"
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
   FreeImage_FoxSetRGBi(hPalette, 71, "R", 255) , FreeImage_FoxSetRGBi(hPalette, 71, "G", 255) , FreeImage_FoxSetRGBi(hPalette, 71, "B", 255)
}

FreeImage_FoxGetTransIndexNum(hImage) {
   ; Mark Num 1 For the first Color, not 0
   hPalette := FreeImage_GetPalette(hImage)
   loop, 256 
      If ( FreeImage_FoxGetRGBi(hPalette, A_index, "G") >= 254 and FreeImage_FoxGetRGBi(hPalette, A_index, "R") < 254 and FreeImage_FoxGetRGBi(hPalette, A_index, "B") < 254 )
         return, A_index
}

FreeImage_FoxGetPallete(hImage) { ; GetPaletteList
   hPalette := FreeImage_GetPalette(hImage)
   loop, 256
      PalleteList .= FreeImage_FoxGetRGBi(hPalette, A_index, "R") . " "
         . FreeImage_FoxGetRGBi(hPalette, A_index, "G") . " "
         . FreeImage_FoxGetRGBi(hPalette, A_index, "B") . " "
         . FreeImage_FoxGetRGBi(hPalette, A_index, "i") . "`n"
   return, PalleteList
}

FreeImage_FoxGetRGBi(StartAdress=2222, ColorIndexNum=1, GetColor="R") {
   If ( GetColor = "R" )
      return, Numget(StartAdress+0, 4*(ColorIndexNum-1)+0, "Uchar")
   If ( GetColor = "G" )
      return, Numget(StartAdress+0, 4*(ColorIndexNum-1)+1, "Uchar")
   If ( GetColor = "B" )
      return, Numget(StartAdress+0, 4*(ColorIndexNum-1)+2, "Uchar")
   If ( GetColor = "i" ) ; RGB or BGR 
      return, Numget(StartAdress+0, 4*(ColorIndexNum-1)+3, "Uchar")
}

FreeImage_FoxSetRGBi(StartAdress=2222, ColorIndexNum=1, SetColor="R", Value=255) {
   If ( SetColor = "R" )
      NumPut(Value, StartAdress+0, 4*(ColorIndexNum-1)+0, "Uchar")
   If ( SetColor = "G" )
      NumPut(Value, StartAdress+0, 4*(ColorIndexNum-1)+1, "Uchar")
   If ( SetColor = "B" )
      NumPut(Value, StartAdress+0, 4*(ColorIndexNum-1)+2, "Uchar")
   If ( SetColor = "i" )
      NumPut(Value, StartAdress+0, 4*(ColorIndexNum-1)+3, "Uchar")
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

FreeImage_Allocate(width, height, bpp=32, red_mask=0xFF000000, green_mask=0x00FF0000, blue_mask=0x0000FF00) {
; function useful to create a new / empty bitmap
   Return DllCall(getFIMfunc("Allocate"), "int", width, "int", height, "int", bpp, "uint", red_mask, "uint", green_mask, "uint", blue_mask)
}

FreeImage_Load(ImPath, GFT:=-1, flag:=0, ByRef dGFT:=0) {
   If (GFT=-1 || GFT="")
      dGFT := GFT := FreeImage_GetFileType(ImPath)
   Return DllCall(getFIMfunc("LoadU"), "Int", GFT, "WStr", ImPath, "int", flag)
}

FreeImage_Save(hImage, ImPath, ImgArg=0) {
   ; FIMfrmt := {"BMP":0, "JPG":2, "JPEG":2, "PNG":13, "TIF":18, "TIFF":18, "GIF":25}
   OutExt := FreeImage_GetFIFFromFilename(ImPath)
   Return DllCall(getFIMfunc("SaveU"), "Int", OutExt, "Int", hImage, "WStr", ImPath, "int", ImgArg)
}

FreeImage_Clone(hImage) {
   Return DllCall(getFIMfunc("Clone"), "int", hImage)
}

FreeImage_UnLoad(hImage) {
   Return DllCall(getFIMfunc("Unload"), "Int", hImage)
}

; === Bitmap information functions ===
; missing functions: GetThumbnail SetThumbnail

FreeImage_GetImageType(hImage) {
   Return DllCall(getFIMfunc("GetImageType"), "int", hImage)
}

FreeImage_GetColorsUsed(hImage) {
   Return DllCall(getFIMfunc("GetColorsUsed"), "int", hImage)
}

FreeImage_GetBPP(hImage) {
   Return DllCall(getFIMfunc("GetBPP"), "int", hImage)
}

FreeImage_GetWidth(hImage) {
   Return DllCall(getFIMfunc("GetWidth"), "Int", hImage)
}

FreeImage_GetHeight(hImage) {
   Return DllCall(getFIMfunc("GetHeight"), "Int", hImage)
}

FreeImage_GetLine(hImage) {
   Return DllCall(getFIMfunc("GetLine"), "Int", hImage)
} ; Untested 

FreeImage_GetPitch(hImage) {
   Return DllCall(getFIMfunc("GetPitch"), "Int", hImage)
}

FreeImage_GetDIBSize(hImage) {
   Return DllCall(getFIMfunc("GetDIBSize"), "Int", hImage)
} ; Untested

FreeImage_GetMemorySize(hImage) {
   Return DllCall(getFIMfunc("GetMemorySize"), "Int", hImage)
} ; Untested

FreeImage_GetPalette(hImage) {
   Return DllCall(getFIMfunc("GetPalette"), "Int", hImage)
}

FreeImage_GetDotsPerMeterX(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterX"), "Int", hImage)
}

FreeImage_GetDotsPerMeterY(hImage) {
   Return DllCall(getFIMfunc("GetDotsPerMeterY"), "Int", hImage)
}

FreeImage_SetDotsPerMeterX(hImage, DPMx) {
   Return DllCall(getFIMfunc("SetDotsPerMeterX"), "Int", hImage)
}

FreeImage_SetDotsPerMeterY(hImage, DPMy) {
   Return DllCall(getFIMfunc("SetDotsPerMeterY"), "Int", hImage)
}

FreeImage_GetInfoHeader(hImage) {
   Return DllCall(getFIMfunc("GetInfoHeader"), "Int", hImage)
}

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "Int", hImage)
}

FreeImage_GetColorType(hImage) {
   Return DllCall(getFIMfunc("GetColorType"), "Int", hImage)
}

FreeImage_GetRedMask(hImage) {
   Return DllCall(getFIMfunc("GetRedMask"), "Int", hImage)
}

FreeImage_GetGreenMask(hImage) {
   Return DllCall(getFIMfunc("GetGreenMask"), "Int", hImage)
}

FreeImage_GetBlueMask(hImage) {
   Return DllCall(getFIMfunc("GetBlueMask"), "Int", hImage)
}

FreeImage_GetTransparencyCount(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyCount"), "Int", hImage)
}

FreeImage_GetTransparencyTable(hImage) {
   Return DllCall(getFIMfunc("GetTransparencyTable"), "Int", hImage)
}

FreeImage_SetTransparencyTable(hImage, hTransTable, count=256) {
   Return DllCall(getFIMfunc("SetTransparencyTable"), "Int", hImage, "UintP", hTransTable, "Uint", count)
} ; Untested

FreeImage_SetTransparent(hImage, isEnable=1) {
   Return DllCall(getFIMfunc("SetTransparent"), "Int", hImage, "Int", isEnable)
}

FreeImage_GetTransparentIndex(hImage) {
   Return DllCall(getFIMfunc("GetTransparentIndex"), "Int", hImage)
}

FreeImage_SetTransparentIndex(hImage, index) {
   Return DllCall(getFIMfunc("SetTransparentIndex"), "Int", hImage, "Int", index)
}

FreeImage_IsTransparent(hImage) {
   Return DllCall(getFIMfunc("IsTransparent"), "Int", hImage)
}

FreeImage_HasPixels(hImage) {
   Return DllCall(getFIMfunc("HasPixels"), "Int", hImage)
}

FreeImage_HasBackgroundColor(hImage) {
   Return DllCall(getFIMfunc("HasBackgroundColor"), "Int", hImage)
}

FreeImage_GetBackgroundColor(hImage) {
   VarSetCapacity(RGB, 4)
   RetValue := DllCall(getFIMfunc("GetBackgroundColor"), "Int", hImage, "UInt", &RGB)
   If RetValue
      return, NumGet(RGB, 0, "UChar") . ":" . NumGet(RGB, 1, "UChar") . ":" . NumGet(RGB, 2, "UChar") . ":" . NumGet(RGB, 3, "UChar")
   else
      return, RetValue
}

FreeImage_SetBackgroundColor(hImage, RGBArray="255:255:255:0") {
   If ( RGBArray != "" ) {
      StringSplit, RGBA_, RGBArray, :, %A_space%
      VarSetCapacity(RGB, 4)
      NumPut(RGBA_1, RGB, 0, "UChar") , NumPut(RGBA_2, RGB, 1, "UChar") , NumPut(RGBA_3, RGB, 2, "UChar") , NumPut(RGBA_4, RGB, 3, "UChar")
   } else
      RGB := 0
   Return DllCall(getFIMfunc("SetBackgroundColor"), "Int", hImage, "UInt", &RGB)
}

; === File type functions ===
; missing functions: GetFileTypeFromHandle, GetFileTypeFromMemory,
; and ValidateFromHandle, ValidateFromMemory

FreeImage_GetFileType(ImPath) {  ; 0:BMP 2:JPG 13:PNG 18:TIF 25:GIF
   r := DllCall(getFIMfunc("GetFileTypeU"), "WStr", ImPath, "Int", 0)
   If (r=-1)
      r := FreeImage_GetFIFFromFilename(ImPath)
   Return r
}

FreeImage_GetFIFFromFilename(file) {
   Return DllCall(getFIMfunc("GetFIFFromFilename"), "AStr", file)
}

FreeImage_Validate(ImPath, FifFormat) {
   Return DllCall(getFIMfunc("ValidateU"), "Int", FifFormat, "WStr", ImPath, "Int", 0)
}

; === Pixel access functions ===

FreeImage_GetBits(hImage) {
   Return DllCall(getFIMfunc("GetBits"), "Int", hImage)
}

FreeImage_GetScanLine(hImage, iScanline) { ; Base 0
   Return DllCall(getFIMfunc("GetScanLine"), "Int", hImage, "Int", iScanline)
}

FreeImage_GetPixelIndex(hImage, xPos, yPos) { ; Base 0
   VarSetCapacity(IndexNum, 1)
   RetValue := DllCall(getFIMfunc("GetPixelIndex"), "int", hImage, "Uint", xPos, "Uint", yPos, "Uint", &IndexNum)
   If RetValue
      return, Numget(IndexNum, 0, "Uchar")
   else
      return, RetValue
}

FreeImage_SetPixelIndex(hImage, xPos, yPos, nIndex) {
   VarSetCapacity(IndexNum, 1)
   NumPut(nIndex, IndexNum, 0, "Uchar")
   Return DllCall(getFIMfunc("SetPixelIndex"), "int", hImage, "Uint", xPos, "Uint", yPos, "Uint", &IndexNum)
}

FreeImage_GetPixelColor(hImage, xPos, yPos) {
   VarSetCapacity(RGBQUAD, 4)
   RetValue := DllCall(getFIMfunc("GetPixelColor") , "int", hImage, "Uint", xPos, "Uint", yPos, "Uint", &RGBQUAD)
   If RetValue
      return, Numget(RGBQUAD, 0, "Uchar") . ":" . Numget(RGBQUAD, 1, "Uchar") . ":" . Numget(RGBQUAD, 2, "Uchar") . ":" . Numget(RGBQUAD, 3, "Uchar")
   else
      return, RetValue
}

FreeImage_SetPixelColor(hImage, xPos, yPos, RGBArray="255:255:255:0") {
   StringSplit, RGBA_, RGBArray, :, %A_space%
   VarSetCapacity(RGBQUAD, 4)
   NumPut(RGBA_1, RGBQUAD, 0, "UChar") , NumPut(RGBA_2, RGBQUAD, 1, "UChar") , NumPut(RGBA_3, RGBQUAD, 2, "UChar") , NumPut(RGBA_4, RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("SetPixelColor"), "int", hImage, "Uint", xPos, "Uint", yPos, "Uint", &RGBQUAD)
}

; === Conversion functions ===
; missing functions: ColorQuantizeEx, ConvertToType,
; ConvertToRawBits, ConvertFromRawBitsEx, ConvertFromRawBits

FreeImage_ConvertTo(hImage, MODE) {
; This is a wrapper for multiple FreeImage functions.
; Possible parameters for MODE: "4Bits", "8Bits", "16Bits555", "16Bits565", "24Bits",
; "32Bits", "Greyscale", "Float", "RGBF", "RGBAF", "UINT16", "RGB16", "RGBA16"
; ATTENTION: these are case sensitive!

   Return DllCall(getFIMfunc("ConvertTo" MODE), "int", hImage)
}

FreeImage_ConvertToStandardType(hImage, bScaleLinear=True) {
   Return DllCall(getFIMfunc("ConvertToStandardType"), "int", hImage, "int", bScaleLinear)
}

FreeImage_ColorQuantize(hImage, quantize=0) {
   Return DllCall(getFIMfunc("ColorQuantize"), "int", hImage, "int", quantize)
}

FreeImage_Threshold(hImage, TT=0) { ; TT: 0 - 255
   Return DllCall(getFIMfunc("Threshold"), "int", hImage, "int", TT)
}

FreeImage_Dither(hImage, algo=0) {
; algo parameter: dithering method
; 0 = FID_FS; Floyd & Steinberg error diffusion algorithm
; 1 = FID_BAYER4x4; Bayer ordered dispersed dot dithering (order 2 – 4x4 -dithering matrix)
; 2 = FID_BAYER8x8; Bayer ordered dispersed dot dithering (order 3 – 8x8 -dithering matrix)
; 3 = FID_BAYER16x16; Bayer ordered dispersed dot dithering (order 4 – 16x16 dithering matrix)
; 4 = FID_CLUSTER6x6; Ordered clustered dot dithering (order 3 - 6x6 matrix)
; 5 = FID_CLUSTER8x8; Ordered clustered dot dithering (order 4 - 8x8 matrix)
; 6 = FID_CLUSTER16x16; Ordered clustered dot dithering (order 8 - 16x16 matrix)

   Return DllCall(getFIMfunc("Dither"), "int", hImage, "int", algo)
}

FreeImage_ToneMapping(hImage, algo:=0, p1:=0, p2:=0) {
; function required to display HDR and RAW images
; algo parameter and p1/p2 intervals and meaning 
; 0 = FITMO_DRAGO03    ; Adaptive logarithmic mapping (F. Drago, 2003)
      ; p1 = gamma [0.0, 9.9]; p2 = exposure [-8, 8]
; 1 = FITMO_REINHARD05 ; Dynamic range reduction inspired by photoreceptor physiology (E. Reinhard, 2005)
      ; p1 = intensity [-8, 8]; p2 = contrast [0.3, 1.0]
; 2 = FITMO_FATTAL02   ; Gradient domain High Dynamic Range compression (R. Fattal, 2002)
      ; p1 = saturation [0.4, 0.6]; p2 = attenuation [0.8, 0.9]

   Return DllCall(getFIMfunc("ToneMapping"), "int", hImage, "int", algo, "Double", p1, "Double", p2)
}

; === ICC profile functions ===
; missing functions: CreateICCProfile, DestroyICCProfile
FreeImage_GetICCProfile(hImage) {
   Return DllCall(getFIMfunc("GetICCProfile"), "int", hImage) ; returns a pointer to it
}

; === Plugin functions ===
; none implemented
; 21 functions available in the FreeImage Library

; === Multipage bitmap functions ===
; none implemented
; 12 functions available in the FreeImage Library

; === Memory I/O functions ===
; missing functions: LoadFromMemory, SeekMemory, ReadMemory,
; WriteMemory, LoadMultiBitmapFromMemory, SaveMultiBitmapFromMemory

FreeImage_OpenMemory(hMemory, size) {
   Return DllCall(getFIMfunc("OpenMemory"), "int", hMemory, "int", size)
}

FreeImage_CloseMemory(hMemory) {
   Return DllCall(getFIMfunc("CloseMemory") , "int", hMemory, "int", size)
}

FreeImage_TellMemory(hMemory) {
   Return DllCall(getFIMfunc("TellMemory"), "int", hMemory)
}

FreeImage_AcquireMemory(hMemory, byref BufAdr, byref BufSize) {
   DataAddr := 0 , DataSizeAddr := 0
   bSucess := DllCall(getFIMfunc("AcquireMemory") , "int", hMemory, "Uint", &DataAddr, "Uint", &DataSizeAddr)
   BufAdr := numget(DataAddr, 0, "int") , BufSize := numget(DataSizeAddr, 0, "int")
   return, bSucess
}

FreeImage_SaveToMemory(FIF,hImage, hMemory, Flags) { ; 0:BMP 2:JPG 13:PNG 18:TIF 25:GIF
   Return DllCall(getFIMfunc("SaveToMemory"), "int", FIF, "int", hImage, "int", hMemory, "int", Flags)
}

; === Compression functions ===
; none implemented
; 5 functions available in the FreeImage Library

; === Metadata functions ===
; none implemented
; 26 functions available in the FreeImage Library

; === Toolkit functions ===
; 38 functions available in the FreeImage Library
; only 11 implemented

FreeImage_Rotate(hImage, angle) {
; missing color parameter
   Return DllCall(getFIMfunc("Rotate"), "Int", hImage, "Double", angle)
}

FreeImage_FlipHorizontal(hImage) {
   Return DllCall(getFIMfunc("FlipHorizontal"), "Int", hImage)
}

FreeImage_FlipVertical(hImage) {
   Return DllCall(getFIMfunc("FlipVertical"), "Int", hImage)
}

FreeImage_Rescale(hImage, w, h, filter:=3) {
; Filter parameter options
; 0 = FILTER_BOX;        Box, pulse, Fourier window, 1st order (constant) B-Spline
; 1 = FILTER_BILINEAR;   Bilinear filter
; 2 = FILTER_BSPLINE;    4th order (cubic) B-Spline
; 3 = FILTER_BICUBIC;    Mitchell and Netravali's two-param cubic filter
; 4 = FILTER_CATMULLROM; Catmull-Rom spline, Overhauser spline
; 5 = FILTER_LANCZOS3;   Lanczos-windowed sinc filter

   Return DllCall(getFIMfunc("Rescale"), "Int", hImage, "Int", w, "Int", h, "Int", filter)
}

FreeImage_AdjustColors(hImage, bright, contrast, gamma, invert) {
; bright and contrast interval: [-100, 100]
; gamma interval: [0.0, 2.0]
; invert: 1 or 0
; return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("AdjustColors"), "Int", hImage, "Double", bright, "Double", contrast, "Double", gamma, "Int", invert)
}

FreeImage_Copy(hImage, nLeft, nTop, nRight, nBottom) {
   Return DllCall(getFIMfunc("Copy"), "Int", hImage, "int", nLeft, "int", nTop, "int", nRight, "int", nBottom)
}

FreeImage_Paste(hImageDst, hImageSrc, nLeft, nTop, nAlpha) {
   Return DllCall(getFIMfunc("Paste"), "Int", hImageDst, "int", hImageSrc, "int", nLeft, "int", nTop, "int", nAlpha)
}

FreeImage_Composite(hImage, useFileBkg=False, RGBArray="255:255:255:0", hImageBkg=False) {
   StringSplit, RGBA_, RGBArray, :, %A_space%
   VarSetCapacity(RGBQUAD, 4)
   NumPut(RGBA_1, RGBQUAD, 0, "UChar") , NumPut(RGBA_2, RGBQUAD, 1, "UChar") , NumPut(RGBA_3, RGBQUAD, 2, "UChar") , NumPut(RGBA_4, RGBQUAD, 3, "UChar")
   Return DllCall(getFIMfunc("Composite"), "int", hImage, "int", useFileBkg, "Uint", &RGBQUAD, "int", hImageBkg)
}

FreeImage_JPEGTransform(SrcImPath, DstImPath, ImgOperation) {
; ImgOperation parameter options:
; 0 = NONE                1 = Flip Horizontally
; 2 = Flip Vertically     3 = Transpose
; 4 = Transverse          5 = Rotate 90
; 6 = Rotate 180          7 = Rotate -90
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("JPEGTransformU"), "WStr", SrcImPath, "WStr", DstImPath, "int", ImgOperation)
}

FreeImage_JPEGCrop(SrcImPath, DstImPath, x1, y1, x2, y2) {
; Return value: 1 -- succes; 0 -- fail
   Return DllCall(getFIMfunc("JPEGCropU"), "WStr", SrcImPath, "WStr", DstImPath, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2)
}

FreeImage_JPEGTransformCombined(SrcImPath, DstImPath, ImgOperation, x1, y1, x2, y2) {
   Return DllCall(getFIMfunc("JPEGTransformCombinedU"), "WStr", SrcImPath, "WStr", DstImPath, "Int*", ImgOperation, "Int*", x1, "Int*", y1, "Int*", x2, "Int*", y2)
}

; === Other functions ===

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

ConvertFIMtoPBITMAP(hFIFimgA, destWin) {
; destWin parameter is the window you intend to display it in required for GetDC()
; this function relies on GDI+ AHK library v1.90 [the edition modified by Marius Șucan]
  imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
  If (imgBPP>32)
     hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)

  hFIFimgC := hFIFimgB ? hFIFimgB : hFIFimgA
  pBits := FreeImage_GetBits(hFIFimgC)
  bitmapInfo := FreeImage_GetInfo(hFIFimgC)
  bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgC)
  hdc := DllCall("GetDC", "UInt", destWin)
  hBITMAP := Gdip_CreateDIBitmap(hDC, bmpInfoHeader, 4, pBits, bitmapInfo, 0)
  pBITMAP := Gdip_CreateBitmapFromHBITMAP(hBITMAP)
  DeleteDC(hdc)
  r2 := DeleteObject(hBITMAP)
  If hFIFimgB
     FreeImage_UnLoad(hFIFimgB)
  Return pBITMAP
}

ConvertPBITMAPtoFIM(pBitmap, destWin) {
; this function relies on GDI+ AHK library v1.90 [the edition modified by Marius Șucan]
  hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
  Gdip_GetImageDimensions(pBitmap, imgW, imgH)
  hFIFimgA := FreeImage_Allocate(imgW, imgH, 32)
  pBits := FreeImage_GetBits(hFIFimgA)
  bitmapInfo := FreeImage_GetInfo(hFIFimgA)
  hdc := DllCall("GetDC", "UInt", destWin)
  bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgA)
  r1 := Gdip_GetDIBits(hdc, hBitmap, 0, imgH, pBits, bitmapInfo, 2)
  DeleteDC(hdc)
  r2 := DeleteObject(hBitmap)
  Return hFIFimgA
}
