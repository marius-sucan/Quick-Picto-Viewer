; P1 - does an OnMessage(0x11F WM_MENUSELECT) monitor fire while this same
; script is blocked inside «Menu, Show»?
; PASS = the result box lists highlight events that happened while the menu was open.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global p1log := ""
OnMessage(0x11F, "onMenuSelect")
Menu, TestPop, Add, Alpha, dummyItem
Menu, TestPop, Add, Beta, dummyItem
Menu, TestPop, Add, Gamma, dummyItem
MsgBox, 64, P1, A menu opens at the cursor next.`nMove the highlight across Alpha / Beta / Gamma (mouse and arrow keys), then press Escape.
Menu, TestPop, Show
MsgBox, 64, P1 result, % p1log ? "PASS - the monitor fired during the modal menu loop:`n`n" SubStr(p1log, 1, 900) : "FAIL - the monitor never fired while the menu was shown."
ExitApp

onMenuSelect(wP, lP, msg, hwnd) {
   Global p1log
   item := wP & 0xFFFF
   flags := (wP >> 16) & 0xFFFF
   p1log .= "item=" item " flags=0x" Format("{:X}", flags) " tick=" A_TickCount "`n"
}

dummyItem:
Return
