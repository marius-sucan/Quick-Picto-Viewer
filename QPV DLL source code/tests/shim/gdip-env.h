// The environment the GDI+ loader of thumbs-pool.h expects to be #included into.
//
// In the real build that is qpv-main.cpp, with gdiplus.h and the WIC guards already seen.
// None of that exists here, so this file supplies the flat GDI+ entry points tpGDIPload()
// touches - as a synthetic image library the test drives - plus the two names it borrows
// from qpv-main.cpp, WICcodecCrashFilter() and GetExceptionCode().
//
// __try/__except are mapped onto a dead branch rather than dropped: both blocks and the
// filter expression are then compiled and type-checked, which is the point of running this
// at all on a box where the DLL cannot be built. Nothing here can raise a structured
// exception, so the handler is never entered.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_GDIP_ENV_H
#define QPV_TEST_GDIP_ENV_H

#include <cstdio>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>

typedef unsigned int  UINT;
typedef unsigned long DWORD;
typedef unsigned char BYTE;
typedef int           PixelFormat;
#define PixelFormat32bppARGB  0x0026200A

struct GUID { unsigned int Data1; unsigned short Data2, Data3; unsigned char Data4[8]; };

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

// The SEH plumbing, compiled but never entered. libstdc++ has a __try of its own - it maps
// onto C++ try when exceptions are enabled - and that one cannot carry an __except, so it
// goes first.
static inline DWORD GetExceptionCode() { return 0; }
static inline int WICcodecCrashFilter(DWORD) { return 0; }
#undef __try
#undef __except
#define __try           if (true)
#define __except(filter) else if (!(filter))

// ---- the synthetic image library --------------------------------------------------------
//
// One file table the test fills in. tpGDIPload() is a loader: what it must get right is
// which numbers it reads off the image, that it selects a frame before it measures, that it
// hands back a COPY, and that the original - the one holding the file open - is disposed.

namespace Gdiplus {
    enum Status { Ok = 0, GenericError = 1 };
    enum InterpolationMode { InterpolationModeDefault = 0 };
    enum SmoothingMode { SmoothingModeAntiAlias = 4 };
    enum PixelOffsetMode { PixelOffsetModeHighQuality = 2 };
    typedef float REAL;

    struct GpBitmap {
        int w = 0, h = 0;
        UINT frames = 1;
        REAL dpix = 0.0f, dpiy = 0.0f;
        int  selectedFrame = -1;
        bool fromFile = false;       // true for the one that holds the file open
    };
    struct GpGraphics { GpBitmap *target = NULL; int interp = -1, smooth = -1, offset = -1; };
}

// every bitmap ever made, and whether it is still alive. A loader that leaves the
// file-backed original undisposed leaves a lock on the file in the shipped product.
static std::vector<Gdiplus::GpBitmap*> gShimAlive;
static int gShimCreatedFromFile = 0, gShimCreatedBlank = 0;
static int gShimDisposed = 0;

// what the next GdipCreateBitmapFromFile() hands back
static int  gShimFileW = 400, gShimFileH = 300;
static UINT gShimFileFrames = 1;
static float gShimFileDpi = 96.0f;
static int  gShimLoadFails = 0;         // the file cannot be opened at all
static int  gShimDimensionsFail = 0;    // the frame dimension list is not available
static int  gShimResolutionFails = 0;   // GdipGetImage*Resolution refuses
static int  gShimGraphicsFails = 0;     // no graphics context for the destination
static int  gShimSelectedFrame = -1;    // the frame the loader asked for, if any
static PixelFormat gShimLastCreateFormat = 0;

// what the last DrawImage was asked for, so the test can read the modes back off it
static int gShimDrawInterp = -1, gShimDrawSmooth = -1, gShimDrawOffset = -1;
static int gShimDrawW = 0, gShimDrawH = 0, gShimDrawCalls = 0;

static inline void gShimReset() {
    for (size_t i = 0; i < gShimAlive.size(); i++)
        delete gShimAlive[i];

    gShimAlive.clear();
    gShimCreatedFromFile = gShimCreatedBlank = gShimDisposed = 0;
    gShimLoadFails = gShimDimensionsFail = gShimResolutionFails = gShimGraphicsFails = 0;
    gShimSelectedFrame = -1;
    gShimLastCreateFormat = 0;
    gShimFileW = 400;
    gShimFileH = 300;
    gShimFileFrames = 1;
    gShimFileDpi = 96.0f;
    gShimDrawInterp = gShimDrawSmooth = gShimDrawOffset = -1;
    gShimDrawW = gShimDrawH = gShimDrawCalls = 0;
}

static inline int gShimLiveCount() {
    return (int)gShimAlive.size();
}

static inline bool gShimIsAlive(const Gdiplus::GpBitmap *b) {
    return (std::find(gShimAlive.begin(), gShimAlive.end(), b)!=gShimAlive.end());
}

