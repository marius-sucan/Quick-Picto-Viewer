// Compiles the shipped duplicate-search block out of dupes-search.h against minimal
// Windows shims and exercises it end to end, so a syntax error, a type error or a
// broken result contract is caught here rather than on the MSVC box.
// Built with -fopenmp, so the "#pragma omp parallel for" clause is parsed too.
//
// The block tested spans popcount64() .. dupesScanEnd(), i.e. buildHamMask,
// hammingDistance, msdSumSquares, msdScore, decodeFingerprintBlob/Chunk, the pair
// fetch, the per-group sweep and the whole-scan cursor. It is text-sliced by
// run-tests.sh.
//
// The load-bearing test here is scanMatchesPerGroupSweep(): dupesScanStep() walks the
// whole candidate set from one entry point under a time budget, and the only thing
// keeping its cursor arithmetic honest is that it must produce, byte for byte, what the
// simple one-group-per-call dupesSweepPairs() produces.
//
// Two more invariants belong to the parallel sweep and are checked here as well:
//   - scanIsThreadCountIndependent(): the same candidate set must come back identical
//     whatever the team size is, down to a one-thread run. The pairs are collected into
//     one buffer per thread and concatenated in PLANNING order, so nothing about the
//     output may depend on who took which item or who finished first;
//   - sweepReallocatesRarely(): the pair list must grow geometrically, not once per
//     batch. reserve() honours its request exactly, so the "reserve(size() + found)" this
//     replaced re-allocated and copied the whole accumulated list on every batch, which
//     is quadratic - 160 seconds of copying against 1.2 seconds of comparing on a scan
//     that yields seven million pairs. Nothing about the RESULT changes when that comes
//     back, so the capacity is what has to be watched.
//
// written by Marius Șucan with Claude Opus 5

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <chrono>
#include <string>
#include <vector>
#include <algorithm>
#include <emmintrin.h>

typedef unsigned int       UINT;
typedef unsigned long long UINT64;
typedef long long          INT64;
typedef int                INT;
typedef int                LONG;      // Windows LONG is 32-bit; "long" here is 64-bit
typedef void*              HWND;
typedef const wchar_t*     LPCWSTR;
#define DLL_API extern "C"
#define DLL_CALLCONV
#define QPV_FORCEINLINE inline __attribute__((always_inline))

__attribute__((unused)) static void fnOutputDebug(std::string) {}
static void SetWindowText(HWND, LPCWSTR) {}

#include "header_extract.h"    // verbatim from dupes-search.h

// dupesScanEnd() and dupesClearPairs() forward-declare this so a scan can hand back its
// candidate rows without the sweep knowing where they came from. The query engine that
// defines it is not part of this test; query_engine.cpp covers that half.
void dupesQueryFreeRows() {}

#include "block_extract.cpp"   // verbatim from dupes-search.h

// ------------------------------------------------------------------------------------

static int failures = 0;

static void check(bool ok, const char *what) {
    printf("    %-58s %s\n", what, ok ? "ok" : "FAILED");
    if (!ok) failures++;
}

// xorshift, so the cases are the same on every machine and every libc
static UINT64 rngState = 88172645463325252ULL;
static void rngSeed(UINT64 s) { rngState = s ? s : 1; }
static UINT64 rnd64() {
    rngState ^= rngState << 13;
    rngState ^= rngState >> 7;
    rngState ^= rngState << 17;
    return rngState;
}
static UINT rndBelow(UINT n) { return (UINT)(rnd64() % n); }

// Fills one fingerprint record with a deterministic pattern; recSeed shifts it so no two
// records are identical (which would make every MSD zero and hide a real error).
static void fillRecord(std::vector<wchar_t> &blob, int rec, int stride, int recSeed) {
    for (int i = 0; i < stride; i++)
        blob[(size_t)rec * stride + i] = (wchar_t)(161 + ((i * 7 + recSeed * 29) % 256));
}

// The pairs used to be drained in 512-record chunks through dupesFetchPairs(). That entry
// point is gone: the sweep now leaves its results in dupesPairsList until dupesClearPairs()
// releases them, and AHK reads them through dupesApplyFilter()/dupesFetchFiltered() instead.
// Every caller below clears before it sweeps, so the whole list is exactly what the sweep
// just produced. dupesPairCount() is the exported view of that same list, so check the two
// agree while we are here - once, because this runs inside the per-case oracle loop.
static std::vector<DupePairRec> drainPairs() {
    static int reported = 0;
    if (!reported && dupesPairCount() != (UINT)dupesPairsList.size())
    {
       reported = 1;
       failures++;
       printf("    %-58s %s\n", "dupesPairCount() matches the pair list", "FAILED");
    }
    return dupesPairsList;
}

