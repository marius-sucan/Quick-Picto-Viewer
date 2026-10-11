; =============================================================================
;  ClipboardOCR.ahk  -  OCR the clipboard image using the Windows 10/11 OCR API
;                       (Windows.Media.Ocr, WinRT) from AutoHotkey v1.1
; =============================================================================
;  You can configure these through the Windows.Media.Ocr API:
;    - Recognizer language (OcrEngine.TryCreateFromLanguage /
;      TryCreateFromUserProfileLanguages, AvailableRecognizerLanguages)
;    - MaxImageDimension (read only - images get scaled down to fit it)
;  The API returns lines, words, word bounding boxes and the text angle.
;  The script adds some extra options of its own: upscaling the image before
;  recognition (helps a lot with small text), the output format, removing the
;  spaces it puts between CJK characters, auto-copy and auto-OCR.
; =============================================================================
#Requires AutoHotkey v1.1.33+
#NoEnv
#SingleInstance Force
SetBatchLines, -1

if (!A_IsUnicode) {
    MsgBox, 16, Clipboard OCR, This script requires the Unicode build of AutoHotkey.
    ExitApp
}
if !(A_OSVersion ~= "^10\.") {
    MsgBox, 16, Clipboard OCR, This script requires Windows 10 or Windows 11.
    ExitApp
}

; ---- super-globals ----------------------------------------------------------
global g_Ocr := "", g_Langs := [], g_LastResult := "", g_EditY := 0
global LangDDL, ScaleDDL, FormatDDL, CjkCB, AutoCopyCB, AutoOcrCB, ResultEdit, BtnOCR, SettingsGB

try g_Ocr := new WinOCR()
catch e {
    MsgBox, 16, Clipboard OCR, % "Could not initialize the Windows OCR API.`n`n" e.Message
    ExitApp
}

; ---- GUI ---------------------------------------------------------------------
Gui, Main:New, +Resize +MinSize640x420, Clipboard OCR (Windows.Media.Ocr)
Gui, Main:Font, s9, Segoe UI
Gui, Main:Add, Button, xm ym w180 h32 Default vBtnOCR gDoOCR, &OCR Clipboard Image
Gui, Main:Add, Button, x+8 yp w100 h32 gCopyResult, &Copy Text
Gui, Main:Add, Button, x+8 yp w80 h32 gClearResult, C&lear

Gui, Main:Add, GroupBox, xm y+10 w620 h124 vSettingsGB Section, OCR Settings
Gui, Main:Add, Text, xs+12 ys+26 w85, Language:
Gui, Main:Add, DropDownList, x+4 yp-4 w300 vLangDDL gLangChanged AltSubmit
Gui, Main:Add, Button, x+6 yp-1 w70 h25 gRefreshLangs, Refresh
Gui, Main:Add, Link, x+10 yp+5, <a href="ms-settings:regionlanguage">Install languages...</a>

Gui, Main:Add, Text, xs+12 y+16 w85, Upscale image:
Gui, Main:Add, DropDownList, x+4 yp-4 w80 vScaleDDL, Auto||1x|1.5x|2x|3x|4x
Gui, Main:Add, Text, x+20 yp+4, Output:
Gui, Main:Add, DropDownList, x+6 yp-4 w250 vFormatDDL gReformat AltSubmit
    , Lines||Single text (OcrResult.Text)|Words (one per line)|Words + bounding boxes|Lines + bounding boxes

Gui, Main:Add, Checkbox, xs+12 y+12 vCjkCB gReformat Checked, Remove spaces between CJK characters
Gui, Main:Add, Checkbox, x+16 yp vAutoCopyCB, Copy result to clipboard
Gui, Main:Add, Checkbox, x+16 yp vAutoOcrCB, Auto-OCR new clipboard images

