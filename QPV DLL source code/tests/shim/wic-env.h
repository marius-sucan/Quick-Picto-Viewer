// The environment the WIC loader of thumbs-pool.h expects to be #included into, for
// wic_icm.cpp: the WIC interfaces tpWICload() and the guards of qpv-main.cpp call, declared
// with the Windows SDK's signatures, and scriptable fakes behind them.
//
// The fakes keep real reference counts and a count of the objects alive, so a test can
// require that a decode leaves nothing behind and releases nothing twice. Pixels flow through
// them: the frame is grey 100, the colour transform adds 50, the scaler samples whatever it
// was given and the converter passes it on - so the bitmap at the end says whether the
// transform was in the chain.
//
// HRESULT is 32 bits on purpose: under LP64 a long HRESULT makes E_FAIL a positive number,
// and SUCCEEDED() true for every failure.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_WIC_ENV_H
#define QPV_TEST_WIC_ENV_H

#include <cstdio>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>
#include <array>
#include <atomic>
#include <algorithm>

typedef int            HRESULT;
typedef int            INT;
typedef int            BOOL;
typedef unsigned int   UINT;
typedef uint32_t       DWORD;
typedef uint32_t       ULONG;
typedef int32_t        LONG;
typedef uint64_t       UINT64;
typedef int64_t        INT64;
typedef uintptr_t      UINT_PTR;
typedef unsigned char  BYTE;
typedef const wchar_t* LPCWSTR;

#define S_OK           ((HRESULT)0)
#define E_FAIL         ((HRESULT)0x80004005)
#define E_POINTER      ((HRESULT)0x80004003)
#define E_NOINTERFACE  ((HRESULT)0x80004002)
#define E_NOTIMPL      ((HRESULT)0x80004001)
#define E_UNEXPECTED   ((HRESULT)0x8000FFFF)
#define E_INVALIDARG   ((HRESULT)0x80070057)
#define SUCCEEDED(hr)  (((HRESULT)(hr)) >= 0)
#define FAILED(hr)     (((HRESULT)(hr)) < 0)
#define GENERIC_READ   0x80000000u

#define EXCEPTION_ACCESS_VIOLATION      0xC0000005u
#define EXCEPTION_ARRAY_BOUNDS_EXCEEDED 0xC000008Cu
#define EXCEPTION_DATATYPE_MISALIGNMENT 0x80000002u
#define EXCEPTION_ILLEGAL_INSTRUCTION   0xC000001Du
#define EXCEPTION_IN_PAGE_ERROR         0xC0000006u
#define EXCEPTION_INT_DIVIDE_BY_ZERO    0xC0000094u
#define EXCEPTION_INT_OVERFLOW          0xC0000095u
#define EXCEPTION_PRIV_INSTRUCTION      0xC0000096u
#define EXCEPTION_EXECUTE_HANDLER       1
#define EXCEPTION_CONTINUE_SEARCH       0

template <typename T> static inline T clamp(T v, T lo, T hi) { return (v < lo) ? lo : ((v > hi) ? hi : v); }
#ifndef min
#define min(a, b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef max
#define max(a, b) (((a) > (b)) ? (a) : (b))
#endif

static std::vector<std::string> gShimDebug;
static inline void fnOutputDebug(std::string s) { gShimDebug.push_back(s); }
static inline std::string WideCharToString(const wchar_t *w) {
    std::string o;
    for (; w && *w; w++) o.push_back((char)(*w & 0x7F));
    return o;
}

// compiled, never entered: nothing here raises a structured exception
static inline DWORD GetExceptionCode() { return 0; }
#undef __try
#undef __except
#define __try            if (true)
#define __except(filter) else if (!(filter))

// MSVC's overload for arrays, which applyColorManagement() writes into
#define sprintf_s(buf, ...) snprintf(buf, sizeof(buf), __VA_ARGS__)

static inline HRESULT UIntMult(UINT a, UINT b, UINT *out) {
    const UINT64 r = (UINT64)a*b;
    if (r>0xFFFFFFFFull)
    {
       *out = 0;
       return (HRESULT)0x80070216;
    }
    *out = (UINT)r;
    return S_OK;
}

