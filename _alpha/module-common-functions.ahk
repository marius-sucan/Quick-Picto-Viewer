calcHistoAvgFile(xBitmap, SortCriterion, thisImgQuality) {
    Gdip_GetImageDimensions(xBitmap, cImgW, cImgH)
    Gdip_GetHistogram(xBitmap, 3, brLvlArray, 0, 0)
    TotalPixelz := cImgW * cImgH
    sumTotalBr := nrPixelz := medianValue := thisSum := 0
    lookValue := stringHistoArray := ""
    Loop, 256
    {
        thisIndex := A_Index - 1
        nrPixelz := brLvlArray[thisIndex]
        If (nrPixelz="")
           Continue

        If InStr(SortCriterion, "median")
           stringHistoArray .= (thisIndex+1) "." nrPixelz "`n"

        sumTotalBr += nrPixelz * (thisIndex+1)
    }

    If InStr(SortCriterion, "median")
    {
       Loop, 256
       {
           lookValue := ST_ReadLine(stringHistoArray, A_Index)
           lookValue := StrSplit(lookValue, ".")
           thisSum += lookValue[2]
           If (thisSum>TotalPixelz//2)
           {
              medianValue := lookValue[1] - 1
              Break
           }
       }
    }

    SortBy := InStr(SortCriterion, "median") ? medianValue ".01" : Round((sumTotalBr/TotalPixelz - 1)/2, 3)
    Return SortBy
}

SaveFIMfile(file2save, pBitmap) {
  initFIMGmodule()
  If !wasInitFIMlib
     Return 1

  hFIFimgA := ConvertPBITMAPtoFIM(pBitmap, hGDIwin)
  If !hFIFimgA
     Return 1

  If FileExist(file2save)
  {
     Try FileSetAttrib, -R, % file2save
     Sleep, 0
     FileMove, % file2save, % file2save "-tmp"
     Sleep, 0
  }

  If RegExMatch(file2save, "i)(.\.(gif|jng|jif|jfif|jpg|jpe|jpeg|ppm|wbm|xpm))$")
  {
     changeMcursor()
     hFIFimgB := FreeImage_ConvertTo(hFIFimgA, "24Bits")
     changeMcursor()
     r := FreeImage_Save(hFIFimgB, file2save)
     FreeImage_UnLoad(hFIFimgB)
  } Else r := FreeImage_Save(hFIFimgA, file2save)

  FreeImage_UnLoad(hFIFimgA)
  If !r
  {
     FileDelete, % file2save
     Sleep, 0
     FileMove, % file2save "-tmp", % file2save
  } Else FileDelete, % file2save "-tmp"

  Return !r3
}

initFIMGmodule() {
  Static firstTimer := 1
  If (wasInitFIMlib!=1)
  {
     r := FreeImage_FoxInit(1) ; Load the FreeImage Dll
     wasInitFIMlib := r ? 1 : 0
  }

  If InStr(r, "err - ")
  {
     alwaysOpenwithFIM := 0
     FIMfailed2init := 1
     If InStr(r, "err - 126")
        friendly := "`n`nPlease install the Rubntime Redistributable Packages of Visual Studio 2013 included in the Quick Picto Viewer ZIP compiled package."
     Else If InStr(r, "err - 404")
        friendly := "`n`nThe FreeImage.dll file seems to be missing..."
     If (firstTimer=1)
     {
        SoundBeep, 300, 900
        triggerOwnDialogs()
        Msgbox, 48, %appTitle%, ERROR: The FreeImage library failed to properly initialize. Some image file formats will no longer be supported. Error code: %r%.%friendly%
     }
  } Else FIMfailed2init := 0

  firstTimer := 0
  Return r
}

FreeImageLoader(imgPath, noBPPconv) {
  Critical, on
  sTime := A_tickcount  
  initFIMGmodule()
  If !wasInitFIMlib
     Return

  noPixels := (noBPPconv=1) ? -1 : 0
  GFT := FreeImage_GetFileType(ImgPath)
  If (GFT=34 && noPixels=0)
     noPixels := (userHQraw=1 && thumbsDisplaying=0) ? 0 : 5

  changeMcursor()
  hFIFimgA := FreeImage_Load(imgPath, -1, noPixels) ; load image
  If !hFIFimgA
     Return

  If (noBPPconv=0 && RenderOpaqueIMG!=1)
     alphaBitmap := FreeImage_GetChannel(hFIFimgA, 4)

  imgBPP := Trim(StrReplace(FreeImage_GetBPP(hFIFimgA), "-"))
  If (imgBPP>32)
  {
     changeMcursor()
     If (noBPPconv=0)
        hFIFimgB := FreeImage_ToneMapping(hFIFimgA, 0, 1.85, 0)
  }

  If (noBPPconv=0)
  {
     ColorsType := FreeImage_GetColorType(hFIFimgA)
     FIMimgBPP := imgBPP " bit [ " ColorsType " ] "
     FIMformat := GFT
  }

  changeMcursor()
  ; If (bwDithering=1 && imgFxMode=4 && doBw=1)
  ;    hFIFimgZ := hFIFimgB ? FreeImage_Dither(hFIFimgB, 0) : FreeImage_Dither(hFIFimgA, 0)
  ; Else
     hFIFimgZ := hFIFimgB ? hFIFimgB : hFIFimgA

  hFIFimgC := hFIFimgZ ? hFIFimgZ : hFIFimgA
  FreeImage_GetImageDimensions(hFIFimgC, imgW, imgH)

  If (noBPPconv=0)
  {
     If alphaBitmap
     {
        hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "32Bits")
        ; ensure the alpha channel does not get lost - reapply it
        ; it sometimes gets lost, I do not know why...
        ; the previously retrieved Alpha channel must 
        ; be converted to Greyscale...
        hFIFimgR := FreeImage_ConvertTo(alphaBitmap, "Greyscale")
        pixelsColorTest1 := FreeImage_GetPixelIndex(hFIFimgR, 2, 2)
        pixelsColorTest2 := FreeImage_GetPixelIndex(hFIFimgR, imgW//2, imgH//2)
        pixelsColorTest3 := FreeImage_GetPixelIndex(hFIFimgR, imgW - 2, imgH - 2)
        If (pixelsColorTest1<20 && pixelsColorTest2<20 && pixelsColorTest3<20)
           mustTestThis := 1
        Else If (pixelsColorTest1>240 && pixelsColorTest2>240 && pixelsColorTest3>240)
           mustTestThis := 2

        If (mustTestThis=1 || mustTestThis=2)
        {
           ; ensure the alpha channel does not render the entire image transparent...
           pvBits := FreeImage_GetBits(hFIFimgR)
           bitmapInfo2 := FreeImage_GetInfo(hFIFimgR)
           testBMP := Gdip_CreateBitmapFromGdiDib(bitmapInfo2, pvBits)
           isUniform := Gdip_TestBitmapUniformity(testBMP, 3, maxLevelIndex, maxLevelPixels)
           If (isUniform=1 && maxLevelIndex<6)
              FreeImage_Invert(hFIFimgR)
           Gdip_DisposeImage(testBMP)
        }
        ; ToolTip, % maxLevelIndex ", " testUniformity " | " pixelsColorTest
        r := FreeImage_SetChannel(hFIFimgD, hFIFimgR, 4)
        FreeImage_PreMultiplyWithAlpha(hFIFimgD)
        FreeImage_UnLoad(hFIFimgR)
        FreeImage_UnLoad(alphaBitmap)
        If (isUniform=1 && mustTestThis=2 && maxLevelIndex>249)
           alphaBitmap := ""
     } Else hFIFimgD := FreeImage_ConvertTo(hFIFimgC, "24Bits")

     hFIFimgE := hFIFimgD ? hFIFimgD : hFIFimgC
;     bmpInfoHeader := FreeImage_GetInfoHeader(hFIFimgE)
     bitmapInfo := FreeImage_GetInfo(hFIFimgE)
     pBits := FreeImage_GetBits(hFIFimgE)
     If alphaBitmap
     {
        nBitmap := Gdip_CreateBitmap(imgW, imgH, 0, imgW*4, pBits)
        Gdip_ImageRotateFlip(nBitmap, 6)
        ; for some reason, nBitmap causes crashes on drawing with Gdip_DrawImage()
        ; in a pGraphics based on a CreateCompatibleDC.
 
        ; the solution I found is to create a new pBitmap
        ; and create a pGraphics based on it and draw into
        ; it the seemingly malformed nBitmap.
        pBitmap := Gdip_CreateBitmap(imgW, imgH)    ; 32-ARGB
     } Else
     {
        nBitmap := Gdip_CreateBitmapFromGdiDib(bitmapInfo, pBits)
        pBitmap := Gdip_CreateBitmap(imgW, imgH, 0x21808)    ; 24-RGB
     }
     G := Gdip_GraphicsFromImage(pBitmap,,,2)
     Gdip_DrawImageFast(G, nBitmap)
     Gdip_DeleteGraphics(G)
     Gdip_DisposeImage(nBitmap)
  } Else pBitmap := Gdip_CreateBitmap(imgW, imgH)

  ; Gdip_GetImageDimensions(pBitmap, imgW2, imgH2)
  imgIDs := hFIFimgA "|" hFIFimgB "|" hFIFimgC "|" hFIFimgD "|" hFIFimgE "|" hFIFimgZ
  Sort, imgIDs, UD|
  Loop, Parse, imgIDs, |
  {
      If A_LoopField
         FreeImage_UnLoad(A_LoopField)
  }

  eTime := A_tickcount - sTime
  ; ToolTip, % imgW ", " imgW2,,,2
  ; Tooltip, % etime "; " noPixels "; " GFT
  ; Tooltip, %r1% -- %r2% -- %pBits% ms ---`n %pbitmap% -- %hbitmap% -- %hfifimg%

  Return pBitmap
}

LoadBitmapFromFileu(imgPath, noBPPconv:=0, forceGDIp:=0) {
  coreIMGzeitLoad := A_TickCount
  If RegExMatch(imgPath, RegExFIMformPtrn) || (alwaysOpenwithFIM=1 && forceGDIp=0)
  {
     oBitmap := FreeImageLoader(imgPath, noBPPconv)
  } Else
  {
     changeMcursor()
     oBitmap := Gdip_CreateBitmapFromFile(imgPath)
     If !oBitmap
        oBitmap := FreeImageLoader(imgPath, noBPPconv)
  }
  Return oBitmap
}

changeMcursor() {
  Static lastInvoked := 1
  If (slideShowRunning!=1) && (A_TickCount - lastInvoked > 300)
  {
     DllCall("user32\SetCursor", "Ptr", hCursBusy)
     lastInvoked := A_TickCount
  }
}

GetImgFileDimension(imgPath, ByRef W, ByRef H, fastWay:=1) {
   Static prevImgPath, prevW, prevH
   thisImgPath := generateThumbName(imgPath, 1) fastWay
   If (prevImgPath=thisImgPath && prevH>1 && prevW>1)
   {
      W := prevW
      H := prevH
      Return 1
   }

   prevImgPath := thisImgPath
   changeMcursor()
   pBitmap := LoadBitmapFromFileu(imgPath, fastWay)
   prevW := W := Gdip_GetImageWidth(pBitmap)
   prevH := H := Gdip_GetImageHeight(pBitmap)
   If pBitmap
      Gdip_DisposeImage(pBitmap, 1)
   Try DllCall("user32\SetCursor", "Ptr", hCursN)
   r := (w>1 && h>1) ? 1 : 0
   Return r
}

minU(val1, val2, val3:="null") {
  a := (val1<val2) ? val1 : val2
  If (val3!="null")
     a := (a<val3) ? a : val3
  Return a
}

maxU(val1, val2, val3:="null") {
  a := (val1>val2) ? val1 : val2
  If (val3!="null")
     a := (a>val3) ? a : val3
  Return a
}

valueBetween(value, inputA, inputB) {
    If (value=inputA || value=inputB)
       Return 1

    testRange := 0
    pointA := minU(inputA, inputB)
    pointB := maxU(inputA, inputB)
    if value between %pointA% and %pointB%
       testRange := 1
    Return testRange
}


ST_ReadLine(String, line, delim="`n", exclude="`r") {
   String := Trim(String, delim)
   StringReplace, String, String, %delim%, %delim%, UseErrorLevel
   TotalLcount := ErrorLevel + 1

   If (abs(line)>TotalLCount && (line!="L" || line!="R" || line!="M"))
      Return 0

   If (Line="R")
      Random, Rand, 1, %TotalLcount%
   Else If (line<=0)
      line := TotalLcount + line

   Loop, Parse, String, %delim%, %exclude%
   {
      out := (Line="R" && A_Index=Rand) ? A_LoopField
           : (Line="M" && A_Index=TotalLcount//2) ? A_LoopField
           : (Line="L" && A_Index=TotalLcount) ? A_LoopField
           : (A_Index=Line) ? A_LoopField : -1
      If (out!=-1) ; Something was found so stop searching.
         Break
   }
   Return out
}

triggerOwnDialogs() {
  If AnyWindowOpen
     Gui, SettingsGUIA: +OwnDialogs
  Else
     Gui, 1: +OwnDialogs
}

generateThumbName(imgPath, forceThis:=0) {
   If (enableThumbsCaching!=1 && forceThis=0)
      Return

   FileGetSize, fileSizu, % imgPath
   FileGetTime, FileDateM, % imgPath, M
   fileInfos := imgPath fileSizu FileDateM
   MD5name := CalcStringHash(fileInfos, 0x8003)
   Return MD5name
}

CalcStringHash(string, algid, encoding = "UTF-8", byref hash = 0, byref hashlength = 0) {
; function by jNizM and Bentschi
; taken from https://github.com/jNizM/HashCalc
; this calculates the MD5 hash
; function under MIT License: https://raw.githubusercontent.com/jNizM/AHK_Network_Management/master/LICENSE

    chrlength := (encoding = "CP1200" || encoding = "UTF-16") ? 2 : 1
    length := (StrPut(string, encoding) - 1) * chrlength
    VarSetCapacity(data, length, 0)
    StrPut(string, &data, floor(length / chrlength), encoding)
    Result := CalcAddrHash(&data, length, algid, hash, hashlength)
    Return Result
}

CalcAddrHash(addr, length, algid, byref hash = 0, byref hashlength = 0) {
; function by jNizM and Bentschi
; taken from https://github.com/jNizM/HashCalc
; function under MIT License: https://raw.githubusercontent.com/jNizM/AHK_Network_Management/master/LICENSE

    Static h := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "a", "b", "c", "d", "e", "f"]
         , b := h.minIndex()
    hProv := hHash := o := ""
    CAC := DllCall("advapi32\CryptAcquireContext", "Ptr*", hProv, "Ptr", 0, "Ptr", 0, "UInt", 24, "UInt", 0xf0000000)
    If CAC
    {
       CCH := DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", algid, "UInt", 0, "UInt", 0, "Ptr*", hHash)
       If CCH
       {
          CHD := DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", addr, "UInt", length, "UInt", 0)
          If CHD
          {
             CGP := DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", 0, "UInt*", hashlength, "UInt", 0)
             If CGP
             {
                VarSetCapacity(hash, hashlength, 0)
                CGHP := DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", &hash, "UInt*", hashlength, "UInt", 0)
                If CGHP
                {
                   Loop, %hashlength%
                   {
                      v := NumGet(hash, A_Index - 1, "UChar")
                      o .= h[(v >> 4) + b] h[(v & 0xf) + b]
                   }
                }
             }
          }
          CDH := DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
       }
       CRC := DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
    }
    Return o
}