Gui, Main:Font, s10, Consolas
Gui, Main:Add, Edit, xm ys+134 w620 h300 vResultEdit +WantTab
Gui, Main:Font
Gui, Main:Font, s9, Segoe UI
Gui, Main:Add, StatusBar

GuiControlGet, ep, Main:Pos, ResultEdit
g_EditY := epY

PopulateLanguages()
OnClipboardChange("ClipChanged")
Gui, Main:Show, w640 h580
return

; ---- GUI events -------------------------------------------------------------
MainGuiSize:
    if (A_EventInfo = 1)  ; minimized
        return
    GuiControlGet, sb, Main:Pos, msctls_statusbar321
    GuiControl, Main:Move, SettingsGB, % "w" (A_GuiWidth - 20)
    GuiControl, Main:Move, ResultEdit, % "w" (A_GuiWidth - 20) " h" (A_GuiHeight - g_EditY - sbH - 10)
return

MainGuiClose:
MainGuiEscape:
ExitApp

DoOCR:
AutoOcrTimer:
    RunOCR()
return

CopyResult:
    GuiControlGet, txt, Main:, ResultEdit
    if (txt != "")
        Clipboard := txt
return

ClearResult:
    GuiControl, Main:, ResultEdit
    g_LastResult := ""
return

RefreshLangs:
    PopulateLanguages()
return

LangChanged:
    Gui, Main:Submit, NoHide
    ApplyLanguage()
return

Reformat:
    Gui, Main:Submit, NoHide
    if IsObject(g_LastResult)
        ShowResult()
return

ClipChanged(type) {
    if (type != 2)  ; 2 = non-text data (e.g. an image)
        return
    GuiControlGet, on, Main:, AutoOcrCB
    if (on && DllCall("IsClipboardFormatAvailable", "UInt", 2))  ; CF_BITMAP
        SetTimer, AutoOcrTimer, -250
}

; ---- App logic ---------------------------------------------------------------
PopulateLanguages() {
    Gui, Main:Default
    try g_Langs := g_Ocr.GetAvailableLanguages()
    catch e
        g_Langs := []
    list := "|User profile languages (automatic)"
    for i, l in g_Langs
        list .= "|" l.Name "   [" l.Tag "]"
    GuiControl, Main:, LangDDL, %list%
    GuiControl, Main:Choose, LangDDL, 1
    ApplyLanguage()
}

ApplyLanguage(throwOnError := false) {
    Gui, Main:Default
    GuiControlGet, idx, Main:, LangDDL
    tag := (idx > 1) ? g_Langs[idx - 1].Tag : ""
    try {
        g_Ocr.SetLanguage(tag)
        SB_SetText("  Engine language: " g_Ocr.EngineLangName " [" g_Ocr.EngineLangTag "]"
            . "    |    Installed OCR languages: " g_Langs.Length()
            . "    |    Max image dimension: " g_Ocr.MaxDim " px")
    } catch e {
        msg := e.Message (g_Langs.Length() ? "" : "  No OCR language packs installed.")
        SB_SetText("  Error: " msg)
        if throwOnError
            throw Exception(msg)
    }
}

