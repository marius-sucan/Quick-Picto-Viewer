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
SetWorkingDir, %A_ScriptDir%
; #Include Lib\gdip_all.ahk
; #Include Lib\freeimage.ahk
; #Include Lib\wia.ahk
SetWinDelay, 1
Global GDIPToken, MainExe := AhkExported(), runningGDIPoperation := 0, WICmoduleHasInit := 0
     , mainCompiledPath := "", wasInitFIMlib := 0, listBitmaps := "", imgQuality := 0
     , operationDone := 1, resultsList := "", FIMfailed2init := 0, thisThreadID := -1
     , waitDataCollect := 1, operationFailed := 0, RegExWICfmtPtrn
     , RegExFIMformPtrn := "i)(.\\*\.(DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f))$"

; E := initThisThread()
Return

initThisThread(params:=0) {
  If !InStr(params, "|")
  {
     GDIPToken := MainExe.ahkGetVar.GDIPToken
     mainCompiledPath := MainExe.ahkGetVar.mainCompiledPath
  } Else
  {
     externObj := StrSplit(params, "|")
     GDIPToken := externObj[1]
     mainCompiledPath := externObj[2]
     imgQuality := externObj[3]
     thisThreadID := externObj[4]
     WICmoduleHasInit := externObj[5]
     RegExWICfmtPtrn := MainExe.ahkGetVar.RegExWICfmtPtrn
  }

  ; initQPVmainDLL()
  If !wasInitFIMlib
     r := FreeImage_FoxInit(1) ; Load the FreeImage Dll

  wasInitFIMlib := (r && !InStr(r, "err")) ? 1 : 0
  r := (WICmoduleHasInit=1 || wasInitFIMlib=1) ? 1 : 0
   ; MsgBox, % r "`n" wasInitFIMlib "`n" GDIPToken "`n" mainCompiledPath
  Return r
}

cleanupThread() {
   If (wasInitFIMlib=1)
      FreeImage_FoxInit(0) ; Unload Dll

   wasInitFIMlib := GDIPToken := 0
}

