# qpvmain.dll bug audit — 2026-10-06

Branch `interface-thread-merge-phase-c` @ 5673b2b. Scope: every C++ source of the DLL
(`qpv-main.cpp`, `qpv-main.h`, `dupes-search.h`, `dupes-pixels.h`, `thumbs-pool.h`,
`pdf-writer.h`, `freeimage-dynamic.h`, `sqlite-dynamic.h`, `callwndproc-hook.h`, `dllmain.cpp`).

**How it was checked.** Twelve reviewers each took one region; every item below was then re-read
against the source, and its AHK caller was traced to confirm a user can reach it. "Harness" means
the shipped function was text-sliced into a g++ program (ASan/UBSan) and run. "Reading" means the
defect is visible in the code and the trigger was traced by hand. Nothing was built with MSVC and
nothing was run on Windows. Every fix needs a qpvmain.dll rebuild.

Terms:
- **huge image**: an image over the GDI+ size limit, held in `viewportQPVimage` as a FreeImage bitmap;
  most tools then run through `HugeImagesApplyGenericFilters()`.
- **exact fill / tolerance fill**: `FloodFillWrapper()` sends tolerances ≤ 2 to
  `FloodFillScanlineStack()` and larger ones to `FloodFill8Stack()`.
- **teleport path**: `WICpreLoadImage()` → `WICgetBufferImage()` → AHK `teleportWICtoFIM()`, which
  wraps the raw WIC pixels as a FreeImage bitmap.
- **straight ARGB**: what LockBits hands the DLL — colour not multiplied by alpha, so a transparent
  pixel still carries an RGB (usually white) that unweighted averaging lets bleed into its neighbours.
- **normal image**: one on the GDI+ path; for brushes AHK locks only a rectangle around each stamp.

**46 items: 8 high, 22 medium, 16 low.** The ones most likely to have been seen already: #1 (flood
fill at the default tolerance), #2 (painting inside a selection), #3 (any hue change) and #6
(converting a grey JPEG). Memory-safety: #4, #27, #41, #45. Crashes: #7, #8, #30.

**Fixed: #1 to #22, and #27**, one commit each (#27 with #11), named under each item; qpvmain.dll must
be rebuilt for them to take effect, and #4, #7, #10 and #15 also change quick-picto-viewer.ahk.
**Open: #23 to #26, and #28 to #46.**


## High

### 1. Flood fill at low tolerance leaves part of a large region unfilled
- **Fixed in `c2ba1af`:** the two `!= oldColor` tests are back, and the loop budget is
  `3*w*h + 1`, held in 64 bits; with the tests restored, `w*h + w` still cut 6% of random fills short.
- **Where:** `qpv-main.cpp:3209-3227` (`FloodFillScanlineStack`), with the loop budget at 3146/3186.
- **What's wrong:** the two `else if (spanAbove && y>0)` / `(spanBelow && y<h-1)` branches reset the
  span flag without testing that the pixel above/below stopped matching, so a seed is pushed for every
  second pixel of every filled run. Each stale seed spends one unit of the `w*h + w` budget; once the
  budget is gone the rest of the stack is drained without filling. The test was dropped in f5129f1
  (2024-04-18, v6.0 alpha) when the comparisons moved from ints to bytes; af57370 had it.
- **Trigger:** default settings (tolerance slider 0, "Grayscale" → AHK passes 1 → exact fill), normal
  or huge images. The fill is cut short once the region is a large share of the image (a centred click
  on a region of 64% fills it, 81% leaves 1.4%, the whole image leaves a quarter).
- **What you see:** uniform 1920×1080 canvas, click at y=360: 33.1% of it keeps the old colour (y=540:
  24.8%, y=180: 16.7%). The DLL returns a positive count, so an undo level is recorded and it looks
  like success. On a huge image the stale seeds also cost w·h/4..w·h/2 stack entries (1.2–2.4 GB for
  30000×20000).
- **Evidence:** harness on the shipped function — confirmed; restoring the missing `!= oldColor`
  test fills 100% with a 2-entry stack peak. (The `UINT maxPixels = w*h + w` product is also an
  `int` multiply that wraps above 4.29 Gpx.)

### 2. Painting "inside/outside the selection" is mirrored vertically on normal images
- **Fixed in `eabf2d4`:** `PaintBrushLarge()` asks `clipMaskFilter()` about the bottom-up row `py`
  when the buffer is a GDI+ lock rect (`lockW>0`); huge images are unchanged.
- **Where:** `qpv-main.cpp:9576` (`clipMaskFilter(px, iy, NULL, 0)`) with ahk:78418-78430
  (`InitHugeImgSelPath()` + `QPV_PrepareHugeImgSelectionArea()`) and ahk:78893 (`dll_tkY = imgH-1-cur_tkY`).
- **What's wrong:** the selection is always prepared in bottom-up rows (`Y1 := imgH - imgSelPy`), which
  suits FreeImage; on the GDI+ path the brush's `iy` is the top-down row, so it is tested against a
  mirrored box.
- **What you see:** 400×300 image, selection y 20..79, "Paint inside selection": a stamp at y=50 paints
  nothing; one at y=249 paints rows 235..263. "Paint outside" is mirrored the same way. Huge images are
  right.
- **Evidence:** reviewer harness running the shipped `prepareSelectionArea`, `clipMaskFilter` and
  `PaintBrushLarge` with the AHK flow emulated — confirmed. The fix belongs to one side of the contract:
  prepare top-down coordinates for `isLarge=0`, or flip `iy` in the DLL when `lockW>0`.

### 3. Any hue change washes out light colours
- **Fixed in `cae77ac`:** `S = del_Max / (2.0 - max - min)`.
- **Where:** `qpv-main.h:311` (`RGBA16color::ConvertRGBtoHSL`).
- **What's wrong:** for L ≥ 0.5 it computes `S = del_Max / (2.0 - del_Max)`; the formula is
  `del_Max / (2.0 - max - min)`. The two agree only when min = 0, which is why saturated primaries and
  dark colours look right.
