// qpv-main.cpp : Définit les fonctions exportées de la DLL.

#define GDIPVER 0x110
#include "pch.h"
#include "framework.h"
#include <wchar.h>
#include "omp.h"
#include "math.h"
#include "windows.h"
#include <string>
#include <vector>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <stack>
#include <map>
#include <unordered_set>
#include <unordered_map>
#include <list>
#include <array>
#include <cstdint>
#include <cstdio>
#include <chrono>   // steady_clock, for the duplicate sweep's time budget
#include <new>      // std::bad_alloc, thrown by the candidate-set allocation
#include <numeric>
#include <algorithm>
#include <emmintrin.h> // SSE2 intrinsics for CalculateNewBlendModes
#if defined(_MSC_VER)
#include <intrin.h>
#endif
#include <d2d1.h>
#include <d2d1_3.h>
#include <wincodec.h>
#include <shlwapi.h>
#include "Tchar.h"
#define GDIPVER 0x110
#include <gdiplus.h>
#include <gdiplusflat.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <locale>
#include <codecvt>
#define cimg_use_openmp 1
#include "includes\CImg-3.4.3\CImg.h"
// #include <opencv2/opencv.hpp>
#include "includes\opencv2\opencv.hpp"
#include "includes\pdfium\fpdfview.h"
#include "includes\pdfium\fpdf_text.h"
#include "includes\pdfium\fpdf_annot.h"
#include "includes\pdfium\fpdf_doc.h"
#include "includes\pdfium\fpdf_edit.h"
using namespace std;
using namespace cimg_library;
#define DLL_API extern "C" __declspec(dllexport)
#define DLL_CALLCONV __stdcall

const double M_PI = 3.14159265358979323846;  // PI

int debugInfos = 0;
void fnOutputDebug(std::string input) {
    if (debugInfos!=1)
       return;

    std::string line = "qpv: " + input;
    OutputDebugStringA(line.c_str());
}

#if defined(_MSC_VER)
  #define QPV_FORCEINLINE __forceinline
#else
  #define QPV_FORCEINLINE inline __attribute__((always_inline))
#endif

IWICImagingFactory *m_pIWICFactory;
ID2D1Factory       *pD2D1Factory;

inline bool inRange(const float &low, const float &high, const float &x) {
    return (low <= x && x <= high);
}

inline bool inRange(const int &low, const int &high, const int &x) {
    return (low <= x && x <= high);
}

int inline weighTwoValues(const float &A, const float &B, const float &w) {
    if (w >= 1.0f)
       return A;
    else if (w <= 0.0f)
       return B;
    else
       return (w * (A - B) + B);
}

float inline weighTwoValues(const float &A, const float &B, const float &w, int &r) {
    if (w >= 1)
       return A;
    else if (w <= 0)
       return B;
    else
       return (w * (A - B) + B);
}

static inline unsigned int qpvThreadRand(unsigned int &state) {
    // xorshift32 PRNG; used instead of rand() inside OpenMP loops, where
    // srand() only seeds the main thread and workers repeat the same sequence
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

static unsigned short gamma_to_linear[256];
static unsigned char linear_to_gamma[32769];
static float char_to_float[256];
static float char_to_floatGamma[256];
static float char_to_grayRfloat[256];
static float char_to_grayGfloat[256];
static float char_to_grayBfloat[256];
static float int_to_float[65536];
static int int_to_char[65536];
static int char_to_int[256];
static int int_to_grayRi[65536];
static int int_to_grayGi[65536];
static int int_to_grayBi[65536];
static int linear_to_gammaInt16[65536];
static int gamma_to_linearInt16[65536];

// read by CalculateNewBlendModes() and the colour adjust; initialized in initWICnow
static unsigned char blend_degamma_lut[65536]; // maps fixed16 [0..65535] -> degamma'd byte [0..255]

static double LUT_X_R[256];
static double LUT_X_G[256];
static double LUT_X_B[256];
static double LUT_Y_R[256];
static double LUT_Y_G[256];
static double LUT_Y_B[256];
static double LUT_Z_R[256];
static double LUT_Z_G[256];
static double LUT_Z_B[256];

// CalculateNewBlendModes() and its tables; initWICnow() fills them through initBlendLUTs()
#include "blend-modes.h"

// the tables the pixel code reads; initWICnow() fills them once
static void initColorLUTs() {
    // source https://www.teamten.com/lawrence/graphics/gamma/
    static const float GAMMA = 2.1;
    int result;
    for (int i = 0; i < 32769; i++)
    {
        result = (int)(pow(i/32768.0, 1/GAMMA)*255.0 + 0.5);
        linear_to_gamma[i] = (unsigned char)result;
    }

    for (int i = 0; i < 256; i++)
    {
        char_to_float[i] = i/255.0f;
        result = (int)(pow(char_to_float[i], GAMMA)*32768.0f + 0.5f);
        gamma_to_linear[i] = (unsigned short)result;
        char_to_grayRfloat[i] = i*0.299701f;
        char_to_grayGfloat[i] = i*0.587130f;
        char_to_grayBfloat[i] = i*0.114180f;
        char_to_int[i] = char_to_float[i] * 65535.0f;
        char_to_floatGamma[i] = pow(char_to_float[i], GAMMA);

        double val = char_to_float[i];
        if (val > 0.0404482362771076)
            val = pow((val + 0.055)/1.055, 2.4);
        else
            val = val / 12.92;

        double val100 = val * 100.0;
        
        LUT_X_R[i] = val100 * 0.4123955889674142161 / 95.047;
        LUT_X_G[i] = val100 * 0.3575834307637148171 / 95.047;
        LUT_X_B[i] = val100 * 0.1804926473817015735 / 95.047;

        LUT_Y_R[i] = val100 * 0.2125862307855955516 / 100.000;
        LUT_Y_G[i] = val100 * 0.7151703037034108499 / 100.000;
        LUT_Y_B[i] = val100 * 0.07220049864333622685 / 100.000;

        LUT_Z_R[i] = val100 * 0.01929721549174694484 / 108.883;
        LUT_Z_G[i] = val100 * 0.1191838645808485318 / 108.883;
        LUT_Z_B[i] = val100 * 0.9504971251315797660 / 108.883;
    }

    for (int i = 0; i < 65536; i++)
    {
        int_to_float[i] = (float)i/65535.0f;
        int_to_char[i] = int_to_float[i] * 255.0f;
        int_to_grayRi[i] = i*0.299701f;
        int_to_grayGi[i] = i*0.587130f;
        int_to_grayBi[i] = i*0.114180f;

        result = (int)(pow(int_to_float[i], 1.0f/GAMMA)*65535.0f + 0.5f);
        linear_to_gammaInt16[i] = result;
        result = (int)(pow(int_to_float[i], GAMMA)*65535.0f + 0.5f);
        gamma_to_linearInt16[i] = result;
    }

    // Initialize LUTs for CalculateNewBlendModes
    static const float invGAMMA = 1.0f / GAMMA;
    for (int i = 0; i < 65536; i++)
    {
        float v = (float)i / 65535.0f;
        blend_degamma_lut[i] = (unsigned char)(pow(v, invGAMMA) * 255.0f + 0.5f);
    }
}

DLL_API int DLL_CALLCONV initWICnow(UINT modus, int threadIDu) {
    debugInfos = modus;
    HRESULT hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_MULTI_THREADED, &pD2D1Factory);

    // WICImagingFactory2 is unavailable on Windows 7 without the Platform Update,
    // so the choice must be made at runtime, not via _WIN32_WINNT
    hr = CoCreateInstance(CLSID_WICImagingFactory2, NULL, CLSCTX_INPROC_SERVER,
                         IID_PPV_ARGS(&m_pIWICFactory));
    if (FAILED(hr))
        hr = CoCreateInstance(CLSID_WICImagingFactory1, NULL, CLSCTX_INPROC_SERVER,
                             IID_PPV_ARGS(&m_pIWICFactory));


    FPDF_LIBRARY_CONFIG config;
    config.version = 2;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    FPDF_InitLibraryWithConfig(&config);

    initColorLUTs();
    initBlendLUTs();

    return (SUCCEEDED(hr)) ? 1 : 0;
}

int inline brightMathsInt16(int i, float fintensity) {
    return clamp((int)(i + (float)i * fintensity), 0, 65535);
}

int inline contraMathsInt16(int i, float fintensity, float deviation) {
    return clamp((int)(floor(fintensity * (i - 32768.0f)) + deviation), 0, 65535);
}

// The duplicate-identification pipeline used to sit right here, between ColorizeGrayImage()
// and SafeRelease(): the Hamming/MSD sweep, the whole-scan cursor, the threshold filter and
// grouping, the candidate query engine, hash generation and the DCT that pHash is built on.
// It is a file of its own now. Still #included rather than compiled separately - it shares
// fnOutputDebug(), the DLL_API / QPV_FORCEINLINE macros and M_PI with this translation unit,
// and it brings in sqlite-dynamic.h, whose binding is static and has to be the same one
// dupes-pixels.h uses further down.
#include "dupes-search.h"
// The native WH_CALLWNDPROC procedure that feeds the script's menu machinery
// [see the header]. #included like the rest: it uses DLL_API / DLL_CALLCONV.
#include "callwndproc-hook.h"

std::string WideCharToString(const wchar_t* inwstr) {
    if (!inwstr)
       return "";

    std::wstring wstr(inwstr);
    std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
    return converter.to_bytes(wstr);
}

inline INT64 CalcPixOffset(const int &x, const int &y, const int &Stride, const int &bitsPerPixel) {
    return (INT64)y * Stride + (INT64)x * (bitsPerPixel / 8);
}

// the selection: its state, the polygon masks and clipMaskFilter(), which every effect below
// and flood-fill.h clip through
#include "selection-mask.h"

