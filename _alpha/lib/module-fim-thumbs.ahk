#NoEnv
#NoTrayIcon
#MaxHotkeysPerInterval, 500
#MaxThreads, 1
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#MaxMem, 2924
#SingleInstance, force
#Persistent
#UseHook, Off
SetWinDelay, 1
Global GDIPToken, MainExe := AhkExported()
     , mainCompiledPath := "", wasInitFIMlib := 0, listBitmaps := ""
     , operationDone := 1, resultsList := "", FIMfailed2init := 0
     , waitDataCollect := 1, operationFailed := 0

; E := initThisThread()
Return

initThisThread() {
  GDIPToken := MainExe.ahkGetVar.GDIPToken
  mainCompiledPath := MainExe.ahkGetVar.mainCompiledPath
  r := FreeImage_FoxInit(1) ; Load the FreeImage Dll
  wasInitFIMlib := r ? 1 : 0
  ; MsgBox, % r "`n" wasInitFIMlib "`n" GDIPToken "`n" mainCompiledPath
  Return r
}

cleanupThread() {
   If (wasInitFIMlib=1)
      FreeImage_FoxInit(0) ; Unload Dll

   wasInitFIMlib := GDIPToken := 0
}

cleanMess() {
   waitDataCollect := 1
   Sort, listBitmaps, UD|
   Loop, Parse, listBitmaps, |
       Gdip_DisposeImage(A_LoopField, 1)

   listBitmaps := ""
   waitDataCollect := 0
   operationFailed := 0
   operationDone := 1
}

MonoGenerateThumb(imgPath, file2save, mustSaveFile, thumbsSizeQuality, timePerImg, coreIndex, thisfileIndex, thisBindex) {
   Critical, on
   operationDone := 0
   hFIFimgA := 0
   finalBitmap := 0
   waitDataCollect := 0
   operationFailed := 0
   startZeit := A_TickCount
   resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
   ; RegWrite, REG_SZ, %QPVregEntry%, thumbThreadDone%coreIndex%, 0
   r := imgPath
   GFT := FreeImage_GetFileType(r)
   loadOption := (GFT=34) ? 5 : 0
   hFIFimgA := FreeImage_Load(r, -1, loadOption)
   If !hFIFimgA
   {
      operationDone := 1
      waitDataCollect := 1
      operationFailed := 1
      resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
      Return -1
   }
 
   imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
   If (imgBPP>32)
   {
      hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)
      FreeImage_UnLoad(hFIFimgA)
      If !hFIFimgB
      {
         operationDone := 1
         waitDataCollect := 1
         operationFailed := 1
         resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
         Return -1
      }
      hFIFimgA := hFIFimgB
   }

   FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
   calcIMGdimensions(imgW, imgH, thumbsSizeQuality, thumbsSizeQuality, ResizedW, ResizedH)
   resizeFilter := 0 ; (ResizeQualityHigh=1) ? 3 : 0
   ; hFIFimgB := FreeImage_MakeThumbnail(hFIFimgA, thumbsSizeQuality, 0)
   hFIFimgB := FreeImage_Rescale(hFIFimgA, ResizedW, ResizedH, resizeFilter)
   If hFIFimgB
   {
      FreeImage_UnLoad(hFIFimgA)
      hFIFimgA := hFIFimgB
   } Else
   {
      FreeImage_UnLoad(hFIFimgA)
      operationDone := 1
      operationFailed := 1
      waitDataCollect := 1
      resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
      Return -1
   }

   If (hFIFimgA)
   {
      imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
      thisZeit := A_TickCount - startZeit
      If (imgBPP!=24)
      {
         hFIFimgB := FreeImage_ConvertTo(hFIFimgA, "24Bits")
         If hFIFimgB
         {
            FreeImage_UnLoad(hFIFimgA)
            hFIFimgA := hFIFimgB
         }
      }

      If (mustSaveFile=1 && thisZeit>timePerImg)
         savedFile := FreeImage_Save(hFIFimgA, file2save)
      Else savedFile := "yeah"

      finalBitmap := ConvertFimObj2pBitmap(hFIFimgA, ResizedW, ResizedH)
      FreeImage_UnLoad(hFIFimgA)
      If (finalBitmap && thisZeit>timePerImg && mustSaveFile=1 && !savedFile)
      {
         r := Gdip_SaveBitmapToFile(finalBitmap, file2save)
         ; SoundBeep , 900, 100
      } Else If (!finalBitmap && mustSaveFile=1 && savedFile)
      {
         ; SoundBeep , 900, 100
         finalBitmap := Gdip_CreateBitmapFromFile(file2save)
      }
   }
   listBitmaps .=  finalBitmap "|"
   ; Sleep, 0
   waitDataCollect := 1
   operationDone := 1
   operationFailed := 0
   resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex

   ; RegWrite, REG_SZ, %QPVregEntry%, thumbThreadDone%coreIndex%, 1
   ; MainExe.ahkassign("thumbCoreRun" coreIndex, operationDone)
   ; cleanupThread()
}

