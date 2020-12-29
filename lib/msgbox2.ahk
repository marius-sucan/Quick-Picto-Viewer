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
  Critical, off

  thisHwnd := ownerHwnd ? ownerHwnd : modalHwnd
  If !thisHwnd
     thisHwnd := "mouse"

  ActiveMon := calcScreenLimits(thisHwnd)
  rMaxW := Floor(ActiveMon.w*0.95)
  rMaxH := Floor(ActiveMon.h*0.95)

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
  If editOptions
     Gui, Add, Edit, xp y+%marginz% wp -WantReturn r1 -multi -HScroll -VScroll %editOptions% vEditUserMsg, %editDefaultLine%

  If checkBoxCaption
     Gui, Add, Checkbox, xp y+%marginz% wp Checked%checkBoxState% vUsrCheckBoxu, %checkBoxCaption%

  multiSel := (DropListMode=3) ? 8 : " gMsgBox2ListBoxEvent "
  If (dropListu || 2ndDropListu)
     Gui, +Delimiter`f

  If (dropListu && (DropListMode=2 || DropListMode=3))
  {
     dropListu := Chr(160) StrReplace(dropListu, "`f", "`f" Chr(160))
     dropListu := StrReplace(dropListu, "`f" Chr(160) "`f", "`f`f")
  }

  If (dropListu && DropListMode=0)
     Gui, Add, DropDownList, xp y+%marginz% w%listWidth% AltSubmit vDropListuChoice, % dropListu
  Else If (dropListu && DropListMode=1)
     Gui, Add, ComboBox, xp y+%marginz% w%listWidth% vDropListuChoice, % dropListu
  Else If (dropListu && (DropListMode=2 || DropListMode=3))
     Gui, Add, ListBox, xp y+%marginz% r%listRows% w%listWidth% AltSubmit %multisel% vDropListuChoice, % dropListu

  If (2ndDropListu && (2ndDropListMode=2 || 2ndDropListMode=3))
  {
     2ndDropListu := Chr(160) StrReplace(2ndDropListu, "`f", "`f" Chr(160))
     2ndDropListu := StrReplace(2ndDropListu, "`f" Chr(160) "`f", "`f`f")
  }

  If (2ndDropListu && 2ndDropListMode=0)
     Gui, Add, DropDownList, xp y+%marginz% w%2ndlistWidth% AltSubmit v2ndDropListuChoice, % 2ndDropListu
  Else If (2ndDropListu && 2ndDropListMode=1)
     Gui, Add, ComboBox, xp y+%marginz% w%2ndlistWidth% v2ndDropListuChoice, % 2ndDropListu
  Else If (2ndDropListu && (2ndDropListMode=2 || 2ndDropListMode=3))
     Gui, Add, ListBox, xp y+%marginz% r%2ndlistRows% w%2ndlistWidth% AltSubmit %2ndmultisel% v2ndDropListuChoice, % 2ndDropListu

  Loop, Parse, btnList, | ; list specified buttons
  {
      If !A_LoopField
         Continue

      btnText := A_LoopField
      def := (A_Index=btnDefault) ? " +Default" : ""
      thisBW := btnDimensions[A_Index].w + bH
      If (thisBW<minBW)
         thisBW := minBW

      If (A_Index=1)
         Gui, Add, Button, gMsgBox2event xp y+%marginz% w%thisBW% h%bH% %def% -wrap, %btnText%
      Else
         Gui, Add, Button, gMsgBox2event x+5 w%thisBW% hp %def% -wrap, %btnText%
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

  SetTimer, WatchMsgBox2Win, 300
  MsgBox2InputHook := InputHook("V") ; "V" for not blocking input
  MsgBox2InputHook.KeyOpt("{BackSpace}{Delete}{PgUp}{PgDn}{Enter}{Escape}{F4}{NumpadEnter}","N")
  MsgBox2InputHook.OnKeyDown := Func("MsgBox2InputHookKeyDown")
  MsgBox2InputHook.Start()
  MsgBox2InputHook.Wait()
  r := []
  Sleep, 1
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

  GuiControlGet, btnText, WinMsgBox: FocusV
  keyPressed := GetKeyName(Format("vk{:x}sc{:x}", VK, SC))
  If (keyPressed="Escape" || keyPressed="f4")
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

GuiDefaultFont() {
   ; by SKAN (modified by just me)
   ; https://www.autohotkey.com/boards/viewtopic.php?t=6750
   ; By SKAN https://autohotkey.com/board/topic/7984-ahk-functions-incache-cache-list-of-recent-items/page-10#entry443622
   VarSetCapacity(LF, szLF := 28 + (A_IsUnicode ? 64 : 32), 0) ; LOGFONT structure
   If DllCall("GetObject", "Ptr", DllCall("GetStockObject", "Int", 17, "Ptr"), "Int", szLF, "Ptr", &LF)
      Return {Name: StrGet(&LF + 28, 32), Size: Round(Abs(NumGet(LF, 0, "Int")) * (72 / A_ScreenDPI), 1)
            , Weight: NumGet(LF, 16, "Int"), Quality: NumGet(LF, 26, "UChar")}
   Return False
}

Fnt_GetSizeForEdit(hFont,p_Text,p_MaxW:=0,mustWrap:=1,ByRef r_Width:="",ByRef r_Height:="") {
    Static Dummy13373556
          ,DEFAULT_GUI_FONT:=17
          ,HWND_DESKTOP    :=0
          ,MAXINT          :=0x7FFFFFFF
          ,OBJ_FONT        :=6
          ,SIZE

          ;-- DrawText formats
          ,DT_WORDBREAK:=0x10
                ;-- Breaks words.  Lines are automatically broken between words
                ;   if a word extends past the edge of the rectangle specified
                ;   by the lprc parameter.  A carriage return line feed sequence
                ;   also breaks the line.

          ,DT_EXPANDTABS:=0x40
                ;-- Expands tab characters. The default number of characters per
                ;   tab is eight.

          ,DT_NOCLIP:=0x100
                ;-- Draws without clipping.  DrawText is somewhat faster when
                ;   DT_NOCLIP is used.

          ,DT_CALCRECT:=0x400
                ;-- Determines the width and height of the rectangle.  The text
                ;   is not drawn.

          ,DT_NOPREFIX:=0x800
                ;-- Turns off processing of prefix characters.

          ,DT_EDITCONTROL:=0x2000
                ;-- Duplicates the text-displaying characteristics of a
                ;   multiline edit control.  Specifically, the average character
                ;   width is calculated in the same manner as for an Edit
                ;   control, and the function does not display a partially
                ;   visible last line.

          ,s_DTFormat:=DT_EXPANDTABS|DT_CALCRECT|DT_NOPREFIX|DT_EDITCONTROL|DT_NOCLIP

    If (mustWrap=1)
       s_DTFormat |= DT_WORDBREAK

    ;-- Initialize
    VarSetCapacity(SIZE,8,0)
    r_Width := r_Height := 0
    l_Width := MAXINT
    if p_MaxW is Integer
        if (p_MaxW>0)
            l_Width:=p_MaxW

    ;-- Bounce if p_Text is null.  All output and return values are zero.
    if not StrLen(p_Text)
        Return &SIZE

    ;-- If needed, get the handle to the default GUI font
    if (DllCall("GetObjectType","Ptr",hFont)<>OBJ_FONT)
        hFont:=DllCall("GetStockObject","Int",DEFAULT_GUI_FONT)

    ;-- Create and populate the RECT structure
    VarSetCapacity(RECT,16,0)
    NumPut(l_Width,RECT,8,"Int")                       ;-- right

    ;-- Select the font into the device context for the desktop
    hDC      :=DllCall("GetDC","Ptr",HWND_DESKTOP)
    old_hFont:=DllCall("SelectObject","Ptr",hDC,"Ptr",hFont)

    ;-- DrawText
    DllCall("DrawText"
        ,"Ptr",hDC                                      ;-- hdc [in]
        ,"Str",p_Text                                   ;-- lpchText [in, out]
        ,"Int",-1                                       ;-- cchText [in]
        ,"Ptr",&RECT                                    ;-- lprc [in, out]
        ,"UInt",s_DTFormat)                             ;-- uFormat [in]

    ;-- Release the objects needed by the DrawText function
    DllCall("SelectObject","Ptr",hDC,"Ptr",old_hFont)
        ;-- Necessary to avoid memory leak

    DllCall("ReleaseDC","Ptr",HWND_DESKTOP,"Ptr",hDC)

    ;-- Update output variables and populate SIZE structure
    NumPut(r_Width:=NumGet(RECT,8,"Int"),SIZE,0,"Int")
        ;-- right, cx

    NumPut(r_Height:=NumGet(RECT,12,"Int"),SIZE,4,"Int")
        ;-- bottom, cy

    Return &SIZE
}


GetStringSize(FontFace, fontSize, doBold, p_String, mustWrap, l_Width:=0) {
; ======================================================================
; functions from Fnt_Library v3 posted by jballi
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
       obju := GuiDefaultFont()
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

    Fnt_GetSizeForEdit(hFont, p_String, mustWrap, l_Width, r_Width, r_Height)
    Fnt_DeleteFont(hFont)
    ; If (r_Height>15*fontSize && mustWrap!=1)
    ;    r_Height := fontSize * 3

    result := []
    result.w := (mustWrap=1) ? r_Width + Round(fontSize*1.5) : r_Width
    result.h := r_Height ? r_Height : fontSize * 2
    Return result
}

Fnt_GetFontName(hFont:="") {
    Static Dummy87890484
          ,DEFAULT_GUI_FONT    :=17
          ,HWND_DESKTOP        :=0
          ,OBJ_FONT            :=6
          ,MAX_FONT_NAME_LENGTH:=32     ;-- In TCHARS

    ;-- If needed, get the handle to the default GUI font
    if (DllCall("GetObjectType","Ptr",hFont)<>OBJ_FONT)
        hFont:=DllCall("GetStockObject","Int",DEFAULT_GUI_FONT)

    ;-- Select the font into the device context for the desktop
    hDC      :=DllCall("GetDC","Ptr",HWND_DESKTOP)
    old_hFont:=DllCall("SelectObject","Ptr",hDC,"Ptr",hFont)

    ;-- Get the font name
    VarSetCapacity(l_FontName,MAX_FONT_NAME_LENGTH*(A_IsUnicode ? 2:1))
    DllCall("GetTextFace","Ptr",hDC,"Int",MAX_FONT_NAME_LENGTH,"Str",l_FontName)

    ;-- Release the objects needed by the GetTextFace function
    DllCall("SelectObject","Ptr",hDC,"Ptr",old_hFont)
        ;-- Necessary to avoid memory leak

    DllCall("ReleaseDC","Ptr",HWND_DESKTOP,"Ptr",hDC)

    ;-- Return to sender
    Return l_FontName
}

Fnt_GetFontSize(hFont:="") {
    Static Dummy64998752

          ;-- Device constants
          ,HWND_DESKTOP:=0
          ,LOGPIXELSY  :=90

          ;-- Misc.
          ,DEFAULT_GUI_FONT:=17
          ,OBJ_FONT        :=6

    ;-- If needed, get the handle to the default GUI font
    if (DllCall("GetObjectType","Ptr",hFont)<>OBJ_FONT)
        hFont:=DllCall("GetStockObject","Int",DEFAULT_GUI_FONT)

    ;-- Select the font into the device context for the desktop
    hDC      :=DllCall("GetDC","Ptr",HWND_DESKTOP)
    old_hFont:=DllCall("SelectObject","Ptr",hDC,"Ptr",hFont)

    ;-- Collect the number of pixels per logical inch along the screen height
    l_LogPixelsY:=DllCall("GetDeviceCaps","Ptr",hDC,"Int",LOGPIXELSY)

    ;-- Get text metrics for the font
    VarSetCapacity(TEXTMETRIC,A_IsUnicode ? 60:56,0)
    DllCall("GetTextMetrics","Ptr",hDC,"Ptr",&TEXTMETRIC)

    ;-- Convert em height to point size
    l_Size:=Round((NumGet(TEXTMETRIC,0,"Int")-NumGet(TEXTMETRIC,12,"Int"))*72/l_LogPixelsY)
        ;-- (Height - Internal Leading) * 72 / LogPixelsY

    ;-- Release the objects needed by the GetTextMetrics function
    DllCall("SelectObject","Ptr",hDC,"Ptr",old_hFont)
        ;-- Necessary to avoid memory leak

    DllCall("ReleaseDC","Ptr",HWND_DESKTOP,"Ptr",hDC)

    ;-- Return to sender
    Return l_Size
}


Fnt_CreateFont(p_Name:="",p_Options:="") {
    Static Dummy34361446

          ;-- Device constants
          ,LOGPIXELSY:=90

          ;-- Misc. font constants
          ,CLIP_DEFAULT_PRECIS:=0
          ,DEFAULT_CHARSET    :=1
          ,DEFAULT_GUI_FONT   :=17
          ,OUT_TT_PRECIS      :=4

          ;-- Font family
          ,FF_DONTCARE  :=0x0
          ,FF_ROMAN     :=0x1
          ,FF_SWISS     :=0x2
          ,FF_MODERN    :=0x3
          ,FF_SCRIPT    :=0x4
          ,FF_DECORATIVE:=0x5

          ;-- Font pitch
          ,DEFAULT_PITCH :=0
          ,FIXED_PITCH   :=1
          ,VARIABLE_PITCH:=2

          ;-- Font quality
          ,DEFAULT_QUALITY       :=0
          ,DRAFT_QUALITY         :=1
          ,PROOF_QUALITY         :=2  ;-- AutoHotkey default
          ,NONANTIALIASED_QUALITY:=3
          ,ANTIALIASED_QUALITY   :=4
          ,CLEARTYPE_QUALITY     :=5

          ;-- Font weight
          ,FW_DONTCARE:=0
          ,FW_NORMAL  :=400
          ,FW_BOLD    :=700

    ;-- Parameters
    ;   Remove all leading/trailing white space
    p_Name   :=Trim(p_Name," `f`n`r`t`v")
    p_Options:=Trim(p_Options," `f`n`r`t`v")

    ;-- If both parameters are null or unspecified, return the handle to the
    ;   default GUI font.
    if (p_Name="" and p_Options="")
        Return DllCall("GetStockObject","Int",DEFAULT_GUI_FONT)

    ;-- Initialize options
    o_Height   :=""             ;-- Undefined
    o_Italic   :=False
    o_Quality  :=PROOF_QUALITY  ;-- AutoHotkey default
    o_Size     :=""             ;-- Undefined
    o_Strikeout:=False
    o_Underline:=False
    o_Weight   :=FW_DONTCARE

    ;-- Extract options (if any) from p_Options
    Loop Parse,p_Options,%A_Space%
        {
        if A_LoopField is Space
            Continue

        if (SubStr(A_LoopField,1,4)="bold")
            o_Weight:=1000
        else if (SubStr(A_LoopField,1,6)="italic")
            o_Italic:=True
        else if (SubStr(A_LoopField,1,4)="norm")
            {
            o_Italic   :=False
            o_Strikeout:=False
            o_Underline:=False
            o_Weight   :=FW_DONTCARE
            }
        else if (A_LoopField="-s")
            o_Size:=0
        else if (SubStr(A_LoopField,1,6)="strike")
            o_Strikeout:=True
        else if (SubStr(A_LoopField,1,9)="underline")
            o_Underline:=True
        else if (SubStr(A_LoopField,1,1)="h")
            {
            o_Height:=SubStr(A_LoopField,2)
            o_Size  :=""  ;-- Undefined
            }
        else if (SubStr(A_LoopField,1,1)="q")
            o_Quality:=SubStr(A_LoopField,2)
        else if (SubStr(A_LoopField,1,1)="s")
            {
            o_Size  :=SubStr(A_LoopField,2)
            o_Height:=""  ;-- Undefined
            }
        else if (SubStr(A_LoopField,1,1)="w")
            o_Weight:=SubStr(A_LoopField,2)
        }

    ;----------------------------------
    ;-- Convert/Fix invalid or
    ;-- unspecified parameters/options
    ;----------------------------------
    if p_Name is Space
        p_Name:=Fnt_GetFontName()   ;-- Font name of the default GUI font

    if o_Height is not Integer
        o_Height:=""                ;-- Undefined

    if o_Quality is not Integer
        o_Quality:=PROOF_QUALITY    ;-- AutoHotkey default

    if o_Size is Space              ;-- Undefined
        o_Size:=Fnt_GetFontSize()   ;-- Font size of the default GUI font
     else
        if o_Size is not Integer
            o_Size:=""              ;-- Undefined
         else
            if (o_Size=0)
                o_Size:=""          ;-- Undefined

    if o_Weight is not Integer
        o_Weight:=FW_DONTCARE       ;-- A font with a default weight is created

    ;-- If needed, convert point size to em height
    if o_Height is Space        ;-- Undefined
        if o_Size is Integer    ;-- Allows for a negative size (emulates AutoHotkey)
            {
            hDC:=DllCall("CreateDC","Str","DISPLAY","Ptr",0,"Ptr",0,"Ptr",0)
            o_Height:=-Round(o_Size*DllCall("GetDeviceCaps","Ptr",hDC,"Int",LOGPIXELSY)/72)
            DllCall("DeleteDC","Ptr",hDC)
            }

    if o_Height is not Integer
        o_Height:=0                 ;-- A font with a default height is created

    ;-- Create font
    hFont:=DllCall("CreateFont"
        ,"Int",o_Height                                 ;-- nHeight
        ,"Int",0                                        ;-- nWidth
        ,"Int",0                                        ;-- nEscapement (0=normal horizontal)
        ,"Int",0                                        ;-- nOrientation
        ,"Int",o_Weight                                 ;-- fnWeight
        ,"UInt",o_Italic                                ;-- fdwItalic
        ,"UInt",o_Underline                             ;-- fdwUnderline
        ,"UInt",o_Strikeout                             ;-- fdwStrikeOut
        ,"UInt",DEFAULT_CHARSET                         ;-- fdwCharSet
        ,"UInt",OUT_TT_PRECIS                           ;-- fdwOutputPrecision
        ,"UInt",CLIP_DEFAULT_PRECIS                     ;-- fdwClipPrecision
        ,"UInt",o_Quality                               ;-- fdwQuality
        ,"UInt",(FF_DONTCARE<<4)|DEFAULT_PITCH          ;-- fdwPitchAndFamily
        ,"Str",SubStr(p_Name,1,31))                     ;-- lpszFace

  Return hFont
}


