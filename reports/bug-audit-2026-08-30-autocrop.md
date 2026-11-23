# Bug audit — `AutoCropAction()` / `CoreAutoCropAlgo()` / `autoCropAider()`, 2026-08-30

Targeted audit of the auto-crop pipeline, run on master @34ae01f. Line numbers are as of that
commit (the working tree is clean apart from untracked `.md` files).

* `AutoCropAction()` — `quick-picto-viewer.ahk:98248`
* `CoreAutoCropAlgo()` — `quick-picto-viewer.ahk:98324`
* `autoCropAider()` — `QPV DLL source code/qpv-main.cpp:3347`

Callers examined because the defects surface there: `PerformAutoCropViewportMode()` :22610,
`coreAutoCropFileProcessing()` :98525, `batchAutoCropFiles()` :98574, `BTNautoCropRealtime()`
:98781, `partialUpdateUIautoCropParams()` :98147.

**Status: all six findings and minors a, b, c, d, f, g, i, j are FIXED in the working tree.**
Minors **e** (unchecked DLL return value) and **h** (int index arithmetic) were left alone on
purpose. Line numbers throughout are those of 34ae01f, i.e. of the code as it was found — see
"Fixes applied" at the end for what changed, which fixes need a DLL rebuild, and the three
behaviour changes worth knowing about.

Findings are ordered by severity × confidence. **#1 is the highest-confidence** (it is a
regression proven by `git`, not an inference) and **#2 is the highest-severity** (it writes a
degenerate file and reports success).

**Findings 2, 5 and 6 were measured, not reasoned about.** `qpvmain.dll` cannot be built on this
box, so `autoCropAider()` was extracted verbatim into a g++ oracle harness — the grayscale LUT,
both `inRange` overloads, both scan loops, and the `CoreAutoCropAlgo` tail including the
180-degree rotate and the four `-1` retries — and driven over synthetic images.
`calcIMGdimensions()` was re-implemented in Python with AHK's round-half-away-from-zero and swept
over the whole dimension space above the 900x900 threshold. The same oracle settled the `inRange`
overload-resolution question in "Checked and found correct".

That exercise **corrected finding 6**, whose direction of error was inferred backwards on the
first pass: the drift makes the crop too *conservative*, not too aggressive. Anything not marked
as measured is reasoned from the source — the GDI+ claims in particular come from the wrappers in
`lib/Gdip_All.ahk`, not from running GDI+.

---

## 1. The "Cropped area alteration" slider has done nothing since v5.7.9

`CoreAutoCropAlgo()` :98402-98419.

```ahk
   if (X1=-1 && Y1=-1 && X2=-1 && Y2=-1)
   {
      X1 := Y1 := X2 := Y2 := 2
      deviationW := (usrAutoCropDeviationPixels=1) ? usrAutoCropDeviation : Round((Width/100)*usrAutoCropDeviation)
      deviationH := (usrAutoCropDeviationPixels=1) ? usrAutoCropDeviation : Round((Height/100)*usrAutoCropDeviation)
      If (usrAutoCropDeviationSnap=1 && X1>2) || (usrAutoCropDeviationSnap=0)
         X1 -= deviationW
      ...
   } Else
   {
      X2 := Width - X2
      Y2 := Height - Y2
   }
```

The whole deviation block sits **inside the "nothing was detected" branch**. The `Else` branch —
the one every real image takes — applies no deviation at all. So `usrAutoCropDeviation`
(slider `Cropped area alteration`, :98067, range -50..50 / :98003), together with
`usrAutoCropDeviationSnap` and `usrAutoCropDeviationPixels`, is inert for any image where the
scan finds content.

And inside the branch it is self-defeating anyway: `X1` and `Y1` are assigned the literal `2` on
the line directly above the `X1>2` / `Y1>2` tests, so under `usrAutoCropDeviationSnap=1` the
left/top deviation can never apply, while `X2<Width-3` / `Y2<Height-3` are always true.

**This is a regression, introduced in `46df4b8` (v5.7.9, 2022-12-01).** Before that commit the
block ran unconditionally on real coordinates (old `quick-picto-viewer.ahk:73781`, and the
`X1>2` / `X2<Width-3` guards were meaningful because `X1`/`X2` held detected values). The commit
that ported the four scans to the DLL and introduced the `-1` sentinel wrapped the pre-existing
deviation block in the sentinel test instead of leaving it on the shared path.