LoadWICimage(imgPath, w:=0, h:=0, keepAratio:=1, thisImgQuality:=0, frameu:=0, ScaleAnySize:=0, noBPPconv:=0, doFlipu:=0, doGray:=0) {
   ; Return
   ; startZeit := A_TickCount
   VarSetCapacity(resultsArray, 8 * 6, 0)
   ; If (!w || !h)
   ;    GetWinClientSize(w, h, PVhwnd, 0) 

   ; If !imgPath
   ;    imgPath := getIDimage(currentFileIndex)
   ; fnOutputDebug("wic-load " imgPath)
   func2exec := (A_PtrSize=8) ? "LoadWICimage" : "_LoadWICimage@48"
   r := DllCall("qpvmain.dll\" func2exec, "Int", thisThreadID, "Int", noBPPconv, "Int", thisImgQuality, "Int", w, "Int", h, "int", keepAratio, "int", ScaleAnySize, "int", frameu, "int", doFlipu, "int", doGray, "Str", imgPath, "UPtr", &resultsArray, "Ptr")
   ; mainLoadedIMGdetails.imgW := NumGet(resultsArray, 4 * 0, "uInt")
   ; mainLoadedIMGdetails.imgH := NumGet(resultsArray, 4 * 1, "uInt")
   ; mainLoadedIMGdetails.Frames := NumGet(resultsArray, 4 * 2, "uInt")
   ; mainLoadedIMGdetails.pixFmt := NumGet(resultsArray, 4 * 3, "uInt")
   ; mainLoadedIMGdetails.DPI := NumGet(resultsArray, 4 * 4, "uInt")
   ; mainLoadedIMGdetails.RawFormat := NumGet(resultsArray, 4 * 5, "uInt")
   ; mainLoadedIMGdetails.TooLargeGDI := (imgW>32500 || imgH>32500) ? 1 : 0
   ; mainLoadedIMGdetails.HasAlpha := InStr(mainLoadedIMGdetails.pixFmt, "argb") || InStr(mainLoadedIMGdetails.pixFmt, "bgra") || InStr(mainLoadedIMGdetails.pixFmt, "alpha") ? 1 : 0
   ; mainLoadedIMGdetails.OpenedWith := "WIC"
   resultsArray := ""
   ; zeitu := A_TickCount - startZeit
   ; msgbox, % r "==" zeitu " = " pixfmt "=" rawFmt
   ; ToolTip, % WICmoduleHasInit " | " r "==" zeitu " = " mainLoadedIMGdetails.pixfmt "=" mainGdipWinThumbsGrid.RawFormat , , , 3
   ; https://stackoverflow.com/questions/8101203/wicbitmapsource-copypixels-to-gdi-bitmap-scan0
   ; https://github.com/Microsoft/Windows-classic-samples/blob/master/Samples/Win7Samples/multimedia/wic/wicviewergdi/WicViewerGdi.cpp#L354
   Return r
}

cleanMess(thisID:=0) {
   Critical, on
   waitDataCollect := 1
   ; OutputDebug, QPV: ThumbsMode. Script thread. Clean GDIs mess...

   cleaned := 0
   Sort, listBitmaps, UD|
   Loop, Parse, listBitmaps, |
   {
       cleaned++
       Gdip_DisposeImage(A_LoopField, 1)
   }

   OutputDebug, QPV: ThumbsMode. External thread. Clean GDIs mess core %thisID%: %cleaned% bitmaps disposed.
   listBitmaps := ""
   waitDataCollect := 0
   operationFailed := 0
   operationDone := 1
}

fnOutputDebug(msg) {
   OutputDebug, QPV: threadex %thisThreadID% - %msg%
}

MonoGenerateThumb(imgPath, file2save, mustSaveFile, thumbsSizeQuality, timePerImg, coreIndex, thisfileIndex, thisBindex) {
   Critical, on

   operationDone := hFIFimgA := finalBitmap := 0
   waitDataCollect := operationFailed := 0
   startZeit := A_TickCount
   resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
   ; RegWrite, REG_SZ, %QPVregEntry%, thumbThreadDone%coreIndex%, 0
   If (RegExMatch(imgPath, RegExWICfmtPtrn) && WICmoduleHasInit=1)
   {
      thisImgQuality := (imgQuality=1) ? 6 : 5
      finalBitmap := LoadWICimage(imgPath, thumbsSizeQuality, thumbsSizeQuality, 1, thisImgQuality, 3, 0)
      thisZeit := A_TickCount - startZeit
      If (mustSaveFile=1 && thisZeit>timePerImg && finalBitmap)
         r := Gdip_SaveBitmapToFile(finalBitmap, file2save)
   }

   If (StrLen(finalBitmap)<3 && wasInitFIMlib=1)
   {
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

      FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
      calcIMGdimensions(imgW, imgH, thumbsSizeQuality, thumbsSizeQuality, ResizedW, ResizedH)
      resizeFilter := 0 ; (ResizeQualityHigh=1) ? 3 : 0
    
      hFIFimgX := FreeImage_Rescale(hFIFimgA, ResizedW, ResizedH, resizeFilter)
      FreeImage_UnLoad(hFIFimgA)
      If StrLen(hFIFimgX)>1
      {
         hFIFimgA := hFIFimgX
      } Else
      {
         fnOutputDebug(mustSaveFile " - " thumbsSizeQuality "px - " timePerImg "ms - core" coreIndex " - file" thisfileIndex " - loopIndex" thisBindex " - " imgPath)
         operationDone := 1
         waitDataCollect := 1
         operationFailed := 1
         resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
         Return -1
      }

      imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
      ColorsType := FreeImage_GetColorType(hFIFimgA)
      mustApplyToneMapping := (imgBPP>32 && !InStr(ColorsType, "rgba")) || (imgBPP>64) ? 1 : 0
      If (mustApplyToneMapping=1)
      {
         hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)
         FreeImage_UnLoad(hFIFimgA)
         If !hFIFimgB
         {
            fnOutputDebug(mustSaveFile " - " thumbsSizeQuality "px - " timePerImg "ms - core" coreIndex " - file" thisfileIndex " - loopIndex" thisBindex " - " imgPath)
            operationDone := 1
            waitDataCollect := 1
            operationFailed := 1
            resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
            Return -1
         }
         hFIFimgA := hFIFimgB
      }

      FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
      If (imgW!=ResizedW || imgH!=ResizedH)
      {
         ; hFIFimgB := FreeImage_MakeThumbnail(hFIFimgA, thumbsSizeQuality, 0)
         hFIFimgB := FreeImage_Rescale(hFIFimgA, ResizedW, ResizedH, resizeFilter)
         FreeImage_UnLoad(hFIFimgA)
         If StrLen(hFIFimgB)>1
         {
            hFIFimgA := hFIFimgB
         } Else
         {
            fnOutputDebug(mustSaveFile " - " thumbsSizeQuality "px - " timePerImg "ms - core" coreIndex " - file" thisfileIndex " - loopIndex" thisBindex " - " imgPath)
            operationDone := 1
            operationFailed := 1
            waitDataCollect := 1
            resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
            Return -1
         }
      }

      If StrLen(hFIFimgA)>1
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
            finalBitmap := Gdip_CreateBitmapFromFileSimplified(file2save)
         }
      }
   } ; // fim loader

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
   hFIFimgA := Gdip_CreateBitmapFromFileSimplified(r)
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

