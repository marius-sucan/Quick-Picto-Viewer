// The environment dupes-pixels.h expects to be #included into.
//
// In the real build that environment is qpv-main.cpp at line ~9200: gdiplus.h, wincodec.h,
// omp.h, freeimage-dynamic.h and thumbs-pool.h have all been seen by then. None of them
// exist here, so this file supplies the pieces the collector actually touches - enough to
// COMPILE it verbatim, and enough to drive its arithmetic.
//
// The two loaders are stubs on purpose. Nothing off Windows can decode a JPEG the way WIC
// does, and pretending otherwise would prove nothing; what this pins down is everything
// around the decode - the histogram statistics, the blue-channel dump, the queue and its
// generation counter, the cancel path, and that the whole file type-checks under -Wall.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_PIXELS_ENV_H
#define QPV_TEST_PIXELS_ENV_H

#include <windows.h>          // the shim next door: dlopen-backed LoadLibraryW, LONG, INT64
#include <cstdio>
#include <cstring>
#include <cmath>
#include <cstdlib>
#include <string>
#include <vector>
#include <deque>
#include <map>
#include <set>
#include <unordered_set>
#include <memory>
#include <thread>
#include <mutex>
#include <atomic>
#include <condition_variable>
#include <chrono>
#include <algorithm>

// ---- odds and ends from framework.h / qpv-main.h --------------------------------------
#define DLL_API
#define DLL_CALLCONV
#ifndef TRUE
#define TRUE  1
#define FALSE 0
#endif
typedef long           HRESULT;
typedef unsigned char  BYTE;
typedef unsigned long long ULONGLONG;
#define S_OK    ((HRESULT)0)
#define E_FAIL  ((HRESULT)0x80004005L)
#define SUCCEEDED(hr) (((HRESULT)(hr)) >= 0)
#define FAILED(hr)    (((HRESULT)(hr)) < 0)

struct GUID { unsigned int Data1; unsigned short Data2, Data3; unsigned char Data4[8]; };

static inline void fnOutputDebug(std::string s) { (void)s; }
static inline std::string WideCharToString(const wchar_t *w) {
    std::string o;
    for (; w && *w; w++) o.push_back((char)(*w & 0x7F));
    return o;
}
template <typename T> static inline T clamp(T v, T lo, T hi) { return (v < lo) ? lo : ((v > hi) ? hi : v); }
template <typename T> static inline void SafeRelease(T *&p, std::string, int) { p = NULL; }
static inline void omp_set_num_threads(int) { }
static inline double _wtof(const wchar_t *s) {
    std::string u;
    for (; s && *s; s++) u.push_back((char)*s);
    return atof(u.c_str());
}

// ---- file attributes ------------------------------------------------------------------
typedef struct { unsigned long long q; } QPV_FILETIME;
struct WIN32_FILE_ATTRIBUTE_DATA {
    DWORD dwFileAttributes;
    QPV_FILETIME ftCreationTime, ftLastAccessTime, ftLastWriteTime;
    DWORD nFileSizeHigh, nFileSizeLow;
};
#define GetFileExInfoStandard 0
// Files the test asks about are named, not opened: a path with "gone" in it does not
// exist, everything else does and has a plausible size. That is the one thing dpRunJob()
// branches on before it reaches a decoder.
static inline int GetFileAttributesExW(const wchar_t *path, int, WIN32_FILE_ATTRIBUTE_DATA *fad) {
    if (path==NULL || fad==NULL)
       return 0;

    const std::string p = WideCharToString(path);
    if (p.find("gone")!=std::string::npos)
       return 0;

    memset(fad, 0, sizeof(*fad));
    fad->nFileSizeLow = 4096;
    fad->ftLastWriteTime.q = 130000000000000000ull;
    fad->ftCreationTime.q  = 129000000000000000ull;
    return 1;
}
static inline DWORD GetTickCount() { return 0; }
// A real clock: dupesPixBusyJob() times a job with it, and a test that wants to see how long
// a worker has been holding one cannot do that against a constant.
static inline ULONGLONG GetTickCount64() {
    return (ULONGLONG)std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch()).count();
}