- **Trigger:** the Hue slider of Adjust colours (any value), paste-in-place hue, blur-area hue, the
  Desaturate tool's hue, and the effects/cloner brushes (`brushHue`). Only `hueRotate()` reads this S.
- **What you see:** pastels, sky and skin go grey: (255,255,128) at hue −1 → (213,212,169) instead of
  (255,253,127); at 180 → (169,169,213) instead of (127,127,255); (240,200,160) at 180 → (189,200,210)
  instead of (159,200,240).
- **Evidence:** harness on the sliced pipeline — confirmed. The 2026-07 rewrite was verified
  bit-identical to the older code, so it carried this over.

### 4. The smudge brush reads outside the locked pixels on normal images
- **Fixed in `b265651`:** the DLL clamps the clone region to the lock rect (a sample past it takes the
  edge pixel; a GDI+ stamp without the copy is skipped), and `DrawPaintBrushNowStep` pads the smudge
  lock by `cur_off * scale` on the side the samples come from, with the DLL's scale formula.
- **Where:** `qpv-main.cpp:9213-9228` (the clone region is the brush box plus `offX*scale`, scale 3 at
  wetness 0 up to ~26), `9232-9254` (the `memcpy` at 9248 copies all of it), fallback reads at 9903-9912;
  ahk:78813-78820 (type-6 lock padding `|factor|*2 + 10`) and ahk:78895-78905 (lock rect, virtual base).
- **What's wrong:** on a normal image AHK locks only a rectangle around the stamp, as ARGB over a PArgb
  bitmap, so GDI+ returns a converted buffer holding just that rectangle, and passes
  `imgBits - lockY*pitch - lockX*4`. The clone region reaches `cloneOffset + 2` px past the brush box,
  beyond the padding as soon as the per-stamp offset exceeds ~1 px. The lock-rect check on this copy was
  added in 925ea44 and dropped the same day in 63573f6 ("reverted the brushOriginalPixels stuff").
- **Trigger:** smudge brush on a normal image with stepping AUTO or a fixed step of ~4 px or more, any
  stroke with a vertical component (wetness 0, brush 20 → 13.6 px offset against a 12 px margin; brush 50
  at wetness 10 → reads ~124 rows above the lock). The default 1 px stepping is safe.
- **What you see:** colours dragged in from unrelated memory or from the wrong rows; when the read
  reaches unmapped memory, an access violation swallowed by DllCall (stamp lost). If the clone region
  is ≥ 150 MB the out-of-lock reads happen inside the OpenMP loop instead, where a fault ends the process.
- **Evidence:** reviewer harness modelling the GDI+ buffer as exactly the lock rect between guard pages:
  SIGSEGV in the `memcpy` at 9248 — confirmed (that GDI+ hands back a rect-sized conversion buffer is
  also what c0bcb1f's earlier out-of-lock crash fix relied on).

### 5. Auto-adjust colours, "RGB levels": a flat channel is wiped, an all-transparent crop inverts
- **Fixed in `0fbedaa`:** a flat channel keeps its values (factor 1 from 0), and when no pixel of the
  copy is counted the image is left alone, in both modes.
- **Where:** `qpv-main.cpp:8308` (the flat-range guard applies to `modus==1` only), 8311-8320,
  8346-8348 (`autoContrastBitmap`).
- **What's wrong:** with `modus==2` a channel whose range in the analysed copy is 0 gives `255/0 = inf`,
  and `(v-min)*inf` is `0*inf = NaN` for its pixels → `(int)NaN` = INT_MIN on MSVC → clamped to 0. If
  every pixel of the analysed copy has alpha < 30, max=0 and min=255, so the factor is −1 and every
  channel is inverted.
- **Trigger:** "Auto-adjust image colors" with "RGB levels" or "Both" on an image/selection where one
  channel is constant (a red or yellow logo on white: R=255 everywhere; a flat-colour selection), or
  whose analysed area is transparent (a frame PNG).
- **What you see:** yellow on white → black on blue; a flat selection turns black; inverted colours.
  The batch version overwrites the files in place (`destImgPath := imgPath`, ahk:98133).
- **Evidence:** reading + reviewer harness (UBSan flags the NaN→int) — confirmed.

### 6. Grey and palette images lose their tones on the WIC→FreeImage path (5 bits per channel)
- **Fixed in `06a00c9`:** those formats answer 24, and 8bppAlpha 32; `WICpreLoadImage()` answers 32
  for an indexed frame whose palette has an entry that is not opaque. WIC is never asked for
  16bppBGR555 now, so the link below that was not run no longer matters.
- **Where:** `qpv-main.cpp:6508-6516` (`decideWICtoFIMpixelFormat` answers 16 for 1/2/4/8bppIndexed,
  BlackWhite, 2/4/8bppGray, 8bppAlpha, 16bppBGR565 and 16bppGray) and `6279-6280`
  (`coreWICgetBufferImage` turns 16 into `GUID_WICPixelFormat16bppBGR555`).
- **What's wrong:** `WICpreLoadImage()` returns that 16; `loadWICasFreeImage()` / `teleportWICtoFIM()`
  pass it straight to `WICgetBufferImage()`, so an 8-bit grey image is converted to 16bppBGR555 and
  wrapped as a 555 FreeImage bitmap: 256 grey levels become 32, 16-bit grey becomes 32 levels, palette
  images shift colour and lose tRNS transparency.
- **Trigger, default settings** (allowWICloader=1, alwaysOpenWithFIM=0, userPerformColorManagement=1):
  "Convert format" of a grey/palette .jpg/.png/.tif (`coreConvertImgFormat`, ahk:61244), "Extract
  TIFF pages" (ahk:61689, no extension gate), batch rotate/crop/resize (ahk:98315), batch colour adjust
  (ahk:98458); also huge images the viewer loads through WIC.
- **What you see:** banding in grey gradients in the written file, max error 7 levels.
- **Evidence:** the chain is confirmed by reading, and a reviewer harness with the FreeImage fork shows
  the 555 wrap keeps 32 of 256 grey levels. One link was not run: that WIC's format converter accepts
  16bppBGR555 as a target (its documentation lists it). If it did not, `coreWICgetBufferImage()` would
  return NULL and AHK would fall back to `FreeImage_Load()` with no damage — so test one grey JPEG
  through "Convert format" before fixing. Fix direction: answer 24 (32 for palette-with-alpha) for the
  8-bit-and-up members of that group.

### 7. PDFium is called from two threads at once
- **Fixed in `f4d01a9`:** every PDFium caller takes one `std::timed_mutex pdfiumMutex`, declared ahead
  of the PDF exports. The pools block on it and call `coreRenderPdfPageAsBitmap()`; the four exports
  wait for it at most 15 s, then return the error code -8, which `friendlyPDFerrorCodes()` names
  "PDFium is busy with another document". The viewer asks PDFium for the bookmarks of `.pdf` files only.
- **Where:** `ExtractPDFBookmarks` (qpv-main.cpp:6847), `RenderPdfPageAsTextLinks` (6891),
  `RenderPdfPageAsText` (7016), `RenderPdfPageAsBitmap` (7103) take no lock; `tpPdfMutex` is declared
  later (thumbs-pool.h:205) and only the two worker pools take it (thumbs-pool.h:1660,
  dupes-pixels.h:452).
- **What's wrong:** PDFium is not thread-safe ("only a single PDFium call can be made at a time",
  fpdfview.h). The AHK thread's calls are not serialised against the pools'. `thumbsPoolEnd()` and
  `dupesPixEnd()` do not wait for renders already running, and the thumbnail watchdog gives up on a
  worker that is still inside PDFium.
