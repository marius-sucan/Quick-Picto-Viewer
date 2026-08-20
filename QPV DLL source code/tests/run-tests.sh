#!/usr/bin/env bash
# Verifies the duplicate-search maths in dupes-search.h on a machine that cannot build
# the DLL (no MSVC, no WIC, no Direct2D). The functions under test are TEXT-SLICED out
# of the shipped sources on every run, so what is tested is what actually ships rather
# than a scratch copy that can drift.
#
# Flags match the project's x64/SSE2 baseline (EnableEnhancedInstructionSet=SSE2).
# GCC's inliner is not MSVC's - these tests are for correctness; treat the benchmark as
# an order of magnitude, not as a prediction of the shipped DLL.
#
# Usage:  ./run-tests.sh            correctness only
#         ./run-tests.sh --bench    also run the MSD benchmark
#
# written by Marius Șucan with Claude Opus 5

set -u
cd "$(dirname "$0")" || exit 1

CXXFLAGS="-O2 -std=c++17 -msse2 -mfpmath=sse -Wall"
# One file now: the pipeline, the records AHK reads by byte offset and the DCT all moved
# out of qpv-main.cpp/.h into dupes-search.h, so every slice below comes from the same
# place. thumbs-pool.h is named inline by the one slice that needs it.
SRC="../dupes-search.h"
fail=0

for f in "$SRC"; do
    [ -r "$f" ] || { echo "cannot read $f - run this from inside the tests directory"; exit 1; }
done

# slice <output> <source> <awk-start-regex> <awk-end-regex> <min-lines>
# Fails loudly when an anchor stops matching: an empty or truncated slice would other-
# wise compile into a test that silently proves nothing.
slice() {
    local out=$1 src=$2 from=$3 to=$4 minlines=$5
    sed -n "/$from/,/$to/p" "$src" > "$out"
    local n; n=$(wc -l < "$out")
    if [ "$n" -lt "$minlines" ]; then
        echo "  ERROR: slicing '$from' out of $src gave $n lines (expected >= $minlines)."
        echo "         The anchor no longer matches - update run-tests.sh."
        fail=1
        return 1
    fi
    return 0
}

echo "== slicing the shipped sources =="
slice msd_extract.cpp    "$SRC" '^QPV_FORCEINLINE INT64 msdSumSquares' '^}' 20 || exit 1
slice msd_score.part     "$SRC" '^QPV_FORCEINLINE int msdScore'        '^}' 3  || exit 1
cat msd_score.part >> msd_extract.cpp && rm -f msd_score.part
slice decode_extract.cpp "$SRC" '^static void decodeFingerprintChunk'  '^}' 20 || exit 1
slice decode_blob.part   "$SRC" '^static void decodeFingerprintBlob'   '^}' 5  || exit 1
cat decode_blob.part >> decode_extract.cpp && rm -f decode_blob.part
slice header_extract.h   "$SRC" '^\/\/ One record per surviving image pair' '^\/\/ qpv-dupes-query-state-end' 55 || exit 1
slice block_extract.cpp  "$SRC" '^\/\/ SWAR population count'          '^\/\/ qpv-dupes-block-end' 450 || exit 1
slice query_extract.cpp  "$SRC" '^\/\/ qpv-dupes-query-begin'          '^\/\/ qpv-dupes-query-end' 350 || exit 1
slice dct_extract.cpp    "$SRC" '^double calcArrayAvgMedian'          '^\/\/ qpv-dct-block-end' 100 || exit 1
slice thumbs_structs.part ../thumbs-pool.h '^#pragma pack(push, 8)'  '^#pragma pack(pop)' 40 || exit 1
slice mem_limits.part     ../thumbs-pool.h '^\/\/ Memory pressure'   '^#define TP_SLOT_POLL_MS' 20 || exit 1
slice mem_sample.part     ../thumbs-pool.h '^\/\/ qpv-mem-sample-begin' '^\/\/ qpv-mem-sample-end' 30 || exit 1
slice slots_extract.part  ../thumbs-pool.h '^\/\/ One attempt at taking a slot' '^\/\/ qpv-job-slot-end' 40 || exit 1
slice calc_dims.part      ../thumbs-pool.h '^\/\/ qpv-calc-dims-begin'   '^\/\/ qpv-calc-dims-end' 30 || exit 1
slice gdip_loader.part    ../thumbs-pool.h '^\/\/ qpv-gdip-loader-begin' '^\/\/ qpv-gdip-loader-end' 120 || exit 1
echo "   ok"

