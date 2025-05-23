﻿
Class screenQPVimage {
   Static noIdea := "yep"
   __New() {
      Sleep, -1 
   }
   __Delete() {
      This.DiscardImage()
   }

   LoadImage(imgPath, frameu, noBMP:=0, externMode:=0, externHandle:=0, forceLoader:=0) {
      ; If ((RegExMatch(imgPath, RegExFIMformPtrn) || alwaysOpenwithFIM=1) && allowFIMloader=1)
      If (imgPath && allowFIMloader=1 && externMode=0 || forceLoader=1 && externMode=1)
      {
         r := This.LoadFreeImageFile(imgPath, frameu, noBMP, externMode, externHandle)
      ; Else If (RegExMatch(imgPath, RegExWICfmtPtrn) && WICmoduleHasInit=1 && allowWICloader=1)
      } Else If (imgPath && externMode=1 || forceLoader=2 && externMode=1)
      {
         r := This.LoadWICfile(imgPath, frameu, noBMP, externMode, externHandle)
         ; ToolTip, % "l=" r "|" externMode "|" forceLoader , , , 2
         ; SoundBeep 900, 1000
      }
      Return r
   }

   ImageGetRect(x, y, w, h) {
      If (This.LoadedWith="FIM")
         r := This.FimGetRect(x, y, w, h, 0, 0)
      Else If (This.LoadedWith="WIC")
         r := This.WicGetRect(x, y, w, h, 0, 0)
      Return r
   }

   ImageGetResizedRect(x, y, w, h, newW, newH, highQuality) {
      If (This.LoadedWith="FIM")
         r := This.FimGetRect(x, y, w, h, newW, newH, highQuality)
      Else If (This.LoadedWith="WIC")
         r := This.WicGetRect(x, y, w, h, newW, newH)
      Return r
   }

   DiscardImage(disposeBuffer:=1) {
      If (This.imgHandle)
      {
         If (This.LoadedWith="FIM")
         {
            FreeImage_UnLoad(This.imgHandle)
         } Else If (This.LoadedWith="WIC")
            r := DllCall(whichMainDLL "\WICdestroyPreloadedImage", "Int", 12, "Int")

         If (This.FimBuffer!="" && disposeBuffer=1)
         {
            DllCall("GlobalFree", "uptr", This.FimBuffer)
            This.FimBuffer := ""
         }

         This.imgHandle := ""
         This.ImgFile := ""
         This.actions := 0
         killQPVscreenImgSection()
         If (disposeBuffer!=1)
            Return This.FimBuffer
      }
   }

   FimGetRect(x, y, w, h, newW, newH, highQuality) {
     ; mgpx := Round((w * h)/1000000, 1)
     ; FreeImage_GetImageDimensions(This.imgHandle, zw, zh)
     ; fnOutputDebug(A_ThisFunc "(): " zw "|" zh "||" x2 "|" y2 "||" x "|" y "|" mgpx)
     thisStartZeit := A_TickCount
     interpo := (highQuality=1) ? 3 : 0
     FreeImage_GetImageDimensions(this.imgHandle, ow, oh)
     ay := oh - y
     by := oh - (y + h)
     ny := min(ay, by)
     hFIFimgZ := OpenCV_FimResizeBitmap(This.imgHandle, newW, newH, x, ny, w, h, interpo)
     If !hFIFimgZ
        hFIFimgZ := FreeImage_RescaleRect(This.imgHandle, newW, newH, x, y, w, h, interpo)
     ; fnOutputDebug(A_ThisFunc "(): " A_TickCount - thisStartZeit)
     If !hFIFimgZ
        Return 0

     If InStr(This.FIMtype, "UINT16")
     {
        hFIFimgKOE := FreeImage_ConvertToGreyscale(hFIFimgZ)
        If hFIFimgKOE
        {
           FreeImage_UnLoad(hFIFimgZ)
           hFIFimgZ := hFIFimgKOE
           hFIFimgDOE := FreeImage_ConvertTo(hFIFimgZ, "24Bits")
           If hFIFimgDOE
           {
              FreeImage_UnLoad(hFIFimgZ)
              hFIFimgZ := hFIFimgDOE
           }
        }
     }

     If (This.FIMgft=0 && InStr(This.FIMcolors, "rgba"))
        alphaBitmap := FreeImage_GetChannel(hFIFimgZ, 4)

     imgBPP := Trimmer(StrReplace(FreeImage_GetBPP(hFIFimgZ), "-"))
     If (imgBPP!=32)
        hFIFimgX := FreeImage_ConvertTo(hFIFimgZ, "32Bits")

     hFIFimgE := hFIFimgX ? hFIFimgX : hFIFimgZ
     If alphaBitmap
     {
        This.HasAlpha := FIMalphaChannelFix(alphaBitmap, hFIFimgE)
        ; image object discarded by FIMalphaChannelFix()
     }
     ; FreeImage_PreMultiplyWithAlpha(hFIFimgE)
     pBitmap := ConvertFIMtoPBITMAP(hFIFimgE)
     If hFIFimgX
        FreeImage_UnLoad(hFIFimgX)

     FreeImage_UnLoad(hFIFimgZ)
     ; ToolTip, % pBitmap "|"  hFIFimgE "|" hFIFimgZ "|" x "|" y "|" w "|" h "|" newW "|" newH , , , 2
     If StrLen(pBitmap)>2
        recordGdipBitmaps(pBitmap, A_ThisFunc)

     Return pBitmap
   }

   LoadFreeImageFile(imgPath, frameu, noBMP:=0, externMode:=0, externHandle:=0, qualityRaw:=0) {
     sTime := A_TickCount
     loadArgs := FIMdecideLoadArgs(imgPath, qualityRaw, GFT)
     If (noBMP=1)
        GFT := -1  ; FIF_LOAD_NOPIXELS

     This.Frames := 0
     This.ActiveFrame := 0
     changeMcursor()
     If (externMode=0)
     {
         If ((GFT=18 || GFT=25) && noBMP=0)
         {
            ; open multi-page GIF and TIFFs
            multiFlags := (GFT=25) ? 2 : 0
            hMultiBMP := FreeImage_OpenMultiBitmap(imgPath, GFT, 0, 1, 1, multiFlags)
         }

         If StrLen(hMultiBMP)>1
         {
            hasOpenedMulti := 1
            tFrames := FreeImage_GetPageCount(hMultiBMP)
            If (tFrames<2 || !tFrames)
               tFrames := 0

            If (tFrames>1)
            {
               This.Frames := tFrames
               fimMultiPage := (GFT=18) ? "tiff" : "gif"
               frameu := clampInRange(frameu, 0, tFrames - 1)
               hPage := FreeImage_LockPage(hMultiBMP, frameu)
               If (hPage!="")
               {
                  hFIFimgA := FreeImage_Clone(hPage)
                  If hFIFimgA
                     hasMultiTrans := FreeImage_GetTransparencyCount(hFIFimgA)

                  FreeImage_UnlockPage(hMultiBMP, hPage, 0)
               }
               ; ToolTip, % hasMultiTrans "==" frameu "==" frameu , , , 2
               FreeImage_CloseMultiBitmap(hMultiBMP, 0)
               This.ActiveFrame := frameu
            } Else
            {
               FreeImage_CloseMultiBitmap(hMultiBMP, 0)
               hFIFimgA := FreeImage_Load(imgPath, GFT, loadArgs) ; load image
            }
         } Else hFIFimgA := FreeImage_Load(imgPath, GFT, loadArgs) ; load image
     } Else
     {
         hFIFimgA := externHandle[1]
         This.ActiveFrame := frameu
         This.Frames := (externHandle[2]>1) ? externHandle[2] : 0
     }

     If !hFIFimgA
        Return 0

     ; SoundBeep , 900, 100
     FreeImage_GetImageDimensions(hFIFimgA, imgW, imgH)
     FreeImage_GetDPIresolution(hFIFimgA, dpiX, dpiY)
     oimgBPP := FreeImage_GetBPP(hFIFimgA)
     imgBPP := Trimmer(StrReplace(oimgBPP, "-"))
     ColorsType := FreeImage_GetColorType(hFIFimgA)
     imgType := FreeImage_GetImageType(hFIFimgA, 1)
     ; msgbox, % GFT "=l=" mustApplyToneMapping
     ; fnOutputDebug(A_ThisFunc "(): " imgBPP "|" ColorsType "|" imgType "|" mustApplyToneMapping "|" GFT "|" imgPath)
     If (noBMP=0)
        hFIFimgA := FIMapplyToneMapper(hFIFimgA, GFT, imgBPP, ColorsType, 1, toneMapped)

     fileType := FreeImage_GetFileType(imgPath, 1)
     If (fileType="raw" && qualityRaw!=1)
     {
        fileType .= " [LOW QUALITY]"
        If !toneMapped
           toneMapped := " (TONE-MAPPABLE)"
     }

     imgTypeID := FreeImage_GetImageType(hFIFimgA, 0)
     If isInRange(imgTypeID, 2, 8)
        Channels := 1
     Else If InStr(ColorsType, "rgba")
        Channels := 4
     Else If (InStr(ColorsType, "rgb") || InStr(ColorsType, "cmyk"))
        Channels := 3
 
     This.ImgFile := imgPath
     This.imgHandle := hFIFimgA
     This.HasAlpha := (InStr(ColorsType, "rgba") || hasMultiTrans) ? 1 : 0
     This.RawFormat := fileType " | " imgType
     This.PixelFormat := StrReplace(oimgBPP, "-", "+") "-" ColorsType toneMapped
     This.ClrInfo := oimgBPP "-bit " ColorsType
     This.OpenedWith := "FreeImage library [FIM]"
     This.LoadedWith := "FIM"
     This.TooLargeGDI := 0 ; isImgSizeTooLarge(imgW, imgH)
     This.Width := imgW
     This.Height := imgH
     This.dpiX := dpiX
     This.dpiY := dpiY
     This.DPI := Round((dpiX + dpiY)/2)
     This.FIMcolors := ColorsType
     This.FIMtype := imgType
     This.FIMbpp := imgBPP
     This.FIMgft := GFT
     This.FimBuffer := externHandle[3]
     This.BPP := imgBPP
     This.Channels := Channels
     This.actions := 0
     Return 1
   } ; // LoadFimFile

   WicGetRect(x, y, w, h, newW, newH) {
      mustClip := (x=0 && y=0 && w=This.Width && h=This.Height) ? 0 : 1
      func2exec := (A_PtrSize=8) ? "WICgetRectImage" : "_LoadWICimage@48"
      If !newW
         newW := w
      If !newH
         newH := h

      resizeQuality := 0
      useICM := userPerformColorManagement
      ; Known bug: the act of resizing the rect retrieved from the main image
      ; breaks color management when activated...
      ; the bitmap scaler of WIC found in coreWICgetRectImage() messes things up...
      ; I could use OpenCV, but as of now, QPV [almost] never loads huge images
      ; in this mode with WIC, therefore,  I do not care for now ;-).

      pBitmap := DllCall(whichMainDLL "\" func2exec, "Int", x, "Int", y, "Int", w, "Int", h, "Int", newW, "Int", newH, "Int", mustClip, "int", useICM, "int", resizeQuality, "UPtr")
      ; ToolTip, % pBitmap "|"  hFIFimgE "|" hFIFimgZ "|" x "|" y "|" w "|" h "|" newW "|" newH , , , 2
      If StrLen(pBitmap)>1
         recordGdipBitmaps(pBitmap, A_ThisFunc)
     Return pBitmap
   }

   LoadWICfile(imgPath, frameu, noBPPconv, externMode, externHandle) {
      startZeit := A_TickCount
      If (externMode!=1)
      {
         VarSetCapacity(resultsArray, 8 * 9, 0)
         func2exec := (A_PtrSize=8) ? "WICpreLoadImage" : "_LoadWICimage@48"
         r := DllCall(whichMainDLL "\" func2exec, "Str", imgPath, "Int", frameu, "UPtr", &resultsArray, "UPtr")
      }

      If r
      {
         Random, OutputVar, 1, 999999
         k := WicPixelFormats(NumGet(resultsArray, 4 * 3, "uInt"))
         This.PixelFormat := k
         This.ImgFile := imgPath
         This.imgHandle := OutputVar
         This.Width := NumGet(resultsArray, 4 * 0, "uInt")
         This.Height := NumGet(resultsArray, 4 * 1, "uInt")
         This.Frames := NumGet(resultsArray, 4 * 2, "uInt") - 1
         This.ActiveFrame := NumGet(resultsArray, 4 * 6, "uInt")
         This.DPI := NumGet(resultsArray, 4 * 4, "uInt")
         This.BPP := NumGet(resultsArray, 4 * 7, "uInt")
         This.Channels := NumGet(resultsArray, 4 * 8, "uInt")
         This.RawFormat := WICcontainerFmts(NumGet(resultsArray, 4 * 5, "uInt"), imgPath)
         This.TooLargeGDI := 0 ; isImgSizeTooLarge(This.Width, This.Height)
         This.HasAlpha := varContains(k, "argb", "prgba", "bgra", "rgba", "alpha")
         This.OpenedWith := "Windows Imaging Component [WIC]"
         This.LoadedWith := "WIC"
      } Else If externMode
      {
         ; ToolTip, % "l=" externHandle.PixelFormat "|" externMode , , , 2
         This.PixelFormat := externHandle.PixelFormat
         This.ImgFile := externHandle.ImgFile
         This.imgHandle := externHandle.imgHandle
         This.Width := externHandle.Width
         This.Height := externHandle.Height
         This.Frames := externHandle.Frames
         This.ActiveFrame := externHandle.ActiveFrame
         This.DPI := externHandle.DPI
         This.BPP := externHandle.BPP
         This.Channels := externHandle.Channels
         This.RawFormat := externHandle.RawFormat
         This.TooLargeGDI := externHandle.TooLargeGDI
         This.HasAlpha := externHandle.HasAlpha
         This.OpenedWith := externHandle.OpenedWith
         This.LoadedWith := externHandle.LoadedWith
         r := 1
      }

      This.LoadedWith := "WIC"
      This.ClrInfo := ""
      ; SoundBeep , 300, 600
      resultsArray := ""
      zeitu := A_TickCount - startZeit
      Return r
   } ; // LoadWICfile


} ; // class screenQPVimage