- **Trigger:** the realistic window is a PDF opened in the viewer (render, bookmarks, text) while
  PDF thumbnails are still rendering, or while "Collect image data" renders PDFs and the thumbnails timer
  draws a PDF on the AHK thread (single-threaded branch). The viewer also calls `ExtractPDFBookmarks()`
  → `FPDF_LoadDocument()` for every WIC-loaded JPEG/PNG/TIFF (`generateViewPortPDFbookmarks()`,
  ahk:75120, 99553), but on a non-PDF that fails at the header, so the JPEG case is a far smaller window.
- **What you see:** intermittent crashes or heap corruption inside pdfium.dll.
- **Evidence:** reading (three reviewers independently); likely. A plain blocking lock on the AHK thread
  would freeze the UI behind a stuck worker; a timed lock or one PDFium thread avoids that.

### 8. A PDF whose outline loops freezes or crashes QPV when it is opened
- **Fixed in `c7a7662`:** each outline item is listed once; at most 100000 items and 256 levels.
- **Where:** `qpv-main.cpp:6793-6843` (`TraverseBookmarks`).
- **What's wrong:** no cycle guard. PDFium only refuses `/Next` pointing at the item itself, and
  fpdf_doc.h leaves circular references to the caller. A sibling loop grows `out` without limit; a
  child loop recurses until the stack overflows.
- **Trigger:** opening such a PDF (≥3 pages) in the viewer, the PDF panel, or a text export.
- **What you see:** memory climbing until an allocation fails, or a stack overflow swallowed by
  DllCall that leaks the document and leaves the thread without its guard page.
- **Evidence:** reviewer harness against stubs following upstream semantics — confirmed (the shipped
  pdfium.dll itself could not be inspected).

## Medium

### 9. Exact flood fill with "Flood inside/outside" on huge images ignores the selection on one side
- **Fixed in `429cb86`:** one test - the old colour and not masked - drives the left scan, the right
  scan and the seeds above and below; a click on a masked pixel fills nothing and returns 0.
- **Where:** `qpv-main.cpp:3170-3177` against `3190-3196` (`FloodFillScanlineStack`).
- **What's wrong:** the left scan walks over masked pixels; the right scan then starts at the leftmost
  pixel of the run and stops at the first masked one. Any row whose run reaches left past the
  selection edge is not filled, and nothing spreads from it.
- **What you see:** 200×200 uniform image, selection 50..149: "Flood inside" at (100,100) fills
  0 of 10 000 pixels yet returns 1 (undo level, success beep); "Flood outside" misses the band right of
  the selection. The tolerance fill gets both right.
- **Evidence:** harness on the shipped function — confirmed.

### 10. Pixelate and pixelated noise on huge images use blocks too large by image ÷ selection
- **Fixed in `ad3f998`:** `smallBitmapArea()` maps the small bitmap over the selection box clipped to
  the image (the whole image when inverted), its start row corrected by `polyOffYb` for freeform
  shapes; Add noise sizes its small bitmap from the selection. Rotated ellipses stay off: the DLL gets
  a rescaled box for them, and the small bitmap is made from the unrotated rectangle.
- **Where:** `qpv-main.cpp:3633/3636` (`GenerateRandomNoiseOnBitmap`) and `5289/5292`
  (`PixelateHugeBitmap`): `mw*((x - bmpX)/(float)w)` divides by the whole image width/height.
- **What's wrong:** AHK sizes the small bitmap from the *selection* (`Ceil(obju.bImgSelW/amount)`,
  ahk:22286, 22361) but passes the whole image as `w`/`h` (ahk:22323, 22383), so only the first
  `selW²/(amount·imgW)` columns of it are used.
- **What you see:** 40000-px image, 10000-px selection, Pixelate 50 → 200-px blocks, built from the
  lower-left corner of the selection magnified; noise grain likewise coarse and stretched. The live
  previews pass box-sized values, so the preview looks right and the result does not. Correct when the
  selection is inverted or covers the whole image.
- **Evidence:** two reviewers independently; harness on `PixelateHugeBitmap` — confirmed.

