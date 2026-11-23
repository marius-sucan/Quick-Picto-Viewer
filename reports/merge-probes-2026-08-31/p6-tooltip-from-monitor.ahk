; P6 - can a NoActivate, click-through tooltip GUI be created/updated from inside a
; WM_MENUSELECT monitor without dismissing the menu? (The OSD reader needs this, D2.)
; PASS = a floating tip follows the highlighted item and the menu STAYS OPEN.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Menu, SubPop, Add, Alpha, dummyItem
Menu, SubPop, Add, Beta, dummyItem
Menu, SubPop, Add, Gamma, dummyItem
Menu, BarMain, Add, OpenMe, :SubPop
Gui, Main: Add, Text,, Open the menu and move the highlight around.`nPASS: a floating tip follows the highlight and the menu never closes on its own.
Gui, Main: Menu, BarMain
Gui, Main: Show, w480 h90, P6 tooltip-from-monitor
OnMessage(0x11F, "onMenuSelect6")
Return

onMenuSelect6(wP, lP, msg, hwnd) {
   Static tipExists := 0
   item := wP & 0xFFFF
   CoordMode, Mouse, Screen
   MouseGetPos, mx, my
   Gui, Tipy: Destroy
   Gui, Tipy: -Caption +ToolWindow +AlwaysOnTop +E0x20 -DPIScale +HwndhTipy
   Gui, Tipy: Margin, 8, 4
   Gui, Tipy: Add, Text,, % "highlight: item #" item "  tick " A_TickCount
   Gui, Tipy: Show, % "NA x" mx+24 " y" my+24 " AutoSize"
}

dummyItem:
Return

MainGuiClose:
ExitApp
