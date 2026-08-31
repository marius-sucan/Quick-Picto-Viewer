; P7 - does a same-thread WH_CALLWNDPROC hook receive WM_MENUSELECT (SENT to the
; owner window during the menu modal loop), and can it update a tooltip GUI live
; from the raw callback? This is the candidate reader-tracking mechanism after
; P1/P6 proved OnMessage monitors never run during same-interpreter menu loops.
; PASS = a floating tip follows the highlighted item while the menu STAYS open.
; CWPSTRUCT layout is REVERSED: lParam@0, wParam@A_PtrSize, message(UInt)@2*A_PtrSize, hwnd@3*A_PtrSize
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global hCwpHook := 0, seen := 0
Menu, SubPop, Add, Alpha, dummyItem
Menu, SubPop, Add, Beta, dummyItem
Menu, SubPop, Add, Gamma, dummyItem
Menu, BarMain, Add, OpenMe, :SubPop
Gui, Main: Add, Text,, Open the menu and move the highlight around.`nPASS: a tip follows the highlight and the menu stays open.`nClose this window for the verdict.
Gui, Main: Menu, BarMain
Gui, Main: Show, w500 h100, P7 callwndproc-menuselect
cb := RegisterCallback("cwpHook7", "F")
hCwpHook := DllCall("SetWindowsHookEx", "Int", 4, "Ptr", cb, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr") ; WH_CALLWNDPROC = 4
Return

cwpHook7(nCode, wP, lP) {
   Global seen
   Static busy := 0   ; Gui commands below SEND messages themselves -> guard re-entry
   If (nCode >= 0 && !busy)
   {
      msg := NumGet(lP+0, 2*A_PtrSize, "UInt")
      If (msg = 0x11F) ; WM_MENUSELECT
      {
         busy := 1
         seen++
         mwParam := NumGet(lP+0, A_PtrSize, "UPtr")
         item := mwParam & 0xFFFF
         flags := (mwParam >> 16) & 0xFFFF
         CoordMode, Mouse, Screen
         MouseGetPos, mx, my
         Gui, Tipy: Destroy
         Gui, Tipy: -Caption +ToolWindow +AlwaysOnTop +E0x20 -DPIScale
         Gui, Tipy: Margin, 8, 4
         Gui, Tipy: Add, Text,, % "menuselect #" seen ": item " item " flags 0x" Format("{:X}", flags)
         Gui, Tipy: Show, % "NA x" mx+24 " y" my+24 " AutoSize"
         busy := 0
      }
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return

MainGuiClose:
DllCall("UnhookWindowsHookEx", "Ptr", hCwpHook)
MsgBox, 64, P7 result, % seen ? "The hook saw " seen " WM_MENUSELECT message(s).`n`nIf the tip followed the highlight while the menu was open: FULL PASS.`nIf messages were counted but no tip ever appeared: reception works, GUI-from-this-callback does not - use P11's mechanism for the display instead." : "FAIL - the CALLWNDPROC hook never saw WM_MENUSELECT."
ExitApp
