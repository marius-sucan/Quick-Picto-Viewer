#!/usr/bin/env bash
# Verifies the duplicate-search maths in qpv-main.cpp on a machine that cannot build
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
SRC="../qpv-main.cpp"
HDR="../qpv-main.h"
fail=0

for f in "$SRC" "$HDR"; do
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
slice header_extract.h   "$HDR" '^\/\/ One record per surviving image pair' '^\/\/ qpv-dupes-query-state-end' 55 || exit 1
slice block_extract.cpp  "$SRC" '^\/\/ SWAR population count'          '^\/\/ qpv-dupes-block-end' 450 || exit 1
slice query_extract.cpp  "$SRC" '^\/\/ qpv-dupes-query-begin'          '^\/\/ qpv-dupes-query-end' 350 || exit 1
slice dct_extract.cpp    "$SRC" '^double calcArrayAvgMedian'          '^\/\/ qpv-dct-block-end' 100 || exit 1
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
echo "== mutation check: the histogram oracle must reject wrong maths =="
# Drops the "- 1" from the mean, which is the one term that looks like an off-by-one and
# is not: sumTotalBr accumulates (level + 1) so the /256 maps level 255 to exactly 1.0.
# The mutation goes into a COPY - the shipped header is never edited, so an interrupted
# run cannot leave it broken.
sed 's|const double avgu     = (double)sumTotalBr/totalPixelz - 1.0;|const double avgu     = (double)sumTotalBr/totalPixelz;|' \
    ../dupes-pixels.h > pixels_mutant.h
if ! cmp -s pixels_mutant.h ../dupes-pixels.h; then
    g++ $CXXFLAGS -Wno-sign-compare -Ishim -DQPV_PIXELS_HEADER='"pixels_mutant.h"' -o pixels_mutant pixels_smoke.cpp -ldl -lpthread 2>/dev/null
    if ./pixels_mutant > /dev/null 2>&1; then
        echo "  ERROR: the mutant passed - the histogram oracle proves nothing"; fail=1
    else
        echo "   ok - the mutant is caught"
    fi
    rm -f pixels_mutant
else
    echo "  ERROR: the mutation did not apply - update the sed pattern"; fail=1
fi
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

if [ "${1:-}" = "--bench" ]; then
    echo
    echo "== MSD benchmark =="
    g++ $CXXFLAGS -o msd_bench msd_bench.cpp 2>&1 && ./msd_bench
fi

echo
if [ "$fail" = "0" ]; then
    echo "ALL TESTS PASSED"
else
    echo "SOME TESTS FAILED"
fi
exit $fail
