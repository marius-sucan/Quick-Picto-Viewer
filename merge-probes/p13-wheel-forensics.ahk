; P13 - wheel forensics + last resort. p5 showed wheel never traverses MSGF_MENU and
; p12 failed at WH_GETMESSAGE, so this probe taps ALL remaining layers at once to find
; where in-menu wheel input actually goes, and acts from the one layer that must see it:
;   tap 1: WH_GETMESSAGE   - counts wheel in the queue (PM_REMOVE and PM_NOREMOVE peeks)
;   tap 2: WH_CALLWNDPROC  - counts wheel SENT to any window of this thread (e.g. #32768)
;   tap 3: WH_MOUSE_LL     - hardware level; while our menu is open it EATS the wheel
;                            and posts WM_KEYDOWN Up/Down to the owner's queue
; PASS = the highlight moves on wheel (tap 3 acting). The counters tell us, regardless,
; which layers ever saw wheel input - so one run finishes the investigation.
; If even tap 3 shows wheel seen but the highlight never moves, menus do not accept
; synthesized key-downs from the queue and the in-menu wheel feature is dropped.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global cntQueueRem := 0, cntQueuePeek := 0, cntSent := 0, cntLL := 0, hOwner := A_ScriptHwnd, QPVpid13 := DllCall("GetCurrentProcessId")
cb1 := RegisterCallback("tapGetMsg", "F")
hH1 := DllCall("SetWindowsHookEx", "Int", 3, "Ptr", cb1, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr")   ; WH_GETMESSAGE
cb2 := RegisterCallback("tapCallWnd", "F")
hH2 := DllCall("SetWindowsHookEx", "Int", 4, "Ptr", cb2, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr")   ; WH_CALLWNDPROC
cb3 := RegisterCallback("tapMouseLL", "F")
hH3 := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", cb3, "Ptr", DllCall("GetModuleHandle", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr") ; WH_MOUSE_LL
Menu, TestPop, Add, wheel over the menu - watch whether the highlight moves, dummyItem
Menu, TestPop, Add, item 2, dummyItem
Menu, TestPop, Add, item 3, dummyItem
Menu, TestPop, Add, item 4, dummyItem
Menu, TestPop, Add, item 5 - press Escape when done, dummyItem
MsgBox, 64, P13, A menu opens next. Scroll the wheel up and down over it a few times, then press Escape.
Menu, TestPop, Show
DllCall("UnhookWindowsHookEx", "Ptr", hH1)
DllCall("UnhookWindowsHookEx", "Ptr", hH2)
DllCall("UnhookWindowsHookEx", "Ptr", hH3)
MsgBox, 64, P13 result, % "Wheel sightings while the menu was open:`n"
   . "  queue [PM_REMOVE]: " cntQueueRem "   queue [peek]: " cntQueuePeek "`n"
   . "  sent to a window of this thread: " cntSent "`n"
   . "  low-level hook [eaten, keydown posted]: " cntLL "`n`n"
   . (cntLL ? "If the highlight MOVED per notch: PASS - a menu-scoped WH_MOUSE_LL hook is the D2 wheel mechanism.`nIf it did NOT move: menus ignore queue-posted key-downs; the in-menu wheel feature is dropped."
            : "Even the low-level hook saw no wheel - nothing more to try; the in-menu wheel feature is dropped.")
ExitApp

menuIsOpen13() {
; NB: a HIDDEN #32768 window persists in the process once any menu has ever shown -
; with DetectHiddenWindows off [the default here], WinExist matches only a visible one.
   Global QPVpid13
   Return WinExist("ahk_class #32768 ahk_pid " QPVpid13) ? 1 : 0
}

tapGetMsg(nCode, wP, lP) {
   Global cntQueueRem, cntQueuePeek
   Critical
   If (nCode = 0 && NumGet(lP+0, A_PtrSize, "UInt") = 0x20A)
   {
      If (wP = 1)
         cntQueueRem++
      Else
         cntQueuePeek++
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

tapCallWnd(nCode, wP, lP) {
   Global cntSent
   Critical
   If (nCode >= 0 && NumGet(lP+0, 2*A_PtrSize, "UInt") = 0x20A)   ; CWPSTRUCT: message @ 2*PtrSize
      cntSent++
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

tapMouseLL(nCode, wP, lP) {
; MSLLHOOKSTRUCT: pt(8), mouseData@8 (wheel delta in high word), flags, time, extra
   Global cntLL, hOwner
   Critical
   If (nCode = 0 && wP = 0x20A && menuIsOpen13())
   {
      cntLL++
      delta := (NumGet(lP+0, 8, "UInt") >> 16) & 0xFFFF
      delta := (delta > 0x7FFF) ? delta - 0x10000 : delta
      vk := (delta > 0) ? 0x26 : 0x28   ; VK_UP : VK_DOWN
      DllCall("PostMessage", "Ptr", hOwner, "UInt", 0x100, "Ptr", vk, "Ptr", 1)
      Return 1   ; eat the hardware wheel event while our menu is open
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return