Fnt_DeleteFont(hFont) {
    If !hFont  ;-- Zero or null
       Return True

    Return DllCall("gdi32\DeleteObject","Ptr",hFont) ? True:False
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

GetWindowBounds(hWnd) {
   ; function by GeekDude: https://gist.github.com/G33kDude/5b7ba418e685e52c3e6507e5c6972959
   ; W10 compatible function to find a window's visible boundaries
   ; modified by Marius Șucanto return an array
   size := VarSetCapacity(rect, 16, 0)
   er := DllCall("dwmapi\DwmGetWindowAttribute"
      , "UPtr", hWnd  ; HWND  hwnd
      , "UInt", 9     ; DWORD dwAttribute (DWMWA_EXTENDED_FRAME_BOUNDS)
      , "UPtr", &rect ; PVOID pvAttribute
      , "UInt", size  ; DWORD cbAttribute
      , "UInt")       ; HRESULT

   If er
      DllCall("GetWindowRect", "UPtr", hwnd, "UPtr", &rect, "UInt")

   r := []
   r.x1 := NumGet(rect, 0, "Int"), r.y1 := NumGet(rect, 4, "Int")
   r.x2 := NumGet(rect, 8, "Int"), r.y2 := NumGet(rect, 12, "Int")
   r.w := Abs(max(r.x1, r.x2) - min(r.x1, r.x2))
   r.h := Abs(max(r.y1, r.y2) - min(r.y1, r.y2))
   ; ToolTip, % r.w " --- " r.h , , , 2
   Return r
}

GetWinClientSize(ByRef w, ByRef h, hwnd, mode) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
; modified by Marius Șucan
    Static prevW, prevH, prevHwnd, lastInvoked := 1
    If (A_TickCount - lastInvoked<95) && (prevHwnd=hwnd)
    {
       W := prevW, H := prevH
       Return
    }

    prevHwnd := hwnd
    VarSetCapacity(rc, 16, 0)
    If (mode=1)
    {
       r := GetWindowBounds(hwnd)
       prevW := W := r.w
       prevH := H := r.h
       lastInvoked := A_TickCount
       Return
    } Else DllCall("GetClientRect", "uint", hwnd, "uint", &rc)

    prevW := W := NumGet(rc, 8, "int")
    prevH := H := NumGet(rc, 12, "int")
    lastInvoked := A_TickCount
} 