// ---- COM / WIC ------------------------------------------------------------------------
struct IWICImagingFactory { int dummy; };
static GUID CLSID_WICImagingFactory1 = {0,0,0,{0,0,0,0,0,0,0,0}};
static GUID CLSID_WICImagingFactory2 = {0,0,0,{0,0,0,0,0,0,0,0}};
#define COINIT_MULTITHREADED 0
#define CLSCTX_INPROC_SERVER 1
static inline HRESULT CoInitializeEx(void*, int) { return S_OK; }
static inline void CoUninitialize() { }
#define IID_PPV_ARGS(p) (void**)(p)
static inline HRESULT CoCreateInstance(GUID&, void*, int, void**) { return E_FAIL; }
static IWICImagingFactory *m_pIWICFactory = NULL;

// ---- GDI+ ------------------------------------------------------------------------------
//
// One synthetic bitmap type. It carries real pixels, so dpDumpBlue() and the resize can be
// checked; the effects and the histogram are driven from the test rather than computed.
namespace Gdiplus {
    enum Status { Ok = 0, GenericError = 1 };
    enum InterpolationMode { InterpolationModeDefault = 0 };
    enum SmoothingMode { SmoothingModeAntiAlias = 4 };
    enum PixelOffsetMode { PixelOffsetModeHighQuality = 2 };
    enum ImageLockMode { ImageLockModeRead = 1, ImageLockModeWrite = 2 };
    enum HistogramFormat { HistogramFormatARGB = 0, HistogramFormatGray = 3 };
    enum RotateFlipType { RotateNoneFlipNone = 0, Rotate90FlipNone = 1, Rotate270FlipNone = 3, RotateNoneFlipX = 4 };
    class CGpEffect { public: int kind = 0; };

    struct GpBitmap {
        int w = 0, h = 0;
        std::vector<unsigned char> bgra;    // w*h*4
        int flips = 0, blurs = 0, grays = 0;
        // Set by the synthetic decoders for a path the test wants to fail AFTER the
        // decode, which is the only way to reach DP_ERR_PROCESS: the histogram stub
        // below refuses a poisoned bitmap the way GDI+ refuses one when memory is gone.
        bool poisoned = false;
    };
    struct GpGraphics { GpBitmap *target = NULL; int interp = -1, smooth = -1, offset = -1; };
    struct Rect { int X, Y, Width, Height; Rect(int x, int y, int w, int h) : X(x), Y(y), Width(w), Height(h) {} };
    struct BitmapData { unsigned int Width = 0, Height = 0; int Stride = 0; void *Scan0 = NULL; };

    // These three sit at Gdiplus scope rather than in DllExports below, because that is
    // where the real SDK puts them: gdiplus.h includes gdipluseffects.h outside the
    // namespace DllExports { #include "gdiplusflat.h" } block. GdipBitmapApplyEffect(),
    // which does come from gdiplusflat.h, stays in DllExports.
    static inline Status GdipCreateEffect(const GUID, CGpEffect **fx) { *fx = new CGpEffect(); return Ok; }
    static inline Status GdipSetEffectParameters(CGpEffect *fx, const void *p, unsigned int size) {
        // 12 bytes is the hue/saturation/lightness struct, 8 the blur one
        if (fx!=NULL) fx->kind = (size==12) ? 1 : 2;
        (void)p;
        return Ok;
    }
    static inline Status GdipDeleteEffect(CGpEffect *fx) { delete fx; return Ok; }
}
typedef int PixelFormat;
#define PixelFormat32bppARGB  0x0026200A
#define PixelFormat32bppPARGB 0x000E200B

// What the histogram stub hands back, and how many times it was asked
static unsigned int  gShimHistogram[256];
static int           gShimHistogramCalls = 0;
static int           gShimGrayCalls = 0;
static int           gShimBlurCalls = 0;
static int           gShimResizeCalls = 0;
static int           gShimFlipCalls = 0;

