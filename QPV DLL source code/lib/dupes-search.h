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
//     runs across every core on std::thread and the unit of parallel work is a run of candidate ROWS,
//     which is the only unit that fills the machine for both shapes a real library comes
//     in. dupesScanState.threads reports how wide it actually ran;
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
// of a million images the sweep is where most of the time goes; it and the hash generation
// are the two halves of the pipeline that thread, and both do it the same way.
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
int                         dupesPairsMSD = 0;   // 1 when the sweep that filled dupesPairsList computed MSD scores
UINT                        dupesPairsMaxId = 0;
size_t                      dupesPairsMaxIdCount = 0;
std::vector<DupePairRec>    dupesSavedPairs;
int                         dupesSavedMSD = 0;
UINT                        dupesSavedMaxId = 0;
size_t                      dupesSavedMaxIdCount = 0;
bool                        dupesHasSavedPairs = false;
bool                        dupesSweepActive = false;
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
    volatile LONG  threads;    // 52   widest crew the sweep actually ran a block with;
};                             //      0 from any qpvmain.dll older than the threaded sweep
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
UINT                        dupesScanMihBlock = 0;
UINT64                      dupesScanMaskApplied = ~0ULL;
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

// SWAR population count, with hardware POPCNT / AVX2 detected once via CPUID + XGETBV.
// qpv-cpu-begin
#if defined(_M_X64) || defined(_M_AMD64) || defined(__x86_64__)
#define QPV_X64 1
#include <immintrin.h>
#if defined(_MSC_VER)
#include <intrin.h>
#define QPV_NOINLINE       __declspec(noinline)
#define QPV_TARGET_AVX2    __declspec(noinline)
#define QPV_TARGET_POPCNT  __declspec(noinline)
#define QPV_POPCNT64_HW(x) ((int)__popcnt64(x))
#elif defined(__GNUC__) || defined(__clang__)
#include <cpuid.h>
#define QPV_NOINLINE       __attribute__((noinline))
#define QPV_TARGET_AVX2    __attribute__((noinline, target("avx2,popcnt")))
#define QPV_TARGET_POPCNT  __attribute__((noinline, target("popcnt")))
#define QPV_POPCNT64_HW(x) __builtin_popcountll((unsigned long long)(x))
#endif
#endif
#ifndef QPV_NOINLINE
#if defined(_MSC_VER)
#define QPV_NOINLINE __declspec(noinline)
#elif defined(__GNUC__) || defined(__clang__)
#define QPV_NOINLINE __attribute__((noinline))
#else
#define QPV_NOINLINE
#endif
#endif

#ifdef QPV_X64
struct QpvCpuCaps {
    bool popcnt;
    bool avx2;
};

static QpvCpuCaps qpvDetectCpuCaps() {
    QpvCpuCaps caps = { false, false };
#if defined(_MSC_VER)
    int r0[4] = {0, 0, 0, 0};
    __cpuid(r0, 0);
    const int maxLeaf = r0[0];
    if (maxLeaf < 1)
       return caps;

    int r1[4] = {0, 0, 0, 0};
    __cpuid(r1, 1);
    caps.popcnt = (r1[2] & (1 << 23)) != 0;   // CPUID.01H:ECX.POPCNT
    const bool hasOsXsave = (r1[2] & (1 << 27)) != 0;
    const bool hasAvx     = (r1[2] & (1 << 28)) != 0;
    if (hasOsXsave && hasAvx && maxLeaf >= 7)
    {
       if ((_xgetbv(0) & 0x6ULL) == 0x6ULL)
       {
          int r7[4] = {0, 0, 0, 0};
          __cpuidex(r7, 7, 0);
          caps.avx2 = (r7[1] & (1 << 5)) != 0; // CPUID.07H:EBX.AVX2
       }
    }
#elif defined(__GNUC__) || defined(__clang__)
    unsigned int eax = 0, ebx = 0, ecx = 0, edx = 0;
    const unsigned int maxLeaf = __get_cpuid_max(0, NULL);
    if (maxLeaf < 1)
       return caps;

    __cpuid(1, eax, ebx, ecx, edx);
    caps.popcnt = (ecx & (1u << 23)) != 0;
    const bool hasOsXsave = (ecx & (1u << 27)) != 0;
    const bool hasAvx     = (ecx & (1u << 28)) != 0;
    if (hasOsXsave && hasAvx && maxLeaf >= 7)
    {
       unsigned int xlo = 0, xhi = 0;
       __asm__ volatile("xgetbv" : "=a"(xlo), "=d"(xhi) : "c"(0));
       if ((xlo & 0x6u) == 0x6u)
       {
          __cpuid_count(7, 0, eax, ebx, ecx, edx);
          caps.avx2 = (ebx & (1u << 5)) != 0;
       }
    }
#endif
    return caps;
}

static const QpvCpuCaps qpvCpuCaps = qpvDetectCpuCaps();
static const bool qpvHasPopcnt = qpvCpuCaps.popcnt;
static const bool qpvHasAvx2   = qpvCpuCaps.avx2;
#else
static const bool qpvHasPopcnt = false;
static const bool qpvHasAvx2   = false;
#endif
// qpv-cpu-end

inline int popcount64SWAR(UINT64 x) {
    x -= (x >> 1) & 0x5555555555555555ULL;
    x  = (x & 0x3333333333333333ULL) + ((x >> 2) & 0x3333333333333333ULL);
    x  = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0FULL;
    return (int)((x * 0x0101010101010101ULL) >> 56);
}

inline int popcount64(UINT64 x) {
#if defined(_MSC_VER) && defined(QPV_X64)
    if (qpvHasPopcnt)
       return (int)__popcnt64(x);
#elif (defined(__GNUC__) || defined(__clang__)) && defined(__POPCNT__)
    return __builtin_popcountll((unsigned long long)x);
#endif
    return popcount64SWAR(x);
}

// Builds the bit window the two crop settings describe: lCrop drops that many
// LOW bits, rCrop that many HIGH bits.
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

#define QPV_MSD_NONE 2500