echo
echo "== MSD oracle: the shipped port vs the AHK it replaced =="
if g++ $CXXFLAGS -o msd_oracle msd_oracle.cpp 2>&1; then
    for seed in 1 7 999 20260807 4242424; do
        ./msd_oracle $seed | tail -1
        [ "${PIPESTATUS[0]}" = "0" ] || fail=1
    done
else
    echo "  ERROR: msd_oracle.cpp did not compile"; fail=1
fi

echo
echo "== mutation check: the oracle must reject wrong maths =="
# Drops the graylevelCompressor factor msdScore() folds back in. If this still passes,
# the oracle is not actually testing anything and every result above is worthless.
cp msd_extract.cpp msd_extract.orig
sed -i 's|msdSumSquares(a, b, count) \* (INT64)scale \* (INT64)scale|msdSumSquares(a, b, count)|' msd_extract.cpp
if ! cmp -s msd_extract.cpp msd_extract.orig; then
    g++ $CXXFLAGS -o msd_mutant msd_oracle.cpp 2>/dev/null
    if ./msd_mutant 20260807 > /dev/null 2>&1; then
        echo "  ERROR: the mutant passed - the oracle proves nothing"; fail=1
    else
        echo "   ok - the mutant is caught"
    fi
    rm -f msd_mutant
else
    echo "  ERROR: the mutation did not apply - update the sed pattern"; fail=1
fi
mv msd_extract.orig msd_extract.cpp

echo
echo "== sweep: compiles under -Wall -fopenmp, and the result contract holds =="
if g++ $CXXFLAGS -fopenmp -o sweep_smoke sweep_smoke.cpp 2>&1; then
    ./sweep_smoke || fail=1
else
    echo "  ERROR: sweep_smoke.cpp did not compile"; fail=1
fi

echo
echo "== and without OpenMP at all: the sweep must still build and agree =="
# The whole thing degrades to a one-thread sweep when the macro is absent, and the result
# has to be the same one. A team of one is also what a machine with a single core gets.
if g++ $CXXFLAGS -Wno-unknown-pragmas -o sweep_serial sweep_smoke.cpp 2>&1; then
    ./sweep_serial > /dev/null && echo "   ok - the serial build passes the same suite" || { ./sweep_serial | tail -20; fail=1; }
else
    echo "  ERROR: sweep_smoke.cpp did not compile without -fopenmp"; fail=1
fi
rm -f sweep_serial

echo
echo "== mutation checks: the parallel sweep must reject each way of getting it wrong =="
# Both mutations go into the SLICE, never into the shipped header. Each is a plausible
# version of the code, and each breaks one of the two properties the sweep rests on that
# no ordinary result check would notice.
#
# sweepMutant <sed-expression> <what it breaks>
sweepMutant() {
    local expr=$1 what=$2
    cp block_extract.cpp block_extract.orig
    sed -i "$expr" block_extract.cpp
    if cmp -s block_extract.cpp block_extract.orig; then
        echo "  ERROR: the mutation did not apply [$what] - update the sed pattern"; fail=1
        mv -f block_extract.orig block_extract.cpp
        return 1
    fi

    if ! g++ $CXXFLAGS -fopenmp -o sweep_mutant sweep_smoke.cpp 2>/dev/null; then
        echo "  ERROR: the mutant did not compile [$what] - the mutation is malformed"; fail=1
    elif ./sweep_mutant > /dev/null 2>&1; then
        echo "  ERROR: the mutant passed [$what] - that property is not being tested"; fail=1
    else
        echo "   ok - caught: $what"
    fi

    rm -f sweep_mutant
    mv -f block_extract.orig block_extract.cpp
}

