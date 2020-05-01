; ================================================================================
; by: TheArkive and Marius Șucan
; Replaces MsgBox function and allows using MsgBox2() inline as a function returning
; a value selected by the user. 
; ================================================================================================
; Thanks to [just me] for creating TaskDialog that gave me ideas and inspiration.
; https://github.com/AHK-just-me/TaskDialog/blob/master/Sources/TaskDialog.ahk
; ================================================================================
; modified a lot by Marius Șucan in mercredi 29 avril 2020
; Usage example:
; msgResult := MsgBox2("Please confirm you want to delete this file", "confirmation box", "&Delete|&Cancel", 2, "question", "Arial", 0, 12, ,, "Do not prompt again before file delete", 1)

Global MsgBox2InputHook, MsgBox2Result, MsgBox2hwnd

MsgBox2(sMsg, title:="Notification", btnList:=0, btnDefault:=1, icon:="", fontFace:="Arial", doBold:=0, fontSize:="", modalHwnd:="", ownerHwnd:="", checkBoxCaption:="", checkBoxState:=0) {
  Global CheckBoxu
  oCritic := A_IsCritical 
  Critical, off

  fontSize := Round(A_ScreenDPI/100) + fontSize
  thisHwnd := ownerHwnd ? ownerHwnd : modalHwnd
  If !thisHwnd
     thisHwnd := "mouse"

  ActiveMon := calcScreenLimits(thisHwnd)
  rMaxW := Floor(ActiveMon.w*0.95)
  rMaxH := Floor(ActiveMon.h*0.95)
  retVal := GetMsgDimensions("TRY AGAIN", fontFace, fontSize, rMaxW, rMaxW, 1)   ; default btn width / height
  bH := retVal.h, bW := retVal.w, retVal := ""  ; btn min width / height

  mustCalcBtnDimensions := 0
  bMW := 0 ; initialize btnCount, btnDefault (excludes help button)
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
  Else mustCalcBtnDimensions := 1

  btnCount := 0
  If InStr(btnList, "|")
  {
    Loop, Parse, btnList, |
    {
      btnText := A_LoopField
      newBtnList .= StrReplace(btnText,"[d]","") "|"
      btnTextProp := InStr(A_LoopField,"["), btnText := btnTextProp?SubStr(btnText,1,btnTextProp-1):btnText
      If (mustCalcBtnDimensions=1)
         btnDim := GetMsgDimensions(btnText, fontFace, fontSize, rMaxW, rMaxH)
      btnCount++
      If (btnDim.w > bW)
      {
         bW := btnDim.w
         bH := btnDim.h
      }
    }
    btnList := Trim(newBtnList, "|")
  }
  If (btnCount=0 && StrLen(btnList)>0)
     btnCount := 1

  bW+=20, bH+=Round(bH*0.9), bMW := btnCount*bW, btnDim := "" ; bH+=15       set button group width
  btnDefault := !btnDefault ? 1 : btnDefault
  marginsGui := bH//2
  doBold := (doBold=1) ? "Bold" : ""

  msg := GetMsgDimensions(sMsg, fontFace, fontSize, rMaxW - bH//2, rMaxH - bH*2) ; get msg dimensions and line height (txtH)
  msgW := (icon && btnCount>0) ? msg.w - bH : msg.w
  If (msgW<bMW)
     msgW := bMW + bH//2

  msgH := msg.h - bH//2
  msgH := (msgH>rMaxH) ? "h" maxH : ""
  Gui, MsgBox2:New, -SysMenu -DPIScale +HwndMsgBox2hwnd +LabelMsgBox2, % Chr(160) Chr(160) title
  Gui, MsgBox2: Margin, %marginsGui%, %marginsGui%
  Gui, Font, s%fontSize% %doBold% Q4, %fontFace% 

  iconFile := 0
  If (icon && btnCount>0)
  {
    If (icon="error" || icon="stop")
    {
      iconFile := "imageres.dll", iconNum := 94
      SoundPlay, *16
    } Else If (icon="question")
    {
      iconFile := "imageres.dll", iconNum := 95
      SoundPlay, *32
    } Else If (icon="warning" || icon="exclamation")
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
    } Else If (!InStr(icon,"HBITMAP:") && !InStr(icon,"HICON:"))
    {
      iconArr := StrSplit(icon,"/"), iconFile := iconArr[1], iconNum := iconArr[2], iconArr := ""
    } Else
    {
      iconFile := icon
      iconHandle := true
    }
  }

   If (iconFile)
   {
    If (iconHandle)
       Gui, MsgBox2:Add, Picture, AltSubmit x%marginsGui% y%marginsGui% h%bH% w-1, %iconFile%
    Else If (iconNum)
       Gui, MsgBox2:Add, Picture, AltSubmit x%marginsGui% y%marginsGui% h%bH% Icon%iconNum% w-1, %iconFile%
    Else
       Gui, MsgBox2:Add, Picture, AltSubmit x%marginsGui% y%marginsGui% h%bH% w-1, %iconFile%
    Gui, MsgBox2:Add, Edit, x+%marginsGui% w%msgW% %msgH% ReadOnly -Tabstop -E0x200 -HScroll -VScroll, %sMsg%
  } Else
    Gui, MsgBox2:Add, Edit, x%marginsGui% y%marginsGui% w%msgW% %msgH% ReadOnly -Tabstop -E0x200 -HScroll -VScroll, %sMsg%

  Gui, MsgBox2:Add, Text, xp yp wp hp BackgroundTrans,% A_Space

  If checkBoxCaption
     Gui, MsgBox2:Add, Checkbox, xp y+15 wp Checked%checkBoxState% vCheckBoxu, %checkBoxCaption%

  Loop, Parse, btnList, | ; list specified buttons
  {
      If !A_LoopField
         Continue

      def := ""
      btnText := A_LoopField
      If (A_Index=btnDefault)
         def := " +Default"
      
      If (A_Index=1)
         Gui, MsgBox2:Add, Button, gMsgBox2event xp y+15 w%bW% h%bH% %def%, %btnText%
      Else
         Gui, MsgBox2:Add, Button, gMsgBox2event x+0 w%bW% h%bH% %def%, %btnText%
  }
  If !btnCount
     Gui, MsgBox2:Add, Button, gMsgBox2event x+0 w1 h1 Default, --

  Gui, MsgBox2:Add, Text, xp yp w1 h1 BackgroundTrans,% A_Space

  If ownerHwnd
     Gui, +Owner%ownerHwnd%

  If (modalHwnd && btnCount>0)
     WinSet, Disable,, ahk_id %modalHwnd%

  Gui, MsgBox2:Show, AutoSize
  repositionWindowCenter("MsgBox2", MsgBox2hwnd)
  If checkBoxCaption
     btnDefault++
  GuiControl, MsgBox2:Focus, Button%btnDefault%

  If !btnCount
     SetTimer, CloseMsgBox2Win, 400

  MsgBox2InputHook := InputHook("V") ; "V" for not blocking input
  MsgBox2InputHook.KeyOpt("{BackSpace}{Escape}{Enter}{Space}{NumpadEnter}","N")
  MsgBox2InputHook.OnKeyUp := Func("MsgBox2InputHookKeyDown")
  MsgBox2InputHook.Start()
  MsgBox2InputHook.Wait()
  GuiControlGet, CheckBoxu
  If checkBoxCaption
     addCheckInfo := "||" CheckBoxu

  If modalHwnd
     WinSet, Enable,, ahk_id %modalHwnd%

  Gui, MsgBox2:Destroy
  Critical, % oCritic 
  return StrReplace(MsgBox2Result, "&") addCheckInfo
}

