// dupes-search.h
//
// The duplicate-identification pipeline: everything that turns a library of images into a
// list of the near-identical ones. It was the middle third of qpv-main.cpp until it was
// lifted out whole - not one line of it changed on the way here.
//
// What lives in this file, top to bottom - which is the order it sat in inside
// qpv-main.cpp, not the order a scan runs it in:
//
//   - the records and the state AutoHotkey reads by byte offset - DupePairRec,
//     DupesScanState, DupeCandRow, DupeResultRow - which came out of qpv-main.h with it;
//   - the Hamming and mean-squared-difference sweep, per group (dupesSweepPairs) or over
//     a whole library from one entry point (dupesScanBegin/Feed/SetGroups/Step/End). It
//     runs across every core: the unit of parallel work is a run of candidate ROWS, which
//     is the only unit that fills the machine for both shapes a real library comes in -
//     see "the parallel pair sweep" below;
//   - the threshold filter and the union-find grouping behind the similarity sliders
//     (dupesApplyFilter), plus the fetches AHK drains the results through;
//   - the candidate query engine, which steps the grouping SELECT itself and keeps only
//     the images that landed in a group of two or more (dupesEngineInit, dupesQuery*);
//   - hash generation - dHash, lHash and pHash over the stored pixel fingerprints,
//     written back through the database handle AHK owns (dupesHashBegin/Step/End);
//   - the discrete cosine transform pHash is built on (calculateDCTcoeffs, calcPHashAlgo).
//
// A run goes the other way round: the hashes are generated once for the library, the query
// engine then picks the candidates and groups them, the sweep compares them, and the filter
// is what the similarity sliders re-run over the pairs the sweep left behind. On a library
// of a million images the sweep is where all the time goes, and it is the only part of the
// pipeline that is threaded.
//
// The fingerprints the hashes are computed FROM are collected by dupes-pixels.h, which is
// included further down qpv-main.cpp and reads dupesPixCancel out of here, so that the one
// "stop" the user can press answers both halves of the work.
//
// This file is #included by qpv-main.cpp rather than compiled on its own. The pipeline
// shares fnOutputDebug(), the DLL_API / QPV_FORCEINLINE macros and M_PI with the rest of
// that translation unit, and sqlite-dynamic.h declares its SQLiteAPI instance static - so
// a second translation unit would quietly bind sqlite3.dll into a second copy of it and
// the collector would no longer be talking to the same binding as the query engine.
//
// tests/run-tests.sh text-slices the algorithms below out of this file and compiles them
// against Windows shims, which is the only way they can be checked on a machine that
// cannot build the DLL. The marker comments it anchors on say so where they are; leave
// them in place, and keep the function signatures it names at the start of a line.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_DUPES_SEARCH_H
#define QPV_DUPES_SEARCH_H

// The run-time binding to sqlite3.dll. It used to be #included halfway down this block,
// between the sweep and the query engine; it sits at the top now because the query engine,
// the hash loop and the fingerprint collector of dupes-pixels.h all go through it and this
// file is the first of the three.
#include "sqlite-dynamic.h"

// ---- the records and the state shared with AutoHotkey ---------------------------------
//
// Declared here rather than in qpv-main.h so the whole subsystem is one file. Everything
// below is read from AHK by byte offset, which is what the fixed layouts are about.

// One record per surviving image pair.
// The three parallel std::vector<UINT> this replaced needed three exports, three
// AHK buffers and three copies of what is one row.
struct DupePairRec {      // 16 bytes; AHK NumGet()s the fields at 0/4/8/12
    UINT idA;
    UINT idB;
    UINT hamDist;
    UINT mse;             // QPV_MSD_NONE when MSD is off or a fingerprint is missing
};

std::vector<DupePairRec>    dupesPairsList;
std::vector<unsigned char>  dupesPixData;   // decoded fingerprints, arraySize * dupesPixStride
std::vector<unsigned char>  dupesPixOK;     // 1 when that index carries a usable fingerprint
UINT                        dupesPixStride = 0;
int                         dupesPixScale = 1;   // graylevelCompressor, folded back in by msdScore()
size_t                      dupesPairsRead = 0;

// Progress and phase for the whole-scan duplicate sweep. AHK polls it with NumGet()
// through dupesScanGetState(), the way it polls thumbsPoolGetState(), so a tooltip and
// an ETA cost no DllCall of their own. Fixed layout - do not reorder.
#pragma pack(push, 8)
struct DupesScanState {
    volatile LONG  phase;      //  0   0 idle, 1 loading, 2 querying, 3 sweeping, 5 done, -1 cancelled
    volatile LONG  lastError;  //  4
    volatile INT64 done;       //  8   comparisons performed
    volatile INT64 total;      // 16   comparisons planned
    volatile INT64 pairs;      // 24   surviving pairs collected so far
    volatile LONG  groups;     // 32
    volatile LONG  rows;       // 36   candidate images
    volatile INT64 scanned;    // 40   rows the candidate query has stepped through
    volatile LONG  queryDone;  // 48   1 once the query has been walked to the end
    volatile LONG  spare;      // 52
};
#pragma pack(pop)

// The whole candidate set for one duplicate scan, laid out flat and grouped.
// dupesScanGroupStart holds groups+1 offsets into the arrays, so group g occupies
// [dupesScanGroupStart[g], dupesScanGroupStart[g+1]) and the last entry is the row
// count - the same shape a CSR sparse matrix uses for its rows.
std::vector<UINT64>         dupesScanHashes;
std::vector<UINT64>         dupesScanFlipped;   // empty unless findFlippedDupes=1
std::vector<UINT>           dupesScanIDs;       // resultedFilesList row indexes
std::vector<UINT>           dupesScanGroupStart;
DupesScanState              dupesScanState = {};
UINT                        dupesScanRows = 0;
int                         dupesScanWantMSD = 0;
// Where every candidate row's group ends: row r is swept against [r+1, dupesScanRowEnd[r]).
// It is dupesScanGroupStart flattened to one entry per row, which is what lets a unit of
// work be any run of consecutive rows rather than a slice of one group - see the sweep
// below. A row no group covers gets r+1, i.e. nothing to compare, which is exactly what
// the group-walking cursor this replaced did with it. Built by dupesScanBuildRowEnd().
std::vector<UINT>           dupesScanRowEnd;
// Cursor: the next candidate row the sweep has to visit, plus the adaptive amount of work
// one parallel block aims for - see dupesScanStep().
UINT                        dupesScanOuter = 0;
INT64                       dupesScanBlock = 0;
// qpv-dupes-state-end - sliced by tests/run-tests.sh; leave the marker in place.

// One candidate row, as dupesFetchRows() hands it to AHK. The path is not in the record:
// every path of the scan lives end to end in one UTF-16 buffer (dupesGetPathBuffer()) and
// the row points at it, so AHK pays one StrGet per row and no DllCall at all.
#pragma pack(push, 8)
struct DupeCandRow {          // 32 bytes; AHK NumGet()s the fields at 0/8/16/24/28
    INT64  imgidu;            //  0
    INT64  fsize;             //  8
    double megapix;           // 16
    UINT   groupID;           // 24   1-based ordinal, ascending in scan order
    UINT   pathOffset;        // 28   UTF-16 code units into the path buffer
};
#pragma pack(pop)

std::vector<DupeCandRow>    dupesCandRows;
std::wstring                dupesPathBuf;     // every candidate path, NUL separated
UINT                        dupesCandGroups = 0;

// One image of the filtered duplicates list, in display order, as dupesFetchFiltered()
// hands it to AHK. AHK turns groupRoot and grpTag into the "root_tag" group ID column 23
// has always held, and copies hamDist / mse into columns 33 and 34.
#pragma pack(push, 8)
struct DupeResultRow {        // 20 bytes; AHK NumGet()s the fields at 0/4/8/12/16
    UINT imgIndex;            //  0   row index into bckpResultedFilesList
    UINT groupRoot;           //  4   union-find root: the smallest row index in the group
    UINT grpTag;              //  8   the group ID's suffix
    UINT hamDist;             // 12   this image's own closest match
    UINT mse;                 // 16
};
#pragma pack(pop)

std::vector<DupeResultRow>  dupesFilterRows;
// qpv-dupes-query-state-end - sliced by tests/run-tests.sh; leave the marker in place.

// ---- the pair sweep, the scan cursor and the threshold filter -------------------------

// POPCNT is an SSE4.2 instruction. This project builds with
// EnableEnhancedInstructionSet=SSE2 and ships a Win7 x64 DLL, and MSVC emits the
// instruction wherever __popcnt64() appears - /arch does not gate it - so using the
// intrinsic unconditionally faults with an illegal instruction on the x64 machines
// that predate it (Intel before Nehalem, AMD before K10). Hence the run-time check:
// the CPUID bit is read once at load and the branch below is perfectly predicted,
// which is noise next to the memory traffic of the sweep. DO NOT remove the SWAR
// fallback - hammingDistance() runs n*n/2 times per group and this is the one place
// where the baseline the project declares actually has teeth.
#if defined(_MSC_VER) && (defined(_M_X64) || defined(_M_AMD64))
static bool qpvDetectPopcnt() {
    int regs[4] = {0, 0, 0, 0};
    __cpuid(regs, 1);
    return (regs[2] & (1 << 23))!=0;    // CPUID.01H:ECX.POPCNT[bit 23]
}
static const bool qpvHasPopcnt = qpvDetectPopcnt();
#endif

// SWAR population count, with the hardware instruction when this CPU has it.
inline int popcount64(UINT64 x) {
#if defined(_MSC_VER) && (defined(_M_X64) || defined(_M_AMD64))
    if (qpvHasPopcnt)
       return (int)__popcnt64(x);
#elif defined(__GNUC__) || defined(__clang__)
    // without -mpopcnt this expands to a table or the same SWAR, never a bare POPCNT
    return __builtin_popcountll((unsigned long long)x);
#endif

    x -= (x >> 1) & 0x5555555555555555ULL;
    x  = (x & 0x3333333333333333ULL) + ((x >> 2) & 0x3333333333333333ULL);
    x  = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0FULL;
    return (int)((x * 0x0101010101010101ULL) >> 56);
}

// Builds the bit window the two crop settings describe: lCrop drops that many
// LOW bits, rCrop that many HIGH bits. That is what the 8x8 preview grid in
// updateUIimageHashPreview() promises; the old loop compared a 1-based counter
// against hamDistLBorderCrop and so dropped only lCrop-1 low bits while
// dropping rCrop high bits.
// A crop wider than the hash is treated as "no crop": the alternative is an
// empty mask, which makes every distance 0 and every image a duplicate.
inline UINT64 buildHamMask(UINT lCrop, UINT rCrop) {
    if (lCrop > 64) lCrop = 64;
    if (rCrop > 64) rCrop = 64;
    if (lCrop + rCrop >= 64)
       return ~0ULL;

    const UINT keep = 64 - lCrop - rCrop;
    return ((keep == 64) ? ~0ULL : ((1ULL << keep) - 1ULL)) << lCrop;
}

inline int hammingDistance(const UINT64 n1, const UINT64 n2, const UINT64 mask) {
    return popcount64((n1 ^ n2) & mask);
}

// "MSD was not computed for this pair" - the same sentinel calcMSDvalues()'s caller
// seeded MSE with, and the value testWasMSEdupes() tests against.
#define QPV_MSD_NONE 2500

// Sum of squared differences over two grayscale fingerprints.
// The accumulator cannot overflow the INT32 lanes _mm_madd_epi16 sums into:
// 1024 * 255^2 = 66,585,600, and graylevelCompressor only ever shrinks the operands
// (they are stored pre-division - see decodeFingerprintBlob).
QPV_FORCEINLINE INT64 msdSumSquares(const unsigned char *a, const unsigned char *b, const int count) {
    __m128i acc = _mm_setzero_si128();
    const __m128i zero = _mm_setzero_si128();
    int i = 0;
    for ( ; i + 16 <= count ; i += 16)
    {
        const __m128i va = _mm_loadu_si128((const __m128i*)(a + i));
        const __m128i vb = _mm_loadu_si128((const __m128i*)(b + i));
        const __m128i dlo = _mm_sub_epi16(_mm_unpacklo_epi8(va, zero), _mm_unpacklo_epi8(vb, zero));
        const __m128i dhi = _mm_sub_epi16(_mm_unpackhi_epi8(va, zero), _mm_unpackhi_epi8(vb, zero));
        acc = _mm_add_epi32(acc, _mm_madd_epi16(dlo, dlo));
        acc = _mm_add_epi32(acc, _mm_madd_epi16(dhi, dhi));
    }

    acc = _mm_add_epi32(acc, _mm_shuffle_epi32(acc, _MM_SHUFFLE(1, 0, 3, 2)));
    acc = _mm_add_epi32(acc, _mm_shuffle_epi32(acc, _MM_SHUFFLE(2, 3, 0, 1)));
    INT64 sum = (INT64)_mm_cvtsi128_si32(acc);
    for ( ; i < count ; i++)
    {
        const int d = (int)a[i] - (int)b[i];
        sum += (INT64)d * d;
    }

    return sum;
}

// What the interpreted calcMSDvalues() produced: Round(sqrt(sumOfSquares/(count/2))).
// The /2 is not a typo - it is the scale every stored userFindDupesMSElvl threshold is
// calibrated against - and AHK's Round() is half away from zero, so floor(x + 0.5) and
// not rint().
// scale folds graylevelCompressor back in. discretizeValue() stored Round(v/L)*L, which
// reaches 256 for v=255, L=2 and so does not fit a byte; the fingerprints are stored as
// the quotient Round(v/L) instead, and every difference is therefore L times too small.
// Sum of (L*d)^2 is L^2 * sum of d^2, so the factor comes back out here exactly - no
// clamping, and the operands stay bytes for the SSE2 path.
QPV_FORCEINLINE int msdScore(const unsigned char *a, const unsigned char *b, const int count, const int scale) {
    const INT64 sum = msdSumSquares(a, b, count) * (INT64)scale * (INT64)scale;
    return (int)floor(sqrt((double)sum / ((double)count / 2.0)) + 0.5);
}