RunOCR() {
    static busy := false
    if busy
        return
    busy := true
    Gui, Main:Default
    Gui, Main:Submit, NoHide
    GuiControl, Main:Disable, BtnOCR
    hBmp := 0
    try {
        ApplyLanguage(true)
        hBmp := GetClipboardBitmap()
        if !hBmp
            throw Exception("The clipboard does not contain an image.")
        GetBitmapSize(hBmp, w, h)
        SB_SetText("  Recognizing " w "x" h " image...")
        t0 := A_TickCount

        auto := (ScaleDDL = "Auto")
        want := auto ? 1 : StrReplace(ScaleDDL, "x") + 0
        res := OcrAtScale(hBmp, w, h, FitScale(w, h, want))

        ; Auto mode: Windows OCR struggles with small text. If nothing was found
        ; or the median word height is small, try again with the image upscaled
        ; and keep whichever pass recognized more characters.
        if (auto) {
            mh := MedianWordHeight(res) / res.Scale
            target := (res.Lines.Length() = 0) ? 2 : (mh > 0 && mh < 18) ? Min(30 / mh, 4) : 1
            s2 := FitScale(w, h, target)
            if (s2 > res.Scale * 1.2) {
                res2 := OcrAtScale(hBmp, w, h, s2)
                if (CountChars(res2) >= CountChars(res))
                    res := res2
            }
        }

        g_LastResult := res
        text := ShowResult()
        if (AutoCopyCB && text != "")
            Clipboard := text

        nWords := 0
        for i, ln in res.Lines
            nWords += ln.Words.Length()
        angle := (res.Angle = "") ? "n/a" : Format("{:.2f}", res.Angle) Chr(176)
        SB_SetText(Format("  Done in {} ms  |  {} line(s), {} word(s)  |  {}x{} @ {:.2f}x  |  Text angle: {}  |  {}"
            , A_TickCount - t0, res.Lines.Length(), nWords, w, h, res.Scale, angle, g_Ocr.EngineLangTag))
    } catch e {
        SB_SetText("  Error: " e.Message)
    } finally {
        if hBmp
            DllCall("DeleteObject", "Ptr", hBmp)
        GuiControl, Main:Enable, BtnOCR
        busy := false
    }
}

OcrAtScale(hBmp, w, h, scale) {
    nw := Max(1, Floor(w * scale)), nh := Max(1, Floor(h * scale))
    hScaled := ScaleBitmap(hBmp, w, h, nw, nh)
    try res := g_Ocr.Recognize(hScaled)
    finally DllCall("DeleteObject", "Ptr", hScaled)
    res.Scale := nw / w
    return res
}

; Clamp the requested scale so that the image fits OcrEngine.MaxImageDimension.
FitScale(w, h, want) {
    s := want, maxD := g_Ocr.MaxDim
    if (w * s > maxD)
        s := maxD / w
    if (h * s > maxD)
        s := maxD / h
    return s
}

MedianWordHeight(res) {
    hs := ""
    for i, ln in res.Lines
        for j, wd in ln.Words
            hs .= wd.H "`n"
    hs := RTrim(hs, "`n")
    if (hs = "")
        return 0
    Sort, hs, N
    arr := StrSplit(hs, "`n")
    return arr[Ceil(arr.Length() / 2)]
}

CountChars(res) {
    return StrLen(RegExReplace(res.Text, "\s"))
}

ShowResult() {
    text := FormatResult(g_LastResult, FormatDDL, CjkCB)
    GuiControl, Main:, ResultEdit, %text%
    return text
}

FormatResult(res, fmt, cjk) {
    s := res.Scale, out := ""
    if (fmt = 2) {
        out := res.Text
    } else {
        for i, ln in res.Lines {
            if (fmt = 1) {
                out .= ln.Text "`n"
            } else if (fmt = 3) {
                for j, wd in ln.Words
                    out .= wd.Text "`n"
            } else if (fmt = 4) {
                for j, wd in ln.Words
                    out .= Format("{}`t[x={}, y={}, w={}, h={}]`n", wd.Text
                        , Round(wd.X / s), Round(wd.Y / s), Round(wd.W / s), Round(wd.H / s))
            } else if (fmt = 5) {
                x1 := y1 := 0x7FFFFFFF, x2 := y2 := -0x7FFFFFFF
                for j, wd in ln.Words {
                    x1 := Min(x1, wd.X), y1 := Min(y1, wd.Y)
                    x2 := Max(x2, wd.X + wd.W), y2 := Max(y2, wd.Y + wd.H)
                }
                out .= Format("{}`t[x={}, y={}, w={}, h={}]`n", ln.Text
                    , Round(x1 / s), Round(y1 / s), Round((x2 - x1) / s), Round((y2 - y1) / s))
            }
        }
    }
    out := RTrim(out, "`n")
    if (cjk) {
        ; Windows OCR separates every CJK character with a space - remove those
        c := "\x{3000}-\x{303F}\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{F900}-\x{FAFF}\x{FF00}-\x{FFEF}"
        out := RegExReplace(out, "(?<=[" c "]) +(?=[" c "])")
    }
    return out
}