ConvertFimObj2pBitmap(hFIFimgD, imgW, imgH) {
  ; hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "24Bits")
  If StrLen(hFIFimgD)<3
     Return

  bitmapInfo := FreeImage_GetInfo(hFIFimgD)
  pBits := FreeImage_GetBits(hFIFimgD)
  If (!bitmapInfo || !pBits)
     Return

  nBitmap := Gdip_CreateBitmapFromGdiDib(bitmapInfo, pBits)
  pBitmap := Gdip_CreateBitmap(imgW, imgH, 0xE200B)    ; 24-RGB

  G := Gdip_GraphicsFromImage(pBitmap)
  Gdip_DrawImageFast(G, nBitmap)
  Gdip_DeleteGraphics(G)
  Gdip_DisposeImage(nBitmap)
  Return pBitmap
}

; external functions

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "uptr", hImage, "uptr")
}

FreeImage_GetBits(hImage) {
   Return DllCall(getFIMfunc("GetBits"), "uptr", hImage, "uptr")
}

FreeImage_ConvertTo(hImage, MODE) {
; This is a wrapper for multiple FreeImage functions.
; Possible parameters for MODE: "4Bits", "8Bits", "16Bits555", "16Bits565", "24Bits",
; "32Bits", "Greyscale", "Float", "RGBF", "RGBAF", "UINT16", "RGB16", "RGBA16"
; ATTENTION: these are case sensitive!
   If !hImage
      Return

   If (mode="16bits")
      mode := "16Bits565"

   Return DllCall(getFIMfunc("ConvertTo" MODE), "uptr", hImage, "uptr")
}

FreeImage_GetFIFFromFilename(ImgPath) {
   Return DllCall(getFIMfunc("GetFIFFromFilename"), "AStr", ImgPath)
}


FreeImage_Save(hImage, ImgPath, ImgArg:=0) {
; Return 0 = failed; 1 = success
; FIMfrmt := {"BMP":0, "JPG":2, "JPEG":2, "PNG":13, "TIF":18, "TIFF":18, "GIF":25}
   If (!hImage || !ImgPath)
      Return

   OutExt := FreeImage_GetFIFFromFilename(ImgPath)
   Return DllCall(getFIMfunc("SaveU"), "Int", OutExt, "uptr", hImage, "WStr", ImgPath, "int", ImgArg)
}

FreeImage_UnLoad(hImage) {
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Unload"), "uptr", hImage)
}

