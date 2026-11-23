# Did de84c3d ("clean-ups") break anything?

Scope: `de84c3d` touches one file, `quick-picto-viewer.ahk` (+104 / -508).

## Method

Stripped every full-line comment and blank line from `HEAD~1` and `HEAD`, then diffed
the remainder. 122 diff hunks collapse to **7 real code changes**. Everything else is
comment rewording or comments moved from above a function definition to inside its body.

Structural checks: brace balance unchanged (delta 2 in both, from braces inside strings);
exactly one function definition disappeared (`applyAudioVolumeNow`), and it is referenced
nowhere in the repo, so nothing dangles and the script still parses.

The one way that method could lie is an AHK continuation section: inside `(` ... `)` a line
beginning with `;` is string *data*, not a comment, so stripping it would silently change a
runtime string while the code-only diff stayed clean. `quick-picto-viewer.ahk` contains no
continuation sections at all (0 hits for a line opening `(` without closing it, in both the
old and the new file), so the stripping is exact and the neutrality claim below holds.

## Two real regressions

### 1. Seen-images MONTHS chart can no longer report gaps  (`PlotSeenMonthsStatsNow`)

Removed:

```ahk
      If (nYear thisM>=202004)
         dataSkipped[dateu] := 1
```

That was the only statement the calendar walk loop produced. The loop is now dead: it
still steps month by month from `startPeriod` to `endPeriod` (up to a 2500 ms budget) and
produces nothing.

`dataSkipped` is now only written by the second loop, `dataSkipped[oindexu] := valu ? 0 : 1`,
which visits only months that already have a list-view row. `LViewMetaM` is filled from
`entriesM`, whose values are accumulated counts >= 1, so `valu` is never falsy and every
entry is set to 0. Therefore `countSkipped` is always 0 and

```ahk
   lacking := (countSkipped>0) ? groupDigits(countSkipped) " months lack data." : ""
```

is always blank. "N months lack data." is unreachable.

This is the same defect the 2026-08-27 audit recorded for the Days chart, and that the
immediately preceding commit 66a367a fixed there. `PlotSeenDaysStatsNow` still has its
`realDay` guard and its seeding — Days is fine; only Months lost it.

Note: the removed lines had no adjacent comments, so this was not comment collateral.
If the `>=202004` floor was the thing being rejected (66a367a's message calls it out as
able to undercount gaps before April 2020), the fix is to seed unconditionally, the way
Days now does, not to drop the seeding — and the now-dead walk loop should go with it.

### 2. Audio volume slider no longer applies while dragging  (`PanelPreferencesWindow`)

`applyAudioVolumeNow()` was deleted and the slider reverted to the inert `dummy` callback:

```ahk
-    GuiAddSlider("mediaSNDvolume", 1,100, 50, "QPV audio volume", "applyAudioVolumeNow", ...)
+    GuiAddSlider("mediaSNDvolume", 1,100, 50, "QPV audio volume", "dummy", ...)
```

This reverts half of 66a367a. The other half survived, and the save/close path was traced
end to end to confirm it: closing the Preferences panel runs
`If (AnyWindowOpen=14) BtnSavePreferencesClose()` (line ~97289) which calls
`updateUIsettings()`, whose `If (AnyWindowOpen!=14) Return` guard therefore passes, and
`SetVolume(mediaSNDvolume)` now sits outside the `CurrentPanelTab=4` branch (line 58317)
so it runs whatever tab is showing.

So this is **not** the full 2026-08-27 audit defect returning. The volume still applies when
Preferences is saved or closed. What is lost is only the live feedback: dragging the knob no
longer changes what you hear until the panel is closed.

Not a crash: `dummy()` exists in both `quick-picto-viewer.ahk:73679` and
`lib/module-interface.ahk:2393`.

## One cosmetic wart

`importSLDBintoSLDB()` version-mismatch message was rewritten:

- `appTitle` ("Quick Picto Viewer") replaced by a hardcoded "QPV".
- The parenthesis now spans the inserted newline, so it renders as
  `...different version of QPV (v3.` / `This QPV instance is v4).`

## The other four changes are behaviour-neutral

- `SQLstmtFinalize/Step/BindInt/BindDouble/BindText`: `Return X` rewritten as
  `rr := X` + `Return rr`. These functions are assume-local (no `Global` line) and `rr`
  is not a super-global (absent from every top-level `Global` block), so it is a fresh
  local each call. The `bind_text16` DllCall kept identical arguments, just un-wrapped
  from its line continuation onto one line.
- `trenchSize := maxList//systemCores` swapped with `r := 0` — no dependency either way.
- `Static  SQLa` -> `Static SQLa` (whitespace).
- `showTOOLtip("Merging databases contents...")`, `Return histoObj`, and the
  `customShapePoints` / `symMode` pair moved relative to *comments only*; with comments
  stripped their order is unchanged.

## Documentation lost

