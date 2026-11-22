# `dupes-pixels.h` & `dupes-search.h` audit and optimization report, 2026-11-22

Scope:

- `QPV DLL source code/lib/dupes-pixels.h` (1,561 lines): parallel image decoding, histogram statistics, pixel-fingerprint extraction, shared decode-slot throttling, and SQLite write-back (`dupesPixInit` / `Begin` / `Step` / `End` / `Shutdown`, `dupesPixBusyJob`, `dupesPixWorkStates`, `qpvSetPixelFormatNames`, `qpvGetPixelFormatName`);
- `QPV DLL source code/lib/dupes-search.h` (2,954 lines): Hamming and MSD pair sweep (`dupesSweepPairs`, `dupesScanBegin` / `Feed` / `SetGroups` / `Step` / `End`), threshold filter and union-find grouping (`dupesApplyFilter`), candidate query engine (`dupesEngineInit` / `Release` / `Cancel`, `dupesQueryBegin` / `Step`, `dupesScanBuildFromQuery`), hash generation (`dupesHashBegin` / `Step` / `End`), and 2D 32×32 DCT pHash (`calculateDCTcoeffs`, `calcPHashAlgo`).

Cross-checked against `QPV DLL source code/lib/thumbs-pool.h`, `sqlite-dynamic.h`, `open-cv-func.h`, `pdfium-reader.h`, `qpv-main.cpp`, `qpv-main.vcxproj`, `QPV DLL source code/tests/*`, and the AutoHotkey callers in `quick-picto-viewer.ahk`.

Line numbers refer to `development` at `2ae58f6`. This audit changed no source code.

Each finding states how it was checked: **run** means reproduced or benchmarked on Linux x64 (`g++ 11+`, `-O2 -std=c++17`, Intel Core i7-7700T, 8 hardware threads) against verbatim `dupes-pixels.h` (via `tests/shim/pixels-env.h` + `libsqlite3.so.0`) or verbatim `dupes-search.h` extracts sliced by `tests/run-tests.sh` + `libsqlite3.so.0`; **read** means established from code inspection (including Windows/MSVC-specific paths and thread-interleaving races).

---

## Summary

### Part 1 — Bugs in `dupes-pixels.h`

| # | Finding | Harm | Checked |
|---|---------|------|---------|
| P1 | `dpDecodeFile()` ignores `cfg.firstFIM` (`alwaysOpenWithFIM`), skips WIC fallback after FreeImage failure, and lets failed `.pdf` / `.svg` fall through to GDI+ | high | run |
| P2 | `dpDecodeFile()` discards `tpFIMthumb()`'s `status` and PDFium's `errorType`, permanently marking valid images `isDeleted=1` on transient OOM / resize / tone-map failures | high | read |
| P3 | `dpTopUpQueue()` runs `UPDATE images SET isDeleted=1` while `dpSelect` is actively stepping `images` on the same connection (SQLite undefined cursor behavior) | high | read |
| P4 | `updPixSQL` (`INSERT OR REPLACE`) wipes existing `smallH`/`bigH` fingerprints with `NULL` whenever a row is re-collected with `wantFlipped=0` | high | run |
| P5 | Uncaught `std::bad_alloc` on worker threads (`dpMarkBusy` string copy, `dpResults.push_back`) calls `std::terminate()` under low memory; uncaught `std::system_error` in `dupesPixInit()` crosses `__stdcall` | high | read |
| P6 | `dupesPixShutdown()` timeout (`!allOut`) detaches workers and empties `dpWorkers`, so a subsequent `dupesPixInit()` revives zombie workers on colliding `dpBusy` slots and breaks `dpExited` | medium | read |
| P7 | `dupesPixBegin()` / `dupesPixEnd()` never call `cv::setNumThreads(1)`, causing `N × N` OpenCV thread oversubscription during FreeImage rescale and tone mapping | medium | read |
| P8 | `dpDecodeFile()` blocks uninterruptibly on `pdfiumMutex` while holding a shared `TpJobSlot`, starving `thumbs-pool` under memory pressure and causing shutdown timeouts | medium | read |
| P9 | `dpTopUpQueue()` treats `SQLITE_INTERRUPT` as normal end-of-rows (`dpSetDrained(true)`), reporting an interrupted query as drained | medium | read |
| P10 | GDI+ bitmap and `LockBits` leak when `out.resize()` throws `std::bad_alloc` inside `dpDumpBlue()` | low-med | read |
| P11 | `dpMakeEffects()` ignores `GdipSetEffectParameters()` failure (silently leaving no-op gray/blur effects active) and skips `blurB` when `blurA != NULL`; `dpWriteResult()` ignores `dpMarkDead` failures | low | read |

### Part 2 — Bugs in `dupes-search.h`

