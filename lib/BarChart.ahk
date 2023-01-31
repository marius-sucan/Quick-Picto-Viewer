;===Description=========================================================================
/*
[function] BarChart
Author:     Learning one (Boris Mudrinić)
Contact:    boris.mudrinic@gmail.com
Version:    1.01 updated to v1.2 [25/03/2022]
Link:       https://www.autohotkey.com/community/viewtopic.php?f=2&t=89246
            https://www.autohotkey.com/boards/viewtopic.php?f=6&t=12300

Updated by Marius Șucan

Requires Gdip.ahk by Tic; www.autohotkey.com/community/viewtopic.php?f=2&t=32238
Compatible with AHK_L and AHK Basic

====== License ======
You can non-commercialy use and redistribute BarChart if put 2 things in your product's documentation or "About MsgBox"; 1) credit to the author, 2) link to BarChart's AutoHotkey forum post. Author is not responsible for any damages arising from use or redistribution of his work. If redistributed in source form, you are not allowed to remove comments from this file. If you are interested in commercial usage, contact the author to get permission for it.

====== Documentation ======
BarChart(ChartData, Width, Height="", TitleText="", Skin="LightOrange", Options="")

=ChartData=
Must be a simple array.

=LabelsData=
Must be a simple array.

=Width, Height=
[Case A] If Width is a number, than Width and Height parameters represent dimensions of a bitmap
in which BarChart will be drawn. BarChart() will return a pointer to BarChart bitmap (pBitmap).
Use this bitmap to set it to picture control in your GUI, create layered window from it, save it
to file, set it to clipboard, etc. To create and use bitmap, call Gdip_Startup() first, than
BarChart(), than do what you want with bitmap, than Gdip_DisposeImage(), and finally Gdip_Shutdown().
[Case B] If Width is not a number, than it can be : 1) name of the picture control's associated
variable or 2) a string "hwnd" followed by the variable which holds a handle of the picture control.
In this case, BarChart() will automaticaly get picture control's width and height, create Barchart
bitmap whose width and height will be equal to picture control's width and height, set bitmap
to picture control and than dispose of that bitmap. BarChart()'s return value will be blank
(it will not return pBitmap). In this case, Height parameter represents Gui number.
If blank, it is set to 1.

BarChart is centered in its width and height. BarChart is cropped (not scaled) if it is bigger 
than specified bitmap's width and height.

=TitleText=
Optional. BarChart's title. If blank, entire title bar in chart won't be drawn.

=Skin=
Optional. It is a set of BarChart's pre-defined graphical attributes. You can create your own
skins, and override pre-defined skin attributes. Here is a list of pre-defines skins;

SimpleGreen,SimpleBlue,SimpleOrange,
LightGreen,LightBlue,LightOrange,
ClassicGreen,ClassicBlue,ClassicOrange,
DiagonBlackGreen,DiagonBlackBlue,DiagonBlackOrange,
DiagonWhiteGreen,DiagonWhiteBlue,DiagonWhiteOrange,
OutlinesWhite,OutlinesGray,OutlinesDark,
DarkT,Bricks

=Options=
Optional. Here you can set and override a bunch of BarChart's pre-defined graphical and other
attributes like; BarSpacing, BarRoundness, BarHeightFactor, MaxValue, TextSize, TextFont,
DataAlignment, TitleAlignment, ValuesSuffix, BackgroundImage and many more. For a full list
you'll have to look in the code. Look at examples to learn how to use them.

Syntax is "AttributeA:valueA, AttributeB:valueB, AttributeZ:valueZ".

Example: "BarHeightFactor:1.8, ValuesSuffix: °C, DataAlignment:Center"

=Return value=
Can be: 1) pointer to BarChart bitmap (pBitmap) or 2) blank value. For more info see Width, Height parameters

=GDI+ Startup & Shutdown=
The user must call Gdip_Startup to use create BarChart bitmaps
and call Gdip_Shutdown() when no longer needed

=Change log=
-- v1.2 - vendredi 25 mars 2022
-- added options: MaxPercentValue, AutoCalculateHeight, BarHeight
            -- set AutoCalculateHeight=1 to have the function automatically calculate
               the size of the returned bitmap
            -- BgrStyle=1 = gradient background  
               BgrStyle=2 = hatch background  
               BgrStyle=3 = simple solid colored background  
               BgrStyle=0 = default [combined 1 and 2]

-- changed: -- if TextSize=0 no labels or values are displayed for the bars
            -- ChartData is only accepting arrays
            -- LabelsData -- new parameter to set the text labels for the bars
            -- one can set BarColorDirection=2, to draw bars with a simple color
            -- set BarColorDirection=3 to draw bars with a simple/solid color and peaks; set BarPeaksColor
*/

