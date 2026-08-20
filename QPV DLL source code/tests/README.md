# qpvmain.dll tests

`qpvmain.dll` builds only under MSVC on Windows — WIC, Direct2D, OpenMP, `windows.h` — so a
change to it cannot be checked by building the project on a Linux box or in CI. The parts
that carry the meaning are self-contained, though, so these tests slice the functions under
test straight out of the shipped sources and compile *those* against minimal Windows shims.

Most of the suite covers the duplicate-identification pipeline, which is what it was written
for; `pdf_document.cpp` covers the PDF exporter.

The slicing is the point. A scratch copy of an algorithm drifts from the shipped one and
then proves nothing; `run-tests.sh` re-extracts from `../dupes-search.h` on every run and
fails loudly if an anchor stops matching. The markers it anchors on
(`qpv-dupes-block-end`, `qpv-dupes-query-begin`, `qpv-dupes-state-end`, `qpv-dct-block-end`,
`qpv-job-slot-end` and friends) are comments in the sources; leave them there.

`dupes-search.h` is the whole duplicate-identification pipeline in one file — the sweep,
the grouping, the candidate query engine, hash generation, the DCT, and the records
AutoHotkey reads by byte offset. It used to be the middle third of `qpv-main.cpp`, with
the records in `qpv-main.h`, which is why the anchors are worded the way they are.

## Running

```sh
./run-tests.sh            # correctness
./run-tests.sh --bench    # correctness, then the MSD and duplicate-sweep benchmarks
```

Needs `g++`. `python3` and `libsqlite3.so.0` unlock four more suites; without them those are
skipped rather than failed. Exits non-zero if anything fails.

## What is covered

**`msd_oracle.cpp`** — the shipped `msdScore()` / `decodeFingerprintBlob()` against a
reimplementation of the AHK they replaced (`calcMSDvalues()` and
`processPixArrayCharsAsSTR()`). ~3 600 randomised fingerprint pairs per seed across all nine
`graylevelCompressor` levels, over five distributions, plus explicit boundary cases. Every
value must match exactly — MSD scores are compared against user thresholds that were
calibrated on the old numbers.

Three details that are easy to get wrong and that this pins down:

- AHK's `Round()` is **half away from zero**, so the port uses `floor(x + 0.5)`, not `rint()`.
- `calcMSDvalues()` divided by `size/2`, not `size`. That looks like a typo and is not: it is
  the scale every stored `userFindDupesMSElvl` is calibrated against.
- `discretizeValue(255, 2)` is **256** and does not fit a byte. The MSD path stores the
  quotient `Round(v/L)` and multiplies the factor back in `msdScore()`, which is exact
  because every difference simply scales by L. Clamping to 255 instead would shift results at
  compressor ≥ 2 — the oracle's reference is deliberately left unclamped so that mistake
  cannot pass.

**The mutation check** — `run-tests.sh` deliberately breaks the sliced `msdScore()` (drops the
gray-scale factor) and requires the oracle to *fail*. An oracle that passes a known-wrong
implementation is worse than no oracle, so this runs on every invocation.

**`sweep_smoke.cpp`** — compiles the whole block from `popcount64()` through the whole-scan
cursor under `-Wall -fopenmp`, so a syntax or type error surfaces here rather than on the
MSVC box, and then exercises the result contract: the fetch drains exactly what the sweep
counted, every pair is under the threshold, a record with no fingerprint scores
`QPV_MSD_NONE` rather than 0 (0 would read as a *perfect* match), MSD-off leaves every score
at the sentinel, and the crop mask never empties out.

The load-bearing test is `scanMatchesPerGroupSweep()`. `dupesScanStep()` walks the whole
candidate set from one entry point under a time budget, with an adaptive block size and a
cursor that is a plain candidate-row index; the only thing keeping that arithmetic honest is
that it must produce, **byte for byte**, what the simple one-group-per-call
`dupesSweepPairs()` produces. That is why `dupesSweepPairs()` is still exported even though
AHK no longer calls it.

Two more stages belong to the parallel sweep, which fans a block of candidate rows out
across every core:

- `scanIsThreadCountIndependent()` sweeps one candidate set with teams of 1, 2, 3, 5 and 8
  and requires all five to be byte-identical to the per-group reference — and checks that
  more than one thread really did collect pairs, so the comparison is not vacuous. Each item
  of a block collects into a buffer of its own and the buffers are concatenated in
  **planning** order, never in the order the threads finished; the grouping downstream is
  order-dependent by design, so an output that depended on the team size would label the
  same images into different groups on different machines.