// The fingerprints live in the database as Chr(gray + 161), so the AHK string holding
// them is one UTF-16 code unit per pixel in U+00A1..U+01A0 and needs no conversion on
// the way in - AHK hands over the pointer and this walks it.
// AHK pads records with no usable fingerprint with code units below 161; the first one
// of a record is the flag, which keeps the blob dense and the stride constant.
// grayCompressor mirrors discretizeValue(): Round(v/level)*level, half away from zero.
// Only the QUOTIENT Round(v/level) is stored - the product reaches 256 for v=255,
// level=2 and would not fit a byte - and dupesPixScale carries the level back into
// msdScore(), which is exact because every difference simply scales by it.
// Decodes count records into slots [firstIndex, firstIndex+count) of the already-sized
// dupesPixData. Split out of decodeFingerprintBlob() so a whole-library candidate set can
// arrive in chunks: at 2 KB of UTF-16 per image, one blob covering every candidate is
// hundreds of megabytes AHK would have to hold while the DLL holds the decoded copy too.
static void decodeFingerprintChunk(const wchar_t *blob, const UINT firstIndex, const UINT count) {
    if (blob==NULL || count==0 || dupesPixStride==0)
       return;

    const UINT stride = dupesPixStride;
    if ((size_t)(firstIndex + count) * stride > dupesPixData.size() || firstIndex + count > dupesPixOK.size())
       return;

    for ( UINT rec = 0 ; rec < count ; rec++)
    {
        const wchar_t *src = blob + (size_t)rec * stride;
        if (src[0] < 161)
           continue;

        unsigned char *dst = &dupesPixData[(size_t)(firstIndex + rec) * stride];
        for ( UINT k = 0 ; k < stride ; k++)
        {
            int v = (int)src[k] - 161;
            if (v < 0) v = 0;
            else if (v > 255) v = 255;
            if (dupesPixScale > 1)
               v = (int)floor((double)v / dupesPixScale + 0.5);
            dst[k] = (unsigned char)v;
        }
        dupesPixOK[firstIndex + rec] = 1;
    }
}

static void decodeFingerprintBlob(const wchar_t *blob, const UINT count, const UINT stride, const int grayCompressor) {
    dupesPixStride = stride;
    dupesPixScale = (grayCompressor > 1) ? grayCompressor : 1;
    dupesPixData.assign((size_t)count * stride, 0);
    dupesPixOK.assign(count, 0);
    decodeFingerprintChunk(blob, 0, count);
}

void dupesQueryFreeRows();
// The sweep's collecting buffers and its block plan, both defined with the sweep further
// down. Forward-declared so the two release paths above the sweep can hand them back.
static void dupesSweepReleaseScratch();

// Releases everything the duplicate scan holds. AHK calls it on every exit path from
// filterDupeResultsByHdist(), including the abandoned ones: a partially read pair list
// would otherwise be handed to the next scan ahead of its own results.
DLL_API UINT DLL_CALLCONV dupesClearPairs() {
    dupesQueryFreeRows();
    dupesSweepReleaseScratch();
    dupesFilterRows.clear();
    dupesFilterRows.shrink_to_fit();
    dupesPairsList.clear();
    dupesPairsList.shrink_to_fit();
    dupesPixData.clear();
    dupesPixData.shrink_to_fit();
    dupesPixOK.clear();
    dupesPixOK.shrink_to_fit();
    dupesScanHashes.clear();     dupesScanHashes.shrink_to_fit();
    dupesScanFlipped.clear();    dupesScanFlipped.shrink_to_fit();
    dupesScanIDs.clear();        dupesScanIDs.shrink_to_fit();
    dupesScanGroupStart.clear(); dupesScanGroupStart.shrink_to_fit();
    dupesScanRowEnd.clear();     dupesScanRowEnd.shrink_to_fit();
    dupesPixStride = 0;
    dupesPixScale = 1;
    dupesPairsRead = 0;
    dupesScanRows = 0;
    dupesScanWantMSD = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 0;
    memset((void*)&dupesScanState, 0, sizeof(dupesScanState));

    return 1;
}

void setMainWindowTitle(std::string str, HWND pvHwnd) {
  // std::string str = "Calculating hamming distance: " + std::to_string(yay) + " / " + std::to_string(yoyo);
  std::wstring temp = std::wstring(str.begin(), str.end());
  LPCWSTR wideString = temp.c_str();

  SetWindowText(pvHwnd, wideString);
}

// ---- the parallel pair sweep -----------------------------------------------------------
//
// A scan of a large library spends nearly all of its time here, so the sweep runs across
// every core the machine has. What gets fanned out is a BLOCK OF CANDIDATE ROWS, not one
// group and not one outer index of one group, because a real candidate set is both shapes
// at once: grouping by file size and megapixels gives hundreds of thousands of groups of
// two or three, and grouping by aspect ratio and frame count gives a handful of groups one
// of which holds most of the library. Cutting the work up by group, or by the outer indexes
// inside one group, is what this used to do, and neither fills the machine for the first
// shape - a group of three has two outer indexes and two comparisons, which is not enough
// to be worth a team however it is sliced, so the sweep ran on one core no matter how many
// the machine had. Rows are the unit that serves both, and dupesScanRowEnd[] is what makes
// a row self-describing: it says where that row's own group ends, so a block of rows never
// has to care how many groups it spans.
//
// The result order is the one a serial run would have produced - row ascending, and inner
// index ascending within a row - because every item of the block collects into a buffer of
// its own and the buffers are concatenated in PLANNING order afterwards. Nothing about the
// output depends on how many threads ran, on which item they took or on the order they
// finished in. Both callers rely on that: it is what makes the whole-scan sweep
// byte-identical to the per-group one, and it is why two identical scans of the same
// library cannot come back with different groups. See [[qpv-2026-08-dupes-sweep]].

// qpv-main.cpp includes this unconditionally; the test slices do not, and they are built
// both with and without -fopenmp. Everything below degrades to a serial sweep when the
// macro is absent - the pragma is ignored and the team is one thread wide.
#ifdef _OPENMP
#include <omp.h>
#endif

// Everything the pair sweep needs that does not change while it runs. Gathered into a
// struct because the sweep is now entered from two places - the per-group export below
// and the whole-scan cursor in dupesScanStep() - and a fourteen-argument inner function
// is a transcription bug waiting to happen.
struct DupesSweepCtx {
    const UINT64 *hashes;
    const UINT64 *flipped;    // may alias hashes when flipped detection is off
    const UINT   *ids;
    const UINT   *rowEnd;     // NULL: every row's group ends at flatEnd (the one-group entry point)
    UINT   flatEnd;
    UINT64 hamMask;
    int    threshold;
    int    checkInverted;
    int    checkFlipped;
    bool   wantMSD;
};

// One unit of parallel work: the candidate rows [firstRow, lastRow]. slot, begin and count
// are written by whichever thread ran the item and say where its pairs ended up, so the
// concatenation can put the items back in planning order without the threads having to
// agree on anything while they run.
struct DupesSweepItem {
    UINT   firstRow, lastRow;
    int    slot;
    int    failed;            // this item ran out of memory; see dupesRunPlan()
    size_t begin, count;
};

// One collecting buffer per thread, padded so that no two of them share a cache line: a
// push_back writes the vector's own size field, and two threads finding pairs at the same
// moment would otherwise ping-pong that line between their caches for the whole sweep.
// Both arrays survive from block to block and from call to call. Their predecessor was a
// "std::vector<std::vector<DupePairRec>> part(noffset)" allocated and thrown away on every
// block of every group, which on a library of 300 000 groups is 300 000 allocations of a
// vector of vectors before a single comparison is made.
struct DupesSweepBuf {
    std::vector<DupePairRec> v;
    char pad[128 - (sizeof(std::vector<DupePairRec>) % 128)];
};

static std::vector<DupesSweepItem> dupesSweepPlan;
static std::vector<DupesSweepBuf>  dupesSweepBufs;
// Set when a block could not be collected because the machine ran out of memory. Cleared
// and read by dupesScanStep(), which turns it into the error phase AHK stops on: a scan
// that silently dropped a block of pairs would report duplicate groups it had not finished
// building, and nothing downstream could tell that apart from a library that really has
// none. dupesSweepPairs() neither clears nor reports it - it sweeps one group of a size AHK
// chose, and nothing in the application drives it any more.
static bool dupesSweepAllocFailed = false;

static void dupesSweepReleaseScratch() {
    dupesSweepPlan.clear();  dupesSweepPlan.shrink_to_fit();
    dupesSweepBufs.clear();  dupesSweepBufs.shrink_to_fit();
}

// How wide the team may be. Read once per block rather than baked in: omp_set_num_threads()
// can change it from outside, and the buffers above are indexed by the thread number, so
// the count and the buffer array have to be decided together. The num_threads clause on the
// region below is what makes that airtight - a team is never larger than it asks for, so
// omp_get_thread_num() cannot come back with an index past the end of the array.
static int dupesSweepThreads() {
#ifdef _OPENMP
    int t = omp_get_max_threads();
    if (t < 1)
       t = 1;

    if (t > 256)      // one buffer per thread; a machine this wide is not the problem here
       t = 256;

    return t;
#else
    return 1;
#endif
}

// What one candidate row costs on top of its comparisons: the group-end lookup and the
// inner loop's setup, and for a singleton nothing else at all. Blocks are planned in these
// units rather than in comparisons, because a candidate set of 300 000 groups of three is
// almost no comparisons and a very great deal of loop - planned by comparisons alone, one
// block would swallow the entire scan and the cancel latency with it.
#define QPV_SWEEP_ROW_COST   4
// Never cut an item smaller than this: below it the OpenMP scheduler costs more than the
// work does.
#define QPV_SWEEP_MIN_ITEM   4096
// And never plan more items than this in one block, whatever the arithmetic says.
#define QPV_SWEEP_MAX_ITEMS  4096

// Sweeps candidate rows [firstRow, lastRow] against everything after each of them inside
// that row's own group, appending the survivors to out - outer ascending, inner ascending,
// exactly what a serial run over the same rows produces.
static void sweepRowsInto(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, std::vector<DupePairRec> &out) {
    const UINT64 *givenHashesArray = C.hashes;
    const UINT64 *givenFlippedHashesArray = C.flipped;
    const UINT   *givenIDs = C.ids;
    const UINT   *rowEnd   = C.rowEnd;
    const UINT64  hamMask  = C.hamMask;
    const int  threshold     = C.threshold;
    const int  checkInverted = C.checkInverted;
    const int  checkFlipped  = C.checkFlipped;
    const bool wantMSD       = C.wantMSD;

    for ( UINT secondIndex = firstRow ; secondIndex <= lastRow ; secondIndex++)
    {
        const UINT n = (rowEnd!=NULL) ? rowEnd[secondIndex] : C.flatEnd;
        if (secondIndex + 1 >= n)
           continue;      // a singleton, or the last member of its group: nothing after it

        const UINT64 hashSecond = givenHashesArray[secondIndex];
        UINT64 invert2ndindex = 0;
        // UINT64 reversed2ndindex = 0;
        if (checkInverted==1)
           invert2ndindex = ~hashSecond;

        const UINT64 flipped2ndindex = (checkFlipped==1) ? givenFlippedHashesArray[secondIndex] : 0;

        // if (checkFlipped==1)
        // {
        //    reversed2ndindex = revBits_entire(givenHashesArray[secondIndex]);
        //    // fnOutputDebug("reverso " + to_string(givenHashesArray[secondIndex]) + " -- " + to_string(reversed2ndindex));
        // }

        for ( UINT mainIndex = secondIndex + 1 ; mainIndex < n ; mainIndex++)
        {
            int diff2 = 900;
            int diff3 = 900;

            int diff = hammingDistance(givenHashesArray[mainIndex], hashSecond, hamMask);
            if (checkInverted==1)
               diff2 = hammingDistance(givenHashesArray[mainIndex], invert2ndindex, hamMask);
            if (checkFlipped==1)
               diff3 = hammingDistance(givenHashesArray[mainIndex], flipped2ndindex, hamMask);

            // if (threshold>2 && diff>=threshold)
            //    diff = hammingDistance(givenHashesArray[mainIndex], reversed2ndindex, hamMask);

            // matches are rare: skip the bookkeeping for the overwhelming
            // majority of pairs
            if (diff>=threshold && diff2>=threshold && diff3>=threshold)
               continue;

            // The two fingerprints are in cache right here, and the pair survives at
            // most three times, so this is computed once and shared - which is also
            // what the AHK loop did, one MSE per result row of the same pair.
            // A pair missing either fingerprint keeps the sentinel: it used to read as
            // MSE 0 (StrSplit("") -> an empty array -> a sum of zeroes), i.e. a perfect
            // match, which is the same phantom-duplicate shape as the "0x" -> 0 hash bug.
            UINT mse = QPV_MSD_NONE;
            if (wantMSD && dupesPixOK[mainIndex] && dupesPixOK[secondIndex])
               mse = (UINT)msdScore(&dupesPixData[(size_t)mainIndex * dupesPixStride],
                                    &dupesPixData[(size_t)secondIndex * dupesPixStride],
                                    (int)dupesPixStride, dupesPixScale);

            const UINT idA = givenIDs[mainIndex], idB = givenIDs[secondIndex];
            if (diff<threshold)
               out.push_back({ idA, idB, (UINT)diff, mse });

            if (diff2<threshold)
               out.push_back({ idA, idB, (UINT)diff2, mse });

            if (diff3<threshold)
            {
                // fnOutputDebug("c++ dupe pair:" + to_string(givenHashesArray[mainIndex]) + "/" + to_string(givenFlippedHashesArray[secondIndex]));
                out.push_back({ idA, idB, (UINT)diff3, mse });
            }
        }
    }
}

// Grows the pair list the way push_back would have. std::vector::reserve() honours the
// request EXACTLY - it never rounds up - so the old "reserve(size() + found)" on every
// block made each block re-allocate the whole accumulated list and copy it across. Over
// the thousands of blocks a library-sized scan runs that is quadratic in the number of
// pairs, and it was by a wide margin the most expensive thing the sweep did: a candidate
// set that produced seven million pairs spent 160 seconds in here and 1.2 seconds
// comparing hashes. Growing by half again amortises it back to linear.
static void dupesReservePairs(size_t need) {
    size_t cap = dupesPairsList.capacity();
    if (need <= cap)
       return;

    if (cap < 4096)
       cap = 4096;

    while (cap < need)
    {
        const size_t grown = cap + cap / 2;
        if (grown <= cap)      // size_t is about to wrap: ask for exactly what is needed
        {
           cap = need;
           break;
        }

        cap = grown;
    }

    dupesPairsList.reserve(cap);
}