DLL_API int DLL_CALLCONV SetBitmapAsAlphaChannel(unsigned char *imageData, unsigned char *maskData, int w, int h, int Stride, int bpp, int invert, int replaceAlpha, int whichChannel) {
/*
pBitmap and pBitmapMask must be the same width and height
and in 32-ARGB format: PXF32ARGB - 0x26200A.

The alpha channel will be applied directly on the pBitmap provided.

For best results, pBitmapMask should be grayscale.
*/
    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        for (int x = 0; x < w; x++)
        {
            unsigned char alpha, alpha2;
            INT64 px = ky + (INT64)x * bpc;
            if (whichChannel==2)
               alpha = maskData[px + 1]; // green
            else if (whichChannel==3)
               alpha = maskData[px];     // blue
            else if (whichChannel==4)
               alpha = maskData[px + 3]; // alpha
            else
               alpha = maskData[px + 2]; // red

            if (replaceAlpha!=1)
            {
               if (invert == 1)
                  alpha = 255 - alpha;
               alpha2 = min(alpha, imageData[px + 3]);    // handles bitmaps that already have alpha
            } else {
               alpha2 = (invert == 1) ? 255 - alpha : alpha;
            }

            imageData[px + 3] = alpha2;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV SetColorAlphaChannel(int *imageData, int w, int h, int newColor, int invert) {
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * w;
        for (int x = 0; x < w; x++)
        {
            INT64 px = x + ky;
            unsigned char alpha1 = (imageData[px] >> 16) & 0xFF; // red
            alpha1 = (invert==1) ? 255 - alpha1 : alpha1;
            unsigned char alpha2 = (newColor >> 24) & 0xFF; // alpha
            // imageData[px] = newColor;
            imageData[px] = (min(alpha1,alpha2) << 24) | (newColor & 0x00ffffff);
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV AlterBitmapAlphaChannel(unsigned char *imageData, int w, int h, int Stride, int bpp, int level, int replaceAlpha) {
    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        for (int x = 0; x < w; x++)
        {
            INT64 px = ky + (INT64)x * bpc;
            if (imageData[px + 3]==0)
               continue;

            if (replaceAlpha==1)
               imageData[px + 3] = level;
            else
               imageData[px + 3] = clamp(imageData[px + 3] + level, 0, 255);
        }
    }

    return 1;
}

double toLABfx(double Y) {
  // if (Y >= 0.00885645167903563082) // CIE epsilon = 216/24389
  if (Y >= 8.88564517) // intentionally chosen value
     Y = cbrt(Y);  // 1/3
  else
     Y = 7.7870370 * Y + 0.1379310; // (841.0/108.0) * Y + ( 4.0 / 29.0 );

  return Y;
}

double deg2rad(double degree) {
    // convert degree to radian
    const double p = M_PI / 180.0;
    return (degree * p);
}

double rad2deg(double radian) {
    // convert radian to degree
    const double p = 180.0 / M_PI;
    return (radian * p);
}

int RGBtoGray(int &sR, int &sG, int &sB, int &alternateMode) {
  // https://getreuer.info/posts/colorspace/index.html
  // http://www.easyrgb.com/en/math.php
  // sR, sG and sB (Standard RGB) input range [0, 255]
  // X, Y and Z output refer to a D65/2° standard illuminant.
  // return value is L* - Luminance from L*ab, based on D65 luminant

  if (alternateMode==1)
     return round(char_to_grayRfloat[sR] + char_to_grayGfloat[sG] + char_to_grayBfloat[sB]); // weighted grayscale conversion

  double Y = LUT_Y_R[sR] + LUT_Y_G[sG] + LUT_Y_B[sB];

  Y = toLABfx(Y);
  double L = 116.0*Y - 16.0;
  return round(L/2); // return derived luminosity in pseudo-LAB color space
}

// the flood fill and "Replace similar colours anywhere"; it must sit here because it uses
// prepareSelectionArea()'s selection state, clipMaskFilter() and the colour helpers above
#include "flood-fill.h"

// Auto-crop pixel metric. A pixel is (luma, alpha): two fully transparent pixels must
// read as identical whatever their RGB is, and a transparent pixel must never be mistaken
// for an opaque black one. For opaque pixels the weight is 255 and the result is exactly
// the plain luma difference, so images without an alpha channel are unaffected.
static inline void acReadPixel(const unsigned char *px, int bpp, int &gray, int &alpha) {
   // px points at one pixel of a BGRA / BGR buffer; a bitmap without an alpha
   // channel is opaque everywhere
   alpha = (bpp==32) ? px[3] : 255;
   int sR = px[2], sG = px[1], sB = px[0], mode = 1;
   gray = RGBtoGray(sR, sG, sB, mode);
}

static inline int acDelta(int prevGray, int prevAlpha, int gray, int alpha) {
   int dA = abs(prevAlpha - alpha);
   int weight = (prevAlpha < alpha) ? prevAlpha : alpha;
   int dG = (abs(prevGray - gray) * weight) / 255;
   return (dA > dG) ? dA : dG;
}

DLL_API int DLL_CALLCONV autoCropAider(unsigned char* BitmapData, int Width, int Height, int Stride, int bpp, int adaptLevel, double threshold, double vTolrc, int whichLoop, int aaMode, int* fcoord) {
   const int bpc = bpp/8;
   int maxThresholdHitsW = round(Width*threshold) + 1;
   if (maxThresholdHitsW>floor(Width/2))
      maxThresholdHitsW = floor(Width/2);

   int maxThresholdHitsH = round(Height*threshold) + 1;
   if (maxThresholdHitsH>floor(Height/2))
      maxThresholdHitsH = floor(Height/2);

   const unsigned char *clrPrimeA = BitmapData;
   const unsigned char *clrPrimeB = (Width > 1) ? BitmapData + bpc : clrPrimeA;     // pixel (1,0)
   const unsigned char *clrPrimeC = (Height > 1) ? BitmapData + Stride : clrPrimeA; // pixel (0,1)
   int prevR1, prevR2, prevR3, prevA1, prevA2, prevA3;
   acReadPixel(clrPrimeA, bpp, prevR1, prevA1);
   acReadPixel(clrPrimeB, bpp, prevR2, prevA2);
   acReadPixel(clrPrimeC, bpp, prevR3, prevA3);
   int prevR4 = (prevR1 + prevR2 + prevR3)/3;
   int prevA4 = (prevA1 + prevA2 + prevA3)/3;

   // In adaptive mode (aaMode=1) the reference is re-seeded from the leading pixels of every scan line.
   // Letting it carry across the line break pins it to the far end of the previous line on any
   // graded background, and every later line then spends its whole tolerance budget at once.
   int seedStepW = (Width > 2) ? 2 : Width - 1;
   int seedStepH = (Height > 2) ? 2 : Height - 1;

   int ToleranceHits = 0;
   int loopDone = 0;
   int x = 0; int y = 0;
   if (whichLoop==1)
   {
      for (y = 0; y < Height; y++)
      {
         const unsigned char *row = BitmapData + (INT64)y * Stride;
         if (aaMode==1)
         {
            int lineR1, lineA1, lineR2, lineA2;
            acReadPixel(row, bpp, lineR1, lineA1);
            acReadPixel(row + (INT64)seedStepW * bpc, bpp, lineR2, lineA2);
            prevR4 = (lineR1 + lineR2 + 1)/2;
            prevA4 = (lineA1 + lineA2 + 1)/2;
         }

         for (x = 0; x < Width; x++)
         {
            int R1, A1;
            acReadPixel(row + (INT64)x * bpc, bpp, R1, A1);
            int d = acDelta(prevR4, prevA4, R1, A1);

            if (aaMode==1)
            {
               if (inRange(d - adaptLevel, d + adaptLevel, vTolrc))
               {
                  prevR4 = R1;
                  prevA4 = A1;
               }
            }

            if (ToleranceHits<maxThresholdHitsW && d>vTolrc)
            {
               ToleranceHits++;
            } else if (d<=vTolrc)
            {
               d = 0;
            } else
            {
               loopDone = 1;
               break;
            }
         }

         ToleranceHits = 0;
         if (loopDone==1)
         {
            *fcoord = y;
            break;
         }
      }
   } else if (whichLoop==2)
   {
      for (x = 0; x < Width; x++)
      {
         const unsigned char *col = BitmapData + (INT64)x * bpc;
         if (aaMode==1)
         {
            int lineR1, lineA1, lineR2, lineA2;
            acReadPixel(col, bpp, lineR1, lineA1);
            acReadPixel(col + (INT64)seedStepH * Stride, bpp, lineR2, lineA2);
            prevR4 = (lineR1 + lineR2 + 1)/2;
            prevA4 = (lineA1 + lineA2 + 1)/2;
         }

         for (y = 0; y < Height; y++)
         {
            int R1, A1;
            acReadPixel(col + (INT64)y * Stride, bpp, R1, A1);
            int d = acDelta(prevR4, prevA4, R1, A1);

            if (aaMode==1 && inRange(d - adaptLevel, d + adaptLevel, vTolrc))
            {
               prevR4 = R1;
               prevA4 = A1;
            }

            if (ToleranceHits<maxThresholdHitsH && d>vTolrc)
            {
               ToleranceHits++;
            } else if (d<=vTolrc)
            {
               d = 0;
            } else
            {
               loopDone = 1;
               break;
            }
         }

         ToleranceHits = 0;
         if (loopDone==1)
         {
            *fcoord = x;
            break;
         }
      }
   }
   return 1;
}

DLL_API int DLL_CALLCONV FillImageHoles(int *imageData, int w, int h, int newColor) {
    // fnOutputDebug("FillImageHoles newColor = " + std::to_string(newColor));
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * w;
        for (int x = 0; x < w; x++)
        {
            INT64 px = x + ky;
            int a = (imageData[px] >> 24) & 0xFF;
            if (a<2)
               imageData[px] = newColor;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV PrepareAlphaChannelBlur(int *imageData, int w, int h, int givenLevel, int fillMissingOnly, int threadz) {
    // this function fills / replaces black pixels [and with opacity 0] with surrounding colors
    // this helps mitigate the dark hallows that emerge when applying blur on images with areas that are fully transparent 
    // the function can also be used to specify an opacity/alpha level of the image

    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * w;
        int defaultColor = 0;
        UINT bgrColor = imageData[ky];
        if (bgrColor!=0x0)
           defaultColor = bgrColor & 0x00ffffff;

        for (int x = 0; x < w; x++)
        {
            INT64 px = x + ky;
            bgrColor = imageData[px];
            if (bgrColor==0x0 && defaultColor)
               imageData[px] = (givenLevel << 24) | defaultColor;
            else
               defaultColor = bgrColor & 0x00ffffff;

            if (fillMissingOnly==0)
               imageData[px] = (givenLevel << 24) | (imageData[px] & 0x00ffffff);
        }
    }

    #pragma omp parallel for schedule(dynamic)
    for (int y = h - 1; y >= 0; y--)
    {
        INT64 ky = (INT64)y * w;
        int defaultColor = 0;
        UINT bgrColor = imageData[(w - 1) + ky];
        if (bgrColor!=0x0)
           defaultColor = bgrColor & 0x00ffffff;

        for (int x = w - 1; x >= 0; x--)
        {
            INT64 px = x + ky;
            bgrColor = imageData[px];
            if (bgrColor==0x0 && defaultColor)
               imageData[px] = (givenLevel << 24) | defaultColor;
            else
               defaultColor = bgrColor & 0x00ffffff;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV BlendBitmaps(unsigned char* bgrImageData, unsigned char* otherData, int w, int h, int Stride, int bpp, int blendMode, int flipLayers,int keepAlpha, int linearGamma, int opacity) {
    // pBitmap and pBitmap2Blend must be the same width and height
    // and in 32-ARGB or 24-RGB format.

    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        for (int x = 0; x < w; x++)
        {
            INT64 o = ky + (INT64)x * bpc;
            int aB = (bpp==32) ? bgrImageData[3 + o] : 255;
            int aO = (bpp==32) ? otherData[3 + o] : 255;
            RGBAColor Brgb = {bgrImageData[o], bgrImageData[o + 1], bgrImageData[o + 2], aB};
            RGBAColor Orgb = {otherData[o], otherData[o + 1], otherData[o + 2], aO};
            RGBAColor newColor = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, keepAlpha, bpp, opacity);
            bgrImageData[2 + o] = newColor.r;
            bgrImageData[1 + o] = newColor.g;
            bgrImageData[o]     = newColor.b;
            if (bpp==32)
               bgrImageData[3 + o] = newColor.a;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV GenerateRandomNoise(int* bgrImageData, int w, int h, int intensity, int doGrayScale, int threadz, int fillBgr) {
    // pBitmap will be filled with a random generated noise
    // It must be in 32-ARGB format: PXF32ARGB - 0x26200A.

    // #pragma omp parallel for default(none) num_threads(threadz)
    time_t nTime;
    srand((unsigned) time(&nTime));
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * w;
        for (int x = 0; x < w; x++)
        {
            INT64 px = x + ky;
            unsigned char aT = 255;
            unsigned char z = rand() % 101;
            if (z<intensity)
            {
               // unsigned char rT = 0;
               bgrImageData[px] = (fillBgr!=1) ? 0 : (255 << 24) | (0 << 16) | (0 << 8) | 0;
               continue;
            }

            if (doGrayScale!=1)
            {
               unsigned char rT = rand() % 256;
               unsigned char gT = rand() % 256;
               unsigned char bT = rand() % 256;
               bgrImageData[px] = (aT << 24) | (rT << 16) | (gT << 8) | bT;
            } else
            {
               unsigned char rT = rand() % 256;
               bgrImageData[px] = (aT << 24) | (rT << 16) | (rT << 8) | rT;
            }
        }
    }

    return 1;
}

// The area of the w x h image that the small bitmap of GenerateRandomNoiseOnBitmap() and
// PixelateHugeBitmap() stands for: the whole image when the selection is inverted, else the
// selection box clipped to the image. AHK shifts the start row of a freeform selection by
// imgSel.y1Push; a rotated ellipse's box is the rescaled one prepareSelectionArea() received.
static void smallBitmapArea(const int w, const int h, int &x, int &y, int &bw, int &bh) {
    if (imgSel.inverted==1)
    {
       x = y = 0;
       bw = w;
       bh = h;
       return;
    }

    x = max(0, imgSel.x1);
    y = max(0, (int)(imgSel.y1 - imgSel.y1Push));
    bw = max(1, min(imgSel.x2 + 1, w) - x);
    bh = max(1, min(imgSel.y2 + 1, h) - y);
}

DLL_API int DLL_CALLCONV GenerateRandomNoiseOnBitmap(unsigned char* bgrImageData, int w, int h, int Stride, int bpp, int intensity, int opacity, int brightness, int doGrayScale, int pixelize, unsigned char *newBitmap, int StrideMini, int mw, int mh, int blendMode, int flipLayers, int keepAlpha, int linearGamma) {
    // newBitmap must be 24 bits
    time_t nTime;
    opacity = 255 - opacity;
    srand((unsigned) time(&nTime));
    fnOutputDebug("add noise; grayscale==" + std::to_string(doGrayScale) + " / " + std::to_string(blendMode));
    if (pixelize>0)
    {
        std::vector<int> pixelzMapW(w + 2, 0);
        std::vector<int> pixelzMapH(h + 2, 0);
        int bmpX, bmpY, bmpW, bmpH;
        smallBitmapArea(w, h, bmpX, bmpY, bmpW, bmpH);
        // fnOutputDebug("add noise step -1");
        for (int x = 0; x < w + 1; x++)
            pixelzMapW[x] = clamp( (float)mw*((x - bmpX)/(float)bmpW), 0.0f, (float)mw - 1.0f);

        for (int y = 0; y < h + 1; y++)
            pixelzMapH[y] = clamp( (float)mh*((y - bmpY)/(float)bmpH), 0.0f, (float)mh - 1.0f);

        // fnOutputDebug("add noise step 0");
        #pragma omp parallel for schedule(dynamic)
        for (int y = 0; y < mh; y++)
        {
            INT64 ky = (INT64)y * StrideMini;
            unsigned int rngState = (unsigned int)nTime ^ (2654435761u * (unsigned int)(y + 1));
            if (rngState==0)
               rngState = 0x9E3779B9u;
            // prepare the noise bitmap
            for (int x = 0; x < mw; x++)
            {
                unsigned char z = qpvThreadRand(rngState) % 101;
                INT64 o = ky + (INT64)x * 3;
                if (z<intensity)
                {
                   newBitmap[2 + o] = 128;
                   newBitmap[1 + o] = 128;
                   newBitmap[o] = 128;
                   continue;
                }

                if (doGrayScale==1)
                {
                   unsigned char zT = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
                   newBitmap[2 + o] = zT;
                   newBitmap[1 + o] = zT;
                   newBitmap[o] = zT;
                } else
                {
                   newBitmap[2 + o] = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
                   newBitmap[1 + o] = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
                   newBitmap[o] = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
                }
            }
        }

        // fnOutputDebug("add noise step 1");
        const int bpc = bpp / 8;
        #pragma omp parallel for schedule(dynamic)
        for (int y = 0; y < h; y++)
        {
            INT64 ky = (INT64)y * Stride;
            int py = pixelzMapH[y];
            INT64 ky_mini = (INT64)py * StrideMini;
            for (int x = 0; x < w; x++)
            {
                if (clipMaskFilter(x, y, NULL, 0)==1)
                   continue;

                int px = pixelzMapW[x];
                if (px>=mw || py>=mh || px<0 || py<0)
                   continue;

                INT64 on = ky_mini + (INT64)px * 3;
                RGBAColor Orgb = {newBitmap[2 + on], newBitmap[1 + on], newBitmap[on], 255};
                if (Orgb.r==128 && Orgb.g==128 && Orgb.b==128)
                   continue;
     
                INT64 o = ky + (INT64)x * bpc;
                int oA = (bpp==32) ? bgrImageData[3 + o] : 255;
                RGBAColor Brgb = {bgrImageData[o], bgrImageData[1 + o], bgrImageData[2 + o], oA};
                RGBAColor newColor = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, 1, bpp, opacity);
                bgrImageData[2 + o] = newColor.r;
                bgrImageData[1 + o] = newColor.g;
                bgrImageData[o]     = newColor.b;
                if (bpp==32)
                   bgrImageData[3 + o] = newColor.a;
            }
        }

        // fnOutputDebug("add noise step 2");
        return 1;
    }

    // fnOutputDebug("add noise step 3");
    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        unsigned int rngState = (unsigned int)nTime ^ (2654435761u * (unsigned int)(y + 1));
        if (rngState==0)
           rngState = 0x9E3779B9u;
        for (int x = 0; x < w; x++)
        {
            unsigned char nR, nG, nB;
            unsigned char z = qpvThreadRand(rngState) % 101;
            if (z<intensity)
               continue;

            if (clipMaskFilter(x, y, NULL, 0)==1)
               continue;

            INT64 o = ky + (INT64)x * bpc;
            if (doGrayScale==1)
            {
               unsigned char zT = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
               nR = zT;
               nG = zT;
               nB = zT;
            } else
            {
               nR = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
               nG = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
               nB = clamp((int)(qpvThreadRand(rngState) % 256) + brightness, 0, 255);
            }
 
            int oA = (bpp==32) ? bgrImageData[3 + o] : 255;
            RGBAColor Orgb = {nR, nG, nB, 255};
            RGBAColor Brgb = {bgrImageData[o], bgrImageData[1 + o], bgrImageData[2 + o], oA};
            RGBAColor newColor = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, 1, bpp, opacity);
            bgrImageData[2 + o] = newColor.r;
            bgrImageData[1 + o] = newColor.g;
            bgrImageData[o]     = newColor.b;
            if (bpp==32)
               bgrImageData[3 + o] = newColor.a;
        }
    }

    fnOutputDebug("add noise step DONE");
    return 1;
} // GenerateRandomNoiseOnBitmap()

/*
Pixelate C/C++ Function by Tic and fixed by Fincs;
https://autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/page-55
*/

DLL_API int DLL_CALLCONV PixelateBitmap(unsigned char* sBitmap, unsigned char* dBitmap, int w, int h, int Stride, int Size, int bpp) {
    const int bpc = bpp / 8;
    // a block takes the alpha-weighted mean of its colours [straight ARGB], so semi-transparent pixels count as much as they show
    auto pixelateBlock = [&](const int bx, const int by, const int bw, const int bh) {
        const INT64 n = (INT64)bw * bh;
        if (n<1)
           return;

        INT64 sA = 0, sR = 0, sG = 0, sB = 0, wR = 0, wG = 0, wB = 0;
        for (int y = by; y < by + bh; ++y)
        {
            for (int x = bx; x < bx + bw; ++x)
            {
                const INT64 o = (INT64)bpc * x + (INT64)Stride * y;
                const int a = (bpp==32) ? sBitmap[3 + o] : 255;
                sA += a;
                sR += sBitmap[2 + o];
                sG += sBitmap[1 + o];
                sB += sBitmap[o];
                wR += sBitmap[2 + o] * a;
                wG += sBitmap[1 + o] * a;
                wB += sBitmap[o] * a;
            }
        }

        // a block with nothing visible keeps the plain mean
        const bool weighted = (bpp==32 && sA>0);
        const unsigned char nA = (unsigned char)(sA / n);
        const unsigned char nR = (unsigned char)(weighted ? wR / sA : sR / n);
        const unsigned char nG = (unsigned char)(weighted ? wG / sA : sG / n);
        const unsigned char nB = (unsigned char)(weighted ? wB / sA : sB / n);
        for (int y = by; y < by + bh; ++y)
        {
            for (int x = bx; x < bx + bw; ++x)
            {
                const INT64 o = (INT64)bpc * x + (INT64)Stride * y;
                if (bpp==32)
                   dBitmap[3 + o] = nA;
                dBitmap[2 + o] = nR;
                dBitmap[1 + o] = nG;
                dBitmap[o] = nB;
            }
        }
    };

    const int fullW = (w / Size) * Size;
    const int fullH = (h / Size) * Size;
    for (int y1 = 0; y1 < fullH; y1 += Size)
    {
        for (int x1 = 0; x1 < fullW; x1 += Size)
            pixelateBlock(x1, y1, Size, Size);

        pixelateBlock(fullW, y1, w % Size, Size);
    }

    for (int x1 = 0; x1 < fullW; x1 += Size)
        pixelateBlock(x1, fullH, Size, h % Size);

    pixelateBlock(fullW, fullH, w % Size, h % Size);
    return 1;
}

DLL_API int DLL_CALLCONV ConvertToGrayScale(unsigned char *BitmapData, const int w, const int h, const int modus, const int intensity, const int Stride, const int bpp, unsigned char *maskBitmap, const int mStride) {
// NTSC // CCIR 601 luma RGB weights:
// r := 0.29970, g := 0.587130, b := 0.114180

    const float fintensity = intensity/100.0f;
    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        for (int x = 0; x < w; x++)
        {
            int G;
            if (clipMaskFilter(x, y, maskBitmap, mStride)==1)
               continue;

            INT64 o = ky + (INT64)x * bpc;
            int zR = BitmapData[2 + o];
            int zG = BitmapData[1 + o];
            int zB = BitmapData[o];
            if (modus==1) {
               G = BitmapData[2 + o]; // red
            } else if (modus==2) {
               G = BitmapData[1 + o]; // green
            } else if (modus==3) {
               G = BitmapData[o];     // blue
            } else if (modus==4 && bpp==32) {
               G = BitmapData[3 + o]; // alpha
            } else { // if (modus==5)
               G = clamp((int)round(char_to_grayRfloat[zR] + char_to_grayGfloat[zG] + char_to_grayBfloat[zB]), 0, 255);
            }

            BitmapData[2 + o] = weighTwoValues(G, zR, fintensity);
            BitmapData[1 + o] = weighTwoValues(G, zG, fintensity);
            BitmapData[o]     = weighTwoValues(G, zB, fintensity);
        }
    }
    return 1;
}

// ---------------------------------------------------------------------------
// Just-in-time rescaling of the overlay bitmap in FillSelectArea().
//
// The overlay is stretched inside the loop that already walks the destination,
// so the caller never has to materialise a full-size copy of it. Same trick as
// PixelateHugeBitmap() and GenerateRandomNoiseOnBitmap(), which map a small
// bitmap onto a big one through precalculated per-axis tables -- those two use
// nearest-neighbour, this one interpolates.
//
// One table entry per DESTINATION column/row, so the set-up is O(w + h) instead
// of the O(w*h) buffer it replaces, and the divide/floor leave the inner loop.
//
// Filters carry FreeImage's numbering, the one the rest of QPV already speaks
// (trFreeImage_Rescale(), blurAreaPixelizeMethod, thumbs-pool.h):
//    1 = BICUBIC (Mitchell-Netravali)   3 = BSPLINE
//    2 = BILINEAR, the default          4 = CATMULLROM
// 0 (BOX) and 5 (LANCZOS3) want a different tap count and are not implemented;
// anything unrecognised degrades to bilinear rather than failing the call.
// ---------------------------------------------------------------------------
struct JITaxisTap {
    INT64 o[4];   // byte offsets of the taps (x: pixel stride, y: row stride)
    float w[4];   // bilinear fills [0..1] only, cubic fills all four
};

// Mitchell-Netravali cubic. The three cubic filters above are this one kernel
// under different (B,C), so they cost two constants each rather than a filter.
static double cubicKernel(double x, double B, double C) {
    x = fabs(x);
    const double x2 = x*x, x3 = x2*x;
    if (x<1.0)
       return ((12.0 - 9.0*B - 6.0*C)*x3 + (-18.0 + 12.0*B + 6.0*C)*x2 + (6.0 - 2.0*B)) / 6.0;

    if (x<2.0)
       return ((-B - 6.0*C)*x3 + (6.0*B + 30.0*C)*x2 + (-12.0*B - 48.0*C)*x + (8.0*B + 24.0*C)) / 6.0;

    return 0.0;
}

// true when the filter is one of the supported cubics, with its constants.
// Keeps the filter -> (B,C) table in exactly one place.
static bool jitFilterBC(int filter, double &B, double &C) {
    if (filter==1)      { B = 1.0/3.0; C = 1.0/3.0; return true; }  // BICUBIC / Mitchell
    else if (filter==3) { B = 1.0;     C = 0.0;     return true; }  // BSPLINE
    else if (filter==4) { B = 0.0;     C = 0.5;     return true; }  // CATMULLROM
    return false;                                                   // BILINEAR, and fallbacks
}

// destSize entries covering the destination axis; the source is stretched onto
// [origin, origin + targetSize). Pixel centres are mapped the way OpenCV's
// INTER_LINEAR does it, so this lines up with openCVresizeBitmap() elsewhere.
static void buildJITaxis(std::vector<JITaxisTap> &tab, int destSize, int origin, int targetSize, int srcSize, INT64 unitStride, int filter) {
    tab.resize(max(destSize, 1));
    double B = 0.0, C = 0.0;
    const bool cubic = jitFilterBC(filter, B, C);
    const double scale = (double)srcSize / (double)targetSize;
    for (int i = 0; i < destSize; i++)
    {
        const double s = ((double)(i - origin) + 0.5) * scale - 0.5;
        const int i0 = (int)floor(s);
        const double t = s - (double)i0;
        if (cubic)
        {
           // taps i0-1 .. i0+2; distance from the sample to tap k is t + 1 - k.
           // These kernels are a partition of unity, so the weights need no
           // renormalising -- and where the clamp below folds two taps onto the
           // same texel that texel simply gathers both weights, which is the
           // edge replication we want.
           for (int k = 0; k < 4; k++)
           {
               tab[i].o[k] = (INT64)clamp(i0 - 1 + k, 0, srcSize - 1) * unitStride;
               tab[i].w[k] = (float)cubicKernel(t + 1.0 - (double)k, B, C);
           }
        } else
        {
           // outside the source the edge texel is replicated; o[0]==o[1] there,
           // which makes the weight irrelevant, so it needs no clamping too
           const float tf = (float)t;
           tab[i].o[0] = (INT64)clamp(i0,     0, srcSize - 1) * unitStride;
           tab[i].o[1] = (INT64)clamp(i0 + 1, 0, srcSize - 1) * unitStride;
           tab[i].o[2] = tab[i].o[0];   // never read, but always safe to dereference
           tab[i].o[3] = tab[i].o[0];
           tab[i].w[0] = 1.0f - tf;
           tab[i].w[1] = tf;
           tab[i].w[2] = 0.0f;
           tab[i].w[3] = 0.0f;
        }
    }
}

// The overlay buffer is straight (non-premultiplied) ARGB: the code downstream
// hands alpha to the blend modes as a separate weight and never divides RGB by
// it. So each tap has to be weighed by its own alpha before mixing, otherwise a
// fully transparent texel bleeds its stored colour into every neighbour and the
// overlay grows halos along its edges. The accumulated alpha is divided back out.
QPV_FORCEINLINE void sampleColorBitmapBilinear(const unsigned char *src, const JITaxisTap &tx, const JITaxisTap &ty, int gBpp, int flatOpacity, int &oR, int &oG, int &oB, int &oA) {
    const float wx0 = tx.w[0], wx1 = tx.w[1];
    const float wy0 = ty.w[0], wy1 = ty.w[1];
    const INT64 q[4]  = { ty.o[0] + tx.o[0], ty.o[0] + tx.o[1], ty.o[1] + tx.o[0], ty.o[1] + tx.o[1] };
    const float wq[4] = { wx0*wy0, wx1*wy0, wx0*wy1, wx1*wy1 };
    if (gBpp==32)
    {
       float sa = 0.0f, sr = 0.0f, sg = 0.0f, sb = 0.0f;
       for (int i = 0; i < 4; i++)
       {
           const unsigned char *p = src + q[i];
           const float aw = wq[i] * (float)p[3];
           sa += aw;
           sr += aw * (float)p[2];
           sg += aw * (float)p[1];
           sb += aw * (float)p[0];
       }

       if (sa<0.5f)
       {
          oR = oG = oB = oA = 0;
          return;
       }

       oA = clamp((int)(sa + 0.5f), 0, 255);
       oR = clamp((int)(sr/sa + 0.5f), 0, 255);
       oG = clamp((int)(sg/sa + 0.5f), 0, 255);
       oB = clamp((int)(sb/sa + 0.5f), 0, 255);
    } else
    {
       float sr = 0.0f, sg = 0.0f, sb = 0.0f;
       for (int i = 0; i < 4; i++)
       {
           const unsigned char *p = src + q[i];
           sr += wq[i] * (float)p[2];
           sg += wq[i] * (float)p[1];
           sb += wq[i] * (float)p[0];
       }

       oA = flatOpacity;
       oR = clamp((int)(sr + 0.5f), 0, 255);
       oG = clamp((int)(sg + 0.5f), 0, 255);
       oB = clamp((int)(sb + 0.5f), 0, 255);
    }
}

// Same alpha-weighted contract as sampleColorBitmapBilinear(), over 4x4 taps.
//
// Mitchell and Catmull-Rom have NEGATIVE lobes, which bilinear and B-spline do
// not, and that is why none of the guards below are redundant here:
//   - the accumulated alpha can come out negative or near zero, so the
//     "< 0.5f -> fully transparent" test is doing real work, not just dodging a
//     division by zero;
//   - sr/sa can land outside 0..255 (overshoot at edges is the whole point of a
//     sharpening kernel), so every channel has to be clamped;
//   - in the 24bpp branch the weighted sum itself overshoots, same story.
QPV_FORCEINLINE void sampleColorBitmapCubic(const unsigned char *src, const JITaxisTap &tx, const JITaxisTap &ty, int gBpp, int flatOpacity, int &oR, int &oG, int &oB, int &oA) {
    if (gBpp==32)
    {
       float sa = 0.0f, sr = 0.0f, sg = 0.0f, sb = 0.0f;
       for (int j = 0; j < 4; j++)
       {
           const float wy = ty.w[j];
           if (wy==0.0f)
              continue;

           const unsigned char *row = src + ty.o[j];
           for (int i = 0; i < 4; i++)
           {
               const unsigned char *p = row + tx.o[i];
               const float aw = wy * tx.w[i] * (float)p[3];
               sa += aw;
               sr += aw * (float)p[2];
               sg += aw * (float)p[1];
               sb += aw * (float)p[0];
           }
       }

       if (sa<0.5f)
       {
          oR = oG = oB = oA = 0;
          return;
       }

       oA = clamp((int)(sa + 0.5f), 0, 255);
       oR = clamp((int)(sr/sa + 0.5f), 0, 255);
       oG = clamp((int)(sg/sa + 0.5f), 0, 255);
       oB = clamp((int)(sb/sa + 0.5f), 0, 255);
    } else
    {
       float sr = 0.0f, sg = 0.0f, sb = 0.0f;
       for (int j = 0; j < 4; j++)
       {
           const float wy = ty.w[j];
           if (wy==0.0f)
              continue;

           const unsigned char *row = src + ty.o[j];
           for (int i = 0; i < 4; i++)
           {
               const unsigned char *p = row + tx.o[i];
               const float wq = wy * tx.w[i];
               sr += wq * (float)p[2];
               sg += wq * (float)p[1];
               sb += wq * (float)p[0];
           }
       }

       oA = flatOpacity;
       oR = clamp((int)(sr + 0.5f), 0, 255);
       oG = clamp((int)(sg + 0.5f), 0, 255);
       oB = clamp((int)(sb + 0.5f), 0, 255);
    }
}

DLL_API int DLL_CALLCONV FillSelectArea(unsigned char *BitmapData, int w, int h, int Stride, int bpp, int color, int opacity, int eraser, int linearGamma, int blendMode, int flipLayers, unsigned char *colorBitmap, int gStride, int gBpp, int opacityMultiplier, int keepAlpha, int nBmpW, int nBmpH, int rescaleBitmapJIT, int jitFilter) {
    // nBmpW and nBmpH, gBpp, gStride describe colorBitmap data. colorBitmap is scaled
    // just-in-time, as the loop below unfolds:
    //    rescaleBitmapJIT=0 / colorBitmap is read 1:1 and placed at bmpX/bmpY
    //    rescaleBitmapJIT=1 / colorBitmap is stretched over the whole of BitmapData,
    //                         w and h; bmpX/bmpY do not apply
    //    rescaleBitmapJIT=2 / colorBitmap is stretched over the WHOLE selection box,
    //                         the parts of it that hang off the image included, and
    //                         whatever lands outside the image is dropped; an
    //                         inverted selection falls back to the full w and h
    // jitFilter picks the interpolation, in FreeImage's numbering: 1 = bicubic
    // (Mitchell), 2 = bilinear, 3 = B-spline, 4 = Catmull-Rom. Anything else,
    // 0 (box) and 5 (Lanczos3) included, degrades to bilinear.
    // the opacity and opacityMultiplier parameters only apply if colorBitmap is not NULL.
    // With gBpp!=32 the overlay has no alpha of its own, so opacity simply IS the alpha of
    // every one of its pixels; opacityMultiplier stays 32bpp-only because an overlay that
    // is opaque everywhere has no partially visible pixels left to restore

    fnOutputDebug("FillSelectArea() Stride=" + std::to_string(Stride) + " opacity=" + std::to_string(opacity));
    // fnOutputDebug("clipMaskFilter=zx=" + std::to_string(zx1) + "/" + std::to_string(zx2) + "=w=" + std::to_string(max(zx1, zx2) - min(zx1, zx2)));
    // fnOutputDebug("clipMaskFilter=zy=" + std::to_string(zy1) + "/" + std::to_string(zy2) + "=h=" + std::to_string(max(zy1, zy2) - min(zy1, zy2)));
    RGBAColor initialColor;
    initialColor.a = (color >> 24) & 0xFF;
    initialColor.r = (color >> 16) & 0xFF;
    initialColor.g = (color >> 8) & 0xFF;
    initialColor.b = color & 0xFF;

    const int bpc = bpp/8;
    const int gbpc = gBpp/8;
    // where a 1:1 overlay starts. The rescaleBitmapJIT=0 call sites hand over an
    // overlay they cropped themselves to the on-image part of the selection box, so
    // for them the origin is the clamped one; the JIT modes below re-anchor it
    int bmpX = (imgSel.x1<0 || imgSel.inverted==1) ? 0 : imgSel.x1;
    int bmpY = (imgSel.y1<0 || imgSel.inverted==1) ? 0 : imgSel.y1;
    // ... and the selection box as the caller actually declared it, off-image parts
    // included. QPV_PrepareHugeImgSelectionArea() pushes y1 up by imgSel.y1Push for mode 2
    // to accomodate FreeImage's Y-flipped crap, so subtracting it recovers the origin
    const int selX = imgSel.x1;
    const int selY = imgSel.y1 - (int)imgSel.y1Push;
    const int mw = (imgSel.shape==2 && imgSel.inverted==0) ? min(w - 1, imgSel.x2) : w - 1;
    const int mh = (imgSel.shape==2 && imgSel.inverted==0) ? min(h - 1, imgSel.y2) : h - 1;
    const int mx = (imgSel.shape==2 && imgSel.inverted==0) ? clamp(imgSel.x1, 0, w - 1) : 0;
    const int my = (imgSel.shape==2 && imgSel.inverted==0) ? clamp(imgSel.y1 - (int)imgSel.maskRowShift, 0, h - 1) : 0;
    // fnOutputDebug("offsets X/Y: " + std::to_string(bmpX) + "|" + std::to_string(bmpY));
    // fnOutputDebug("colorBitmap W/H: " + std::to_string(nBmpW) + "|" + std::to_string(nBmpH));

    // colorBitmap!=NULL has to be tested FIRST: the call sites that pass no overlay
    // stop short of this parameter, so rescaleBitmapJIT is uninitialised stack there
    // and only the short-circuit keeps it from being read
    bool useJIT = (colorBitmap!=NULL && (rescaleBitmapJIT==1 || rescaleBitmapJIT==2) && nBmpW>0 && nBmpH>0);
    int jitX = 0, jitY = 0, jitW = w, jitH = h;
    if (useJIT && rescaleBitmapJIT==2 && imgSel.inverted!=1)
    {
       // the overlay spans the whole selection box, so the box is what it is stretched
       // onto -- and the loop below simply never visits the part of it that falls off
       // the image. That is the crop the callers used to make by hand, minus the copy;
       // and because the overlay is never trimmed, the taps along the image border
       // still gather their real neighbours instead of a replicated edge
       jitX = selX;
       jitY = selY;
       jitW = imgSel.x2 - selX + 1;
       jitH = imgSel.y2 - selY + 1;
       if (jitW<1 || jitH<1)
          useJIT = false;
    }

    // nothing left to interpolate: hand the overlay back to the direct path, anchored
    // at the box origin rather than the clamped one -- the negative-source guard there
    // drops whatever hangs off the image. This is not merely an optimisation: B-spline
    // at t==0 is a blur, so a 1:1 overlay must not go through the resampler
    if (useJIT && nBmpW==jitW && nBmpH==jitH)
    {
       useJIT = false;
       bmpX = jitX;
       bmpY = jitY;
    }

    std::vector<JITaxisTap> jitMapX, jitMapY;
    bool jitCubic = false;
    if (useJIT)
    {
       double jitB = 0.0, jitC = 0.0;
       jitCubic = jitFilterBC(jitFilter, jitB, jitC);
       if (!jitCubic && jitFilter!=2)
          fnOutputDebug("FillSelectArea(): interpolation filter " + std::to_string(jitFilter) + " is not supported, falling back to bilinear");

       fnOutputDebug("FillSelectArea(): JIT rescale mode " + std::to_string(rescaleBitmapJIT) + ", filter " + std::to_string(jitFilter) + "; " + std::to_string(nBmpW) + "x" + std::to_string(nBmpH) + " onto " + std::to_string(jitW) + "x" + std::to_string(jitH) + " at " + std::to_string(jitX) + "|" + std::to_string(jitY));
       buildJITaxis(jitMapX, w, jitX, jitW, nBmpW, (INT64)gbpc, jitFilter);
       buildJITaxis(jitMapY, h, jitY, jitH, nBmpH, (INT64)gStride, jitFilter);
    }

    #pragma omp parallel for schedule(dynamic)
    for (int y = my; y <= mh; y++)
    {
        INT64 ky = (INT64)y * Stride;
        INT64 kzy = (INT64)(y - bmpY) * gStride;
        JITaxisTap rowTap = {{0, 0, 0, 0}, {0.0f, 0.0f, 0.0f, 0.0f}};
        if (useJIT)
        {
           if (y<jitY || (y - jitY)>=jitH)
              continue;

           rowTap = jitMapY[y];
        }

        for (int x = mx; x <= mw; x++)
        {
            INT64 kx = (INT64)x * bpc;
            INT64 kzx = (INT64)(x - bmpX) * gbpc;
            float opacityDepth = clipMaskFilter(x, y, NULL, 0);
            if (opacityDepth==1 && imgSel.highDepth==0 || opacityDepth==0 && imgSel.highDepth==1)
               continue;

            if (opacityDepth>1)
               opacityDepth *= 0.825f;
            // INT64 o = CalcPixOffset(x, y, Stride, bpp);
            INT64 o = ky + kx;
            RGBAColor userColor;
            if (colorBitmap!=NULL)
            {
               // INT64 oz = CalcPixOffset(x - zx1, y - zy1, gStride, 32);
               int sR, sG, sB, sA, sRawA;
               if (useJIT)
               {
                  // same no-bleed-outside-the-footprint rule as the direct path below
                  if (x<jitX || (x - jitX)>=jitW)
                     continue;

                  // loop-invariant branch, so it costs a perfectly predicted test
                  if (jitCubic)
                     sampleColorBitmapCubic(colorBitmap, jitMapX[x], rowTap, gBpp, opacity, sR, sG, sB, sA);
                  else
                     sampleColorBitmapBilinear(colorBitmap, jitMapX[x], rowTap, gBpp, opacity, sR, sG, sB, sA);

                  // an overlay that carries no alpha channel is opaque
                  sRawA = (gBpp==32) ? sA : 255;
               } else
               {
                  if ((y - bmpY)>=nBmpH || (x - bmpX)>=nBmpW || (y - bmpY)<0 || (x - bmpX)<0)
                     continue;

                  INT64 oz = kzy + kzx;
                  // fnOutputDebug("y=" + std::to_string(y - bmpY));
                  sRawA = (gBpp==32) ? colorBitmap[3 + oz] : 255;
                  sA = (gBpp==32) ? sRawA : opacity;
                  sR = colorBitmap[2 + oz];
                  sG = colorBitmap[1 + oz];
                  sB = colorBitmap[oz];
               }

               int thisOpacity = sA;
               // opacity is subtractive here, and that only makes sense against an alpha
               // channel the overlay actually has: for anything but 32bpp sA IS the flat
               // opacity, so subtracting it again applies it twice and the object dies at
               // half the slider [2*opacity - 255]. An opaque 32bpp overlay resolves to
               // 255 - (255 - opacity), and one without an alpha channel has to match it
               if (color==-1 && gBpp==32 && thisOpacity>0)
                  thisOpacity = clamp(thisOpacity - (255 - opacity), 0, 255);

               if (opacityMultiplier>0 && gBpp==32)
                  thisOpacity = clamp(thisOpacity + opacityMultiplier, 0, 255);

               if (imgSel.highDepth==1)
                  thisOpacity = clamp(thisOpacity * opacityDepth, 0.0f, 255.0f);

               userColor.a = thisOpacity;
               userColor.r = sR;
               userColor.g = sG;
               userColor.b = sB;
               if (color==-1 && userColor.r==0 && userColor.g==0 && userColor.b==0 && sRawA==0)
                  userColor.a = 0;
            } else
            {
               userColor = initialColor;
               userColor.a = (imgSel.highDepth==0) ? initialColor.a : clamp(initialColor.a * opacityDepth, 0.0f, 255.0f);
            }

            if (eraser==1)
            {
               // alter opacity/alpha
               if (bpp==32)
               {
                  BitmapData[3 + o] = clamp(BitmapData[3 + o] - userColor.a, 0, 255);
               } else
               {
                  BitmapData[2 + o] = clamp(BitmapData[2 + o] - userColor.a, 0, 255);
                  BitmapData[1 + o] = clamp(BitmapData[1 + o] - userColor.a, 0, 255);
                  BitmapData[o]     = clamp(BitmapData[o]     - userColor.a, 0, 255);
               }
               continue;
            }

            int oA = (bpp==32) ? BitmapData[3 + o] : 255;
            RGBAColor Orgb = {userColor.b, userColor.g, userColor.r, userColor.a};
            RGBAColor Brgb = {BitmapData[o], BitmapData[1 + o], BitmapData[2 + o], oA};
            RGBAColor newColor = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, keepAlpha, bpp, 0);
            BitmapData[2 + o] = newColor.r;
            BitmapData[1 + o] = newColor.g;
            BitmapData[o]     = newColor.b;
            if (bpp==32)
               BitmapData[3 + o] = newColor.a;
        }
    }
    return 1;
}

// AdjustImageColorsPrecise() and its 16-bit pixel kernel, which the effects brush reuses
#include "color-adjust.h"

DLL_API int DLL_CALLCONV MergeBitmapsWithMask(unsigned char *originalData, unsigned char *newBitmap, unsigned char *maskBitmap, int invert, int w, int h, int maskOpacity, int invertMaskOpacity, int Stride, int bpp, int linearGamma, int whichChannel) {
    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        for (int x = 0; x < w; x++)
        {
            int nA = 1;
            int oA = 1;
            int intensity = 0;
            INT64 o = ky + (INT64)x * bpc;
            if (maskBitmap!=NULL)
            {
               intensity = (invert==1) ? 255 - maskBitmap[o + whichChannel] : maskBitmap[o + whichChannel];
               if (maskOpacity!=0)
               {
                  intensity = (invertMaskOpacity==1) ? intensity + maskOpacity : intensity - maskOpacity;
                  intensity = clamp(intensity, 0, 255);
               }
            } else intensity = maskOpacity;

            if (intensity<1)
               continue;

            if (bpp==32)
               nA = newBitmap[3 + o];
            int nR = newBitmap[2 + o];
            int nG = newBitmap[1 + o];
            int nB = newBitmap[o];
            if (intensity>254)
            {
               originalData[2 + o] = nR;
               originalData[1 + o] = nG;
               originalData[o] = nB;
               if (bpp==32)
                  originalData[3 + o] = nA;
               continue;
            }

            if (bpp==32)
               oA = originalData[3 + o];
            const int oR = originalData[2 + o];
            const int oG = originalData[1 + o];
            const int oB = originalData[o];
            float fintensity = char_to_float[intensity];
            if (linearGamma==1)
            {
               originalData[2 + o] = linear_to_gamma[weighTwoValues(gamma_to_linear[nR], gamma_to_linear[oR], fintensity)];
               originalData[1 + o] = linear_to_gamma[weighTwoValues(gamma_to_linear[nG], gamma_to_linear[oG], fintensity)];
               originalData[o]     = linear_to_gamma[weighTwoValues(gamma_to_linear[nB], gamma_to_linear[oB], fintensity)];
            } else
            {
               originalData[2 + o] = weighTwoValues(nR, oR, fintensity);
               originalData[1 + o] = weighTwoValues(nG, oG, fintensity);
               originalData[o]     = weighTwoValues(nB, oB, fintensity);
            }

            if (bpp==32)
               originalData[3 + o] = weighTwoValues(nA, oA, fintensity);
        }
    }
    return 1;
}


DLL_API int DLL_CALLCONV openCVdiffBlendBitmap(unsigned char* bgrImageData, int w, int h, int Stride, int bpp, int offsetX, int offsetY, int preblur, int postblur, int invert, float prebrighten, float precontrast, float postbrighten, float postcontrast) {
// works best with 24 bits images 
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat bitmap(h, w, clr, bgrImageData, Stride);
    if (precontrast!=1 || prebrighten!=0)
       bitmap.convertTo(bitmap, -1, precontrast, prebrighten);

    cv::Mat otherData = bitmap.clone();
    if (preblur % 2 != 1)
       preblur++;
    if (postblur % 2 != 1)
       postblur++;
    if (preblur>0)
       cv::stackBlur(otherData, otherData, cv::Size(preblur, preblur));

    // Define the region of interest (ROI) for shifting; an offset as large as the selection
    // [3 px or less] leaves nothing to shift, and a negative ROI would throw
    const int roiW = bitmap.cols - abs(offsetX);
    const int roiH = bitmap.rows - abs(offsetY);
    if (roiW>0 && roiH>0)
    {
       cv::Rect sourceROI(max(0, offsetX), max(0, offsetY), roiW, roiH);
       cv::Rect destROI(max(0, -offsetX), max(0, -offsetY), roiW, roiH);
       otherData(sourceROI).copyTo(bitmap(destROI));
    }
    cv::subtract(bitmap, otherData, bitmap);
    if (postcontrast!=1 || postbrighten!=0)
       bitmap.convertTo(bitmap, -1, postcontrast, postbrighten);

    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int y = 0; y < bitmap.rows; y++) {
        // walk the row channel-aware: the Mat is CV_8UC4 for 32-bit images,
        // where at<Vec3b>() would step 3 bytes over 4-byte pixels
        const int nch = bitmap.channels();
        unsigned char* row = bitmap.ptr<unsigned char>(y);
        for (int x = 0; x < bitmap.cols; x++) {
            unsigned char* pixel = row + (INT64)x * nch;
            int gray = clamp( ( pixel[0] + pixel[1] + pixel[2] ) / 3, 0, 255 );
            if (invert==1)
               gray = 255 - gray;
            pixel[0] = gray;
            pixel[1] = gray;
            pixel[2] = gray;
        }
    }

    if (bpp==32)
    {
       bitmap.forEach<cv::Vec4b> ( [&](cv::Vec4b& pixel, const int* position) -> void {
             pixel[3] = 255;
       });
    }

    if (postblur>0)
       cv::stackBlur(bitmap, bitmap, cv::Size(postblur, postblur));

    return 1;
}

