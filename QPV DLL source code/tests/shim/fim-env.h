// The environment the FreeImage loader of thumbs-pool.h expects to be #included into.
//
// In the real build that is qpv-main.cpp. Here FreeImage is the real library - the Linux
// build of QPV's fork, bound by the shipped freeimage-dynamic.h through shim/fim/windows.h -
// and everything else tpFIMthumb() borrows is supplied below:
//
//   - openCVresizeBitmapExtended() really resizes, into the bitmap tpFIMrescale() allocated,
//     and like OpenCV it carries over nothing but the pixels: no ICC profile, no CICP tag.
//     That loss is what decides where the tone mapping verdict may be taken, so a stand-in
//     that kept them would hide the very mistake this harness exists to catch.
//   - openCVapplyToneMappingAlgos() declines, so FreeImage_ToneMapping() runs, as it does for
//     toneMapAlgo 0 to 2.
//   - the flat GDI+ calls tpFIMtoGdip() makes keep a copy of the pixels, so a test can
//     measure what the thumbnail looks like.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_FIM_ENV_H
#define QPV_TEST_FIM_ENV_H

#include <windows.h>      // shim/fim/windows.h
#include <cstdio>
#include <cstring>
#include <cmath>
#include <cwchar>
#include <cwctype>
#include <string>
#include <vector>
#include <mutex>
#include <chrono>
#include <algorithm>
#include <cstddef>
#include <type_traits>

template <typename T> static inline T clamp(T v, T lo, T hi) { return (v < lo) ? lo : ((v > hi) ? hi : v); }
#ifndef min
#define min(a, b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef max
#define max(a, b) (((a) > (b)) ? (a) : (b))
#endif

static std::string gShimLastDebug;
static inline void fnOutputDebug(std::string s) { gShimLastDebug = s; }
static inline std::string WideCharToString(const wchar_t *w) {
    std::string o;
    for (; w && *w; w++) o.push_back((char)(*w & 0x7F));
    return o;
}

static inline DWORD GetTickCount() {
    return (DWORD)std::chrono::duration_cast<std::chrono::milliseconds>(
                  std::chrono::steady_clock::now().time_since_epoch()).count();
}

// qpv-main.cpp's: the extension after the last dot, compared without regard to case
static inline bool IsFileExtension(const wchar_t *szFileName, const wchar_t *extension) {
    if (!szFileName || !extension || extension[0]!=L'.')
       return false;

    const wchar_t *fileExt = wcsrchr(szFileName, L'.');
    if (!fileExt || wcslen(fileExt)!=wcslen(extension))
       return false;

    for (size_t i = 0; fileExt[i]; i++)
        if (towlower(fileExt[i])!=towlower(extension[i]))
           return false;
    return true;
}

namespace cv { enum { INTER_NEAREST = 0, INTER_LINEAR = 1, INTER_CUBIC = 2, INTER_AREA = 3 }; }

static int gShimCvResizes = 0;

template <typename T>
static void shimResizeRows(const BYTE *src, BYTE *dst, int w, int h, int stride, int nw, int nh, int mStride, int channels) {
    for (int y = 0; y < nh; y++)
    {
        const int y0 = (int)((long long)y*h/nh), y1 = max(y0 + 1, (int)((long long)(y + 1)*h/nh));
        T *out = (T*)(dst + (size_t)y*mStride);
        for (int x = 0; x < nw; x++)
        {
            const int x0 = (int)((long long)x*w/nw), x1 = max(x0 + 1, (int)((long long)(x + 1)*w/nw));
            for (int c = 0; c < channels; c++)
            {
                double sum = 0;
                for (int yy = y0; yy < y1 && yy < h; yy++)
                {
                    const T *row = (const T*)(src + (size_t)yy*stride);
                    for (int xx = x0; xx < x1 && xx < w; xx++)
                        sum += (double)row[(size_t)xx*channels + c];
                }
                const double avg = sum/((double)(min(y1, h) - y0)*(min(x1, w) - x0));
                out[(size_t)x*channels + c] = std::is_floating_point<T>::value ? (T)avg : (T)(avg + 0.5);
            }
        }
    }
}

// cv::resize() over the whole image: a box average shrinking, the nearest pixel enlarging
static int openCVresizeBitmapExtended(unsigned char *imageData, unsigned char *otherData, int w, int h, int Stride,
                                      int rx, int ry, int rw, int rh, int nw, int nh, int mStride, int bpp, int) {
    if (!imageData || !otherData || rx!=0 || ry!=0 || rw!=w || rh!=h || nw<1 || nh<1)
       return 0;

    gShimCvResizes++;
    switch (bpp)
    {
        case 24:  shimResizeRows<uint8_t>(imageData, otherData, w, h, Stride, nw, nh, mStride, 3); return 1;
        case 32:  shimResizeRows<uint8_t>(imageData, otherData, w, h, Stride, nw, nh, mStride, 4); return 1;
        case 48:  shimResizeRows<uint16_t>(imageData, otherData, w, h, Stride, nw, nh, mStride, 3); return 1;
        case 64:  shimResizeRows<uint16_t>(imageData, otherData, w, h, Stride, nw, nh, mStride, 4); return 1;
        case 96:  shimResizeRows<float>(imageData, otherData, w, h, Stride, nw, nh, mStride, 3); return 1;
        case 128: shimResizeRows<float>(imageData, otherData, w, h, Stride, nw, nh, mStride, 4); return 1;
    }
    return 0;
}