// Fills dupesSweepPlan with items covering the rows from firstRow, stopping at lastRow,
// when costBudget units of work have been planned, or when the plan is full. A new item is
// cut every itemTarget units so the team gets several items per thread to balance against
// and one heavy item cannot leave the rest of the machine idle.
// Returns the comparisons planned - which is what the progress counter counts - and reports
// the first row NOT planned through stoppedAt, which is where the caller resumes.
static INT64 dupesPlanRows(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, const INT64 costBudget, const INT64 itemTarget, UINT &stoppedAt) {
    dupesSweepPlan.clear();
    stoppedAt = firstRow;
    if (firstRow > lastRow)
       return 0;

    const UINT  *rowEnd = C.rowEnd;
    const INT64  last = (INT64)lastRow;
    INT64 comparisons = 0, cost = 0;
    INT64 r = (INT64)firstRow;
    while (r <= last)
    {
        const INT64 itemFirst = r;
        INT64 itemCost = 0;
        while (r <= last)
        {
            const UINT row = (UINT)r;
            const UINT end = (rowEnd!=NULL) ? rowEnd[row] : C.flatEnd;
            const INT64 c = (end > row + 1) ? (INT64)(end - row - 1) : 0;
            comparisons += c;
            cost        += c + QPV_SWEEP_ROW_COST;
            itemCost    += c + QPV_SWEEP_ROW_COST;
            r++;
            if (itemCost >= itemTarget)
               break;
        }

        DupesSweepItem it;
        it.firstRow = (UINT)itemFirst;
        it.lastRow  = (UINT)(r - 1);
        it.slot   = 0;
        it.failed = 0;
        it.begin  = 0;
        it.count  = 0;
        dupesSweepPlan.push_back(it);
        if (costBudget > 0 && cost >= costBudget)
           break;

        if ((INT64)dupesSweepPlan.size() >= QPV_SWEEP_MAX_ITEMS)
           break;
    }

    stoppedAt = (UINT)r;
    return comparisons;
}

// Runs the planned block across the team and appends everything it found to
// dupesPairsList in planning order. Returns how many pairs that was.
static size_t dupesRunPlan(const DupesSweepCtx &C, const int nThreads) {
    const int nItems = (int)dupesSweepPlan.size();
    if (nItems < 1)
       return 0;

    if ((int)dupesSweepBufs.size() < nThreads)
       dupesSweepBufs.resize((size_t)nThreads);

    for ( int t = 0 ; t < nThreads ; t++)
        dupesSweepBufs[t].v.clear();    // keeps the capacity: after the first few blocks
                                        // the sweep stops allocating altogether

    DupesSweepItem *items = dupesSweepPlan.data();
    DupesSweepBuf  *bufs  = dupesSweepBufs.data();
    const DupesSweepCtx *ctx = &C;

    // Every iteration writes only its own slot of items[] and only its own thread's
    // buffer, so the region needs no synchronisation whatsoever; the candidate arrays,
    // dupesPixData and dupesPixOK are read-only for its whole duration.
    // The shared state is spelled out rather than left to default(none): the old clause
    // named one of the dozen or so variables the region actually touched, which MSVC's
    // OpenMP 2.0 lets through and clang-cl and gcc do not. default(none) is deliberately
    // not used here either, because whether a const variable may appear in a data-sharing
    // clause changed between OpenMP versions and the compilers disagree; the read-only
    // locals above are shared by default on every one of them.
    #pragma omp parallel for schedule(dynamic) num_threads(nThreads) shared(items, bufs, ctx) if (nItems > 1 && nThreads > 1)
    for ( int i = 0 ; i < nItems ; i++)
    {
        int slot = 0;
#ifdef _OPENMP
        slot = omp_get_thread_num();
#endif
        std::vector<DupePairRec> &out = bufs[slot].v;
        const size_t begin = out.size();
        // An exception that leaves an OpenMP structured block is undefined behaviour, and
        // push_back() can throw: one block of a pathological candidate set - a hundred
        // thousand images that are all the same picture - really can ask for more than the
        // machine has. Caught here so it becomes a reported failure instead of a crash.
        // The flag is per ITEM rather than a shared one so the region still needs no
        // synchronisation; what the item collected before it threw is a PREFIX of what it
        // owed, so the ordering of everything else survives.
        int failed = 0;
        try
        {
            sweepRowsInto(*ctx, items[i].firstRow, items[i].lastRow, out);
        }
        catch (const std::bad_alloc&)
        {
            failed = 1;
        }

        items[i].slot   = slot;
        items[i].failed = failed;
        items[i].begin  = begin;
        items[i].count  = out.size() - begin;
    }

    size_t results = 0;
    for ( int i = 0 ; i < nItems ; i++)
    {
        results += dupesSweepPlan[i].count;
        if (dupesSweepPlan[i].failed!=0)
           dupesSweepAllocFailed = true;
    }

    if (results > 0)
    {
       // and the same for the concatenation: this throw would otherwise cross the __stdcall
       // boundary into AutoHotkey, which has nothing to catch it with
       try
       {
           dupesReservePairs(dupesPairsList.size() + results);
           for ( int i = 0 ; i < nItems ; i++)
           {
               const DupesSweepItem &it = dupesSweepPlan[i];
               if (it.count==0)
                  continue;

               const std::vector<DupePairRec> &src = dupesSweepBufs[it.slot].v;
               dupesPairsList.insert(dupesPairsList.end(), src.begin() + it.begin, src.begin() + it.begin + it.count);
           }
       }
       catch (const std::bad_alloc&)
       {
           dupesSweepAllocFailed = true;
       }
    }

    return results;
}

// Compares outer indexes [firstOuter, lastOuter] against everything after them inside the
// half-open candidate range [groupFirst, groupEnd), and appends the surviving pairs to
// dupesPairsList. Returns how many it appended.
//
// This is the one-group entry point dupesSweepPairs() drives, where every row of the range
// shares one group end and C.rowEnd is therefore NULL. dupesScanStep() does not come
// through here - it plans its own blocks, which is the whole point of the rewrite - but
// both go through the same planner, the same worker and the same concatenation, so the two
// cannot drift apart. tests/sweep_smoke.cpp asserts they agree record for record.
static UINT sweepOuterRange(const DupesSweepCtx &C, const UINT groupFirst, const UINT groupEnd, const UINT firstOuter, const UINT lastOuter) {
    (void)groupFirst;
    if (firstOuter > lastOuter || lastOuter >= groupEnd)
       return 0;

    // The group is flat here, so the cost of the range is closed-form: outer index m
    // compares against groupEnd-m-1 others, which is an arithmetic series.
    const INT64 rows = (INT64)lastOuter - (INT64)firstOuter + 1;
    const INT64 hi = (INT64)groupEnd - (INT64)firstOuter - 1;
    const INT64 lo = (INT64)groupEnd - (INT64)lastOuter - 1;
    const INT64 cost = (hi + lo) * rows / 2 + rows * QPV_SWEEP_ROW_COST;

    const int nThreads = dupesSweepThreads();
    INT64 itemTarget = cost / ((INT64)nThreads * 8);
    if (itemTarget < QPV_SWEEP_MIN_ITEM)
       itemTarget = QPV_SWEEP_MIN_ITEM;

    // One plan is capped at QPV_SWEEP_MAX_ITEMS items, so a range wide enough to overflow
    // it takes more than one pass. It cannot happen with the item size above; the loop is
    // what makes "sweeps the whole range" true rather than nearly true.
    size_t results = 0;
    UINT next = firstOuter;
    while (next <= lastOuter)
    {
        UINT stoppedAt = next;
        dupesPlanRows(C, next, lastOuter, -1, itemTarget, stoppedAt);
        if (stoppedAt <= next)
           break;

        results += dupesRunPlan(C, nThreads);
        next = stoppedAt;
    }

    return (UINT)results;
}

// Renamed from hammingDistanceOverArray() when the mean-squared difference moved in
// here: the signature gained four parameters, and an export whose argument list changes
// under a __stdcall caller is a stack corruption waiting for a stale qpvmain.dll. A new
// name makes a version mismatch a clean "function not found" instead.
//
// Sweeps ONE group per call, in batches of "stepping" outer indexes. The scan path
// (dupesScanBegin/Step) superseded it - it walks every group from one entry point under a
// time budget - but this stays exported and stays the simplest statement of what the
// sweep means. tests/sweep_smoke.cpp asserts the two agree record for record, which is
// the only guard there is against the cursor arithmetic in dupesScanStep() drifting.
DLL_API UINT DLL_CALLCONV dupesSweepPairs(UINT64 *givenHashesArray, UINT64 *givenFlippedHashesArray, UINT *givenIDs, const wchar_t *pixelBlob, UINT arraySize, int threshold, UINT hamDistLBorderCrop, UINT hamDistRBorderCrop, int checkInverted, int checkFlipped, int doMSD, int grayCompressor, int pixStride, int stepping, int offsetu, int* hoffset) {
   UINT n = arraySize;

    // The caller re-enters this for every batch of the same group, so the fingerprints
    // are decoded once on the first batch and reused. A short blob disables MSD rather
    // than reading past its end.
    if (offsetu==0)
    {
       if (doMSD==1 && pixelBlob!=NULL && pixStride > 0)
          decodeFingerprintBlob(pixelBlob, arraySize, (UINT)pixStride, grayCompressor);
       else
       {
          dupesPixData.clear();
          dupesPixOK.clear();
          dupesPixStride = 0;
       }
    }

    DupesSweepCtx C;
    C.hashes   = givenHashesArray;
    C.flipped  = (givenFlippedHashesArray!=NULL) ? givenFlippedHashesArray : givenHashesArray;
    C.ids      = givenIDs;
    C.rowEnd   = NULL;    // one group, and it ends where the caller's arrays do
    C.flatEnd  = n;
    C.hamMask  = buildHamMask(hamDistLBorderCrop, hamDistRBorderCrop);
    C.threshold = threshold;
    C.checkInverted = checkInverted;
    C.checkFlipped  = checkFlipped;
    C.wantMSD  = (doMSD==1 && dupesPixStride > 0 && dupesPixOK.size() >= (size_t)arraySize);

    // The caller walks the outer index in batches of "stepping" so it can show
    // progress and stay interruptible; the old code covered offsetu ..
    // offsetu+stepping inclusive, which is preserved here.
    const INT firstIndex = offsetu;
    INT lastIndex = offsetu + stepping;
    if (lastIndex > (INT)n - 1)
       lastIndex = (INT)n - 1;

    if (firstIndex > lastIndex || firstIndex < 0)
    {
       *hoffset = 0;
       return 0;
    }

    const UINT results = sweepOuterRange(C, 0, n, (UINT)firstIndex, (UINT)lastIndex);
    *hoffset = lastIndex - firstIndex + 1;
    return results;
}

// ---- the whole-scan sweep ------------------------------------------------------------
//
// One entry point walks every group instead of AHK entering the DLL once per group. On a
// library with 20 000 groups of two to four images that was 60 000+ DllCalls, each one
// preceded by three VarSetCapacity()s and an interpreted marshalling loop, around a few
// hundred nanoseconds of actual work.
//
// The candidate set is loaded once and the sweep is then driven by dupesScanStep(msBudget),
// which does a bounded chunk of work and returns so AHK can repaint and poll
// determineTerminateOperation(). Interruption therefore keeps exactly the shape it had;
// only the call count changed.
//
// In the application the set only ever arrives from SQLite, through dupesQueryBegin() and
// dupesScanBuildFromQuery(): AHK no longer has a query path of its own, so it has nothing
// to feed. dupesScanBegin/Feed/SetGroups stay exported because they are the seam
// tests/sweep_smoke.cpp drives the sweep through, without a database and without SQLite.

// Sizes the candidate arrays. rows is the total across every group; groups only reserves
// the boundary array, dupesScanSetGroups() is what actually fills it.
// Returns 1 on success, 0 if the allocation failed - a scan of a large library with MSD
// on asks for rows * pixStride bytes of fingerprints, which is the one allocation here
// big enough to fail.
DLL_API int DLL_CALLCONV dupesScanBegin(UINT rows, UINT groups, int pixStride, int grayCompressor, int doMSD) {
    dupesScanHashes.clear();
    dupesScanFlipped.clear();
    dupesScanIDs.clear();
    dupesScanGroupStart.clear();
    dupesScanRowEnd.clear();
    dupesPixData.clear();
    dupesPixOK.clear();
    dupesPairsList.clear();
    dupesPairsRead = 0;
    dupesScanRows = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 0;
    dupesScanWantMSD = 0;
    dupesPixStride = 0;
    dupesPixScale = 1;
    memset((void*)&dupesScanState, 0, sizeof(dupesScanState));
    if (rows < 2)
    {
       dupesScanState.phase = 5;
       return 1;
    }

    try
    {
        dupesScanHashes.assign(rows, 0);
        dupesScanIDs.assign(rows, 0);
        dupesScanGroupStart.reserve((size_t)groups + 1);
        if (doMSD==1 && pixStride > 0)
        {
           dupesPixStride = (UINT)pixStride;
           dupesPixScale = (grayCompressor > 1) ? grayCompressor : 1;
           dupesPixData.assign((size_t)rows * pixStride, 0);
           dupesPixOK.assign(rows, 0);
           dupesScanWantMSD = 1;
        }
    }
    catch (const std::bad_alloc&)
    {
        dupesScanHashes.clear();
        dupesScanIDs.clear();
        dupesPixData.clear();
        dupesPixOK.clear();
        dupesPixStride = 0;
        dupesScanWantMSD = 0;
        dupesScanState.lastError = 1;
        dupesScanState.phase = -1;
        return 0;
    }

    dupesScanRows = rows;
    dupesScanState.phase = 1;
    dupesScanState.rows = (LONG)rows;
    return 1;
}

