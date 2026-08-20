// Times dupesScanStep() over library-sized candidate sets, the way AutoHotkey drives it:
// dupesScanBegin/Feed/SetGroups and then a step loop under a millisecond budget.
//
// This is a BENCHMARK, not a correctness test - sweep_smoke.cpp is what pins the result
// contract. What it answers is the question a profile on the MSVC box cannot be run to
// answer from here: where a scan of a million images spends its time, and how much of
// the machine the sweep actually uses while it does.
//
// The three shapes below are the ones a real library produces:
//
//   - "small groups": grouping by file size and megapixels, which is what the property
//     presets do. Hundreds of thousands of groups of two to four, almost no comparisons,
//     and therefore nothing but per-group overhead.
//   - "one huge group": grouping by aspect ratio and frame count - the fallback the
//     Find Duplicates panel drops to when no properties are ticked. Half a photo library
//     is 3:2 single-frame, so one group holds most of it and the sweep is quadratic.
//   - "mixed": a spread of group sizes with a long tail, which is what an ordinary
//     library looks like.
//
// Built with -fopenmp and -mpopcnt: the shipped DLL uses the POPCNT instruction whenever
// the CPU reports it, and without -mpopcnt gcc expands __builtin_popcountll to a libgcc
// call that no shipped build ever executes. Treat the absolute numbers as an order of
// magnitude - GCC's inliner is not MSVC's - and the ratios as the real result.
//
// Usage:  ./sweep_bench [shape] [rows]
//         shapes: small | huge | mixed | msd | all   (default all)
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
#ifdef _OPENMP
#include <omp.h>
#endif
#ifndef _WIN32
#include <time.h>
#endif

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

void dupesQueryFreeRows() {}

#include "block_extract.cpp"   // verbatim from dupes-search.h

// ------------------------------------------------------------------------------------

// CPU time across every thread, so a wall time can be turned into "how many cores was
// this actually using". clock() is per-process on Linux and on Windows both.
static double cpuSeconds() {
#ifndef _WIN32
    struct timespec ts;
    if (clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts)==0)
       return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
    return (double)clock() / (double)CLOCKS_PER_SEC;
}

static UINT64 rngState = 88172645463325252ULL;
static void rngSeed(UINT64 s) { rngState = s ? s : 1; }
static UINT64 rnd64() {
    rngState ^= rngState << 13;
    rngState ^= rngState >> 7;
    rngState ^= rngState << 17;
    return rngState;
}
static UINT rndBelow(UINT n) { return (UINT)(rnd64() % n); }

struct BenchCase {
    std::vector<UINT64>  hashes;
    std::vector<UINT>    ids;
    std::vector<UINT>    groupStart;
    std::vector<unsigned char> pix;   // raw bytes, fed through dupesScanFeed's blob path
    int  stride = 0;
    int  threshold = 4;
    int  doMSD = 0;
    const char *name = "";
};

// A group of near-duplicates: one base hash per group with a handful of bits flipped per
// member, so the sweep actually finds pairs and pays for the ones it finds.
static void pushGroup(BenchCase &K, UINT m, int spread) {
    const UINT64 base = rnd64();
    for ( UINT i = 0 ; i < m ; i++)
    {
        UINT64 h = base;
        const int flips = (int)rndBelow((UINT)spread);
        for ( int f = 0 ; f < flips ; f++)
            h ^= 1ULL << rndBelow(64);

        K.hashes.push_back(h);
        K.ids.push_back((UINT)K.ids.size() + 1);
    }
    K.groupStart.push_back((UINT)K.hashes.size());
}

// Groups of two to four, which is what grouping by file size and megapixels produces.
static BenchCase makeSmall(UINT rows) {
    rngSeed(20260820);
    BenchCase K;
    K.name = "small groups (fsize, megapix)";
    K.threshold = 4;
    K.groupStart.push_back(0);
    while (K.hashes.size() < rows)
    {
        UINT m = 2 + rndBelow(3);
        if (rndBelow(9)==0)
           m = 1;                       // a singleton the cursor has to step over

        if (K.hashes.size() + m > rows)
           m = (UINT)(rows - K.hashes.size());
        if (m==0)
           break;

        pushGroup(K, m, 40);
    }
    return K;
}

// One group holding most of the library, which is what "imgwhratio, imgframes" does.
static BenchCase makeHuge(UINT rows) {
    rngSeed(777);
    BenchCase K;
    K.name = "one huge group (imgwhratio, imgframes)";
    K.threshold = 4;
    K.groupStart.push_back(0);
    const UINT big = (rows * 7) / 10;
    pushGroup(K, big, 64);              // 64 -> essentially random hashes, few pairs
    while (K.hashes.size() < rows)
    {
        UINT m = 2 + rndBelow(4);
        if (K.hashes.size() + m > rows)
           m = (UINT)(rows - K.hashes.size());
        if (m==0)
           break;

        pushGroup(K, m, 40);
    }
    return K;
}

// A long tail: mostly small, a few hundred medium, a couple of thousands.
static BenchCase makeMixed(UINT rows) {
    rngSeed(4242);
    BenchCase K;
    K.name = "mixed group sizes";
    K.threshold = 4;
    K.groupStart.push_back(0);
    while (K.hashes.size() < rows)
    {
        UINT m = 2 + rndBelow(3);
        const UINT r = rndBelow(1000);
        if (r < 3)        m = 3000 + rndBelow(9000);
        else if (r < 40)  m = 200 + rndBelow(600);
        else if (r < 160) m = 20 + rndBelow(60);

        if (K.hashes.size() + m > rows)
           m = (UINT)(rows - K.hashes.size());
        if (m==0)
           break;

        pushGroup(K, m, 48);
    }
    return K;
}

