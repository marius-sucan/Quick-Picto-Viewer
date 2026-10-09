# "Replace similar colours anywhere" speed work, 2026-10-09

Branch `replace-color-speed`, code commit `ae181dc` (on top of `4228663`). qpvmain.dll must be
rebuilt for any of it to take effect. This follows the flood fill work in
`floodfill-speed-2026-10-09.md` and reuses its engine.

## Summary

`ReplaceGivenColor()`, the "Replace similar colors anywhere" option of the flood fill tool, now runs
on the flood fill engine (`FloodJob`). It paints exactly the bytes, and returns exactly the count,
that the shipped function does. Against the shipped function, which already ran on all cores with
OpenMP, it is 2.5–3.4× faster on photos in the default "Grayscale [fast]" mode, 8× on flat colour,
25–30× with CIEDE2000, 150–270× with CIEDE2000 on flat colour, and 3–5× inside a selection; a small
selection on a big image is 20–58× faster. Memory stays small: at most 124 MiB on a 900 MP image.

On huge images the undo level of a replacement now covers only the rectangle of the replaced
pixels: a colour that appears in one 400 × 300 patch of a 900 MP image no longer copies the whole
image before it is replaced.

The flood fill gains two of the new pieces: flat areas are 1.6–2.3× faster and semi-transparent
images with blending 1.3× faster than in the flood fill commit.

## What the shipped function spent its time on

It tested every pixel of the image on its own, with no memory of earlier answers: the selection
test, then the colour test, then for every matching pixel the blend. With CIEDE2000 the colour
test alone was 232 ns per pixel, 5.6 s for 24 MP on one core. A selection was tested pixel by
pixel even where it could not let anything through, so a selection covering 1% of an image cost
almost the full scan.

## What was done

Terms as in the flood fill report; in short: a **word** is 64 pixels of a row handled as one 64-bit
number, the **colour table** remembers each colour's yes/no answer, the **paint memo** remembers
the painted colour for each source colour.

1. **The colour replacement is a mode of the engine** (`FloodParams::replace`): no region is
   walked, every pixel the selection leaves open is tested by the engine's word test and painted
   with its paint code. Rows are shared out to a `std::thread` crew; counts are 64-bit.
2. **Each colour is decided once.** "Grayscale [fast]" gets a dedicated table, see 3; the other
   modes use the colour table.
3. **"Grayscale [fast]" decides by blue ranges.** Its grayscale value only grows with blue, so for
   every (red, green) the blues that match form one range. The ranges are worked out on first use
   (two binary searches each) into a 65 536-entry table, 256 KB in place of the 4 MB colour
   table. Checked against the shipped decision on all 16.7 million colours for ten tolerances.
4. **A word of one colour is decided once** (alpha aside), the whole word at a time. For 24-bit
   images the test is that the word's bytes equal themselves shifted by one pixel.
5. **The paint memo drops itself when it mostly misses.** When more than three in four lookups miss
   (alpha that varies per pixel makes almost every source colour new), each thread paints without
   it. The flood fill's paint uses the same rule.
6. **Selections are tested a word at a time** (boxes, polygons and the SSE2 shape steps of the
   flood fill), and with a selection that is not inverted, rows and columns outside its box are not
   visited at all.
7. **Two steps for huge images.** `FloodFillFindRegion()` now handles the replacement: it counts
   and bounds the matches and keeps a one-bit-per-pixel map of them when it fits the 512 MiB budget
   (112 MiB at 900 MP), so `FloodFillPaintRegion()` paints without testing again. Above the budget it
   marks the rows with matches and tests those rows again. The huge-image flood tool now uses the
   two steps for this option too and records an undo level of the bounds.
8. **For CIEDE2000 the clicked colour keeps its own distance.** The shipped function measured the
   clicked colour like any other; because its L\*a\*b\* is stored as float and the pixel's as
   double, that distance is not 0 but at most 3.5×10⁻⁶ over all colours. It feeds dynamic opacity,
   where it cannot change a painted byte (measured); it is kept anyway, so the values match exactly.

## Measurements

Linux, i7-7700T (4 cores, 8 threads), g++ `-O2 -msse2`; the shipped function compiled with OpenMP as
in the DLL. Best of three runs; every row painted the same bytes and returned the same count as the
shipped function. The shipped function's 8-thread times varied with other load on the machine
across runs (photo grayscale 72–102 ms); the new times varied less (25–29 ms). MSVC inlines
differently, so the DLL build should be re-measured.

**24 MP image (6000 × 4000), ms:**