// ------------------------------------------------------------------------------------
// Stage 1 contract: what one sweep of one group has to hand back.

static void resultContract() {
    const int stride = 1024;
    const int n = 8;

    // record 3 carries no fingerprint, and its hash matches record 0 so it is forced
    // into pairs - that is the path that must yield the QPV_MSD_NONE sentinel
    UINT64 h[n]   = {1, 1, 3, 1, 0, 7, 1, 1};
    UINT64 fh[n]  = {1, 1, 3, 1, 0, 7, 1, 1};
    UINT   ids[n] = {10, 11, 12, 13, 14, 15, 16, 17};

    std::vector<wchar_t> blob((size_t)n * stride);
    for (int r = 0; r < n; r++)
        fillRecord(blob, r, stride, r);
    for (int i = 0; i < stride; i++)
        blob[(size_t)3 * stride + i] = (wchar_t)160;   // below 161 -> "no fingerprint"

    printf("  one group, one batch\n");
    dupesClearPairs();
    int hoff = 0;
    const UINT got = dupesSweepPairs(h, fh, ids, blob.data(), n, /*threshold*/ 4,
                                     0, 0, /*inverted*/ 0, /*flipped*/ 0,
                                     /*doMSD*/ 1, /*grayCompressor*/ 1, stride,
                                     /*stepping*/ 100, /*offsetu*/ 0, &hoff);
    check(hoff == n, "hoffset covers every outer index");
    check(got > 0, "the sweep found pairs");

    const std::vector<DupePairRec> ref = drainPairs();
    check(ref.size() == got, "the pair list holds exactly what the sweep counted");

    int sentinelPairs = 0, scoredPairs = 0, badId = 0, badHam = 0;
    for (size_t i = 0; i < ref.size(); i++) {
        const DupePairRec &r = ref[i];
        if (r.idA < 10 || r.idA > 17 || r.idB < 10 || r.idB > 17 || r.idA == r.idB)
           badId++;
        if ((int)r.hamDist >= 4)
           badHam++;
        if (r.idA == 13 || r.idB == 13) {
           if (r.mse == QPV_MSD_NONE) sentinelPairs++;
        } else if (r.mse != QPV_MSD_NONE)
           scoredPairs++;
    }
    check(badId == 0, "every pair references two distinct input IDs");
    check(badHam == 0, "every pair is strictly under the threshold");
    check(sentinelPairs > 0, "a record with no fingerprint scores QPV_MSD_NONE, not 0");
    check(scoredPairs > 0, "pairs with fingerprints get a real MSD score");

    // Batching must be transparent: the same input swept one outer index at a time has
    // to produce the same pairs, in the same order, as one batch covering everything.
    printf("  the same group, one outer index per batch\n");
    dupesClearPairs();
    UINT total = 0;
    int callOffset = 0;
    for (;;) {
        hoff = 0;
        const UINT rz = dupesSweepPairs(h, fh, ids, blob.data(), n, 4, 0, 0, 0, 0, 1, 1,
                                        stride, /*stepping*/ 0, callOffset, &hoff);
        callOffset += hoff;
        total += rz;
        if (hoff == 0) break;
    }
    check(total == got, "batched sweep finds the same number of pairs");

    const std::vector<DupePairRec> batched = drainPairs();
    check(batched.size() == ref.size(), "batched sweep returns the same record count");
    check(!ref.empty() && memcmp(ref.data(), batched.data(), ref.size() * sizeof(DupePairRec)) == 0,
          "batched sweep is byte-identical to the single-batch run");

    // A group whose fingerprints were never collected must still sweep on the hashes.
    printf("  MSD disabled\n");
    dupesClearPairs();
    hoff = 0;
    const UINT noMsd = dupesSweepPairs(h, fh, ids, NULL, n, 4, 0, 0, 0, 0,
                                       /*doMSD*/ 0, 1, stride, 100, 0, &hoff);
    check(noMsd == got, "the same pairs are found without fingerprints");
    const std::vector<DupePairRec> nomsd = drainPairs();
    int allSentinel = 1;
    for (size_t i = 0; i < nomsd.size(); i++)
        if (nomsd[i].mse != QPV_MSD_NONE) allSentinel = 0;
    check(allSentinel == 1, "every MSD reads as QPV_MSD_NONE when MSD is off");

    // The crop mask must not empty out: an over-wide crop is documented to mean "no
    // crop", because an empty mask makes every distance 0 and every image a duplicate.
    printf("  hash crop mask\n");
    check(buildHamMask(0, 0) == ~0ULL,       "no crop keeps all 64 bits");
    check(buildHamMask(80, 80) == ~0ULL,     "a crop wider than the hash means no crop");
    check(buildHamMask(1, 0) == ~1ULL,       "lCrop drops exactly that many low bits");
    check(popcount64(buildHamMask(2, 3)) == 59, "lCrop + rCrop drop the right count");

    dupesClearPairs();
    check(dupesPairsList.empty() && dupesPixData.empty() && dupesPixStride == 0,
          "dupesClearPairs releases everything");
}

