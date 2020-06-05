; SGDIPrint-library
; Simple GDI-Printing library for AHK_L (32bit & 64bit compatible)
; found on : https://www.autohotkey.com/boards/viewtopic.php?f=6&t=68403
; by Zed_Gecko
; updated by Marius Șucan on vendredi 5 juin 2020.
;
; this edition relies on GDI+ library compilation
; https://github.com/marius-sucan/AHK-GDIp-Library-Compilation
;
; thanks to: engunneer, Lexikos, closed, controlfreak, just me, fincs, tic
; Requires tics GDI+ Library unless you use bare GDI printing (means printing directly on the printer-DC)
; http://www.autohotkey.com/forum/viewtopic.php?t=32238
; with GDI+ you can either draw directly on the printer (SGDIPrint_GraphicsFromHDC) or
; draw on a matching bitmap first (SGDIPrint_GetMatchingBitmap) which you copy later to the printer,
; which allows to  preview the print and to save it to file 
; but it uses more resources & time, and the printing result may differ from "direct"-printing
;---------------------------------------------------------------
; Functions:
; SGDIPrint_EnumPrinters()            Get List of Printer Names
; SGDIPrint_SetDefaultPrinter()       Sets default printer by name
; SGDIPrint_GetDefaultPrinter()       Get default-Printer Name
; SGDIPrint_GetHDCfromPrinterName()   Get GDI DC based on Printer Name
; SGDIPrint_GetHDCfromPrintDlg()      Get GDI DC from user-dialog
; SGDIPrint_GetMatchingBitmap()       Get a GDI+ Bitmap matching to print-out size
; SGDIPrint_BeginDocument()           starts the GDI-print-session
; SGDIPrint_GraphicsFromBitmap()      creates GDI+ graphic 
; SGDIPrint_CopyBitmapToPrinterHDC()  copies a GDI+ Bitmap to a matching printer GDI DC
; SGDIPrint_GraphicsFromHDC()         creates GDI+ graphic 
; SGDIPrint_TextFillUpRect()          fills up a rectangle on a GDI+ graphic with text
; SGDIPrint_NextPage()                starts new page in the GDI-print-session
; SGDIPrint_EndDocument()             ends the GDI-print-session
; SGDIPrint_AbortDocument()           aborts the GDI-print-session
; SGDIPrint_AbortPrinter()            it deletes a printer's spool file if the printer is configured for spooling.
; SGDIPrint_OpenPrinterProperties() 
; SGDIPrint_ConnectToPrinterDlg()
;-----------
; This edition no longer relies on global Vars.
; SGDIPrint_GetHDCfromPrinterName() and SGDIPrint_GetHDCfromPrintDlg()
; return an object with the following properties:
;  SGDIPrint.HDC_Orientation  Page Orientation:  PORTRAIT = 1  LANDSCAPE = 2
;  SGDIPrint.HDC_Color        Color-Printing.Mode:  B/W = 1  COLOR = 2
;  SGDIPrint.HDC_Copies       the number of copies you or user selected [integer]
;  SGDIPrint.HDC_Width        Width in pixel
;  SGDIPrint.HDC_Height       Height in pixel
;  SGDIPrint.HDC_xdpi         X resolution in DPI
;  SGDIPrint.HDC_ydpi         Y resolution in DPI
;  SGDIPrint.HDC_ptr          The handle of the HDC
;  SGDIPrint.HDC_PrinterName  The selected/given printer name

; SGDIPrint_EnumPrinters retrieves a list of NAMES of available printers 
; use this or SGDIPrint_GetDefaultPrinter() to get a valid printer-name for SGDIPrint_GetHDCfromPrinterName()
; use DELIM to specify the delimiter for printer names
; set returnArray=1 to retrieve details about each printer