DLL_API int DLL_CALLCONV openCVedgeDetection(unsigned char *imageData, int w, int h, int xa, int ya, int ks, int preblur, int postblur, int invert, float prebrighten, float precontrast, float postbrighten, float postcontrast, int modus, int Stride, int bpp) {
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat image(h, w, clr, imageData, Stride);
    fnOutputDebug("openCVedgeDetection step 1; modus = " + std::to_string( modus ) + " | xa = " + std::to_string( xa ) + " | ya = " + std::to_string( ya ) + " | ks= " + std::to_string( ks ) );
    fnOutputDebug("openCVedgeDetection step 1; prebrighten = " + std::to_string( prebrighten ) + " | precontrast = " + std::to_string( precontrast ) );

    cv::Mat grayImage;
    if (precontrast!=1 || prebrighten!=0)
    {
       image.convertTo(image, -1, precontrast, prebrighten);
       if (bpp==32)
       {
          image.forEach<cv::Vec4b> ( [&](cv::Vec4b& pixel, const int* position) -> void {
                pixel[3] = 255;
          });
       }
    }

    if (preblur % 2 != 1)
       preblur++;
    if (postblur % 2 != 1)
       postblur++;

    cv::cvtColor(image, grayImage, cv::COLOR_BGR2GRAY);
    if (preblur>0)
       cv::stackBlur(grayImage, grayImage, cv::Size(preblur, preblur));

    cv::Mat gradXY, absGradXY, edgeImage;
    cv::Mat gradX, absGradX, gradY, absGradY;
    if (modus<=2)
    {
       if (ks==1)
       {
          if (xa > 2)
             xa = 2;
          if (ya > 2)
             ya = 2;
       } else if (ks>2)
       {
          if (xa >= ks)
             xa = ks - 1;
          if (ya >= ks)
             ya = ks - 1;
       }

       // fnOutputDebug("openCVedgeDetection step Sobel | xa = " + std::to_string( xa ) + " | ya = " + std::to_string( ya ) + " | ks= " + std::to_string( ks ) );
       // optimal values xa=1, ya=0, xb=0, yb=1, ks=3
       if (xa==0 && ya==0)
       {
          edgeImage = cv::Mat::zeros(grayImage.size(), CV_8UC1); // Creates a black image
       } else if (modus==2 && xa>0 && ya>0)
       {
          cv::Sobel(grayImage, gradX, CV_16S, xa, 0, ks);
          cv::Sobel(grayImage, gradY, CV_16S, 0, ya, ks);
          cv::convertScaleAbs(gradX, absGradX);
          cv::convertScaleAbs(gradY, absGradY);
          cv::addWeighted(absGradX, 0.5, absGradY, 0.5, 0, edgeImage);
       } else
       {
          cv::Sobel(grayImage, gradXY, CV_16S, xa, ya, ks);
          cv::convertScaleAbs(gradXY, edgeImage);
       }
    } else if (modus==3)
    {
       if (xa==1 && ya==1)
       {
          cv::Sobel(grayImage, gradX, CV_16S, 1, 0, cv::FILTER_SCHARR);
          cv::Sobel(grayImage, gradY, CV_16S, 0, 1, cv::FILTER_SCHARR);
          cv::convertScaleAbs(gradX, absGradX);
          cv::convertScaleAbs(gradY, absGradY);
          cv::addWeighted(absGradX, 0.5, absGradY, 0.5, 0, edgeImage);
       } else if (xa==1 && ya==0 || xa==0 && ya==1)
       {
          cv::Sobel(grayImage, gradXY, CV_16S, xa, ya, cv::FILTER_SCHARR);
          cv::convertScaleAbs(gradXY, edgeImage);
       } else 
       {
          edgeImage = cv::Mat::zeros(grayImage.size(), CV_8UC1); // Creates a black image
       }
    } else if (modus==4)
    {
       if (ks % 2 != 1)
          ks++;
       if (ks>7)
          ks = 7;
       cv::Canny(grayImage, edgeImage, xa, ya, ks);
    }

    if (postblur>0)
       cv::stackBlur(edgeImage, edgeImage, cv::Size(postblur, postblur));
    if (invert==1)
       edgeImage = 255 - edgeImage;

    if (postcontrast!=1 || postbrighten!=0)
       edgeImage.convertTo(edgeImage, -1, postcontrast, postbrighten);

    // Convert edge image to RGB
    clr = (bpp==32) ? cv::COLOR_GRAY2BGRA : cv::COLOR_GRAY2BGR;
    cv::cvtColor(edgeImage, image, clr);
    fnOutputDebug("openCVedgeDetection() done");
    return 1;
}

