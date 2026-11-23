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

## Round 4

| Probe | Question | Verdict |
|---|---|---|
| p13-wheel-forensics | Wheel via a menu-scoped WH_MOUSE_LL hook (eat + post WM_KEYDOWN) | **PASS** (2026-08-31) — the highlight moves per notch. Bonus finding: menus DO accept queue-posted WM_KEYDOWN, validated for the first time (p10 never got to exercise it). |

## PROBE PROGRAM COMPLETE — final phase-D mechanism table

| Need | Mechanism | Proven by |
|---|---|---|
| Bar hover-switching, Alt-accelerators, F10 | Native submenus attached to the PVbar menu bar (pure Win32) | design + p2 (native bar used) |
| JIT dropdown rebuild | WH_CALLWNDPROC hook on WM_INITMENUPOPUP → `InvokeMenuBar*` builders | **p8 FULL PASS** |
| Reader: highlight tracking + live OSD tip | WH_CALLWNDPROC hook on WM_MENUSELECT → tooltip GUI from the raw callback | **p7 FULL PASS** (alternative: out-of-context SetWinEventHook, **p11 FULL PASS**) |
| In-menu wheel scrolling | Menu-scoped WH_MOUSE_LL hook: eat wheel while a visible own-process #32768 exists, post WM_KEYDOWN Up/Down to the owner | **p13 PASS** |
| In-menu RButton announce, PgUp/PgDn | MSGF_MENU hook sees them (p5 census: keydown 8, rbutton 2); posted key-downs also proven (p13) | p5 + p13 |
| What must NOT be relied on | OnMessage monitors, SetTimer, hotkey subroutines during any same-interpreter menu loop (p1/p2/p3/p4/p6); SendInput from hook callbacks (p5); MSGF_MENU for wheel (p5: wheel 0); WH_GETMESSAGE for wheel (p12) | rounds 1-3 |

Hook lifecycle for the D2 implementation: install CALLWNDPROC + MOUSE_LL on menu open
(WM_ENTERMENULOOP 0x211 arrives via CALLWNDPROC; or install CALLWNDPROC permanently — it
is cheap — and LL only while a menu is up), remove LL at WM_EXITMENULOOP 0x212. Keep the
LL callback minimal (system-wide hook with a latency budget): compare, post, return.
