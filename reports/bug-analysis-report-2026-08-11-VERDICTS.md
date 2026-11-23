# Verification of `bug-analysis-report.md`

Every one of the 21 claims was checked against the current working tree
(`quick-picto-viewer.ahk`, `QPV DLL source code/`). Verdicts below.

**Score: 4 confirmed, 1 confirmed-but-negligible, 3 partially true, 1 subjective, 12 false.**

A general warning about the source report: **every C++ line number in it is wrong**
(`qpv-main.cpp:9278` is brush blending, `qpv-main.cpp:6146` is WIC decoding, and
`dupesApplyFilter` is not in `qpv-main.cpp` at all — it lives in `dupes-search.h`).
The AHK line numbers are uniformly ~350 lines low. Several of the false findings are
the result of quoting a code excerpt and stopping before the part that handles the case.

---

## Confirmed — worth fixing

### #1 `navSelectedFilesPrev()` navigates forward — **TRUE**

`quick-picto-viewer.ahk:39606`

```autohotkey
navSelectedFilesNext() {
   navSelectedFiles(1)
}

navSelectedFilesPrev() {
   navSelectedFiles(1)     ; <-- should be -1
}
```

`navSelectedFiles()` branches on `direction=-1` for backward (`:39632`, `:39644`), and the
keyboard handler passes `-1` for `^Left` / `1` for `^Right` (`:2070`, `:2074`). So the
keyboard shortcuts are correct; only the two menu items that route through
`navSelectedFilesPrev` are broken — "Pr&evious selected" (`:66702`) and "&Previous"
(`:69903`), both labelled `Ctrl+Left`.

**Fix:** `navSelectedFiles(-1)`.

---

### #9 `modus="ouside"` typo — **TRUE**

`quick-picto-viewer.ahk:17526`, in `ApplyVPcolorAdjustSelectedArea()`

```autohotkey
If InStr(modus, "outside")
   modus := "outside"
...
If (throwErrorSelectionOutsideBounds(whichBitmap) || testEntireImgSelected() && modus="ouside")
   Return
```

`modus` is normalized to `"outside"` at `:17512`, so `modus="ouside"` is never true and the
whole second clause is dead (`&&` binds tighter than `||`).

Consequence is real but mild: with the entire image selected and "outside the selection"
chosen, `Gdip_SetClipPath(G2, pPath, 4)` (CombineModeExclude) yields an empty clip region,
so the clear+draw at `:17584-17585` do nothing. The unchanged clone is still pushed as an
undo level (`wrapRecordUndoLevelNow`) and `imgFxMode` is reset to 1 — the user's viewport
effects are silently discarded with no visible change. That is exactly what the guard was
meant to prevent.

---

### #10 Page Up / Page Down labels contradict the bindings — **TRUE (and worse than reported)**

Code (`:2145`, `:2164`): `PgDn` → `NextPicture()`, `PgUp` → `PreviousPicture()`.
In thumbnails mode (`:25711`, `:25715`): `PgUp` → back a page, `PgDn` → forward a page.

Menu labels claim the opposite at four sites: `:66665`, `:66666`, `:66676`, `:66677`
(plus `:66743`).

The report missed that **`resources/help-keyboard-shortcuts.txt` also contradicts the code**:

```
line 176: Page Up / Down|Next / Previous image|Image view|-
line 177: Page Up / Down|Jump forwards or backwards one page of images|Files list|-
```

So two documentation sources agree with each other and disagree with the implementation.
Whichever way you resolve it, three places need to change together. Note the labels for
`Page up`/`Page down` on *selection movement* (`:65470-65471`) **are** correct against
`:2154`/`:2173` — so this is not a blanket mixup.

Cosmetic only; nothing malfunctions.

---

### #13 PDF `MediaBox` is scaled by DPI instead of 72 pt/inch — **TRUE (numbers in the report are invented)**

`QPV DLL source code/Jpeg2PDF.cpp:24-25`

```cpp
pPDF->pageW = (UINT32)(pdfW * pdf_dpi);
pPDF->pageH = (UINT32)(pdfH * pdf_dpi);
```

`pageW`/`pageH` are written straight into `MediaBox[0 0 %d %d]` (`:84-85`). PDF user-space
units are 1/72 inch by default and there is no `/UserUnit` key in the output, so the page
box must be `inches * 72`. `Jpeg2PDF.h:53` even documents the input as
`/* pdfW, pdfH: Page Size in Inch */`. The upstream CodeProject library this is based on
multiplies by 72.