DLL_API int DLL_CALLCONV openCVblurFilters(unsigned char *imageData, int w, int h, int intensityX, int intensityY, int modus, int circle, int Stride, int bpp) {
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat image(h, w, clr, imageData, Stride);
    bool equal = (intensityX == intensityY) ? 1 : 0;
    if (intensityX % 2 != 1)
       intensityX++;
    if (intensityY % 2 != 1)
       intensityY++;
 
    int avg = (intensityX + intensityY)/2;
    if (avg % 2 != 1)
       avg++;
 
    if (equal==1)
       intensityX = intensityY = min(intensityX, intensityY);

    fnOutputDebug("openCVblurFilters step 1; modus = " + std::to_string( modus ) + " | inX = " + std::to_string( intensityX ) + " | inY = " + std::to_string( intensityY )  + " | w = " + std::to_string( w ) + " | h = " + std::to_string( h ) );
    int type = (circle==1) ? cv::MORPH_ELLIPSE : cv::MORPH_RECT;
    // cv::blur(image, image, cv::Size(951, 951));
    if (modus==0) {
       cv::blur(image, image, cv::Size(intensityX, intensityY));
    } else if (modus==1) {
       cv::stackBlur(image, image, cv::Size(intensityX, intensityY));
    } else if (modus==2) {
       cv::GaussianBlur(image, image, cv::Size(intensityX, intensityY), (intensityX + intensityY)/12.0f);
    } else if (modus==3) {
       cv::medianBlur(image, image, avg);
    } else if (modus==4) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::dilate(image, image, shape);
    } else if (modus==5) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::erode(image, image, shape);
    } else if (modus==6) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::morphologyEx(image, image, cv::MORPH_OPEN, shape);
    } else if (modus==7) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::morphologyEx(image, image, cv::MORPH_CLOSE, shape);
    }

    fnOutputDebug("openCVblurFilters done");
    return 1;
}

DLL_API int DLL_CALLCONV openCVresizeBlendEachChannel(unsigned char *imageData, int w, int h, int bpp, int Stride, int posX, int posY, int newWidth, int newHeight, float alpha) {
    float opacity = clamp(alpha, 0.0f, 1.0f);
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat image(h, w, clr, imageData, Stride);

    // Make sure the ROI starts within the image
    int startX = std::max(0, posX);
    int startY = std::max(0, posY);
    
    // Calculate valid width and height for the ROI
    int validWidth = std::min(newWidth - (startX - posX), image.cols - startX);
    int validHeight = std::min(newHeight - (startY - posY), image.rows - startY);
    if (validWidth <= 0 || validHeight <= 0) {
        fnOutputDebug("openCVresizeBitmap: No valid overlap between resized channel and image");
        return 0;
    }

    // Split channels
    std::vector<cv::Mat> channels;
    cv::split(image, channels);
    cv::Rect srcRoi(startX - posX, startY - posY, validWidth, validHeight);
    cv::Rect dstRoi(startX, startY, validWidth, validHeight);

    // Resize each channel
    int maxu = (bpp==32) ? 4 : 3;
    for (int channelIndex = 0; channelIndex < maxu; channelIndex++)
    {
        cv::Mat resizedChannel;
        cv::resize(channels[channelIndex], resizedChannel, cv::Size(newWidth, newHeight));
        cv::Mat blendCanvas = cv::Mat::zeros(channels[channelIndex].size(), channels[channelIndex].type());
        resizedChannel(srcRoi).copyTo(blendCanvas(dstRoi));
        cv::addWeighted(blendCanvas, opacity, channels[channelIndex], 1.0 - opacity, 0, channels[channelIndex]);
    }

    // Merge channels back into the original image
    cv::merge(channels, image);
    return 1;
}

DLL_API int DLL_CALLCONV openCVresizeBitmapExtended(unsigned char *imageData, unsigned char *otherData, int w, int h, int Stride, int rx, int ry, int rw, int rh, int nw, int nh, int mStride, int bpp, int interpolation) {
  int clr;
  if (bpp==24)
     clr = CV_8UC3;
  else if (bpp==32)
     clr = CV_8UC4;
  else if (bpp==48)
     clr = CV_16UC3;
  else if (bpp==64)
     clr = CV_16UC4;
  else if (bpp==96)
     clr = CV_32FC3;
  else if (bpp==128)
     clr = CV_32FC4;
  else return 0;

  cv::Mat image(h, w, clr, imageData, Stride);
  cv::Mat other(nh, nw, clr, otherData, mStride);

  cv::Rect subRect(rx, ry, rw, rh);
  subRect.x = min( max(0, subRect.x), w - 1);
  subRect.y = min( max(0, subRect.y), h - 1);
  subRect.width = min(subRect.width, image.cols - subRect.x);
  subRect.height = min(subRect.height, image.rows - subRect.y);
  cv::Mat cropped = image(subRect);

  try
  {
      cv::resize(cropped, other, cv::Size(nw, nh), 0, 0, interpolation);
  } catch (const cv::Exception &e)
  {
      fnOutputDebug("OpenCV: error attempting to resize bitmap in openCVresizeBitmapExtended: " + std::to_string(w) + " x " + std::to_string(h) + " to " + std::to_string(rw) + " x " + std::to_string(rh));
      fnOutputDebug( e.what() );
      return 0;
  }
  return 1;
}

static int coreOpenCVapplyToneMappingAlgos(float* hdrData, int hStride, int width, int height, unsigned char* ldrData, int lStride, int algo, float paramA, float paramB, float paramC, float addExposure, int altModeExposure) {
// the tone-mapping algorithms do not give correct results with 4 channels [RGBA]

    // fnOutputDebug("openCVapplyToneMappingAlgos: hStride=" + std::to_string(hStride));
    cv::Mat hdrImage(height, width, CV_32FC3, hdrData, hStride);
    cv::Mat ldrFinal(height, width, CV_8UC3, ldrData, lStride);
    // fnOutputDebug("openCVapplyToneMappingAlgos: hdrStride=" + std::to_string(hdrImage.step) + " // ldrStride=" + std::to_string(ldrFinal.step));
    cv::Mat ldrImage;
    if (algo==0)
    {
       cv::Ptr<cv::TonemapDrago> Drago = cv::createTonemapDrago(paramA, paramB, paramC);
       Drago->process(hdrImage, ldrImage);
    } else if (algo==1)
    {
       cv::Ptr<cv::TonemapReinhard> reinhard = cv::createTonemapReinhard(paramA, paramB, paramC, 0);
       reinhard->process(hdrImage, ldrImage);
    } else if (algo==2)
    {
       cv::Ptr<cv::Tonemap> tnmp = cv::createTonemap(paramA);
       tnmp->process(hdrImage, ldrImage);
    } else
    {
       cv::Ptr<cv::TonemapMantiuk> mantiuk = cv::createTonemapMantiuk(paramA, paramB, paramC);
       mantiuk->process(hdrImage, ldrImage);
    }

    if (addExposure>0.002)
    {
       float p = (addExposure + 0.33f) * 3.0f;
       if (altModeExposure==1)
          cv::scaleAdd(hdrImage, addExposure, ldrImage, ldrImage);
       else if (p>1.001)
          cv::normalize(ldrImage, ldrImage, 0.0f, p, cv::NORM_MINMAX);
    }

    // fnOutputDebug("openCVapplyToneMappingAlgos: addExposure=" + std::to_string(addExposure));
    ldrImage = ldrImage * 255.0f;
    ldrImage.convertTo(ldrFinal, CV_8UC3);
    cv::cvtColor(ldrFinal, ldrFinal, cv::COLOR_RGB2BGR);
    return 1;
}

// nothing may be thrown out of an exported function, and the thumbnail pool calls this one directly:
// Drago asserts on an all-black image, and any of the algorithms can run out of memory
DLL_API int DLL_CALLCONV openCVapplyToneMappingAlgos(float* hdrData, int hStride, int width, int height, unsigned char* ldrData, int lStride, int algo, float paramA, float paramB, float paramC, float addExposure, int altModeExposure) {
    try
    {
        return coreOpenCVapplyToneMappingAlgos(hdrData, hStride, width, height, ldrData, lStride, algo, paramA, paramB, paramC, addExposure, altModeExposure);
    } catch (...)
    {
        return 0;
    }
}

DLL_API uintptr_t DLL_CALLCONV ListProcessMemoryBlocks(int a) {
    // Get system information to know memory ranges
    fnOutputDebug("ListProcessMemoryBlocks A");
    SYSTEM_INFO sysInfo;
    GetSystemInfo(&sysInfo);

    // Start from the minimum application address
    LPVOID address = sysInfo.lpMinimumApplicationAddress;
    
    // Store results
    struct MemoryBlock {
        void* address;
        SIZE_T size;
        DWORD state;
        DWORD protect;
    };
    std::vector<MemoryBlock> blocks;
    int mi = 0;

    fnOutputDebug("ListProcessMemoryBlocks B");
    // Query memory regions until we reach maximum address
    while(address < sysInfo.lpMaximumApplicationAddress) {
        MEMORY_BASIC_INFORMATION memInfo;
        SIZE_T result = VirtualQuery(address, &memInfo, sizeof(memInfo));
        
        if(result == 0) {
            break; // Query failed
        }
        mi++;

        // Only show committed memory (actually allocated blocks)
        if(memInfo.State == MEM_COMMIT && memInfo.Protect == 4 && memInfo.RegionSize>987654) {
            blocks.push_back({
                memInfo.BaseAddress,
                memInfo.RegionSize,
                memInfo.State,
                memInfo.Protect
            });
        }

        // Move to next region
        address = (LPVOID)((DWORD_PTR)address + memInfo.RegionSize);
    }

    // Sort blocks by size in descending order
    std::sort(blocks.begin(), blocks.end(), 
        [](const MemoryBlock& a, const MemoryBlock& b) {
            return a.size > b.size;
        });

    // Print results
    fnOutputDebug("ListProcessMemoryBlocks C; mi=" + std::to_string(mi));
    fnOutputDebug("Memory Blocks...");
    fnOutputDebug("Address, Size");
    int index = 0;
    for(const auto& block : blocks) {
        index++;
        fnOutputDebug( std::to_string(index) + " = " 
                     + std::to_string( (uintptr_t)block.address ) + ", "
                     + std::to_string(block.size) + ", " );
    }
    fnOutputDebug("ListProcessMemoryBlocks D; index=" + std::to_string(index));
    if (blocks.empty())
       return 0;
    return (uintptr_t)blocks[0].address;
}