- `sweepReallocatesRarely()` counts how often `dupesPairsList` changes capacity across 1 500
  appends. `reserve()` honours its request *exactly*, so the `reserve(size() + found)` this
  replaced re-allocated and copied the whole accumulated list on every batch — quadratic in
  the number of pairs, and by a wide margin the most expensive thing the sweep did: 160
  seconds of copying against 1.2 seconds of comparing hashes, on a candidate set that yields
  seven million pairs. Nothing about the *result* changes when that comes back, which is why
  the capacity is what gets watched.

`run-tests.sh` also builds `sweep_smoke.cpp` **without** `-fopenmp` and runs the same suite:
everything degrades to a one-thread sweep when the macro is absent, which is also what a
single-core machine gets, and the answer has to be the same one.

**The sweep mutation checks** — two plausible versions of the code that break exactly those
two properties and nothing else: concatenating the items in whatever order suits the loop
rather than in planning order, and going back to an exact `reserve()` per batch.

**`filter_oracle.cpp`** — `dupesApplyFilter()` against a transcription of
`changeHdistLevelCached()` and `sortDupeGroups()`. This is where a difference is invisible:
nothing crashes, the duplicates are simply grouped or ordered slightly differently. Both
modes are fuzzed — the union path (smallest image index always the root, so the grouping
cannot depend on pair arrival order) and the `BreakDupesGroups=1` incremental path, which
deliberately re-labels a group by the distance of the pair being walked and *is* order
dependent.

**`hash_oracle.cpp`** — dHash, lHash and pHash against a transcription of
`generateSQLimageFingerPrintHash()`, `calcLhashAlgo()` and `calcDLLpHashAlgo()`, across every
compressor level and all three pHash compare modes. The stakes are the highest here: every
hash already in every user's database was computed the old way, so a one-bit difference is
not a wrong answer, it is a *different* answer. Two traps it pins:

- `discretizeValue()` returns `Round(v/L)*L` — the **product**, unlike the MSD path — and
  `calcDLLpHashAlgo()` wrote those through `NumPut(..., "UChar")`, so a 256 became 0.
- `lHash` compares each pixel against the exact float mean, never a rounded one; rounding
  first creates ties between the pixel and its threshold.

**`pixels_smoke.cpp`** — `dupes-pixels.h`, the parallel fingerprint / histogram collector,
compiled **verbatim** against `shim/pixels-env.h`. In the real build that header is
`#include`d into `qpv-main.cpp` after gdiplus, wincodec, OpenMP and `thumbs-pool.h`; none of
those exist here, so the shim stands in for the pieces the collector actually touches. That
is the only chance to catch a type error in it before the MSVC box sees it, and the checks
around the compile cover everything that is not an image decoder:

- **the histogram statistics** against a transcription of `calcHistoAvgFile()`, over five
  histogram shapes so the median, mode and rarest-level branches all get walked. Those
  eight numbers are stored, `Round()`ed and then GROUPed on by the duplicate finder, so a
  difference in the last decimal changes which images are called duplicates.
- **the blue-channel dump**, at the right stride, and `RotateNoneFlipX` mirroring each row.
  The flipped fingerprint is taken from a flipped *bitmap* rather than by reversing the
  unflipped fingerprint, because no resampler that samples at fixed offsets is
  mirror-equivariant — the test says so where it is exact and only where it is exact.
- **one job**: the loader chain, in the order `tpRunJob()` runs it — SVG and PDF to the two
  renderers of their own and to nothing else, then FreeImage for the extensions it claims,
  then WIC for the ones it declares, then GDI+ for everything left over, including whatever
  the loader that did claim the file could not open. A missing file is marked rather than
  handed to a decoder, a file every loader refuses is a decode failure, and the blur is
  applied as the two passes `Gdip_GaussianBlur()` applied. Which loader a file reaches
  decides what its fingerprints are measured on, so this is where a reordering shows up.
