# Frame and page extractor audit, 2026-11-03

Scope: `batchExtractFramesFromImages()` (:61948) and `coreExtractFramesFromImage()` (:62534),
with the routines they hand files to: `coreExtractFramesFromTiff()` (:62052),
`coreExtractFramesFromWEBP()` (:62286) and `coreExtractBatchModeTextsFromGivenPDF()` (:62450),
plus `PanelExtractFrames()` (:43541) and `BTNperformExtractFrames()` (:44103), which drive them.
Line numbers are `quick-picto-viewer.ahk` on `development` at 622f848. They are unchanged at
4c8ec92 (Marius, 2026-11-03), whose fixes are marked in the findings below. Findings 2 and 5
to 8 were fixed in `6065e4f`, after Marius's decisions; see «What `6065e4f` changed on purpose».

This follows the 2026-08-30 audit of the same code (report in 7a00a9c, fixes in 34ae01f). Its
findings are not repeated; their status is in the table near the end.

## Terms

- **WIC**: Windows Imaging Component, the Windows codec layer that qpvmain.dll drives.
- **FIF**: a FreeImage format number, what `FreeImage_GetFileType()` returns; the code keeps
  it in `GFT`. ICO 1, MNG 6, PNG 13, TIFF 18, GIF 25, WEBP 35, AVIF 37, HEIF 38, APNG 39, JXL 40.
- **PLAYBACK flag**: a `FreeImage_OpenMultiBitmap()` flag; with it, the fork's plugins hand
  over every frame as a viewer shows it, composed on the canvas. GIF, APNG, MNG, AVIF, HEIF
  and JXL take 2, WEBP takes 1 (`lib/freeimage-wrapper.ahk` :1375-1387). Without it, frames
  come as stored.
- **Sub-frame**: a frame as stored in an animation file. In GIF, APNG, WebP and MNG it is
  often only the rectangle that changed, placed by an offset.
- **ANMF**: the WebP chunk that holds one animation frame.
- **r**: what the extractors return. 1 or more = the file's frame or page count (success),
  −1 = FreeImage could not open the TIFF, −2 = a single frame, −3 = no frame support (or, in
  PDF text mode, the text file was skipped), −4 = failed, −5 = aborted.

## Summary

- **One regression** from the 08-30 fixes: the batch summary counted almost every successful
  file as skipped (finding 1). **Fixed in `4c8ec92`.**
- **None of JXL, APNG, MNG, AVIF or HEIC/HEIF is handled.** The panel advertises JXL, MNG
  and APNG, and the batch filter admits all five. The extractor sends them to GDI+, which
  cannot decode them or reads only one image. The viewer and the join-images tool read
  their frames through FreeImage, and the shipped FreeImage.dll reports every frame (finding 2).
  **Fixed in `6065e4f`.**
- **Multi-page files**: GIF, TIFF and PDF are extracted, and WebP where Windows has a WebP
  codec. HEIF collections, bursts and sequences, AVIF sequences, multi-size ICO files and
  APNG are not. **Since `6065e4f` all of them are, and WebP needs no Windows codec.**
- Two medium defects: saved output formats point at other formats since 0a5b8e1 (finding 3,
  **partly fixed in `4c8ec92`**), and PDF text mode wrote a file named `abort` when the user
  cancelled (finding 4, **fixed in `4c8ec92`**). One medium-low: TIFF pages ignore «Color
  depth» (finding 5, **fixed in `6065e4f`**). Six low or latent items follow; 6 to 8 are
  **fixed in `6065e4f`**.

## What `6065e4f` changed on purpose

Marius's decisions of 2026-11-03, and what follows from them. Check here before calling any
of it a regression.

- **Routes.** `coreExtractFramesFromImage()` asks `FreeImage_GetFileType()` first, so files go
  by content, not by extension. ICO, MNG, TIFF, WebP, AVIF, HEIF, APNG and JXL go to
  `coreExtractFramesFromFIMfiles()`, which replaces `coreExtractFramesFromTiff()`. GIF still
  goes to GDI+. Any other format FreeImage knows answers −3 without being decoded, so plain
  PNGs in a batch cost nothing. A TIFF that FreeImage cannot open goes to GDI+. With FreeImage
  missing or «Allow FreeImage loader» off, only GIF, TIFF and PDF files are extracted.
