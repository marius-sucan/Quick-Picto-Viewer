# lib/msgbox2.ahk bug audit — 2026-09-05

Branch `interface-thread-merge-phase-c` @ 50f4d3d. Static analysis only (nothing was run on
Windows). Interpreter claims were checked against the cached AutoHotkey v1.1 sources
(`script_gui.cpp`, `script.cpp`, `script2.cpp`, `application.cpp`, `window.cpp`). Line numbers
refer to `lib/msgbox2.ahk` unless a file is named.

## Confirmed defects, most severe first

### 1. Escape, the ✗ button and Alt+F4 return STALE or blank `.check` / `.list` / `.edit`, and one caller reads that as "do not ask again"
`WinMsgBoxGuiClose:` / `WinMsgBoxGuiEscape:` (quick-picto-viewer.ahk:33274-33279) run
`KillMsgbox2Win()` and then `Gui, WinMsgBox: Destroy` *before* `MsgBox2()` resumes from
`InputHook.Wait()`. `Gui, WinMsgBox: Default` (:450) then installs a windowless dummy
(script_gui.cpp:214 `GUI_CMD_DEFAULT`), `Line::GuiControlGet` resolves it through
`GuiDefaultWindowValid()` → `ValidGui()` (`!mHwnd` → NULL) and bails with
`SetErrorLevelOrThrow()` *before* touching the output variable. So the four `GuiControlGet`
at :451-454 leave `UsrCheckBoxu` / `DropListuChoice` / `2ndDropListuChoice` / `EditUserMsg`
exactly as the previous dialog left them — the last ticked state of an earlier box, or `""`
if the earlier box had no such control (a missing control does blank the variable, :1476
`output_var.Assign()`). :60 declares the four as globals and never resets them.
Escape takes this path in practice: the InputHook callback sets `win_close_Escape` and stops
the hook, but the still-queued WM_KEYDOWN is retrieved inside `Sleep, 1` (:449) — MsgSleep
uses GetMessage for a positive sleep and keeps looping after each message — `IsDialogMessage`
turns it into WM_COMMAND/IDCANCEL, the GuiEscape thread launches and destroys the GUI before
:450.
Consequence: quick-picto-viewer.ahk:77867 `noPrompting := msgResult.check` after the
"Cloner effects" box (it has the "&Do not prompt me again" checkbox) → stale or `""`;
:77864 `(noPrompting=0)` is a string comparison that is false for `""` and for a stale `1`,
so dismissing that box with ✗/Escape usually suppresses it for the rest of the session.
Other unguarded stores: :64944 (`noAsking`, compared to 1 → harmless), :43349
(`useLastOption`).
Related hardening: :349 `Checked%checkBoxState%` renders a blank state as CHECKED (bare
`Checked`), so any persisted blank flag fed back in pre-ticks the box.
**Fix:** reset the four globals at the top of `MsgBox2()` (next to :70) so a failed read
cannot return another dialog's answer, normalise `r.check` to 0/1 at :459, and/or read the
controls inside `KillMsgbox2Win()` before the labels destroy the window; `Checked`
(checkBoxState=1 ? 1 : 0) at :349. (`(UsrCheckBoxu=1) ? 1 : 0` alone is not enough — it
would pass a stale 1 through.)

### 2. Long messages come out about twice as wide as intended — the narrowing rule never fires
`GetMsgDimensions()` :570 `maxLineLength := max(maxLineLength, StrLen(A_LoopField))` starts
from an unset local. `BIF_MinMax` (script2.cpp:16456) returns `""` when any argument is
non-numeric, so `maxLineLength` stays blank for the whole loop and :581's
`maxLineLength>118` is never true; the `r.w := r.w//2` block (:581-585) is dead. A wide
paragraph therefore stays at `ctlSizeW//1.7` (~56 % of the work area, e.g. ~1120 px on a
1920 px screen) instead of being halved into a taller block. **Fix:** `maxLineLength := 0`
before the loop.

