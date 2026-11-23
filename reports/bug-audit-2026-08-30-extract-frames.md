# Bug audit — the frame/page extractors, 2026-08-30

Scope as asked: `coreExtractFramesFromImage()` (:62054), `coreExtractFramesFromWEBP()`
(:61889) and `coreExtractFramesFromTiff()` (:61773), plus the two callers that consume
their return value and their two `ByRef` counters —
`BTNperformExtractFrames()` (:44311) and `batchExtractFramesFromImages()` (:61667).

Nine defects, all long-standing (blame: 2023-09 / 2025-01 / 2025-02 / v6.1.60), **none of
them a regression from a recent commit**. Ranked by user impact.

---

## 1. Aborting a batch extraction does not stop it — it silently keeps writing files

`batchExtractFramesFromImages()` :61727

```ahk
If (r=-5 && pdfTextMode=1)
{
   abandonAll := 1
   Break
}
```

`-5` is "the user abandoned" in **all four** extractors, but the outer loop only honours it
in PDF-text mode. In frame mode the `-5` falls through to the `Else` at :61748 and is
counted as `failedFiles++`, and the loop moves on to the next selected file.

The outer loop does re-check `determineTerminateOperation()` at :61688 — but that function
is throttled by a **shared static** (:35473):

```ahk
Static lastInvoked := 1
If (A_TickCount - lastInvoked < 200)
   Return 0
```

The inner extractor's aborting call set `lastInvoked` microseconds earlier, so the outer
re-check returns 0, and so does the *next* file's first in-loop check. That file therefore
extracts one or two frames to disk before its own abort trips ~200 ms later, returns `-5`,
and the cycle repeats — for every remaining selected file.

`mustAbandonCurrentOperations` is sticky (set only by `askAboutStoppingOperations()`
answering *yes*, `module-interface.ahk:1043`; cleared only by `initAppBusyMode()` :291 and
the `"normal-extra"` cursor :1373, neither of which fires mid-batch — `changeMcursor()`
posts `"busy"`), so this is not a lost-flag problem. It is purely the missing `Break`
compounded by the throttle.

**Repro:** select 3+ animated GIFs → Extract frames → abort and confirm during the first
file. Observed: the operation runs to the end of the selection, leaves 1–2 stray frame
files per remaining file in the destination folder, and the final message reads
*"N out of M selected files were processed / For K files, the operations failed"* —
never *"Operation aborted"*.

**Fix:** drop `&& pdfTextMode=1` at :61727. (The throttle then no longer matters, because
the loop breaks on the return value rather than on a second poll.)

---

## 2. A single-page PDF is reported as a total failure, although the page is written

`coreExtractFramesFromImage()` :62160 returns `clampInRange(tFrames, 0, 9892899)`, i.e.
`1` for a one-page PDF — and the page *is* rendered and saved correctly by the loop above.

Both callers treat only `r>1` as success:

* `BTNperformExtractFrames()` :44355–44358 → `r=1` falls into
  *"ERROR: An undefined error has occured.`nNo frames or pages were extracted."*
* `batchExtractFramesFromImages()` :61745–61748 → `r=1` falls into `failedFiles++`, and
  :61733 also skips the frame counters, so the page is missing from the totals too.

The GIF / TIFF / WEBP paths can never return `1` (they return `-2` when `tFrames<2`), so
only the PDF paths hit this. `coreExtractBatchModeTextsFromGivenPDF()` :62051 has the same
return contract and the same bug in text-extraction mode.

**Repro:** extract pages from any 1-page PDF. The .png/.hdp lands in the destination
folder; the app says it failed.

**Fix:** make the success predicate `r>=1` at :44355, :61733 and :61745.

---

## 3. `coreExtractFramesFromTiff()` leaks the source page whenever it rescales

:61856–61873

```ahk
If isImgSizeTooLarge(imgW, imgH, saveImgFormatsList[userExtractFramesFmt])
{
   capIMGdimensionsFormatlimits(saveImgFormatsList[userExtractFramesFmt], 1, imgW, imgH)
   hFIFimgB := trFreeImage_Rescale(hFIFimgA, imgW, imgH)
   If hFIFimgB
   {
      FimBuffer := DestroyMemoryBuffer(FimBuffer)
      rz := coreConvertImgFormat(imgPath, file2save, hFIFimgB)   ; <-- hFIFimgA never unloaded
   } Else
   {
      rz := "err"
      FreeImage_UnLoad(hFIFimgA)                                  ; <-- correct here
   }
} Else rz := coreConvertImgFormat(imgPath, file2save, hFIFimgA)   ; <-- consumed here
```