DLL_API int DLL_CALLCONV PixelateHugeBitmap(unsigned char *originalData, int w, int h, int Stride, int bpp, int maskOpacity, int blendMode, int flipLayers, int keepAlpha, int linearGamma, unsigned char *newBitmap, int StrideMini, int mw, int mh) {
    if (maskOpacity<2)
       return 1;

    std::vector<int> pixelzMapW(w + 2, 0);
    std::vector<int> pixelzMapH(h + 2, 0);
    int bmpX, bmpY, bmpW, bmpH;
    smallBitmapArea(w, h, bmpX, bmpY, bmpW, bmpH);
    for (int x = 0; x < w + 1; x++)
        pixelzMapW[x] = clamp( (float)mw*((x - bmpX)/(float)bmpW), 0.0f, (float)mw - 1.0f);

    for (int y = 0; y < h + 1; y++)
        pixelzMapH[y] = clamp( (float)mh*((y - bmpY)/(float)bmpH), 0.0f, (float)mh - 1.0f);
    // fnOutputDebug("PixelateHugeBitmap step 1; min = " + std::to_string( pixelzMapW[0] ) + " x " + std::to_string( pixelzMapH[0] ));
    // fnOutputDebug("PixelateHugeBitmap step 1; max = " + std::to_string( pixelzMapW[w] ) + " x " + std::to_string( pixelzMapH[h] ));
    maskOpacity = 255 - maskOpacity;
    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        int py = pixelzMapH[y];
        INT64 ky_mini = (INT64)py * StrideMini;
        for (int x = 0; x < w; x++)
        {
            if (clipMaskFilter(x, y, NULL, 0)==1)
               continue;

            int px = pixelzMapW[x];
            if (px>=mw || py>=mh)
               continue;

            INT64 on = ky_mini + (INT64)px * bpc;
            INT64 o = ky + (INT64)x * bpc;
            int nA = (bpp==32) ? newBitmap[3 + on] : 255;
            int oA = (bpp==32) ? originalData[3 + o] : 255;
            RGBAColor Orgb = {newBitmap[on], newBitmap[1 + on], newBitmap[2 + on], nA};
            RGBAColor Brgb = {originalData[o], originalData[1 + o], originalData[2 + o], oA};
            RGBAColor newColor = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, keepAlpha, bpp, maskOpacity);
            originalData[2 + o] = newColor.r;
            originalData[1 + o] = newColor.g;
            originalData[o]     = newColor.b;
            if (bpp==32)
               originalData[3 + o] = newColor.a;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV DrawTextBitmapInPlace(unsigned char *originalData, int w, int h, int Stride, int bpp, int opacity, int linearGamma, int blendMode, int flipLayers, int keepAlpha, unsigned char *newBitmap, int StrideMini, int nbpp, int imgX, int imgY, int imgW, int imgH) {
    const int aA = (StrideMini >> 24) & 0xFF;
    const int rA = (StrideMini >> 16) & 0xFF;
    const int gA = (StrideMini >> 8) & 0xFF;
    const int bA = StrideMini & 0xFF;

    const INT64 data = CalcPixOffset(w - 1, h - 1, Stride, bpp);
    // fnOutputDebug("yay DrawTextBitmapInPlace; y = " + std::to_string(imgY));
    const int bpc = bpp / 8;
    const int nbpc = nbpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < imgH; y++)
    {
        INT64 ky_mini = (INT64)y * StrideMini;
        INT64 ky = (INT64)(h - imgY + y - imgH) * Stride;
        for (int x = 0; x < imgW; x++)
        {
            int nR, nG, nB;
            int nA = 255;
            int oA = 255;
            INT64 o = ky + (INT64)(imgX + x) * bpc;
            if (o>data || o<0) // data is the offset of the last valid pixel, inclusive
               continue;

            if (newBitmap!=NULL)
            {
                INT64 on = ky_mini + (INT64)x * nbpc;
                if (nbpp==32)
                   nA = newBitmap[on + 3];

                nR = newBitmap[2 + on];
                nG = newBitmap[1 + on];
                nB = newBitmap[on];
            } else
            {
                nR = rA;
                nG = gA;
                nB = bA;
                nA = aA;
            }

            if (bpp==32)
               oA = originalData[3 + o];
            if (oA<1 && bpp==32)
            {
                // the alpha CalculateNewBlendModes() gives over a transparent pixel; opacity is subtractive
                originalData[3 + o] = clamp((nA * (255 - opacity)) / 255, 0, 255);
                originalData[2 + o] = nR;
                originalData[1 + o] = nG;
                originalData[o] = nB;
                continue;
            }

            int oR = originalData[2 + o];
            int oG = originalData[1 + o];
            int oB = originalData[o];
            RGBAColor Orgb = {nB, nG, nR, nA};
            RGBAColor Brgb = {oB, oG, oR, oA};
            RGBAColor newColor = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, keepAlpha, bpp, opacity);
            originalData[2 + o] = newColor.r;
            originalData[1 + o] = newColor.g;
            originalData[o]     = newColor.b;
            if (bpp==32)
               originalData[3 + o] = newColor.a;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV UndoAiderSwapPixelRegions(unsigned char* BitmapData, int w, int h, const INT64 Stride, unsigned char* otherData, const INT64 mStride, int bpp, const int x1, const int y1, const int x2, const int y2) {
    const INT64 bytesPerPixel = (bpp==32) ? 4 : 3;
    const INT64 opx = x1 * bytesPerPixel;
    const INT64 chunk = (x2 - x1) * bytesPerPixel;
    if (chunk<0)
       return 0;

    // swapped in place: an exception cannot leave an OpenMP loop, so a failed allocation here would end the process
    #pragma omp parallel for schedule(dynamic) default(none)
    for (int y = y1; y < y2; y++)
    {
            INT64 o = y * Stride + opx;
            INT64 n = (y - y1) * mStride;
            std::swap_ranges(&BitmapData[o], &BitmapData[o] + chunk, &otherData[n]);
    }
    return 1;
}

DLL_API int DLL_CALLCONV ColorizeGrayImage(unsigned char *originalData, int w, int h, int Stride, int bpp, int linearGamma, int colorA, int colorB) {
    const int aB = (colorB >> 24) & 0xFF;
    const int rB = (colorB >> 16) & 0xFF;
    const int gB = (colorB >> 8) & 0xFF;
    const int bB = colorB & 0xFF;
    const int aA = (colorA >> 24) & 0xFF;
    const int rA = (colorA >> 16) & 0xFF;
    const int gA = (colorA >> 8) & 0xFF;
    const int bA = colorA & 0xFF;

    const int bpc = bpp / 8;
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < h; y++)
    {
        INT64 ky = (INT64)y * Stride;
        for (int x = 0; x < w; x++)
        {
            INT64 o = ky + (INT64)x * bpc;
            float fintensity = char_to_float[originalData[o]];
            if (linearGamma==1)
            {
               originalData[2 + o] = linear_to_gamma[weighTwoValues(gamma_to_linear[rA], gamma_to_linear[rB], fintensity)];
               originalData[1 + o] = linear_to_gamma[weighTwoValues(gamma_to_linear[gA], gamma_to_linear[gB], fintensity)];
               originalData[o]     = linear_to_gamma[weighTwoValues(gamma_to_linear[bA], gamma_to_linear[bB], fintensity)];
            } else
            {
               originalData[2 + o] = weighTwoValues(rA, rB, fintensity);
               originalData[1 + o] = weighTwoValues(gA, gB, fintensity);
               originalData[o]     = weighTwoValues(bA, bB, fintensity);
            }

            if (bpp==32)
               originalData[3 + o] = weighTwoValues(aA, aB, fintensity);
        }
    }
    return 1;
}

// WIC decoding; the PDF and SVG readers and both pools below use its guards and helpers
#include "wic-loader.h"

// PDFium: bookmarks, text and pages; thumbs-pool.h and dupes-pixels.h render pages through it
#include "pdfium-reader.h"

// SVG through Direct2D; thumbs-pool.h draws its SVG thumbnails with LoadSVGimageEx()
#include "svg-render.h"

// multi-threaded thumbnails generator; it must sit here because it calls LoadSVGimage(),
// coreRenderPdfPageAsBitmap(), adaptImageGivenSize() and the openCV* helpers defined above
#include "thumbs-pool.h"

// the fingerprint / histogram collector; it reuses the thumbnails pool's two loaders and
// its extension sets, so it has to come after them
#include "dupes-pixels.h"

// The PDF writer of "Join images into a single file"; its GDI+ and OpenCV part follows.
#include "pdf-writer.h"

// Adds a page that shows a GDI+ bitmap: scaled down to rasterW x rasterH when it is larger
// [the pixels are never enlarged; the PDF reader does that], laid over bgColor where it is
// transparent and stored as a JPEG of the given quality. The caller keeps the bitmap.
// Returns PDFW_ADDED, PDFW_SKIPPED [the document stays as it was] or PDFW_LOST.
DLL_API int DLL_CALLCONV PdfWriterAddBitmap(PdfWriter *w, Gdiplus::GpBitmap *bmp, int rasterW, int rasterH, int quality, double pageW, double pageH, double x, double y, double width, double height, UINT bgColor) {
    static CLSID jpegEncoder;
    static int hasEncoder = 0;
    if (!pdfwValid(w) || w->failed)
       return PDFW_LOST;

    const PdfwPlace p = { pageW, pageH, x, y, width, height, bgColor, 1 };
    UINT srcW = 0, srcH = 0;
    if (bmp==NULL || !pdfwPlaceUsable(p)
        || Gdiplus::DllExports::GdipGetImageWidth(bmp, &srcW)!=Gdiplus::Ok
        || Gdiplus::DllExports::GdipGetImageHeight(bmp, &srcH)!=Gdiplus::Ok || srcW==0 || srcH==0)
       return PDFW_SKIPPED;

    if (hasEncoder==0)
    {
       UINT count = 0, size = 0;
       Gdiplus::DllExports::GdipGetImageEncodersSize(&count, &size);
       std::vector<BYTE> list(size + 1);
       Gdiplus::ImageCodecInfo *codecs = (Gdiplus::ImageCodecInfo*)list.data();
       if (size>0 && Gdiplus::DllExports::GdipGetImageEncoders(count, size, codecs)==Gdiplus::Ok)
       {
          for (UINT i = 0; i < count; i++)
          {
              if (codecs[i].MimeType!=NULL && wcscmp(codecs[i].MimeType, L"image/jpeg")==0)
              {
                 jpegEncoder = codecs[i].Clsid;
                 hasEncoder = 1;
                 break;
              }
          }
       }

       if (hasEncoder==0)
       {
          fnOutputDebug("PdfWriterAddBitmap: GDI+ has no JPEG encoder");
          return PDFW_SKIPPED;
       }
    }

    UINT rw = (rasterW<1) ? 1 : std::min<UINT>((UINT)rasterW, srcW);
    UINT rh = (rasterH<1) ? 1 : std::min<UINT>((UINT)rasterH, srcH);
    // the JPEG encoder takes no side over 65500 px: the raster shrinks to fit, the page keeps its size
    const UINT jpegMax = 65500;
    if (rw>jpegMax || rh>jpegMax)
    {
       if (rw>=rh)
       {
          rh = std::max<UINT>(1, (UINT)((UINT64)rh * jpegMax / rw));
          rw = jpegMax;
       } else
       {
          rw = std::max<UINT>(1, (UINT)((UINT64)rw * jpegMax / rh));
          rh = jpegMax;
       }
    }

    Gdiplus::Rect rect(0, 0, (INT)srcW, (INT)srcH);
    Gdiplus::BitmapData bd;
    if (Gdiplus::DllExports::GdipBitmapLockBits(bmp, &rect, Gdiplus::ImageLockModeRead, PixelFormat32bppPARGB, &bd)!=Gdiplus::Ok)
       return PDFW_SKIPPED;

    bool locked = true;
    int result = PDFW_SKIPPED;
    IStream *stream = NULL;
    Gdiplus::GpBitmap *rgbBitmap = NULL;
    std::vector<BYTE> topDown, scaled, rgb;
    try
    {
       const BYTE *px = (const BYTE*)bd.Scan0;
       int stride = bd.Stride;
       if (stride<0)
       {
          // a bottom-up bitmap; OpenCV wants the rows top-down in memory
          topDown.resize((size_t)srcW * 4 * srcH);
          for (UINT row = 0; row < srcH; row++)
              memcpy(&topDown[(size_t)row * srcW * 4], px + (ptrdiff_t)row * stride, (size_t)srcW * 4);
          px = topDown.data();
          stride = (int)srcW * 4;
       }

       if (rw!=srcW || rh!=srcH)
       {
          // premultiplied, so that transparent pixels add nothing to their neighbours
          scaled.resize((size_t)rw * 4 * rh);
          const cv::Mat src(srcH, srcW, CV_8UC4, (void*)px, (size_t)stride);
          cv::Mat dst(rh, rw, CV_8UC4, scaled.data(), (size_t)rw * 4);
          cv::resize(src, dst, dst.size(), 0, 0, cv::INTER_AREA);
          px = scaled.data();
          stride = (int)rw * 4;
       }

       const int rgbStride = (int)((rw * 3 + 3) & ~3u);
       rgb.resize((size_t)rgbStride * rh);
       pdfwOverColor(px, stride, rw, rh, bgColor, rgb.data(), rgbStride);
       Gdiplus::DllExports::GdipBitmapUnlockBits(bmp, &bd);
       locked = false;

       if (Gdiplus::DllExports::GdipCreateBitmapFromScan0((INT)rw, (INT)rh, rgbStride, PixelFormat24bppRGB, rgb.data(), &rgbBitmap)==Gdiplus::Ok
           && CreateStreamOnHGlobal(NULL, TRUE, &stream)==S_OK)
       {
          static const GUID encoderQuality = { 0x1d5be4b5, 0xfa4a, 0x452d, { 0x9c, 0xdd, 0x5d, 0xb3, 0x51, 0x05, 0xe7, 0xeb } };
          ULONG q = (ULONG)std::min<int>(std::max<int>(quality, 1), 100);
          Gdiplus::EncoderParameters params;
          params.Count = 1;
          params.Parameter[0].Guid = encoderQuality;
          params.Parameter[0].Type = Gdiplus::EncoderParameterValueTypeLong;
          params.Parameter[0].NumberOfValues = 1;
          params.Parameter[0].Value = &q;
          STATSTG st;
          HGLOBAL mem = NULL;
          if (Gdiplus::DllExports::GdipSaveImageToStream(rgbBitmap, stream, &jpegEncoder, &params)==Gdiplus::Ok
              && stream->Stat(&st, STATFLAG_NONAME)==S_OK && GetHGlobalFromStream(stream, &mem)==S_OK)
          {
             const BYTE *jpeg = (const BYTE*)GlobalLock(mem);
             if (jpeg!=NULL)
             {
                result = pdfwAddJpegData(w, jpeg, (size_t)st.cbSize.QuadPart, p);
                GlobalUnlock(mem);
             }
          } else fnOutputDebug("PdfWriterAddBitmap: GDI+ failed to encode the page");
       }
    } catch (...)
    {
       fnOutputDebug("PdfWriterAddBitmap: failed to prepare the page");
       result = PDFW_SKIPPED;
    }

    if (locked)
       Gdiplus::DllExports::GdipBitmapUnlockBits(bmp, &bd);
    if (rgbBitmap!=NULL)
       Gdiplus::DllExports::GdipDisposeImage(rgbBitmap);
    if (stream!=NULL)
       stream->Release();
    return w->failed ? PDFW_LOST : result;
}

Gdiplus::GpBitmap* CreateGdipBitmapFromCImg(CImg<float> & img, int width, int height) {
    // fnOutputDebug("CreateGdipBitmapFromCImg called, yay");
    // Size of a scan line represented in bytes: 4 bytes each pixel
    UINT cbStride = 0;
    UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);

    // Size of the image, represented in bytes
    UINT cbBufferSize = 0;
    UIntMult(cbStride, height, &cbBufferSize);

    Gdiplus::GpBitmap  *myBitmap = NULL;
    BYTE *m_pbBuffer = NULL;  // the GDI+ bitmap buffer
    m_pbBuffer = new (std::nothrow) BYTE[cbBufferSize];
    if (m_pbBuffer==nullptr)
       return myBitmap;

    // fnOutputDebug("gdip bmp created, yay");
    Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, cbStride, PixelFormat32bppARGB, NULL, &myBitmap);
    Gdiplus::Rect rectu(0, 0, width, height);
    Gdiplus::BitmapData bitmapDatu;
    bitmapDatu.Width = width;
    bitmapDatu.Height = height;
    bitmapDatu.Stride = cbStride;
    bitmapDatu.PixelFormat = PixelFormat32bppARGB;
    bitmapDatu.Scan0 = m_pbBuffer;
    const int nPlanes = 4; // NOTE we assume alpha plane is the 4th plane.
 
    Gdiplus::Status s = Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, 6, PixelFormat32bppARGB, &bitmapDatu);
    // Step through cimg and bitmap, copy values to bitmap.
    if (s == Gdiplus::Ok)
    {
        // fnOutputDebug("gdip bmp locked, yay");
        // fnOutputDebug("init vars for conversion; Stride=" + std::to_string(dLineDest));
        BYTE *pStartDest = (BYTE *) bitmapDatu.Scan0;
        UINT dPixelDest = nPlanes;             // pixel step in destination
        UINT dLineDest = bitmapDatu.Stride;    // line step in destination
        #pragma omp parallel for schedule(dynamic)
        for (int y = 0; y < height; y++)
        {
            // loop through lines
            BYTE *pLineDest  = pStartDest + dLineDest*y;
            BYTE *pPixelDest = pLineDest;
            for (int x = 0; x < width; x++)
            {
                // loop through pixels on line
                // T & operator() (const unsigned int x, const unsigned int y=0, const unsigned int z=0, const unsigned int v=0) const
                // Fast access to pixel value for reading or writing.
                float    redCompF = img(x,y,0,0);
                if (redCompF < 0.0f)
                    redCompF = 0.0f;
                else if (redCompF > 255.0f)
                    redCompF = 255.0f;

                float    greenCompF = img(x,y,0,1);
                if (greenCompF < 0.0f)
                    greenCompF = 0.0f;
                else if (greenCompF > 255.0f)
                    greenCompF = 255.0f;

                float    blueCompF = img(x,y,0,2);
                if (blueCompF < 0.0f)
                    blueCompF = 0.0f;
                else if (blueCompF > 255.0f)
                    blueCompF = 255.0f;

                float    alphaCompF = img(x,y,0,3);
                if (alphaCompF < 0.0f)
                    alphaCompF = 0.0f;
                else if (alphaCompF > 255.0f)
                    alphaCompF = 255.0f;

                BYTE    redComp = BYTE(redCompF + 0.4999f);
                BYTE    greenComp = BYTE(greenCompF + 0.4999f);
                BYTE    blueComp = BYTE(blueCompF + 0.4999f);
                BYTE    alphaComp = BYTE(alphaCompF + 0.4999f);
                *(pPixelDest) = blueComp;
                *(pPixelDest+1) = greenComp;
                *(pPixelDest+2) = redComp;
                *(pPixelDest+3) = alphaComp;
                pPixelDest += dPixelDest;
            }
            // pLineDest += dLineDest;
        }
        // fnOutputDebug("for loops done");
        Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
        // fnOutputDebug("gdip bmp unlocked");
    }
    delete[] m_pbBuffer;
    m_pbBuffer = NULL; 

    return myBitmap;
}

void FillGdipLockedBitmapDataFromCImg(unsigned char *imageData, CImg<unsigned char> &img, int width, int height, int Stride, int bpp) {
    #pragma omp parallel for schedule(dynamic)
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            INT64 o = CalcPixOffset(x, y, Stride, bpp);
            imageData[o]     = img(x,y,0,0); // b
            imageData[o + 1] = img(x,y,0,1); // g
            imageData[o + 2] = img(x,y,0,2); // r
            if (bpp==32)
               imageData[o + 3] = img(x,y,0,3); // a
        }
    }
}

int FillCImgFromBitmap(cimg_library::CImg<float> & img, Gdiplus::GpBitmap *myBitmap, int width, int height) {

    // fnOutputDebug("FillCImgFromBitmap called, yay");
    // Size of a scan line represented in bytes: 4 bytes each pixel
    UINT cbStride = 0;
    UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);

    // Size of the image, represented in bytes
    UINT cbBufferSize = 0;
    UIntMult(cbStride, height, &cbBufferSize);

    Gdiplus::Rect rectu(0, 0, width, height);
    Gdiplus::BitmapData bitmapDatu;
    Gdiplus::Status s = Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, 1, PixelFormat32bppARGB, &bitmapDatu);
    // fnOutputDebug("bits locked: FillCImgFromBitmap()");
    if (s == Gdiplus::Ok)
    {
        // fnOutputDebug("for loops begin: FillCImgFromBitmap(); w=" + std::to_string(nPixels) + "; h=" + std::to_string(nLines) );
        // fnOutputDebug("moar; Stride=" + std::to_string(dLineSrc) + "/scan0=" + std::to_string(*pStartSrc));
        BYTE *pStartSrc = (BYTE *) bitmapDatu.Scan0;
        UINT dPixelSrc = 4;          // pixel step in source ; nPlanes
        UINT dLineSrc = cbStride;    // line step in source
        #pragma omp parallel for schedule(dynamic)
        for (int y = 0; y < height; y++)
        {
            // loop through lines
            BYTE *pLineSrc = pStartSrc + dLineSrc*y;
            BYTE *pPixelSrc = pLineSrc;
            // fnOutputDebug("Y loop: " + std::to_string(y) + "//Stride=" + std::to_string(dLineSrc));
            for (int x = 0; x < width; x++)
            {
                // loop through pixels on line
                BYTE alphaComp = *(pPixelSrc+3);
                BYTE redComp = *(pPixelSrc+2);
                BYTE greenComp = *(pPixelSrc+1);
                BYTE blueComp = *(pPixelSrc+0);
                img(x,y,0,0) = float(redComp);
                img(x,y,0,1) = float(greenComp);
                img(x,y,0,2) = float(blueComp);
                img(x,y,0,3) = float(alphaComp);
                pPixelSrc += dPixelSrc;
                // fnOutputDebug("x loop B: " + std::to_string(x));
            }
            // pLineSrc += dLineSrc;
        }
        // fnOutputDebug("for loops done: FillCImgFromBitmap()");
        Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
        // fnOutputDebug("gdip bmp unlocked: FillCImgFromBitmap()");
        return 1;
    } else return 0;
}

DLL_API int DLL_CALLCONV cImgAddGaussianNoiseOnBitmap(unsigned char *imageData, int width, int height, int intensity, int Stride, int bpp) {
  int channels = (bpp==32) ? 4 : 3;
  CImg<unsigned char> img(imageData, channels, width, height, 1);
  img.permute_axes("yzcx");
  img.noise(intensity, 0);
  FillGdipLockedBitmapDataFromCImg(imageData, img, width, height, Stride, bpp);
  return 1;
}

DLL_API int DLL_CALLCONV cImgSharpenBitmap(unsigned char *imageData, int width, int height, int intensity, int Stride, int bpp) {
  // inverse diffusion; neighbours count by their opacity, transparent pixels and alpha are left as they are
  const int nc = bpp/8;
  if (imageData==NULL || width<1 || height<1 || (bpp!=32 && bpp!=24) || Stride<width*nc)
     return 0;

  std::vector<unsigned char> src;
  std::vector<float> rowVmax;
  std::vector<int> rowLo, rowHi;
  try {
      src.assign(imageData, imageData + (size_t)Stride*height);
      rowVmax.assign(height, 0.0f);
      rowLo.assign(height, 255);
      rowHi.assign(height, 0);
  } catch (const std::bad_alloc&) {
      return 0;
  }

  float opacity[256];
  for (int a = 0; a < 256; a++)
      opacity[a] = a / 255.0f;

  // the 4 neighbours laplacian; a neighbour past the edges is the pixel itself, which adds nothing
  auto velocity = [&](const unsigned char *p, const int x, const int y, float v[3]) {
      const int l = (x>0) ? -nc : 0, r = (x<width - 1) ? nc : 0;
      const int u = (y>0) ? -Stride : 0, d = (y<height - 1) ? Stride : 0;
      const float wl = (nc==4) ? opacity[p[l + 3]] : 1.0f, wr = (nc==4) ? opacity[p[r + 3]] : 1.0f;
      const float wu = (nc==4) ? opacity[p[u + 3]] : 1.0f, wd = (nc==4) ? opacity[p[d + 3]] : 1.0f;
      for (int c = 0; c < 3; c++)
          v[c] = wl * (float)(p[c] - p[l + c]) + wr * (float)(p[c] - p[r + c])
               + wu * (float)(p[c] - p[u + c]) + wd * (float)(p[c] - p[d + c]);
  };

  #pragma omp parallel for schedule(dynamic)
  for (int y = 0; y < height; y++)
  {
      float vm = 0;
      int lo = 255, hi = 0;
      for (int x = 0; x < width; x++)
      {
          const unsigned char *p = &src[CalcPixOffset(x, y, Stride, bpp)];
          if (nc==4 && p[3]==0)
             continue;

          float v[3];
          velocity(p, x, y, v);
          for (int c = 0; c < 3; c++)
          {
              const float av = fabs(v[c]);
              if (av>vm)
                 vm = av;
              if (p[c]<lo)
                 lo = p[c];
              if (p[c]>hi)
                 hi = p[c];
          }
      }
      rowVmax[y] = vm;
      rowLo[y] = lo;
      rowHi[y] = hi;
  }

  float vmax = 0;
  int lo = 255, hi = 0;
  for (int y = 0; y < height; y++)
  {
      vmax = max(vmax, rowVmax[y]);
      lo = min(lo, rowLo[y]);
      hi = max(hi, rowHi[y]);
  }

  if (vmax<=0)
     return 1;

  // results stay within [darkest visible colour, 255], or the brightest colour in 24 bits
  const float lowest = (float)lo, highest = (nc==4) ? 255.0f : (float)hi;
  const float f = (float)intensity / vmax;
  #pragma omp parallel for schedule(dynamic)
  for (int y = 0; y < height; y++)
  {
      for (int x = 0; x < width; x++)
      {
          const INT64 o = CalcPixOffset(x, y, Stride, bpp);
          if (nc==4 && src[o + 3]==0)
             continue;

          float v[3];
          velocity(&src[o], x, y, v);
          for (int c = 0; c < 3; c++)
          {
              float t = v[c] * f;
              t += src[o + c];
              imageData[o + c] = (unsigned char)((t<=lowest) ? lowest : (t>=highest) ? highest : t);
          }
      }
  }
  return 1;
}