- **the properties of the original file** — `imgwidth`, `imgheight`, `imgframes`, `imgdpi`
  and `imgpixfmt` — taken before anything is scaled or converted, and named with the tables
  the interpreter sends through `qpvSetPixelFormatNames()`. The stubbed loaders report a
  source larger than the bitmap they return, so a value read off the 350 pixel intermediate
  instead of the file cannot pass. A WIC attempt that fails and falls through to FreeImage
  must leave nothing of itself in the record either, or the database is told a `.psd` is
  whatever WIC thought before it gave up.
- **`qpvGetPixelFormatName()`**, which is the same naming handed to the *thumbnails* pool
  so that one file gets one spelling however it was decoded. A cached thumbnail file must
  answer nothing at all, and a short buffer must truncate rather than spill.
- **a whole collection run against a real SQLite database**: 3000 rows, three worker
  threads, a 1 ms budget. It asserts that the step loop yields and is re-entered, that every
  readable image is written exactly once, that unreadable ones are marked `isDeleted=1`
  instead of being retried, and that a second pass finds nothing left — which is the
  resumability the collect-data dialog promises, and the property a bare `LIMIT` cursor
  would have broken. An image is handed to a worker and written *later*, so it still
  matches the query while it is being decoded; `dpTopUpQueue()` therefore walks a keyset
  cursor on `imgidu` rather than re-running a plain `LIMIT`.

- **the files only GDI+ reads** — EMF, WMF and the GIFs FreeImage refuses. They reach the
  third loader and are collected; before it existed they reached no decoder at all and the
  collection marked them `isDeleted=1`, which hides an image from the whole library until
  the caches overview revalidates it. The same test covers the `COALESCE` in the UPDATE: a
  loader that cannot name a pixel format — PDFium, GDI+ — must leave `imgpixfmt` as it
  found it, because "collected, and the format is blank" and "never collected" are the same
  thing to `ifnull(imgpixfmt,'')=''` and the single threaded pass would then re-decode those
  files on every run, for ever.

- **a run on a machine that is short of memory**, six workers, driven against a wall clock.
  Decoding then narrows to one image at a time (see `throttle_slots.cpp` below) and the
  point of narrowing rather than stopping is that the run still ends by itself, with every
  readable image collected. `shim/pixels-env.h` drives `tpMemoryIsTight()` for it, since
  nothing else here can make the machine short of memory on demand. The deadline is what
  turns the failure this pins down into a failed check instead of a hung test.

Two mutation checks for it, both applied to a **copy** of the header so an interrupted run
cannot leave the shipped source broken. **A** drops the `- 1` from the mean, which is the one
term that looks like an off-by-one and is not. **B** restores the memory throttle the pool
shipped with: a worker waiting on `dpState.inFlight`, a count raised when the job leaves the
queue and therefore including the waiter itself. With every worker holding an image it never
fell back to 1, no decode ever started, `dupesPixStep()` never reported the pool idle, and
`collectImgDataViaPool()` sat on `0 / N ( 0% )` in front of the user for as long as they let
it. It only bites while memory is tight, which is how it got past every other test here.

**`throttle_slots.cpp`** — the decode throttle both pools share, sliced out of the shipped
`thumbs-pool.h`: the thresholds, `tpMemoryIsTight()`, `tpTryTakeJobSlot()`,
`tpTryTakeJobSlotNow()`, `tpReleaseJobSlot()`, `TpJobSlot` and `tpWaitForJobSlot()`, which
both pools wait in (`dpAcquireJobSlot()` in `dupes-pixels.h` is the collection pool's, with a
wider predicate). One count for the whole DLL is deliberate: `QPV_ShowThumbnails()` is
reached from a timer and lists a page *while* a collection run is in progress, so both pools
decode at the same time, and a counter per pool would let each believe it is alone.

The memory readings and the clock are the test's own, which is what makes any of this
testable at all: `GlobalMemoryStatusEx()` and `GetTickCount64()` are shimmed, so a test can
say what the machine reports and move time forward itself, and a frozen clock keeps the
memory state from changing under the threaded tests. Five properties:

- at most one decode at a time while memory is short, twelve threads taking forty images
  each through the single slot, and a waiter always let through afterwards;
- the throttle is entered and left at **different** readings. Most of the pressure is its
  own doing — the decodes it throttles are what put the machine over the line — so one set
  of thresholds lifts it the moment it has worked, and puts the machine straight back over;
- and it is lifted one decode per reading rather than all at once, for the same reason;
- what turns it on: the percentage, the free physical memory, the commit headroom, and the
  address space left to *this process*, which is the wall the 32 bits build hits while
  `GlobalMemoryStatusEx()` still reports gigabytes free;