### 11. "Separated line segments" lose most of each stroke on huge images
- **Fixed in `1774b87`:** the merge window is mapped the way `NewDrawLinesOnMask()` maps the points,
  and a window wholly off the mask returns before touching it (which also fixes #27).
- **Where:** `qpv-main.cpp:1764-1767` (`mergePolyMaskIntoHighDepthMask`) against 1357-1373
  (`NewDrawLinesOnMask`).
- **What's wrong:** `NewDrawLinesOnMask()` places a point at mask (x−polyX, y+polyOffYa−polyOffYb−polyY);
  the merge window uses the AHK path bounds unmapped. When `polyOffYb` ≠ 0 the window sits that many rows
  off the stroke; the unmerged rows never reach `highDephMaskMap`, which is all FillSelectArea reads in
  this mode.
- **Trigger:** Draw parametric lines on a huge image with "Separated line segments" (default 1) and a
  selection within `tk` (the margin AHK adds around the lines, about 1.25× the stroke radius) of the
  image bottom: `imgSelY2 += tk` (ahk:21704) makes
  `ppofYb = imgSelY2 − imgH` (ahk:14855). "Select all" hides it (ahk:21705 resets `imgSelY2 := imgH`).
  The DLL mismatch is in the code; this AHK chain was traced by reading, not run.
- **What you see:** horizontal strokes drawn at ~⅓ of their thickness and off-centre, vanishing once the
  offset exceeds the stroke; vertical strokes shortened. Unticking the option draws them whole.
- **Evidence:** reviewer harness on the sliced functions (with `polyOffYb` = 17, 32 140 of a stroke's 96 443 px
  are merged) — confirmed.

### 12. Polygon selections fill a straight span outside the shape (huge images)
- **Fixed in `469395e`:** every span is tested against the polygon, two crossings or more.
- **Where:** `qpv-main.cpp:769` (`fillMaskPolyBounds`): `if (listu.size()>2 && simpleMode==0)`.
- **What's wrong:** when a scanline holds exactly two distinct crossings after `unique()` — two tips on
  one row, each deduplicated to one entry — the span between them is filled without the inside test.
- **What you see:** the built-in Star-5 shape: a line joining the two lower tips across the gap
  between the legs (400×400 selection: row from x 40..360), in fills, erases and colour adjustments.
  Also "M" shapes and thin spikes.
- **Evidence:** reviewer fuzz against an even-odd reference — 8..805 mismatching pixels per seed with
  the shipped code, 0 with the shortcut removed — confirmed.

### 13. Cloner, effects, smudge and pinch/bulge brushes put opaque halos on transparent areas
- **Fixed in `6d0e50c`:** the layer's alpha is `srcA * weight / 255`, rounded; opaque sources are
  byte-identical to before.
- **Where:** `qpv-main.cpp:9987`: `outA = 255 - clamp(max(srcA,weightInt) - min(srcA,weightInt), 0, 255)`.
- **What's wrong:** this equals the brush weight only when `srcA` is 255; for a transparent source it
  inverts (`srcA=0` → `255-weight`), so the soft rim of the stamp becomes the most opaque part.
  `srcA*weight/255` is what the rest of the code implies.
- **What you see:** the effects brush (hue +30, opacity 200) over a fully transparent area makes 2917
  pixels visible, the rim at alpha 251; cloning a transparent region onto opaque red turns 1020 pixels
  white/pink; half-transparent areas go opaque. Paint brushes (types 1/2) pass `srcA=255` and are fine.
- **Evidence:** reading + reviewer harness — confirmed; with only that line changed, the transparent cases
  change 0 pixels and every `srcA=255` case is byte-identical.

### 14. The MSD (mean squared difference) bounds are silently skipped
- **Fixed in `f35d44d`:** `dupesApplyFilter()` applies the MSD bounds whenever `dupesHaveMSD()`, the
  panel's test, finds scores; `tests/filter_oracle.cpp` follows.
- **Where:** `dupes-search.h:1369-1370` (`dupesApplyFilter`'s `allowMSE`) against 1577-1598
  (`dupesHaveMSD`).
- **What's wrong:** 736de91 widened `dupesHaveMSD()` because "a sweep can legitimately leave the leading
  pairs without a score"; `dupesApplyFilter()` still requires pairs 0 *and* 1 to be scored, else it
  ignores `mseLo/mseHi` entirely.
- **What you see:** when either leading pair lacks a fingerprint, the MSD threshold is not applied to
  the result while the panel shows the MSD fields enabled; pairs scoring 300 stay grouped, and pairs
  without a fingerprint (2500) are no longer excluded.
- **Evidence:** reading + reviewer harness — confirmed.

### 15. Re-filtering duplicates brings deleted images back and can drop a live one
- **Fixed in `33e3611`:** the mask has two bits: the search string (first image of a pair, cached)
  and deleted entries (refreshed on every pass), which link their group but are not listed nor
  counted towards hiding single-member groups.
- **Where:** `dupes-search.h:1390-1392` (`imgKeep` is tested on `idA` only) and ahk:86573-86583
  (`maskKey` does not change when an image is deleted).
- **What's wrong:** AHK now puts the "deleted entry" test (`!InStr(imgPath,"||")`) into the same mask
  the DLL applies to the first image of each pair only; the pre-port code removed deleted images one by
  one after grouping.
- **What you see:** delete one image of a group, then Update in "Change hashes threshold": the stale mask
  shows the dead entry again; with a fresh mask, pairs A~B, B~C with B deleted give {B, C} — B shown,
  A lost.
- **Evidence:** reviewer harness — confirmed. Needs a per-image mask in the DLL or an AHK post-filter.

### 16. Desaturate: "Green" and "Blue" are swapped
- **Fixed in `da24af0`:** both DLL sites map 3 to green and 4 to blue.
- **Where:** `qpv-main.h:698-700` (`saturation()`: 2→r, 3→b, else g) and `qpv-main.cpp:4679-4681` (the
  table shortcut, same mapping).
- **What's wrong:** the panel list is "All channels|All (alt)|Red|Green|Blue" with AltSubmit and AHK
  passes `DesaturateAreaChannel-1`, i.e. Red=2, Green=3, Blue=4 (ahk:19905, 22396, 55874).
- **What you see:** (200,100,50) with Green → (50,50,50), with Blue → (100,100,100).
- **Evidence:** reading + reviewer harness — confirmed. Change both DLL sites together (or the AHK
  mapping), or the table and per-pixel paths will disagree.

### 17. Luminosity blend mode is wrong with gamma correction on
- **Fixed in `32a871a`:** with gamma correction both lumas are taken from the linear values, with the
  same weights (modes 20 and 21): grey 50 over 200 now gives 50, 24 over 231 gives 23, 128 over 200
  gives 128. Without gamma correction nothing changes.
- **Where:** `qpv-main.cpp:2600-2611` (`CalculateNewBlendModes`, modes 20/21).
- **What's wrong:** `lO`/`lB` are sRGB-space lumas, but with gamma correction the channels are linear
  (`char_to_floatGamma`), so a gamma-space difference is added to linear values.
- **What you see:** grey 50 over grey 200 → 30 (should be 50); 24 over 231 → 0; 128 over 200 → 148.
  Every tool with a blend-mode list (blur, noise, fill, text, brushes, flood fill) when "Gamma
  correction" is ticked.
- **Evidence:** reading + reviewer harness — confirmed (inherited, not from the lookup tables).

### 18. The PDF links list keeps only the first web link
- **Fixed in `c823683`:** the copy stops at the terminator; two link annotations and three web links
  now list all five.
- **Where:** `qpv-main.cpp:6977-6989` (`RenderPdfPageAsTextLinks`).
- **What's wrong:** `FPDFLink_GetURL()`'s count includes the terminator and the loop copies it before
  appending `|`; AHK reads the buffer with `StrGet(&textBuffer, bufferSize)` (ahk:100624), which stops
  at the first NUL.
- **What you see:** the PDF panel's links list and the "texts + links" export show the link
  annotations and the first detected URL only.
- **Evidence:** reviewer harness — confirmed.

### 19. A failed SVG render comes back as a blank image, as if it had worked
- **Fixed in `b0bdf3c` and `bedbd2e`:** `WicD2DrenderSVG()` returns NULL unless the document was
  drawn, so the viewer reports a load error, the thumbnails pool a failed tile, and the collection pool
  marks the file dead (`isDeleted=1`), on every system.
- **Where:** `qpv-main.cpp:7603-7641` (`WicD2DrenderSVG`).
- **What's wrong:** when the `ID2D1DeviceContext5` query fails (Windows 7/8.x, Windows 10 before
  1703), `CreateSvgDocument()` fails (malformed/truncated SVG) or `EndDraw()` fails, the never-drawn WIC
  bitmap is still returned.
- **What you see:** an empty transparent image instead of a load error; the thumbnails pool reports
  success (`TP_OK`) and caches the blank tile; the collection pool stores the fingerprint of a blank image, so
  broken SVGs can match one another (and uniform images) as duplicates.
- **Evidence:** reading — confirmed code path (Direct2D not run).

### 20. "Generate all thumbnails" reports FreeImage-only files as failed and decodes the rest twice
- **Fixed in `6b02fd1`:** with no bitmap wanted, a NULL with `TP_OK` and the cache file saved ends the
  chain: such files are decoded once, reported done, and record loader 2 with FreeImage's properties,
  as viewing mode does. With a bitmap wanted, a NULL (saved, but the conversion to GDI+ failed) still
  falls back to WIC.
- **Where:** `thumbs-pool.h:1584-1596` with 1697 and 1727 (`tpRunJob`).
- **What's wrong:** with `wantBitmap=0` (no bitmap wanted back) a successful FreeImage save returns NULL
  with success status (`TP_OK`); the chain
  treats NULL as failure and `hasFIMtried==1` sends the file on to WIC and then GDI+, which overwrite
  status, loader and image properties.
- **What you see:** TGA/PSD/EXR/DDS...: the cache PNG is written but the tile is marked "x" and the
  journal says "Failed to generate"; PNG/WEBP/RAW: an extra full WIC decode each, and WIC's image
  properties recorded instead of FreeImage's.
- **Evidence:** reviewer harness with the real FreeImage fork — confirmed.

### 21. Sharpen (CImg mode) ignores transparency
- **Fixed in `4cd6477`:** the DLL runs the same inverse diffusion itself, each neighbour weighted by its
  opacity; transparent pixels and alpha are left as they are, and a clone padded with transparency
  sharpens exactly like the image alone. Opaque images, 32 and 24 bits, get CImg 3.4.3's bytes
  (harness, 2160 cases).
- **Where:** `qpv-main.cpp:8012-8019` (`cImgSharpenBitmap`).
- **What's wrong:** `img.sharpen()` runs on all four straight-ARGB planes; transparent pixels (RGB 0)
  are sharpened in as black, and CImg normalises the velocity by the maximum over all planes, alpha
  included.
- **What you see:** a bright opaque rim along every transparent edge (grey 128 next to transparency
  → 247) and weaker sharpening elsewhere; also on opaque images when the selection overhangs the
  image edge (the clone is padded with transparency). Default mode and amount.
- **Evidence:** reviewer harness with CImg 3.4.3 — confirmed.

### 22. "Replace" blend mode at partial opacity: wrong alpha with gamma correction, colour bleed
- **Fixed in `2271b06`:** the colours mix by how much of each layer is visible (a cross-fade of the
  premultiplied layers) and alpha is interpolated without gamma correction: red over transparent
  white at 50% gives (255,0,0, a127) with gamma correction off and on. Opaque and 24-bit images get
  the same bytes as before, and layers of equal alpha the same colours. The paint brush's own Replace
  (`PaintBrushLarge()`) goes through the same code since `b5131b2`: its soft edges no longer take the
  colour of transparent pixels, and it honours gamma correction. Since `7f11a0a` the alpha it paints is
  the stroke's opacity capped by the source's alpha, so the cloner, effects, smudge, pinch and bulge
  brushes no longer reveal colour hidden under transparency.
- **Where:** `qpv-main.cpp:2507-2530` (`CalculateNewBlendModes`, modes 24/100).
- **What's wrong:** straight RGB is interpolated without alpha weighting, and with gamma correction the
  *alpha* is pushed through `gamma_to_linear`/`linear_to_gamma` too.
- **What you see:** red over transparent white at 50% → (255,128,128, a127), or a183 with gamma
  correction — pink fringes, and a 50% Replace giving 72% alpha. Blur and Add noise with "Replace",
  PixelateHugeBitmap.
- **Evidence:** reading + reviewer harness — confirmed.

### 23. "Behind" blend mode ignores the opacity slider
- **Where:** `qpv-main.cpp:2489` (opacity applied only for `blendMode < 24`) and 2550 (mode 25 swaps
  the layers).
- **What you see:** red over half-transparent blue gives (127,0,128,a255) at opacity 0, 128 and 250
  alike.
- **Evidence:** reading + reviewer harness — confirmed. No AHK caller compensates.

### 24. Huge-image insert text at reduced opacity loses its anti-aliased edges
- **Where:** `qpv-main.cpp:5372-5379` (`DrawTextBitmapInPlace`).
- **What's wrong:** over a destination pixel with alpha 0 it writes `nA - opacity` (subtractive); over
  alpha ≥ 1 it goes through `CalculateNewBlendModes()`, which multiplies. The canvas is a zeroed
  FreeImage bitmap, so every text pixel takes the subtractive branch.
- **What you see:** at text opacity 128 a glyph edge with coverage 128 gets alpha 1 (64 on the other
  branch); thin, jagged text, unlike the GDI+ renderer. Negligible at the default opacity 250.
- **Evidence:** reading + reviewer harness — confirmed.

### 25. The effects brush's blur paints nothing on normal images at wetness ≥ 10
- **Where:** `qpv-main.cpp:9200-9205` (`halfW/halfH` include `|bulgePinchFactor|`) and 9320-9347 (the ROI —
  the region of interest it blurs — is clamped to the image, not to the locked Mat; `srcMat(roi)` has no
  try/catch); ahk:78819 (type-5
  padding `size//2+2+blur+10` has no wetness term).
- **What's wrong:** once the ROI leaves the locked Mat, OpenCV's `Mat(Mat, Rect)` assertion throws a
  cv::Exception out of the `extern "C"` export.
- **What you see:** the Blur effect brush paints nothing (or only now and then), with no message; the
  wet-brush toolbar preset sets wetness to exactly 10 and the slider is only greyed out for this brush.
  Huge images are fine.
- **Evidence:** arithmetic + reviewer harness applying OpenCV's exact assert condition (1440/1600 stamps
  throw at wetness 10, all at ≥ 11); likely (OpenCV itself not run).