DLL_API int DLL_CALLCONV cImgBlurBitmapFilters(unsigned char *imageData, int width, int height, int intensityX, int intensityY, int modus, int circle, int preview, int Stride, int bpp) {
  int ow = width;  int oh = height;
  int channels = (bpp==32) ? 4 : 3;
  fnOutputDebug("cImgBlurBitmapFilters invoked | modus = " + std::to_string(modus));
  CImg<unsigned char> img(imageData, channels, width, height, 1);
  // If I set is_Shared==1, it does not work; no idea why; it results in a messed up image.
  // Note: I pass the wrong parameters and then i fix it with permute_axes().
  // It should be CImg<unsigned char> img(imageData, width, height, 1, channels), but I get a messed up image.

  img.permute_axes("yzcx");
  if (preview==1)
  {
     width /=2;          height /=2;
     intensityX /=2;     intensityY /=2;
     img.resize(width,height, -100, -100, 3);
  }

  CImg<unsigned char> shape(intensityX,intensityX,1,3,0);
  const unsigned char clr[] = {254, 254, 254};
  if (circle==1)
  {
     shape.draw_circle(intensityX/2, intensityX/2, intensityX/2, clr);
     // shape.blur(3, 3, 0, 1, 3);
     if (intensityX!=intensityY)
        shape.resize(intensityX, intensityY);
  }

  if (modus==1)
  {
     img.blur_box(intensityX, intensityY, 0, 3);
  } else if (modus==2)
  {
     if (circle==1)
        img.dilate(shape);
     else
        img.dilate(intensityX, intensityY, 1);
  } else if (modus==3)
  {
     if (circle==1)
        img.erode(shape);
     else
        img.erode(intensityX, intensityY, 1);
  } else if (modus==4)
  {
     if (circle==1)
        img.opening(shape);
     else
        img.opening(intensityX, intensityY, 1);
  } else if (modus==5)
  {
     if (circle==1)
        img.closing(shape);
     else
        img.closing(intensityX, intensityY, 1);
  } else
  {
     img.blur(intensityX, intensityY, 0, 1, 3);
  }

  if (circle==1)
     img.blur(3, 3, 0, 1, 3);

  if (preview==1)
     img.resize(ow, oh, -100, -100, 3);

  FillGdipLockedBitmapDataFromCImg(imageData, img, ow, oh, Stride, bpp);
  return 1;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV cImgResizeBitmap(Gdiplus::GpBitmap *myBitmap, int width, int height, int resizedW, int resizedH, int interpolation, int bond) {
  // function invoked by QPV_ResizeBitmap() from AHK
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;

  img.resize(resizedW, resizedH, -100, -100, interpolation, bond);

  newBitmap = CreateGdipBitmapFromCImg(img, img.width(), img.height());
  return newBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV GenerateCIMGnoiseBitmap(int width, int height, int intensity, int details, int scale, int blurX, int blurY, int doBlur) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);

  img.draw_plasma((float)intensity/2.0f, (float)details/2.0f, (float)scale/9.5f);
  if (doBlur==1)
     img.blur(blurX, blurY, 0, 1, 2);

  newBitmap = CreateGdipBitmapFromCImg(img, width, height);
  return newBitmap;
}

DLL_API int DLL_CALLCONV dissolveBitmap(int *imageData, int *newData, int Width, int Height, int rx, int ry) {
      // fnOutputDebug("maxR===" + std::to_string(maxuRadius) + "; rS=" + std::to_string(rScale) + "; imgAR=" + std::to_string(imgAR));
      if (rx<1) rx = 1; // radius 0 would be a modulo-by-zero below
      if (ry<1) ry = 1;
      const UINT maxPixels = Width + Height * Width;
      MaskBitMap pixelzMap; // bit-packed with atomic writes; std::vector<bool> races between OpenMP threads
      pixelzMap.resize(maxPixels);
      time_t nTime;
      time(&nTime);

      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         unsigned int rngState = (unsigned int)nTime ^ (2654435761u * (unsigned int)(y + 1));
         if (rngState==0)
            rngState = 0x9E3779B9u;
         for (int x = 0; x < Width; x++)
         {
            int gx = (int)(qpvThreadRand(rngState) % (rx*2)) - rx;
            int gy = (int)(qpvThreadRand(rngState) % (ry*2)) - ry;
            int dx = clamp(x + gx, 0, Width - 1);
            int dy = clamp(y + gy, 0, Height - 1);
            if (pixelzMap[dx + dy*Width]==1)
            {
               gx = (int)(qpvThreadRand(rngState) % (rx*2)) - rx;
               gy = (int)(qpvThreadRand(rngState) % (ry*2)) - ry;
               dx = clamp(x + gx, 0, Width - 1);
               dy = clamp(y + gy, 0, Height - 1);
            }

            pixelzMap[dx + dy*Width] = 1;
            newData[x + y*Width] = imageData[dx + (dy * Width)];
         }
      }

      if (rx>35 || ry>35)
      {
          #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
          for (int y = 0; y < Height; y++)
          {
             unsigned int rngState = (unsigned int)nTime ^ (2654435761u * (unsigned int)(y + 1)) ^ 0x55555555u;
             if (rngState==0)
                rngState = 0x9E3779B9u;
             for (int x = 0; x < Width; x++)
             {
                int gx = (int)(qpvThreadRand(rngState) % (rx*2)) - rx;
                int gy = (int)(qpvThreadRand(rngState) % (ry*2)) - ry;
                int dx = clamp(x + gx, 0, Width - 1);
                int dy = clamp(y + gy, 0, Height - 1);
                if (pixelzMap[dx + dy*Width]==1)
                {
                   gx = (int)(qpvThreadRand(rngState) % (rx*2)) - rx;
                   gy = (int)(qpvThreadRand(rngState) % (ry*2)) - ry;
                   dx = clamp(x + gx, 0, Width - 1);
                   dy = clamp(y + gy, 0, Height - 1);
                }

                pixelzMap[dx + dy*Width] = 1;
                newData[x + y*Width] = imageData[dx + (dy * Width)];
            }
          }
      }

      if (rx>350 || ry>350)
      {
          #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
          for (int y = 0; y < Height; y++)
          {
             unsigned int rngState = (unsigned int)nTime ^ (2654435761u * (unsigned int)(y + 1)) ^ 0xAAAAAAAAu;
             if (rngState==0)
                rngState = 0x9E3779B9u;
             for (int x = 0; x < Width; x++)
             {
                int gx = (int)(qpvThreadRand(rngState) % (rx*2)) - rx;
                int gy = (int)(qpvThreadRand(rngState) % (ry*2)) - ry;
                int dx = clamp(x + gx, 0, Width - 1);
                int dy = clamp(y + gy, 0, Height - 1);
                if (pixelzMap[dx + dy*Width]==1)
                {
                   gx = (int)(qpvThreadRand(rngState) % (rx*2)) - rx;
                   gy = (int)(qpvThreadRand(rngState) % (ry*2)) - ry;
                   dx = clamp(x + gx, 0, Width - 1);
                   dy = clamp(y + gy, 0, Height - 1);
                }

                pixelzMap[dx + dy*Width] = 1;
                newData[x + y*Width] = imageData[dx + (dy * Width)];
            }
          }
      }

      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            if (pixelzMap[x + y*Width]!=1)
               newData[x + y*Width] = imageData[x + (y * Width)];
        }
      }
      return 1;
}

DLL_API int DLL_CALLCONV symmetricaBitmap(int *imageData, int Width, int Height, int rx, int ry) {
// only works with 32-ARGB bitmaps 

      if (rx>0)
      {
         #pragma omp parallel for schedule(static) default(none) // num_threads(3)
         for (int y = 0; y < Height; y++)
         {
            // fnOutputDebug("y=" + std::to_string(y) + "; rx=" + std::to_string(rx));
            int p = -1;
            for (int x = 0; x < Width; x++)
            {
               if (x>=rx)
               {
                  p++;
                  int gx = (p>=rx) ? clamp(x - rx*2, 0, Width - 1) : clamp(rx - p, 0, Width - 1);
                  // fnOutputDebug(std::to_string(p) + "=p; x="  +  std::to_string(x) + "; gx=" + std::to_string(gx));
                  imageData[x + y*Width] = imageData[gx + (y * Width)];
               }
            }
            p = 0;
         }
      }

      if (ry>0)
      {
         #pragma omp parallel for schedule(static) default(none) // num_threads(3)
         for (int x = 0; x < Width; x++)
         {
            // fnOutputDebug("y=" + std::to_string(y) + "; rx=" + std::to_string(rx));
            int p = -1;
            for (int y = 0; y < Height; y++)
            {
               if (y>=ry)
               {
                  p++;
                  int gy = (p>=ry) ? clamp(y - ry*2, 0, Height - 1) : clamp(ry - p, 0, Height - 1);
                  // fnOutputDebug(std::to_string(p) + "=p; x="  +  std::to_string(x) + "; gx=" + std::to_string(gx));
                  imageData[x + y*Width] = imageData[x + (gy * Width)];
               }
            }
            p = 0;
         }
      }

      return 1;
}

// the factor that stretches minL..maxL over 0..255; a flat channel is left as it is
static inline double autoLevelsFactor(int &minL, const int maxL) {
      if (maxL<=minL)
      {
         minL = 0;
         return 1.0;
      }
      return 255.0f / (maxL - minL);
}

DLL_API int DLL_CALLCONV autoContrastBitmap(unsigned char *imageData, unsigned char *miniData, int Width, int Height, int mw, int mh, int modus, int intensity, int linearGamma, int Stride, int StrideMini, int bpp, unsigned char *maskBitmap, int mStride) {
      int maxRLevel = 0;      int minRLevel = 255;
      int maxGLevel = 0;      int minGLevel = 255;
      int maxBLevel = 0;      int minBLevel = 255;
      for (int y = 0; y < mh; y++)
      {
         for (int x = 0; x < mw; x++)
         {
            INT64 o = CalcPixOffset(x, y, StrideMini, bpp);
            if (bpp==32)
            {
               if (miniData[3 + o]<30)
                  continue;
            }

            if (modus==2)
            {
               int aR = miniData[2 + o]; // red
               int aB = miniData[o];     // blue
               maxRLevel = max(aR, maxRLevel);    minRLevel = min(aR, minRLevel);
               maxBLevel = max(aB, maxBLevel);    minBLevel = min(aB, minBLevel);
            }

            int aG = miniData[1 + o];   // green
            maxGLevel = max(aG, maxGLevel);    minGLevel = min(aG, minGLevel);
         }
      }

      // max < min: no pixel was counted, every one being nearly transparent
      if (maxGLevel<minGLevel || maxGLevel==minGLevel && modus==1)
         return 1;

      double fG = autoLevelsFactor(minGLevel, maxGLevel);
      double fR = fG;
      double fB = fG;
      if (modus==2)
      {
         fR = autoLevelsFactor(minRLevel, maxRLevel);
         fB = autoLevelsFactor(minBLevel, maxBLevel);
      } else
      {
         minRLevel = minGLevel;
         minBLevel = minGLevel;
         maxRLevel = maxGLevel;
         maxBLevel = maxGLevel;
      }

      float fintensity = char_to_float[intensity];
      // fnOutputDebug("RmaxL===" + std::to_string(maxRLevel) + "; minL=" + std::to_string(minRLevel) + "; fR=" + std::to_string(fR) + "; m=" + std::to_string(modus));
      // fnOutputDebug("GmaxL===" + std::to_string(maxGLevel) + "; minL=" + std::to_string(minGLevel) + "; fG=" + std::to_string(fG)  );
      // fnOutputDebug("BmaxL===" + std::to_string(maxBLevel) + "; minL=" + std::to_string(minBLevel) + "; fB=" + std::to_string(fB)  );
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int x = 0; x < Width; x++)
      {
         for (int y = 0; y < Height; y++)
         {
            if (clipMaskFilter(x, y, maskBitmap, mStride)==1)
               continue;

            INT64 o = CalcPixOffset(x, y, Stride, bpp);
            // fnOutputDebug("x===" + std::to_string(x) + "; y=" + std::to_string(y));
            int rO = imageData[2 + o];
            int gO = imageData[1 + o];
            int bO = imageData[o];
            int rB = clamp((int)round( (float)(rO - minRLevel)*fR ) , 0, 255);
            int gB = clamp((int)round( (float)(gO - minGLevel)*fG ) , 0, 255);
            int bB = clamp((int)round( (float)(bO - minBLevel)*fB ) , 0, 255);

            if (linearGamma==1 && intensity<255)
            {
               imageData[2 + o] = linear_to_gamma[weighTwoValues(gamma_to_linear[rB], gamma_to_linear[rO], fintensity)];
               imageData[1 + o] = linear_to_gamma[weighTwoValues(gamma_to_linear[gB], gamma_to_linear[gO], fintensity)];
               imageData[o]     = linear_to_gamma[weighTwoValues(gamma_to_linear[bB], gamma_to_linear[bO], fintensity)];
            } else
            {
               imageData[2 + o] = weighTwoValues(rB, rO, fintensity);
               imageData[1 + o] = weighTwoValues(gB, gO, fintensity);
               imageData[o]     = weighTwoValues(bB, bO, fintensity);
            }
            // imageData[x + (y * Width)] = (aO << 24) | (tR << 16) | (tG << 8) | tB;
         }
      }

      return 1;
}

// Bilinear tap into a 32bpp buffer of stride Width*4, added into acc[] with the given weight.
// Colours are weighted by their own alpha before being mixed, so a fully transparent pixel
// cannot bleed its RGB into its neighbours; resolveSampleAccum() divides that back out.
// wrapX makes the x axis periodic, which is what keeps the 0/360 seam of a polar strip
// continuous instead of pinning it against a clamped edge.
inline void accumBilinearSample(const unsigned char *data, int W, int H, double fx, double fy, bool wrapX, double weight, double *acc) {
      double fx0 = floor(fx), fy0 = floor(fy);
      double tx = fx - fx0, ty = fy - fy0;
      int x0 = (int)fx0, y0 = (int)fy0;
      int x1 = x0 + 1, y1 = y0 + 1;

      if (wrapX)
      {
         x0 = ((x0 % W) + W) % W;
         x1 = ((x1 % W) + W) % W;
      } else
      {
         x0 = clamp(x0, 0, W - 1);
         x1 = clamp(x1, 0, W - 1);
      }
      y0 = clamp(y0, 0, H - 1);
      y1 = clamp(y1, 0, H - 1);

      const double wq[4] = { weight*(1.0 - tx)*(1.0 - ty), weight*tx*(1.0 - ty), weight*(1.0 - tx)*ty, weight*tx*ty };
      const INT64 idx[4] = { ((INT64)y0*W + x0)*4, ((INT64)y0*W + x1)*4, ((INT64)y1*W + x0)*4, ((INT64)y1*W + x1)*4 };
      for (int i = 0; i < 4; i++)
      {
         const unsigned char *p = data + idx[i];
         const double aw = wq[i] * (double)p[3];
         acc[0] += aw;
         acc[1] += aw * (double)p[2];
         acc[2] += aw * (double)p[1];
         acc[3] += aw * (double)p[0];
      }
}

inline void resolveSampleAccum(const double *acc, unsigned char *out) {
      if (acc[0]<0.5)
      {
         out[0] = 0;   out[1] = 0;   out[2] = 0;   out[3] = 0;
         return;
      }

      out[3] = (unsigned char)clamp((int)round(acc[0]), 0, 255);          // alpha
      out[2] = (unsigned char)clamp((int)round(acc[1]/acc[0]), 0, 255);   // red
      out[1] = (unsigned char)clamp((int)round(acc[2]/acc[0]), 0, 255);   // green
      out[0] = (unsigned char)clamp((int)round(acc[3]/acc[0]), 0, 255);   // blue
}

DLL_API int DLL_CALLCONV rect2polarIMG(unsigned char *imageData, unsigned char *newData, int Width, int Height, double cx, double cy, double userScale, int superSamples) {
// Wraps a polar strip (column = angle 0..360, row = radius) back onto a rectangular bitmap.
// inspired by https://imagej.nih.gov/ij/plugins/polar-transformer.html
//
// Backward (gather) mapping: each destination pixel's angle/radius around (cx,cy) locates the
// strip pixel to pull from, so every destination is filled in one pass with no gaps.
// The destination is addressed in normalized elliptical coordinates -- radius 1 is the ellipse
// inscribed in the WxH destination, not a circle of radius min(W,H)/2 -- so the whole bitmap is
// covered whatever its aspect ratio. Beyond radius 1 the strip's last row keeps being
// pulled, which is what fills the corners.

      if (!imageData || !newData || Width<1 || Height<1)
         return 0;

      // semi-axes of the covered ellipse; Width/2 and Height/2 for a centered origin, and far
      // enough to still reach every edge if the origin is moved off center
      const double rx = max(cx, Width - cx);
      const double ry = max(cy, Height - cy);
      if (rx<=0 || ry<=0)
         return 0;

      const int ss = clamp(superSamples, 1, 4);
      const double ssStep = 1.0 / ss;
      const double ssWeight = 1.0 / (ss*ss);
      const double angleToCol = Width / 360.0;
      const double radiusToRow = Height * userScale;

      #pragma omp parallel for schedule(dynamic) default(none) shared(imageData, newData, Width, Height, cx, cy, rx, ry, ss, ssStep, ssWeight, angleToCol, radiusToRow)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            double acc[4] = { 0.0, 0.0, 0.0, 0.0 };
            for (int sy = 0; sy < ss; sy++)
            {
               const double v = ((y + (sy + 0.5)*ssStep - 0.5) - cy) / ry;
               for (int sx = 0; sx < ss; sx++)
               {
                  // mirrored horizontally, as the caller used to do to the finished bitmap
                  const double u = ((Width - 1 - (x + (sx + 0.5)*ssStep - 0.5)) - cx) / rx;
                  double angle = rad2deg(atan2(v, u)) + 90.0;
                  if (angle<0)
                     angle += 360.0;

                  accumBilinearSample(imageData, Width, Height, angle*angleToCol, sqrt(u*u + v*v)*radiusToRow, true, ssWeight, acc);
               }
            }
            resolveSampleAccum(acc, newData + ((INT64)x + (INT64)y*Width)*4);
        }
      }
      return 1;
}

DLL_API int DLL_CALLCONV polar2rectIMG(unsigned char *imageData, unsigned char *newData, int Width, int Height, double cx, double cy, double userScale, int superSamples) {
// Unrolls a rectangular bitmap into a polar strip (column = angle 0..360, row = radius): the
// analytical inverse of rect2polarIMG, so every destination pixel is computed directly from its
// source location -- no scatter, no gap-filling.
// inspired by https://imagej.nih.gov/ij/plugins/polar-transformer.html
//
// The source is swept in normalized elliptical coordinates -- radius 1 is the ellipse inscribed
// in the WxH source, not a circle of radius min(W,H)/2 -- so the whole bitmap is read whatever
// its aspect ratio. 

      if (!imageData || !newData || Width<1 || Height<1)
         return 0;

      const double rx = max(cx, Width - cx);
      const double ry = max(cy, Height - cy);
      const double invScale = (userScale!=0) ? 1.0/userScale : 0.0;
      const int ss = clamp(superSamples, 1, 4);
      const double ssStep = 1.0 / ss;
      const double ssWeight = 1.0 / (ss*ss);
      const double colToAngle = 360.0 / Width;
      const double rowToRadius = invScale / Height;

      #pragma omp parallel for schedule(dynamic) default(none) shared(imageData, newData, Width, Height, cx, cy, rx, ry, ss, ssStep, ssWeight, colToAngle, rowToRadius)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            double acc[4] = { 0.0, 0.0, 0.0, 0.0 };
            for (int sy = 0; sy < ss; sy++)
            {
               const double r = max(0.0, (y + (sy + 0.5)*ssStep - 0.5)) * rowToRadius;
               for (int sx = 0; sx < ss; sx++)
               {
                  // mirrored angle
                  const double angle = (Width - 1 - (x + (sx + 0.5)*ssStep - 0.5)) * colToAngle;
                  const double angleRad = deg2rad(angle - 90.0);
                  accumBilinearSample(imageData, Width, Height, cx + r*rx*cos(angleRad), cy + r*ry*sin(angleRad), false, ssWeight, acc);
               }
            }
            resolveSampleAccum(acc, newData + ((INT64)x + (INT64)y*Width)*4);
        }
      }
      return 1;
}