### 3. The second list never gets its options: `%2ndmultisel%` (:381) is never assigned
Only `multiSel` exists (:351). With `2ndDropListMode=2` the second ListBox has no
`gMsgBox2ListBoxEvent` (double-click does not accept the dialog, unlike the first list); with
mode 3 it is not multi-select. Both live callers use mode 2: `PanelOfferAlphaMaskMerger()`
(:4119) and `PanelAutoSelectDupes()` (:46446). **Fix:** derive a second variable from
`2ndDropListMode` the same way :351 does.

### 4. The keystroke hook ends itself after ~1023 characters and closes the box with a blank answer
`InputHook("V")` (:443) has no `L` option, so it keeps the InputHook default length limit:
upstream v1.1 `hook.h:169` `#define INPUTHOOK_BUFFER_SIZE 1024` and `:231`
`BufferLengthMax(INPUTHOOK_BUFFER_SIZE - 1)` = 1023 (the legacy `Input` command overrides it
to 16383 at script2.cpp:1481). Reaching it ends the hook with EndReason `Max`
(script2.cpp:1951 `INPUT_LIMIT_REACHED`). The hook is
system-wide and visible, so ~1000 characters typed *anywhere* (another application, while a
QPV prompt is left open) end it with EndReason `Max`; `Wait()` returns, MsgBox2 destroys the
dialog with `r.btn = ""` (treated as cancel by every caller) and `WinActivate` (:469) pulls
focus back to QPV mid-typing. **Fix:** give the hook an explicit large `L` limit, or set
`OnEnd` and restart the hook when `EndReason = "Max"` while `MsgBox2hwnd` is still alive.

### 5. `2ndlistWidth` accumulates the wrong variable (:153)
`2ndlistWidth := max(listDim.w, listWidth, btnDim.w)` uses `listWidth` (the first list's
final width) instead of `2ndlistWidth`, so the second list is sized by its *last* row, not its
widest. Masked today because both callers pass `setWidth` (600/900), which dominates through
:165/:184. **Fix:** replace `listWidth` with `2ndlistWidth` on :153.

### 6. Icon plumbing (latent; no current caller reaches these branches)
- :322 lacks the comma before `%iconFile%`, so the path becomes part of the option string.
  `ControlParseOptions` raises "Invalid option" (script_gui.cpp:5857 → `return_fail`), the
  `Catch` on :323 swallows it and the icon is dropped. This is the branch for an icon given as
  a bare file path or a raw handle number (`iconNum` blank), i.e. the header's "HBITMAP or
  HICON handle" promise (:36) never works unless the `HBITMAP:`/`HICON:` prefix is used.
- :245 and :249 say `imagres.dll` — the `checkbox` and `cloud` icons never load.
- :313-326: the `Catch wasError` belongs only to the *last* `Try` (script.cpp
  `PreparseBlocks` attaches CATCH to the immediately preceding TRY), and a picture that fails
  to load does not throw anyway (script_gui.cpp:3088 `break`s out leaving an empty control).
  A bad icon is therefore never detected: `iconFile` stays set, `msgW` is reduced by `bH`
  (:174) and the prompt is offset (:329-330) for an icon that is not there.

### 7. The over-tall-message guard is dead three ways (latent)
- :187 `"h" maxH` — `maxH` is undefined in `MsgBox2()`; if the branch ever ran it would emit a
  bare `h`, which `ControlParseOptions` parses as height 0 (script_gui.cpp:5728 `ATOI("")`),
  i.e. an invisible message. It cannot run: `GetMsgDimensions()` already clamps `r.h` to
  `0.9*(rMaxH-2*bH)` (:605-606), so `msgH>rMaxH` is never true.
- :600 `GetStringSize(FaceName, FntSize, ...)` — `FntSize` is a typo for `FontSize`, so
  `dimz` is measured at the *default* GUI size, not the requested one.
