// Honest timing for the SSE2 msdScore() against a plain scalar loop over the same
// decoded bytes. Only the call is measured; buffers are prepared outside the timed
// region and the minimum of several runs is reported.
// This measures the C++ side only - it says nothing about the AHK interpreter the port
// replaced, which is the actual saving and cannot be measured on this machine.

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <random>
#include <chrono>
#include <emmintrin.h>

typedef unsigned int UINT;
typedef long long INT64;
#define QPV_FORCEINLINE inline __attribute__((always_inline))

std::vector<unsigned char> dupesPixData;
std::vector<unsigned char> dupesPixOK;
UINT                       dupesPixStride = 0;
int                        dupesPixScale = 1;

#include "msd_extract.cpp"

static int scalarMSD(const unsigned char *a, const unsigned char *b, int count, int scale) {
    INT64 sum = 0;
    for (int i = 0; i < count; i++) {
        const int d = (int)a[i] - (int)b[i];
        sum += (INT64)d * d;
    }
    sum *= (INT64)scale * scale;
    return (int)floor(sqrt((double)sum / ((double)count / 2.0)) + 0.5);
}

int main() {
    const int stride = 1024, nImg = 512, iters = 200;
    std::mt19937 rng(12345);
    std::vector<unsigned char> pix((size_t)nImg * stride);
    for (size_t i = 0; i < pix.size(); i++) pix[i] = (unsigned char)(rng() % 256);

    double bestSSE = 1e30, bestScalar = 1e30;
    volatile int sink = 0;

    for (int run = 0; run < 7; run++) {
        auto t0 = std::chrono::steady_clock::now();
        for (int it = 0; it < iters; it++)
            for (int i = 0; i + 1 < nImg; i++)
                sink += msdScore(&pix[(size_t)i * stride], &pix[(size_t)(i+1) * stride], stride, 1);
        auto t1 = std::chrono::steady_clock::now();
        double ns = std::chrono::duration<double, std::nano>(t1 - t0).count() / (iters * (nImg - 1));
        if (ns < bestSSE) bestSSE = ns;

        t0 = std::chrono::steady_clock::now();
        for (int it = 0; it < iters; it++)
            for (int i = 0; i + 1 < nImg; i++)
                sink += scalarMSD(&pix[(size_t)i * stride], &pix[(size_t)(i+1) * stride], stride, 1);
        t1 = std::chrono::steady_clock::now();
        ns = std::chrono::duration<double, std::nano>(t1 - t0).count() / (iters * (nImg - 1));
        if (ns < bestScalar) bestScalar = ns;
    }

    printf("  msdScore (SSE2)  %8.1f ns/pair\n", bestSSE);
    printf("  scalar loop      %8.1f ns/pair   (%.1fx)\n", bestScalar, bestScalar / bestSSE);
    printf("  pairs per second (SSE2): %.1f million\n", 1000.0 / bestSSE);
    return sink == 0x7fffffff;
}