### 26. Inverted freeform selections land shifted on huge images
- **Where:** `qpv-main.cpp:1872-1873` (`clipMaskFilter`, inverted `EllipseSelectMode==2` branch).
- **What's wrong:** the mask row is `y−imgSelY1−polyY`; the non-inverted branch (fixed in 52b9183) and
  `FillMaskPolygon()` both add `polyOffYa`.
- **What you see:** with a freeform/vector selection that extends d px above the image top
  (LimitSelectBoundsImg off) and "invert" on, the protected area is d−1 rows off the outline (fill,
  erase, blur, colour adjust, grayscale, brush outside selection).
- **Evidence:** arithmetic + reviewer harness; likely (the non-inverted branch is the documented model).

### 27. Heap writes past the selection mask with "Separated line segments"
- **Fixed in `1774b87`**, with #11: a window wholly off the mask returns before touching it.
- **Where:** `qpv-main.cpp:1765, 1778-1780` (`mergePolyMaskIntoHighDepthMask`).
- **What's wrong:** a subpath lying wholly below mask row 0 makes `mh` negative; `rend + 1` is then a
  negative INT64 turned into a huge `size_t`, `fill_zero()`'s `start >= end` test passes, and its
  middle loop zeroes words far past the buffer.
- **Trigger:** narrow — separated segments on, LimitSelectBoundsImg off, lines past all four image edges,
  one subpath lying between (stroke radius + 3) and (`tk` − 1) px below the bottom.