# The items are concatenated in whatever order suits the loop rather than in planning
# order. It still finds every pair; it just hands them back in an order that depends on
# how the work was cut up, and the grouping downstream is order-dependent by design.
sweepMutant 's|^           for ( int i = 0 ; i < nItems ; i++)$|           for ( int i = nItems - 1 ; i >= 0 ; i--)|' \
    "the pairs are concatenated in item order no longer"
# reserve() asked for exactly what is needed, which is what the sweep used to do: correct,
# and quadratic in the number of pairs.
sweepMutant 's|    dupesPairsList.reserve(cap);|    dupesPairsList.reserve(need);|' \
    "the pair list re-allocated once per batch instead of geometrically"

echo
echo "== threshold filter and grouping vs the AHK they replaced =="
if g++ $CXXFLAGS -fopenmp -o filter_oracle filter_oracle.cpp 2>&1; then
    ./filter_oracle || fail=1
else
    echo "  ERROR: filter_oracle.cpp did not compile"; fail=1
fi

echo
echo "== perceptual hashes vs the AHK that computed them =="
if g++ $CXXFLAGS -Wno-sign-compare -Ishim -fopenmp -o hash_oracle hash_oracle.cpp -ldl 2>&1; then
    ./hash_oracle || fail=1
else
    echo "  ERROR: hash_oracle.cpp did not compile"; fail=1
fi

echo
echo "== fingerprint collector: compiles, and its statistics match the AHK =="
# dupes-pixels.h is #included into qpv-main.cpp after gdiplus, wincodec and thumbs-pool.h.
# shim/pixels-env.h stands in for all of that, so the collector is compiled VERBATIM here
# rather than transcribed - which is the only chance to catch a type error in it before the
# MSVC box sees it.
if g++ $CXXFLAGS -Wno-sign-compare -Ishim -o pixels_smoke pixels_smoke.cpp -ldl -lpthread 2>&1; then
    ./pixels_smoke || fail=1
else
    echo "  ERROR: pixels_smoke.cpp did not compile"; fail=1
fi

echo
echo "== the decode throttle both worker pools share =="
# One slot while the machine is short of memory, and a waiter that is always let through
# afterwards. Both pools stop dead without the second property, and the collection pool did.
if g++ $CXXFLAGS -pthread -o throttle_slots throttle_slots.cpp 2>&1; then
    ./throttle_slots || fail=1
else
    echo "  ERROR: throttle_slots.cpp did not compile"; fail=1
fi

echo
echo "== mutation checks: the throttle test must reject each way of getting this wrong =="
# Every mutation goes into the SLICE, never into the shipped header, and each one is a
# plausible version of the code that the test has to notice. One that still passes means
# the property it stands for is not actually being tested.
#
# throttleMutant <part-file> <sed-expression> <what it breaks>
throttleMutant() {
    local part=$1 expr=$2 what=$3
    cp "$part" "$part.orig"
    sed -i "$expr" "$part"
    if cmp -s "$part" "$part.orig"; then
        echo "  ERROR: the mutation did not apply [$what] - update the sed pattern"; fail=1
        mv -f "$part.orig" "$part"
        return 1
    fi

    if ! g++ $CXXFLAGS -pthread -o throttle_mutant throttle_slots.cpp 2>/dev/null; then
        echo "  ERROR: the mutant did not compile [$what] - the mutation is malformed"; fail=1
    elif ./throttle_mutant > /dev/null 2>&1; then
        echo "  ERROR: the mutant passed [$what] - that property is not being tested"; fail=1
    else
        echo "   ok - caught: $what"
    fi

    rm -f throttle_mutant
    mv -f "$part.orig" "$part"
}

# two decodes at once under memory pressure, which is the state this exists to prevent
throttleMutant slots_extract.part 's|if (active>=cap)|if (active>=cap + 1)|' \
    "a second decode allowed while the machine is short of memory"
# the throttle lifted at the same reading that turned it on - the flapping this used to do
throttleMutant mem_sample.part 's|ms.dwMemoryLoad    <= TP_MEM_LOAD_LOW|ms.dwMemoryLoad    < TP_MEM_LOAD_HIGH|' \
    "no hysteresis: the throttle lifted at the reading that turned it on"
