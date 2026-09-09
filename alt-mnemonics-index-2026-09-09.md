# Menu bar Alt mnemonics vs. keyboard shortcuts (2026-09-09)

Request: index the Alt keys in `loadCustomUserKbds()` and use that list in `forbiddenAltKeys()`,
with no hardcoded keys. Branch: `interface-thread-merge-phase-c`, working tree only, no commit.
Nothing here ran on Windows: the AHK code is desk-traced only (see "Verification").

## Why this matters more since the interface merge

`uiWM_KEYDOWN()` handles WM_SYSKEYDOWN before anything else: for every letter the menu bar
claimed as a mnemonic (`menuHotkeys`), it posts `WM_SYSCOMMAND SC_KEYMENU` and swallows the
key. The key never reaches `KeyboardResponder()`, so neither a custom user key nor a default
combo can run on it. `forbiddenAltKeys()` was therefore the only thing keeping bound letters
away from the bar, and it only knew the seven default combos, hardcoded per thumbs/non-thumbs.
A user who bound Alt+F to anything got the File menu instead.

## What changed

1. `loadCustomUserKbds(refreshMenuBar:=0)` (quick-picto-viewer.ahk)
   - New index `userCustomAltKeys` (declared next to `userCustomKeysDefined` in the top Global
     block). Built after the parse loop from the finished `userCustomKeysDefined`, so it says
     exactly what the custom-keys branch of `KeyboardResponder()` does with the key:
     `userCustomAltKeys[context "!" letter]` = 1 (bound to a custom function) or 0 (dead: the
     entry is a `?` / `?_` marker because the user disabled the shortcut or moved the default
     action to another key). Only plain Alt+letter keys are indexed (`i)^\d+![a-z]$`);
     `+!x` / `^!x` are not bar mnemonics.
   - `allowCustomKeys!=1` no longer returns early: both tables are reset and left empty
     (`Loop, Parse` over an empty string runs zero times - verified in the AHK source).
   - `refreshMenuBar=1` triggers `TriggerMenuBarUpdate("forced", A_TickCount)` when the index
     changed (signature compare in a Static), so the underlines follow a save immediately.
     The signature advances only on refresh calls: `writeMainSettingsApp()` reloads from a
     500 ms throttle timer, and if it fired inside a panel's `Sleep, 5` it would otherwise
     record the new index first and the panel's own call would see "unchanged". Cost: the
     first refresh call of a session rebuilds once even if nothing changed.
     Marker shapes the index maps to 0: `?Func` (disabled), `?_Func` / `?_generic` (moved
     default) and `?2` (the panel's "already replaced" value); none is a function name.
     The ten runtime reload sites pass 1 (custom-keys panel flows, `ToggleCustomKBDsMode()`,
     `BtnSavePreferencesClose()`, `updateUIsettings()` tab 4). `readMainSettingsApp()` keeps
     the default: it runs before `BuildGUI()`.
   - Fixed: the guard `StrLen(userCustomKeysDefined[defu, 1])<3` looked up the bare key,
     where nothing is ever stored, so it was always true. Now `c . defu`. Effect: a line that
     moves a function away from its default key no longer overwrites an earlier line that
     binds that same key to another function. Reachable from the panel: bind Alt+E to F2,
     then move F1 (default Alt+E) to Alt+X. Before: Alt+E dead. After: Alt+E runs F2.
2. `forbiddenAltKeys(n, kbdContext:=0)` (lib/module-interface.ahk): no letters. Index lookup
   for the context first; otherwise `testDefaultKbdComboBound("!" n, c)`.
   `BuildMenuBar()` computes the context once with `defineKBDcontexts(-1)` (the id, bypassing
   the 100 ms cache - the bar is built from a timer right after the key that changed the mode).
3. New helpers next to `testCustomKBDcontexts()`:
   - `testKbdComboBound(givenKey, contextID:=0)`: custom entry (any entry claims the key,
     `IsFunc` decides bound/dead), else the default probe.
   - `testDefaultKbdComboBound(givenKey, contextID)`: `processDefaultKbdCombos(key, PVhwnd, 0,
     PVhwnd, 1)` simulacrum, then the same "disabled default" check the real dispatch makes
     (the simulacrum returns before it). Side-effect free: every Else-If condition of the chain
     is a plain compare on givenKey, only the matching branch runs, all 376 assignments are
     arrays, and it returns before dispatching.
4. `uiWM_KEYDOWN()`: only plain Alt+letter is treated as a bar mnemonic now. With Ctrl or
   Shift down the block is skipped and the key takes the normal dispatch path as `^!x` /
   `+!x` (Windows itself never opens a menu on Ctrl+Alt+letter; before this, Ctrl+Alt+F and
   Shift+Alt+F opened File whenever 'f' was claimed, and AltGr+letter on layouts that report
   it as Ctrl+Alt did too). For a plain Alt+letter the bar claimed, `testKbdComboBound("!"
   letter)` runs before the SC_KEYMENU post; a bound key falls through to the dispatch path.
   That check exists because the bar is now built from live state: `thisState` in `UpdateMenuBar()` does not
   cover `openingPanelNow`, `whileLoopExec`, `CurrentSLD` or bitmap validity, all of which zero
   `HKifs()`. A bar built in such a window would claim a letter that is bound once the state
   settles, and without this guard the shortcut would be shadowed until the next rebuild.
   The check never assigns the global `hotkate`: the drain loop treats a set `hotkate` as
   a key-down to dispatch. The Alt+Space block (system menu) has the same rule, by request:
   only plain Alt+Space opens it; Shift+Alt+Space and Ctrl+Alt+Space reach the dispatcher
   as `+!SPACE` / `^!SPACE`, where no default combo exists. The two modifier reads moved
   to the top of the function and feed both blocks and the later `constructKbdKey()` call.

## Behaviour changes (model of BuildMenuBar over the six menu lists, no custom keys)

| State | Forbidden letters now | Bar |
|---|---|---|
| image view, list loaded | a e g p r u y | same as before |
| image view, single image | a e g p r u y | same |
| thumbnails, list loaded | a e g p r u y (was e u; p r y g a unused there) | same |
| editor, live edit panel | e g p y (was all seven; a r u unused there) | same |
| welcome screen | u | `E&dit` -> `&Edit` |
| image view, another panel open | none | `E&dit` -> `&Edit` (reverts when the panel closes) |
| editor, transform panels 24/31 | g p | `E&dit` -> `&Edit` |
| alpha mask painting | e g p y | `A&lpha mask` -> `&Alpha mask` |
| vector editor (`HKifs()`=0 under drawingShapeNow) | none | `E&dit` -> `&Edit` |

In every changed state the letter was a dead key before (its combo is gated off there), so
Alt+E / Alt+A now open the menu, and Alt+D / Alt+L no longer do. The cost is that the Edit
mnemonic differs between modes (D in image view, thumbs and the editor; E on the welcome
screen, in the vector editor and in the transform tool). If stable mnemonics matter more
than a live probe, the probe would have to answer "bound in any state of this mode", which
only a permissive `HKifs()` mode could give; not done.

Semantics chosen for markers: a disabled or moved default is a dead key today; it becomes
claimable by the bar. Disabling the Alt+E properties shortcut makes Alt+E open Edit.

## Sample files through the index (context 2, image view with a list)

- `!f ▪ FuncZ ▪ … ▪ 2 ▪ ^z`: index `2!f=1`, bar `F&ile`, `I&mage` (i taken by File), Alt+F runs FuncZ.
- `!e ▪ ?PanelIMGselProperties ▪ … ▪ 2 ▪ !e`: index `2!e=0`, bar `&Edit`.
- `!x ▪ PanelIMGselProperties ▪ … ▪ 2 ▪ !e`: index `2!x=1, 2!e=0`, bar `&Edit`.
- `!e ▪ FuncQ ▪ … ▪ !k` then `!x ▪ PanelIMGselProperties ▪ … ▪ !e`: index `2!e=1, 2!k=0, 2!x=1` (the guard fix; before it `2!e` became a marker).
- `+!f ▪ FuncZ …`: index empty (bar keeps `&File`; Shift+Alt+F is not a mnemonic and reaches the dispatcher).
- custom keys disabled: index empty, seven default letters forbidden as before.

## Not changed, worth knowing

- Shift+Alt+letter and Ctrl+Alt+letter no longer open a bar menu (see 4). Unbound ones now
  do nothing, as in Windows; before, they opened the menu of any claimed letter.
- `KeyboardResponder()`'s third branch (`invokeGivenMenuBarPopup`, the pre-merge detached
  popup) is reachable again only if the state flips within the 3 ms between the press-time
  check and the dispatch.
- `userCustomAltKeys` is a loaded data table like `userCustomKeysDefined`, not a flag threaded
  through a call chain. If a new global is unwanted, the index can live under a reserved key
  inside `userCustomKeysDefined` (`updateUIKeysListManager()` skips keys with "." at position 2
  and reads `V[4]`, so a nested object there would be ignored).

## Verification

No wine or AHK on this box. Done: brace/paren balance of every touched function, line
endings (main file LF, module CRLF, BOM intact), a Python model of the index builder,
`forbiddenAltKeys()` and the `BuildMenuBar()` mnemonic loop over the six menu lists and the
sample files above, and the AHK source for `Loop, Parse` on an empty string. Not done: any
run. First thing to try on Windows: bind Alt+F to a function, save, watch File become
`F&ile` without a mode switch, press Alt+F; then disable Alt+E and press Alt+E on an image.
