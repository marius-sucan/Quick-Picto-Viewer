# Frame and page extractor audit, 2026-11-03

Scope: `batchExtractFramesFromImages()` (:61948) and `coreExtractFramesFromImage()` (:62534),
with the routines they hand files to: `coreExtractFramesFromTiff()` (:62052),
`coreExtractFramesFromWEBP()` (:62286) and `coreExtractBatchModeTextsFromGivenPDF()` (:62450),
plus `PanelExtractFrames()` (:43541) and `BTNperformExtractFrames()` (:44103), which drive them.
Line numbers are `quick-picto-viewer.ahk` on `development` at 622f848.

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

- **One regression** from the 08-30 fixes: the batch summary counts almost every successful
  file as skipped (finding 1). It is one missing character.
- **None of JXL, APNG, MNG, AVIF or HEIC/HEIF is handled.** The panel advertises JXL, MNG
  and APNG, and the batch filter admits all five. The extractor sends them to GDI+, which
  cannot decode them or reads only one image. The viewer and the join-images tool read
  their frames through FreeImage, and the shipped FreeImage.dll reports every frame (finding 2).
- **Multi-page files**: GIF, TIFF and PDF are extracted, and WebP where Windows has a WebP
  codec. HEIF collections, bursts and sequences, AVIF sequences, multi-size ICO files and
  APNG are not.
- Two medium defects: saved output formats point at other formats since 0a5b8e1 (finding 3),
  and PDF text mode writes a file named `abort` when the user cancels (finding 4). One
  medium-low: TIFF pages ignore «Color depth» (finding 5). Six low or latent items follow.

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

**Fix:** `Else If (r=-3 || r=-2)`.

---

## 2. JXL, APNG, MNG, AVIF and HEIC/HEIF frames are never extracted

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
- `LoadFimFile()`'s flag table is not a model: it passes 0 to MNG (see «Seen in passing»).
- `coreExtractFramesFromTiff()` decodes each page with WIC first (:62103-62109). If that
  routine becomes the general one, the WIC step must stay TIFF-only: WIC hands over GIF
  frames undisposed (finding 7).

---

## 3. Saved output formats point at other formats since 0a5b8e1; two of them write nothing

0a5b8e1 (2026-10-13) shortened the «File format on save» list from 15 entries to 13
(`saveimgformatslist` :131, `userPossibleWriteFMTs` :130). `userExtractFramesFmt` is stored as
a position in that list, nothing converts the stored value, and
`RegAction(0, "userExtractFramesFmt",, 2, 1, 15)` (:43550) still accepts up to 15:

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
| 14 | WEBP | nothing |
| 15 | XPM | nothing |

For 14 and 15, the dropdown opens with nothing selected and `GuiControlGet` reads it back
blank (Wine run). The frame names then end in a bare dot (`name_1.`), no writer matches the
extension, and every frame fails. The single-file message reads «Succesfully extracted 0
frames out of N». For 3 to 13, the panel shows the remapped format, so a user who looks sees
it; one who doesn't gets PPM frames where they had chosen PNG.

The format converter's `userDesireWriteFMT` (`RegAction(…, 2, 1, 16)`) has the same remap. It
is not analysed here.

**Fix:** map the old positions once, or store the extension instead of the position
(decision 4).

---

## 4. PDF text mode: «Cancel» at a name collision writes a file named `abort` and carries on

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

**Fix:** `Return -5` where the function now sets `abandonAll := 1`.

---

## 5. TIFF pages ignore «Color depth»

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

`coreExtractFramesFromTiff()` opens a file whose content is a GIF with GIF_PLAYBACK (:62055,
the 08-30 fix), then decodes every page with WIC first (:62103-62109). WIC hands over GIF
frames as stored, so the composed FreeImage page is used only when WIC fails. This is narrow:
it needs a GIF renamed to `.tif`.

**Fix:** take the WIC step only when `GFT=18`.

---

## 8. When FreeImage cannot open a .tif, nothing else is tried and the message says «undefined error»

`coreExtractFramesFromTiff()` returns −1 when `FreeImage_OpenMultiBitmap()` fails (:62169).
`coreExtractFramesFromImage()` returns that straight away; it never falls through to the GDI+
branch, which reads multi-page TIFFs too. `BTNperformExtractFrames()` has no message for −1,
so it shows «ERROR: An undefined error has occurred.» (:44145). A batch counts it as skipped
(finding 1) instead of failed.

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
  copy, before it is saved.
- «Action on file name collisions» (`OnExtractConflictOverwrite`) has no `RegAction`, so it
  goes back to «Ask user» on every start.

## Status of the 2026-08-30 findings

| 08-30 # | Item | Now |
|---|---|---|
| 1 | Aborting a batch did not stop it | fixed (:62007) |
| 2 | A single-page PDF was reported as a failure | fixed in single-file mode; a batch counts it as skipped (finding 1) |
| 3 | The TIFF route leaked the page it rescaled from | fixed (:62144) |
| 4 | Progress tooltip throttle, none in single-file mode | fixed |
| 5 | Batch frame totals | fixed |
| 6 | The WebP route overwrote `mainLoadedIMGdetails` | fixed; the PDF route does the same, latent (finding 11) |
| 7 | WebP frames were written as raw sub-frames | fixed by composing them; depends on WIC (finding 6) |
| 8 | 715 MPx extra limit | open |
| 9 | Collision choice not saved | open |
| 10 | Read-only destination files | fixed |
| 11 | GIF_PLAYBACK in the TIFF route | fixed for the FreeImage step; WIC runs first (finding 7) |
| 12 | `teleportWICtoFIM()` buffer leak | fixed |
| 13 | `\|\|` marker in single-file mode | fixed (:62536) |

## Seen in passing

- The viewer opens MNG without the PLAYBACK flag (`LoadFimFile()` :99784), so it shows the
  stored sub-images. mng_anim.mng plays as 16×16 pieces of a 64×48 canvas (Wine run).
  `combineFimOpenPages()` passes 2 and gets the canvas.
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
4. Saved output formats: convert the old positions once, or store the extension?
5. «Color depth» on the FreeImage routes: apply it, or disable it where it does not apply?
6. Same-name source files in one batch: add the source extension to the frame names, use one
   subfolder per source, or leave it?

Suggested order: finding 1 (one character), 4, 3, then 2 with 6 and 7, then 5, then 8 to 11.

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
- Not run on Windows: what GDI+ and WIC do with each format. The −3/−4 outcomes in finding 2
  come from the code and from how those codecs are documented to behave. The test scripts
  were not kept.
