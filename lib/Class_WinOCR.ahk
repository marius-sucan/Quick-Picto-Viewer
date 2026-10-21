; Text recognition (OCR) with the Windows.Media.Ocr WinRT API, available since Windows 10.
; The WinRT interfaces are called through their vtables. IInspectable takes the slots 0 to 5,
; so the first method of every interface used here sits in slot 6.
;
; The asynchronous calls are awaited with Sleep, which pumps messages: other threads can run
; while a recognition is in progress. Call RecognizeBitmap() or Recognize() from a thread that
; is not Critical: under Critical, Sleep leaves the messages above WM_HOTKEY queued, COM's too.

Class WinOCR {
   __New() {
      this.Engine := this.LangFactory := this.Decoder := this.Statics := 0
      this.EngineTag := this.EngineLangTag := this.EngineLangName := ""
      this.LangFactory := WinOCR_GetFactory("Windows.Globalization.Language", "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")      ; ILanguageFactory
      this.Decoder := WinOCR_GetFactory("Windows.Graphics.Imaging.BitmapDecoder", "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}") ; IBitmapDecoderStatics
      this.Statics := WinOCR_GetFactory("Windows.Media.Ocr.OcrEngine", "{5BFFA85A-3384-3540-9940-699120D428A8}")            ; IOcrEngineStatics
      maxDim := 0
      hr := DllCall(WinOCR_VTable(this.Statics, 6), "Ptr", this.Statics, "UInt*", maxDim, "UInt")  ; get_MaxImageDimension
      WinOCR_CheckHR(hr, "OcrEngine.MaxImageDimension")
      If (maxDim<1)
         Throw Exception("The text recognition engine reports an invalid maximum image size: " maxDim ".")
      this.MaxDim := maxDim
   }

   __Delete() {
      For i, k in ["Engine", "Statics", "Decoder", "LangFactory"]
      {
         If this[k]
            ObjRelease(this[k])
      }
   }

   GetAvailableLanguages() {
   ; OcrEngine.AvailableRecognizerLanguages as [{Tag, Name}, ...]
      langs := [], list := n := 0
      hr := DllCall(WinOCR_VTable(this.Statics, 7), "Ptr", this.Statics, "Ptr*", list, "UInt")  ; get_AvailableRecognizerLanguages
      WinOCR_CheckHR(hr, "OcrEngine.AvailableRecognizerLanguages")
      DllCall(WinOCR_VTable(list, 7), "Ptr", list, "UInt*", n)  ; IVectorView.get_Size
      Loop, % n
      {
         lang := 0
         DllCall(WinOCR_VTable(list, 6), "Ptr", list, "UInt", A_Index - 1, "Ptr*", lang)  ; IVectorView.GetAt
         If !lang
            Continue

         tag := WinOCR_LanguageTag(lang)
         name := WinOCR_LanguageName(lang)
         ObjRelease(lang)
         langs.Push({Tag: tag, Name: name})
      }

      ObjRelease(list)
      Return langs
   }

   SetLanguage(tag) {
   ; tag: a BCP-47 language tag, eg. en-US; empty = the languages of the user profile
      If (this.Engine && tag==this.EngineTag)
         Return

      engine := lang := supported := 0
      If (tag="")
      {
         DllCall(WinOCR_VTable(this.Statics, 10), "Ptr", this.Statics, "Ptr*", engine)  ; TryCreateFromUserProfileLanguages
         If !engine
            Throw Exception("None of the languages of the user profile can be used for text recognition. Install an OCR language pack.")
      } Else
      {
         hs := WinOCR_CreateHString(tag)
         DllCall(WinOCR_VTable(this.LangFactory, 6), "Ptr", this.LangFactory, "Ptr", hs, "Ptr*", lang)  ; CreateLanguage
         WinOCR_DeleteHString(hs)
         If !lang
            Throw Exception("Invalid language tag: " tag ".")

         DllCall(WinOCR_VTable(this.Statics, 8), "Ptr", this.Statics, "Ptr", lang, "Int*", supported)  ; IsLanguageSupported
         If (supported & 0xFF)
            DllCall(WinOCR_VTable(this.Statics, 9), "Ptr", this.Statics, "Ptr", lang, "Ptr*", engine)  ; TryCreateFromLanguage

         ObjRelease(lang)
         If !engine
            Throw Exception("The language " tag " cannot be used for text recognition. Install its OCR language pack.")
      }

      If this.Engine
         ObjRelease(this.Engine)

      this.Engine := engine, this.EngineTag := tag
      this.EngineLangTag := this.EngineLangName := ""
      lang := 0
      DllCall(WinOCR_VTable(engine, 7), "Ptr", engine, "Ptr*", lang)  ; IOcrEngine.get_RecognizerLanguage
      If lang
      {
         this.EngineLangTag := WinOCR_LanguageTag(lang)
         this.EngineLangName := WinOCR_LanguageName(lang)
         ObjRelease(lang)
      }
   }

   FitScale(w, h, want) {
   ; clamps the scale so the image fits within OcrEngine.MaxImageDimension
      s := want
      If (w*s>this.MaxDim)
         s := this.MaxDim/w
      If (h*s>this.MaxDim)
         s := this.MaxDim/h
      Return s
   }

   RecognizeBitmap(pBitmap, upscale:=0) {
   ; pBitmap: a GDI+ bitmap, it stays owned by the caller and it must stay valid until this returns
   ; upscale: the scale factor to recognize the image at; 0 = automatic
   ; Windows OCR misses small text. In automatic mode, when nothing is found or the words are
   ; small, the image is recognized again upscaled and the pass that found more characters wins.
   ; Returns {Text, Angle, Scale, Lines: [{Text, Words: [{Text, X, Y, W, H}]}]}, where Scale is
   ; the scale of the recognized image relative to pBitmap.
      Gdip_GetImageDimensions(pBitmap, w, h)
      If (w<1 || h<1)
         Throw Exception("Invalid bitmap.")

      want := upscale ? upscale : 1
      res := this._RecognizeAtScale(pBitmap, w, h, this.FitScale(w, h, want))
      If upscale
         Return res

      mh := WinOCR_MedianWordHeight(res) / res.Scale
      target := !res.Lines.Length() ? 2 : (mh>0 && mh<18) ? Min(30/mh, 4) : 1
      s2 := this.FitScale(w, h, target)
      If (s2>res.Scale*1.2)
      {
         res2 := this._RecognizeAtScale(pBitmap, w, h, s2)
         If (WinOCR_CountChars(res2)>=WinOCR_CountChars(res))
            res := res2
      }
      Return res
   }

   Recognize(hBitmap) {
   ; hBitmap: a GDI bitmap; it stays owned by the caller
      stream := this._StreamFromHBITMAP(hBitmap)
      Return this._RecognizeStream(stream)
   }

   _RecognizeAtScale(pBitmap, w, h, scale) {
      ; FitScale() returns its float formatted to 6 decimals, hence Round() and the clamp
      nw := Max(1, Min(Round(w*scale), this.MaxDim)), nh := Max(1, Min(Round(h*scale), this.MaxDim))
      ; the white default background of Gdip_CreateHBITMAPFromBitmap() fills the transparent pixels
      If (nw=w && nh=h)
      {
         hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
      } Else
      {
         pScaled := Gdip_ResizeBitmap(pBitmap, nw, nh, 0, 7)  ; 7 = InterpolationModeHighQualityBicubic
         If !pScaled
            Throw Exception("Unable to create a bitmap of " nw " x " nh " pixels. Out of memory?")

         hBitmap := Gdip_CreateHBITMAPFromBitmap(pScaled)
         Gdip_DisposeImage(pScaled, 1)
      }

      If !hBitmap
         Throw Exception("Unable to create a GDI bitmap of " nw " x " nh " pixels. Out of memory?")

      Try stream := this._StreamFromHBITMAP(hBitmap)
      Finally DllCall("gdi32\DeleteObject", "Ptr", hBitmap)

      res := this._RecognizeStream(stream)
      res.Scale := nw/w
      Return res
   }

   _RecognizeStream(stream) {
   ; stream: an IRandomAccessStream with an encoded image; it is closed and released here
      decoder := frame := swb := result := op := 0
      Try
      {
         If !this.Engine
            Throw Exception("No text recognition engine is available.")

         hr := DllCall(WinOCR_VTable(this.Decoder, 14), "Ptr", this.Decoder, "Ptr", stream, "Ptr*", op, "UInt")  ; BitmapDecoder.CreateAsync
         WinOCR_CheckHR(hr, "BitmapDecoder.CreateAsync")
         decoder := WinOCR_Await(op)
         frame := ComObjQuery(decoder, "{FE287C9A-420C-4963-87AD-691436E08383}")  ; IBitmapFrameWithSoftwareBitmap
         If !frame
            Throw Exception("The image decoder did not provide a software bitmap.")

         op := 0
         hr := DllCall(WinOCR_VTable(frame, 6), "Ptr", frame, "Ptr*", op, "UInt")  ; GetSoftwareBitmapAsync
         WinOCR_CheckHR(hr, "GetSoftwareBitmapAsync")
         swb := WinOCR_Await(op)
         op := 0
         hr := DllCall(WinOCR_VTable(this.Engine, 6), "Ptr", this.Engine, "Ptr", swb, "Ptr*", op, "UInt")  ; OcrEngine.RecognizeAsync
         WinOCR_CheckHR(hr, "OcrEngine.RecognizeAsync")
         result := WinOCR_Await(op)
         Return this._ParseResult(result)
      } Finally
      {
         For i, p in [result, swb, frame, decoder]
         {
            If p
               ObjRelease(p)
         }
         WinOCR_CloseRelease(stream)
      }
   }

   _StreamFromHBITMAP(hBitmap) {
   ; the bitmap saved as a BMP file in an IStream, wrapped in an IRandomAccessStream
      pStream := pPicture := pRas := size := 0
      hr := DllCall("ole32\CreateStreamOnHGlobal", "Ptr", 0, "Int", 1, "Ptr*", pStream, "UInt")
      WinOCR_CheckHR(hr, "CreateStreamOnHGlobal")
      VarSetCapacity(pd, sz := 8 + A_PtrSize*2, 0)  ; PICTDESC
      NumPut(sz, pd, 0, "UInt")
      NumPut(1, pd, 4, "UInt")  ; PICTYPE_BITMAP
      NumPut(hBitmap, pd, 8, "Ptr")
      VarSetCapacity(iid, 16, 0)
      DllCall("ole32\CLSIDFromString", "WStr", "{7BF80980-BF32-101A-8BBB-00AA00300CAB}", "Ptr", &iid)  ; IID_IPicture
      hr := DllCall("oleaut32\OleCreatePictureIndirect", "Ptr", &pd, "Ptr", &iid, "Int", 0, "Ptr*", pPicture, "UInt")
      If ((hr & 0x80000000) || !pPicture)
      {
         ObjRelease(pStream)
         WinOCR_CheckHR(hr ? hr : 0x80004005, "OleCreatePictureIndirect")  ; E_FAIL
      }

      hr := DllCall(WinOCR_VTable(pPicture, 15), "Ptr", pPicture, "Ptr", pStream, "Int", 1, "Int*", size, "UInt")  ; IPicture.SaveAsFile
      ObjRelease(pPicture)
      If (hr & 0x80000000)
      {
         ObjRelease(pStream)
         WinOCR_CheckHR(hr, "IPicture.SaveAsFile")
      }

      DllCall(WinOCR_VTable(pStream, 5), "Ptr", pStream, "Int64", 0, "UInt", 0, "Ptr", 0)  ; IStream.Seek, 0 = STREAM_SEEK_SET
      DllCall("ole32\CLSIDFromString", "WStr", "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}", "Ptr", &iid)  ; IID_IRandomAccessStream
      hr := DllCall("shcore\CreateRandomAccessStreamOverStream", "Ptr", pStream, "UInt", 0, "Ptr", &iid, "Ptr*", pRas, "UInt")  ; 0 = BSOS_DEFAULT
      ObjRelease(pStream)
      WinOCR_CheckHR(hr, "CreateRandomAccessStreamOverStream")
      Return pRas
   }

   _ParseResult(result) {
      res := {Text: "", Angle: "", Scale: 1, Lines: []}
      hs := angleRef := lines := nLines := 0
      DllCall(WinOCR_VTable(result, 8), "Ptr", result, "Ptr*", hs)  ; IOcrResult.get_Text
      res.Text := WinOCR_GetHString(hs)
      DllCall(WinOCR_VTable(result, 7), "Ptr", result, "Ptr*", angleRef)  ; IOcrResult.get_TextAngle, an IReference<double>
      If angleRef
      {
         angle := 0.0
         DllCall(WinOCR_VTable(angleRef, 6), "Ptr", angleRef, "Double*", angle)  ; IReference.get_Value
         res.Angle := angle
         ObjRelease(angleRef)
      }

      DllCall(WinOCR_VTable(result, 6), "Ptr", result, "Ptr*", lines)  ; IOcrResult.get_Lines
      If !lines
         Return res

      DllCall(WinOCR_VTable(lines, 7), "Ptr", lines, "UInt*", nLines)  ; IVectorView.get_Size
      VarSetCapacity(rc, 16, 0)
      lineIndex := 0
      Loop, % nLines
      {
         line := words := nWords := hs := 0
         DllCall(WinOCR_VTable(lines, 6), "Ptr", lines, "UInt", lineIndex++, "Ptr*", line)  ; IVectorView.GetAt
         If !line
            Continue

         DllCall(WinOCR_VTable(line, 7), "Ptr", line, "Ptr*", hs)  ; IOcrLine.get_Text
         ln := {Text: WinOCR_GetHString(hs), Words: []}
         DllCall(WinOCR_VTable(line, 6), "Ptr", line, "Ptr*", words)  ; IOcrLine.get_Words
         ObjRelease(line)
         If !words
         {
            res.Lines.Push(ln)
            Continue
         }

         DllCall(WinOCR_VTable(words, 7), "Ptr", words, "UInt*", nWords)
         wordIndex := 0
         Loop, % nWords
         {
            word := hs := 0
            DllCall(WinOCR_VTable(words, 6), "Ptr", words, "UInt", wordIndex++, "Ptr*", word)
            If !word
               Continue

            DllCall(WinOCR_VTable(word, 6), "Ptr", word, "Ptr", &rc)  ; IOcrWord.get_BoundingRect, a Rect of 4 floats
            DllCall(WinOCR_VTable(word, 7), "Ptr", word, "Ptr*", hs)  ; IOcrWord.get_Text
            ObjRelease(word)
            wd := {Text: WinOCR_GetHString(hs), X: NumGet(rc, 0, "Float"), Y: NumGet(rc, 4, "Float"), W: NumGet(rc, 8, "Float"), H: NumGet(rc, 12, "Float")}
            ln.Words.Push(wd)
         }

         ObjRelease(words)
         res.Lines.Push(ln)
      }

      ObjRelease(lines)
      Return res
   }
}