- **What you see:** an access violation swallowed by DllCall, or silent heap corruption for small masks.
- **Evidence:** reviewer harness under ASan (heap-buffer-overflow write in `fill_zero`) — confirmed.

### 28. Collection pool: a failed grey effect stores the blue channel as the fingerprint
- **Where:** `dupes-pixels.h:581-582` (status of `GdipBitmapApplyEffect` ignored; NULL `fx.gray`
  skipped silently), 236-241.
- **What you see:** under memory pressure, rows are written as successes (DP_OK) with fingerprints of the colour
  image's blue channel; they are never re-collected, so duplicates by hash/MSD are missed or invented
  for them until a purge.
- **Evidence:** reading + reviewer harness — confirmed path; needs an allocation failure.

### 29. Collection pool: a new run cannot finish while the previous run's decodes are still running
- **Where:** `dupes-pixels.h:1428` (the idle test uses `inFlight`, which counts jobs of every
  generation).
- **What you see:** abort a collection and start another at once: the new run's rows are written in
  milliseconds but it reports done only when the abandoned decodes end; with a decoder that hangs, every
  later run in the session hits the 180 s "workers stopped responding" error and the sort/dupes step is
  dropped.
- **Evidence:** reviewer harness (2984 ms vs 50-103 ms) — confirmed mechanism.

### 30. A crash at exit when a FreeImage decode outlives the 5 s shutdown wait
- **Where:** `thumbs-pool.h:2108-2147` (detach, return 0), `freeimage-dynamic.h:144` (`GetModuleHandleW`
  takes no reference), ahk:4436-4438 (return ignored, then `FreeLibrary` on FreeImage.dll);
  `dupesPixShutdown()` (dupes-pixels.h:1487-1504) has the same shape.
- **What you see:** closing QPV during thumbnail generation of a big TIFF/PSD/EXR (or a slow share) →
  a 5 s pause, then an access violation on the abandoned worker ("stopped working" at exit).
- **Evidence:** reading; plausible-to-likely. Fix: pin FreeImage (`GetModuleHandleExW` with
  `GET_MODULE_HANDLE_EX_FLAG_PIN`) or skip the unload when shutdown returns 0.

## Low

### 31. Tolerance flood fill does nothing when the fill colour equals the clicked colour
- **Where:** `qpv-main.cpp:2934-2935` (`FloodFill8Stack`). The "avoid infinite loop" early return is a
  leftover from the scanline fill; this one has a visited bitmap.
- **What you see:** fill white at tolerance 20 on a near-white area clicked on a pure-white pixel:
  nothing changes ("Replace anywhere" does flatten it); on a huge image the error beep and "Failed to
  apply the flood fill".