;===Function============================================================================
BarChart(ChartData, LabelsData, Width, Height:="", TitleText:="", Skin:="LightOrange", Options:="") {
; by Learning one
; found on https://www.autohotkey.com/boards/viewtopic.php?f=6&t=12300
; updated by Marius Șucan on jeudi 24 mars 2022

    ;=== Skin ===
    if Skin in SimpleGreen,SimpleBlue,SimpleOrange
    {
        if (Skin = "SimpleGreen")
            Color := "BEF4B2"
        else if (Skin = "SimpleBlue")
            Color := "D8DFFF"
        else if (Skin = "SimpleOrange")
            Color := "FFE67A"
        BarColorA := "ff" Color, BarColorB := "ff" Color, BarColorDirection := 1, BarBorderColor := 0, BarTextColor := "ff000000", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := 0, TitleBackColorB := 0, TitleBackColorDirection := 1, TitleBorderColor := 0, TitleTextColor := "ff000000", TitleHeightFactor := 1
        PlotBackColorA := "ffffffff", PlotBackColorB := "ffffffff", PlotBackColorDirection := 1, PlotRangeBorderColor := 0
        ChartBackColorA := "ffffffff", ChartBackColorB := "ffffffff", ChartBackColorDirection := 1
        ChartBackHatchColorA :=  0, ChartBackHatchColorB := 0, ChartBackHatchStyle :=  0
    }
    else if Skin in LightGreen,LightBlue,LightOrange
    {
        if (Skin = "LightGreen")
            Color := "AEEA9A"
        else if (Skin = "LightBlue")
            Color := "B8BFDD"
        else if (Skin = "LightOrange")
            Color := "F7DC42"
        BarColorA := "33" Color, BarColorB := "ff" Color, BarColorDirection := 0, BarBorderColor := "ee" Color, BarTextColor := "ff555555", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := 0, TitleBackColorB := 0, TitleBackColorDirection := 1, TitleBorderColor := 0, TitleTextColor := "ff6B624C", TitleHeightFactor := 1
        PlotBackColorA := 0, PlotBackColorB := 0, PlotBackColorDirection := 1, PlotRangeBorderColor := 0
        ChartBackColorA := "ffffffff", ChartBackColorB := "ffffffff", ChartBackColorDirection := 1
        ChartBackHatchColorA :=  0, ChartBackHatchColorB := 0, ChartBackHatchStyle :=  18
    }
    else if Skin in ClassicGreen,ClassicBlue,ClassicOrange
    {
        if (Skin = "ClassicGreen")
            Color := "AEEA9A"
        else if (Skin = "ClassicBlue")
            Color := "B8BFDD"
        else if (Skin = "ClassicOrange")
            Color := "F7DC42"
        BarColorA := 0, BarColorB := "ff" Color, BarColorDirection := 1, BarBorderColor := "88" Color, BarTextColor := "ff555555", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := 0, TitleBackColorB := 0, TitleBackColorDirection := 0, TitleBorderColor := 0, TitleTextColor := "ff6B624C", TitleHeightFactor := 1
        PlotBackColorA := 0, PlotBackColorB := 0, PlotBackColorDirection := 0, PlotRangeBorderColor := 0
        ChartBackColorA := "ffffffff", ChartBackColorB := "ffffffff", ChartBackColorDirection := 1
        ChartBackHatchColorA :=  0, ChartBackHatchColorB := 0, ChartBackHatchStyle :=  18
    }
    else if Skin in DiagonBlackGreen,DiagonBlackBlue,DiagonBlackOrange
    {
        if (Skin = "DiagonBlackGreen")
            Color := "469336"
        else if (Skin = "DiagonBlackBlue")
            Color := "071D9E"
        else if (Skin = "DiagonBlackOrange")
            Color := "BF7C00"
        BarColorA := "33" Color, BarColorB := "ff" Color, BarColorDirection := 0, BarBorderColor := "ff" Color, BarTextColor := "ffdddddd", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := 0, TitleBackColorB := 0, TitleBackColorDirection := 1, TitleBorderColor := 0, TitleTextColor := "ffdddddd", TitleHeightFactor := 1
        PlotBackColorA := 0, PlotBackColorB := 0, PlotBackColorDirection := 1, PlotRangeBorderColor := 0
        ChartBackColorA := "ff000000", ChartBackColorB := "ff000000", ChartBackColorDirection := 1
        ChartBackHatchColorA :=  "20ffffff", ChartBackHatchColorB := 0, ChartBackHatchStyle :=  18
    }
    else if Skin in DiagonWhiteGreen,DiagonWhiteBlue,DiagonWhiteOrange
    {
        if (Skin = "DiagonWhiteGreen")
            Color := "AEEA9A"
        else if (Skin = "DiagonWhiteBlue")
            Color := "B8BFDD"
        else if (Skin = "DiagonWhiteOrange")
            Color := "F4CE44"
        BarColorA := "ffffffff", BarColorB := "ff" Color, BarColorDirection := 1, BarBorderColor := "ff" Color, BarTextColor := "ff333333", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := "ffffffff", TitleBackColorB := "55ffffff", TitleBackColorDirection := 1, TitleBorderColor := "ffdddddd", TitleTextColor := "ff555555", TitleHeightFactor := 1.4
        PlotBackColorA := "55ffffff", PlotBackColorB := "ffffffff", PlotBackColorDirection := 1, PlotRangeBorderColor := "ffdddddd"
        ChartBackColorA := "ffffffff", ChartBackColorB := "fff7f7f7", ChartBackColorDirection := 1
        ChartBackHatchColorA := "ffffffff", ChartBackHatchColorB := "ffffffff", ChartBackHatchStyle :=  18
    }
    else if skin in OutlinesWhite,OutlinesGray,OutlinesDark 
    {
        if (Skin = "OutlinesWhite")
            OutlineColor := "ff666666", BackgroundColor := "ffffffff"
        else if (Skin = "OutlinesGray")
            OutlineColor := "ffffffff", BackgroundColor := "ff888888"
        else
            OutlineColor := "ffcccccc", BackgroundColor := "ff181818"
        BarColorA := 0, BarColorB := 0, BarColorDirection := 1, BarBorderColor := OutlineColor, BarTextColor := OutlineColor, BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := 0, TitleBackColorB := 0, TitleBackColorDirection := 1, TitleBorderColor := "", TitleTextColor := OutlineColor, TitleHeightFactor := 1
        PlotBackColorA := 0, PlotBackColorB := 0, PlotBackColorDirection := 1, PlotRangeBorderColor := ""
        ChartBackColorA := BackgroundColor, ChartBackColorB := BackgroundColor, ChartBackColorDirection := 1
        ChartBackHatchColorA :=  0, ChartBackHatchColorB := 0, ChartBackHatchStyle :=  38
    }
    else if (Skin = "DarkT") {
        BarColorA := "ff858ADB", BarColorB := "ff383C77", BarColorDirection := 1, BarBorderColor := 0, BarTextColor := "ffffffff", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := "aa000000", TitleBackColorB := "66000022", TitleBackColorDirection := 1, TitleBorderColor := 0, TitleTextColor := "ffffffff", TitleHeightFactor := 1.4
        PlotBackColorA := "66000022", PlotBackColorB := "aa333344", PlotBackColorDirection := 1, PlotRangeBorderColor := 0
        ChartBackColorA := "ff333344", ChartBackColorB := "ff111122", ChartBackColorDirection := 1
        ChartBackHatchColorA :=  "44000000", ChartBackHatchColorB := 0, ChartBackHatchStyle :=  21
    }
    else if (Skin = "Bricks") {
        BarColorA := "ffffffff", BarColorB := "99619B68", BarColorDirection := 1, BarBorderColor := "44619B68", BarTextColor := "ff555555", BarColorWidthDiv := 1, BarColorHeightDiv := 1
        TitleBackColorA := "ffffffff", TitleBackColorB := "ccffffff", TitleBackColorDirection := 1, TitleBorderColor := "ffbbbbbb", TitleTextColor := "ff6B624C", TitleHeightFactor := 1.4
        PlotBackColorA := "ccffffff", PlotBackColorB := "ffffffff", PlotBackColorDirection := 1, PlotRangeBorderColor := "ffbbbbbb"
        ChartBackColorA := "ffffffff", ChartBackColorB := "ffffffff", ChartBackColorDirection := 1
        ChartBackHatchColorA :=  "45000000", ChartBackHatchColorB := 0, ChartBackHatchStyle :=  38
    }
    
    ;=== if user wants to automaticaly set bitmap to picture control and than dispose of it ===
    if Width is not number
    {
        ; In this case width can be: 1) name of the control's associated variable or 2) a string "hwnd" followed by the handle of the control
        SetBitmap2Control := 1
        ControlID := Width
        GuiNum := (Height = "") ? 1 : Height    ; in this case, Height parameter represents Gui number
        
        if (SubStr(Width,1,4) = "hwnd")
        {
            ; extra feature for AHK_L users - use  handle of the control
            PotentialHwnd := SubStr(Width,5)
            if PotentialHwnd is number
                hControl := PotentialHwnd, ControlID := PotentialHwnd    ; [AHK_L v1.1.04+]: ControlID can be the HWND of the control
            else
                GuiControlGet, hControl, %GuiNum%:hwnd, %ControlID%
        } else        
            GuiControlGet, hControl, %GuiNum%:hwnd, %ControlID%

        GuiControlGet, Control, %GuiNum%:Pos, %ControlID%    ; get control's Width & Height
        Width := ControlW, Height := ControlH                ; store control's Width & Height
    }
    
    ;=== User's options & overrides ===    
    Loop, Parse, Options, `,, %A_Space%
    {
        colonpos := InStr(A_LoopField, ":")
        If !colonpos
            Continue

        var := SubStr(A_LoopField, 1, colonpos-1)
        val := SubStr(A_LoopField, colonpos+1)
        %var% := val
    }

    ;=== Other options, defaults ===    
    BarSpacing := (BarSpacing="") ? 4 : BarSpacing
    BarRoundness := (BarRoundness="") ? 4 : BarRoundness
    BarHeight := !BarHeight ? 1.5 : BarHeight
    BarHeight := !BarHeight ? 1.5 : BarHeight
    BarHeightFactor := (BarHeightFactor = "") ? 1.4 : BarHeightFactor
    BarColorsFlip := (BarColorsFlip = "") ? 0 : BarColorsFlip
    BarPeaksColor := (BarPeaksColor = "") ? "77ff2299" : BarPeaksColor
    
    TextIndentation := (TextIndentation = "") ? 4 : TextIndentation
    RowsDelimiter := (RowsDelimiter = "") ? "`n" : RowsDelimiter
    ColumnsDelimiter := (ColumnsDelimiter = "") ? "`t" : ColumnsDelimiter
    DisplayValues := (DisplayValues = "") ? 1 : DisplayValues
    DataValueSeparator := (DataValueSeparator = "") ? ": " : DataValueSeparator
    ValuesSuffix := (ValuesSuffix = "") ? "" : ValuesSuffix
    DataAlignment := (DataAlignment = "") ? "Left" : DataAlignment    ; Left,Right,Center. Note: case sensitive!
    MaxValue := (MaxValue = "") ? 0 : MaxValue
    MaxPercentValue := !MaxPercentValue ? 1 : MaxPercentValue

    TextFont := (TextFont = "") ? "Arial" : TextFont
    TextSize := (TextSize = "") ? 12 : TextSize
    TextRendering := (TextRendering = "") ? 5 : TextRendering
    TitleTextSize := (TitleTextSize = "") ? 14 : TitleTextSize
    TitleTextFormat := (TitleTextFormat = "") ? "Bold" : TitleTextFormat    ; Available formats: "Regular|Bold|Italic|BoldItalic|Underline|Strikeout". Note: case sensitive!
    TitleAlignment := (TitleAlignment = "") ? DataAlignment : TitleAlignment    ; Left,Right,Center. Note: case sensitive!
    TitleIndentation := (TitleIndentation = "") ? 0 : TitleIndentation
    
    FrameWidth := (FrameWidth = "") ? 8 : FrameWidth
    SmoothingMode := (SmoothingMode = "") ? 4 : SmoothingMode
    
    ;=== If user didn't use obligatory Title case for Gdip_TextToGraphics() options, fix it ===
    StringUpper, DataAlignment, DataAlignment, T
    StringUpper, TitleTextFormat, TitleTextFormat, T
    StringUpper, TitleAlignment, TitleAlignment, T
    if InStr(TitleTextFormat, "Bolditalic")
       TitleTextFormat := StrReplace(TitleTextFormat, "Bolditalic", "BoldItalic")

    ;=== Bitmap, Graphics, SmoothingMode ===
    pBitmap := Gdip_CreateBitmap(Width, Height)
    if !pBitmap    ; than user probably didn't start up GDI+
       return

    G := Gdip_GraphicsFromImage(pBitmap), Gdip_SetSmoothingMode(G, SmoothingMode)

    ;=== Get Bar height ===
    If (TextSize && TextSize>1)
    {
       TextMeasure := Gdip_TextToGraphics(G, "T_", "x0 y0 Vcenter " DataAlignment " c" BarTextColor " r" TextRendering " s" TextSize, TextFont, Width, Height, 1)
       StringSplit, m, TextMeasure, |
       TextHeight := m4
       BarHeight := TextHeight*BarHeightFactor
    } Else
       BarHeight := BarHeight*BarHeightFactor

    ;=== Get Title height ===
    if (TitleText!="")
    {
       TextMeasure := Gdip_TextToGraphics(G, TitleText, "x" FrameWidth " y0 Vcenter " TitleAlignment " " TitleTextFormat " c" TitleTextColor " r" TextRendering " s" TitleTextSize, TextFont, Width - FrameWidth*2, "", 1)
       StringSplit, m, TextMeasure, |
       TitleHeight := (BarHeight > m4) ? BarHeight : m4
       TitleHeight *= TitleHeightFactor
    } else TitleHeight := 0

    ;=== Get dimensions, layout... ===
    TotalBars := ChartData.Count(), MaxPositiveValues := 0, MaxNegativeValues := 0
    Loop, % TotalBars
    {
        v := ChartData[A_Index]
        If v is not Number
           Continue

        MaxPositiveValues := max(MaxPositiveValues, v)
        MaxNegativeValues := min(MaxNegativeValues, v)
    }

    MaxPositiveValues *= MaxPercentValue
    MaxValue := abs(MaxValue)
    if (MaxPositiveValues>0 && MaxNegativeValues=0)
    { ; only positive
        ChartDataMaxRange := (MaxValue > MaxPositiveValues) ? MaxValue : MaxPositiveValues
    } else if (MaxPositiveValues=0 && MaxNegativeValues<0) { ; only negative
        ChartDataMaxRange := (MaxValue > abs(MaxNegativeValues)) ? - MaxValue : MaxNegativeValues
    } else if (MaxPositiveValues>0 && MaxNegativeValues<0)
    { ; positive & negative
        ChartDataMaxRange := max(MaxValue, MaxPositiveValues, Abs(MaxNegativeValues))*2
        DataAlignment := "Center", TitleAlignment := "Center"    ; force to Center data and title alignment
    } else    ; zeros
        ChartDataMaxRange := 1

    TotalBarSpacing := (TotalBars-1)*BarSpacing
    MaxBarWidth := Width - FrameWidth*2
    BarUnitWidth := abs(MaxBarWidth/ChartDataMaxRange)
    if (TitleText!="")
        y := (Height-(BarHeight*TotalBars+TotalBarSpacing+TitleHeight+BarSpacing))/2
    else
        y := (Height-(BarHeight*TotalBars+TotalBarSpacing))/2

    If (AutoCalculateHeight=1)
    {
       y := TitleHeight
       height := Round(2*TitleHeight+BarHeight*TotalBars+TotalBarSpacing)
       Gdip_DeleteGraphics(G)
       Gdip_DisposeImage(pBitmap)
       pBitmap := Gdip_CreateBitmap(Width,height)
       if !pBitmap    ; than user probably didn't start up GDI+
          return

       G := Gdip_GraphicsFromImage(pBitmap), Gdip_SetSmoothingMode(G, SmoothingMode)
    }

    ;=== Draw Background image ===
    if BackgroundImage
    {
        if (SubStr(BackgroundImage,1,3) = "ptr")
        {    ; if user passes pointer to bitmap. Example: "ptr" pBackgroundBitmap
            PotentialpBitmap := SubStr(BackgroundImage,4)
            if PotentialpBitmap is number
               pBackgroundBitmap := PotentialpBitmap
            else
               pBackgroundBitmap := Gdip_CreateBitmapFromFile(BackgroundImage)
        } else                                        ; if user passes image's full path. Example: "C:\Pictire.jpg"
            pBackgroundBitmap := Gdip_CreateBitmapFromFile(BackgroundImage)
        Gdip_DrawImage(G, pBackgroundBitmap, 0, 0, Width, Height)
        Gdip_DisposeImage(pBackgroundBitmap)
    }

    If (BgrStyle=1)
    {    ;=== Draw Chart back ===
       pBrush := Gdip_CreateLineBrushFromRect(0, 0, Width, Height, "0x" ChartBackColorA, "0x" ChartBackColorB, ChartBackColorDirection, 1)
       Gdip_FillRectangle(G, pBrush, 0, 0, Width, Height)
       Gdip_DeleteBrush(pBrush)
    } Else If (BgrStyle=2)
    {
       pBrush := Gdip_BrushCreateHatch("0x" ChartBackHatchColorA, "0x" ChartBackHatchColorB, ChartBackHatchStyle)
       Gdip_FillRectangle(G, pBrush, 0, 0, Width, Height)
       Gdip_DeleteBrush(pBrush)
    } Else If (BgrStyle=3)
    {
       pBrush := Gdip_BrushCreateSolid("0x" ChartBackColorA)
       Gdip_FillRectangle(G, pBrush, 0, 0, Width, Height)
       Gdip_DeleteBrush(pBrush)
    } Else
    {
       pBrush := Gdip_CreateLineBrushFromRect(0, 0, Width, Height, "0x" ChartBackColorA, "0x" ChartBackColorB, ChartBackColorDirection, 1)
       Gdip_FillRectangle(G, pBrush, 0, 0, Width, Height)
       Gdip_DeleteBrush(pBrush)

       pBrush := Gdip_BrushCreateHatch("0x" ChartBackHatchColorA, "0x" ChartBackHatchColorB, ChartBackHatchStyle)
       Gdip_FillRectangle(G, pBrush, 0, 0, Width, Height)
       Gdip_DeleteBrush(pBrush)
    }

    ;=== Draw Title area ===
    if (TitleText!="")
    {
        if (TitleBackColorA!=0 || TitleBackColorB!=0)
        {
           pBrush := Gdip_CreateLineBrushFromRect(FrameWidth, y, MaxBarWidth, TitleHeight, "0x" TitleBackColorA, "0x" TitleBackColorB, TitleBackColorDirection, 1)
           Gdip_FillRoundedRectangle(G, pBrush, FrameWidth, y, MaxBarWidth, TitleHeight, BarRoundness)
           Gdip_DeleteBrush(pBrush)
        }

        if (TitleBorderColor!=0)
        {
           pPen := Gdip_CreatePen("0x" TitleBorderColor, 1)
           Gdip_DrawRoundedRectangle(G, pPen, FrameWidth, y, MaxBarWidth, TitleHeight, BarRoundness)
           Gdip_DeletePen(pPen)
        }
        Gdip_TextToGraphics(G, TitleText, "x" FrameWidth + TitleIndentation " y" y+1 " Vcenter " TitleAlignment " "  TitleTextFormat " c" TitleTextColor " r" TextRendering " s" TitleTextSize, TextFont, MaxBarWidth - TitleIndentation*2, TitleHeight)
        y := y+TitleHeight+BarSpacing
    }

    ;=== Draw Plot area ===
    if (PlotBackColorA!=0 || PlotBackColorB!=0)
    {
       pBrush := Gdip_CreateLineBrushFromRect(FrameWidth, y, MaxBarWidth, BarHeight*TotalBars+TotalBarSpacing, "0x" PlotBackColorA, "0x" PlotBackColorB, PlotBackColorDirection, 1)
       Gdip_FillRoundedRectangle(G, pBrush, FrameWidth, y, MaxBarWidth, BarHeight*TotalBars+TotalBarSpacing, BarRoundness)
       Gdip_DeleteBrush(pBrush)
    }

    if (PlotRangeBorderColor!=0)
    {
       pPen := Gdip_CreatePen("0x" PlotRangeBorderColor, 1)
       Gdip_DrawRoundedRectangle(G, pPen, FrameWidth, y, MaxBarWidth, BarHeight*TotalBars+TotalBarSpacing, BarRoundness)        
       Gdip_DeletePen(pPen)
    }
    
    ;=== Draw Bars & Text ===
    if (BarBorderColor!=0)
       pPen := Gdip_CreatePen("0x" BarBorderColor, 1)

    if (BarColorDirection=3)
       pBrushPeaks := Gdip_BrushCreateSolid("0x" BarPeaksColor)

    If (BarColorDirection=2 || BarColorDirection=3)
       pBrushSolid := Gdip_BrushCreateSolid("0x" BarColorA)
 
    y := y-BarHeight-BarSpacing
    Loop, % ChartData.Count()
    {
        y := y+BarHeight+BarSpacing
        Field1 := LabelsData[A_Index]
        Field2 := ChartData[A_Index]
        if (MaxPositiveValues>0 && MaxNegativeValues<0)
        {
            ; positive & negative. (forced Center data and title alignment)
            x := (Field2>=0) ? Width/2 : Width/2 - BarUnitWidth*abs(Field2)
            DivW := 2
        } else
        {
            if (DataAlignment="Right")
                x := Width - FrameWidth-BarUnitWidth*abs(Field2)
            else if (DataAlignment="Center")
                x := FrameWidth + (MaxBarWidth - BarUnitWidth*abs(Field2))/2
            else ; if (DataAlignment="Left")
                x := FrameWidth
            DivW := 1
        }

        if (Field2!="")
        {
            if (BarColorA!=0 || BarColorB!=0)
            {
               If (BarColorDirection=3)
               {
                  Gdip_FillRectangle(G, pBrushSolid, x, y, BarUnitWidth*abs(Field2) + 0.2, BarHeight)
                  Gdip_FillRectangle(G, pBrushPeaks, x + BarUnitWidth*abs(Field2) + 0.2, y - BarHeight/2, (BarUnitWidth + BarSpacing)*5 + 2, BarHeight*2)
               } Else If (BarColorDirection=2)
               {
                  Gdip_FillRectangle(G, pBrushSolid, x, y, BarUnitWidth*abs(Field2) + 0.5, BarHeight)
               } Else
               {
                   if !BarColorsFlip
                       pBrush := Gdip_CreateLineBrushFromRect(x, y, MaxBarWidth/BarColorWidthDiv/DivW, BarHeight/BarColorHeightDiv, "0x" BarColorA, "0x" BarColorB, BarColorDirection, 1)
                   else
                       pBrush := Gdip_CreateLineBrushFromRect(x, y, MaxBarWidth/BarColorWidthDiv/DivW, BarHeight/BarColorHeightDiv, "0x" BarColorB, "0x" BarColorA, BarColorDirection, 1)

                   Gdip_FillRectangle(G, pBrush, x, y, BarUnitWidth*abs(Field2), BarHeight)
                   Gdip_DeleteBrush(pBrush)
                }
            }

            if (BarBorderColor!=0 && pPen!="")
                Gdip_DrawRectangle(G, pPen, x, y, BarUnitWidth*abs(Field2), BarHeight)
        }

        if (DisplayValues=2 && TextSize>1)
        {
            BarText := Field1 ValuesSuffix
        } else if (DisplayValues=1 && TextSize>1)
        {
            if (Field1="" && Field2="")
                BarText := ""
            else if (Field1!="" && Field2="")
                BarText := Field1
            else if (Field1="" && Field2!="")
                BarText := Field2 ValuesSuffix
            else if (Field1!="" && Field2!="")
                BarText := Field1 DataValueSeparator Field2 ValuesSuffix
        } else BarText := (TextSize>1) ? Field1 : ""

        if (DataAlignment="Left" && BarText!="")
            Gdip_TextToGraphics(G, BarText, "x" FrameWidth+TextIndentation " y" y+1 " Left Vcenter c" BarTextColor " r" TextRendering " s" TextSize, TextFont, MaxBarWidth-TextIndentation, BarHeight)
        else if (DataAlignment="Right" && BarText!="")
            Gdip_TextToGraphics(G, BarText, "x" FrameWidth " y" y+1 " Right Vcenter c" BarTextColor " r" TextRendering " s" TextSize, TextFont, MaxBarWidth-TextIndentation, BarHeight)
        else if (DataAlignment="Center" && BarText!="")
            Gdip_TextToGraphics(G, BarText, "x" FrameWidth " y" y+1 " Center Vcenter c" BarTextColor " r" TextRendering " s" TextSize, TextFont, MaxBarWidth, BarHeight)
    }

    If (BarColorDirection=2 || BarColorDirection=3)
       Gdip_DeleteBrush(pBrushSolid)

    If (BarColorDirection=3)
       Gdip_DeleteBrush(pBrushPeaks)

    Gdip_DeletePen(pPen)
    Gdip_DeleteGraphics(G)
    if SetBitmap2Control
    {
       hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap), SetImage(hControl, hBitmap), DeleteObject(hBitmap)    
       GuiControl, %GuiNum%:MoveDraw, %ControlID%    ; repaints the region of the GUI window occupied by the control
       Gdip_DisposeImage(pBitmap)
    } else return pBitmap
}
