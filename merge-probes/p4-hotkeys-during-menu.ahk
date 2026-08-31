; P4 - do hook hotkeys gated on «#If WinExist("ahk_class #32768 ...")» actually RUN,
; and does SendInput from them work, while this same thread is inside the menu loop?
; This mirrors the accessibility menu-reader block (module-interface.ahk:2740).
; PASS = timestamps BEFORE the "menu closed" timestamp, and the wheel moved the highlight.
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global hits := ""
Menu, TestPop, Add, While open: press F9 + RIGHT-click + wheel DOWN. Then Escape., dummyItem
Menu, TestPop, Add, second item (wheel should move the highlight here), dummyItem
Menu, TestPop, Add, third item, dummyItem
MsgBox, 64, P4, While the menu is open:`n1) press F9`n2) RIGHT-click`n3) scroll the wheel DOWN (watch whether the highlight moves)`nThen press Escape.
Menu, TestPop, Show
closedAt := A_TickCount
MsgBox, 64, P4 result, % (hits ? "Hotkey subroutines ran at:`n" hits : "No hotkey subroutine ran at all.`n") . "`nMenu closed at tick " closedAt ".`nEntries with SMALLER ticks ran DURING the loop = PASS (deferred ones show ticks >= close).`nIf the highlight moved on wheel, SendInput works from inside too."
ExitApp

#If WinExist("ahk_class #32768 ahk_pid " DllCall("GetCurrentProcessId"))
F9::
   hits .= "F9 at " A_TickCount "`n"
Return
~RButton::
   hits .= "RButton at " A_TickCount "`n"
Return
~WheelDown::
   hits .= "WheelDown at " A_TickCount "`n"
   SendInput, {Down}
Return
#If

dummyItem:
Return
