; ================================================================================
; Inspired by TheArkive [many thanks !!!!]
; Developed by Marius Șucan [ http://marius.sucan.ro/ ]
; Replaces MsgBox function and allows using MsgBox2() inline as a function
;
; Features:
; - message box standard icons [optional]
    ; - with windows standard sound beeps
; - usable with the keyboard or mouse
; - drop-down option
; - checkbox option
; - edit field option
; - window centers on the screen where the owner or modal hwnd is, if none given, where the mouse is
;
; It returns an array object
  ; array.btn - button clicked
  ; array.check - checkbox state
  ; array.list - drop-down selected row; if DropListMode=1, it will return the text of the edit/selection
  ; array.edit - edit field text
;
; ================================================================================================
; Thanks to [just me] for creating TaskDialog that gave me ideas and inspiration.
; https://github.com/AHK-just-me/TaskDialog/blob/master/Sources/TaskDialog.ahk
; ================================================================================
; Current version: jeudi 18 juin 2020
;
; Usage example:
; msgResultArray := MsgBox2("Please confirm you want to delete this file", "confirmation box", "&Delete|&Cancel", 2, "question", "Arial", 0, 12, ,, "Do not prompt again before file delete", 1)
;
; Parameters/arguments:
   ; - sMsg            - message / prompt to display
   ; - title           - window title
   ; - btnList         - buttons list, it can be a number from -1 to 6, as in AHK v1.1; -1 means no button
   ;                   - or a string with button names: "btn1|btn2|btn3"
   ; - btnDefault      - the number of the default button
   ; - icon            - it can be a HBITMAP or HICON handle
   ;                   - english icon names accepted: question, error, info and many others...
   ; - fontFace        - font name to use for the dialog
   ; - doBold          - set the bold style the font [boolean]
   ; - fontSize
   ; - modalHwnd       - the window handle to disable and prevent it from receving clicks
   ; - ownerHwnd       - the window handle of the window to which the message box should belong to
   ; - checkBoxCaption - the checkbox text to display; if none providne, no checkbox
   ; - checkBoxState   - the default checkbox state [boolean]
   ; - dropListu       - drop-down list rows separated by "f" [eg., "option1`foption2`foption3"]; if no string provided, no drop-down list; to set a given entry as default use double "`f"
   ; - editOptions     - common ahk v1.1 edit parameters/options [eg., "limit10 number"]; if provided, an edit field will be added
   ; - editDefaultLine - the default string in the text field
   ; - DropListMode    - 0 = to use a drop-down; the row selected number is returned in Array.list
   ;                   - 1 = to use a ComboBox/ComboList that allows typing in; the result is the typed/selected string returned in Array.list
   ;                   - 2 = to use a ListBox to display the options as a list; the row selected number is returned in Array.list
   ;                   - 3 = to use a ListBox to display the options as a list that allows multiple options to be selected; the rows selected numbers are returned in Array.list , each separated by `f
   ;                   - in any case dropListu parameter must be given;
   ; - setWidth        - sets the desired width for the prompt message, checkbox edit field
   ; - 2ndDropListu
   ; - 2ndDropListMode

Global MsgBox2InputHook, MsgBox2Result, MsgBox2hwnd

MsgBox2(sMsg, title, btnList:=0, btnDefault:=1, icon:="", fontFace:="", doBold:=0, fontSize:=0, modalHwnd:="", ownerHwnd:="", checkBoxCaption:="", checkBoxState:=0, dropListu:="", editOptions:="", editDefaultLine:="", DropListMode:=0, setWidth:=0, 2ndDropListu:=0, 2ndDropListMode:=0) {
  Global UsrCheckBoxu, 2ndDropListuChoice, DropListuChoice, EditUserMsg, prompt, BoxIcon
  oCritic := A_IsCritical 
  thisHwnd := ownerHwnd ? ownerHwnd : modalHwnd
  If !thisHwnd
     thisHwnd := "mouse"

  ActiveMon := calcScreenLimits(thisHwnd)
  rMaxW := Floor(ActiveMon.w*0.95)
  rMaxH := Floor(ActiveMon.h*0.95)

  MsgBox2hwnd := 0
  MsgBox2Result := ""
  If (btnList=-1)
     btnList := ""
  Else If (btnList=0)
     btnList := "&OK"
  Else If (btnList=1)
     btnList := "&OK|&Cancel"
  Else If (btnList=2)
     btnList := "&Abort|&Retry|&Ignore"
  Else If (btnList=3)
     btnList := "&Yes|&No|&Cancel"
  Else If (btnList=4)
     btnList := "&Yes|&No"
  Else If (btnList=5)
     btnList := "&Retry|&Cancel"
  Else If (btnList=6)
     btnList := "&Cancel|&Try Again|C&ontinue"

  thisFontSize := !fontSize ? 8 : fontSize
  btnDim := GetMsgDimensions("Again?!", fontFace, fontSize, rMaxW, rMaxH, 1, doBold)
  bH := btnDim.h
  bH += Round(bH*0.8)
  If !bH
     bH:= Round(thisFontSize*2.5)

  minBW := Round(bH*2.5)
  btnCount := btnTotalWidth := 0
  btnDimensions := []
  If InStr(btnList, "|")
  {
     Loop, Parse, btnList, |
     {
        If !A_LoopField
           Continue
 
        btnText := Trim(A_LoopField)
        newBtnList .= btnText "|"
        If (A_Index=btnDefault)
           textbtnDefault := btnText
        btnCount++
        btnDimensions[btnCount] := GetMsgDimensions(btnText, fontFace, fontSize, rMaxW, rMaxH, 1, doBold)
        btnTotalWidth += btnDimensions[btnCount].w + bH
     }
     btnList := Trim(newBtnList, "|")
  }

  If !btnTotalWidth
     btnTotalWidth := btnDim.w + bH

  listWidth := 1
  listRows := 0
  If dropListu
  {
     Loop, Parse, dropListu, `f
     {
        If A_LoopField
        {
           listRows++
           listDim := GetMsgDimensions(A_LoopField, fontFace, fontSize, rMaxW, rMaxH, 1, doBold)
           listWidth := max(listDim.w, listWidth, btnDim.w)
        }
     }
     listWidth += bH
  }
  If (listRows=0 && DropListMode!=1)
     dropListu := ""
  Else If (listRows=0 && DropListMode=1)
     listRows := 10
  Else If (listRows>10)
     listRows := 10


  2ndlistWidth := 1
  2ndlistRows := 0
  If 2ndDropListu
  {
     Loop, Parse, 2ndDropListu, `f
     {
        If A_LoopField
        {
           2ndlistRows++
           listDim := GetMsgDimensions(A_LoopField, fontFace, fontSize, rMaxW, rMaxH, 1, doBold)
           2ndlistWidth := max(listDim.w, listWidth, btnDim.w)
        }
     }
     2ndlistWidth += bH
  }
  If (2ndlistRows=0 && 2ndDropListMode!=1)
     2ndDropListu := ""
  Else If (2ndlistRows=0 && 2ndDropListMode=1)
     2ndlistRows := 10
  Else If (2ndlistRows>10)
     2ndlistRows := 10

  btnTotalWidth := max(btnTotalWidth, listWidth, 2ndlistWidth, setWidth)
  If (btnCount=0 && StrLen(btnList)>0)
     btnCount := 1

  btnDefault := !btnDefault ? 1 : btnDefault
  marginsGui := bH//2
  marginz := bH//3

  msg := GetMsgDimensions(sMsg, fontFace, fontSize, rMaxW - bH//2, rMaxH - bH*2, 0, doBold)
  msgW := (icon && btnCount>0) ? msg.w - bH : msg.w
  If (msgW<btnTotalWidth)
     msgW := btnTotalWidth + bH//2

  If (Abs(setWidth)>bH)
     msgW := Abs(setWidth)

  If (DropListMode=1)
     2ndlistWidth := listWidth := msgW
  Else
     2ndlistWidth := listWidth := max(listWidth, 2ndlistWidth, btnTotalWidth)

  msgH := msg.h - bH//2
  msgH := (msgH>rMaxH) ? "h" maxH : ""
  thisBold := (doBold=1) ? " Bold " : ""
  Gui, WinMsgBox: Default
  Gui, WinMsgBox: -MinimizeBox -DPIScale +HwndMsgBox2hwnd
  Gui, WinMsgBox: Margin, %marginsGui%, %marginsGui%

  If (uiUseDarkMode=1)
  {
     Gui, Color, % darkWindowColor, % darkWindowColor
     Gui, Font, c%darkControlColor%
     setDarkWinAttribs(MsgBox2hwnd)
  }

  If fontFace
     Gui, Font, %thisBold% Q4, %fontFace% 

  If (fontSize>0)
     Gui, Font, s%fontSize% %thisBold% Q4

  iconFile := 0
  If (icon)
  {
     If (icon="error" || icon="stop")
     {
       iconFile := "imageres.dll", iconNum := 94
       SoundPlay, *16
     } Else If (icon="question")
     {
       iconFile := "imageres.dll", iconNum := 95
       SoundPlay, *32
     } Else If (icon="warning" || icon="alert" || icon="exclamation")
     {
       iconFile := "imageres.dll", iconNum := 80
       SoundPlay, *48
     } Else If (icon="hand" || icon="forbidden")
     {
       iconFile := "imageres.dll", iconNum := 208
       SoundPlay, *48
     } Else If (icon="info")
     {
       iconFile := "imageres.dll", iconNum := 77
       SoundPlay, *64
     } Else If (icon="info2")
     {
       iconFile := "explorer.exe", iconNum := 6
       SoundPlay, *64
     } Else If (icon="search")
     {
       iconFile := "imageres.dll", iconNum := 169
     } Else If (icon="checkbox")
     {
       iconFile := "imagres.dll", iconNum := 233
     } Else If (icon="cloud")
     {
       iconFile := "imagres.dll", iconNum := 232
     } Else If (icon="recycle" || icon="refresh")
     {
       iconFile := "imageres.dll", iconNum := 229
     } Else If (icon="trash")
     {
       iconFile := "imageres.dll", iconNum := 51
       SoundPlay, *32
     } Else If (icon="file")
     {
       iconFile := "imageres.dll", iconNum := 15
     } Else If (icon="audio-file" || icon="audio")
     {
       iconFile := "imageres.dll", iconNum := 126
     } Else If (icon="image-file" || icon="image")
     {
       iconFile := "imageres.dll", iconNum := 68
     } Else If (icon="folder")
     {
       iconFile := "imageres.dll", iconNum := 4
     } Else If (icon="modify-file")
     {
       iconFile := "imageres.dll", iconNum := 247
     } Else If (icon="modify-entry")
     {
       iconFile := "imageres.dll", iconNum := 90
     } Else If (icon="settings" || icon="gear")
     {
       iconFile := "shell32.dll", iconNum := 317
     } Else If (icon="cut" || icon="scissor")
     {
       iconFile := "shell32.dll", iconNum := 260
     } Else If (icon="fast-forward")
     {
       iconFile := "shell32.dll", iconNum := 268
     } Else If (icon="disc" || icon="save")
     {
       iconFile := "shell32.dll", iconNum := 259
     } Else If (!InStr(icon,"HBITMAP:") && !InStr(icon,"HICON:"))
     {
       iconArr := StrSplit(icon,"/")
       iconFile := iconArr[1]
       iconNum := iconArr[2]
       iconArr := ""
     } Else
     {
       iconFile := icon
       iconHandle := true
     }
   }

   If (iconFile)
   {
      If (iconHandle)
         Try Gui, Add, Picture, AltSubmit x%marginsGui% y%marginsGui% h%bH% w-1 vBoxIcon, %iconFile%
      Else If (iconNum)
         Try Gui, Add, Picture, AltSubmit x%marginsGui% y%marginsGui% h%bH% vBoxIcon Icon%iconNum% w-1, %iconFile%
      Else
         Try Gui, Add, Picture, AltSubmit x%marginsGui% y%marginsGui% h%bH% vBoxIcon w-1  %iconFile%
      Catch wasError
         Sleep, 1
      If wasError
         iconFile := ""
  }

  yPos := iconFile ? "" : "y+" marginsGui
  xPos := iconFile ? "x+" marginsGui : "x" marginsGui
  If (btnCount>0)
     ; Gui, Add, Text, %xPos% %yPos% w%msgW% %msgH% vprompt, %sMsg%
     Gui, Add, Edit, %xPos% %yPos% w%msgW% %msgH% ReadOnly -WantReturn vprompt -Tabstop -E0x200 -HScroll -VScroll, %sMsg%
  Else
     Gui, Add, Text, %xPos% %yPos% w%msgW% %msgH% vprompt gKillMsgbox2Win, %sMsg%

  Gui, Add, Text, xp yp wp hp BackgroundTrans, %A_Space%
  addLabelu := InStr(editOptions, "number") ? "" : " gUIeditsGenericAllowCtrlBksp "
  If editOptions
     Gui, Add, Edit, xp y+%marginz% wp %addLabelu% -WantReturn r1 -multi -HScroll -VScroll %editOptions% vEditUserMsg, %editDefaultLine%

  If checkBoxCaption
     Gui, Add, Checkbox, xp y+%marginz% wp Checked%checkBoxState% vUsrCheckBoxu, %checkBoxCaption%

  multiSel := (DropListMode=3) ? 8 : " gMsgBox2ListBoxEvent "
  If (dropListu || 2ndDropListu)
     Gui, +Delimiter`f

  If (dropListu && (DropListMode=2 || DropListMode=3))
  {
     dropListu := Chr(160) StrReplace(dropListu, "`f", "`f" Chr(160))
     dropListu := StrReplace(dropListu, "`f" Chr(160) "`f", "`f`f")
     dropListu := StrReplace(RTrim(dropListu, Chr(160)), "`f`f`f", "`f`f")
  }

  If (dropListu && DropListMode=0)
     Gui, Add, DropDownList, xp y+%marginz% w%listWidth% AltSubmit vDropListuChoice, % dropListu
  Else If (dropListu && DropListMode=1)
     Gui, Add, ComboBox, xp y+%marginz% w%listWidth% gUIgenericComboAction vDropListuChoice, % dropListu
  Else If (dropListu && (DropListMode=2 || DropListMode=3))
     Gui, Add, ListBox, xp y+%marginz% r%listRows% w%listWidth% AltSubmit %multisel% vDropListuChoice, % dropListu

  If (2ndDropListu && (2ndDropListMode=2 || 2ndDropListMode=3))
  {
     2ndDropListu := Chr(160) StrReplace(2ndDropListu, "`f", "`f" Chr(160))
     2ndDropListu := StrReplace(2ndDropListu, "`f" Chr(160) "`f", "`f`f")
     2ndDropListu := StrReplace(RTrim(2ndDropListu, Chr(160)), "`f`f`f", "`f`f")
  }

  If (2ndDropListu && 2ndDropListMode=0)
     Gui, Add, DropDownList, xp y+%marginz% w%2ndlistWidth% AltSubmit v2ndDropListuChoice, % 2ndDropListu
  Else If (2ndDropListu && 2ndDropListMode=1)
     Gui, Add, ComboBox, xp y+%marginz% w%2ndlistWidth% v2ndDropListuChoice, % 2ndDropListu
  Else If (2ndDropListu && (2ndDropListMode=2 || 2ndDropListMode=3))
     Gui, Add, ListBox, xp y+%marginz% r%2ndlistRows% w%2ndlistWidth% AltSubmit %2ndmultisel% v2ndDropListuChoice, % 2ndDropListu

  hDefBtn := ""
  ledH := (PrefsLargeFonts=1) ? 10 : 6
  Loop, Parse, btnList, | ; list specified buttons
  {
      If !A_LoopField
         Continue

      btnText := A_LoopField
      def := (A_Index=btnDefault) ? " +Default +hwndhDefBtn" : ""
      thisBW := btnDimensions[A_Index].w + bH
      If (thisBW<minBW)
         thisBW := minBW

      thisYpos := (addedLine=1) ? "yp-" bH - 0 : ""
      If (A_Index=1)
         Gui, Add, Button, gMsgBox2event xp y+%marginz% w%thisBW% h%bH% %def% -wrap, %btnText%
      Else
         Gui, Add, Button, gMsgBox2event x+5 %thisYpos% w%thisBW% h%bH% %def% -wrap, %btnText%

      addedLine := 0
      If RegExMatch(StrReplace(btnText, "&"), "i)(discard|remove|delete|erase|wipe)")
      {
         Gui, Add, Progress, xp+0 y+0 wp h%ledH% -border BackgroundFF5522 cFF5500 -TabStop +disabled, 100
         addedLine := 1
      } Else If InStr(def, "+def")
      {
         Gui, Add, Progress, xp+0 y+0 wp h%ledH% -border Background2288FF c2288FF -TabStop +disabled, 100
         addedLine := 1
      }
  }

  If !btnCount
     Gui, Add, Button, gMsgBox2event x+0 w1 h1 Default, --

  Gui, Add, Text, xp yp w1 h1 BackgroundTrans,% A_Space
  If StrLen(ownerHwnd)>1
     Try Gui, +Owner%ownerHwnd%

  If modalHwnd
     WinSet, Disable,, ahk_id %modalHwnd%

  repositionWindowCenter("WinMsgBox", MsgBox2hwnd, thisHwnd, title)
  If editOptions
     GuiControl, WinMsgBox: Focus, EditUserMsg
  Else If (checkBoxCaption && DropListMode!=1)
     GuiControl, WinMsgBox: Focus, UsrCheckBoxu
  Else If dropListu
     GuiControl, WinMsgBox: Focus, DropListuChoice
  Else
     GuiControl, WinMsgBox: Focus, Button%btnDefault%

  If !btnCount
     SetTimer, CloseMsgBox2Win, 300

  Critical, off
  SetTimer, WatchMsgBox2Win, 300

  Gui, WinMsgBox: Default
  MsgBox2InputHook := InputHook("V") ; "V" for not blocking input
  MsgBox2InputHook.KeyOpt("{BackSpace}{Delete}{PgUp}{PgDn}{Enter}{Escape}{F4}{NumpadEnter}","N")
  MsgBox2InputHook.OnKeyDown := Func("MsgBox2InputHookKeyDown")
  MsgBox2InputHook.Start()
  MsgBox2InputHook.Wait()
  r := []
  Sleep, 1
  Gui, WinMsgBox: Default
  GuiControlGet, UsrCheckBoxu
  GuiControlGet, DropListuChoice
  GuiControlGet, 2ndDropListuChoice
  GuiControlGet, EditUserMsg
  r.btn := StrReplace(MsgBox2Result, "&")
  If (MsgBox2Result="usr-dbl-clk")
     r.btn := StrReplace(textbtnDefault, "&")

  r.check := !checkBoxCaption ? 0 : UsrCheckboxu
  r.list := !dropListu ? 0 : DropListuChoice
  r.2ndlist := !2ndDropListu ? 0 : 2ndDropListuChoice
  r.edit := !editOptions ? 0 : EditUserMsg
  If modalHwnd
     WinSet, Enable,, ahk_id %modalHwnd%

  Gui, WinMsgBox: Destroy
  Sleep, 1
  If (thisHwnd && thisHwnd!="mouse")
     WinActivate, ahk_id %thisHwnd%

  SetTimer, CloseMsgBox2Win, Delete
  SetTimer, WatchMsgBox2Win, Delete
  MsgBox2hwnd := 0
  Critical, % oCritic 
  return r
}

