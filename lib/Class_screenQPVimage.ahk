
Class screenQPVimage {
   Static noIdea := "yep"
   __New() {
      SoundBeep 
   }
   __Delete() {
      This.DiscardImage()
   }

   LoadImage(imgPath, frameu, noBMP:=0) {
      ; If ((RegExMatch(imgPath, RegExFIMformPtrn) || alwaysOpenwithFIM=1) && allowFIMloader=1)
      If (imgPath && allowFIMloader=1)
      {
         r := This.LoadFreeImageFile(imgPath, frameu, noBMP)
      ; Else If (RegExMatch(imgPath, RegExWICfmtPtrn) && WICmoduleHasInit=1 && allowWICloader=1)
      } Else If imgPath
      {
         r := This.LoadWICfile(imgPath, frameu, noBMP)
      }
      ; Else
      ; {
      ;    SoundBeep 
      ; }
      ; ToolTip, % "l=" r , , , 2
      Return r
   }

   ImageGetRect(x, y, w, h) {
      If InStr(This.OpenedWith, "[FIM]")
         r := This.FimGetRect(x, y, w, h, 0, 0)
      Else If InStr(This.OpenedWith, "[WIC]")
         r := This.WicGetRect(x, y, w, h, 0, 0)
      Return r
   }

   ImageGetResizedRect(x, y, w, h, newW, newH) {
      If InStr(This.OpenedWith, "[FIM]")
         r := This.FimGetRect(x, y, w, h, newW, newH)
      Else If InStr(This.OpenedWith, "[WIC]")
         r := This.WicGetRect(x, y, w, h, newW, newH)
      Return r
   }

   DiscardImage() {
      If (This.imgHandle)
      {
         If InStr(This.OpenedWith, "[FIM]")
            FreeImage_UnLoad(This.imgHandle)
         Else If InStr(This.OpenedWith, "[WIC]")
            DllCall(whichMainDLL "\WICdestroyPreloadedImage", "Int", 1, "Int")

         This.imgHandle := ""
      }
   }

   FimGetRect(x, y, w, h, newW, newH) {
     GFT := FreeImage_GetFileType(This.ImgFile)
     If (newW && newH)
        hFIFimgZ := FreeImage_RescaleRect(This.imgHandle, newW, newH, x, y, w, h)
     Else
        hFIFimgZ := FreeImage_Copy(This.imgHandle, x, y, x + w, y + h)

     If !hFIFimgZ
        Return 0

     If (GFT=0 && InStr(This.FIMcolors, "rgba"))
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
     If StrLen(pBitmap)
        createdGDIobjsArray["x" pBitmap] := [pBitmap, "bmp", 1, A_ThisFunc]
     Return pBitmap
   }

   LoadFreeImageFile(imgPath, frameu, noBMP:=0, qualityRaw:=0) {
     sTime := A_TickCount
     loadArgs := FIMdecideLoadArgs(imgPath, qualityRaw, GFT)
     If (noBMP=1)
        GFT := -1  ; FIF_LOAD_NOPIXELS

     changeMcursor()
     If ((GFT=18 || GFT=25) && noBMP=0)
     {
        ; open multi-page GIF and TIFFs
        multiFlags := (GFT=25) ? 2 : 0
        hMultiBMP := FreeImage_OpenMultiBitmap(imgPath, GFT, 0, 1, 1, multiFlags)
     }

     This.Frames := 0
     This.ActiveFrame := 0
     If StrLen(hMultiBMP)>1
     {
        hasOpenedMulti := 1
        tFrames := FreeImage_GetPageCount(hMultiBMP)
        If (tFrames<0 || !tFrames)
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

     If !hFIFimgA
        Return 0

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

     This.ImgFile := imgPath
     This.imgHandle := hFIFimgA
     This.HasAlpha := (InStr(ColorsType, "rgba") || hasMultiTrans) ? 1 : 0
     This.RawFormat := fileType " | " imgType
     This.PixelFormat := StrReplace(oimgBPP, "-", "+") "-" ColorsType toneMapped
     This.OpenedWith := "FreeImage library [FIM]"
     This.TooLargeGDI := isImgSizeTooLarge(imgW, imgH)
     This.Width := imgW
     This.Height := imgH
     This.dpiX := dpiX
     This.dpiY := dpiY
     This.DPI := Round((dpiX + dpiY)/2)
     This.FIMcolors := ColorsType
     This.FIMtype := imgType
     This.FIMbpp := imgBPP
     Return 1
   } ; // LoadFimFile


   WicGetRect(x, y, w, h, newW, newH) {
      mustClip := (x=0 && y=0 && w=This.Width && h=This.Height) ? 0 : 1
      func2exec := (A_PtrSize=8) ? "WICgetRectImage" : "_LoadWICimage@48"
      If !newW
         newW := w
      If !newH
         newH := h

      pBitmap := DllCall(whichMainDLL "\" func2exec, "Int", x, "Int", y, "Int", w, "Int", h, "Int", newW, "Int", newH, "Int", mustClip, "UPtr")
      ; ToolTip, % pBitmap "|"  hFIFimgE "|" hFIFimgZ "|" x "|" y "|" w "|" h "|" newW "|" newH , , , 2
      If StrLen(pBitmap)>1
         createdGDIobjsArray["x" pBitmap] := [pBitmap, "bmp", 1, A_ThisFunc]
     Return pBitmap
   }

   LoadWICfile(imgPath, frameu, noBPPconv) {
      ; Return
      Static lastEdition := 1, hasRan := 0
      startZeit := A_TickCount
      ; lastEdition := !lastEdition
      VarSetCapacity(resultsArray, 8 * 6)
      func2exec := (A_PtrSize=8) ? "WICpreLoadImage" : "_LoadWICimage@48"
      r := DllCall(whichMainDLL "\" func2exec, "Str", imgPath, "Int", frameu, "UPtr", &resultsArray, "UPtr")
      If r
      {
         Random, OutputVar, 1, 999999
         k := This.PixelFormat := WicPixelFormats(NumGet(resultsArray, 4 * 3, "uInt"))
         This.ImgFile := imgPath
         This.imgHandle := OutputVar
         This.Width := NumGet(resultsArray, 4 * 0, "uInt")
         This.Height := NumGet(resultsArray, 4 * 1, "uInt")
         This.Frames := NumGet(resultsArray, 4 * 2, "uInt") - 1
         This.ActiveFrame := NumGet(resultsArray, 4 * 6, "uInt")
         This.DPI := NumGet(resultsArray, 4 * 4, "uInt")
         This.RawFormat := WICcontainerFmts(NumGet(resultsArray, 4 * 5, "uInt"))
         This.TooLargeGDI := isImgSizeTooLarge(This.Width, This.Height)
         This.HasAlpha := varContains(k, "argb", "prgba", "bgra", "rgba", "alpha")
         This.OpenedWith := "Windows Imaging Component [WIC]"
      }

      resultsArray := ""
      zeitu := A_TickCount - startZeit
      ; msgbox, % r "==" zeitu " = " pixfmt "=" rawFmt
      ; ToolTip, % WICmoduleHasInit " | " r "==" zeitu " = " mainLoadedIMGdetails.pixfmt "=" mainGdipWinThumbsGrid.RawFormat , , , 3
      ; https://stackoverflow.com/questions/8101203/wicbitmapsource-copypixels-to-gdi-bitmap-scan0
      ; https://github.com/Microsoft/Windows-classic-samples/blob/master/Samples/Win7Samples/multimedia/wic/wicviewergdi/WicViewerGdi.cpp#L354
      Return r
   } ; // LoadWICfile


} ; // class screenQPVimage