/*
gdipMonoGenerateThumb(imgPath, file2save, mustSaveFile, thumbsSizeQuality, resizeFilter, coreIndex, thisfileIndex, thisBindex) {
   Critical, on
   operationDone := 0
   hFIFimgA := 0
   finalBitmap := 0
   waitDataCollect := 0
   operationFailed := 0
   startZeit := A_TickCount
   resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
   ; RegWrite, REG_SZ, %QPVregEntry%, thumbThreadDone%coreIndex%, 0
   r := imgPath
   hFIFimgA := Gdip_CreateBitmapFromFile(r)
   If !hFIFimgA
   {
      operationDone := 1
      waitDataCollect := 1
      operationFailed := 1
      resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
      Return -1
   }
 
   resizeFilter := (ResizeQualityHigh=1) ? 7 : 5
   hFIFimgB := Gdip_ResizeBitmap(hFIFimgA, thumbsSizeQuality, thumbsSizeQuality, 1, resizeFilter)
   If hFIFimgB
   {
      Gdip_DisposeImage(hFIFimgA)
      hFIFimgA := hFIFimgB
   } Else
   {
      Gdip_DisposeImage(hFIFimgA)
      operationDone := 1
      operationFailed := 1
      waitDataCollect := 1
      resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
      Return -1
   }

   If (hFIFimgA)
   {
      thisZeit := A_TickCount - startZeit
      If (mustSaveFile=1 && thisZeit>225)
         savedFile := Gdip_SaveBitmapToFile(hFIFimgA, file2save)

      finalBitmap := hFIFimgA
   }

   ; Sleep, 0
   waitDataCollect := 1
   operationDone := 1
   operationFailed := 0
   resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex

   ; RegWrite, REG_SZ, %QPVregEntry%, thumbThreadDone%coreIndex%, 1
   ; MainExe.ahkassign("thumbCoreRun" coreIndex, operationDone)
   ; cleanupThread()
}
*/

ConvertFimObj2pBitmap(hFIFimgD, imgW, imgH) {
  ; hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "24Bits")
  bitmapInfo := FreeImage_GetInfo(hFIFimgD)
  pBits := FreeImage_GetBits(hFIFimgD)

  nBitmap := Gdip_CreateBitmapFromGdiDib(bitmapInfo, pBits)
  pBitmap := Gdip_CreateBitmap(imgW, imgH, 0x21808)    ; 24-RGB

  G := Gdip_GraphicsFromImage(pBitmap)
  Gdip_DrawImageFast(G, nBitmap)
  Gdip_DeleteGraphics(G)
  Gdip_DisposeImage(nBitmap)
  Return pBitmap
}












; ================
; Includes

FreeImage_GetBits(hImage) {
   Return DllCall(getFIMfunc("GetBits"), "Int", hImage)
}

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "Int", hImage)
}

FreeImage_ConvertTo(hImage, MODE) {
; This is a wrapper for multiple FreeImage functions.
; Possible parameters for MODE: "4Bits", "8Bits", "16Bits555", "16Bits565", "24Bits",
; "32Bits", "Greyscale", "Float", "RGBF", "RGBAF", "UINT16", "RGB16", "RGBA16"
; ATTENTION: these are case sensitive!

   Return DllCall(getFIMfunc("ConvertTo" MODE), "int", hImage)
}