- **Flags.** Pages open through `combineFimOpenPages()`, the join tool's opener: TIFF with no
  flag, WebP with WEBP_PLAYBACK (1), the other animations with their PLAYBACK flag (2), ICO
  with ICO_MAKEALPHA (1). JXL, AVIF and HEIF frames therefore arrive at 8 bits per channel,
  as the viewer shows them. ICO is opened by pages for the extractor only (`withIcons=1`);
  the join tool still reads the first icon.
- **Depth.** A frame keeps its own depth when the output format holds it; otherwise it takes
  the panel's depth, now labelled «Fallback depth» with a tooltip; otherwise the closest
  depth the format allows. `coreConvertImgFormat()` applies this through its new
  `fallbackLevel` parameter, which only the extractor passes.
  - TIFF pages come from FreeImage at their stored depth; the WIC step, and its conversion
    to sRGB, are gone. The embedded colour profile goes into the output: PNG, TIFF, JPG,
    WebP, JXL and BMP keep it, GIF cannot. Since `2b3d5da`, see «Colour management» below,
    formats without profiles get sRGB pixels instead, and CMYK pages go through their profile.
  - Frames composed at 32 bits go back to the depth their file stores, when nothing is lost
    (`FIMfitFrameToFileDepth()`). The depth comes from the first page header, or from each
    page of an ICO file. Opaque frames of files without alpha become 24 bits. Opaque frames
    of palette or grey files with up to 256 colours become 8 bits, with an exact palette;
    grey ones stay greyscale. Everything else stays at 32 bits, palette files with
    transparency included.
  - GIF frames, still drawn by GDI+, follow the palette rule: 8 bits when opaque, 32 bits
    with transparency. PDF pages keep using the panel's depth.
  - 1-bit pages still become the fallback depth, except in GIF output: the depth tables
    have no 1-bit entry, and Marius chose to leave them so.
  - A page whose pixel type the format cannot store takes the fallback depth before the
    nearest high-depth type. A float TIFF page saved as PNG with «24 bits» is tone mapped to
    24 bits, not written as RGB16 as the format converter does.
- **Format converter, all callers of `coreConvertImgFormat()`.** The colour profile is kept
  across its rescale and depth conversions, where it suits the new pixels. 16-bit greyscale
  goes to 8-bit grey by its high bytes for formats without a 16-bit grey type, which fixes
  finding 5 of the 2026-11-02 converter audit. Without `fallbackLevel`, the 2026-11-02
  converter suites give the same results as before in every other case.
- **Removed:** the WIC WebP route, `coreExtractFramesFromWEBP()`, and its helpers
  `parseWEBPanimation()`, `compositeWEBPframeOnCanvas()`, `disposeWEBPframeArea()` and
  `readWEBPuint24()`. WEBP_PLAYBACK composes the frames.
- **Size caps.** The extractor no longer rescales oversized pages itself; `coreConvertImgFormat()`
  caps them per format. This ends the 715 MPx full-size rescale on the FreeImage and GIF
  routes. PDF pages, and frames saved without FreeImage, still go through `isImgSizeTooLarge()`.
- **Colour management, `2b3d5da` (Marius, 2026-11-04).** Only with «Color management» on
  (`userPerformColorManagement=1`):
  - `coreConvertImgFormat()` converts an image that carries a profile to sRGB before saving
    it to a format that cannot store one (`FreeImage_FIFSupportsICCProfiles()` is false: GIF,
    TGA, PPM, XPM, J2K, ICO, HDR, EXR, PFM). The conversion uses relative colorimetric with
    black point compensation, as the viewer does; untagged files are read as sRGB. This
    applies to every caller: converter, extractor, huge-image save, resize panel, clipboard save.
  - The conversion runs on a clone (`FreeImage_ApplyICCProfile()`), so palettes keep 8 bits
    and the view of the huge image that `saveHugeVPimageFile()` hands over is not touched.
    `FreeImage_ConvertToICCProfile()` takes over when the pixel format must change.
  - Not FIF_LOAD_DISPLAY_ICC, which Marius proposed: QPV pins no display profile, so that
    flag converts to the monitor profile Windows reports, which is wrong for untagged files
    read elsewhere.
  - The extractor opens TIFFs with TIFF_CMYK and converts CMYK pages to sRGB through their
    own profile (`FreeImage_ConvertCMYKToRGB()`), for every output format. A CMYK page
    without a profile comes out as FreeImage's plain ink formula makes it, as before.
  - `e39834b`: the batch workers (`initExternalCoreMode()`) read the setting from the INI,
    as the main window does; they used to keep its default, on. `FIMrescaleICOmode()`
    copies the profile onto its 256 px canvas, so a larger image saved as ICO is converted
    too; with the setting off, that profile now goes into the icon's PNG entry.
  - Wine run: Adobe RGB (200,60,40) and (40,90,200) reach GIF, TGA, PPM and XPM as
    (231,57,34) and (0,90,204), what Pillow's Little CMS gives, and every frame equals
    FreeImage's own sRGB conversion of it. PNG and JPG keep the profile and the pixels. The
    image behind a view was left unchanged. A 400×300 Adobe RGB image saved as ICO reads
    (230,56,33) at the icon's centre, one level under because `FIMrescaleICOmode()` pastes
    with a 255/256 blend, as before. The 2026-11-02 converter suites and the extraction test
    show no unintended change of depth or type; they do not compare pixels for formats
    without profiles, and their profiled sources keep their pixels in the formats they test.
  - Not run: CMYK pages with alpha and 16-bit CMYK pages; float images with a profile saved
    as HDR, EXR or PFM; the workers' INI read; WIC's own conversion (Wine applies none), and
    whether it leaves no profile behind, which rests on reading `teleportWICtoFIM()`. A CMYK
    page whose conversion fails counts as failed, without a journal line. A profiled huge
    image saved without a profile is cloned in full once.