KillMsgbox2Win() {
     MsgBox2Result := "win_closed"
     MsgBox2InputHook.Stop()
}

CloseMsgBox2Win() {
  hwnd := WinActive("A")
  If (hwnd!=MsgBox2hwnd)
  {
     MsgBox2Result := "win_closed"
     MsgBox2InputHook.Stop()
     SetTimer, , Off
  }
}

WatchMsgBox2Win() {
  hwnd := WinExist("ahk_id" MsgBox2hwnd)
  r := DllCall("IsWindowVisible", "UInt", MsgBox2hwnd)
  If (hwnd!=MsgBox2hwnd || !r)
  {
     Sleep, 0
     MsgBox2Result := "win_closed"
     MsgBox2InputHook.Stop()
     SetTimer, , Off
  }
}

MsgBox2event(CtrlHwnd, GuiEvent, EventInfo) {
  Gui, WinMsgBox: Default
  GuiControlGet, btnFocused, WinMsgBox: FocusV
  ControlGetText, btnText, , ahk_id %CtrlHwnd%
  If btnFocused
  {
     Sleep, 50
     MsgBox2Result := btnText
     MsgBox2InputHook.Stop()
  }
}

MsgBox2ListBoxEvent(CtrlHwnd, GuiEvent, EventInfo) {
  If (GuiEvent="DoubleClick")
  {
     Sleep, 50
     MsgBox2Result := "usr-dbl-clk"
     MsgBox2InputHook.Stop()
  }
}