FreeImage_FoxInit(isInit:=1) {
   Static hFIDll
   DllPath := FreeImage_FoxGetDllPath("freeimage.dll")
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


FreeImage_Load(ImPath, GFT:=-1, flag:=0, ByRef dGFT:=0) {
   If (GFT=-1 || GFT="")
      dGFT := GFT := FreeImage_GetFileType(ImPath)
   If (GFT="" || !ImPath)
      Return
   Return DllCall(getFIMfunc("LoadU"), "Int", GFT, "WStr", ImPath, "int", flag)
}

FreeImage_Save(hImage, ImPath, ImgArg:=0) {
   ; FIMfrmt := {"BMP":0, "JPG":2, "JPEG":2, "PNG":13, "TIF":18, "TIFF":18, "GIF":25}
   OutExt := FreeImage_GetFIFFromFilename(ImPath)
   Return DllCall(getFIMfunc("SaveU"), "Int", OutExt, "Int", hImage, "WStr", ImPath, "int", ImgArg)
}


FreeImage_UnLoad(hImage) {
   If StrLen(hImage)<4
      Return
   Return DllCall(getFIMfunc("Unload"), "Int", hImage)
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

FreeImage_GetImageDimensions(hImage, ByRef imgW, ByRef imgH) {
   imgH := FreeImage_GetHeight(hImage)
   imgW := FreeImage_GetWidth(hImage)
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


FreeImage_GetFileType(ImPath) {
   ; 0:BMP 2:JPG 13:PNG 18:TIF 25:GIF
   r := DllCall(getFIMfunc("GetFileTypeU"), "WStr", ImPath, "Int", 0)
   If (r=-1)
      r := FreeImage_GetFIFFromFilename(ImPath)
   Return r
}

FreeImage_GetFIFFromFilename(file) {
   Return DllCall(getFIMfunc("GetFIFFromFilename"), "AStr", file)
}

FreeImage_ToneMapping(hImage, algo:=0, p1:=0, p2:=0) {
   Return DllCall(getFIMfunc("ToneMapping"), "int", hImage, "int", algo, "Double", p1, "Double", p2)
}

FreeImage_Rescale(hImage, w, h, filter:=3) {
   Return DllCall(getFIMfunc("Rescale"), "Int", hImage, "Int", w, "Int", h, "Int", filter)
}

calcIMGdimensions(imgW, imgH, givenW, givenH, ByRef ResizedW, ByRef ResizedH) {

   PicRatio := Round(imgW/imgH, 5)
   givenRatio := Round(givenW/givenH, 5)
   If (imgW <= givenW) && (imgH <= givenH)
   {
      ResizedW := givenW
      ResizedH := Round(ResizedW / PicRatio)
      If (ResizedH>givenH)
      {
         ResizedH := (imgH <= givenH) ? givenH : imgH
         ResizedW := Round(ResizedH * PicRatio)
      }   
   } Else If (PicRatio > givenRatio)
   {
      ResizedW := givenW
      ResizedH := Round(ResizedW / PicRatio)
   } Else
   {
      ResizedH := (imgH >= givenH) ? givenH : imgH         ;set the maximum picture height to the original height
      ResizedW := Round(ResizedH * PicRatio)
   }
}

Gdip_CreateBitmapFromFile(sFile) {
   pBitmap := ""
   Ptr := A_PtrSize ? "UPtr" : "UInt"
   PtrA := A_PtrSize ? "UPtr*" : "UInt*"

   SplitPath sFile,,, Extension
   DllCall("gdiplus\GdipCreateBitmapFromFile", Ptr, &sFile, PtrA, pBitmap)
   return pBitmap
}


Gdip_SaveBitmapToFile(pBitmap, sOutput, Quality:=75) {
   Ptr := A_PtrSize ? "UPtr" : "UInt"
   nCount := 0
   nSize := 0
   _p := 0

   SplitPath sOutput,,, Extension
   If !RegExMatch(Extension, "^(?i:BMP|DIB|RLE|JPG|JPEG|JPE|JFIF|GIF|TIF|TIFF|PNG)$")
      Return -1

   Extension := "." Extension
   DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", nCount, "uint*", nSize)
   VarSetCapacity(ci, nSize)
   DllCall("gdiplus\GdipGetImageEncoders", "uint", nCount, "uint", nSize, Ptr, &ci)
   If !(nCount && nSize)
      Return -2

    StrGet_Name := "StrGet"
    N := (A_AhkVersion < 2) ? nCount : "nCount"
    Loop %N%
    {
       sString := %StrGet_Name%(NumGet(ci, (idx := (48+7*A_PtrSize)*(A_Index-1))+32+3*A_PtrSize), "UTF-16")
       If !InStr(sString, "*" Extension)
          Continue

       pCodec := &ci+idx
       Break
    }
   If !pCodec
      Return -3

   If (Quality!=75)
   {
      Quality := (Quality < 0) ? 0 : (Quality > 100) ? 100 : Quality
      If RegExMatch(Extension, "^\.(?i:JPG|JPEG|JPE|JFIF)$")
      {
         DllCall("gdiplus\GdipGetEncoderParameterListSize", Ptr, pBitmap, Ptr, pCodec, "uint*", nSize)
         VarSetCapacity(EncoderParameters, nSize, 0)
         DllCall("gdiplus\GdipGetEncoderParameterList", Ptr, pBitmap, Ptr, pCodec, "uint", nSize, Ptr, &EncoderParameters)
         nCount := NumGet(EncoderParameters, "UInt")
         N := (A_AhkVersion < 2) ? nCount : "nCount"
         Loop %N%
         {
            elem := (24+(A_PtrSize ? A_PtrSize : 4))*(A_Index-1) + 4 + (pad := A_PtrSize = 8 ? 4 : 0)
            If (NumGet(EncoderParameters, elem+16, "UInt") = 1) && (NumGet(EncoderParameters, elem+20, "UInt") = 6)
            {
               _p := elem+&EncoderParameters-pad-4
               NumPut(Quality, NumGet(NumPut(4, NumPut(1, _p+0)+20, "UInt")), "UInt")
               Break
            }
         }
      }
   }
   _E := DllCall("gdiplus\GdipSaveImageToFile", Ptr, pBitmap, Ptr, &sOutput, Ptr, pCodec, "uint", _p ? _p : 0)
   Return _E ? -5 : 0
}


Gdip_CreateBitmapFromGdiDib(BITMAPINFO, BitmapData) {
   Ptr := A_PtrSize ? "UPtr" : "UInt"
   E := DllCall("gdiplus\GdipCreateBitmapFromGdiDib", Ptr, BITMAPINFO, Ptr, BitmapData, "UPtr*", pBitmap)
   Return pBitmap
}


Gdip_CreateBitmap(Width, Height, PixelFormat:=0, Stride:=0, Scan0:=0) {
; By default, this function creates a new 32-ARGB bitmap.
; modified by Marius Șucan

   pBitmap := ""
   If !PixelFormat
      PixelFormat := 0x26200A  ; 32-ARGB

   DllCall("gdiplus\GdipCreateBitmapFromScan0"
      , "int", Width
      , "int", Height
      , "int", Stride
      , "int", PixelFormat
      , A_PtrSize ? "UPtr" : "UInt", Scan0
      , A_PtrSize ? "UPtr*" : "uint*", pBitmap)
   Return pBitmap
}


Gdip_GraphicsFromImage(pBitmap, InterpolationMode:="", SmoothingMode:="", PageUnit:="", CompositingQuality:="") {
   pGraphics := ""
   DllCall("gdiplus\GdipGetImageGraphicsContext", A_PtrSize ? "UPtr" : "UInt", pBitmap, A_PtrSize ? "UPtr*" : "UInt*", pGraphics)
   return pGraphics
}

Gdip_DisposeImage(pBitmap, noErr:=0) {
; modified by Marius Șucan to help avoid crashes 
; by disposing a non-existent pBitmap

   If (StrLen(pBitmap)<=2 && noErr=1)
      Return 0

   r := DllCall("gdiplus\GdipDisposeImage", A_PtrSize ? "UPtr" : "UInt", pBitmap)
   If (r=2 || r=1) && (noErr=1)
      r := 0
   Return r
}

Gdip_DeleteGraphics(pGraphics) {
   return DllCall("gdiplus\GdipDeleteGraphics", A_PtrSize ? "UPtr" : "UInt", pGraphics)
}


Gdip_DrawImageFast(pGraphics, pBitmap, X:=0, Y:=0) {
; This function performs faster than Gdip_DrawImage().
; X, Y - the coordinates of the destination upper-left corner
; where the pBitmap will be drawn.

   Ptr := A_PtrSize ? "UPtr" : "UInt"
   _E := DllCall("gdiplus\GdipDrawImage"
            , Ptr, pGraphics
            , Ptr, pBitmap
            , "float", X
            , "float", Y)
   return _E
}