// ------------------------------------------------------------------------------------
// Stage 2: the whole-scan cursor has to reproduce the per-group sweep exactly.

struct ScanCase {
    std::vector<UINT64>  hashes, flipped;
    std::vector<UINT>    ids;
    std::vector<UINT>    groupStart;    // groups+1 entries
    std::vector<wchar_t> pix;
    int  stride;
    int  threshold;
    int  checkInverted, checkFlipped, doMSD, grayCompressor;
    UINT lCrop, rCrop;
};

// Builds a candidate set with a realistic group-size distribution: mostly pairs and
// triples, occasionally one large group, plus the odd group of one that the sweep has to
// skip without losing its place.
static ScanCase makeCase(UINT64 seed, UINT groups, int stride) {
    rngSeed(seed);
    ScanCase K;
    K.stride = stride;
    K.threshold = 3 + (int)rndBelow(6);
    K.checkInverted = (rndBelow(4) == 0) ? 1 : 0;
    K.checkFlipped  = (rndBelow(3) == 0) ? 1 : 0;
    K.doMSD         = (rndBelow(4) != 0) ? 1 : 0;
    K.grayCompressor = 1 + (int)rndBelow(4);
    K.lCrop = (rndBelow(5) == 0) ? rndBelow(8) : 0;
    K.rCrop = (rndBelow(5) == 0) ? rndBelow(8) : 0;

    K.groupStart.push_back(0);
    for (UINT g = 0; g < groups; g++)
    {
        UINT m = 1 + rndBelow(4);
        if (rndBelow(12) == 0)
           m = 40 + rndBelow(90);      // one big group, to exercise the block splitter

        // a base hash per group, with a few bits flipped per member, so real pairs exist
        const UINT64 base = rnd64();
        for (UINT i = 0; i < m; i++)
        {
            UINT64 h = base;
            const int flips = (int)rndBelow(6);
            for (int f = 0; f < flips; f++)
                h ^= 1ULL << rndBelow(64);

            K.hashes.push_back(h);
            K.flipped.push_back(h ^ (rndBelow(2) ? 0ULL : 1ULL << rndBelow(64)));
            K.ids.push_back((UINT)K.ids.size() + 1);
        }
        K.groupStart.push_back((UINT)K.hashes.size());
    }

    const size_t rows = K.hashes.size();
    K.pix.assign(rows * stride, 0);
    for (size_t r = 0; r < rows; r++)
    {
        if (rndBelow(20) == 0)                          // no fingerprint for this one
        {
           for (int i = 0; i < stride; i++)
               K.pix[r * stride + i] = (wchar_t)160;
           continue;
        }

        const int shift = (int)rndBelow(40);
        for (int i = 0; i < stride; i++)
        {
            int v = (int)((i * 13 + shift * 7 + (int)(r % 251)) % 256);
            if (rndBelow(64) == 0)
               v = (int)rndBelow(256);
            K.pix[r * stride + i] = (wchar_t)(161 + v);
        }
    }
    return K;
}