// qpv-msd-begin
static INT64 msdSumSquaresSSE2(const unsigned char *a, const unsigned char *b, const int count) {
    __m128i acc0 = _mm_setzero_si128();
    __m128i acc1 = _mm_setzero_si128();
    const __m128i mask00FF = _mm_set1_epi16(0x00FF);
    int i = 0;
    for ( ; i + 16 <= count ; i += 16)
    {
        const __m128i va = _mm_loadu_si128((const __m128i*)(a + i));
        const __m128i vb = _mm_loadu_si128((const __m128i*)(b + i));
        const __m128i d8 = _mm_or_si128(_mm_subs_epu8(va, vb), _mm_subs_epu8(vb, va));
        const __m128i lo = _mm_and_si128(d8, mask00FF);
        const __m128i hi = _mm_srli_epi16(d8, 8);
        acc0 = _mm_add_epi32(acc0, _mm_madd_epi16(lo, lo));
        acc1 = _mm_add_epi32(acc1, _mm_madd_epi16(hi, hi));
    }

    __m128i acc = _mm_add_epi32(acc0, acc1);
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

#ifdef QPV_X64
static QPV_TARGET_AVX2 INT64 msdSumSquaresAVX2(const unsigned char *a, const unsigned char *b, const int count) {
    __m256i acc0 = _mm256_setzero_si256();
    __m256i acc1 = _mm256_setzero_si256();
    const __m256i mask00FF = _mm256_set1_epi16(0x00FF);
    int i = 0;
    for ( ; i + 32 <= count ; i += 32)
    {
        const __m256i va = _mm256_loadu_si256((const __m256i*)(a + i));
        const __m256i vb = _mm256_loadu_si256((const __m256i*)(b + i));
        const __m256i d8 = _mm256_or_si256(_mm256_subs_epu8(va, vb), _mm256_subs_epu8(vb, va));
        const __m256i lo = _mm256_and_si256(d8, mask00FF);
        const __m256i hi = _mm256_srli_epi16(d8, 8);
        acc0 = _mm256_add_epi32(acc0, _mm256_madd_epi16(lo, lo));
        acc1 = _mm256_add_epi32(acc1, _mm256_madd_epi16(hi, hi));
    }

    const __m256i sum256 = _mm256_add_epi32(acc0, acc1);
    __m128i acc = _mm_add_epi32(_mm256_castsi256_si128(sum256), _mm256_extracti128_si256(sum256, 1));
    if (i + 16 <= count)
    {
        const __m128i va = _mm_loadu_si128((const __m128i*)(a + i));
        const __m128i vb = _mm_loadu_si128((const __m128i*)(b + i));
        const __m128i d8 = _mm_or_si128(_mm_subs_epu8(va, vb), _mm_subs_epu8(vb, va));
        const __m128i lo = _mm_and_si128(d8, _mm256_castsi256_si128(mask00FF));
        const __m128i hi = _mm_srli_epi16(d8, 8);
        acc = _mm_add_epi32(acc, _mm_madd_epi16(lo, lo));
        acc = _mm_add_epi32(acc, _mm_madd_epi16(hi, hi));
        i += 16;
    }

    acc = _mm_add_epi32(acc, _mm_shuffle_epi32(acc, _MM_SHUFFLE(1, 0, 3, 2)));
    acc = _mm_add_epi32(acc, _mm_shuffle_epi32(acc, _MM_SHUFFLE(2, 3, 0, 1)));
    INT64 sum = (INT64)_mm_cvtsi128_si32(acc);
    for ( ; i < count ; i++)
    {
        const int d = (int)a[i] - (int)b[i];
        sum += (INT64)d * d;
    }

    _mm256_zeroupper();
    return sum;
}
#endif

QPV_FORCEINLINE INT64 msdSumSquares(const unsigned char *a, const unsigned char *b, const int count) {
#ifdef QPV_X64
    if (qpvHasAvx2 && count >= 32)
       return msdSumSquaresAVX2(a, b, count);
#endif
    return msdSumSquaresSSE2(a, b, count);
}

QPV_FORCEINLINE int msdScore(const unsigned char *a, const unsigned char *b, const int count, const int scale) {
    const INT64 sum = msdSumSquares(a, b, count) * (INT64)scale * (INT64)scale;
    return (int)floor(sqrt((double)sum / ((double)count / 2.0)) + 0.5);
}
// qpv-msd-end

// Color-inverted and horizontally-flipped MSD counterparts for API callers that enable
// checkInverted or checkFlipped alongside wantMSD. Named away from msdScore() so
// run-tests.sh's msd_extract slice keeps only msdSumSquares/msdScore.
static int dupesMsdScoreInverted(const unsigned char *a, const unsigned char *b, const int count, const int scale) {
    const int invMax = (scale > 1) ? (int)floor(255.0 / (double)scale + 0.5) : 255;
    INT64 sum = 0;
    for ( int i = 0 ; i < count ; i++)
    {
        const int d = (int)a[i] - (invMax - (int)b[i]);
        sum += (INT64)d * d;
    }
    sum *= (INT64)scale * (INT64)scale;
    return (int)floor(sqrt((double)sum / ((double)count / 2.0)) + 0.5);
}

static int dupesMsdScoreFlipped(const unsigned char *a, const unsigned char *b, const int count, const int scale) {
    if (count!=1024)
       return msdScore(a, b, count, scale);

    INT64 sum = 0;
    for ( int y = 0 ; y < 32 ; y++)
    {
        const unsigned char *ra = a + y * 32;
        const unsigned char *rb = b + y * 32;
        for ( int x = 0 ; x < 32 ; x++)
        {
            const int d = (int)ra[x] - (int)rb[31 - x];
            sum += (INT64)d * d;
        }
    }
    sum *= (INT64)scale * (INT64)scale;
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
    if ((size_t)firstIndex > dupesPixOK.size() || (size_t)count > dupesPixOK.size() - (size_t)firstIndex)
       return;

    const size_t endIndex = (size_t)firstIndex + (size_t)count;
    if (endIndex > dupesPixData.size() / (size_t)stride)
       return;

    const int scale = dupesPixScale;
    static int lutScale = 0;
    static unsigned char lut[256];
    if (scale > 1 && lutScale != scale)
    {
       for ( int v = 0 ; v < 256 ; v++)
           lut[v] = (unsigned char)floor((double)v / scale + 0.5);
       lutScale = scale;
    }

    for ( UINT rec = 0 ; rec < count ; rec++)
    {
        const wchar_t *src = blob + (size_t)rec * stride;
        if (src[0] < 161)
           continue;

        const size_t slot = (size_t)firstIndex + (size_t)rec;
        unsigned char *dst = &dupesPixData[slot * (size_t)stride];
        if (scale > 1)
        {
           for ( UINT k = 0 ; k < stride ; k++)
           {
               int v = (int)src[k] - 161;
               if (v < 0) v = 0;
               else if (v > 255) v = 255;
               dst[k] = lut[v];
           }
        }
        else
        {
           for ( UINT k = 0 ; k < stride ; k++)
           {
               int v = (int)src[k] - 161;
               if (v < 0) v = 0;
               else if (v > 255) v = 255;
               dst[k] = (unsigned char)v;
           }
        }
        dupesPixOK[slot] = 1;
    }
}

static void decodeFingerprintBlob(const wchar_t *blob, const UINT count, const UINT stride, const int grayCompressor) {
    dupesPixStride = 0;
    dupesPixScale = (grayCompressor > 1) ? grayCompressor : 1;
    if (stride==0 || (size_t)count > ((size_t)-1) / (size_t)stride)
    {
       dupesPixData.clear();
       dupesPixOK.clear();
       return;
    }
    try
    {
       dupesPixData.assign((size_t)count * (size_t)stride, 0);
       dupesPixOK.assign(count, 0);
    }
    catch (...)
    {
       dupesPixData.clear();
       dupesPixOK.clear();
       return;
    }
    dupesPixStride = stride;
    decodeFingerprintChunk(blob, 0, count);
}

void dupesQueryFreeRows();
// The sweep's collecting buffers and its block plan, both defined with the sweep further
// down. Forward-declared so the two release paths above the sweep can hand them back.
static void dupesSweepReleaseScratch();

static void dupesDropSavedPairs() {
    std::vector<DupePairRec>().swap(dupesSavedPairs);
    dupesSavedMSD = 0;
    dupesSavedMaxId = 0;
    dupesSavedMaxIdCount = 0;
    dupesHasSavedPairs = false;
}

static void dupesRestoreSavedPairs() {
    if (!dupesHasSavedPairs)
       return;

    dupesPairsList.swap(dupesSavedPairs);
    dupesPairsMSD = dupesSavedMSD;
    dupesPairsMaxId = dupesSavedMaxId;
    dupesPairsMaxIdCount = dupesSavedMaxIdCount;
    dupesDropSavedPairs();
}

// Releases everything the duplicate scan holds. AHK calls it on every exit path from
// filterDupeResultsByHdist(), including the abandoned ones: a partially read pair list
// would otherwise be handed to the next scan ahead of its own results.
DLL_API UINT DLL_CALLCONV dupesClearPairs() {
    dupesQueryFreeRows();
    dupesSweepReleaseScratch();
    dupesDropSavedPairs();
    dupesSweepActive = false;
    dupesFilterRows.clear();
    dupesFilterRows.shrink_to_fit();
    dupesPairsList.clear();
    dupesPairsList.shrink_to_fit();
    dupesPairsMSD = 0;
    dupesPairsMaxId = 0;
    dupesPairsMaxIdCount = 0;
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
    dupesScanMihBlock = 0;
    dupesScanMaskApplied = ~0ULL;
    memset((void*)&dupesScanState, 0, sizeof(dupesScanState));

    return 1;
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

// The threads are std::thread and NOT OpenMP, deliberately.
//
// dupesSweepSetThreads() below makes the width settable and dupesScanState.threads reports
// what was really used, so "is it threading?" is a question the application can answer
// instead of a question about the compiler.
#include <thread>
#include <atomic>

#define QPV_MIH_MIN_GROUP   4096u
#define QPV_MIH_MAX_R       9
#define QPV_MIH_MAX_TABLES  6

struct DupesMIHIndex;

struct DupesSweepCtx {
    const UINT64 *hashes;
    const UINT64 *flipped;    // may alias hashes when flipped detection is off
    const UINT   *ids;
    const UINT   *rowEnd;     // NULL: every row's group ends at flatEnd (the one-group entry point)
    UINT   flatEnd;
    UINT64 hamMask;
    int    maskBits;
    int    threshold;
    int    checkInverted;
    int    checkFlipped;
    bool   wantMSD;
    bool   preMasked;
    const DupesMIHIndex *mih;
};

struct DupesSweepItem {
    UINT   firstRow, lastRow;
    int    slot;
    int    failed;            // this item ran out of memory; see dupesRunPlan()
    size_t begin, count;
};

struct DupesSweepBufBody {
    std::vector<DupePairRec> v;
    std::vector<UINT64> mihBits;
    std::vector<UINT>   mihHits;
    std::vector<UINT>   rowHits[4];
    UINT maxId;
};

struct DupesSweepBuf {
    std::vector<DupePairRec> v;
    std::vector<UINT64> mihBits;
    std::vector<UINT>   mihHits;
    std::vector<UINT>   rowHits[4];
    UINT maxId = 0;
    char pad[128 - (sizeof(DupesSweepBufBody) % 128)];
};

// Multi-index hashing CSR tables for one active large group.
struct DupesMIHIndex {
    UINT   groupStart = 0;
    UINT   groupEnd = 0;
    UINT   M = 0;
    UINT64 hamMask = 0;
    int    threshold = -1;
    int    checkInverted = 0;
    int    checkFlipped = 0;
    bool   attempted = false;
    bool   active = false;
    int    m = 0;
    int    maxFlip = 0;
    int    w = 0;
    UINT   maskKey = 0;
    UINT   byteLut[QPV_MIH_MAX_TABLES][8][256];
    std::vector<UINT> head[QPV_MIH_MAX_TABLES];
    std::vector<UINT> vals[QPV_MIH_MAX_TABLES];

    void releaseTables() {
        for (int k = 0; k < QPV_MIH_MAX_TABLES; k++)
        {
            std::vector<UINT>().swap(head[k]);
            std::vector<UINT>().swap(vals[k]);
        }
        active = false;
        m = 0;
        maxFlip = 0;
        w = 0;
        maskKey = 0;
    }

    void release() {
        releaseTables();
        groupStart = 0;
        groupEnd = 0;
        M = 0;
        hamMask = 0;
        threshold = -1;
        checkInverted = 0;
        checkFlipped = 0;
        attempted = false;
    }

    bool matches(UINT r, const DupesSweepCtx &C) const {
        return attempted && groupEnd > groupStart && r >= groupStart && r < groupEnd
            && hamMask == C.hamMask && threshold == C.threshold
            && checkInverted == C.checkInverted && checkFlipped == C.checkFlipped;
    }
};

static DupesMIHIndex               dupesMIH;
static std::vector<DupesSweepItem> dupesSweepPlan;
static std::vector<DupesSweepBuf>  dupesSweepBufs;
static bool dupesSweepAllocFailed = false;

static void dupesSweepReleaseScratch() {
    dupesMIH.release();
    dupesSweepPlan.clear();  dupesSweepPlan.shrink_to_fit();
    dupesSweepBufs.clear();  dupesSweepBufs.shrink_to_fit();
}

// The shared cursor a block's workers pull items off. One relaxed increment per item is
// the whole of the coordination between them: an item is millions of comparisons, so the
// contention is nothing, and taking them one at a time is what balances a block whose items
// are not all equally heavy - the same thing schedule(dynamic) was there for.
static std::atomic<int> dupesSweepCursor(0);

// How wide a team may be. hardware_concurrency() is the logical processor count of this
// process's processor group, which is what the machine can actually run at once.
static int dupesSweepHW = 0;
static int dupesSweepWidthSet = 0;      // 0 = one worker per hardware thread

static int dupesSweepThreads() {
    if (dupesSweepWidthSet > 0)
       return dupesSweepWidthSet;

    if (dupesSweepHW==0)
    {
       const unsigned int hw = std::thread::hardware_concurrency();
       int t = (hw > 0) ? (int)hw : 1;
       if (t < 1)
          t = 1;

       if (t > 256)   // one collecting buffer per worker; a machine this wide is not the
          t = 256;    // problem this code has

       dupesSweepHW = t;
    }

    return dupesSweepHW;
}

// Pins the sweep to a fixed number of workers; 0 puts it back to one per hardware thread.
// Returns the width now in force.
//
// It exists for two reasons. tests/sweep_smoke.cpp sweeps one candidate set with teams of
// 1, 2, 3, 5 and 8 and requires all five to come back byte-identical, which is the only way
// to prove the result does not depend on how the work was cut up. And it is the switch to
// reach for when a machine behaves oddly: pinning the sweep to 1 turns a threading question
// into a plain measurement, without a rebuild.
DLL_API int DLL_CALLCONV dupesSweepSetThreads(int n) {
    if (n < 0)
       n = 0;

    if (n > 256)
       n = 256;

    dupesSweepWidthSet = n;
    return dupesSweepThreads();
}

// Runs body(i) for every i in [0, count) across the same crew width the sweep uses, and
// returns when the last one is done. The items come off a shared cursor rather than being
// split up front, so a machine that will not give us a thread is slower and not wrong -
// whatever the crew does not take, the calling thread does.
//
// body() must not throw: it runs on threads whose entry point is this lambda, and an
// exception out of one calls std::terminate. The only caller is the hash loop, whose three
// hash functions are arithmetic over a stack buffer.
//
// worthATeam is the caller saying whether one item is expensive enough to be worth handing
// to another thread, because count alone cannot tell: 512 items are 512 items whether each
// one is a DCT or a handful of comparisons. Starting and joining the crew costs about the
// same either way, and for the cheap hashes that is several times the work itself - see the
// measurements at the call site in dupesHashStep().
template <class F>
static void dupesParallelFor(const int count, F body, const bool worthATeam = true) {
    if (count < 1)
       return;

    int team = worthATeam ? dupesSweepThreads() : 1;
    if (team > count)
       team = count;

    if (team < 2)
    {
       for ( int i = 0 ; i < count ; i++)
           body(i);

       return;
    }

    std::atomic<int> cursor(0);
    std::atomic<int> *pCursor = &cursor;
    std::vector<std::thread> crew;
    const auto run = [pCursor, count, &body]() {
        for (;;)
        {
            const int i = pCursor->fetch_add(1, std::memory_order_relaxed);
            if (i >= count)
               break;

            body(i);
        }
    };

    try
    {
        crew.reserve((size_t)(team - 1));
        for ( int t = 1 ; t < team ; t++)
            crew.push_back(std::thread(run));
    }
    catch (...)
    {
        // out of threads or out of memory; the cursor covers whatever did not start
    }

    run();
    for ( size_t t = 0 ; t < crew.size() ; t++)
        crew[t].join();
}

// What one candidate row costs on top of its comparisons: the group-end lookup and the
// inner loop's setup, and for a singleton nothing else at all. Blocks are planned in these
// units rather than in comparisons, because a candidate set of 300 000 groups of three is
// almost no comparisons and a very great deal of loop - planned by comparisons alone, one
// block would swallow the entire scan and the cancel latency with it.
#define QPV_SWEEP_ROW_COST   4
// Never cut an item smaller than this: below it handing the item out costs more than
// running it does.
#define QPV_SWEEP_MIN_ITEM   4096
// And never plan more items than this in one block, whatever the arithmetic says.
#define QPV_SWEEP_MAX_ITEMS  4096

QPV_FORCEINLINE void dupesCheckAndEmitPair(
    const DupesSweepCtx &C, const UINT secondIndex, const UINT mainIndex,
    const UINT64 hashSecond, const UINT64 invert2ndindex, const UINT64 flipped2ndindex,
    std::vector<DupePairRec> &out, UINT &maxId) {
    (void)invert2ndindex;
    const UINT64 hMain = C.hashes[mainIndex];
    const UINT64 hamMask = C.hamMask;
    const int threshold = C.threshold;
    const UINT64 x = hMain ^ hashSecond;
    const int diff  = popcount64(C.preMasked ? x : (x & hamMask));
    const int diff2 = (C.checkInverted==1) ? (C.maskBits - diff) : 900;
    const int diff3 = (C.checkFlipped==1)
                    ? popcount64(C.preMasked ? (hMain ^ flipped2ndindex) : ((hMain ^ flipped2ndindex) & hamMask))
                    : 900;

    int bestDiff = diff;
    if (diff2 < bestDiff) bestDiff = diff2;
    if (diff3 < bestDiff) bestDiff = diff3;

    if (bestDiff >= threshold)
       return;

    UINT mse = QPV_MSD_NONE;
    if (C.wantMSD && dupesPixOK[mainIndex] && dupesPixOK[secondIndex])
    {
       const unsigned char *pa = &dupesPixData[(size_t)mainIndex * dupesPixStride];
       const unsigned char *pb = &dupesPixData[(size_t)secondIndex * dupesPixStride];
       const int stride = (int)dupesPixStride;
       bool haveMse = false;
       if (diff < threshold)
       {
          mse = (UINT)msdScore(pa, pb, stride, dupesPixScale);
          haveMse = true;
       }
       if (diff2 < threshold)
       {
          const UINT m2 = (UINT)dupesMsdScoreInverted(pa, pb, stride, dupesPixScale);
          if (!haveMse || m2 < mse) { mse = m2; haveMse = true; }
       }
       if (diff3 < threshold)
       {
          const UINT m3 = (UINT)dupesMsdScoreFlipped(pa, pb, stride, dupesPixScale);
          if (!haveMse || m3 < mse) { mse = m3; haveMse = true; }
       }
    }

    const UINT idA = C.ids[mainIndex], idB = C.ids[secondIndex];
    if (idA > maxId) maxId = idA;
    if (idB > maxId) maxId = idB;
    out.push_back({ idA, idB, (UINT)bestDiff, mse });
}

static QPV_NOINLINE void dupesEmitMatchedPair(
    const DupesSweepCtx &C, const UINT secondIndex, const UINT mainIndex,
    const UINT64 hashSecond, const UINT64 flipped2ndindex,
    std::vector<DupePairRec> &out, UINT &maxId) {
    dupesCheckAndEmitPair(C, secondIndex, mainIndex, hashSecond, 0, flipped2ndindex, out, maxId);
}

static QPV_NOINLINE void dupesFlushRowHits(
    const DupesSweepCtx &C, const UINT secondIndex, const std::vector<UINT> &hits,
    std::vector<DupePairRec> &out, UINT &maxId) {
    const UINT64 hashSecond = C.hashes[secondIndex];
    const UINT64 flipped2ndindex = (C.checkFlipped==1) ? C.flipped[secondIndex] : 0;
    const size_t nh = hits.size();
    const UINT *hp = hits.data();
    for ( size_t i = 0 ; i < nh ; i++)
        dupesCheckAndEmitPair(C, secondIndex, hp[i], hashSecond, 0, flipped2ndindex, out, maxId);
}

QPV_FORCEINLINE UINT qpvCtz64(UINT64 x) {
#if defined(_MSC_VER) && (defined(_M_X64) || defined(_M_AMD64))
    unsigned long idx = 0;
    _BitScanForward64(&idx, x);
    return (UINT)idx;
#elif defined(_MSC_VER)
    unsigned long idx = 0;
    if (_BitScanForward(&idx, (unsigned long)(x & 0xFFFFFFFFu)))
       return (UINT)idx;
    _BitScanForward(&idx, (unsigned long)(x >> 32));
    return (UINT)(idx + 32);
#elif defined(__GNUC__) || defined(__clang__)
    return (UINT)__builtin_ctzll((unsigned long long)x);
#else
    UINT n = 0;
    while ((x & 1ULL) == 0) { x >>= 1; n++; }
    return n;
#endif
}

QPV_FORCEINLINE UINT mihExtractKey(const UINT lut[8][256], const UINT64 h) {
    return lut[0][ h        & 0xFFu]
         | lut[1][(h >>  8) & 0xFFu]
         | lut[2][(h >> 16) & 0xFFu]
         | lut[3][(h >> 24) & 0xFFu]
         | lut[4][(h >> 32) & 0xFFu]
         | lut[5][(h >> 40) & 0xFFu]
         | lut[6][(h >> 48) & 0xFFu]
         | lut[7][(h >> 56)        ];
}

// Builds MIH CSR tables for [gStart, gEnd), or marks attempted=true, active=false on
// skew/OOM/unsupported parameters so the caller falls back to brute force.
static bool dupesMIHBuild(const DupesSweepCtx &C, const UINT gStart, const UINT gEnd) {
    dupesMIH.release();
    dupesMIH.groupStart = gStart;
    dupesMIH.groupEnd = gEnd;
    dupesMIH.M = (gEnd > gStart) ? (gEnd - gStart) : 0;
    dupesMIH.hamMask = C.hamMask;
    dupesMIH.threshold = C.threshold;
    dupesMIH.checkInverted = C.checkInverted;
    dupesMIH.checkFlipped = C.checkFlipped;
    dupesMIH.attempted = true;

    const UINT M = dupesMIH.M;
    if (M < QPV_MIH_MIN_GROUP || C.threshold < 1)
       return false;

    const int r = C.threshold - 1;
    if (r > QPV_MIH_MAX_R)
       return false;

    int activeBits[64];
    int B = 0;
    for (int b = 0; b < 64; b++)
        if ((C.hamMask >> b) & 1ULL)
           activeBits[B++] = b;

    if (r >= B || B < 8)
       return false;

    int lgM = 0;
    while ((1u << lgM) < M && lgM < 20)
        lgM++;

    int bestM = 0, bestFlip = 0, bestW = 0;
    double bestEst = 1e30;

    if (r + 1 <= QPV_MIH_MAX_TABLES)
    {
       const int mA = r + 1;
       int wA = B / mA;
       if (wA > lgM + 1) wA = lgM + 1;
       if (wA > 20) wA = 20;
       if (wA >= 8)
       {
          bestM = mA;
          bestFlip = 0;
          bestW = wA;
          bestEst = (double)mA * (4.0 + 6.0 * (double)M / (double)(1u << wA));
       }
    }

    if (r >= 2 && (r / 2) + 1 <= QPV_MIH_MAX_TABLES)
    {
       const int mB = (r / 2) + 1;
       int wB = B / mB;
       if (wB > lgM + 1) wB = lgM + 1;
       if (wB > 18) wB = 18;
       if (wB >= 11)
       {
          const double probes = (double)mB * (double)(1 + wB);
          const double estB = probes * (4.0 + 6.0 * (double)M / (double)(1u << wB));
          if (estB < bestEst)
          {
             bestM = mB;
             bestFlip = 1;
             bestW = wB;
             bestEst = estB;
          }
       }
    }

    if (bestM < 1)
       return false;

    int bitPos[QPV_MIH_MAX_TABLES][20];
    int bitCnt[QPV_MIH_MAX_TABLES] = {};
    for (int i = 0; i < B; i++)
    {
        const int k = i % bestM;
        if (bitCnt[k] < bestW)
           bitPos[k][bitCnt[k]++] = activeBits[i];
    }

    for (int k = 0; k < bestM; k++)
    {
        memset(dupesMIH.byteLut[k], 0, sizeof(dupesMIH.byteLut[k]));
        for (int outBit = 0; outBit < bestW; outBit++)
        {
            const int srcBit = bitPos[k][outBit];
            const int byteIdx = srcBit >> 3;
            const int inByteMask = 1 << (srcBit & 7);
            const UINT outMask = 1u << outBit;
            UINT *tbl = dupesMIH.byteLut[k][byteIdx];
            for (int v = 0; v < 256; v++)
                if (v & inByteMask)
                   tbl[v] |= outMask;
        }
    }

    const UINT nbuckets = 1u << bestW;
    const UINT maskKey = nbuckets - 1u;
    try
    {
        for (int k = 0; k < bestM; k++)
            dupesMIH.head[k].assign((size_t)nbuckets + 1, 0);
    }
    catch (...)
    {
        dupesMIH.releaseTables();
        return false;
    }

    const UINT64 *gh = C.hashes + gStart;
    const bool parBuild = (M >= 16384u && bestM >= 2);
    dupesParallelFor(bestM, [gh, M](int k) {
        UINT *hd = dupesMIH.head[k].data();
        const UINT (*lut)[256] = dupesMIH.byteLut[k];
        for (UINT i = 0; i < M; i++)
            hd[mihExtractKey(lut, gh[i]) + 1]++;
    }, parBuild);

    const double bfPairs = (double)M * (double)(M - 1) * 0.5;
    const int mult = 1 + (C.checkInverted==1 ? 1 : 0) + (C.checkFlipped==1 ? 1 : 0);
    const double probeOps = (double)M * (double)bestM * (double)(1 + bestFlip * bestW) * (double)mult;
    double candEntries = 0.0;
    for (int k = 0; k < bestM; k++)
    {
        const UINT *cnt = dupesMIH.head[k].data() + 1;
        double sameAndFlip = 0.0;
        for (UINT b = 0; b < nbuckets; b++)
        {
            const double c = (double)cnt[b];
            if (c == 0.0)
               continue;

            sameAndFlip += c * (c - 1.0) * 0.5;
            if (C.checkInverted==1)
               candEntries += c * (double)cnt[b ^ maskKey] * 0.5;

            if (bestFlip == 1)
            {
               for (int bit = 0; bit < bestW; bit++)
               {
                   const UINT nb = b ^ (1u << bit);
                   sameAndFlip += c * (double)cnt[nb] * 0.5;
                   if (C.checkInverted==1)
                      candEntries += c * (double)cnt[(b ^ maskKey) ^ (1u << bit)] * 0.5;
               }
            }
        }
        candEntries += sameAndFlip;
        if (C.checkFlipped==1)
           candEntries += sameAndFlip;
    }

    if (candEntries > bfPairs * 0.25 || candEntries * 6.0 + probeOps * 2.0 > bfPairs * 0.70)
    {
       dupesMIH.releaseTables();
       return false;
    }

    try
    {
        for (int k = 0; k < bestM; k++)
            dupesMIH.vals[k].resize(M);
    }
    catch (...)
    {
        dupesMIH.releaseTables();
        return false;
    }

    dupesParallelFor(bestM, [gh, M, nbuckets](int k) {
        UINT *hd = dupesMIH.head[k].data();
        UINT *vl = dupesMIH.vals[k].data();
        const UINT (*lut)[256] = dupesMIH.byteLut[k];
        for (UINT b = 1; b <= nbuckets; b++)
            hd[b] += hd[b - 1];
        for (UINT i = 0; i < M; i++)
            vl[hd[mihExtractKey(lut, gh[i])]++] = i;
        memmove(hd + 1, hd, (size_t)nbuckets * sizeof(UINT));
        hd[0] = 0;
    }, parBuild);

    dupesMIH.m = bestM;
    dupesMIH.maxFlip = bestFlip;
    dupesMIH.w = bestW;
    dupesMIH.maskKey = maskKey;
    dupesMIH.active = true;
    return true;
}

static void mihSweepRowsInto(const DupesSweepCtx &C, const DupesMIHIndex &MIH, const UINT firstRow, const UINT lastRow, DupesSweepBuf &buf) {
    const UINT gStart = MIH.groupStart;
    const UINT M = MIH.M;
    const int m = MIH.m;
    const int maxFlip = MIH.maxFlip;
    const int w = MIH.w;
    const UINT maskKey = MIH.maskKey;
    const UINT64 hamMask = C.hamMask;
    const int threshold = C.threshold;
    const int checkInverted = C.checkInverted;
    const int checkFlipped = C.checkFlipped;
    const UINT64 *givenHashesArray = C.hashes;
    const UINT64 *givenFlippedHashesArray = C.flipped;
    std::vector<DupePairRec> &out = buf.v;
    std::vector<UINT> &hits = buf.mihHits;

    const size_t needWords = ((size_t)M + 63u) >> 6;
    if (buf.mihBits.size() < needWords)
       buf.mihBits.assign(needWords, 0ULL);

    UINT64 *bits = buf.mihBits.data();
    const size_t denseCap = ((needWords >> 2) > 256u) ? (needWords >> 2) : 256u;

    for ( UINT secondIndex = firstRow ; secondIndex <= lastRow ; secondIndex++)
    {
        const UINT localS = secondIndex - gStart;
        if (localS + 1 >= M)
           continue;

        const UINT64 hashSecond = givenHashesArray[secondIndex];
        const UINT64 invert2ndindex = (checkInverted==1) ? ~hashSecond : 0;
        const UINT64 flipped2ndindex = (checkFlipped==1) ? givenFlippedHashesArray[secondIndex] : 0;
        const bool probeFlip = (checkFlipped==1)
            && (((flipped2ndindex ^ hashSecond) & hamMask) != 0)
            && (checkInverted!=1 || (((flipped2ndindex ^ invert2ndindex) & hamMask) != 0));

        // Single-bucket exact lookup: vals[0] is already unique and ascending.
        if (m == 1 && maxFlip == 0 && checkInverted!=1 && !probeFlip)
        {
           const UINT key = mihExtractKey(MIH.byteLut[0], hashSecond);
           const UINT *hd = MIH.head[0].data();
           const UINT *vl = MIH.vals[0].data();
           const UINT lo = hd[key], hi = hd[key + 1];
           if (lo == hi || vl[hi - 1] <= localS)
              continue;

           UINT pos = lo;
           if (vl[pos] <= localS)
           {
              UINT l = lo + 1, r = hi;
              while (l < r)
              {
                  const UINT mid = l + ((r - l) >> 1);
                  if (vl[mid] <= localS) l = mid + 1;
                  else r = mid;
              }
              pos = l;
           }
           for ( ; pos < hi ; pos++)
               dupesCheckAndEmitPair(C, secondIndex, gStart + vl[pos], hashSecond, invert2ndindex, flipped2ndindex, out, buf.maxId);
           continue;
        }

        hits.clear();
        bool denseBits = false;
        size_t hitCount = 0;

        auto probeBucket = [&](const UINT *hd, const UINT *vl, const UINT b) {
            const UINT lo = hd[b];
            const UINT hi = hd[b + 1];
            if (lo == hi || vl[hi - 1] <= localS)
               return;

            UINT pos = lo;
            if (vl[pos] <= localS)
            {
               UINT l = lo + 1, r = hi;
               while (l < r)
               {
                   const UINT mid = l + ((r - l) >> 1);
                   if (vl[mid] <= localS) l = mid + 1;
                   else r = mid;
               }
               pos = l;
            }
            for ( ; pos < hi ; pos++)
            {
                const UINT cand = vl[pos];
                UINT64 &word = bits[cand >> 6];
                const UINT64 bit = 1ULL << (cand & 63);
                if ((word & bit) != 0)
                   continue;

                const UINT64 hMain = givenHashesArray[gStart + cand];
                const int d0 = popcount64(C.preMasked ? (hMain ^ hashSecond) : ((hMain ^ hashSecond) & hamMask));
                if (d0 >= threshold)
                {
                   if (checkInverted!=1 || (C.maskBits - d0) >= threshold)
                      if (checkFlipped!=1 || popcount64(C.preMasked ? (hMain ^ flipped2ndindex) : ((hMain ^ flipped2ndindex) & hamMask)) >= threshold)
                         continue;
                }

                if (!denseBits)
                {
                   if (hits.size() < denseCap)
                      hits.push_back(cand);
                   else
                      denseBits = true;
                }
                word |= bit;
                hitCount++;
            }
        };

        auto probeKey = [&](const int k, const UINT key) {
            const UINT *hd = MIH.head[k].data();
            const UINT *vl = MIH.vals[k].data();
            probeBucket(hd, vl, key);
            if (maxFlip == 1)
            {
               for (int bit = 0; bit < w; bit++)
                   probeBucket(hd, vl, key ^ (1u << bit));
            }
        };

        for (int k = 0; k < m; k++)
        {
            const UINT key = mihExtractKey(MIH.byteLut[k], hashSecond);
            probeKey(k, key);
            if (checkInverted==1)
               probeKey(k, key ^ maskKey);
            if (probeFlip)
               probeKey(k, mihExtractKey(MIH.byteLut[k], flipped2ndindex));
        }

        if (hitCount == 0)
           continue;

        if (denseBits)
        {
           // Extract true matches directly from the bitset in ascending order (no sort).
           for (size_t wIdx = (size_t)(localS >> 6); wIdx < needWords; wIdx++)
           {
               UINT64 wv = bits[wIdx];
               if (wv == 0)
                  continue;

               bits[wIdx] = 0;
               const UINT base = (UINT)(wIdx << 6);
               while (wv != 0)
               {
                   const UINT bpos = qpvCtz64(wv);
                   wv &= wv - 1;
                   dupesCheckAndEmitPair(C, secondIndex, gStart + base + bpos, hashSecond, invert2ndindex, flipped2ndindex, out, buf.maxId);
               }
           }
        }
        else
        {
           for (size_t i = 0; i < hits.size(); i++)
               bits[hits[i] >> 6] = 0;

           if (hits.size() > 1)
              std::sort(hits.begin(), hits.end());

           for (size_t i = 0; i < hits.size(); i++)
               dupesCheckAndEmitPair(C, secondIndex, gStart + hits[i], hashSecond, invert2ndindex, flipped2ndindex, out, buf.maxId);
        }
    }
}

template <bool Masked, bool CheckInverted, bool CheckFlipped>
static void sweepRowsSWAR(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, DupesSweepBuf &buf) {
    const UINT64 *hashes = C.hashes;
    const UINT64 *flipped = C.flipped;
    const UINT   *rowEnd = C.rowEnd;
    const UINT64 hamMask = C.hamMask;
    const int    threshold = C.threshold;
    const int    maskBits = C.maskBits;
    const bool   invAll = CheckInverted && ((INT64)threshold * 2 > (INT64)maskBits);
    const UINT   invSpan = (CheckInverted && !invAll) ? (UINT)(maskBits - 2 * threshold) : 0u;
    (void)flipped; (void)hamMask; (void)invAll; (void)invSpan;

    std::vector<DupePairRec> &out = buf.v;
    std::vector<UINT> &b0 = buf.rowHits[0];
    std::vector<UINT> &b1 = buf.rowHits[1];
    std::vector<UINT> &b2 = buf.rowHits[2];
    std::vector<UINT> &b3 = buf.rowHits[3];

    #define QPV_SWAR_DIST(a, b) popcount64SWAR(Masked ? (((a) ^ (b)) & hamMask) : ((a) ^ (b)))
    #define QPV_SWAR_MATCH(hM, hR, fR) ( \
        (CheckInverted ? (int)(invAll || ((UINT)(QPV_SWAR_DIST(hM, hR) - threshold) > invSpan)) \
                       : (int)(QPV_SWAR_DIST(hM, hR) < threshold)) \
        | (CheckFlipped ? (int)(QPV_SWAR_DIST(hM, fR) < threshold) : 0) \
    )

    UINT s = firstRow;
    while (s <= lastRow)
    {
        const UINT n = (rowEnd!=NULL) ? rowEnd[s] : C.flatEnd;
        if (s + 3 <= lastRow && n >= s + 4 && (rowEnd==NULL || rowEnd[s + 3]==n))
        {
           const UINT64 h0 = hashes[s], h1 = hashes[s + 1], h2 = hashes[s + 2], h3 = hashes[s + 3];
           const UINT64 f0 = CheckFlipped ? flipped[s]     : 0;
           const UINT64 f1 = CheckFlipped ? flipped[s + 1] : 0;
           const UINT64 f2 = CheckFlipped ? flipped[s + 2] : 0;
           const UINT64 f3 = CheckFlipped ? flipped[s + 3] : 0;
           b0.clear(); b1.clear(); b2.clear(); b3.clear();

           if (QPV_SWAR_MATCH(h1, h0, f0)) b0.push_back(s + 1);
           if (QPV_SWAR_MATCH(h2, h0, f0)) b0.push_back(s + 2);
           if (QPV_SWAR_MATCH(h3, h0, f0)) b0.push_back(s + 3);
           if (QPV_SWAR_MATCH(h2, h1, f1)) b1.push_back(s + 2);
           if (QPV_SWAR_MATCH(h3, h1, f1)) b1.push_back(s + 3);
           if (QPV_SWAR_MATCH(h3, h2, f2)) b2.push_back(s + 3);

           for ( UINT mainIndex = s + 4 ; mainIndex < n ; mainIndex++)
           {
               const UINT64 hM = hashes[mainIndex];
               const int m0 = QPV_SWAR_MATCH(hM, h0, f0);
               const int m1 = QPV_SWAR_MATCH(hM, h1, f1);
               const int m2 = QPV_SWAR_MATCH(hM, h2, f2);
               const int m3 = QPV_SWAR_MATCH(hM, h3, f3);
               if ((m0 | m1 | m2 | m3) != 0)
               {
                  if (m0) b0.push_back(mainIndex);
                  if (m1) b1.push_back(mainIndex);
                  if (m2) b2.push_back(mainIndex);
                  if (m3) b3.push_back(mainIndex);
               }
           }

           if (!b0.empty()) dupesFlushRowHits(C, s,     b0, out, buf.maxId);
           if (!b1.empty()) dupesFlushRowHits(C, s + 1, b1, out, buf.maxId);
           if (!b2.empty()) dupesFlushRowHits(C, s + 2, b2, out, buf.maxId);
           if (!b3.empty()) dupesFlushRowHits(C, s + 3, b3, out, buf.maxId);
           s += 4;
           continue;
        }

        if (s + 1 < n)
        {
           const UINT64 h0 = hashes[s];
           const UINT64 f0 = CheckFlipped ? flipped[s] : 0;
           for ( UINT mainIndex = s + 1 ; mainIndex < n ; mainIndex++)
               if (QPV_SWAR_MATCH(hashes[mainIndex], h0, f0))
                  dupesEmitMatchedPair(C, s, mainIndex, h0, f0, out, buf.maxId);
        }
        s++;
    }

    #undef QPV_SWAR_MATCH
    #undef QPV_SWAR_DIST
}

#ifdef QPV_X64
template <bool Masked, bool CheckInverted, bool CheckFlipped>
static QPV_TARGET_POPCNT void sweepRowsPopcnt(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, DupesSweepBuf &buf) {
    const UINT64 *hashes = C.hashes;
    const UINT64 *flipped = C.flipped;
    const UINT   *rowEnd = C.rowEnd;
    const UINT64 hamMask = C.hamMask;
    const int    threshold = C.threshold;
    const int    maskBits = C.maskBits;
    const bool   invAll = CheckInverted && ((INT64)threshold * 2 > (INT64)maskBits);
    const UINT   invSpan = (CheckInverted && !invAll) ? (UINT)(maskBits - 2 * threshold) : 0u;
    (void)flipped; (void)hamMask; (void)invAll; (void)invSpan;

    std::vector<DupePairRec> &out = buf.v;
    std::vector<UINT> &b0 = buf.rowHits[0];
    std::vector<UINT> &b1 = buf.rowHits[1];
    std::vector<UINT> &b2 = buf.rowHits[2];
    std::vector<UINT> &b3 = buf.rowHits[3];

    #define QPV_HW_DIST(a, b) QPV_POPCNT64_HW(Masked ? (((a) ^ (b)) & hamMask) : ((a) ^ (b)))
    #define QPV_HW_MATCH(hM, hR, fR) ( \
        (CheckInverted ? (int)(invAll || ((UINT)(QPV_HW_DIST(hM, hR) - threshold) > invSpan)) \
                       : (int)(QPV_HW_DIST(hM, hR) < threshold)) \
        | (CheckFlipped ? (int)(QPV_HW_DIST(hM, fR) < threshold) : 0) \
    )

    UINT s = firstRow;
    while (s <= lastRow)
    {
        const UINT n = (rowEnd!=NULL) ? rowEnd[s] : C.flatEnd;
        if (s + 3 <= lastRow && n >= s + 4 && (rowEnd==NULL || rowEnd[s + 3]==n))
        {
           const UINT64 h0 = hashes[s], h1 = hashes[s + 1], h2 = hashes[s + 2], h3 = hashes[s + 3];
           const UINT64 f0 = CheckFlipped ? flipped[s]     : 0;
           const UINT64 f1 = CheckFlipped ? flipped[s + 1] : 0;
           const UINT64 f2 = CheckFlipped ? flipped[s + 2] : 0;
           const UINT64 f3 = CheckFlipped ? flipped[s + 3] : 0;
           b0.clear(); b1.clear(); b2.clear(); b3.clear();

           if (QPV_HW_MATCH(h1, h0, f0)) b0.push_back(s + 1);
           if (QPV_HW_MATCH(h2, h0, f0)) b0.push_back(s + 2);
           if (QPV_HW_MATCH(h3, h0, f0)) b0.push_back(s + 3);
           if (QPV_HW_MATCH(h2, h1, f1)) b1.push_back(s + 2);
           if (QPV_HW_MATCH(h3, h1, f1)) b1.push_back(s + 3);
           if (QPV_HW_MATCH(h3, h2, f2)) b2.push_back(s + 3);

           for ( UINT mainIndex = s + 4 ; mainIndex < n ; mainIndex++)
           {
               const UINT64 hM = hashes[mainIndex];
               const int m0 = QPV_HW_MATCH(hM, h0, f0);
               const int m1 = QPV_HW_MATCH(hM, h1, f1);
               const int m2 = QPV_HW_MATCH(hM, h2, f2);
               const int m3 = QPV_HW_MATCH(hM, h3, f3);
               if ((m0 | m1 | m2 | m3) != 0)
               {
                  if (m0) b0.push_back(mainIndex);
                  if (m1) b1.push_back(mainIndex);
                  if (m2) b2.push_back(mainIndex);
                  if (m3) b3.push_back(mainIndex);
               }
           }

           if (!b0.empty()) dupesFlushRowHits(C, s,     b0, out, buf.maxId);
           if (!b1.empty()) dupesFlushRowHits(C, s + 1, b1, out, buf.maxId);
           if (!b2.empty()) dupesFlushRowHits(C, s + 2, b2, out, buf.maxId);
           if (!b3.empty()) dupesFlushRowHits(C, s + 3, b3, out, buf.maxId);
           s += 4;
           continue;
        }

        if (s + 1 < n)
        {
           const UINT64 h0 = hashes[s];
           const UINT64 f0 = CheckFlipped ? flipped[s] : 0;
           for ( UINT mainIndex = s + 1 ; mainIndex < n ; mainIndex++)
               if (QPV_HW_MATCH(hashes[mainIndex], h0, f0))
                  dupesEmitMatchedPair(C, s, mainIndex, h0, f0, out, buf.maxId);
        }
        s++;
    }

    #undef QPV_HW_MATCH
    #undef QPV_HW_DIST
}