`coreConvertImgFormat()` discards only the bitmap it is handed (`FreeImage_UnLoad(hFIFimgA)`
on both of its return paths, :61400 and :61551) — the comment at :61871 says as much.
`trFreeImage_Rescale()` produces a *new* object and leaves its source intact
(`OpenCV_FimResizeBitmap` / `FreeImage_Rescale`, :15223). So the rescale-succeeded branch
is the one path out of three that drops `hFIFimgA` on the floor; :61873 then blanks the
variable, so the handle is unrecoverable.

Severity splits by which loader produced the page:

* **From `FreeImage_LockPage` + `FreeImage_Clone` (:61834)** — a deep copy that owns its
  pixels. The full page leaks, once per page.
* **From `loadWICasFreeImage()` (:61824)** — the bitmap only *wraps* `FimBuffer`
  (`FreeImage_ConvertFromRawBitsEx(0, buffer, …)`, :101495, `copySource=0`), and :61862
  frees that buffer, so only the FIBITMAP header leaks.

The Clone path is the common one for TIFFs WIC declines (CMYK, float, HDR — the DLL
explicitly bounces HDR TIFFs to FreeImage at qpv-main.cpp:7311) and for anyone running
with `allowWICloader=0` or `alwaysOpenWithFIM=1`.

**Repro (worst case):** extract frames from a many-page TIFF with **`.ico` as the output
format**. `getIMGformatLimits()` gives ico a 256 px cap, so *every* page over 256 px takes
the rescale branch and leaks its full clone. A 100-page 4000×3000 TIFF leaks ~4.5 GB.
`.webp` (16350 px / 267.2 Mpx), `.jp2`/`.j2k` (32760 / 1073 Mpx) and `.jpg`/`.gif`/`.tga`
(65530 / 4294 Mpx) trigger it at their own thresholds.

**Fix:** `FreeImage_UnLoad(hFIFimgA)` inside the `If hFIFimgB` branch. Safe and already
house style — :61849–61851 does exactly this unload/destroy pair on a possibly
WIC-derived bitmap, and unloading a `copySource=0` wrapper does not touch the external
buffer.

---

## 4. The progress tooltip is mis-throttled in all three loops, and absent entirely for a single file

:61806 (TIFF), :61922 (WEBP), :62194 (GIF/TIFF via GDI+):

```ahk
If ((A_TickCount - prevMSGdisplay>3000) && inLoop=1 && yay=1)
   showTOOLtip(...)
yay := !yay
```

Two separate problems:

* **`prevMSGdisplay` is a by-value parameter and is never refreshed inside these loops.**
  Once 3 s have elapsed, the condition is true forever, so `showTOOLtip()` fires on *every
  other frame* for the rest of the file — the `yay` toggle is a 50 % damper, not a throttle.
  On a 500-frame GIF that is 250 tooltip repaints. The PDF branch of the very same
  function does it correctly (:62109–62114: shows, then `prevMSGdisplay := A_TickCount`).
* **`&& inLoop=1` means single-file extraction shows no progress at all.** Extracting from
  the panel's active-file button leaves the initial *"Extracting N frames from: …"*
  tooltip frozen on screen for the whole operation — no counter, no ETA, no progress-bar
  fraction, and no reminder that it can be aborted. The PDF branch shows progress in both
  modes.

**Fix:** add `prevMSGdisplay := A_TickCount` inside the `If`, and drop `&& inLoop=1` and
the `yay` toggle, matching :62109–62114.

---

## 5. Batch frame counters are wrong whenever any frame fails

`batchExtractFramesFromImages()` :61735

```ahk
tFrames += totalz          ; totalz is the ByRef *extractedFrames*, not the total
tFramFailed += failedFrames
```

`totalz` is bound to the 6th parameter, `ByRef extractedFrames` — successes only. The
display at :61703 and :61754 then computes

```ahk
percF := Round((1 - tFramFailed / tFrames) * 100, 1)
"…s extracted: " groupDigits(tFrames - tFramFailed) " / " groupDigits(tFrames) " ( " percF "% )"
```

i.e. *"(extracted − failed) / extracted"*. A 10-frame GIF with 3 failures reports
**"frames extracted: 4 / 7 ( 57.1% )"** instead of 7 / 10 (70 %). It only looks right when
nothing fails, which is why it has survived.

`coreExtractBatchModeTextsFromGivenPDF()` feeds the same counters, so PDF text mode is
affected identically.

**Fix:** `tFrames += totalz + failedFrames` at :61735 (this excludes frames the user chose
to skip in the collision dialog, which is what the "extracted" label means).