// ---- GUIDs ------------------------------------------------------------------------------------

struct GUID { unsigned int Data1; unsigned short Data2, Data3; unsigned char Data4[8]; };
static inline bool operator==(const GUID &a, const GUID &b) { return memcmp(&a, &b, sizeof(GUID))==0; }
static inline bool operator!=(const GUID &a, const GUID &b) { return !(a==b); }
typedef GUID IID, CLSID, WICPixelFormatGUID;
typedef const GUID &REFIID, &REFCLSID, &REFGUID, &REFWICPixelFormatGUID;

// distinct values, not the SDK's: only identity matters here
#define SHIM_GUID(name, n) static const GUID name = { 0x6fddc324u, 0x4e03, 0x4bfe, {0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, (unsigned char)(n)} };
SHIM_GUID(GUID_WICPixelFormat8bppIndexed, 0x04)
SHIM_GUID(GUID_WICPixelFormat8bppGray, 0x08)
SHIM_GUID(GUID_WICPixelFormat16bppBGR555, 0x09)
SHIM_GUID(GUID_WICPixelFormat16bppBGR565, 0x0a)
SHIM_GUID(GUID_WICPixelFormat16bppGray, 0x0b)
SHIM_GUID(GUID_WICPixelFormat24bppBGR, 0x0c)
SHIM_GUID(GUID_WICPixelFormat24bppRGB, 0x0d)
SHIM_GUID(GUID_WICPixelFormat32bppBGR, 0x0e)
SHIM_GUID(GUID_WICPixelFormat32bppBGRA, 0x0f)
SHIM_GUID(GUID_WICPixelFormat32bppPBGRA, 0x10)
SHIM_GUID(GUID_WICPixelFormat32bppBGR101010, 0x14)
SHIM_GUID(GUID_WICPixelFormat48bppRGB, 0x15)
SHIM_GUID(GUID_WICPixelFormat64bppRGBA, 0x16)
SHIM_GUID(GUID_WICPixelFormat64bppPRGBA, 0x17)
SHIM_GUID(GUID_WICPixelFormat32bppCMYK, 0x1c)
SHIM_GUID(GUID_WICPixelFormat32bppRGBA, 0x2d)
SHIM_GUID(GUID_WICPixelFormat32bppPRGBA, 0x2e)
SHIM_GUID(GUID_WICPixelFormat48bppBGR, 0x31)
SHIM_GUID(GUID_WICPixelFormat64bppBGRA, 0x32)
SHIM_GUID(GUID_WICPixelFormat64bppPBGRA, 0x33)
SHIM_GUID(GUID_WICPixelFormat64bppCMYK, 0x1f)
SHIM_GUID(GUID_WICPixelFormat40bppCMYKAlpha, 0x2c)
SHIM_GUID(GUID_WICPixelFormat80bppCMYKAlpha, 0x2f)
SHIM_GUID(GUID_WICPixelFormat96bppRGBFloat, 0x27)
SHIM_GUID(GUID_ContainerFormatJpeg, 0xf0)
SHIM_GUID(IID_IWICBitmapSource, 0xfe)
SHIM_GUID(shimIID, 0xff)
#define IID_PPV_ARGS(pp) shimIID, reinterpret_cast<void**>(pp)

// ---- the WIC interfaces, with the SDK's method signatures -------------------------------------

enum WICDecodeOptions { WICDecodeMetadataCacheOnDemand = 0, WICDecodeMetadataCacheOnLoad = 1 };
enum WICBitmapInterpolationMode { WICBitmapInterpolationModeNearestNeighbor = 0, WICBitmapInterpolationModeLinear = 1,
                                  WICBitmapInterpolationModeCubic = 2, WICBitmapInterpolationModeFant = 3,
                                  WICBitmapInterpolationModeHighQualityCubic = 4 };