template <bool Masked, bool CheckInverted, bool CheckFlipped>
static QPV_TARGET_AVX2 void sweepRowsAVX2(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, DupesSweepBuf &buf) {
    const UINT64 *hashes = C.hashes;
    const UINT64 *flipped = C.flipped;
    const UINT   *rowEnd = C.rowEnd;
    const UINT64 hamMask = C.hamMask;
    const int    threshold = C.threshold;
    const int    maskBits = C.maskBits;
    const bool   invAll = CheckInverted && ((INT64)threshold * 2 > (INT64)maskBits);
    const UINT   invSpan = (CheckInverted && !invAll) ? (UINT)(maskBits - 2 * threshold) : 0u;
    (void)flipped; (void)hamMask; (void)invAll; (void)invSpan;

    std::vector<DupePairRec> &out = buf.v;
    std::vector<UINT> &b0 = buf.rowHits[0];
    std::vector<UINT> &b1 = buf.rowHits[1];
    std::vector<UINT> &b2 = buf.rowHits[2];
    std::vector<UINT> &b3 = buf.rowHits[3];

    const __m256i vLowMask = _mm256_set1_epi8(0x0F);
    const __m256i vLut = _mm256_setr_epi8(
        0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
        0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
    );
    const __m256i vZero   = _mm256_setzero_si256();
    const __m256i vMask   = _mm256_set1_epi64x((long long)hamMask);
    const __m256i vThresh = _mm256_set1_epi64x((long long)threshold);
    const __m256i vInvHi  = _mm256_set1_epi64x((long long)(maskBits - threshold));
    (void)vMask; (void)vInvHi;

    #define QPV_HW_DIST(a, b) QPV_POPCNT64_HW(Masked ? (((a) ^ (b)) & hamMask) : ((a) ^ (b)))
    #define QPV_HW_MATCH(hM, hR, fR) ( \
        (CheckInverted ? (int)(invAll || ((UINT)(QPV_HW_DIST(hM, hR) - threshold) > invSpan)) \
                       : (int)(QPV_HW_DIST(hM, hR) < threshold)) \
        | (CheckFlipped ? (int)(QPV_HW_DIST(hM, fR) < threshold) : 0) \
    )
    #define QPV_AVX2_POP64(outCnt, xVal) do { \
        const __m256i _x  = Masked ? _mm256_and_si256((xVal), vMask) : (xVal); \
        const __m256i _lo = _mm256_and_si256(_x, vLowMask); \
        const __m256i _hi = _mm256_and_si256(_mm256_srli_epi16(_x, 4), vLowMask); \
        const __m256i _p8 = _mm256_add_epi8(_mm256_shuffle_epi8(vLut, _lo), _mm256_shuffle_epi8(vLut, _hi)); \
        (outCnt) = _mm256_sad_epu8(_p8, vZero); \
    } while (0)
    #define QPV_AVX2_HIT(outHit, vhM, vhR, vfR) do { \
        __m256i _c; \
        QPV_AVX2_POP64(_c, _mm256_xor_si256((vhM), (vhR))); \
        __m256i _h = _mm256_cmpgt_epi64(vThresh, _c); \
        if constexpr (CheckInverted) \
           _h = _mm256_or_si256(_h, _mm256_cmpgt_epi64(_c, vInvHi)); \
        if constexpr (CheckFlipped) { \
           __m256i _cf; \
           QPV_AVX2_POP64(_cf, _mm256_xor_si256((vhM), (vfR))); \
           _h = _mm256_or_si256(_h, _mm256_cmpgt_epi64(vThresh, _cf)); \
        } \
        (outHit) = _h; \
    } while (0)
    #define QPV_PUSH_MASK4(vec, baseIdx, mask4) do { \
        if (mask4) { \
           if ((mask4) & 1) (vec).push_back((baseIdx)); \
           if ((mask4) & 2) (vec).push_back((baseIdx) + 1); \
           if ((mask4) & 4) (vec).push_back((baseIdx) + 2); \
           if ((mask4) & 8) (vec).push_back((baseIdx) + 3); \
        } \
    } while (0)

    UINT s = firstRow;
    while (s <= lastRow)
    {
        const UINT n = (rowEnd!=NULL) ? rowEnd[s] : C.flatEnd;
        if (s + 3 <= lastRow && n >= s + 4 && (rowEnd==NULL || rowEnd[s + 3]==n))
        {
           const UINT64 h0 = hashes[s], h1 = hashes[s + 1], h2 = hashes[s + 2], h3 = hashes[s + 3];
           const UINT64 f0 = CheckFlipped ? flipped[s]     : 0;
           const UINT64 f1 = CheckFlipped ? flipped[s + 1] : 0;
           const UINT64 f2 = CheckFlipped ? flipped[s + 2] : 0;
           const UINT64 f3 = CheckFlipped ? flipped[s + 3] : 0;
           b0.clear(); b1.clear(); b2.clear(); b3.clear();

           if (QPV_HW_MATCH(h1, h0, f0)) b0.push_back(s + 1);
           if (QPV_HW_MATCH(h2, h0, f0)) b0.push_back(s + 2);
           if (QPV_HW_MATCH(h3, h0, f0)) b0.push_back(s + 3);
           if (QPV_HW_MATCH(h2, h1, f1)) b1.push_back(s + 2);
           if (QPV_HW_MATCH(h3, h1, f1)) b1.push_back(s + 3);
           if (QPV_HW_MATCH(h3, h2, f2)) b2.push_back(s + 3);

           UINT mainIndex = s + 4;
           if (mainIndex + 4 <= n)
           {
              const __m256i vh0 = _mm256_set1_epi64x((long long)h0);
              const __m256i vh1 = _mm256_set1_epi64x((long long)h1);
              const __m256i vh2 = _mm256_set1_epi64x((long long)h2);
              const __m256i vh3 = _mm256_set1_epi64x((long long)h3);
              const __m256i vf0 = CheckFlipped ? _mm256_set1_epi64x((long long)f0) : vZero;
              const __m256i vf1 = CheckFlipped ? _mm256_set1_epi64x((long long)f1) : vZero;
              const __m256i vf2 = CheckFlipped ? _mm256_set1_epi64x((long long)f2) : vZero;
              const __m256i vf3 = CheckFlipped ? _mm256_set1_epi64x((long long)f3) : vZero;
              (void)vf0; (void)vf1; (void)vf2; (void)vf3;

              for ( ; mainIndex + 4 <= n ; mainIndex += 4)
              {
                  const __m256i vhM = _mm256_loadu_si256((const __m256i*)(hashes + mainIndex));
                  __m256i hit0, hit1, hit2, hit3;
                  QPV_AVX2_HIT(hit0, vhM, vh0, vf0);
                  QPV_AVX2_HIT(hit1, vhM, vh1, vf1);
                  QPV_AVX2_HIT(hit2, vhM, vh2, vf2);
                  QPV_AVX2_HIT(hit3, vhM, vh3, vf3);
                  const __m256i anyHit = _mm256_or_si256(_mm256_or_si256(hit0, hit1),
                                                         _mm256_or_si256(hit2, hit3));
                  if (_mm256_movemask_pd(_mm256_castsi256_pd(anyHit)) != 0)
                  {
                     const int m0 = _mm256_movemask_pd(_mm256_castsi256_pd(hit0));
                     const int m1 = _mm256_movemask_pd(_mm256_castsi256_pd(hit1));
                     const int m2 = _mm256_movemask_pd(_mm256_castsi256_pd(hit2));
                     const int m3 = _mm256_movemask_pd(_mm256_castsi256_pd(hit3));
                     QPV_PUSH_MASK4(b0, mainIndex, m0);
                     QPV_PUSH_MASK4(b1, mainIndex, m1);
                     QPV_PUSH_MASK4(b2, mainIndex, m2);
                     QPV_PUSH_MASK4(b3, mainIndex, m3);
                  }
              }
           }

           for ( ; mainIndex < n ; mainIndex++)
           {
               const UINT64 hM = hashes[mainIndex];
               if (QPV_HW_MATCH(hM, h0, f0)) b0.push_back(mainIndex);
               if (QPV_HW_MATCH(hM, h1, f1)) b1.push_back(mainIndex);
               if (QPV_HW_MATCH(hM, h2, f2)) b2.push_back(mainIndex);
               if (QPV_HW_MATCH(hM, h3, f3)) b3.push_back(mainIndex);
           }

           if (!b0.empty()) dupesFlushRowHits(C, s,     b0, out, buf.maxId);
           if (!b1.empty()) dupesFlushRowHits(C, s + 1, b1, out, buf.maxId);
           if (!b2.empty()) dupesFlushRowHits(C, s + 2, b2, out, buf.maxId);
           if (!b3.empty()) dupesFlushRowHits(C, s + 3, b3, out, buf.maxId);
           s += 4;
           continue;
        }

        if (s + 1 < n)
        {
           const UINT64 h0 = hashes[s];
           const UINT64 f0 = CheckFlipped ? flipped[s] : 0;
           UINT mainIndex = s + 1;
           if (mainIndex + 4 <= n)
           {
              b0.clear();
              const __m256i vh0 = _mm256_set1_epi64x((long long)h0);
              const __m256i vf0 = CheckFlipped ? _mm256_set1_epi64x((long long)f0) : vZero;
              (void)vf0;
              for ( ; mainIndex + 4 <= n ; mainIndex += 4)
              {
                  const __m256i vhM = _mm256_loadu_si256((const __m256i*)(hashes + mainIndex));
                  __m256i hit0;
                  QPV_AVX2_HIT(hit0, vhM, vh0, vf0);
                  const int m0 = _mm256_movemask_pd(_mm256_castsi256_pd(hit0));
                  QPV_PUSH_MASK4(b0, mainIndex, m0);
              }
              for ( ; mainIndex < n ; mainIndex++)
                  if (QPV_HW_MATCH(hashes[mainIndex], h0, f0))
                     b0.push_back(mainIndex);
              if (!b0.empty())
                 dupesFlushRowHits(C, s, b0, out, buf.maxId);
           }
           else
           {
              for ( ; mainIndex < n ; mainIndex++)
                  if (QPV_HW_MATCH(hashes[mainIndex], h0, f0))
                     dupesEmitMatchedPair(C, s, mainIndex, h0, f0, out, buf.maxId);
           }
        }
        s++;
    }

    #undef QPV_PUSH_MASK4
    #undef QPV_AVX2_HIT
    #undef QPV_AVX2_POP64
    #undef QPV_HW_MATCH
    #undef QPV_HW_DIST
    _mm256_zeroupper();
}
#endif