repositionWindowCenter(whichGUI, hwndGUI, referencePoint, winTitle:="", winPos:="") {
    Static lastAsked := 1
    If !winPos
    {
       SysGet, MonitorCount, 80
       ActiveMonDetails := calcScreenLimits(referencePoint)
       ActiveMon := ActiveMonDetails.m
       ResWidth := ActiveMonDetails.w, ResHeight:= ActiveMonDetails.h
       mCoordRight := ActiveMonDetails.mCRight, mCoordLeft := ActiveMonDetails.mCLeft
       mCoordTop := ActiveMonDetails.mCTop, mCoordBottom := ActiveMonDetails.mCBottom
    }

    If (MonitorCount>1 && !winPos && A_OSVersion!="WIN_XP")
    {
       ; center window on the monitor/screen where the mouse cursor is
       semiFinal_x := mCoordLeft + 2
       semiFinal_y := mCoordTop + 2
       If !semiFinal_y
          semiFinal_y := 1
       If !semiFinal_x
          semiFinal_x := 1

       Gui, %whichGUI%: Show, Hide AutoSize x%semiFinal_x% y%semiFinal_y%, % winTitle
       Sleep, 25
       GetWinClientSize(msgWidth, msgHeight, hwndGUI, 1)
       If !msgWidth
          msgWidth := 1
       If !msgHeight
          msgHeight := 1

       Final_x := Round(mCoordLeft + ResWidth/2 - msgWidth/2)
       Final_y := Round(mCoordTop + ResHeight/2 - msgHeight/2)
       If (!Final_x) || (Final_x + 1<mCoordLeft)
          Final_x := mCoordLeft + 1
       If (!Final_y) || (Final_y + 1<mCoordTop)
          Final_y := mCoordTop + 1
       Gui, %whichGUI%: Show, x%Final_x% y%Final_y%, % Chr(160) winTitle
    } Else Gui, %whichGUI%: Show, AutoSize %winPos%, % Chr(160) winTitle
}