namespace Gdiplus { namespace DllExports {

static inline Status GdipCreateBitmapFromScan0(int w, int h, int, PixelFormat, BYTE*, GpBitmap **out) {
    GpBitmap *b = new GpBitmap();
    b->w = w; b->h = h;
    b->bgra.assign((size_t)w*h*4, 0);
    *out = b;
    return Ok;
}
static inline Status GdipDisposeImage(GpBitmap *b) { delete b; return Ok; }
static inline Status GdipGetImageWidth(GpBitmap *b, unsigned int *w)  { *w = (unsigned int)(b ? b->w : 0); return Ok; }
static inline Status GdipGetImageHeight(GpBitmap *b, unsigned int *h) { *h = (unsigned int)(b ? b->h : 0); return Ok; }

static inline Status GdipBitmapLockBits(GpBitmap *b, Rect *r, int, PixelFormat, BitmapData *bd) {
    if (b==NULL || bd==NULL || r==NULL)
       return GenericError;

    bd->Width = (unsigned int)b->w;
    bd->Height = (unsigned int)b->h;
    bd->Stride = b->w*4;
    bd->Scan0 = b->bgra.data();
    return Ok;
}
static inline Status GdipBitmapUnlockBits(GpBitmap*, BitmapData*) { return Ok; }

static inline Status GdipBitmapGetHistogram(GpBitmap *b, HistogramFormat, unsigned int n,
                                            unsigned int *c0, unsigned int*, unsigned int*, unsigned int*) {
    if (b==NULL || c0==NULL || n!=256)
       return GenericError;

    if (b->poisoned)      // decoded, then the chain after it failed
       return GenericError;

    gShimHistogramCalls++;
    memcpy(c0, gShimHistogram, sizeof(gShimHistogram));
    return Ok;
}

static inline Status GdipBitmapApplyEffect(GpBitmap *b, CGpEffect *fx, void*, BOOL, void**, int*) {
    if (b==NULL || fx==NULL)
       return GenericError;

    if (fx->kind==1) { b->grays++; gShimGrayCalls++; }
    else             { b->blurs++; gShimBlurCalls++; }
    return Ok;
}
static inline Status GdipImageRotateFlip(GpBitmap *b, RotateFlipType t) {
    if (b==NULL)
       return GenericError;

    if (t==RotateNoneFlipX)
    {
       for ( int y = 0 ; y < b->h ; y++)
           for ( int x = 0 ; x < b->w/2 ; x++)
               for ( int k = 0 ; k < 4 ; k++)
                   std::swap(b->bgra[((size_t)y*b->w + x)*4 + k],
                             b->bgra[((size_t)y*b->w + (b->w - 1 - x))*4 + k]);
       b->flips++;
       gShimFlipCalls++;
    }
    return Ok;
}

static inline Status GdipGetImageGraphicsContext(GpBitmap *b, GpGraphics **g) {
    GpGraphics *gg = new GpGraphics();
    gg->target = b;
    *g = gg;
    return Ok;
}
static inline Status GdipSetInterpolationMode(GpGraphics *g, InterpolationMode m) { g->interp = (int)m; return Ok; }
static inline Status GdipSetSmoothingMode(GpGraphics *g, SmoothingMode m)         { g->smooth = (int)m; return Ok; }
static inline Status GdipSetPixelOffsetMode(GpGraphics *g, PixelOffsetMode m)     { g->offset = (int)m; return Ok; }
// nearest neighbour; the point is that the destination really is filled from the source
static inline Status GdipDrawImageRectI(GpGraphics *g, GpBitmap *src, int, int, int w, int h) {
    if (g==NULL || g->target==NULL || src==NULL || src->w < 1 || src->h < 1)
       return GenericError;

    gShimResizeCalls++;
    GpBitmap *dst = g->target;
    for ( int y = 0 ; y < h && y < dst->h ; y++)
    {
        const int sy = (int)((double)y*src->h/h);
        for ( int x = 0 ; x < w && x < dst->w ; x++)
        {
            const int sx = (int)((double)x*src->w/w);
            memcpy(&dst->bgra[((size_t)y*dst->w + x)*4], &src->bgra[((size_t)sy*src->w + sx)*4], 4);
        }
    }
    return Ok;
}
static inline Status GdipDeleteGraphics(GpGraphics *g) { delete g; return Ok; }

}} // namespace Gdiplus::DllExports