// The reference: AHK's stage-1 shape, one DllCall per group over per-group buffers.
static std::vector<DupePairRec> perGroupSweep(const ScanCase &K) {
    dupesClearPairs();
    const UINT groups = (UINT)K.groupStart.size() - 1;
    for (UINT g = 0; g < groups; g++)
    {
        const UINT a = K.groupStart[g], b = K.groupStart[g + 1];
        const UINT m = b - a;
        if (m < 2)
           continue;

        std::vector<UINT64> h(K.hashes.begin() + a, K.hashes.begin() + b);
        std::vector<UINT64> fh(K.flipped.begin() + a, K.flipped.begin() + b);
        std::vector<UINT>   id(K.ids.begin() + a, K.ids.begin() + b);
        std::vector<wchar_t> px;
        if (K.doMSD)
           px.assign(K.pix.begin() + (size_t)a * K.stride, K.pix.begin() + (size_t)b * K.stride);

        int callOffset = 0;
        for (;;)
        {
            int hoff = 0;
            dupesSweepPairs(h.data(), fh.data(), id.data(), K.doMSD ? px.data() : NULL, m,
                            K.threshold, K.lCrop, K.rCrop, K.checkInverted, K.checkFlipped,
                            K.doMSD, K.grayCompressor, K.stride, /*stepping*/ 7, callOffset, &hoff);
            callOffset += hoff;
            if (hoff == 0) break;
        }
    }
    return drainPairs();
}

// The whole-scan path, fed in chunks and stepped under a budget - what AHK now drives.
static std::vector<DupePairRec> wholeScanSweep(const ScanCase &K, UINT feedChunk, int msBudget, int *stepsOut) {
    const UINT rows = (UINT)K.hashes.size();
    const UINT groups = (UINT)K.groupStart.size() - 1;
    dupesClearPairs();
    if (!dupesScanBegin(rows, groups, K.stride, K.grayCompressor, K.doMSD))
       return std::vector<DupePairRec>();

    for (UINT first = 0; first < rows; first += feedChunk)
    {
        const UINT count = (first + feedChunk <= rows) ? feedChunk : rows - first;
        dupesScanFeed(first, count, &K.hashes[first],
                      K.checkFlipped ? &K.flipped[first] : NULL, &K.ids[first],
                      K.doMSD ? &K.pix[(size_t)first * K.stride] : NULL);
    }

    dupesScanSetGroups(K.groupStart.data(), groups);
    int steps = 0;
    while (dupesScanStep(K.threshold, K.lCrop, K.rCrop, K.checkInverted, K.checkFlipped, msBudget))
    {
        steps++;
        if (steps > 2000000) { printf("    runaway step loop\n"); failures++; break; }
    }
    if (stepsOut) *stepsOut = steps;
    return drainPairs();
}

static bool samePairs(const std::vector<DupePairRec> &a, const std::vector<DupePairRec> &b) {
    if (a.size() != b.size())
       return false;
    if (a.empty())
       return true;
    return memcmp(a.data(), b.data(), a.size() * sizeof(DupePairRec)) == 0;
}

static void scanMatchesPerGroupSweep() {
    printf("  whole-scan sweep vs the per-group sweep\n");
    int mismatches = 0, emptyCases = 0, totalPairs = 0;
    for (UINT64 seed = 1; seed <= 12; seed++)
    {
        const ScanCase K = makeCase(seed * 7919, 60, 1024);
        const std::vector<DupePairRec> ref = perGroupSweep(K);
        totalPairs += (int)ref.size();
        if (ref.empty())
           emptyCases++;

        int steps = 0;
        const std::vector<DupePairRec> got = wholeScanSweep(K, 64, /*msBudget*/ 1, &steps);
        if (!samePairs(ref, got))
           mismatches++;

        // and again in one unbounded step, and with a feed chunk that covers everything
        const std::vector<DupePairRec> got2 = wholeScanSweep(K, (UINT)K.hashes.size(), 100000, NULL);
        if (!samePairs(ref, got2))
           mismatches++;
    }
    char msg[128];
    snprintf(msg, sizeof(msg), "12 candidate sets, %d pairs: identical record for record", totalPairs);
    check(mismatches == 0, msg);
    check(emptyCases <= 2, "the test data actually produces pairs");
    check(totalPairs > 200, "enough pairs to be worth comparing");
}