// mode: 0 = SWAR, 1 = hardware POPCNT, 2 = AVX2+POPCNT
static void sweepRowsDispatchMode(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, DupesSweepBuf &buf, const int mode) {
    if (C.threshold <= 0 || firstRow > lastRow)
       return;

    const int key = (C.preMasked ? 0 : 4)
                  | ((C.checkInverted==1) ? 2 : 0)
                  | ((C.checkFlipped==1) ? 1 : 0);

    #define QPV_DISPATCH_8(FN) switch (key) { \
        case 0: FN<false, false, false>(C, firstRow, lastRow, buf); break; \
        case 1: FN<false, false, true >(C, firstRow, lastRow, buf); break; \
        case 2: FN<false, true,  false>(C, firstRow, lastRow, buf); break; \
        case 3: FN<false, true,  true >(C, firstRow, lastRow, buf); break; \
        case 4: FN<true,  false, false>(C, firstRow, lastRow, buf); break; \
        case 5: FN<true,  false, true >(C, firstRow, lastRow, buf); break; \
        case 6: FN<true,  true,  false>(C, firstRow, lastRow, buf); break; \
        default: FN<true, true,  true >(C, firstRow, lastRow, buf); break; \
    }

#ifdef QPV_X64
    if (mode == 2 && qpvHasAvx2 && qpvHasPopcnt) { QPV_DISPATCH_8(sweepRowsAVX2); return; }
    if (mode >= 1 && qpvHasPopcnt)               { QPV_DISPATCH_8(sweepRowsPopcnt); return; }
#endif
    (void)mode;
    QPV_DISPATCH_8(sweepRowsSWAR);

    #undef QPV_DISPATCH_8
}

static void sweepRowsInto(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, DupesSweepBuf &buf) {
#ifdef QPV_X64
    const int mode = (qpvHasAvx2 && qpvHasPopcnt) ? 2 : (qpvHasPopcnt ? 1 : 0);
#else
    const int mode = 0;
#endif
    sweepRowsDispatchMode(C, firstRow, lastRow, buf, mode);
}

static void dupesReservePairs(size_t need) {
    size_t cap = dupesPairsList.capacity();
    if (need <= cap)
       return;

    if (cap < 4096)
       cap = 4096;

    while (cap < need)
    {
        const size_t grown = cap + cap / 2;
        if (grown <= cap)
        {
           cap = need;
           break;
        }

        cap = grown;
    }

    dupesPairsList.reserve(cap);
}

static INT64 dupesPlanRows(const DupesSweepCtx &C, const UINT firstRow, const UINT lastRow, const INT64 costBudget, const INT64 itemTarget, UINT &stoppedAt, const UINT stopBeforeLarge = 0) {
    dupesSweepPlan.clear();
    stoppedAt = firstRow;
    if (firstRow > lastRow)
       return 0;

    const UINT  *rowEnd = C.rowEnd;
    const INT64  last = (INT64)lastRow;
    INT64 comparisons = 0, cost = 0;
    INT64 r = (INT64)firstRow;
    bool hitLarge = false;
    while (r <= last && !hitLarge)
    {
        const INT64 itemFirst = r;
        INT64 itemCost = 0;
        while (r <= last)
        {
            const UINT row = (UINT)r;
            const UINT end = (rowEnd!=NULL) ? rowEnd[row] : C.flatEnd;
            if (stopBeforeLarge > 0 && rowEnd!=NULL && r > (INT64)firstRow
                && (row == 0 || rowEnd[row - 1] <= row)
                && end > row && (end - row) >= stopBeforeLarge)
            {
               hitLarge = true;
               break;
            }
            const INT64 c = (end > row + 1) ? (INT64)(end - row - 1) : 0;
            comparisons += c;
            cost        += c + QPV_SWEEP_ROW_COST;
            itemCost    += c + QPV_SWEEP_ROW_COST;
            r++;
            if (itemCost >= itemTarget)
               break;
        }

        if (r == itemFirst)
           break;

        DupesSweepItem it;
        it.firstRow = (UINT)itemFirst;
        it.lastRow  = (UINT)(r - 1);
        it.slot   = 0;
        it.failed = 0;
        it.begin  = 0;
        it.count  = 0;
        try
        {
            dupesSweepPlan.push_back(it);
        }
        catch (...)
        {
            dupesSweepPlan.clear();
            dupesSweepAllocFailed = true;
            stoppedAt = firstRow;
            return 0;
        }
        if (costBudget > 0 && cost >= costBudget)
           break;

        if ((INT64)dupesSweepPlan.size() >= QPV_SWEEP_MAX_ITEMS)
           break;
    }

    stoppedAt = (UINT)r;
    return comparisons;
}

static INT64 dupesPlanMihRows(const UINT firstRow, const UINT groupEnd, const UINT rowBudget, const int nThreads, UINT &stoppedAt) {
    dupesSweepPlan.clear();
    stoppedAt = firstRow;
    if (firstRow >= groupEnd)
       return 0;

    UINT take = groupEnd - firstRow;
    if (rowBudget > 0 && take > rowBudget)
       take = rowBudget;
    if (take < 1)
       take = 1;

    UINT itemRows = take / (UINT)(nThreads * 8);
    if (itemRows < 32)
       itemRows = 32;
    const UINT minItemForCap = (take + QPV_SWEEP_MAX_ITEMS - 1) / QPV_SWEEP_MAX_ITEMS;
    if (itemRows < minItemForCap)
       itemRows = minItemForCap;

    const UINT planEnd = firstRow + take;
    UINT r = firstRow;
    while (r < planEnd)
    {
        UINT itemEnd = r + itemRows;
        if (itemEnd > planEnd)
           itemEnd = planEnd;

        DupesSweepItem it;
        it.firstRow = r;
        it.lastRow  = itemEnd - 1;
        it.slot   = 0;
        it.failed = 0;
        it.begin  = 0;
        it.count  = 0;
        try
        {
            dupesSweepPlan.push_back(it);
        }
        catch (...)
        {
            dupesSweepPlan.clear();
            dupesSweepAllocFailed = true;
            stoppedAt = firstRow;
            return 0;
        }
        r = itemEnd;
    }

    stoppedAt = planEnd;
    const INT64 rows = (INT64)(planEnd - firstRow);
    const INT64 hi = (INT64)(groupEnd - firstRow - 1);
    const INT64 lo = (INT64)(groupEnd - planEnd);
    return (hi + lo) * rows / 2;
}

static void dupesSweepWorker(const DupesSweepCtx *ctx, DupesSweepItem *items, const int nItems, DupesSweepBuf *bufs, const int slot) {
    std::vector<DupePairRec> &out = bufs[slot].v;
    for (;;)
    {
        const int i = dupesSweepCursor.fetch_add(1, std::memory_order_relaxed);
        if (i >= nItems)
           break;

        const size_t begin = out.size();
        int failed = 0;
        try
        {
            if (ctx->mih!=NULL)
               mihSweepRowsInto(*ctx, *ctx->mih, items[i].firstRow, items[i].lastRow, bufs[slot]);
            else
               sweepRowsInto(*ctx, items[i].firstRow, items[i].lastRow, bufs[slot]);
        }
        catch (...)
        {
            failed = 1;
            if (!bufs[slot].mihBits.empty())
               std::fill(bufs[slot].mihBits.begin(), bufs[slot].mihBits.end(), 0ULL);
            bufs[slot].mihHits.clear();
            for ( int b = 0 ; b < 4 ; b++)
                bufs[slot].rowHits[b].clear();
        }

        items[i].slot   = slot;
        items[i].failed = failed;
        items[i].begin  = begin;
        items[i].count  = out.size() - begin;
    }
}