static inline int openCVapplyToneMappingAlgos(float*, int, int, int, unsigned char*, int, int, float, float, float, float, int) {
    return 0;
}

// ---- flat GDI+, keeping the pixels -----------------------------------------------------------

typedef int PixelFormat;
#define PixelFormat32bppARGB   0x0026200A
#define PixelFormat32bppPARGB  0x000E200B

namespace Gdiplus {
    enum Status { Ok = 0, GenericError = 1 };
    struct GpBitmap {
        int w = 0, h = 0, bpp = 0, stride = 0;
        std::vector<BYTE> px;
    };
}

static int gShimLiveBitmaps = 0;

namespace Gdiplus { namespace DllExports {

static inline Status GdipCreateBitmapFromScan0(INT w, INT h, INT stride, PixelFormat, BYTE *scan0, GpBitmap **out) {
    *out = NULL;
    if (w<1 || h<1 || !scan0 || stride<w*4)
       return GenericError;

    GpBitmap *b = new GpBitmap();
    b->w = w;  b->h = h;  b->bpp = 32;  b->stride = stride;
    b->px.assign(scan0, scan0 + (size_t)stride*h);
    gShimLiveBitmaps++;
    *out = b;
    return Ok;
}

static inline Status GdipCreateBitmapFromGdiDib(const BITMAPINFO *info, void *bits, GpBitmap **out) {
    *out = NULL;
    if (!info || !bits || info->bmiHeader.biWidth<1 || info->bmiHeader.biHeight<1)
       return GenericError;

    const int bpp = info->bmiHeader.biBitCount;
    if (bpp!=24 && bpp!=32)
       return GenericError;   // the shim only reads what tpFIMtoGdip() is left with

    GpBitmap *b = new GpBitmap();
    b->w = info->bmiHeader.biWidth;
    b->h = info->bmiHeader.biHeight;
    b->bpp = bpp;
    b->stride = ((b->w*bpp + 31)/32)*4;
    const BYTE *p = (const BYTE*)bits;
    b->px.assign(p, p + (size_t)b->stride*b->h);
    gShimLiveBitmaps++;
    *out = b;
    return Ok;
}

static inline Status GdipCloneBitmapAreaI(INT x, INT y, INT w, INT h, PixelFormat, GpBitmap *src, GpBitmap **out) {
    *out = NULL;
    if (!src || x!=0 || y!=0 || w!=src->w || h!=src->h)
       return GenericError;

    GpBitmap *b = new GpBitmap(*src);
    gShimLiveBitmaps++;
    *out = b;
    return Ok;
}

static inline Status GdipDisposeImage(GpBitmap *b) {
    if (!b)
       return GenericError;
    delete b;
    gShimLiveBitmaps--;
    return Ok;
}

} } // namespace Gdiplus::DllExports

// the average of the blue, green and red samples of a bitmap, 0 to 255, and of each of them
static inline double shimMeanBGR(const Gdiplus::GpBitmap *b, double *perChannel = NULL) {
    if (!b || b->w<1 || b->h<1)
       return -1;

    const int step = b->bpp/8;
    double sum[3] = {0, 0, 0};
    for (int y = 0; y < b->h; y++)
    {
        const BYTE *row = &b->px[(size_t)y*b->stride];
        for (int x = 0; x < b->w; x++)
            for (int c = 0; c < 3; c++)
                sum[c] += row[x*step + c];
    }

    const double n = (double)b->w*b->h;
    if (perChannel)
       for (int c = 0; c < 3; c++)
           perChannel[c] = sum[c]/n;
    return (sum[0] + sum[1] + sum[2])/(3.0*n);
}

// how colourful a bitmap is: the average of each pixel's largest channel minus its smallest
static inline double shimMeanChroma(const Gdiplus::GpBitmap *b) {
    if (!b || b->w<1 || b->h<1)
       return -1;

    const int step = b->bpp/8;
    double sum = 0;
    for (int y = 0; y < b->h; y++)
    {
        const BYTE *row = &b->px[(size_t)y*b->stride];
        for (int x = 0; x < b->w; x++)
        {
            const BYTE *p = row + x*step;
            sum += max(p[0], max(p[1], p[2])) - min(p[0], min(p[1], p[2]));
        }
    }
    return sum/((double)b->w*b->h);
}

#endif // QPV_TEST_FIM_ENV_H