enum WICBitmapDitherType { WICBitmapDitherTypeNone = 0 };
enum WICBitmapPaletteType { WICBitmapPaletteTypeCustom = 0 };
enum WICColorContextType { WICColorContextUninitialized = 0, WICColorContextProfile = 1, WICColorContextExifColorSpace = 2 };
struct WICRect { INT X, Y, Width, Height; };
struct IWICPalette;
struct IWICColorContext;

struct IUnknown {
    virtual HRESULT QueryInterface(REFIID riid, void **ppv) = 0;
    virtual ULONG AddRef() = 0;
    virtual ULONG Release() = 0;
};
struct IWICBitmapSource : IUnknown {
    virtual HRESULT GetSize(UINT *puiWidth, UINT *puiHeight) = 0;
    virtual HRESULT GetPixelFormat(WICPixelFormatGUID *pPixelFormat) = 0;
    virtual HRESULT GetResolution(double *pDpiX, double *pDpiY) = 0;
    virtual HRESULT CopyPalette(IWICPalette *pIPalette) = 0;
    virtual HRESULT CopyPixels(const WICRect *prc, UINT cbStride, UINT cbBufferSize, BYTE *pbBuffer) = 0;
};
struct IWICBitmapFrameDecode : IWICBitmapSource {
    virtual HRESULT GetColorContexts(UINT cCount, IWICColorContext **ppIColorContexts, UINT *pcActualCount) = 0;
};
struct IWICBitmapDecoder : IUnknown {
    virtual HRESULT GetContainerFormat(GUID *pguidContainerFormat) = 0;
    virtual HRESULT GetFrameCount(UINT *pCount) = 0;
    virtual HRESULT GetFrame(UINT index, IWICBitmapFrameDecode **ppIBitmapFrame) = 0;
};
struct IWICColorContext : IUnknown {
    virtual HRESULT InitializeFromExifColorSpace(UINT value) = 0;
    virtual HRESULT GetType(WICColorContextType *pType) = 0;
    virtual HRESULT GetExifColorSpace(UINT *pValue) = 0;
};
struct IWICColorTransform : IWICBitmapSource {
    virtual HRESULT Initialize(IWICBitmapSource *pIBitmapSource, IWICColorContext *pIContextSource,
                               IWICColorContext *pIContextDest, REFWICPixelFormatGUID pixelFmtDest) = 0;
};
struct IWICBitmapScaler : IWICBitmapSource {
    virtual HRESULT Initialize(IWICBitmapSource *pISource, UINT uiWidth, UINT uiHeight, WICBitmapInterpolationMode mode) = 0;
};
struct IWICFormatConverter : IWICBitmapSource {
    virtual HRESULT Initialize(IWICBitmapSource *pISource, REFWICPixelFormatGUID dstFormat, WICBitmapDitherType dither,
                               IWICPalette *pIPalette, double alphaThresholdPercent, WICBitmapPaletteType paletteTranslate) = 0;
    virtual HRESULT CanConvert(REFWICPixelFormatGUID srcPixelFormat, REFWICPixelFormatGUID dstPixelFormat, BOOL *pfCanConvert) = 0;
};
struct IWICBitmapClipper : IWICBitmapSource {
    virtual HRESULT Initialize(IWICBitmapSource *pISource, const WICRect *prc) = 0;
};
struct IWICComponentInfo : IUnknown {};
struct IWICPixelFormatInfo : IWICComponentInfo {
    virtual HRESULT GetBitsPerPixel(UINT *puiBitsPerPixel) = 0;
    virtual HRESULT GetChannelCount(UINT *puiChannelCount) = 0;
};
struct IWICImagingFactory : IUnknown {
    virtual HRESULT CreateDecoderFromFilename(LPCWSTR wzFilename, const GUID *pguidVendor, DWORD dwDesiredAccess,
                                              WICDecodeOptions metadataOptions, IWICBitmapDecoder **ppIDecoder) = 0;
    virtual HRESULT CreateComponentInfo(REFCLSID clsidComponent, IWICComponentInfo **ppIInfo) = 0;
    virtual HRESULT CreateFormatConverter(IWICFormatConverter **ppIFormatConverter) = 0;
    virtual HRESULT CreateBitmapScaler(IWICBitmapScaler **ppIBitmapScaler) = 0;
    virtual HRESULT CreateBitmapClipper(IWICBitmapClipper **ppIBitmapClipper) = 0;
    virtual HRESULT CreateColorContext(IWICColorContext **ppIWICColorContext) = 0;
    virtual HRESULT CreateColorTransformer(IWICColorTransform **ppIWICColorTransform) = 0;
};

