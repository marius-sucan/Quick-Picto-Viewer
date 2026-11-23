; P12 - in-menu mouse wheel, strategy C: a same-thread WH_GETMESSAGE hook.
; Round-2 established wheel messages do NOT traverse MSGF_MENU (p5: wheel=0), which
; is why p9/p10 failed. WH_GETMESSAGE sees every message the modal menu loop
; retrieves from the thread queue, and PM_REMOVE'd messages may legally be
; modified in place (documented for this hook).
; PASS = the highlight moves 1 item per wheel notch while the menu is open.
; FAIL + empty log = wheel is consumed below the queue; the in-menu wheel feature
; becomes an accepted degradation (native Win10 menus still wheel-scroll when they
; overflow the screen).
; MSG layout: hwnd@0, message(UInt)@A_PtrSize, wParam@2*A_PtrSize, lParam@3*A_PtrSize
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global logu := ""
cb := RegisterCallback("getMsg12", "F")
hHook := DllCall("SetWindowsHookEx", "Int", 3, "Ptr", cb, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr") ; WH_GETMESSAGE = 3
Menu, TestPop, Add, wheel over the menu - the highlight should move 1 per notch, dummyItem
Menu, TestPop, Add, item 2, dummyItem
Menu, TestPop, Add, item 3, dummyItem
Menu, TestPop, Add, item 4, dummyItem
Menu, TestPop, Add, item 5 - press Escape when done, dummyItem
MsgBox, 64, P12, A menu opens next. Scroll the wheel up and down over it, then press Escape.
Menu, TestPop, Show
DllCall("UnhookWindowsHookEx", "Ptr", hHook)
MsgBox, 64, P12 result, % logu ? "Wheel messages seen by WH_GETMESSAGE and rewritten:`n" SubStr(logu, 1, 700) "`nIf the highlight MOVED per notch: PASS [strategy C - this is the D2 wheel mechanism]." : "NO wheel messages reached WH_GETMESSAGE while the menu was open - wheel input is consumed below the queue; the in-menu wheel feature would be dropped [accepted degradation]."
ExitApp

getMsg12(nCode, wP, lP) {
; wP = PM_REMOVE(1) / PM_NOREMOVE(0); modify only removed messages
   Global logu
   Critical
   If (nCode = 0 && wP = 1)
   {
      msg := NumGet(lP+0, A_PtrSize, "UInt")
      If (msg = 0x20A) ; WM_MOUSEWHEEL
      {
         ; act only while our own menu window is up (the real D2 gates the same way)
         If WinExist("ahk_class #32768 ahk_pid " DllCall("GetCurrentProcessId"))
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
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return