; Returns a new HBITMAP (caller must DeleteObject) from the clipboard image, or
; from the first image file if files were copied in Explorer. 0 if none.
GetClipboardBitmap() {
    hCopy := 0
    if DllCall("IsClipboardFormatAvailable", "UInt", 2) {          ; CF_BITMAP
        Loop, 20 {
            if (opened := DllCall("OpenClipboard", "Ptr", A_ScriptHwnd))
                break
            Sleep, 25
        }
        if !opened
            throw Exception("Could not open the clipboard.")
        if (h := DllCall("GetClipboardData", "UInt", 2, "Ptr"))
            hCopy := DllCall("CopyImage", "Ptr", h, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x2000, "Ptr") ; LR_CREATEDIBSECTION
        DllCall("CloseClipboard")
    } else if DllCall("IsClipboardFormatAvailable", "UInt", 15) {  ; CF_HDROP
        Loop, Parse, Clipboard, `n, `r
        {
            if (A_LoopField ~= "i)\.(png|jpe?g|bmp|gif|tiff?|ico|webp)$") && FileExist(A_LoopField) {
                hCopy := LoadPicture(A_LoopField, "GDI+")
                break
            }
        }
    }
    return hCopy
}

GetBitmapSize(hBmp, ByRef w, ByRef h) {
    VarSetCapacity(bm, sz := (A_PtrSize = 8 ? 32 : 24), 0)
    DllCall("GetObject", "Ptr", hBmp, "Int", sz, "Ptr", &bm)
    w := NumGet(bm, 4, "Int"), h := Abs(NumGet(bm, 8, "Int"))
}

; Copies/resizes a bitmap into a new screen-compatible 32bpp bitmap.
ScaleBitmap(hSrc, w, h, nw, nh) {
    hdcScr := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcS := DllCall("CreateCompatibleDC", "Ptr", hdcScr, "Ptr")
    hdcD := DllCall("CreateCompatibleDC", "Ptr", hdcScr, "Ptr")
    hDst := DllCall("CreateCompatibleBitmap", "Ptr", hdcScr, "Int", nw, "Int", nh, "Ptr")
    if (hDst) {
        oS := DllCall("SelectObject", "Ptr", hdcS, "Ptr", hSrc, "Ptr")
        oD := DllCall("SelectObject", "Ptr", hdcD, "Ptr", hDst, "Ptr")
        DllCall("SetStretchBltMode", "Ptr", hdcD, "Int", (nw = w && nh = h) ? 3 : 4) ; COLORONCOLOR : HALFTONE
        DllCall("SetBrushOrgEx", "Ptr", hdcD, "Int", 0, "Int", 0, "Ptr", 0)
        DllCall("StretchBlt", "Ptr", hdcD, "Int", 0, "Int", 0, "Int", nw, "Int", nh
            , "Ptr", hdcS, "Int", 0, "Int", 0, "Int", w, "Int", h, "UInt", 0x00CC0020) ; SRCCOPY
        DllCall("SelectObject", "Ptr", hdcS, "Ptr", oS)
        DllCall("SelectObject", "Ptr", hdcD, "Ptr", oD)
    }
    DllCall("DeleteDC", "Ptr", hdcS)
    DllCall("DeleteDC", "Ptr", hdcD)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
    if !hDst
        throw Exception("Failed to create a " nw "x" nh " bitmap (out of memory?).")
    return hDst
}