// ---- what the test scripts, and what it reads back ----------------------------------------------

struct ShimScenario {
    WICPixelFormatGUID pixelFmt = GUID_WICPixelFormat24bppBGR;
    UINT w = 1000, h = 800;
    UINT contexts = 0;                     // what GetColorContexts() says the frame carries
    HRESULT contextsHr = S_OK;
    WICColorContextType contextType = WICColorContextProfile;
    UINT exifSpace = 0;
    int createContextFails = 0;
    int createTransformFails = 0;
    int transformInitFails = 0;
    int scalerRejectsTransform = 0;
    int transformCopyFails = 0;
};
static ShimScenario gScn;

static int gLiveCom = 0, gOverRelease = 0, gDecoders = 0, gContextsMade = 0, gTransformsMade = 0;
static int gTransformInits = 0, gTransformReadsFrame = 0, gTransformDestExif = -1, gTransformSrcType = -1;
static int gScalerReadsTransform = -1, gConverterReadsTransform = -1;
static GUID gTransformDestFmt = {0, 0, 0, {0}};

static inline void shimResetCounters() {
    gLiveCom = gOverRelease = gDecoders = gContextsMade = gTransformsMade = 0;
    gTransformInits = gTransformReadsFrame = 0;
    gTransformDestExif = gTransformSrcType = gScalerReadsTransform = gConverterReadsTransform = -1;
    memset(&gTransformDestFmt, 0, sizeof(GUID));
}

// applyColorManagement() asks the transform for its IWICBitmapSource, the one interface answered
#define SHIM_IUNKNOWN(cls) \
    LONG refs = 1; \
    cls() { gLiveCom++; } \
    HRESULT QueryInterface(REFIID riid, void **ppv) override { \
        IWICBitmapSource *src = (riid==IID_IWICBitmapSource) ? dynamic_cast<IWICBitmapSource*>(this) : NULL; \
        if (ppv) *ppv = NULL; \
        if (src==NULL || ppv==NULL) return E_NOINTERFACE; \
        AddRef(); \
        *ppv = src; \
        return S_OK; \
    } \
    ULONG AddRef() override { return (ULONG)++refs; } \
    ULONG Release() override { \
        if (refs<=0) { gOverRelease++; return 0; } \
        const LONG r = --refs; \
        if (r==0) { gLiveCom--; delete this; } \
        return (ULONG)r; \
    }

static void shimFill(BYTE *buf, UINT stride, UINT w, UINT h, BYTE grey) {
    for (UINT y = 0; y < h; y++)
        for (UINT x = 0; x < w; x++)
        {
            BYTE *p = buf + (size_t)y*stride + (size_t)x*4;
            p[0] = p[1] = p[2] = grey;
            p[3] = 255;
        }
}

struct FakeContext final : IWICColorContext {
    SHIM_IUNKNOWN(FakeContext)
    WICColorContextType type = WICColorContextUninitialized;
    UINT exif = 0;
    HRESULT InitializeFromExifColorSpace(UINT value) override {
        if (value!=1 && value!=2)
           return E_INVALIDARG;   // sRGB and Adobe RGB are the only EXIF colour spaces
        type = WICColorContextExifColorSpace;
        exif = value;
        return S_OK;
    }
    HRESULT GetType(WICColorContextType *t) override { *t = type; return S_OK; }
    HRESULT GetExifColorSpace(UINT *v) override {
        if (type!=WICColorContextExifColorSpace)
           return E_FAIL;
        *v = exif;
        return S_OK;
    }
};