// Edge-extended integral of one channel along a lane of pixels, in box coordinates where pixel i
// covers [i, i+1). pre holds chan-interleaved prefix sums: pre[i*chan + c] = sum of pixels [0, i).
// Outside [0, w] the lane continues with its first/last pixel value (clamp-to-edge), so however
// far an overshooting streak reaches, the integral stays defined.
inline double zbLaneIntegral(const double *pre, const unsigned char *lane, const int &pixStep, const int &chan, const int &c, const int &w, const double &t) {
      if (t<=0.0)
         return t * (double)lane[c];

      if (t>=(double)w)
         return pre[(INT64)w*chan + c] + (t - (double)w) * (double)lane[(INT64)(w - 1)*pixStep + c];

      const int i = (int)t;
      return pre[(INT64)i*chan + c] + (t - (double)i) * (double)lane[(INT64)i*pixStep + c];
}

// These filters receive straight [non-premultiplied] ARGB: Gdip_LockBits hands over
// PixelFormat32bppARGB whatever the bitmap's own format is, so a fully transparent pixel still
// carries real RGB -- usually white -- and mixing that raw lets invisible pixels paint visible
// ones. A bitmap that has any transparency is therefore weighted by its own alpha once, up
// front, and the gather loops then run unchanged over the weighted copy: blending weighted
// colours is the same arithmetic as weighting every tap, at one pass instead of once per
// sample. The resolve divides the weighting back out. Returns false when every pixel is
// already opaque, where weighting would be the identity and the copy is pure waste.
inline bool blurNeedsAlphaWeighting(const unsigned char *data, const int &w, const int &h, const int &Stride) {
      int opaque = 1;
      #pragma omp parallel for schedule(static) reduction(&:opaque) default(none) shared(data, w, h, Stride)
      for (int y = 0; y < h; y++)
      {
         const unsigned char *a = data + (INT64)y*Stride + 3;
         for (int x = 0; x < w; x++, a += 4)
         {
            if (*a!=255)
            {
               opaque = 0;
               break;
            }
         }
      }
      return opaque==0;
}

// c*(a+1)>>8 -- exact for a=255, ~c*a/255 otherwise; alpha passes through untouched. keep receives
// the untouched pixels, so src and dst may be the same buffer; keep must be a third one.
inline void blurWeighByAlpha(const unsigned char *src, unsigned char *dst, unsigned char *keep, const int &w, const int &h, const int &Stride) {
      #pragma omp parallel for schedule(static) default(none) shared(src, dst, keep, w, h, Stride)
      for (int y = 0; y < h; y++)
      {
         const unsigned char *p = src + (INT64)y*Stride;
         unsigned char *q = dst + (INT64)y*Stride;
         unsigned char *k = keep + (INT64)y*Stride;
         for (int x = 0; x < w; x++, p += 4, q += 4, k += 4)
         {
            const unsigned int a = (unsigned int)p[3] + 1;
            *(UINT32 *)k = *(const UINT32 *)p;
            q[0] = (unsigned char)((p[0]*a) >> 8);
            q[1] = (unsigned char)((p[1]*a) >> 8);
            q[2] = (unsigned char)((p[2]*a) >> 8);
            q[3] = p[3];
         }
      }
}

DLL_API int DLL_CALLCONV zoomBlurBitmap(unsigned char *imageData, unsigned char *newData, int w, int h, int Stride, int bpp, int cx, int cy, int mode, int intensity, int quality) {
      if (!imageData || !newData || imageData==newData || w<1 || h<1 || Stride<1 || (bpp!=24 && bpp!=32))
         return 0;

      const int chan = bpp / 8;
      const double f = clamp(intensity, 0, 20000) / 100.0;
      fnOutputDebug("zoomBlurBitmap invoked; mode=" + std::to_string(mode) + "; intensity=" + std::to_string(intensity) + "; quality=" + std::to_string(quality));
      if (f==0.0)
      {
         #pragma omp parallel for schedule(static) default(none) shared(imageData, newData, h, Stride, w, chan)
         for (int y = 0; y < h; y++)
             memcpy(newData + (INT64)y*Stride, imageData + (INT64)y*Stride, (size_t)w*chan);
         return 1;
      }

      // straight-ARGB sources get weighted by their own alpha once, up front, so the streaks mix
      // only what is actually visible [see blurWeighByAlpha]; the resolve divides it back out.
      // The weighting runs in place; newData is idle until the gather starts, so it keeps the
      // untouched pixels for the pass-through reads and the output alpha: every pixel reads only
      // its own original before overwriting it
      const unsigned char *srcData = imageData;
      const unsigned char *origData = imageData;
      if (bpp==32 && blurNeedsAlphaWeighting(imageData, w, h, Stride))
      {
         fnOutputDebug("zoomBlurBitmap weighted");
         blurWeighByAlpha(imageData, imageData, newData, w, h, Stride);
         origData = newData;
      }

      if (mode==2 || mode==3)
      {
         // exact box average along one axis: a lane is a row [mode 2] or a column [mode 3]
         const int lanes = (mode==2) ? h : w;
         const int lanePix = (mode==2) ? w : h;
         const int pixStep = (mode==2) ? chan : Stride;
         const INT64 laneStep = (mode==2) ? Stride : chan;
         const double cLane = (mode==2) ? (double)cx : (double)cy;

         #pragma omp parallel shared(origData, srcData, newData, lanes, lanePix, pixStep, laneStep, cLane, chan, f)
         {
            std::vector<double> pre((INT64)(lanePix + 1)*chan, 0.0);
            #pragma omp for schedule(static)
            for (int L = 0; L < lanes; L++)
            {
               const unsigned char *lane = srcData + L*laneStep;      // alpha-weighted, for the sums
               const unsigned char *oLane = origData + L*laneStep;    // untouched, for pass-through pixels
               unsigned char *outLane = newData + L*laneStep;
               double sum[4] = { 0.0, 0.0, 0.0, 0.0 };
               for (int i = 0; i < lanePix; i++)
               {
                  const unsigned char *p = lane + (INT64)i*pixStep;
                  for (int c = 0; c < chan; c++)
                  {
                     sum[c] += (double)p[c];
                     pre[(INT64)(i + 1)*chan + c] = sum[c];
                  }
               }

               for (int i = 0; i < lanePix; i++)
               {
                  unsigned char *out = outLane + (INT64)i*pixStep;
                  const double d = f * ((double)i - cLane);
                  if (d==0.0)
                  {
                     const unsigned char *p = oLane + (INT64)i*pixStep;
                     for (int c = 0; c < chan; c++)
                         out[c] = p[c];
                     continue;
                  }

                  const double a = (double)i + 0.5;   // pixel center in box coordinates
                  const double u = (d>0) ? a - d : a;
                  const double v = (d>0) ? a : a - d;
                  const double inv = 1.0 / (v - u);
                  if (chan==4)
                  {
                     // straight ARGB: the colour is the streak's alpha-weighted average
                     // [sum(c*a)/sum(a)], so transparent stretches can neither dilute it nor
                     // bleed the RGB hiding under them, and the alpha never drops below the
                     // pixel's own. Opaque lanes give sum(a) = 255*length and resolve to the
                     // same plain box average as always
                     double sums[4];
                     for (int c = 0; c < 4; c++)
                         sums[c] = zbLaneIntegral(pre.data(), lane, pixStep, chan, c, lanePix, v)
                                 - zbLaneIntegral(pre.data(), lane, pixStep, chan, c, lanePix, u);
                     const unsigned char *px = oLane + (INT64)i*pixStep;
                     if (sums[3]<0.5)
                     {
                        for (int c = 0; c < 4; c++)
                            out[c] = px[c];   // the streak saw nothing visible; keep the pixel
                     } else
                     {
                        const double sc = 255.0 / sums[3];
                        const double avgA = sums[3] * inv;
                        const double srcA = (double)px[3];   // read before out[] is written: px may alias out
                        out[0] = (unsigned char)(min(255.0, sums[0] * sc) + 0.5);
                        out[1] = (unsigned char)(min(255.0, sums[1] * sc) + 0.5);
                        out[2] = (unsigned char)(min(255.0, sums[2] * sc) + 0.5);
                        out[3] = (unsigned char)((srcA>avgA ? srcA : avgA) + 0.5);
                     }
                  } else
                  {
                     for (int c = 0; c < chan; c++)
                     {
                        const double avg = (zbLaneIntegral(pre.data(), lane, pixStep, chan, c, lanePix, v)
                                          - zbLaneIntegral(pre.data(), lane, pixStep, chan, c, lanePix, u)) * inv;
                        out[c] = (unsigned char)clamp((int)(avg + 0.5), 0, 255);
                     }
                  }
               }
            }
         }

         return 1;
      }

      // radial zoom: gather along the pixel->anchor segment in 16.16 fixed point with integer
      // bilinear taps; rows near the anchor carry far fewer samples, hence schedule(dynamic)
      const int maxS = (quality<1) ? 128 : clamp(quality, 8, 256);
      const double cxf = (double)cx, cyf = (double)cy;

      #pragma omp parallel for schedule(dynamic) default(none) shared(imageData, origData, srcData, newData, w, h, Stride, bpp, chan, f, maxS, cxf, cyf)
      for (int y = 0; y < h; y++)
      {
         unsigned char *out = newData + (INT64)y*Stride;
         const double ty = -f * ((double)y - cyf);
         for (int x = 0; x < w; x++, out += chan)
         {
            const double tx = -f * ((double)x - cxf);
            const double len = sqrt(tx*tx + ty*ty);
            if (len<0.0001)
            {
               const unsigned char *p = origData + CalcPixOffset(x, y, Stride, bpp);
               for (int c = 0; c < chan; c++)
                   out[c] = p[c];
               continue;
            }

            // one sample per streak pixel, endpoints included; n>=2 so the blur fades in
            // continuously as the streak shrinks toward the anchor
            const int n = 2 + (int)min((double)(maxS - 2), len);
            const double invSeg = 1.0 / (double)(n - 1);
            const INT64 stepX = (INT64)(tx * invSeg * 65536.0);
            const INT64 stepY = (INT64)(ty * invSeg * 65536.0);
            INT64 pxf = (INT64)x << 16;
            INT64 pyf = (INT64)y << 16;

            // the exact endpoints bound every fixed-point tap, so they decide whether the
            // unclamped fast path is safe; the +1 bilinear tap costs the -1 on each far edge
            const double ex = (double)x + tx, ey = (double)y + ty;
            const bool safe = min((double)x, ex)>=0.0 && max((double)x, ex)<(double)(w - 1) - 0.001
                           && min((double)y, ey)>=0.0 && max((double)y, ey)<(double)(h - 1) - 0.001;

            if (bpp==32)
            {
               // SSE2 bilinear: the x blend runs on 16-bit words (7-bit weights keep the products
               // signed-safe for pmaddwd) and the y blend folds both tap rows in a single madd;
               // per-sample weights total 128*256 = 32768, so 256 samples peak at
               // 255*32768*256 < 2^31 per lane and the averages can never exceed 255
               const __m128i zero = _mm_setzero_si128();
               __m128i acc = zero;
               if (safe)
               {
                  // both x-neighbours of a tap row arrive in one 64-bit load
                  for (int i = 0; i < n; i++)
                  {
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const int wx1 = (int)((pxf >> 9) & 0x7F), wy1 = (int)((pyf >> 8) & 0xFF);
                     const unsigned char *row = srcData + (INT64)yi*Stride + (INT64)xi*4;
                     const __m128i xw = _mm_unpacklo_epi64(_mm_set1_epi16((short)(128 - wx1)), _mm_set1_epi16((short)wx1));
                     const __m128i yw = _mm_set1_epi32((256 - wy1) | (wy1 << 16));
                     __m128i t16 = _mm_mullo_epi16(_mm_unpacklo_epi8(_mm_loadl_epi64((const __m128i *)row), zero), xw);
                     __m128i b16 = _mm_mullo_epi16(_mm_unpacklo_epi8(_mm_loadl_epi64((const __m128i *)(row + Stride)), zero), xw);
                     t16 = _mm_add_epi16(t16, _mm_srli_si128(t16, 8));
                     b16 = _mm_add_epi16(b16, _mm_srli_si128(b16, 8));
                     acc = _mm_add_epi32(acc, _mm_madd_epi16(_mm_unpacklo_epi16(t16, b16), yw));
                     pxf += stepX;   pyf += stepY;
                  }
               } else
               {
                  // same arithmetic, but every tap is clamped to the bitmap and loaded singly
                  for (int i = 0; i < n; i++)
                  {
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const int wx1 = (int)((pxf >> 9) & 0x7F), wy1 = (int)((pyf >> 8) & 0xFF);
                     const INT64 x0 = (INT64)clamp(xi, 0, w - 1)*4, x1 = (INT64)clamp(xi + 1, 0, w - 1)*4;
                     const unsigned char *r0 = srcData + (INT64)clamp(yi, 0, h - 1)*Stride;
                     const unsigned char *r1 = srcData + (INT64)clamp(yi + 1, 0, h - 1)*Stride;
                     const __m128i xw = _mm_unpacklo_epi64(_mm_set1_epi16((short)(128 - wx1)), _mm_set1_epi16((short)wx1));
                     const __m128i yw = _mm_set1_epi32((256 - wy1) | (wy1 << 16));
                     const __m128i top = _mm_unpacklo_epi32(_mm_cvtsi32_si128(*(const int *)(r0 + x0)), _mm_cvtsi32_si128(*(const int *)(r0 + x1)));
                     const __m128i bot = _mm_unpacklo_epi32(_mm_cvtsi32_si128(*(const int *)(r1 + x0)), _mm_cvtsi32_si128(*(const int *)(r1 + x1)));
                     __m128i t16 = _mm_mullo_epi16(_mm_unpacklo_epi8(top, zero), xw);
                     __m128i b16 = _mm_mullo_epi16(_mm_unpacklo_epi8(bot, zero), xw);
                     t16 = _mm_add_epi16(t16, _mm_srli_si128(t16, 8));
                     b16 = _mm_add_epi16(b16, _mm_srli_si128(b16, 8));
                     acc = _mm_add_epi32(acc, _mm_madd_epi16(_mm_unpacklo_epi16(t16, b16), yw));
                     pxf += stepX;   pyf += stepY;
                  }
               }

               // resolve back to straight ARGB: the colour is the streak's alpha-weighted
               // average [sum(c*a)/sum(a)], so only pixels that are actually visible tint it,
               // and the alpha is the plain streak average but never below the source pixel's
               // own. Fully opaque input gives sum(a) = 255*n and resolves to the same plain
               // average as always
               int lanes[4];
               _mm_storeu_si128((__m128i *)lanes, acc);
               const unsigned char *sp = origData + (INT64)y*Stride + (INT64)x*4;
               if (lanes[3]<1)
               {
                  *(UINT32 *)out = *(const UINT32 *)sp;   // the streak saw nothing visible; keep the pixel
               } else
               {
                  const double sc = 255.0 / (double)lanes[3];
                  const double avgA = (double)lanes[3] / ((double)n * 32768.0);
                  const double srcA = (double)sp[3];   // read before out[] is written: sp may alias out
                  out[0] = (unsigned char)(min(255.0, (double)lanes[0] * sc) + 0.5);
                  out[1] = (unsigned char)(min(255.0, (double)lanes[1] * sc) + 0.5);
                  out[2] = (unsigned char)(min(255.0, (double)lanes[2] * sc) + 0.5);
                  out[3] = (unsigned char)((srcA>avgA ? srcA : avgA) + 0.5);
               }
            } else
            {
               UINT32 accB = 0, accG = 0, accR = 0;
               if (safe)
               {
                  for (int i = 0; i < n; i++)
                  {
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const UINT32 wx1 = (pxf >> 8) & 0xFF, wy1 = (pyf >> 8) & 0xFF;
                     const UINT32 wx0 = 256 - wx1, wy0 = 256 - wy1;
                     const UINT32 w00 = wx0*wy0, w01 = wx1*wy0, w10 = wx0*wy1, w11 = wx1*wy1;
                     const unsigned char *p00 = imageData + (INT64)yi*Stride + (INT64)xi*3;
                     const unsigned char *p10 = p00 + Stride;
                     accB += p00[0]*w00 + p00[3]*w01 + p10[0]*w10 + p10[3]*w11;
                     accG += p00[1]*w00 + p00[4]*w01 + p10[1]*w10 + p10[4]*w11;
                     accR += p00[2]*w00 + p00[5]*w01 + p10[2]*w10 + p10[5]*w11;
                     pxf += stepX;   pyf += stepY;
                  }
               } else
               {
                  for (int i = 0; i < n; i++)
                  {
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const UINT32 wx1 = (pxf >> 8) & 0xFF, wy1 = (pyf >> 8) & 0xFF;
                     const UINT32 wx0 = 256 - wx1, wy0 = 256 - wy1;
                     const UINT32 w00 = wx0*wy0, w01 = wx1*wy0, w10 = wx0*wy1, w11 = wx1*wy1;
                     const INT64 x0 = (INT64)clamp(xi, 0, w - 1)*3, x1 = (INT64)clamp(xi + 1, 0, w - 1)*3;
                     const unsigned char *r0 = imageData + (INT64)clamp(yi, 0, h - 1)*Stride;
                     const unsigned char *r1 = imageData + (INT64)clamp(yi + 1, 0, h - 1)*Stride;
                     accB += r0[x0]*w00 + r0[x1]*w01 + r1[x0]*w10 + r1[x1]*w11;
                     accG += r0[x0 + 1]*w00 + r0[x1 + 1]*w01 + r1[x0 + 1]*w10 + r1[x1 + 1]*w11;
                     accR += r0[x0 + 2]*w00 + r0[x1 + 2]*w01 + r1[x0 + 2]*w10 + r1[x1 + 2]*w11;
                     pxf += stepX;   pyf += stepY;
                  }
               }

               const double invW = 1.0 / (double)((UINT64)n << 16);
               out[0] = (unsigned char)((double)accB * invW + 0.5);
               out[1] = (unsigned char)((double)accG * invW + 0.5);
               out[2] = (unsigned char)((double)accR * invW + 0.5);
            }
         }
      }

      return 1;
}

// True when the angular sweep [a0, a1] passes absolute angle a [radians] or a full-turn alias
// of it; the sweep never exceeds one turn, so the three nearest aliases are exhaustive. Used to
// find where an arc peaks against the bitmap borders.
inline bool rbArcCrosses(const double &a0, const double &a1, const double &a) {
      return (a>=a0 && a<=a1) || (a - 2.0*M_PI>=a0 && a - 2.0*M_PI<=a1) || (a + 2.0*M_PI>=a0 && a + 2.0*M_PI<=a1);
}