Repro: open the auto-crop panel, set "Cropped area alteration" to +25 (or -25), press Preview.
The selection box is byte-identical to the one produced at 0.

Fix: move the block out of the branch, onto the shared path. It must run **after** the
`doubleSize` scaling at :98431-98435, not before it as in the pre-5.7.9 code — otherwise the
"px" mode is silently doubled for images over 900x900, and the "%" deviations are computed
against the halved `Width`/`Height`. Something like:

```ahk
   If (doubleSize=1)
   {
      X2 := X2*2, Y2 := Y2*2
      X1 := X1*2, Y1 := Y1*2
   }

   fullW := (doubleSize=1) ? Width*2 : Width
   fullH := (doubleSize=1) ? Height*2 : Height
   deviationW := (usrAutoCropDeviationPixels=1) ? usrAutoCropDeviation : Round((fullW/100)*usrAutoCropDeviation)
   deviationH := (usrAutoCropDeviationPixels=1) ? usrAutoCropDeviation : Round((fullH/100)*usrAutoCropDeviation)
   If (usrAutoCropDeviationSnap=1 && X1>2) || (usrAutoCropDeviationSnap=0)
      X1 -= deviationW
   ... etc, guards now testing real values against fullW / fullH
```

---

## 2. A uniform image is cropped to 1x1 (2x2), and batch mode saves that and calls it a success

`CoreAutoCropAlgo()` :98402-98429, `AutoCropAction()` :98293-98313.

All four coordinates come back `-1` exactly when every scan ran to completion without tripping,
i.e. when the image is uniform within `usrAutoCropColorTolerance`. The branch then sets
`X1 := Y1 := X2 := Y2 := 2`; with the default deviation of 0 nothing moves; :98426-98429 clamps
`X2` and `Y2` up to `3`. The result is a **1x1 box** (2x2 once :98431 doubles it), which
`AutoCropAction()` :98293-98300 clamps and hands to
`Gdip_CloneBmpPargbArea()` :98313.

Consequences by path:

* Viewport (`PerformAutoCropViewportMode()` :22610): the displayed image is replaced by a 1-2 px
  bitmap. It goes through `wrapRecordUndoLevelNow()` :22629 so it is undoable, but it is still a
  silent, complete destruction of the view.
* Batch (`coreAutoCropFileProcessing()` :98525 <- `batchAutoCropFiles()` :98574): the only guard
  is :98544 `If (imgW>oImgW - 1) && (imgH>oImgH - 1) → Return -2`, which catches *no change*, not
  *degenerate*. `1 > oImgW-1` is false, so execution falls through to
  `Gdip_SaveBitmapToFile()` :98560 and the 1x1 image is written. `batchAutoCropFiles()` :98668
  then treats `!r` as success and the run reports "N out of M selected images were automatically
  cropped". When `ResizeUseDestDir=0` and no format conversion is set, the destination is the
  source path, so the original file is replaced by a 1x1 image.

Reachability is not exotic. Any solid-colour placeholder, blank scan or export qualifies — and
so does **any fully transparent PNG**, because `wrapRGBtoGray()` ignores alpha (minor **g**
below) and a GDI+ PARGB source un-premultiplies to (0,0,0), i.e. a perfectly uniform black frame.

Repro (two paths, split by `BTNsaveAutoCroppedFile()` :98452-98456, which routes >1 selected file to
the batch). Make a 512x512 fully transparent PNG, or a solid #808080 one.
* **One file selected** — Auto-crop panel > Save: `PerformAutoCropViewportMode()` runs, the
  viewport image becomes 1x1, and `PanelSaveImg()` :98467 offers to save that.
* **Two or more selected** — Auto-crop panel > Save: `batchAutoCropFiles()` writes each 1x1 file
  (in place, when `ResizeUseDestDir=0` with no format conversion — `destImgPath := imgPath`
  :98648) and reports "N out of N selected images were automatically cropped".

Measured on the oracle — a solid grey-128 512x512 image, defaults (`vTolrc=5`,
`threshold=0.02`, `adaptLevel=3`):

```
A. uniform grey 128   -> [2,2..3,3] = 1x1   (all four sentinels stayed -1)
```

Expected: "found nothing to crop" should yield the full frame — `X1 := Y1 := 0`, `X2 := Width`,
`Y2 := Height` — or abort with the same "change"/skip treatment. Returning a 2 px box is never a
useful answer.

---

## 3. Seven early returns leave the bitmap locked; `trGdip_DisposeImage()` does not unlock it