SGDIPrint_EnumPrinters(delim:="`n", flags:=0, returnArray:=0) {
; PrinterEnumFlags:
; PRINTER_ENUM_DEFAULT     = 0x00000001
; PRINTER_ENUM_LOCAL       = 0x00000002
; PRINTER_ENUM_CONNECTIONS = 0x00000004
; PRINTER_ENUM_FAVORITE    = 0x00000004
; PRINTER_ENUM_NAME        = 0x00000008
; PRINTER_ENUM_REMOTE      = 0x00000010
; PRINTER_ENUM_SHARED      = 0x00000020
; PRINTER_ENUM_NETWORK     = 0x00000040
; PRINTER_ENUM_EXPAND      = 0x00004000
; PRINTER_ENUM_CONTAINER   = 0x00008000
; PRINTER_ENUM_ICONMASK    = 0x00ff0000
; PRINTER_ENUM_CATEGORY_ALL= 0x02000000
; PRINTER_ENUM_CATEGORY_3D = 0x04000000
; adapted from: https://www.autohotkey.com/boards/viewtopic.php?t=62955
; a printers class by jNizM

  If !flags
     flags := 0x2|0x4

  if !(DllCall("winspool.drv\EnumPrinters", "uint", flags, "ptr", 0, "uint", 2, "ptr", 0, "uint", 0, "uint*", size, "uint*", 0))
  {
    size := VarSetCapacity(buf, size << 1, 0)
    if (DllCall("winspool.drv\EnumPrinters", "uint", flags, "ptr", 0, "uint", 2, "ptr", &buf, "uint", size, "uint*", 0, "uint*", count))
    {
      addr := &buf, PRINTERS := []
      loop % count
      {
        PRINTERS[A_Index, "ServerName"]      := StrGet(NumGet(addr + 0,              "ptr"))
        PRINTERS[A_Index, "PrinterName"]     := StrGet(NumGet(addr + A_PtrSize,      "ptr"))
        PRINTERS[A_Index, "ShareName"]       := StrGet(NumGet(addr + A_PtrSize *  2, "ptr"))
        PRINTERS[A_Index, "PortName"]        := StrGet(NumGet(addr + A_PtrSize *  3, "ptr"))
        PRINTERS[A_Index, "DriverName"]      := StrGet(NumGet(addr + A_PtrSize *  4, "ptr"))
        PRINTERS[A_Index, "Comment"]         := StrGet(NumGet(addr + A_PtrSize *  5, "ptr"))
        PRINTERS[A_Index, "Location"]        := StrGet(NumGet(addr + A_PtrSize *  6, "ptr"))
        ;DevMode                             := NumGet(addr + A_PtrSize *  7,      "ptr")
        ; https://docs.microsoft.com/en-us/windows/desktop/api/Wingdi/ns-wingdi-_devicemodea
        PRINTERS[A_Index, "SepFile"]         := StrGet(NumGet(addr + A_PtrSize *  8, "ptr"))
        PRINTERS[A_Index, "PrintProcessor"]  := StrGet(NumGet(addr + A_PtrSize *  9, "ptr"))
        PRINTERS[A_Index, "Datatpye"]        := StrGet(NumGet(addr + A_PtrSize * 10, "ptr"))
        PRINTERS[A_Index, "Parameters"]      := StrGet(NumGet(addr + A_PtrSize * 11, "ptr"))
        ;SecurityDescriptor                  := NumGet(addr + A_PtrSize * 12,      "ptr")
        ; https://docs.microsoft.com/de-de/windows/desktop/api/winnt/ns-winnt-_security_descriptor
        PRINTERS[A_Index, "Attributes"]      := NumGet(addr + A_PtrSize * 13,      "uint")
        PRINTERS[A_Index, "Priority"]        := NumGet(addr + A_PtrSize * 13 +  4, "uint")
        PRINTERS[A_Index, "DefaultPriority"] := NumGet(addr + A_PtrSize * 13 +  8, "uint")
        PRINTERS[A_Index, "StartTime"]       := NumGet(addr + A_PtrSize * 13 + 12, "uint")
        PRINTERS[A_Index, "UntilTime"]       := NumGet(addr + A_PtrSize * 13 + 16, "uint")
        PRINTERS[A_Index, "Status"]          := NumGet(addr + A_PtrSize * 13 + 20, "uint")
        PRINTERS[A_Index, "Jobs"]            := NumGet(addr + A_PtrSize * 13 + 24, "uint")
        PRINTERS[A_Index, "AveragePPM"]      := NumGet(addr + A_PtrSize * 13 + 28, "uint")
        thisPrinterName := StrGet(NumGet(addr + A_PtrSize, "ptr"))
        If thisPrinterName
           PRINTERSlist .= thisPrinterName delim
        addr += A_PtrSize * 13 + 32
      }

      If (returnArray=1)
         return PRINTERS
      Else
         return Trim(PRINTERSlist, delim)
    }
  }
  return
}