**But the report's arithmetic is fabricated.** QPV never offers 300 DPI:

```autohotkey
dpi := (combinePDFpageHighQuality=1) ? 192 : 96          ; :43861
```

So Letter (8.5 × 11 in) comes out as:
- high quality: `8.5*192 = 1632` units → 22.67 in wide → **2.67× oversized**
- normal: `8.5*96 = 816` units → 11.33 in wide → **1.33× oversized**

not 2550 units / 35.4 in / 4.16×. The image content is scaled to fill the page box
(`:91-92`), so proportions and layout are correct — what is wrong is the reported physical
page size in Document Properties and anything that prints at 100%.

**Fix:** `pPDF->pageW = (UINT32)(pdfW * 72);` (and drop or repurpose the `pdf_dpi` argument).

---

### #15 `if (pdfId < 0)` is not a null check — **TRUE, but practically unreachable**

`QPV DLL source code/qpv-main.cpp:7226-7228`

```cpp
pdfId = Jpeg2PDF_BeginDocument(pageW, pageH, dpi);
if (pdfId < 0)
   return -1;
```

`PJPEG2PDF` is `JPEG2PDF*`; pointers are never `< 0`, so a `malloc` failure sails through.
`Jpeg2PDF_AddJpeg` and `Jpeg2PDF_GetFinalDocumentAndCleanup` do guard with `if (pPDF)`, but
`Jpeg2PDF_EndDocument` dereferences **outside** its own guard:

```cpp
headerSize = (UINT32)strlen((char *)pPDF->pdfHeader);   // Jpeg2PDF.cpp:180, past the if(pPDF) block
```

so it would crash. The struct is ~441 KB (`MAX_PDF_TAILER` ≈ 226 KB + `MAX_PDF_XREF` ≈ 215 KB),
so the allocation realistically never fails. Cheap to fix: `if (pdfId == NULL) return -1;`

---

## Partially true

### #6 `nImgSelX1 := imgSelX1 := min(...)` before `max(...)` — **real defect, wrong repro**

The idiom the report flags is genuinely broken, at two sites — `:25172-25175`
(`CropImageInViewPortToSelection`) and `:75969-75972` (`calcRelativeSelCoords`):

```autohotkey
nImgSelX1 := imgSelX1 := min(imgSelX1, imgSelX2)   ; imgSelX1 is now the min
nimgSelX2 := max(imgSelX1, imgSelX2)               ; max(min, X2) can never recover the old X1
```

If `imgSelX1 > imgSelX2` the result is `X1 = X2 = imgSelX2` — zero width. The codebase uses
the *correct* form everywhere else (`:6446`, `:18429`, `:18442`, and inside
`calcImgSelection2bmp`), which is what makes these two look accidental rather than idiomatic.

**But the described repro does not happen.** Two reasons:

1. `:25172` is inside the `if (viewportQPVimage.imgHandle)` branch — the huge-image DLL path
   only. Ordinary crops never reach it.
2. Mouse drags maintain `X1 <= X2`. The drag loop swaps explicitly at `:10602-10622`
   ("`If (nImgSelX1>nImgSelX2 || nImgSelY1>nImgSelY2)` → assign crossed"), and
   `initFreeHandClickResponse` seeds `imgSelX2 := kX + 1` (`:10039`). Dragging right-to-left
   or bottom-to-top produces a normal, correctly-sized crop.

The realistic route to reversed coordinates is the typed-coordinates panel at `:54217-54218`,
which — unlike its percentage sibling at `:54229-54233` — does **not** min/max the input:

```autohotkey
imgSelX1 := Round(NewPosX1), imgSelY1 := Round(NewPosY1)
imgSelX2 := Round(NewPosX2), imgSelY2 := Round(NewPosY2)   ; X2 < X1 is accepted
```

Type `X1=800, X2=200`, then open a huge image, and `calcRelativeSelCoords` collapses the
selection.

**Fix:** compute both endpoints from untouched inputs (or normalize at `:54218`, matching the
percentage branch). Worth doing regardless of reachability — it costs one temp variable.

---

