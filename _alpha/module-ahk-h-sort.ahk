#NoEnv
#NoTrayIcon
#MaxHotkeysPerInterval, 500
#MaxThreads, 1
#MaxThreadsPerHotkey, 1
#MaxThreadsBuffer, Off
#MaxMem, 1924
#SingleInstance, force
#UseHook, Off
#Include, Gdip_All.ahk
#Include, freeimage.ahk
#Include, module-common-functions.ahk
SetWinDelay, 1
Global GDIPToken, RegExFIMformPtrn := "i)(.\\*\.(DDS|EXR|HDR|IFF|JBG|JNG|JP2|JXR|JIF|MNG|PBM|PGM|PPM|PCX|PFM|PSD|PCD|SGI|RAS|TGA|WBMP|WEBP|XBM|XPM|G3|LBM|J2K|J2C|WDP|HDP|KOA|PCT|PICT|PIC|TARGA|WAP|WBM|crw|cr2|nef|raf|mos|kdc|dcr|3fr|arw|bay|bmq|cap|cine|cs1|dc2|drf|dsc|erf|fff|ia|iiq|k25|kc2|mdc|mef|mrw|nrw|orf|pef|ptx|pxn|qtk|raw|rdc|rw2|rwz|sr2|srf|sti|x3f))$"
     , mainCompiledPath := "", wasInitFIMlib := 0, alwaysOpenwithFIM := 0
     , operationDone := 0, resultsList := "", FIMfailed2init := 0
     , MainExe := AhkExported()


while !(gdiptoken)
{
if (A_index < 5000)
{
GDIPToken := Gdip_Startup()
} Else if (!GDIPToken || thisGDIPversion<1.78)
   {
      operationDone := 1
      MsgBox, 48, %appTitle%, ERROR: unable to initialize GDI+...`n`nThe program will now exit.`n`nRequired GDI+ library wrapper: v1.78 - extended compilation edition.
      Return 
   }
}
; placeholder

; MsgBox, % filesList
sortMainCore(SortCriterion, filesList)
Return

initThisThread() {
   GDIPToken := Gdip_Startup()
while !(gdiptoken)
{
if (A_index < 5000)
{
GDIPToken := Gdip_Startup()
} Else if (!GDIPToken || thisGDIPversion<1.78)
   {
      operationDone := 1
      MsgBox, 48, %appTitle%, ERROR: unable to initialize GDI+...`n`nThe program will now exit.`n`nRequired GDI+ library wrapper: v1.78 - extended compilation edition.
      Return -1
   }
}


   initFIMGmodule()
}

cleanupThread() {
   If (wasInitFIMlib=1)
      FreeImage_FoxInit(0) ; Unload Dll

   If GDIPToken
      Gdip_Shutdown(GDIPToken)

   wasInitFIMlib := GDIPToken := 0
}

sortMainCore(SortCriterion, filesList) {
  resultsList := ""
  operationDone := 0
  ; E := initThisThread()
  ; If (E=-1)
  ; {
  ;     cleanupThread()
  ;     Return
  ; }
  Loop, Parse, filesList,`n,`r
  {
       If A_LoopField
          r := A_LoopField
       Else
          Continue

       If (SortCriterion="similarity")
       {
          op := GetImgFileDimension(r, Wi, He)
          PicRatio := Round(Wi/He, 3)
          If valueBetween(PicRatio, o_picRatio + 0.4, o_picRatio - 0.4)
          {
             thisHistoAvg := 0.001
             oBitmap := LoadBitmapFromFileu(r)
             If oBitmap
             {
                xBitmap := Gdip_ResizeBitmap(oBitmap, rImgW, rImgH, 0, 3)
                thisHistoAvg := calcHistoAvgFile(xBitmap, "histogram", 3)
             }

             ; ToolTip, % o_thisHistoAvg "--" thisHistoAvg, , , 2
             If !valueBetween(thisHistoAvg, o_thisHistoAvg + 45, o_thisHistoAvg - 45)
             {
                oBitmap := Gdip_DisposeImage(oBitmap, 1)
                xBitmap := Gdip_DisposeImage(xBitmap, 1)
             }
          }

          If oBitmap
          {
             oBitmap := Gdip_DisposeImage(oBitmap, 1)
             lBitmap := Gdip_BitmapConvertGray(xBitmap)
             SortByA := 100 - Gdip_CompareBitmaps(zBitmap, xBitmap, 100)
             SortByB := 100 - Gdip_CompareBitmaps(gBitmap, lBitmap, 100)
             SortBy := (SortByA + SortByB)/2
             Gdip_DisposeImage(xBitmap, 1)
             Gdip_DisposeImage(lBitmap, 1)
          } Else SortBy := (op=1) ? "0.01" thisHistoAvg : 0
       } Else If InStr(SortCriterion, "histogram")
       {
          oBitmap := LoadBitmapFromFileu(r)
          If oBitmap
          {
             xBitmap := Gdip_ResizeBitmap(oBitmap, 300, 300, 1, 3)
             SortBy := calcHistoAvgFile(xBitmap, SortCriterion, 3)
             xBitmap := Gdip_DisposeImage(xBitmap, 1)
             oBitmap := Gdip_DisposeImage(oBitmap, 1)
          } Else SortBy := 0
       }
       If StrLen(SortBy)>1
          resultsList .= SortBy " |!\!|" r "`n"
   }

   If (SortCriterion="similarity")
   {
      Gdip_DisposeImage(zBitmap, 1)
      Gdip_DisposeImage(gBitmap, 1)
   }

   operationDone := 1
   ; cleanupThread()
}
