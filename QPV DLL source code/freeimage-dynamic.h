// freeimage-dynamic.h
//
// Minimal run-time binding to FreeImage.dll for the thumbnails worker pool.
// qpvmain.dll does not link FreeImage; the AHK side already LoadLibraryW()s it
// (FreeImage_FoxInit() in lib\freeimage-wrapper.ahk), so GetModuleHandleW() normally
// finds the very same module. If it is absent, LoadLibraryW() is tried once and, failing
// that, FIM.ok stays false and the pool simply behaves as if wasInitFIMlib=0
//
// Only the entry points MonoGenerateThumb() used are bound. Signatures match the DllCall
// argument sizes encoded in getFIMfunc()'s fList tables.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_FREEIMAGE_DYNAMIC_H
#define QPV_FREEIMAGE_DYNAMIC_H

#include <windows.h>
#include <mutex>

// ---- FreeImage public constants (subset) --------------------------------------------

typedef void* FIBITMAPptr;   // opaque FIBITMAP*

// FREE_IMAGE_FORMAT
#define FIF_UNKNOWN  (-1)
#define FIF_BMP        0
#define FIF_JPEG       2
#define FIF_PNG       13
#define FIF_TIFF      18
#define FIF_PSD       20
#define FIF_GIF       25
#define FIF_HDR       26
#define FIF_EXR       29
#define FIF_PFM       32
#define FIF_RAW       34

// FREE_IMAGE_TYPE
#define FIT_UNKNOWN    0
#define FIT_BITMAP     1
#define FIT_UINT16     2
#define FIT_INT16      3
#define FIT_UINT32     4
#define FIT_INT32      5
#define FIT_FLOAT      6
#define FIT_DOUBLE     7
#define FIT_COMPLEX    8
#define FIT_RGB16      9
#define FIT_RGBA16    10
#define FIT_RGBF      11
#define FIT_RGBAF     12

// FREE_IMAGE_COLOR_TYPE
#define FIC_MINISWHITE 0
#define FIC_MINISBLACK 1
#define FIC_RGB        2
#define FIC_PALETTE    3
#define FIC_RGBALPHA   4
#define FIC_CMYK       5

// FREE_IMAGE_FILTER
#define FILTER_BOX        0
#define FILTER_BICUBIC    1
#define FILTER_BILINEAR   2
#define FILTER_BSPLINE    3
#define FILTER_CATMULLROM 4
#define FILTER_LANCZOS3   5

// load flags used by MonoGenerateThumb()
#define JPEG_EXIFROTATE   0x0008
#define RAW_DEFAULT       0
#define RAW_PREVIEW       1
#define RAW_DISPLAY       2

// ---- entry points --------------------------------------------------------------------

struct FreeImageAPI {
    bool ok = false;
    HMODULE hLib = NULL;

    int         (__stdcall *GetFileTypeU)(const wchar_t*, int) = NULL;
    int         (__stdcall *GetFIFFromFilenameU)(const wchar_t*) = NULL;
    FIBITMAPptr (__stdcall *LoadU)(int, const wchar_t*, int) = NULL;
    BOOL        (__stdcall *SaveU)(int, FIBITMAPptr, const wchar_t*, int) = NULL;
    void        (__stdcall *Unload)(FIBITMAPptr) = NULL;
    FIBITMAPptr (__stdcall *Clone)(FIBITMAPptr) = NULL;

    unsigned    (__stdcall *GetWidth)(FIBITMAPptr) = NULL;
    unsigned    (__stdcall *GetHeight)(FIBITMAPptr) = NULL;
    unsigned    (__stdcall *GetBPP)(FIBITMAPptr) = NULL;
    unsigned    (__stdcall *GetPitch)(FIBITMAPptr) = NULL;
    BYTE*       (__stdcall *GetBits)(FIBITMAPptr) = NULL;
    BITMAPINFO* (__stdcall *GetInfo)(FIBITMAPptr) = NULL;
    int         (__stdcall *GetImageType)(FIBITMAPptr) = NULL;
    int         (__stdcall *GetColorType)(FIBITMAPptr) = NULL;