static void scanProgressAndCursor() {
    printf("  progress, cursor and state\n");
    const ScanCase K = makeCase(4242, 40, 1024);
    int steps = 0;
    const std::vector<DupePairRec> got = wholeScanSweep(K, 32, 1, &steps);

    const DupesScanState *S = (const DupesScanState*)dupesScanGetState();
    check(S->phase == 5, "phase reads 5 (done) once the step loop returns 0");
    check(S->done == S->total, "every planned comparison is accounted for");
    check(S->pairs == (INT64)got.size(), "state.pairs matches what the fetch handed back");
    check(S->rows == (LONG)K.hashes.size(), "state.rows is the candidate count");
    check(S->groups == (LONG)(K.groupStart.size() - 1), "state.groups is the group count");
    (void)steps;

    // total must be the triangular sum, which is what the progress bar divides by
    INT64 expect = 0;
    for (size_t g = 0; g + 1 < K.groupStart.size(); g++)
    {
        const INT64 m = K.groupStart[g + 1] - K.groupStart[g];
        expect += m * (m - 1) / 2;
    }
    check(S->total == expect, "state.total is the triangular comparison count");

    // Stepping a finished scan again must be a no-op, not a second pass. This used to read
    // as "the pair list is empty", which only held because the old dupesFetchPairs() had
    // consumed it; the list now survives until dupesClearPairs(), so what a second pass
    // would show is the count growing.
    const size_t pairsBefore = dupesPairsList.size();
    const int more = dupesScanStep(K.threshold, K.lCrop, K.rCrop, K.checkInverted, K.checkFlipped, 50);
    check(more == 0 && dupesPairsList.size() == pairsBefore, "stepping past the end finds nothing new");

    dupesScanEnd();
    check(dupesScanHashes.empty() && dupesPixData.empty() && dupesScanRows == 0,
          "dupesScanEnd releases the candidate set");
}

// The budget is the whole reason AHK can still cancel a scan: a step that runs away takes
// the cancel latency with it. One group of 3 000 images is 4.5 M comparisons, far more
// than any plausible single block, so a 1 ms budget has to come back repeatedly - and
// each return has to be prompt.
static void scanTimeBudget() {
    printf("  time budget\n");
    rngSeed(31337);
    ScanCase K;
    K.stride = 1024; K.threshold = 3; K.checkInverted = 0; K.checkFlipped = 0;
    K.doMSD = 0; K.grayCompressor = 1; K.lCrop = 0; K.rCrop = 0;
    const UINT m = 3000;
    for (UINT i = 0; i < m; i++) { K.hashes.push_back(rnd64()); K.flipped.push_back(0); K.ids.push_back(i + 1); }
    K.groupStart.push_back(0); K.groupStart.push_back(m);

    dupesClearPairs();
    dupesScanBegin(m, 1, K.stride, 1, 0);
    dupesScanFeed(0, m, K.hashes.data(), NULL, K.ids.data(), NULL);
    dupesScanSetGroups(K.groupStart.data(), 1);

    int steps = 0;
    double worstStepMs = 0.0;
    for (;;)
    {
        const std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
        const int more = dupesScanStep(K.threshold, 0, 0, 0, 0, /*msBudget*/ 1);
        const double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
        if (ms > worstStepMs) worstStepMs = ms;
        if (!more) break;
        steps++;
        if (steps > 1000000) { printf("    runaway step loop\n"); failures++; break; }
    }

    const DupesScanState *S = (const DupesScanState*)dupesScanGetState();
    char msg[160];
    snprintf(msg, sizeof(msg), "4.5 M comparisons at a 1 ms budget: %d steps, worst %.1f ms", steps, worstStepMs);
    check(steps > 1, msg);
    check(worstStepMs < 250.0, "no single step runs away with the cancel latency");
    check(S->done == S->total && S->total == (INT64)m * (m - 1) / 2, "every comparison was made exactly once");

    // and the same scan in one go must find the same pairs
    const std::vector<DupePairRec> stepped = drainPairs();
    const std::vector<DupePairRec> oneShot = wholeScanSweep(K, m, 100000, NULL);
    check(samePairs(stepped, oneShot), "stepping changes nothing about the result");
    dupesClearPairs();
}