### #7 `currentFileIndex := maxFilesIndex - 1` can reach 0 — **real edge case, wrong arithmetic**

`maxFilesIndex` is a **count** (`maxFilesIndex := resultedFilesList.Count()`, `:56466`), so
`maxFilesIndex - 1` selects the *second-to-last* entry, and hits `0` on a one-item list.
Index 0 is fatal: `IDshowImage()` reads `resultedFilesList[0, 1]`, gets blank, logs
"Index entry error", beeps, and returns 0 → `informUserFileMissing(1)`.

The author is aware of this elsewhere — `:39259` writes
`clampInRange(maxFilesIndex - 1, 1, maxFilesIndex)`. The unguarded sites are `:25290`,
`:26932`, `:32086`, `:42068`, `:42076`, `:64440`, `:64687`.

**The report's reasoning is wrong** ("start with `maxFilesIndex = 1`, append 1 image,
`maxFilesIndex` becomes 1" — it becomes 2), and its repro is wrong: `folderTreeAppendFiles`
(`:32064`) and `omniBoxFolderImport` (`:26909`) both early-return when `maxFilesIndex < 1`,
so a successful append always leaves the index ≥ 1.

Actual triggers:
- **`:25290`** — paste a single file path into a *completely empty* workspace.
  `PasteHDropFiles` has no `maxFilesIndex` guard; `0 → 1` gives `currentFileIndex := 0`.
- **`:32086` / `:26932`** — append a folder that adds **nothing** (already indexed, cancelled)
  while exactly one file is loaded. Count stays 1 → index 0.
- **`:64440`** — after `remFilesFromList()` leaves one file (→ 0) or none (→ **-1**).

**Fix:** wrap all of them in `clampInRange(..., 1, maxFilesIndex)` like `:39259` already does.

---

### #21 `allowMSE` requires `n >= 2` — **true but deliberate**

`QPV DLL source code/dupes-search.h:897` (not `qpv-main.cpp:6146`)

```cpp
// testWasMSEdupes(): the MSD bounds only apply when the scan actually computed one.
// The first two pairs standing in for the whole list is what the AHK did.
const bool allowMSE = (n >= 2 && dupesPairsList[0].mse < QPV_MSD_NONE
                              && dupesPairsList[1].mse < QPV_MSD_NONE);
```

The observation is correct — with exactly one pair, the MSE bounds are skipped. But this is a
documented, intentional 1:1 port of the old AHK `testWasMSEdupes()` heuristic, kept for
behaviour parity during the DLL migration. The `n >= 2` sample is over-strict for a one-pair
list; sampling `pairs[0]` alone when `n == 1` would be a safe tightening if you want it.

---

## Subjective

### #11 Swipe direction — **not a bug**

`:5777-5780`: `dirX=1` (swipe right) → next, `dirX=-1` → previous.

This is a UI-convention preference, not a logic error, and it is **internally consistent**
with the app's own tap zones a few lines above: `|PicOnGUI3|` (right region) → `doNextSlide`,
`|PicOnGUI1|` (left region) → `doPrevSlide` (`:5751-5758`). Right means forward throughout.
The report is citing the iOS-carousel convention (drag content, not pages), which is a valid
alternative but not what this app implements anywhere.

---

## False

### #2 `VPchangeZoom` uses unrotated `ImgW` — **FALSE**

The premise is wrong: **viewport rotation is baked into the bitmap**, not applied as a draw
transform. `:75420` does `nBitmap := trGdip_RotateBitmapAtCenter(..., vpIMGrotation, ...)` on
load and replaces `rBitmap` with it. `mergeViewPortRotationImgEditing()` (`:77843`) confirms
the model — it "merges" rotation by cloning the already-rotated bitmap and resetting
`vpIMGrotation := 0`.

So `trGdip_GetImageDimensions(useGdiBitmap(), ImgW, ImgH)` at `:11859` already returns the
rotated width, and `ImgW * zoomLevel` matches `prevResizedVPimgW` exactly. There is nothing to
swap. Focal zoom on a rotated image is correct.

---

### #3 `!Final_x` jumps windows across monitors — **FALSE**

`:27902-27905`

```autohotkey
Final_x := Round(mCoordLeft + ResWidth/2 - msgWidth/2)
If (!Final_x) || (Final_x + 1<mCoordLeft)
   Final_x := mCoordLeft + 1
```