// Fills rows [firstIndex, firstIndex+count) from AHK-side buffers. flipped may be NULL
// when findFlippedDupes=0, pixelBlob when MSD is off; pixelBlob holds count records of
// pixStride UTF-16 code units, the same Chr(gray+161) encoding the database stores.
DLL_API int DLL_CALLCONV dupesScanFeed(UINT firstIndex, UINT count, const UINT64 *hashes, const UINT64 *flipped, const UINT *ids, const wchar_t *pixelBlob) {
    if (count==0 || (size_t)firstIndex + count > dupesScanRows)
       return 0;

    if (hashes!=NULL)
       memcpy(&dupesScanHashes[firstIndex], hashes, (size_t)count * sizeof(UINT64));

    if (ids!=NULL)
       memcpy(&dupesScanIDs[firstIndex], ids, (size_t)count * sizeof(UINT));

    if (flipped!=NULL)
    {
       if (dupesScanFlipped.size() < dupesScanRows)
          dupesScanFlipped.assign(dupesScanRows, 0);

       memcpy(&dupesScanFlipped[firstIndex], flipped, (size_t)count * sizeof(UINT64));
    }

    if (dupesScanWantMSD==1 && pixelBlob!=NULL)
       decodeFingerprintChunk(pixelBlob, firstIndex, count);

    return 1;
}

// Flattens the group boundaries into one entry per candidate row, so a block of work can
// be any run of rows: row r is compared against [r+1, dupesScanRowEnd[r]). A row that no
// group covers - neither dupesScanSetGroups() nor dupesScanBuildFromQuery() insists the
// boundaries start at 0 - gets r+1 and is stepped over, which is exactly what the cursor
// that walked groupStart did with it.
// Returns false only when the array cannot be allocated. That is four bytes a row against
// the eight of hash and the up-to-a-kilobyte of fingerprint the same scan already holds,
// so it is not a realistic failure; it is reported rather than ignored because a short
// dupesScanRowEnd would sweep the wrong ranges rather than none.
static bool dupesScanBuildRowEnd() {
    dupesScanRowEnd.clear();
    if (dupesScanRows < 1)
       return true;

    try
    {
        dupesScanRowEnd.resize(dupesScanRows);
    }
    catch (const std::bad_alloc&)
    {
        dupesScanRowEnd.clear();
        return false;
    }

    for ( UINT r = 0 ; r < dupesScanRows ; r++)
        dupesScanRowEnd[r] = r + 1;

    for ( size_t g = 0 ; g + 1 < dupesScanGroupStart.size() ; g++)
    {
        const UINT a = dupesScanGroupStart[g], b = dupesScanGroupStart[g + 1];
        if (b <= a || b > dupesScanRows)   // already rejected by the two callers; a
           continue;                       // malformed boundary must not index past the end

        for ( UINT r = a ; r < b ; r++)
            dupesScanRowEnd[r] = b;
    }

    return true;
}

// groupStart holds groups+1 ascending offsets into the candidate arrays; entry g is where
// group g starts and the last entry is the row count, so group g is
// [groupStart[g], groupStart[g+1]). Also computes the comparison total the progress bar
// divides by: the sweep is triangular, so a group of m images is m*(m-1)/2 comparisons
// and counting groups or images instead makes the bar crawl and then jump.
DLL_API int DLL_CALLCONV dupesScanSetGroups(const UINT *groupStart, UINT groups) {
    if (groupStart==NULL || groups==0 || dupesScanRows < 2)
    {
       dupesScanState.phase = 5;
       return 0;
    }

    dupesScanGroupStart.assign(groupStart, groupStart + groups + 1);
    INT64 total = 0;
    for ( UINT g = 0 ; g < groups ; g++)
    {
        const UINT a = dupesScanGroupStart[g], b = dupesScanGroupStart[g + 1];
        if (b <= a || b > dupesScanRows)   // a malformed boundary array would run the
        {                                  // sweep off the end of the candidate arrays
           dupesScanGroupStart.clear();
           dupesScanState.lastError = 2;
           dupesScanState.phase = -1;
           return 0;
        }

        const INT64 m = (INT64)(b - a);
        total += m * (m - 1) / 2;
    }

    if (!dupesScanBuildRowEnd())
    {
       dupesScanGroupStart.clear();
       dupesScanState.lastError = 1;
       dupesScanState.phase = -1;
       return 0;
    }

    dupesScanState.groups = (LONG)groups;
    dupesScanState.total = total;
    dupesScanOuter = 0;         // rows before the first group carry no comparisons at all,
                                // so starting at 0 costs one loop iteration each and keeps
                                // the cursor a plain row index
    dupesScanBlock = 1 << 16;   // first block is deliberately small; the clock below sizes
    dupesScanState.phase = 3;   // the rest from what this machine actually managed
    return 1;
}

// Does up to msBudget milliseconds of sweeping and returns 1 while work remains, 0 when
// the scan is complete. Progress is in dupesScanState - AHK NumGet()s it rather than
// paying for a DllCall per tooltip refresh.
//
// The work is done in BLOCKS of candidate rows, each one fanned out across every core - see
// the sweep above for why rows rather than groups are the unit. The budget is checked
// between blocks, never per comparison and never inside a block, and the block size adapts
// to what this machine measured: the old AHK-side heuristic grew "stepping" by half
// whenever the previous batch came back inside 1.5 s, which is the same idea driven by a
// number nobody could calibrate.
//
// A block is free to span as many groups as fit it, which is the difference that matters on
// a real library: a candidate set of 300 000 groups of three used to be 300 000 blocks of
// two comparisons each, every one of them below the size at which the old code would even
// start a team, so the whole sweep ran on one core no matter how many the machine had.
DLL_API int DLL_CALLCONV dupesScanStep(int threshold, UINT hamDistLBorderCrop, UINT hamDistRBorderCrop, int checkInverted, int checkFlipped, int msBudget) {
    if (dupesScanGroupStart.size() < 2 || dupesScanRows < 2 || dupesScanRowEnd.size() < (size_t)dupesScanRows)
    {
       if (dupesScanState.phase!=-1)   // a rejected boundary array stays an error; it
          dupesScanState.phase = 5;    // must not read back as a scan that found nothing

       return 0;
    }

    DupesSweepCtx C;
    C.hashes   = dupesScanHashes.data();
    C.flipped  = (dupesScanFlipped.size() >= dupesScanRows) ? dupesScanFlipped.data() : dupesScanHashes.data();
    C.ids      = dupesScanIDs.data();
    C.rowEnd   = dupesScanRowEnd.data();
    C.flatEnd  = dupesScanRows;
    C.hamMask  = buildHamMask(hamDistLBorderCrop, hamDistRBorderCrop);
    C.threshold = threshold;
    C.checkInverted = checkInverted;
    C.checkFlipped  = (dupesScanFlipped.size() >= dupesScanRows) ? checkFlipped : 0;
    C.wantMSD  = (dupesScanWantMSD==1 && dupesPixStride > 0 && dupesPixOK.size() >= dupesScanRows);

    if (msBudget < 1)
       msBudget = 1;

    if (dupesScanBlock < 4096)
       dupesScanBlock = 1 << 16;

    // aim for a block around an eighth of the budget: often enough that overshooting one
    // block cannot blow the cancel latency, rare enough that the clock read is noise
    const double blockTargetMs = (double)msBudget / 8.0;
    const std::chrono::steady_clock::time_point tStart = std::chrono::steady_clock::now();
    const int nThreads = dupesSweepThreads();
    dupesSweepAllocFailed = false;
    dupesScanState.phase = 3;

    while (dupesScanOuter < dupesScanRows)
    {
        // several items per thread, so a heavy one cannot leave the rest of the team idle
        INT64 itemTarget = dupesScanBlock / ((INT64)nThreads * 8);
        if (itemTarget < QPV_SWEEP_MIN_ITEM)
           itemTarget = QPV_SWEEP_MIN_ITEM;

        UINT stoppedAt = dupesScanOuter;
        const INT64 planned = dupesPlanRows(C, dupesScanOuter, dupesScanRows - 1, dupesScanBlock, itemTarget, stoppedAt);
        if (stoppedAt <= dupesScanOuter)   // an empty plan would spin this loop for ever
           break;

        const std::chrono::steady_clock::time_point tBlock = std::chrono::steady_clock::now();
        const size_t got = dupesRunPlan(C, nThreads);
        const double blockMs = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tBlock).count();

        dupesScanState.pairs += (INT64)got;
        dupesScanState.done += planned;
        dupesScanOuter = stoppedAt;
        if (dupesSweepAllocFailed)
        {
           // the pair list is missing part of this block and cannot be completed; stopping
           // on the error phase is what keeps AHK from presenting it as a finished scan
           dupesScanState.lastError = 1;
           dupesScanState.phase = -1;
           return 0;
        }

        if (blockMs < blockTargetMs * 0.5 && dupesScanBlock < (INT64)1 << 30)
           dupesScanBlock *= 2;
        else if (blockMs > blockTargetMs && dupesScanBlock > 4096)
           dupesScanBlock /= 2;

        if (std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tStart).count() >= msBudget)
           return 1;
    }

    dupesScanState.done = dupesScanState.total;
    dupesScanState.phase = 5;
    return 0;
}

// The progress block, for NumGet(). Offsets are in the DupesScanState declaration.
DLL_API void* DLL_CALLCONV dupesScanGetState() {
    return (void*)&dupesScanState;
}

// Releases the candidate set once the sweep is over, keeping the pair list so AHK can
// still drain it. On a large library with MSD on this is the several hundred megabytes of
// fingerprints, and it is worth handing back before AHK starts building its result rows.
DLL_API int DLL_CALLCONV dupesScanEnd() {
    // dupesQueryFreeRows() lives further down with the query engine; forward-declared
    // at global scope so releasing the sweep also releases the candidate rows and their paths,
    // which AHK has already copied into resultedFilesList by this point.
    dupesQueryFreeRows();
    dupesSweepReleaseScratch();
    dupesScanHashes.clear();     dupesScanHashes.shrink_to_fit();
    dupesScanFlipped.clear();    dupesScanFlipped.shrink_to_fit();
    dupesScanIDs.clear();        dupesScanIDs.shrink_to_fit();
    dupesScanGroupStart.clear(); dupesScanGroupStart.shrink_to_fit();
    dupesScanRowEnd.clear();     dupesScanRowEnd.shrink_to_fit();
    dupesPixData.clear();        dupesPixData.shrink_to_fit();
    dupesPixOK.clear();          dupesPixOK.shrink_to_fit();
    dupesPixStride = 0;
    dupesPixScale = 1;
    dupesScanRows = 0;
    dupesScanWantMSD = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 0;
    if (dupesScanState.phase!=-1)
       dupesScanState.phase = 0;

    return 1;
}
// ---- the threshold filter and the grouping -------------------------------------------
//
// changeHdistLevelCached() ran all of this in the interpreter, from scratch, every time
// the user nudged a similarity slider: a pass over every surviving pair (millions on a
// large library), a union-find in AHK objects, and then sortDupeGroups() building one
// multi-megabyte "|"-delimited string, handing it to the Sort command and parsing it back.
// The pair list now stays in the DLL after the sweep, so a slider change is this function.
//
// Two behaviours are load-bearing and deliberately preserved:
//   - the smaller image index always wins as the union-find root, so a group's ID does
//     not depend on the order the pairs arrived in;
//   - BreakDupesGroups=1 keeps the OLD incremental single-pass labelling rather than the
//     union, because that option exists precisely to split a group by similarity.
// See [[qpv-2026-08-dupes-sweep]]. tests/filter_oracle.cpp fuzzes both against a
// transcription of the AHK they replaced.

// Path-compressed find. parent[] is seeded to the identity, and every union points the
// larger index at the smaller, so a component's root is always its smallest member.
static UINT dupesFindRoot(std::vector<UINT> &parent, UINT x) {
    UINT r = x;
    while (parent[r]!=r)
        r = parent[r];

    while (parent[x]!=r)
    {
        const UINT nx = parent[x];
        parent[x] = r;
        x = nx;
    }
    return r;
}

// isInRange() in AHK is inclusive at both ends.
QPV_FORCEINLINE bool dupesInRange(const UINT v, const int lo, const int hi) {
    return ((int)v >= lo && (int)v <= hi);
}

// Zero-padded to 9 digits, the way sortDupeGroups() formatted both halves of its sort key:
// the padding is what keeps the ordering numeric under a lexicographic sort, so group 100
// does not come before group 12 and row 100 does not come before row 7.
static void dupesAppendPad9(std::string &out, UINT v) {
    char buf[16];
    snprintf(buf, sizeof(buf), "%09u", v);
    out += buf;
}

// The group ID column 23 has always carried: the union-find root, an underscore, and the
// group's tightest Hamming distance. Not padded - this is the value the user sees.
static std::string dupesGroupID(UINT root, UINT tag) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%u_%u", root, tag);
    return std::string(buf);
}