static size_t dupesRunPlan(const DupesSweepCtx &C, const int nThreads, int *teamOut) {
    const int nItems = (int)dupesSweepPlan.size();
    if (teamOut!=NULL)
       *teamOut = 0;

    if (nItems < 1)
       return 0;

    int team = nThreads;
    if (team > nItems)
       team = nItems;

    if (team < 1)
       team = 1;

    if ((int)dupesSweepBufs.size() < team)
    {
       try
       {
           dupesSweepBufs.resize((size_t)team);
       }
       catch (...)
       {
           if (dupesSweepBufs.empty())
           {
              try
              {
                  dupesSweepBufs.resize(1);
              }
              catch (...)
              {
                  dupesSweepAllocFailed = true;
                  return 0;
              }
           }
           team = (int)dupesSweepBufs.size();
       }
    }

    for ( int t = 0 ; t < team ; t++)
    {
        dupesSweepBufs[t].v.clear();
        dupesSweepBufs[t].maxId = 0;
    }

    DupesSweepItem *items = dupesSweepPlan.data();
    DupesSweepBuf  *bufs  = dupesSweepBufs.data();
    const DupesSweepCtx *ctx = &C;
    dupesSweepCursor.store(0, std::memory_order_relaxed);

    std::vector<std::thread> crew;
    if (team > 1)
    {
       try
       {
           crew.reserve((size_t)(team - 1));
           for ( int t = 1 ; t < team ; t++)
               crew.push_back(std::thread(dupesSweepWorker, ctx, items, nItems, bufs, t));
       }
       catch (...)
       {
       }
    }

    dupesSweepWorker(ctx, items, nItems, bufs, 0);
    for ( size_t t = 0 ; t < crew.size() ; t++)
        crew[t].join();

    if (teamOut!=NULL)
       *teamOut = (int)crew.size() + 1;

    size_t results = 0;
    for ( int i = 0 ; i < nItems ; i++)
    {
        results += dupesSweepPlan[i].count;
        if (dupesSweepPlan[i].failed!=0)
           dupesSweepAllocFailed = true;
    }

    if (results > 0)
    {
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
           if (dupesPairsMaxIdCount + results == dupesPairsList.size())
           {
              for (int t = 0; t < team; t++)
                  if (dupesSweepBufs[t].maxId > dupesPairsMaxId)
                     dupesPairsMaxId = dupesSweepBufs[t].maxId;
              dupesPairsMaxIdCount = dupesPairsList.size();
           }
       }
       catch (...)
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

        results += dupesRunPlan(C, nThreads, NULL);
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
    if (hoffset==NULL)
       return 0;

    *hoffset = 0;
    const UINT n = arraySize;
    if (givenHashesArray==NULL || givenIDs==NULL || n < 2 || offsetu < 0 || (UINT)offsetu >= n || stepping < 0)
       return 0;

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
    C.rowEnd   = NULL;
    C.flatEnd  = n;
    C.hamMask  = buildHamMask(hamDistLBorderCrop, hamDistRBorderCrop);
    C.maskBits = popcount64(C.hamMask);
    C.threshold = threshold;
    C.checkInverted = checkInverted;
    C.checkFlipped  = (givenFlippedHashesArray!=NULL) ? checkFlipped : 0;
    C.wantMSD  = (doMSD==1 && dupesPixStride > 0 && dupesPixOK.size() >= (size_t)arraySize);
    C.preMasked = (C.hamMask == ~0ULL);
    C.mih      = NULL;
    if (C.wantMSD)
       dupesPairsMSD = 1;

    // The caller walks the outer index in batches of "stepping" so it can show
    // progress and stay interruptible; the old code covered offsetu ..
    // offsetu+stepping inclusive, which is preserved here. Arithmetic stays in
    // INT64 so large stepping values cannot overflow signed 32-bit INT.
    const INT64 firstIndex = (INT64)offsetu;
    INT64 lastIndex = firstIndex + (INT64)stepping;
    if (lastIndex > (INT64)n - 1)
       lastIndex = (INT64)n - 1;

    if (lastIndex - firstIndex >= (INT64)0x7FFFFFFF)
       lastIndex = firstIndex + (INT64)0x7FFFFFFF - 1;

    if (firstIndex > lastIndex)
       return 0;

    const UINT results = sweepOuterRange(C, 0, n, (UINT)firstIndex, (UINT)lastIndex);
    *hoffset = (int)(lastIndex - firstIndex + 1);
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
    dupesMIH.release();
    dupesScanHashes.clear();
    dupesScanFlipped.clear();
    dupesScanIDs.clear();
    dupesScanGroupStart.clear();
    dupesScanRowEnd.clear();
    dupesPixData.clear();
    dupesPixOK.clear();
    dupesDropSavedPairs();
    dupesSweepActive = false;
    dupesPairsList.clear();
    dupesPairsMSD = 0;
    dupesPairsMaxId = 0;
    dupesPairsMaxIdCount = 0;
    dupesPairsRead = 0;
    dupesScanRows = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 0;
    dupesScanMihBlock = 0;
    dupesScanMaskApplied = ~0ULL;
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
        if (groups < 0xFFFFFFFFu)
           dupesScanGroupStart.reserve((size_t)groups + 1);
        if (doMSD==1 && pixStride > 0)
        {
           if ((size_t)rows > ((size_t)-1) / (size_t)pixStride)
              throw std::bad_alloc();
           dupesPixStride = (UINT)pixStride;
           dupesPixScale = (grayCompressor > 1) ? grayCompressor : 1;
           dupesPixData.assign((size_t)rows * (size_t)pixStride, 0);
           dupesPixOK.assign(rows, 0);
           dupesScanWantMSD = 1;
        }
    }
    catch (...)
    {
        dupesScanHashes.clear();
        dupesScanIDs.clear();
        dupesScanGroupStart.clear();
        dupesPixData.clear();
        dupesPixOK.clear();
        dupesPixStride = 0;
        dupesScanWantMSD = 0;
        dupesScanState.lastError = 1;
        dupesScanState.phase = -1;
        return 0;
    }

    dupesScanRows = rows;
    dupesSweepActive = true;
    dupesScanState.phase = 1;
    dupesScanState.rows = (LONG)rows;
    return 1;
}

// Fills rows [firstIndex, firstIndex+count) from AHK-side buffers. flipped may be NULL
// when findFlippedDupes=0, pixelBlob when MSD is off; pixelBlob holds count records of
// pixStride UTF-16 code units, the same Chr(gray+161) encoding the database stores.
DLL_API int DLL_CALLCONV dupesScanFeed(UINT firstIndex, UINT count, const UINT64 *hashes, const UINT64 *flipped, const UINT *ids, const wchar_t *pixelBlob) {
    if (count==0 || firstIndex > dupesScanRows || count > dupesScanRows - firstIndex)
       return 0;

    if (hashes!=NULL)
    {
       memcpy(&dupesScanHashes[firstIndex], hashes, (size_t)count * sizeof(UINT64));
       dupesScanMaskApplied = ~0ULL;
    }

    if (ids!=NULL)
       memcpy(&dupesScanIDs[firstIndex], ids, (size_t)count * sizeof(UINT));

    if (flipped!=NULL)
    {
       if (dupesScanFlipped.size() < dupesScanRows)
       {
          try
          {
             dupesScanFlipped.assign(dupesScanRows, 0);
          }
          catch (...)
          {
             dupesScanFlipped.clear();
             dupesScanState.lastError = 1;
             dupesScanState.phase = -1;
             return 0;
          }
       }

       memcpy(&dupesScanFlipped[firstIndex], flipped, (size_t)count * sizeof(UINT64));
       dupesScanMaskApplied = ~0ULL;
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

    if (groups==0xFFFFFFFFu || groups > dupesScanRows)
    {
       dupesScanGroupStart.clear();
       dupesScanState.lastError = 2;
       dupesScanState.phase = -1;
       return 0;
    }

    try
    {
       dupesScanGroupStart.assign(groupStart, groupStart + (size_t)groups + 1);
    }
    catch (...)
    {
       dupesScanGroupStart.clear();
       dupesScanState.lastError = 1;
       dupesScanState.phase = -1;
       return 0;
    }
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

    dupesMIH.release();
    dupesScanState.groups = (LONG)groups;
    dupesScanState.total = total;
    dupesScanOuter = 0;
    dupesScanBlock = 1 << 16;
    dupesScanMihBlock = 0;
    dupesScanMaskApplied = ~0ULL;
    dupesScanState.phase = 3;
    return 1;
}

DLL_API int DLL_CALLCONV dupesScanStep(int threshold, UINT hamDistLBorderCrop, UINT hamDistRBorderCrop, int checkInverted, int checkFlipped, int msBudget) {
    if (dupesScanGroupStart.size() < 2 || dupesScanRows < 2 || dupesScanRowEnd.size() < (size_t)dupesScanRows)
    {
       dupesMIH.release();
       if (dupesScanState.phase!=-1)
       {
          if (dupesScanState.threads < 1)
             dupesScanState.threads = 1;
          dupesScanState.phase = 5;
       }

       return 0;
    }

    const UINT64 hamMask = buildHamMask(hamDistLBorderCrop, hamDistRBorderCrop);
    if (hamMask != ~0ULL && dupesScanMaskApplied != hamMask)
    {
       UINT64 *hd = dupesScanHashes.data();
       for ( UINT i = 0 ; i < dupesScanRows ; i++)
           hd[i] &= hamMask;
       if (dupesScanFlipped.size() >= dupesScanRows)
       {
          UINT64 *fh = dupesScanFlipped.data();
          for ( UINT i = 0 ; i < dupesScanRows ; i++)
              fh[i] &= hamMask;
       }
       dupesScanMaskApplied = hamMask;
    }

    DupesSweepCtx C;
    C.hashes   = dupesScanHashes.data();
    C.flipped  = (dupesScanFlipped.size() >= dupesScanRows) ? dupesScanFlipped.data() : dupesScanHashes.data();
    C.ids      = dupesScanIDs.data();
    C.rowEnd   = dupesScanRowEnd.data();
    C.flatEnd  = dupesScanRows;
    C.hamMask  = hamMask;
    C.maskBits = popcount64(hamMask);
    C.threshold = threshold;
    C.checkInverted = checkInverted;
    C.checkFlipped  = (dupesScanFlipped.size() >= dupesScanRows) ? checkFlipped : 0;
    C.wantMSD  = (dupesScanWantMSD==1 && dupesPixStride > 0 && dupesPixOK.size() >= dupesScanRows);
    C.preMasked = true;
    C.mih      = NULL;
    if (C.wantMSD)
       dupesPairsMSD = 1;

    if (msBudget < 1)
       msBudget = 1;

    if (dupesScanBlock < 4096)
       dupesScanBlock = 1 << 16;

    const double blockTargetMs = (double)msBudget / 8.0;
    const std::chrono::steady_clock::time_point tStart = std::chrono::steady_clock::now();
    const int nThreads = dupesSweepThreads();
    const bool mihPossible = (threshold >= 1 && (threshold - 1) <= QPV_MIH_MAX_R);
    dupesSweepAllocFailed = false;
    dupesScanState.phase = 3;

    while (dupesScanOuter < dupesScanRows)
    {
        if (dupesMIH.groupEnd > dupesMIH.groupStart && dupesScanOuter >= dupesMIH.groupEnd)
           dupesMIH.release();

        if (mihPossible)
        {
           const UINT cur = dupesScanOuter;
           const UINT curEnd = dupesScanRowEnd[cur];
           if (!dupesMIH.matches(cur, C))
           {
              if (dupesMIH.groupEnd > dupesMIH.groupStart)
                 dupesMIH.release();

              if ((cur == 0 || dupesScanRowEnd[cur - 1] <= cur)
                  && curEnd > cur && (curEnd - cur) >= QPV_MIH_MIN_GROUP)
              {
                 if (dupesMIHBuild(C, cur, curEnd))
                    dupesScanMihBlock = 0;
              }
           }

           if (dupesMIH.active && dupesMIH.matches(cur, C))
           {
              C.mih = &dupesMIH;
              if (dupesScanMihBlock < 128)
                 dupesScanMihBlock = (msBudget < 20) ? 1024u : 8192u;

              UINT stoppedAt = dupesScanOuter;
              const INT64 planned = dupesPlanMihRows(dupesScanOuter, dupesMIH.groupEnd, dupesScanMihBlock, nThreads, stoppedAt);
              if (dupesSweepAllocFailed)
              {
                 dupesMIH.release();
                 dupesScanState.lastError = 1;
                 dupesScanState.phase = -1;
                 return 0;
              }
              if (stoppedAt <= dupesScanOuter)
                 break;

              int team = 0;
              const std::chrono::steady_clock::time_point tBlock = std::chrono::steady_clock::now();
              const size_t got = dupesRunPlan(C, nThreads, &team);
              const double blockMs = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tBlock).count();
              if ((LONG)team > dupesScanState.threads)
                 dupesScanState.threads = (LONG)team;

              dupesScanState.pairs += (INT64)got;
              dupesScanState.done += planned;
              dupesScanOuter = stoppedAt;
              if (dupesSweepAllocFailed)
              {
                 dupesMIH.release();
                 dupesScanState.lastError = 1;
                 dupesScanState.phase = -1;
                 return 0;
              }

              if (dupesScanOuter >= dupesMIH.groupEnd)
                 dupesMIH.release();

              if (blockMs < blockTargetMs * 0.5 && dupesScanMihBlock < (1u << 20))
                 dupesScanMihBlock *= 2;
              else if (blockMs > blockTargetMs && dupesScanMihBlock > 128)
                 dupesScanMihBlock /= 2;

              if (std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tStart).count() >= msBudget)
                 return 1;
              continue;
           }
        }
        else if (dupesMIH.groupEnd > dupesMIH.groupStart)
           dupesMIH.release();

        C.mih = NULL;
        INT64 itemTarget = dupesScanBlock / ((INT64)nThreads * 8);
        if (itemTarget < QPV_SWEEP_MIN_ITEM)
           itemTarget = QPV_SWEEP_MIN_ITEM;

        UINT stoppedAt = dupesScanOuter;
        const INT64 planned = dupesPlanRows(C, dupesScanOuter, dupesScanRows - 1, dupesScanBlock, itemTarget, stoppedAt, mihPossible ? QPV_MIH_MIN_GROUP : 0);
        if (dupesSweepAllocFailed)
        {
           dupesMIH.release();
           dupesScanState.lastError = 1;
           dupesScanState.phase = -1;
           return 0;
        }
        if (stoppedAt <= dupesScanOuter)
           break;

        int team = 0;
        const std::chrono::steady_clock::time_point tBlock = std::chrono::steady_clock::now();
        const size_t got = dupesRunPlan(C, nThreads, &team);
        const double blockMs = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tBlock).count();
        if ((LONG)team > dupesScanState.threads)
           dupesScanState.threads = (LONG)team;

        dupesScanState.pairs += (INT64)got;
        dupesScanState.done += planned;
        dupesScanOuter = stoppedAt;
        if (dupesSweepAllocFailed)
        {
           dupesMIH.release();
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

    dupesMIH.release();
    if (dupesScanState.threads < 1)
       dupesScanState.threads = 1;
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
    dupesScanMihBlock = 0;
    dupesScanMaskApplied = ~0ULL;
    if (dupesHasSavedPairs)
    {
       if (dupesScanState.phase!=5 || dupesPairsList.empty())
          dupesRestoreSavedPairs();
    }
    else if (dupesSweepActive && dupesScanState.phase!=5)
    {
       dupesPairsList.clear();
       dupesPairsList.shrink_to_fit();
       dupesPairsMSD = 0;
       dupesPairsMaxId = 0;
       dupesPairsMaxIdCount = 0;
    }
    dupesSweepActive = false;
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

static int dupesCmpTagLexZFallback(UINT a, UINT b) {
    char sa[16], sb[16], rev[16];
    int na = 0, nb = 0, r = 0;
    UINT v = a;
    do { rev[r++] = (char)('0' + (v % 10)); v /= 10; } while (v!=0);
    while (r > 0) sa[na++] = rev[--r];
    sa[na++] = 'z';
    sa[na] = '\0';

    v = b;
    do { rev[r++] = (char)('0' + (v % 10)); v /= 10; } while (v!=0);
    while (r > 0) sb[nb++] = rev[--r];
    sb[nb++] = 'z';
    sb[nb] = '\0';

    return strcmp(sa, sb);
}

struct DupesTagRank65 { unsigned char r[65]; };

static const DupesTagRank65& dupesTagRankTable() {
    static const DupesTagRank65 tbl = []() {
        unsigned char idx[65];
        for (int i = 0; i <= 64; i++) idx[i] = (unsigned char)i;
        std::sort(idx, idx + 65, [](unsigned char a, unsigned char b) {
            return dupesCmpTagLexZFallback(a, b) < 0;
        });
        DupesTagRank65 out = {};
        for (int pos = 0; pos <= 64; pos++) out.r[idx[pos]] = (unsigned char)pos;
        return out;
    }();
    return tbl;
}

// Lexicographic comparison of decimal(a)+'z' vs decimal(b)+'z' for BreakDupesGroups=1.
QPV_FORCEINLINE int dupesCmpTagLexZ(UINT a, UINT b, const unsigned char *rank65) {
    if (a==b)
       return 0;
    if (a <= 64 && b <= 64)
       return (int)rank65[a] - (int)rank65[b];
    return dupesCmpTagLexZFallback(a, b);
}

// The group ID column 23 carries: "<root>_<tag>". Kept inline for tests/filter_oracle.cpp.
static inline std::string dupesGroupID(UINT root, UINT tag) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%u_%u", root, tag);
    return std::string(buf);
}

DLL_API int DLL_CALLCONV dupesHaveMSD();

