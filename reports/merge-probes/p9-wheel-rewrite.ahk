; P9 - in-menu mouse wheel, strategy A: the WH_MSGFILTER hook REWRITES the wheel
; message in place into a keyboard Up/Down before the menu loop processes it.
; (P5 proved the hook runs during the loop; SendInput from inside it did nothing.)
; PASS = the highlight moves 1 item per wheel notch.
; Also answers: do wheel messages traverse MSGF_MENU at all?
; MSG layout: hwnd@0, message(UInt)@A_PtrSize, wParam@2*A_PtrSize, lParam@3*A_PtrSize
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global logu := ""
cb := RegisterCallback("msgf9", "F")
hHook := DllCall("SetWindowsHookEx", "Int", -1, "Ptr", cb, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr") ; WH_MSGFILTER = -1
Menu, TestPop, Add, wheel over the menu - the highlight should move 1 per notch, dummyItem
Menu, TestPop, Add, item 2, dummyItem
Menu, TestPop, Add, item 3, dummyItem
Menu, TestPop, Add, item 4, dummyItem
Menu, TestPop, Add, item 5 - press Escape when done, dummyItem
MsgBox, 64, P9, A menu opens next. Scroll the wheel up and down over it, then press Escape.
Menu, TestPop, Show
DllCall("UnhookWindowsHookEx", "Ptr", hHook)
MsgBox, 64, P9 result, % logu ? "Wheel messages seen and rewritten:`n" SubStr(logu, 1, 700) "`nIf the highlight MOVED per notch: PASS [strategy A works].`nIf it never moved: rewrite is ignored - try P10 [strategy B]." : "NO wheel messages traversed MSGF_MENU at all - strategy A impossible here; run P10 and note whether it sees any either."
ExitApp

msgf9(nCode, wP, lP) {
   Global logu
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
         NumPut(0x100, lP+0, A_PtrSize, "UInt")   ; message := WM_KEYDOWN
         NumPut(vk, lP+0, 2*A_PtrSize, "UPtr")    ; wParam  := virtual key
         NumPut(1, lP+0, 3*A_PtrSize, "UPtr")     ; lParam  := repeat count 1
         logu .= "delta " delta " -> WM_KEYDOWN vk 0x" Format("{:X}", vk) "`n"
      }
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return