| Case | Shipped, 8 threads | New, 8 threads | Shipped, 1 thread | New, 1 thread |
|---|---|---|---|---|
| photo, grayscale | 95.0 | 28.5 | 313.2 | 114.1 |
| photo, L\*a\*b grayscale | 111.7 | 33.8 | 382.5 | 128.3 |
| photo, CIEDE2000 | 1412.9 | 49.8 | 5724.9 | 192.8 |
| photo, exact colour (tolerance 0) | 49.2 | 3.8 | 138.6 | 9.7 |
| flat, grayscale | 61.8 | 7.7 | 166.7 | 19.8 |
| flat, CIEDE2000 | 1403.9 | 7.8 | 5597.3 | 20.5 |
| photo, opacity 128 | 151.7 | 50.9 | 566.2 | 157.3 |
| photo, dynamic opacity | 167.3 | 54.2 | 729.5 | 161.7 |
| photo, CIEDE2000 + dynamic opacity | 1595.4 | 85.5 | 6188.7 | 289.8 |
| photo, blend 5 + linear gamma | 157.3 | 50.6 | 508.3 | 160.6 |
| semi-transparent photo, opacity 128 + blend 3 | 190.6 | 142.4 | 616.6 | 494.1 |
| photo, cartoon | 94.3 | 28.4 | 296.5 | 109.5 |
| photo + ellipse selection | 159.8 | 32.3 | 449.5 | 126.8 |
| photo + rotated rectangle selection | 130.8 | 25.5 | 392.3 | 98.1 |
| photo + polygon selection | 99.1 | 19.2 | 298.7 | 74.4 |
| photo + inverted ellipse selection | 117.3 | 29.3 | 339.2 | 112.7 |
| photo + small rectangle selection (1%) | 38.0 | 1.9 | 91.4 | 1.6 |

**900 MP image (30000 × 30000, 24 bpp), noisy grey field with one 400 × 300 patch of a colour
found nowhere else:**

| Case | Shipped | New, one call | New, find + paint | Bounds for undo |
|---|---|---|---|---|
| grayscale | 3.25 s | 1.07 s | 1.07 s, 108 MiB | whole image |
| CIEDE2000 | 58.13 s | 1.10 s | 1.31 s, 111 MiB | whole image |
| opacity 128 | 7.74 s | 1.59 s | 1.67 s, 124 MiB | whole image |
| the patch's colour, exact | 1.82 s | 0.27 s | 0.25 s, 107 MiB | 400 × 300 |

(Grayscale mode matches every colour of the same grey, so its bounds cover the whole field.)

## Verification

Against the shipped code at `c26999f`, sliced unchanged into the g++ harness used for the flood fill:

- 13 000 randomised cases (8 000 flood-fill-weighted, 5 000 replacement-weighted; 4 046 of them
  replacements): image bytes and returned count against the shipped function, the same through
  `FloodFillFindRegion`/`FloodFillPaintRegion` (a third of them on a budget too small for the map,
  so the second test runs), and count and bounds against a per-pixel reference.
- The blue ranges against `decideColorsEqual()` on all 16.7 million colours, ten configurations.
- CIEDE2000 with dynamic opacity on the clicked colour's own distance: 4 000 cases.
- The flood fill checks from its report all pass again (it shares the changed word test and paint).
- AddressSanitizer + UBSan (2 500 cases) and ThreadSanitizer (2 000 cases + 20 large parallel ones):
  no reports.
- The DLL's own `tests/run-tests.sh`, on a copy: the same results as on `c26999f`.
- The AHK script load-checks under Wine with AutoHotkey_H.

## Behaviour and contracts

- Output and the returned count are unchanged. The count is 64-bit inside and clamped to the
  largest int; the shipped OpenMP sum could overflow above 2.1 billion matches.
- `FloodFillFindRegion()` answers the replacement instead of -1. The AHK treats an error or a
  negative answer as "use the one-step call", so an older qpvmain.dll still works.
- When the map of matches does not fit the budget (above about 3.5 GP), paint tests the pixels
  again: between the two calls the image and the selection must not change (AHK only records the
  undo level in between).
- The colour replacement no longer uses OpenMP.

## Tried and rejected

- **Blue ranges looked up through a function call**: exact but slower than the colour table
  (photo grayscale 43 against 32 ms) until the lookup was written into the word loop and the
  helper forced inline (`QPV_FORCEINLINE`, as elsewhere in the per-pixel code).
- **No paint memo at all**: best for the semi-transparent case (127 ms) but slower for every other
  blend (opacity 128: 103 against 52 ms; CIEDE2000 + dynamic opacity: 208 against 76 ms); the
  self-dropping memo gets close to both.

## Known limits

- The semi-transparent photo with blending gains only 1.2–1.4×: nearly every pixel has a colour and
  alpha of its own, so there is nothing to remember, and the blend itself is the cost.
- Not run on Windows: the MSVC build and the huge-image undo through the two steps.

## Next steps

1. Rebuild qpvmain.dll (MSVC) and load the branch's `quick-picto-viewer.ahk` with it.
2. On a huge image: replace a colour that appears only in one area; the undo level must cover
   that area only (the journal shows the time), and undo/redo must restore it.
3. On a normal image: replace a colour with and without a selection, with opacity and blend modes.

The harness is in `.claude/scratch/floodfill-impl-2026-10-09/replace/` (git-excluded):
`bash verify_all.sh` reruns every check.