    FIBITMAPptr (__stdcall *AllocateT)(int, int, int, int, unsigned, unsigned, unsigned) = NULL;
    FIBITMAPptr (__stdcall *Rescale)(FIBITMAPptr, int, int, int) = NULL;
    FIBITMAPptr (__stdcall *ConvertToGreyscale)(FIBITMAPptr) = NULL;
    FIBITMAPptr (__stdcall *ConvertTo24Bits)(FIBITMAPptr) = NULL;
    FIBITMAPptr (__stdcall *ConvertTo32Bits)(FIBITMAPptr) = NULL;
    FIBITMAPptr (__stdcall *ConvertToRGBF)(FIBITMAPptr) = NULL;
    FIBITMAPptr (__stdcall *ToneMapping)(FIBITMAPptr, int, double, double) = NULL;
    BOOL        (__stdcall *FlipVertical)(FIBITMAPptr) = NULL;
};

static FreeImageAPI FIM;
static std::once_flag FIMbindOnce;

// On x86 FreeImage exports are stdcall-decorated (_FreeImage_Xxx@N); the thumbnails pool is
// x64-only (QPV_ShowThumbnails() forces mustDoMultiCore=0 when A_PtrSize=4), so the plain
// name is tried first and the decorated one only as a courtesy fallback.
static FARPROC FIMresolve(HMODULE h, const char* name, int argBytes) {
    FARPROC p = GetProcAddress(h, name);
    if (p==NULL)
    {
       char decorated[128];
       sprintf_s(decorated, sizeof(decorated), "_%s@%d", name, argBytes);
       p = GetProcAddress(h, decorated);
    }
    return p;
}

static void bindFreeImageOnce() {
    std::call_once(FIMbindOnce, []() {
        FIM.hLib = GetModuleHandleW(L"FreeImage.dll");
        if (FIM.hLib==NULL)
           FIM.hLib = LoadLibraryW(L"FreeImage.dll");

        if (FIM.hLib==NULL)
        {
           fnOutputDebug("thumbsPool: FreeImage.dll not present; FreeImage-only formats disabled");
           return;
        }

        #define BINDFIM(field, argBytes) \
            *(FARPROC*)&FIM.field = FIMresolve(FIM.hLib, "FreeImage_" #field, argBytes)

        BINDFIM(GetFileTypeU, 8);
        BINDFIM(GetFIFFromFilenameU, 4);
        BINDFIM(LoadU, 12);
        BINDFIM(SaveU, 16);
        BINDFIM(Unload, 4);
        BINDFIM(Clone, 4);
        BINDFIM(GetWidth, 4);
        BINDFIM(GetHeight, 4);
        BINDFIM(GetBPP, 4);
        BINDFIM(GetPitch, 4);
        BINDFIM(GetBits, 4);
        BINDFIM(GetInfo, 4);
        BINDFIM(GetImageType, 4);
        BINDFIM(GetColorType, 4);
        BINDFIM(AllocateT, 28);
        BINDFIM(Rescale, 16);
        BINDFIM(ConvertToGreyscale, 4);
        BINDFIM(ConvertTo24Bits, 4);
        BINDFIM(ConvertTo32Bits, 4);
        BINDFIM(ConvertToRGBF, 4);
        BINDFIM(ToneMapping, 24);
        BINDFIM(FlipVertical, 4);
        #undef BINDFIM

        FIM.ok = (FIM.GetFileTypeU && FIM.LoadU && FIM.Unload && FIM.GetWidth && FIM.GetHeight
               && FIM.GetBPP && FIM.GetPitch && FIM.GetBits && FIM.GetInfo && FIM.GetImageType
               && FIM.GetColorType && FIM.Rescale && FIM.ConvertTo24Bits && FIM.FlipVertical);

        if (FIM.ok)
           fnOutputDebug("thumbsPool: FreeImage.dll bound successfully");
        else
           fnOutputDebug("thumbsPool: FreeImage.dll found but required entry points are missing");
    });
}

#endif // QPV_FREEIMAGE_DYNAMIC_H
