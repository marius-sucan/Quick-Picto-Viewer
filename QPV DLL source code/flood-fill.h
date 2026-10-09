// flood-fill.h
//
// The flood fill and "Replace similar colours anywhere" [modus 1], both run by FloodJob.
//
// Usage from AHK:
//    FloodFillWrapper(imageData, modus, ...)               finds and paints in one call
//    FloodFillFindRegion(imageData, modus, ..., &bounds)   finds and keeps the region, then
//    FloodFillPaintRegion(imageData, w, h, Stride, bpp)    paints it, or
//    FloodFillDiscardRegion()                              drops it
//
// #included by qpv-main.cpp after selection-mask.h, whose selection state and clipMaskFilter() it
// uses; it also uses CalculateNewBlendModes() from blend-modes.h, and CalcPixOffset(), RGBtoGray()
// and the LUT_X/Y/Z_* tables of qpv-main.cpp.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_FLOOD_FILL_H
#define QPV_FLOOD_FILL_H

#include <atomic>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <vector>
#include <array>
#include <string>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <climits>
#include <new>
#include <emmintrin.h>
#if defined(_MSC_VER)
#include <intrin.h>
#endif

double toLABf(double Y) {
  // if (Y >= 0.00885645167903563082) // CIE epsilon = 216/24389
  if (Y >= 0.00885645167903563082e-3) // intentionally chosen value
     Y = cbrt(Y);  // 1/3
  else
     Y = (841.0/108.0) * Y + (4.0/29.0);

  return Y;
}

float CIEdeltaE2000(double Cl_1, double Ca_1, double Cb_1, double Cl_2, double Ca_2, double Cb_2, float WHT_L, float WHT_C, float WHT_H) {
// Cl_1,  Ca_1,  Cb_1   - Color #1 CIE-L*ab values
// Cl_2,  Ca_2,  Cb_2   - Color #2 CIE-L*ab values
// WHT_L, WHT_C, WHT_H  - Weight factors: luminance, chroma and hue
// tested against http://www.brucelindbloom.com/index.html?ColorDifferenceCalc.html

  const double pwr = 6103515625.0; // 25^7;
  double xC1 = sqrt( Ca_1*Ca_1 + Cb_1*Cb_1 );
  double xC2 = sqrt( Ca_2*Ca_2 + Cb_2*Cb_2 );
  double xCX = ( xC1 + xC2 ) * 0.5;   // C-bar
  
  double xCX2 = xCX * xCX;
  double xCX4 = xCX2 * xCX2;
  double zpx = xCX4 * xCX2 * xCX; // xCX^7
  
  double xGX = 0.5 * ( 1.0 - sqrt( zpx / ( zpx + pwr ) ) );

  double xNN1 = ( 1.0 + xGX ) * Ca_1;            // A-Prime 1
  double xCPrime1 = sqrt( xNN1*xNN1 + Cb_1*Cb_1 );   // C-Prime 1
  double xH1 = (xNN1 == 0.0 && Cb_1 == 0.0) ? 0.0 : atan2(Cb_1, xNN1) * (180.0 / M_PI);
  if (xH1 < 0.0) xH1 += 360.0;
 
  double xNN2 = ( 1.0 + xGX ) * Ca_2;                   // A-Prime 2
  double xCPrime2 = sqrt( xNN2*xNN2 + Cb_2*Cb_2 );   // C-Prime 2
  double xH2 = (xNN2 == 0.0 && Cb_2 == 0.0) ? 0.0 : atan2(Cb_2, xNN2) * (180.0 / M_PI);
  if (xH2 < 0.0) xH2 += 360.0;

  // compute Delta H-Prime based on H-Primes
  double xDH; 
  if ( ( xCPrime1 * xCPrime2 ) == 0.0 )
  {
     xDH = 0.0;
  } else 
  {
     double diff = xH2 - xH1;
     if ( fabs( diff ) <= 180.0 ) {
        xDH = diff;
     }
     else {
        if ( diff > 180.0 )
           xDH = diff - 360.0;
        else
           xDH = diff + 360.0;
     }
  }

  xDH = 2.0 * sqrt( xCPrime1 * xCPrime2 ) * sin( (xDH * 0.5) * (M_PI / 180.0) ); // Delta H-Prime

  double xHX;  // compute the H-Bar Prime
  if ( ( xCPrime1 *  xCPrime2 ) == 0.0 )
  {
     xHX = xH1 + xH2;
  } else
  {
     double diff = fabs(xH1 - xH2);
     if ( diff > 180.0 )
     {
        if ( ( xH2 + xH1 ) < 360.0 )
           xHX = xH1 + xH2 + 360.0;
        else
           xHX = xH1 + xH2 - 360.0;
     } else
     {
        xHX = xH1 + xH2;
     }
     xHX *= 0.5; // the H-Bar Prime
  }

  // xTX, the T variable, based on H-Bar Prime
  double hxRad = xHX * (M_PI / 180.0);
  double xTX = 1.0 - 0.17 * cos( hxRad - (30.0 * M_PI / 180.0) ) + 0.24
                          * cos( 2.0 * hxRad ) + 0.32
                          * cos( 3.0 * hxRad + (6.0 * M_PI / 180.0) ) - 0.20
                          * cos( 4.0 * hxRad - (63.0 * M_PI / 180.0) );

  double xCY = ( xCPrime1 + xCPrime2 ) * 0.5;        // C-Bar Prime based on C-Primes
  double xCY2 = xCY * xCY;
  double xCY4 = xCY2 * xCY2;
  double ytp = xCY4 * xCY2 * xCY; // xCY^7

  // compute R sub T
  double grp = ( xHX - 275.0 ) * 0.04; // / 25.0
  double xPH = 60.0 * exp(-1.0*(grp*grp));           // based on H-Bar Prime
  double xRC = 2.0 * sqrt( ytp / ( ytp + pwr ) );   // based on C-Bar Prime
  double xRT = - sin( xPH * (M_PI / 180.0) ) * xRC;  // R sub T

  double xLX = ( Cl_1 + Cl_2 ) * 0.5 - 50.0; // L-Bar
  double xLX2 = xLX * xLX;
  double xSL = 1.0 + ( 0.015 * xLX2 ) / sqrt( 20.0 + xLX2 );   // S sub L based on L-Bar
  double xSC = 1.0 + 0.045 * xCY;       // S sub C - based on C-Bar Prime
  double xSH = 1.0 + 0.015 * xCY * xTX; // S sub H - based on C-Bar Prime and T-var

  double xDL = Cl_2 - Cl_1;              // Delta L-Prime
  double xDC = xCPrime2 - xCPrime1;                // Delta C-Prime based on C-Primes
  xDL = xDL / ( WHT_L * xSL );
  xDC = xDC / ( WHT_C * xSC );
  xDH = xDH / ( WHT_H * xSH );

  return sqrt(xDL*xDL + xDC*xDC + xDH*xDH + xRT * xDC * xDH);
}

auto RGBtoLAB(int &sR, int &sG, int &sB) {
  // https://getreuer.info/posts/colorspace/index.html
  // http://www.easyrgb.com/en/math.php
  // sR, sG and sB (Standard RGB) input range = 0 ÷ 255
  // X, Y and Z outputs refer to a D65/2° standard illuminant.
  // https://zschuessler.github.io/DeltaE/demos/
  // tested against ColorMine.org

  double X = LUT_X_R[sR] + LUT_X_G[sG] + LUT_X_B[sB];
  double Y = LUT_Y_R[sR] + LUT_Y_G[sG] + LUT_Y_B[sB];
  double Z = LUT_Z_R[sR] + LUT_Z_G[sG] + LUT_Z_B[sB];

  X = toLABf(X);
  Y = toLABf(Y);
  Z = toLABf(Z);

  std::array<double, 3> Lab;
  Lab[0] = 116.0*Y - 16.0;
  Lab[1] = 500.0*(X - Y);
  Lab[2] = 200.0*(Y - Z);
  return Lab;
}

RGBAColor mixColorsFloodFill(RGBAColor &colorB, RGBAColor &colorA, float &fillOpacity, int dynamicOpacity, int &blendMode, float prevCLRindex, float tolerance, int alternateMode, float thisCLRindex, int linearGamma, int flipLayers) {
  int opacity = 0;
  if (dynamicOpacity==1)
  {
     // a colour equal to the clicked one keeps the full opacity; at tolerance 0 it would be 0/0
     float fz = 0.0f;
     if (alternateMode==3) {
        if (thisCLRindex>0)
           fz = clamp ( (float)thisCLRindex/tolerance, 0.0f, 1.0f);
     } else 
     {
        float diffu = max(thisCLRindex, prevCLRindex) - min(thisCLRindex, prevCLRindex);
        if (diffu>0)
           fz = clamp( (float)diffu/tolerance, 0.0f, 1.0f);
     }
     float f = 1.0f - clamp(fillOpacity - fz, 0.0f, 1.0f);
     opacity = (unsigned char)(f * 255.0f + 0.5f);
  } else
     opacity = (unsigned char)((1.0f - fillOpacity) * 255.0f + 0.5f);

  return CalculateNewBlendModes(colorA, colorB, blendMode, flipLayers, linearGamma, 0, 32, opacity);
}