namespace Gdiplus { namespace DllExports {

static inline Status GdipCreateBitmapFromFile(const wchar_t *path, GpBitmap **out) {
    if (path==NULL || out==NULL)
       return GenericError;

    *out = NULL;
    if (gShimLoadFails)
       return GenericError;

    GpBitmap *b = new GpBitmap();
    b->w = gShimFileW;
    b->h = gShimFileH;
    b->frames = gShimFileFrames;
    b->dpix = b->dpiy = gShimFileDpi;
    b->fromFile = true;
    gShimAlive.push_back(b);
    gShimCreatedFromFile++;
    *out = b;
    return Ok;
}

static inline Status GdipCreateBitmapFromScan0(int w, int h, int, PixelFormat fmt, BYTE*, GpBitmap **out) {
    gShimLastCreateFormat = fmt;
    GpBitmap *b = new GpBitmap();
    b->w = w;
    b->h = h;
    gShimAlive.push_back(b);
    gShimCreatedBlank++;
    *out = b;
    return Ok;
}

static inline Status GdipDisposeImage(GpBitmap *b) {
    if (b==NULL)
       return GenericError;

    std::vector<GpBitmap*>::iterator it = std::find(gShimAlive.begin(), gShimAlive.end(), b);
    if (it==gShimAlive.end())
       return GenericError;          // a double dispose; the test asserts this never happens

    gShimAlive.erase(it);
    gShimDisposed++;
    delete b;
    return Ok;
}

static inline Status GdipGetImageWidth(GpBitmap *b, UINT *w)  { *w = (UINT)(b ? b->w : 0); return Ok; }
static inline Status GdipGetImageHeight(GpBitmap *b, UINT *h) { *h = (UINT)(b ? b->h : 0); return Ok; }

static inline Status GdipImageGetFrameDimensionsCount(GpBitmap *b, UINT *count) {
    if (b==NULL || count==NULL)
       return GenericError;

    *count = gShimDimensionsFail ? 0 : 1;
    return gShimDimensionsFail ? GenericError : Ok;
}

static inline Status GdipImageGetFrameDimensionsList(GpBitmap *b, GUID *ids, UINT count) {
    if (b==NULL || ids==NULL || count<1 || gShimDimensionsFail)
       return GenericError;

    memset(ids, 0, sizeof(GUID)*count);
    return Ok;
}

static inline Status GdipImageGetFrameCount(GpBitmap *b, const GUID *id, UINT *count) {
    if (b==NULL || id==NULL || count==NULL)
       return GenericError;

    *count = b->frames;
    return Ok;
}

static inline Status GdipImageSelectActiveFrame(GpBitmap *b, const GUID *id, UINT frame) {
    if (b==NULL || id==NULL || frame>=b->frames)
       return GenericError;

    b->selectedFrame = (int)frame;
    gShimSelectedFrame = (int)frame;
    return Ok;
}

static inline Status GdipGetImageHorizontalResolution(GpBitmap *b, REAL *r) {
    if (b==NULL || r==NULL || gShimResolutionFails)
       return GenericError;

    *r = b->dpix;
    return Ok;
}

static inline Status GdipGetImageVerticalResolution(GpBitmap *b, REAL *r) {
    if (b==NULL || r==NULL || gShimResolutionFails)
       return GenericError;

    *r = b->dpiy;
    return Ok;
}

static inline Status GdipGetImageGraphicsContext(GpBitmap *b, GpGraphics **g) {
    if (b==NULL || g==NULL || gShimGraphicsFails)
       return GenericError;

    GpGraphics *gg = new GpGraphics();
    gg->target = b;
    *g = gg;
    return Ok;
}

static inline Status GdipSetInterpolationMode(GpGraphics *g, InterpolationMode m) { g->interp = (int)m; return Ok; }
static inline Status GdipSetSmoothingMode(GpGraphics *g, SmoothingMode m)         { g->smooth = (int)m; return Ok; }
static inline Status GdipSetPixelOffsetMode(GpGraphics *g, PixelOffsetMode m)     { g->offset = (int)m; return Ok; }

static inline Status GdipDrawImageRectI(GpGraphics *g, GpBitmap *src, int, int, int w, int h) {
    if (g==NULL || g->target==NULL || src==NULL)
       return GenericError;

    gShimDrawInterp = g->interp;
    gShimDrawSmooth = g->smooth;
    gShimDrawOffset = g->offset;
    gShimDrawW = w;
    gShimDrawH = h;
    gShimDrawCalls++;
    return Ok;
}

static inline Status GdipDeleteGraphics(GpGraphics *g) { delete g; return Ok; }

}} // namespace Gdiplus::DllExports

// mirrors TpSrcMeta of thumbs-pool.h; the loader fills the two fields it can know
struct TpSrcMeta {
    int frames    = 1;
    int dpi       = 0;
    int wicFmt    = -1;
    int fimBPP    = 0;
    int fimColor  = -1;
    int fimToneMap = 0;
};

#endif // QPV_TEST_GDIP_ENV_H