## Format coverage

The batch filter is `thisRegEX` (:61951). Single-file mode applies no filter.

| Format | Batch filter | Route in `coreExtractFramesFromImage()` | Outcome | Frames the shipped FreeImage.dll reports |
|---|---|---|---|---|
| GIF | admits | GDI+ frames, composed by GDI+ | extracted | 4 (anim.gif), 3 (sample.gif) |
| TIFF | admits | FreeImage pages, each decoded by WIC first | extracted | 16 (mpages.tif) |
| PDF | admits | PDFium | extracted | n/a |
| WebP | admits | WIC frames, composed by QPV from the ANMF chunks | extracted where a WIC WebP codec reports the frames (finding 6) | 4 |
| APNG, `.apng` or `.png` | admits | GDI+, which reads it as a plain PNG | −3 | 4, FIF 39 under both names |
| MNG | admits | GDI+, no decoder | −4 | 4 (mng_anim), 3 (mng_disposal) |
| JXL | admits | GDI+, no decoder | −4 | 5, 4, 3 |
| AVIF | admits | GDI+ | −4, or −3 where GDI+ decodes it through a Windows codec | 5 |
| AVIF sequence, `.avifs` | skips | GDI+ (single file) | skipped / −4 | 5 |
| HEIC, HEIF | admits | GDI+ | −4, or −3 where GDI+ decodes it through the Windows HEIF extension | 4 (collection), 90 (burst), 120 (animation), 4 (sequence with a still) |
| HEIF sequence, `.heics` | skips | GDI+ (single file) | skipped / −4 | 6, 4 |
| ICO | skips | GDI+, raw format Icon | skipped / −3 | 3, one page per icon size |
| plain PNG | admits | GDI+ decodes the whole image | −3 | 1 |

Single-file messages (:44136-44145): −4 «ERROR: Failed to load the image. No frames or pages
were extracted», −3 «WARNING: The image format does not have support for multiple frames».

---

## 1. The batch summary counts almost every successful file as skipped (regression, 34ae01f)

**Fixed in `4c8ec92`:** the line now reads `Else If (r=-3 || r=-2)`, which counts files as in
the right-hand column of the table below.

`batchExtractFramesFromImages()` :62021

```ahk
If (r=-4)
   failedFiles++
Else If (r=-3 || r-2)
   skippedFiles++
Else If (r>=1)
   countFilez++
Else 
   failedFiles++
```

`r-2` is a subtraction, not `r=-2`, so the test is true for every `r` except 2. These lines,
run under Wine with the AutoHotkey_H interpreter QPV uses, give:

| r | meaning | counted now as | with `r=-2` |
|---|---|---|---|
| 1, 3, 10 | extracted; r is the frame or page count | skipped | processed |
| 2 | extracted, 2 frames | processed | processed |
| 0 | a PDF of no pages | skipped | failed |
| −1 | FreeImage could not open the TIFF | skipped | failed |
| −2 | a single frame | skipped | skipped |
| −3 | no frame support | skipped | skipped |
| −4 | failed | failed | failed |