DLL_API UINT DLL_CALLCONV dupesApplyFilter(int hamLo, int hamHi, int mseLo, int mseHi, int breakGroups, int remSingles, const unsigned char *imgKeep, UINT imgKeepCount) {
    dupesFilterRows.clear();
    const size_t n = dupesPairsList.size();
    if (n < 1)
    {
       dupesRestoreSavedPairs();
       return 0;
    }

    if (hamLo > hamHi)
       std::swap(hamLo, hamHi);
    if (mseLo > mseHi)
       std::swap(mseLo, mseHi);

    const bool allowMSE = (dupesHaveMSD()==1);
    const UINT NONE = 0xFFFFFFFFu;
    const UINT minMembers = (UINT)((remSingles > 0) ? remSingles : 0);
    const size_t hintSlots = (dupesPairsMaxIdCount == n && dupesPairsMaxId < NONE)
                           ? ((size_t)dupesPairsMaxId + 1) : 0;

    try
    {
        if (breakGroups==1)
        {
           std::vector<UINT> rowRoot, rowTag, imgHam, imgMSE;
           size_t idSlots = 0, keptCount = 0;
           UINT minKeptId = NONE, maxKeptId = 0;

           for ( size_t i = 0 ; i < n ; i++)
           {
               const DupePairRec &p = dupesPairsList[i];
               if (!dupesInRange(p.hamDist, hamLo, hamHi))
                  continue;

               if (allowMSE && !dupesInRange(p.mse, mseLo, mseHi))
                  continue;

               if (imgKeep!=NULL && (p.idA >= imgKeepCount || (imgKeep[p.idA] & 1)==0))
                  continue;

               const UINT a = p.idA, b = p.idB;
               const UINT hiId = (a > b) ? a : b;
               if (hiId >= idSlots)
               {
                  if (hiId==NONE)
                  {
                     dupesRestoreSavedPairs();
                     return 0;
                  }
                  size_t newSlots = (idSlots == 0) ? hintSlots : (idSlots + idSlots / 2 + 64);
                  const size_t need = (size_t)hiId + 1;
                  if (newSlots < need) newSlots = need;
                  if (newSlots > (size_t)NONE) newSlots = (size_t)NONE;
                  rowRoot.resize(newSlots, NONE);
                  rowTag.resize(newSlots, 0);
                  imgHam.resize(newSlots, NONE);
                  imgMSE.resize(newSlots, NONE);
                  idSlots = newSlots;
               }

               const UINT loId = (a < b) ? a : b;
               if (loId < minKeptId) minKeptId = loId;
               if (hiId > maxKeptId) maxKeptId = hiId;
               keptCount++;

               const bool hasA = (rowRoot[a]!=NONE), hasB = (rowRoot[b]!=NONE);
               if (hasA && hasB)
               {
                  rowTag[a] = p.hamDist;
                  imgHam[a] = p.hamDist;
                  imgMSE[a] = p.mse;
                  rowTag[b] = p.hamDist;
                  imgHam[b] = p.hamDist;
                  imgMSE[b] = p.mse;
                  continue;
               }

               if (!hasA && !hasB)
               {
                  const UINT root = loId;
                  rowRoot[a] = rowRoot[b] = root;
                  rowTag[a] = rowTag[b] = p.hamDist;
                  imgHam[a] = imgHam[b] = p.hamDist;
                  imgMSE[a] = imgMSE[b] = p.mse;
                  continue;
               }

               const UINT root = hasA ? rowRoot[a] : rowRoot[b];
               if (!hasA) { imgHam[a] = 100; imgMSE[a] = QPV_MSD_NONE; }
               if (!hasB) { imgHam[b] = 100; imgMSE[b] = QPV_MSD_NONE; }
               rowRoot[a] = rowRoot[b] = root;
               rowTag[a] = rowTag[b] = p.hamDist;

               const UINT lowHam = (p.hamDist < imgHam[a]) ? p.hamDist : imgHam[a];
               const UINT lowHam2 = (lowHam < imgHam[b]) ? lowHam : imgHam[b];
               const UINT lowMSE = (p.mse < imgMSE[a]) ? p.mse : imgMSE[a];
               const UINT lowMSE2 = (lowMSE < imgMSE[b]) ? lowMSE : imgMSE[b];
               imgHam[a] = lowHam2;
               imgMSE[a] = lowMSE2;
               imgHam[b] = p.hamDist;
               imgMSE[b] = p.mse;
           }

           if (keptCount==0)
           {
              dupesRestoreSavedPairs();
              return 0;
           }

           const size_t activeSlots = (size_t)maxKeptId + 1;
           size_t orderCount = 0;
           for ( size_t idu = minKeptId ; idu < activeSlots ; idu++)
           {
               if (rowRoot[idu]==NONE)
                  continue;
               if (imgKeep!=NULL && idu < (size_t)imgKeepCount && (imgKeep[idu] & 2))
                  continue;
               orderCount++;
           }

           struct SortEnt { UINT root; UINT tag; UINT idu; };
           std::vector<SortEnt> order;
           order.reserve(orderCount);

           std::vector<UINT> seen;
           std::vector<UINT64> keepIDs;
           if (minMembers > 0)
              seen.assign(activeSlots, 0);

           for ( size_t idu = minKeptId ; idu < activeSlots ; idu++)
           {
               if (rowRoot[idu]==NONE)
                  continue;
               if (imgKeep!=NULL && idu < (size_t)imgKeepCount && (imgKeep[idu] & 2))
                  continue;

               const UINT root = rowRoot[idu];
               const UINT tag  = rowTag[idu];
               if (minMembers > 0)
               {
                  seen[root]++;
                  if (seen[root] > minMembers)
                     keepIDs.push_back(((UINT64)root << 32) | (UINT64)tag);
               }
               order.push_back({ root, tag, (UINT)idu });
           }

           const unsigned char *tagRank = dupesTagRankTable().r;
           std::sort(order.begin(), order.end(), [tagRank](const SortEnt &a, const SortEnt &b) {
               if (a.root!=b.root) return a.root < b.root;
               if (a.tag!=b.tag)   return dupesCmpTagLexZ(a.tag, b.tag, tagRank) < 0;
               return a.idu < b.idu;
           });

           if (minMembers > 0)
           {
              std::sort(keepIDs.begin(), keepIDs.end());
              keepIDs.erase(std::unique(keepIDs.begin(), keepIDs.end()), keepIDs.end());
           }

           dupesFilterRows.reserve(order.size());
           for ( size_t i = 0 ; i < order.size() ; i++)
           {
               if (minMembers > 0)
               {
                  const UINT64 gidKey = ((UINT64)order[i].root << 32) | (UINT64)order[i].tag;
                  if (!std::binary_search(keepIDs.begin(), keepIDs.end(), gidKey))
                     continue;
               }

               const UINT idu = order[i].idu;
               DupeResultRow row;
               row.imgIndex = idu;
               row.groupRoot = rowRoot[idu];
               row.grpTag = rowTag[idu];
               row.hamDist = (imgHam[idu]!=NONE) ? imgHam[idu] : 100;
               row.mse = (imgMSE[idu]!=NONE) ? imgMSE[idu] : QPV_MSD_NONE;
               dupesFilterRows.push_back(row);
           }
        }
        else
        {
           std::vector<UINT> parent, imgHam, imgMSE;
           size_t idSlots = 0, keptCount = 0;
           UINT minKeptId = NONE, maxKeptId = 0;

           for ( size_t i = 0 ; i < n ; i++)
           {
               const DupePairRec &p = dupesPairsList[i];
               if (!dupesInRange(p.hamDist, hamLo, hamHi))
                  continue;

               if (allowMSE && !dupesInRange(p.mse, mseLo, mseHi))
                  continue;

               if (imgKeep!=NULL && (p.idA >= imgKeepCount || (imgKeep[p.idA] & 1)==0))
                  continue;

               const UINT a = p.idA, b = p.idB;
               const UINT hiId = (a > b) ? a : b;
               if (hiId >= idSlots)
               {
                  if (hiId==NONE)
                  {
                     dupesRestoreSavedPairs();
                     return 0;
                  }
                  size_t newSlots = (idSlots == 0) ? hintSlots : (idSlots + idSlots / 2 + 64);
                  const size_t need = (size_t)hiId + 1;
                  if (newSlots < need) newSlots = need;
                  if (newSlots > (size_t)NONE) newSlots = (size_t)NONE;
                  const size_t oldSlots = idSlots;
                  parent.resize(newSlots);
                  for (size_t k = oldSlots; k < newSlots; k++)
                      parent[k] = (UINT)k;
                  imgHam.resize(newSlots, NONE);
                  imgMSE.resize(newSlots, NONE);
                  idSlots = newSlots;
               }

               const UINT loId = (a < b) ? a : b;
               if (loId < minKeptId) minKeptId = loId;
               if (hiId > maxKeptId) maxKeptId = hiId;
               keptCount++;

               const UINT ra = dupesFindRoot(parent, a), rb = dupesFindRoot(parent, b);
               if (ra!=rb)
                  parent[(ra > rb) ? ra : rb] = (ra < rb) ? ra : rb;

               if (imgHam[a]==NONE || p.hamDist < imgHam[a]) imgHam[a] = p.hamDist;
               if (imgHam[b]==NONE || p.hamDist < imgHam[b]) imgHam[b] = p.hamDist;
               if (imgMSE[a]==NONE || p.mse < imgMSE[a])     imgMSE[a] = p.mse;
               if (imgMSE[b]==NONE || p.mse < imgMSE[b])     imgMSE[b] = p.mse;
           }

           if (keptCount==0)
           {
              dupesRestoreSavedPairs();
              return 0;
           }

           const size_t activeSlots = (size_t)maxKeptId + 1;
           std::vector<UINT> grpHam(activeSlots, NONE);
           std::vector<UINT> seen(activeSlots, 0);
           for ( size_t idu = minKeptId ; idu < activeSlots ; idu++)
           {
               if (imgHam[idu]==NONE)
                  continue;

               const UINT r = dupesFindRoot(parent, (UINT)idu);
               parent[idu] = r;
               if (grpHam[r]==NONE || imgHam[idu] < grpHam[r])
                  grpHam[r] = imgHam[idu];

               if (imgKeep!=NULL && idu < (size_t)imgKeepCount && (imgKeep[idu] & 2))
                  continue;

               seen[r]++;
           }

           // Prefix sum over surviving roots gives direct (root, idu) output offsets.
           size_t totalOut = 0;
           for ( size_t r = minKeptId ; r < activeSlots ; r++)
           {
               const UINT cnt = seen[r];
               if (cnt > minMembers)
               {
                  seen[r] = (UINT)totalOut;
                  totalOut += cnt;
               }
               else
                  seen[r] = NONE;
           }

           if (totalOut > 0)
           {
              dupesFilterRows.resize(totalOut);
              DupeResultRow *dst = dupesFilterRows.data();
              for ( size_t idu = minKeptId ; idu < activeSlots ; idu++)
              {
                  if (imgHam[idu]==NONE)
                     continue;

                  if (imgKeep!=NULL && idu < (size_t)imgKeepCount && (imgKeep[idu] & 2))
                     continue;

                  const UINT r = parent[idu];
                  const UINT pos = seen[r];
                  if (pos==NONE)
                     continue;

                  seen[r] = pos + 1;
                  DupeResultRow &row = dst[pos];
                  row.imgIndex = (UINT)idu;
                  row.groupRoot = r;
                  row.grpTag = (grpHam[r]!=NONE) ? grpHam[r] : 0;
                  row.hamDist = imgHam[idu];
                  row.mse = (imgMSE[idu]!=NONE) ? imgMSE[idu] : QPV_MSD_NONE;
              }
           }
        }
    }
    catch (...)
    {
        dupesFilterRows.clear();
        dupesRestoreSavedPairs();
        return 0;
    }

    if (dupesFilterRows.size() >= 2)
       dupesDropSavedPairs();
    else if (dupesHasSavedPairs)
    {
       dupesRestoreSavedPairs();
       dupesFilterRows.clear();
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

// Whether the sweep computed MSD scores, which decides if the MSD bounds apply and if the panel
// offers its MSD fields. A pair missing a fingerprint keeps QPV_MSD_NONE and fails the bounds.
DLL_API int DLL_CALLCONV dupesHaveMSD() {
    return dupesPairsMSD;
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
static std::mutex    dupesDBMutex;        // guards dupesDB lifetime against cross-thread dupesEngineCancel()
static sqlite3_stmt *dupesStmt = NULL;
static sqlite3_stmt *dupesPixStmt = NULL;
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
    int  deferredPix = 0;
    int  pixStride = 0;
    int  grayCompressor = 1;
};
static DupesQueryCfg dupesQCfg;

// scan cursor: where the current run of equal-key rows began in the output arrays
static size_t dupesRunStart = 0;
static bool   dupesRunOpen = false;
static std::vector<unsigned char> dupesKeyCur, dupesKeyPrev;

// db is the connection the failed call ran on: the engine's own, or AHK's for the hash and
// pixel-collection statements. Its message is added only when its last call really failed;
// "not an error" and the row/done notices say nothing about the failure.
static void dupesSetError(const wchar_t *what, sqlite3 *db) {
    try
    {
        dupesEngineError = (what!=NULL) ? what : L"";
        if (db==NULL || SQ.errmsg16==NULL)
           return;

        const int code = (SQ.errcode!=NULL) ? (SQ.errcode(db) & 0xFF) : SQLITE_ERROR;
        if (code==SQLITE_OK || code==SQLITE_ROW || code==SQLITE_DONE)
           return;

        const wchar_t *m = (const wchar_t*)SQ.errmsg16(db);
        if (m!=NULL && m[0]!=0)
        {
           dupesEngineError += L": ";
           dupesEngineError += m;
        }
    }
    catch (...)
    {
        dupesEngineError.clear();
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
    dupesEngineError.clear();
    if (!SQ.ok || dbPath==NULL || dbPath[0]==0)
       return 0;

    if (dupesStmt!=NULL) { SQ.finalize(dupesStmt); dupesStmt = NULL; }
    if (dupesPixStmt!=NULL) { SQ.finalize(dupesPixStmt); dupesPixStmt = NULL; }
    {
       std::lock_guard<std::mutex> lk(dupesDBMutex);
       if (dupesDB!=NULL)
       {
          if (SQ.progress_handler!=NULL)
             SQ.progress_handler(dupesDB, 0, NULL, NULL);

          SQ.close_v2(dupesDB);
          dupesDB = NULL;
       }
    }

    const int need = WideCharToMultiByte(CP_UTF8, 0, dbPath, -1, NULL, 0, NULL, NULL);
    if (need <= 0)
       return 0;

    std::vector<char> utf8;
    try
    {
       utf8.resize((size_t)need);
    }
    catch (...)
    {
       dupesSetError(L"not enough memory to open the database", NULL);
       return 0;
    }
    WideCharToMultiByte(CP_UTF8, 0, dbPath, -1, utf8.data(), need, NULL, NULL);

    // FULLMUTEX because dupesEngineCancel() reaches this handle from the interface
    // thread; sqlite3_interrupt() is documented as safe either way, but a serialized
    // connection removes the question. A single-threaded build of sqlite3.dll ignores it.
    sqlite3 *newDB = NULL;
    const int rc = SQ.open_v2(utf8.data(), &newDB, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, NULL);
    if (rc!=SQLITE_OK || newDB==NULL)
    {
       dupesSetError(L"could not open the database read-only", newDB);
       if (newDB!=NULL) SQ.close_v2(newDB);
       return 0;
    }

    dupesCancelFlag.store(0, std::memory_order_relaxed);
    if (SQ.progress_handler!=NULL)
       SQ.progress_handler(newDB, 4096, dupesProgressCB, NULL);

    // The database is opened by AHK with no pragmas at all. These two only affect this
    // connection and only make the scan cheaper: the ORDER BY sorts in RAM, and 64 MB of
    // page cache spares a re-read of the table on a second scan.
    if (SQ.exec!=NULL)
       SQ.exec(newDB, "PRAGMA temp_store=MEMORY; PRAGMA cache_size=-65536;", NULL, NULL, NULL);

    {
       std::lock_guard<std::mutex> lk(dupesDBMutex);
       dupesDB = newDB;
    }

    return 1;
}

DLL_API int DLL_CALLCONV dupesEngineRelease() {
    if (SQ.ok)
    {
       if (dupesStmt!=NULL) { SQ.finalize(dupesStmt); dupesStmt = NULL; }
       if (dupesPixStmt!=NULL) { SQ.finalize(dupesPixStmt); dupesPixStmt = NULL; }
       std::lock_guard<std::mutex> lk(dupesDBMutex);
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
    std::lock_guard<std::mutex> lk(dupesDBMutex);
    if (dupesDB!=NULL && SQ.ok && SQ.interrupt!=NULL)
       SQ.interrupt(dupesDB);

    return 1;
}

DLL_API int DLL_CALLCONV dupesEngineReady() {
    bindSQLiteOnce();
    std::lock_guard<std::mutex> lk(dupesDBMutex);
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
           if (d >= -9223372036854775808.0 && d < 9223372036854775808.0 && (sqlite3_int64)d == v)
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
           const unsigned char *s = SQ.column_text(st, col);
           int n = (s!=NULL) ? SQ.column_bytes(st, col) : 0;
           if (n < 0) n = 0;
           const size_t pos = out.size();
           out.resize(pos + 1 + sizeof(n) + (size_t)n);
           unsigned char *dst = out.data() + pos;
           dst[0] = 3;
           memcpy(dst + 1, &n, sizeof(n));
           if (n > 0)
           {
              unsigned char *tdst = dst + 1 + sizeof(n);
              const bool fold = (k < 32) && (((nocaseMask >> k) & 1u)!=0);
              if (!fold)
                 memcpy(tdst, s, (size_t)n);
              else
              {
                 for ( int i = 0 ; i < n ; i++)
                 {
                     unsigned char c = s[i];
                     if (c >= 'A' && c <= 'Z')
                        c = (unsigned char)(c + 32);
                     tdst[i] = c;
                 }
              }
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
static bool parseHexHash(const unsigned char *s, int n, UINT64 &out) {
    out = 0;
    if (s==NULL || n < 1 || n > 16)
       return false;

    for ( int i = 0 ; i < n ; i++)
    {
        const unsigned char c = s[i];
        int v;
        if (c >= '0' && c <= '9')       v = c - '0';
        else if (c >= 'a' && c <= 'f')  v = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F')  v = c - 'A' + 10;
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
    dupesMIH.release();
    dupesCandRows.clear();
    dupesPathBuf.clear();
    dupesScanHashes.clear();
    dupesScanFlipped.clear();
    dupesScanIDs.clear();
    dupesScanGroupStart.clear();
    dupesScanRowEnd.clear();
    dupesPixData.clear();
    dupesPixOK.clear();
    dupesSweepActive = false;
    dupesRestoreSavedPairs();
    dupesKeyCur.clear();
    dupesKeyPrev.clear();
    dupesPairsRead = 0;
    dupesCandGroups = 0;
    dupesRunStart = 0;
    dupesRunOpen = false;
    dupesScanRows = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 0;
    dupesScanMihBlock = 0;
    dupesScanMaskApplied = ~0ULL;
    dupesQCfg.deferredPix = 0;
    memset((void*)&dupesScanState, 0, sizeof(dupesScanState));
}

static const unsigned char* dupesGetPixScaleLUT(const int scale) {
    static int lutScale = 0;
    static unsigned char lut[256];
    if (scale > 1 && lutScale != scale)
    {
       for ( int v = 0 ; v < 256 ; v++)
           lut[v] = (unsigned char)floor((double)v / scale + 0.5);
       lutScale = scale;
    }
    return lut;
}

static inline void decodeFingerprintBytes(const unsigned char *blob, const UINT firstIndex, const UINT count) {
    if (blob==NULL || count==0 || dupesPixStride==0)
       return;

    const UINT stride = dupesPixStride;
    if ((size_t)firstIndex > dupesPixOK.size() || (size_t)count > dupesPixOK.size() - (size_t)firstIndex)
       return;

    const size_t endIndex = (size_t)firstIndex + (size_t)count;
    if (endIndex > dupesPixData.size() / (size_t)stride)
       return;

    const int scale = dupesPixScale;
    const unsigned char *lut = (scale > 1) ? dupesGetPixScaleLUT(scale) : NULL;
    for ( UINT rec = 0 ; rec < count ; rec++)
    {
        const unsigned char *src = blob + (size_t)rec * stride;
        const size_t slot = (size_t)firstIndex + (size_t)rec;
        unsigned char *dst = &dupesPixData[slot * (size_t)stride];
        if (scale > 1)
        {
           for ( UINT k = 0 ; k < stride ; k++)
               dst[k] = lut[src[k]];
        } else
           memcpy(dst, src, stride);

        dupesPixOK[slot] = 1;
    }
}

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
       if (dupesRunStart < n)
          dupesPathBuf.resize(dupesCandRows[dupesRunStart].pathOffset);

       dupesCandRows.resize(dupesRunStart);
       dupesScanHashes.resize(dupesRunStart);
       if (!dupesScanFlipped.empty())
          dupesScanFlipped.resize(dupesRunStart);

       if (dupesQCfg.hasPix==1 && dupesQCfg.deferredPix==0 && dupesPixStride > 0)
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
    if (dupesPixStmt!=NULL) { SQ.finalize(dupesPixStmt); dupesPixStmt = NULL; }

    dupesQueryReset();
    dupesCancelFlag.store(0, std::memory_order_relaxed);
    dupesQCfg.keyCount = keyCount;
    dupesQCfg.nocaseMask = nocaseMask;
    dupesQCfg.hasHash = (hasHash==1) ? 1 : 0;
    dupesQCfg.hasFlip = (hasFlip==1) ? 1 : 0;
    dupesQCfg.hasPix  = (hasPix==1 && pixStride > 0) ? 1 : 0;
    dupesQCfg.deferredPix = 0;
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
       dupesSetError(L"could not prepare the duplicates query", dupesDB);
       dupesStmt = NULL;
       dupesScanState.lastError = 3;
       dupesScanState.phase = -1;
       return 0;
    }

    // Accepts both deferred mode (no p.big column; point-fetched in dupesScanBuildFromQuery)
    // and inline mode (p.big column present in SELECT).
    const int baseNoPix = 4 + dupesQCfg.hasHash + dupesQCfg.hasFlip + keyCount;
    const int colCount = (SQ.column_count!=NULL) ? SQ.column_count(dupesStmt) : (baseNoPix + dupesQCfg.hasPix);
    if (dupesQCfg.hasPix==1 && colCount==baseNoPix)
    {
       const int prc = SQ.prepare16_v2(dupesDB, L"SELECT big FROM imagesPixels WHERE imgidu=?1;", -1, &dupesPixStmt, NULL);
       if (prc!=SQLITE_OK || dupesPixStmt==NULL)
       {
          dupesSetError(L"could not prepare the pixel-fingerprint lookup query", dupesDB);
          SQ.finalize(dupesStmt);
          dupesStmt = NULL;
          dupesPixStmt = NULL;
          dupesScanState.lastError = 3;
          dupesScanState.phase = -1;
          return 0;
       }
       dupesQCfg.deferredPix = 1;
    }
    else if (colCount != baseNoPix + dupesQCfg.hasPix)
    {
       dupesSetError(L"the duplicates query does not have the expected column layout", dupesDB);
       SQ.finalize(dupesStmt);
       dupesStmt = NULL;
       dupesScanState.lastError = 4;
       dupesScanState.phase = -1;
       return 0;
    }

    dupesScanState.phase = 2;
    return 1;
}

DLL_API int DLL_CALLCONV dupesQueryStep(int msBudget) {
    if (!SQ.ok || dupesStmt==NULL)
       return -1;

    if (msBudget < 1)
       msBudget = 1;

    const int inlinePix = (dupesQCfg.hasPix==1 && dupesQCfg.deferredPix==0) ? 1 : 0;
    const int base = 4 + dupesQCfg.hasHash + dupesQCfg.hasFlip + inlinePix;
    const int colHash = dupesQCfg.hasHash ? 4 : -1;
    const int colFlip = dupesQCfg.hasFlip ? (4 + dupesQCfg.hasHash) : -1;
    const int colPix  = inlinePix ? (4 + dupesQCfg.hasHash + dupesQCfg.hasFlip) : -1;
    const UINT stride = (UINT)dupesQCfg.pixStride;
    const std::chrono::steady_clock::time_point tStart = std::chrono::steady_clock::now();
    int sinceClock = 0;

    for (;;)
    {
        const int rc = SQ.step(dupesStmt);
        if (rc==SQLITE_ROW)
        {
           dupesScanState.scanned++;
           bool appending = false;
           size_t nPath = 0, nRows = 0, nHash = 0, nFlip = 0, nPixData = 0, nPixOK = 0;
           try
           {
              if (!buildRowKey(dupesStmt, base, dupesQCfg.keyCount, dupesQCfg.nocaseMask, dupesKeyCur))
              {
                 dupesCloseRun();
                 dupesKeyPrev.clear();
              }
              else
              {
                 UINT64 hash = 0, flip = 0;
                 bool usable = true;
                 if (colHash >= 0)
                 {
                    const unsigned char *h = SQ.column_text(dupesStmt, colHash);
                    usable = parseHexHash(h, (h!=NULL) ? SQ.column_bytes(dupesStmt, colHash) : 0, hash);
                    flip = hash;
                    if (usable && colFlip >= 0)
                    {
                       const unsigned char *f = SQ.column_text(dupesStmt, colFlip);
                       if (!parseHexHash(f, (f!=NULL) ? SQ.column_bytes(dupesStmt, colFlip) : 0, flip))
                          flip = hash;
                    }
                 }

                 if (usable)
                 {
                    if (!dupesRunOpen || dupesKeyPrev!=dupesKeyCur)
                    {
                       dupesCloseRun();
                       dupesKeyPrev.swap(dupesKeyCur);
                       dupesRunStart = dupesCandRows.size();
                       dupesRunOpen = true;
                    }

                    DupeCandRow row;
                    row.imgidu = (INT64)SQ.column_int64(dupesStmt, 0);
                    row.megapix = SQ.column_double(dupesStmt, 2);
                    row.fsize = (INT64)SQ.column_int64(dupesStmt, 3);
                    row.groupID = 0;
                    row.pathOffset = (UINT)dupesPathBuf.size();

                    const wchar_t *p = (const wchar_t*)SQ.column_text16(dupesStmt, 1);
                    const int plen = (p!=NULL) ? SQ.column_bytes16(dupesStmt, 1) / (int)sizeof(wchar_t) : 0;
                    nPath = dupesPathBuf.size(); nRows = dupesCandRows.size(); nHash = dupesScanHashes.size();
                    nFlip = dupesScanFlipped.size(); nPixData = dupesPixData.size(); nPixOK = dupesPixOK.size();
                    appending = true;

                    if (plen > 0)
                       dupesPathBuf.append(p, (size_t)plen);

                    dupesPathBuf.push_back(L'\0');
                    dupesCandRows.push_back(row);
                    dupesScanHashes.push_back(hash);
                    if (colFlip >= 0)
                       dupesScanFlipped.push_back(flip);

                    if (colPix >= 0)
                    {
                       const unsigned char *px = (const unsigned char*)SQ.column_blob(dupesStmt, colPix);
                       const int pxlen = (px!=NULL) ? SQ.column_bytes(dupesStmt, colPix) : 0;
                       if (px!=NULL && pxlen==(int)stride)
                       {
                          if (dupesPixScale > 1)
                          {
                             const unsigned char *lut = dupesGetPixScaleLUT(dupesPixScale);
                             if (stride <= 1024)
                             {
                                unsigned char tmp[1024];
                                for ( UINT k = 0 ; k < stride ; k++)
                                    tmp[k] = lut[px[k]];
                                dupesPixData.insert(dupesPixData.end(), tmp, tmp + stride);
                             }
                             else
                             {
                                const size_t slot = dupesCandRows.size() - 1;
                                dupesPixData.resize((slot + 1) * stride);
                                unsigned char *dst = &dupesPixData[slot * stride];
                                for ( UINT k = 0 ; k < stride ; k++)
                                    dst[k] = lut[px[k]];
                             }
                          }
                          else
                             dupesPixData.insert(dupesPixData.end(), px, px + stride);

                          dupesPixOK.push_back(1);
                       }
                       else
                       {
                          dupesPixData.insert(dupesPixData.end(), stride, 0);
                          dupesPixOK.push_back(0);
                       }
                    }
                 }
              }
           }
           catch (...)
           {
              if (appending)
              {
                 dupesPathBuf.resize(nPath);
                 dupesCandRows.resize(nRows);
                 dupesScanHashes.resize(nHash);
                 dupesScanFlipped.resize(nFlip);
                 dupesPixData.resize(nPixData);
                 dupesPixOK.resize(nPixOK);
                 if (dupesRunOpen && dupesRunStart==nRows)
                    dupesRunOpen = false;
              }
              SQ.finalize(dupesStmt);
              dupesStmt = NULL;
              dupesScanState.lastError = 1;
              dupesScanState.phase = -1;
              dupesSetError(L"the duplicates query ran out of memory", NULL);
              return -1;
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
        dupesSetError((rc==SQLITE_INTERRUPT) ? L"the duplicates query was cancelled" : L"the duplicates query failed", dupesDB);
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

    const bool deferredPix = (dupesQCfg.hasPix==1 && dupesQCfg.deferredPix==1 && dupesPixStride > 0);
    const bool wantPix = (!deferredPix && dupesScanWantMSD==1 && dupesPixStride > 0 && dupesPixData.size() >= (size_t)total * dupesPixStride);
    const bool wantFlip = (dupesScanFlipped.size() >= total);
    UINT kept = 0;
    UINT prevGroup = 0;
    INT64 comparisons = 0;
    dupesScanGroupStart.clear();
    dupesScanIDs.clear();

    try
    {
        dupesScanIDs.reserve(total);
        if (dupesCandGroups < 0xFFFFFFFFu)
           dupesScanGroupStart.reserve((size_t)dupesCandGroups + 1);

        std::vector<INT64> keptImgIds;
        if (deferredPix)
           keptImgIds.reserve(total);

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

            dupesScanHashes[kept] = dupesScanHashes[i];
            if (wantFlip)
               dupesScanFlipped[kept] = dupesScanFlipped[i];

            if (wantPix)
            {
               if (kept!=i)
                  memmove(&dupesPixData[(size_t)kept * dupesPixStride], &dupesPixData[(size_t)i * dupesPixStride], dupesPixStride);

               dupesPixOK[kept] = dupesPixOK[i];
            }
            else if (deferredPix)
               keptImgIds.push_back(dupesCandRows[i].imgidu);

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

        if (kept >= 2 && !dupesScanGroupStart.empty())
           dupesScanGroupStart.push_back(kept);

        for ( size_t g = 0 ; g + 1 < dupesScanGroupStart.size() ; g++)
        {
            const INT64 m = (INT64)(dupesScanGroupStart[g + 1] - dupesScanGroupStart[g]);
            comparisons += m * (m - 1) / 2;
        }

        if (kept >= 2 && dupesScanGroupStart.size() >= 2 && comparisons >= 1 && deferredPix)
        {
           const UINT stride = dupesPixStride;
           if ((size_t)kept > ((size_t)-1) / (size_t)stride)
              throw std::bad_alloc();

           dupesPixData.assign((size_t)kept * (size_t)stride, 0);
           dupesPixOK.assign(kept, 0);

           if (dupesPixStmt!=NULL && SQ.ok)
           {
              struct PixFetchReq { INT64 imgidu; UINT slot; };
              std::vector<PixFetchReq> reqs;
              reqs.reserve(kept);
              for ( size_t g = 0 ; g + 1 < dupesScanGroupStart.size() ; g++)
              {
                  const UINT a = dupesScanGroupStart[g], b = dupesScanGroupStart[g + 1];
                  if (b - a < 2)
                     continue;
                  for ( UINT s = a ; s < b ; s++)
                      reqs.push_back({ keptImgIds[s], s });
              }

              // Primary-key order turns random lookups into a sequential B-tree scan.
              std::sort(reqs.begin(), reqs.end(), [](const PixFetchReq &x, const PixFetchReq &y) {
                  return x.imgidu < y.imgidu;
              });

              const int scale = dupesPixScale;
              const unsigned char *lut = (scale > 1) ? dupesGetPixScaleLUT(scale) : NULL;
              for ( size_t r = 0 ; r < reqs.size() ; r++)
              {
                  if ((r & 255u)==0 && dupesCancelFlag.load(std::memory_order_relaxed)!=0)
                  {
                     SQ.reset(dupesPixStmt);
                     dupesScanGroupStart.clear();
                     dupesScanIDs.clear();
                     dupesScanRowEnd.clear();
                     dupesPixData.clear();
                     dupesPixOK.clear();
                     dupesScanRows = 0;
                     dupesScanState.rows = 0;
                     dupesScanState.groups = 0;
                     dupesScanState.total = 0;
                     dupesScanState.lastError = 0;
                     dupesScanState.phase = -1;
                     dupesSetError(L"the duplicates query was cancelled", dupesDB);
                     return 0;
                  }

                  SQ.reset(dupesPixStmt);
                  SQ.bind_int64(dupesPixStmt, 1, (sqlite3_int64)reqs[r].imgidu);
                  const int prc = SQ.step(dupesPixStmt);
                  if (prc==SQLITE_ROW)
                  {
                     const unsigned char *px = (const unsigned char*)SQ.column_blob(dupesPixStmt, 0);
                     const int pxlen = (px!=NULL) ? SQ.column_bytes(dupesPixStmt, 0) : 0;
                     if (px!=NULL && pxlen==(int)stride)
                     {
                        unsigned char *dst = &dupesPixData[(size_t)reqs[r].slot * (size_t)stride];
                        if (scale > 1)
                        {
                           for ( UINT k = 0 ; k < stride ; k++)
                               dst[k] = lut[px[k]];
                        }
                        else
                           memcpy(dst, px, stride);

                        dupesPixOK[reqs[r].slot] = 1;
                     }
                  }
                  else if (prc!=SQLITE_DONE)
                  {
                     SQ.reset(dupesPixStmt);
                     dupesScanGroupStart.clear();
                     dupesScanIDs.clear();
                     dupesScanRowEnd.clear();
                     dupesPixData.clear();
                     dupesPixOK.clear();
                     dupesScanRows = 0;
                     dupesScanState.rows = 0;
                     dupesScanState.groups = 0;
                     dupesScanState.total = 0;
                     dupesScanState.lastError = (prc==SQLITE_INTERRUPT) ? 0 : 5;
                     dupesScanState.phase = -1;
                     dupesSetError((prc==SQLITE_INTERRUPT) ? L"the duplicates query was cancelled" : L"could not read pixel fingerprints", dupesDB);
                     return 0;
                  }
              }
              SQ.reset(dupesPixStmt);
           }
        }
    }
    catch (...)
    {
        if (dupesPixStmt!=NULL && SQ.ok)
           SQ.reset(dupesPixStmt);
        dupesScanGroupStart.clear();
        dupesScanIDs.clear();
        dupesScanRowEnd.clear();
        dupesPixData.clear();
        dupesPixOK.clear();
        dupesScanRows = 0;
        dupesScanState.rows = 0;
        dupesScanState.groups = 0;
        dupesScanState.total = 0;
        dupesScanState.lastError = 1;
        dupesScanState.phase = -1;
        dupesSetError(L"not enough memory to prepare the duplicates sweep", NULL);
        return 0;
    }

    if (kept < 2 || dupesScanGroupStart.size() < 2 || comparisons < 1)
    {
       dupesScanGroupStart.clear();
       dupesScanRowEnd.clear();
       dupesScanRows = 0;
       dupesScanState.rows = 0;
       dupesScanState.groups = 0;
       dupesScanState.total = 0;
       dupesScanState.phase = 5;
       return 0;
    }

    dupesScanRows = kept;
    dupesScanState.rows = (LONG)kept;
    if (!dupesScanBuildRowEnd())
    {
       dupesScanGroupStart.clear();
       dupesScanRows = 0;
       dupesScanState.rows = 0;
       dupesScanState.groups = 0;
       dupesScanState.total = 0;
       dupesScanState.lastError = 1;
       dupesScanState.phase = -1;
       return 0;
    }

    dupesMIH.release();
    if (!dupesHasSavedPairs && !dupesPairsList.empty())
    {
       dupesSavedPairs.swap(dupesPairsList);
       dupesSavedMSD = dupesPairsMSD;
       dupesSavedMaxId = dupesPairsMaxId;
       dupesSavedMaxIdCount = dupesPairsMaxIdCount;
       dupesHasSavedPairs = true;
    }
    dupesPairsList.clear();
    dupesPairsMSD = 0;
    dupesPairsMaxId = 0;
    dupesPairsMaxIdCount = 0;
    dupesPairsRead = 0;
    dupesSweepActive = true;
    dupesScanState.groups = (LONG)(dupesScanGroupStart.size() - 1);
    dupesScanState.total = comparisons;
    dupesScanState.done = 0;
    dupesScanState.pairs = 0;
    dupesScanOuter = 0;
    dupesScanBlock = 1 << 16;
    dupesScanMihBlock = 0;
    dupesScanMaskApplied = ~0ULL;
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
static INT64 dupesHashWritten = 0, dupesHashFailed = 0;
// images whose stored fingerprint is not the length this hash needs. They are not write
// failures - the write succeeds, it just has nothing to write - so they are counted apart
// from dupesHashFailed, which AHK reports as "failed to commit to database".
static INT64 dupesHashSkipped = 0;

// The keyset cursor: the highest imgidu this run has read, bound as ?2 of the SELECT.
// See the contract above dupesHashBegin() for what it is for and what happens without it.
static INT64 dupesHashCursor = 0;
// Consecutive batches that moved nothing at all; the backstop in dupesHashStillMoving().
static int   dupesHashStall = 0;
#define QPV_HASH_STALL_BATCHES 3

static int           dupesHashLUT[256];
static unsigned char dupesHashByteLUT[256];
static std::vector<int>           dupesHashPixBuf;
static std::vector<unsigned char> dupesHashByteBuf;

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

static int dupesHexHashLen(UINT64 v, wchar_t *out, int cap) {
    if (out==NULL || cap < 1)
       return 0;

    if (cap == 1)
    {
       out[0] = 0;
       return 0;
    }

    static const wchar_t kHex[16] = {
        L'0', L'1', L'2', L'3', L'4', L'5', L'6', L'7',
        L'8', L'9', L'a', L'b', L'c', L'd', L'e', L'f'
    };
    wchar_t rev[16];
    int r = 0;
    do {
        rev[r++] = kHex[v & 0xFu];
        v >>= 4;
    } while (v != 0);

    int n = 0;
    while (r > 0 && n < cap - 1)
        out[n++] = rev[--r];
    out[n] = 0;
    return n;
}

static inline void dupesHexHash(UINT64 v, wchar_t *out, int cap) {
    (void)dupesHexHashLen(v, out, cap);
}

DLL_API int DLL_CALLCONV dupesHashBegin(void *ahkDb, const wchar_t *selectSQL, const wchar_t *updateSQL, int hashKind, int pixCount, int grayCompressor, int pHashMode) {
    bindSQLiteOnce();
    dupesEngineError.clear();
    if (!SQ.ok || ahkDb==NULL || selectSQL==NULL || updateSQL==NULL)
       return 0;

    if (hashKind!=2 && hashKind!=3 && hashKind!=4)
       return 0;

    if (pixCount!=((hashKind==3) ? 1024 : 72))
       return 0;

    if (dupesHashSel!=NULL) { SQ.finalize(dupesHashSel); dupesHashSel = NULL; }
    if (dupesHashUpd!=NULL) { SQ.finalize(dupesHashUpd); dupesHashUpd = NULL; }

    dupesHashDB = (sqlite3*)ahkDb;
    dupesHashKind = hashKind;
    dupesHashPix = pixCount;
    dupesHashGray = (grayCompressor > 1) ? grayCompressor : 1;
    dupesHashMode = pHashMode;
    dupesHashWritten = dupesHashFailed = dupesHashSkipped = 0;
    dupesHashCursor = 0;
    dupesHashStall = 0;
    for ( int v = 0 ; v < 256 ; v++)
    {
        dupesHashLUT[v] = dupesDiscretize(v, dupesHashGray);
        dupesHashByteLUT[v] = (unsigned char)(dupesHashLUT[v] & 0xFF);
    }

    if (SQ.prepare16_v2(dupesHashDB, selectSQL, -1, &dupesHashSel, NULL)!=SQLITE_OK || dupesHashSel==NULL)
    {
       dupesSetError(L"could not prepare the hash-generation query", dupesHashDB);
       dupesHashSel = NULL;
       return 0;
    }

    if (SQ.prepare16_v2(dupesHashDB, updateSQL, -1, &dupesHashUpd, NULL)!=SQLITE_OK || dupesHashUpd==NULL)
    {
       dupesSetError(L"could not prepare the hash-generation update", dupesHashDB);
       SQ.finalize(dupesHashSel);
       dupesHashSel = NULL;
       dupesHashUpd = NULL;
       return 0;
    }

    return 1;
}

static int dupesHashStillMoving(INT64 cursorWas, INT64 wroteWas, INT64 skippedWas) {
    if (dupesHashCursor > cursorWas || dupesHashWritten > wroteWas || dupesHashSkipped > skippedWas)
    {
       dupesHashStall = 0;
       return 1;
    }

    if (++dupesHashStall < QPV_HASH_STALL_BATCHES)
       return 1;

    dupesSetError(L"the hash generation stopped making progress - the database is refusing every write", dupesHashDB);
    return -1;
}

DLL_API int DLL_CALLCONV dupesHashStep(int batch) {
    if (!SQ.ok || dupesHashSel==NULL || dupesHashUpd==NULL)
       return -1;

    if (batch < 1)
       batch = 256;

    if (dupesHashPix < 1 || (size_t)batch > ((size_t)-1) / (size_t)dupesHashPix)
    {
       dupesSetError(L"the hash generation ran out of memory", NULL);
       return -1;
    }

    const INT64 cursorWas = dupesHashCursor, wroteWas = dupesHashWritten, skippedWas = dupesHashSkipped;
    try
    {
        std::vector<INT64> ids;
        std::vector<INT64> badIds;    // written back after the SELECT is reset, never during
        ids.reserve((size_t)batch);
        const bool isPHash = (dupesHashKind==3);
        int *pix = NULL;
        unsigned char *bytePix = NULL;
        if (isPHash)
        {
           dupesHashByteBuf.resize((size_t)batch * (size_t)dupesHashPix);
           bytePix = dupesHashByteBuf.data();
        }
        else
        {
           dupesHashPixBuf.resize((size_t)batch * (size_t)dupesHashPix);
           pix = dupesHashPixBuf.data();
        }
        bool sawRow = false;

        SQ.reset(dupesHashSel);
        if (SQ.bind_int64!=NULL)
        {
           SQ.bind_int64(dupesHashSel, 1, batch);
           SQ.bind_int64(dupesHashSel, 2, dupesHashCursor);
        }

        for (;;)
        {
            const int rc = SQ.step(dupesHashSel);
            if (rc==SQLITE_ROW)
            {
               const unsigned char *s = (const unsigned char*)SQ.column_blob(dupesHashSel, 1);
               const int n = (s!=NULL) ? SQ.column_bytes(dupesHashSel, 1) : 0;
               const INT64 id = (INT64)SQ.column_int64(dupesHashSel, 0);
               sawRow = true;
               if (id > dupesHashCursor)
                  dupesHashCursor = id;

               if (n!=dupesHashPix)
               {
                  badIds.push_back(id);
                  continue;
               }

               if (isPHash)
               {
                  unsigned char *d = bytePix + ids.size() * (size_t)dupesHashPix;
                  for ( int i = 0 ; i < n ; i++)
                      d[i] = dupesHashByteLUT[s[i]];
               }
               else
               {
                  int *d = pix + ids.size() * (size_t)dupesHashPix;
                  for ( int i = 0 ; i < n ; i++)
                      d[i] = dupesHashLUT[s[i]];
               }

               ids.push_back(id);
               if ((int)ids.size() >= batch)
                  break;

               continue;
            }

            if (rc==SQLITE_DONE)
               break;

            dupesHashCursor = cursorWas;
            dupesSetError((rc==SQLITE_INTERRUPT) ? L"the hash generation was cancelled" : L"the hash-generation query failed", dupesHashDB);
            SQ.reset(dupesHashSel);
            return -1;
        }

        SQ.reset(dupesHashSel);

        if (!badIds.empty() && SQ.bind_text16!=NULL && SQ.bind_int64!=NULL)
        {
           for ( size_t i = 0 ; i < badIds.size() ; i++)
           {
               SQ.reset(dupesHashUpd);
               SQ.bind_text16(dupesHashUpd, 1, L"", 0, QPV_SQLITE_STATIC);
               SQ.bind_int64(dupesHashUpd, 2, badIds[i]);
               const int urc = SQ.step(dupesHashUpd);
               if (urc==SQLITE_DONE)
                  dupesHashSkipped++;
               else if (urc==SQLITE_INTERRUPT)
               {
                  SQ.reset(dupesHashUpd);
                  dupesSetError(L"the hash generation was cancelled", dupesHashDB);
                  return -1;
               }
               else
                  dupesHashFailed++;
           }

           SQ.reset(dupesHashUpd);
        }

        if (ids.empty())
           return sawRow ? dupesHashStillMoving(cursorWas, wroteWas, skippedWas) : 0;

        const int count = (int)ids.size();
        std::vector<UINT64> out((size_t)count, 0);
        const int kind = dupesHashKind, stride = dupesHashPix, mode = dupesHashMode;
        UINT64 *outData = out.data();

        if (isPHash)
        {
           dupesParallelFor(count, [bytePix, outData, stride, mode](int i) {
               outData[i] = (UINT64)calcPHashAlgo(bytePix + (size_t)i * stride, 32, mode);
           }, count >= 64);
        }
        else
        {
           const int *pixData = pix;
           for ( int i = 0 ; i < count ; i++)
           {
               const int *p = pixData + (size_t)i * stride;
               outData[i] = (kind==2) ? dupesDHash(p) : dupesLHash(p);
           }
        }

        wchar_t hex[32];
        for ( int i = 0 ; i < count ; i++)
        {
            const int hlen = dupesHexHashLen(out[i], hex, 32);
            SQ.reset(dupesHashUpd);
            if (SQ.bind_text16!=NULL)
               SQ.bind_text16(dupesHashUpd, 1, hex, hlen * (int)sizeof(wchar_t), QPV_SQLITE_STATIC);

            if (SQ.bind_int64!=NULL)
               SQ.bind_int64(dupesHashUpd, 2, ids[i]);

            const int rc = SQ.step(dupesHashUpd);
            if (rc==SQLITE_DONE)
               dupesHashWritten++;
            else if (rc==SQLITE_INTERRUPT)
            {
               SQ.reset(dupesHashUpd);
               dupesSetError(L"the hash generation was cancelled", dupesHashDB);
               return -1;
            }
            else
               dupesHashFailed++;
        }

        SQ.reset(dupesHashUpd);
        return dupesHashStillMoving(cursorWas, wroteWas, skippedWas);
    }
    catch (...)
    {
        dupesHashCursor = cursorWas;
        if (dupesHashSel!=NULL) SQ.reset(dupesHashSel);
        if (dupesHashUpd!=NULL) SQ.reset(dupesHashUpd);
        dupesSetError(L"the hash generation ran out of memory", NULL);
        return -1;
    }
}

DLL_API INT64 DLL_CALLCONV dupesHashWrittenCount() { return dupesHashWritten; }
DLL_API INT64 DLL_CALLCONV dupesHashFailedCount()  { return dupesHashFailed; }
DLL_API INT64 DLL_CALLCONV dupesHashSkippedCount() { return dupesHashSkipped; }

DLL_API int DLL_CALLCONV dupesHashHasKeyset() { return 1; }

DLL_API int DLL_CALLCONV dupesHashEnd() {
    if (SQ.ok)
    {
       if (dupesHashSel!=NULL) { SQ.finalize(dupesHashSel); dupesHashSel = NULL; }
       if (dupesHashUpd!=NULL) { SQ.finalize(dupesHashUpd); dupesHashUpd = NULL; }
    }

    dupesHashDB = NULL;
    std::vector<int>().swap(dupesHashPixBuf);
    std::vector<unsigned char>().swap(dupesHashByteBuf);
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
    const int n = (int)givenArray.size();
    if (modus==1) // median
    {
        std::nth_element(givenArray.begin(), givenArray.begin() + (n / 2), givenArray.end());
        if (n % 2 == 0)
        {
            const double lo = *std::max_element(givenArray.begin(), givenArray.begin() + (n / 2));
            return (lo + givenArray[n / 2]) / 2.0;
        }

        return givenArray[n / 2];
    }
    else
    {
        double thisSum = 0.0;
        for (int i = 1; i < n; i++)
            thisSum += givenArray[i];

        return thisSum / (n - 1);
    }
}

// Pre-scaled 8x16 even/odd symmetric 32-point DCT-II table (1 KB, L1-resident).
struct alignas(16) DupesDCT8x16 {
    double even[16][4]; // u = 0, 2, 4, 6
    double odd[16][4];  // u = 1, 3, 5, 7
};

static const DupesDCT8x16& dupesDCT8x16() {
    static const DupesDCT8x16 table = []() {
        DupesDCT8x16 t = {};
        for (int j = 0; j < 16; j++)
        {
            const double angle = M_PI * (j + 0.5) / 32.0;
            for (int k = 0; k < 4; k++)
            {
                const int ue = k * 2;
                const int uo = k * 2 + 1;
                const double scaleE = (ue == 0) ? (div2sz * div2sq) : div2sz;
                t.even[j][k] = scaleE * cos(ue * angle);
                t.odd[j][k]  = div2sz * cos(uo * angle);
            }
        }
        return t;
    }();
    return table;
}

DLL_API int DLL_CALLCONV calculateDCTcoeffs(int size) {
    if (size < 1 || size > 32)
       return 0;

    int thisIndex = 0;
    for (int i = 0; i < size; i++)
    {
        for (int j = 0; j < size; j++)
        {
            thisIndex++;
            DCTcoeffs[thisIndex] = cos(i * M_PI * (j + 0.5) / size);
        }
    }

    if (size == 32)
       (void)dupesDCT8x16();

    return 1;
}

DLL_API INT64 DLL_CALLCONV calcPHashAlgo(unsigned char *givenArray, UINT size, int compareMethod) {
    if (givenArray == NULL || size != 32)
       return 0;

    const DupesDCT8x16 &T = dupesDCT8x16();
    alignas(16) double rows[32][8];

    // Pass 1: 32 rows x 8 horizontal frequencies (even/odd symmetry + SSE2)
    for (int y = 0; y < 32; y++)
    {
        const unsigned char *src = givenArray + y * 32;
        __m128d e02 = _mm_setzero_pd();
        __m128d e46 = _mm_setzero_pd();
        __m128d o13 = _mm_setzero_pd();
        __m128d o57 = _mm_setzero_pd();
        for (int j = 0; j < 16; j++)
        {
            const int a = (int)src[j];
            const int b = (int)src[31 - j];
            const __m128d ve = _mm_set1_pd((double)(a + b));
            const __m128d vo = _mm_set1_pd((double)(a - b));
            e02 = _mm_add_pd(e02, _mm_mul_pd(ve, _mm_load_pd(T.even[j] + 0)));
            e46 = _mm_add_pd(e46, _mm_mul_pd(ve, _mm_load_pd(T.even[j] + 2)));
            o13 = _mm_add_pd(o13, _mm_mul_pd(vo, _mm_load_pd(T.odd[j]  + 0)));
            o57 = _mm_add_pd(o57, _mm_mul_pd(vo, _mm_load_pd(T.odd[j]  + 2)));
        }
        double *dst = rows[y];
        _mm_store_pd(dst + 0, _mm_unpacklo_pd(e02, o13));
        _mm_store_pd(dst + 2, _mm_unpackhi_pd(e02, o13));
        _mm_store_pd(dst + 4, _mm_unpacklo_pd(e46, o57));
        _mm_store_pd(dst + 6, _mm_unpackhi_pd(e46, o57));
    }

    // Pass 2: 8 columns x 8 vertical frequencies -> top 8x8 DCT block
    std::array<double, 64> fpexels;
    for (int u = 0; u < 8; u++)
    {
        __m128d e02 = _mm_setzero_pd();
        __m128d e46 = _mm_setzero_pd();
        __m128d o13 = _mm_setzero_pd();
        __m128d o57 = _mm_setzero_pd();
        for (int j = 0; j < 16; j++)
        {
            const double a = rows[j][u];
            const double b = rows[31 - j][u];
            const __m128d ve = _mm_set1_pd(a + b);
            const __m128d vo = _mm_set1_pd(a - b);
            e02 = _mm_add_pd(e02, _mm_mul_pd(ve, _mm_load_pd(T.even[j] + 0)));
            e46 = _mm_add_pd(e46, _mm_mul_pd(ve, _mm_load_pd(T.even[j] + 2)));
            o13 = _mm_add_pd(o13, _mm_mul_pd(vo, _mm_load_pd(T.odd[j]  + 0)));
            o57 = _mm_add_pd(o57, _mm_mul_pd(vo, _mm_load_pd(T.odd[j]  + 2)));
        }
        double *dst = fpexels.data() + u * 8;
        _mm_storeu_pd(dst + 0, _mm_unpacklo_pd(e02, o13));
        _mm_storeu_pd(dst + 2, _mm_unpackhi_pd(e02, o13));
        _mm_storeu_pd(dst + 4, _mm_unpacklo_pd(e46, o57));
        _mm_storeu_pd(dst + 6, _mm_unpackhi_pd(e46, o57));
    }

    UINT64 hash = 0;
    const double compareTerm = calcArrayAvgMedian(fpexels, compareMethod);
    for (int x = 0; x < 64; x++)
    {
        if (fpexels[x] > compareTerm)
           hash |= (1ULL << x);
    }

    return (INT64)hash;
}
// qpv-dct-block-end - tests/run-tests.sh slices calcArrayAvgMedian .. calcPHashAlgo out
// of here for the hash oracle. Leave the marker in place.

#endif // QPV_DUPES_SEARCH_H
