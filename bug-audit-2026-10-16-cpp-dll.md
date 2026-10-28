# C++ QPV DLL Deep Code Audit & Bug Report

## Verification (2026-10-27)

Every claim below was checked by Claude (Opus 5.5) on 2026-10-27 against the `development` branch at c695da0. The
report's 37 sections hold 69 separate claims; the table numbers them one per row (1.1.1, 1.1.2, ...). The
report's own text further down is left as Gemini wrote it, apart from one "Verified" line under each section heading.

**Outcome:** 12 of the 69 claims are real bugs that a user can trigger today: 2 of medium severity, 10 low. Another 25 are real in the DLL code but nothing in the app triggers them now ("latent"). 14 are not bugs, 11 describe deliberate or already known behaviour, and 7 concern CImg code removed after the report was written. Of the 17 sections the report rates critical or high (its summary says 18), only three hold in the app (1.2.1, 4.5.1, 5.2), none of them as a likely crash.

**How the claims were checked.** The DLL builds only with MSVC on Windows, so each claim was checked in three steps:
1. **Code:** read at HEAD, together with the AutoHotkey code that calls it.
2. **Run:** the shipped DLL functions were cut out of the source files unchanged and compiled with g++ into small test
   programs that stand in for the Windows APIs.
3. **Sanitizers:** compiler checks that stop a test program on bad behaviour:
   - **ASan** (AddressSanitizer): a read or write outside a buffer.
   - **UBSan** (UndefinedBehaviorSanitizer): undefined behaviour such as an out-of-range float conversion.
   - **TSan** (ThreadSanitizer): two threads touching the same data without a lock.

Some claims ran against real libraries instead of stand-ins: the duplicates engine against a real SQLite, the EXIF
claim against the FreeImage fork's own build, and the Insert text case (1.2.1) through the repo's prebuilt
qpvmain.dll under Wine. PDFium, OpenCV and Direct2D behaviour is quoted from their sources and documentation. The test programs and their outputs are in `.claude/scratch/gemini-audit-2026-10-27/`, which git
ignores. Nothing was run in the app itself; a fix still needs a qpvmain.dll build and a Windows check.

**Verdicts used in the table:**
- **Confirmed:** the defect is real, it was reproduced, and something a user can do in the app triggers it today.
- **Confirmed, latent:** the defect is real in the DLL code and was reproduced, but no current caller in the app
  passes the input or creates the condition that triggers it. Such items only matter if a caller changes.
- **Not a bug:** the claim misreads the code, or the consequence it describes does not follow.
- **Intentional or known:** the behaviour is a documented decision or an already known limitation (commit cited).
- **Obsolete:** the code was removed or rewritten after 2026-10-16, and its successor does not have the problem.
- A sixth verdict, "Not verifiable here" (behaviour that only Windows can show), turned out not to be needed. The one
  claim that leans on Direct2D (4.6.2) is settled by its callers.

**How far the report can be trusted:**
- **Quotes:** of the 100 lines it presents as code (in 23 sections), 66 do not exist in the source it audited (42ed05e),
  even ignoring whitespace. Some are harmless paraphrases. Others describe code that is not there at all, such as a
  `BrushCtx` struct, a `tpRunning` flag, a `tpFIMload` function, an `extractChannel` call removed in 2024, Sobel and
  Laplacian modes in openCVblurFilters, or a "path-splitting loop". Its line numbers for the `lib/` headers are
  approximate.
- **Crashes:** several "crash" claims assume an exception kills the process. AutoHotkey's DllCall runs each call under
  `__try/__except` (AutoHotkey v1.1 source, script2.cpp), so a C++ exception thrown on the script thread only sets
  ErrorLevel. It ends the process only on a DLL worker thread or inside an OpenMP region.
- **Races:** since the interface-thread merge the app has a single AutoHotkey thread, so a race between two exports
  needs a second thread that no longer exists.
- **Already settled:** some items were documented decisions before the report was written. The LAB constants were
  restored on purpose in 8f5cbb4. The blank WIC tile was left on purpose on 2026-08-12. The 10-06 audit had already
  recorded clipMaskFilter's mask-bitmap case (#26) and the full-size thumbnail fallback (#44).

**The confirmed bugs, most important first:**
1. **2.2 (Medium):** "Swap blended layers" together with "Protect alpha channel" makes blend modes 2..21 ignore the
   new layer's opacity. The paste opacity slider, soft brush edges and antialiasing are lost in paste-in-place, brush
   types 2/3/5/7/8, fill, text and draw lines. Cause: the `mix` rule in CalculateNewBlendModes() was written for
   unswapped layers. Detect edges forces Protect alpha on, and the huge-image noise always passes it, so there
   "Swap blended layers" alone voids the opacity slider.
2. **1.2.1 (Medium, cosmetic):** huge-image Insert text with letter spacing below -10. The canvas is sized from the
   squeezed width, but lines and backgrounds are drawn at full width, so DrawTextBitmapInPlace() wraps a strip into the
   next row. The GDI+ renderer squeezes the line instead.
3. **Low:**
   - 2.8: the smudge brush can index a blend table at 256 (assuming MSVC rounds floats as the g++ test build did).
   - 3.6.1: "Flood opacity based on color similarity" does nothing at 100 % opacity.
   - 5.2: the thumbnail format lists are read by the workers without the lock.
   - 5.3.1: JPEG thumbnails ignore EXIF orientation with "Always open with FreeImage".
   - 5.3.2: high-bit-depth TIFF thumbnails skip FreeImage.
   - 5.3.4: "vmin" is read as inches (DLL and AHK).
   - 6.3: the MSD (mean squared difference) threshold is skipped for a single pair.
   - 6.4: the rarest level of a solid-colour image is wrong.
   - 4.5.1: a 0-px-wide PDF page triggers undefined behaviour.
   - 1.6.2: the dissolve blur applies an empty bitmap when memory runs out.

**Fixed on 2026-10-28.** The DLL changes take effect with the next qpvmain.dll build.
- **2.2 (lib/blend-modes.h):** with the layers swapped and Protect alpha on, the new layer's alpha weighs the swapped
  blend against the image's own colour, as it does without the swap. Every other combination is byte-identical, and
  swapping no longer changes the commutative modes, marked * in the blend-mode list (Hard mix aside: its table is
  itself asymmetric in 190 cells).
- **1.2.1 (quick-picto-viewer.ahk, qpv-main.cpp):**
  - Both Insert text renderers align, size and back each line by its squeezed width.
  - The huge-image renderer squeezes the line and border bitmaps as the preview draws them.
  - The preview loses three quirks with letter spacing below -10: right-aligned shorter lines lost a strip at their
    right end, centred ones sat off-centre, and backgrounds kept the unsqueezed width.
  - DrawTextBitmapInPlace() clips at the canvas edges instead of wrapping into the next row.
- **3.4b (lib/selection-mask.h, quick-picto-viewer.ahk):** not a visible defect (see its row). NewDrawLinesOnMask()
  shifts a copy of the points, and both huge-image line tools pass 0 instead of diffThick; the output is unchanged.
  The two halves belong together: the new AHK with an older qpvmain.dll offsets the second line.

**Found while checking, not in the report:**
- **A stale undo level (possible heap overflow; traced in code, not run).**
  - **Mechanism:** the huge-image undo level is cleared when a file is loaded, but not by
    downscaleHugeImagesForEditing() or convertImageIntoHugeImage(). Both replace the viewport image without loading a
    file. undoRedoHugeImagesAct() then applies the old level to whatever image is current, checking only the colour
    depth.
  - **Effect:** with a smaller new image, UndoAiderSwapPixelRegions() (1.6.1) writes outside it; otherwise the old
    pixels are pasted into the new image.
  - **To test on Windows:**
    1. Open a huge image and apply a filter to a selection near its far edge.
    2. Downscale it for editing.
    3. Convert it back to a huge image, or enlarge it in the resize panel.
    4. Press Ctrl+Z.
- **Noise and "Protect alpha channel" (code reading):** GenerateRandomNoiseOnBitmap() ignores its keepAlpha argument
  (qpv-main.cpp:578 and 622 pass 1), so on huge images the noise tool's checkbox has no effect.
- **Pixelate alpha (code reading):** pixelate sets the alpha to the mean of the alpha levels present, not the most
  common one (avgLevel in lib/Gdip_All.ahk, used at quick-picto-viewer.ahk:24187). A mostly opaque selection with a few
  transparent pixels gets alpha 127, so the pixelation lands at half strength.
- **2.9 reaches further than 72aeac1 says:**
  - With Double size and Random size on a huge image, about a third of pinch and bulge strokes at size 990 pass the
    150 MB limit.
  - The commit's "the same as for the smudge" is out of date: since 2026-10-11 the smudge refuses to paint without its
    copy.
- **Curve hover highlight (cosmetic):** traverseCurvedPath()'s hover highlight starts one flattened point before the
  segment it marks.
- **"Protect alpha" with "No blend mode" behaves differently per tool:**
  - Paste-in-place turns it into Clip to alpha.
  - Draw lines does not (since eb7ea93).
  - Brush types 2/3/5/7/8 ignore it.
  - The smudge honours it.

  A consistency question rather than a DLL defect.

**The claims one by one.** Item numbers follow the report's sections; a third number or a letter marks one claim
within a section. "Sliced DLL code" means the shipped function compiled unchanged into a test program.