Ten animated GIFs of five frames each therefore end with «0 out of 10 selected files were
processed … frames extracted: 50 / 50 ( 100.0% ) … Skipped files: 10». The frame totals stay
right, because the `r>=1` block just above adds them first. PDF text mode goes through the
same lines, so every PDF without exactly 2 pages counts as skipped. A single-page PDF, which
the 08-30 fix set out to count as a success, counts as skipped in a batch; single-file mode
reports it correctly.

Origin: the «clean-ups» commit squashed into 34ae01f (2026-08-30) merged `Else If (r=-3)`
and `Else If (r=-2)` into one line and dropped the `=`.

---

## 2. JXL, APNG, MNG, AVIF and HEIC/HEIF frames are never extracted

**Fixed in `6065e4f`:** files are routed by `FreeImage_GetFileType()`, and JXL, APNG
(under either name), MNG, AVIF, HEIF, ICO, WebP and TIFF go to `coreExtractFramesFromFIMfiles()`,
with the PLAYBACK flags. See «What `6065e4f` changed on purpose».

`coreExtractFramesFromImage()` picks its route from the extension: `.webp` goes to WIC
(:62537), `.tif`/`.tiff` to FreeImage (:62543) and `.pdf` to PDFium (:62549). Everything
else goes to GDI+ (:62644) and is accepted only when GDI+ reports the raw format GIF or TIFF
(:62648):

- JXL and MNG: GDI+ has no decoder, so the result is −4.
- APNG, named `.apng` or `.png`: GDI+ reads it as a PNG with one image, so the result is −3.
- AVIF and HEIC/HEIF: −4, or −3 where GDI+ decodes them through an installed Windows codec.
  Either way, no frames.

Meanwhile:

- the panel reads «Extract frames or pages from GIF, TIFF, PDF, JXL, MNG, APNG or WEBP
  files.» (:43569). APNG has been listed since 4a594a2 (2026-09-19), JXL and MNG since
  64f6ebd (2026-10-12).
- the batch filter (:61951) has admitted apng, png, mng, avif, heif, heic and jxl since
  d6a5681 (2026-10-12). Before, it was `pdf|gif|tif|tiff|webp` and these files were skipped
  unread. Now each one is decoded by GDI+ first, and so is every plain PNG in the selection.
- the viewer opens all of them as FreeImage multi-page bitmaps (`LoadFimFile()` :99781), and
  so does the join-images tool (`combineFimOpenPages()` :63325).

The shipped FreeImage.dll (3.20.0, 9b41683) reads every frame. Wine run, page sizes in
pixels:

| Sample | No flag: frames as stored | PLAYBACK flag: frames as shown |
|---|---|---|
| anim-apng.png (an APNG named .png) | 160×120, then 55×25 ×3 | 160×120 ×4 |
| anim.webp | 160×120, then 55×25 ×3 | 160×120 ×4 |
| anim.gif | 160×120, then 55×25 ×3, 4 bpp | 160×120 ×4, 32 bpp |
| mng_anim.mng | 16×16 ×4 | 64×48 ×4 |
| anim16_lossy.jxl | 36×28 ×3, RGBA16 | 36×28 ×3, 8-bit RGBA |
| colors-animated-12bpc-keyframes-0-2-3.avif | 64×64 ×5, RGBA16 | 64×64 ×5, 8-bit RGBA |
| seq-10bit.heics | 64×64 ×4, RGB16 | 64×64 ×4, 8-bit RGBA |

What this means for a fix:

- An APNG named `.png` is FIF 39, so routing on `FreeImage_GetFileType()`, which reads the
  content, finds it; the extension cannot.
- GIF, APNG, WebP and MNG need their PLAYBACK flag, or frames 2..N come out as the changed
  rectangles.
- JXL, AVIF and HEIF frames are whole without the flag. The fork's JXL plugin leaves libjxl's
  frame coalescing on, and AVIF and HEIF sequence frames are whole pictures. The flag only
  turns 10- to 16-bit frames into 8-bit RGBA. `combineFimOpenPages()` passes 2 to them,
  which suits joining animations; an extractor may want 0 to keep the depth (decision 3).
- Since `4c8ec92`, `LoadFimFile()` passes 2 to MNG as well, so its flags and
  `combineFimOpenPages()`'s compose the same formats. They differ only for HEIF (0 against 2),
  which changes the depth, not the composition.
- `coreExtractFramesFromTiff()` decodes each page with WIC first (:62103-62109). If that
  routine becomes the general one, the WIC step must stay TIFF-only: WIC hands over GIF
  frames undisposed (finding 7).

