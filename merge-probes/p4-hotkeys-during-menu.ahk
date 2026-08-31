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
during := 0, after := 0
Loop, Parse, hits, `n
{
   If !A_LoopField
      Continue
   RegExMatch(A_LoopField, "at (\d+)", m)
   If (m1 && m1 < closedAt)
      during++
   Else
      after++
}
verdict := !hits ? "FAIL - no hotkey subroutine ran at all."
   : (during ? "PASS - " during " subroutine(s) ran DURING the menu loop [" after " deferred]."
   : "FAIL/DEFERRED - all " after " subroutine(s) ran only after the menu closed.")
MsgBox, 64, P4 result, % verdict "`n`nRaw log [menu closed at tick " closedAt "]:`n" hits "`nIf the highlight also moved on wheel while the menu was open, SendInput from a hotkey works during the loop."
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