MWAGetMonitorMouseIsIn(coordX:=0,coordY:=0) {
; function from: https://autohotkey.com/boards/viewtopic.php?f=6&t=54557
; by Maestr0

  ; get the mouse coordinates first
  If (coordX && coordY)
  {
     Mx := coordX
     My := coordY
  } Else GetPhysicalCursorPos(mX, mY)

  SysGet, MonitorCount, 80  ; monitorcount, so we know how many monitors there are, and the number of loops we need to do
  Loop, %MonitorCount%
  {
    SysGet, mon%A_Index%, Monitor, %A_Index%  ; "Monitor" will get the total desktop space of the monitor, including taskbars
    If (Mx>=mon%A_Index%left) && (Mx<mon%A_Index%right)
    && (My>=mon%A_Index%top) && (My<mon%A_Index%bottom)
    {
       ActiveMon := A_Index
       Break
    }
  }
  Return ActiveMon
}

GetPhysicalCursorPos(ByRef mX, ByRef mY) {
; function from: https://github.com/jNizM/AHK_DllCall_WinAPI/blob/master/src/Cursor%20Functions/GetPhysicalCursorPos.ahk
; by jNizM, modified by Marius Șucan
    Static lastMx, lastMy, lastInvoked := 1
    If (A_TickCount - lastInvoked<70)
    {
       mX := lastMx
       mY := lastMy
       Return
    }

    lastInvoked := A_TickCount
    Static POINT
         , init := VarSetCapacity(POINT, 8, 0) && NumPut(8, POINT, "Int")
    GPC := DllCall("user32.dll\GetPhysicalCursorPos", "Ptr", &POINT)
    If (!GPC || A_OSVersion="WIN_XP")
    {
       MouseGetPos, mX, mY
       lastMx := mX
       lastMy := mY
       Return
     ; Return DllCall("kernel32.dll\GetLastError")
    }

    lastMx := mX := NumGet(POINT, 0, "Int")
    lastMy := mY := NumGet(POINT, 4, "Int")
    Return
}