; =============================================================================
;  WinRT Windows.Media.Ocr wrapper (raw vtable calls)
; =============================================================================
class WinOCR
{
    __New() {
        this.LangFactory := RtFactory("Windows.Globalization.Language", "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")    ; ILanguageFactory
        this.Decoder     := RtFactory("Windows.Graphics.Imaging.BitmapDecoder", "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}") ; IBitmapDecoderStatics
        this.Statics     := RtFactory("Windows.Media.Ocr.OcrEngine", "{5BFFA85A-3384-3540-9940-699120D428A8}")         ; IOcrEngineStatics
        DllCall(VT(this.Statics, 6), "Ptr", this.Statics, "UInt*", maxDim)   ; get_MaxImageDimension
        this.MaxDim := maxDim
        this.Engine := 0, this.EngineTag := "", this.EngineLangTag := "", this.EngineLangName := ""
    }

    __Delete() {
        for i, k in ["Engine", "Statics", "Decoder", "LangFactory"]
            if this[k]
                ObjRelease(this[k])
    }

    ; OcrEngine.AvailableRecognizerLanguages -> [{Tag, Name}, ...]
    GetAvailableLanguages() {
        arr := []
        CheckHR(DllCall(VT(this.Statics, 7), "Ptr", this.Statics, "Ptr*", list, "UInt"), "get_AvailableRecognizerLanguages")
        DllCall(VT(list, 7), "Ptr", list, "UInt*", n)                     ; IVectorView.Size
        Loop, %n% {
            DllCall(VT(list, 6), "Ptr", list, "UInt", A_Index - 1, "Ptr*", lang) ; IVectorView.GetAt
            arr.Push({Tag: LangTag(lang), Name: LangName(lang)})
            ObjRelease(lang)
        }
        ObjRelease(list)
        return arr
    }

    ; tag = BCP-47 tag (e.g. "en-US"), or "" for the user profile languages
    SetLanguage(tag) {
        if (this.Engine && tag == this.EngineTag)
            return
        engine := 0
        if (tag = "") {
            DllCall(VT(this.Statics, 10), "Ptr", this.Statics, "Ptr*", engine)        ; TryCreateFromUserProfileLanguages
            if !engine
                throw Exception("None of the user profile languages is supported for OCR.")
        } else {
            hs := HStr(tag)
            DllCall(VT(this.LangFactory, 6), "Ptr", this.LangFactory, "Ptr", hs, "Ptr*", lang) ; CreateLanguage
            HStrFree(hs)
            if !lang
                throw Exception("Invalid language tag: " tag)
            DllCall(VT(this.Statics, 8), "Ptr", this.Statics, "Ptr", lang, "Int*", supported)  ; IsLanguageSupported
            if supported
                DllCall(VT(this.Statics, 9), "Ptr", this.Statics, "Ptr", lang, "Ptr*", engine) ; TryCreateFromLanguage
            ObjRelease(lang)
            if !engine
                throw Exception("Language " tag " is not supported for OCR (install its OCR language pack).")
        }
        if this.Engine
            ObjRelease(this.Engine)
        this.Engine := engine, this.EngineTag := tag
        DllCall(VT(engine, 7), "Ptr", engine, "Ptr*", lang)                            ; get_RecognizerLanguage
        this.EngineLangTag := LangTag(lang), this.EngineLangName := LangName(lang)
        ObjRelease(lang)
    }