static void scanEdgeCases() {
    printf("  edge cases\n");
    dupesClearPairs();

    // every group a singleton: nothing to compare, and the cursor must still terminate
    ScanCase K = makeCase(99, 1, 1024);
    K.hashes.assign(5, 12345);
    K.flipped.assign(5, 12345);
    K.ids.clear();
    for (UINT i = 0; i < 5; i++) K.ids.push_back(i + 1);
    K.groupStart.clear();
    for (UINT i = 0; i <= 5; i++) K.groupStart.push_back(i);
    K.pix.assign((size_t)5 * K.stride, (wchar_t)200);
    K.doMSD = 1; K.checkInverted = 0; K.checkFlipped = 0; K.threshold = 5;
    K.lCrop = K.rCrop = 0; K.grayCompressor = 1;
    int steps = 0;
    const std::vector<DupePairRec> none = wholeScanSweep(K, 5, 1, &steps);
    check(none.empty(), "a scan of nothing but singletons finds no pairs");
    check(((const DupesScanState*)dupesScanGetState())->phase == 5, "and still reaches phase 5");

    // fewer than two candidates: dupesScanBegin short-circuits rather than dividing by
    // zero or handing the sweep an empty boundary array
    dupesClearPairs();
    check(dupesScanBegin(1, 1, 1024, 1, 1) == 1, "dupesScanBegin(1 row) succeeds");
    check(((const DupesScanState*)dupesScanGetState())->phase == 5, "... and reports done");
    check(dupesScanStep(4, 0, 0, 0, 0, 10) == 0, "... and stepping it is a no-op");

    // a boundary array that runs off the end has to be rejected, not swept: it would
    // index the candidate arrays out of bounds
    dupesClearPairs();
    dupesScanBegin(4, 2, 1024, 1, 0);
    UINT bad[3] = {0, 2, 9};
    check(dupesScanSetGroups(bad, 2) == 0, "an out-of-range group boundary is rejected");
    check(((const DupesScanState*)dupesScanGetState())->phase == -1, "... and flagged as an error");
    check(dupesScanStep(4, 0, 0, 0, 0, 10) == 0, "... and the sweep refuses to run");

    // one big group in one step, to be sure the block splitter covers the last outer
    // index rather than stopping one short
    dupesClearPairs();
    ScanCase B;
    B.stride = 1024; B.threshold = 64; B.checkInverted = 0; B.checkFlipped = 0;
    B.doMSD = 0; B.grayCompressor = 1; B.lCrop = 0; B.rCrop = 0;
    const UINT m = 200;
    for (UINT i = 0; i < m; i++) { B.hashes.push_back(0); B.flipped.push_back(0); B.ids.push_back(i + 1); }
    B.groupStart.push_back(0); B.groupStart.push_back(m);
    const std::vector<DupePairRec> all = wholeScanSweep(B, m, 1, NULL);
    check(all.size() == (size_t)m * (m - 1) / 2, "a fully-matching group yields every pair exactly once");
    const std::vector<DupePairRec> ref = perGroupSweep(B);
    check(samePairs(ref, all), "... in the same order as the per-group sweep");

    dupesClearPairs();
}