// ---- FreeImage and the thumbnails pool -------------------------------------------------
struct QpvFIMstub { bool ok = false; };
static QpvFIMstub FIM;
static inline void bindFreeImageOnce() { }

#define TP_ERR_LOAD 1
// mirrors TpSrcMeta of thumbs-pool.h; the stubbed loaders below fill it the way the real
// ones do, so the collector's imgframes/imgdpi/imgpixfmt path is exercised here too
#define FIC_RGBALPHA 4
struct TpSrcMeta {
    int frames = 1;
    int dpi = 0;
    int wicFmt = -1;
    int fimBPP = 0;
    int fimColor = -1;
    int fimToneMap = 0;
};

struct ThumbsConfig {
    int thumbSize = 250, timePerImg = 25, enableCaching = 1, userHQraw = 1, allowToneMapping = 1;
    int allowWIC = 1, allowFIM = 1, imgQuality = 5, toneMapAlgo = 0;
    float tmParamA = 0, tmParamB = 0, tmParamC = 0, tmParamD = 0, tmOCVparamA = 0, tmOCVparamB = 0;
    int tmAltExpo = 0, wantBitmap = 1, alwaysSave = 0;
};

static std::unordered_set<std::wstring> tpWicExts;
static std::unordered_set<std::wstring> tpFimExts;

// The real one samples GlobalMemoryStatusEx() a few times a second. Here the tests say when
// the machine is short of memory, because that is the state in which the collector's job
// slot handling is the only thing keeping the pool moving.
static bool gShimMemoryTight = false;
static inline bool tpMemoryIsTight() { return gShimMemoryTight; }

// The shared job-slot count of thumbs-pool.h. Mirrored here the way ThumbsConfig and
// TpSrcMeta are: while memory is tight only the worker that finds no decode running is let
// through, so both pools of the DLL together decode one image at a time. gShimMaxActiveJobs
// is the high-water mark, which is what a test can assert on.
static std::atomic<LONG> tpActiveJobs(0);
static std::atomic<int>  gShimMaxActiveJobs(0);

static inline bool tpTryTakeJobSlot() {
    for (;;)
    {
        LONG active = tpActiveJobs.load(std::memory_order_acquire);
        if (active>=1 && tpMemoryIsTight())
           return false;

        if (tpActiveJobs.compare_exchange_weak(active, active + 1, std::memory_order_acq_rel))
        {
           int taken = (int)active + 1, seen = gShimMaxActiveJobs.load();
           while (taken > seen && !gShimMaxActiveJobs.compare_exchange_weak(seen, taken))
               ;
           return true;
        }
    }
}

static inline void tpReleaseJobSlot() {
    tpActiveJobs.fetch_sub(1, std::memory_order_acq_rel);
}

struct TpJobSlot {
    ~TpJobSlot() { tpReleaseJobSlot(); }
};

static inline std::wstring tpLowerCase(const std::wstring &s) {
    std::wstring r = s;
    for (size_t i = 0; i < r.size(); i++)
        if (r[i] >= L'A' && r[i] <= L'Z') r[i] = (wchar_t)(r[i] - L'A' + L'a');
    return r;
}
static inline std::wstring tpFileExtension(const std::wstring &path) {
    size_t dot = path.find_last_of(L'.');
    size_t sep = path.find_last_of(L"\\/");
    if (dot==std::wstring::npos || (sep!=std::wstring::npos && dot < sep))
       return L"";
    return tpLowerCase(path.substr(dot + 1));
}

// The synthetic decoders. The gShim*Fails switches make one refuse, which is how the
// fallbacks down the chain get exercised; every one of them records what it was asked for.
static int gShimWicFails = 0;
static int gShimFimFails = 0;
static int gShimWicCalls = 0;
static int gShimFimCalls = 0;
static int gShimDecodeW = 40, gShimDecodeH = 30;

static bool shimPathHas(const wchar_t *path, const wchar_t *needle) {
    return (path!=NULL && needle!=NULL && wcsstr(path, needle)!=NULL);
}

