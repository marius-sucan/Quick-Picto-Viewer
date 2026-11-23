; P10 - in-menu mouse wheel, strategy B: the WH_MSGFILTER hook EATS the wheel
; message (returns nonzero) and posts WM_KEYDOWN Up/Down to the owner window's
; queue for the menu loop to pick up.
; PASS = the highlight moves 1 item per wheel notch.
; MSG layout: hwnd@0, message(UInt)@A_PtrSize, wParam@2*A_PtrSize, lParam@3*A_PtrSize
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global logu := "", hOwner := A_ScriptHwnd
cb := RegisterCallback("msgf10", "F")
hHook := DllCall("SetWindowsHookEx", "Int", -1, "Ptr", cb, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr") ; WH_MSGFILTER = -1
Menu, TestPop, Add, wheel over the menu - the highlight should move 1 per notch, dummyItem
Menu, TestPop, Add, item 2, dummyItem
Menu, TestPop, Add, item 3, dummyItem
Menu, TestPop, Add, item 4, dummyItem
Menu, TestPop, Add, item 5 - press Escape when done, dummyItem
MsgBox, 64, P10, A menu opens next. Scroll the wheel up and down over it, then press Escape.
Menu, TestPop, Show
DllCall("UnhookWindowsHookEx", "Ptr", hHook)
MsgBox, 64, P10 result, % logu ? "Wheel messages seen, eaten, and re-posted as key-downs:`n" SubStr(logu, 1, 700) "`nIf the highlight MOVED per notch: PASS [strategy B works]." : "NO wheel messages traversed MSGF_MENU - if P9 saw none either, in-menu wheel handling needs a WH_GETMESSAGE hook instead."
ExitApp

msgf10(nCode, wP, lP) {
   Global logu, hOwner
   Critical
   If (nCode = 2) ; MSGF_MENU
   {
      msg := NumGet(lP+0, A_PtrSize, "UInt")
      If (msg = 0x20A) ; WM_MOUSEWHEEL
      {
         wpar := NumGet(lP+0, 2*A_PtrSize, "UPtr")
         delta := (wpar >> 16) & 0xFFFF
         delta := (delta > 0x7FFF) ? delta - 0x10000 : delta
         vk := (delta > 0) ? 0x26 : 0x28   ; VK_UP : VK_DOWN
         DllCall("PostMessage", "Ptr", hOwner, "UInt", 0x100, "Ptr", vk, "Ptr", 1)
         logu .= "delta " delta " -> posted WM_KEYDOWN vk 0x" Format("{:X}", vk) " to owner`n"
         Return 1   ; eat the wheel message
      }
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return