Cosmetic corollary: both divisions are unguarded, so when no file yields `r>1` the summary
prints *"frames extracted: 0 / 0 ( 100% )"* — AHK's divide-by-zero is blank, and `1 - ""`
coerces to 1. Wrong-looking, not a crash.

---

## 6. `coreExtractFramesFromWEBP()` overwrites the global `mainLoadedIMGdetails`

:61897 and :61937 both call `LoadWICimage(imgPath, 0, …)` with `noBPPconv=0`, and
`LoadWICimage()` :101593 ends with `mainLoadedIMGdetails := obj.Clone()`.
`mainLoadedIMGdetails` is a super-global (:150) that describes the image **currently loaded
in the viewport**. After any WEBP extraction it describes the last extracted WEBP frame
instead.

Readers that can then see stale data:

* `GetCachableImgFileDetails()` :84392–84404 — when it is handed an already-valid
  `thumbBMP` it skips the load entirely (`r := 1`) and reads width/height/frames/dpi
  straight out of the global, then `UpdateFilesListImgIDinfos()` :84417 writes them into
  the files list via `recordFilesListImgProps()`, and :99787–99793 into the DB columns
  13/14/15/17/22.
* `totalFlames := mainLoadedIMGdetails.Frames + 1` at :44167 and :62393 (the joiner's
  "join contained frames" count), and `.HasAlpha` at :44205 / :44545.

This is made worse by §7: the value left behind is the last *sub-frame's* size, which for
an animated WEBP is often a small changed-region rectangle rather than the canvas.

`LoadWICimage()` already has the escape hatch for a details-only read — `noBPPconv=2`
returns the object without touching the global (:101588–101591) — but it also suppresses
the bitmap for anything over 536 Mpx, so the straightforward fix here is to snapshot the
global before :61897 and restore it on **every** exit, including the early `-4` (:61900)
and `-2` (:61904) returns.

---

## 7. Extracted WEBP frames are raw stored sub-frames, not composed animation frames

`coreExtractFramesFromWEBP()` gets each frame from `LoadWICimage(imgPath, 0, A_Index-1, …)`
→ `WICguardedOpenFrame()` (qpv-main.cpp:5880), which is a plain
`IWICBitmapDecoder::GetFrame(n)` followed by `GetFrame->GetSize()`. There is **no
compositing anywhere in qpvmain.dll** — I grepped for dispose/blend/ANMF/imgdesc/grctlext
and the only "blend" hits are the image-editing blend-mode LUTs.

An animated WEBP's ANMF chunks normally carry a partial frame plus an (x,y) offset and a
blend/dispose method. Without compositing, frames 2..N come out as the changed rectangle
only, at their stored size — so the extracted files can legitimately have *different
dimensions from each other*, and show fragments on a transparent ground.

Framing matters here: QPV's viewer animates WEBPs through the same raw
`LoadWICimage(frameu)` call, so the extractor faithfully reproduces what the viewer shows —
this is an app-wide gap rather than something `coreExtractFramesFromWEBP()` does wrong on
its own. Worth knowing before anyone treats the extractor's output as a bug report about
the extractor. Note the contrast: **GIFs are composited correctly** by both of their paths
— FreeImage gets the `GIF_PLAYBACK` flag (`multiFlags := (GFT=25) ? 2 : 0`, :100007 /
:62899) and GDI+ `Gdip_BitmapSelectActiveFrame()` composites internally.

One assumption left open, because it cannot be settled from the source: that the
Windows WEBP WIC codec hands back raw ANMF sub-frames, the way the WIC GIF codec
famously does, rather than compositing internally. The code-level half is verified —
plain `GetFrame(n)`, no compositing in the DLL, dimensions taken from the frame itself.
Confirm with one animated WEBP: if frames 2..N come out canvas-sized and complete, the
codec composites and this whole section is moot.

---

## Minor / footnotes

**8. `isImgSizeTooLarge()` and `capIMGdimensionsFormatlimits()` disagree about the extra
715.3 Mpx limit.** `isImgSizeTooLarge()` :12203 applies `mpx>715.3` by default
(`extraLimit:=1`), but `capIMGdimensionsFormatlimits()` only consults
`getIMGformatLimits()`, which has **no entry** for png / tif / bmp / hdp / wdp / jxr / ppm /
xpm and so returns unchanged dimensions. Extracting a >715 Mpx TIFF page to any of those
therefore enters the rescale branch, rescales to the *identical* size — a pointless
multi-GB duplicate — and then leaks the original per §3. Only reachable on the FreeImage
TIFF path; a live GDI+ bitmap cannot exceed ~715 Mpx, so :61945 and :62228 are safe.
Passing `extraLimit=0` at :61856 would be the targeted fix, since that path saves through
FreeImage and is not bound by the GDI+ ceiling.