Treating `0` as falsy is a wart, but the described failure is arithmetically impossible.
`Final_x = 0` requires `mCoordLeft = (msgWidth - ResWidth)/2`, i.e. the monitor's horizontal
centre equals half the dialog width. On the report's own setup (secondary monitor at
`mCoordLeft = -1920`, `ResWidth = 1920`) that would need `msgWidth = -1920`. `Final_x` is
always negative there — `!Final_x` is false and the branch never fires.

Where it *can* fire, `mCoordLeft` is non-negative (the monitor's centre is at positive x), so
the window is nudged to `mCoordLeft + 1` **on the same monitor** — a ≤1 px shift, or in a
contrived arrangement a left-edge snap. No screen jump.

---

### #4 `clampInRange(..., 0, totalFramesIndex, 1)` overruns — **FALSE**

`totalFramesIndex` is **not** a frame count — it is the **last valid index**. `multiPageFileManaging`:

```autohotkey
tFrames := Gdip_GetBitmapFramesCount(oBitmap) - 1     ; :74632
...
Return tFrames                                        ; :74644 -> totalFramesIndex
```

and every other producer agrees: `:74941` `mainLoadedIMGdetails.Frames := Gdip_GetBitmapFramesCount(oBitmap) - 1`,
`:99918` `... - 1`, `:100826` `(pg>1) ? pg - 1 : 0`, `:101159` `NumGet(...) - 1`. Consumers
convert back with `+1` when they want a real count (`:84118`, `:99588`).

So for a 5-frame GIF `totalFramesIndex = 4`, and `clampInRange(desiredFrameIndex + dir, 0, 4, 1)`
is exactly right — index 4 is the last frame and stepping forward wraps to 0. Corroborated by
`:58670` (`usrJumpIndex - 1` clamped to `totalFramesIndex`) and `:79781`
(`desiredFrameIndex = totalFramesIndex` = fully-filled progress bullet).

*(Unrelated cosmetic nit found while checking: the dialog at `:58634` prints
`"Total frames / pages: " totalFramesIndex`, which shows 4 for a 5-page file.)*

---

### #5 Pure blue text becomes transparent — **FALSE**

`SetColorAlphaChannel` reads the red byte **on purpose**, because its input is a
white-on-black glyph mask, not coloured text. `:13299`:

```autohotkey
objBMPs := Gdi_DrawTextInBox(srr, thisHFont, "FFffFF", "000000", ...)
```

— white glyphs on a black field. Red therefore *is* the mask luminance. The user's colour
arrives via the `newColor` parameter and is written into the low 24 bits
(`newColor & 0x00ffffff`); the alpha comes from `min(maskLuma, newColorAlpha)`. The comment
immediately above the call spells this out (`:13350-13353`): *"the raw GDI text bitmaps are
entirely opaque; the call below turns the black area around the glyphs into transparent
pixels."*

All three call sites (`:13344`, `:13354`, `:13406`) feed masks from that same renderer. Pure
blue text renders fine.

---

### #8 `ThreG` vs `threG` case typo — **FALSE**

**AutoHotkey v1 variable names are case-insensitive.** `ThreG` and `threG` are the same
variable. `:17792-17794` works exactly as intended, as do the identical blocks at `:55861`,
`:56034`, `:90828`.

---

### #12 PDF export rejects a single image — **FALSE as described**

`If (z>1 && abandonAll!=1)` exists (`:44010`), but a single-image selection can never reach it.

`CombineImgsIntoPDF()` opens with `If (markedSelectFile>1)` (`:43831`), and more importantly
**QPV's selection model has no such thing as a one-file selection** — `getSelectedFiles(0, 1)`
deliberately clears it:

```autohotkey
If (markedSelectFile=1)                    ; :39463
{
   markedSelectFile := 0
   resultedFilesList[firstItem, 2] := 0
}
```

So with one image selected, `PanelCombineImagesMultipage()` shows *"WARNING: Insufficient
files selected to join"* and the panel never opens. The reported tooltip cannot appear.

The line is a genuine (narrow) defect only in one case: ≥2 images selected, all but one fail
to encode → `z = 1` → no PDF plus the misleading "No image was succesfully processed". `z>=1`
would be the correct bound.

---

### #14 EXIF/camera JPEGs fail to export — **FALSE**

`get_jpeg_size()` does require APP0/JFIF, but **it never sees a user's file**. The AHK side
re-renders every page onto a fresh GDI+ page bitmap and writes it out:

```autohotkey
f := Gdip_SaveBitmapToFile(newBitmap, tempusDir "\" fileIndex ".jpg", userJpegQuality)   ; :43981
```

and `CreatePDFfile` only ever opens `<n>.jpg` from that temp directory (`:7257-7264`). The
GDI+ JPEG encoder emits a JFIF APP0 segment, and `newBitmap` is freshly created so it carries
no EXIF property items. Camera photos, Photoshop output, HEIC-converted files — all are
normalized before they get anywhere near the parser.

The JFIF-only restriction is a latent limitation of the helper, not a reachable bug.

---

### #16 GDI+ stride padding skew — **FALSE**

The lock is always 32 bpp: `QPV_SetColorAlphaChannel` calls `trGdip_LockBits(...)` (`:14548`)
with the wrapper's default `PixelFormat := "0x26200A"` (32bppPARGB). For 32 bpp,
`stride = ceil(w*32/32)*4 = w*4` — GDI+'s 4-byte scanline alignment is already satisfied, so
padding is never inserted. The report's example (101 px wide → `101*4 = 404`, already
4-byte aligned) disproves itself. Callers also convert to `0xE200B` first (`:13340`, `:13402`).