CloseMsgBox2Win() {
  hwnd := WinActive("A")
  If (hwnd!=MsgBox2hwnd)
  {
     MsgBox2InputHook.Stop()
     SetTimer, , Off
  }
}

MsgBox2event(CtrlHwnd, GuiEvent, EventInfo) {
  ; GuiControlGet, btnClassNN, Focus
  ; GuiControlGet, btnText, FocusV
  ControlGetText, btnText, , ahk_id %CtrlHwnd%
  ; MsgBox, % btnText "`n" OutputVar "`n" CtrlHwnd "`n" guievent "`n" EventInfo "`n" btnClassNN
  MsgBox2Result := btnText
  MsgBox2InputHook.Stop()
}

MsgBox2InputHookKeyDown(iHook, VK, SC) {
  GuiControlGet, btnText, FocusV
  If (vk=27)
  {
     MsgBox2Result := "Escape_vk" vk
     MsgBox2InputHook.Stop()
  } Else If !btnText
     GuiControl, MsgBox2:Focus, Button1
}

GetMsgDimensions(sString, FaceName, FntSize, maxW, maxH, btnMode:=0) {
    Gui, New, -DPIScale
    Gui, Font, s%FntSize%, %FaceName%
    Gui, Add, Text,, %sString%
    GuiControlGet, ctlSizeTmp1, Pos, Static1

    ; half := Round(maxW*0.65)
    ; Gui, Add, Text, w%half%, %sString%
    ; GuiControlGet, ctlSizeTmp2, Pos, Static2
    Gui, Destroy
    r := []
    r.l := ctlSizeTmp1h ; line height
    modifiedW := 0
    If (ctlSizeTmp1W>maxW*0.6)
    {
       modifiedW := 1
       r.w := ctlSizeTmp1W//1.7
    } Else r.w := ctlSizeTmp1W

    If (ctlSizeTmp1W>maxW)
    {
       modifiedW := 1
       r.w := Round(maxW*0.8)
    }

    r.h := ctlSizeTmp1H
    If (btnMode=1)
       r.w := ctlSizeTmp1W
    Else If (ctlSizeTmp1H>maxH*0.9 && modifiedW=1)
       r.w := maxW

    If (ctlSizeTmp1H>maxH*0.99)
       r.h := maxH
    ; MsgBox, % r.w "`n" maxW "`n" maxH "`n" ctlSizeTmp1W "`n" ctlSizeTmp1H
    Return r
}