# every waiting worker let through on the first good reading, all starting a decoder at once
throttleMutant mem_sample.part 's|tpSlotCap.store(cap + 1, std::memory_order_release);|tpSlotCap.store(TP_SLOT_CAP_MAX, std::memory_order_release);|' \
    "the full worker count restored in one step instead of one decode per reading"
# and the fairness: a worker that just released a slot walking straight back into it
throttleMutant slots_extract.part 's|return tpSlotWaiters.load(std::memory_order_acquire)==0 \&\& tpTryTakeJobSlot();|return tpTryTakeJobSlot();|' \
    "arrivals allowed to barge past the workers already queued"

echo
echo "== the GDI+ loader of the two worker pools =="
# The third loader of the product: EMF, WMF and the GIFs FreeImage refuses and WIC cannot
# decode. thumbs-pool.h never reaches a compiler on this box, so this is the only thing that
# type-checks it before MSVC does - and it pins the two rules a reader cannot see: the file
# backed bitmap is disposed [it holds a lock on the file] and the frame is selected before
# the size is read.
if g++ $CXXFLAGS -o gdip_loader gdip_loader.cpp 2>&1; then
    ./gdip_loader || fail=1
else
    echo "  ERROR: gdip_loader.cpp did not compile"; fail=1
fi

echo
echo "== mutation check: the GDI+ loader must hand back a copy, not the file =="
# Returns the file-backed bitmap itself. It looks like an optimisation - one allocation
# fewer - and it leaves every file the loader ever touched locked for as long as the
# thumbnail lives, which is what GDIbmpFileConnected exists to avoid in the AHK.
cp gdip_loader.part gdip_loader.orig
sed -i 's|    Gdiplus::GpBitmap \*out = tpGdipResizeCopy(loaded, outW, outH, interpolation);|    Gdiplus::GpBitmap *out = loaded;|' gdip_loader.part
if ! cmp -s gdip_loader.part gdip_loader.orig; then
    g++ $CXXFLAGS -o gdip_mutant gdip_loader.cpp 2>/dev/null
    if ./gdip_mutant > /dev/null 2>&1; then
        echo "  ERROR: the mutant passed - the test proves nothing"; fail=1
    else
        echo "   ok - the mutant is caught (the file-backed bitmap is handed straight back)"
    fi
    rm -f gdip_mutant
else
    echo "  ERROR: the mutation did not apply - update the sed pattern"; fail=1
fi
mv -f gdip_loader.orig gdip_loader.part

echo
echo "== the records the thumbnails pool shares with AutoHotkey =="
# Nothing else pins these: the AHK walks thumbsPoolFetch()'s array with a stride and byte
# offsets it writes out by hand, so a field inserted in ThumbResult compiles and then hands
# AHK a bitmap pointer read out of the middle of another record.
if g++ $CXXFLAGS -o thumbs_record thumbs_record.cpp 2>&1; then
    ./thumbs_record || fail=1
else
    echo "  ERROR: thumbs_record.cpp did not compile"; fail=1
fi