// Applies the four threshold bounds to the pair list, groups what survives, drops the
// groups that are too small, and orders the result exactly as sortDupeGroups() did.
// Returns the number of result rows.
//
// imgKeep is the one filter AHK still owns - the path search string, which is a PCRE the
// DLL cannot evaluate - as one byte per image row index. NULL keeps everything.
// remSingles: a group survives when it has MORE than this many members, so 0 keeps
// everything and 1 is the "hide mono groups" setting.
DLL_API UINT DLL_CALLCONV dupesApplyFilter(int hamLo, int hamHi, int mseLo, int mseHi, int breakGroups, int remSingles, const unsigned char *imgKeep, UINT imgKeepCount) {
    dupesFilterRows.clear();
    const size_t n = dupesPairsList.size();
    if (n < 1)
       return 0;

    // testWasMSEdupes(): the MSD bounds only apply when the scan actually computed one.
    // The first two pairs standing in for the whole list is what the AHK did.
    const bool allowMSE = (n >= 2 && dupesPairsList[0].mse < QPV_MSD_NONE
                                  && dupesPairsList[1].mse < QPV_MSD_NONE);

    UINT maxId = 0;
    for ( size_t i = 0 ; i < n ; i++)
    {
        if (dupesPairsList[i].idA > maxId) maxId = dupesPairsList[i].idA;
        if (dupesPairsList[i].idB > maxId) maxId = dupesPairsList[i].idB;
    }

    std::vector<size_t> kept;
    kept.reserve(n);
    for ( size_t i = 0 ; i < n ; i++)
    {
        const DupePairRec &p = dupesPairsList[i];
        if (!dupesInRange(p.hamDist, hamLo, hamHi))
           continue;

        if (allowMSE && !dupesInRange(p.mse, mseLo, mseHi))
           continue;

        // the string filter was tested against the FIRST image of the pair only
        if (imgKeep!=NULL && (p.idA >= imgKeepCount || imgKeep[p.idA]==0))
           continue;

        kept.push_back(i);
    }

    if (kept.empty())
       return 0;

    const UINT NONE = 0xFFFFFFFFu;
    std::vector<UINT> rowRoot(maxId + 1, NONE), rowTag(maxId + 1, 0);
    std::vector<UINT> imgHam(maxId + 1, NONE), imgMSE(maxId + 1, NONE);

    if (breakGroups==1)
    {
       // The incremental labelling, walked in pair order: a pair whose images are both
       // already labelled only re-tags them with its own distance, a pair of two unlabelled
       // images starts a group at min(idA,idB), and a pair with one of each joins the
       // labelled one's group. Order-dependent by design - which is why the sweep emits
       // its pairs in a reproducible order.
       for ( size_t k = 0 ; k < kept.size() ; k++)
       {
           const DupePairRec &p = dupesPairsList[kept[k]];
           const bool hasA = (rowRoot[p.idA]!=NONE), hasB = (rowRoot[p.idB]!=NONE);
           if (hasA && hasB)
           {
              rowTag[p.idA] = p.hamDist;
              imgHam[p.idA] = p.hamDist;
              imgMSE[p.idA] = p.mse;
              rowTag[p.idB] = p.hamDist;
              imgHam[p.idB] = p.hamDist;
              imgMSE[p.idB] = p.mse;
              continue;
           }

           if (!hasA && !hasB)
           {
              const UINT root = (p.idA < p.idB) ? p.idA : p.idB;
              rowRoot[p.idA] = rowRoot[p.idB] = root;
              rowTag[p.idA] = rowTag[p.idB] = p.hamDist;
              imgHam[p.idA] = imgHam[p.idB] = p.hamDist;
              imgMSE[p.idA] = imgMSE[p.idB] = p.mse;
              continue;
           }

           const UINT root = hasA ? rowRoot[p.idA] : rowRoot[p.idB];
           // whichever of the two had no row yet gets one seeded at 100/2500, the same
           // values pullDupeRowFromCache() seeded, so the min() below can only go down
           if (!hasA) { imgHam[p.idA] = 100; imgMSE[p.idA] = QPV_MSD_NONE; }
           if (!hasB) { imgHam[p.idB] = 100; imgMSE[p.idB] = QPV_MSD_NONE; }
           rowRoot[p.idA] = rowRoot[p.idB] = root;
           rowTag[p.idA] = rowTag[p.idB] = p.hamDist;

           const UINT lowHam = (p.hamDist < imgHam[p.idA]) ? p.hamDist : imgHam[p.idA];
           const UINT lowHam2 = (lowHam < imgHam[p.idB]) ? lowHam : imgHam[p.idB];
           const UINT lowMSE = (p.mse < imgMSE[p.idA]) ? p.mse : imgMSE[p.idA];
           const UINT lowMSE2 = (lowMSE < imgMSE[p.idB]) ? lowMSE : imgMSE[p.idB];
           imgHam[p.idA] = lowHam2;
           imgMSE[p.idA] = lowMSE2;
           imgHam[p.idB] = p.hamDist;   // BreakDupesGroups keeps the pair's own values
           imgMSE[p.idB] = p.mse;       // on the second image rather than the minimum
       }
    }
    else
    {
       std::vector<UINT> parent(maxId + 1);
       for ( UINT i = 0 ; i <= maxId ; i++)
           parent[i] = i;

       for ( size_t k = 0 ; k < kept.size() ; k++)
       {
           const DupePairRec &p = dupesPairsList[kept[k]];
           const UINT ra = dupesFindRoot(parent, p.idA), rb = dupesFindRoot(parent, p.idB);
           if (ra!=rb)
              parent[(ra > rb) ? ra : rb] = (ra < rb) ? ra : rb;
       }

       // col 33/34 hold how close this image is to its nearest surviving match; the group
       // ID's suffix holds the tightest pair anywhere in the group
       std::vector<UINT> grpHam(maxId + 1, NONE);
       for ( size_t k = 0 ; k < kept.size() ; k++)
       {
           const DupePairRec &p = dupesPairsList[kept[k]];
           if (imgHam[p.idA]==NONE || p.hamDist < imgHam[p.idA]) imgHam[p.idA] = p.hamDist;
           if (imgHam[p.idB]==NONE || p.hamDist < imgHam[p.idB]) imgHam[p.idB] = p.hamDist;
           if (imgMSE[p.idA]==NONE || p.mse < imgMSE[p.idA])     imgMSE[p.idA] = p.mse;
           if (imgMSE[p.idB]==NONE || p.mse < imgMSE[p.idB])     imgMSE[p.idB] = p.mse;

           const UINT r = dupesFindRoot(parent, p.idA);
           if (grpHam[r]==NONE || p.hamDist < grpHam[r]) grpHam[r] = p.hamDist;
       }

       for ( UINT idu = 0 ; idu <= maxId ; idu++)
       {
           if (imgHam[idu]==NONE)
              continue;

           const UINT r = dupesFindRoot(parent, idu);
           rowRoot[idu] = r;
           rowTag[idu] = (grpHam[r]!=NONE) ? grpHam[r] : 0;
       }
    }

    // sortDupeGroups(): count members per ROOT but flag survival per FULL group ID, which
    // only differ under BreakDupesGroups - there the first remSingles members of a root
    // are left unflagged under whatever label they happen to carry. Reproduced rather
    // than tidied, because the option's whole point is that odd split.
    std::vector<UINT> seen(maxId + 1, 0);
    struct SortEnt { std::string key; std::string gid; UINT idu; };
    std::vector<SortEnt> order;
    std::vector<std::string> keepIDs;
    order.reserve(kept.size());
    UINT position = 0;
    for ( UINT idu = 0 ; idu <= maxId ; idu++)
    {
        if (rowRoot[idu]==NONE)
           continue;

        position++;   // the 1-based index of this row in ascending-idu order
        SortEnt e;
        e.idu = idu;
        e.gid = dupesGroupID(rowRoot[idu], rowTag[idu]);

        seen[rowRoot[idu]]++;
        if (seen[rowRoot[idu]] > (UINT)((remSingles > 0) ? remSingles : 0))
           keepIDs.push_back(e.gid);

        dupesAppendPad9(e.key, rowRoot[idu]);
        e.key += 'y';
        e.key += e.gid;
        e.key += 'z';
        dupesAppendPad9(e.key, position);
        order.push_back(e);
    }

    std::sort(order.begin(), order.end(), [](const SortEnt &a, const SortEnt &b) { return a.key < b.key; });
    std::sort(keepIDs.begin(), keepIDs.end());

    dupesFilterRows.reserve(order.size());
    for ( size_t i = 0 ; i < order.size() ; i++)
    {
        if (!std::binary_search(keepIDs.begin(), keepIDs.end(), order[i].gid))
           continue;

        const UINT idu = order[i].idu;
        DupeResultRow row;
        row.imgIndex = idu;
        row.groupRoot = rowRoot[idu];
        row.grpTag = rowTag[idu];
        row.hamDist = (imgHam[idu]!=NONE) ? imgHam[idu] : 100;
        row.mse = (imgMSE[idu]!=NONE) ? imgMSE[idu] : QPV_MSD_NONE;
        dupesFilterRows.push_back(row);
    }

    return (UINT)dupesFilterRows.size();
}

DLL_API UINT DLL_CALLCONV dupesFilterRowCount() {
    return (UINT)dupesFilterRows.size();
}

DLL_API UINT DLL_CALLCONV dupesFetchFiltered(void *outArray, UINT firstIndex, UINT maxItems) {
    if (outArray==NULL || maxItems==0 || firstIndex >= dupesFilterRows.size())
       return 0;

    size_t n = dupesFilterRows.size() - firstIndex;
    if (n > (size_t)maxItems)
       n = (size_t)maxItems;

    memcpy(outArray, dupesFilterRows.data() + firstIndex, n * sizeof(DupeResultRow));
    return (UINT)n;
}

// How many pairs the last sweep produced. AHK used to hold them all in an array of
// four-element arrays purely so it could ask this and re-filter them.
DLL_API UINT DLL_CALLCONV dupesPairCount() {
    return (UINT)dupesPairsList.size();
}

// What testWasMSEdupes() answered: whether the scan actually computed similarity scores,
// which is what decides if the MSD sliders mean anything. Sampling only the first two pairs
// was too thin - a sweep can legitimately leave the leading pairs without a score. Sample
// the first half of the list instead, but keep the old bar of two scored pairs so a single
// stray score cannot switch the sliders on, and stop the moment the second one turns up:
// only a genuinely score-less list pays for the whole walk. The sample never drops below
// two entries, otherwise short lists could not clear the bar no matter what they hold.
DLL_API int DLL_CALLCONV dupesHaveMSD() {
    size_t total = dupesPairsList.size();
    if (total < 2)
       return 0;

    size_t n = total / 2;
    if (n < 2)
       n = 2;

    int k = 0;
    for (size_t i=0; i<n; i++)
    {
        if (dupesPairsList[i].mse < QPV_MSD_NONE)
        {
           k++;
           if (k>1)
              return 1;
        }
    }

    return 0;
}

// qpv-dupes-block-end - tests/run-tests.sh slices from the SWAR comment above down to
// this line and compiles it against Windows shims. Leave the marker in place.

// ---- the candidate query engine and hash generation -----------------------------------

// qpv-dupes-query-begin - the candidate query engine; sliced separately by the tests
// because it needs sqlite3 stubs the sweep does not.
//
// AHK used to run this query through Class_SQLiteDB.GetTable(), which is the legacy
// sqlite3_get_table() - it materialises the ENTIRE result set as a char** table, and the
// AHK class then copies all of it again into an array of per-row arrays. With MSD on, the
// SELECT drags a 2 KB fingerprint through every candidate row, so both copies carried it.
// AHK then walked the rows one at a time to build resultedFilesList and two hashtables.
//
// Here the DLL steps the statement itself: nothing is materialised twice, the fingerprints
// are decoded straight into the flat byte array the sweep compares, the hashes are parsed
// into UINT64 on the way past, and only images that actually landed in a group of two or
// more are kept. The query is also interruptible for the first time - GetTable() had no
// cancel path at all, and on a large library it runs for minutes.
//
// The grouping moved out of SQL with it. The old query discovered groups with a self-join
// against a GROUP BY subquery: full scan, temp B-tree, second scan, join probe. The rows
// now arrive sorted by the same key columns, so a group is simply a run of consecutive
// rows whose key tuple is unchanged - one scan and one sort.
//
// Reproducing SQLite's equality in C++ is the delicate part of that, and
// tests/sql_grouping.py is the specification: it diffs the two groupings over every column
// set the Find Duplicates panel can build. Two rules came out of it that are easy to miss:
//
//   - a row with a NULL in ANY key column is not a candidate. The old ON clause was a
//     chain of "=", and NULL = NULL is NULL rather than true, so no row of "a" ever joined
//     to the NULL bucket GROUP BY had made. Keeping those rows would invent enormous
//     phantom groups of everything that shares a missing property.
//   - imgfile and imgpixfmt are declared COLLATE NOCASE, so both the GROUP BY and the
//     ORDER BY fold ASCII case on them and the key builder has to fold it too.

static sqlite3      *dupesDB = NULL;      // private, read-only; AHK keeps its own handle
static sqlite3_stmt *dupesStmt = NULL;
static std::atomic<int> dupesCancelFlag(0);
static std::wstring  dupesEngineError;

// Read by the fingerprint collection pool of dupes-pixels.h, which is included much
// further down but has to answer the same cancel the query engine answers: the user only
// ever presses one "stop", and stopDupesEngineNow() only knows about dupesEngineCancel().
static std::atomic<int> dupesPixCancel(0);

struct DupesQueryCfg {
    int  keyCount = 0;
    UINT nocaseMask = 0;      // bit k set when key column k is COLLATE NOCASE
    int  hasHash = 0;
    int  hasFlip = 0;
    int  hasPix = 0;
    int  pixStride = 0;
    int  grayCompressor = 1;
};
static DupesQueryCfg dupesQCfg;

// scan cursor: where the current run of equal-key rows began in the output arrays
static size_t dupesRunStart = 0;
static bool   dupesRunOpen = false;
static std::vector<unsigned char> dupesKeyCur, dupesKeyPrev;

static void dupesSetError(const wchar_t *what) {
    dupesEngineError = (what!=NULL) ? what : L"";
    if (dupesDB!=NULL && SQ.errmsg16!=NULL)
    {
       const wchar_t *m = (const wchar_t*)SQ.errmsg16(dupesDB);
       if (m!=NULL && m[0]!=0)
       {
          dupesEngineError += L": ";
          dupesEngineError += m;
       }
    }
}

// SQLite calls this every few thousand VM instructions, INCLUDING while it is sorting,
// which is the one place a step budget cannot reach. Returning non-zero aborts the
// statement with SQLITE_INTERRUPT. The flag is set by dupesEngineCancel(), which the
// interface thread calls when the user answers "yes" to "stop the current operation" -
// the main AHK thread is inside sqlite3_step() at that moment and cannot ask anything.
static int __cdecl dupesProgressCB(void*) {
    return dupesCancelFlag.load(std::memory_order_relaxed) ? 1 : 0;
}