struct FakeFrame final : IWICBitmapFrameDecode {
    SHIM_IUNKNOWN(FakeFrame)
    HRESULT GetSize(UINT *w, UINT *h) override { *w = gScn.w; *h = gScn.h; return S_OK; }
    HRESULT GetPixelFormat(WICPixelFormatGUID *f) override { *f = gScn.pixelFmt; return S_OK; }
    HRESULT GetResolution(double *x, double *y) override { *x = *y = 72.0; return S_OK; }
    HRESULT CopyPalette(IWICPalette*) override { return E_NOTIMPL; }
    HRESULT CopyPixels(const WICRect *rc, UINT stride, UINT size, BYTE *buf) override {
        const UINT w = rc ? (UINT)rc->Width : gScn.w, h = rc ? (UINT)rc->Height : gScn.h;
        if ((UINT64)stride*h>size || stride<w*4)
           return E_INVALIDARG;
        shimFill(buf, stride, w, h, 100);
        return S_OK;
    }
    HRESULT GetColorContexts(UINT cCount, IWICColorContext **ctx, UINT *actual) override {
        *actual = gScn.contexts;
        if (FAILED(gScn.contextsHr))
           return gScn.contextsHr;

        if (cCount>0 && gScn.contexts>0 && ctx!=NULL && ctx[0]!=NULL)
        {
           FakeContext *c = static_cast<FakeContext*>(ctx[0]);
           c->type = gScn.contextType;
           c->exif = gScn.exifSpace;
        }
        return S_OK;
    }
};

struct FakeDecoder final : IWICBitmapDecoder {
    SHIM_IUNKNOWN(FakeDecoder)
    HRESULT GetContainerFormat(GUID *g) override { *g = GUID_ContainerFormatJpeg; return S_OK; }
    HRESULT GetFrameCount(UINT *n) override { *n = 1; return S_OK; }
    HRESULT GetFrame(UINT, IWICBitmapFrameDecode **pp) override { *pp = new FakeFrame(); return S_OK; }
};

struct FakeTransform final : IWICColorTransform {
    SHIM_IUNKNOWN(FakeTransform)
    IWICBitmapSource *src = NULL;
    IWICColorContext *from = NULL, *to = NULL;
    WICPixelFormatGUID fmt;
    ~FakeTransform() {
        if (src) src->Release();
        if (from) from->Release();
        if (to) to->Release();
    }
    HRESULT Initialize(IWICBitmapSource *s, IWICColorContext *a, IWICColorContext *b, REFWICPixelFormatGUID f) override {
        gTransformInits++;
        FakeContext *ca = static_cast<FakeContext*>(a);
        gTransformSrcType = ca ? (int)ca->type : -1;
        if (gScn.transformInitFails || s==NULL || ca==NULL || b==NULL || ca->type==WICColorContextUninitialized)
           return E_INVALIDARG;

        gTransformReadsFrame = (dynamic_cast<FakeFrame*>(s)!=NULL) ? 1 : 0;
        gTransformDestExif = (int)static_cast<FakeContext*>(b)->exif;
        gTransformDestFmt = f;
        src = s;   src->AddRef();
        from = a;  from->AddRef();
        to = b;    to->AddRef();
        fmt = f;
        return S_OK;
    }
    HRESULT GetSize(UINT *w, UINT *h) override { return src ? src->GetSize(w, h) : E_FAIL; }
    HRESULT GetPixelFormat(WICPixelFormatGUID *f) override { *f = fmt; return S_OK; }
    HRESULT GetResolution(double *x, double *y) override { return src ? src->GetResolution(x, y) : E_FAIL; }
    HRESULT CopyPalette(IWICPalette*) override { return E_NOTIMPL; }
    HRESULT CopyPixels(const WICRect *rc, UINT stride, UINT size, BYTE *buf) override {
        if (gScn.transformCopyFails || src==NULL)
           return E_FAIL;
        HRESULT hr = src->CopyPixels(rc, stride, size, buf);
        if (FAILED(hr))
           return hr;
        UINT w = 0, h = 0;
        src->GetSize(&w, &h);
        if (rc) { w = (UINT)rc->Width; h = (UINT)rc->Height; }
        for (UINT y = 0; y < h; y++)
            for (UINT x = 0; x < w; x++)
            {
                BYTE *p = buf + (size_t)y*stride + (size_t)x*4;
                p[0] += 50;  p[1] += 50;  p[2] += 50;
            }
        return S_OK;
    }
};

