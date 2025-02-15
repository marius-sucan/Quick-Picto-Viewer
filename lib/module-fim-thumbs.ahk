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
Global GDIPToken, MainExe := AhkExported(), runningGDIPoperation := 0, WICmoduleHasInit := 0, allowWICloader := 1
     , mainCompiledPath := "", wasInitFIMlib := 0, listBitmaps := "", userImgQuality := 0, userHQraw := 1
     , operationDone := 1, resultsList := "", FIMfailed2init := 0, thisThreadID := -1, allowToneMappingImg := 1
     , waitDataCollect := 1, operationFailed := 0, RegExWICfmtPtrn, enableThumbsCaching := 1, allowFIMloader := 1
     , cmrRAWtoneMapAlgo, cmrRAWtoneMapParamA, cmrRAWtoneMapParamB, cmrRAWtoneMapOCVparamA, cmrRAWtoneMapOCVparamB
     , cmrRAWtoneMapParamC, cmrRAWtoneMapParamD, cmrRAWtoneMapAltExpo, userPerformColorManagement := 1
     , RegExFIMformPtrn := "i)(.\\*\.(DNG|DDS|EXR|HDR|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f))$"

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
     userImgQuality := externObj[3]
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

capIMGdimensionsFormatlimits(typu, givenSize, keepRatio, ByRef ResizedW, ByRef ResizedH) {
    mpxLimit := thisLimit := 0
    If (typu="given")
    {
       thisLimit := givenSize
       mpxLimit := 2
    } Else 
    {
       thisLimit := 199000
       mpxLimit := 536.7
    }

    ow := ResizedW, oh := ResizedH
    If (keepRatio=1 && thisLimit>1)
    {
       If (max(ResizedW, ResizedH)>thisLimit)
       {
          z := thisLimit/max(ResizedW, ResizedH)
          ResizedW := Floor(ResizedW * z)
          ResizedH := Floor(ResizedH * z)
       }
    } Else If (thisLimit>1)
    {
       ResizedW := (ResizedW>thisLimit) ? thisLimit : ResizedW
       ResizedH := (ResizedH>thisLimit) ? thisLimit : ResizedH
    }

    mpx := Round((ResizedW * ResizedH)/1000000, 1)
    If (mpx>mpxLimit)
    {
       g := 1
       rw := rh := 0
       Loop
       {
          g -= 0.001
          rw := Floor(ResizedW * g)
          rh := Floor(ResizedH * g)
          mpx := Round((rw * rh)/1000000, 1)
          If (mpx<mpxLimit)
             Break
       }
       ResizedW := rw
       ResizedH := rh
    }

    p := ((ResizedW + ResizedH)/2) / ((ow + oh)/2)
    Return p
}

