# Quick Picto Viewer (QPV) - Reproducible Bugs Analysis Report

This report provides a detailed breakdown of 21 reproducible functional bugs, logic errors, and broken options identified in the Quick Picto Viewer codebase (`quick-picto-viewer.ahk` and `QPV DLL source code/`).

---

### 1. `navSelectedFilesPrev()` Navigates Forward Instead of Backward

- **Locations**: `quick-picto-viewer.ahk` (Lines 39254–39256).
- **Code Snippet**:
  ```autohotkey
  navSelectedFilesPrev() {
     navSelectedFiles(1)
  }
  ```
- **Root Cause Analysis**:
  `navSelectedFilesPrev()` is intended to navigate to the previous selected image in the file list. However, line 39255 passes `1` (forward) instead of `-1` (backward) to `navSelectedFiles()`. As a result, both "Previous selected" and "Next selected" commands move forward in the selection list.
- **Steps to Reproduce**:
  1. Load a folder of images and select multiple non-adjacent files (e.g. items #2, #5, #8).
  2. Open item #5.
  3. Click **Menu -> Navigation -> Previous selected** (or trigger `navSelectedFilesPrev`).
  4. **Result:** The viewer advances forward to item #8 instead of going back to item #2.

---

### 2. Viewport Rotation Math Error in Focal Mouse-Wheel Zoom (`VPchangeZoom`)

- **Locations**: `quick-picto-viewer.ahk` (Lines 11782–11794).
- **Code Snippet**:
  ```autohotkey
  gmX := (FlipImgH=1) ? GuiW - mX : mX
  prcW := (gmX - prevDestPosX)/prevResizedVPimgW
  IMGdecalageX := Round(gmX - prcW * ImgW * zoomLevel)
  ```
- **Root Cause Analysis**:
  When zooming with the mouse wheel toward the mouse cursor, `VPchangeZoom()` calculates image offset shifts `IMGdecalageX` and `IMGdecalageY`. `prcW` is calculated relative to `prevResizedVPimgW`.
  When an image is rotated 90° or 270° (`vpIMGrotation`), `prevResizedVPimgW` represents `ImgH * oldZoomLevel` (the rotated width). However, line 11792 calculates `IMGdecalageX` using unrotated `ImgW` instead of `ImgH`. This causes the point under the cursor to jump and drift away when zooming in or out on rotated images.
- **Steps to Reproduce**:
  1. Open a non-square image (e.g., 1920x1080).
  2. Rotate the image by 90 degrees (press `0`).
  3. Hover the mouse cursor over a specific detail in the image and scroll the mouse wheel to zoom in.
  4. **Result:** The image jumps and drifts away from the cursor focal point because `ImgW` was used instead of `ImgH`.

---

### 3. Multi-Monitor Window Positioning Logic Bug (`If (!Final_x)` Evaluates `0` as False)

- **Locations**: `quick-picto-viewer.ahk` (Lines 27808–27826).
- **Code Snippet**:
  ```autohotkey
  Final_x := Round(mCoordLeft + ResWidth/2 - msgWidth/2)
  If (!Final_x) || (Final_x + 1<mCoordLeft)
     Final_x := mCoordLeft + 1
  ```
- **Root Cause Analysis**:
  In AutoHotkey v1, numeric `0` evaluates to boolean `false`. When `repositionWindowCenter()` calculates window coordinates for multi-monitor setups, if the target centered coordinate `Final_x` equals `0` (standard for primary monitor left alignment), `!Final_x` evaluates to `true`.
  This triggers line 27824 (`Final_x := mCoordLeft + 1`). On multi-monitor systems where `mCoordLeft` is negative (e.g. secondary monitor to the left at `X = -1920`), a window centered at `X = 0` gets forcibly repositioned to `X = -1919`, jumping screens unexpectedly.
- **Steps to Reproduce**:
  1. Set up a multi-monitor environment with a secondary monitor to the left of the primary monitor (`mCoordLeft = -1920`).
  2. Open any dialog in QPV that uses `repositionWindowCenter()` while on monitor 1 such that `Final_x` calculates to `0`.
  3. **Result:** `!Final_x` evaluates to true, setting `Final_x = -1919` and jumping the window onto the left monitor.

---

### 4. Out-of-Bounds Frame Navigation (`changeDesiredFrame`)

- **Locations**: `quick-picto-viewer.ahk` (Line 12198).
- **Code Snippet**:
  ```autohotkey
  desiredFrameIndex := clampInRange(desiredFrameIndex + dir, 0, totalFramesIndex, 1)
  ```
- **Root Cause Analysis**:
  For multi-frame files (GIFs, TIFFs, PDFs), frame indexing is 0-based: valid indices range from `0` to `totalFramesIndex - 1`. Line 12198 passes `totalFramesIndex` as the maximum parameter to `clampInRange()`.
  Because `max` is `totalFramesIndex` (e.g. 5 for a 5-frame GIF), `desiredFrameIndex` is allowed to reach `5`. When stepping forward past the last valid frame (index 4), `desiredFrameIndex` becomes 5 (out of bounds), attempting to render a non-existent frame before wrapping around to 0 on the next step.
- **Steps to Reproduce**:
  1. Open a multi-frame image or document (e.g., a 5-frame animated GIF or 5-page PDF).
  2. Step forward through frames using `Ctrl+Up` / `Ctrl+Down` or the frame menu options.
  3. Stepping past frame index 4 sets `desiredFrameIndex = 5` (an out-of-bounds index), causing a blank/failed frame render before wrapping to 0 on the next step.

---

### 5. Pure Blue Text / Vector Overlays Turn 100% Transparent in Watermark Tool

- **Locations**: `QPV DLL source code/qpv-main.cpp` (Lines 488–503, line 496).
- **Code Snippet**:
  ```cpp
  DLL_API int DLL_CALLCONV SetColorAlphaChannel(int *imageData, int w, int h, int newColor, int invert) {
      ...
      for (int x = 0; x < w; x++)
      {
          INT64 px = x + ky;
          unsigned char alpha1 = (imageData[px] >> 16) & 0xFF; // red
          alpha1 = (invert==1) ? 255 - alpha1 : alpha1;
          unsigned char alpha2 = (newColor >> 24) & 0xFF; // alpha
          imageData[px] = (min(alpha1,alpha2) << 24) | (newColor & 0x00ffffff);
      }
  }
  ```
- **Root Cause Analysis**:
  In 32-bit ARGB pixel format (`0xAARRGGBB`), the red channel byte is located at bit offset 16 (`>> 16`) and the alpha channel byte is at bit offset 24 (`>> 24`). Line 496 incorrectly shifts by `>> 16` (the red channel byte) to extract `alpha1`.
  When rendering pure blue text or vector shapes (`#0000FF` / RGB 0, 0, 255), the red channel byte is `0`. `alpha1` evaluates to `0`, causing `min(alpha1, alpha2)` to set the pixel's alpha channel to `0` (completely transparent). The blue text or shape overlay disappears entirely.
- **Steps to Reproduce**:
  1. Open an image in Quick Picto Viewer.
  2. Open the **Text / Watermark Tool** panel (`coreInsertTextInAreaBox`).
  3. Enter text and select **Pure Blue** (`#0000FF` / RGB 0, 0, 255) as the font color.
  4. Render/place the text onto the image canvas.
  5. **Result:** The rendered text is completely invisible because its red channel byte is `0`, causing `SetColorAlphaChannel` to force alpha to `0`.

---

### 6. Selection Box Collapses to 0 Pixels When Dragging Crop Right-to-Left or Bottom-to-Top

- **Locations**: `quick-picto-viewer.ahk` (Lines 25087–25096).
- **Code Snippet**:
  ```autohotkey
  nImgSelX1 := imgSelX1 := min(imgSelX1, imgSelX2)
  nimgSelX2 := max(imgSelX1, imgSelX2)
  ```
- **Root Cause Analysis**:
  Line 25091 mutates `imgSelX1` to `min(imgSelX1, imgSelX2)`. Line 25093 then calculates `nimgSelX2 := max(imgSelX1, imgSelX2)`.
  When a user drags a crop selection box from right to left, initial `imgSelX1` is greater than `imgSelX2`.
  Line 25091 overwrites `imgSelX1` with `imgSelX2`. Line 25093 calculates `max(imgSelX2, imgSelX2)`, setting `nimgSelX2` equal to `imgSelX2`. Both `ImgSelX1` and `ImgSelX2` become identical, collapsing the crop width to 0 pixels. The exact same flaw exists for Y coordinates when dragging from bottom to top.
- **Steps to Reproduce**:
  1. Open an image in Quick Picto Viewer.
  2. Drag a crop selection box from **right to left** (or **bottom to top**).
  3. Press `Ctrl+X` (or click Crop selection).
  4. **Result:** Crop fails or yields a 0-pixel width/height image.

---

### 7. Out-of-Bounds Indexing Bug when Appending Files (`currentFileIndex := maxFilesIndex - 1`)

- **Locations**: `quick-picto-viewer.ahk` (Line 25209, Line 26851, Line 32005).
- **Code Snippet**:
  ```autohotkey
  currentFileIndex := maxFilesIndex - 1
  ```
- **Root Cause Analysis**:
  AutoHotkey arrays are 1-indexed (`1` to `maxFilesIndex`). When appending files from the clipboard (`coreAddNewFiles`), adding a folder (`addNewFolder2list`), or double-clicking a folder in the Folders Tree window, QPV attempts to select the newly added image using `currentFileIndex := maxFilesIndex - 1`.
  If QPV starts with an empty workspace or a single open image (`maxFilesIndex = 1`) and 1 new image is appended (`maxFilesIndex` becomes 1), `maxFilesIndex - 1` calculates `1 - 1 = 0`.
  Setting `currentFileIndex := 0` causes QPV to look up `resultedFilesList[0]`, which does not exist in AHK. This results in a blank display or broken navigation state until manually navigating away.
- **Steps to Reproduce**:
  1. Launch QPV with a single image loaded (`maxFilesIndex = 1`).
  2. Open the **Folders Tree** tool window (or paste a folder/image from the clipboard).
  3. Double-click a folder to append its files to the current list.
  4. QPV sets `currentFileIndex` to `0`, resulting in a blank or broken main image display.

---

### 8. Variable Case Typo Bypasses Linked Channel Thresholds in Color Adjustments Panel

- **Locations**: `quick-picto-viewer.ahk` (Lines 17711–17713).
- **Code Snippet**:
  ```autohotkey
  threB := (userImgAdjustLinkThresholds=1) ? userImgAdjustThreR : userImgAdjustThreB
  threG := (userImgAdjustLinkThresholds=1) ? userImgAdjustThreR : userImgAdjustThreG
  QPV_AdjustImageColors(..., userImgAdjustThreR, ThreG, ThreB, ...)
  ```
- **Root Cause Analysis**:
  Lines 17711 and 17712 assign the linked threshold values to local variables `threB` and `threG` (lowercase).
  However, line 17713 passes `ThreG` and `ThreB` (capitalized) to `QPV_AdjustImageColors`. Since `ThreG` and `ThreB` are uninitialized variables in this scope, they evaluate to 0/empty strings, completely ignoring the linked threshold calculation and passing 0 for Green and Blue thresholds into `AdjustImageColorsPrecise`.
- **Steps to Reproduce**:
  1. Open an image in Quick Picto Viewer and open the **Color Adjustments** panel.
  2. Check the **"Link Thresholds"** checkbox.
  3. Adjust the **Red Threshold** slider value.
  4. Apply color adjustments: the Green and Blue channel thresholds remain 0 rather than matching the Red threshold.

---

### 9. Typo in Filter Operation Handler (`"ouside"` instead of `"outside"`)

- **Locations**: `quick-picto-viewer.ahk` (Lines 17431–17445).
- **Code Snippet**:
  ```autohotkey
  If InStr(modus, "outside")
     modus := "outside"
  ...
  If (throwErrorSelectionOutsideBounds(whichBitmap) || testEntireImgSelected() && modus="ouside")
  ```
- **Root Cause Analysis**:
  Line 17432 sets `modus := "outside"`. Line 17445 attempts to check `modus="ouside"` (missing the letter 't'). Because `"outside" = "ouside"` is always false, the validation check `testEntireImgSelected() && modus="ouside"` is completely bypassed when applying color effects outside a selection area.
- **Steps to Reproduce**:
  1. Open an image and select the entire image area (`Ctrl+A`).
  2. Select **Menu -> Edit -> Filters -> Apply viewport color effects -> ... outside the selection**.
  3. Due to the typo `"ouside"`, the condition never evaluates to true.

---

### 10. Navigation Menu Shortcut Text Swapped (Page Up vs Page Down)

- **Locations**: `quick-picto-viewer.ahk` (Lines 66288–66289).
- **Code Snippet**:
  ```autohotkey
  kMenu("PVnav", "Add", "&Previous`tPage down", "PreviousPicture",, " image in index")
  kMenu("PVnav", "Add", "&Next`tPage up", "NextPicture",, " image in index")
  ```
- **Root Cause Analysis**:
  In `createMenuNavigation()`, the shortcut text displayed in the menu labels is swapped: `&Previous` displays `Page down` and `&Next` displays `Page up`.
  However, in `processDefaultKbdCombos()` (lines 2145 & 2164), `PgDn` invokes `NextPicture()` while `PgUp` invokes `PreviousPicture()`. The menu labels contradict the actual keyboard bindings.
- **Steps to Reproduce**:
  1. Open an image in single image view.
  2. Open **Menu -> Navigation**.
  3. Observe the menu text: `Previous` claims the shortcut is `Page down`, and `Next` claims `Page up`.
  4. Press `Page down` on the keyboard: it loads the **Next** image. Press `Page up`: it loads the **Previous** image.

---

### 11. Touch Gesture Navigation Direction Inverted

- **Locations**: `quick-picto-viewer.ahk` (Lines 5692–5698).
- **Code Snippet**:
  ```autohotkey
  If (dirX=1)
     doNextSlide := 1
  Else If (dirX=-1)
     doPrevSlide := 1
  ```
- **Root Cause Analysis**:
  For horizontal touch swipe gestures (`swipeAct=2`), `dirX=1` represents a swipe from left to right. In standard UI touch gesture conventions, swiping right drags the previous image into view (`doPrevSlide`), and swiping left (`dirX=-1`) drags the next image into view (`doNextSlide`). Here `dirX=1` sets `doNextSlide := 1` and `dirX=-1` sets `doPrevSlide := 1`, reversing expected touch swipe behavior.
- **Steps to Reproduce**:
  1. Use touch or pen swipe gestures in image view mode.
  2. Swipe horizontally from left to right across the screen.
  3. **Result:** The viewer advances to the next image instead of pulling the previous image into view.

---

### 12. PDF Export Rejects Single Image Selection (`z > 1` Check)

- **Locations**: `quick-picto-viewer.ahk` (Lines 43658, 43679).
- **Code Snippet**:
  ```autohotkey
  z := Round(tempList.Count())
  ...
  If (z>1 && abandonAll!=1)
  {
     r := DllCall("qpvmain.dll\CreatePDFfile", ...)
  }
  ...
  If (z<=1 && abandonAll!=1)
  {
     showTOOLtip(erm "No image was succesfully processed.")
  }
  ```
- **Root Cause Analysis**:
  The check `If (z>1 && abandonAll!=1)` requires `z` (the number of selected images/pages) to be strictly greater than 1. When a user selects a single image and attempts to convert it to PDF, `z` equals 1. The script skips calling `CreatePDFfile` altogether and displays the error tooltip `"Failed to create the PDF file. No image was succesfully processed."` without producing a PDF.
- **Steps to Reproduce**:
  1. Open QPV and select exactly **1 image** in the grid or workspace.
  2. Click **File -> Combine / Export selected images to PDF**.
  3. Click **Start / Save PDF**.
  4. **Result:** The operation fails with the tooltip error `"No image was succesfully processed."` and no PDF is created.

---

### 13. PDF Page Box Scaling Bug in PDF Export (DPI Multiplier Bug)

- **Locations**: `QPV DLL source code/Jpeg2PDF.cpp` (Lines 24–25, 84, 91), `QPV DLL source code/qpv-main.cpp` (Line 9278), `quick-picto-viewer.ahk` (Line 43669).
- **Code Snippet**:
  ```cpp
  pPDF->pageW = (UINT32)(pdfW * pdf_dpi); // e.g. 8.5 * 300 = 2550
  pPDF->pageH = (UINT32)(pdfH * pdf_dpi); // e.g. 11.0 * 300 = 3300
  ```
- **Root Cause Analysis**:
  In `quick-picto-viewer.ahk`, page dimensions are calculated in inches (e.g. `8.5` × `11.0` inches for Letter) and passed to `CreatePDFfile` along with target DPI.
  Inside `Jpeg2PDF_BeginDocument`, `pdfW` and `pdfH` are multiplied by `pdf_dpi` (`8.5 * 300 = 2550`), and `pPDF->pageW` is formatted directly into the PDF output header: `MediaBox[0 0 2550 3300]`.
  According to the official PDF Specification, `MediaBox` dimensions MUST be specified in **points** at fixed **72 points per inch** (1 pt = 1/72 inch). Because `pdfW` was multiplied by 300 DPI, the generated PDF page box is set to `2550` points instead of `612` points.
  When opened in any standard PDF reader (Adobe Acrobat, Chrome, Edge), selecting 300 DPI turns an 8.5" × 11" document into a giant 35.4" × 45.8" poster (~4.16× oversized).
- **Steps to Reproduce**:
  1. Select multiple images in QPV and click **Export to PDF**.
  2. Select **Letter** or **A4** page size and set resolution to **300 DPI**.
  3. Export and open the PDF file in Adobe Acrobat or Chrome.
  4. Check Document Properties: an 8.5" × 11" page renders as ~35.4" × 45.8".

---

### 14. Non-JFIF (EXIF / Camera / Smartphone) JPEGs Fail to Export to PDF

- **Locations**: `QPV DLL source code/Jpeg2PDF.cpp` (Lines 253–260), `QPV DLL source code/qpv-main.cpp` (Lines 9256–9265).
- **Code Snippet**:
  ```cpp
  static int get_jpeg_size(unsigned char* data, unsigned int data_size, unsigned short *width, unsigned short *height) {
    if (data[i] == 0xFF && data[i+1] == 0xD8 && data[i+2] == 0xFF && data[i+3] == 0xE0)
    {
      i += 4;
      if (data[i+2] == 'J' && data[i+3] == 'F' && data[i+4] == 'I' && data[i+5] == 'F' && data[i+6] == 0x00)
  ```
- **Root Cause Analysis**:
  `get_jpeg_size()` strictly requires JPEG files to start with an APP0 marker (`0xE0`) containing a null-terminated `JFIF` header.
  Photos taken by smartphones, digital cameras, or saved by Adobe Photoshop/Lightroom use EXIF APP1 headers (`0xE1` / `Exif\0\0`) or Adobe APP14 headers (`0xEE`).
  When an EXIF photo is passed to PDF export, `get_jpeg_size()` fails and returns `0`. `InsertJPEGFile2PDF` logs a failure and returns `ERROR`, causing PDF export to fail or skip standard camera photos.
- **Steps to Reproduce**:
  1. Select standard photos taken with a smartphone or digital camera (or a JPEG saved with EXIF headers in Photoshop).
  2. Open QPV, select the photos, and click **Export to PDF**.
  3. PDF export fails (or displays error code `-1` / `-7`), because `get_jpeg_size()` rejects non-JFIF EXIF JPEG headers.

---

### 15. Null-Pointer Check Comparison Error in PDF Generation (`pdfId < 0`)

- **Locations**: `QPV DLL source code/qpv-main.cpp` (Lines 9278–9280).
- **Code Snippet**:
  ```cpp
  PJPEG2PDF pdfId;
  pdfId = Jpeg2PDF_BeginDocument(pageW, pageH, dpi);
  if (pdfId < 0) 
     return -1;
  ```
- **Root Cause Analysis**:
  `Jpeg2PDF_BeginDocument` returns a pointer (`PJPEG2PDF` / `JPEG2PDF*`). If memory allocation inside `Jpeg2PDF_BeginDocument` fails, it returns `NULL` (`0`).
  Comparing a pointer against `< 0` (`pdfId < 0`) evaluates to `false` when `pdfId == NULL`, so execution continues with `pdfId == NULL`, causing an immediate null pointer dereference crash inside subsequent `Jpeg2PDF_AddJpeg` or `Jpeg2PDF_SetXREF` calls.
- **Steps to Reproduce**:
  1. Trigger PDF Export under constrained system memory conditions.
  2. If memory allocation fails, the application crashes immediately instead of returning error code `-1` gracefully to AHK.

---

### 16. GDI+ Bitmap Stride Padding Skew in `SetColorAlphaChannel`

- **Locations**: `QPV DLL source code/qpv-main.cpp` (Line 488), `quick-picto-viewer.ahk` (Line 14468).
- **Code Snippet**:
  ```cpp
  DLL_API int DLL_CALLCONV SetColorAlphaChannel(int *imageData, int w, int h, int newColor, int invert) {
      ...
      INT64 ky = (INT64)y * w;
      INT64 px = x + ky;
  ```
- **Root Cause Analysis**:
  `SetColorAlphaChannel` indexes pixels assuming a tightly packed pixel buffer where row stride equals `w * 4`.
  However, in `quick-picto-viewer.ahk`, `iScan` is passed directly from GDI+ `LockBits`. On Windows, GDI+ aligns scanlines to 4-byte boundaries, meaning images with odd widths (e.g. 101px wide) contain padding bytes at the end of each row (`Stride != w * 4`).
  Because `SetColorAlphaChannel` ignores `Stride`, row pixel calculations drift out of alignment, causing diagonal skewing and visual pixel corruption across image rows.
- **Steps to Reproduce**:
  1. Open an image with an odd width (e.g., 101 × 100 pixels).
  2. Apply the Color Alpha Channel operation (`QPV_SetColorAlphaChannel`).
  3. Observe diagonal skewing and pixel alignment corruption across the rendered image.

---

### 17. Bottom Edge Unprocessed/Corrupted in Image Pixelate Filter

- **Locations**: `QPV DLL source code/qpv-main.cpp` (Lines 3803–3845).
- **Code Snippet**:
  ```cpp
  for (int y1 = 0; y1 < h / Size; ++y1)
  {
      for (int x1 = 0; x1 < w / Size; ++x1)
      ...
  }

  if (w % Size != 0)
  {
      // Handles right edge horizontal remainder
  }
  ```
- **Root Cause Analysis**:
  In `PixelateBitmap`, line 3840 handles horizontal remainder (`w % Size != 0`) along the right edge of the image.
  However, there is **no handling for vertical remainder (`h % Size != 0`)** at the bottom of the image.
  When the image height `h` is not an exact multiple of the block size `Size` (e.g., height 1005px with block size 20px), the bottom 5 pixel rows (rows 1000 to 1004) are skipped and never rendered or copied to `dBitmap`. This leaves the bottom strip of the image un-pixelated or filled with garbage memory.
- **Steps to Reproduce**:
  1. Open an image in QPV whose height is not a multiple of the pixelate block size (e.g. height 1005px, block size 20px).
  2. Open **Image Live Editing / Adjustments** panel and apply **Pixelate**.
  3. The bottommost pixels remain un-pixelated or exhibit corrupt pixel artifacts.

---

### 18. Metadata Changes Lost on Clearing Numerical QPV Queries (`isStrFilter = 0`)

- **Locations**: `quick-picto-viewer.ahk` (Lines 33562–33629).
- **Code Snippet**:
  ```autohotkey
  If (mustDoQuery=1)
  {
     ...
     If !zuza
        Continue
  } Else If (isStrFilter=1)
  {
     If !coreSearchIndex(...)
        Continue
  }

  newFilesIndex++
  newFilesList[newFilesIndex] := bckpResultedFilesList[A_Index]
  ...
  If (isStrFilter=1)
     newMappingList[newFilesIndex] := A_Index
  ```
- **Root Cause Analysis**:
  `newMappingList` maintains index mapping between the filtered file list and `bckpResultedFilesList`.
  Line 33629 places `newMappingList[newFilesIndex] := A_Index` inside an `If (isStrFilter=1)` block.
  When running a numerical QPV query (e.g. filtering by image width, height, megapixels, or DPI), `mustDoQuery := 1` is true, but `isStrFilter` is `0`.
  As a result, `newMappingList` is never populated for numerical QPV queries. When `FilterFilesListuIndex` finishes, `filteredMap2mainList` is left empty, causing metadata or rating modifications made during the filtered view to be lost when turning off the filter.
- **Steps to Reproduce**:
  1. Open a folder of images.
  2. Apply a numerical QPV filter (e.g. Filter by Image Width or Megapixels).
  3. Modify an image property or rating while in the filtered view.
  4. Clear the filter to return to the full file list.
  5. **Result:** The property/rating modification applied during the filtered view is lost.

---

### 19. Filter to Selection Shortcut (Ctrl+Tab) Out-of-Bounds Index (`userFilterProperty := 19`)

- **Locations**: `quick-picto-viewer.ahk` (Lines 32920, 39124–39128).
- **Code Snippet**:
  ```autohotkey
  filterToFilesSelection() {
     userFilterProperty := 19
     userFilterInvertThis := userFilterDoString := 0
     thisFilter := updateUIFiltersPanel("external")
     coreSetFilesFilteru(thisFilter)
     ...
  }
  ```
- **Root Cause Analysis**:
  `filterToFilesSelection()` sets `userFilterProperty := 19`.
  However, the `columnsList` dictionary inside `updateUIFiltersPanel` only defines key mapping up to index `18`.
  Accessing `columnsList[19]` returns a blank string (`""`), causing `updateUIFiltersPanel("external")` to construct an invalid query string `QPV::query::::...`. This causes the "Filter files list to selection" shortcut (Ctrl+Tab) to fail or produce query errors.
- **Steps to Reproduce**:
  1. Select several images in the file list.
  2. Press **Ctrl+Tab** (or click **Filter files list to selection** in the menu).
  3. **Result:** The filter fails to isolate the selected files due to the invalid property index 19.

---

### 20. Random Navigation / Slideshow Reverts to Sequential Playback After Filter or Sort

- **Locations**: `quick-picto-viewer.ahk` (Lines 2734–2739, 12511–12562, 39057–39074).
- **Code Snippet**:
  ```autohotkey
  GenerateRandyList() {
     interfaceThread.ahkassign("maxFilesIndex", maxFilesIndex)
     RandyIMGids := []
     RandyIMGnow := -1
  }
  ```
- **Root Cause Analysis**:
  Whenever the user filters, sorts, or refreshes the file list, QPV calls `GenerateRandyList()`, which resets `RandyIMGids` to an empty array (`[]`).
  When random navigation or random slideshow advances to the next image, `coreNextPrevImage` looks up `z := RandyIMGids[thisIndex]`. Because `RandyIMGids` was cleared by `GenerateRandyList()`, `z` and `r` evaluate to blank, skipping all loop iterations.
  `coreNextPrevImage` falls back to line 12548: `newIndex := startIndex + 1` (linear sequential mode).
  As a result, applying any filter or changing sort order breaks random mode, forcing QPV to play images in plain sequential order (1, 2, 3...) instead of randomly.
- **Steps to Reproduce**:
  1. Open a folder with multiple images, enable **Random Slideshow** (or press Next Random Image).
  2. Apply any file filter (e.g. search query) or change sort order (e.g. Sort by Date/Name).
  3. Press **Next Random Image** (or let slideshow advance).
  4. QPV stops picking random images and advances sequentially in linear order.

---

### 21. Duplicates Filter Ignores MSE Threshold When Only One Duplicate Pair Exists

- **Locations**: `QPV DLL source code/qpv-main.cpp` (Lines 6146–6147).
- **Code Snippet**:
  ```cpp
  const bool allowMSE = (n >= 2 && dupesPairsList[0].mse < QPV_MSD_NONE
                               && dupesPairsList[1].mse < QPV_MSD_NONE);
  ```
- **Root Cause Analysis**:
  `dupesApplyFilter` determines whether Mean Squared Difference (MSE) filtering should be enabled by checking `n >= 2` and checking `dupesPairsList[0]` and `dupesPairsList[1]`.
  If the duplicate scanner finds exactly **1 duplicate pair** (`n == 1`), `allowMSE` evaluates to `false`. The MSE lower and upper threshold bounds (`mseLo` / `mseHi`) are completely ignored, returning the pair even if it exceeds the user's MSE limit.
- **Steps to Reproduce**:
  1. Run a duplicate scan on a set of images where exactly 1 duplicate pair exists.
  2. Set an MSE filter threshold to filter out pairs with high pixel differences.
  3. **Result:** The MSE filter threshold is ignored and the single pair is kept regardless of its MSE score.

---

### Summary Table

| # | Subsystem | Target File & Line | Root Cause Summary | Impact |
| :-: | :--- | :--- | :--- | :--- |
| **1** | Selection Nav | `quick-picto-viewer.ahk:L39254` | `navSelectedFilesPrev()` calls `navSelectedFiles(1)` (forward) | "Previous Selected" menu item/action moves forward instead of backward |
| **2** | Viewport Zoom | `quick-picto-viewer.ahk:L11782` | Rotated zoom calculation uses unrotated `ImgW` instead of `ImgH` | Mouse wheel focal zoom jumps/drifts on 90°/270° rotated viewports |
| **3** | Window Handling | `quick-picto-viewer.ahk:L27808` | `!Final_x` evaluates `0` as false, forcing `mCoordLeft + 1` | Dialogs centered at X=0 jump screens on multi-monitor setups |
| **4** | Multi-frame Nav | `quick-picto-viewer.ahk:L12198` | `clampInRange` passes `totalFramesIndex` instead of `totalFramesIndex - 1` | Stepping past last frame tries rendering out-of-bounds frame index |
| **5** | Watermark Tool | `qpv-main.cpp:L496` | Bit-shift `>> 16` extracts Red channel byte instead of Alpha byte | Pure blue (`#0000FF`) text/vector overlays turn 100% transparent/invisible |
| **6** | Image Crop | `quick-picto-viewer.ahk:L25087` | Overwrites `imgSelX1` before evaluating `max(imgSelX1, imgSelX2)` | Dragging selection right-to-left or bottom-to-top collapses crop box to 0px |
| **7** | File Navigation | `quick-picto-viewer.ahk:L25209` | `currentFileIndex := maxFilesIndex - 1` sets index to `0` on 1-item lists | Blank/failed viewport display when adding files/folders to empty workspace |
| **8** | Color Adjustments | `quick-picto-viewer.ahk:L17711` | Passes capitalized `ThreG`/`ThreB` instead of local `threG`/`threB` | Checking "Link Thresholds" ignores Green and Blue sliders |
| **9** | Filter Handler | `quick-picto-viewer.ahk:L17445` | Typo `"ouside"` (missing 't') in `modus="ouside"` comparison | Whole-image selection check bypassed for outside-selection color effects |
| **10** | Menu Labels | `quick-picto-viewer.ahk:L66288` | Menu text claims `Previous` is `PgDn` and `Next` is `PgUp` | Menu shortcut labels contradict actual keyboard hotkey bindings |
| **11** | Touch Gestures | `quick-picto-viewer.ahk:L5692` | `dirX = 1` (swipe right) sets `doNextSlide` instead of `doPrevSlide` | Touch/pen horizontal swipe navigation directions are inverted |
| **12** | PDF Export | `quick-picto-viewer.ahk:L43658` | `If (z > 1)` check strictly requires > 1 image | Selecting a single image to export to PDF fails with error |
| **13** | PDF Export | `Jpeg2PDF.cpp:L24` | PDF `MediaBox` multiplied by DPI instead of using fixed 72 pt/inch | Generated PDF pages render ~4.16× oversized (e.g. 35.4" × 45.8" at 300 DPI) |
| **14** | PDF Export | `Jpeg2PDF.cpp:L253` | `get_jpeg_size()` strictly requires `0xE0` (JFIF) headers | Standard EXIF photos (cameras/smartphones) fail to export to PDF |
| **15** | PDF Export | `qpv-main.cpp:L9278` | Pointer check `pdfId < 0` instead of `pdfId == NULL` | Memory allocation failure causes crash instead of graceful error |
| **16** | Image Editing | `qpv-main.cpp:L488` | `SetColorAlphaChannel()` ignores GDI+ Stride byte padding | Diagonal skewing and corruption on images with non-multiple-of-4 widths |
| **17** | Image Editing | `qpv-main.cpp:L3803` | `PixelateBitmap()` lacks handling for vertical remainder (`h % Size != 0`) | Bottom edge of pixelated image remains un-pixelated or corrupted |
| **18** | File Searching | `quick-picto-viewer.ahk:L33562` | `newMappingList` skipped when `isStrFilter = 0` during QPV query | Metadata changes/ratings lost upon clearing numerical QPV queries |
| **19** | File Searching | `quick-picto-viewer.ahk:L32920` | `filterToFilesSelection()` sets `userFilterProperty := 19` out of bounds | Filter to Selection shortcut (Ctrl+Tab) fails or returns query errors |
| **20** | Navigation / Slideshow | `quick-picto-viewer.ahk:L2734` | `GenerateRandyList()` resets `RandyIMGids` without rebuilding it | Sorting/filtering forces Random Mode back into linear 1-2-3 sequence |
| **21** | Duplicates Finder | `qpv-main.cpp:L6146` | `allowMSE` requires `n >= 2` duplicate pairs | MSE threshold is ignored when exactly 1 duplicate pair is found |