// The time a decoder pretends to spend waiting for the disk. Zero - the default - leaves
// every other test exactly as fast as it was; pool_latency.cpp raises it, because the one
// thing that differs between a run over an SSD and a run over a mechanical drive is how
// long a decode takes, and the pool's queue behaviour is supposed to be the same either
// way. A path carrying "slow" is the straggler: the single huge file at the tail of a run.
static std::atomic<int> gShimDecodeSleepMs(0);
static std::atomic<int> gShimDecodeJitterMs(0);
static std::atomic<int> gShimStragglerFactor(25);

static void shimFakeDiskDelay(const wchar_t *path) {
    int ms = gShimDecodeSleepMs.load();
    if (ms < 1)
       return;

    const int jitter = gShimDecodeJitterMs.load();
    if (jitter > 0)
    {
       // deterministic per path, so a run is repeatable
       unsigned int h = 2166136261u;
       for ( const wchar_t *p = path ; p!=NULL && *p ; p++)
           h = (h ^ (unsigned int)*p) * 16777619u;

       ms += (int)(h % (unsigned int)jitter);
    }

    if (shimPathHas(path, L"slow"))
       ms *= gShimStragglerFactor.load();

    std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

static Gdiplus::GpBitmap *shimMakeBitmap(int w, int h, unsigned char seed) {
    Gdiplus::GpBitmap *b = NULL;
    Gdiplus::DllExports::GdipCreateBitmapFromScan0(w, h, 0, PixelFormat32bppPARGB, NULL, &b);
    for ( int y = 0 ; y < h ; y++)
        for ( int x = 0 ; x < w ; x++)
        {
            const unsigned char v = (unsigned char)((x*7 + y*13 + seed) & 0xFF);
            b->bgra[((size_t)y*w + x)*4 + 0] = v;          // blue, the channel that is read
            b->bgra[((size_t)y*w + x)*4 + 1] = (unsigned char)(v ^ 0x5A);
            b->bgra[((size_t)y*w + x)*4 + 2] = (unsigned char)(v ^ 0xA5);
            b->bgra[((size_t)y*w + x)*4 + 3] = 255;
        }
    return b;
}

static inline Gdiplus::GpBitmap* tpWICload(IWICImagingFactory*, const wchar_t *path, int, int, int, int, int,
                                           int &srcW, int &srcH, TpSrcMeta *meta = NULL) {
    gShimWicCalls++;
    shimFakeDiskDelay(path);
    if (gShimWicFails)
    {
       // a failed WIC attempt still touches the record, which is what dpDecodeFile() has
       // to clear before it hands the file to FreeImage
       if (meta!=NULL)
       {
          meta->frames = 99;
          meta->dpi    = 999;
          meta->wicFmt = 15;
       }
       return NULL;
    }

    srcW = gShimDecodeW*4;
    srcH = gShimDecodeH*4;
    if (meta!=NULL)
    {
       meta->frames = 3;
       meta->dpi    = 72;
       meta->wicFmt = 15;         // "24-bpp - BGR"
    }

    Gdiplus::GpBitmap *b = shimMakeBitmap(gShimDecodeW, gShimDecodeH, (unsigned char)(path ? path[3] : 0));
    if (b!=NULL && path!=NULL && shimPathHas(path, L"poison"))
       b->poisoned = true;

    return b;
}

static inline Gdiplus::GpBitmap* tpFIMthumb(const ThumbsConfig*, const std::wstring &path, const std::wstring&,
                                            DWORD, int &srcW, int &srcH, int &status, int &saved,
                                            TpSrcMeta *meta = NULL) {
    gShimFimCalls++;
    shimFakeDiskDelay(path.c_str());
    saved = 0;
    status = TP_ERR_LOAD;
    // "nofim" in the name is a file FreeImage alone refuses, the way an EMF or one of the
    // GIFs its plugin chokes on does; gShimFimFails is the same thing for every file
    if (gShimFimFails || shimPathHas(path.c_str(), L"nofim"))
    {
       // a failed attempt still touches the record, which is what dpDecodeFile() has to
       // clear before it hands the file to the loader after it
       if (meta!=NULL)
       {
          meta->frames   = 77;
          meta->dpi      = 777;
          meta->fimBPP   = 8;
          meta->fimColor = 3;
       }
       return NULL;
    }

    srcW = gShimDecodeW*2;
    srcH = gShimDecodeH*2;
    status = 0;
    if (meta!=NULL)
    {
       meta->frames     = 1;
       meta->dpi        = 300;
       meta->fimBPP     = 48;
       meta->fimColor   = 2;      // FIC_RGB -> "48-RGB"
       meta->fimToneMap = 2;      // " (TONE-MAPPABLE)"
    }

    Gdiplus::GpBitmap *b = shimMakeBitmap(gShimDecodeW, gShimDecodeH, (unsigned char)(path.size() & 0xFF));
    if (b!=NULL && shimPathHas(path.c_str(), L"poison"))
       b->poisoned = true;

    return b;
}

// ---- the three loaders dupes-pixels.h shares with the thumbnails pool -------------------
//
// The SVG renderer, PDFium and GDI+, stubbed the way the two above are. What the tests drive
// with them is the DISPATCH: which loader a given extension reaches, in which order, and
// what each one leaves in TpSrcMeta - not the decoding, which nothing off Windows can do.
struct ID2D1Factory { int dummy; };
#define D2D1_FACTORY_TYPE_SINGLE_THREADED 0
static int gShimD2DfactoryCalls = 0;
static inline HRESULT D2D1CreateFactory(int, ID2D1Factory **f) {
    gShimD2DfactoryCalls++;
    *f = new ID2D1Factory();
    return S_OK;
}

// the real one lives in thumbs-pool.h and is shared BETWEEN the two pools, because PDFium
// keeps global state
static std::mutex tpPdfMutex;

static int gShimSvgCalls = 0, gShimPdfCalls = 0, gShimGdipCalls = 0;
static int gShimSvgFails = 0, gShimPdfFails = 0, gShimGdipFails = 0;

static inline Gdiplus::GpBitmap* tpRenderSVG(const std::wstring &path, int, int, int &srcW, int &srcH,
                                             ID2D1Factory*, IWICImagingFactory*) {
    gShimSvgCalls++;
    if (gShimSvgFails)
       return NULL;

    // the size the document declares, which is what RenderSVGfile() reports as well
    srcW = 200;
    srcH = 100;
    return shimMakeBitmap(gShimDecodeW, gShimDecodeH, (unsigned char)(path.size() & 0xFF));
}

static inline Gdiplus::GpBitmap* RenderPdfPageAsBitmap(const wchar_t *path, int, float, int *givenW, int *givenH,
                                                       int, int, int *varOut, int *errorType, const wchar_t*, int) {
    gShimPdfCalls++;
    *errorType = 0;
    if (gShimPdfFails)
    {
       *errorType = 4;            // FPDF: the document wants a password
       return NULL;
    }

    *varOut = 5;                  // pages
    *givenW = 612;                // the PAGE, in points - what the real one hands back
    *givenH = 792;
    return shimMakeBitmap(gShimDecodeW, gShimDecodeH, (unsigned char)(path ? path[0] : 0));
}

static inline Gdiplus::GpBitmap* tpGDIPload(const std::wstring &path, int, int, int, int,
                                            int &srcW, int &srcH, TpSrcMeta *meta = NULL) {
    gShimGdipCalls++;
    if (gShimGdipFails)
       return NULL;

    srcW = gShimDecodeW*3;
    srcH = gShimDecodeH*3;
    if (meta!=NULL)
    {
       meta->frames = 7;          // an animated GIF; GDI+ counts the time dimension
       meta->dpi    = 96;
    }

    return shimMakeBitmap(gShimDecodeW, gShimDecodeH, (unsigned char)(path.size() & 0xFF));
}

// ---- the two names dupes-pixels.h borrows from the query engine ------------------------
#include "../../sqlite-dynamic.h"
static std::wstring dupesEngineError;
static std::atomic<int> dupesPixCancel(0);
static inline void dupesSetError(const wchar_t *what) { dupesEngineError = (what!=NULL) ? what : L""; }

#endif // QPV_TEST_PIXELS_ENV_H