; SGDIPrint_GetDefaultPrinter retrieves the NAME of the default printer
; use this or SGDIPrint_EnumPrinters() to get a valid printer-name for SGDIPrint_GetHDCfromPrinterName()
; if unsucessful, it returns an empty string.
SGDIPrint_GetDefaultPrinter() {
  DllCall("winspool.drv\GetDefaultPrinter", "Ptr", 0, "Uint*", nSize)
  if A_IsUnicode
     nSize := VarSetCapacity(gPrinter, nSize*2)
  else
     nSize := VarSetCapacity(gPrinter, nSize)

  r := DllCall("winspool.drv\GetDefaultPrinter", "Str", gPrinter, "Uint*", nSize)
  If !r
     gPrinter := ""
  Return gPrinter
}

; SGDIPrint_GetHDCfromPrinterName returns a
; SGDIPrint object. On failure, it returns 0.
;
; Parameters:
; Orientation: PORTRAIT = 1  LANDSCAPE = 2
; Color: B/W = 1  COLOR = 2
; Copies: any number of copies you want [integer]

SGDIPrint_GetHDCfromPrinterName(pPrinterName, dmOrientation:=0, dmColor:=0, dmCopies:=0, MainhWnd:=0) {
  SGDIPrint := []
  If !MainhWnd
     MainhWnd := A_ScriptHwnd

  pPrinterName := Trim(pPrinterName)
  VarSetCapacity(pPrinter , A_PtrSize, 0)
  out := DllCall("Winspool.drv\OpenPrinter", "Ptr", &pPrinterName, "Ptr*", pPrinter, "Ptr", 0, "Ptr")
  If !out
     Return 0

  sizeDevMode := DllCall("Winspool.drv\DocumentProperties", "Ptr", MainhWnd, "Ptr", pPrinter, "Ptr", &pPrinterName, "Ptr", 0, "Ptr", 0, "UInt", 0, "Int")
  VarSetCapacity(pDevModeOutput, sizeDevMode, 0)
  out2 := DllCall("Winspool.drv\DocumentProperties", "Ptr", MainhWnd, "Ptr", pPrinter, "Ptr", &pPrinterName, "Ptr", &pDevModeOutput, "Ptr", 0, "UInt", 2, "Int")

  ansiUnicodeOffSet := (A_IsUnicode=1) ? 32 : 0
  if (dmOrientation=1 || dmOrientation=2)
     NumPut(dmOrientation, pDevModeOutput, 44 + ansiUnicodeOffSet, "Short")

  if dmCopies is integer
  {
     if (dmCopies>0)
        NumPut(dmCopies, pDevModeOutput, 54 + ansiUnicodeOffSet, "Short")
  }

  if (dmColor=1 || dmColor=2)
     NumPut(dmColor, pDevModeOutput, 60 + ansiUnicodeOffSet, "Short")

  out3 := DllCall("Winspool.drv\DocumentProperties", "UPtr", MainhWnd, "Ptr", pPrinter, "Ptr", &pPrinterName, "Ptr", &pDevModeOutput, "Ptr", &pDevModeOutput, "UInt", 10, "Int") 
  SGDIPrint.HDC_PrinterName := pPrinterName
  SGDIPrint.HDC_Orientation := NumGet(pDevModeOutput, 44 + ansiUnicodeOffSet, "Short")
  SGDIPrint.HDC_Color := NumGet(pDevModeOutput, 54 + ansiUnicodeOffSet, "Short")
  SGDIPrint.HDC_Copies := NumGet(pDevModeOutput, 60 + ansiUnicodeOffSet , "Short")
  hDC := DllCall("Gdi32.dll\CreateDC", "Ptr", 0, "WStr", pPrinterName, "Ptr", 0, "Ptr", &pDevModeOutput, "UPtr")
  ; DllCall("ClosePrinter", "Ptr", pPrinter)

  VarSetCapacity(pDevModeOutput, 0)
  VarSetCapacity(pPrinter, 0)
  ; Retrieve the size of the printable area in pixels:
  SGDIPrint.HDC_Width  := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 8)    ; HORZRES
  SGDIPrint.HDC_Height := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 10)  ; VERTRES

  ; Retrieve the resolution of the printer in pixels/doots per inch:
  SGDIPrint.HDC_xdpi := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt",0x58) ; LOGPIXELSX
  SGDIPrint.HDC_ydpi := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 0x5A) ; LOGPIXELSY

  ; Retrieve paper physical dimensions and non-printable margins (offset). Values in «device units».
  SGDIPrint.HDC_PHYSICALWIDTH   := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x6E)
  SGDIPrint.HDC_PHYSICALHEIGHT  := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x6F)
  SGDIPrint.HDC_PHYSICALOFFSETX := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x70)
  SGDIPrint.HDC_PHYSICALOFFSETY := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x71)
  SGDIPrint.HDC_ptr := hDC
  return SGDIPrint
}