WinOCR_IsSupported() {
; Windows 11 reports itself as 10.0 as well
   Return (RegExMatch(A_OSVersion, "^(\d+)\.", v) && v1>=10) ? 1 : 0
}

WinOCR_FormatResult(res, fmt, joinCJK) {
; fmt: 1 = lines, 2 = the text as the engine joins it, 3 = words, one per line,
; 4 = words with their bounding boxes, 5 = lines with their bounding boxes.
; The boxes are in pixels of the bitmap given to RecognizeBitmap(), divided by res.Scale.
   If !IsObject(res)
      Return

   s := (res.Scale>0) ? res.Scale : 1
   out := ""
   If (fmt=2)
   {
      out := res.Text
   } Else
   {
      For i, ln in res.Lines
      {
         If (fmt=1)
         {
            out .= ln.Text "`n"
         } Else If (fmt=3)
         {
            For j, wd in ln.Words
               out .= wd.Text "`n"
         } Else If (fmt=4)
         {
            For j, wd in ln.Words
               out .= wd.Text "`t" WinOCR_FormatBox(wd.X, wd.Y, wd.W, wd.H, s) "`n"
         } Else If (fmt=5)
         {
            x1 := y1 := 0x7FFFFFFF, x2 := y2 := -0x7FFFFFFF
            For j, wd in ln.Words
            {
               x1 := Min(x1, wd.X), y1 := Min(y1, wd.Y)
               x2 := Max(x2, wd.X + wd.W), y2 := Max(y2, wd.Y + wd.H)
            }

            out .= ln.Text
            If (x2>=x1)
               out .= "`t" WinOCR_FormatBox(x1, y1, x2 - x1, y2 - y1, s)
            out .= "`n"
         }
      }
   }

   out := RTrim(out, "`n")
   If joinCJK
   {
      ; Windows OCR puts a space between every two CJK characters
      c := "\x{3000}-\x{303F}\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{F900}-\x{FAFF}\x{FF00}-\x{FFEF}"
      out := RegExReplace(out, "(?<=[" c "]) +(?=[" c "])")
   }
   Return out
}

