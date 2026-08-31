; P3 - do AHK SetTimer timers tick while this same thread is inside «Menu, Show»?
; Expected: NO (delta ~0). That confirms the 60ms MSAA menu poll cannot survive the
; merge, and that hover-switching needs native submenus (D1).
#NoEnv
#SingleInstance Force
SetBatchLines, -1

Global ticks := 0
SetTimer, tickTock, 100
Menu, TestPop, Add, Keep this menu open ~3 seconds - then press Escape, dummyItem
MsgBox, 64, P3, A menu opens next. Keep it OPEN for about 3 seconds, then press Escape.
before := ticks
t0 := A_TickCount
Menu, TestPop, Show
elapsed := A_TickCount - t0
delta := ticks - before
MsgBox, 64, P3 result, % "Menu was open " elapsed " ms; the 100ms timer ticked " delta " time(s) during it.`n`n" ((delta < 2) ? "CONFIRMED: AHK timers do NOT run during the same-thread menu loop." : "SURPRISE: timers DO run during the menu loop - the D1 design can be simplified.")
ExitApp

tickTock:
ticks++
Return

dummyItem:
Return