// The result must not depend on how many threads swept it. This is the whole reason the
// items collect into buffers of their own and are concatenated in planning order rather
// than pushed into one shared list under a lock - and it is not a theoretical worry: the
// sweep that preceded this one appended under a critical section, so two identical scans
// of the same library could label the same images into different groups. See
// [[qpv-2026-08-dupes-sweep]].
static void scanIsThreadCountIndependent() {
    printf("  the team size changes nothing about the result\n");
#ifdef _OPENMP
    const int wasMax = omp_get_max_threads();
#endif
    // big groups on purpose: a candidate set of nothing but pairs would be swept by one
    // thread whatever the team size, and prove nothing
    ScanCase K = makeCase(90210, 12, 1024);
    K.hashes.clear(); K.flipped.clear(); K.ids.clear(); K.groupStart.clear();
    rngSeed(5150);
    K.groupStart.push_back(0);
    for (int g = 0; g < 6; g++)
    {
        const UINT64 base = rnd64();
        const UINT m = 400 + rndBelow(400);
        for (UINT i = 0; i < m; i++)
        {
            UINT64 h = base;
            const int flips = (int)rndBelow(5);
            for (int f = 0; f < flips; f++)
                h ^= 1ULL << rndBelow(64);

            K.hashes.push_back(h);
            K.flipped.push_back(h);
            K.ids.push_back((UINT)K.ids.size() + 1);
        }
        K.groupStart.push_back((UINT)K.hashes.size());
    }
    K.pix.assign(K.hashes.size() * K.stride, (wchar_t)200);
    K.doMSD = 0; K.checkInverted = 0; K.checkFlipped = 0;
    K.threshold = 6; K.lCrop = K.rCrop = 0; K.grayCompressor = 1;

    const std::vector<DupePairRec> ref = perGroupSweep(K);
    check(ref.size() > 10000, "the candidate set yields enough pairs to be worth threading");

    int mismatches = 0, slotsSeen = 0;
    const int teams[5] = {1, 2, 3, 5, 8};
    for (int t = 0; t < 5; t++)
    {
#ifdef _OPENMP
        omp_set_num_threads(teams[t]);
#endif
        // step it by hand rather than through wholeScanSweep(), so the plan can be read
        // back after every step: it still holds the last block's items, and the slot each
        // one recorded is the thread that ran it
        const UINT rows = (UINT)K.hashes.size();
        const UINT groups = (UINT)K.groupStart.size() - 1;
        dupesClearPairs();
        dupesScanBegin(rows, groups, K.stride, K.grayCompressor, K.doMSD);
        dupesScanFeed(0, rows, K.hashes.data(), NULL, K.ids.data(), NULL);
        dupesScanSetGroups(K.groupStart.data(), groups);
        int guard = 0;
        while (dupesScanStep(K.threshold, K.lCrop, K.rCrop, K.checkInverted, K.checkFlipped, 1))
        {
            int lo = 1 << 30, hi = -1;
            for (size_t i = 0; i < dupesSweepPlan.size(); i++)
            {
                if (dupesSweepPlan[i].slot < lo) lo = dupesSweepPlan[i].slot;
                if (dupesSweepPlan[i].slot > hi) hi = dupesSweepPlan[i].slot;
            }
            if (hi > lo && teams[t] > 1)
               slotsSeen = 1;

            if (++guard > 200000) { printf("    runaway step loop\n"); failures++; break; }
        }

        if (!samePairs(ref, dupesPairsList))
           mismatches++;

        dupesScanEnd();
    }
#ifdef _OPENMP
    omp_set_num_threads(wasMax);
#endif
    dupesClearPairs();

    char msg[128];
    snprintf(msg, sizeof(msg), "%d pairs, teams of 1/2/3/5/8: identical record for record", (int)ref.size());
    check(mismatches == 0, msg);
#ifdef _OPENMP
    check(slotsSeen == 1, "and more than one thread really did collect pairs");
#else
    (void)slotsSeen;
    printf("    %-58s %s\n", "team size (this build has no OpenMP)", "skipped");
#endif
}

// The pair list has to grow the way push_back grows, not once per batch. dupesSweepPairs()
// is the sharp instrument for this: one call per outer index means one append per call, so
// counting how often the capacity changes counts re-allocations exactly. Geometric growth
// gets from nothing to a million records in about twenty steps; an exact reserve() per
// batch re-allocates on every single one of the 1 500 calls and copies everything it has
// so far each time.
static void sweepReallocatesRarely() {
    printf("  the pair list grows geometrically, not once per batch\n");
    const UINT n = 1500;
    std::vector<UINT64> h(n, 0x0123456789abcdefULL);   // identical: every pair survives
    std::vector<UINT>   ids(n);
    for (UINT i = 0; i < n; i++)
        ids[i] = i + 1;

    dupesClearPairs();
    size_t lastCap = dupesPairsList.capacity();
    int changes = 0, calls = 0, offset = 0;
    for (;;)
    {
        int hoff = 0;
        dupesSweepPairs(h.data(), h.data(), ids.data(), NULL, n, /*threshold*/ 1, 0, 0,
                        0, 0, /*doMSD*/ 0, 1, 0, /*stepping*/ 0, offset, &hoff);
        offset += hoff;
        calls++;
        if (dupesPairsList.capacity() != lastCap)
        {
           lastCap = dupesPairsList.capacity();
           changes++;
        }
        if (hoff == 0 || calls > 100000)
           break;
    }

    char msg[160];
    snprintf(msg, sizeof(msg), "%d appends of %d pairs re-allocated %d times",
             calls, (int)dupesPairsList.size(), changes);
    check(dupesPairsList.size() == (size_t)n * (n - 1) / 2, "every pair of an all-equal group is found");
    check(changes > 0 && changes < 64, msg);
    dupesClearPairs();
}

int main() {
    resultContract();
    scanMatchesPerGroupSweep();
    scanProgressAndCursor();
    scanTimeBudget();
    scanEdgeCases();
    scanIsThreadCountIndependent();
    sweepReallocatesRarely();

    printf("\n  %s\n", failures ? "SWEEP SMOKE TEST FAILED" : "sweep smoke test passed");
    return failures ? 1 : 0;
}