bool decideColorsEqual(RGBAColor newColor, RGBAColor oldColor, float tolerance, float prevCLRindex, int alternateMode, float *nC, float& index, int debug=0) {
    // should use CIEDE2000
    if (oldColor.r == newColor.r && oldColor.g == newColor.g && oldColor.b == newColor.b && alternateMode!=3)
    {
       index = prevCLRindex;
       return 1;
    }

    if (tolerance<1)
       return 0;

    bool result;
    if (alternateMode==3)
    {
       auto LabB = RGBtoLAB(newColor.r, newColor.g, newColor.b);
       index = CIEdeltaE2000(nC[4], nC[5], nC[6], LabB[0], LabB[1], LabB[2], 1, 1, 1);
       result = (index<=tolerance) ? 1 : 0;
    } else
    {
       index = RGBtoGray(newColor.r, newColor.g, newColor.b, alternateMode);
       result = inRange(index - tolerance, index + tolerance, prevCLRindex);
    }
    // if (debug==1)
    //    fnOutputDebug("clr==" + std::to_string(newColor.r) + "," + std::to_string(newColor.g) + "," + std::to_string(newColor.b) + "  |  " + std::to_string(index) );
    return result;
}

// ---------- Flood fill ----------
// The region is found first, as a map of filled pixels, and painted afterwards. Rows are tested 64
// pixels per word and each word's test runs once. Everything a fill allocates stays within
// floodFillBudget: an image whose maps do not fit is walked in bands of rows that pass seeds
// across their edges until no edge changes.

static size_t floodFillBudget = (size_t)512 << 20;
static int floodFillThreadsSet = 0;   // 0 = one per hardware thread
static size_t floodSpanCapSet = 0;   // 0 = as many spans as the budget leaves room for
static const size_t floodSpanReserve = (size_t)1 << 20;
static INT64 floodParallelMin = 65536;
static const int floodPaintMemoBits = 18;
static const int floodIndexMemoBits = 18;
static const uint32_t floodHashMul = 2654435761u;

static inline int floodLowBit(uint64_t v) {
#if defined(_MSC_VER)
    unsigned long i;
    _BitScanForward64(&i, v);
    return (int)i;
#else
    return __builtin_ctzll(v);
#endif
}

static inline int floodHighBit(uint64_t v) {
#if defined(_MSC_VER)
    unsigned long i;
    _BitScanReverse64(&i, v);
    return (int)i;
#else
    return 63 - __builtin_clzll(v);
#endif
}

static inline std::atomic<uint64_t>* floodAtom(uint64_t *p) {
    return reinterpret_cast<std::atomic<uint64_t>*>(p);
}

// bits lo..hi, 0 <= lo <= hi <= 63
static inline uint64_t floodBits(int lo, int hi) {
    return (~0ULL >> (63 - hi)) & (~0ULL << lo);
}

// 64 bits of a bit array from bit position start on
static inline uint64_t floodBitsAt(const uint64_t *words, size_t count, INT64 start) {
    const size_t i = (size_t)(start >> 6);
    const int s = (int)(start & 63);
    uint64_t v = (i < count) ? words[i] >> s : 0;
    if (s && i + 1 < count)
       v |= words[i + 1] << (64 - s);
    return v;
}