// Opens the engine's own read-only connection on the database AHK already has open.
// Read-only makes the whole scan path incapable of touching the file, whatever else goes
// wrong, and leaves AHK's handle free to be used concurrently.
DLL_API int DLL_CALLCONV dupesEngineInit(const wchar_t *dbPath) {
    bindSQLiteOnce();
    if (!SQ.ok || dbPath==NULL || dbPath[0]==0)
       return 0;

    if (dupesStmt!=NULL) { SQ.finalize(dupesStmt); dupesStmt = NULL; }
    if (dupesDB!=NULL)   { SQ.close_v2(dupesDB);   dupesDB = NULL; }

    const int need = WideCharToMultiByte(CP_UTF8, 0, dbPath, -1, NULL, 0, NULL, NULL);
    if (need <= 0)
       return 0;

    std::vector<char> utf8((size_t)need);
    WideCharToMultiByte(CP_UTF8, 0, dbPath, -1, utf8.data(), need, NULL, NULL);

    // FULLMUTEX because dupesEngineCancel() reaches this handle from the interface
    // thread; sqlite3_interrupt() is documented as safe either way, but a serialized
    // connection removes the question. A single-threaded build of sqlite3.dll ignores it.
    const int rc = SQ.open_v2(utf8.data(), &dupesDB, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, NULL);
    if (rc!=SQLITE_OK || dupesDB==NULL)
    {
       dupesSetError(L"could not open the database read-only");
       if (dupesDB!=NULL) { SQ.close_v2(dupesDB); dupesDB = NULL; }
       return 0;
    }

    dupesCancelFlag.store(0, std::memory_order_relaxed);
    if (SQ.progress_handler!=NULL)
       SQ.progress_handler(dupesDB, 4096, dupesProgressCB, NULL);

    // The database is opened by AHK with no pragmas at all. These two only affect this
    // connection and only make the scan cheaper: the ORDER BY sorts in RAM, and 64 MB of
    // page cache spares a re-read of the table on a second scan.
    if (SQ.exec!=NULL)
       SQ.exec(dupesDB, "PRAGMA temp_store=MEMORY; PRAGMA cache_size=-65536;", NULL, NULL, NULL);

    return 1;
}

DLL_API int DLL_CALLCONV dupesEngineRelease() {
    if (SQ.ok)
    {
       if (dupesStmt!=NULL) { SQ.finalize(dupesStmt); dupesStmt = NULL; }
       if (dupesDB!=NULL)
       {
          if (SQ.progress_handler!=NULL)
             SQ.progress_handler(dupesDB, 0, NULL, NULL);

          SQ.close_v2(dupesDB);
          dupesDB = NULL;
       }
    }

    dupesCandRows.clear();  dupesCandRows.shrink_to_fit();
    dupesPathBuf.clear();   dupesPathBuf.shrink_to_fit();
    dupesKeyCur.clear();    dupesKeyCur.shrink_to_fit();
    dupesKeyPrev.clear();   dupesKeyPrev.shrink_to_fit();
    dupesCandGroups = 0;
    dupesRunStart = 0;
    dupesRunOpen = false;
    return 1;
}

// Safe to call from any thread - and meant to be: the AHK thread that started the scan is
// blocked inside sqlite3_step() while SQLite sorts, so only another thread can stop it.
DLL_API int DLL_CALLCONV dupesEngineCancel() {
    dupesCancelFlag.store(1, std::memory_order_relaxed);
    dupesPixCancel.store(1, std::memory_order_relaxed);
    if (SQ.ok && dupesDB!=NULL && SQ.interrupt!=NULL)
       SQ.interrupt(dupesDB);

    return 1;
}

DLL_API int DLL_CALLCONV dupesEngineReady() {
    bindSQLiteOnce();
    return (SQ.ok && dupesDB!=NULL) ? 1 : 0;
}

// Copies the last error out for the journal. Returns the number of characters written.
DLL_API int DLL_CALLCONV dupesEngineLastError(wchar_t *buf, int maxChars) {
    if (buf==NULL || maxChars < 1)
       return 0;

    int n = (int)dupesEngineError.size();
    if (n > maxChars - 1)
       n = maxChars - 1;

    if (n > 0)
       memcpy(buf, dupesEngineError.data(), (size_t)n * sizeof(wchar_t));

    buf[n] = 0;
    return n;
}

static void appendKeyBytes(std::vector<unsigned char> &out, const void *p, size_t n) {
    const unsigned char *b = (const unsigned char*)p;
    out.insert(out.end(), b, b + n);
}

// Builds the flat comparison key for the row the statement is sitting on: one tag byte
// per key column followed by its payload, so two rows belong to the same group exactly
// when their key blobs are identical. Returns false when any key column is NULL, which
// means the row is not a candidate at all (see the header comment).
static bool buildRowKey(sqlite3_stmt *st, const int firstCol, const int count, const UINT nocaseMask, std::vector<unsigned char> &out) {
    out.clear();
    for ( int k = 0 ; k < count ; k++)
    {
        const int col = firstCol + k;
        const int t = SQ.column_type(st, col);
        if (t==SQLITE_NULL)
           return false;

        if (t==SQLITE_INTEGER)
        {
           const sqlite3_int64 v = SQ.column_int64(st, col);
           const double d = (double)v;
           if ((sqlite3_int64)d == v)
           {
              out.push_back(1);            // numeric: an INTEGER and a REAL of the same
              appendKeyBytes(out, &d, sizeof(d));   // value compare equal in SQLite
           } else
           {
              out.push_back(2);            // past 2^53 a double cannot stand in for it;
              appendKeyBytes(out, &v, sizeof(v));   // no such value occurs in this schema
           }
        }
        else if (t==SQLITE_FLOAT)
        {
           double d = SQ.column_double(st, col);
           if (d==0.0)                     // fold -0.0: its bits differ from +0.0 but
              d = 0.0;                     // SQLite compares the two equal

           out.push_back(1);
           appendKeyBytes(out, &d, sizeof(d));
        }
        else if (t==SQLITE_TEXT)
        {
           const wchar_t *s = (const wchar_t*)SQ.column_text16(st, col);
           int n = (s!=NULL) ? SQ.column_bytes16(st, col) / (int)sizeof(wchar_t) : 0;
           if (n < 0) n = 0;
           out.push_back(3);
           appendKeyBytes(out, &n, sizeof(n));
           const bool fold = ((nocaseMask >> k) & 1u)!=0;
           for ( int i = 0 ; i < n ; i++)
           {
               wchar_t c = s[i];
               if (fold && c >= L'A' && c <= L'Z')   // SQLite's NOCASE folds ASCII only,
                  c = (wchar_t)(c + 32);             // and so does this

               appendKeyBytes(out, &c, sizeof(c));
           }
        }
        else
        {
           const unsigned char *b = (const unsigned char*)SQ.column_blob(st, col);
           int n = (b!=NULL) ? SQ.column_bytes(st, col) : 0;
           if (n < 0) n = 0;
           out.push_back(4);
           appendKeyBytes(out, &n, sizeof(n));
           if (n > 0)
              out.insert(out.end(), b, b + n);
        }
    }
    return true;
}

// The hashes are stored by ConvertBase(10,16,...) / ConvertBase(2,16,...), which is
// _i64tow with radix 16: lowercase hex, no prefix, no sign, no fixed width.
// AHK read them back as "0x" . hash, which turned an unusable value into 0 - and a hash
// of 0 sits at distance 0 from every other image with few set bits, which is exactly the
// phantom-group shape the ifnull() guard in the WHERE clause exists to prevent. Here an
// unparseable hash drops the row instead.
static bool parseHexHash(const wchar_t *s, int n, UINT64 &out) {
    out = 0;
    if (s==NULL || n < 1 || n > 16)
       return false;

    for ( int i = 0 ; i < n ; i++)
    {
        const wchar_t c = s[i];
        int v;
        if (c >= L'0' && c <= L'9')       v = c - L'0';
        else if (c >= L'a' && c <= L'f')  v = c - L'a' + 10;
        else if (c >= L'A' && c <= L'F')  v = c - L'A' + 10;
        else return false;

        out = (out << 4) | (UINT64)v;
    }
    return true;
}

// Releases the candidate rows and the path blob. Not static: dupesScanEnd() and
// dupesClearPairs() sit above the query engine and forward-declare it, so the sweep can
// hand back every byte of a scan without knowing how the rows were obtained.
void dupesQueryFreeRows() {
    dupesCandRows.clear();  dupesCandRows.shrink_to_fit();
    dupesPathBuf.clear();   dupesPathBuf.shrink_to_fit();
    dupesKeyCur.clear();    dupesKeyCur.shrink_to_fit();
    dupesKeyPrev.clear();   dupesKeyPrev.shrink_to_fit();
    dupesCandGroups = 0;
    dupesRunStart = 0;
    dupesRunOpen = false;
}

static void dupesQueryReset() {
    dupesCandRows.clear();
    dupesPathBuf.clear();
    dupesScanHashes.clear();
    dupesScanFlipped.clear();
    dupesScanIDs.clear();
    dupesScanGroupStart.clear();
    dupesScanRowEnd.clear();
    dupesPixData.clear();
    dupesPixOK.clear();
    dupesPairsList.clear();
    dupesKeyCur.clear();
    dupesKeyPrev.clear();
    dupesPairsRead = 0;
    dupesCandGroups = 0;
    dupesRunStart = 0;
    dupesRunOpen = false;
    dupesScanRows = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 0;
    memset((void*)&dupesScanState, 0, sizeof(dupesScanState));
}

// Schema v3 keeps the fingerprints as raw BLOBs in imagesPixels, one byte per pixel: the
// Chr(gray + 161) encoding above only ever existed so the values could survive being
// pasted into an SQL string literal, which bound parameters make unnecessary. Half the
// bytes, and the decode collapses to the grayCompressor division - which still has to
// happen here, exactly as above, because msdScore() multiplies the level back in.
static void decodeFingerprintBytes(const unsigned char *blob, const UINT firstIndex, const UINT count) {
    if (blob==NULL || count==0 || dupesPixStride==0)
       return;

    const UINT stride = dupesPixStride;
    if ((size_t)(firstIndex + count) * stride > dupesPixData.size() || firstIndex + count > dupesPixOK.size())
       return;

    for ( UINT rec = 0 ; rec < count ; rec++)
    {
        const unsigned char *src = blob + (size_t)rec * stride;
        unsigned char *dst = &dupesPixData[(size_t)(firstIndex + rec) * stride];
        if (dupesPixScale > 1)
        {
           for ( UINT k = 0 ; k < stride ; k++)
               dst[k] = (unsigned char)floor((double)src[k] / dupesPixScale + 0.5);
        } else
           memcpy(dst, src, stride);

        dupesPixOK[firstIndex + rec] = 1;
    }
}

// Drops the run that is still open back off the output arrays. A run of one is not a
// duplicate group, and the old query never produced one: HAVING count(*)>1.
static void dupesCloseRun() {
    if (!dupesRunOpen)
       return;

    const size_t n = dupesCandRows.size();
    if (n - dupesRunStart >= 2)
    {
       dupesCandGroups++;
       for ( size_t i = dupesRunStart ; i < n ; i++)
           dupesCandRows[i].groupID = dupesCandGroups;
    } else
    {
       // truncate every parallel array back to where the run began
       if (dupesRunStart < n)
          dupesPathBuf.resize(dupesCandRows[dupesRunStart].pathOffset);

       dupesCandRows.resize(dupesRunStart);
       dupesScanHashes.resize(dupesRunStart);
       if (!dupesScanFlipped.empty())
          dupesScanFlipped.resize(dupesRunStart);

       if (dupesQCfg.hasPix==1 && dupesPixStride > 0)
       {
          dupesPixData.resize(dupesRunStart * dupesPixStride);
          dupesPixOK.resize(dupesRunStart);
       }
    }

    dupesRunOpen = false;
}

// Prepares the candidate query. The SELECT must list, in this exact order:
//   imgidu, fullPath, imgmegapix, fsize [, hash] [, flippedHash] [, fingerprint],
//   then keyCount grouping key expressions,
// and must ORDER BY those key expressions followed by imgmegapix, fsize - the sort is
// what makes a group a run of consecutive rows, and the tail keeps the within-group order
// the old query produced.
DLL_API int DLL_CALLCONV dupesQueryBegin(const wchar_t *sql, int keyCount, UINT nocaseMask, int hasHash, int hasFlip, int hasPix, int pixStride, int grayCompressor) {
    bindSQLiteOnce();
    dupesEngineError.clear();
    if (!SQ.ok || dupesDB==NULL || sql==NULL || keyCount < 1)
       return 0;

    if (dupesStmt!=NULL) { SQ.finalize(dupesStmt); dupesStmt = NULL; }

    dupesQueryReset();
    dupesCancelFlag.store(0, std::memory_order_relaxed);
    dupesQCfg.keyCount = keyCount;
    dupesQCfg.nocaseMask = nocaseMask;
    dupesQCfg.hasHash = (hasHash==1) ? 1 : 0;
    dupesQCfg.hasFlip = (hasFlip==1) ? 1 : 0;
    dupesQCfg.hasPix  = (hasPix==1 && pixStride > 0) ? 1 : 0;
    dupesQCfg.pixStride = pixStride;
    dupesQCfg.grayCompressor = (grayCompressor > 1) ? grayCompressor : 1;
    if (dupesQCfg.hasPix==1)
    {
       dupesPixStride = (UINT)pixStride;
       dupesPixScale = dupesQCfg.grayCompressor;
       dupesScanWantMSD = 1;
    } else
    {
       dupesPixStride = 0;
       dupesPixScale = 1;
       dupesScanWantMSD = 0;
    }

    const int rc = SQ.prepare16_v2(dupesDB, sql, -1, &dupesStmt, NULL);
    if (rc!=SQLITE_OK || dupesStmt==NULL)
    {
       dupesSetError(L"could not prepare the duplicates query");
       dupesStmt = NULL;
       dupesScanState.lastError = 3;
       dupesScanState.phase = -1;
       return 0;
    }

    // the column count is fixed by the layout above; a mismatch means the caller and the
    // DLL disagree about the SELECT, which would silently read the wrong columns
    const int want = 4 + dupesQCfg.hasHash + dupesQCfg.hasFlip + dupesQCfg.hasPix + keyCount;
    if (SQ.column_count!=NULL && SQ.column_count(dupesStmt)!=want)
    {
       dupesSetError(L"the duplicates query does not have the expected column layout");
       SQ.finalize(dupesStmt);
       dupesStmt = NULL;
       dupesScanState.lastError = 4;
       dupesScanState.phase = -1;
       return 0;
    }

    dupesScanState.phase = 2;
    return 1;
}