    Recognize(hBitmap) {
        if !this.Engine
            throw Exception("No OCR engine available.")
        stream := decoder := swbFrame := swb := result := 0
        try {
            stream := HBitmapToRandomAccessStream(hBitmap)
            CheckHR(DllCall(VT(this.Decoder, 14), "Ptr", this.Decoder, "Ptr", stream, "Ptr*", op, "UInt"), "BitmapDecoder.CreateAsync")
            decoder := RtAwait(op)
            swbFrame := ComObjQuery(decoder, "{FE287C9A-420C-4963-87AD-691436E08383}")   ; IBitmapFrameWithSoftwareBitmap
            CheckHR(DllCall(VT(swbFrame, 6), "Ptr", swbFrame, "Ptr*", op, "UInt"), "GetSoftwareBitmapAsync")
            swb := RtAwait(op)
            CheckHR(DllCall(VT(this.Engine, 6), "Ptr", this.Engine, "Ptr", swb, "Ptr*", op, "UInt"), "OcrEngine.RecognizeAsync")
            result := RtAwait(op)
            return this._ParseResult(result)
        } finally {
            for i, p in [result, swb, swbFrame, decoder]
                if p
                    ObjRelease(p)
            if stream {
                if (cl := ComObjQuery(stream, "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}")) { ; IClosable
                    DllCall(VT(cl, 6), "Ptr", cl)
                    ObjRelease(cl)
                }
                ObjRelease(stream)
            }
        }
    }

    ; IOcrResult -> {Text, Angle, Lines: [{Text, Words: [{Text, X, Y, W, H}]}]}
    _ParseResult(result) {
        res := {Text: "", Angle: "", Lines: []}
        DllCall(VT(result, 8), "Ptr", result, "Ptr*", hs)            ; get_Text
        res.Text := HStrGet(hs)
        DllCall(VT(result, 7), "Ptr", result, "Ptr*", angleRef)      ; get_TextAngle (IReference<double>)
        if angleRef {
            DllCall(VT(angleRef, 6), "Ptr", angleRef, "Double*", angle) ; get_Value
            res.Angle := angle
            ObjRelease(angleRef)
        }
        DllCall(VT(result, 6), "Ptr", result, "Ptr*", lines)         ; get_Lines
        DllCall(VT(lines, 7), "Ptr", lines, "UInt*", nLines)
        VarSetCapacity(rc, 16, 0)
        li := 0
        Loop, %nLines% {
            DllCall(VT(lines, 6), "Ptr", lines, "UInt", li++, "Ptr*", line)
            DllCall(VT(line, 7), "Ptr", line, "Ptr*", hs)            ; IOcrLine.get_Text
            ln := {Text: HStrGet(hs), Words: []}
            DllCall(VT(line, 6), "Ptr", line, "Ptr*", words)         ; IOcrLine.get_Words
            DllCall(VT(words, 7), "Ptr", words, "UInt*", nWords)
            wi := 0
            Loop, %nWords% {
                DllCall(VT(words, 6), "Ptr", words, "UInt", wi++, "Ptr*", word)
                DllCall(VT(word, 6), "Ptr", word, "Ptr", &rc)        ; IOcrWord.get_BoundingRect
                DllCall(VT(word, 7), "Ptr", word, "Ptr*", hs)        ; IOcrWord.get_Text
                ln.Words.Push({Text: HStrGet(hs)
                    , X: NumGet(rc, 0, "Float"), Y: NumGet(rc, 4, "Float")
                    , W: NumGet(rc, 8, "Float"), H: NumGet(rc, 12, "Float")})
                ObjRelease(word)
            }
            ObjRelease(words)
            ObjRelease(line)
            res.Lines.Push(ln)
        }
        ObjRelease(lines)
        return res
    }
}

; ---- WinRT / COM helpers -------------------------------------------------------
VT(p, i) {
    return NumGet(NumGet(p + 0, "Ptr") + i * A_PtrSize, "Ptr")
}

CheckHR(hr, what) {
    if (hr & 0x80000000)
        throw Exception(what " failed (HRESULT 0x" Format("{:08X}", hr) ")")
}

HStr(s) {
    DllCall("combase\WindowsCreateString", "WStr", s, "UInt", StrLen(s), "Ptr*", hs)
    return hs
}

HStrFree(hs) {
    DllCall("combase\WindowsDeleteString", "Ptr", hs)
}