### 32. Tolerance flood fill paints the clicked pixel even when it is outside the selection
- **Where:** `qpv-main.cpp:3013-3016` — the seed is force-matched, and the only way a seed fails
  `checkPixel()` is the selection mask. Huge images, "Flood inside/outside": one pixel changed on the
  wrong side, occasionally a whole fill started from just outside the edge.

### 33. "Replace similar colors anywhere" ignores the fill opacity at tolerance 0
- **Where:** `qpv-main.cpp:2772-2776` (`mixColorsFloodFill`): `0/0` → NaN → `(unsigned char)NaN`
  (undefined; 0 on MSVC x64 = full strength). Only with "L*a*b-based grayscale" (the one algorithm that
  passes tolerance 0 through), dynamic opacity left ticked (the panel disables it below 3 but keeps the
  value) and opacity < 255 or a blend mode.

### 34. "Avoid clamping" with contrast makes a hard edge where a channel goes negative
- **Where:** `qpv-main.h:628-634` (`contrast()`, noClamping): the slider value is folded into a
  per-pixel offset when a channel is below 0, and the shifted grey is never shifted back.
- **What you see:** Brightness −20000, Contrast +20000: (200,120,78) → (94,0,0) but (200,120,77) →
  (16,0,0); the clamped path gives (116,11,0) for both. Reviewer harness — confirmed.

### 35. Small negative hue values skip the fade-in that positive ones get
- **Where:** `qpv-main.cpp:4590-4591` turns −5 into 355 before `hueRotate()` (qpv-main.h:766-776), whose
  fade-in covers −15..15 only. (255,0,0): +5 → (255,6,0), −5 → (255,0,20).

### 36. Gamma correction with opacity < 255 darkens 31 shadow levels by one per application
- **Where:** `qpv-main.cpp:252` (`int_to_char` truncates) with the 16-bit gamma tables (257-260), via
  `pixelRGB` (4553-4557) and the alpha table (4659). Neutral sliders, opacity 200: 2→1, 7→6, 9→8 ...
  118→117; repeated edits accumulate. Reviewer harness — confirmed.

### 37. Pixelate (default method) averages colours without alpha weighting
- **Where:** `qpv-main.cpp:3843-3986` (`PixelateBitmap`). Fully transparent pixels are pre-filled by
  `PrepareAlphaChannelBlur()`, so only semi-transparent ones bleed: two opaque black + two white at
  alpha 10 → grey 127 instead of ≈10.

### 38. The effects brush's blur bleeds hidden colour into cut-out edges
- **Where:** `qpv-main.cpp:9341-9350` (`cv::blur` on the straight-ARGB ROI), used at 9837-9849; the 4-tap
  bilinear samplers at 9915-9919 and 9967-9971 do it slightly too.
- **What you see:** an edge between opaque black and transparent white, blur 10: up to 311 opaque pixels
  lightened (to RGB 121). Reviewer harness — confirmed.