---

## 3. Saved output formats point at other formats since 0a5b8e1; two of them write nothing

**Partly fixed in `4c8ec92`:** `RegAction(0, "userExtractFramesFmt",, 2, 1, 13)` (:43550) now
clamps the stored position to the 13 entries. Stored 14 and 15 become 13, so they write XPM
frames instead of failing, and the dropdown shows «.XPM». Stored 3 to 15 still mean other
formats than they did before 10-13.

0a5b8e1 (2026-10-13) shortened the «File format on save» list from 15 entries to 13
(`saveimgformatslist` :131, `userPossibleWriteFMTs` :130). `userExtractFramesFmt` is stored as
a position in that list, and nothing converts the stored value:

| Stored | Meant before 10-13 | Means now |
|---|---|---|
| 1, 2 | BMP, GIF | BMP, GIF |
| 3 | HDP | JXL |
| 4 | J2K | JNG |
| 5 | JNG | JP2 |
| 6 | JP2 | JPG |
| 7 | JPG | JXR |
| 8 | JXR | PNG |
| 9 | PNG | PPM |
| 10 | PPM | TGA |
| 11 | TGA | TIF |
| 12 | TIF | WEBP |
| 13 | WDP | XPM |
| 14 | WEBP | XPM (clamped) |
| 15 | XPM | XPM (clamped) |

Before 4c8ec92, 14 and 15 opened the dropdown with nothing selected, and `GuiControlGet` read
it back blank (Wine run). The frame names then ended in a bare dot (`name_1.`), no writer
matched the extension, and every frame failed. The panel shows the remapped format, so a user
who looks sees it. One who doesn't gets PPM frames where they had chosen PNG, or XPM where
they had chosen WebP.

The format converter's `userDesireWriteFMT` has the same remap. 4c8ec92 clamps it to 13 in
`ReadSettingsAutoCropPanel()` (:97482), but its four other reads (:38263, :44196, :44649,
:59011) still accept up to 16. It is not analysed further here.

**What remains:** map the old positions once, or store the extension instead of the position
(decision 4).

---

## 4. PDF text mode: «Cancel» at a name collision writes a file named `abort` and carries on

**Fixed in `4c8ec92`:** the function now returns −5 at that point, so the batch stops with
«Operation aborted», as the frame routines do.

`coreExtractBatchModeTextsFromGivenPDF()` :62507

```ahk
If (file2save="abort")
   abandonAll := 1

If !file2save
   Return -3
…
FileAppend, % txt, % file2save, UTF-8
…
Return clampInRange(tFrames, 0, 9892899)
```

`"abort"` is not blank, so the function goes on. It writes the extracted text to a file
literally named `abort` in the working folder (QPV's program folder, `SetWorkingDir` :97457)
and returns the page count as a success. Nothing reads `abandonAll` afterwards, so the batch
moves on to the next PDF; a second «Cancel» replaces the same `abort` file. Where the program
folder is read-only, `FileAppend` fails and the PDF counts as failed. Either way, «Cancel»
never stops the batch. The frame routines all `Break` on `"abort"` and return −5.

---

## 5. TIFF pages ignore «Color depth»

**Fixed in `6065e4f`:** on every route but PDF, the panel's depth, now «Fallback depth», applies
only where the output format cannot store a page's own depth.

The panel's «Color depth» (32 bits RGBA, 24 bits, 16 bits [32768 colors], 8 bits [256
colors]) reaches `QPV_SaveImageFile()` in the WebP, PDF and GDI+ routes (:62418/:62421,
:62626/:62629, :62721/:62724). The TIFF route saves through `coreConvertImgFormat()`
(:62146, :62152), which takes no depth and keeps each page's own depth where the output
format allows it. With «8 bits RGB [256 colors]» and PNG output, GIF frames come out
palettised but TIFF pages in full colour.

Any FreeImage route added for finding 2 inherits this if it also saves through
`coreConvertImgFormat()` (decision 5).

---

## 6. WebP extraction needs a WIC WebP codec; the viewer doesn't

**Fixed in `6065e4f`:** WebP goes through FreeImage with WEBP_PLAYBACK, and the WIC route and
its compositing helpers are removed.