; SGDIPrint_GetHDCfromPrintDlg returns a
; SGDIPrint object with the properties of the printer selected
; by the user in the Windows standard print dialog window.
; On failure, it returns 0.

SGDIPrint_GetHDCfromPrintDlg(hwndOwner) {
  Static PD_ALLPAGES := 0x00
       , PD_COLLATE := 0x00000010
       , PD_DISABLEPRINTTOFILE := 0x00080000
       , PD_ENABLEPRINTHOOK := 0x00001000
       , PD_ENABLEPRINTTEMPLATE := 0x00004000
       , PD_ENABLEPRINTTEMPLATEHANDLE := 0x00010000
       , PD_ENABLESETUPHOOK := 0x00002000
       , PD_ENABLESETUPTEMPLATE := 0x00008000
       , PD_ENABLESETUPTEMPLATEHANDLE := 0x00020000
       , PD_NOPAGENUMS := 0x00000008
       , PD_NOWARNING := 0x00000080
       , PD_PRINTSETUP := 0x00000040
       , PD_PRINTTOFILE := 0x00000020
       , PD_RETURNDEFAULT := 0x00000400
       , PD_RETURNIC := 0x00000200
       , PD_SHOWHELP := 0x800
       , PD_USEDEVMODECOPIESANDCOLLATE := 0x040000
       , PD_SELECTION := 0x01
       , PD_PAGENUMS := 0x02
       , PD_NOSELECTION := 0x04
       , PD_RETURNDC := 0x0100
       , PD_USEDEVMODECOPIES := 0x040000
       , PD_HIDEPRINTTOFILE := 0x100000
       , PD_NONETWORKBUTTON := 0x200000
       , PD_NOCURRENTPAGE := 0x800000
       , PD_StructSize := (A_PtrSize=8) ? (13 * A_PtrSize) + 16 : 66
       , PD_Flags := PD_NOCURRENTPAGE | PD_NOSELECTION | PD_RETURNDC | PD_HIDEPRINTTOFILE | PD_USEDEVMODECOPIES

  SGDIPrint := []
  VarSetCapacity(PRINTDIALOG_STRUCT, PD_StructSize, 0)
  NumPut(PD_StructSize, PRINTDIALOG_STRUCT, 0, "UInt")
  NumPut(hwndOwner, PRINTDIALOG_STRUCT, A_PtrSize, "UPtr")
  NumPut(PD_Flags, PRINTDIALOG_STRUCT, A_PtrSize * 5, "UInt")

  if !DllCall("comdlg32\PrintDlg","Ptr", &PRINTDIALOG_STRUCT, "UInt")
     return 0

  ansiUnicodeOffSet := (A_IsUnicode=1) ? 32 : 0
  if (hDevNames := NumGet(PRINTDIALOG_STRUCT, A_PtrSize * 3))
     DllCall("GlobalFree", "Ptr", hDevNames)
  
  if (hDevModeOutput := NumGet(PRINTDIALOG_STRUCT, A_PtrSize * 2))
  { 
     pDevModeOutput := DllCall("GlobalLock", "Ptr", hDevModeOutput)
     SGDIPrint.HDC_PrinterName := StrGet(NumGet(hDevModeOutput + 0, 0, "ptr"))
     SGDIPrint.HDC_Orientation := NumGet(pDevModeOutput + 0, 44 + ansiUnicodeOffSet, "Short")
     SGDIPrint.HDC_Color := NumGet(pDevModeOutput + 0, 54 + ansiUnicodeOffSet, "Short")
     SGDIPrint.HDC_Copies := NumGet(pDevModeOutput + 0, 60 + ansiUnicodeOffSet, "Short")
     DllCall("GlobalFree","Ptr",hDevModeOutput)
  }

   ; Get the newly created printer device context.
   if !(hDC := NumGet(PRINTDIALOG_STRUCT, A_PtrSize * 4, "UPtr"))
      return 0

   VarSetCapacity(PRINTDIALOG_STRUCT, 0)
   ; Retrieve the size of the printable area in pixels:
   SGDIPrint.HDC_Width  := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 8)   ; HORZRES
   SGDIPrint.HDC_Height := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 10)  ; VERTRES

   ; Retrieve the resolution of the printer in pixels/doots per inch:
   SGDIPrint.HDC_xdpi := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 0x58) ; LOGPIXELSX
   SGDIPrint.HDC_ydpi := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "UInt", 0x5A) ; LOGPIXELSY

   ; Retrieve paper physical dimensions and non-printable margins (offset). Values in «device units».
   SGDIPrint.HDC_PHYSICALWIDTH   := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x6E)
   SGDIPrint.HDC_PHYSICALHEIGHT  := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x6F)
   SGDIPrint.HDC_PHYSICALOFFSETX := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x70)
   SGDIPrint.HDC_PHYSICALOFFSETY := DllCall("GetDeviceCaps", "Ptr", hDC, "UInt", 0x71)
   SGDIPrint.HDC_ptr := hDC
   ; MsgBox, % SGDIPrint.HDC_PrinterName
   return SGDIPrint
}