WinOCR_FormatBox(x, y, w, h, s) {
   Return "[x=" Round(x/s) ", y=" Round(y/s) ", w=" Round(w/s) ", h=" Round(h/s) "]"
}

WinOCR_CountWords(res) {
   n := 0
   For i, ln in res.Lines
      n += ln.Words.Length()
   Return n
}

WinOCR_CountChars(res) {
   Return StrLen(RegExReplace(res.Text, "\s"))
}

WinOCR_MedianWordHeight(res) {
   hs := ""
   For i, ln in res.Lines
   {
      For j, wd in ln.Words
         hs .= wd.H "`n"
   }

   hs := RTrim(hs, "`n")
   If (hs="")
      Return 0

   Sort, hs, N
   arr := StrSplit(hs, "`n")
   Return arr[Ceil(arr.Length()/2)]
}

WinOCR_Await(op, timeOut:=120000) {
; waits for an IAsyncOperation, releases it and returns its result
   info := ComObjQuery(op, "{00000036-0000-0000-C000-000000000046}")  ; IAsyncInfo
   If !info
   {
      ObjRelease(op)
      Throw Exception("The object is not an asynchronous operation.")
   }

   startZeit := A_TickCount, status := 0
   Loop
   {
      DllCall(WinOCR_VTable(info, 7), "Ptr", info, "UInt*", status)  ; IAsyncInfo.get_Status
      If (status!=0)  ; AsyncStatus.Started
         Break

      If (A_TickCount - startZeit>timeOut)
      {
         DllCall(WinOCR_VTable(info, 9), "Ptr", info)  ; IAsyncInfo.Cancel
         ObjRelease(info), ObjRelease(op)
         Throw Exception("The text recognition timed out.")
      }
      Sleep, 10
   }

   If (status!=1)  ; AsyncStatus.Completed
   {
      err := 0
      DllCall(WinOCR_VTable(info, 8), "Ptr", info, "UInt*", err)  ; IAsyncInfo.get_ErrorCode
      ObjRelease(info), ObjRelease(op)
      If (status=2)  ; AsyncStatus.Canceled
         Throw Exception("The asynchronous operation was canceled.")
      Throw Exception("The asynchronous operation failed (HRESULT 0x" Format("{:08X}", err) ").")
   }

   ObjRelease(info)
   result := 0
   hr := DllCall(WinOCR_VTable(op, 8), "Ptr", op, "Ptr*", result, "UInt")  ; IAsyncOperation.GetResults
   ObjRelease(op)
   WinOCR_CheckHR(hr, "IAsyncOperation.GetResults")
   Return result
}