- `r.w := ctlSizeW//1.7` (:564) is a float; `Fnt_GetSizeForEdit`'s `if p_MaxW is Integer`
  (Font_Library3.ahk:6966) then fails and the :600 measurement is unwrapped.
Net effect: nothing caps the dialog height. The prompt Edit gets no `h` (:335), AHK sizes it
to the full word-wrapped text (script_gui.cpp:2722 `DT_WORDBREAK`), so a very long message at
a large font can exceed the work area. Current call sites are short enough.

### 8. ClassNN focus targets miscount the checkbox (low)
`GuiControl, Focus, Button1` (:548) and `Button%btnDefault%` (:434) are ClassNN names
(`FindControl` falls through to `ControlExist`, script_gui.cpp:7626). The checkbox (:349) is a
Button-class control created *before* the push buttons, so with a checkbox present `Button1`
is the checkbox: the :548 refocus (prompt → first button on Backspace/Delete/PgUp/PgDn/Enter/
F4) lands on the checkbox. :434 is only reached with a checkbox in the empty-ComboBox edge.
Enter is not affected: `GuiControl Focus` is a plain `SetFocus` (script_gui.cpp:1150), which
does not move the dialog's default button, so Enter still fires the `+Default` button.
**Fix:** focus by hwnd (`+hwnd` per button; `hDefBtn` is already captured and unused).

### 9. `textbtnDefault` is unset for single-button lists and `btnDefault=0` (latent)
It is only assigned inside the `InStr(btnList, "|")` block (:108) and before the
`btnDefault := !btnDefault ? 1 : btnDefault` normalisation (:169). A ListBox double-click
(`usr-dbl-clk`, :456-457) then returns `r.btn = ""`. Also the first loop's `A_Index` counts
blank fields while the second loop (:391) iterates the cleaned list, so a blank field before
the default names the wrong button. No current mode-2 caller has a single button, default 0
or blank fields.

### 10. Nits
- `calcScreenLimits()` :673 compares `prevHwnd` with the raw argument but :726 stores the
  translated one, so `"main"` never hits the 350 ms cache (perf only; MsgBox2 never passes it).
- Dead: `hDefBtn` (:391), `hTemp`, `r.l` (:559), `Sleep, 0` (:506); the "indicator" statics
  (:405/:410) are SS_BITMAP controls whose colouring is commented out — they add 6-10 px under
  destructive/default buttons and show nothing.

## Adjacent (quick-picto-viewer.ahk) — affects the dialog
- :27380 `WinMsgBoxGuiContextMenu` compares `A_GuiControl` with `"vprompt"`; A_GuiControl is
  the variable *name* (`prompt`), so the exclusion never matches.
- `coreDialogConflictsMsgBox()` closes through the same `WinMsgBoxGuiClose:` →
  `KillMsgbox2Win()`, which re-enables/activates `lastMsgBox2win` — the hwnds of the *previous*
  `MsgBox2()`, since only MsgBox2 sets it (:441). Harmless today.
- :96933-96938 `CloseWindow()` destroys the WinMsgBox GUI while its owner is still disabled
  (MsgBox2 re-enables it only when it resumes), the classic momentary-activation glitch.

## Verified not bugs (do not re-report)
- Doubled `` `f `` in list strings is the default-entry marker.
- Enter after clicking the prompt text still fires the `+Default` button (SetFocus does not
  change the dialog default; IsDialogMessage uses DM_GETDEFID).
- `WinExist("ahk_id" MsgBox2hwnd)` without a space parses (window.cpp:1551 `ATOU64`).
- `If StrLen(ownerHwnd)>1` is an expression-If (first token is a call).
- The prompt Edit auto-height wraps correctly (width given → `DT_WORDBREAK`, script_gui.cpp:2722).
- `Critical, % oCritic` round-trips `A_IsCritical` exactly.
- The a11y overlay Text on the prompt (:343) could not be checked visually from here.