// Steps the query for up to msBudget milliseconds. Returns 1 while rows remain, 0 when
// the whole result set has been consumed and the groups are closed, -1 on error or when
// the user cancelled.
DLL_API int DLL_CALLCONV dupesQueryStep(int msBudget) {
    if (!SQ.ok || dupesStmt==NULL)
       return -1;

    if (msBudget < 1)
       msBudget = 1;

    const int base = 4 + dupesQCfg.hasHash + dupesQCfg.hasFlip + dupesQCfg.hasPix;
    const int colHash = dupesQCfg.hasHash ? 4 : -1;
    const int colFlip = dupesQCfg.hasFlip ? (4 + dupesQCfg.hasHash) : -1;
    const int colPix  = dupesQCfg.hasPix  ? (4 + dupesQCfg.hasHash + dupesQCfg.hasFlip) : -1;
    const UINT stride = (UINT)dupesQCfg.pixStride;
    const std::chrono::steady_clock::time_point tStart = std::chrono::steady_clock::now();
    int sinceClock = 0;

    for (;;)
    {
        const int rc = SQ.step(dupesStmt);
        if (rc==SQLITE_ROW)
        {
           dupesScanState.scanned++;
           if (!buildRowKey(dupesStmt, base, dupesQCfg.keyCount, dupesQCfg.nocaseMask, dupesKeyCur))
           {
              // a NULL key column: not a candidate, and it also breaks the run - two rows
              // either side of it are not adjacent as far as grouping is concerned
              dupesCloseRun();
              dupesKeyPrev.clear();
           }
           else
           {
              UINT64 hash = 0, flip = 0;
              bool usable = true;
              if (colHash >= 0)
              {
                 const wchar_t *h = (const wchar_t*)SQ.column_text16(dupesStmt, colHash);
                 usable = parseHexHash(h, (h!=NULL) ? SQ.column_bytes16(dupesStmt, colHash) / (int)sizeof(wchar_t) : 0, hash);
                 flip = hash;
                 if (usable && colFlip >= 0)
                 {
                    const wchar_t *f = (const wchar_t*)SQ.column_text16(dupesStmt, colFlip);
                    // no flipped hash stored: mirroring its own hash makes the flipped
                    // comparison degenerate to the ordinary one, which is harmless. A 0
                    // would have matched every sparse hash in the group.
                    if (!parseHexHash(f, (f!=NULL) ? SQ.column_bytes16(dupesStmt, colFlip) / (int)sizeof(wchar_t) : 0, flip))
                       flip = hash;
                 }
              }

              if (!usable)
              {
                 dupesCloseRun();
                 dupesKeyPrev.clear();
              }
              else
              {
                 if (!dupesRunOpen || dupesKeyPrev!=dupesKeyCur)
                 {
                    dupesCloseRun();
                    dupesRunStart = dupesCandRows.size();
                    dupesRunOpen = true;
                    dupesKeyPrev = dupesKeyCur;
                 }

                 DupeCandRow row;
                 row.imgidu = (INT64)SQ.column_int64(dupesStmt, 0);
                 row.megapix = SQ.column_double(dupesStmt, 2);
                 row.fsize = (INT64)SQ.column_int64(dupesStmt, 3);
                 row.groupID = 0;
                 row.pathOffset = (UINT)dupesPathBuf.size();

                 const wchar_t *p = (const wchar_t*)SQ.column_text16(dupesStmt, 1);
                 const int plen = (p!=NULL) ? SQ.column_bytes16(dupesStmt, 1) / (int)sizeof(wchar_t) : 0;
                 if (plen > 0)
                    dupesPathBuf.append(p, (size_t)plen);

                 dupesPathBuf.push_back(L'\0');
                 dupesCandRows.push_back(row);
                 dupesScanHashes.push_back(hash);
                 if (colFlip >= 0)
                    dupesScanFlipped.push_back(flip);

                 if (colPix >= 0)
                 {
                    const size_t slot = dupesCandRows.size() - 1;
                    dupesPixData.resize((slot + 1) * stride, 0);
                    dupesPixOK.resize(slot + 1, 0);
                    const unsigned char *px = (const unsigned char*)SQ.column_blob(dupesStmt, colPix);
                    const int pxlen = (px!=NULL) ? SQ.column_bytes(dupesStmt, colPix) : 0;
                    // a fingerprint of the wrong length is treated as absent rather than
                    // decoded short: a partial one would score as a near-perfect match
                    if (px!=NULL && pxlen==(int)stride)
                       decodeFingerprintBytes(px, (UINT)slot, 1);
                 }
              }
           }

           if (++sinceClock >= 256)
           {
              sinceClock = 0;
              if (std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tStart).count() >= msBudget)
                 return 1;
           }
           continue;
        }

        if (rc==SQLITE_DONE)
        {
           dupesCloseRun();
           SQ.finalize(dupesStmt);
           dupesStmt = NULL;
           dupesScanState.queryDone = 1;
           dupesScanState.rows = (LONG)dupesCandRows.size();
           dupesScanState.groups = (LONG)dupesCandGroups;
           return 0;
        }

        // SQLITE_INTERRUPT is the cancel path; anything else is a real failure
        dupesSetError((rc==SQLITE_INTERRUPT) ? L"the duplicates query was cancelled" : L"the duplicates query failed");
        SQ.finalize(dupesStmt);
        dupesStmt = NULL;
        dupesScanState.lastError = (rc==SQLITE_INTERRUPT) ? 0 : 5;
        dupesScanState.phase = -1;
        return -1;
    }
}

DLL_API UINT DLL_CALLCONV dupesQueryRowCount() {
    return (UINT)dupesCandRows.size();
}

DLL_API UINT DLL_CALLCONV dupesQueryGroupCount() {
    return dupesCandGroups;
}

// The path buffer every DupeCandRow.pathOffset indexes into. Valid until the next
// dupesQueryBegin() or dupesEngineRelease().
DLL_API void* DLL_CALLCONV dupesGetPathBuffer() {
    return (void*)dupesPathBuf.c_str();
}

DLL_API UINT DLL_CALLCONV dupesFetchRows(void *outArray, UINT firstIndex, UINT maxItems) {
    if (outArray==NULL || maxItems==0 || firstIndex >= dupesCandRows.size())
       return 0;

    size_t n = dupesCandRows.size() - firstIndex;
    if (n > (size_t)maxItems)
       n = (size_t)maxItems;

    memcpy(outArray, dupesCandRows.data() + firstIndex, n * sizeof(DupeCandRow));
    return (UINT)n;
}

// Turns the query results into the sweep's candidate set. keepMask carries one byte per
// query row - 0 drops it - which is how AHK applies the filters it cannot push into SQL:
// the path regex and the "exclude the duplicates already in the list" set. Pass NULL to
// keep everything.
//
// Dropping rows can leave a group with a single member, and a group of one has nothing to
// compare, so the boundaries are recomputed rather than reused; the sweep then simply
// steps over the singletons.
//
// idBase is where AHK appended the first kept row: the sweep reports pairs by
// resultedFilesList row index, and the kept rows land there consecutively, so row k gets
// idBase + k + 1.
DLL_API int DLL_CALLCONV dupesScanBuildFromQuery(const unsigned char *keepMask, UINT maskCount, UINT idBase) {
    const UINT total = (UINT)dupesCandRows.size();
    if (total < 2)
    {
       dupesScanRows = 0;
       dupesScanState.phase = 5;
       return 0;
    }

    if (keepMask!=NULL && maskCount < total)
       return 0;

    const bool wantPix = (dupesScanWantMSD==1 && dupesPixStride > 0 && dupesPixData.size() >= (size_t)total * dupesPixStride);
    const bool wantFlip = (dupesScanFlipped.size() >= total);
    UINT kept = 0;
    UINT prevGroup = 0;
    dupesScanGroupStart.clear();
    dupesScanIDs.clear();
    dupesScanIDs.reserve(total);

    for ( UINT i = 0 ; i < total ; i++)
    {
        if (keepMask!=NULL && keepMask[i]==0)
           continue;

        const UINT g = dupesCandRows[i].groupID;
        if (g!=prevGroup)
        {
           dupesScanGroupStart.push_back(kept);
           prevGroup = g;
        }

        // compact in place: kept <= i always, so this never overwrites a row it still
        // has to read
        dupesScanHashes[kept] = dupesScanHashes[i];
        if (wantFlip)
           dupesScanFlipped[kept] = dupesScanFlipped[i];

        if (wantPix)
        {
           if (kept!=i)
              memmove(&dupesPixData[(size_t)kept * dupesPixStride], &dupesPixData[(size_t)i * dupesPixStride], dupesPixStride);

           dupesPixOK[kept] = dupesPixOK[i];
        }

        dupesScanIDs.push_back(idBase + kept + 1);
        kept++;
    }

    dupesScanHashes.resize(kept);
    if (wantFlip)
       dupesScanFlipped.resize(kept);

    if (wantPix)
    {
       dupesPixData.resize((size_t)kept * dupesPixStride);
       dupesPixOK.resize(kept);
    }

    dupesScanRows = kept;
    dupesScanState.rows = (LONG)kept;
    if (kept < 2 || dupesScanGroupStart.empty())
    {
       dupesScanState.phase = 5;
       return 0;
    }

    dupesScanGroupStart.push_back(kept);
    if (!dupesScanBuildRowEnd())
    {
       dupesScanGroupStart.clear();
       dupesScanState.lastError = 1;
       dupesScanState.phase = -1;
       return 0;
    }

    INT64 comparisons = 0;
    for ( size_t g = 0 ; g + 1 < dupesScanGroupStart.size() ; g++)
    {
        const INT64 m = (INT64)(dupesScanGroupStart[g + 1] - dupesScanGroupStart[g]);
        comparisons += m * (m - 1) / 2;
    }

    dupesScanState.groups = (LONG)(dupesScanGroupStart.size() - 1);
    dupesScanState.total = comparisons;
    dupesScanState.done = 0;
    dupesScanState.pairs = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 1 << 16;
    dupesScanState.phase = 3;
    return 1;
}
// ---- hash generation ------------------------------------------------------------------
//
// generateSQLimageFingerPrintHash() produced 8 bytes per image through roughly three to
// five thousand interpreted operations: StrSplit() of the fingerprint into an AHK array,
// a per-element loop calling Ord() and discretizeValue(), then a 64-iteration loop
// building a binary STRING, then ConvertBase() through two msvcrt DllCalls - and for
// pHash, a 1024-iteration NumPut loop whose only purpose was to marshal the array the
// previous loop had just built. Every image also cost one string-built UPDATE statement,
// parsed from scratch by SQLite.
//
// Here the fingerprint is decoded once into ints, the hash is a few dozen arithmetic
// operations, the batch is hashed across cores, and the UPDATE is a prepared statement
// bound and reset per row. The values are identical: tests/hash_oracle.cpp checks all
// three against a transcription of the AHK across every graylevelCompressor level.
//
// Reads and writes both go through the handle AHK owns, deliberately. The engine's own
// read-only connection would not see the rows this loop has already updated inside AHK's
// open transaction, so they would come back as "hash IS NULL" on the next batch forever.

DLL_API INT64 DLL_CALLCONV calcPHashAlgo(unsigned char *givenArray, UINT size, int compareMethod);

static sqlite3      *dupesHashDB = NULL;     // AHK's handle - never the engine's
static sqlite3_stmt *dupesHashSel = NULL;
static sqlite3_stmt *dupesHashUpd = NULL;
static int   dupesHashKind = 0, dupesHashPix = 0, dupesHashGray = 1, dupesHashMode = 1;
static INT64 dupesHashWritten = 0, dupesHashFailed = 0, dupesHashSeen = 0;
// images whose stored fingerprint is not the length this hash needs. They are not write
// failures - the write succeeds, it just has nothing to write - so they are counted apart
// from dupesHashFailed, which AHK reports as "failed to commit to database".
static INT64 dupesHashSkipped = 0;

// discretizeValue(v, level) -> Round(v/level)*level, and AHK's Round() is half away from
// zero. Note this is the PRODUCT, not the quotient the MSD path stores: dHash and lHash
// compare and average these numbers rather than packing them into bytes, so 256 is a
// perfectly good value here. pHash is the exception - see below.
QPV_FORCEINLINE int dupesDiscretize(int v, int level) {
    if (level <= 1)
       return v;

    return (int)floor((double)v / level + 0.5) * level;
}

// 9x8 = 72 gray levels; every 9th value is skipped so the 64 comparisons never straddle a
// row. The first comparison is the most significant bit, because AHK built a binary
// string left to right and ConvertBase(2,16,...) reads it MSB first.
static UINT64 dupesDHash(const int *p) {
    UINT64 h = 0;
    for ( int i = 0 ; i < 72 ; i++)
    {
        if (((i + 1) % 9)==0)
           continue;

        h = (h << 1) | ((p[i] < p[i + 1]) ? 1ull : 0ull);
    }
    return h;
}

// The leftmost 8x8 block of the same 9x8 fingerprint: every pixel against the mean of its
// row mean and its column mean. The exact float mean is used on purpose - rounding it
// first creates ties between the pixel and its threshold.
static UINT64 dupesLHash(const int *p) {
    double rowMean[8], colMean[8];
    for ( int r = 0 ; r < 8 ; r++)
    {
        double s = 0.0;
        for ( int c = 0 ; c < 8 ; c++)
            s += p[r * 9 + c];

        rowMean[r] = s / 8.0;
    }

    for ( int c = 0 ; c < 8 ; c++)
    {
        double s = 0.0;
        for ( int r = 0 ; r < 8 ; r++)
            s += p[r * 9 + c];

        colMean[c] = s / 8.0;
    }

    UINT64 h = 0;
    for ( int r = 0 ; r < 8 ; r++)
        for ( int c = 0 ; c < 8 ; c++)
        {
            const double avg = (colMean[c] + rowMean[r]) / 2.0;
            h = (h << 1) | ((p[r * 9 + c] > avg) ? 1ull : 0ull);
        }

    return h;
}

// The 32x32 fingerprint, marshalled into the bytes calcPHashAlgo() reads.
// The truncation is not an oversight: AHK wrote these with NumPut(..., "UChar"), so a
// discretised 256 became 0, and every stored pHash was computed that way.
static UINT64 dupesPHash(const int *p, int mode) {
    unsigned char buf[1024];
    for ( int i = 0 ; i < 1024 ; i++)
        buf[i] = (unsigned char)(p[i] & 0xFF);

    return (UINT64)calcPHashAlgo(buf, 32, mode);
}

