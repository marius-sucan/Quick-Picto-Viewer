; P5 - does a thread-scoped WH_MSGFILTER hook (installed via RegisterCallback) receive
; MSGF_MENU messages during «Menu, Show», and does SendInput work from inside it?
; PASS = wheel scrolling moves the menu highlight 2 items per notch, and the result
; box lists the wheel/button messages the hook saw.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global msgfLog := ""
cb := RegisterCallback("menuMsgFilter", "F")
hHook := DllCall("SetWindowsHookEx", "Int", -1, "Ptr", cb, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr") ; WH_MSGFILTER = -1
If !hHook
{
   MsgBox, 16, P5, SetWindowsHookEx failed.
   ExitApp
}
Menu, TestPop, Add, Scroll the wheel over this menu (2 items per notch = PASS), dummyItem
Menu, TestPop, Add, second item, dummyItem
Menu, TestPop, Add, third item, dummyItem
Menu, TestPop, Add, fourth item, dummyItem
Menu, TestPop, Add, fifth item - then press Escape, dummyItem
MsgBox, 64, P5, A menu opens next. Hover it and scroll the wheel up/down - the highlight should move 2 items per notch. Also right-click once. Then Escape.
Menu, TestPop, Show
DllCall("UnhookWindowsHookEx", "Ptr", hHook)
MsgBox, 64, P5 result, % msgfLog ? "PASS - MSGF_MENU messages seen by the hook:`n`n" SubStr(msgfLog, 1, 900) : "FAIL - the hook saw no menu-loop messages."
ExitApp

menuMsgFilter(nCode, wP, lP) {
   Global msgfLog
   Critical
   If (nCode = 2)  ; MSGF_MENU
   {
      ; lP -> MSG: hwnd(Ptr), message(UInt @A_PtrSize), wParam(UPtr @2*A_PtrSize)
      msg := NumGet(lP+0, A_PtrSize, "UInt")
      If (msg = 0x20A)  ; WM_MOUSEWHEEL
      {
         wParamu := NumGet(lP+0, 2*A_PtrSize, "UPtr")
         delta := (wParamu >> 16) & 0xFFFF
         delta := (delta > 0x7FFF) ? delta - 0x10000 : delta
         msgfLog .= "wheel delta=" delta " -> SendInput {" (delta > 0 ? "Up" : "Down") " 2}`n"
         SendInput, % "{" (delta > 0 ? "Up" : "Down") " 2}"
      } Else If (msg = 0x204 || msg = 0x205)
         msgfLog .= "RButton msg=0x" Format("{:X}", msg) "`n"
      Else If (msg = 0x100)
         msgfLog .= "keydown vk=0x" Format("{:X}", NumGet(lP+0, 2*A_PtrSize, "UPtr")) "`n"
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return
