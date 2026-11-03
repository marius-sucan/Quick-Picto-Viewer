# Format converter audit: `batchConvert2format()` and `coreConvertImgFormat()`

Snapshot of 2026-11-02, branch `development` at `f38849e`.

Scope: `batchConvert2format()` (`quick-picto-viewer.ahk:60925-61138`) and `coreConvertImgFormat()`
(`quick-picto-viewer.ahk:61334-61554`), every helper they call, the multi-threaded worker
`multiCoreThreadFormatConvert()` (`:38288`), and how both handle JPEG XL, APNG, MNG, HEIC/HEIF, AVIF
and multi-page files.

Method:
- Both functions, their helpers and the FreeImage fork's plugins (`~/repos/FreeImage-library`, branch `qpv`)
  were read in full.
- `coreConvertImgFormat()` was then run under Wine against the repo's own `FreeImage.dll` (committed 2026-10-27,
  reports 3.20.0, exports `FreeImage_MustTonemap`, `FreeImage_ConvertToLinear` and
  `FreeImage_ApplyDisplayICCProfile`) and `qpvmain.dll` (for WIC). That was 143 conversions, plus one that hit an
  access violation, run on AutoHotkey_H 1.1.33.10 x64 (the runtime QPV ships with) and, for finding 3, on stock
  AutoHotkey 1.1.37.02.
- The test copy is the working-tree function plus the 22 functions it calls and QPV's Global block, with
  logging probes added that change nothing. How to re-run it is at the end.
- Each finding says how it was checked: **Wine** (run and observed), **reading** (code only), or both.

## Terms used

- **WIC loader**: Windows Imaging Component, used through `loadWICasFreeImage()` (`:62939`). It decodes the file
  in `qpvmain.dll`, converts it to sRGB, and wraps the pixel buffer in a FreeImage bitmap without copying it.
  `coreConvertImgFormat()` uses it first for `.png .jpg .jpeg .jpe .tif .tiff` when colour management is on,
  which is the default (`:61361`). It also uses it as a fallback when FreeImage fails (`:61376`).
- **FreeImage loader**: `FreeImage_Load()` (`:61371`), used for every other format, and for those six
  extensions when colour management is off.
- **Worker**: one of the extra QPV processes that «Use multiple threads» starts.
- **In-place conversion**: the destination path is the source path. This happens when «Auto-skip format» is
  unticked, no destination folder is used, and the file already has the target extension.
- **FIF**: FreeImage's format number; for example APNG is 39 and JXL is 40.
- **PQ**: the HDR transfer curve (SMPTE ST 2084) used by HDR AVIF, HEIC and JXL files.
- **CICP**: the four code numbers that describe primaries and transfer curve in AVIF/HEIF (`nclx`), PNG (`cICP`)
  and JXL. In FreeImage they live in a metadata tag.
- **Palette transparency**: the transparent entry of a 1/4/8-bit palette image (GIF, PNG-8). It is stored next to
  the palette, not as an alpha channel.
- **The tables**: the static `gifOPT`, `pngOPT`, `tiffOPT`, … strings at `:61335-61347`. They list the depths
  (`-s24-`) and FreeImage pixel types (`-f9-` = RGB16, `-f11-` = RGBF, …) that each destination format accepts.

## Summary