WinOCR_GetFactory(className, iid) {
   factory := 0
   hs := WinOCR_CreateHString(className)
   VarSetCapacity(guid, 16, 0)
   DllCall("ole32\CLSIDFromString", "WStr", iid, "Ptr", &guid)
   hr := DllCall("combase\RoGetActivationFactory", "Ptr", hs, "Ptr", &guid, "Ptr*", factory, "UInt")
   WinOCR_DeleteHString(hs)
   WinOCR_CheckHR(hr, "RoGetActivationFactory(" className ")")
   Return factory
}

WinOCR_CloseRelease(p) {
   If !p
      Return

   closable := ComObjQuery(p, "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}")  ; IClosable
   If closable
   {
      DllCall(WinOCR_VTable(closable, 6), "Ptr", closable)  ; IClosable.Close
      ObjRelease(closable)
   }
   ObjRelease(p)
}

WinOCR_LanguageTag(lang) {
   hs := 0
   DllCall(WinOCR_VTable(lang, 6), "Ptr", lang, "Ptr*", hs)  ; ILanguage.get_LanguageTag
   Return WinOCR_GetHString(hs)
}

WinOCR_LanguageName(lang) {
   hs := 0
   DllCall(WinOCR_VTable(lang, 7), "Ptr", lang, "Ptr*", hs)  ; ILanguage.get_DisplayName
   Return WinOCR_GetHString(hs)
}

WinOCR_CreateHString(str) {
   hs := 0
   DllCall("combase\WindowsCreateString", "WStr", str, "UInt", StrLen(str), "Ptr*", hs)
   Return hs
}

WinOCR_DeleteHString(hs) {
   If hs
      DllCall("combase\WindowsDeleteString", "Ptr", hs)
}

WinOCR_GetHString(hs, free:=1) {
   If !hs
      Return ""

   len := 0
   p := DllCall("combase\WindowsGetStringRawBuffer", "Ptr", hs, "UInt*", len, "Ptr")
   str := (p && len>0) ? StrGet(p, len, "UTF-16") : ""
   If free
      WinOCR_DeleteHString(hs)
   Return str
}

WinOCR_VTable(p, i) {
   Return NumGet(NumGet(p + 0, "Ptr") + i*A_PtrSize, "Ptr")
}

WinOCR_CheckHR(hr, what) {
   If (hr & 0x80000000)
      Throw Exception(what " failed (HRESULT 0x" Format("{:08X}", hr & 0xFFFFFFFF) ").")
}