static void addFingerprints(BenchCase &K, int stride) {
    K.stride = stride;
    K.doMSD = 1;
    const size_t rows = K.hashes.size();
    K.pix.assign(rows * stride, 0);
    for ( size_t r = 0 ; r < rows ; r++)
    {
        const int shift = (int)rndBelow(40);
        unsigned char *p = &K.pix[r * stride];
        for ( int i = 0 ; i < stride ; i++)
            p[i] = (unsigned char)((i * 13 + shift * 7 + (int)(r % 251)) % 256);
    }
}

// dupesScanFeed() takes the Chr(gray+161) UTF-16 blob; the query engine feeds raw bytes
// through decodeFingerprintBytes() instead. Convert once, per chunk, so the benchmark
// does not hold a second copy of a gigabyte.
static void feedCase(const BenchCase &K) {
    const UINT rows = (UINT)K.hashes.size();
    const UINT chunk = 65536;
    std::vector<wchar_t> blob;
    if (K.doMSD)
       blob.resize((size_t)chunk * K.stride);

    for ( UINT first = 0 ; first < rows ; first += chunk)
    {
        const UINT count = (first + chunk <= rows) ? chunk : rows - first;
        if (K.doMSD)
        {
           const unsigned char *src = &K.pix[(size_t)first * K.stride];
           for ( size_t i = 0 ; i < (size_t)count * K.stride ; i++)
               blob[i] = (wchar_t)(161 + src[i]);
        }

        dupesScanFeed(first, count, &K.hashes[first], NULL, &K.ids[first],
                      K.doMSD ? blob.data() : NULL);
    }
}

struct Result {
    double wallSec, cpuSec, worstStepMs;
    int    steps;
    INT64  comparisons, pairs;
};

static Result runCase(const BenchCase &K, int msBudget) {
    const UINT rows = (UINT)K.hashes.size();
    const UINT groups = (UINT)K.groupStart.size() - 1;
    dupesClearPairs();
    dupesScanBegin(rows, groups, K.stride, 1, K.doMSD);
    feedCase(K);
    dupesScanSetGroups(K.groupStart.data(), groups);

    Result R = {};
    const double cpu0 = cpuSeconds();
    const std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
    for (;;)
    {
        const std::chrono::steady_clock::time_point s0 = std::chrono::steady_clock::now();
        const int more = dupesScanStep(K.threshold, 0, 0, 0, 0, msBudget);
        const double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - s0).count();
        if (ms > R.worstStepMs) R.worstStepMs = ms;
        R.steps++;
        if (!more)
           break;
    }
    R.wallSec = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    R.cpuSec = cpuSeconds() - cpu0;
    R.comparisons = dupesScanState.total;
    R.pairs = dupesScanState.pairs;
    dupesScanEnd();
    dupesClearPairs();
    return R;
}

static void report(const BenchCase &K, const Result &R) {
    const double mcps = (R.wallSec > 0.0) ? (double)R.comparisons / R.wallSec / 1e6 : 0.0;
    printf("  %-40s rows %8u  groups %8u\n", K.name, (UINT)K.hashes.size(), (UINT)K.groupStart.size() - 1);
    printf("      comparisons %14lld   pairs %10lld\n", (long long)R.comparisons, (long long)R.pairs);
    printf("      wall %8.3f s   cpu %8.3f s   cores used %5.2f\n",
           R.wallSec, R.cpuSec, (R.wallSec > 0.0) ? R.cpuSec / R.wallSec : 0.0);
    printf("      %10.1f M comparisons/s      steps %6d   worst step %7.1f ms\n\n",
           mcps, R.steps, R.worstStepMs);
}

int main(int argc, char **argv) {
    const std::string shape = (argc > 1) ? argv[1] : "all";
    const UINT rows = (argc > 2) ? (UINT)strtoul(argv[2], NULL, 10) : 1000000;
    const int msBudget = 350;      // filterDupeResultsByHdist()'s own budget

#ifdef _OPENMP
    printf("OpenMP: %d threads available\n", omp_get_max_threads());
#else
    printf("OpenMP: NOT enabled in this build\n");
#endif
    printf("budget %d ms per step, %u rows\n\n", msBudget, rows);

    if (shape=="small" || shape=="all")
    {
       const BenchCase K = makeSmall(rows);
       report(K, runCase(K, msBudget));
    }

    if (shape=="mixed" || shape=="all")
    {
       const BenchCase K = makeMixed(rows);
       report(K, runCase(K, msBudget));
    }

    if (shape=="huge" || shape=="all")
    {
       // quadratic: a full million in one group is 3.5e11 comparisons, which is not a
       // benchmark but an afternoon. A tenth of the rows is the same shape at 1% of the
       // cost, and the rate is what is being measured.
       const UINT hugeRows = (shape=="huge") ? rows : rows / 10;
       const BenchCase K = makeHuge(hugeRows);
       report(K, runCase(K, msBudget));
    }

    if (shape=="msd" || shape=="all")
    {
       // the fingerprints are 1 KB per image; a million of them is a gigabyte, which is
       // exactly what the shipped scan allocates when the MSD filter is on
       BenchCase K = makeMixed(rows / 5);
       K.name = "mixed, MSD on (1 KB fingerprints)";
       addFingerprints(K, 1024);
       report(K, runCase(K, msBudget));
    }

    return 0;
}