`CoreAutoCropAlgo()` :98351, :98360, :98364, :98373 (holding lock #1 taken at :98332) and :98386,
:98392, :98396 (holding lock #2 taken at :98377).

```ahk
   If !partialUpdateUIautoCropParams()
      Return "change"
```

None of the seven calls `Gdip_UnlockBits()`. That this is an oversight rather than a convention is
settled by :98344-98348, where the one path that *does* check the DLL return value unlocks before
returning, and by :98443, which unlocks on the success path.

The lock is not released downstream either. `AutoCropAction()` :98277 calls
`trGdip_DisposeImage(pBitmap, 1)` :102139, which does bookkeeping in `createdGDIobjsArray` and
calls `Gdip_DisposeImage()` (`lib/Gdip_All.ahk:4424`) -> `GdipDisposeImage`. Nothing anywhere
tracks or releases an outstanding `GdipBitmapLockBits`.

Cost per hit: `trGdip_LockBits()` :18492 is called with the default `PixelFormat := "0x26200A"`
(32bppARGB) and `LockMode := 3`. `pBitmap` is a clone/resize of the viewport bitmap and is
normally 32bppPARGB (`coreDesiredPixFmt` / `highDesiredPixFmt` = `0xE200B`, :173/:177), so GDI+
must materialise a full W x H x 4 shadow buffer for the lock. A 6000x4000 source is halved to
3000x2000, so each abandoned run strands ~24 MB.

Trigger: move any of the four controls `partialUpdateUIautoCropParams()` :98147 samples while a
preview is computing. AHK g-labels interrupt between lines, so the slider's `UpdateUIautoCropParams`
handler can land between two `DllCall`s; `AutoCropAction()` :98304 itself anticipates runs over
3 s (`If (A_TickCount - startu > 3000) SoundBeep`), so on large images the window is wide. Batch
mode is safe — `batchAutoCropFiles()` :98590 calls `BtnCloseWindow()` first, so `AnyWindowOpen!=17`
and `partialUpdateUIautoCropParams()` short-circuits to 1 at :98149.

Fix: `Gdip_UnlockBits(pBitmap, BitmapData1)` before each of the seven returns (a single
`gotoBail`-style tail, or a flag, would be less fragile than seven copies).

While here: `LockMode := 3` is `Read|Write`, but `autoCropAider()` only reads. Passing `1`
(read-only) drops the ARGB->PARGB write-back conversion on every unlock — two full-image
conversions per run.

---

## 4. The two abort paths show each other's message

`AutoCropAction()` :98278-98292.

```ahk
   If (selCoords="error")
   {
      If (silentMode!=1)
      {
         showTOOLtip("Auto-crop processing aborted by user")
         ...
   } Else If (selCoords="change")
      Return
```

`"error"` is returned for an invalid bitmap :98328, a `LockBits` failure :98334 / :98379, or the
DLL returning 0 :98347. None of those is a user abort, yet all three report "Auto-crop processing
aborted by user".

`"change"` is the one that genuinely *is* user-initiated (the user moved a panel control
mid-run), and it returns silently — so `PerformAutoCropViewportMode()` :22621-22626 logs
`"ERROR. Failed to perform auto-crop for image."` to the journal and beeps 300 Hz.

Each case therefore surfaces the other's wording. What the user actually gets:

| what happened | tooltip | beeps | journal |
|---|---|---|---|
| real failure (`"error"`) | "Auto-crop processing aborted by user" | 300 Hz twice — :98283 and :22624 | "ERROR. Failed to perform auto-crop" |
| user changed a slider (`"change"`) | *(none)* | 300 Hz once — :22624 | "ERROR. Failed to perform auto-crop" |

So a genuine failure is blamed on the user, a genuine user abort is logged as an internal error,
and neither is distinguishable from the other in the journal — which is the one place a
bug report would come from.

There is a third consequence, and it is the one a user would actually notice.
`BTNsaveAutoCroppedFile()` :98465-98467 discards the return value:

```ahk
    PerformAutoCropViewportMode()
    BtnCloseWindow()
    PanelSaveImg()
```

`PerformAutoCropViewportMode()` returns `"fail"` on both abort paths (:22626), but nothing reads
it. The panel closes and the Save dialog opens regardless — offering to save the **uncropped**
image, with nothing on screen to say the crop never happened beyond a beep that has already
stopped. A user who does not have the journal open will save the original believing it was
cropped.

Fix: swap the two messages, and have `BTNsaveAutoCroppedFile()` check the return value and skip
`BtnCloseWindow()` / `PanelSaveImg()` when it is `"fail"`. The batch path is unaffected —
`silentMode=1` there suppresses the tooltip at :98280, and `coreAutoCropFileProcessing()` returns
`-1`, which `batchAutoCropFiles()` :98671 correctly counts as a failure.

---

## 5. The half-size copy is not exactly half, but the coordinates are scaled by exactly 2

`AutoCropAction()` :98254-98258 and `CoreAutoCropAlgo()` :98431-98435.

```ahk
      pBitmap := trGdip_ResizeBitmap(A_ThisFunc, zBitmap, Width//2, Height//2, 1, 2)
```

The `1` is `KeepRatio`, which routes through `calcIMGdimensions()` (`lib/Gdip_All.ahk:9244`).
That function recomputes one dimension from `Round(imgW/imgH, 8)`, so the result is not reliably
`Width//2 x Height//2`. `CoreAutoCropAlgo()` nevertheless multiplies the detected coordinates by
exactly 2.

Worked example — 1001 x 1500: `givenW=500, givenH=750`; `PicRatio=0.66733333 > givenRatio=0.66666667`,
so the `PicRatio>givenRatio` branch gives `ResizedW=500`, `ResizedH=Round(500/0.66733333)=749`.
The real vertical scale is `749/1500 = 0.49933`, so the bottom edge maps to `y*2.00267` while the
code uses `y*2`.

**How often, and how much.** `calcIMGdimensions()` was re-implemented with AHK's
round-half-away-from-zero and swept over every `W` in 901..4000 against every third `H` in the
same range (3,205,400 pairs — the whole region where the 900x900 halving test at :98254 fires):

```
resized dimension drifts below the exact half : 31.3% of all (W,H) pairs
   drift 0 px  ->  68.7%   costs 0 px of extra border
   drift 1 px  ->  29.8%   costs 2 px
   drift 2 px  ->   1.6%   costs 4 px
worst observed: 901x3607 -> 450x1801 (H drifts 2), total leftover 5 px
```

Read the "extra border" column as background the crop leaves behind at the right and bottom edges
only — the top and left are exact, because `X1`/`Y1` map to `2x` and rounding down is always safe
there. It is one-sided, so it also shifts the *centre* of the result.

Separating the two contributions matters: 0-1 px of leftover is unavoidable parity from integer
halving of an odd dimension. **Anything >= 2 px is this bug**, and that is the same 31.3% of the space.
Common camera ratios are safe — 4:3 (4032x3024), 3:2 (3000x2000) and 16:9 (1920x1080) all halve
exactly. It is the odd ratios that lose: cropped, scanned and screenshotted images, e.g.
2560x1707 -> 1279x853 (2 px left on the right edge).

This compounds directly with finding **1**: trimming a couple of stray pixels of border is
precisely what the "Cropped area alteration" slider exists for, and that slider is dead.

Fix: pass `KeepRatio=0` — both arguments are already exact halves, so there is nothing for the
ratio logic to preserve and it can only introduce drift. If `KeepRatio=1` must stay, read the
resulting dimensions back and scale by `origW/pWidth` instead of the hard-coded 2.

Related quality note (not scored): `InterpolationMode=2` is HighQuality bicubic. Bicubic
downscaling rings at the content/background boundary, and the resulting halo reads as content,
which biases the detected edge outward by another pixel or two — in the same direction as the
drift above, never against it. Nearest-neighbour would be a better fit for an edge detector.

---

## 6. The adaptive reference drifts across row/column boundaries and is never re-seeded

`autoCropAider()` :3359-3365, :3381-3387 (row scan), :3421-3422 (column scan).

```cpp
   int clrPrimeA = BitmapData[0];
   int clrPrimeB = BitmapData[1];
   int clrPrimeC = (Height > 1) ? BitmapData[Width] : clrPrimeA;
   ...
   int prevR4 = (prevR1 + prevR2 + prevR3)/3;
```

`prevR4` is seeded **once**, from the three pixels at the top-left corner. In adaptive mode it is
then overwritten as the scan walks (`prevR4 = R1`), and it is **never reset when the inner loop
advances to the next row (:3403-3408) or column (:3438-3443)** — only `ToleranceHits` is. Row
`y+1` therefore begins from whatever grey level the right-hand end of row `y` left behind.

This is a behavioural regression against the pre-`46df4b8` AHK implementation, which recomputed a
per-line reference on every outer iteration from that line's own leading pixels (old
:73707-73711, `vX := 0 ... vX := 2 ... primeR1 := Round((primeR1a + primeR1b)/2)`) and accepted a
pixel if it matched *either* the line seed or the running value — so drift was self-correcting.

**Direction of the error — corrected.** The first pass of this audit reasoned that the drift made
the crop *too aggressive*. The oracle shows the opposite, and the mechanism is worth stating
because it is counter-intuitive. `prevR4` only re-syncs while `d` falls inside
`[vTolrc - adaptLevel, vTolrc + adaptLevel]` — with the defaults, `d` in 2..8. Inside a row that
works: a shallow gradient creeps up to `d=2`, the reference adopts the new value, and the cycle
repeats, so the reference tracks the background. But the wrap from `(Width-1, y)` to `(0, y+1)`
is a jump of the **whole** gradient span at once. That `d` is far outside 2..8, so the reference
can never re-sync — it stays pinned at the right-hand end's brightness for the rest of the scan.
Every subsequent row spends its whole tolerance budget in its first few pixels and trips. `Y1`
lands at 1 and `Y2` at `Height-1`: the vertical crop becomes a **no-op**. Too conservative, not
too aggressive — and the axis that fails is the one whose *inner* loop runs along the gradient.

Measured on the oracle. 512x512, content rectangle [100,80..400,300] (300x220), defaults
`vTolrc=5`, `threshold=0.02`, `adaptLevel=3`. "adaptive" is `AutoCropAdaptiveMode=1`, the
**default** (:248); "plain" is the `aaMode=0` fallback; "per-line seed" is the pre-5.7.9 rule
reinstated inside the current DLL loop.

```
                              adaptive (shipping)   plain (aaMode=0)     per-line seed
B. flat background            300x220  exact        300x220  exact       300x220  exact
C. horizontal-gradient bg     300x510  Y is a no-op 408x512  both fail   300x220  exact
D. vertical-gradient bg       510x220  X is a no-op 512x408  both fail   300x220  exact
E. radial vignette            300x220  exact        512x512  no crop     300x220  exact
```

Two things fall out of that table.

* **Adaptive mode does not deliver what it exists for.** Scenario E is the case it was written
  for and it handles it perfectly. But C and D — a page lit from one side, a scan with a lighting
  falloff, any linear background ramp — are just as common, and there it keeps 510 of 512 rows or
  columns. The `AutoCropAdaptiveMode=1 && Y1=-1` retries at :98353 / :98366 / :98388 / :98398 do
  not help: they only fire when the scan returned `-1`, and a scan that trips at row 1 returns
  `1`, not `-1`. The failure is silent and looks like "auto-crop just doesn't work on this image".
* **The minimal fix is not enough.** Resetting to the corner seed each line (`prevR4 = oprevR4;`,
  which the original write-up suggested as a floor) was measured too: it gives 358x220 on C,
  300x358 on D — one axis fixed, the other still loose — and it *regresses* E from an exact
  300x220 to 325x340. Re-seeding from **that line's own leading pixels**, which is what the code
  did before `46df4b8`, is exact in all four scenarios.

Fix: at the top of each outer iteration, seed `prevR4` from the leading pixels of that row or
column — `BitmapData[0 + y*Width]` and `BitmapData[2 + y*Width]` for `whichLoop==1`,
`BitmapData[x + 0*Width]` and `BitmapData[x + 2*Width]` for `whichLoop==2`, guarding the `2`
against 1- and 2-px dimensions. That also gives the dead `oprevR4` at :3366 an actual use, or
lets it go. Requires a `qpvmain.dll` rebuild.

Caveat on the numbers: the oracle reproduces `autoCropAider()` and the `CoreAutoCropAlgo` tail
exactly, but feeds them synthetic images directly rather than through
`trGdip_ResizeBitmap` + `Gdip_ImageRotateFlip`. The scenarios are all under 900x900, so the
halving path (finding **5**) is not in play and the two do not interact here.

---

## Minor / footnotes

**a.** `CoreAutoCropAlgo()` :98367 passes `"Int", 9` as `aaMode` where the three sibling retries
(:98354, :98389, :98399) pass `"Int", 0`. Harmless — the DLL only ever tests `aaMode==1`
(:3381, :3421) — but it is plainly a typo.

**b.** `autoCropAider()` :3360 reads `BitmapData[1]` with no width guard, while :3361 carefully
guards `BitmapData[Width]` behind `Height > 1`. On a 1x1 bitmap that is a 4-byte read past the
buffer; on a 1xN bitmap it silently samples pixel (0,1) instead of a horizontal neighbour.
`AutoCropAction()` imposes no minimum size, so both are reachable.

**c.** :3356-3357 `if (threshold==0) maxThresholdHitsW = maxThresholdHitsH = 1;` is dead —
`round(Width*0) + 1` is already exactly 1.

**d.** :3366 `oprevR4` is assigned and never read; its only use, :3386, is commented out.

**e.** `CoreAutoCropAlgo()` checks the DLL return value for the first call only (:98344). The other
seven assignments to `r` (:98354, :98362, :98367, :98381, :98389, :98394, :98399) are dead stores.
Harmless today because `autoCropAider()` unconditionally `return 1`s at :3447, but the lone check
implies a contract that is not enforced.

**f.** The DLL takes no `Stride` and hard-codes `x + (y * Width)` (:3377, :3416). This is currently
correct because `trGdip_LockBits()` requests `0x26200A` (32 bpp => stride is `Width*4`), but every
other bitmap entry point in `qpv-main.cpp` takes `Stride`, and here the value is read into a
variable that is only ever printed (:98338). An `If (Stride != Width*4) → bail` on the AHK side
would cost nothing.

**g.** `wrapRGBtoGray(color, 1)` :2903 ignores alpha entirely, so auto-crop cannot recognise a
transparent border as background — it sees the un-premultiplied RGB, which for GDI+ PARGB sources
is (0,0,0). Trimming a transparent margin therefore only works on light images, and fully
transparent images fall into finding **2**.

**h.** `x + (y * Width)` (:3377, :3416) is int arithmetic; the sibling `FillImageHoles()` :3450
uses `INT64 ky = (INT64)y * w`. Unreachable under QPV's 32750 px cap — noted only for consistency.

**i.** `BTNautoCropRealtime(modus:=0)` :98781 guards on `modus!="timer"` :98786, but no caller
passes `"timer"` — :90471, :98128 and :98134 are the only entry points. Vestigial.

**j.** Adjacent, just outside the three functions: `coreAutoCropFileProcessing()` :98545 returns
`-2` without disposing `kBitmap`, leaking one bitmap per "nothing to crop" file; and
`batchAutoCropFiles()` :98671 counts that `-2` as `failedFiles++`, so a batch over already-cropped
images reports every one of them as an error.

---

## Checked and found correct (so they are not re-reported later)

* **The 180-degree coordinate conversion.** `X2 := Width - X2` / `Y2 := Height - Y2` (:98417-98418)
  is exact, not off by one. Rotated column `j` is original column `Width-1-j`; if columns `0..x2r-1`
  of the rotated image are background, the first content column from the right is `Width-1-x2r`,
  and the exclusive right bound is `Width-x2r`. Same for the vertical axis.
* **Partial `-1`s** are handled acceptably. `X1=-1` is not `> Width-2`, so it survives :98422 and
  `clampInRange(-1, 0, Width-1)` :98297 pulls it to 0. `X2=-1` becomes `Width+1` at :98417, is not
  `< 3`, and `clampInRange(Width+1, xa+1, Width)` :98299 pulls it to `Width`. Both are the right
  answers.
* **`whichLoop==2` indexing** uses `x + (y * Width)` :3416, not the commented-out
  `x * Height + y` :3417. Correct row-major access for a column walk.
* **The two hit caps are not swapped.** The row scan (`whichLoop==1`, inner loop over `Width`) uses
  `maxThresholdHitsW`; the column scan (`whichLoop==2`, inner loop over `Height`) uses
  `maxThresholdHitsH`.
* **`Gdip_ImageRotateFlip(pBitmap, 2)`** :98376 is `Rotate180FlipNone`, so `Width`/`Height` stay
  valid for the second `LockBits` at :98377.
* **`AutoCropAction()` clamps against the original dimensions**, read at :98253 before the halving,
  and crops from `zBitmap` (:98313), not from the halved `pBitmap`. Correct.
* **The `doubleSize` doubling never cuts content.** The inclusive top-left maps to `2x` (the true
  edge is at `2x` or `2x+1`), and the exclusive bottom-right to `2*x2`, which is >= the true bound.
  Only background survives — see finding **5** for how much.
* **`selCoords="error"` against an AHK array is safe.** AHK v1.1 stringifies an object token to `""`
  in a comparison, so `[x1,y1,x2,y2] = "error"` is simply false; the object path is not
  mis-detected as an error.
* **`inRange(d - adaptLevel, d + adaptLevel, vTolrc)`** :3383 resolves to the **int** overload
  (:82), not the float one (:78) — verified with a g++ oracle: `(int, int, double)` beats the float
  overload on arguments 1 and 2 and ties on 3. `vTolrc` is therefore truncated. Harmless in
  practice: both sliders are integer (`usrAutoCropColorTolerance` 0..254 :98061,
  `usrAutoCropErrThreshold` 0..99 :98065), so `vTolrc` never has a fractional part.
* **`partialUpdateUIautoCropParams()`'s static `prevp`** is primed by the deliberately unchecked
  call at :98336, so the first real check at :98350 cannot spuriously report a change on the very
  first run of a session.
* **`GdipCloneImage` aliasing** is ruled out empirically: if `trGdip_CloneBitmap()` :101989 shared
  pixels with the source, `Gdip_ImageRotateFlip(pBitmap, 2)` :98376 would flip the user's live
  image on every single preview.
* **Super-global scope trap:** every variable the three functions touch (`msgDisplayTime`,
  `VPselRotation`, `innerSelectionCavityX/Y`, `EllipseSelectMode`, `imgSelX1/Y1/X2/Y2`,
  `AutoCropAdaptiveMode`, `AutoCropStrongAdaptiveMode`, `usrAutoCropDeviation*`,
  `usrAutoCropColorTolerance`, `usrAutoCropErrThreshold`, `coreDesiredPixFmt`) is declared in one
  of the five top-level `Global` blocks (:94, :205, :257, :454, :485). No dead per-function locals.
  Note the blocks continue across blank and comment lines, so any audit script must not stop at
  the first blank line (:204, :224, :256).
* **`silentMode!=1` :98280 vs `silentMode=0` :98249/:98267/:98302** is an inconsistency with no
  effect — the only values ever passed are 0 (:22620, :98802) and 1 (:98667).


---

## Fixes applied

Working-tree changes only, not committed. **Fixes 6, b, c, d and g are in `qpvmain.dll` and do
nothing until the DLL is rebuilt on Windows.** Everything else is AHK and is live immediately.

### `QPV DLL source code/qpv-main.cpp` — `autoCropAider()`

| # | change |
|---|---|
| 6 | In adaptive mode the reference is re-seeded at the top of every outer iteration from that line's own leading pixels — `(0,y)`/`(2,y)` for the row scan, `(x,0)`/`(x,2)` for the column scan. **The re-seed is scoped to `aaMode==1`** — re-seeding the `aaMode=0` fallback as well was measured and buys nothing, so its reference handling is unchanged. Note that fix **g** below applies to *both* modes, so the fallback is not byte-identical for images that carry an alpha channel; for opaque images both modes are unchanged. |
| b | `clrPrimeB` is now `(Width > 1) ? BitmapData[1] : clrPrimeA`, matching the guard `clrPrimeC` already had. |
| c | The dead `if (threshold==0)` line is gone. |
| d | `oprevR4` and its commented-out use are gone; the per-line re-seed replaced what it was there for. |
| g | New `acReadPixel()` / `acDelta()` helpers give the scan an alpha-aware metric: `max(|Δalpha|, |Δluma| * min(alpha) / 255)`. Two transparent pixels now read as identical whatever their RGB, and a transparent pixel is never mistaken for an opaque black one. For opaque pixels the weight is 255 and the arithmetic reduces **exactly** to the old luma difference, so images with no alpha are unaffected. |

The new seed indices are guarded for narrow images (`seedStepW = (Width > 2) ? 2 : Width - 1`,
and likewise for height), so 1- and 2-px dimensions stay in bounds.

### `quick-picto-viewer.ahk`

| # | change |
|---|---|
| 1 | The deviation block moved out of the `-1` branch onto the shared path, **after** the `doubleSize` scaling, computing `deviationW`/`deviationH` from new `fullW`/`fullH` and testing its snap guards against those. The "px" mode is therefore no longer doubled on images over 900x900, and the "%" mode no longer measures against the halved copy. |
| 2 | `CoreAutoCropAlgo()` returns the new sentinel `"nocrop"` when all four scans come back `-1`; `AutoCropAction()` turns that into the **entire frame** (`0, 0, Width, Height` in original coordinates, so the `doubleSize` parity problem cannot bite) and shows a tooltip saying there was nothing to trim. |
| 3 | All seven `Return "change"` sites now `Gdip_UnlockBits()` first, and the success path unlocks before the arithmetic tail instead of after it, so every exit from the function is balanced. Both locks changed from `LockMode 3` (Read/Write) to `1` (Read), dropping a full-image write-back conversion per unlock. |
| 4 | The two messages are swapped — a genuine failure now says "Auto-crop failed to process the image", a user-initiated abort says "Auto-crop processing aborted by user". `AutoCropAction()` propagates `"change"`; `PerformAutoCropViewportMode()` distinguishes `"noop"` (could not start) / `"abort"` (user changed the parameters, no longer journalled as an ERROR) / `"fail"`; and `BTNsaveAutoCroppedFile()` checks the result, so the panel no longer closes and offers the **uncropped** image as though it had been cropped. `"noop"` — the only case with no message of its own — gets one there. |
| 5 | `trGdip_ResizeBitmap(..., Width//2, Height//2, 0, 2)` — `KeepRatio` 1 → 0, so the half-size copy is exactly half and the unconditional `*2` is exact. |
| a | `"Int", 9` → `"Int", 0` on the X1 retry, matching its three siblings. |
| f | After both `LockBits` calls, `If (Stride != Width*4)` journals and bails. `autoCropAider()` indexes `[x + y*Width]` with no stride of its own, and `Gdip_All.ahk`'s own comment notes a stride can be padded or negative. |
| i | `BTNautoCropRealtime(modus:=0)` → `BTNautoCropRealtime()`; the `modus!="timer"` guard no caller could ever trigger is gone. |
| j | `coreAutoCropFileProcessing()` disposes `kBitmap` before `Return -2`, and `batchAutoCropFiles()` counts `-2` as `skippedFiles++` rather than `failedFiles++`, so a batch over already-tight images no longer reports every one of them as an error. |

### Behaviour changes worth knowing about

These are intentional and will look like regressions to anyone who tuned around the old code.

1. **Adaptive crops change on graded backgrounds.** Fix 6 makes `AutoCropAdaptiveMode=1` actually
   work on linear ramps, where it previously kept 510 of 512 rows. Anyone who compensated by
   lowering the tolerance or switching adaptive off will now get a *tighter* crop than before.
2. **A uniform image is no longer destroyed — and no longer counted as cropped.** Batch runs over
   solid-colour or fully transparent files now report them under "Skipped files" instead of
   silently writing a 1x1 image and counting it a success.
3. **The deviation slider does something again.** Any saved `usrAutoCropDeviation` other than 0
   has been inert since v5.7.9 and takes effect the moment this build runs. At the extreme end
   of its range a large negative value can shrink a small detected box past nothing; the
   pre-existing `If (X2 < X1 - 2)` guard clamps that to a minimal box rather than inverting it,
   which is what the code did before v5.7.9 too.

### Verification

The DLL cannot be built here, so the patched `autoCropAider()` was **extracted verbatim from the
edited file** into the g++ oracle and re-run under ASan/UBSan: all eight scenarios exact
(flat, horizontal ramp, vertical ramp, vignette, content flush left, content flush top, noisy
background, uniform → nocrop), plus a transparent-border/near-black-content case that the old
luma-only metric could not see, and 1x1 / 1xN / Nx1 / 2x2 inputs with no out-of-bounds read.
Before choosing the re-seed rule, a sweep over adaptLevel 1..6 x tolerance 1..40 x threshold
{0, .005, .02, .10} x 5 backgrounds gave **2350 strict improvements and 0 regressions**.

`QPV DLL source code/tests/run-tests.sh` was run against the patched source and against the
unpatched original, and the two outputs are identical apart from two nondeterministic counters
(a scheduling step count and a work-stealing hand-off tally). The failure set is unchanged: the
same five WIC-to-GDI+ checks in the pixel collector that have failed on master since before
2026-08-20. The two tracked files the harness consumes were restored afterwards.

The AHK tail was modelled separately to confirm the deviation now moves the box in both px and %
modes, is not doubled on a `doubleSize` image, that a uniform image yields the full frame in both
size regimes, and that partial `-1` sentinels still clamp sanely. Brace balance across the file
is unchanged, and the UTF-8 BOM and LF line endings are preserved.