; SGDIPrint_GetMatchingBitmap returns a GDI+ Bitmap matching the current printers page-size with white background
; you need to call SGDIPrint_GetHDCfromPrintDlg or SGDIPrint_GetHDCfromPrinterName first to
; retrieve width and height values
SGDIPrint_GetMatchingBitmap(width, height, color:="0xFFFFFF") {
  ; set background-color (default is white)
  pBitmap := Gdip_CreateBitmap(width, height)
  G := Gdip_GraphicsFromImage(pBitmap)
  Gdip_SetPageUnit(G, 2)
  Gdip_SetSmoothingMode(G, 4) 
  pBrush := Gdip_BrushCreateSolid(0xffffffff)
  Gdip_FillRectangle(G, pBrush, 0, 0, width, height) 
  Gdip_DeleteBrush(pBrush)  
  Gdip_DeleteGraphics(G)
  return pBitmap
}

; SGDIPrint_BeginDocument starts the GDI-print-session and the first page
; returns a value>0 on success
SGDIPrint_BeginDocument(hDC, Document_Name) {
  VarSetCapacity(DOCUMENTINFO_STRUCT,(A_PtrSize * 4) + 4,0), 
  NumPut((A_PtrSize * 4) + 4, DOCUMENTINFO_STRUCT) 
  NumPut(&Document_Name,DOCUMENTINFO_STRUCT,A_PtrSize)

  r := DllCall("Gdi32.dll\StartDoc","Ptr", hDC, "Ptr", &DOCUMENTINFO_STRUCT, "int")
  if (r>0)
     out := DllCall("Gdi32.dll\StartPage","Ptr",hDC,"int")
 
  return out
}

