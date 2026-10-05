// The <windows.h> freeimage-dynamic.h is compiled against in fim_thumb.cpp, on its own include
// path because shim/windows.h is sqlite's. "FreeImage.dll" is the Linux build of QPV's
// FreeImage fork, named by QPV_FREEIMAGE_SO, so bindFreeImageOnce() binds the real library
// through dlopen() and dlsym() exactly as it binds the DLL on Windows.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_FIM_WINDOWS_H
#define QPV_TEST_FIM_WINDOWS_H

#include <dlfcn.h>
#include <cstdio>
#include <cstdlib>
#include <cstdint>

typedef int            BOOL;
typedef int            INT;
typedef unsigned int   UINT;
typedef uint32_t       DWORD;
typedef int32_t        LONG;
typedef int64_t        INT64;
typedef uint16_t       WORD;
typedef unsigned char  BYTE;
typedef void*          HMODULE;
typedef void*          FARPROC;

#define __stdcall
#define sprintf_s snprintf

// FreeImage_GetInfo() hands back FreeImage's own layout, which is this one
struct BITMAPINFOHEADER {
    DWORD biSize;
    LONG  biWidth;
    LONG  biHeight;
    WORD  biPlanes;
    WORD  biBitCount;
    DWORD biCompression;
    DWORD biSizeImage;
    LONG  biXPelsPerMeter;
    LONG  biYPelsPerMeter;
    DWORD biClrUsed;
    DWORD biClrImportant;
};
struct RGBQUAD { BYTE rgbBlue, rgbGreen, rgbRed, rgbReserved; };
struct BITMAPINFO { BITMAPINFOHEADER bmiHeader; RGBQUAD bmiColors[1]; };

// nothing is loaded before the binding runs, so it always reaches LoadLibraryW()
static inline HMODULE GetModuleHandleW(const wchar_t*) { return NULL; }
static inline HMODULE LoadLibraryW(const wchar_t*) {
    const char *so = getenv("QPV_FREEIMAGE_SO");
    return (so && so[0]) ? dlopen(so, RTLD_NOW) : NULL;
}
static inline FARPROC GetProcAddress(HMODULE h, const char *name) {
    return h ? dlsym(h, name) : NULL;
}

#endif // QPV_TEST_FIM_WINDOWS_H
