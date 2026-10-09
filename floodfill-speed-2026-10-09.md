# Flood fill speed work, 2026-10-09

Branch `floodfill-speed`, code commit `1a73504` (on top of `c26999f`). qpvmain.dll must be rebuilt
for any of it to take effect.

## Summary

`FloodFill8Stack()` (the tolerance fill) and `FloodFillScanlineStack()` (the exact fill) are
replaced by one engine, `FloodJob` in `qpv-main.cpp`. It paints exactly the bytes the shipped
fills paint, but 4–24× faster on typical fills with all cores, and 1.5–17× on one core for all
but two kinds of fill (see Known limits). A 900-megapixel fill that took 9.6 s takes 0.87 s; CIEDE2000 with blending went from 51.6 s
to 1.8 s.

Everything a fill allocates stays under **512 MiB on any image size**, including the
13.6-gigapixel FreeImage ceiling. On a 900 MP image the peak is 216–319 MiB. The shipped
tolerance fill used 108 MiB on a flat region, but 1259 MiB on a fragmented one, because of an
unbounded span stack.

Huge images also stop copying the whole image for undo before every fill: the undo level now
holds only the rectangle the fill changes.

## Terms

- **Span**: a horizontal run of filled pixels in one row; the walk keeps a stack of spans whose
  neighbouring rows still need probing.
- **Word**: 64 pixels of a row handled as one 64-bit number, one bit per pixel.
- **Visited map (F)**: one bit per pixel, set once the pixel belongs to the region.
- **Test cache (M, K)**: M holds each word's test result (colour matches and the selection allows
  it); K records which words of M are filled in. Each pixel's test therefore runs once.
- **Colour table**: two bits for every one of the 16.7 million RGB colours: not tested yet,
  matches, does not match.
- **Paint memo**: per thread, the painted colour for each source colour already seen, so the
  blend runs once per colour instead of once per pixel.
- **Strip**: a column of the image (a multiple of 64 pixels wide) that a span may not cross, so
  several threads can work on one wide row.
- **Band**: a block of rows whose maps fit the budget; only used when the whole image's maps do not.
- **Budget**: `floodFillBudget`, 512 MiB, the ceiling on everything a fill allocates.

## The options from the 2026-10-08 study

| # | Option | Status |
|---|---|---|
| 1 | Decide each colour once (full colour table) | done |
| 2 | Paint memo; store CIEDE2000 distance per colour for dynamic opacity | done |
| 3 | Word engine: 64 pixels per step, each pixel tested once, colour before selection | done |
| 4 | Find first, paint afterwards on all cores | done |
| 5 | Exact fill on the same engine | done (stays 4-connected) |
| 6 | Zero pages for the maps; seed checked before anything is allocated | done (`VirtualAlloc`) |
| 7 | Cheaper rectangle and ellipse selection tests | done another way, see below |
| 8 | Polygon selections as words | done (64 mask bits per read) |
| 9 | Parallel walk | done (strips, shared work pool) |
| 10 | Reuse the last region after undo | not done, see below |
| 11 | Huge images: undo only the filled rectangle | done (new exports + AHK) |
| 12 | Normal images: lock only the changed rectangle | not done, see below |
| — | 512 MiB ceiling on any image | done |

**Option 7.** Computing per-row inside intervals analytically would match the shipped
per-pixel float test only with a proof of float error bounds near the shape's edges. Instead,
`FloodSel::shapeBits()` performs `isInsideRectOval()`'s own float steps 4 pixels at a time with
SSE2. The steps are the same IEEE operations, so the results are bit-identical by construction:
the build targets SSE2, so no FMA contraction occurs. It is about 5–10× cheaper per pixel.
Checked on 32.9 million pixels, including coordinates up to 600 000 px, scales from 0.01 to 3,
every rotation, flips, cavities and inverted selections.

**Option 10, not implemented.** It is only correct if the image has not changed since the region
was found, and the DLL cannot know that. AHK would have to version the image content through undo
and redo. A stale region would paint the wrong pixels, which is a worse failure than a slow fill.
After this work the walk is a small share of a fill's time anyway.