Several comment blocks recording measured rationale were deleted, notably the
`SQLpixelsMissingClause()` note explaining why it is `NOT EXISTS` and not `NOT IN`
(refill measured 6.5 ms -> 63 ms as the table filled; 1.47x over a 20k-image run,
`tests/pool_latency.cpp`). No behaviour change, but that is the note that stops the
query being "simplified" back into the slow form.

---

# Fix applied to `PlotSeenMonthsStatsNow()`

Constraint from the user: **do not re-add the two removed lines.** So the gap count is no
longer produced by seeding a hashtable from a calendar walk — it is computed arithmetically
and the walk is deleted outright.

## Why arithmetic is exact here

`LViewMetaM` is built from `entriesM`, keyed `"z" . yyyyMM` and given a key only when a month
has images (the source query is `SELECT imgViewDate, COUNT(*) ... GROUP BY imgViewDate`, so
every count is >= 1). Its row count therefore *is* the number of months that carry data:

```
  months lacking data = (months in the range) - (months with data)
                      = monthsRange - counter
```

Months are uniform, so the range is `(eYear - nYear)*12 + (eMon - nMon) + 1`. No walk needed.
`PlotSeenDaysStatsNow()` keeps its walk because days are **not** uniform — that asymmetry is
the reason the two functions now differ, and it is deliberate.

## Equivalent to the mechanism that was deleted

The old walk seeded the **open** interval `(startPeriod, endPeriod)`: it increments the month
before forming `dateu` and breaks before seeding `endPeriod`. Both endpoints are list-view
rows, so they cancel out of the subtraction:

```
  old countSkipped = (span - 2) - (totalz - 2) = span - totalz
```

Verified with a Python oracle (`$CLAUDE_JOB_DIR/tmp/oracle.py`) that reimplements the deleted
loop verbatim: 35,010 start/end month pairs across 1998-2030 confirm the walk seeds exactly
the open interval, and 20,000 random datasets confirm the old tally equals `span - totalz`.

## The five edits

1. Calendar walk loop deleted (dead since `de84c3d`, and it burned up to 2500 ms per redraw).
2. `dataSkipped := new hashtable()` deleted.
3. `dataSkipped[oindexu] := valu ? 0 : 1` deleted — it could only ever assign 0.
4. The `For Key, Value in dataSkipped` tally replaced by
   `countSkipped := (monthsRange>counter) ? monthsRange - counter : 0`.
5. `counter := 1` -> `counter := 0`, with `counter++` moved ahead of the two array writes,
   exactly as `PlotSeenDaysStatsNow()` does it.

Net: 14 insertions, 29 deletions.

## Why edit 5 was necessary, not scope creep

`counter` started at 1 and was incremented *after* `dataArray[counter]` / `namesLabel[counter]`,
so it ended at N+1. It feeds both `"Total: " groupDigits(counter) " months."` and
`Floor(totalu/counter)`. Left alone it would have printed "Total: 25 months. 3 months lack
data." over a 27-month span holding 24 months of data — Total + lacking has to equal the span
or the new figure reads as broken. Fixing it also un-breaks the average, which was dividing by
N+1. `dataArray` / `namesLabel` still get indices 1..N, unchanged.

## Numbers that will look different

- **Total** and **Average** each change: they were off by one before, in the direction of
  over-counting months and under-stating the average.
- **`If (counter>20)`** picks the BarChart style; it was effectively N>=20 and is now N>=21.
  A one-row cosmetic shift at exactly 20 months, and it now matches Days.
- **Old datasets will report more lacking months than they did before `de84c3d`**, because the
  `>=202004` floor is gone. On a 2016-01..2024-06 span that floor was hiding 50 of 100 gaps.
  That is the same call 66a367a made for the Days chart, not a new defect.

## Verification

- Comment-strip diff of the working tree against the pre-fix file shows exactly these five
  changes and nothing else; brace balance unchanged; still zero continuation sections.
- `eYear`, `eMon`, `monthsRange` are new identifiers used only in the four added lines, and
  none of them (nor `countSkipped`, `dataSkipped`, `totalz`) is a super-global — checked
  against every top-level `Global` block, since the function is assume-local and a collision
  would have written through to a global.
- No dangling references left: `startZeit`, `thisM`, `dateu`, `dataSkipped` are gone from this
  function; `dataSkipped` survives only in `PlotSeenDaysStatsNow()`, untouched.
- `$CLAUDE_JOB_DIR/tmp/sim.py` simulates the fixed function: a hand dataset with known gaps
  (14-month span, 5 months of data -> 9 lacking), 50,000 random datasets asserting
  `Total + lacking == span` and a 1-based chart array of length N, and a contiguous 12-month
  set confirming the note is suppressed when nothing is missing.
- Not run in AutoHotkey — this box is Linux, so the AHK edits are verified by oracle and by
  structural diff, not by executing the app.