struct FakeScaler final : IWICBitmapScaler {
    SHIM_IUNKNOWN(FakeScaler)
    IWICBitmapSource *src = NULL;
    UINT w = 0, h = 0;
    ~FakeScaler() { if (src) src->Release(); }
    HRESULT Initialize(IWICBitmapSource *s, UINT nw, UINT nh, WICBitmapInterpolationMode) override {
        const bool isTransform = (dynamic_cast<FakeTransform*>(s)!=NULL);
        if (s==NULL || src!=NULL || (gScn.scalerRejectsTransform && isTransform))
           return E_FAIL;
        gScalerReadsTransform = isTransform ? 1 : 0;
        src = s;  src->AddRef();
        w = nw;   h = nh;
        return S_OK;
    }
    HRESULT GetSize(UINT *pw, UINT *ph) override { *pw = w; *ph = h; return S_OK; }
    HRESULT GetPixelFormat(WICPixelFormatGUID *f) override { return src ? src->GetPixelFormat(f) : E_FAIL; }
    HRESULT GetResolution(double *x, double *y) override { return src ? src->GetResolution(x, y) : E_FAIL; }
    HRESULT CopyPalette(IWICPalette*) override { return E_NOTIMPL; }
    HRESULT CopyPixels(const WICRect*, UINT stride, UINT size, BYTE *buf) override {
        UINT sw = 0, sh = 0;
        if (src==NULL || FAILED(src->GetSize(&sw, &sh)) || (UINT64)stride*h>size)
           return E_FAIL;
        std::vector<BYTE> whole((size_t)sw*sh*4);
        HRESULT hr = src->CopyPixels(NULL, sw*4, (UINT)whole.size(), whole.data());
        if (FAILED(hr))
           return hr;
        for (UINT y = 0; y < h; y++)
            for (UINT x = 0; x < w; x++)
                memcpy(buf + (size_t)y*stride + (size_t)x*4, &whole[((size_t)(y*sh/h)*sw + x*sw/w)*4], 4);
        return S_OK;
    }
};

struct FakeConverter final : IWICFormatConverter {
    SHIM_IUNKNOWN(FakeConverter)
    IWICBitmapSource *src = NULL;
    WICPixelFormatGUID fmt;
    ~FakeConverter() { if (src) src->Release(); }
    HRESULT Initialize(IWICBitmapSource *s, REFWICPixelFormatGUID f, WICBitmapDitherType, IWICPalette*, double,
                       WICBitmapPaletteType) override {
        if (s==NULL || src!=NULL)
           return E_FAIL;
        gConverterReadsTransform = (dynamic_cast<FakeTransform*>(s)!=NULL) ? 1 : 0;
        src = s;  src->AddRef();
        fmt = f;
        return S_OK;
    }
    HRESULT CanConvert(REFWICPixelFormatGUID, REFWICPixelFormatGUID, BOOL *ok) override { *ok = 1; return S_OK; }
    HRESULT GetSize(UINT *w, UINT *h) override { return src ? src->GetSize(w, h) : E_FAIL; }
    HRESULT GetPixelFormat(WICPixelFormatGUID *f) override { *f = fmt; return S_OK; }
    HRESULT GetResolution(double *x, double *y) override { return src ? src->GetResolution(x, y) : E_FAIL; }
    HRESULT CopyPalette(IWICPalette*) override { return E_NOTIMPL; }
    HRESULT CopyPixels(const WICRect *rc, UINT stride, UINT size, BYTE *buf) override {
        return src ? src->CopyPixels(rc, stride, size, buf) : E_FAIL;
    }
};

