; P2 - does OnMessage(0x117 WM_INITMENUPOPUP) fire before a popup opens, and do
; Menu, DeleteAll / Add executed INSIDE the monitor take effect in that very popup?
; PASS = the dropdown shows a freshly timestamped item, never the "placeholder" item.
; Also proves the wParam(HMENU) <-> MenuGetHandle mapping the D1 design relies on.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global fired := 0
Menu, SubPop, Add, placeholder (you should NEVER see this), dummyItem
Menu, BarMain, Add, OpenMe, :SubPop
Gui, Main: Add, Text,, Open the "OpenMe" menu a few times.`nPASS: the dropdown always shows a freshly timestamped item, never "placeholder".
Gui, Main: Menu, BarMain
Gui, Main: Show, w460 h90, P2 initmenupopup
OnMessage(0x117, "onInitMenuPopup")
Return

onInitMenuPopup(wP, lP, msg, hwnd) {
   Global fired
   If (wP != MenuGetHandle("SubPop"))  ; the HMENU<->name mapping D1 uses
      Return
   fired++
   Menu, SubPop, DeleteAll
   Menu, SubPop, Add, % "rebuilt at tick " A_TickCount " (open #" fired ")", dummyItem
}

dummyItem:
Return

MainGuiClose:
MsgBox, 64, P2 result, % fired ? "Monitor fired " fired " time(s) with a correct HMENU match.`nIf every popup showed the rebuilt item: PASS." : "FAIL - the 0x117 monitor never fired (or the HMENU never matched)."
ExitApp
