# Merge probes (Phase P)

Six standalone probes for the interfaceThread merge (see the plan). Run each on Windows
with **stock AutoHotkey v1.1 (U64)** — NOT AHK_H — because they establish what the merged,
de-H app can rely on. Each shows its verdict in a MsgBox; no files are written.

| Probe | Question | Decides |
|---|---|---|
| p1-menuselect.ahk | Does an `OnMessage(0x11F WM_MENUSELECT)` monitor fire while this same script sits inside `Menu, Show`? | D2 reader architecture. PASS → highlight tracking + announcements come from the monitor. FAIL → reader falls back to the WH_MSGFILTER hook (P5). |
| p2-initmenupopup.ahk | Does `OnMessage(0x117 WM_INITMENUPOPUP)` fire before the popup opens, and do `Menu, Add/Delete` inside the monitor take effect in that very popup? | D1 dropdown strategy. PASS → JIT rebuild (InvokeMenuBar* builders run from the monitor). FAIL → eager rebuild driven by UpdateMenuBar's state hash. |
| p3-timer-during-menu.ahk | Do AHK `SetTimer` timers tick while the same thread is inside `Menu, Show`? | Expected NO — confirms `findMenuBarItemUnderMouse` (60ms MSAA poll) cannot survive the merge and must be deleted in favor of native submenus, and predicts the C-era hover-switch degradation. A surprise YES would shrink D1. |
| p4-hotkeys-during-menu.ahk | Do hook hotkeys under `#If WinExist("ahk_class #32768 ...")` actually RUN (and can they SendInput) while the same thread is inside the menu loop? | Whether the accessibility menu-reader hotkey block (module-interface.ahk:2740) survives the merge nearly unchanged (PASS) or must be rebuilt on the WH_MSGFILTER hook (FAIL). |
| p5-msgfilter-hook.ahk | Does a thread-scoped `WH_MSGFILTER` hook installed via `RegisterCallback` receive MSGF_MENU messages during `Menu, Show`, and does `SendInput` work from inside the callback? | The fallback transport for in-menu wheel/RButton/PgUp-PgDn behaviors (D2). Also the fallback for P1/P4 failures. |
| p6-tooltip-from-monitor.ahk | Can a NoActivate, click-through tooltip GUI be created/updated from inside a menu-message monitor without dismissing the menu? | Whether the OSD reader announcements can render live during menus (D2), or must be deferred to menu-close. |

Record the six verdicts before starting Phase C — they are inputs to the C keep-vs-delete
list and to the D1/D2 designs. While testing p4, also note whether the wheel highlight
moves (SendInput from a hotkey during the loop) — that is the load-bearing part.
