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

## Round 2 verdicts (recorded 2026-08-31, second run)

| Probe | Question | Verdict |
|---|---|---|
| p4 (re-run) | Hook-hotkey subroutines during the loop? | **FAIL** — no response on wheel/F9/right-click. The reader `#If` block is definitively non-viable post-merge. |
| p5 (re-run) | MSGF_MENU traffic census | Reception works; **wheel: 0, keydown: 8, rbutton: 2** — wheel does NOT traverse MSGF_MENU (explains p9/p10). |
| p7-callwndproc-menuselect | WH_CALLWNDPROC sees WM_MENUSELECT + tooltip GUI from the raw callback | **FULL PASS** — tip followed mouse hover AND arrow-key highlight changes. **D2 tracking + display mechanism.** |
| p8-initmenupopup-hook | AHK `Menu, DeleteAll/Add` from the callback at WM_INITMENUPOPUP time | **FULL PASS** — never showed the placeholder. **D1 JIT rebuild mechanism.** |
| p9-wheel-rewrite | Wheel via MSGF_MENU rewrite | FAIL (no wheel messages to rewrite — see p5) |
| p10-wheel-eat-post | Wheel via MSGF_MENU eat+post | FAIL (same cause) |
| p11-wineventhook-menu | Out-of-context SetWinEventHook(EVENT_OBJECT_FOCUS) + tooltip | **FULL PASS** — available as alternative/fallback to p7. |

**Design consequence:** D1/D2 are settled on two same-thread hooks — `WH_CALLWNDPROC`
(WM_MENUSELECT tracking/announcements + WM_INITMENUPOPUP JIT rebuild, both proven) and a
queue-side hook for in-menu input shaping (RButton and keydowns provably traverse
MSGF_MENU; wheel does not, hence round 3).

## Round 3

| Probe | Question | Verdict |
|---|---|---|
| p12-getmessage-wheel | WH_GETMESSAGE rewrite of wheel → WM_KEYDOWN | **FAIL** (2026-08-31) |

## Round 4 — the final wheel probe

| Probe | Question | Decides |
|---|---|---|
| p13-wheel-forensics | Taps ALL remaining layers at once — queue (PM_REMOVE + peeks), messages SENT to this thread's windows, and a low-level WH_MOUSE_LL hook that eats the wheel while our menu is visible and posts WM_KEYDOWN Up/Down | The definitive answer in one run: the counters show where wheel input goes (or that nothing above the hardware layer ever sees it), and the LL tap tests the last viable mechanism (a menu-scoped low-level hook). If the LL tap sees wheel but the highlight still does not move, menus ignore queue-posted key-downs and the in-menu wheel feature is dropped for good (accepted degradation - native Win10 menus wheel-scroll on overflow regardless). |