`coreExtractFramesFromWEBP()` decodes only through `LoadWICimage()` (:62319). That needs WIC
(:101400) and a Windows WebP codec, and it ignores `allowWICloader`. The viewer and the join
tool read WebP through FreeImage. On a system without the codec, for example Windows 7 (the
repo ships win7-DLL-files-x64.zip), the viewer plays a WebP that the extractor reports as
«Failed to load the image».

The question left open on 08-30 is still open: whether the Windows WebP codec reports an
animated WebP's frames at all. If it reports one frame, the extractor answers «The image has
no frames or pages to extract» and logs «the WEBP container declares N animation frames while
the decoder reports 1» (:62329).

FreeImage's WEBP_PLAYBACK flag (1) composes the frames itself (table in finding 2). On that
route, `parseWEBPanimation()`, `compositeWEBPframeOnCanvas()` and `disposeWEBPframeArea()`
have nothing left to do.

---

## 7. A GIF renamed to .tif gets undisposed frames while WIC is on

**Fixed in `6065e4f`:** a GIF named .tif is routed to GDI+ by its content, and TIFF pages no
longer go through WIC.

`coreExtractFramesFromTiff()` opens a file whose content is a GIF with GIF_PLAYBACK (:62055,
the 08-30 fix), then decodes every page with WIC first (:62103-62109). WIC hands over GIF
frames as stored, so the composed FreeImage page is used only when WIC fails. This is narrow:
it needs a GIF renamed to `.tif`.

**Fix:** take the WIC step only when `GFT=18`.

---

## 8. When FreeImage cannot open a .tif, nothing else is tried and the message says «undefined error»

**Fixed in `6065e4f`:** a TIFF that FreeImage cannot open goes to GDI+; any other format then
answers −4, «Failed to load the image».

`coreExtractFramesFromTiff()` returns −1 when `FreeImage_OpenMultiBitmap()` fails (:62169).
`coreExtractFramesFromImage()` returns that straight away; it never falls through to the GDI+
branch, which reads multi-page TIFFs too. `BTNperformExtractFrames()` has no message for −1,
so it shows «ERROR: An undefined error has occurred.» (:44145). A batch counts it as failed.

---

## 9. A frame GDI+ cannot select is saved as a copy of the previous one

The GDI+ loop ignores the −1 that `Gdip_BitmapSelectActiveFrame()` returns on failure
(:62695). The bitmap then stays on the previous frame, and that frame is drawn, saved under
the new number and counted as extracted. A damaged GIF or TIFF is where this would show.

---

## 10. Two selected files with the same name write the same frame names

Frames are named `<name>_<N>.<ext>` in one destination folder (:62079, :62381, :62581,
:62669). Two selected files with the same name and different extensions (clip.gif and
clip.webp), or with the same name in two folders, produce the same frame names. The
collision setting cannot tell these apart from leftovers of an earlier run:

- «Overwrite»: the second file's frames replace the first file's without a prompt.
- «Skip files»: all of the second file's frames are dropped, yet the file counts as
  processed.
- «Auto-rename» and «Ask user» keep both sets.

---

## 11. Latent: PDF extraction rewrites the viewer's image details

`RenderPDFpage()` rebuilds the `mainLoadedIMGdetails` global for every page (:100914). After
a PDF extraction, the global describes the last rendered page, not the image in the viewport.
The 08-30 fix made the WebP route back up and restore the global (:62296); the PDF route
doesn't. Nothing reads the stale copy today: every reader found loads an image first
(`GetCachableImgFileDetails()`, `GetCachableHistogramFile()`, the thumbnail-sheet and join
loops).

---

## Still open from 2026-08-30

- `isImgSizeTooLarge()` applies its 715.3 MPx limit (`extraLimit=1`) in the TIFF route
  (:62138) to formats that `getIMGformatLimits()` does not cap. That now includes JXL, the
  default output format. A larger page is rescaled to its own size, which is a full extra
  copy, before it is saved. **Gone from the FreeImage and GIF routes in `6065e4f`**; PDF
  pages, and frames saved without FreeImage, still take it.
- «Action on file name collisions» (`OnExtractConflictOverwrite`) has no `RegAction`, so it
  goes back to «Ask user» on every start.

## Status of the 2026-08-30 findings

