
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
      If imgPath
      {
         r := This.LoadFreeImageFile(imgPath, frameu, noBMP)
      } Else If (RegExMatch(imgPath, RegExWICfmtPtrn) && WICmoduleHasInit=1 && allowWICloader=1)
      {
         SoundBeep
      } Else
      {
         SoundBeep 
      }
      ; ToolTip, % "l=" r , , , 2
      Return r
   }

   ImageGetRect(x, y, w, h) {
      If InStr(This.OpenedWith, "[FIM]")
         r := This.FimGetRect(x, y, w, h, 0, 0)
      Return r
   }

   ImageGetResizedRect(x, y, w, h, newW, newH) {
      If InStr(This.OpenedWith, "[FIM]")
         r := This.FimGetRect(x, y, w, h, newW, newH)
      Return r
   }

   DiscardImage() {
      If (This.imgHandle)
      {
         If InStr(This.OpenedWith, "[FIM]")
            FreeImage_UnLoad(This.imgHandle)
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
        This.HasAlpha := FIMalphaChannelFix(alphaBitmap, hFIFimgE)

     ; FreeImage_PreMultiplyWithAlpha(hFIFimgE)
     pBitmap := ConvertFIMtoPBITMAP(hFIFimgE)
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
     This.Width := imgW,     This.Height := imgH
     FreeImage_GetDPIresolution(hFIFimgA, dpiX, dpiY)
     This.dpiX := dpiX,      This.dpiY := dpiY,    This.DPI := Round((dpiX + dpiY)/2)

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
     This.imgW := imgW
     This.imgH := imgH
     This.FIMcolors := ColorsType
     This.FIMtype := imgType
     This.FIMbpp := imgBPP
     Return 1
   } ; // LoadFimFile

} ; // class screenQPVimage
