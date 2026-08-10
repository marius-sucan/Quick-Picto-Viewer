// Oracle harness for the MSD port: the SHIPPED msdScore()/decodeFingerprintBlob() are
// text-sliced out of qpv-main.cpp by run-tests.sh, so this tests what
// actually ships, not a scratch copy.
//
// Reference side reimplements the retired AHK pair exactly:
//   processPixArrayCharsAsSTR: Ord(ch) - 161, then discretizeValue(v, level)
//                              = (level != 1) ? Round(v/level)*level : v
//   calcMSDvalues:             sumB += (a[i] - b[i])**2 ; Round(sqrt(sumB/(size/2)))
// AHK's Round() is half away from zero.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <vector>
#include <random>
#include <emmintrin.h>

typedef unsigned int UINT;
typedef long long INT64;
#define QPV_FORCEINLINE inline __attribute__((always_inline))

// ---- globals the shipped decoder writes into -------------------------------------
std::vector<unsigned char> dupesPixData;
std::vector<unsigned char> dupesPixOK;
UINT                       dupesPixStride = 0;
int                        dupesPixScale = 1;

#include "msd_extract.cpp"
#include "decode_extract.cpp"

// ---- reference: the AHK that was replaced -----------------------------------------

// AHK Round(x) with no second arg: half away from zero, result is an integer.
static double ahkRound(double x) {
    return (x >= 0.0) ? std::floor(x + 0.5) : std::ceil(x - 0.5);
}

// discretizeValue(valu, levelu) -> (levelu != 1) ? Round(valu/levelu) * levelu : valu
static double ahkDiscretize(double v, int level) {
    return (level != 1) ? ahkRound(v / level) * level : v;
}

// processPixArrayCharsAsSTR() produced decimal text of these values, one per pixel.
static std::vector<double> refDecode(const wchar_t *rec, int stride, int level) {
    std::vector<double> out((size_t)stride);
    for (int i = 0; i < stride; i++)
        out[i] = ahkDiscretize((double)((int)rec[i] - 161), level);
    return out;
}

// calcMSDvalues(arrayA, arrayB, size)
static int refMSD(const std::vector<double> &a, const std::vector<double> &b, int size) {
    double sumB = 0.0;
    for (int i = 0; i < size; i++) {
        const double d = a[i] - b[i];
        sumB += d * d;
    }
    return (int)ahkRound(std::sqrt(sumB / ((double)size / 2.0)));
}

// -----------------------------------------------------------------------------------