| 08-30 # | Item | Now |
|---|---|---|
| 1 | Aborting a batch did not stop it | fixed (:62007) |
| 2 | A single-page PDF was reported as a failure | fixed; in a batch too since 4c8ec92 (finding 1) |
| 3 | The TIFF route leaked the page it rescaled from | fixed (:62144) |
| 4 | Progress tooltip throttle, none in single-file mode | fixed |
| 5 | Batch frame totals | fixed |
| 6 | The WebP route overwrote `mainLoadedIMGdetails` | fixed; the PDF route does the same, latent (finding 11) |
| 7 | WebP frames were written as raw sub-frames | fixed by composing them; FreeImage composes them since `6065e4f` |
| 8 | 715 MPx extra limit | open on the PDF route; gone elsewhere since `6065e4f` |
| 9 | Collision choice not saved | open |
| 10 | Read-only destination files | fixed |
| 11 | GIF_PLAYBACK in the TIFF route | GIF content goes to GDI+ since `6065e4f` (finding 7) |
| 12 | `teleportWICtoFIM()` buffer leak | fixed |
| 13 | `\|\|` marker in single-file mode | fixed (:62536) |

## Seen in passing

- **Fixed in `4c8ec92`:** the viewer opened MNG without the PLAYBACK flag (`LoadFimFile()`
  :99784), so it showed the stored sub-images; mng_anim.mng played as 16×16 pieces of a 64×48
  canvas (Wine run). It now passes 2, as `combineFimOpenPages()` does.
- The viewer's guard against animating GIFs outside FreeImage is dead.
  `LoadBitmapForScreen()` still tests `isAnimFmt` (:75529) to show only the first frame when
  a loader other than FreeImage opens a `.gif` or `.webp`. 98e33f0 (2026-09-21) deleted the
  line that set it, along with `isFIMonlyAnimFile()`, and `isAnimFmt` now occurs only there,
  so it is always blank. `RegExFIMformPtrn` (:117) lists WEBP but not GIF. With the default
  settings, a `.gif` therefore opens through WIC and keeps WIC's frame count. WIC hands over
  stored sub-frames, undisposed, and qpvmain.dll does not compose them. Static analysis only,
  not run on Windows.

## Checked and found correct

- Abort: −5 ends the batch (:62007). Every frame loop stops on the collision dialog's
  «Cancel». `determineTerminateOperation()` returns `mustAbandonCurrentOperations` again
  (c560437).
- FreeImage is loaded before any image or thumbnail is shown: `initQPVmainDLL()` calls
  `initFIMGmodule()` (:2335). The TIFF route's `wasInitFIMlib=1` gate (:62543) fails only
  when FreeImage itself failed to load.
- 16-bit and floating-point TIFF pages: `WICpreLoadImage()` declines them when FreeImage is
  available (`lib/wic-loader.h` :1202), so they come from FreeImage at full depth.
- WebP container parsing matches the format: offsets ×2, sizes +1, flag bit 1 = do not blend,
  bit 0 = dispose. Disposal happens after the frame is written, and compositing continues
  through frames that were skipped or failed to decode.
- `mainLoadedIMGdetails` is restored on all three exits of the WebP route.
- `QPV_SaveImageFile()` converts the bitmap it is given in place. Every bitmap the extractors
  give it is a temporary, disposed right after.
- `coreConvertImgFormat()` with a bitmap passed in unloads it on every path and does not copy
  timestamps. Its own size cap finds nothing left to do after the extractor's.
- Single-file mode: every early return happens before `doStartLongOpDance()`, so no busy
  state is left on.
- The collision dialog's «apply to all» memory is reset at both entry points (:44126,
  :61962).

## Decisions to make before fixing

1. Route by content (`FreeImage_GetFileType()`) or keep the extension switch? Only content
   finds an APNG named `.png`.
2. Which formats take a FreeImage route: the eight `combineFimOpenPages()` reads (MNG, TIFF,
   GIF, WebP, AVIF, HEIF, APNG, JXL), and ICO too? Should GIF leave GDI+, and WebP leave WIC
   and QPV's own compositing, for GIF_PLAYBACK and WEBP_PLAYBACK?
3. JXL, AVIF and HEIF frames: keep their own depth (flag 0; RGB16/RGBA16 reaches PNG, TIFF,
   JXL, JXR and JP2), or 8-bit RGBA as the viewer shows them (flag 2)?
4. Saved output formats: 4c8ec92's clamp keeps every stored value usable. Should the old
   positions also be converted once, or the extension stored instead?
5. «Color depth» on the FreeImage routes: apply it, or disable it where it does not apply?
6. Same-name source files in one batch: add the source extension to the frame names, use one
   subfolder per source, or leave it?