DLL_API int DLL_CALLCONV rotateBlurBitmap(unsigned char *imageData, unsigned char *newData, int w, int h, int Stride, int bpp, int cx, int cy, int intensity, int quality) {
// Rotational [spin] blur anchored on (cx, cy): every pixel is streaked along the arc of the
// circle centered on the anchor and passing through it, sweeping intensity degrees in total --
// half to each side of the pixel's own position, so the image blurs in place instead of looking
// rotated; 360 averages the entire circle. The anchor may sit outside the bitmap, and arcs
// leaving the bitmap are fed by clamp-to-edge samples. The gather walks the arc with a
// per-pixel sample count matched to the arc length, so pixels near the anchor stay nearly
// free; quality caps the samples per pixel (<=0 picks 128; hard ceiling 256 -- the integer
// accumulators overflow past that).
// 32-bpp data is straight [non-premultiplied] ARGB -- what Gdip_LockBits hands over as
// PixelFormat32bppARGB, whatever the bitmap's own format is -- so every tap is weighted by its
// own alpha before being mixed and the arc resolves to sum(c*a)/sum(a), the average of the
// content that is actually visible. Output alpha is the arc average but never below the source
// pixel's own. Together that keeps transparency from either diluting the effect into
// invisibility or bleeding the RGB hidden under it [usually white] over the image.
// imageData is the source and newData receives the result; a gather filter cannot work in place,
// so the two must be distinct buffers. A 32-bpp source carrying transparency gets weighted in
// place by blurWeighByAlpha(), to avoid a third buffer.

      if (!imageData || !newData || imageData==newData || w<1 || h<1 || Stride<1 || (bpp!=24 && bpp!=32))
         return 0;

      const int chan = bpp / 8;
      const double A = deg2rad(clamp(intensity, 0, 360));
      fnOutputDebug("rotateBlurBitmap invoked; intensity=" + std::to_string(intensity) + "; quality=" + std::to_string(quality));
      if (A==0.0)
      {
         #pragma omp parallel for schedule(static) default(none) shared(imageData, newData, h, Stride, w, chan)
         for (int y = 0; y < h; y++)
             memcpy(newData + (INT64)y*Stride, imageData + (INT64)y*Stride, (size_t)w*chan);
         return 1;
      }

      // straight-ARGB sources get weighted by their own alpha once, up front, so the arcs mix
      // only what is actually visible [see blurWeighByAlpha]; the resolve divides it back out.
      // The weighting runs in place; newData is idle until the gather starts, so it keeps the
      // untouched pixels for the pass-through reads and the output alpha: every pixel reads only
      // its own original before overwriting it
      const unsigned char *srcData = imageData;
      const unsigned char *origData = imageData;
      if (bpp==32 && blurNeedsAlphaWeighting(imageData, w, h, Stride))
      {
         blurWeighByAlpha(imageData, imageData, newData, w, h, Stride);
         origData = newData;
      }

      const int maxS = (quality<1) ? 128 : clamp(quality, 8, 256);
      const double cxf = (double)cx, cyf = (double)cy;
      const double cH = cos(0.5*A), sH = sin(0.5*A);   // rotation by half the sweep reaches the arc ends

      // the arc is walked with the constant-angle rotation recurrence, so cos/sin of the step
      // are needed only once per sample count, never per sample; every count gets its pair here
      double stepC[257], stepS[257];
      for (int i = 2; i <= 256; i++)
      {
         const double a = A / (double)(i - 1);
         stepC[i] = cos(a);   stepS[i] = sin(a);
      }

      // rows far from the anchor carry longer arcs, hence schedule(dynamic)
      #pragma omp parallel for schedule(dynamic) default(none) shared(imageData, origData, srcData, newData, w, h, Stride, bpp, chan, A, maxS, cxf, cyf, cH, sH, stepC, stepS)
      for (int y = 0; y < h; y++)
      {
         unsigned char *out = newData + (INT64)y*Stride;
         const double dy = (double)y - cyf;
         for (int x = 0; x < w; x++, out += chan)
         {
            const double dx = (double)x - cxf;
            const double r2 = dx*dx + dy*dy;
            if (r2<0.00000001)
            {
               const unsigned char *p = origData + CalcPixOffset(x, y, Stride, bpp);
               for (int c = 0; c < chan; c++)
                   out[c] = p[c];
               continue;
            }

            // one sample per arc pixel, endpoints included; n>=2 so the blur fades in
            // continuously as the arc shrinks toward the anchor
            const double r = sqrt(r2);
            const int n = 2 + (int)min((double)(maxS - 2), r*A);
            const double rc = stepC[n], rs = stepS[n];
            // sweep start and end: the pixel's offset from the anchor, rotated a half sweep
            // backward [walked from] and forward [only bounds-checked]
            double vx = dx*cH + dy*sH, vy = dy*cH - dx*sH;
            const double ex = dx*cH - dy*sH, ey = dy*cH + dx*sH;

            // the arc peaks at +-r on every axis direction it sweeps past and at its endpoints
            // otherwise; that exact bounding box decides whether the unclamped fast path is
            // safe; the +1 bilinear tap costs the -1 on each far edge. The circle test first
            // spares the atan2 wherever the whole circle already fits
            bool safe = cxf - r>=0.0 && cxf + r<(double)(w - 1) - 0.001
                     && cyf - r>=0.0 && cyf + r<(double)(h - 1) - 0.001;
            if (!safe)
            {
               const double th = atan2(dy, dx);
               const double a0 = th - 0.5*A, a1 = th + 0.5*A;
               const double bxMax = rbArcCrosses(a0, a1, 0.0) ? r : max(vx, ex);
               const double bxMin = rbArcCrosses(a0, a1, M_PI) ? -r : min(vx, ex);
               const double byMax = rbArcCrosses(a0, a1, 0.5*M_PI) ? r : max(vy, ey);
               const double byMin = rbArcCrosses(a0, a1, -0.5*M_PI) ? -r : min(vy, ey);
               safe = cxf + bxMin>=0.0 && cxf + bxMax<(double)(w - 1) - 0.001
                   && cyf + byMin>=0.0 && cyf + byMax<(double)(h - 1) - 0.001;
            }

            if (bpp==32)
            {
               // SSE2 bilinear: the x blend runs on 16-bit words (7-bit weights keep the products
               // signed-safe for pmaddwd) and the y blend folds both tap rows in a single madd;
               // per-sample weights total 128*256 = 32768, so 256 samples peak at
               // 255*32768*256 < 2^31 per lane and the averages can never exceed 255
               const __m128i zero = _mm_setzero_si128();
               __m128i acc = zero;
               if (safe)
               {
                  // both x-neighbours of a tap row arrive in one 64-bit load
                  for (int i = 0; i < n; i++)
                  {
                     const INT64 pxf = (INT64)((cxf + vx)*65536.0), pyf = (INT64)((cyf + vy)*65536.0);
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const int wx1 = (int)((pxf >> 9) & 0x7F), wy1 = (int)((pyf >> 8) & 0xFF);
                     const unsigned char *row = srcData + (INT64)yi*Stride + (INT64)xi*4;
                     const __m128i xw = _mm_unpacklo_epi64(_mm_set1_epi16((short)(128 - wx1)), _mm_set1_epi16((short)wx1));
                     const __m128i yw = _mm_set1_epi32((256 - wy1) | (wy1 << 16));
                     __m128i t16 = _mm_mullo_epi16(_mm_unpacklo_epi8(_mm_loadl_epi64((const __m128i *)row), zero), xw);
                     __m128i b16 = _mm_mullo_epi16(_mm_unpacklo_epi8(_mm_loadl_epi64((const __m128i *)(row + Stride)), zero), xw);
                     t16 = _mm_add_epi16(t16, _mm_srli_si128(t16, 8));
                     b16 = _mm_add_epi16(b16, _mm_srli_si128(b16, 8));
                     acc = _mm_add_epi32(acc, _mm_madd_epi16(_mm_unpacklo_epi16(t16, b16), yw));
                     const double t = vx*rc - vy*rs;   vy = vx*rs + vy*rc;   vx = t;
                  }
               } else
               {
                  // same arithmetic, but every tap is clamped to the bitmap and loaded singly
                  for (int i = 0; i < n; i++)
                  {
                     const INT64 pxf = (INT64)((cxf + vx)*65536.0), pyf = (INT64)((cyf + vy)*65536.0);
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const int wx1 = (int)((pxf >> 9) & 0x7F), wy1 = (int)((pyf >> 8) & 0xFF);
                     const INT64 x0 = (INT64)clamp(xi, 0, w - 1)*4, x1 = (INT64)clamp(xi + 1, 0, w - 1)*4;
                     const unsigned char *r0 = srcData + (INT64)clamp(yi, 0, h - 1)*Stride;
                     const unsigned char *r1 = srcData + (INT64)clamp(yi + 1, 0, h - 1)*Stride;
                     const __m128i xw = _mm_unpacklo_epi64(_mm_set1_epi16((short)(128 - wx1)), _mm_set1_epi16((short)wx1));
                     const __m128i yw = _mm_set1_epi32((256 - wy1) | (wy1 << 16));
                     const __m128i top = _mm_unpacklo_epi32(_mm_cvtsi32_si128(*(const int *)(r0 + x0)), _mm_cvtsi32_si128(*(const int *)(r0 + x1)));
                     const __m128i bot = _mm_unpacklo_epi32(_mm_cvtsi32_si128(*(const int *)(r1 + x0)), _mm_cvtsi32_si128(*(const int *)(r1 + x1)));
                     __m128i t16 = _mm_mullo_epi16(_mm_unpacklo_epi8(top, zero), xw);
                     __m128i b16 = _mm_mullo_epi16(_mm_unpacklo_epi8(bot, zero), xw);
                     t16 = _mm_add_epi16(t16, _mm_srli_si128(t16, 8));
                     b16 = _mm_add_epi16(b16, _mm_srli_si128(b16, 8));
                     acc = _mm_add_epi32(acc, _mm_madd_epi16(_mm_unpacklo_epi16(t16, b16), yw));
                     const double t = vx*rc - vy*rs;   vy = vx*rs + vy*rc;   vx = t;
                  }
               }

               // resolve back to straight ARGB: the color is the arc's alpha-weighted average
               // [sum(c*a)/sum(a)], so only pixels that are actually visible tint the streak,
               // and the alpha is the plain arc average but never below the source pixel's own,
               // so transparency can neither dilute the effect into invisibility nor paint the
               // image with the RGB hiding under it. Fully opaque input keeps resolving to the
               // same plain average as always [c*(255+1)>>8 == c]. The arc always passes
               // through the pixel itself, so an opaque pixel always has its own alpha in the
               // sum and a faint fringe can never outvote it
               int lanes[4];
               _mm_storeu_si128((__m128i *)lanes, acc);
               const unsigned char *sp = origData + (INT64)y*Stride + (INT64)x*4;
               if (lanes[3]<1)
               {
                  *(UINT32 *)out = *(const UINT32 *)sp;   // the arc saw nothing visible; keep the pixel
               } else
               {
                  const double sc = 255.0 / (double)lanes[3];
                  const double avgA = (double)lanes[3] / ((double)n * 32768.0);
                  const double srcA = (double)sp[3];   // read before out[] is written: sp may alias out
                  out[0] = (unsigned char)(min(255.0, (double)lanes[0] * sc) + 0.5);
                  out[1] = (unsigned char)(min(255.0, (double)lanes[1] * sc) + 0.5);
                  out[2] = (unsigned char)(min(255.0, (double)lanes[2] * sc) + 0.5);
                  out[3] = (unsigned char)((srcA>avgA ? srcA : avgA) + 0.5);
               }
            } else
            {
               UINT32 accB = 0, accG = 0, accR = 0;
               if (safe)
               {
                  for (int i = 0; i < n; i++)
                  {
                     const INT64 pxf = (INT64)((cxf + vx)*65536.0), pyf = (INT64)((cyf + vy)*65536.0);
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const UINT32 wx1 = (pxf >> 8) & 0xFF, wy1 = (pyf >> 8) & 0xFF;
                     const UINT32 wx0 = 256 - wx1, wy0 = 256 - wy1;
                     const UINT32 w00 = wx0*wy0, w01 = wx1*wy0, w10 = wx0*wy1, w11 = wx1*wy1;
                     const unsigned char *p00 = imageData + (INT64)yi*Stride + (INT64)xi*3;
                     const unsigned char *p10 = p00 + Stride;
                     accB += p00[0]*w00 + p00[3]*w01 + p10[0]*w10 + p10[3]*w11;
                     accG += p00[1]*w00 + p00[4]*w01 + p10[1]*w10 + p10[4]*w11;
                     accR += p00[2]*w00 + p00[5]*w01 + p10[2]*w10 + p10[5]*w11;
                     const double t = vx*rc - vy*rs;   vy = vx*rs + vy*rc;   vx = t;
                  }
               } else
               {
                  for (int i = 0; i < n; i++)
                  {
                     const INT64 pxf = (INT64)((cxf + vx)*65536.0), pyf = (INT64)((cyf + vy)*65536.0);
                     const int xi = (int)(pxf >> 16), yi = (int)(pyf >> 16);
                     const UINT32 wx1 = (pxf >> 8) & 0xFF, wy1 = (pyf >> 8) & 0xFF;
                     const UINT32 wx0 = 256 - wx1, wy0 = 256 - wy1;
                     const UINT32 w00 = wx0*wy0, w01 = wx1*wy0, w10 = wx0*wy1, w11 = wx1*wy1;
                     const INT64 x0 = (INT64)clamp(xi, 0, w - 1)*3, x1 = (INT64)clamp(xi + 1, 0, w - 1)*3;
                     const unsigned char *r0 = imageData + (INT64)clamp(yi, 0, h - 1)*Stride;
                     const unsigned char *r1 = imageData + (INT64)clamp(yi + 1, 0, h - 1)*Stride;
                     accB += r0[x0]*w00 + r0[x1]*w01 + r1[x0]*w10 + r1[x1]*w11;
                     accG += r0[x0 + 1]*w00 + r0[x1 + 1]*w01 + r1[x0 + 1]*w10 + r1[x1 + 1]*w11;
                     accR += r0[x0 + 2]*w00 + r0[x1 + 2]*w01 + r1[x0 + 2]*w10 + r1[x1 + 2]*w11;
                     const double t = vx*rc - vy*rs;   vy = vx*rs + vy*rc;   vx = t;
                  }
               }

               const double invW = 1.0 / (double)((UINT64)n << 16);
               out[0] = (unsigned char)((double)accB * invW + 0.5);
               out[1] = (unsigned char)((double)accG * invW + 0.5);
               out[2] = (unsigned char)((double)accR * invW + 0.5);
            }
         }
      }

      return 1;
}

// the brush tool: PaintBrushLarge() and its per-stroke opacity chunks
#include "paint-brush.h"



////////////////////////////////////////////////////////////////////////////////
// Local time stamps for file times
//
// GetFilesList() in the script converts two FILETIMEs per file into the local
// "YYYYMMDDHH24MISS" form that A_LoopFileTimeModified produces. At 800 000
// files that is 1.6 million conversions, and driving them one at a time from
// the script, through FileTimeToSystemTime() + SystemTimeToTzSpecificLocalTime(),
// costs many seconds.
//
// The offset between UTC and local time only ever changes twice a year, so it
// is cached per day here and the calendar arithmetic is done inline.
// SystemTimeToTzSpecificLocalTime(NULL, ..) applies the time zone rule that is
// currently in force to every date it is handed, historical or not, so one
// fixed offset per day reproduces its results exactly. The two days a year
// that do contain a transition are marked as such in the cache and are passed
// to the system call itself, so nothing is ever approximated.
//
// The cache would go stale if the user changed the time zone of the machine
// while the application is running. Note that a mere daylight saving switch is
// not enough to do that: what is cached is the offset of the day a file was
// written on, not the offset of today.
////////////////////////////////////////////////////////////////////////////////

#define QPV_FT_PER_DAY   864000000000LL   // 100 ns units in 24 hours
#define QPV_FT_PER_SEC   10000000LL
#define QPV_FT_PER_MIN   600000000LL
#define QPV_DAYS_1601_1970  134774LL      // whole days between the two epochs

#define QPV_TZDAY_SLOTS     32768         // enough distinct days for 89 years
#define QPV_TZ_TRANSITION   0x7FFFFFFF    // this day contains a DST switch

// Every slot packs (day + 1) in the high 32 bits and the offset, in minutes,
// in the low 32. A 64 bit atomic load can never see one half of an update, so
// no lock is needed here, and a slot that misses is simply recomputed. Zero,
// which is what the table starts out as, can never be mistaken for a real day,
// because the day is stored biased by one.
static std::atomic<INT64> qpvTZdayCache[QPV_TZDAY_SLOTS];

static bool qpvUTCtoLocalFileTime(INT64 ft, INT64 &outLocal) {
// Runs one UTC file time through the system, and hands back the local wall
// clock reading of it, expressed on the very same 100 ns scale. The result is
// not a valid file time any more, it is only ever used to take a difference.
    FILETIME f, lf;
    SYSTEMTIME su, sl;

    f.dwLowDateTime  = (DWORD)(ft & 0xFFFFFFFFLL);
    f.dwHighDateTime = (DWORD)((ft >> 32) & 0xFFFFFFFFLL);
    if (!FileTimeToSystemTime(&f, &su))
        return false;
    if (!SystemTimeToTzSpecificLocalTime(NULL, &su, &sl))
        return false;
    if (!SystemTimeToFileTime(&sl, &lf))
        return false;

    outLocal = ((INT64)lf.dwHighDateTime << 32) | (INT64)lf.dwLowDateTime;
    return true;
}

static int qpvComputeDayOffset(INT64 day) {
// The UTC to local offset, in minutes, for the given day, or QPV_TZ_TRANSITION
// when the two ends of that day do not agree. Both probes are placed on a
// whole second, so that the millisecond resolution of SYSTEMTIME cannot round
// one of them and forge a difference that is not there.
    INT64 a = day * QPV_FT_PER_DAY;                    // 00:00:00
    INT64 b = a + QPV_FT_PER_DAY - QPV_FT_PER_SEC;     // 23:59:59
    INT64 la, lb;

    if (!qpvUTCtoLocalFileTime(a, la) || !qpvUTCtoLocalFileTime(b, lb))
        return QPV_TZ_TRANSITION;

    INT64 offA = (la - a) / QPV_FT_PER_MIN;
    INT64 offB = (lb - b) / QPV_FT_PER_MIN;
    if (offA != offB)
        return QPV_TZ_TRANSITION;

    return (int)offA;
}

static QPV_FORCEINLINE void qpvCivilFromDays(INT64 z, int &y, int &m, int &d) {
// Days since 1970-01-01 to a proleptic Gregorian date, after Howard Hinnant's
// chrono-Compatible Low-Level Date Algorithms
    z += 719468;
    const INT64 era = (z >= 0 ? z : z - 146096) / 146097;
    const unsigned doe = (unsigned)(z - era * 146097);              // [0, 146096]
    const unsigned yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365;   // [0, 399]
    const INT64 yy = (INT64)yoe + era * 400;
    const unsigned doy = doe - (365*yoe + yoe/4 - yoe/100);         // [0, 365]
    const unsigned mp = (5*doy + 2)/153;                            // [0, 11]
    d = (int)(doy - (153*mp+2)/5 + 1);                              // [1, 31]
    m = (int)(mp < 10 ? mp + 3 : mp - 9);                           // [1, 12]
    y = (int)(yy + (m <= 2));
}

static QPV_FORCEINLINE INT64 qpvStampFromLocalFileTime(INT64 lft) {
// Packs a local wall clock reading into the decimal YYYYMMDDHHMISS number the
// script stores, for instance 20240131235959
    INT64 days = lft / QPV_FT_PER_DAY;
    int secOfDay = (int)((lft - days * QPV_FT_PER_DAY) / QPV_FT_PER_SEC);
    int y, m, d;

    qpvCivilFromDays(days - QPV_DAYS_1601_1970, y, m, d);
    if (y < 1601 || y > 9999)
        return 0;

    return ((((((INT64)y * 100 + m) * 100 + d) * 100
            + secOfDay / 3600) * 100
            + (secOfDay / 60) % 60) * 100)
            + secOfDay % 60;
}

static INT64 qpvFileTimeToLocalStamp(INT64 ft) {
    if (ft <= 0)
        return 0;

    INT64 day = ft / QPV_FT_PER_DAY;
    unsigned slot = (unsigned)(day & (QPV_TZDAY_SLOTS - 1));
    INT64 packed = qpvTZdayCache[slot].load(std::memory_order_relaxed);
    int offMin;

    if ((packed >> 32) == day + 1)
    {
       offMin = (int)(unsigned int)(packed & 0xFFFFFFFFLL);
    } else
    {
       offMin = qpvComputeDayOffset(day);
       qpvTZdayCache[slot].store(((day + 1) << 32) | (INT64)(unsigned int)offMin, std::memory_order_relaxed);
    }

    if (offMin == QPV_TZ_TRANSITION)
    {
       INT64 lft;
       if (!qpvUTCtoLocalFileTime(ft, lft))
          return 0;

       return qpvStampFromLocalFileTime(lft);
    }

    return qpvStampFromLocalFileTime(ft + (INT64)offMin * QPV_FT_PER_MIN);
}

DLL_API int DLL_CALLCONV DirEntryTimesToLocal(const unsigned char *dirEntry, INT64 *out) {
// Reads the two file times straight out of one directory record as returned by
// GetFileInformationByHandleEx(), and writes them back as local YYYYMMDDHHMISS
// numbers: out[0] is the last write time, out[1] the creation time.
// CreationTime sits at offset 8 and LastWriteTime at offset 24 in both of the
// record layouts the script asks for, FILE_FULL_DIR_INFO and
// FILE_ID_BOTH_DIR_INFO, so one entry pointer is all this needs.
    if (!dirEntry || !out)
        return 0;

    INT64 ctime, mtime;
    std::memcpy(&ctime, dirEntry + 8, sizeof(INT64));
    std::memcpy(&mtime, dirEntry + 24, sizeof(INT64));
    out[0] = qpvFileTimeToLocalStamp(mtime);
    out[1] = qpvFileTimeToLocalStamp(ctime);
    return 1;
}