| # | Finding | Harm | Checked |
|---|---------|------|---------|
| S1 | `dupesQueryStep()` closes the active group on an unparseable hash (`!usable`), splitting valid duplicate groups in two and silently dropping duplicate images | high | run |
| S2 | `dupesApplyFilter()` calls `order.reserve(kept.size())` (pair count, not image count — 504 MB for 7M pairs on MSVC x64) with no `try/catch`, crashing AutoHotkey on `std::bad_alloc` | high | read |
| S3 | `dupesEngineCancel()` races without a lock against `dupesEngineRelease()` / `dupesEngineInit()` on raw pointer `dupesDB` (use-after-free in `SQ.interrupt`); `dupesEngineInit()` also leaks `progress_handler` and stale `dupesEngineError` | high | read |
| S4 | `calcPHashAlgo()` has C++17 signed left-shift UB (`one << 1` at `x = 62, 63`), unchecked `givenArray == NULL`, and silently returns all-zero hashes if `calculateDCTcoeffs(32)` was not called | med-high | run |
| S5 | Multiple uncaught `std::bad_alloc` paths cross `__stdcall` into AutoHotkey (including `dupesSetError()` inside `dupesQueryStep()`'s own OOM `catch (...)`) | medium | read |
| S6 | `dupesHashStep()` treats `SQLITE_INTERRUPT` as normal completion (`return 0`) instead of cancel/error | medium | read |
| S7 | `buildRowKey()` has C++ UB on `SQLITE_INTEGER >= 2^63 - 512` (`(sqlite3_int64)(double)v`) and shift UB on `nocaseMask >> k` when `keyCount >= 32` | medium | read |
| S8 | `dupesSweepPairs()` has signed `INT` overflow on `offsetu + stepping`, unchecked `NULL` pointer arguments, and doubles every pair when `checkFlipped=1` with `givenFlippedHashesArray=NULL` | medium | run |
| S9 | 32-bit `UINT` wraparound in bounds checks (`decodeFingerprintChunk`, `decodeFingerprintBytes`, `dupesScanSetGroups`, and `dupesApplyFilter` `maxId + 1` / infinite loop at `UINT_MAX`) | medium | read |
| S10 | `sweepRowsInto()` emits up to 2–3 duplicate records for the same `(idA, idB)` under `checkFlipped`/`checkInverted`, bloating RAM and overwriting better distances under `BreakDupesGroups=1`; API-level `wantMSD` ignores flip/invert | low-med | read |
| S11 | `dupesApplyFilter()` leaves 1 stale row in `dupesFilterRows` when `dupesFilterRows.size() == 1` triggers `dupesRestoreSavedPairs()` | low | run |
| S12 | `dupesScanBuildFromQuery()` returns `1` with `comparisons == 0` on all-singleton survivors; `dupesScanStep()` can finish with `dupesScanState.threads == 0` | low | read |
| S13 | Dead helper `setMainWindowTitle()` remains compiled and sliced, with broken signed-`char` widening | low | read |

### Part 3 — Big-Gain Optimization Opportunities in `dupes-search.h`

| # | Target | Technique | Measured / Expected Gain | Output |
|---|--------|-----------|--------------------------|--------|
| O1 | Large-group Hamming sweep (`dupesScanStep`) | **Multi-Index Hashing (MIH)** / pigeonhole bucketing (`r <= 7..11`) with automatic skew-aware fallback | **60× – 208×** at `N=70k`; **~1,500×+** at `N=500k` (`74 ms` vs `~110 s` on Preset 1) | 100% byte-identical |
| O2 | `calcPHashAlgo()` & `dupesHashStep()` | **8×8 truncated + even/odd symmetric + pre-scaled SIMD DCT** + `nth_element` + compact `uint8_t` buffer | **19.4×** (SSE2 baseline, `34.3 → 1.77 µs/img`) / **21.0×** (AVX2+FMA); `0 / 50,000` hash mismatches | Bit-identical hashes |
| O3 | Brute-force sweep (`sweepRowsInto`) | **Template specialization + pre-masking + 4× outer unroll + runtime AVX2 `vpshufb+vpsadbw` + `maskBits - diff` inverted identity** | **2.7× – 3.4×** (SSE2+POPCNT) / **5.0×** (AVX2, `981 → 196 ms`, `12.5B cmp/s`) | 100% byte-identical |
| O4 | `dupesApplyFilter()` | **Zero `std::string`/`snprintf` sorting**, single-pass fused union-find, drop `kept` vector, fix `order.reserve()` | **3.5×** faster (`367 → 106 ms` on 5M pairs) + **80–95% less RAM** (even larger on MSVC) | 100% byte-identical |
| O5 | `msdSumSquares()` & `decodeFingerprintBytes()` | **Runtime AVX2 32 B/iter dual-accumulator MSD** + **256-byte LUT** for `grayCompressor > 1` | **2.33×** MSD (`89.7 → 38.5 ns/pair`); **1.7×–4.4×** fingerprint decode | Exact |
| O6 | `dupesQueryStep()` & `buildRowKey()` | **Defer `imagesPixels.big` PK fetch out of SQLite `ORDER BY`** + UTF-8 `column_text` + skip zero-fill | **1.8×** in RAM (100k rows); **5×–10×** when 1 GB sort avoids disk spill on 1M-image libraries | Exact |
| O7 | Parallel driver (`dupesScanStep` / `dupesRunPlan`) | **Step-scoped thread crew** (reused across blocks within one `dupesScanStep`), huge-row splitting, parallel merge | Eliminates ~8–15 OS thread spawn/joins per 350 ms step (major on Windows) & boosts multi-core fill | 100% byte-identical |

---

# Part 1 — Bugs in `dupes-pixels.h`

## P1. `dpDecodeFile()` diverges from `tpRunJob()`: ignores `cfg.firstFIM`, misses WIC fallback after FreeImage, and hands failed `.pdf`/`.svg` to GDI+

- **Location**: `dupes-pixels.h:425-559` (compare `thumbs-pool.h:1639-1765`).
- **Checked**: **run** (verbatim `dupes-pixels.h` via `shim/pixels-env.h`).

`dupes-pixels.h`'s header comment (lines 39-41) states that `dpDecodeFile()` runs the exact same loader chain as `tpRunJob()` so thumbnails and fingerprints never disagree. Three concrete divergences break that contract:

1. **`cfg.firstFIM` (`alwaysOpenWithFIM`) is parsed and then completely ignored.** `dupesPixBegin()` reads option 16 into `cfg->firstFIM` (`:1323`), `dpWorkerBody()` copies it into `tcfg.firstFIM` (`:762`), and `tpFIMthumb()` never reads `cfg->firstFIM`. In `dpDecodeFile()` (`:430`):
   ```cpp
   const bool fimHandles = (FIM.ok && cfg.allowFIM==1 && tpFimExts.count(ext) > 0);
   ```
   Compare `thumbs-pool.h:1640, 1691`:
   ```cpp
   const bool fimHandles = (FIM.ok && (cfg->allowFIM==1 && tpFimExts.count(ext)>0 || cfg->firstFIM==1));
   ```
   When the user enables «Always open images with FreeImage» (`alwaysOpenWithFIM=1`), `thumbs-pool.h` sends `.jpg`/`.png`/etc. to FreeImage first, whereas `dpDecodeFile()` still sends them to WIC (`fimCalls=0, wicCalls=1, loaderUsed=1` in our run on `photo.jpg` with `cfg.firstFIM=1`). If `allowFIM=0 && firstFIM=1`, `thumbs-pool.h` still invokes FreeImage while `dupes-pixels.h` skips it.
2. **Failed `.pdf` and `.svg` files fall through to `tpGDIPload()` (and to FreeImage once `firstFIM` is honored).** Unlike `thumbs-pool.h:1690-1757`, which guards FreeImage, WIC, and GDI+ with `!isPdf`, `dpDecodeFile()` has no early return (or `!isPdf && !isSvg` guard) after the `svg`/`pdf` branches (`:432-491`). When PDFium fails on a password-protected or corrupt PDF or Direct2D fails on a broken SVG, `bmp == NULL` falls straight into `tpGDIPload()` (`:549-556`). In our run:
   - `locked.pdf` with `gShimPdfFails=1, gShimGdipFails=0` ran `pdfCalls=1, gdipCalls=1` and returned `loaderUsed=6`! (Even `tests/pixels_smoke.cpp:408, 424` had to set `gShimGdipFails=1` to mask this.)
   - Every corrupt/locked PDF or broken SVG pays an unnecessary extra GDI+ open/parse attempt (risking GDI+ codec overhead or polyglot misinterpretation).
3. **FreeImage failure skips WIC when `ext` is not in `tpWicExts`.** `thumbs-pool.h:1710` tries WIC whenever `tpWicExts.count(ext)>0 || hasFIMtried==1`; `dupes-pixels.h:511` checks only `tpWicExts.count(ext) > 0`. If FreeImage fails on an extension it claims (e.g. a RAW/WebP/HEIF/AVIF/JXL file for which a Windows WIC codec is installed, or a misnamed file), `dpDecodeFile()` skips WIC and jumps straight to GDI+ (`fimCalls=1, wicCalls=0, gdipCalls=1` on `.exr` in our run).

**Fix**: Align `dpDecodeFile()` with `tpRunJob()`: honor `cfg.firstFIM==1` in `fimHandles` and the FreeImage check; `return bmp;` directly at the end of the `ext==L"svg"` and `ext==L"pdf"` branches (never falling through to raster loaders); and include `|| hasTriedFim==1` in the WIC fallback condition at `:511`.

---

## P2. Transient OOM / resize / tone-map / convert errors inside FreeImage and PDFium permanently mark valid images `isDeleted=1`

- **Location**: `dupes-pixels.h:52-62, 468-546, 586-593`; `thumbs-pool.h:1465-1595`; `open-cv-func.h:276-281, 333-336`; `pdfium-reader.h:431-472`.
- **Checked**: **read**.

`dupes-pixels.h:52-62` explicitly distinguishes `DP_ERR_LOAD` (permanently marks `isDeleted=1`) from `DP_ERR_PROCESS` (retried on the next run, never marked dead) specifically because allocation failures and OpenCV rescale failures happen far more often under 32-thread collection:

> `"what reaches here is an allocation that did not come back, an exception out of the FreeImage/OpenCV rescale, or GDI+ refusing a bitmap it had just produced ... a library quietly marking good photos as dead is not."`

However, `dpDecodeFile()` breaks this invariant in two ways:

1. **FreeImage (`:498-509, 528-538`)**: `tpFIMthumb()` reports distinct failure causes through `int status`: `TP_ERR_LOAD` (decode failed) vs. `TP_ERR_RESIZE` (OOM/OpenCV error in rescale), `TP_ERR_CONVERT` (OOM in `ConvertToStandardType`/`ConvertTo24Bits`/`tpFIMtoGdip`), and `TP_ERR_TONEMAP` (tone-map OOM/failure). Furthermore, `openCVresizeBitmapExtended()` (`open-cv-func.h:276`) and `openCVapplyToneMappingAlgos()` (`open-cv-func.h:333`) catch `cv::Exception` / `(...)` internally and return `0`, so they **never** escape to `dpRunJob()`'s `catch (...)` at `:654` — they turn into `status = TP_ERR_RESIZE` / `TP_ERR_TONEMAP` and return `NULL`. `dpDecodeFile()` discards `status` completely, falls through, returns `NULL`, and `dpRunJob()` leaves `res.status = DP_ERR_LOAD` (`:564, 587-593`), permanently setting `isDeleted=1`!
2. **PDFium (`:468-490`)**: `coreRenderPdfPageAsBitmap()` returns `errorType == -4` (failed to allocate or lock GDI+ bitmap) and `errorType == -5` (failed to allocate `FPDF_BITMAP`) on OOM after the PDF opened and loaded the page. `dpDecodeFile()` only logs `errorType` and returns `NULL`, so `dpRunJob()` marks the valid PDF `isDeleted=1`.

**Fix**: Propagate a `bool &transientErr` out-parameter from `dpDecodeFile()`: set it when `tpFIMthumb()` returns `TP_ERR_RESIZE`, `TP_ERR_CONVERT`, or `TP_ERR_TONEMAP`, or when PDFium returns `errorType == -4` or `-5` (and stop falling through to later loaders when a file already decoded and only failed post-decode). In `dpRunJob()`, when `bmp == NULL && transientErr`, set `res.status = DP_ERR_PROCESS`.

---

## P3. `dpTopUpQueue()` runs `UPDATE images SET isDeleted=1` while `dpSelect` is mid-scan on `images`

- **Location**: `dupes-pixels.h:1021-1070`.
- **Checked**: **read**.

Inside the `for (;;)` loop stepping `dpSelect` (`SELECT imgidu, fullPath FROM images ...`):

```cpp
if (plen < 1)
{
   if (dpMarkDead!=NULL)
   {
      SQ.reset(dpMarkDead);
      SQ.bind_int64(dpMarkDead, 1, job.imgidu);
      SQ.step(dpMarkDead);
      SQ.reset(dpMarkDead);
   }
   dpState.failed = dpState.failed + 1;
   continue;
}
```

1. **Undefined SQLite cursor mutation**: `dpMarkDead` (`UPDATE images SET isDeleted=1 WHERE imgidu=?1`) modifies `images` and `imgsAliveIndex(isDeleted)` on the same connection while `dpSelect` holds an open read cursor on `images`. `dupes-search.h:2659-2661` explicitly calls out this exact hazard (`"stepping an UPDATE against 'images' while this SELECT is still scanning it leaves what the cursor sees next undefined"`) and collects `badIds` to update *after* `SQ.reset(selectStmt)`. `dpTopUpQueue()` does not.
2. **Silent write failure & skewed `submitted` counter**: `SQ.step(dpMarkDead)`'s return value is ignored (write failures are not counted in `dpState.dbErrors`), and `continue;` skips `dpState.submitted++` at `:1067`, allowing `written + failed + dbErrors > submitted`.

**Fix**: Collect empty-path `imgidu`s into a local `std::vector<INT64> deadIds`, step `dpMarkDead` *after* `SQ.reset(dpSelect)` at `:1070`, check `SQ.step(dpMarkDead) == SQLITE_DONE` (incrementing `dpState.dbErrors` on failure), and increment `dpState.submitted` consistently.

---

## P4. `updPixSQL` (`INSERT OR REPLACE`) wipes existing `smallH`/`bigH` fingerprints when re-collecting with `wantFlipped=0`

- **Location**: `dupes-pixels.h:977-989, 1365-1366`.
- **Checked**: **run** (verbatim `dupes-pixels.h` against `libsqlite3.so.0`).

```sql
INSERT OR REPLACE INTO imagesPixels (imgidu, small, big, smallH, bigH) VALUES (?1,?2,?3,?4,?5);
```

When `cfg.wantFlipped == 0`, `res.smallH` and `res.bigH` are empty vectors, so `dpBindBlobOrNull()` binds `NULL` for `?4` and `?5`. SQLite's `INSERT OR REPLACE` deletes the existing row and inserts a new one with `smallH = NULL, bigH = NULL` — silently erasing flipped fingerprints that were already collected! This happens whenever a row with existing `imagesPixels` is selected for a non-flipped collection pass (for example, collecting missing histogram stats `imgavg`/`imgmedian` via `collectSQLFileInfosNow()` with `findFlippedDupes=0`, or after partial/imported data). In our run on a row with `imgavg IS NULL` and all four blobs populated, `smallH` and `bigH` dropped from `1` present to `0` present after a single `wantFlipped=0` collection pass.

Compare `updHistSQL` (`:1358-1364`), which carefully uses `COALESCE(?9, imgwidth)` etc. to avoid erasing existing columns with `NULL`.

**Fix**: Use SQLite UPSERT (supported since SQLite 3.24; QPV already requires >= 3.31 for generated columns):
```sql
INSERT INTO imagesPixels (imgidu, small, big, smallH, bigH) VALUES (?1,?2,?3,?4,?5)
ON CONFLICT(imgidu) DO UPDATE SET
  small  = COALESCE(excluded.small,  imagesPixels.small),
  big    = COALESCE(excluded.big,    imagesPixels.big),
  smallH = COALESCE(excluded.smallH, imagesPixels.smallH),
  bigH   = COALESCE(excluded.bigH,   imagesPixels.bigH);
```

---

## P5. Uncaught `std::bad_alloc` on worker threads in `dpWorkerBody()` (and `std::system_error` in `dupesPixInit()`) terminates the process

- **Location**: `dupes-pixels.h:211, 775, 799, 1103`.
- **Checked**: **read**.

`dpRunJob()` wraps decoding and GDI+ work in `try { ... } catch (...)` (`:583-664`), explicitly noting that allocations throw when memory is scarce. However, two heap allocations on the worker thread happen **outside** any `try/catch`:

1. `dpMarkBusy(mySlot, &job.path, 1)` (`:775` -> `:211`: `dpBusy[slot].path = *path;`) allocates heap memory for `std::wstring`.
2. `dpResults.push_back(std::move(res))` (`:799`) allocates a new `std::deque` block when crossing a chunk boundary.

An uncaught exception escaping a `std::thread` function calls `std::terminate()` and kills QPV immediately — right under the low-memory conditions this pool's throttle is designed to survive.

Similarly, `dupesPixInit()` (`:1103`) calls `dpWorkers.push_back(std::thread(dpWorkerBody, (size_t)i))` with no `try/catch`; if thread creation throws `std::system_error` (or `reserve` throws `bad_alloc`), the exception crosses the `extern "C" __stdcall` DLL boundary into AutoHotkey (UB / crash) while leaving earlier threads running with `dpState.alive == 0`.

**Fix**: Wrap the body of `dpWorkerBody()`'s job processing (including `dpMarkBusy` and `dpResults.push_back`) so any `bad_alloc` drops the busy path / marks the job failed without leaking `dpState.inFlight`/`dpRunInFlight` or escaping the thread. Wrap `dupesPixInit()`'s thread-spawn loop in `try/catch (...)` (setting `dpState.alive = (LONG)dpWorkers.size()` for however many started).

---

## P6. `dupesPixShutdown()` timeout leaves detached workers that collide with a subsequent `dupesPixInit()`

- **Location**: `dupes-pixels.h:152, 718-817, 1086-1108, 1508-1559`.
- **Checked**: **read**.

When `dupesPixShutdown()` times out after 5 seconds (`allOut == false`):
- It detaches all `workers` (`:1543`), leaves `dpStopping == true` (`:1551-1552`), empties `dpWorkers`, and resets `dpState.alive = 0; dpState.inFlight = 0;` (`:1549-1550`).
- If `dupesPixInit()` is called again later while any detached worker is still stuck in a decoder:
  1. `dupesPixInit()` sees `dpWorkers.empty()` and resets `dpStopping.store(false)` (`:1099`), spawning new workers with slots `0..nThreads-1`.
  2. When the detached straggler eventually finishes its decode, it writes `dpBusy[mySlot]` (`:789-791`), clobbering the *new* worker assigned to `mySlot`, and decrements the *new* run's `dpState.inFlight` (`:793`).
  3. Because `dpStopping` is now `false` again, the detached worker **never exits** — it loops back to `dpJobCV.wait()` (`:718`) and permanently competes for jobs on the same `mySlot` as the new worker!
  4. On a later `dupesPixShutdown()`, the extra zombie worker increments `dpExited++` (`:815`), making `dpExited >= workers.size()` true prematurely so `join()` can hang on a wedged new worker instead of honoring the 5-second timeout.

*(In AHK today, `TrueCleanup()` only calls `dupesPixShutdown()` on application exit, so this is latent in normal QPV use, but `dupesPixShutdown()`/`dupesPixInit()` is a public re-initializable lifecycle API and exercised repeatedly in tests.)*

**Fix**: Give each pool incarnation its own `std::shared_ptr<std::atomic<bool>> stopFlag` (and per-incarnation `dpExited` / `dpBusy` or refuse `dupesPixInit()` while detached workers from a prior incarnation remain alive) so a detached worker can never see a new incarnation's `dpStopping == false`, touch its `dpBusy` slot, or increment its `dpExited` / `inFlight`.

---

## P7. Missing `cv::setNumThreads(1)` causes `N × N` OpenCV thread oversubscription

- **Location**: `dupes-pixels.h:780, 1278-1391, 1491-1506` (compare `thumbs-pool.h:2040-2047, 2110-2118`).
- **Checked**: **read**.

`thumbsPoolBegin()` explicitly clamps OpenCV to one thread (`cv::setNumThreads(1)`) because each worker calls `tpFIMthumb()` -> `tpFIMrescale()` -> `openCVresizeBitmapExtended()` -> `cv::resize()` and `tpFIMtoneMapOpenCV()` -> `openCVapplyToneMappingAlgos()`, noting that otherwise `"every worker would otherwise spawn a full team of its own"`.

`dupes-pixels.h` calls the exact same `tpFIMthumb()` on up to 32 worker threads simultaneously, yet `dupesPixBegin()` / `dupesPixEnd()` **never** set `cv::setNumThreads(1)`. On libraries with FreeImage formats (RAW, EXR, HDR, WebP, AVIF, JXL, etc., or with `alwaysOpenWithFIM=1`), every collection worker triggers multi-threaded OpenCV on 350 px thumbnails, causing severe thread oversubscription (`N × N` threads fighting over `N` cores) and excess memory overhead.

Also note: because `thumbs-pool` and `dupes-pixels` can run concurrently (as documented in `thumbs-pool.h:425-428`), OpenCV's thread clamp should use a **shared reference count** between the two pools rather than two independent save/restore globals (`tpPrevCVthreads`), so `thumbsPoolEnd()` does not restore multi-threaded OpenCV while `dupes-pixels` is still running (or vice versa).

---

## P8. `dpDecodeFile()` holds a `TpJobSlot` while blocking uninterruptibly on `pdfiumMutex`

- **Location**: `dupes-pixels.h:458-470, 776-782`.
- **Checked**: **read**.

In `dpWorkerBody()`, a worker acquires a `TpJobSlot` (incrementing `tpActiveJobs`) *before* calling `dpRunJob()` -> `dpDecodeFile()`. Inside `dpDecodeFile()` (`:460`), PDF jobs execute:

```cpp
std::lock_guard<std::timed_mutex> pdfLock(pdfiumMutex);
if (dpJobAbandoned(jobGeneration))
   return NULL;
```

Two consequences:

1. **Uninterruptible cancel/shutdown**: If one worker (or the viewport's `RenderPdfPageAsBitmap`) holds `pdfiumMutex` for a slow PDF, all other PDF workers waiting on `pdfLock` cannot check `dpJobAbandoned()` until the lock is released. Calling `dupesPixShutdown()` during a PDF backlog easily hits the 5-second timeout and detaches those workers.
2. **Decode-slot starvation**: Multiple PDF workers sleeping on `pdfiumMutex` each hold an active `TpJobSlot` (`tpActiveJobs`), even though only one is decoding. When memory turns tight (`tpSlotCap = 1`), those sleeping waiters block `thumbs-pool` from taking any decode slot until the PDF queue drains.

**Fix**: Replace `std::lock_guard` with a polling `std::unique_lock<std::timed_mutex>` loop using `try_lock_for(std::chrono::milliseconds(25))` that checks `dpJobAbandoned(jobGeneration)` on each wake. Even better, acquire `pdfiumMutex` *without* holding `TpJobSlot` while waiting, or check `pdf` before taking a slot so only the worker that holds `pdfiumMutex` consumes a `TpJobSlot`.

---

## P9. `dpTopUpQueue()` marks the query drained on `SQLITE_INTERRUPT`

- **Location**: `dupes-pixels.h:1023-1034, 1073-1074`.
- **Checked**: **read**.

```cpp
if (rc!=SQLITE_ROW)
{
   if (rc!=SQLITE_DONE && rc!=SQLITE_INTERRUPT)
   {
      dupesSetError(L"the pixel-collection query failed", dpDB);
      dpState.lastError = 6;
      SQ.reset(dpSelect);
      return -1;
   }
   break;
}
...
if (seen < want)
   dpSetDrained(true);
```

If `dpDB` is interrupted (`SQLITE_INTERRUPT`), `dpTopUpQueue()` breaks out without returning `-1`, sees `seen < want`, and sets `dpSetDrained(true)` — causing `dupesPixStep()` to treat the run as finished (`phase = 5`, returning `0`) once in-flight items drain, even though rows remain uncollected.

**Fix**: Treat `SQLITE_INTERRUPT` as cancellation (return `-1` or set `dpState.phase = -1` and do **not** call `dpSetDrained(true)`).

---

## P10. GDI+ bitmap and `LockBits` leak on `std::bad_alloc` inside `dpDumpBlue()`

- **Location**: `dupes-pixels.h:319-332, 621-628, 640-647, 654-664`.
- **Checked**: **read**.

In `dpDumpBlue()`, `out.resize((size_t)w * h)` (`:322`) runs *after* `GdipBitmapLockBits(bmp, ...)` (`:319`). If `out.resize()` throws `std::bad_alloc`, execution jumps directly to `dpRunJob()`'s `catch (...)` at `:654`:
- `GdipBitmapUnlockBits()` (`:332`) is never called on `x1` or `x2`;
- `x1` and `x2` (`:621-622`, `:640-641`) are local variables inside the `try` block and are **never disposed** (`catch (...)` only disposes `bmp`), leaking GDI+ bitmaps precisely when memory is already exhausted.

**Fix**: Resize `out` *before* calling `GdipBitmapLockBits()`, and hold `x1`/`x2` (and `bmp`) in a tiny RAII wrapper so every GDI+ bitmap is disposed on any exit path.

---

## P11. Unchecked `GdipSetEffectParameters()` in `dpMakeEffects()` and unchecked `dpMarkDead` in `dpWriteResult()`

- **Location**: `dupes-pixels.h:239-259, 918-925`.
- **Checked**: **read**.

1. `dpMakeEffects()` (`:240-258`) checks `GdipCreateEffect()` but ignores the `Gdiplus::Status` returned by `GdipSetEffectParameters()`. If setting parameters fails, `fx.gray` remains non-NULL with default saturation `0` (so `GdipBitmapApplyEffect` succeeds without grayscaling, silently storing the color image's blue channel!), and `fx.blurA`/`fx.blurB` remain non-NULL with radius `0` (silently storing unblurred fingerprints). Also `:249` gates both `blurA` and `blurB` creation on `fx.blurA == NULL`, so if `blurB` previously failed while `blurA` succeeded, a re-call without `dpFreeEffects()` would skip creating `blurB`.
2. `dpWriteResult()` (`:918-925`) ignores the return value of `SQ.step(dpMarkDead)`. If marking a dead row fails (read-only / full / locked DB), `dpState.dbErrors` is not incremented and the failure goes unreported.

**Fix**: In `dpMakeEffects()`, delete and NULL the effect handle if `GdipSetEffectParameters() != Gdiplus::Ok`, and check `fx.blurA==NULL` / `fx.blurB==NULL` independently. In `dpWriteResult()`, check `SQ.step(dpMarkDead) == SQLITE_DONE` and reflect DB write failures in `dpState.dbErrors`.

---

# Part 2 — Bugs in `dupes-search.h`

## S1. `dupesQueryStep()` splits and drops valid duplicate groups when an unparseable hash sits inside a key run

- **Location**: `dupes-search.h:2124-2153`.
- **Checked**: **run** (verbatim `query_extract.cpp` against `libsqlite3.so.0`).

```cpp
if (!usable)
{
   dupesCloseRun();
   dupesKeyPrev.clear();
}
```

When a grouping key column is `NULL` (`!buildRowKey(...)`, `:2113`), SQLite's `ORDER BY` places all `NULL`s together at the start of their key partition, so closing the run cannot separate equal non-NULL rows.

**Hashes are not in `ORDER BY`** (rows within a group are ordered by `imgmegapix, fsize`). A row with an unparseable hash (non-hex characters, whitespace, length > 16, or corrupt text in the DB) can land right in the **middle** of a run of identical-key rows `{A, bad, C}`:
- `A` opens a run of length 1;
- `bad` hits `if (!usable)` and calls `dupesCloseRun(); dupesKeyPrev.clear();`, which sees length 1 (`< 2`) and **deletes `A`**;
- `C` opens a new run of length 1, which is also **deleted** at the end of the group!
- Even with `{A1, A2, bad, C1, C2}`, the single group is split into **two separate groups** `{A1, A2}` and `{C1, C2}` that are never compared against each other!

Verified live against SQLite (`bug_repro.cpp`):
- 2 identical valid dupes (`imgidu 1, 3`) separated by 1 bad-hash row (`imgidu 2`): returned **`rows=0, groups=0`** (expected `rows=2, groups=1`);
- 4 identical valid dupes (`imgidu 1, 4, 3, 5`) separated by 1 bad-hash row (`imgidu 2`): returned **`rows=4, groups=2`** (expected `rows=4, groups=1`).

**Fix**: Simply skip unusable rows without closing the current run or clearing `dupesKeyPrev`:
```cpp
if (!usable)
   continue; // (still updating sinceClock if desired)
```
Because rows arrive sorted by the grouping keys, skipping a bad row inside the same key keeps the run intact, and if the bad row had a *different* key, the next usable row (with a different key) will still fail `dupesKeyPrev != dupesKeyCur` and close the previous run cleanly.

---

## S2. `dupesApplyFilter()` over-reserves `order` by pair count (`kept.size()`) with no `try/catch`, crashing AutoHotkey on large pair lists

- **Location**: `dupes-search.h:1410-1613`, specifically `:1558-1561`.
- **Checked**: **read**.

```cpp
struct SortEnt { std::string key; std::string gid; UINT idu; };
std::vector<SortEnt> order;
std::vector<std::string> keepIDs;
order.reserve(kept.size());
```

`order` holds at most **one entry per unique surviving image** (`<= maxId + 1`), yet line 1561 reserves `kept.size()` — the number of **surviving pairs**!
- On MSVC x64, `sizeof(std::string) == 32`, so `sizeof(SortEnt) == 72` bytes.
- A scan producing 7 million pairs (explicitly cited in the comment at `:670`) over 100,000 images allocates **`7,000,000 × 72 B = 504 MB`** for a vector that will only use ~7 MB. At 25–30M pairs, that single `reserve()` demands **~2 GB** on top of `dupesPairsList` (~480 MB) and `kept` (~240 MB).
- Worse, **none** of the allocations in `dupesApplyFilter()` (`kept`, `rowRoot`, `rowTag`, `imgHam`, `imgMSE`, `parent`, `grpHam`, `seen`, `order`, `keepIDs`, `dupesFilterRows`) are wrapped in `try/catch`. A `std::bad_alloc` propagates straight across the `extern "C" __stdcall` DLL boundary into AutoHotkey, immediately crashing the application (contrast `dupesRunPlan()` at `:873-891` which explicitly guards against this).

**Fix**: Replace `SortEnt` with `{ UINT root, tag, idu }` (see Optimization O4), reserve at most the actual unique image count (or `min<size_t>((size_t)maxId + 1, keptCount * 2)`), and wrap `dupesApplyFilter()` in `try { ... } catch (const std::bad_alloc&) { dupesFilterRows.clear(); dupesRestoreSavedPairs(); return 0; }`.

---

## S3. `dupesEngineCancel()` use-after-free race on `dupesDB` against `dupesEngineRelease()` / `dupesEngineInit()`

- **Location**: `dupes-search.h:1679, 1737-1809`.
- **Checked**: **read**.

`dupesEngineCancel()` is explicitly documented as `"Safe to call from any thread - and meant to be"` (`:1800-1809`), and `dupesEngineInit()` passes `SQLITE_OPEN_FULLMUTEX` specifically for cross-thread cancellation (`:1752-1755`). However, `dupesDB` is an unprotected raw pointer:

```cpp
DLL_API int DLL_CALLCONV dupesEngineCancel() {
    dupesCancelFlag.store(1, std::memory_order_relaxed);
    dupesPixCancel.store(1, std::memory_order_relaxed);
    if (SQ.ok && dupesDB!=NULL && SQ.interrupt!=NULL)
       SQ.interrupt(dupesDB);
    return 1;
}
```

`SQLITE_OPEN_FULLMUTEX` only serializes operations on an *open* connection; it does **not** protect against another thread calling `SQ.close_v2(dupesDB); dupesDB = NULL;` (`:1743, 1785-1786`) between the `dupesDB != NULL` check and `SQ.interrupt(dupesDB)`. That is a classic use-after-free crash if any non-main thread invokes `dupesEngineCancel()` during init or teardown.

Two additional small defects in `dupesEngineInit()` (`:1737-1748`):
- When replacing an already-open `dupesDB` at `:1743`, it does not clear `SQ.progress_handler(dupesDB, 0, NULL, NULL)` first (unlike `dupesEngineRelease()` at `:1783`).
- It never calls `dupesEngineError.clear()` on entry (unlike `dupesQueryBegin`/`dupesHashBegin`/`dupesPixBegin`), so early failures (`dbPath == NULL` or `WideCharToMultiByte <= 0`) leave a stale message in `dupesEngineLastError()`.

**Fix**: Guard `dupesDB` open, close, and `SQ.interrupt(dupesDB)` with a dedicated `std::mutex dupesDBMutex` (never held across `SQ.step()`), unregister `progress_handler` before closing in `dupesEngineInit()`, and clear `dupesEngineError` at the start of `dupesEngineInit()`.

---

## S4. `calcPHashAlgo()`: C++17 signed shift UB, unchecked `NULL`, and silent all-zero hashes without `calculateDCTcoeffs(32)`

- **Location**: `dupes-search.h:2801, 2826-2842, 2872-2950`.
- **Checked**: **run** (verbatim `dct_extract.cpp`) & **read**.

1. **C++17 Undefined Behavior (`:2934-2946`)**:
   ```cpp
   INT64 one = 0x0000000000000001;
   INT64 hash = 0x0000000000000000;
   ...
   for (int x = 0; x < 64; x++)
   {
       if (fpexels[x] > compareTerm)
          hash |= one;
       one = one << 1;
   }
   ```
   `qpv-main.vcxproj` compiles with `<LanguageStandard>stdcpp17</LanguageStandard>`. In C++17, `one` is signed `INT64`: at `x = 62`, `one << 1` shifts a `1` bit into the sign bit (UB), and at `x = 63`, left-shifting negative `INT64_MIN` is also UB.
2. **Silent all-zero hashes if `calculateDCTcoeffs(32)` has not been called (`:2801, 2856`)**: `DCTcoeffs` starts zero-initialized; neither `calcPHashAlgo()` nor `dupesHashBegin(..., hashKind=3)` checks whether `calculateDCTcoeffs(32)` ran (or whether someone called `calculateDCTcoeffs(k)` with `k != 32`, which corrupts the table!). In our run on a non-uniform 32×32 image, `calcPHashAlgo()` silently returned **`0x0`** before `calculateDCTcoeffs(32)` vs `0xba50bb54ff551141` after. Every image hashed while uninitialized becomes a 0-distance duplicate of every other image.
3. **Unchecked `givenArray == NULL` (`:2878`)**: Passing `NULL` with `size == 32` dereferences `NULL` at `:2889`.

**Fix**: Use `UINT64 hash = 0;` with `hash |= (1ULL << x);`, guard `if (givenArray == NULL || size != 32) return 0;`, and initialize the 32×32 DCT table automatically (compile-time/startup static or `std::call_once`) so `calcPHashAlgo()` and `dupesHashBegin()` can never read an uninitialized or wrong-sized table.

---

## S5. Multiple uncaught `std::bad_alloc` paths cross the `__stdcall` DLL boundary

- **Location**: `dupes-search.h:735, 826, 1101, 1164, 2113, 2152, 2204, 2296, 2306, 2324, 2346, 2626, 2629, 2721`.
- **Checked**: **read**.

`dupes-search.h` carefully catches `std::bad_alloc` in `dupesScanBegin`, `dupesScanBuildRowEnd`, `dupesSweepWorker`, `dupesRunPlan` concatenation, and `dupesQueryStep`'s row-append block — explicitly noting that an uncaught exception across `__stdcall` crashes AutoHotkey. Several sibling allocation sites were missed:
- **`dupesQueryStep()` `:2204`**: inside its own OOM `catch (...)` handler, it calls `dupesSetError(L"the duplicates query ran out of memory", NULL);` — right beneath a comment warning `"the message is a string, which can fail to allocate as well"` — without wrapping `dupesSetError()` in its own `try/catch`! Also `:2113` (`buildRowKey`) and `:2152` (`dupesKeyPrev = dupesKeyCur`) allocate outside the `try` block.
- **`dupesScanFeed()` `:1101`**: `dupesScanFlipped.assign(dupesScanRows, 0);` (8 MB for 1M rows) is uncaught.
- **`dupesScanSetGroups()` `:1164`**: `dupesScanGroupStart.assign(...)` is uncaught.
- **`dupesScanBuildFromQuery()` `:2296, 2306, 2324, 2346`**: `dupesScanIDs.reserve(total)` and `dupesScanGroupStart.push_back(...)` are uncaught (even though `dupesScanBuildRowEnd()` right after them checks for OOM).
- **`dupesPlanRows()` `:735` and `dupesRunPlan()` `:826`**: `dupesSweepPlan.push_back` and `dupesSweepBufs.resize` are uncaught.
- **`dupesHashStep()` `:2626, 2629, 2721`**: `ids.reserve`, `dupesHashPixBuf.resize`, and `out` allocation are uncaught.

**Fix**: Wrap these exported entry points (and the inner `dupesSetError()` in `dupesQueryStep`'s `catch`) in `try/catch (const std::bad_alloc&)` returning clean error codes (`0` / `-1`) with `phase = -1, lastError = 1`.

---

## S6. `dupesHashStep()` reports `SQLITE_INTERRUPT` as normal completion (`return 0`)

- **Location**: `dupes-search.h:2679-2680, 2717-2718`.
- **Checked**: **read**.

```cpp
if (rc==SQLITE_DONE || rc==SQLITE_INTERRUPT)
   break;
...
if (ids.empty())
   return sawRow ? dupesHashStillMoving(cursorWas, wroteWas, skippedWas) : 0;
```

If `dupesHashSel` is interrupted (`SQLITE_INTERRUPT`) before yielding a row, `ids.empty()` and `!sawRow` cause `dupesHashStep()` to return **`0`** (completed!) rather than `-1` (cancelled/error). If interrupted mid-batch after some rows, it hashes those rows and returns `1` as if nothing happened.

**Fix**: Handle `rc == SQLITE_INTERRUPT` separately: reset `dupesHashSel`, call `dupesSetError(L"the hash generation was cancelled", dupesHashDB)`, and return `-1`.

---

## S7. `buildRowKey()` undefined behavior on near-`INT64_MAX` integers and `keyCount >= 32`

- **Location**: `dupes-search.h:1850-1863, 1880`.
- **Checked**: **read**.

1. **Out-of-range float-to-int conversion (`:1852-1854`)**:
   ```cpp
   const sqlite3_int64 v = SQ.column_int64(st, col);
   const double d = (double)v;
   if ((sqlite3_int64)d == v)
   ```
   For any `v` in `[2^63 - 512, 2^63 - 1]` (e.g. `INT64_MAX`), `(double)v` rounds up to `+2^63` (`9223372036854775808.0`), which exceeds `INT64_MAX`. Converting `+2^63` back via `(sqlite3_int64)d` is C++ Undefined Behavior. Fix: guard with `if (v >= -(1LL << 53) && v <= (1LL << 53))` (or `d >= -9223372036854775808.0 && d < 9223372036854775808.0 && (sqlite3_int64)d == v`).
2. **Shift count >= 32 (`:1880`)**:
   ```cpp
   const bool fold = ((nocaseMask >> k) & 1u)!=0;
   ```
   `nocaseMask` is a 32-bit `UINT`. If a caller ever supplies `keyCount > 32`, `nocaseMask >> k` for `k >= 32` is UB (on x64 `shr` masks by 31, silently applying column 0's NOCASE flag to column 32). Fix: `(k < 32) && (((nocaseMask >> k) & 1u) != 0)`.

---

## S8. `dupesSweepPairs()` bugs: signed `INT` overflow, unchecked `NULL`s, and doubled pairs when `flipped == NULL`

- **Location**: `dupes-search.h:952-1001`.
- **Checked**: **run** (verbatim `block_extract.cpp`).

1. **`checkFlipped=1` with `givenFlippedHashesArray=NULL` emits every match TWICE (`:972, 979`)**:
   `C.flipped` aliases `givenHashesArray` while `C.checkFlipped` stays `1` (contrast `dupesScanStep()` `:1232`, which correctly disables `C.checkFlipped = 0` when flipped hashes are absent). In our run on 2 identical images with `flipped=NULL, checkFlipped=1`, `dupesSweepPairs()` returned **`pairs=2`** instead of `1`.
2. **Signed `INT` overflow (`:987-992`)**:
   ```cpp
   const INT firstIndex = offsetu;
   INT lastIndex = offsetu + stepping;
   if (lastIndex > (INT)n - 1) lastIndex = (INT)n - 1;
   ```
   With `offsetu=1, stepping=0x7FFFFFFF`, `offsetu + stepping` overflows signed `INT` (UB, wraps to `INT_MIN`), so `firstIndex > lastIndex` triggers and our run returned **`pairs=0, hoff=0`** instead of `pairs=3, hoff=3`! Similarly `(INT)n - 1` overflows if `arraySize > INT_MAX`.
3. **Unchecked `NULL` pointers (`:971, 973, 994, 999`)**: Passing `NULL` for `hoffset`, `givenHashesArray`, or `givenIDs` crashes immediately.

**Fix**: Validate `if (!hoffset) return 0; *hoffset = 0; if (!givenHashesArray || !givenIDs || n < 2 || offsetu < 0 || (UINT)offsetu >= n) return 0;`, disable `C.checkFlipped = (givenFlippedHashesArray != NULL) ? checkFlipped : 0;`, and compute `lastIndex` in `INT64` (`min<INT64>((INT64)n - 1, (INT64)offsetu + max(0, stepping))`).

---

## S9. 32-bit `UINT` wraparound in bounds checks and `maxId + 1`

- **Location**: `dupes-search.h:281, 1164, 1460-1461, 1516, 1542, 1563, 1976`.
- **Checked**: **read**.

- `decodeFingerprintChunk()` (`:281`) and `decodeFingerprintBytes()` (`:1976`):
  ```cpp
  if ((size_t)(firstIndex + count) * stride > dupesPixData.size() || firstIndex + count > dupesPixOK.size())
  ```
  `firstIndex` and `count` are 32-bit `UINT`; `firstIndex + count` wraps modulo `2^32` *before* widening to `size_t`, bypassing both bounds checks on wraparound (compare `dupesScanFeed()` `:1089`, which properly writes `(size_t)firstIndex + count`).
- `dupesScanSetGroups()` (`:1164`): `groupStart + groups + 1` wraps if `groups == UINT_MAX`; widen `(size_t)groups + 1`.
- `dupesApplyFilter()` (`:1460, 1516, 1542, 1563`): if any pair holds `idA == UINT_MAX` or `idB == UINT_MAX`, `maxId + 1` wraps to `0` (out-of-bounds heap write on `rowRoot[p.idA]`), and `for (UINT i = 0; i <= maxId; i++)` is an infinite loop. Use `size_t` for `maxId + 1` and loop counters, and reject `maxId == 0xFFFFFFFFu` (which also collides with `NONE`).

---

## S10. Duplicate `(idA, idB)` emission under `checkFlipped`/`checkInverted` and API-level MSD mismatch

- **Location**: `dupes-search.h:618-661, 1474-1482`.
- **Checked**: **read**.

1. **Duplicate pair records & `BreakDupesGroups=1` regression**: In `sweepRowsInto()` (`:650-660`), if a pair satisfies both `diff < threshold` and `diff3 < threshold` (common for horizontally symmetric photos, or when a missing flipped hash fell back to `flip = hash` at `:2136`), the sweep pushes **two** `DupePairRec`s for the same `(idA, idB)` (up to three with `checkInverted=1` at high thresholds). Besides doubling `dupesPairsList` memory, under `BreakDupesGroups=1` (`dupesApplyFilter()` `:1474-1482`), the second record hits `hasA && hasB` and **overwrites** `rowTag` and `imgHam` with the later (potentially worse!) `diff3` distance (e.g. `diff = 0` overwritten by `diff3 = 4`). *(Note: changing `sweepRowsInto()` to emit only the minimum distance per pair is cleaner and matches user intent, though it slightly changes `dupesPairCount()` vs the legacy AHK transcription in `sweep_smoke.cpp` if flipped/inverted collide.)*
2. **DLL API contract for `wantMSD` + `checkFlipped` / `checkInverted`**: `BTNfindDupesNow()` in AHK (`quick-picto-viewer.ahk:91768-91769`) currently forces `findFlippedDupes = findInvertedDupes = 0` when `PerformMSDonDupes = 1`, so users cannot hit this through the GUI today. At the DLL API level (`dupesScanStep`, `dupesSweepPairs`, and `sweep_smoke.cpp`), however, `sweepRowsInto()` accepts all three flags simultaneously yet computes `msdScore()` strictly between the unflipped, uninverted `dupesPixData` rows — assigning huge MSD scores (~150–360) to genuinely mirrored or color-inverted duplicates.

---

## S11. `dupesApplyFilter()` leaves 1 stale row in `dupesFilterRows` after restoring saved pairs

- **Location**: `dupes-search.h:1607-1612`.
- **Checked**: **run** (`bug_repro.cpp`).

```cpp
if (dupesFilterRows.size() >= 2)
   dupesDropSavedPairs();
else
   dupesRestoreSavedPairs();

return (UINT)dupesFilterRows.size();
```

When a failed second search produces exactly 1 surviving row (`dupesFilterRows.size() == 1`, e.g. one image of a single pair is marked deleted in `imgKeep`), `dupesRestoreSavedPairs()` restores the prior search's `dupesPairsList`, yet `dupesFilterRows` is **not cleared**. In our run, `dupesApplyFilter()` returned `1`, restored the old cache, and left `dupesFilterRowCount() == 1` holding an orphan row from the discarded search. (AHK's `If (newIndex < 2)` avoids fetching it, but the DLL's filter buffer and pairs cache are now out of sync.)

**Fix**: Clear `dupesFilterRows` (and return `0` if appropriate, or clear when restoring saved pairs) so `dupesFilterRows` never holds a discarded search's row.

---

## S12. Minor `dupesScanBuildFromQuery()` / `dupesScanStep()` edge cases

- **Location**: `dupes-search.h:1251-1272, 2340-2379`.
- **Checked**: **read**.

1. If `keepMask` reduces every multi-image group to size 1 (e.g. two groups each losing one of two members), `kept == 2` passes `kept < 2` at `:2340`, so `dupesScanBuildFromQuery()` builds `dupesScanRowEnd`, saves the previous pairs cache, sets `dupesScanState.total = 0` (`comparisons == 0`), and returns `1`, sending AHK through a no-op `dupesScanStep()` round-trip. Checking `if (comparisons < 1)` before committing the sweep state avoids the useless step (and avoids claiming `groups > 0` for all-singleton survivors).
2. If `dupesScanStep()` finishes without running a block (e.g. `dupesScanOuter >= dupesScanRows`), `dupesScanState.threads` remains `0`, causing AHK (`quick-picto-viewer.ahk:88942`) to log the false warning `"The qpvmain.dll in use predates the threaded duplicates sweep"`.

---

## S13. Dead helper `setMainWindowTitle()` with broken non-ASCII widening

- **Location**: `dupes-search.h:367-373`.
- **Checked**: **read**.

`setMainWindowTitle()` is unused anywhere in QPV (not exported, no callers in C++ or AHK), yet it is still compiled into `qpvmain.dll` and sliced into every test harness (`sweep_smoke`, `filter_oracle`, `query_engine`, `sweep_bench`, `hash_bench` all declare a dummy `SetWindowText` stub solely for it). Its `std::wstring(str.begin(), str.end())` also sign-extends negative `char` bytes on MSVC into `0xFFxx` garbage.

**Fix**: Remove `setMainWindowTitle()` (and the dummy `SetWindowText` stubs in the test files).

---

# Part 3 — Big-Gain Optimization Opportunities in `dupes-search.h`

All proposals below were prototyped against verbatim `dupes-search.h` extracts and benchmarked on this machine (Intel Core i7-7700T @ 2.90 GHz, 8 hardware threads, `g++ -O2 -std=c++17`) while asserting **100% byte-for-byte identical output** against the shipped code (preserving exact deterministic `(secondIndex, mainIndex)` pair ordering, `BreakDupesGroups=1` semantics, and `hash_oracle` / `filter_oracle` / `sweep_smoke` contracts).

## O1. Multi-Index Hashing (MIH) / Pigeonhole Bucketing for Large Groups — **60× to 1,500×+ speedup**

- **Location**: `dupes-search.h:587-663, 1214-1297`.
- **Why it is huge**: When the user runs **Preset 1** (the default duplicate preset: `imgframes, imgwhratio`, `dHash`, `threshold = 2` -> `hamDist < 3`, `lCrop = 1, rCrop = 1`, `findFlippedDupes = 1`) or Custom mode with loose grouping, half a photo library lands in one giant 3:2 single-frame group. Today `sweepRowsInto()` runs an **O(M²)** brute-force triangle:
  - At `M = 70,000` (100k library): `2.45 billion` comparisons -> **`1.91 s`** with flipped detection (`0.97 s` without).
  - At `M = 500,000` (700k–1M library): `125 billion` comparisons -> **`~110 seconds`** (nearly 2 minutes; `245B` at `M = 700,000` is ~3–4 minutes).

### Algorithm (100% exact, zero false negatives)

To find all pairs with `popcount((h1 ^ h2) & hamMask) <= r` (where `r = threshold - 1`, over `B = popcount(hamMask)` active bits):

1. **Exact pigeonhole partitioning (`r <= 5`, covering Preset 1 `r=2` and typical thresholds `r=0..5`)**:
   - Split the `B` active bits into `m = r + 1` disjoint chunks of `floor(B/m)` or `ceil(B/m)` bits (capped at 20 bits -> max 4 MB histogram per table).
   - By the pigeonhole principle, any two hashes with Hamming distance `<= r` **must match identically in at least one of the `m` chunks**.
   - Build `m` flat CSR inverted indices (`head[(1<<w)+1]`, `vals[M]`, where indices inside each bucket are naturally sorted ascending because `i = 0..M-1` is inserted in order!).
   - For each row `s` (in parallel across all cores!), probe the `m` tables for `hashes[s]` (plus `~hashes[s]` if `checkInverted`, plus `flipped[s]` if `checkFlipped` — **reusing the exact same `m` tables**, zero extra index build!).
   - Inside each hit bucket, binary-search for the first index `> s`, deduplicate hits across the `m` chunks via a thread-local generation-stamped array `uint32_t seen[M]`, sort the tiny hit list ascending by `mainIndex`, and verify the full 64-bit `hammingDistance` + optional `msdScore`.
2. **1-bit-probe MIH (`r = 6..7`, i.e. `threshold = 7..8`)**:
   - Partition into `m = 4` chunks of 16 bits (`65,536` buckets each = 256 KB, L2-resident). If `dist <= 7`, at least one of the 4 chunks has `<= 1` differing bit (`4 × 2 = 8 > 7`).
   - Probing 1 exact + 16 1-bit-flipped buckets = 17 bucket lookups per chunk (`68` total per row) inspects only `68 / 65,536 ≈ 0.1%` of the group per row!
3. **Real-world skew protection & exactness**:
   - **Interleaved bit assignment**: Real `dHash`/`lHash`/`pHash` bits have spatial correlation (top rows = sky, low-entropy runs). Assign active bits interleaved across chunks (`bit k -> chunk k % m`) using a small mask/extract (or BMI2 `PEXT` when available; simple shift-and-mask for contiguous chunks already works cleanly, and bit-interleaving spreads entropy uniformly so sky-heavy photos don't pile into bucket `0`).
   - **Cost-checked automatic fallback**: Only enable MIH for groups with `M >= 1024` and `r <= 7` (or `r <= 11` with 2-bit probe / 6×10-bit 1-bit probe). After the O(M) counting pass builds `head[]`, sum `count[b] * (count[b] - 1) / 2` across all `m` tables in O(buckets): if the projected MIH candidate count exceeds `0.30 * M*(M-1)/2` (pathological all-identical or all-zero hashes), fall back immediately to the SIMD brute-force sweep (O3) for that group. Thus MIH can **never** regress below brute force.
   - **Exact output order & time-budgeting**: Building CSR tables for `M = 500,000` takes ~20 ms (well inside the 350 ms `dupesScanStep` budget), and row queries run in bounded row blocks through the exact same `dupesSweepPlan` / per-thread buffer concatenation — preserving exact `(secondIndex ascending, mainIndex ascending)` order and cancel responsiveness.

### Measured prototype results (`opt_bench` & `opt_bench2`, 8 threads, byte-identical verified)

| Scenario | Shipped `dupesScanStep` | MIH Prototype | Speedup | Byte-identical |
|---|---:|---:|---:|:---:|
| **Preset 1** (`r<=2`, `lCrop=1, rCrop=1`, `flipped=1`, `N=70k`, 6,114 pairs) | `1,909.9 ms` | **`19.8 ms`** | **96.4×** | YES |
| **Custom** (`r<=3`, no flip, `N=70k`, 7,404 pairs) | `968.4 ms` | **`4.7 ms`** | **207.7×** | YES |
| **Custom** (`r<=7`, 4×16 1-bit probe, `N=70k`, 7,357 pairs) | `968.4 ms` | **`16.0 ms`** | **60.7×** | YES |
| **Preset 1 at `N=500,000`** (`125B` brute-force pairs, 38,934 matches) | `~110,000 ms` *(extrap.)* | **`73.7 ms`** | **~1,490×** | *(exact alg.)* |

---

## O2. 2D 32×32 DCT `calcPHashAlgo()` & `dupesHashStep()` — **19× to 21× speedup**

- **Location**: `dupes-search.h:2494-2517, 2629-2759, 2803-2950`.
- **Why it is huge**: In `./hash_bench`, `dHash` takes `0.06 µs/image`, `lHash` takes `0.12 µs/image`, and `pHash` takes **`37.34 µs/image`** (600× slower than `dHash`, dominating full-library `pHash` generation: `3.90 s` single-threaded / `1.27 s` on 8 threads for 100k images).

### Four compounding wastes in `calcPHashAlgo()`

1. **93.75% of the DCT output is computed and thrown away (`:2885-2932`)**:
   - Pass 1 (row DCT) computes all 32 horizontal frequencies `u = 0..31` for all 32 rows (`32,768` multiply-adds), but Pass 2 only needs **`u = 0..7`** -> **75% dead work**.
   - Pass 2 (column DCT) computes all 32 vertical frequencies `v = 0..31` for all 32 columns (`32,768` multiply-adds), but `:2925-2932` only reads **`u = 0..7, v = 0..7`** -> **93.75% dead work**.
   - Truncating to `32 × 8` (Pass 1) + `8 × 8` (Pass 2) cuts multiply-adds from `65,536` to `10,240` (**6.4×**) with identical math.
2. **DCT-II even/odd symmetry cuts remaining multiplies in half**:
   - `cos(u * pi * (31 - j + 0.5) / 32) == (-1)^u * cos(u * pi * (j + 0.5) / 32)`.
   - Pre-adding `even[j] = x[j] + x[31-j]` and `odd[j] = x[j] - x[31-j]` for `j = 0..15` halves the inner loop to 16 steps (**12.8× fewer multiplies total**: `5,120` vs `65,536`).
3. **Fold `div2sz` / `div2sq` into an aligned 16×4 even + 16×4 odd table (1 KB total, L1-resident) and vectorize across `u = 0,2,4,6` and `u = 1,3,5,7`**:
   - Works on **baseline SSE2** (`__m128d`, two 2-wide accumulators for even + two for odd — ships on every Win7 x64 CPU with zero dispatch needed!), and even faster with runtime AVX2+FMA (`__m256d`).
4. **Replace `std::sort` on 64 doubles in `calcArrayAvgMedian()` (`:2807`) with `std::nth_element`** (finds indices 31 and 32 in O(64) instead of full O(64 log 64) sort).

### Additional `dupesHashStep()` cleanups
- Store `pHash` pixels in `dupesHashPixBuf` as `unsigned char` (`(unsigned char)(dupesHashLUT[s[i]] & 0xFF)`) instead of `int` (`:2432, 2498-2500`): shrinks the batch buffer 4× (`2 MB -> 512 KB`, better cache locality) and eliminates the per-image `buf[1024]` truncation copy in `dupesPHash()`.
- Pass `QPV_SQLITE_STATIC` instead of `QPV_SQLITE_TRANSIENT` at `:2746` (`hex[32]` is alive across `SQ.step` + `SQ.reset`).
- Replace `snprintf(tmp, ..., "%llx", v)` + widen loop in `dupesHexHash()` (`:2507-2517`) with a 10-line nibble-to-`wchar_t` loop.

### Measured prototype results (`opt_bench`, 50,000 random 32×32 images, single-threaded)

| Implementation | Total (50k imgs) | Per image | Speedup | Hash mismatches vs shipped |
|---|---:|---:|---:|---:|
| Shipped `calcPHashAlgo` | `1,715.4 ms` | `34.31 µs` | `1.0×` | — |
| **Baseline SSE2** (8×8 + sym + `nth_element`) | **`88.6 ms`** | **`1.77 µs`** | **19.4×** | **0 / 50,000** |
| **AVX2 + FMA** (8×8 + sym + `nth_element`) | **`81.6 ms`** | **`1.63 µs`** | **21.0×** | **0 / 50,000** |

At `1.77 µs/img`, a batch of 512 pHashes drops from **`19.1 ms` to `0.9 ms` on a single core** (making full-library pHash generation SQLite-bound, nearly as fast as `dHash`, even on low-core machines).

---

## O3. Brute-Force Sweep Kernel (`sweepRowsInto()`) — **2.7× to 5.0× speedup**

- **Location**: `dupes-search.h:169-213, 587-663`.
- **When it applies**: Whenever MIH does not trigger — high thresholds (`r >= 8..12+`), skewed/dense hash distributions where MIH falls back to brute force, and medium-sized groups (`M = 64..1023`).

### Five bottlenecks in the current `O(N²)` inner loop

1. **Runtime flags tested on every single pair (`:624, 626, 634`)**: `if (checkInverted==1)`, `if (checkFlipped==1)`, and the 3-way `diff >= threshold && diff2 >= threshold && diff3 >= threshold` execute billions of times, plus `if (qpvHasPopcnt)` inside `popcount64()`. Template-specializing the inner loop on `<HasPopcnt, CheckInverted, CheckFlipped>` removes every branch from the hot path.
2. **Redundant second `POPCNT` for `checkInverted == 1` (`:624-625`)**: Mathematically, `popcount((h1 ^ ~h2) & mask) === popcount(mask) - popcount((h1 ^ h2) & mask)` (`maskBits - diff`). Computing `diff2 = maskBits - diff` is bit-for-bit exact and eliminates the second `XOR + AND + POPCNT` entirely; both checks collapse to a single unsigned range test `(UINT)(diff - threshold) > (UINT)(maskBits - 2 * threshold)` when `2 * threshold <= maskBits`.
3. **Redundant `& hamMask` per pair (`:212`)**: Pre-masking `hashes[i] &= hamMask` (and `flipped[i] &= hamMask`) once before the sweep eliminates one ALU op per comparison on every cropped search (including Preset 1!).
4. **4× outer-loop unrolling**: Processing 4 consecutive `secondIndex` rows against each loaded `hashes[mainIndex]` cuts memory traffic on large L3-exceeding groups by **4×**, breaks `POPCNT` latency stalls, and amortizes loop control — while buffering hits in 4 tiny per-row scratch vectors `b0..b3` and flushing `b0, b1, b2, b3` in order preserves **100% byte-identical** output order.
5. **Runtime-dispatched AVX2 `vpshufb + vpsadbw` kernel**: The DLL already uses `__cpuid` at load (`:172`). Checking AVX2 (`CPUID.07H:EBX[5]` + `OSXSAVE` + `_xgetbv(0) & 6`) lets modern CPUs compute **4 × 64-bit Hamming distances in 6 vector instructions** (`vpxor`, 2× `vpshufb` nibble LUT, `vpaddb`, `vpsadbw`, `vpcmpgtq`) and skip all 4 pairs in **one branch** (`_mm256_movemask_pd == 0`), while keeping Win7 SSE2 compatibility intact.

### Measured prototype results (`opt_bench` & `opt_bench2`, `N = 70,000`, 8 threads)

| Kernel | Shipped | Optimized | Throughput | Speedup | Byte-identical |
|---|---:|---:|---:|---:|:---:|
| **SSE2+POPCNT** 4× unrolled (normal, `r<=5`) | `970.0 ms` | **`289.4 ms`** | `8.5B cmp/s` | **3.35×** | YES |
| **SSE2+POPCNT** 4× + `maskBits - diff` (`inverted=1`) | `959.4 ms` | **`357.6 ms`** | `6.9B cmp/s` | **2.68×** | YES |
| **AVX2** 4-wide × 4-outer (normal, `r<=3`) | `968.4 ms` | **`192.9 ms`** | `12.7B cmp/s` | **5.02×** | YES |
| **AVX2** 4-wide × 4-outer (high thresh `r<=11`) | `980.7 ms` | **`195.6 ms`** | `12.5B cmp/s` | **5.01×** | YES |

---

## O4. `dupesApplyFilter()` — **3.5×+ speedup and 80–95% RAM reduction**

- **Location**: `dupes-search.h:1380-1613`.
- **Why it matters**: Runs interactively on every Ctrl+F similarity slider adjustment and after every sweep.

### What wastes time and RAM today
1. **Four full passes over `dupesPairsList` + 80 MB `kept` vector**: Pass 1 finds `maxId` (`:1429`); Pass 2 filters into `std::vector<size_t> kept` (`:1437`, 80 MB for 10M pairs); Pass 3 runs union-find over `kept` (`:1519`); Pass 4 re-walks `kept` to compute `imgHam`, `imgMSE`, and `grpHam` (`:1530`).
   - **Fix**: Fuse filtering + union-find + `imgHam`/`imgMSE` into **one single streaming pass** over `dupesPairsList` (zero `kept` vector!). Since every kept pair `(a, b)` shares root `r`, `grpHam[r] = min_{u in component r} imgHam[u]` is mathematically identical to `min_{p in component r} p.hamDist` — computed in one O(unique images) pass instead of re-walking millions of pairs! (Tracking `dupesPairsMaxId` during the sweep eliminates Pass 1 too.)
2. **Per-image `std::string` + `snprintf("%09u")` + `snprintf("%u_%u")` sorting (`:1558-1595`)**:
   - Currently formats two strings per image (`e.key` ~28–35 chars -> exceeds 15-byte SSO -> heap allocation per image; `e.gid` -> another string), pushes `e` **by copy** (`order.push_back(e)` without `std::move`), sorts `std::string`s, pushes duplicate `std::string`s into `keepIDs`, sorts `keepIDs`, and binary-searches `std::string`s.
   - **Fix**:
     - Store `struct Ent { UINT root, tag, idu; };` (12 bytes vs 72 bytes + heap strings!).
     - For `breakGroups == 0`, every row with the same `root` shares the exact same `tag`, so sorting by `(root, idu)` and checking `seen[e.root] > minMembers` in O(1) is **100% identical** — zero strings, zero `keepIDs` vector!
     - For `breakGroups == 1`, compare `(root, lex(str(tag)+'z'), idu)` in registers/stack (or a 65-entry constant rank table for `tag <= 64`) and pack `keepIDs` as `UINT64 ((UINT64)root << 32 | tag)` with `std::unique`.
3. **Fixing `order.reserve(kept.size())` (Bug S2)** avoids allocating 500 MB–2 GB of unused memory.

### Measured prototype results (`opt_bench`, 5,000,000 pairs, 200,000 images)

| Mode | Shipped `dupesApplyFilter` | Optimized | Speedup | Byte-identical |
|---|---:|---:|---:|:---:|
| `BreakDupesGroups=0` (200k rows) | `367.4 ms` | **`106.3 ms`** | **3.46×** | YES |
| `BreakDupesGroups=1` (167.9k rows) | `237.4 ms` | **`70.3 ms`** | **3.38×** | YES |

*(On Windows MSVC x64, where `sizeof(std::string)` is 32 B and `HeapAlloc` + OS page-faulting 360+ MB for `order.reserve(5M)` is significantly heavier than Linux glibc, the real-world speedup and RAM savings will be even larger.)*

---

## O5. Runtime AVX2 `msdSumSquares()` & 256-Byte LUT in `decodeFingerprintBytes()` / `Chunk()`

- **Location**: `dupes-search.h:223-247, 296-298, 1983-1988`.

1. **AVX2 32-byte/iter dual-accumulator `msdSumSquares()`**: Processes 32 pixels per iteration (32 iterations instead of 64 for 1,024-byte fingerprints) into two independent `__m256i` accumulators to hide `vpaddd`/`vpmaddwd` latency.
   - Measured (`opt_bench`, 5M pairs × 1,024 B): SSE2 **`89.7 ns/pair`** -> AVX2 **`38.5 ns/pair`** (**2.33× faster**, exact sum verified).
2. **256-byte LUT for `graylevelCompressor > 1`**: `dupesHashStep()` already built `dupesHashLUT[256]` and recorded a **4.4×** decode speedup (`:2419-2426`), yet `decodeFingerprintBytes()` (`:1986`) and `decodeFingerprintChunk()` (`:297`) still call `(unsigned char)floor((double)src[k] / dupesPixScale + 0.5)` 1,024 times per image. Precomputing `unsigned char dupesPixScaleLUT[256]` once in `dupesQueryBegin()`/`dupesScanBegin()`/`decodeFingerprintBlob()` hits full memory bandwidth (`101.2 ms -> 58.3 ms` = **1.74×** on Linux GCC `-O2`, and **4×–8×** on MSVC where `floor()` is a CRT call).

---

## O6. Candidate Query Engine (`dupesQueryStep()` & `buildRowKey()`): Defer `imagesPixels.big` Out of SQLite `ORDER BY` + UTF-8 Parsing

- **Location**: `dupes-search.h:1841-1927, 2113-2190`; `quick-picto-viewer.ahk:89168-89171`.

1. **Do not drag 1 KB `p.big` blobs through SQLite's `ORDER BY` sorter**:
   - Currently, when MSD is on, `dupesCandidateSQL()` selects `..., p.big, k0, k1 ... FROM images LEFT JOIN imagesPixels AS p ... ORDER BY k0, k1, imgmegapix, fsize`.
   - SQLite must copy the 1 KB `p.big` blob into its temporary sort B-tree for **every row in the library** — even the 90–95% of rows that turn out to be singletons and are immediately discarded by `dupesCloseRun()`! On 1,000,000 images, that inflates the sort from **~60 MB** to **~1.1 GB**, forcing temp-sort disk spills or memory pressure.
   - **Fix**: Keep the `ORDER BY` query purely on `images` (no `LEFT JOIN imagesPixels`), and have `dupesQueryStep()` (or `dupesScanBuildFromQuery()` — *after* `keepMask` drops excluded rows too!) point-fetch `SELECT big FROM imagesPixels WHERE imgidu=?1` on `dupesDB` (O(log N) PK lookup on `imagesPixels(imgidu INTEGER PRIMARY KEY)`) **only for surviving multi-image candidates**.
   - **Measured (`opt_bench2`, 100k rows, 5k candidates, all in RAM)**: `307.4 ms -> 171.1 ms` (**1.80×** in RAM; **5×–10×** when avoiding temp-sort disk spill on 500k–1M rows, plus dramatically lower peak RAM).
2. **Avoid unnecessary UTF-8 -> UTF-16 transcoding in SQLite**:
   - SQLite stores strings in UTF-8 by default. Calling `SQ.column_text16()` for pure-ASCII hex hashes (`dHash`, `HdHash`, `:2126, 2131`) and `SQLITE_TEXT` key columns (`buildRowKey`, `:1875`) forces SQLite to allocate and transcode UTF-8 -> UTF-16 on every single row of the library.
   - Binding `sqlite3_column_text` in `sqlite-dynamic.h` lets `parseHexHash()` read raw ASCII bytes zero-copy and lets `buildRowKey()` copy/ASCII-fold UTF-8 directly (ASCII `'A'..'Z'` bytes `0x41..0x5A` never appear inside multi-byte UTF-8 sequences, so UTF-8 ASCII case-folding is byte-for-byte equivalent to UTF-16 ASCII case-folding). Also replace per-char `appendKeyBytes(out, &c, 2)` inside the loop at `:1887` with pre-resized bulk writes.
3. **Skip redundant 1 KB zero-fill in `dupesQueryStep()` (`:2182`)**:
   - `dupesPixData.resize((slot + 1) * stride, 0)` zeroes every 1,024-byte slot immediately before `decodeFingerprintBytes()` overwrites all 1,024 bytes via `memcpy`. (And if a fingerprint is missing, `dupesPixOK[slot] == 0` guarantees `dupesPixData[slot]` is never read anyway.)

---

## O7. Step-Scoped Worker Crew & Parallel Merge (`dupesScanStep()` / `dupesRunPlan()`)

- **Location**: `dupes-search.h:701-895, 1245-1292`.

`dupes-search.h:794-802` explains why a *static* parked thread pool was rejected (`DllMain` / `ExitProcess` crash on joinable static `std::thread`). That constraint does **not** prevent keeping a worker crew alive **within a single `dupesScanStep(msBudget)` call**:

1. **Eliminate per-block OS thread creation/teardown**: Currently `blockTargetMs = msBudget / 8` (`43.75 ms`), so each 350 ms `dupesScanStep()` spawns and joins `N - 1` OS threads **~8–15 times** (and starts `dupesScanBlock` at `65,536`, causing ~6 tiny spawns on `small groups`, where `./sweep_bench` used only `2.51 / 8` cores). On Windows, every `CreateThread` runs `DLL_THREAD_ATTACH` / `DLL_THREAD_DETACH` across every loaded DLL (`opencv_world4140.dll`, `FreeImage.dll`, `pdfium.dll`, `sqlite3.dll`, `gdiplus.dll`), costing far more than Linux `pthread_create`. Spawning the crew once on entry to `dupesScanStep()`, processing items until the `msBudget` deadline (workers check an atomic stop flag or pull from a step-wide plan), and joining before `dupesScanStep()` returns eliminates ~90% of thread-creation overhead with **zero** DLL-unload risk.
2. **Split giant single rows when a row exceeds `blockBudget / nThreads`**: Currently `dupesPlanRows()` never splits a single outer row `r`. On a 500k-row group with MSD/high match density (or on the initial `dupesScanBlock = 65,536` blocks), a single row exceeds `costBudget`, so `nItems == 1` and `dupesRunPlan()` runs **single-threaded** until `dupesScanBlock` doubles many times. Splitting a heavy row `[r+1, rowEnd[r])` into inner-range slices `(r, innerBegin, innerEnd)` ensures full multi-core utilization from block 1.
3. **Parallelize large-block pair-buffer concatenation (`:878-886`)**: On scans yielding millions of pairs (`mixed`: 9.5M pairs = 152 MB), copying `dupesSweepBufs[it.slot]` into `dupesPairsList` currently runs single-threaded on thread 0 while the other cores sit idle. Computing prefix offsets per item and copying in parallel with the already-alive step crew removes that serial tail.

---

## O8. Suggested Implementation Order

1. **Quick, self-contained wins (high ROI, minimal code, zero schema/AHK changes)**:
   - **O2** (`calcPHashAlgo` 8×8 + symmetry + SSE2 + `nth_element` + `dupesHashStep` `uint8_t` buffer): **~20× pHash speedup**, also fixes **S4** (signed shift UB + auto-init `DCTcoeffs`).
   - **O4** (`dupesApplyFilter` integer sort + fused single pass + drop `kept` + fix `order.reserve`): **3.5×+ speedup, 80–95% RAM savings**, also fixes **S2** & **S11**.
   - **O5** (256-byte LUT in `decodeFingerprintBytes`/`Chunk` + AVX2 `msdSumSquares`): **2.3× MSD, 1.7×–4.4× decode**.
   - **Correctness fixes**: **P1–P11** and **S1, S3, S5–S9, S13**.
2. **Massive sweep wins (zero AHK changes, preserves `tests/run-tests.sh` slicing markers)**:
   - **O3** (specialized + pre-masked + 4× unrolled + `maskBits - diff` + runtime AVX2 brute-force kernel): **2.7×–5.0×** on every brute-force sweep.
   - **O1** (MIH pigeonhole bucketing for large groups with skew fallback): **60×–1,500×+** on Preset 1 and typical Custom hash searches.
   - **O7** (step-scoped thread crew inside `dupesScanStep`).
3. **Query engine win (tiny AHK + DLL coordination)**:
   - **O6** (defer `imagesPixels.big` out of `ORDER BY` + UTF-8 `column_text` in `sqlite-dynamic.h`).

> **Note on `QPV DLL source code/tests/run-tests.sh`**: Keep the text-slice anchor comments (`// One record per surviving image pair`, `// qpv-dupes-state-end`, `// qpv-dupes-query-state-end`, `// SWAR population count`, `// qpv-dupes-block-end`, `// qpv-dupes-query-begin`, `// qpv-dupes-query-end`, `// qpv-dct-block-end`) and sliced function signatures at the start of their lines, and keep the mutation-test anchor lines or update `run-tests.sh` in lockstep.

---

## How This Was Checked

- **Baseline DLL benchmarks** (`QPV DLL source code/tests/`):
  - `./msd_bench`: SSE2 `110.9 ns/pair` (`9.0M pairs/s`) vs scalar `294.5 ns/pair`.
  - `./sweep_bench` (8 threads, 350 ms budget): `small` `6 ms` (`2.51` cores), `mixed` `1.060 s` (`1,797 M cmp/s`, `5.78` cores, 9.5M pairs), `huge` (100k rows / 70k group) `1.146 s` (`2,138 M cmp/s`, `6.58` cores, 7.1M pairs), `msd` (200k rows) `0.333 s` (`1,552 M cmp/s`, `6.26` cores).
  - `./hash_bench 100000` (8 threads, batch 512): `dHash` keyset `0.39 s` (`0.06 µs/img`), `lHash` (`0.12 µs/img`), `pHash` `3.90 s` (1 thread) / `1.27 s` (8 threads, `37.34 µs/img`), empty 8-thread crew `0.148 ms`.
- **Bug reproducers** (compiled outside the repo in scratch against verbatim `dupes-pixels.h`, `tests/*_extract.*`, `shim/pixels-env.h`, and `libsqlite3.so.0`): verified P1, P4, S1, S4, S8, and S11 live.
- **Optimization prototypes** (compiled outside the repo with `-O2 -std=c++17 -mavx2 -mfma -mpopcnt -pthread` and `-msse2 -mfpmath=sse -mpopcnt -pthread`): verified O1–O6 timings and 100% byte-for-byte / bit-for-bit output equivalence against the verbatim shipped code.