| Item | Claim | Verdict | How it was checked | Note |
| --- | --- | --- | --- | --- |
| 1.1.1 | PrepareAlphaChannelBlur pass 1 gives leading transparent pixels alpha before pass 2 (black halos) | Confirmed, latent | Run, sliced DLL code | Real in the DLL, but the only live call with fillMissingOnly 0 gets a bitmap that the call before it already filled, so no halo appears; the other such call is dead code. |
| 1.1.2 | Same with givenLevel 0: opaque black loses alpha and is recoloured | Confirmed, latent | Run, sliced DLL code | Only changes hidden colour under zero alpha; the one caller passes level 0 only for already transparent selections. |
| 1.2.1 | DrawTextBitmapInPlace has no per-row bound, so text past the right edge wraps into the next row | **Confirmed** | ASan, sliced DLL code; real qpvmain.dll under Wine | On huge images, Insert text with letter spacing below -10 makes the canvas narrower than its lines, so line backgrounds wrap a strip into the next row. Writes stay inside the canvas. The "o == data" point is wrong. Medium. Fixed 2026-10-28. |
| 1.2.2 | DrawTextBitmapInPlace's alpha-0 shortcut ignores Protect alpha, layer swap, blend mode | Intentional or known | Run, sliced DLL code | Accurate, but the shortcut is scoped on purpose to modes 0 and 5 (62ff06f, 10-06 audit #24), which are all the text tool uses; only hidden colour under zero alpha differs. |
| 1.3.1 | CImg noise/blur ignore Stride | Obsolete | Run, successors | CImg was removed (5101af2); the blur export was already dead on 10-16. The successors honour Stride. |
| 1.3.2 | CImg noise also noises alpha | Obsolete | Run, successor | The replacement leaves alpha and fully transparent pixels untouched. |
| 1.3.3 | CImg blur: preview halving gives a 0-size kernel | Obsolete | Code reading | Dead code even when reported (no live caller), now deleted; the OpenCV replacement has no preview halving. |
| 1.3.4 | CImg blur: "circle" blurs every mode | Obsolete | Code reading | Deleted; in the OpenCV replacement "circle" only selects the kernel shape. |
| 1.4.1 | CImg plasma noise reads uninitialised floats (NaN) | Obsolete | Run, successor | The new plasma generator writes every grid point before reading it. |
| 1.4.2 | CreateGdipBitmapFromCImg returns a blank bitmap when locking fails | Obsolete | Code reading | The function is gone; the AHK wrapper now disposes the bitmap and reports the failure. |
| 1.4.3 | CreateGdipBitmapFromCImg: unchecked UIntMult, 32-bit row offset | Obsolete | Code reading | The function is gone; the replacement computes row offsets in 64-bit. |
| 1.5 | Zoom/rotate blur leave the caller's source alpha-weighted | Intentional or known | Run, sliced DLL code | Deliberate memory saving (e6f3ddd); the source is documented as consumed and both callers discard it. |
| 1.6.1 | UndoAiderSwapPixelRegions does not clamp its rectangle (out of bounds) | Confirmed, latent | ASan, sliced DLL code | No clamps, but the claimed trigger cannot happen: the undo rectangle is a crop FreeImage accepted from the same image. See "a stale undo level" below for a path that may reach it. |
| 1.6.2 | dissolveBitmap lets std::bad_alloc escape the export | **Confirmed** | Run, sliced DLL code (failing allocation) | Only when memory runs out: DllCall catches the exception, but QPV_DissolveBitmap ignores the failure and the blur tool applies an unwritten bitmap. Low. |
| 1.6.3 | dissolveBitmap / symmetricaBitmap index in 32-bit int | Confirmed, latent | UBSan, sliced DLL code | Overflows above 2.1 gigapixels, but both exports only get GDI+ bitmaps, which the app caps at 537 megapixels. |
| 2.1.1 | Protect alpha ignored in Normal (blend mode 0) | Intentional or known | Run, sliced DLL code; git history | Accurate, but Marius excluded Normal on purpose (eb7ea93, 2025-03-24); the checkbox tooltip says "unaltered by blend modes". |
| 2.1.2 | Protect alpha ignored in Behind (mode 25) | Intentional or known | Run, sliced DLL code; git history | Accurate, but deliberate (9df5106, 2025-03-17): Behind exists to paint under transparent pixels, which raises their alpha. |
| 2.2 | Swap blended layers + Protect alpha in modes 2..21 ignores the new layer's opacity | **Confirmed** | Run, sliced DLL code (all 40 mode/gamma cases) | With both boxes ticked, a layer at alpha 10 blends like alpha 255: the opacity slider and soft edges are lost in paste, brush, fill and text. Medium. Fixed 2026-10-28. |
| 2.3.1 | toLABfx epsilon wrong, RGBtoGray reaches 452 | Intentional or known | Run, sliced DLL code; git history | White does give 452, but Marius restored this constant on purpose (8f5cbb4, 2026-07-18, "intentionally chosen value"). |
| 2.3.2 | toLABf epsilon has an extra e-3 (discontinuity) | Intentional or known | Run, sliced DLL code; git history | The jump (0.138 to 0.021) is real, but restored on purpose in the same 8f5cbb4. |
| 2.4 | Tint reads 65536-entry tables out of bounds after black/white point noise | Confirmed, latent | ASan, sliced DLL code | Real order (tint before the final clamp), but needs black point >= 62937 or white point <= 2598; the sliders stop at 45535 / 20100, so only a hand-edited registry value reaches it. |
| 2.5.1 | Contrast stage 2 uses the unfaded mix | Not a bug | Run, sliced DLL code | Stage 2 does read the unfaded mix, but the output is continuous and matches the clamped path from 16000 up; the proposed change would make the two modes disagree. |
| 2.5.2 | Contrast level >= 16000 discards the 16000..19500 fade | Not a bug | Run, sliced DLL code | That stage-1 fade is dead code there, but nothing visible is lost: no jump at 16000 or 19500. |
| 2.6 | Smudge brush with a clone buffer reads an empty copy (null pointer) | Confirmed, latent | ASan, sliced DLL code | The smudge crashes if handed a clone buffer, but the app passes one only to the cloner brush, never to the smudge. |
| 2.7.1 | Brush chunk cache ignores a change of bits per pixel (heap overflow) | Confirmed, latent | ASan, sliced DLL code | The cache is keyed on the chunk count only, but the app clears it at every stroke's start and end, so it never meets a different image. |
| 2.7.2 | Brush chunk cache ignores a change of grid shape (out-of-range chunk) | Confirmed, latent | ASan, sliced DLL code | Same per-stroke reset as 2.7.1, so the out-of-range chunk index never happens. |
| 2.8 | Smudge sample can reach 256 and index 256-entry tables | **Confirmed** | ASan + UBSan, full PaintBrushLarge smudge | Smudging with a blend mode across transparent edges of 32-bit images occasionally yields 256: one wrong pixel (another mode's value, or a read past the table), no crash. The report's all-255 example is wrong. The reproduction assumes MSVC rounds floats as the g++ build did; not run on Windows. Low. |
| 2.9 | Cloner/pinch/bulge without a copy race the painting threads | Intentional or known | Run, sliced DLL code (8 threads) | Documented in 72aeac1: past a 150 MB sampled box a huge image is read directly. Reachable only with Double size plus Random size; nondeterministic pixels, no crash. |
| 3.1 | Cached mask kept while the mask window grows (out-of-bounds read) | Confirmed, latent | ASan, sliced DLL code | Reproduced by calling the DLL directly; the app reuses the cache only for an identical selection, or right before prepareDrawLinesMask(), which resizes it. |
| 3.2.1a | highDepth never reset by prepareSelectionArea (stale depth mask read out of bounds) | Confirmed, latent | ASan, sliced DLL code | Reproduced in the DLL; the high-depth flag exists only inside the parametric-lines tool, which clears it before any new selection is prepared. |
| 3.2.1b | Stale highDepth inverts rectangles/ellipses outside the box | Not a bug | Code reading | In high-depth mode the value is an opacity, so 0 outside means "leave untouched"; high depth always comes with a freeform shape. |
| 3.2.2 | Mask resize failure unchecked, empty mask read | Not a bug | Code reading | Failures are caught: the polygon path falls back to a rectangle and returns 0, the lines path returns 0, and the AHK stops on 0. |
| 3.2.3 | Same-size depth mask reused without zeroing | Confirmed, latent | Run, sliced DLL code | Reproduced in the DLL; the only high-depth tool empties the depth mask at the end of every run. |
| 3.3 | clipMaskFilter row shift with a mask bitmap reads before the bitmap | Confirmed, latent | ASan, sliced DLL code | Already recorded as latent in the 10-06 audit (#26): no caller passes a mask bitmap (the AHK variable is never assigned). |
| 3.4a | Line-merge window lacks the row offset and margin (stale mask bits) | Intentional or known | Code reading | The row offset is applied (10-06 fix #11); what remains is the known loss of miter tips beyond the merge margin. |
| 3.4b | NewDrawLinesOnMask shifts the caller's points in place | Confirmed, latent | Run, sliced DLL code with the AHK's arguments (540 cases) | The points are shifted in place, but the second "Double line" call passes diffThick as offsetY, and in both huge-image line tools diffThick equals that shift (the selection top is clamped to 0 first, so maskRowShift is 0 and diffThick is y1Push). The second line lands on the first. Cleaned up 2026-10-28. |
| 3.5 | traverseCurvedPath off by one, corrupts closed multi-path curves | Not a bug | Run, sliced DLL code | The loops the report describes do not exist; the returned insert position is correct. |
| 3.6.1 | Flood fill ignores dynamic opacity at 100 % opacity, Normal | **Confirmed** | Run, sliced DLL code | Long-standing: at opacity 255 with Normal blending, "Flood opacity based on color similarity" has no effect (254 fades, 255 paints solid). Low. |
| 3.6.2 | Semi-transparent fill colour overwrites instead of blending | Confirmed, latent | Run, sliced DLL code | True in the DLL, but the app always sends the fill colour with alpha FF. |
| 3.6.3 | Cartoon mode ignores opacity, blend mode, dynamic opacity | Intentional or known | Run, sliced DLL code; AHK panel | By design: cartoon mode fills with the clicked colour, and the panel disables those controls while it is on. |
| 3.7 | Flood fill selection test wrong with high-depth masks | Confirmed, latent | Run, sliced DLL code | True if a fill ran with a high-depth mask, but that mask exists only inside the parametric-lines tool, which clears it before returning. |
| 4.1.1 | Static colour-management COM pointers race across threads | Confirmed, latent | Code reading | Not thread-safe, but only the one script thread reaches them; the worker pools use their own per-call copy. |
| 4.1.2 | Source bitmap released before QueryInterface | Not a bug | Code reading | The query cannot fail: a WIC colour transform is itself a bitmap source; even then the load would just fail. |
| 4.2 | WICgetRectImage returns a blank 100x100 bitmap on failure | Intentional or known | Code reading | Accurate and already known (2026-08-12, left on purpose): a blank tile instead of an error; the bitmap is tracked, not leaked. |
| 4.3.1 | LoadWICimage `UINT *&resultsArray` ABI mismatch | Not a bug | Code reading | The only caller passes "UPtr*", &buffer, a pointer to a pointer, which is what the reference expects. |
| 4.3.2 | doFlipHV ignored when no resize is needed | Confirmed, latent | Code reading | True (the flip only happens on the resize path), but no caller ever asks LoadWICimage to flip. |
| 4.4.1 | CountChars -1 in a UINT: 4.29-billion-iteration loop | Not a bug | Reading + PDFium source | The text page is checked first, and PDFium returns -1 only for a missing text page; the quoted loop does not exist. |
| 4.4.2 | Text size query 1-2 units short, buffer overflow | Confirmed, latent | ASan, sliced DLL code + PDFium contract | The size can be short on malformed pages, but the only caller allocates eight times the reported size. |
| 4.4.3 | Pages with 1-2 characters skipped, buffer unterminated | Not a bug | Code reading | An explicit threshold; the caller zero-fills the buffer and does not read it when nothing was extracted. |
| 4.5.1 | adaptImageGivenSize divides by zero | **Confirmed** | UBSan, sliced DLL code | Undefined behaviour for a malformed PDF page 0 px wide in a contact sheet; on x64 it ends as a 1-pixel-high image, not a crash. Low. |
| 4.5.2 | dpi 0 skips the size cap (32650 x 32650) | Confirmed, latent | Code reading | dpi 0 means "exactly this size" by design; the 32650 fallback only applies when a size is missing, and no caller combines the two. |
| 4.5.3 | 24-bit stride not 4-aligned, bitmap creation fails | Not a bug | Code reading | The bitmap has no caller buffer, so GDI+ uses its own aligned stride; PDFium draws through the locked stride. |
| 4.6.1 | WicD2DrenderSVG does not check its factories for NULL | Confirmed, latent | Code reading | True, but the factories exist whenever the DLL loads; only an out-of-memory start-up could leave them NULL. |
| 4.6.2 | viewBox SVGs scaled twice | Not a bug | Code reading (Direct2D not run) | Both callers use a scale of 1 for missing, percentage and viewport-unit sizes, so the viewBox is scaled once. |
| 5.1.1 | Detached pool workers: use-after-free at DLL unload | Not a bug | Code reading | The pools shut down only on exit, and the app then terminates itself, so no destructor runs under a stray worker; the DLL is never unloaded early. |
| 5.1.2 | Detached worker revived by a pool restart | Confirmed, latent | Code reading | True only if a pool restarted after a timed-out shutdown; both pools start once and shut down only at exit. |
| 5.2 | Thumbnail format lists rewritten while workers read them | **Confirmed** | TSan, sliced DLL code | Real race, for a different reason than the report gives: the writer locks, the readers do not. Only the first duplicates scan of a session can hit it. Low. |
| 5.3.1 | FreeImage thumbnails ignore EXIF orientation | **Confirmed** | Run, real FreeImage fork | With "Always open with FreeImage" on, the viewer turns JPEGs upright but their thumbnails stay sideways. Low. |
| 5.3.2 | HDR TIFF hand-off to FreeImage is dead in the pools | **Confirmed** | Code reading | Every pool call passes 0, so high-bit-depth TIFF thumbnails come from WIC, not FreeImage's tone mapping as in the viewer. Low. |
| 5.3.3 | Scaler failure gives a top-left crop | Intentional or known | Code reading | No crop: the whole frame is decoded unscaled; that fallback is the 10-06 audit's item 44, whose cause was fixed in dcaaf28. |
| 5.3.4 | "in" tested before "vmin" in the SVG unit converter | **Confirmed** | Run, sliced DLL code | Real in the pool's converter and in the viewer's AHK twin: "10vmin" is read as 10 inches. svg-render.h has no converter. Low. |
| 5.4 | openCVdiffBlendBitmap copies before subtracting: black at offset 0 | Not a bug | Run, sliced DLL code (OpenCV stand-ins) | The copy builds the shifted operand; the filter is "shifted image minus image", so zero shift gives a flat result by definition. |
| 5.5.1 | openCVedgeDetection lets cv::Exception escape | Confirmed, latent | Reading + OpenCV source | No try/catch, but the panel always sends valid sizes and modes, and DllCall catches a throw on the script thread. The extractChannel part is code removed in 2024. |
| 5.5.2 | openCVblurFilters throws for Sobel/Laplacian kernels > 31 | Not a bug | Code reading | The function has no Sobel or Laplacian mode. |
| 5.5.3 | openCVresizeBitmapExtended crop outside the try | Confirmed, latent | Reading + OpenCV source | True, but every caller passes the whole image, so the crop rectangle is always valid. |
| 6.1 | dupesEngineCancel races Release/Init on the database handle | Confirmed, latent | TSan, sliced DLL code | True only with two threads; since the interface-thread merge every call comes from the one script thread. |
| 6.2 | An unusable hash splits a group and drops valid pairs | Confirmed, latent | Run, real SQLite + sliced engine | The flaw is real, but the app's query drops empty hashes and its writer only stores valid hex, so nothing triggers it. |
| 6.3 | MSD filter skipped when only one pair exists | **Confirmed** | Run, sliced DLL code | The two-pair rule is deliberate, but it also gates the search's own MSD threshold: a single-pair result is listed even above the threshold. Low. |
| 6.4 | Rarest level of a single-level image reported as level 0 | **Confirmed** | Run, sliced DLL code | Real, in the DLL and in the AHK original it copies: any solid-colour image above black stores level 0. Low. |


**Scope:** All C++ source and header files in `QPV DLL source code/` (`qpv-main.cpp`, `dllmain.cpp`, and `lib/*.h`). AutoHotkey (`.ahk`) files were excluded.

---

## Executive Summary

A line-by-line static audit of the C++ QPV DLL codebase identified **38 verified bugs** across the core image processing routines, blending/color adjustment engines, paint/smudge brushes, selection masks, flood-fill engine, WIC/PDFium/SVG loaders, thumbnail worker pool, OpenCV filters, and duplicate search engines.

| Severity | Count | Key Categories |
| :--- | :---: | :--- |
| **Critical / High** | 18 | Out-of-bounds memory reads/writes, thread data races & use-after-free on COM/SQLite/worker objects, null-pointer dereferences, 4.29B infinite-loop hang, uncaught C++ exceptions across `DLL_API` boundaries |
| **Medium** | 14 | Broken alpha propagation/protection, stride mismatches on 24-bpp/sub-rect bitmaps, in-place corruption of caller buffers, broken flood-fill `dynamicOpacity` and `highDepth` selection masking, double-scaled SVGs |
| **Low** | 6 | Resource leaks on error paths, dead code / unreachable branches in CIE LAB math, integer overflow edge cases on multi-gigapixel buffers, solid-color histogram edge case |

---

## 1. Core Image Processing (`qpv-main.cpp`)

### 1.1. [`PrepareAlphaChannelBlur`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L370-L418) — Pass 1 Overwrites Alpha Before Pass 2 Runs, Breaking Leftward Color Propagation and Corrupting Opaque Black Pixels (`fillMissingOnly == 0`)

> **Verified 2026-10-27:** Confirmed, latent (1.1.1, 1.1.2). The mechanism is real, but the only live call gets an already filled bitmap; the other call is dead code.

- **Severity:** Medium
- **Location:** [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L379-L416)
- **Root Cause:**
  `PrepareAlphaChannelBlur` performs two horizontal passes per scanline to bleed RGB colors from non-transparent pixels into completely transparent (`0x00000000`) pixels before blurring:
  1. **Pass 1 (left-to-right, lines 384–395):** Propagates the last seen non-zero RGB (`defaultColor`) into `0x00000000` pixels, and when `fillMissingOnly == 0`, immediately rewrites the pixel's alpha channel to `givenLevel`:
     ```cpp
     if (fillMissingOnly==0)
        imageData[px] = (givenLevel << 24) | (imageData[px] & 0x00ffffff);
     ```
  2. **Pass 2 (right-to-left, lines 399–416):** Scans backward to fill leading transparent pixels at the left of each row that existed before the first colored pixel on that row, testing `if (bgrColor == 0x0)`.
  - **Case A (`fillMissingOnly == 0` and `givenLevel > 0`, e.g., `255`):** Any leading `0x00000000` pixels on a row before the first colored pixel have `defaultColor == 0` during Pass 1, so line 394 rewrites them to `(givenLevel << 24) | 0x000000` (non-zero). When Pass 2 runs on the same row, `bgrColor == 0x0` (line 411) is `false` for all of those leading pixels. Pass 2 never propagates colors leftward, leaving opaque black (`0xFF000000`) halos on the left side of every object.
  - **Case B (`fillMissingOnly == 0` and `givenLevel == 0`):** Pass 1 strips the alpha channel on all pixels, turning legitimate opaque black pixels (`0xFF000000`) into `0x00000000`. Pass 2 then cannot distinguish them from originally transparent pixels (`bgrColor == 0x0`) and overwrites originally opaque black pixels with their right neighbor's RGB color.
- **Fix:** Apply the `fillMissingOnly == 0` alpha replacement (`givenLevel << 24`) only after Pass 2 completes (at the end of Pass 2), so Pass 2 inspects the unmodified alpha values.

---

### 1.2. [`DrawTextBitmapInPlace`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1256-L1316) — Missing Horizontal/Vertical Coordinate Bounds Check Causes Scanline Wrap-Around Corruption, Plus `oA < 1` Bypass of `keepAlpha` / `flipLayers`

> **Verified 2026-10-27:** 1.2.1 **Confirmed** (huge-image Insert text with letter spacing below -10 wraps line backgrounds into the next row; the "o == data" point is wrong); 1.2.2 Intentional or known (shortcut scoped to the text tool's modes, 62ff06f). 1.2.1 fixed 2026-10-28.

- **Severity:** High
- **Location:** [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1273-L1308)
- **Root Cause:**
  1. **Missing 2D coordinate bounds check (lines 1274–1278):**
     ```cpp
     INT64 ky = (INT64)(imgY + y) * Stride;
     for (int x = 0; x < imgW; ++x)
     {
          INT64 o = ky + (INT64)(imgX + x) * bpc;
          if (o > data || o < 0)
             continue;
     ```
     Because `o` is only checked against the flat 1D buffer range `[0, data]`, whenever the text bitmap extends horizontally past the left (`imgX + x < 0`) or right (`imgX + x >= w`) edge of the destination canvas (while `0 <= o <= data`), pixels wrap into the adjacent scanline (`imgY + y - 1` or `imgY + y + 1`) on the opposite side of the canvas. On 24-bpp images where `Stride > w * 3`, out-of-bounds horizontal coordinates also write into the stride padding bytes and misalign the B, G, R byte offsets across pixel boundaries. Additionally, `o == data` is allowed by `o > data` on line 1277 (only caught later by `o < data` on line 1285).
  2. **Broken `oA < 1` fast path (lines 1299–1307):**
     When `oA < 1 && bpp == 32`, the function bypasses `CalculateNewBlendModes` and directly writes `[nB, nG, nR, nA]` into `originalData`:
     - Ignores `keepAlpha == 1` (overwriting `oA == 0` with `nA > 0`, violating alpha lock).
     - Ignores `flipLayers == 1` and `blendMode` (e.g., Erase mode `23` or Multiply mode `2`).
     - Overwrites `originalData[o..o+2]` even when `nA == 0`.
- **Fix:** Check `if (imgY + y < 0 || imgY + y >= h) continue;` in the outer loop, `if (imgX + x < 0 || imgX + x >= w) continue;` in the inner loop, and remove the `oA < 1` bypass or guard it with `blendMode == 0 && keepAlpha == 0 && flipLayers == 0 && nA > 0`.

---

### 1.3. [`cImgAddGaussianNoiseOnBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1483-L1490) & [`cImgBlurBitmapFilters`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1591-L1658) — `Stride` Ignored on Input Construction, Alpha Channel Corrupted by Noise, and `preview == 1` Zero-Size Structuring Element

> **Verified 2026-10-27:** Obsolete (1.3.1-1.3.4). CImg was removed after the report (5101af2); the blur export was already dead on 10-16, and the successors do not have these problems.

- **Severity:** High
- **Location:** [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1485-L1488), [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1597-L1651)
- **Root Cause:**
  1. **`Stride` ignored when reading `imageData`:**
     Both functions construct `cimg_library::CImg<unsigned char> img(imageData, channels, width, height, 1);` (lines 1486, 1597), which reads `channels * width * height` tightly-packed contiguous bytes from `imageData`, completely ignoring `Stride`. On any 24-bpp GDI+ bitmap whose width is not a multiple of 4 (`Stride > width * 3`), or any sub-rectangle lock where `Stride > width * channels`, every scanline after `y = 0` is read at the wrong byte offset, shifting the image diagonally and rotating B/G/R channels across rows. `FillGdipLockedBitmapDataFromCImg` then writes the corrupted data back respecting `Stride`. Furthermore, if `Stride < 0` (bottom-up bitmap), `imageData` (`Scan0`) points to the last row and reading `width * height * channels` bytes forward reads out-of-bounds past the buffer.
  2. **Alpha channel corrupted in `cImgAddGaussianNoiseOnBitmap` (line 1487):**
     On 32-bpp images (`channels == 4`), `img.noise(intensity, 0)` adds random Gaussian noise across all 4 channels including alpha, making opaque pixels semi-transparent and transparent background pixels partially visible.
  3. **Zero-dimension structuring element when `preview == 1` in `cImgBlurBitmapFilters` (lines 1601–1616):**
     When `preview == 1`, `width /= 2; height /= 2; intensityX /= 2; intensityY /= 2;` are computed without clamping to `>= 1`. When `intensityX == 1` or `intensityY == 1`, integer division yields `0`, constructing an empty `0x0` `shape` `CImg` for `erode`/`dilate`/`opening`/`closing`.
  4. **Unconditional blur when `circle == 1` (line 1650):**
     `if (circle == 1) img.blur(3, 3, 0, 1, 3);` executes even when `modus` is not a morphological filter (`modus < 5 || modus > 8`), unexpectedly blurring Box/Gaussian/Median/Sharpen outputs whenever `circle == 1`.
- **Fix:** Copy `imageData` into the `CImg` buffer row-by-row using `Stride` (matching `FillGdipLockedBitmapDataFromCImg`), apply noise only to RGB (`img.get_shared_channels(0, 2)`), clamp halved preview dimensions/intensities with `std::max(1, ...)`, and guard the `circle == 1` post-blur to `modus >= 5 && modus <= 8`.

---

### 1.4. [`CreateGdipBitmapFromCImg`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1374-L1465) & [`GenerateCIMGnoiseBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1719-L1729) — Uninitialized `CImg<float>` Buffer, GDI+ Bitmap Leak on Failed `LockBits`, and Unchecked `UIntMult` / 32-Bit Row Offset Overflow

> **Verified 2026-10-27:** Obsolete (1.4.1-1.4.3). The CImg functions are gone; the plasma generator and its AHK wrapper do not have these problems.

- **Severity:** Medium
- **Location:** [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1378-L1414), [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1721-L1724)
- **Root Cause:**
  1. `GenerateCIMGnoiseBitmap` allocates `cimg_library::CImg<float> img(width, height, 1, 4);` without an initial fill value (`CImg`'s constructor does not zero-initialize pixel memory). `img.draw_plasma()` adds random variation onto the existing uninitialized floats in the buffer. If any uninitialized float bit pattern is `NaN`, the clamping checks in `CreateGdipBitmapFromCImg` (`if (redCompF < 0.0f) ... else if (redCompF > 255.0f)`) both evaluate to `false`, and `BYTE(redCompF + 0.4999f)` invokes undefined behavior.
  2. In `CreateGdipBitmapFromCImg`, if `GdipBitmapLockBits` fails (`res != Gdiplus::Ok` at line 1401), the function returns `myBitmap` directly without calling `GdipDisposeImage(myBitmap)` and returns an unpopulated blank bitmap instead of `nullptr`.
  3. At lines 1378 and 1382, `UIntMult(width, height, &uPlane)` and `UIntMult(uPlane, 2, &uPlane2)` ignore their `HRESULT` return values, and line 1414 computes `UINT dIndexDest = dLineDest * y;` in 32-bit `UINT` instead of `size_t`/`INT64`.
- **Fix:** Initialize the `CImg<float>` with `0.0f` (`CImg<float> img(width, height, 1, 4, 0.0f);`), use `!(val >= 0.0f)` for NaN-safe clamping, dispose and null `myBitmap` when `GdipBitmapLockBits` fails, and use `size_t` for `dLineDest * y`.

---

### 1.5. [`zoomBlurBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L2200-L2215) & [`rotateBlurBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L2494-L2508) — Source Buffer `imageData` Mutated In-Place When `bpp == 32` Has Semi-Transparent Pixels

> **Verified 2026-10-27:** Intentional or known. In-place weighting saves memory on purpose (e6f3ddd); both callers discard the source.

- **Severity:** Medium
- **Location:** [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L2209-L2214), [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L2503-L2507)
- **Root Cause:**
  Both functions take a read-only source buffer `imageData` and a destination buffer `newData`. However, when `bpp == 32` and `checkHasTransparency(imageData, w, h, Stride) == 1`, both call:
  ```cpp
  blurWeighByAlpha(imageData, imageData, newData, w, h, Stride, 0);
  ```
  `blurWeighByAlpha` writes alpha-premultiplied RGB values directly into its second parameter (`imageData`). Unlike `blurBitmap`, `motionBlurBitmap`, `radialBlurBitmap`, and `bokehBlurBitmap` (which pass `imageData` as both input and output and un-weigh it afterward), `zoomBlurBitmap` and `rotateBlurBitmap` only call `blurUnWeighByAlpha(newData, newData, w, h, Stride)` on `newData`, leaving the caller's source buffer `imageData` permanently darkened/premultiplied.
- **Fix:** Call `blurUnWeighByAlpha(imageData, imageData, w, h, Stride)` after the blur loop completes (or premultiply during sampling without mutating `imageData`).

---

### 1.6. [`UndoAiderSwapPixelRegions`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1318-L1334), [`dissolveBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1731-L1832), & [`symmetricaBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1834-L1880) — Missing Region Clamping and Uncaught `resize` / 32-Bit Index Overflow

> **Verified 2026-10-27:** 1.6.1 Confirmed, latent (the undo rectangle is always a valid crop; but see the stale-undo-level note in the verification section); 1.6.2 **Confirmed** (only when memory runs out: the failure is ignored and an unwritten bitmap applied); 1.6.3 Confirmed, latent (GDI+ caps the size).

- **Severity:** Medium
- **Location:** [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1318-L1334), [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1740-L1817), [qpv-main.cpp](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/qpv-main.cpp#L1844-L1875)
- **Root Cause:**
  1. `UndoAiderSwapPixelRegions` loops `for (int y = y1; y < y2; ++y)` and `for (int x = x1; x < x2; ++x)` without clamping `x1, y1, x2, y2` to `[0, w]` and `[0, h]`. If a brush stroke or bounding box overhangs the image edge (`x1 < 0`, `y1 < 0`, `x2 > w`, or `y2 > h`), `imageDataA[o]` and `imageDataB[o]` read and write out-of-bounds.
  2. `dissolveBitmap` calls `pixelzMap.resize(maxPixels);` (line 1742) *outside* a `try/catch` block (throwing an uncaught `std::bad_alloc` across `DLL_API` on failure), and computes `pixelzMap[dx + dy * Width]` (line 1775) and `pixelzMap[x + y * Width]` (line 1817) in 32-bit signed `int` despite `maxPixels` being `INT64`. `symmetricaBitmap` similarly computes `pixelzMap[x + y * Width]` in 32-bit signed `int` (lines 1859, 1875).
- **Fix:** Clamp `x1, y1, x2, y2` to `[0, w]` and `[0, h]` in `UndoAiderSwapPixelRegions`, wrap `pixelzMap.resize` in `try/catch`, and cast `y * (INT64)Width` in `dissolveBitmap` and `symmetricaBitmap`.

---

## 2. Blending, Color Adjustments & Paint Brush (`lib/blend-modes.h`, `lib/color-adjust.h`, `lib/paint-brush.h`)

### 2.1. [`CalculateNewBlendModes`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L251-L488) — `keepAlpha == 1` ("Protect Alpha") Fails in Normal (`0`) and Behind (`25`) Blend Modes

> **Verified 2026-10-27:** Intentional or known (2.1.1, 2.1.2). Accurate, but Normal and Behind were excluded from "Protect alpha" on purpose (eb7ea93, 9df5106).

- **Severity:** Medium
- **Location:** [blend-modes.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L258), [blend-modes.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L334-L362), [blend-modes.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L485-L486)
- **Root Cause:**
  Line 258 initializes `oA`:
  ```cpp
  const int oA = (blendMode >= 23 || blendMode == 0) ? -1 : Brgb.a;
  ```
  Later, lines 335, 360, and 485 attempt to restore the original destination alpha when `keepAlpha == 1`:
  ```cpp
  if (keepAlpha == 1 && oA != -1)
      result.a = oA;
  ```
  Because `oA` is forced to `-1` whenever `blendMode == 0` (Normal) or `blendMode == 25` (Behind), `oA != -1` is always `false` in those modes:
  - In **Normal mode (`blendMode == 0`)** with `keepAlpha == 1`: Painting over a semi-transparent pixel (`Brgb.a = 128`) or transparent pixel (`Brgb.a = 0`) overwrites destination alpha with `Orgb.a + Brgb.a * (1 - Orgb.a)` instead of keeping `Brgb.a`.
  - In **Behind mode (`blendMode == 25`)** with `keepAlpha == 1`: Painting behind a pixel increases its alpha instead of preserving `Brgb.a`.
- **Fix:** Set `const int oA = (blendMode == 23 || blendMode == 24) ? -1 : Brgb.a;` (excluding only Erase `23` and Alpha-to-Gray `24`), and when `keepAlpha == 1 && Brgb.a == 0`, return `Brgb` directly so completely transparent pixels do not receive RGB color.

---

### 2.2. [`CalculateNewBlendModes`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L319-L470) — `flipLayers == 1` Combined With `keepAlpha == 1` in Blend Modes `2..21` Ignores Brush / Top-Layer Opacity

> **Verified 2026-10-27:** **Confirmed.** With "Swap blended layers" and "Protect alpha" both on, modes 2..21 ignore the new layer's opacity (reproduced for every mode). Fixed 2026-10-28.

- **Severity:** Medium
- **Location:** [blend-modes.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L319-L325), [blend-modes.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L367-L469)
- **Root Cause:**
  When `flipLayers == 1`, `do_swap` swaps `Orgb` (top layer / brush, e.g. `alpha = 10`) and `Brgb` (canvas, e.g. `alpha = 255`). After the swap, `sa = Orgb.a = 255` and `da = Brgb.a = 10`.
  Normally, when `keepAlpha == 0`, `mix` is `true` (line 367), so lines 395/442/467 interpolate between the blended result and the original canvas color using `da` (the brush's alpha `10`), scaling the effect appropriately.
  However, when `keepAlpha == 1` and `blendMode` is in `[2..21]`, line 367 sets `mix = false`:
  ```cpp
  const bool mix = !(keepAlpha == 1 && blendMode > 1 && blendMode < 22);
  ```
  This skips the `da < 255` interpolation completely, leaving only the `sa_scaled` (`Orgb.a == 255` $\implies$ `65536U`) interpolation. As a result, every pixel touched by a soft brush (`alpha = 1..254`) on an opaque canvas receives a 100%-opacity hard-edged blend, ignoring brush opacity and feathering.
- **Fix:** When `do_swap` is `true` and `keepAlpha == 1`, retain `mix = true` (or scale the final interpolation toward the unswapped destination `Orgb` by `da_scaled`).

---

### 2.3. [`toLABfx`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L75-L81) / [`RGBtoGray`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L83-L100) & [`toLABf`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L38-L46) — Misscaled CIE $L^*a^*b^*$ $\epsilon$ Constants

> **Verified 2026-10-27:** Intentional or known (2.3.1, 2.3.2). The numbers are right, but Marius restored both constants on purpose (8f5cbb4, "intentionally chosen value"); the quoted code differs from the real code.

- **Severity:** Low
- **Location:** [blend-modes.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/blend-modes.h#L75-L100), [flood-fill.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L38-L46)
- **Root Cause:**
  1. In `lib/blend-modes.h:77`:
     ```cpp
     inline float toLABfx(float Y) {
          if (Y <= 8.88564517f)
             return (903.2962962f * Y);
          else
             return cbrt(Y);
     }
     ```
     In `RGBtoGray`, `Y` is normalized linear luminance in `[0.0f, 1.0f]`. Because the CIE $\epsilon$ threshold was typed as `8.88564517f` instead of `0.0088564517f`, `Y <= 8.88564517f` is **always true** for all valid RGB inputs, making `cbrt(Y)` dead code and causing `RGBtoGray(..., alternateMode = 0)` to return up to `452` instead of `255` for white (`255, 255, 255`).
  2. In `lib/flood-fill.h:40`:
     ```cpp
     if (Y <= 0.00885645167903563082e-3)
          return (841.0 / 108.0) * Y + (4.0 / 29.0);
     ```
     Adding `e-3` to `0.00885645...` made the threshold $8.856 \times 10^{-6}$ instead of $0.00885645$ ($(6/29)^3$), creating a large discontinuity at $Y = 8.856 \times 10^{-6}$ where the linear branch returns `0.1380` while `cbrt(Y)` returns `0.0207`.
- **Fix:** Use `0.00885645167903563082` in both functions, and in `toLABfx` return `(841.0f / 108.0f) * Y + (4.0f / 29.0f)` so `116.0f * toLABfx(Y) - 16.0f` maps `[0, 1]` cleanly to `[0, 100]`.

---

### 2.4. [`AdjustColorsFXplan::applyRGB`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/color-adjust.h#L765-L781) — Out-of-Bounds LUT Reads in `tint()` / `tinto()` After `blackPoint` / `whitePoint` With Noise

> **Verified 2026-10-27:** Confirmed, latent. Reproduced with ASan, but it needs a black or white point beyond the sliders' range (registry edit only).

- **Severity:** High
- **Location:** [color-adjust.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/color-adjust.h#L291-L343), [color-adjust.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/color-adjust.h#L533-L619), [color-adjust.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/color-adjust.h#L765-L781)
- **Root Cause:**
  In `AdjustColorsFXplan::applyRGB`:
  ```cpp
  if (blackP!=0)
     px.blackPoint(blackP, blackVal, noiseMode, 1);
  if (whiteP!=0)
     px.whitePoint(whiteP, whiteVal, noiseMode, 1);
  if (hasTint)
     px.tint(tintH, tintS, tintB, tintParam, isLinear, thisRow, z);
  ```
  When `blackPoint` or `whitePoint` is called with `noClamping == 1` and `noiseMode == 1`, random noise (`±2599`) pushes `px.r`, `px.g`, `px.b` outside `[0, 65535]` into `[-2599, 68134]`.
  However, the `[0, 65535]` clamping in `applyRGB` is placed at lines 774–781—**after** `px.tint(...)` at line 770. Inside `px.tint()`:
  - When `mode < 10`, `ConvertRGBtoHSL()` (lines 76–78) indexes `int_to_float[r]`, `int_to_float[g]`, `int_to_float[b]` without clamping.
  - `tinto()` (lines 310–315) and `tint()` (lines 336–343) index `gamma_to_linearInt16[r/g/b]` and `int_to_float[r/g/b]` without clamping.
  Both LUTs have 65,536 elements (`[0..65535]`), so indices in `[-2599..-1]` or `[65536..68134]` read out-of-bounds memory.
- **Fix:** Move the `px.r`, `px.g`, `px.b` clamping to `[0, 65535]` immediately before `if (hasTint) px.tint(...)`.

---

### 2.5. [`RGBA16color::contrast`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/color-adjust.h#L450-L493) — Stage 2 Uses Unfaded `nr, ng, nb` Instead of Faded `r, g, b` When `noClamping == 1`

> **Verified 2026-10-27:** Not a bug (2.5.1, 2.5.2). The stage-1 fade is dead code there, but the output is continuous and equals the clamped path.

- **Severity:** Low
- **Location:** [color-adjust.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/color-adjust.h#L460-L488)
- **Root Cause:**
  In Stage 1 (`level < 19500`), lines 460–464 blend the contrast-adjusted values `nr, ng, nb` with the original `r, g, b` and store the faded result in `r, g, b`:
  ```cpp
  r = clamp16bits(blendValues(nr, r, fade), noClamping);
  g = clamp16bits(blendValues(ng, g, fade), noClamping);
  b = clamp16bits(blendValues(nb, b, fade), noClamping);
  ```
  In Stage 2 (`level < 16000`), lines 479–481 compute the linear contrast adjustment around `mid` using `nr, ng, nb` instead of the Stage 1 outputs `r, g, b`, and when `level >= 16000 && noClamping == 1`, lines 484–488 overwrite `r, g, b` with the unfaded `nr, ng, nb`, discarding the `16000..19500` fade entirely.
- **Fix:** Write the Stage 1 result into `nr, ng, nb` (as well as `r, g, b`) before Stage 2 runs.

---

### 2.6. [`brushSetupClone`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L306-L336) & [`brushSmudgeSample`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L947-L953) — Null-Pointer Dereference in Smudge Brush (`brushType == 6`) When `cloneData != nullptr`

> **Verified 2026-10-27:** Confirmed, latent. Reproduced (null read under ASan), but the app hands a clone buffer only to the cloner, never to the smudge.

- **Severity:** High (Crash)
- **Location:** [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L309-L335), [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L948-L950)
- **Root Cause:**
  In `brushSetupClone(BrushCtx &s)`:
  ```cpp
  if (!s.cloneData && (s.brushType == 3 || s.brushType == 6 || s.brushType == 7 || s.brushType == 8))
  {
      ... // allocates and fills s.localClone
  }
  return s.cloneData != nullptr || !s.localClone.empty()
      || (s.brushType != 6 && s.lockW == 0 && s.lockH == 0);
  ```
  When `s.brushType == 6` (Smudge brush) and the caller passes a non-null `cloneData`, `if (!s.cloneData && ...)` is `false`, so `s.localClone` remains empty (`size() == 0`, `data() == nullptr`). Yet `brushSetupClone` returns `true` because `s.cloneData != nullptr`.
  Then `brushSmudgeRows` calls `brushSmudgeSample` (line 949):
  ```cpp
  const BYTE *base = s.localClone.data();
  const int stride = s.cloneStride;
  ```
  Because `s.localClone` was never populated and `s.cloneStride` is `0`, `base` is `nullptr` and `base[(size_t)y0 * stride + ...]` immediately crashes with an access violation (`0xC0000005`).
- **Fix:** For `s.brushType == 6`, always allocate `s.localClone` (or use `s.cloneData` when provided with a valid `cloneStride`) and require `!s.localClone.empty()` in the return check for `s.brushType == 6`.

---

### 2.7. [`brushSetupChunkGrid`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L222-L253) — Heap Buffer Overflow & Out-of-Bounds Vector Access When `totalChunks` Remains Constant Across Different Image Dimensions or BPP

> **Verified 2026-10-27:** Confirmed, latent (2.7.1, 2.7.2). Reproduced with ASan, but the app resets the chunk cache at every stroke's start and end.

- **Severity:** High
- **Location:** [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L228-L252)
- **Root Cause:**
  `brushSetupChunkGrid` caches static chunk buffers across calls (`brushOpacityChunks`, `chunkedSnapshot`, `chunkGridW`, `chunkGridH`), but its reallocation guard at line 231 only checks `totalChunks`:
  ```cpp
  if (s.eraseCache == 1 || brushOpacityChunks.size() != totalChunks)
  ```
  1. **BPP change with same chunk count (Heap Buffer Overflow):** If the user switches from a 24-bpp image (`bytesPerPixel == 3`) to a 32-bpp image (`bytesPerPixel == 4`) with the same chunk grid count (`totalChunks`), `chunkedSnapshot[i]` buffers are not reallocated and remain `128 * 128 * 3 = 49,152` bytes, while `brushSnapshotChunk` (lines 283–284) writes `128 * 128 * 4 = 65,536` bytes into them, overflowing the heap buffer by 16 KB per touched chunk.
  2. **Aspect ratio swap with same `totalChunks` (Out-of-Bounds Vector Access):** If the first image is `256 x 128` (`numChunksX = 2, numChunksY = 1, totalChunks = 2`) and the next image is `128 x 256` (`numChunksX = 1, numChunksY = 2, totalChunks = 2`) with `eraseCache == 0`, `chunkGridW` stays `2`. When painting at `y >= 128` (`cy = 1`), `cy * chunkGridW + cx = 1 * 2 + 0 = 2 >= totalChunks`, indexing `brushOpacityChunks[2]` and `chunkedSnapshot[2]` out-of-bounds.
- **Fix:** Change the reallocation condition to:
  ```cpp
  if (s.eraseCache == 1 || brushOpacityChunks.size() != totalChunks
      || chunkGridW != numChunksX || chunkGridH != numChunksY
      || cachedBytesPerPixel != s.bytesPerPixel)
  ```

---

### 2.8. [`brushSmudgeSample`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L963-L982) & [`brushSmudgeRows`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L1051-L1053) — Unclamped `outB/G/R == 256` Indexes 256-Entry Blend LUTs Out-of-Bounds

> **Verified 2026-10-27:** **Confirmed.** Not via the all-255 example (that case is exact): alpha-weighted smudge samples at transparent edges can round to 256, which the blend tables then read past (UBSan, ASan).

- **Severity:** Medium
- **Location:** [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L963-L982), [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L1051-L1053)
- **Root Cause:**
  In `brushSmudgeSample` on 32-bpp images, bilinear weights are rescaled by pixel alpha (`w[k] *= p[k][3] / a`, line 969). Due to IEEE-754 float rounding, `w[0] + w[1] + w[2] + w[3]` can slightly exceed `1.0f` (e.g. `1.0000001f`). When all four neighbor channels are `255`, `v = 255.0f * (w[0]+w[1]+w[2]+w[3]) > 255.0f`, and adding the dither `rnd = 65535.0f / 65536.0f` yields `(int)(v + rnd) == 256`.
  In `brushSmudgeRows`, `outB, outG, outR` are passed **unclamped** to `CalculateNewBlendModes` at line 1053 (clamping is only performed later at lines 1092–1096), indexing `gamma_to_linear[256]`, `int_to_float[256]`, and `divide_by_255[256]` one element past the end of those 256-entry arrays.
- **Fix:** Clamp `out[ch]` to `[0, 255]` inside `brushSmudgeSample`.

---

### 2.9. [`brushRows`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L1359-L1363) — OpenMP Data Race on `s.imgData` in Cloner (`3`) and Pinch/Bulge (`7, 8`) When `localClone` Is Not Used

> **Verified 2026-10-27:** Intentional or known. Documented in 72aeac1; it needs a huge image, Double size and Random size, and gives nondeterministic pixels, not a crash.

- **Severity:** Medium
- **Location:** [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L314-L335), [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L730-L734), [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L834-L844), [paint-brush.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/paint-brush.h#L1359-L1363)
- **Root Cause:**
  When `s.cloneData == nullptr`, `s.lockW == 0`, and `s.localClone` is not allocated (because the image exceeds the `150 MB` threshold at line 314 or `resize` fails), `srcBase` in `brushClonePixel` (line 730) and `brushPinchSample` (line 842) falls back to `s.imgData`. Meanwhile, `#pragma omp parallel for` (lines 1107, 1360) runs concurrently across rows `y`, so one thread reads source coordinates `(px - offX, py - offY)` or `(srcXf, srcYf)` from `s.imgData` while another thread concurrently writes destination pixels to the same bytes in `s.imgData`.
- **Fix:** Disable OpenMP parallelism (`num_threads(1)`) or allocate a bounding-box snapshot whenever `srcBase == s.imgData` for `brushType` 3, 7, or 8.

---

## 3. Selection Masks & Flood Fill (`lib/selection-mask.h`, `lib/flood-fill.h`)

### 3.1. [`prepareSelectionArea`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1564-L1575) — Out-of-Bounds Read on `imgSel.mask` When `useCache == 1` and New Dimensions Exceed Cached Mask Size

> **Verified 2026-10-27:** Confirmed, latent. Reproduced with ASan in the DLL; the app reuses the cache only for an identical selection or right before a resize.

- **Severity:** High
- **Location:** [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1564-L1575)
- **Root Cause:**
  `prepareSelectionArea` unconditionally updates `imgSel.maskW` and `imgSel.maskH` (lines 1554–1561), and then checks:
  ```cpp
  if (imgSel.shape==2)
  {
      if (imgSel.mask.size()<2000)
          useCache = 0;

      if (useCache==0)
      {
          INT64 s = (INT64)imgSel.maskW * (INT64)imgSel.maskH + 2;
          imgSel.mask.resize(s);
          imgSel.mask.zero();
      }
  }
  ```
  If the previous polygon mask had `size >= 2000` (e.g., `100 x 100 = 10,002` bits) and `prepareSelectionArea` is called for a larger area (e.g., `1000 x 1000`) with `useCache == 1`, `imgSel.mask.size() < 2000` is `false`, so `imgSel.mask` is **not** resized while `imgSel.maskW` and `imgSel.maskH` become `1000`. Subsequent calls to `clipMaskFilter(x, y, NULL, 0)` pass the new `imgSel.maskW`/`imgSel.maskH` bounds check and read `imgSel.mask.get(mPos)` far past the 10,002-bit allocation.
- **Fix:** Check `INT64 s = (INT64)imgSel.maskW * (INT64)imgSel.maskH + 2; if (imgSel.mask.size() != (size_t)s) useCache = 0;`.

---

### 3.2. [`prepareSelectionArea`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1545-L1580) & [`prepareDrawLinesMask`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1361-L1413) — Stale `imgSel.highDepth` Flag and Unhandled `.resize()` Failure Cause Out-of-Bounds Reads in `clipMaskFilter`

> **Verified 2026-10-27:** 3.2.1a Confirmed, latent; 3.2.1b Not a bug; 3.2.2 Not a bug; 3.2.3 Confirmed, latent. High depth lives only inside the parametric-lines tool, which clears it; allocation failures are caught.

- **Severity:** High
- **Location:** [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1395-L1412), [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1429-L1487), [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1545-L1580)
- **Root Cause:**
  1. **Stale `imgSel.highDepth == 1` in `prepareSelectionArea`:** `prepareSelectionArea` never resets `imgSel.highDepth = 0`. If `prepareDrawLinesMask` was previously called with `highDepth == 1` and then `prepareSelectionArea` is called for a larger polygon (`shape == 2`), `imgSel.mask` is resized to the new `maskW * maskH + 2`, while `imgSel.depthMask` remains at its old, smaller size. In `clipMaskFilter` (lines 1456, 1482), because `imgSel.highDepth == 1` is still set, `imgSel.depthMask.get(mPos)` reads out-of-bounds. Furthermore, for `shape == 0` (rectangle) or `shape == 1` (ellipse), `clipMaskFilter` returns `0` instead of `1` outside the bounding box when `highDepth == 1 && inverted == 0` (line 1463), inverting the selection outside the box.
  2. **Unchecked `.resize(s)` failure in `prepareDrawLinesMask` and `prepareSelectionArea`:** `MaskBitMap::resize` and `highDephMaskMap::resize` catch `std::bad_alloc` and set `size_ = 0; data_.clear();`. Because `imgSel.shape = 2` and `imgSel.highDepth = highDepth` are set before `.resize(s)` without checking if `resize` succeeded, `clipMaskFilter` subsequently dereferences `data_[idx]` on an empty vector.
  3. **Missing `.zero()` on same-size `depthMask` reuse (`prepareDrawLinesMask`, line 1405):** When `highDepth == 1` and `s == imgSel.depthMask.size()`, `imgSel.depthMask` is neither resized nor zeroed, leaving stale line-mask pixels from the previous operation.
- **Fix:** Reset `imgSel.highDepth = 0;` in `prepareSelectionArea`, always call `imgSel.depthMask.zero()` when `useCache == 0` in `prepareDrawLinesMask`, and verify `mask.size() >= (size_t)s` after `resize(s)` (disabling the selection `imgSel.enabled = 0` on allocation failure).

---

### 3.3. [`clipMaskFilter`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1462-L1469) — Negative Offset Out-of-Bounds Read on `maskBitmap` When `imgSel.inverted == 0` and `imgSel.maskRowShift > 0`

> **Verified 2026-10-27:** Confirmed, latent. Reproduced with ASan; already recorded in the 10-06 audit (#26): no caller passes a mask bitmap.

- **Severity:** High
- **Location:** [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1438-L1443), [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1462-L1469)
- **Root Cause:**
  In `clipMaskFilter`, compare the `inverted == 1` branch (line 1438) with the `inverted == 0` branch (line 1462):
  - Line 1438 (`inverted == 1`):
    ```cpp
    int rowShift = (maskBitmap != NULL) ? 0 : imgSel.maskRowShift;
    if (!inRange(imgSel.x1, imgSel.x2, x) || !inRange(imgSel.y1 - rowShift, imgSel.y2, y))
        return 0;
    ```
  - Line 1462 (`inverted == 0`):
    ```cpp
    if (!inRange(imgSel.x1, imgSel.x2, x) || !inRange(imgSel.y1 - imgSel.maskRowShift, imgSel.y2, y))
        return (imgSel.highDepth == 1) ? 0 : 1;
    if (maskBitmap != NULL)
    {
        INT64 mo = (INT64)(x - imgSel.x1) * 4 + (INT64)(y - imgSel.y1) * imgSel.Stride;
        return 255 - maskBitmap[mo];
    }
    ```
  Because line 1462 unconditionally subtracts `imgSel.maskRowShift` even when `maskBitmap != NULL`, any `y` in `[imgSel.y1 - imgSel.maskRowShift, imgSel.y1 - 1]` passes the range check with `y - imgSel.y1 < 0`, making `mo` negative and reading `maskBitmap[mo]` before the beginning of the `maskBitmap` buffer.
- **Fix:** Use `int rowShift = (maskBitmap != NULL) ? 0 : imgSel.maskRowShift;` on line 1462 just as on line 1438.

---

### 3.4. [`mergePolyMaskIntoHighDepthMask`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1336-L1355) — Incomplete Bounding Box Margin and Missing `offsetY` Leave Stale Bits in `imgSel.mask`

> **Verified 2026-10-27:** 3.4a Intentional or known (the row offset is applied; lost miter tips are known); 3.4b Confirmed, latent: the caller's points are shifted in place, but the second "Double line" call's offsetY (diffThick) cancels that shift exactly. Cleaned up 2026-10-28.

- **Severity:** Medium
- **Location:** [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1260-L1281), [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L1336-L1355)
- **Root Cause:**
  In `NewDrawLinesOnMask`:
  - If `closed == 0` and `pointsCount >= 2`, the caller's `PointsList` Y-coordinates are mutated in-place by `offsetY = imgSel.maskRowShift - imgSel.y1Push` (lines 1262–1265), whereas the bounding box `[px1..px2] x [py1..py2]` was computed *before* adding `offsetY` (lines 1236–1244).
  - The blurred stroke is rendered into a bounding box expanded by `bbMargin = std::max(cvThickness * 4, thickness + 10)` around `[px1..px2] x [py1 + offsetY .. py2 + offsetY]` (lines 1277–1281).
  - However, when `closed == 1 && highDepth == 1`, `mergePolyMaskIntoHighDepthMask` (lines 1338–1341) only iterates over `[px1 - thickness .. px2 + thickness] x [py1 - thickness .. py2 + thickness]` (without `bbMargin` and without `offsetY`). All bits set by `fillPoly` outside `± thickness` remain unmerged into `depthMask` and **uncleared** (`1`) in `imgSel.mask`, corrupting subsequent `NewDrawLinesOnMask` calls.
- **Fix:** Do not mutate the caller's `PointsList` in-place, include `offsetY` in `py1`/`py2`, and pass `bbMargin` to `mergePolyMaskIntoHighDepthMask`.

---

### 3.5. [`traverseCurvedPath`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L562-L660) — Off-by-One 1-Based Indexing in `PathsMap` Corrupts Closed Multi-Path Curves

> **Verified 2026-10-27:** Not a bug. The loops described do not exist; the insert position the function returns is correct.

- **Severity:** Low
- **Location:** [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L575-L586), [selection-mask.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/selection-mask.h#L634-L659)
- **Root Cause:**
  In `traverseCurvedPath`, `fPointsCount` starts at `0`, is incremented *before* storing each point (`fPointsCount++;`), and `PathsMap[fPointsCount] = pathIndex;` writes to 1-based indices `1..fPointsCount` (leaving `PathsMap[0] == 0`).
  Then the path-splitting loop at line 637 iterates `for (int i = 0; i < fPointsCount; ++i)` (starting at `PathsMap[0] == 0` instead of `1` and stopping before `PathsMap[fPointsCount]`), and at line 653 reads `nextPathIndex = PathsMap[last + 1]` even though `last = i` is already the first index of the new path segment.

---

### 3.6. [`FloodJob::setupPaint`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L1085-L1095) & [`floodFillPrepare`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L1760-L1765) — `dynamicOpacity == 1`, Semi-Transparent `newColor`, and `cartoonMode == 1` Broken by `simpleMode` / `constPaint` Fast Path

> **Verified 2026-10-27:** 3.6.1 **Confirmed** (dynamic opacity has no effect at 100 % opacity, Normal); 3.6.2 Confirmed, latent (the app always sends an opaque fill colour); 3.6.3 Intentional or known (the panel disables those controls in cartoon mode).

- **Severity:** Medium
- **Location:** [flood-fill.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L1085-L1140), [flood-fill.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L1760-L1765)
- **Root Cause:**
  In `FloodJob::setupPaint()` and `floodFillPrepare()`:
  ```cpp
  simpleMode = (p.opacity==1 && p.blendMode==0 && p.cartoonMode==0);
  constPaint = (simpleMode || p.cartoonMode==1) && p.PreviewMode!=2;
  wantIndex  = (p.PreviewMode==1) && (!constPaint || needBlur);
  ```
  1. **`dynamicOpacity == 1` ignored at 100% opacity (`p.opacity == 1.0f`, `p.blendMode == 0`):** Because `simpleMode` does not check `p.dynamicOpacity == 0`, `simpleMode` and `constPaint` evaluate to `true` whenever `opacity == 1.0f` and `blendMode == 0`. When `needBlur == false`, `wantIndex` becomes `false`, so `idxList` is never populated and `paint_run` writes `constBGRA` directly during scanline traversal, completely ignoring `dynamicOpacity == 1` (which is only evaluated inside `paint_pixel`, lines 1130–1137).
  2. **Semi-transparent fill color (`p.newColor.a < 255`) overwrites instead of alpha-blending:** When `p.opacity == 1.0f`, `p.blendMode == 0`, and `p.newColor.a < 255` (e.g. `128`), `constPaint` overwrites target pixels directly with raw `p.newColor` instead of compositing `newColor` over the existing pixel via `CalculateNewBlendModes`.
  3. **`cartoonMode == 1` ignores `opacity`, `blendMode`, and `dynamicOpacity`:** Because `constPaint` is forced `true` whenever `p.cartoonMode == 1 && p.PreviewMode != 2`, `paint_run` stamps `constBGRA` (`cartoonR/G/B` with `255` alpha) directly, bypassing `paint_pixel`.
- **Fix:** Define `simpleMode = (p.opacity == 1.0f && p.blendMode == 0 && p.cartoonMode == 0 && p.dynamicOpacity == 0 && (bpp != 32 || p.newColor.a == 255));` and `constPaint = simpleMode && p.PreviewMode != 2;`.

---

### 3.7. [`FloodSel::masked`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L331-L335) — Broken Selection Masking in Flood Fill When `imgSel.highDepth == 1` (`kind == 1`)

> **Verified 2026-10-27:** Confirmed, latent. A fill never runs while a high-depth mask is set.

- **Severity:** Medium
- **Location:** [flood-fill.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L326-L335), [flood-fill.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/flood-fill.h#L424-L431)
- **Root Cause:**
  When `imgSel.enabled == 1` and `maskBitmap == nullptr`, `FloodSel::init` sets `kind = 1`. In `FloodSel::masked(x, y)` (line 333) and `mask_block64(x0, y)` (line 428):
  ```cpp
  if (kind == 1) return clipMaskFilter(x, y, NULL, 0) == 1;
  ```
  When `imgSel.highDepth == 0`, `clipMaskFilter` returns `1` for masked-out pixels and `0` for allowed pixels.
  However, when `imgSel.highDepth == 1` (e.g. after `prepareDrawLinesMask(..., highDepth = 1)`), `clipMaskFilter` returns `0` outside the selection and the 8-bit depth value (`0..255`) inside the selection. Testing `== 1` causes `FloodSel::masked` to treat all pixels outside the selection (`0`) and all pixels inside the selection with `depth >= 2` as **unmasked (allowed)**, while masking out only pixels where `depth == 1`.

---

## 4. WIC, PDFium, PDF Writer & SVG Loaders (`lib/wic-loader.h`, `lib/pdfium-reader.h`, `lib/pdf-writer.h`, `lib/svg-render.h`)

### 4.1. [`applyColorManagement`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L199-L318) & [`LoadWICimage`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L1618) — Data Race, Use-After-Free, and COM Leaks via Function-Local `static` COM Pointers

> **Verified 2026-10-27:** 4.1.1 Confirmed, latent (one script thread reaches the statics; the pools use their own copy); 4.1.2 Not a bug (that QueryInterface cannot fail).

- **Severity:** High
- **Location:** [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L199-L211), [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L252-L315), [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L1618)
- **Root Cause:**
  1. **Unsynchronized `static` COM pointers across threads:** `applyColorManagement` declares `pSrcColorContext`, `pDestColorContext`, `pCmykColorContext`, and `pColorTransform` as `static` local variables (lines 201–204). Furthermore, at the end of `LoadWICimage` (line 1618), every call unconditionally executes `applyColorManagement(nullptr, nullptr, 0, nullptr, 100);` (even when `useICM == 0`), which calls `SafeRelease` and sets those four `static` pointers to `nullptr`. If two threads call `LoadWICimage` concurrently (e.g., main thread + preload/worker thread), one thread's cleanup at line 1618 releases and nulls the COM objects while the other thread is mid-execution inside `applyColorManagement`, causing a null-pointer dereference or COM use-after-free.
  2. **Premature release of `thisWICbitmap` on `QueryInterface` failure (lines 310–314):**
     ```cpp
     if (SUCCEEDED(hr))
     {
         SafeRelease(&thisWICbitmap);
         hr = pColorTransform->QueryInterface(IID_PPV_ARGS(&thisWICbitmap));
     }
     ```
     If `pColorTransform->Initialize` succeeds (`hr == S_OK`) but `QueryInterface` fails, `thisWICbitmap` has already been released and nulled, so the caller loses the valid source bitmap instead of falling back to un-color-managed rendering.
- **Fix:** Store the four ICM COM pointers inside the per-call `WICloaderData` struct (`ld`) instead of `static` variables, and query `IID_IWICBitmapSource` into a temporary pointer before replacing `thisWICbitmap`.

---

### 4.2. [`WICgetRectImage`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L739-L887) — Returns Uninitialized Dummy `100x100` `GpBitmap*` on Error Instead of `nullptr`

> **Verified 2026-10-27:** Intentional or known. Found 2026-08-12 and left on purpose: a blank tile, tracked, not leaked.

- **Severity:** Medium
- **Location:** [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L739-L887), [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L997-L1005)
- **Root Cause:**
  `WICgetRectImage` allocates a dummy `100x100` GDI+ bitmap (`Gdiplus::DllExports::GdipCreateBitmapFromScan0(100, 100, 0, PixelFormat32bppARGB, nullptr, &myBitmap);`, line 999) and passes `myBitmap` by reference to `coreWICgetBufferImage`.
  Inside `coreWICgetBufferImage`, every error return path:
  - Line 744 (`!m_pIWICFactory` or `!imgValid` or `w < 4` or `h < 4`)
  - Line 807 (`FAILED(hr)` on clip/transform)
  - Line 874 (`std::bad_alloc` when allocating `pixels`)
  - Line 875 (`cbStride == 0` when `CopyPixels` fails)
  returns without disposing or nulling `myBitmap`. As a result, `WICgetRectImage` returns a valid non-null pointer to an uninitialized `100x100` bitmap on failure, misleading callers into treating failed region decodes as valid `100x100` images and leaking the GDI+ bitmap if not disposed.
- **Fix:** Initialize `GpBitmap *myBitmap = nullptr;` in `WICgetRectImage`, and only create `myBitmap` inside `coreWICgetBufferImage` immediately before `GdipCreateBitmapFromScan0(nWidth, nHeight, ...)` at line 880.

---

### 4.3. [`LoadWICimage`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L1368-L1536) — `UINT *&resultsArray` Reference-to-Pointer ABI Mismatch and `doFlipHV` Ignored When Image Dimensions Match Target Size

> **Verified 2026-10-27:** 4.3.1 Not a bug (the only caller passes a pointer to a pointer, as the reference expects); 4.3.2 Confirmed, latent (no caller asks for a flip).

- **Severity:** High
- **Location:** [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L1368), [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L1498), [wic-loader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/wic-loader.h#L1525-L1536)
- **Root Cause:**
  1. **`UINT *&resultsArray` parameter type (line 1368):** Unlike `WICpreLoadImage` (line 1344, which takes `UINT *resultsArray`), `LoadWICimage` declares `UINT *&resultsArray` (a reference to a pointer, i.e. `UINT**` at the C ABI level). Any C/FFI caller passing the address of a `UINT[]` array directly (rather than the address of a pointer variable pointing to the array) causes `resultsArray[0..6]` to dereference the first array elements as a memory pointer and crash.
  2. **`doFlipHV` ignored when `nSize[0] == ld.owidth && nSize[1] == ld.oheight` (lines 1498, 1525–1536):**
     Line 1498 sets:
     ```cpp
     ld.mustResize = (nSize[0] != ld.owidth || nSize[1] != ld.oheight) ? true : false;
     ```
     And lines 1525–1536 only invoke `scaleSourceBitmap(..., ld.doFlipHV)` when `ld.mustResize` is `true` (or when an EXIF rotation changed dimensions). When `doFlipHV != 0` (user requested horizontal/vertical flip) on an image that does not need resizing and has no 90°/270° EXIF rotation, `scaleSourceBitmap` is never called and the flip is silently ignored.
- **Fix:** Change `UINT *&resultsArray` to `UINT *resultsArray` (matching `WICpreLoadImage`), and include `|| ld.doFlipHV != 0` when setting `ld.mustResize` (or call `scaleSourceBitmap` whenever `ld.mustResize || ld.rotationFlag != WICBitmapTransformRotate0 || ld.doFlipHV != 0`).

---

### 4.4. [`RenderPdfPageAsText`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/pdfium-reader.h#L294-L343) — `-1` Error Return Cast to `UINT` (`0xFFFFFFFF`) Causes 4.29-Billion-Iteration Freeze, Plus Heap Buffer Overflow on `FPDFText_GetText`

> **Verified 2026-10-27:** 4.4.1 Not a bug; 4.4.2 Confirmed, latent (the only caller allocates 8x the reported size); 4.4.3 Not a bug. The quoted extraction loop does not exist.

- **Severity:** Critical / High
- **Location:** [pdfium-reader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/pdfium-reader.h#L307-L335)
- **Root Cause:**
  ```cpp
  FPDF_TEXTPAGE textPage = FPDFText_LoadPage(PDFpage);
  UINT textLength = FPDFText_CountChars(textPage);
  if (!textBuffer)
  {
      textLength += FPDFPage_CountObjects(PDFpage);
      *bufferSize = textLength;
  } else if (textLength > 2)
  {
      FPDFText_GetText(textPage, 0, textLength, reinterpret_cast<unsigned short*>(textBuffer));
      for (UINT i = 0; i < textLength; ++i)
      {
          if (textBuffer[i] == L'\0')
             textBuffer[i] = L' ';
      }
      textBuffer[textLength] = L'\0';
  }
  ```
  1. **Signed `-1` error return cast to `UINT` (`0xFFFFFFFFu`):** `FPDFText_CountChars(textPage)` returns `int` (`-1` on error or if `textPage == nullptr`). Storing `-1` into `UINT textLength` produces `4,294,967,295` (`0xFFFFFFFFu`). When `textBuffer != nullptr`, `textLength > 2` is `true`, and `for (UINT i = 0; i < textLength; ++i)` loops 4.29 billion times writing past `textBuffer` while holding `pdfiumMutex`, freezing/crashing the process.
  2. **Heap buffer overflow on `FPDFText_GetText` and `textBuffer[textLength] = L'\0'`:**
     - `FPDFText_GetText(textPage, 0, count, buffer)` writes `count` characters **plus** a trailing NUL (`count + 1` `unsigned short` elements total).
     - In the size-query call (`!textBuffer`), `*bufferSize = textLength + FPDFPage_CountObjects(PDFpage)`. If `FPDFPage_CountObjects(PDFpage)` returns `0` (or `-1` on error, which decrements `textLength`!), the caller allocates only `textLength` (or `textLength - 1`) `wchar_t`s.
     - Then, in the extraction call (`textBuffer != nullptr`), the function ignores the caller's `*bufferSize` and passes `textLength` directly to `FPDFText_GetText` and writes `textBuffer[textLength] = L'\0'`, overflowing a buffer of size `textLength` by 1 `wchar_t` (2 bytes) or 2 `wchar_t`s (4 bytes) when `FPDFPage_CountObjects` returned `-1`.
  3. **1–2 character pages silently skipped and `textBuffer` left uninitialized:** When `textLength` is `0`, `1`, or `2`, `else if (textLength > 2)` is `false`, so `textBuffer[0]` is never even NUL-terminated.
- **Fix:** Check `int rawCount = textPage ? FPDFText_CountChars(textPage) : -1; if (rawCount <= 0) { ... }`, return `*bufferSize = (UINT)rawCount + 2;` on size query, respect `*bufferSize` on extraction, and handle `rawCount >= 1`.

---

### 4.5. [`adaptImageGivenSize`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/pdfium-reader.h#L46-L65) & [`coreRenderPdfPageAsBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/pdfium-reader.h#L387-L445) — Division by Zero (`imgH == 0` / `givenH == 0`), `dpi == 0` Bypassing `maxMPX` Cap, and Unaligned 24-bpp GDI+ Stride

> **Verified 2026-10-27:** 4.5.1 **Confirmed** (undefined behaviour on a malformed 0-px-wide PDF page in a contact sheet; harmless on x64); 4.5.2 Confirmed, latent; 4.5.3 Not a bug (GDI+ allocates with its own stride).

- **Severity:** High
- **Location:** [pdfium-reader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/pdfium-reader.h#L46-L65), [pdfium-reader.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/pdfium-reader.h#L399-L445)
- **Root Cause:**
  1. **Division by zero in `adaptImageGivenSize` (lines 48–62):** Computes `(float)imgW / (float)imgH`, `(float)givenW / (float)givenH`, and `/ PicRatio` without checking `imgW > 0 && imgH > 0 && givenW > 0 && givenH > 0`. If any dimension is `0`, `NaN` or `+Inf` is cast to `UINT` (`std::round(NaN)`), which is undefined behavior in C++.
  2. **`dpi == 0` bypasses `nSize` and `maxMPX` cap in `coreRenderPdfPageAsBitmap` (lines 399–419):**
     When `*givenW == 0 || *givenH == 0`, lines 401–402 set `*givenW = 32650; *givenH = 32650;`. Line 407 computes `nSize` capped to `maxMPX`, and lines 411–412 set `bitmapWidth = nSize[0]; bitmapHeight = nSize[1];`.
     However, lines 414–418 then execute:
     ```cpp
     if (!dpi)
     {
         bitmapWidth = *givenW;
         bitmapHeight = *givenH;
     }
     ```
     When `dpi == 0`, this overwrites `bitmapWidth` and `bitmapHeight` with the raw `*givenW` and `*givenH` (`32650 x 32650` = 1,066 megapixels = 4.26 GB!), completely bypassing both aspect-ratio adaptation and the `maxMPX` safety cap, and overflowing 32-bit signed `int cbStride = bitmapWidth * 4` whenever `*givenW >= 536,870,912`.
  3. **Unaligned 24-bpp stride passed to `GdipCreateBitmapFromScan0` (lines 428, 444):**
     When `do24bits == 1`, line 428 sets `cbStride = bitmapWidth * 3;`. GDI+ (`GdipCreateBitmapFromScan0`) requires `stride` to be a multiple of 4 bytes (`(bitmapWidth * 3 + 3) & ~3`); whenever `bitmapWidth % 4 != 0`, `GdipCreateBitmapFromScan0` fails with `InvalidParameter` while `pixels` is already allocated, leaking or dangling the buffer.
- **Fix:** Guard `adaptImageGivenSize` against zero dimensions, remove lines 414–418 in `coreRenderPdfPageAsBitmap` (`nSize` already adapts to `*givenW` and `*givenH`), and align `cbStride` to 4 bytes (`((bitmapWidth * bytesPerPixel + 3) & ~3)`).

---

### 4.6. [`WicD2DrenderSVG`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/svg-render.h#L67-L125) — Null-Pointer Dereference on `wicFac` / `d2dFac` and Double-Scaling of SVGs With `viewBox`

> **Verified 2026-10-27:** 4.6.1 Confirmed, latent (the factories exist whenever the DLL loads); 4.6.2 Not a bug (both callers use scale 1 for such SVGs).

- **Severity:** Medium
- **Location:** [svg-render.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/svg-render.h#L79-L124)
- **Root Cause:**
  1. `WicD2DrenderSVG` dereferences `wicFac->CreateBitmap(...)` (line 79) and `d2dFac->CreateWicBitmapRenderTarget(...)` (line 91) without checking if `wicFac == nullptr` or `d2dFac == nullptr` (e.g., if `D2D1CreateFactory` failed during `initWIC`).
  2. At line 108, `dc5->CreateSvgDocument(pStream, D2D1::SizeF((FLOAT)width, (FLOAT)height), &svgDoc)` sets the SVG viewport size to the already-scaled target `(width, height)`. For any SVG whose root `<svg>` element has a `viewBox` attribute and either percentage or omitted `width`/`height`, Direct2D automatically scales the `viewBox` to fill the `(width, height)` viewport. Then lines 118–120 apply `pRenderTarget->SetTransform(D2D1::Matrix3x2F::Scale(fSx, fSy))` on top of that, scaling the SVG a **second** time by `(fSx, fSy)` (so a $2\times$ upscale renders at $4\times$ and clips 75% of the graphic).
- **Fix:** Null-check `wicFac` and `d2dFac` at the start of `WicD2DrenderSVG`, and pass the unscaled intrinsic viewport `D2D1::SizeF((FLOAT)oWidth, (FLOAT)oHeight)` to `CreateSvgDocument` when applying `Matrix3x2F::Scale(fSx, fSy)`.

---

## 5. Thumbnail Worker Pool & OpenCV Filters (`lib/thumbs-pool.h`, `lib/open-cv-func.h`)

### 5.1. [`thumbsPoolShutdown`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L2106-L2167) & [`dupesPixShutdown`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-pixels.h#L1503-L1554) — Detached Worker Threads Cause Use-After-Free at DLL Unload and Collide With New Workers on Re-Init

> **Verified 2026-10-27:** 5.1.1 Not a bug (the pools stop only at exit and the app then terminates itself); 5.1.2 Confirmed, latent (the pools are never restarted).

- **Severity:** High
- **Location:** [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L2047-L2167), [dupes-pixels.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-pixels.h#L1442-L1554)
- **Root Cause:**
  In both `thumbsPoolShutdown()` and `dupesPixShutdown()`, if a worker thread is blocked inside a slow WIC/FreeImage/network I/O call for more than 5 seconds (`tpExitCV.wait_for(..., 5000ms)`), the shutdown routine detaches the still-running thread (`t.detach()`) and resets `tpRunning = false` / `dpRunning = false`.
  1. **Process exit / DLL unload Use-After-Free:** If `thumbsPoolShutdown()` or `dupesPixShutdown()` was called before process exit, `DllMain(DLL_PROCESS_DETACH)` sees `tpRunning == false` and returns immediately, allowing the C++ runtime to destroy static globals (`tpMutex`, `tpResults`, `tpJobPaths`, `dpMutex`, `dpBusy`, etc.) while the detached worker thread is still executing and subsequently locks the destroyed `std::mutex` or writes to destroyed `std::vector`s.
  2. **Re-initialization worker resurrection & slot collision:** If `thumbsPoolInit()` or `dupesPixInit()` is called again in the same session, it sets `tpStopping = false` / `dpStopping = false` and `tpExited = 0` / `dpExited = 0`. When the old detached worker finally finishes its stalled I/O call:
     - It sees `tpStopping == false` / `dpStopping == false` and **re-enters the active worker loop** instead of exiting!
     - In `dupes-pixels.h`, the old worker has the same `mySlot` index as one of the newly spawned workers, so two threads concurrently overwrite `dpBusy[mySlot]` without synchronization and corrupt `inFlight` counts.
     - If it does exit, it increments the new session's `tpExited` / `dpExited` counter, causing the next shutdown to think all new workers have exited while one is still running.
- **Fix:** Give each pool initialization a monotonically increasing `poolEpoch` ID captured by value in each worker thread. Workers must exit immediately whenever `myEpoch != currentPoolEpoch || stopping`, and `tpExited`/`dpExited` must only be incremented when `myEpoch == currentPoolEpoch`.

---

### 5.2. [`thumbsPoolSetFormats`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1956-L1961) vs [`tpRunJob`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1638) — Unsynchronized Data Race on `tpWicExts` and `tpFimExts`

> **Verified 2026-10-27:** **Confirmed**, for a different reason: the writer does lock; the workers read without the lock (reproduced with TSan).

- **Severity:** High
- **Location:** [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1638), [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1708), [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1956-L1961)
- **Root Cause:**
  `thumbsPoolSetFormats(const wchar_t* wicList, const wchar_t* fimList)` calls `tpParseExts(wicList, tpWicExts)` and `tpParseExts(fimList, tpFimExts)` (which call `.clear()` and `.insert(...)` on those global `std::unordered_set<std::wstring>` instances) without acquiring `tpMutex`. Meanwhile, background worker threads in `tpRunJob` concurrently read `tpFimExts.count(ext)` (line 1638) and `tpWicExts.count(ext)` (line 1708) without synchronization. Concurrent `clear()`/`insert()` and `count()` on `std::unordered_set` is undefined behavior and can dereference freed hash buckets.
- **Fix:** Protect `tpWicExts` and `tpFimExts` reads/writes with `tpMutex` (or a dedicated `std::shared_mutex`).

---

### 5.3. [`tpFIMthumb`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1365-L1379), [`tpWICload`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L762-L805), & [`tpConvertSVGunitsToPixels`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1139-L1146) — Missing `JPEG_EXIFROTATE`, Dead HDR-TIFF FreeImage Fallback, Silent Scaler Fallback, and `"in"` Shadowing `"vmin"`

> **Verified 2026-10-27:** 5.3.1 **Confirmed** (with "Always open with FreeImage" JPEG thumbnails ignore EXIF orientation); 5.3.2 **Confirmed** (HDR TIFF hand-off dead in the pools); 5.3.3 Intentional or known (no crop; the full-size fallback is 10-06 item 44); 5.3.4 **Confirmed** ("vmin" read as inches, also in the AHK).

- **Severity:** Medium
- **Location:** [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L762-L805), [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1139-L1146), [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1365-L1379), [thumbs-pool.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/thumbs-pool.h#L1717)
- **Root Cause:**
  1. **Missing `JPEG_EXIFROTATE` in `tpFIMthumb` (line 1368):** Unlike `tpFIMload` (line 1304, which passes `flags |= 0x0008` for `JPEG_EXIFROTATE`), `tpFIMthumb` only sets `int flags = (maxEdge << 16);` (`0x0008` is omitted). When `MakeThumbnail` loads a JPEG via FreeImage, EXIF orientation is ignored, producing sideways/upside-down thumbnails and un-swapped `srcW`/`srcH`.
  2. **Hardcoded `isFIMokay = 0` in `tpRunJob` (line 1717):** `tpWICload` has an escape hatch at line 762 (`if (isFIMokay && bpp > 32 && imgFormat == 2)`) to hand off `> 32 bpp` HDR/float TIFFs to FreeImage's tone-mapper. However, the only caller (`tpRunJob`, line 1717) passes a hardcoded literal `0` for `isFIMokay` instead of checking `FIM.ok`, making the escape hatch dead code.
  3. **Silent fallback to unscaled full-resolution frame in `tpWICload` (lines 797–804):** If `WICguardedScalerInit` fails (`hr` fails) while `pTransform == nullptr` (`rotFlag == WICBitmapTransformRotate0`), the `else if (pTransform)` branch is not taken, leaving `hr = S_OK` (from `pFac->CreateBitmapScaler` at line 795) and `pSource` pointing to the unscaled full-resolution `pFrame`. Line 826 then copies only the top-left `tw x th` crop of the full-size image instead of a scaled thumbnail.
  4. **`"in"` substring check shadows `"vmin"` in `tpConvertSVGunitsToPixels` (lines 1139–1146):** Line 1139 checks `if (s.find("in") != std::string::npos)` before line 1145 checks `else if (s.find("vmin") != std::string::npos)`. Because `"vmin"` contains `"in"`, SVG dimensions specified in `vmin` are always miscalculated as inches (`* 96.0f`). Same issue exists in [svg-render.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/svg-render.h#L36-L42).

---

### 5.4. [`openCVdiffBlendBitmap`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L8-L26) — Overwrites `bitmap(destROI)` With `otherData(sourceROI)` Before Computing `cv::subtract(bitmap, otherData, bitmap)`

> **Verified 2026-10-27:** Not a bug. The copy builds the shifted operand of a shift-difference filter; zero shift gives a flat result by definition.

- **Severity:** High
- **Location:** [open-cv-func.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L8-L26)
- **Root Cause:**
  ```cpp
  if (blur>1)
     cv::GaussianBlur(otherData, otherData, cv::Size(blur, blur), 0, 0, cv::BORDER_DEFAULT);

  if (std::abs(offsetX)<w && std::abs(offsetY)<h)
  {
     cv::Rect sourceROI(std::max(0, -offsetX), std::max(0, -offsetY), w - std::abs(offsetX), h - std::abs(offsetY));
     cv::Rect destROI(std::max(0, offsetX), std::max(0, offsetY), w - std::abs(offsetX), h - std::abs(offsetY));
     otherData(sourceROI).copyTo(bitmap(destROI));
  }
  cv::subtract(bitmap, otherData, bitmap);
  ```
  1. `otherData(sourceROI).copyTo(bitmap(destROI))` overwrites `bitmap` inside `destROI` with `otherData` **before** `cv::subtract(bitmap, otherData, bitmap)` runs!
  2. When `offsetX == 0 && offsetY == 0`, `sourceROI` and `destROI` cover the entire `w x h` image, so `otherData` completely overwrites `bitmap`, and `cv::subtract(bitmap, otherData, bitmap)` subtracts `otherData` from itself, producing an **all-black (`0`) image** regardless of the input or `blur` setting!
  3. Even when `offsetX != 0 || offsetY != 0`, `otherData` is modified in-place by `copyTo` if the caller passed overlapping buffers, and `bitmap`'s original pixels inside `destROI` are destroyed before subtraction.
- **Fix:** Do not copy `otherData(sourceROI)` over `bitmap(destROI)`. Instead, shift `otherData` into a temporary `cv::Mat` (or subtract `otherData(sourceROI)` directly from `bitmap(destROI)`).

---

### 5.5. [`openCVedgeDetection`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L28-L82), [`openCVblurFilters`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L155-L214), & [`openCVresizeBitmapExtended`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L261-L320) — Uncaught `cv::Exception` Across `DLL_API` Boundaries

> **Verified 2026-10-27:** 5.5.1 Confirmed, latent (the panel sends valid values; extractChannel was removed in 2024); 5.5.2 Not a bug (no Sobel/Laplacian in that function); 5.5.3 Confirmed, latent (every caller passes the whole image).

- **Severity:** High (Crash)
- **Location:** [open-cv-func.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L28-L82), [open-cv-func.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L155-L214), [open-cv-func.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/open-cv-func.h#L266-L273)
- **Root Cause:**
  1. **`openCVedgeDetection` (no `try/catch` block):**
     - `ks` is not forced odd or clamped to `<= 31`: if `ks` is even or `> 31`, `cv::Sobel`, `cv::Laplacian`, and `cv::Canny` throw an uncaught `cv::Exception`, terminating the host process.
     - For `modus == 4` (`cv::Canny`), OpenCV requires `apertureSize` in `{3, 5, 7}`; if `ks == 1`, `cv::Canny` throws `cv::Exception`.
     - If `modus > 4` or `modus < 0`, `edgeImage` remains an empty `0x0` `cv::Mat`, and `cv::cvtColor(edgeImage, ...)` at line 79 throws `cv::Exception`.
     - When `channel == 4 && bpp == 24` (`channels == 3`), `cv::extractChannel(bitmap, gray, 3)` extracts channel index `3` on a 3-channel matrix, throwing `cv::Exception`.
  2. **`openCVblurFilters` (no `try/catch` block):**
     - If `intensityX > 31` or `intensityY > 31` with `modus == 4` (`cv::Sobel`) or `modus == 5` (`cv::Laplacian`), OpenCV throws `cv::Exception` because maximum derivative kernel size is 31.
  3. **`openCVresizeBitmapExtended` (lines 266–271):**
     - `cv::Mat subImage = image(subRect);` at line 271 is executed **outside** the `try/catch` block (which starts at line 272). Furthermore, if `srcX >= srcW`, `srcY >= srcH`, `srcWsub <= 0`, or `srcHsub <= 0`, `subRect.width` or `subRect.height` is `<= 0`, causing `image(subRect)` to throw an uncaught `cv::Exception`.
- **Fix:** Wrap `openCVedgeDetection` and `openCVblurFilters` in `try/catch (...)`, clamp `ks` to odd values in `[3, 7]` for `Canny` and `[1, 31]` for `Sobel`/`Laplacian`, clamp `channel` to `< channels`, and move `image(subRect)` inside the `try` block in `openCVresizeBitmapExtended` after clamping `subRect` dimensions to `>= 1`.

---

## 6. Duplicate Search & Pixel Hashing (`lib/dupes-search.h`, `lib/dupes-pixels.h`)

### 6.1. [`dupesEngineCancel`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1772-L1778) vs [`dupesEngineRelease`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1711-L1715) / [`dupesEngineInit`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1754-L1765) — Data Race and Use-After-Free on `dupesDB`

> **Verified 2026-10-27:** Confirmed, latent. Reproduced with TSan, but since the interface-thread merge only one thread calls the engine.

- **Severity:** High
- **Location:** [dupes-search.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1649), [dupes-search.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1711-L1715), [dupes-search.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1754-L1778)
- **Root Cause:**
  `dupesEngineCancel()` is specifically designed to be called asynchronously from another thread to abort an in-progress search:
  ```cpp
  DLL_API int dupesEngineCancel(void) {
      dupesCancel.store(true);
      if (SQ.ok && dupesDB) SQ.interrupt(dupesDB);
      return 1;
  }
  ```
  However, `dupesDB` is a plain `sqlite3*` pointer (`static sqlite3* dupesDB = NULL;`) with no mutex protecting its lifecycle in `dupesEngineRelease()` or `dupesEngineInit()`:
  ```cpp
  if (dupesDB) { SQ.close_v2(dupesDB); dupesDB = NULL; }
  ```
  If `dupesEngineCancel()` executes concurrently with `dupesEngineRelease()` or `dupesEngineInit()`, `dupesEngineCancel()` can pass a closed/freed `sqlite3*` pointer to `sqlite3_interrupt(dupesDB)` (use-after-free).
- **Fix:** Guard `dupesDB` access and `SQ.close_v2` / `SQ.interrupt` with a `std::mutex`.

---

### 6.2. [`dupesQueryStep`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L2109-L2113) — Single Row With Unusable Hash Splits the Current Key Run and Drops Valid Duplicate Pairs

> **Verified 2026-10-27:** Confirmed, latent. Reproduced with a real SQLite; the app's query and hash writer never produce an unusable hash.

- **Severity:** Medium
- **Location:** [dupes-search.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L2109-L2127)
- **Root Cause:**
  During non-hash-only grouping (`dupesAlg != 1 && dupesAlg != 2`), rows are ordered by the grouping key (`ORDER BY <key columns>`), and consecutive rows sharing the same `key` are accumulated into a run `[dupesRunStart .. dupesRows.size())`. When the key changes, `dupesCloseRun()` compares all pairs within the run (requiring at least 2 items: `if (n - dupesRunStart < 2) { dupesRows.resize(dupesRunStart); return; }`).
  However, at lines 2109–2113, if a row has an invalid/unparseable hash (`!usable`):
  ```cpp
  if (!usable) {
      dupesCloseRun();
      dupesKeyPrev.clear();
      continue;
  }
  ```
  Calling `dupesCloseRun(); dupesKeyPrev.clear();` forcibly splits the current group of identical keys in two! For example, if 2 files share the exact same key (`FileA` with valid hash, `FileB` with corrupt/empty hash, `FileC` with valid hash):
  1. `FileA` starts the run (`dupesRunStart = 0`, `size = 1`).
  2. `FileB` has `!usable`: `dupesCloseRun()` sees `n - dupesRunStart == 1 < 2` and **discards `FileA`**!
  3. `FileC` starts a new run (`size = 1`), and at the next key change `dupesCloseRun()` sees `size == 1 < 2` and **discards `FileC`**!
  As a result, the valid duplicate pair `(FileA, FileC)` is completely lost.
- **Fix:** When `!usable`, simply `continue;` to skip the unusable row without calling `dupesCloseRun()` or clearing `dupesKeyPrev`.

---

### 6.3. [`dupesHaveMSD`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1380-L1387) & [`dupesApplyFilter`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1410-L1412) — `mseLo` / `mseHi` Filter Silently Ignored When Only 1 Duplicate Pair Exists

> **Verified 2026-10-27:** **Confirmed.** The two-pair rule is deliberate, but it also skips the search's own MSD threshold for single-pair results.

- **Severity:** Medium
- **Location:** [dupes-search.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1380-L1387), [dupes-search.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-search.h#L1410-L1412)
- **Root Cause:**
  ```cpp
  static int dupesHaveMSD(void) {
      size_t n = dupesPairsList.size();
      if (n < 2) return 0;
      int hits = 0;
      for (size_t i = 0; i < (n / 2) + 1; ++i)
          if (dupesPairsList[i].msd >= 0.0f) { if (++hits >= 2) return 1; }
      return 0;
  }
  ```
  `dupesHaveMSD()` requires `n >= 2` and at least `2` pairs with `msd >= 0.0f` in the first half of `dupesPairsList`.
  - Whenever a duplicate search finds **1 duplicate pair** (`n == 1`), `dupesHaveMSD()` returns `0` even if `dupesPairsList[0].msd >= 0.0f` was computed!
  - Whenever `n >= 4` and only 1 pair in the first half has `msd >= 0.0f` (while pairs in the second half have `msd >= 0.0f`), `dupesHaveMSD()` also returns `0`.
  In `dupesApplyFilter()` (line 1411), `bool useMse = (mseLo > 0.0f || mseHi > 0.0f) && (dupesHaveMSD() == 1);` becomes `false`, causing the user's `mseLo`/`mseHi` filter to be completely ignored.
- **Fix:** Return `1` in `dupesHaveMSD()` if **any** pair in `dupesPairsList` has `msd >= 0.0f` (or track a boolean `dupesMsdComputed` flag).

---

### 6.4. [`dpHistogram`](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-pixels.h#L350-L397) — Wrong Minimum Histogram Bin (`minu`) on Solid-Color / Single-Tone Images

> **Verified 2026-10-27:** **Confirmed.** Single-level images store level 0 as their rarest level, in the DLL and in the AHK original.

- **Severity:** Low
- **Location:** [dupes-pixels.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-pixels.h#L354), [dupes-pixels.h](file:///home/marius/repos/Quick-Picto-Viewer/QPV%20DLL%20source%20code/lib/dupes-pixels.h#L382-L386)
- **Root Cause:**
  `dpHistogram` initializes `UINT64 pixMinu = (UINT64)((INT64)w * (INT64)h);` (line 354) and searches for the least-populated non-zero luminance bin using strict `<`:
  ```cpp
  if (nrPixelz < pixMinu) {
      pixMinu = nrPixelz;
      minPointK = lvl;
  }
  ```
  For any solid-color / single-tone image where all `w * h` pixels fall into a single luminance level `lvl > 0`, that bin has `nrPixelz == w * h == pixMinu`, while all other 255 bins have `nrPixelz == 0` (skipped by `if (!nrPixelz) continue;`). Because `nrPixelz < pixMinu` is `false`, `minPointK` remains at its initial value `0`, reporting `res.minu = 1.0f / 256.0f` instead of `(lvl + 1) / 256.0f`.
- **Fix:** Initialize `pixMinu = UINT64_MAX;` (or use `nrPixelz <= pixMinu`).