MsgBox2InputHookKeyDown(iHook, VK, SC) {
  hwnd := WinActive("A")
  If (hwnd!=MsgBox2hwnd)
     Return

  Gui, WinMsgBox: Default
  GuiControlGet, btnText, WinMsgBox: FocusV
  ctrlState := GetKeyState("Ctrl", "P")
  keyPressed := GetKeyName(Format("vk{:x}sc{:x}", VK, SC))
  If (keyPressed="Escape") || (ctrlState && keyPressed="f4")
  {
     MsgBox2Result := "win_close_" keyPressed
     MsgBox2InputHook.Stop()
  } Else If (btnText="prompt")
     GuiControl, WinMsgBox: Focus, Button1
}

GetMsgDimensions(sString, FaceName, FontSize, maxW, maxH, btnMode:=0, bBold:=0) {
    mustWrap := (btnMode=1) ? 0 : 1
    dims := GetStringSize(FaceName, FontSize, bBold, sString, mustWrap, maxW + 100)
    ctlSizeW := dims.w
    ctlSizeH := dims.h

    thisFontSize := !fontSize ? 8 : fontSize
    r := []
    r.l := ctlSizeH ; line height
    modifiedW := 0
    If (ctlSizeW>maxW*0.6)
    {
       modifiedW := 1
       r.w := ctlSizeW//1.7
    } Else r.w := ctlSizeW

    If (btnMode!=1)
    {
       Loop, Parse, sString, `n,`r
            maxLineLength := max(maxLineLength, StrLen(A_LoopField))
    } Else maxLineLength := StrLen(sString)

    If (r.w>maxW)
    {
       modifiedW := 1
       r.w := Round(maxW*0.8)
    }

    minChars := thisFontSize*42
    newPossibleW := r.w//2
    If ((r.w>ctlSizeH*3.1) && maxLineLength>118 && newPossibleW>=minChars)
    {
       modifiedW := 1
       r.w := r.w//2
    }

    If (r.w>maxW)
    {
       modifiedW := 1
       r.w := Round(maxW*0.8)
    }

    r.h := ctlSizeH
    If (btnMode=1)
       r.w := ctlSizeW
    Else If (ctlSizeH>maxH*0.9 && modifiedW=1)
       r.w := maxW

    If (btnMode!=1)
       dimz := GetStringSize(FaceName, FntSize, bBold, sString, mustWrap, r.w)

    scaledH := Round((ctlSizeW / r.w) * ctlSizeH)
    If (scaledH>maxH*0.9) || (dimz.h>maxH*0.9)
    {
       r.w := Round(maxW * 0.95)
       r.h := Round(maxH * 0.9)
    }
    ; If !btnMode
    ;    MsgBox, % r.w " | " r.h "`n" scaledH "`n" maxW " | " maxH "`n" ctlSizeW " | " ctlSizeH
    Return r
}

