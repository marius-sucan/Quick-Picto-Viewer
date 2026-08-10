# Duplicate-identification tests

`qpvmain.dll` builds only under MSVC on Windows — WIC, Direct2D, OpenMP, `windows.h` — so a
change to the duplicate-identification pipeline cannot be checked by building the project on
a Linux box or in CI. The parts that carry the meaning are self-contained, though, so these
tests slice the functions under test straight out of the shipped sources and compile *those*
against minimal Windows shims.

The slicing is the point. A scratch copy of an algorithm drifts from the shipped one and
then proves nothing; `run-tests.sh` re-extracts from `../qpv-main.cpp` and `../qpv-main.h`
on every run and fails loudly if an anchor stops matching. The markers it anchors on
(`qpv-dupes-block-end`, `qpv-dupes-query-begin`, `qpv-dupes-state-end`, `qpv-dct-block-end`
and friends) are comments in the sources; leave them there.

## Running

```sh
./run-tests.sh            # correctness
./run-tests.sh --bench    # correctness, then the MSD benchmark
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

The load-bearing test is `scanMatchesPerGroupSweep()`. `dupesScanStep()` walks every group
from one entry point under a time budget, with an adaptive block size and a cursor over
(group, outer index); the only thing keeping that arithmetic honest is that it must produce,
**byte for byte**, what the simple one-group-per-call `dupesSweepPairs()` produces. That is
why `dupesSweepPairs()` is still exported even though AHK no longer calls it.

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
- **one job**: WIC first, FreeImage for the formats WIC does not declare *and* whenever WIC
  fails, a missing file marked rather than handed to a decoder, and the blur applied as the
  two passes `Gdip_GaussianBlur()` applied.
- **the properties of the original file** — `imgwidth`, `imgheight`, `imgframes`, `imgdpi`
  and `imgpixfmt` — taken before anything is scaled or converted, and named with the tables
  the interpreter sends through `dupesPixSetFormatNames()`. The stubbed loaders report a
  source larger than the bitmap they return, so a value read off the 350 pixel intermediate
  instead of the file cannot pass. A WIC attempt that fails and falls through to FreeImage
  must leave nothing of itself in the record either, or the database is told a `.psd` is
  whatever WIC thought before it gave up.
- **a whole collection run against a real SQLite database**: 3000 rows, three worker
  threads, a 1 ms budget. It asserts that the step loop yields and is re-entered, that every
  readable image is written exactly once, that unreadable ones are marked `isDeleted=1`
  instead of being retried, and that a second pass finds nothing left — which is the
  resumability the collect-data dialog promises, and the property a bare `LIMIT` cursor
  would have broken. An image is handed to a worker and written *later*, so it still
  matches the query while it is being decoded; `dpTopUpQueue()` therefore walks a keyset
  cursor on `imgidu` rather than re-running a plain `LIMIT`.

The mutation check for it drops the `- 1` from the mean, which is the one term that looks
like an off-by-one and is not. It is applied to a **copy** of the header, so an interrupted
run cannot leave the shipped source broken.

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