echo
echo "== mutation check: the collector must reject wrong maths and a wedged pool =="
# Both mutants go into a COPY - the shipped header is never edited, so an interrupted run
# cannot leave it broken.
#   A - drops the "- 1" from the mean, which is the one term that looks like an off-by-one
#       and is not: sumTotalBr accumulates (level + 1) so the /256 maps level 255 to
#       exactly 1.0;
#   B - restores the memory throttle the pool shipped with, which waited on a count that
#       included the waiting worker itself. It bites only while memory is tight, which is
#       why it survived every other test in the file: with every worker holding a job,
#       dpState.inFlight never falls back to 1, no decode ever starts, dupesPixStep() never
#       reports the pool idle, and collectImgDataViaPool() sits on "0 / N ( 0% )" for ever.
for mutant in A B; do
    case $mutant in
      A) sed 's|const double avgu     = (double)sumTotalBr/totalPixelz - 1.0;|const double avgu     = (double)sumTotalBr/totalPixelz;|' \
             ../dupes-pixels.h > pixels_mutant.h
         label="the mean is computed without its offset" ;;
      B) sed 's|    return tpWaitForJobSlot(\[jobGeneration\] {|    while (tpMemoryIsTight() \&\& dpState.inFlight > 1)\n       std::this_thread::sleep_for(std::chrono::milliseconds(2));\n    return tpWaitForJobSlot([jobGeneration] {|' \
             ../dupes-pixels.h > pixels_mutant.h
         label="a worker waits for a count that includes itself" ;;
    esac

    if cmp -s pixels_mutant.h ../dupes-pixels.h; then
        echo "  ERROR: mutant $mutant did not apply - the sed pattern no longer matches"; fail=1
        continue
    fi

    g++ $CXXFLAGS -Wno-sign-compare -Ishim -DQPV_PIXELS_HEADER='"pixels_mutant.h"' -o pixels_mutant pixels_smoke.cpp -ldl -lpthread 2>/dev/null
    # mutant B is a deadlock: it is caught by the wall clock in the test, not by a wrong
    # number, so this one takes the deadline to answer
    if ./pixels_mutant > /dev/null 2>&1; then
        echo "  ERROR: mutant $mutant passed ($label) - the test proves nothing"; fail=1
    else
        echo "   ok - mutant $mutant is caught ($label)"
    fi
    rm -f pixels_mutant
done
rm -f pixels_mutant.h

echo
echo "== ordered-scan grouping vs the self-join it replaced (SQL only) =="
if command -v python3 >/dev/null 2>&1; then
    python3 sql_grouping.py || fail=1
else
    echo "  SKIPPED: python3 not available"
fi

echo
echo "== database import: the fingerprints survive the renumbering =="
if command -v python3 >/dev/null 2>&1; then
    python3 import_merge.py || fail=1
else
    echo "  SKIPPED: python3 not available"
fi

echo
echo "== candidate query engine, against a real SQLite database =="
# sqlite-dynamic.h binds sqlite3 by name at run time, so pointing its LoadLibraryW at
# libsqlite3.so runs the shipped engine against the genuine article rather than a mock.
if ! command -v python3 >/dev/null 2>&1; then
    echo "  SKIPPED: python3 not available to build the test database"