// zeroed pages from the system; untouched pages cost neither memory nor time
static uint64_t* floodAlloc(size_t words) {
    return (uint64_t*)VirtualAlloc(NULL, std::max<size_t>(words, 1) * sizeof(uint64_t), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
}

template <class T> static void floodRelease(T *&p) {
    if (p)
       VirtualFree(p, 0, MEM_RELEASE);
    p = NULL;
}

static int floodThreads() {
    if (floodFillThreadsSet > 0)
       return floodFillThreadsSet;

    const unsigned int hw = std::thread::hardware_concurrency();
    return (hw > 0) ? std::min((int)hw, 64) : 1;
}

static constexpr uint32_t floodMulInverse(uint32_t a) {
    uint32_t x = a;
    for (int i = 0; i < 4; i++)
        x *= 2u - a * x;
    return x;
}

struct FloodParams {
    unsigned char *img = NULL;
    int w = 0, h = 0, stride = 0, bpp = 0, bpx = 0;
    int sx = 0, sy = 0, exact = 0, eightWay = 0, replace = 0;
    RGBAColor newColor = {0, 0, 0, 0}, oldColor = {0, 0, 0, 0};
    float nC[7] = {0, 0, 0, 0, 0, 0, 0};
    float tolerance = 0, prevCLRindex = 0, opacity = 0;
    int dynamicOpacity = 0, blendMode = 0, cartoonMode = 0, alternateMode = 0;
    int linearGamma = 0, flipLayers = 0, keepAlpha = 0, useSelArea = 0;
};

// clipMaskFilter() for 64 pixels of a row at once; a set bit is a pixel the fill must leave alone
struct FloodSel {
    int kind = 0;   // 0 no selection, 1 clipMaskFilter() per pixel, 2 box, 3 polygon, 4 rect or ellipse
    int inv = 0, ellipse = 0, flip = 0, cavity = 0;
    int bx1 = 0, bx2 = 0, by1 = 0, by2 = 0, selX1 = 0, selY1 = 0;
    INT64 pRowOff = 0, pColOff = 0, pW = 0;
    int pWlast = 0, pHlast = 0;
    const uint64_t *pWords = NULL;
    size_t pWordCount = 0;
    float tw = 0, th = 0, tw2 = 0, th2 = 0, twq = 0, thq = 0, tw2q = 0, th2q = 0;
    float exX = 0, exY = 0, scX = 0, scY = 0, cs = 0, sn = 0;

    void init(int useSelArea) {
        kind = 0;
        if (useSelArea!=1)
           return;

        inv = (imgSel.inverted==1) ? 1 : 0;
        if (!inv && imgSel.highDepth==1)
        {
           kind = 1;
           return;
        }

        selX1 = imgSel.x1;
        selY1 = imgSel.y1;
        bx1 = imgSel.x1;
        bx2 = imgSel.x2;
        by1 = (inv && imgSel.shape!=2) ? imgSel.y1 : (int)(imgSel.y1 - imgSel.maskRowShift);
        by2 = imgSel.y2;
        if (imgSel.shape==2)
        {
           kind = 3;
           pRowOff = imgSel.maskRowShift - imgSel.maskY;
           pColOff = -imgSel.maskX;
           pW = imgSel.maskW;
           pWlast = (int)(imgSel.maskW - 1);
           pHlast = (int)(imgSel.maskH - 1);
           pWords = imgSel.mask.words();
           pWordCount = imgSel.mask.word_count();
        } else if (imgSel.shape==1 || (imgSel.shape==0 && (imgSel.angle!=0 || imgSel.exclusion!=0)))
        {
           kind = 4;
           ellipse = (imgSel.shape==1) ? 1 : 0;
           flip = (imgSel.flipped==1) ? 1 : 0;
           cavity = (imgSel.exclusion!=0) ? 1 : 0;
           tw = imgSel.halfW;      th = imgSel.halfH;
           tw2 = imgSel.exclHalfW;  th2 = imgSel.exclHalfH;
           twq = tw * tw;      thq = th * th;
           tw2q = tw2 * tw2;   th2q = th2 * th2;
           exX = imgSel.exclX;  exY = imgSel.exclY;
           scX = imgSel.scaleX; scY = imgSel.scaleY;
           cs = imgSel.cosAngle;
           sn = imgSel.sinAngle;
        } else
        {
           kind = 2;
        }
    }

    uint64_t polyBits(int y, int x0, int n) const {
        const INT64 my = (INT64)(y - selY1) + pRowOff;
        if ((int)my < 0 || (int)my > pHlast)
           return 0;

        const INT64 mx0 = (INT64)(x0 - selX1) + pColOff;
        const int la = (mx0 < 0) ? (int)std::min<INT64>(-mx0, 64) : 0;
        const int lb = (int)std::min<INT64>(n - 1, (INT64)pWlast - mx0);
        if (la > lb)
           return 0;

        return (floodBitsAt(pWords, pWordCount, my * pW + mx0 + la) << la) & floodBits(la, lb);
    }

    // the float steps of isInsideRectOval(), four pixels per step
    uint64_t shapeBits(int y, int x0, uint64_t lanes) const {
        const float oy = (float)(y - selY1);
        const float yo = (oy - th) * scY;
        const __m128 vYs = _mm_set1_ps(yo * sn), vYc = _mm_set1_ps(yo * cs);
        const float yi = (oy - th2 - exY) * scY;
        const __m128 vYs2 = _mm_set1_ps(yi * sn), vYc2 = _mm_set1_ps(yi * cs);
        const __m128 vTw = _mm_set1_ps(tw), vTh = _mm_set1_ps(th), vTwq = _mm_set1_ps(twq), vThq = _mm_set1_ps(thq);
        const __m128 vTw2 = _mm_set1_ps(tw2), vTh2 = _mm_set1_ps(th2), vTw2q = _mm_set1_ps(tw2q), vTh2q = _mm_set1_ps(th2q);
        const __m128 vExX = _mm_set1_ps(exX), vScX = _mm_set1_ps(scX), vCs = _mm_set1_ps(cs), vSn = _mm_set1_ps(sn);
        const __m128 one = _mm_set1_ps(1.0f), absMask = _mm_castsi128_ps(_mm_set1_epi32(0x7FFFFFFF));
        const int ox0 = x0 - selX1;
        uint64_t r = 0;
        for (int i = floodLowBit(lanes) & ~3; i <= floodHighBit(lanes); i += 4)
        {
            const __m128 ox = _mm_cvtepi32_ps(_mm_setr_epi32(ox0 + i, ox0 + i + 1, ox0 + i + 2, ox0 + i + 3));
            __m128 X = _mm_mul_ps(_mm_sub_ps(ox, vTw), vScX);
            __m128 rX = flip ? _mm_add_ps(_mm_mul_ps(X, vCs), vYs) : _mm_sub_ps(_mm_mul_ps(X, vCs), vYs);
            __m128 rY = flip ? _mm_sub_ps(_mm_mul_ps(X, vSn), vYc) : _mm_add_ps(_mm_mul_ps(X, vSn), vYc);
            __m128 f = ellipse ? _mm_cmple_ps(_mm_add_ps(_mm_div_ps(_mm_mul_ps(rX, rX), vTwq), _mm_div_ps(_mm_mul_ps(rY, rY), vThq)), one)
                               : _mm_and_ps(_mm_cmplt_ps(_mm_and_ps(rX, absMask), vTw), _mm_cmplt_ps(_mm_and_ps(rY, absMask), vTh));
            if (cavity)
            {
               X = _mm_mul_ps(_mm_sub_ps(_mm_sub_ps(ox, vTw2), vExX), vScX);
               rX = flip ? _mm_add_ps(_mm_mul_ps(X, vCs), vYs2) : _mm_sub_ps(_mm_mul_ps(X, vCs), vYs2);
               rY = flip ? _mm_sub_ps(_mm_mul_ps(X, vSn), vYc2) : _mm_add_ps(_mm_mul_ps(X, vSn), vYc2);
               const __m128 g = ellipse ? _mm_cmple_ps(_mm_add_ps(_mm_div_ps(_mm_mul_ps(rX, rX), vTw2q), _mm_div_ps(_mm_mul_ps(rY, rY), vTh2q)), one)
                                        : _mm_and_ps(_mm_cmplt_ps(_mm_and_ps(rX, absMask), vTw2), _mm_cmplt_ps(_mm_and_ps(rY, absMask), vTh2));
               f = _mm_andnot_ps(g, f);
            }
            r |= (uint64_t)_mm_movemask_ps(f) << i;
        }
        return r & lanes;
    }

    uint64_t masked(int y, int x0, int n) const {
        const uint64_t all = (n >= 64) ? ~0ULL : ((1ULL << n) - 1);
        if (kind==1)
        {
           uint64_t m = 0;
           for (int i = 0; i < n; i++)
               if (clipMaskFilter(x0 + i, y, NULL, 0)==1)
                  m |= 1ULL << i;
           return m;
        }

        uint64_t hit = 0;
        if (y >= by1 && y <= by2)
        {
           const int la = std::max(bx1 - x0, 0), lb = std::min(bx2 - x0, n - 1);
           if (la <= lb)
              hit = floodBits(la, lb);
        }
        if (hit && kind==3)
           hit &= polyBits(y, x0, n);
        else if (hit && kind==4)
           hit = shapeBits(y, x0, hit);
        return inv ? hit : (all & ~hit);
    }
};

struct FloodSpan {
    int y, x1, x2;   // x2 < x1: a seed pixel at x1, reached across a strip edge
};

// direct-mapped: source BGRA -> painted BGRA
struct FloodPaintMemo {
    std::vector<uint64_t> e;
    int bits = 0;
    uint32_t lookups = 0, misses = 0;
    void init(int b) {
        bits = b;
        e.resize((size_t)1 << b);
        const uint32_t inv = floodMulInverse(floodHashMul), mask = (1u << b) - 1;
        // an empty slot holds a key that hashes to the next slot, so it never matches
        for (uint32_t s = 0; s <= mask; s++)
            e[s] = (uint64_t)((((s + 1) & mask) << (32 - b)) * inv) << 32;
    }
    // a memo that mostly misses, as with alpha that varies per pixel, costs more than it saves
    bool worthKeeping() {
        if (lookups < 65536)
           return true;
        const bool keep = (uint64_t)misses * 4 <= (uint64_t)lookups * 3;
        lookups = misses = 0;
        return keep;
    }
};

struct FloodJob;

struct FloodShared {
    std::mutex mx;
    std::condition_variable cv;
    std::vector<FloodSpan> pool;
    std::atomic<int> poolSize{0};
    std::atomic<int> idleHint{0};
    int idle = 0, workers = 0;
    bool done = false;
};

struct FloodWalker {
    FloodJob *j;
    FloodShared *sh;   // NULL while one thread walks
    std::vector<FloodSpan> stack;
    INT64 filled = 0;
    int minX = INT_MAX, minY = INT_MAX, maxX = -1, maxY = -1;

    FloodWalker(FloodJob *job, FloodShared *shared) : j(job), sh(shared) {}
    inline uint64_t mword(int y, int k);
    inline uint64_t avail(int y, int k);
    void push(const FloodSpan &s);
    void addRun(int y, int a, int b);
    void claim(int y, int x1, int x2);
    void fillAt(int y, int x);
    void probeRow(int ny, int lo, int hi);
    void process(const FloodSpan &s);
    void seedRow(int y, const uint64_t *probe);
    void donate();
};

struct FloodJob {
    FloodParams p;
    FloodSel sel;
    int T = 1, paintT = 1, wpr = 0, stripW = 0;
    int constPaint = 0, writeAlpha = 0, wantIndex = 0, seedByDistance = 0;
    uint32_t oldRGB = 0, constBGRA = 0;
    float defIndex = 0;
    uint64_t *colourTable = NULL, *indexMemo = NULL;
    uint32_t *grayRanges = NULL;      // "Grayscale [fast]": the matching blues of each (red, green)
    int grayLo = 0, grayHi = -1;
    uint64_t *F = NULL, *M = NULL, *K = NULL;
    int bandRows = 0, bands = 1, r0 = 0, r1 = 0, heldBand = -1, usedRow0 = 0, usedRow1 = -1;
    size_t kWords = 0, spanCap = 0, localCap = 0, dirtyWords = 0;
    uint64_t *dirty = NULL;           // rows of the band whose spans were dropped
    uint64_t *rowHits = NULL;         // colour replacement: rows with a pixel to paint
    std::atomic<int> anyDirty{0};
    std::vector<uint64_t> edgeTop, edgeBot;
    std::vector<INT64> bandCount;
    std::vector<int> bandBox;
    INT64 count = 0;
    int boxX1 = 0, boxY1 = 0, boxX2 = -1, boxY2 = -1;
    bool failed = false;

    explicit FloodJob(const FloodParams &q) : p(q) {}
    ~FloodJob() {
        floodRelease(colourTable);
        floodRelease(indexMemo);
        floodRelease(grayRanges);
        floodRelease(F);
        floodRelease(M);
        floodRelease(K);
        floodRelease(dirty);
        floodRelease(rowHits);
    }

    // rows y-1..y+1 need another look: a span of row y was dropped with the stack full
    void markDirty(int y) {
        for (int r = std::max(y - 1, r0); r <= std::min(y + 1, r1 - 1); r++)
            floodAtom(dirty + ((r - r0) >> 6))->fetch_or(1ULL << ((r - r0) & 63), std::memory_order_relaxed);
        anyDirty.store(1, std::memory_order_relaxed);
    }

    // the weighted grayscale only grows with blue, so the blues that match form one range;
    // bits 0-8 hold its first blue, 9-17 its last, 31 that it was worked out
    uint32_t grayRange(uint32_t rg) {
        int r = rg >> 8, g = rg & 255, alt = 1;
        int lo = 0, hi = 256;
        while (lo < hi)
        {
            int mid = (lo + hi) >> 1;
            if (RGBtoGray(r, g, mid, alt) >= grayLo)
               hi = mid;
            else
               lo = mid + 1;
        }
        const int bLo = lo;
        lo = -1;
        hi = 255;
        while (lo < hi)
        {
            int mid = (lo + hi + 1) >> 1;
            if (RGBtoGray(r, g, mid, alt) <= grayHi)
               lo = mid;
            else
               hi = mid - 1;
        }
        const int bHi = lo;
        const uint32_t e = 0x80000000u | (uint32_t)((bHi < bLo) ? 511 : bLo) | ((uint32_t)std::max(bHi, 0) << 9);
        reinterpret_cast<std::atomic<uint32_t>*>(grayRanges + rg)->store(e, std::memory_order_relaxed);
        return e;
    }

    QPV_FORCEINLINE bool grayMatches(uint32_t rgb) {
        uint32_t e = reinterpret_cast<std::atomic<uint32_t>*>(grayRanges + (rgb >> 8))->load(std::memory_order_relaxed);
        if (!e)
           e = grayRange(rgb >> 8);
        const int b = rgb & 255, bFirst = e & 511, bLast = (e >> 9) & 511;
        return b >= bFirst && b <= bLast;
    }

    // whether the 64 pixels from px on share one colour, alpha aside
    inline bool wordIsOneColour(const unsigned char *px) const {
        if (p.bpx==3)
           return memcmp(px, px + 3, 63 * 3)==0;
        if (p.bpx!=4)
           return false;

        uint32_t first;
        memcpy(&first, px, 4);
        const __m128i rgbMask = _mm_set1_epi32(0x00FFFFFF);
        const __m128i key = _mm_and_si128(_mm_set1_epi32((int)first), rgbMask);
        for (int i = 0; i < 64; i += 4)
        {
            const __m128i v = _mm_and_si128(_mm_loadu_si128((const __m128i*)(px + i * 4)), rgbMask);
            if (_mm_movemask_ps(_mm_castsi128_ps(_mm_cmpeq_epi32(v, key)))!=15)
               return false;
        }
        return true;
    }

    // a lookup table of the colour decisions: blue ranges for "Grayscale [fast]", else every colour
    bool setupColourDecisions() {
        if (p.exact)
           return true;
        if (p.alternateMode==1 && p.tolerance >= 1 && !seedByDistance)
        {
           for (int g = 0; g < 256; g++)
           {
               const float index = (float)g;
               if (inRange(index - p.tolerance, index + p.tolerance, p.prevCLRindex))
               {
                  if (grayHi < grayLo)
                     grayLo = g;
                  grayHi = g;
               }
           }
           grayRanges = (uint32_t*)floodAlloc(65536 / 2);
           return grayRanges!=NULL;
        }
        colourTable = floodAlloc((size_t)1 << 19);
        return colourTable!=NULL;
    }

    QPV_FORCEINLINE bool colourMatches(uint32_t rgb, const unsigned char *q) {
        if (rgb==oldRGB && !seedByDistance)
           return 1;
        if (!(p.tolerance > 0))
           return 0;

        std::atomic<uint64_t> *cw = floodAtom(colourTable + (rgb >> 5));
        const int shift = (rgb & 31) << 1;
        const unsigned int code = (unsigned int)(cw->load(std::memory_order_relaxed) >> shift) & 3;
        if (code)
           return code==1;

        const RGBAColor c = {q[0], q[1], q[2], (p.bpx==4) ? q[3] : 255};
        float index = 0;
        const bool r = decideColorsEqual(c, p.oldColor, p.tolerance, p.prevCLRindex, p.alternateMode, p.nC, index);
        cw->fetch_or((uint64_t)(r ? 1 : 2) << shift, std::memory_order_relaxed);
        if (r && wantIndex)
        {
           uint32_t bits;
           memcpy(&bits, &index, 4);
           floodAtom(indexMemo + ((rgb * floodHashMul) >> (32 - floodIndexMemoBits)))->store(((uint64_t)(rgb | (1u << 24)) << 32) | bits, std::memory_order_relaxed);
        }
        return r;
    }

    uint32_t paintedColour(uint32_t key) {
        RGBAColor prev = {(int)(key & 255), (int)((key >> 8) & 255), (int)((key >> 16) & 255), (int)(key >> 24)};
        const uint32_t rgb = key & 0xFFFFFF;
        float index = defIndex;
        if (wantIndex && (rgb!=oldRGB || seedByDistance))
        {
           const uint64_t e = floodAtom(indexMemo + ((rgb * floodHashMul) >> (32 - floodIndexMemoBits)))->load(std::memory_order_relaxed);
           if ((uint32_t)(e >> 32)==(rgb | (1u << 24)))
           {
              const uint32_t bits = (uint32_t)e;
              memcpy(&index, &bits, 4);
           } else
           {
              decideColorsEqual(prev, p.oldColor, p.tolerance, p.prevCLRindex, p.alternateMode, p.nC, index);
           }
        }

        RGBAColor nc = p.newColor;
        float op = p.opacity;
        int bm = p.blendMode;
        const RGBAColor t = mixColorsFloodFill(prev, nc, op, p.dynamicOpacity, bm, p.prevCLRindex, p.tolerance, p.alternateMode, index, p.linearGamma, p.flipLayers);
        return (uint32_t)(unsigned char)t.b | ((uint32_t)(unsigned char)t.g << 8) | ((uint32_t)(unsigned char)t.r << 16) | ((uint32_t)(unsigned char)t.a << 24);
    }

    void paintRun(unsigned char *row, int x1, int x2, FloodPaintMemo *memo) {
        unsigned char *q = row + (INT64)x1 * p.bpx;
        if (constPaint)
        {
           if (p.bpx==4 && writeAlpha)
           {
              for (int x = x1; x <= x2; x++, q += 4)
                  memcpy(q, &constBGRA, 4);
           } else
           {
              const unsigned char cb = constBGRA & 255, cg = (constBGRA >> 8) & 255, cr = (constBGRA >> 16) & 255, ca = constBGRA >> 24;
              for (int x = x1; x <= x2; x++, q += p.bpx)
              {
                  q[0] = cb;  q[1] = cg;  q[2] = cr;
                  if (writeAlpha)
                     q[3] = ca;
              }
           }
           return;
        }

        const int shift = memo ? 32 - memo->bits : 0;
        for (int x = x1; x <= x2; x++, q += p.bpx)
        {
            const uint32_t key = (uint32_t)q[0] | ((uint32_t)q[1] << 8) | ((uint32_t)q[2] << 16) | ((uint32_t)((p.bpx==4) ? q[3] : 255) << 24);
            uint32_t v;
            if (memo)
            {
               uint64_t &e = memo->e[(key * floodHashMul) >> shift];
               memo->lookups++;
               if ((uint32_t)(e >> 32)!=key)
               {
                  memo->misses++;
                  e = ((uint64_t)key << 32) | paintedColour(key);
               }
               v = (uint32_t)e;
            } else
            {
               v = paintedColour(key);
            }

            q[0] = v & 255;  q[1] = (v >> 8) & 255;  q[2] = (v >> 16) & 255;
            if (writeAlpha)
               q[3] = v >> 24;
        }
    }

    uint64_t testWord(int y, int k);
    void setupPaint();
    bool setup();
    bool setupReplace();
    INT64 replaceScan(bool paintIt);
    INT64 replaceAll();
    void beginBand(int b);
    void runWalk(FloodWalker &w);
    bool walkParallel(FloodWalker &w);
    void rescan();
    bool edgeSeeds(int y, const uint64_t *edge, const uint64_t *known);
    void walkBand(int b);
    INT64 find();
    void paintRows(int y1, int y2, int x1, int x2);
    INT64 paint();
};

// a word's pixels that match the colour and that the selection leaves open
uint64_t FloodJob::testWord(int y, int k) {
    const int x0 = k << 6, n = std::min(64, p.w - x0);
    const unsigned char *px = p.img + (INT64)y * p.stride + (INT64)x0 * p.bpx;
    uint64_t m = 0;
    if (p.exact && p.bpx==4)
    {
       const __m128i key = _mm_set1_epi32((int)oldRGB), rgbMask = _mm_set1_epi32(0x00FFFFFF);
       int i = 0;
       for (; i + 4 <= n; i += 4)
       {
           const __m128i v = _mm_and_si128(_mm_loadu_si128((const __m128i*)(px + i * 4)), rgbMask);
           m |= (uint64_t)_mm_movemask_ps(_mm_castsi128_ps(_mm_cmpeq_epi32(v, key))) << i;
       }
       for (; i < n; i++)
       {
           const unsigned char *q = px + i * 4;
           if ((((uint32_t)q[2] << 16) | ((uint32_t)q[1] << 8) | q[0])==oldRGB)
              m |= 1ULL << i;
       }
    } else if (p.exact)
    {
       for (int i = 0; i < n; i++)
       {
           const unsigned char *q = px + (INT64)i * p.bpx;
           if ((((uint32_t)q[2] << 16) | ((uint32_t)q[1] << 8) | q[0])==oldRGB)
              m |= 1ULL << i;
       }
    } else if (n==64 && wordIsOneColour(px))
    {
       // a flat area: one decision for the whole word
       const uint32_t rgb = ((uint32_t)px[2] << 16) | ((uint32_t)px[1] << 8) | px[0];
       m = (grayRanges ? grayMatches(rgb) : colourMatches(rgb, px)) ? ~0ULL : 0;
    } else if (grayRanges)
    {
       uint32_t last = 0xFFFFFFFF;
       uint64_t lastBit = 0;
       for (int i = 0; i < n; i++)
       {
           const unsigned char *q = px + (INT64)i * p.bpx;
           const uint32_t rgb = ((uint32_t)q[2] << 16) | ((uint32_t)q[1] << 8) | q[0];
           if (rgb!=last)
           {
              last = rgb;
              lastBit = grayMatches(rgb) ? 1 : 0;
           }
           m |= lastBit << i;
       }
    } else
    {
       uint32_t last = 0xFFFFFFFF;
       uint64_t lastBit = 0;
       for (int i = 0; i < n; i++)
       {
           const unsigned char *q = px + (INT64)i * p.bpx;
           const uint32_t rgb = ((uint32_t)q[2] << 16) | ((uint32_t)q[1] << 8) | q[0];
           if (rgb!=last)
           {
              last = rgb;
              lastBit = colourMatches(rgb, q) ? 1 : 0;
           }
           m |= lastBit << i;
       }
    }

    if (m && sel.kind)
       m &= ~sel.masked(y, x0, n);
    return m;
}

inline uint64_t FloodWalker::mword(int y, int k) {
    const size_t i = (size_t)(y - j->r0) * j->wpr + k;
    std::atomic<uint64_t> *kw = floodAtom(j->K + (i >> 6));
    const uint64_t bit = 1ULL << (i & 63);
    if (kw->load(std::memory_order_acquire) & bit)
       return floodAtom(j->M + i)->load(std::memory_order_relaxed);

    const uint64_t v = j->testWord(y, k);
    floodAtom(j->M + i)->store(v, std::memory_order_relaxed);
    kw->fetch_or(bit, std::memory_order_release);
    return v;
}

inline uint64_t FloodWalker::avail(int y, int k) {
    return mword(y, k) & ~floodAtom(j->F + (size_t)(y - j->r0) * j->wpr + k)->load(std::memory_order_relaxed);
}

// a span that does not fit is left to rescan(): its pixels are in F already
void FloodWalker::push(const FloodSpan &s) {
    const size_t cap = sh ? j->localCap : j->spanCap;
    if (stack.size() >= cap)
    {
       j->markDirty(s.y);
       return;
    }

    try {
       if (stack.size()==stack.capacity())
          stack.reserve(std::min(cap, std::max<size_t>(256, stack.capacity() * 2)));
       stack.push_back(s);
    } catch (...) {
       j->markDirty(s.y);
    }
}

void FloodWalker::addRun(int y, int a, int b) {
    filled += b - a + 1;
    if (a < minX)
       minX = a;
    if (b > maxX)
       maxX = b;
    if (y < minY)
       minY = y;
    if (y > maxY)
       maxY = y;
    push({y, a, b});
}

// takes pixels x1..x2 of row y; with other threads walking, only the bits this thread set are its own
void FloodWalker::claim(int y, int x1, int x2) {
    uint64_t *row = j->F + (size_t)(y - j->r0) * j->wpr;
    const int k1 = x1 >> 6, k2 = x2 >> 6;
    if (!sh)
    {
       if (k1==k2)
       {
          row[k1] |= floodBits(x1 & 63, x2 & 63);
       } else
       {
          row[k1] |= ~0ULL << (x1 & 63);
          for (int k = k1 + 1; k < k2; k++)
              row[k] = ~0ULL;
          row[k2] |= ~0ULL >> (63 - (x2 & 63));
       }
       addRun(y, x1, x2);
       return;
    }

    int runStart = -1;
    for (int k = k1; k <= k2; k++)
    {
        const int lo = (k==k1) ? (x1 & 63) : 0, hi = (k==k2) ? (x2 & 63) : 63;
        const uint64_t mask = floodBits(lo, hi);
        const uint64_t own = mask & ~floodAtom(row + k)->fetch_or(mask, std::memory_order_relaxed);
        int pos = lo;
        for (;;)
        {
            if (runStart >= 0)
            {
               const uint64_t gap = ~own & mask & (~0ULL << pos);
               if (!gap)
                  break;
               pos = floodLowBit(gap);
               addRun(y, runStart, (k << 6) + pos - 1);
               runStart = -1;
            } else
            {
               const uint64_t next = own & (~0ULL << pos);
               if (!next)
                  break;
               pos = floodLowBit(next);
               runStart = (k << 6) + pos;
            }
        }
    }
    if (runStart >= 0)
       addRun(y, runStart, x2);
}

// takes the run through pixel x, which must be available, up to the edges of its strip
void FloodWalker::fillAt(int y, int x) {
    const int w = j->p.w, sLo = x - x % j->stripW, sHi = std::min(w - 1, sLo + j->stripW - 1);
    const int k = x >> 6, b = x & 63, kLo = sLo >> 6, kHi = sHi >> 6;
    const uint64_t a = avail(y, k);
    if (!((a >> b) & 1))
       return;

    int x2, x1;
    const uint64_t up = (~a) >> b;
    if (up)
    {
       x2 = std::min(x + floodLowBit(up) - 1, sHi);
    } else
    {
       x2 = std::min((k << 6) + 63, sHi);
       for (int kk = k + 1; kk <= kHi; kk++)
       {
           const uint64_t aa = avail(y, kk);
           if (aa==~0ULL)
           {
              x2 = std::min((kk << 6) + 63, sHi);
              continue;
           }
           x2 = (kk << 6) + floodLowBit(~aa) - 1;
           break;
       }
    }

    const uint64_t dn = (~a) & ((1ULL << b) - 1);
    if (dn)
    {
       x1 = (k << 6) + floodHighBit(dn) + 1;
    } else
    {
       x1 = k << 6;
       for (int kk = k - 1; kk >= kLo; kk--)
       {
           const uint64_t aa = avail(y, kk);
           if (aa==~0ULL)
           {
              x1 = kk << 6;
              continue;
           }
           x1 = (kk << 6) + floodHighBit(~aa) + 1;
           break;
       }
    }

    claim(y, x1, x2);
    // the row goes on in the next strip: another thread may take it from there
    if (x2==sHi && sHi + 1 < w && ((avail(y, (sHi + 1) >> 6) >> ((sHi + 1) & 63)) & 1))
       push({y, sHi + 1, sHi});
    if (x1==sLo && sLo > 0 && ((avail(y, (sLo - 1) >> 6) >> ((sLo - 1) & 63)) & 1))
       push({y, sLo - 1, sLo - 2});
}

void FloodWalker::probeRow(int ny, int lo, int hi) {
    const int kFirst = lo >> 6, kEnd = hi >> 6;
    int k = kFirst;
    while (k <= kEnd)
    {
        const uint64_t c = avail(ny, k) & floodBits((k==kFirst) ? (lo & 63) : 0, (k==kEnd) ? (hi & 63) : 63);
        if (!c)
        {
           k++;
           continue;
        }
        fillAt(ny, (k << 6) + floodLowBit(c));
    }
}

void FloodWalker::process(const FloodSpan &s) {
    if (s.x2 < s.x1)
    {
       fillAt(s.y, s.x1);
       return;
    }

    const int e = (j->p.eightWay==1) ? 1 : 0;
    const int lo = std::max(0, s.x1 - e), hi = std::min(j->p.w - 1, s.x2 + e);
    if (s.y - 1 >= j->r0)
       probeRow(s.y - 1, lo, hi);
    if (s.y + 1 < j->r1)
       probeRow(s.y + 1, lo, hi);
}

// starts runs in row y wherever the probe words say a neighbour is filled
void FloodWalker::seedRow(int y, const uint64_t *probe) {
    for (int k = 0; k < j->wpr; k++)
    {
        if (!probe[k])
           continue;
        uint64_t c;
        while ((c = avail(y, k) & probe[k]))
            fillAt(y, (k << 6) + floodLowBit(c));
    }
}

// hands the oldest half of the stack, the widest part of the walk, to threads that ran dry
void FloodWalker::donate() {
    std::lock_guard<std::mutex> lk(sh->mx);
    const size_t half = std::min(stack.size() / 2, j->spanCap - std::min(j->spanCap, sh->pool.size()));
    if (!half)
       return;
    try {
       if (sh->pool.capacity() < sh->pool.size() + half)
          sh->pool.reserve(std::min(j->spanCap, std::max(sh->pool.size() + half, sh->pool.capacity() * 2)));
       sh->pool.insert(sh->pool.end(), stack.begin(), stack.begin() + half);
    } catch (...) {
       return;
    }
    stack.erase(stack.begin(), stack.begin() + half);
    sh->poolSize.store((int)sh->pool.size(), std::memory_order_relaxed);
    sh->cv.notify_one();
}

static void floodWorkerLoop(FloodWalker *w) {
    FloodShared *sh = w->sh;
    for (;;)
    {
        if (w->stack.empty())
        {
           std::unique_lock<std::mutex> lk(sh->mx);
           sh->idle++;
           sh->idleHint.store(sh->idle, std::memory_order_relaxed);
           while (sh->pool.empty() && !sh->done)
           {
               if (sh->idle==sh->workers)
               {
                  sh->done = true;
                  sh->cv.notify_all();
                  break;
               }
               sh->cv.wait(lk);
           }
           if (sh->pool.empty())
              break;

           sh->idle--;
           sh->idleHint.store(sh->idle, std::memory_order_relaxed);
           const size_t n = sh->pool.size(), take = std::min(w->j->localCap, std::max<size_t>(1, n / sh->workers));
           try {
              if (w->stack.capacity() < take)
                 w->stack.reserve(take);
              w->stack.insert(w->stack.end(), sh->pool.end() - take, sh->pool.end());
           } catch (...) {
              for (size_t i = n - take; i < n; i++)
                  w->j->markDirty(sh->pool[i].y);
           }
           sh->pool.resize(n - take);
           sh->poolSize.store((int)sh->pool.size(), std::memory_order_relaxed);
           // a donation wakes one thread; each one that leaves work behind wakes the next
           if (!sh->pool.empty() && sh->idle > 0)
              sh->cv.notify_one();
           continue;
        }

        const FloodSpan s = w->stack.back();
        w->stack.pop_back();
        w->process(s);
        // sharing a shallow stack costs more than it saves: the spans of a narrow region are cheap
        if (w->stack.size() >= 16 && sh->idleHint.load(std::memory_order_relaxed) > 0 && sh->poolSize.load(std::memory_order_relaxed)==0)
           w->donate();
    }
}

void FloodJob::setupPaint() {
    T = floodThreads();
    paintT = std::min(T, 32);
    wpr = (int)(((INT64)p.w + 63) >> 6);
    oldRGB = ((uint32_t)p.oldColor.r << 16) | ((uint32_t)p.oldColor.g << 8) | (uint32_t)p.oldColor.b;
    writeAlpha = (p.bpp==32 && p.keepAlpha==0) ? 1 : 0;
    defIndex = (p.alternateMode==3) ? 0.0f : p.prevCLRindex;
    // the exact fill paints a colour mixed beforehand; the replacement mixes per pixel like the tolerance fill
    const bool exactFill = p.exact && !p.replace;
    const int simpleMode = (p.opacity==1 && p.blendMode==0 && p.cartoonMode==0) ? 1 : 0;
    constPaint = (exactFill || simpleMode || p.cartoonMode==1) ? 1 : 0;
    const RGBAColor &c = (!exactFill && !simpleMode && p.cartoonMode==1) ? p.oldColor : p.newColor;
    constBGRA = (uint32_t)(unsigned char)c.b | ((uint32_t)(unsigned char)c.g << 8) | ((uint32_t)(unsigned char)c.r << 16) | ((uint32_t)(unsigned char)c.a << 24);
    wantIndex = (!constPaint && p.dynamicOpacity==1) ? 1 : 0;
    // the replacement measures the clicked colour too: its CIEDE2000 distance is not exactly 0
    seedByDistance = (p.replace && p.alternateMode==3) ? 1 : 0;
}

bool FloodJob::setup() {
    const INT64 w = p.w, h = p.h;
    setupPaint();
    // strips of whole words, so threads can take parts of a wide row
    stripW = (int)(((INT64)wpr + 1) << 6);
    if (T > 1)
       stripW = std::max(1024, (int)((((w + 4 * T - 1) / (4 * T)) + 63) & ~(INT64)63));

    // spans: a stack of up to spanCap, plus as many again shared between threads
    size_t fixedBytes = floodSpanReserve * sizeof(FloodSpan) * 2 + ((size_t)T << 16) + ((size_t)1 << 20);
    if (!p.exact)
       fixedBytes += ((size_t)1 << 19) * 8;
    if (wantIndex)
       fixedBytes += ((size_t)1 << floodIndexMemoBits) * 8;
    if (!constPaint)
       fixedBytes += (size_t)paintT * (((size_t)1 << floodPaintMemoBits) * 8);
    if (fixedBytes >= floodFillBudget)
       return false;

    // one band's maps are held at a time: a row costs its F and M words, its share of K and a
    // dirty bit; every band keeps its two edge rows, its pixel count and its bounds
    const size_t avail = floodFillBudget - fixedBytes;
    const size_t rowBytes = (size_t)wpr * 16 + ((size_t)wpr + 7) / 8 + 9;
    const size_t edgeBytes = (size_t)wpr * 16 + 64;
    size_t rows = avail / rowBytes;
    if (rows < (size_t)h)
    {
       for (int i = 0; i < 4 && rows > 0; i++)
       {
           const size_t nb = ((size_t)h + rows - 1) / rows;
           rows = (nb * edgeBytes < avail) ? (avail - nb * edgeBytes) / rowBytes : 0;
       }
       while (rows > 0 && rows * rowBytes + (((size_t)h + rows - 1) / rows) * edgeBytes > avail)
           rows--;
    }
    if (rows < 1)
       return false;

    bandRows = (int)std::min<size_t>(rows, (size_t)h);
    bands = (int)((h + bandRows - 1) / bandRows);
    // what the maps leave over goes to the span stacks
    const size_t used = (size_t)bandRows * rowBytes + ((bands > 1) ? (size_t)bands * edgeBytes : 0);
    spanCap = floodSpanReserve + (avail - std::min(avail, used)) / (sizeof(FloodSpan) * 2);
    if (floodSpanCapSet)
       spanCap = std::min(spanCap, floodSpanCapSet);
    localCap = std::max<size_t>(1, spanCap / T);
    try {
       bandCount.assign(bands, 0);
       bandBox.assign((size_t)bands * 4, 0);
       if (bands > 1)
       {
          edgeTop.assign((size_t)bands * wpr, 0);
          edgeBot.assign((size_t)bands * wpr, 0);
       }
    } catch (...) {
       return false;
    }

    const size_t mapWords = (size_t)bandRows * wpr;
    kWords = (mapWords + 63) >> 6;
    dirtyWords = ((size_t)bandRows + 63) >> 6;
    F = floodAlloc(mapWords);
    M = floodAlloc(mapWords);
    K = floodAlloc(kWords);
    dirty = floodAlloc(dirtyWords);
    if (wantIndex)
       indexMemo = floodAlloc((size_t)1 << floodIndexMemoBits);
    return F && M && K && dirty && setupColourDecisions() && (!wantIndex || indexMemo);
}

// readies the maps for band b, rows r0..r1-1
void FloodJob::beginBand(int b) {
    if (heldBand >= 0)
    {
       if (usedRow1 >= usedRow0)
          memset(F + (size_t)(usedRow0 - r0) * wpr, 0, (size_t)(usedRow1 - usedRow0 + 1) * wpr * 8);
       memset(K, 0, kWords * 8);
       memset(dirty, 0, dirtyWords * 8);
    }
    anyDirty = 0;
    r0 = b * bandRows;
    r1 = std::min(p.h, r0 + bandRows);
    usedRow0 = r0;
    usedRow1 = r1 - 1;
    heldBand = b;
}

bool FloodJob::walkParallel(FloodWalker &w) {
    FloodShared sh;
    std::vector<FloodWalker> crew;
    std::vector<std::thread> threads;
    try {
       crew.reserve(T);
       threads.reserve(T);
       for (int i = 0; i < T; i++)
           crew.emplace_back(this, &sh);
    } catch (...) {
       return false;
    }

    sh.pool.swap(w.stack);
    sh.poolSize = (int)sh.pool.size();
    sh.workers = T;
    for (int i = 1; i < T; i++)
    {
        try {
           threads.emplace_back(floodWorkerLoop, &crew[i]);
        } catch (...) {
           std::lock_guard<std::mutex> lk(sh.mx);
           sh.workers--;
           if (sh.idle==sh.workers && sh.pool.empty())
           {
              sh.done = true;
              sh.cv.notify_all();
           }
        }
    }
    floodWorkerLoop(&crew[0]);
    for (auto &t : threads)
        t.join();

    for (auto &c : crew)
    {
        w.filled += c.filled;
        w.minX = std::min(w.minX, c.minX);
        w.minY = std::min(w.minY, c.minY);
        w.maxX = std::max(w.maxX, c.maxX);
        w.maxY = std::max(w.maxY, c.maxY);
    }
    return true;
}

void FloodJob::runWalk(FloodWalker &w) {
    while (!w.stack.empty())
    {
        if (T > 1 && w.filled >= floodParallelMin && w.stack.size() >= (size_t)T && walkParallel(w))
           return;
        const FloodSpan s = w.stack.back();
        w.stack.pop_back();
        w.process(s);
    }
}

// probes the rows beside spans that were dropped while the stack was full
void FloodJob::rescan() {
    std::vector<uint64_t> probe;
    try {
       probe.assign(wpr, 0);
    } catch (...) {
       failed = true;
       return;
    }

    const int e = (p.eightWay==1) ? 1 : 0;
    while (anyDirty.exchange(0))
    {
        FloodWalker w(this, NULL);
        for (size_t dw = 0; dw < dirtyWords; dw++)
        {
            for (uint64_t bits = floodAtom(dirty + dw)->exchange(0); bits; bits &= bits - 1)
            {
                const int y = r0 + (int)(dw << 6) + floodLowBit(bits);
                const uint64_t *self = F + (size_t)(y - r0) * wpr;
                const uint64_t *up = (y > r0) ? self - wpr : NULL;
                const uint64_t *dn = (y < r1 - 1) ? self + wpr : NULL;
                for (int k = 0; k < wpr; k++)
                {
                    uint64_t v = (up ? up[k] : 0) | (dn ? dn[k] : 0);
                    const uint64_t vl = (up && k > 0 ? up[k - 1] : 0) | (dn && k > 0 ? dn[k - 1] : 0);
                    const uint64_t vr = (up && k + 1 < wpr ? up[k + 1] : 0) | (dn && k + 1 < wpr ? dn[k + 1] : 0);
                    if (e)
                       v |= (v << 1) | (v >> 1) | (vl >> 63) | (vr << 63);
                    // a seed dropped at a strip edge leaves a filled pixel beside an open one in its row
                    v |= (self[k] << 1) | (self[k] >> 1) | (k > 0 ? self[k - 1] >> 63 : 0) | (k + 1 < wpr ? self[k + 1] << 63 : 0);
                    probe[k] = v;
                }
                w.seedRow(y, probe.data());
                runWalk(w);
            }
        }
        count += w.filled;
        bandCount[heldBand] += w.filled;
        int *bb = &bandBox[(size_t)heldBand * 4];
        if (w.filled > 0)
        {
           bb[0] = std::min(bb[0], w.minX);  bb[1] = std::min(bb[1], w.minY);
           bb[2] = std::max(bb[2], w.maxX);  bb[3] = std::max(bb[3], w.maxY);
        }
    }
}

// whether the fill continues from edge, a filled row of one band, into row y of the next band,
// past the pixels known to be filled there already
bool FloodJob::edgeSeeds(int y, const uint64_t *edge, const uint64_t *known) {
    const int e = (p.eightWay==1) ? 1 : 0;
    for (int k = 0; k < wpr; k++)
    {
        uint64_t v = edge[k];
        if (e)
           v |= (v << 1) | (v >> 1) | (k > 0 ? edge[k - 1] >> 63 : 0) | (k + 1 < wpr ? edge[k + 1] << 63 : 0);
        v &= ~known[k];
        if (v && (testWord(y, k) & v))
           return true;
    }
    return false;
}

void FloodJob::walkBand(int b) {
    beginBand(b);
    FloodWalker w(this, NULL);
    if (p.sy >= r0 && p.sy < r1 && ((w.avail(p.sy, p.sx >> 6) >> (p.sx & 63)) & 1))
       w.fillAt(p.sy, p.sx);

    if (bands > 1)
    {
       const int e = (p.eightWay==1) ? 1 : 0;
       std::vector<uint64_t> probe;
       try {
          probe.assign(wpr, 0);
       } catch (...) {
          failed = true;
          return;
       }
       for (int side = 0; side < 2; side++)
       {
           const int nb = (side==0) ? b - 1 : b + 1;
           if (nb < 0 || nb >= bands)
              continue;
           const uint64_t *edge = (side==0) ? &edgeBot[(size_t)nb * wpr] : &edgeTop[(size_t)nb * wpr];
           for (int k = 0; k < wpr; k++)
           {
               uint64_t v = edge[k];
               if (e)
                  v |= (v << 1) | (v >> 1) | (k > 0 ? edge[k - 1] >> 63 : 0) | (k + 1 < wpr ? edge[k + 1] << 63 : 0);
               probe[k] = v;
           }
           w.seedRow((side==0) ? r0 : r1 - 1, probe.data());
       }
    }

    runWalk(w);
    bandCount[b] = w.filled;
    int *bb = &bandBox[(size_t)b * 4];
    bb[0] = w.minX;  bb[1] = w.minY;  bb[2] = w.maxX;  bb[3] = w.maxY;
    count += w.filled;
    if (anyDirty.load())
       rescan();

    // the rows F holds, for the next beginBand()
    usedRow0 = bb[1];
    usedRow1 = (bandCount[b] > 0) ? bb[3] : bb[1] - 1;
}

// returns the number of pixels the fill takes: 0 for none, -1 when memory ran out
INT64 FloodJob::find() {
    if (p.w < 1 || p.h < 1 || p.bpx < 3 || p.sx < 0 || p.sx >= p.w || p.sy < 0 || p.sy >= p.h)
       return 0;
    if (p.replace)
    {
       // the matches are counted and bounded; a map of them, when the budget has room for it,
       // spares paint() a second test
       sel.init(p.useSelArea);
       if (!setupReplace())
          return -1;
       const size_t words = (size_t)p.h * wpr;
       size_t fixedBytes = ((size_t)1 << 20) + (size_t)paintT * (((size_t)1 << floodPaintMemoBits) * 8);
       if (!p.exact)
          fixedBytes += ((size_t)1 << 19) * 8;
       if (wantIndex)
          fixedBytes += ((size_t)1 << floodIndexMemoBits) * 8;
       if (fixedBytes + words * 8 <= floodFillBudget)
          F = floodAlloc(words);
       if (!F)
       {
          rowHits = floodAlloc(((size_t)p.h + 63) >> 6);
          if (!rowHits)
             return -1;
       }
       count = replaceScan(false);
       return count;
    }
    if (p.exact && p.oldColor.r==p.newColor.r && p.oldColor.g==p.newColor.g && p.oldColor.b==p.newColor.b)
       return 0;
    if (p.exact)
       p.eightWay = 0;   // the exact fill is 4-connected

    sel.init(p.useSelArea);
    if (sel.kind && ((sel.masked(p.sy, p.sx & ~63, std::min(64, p.w - (p.sx & ~63))) >> (p.sx & 63)) & 1))
       return 0;   // a click on a masked pixel fills nothing

    if (!setup())
       return -1;

    count = 0;
    if (bands==1)
    {
       walkBand(0);
    } else
    {
       // bands hand seeds across their edges until none can reach further
       std::vector<char> bandDirty(bands, 0);
       bandDirty[p.sy / bandRows] = 1;
       for (int pending = 1; pending > 0 && !failed; )
       {
           for (int b = 0; b < bands && !failed; b++)
           {
               if (!bandDirty[b])
                  continue;
               bandDirty[b] = 0;
               pending--;
               count = 0;
               walkBand(b);
               const uint64_t *top = F, *bot = F + (size_t)(r1 - 1 - r0) * wpr;
               memcpy(&edgeTop[(size_t)b * wpr], top, (size_t)wpr * 8);
               memcpy(&edgeBot[(size_t)b * wpr], bot, (size_t)wpr * 8);
               if (b > 0 && !bandDirty[b - 1] && edgeSeeds(r0 - 1, top, &edgeBot[(size_t)(b - 1) * wpr]))
               {
                  bandDirty[b - 1] = 1;
                  pending++;
               }
               if (b < bands - 1 && !bandDirty[b + 1] && edgeSeeds(r1, bot, &edgeTop[(size_t)(b + 1) * wpr]))
               {
                  bandDirty[b + 1] = 1;
                  pending++;
               }
           }
       }
       count = 0;
       for (int b = 0; b < bands; b++)
           count += bandCount[b];
    }
    if (failed)
       return -1;

    boxX1 = boxY1 = INT_MAX;
    boxX2 = boxY2 = -1;
    for (int b = 0; b < bands; b++)
    {
        if (bandCount[b] <= 0)
           continue;
        const int *bb = &bandBox[(size_t)b * 4];
        boxX1 = std::min(boxX1, bb[0]);  boxY1 = std::min(boxY1, bb[1]);
        boxX2 = std::max(boxX2, bb[2]);  boxY2 = std::max(boxY2, bb[3]);
    }
    if (bands==1)
    {
       // the paint needs only F
       floodRelease(M);
       floodRelease(K);
       floodRelease(colourTable);
       floodRelease(grayRanges);
    }
    return count;
}

void FloodJob::paintRows(int y1, int y2, int x1, int x2) {
    const int k1 = x1 >> 6, k2 = x2 >> 6;
    std::atomic<int> nextRow(y1);
    const int chunk = std::max(1, 4096 / (k2 - k1 + 1));
    auto body = [&]() {
        FloodPaintMemo memo;
        FloodPaintMemo *mp = NULL;
        if (!constPaint)
        {
           try {
              memo.init(floodPaintMemoBits);
              mp = &memo;
           } catch (...) {
              mp = NULL;
           }
        }
        for (;;)
        {
            const int ya = nextRow.fetch_add(chunk, std::memory_order_relaxed);
            if (ya > y2)
               break;
            const int yb = std::min(y2, ya + chunk - 1);
            for (int y = ya; y <= yb; y++)
            {
                const uint64_t *row = F + (size_t)(y - r0) * wpr;
                unsigned char *px = p.img + (INT64)y * p.stride;
                int open = -1;   // start of a run that reaches the end of the previous word
                for (int k = k1; k <= k2; k++)
                {
                    uint64_t v = row[k];
                    if (open >= 0)
                    {
                       if (v==~0ULL)
                          continue;
                       const int e = floodLowBit(~v);
                       paintRun(px, open, (k << 6) + e - 1, mp);
                       open = -1;
                       v &= ~0ULL << e;
                    }
                    while (v)
                    {
                        const int s = floodLowBit(v);
                        const uint64_t gap = ~v & (~0ULL << s);
                        if (!gap)
                        {
                           open = (k << 6) + s;
                           break;
                        }
                        const int e = floodLowBit(gap);
                        paintRun(px, (k << 6) + s, (k << 6) + e - 1, mp);
                        v &= ~0ULL << e;
                    }
                }
                if (open >= 0)
                   paintRun(px, open, std::min(p.w - 1, (k2 << 6) + 63), mp);
                if (mp && !mp->worthKeeping())
                   mp = NULL;
            }
        }
    };

    const INT64 rows = (INT64)y2 - y1 + 1;
    const int n = (paintT > 1 && rows > 1 && count >= floodParallelMin) ? (int)std::min<INT64>(paintT, rows) : 1;
    std::vector<std::thread> threads;
    for (int i = 1; i < n; i++)
    {
        try {
           threads.emplace_back(body);
        } catch (...) {
           break;
        }
    }
    body();
    for (auto &t : threads)
        t.join();
}

INT64 FloodJob::paint() {
    if (p.replace)
    {
       if (!F)
          return replaceScan(true);
       r0 = 0;
       paintRows(boxY1, boxY2, boxX1, boxX2);
       return count;
    }

    INT64 painted = 0;
    const int first = heldBand;
    for (int i = -1; i < bands; i++)
    {
        const int b = (i < 0) ? first : i;
        if (b < 0 || (i >= 0 && b==first) || bandCount[b] <= 0)
           continue;
        if (heldBand!=b)
        {
           count = 0;
           walkBand(b);
           if (failed)
              return -1;
        }
        const int *bb = &bandBox[(size_t)b * 4];
        paintRows(bb[1], bb[3], bb[0], bb[2]);
        painted += bandCount[b];
    }
    count = painted;
    return painted;
}

bool FloodJob::setupReplace() {
    setupPaint();
    if (wantIndex)
       indexMemo = floodAlloc((size_t)1 << floodIndexMemoBits);
    return setupColourDecisions() && (!wantIndex || indexMemo);
}

// "Replace similar colours anywhere": every pixel the selection leaves open is tested on its own.
// Without paintIt the matches are counted, bounded and kept in F, or their rows marked in rowHits
// when F did not fit; with it, they are painted, only in the marked rows when a count came first.
INT64 FloodJob::replaceScan(bool paintIt) {
    int y1 = 0, y2 = p.h - 1, x1 = 0, x2 = p.w - 1;
    if (paintIt && rowHits)
    {
       y1 = boxY1;  y2 = boxY2;
       x1 = boxX1;  x2 = boxX2;
    } else if (sel.kind >= 2 && !sel.inv)
    {
       // outside its box the selection leaves nothing open
       y1 = std::max(y1, sel.by1);  y2 = std::min(y2, sel.by2);
       x1 = std::max(x1, sel.bx1);  x2 = std::min(x2, sel.bx2);
    }
    if (!paintIt)
    {
       boxX1 = boxY1 = INT_MAX;
       boxX2 = boxY2 = -1;
    }
    if (y1 > y2 || x1 > x2)
       return 0;

    const int k1 = x1 >> 6, k2 = x2 >> 6;
    const bool onlyHits = paintIt && rowHits;
    std::atomic<int> nextRow(y1);
    std::atomic<INT64> total(0);
    std::mutex boxLock;
    const int chunk = std::max(1, 4096 / (k2 - k1 + 1));
    auto body = [&]() {
        FloodPaintMemo memo;
        FloodPaintMemo *mp = NULL;
        if (paintIt && !constPaint)
        {
           try {
              memo.init(floodPaintMemoBits);
              mp = &memo;
           } catch (...) {
              mp = NULL;
           }
        }

        INT64 n = 0;
        int lx1 = INT_MAX, ly1 = INT_MAX, lx2 = -1, ly2 = -1;
        for (;;)
        {
            const int ya = nextRow.fetch_add(chunk, std::memory_order_relaxed);
            if (ya > y2)
               break;
            const int yb = std::min(y2, ya + chunk - 1);
            for (int y = ya; y <= yb; y++)
            {
                if (onlyHits && !((rowHits[y >> 6] >> (y & 63)) & 1))
                   continue;

                unsigned char *row = p.img + (INT64)y * p.stride;
                bool hit = false;
                for (int k = k1; k <= k2; k++)
                {
                    uint64_t m = testWord(y, k);
                    if (!m)
                       continue;

                    hit = true;
                    if (!paintIt && F)
                       F[(size_t)y * wpr + k] = m;
                    lx1 = std::min(lx1, (k << 6) + floodLowBit(m));
                    lx2 = std::max(lx2, (k << 6) + floodHighBit(m));
                    while (m)
                    {
                        const int s = floodLowBit(m);
                        const uint64_t gap = ~m & (~0ULL << s);
                        const int e = gap ? floodLowBit(gap) : 64;
                        if (paintIt)
                           paintRun(row, (k << 6) + s, (k << 6) + e - 1, mp);
                        n += e - s;
                        m = (e < 64) ? m & (~0ULL << e) : 0;
                    }
                }
                if (mp && !mp->worthKeeping())
                   mp = NULL;
                if (hit)
                {
                   ly1 = std::min(ly1, y);
                   ly2 = std::max(ly2, y);
                   if (!paintIt && rowHits)
                      floodAtom(rowHits + (y >> 6))->fetch_or(1ULL << (y & 63), std::memory_order_relaxed);
                }
            }
        }

        total.fetch_add(n, std::memory_order_relaxed);
        if (!paintIt && n > 0)
        {
           std::lock_guard<std::mutex> lk(boxLock);
           boxX1 = std::min(boxX1, lx1);  boxY1 = std::min(boxY1, ly1);
           boxX2 = std::max(boxX2, lx2);  boxY2 = std::max(boxY2, ly2);
        }
    };

    const INT64 rows = (INT64)y2 - y1 + 1;
    const INT64 area = rows * (k2 - k1 + 1) * 64;
    const int threadsWanted = (paintT > 1 && rows > 1 && area >= floodParallelMin) ? (int)std::min<INT64>(paintT, rows) : 1;
    std::vector<std::thread> threads;
    for (int i = 1; i < threadsWanted; i++)
    {
        try {
           threads.emplace_back(body);
        } catch (...) {
           break;
        }
    }
    body();
    for (auto &t : threads)
        t.join();
    return total.load();
}

INT64 FloodJob::replaceAll() {
    if (p.w < 1 || p.h < 1 || p.bpx < 3)
       return 0;

    sel.init(p.useSelArea);
    if (!setupReplace())
       return -1;
    return replaceScan(true);
}

static FloodJob *floodPending = NULL;

static void floodDiscardPending() {
    delete floodPending;
    floodPending = NULL;
}

static int floodClampCount(INT64 r) {
    return (r > INT_MAX) ? INT_MAX : (int)r;
}

static int floodFillRun(const FloodParams &q) {
    fnOutputDebug("floodFillRun(): exact=" + std::to_string(q.exact) + " sel=" + std::to_string(q.useSelArea) + " blendMode=" + std::to_string(q.blendMode));
    FloodJob *job = new (std::nothrow) FloodJob(q);
    if (!job)
       return 0;

    INT64 r = job->find();
    if (r > 0)
       r = job->paint();
    fnOutputDebug("floodFillRun(): pixels=" + std::to_string(r) + " bands=" + std::to_string(job->bands) + " threads=" + std::to_string(job->T));
    delete job;
    return (r > 0) ? floodClampCount(r) : 0;
}

// "Replace similar colours anywhere"
int ReplaceGivenColor(const FloodParams &q) {
    fnOutputDebug("ReplaceGivenColor: o=" + std::to_string(q.opacity) + " ; t=" + std::to_string(q.tolerance) + " ; b=" + std::to_string(q.blendMode) + " ; c=" + std::to_string(q.cartoonMode));
    FloodJob *job = new (std::nothrow) FloodJob(q);
    if (!job)
       return 0;

    const INT64 r = job->replaceAll();
    delete job;
    return (r > 0) ? floodClampCount(r) : 0;
}

// The setup the flood fill entry points share. Returns 0 when the seed is outside the image,
// 1 for "replace similar colours anywhere", 2 for a tolerance fill and 3 for an exact fill.
static int floodFillPrepare(FloodParams &q, unsigned char *imageData, int modus, int w, int h, int x, int y, int newColor, int tolerance, int fillOpacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay, int linearGamma, int flipLayers, int Stride, int bpp, int useSelArea, int invertSel, int keepAlpha) {
    if ((x < 0) || (x >= w) || (y < 0) || (y >= h))  // out of bounds
       return 0;

    imgSel.inverted = invertSel;
    float toleranza = (alternateMode==3) ? (float)tolerance/10.0 + 1 : tolerance;
    INT64 oc = CalcPixOffset(x, y, Stride, bpp);
    int aB = (bpp==32) ? imageData[oc + 3] : 255;
    int rB = imageData[oc + 2];
    int gB = imageData[oc + 1];
    int bB = imageData[oc];
    RGBAColor prevColor = {bB, gB, rB, aB};
    float prevCLRindex = RGBtoGray(rB, gB, bB, alternateMode);

    float *nC = q.nC;
    nC[0] = (newColor >> 24) & 0xFF;
    nC[1] = (newColor >> 16) & 0xFF;
    nC[2] = (newColor >> 8) & 0xFF;
    nC[3] = newColor & 0xFF;

    auto LabA = RGBtoLAB(rB, gB, bB);
    nC[4] = LabA[0];
    nC[5] = LabA[1];
    nC[6] = LabA[2];
    RGBAColor newColorI = {(int)nC[3], (int)nC[2], (int)nC[1], (int)nC[0]};

    float opacity = fillOpacity / 255.0f;
    if (modus!=1 && toleranza<=2 && (opacity<1 || blendMode>0))
       newColorI = mixColorsFloodFill(prevColor, newColorI, opacity, 0, blendMode, 0, 0, 0, 0, linearGamma, flipLayers);

    q.img = imageData;
    q.w = w;
    q.h = h;
    q.stride = Stride;
    q.bpp = bpp;
    q.bpx = bpp / 8;
    q.sx = x;
    q.sy = y;
    q.eightWay = eightWay;
    q.replace = (modus==1) ? 1 : 0;
    q.exact = q.replace ? ((alternateMode!=3 && toleranza<1) ? 1 : 0) : ((toleranza>2) ? 0 : 1);
    q.newColor = newColorI;
    q.oldColor = prevColor;
    q.tolerance = toleranza;
    q.prevCLRindex = prevCLRindex;
    q.opacity = opacity;
    q.dynamicOpacity = dynamicOpacity;
    q.blendMode = blendMode;
    q.cartoonMode = cartoonMode;
    q.alternateMode = alternateMode;
    q.linearGamma = linearGamma;
    q.flipLayers = flipLayers;
    q.keepAlpha = keepAlpha;
    q.useSelArea = useSelArea;
    return (modus==1) ? 1 : (q.exact ? 3 : 2);
}

DLL_API int DLL_CALLCONV FloodFillWrapper(unsigned char *imageData, int modus, int w, int h, int x, int y, int newColor, int tolerance, int fillOpacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay, int linearGamma, int flipLayers, int Stride, int bpp, int useSelArea, int invertSel, int keepAlpha) {
    FloodParams q;
    const int kind = floodFillPrepare(q, imageData, modus, w, h, x, y, newColor, tolerance, fillOpacity, dynamicOpacity, blendMode, cartoonMode, alternateMode, eightWay, linearGamma, flipLayers, Stride, bpp, useSelArea, invertSel, keepAlpha);
    if (kind==1)
       return ReplaceGivenColor(q);

    return (kind > 1) ? floodFillRun(q) : 0;
}

// A flood fill or colour replacement in two steps, so the caller can record an undo level of just
// the area that changes. FloodFillFindRegion() keeps the pixels to paint and returns their count,
// with their bounds in bounds[0..3] = x1, y1, x2, y2 (inclusive, rows as in imageData);
// FloodFillPaintRegion() paints them. A replacement whose map of matches did not fit the budget
// tests the pixels again when it paints, so the image and the selection must stay as they were.
DLL_API int DLL_CALLCONV FloodFillFindRegion(unsigned char *imageData, int modus, int w, int h, int x, int y, int newColor, int tolerance, int fillOpacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay, int linearGamma, int flipLayers, int Stride, int bpp, int useSelArea, int invertSel, int keepAlpha, int *bounds) {
    floodDiscardPending();
    FloodParams q;
    const int kind = floodFillPrepare(q, imageData, modus, w, h, x, y, newColor, tolerance, fillOpacity, dynamicOpacity, blendMode, cartoonMode, alternateMode, eightWay, linearGamma, flipLayers, Stride, bpp, useSelArea, invertSel, keepAlpha);
    if (kind==0)
       return 0;

    FloodJob *job = new (std::nothrow) FloodJob(q);
    if (!job)
       return 0;

    const INT64 r = job->find();
    if (r <= 0)
    {
       delete job;
       return 0;
    }

    if (bounds)
    {
       bounds[0] = job->boxX1;
       bounds[1] = job->boxY1;
       bounds[2] = job->boxX2;
       bounds[3] = job->boxY2;
    }
    floodPending = job;
    return floodClampCount(r);
}

DLL_API int DLL_CALLCONV FloodFillPaintRegion(unsigned char *imageData, int w, int h, int Stride, int bpp) {
    FloodJob *job = floodPending;
    floodPending = NULL;
    if (!job)
       return 0;

    INT64 r = 0;
    if (job->p.img==imageData && job->p.w==w && job->p.h==h && job->p.stride==Stride && job->p.bpp==bpp)
       r = job->paint();
    delete job;
    return (r > 0) ? floodClampCount(r) : 0;
}

DLL_API int DLL_CALLCONV FloodFillDiscardRegion() {
    floodDiscardPending();
    return 1;
}

#endif // QPV_FLOOD_FILL_H