### 39. Hamming/MSD lower bound above the upper bound finds nothing
- **Where:** `dupes-search.h:1331-1334` (`dupesInRange` needs lo ≤ hi; AHK's `isInRange()` swaps).
  "Change hashes threshold" with Lower 5 / Upper 2 → "Found no duplicate images"; the old code filtered
  2..5. (`tests/filter_oracle.cpp` transcribed `isInRange()` without the swap, so it cannot see this.)

### 40. Hash-generation and collection errors show another connection's SQLite message
- **Where:** `dupes-search.h:1662-1673` (`dupesSetError` always reads `errmsg16(dupesDB)`, the
  engine's read-only connection), called from 2489, 2496, 2525, 2599 and dupes-pixels.h:988, 1300, 1334,
  whose statements live on AHK's connection. Journal shows "…: not an error" or no reason at all.

### 41. `RenderPdfPageAsBitmap` does not check `GdipBitmapLockBits`
- **Where:** `qpv-main.cpp:7195`. On failure `bitmapDatu` (no constructor, so not even /sdl zeroes it)
  hands PDFium an uninitialised `Scan0`/`Stride`; the PARGB-as-ARGB lock needs a second full-size
  buffer, so a large page at high DPI under memory pressure can make it fail → access violation or
  stray writes. Same defect as the one fixed in `WICbmpSourceConvertGdip()`. `BYTEconvertGdip()`
  (6448) ignores the same status too; there a failed lock only yields a blank bitmap.

### 42. An OpenCV tone-mapping exception leaks two bitmaps and skips the fallback in the pools
- **Where:** `qpv-main.cpp:5171-5211` (no try/catch), `thumbs-pool.h:1280-1301`, 1525-1537.
  "F. Drago (OpenCV)" on an all-black EXR/HDR/PFM: `CV_Assert(max > 0)` throws; `tpRunJob()`'s catch
  shows a broken tile, leaks `dib` and `out` (~0.5 MB) on every listing and never tries FreeImage's tone
  mapper; the viewer is fine (DllCall catches it). Reviewer harness — confirmed propagation and leak.

### 43. PDF thumbnail jobs keep rendering after a cancel or shutdown
- **Where:** `thumbs-pool.h:1655-1662`, `dupes-pixels.h:452`: the generation is checked before the slot
  wait but not after `tpPdfMutex` is acquired, so queued PDF renders run one after another after the
  page was abandoned — delaying the next page, widening #7 and pushing exits into #30.

### 44. Very wide or tall images are thumbnailed at full size by WIC
- **Where:** `thumbs-pool.h:784-808` with `adaptImageGivenSize()` (qpv-main.cpp:5585): above an aspect
  ratio of 2×thumbSize (500:1 at 250 px) the short side rounds to 0, the scaler is dropped, and the full
  image is delivered and cached as the "thumbnail". Likely; rare.

### 45. `MaskBitMap::resize()` reports the new size after a failed allocation
- **Where:** `qpv-main.h:68-69` sets `num_bits` before `data.assign()`. After a `bad_alloc` (caught in
  `initBoolMaskData`, `prepareDrawLinesMask`) every `s == size()` guard passes over an empty/old
  buffer; a later cached use reads past it. Needs memory exhaustion.

### 46. Smaller items
- `qpv-main.cpp:5631` `adaptImageGivenSize()` multiplies `size[0]*size[1]` as UINT: ≥ 4.29 Gpx images
  skip the 536 Mpx cap and fail to load instead of loading downscaled.
- `qpv-main.cpp:6950-6962` link annotations: `char` sign-extends non-ASCII URI bytes (U+FFC3…); URIs of
  1024 bytes or more come back empty.
- `qpv-main.cpp:7724-7725` `PdfWriterAddBitmap()` never caps the raster at JPEG's 65 500 px: "Same as
  the image" pages ≥ 328 dpi of a 70 000-px-wide image are refused ("Failed to add 1 images").
- `qpv-main.cpp:4881-4886` `openCVdiffBlendBitmap()`: an offset ≥ the selection's size gives an empty
  ROI → cv::Exception after `convertTo` already changed the bitmap (≤ 3 px selections).
- `qpv-main.cpp:5407` `UndoAiderSwapPixelRegions()` allocates per row inside an OpenMP loop; a
  `bad_alloc` there terminates the process.
- `qpv-main.cpp:1364/1444` live preview of round-join lines: `cv::polylines` asserts thickness ≤ 32767,
  reached at extreme thickness × zoom (no preview, journal error; applying is fine).
- `qpv-main.cpp:5662-5667` `WICdestroyPreloadedImage()` releases with `SafeRelease`, not the
  crash-guarded `WICsafeRelease` the file's own rule asks for after a decode began.
- `dupes-search.h:2109-2133` a `bad_alloc` part-way through a row of `dupesQueryStep()` leaves the
  candidate vectors at different lengths; `dupesScanBuildFromQuery()` then indexes past them.
- `thumbs-pool.h:1985` / dupes-pixels.h: `cfg->allowWIC` is parsed and never read — unticking "Allow WIC
  loader" does not keep either pool off WIC.
- `thumbs-pool.h` PDF branch: every PDF failure (corrupt, missing, no pages) is reported as
  `TP_ERR_PDFLOCKED`, so the journal says "password protected".

## Seen on the AHK side while tracing (not DLL code)
- `generateViewPortPDFbookmarks()` (ahk:75120, 99553) runs after every WIC-loaded image, so the viewer
  asks PDFium to open every JPEG/PNG/TIFF it shows — wasted I/O, and one more way into PDFium for #7
  (a small one: a non-PDF fails at the header). **Fixed in `f4d01a9`**, with #7: it opens
  `.pdf` files only.
- `HugeImagesApplyAutoColors()`: "Both" runs pass 2 against the small copy made before pass 1 stretched
  the image (ahk:21233, 21252-21256), so levels are stretched twice (input 90 → 9, 150 → 255; the normal
  path gives 64 and 191); "Image contrast" there reads the green channel of a colour copy instead of a
  grey one.
- `changeHdistLevelCached()`'s `maskKey` (ahk:86574) does not change when entries are deleted — half of #15. **Fixed in
  `33e3611`**, with #15: the deleted bit is refreshed on every pass.
- The paint brush loads `brush-texture-<BrushToolTexture>.png` when painting (ahk:78440) but
  `<BrushToolTexture - 1>` for the panel preview (ahk:77748); the list starts with "Soft circle", so the
  preview is right and every textured stroke paints the next texture — "Vertical dots" finds no file and
  paints a plain circle.
- Add noise sizes its small bitmap with the blur panel's `BlurAreaInverted` (ahk:22361-22362) — half of #10. **Fixed in
  `ad3f998`**, with #10.
- `QPV_PrepareHugeImgSelectionArea()` takes `zkw`/`zkh` for the freeform offsets (`ppofYb` etc.) from
  `useGdiBitmap()`, which is `gdiBitmap` or `UserMemBMP`, not the huge image; whether their size matches
  a huge image's was not checked. The #10 fix does not depend on it: AHK adds the same `ppofYb` to
  `y1` and to `polyOffYb`.

## Checked and found correct
By the reviewers, with harnesses: `FloodFill8Stack` traversal (4000-run differential against a BFS
reference); CIEDE2000 against the 34 Sharma–Wu–Dalal pairs (≤ 4.9e-5); blend modes 1–19 and 22 against
their formulas, and the lookup tables within ±1; `MaskBitMap` range setters for every start/end pair in
0..299; `fillMaskPolyBounds` race-freedom (TSan); the polar transforms (ASan, round trip); the collection
pool's results, statements, binds and wake-ups (TSan); `tpRunJob`'s FreeImage path against the real fork.
By the reviewers, by reading: `ReplaceGivenColor`'s reduction; `NewDrawLinesOnMask` index maths,
degenerate segments and parallel lines; `traverseCurvedPath`; `dissolveBitmap`/`symmetricaBitmap`;
`PdfWriterAddBitmap` lock/unlock and composite; FillSelectArea outside the JIT path; AdjustImageColorsPrecise's
table conditions and slider bounds; WIC↔GDI+ pixel format pairs (no premultiplied/straight mismatch); the
WIC guarded helpers and `WICcodecCrashFilter`; `initWICnow` (runs once; `threadIDu` unused); the
thumbnails slot throttle, generation/cancel and condition variables; the dupes union-find, record layouts
against AHK's NumGet offsets, `buildRowKey`, statement finalisation.
By me: `rotateBlurBitmap`; the file-time conversion; pdf-writer.h's Windows file handling; and every one of
the 205 literal `DllCall`s into qpvmain.dll (plus the dynamic ones) against its export signature —
argument count and widths all match.

## By design, so not listed
- The ORDER BY sort inside the first `dupesQueryStep()` cannot be cancelled: the Escape poll in
  `dupesProgressCB()` was reverted in c00bf82 (2026-09-03).
- The skewed CIE LAB thresholds in `toLABf()`/`toLABfx()` ("intentionally chosen value", restored in
  8f5cbb4); they make ΔE non-monotonic near black and `RGBtoGray()` mode 2 return 0..452.
- The five `pixels_smoke` failures ("a WIC failure falls through to GDI+").
