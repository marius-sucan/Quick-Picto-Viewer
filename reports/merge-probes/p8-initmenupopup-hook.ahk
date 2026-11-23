; P8 - can the AHK menu be REBUILT from a raw WH_CALLWNDPROC callback when
; WM_INITMENUPOPUP arrives - i.e., is JIT dropdown rebuilding viable during the
; native menu-bar tracking loop, now that P2 proved OnMessage monitors are not?
; PASS = the dropdown always shows a freshly timestamped item, never "placeholder".
; CWPSTRUCT layout is REVERSED: lParam@0, wParam@A_PtrSize, message(UInt)@2*A_PtrSize, hwnd@3*A_PtrSize
; For WM_INITMENUPOPUP the message's wParam IS the HMENU about to be shown.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global hCwpHook := 0, fired := 0
Menu, SubPop, Add, placeholder (you should NEVER see this), dummyItem
Menu, BarMain, Add, OpenMe, :SubPop
Gui, Main: Add, Text,, Open "OpenMe" several times.`nPASS: the dropdown always shows a fresh timestamped item, never "placeholder".`nClose this window for the verdict.
Gui, Main: Menu, BarMain
Gui, Main: Show, w500 h100, P8 initmenupopup-hook
cb := RegisterCallback("cwpHook8", "F")
hCwpHook := DllCall("SetWindowsHookEx", "Int", 4, "Ptr", cb, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr") ; WH_CALLWNDPROC = 4
Return

cwpHook8(nCode, wP, lP) {
   Global fired
   Static busy := 0
   If (nCode >= 0 && !busy)
   {
      msg := NumGet(lP+0, 2*A_PtrSize, "UInt")
      If (msg = 0x117) ; WM_INITMENUPOPUP
      {
         mwParam := NumGet(lP+0, A_PtrSize, "UPtr")
         If (mwParam = MenuGetHandle("SubPop"))
         {
            busy := 1
            fired++
            Menu, SubPop, DeleteAll
            Menu, SubPop, Add, % "rebuilt at tick " A_TickCount " (open #" fired ")", dummyItem
            busy := 0
         }
      }
   }
   Return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

dummyItem:
Return

MainGuiClose:
DllCall("UnhookWindowsHookEx", "Ptr", hCwpHook)
MsgBox, 64, P8 result, % fired ? "The hook rebuilt the menu " fired " time(s).`nIf every popup showed the fresh item and the app stayed stable: PASS - JIT rebuild from the hook is viable.`nIf you saw ""placeholder"" or crashes: FAIL - phase D falls back to eager rebuilds on state changes." : "FAIL - the hook never matched WM_INITMENUPOPUP for SubPop."
ExitApp