| # | Severity | What the user gets | Checked |
|---|---|---|---|
| 1 | High | Multi-page and animated files keep only their first page; then the original is recycled | Wine + reading |
| 2 | High | In-place conversion deletes the original outright, even with «Keep original files» on; an explicit «Skip file» answer is overridden | Wine + reading; **fixed with originals kept, `26dd9d7`** |
| 3 | High | After a failed save of a PNG/JPG/TIFF the fallback reads freed memory: on AutoHotkey_H the run stopped responding, stock AutoHotkey reports a failure; Windows outcome unverified | Wine; **fixed, `e040c32`** |
| 4 | Medium | Float HDR images (EXR, HDR, PFM, float JXL/TIFF/JXR) cannot be converted to PNG, JPEG 2000 or PPM | Wine |
| 5 | Medium | 16-bit greyscale images cannot be converted to JPG, BMP, WebP, GIF, TGA, PPM, JNG or XPM | Wine; **fixed, `6065e4f`** |
| 6 | Medium | Transparency is lost: palette images to WebP/JP2/JXR/TGA/JXL/TIFF/GIF, anything to GIF, HDR with alpha | Wine; **fixed, `db6ce3e`** |
| 7 | Medium | Photos come out rotated twice (FreeImage path: Exif kept after rotating), or with all metadata dropped and unrotated (WIC path) | Wine + reading |
| 8 | Medium | PQ HDR AVIF/HEIC become flat, washed-out 16-bit PNG/TIFF/JPEG 2000 files | Wine |
| 9 | Medium | Multi-threaded runs load files differently from single-threaded runs, and can switch mid-batch | reading (+ Wine for the two loaders' outputs) |
| 10 | Medium | Multi-threaded runs race on shared destination names; the conflict option is bypassed | reading |
| 11 | Low | The destination format is read from an existing file's content, not from its extension | Wine |
| 12 | Low | «Auto-skip format» compares extension text: `.jpeg`, `.jpe`, `.jfif`, `.tiff` are re-encoded | reading |
| 13 | Low | PDF and SVG files always fail, although the panel shows PDF and SVG sliders | Wine |
| 14 | Low | The colour depth is not kept as the help promises: 1-bit becomes 24-bit; WIC turns 16-bit into 8-bit | Wine + reading |
| 15 | Low | Smaller issues: 1×1 images rejected, progress below 100 %, 8-bit images to HDR/EXR/PFM fail | Wine + reading |

Findings 1 and 2 can lose files; finding 3 could stop QPV. Findings 4–8 decide whether JXL, HEIC and AVIF convert
correctly.

---

## 1. Multi-page and animated files keep only their first page, then the original is recycled

**What happens.** Every source is loaded as one image: WIC frame 0 (`:61364`, `:61378`) or `FreeImage_Load()`,
which asks for page −1, that is page 0 (`:61371`). Neither function looks at the page count anywhere. After a
successful conversion with «Keep original files» off, the batch recycles the original (`:61095-61101`), so the
other pages and frames remain only in the Recycle Bin. The same happens with a destination format that can hold
pages or frames (TIFF, GIF, WebP, JXL): the output still has one page.

**Evidence (Wine).** Source page count, then output page count:

| Source | Pages/frames | Loader | Output |
|---|---|---|---|
| 3-page TIFF, 16-page TIFF (`mpages.tif`) | 3, 16 | WIC | 1-page PNG |
| animated GIF (2 files) | 3 | FreeImage | 1-page PNG, also 1-page TIFF and WebP |
| APNG named `.png` | 3 | WIC (default image) | 1-page PNG |
| APNG named `.apng` | 3 | FreeImage (frame 1) | 1-page PNG |
| animated JXL | 5 | FreeImage | 1-page PNG |
| AVIF sequence | 5 | FreeImage | 1-page PNG |
| HEIC sequence `seq-with-still.heic`, HEIC collection `example.heic` | 4, 2 | FreeImage (primary image) | 1-page PNG / JPG |
| MNG animation | 4 | FreeImage (frame 1, not composited) | 1-page PNG |
| ICO with 3 sizes | 3 | FreeImage (first icon) | 1-page PNG |

QPV already knows which formats can be multi-page: `multiPageAllTypesRegEx` (`:120`), and
`FreeImage_OpenMultiBitmap()` + `FreeImage_GetPageCount()` worked for every format above.

**Fix options.**
- (a) Detect multi-page sources, then skip them, warn about them, or never recycle their originals.
- (b) Convert all pages when the destination can hold them (TIFF, GIF, WebP, JXL; the fork also writes APNG and
  MNG), reusing the join machinery.
- (c) For single-page destinations, write one file per page, as «Extract frames/pages» does.

## 2. In-place conversion deletes the original, ignores «Keep original files» and overrides an explicit «Skip file»

**Fixed in `26dd9d7` with «Keep original files» on.** The batch asks once before it starts, and the single-file
convert asks too, whenever files would be converted onto themselves:
- **Auto-rename:** the converted file is saved as `name [N].ext` and the original stays untouched.
- **Continue:** the file is converted in place and its original goes to the Recycle Bin under its own name
  (`recycleReplacedOriginal()`).
- **Cancel:** nothing is converted.

The answer replaces the conflict option for those files, so «Skip file» is no longer overridden there.
Multi-threaded runs pass the answer to their workers. «Auto-rename» as the conflict option, and «Skip files»
with a destination folder, already keep the originals, so they get no question.

Wine checks:
- 14 batch and single-file scenarios, two worker-loop runs and one fallback of the swap: each original lands in
  the trash byte-identical and under its own name, including a 3-page TIFF.
- Cancel changes nothing, and no `-tmp`/`-new` file is left anywhere.

With «Keep original files» off the behaviour is unchanged by choice: the original is still deleted, not recycled,
and the «Skip file» override remains there.

**What happens.** With «Auto-skip format» unticked and no destination folder, a file that already has the target
extension is re-encoded onto itself:
- `coreConvertImgFormat()` renames the existing destination, which here is the source, to `name.ext-tmp`
  (`:61431-61440`). It saves the new file, then **deletes** `-tmp` with `FileDelete` (`:61543`). The original is
  gone for good, not recycled.
- «Keep original files» is never consulted on this path. The batch tests it only before recycling (`:61095`).
- With a multi-page source this is finding 1 without even the Recycle Bin copy. Wine: a 3-page TIFF re-encoded
  in place is left with 1 page, and so is a 3-frame GIF; no `-tmp` remains.
- A JPEG re-encoded in place loses quality each time. On the FreeImage path it also ends up rotated twice
  (finding 7).

**The self-collision is handled inconsistently** (`:61069-61087`). Source and destination are the same file, so
`FileExist(file2save)` is true and the conflict option is applied to the file itself:
- Line `:61079` turns a blank answer back into `file2save := of`. That line is what makes in-place conversion
  happen at all under the default «Skip files» option, so that part is the mechanism, not the bug. The bug is that
  the same line also discards an explicit «Skip file» click in «Ask user» mode: the file is re-encoded anyway.
- «Auto-rename» writes `name [1].ext` and then recycles the original (if originals are not kept), which is not an
  in-place conversion either.
- The «Ask user» dialog shows the same file as both «SOURCE FILE» and «DESTINATION FILE».

**The same-file test is a string comparison.** `imgPath!=file2save` (`:61095`) is a plain case-insensitive string
test, and `ResizeDestFolder` is used as stored. A drive root from the folder picker (`D:\`), or a typed
trailing backslash, gives `D:\\photo.jpg` for `D:\photo.jpg`. Windows opens both as the same file, but the strings
differ.

The overwrite does not survive the doubled backslash, though:
- `FileRexists()` reads the attributes through a `\\?\` path (`PathToExtendedPath()`), which Windows does not
  normalize, so `D:\\photo.jpg` finds nothing.
- `coreConvertImgFormat()` takes the save for a failure, puts the original back and returns 1.
- The batch reports «Failed to convert» and recycles nothing.

Wine: in that set-up both in-place files failed and stayed intact. A new file written into the same folder
(`c.png` → `c.jpg`) converted, because there was no existing file to check. Since `26dd9d7`, with originals kept,
such files are found by full path and written under the source's spelling, so they convert. With originals not
kept they still fail this way, without loss.

**Fix options.**
- Refuse in-place conversion while «Keep original files» is on, or turn it into an «Auto-rename».
- Recycle the `-tmp` copy instead of deleting it.
- Treat a destination equal to the source as «convert in place» explicitly, without the collision dialog.
- Compare full normalized paths (`GetFullPathName`, then case-insensitive) rather than strings.

## 3. A failed save of a WIC-loaded image makes the fallback read freed memory

**Fixed in `e040c32`.** The buffer is now freed at the end of the function. After the ICO canvas it is freed only
when the canvas replaced the bitmap. Wine: the two rows below now reach the fallback with the buffer alive, with no
access violation and «Failed to convert» reported; the other 127 conversion rows give identical results.

**What happens.** The WIC loader's FreeImage bitmap does not own its pixels. `teleportWICtoFIM()` wraps the DLL's
buffer with `FreeImage_ConvertFromRawBitsEx(0, buffer, …)` (`:101057`); the 0 means "do not copy". In the first
save branch, the buffer is freed straight after `FreeImage_Save()`, whatever the result (`:61493-61494`).

When that save fails, the fallback branch converts the same bitmap again (`:61505`, `:61514`, `:61523`). For a
24-bit image, `FreeImage_ConvertTo(…, "24Bits")` clones it, which reads the freed buffer.

**Evidence (Wine).**
- 80×40 JPEG: the probe shows the fallback running on an image whose pixel pointer equals the buffer just freed.
  No exception; a small freed block stays mapped.
- 2400×1600 JPEG (11.5 MB of pixels): `EXCEPTION_ACCESS_VIOLATION` inside FreeImage.dll, a read of the first byte
  of the freed WIC buffer (`0x4820040`; `0x4950040` in the second run).

What happens next depends on the AutoHotkey build:
- **AutoHotkey_H 1.1.33.10 (the runtime QPV ships with):** a vectored exception handler inside `AutoHotkey.exe`
  receives the exception, and the process stops responding.
- **Stock AutoHotkey 1.1.37.02:** `DllCall`'s own guard catches it: a `__try/__except` around the call
  (`script2.cpp:12896-12903` of the AutoHotkey v1.1 source). Wine's trace shows the unwind landing in
  `AutoHotkeyU64.exe`. `FreeImage_ConvertTo()` returns blank, the fallback save is skipped, and the file is reported as
  «Failed to convert»; the run goes on.

So the outcome ranges from «reported as a failure» to «QPV stops responding». Which one Windows gives with
AutoHotkey_H was not verified.

**When it happens.** All of these hold:
- The file is a PNG/JPG/TIFF with colour management on (the default), or any file FreeImage could not open and
  WIC did.
- The table accepts the bitmap's depth, so the first save is tried.
- That save fails. In the batch the destination folder is created when missing (`:60942`), so the realistic causes
  are: converting next to files on read-only media or a read-only share, a protected folder, a full disk, a
  destination held open by another program, or a folder with the destination's name.

If the process does not recover, as in the AutoHotkey_H run, a destination that existed has already been renamed to
`name.ext-tmp` and stays that way. For an in-place conversion that is the source file itself. When `DllCall` catches
the exception instead, the restore step runs and nothing is left behind.

A second path frees the same buffer while the bitmap still uses it: `.ico` destinations when
`FIMrescaleICOmode()` fails (`:61457-61461`). The batch never targets ICO; Save As does. Checked by reading only.

**Fix options.**
- Free the WIC buffer only after the last use of `hFIFimgA` (the end of the function already does that at `:61535`).
- Or clone the bitmap before the first save.

## 4. Float HDR images cannot be converted to PNG, JPEG 2000 or PPM

**What happens.**
1. For an RGBF or RGBAF source, the PNG, JP2 and PPM tables list `-f9-`/`-f10-` (RGB16, RGBA16). So
   `noDepthConvert := 1`, with `hdrMode := "RGB16"` or `"RGBA16"` (`:61414-61425`).
2. `noDepthConvert` also tells `FIMapplyToneMapper()` not to tone map (`:61427`).
3. The fork's `FreeImage_ConvertToRGB16/RGBA16` refuse float images (`ConversionRGB16.cpp:39-64`,
   `ConversionRGBA16.cpp:39-64`).
4. The fallback's `ConvertTo24Bits/32Bits` refuse them too: they accept only standard, RGB16 and RGBA16
   bitmaps (`Conversion24.cpp:129`, `Conversion32.cpp:194`).
5. Nothing is written, and the file counts as failed.

**Evidence (Wine).** `fi_exr_float.exr` (RGBF), `rgbf_lossy.jxl` (RGBF) and `rgbaf_lossless.jxl` (RGBAF):
- **PNG, JP2, PPM: return 1, no file**, for all three sources.
- BMP, JPG, WebP, TGA, GIF: tone mapped, saved.
- TIFF, JXL, JXR: saved as float.

So the same EXR converts to BMP but not to PNG.

**Fix options.**
- For float sources, tone map whenever the destination has no float type, as the BMP/JPG path already does,
  and keep `hdrMode` only for RGB16 → float.
- Or convert float to RGB16 with an explicit curve and clamp.

## 5. 16-bit greyscale images cannot be converted to 8-bit formats

**Fixed in `6065e4f`** (with the frame extractor's depth rule) by the first fix option below.
`coreConvertImgFormat()` converts UINT16 to 8-bit grey by its high bytes, as the viewer shows
it, whenever the destination has no 16-bit grey type. Wine run: the 20 conversions of
`grey16_lossless.jxl`, `L_12__128x128.heif` and `grey16.png` that failed now write 8-bit grey
JPG, BMP, GIF and TGA files, 24-bit WebP, PPM and JNG files, and XPM files that read back as
palette images. PNG, TIFF, JXL and JP2 still keep 16 bits.

**What happens.** A FIT_UINT16 image (16-bit grey) has no route to 8 bits:
- `FIMapplyToneMapper()` converts only pixel types 3–8 to a standard bitmap (`:61293`); UINT16 is type 2.
- The fallback then calls `ConvertTo24Bits`, which refuses UINT16 (`Conversion24.cpp:129`). For GIF,
  `FIMquantizeImage()` does the same first (`:99346`).
- BMP's table lists `-s16-`, meant for RGB555/565. `FreeImage_GetBPP()` also reports 16 for grey UINT16, so the
  first save is tried and the BMP writer refuses it.

**Evidence (Wine).** `grey16_lossless.jxl` and `L_12__128x128.heif` (12-bit monochrome HEIF):
- **JPG, BMP, WebP, GIF, TGA, PPM, JNG, XPM: return 1, no file.**
- PNG, TIFF, JXL, JP2: saved as 16-bit grey.

**Who hits it.** Every 16-bit grey source on the FreeImage loader:
- JXL, HEIF/AVIF monochrome, JPEG 2000, PGM, PSD, always.
- PNG/TIFF when colour management is off, when «always open with FreeImage» is on, and in workers.

Under Wine, WIC could not decode the 16-bit PNG, so those rows also fell back to FreeImage. On Windows, WIC
decodes it to 24-bit and the conversion works, at 8 bits (finding 14).

**Fix options.**
- Convert UINT16 to 8-bit grey before the fallback: `FreeImage_ConvertTo8Bits` accepts UINT16
  (`Conversion8.cpp:200`), or extend the standard-type step to type 2.

## 6. Transparency is dropped

**Fixed in `db6ce3e`.**
- **Palette images with a transparency table** are converted to 32 bits for WebP, JPEG 2000, JPEG XR, TGA, JPEG
  XL and JNG.
- **TIFF:** 1/4-bit transparent images are widened to 8 bits with their transparency table. For 1-bit images,
  the table is remapped, since the second colour moves to index 255.
- **GIF:** 1/4-bit images are saved as they are. Every other image gets its 256 colours the way Save As makes
  them: GDI+, with «Dithering» and «Keep transparency». The converter's «Format options» now shows both for GIF,
  sharing the Save panel's settings. FreeImage's quantizer stays as the fallback.
- **HDR with alpha:** tone mapping still returns 24 bits, but the RGBA16/RGBAF alpha is scaled to 8 bits and put
  back when the destination stores alpha.

Wine checks:
- A 4-bit and a 1-bit transparent GIF keep their transparency in every format that can store it; GIF stays at
  1/4 bits.
- The float JXL's alpha comes back identical at the sampled pixels.
- Of the 127 earlier conversion rows, only the 10 intended ones changed.
- In the real app, the converter panel shows the two checkboxes for GIF only and saves them. The Save panel
  behaves as before.

Wine's GDI+ cannot reduce to 256 colours (`GdipBitmapConvertFormat` is not implemented there), so the GDI+ step
itself was not seen working. There, the fallback ran, with the orientation kept.

**What happens.**
1. **Palette images.** The fallback chooses 24 bits whenever the colour type lacks "rgba" (`:61511`). A palette
   image with a transparent entry reports PALETTIZED, so its transparency is discarded whenever the destination's
   table has no entry for its depth.
2. **Anything to GIF.** `FIMquantizeImage()` converts to 24 bits before quantizing (`:99346-99347`), so a GIF output
   is always opaque. This includes re-encoding a transparent GIF. The «Keep transparency» and «Dithering»
   options from the Save panel are not used here. Yet the converter's help says the format options «apply to
   every image file QPV saves».
3. **HDR with alpha.** Every tone-mapping operator returns 24 bits, so an RGBAF/RGBA16 source sent to WebP or TGA
   loses its alpha.

**Evidence (Wine).**
- `trans.gif` (palette with a transparent background):
  - **WebP, JPEG 2000, JPEG XR, TGA, JXL: saved opaque, 24-bit.** All five can store alpha.
  - TIFF keeps 4 bits but drops the transparency.
  - GIF in place: opaque.
  - PNG: kept.
- `rgba.png` to GIF: opaque.
- `rgbaf_lossless.jxl` to WebP/TGA: 24-bit.

PNG-8 files should not be affected on the default path, because WIC hands over palette-with-transparency as 32 bits
(DLL fix `06a00c9`). This was checked by reading, not run.

**Fix options.**
- In the fallback, choose 32 bits when `FreeImage_IsTransparent()` is true and the format takes alpha
  (`saveAlphaTypesRegEX`, `:123`, already lists them).
- For GIF, reuse `SaveFIMfile()`'s palettizer and its two options.

## 7. Photo orientation and metadata

**What happens.** The two loaders handle camera metadata in opposite ways.

**FreeImage loader: rotated twice** (workers, colour management off, `.jfif` and other non-WIC extensions). This is
the clear defect:
- JPEGs load with `JPEG_EXIFROTATE` (`:61226`). The fork's `RotateExif()` turns the pixels but leaves the
  Orientation tag (`Source/Metadata/Exif.cpp:1065-1112`).
- The WebP, JXL and JPEG writers copy the raw Exif block unchanged (`PluginWebP.cpp:1051`, `PluginJXL.cpp:1967`,
  `PluginJPEG.cpp:953`).
- So the output is upright and still says «rotate 90°»: viewers that honour the tag turn it again.
- The TIFF writer forces Orientation 1 (`PluginTIFF.cpp:3079`), so TIFF output is right.

**WIC loader: sideways, metadata gone** (single-threaded default for JPG/PNG/TIFF). The image is wrapped without any
metadata, and its colours are converted to sRGB (`wic-loader.h:291-293`). The output has no Exif, XMP or ICC
profile: camera, date taken and GPS are gone. A phone photo stored sideways with Orientation 6 is written sideways
with no tag.

QPV's own viewer also shows such a JPEG unrotated on its default path. The comment at `:43855` says «of the loaders,
only FreeImage turns JPEGs by their EXIF orientation». So this output matches what QPV displays. It differs from
Windows Photos, browsers and phones, which honour the tag and showed the original upright. The loss of the
metadata itself holds either way.

**HEIC and AVIF.** The same mechanism applies. The plugins apply `irot`/`imir`
(`PluginHEIF.cpp:353-354`, `PluginAVIF.cpp:369-410`), then attach the file's Exif block as it is
(`PluginHEIF.cpp:593-622`, `PluginAVIF.cpp:268-287`). An iPhone HEIC whose Exif says Orientation 6 would come out
upright and tagged 6: rotated twice in a JPG.

**Evidence (Wine + Pillow).** `exif6.jpg`, stored 80×40 with Orientation 6:

| Loader | Output | Size, orientation |
|---|---|---|
| WIC | WebP, JXL, PNG, JXR | 80×40, no Exif (sideways) |
| WIC | TIFF | 80×40, Orientation 1 (sideways) |
| FreeImage | WebP, JXL | **40×80 with Orientation 6** (Pillow reads 6 from the WebP): rotated twice |
| FreeImage | JPEG, re-encoded in place | **40×80 with Orientation 6** |
| FreeImage | PNG, TIFF, JXR | 40×80, upright |

`exif.jpg` to WebP:
- WIC: no Exif, no ICC.
- FreeImage: Exif and the 3144-byte ICC profile kept.

The HEIC/AVIF Exif pass-through is confirmed (`hevc32-mini-exif.heif` and `paris_icc_exif_xmp.avif` keep their Exif
in the JPG). No test HEIC has an Orientation other than 1, so the double rotation itself is confirmed by reading only.

**Fix options.**
- After a rotating load, set Orientation to 1, both in the parsed Exif and in the raw block, or drop the raw block.
- On the WIC path, read the orientation and turn the image, and/or copy the metadata from a header-only
  FreeImage load (`FIF_LOAD_NOPIXELS`).

## 8. PQ HDR AVIF/HEIC/JXL become washed-out 16-bit PNG, TIFF and JPEG 2000 files

**What happens.** A 10/12-bit PQ image loads as RGB16 with its curve described only by the CICP tag. PNG, TIFF and
JP2 accept RGB16 (`-f9-`), so `noDepthConvert` skips tone mapping (`:61410-61413`, comment «prevent tone-mapping
HDR formats when destination can handle it»).

But none of those three writers stores CICP: the PNG writer has no `cICP` chunk, only the reader does. The file
holds raw PQ code values that every viewer reads as sRGB. JXL is the exception: its writer turns CICP into a PQ
colour encoding (`PluginJXL.cpp:2075`).

**Evidence (Wine).** `seine_hdr_rec2020.avif` (PQ, `FreeImage_MustTonemap` = 3):
- **PNG:** chunks are `IHDR pHYs tIME iTXt IEND`, with no `cICP`, `iCCP`, `gAMA` or `sRGB`. Reloaded, it reports
  «no tone mapping needed» (0). Its contrast is half that of the tone-mapped JPG: per-channel standard deviation
  31–35 against 60–75.
- **TIFF, JP2:** the same, no colour description.
- **JXL:** reloads as PQ (`MustTonemap` = 3), correct.
- **JPG, WebP:** tone mapped, correct.

A PQ JXL that carries an ICC profile keeps it in the PNG, so the problem is CICP-only files, the usual case for
AVIF and HEIC. HLG files get verdict 0 on purpose and are written as they are.

**Fix options.**
- When `FreeImage_MustTonemap()` gives 3, tone map unless the destination is JXL.
- Or teach the fork's PNG writer `cICP`; TIFF and JP2 would still need tone mapping.

## 9. Multi-threaded runs load files differently from single-threaded runs

**What happens.** A worker starts in `initExternalCoreMode()` (`:100106`), which never calls `initQPVmainDLL()`.
So `WICmoduleHasInit` keeps its global default of 0, and `RegExWICfmtPtrn` still holds its placeholder.

In a worker, every file goes through FreeImage, and the WIC fallback is off. Against a single-threaded run of
the same selection:
- JPEG orientation and metadata differ (finding 7).
- 16-bit PNG/TIFF keep 16 bits, and 16-bit grey then fails for 8-bit formats (finding 5).
- Files only WIC can read fail: for example a HEIC that the Windows HEIF extension opens but FreeImage does not.

**The loader can switch mid-batch.** `OpenCV_FimResizeBitmap()` (`:15292`) and `OpenCV_FimToneMapping()` (`:15356`)
call `initQPVmainDLL()`, which initialises WIC (`:2368`). So the first file of a worker that needs a size cap
(WebP above 16350 px) or OpenCV tone mapping switches the rest of that worker's files to the WIC path. Outputs of
one batch then differ by the order of files, and that order is shuffled (`:37613`).

**Evidence.** Reading. The Wine rows marked «FreeImage loader only» reproduce a worker's loader and show the
differences listed above.

**Fix options.**
- Initialise `qpvmain.dll`/WIC in `initExternalCoreMode()`.
- Or choose one loader for both modes.

## 10. Multi-threaded runs race on shared destination names

**What happens.** `getSelectedFilesListString()` shuffles the selection (`:37613`) and splits it into one chunk per
worker. Each worker checks `FileExist(file2save)` on its own (`:38365`).

Two sources that map to the same output can therefore be converted at the same moment by two workers:
- `a.png` and `a.bmp` going to `a.jpg`;
- two `IMG_0001.png` from different folders going to one destination folder.

Both see no destination, and both write it. The conflict option («Skip», «Auto-rename») never applies. With
originals not kept, both originals are recycled while one output survives. In single-threaded mode the second
file meets the conflict option.

**Evidence.** Reading.

**Fix options.**
- Reserve the destination atomically (create it with `CREATE_NEW` before converting).
- Or put files with the same destination name in the same chunk.

## 11. The destination format is read from an existing file's content

**What happens.** `typu := FreeImage_GetFileType(file2save, 1)` (`:61403`) reads the signature of an existing
destination. It falls back to the extension only when the file does not exist. The save itself goes by extension
(`FreeImage_Save()` → `GetFIFFromFilenameU`), so the depth table and the size cap can belong to another format:
- An existing APNG named `.png` gives `typu = APNG` (the fork names animated PNGs FIF 39, `GetType.cpp:56-59`).
  There is no `apngOPT` table, so nothing is saved and the conversion fails. Overwriting such a file, or
  re-encoding it in place, never works.
- An existing JPEG named `.png` gives `typu = JPEG`, so an RGBA source is written to the `.png` as 24-bit, without
  alpha.
- The size cap follows the old file's format, for example WebP's 16350 px for a `.png`.

**Evidence (Wine).**
- Existing APNG destination: return 1, and the old APNG is restored intact.
- Existing JPEG wearing `.png`: the PNG output is 24-bit, alpha gone.
- PNG wearing `.bmp`: typed as PNG, the save fails, and the old file is restored at its original size.

The restore-on-failure path works as intended.

The same line appears in `saveHugeVPimageFile()` (`:58889`), `coreFreeImageSimpleFileProcessing()` (`:98281`) and
at `:99291`.

**Fix options.** Use `FreeImage_GetFIFFromFilename(file2save)` with the readable name.

## 12. «Auto-skip format» compares extension text

**What happens.** `isSameFormat` is `RegExMatch(imgPath, "i)(.\.(" rDesireWriteFMT "))$")` (`:61018`, and
`:38321` in the worker).

With JPG as the target, `.jpeg`, `.jpe` and `.jfif` files are not skipped. They are re-encoded (generation loss),
and their originals are recycled. With TIF as the target, `.tiff` files are re-encoded, so multi-page `.tiff` files
lose their pages (finding 1).

The panel ticks «Auto-skip format» every time it opens (`:90940`), so this is the default behaviour.

**Evidence.** Reading.

**Fix options.**
- Compare format identities: map `jpeg|jpe|jfif` to `jpg` and `tiff` to `tif`.
- Or compare `FreeImage_GetFileType(imgPath)` with the destination's format number.

## 13. PDF and SVG files always fail, despite the panel's sliders

**What happens.** The converter panel shows «Render PDF pages: DPI» and «SVG rendered resolution»
(`:90947-90950`). No converter path reads them:
- FreeImage cannot open either format.
- The WIC fallback matches them, because `RegExWICfmtPtrn` lists `svg|pdf` (`:118`). But `WICpreLoadImage()`
  has no PDF or SVG decoder.
- Only `LoadWICimage()` routes them to `RenderPDFpage()`/`RenderSVGfile()` (`:101098-101101`), and the converter
  does not use it.

**Evidence (Wine).** `test.pdf` and `test.svg` both return −1, «Failed to load file with FreeImage».

**Fix options.**
- Render them through `RenderPDFpage()`/`RenderSVGfile()` + `ConvertPBITMAPtoFIM()` (one file per PDF page, see
  finding 1).
- Or hide the two sliders and skip these files.

## 14. The colour depth is not kept as the help promises

The help says «QPV will attempt to preserve the color depth of the images» (`:90998`).

- **No 1-bit entry.** No table has `-s1-` (`:61335-61347`), although PNG, TIFF, BMP and the JXL writer accept
  1-bit. Wine: a 622-byte 1-bit TIFF became 24-bit in PNG, TIFF, BMP (12 KB) and JXL. JXL's table also lacks `-s4-`.
- **WIC lowers depth.** It hands over 48/64-bit images as 24/32-bit (`:62946-62949`), and grey, 1-bit and palette
  images as 24-bit RGB (the 2026-10-06 DLL audit, #6). So with colour management on (the default), 16-bit PNG/TIFF
  become 8-bit, and grey JPG/PNG/TIFF become RGB.

Wine's WIC could not decode 16-bit grey or 48-bit PNGs (FreeImage took over), so the WIC half is checked by reading.

**Fix options.**
- Add `-s1-` (and `-s4-` for JXL) where the writer accepts it.
- Use WIC only when the file has a profile to apply, or apply the profile in FreeImage
  (`FreeImage_ConvertToICCProfile()`), which keeps the depth.

## 15. Smaller issues

- **1×1 images are rejected.** A 1×1 image is treated as a load failure (`oImgH=1 && oImgW=1`, `:61385`). Reading.
- **Progress stays below 100 %.** Skipped list entries (`||`) are not counted in `countTFilez`, while the
  progress bar divides by `filesElected` (`:60990`, `:60998`, `:61008-61014`). Reading.
- **8-bit images cannot go to HDR, EXR or PFM.** The `hdrOPT`, `exrOPT` and `pfmOPT` tables have no route for a
  standard bitmap, so a JPG fails in all three (Wine: return 1). The batch never targets them; Save As does, through
  `:59124`.
- **APNG and MNG are not offered as targets, though the fork writes them.** The converter offers 13 formats
  (`:130-131`), JXL included. AVIF and HEIF cannot be offered: the fork reads them but has no writer (`save_proc`
  is NULL in both plugins).

---

## Format support: JXL, APNG, MNG, HEIC/HEIF, AVIF

| Format | As a source | As a destination | Problems found |
|---|---|---|---|
| **JPEG XL** | FreeImage. Stills; animations give frame 1. 8/16-bit, grey, PQ, float; CMYK read as RGB; codestream orientation applied. | Offered. Quality, effort and «Lossless» work; float, 16-bit and PQ are written correctly. | 1 (animation), 4 (float to PNG/JP2/PPM fails), 5 (16-bit grey to 8-bit formats fails), 7 (JPEG Exif kept after rotating), 14 (no 1/4-bit entry) |
| **APNG** | Detected as FIF 39 even when named `.png`. A `.png` goes through WIC (default image), an `.apng` through FreeImage (frame 1). | Not offered (the fork writes it). | 1, 11 (an existing APNG at the destination makes the conversion fail) |
| **MNG** | FreeImage, frame 1 as stored, not composited on the canvas (no `MNG_PLAYBACK`). | Not offered (the fork writes it). | 1 |
| **HEIC / HEIF** | FreeImage (libheif): primary image first; `clap`/`irot`/`imir` applied; 10/12-bit as RGB16 or 16-bit grey; collections and sequences have pages. Not in the WIC-first list; WIC only as a fallback. | Not possible (the fork has no writer). | 1, 5 (12-bit monochrome), 7 (Exif kept after `irot`), 8 (PQ washed out in PNG/TIFF/JP2) |
| **AVIF** | FreeImage (libavif): sequences give frame 1; `irot`/`imir` applied; 10/12-bit as RGB16/RGBA16. | Not possible (read-only plugin). | 1, 7, 8; RGBA16 sources lose alpha in JPG, as expected |

## Multi-page files

Pages beyond the first are never converted, whatever the format: finding 1, and finding 2 when in place. With
«Keep original files» off they leave the folder with the original. The formats measured were TIFF, GIF, APNG, JXL,
AVIF, HEIC (sequence and collection), MNG and ICO; animated WebP takes the same path. PDF does not convert at all
(finding 13).

## Related, outside the two functions

- **`convert2format()`** (`:61597`), the «Active file only» button, calls `coreConvertImgFormat()` too. It shares
  findings 1, 3–8, 11, 13 and 14, and recycles the original the same way (`:61652-61657`).
- **Other callers.** There are 9 live call sites in 7 functions (plus one commented out in `setImageWallpaper()`):
  - `multiCoreThreadFormatConvert` `:38384`
  - `saveHugeVPimageFile` `:58911`, `:58944`
  - `SaveClipboardImage` `:59124`
  - `batchConvert2format` `:61089`
  - `convert2format` `:61640`
  - `coreExtractFramesFromTiff` `:61872`, `:61878`
  - `coreFreeImageSimpleFileProcessing` `:98324`

  Those that pass a file path inherit findings 3–8 and 11. Those that pass their own bitmap skip the loaders, but
  still go through the same tables and fallbacks (4–6, 11).
- **Pages mode is not blocked.** In the mode that lists every page as an entry (`QPV:PAGES:`), Resize, Auto-crop,
  Copy/Move, Rename and Delete refuse to run (`warnFramesActionPrevented()`, `:40244`). The converter's three menu
  entries (`:66795`, `:66824`, `:68397`) and Ctrl+K (`:1840`) are not blocked:
  - «Convert» on the entry of page 5 converts page 1.
  - It then recycles the multi-page original when originals are not kept.
  - The page entries are copies of the file's entry, selection flag included. If that file was selected before
    entering the mode, the batch converts the same file once per page.

  Checked by reading.

## Not verified here

- **Windows WIC decoding of 16-bit grey and 48-bit PNGs** (findings 5 and 14): Wine's WIC could not convert them,
  so FreeImage took over in those rows.
- **A HEIC with Exif Orientation other than 1** (finding 7): no sample exists. The pass-through and `irot`
  application are confirmed separately.
- **Worker processes as a real multi-threaded run starts them** (findings 9 and 10): read, not run. The worker loop
  itself was run for the `26dd9d7` checks.
- **The «Ask user» dialog for a self-collision with originals not kept** (finding 2): read, not run.

## Re-running the checks

The kit is in `.claude/scratch/convert-audit-2026-11-02/`, which git ignores:
- `mksamples.py` builds the inputs, copying some from the fork's `TestAPI`.
- `gen.py` slices `coreConvertImgFormat()` with its callees, QPV's Global block and `lib/shell-stuff.ahk`'s
  `GetFileAttributesEx()`. AutoHotkey_H binds a missing `GetFileAttributesEx` to the Win32 API and hangs, so the
  slice must include it.
- `run.sh main|extra|latent|uafsmall|uaf` runs a group of rows under the fork's private Wine with AutoHotkey_H;
  `run-stock.sh` runs the same with stock AutoHotkey 1.1.37.02. `out-<mode>.txt` holds the results; the `*-seh.sh`
  variants add Wine's exception trace.
- `gen2.py` + `driver2.tpl` + `run2.sh` check the `26dd9d7` prompt. They run `batchConvert2format()`,
  `convert2format()` and the worker loop on real files, with the dialogs answered by a stub. Wine's Recycle Bin is
  redirected to `xdg/`.
- `post2.py` then tells which files hold an original's exact bytes, and what reached the trash, from where.