**Option 12, not implemented.** Its benefit cannot be measured here (GDI+). It needs a second
`LockBits` on a sub-rectangle plus a region kept between the two locks, and the selection modes of
the normal path clone the whole bitmap regardless. It is worth doing only after a measurement on
Windows shows the conversions matter.

## How the memory ceiling holds

- `setup()` charges everything against the budget: the colour table (4 MiB), the distance memo
  (2 MiB), one 2 MiB paint memo per paint thread, the span stacks, and the maps (F, M, K and a
  dirty bit per row: 16.1 bytes per 64 pixels).
- The maps come from `VirtualAlloc`: zero pages, so a small fill on a huge image touches only a
  few pages. They are still *committed*, so the figures below count them in full.
- The span stack is capped. A span that does not fit marks its rows dirty, and `rescan()`
  revisits only those rows. Whatever the maps leave of the budget goes to the span stacks.
- When an image's maps do not fit (above about 1.7 GP), the image is walked in bands of rows.
  Bands hand seeds to each other through their edge rows until no edge can reach further, then
  each band is walked once more and painted.

## Measurements

Linux, i7-7700T (4 cores, 8 threads), g++ `-O2 -msse2`, the shipped code compiled the same way.
Times are the best of three; every row painted the same bytes as the shipped code. MSVC
inlines differently, so the DLL build should be re-measured.

