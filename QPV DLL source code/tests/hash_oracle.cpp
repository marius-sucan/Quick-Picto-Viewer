// Oracle for the perceptual hashes: the SHIPPED dupesDHash/dupesLHash/dupesPHash and the
// fingerprint decode that feeds them, text-sliced out of qpv-main.cpp, against a
// transcription of the AHK they replaced.
//
// The stakes here are the highest in the pipeline: a hash that differs by one bit is not
// a wrong answer, it is a DIFFERENT answer, and every hash already in every user's
// database was computed the old way. A change would silently start grouping images
// differently and nobody could tell why.
//
// The reference is generateSQLimageFingerPrintHash()'s inner loop plus
// processPixArrayChars(), calcLhashAlgo() and calcDLLpHashAlgo(), transcribed:
//   processPixArrayChars: Ord(ch) - 161, then discretizeValue(v, level) = Round(v/L)*L
//   dHash:  72 values, every 9th skipped, a[i] < a[i+1], MSB first
//   lHash:  8x8 of the 9x8 block, pixel > (rowMean + colMean)/2, MSB first
//   pHash:  NumPut(v, buf, i, "UChar") then calcPHashAlgo(), ConvertBase(10,16,...)
//
// The "UChar" in calcDLLpHashAlgo() is the subtle one: discretizeValue(255, 2) is 256,
// which NumPut truncated to 0. Every stored pHash was computed with that truncation, so
// the port keeps it.
//
// written by Marius Șucan with Claude Opus 5

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <chrono>
#include <atomic>
#include <mutex>
#include <string>
#include <vector>
#include <array>
#include <algorithm>
#include <emmintrin.h>
#include <windows.h>             // tests/shim/windows.h, via -Ishim

#define DLL_API extern "C"
#define DLL_CALLCONV
#define QPV_FORCEINLINE inline __attribute__((always_inline))

__attribute__((unused)) static void fnOutputDebug(std::string) {}
static void SetWindowText(HWND, LPCWSTR) {}

#include "../sqlite-dynamic.h"
#include "header_extract.h"

// The DCT table and its two scale factors live in qpv-main.h outside the sliced region;
// copied here rather than sliced because they are three literal declarations, and the
// oracle's whole point is that everything with logic in it comes from the real source.
const double div2sz = sqrt(2.0 / 32.0);
const double div2sq = 1 / sqrt(2.0);
std::array<double, 1025> DCTcoeffs;

#include "dct_extract.cpp"       // calculateDCT + calcPHashAlgo, verbatim
#include "block_extract.cpp"
#include "query_extract.cpp"

// ---- the reference ---------------------------------------------------------------

static double ahkRound(double x) { return (x >= 0.0) ? std::floor(x + 0.5) : std::ceil(x - 0.5); }
static int refDiscretize(int v, int level) {
    return (level != 1) ? (int)(ahkRound((double)v / level) * level) : v;
}

// processPixArrayChars(Row[2])
static std::vector<int> refDecode(const std::vector<wchar_t> &rec, int level) {
    std::vector<int> out;
    out.reserve(rec.size());
    for (size_t i = 0; i < rec.size(); i++)
        out.push_back(refDiscretize((int)rec[i] - 161, level));
    return out;
}

// the dHash loop in generateSQLimageFingerPrintHash(), building a binary string
static std::string refDHashBits(const std::vector<int> &a) {
    std::string bits;
    int thisIndex = 0;
    for (int i = 1; i <= 72; i++) {
        thisIndex++;
        if (thisIndex == 9) { thisIndex = 0; continue; }
        bits += (a[i - 1] < a[i]) ? '1' : '0';
    }
    return bits;
}

// calcLhashAlgo(arrayChars)
static std::string refLHashBits(const std::vector<int> &a) {
    const int W = 9, H = 8;
    double linez[8], cols[8];
    for (int rowu = 1; rowu <= H; rowu++) {
        double s = 0;
        for (int i = 1; i <= 8; i++) s += a[(rowu - 1) * W + i - 1];
        linez[rowu - 1] = s / 8.0;
    }
    for (int colu = 1; colu <= 8; colu++) {
        double s = 0;
        for (int i = 1; i <= H; i++) s += a[(i - 1) * W + colu - 1];
        cols[colu - 1] = s / (double)H;
    }
    std::string bits;
    for (int rowu = 1; rowu <= H; rowu++)
        for (int i = 1; i <= 8; i++) {
            const double avg = (cols[i - 1] + linez[rowu - 1]) / 2.0;
            bits += (a[(rowu - 1) * W + i - 1] > avg) ? '1' : '0';
        }
    return bits;
}

// ConvertBase(2,16,bits): _wcstoui64 base 2, then _i64tow base 16 (lowercase, unsigned)
static std::string refBinToHex(const std::string &bits) {
    unsigned long long v = 0;
    for (size_t i = 0; i < bits.size(); i++) v = (v << 1) | (unsigned)(bits[i] == '1');
    char b[32]; snprintf(b, sizeof(b), "%llx", v); return b;
}
static std::string refIntToHex(unsigned long long v) {
    char b[32]; snprintf(b, sizeof(b), "%llx", v); return b;
}

// calcDLLpHashAlgo(arrayChars, givenArray, mode)
static std::string refPHash(const std::vector<int> &a, int mode) {
    if (a.size() != 1024) return "";
    unsigned char buf[1024];
    for (int i = 0; i < 1024; i++) buf[i] = (unsigned char)(a[i] & 0xFF);   // NumPut "UChar"
    const long long r = calcPHashAlgo(buf, 32, mode);
    return refIntToHex((unsigned long long)r);
}