// ConvertBase(10,16,...) and ConvertBase(2,16,...) are both _i64tow with radix 16:
// lowercase hex, unsigned, no prefix and no leading zeros. A hash of 0 is stored as "0".
static void dupesHexHash(UINT64 v, wchar_t *out, int cap) {
    char tmp[32];
    snprintf(tmp, sizeof(tmp), "%llx", (unsigned long long)v);
    int i = 0;
    while (tmp[i]!=0 && i < cap - 1)
    {
        out[i] = (wchar_t)tmp[i];
        i++;
    }
    out[i] = 0;
}

// selectSQL must end in "LIMIT ?1" - the batch size is bound, and rows leave the result
// set as they are updated, so re-running it is what advances the cursor.
// updateSQL takes the hash as ?1 and the imgidu as ?2.
// hashKind: 2 dHash, 3 pHash, 4 lHash. pixCount: 72 for dHash/lHash, 1024 for pHash.
DLL_API int DLL_CALLCONV dupesHashBegin(void *ahkDb, const wchar_t *selectSQL, const wchar_t *updateSQL, int hashKind, int pixCount, int grayCompressor, int pHashMode) {
    bindSQLiteOnce();
    dupesEngineError.clear();
    if (!SQ.ok || ahkDb==NULL || selectSQL==NULL || updateSQL==NULL)
       return 0;

    if ((hashKind==3 && pixCount!=1024) || ((hashKind==2 || hashKind==4) && pixCount!=72))
       return 0;

    if (dupesHashSel!=NULL) { SQ.finalize(dupesHashSel); dupesHashSel = NULL; }
    if (dupesHashUpd!=NULL) { SQ.finalize(dupesHashUpd); dupesHashUpd = NULL; }

    dupesHashDB = (sqlite3*)ahkDb;
    dupesHashKind = hashKind;
    dupesHashPix = pixCount;
    dupesHashGray = (grayCompressor > 1) ? grayCompressor : 1;
    dupesHashMode = pHashMode;
    dupesHashWritten = dupesHashFailed = dupesHashSeen = dupesHashSkipped = 0;

    if (SQ.prepare16_v2(dupesHashDB, selectSQL, -1, &dupesHashSel, NULL)!=SQLITE_OK || dupesHashSel==NULL)
    {
       dupesSetError(L"could not prepare the hash-generation query");
       dupesHashSel = NULL;
       return 0;
    }

    if (SQ.prepare16_v2(dupesHashDB, updateSQL, -1, &dupesHashUpd, NULL)!=SQLITE_OK || dupesHashUpd==NULL)
    {
       dupesSetError(L"could not prepare the hash-generation update");
       SQ.finalize(dupesHashSel);
       dupesHashSel = NULL;
       dupesHashUpd = NULL;
       return 0;
    }

    return 1;
}

// Reads up to `batch` rows, hashes them across cores, writes them back, and returns 1
// while there is more to do. AHK keeps the surrounding transaction and its periodic
// COMMIT, so an interrupted run keeps the work it finished - which is what the "you can
// stop and resume this process at anytime" promise rests on.
DLL_API int DLL_CALLCONV dupesHashStep(int batch) {
    if (!SQ.ok || dupesHashSel==NULL || dupesHashUpd==NULL)
       return -1;

    if (batch < 1)
       batch = 256;

    std::vector<INT64> ids;
    std::vector<INT64> badIds;    // written back after the SELECT is reset, never during
    std::vector<int> pix;
    ids.reserve(batch);
    pix.reserve((size_t)batch * dupesHashPix);
    bool sawRow = false;

    SQ.reset(dupesHashSel);
    if (SQ.bind_int64!=NULL)
       SQ.bind_int64(dupesHashSel, 1, batch);

    for (;;)
    {
        const int rc = SQ.step(dupesHashSel);
        if (rc==SQLITE_ROW)
        {
           const unsigned char *s = (const unsigned char*)SQ.column_blob(dupesHashSel, 1);
           const int n = (s!=NULL) ? SQ.column_bytes(dupesHashSel, 1) : 0;
           dupesHashSeen++;
           sawRow = true;
           // a fingerprint of the wrong length was skipped by the AHK too: it tested
           // arrayChars.Count()=72 before hashing. The row is only remembered here and
           // written below: stepping an UPDATE against "images" while this SELECT is
           // still scanning it leaves what the cursor sees next undefined, which is the
           // very reason the good rows are held back to the end of the batch as well.
           if (n!=dupesHashPix)
           {
              badIds.push_back((INT64)SQ.column_int64(dupesHashSel, 0));
              continue;
           }

           ids.push_back((INT64)SQ.column_int64(dupesHashSel, 0));
           for ( int i = 0 ; i < n ; i++)
               pix.push_back(dupesDiscretize((int)s[i], dupesHashGray));
           if ((int)ids.size() >= batch)
              break;

           continue;
        }

        if (rc==SQLITE_DONE || rc==SQLITE_INTERRUPT)
           break;

        dupesSetError(L"the hash-generation query failed");
        SQ.reset(dupesHashSel);
        return -1;
    }

    SQ.reset(dupesHashSel);

    // A row whose fingerprint cannot be hashed is given an EMPTY hash, not "0". Either
    // one takes it out of the "hash IS NULL" result set, which is what stops it being
    // offered again - but "0" is a legitimate hash value (dupesHexHash(0) writes it, and
    // a uniform image really does hash to zero), and the candidate query keeps every row
    // for which ifnull(hash,'')!='', so "0" would drop all of these into the duplicates
    // set at distance 0 from one another and from every flat image in the library. The
    // empty string is exactly what that filter exists to exclude.
    // nByte counts BYTES for bind_text16, not characters: 0 is the empty string.
    if (!badIds.empty() && SQ.bind_text16!=NULL && SQ.bind_int64!=NULL)
    {
       for ( size_t i = 0 ; i < badIds.size() ; i++)
       {
           SQ.reset(dupesHashUpd);
           SQ.bind_text16(dupesHashUpd, 1, L"", 0, QPV_SQLITE_STATIC);
           SQ.bind_int64(dupesHashUpd, 2, badIds[i]);
           if (SQ.step(dupesHashUpd)==SQLITE_DONE)
              dupesHashSkipped++;
           else
              dupesHashFailed++;
       }

       SQ.reset(dupesHashUpd);
    }

    // Not "there is nothing left to do": the SELECT is capped at `batch` rows, so a batch
    // that was entirely unhashable says nothing about the rows behind it. Answering 0
    // here ended the whole run and reported it as finished, leaving every image after
    // those rows unhashed. They have just been marked, so the next call moves past them.
    if (ids.empty())
       return sawRow ? 1 : 0;

    const int count = (int)ids.size();
    std::vector<UINT64> out((size_t)count, 0);
    const int kind = dupesHashKind, stride = dupesHashPix, mode = dupesHashMode;
    const int *pixData = pix.data();
    UINT64 *outData = out.data();

    #pragma omp parallel for schedule(static) shared(pixData, outData) if (count > 8)
    for ( int i = 0 ; i < count ; i++)
    {
        const int *p = pixData + (size_t)i * stride;
        if (kind==2)      outData[i] = dupesDHash(p);
        else if (kind==4) outData[i] = dupesLHash(p);
        else              outData[i] = dupesPHash(p, mode);
    }

    for ( int i = 0 ; i < count ; i++)
    {
        wchar_t hex[32];
        dupesHexHash(out[i], hex, 32);
        SQ.reset(dupesHashUpd);
        if (SQ.bind_text16!=NULL)
           SQ.bind_text16(dupesHashUpd, 1, hex, -1, QPV_SQLITE_TRANSIENT);

        if (SQ.bind_int64!=NULL)
           SQ.bind_int64(dupesHashUpd, 2, ids[i]);

        const int rc = SQ.step(dupesHashUpd);
        if (rc==SQLITE_DONE)
           dupesHashWritten++;
        else
           dupesHashFailed++;
    }

    SQ.reset(dupesHashUpd);
    return 1;
}

DLL_API INT64 DLL_CALLCONV dupesHashWrittenCount() { return dupesHashWritten; }
DLL_API INT64 DLL_CALLCONV dupesHashFailedCount()  { return dupesHashFailed; }
// images passed over because their stored fingerprint is not the length this hash needs;
// separate from dupesHashFailedCount(), which really does mean the write failed
DLL_API INT64 DLL_CALLCONV dupesHashSkippedCount() { return dupesHashSkipped; }

DLL_API int DLL_CALLCONV dupesHashEnd() {
    if (SQ.ok)
    {
       if (dupesHashSel!=NULL) { SQ.finalize(dupesHashSel); dupesHashSel = NULL; }
       if (dupesHashUpd!=NULL) { SQ.finalize(dupesHashUpd); dupesHashUpd = NULL; }
    }

    dupesHashDB = NULL;
    return 1;
}
// qpv-dupes-query-end - sliced by tests/run-tests.sh; leave the marker in place.

// ---- the discrete cosine transform pHash is built on ----------------------------------
//
// The table and its two scale factors came out of qpv-main.h with the rest: nothing but
// calculateDCT() has ever read them. M_PI stayed behind, because the geometry and the
// colour code use it too.

const double div2sz = sqrt(2.0 / 32.0);      // used in calculateDCT()
const double div2sq = 1 / sqrt(2.0);         // used in calculateDCT()
std::array<double, 1025>  DCTcoeffs;

double calcArrayAvgMedian(std::array<double, 64> givenArray, int modus) {
    const int n = givenArray.size();
    if (modus==1) // median
    {
        std::sort(givenArray.begin(), givenArray.end());
        if (n % 2 == 0) {
            return (givenArray[n / 2 - 1] + givenArray[n / 2]) / 2;
        }

        return givenArray[n / 2];
    } else
    {
        // Calculate the average value from top 8x8 pixels, except for the first one.
        double thisSum = 0;
        for (int i = 1; i < n; i++)
        {
            thisSum += givenArray[i];
        }

        return (thisSum / (n - 1));
    }
}

DLL_API int DLL_CALLCONV calculateDCTcoeffs(int size) {
    // DCTcoeffs is std::array<double, 1025> and is filled 1-based, so size*size
    // must stay within 1024; calculateDCT() is hard-coded to 32 anyway
    if (size < 1 || size > 32)
       return 0;

    int thisIndex = 0;
    for (int i = 0; i < size; i++)
    {
        for (int j = 0; j < size; j++) {
            thisIndex++;
            DCTcoeffs[thisIndex] = cos(i * M_PI * (j + 0.5) / size);
        }
    }

    return 1;
}

auto calculateDCT(const std::array<double, 32> &matrix, int col, int loopu) {
    // int size = 32;
    std::array<double, 32> transformed;
    // double div2sz = sqrt(2.0 / size);
    // double div2sq = 1 / sqrt(2.0);

    int thisIndex = 0;
    for (int i = 0; i < 32; i++)
    {
        double sum = 0.0;
        for (int j = 0; j < 32; j++) {
            thisIndex++;
            sum += matrix[j] * DCTcoeffs[thisIndex];
            // sum += matrix[j] * cos(i * M_PI * (j + 0.5) / 32);
        }

        sum *= div2sz;
        if (i == 0) {
            sum *= div2sq;
        }

        transformed[i] = sum;
        // fnOutputDebug("calcPHashAlgo: col=" + to_string(col) + " loopu=" + to_string(loopu) + " matrix[" + to_string(i) + "] DCT=" + to_string(matrix[i]));
    }

    return transformed;
}

DLL_API INT64 DLL_CALLCONV calcPHashAlgo(unsigned char *givenArray, UINT size, int compareMethod) {
// based on the PHP implementation found on https://github.com/jenssegers/imagehash

    // givenArray is the pixels fingerprint
    // The buffers below, calculateDCT() and the DCTcoeffs table are all fixed at
    // 32; any other size would run the loops past the end of the stack arrays.
    if (size != 32)
       return 0;

    // calculate DCT for rows
    double rows[32][32];
    std::array<double, 32>  trow;
    // fnOutputDebug("calcPHashAlgo: init before loop" + to_string(size));
    for ( int y = 0; y < size; y++)
    {
        for (int x = 0; x < size; x++) 
        {
            trow[x] = givenArray[x + size*y];
        }

        auto transformed = calculateDCT(trow, y, 1);
        for (int x = 0; x < size; x++) 
        {
            rows[y][x] = transformed[x];
            // fnOutputDebug("calcPHashAlgo: row DCT=" + to_string(rows[y][x]));
        }
    }

    // fnOutputDebug("calcPHashAlgo: first for-loop" + to_string(rows[12][13]));
    // fnOutputDebug("calcPHashAlgo: trow" + to_string(trow[12]));
    // fnOutputDebug("calcPHashAlgo: givenArray" + to_string(givenArray[12]));

    // calculte DCT for columns
    double matrix[32][32];
    std::array<double, 32>  col;
    for (int x = 0; x < size; x++)
    {
        for (int y = 0; y < size; y++)
        {
            col[y] = rows[y][x];
        }

        auto transformed = calculateDCT(col, x, 2);
        for (int y = 0; y < size; y++)
        {
            matrix[x][y] = transformed[y];
        }
    }
    // fnOutputDebug("calcPHashAlgo: second for-loop" + to_string(matrix[12][13]));

    // extract the top 8x8 pixels from the DCT matrix
    int thisIndex = -1;
    std::array<double, 64>   fpexels;
    for (int y = 0; y < 8; y++)
    {
        for (int x = 0; x < 8; x++)
        {
            thisIndex++;
            fpexels[thisIndex] = matrix[y][x];
        }
    }
    // fnOutputDebug("calcPHashAlgo: third for-loop" + to_string(fpexels[13]));

    INT64 one = 0x0000000000000001;
    INT64 hash = 0x0000000000000000;

    // Calculate hash
    double compareTerm = calcArrayAvgMedian(fpexels, compareMethod);
    // fnOutputDebug("calcPHashAlgo: compareTerm =" + to_string(compareTerm));
    for (int x = 0; x < 64; x++)
    {
        // resultsArray[x] = (fpexels[x] > compareTerm) ? 1 : 0;
        if (fpexels[x] > compareTerm)
           hash |= one;
        one = one << 1;
    }

    // fnOutputDebug("calcPHashAlgo: ended=" + to_string(hash));
    return hash;
}
// qpv-dct-block-end - tests/run-tests.sh slices calcArrayAvgMedian .. calcPHashAlgo out
// of here for the hash oracle. Leave the marker in place.

#endif // QPV_DUPES_SEARCH_H