GetGuiDefaultFont() {
   ; by SKAN (modified by just me)
   ; https://www.autohotkey.com/boards/viewtopic.php?t=6750
   ; By SKAN https://autohotkey.com/board/topic/7984-ahk-functions-incache-cache-list-of-recent-items/page-10#entry443622
   VarSetCapacity(LF, szLF := 28 + (A_IsUnicode ? 64 : 32), 0) ; LOGFONT structure
   If DllCall("GetObject", "Ptr", DllCall("GetStockObject", "Int", 17, "Ptr"), "Int", szLF, "Ptr", &LF)
      Return {Name: StrGet(&LF + 28, 32), Size: Round(Abs(NumGet(LF, 0, "Int")) * (72 / A_ScreenDPI), 1)
            , Weight: NumGet(LF, 16, "Int"), Quality: NumGet(LF, 26, "UChar")}
   Return False
}

GetStringSize(FontFace, fontSize, doBold, p_String, mustWrap, l_Width:=0) {
; ======================================================================
; function based on a function from Fnt_Library v3 posted by jballi
; https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4379
; modified by Marius Șucan
; ======================================================================

    Static DEFAULT_GUI_FONT:=17
          ,HWND_DESKTOP    :=0
          ,OBJ_FONT        :=6
          ,defObjDetected  :=0
          ,defFontFace, defFontSize

    r_Width := r_Height := 0
    thisBold := (doBold=1) ? " bold " : ""
    If (defObjDetected=0)
    {
       defObjDetected := 1
       obju := GetGuiDefaultFont()
       defFontFace := Trim(obju.name), defFontSize := Round(obju.size)
       ; msgbox, % defFontFace "=" defFontSize "`n" fontFace "=" fontSize
    }

    fontFace := !fontFace ? defFontFace : fontFace
    fontSize := !fontSize ? defFontSize : FontSize
    If (fontSize<9 || !Trim(fontSize))
       fontSize := 8
    If !Trim(fontFace)
       fontFace := "Tahoma"

    hFont := Fnt_CreateFont(fontFace, "s" fontSize thisBold)
    If (DllCall("GetObjectType","Ptr",hFont)!=OBJ_FONT)
       hFont := DllCall("GetStockObject","Int",DEFAULT_GUI_FONT)

    Fnt_GetSizeForEdit(hFont, p_String, l_Width, r_Width, r_Height, mustWrap)
    Fnt_DeleteFont(hFont)
    ; If (r_Height>15*fontSize && mustWrap!=1)
    ;    r_Height := fontSize * 3

    result := []
    result.w := (mustWrap=1) ? r_Width + Round(fontSize*1.5) : r_Width
    result.h := r_Height ? r_Height : fontSize * 2
    Return result
}