**9. "Action on file name collisions" is not persisted.** `OnExtractConflictOverwrite`
(:211, default 4 = *Ask user*) is read from the GUI at :44316 and :56890 but has no
`RegAction`/`INIaction` anywhere — unlike its panel neighbours `ResizeDestFolder`,
`userJpegQuality`, `userPDFdpi`, `userExtractFramesFmt`. The choice survives the session
(super-global) and is lost on restart. Same class as the unpersisted GIF panel settings
from the join-images audit earlier today. `userSaveBitsDepth` *is* persisted, at :48356.

**10. Overwriting a read-only destination fails in three of the four paths.** The TIFF path
goes through `coreConvertImgFormat()`, which does `FileSetAttrib, -R` (:61445). The WEBP,
PDF and GDI+ paths save through `QPV_SaveImageFile()` → `Gdip_SaveBitmapToFile()`, which
never clears the attribute; the `SaveFIMfile()` fallback does not either. Choosing
*Overwrite* on a read-only existing frame file therefore silently counts as a failed frame.

**11. `coreExtractFramesFromTiff()` opens the multi-bitmap with `flags=0`** (:61776) while
both sibling call sites use `multiFlags := (GFT=25) ? 2 : 0` (:62899, :100007). `GFT` comes
from content sniffing (`FreeImage_GetFileType`), not the extension, so a GIF-content file
named `.tif` would be opened without `GIF_PLAYBACK` and yield uncomposited frames. Narrow,
but the two-line fix matches the rest of the codebase.

**12. Helper-side, adjacent:** `teleportWICtoFIM()` :101503–101525 leaks `buffer` when
`FreeImage_ConvertFromRawBitsEx` fails but `WICgetBufferImage` succeeded — the
`If (hFIFimgA && buffer)` gate falls through to `Return 0` (:101525) without a `GlobalFree`. Reached
from `loadWICasFreeImage()`, so the TIFF extractor is one of its callers.

**13. `coreExtractFramesFromImage()` :62056** resolves `resultedFilesList[indexu, 1]`
without stripping the `||` marker. The batch loop filters those out at :61696;
`BTNperformExtractFrames()` does not, so extracting from a marked current file fails with
"Failed to load the image" rather than being skipped.

---

## Checked and found correct (so they are not re-reported later)

* `trGdip_DrawImage(Gu, oBitmap)` at :62225 is pixel-exact — the all-defaults path fills
  `sx/sy/sw/sh = dx/dy/dw/dh` from the bitmap and calls `GdipDrawImageRectRect` with
  `Unit=2` (UnitPixel). No DPI scaling trap.
* `Gdip_GetBitmapFramesCount()` returns a **count**, and :62170 uses it as one — correct;
  the other three call sites subtract 1 because they want a last index.
* `mainLoadedIMGdetails.Frames` is a last index (`resultsArray[2] = facts.frames`, minus 1
  in AHK), so `tFrames := … + 1` at :61898 is right.
* `abandonAll` is a per-function local everywhere — not a super-global — so nothing leaks
  between calls even though `coreExtractFramesFromImage()` is the only one of the four that
  does not zero it at entry.
* The `hFIFimgA := ""` reset at :61873 and the guard at :61850 close every other exit from
  the TIFF loop; `FimBuffer` cannot be non-blank while `hFIFimgA` is blank, because
  `teleportWICtoFIM()` only returns the pair when both are set.
* `askAboutFileCollision()`'s force mapping is correct: the dropdown is
  `Skip files|Auto-rename|Overwrite|Ask user` with AltSubmit, and 1/2/3 map to
  skip/auto-rename/overwrite while 4 falls through `!isInRange(forceOption, 1, 3)` to the
  dialog. The "apply to all" memory is a `Static` and both callers reset it up front with
  `askAboutFileCollision(0, 0, 1, 3, 0, nullvar)`.
* `sizesDesired[1] := [32750, 32750, 1, 0, …]` at :61893 is inert but harmless — the DLL
  hardcodes `adaptImageGivenSize(2, …)` (qpv-main.cpp:7350), so `mustResize` is always 0
  and givenW/givenH are ignored. Even if honoured, `ScaleAnySize=0` prevents upscaling.
* `coreConvertImgFormat()` unloads the bitmap it is passed on **both** return paths, and
  returns `0` on success / truthy on failure — so `If rz failedFrames++` at :61874 is right.
* The whole operation runs `Critical` (via `BtnCloseWindow()` / `getSelectedFiles()`), so
  `determineTerminateOperation()`'s cross-thread poll is the only abort channel — which is
  what it uses. No re-entrancy risk in these loops.
