; P11 - the canonical screen-reader mechanism: an OUT-OF-CONTEXT SetWinEventHook
; on EVENT_OBJECT_FOCUS (0x8005). Menus fire a focus event per highlighted item,
; and out-of-context events are delivered during the modal menu loop's own
; message retrieval - so the raw callback should run while the menu is open.
; This is the fallback display/tracking mechanism if P7's GUI-from-CALLWNDPROC fails.
; PASS = a floating tip follows the highlight (showing event/idObject/idChild)
; while the menu stays open. The real reader would resolve the item NAME via
; AccessibleObjectFromEvent - this probe only proves delivery + display.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global hWinEvt := 0, seen := 0
Menu, SubPop, Add, Alpha, dummyItem
Menu, SubPop, Add, Beta, dummyItem
Menu, SubPop, Add, Gamma, dummyItem
Menu, BarMain, Add, OpenMe, :SubPop
Gui, Main: Add, Text,, Open the menu and move the highlight around.`nPASS: a tip follows the highlight and the menu stays open.`nClose this window for the verdict.
Gui, Main: Menu, BarMain
Gui, Main: Show, w500 h100, P11 wineventhook-menu
cb := RegisterCallback("winEvt11", "F")
hWinEvt := DllCall("SetWinEventHook", "UInt", 0x8005, "UInt", 0x8005, "Ptr", 0, "Ptr", cb
                 , "UInt", DllCall("GetCurrentProcessId"), "UInt", 0, "UInt", 0, "Ptr") ; WINEVENT_OUTOFCONTEXT, own process only
Return

winEvt11(hHook, event, hwnd, idObject, idChild, idThread, evTime) {
   Global seen
   Static busy := 0
   If busy
      Return
   busy := 1
   seen++
   CoordMode, Mouse, Screen
   MouseGetPos, mx, my
   Gui, Tipy: Destroy
   Gui, Tipy: -Caption +ToolWindow +AlwaysOnTop +E0x20 -DPIScale
   Gui, Tipy: Margin, 8, 4
   Gui, Tipy: Add, Text,, % "focus event #" seen ": idObject " idObject " idChild " idChild
   Gui, Tipy: Show, % "NA x" mx+24 " y" my+24 " AutoSize"
   busy := 0
}

dummyItem:
Return

MainGuiClose:
DllCall("UnhookWinEvent", "Ptr", hWinEvt)
MsgBox, 64, P11 result, % seen ? "The callback fired " seen " time(s).`nIf the tip followed the menu highlight while the menu was open: PASS - this is a viable reader tracking+display vehicle." : "FAIL - the out-of-context event callback never fired during menus."
ExitApp