Fixed in 4c8ec92: findings 1 and 4, and the blank-extension half of 3. Suggested order for
the rest: 2 with 6 and 7, then the rest of 3, then 5, then 8 to 11.

**Marius's answers, 2026-11-03, implemented in `6065e4f`:**
- 1: by content, for every file the FreeImage route could take.
- 2: every multi-page format FreeImage reads, ICO included, except GIF, which stays on GDI+.
  WebP leaves WIC. The frames are read with the PLAYBACK flags.
- 3: settled by the PLAYBACK flags: 8 bits per channel.
- 5: the panel's depth is a fallback: a frame's own depth first, when the output format holds
  it, then the panel's, then the closest the format allows. For composed frames, «own» is the
  depth the file stores, when that loses nothing. GIF frames follow it too; PDF pages do not.
- Also decided: TIFF pages from FreeImage only, without WIC; 1-bit stays out of the depth
  tables; ICO pages in the extractor only, not in the join tool; the label reads «Fallback
  depth». Decisions 4 and 6 are still open.

## How this was checked

- Static reading of `development` at 622f848, of `QPV DLL source code/lib/wic-loader.h`, and
  of the FreeImage fork's JXL, HEIF and AVIF plugins (`~/repos/FreeImage-library`).
- Under Wine, with the AutoHotkey_H x64 interpreter from the repo's zip: finding 1's lines
  for r = −4 to 10, and finding 3's dropdown read-back (Choose9, 13, 14 and 15 on the
  13-item list).
- Under Wine, with the shipped FreeImage.dll (3.20.0, 9b41683): `FreeImage_GetFileType()`,
  then `FreeImage_OpenMultiBitmap()` with no flag, with `LoadFimFile()`'s flags and with the
  wrapper's PLAYBACK flags, then every page's size, depth and frame time. The 22 samples were
  the fork's TestAPI files (GIF, multi-page TIFF, ICO, MNG, JXL, AVIF, and HEIF collections,
  bursts and sequences), plus APNG, WebP and GIF files made with Pillow whose frames 2 to 4
  cover only a 55×25 rectangle.
- Updated after pulling 4c8ec92: its five changed lines were read, and every cited line
  number still holds. The «with `r=-2`» column of finding 1's Wine run is the line as it now
  reads. The same dropdown run shows that a clamped 13 reads back as XPM.
- Not run on Windows: what GDI+ and WIC do with each format. The −3/−4 outcomes in finding 2
  come from the code and from how those codecs are documented to behave. The test scripts
  were not kept.
- `6065e4f`, under Wine with AutoHotkey_H x64 and the shipped FreeImage.dll and qpvmain.dll:
  - Both interpreters (AutoHotkey_H and stock 1.1) load the script.
  - `coreExtractFramesFromImage()` was sliced with its call closure and run on 21 sources:
    Pillow-made APNG (RGBA, RGB, RGB with an ICC profile, palette, palette with transparency,
    grey), WebP (lossless RGBA, lossy RGB, still), GIF (transparent, opaque, one named .tif),
    a TIFF with 1-bit, grey, palette, RGB, RGBA and 16-bit grey pages, an ICO and a plain
    PNG, plus the fork's TestAPI multi-page TIFF, ICO, MNG, JXL, AVIF and HEIF files. Each ran
    into PNG, JPG, WebP, TIFF, BMP, GIF and JXL, and into JPG, GIF, WebP, BMP and PNG with
    «32 bits» and «8 bits».
  - Every frame was compared with the one FreeImage composes with the PLAYBACK flags. Every
    PNG, TIFF, BMP, lossless WebP and lossless JXL output matched. GIF output matched too,
    except for frames of more than 256 colours and frames with transparency: Wine's GDI+
    cannot palettize (`GdipBitmapConvertFormat` returns 6), so the Wu fallback runs and
    drops the transparency.
  - The depths are as listed in «What `6065e4f` changed on purpose». The sRGB profile
    survived the 32 → 24 reduction.
  - HEAD's code, run on the same sources, gave −3 or −4 for every APNG, JXL, AVIF, HEIF, MNG,
    ICO and WebP (Wine has no WebP codec). It wrote transparent GIF frames at 24 bits without
    their transparency, and frames 2 to 4 of the GIF named .tif undisposed (finding 7).
  - The 2026-11-02 converter suites (main, trans, extra, latent) were run on HEAD's and the
    new `coreConvertImgFormat()`. They differ only in the 20 conversions of 16-bit grey
    sources that used to fail (converter finding 5).
