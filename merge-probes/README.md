# Merge probes (Phase P)

Probes for the interfaceThread merge (see interface-thread-merge-plan.md). Run on Windows
with **stock AutoHotkey v1.1 (U64)** — NOT AHK_H — because they establish what the merged,
de-H app can rely on. Each shows its verdict in a MsgBox; no files are written.

## Round 1 verdicts (recorded 2026-08-31)

| Probe | Question | Verdict |
|---|---|---|
| p1-menuselect | OnMessage(WM_MENUSELECT) during same-thread `Menu, Show`? | **FAIL** — never fired |
| p2-initmenupopup | OnMessage(WM_INITMENUPOPUP) + JIT rebuild, native Gui menu bar? | **FAIL** — never fired |
| p3-timer-during-menu | SetTimer ticks during the menu loop? | **NO** (as expected) |
| p4-hotkeys-during-menu | Hook-hotkey subroutines run during the loop? SendInput from them? | ambiguous log; no highlight move on wheel, nothing visible on F9 — re-run with the auto-classifying version if needed |
| p5-msgfilter-hook | WH_MSGFILTER callback runs during the loop? | **Reception PASS** — hook saw MSGF_MENU traffic; but SendInput from it moved nothing (wheel-presence in the log unconfirmed — re-run shows counts) |
| p6-tooltip-from-monitor | Tooltip GUI from an OnMessage monitor during menus? | **FAIL** — consistent with p1 |

**The empirical rule these establish:** in a single stock-v1 interpreter, NO AHK
pseudo-thread launches happen while a menu of that same interpreter is being tracked —
OnMessage monitors, timers, and (apparently) hotkey subroutines are all blocked, for
`Menu, Show` popups AND native Gui menu-bar tracking alike. Raw Win32 callbacks (hooks)
DO run during the loop — p5 proved the vehicle. This is exactly why the current app needs
the second ahk-h interpreter for its menu reader; post-merge, all in-menu behavior must
ride raw callbacks. Round 2 below determines which callback can do what.

## Round 2 — run these next

| Probe | Question | Decides |
|---|---|---|
| p7-callwndproc-menuselect | Same-thread WH_CALLWNDPROC hook sees WM_MENUSELECT (a SENT message the MSGFILTER hook cannot see), and can update a tooltip GUI from the raw callback | D2 reader tracking + display. Distinguishes reception-works from GUI-from-callback-works. |
| p8-initmenupopup-hook | AHK `Menu, DeleteAll/Add` executed from the CALLWNDPROC callback at WM_INITMENUPOPUP time | D1 JIT dropdown rebuild. FAIL → eager rebuilds on state change (UpdateMenuBar's hash machinery survives phase C). |
| p9-wheel-rewrite | MSGF_MENU hook rewrites the wheel message in place into WM_KEYDOWN Up/Down | In-menu wheel scrolling, strategy A. Also reports whether wheel traverses MSGF_MENU at all. |
| p10-wheel-eat-post | MSGF_MENU hook eats the wheel and posts WM_KEYDOWN to the owner | Strategy B, if A fails. Both seeing zero wheel messages → WH_GETMESSAGE needed. |
| p11-wineventhook-menu | OUT-OF-CONTEXT SetWinEventHook(EVENT_OBJECT_FOCUS) fires per highlighted menu item, tooltip from that callback | The canonical screen-reader mechanism; fallback for p7's display half. (taskbarInterface already uses SetWinEventHook, so there is in-codebase precedent.) |

Record all verdicts before Phase C — they finalize the D1/D2 design.