calcScreenLimits(whichHwnd:="main") {
    Static lastInvoked := 1, prevHwnd, prevActiveMon := []

    ; the function calculates screen boundaries for the user given X/Y position for the OSD
    If (A_TickCount - lastInvoked<350) && (prevHwnd=whichHwnd)
       Return prevActiveMon

    whichHwnd := (whichHwnd="main") ? PVhwnd : whichHwnd
    If (whichHwnd="mouse")
    {
       GetPhysicalCursorPos(mainX, mainY)
       hMon := MDMF_FromPoint(mainX, mainY, 2)
    } Else
    {
       hMon := MDMF_FromHWND(whichHwnd, 2)
       WinGetPos, mainX, mainY,, , ahk_id %whichHwnd%
    }

    If hMon
       MonitorInfos := MDMF_GetInfo(hMon)

    If !IsObject(MonitorInfos)
    {
       ActiveMon := MWAGetMonitorMouseIsIn(mainX, mainY)
       If !ActiveMon
       {
          ActiveMon := MWAGetMonitorMouseIsIn()
          If !ActiveMon
             Return prevActiveMon
       }
       SysGet, mCoord, MonitorWorkArea, %ActiveMon%
       prevActiveMon.mCRight := mCoordRight, prevActiveMon.mCLeft := mCoordLeft
       prevActiveMon.mCTop := mCoordTop, prevActiveMon.mCBottom := mCoordBottom
    } Else
    {
       ActiveMon := MonitorInfos.Num
       mCoordRight := MonitorInfos.WARight, mCoordLeft := MonitorInfos.WALeft
       mCoordTop := MonitorInfos.WATop, mCoordBottom := MonitorInfos.WABottom
       prevActiveMon.mCRight := MonitorInfos.WARight, prevActiveMon.mCLeft := MonitorInfos.WALeft
       prevActiveMon.mCTop := MonitorInfos.WATop, prevActiveMon.mCBottom := MonitorInfos.WABottom
    }

    prevActiveMon.w := ResolutionWidth := Abs(max(mCoordRight, mCoordLeft) - min(mCoordRight, mCoordLeft))
    prevActiveMon.h := ResolutionHeight := Abs(max(mCoordTop, mCoordBottom) - min(mCoordTop, mCoordBottom)) 
    If !ResolutionWidth
       prevActiveMon.w := ResolutionWidth := 800
    If !ResolutionHeight
       prevActiveMon.h := ResolutionHeight := 600

    prevActiveMon.m := ActiveMon
    prevActiveMon.hMon := hMon
    lastInvoked := A_TickCount
    prevHwnd := whichHwnd
    ; ToolTip, % ActiveMon "`n" pActiveMon "`n" hMon , , , 2
    Return prevActiveMon
}