// what the shipped code produces, through dupesHexHash()
static std::string shippedHex(UINT64 v) {
    wchar_t hex[32];
    dupesHexHash(v, hex, 32);
    std::string s;
    for (int i = 0; hex[i]; i++) s += (char)hex[i];
    return s;
}

// ---- driver ----------------------------------------------------------------------

static int failures = 0;
static void check(bool ok, const char *what) {
    printf("    %-62s %s\n", what, ok ? "ok" : "FAILED");
    if (!ok) failures++;
}

static UINT64 rngState = 1;
static void rngSeed(UINT64 s) { rngState = s ? s : 1; }
static UINT64 rnd64() {
    rngState ^= rngState << 13; rngState ^= rngState >> 7; rngState ^= rngState << 17;
    return rngState;
}
static UINT rndBelow(UINT n) { return (UINT)(rnd64() % n); }

// A fingerprint as the database stores it: Chr(gray + 161) per pixel.
static std::vector<wchar_t> makeRecord(int n, int kind) {
    std::vector<wchar_t> rec((size_t)n);
    for (int i = 0; i < n; i++) {
        int v;
        switch (kind) {
        case 0: v = (int)rndBelow(256); break;                 // uniform
        case 1: v = 128 + (int)rndBelow(5) - 2; break;         // near-flat, makes ties
        case 2: v = (rndBelow(2) ? 255 : 0); break;            // extremes
        case 3: v = (int)rndBelow(6); break;                   // dark
        case 4: v = 250 + (int)rndBelow(6); break;             // bright, hits the 256 case
        default: v = (i * 37) % 256; break;                    // a gradient
        }
        if (v < 0) v = 0; else if (v > 255) v = 255;
        rec[i] = (wchar_t)(v + 161);
    }
    return rec;
}

// the decode the shipped dupesHashStep() performs, extracted so it can be compared alone
static std::vector<int> shippedDecode(const std::vector<wchar_t> &rec, int level) {
    std::vector<int> out;
    out.reserve(rec.size());
    for (size_t i = 0; i < rec.size(); i++) {
        int v = (int)rec[i] - 161;
        if (v < 0) v = 0; else if (v > 255) v = 255;
        out.push_back(dupesDiscretize(v, level));
    }
    return out;
}

int main() {
    if (!calculateDCTcoeffs(32)) {
        printf("    calculateDCTcoeffs(32) failed\n");
        return 1;
    }

    long long cases = 0, badDecode = 0, badD = 0, badL = 0, badP = 0;
    for (int level = 1; level <= 9; level++) {
        for (int trial = 0; trial < 240; trial++) {
            rngSeed((UINT64)level * 7919 + trial * 104729 + 1);
            const int kind = trial % 6;

            const std::vector<wchar_t> small = makeRecord(72, kind);
            const std::vector<int> want = refDecode(small, level);
            const std::vector<int> got = shippedDecode(small, level);
            if (want != got) badDecode++;

            if (refBinToHex(refDHashBits(want)) != shippedHex(dupesDHash(got.data()))) badD++;
            if (refBinToHex(refLHashBits(want)) != shippedHex(dupesLHash(got.data()))) badL++;

            const std::vector<wchar_t> big = makeRecord(1024, kind);
            const std::vector<int> wantB = refDecode(big, level);
            const std::vector<int> gotB = shippedDecode(big, level);
            if (wantB != gotB) badDecode++;
            for (int mode = 0; mode <= 2; mode++) {
                if (refPHash(wantB, mode) != shippedHex(dupesPHash(gotB.data(), mode))) badP++;
                cases++;
            }
            cases += 2;
        }
    }

    char msg[160];
    snprintf(msg, sizeof(msg), "%lld hash cases across 9 compressor levels", cases);
    check(badDecode == 0, "the fingerprint decode matches processPixArrayChars()");
    check(badD == 0, "dHash matches, bit for bit");
    check(badL == 0, "lHash matches, bit for bit");
    check(badP == 0, "pHash matches, in all three compare modes");
    check(cases > 5000, msg);

    // The 256 case: discretizeValue(255, 2) is 256, which NumPut(..., "UChar") truncated
    // to 0. If the port ever "fixed" that by clamping, every stored pHash would shift.
    {
        std::vector<wchar_t> rec(1024, (wchar_t)(255 + 161));
        const std::vector<int> a = shippedDecode(rec, 2);
        check(a[0] == 256, "a discretised 255 at level 2 really is 256, not clamped");
        check(refPHash(a, 1) == shippedHex(dupesPHash(a.data(), 1)),
              "... and both sides truncate it to 0 on the way into calcPHashAlgo");
    }

    // The hex format: ConvertBase produces lowercase, unsigned, no padding, and "0" for 0.
    check(shippedHex(0) == "0", "a zero hash is stored as \"0\", not as an empty string");
    check(shippedHex(0xFFFFFFFFFFFFFFFFull) == "ffffffffffffffff", "the top bit does not become a minus sign");
    check(shippedHex(0x1Aull) == "1a", "lowercase, unpadded");

    printf("\n  %s\n", failures ? "HASH ORACLE FAILED" : "hash oracle passed");
    return failures ? 1 : 0;
}