elif ! ls /usr/lib/*/libsqlite3.so.0 >/dev/null 2>&1 && ! ls /usr/lib/libsqlite3.so.0 >/dev/null 2>&1; then
    echo "  SKIPPED: libsqlite3.so.0 not available"
else
    python3 make_test_db.py testdb.sldb || fail=1
    if g++ $CXXFLAGS -Wno-sign-compare -Ishim -fopenmp -o query_engine query_engine.cpp -ldl 2>&1; then
        ./query_engine testdb.sldb || fail=1
    else
        echo "  ERROR: query_engine.cpp did not compile"; fail=1
    fi

    echo
    echo "== mutation check: the unhashable-fingerprint cases must reject both old bugs =="
    # Two regressions that a passing suite would otherwise say nothing about, because both
    # only show up on a database that holds a fingerprint of the wrong length:
    #   A - answering "nothing left to do" for a batch that was entirely unhashable, which
    #       ended the whole run and reported it as finished;
    #   B - marking those rows with the string "0" instead of an empty hash. "0" is a real
    #       hash value, so it lands them all in one phantom duplicate group.
    cp query_extract.cpp query_extract.orig
    for mutant in A B; do
        cp query_extract.orig query_extract.cpp
        case $mutant in
          A) sed -i 's|return sawRow ? 1 : 0;|return 0;|' query_extract.cpp
             label="a batch of only unhashable rows ends the run" ;;
          B) sed -i 's|SQ.bind_text16(dupesHashUpd, 1, L"", 0, QPV_SQLITE_STATIC);|SQ.bind_text16(dupesHashUpd, 1, L"0", 2, QPV_SQLITE_STATIC);|' query_extract.cpp
             label="the marker is the string \"0\"" ;;
        esac

        if cmp -s query_extract.cpp query_extract.orig; then
            echo "  ERROR: mutant $mutant did not apply - the anchor no longer matches"; fail=1
            continue
        fi

        g++ $CXXFLAGS -Wno-sign-compare -Ishim -fopenmp -o query_mutant query_engine.cpp -ldl 2>/dev/null
        if ./query_mutant testdb.sldb > /dev/null 2>&1; then
            echo "  ERROR: mutant $mutant passed ($label) - the test proves nothing"; fail=1
        else
            echo "   ok - mutant $mutant is caught ($label)"
        fi
    done
    mv -f query_extract.orig query_extract.cpp
    rm -f query_mutant
fi

echo
echo "== the PDF exporter's page geometry and document structure =="
# Jpeg2PDF.cpp is #included into qpv-main.cpp rather than compiled on its own, and it needs
# nothing from windows.h beyond three typedefs, so pdf_document.cpp compiles it VERBATIM.
# No slicing and no anchors to drift: what is tested is the whole shipped file.
if g++ $CXXFLAGS -o pdf_document pdf_document.cpp 2>&1; then
    ./pdf_document || fail=1
else
    echo "  ERROR: pdf_document.cpp did not compile"; fail=1
fi

echo
echo "== mutation check: the page box must be rejected at any unit but the point =="
# Both mutants restore a bug the exporter actually shipped with. They go into COPIES - the
# shipped sources are never edited, so an interrupted run cannot leave them broken.
#   A - the page box scaled by the render DPI instead of 72, which is what made every
#       exported page (dpi/72) times too large while the layout still looked correct;
#   B - the truncating cast that rounds A4's 841.68 pt down to a 841 pt page.
sed 's|#define PDF_UNITS_PER_INCH    72.0|#define PDF_UNITS_PER_INCH    192.0|' \
    ../Jpeg2PDF.h > jpeg2pdf_mutant.h
sed 's|\* PDF_UNITS_PER_INCH + 0.5|* PDF_UNITS_PER_INCH|g' ../Jpeg2PDF.cpp > jpeg2pdf_mutant.cpp
for mutant in A B; do
    case $mutant in
      A) defs="-DQPV_JPEG2PDF_HEADER='\"jpeg2pdf_mutant.h\"'"
         orig=../Jpeg2PDF.h;   copy=jpeg2pdf_mutant.h
         label="the page box is scaled by the render DPI" ;;
      B) defs="-DQPV_JPEG2PDF_SOURCE='\"jpeg2pdf_mutant.cpp\"'"
         orig=../Jpeg2PDF.cpp; copy=jpeg2pdf_mutant.cpp
         label="the page size is truncated rather than rounded" ;;
    esac

    if cmp -s "$copy" "$orig"; then
        echo "  ERROR: mutant $mutant did not apply - the sed pattern no longer matches"; fail=1
        continue
    fi

    if ! eval g++ \$CXXFLAGS $defs -o pdf_mutant pdf_document.cpp 2>/dev/null; then
        echo "  ERROR: mutant $mutant did not compile"; fail=1
        continue
    fi
    if ./pdf_mutant > /dev/null 2>&1; then
        echo "  ERROR: mutant $mutant passed ($label) - the test proves nothing"; fail=1
    else
        echo "   ok - mutant $mutant is caught ($label)"
    fi
done
rm -f pdf_mutant jpeg2pdf_mutant.h jpeg2pdf_mutant.cpp

if [ "${1:-}" = "--bench" ]; then
    echo
    echo "== MSD benchmark =="
    g++ $CXXFLAGS -o msd_bench msd_bench.cpp 2>&1 && ./msd_bench

    echo
    echo "== duplicate sweep benchmark, at library scale =="
    # -mpopcnt on purpose: the shipped DLL uses the POPCNT instruction whenever the CPU
    # reports it, and without the flag gcc expands __builtin_popcountll into a libgcc call
    # no shipped build ever executes. The correctness tests above stay on the plain SSE2
    # baseline, which is what the DLL is compiled against.
    g++ $CXXFLAGS -mpopcnt -fopenmp -o sweep_bench sweep_bench.cpp 2>&1 && ./sweep_bench
fi

echo
if [ "$fail" = "0" ]; then
    echo "ALL TESTS PASSED"
else
    echo "SOME TESTS FAILED"
fi
exit $fail