**24 MP and 16 MP images** (the study's cases; ms):

| Case | Shipped | New, 8 threads | New, 1 thread |
|---|---|---|---|
| exact, flat 32 bpp | 132.6 | 28.0 (4.7×) | 27.0 (4.8×) |
| exact, flat 24 bpp | 117.3 | 36.9 (3.2×) | 51.4 (2.3×) |
| exact, maze | 114.2 | 92.1 (1.2×) | 131.5 (0.9×) |
| exact, random noise | 211.8 | 108.4 (2.0×) | 237.2 (0.9×) |
| exact, flat + ellipse selection | 482.8 | 33.6 (14.4×) | 39.7 (12.4×) |
| exact, flat + rectangle selection | 454.2 | 30.0 (15.1×) | 26.2 (17.4×) |
| tolerance, flat, grayscale | 271.8 | 42.2 (6.4×) | 56.2 (4.9×) |
| tolerance, photo, grayscale | 320.7 | 33.7 (9.5×) | 98.6 (3.3×) |
| tolerance, photo, L\*a\*b grayscale | 196.5 | 25.8 (7.6×) | 73.5 (2.7×) |
| tolerance, photo, CIEDE2000 | 1660.3 | 69.4 (23.9×) | 179.6 (9.2×) |
| tolerance, photo, opacity 128 | 648.0 | 50.4 (12.9×) | 148.4 (4.3×) |
| tolerance, photo, dynamic opacity | 763.6 | 53.6 (14.2×) | 150.4 (5.2×) |
| tolerance, photo, CIEDE2000 + dynamic | 2074.8 | 98.0 (21.2×) | 252.4 (8.1×) |
| tolerance, photo, blend 5, linear gamma | 596.3 | 50.8 (11.7×) | 144.9 (4.1×) |
| tolerance, semi-transparent photo, blend 3 | 709.0 | 168.1 (4.2×) | 475.7 (1.5×) |
| tolerance, flat, opacity 128 | 1041.3 | 55.8 (18.6×) | 112.0 (9.3×) |
| tolerance, maze | 272.3 | 119.7 (2.3×) | 176.2 (1.5×) |
| tolerance, noise, 8-way | 546.4 | 129.0 (4.2×) | 343.0 (1.6×) |
| tolerance, photo + ellipse selection | 362.9 | 30.0 (12.1×) | 90.1 (4.0×) |

**900 MP image** (30000 × 30000, 24 bpp). Memory is the peak of everything the fill allocated:

| Case | Shipped | New |
|---|---|---|
| small square (89 K pixels), grayscale | 0.05 s, 108 MiB | <0.01 s, 220 MiB committed, few pages touched |
| flat, grayscale | 9.57 s, 108 MiB | 0.87 s, 221 MiB |
| flat, exact | 4.92 s, 0 MiB | 0.74 s, 217 MiB |
| noisy, CIEDE2000 + dynamic opacity + blend | 51.63 s, 108 MiB | 1.81 s, 238 MiB |
| 612 MP noise cluster, 8-way | 31.41 s, **1259 MiB** | 4.5–8.6 s, **319 MiB** |
| flat, budget forced to 128 MiB (3 bands) | 9.59 s, 108 MiB | 1.26 s, 103 MiB |
| noise cluster, budget forced to 128 MiB | 31.53 s, 1259 MiB | 27.9 s, 123 MiB |

The noise-cluster time depends on memory pressure: 4.5 s alone, 8.6 s while the test held two
more copies of the 2.7 GB image.

## Verification

All against the shipped code at `c26999f`, sliced unchanged into a g++ harness:

- 12 000 randomised cases: image size and contents, 24 and 32 bpp, padded strides, every fill
  option, every selection kind (inverted and high-depth included), 1/2/3/8 threads, forced band
  walks and forced span-stack overflows. Each case compares the image bytes and pixel count with
  the shipped fill, repeats the fill through `FloodFillFindRegion`/`FloodFillPaintRegion`, and
  checks the pixel count and bounds against a plain breadth-first fill.
- 40 large multi-threaded cases (up to 1400 × 930).
- AddressSanitizer + UBSan (2000 cases) and ThreadSanitizer (1500 cases + 20 large parallel
  ones): no reports. TSan was confirmed to catch a planted race.
- The AHK script load-checks under Wine with AutoHotkey_H; the check was confirmed to reject a
  broken script.

## Behaviour changes and contracts

- The exact fill returns the number of pixels filled. It used to return a loop count, usually
  pixels + 1. The normal-image caller now records undo when `r>0`; with `r>1`, a fill of a single
  pixel recorded no undo level.
- The exact fill stays 4-connected; the "eight ways" option still applies only to tolerance fills.
- New exports, with `FloodFillWrapper` unchanged:
  - `FloodFillFindRegion(...same 21 arguments..., int *bounds)` keeps the region and returns its
    pixel count, with `bounds` = x1, y1, x2, y2 (inclusive; rows in FreeImage order). It returns
    -1 for "replace similar colours anywhere".
  - `FloodFillPaintRegion(imageData, w, h, stride, bpp)` paints the kept region.
  - `FloodFillDiscardRegion()` drops it.
- The huge-image flood fill uses those exports and records an undo level of just the bounds,
  through the existing rectangle undo (`FreeImage_Crop` + `UndoAiderSwapPixelRegions`). With a
  qpvmain.dll that lacks the exports it falls back to the previous flow.
- Fills run on every hardware thread (`std::thread` crews created per call; no OpenMP, no parked
  threads) once 65 536 pixels are filled.
- Out of memory: the fill reports failure (r = 0). The maps are allocated before anything is
  painted, so nothing changes; inside the paint, a missing memo only means slower painting. The
  shipped code would have thrown `bad_alloc` out of the DLL.

## Known limits

- With 1–2 threads, exact fills over maze-like or binary-noise images run at about 0.9× the
  shipped speed. The shipped exact fill painted as it went and kept no maps. Every other case is
  faster at every thread count measured (1, 2, 4, 8).
- Above about 1.7 GP, band walks cost roughly 1.5–3× a single-band walk. The memory stays in budget.
- Maps are committed for the whole image even when a fill touches a corner of it. RAM use follows
  the touched pages, but Windows' commit charge counts the full size, up to the budget.
- Not run on Windows: the MSVC build, and the huge-image undo through the new exports.

## Next steps

1. Rebuild qpvmain.dll (MSVC) and load the branch's `quick-picto-viewer.ahk` with it.
2. On a huge image (FreeImage path): fill a small area, undo, redo. The undo level must cover the
   filled rectangle, and the journal shows the fill time.
3. On a normal image: fill one isolated pixel; undo must now restore it.
4. Optional: time a large tolerance fill and a CIEDE2000 fill against the release DLL.

The harness, scripts and outputs are in `.claude/scratch/floodfill-impl-2026-10-09/`
(git-excluded): `bash verify_all.sh` reruns every check, and `README.txt` lists the rest.