- neither pool can lock the other out. A worker that has just released a slot asks for
  another one microseconds later while everybody else is asleep, so it wins any race decided
  by who asks first — the count or the mutex, it makes no difference. Slots are handed out
  in the order the workers queued for them instead.

Four mutation checks, one per property that has a single line to get wrong: a second decode
allowed while the machine is short, the throttle lifted at the reading that turned it on, the
full worker count restored in one step, and arrivals allowed to barge past the queue.

**`gdip_loader.cpp`** — `tpGDIPload()`, the third loader of the product, sliced out of the
shipped `thumbs-pool.h` together with `tpCalcIMGdimensions()` and compiled against
`shim/gdip-env.h`. It exists because EMF and WMF have neither a FreeImage plugin nor a WIC
codec, and a GIF that FreeImage refuses and WIC cannot decode is still drawn in the viewport
by `LoadFileWithGDIp()`; until it was written, both pools ran out of loaders on those files.

The shim maps `__try`/`__except` onto a dead branch rather than dropping them, so both blocks
and the filter expression are type-checked — nothing else here ever puts that code in front
of a compiler. Beyond the compile it pins the two rules a reader cannot see by looking at the
function: the bitmap handed back is a **copy** and the file-backed original is disposed
(`GdipCreateBitmapFromFile()` keeps the file mapped for as long as its bitmap lives — what
`GDIbmpFileConnected` tracks in the AHK — and the copy is also what turns the 8bpp indexed
bitmap a GIF decodes into into the 32bpp one the effects and the histogram need), and the
frame is selected *before* the size is read, because the frames of an animated GIF need not
all be the size of the first. The mutation check hands the file-backed bitmap straight back.

**`thumbs_record.cpp`** — the layout of `ThumbResult` and `ThumbsPoolState`, sliced out of
the shipped `thumbs-pool.h`. Nothing else pins them: `thumbsPoolFetch()` fills an array of
records and `QPV_ThumbsPoolDrain()` / `poolRecordImgProps()` / `QPV_ThumbsPoolPending()`
walk it with a stride and byte offsets written out by hand in the AHK. A field inserted in
the middle of `ThumbResult` compiles perfectly and then hands AutoHotkey a GDI+ bitmap
pointer read out of the middle of the next record. Every offset asserted here appears as a
literal in `quick-picto-viewer.ahk`; when this test fails, the AHK is what has to change —
and `initThumbsPool()` refuses a `qpvmain.dll` that predates the current record, because a
version mismatch is the same corruption from the other side.

**`pdf_document.cpp`** — the PDF exporter's page geometry and document structure. This one
does not slice: `Jpeg2PDF.cpp` is `#include`d into `qpv-main.cpp` rather than compiled on its
own and needs nothing from `windows.h` beyond `UINT32`, `IDOK` and `ERROR`, so the whole
shipped file is compiled **verbatim** — no anchors, nothing to drift.

What it pins is a unit that is invisible in the output. `MediaBox` is written in PDF user
space units, which the spec fixes at 1/72 inch, but the file emits bare integers — so when
`Jpeg2PDF_BeginDocument()` scaled the page by the DPI the pages were *rasterised* at, every
exported page came out `(dpi/72)` times too large and nothing looked wrong: a Letter page
measured 22.7 × 29.3 in at the high quality setting, while the layout stayed correct because
the image placement matrix is driven by the same two fields. Only a reader's page properties
showed it. Hence the checks that Letter, A4 and landscape land on their canonical point
sizes, that the placement matrix agrees with `MediaBox`, and that the render DPI still comes
out as the printed resolution via the embedded JPEG's own pixel count.

Two more things it guards:

- A4 is 8.27 × 11.69 in, so its height is 841.68 pt. The cast to `UINT32` truncates, which
  gives a page one point short of the canonical 842 — the rounding is deliberate.
- the xref offsets are accumulated by hand from `sprintf` return values, and the fix changed
  the page size's digit count. The test walks the table the way a reader does and requires
  every offset to land on its own object.

**The mutation check** — `run-tests.sh` restores both bugs in *copies* of the shipped sources
(the DPI-scaled page box, and the truncating cast) and requires the test to fail. The
`QPV_JPEG2PDF_HEADER` / `QPV_JPEG2PDF_SOURCE` defines exist for that; they default to the
shipped files.