FreeImage_Rescale(hImage, w, h, filter:=3) {
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Rescale"), "uptr", hImage, "Int", w, "Int", h, "Int", filter, "uptr")
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

FreeImage_GetColorType(hImage, humanReadable:=1) {
   Static ColorsTypes := {1:"MINISBLACK", 0:"MINISWHITE", 3:"PALETTIZED", 2:"RGB", 4:"RGBA", 5:"CMYK"}
   r := DllCall(getFIMfunc("GetColorType"), "uptr", hImage)
   If (ColorsTypes.HasKey(r) && humanReadable=1)
      r := ColorsTypes[r]

   Return r
}

FreeImage_ToneMapping(hImage, algo:=0, p1:=0, p2:=0) {
   Return DllCall(getFIMfunc("ToneMapping"), "uptr", hImage, "int", algo, "Double", p1, "Double", p2, "uptr")
}

FreeImage_FoxInit(isInit:=1) {
   Static hFIDll
   ; if you change the dll name, getFIMfunc() needs to reflect this
   DllPath := FreeImage_FoxGetDllPath("freeimage.dll")
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

FreeImage_GetFileType(ImgPath, humanReadable:=0) {
   Static fileTypes := {0:"BMP", 1:"ICO", 2:"JPEG", 3:"JNG", 4:"KOALA", 5:"LBM", 5:"IFF", 6:"MNG", 7:"PBM", 8:"PBMRAW", 9:"PCD", 10:"PCX", 11:"PGM", 12:"PGMRAW", 13:"PNG", 14:"PPM", 15:"PPMRAW", 16:"RAS", 17:"TARGA", 18:"TIFF", 19:"WBMP", 20:"PSD", 21:"CUT", 22:"XBM", 23:"XPM", 24:"DDS", 25:"GIF", 26:"HDR", 27:"FAXG3", 28:"SGI", 29:"EXR", 30:"J2K", 31:"JP2", 32:"PFM", 33:"PICT", 34:"RAW", 35:"WEBP", 36:"JXR"}
   r := DllCall(getFIMfunc("GetFileTypeU"), "WStr", ImgPath, "Int", 0)
   If (r=-1)
      r := FreeImage_GetFIFFromFilename(ImgPath)
   If (humanReadable=1 && fileTypes.HasKey(r))
      r := fileTypes[r]

   Return r
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

FreeImage_GetBPP(hImage) {
   Return DllCall(getFIMfunc("GetBPP"), "uptr", hImage)
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



Gdip_CreateBitmapFromGdiDib(BITMAPINFO, BitmapData) {
   pBitmap := 0
   gdipLastError := DllCall("gdiplus\GdipCreateBitmapFromGdiDib", "UPtr", BITMAPINFO, "UPtr", BitmapData, "UPtr*", pBitmap)
   Return pBitmap
}

Gdip_CreateBitmap(Width, Height, PixelFormat:=0, Stride:=0, Scan0:=0) {
; By default, this function creates a new 32-ARGB bitmap.
; modified by Marius Șucan
   If (!Width || !Height)
   {
      gdipLastError := 2
      Return
   }

   pBitmap := 0
   If !PixelFormat
      PixelFormat := 0x26200A  ; 32-ARGB

   gdipLastError := DllCall("gdiplus\GdipCreateBitmapFromScan0"
      , "int", Width  , "int", Height
      , "int", Stride , "int", PixelFormat
      , "UPtr", Scan0 , "UPtr*", pBitmap)

   Return pBitmap
}

Gdip_DrawImageFast(pGraphics, pBitmap, X:=0, Y:=0) {
; This function performs faster than Gdip_DrawImage().
; X, Y - the coordinates of the destination upper-left corner
; where the pBitmap will be drawn.

   return DllCall("gdiplus\GdipDrawImage"
            , "UPtr", pGraphics
            , "UPtr", pBitmap
            , "float", X
            , "float", Y)
}

Gdip_GetImagePixelFormat(pBitmap, mode:=0) {
   Static PixelFormatsList := {0x30101:"1-INDEXED", 0x30402:"4-INDEXED", 0x30803:"8-INDEXED", 0x101004:"16-GRAYSCALE", 0x021005:"16-RGB555", 0x21006:"16-RGB565", 0x61007:"16-ARGB1555", 0x21808:"24-RGB", 0x22009:"32-RGB", 0x26200A:"32-ARGB", 0xE200B:"32-PARGB", 0x10300C:"48-RGB", 0x34400D:"64-ARGB", 0x1A400E:"64-PARGB", 0x200f:"32-CMYK"}
   PixelFormat := 0
   gdipLastError := DllCall("gdiplus\GdipGetImagePixelFormat", "UPtr", pBitmap, "UPtr*", PixelFormat)
   If gdipLastError
      Return -1

   If (mode=0)
      Return PixelFormat

   inHEX := Format("{1:#x}", PixelFormat)
   If (PixelFormatsList.Haskey(inHEX) && mode=2)
      result := PixelFormatsList[inHEX]
   Else
      result := inHEX
   return result
}

Gdip_GraphicsFromImage(pBitmap) {
   pGraphics := 0
   gdipLastError := DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pBitmap, "UPtr*", pGraphics)
   If (gdipLastError=1 && A_LastError=8) ; out of memory
      gdipLastError := 3
   return pGraphics
}

Gdip_DisposeImage(pBitmap, noErr:=1) {
; modified by Marius Șucan to help avoid crashes 
; by disposing a non-existent pBitmap

   If (StrLen(pBitmap)<=2 && noErr=1)
      Return 0

   r := DllCall("gdiplus\GdipDisposeImage", "UPtr", pBitmap)
   If (r=2 || r=1) && (noErr=1)
      r := 0
   Return r
}


Gdip_DeleteGraphics(pGraphics) {
   If (pGraphics!="")
      return DllCall("gdiplus\GdipDeleteGraphics", "UPtr", pGraphics)
}

Gdip_GetEncoderParameterList(pBitmap, pCodec, ByRef EncoderParameters) {
   DllCall("gdiplus\GdipGetEncoderParameterListSize", "UPtr", pBitmap, "UPtr", pCodec, "uint*", nSize)
   VarSetCapacity(EncoderParameters, nSize, 0) ; struct size
   DllCall("gdiplus\GdipGetEncoderParameterList", "UPtr", pBitmap, "UPtr", pCodec, "uint", nSize, "UPtr", &EncoderParameters)
   Return NumGet(EncoderParameters, "UInt") ; number of parameters possible
}

Gdip_GetImageEncoder(Extension, ByRef pCodec) {
; The function returns the handle to the GDI+ image encoder for the given file extension, if it is available
; on error, it returns -1

   Static mimeTypeOffset := 48
        , sizeImageCodecInfo := 76

   nCount := nSize := pCodec := 0
   DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", nCount, "uint*", nSize)
   VarSetCapacity(ci, nSize)
   DllCall("gdiplus\GdipGetImageEncoders", "uint", nCount, "uint", nSize, "UPtr", &ci)

   If !(nCount && nSize)
   {
      ci := ""
      Return -1
   }

   If (A_IsUnicode)
   {
      Loop, % nCount
      {
         idx := (mimeTypeOffset + 7*A_PtrSize) * (A_Index-1)
         sString := StrGet(NumGet(ci, idx + 32 + 3*A_PtrSize), "UTF-16")
         If !InStr(sString, "*" Extension)
            Continue

         pCodec := &ci + idx
         Break
      }
   } 
   Return
}

Gdip_SaveBitmapToFile(pBitmap, sOutput, Quality:=75) {
   nCount := nSize := 0
   pStream := hData := 0
   _p := pCodec := 0

   SplitPath sOutput,,, Extension
   If !RegExMatch(Extension, "^(?i:BMP|DIB|RLE|JPG|JPEG|JPE|JFIF|GIF|TIF|TIFF|PNG)$")
      Return -1

   Extension := "." Extension
   r := Gdip_GetImageEncoder(Extension, pCodec)
   If (r=-1)
      Return -2
   
   If !pCodec
      Return -3

   If (Quality!=75)
   {
      Quality := (Quality < 0) ? 0 : (Quality > 100) ? 100 : Quality
      If RegExMatch(Extension, "^\.(?i:JPG|JPEG|JPE|JFIF)$")
      {
         Static EncoderParameterValueTypeLongRange := 6
         If !(nCount:= Gdip_GetEncoderParameterList(pBitmap, pCodec, EncoderParameters))
            Return -8

         pad := (A_PtrSize = 8) ? 4 : 0
         Loop, % nCount
         {
            elem := (24+A_PtrSize)*(A_Index-1) + 4 + pad
            If (NumGet(EncoderParameters, elem+16, "UInt") = 1) ; number of values = 1
            && (NumGet(EncoderParameters, elem+20, "UInt") = EncoderParameterValueTypeLongRange)
            {
               ; MsgBox, % "nc=" nCount " | " A_Index
               _p := elem + &EncoderParameters - pad - 4
               NumPut(Quality, NumGet(NumPut(4, NumPut(1, _p+0)+20, "UInt")), "UInt")
               Break
            }
         }
      }
   }

   _E := DllCall("gdiplus\GdipSaveImageToFile", "UPtr", pBitmap, "WStr", sOutput, "UPtr", pCodec, "uint", _p ? _p : 0)
   gdipLastError := _E
   Return _E ? -5 : 0
}


Gdip_GetImageDimension(pBitmap, ByRef w, ByRef h) {
   w := 0, h := 0
   If !pBitmap
      Return 2

   return DllCall("gdiplus\GdipGetImageDimension", "UPtr", pBitmap, "float*", w, "float*", h)
}

calcIMGdimensions(imgW, imgH, givenW, givenH, ByRef ResizedW, ByRef ResizedH) {
; This function calculates from original imgW and imgH 
; new image dimensions that maintain the aspect ratio
; and are within the boundaries of givenW and givenH.
;
; imgW, imgH         - original image width and height [in pixels] 
; givenW, givenH     - the width and height to adapt to [in pixels] 
; ResizedW, ResizedH - the width and height resulted from adapting imgW, imgH to givenW, givenH
;                      by keeping the aspect ratio
; function initially written by SBC; modified by Marius Șucan

   PicRatio := Round(imgW/imgH, 5)
   givenRatio := Round(givenW/givenH, 5)
   If (imgW<=givenW && imgH<=givenH)
   {
      ResizedW := givenW
      ResizedH := Round(ResizedW / PicRatio)
      If (ResizedH>givenH)
      {
         ResizedH := (imgH <= givenH) ? givenH : imgH
         ResizedW := Round(ResizedH * PicRatio)
      }   
   } Else If (PicRatio>givenRatio)
   {
      ResizedW := givenW
      ResizedH := Round(ResizedW / PicRatio)
   } Else
   {
      ResizedH := (imgH >= givenH) ? givenH : imgH
      ResizedW := Round(ResizedH * PicRatio)
   }
}

Gdip_ResizeBitmap(pBitmap, givenW, givenH, KeepRatio, InterpolationMode:="", KeepPixelFormat:=0, checkTooLarge:=0, bgrColor:=0) {
; KeepPixelFormat can receive a specific PixelFormat.
; The function returns a pointer to a new pBitmap.
; Default is 0 = 32-ARGB.
; For maximum speed, use 0xE200B - 32-PARGB pixel format.
; Set bgrColor to have a background colour painted.

    If (!pBitmap || !givenW || !givenH)
       Return

    Gdip_GetImageDimension(pBitmap, Width, Height)
    If (KeepRatio=1)
    {
       calcIMGdimensions(Width, Height, givenW, givenH, ResizedW, ResizedH)
    } Else
    {
       ResizedW := givenW
       ResizedH := givenH
    }

    If (((ResizedW*ResizedH>536848912) || (ResizedW>32100) || (ResizedH>32100)) && checkTooLarge=1)
       Return

    PixelFormatReadable := Gdip_GetImagePixelFormat(pBitmap, 2)
    Static PixelFormat := "0xE200B"

    If InStr(PixelFormatReadable, "indexed")
    {
       hbm := CreateDIBSection(ResizedW, ResizedH,,24)
       If !hbm
          Return

       hDC := CreateCompatibleDC()
       If !hDC
       {
          DeleteDC(hdc)
          Return
       }

       obm := SelectObject(hDC, hbm)
       G := Gdip_GraphicsFromHDC(hDC)
       Gdip_SetPixelOffsetMode(G, 2)
       If G
          r := Gdip_DrawImageRect(G, pBitmap, 0, 0, ResizedW, ResizedH)

       newBitmap := !r ? Gdip_CreateBitmapFromHBITMAP(hbm) : ""
       SelectObject(hdc, obm)
       DeleteObject(hbm)
       DeleteDC(hdc)
       Gdip_DeleteGraphics(G)
    } Else
    {
       newBitmap := Gdip_CreateBitmap(ResizedW, ResizedH, PixelFormat)
       If StrLen(newBitmap)>2
       {
          G := Gdip_GraphicsFromImage(newBitmap)
          Gdip_SetPixelOffsetMode(G, 2)
          If G
             r := Gdip_DrawImageRect(G, pBitmap, 0, 0, ResizedW, ResizedH)

          Gdip_DeleteGraphics(G)
          If (r || !G)
          {
             Gdip_DisposeImage(newBitmap, 1)
             newBitmap := ""
          }
       }
    }

    Return newBitmap
}

Gdip_CreateBitmapFromHBITMAP(hBitmap, hPalette:=0) {
   pBitmap := 0
   If !hBitmap
   {
      gdipLastError := 2
      Return
   }

   gdipLastError := DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "UPtr", hBitmap, "UPtr", hPalette, "UPtr*", pBitmap)
   return pBitmap
}

Gdip_SetPixelOffsetMode(pGraphics, PixelOffsetMode) {
   If !pGraphics
      Return 2

   Return DllCall("gdiplus\GdipSetPixelOffsetMode", "UPtr", pGraphics, "int", PixelOffsetMode)
}

Gdip_GraphicsFromHDC(hDC, hDevice:="", InterpolationMode:="", SmoothingMode:="", PageUnit:="", CompositingQuality:="") {
   pGraphics := 0
   If hDevice
      gdipLastError := DllCall("Gdiplus\GdipCreateFromHDC2", "UPtr", hDC, "UPtr", hDevice, "UPtr*", pGraphics)
   Else
      gdipLastError := DllCall("gdiplus\GdipCreateFromHDC", "UPtr", hdc, "UPtr*", pGraphics)

   If (gdipLastError=1 && A_LastError=8) ; out of memory
      gdipLastError := 3

   return pGraphics
}

Gdip_CreateBitmapFromFileSimplified(sFile, useICM:=0) {
   pBitmap := 0
   function2call := (useICM=1) ? "ICM" : ""
   gdipLastError := DllCall("gdiplus\GdipCreateBitmapFromFile" function2call, "WStr", sFile, "UPtr*", pBitmap)
   return pBitmap
}

Gdip_DrawImageRect(pGraphics, pBitmap, X, Y, W, H) {
; X, Y - the coordinates of the destination upper-left corner
; where the pBitmap will be drawn.
; W, H - the width and height of the destination rectangle, where the pBitmap will be drawn.

   return DllCall("gdiplus\GdipDrawImageRect"
            , "UPtr", pGraphics
            , "UPtr", pBitmap
            , "float", X, "float", Y
            , "float", W, "float", H)
}

SelectObject(hdc, hgdiobj) {
   return DllCall("SelectObject", "UPtr", hdc, "UPtr", hgdiobj)
}

DeleteObject(hObject) {
   return DllCall("DeleteObject", "UPtr", hObject)
}

CreateDIBSection(w, h, hdc:="", bpp:=32, ByRef ppvBits:=0, Usage:=0, hSection:=0, Offset:=0) {
; A GDI function that creates a new hBitmap,
; a device-independent bitmap [DIB].
; A DIB consists of two distinct parts:
; a BITMAPINFO structure describing the dimensions
; and colors of the bitmap, and an array of bytes
; defining the pixels of the bitmap. 

   hdc2 := hdc ? hdc : GetDC()
   VarSetCapacity(bi, 40, 0)
   NumPut(40, bi, 0, "uint")
   NumPut(w, bi, 4, "uint")
   NumPut(h, bi, 8, "uint")
   NumPut(1, bi, 12, "ushort")
   NumPut(bpp, bi, 14, "ushort")
   NumPut(0, bi, 16, "uInt")

   hbm := DllCall("CreateDIBSection"
               , "UPtr", hdc2
               , "UPtr", &bi    ; BITMAPINFO
               , "UInt", Usage
               , "UPtr*", ppvBits
               , "UPtr", hSection
               , "UInt", OffSet, "UPtr")

   if !hdc
      ReleaseDC(hdc2)
   return hbm
}

ReleaseDC(hdc, hwnd:=0) {
   return DllCall("ReleaseDC", "UPtr", hwnd, "UPtr", hdc)
}

DeleteDC(hdc) {
   return DllCall("DeleteDC", "UPtr", hdc)
}

CreateCompatibleDC(hdc:=0) {
   return DllCall("CreateCompatibleDC", "UPtr", hdc)
}