struct FakeFactory final : IWICImagingFactory {
    HRESULT QueryInterface(REFIID, void **ppv) override { if (ppv) *ppv = NULL; return E_NOINTERFACE; }
    ULONG AddRef() override { return 1; }
    ULONG Release() override { return 1; }
    HRESULT CreateDecoderFromFilename(LPCWSTR, const GUID*, DWORD, WICDecodeOptions, IWICBitmapDecoder **pp) override {
        gDecoders++;
        *pp = new FakeDecoder();
        return S_OK;
    }
    HRESULT CreateComponentInfo(REFCLSID, IWICComponentInfo **pp) override { *pp = NULL; return E_NOTIMPL; }
    HRESULT CreateFormatConverter(IWICFormatConverter **pp) override { *pp = new FakeConverter(); return S_OK; }
    HRESULT CreateBitmapScaler(IWICBitmapScaler **pp) override { *pp = new FakeScaler(); return S_OK; }
    HRESULT CreateBitmapClipper(IWICBitmapClipper **pp) override { *pp = NULL; return E_NOTIMPL; }
    HRESULT CreateColorContext(IWICColorContext **pp) override {
        *pp = NULL;
        if (gScn.createContextFails)
           return E_FAIL;
        gContextsMade++;
        *pp = new FakeContext();
        return S_OK;
    }
    HRESULT CreateColorTransformer(IWICColorTransform **pp) override {
        *pp = NULL;
        if (gScn.createTransformFails)
           return E_FAIL;
        gTransformsMade++;
        *pp = new FakeTransform();
        return S_OK;
    }
};

// ---- the GDI+ calls tpWICload() makes ---------------------------------------------------------

typedef int PixelFormat;
#define PixelFormat32bppPARGB  0x000E200B

static int gShimLiveBitmaps = 0;

namespace Gdiplus {
    enum Status { Ok = 0, GenericError = 1 };
    enum ImageLockMode { ImageLockModeRead = 1, ImageLockModeWrite = 2 };
    typedef DWORD ARGB;
    struct Rect {
        INT X, Y, Width, Height;
        Rect(INT x, INT y, INT w, INT h) : X(x), Y(y), Width(w), Height(h) {}
    };
    struct BitmapData {
        UINT Width, Height;
        INT Stride;
        ::PixelFormat PixelFormat;
        void *Scan0;
        UINT_PTR Reserved;
    };
    struct GpBitmap {
        int w = 0, h = 0;
        std::vector<BYTE> px;
    };

    namespace DllExports {
        static inline Status GdipCreateBitmapFromScan0(INT w, INT h, INT, ::PixelFormat, BYTE*, GpBitmap **out) {
            *out = NULL;
            if (w<1 || h<1)
               return GenericError;
            GpBitmap *b = new GpBitmap();
            b->w = w;
            b->h = h;
            b->px.assign((size_t)w*h*4, 0);
            gShimLiveBitmaps++;
            *out = b;
            return Ok;
        }
        static inline Status GdipBitmapLockBits(GpBitmap *b, const Rect*, UINT, ::PixelFormat fmt, BitmapData *d) {
            if (!b || !d)
               return GenericError;
            d->Width = (UINT)b->w;
            d->Height = (UINT)b->h;
            d->Stride = b->w*4;
            d->PixelFormat = fmt;
            d->Scan0 = b->px.data();
            d->Reserved = 0;
            return Ok;
        }
        static inline Status GdipBitmapUnlockBits(GpBitmap *b, BitmapData*) { return b ? Ok : GenericError; }
        static inline Status GdipDisposeImage(GpBitmap *b) {
            if (!b)
               return GenericError;
            delete b;
            gShimLiveBitmaps--;
            return Ok;
        }
    }
}

// ---- what tpWICload() borrows from qpv-main.cpp besides the guards ------------------------------

static inline INT indexedWICpixelFormats(const WICPixelFormatGUID) { return 1; }
static inline UINT indexedWICcontainerFormats(const GUID) { return 1; }
static inline int decideWICtoFIMpixelFormat(GUID) { return 32; }
static inline bool IsFileExtension(const wchar_t*, const wchar_t*) { return false; }

#endif // QPV_TEST_WIC_ENV_H