retrieveXMLattributeValue(content, attrib) {
   foundPos := RegExMatch(content, "i)" attrib "=[""']([^""']*)[""']", string)
   If foundPos
      string := SubStr(string, StrLen(attrib) + 2)
   Return Trim(string, """' ")
}

convertSVGunitsToPixels(ByRef length) {
    w := A_ScreenWidth, h := A_ScreenHeight
    base := Round( (w + h)/2 ) * 2
    length := StrReplace(length, A_Space)
    If !length
    {
       length := base "v"
       Return base
    }

    isNumber := 0
    If length Is number
       isNumber := 1

    If (InStr(length, "px") || isNumber=1 && length>0)
       Return StrReplace(length, "px") ; pixels
    Else If InStr(length, "pt")   ; points
       Return Round(StrReplace(length, "pt")*1.33333)
    Else If InStr(length, "pc")   ; picas
       Return Round(StrReplace(length, "pc")*16)
    Else If InStr(length, "cm")   ; centimeters
       Return Round(StrReplace(length, "cm")*37.795275591)
    Else If InStr(length, "mm")   ; milimeters
       Return Round(StrReplace(length, "mm")*3.7795275591)
    Else If InStr(length, "in")   ; inches
       Return Round(StrReplace(length, "in")*96)
    Else If InStr(length, "vw")   ; viewport width
       Return w*2
    Else If InStr(length, "vh")   ; viewport height
       Return h*2
    Else If InStr(length, "vmin")   ; viewport minimum
       Return min(w, h)*2
    Else If InStr(length, "vmax")   ; viewport maximum
       Return max(w, h)*2
    Else If InStr(length, "%")
       Return Round(clampInRange(StrReplace(length, "%")/200, 0.1, 1) * max(w, h)) * 3
    Else
    {
       length := base "v"
       Return base
    }
}

RenderSVGfile(imgPath, gw, hh) {
   startZeit := A_TickCount
   FileRead, content, % imgPath
   If !content
      Return

   foundPos := RegExMatch(content, "i)\<svg.*")
   svgRoot := SubStr(content, foundPos, InStr(content, ">", 0, foundPos + 1) - foundPos + 1)
   width := retrieveXMLattributeValue(svgRoot, "width")
   height := retrieveXMLattributeValue(svgRoot, "height")
   ver := retrieveXMLattributeValue(svgRoot, "version")
   ow := w := convertSVGunitsToPixels(width)
   oh := h := convertSVGunitsToPixels(height)
   capIMGdimensionsFormatlimits("given", max(gw, gh), 1, w, h)
   fscaleX := varContains(width, "v", "%") ? 1 : Round(w/ow, 6)
   If InStr(width, "%")
      fscaleX := StrReplace(width, "%")>100 ? 100 / StrReplace(width, "%") : 1

   fscaleY := varContains(height, "v", "%") ? 1 : Round(h/oh, 6)
   If InStr(height, "%")
      fscaleY := StrReplace(height, "%")>100 ? 100 / StrReplace(height, "%") : 1
   ; ToolTip, % width "|" svgRoot "|" , , , 2
   pBitmap := DllCall("qpvmain.dll\LoadSVGimage", "Int", thisThreadID ,"Int", w, "Int", h, "float", fscaleX, "float", fscaleY, "Str", imgPath, "UPtr")
   ; ToolTip, % fscaleX "|" fscaleY "|" w "|" h "|" svgRoot "|" , , , 2
   ; fnOutputDebug("RenderSVGfile: " A_TickCount - startZeit)
   return pBitmap
}

RenderPDFpage(imgPath, noBPPconv, frameu, pwd:="", maxW:=0, maxH:=0, dpi:=450, ByRef pageCount:=0, ByRef errorType:=0, fillBgr:=1, bgrColor:="ffffff") {
    If (noBPPconv=1)
       pageCount := -6

    errorType := -100
    pBitmap := DllCall("qpvmain.dll\RenderPdfPageAsBitmap", "WStr", Trimmer(imgPath), "Int", frameu, "float", dpi, "int*", maxW, "int*", maxH, "int", fillBgr, "int", "0xff" bgrColor, "int*", pageCount, "int*", errorType, "Str", pwd, "UPtr", 0, "int", 1, "UPtr")
    If StrLen(pBitmap)>2
       Return pBitmap
}

LoadWICimage(imgPath, w, h, keepAratio, thisImgQuality, frameu, ScaleAnySize) {
   If RegExMatch(imgPath, "i)(.\.(svg))$")
      Return RenderSVGfile(imgPath, w, h)
   Else If RegExMatch(imgPath, "i)(.\.pdf)$")
      Return RenderPDFpage(imgPath, 0, 0, "", w, h, 250)

   VarSetCapacity(resultsArray, 8 * 9, 0)
   fimu := (wasInitFIMlib=1 && allowFIMloader=1) ? 1 : 0
   func2exec := (A_PtrSize=8) ? "LoadWICimage" : "_LoadWICimage@48"
   r := DllCall("qpvmain.dll\" func2exec, "Int", thisThreadID, "Int", 0, "Int", thisImgQuality, "Int", w, "Int", h, "int", keepAratio, "int", ScaleAnySize, "int", frameu, "int", 0, "int", userPerformColorManagement, "Str", imgPath, "UPtr*", &resultsArray, "int", fimu, "UPtr")
   resultsArray := ""
   Return r
}

cleanMess(thisID:=0, params:=0) {
   Critical, on
   optionz := StrSplit(params, "|")
   If (InStr(params, "|")>1 && optionz.count()>12)
   {
      ; fnOutputDebug("thumbs thread settings defined")
      enableThumbsCaching := optionz[1]
      userHQraw := optionz[2]
      allowToneMappingImg := optionz[3]
      allowWICloader := optionz[4]
      userImgQuality := optionz[5]
      cmrRAWtoneMapAlgo := optionz[6]
      cmrRAWtoneMapParamA := optionz[7]
      cmrRAWtoneMapParamB := optionz[8]
      cmrRAWtoneMapParamC := optionz[9]
      cmrRAWtoneMapParamD := optionz[10]
      cmrRAWtoneMapOCVparamA := optionz[11]
      cmrRAWtoneMapOCVparamB := optionz[12]
      cmrRAWtoneMapAltExpo := optionz[13]
      userPerformColorManagement := optionz[14]
      allowFIMloader := optionz[15]
   }

   waitDataCollect := 1
   cleaned := 0
   Sort, listBitmaps, UD|
   Loop, Parse, listBitmaps, |
   {
       cleaned++
       Gdip_DisposeImage(A_LoopField, 1)
   }

   ; fnOutputDebug("ThumbsMode. " A_ThisFunc ":() #" thisID ". " cleaned " bitmaps disposed.")
   listBitmaps := ""
   waitDataCollect := 0
   operationFailed := 0
   operationDone := 1
}

fnOutputDebug(msg) {
   OutputDebug, QPV: Thread #%thisThreadID%: %msg%
}

varContains(value, vals*) {
   yay := 0
   for index, param in vals
   {
       If InStr(value, param)
       {
          yay := 1
          Break
       }
   }
   Return yay
}

isVarEqualTo(value, vals*) {
   yay := 0
   for index, param in vals
   {
       If (value=param)
       {
          yay := 1
          Break
       }
   }
   Return yay
}

MonoGenerateThumb(imgPath, file2save, params, thisBindex) {
   Critical, on
   optionz := StrSplit(params, "|")
   thumbsSizeQuality := optionz[1]
   timePerImg := optionz[2]
   coreIndex := optionz[3]
   thisFileIndex := optionz[4]

   operationDone := hFIFimgA := finalBitmap := 0
   waitDataCollect := operationFailed := 0
   startZeit := A_TickCount
   resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
   ; RegWrite, REG_SZ, %QPVregEntry%, thumbThreadDone%coreIndex%, 0
   excludeFIMs := (wasInitFIMlib=1 && allowFIMloader=1) ? RegExMatch(imgPath, RegExFIMformPtrn) : 0
   If (RegExMatch(imgPath, RegExWICfmtPtrn) && WICmoduleHasInit=1 && allowWICloader=1 && !excludeFIMs)
   {
      thisImgQuality := (imgQuality=1) ? 7 : 5
      finalBitmap := LoadWICimage(imgPath, thumbsSizeQuality, thumbsSizeQuality, 1, thisImgQuality, 3, 0)
      thisZeit := A_TickCount - startZeit
      If (enableThumbsCaching=1 && thisZeit>timePerImg && StrLen(finalBitmap)>2)
         r := Gdip_SaveBitmapToFile(finalBitmap, file2save)
   }

   If (StrLen(finalBitmap)<3 && wasInitFIMlib=1 && allowFIMloader=1)
   {
      r := imgPath
      GFT := FreeImage_GetFileType(r)
      loadArgs := 0
      If (GFT=34 && loadArgs=0 && RegExMatch(r, "i)(.\.(dng))$"))
         loadArgs := (userHQraw=1) ? 0 : 2
      Else If (GFT=34 && loadArgs=0)
         loadArgs := (userHQraw=1) ? 0 : 1
      Else If (GFT=2 && loadArgs=0)
         loadArgs := 8

      hFIFimgA := FreeImage_Load(r, -1, loadArgs)
      If !hFIFimgA
      {
         operationDone := 1
         waitDataCollect := 1
         operationFailed := 1
         resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
         fnOutputDebug("failed to load bitmap file: " r)
         Return -1
      }

      FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
      bad := (!imgW || !imgH || imgW=1 && imgH=1) ? 1 : 0
      calcIMGdimensions(imgW, imgH, thumbsSizeQuality, thumbsSizeQuality, ResizedW, ResizedH)
      resizeFilter := (ResizeQualityHigh=1) ? 3 : 0
      if (bad=0)
         hFIFimgX := trFreeImage_Rescale(hFIFimgA, ResizedW, ResizedH, resizeFilter)

      FreeImage_UnLoad(hFIFimgA)
      If StrLen(hFIFimgX)>1
      {
         hFIFimgA := hFIFimgX
      } Else
      {
         ; fnOutputDebug(enableThumbsCaching " - " thumbsSizeQuality "px - " timePerImg "ms - core" coreIndex " - file" thisfileIndex " - loopIndex" thisBindex " - " imgPath)
         operationDone := 1
         waitDataCollect := 1
         operationFailed := 1
         resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
         fnOutputDebug("failed to rescale bitmap: " r)
         Return -1
      }

      ColorsType := FreeImage_GetColorType(hFIFimgA)
      imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
      PixelFormat := FreeImage_GetImageType(hFIFimgA, 1)
      If InStr(PixelFormat, "UINT16")
      {
         hFIFimgKOE := FreeImage_ConvertTo(hFIFimgA, "Greyscale")
         If hFIFimgKOE
         {
            FreeImage_UnLoad(hFIFimgA)
            hFIFimgA := hFIFimgKOE
            hFIFimgDOE := FreeImage_ConvertTo(hFIFimgA, "24Bits")
            If hFIFimgDOE
            {
               FreeImage_UnLoad(hFIFimgA)
               hFIFimgA := hFIFimgDOE
            } else
            {
               operationDone := 1
               waitDataCollect := 1
               operationFailed := 1
               resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
               fnOutputDebug("failed to convert UINT16//Greyscale bitmap to 24 bits: " r)
               Return -1
            }
         } Else
         {
            operationDone := 1
            waitDataCollect := 1
            operationFailed := 1
            resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
            fnOutputDebug("failed to convert UINT16 bitmap to Greyscale/8-bits: " r)
            Return -1
         }
      }

      thisAllow := (isVarEqualTo(GFT, 32, 26, 29) && imgBPP>32) ? 1 : allowToneMappingImg
      mustApplyToneMapping := (imgBPP>32 && !InStr(ColorsType, "rgba") && GFT!=13) || (imgBPP>64) ? 1 : 0
      If (mustApplyToneMapping=1 && thisAllow=1)
      {
         If (!InStr(PixelFormat, "RGBF") && cmrRAWtoneMapAlgo>2)
         {
            hFIFimgD := FreeImage_ConvertTo(hFIFimgA, "RGBF")
            If hFIFimgD
            {
               ; fnOutputDebug("converted to RGBF")
               FreeImage_UnLoad(hFIFimgA)
               hFIFimgA := hFIFimgD
            }
         }
 
         PixelFormat := FreeImage_GetImageType(hFIFimgA, 1)
         If (cmrRAWtoneMapAlgo>2 && InStr(PixelFormat, "RGBF"))
            hFIFimgB := OpenCV_FimToneMapping(hFIFimgA, cmrRAWtoneMapAlgo - 3, cmrRAWtoneMapOCVparamA, cmrRAWtoneMapOCVparamB, cmrRAWtoneMapParamC, cmrRAWtoneMapParamD, PixelFormat, cmrRAWtoneMapAltExpo)
         If !hFIFimgB
            hFIFimgB := FreeImage_ToneMapping(hFIFimgA, clampInRange(cmrRAWtoneMapAlgo - 1, 0, 1), cmrRAWtoneMapParamA, cmrRAWtoneMapParamB)
 
         FreeImage_UnLoad(hFIFimgA)
         If !hFIFimgB
         {
            ; fnOutputDebug(enableThumbsCaching " - " thumbsSizeQuality "px - " timePerImg "ms - core" coreIndex " - file" thisfileIndex " - loopIndex" thisBindex " - " imgPath)
            operationDone := 1
            waitDataCollect := 1
            operationFailed := 1
            resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
            fnOutputDebug("failed to apply tone-mapping on HDR image file: " r)
            Return -1
         }
         hFIFimgA := hFIFimgB
      }

      FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
      If (imgW!=ResizedW || imgH!=ResizedH)
      {
         ; hFIFimgB := FreeImage_MakeThumbnail(hFIFimgA, thumbsSizeQuality, 0)
         hFIFimgB := trFreeImage_Rescale(hFIFimgA, ResizedW, ResizedH, resizeFilter)
         FreeImage_UnLoad(hFIFimgA)
         If StrLen(hFIFimgB)>1
         {
            hFIFimgA := hFIFimgB
         } Else
         {
            ; fnOutputDebug(enableThumbsCaching " - " thumbsSizeQuality "px - " timePerImg "ms - core" coreIndex " - file" thisfileIndex " - loopIndex" thisBindex " - " imgPath)
            operationDone := 1
            operationFailed := 1
            waitDataCollect := 1
            resultsList := operationDone "|" finalBitmap "|" thisfileIndex "|" coreIndex "|" thisBindex
            fnOutputDebug("failed to rescale bitmap [second attempt]: " r)
            Return -1
         }
      }

      If StrLen(hFIFimgA)>1
      {
         imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
         thisZeit := A_TickCount - startZeit
         If (imgBPP!=24 || imgBPP!=32)
         {
            hFIFimgB := FreeImage_ConvertTo(hFIFimgA, "24Bits")
            If hFIFimgB
            {
               FreeImage_UnLoad(hFIFimgA)
               hFIFimgA := hFIFimgB
            }
         }

         If (enableThumbsCaching=1 && thisZeit>timePerImg)
            savedFile := FreeImage_Save(hFIFimgA, file2save)
         Else savedFile := "yeah"

         finalBitmap := ConvertFimObj2pBitmap(hFIFimgA, ResizedW, ResizedH)
         FreeImage_UnLoad(hFIFimgA)
         If (finalBitmap && thisZeit>timePerImg && enableThumbsCaching=1 && !savedFile)
         {
            r := Gdip_SaveBitmapToFile(finalBitmap, file2save)
            ; SoundBeep , 900, 100
         } Else If (!finalBitmap && enableThumbsCaching=1 && savedFile)
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

gdipMonoGenerateThumb(imgPath, file2save, enableThumbsCaching, thumbsSizeQuality, resizeFilter, coreIndex, thisfileIndex, thisBindex) {
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

   If hFIFimgA
   {
      thisZeit := A_TickCount - startZeit
      If (enableThumbsCaching=1 && thisZeit>225)
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

ConvertFimObj2pBitmap(hFIFimgA, w, h) {
  ; hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "24Bits")
  If StrLen(hFIFimgA)<3
     Return

  pBits := FreeImage_GetBits(hFIFimgA)
  If !pBits
     Return

  bpp := FreeImage_GetBPP(hFIFimgA)
  If (bpp=32)
  {
     FreeImage_FlipVertical(hFIFimgA)
     Stride := FreeImage_GetPitch(hFIFimgA)
     nBitmap := Gdip_CreateBitmap(w, h, "0x26200A", Stride, pBits)
  } Else
  {
     bitmapInfo := FreeImage_GetInfo(hFIFimgA)
     nBitmap := Gdip_CreateBitmapFromGdiDib(bitmapInfo, pBits)
  }

  If !nBitmap
     Return

  pBitmap := Gdip_CloneBitmapArea(nBitmap, 0, 0, w, h, "0xE200B")
  Gdip_DisposeImage(nBitmap)
  Return pBitmap
}

OpenCV_FimToneMapping(hFIFimgA, algo, paramA, paramB, paramC, paramD, PixelFormat, altExpo) {
; apply tone mapping on HDR image using OpenCV instead of FreeImage. It is much faster.
    If !hFIFimgA
    {
       fnOutputDebug(A_ThisFunc "(): failed to perform tone-mapping, undefined bitmap object")
       Return 0
    }

    FreeImage_GetImageDimensions(hFIFimgA, Width, Height)
    If (!Width || !Height)
    {
       fnOutputDebug(A_ThisFunc "(): failed to perform tone-mapping; incorrect FreeImage bitmap provided")
       Return 0
    }

    hFIFimgX := FreeImage_Allocate(Width, Height, 24)
    If !hFIFimgX
    {
       fnOutputDebug(A_ThisFunc "(): failed to perform tone-mapping; unable to allocate new FreeImage bitmap object")
       Return 0
    }
  
    pBits := FreeImage_GetBits(hFIFimgX)
    pBitsAll := FreeImage_GetBits(hFIFimgA)
    hStride := FreeImage_GetPitch(hFIFimgA)
    lStride := FreeImage_GetPitch(hFIFimgX)
    r := DllCall("qpvmain.dll\openCVapplyToneMappingAlgos", "UPtr", pBitsAll, "int", hStride, "int", width, "int", height, "UPtr", pBits, "int", lStride, "int", algo, "float", paramA, "float", paramB, "float", paramC, "float", paramD, "int", altExpo)
    If !r 
    {
       fnOutputDebug(A_ThisFunc "(): failed to perform tone-mapping; opencv or qpv dll failure occured")
       FreeImage_UnLoad(hFIFimgX)
       Return 0
    }
    Return hFIFimgX
}

OpenCV_FimResizeBitmap(hFIFimgA, resizedW, resizedH, rx, ry, rw, rh, InterpolationMode:="") {
; resize image using OpenCV instead of FreeImage. It is much faster.

    If (!hFIFimgA || !resizedW || !resizedH)
    {
       fnOutputDebug(A_ThisFunc "(): failed to resize bitmap; incorrect bitmap provided")
       Return 0
    }

    FreeImage_GetImageDimensions(hFIFimgA, Width, Height)
    If (Width=resizedW && Height=resizedH && rx=0 && ry=0)
       Return FreeImage_Clone(hFIFimgA)

    If (!Width || !Height)
    {
       fnOutputDebug(A_ThisFunc "(): failed to resize bitmap; incorrect FreeImage bitmap provided")
       Return 0
    }

    thisStartZeit := A_TickCount
    PixelFormat := FreeImage_GetImageType(hFIFimgA, 0)
    bpp := Trimmer(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
    If (PixelFormat=1 && bpp<24 || !PixelFormat || isInRange(PixelFormat, 2, 8))
    {
       fnOutputDebug(A_ThisFunc "(): failed to resize bitmap; unsupported FreeImage bitmap provided; PixelFormat=" PixelFormat)
       Return 0
    }

    hFIFimgX := FreeImage_Allocate(ResizedW, ResizedH, bpp, PixelFormat)
    If !hFIFimgX
    {
       fnOutputDebug(A_ThisFunc "(): failed to resize bitmap; unable to allocate new FreeImage bitmap object")
       Return 0
    }

    If !rw
       rw := Width
    If !rh
       rh := Height

    pBits := FreeImage_GetBits(hFIFimgX)
    mStride := FreeImage_GetPitch(hFIFimgX) 
    pBitsAll := FreeImage_GetBits(hFIFimgA)
    Stride := FreeImage_GetPitch(hFIFimgA)
    r := DllCall("qpvmain.dll\openCVresizeBitmapExtended", "UPtr", pBitsAll, "UPtr", pBits, "Int", width, "Int", height, "Int", stride, "Int", rx, "Int", ry, "Int", rw, "Int", rh, "Int", resizedW, "Int", resizedH, "Int", mstride, "Int", bpp, "Int", InterpolationMode)
    ; fnOutputDebug(A_ThisFunc "(): " A_TickCount - thisStartZeit)
    If !r 
    {
       PixelFormat := FreeImage_GetImageType(hFIFimgX, 0)
       bpp := Trimmer(StrReplace(FreeImage_GetBPP(hFIFimgX), "-"))
       fnOutputDebug(A_ThisFunc "(): failed to resize bitmap; opencv or qpv dll failure occured: " PixelFormat " | " bpp " | " hFIFimgX)
       FreeImage_UnLoad(hFIFimgX)
       Return 0
    }
    Return hFIFimgX
}

trFreeImage_Rescale(hImage, w, h, filter:=3) {
   a := OpenCV_FimResizeBitmap(hImage, w, h, 0, 0, 0, 0, filter)
   If !a
      a := FreeImage_Rescale(hImage, w, h, filter)
   Return a
}

clampInRange(value, min, max, reverse:=0) {
   If (reverse=1)
   {
      If (value>max)
         value := min
      Else If (value<min)
         value := max
   } Else
   {
      If (value>max)
         value := max
      Else If (value<min)
         value := min
   }

   Return value
}

Trimmer(string, whatTrim:="") {
   If (whatTrim!="")
      string := Trim(string, whatTrim)
   Else
      string := Trim(string, "`r`n `t`f`v`b")
   Return string
}

isInRange(value, inputA, inputB) {
    If (value=inputA || value=inputB)
       Return 1

    Return (value>=min(inputA, inputB) && value<=max(inputA, inputB)) ? 1 : 0
}


; external functions
; freeimage library functions 

FreeImage_Allocate(width, height, bpp:=32, imageType:=1, red_mask:=0xFF000000, green_mask:=0x00FF0000, blue_mask:=0x0000FF00) {
; function useful to create a new / empty bitmap
; for imageType see FreeImage_GetImageType()
   Return DllCall(getFIMfunc("AllocateT"), "int", imageType, "int", width, "int", height, "int", bpp, "uint", red_mask, "uint", green_mask, "uint", blue_mask, "uptr")
}

FreeImage_GetInfo(hImage) {
   Return DllCall(getFIMfunc("GetInfo"), "uptr", hImage, "uptr")
}

FreeImage_GetBits(hImage) {
   Return DllCall(getFIMfunc("GetBits"), "uptr", hImage, "uptr")
}

FreeImage_GetPitch(hImage) {
   Return DllCall(getFIMfunc("GetPitch"), "uptr", hImage, "int")
}

FreeImage_ConvertTo(hImage, MODE) {
   If !hImage
      Return

   If (mode="16bits")
      mode := "16Bits565"

   Return DllCall(getFIMfunc("ConvertTo" MODE), "uptr", hImage, "uptr")
}

FreeImage_Clone(hImage) {
   If (hImage="")
      Return

   Return DllCall(getFIMfunc("Clone"), "uptr", hImage, "uptr")
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

FreeImage_FlipVertical(hImage) {
   Return DllCall(getFIMfunc("FlipVertical"), "uptr", hImage)
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

FreeImage_GetImageType(hImage, humanReadable:=0) {
   Static imgTypes := {0:"UNKNOWN", 1:"Standard Bitmap", 2:"UINT16 [16-bit]", 3:"INT16 [16-bit]", 4:"UINT32 [32-bit]", 5:"INT32 [32-bit]", 6:"FLOAT [32-bit]", 7:"DOUBLE [64-bit]", 8:"COMPLEX [2x64-bit]", 9:"RGB16 [48-bit]", 10:"RGBA16 [64-bit]", 11:"RGBF [96-bit]", 12:"RGBAF [128-bit]"}
   r := DllCall(getFIMfunc("GetImageType"), "uptr", hImage)
   If (humanReadable=1 && imgTypes.HasKey(r))
      r := imgTypes[r]
   Return r
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

Gdip_CloneBitmapArea(pBitmap, x, y, w, h, PixelFormat:="0x26200A") {
   If (pBitmap="")
      Return

   gdipLastError := DllCall("gdiplus\GdipCloneBitmapArea"
               , "float", x, "float", y
               , "float", w, "float", h
               , "int", PixelFormat
               , "UPtr", pBitmap
               , "UPtr*", pBitmapDest)

   return pBitmapDest
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