HStrGet(hs, free := true) {
    if !hs
        return ""
    p := DllCall("combase\WindowsGetStringRawBuffer", "Ptr", hs, "UInt*", len, "Ptr")
    s := StrGet(p, len, "UTF-16")
    if free
        HStrFree(hs)
    return s
}

LangTag(lang) {
    DllCall(VT(lang, 6), "Ptr", lang, "Ptr*", hs)   ; ILanguage.get_LanguageTag
    return HStrGet(hs)
}

LangName(lang) {
    DllCall(VT(lang, 7), "Ptr", lang, "Ptr*", hs)   ; ILanguage.get_DisplayName
    return HStrGet(hs)
}

RtFactory(className, iid) {
    hs := HStr(className)
    VarSetCapacity(guid, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", iid, "Ptr", &guid)
    hr := DllCall("combase\RoGetActivationFactory", "Ptr", hs, "Ptr", &guid, "Ptr*", factory, "UInt")
    HStrFree(hs)
    CheckHR(hr, "RoGetActivationFactory(" className ")")
    return factory
}

; Waits for an IAsyncOperation<T>, releases it and returns its result.
RtAwait(op) {
    info := ComObjQuery(op, "{00000036-0000-0000-C000-000000000046}")  ; IAsyncInfo
    if !info {
        ObjRelease(op)
        throw Exception("Object is not an async operation.")
    }
    Loop {
        DllCall(VT(info, 7), "Ptr", info, "UInt*", status)   ; get_Status
        if (status != 0)                                      ; 0 = Started
            break
        Sleep, 10
    }
    if (status != 1) {                                        ; 1 = Completed
        DllCall(VT(info, 8), "Ptr", info, "UInt*", err)       ; get_ErrorCode
        ObjRelease(info), ObjRelease(op)
        throw Exception("Async operation " (status = 2 ? "canceled" : "failed (HRESULT 0x" Format("{:08X}", err) ")"))
    }
    ObjRelease(info)
    hr := DllCall(VT(op, 8), "Ptr", op, "Ptr*", result, "UInt") ; GetResults
    ObjRelease(op)
    CheckHR(hr, "GetResults")
    return result
}

; HBITMAP -> BMP in an IStream -> WinRT IRandomAccessStream
HBitmapToRandomAccessStream(hBitmap) {
    DllCall("ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", true, "Ptr*", pStream)
    VarSetCapacity(pd, sz := 8 + A_PtrSize * 2, 0)            ; PICTDESC
    NumPut(sz, pd, 0, "UInt"), NumPut(1, pd, 4, "UInt")       ; PICTYPE_BITMAP
    NumPut(hBitmap, pd, 8, "Ptr")
    VarSetCapacity(iidPic, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", "{7BF80980-BF32-101A-8BBB-00AA00300CAB}", "Ptr", &iidPic) ; IPicture
    hr := DllCall("oleaut32\OleCreatePictureIndirect", "Ptr", &pd, "Ptr", &iidPic, "Int", false, "Ptr*", pPicture, "UInt")
    if (hr || !pPicture) {
        ObjRelease(pStream)
        CheckHR(hr ? hr : 0x80004005, "OleCreatePictureIndirect")
    }
    DllCall(VT(pPicture, 15), "Ptr", pPicture, "Ptr", pStream, "Int", true, "Int*", size)  ; IPicture.SaveAsFile
    DllCall(VT(pStream, 5), "Ptr", pStream, "Int64", 0, "UInt", 0, "Ptr", 0)               ; IStream.Seek(0, SET)
    VarSetCapacity(iidRas, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}", "Ptr", &iidRas) ; IRandomAccessStream
    hr := DllCall("shcore\CreateRandomAccessStreamOverStream", "Ptr", pStream, "UInt", 0, "Ptr", &iidRas, "Ptr*", pRas, "UInt")
    ObjRelease(pPicture)
    ObjRelease(pStream)
    CheckHR(hr, "CreateRandomAccessStreamOverStream")
    return pRas
}