; SGDIPrint_GraphicsFromBitmap returns a GDI+ graphic object with printerfriendly preformatting
SGDIPrint_GraphicsFromBitmap(pBitmap) {
  G := Gdip_GraphicsFromImage(pBitmap, 7, 4, 2)
  return G
}

; SGDIPrint_CopyBitmapToPrinterHDC copies a GDI+ Bitmap on a matching Printer HDC
SGDIPrint_CopyBitmapToPrinterHDC(pBitmap, hDC, Width, Height) {
  PG := SGDIPrint_GraphicsFromHDC(hDC)
  If PG
  {
     Gdip_DrawImage(PG, pBitmap, 0, 0, Width, Height)
     Gdip_DeleteGraphics(PG)
  }
  return
}

; SGDIPrint_GraphicsFromHDC returns a GDI+ graphic object with printerfriendly preformatting
SGDIPrint_GraphicsFromHDC(hDC) {
  ; The default unit of measurement when creating Graphics from a DC is UnitDisplay.
  ; It must be UnitPixel, or our drawing will be off.
  G := Gdip_GraphicsFromHDC(hDC, "", 7, 4, 2)
  return G
}

; SGDIPrint_NextPage creates a new page in the current printer document
; if return value not 0, then an error occured
SGDIPrint_NextPage(hDC) {
  DllCall("Gdi32.dll\EndPage","Ptr",hDC,"int")
  r := DllCall("Gdi32.dll\StartPage","Ptr",hDC,"int")
  return r
}  

; SGDIPrint_EndDocument ends the printing session and deletes the DC
; if return value not 0, then an error occured
SGDIPrint_EndDocument(hDC) {
  r := DllCall("Gdi32.dll\EndPage","Ptr",hDC,"int")
  DllCall("Gdi32.dll\EndDoc","Ptr",hDC)
  DeleteDC(hDC)
  return r
}

; SGDIPrint_AbortDocument aborts the printing session and deletes the DC
SGDIPrint_AbortDocument(hDC) {
  DllCall("Gdi32.dll\AbortDoc","Ptr",hDC)
  DeleteDC(hDC)
  return
}

SGDIPrint_SetDefaultPrinter(pPrinterName) {
   if !(DllCall("winspool.drv\SetDefaultPrinter", "Str", pPrinterName))
      return 0
   return 1
}

SGDIPrint_OpenPrinterProperties(pPrinterName, hwndParent) {
  out := DllCall("Winspool.drv\OpenPrinter", "Ptr", &pPrinterName, "Ptr*", pPrinter, "Ptr", 0, "Ptr")
  If !out
     Return 0

   if !(DllCall("winspool.drv\PrinterProperties", "Ptr", hwndParent, "Ptr", pPrinter))
      return 0
   return 1
}

SGDIPrint_AbortPrinter(pPrinterName) {
  out := DllCall("Winspool.drv\OpenPrinter", "Ptr", &pPrinterName, "Ptr*", pPrinter, "Ptr", 0, "Ptr")
  If !out
     Return 0

   if !(DllCall("winspool.drv\AbortPrinter", "Ptr", pPrinter))
      return 0
   return 1
}


SGDIPrint_ConnectToPrinterDlg(hwndParent) {
   if !(DllCall("winspool.drv\ConnectToPrinterDlg", "Ptr", hwndParent, "uint", 0))
      return 0
   return 1
}