int main(int argc, char **argv) {
    const int stride = 1024;
    unsigned long seed = (argc > 1) ? strtoul(argv[1], NULL, 10) : 20260807UL;
    std::mt19937 rng(seed);

    long long cases = 0, mismatchMSD = 0, mismatchDecode = 0;
    int worstDelta = 0;

    // A mix of distributions: uniform noise finds rounding disagreements, near-identical
    // pairs exercise the small-sum end (where the sqrt rounds near .5), and flat/extreme
    // images pin the 0 and 255 ends.
    const int kinds = 5;
    for (int level = 1; level <= 9; level++) {
        for (int trial = 0; trial < 400; trial++) {
            const int kind = trial % kinds;
            std::vector<wchar_t> blob((size_t)stride * 2);

            for (int rec = 0; rec < 2; rec++) {
                for (int i = 0; i < stride; i++) {
                    int v;
                    switch (kind) {
                    case 0: v = (int)(rng() % 256); break;                 // uniform
                    case 1: v = 128 + (int)(rng() % 5) - 2; break;         // near-flat mid
                    case 2: v = (rng() % 2) ? 255 : 0; break;              // extremes
                    case 3: v = (int)(rng() % 8); break;                   // dark
                    default: v = 248 + (int)(rng() % 8); break;            // bright
                    }
                    if (v < 0) v = 0; else if (v > 255) v = 255;
                    blob[(size_t)rec * stride + i] = (wchar_t)(v + 161);
                }
            }
            // record 1 is a perturbation of record 0 half the time, which is what a real
            // duplicate pair looks like and where the interesting MSD values live
            if (trial & 1) {
                for (int i = 0; i < stride; i++) {
                    int v = (int)blob[i] - 161 + (int)(rng() % 7) - 3;
                    if (v < 0) v = 0; else if (v > 255) v = 255;
                    blob[(size_t)stride + i] = (wchar_t)(v + 161);
                }
            }

            decodeFingerprintBlob(blob.data(), 2, (UINT)stride, level);

            const std::vector<double> ra = refDecode(&blob[0], stride, level);
            const std::vector<double> rb = refDecode(&blob[stride], stride, level);

            // the port stores the quotient Round(v/L) and multiplies back in msdScore(),
            // so the decoded byte times the level must equal AHK's discretised value
            for (int i = 0; i < stride; i++) {
                if ((int)ra[i] != (int)dupesPixData[i] * dupesPixScale) { mismatchDecode++; break; }
                if ((int)rb[i] != (int)dupesPixData[stride + i] * dupesPixScale) { mismatchDecode++; break; }
            }

            // reference is UNCLAMPED - discretizeValue(255, 2) is 256 and AHK kept it
            const int want = refMSD(ra, rb, stride);
            const int got  = msdScore(&dupesPixData[0], &dupesPixData[stride], stride, dupesPixScale);
            cases++;
            if (want != got) {
                mismatchMSD++;
                const int d = abs(want - got);
                if (d > worstDelta) worstDelta = d;
                if (mismatchMSD <= 5)
                    printf("  MSD mismatch level=%d kind=%d want=%d got=%d\n", level, kind, want, got);
            }
        }
    }

    // Explicit boundary cases.
    struct { int a, b; const char *name; } edges[] = {
        {0, 0, "both black"}, {255, 255, "both white"},
        {0, 255, "max difference"}, {255, 0, "max difference reversed"},
        {128, 129, "off by one"},
    };
    for (unsigned e = 0; e < sizeof(edges)/sizeof(edges[0]); e++) {
        std::vector<wchar_t> blob((size_t)stride * 2);
        for (int i = 0; i < stride; i++) {
            blob[i] = (wchar_t)(edges[e].a + 161);
            blob[stride + i] = (wchar_t)(edges[e].b + 161);
        }
        decodeFingerprintBlob(blob.data(), 2, (UINT)stride, 1);
        const std::vector<double> ra = refDecode(&blob[0], stride, 1);
        const std::vector<double> rb = refDecode(&blob[stride], stride, 1);
        const int want = refMSD(ra, rb, stride);
        const int got  = msdScore(&dupesPixData[0], &dupesPixData[stride], stride, dupesPixScale);
        cases++;
        printf("  edge %-24s want=%5d got=%5d %s\n", edges[e].name, want, got,
               (want == got) ? "ok" : "MISMATCH");
        if (want != got) mismatchMSD++;
    }

    // The "no fingerprint" sentinel: AHK pads such a record with code units below 161.
    {
        std::vector<wchar_t> blob((size_t)stride * 2);
        for (int i = 0; i < stride; i++) {
            blob[i] = (wchar_t)160;                 // padded / missing
            blob[stride + i] = (wchar_t)(200 + 161 - 161 + 161);
        }
        decodeFingerprintBlob(blob.data(), 2, (UINT)stride, 1);
        printf("  sentinel record: pixOK[0]=%d pixOK[1]=%d (want 0, 1)\n",
               (int)dupesPixOK[0], (int)dupesPixOK[1]);
        if (dupesPixOK[0] != 0 || dupesPixOK[1] != 1) mismatchDecode++;
    }

    // Overflow headroom: the worst case must stay inside the INT32 lanes _mm_madd_epi16
    // accumulates into.
    printf("  worst-case accumulator: %lld (INT32 max %lld)\n",
           (long long)stride * 255 * 255, (long long)2147483647);

    printf("\n  cases=%lld  MSD mismatches=%lld  decode mismatches=%lld  worst delta=%d\n",
           cases, mismatchMSD, mismatchDecode, worstDelta);
    return (mismatchMSD || mismatchDecode) ? 1 : 0;
}