---

### #17 Pixelate leaves the bottom edge unprocessed — **FALSE**

`PixelateBitmap` has **three** remainder blocks, not one. The report quoted through line ~3845
and stopped:

- `:3846-3880` — right edge (`w % Size`), inside the `y1` loop
- **`:3883-3918` — bottom edge (`h % Size`)** ← the block claimed to be missing
- `:3920-3952` — bottom-right corner (`w % Size` × `h % Size`)

---

### #18 Metadata lost on numerical queries — **FALSE**

`isStrFilter` is not "string filter mode", it is *"is there a filter string at all"*:

```autohotkey
isStrFilter := StrLen(filesFilter)>1 ? 1 : 0     ; :33635
```

and `mustDoQuery=1` is only ever set inside `If InStr(filesFilter, "QPV::query::")` (`:33529`).
A numerical QPV query **is** a long filter string (`QPV::query::imgwidth::100::500`), so
`isStrFilter = 1` and `newMappingList` is populated at `:33709`.

The guard is also correct by construction: the consumer at `:33715` tests
`If StrLen(filesFilter)>1` — the *same* condition. The two can't disagree.

---

### #19 `userFilterProperty := 19` is out of bounds — **FALSE**

`columnsList` does stop at 18 (`:33001`), so `columnsList[19]` is blank — but the resulting
string is **discarded**. `updateUIFiltersPanel` overrides it unconditionally afterwards:

```autohotkey
If (userFilterProperty=19)                                                       ; :33168
   newFilter := (SLDtypeLoaded=3) ? "SQL:query:||Prev-Files-Selection||" : "||Prev-Files-Selection||"
Else If (userFilterProperty=20)
   newFilter := "||Already-Seen-Images||"
```

19 is a legitimate entry in the dropdown ("Selected files", 19th of 20 items at `:32934`) and
is special-cased elsewhere too (`:33043`). `FilterFilesListuIndex` has a dedicated
`||Prev-Files-Selection||` branch (`:33611`). Ctrl+Tab works.

---

### #20 Random mode reverts to sequential after filter/sort — **FALSE**

`GenerateRandyList()` is an **invalidation**, not a (failed) build. The builder is a different
function, `coreGenerateRandomList()` (`:2754`), and `RandyIMGnow := -1` is the sentinel that
triggers a lazy rebuild. Every consumer honours it:

```autohotkey
If (RandyIMGnow=-1 || !RandyIMGids.Count())      ; :39409 RandomPicture()
   coreGenerateRandomList()                      ; :39422 PrevRandyPicture()
                                                 ; :11034 slideshow start
```

The slideshow advance goes through `GoNextSlide()` → `RandomPicture()` (`:11112`), and the
interface thread's `theSlideShowCore()` posts `RandomPicture` back to the main thread
(`lib/module-interface.ahk:1260`). `coreNextPrevImage` is never called with an empty
`RandyIMGids`, so the sequential fallback at `:12631` is not reached.