**`import_merge.py`** — the database import, executed by SQLite rather than simulated.
`importSLDBintoSLDB()` renumbers every `imgidu`, so fingerprints keyed by it have to be
re-keyed: the old side table is set aside, the imported database is `ATTACH`ed, and one
`INSERT ... SELECT` with a `COALESCE` per column puts them back. The `COALESCE` is what
makes a file present in **both** databases take the imported fingerprint where it has one
and keep the existing one where it does not — the same rule the merge applies to every
other column. That branch could not fire until 2026-08-10: such a file used to get a second
plan slot, so the merge looked its main row up at an index nothing had filled, wrote the
imported record alone, and had it rejected by `UNIQUE (fullPath)`. This test is what says
that is over.

**`sql_grouping.py`** — the ordered-scan grouping against the self-join it replaced, over
every column set the Find Duplicates panel can build and four precisions, on a synthetic
database with the real `images` schema. `keyEquals()` in it is the specification the C++
`buildRowKey()` implements. It is what turned up the two rules that are easy to miss:

- a row with a **NULL in any grouping column is not a candidate**. The old `ON` clause was a
  chain of `=`, and `NULL = NULL` is NULL rather than true, so no row ever joined to the NULL
  bucket `GROUP BY` had made. Keeping those rows invents enormous phantom groups of
  everything that shares a missing property.
- `imgfile` and `imgpixfmt` are declared `COLLATE NOCASE`, so both the `GROUP BY` and the
  `ORDER BY` fold ASCII case and the key builder has to fold it too.

**`query_engine.cpp`** — the whole candidate-query engine against a *real* SQLite database
(`make_test_db.py` builds one with the real schema). `sqlite-dynamic.h` binds sqlite3 by name
at run time, so `tests/shim/windows.h` points `LoadLibraryW` at `dlopen("libsqlite3.so.0")`
and the shipped engine runs against the genuine article — nothing about it is mocked, only
the loader underneath. Covers the grouping equivalence again (this time through the actual
C++), the row/path/fingerprint/hash round trip through the `imagesPixels` join, the
keep-mask recut, cancellation, and the hash-generation loop end to end: the values land on
the right rows and the batch loop terminates, which it only does because updated rows drop
out of its own `SELECT`.

`wchar_t` is 4 bytes here and 2 on Windows, while sqlite3's `*16` entry points always speak
2-byte UTF-16 — on Windows those coincide, which is exactly why the engine can read
`sqlite3_column_text16()` straight into a `const wchar_t*`. The shim's `GetProcAddress`
returns adapters for the five `*16` functions so the difference stays in the loader.

**`msd_bench.cpp`** — times the SSE2 MSD against a scalar loop. Order of magnitude only:
GCC's inliner is not MSVC's, and this says nothing about the AHK interpreter the port
replaced.

**`sweep_bench.cpp`** — drives `dupesScanStep()` over library-sized candidate sets exactly
the way AHK does, and reports comparisons per second along with how many cores the sweep
actually used (wall time against process CPU time). The three shapes are the ones a real
library produces: hundreds of thousands of groups of two or three (grouping by file size and
megapixels), one group holding most of the library (grouping by aspect ratio and frame
count, which is the fallback the Find Duplicates panel drops to), and a long tail of sizes.
Built with `-mpopcnt` on purpose — the shipped DLL uses the POPCNT instruction whenever
CPUID reports it, and without the flag gcc expands `__builtin_popcountll()` into a libgcc
call no shipped build ever executes. The correctness tests stay on the plain SSE2 baseline.

## Conventions

Built with `-O2 -std=c++17 -msse2 -mfpmath=sse` to match the project's x64/SSE2 baseline
(`EnableEnhancedInstructionSet=SSE2` in `qpv-main.vcxproj`, which is why `popcount64()` is
SWAR rather than a POPCNT intrinsic).

`min`/`max` are `windows.h` macros in the real build but `std::` templates under g++ —
equivalent for same-typed arguments, worth remembering if a future test pulls in code that
uses them. `LONG` is typedef'd to `int`, because Windows' `LONG` is 32-bit and `long` here is
not; the `DupesScanState` byte offsets AHK reads depend on it.

Generated extracts, the test database and the binaries are git-ignored; only the harness
sources are tracked.
