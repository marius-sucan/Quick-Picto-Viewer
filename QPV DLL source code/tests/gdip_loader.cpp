// The GDI+ loader of thumbs-pool.h - the third loader of the product, and for some files
// the only one.
//
// EMF and WMF have neither a FreeImage plugin nor a WIC codec, and a GIF that FreeImage
// refuses and WIC either has no codec for or cannot decode is still drawn in the viewport,
// by LoadFileWithGDIp(). Until this loader existed, both worker pools ran out of loaders on
// those files: the thumbnails pool drew nothing and the collection pool of dupes-pixels.h
// marked them isDeleted=1, which hides an image from the whole library until the caches
// overview revalidates it.
//
// thumbs-pool.h cannot be compiled on this box - WIC, Direct2D, OpenMP - so the loader is
// TEXT-SLICED out of the shipped header by run-tests.sh and compiled against shim/gdip-env.h.
// That alone is worth the file: nothing else here ever sees a compiler before MSVC does.
// What is checked beyond that is the behaviour the shipped product depends on and a reader
// cannot see by looking at one function:
//
//   - the bitmap handed back is a COPY, and the file-backed original is disposed. GDI+ keeps
//     the file mapped for as long as that bitmap lives - GDIbmpFileConnected tracks exactly
//     that in the AHK - so a worker that returns it leaves a lock on a file the user may be
//     about to move or delete. The copy is also what turns the 8bpp indexed bitmap a GIF
//     decodes into into the 32bpp one the effects and the histogram downstream need.
//   - the frame is selected BEFORE the size is read: the frames of an animated GIF need not
//     all be the size of the first.
//   - the resize asks GDI+ for the modes Gdip_ResizeBitmap() asks for.
//
// written by Marius Șucan with Claude Opus 5

#include "shim/gdip-env.h"

// sliced out of ../thumbs-pool.h by run-tests.sh
#include "calc_dims.part"
#include "gdip_loader.part"

static int failures = 0;
static void check(bool cond, const char *what) {
    printf("    %-62s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

int main() {
    printf("thumbs-pool.h GDI+ loader\n");

    // ---- the copy, and the lock it releases ---------------------------------------------
    printf("  what comes back, and what is let go of\n");
    {
        gShimReset();
        gShimFileW = 400;
        gShimFileH = 300;
        gShimFileDpi = 72.0f;
        int srcW = 0, srcH = 0;
        TpSrcMeta meta;
        Gdiplus::GpBitmap *out = tpGDIPload(L"C:\\p\\drawing.emf", 250, 250, 0, 6, srcW, srcH, &meta);

        check(out!=NULL, "a file GDI+ can read is loaded");
        check(gShimCreatedFromFile==1, "the file was opened once");
        check(out!=NULL && !out->fromFile, "and what comes back is not the bitmap holding it open");
        check(gShimLiveCount()==1 && gShimIsAlive(out),
              "the file-backed original is disposed - the lock on the file goes with it");
        check(gShimLastCreateFormat==PixelFormat32bppARGB,
              "the copy is 32bpp, which is what the effects and the histogram need");

        // 400x300 into a 250 box: the width leads, and the height follows the ratio
        check(out!=NULL && out->w==250 && out->h==188, "it is sized by tpCalcIMGdimensions()");
        check(srcW==400 && srcH==300, "and the ORIGINAL dimensions come back separately");
        check(meta.dpi==72, "the resolution is recorded");
        check(meta.frames==1, "and so is the frame count");

        Gdiplus::DllExports::GdipDisposeImage(out);
        check(gShimLiveCount()==0, "nothing else was left behind");
    }

    // ---- an image smaller than the box is enlarged into it, like every other loader ------
    {
        gShimReset();
        gShimFileW = 40;
        gShimFileH = 30;
        int srcW = 0, srcH = 0;
        Gdiplus::GpBitmap *out = tpGDIPload(L"C:\\p\\tiny.gif", 250, 250, 0, 6, srcW, srcH, NULL);
        check(out!=NULL && out->w==250 && out->h==188,
              "a small image is enlarged into the box, as the FreeImage branch does");
        check(srcW==40 && srcH==30, "while the recorded size stays the file's own");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);
    }

    // ---- the native size, for a caller that asks for no box -----------------------------
    {
        gShimReset();
        gShimFileW = 123;
        gShimFileH = 45;
        int srcW = 0, srcH = 0;
        Gdiplus::GpBitmap *out = tpGDIPload(L"C:\\p\\native.wmf", 0, 0, 0, 6, srcW, srcH, NULL);
        check(out!=NULL && out->w==123 && out->h==45, "a box of zero means the image's own size");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);
    }

    // ---- frames ---------------------------------------------------------------------
    printf("  frames\n");
    {
        gShimReset();
        gShimFileFrames = 12;
        int srcW = 0, srcH = 0;
        TpSrcMeta meta;
        Gdiplus::GpBitmap *out = tpGDIPload(L"C:\\p\\anim.gif", 250, 250, 0, 6, srcW, srcH, &meta);
        check(meta.frames==12, "an animated GIF reports every frame it has");
        check(gShimSelectedFrame==-1, "frame 0 is what the decoder already sits on - nothing is selected");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        gShimReset();
        gShimFileFrames = 12;
        out = tpGDIPload(L"C:\\p\\anim.gif", 250, 250, 5, 6, srcW, srcH, &meta);
        check(gShimSelectedFrame==5, "a later frame is selected before anything is measured");
        check(meta.frames==12, "and the count is still the whole animation's");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        gShimReset();
        gShimFileFrames = 3;
        out = tpGDIPload(L"C:\\p\\anim.gif", 250, 250, 99, 6, srcW, srcH, &meta);
        check(gShimSelectedFrame==2, "a frame past the end is clamped to the last one");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        // an image with no frame dimension at all is still an image
        gShimReset();
        gShimDimensionsFail = 1;
        meta = TpSrcMeta();
        out = tpGDIPload(L"C:\\p\\plain.emf", 250, 250, 0, 6, srcW, srcH, &meta);
        check(out!=NULL && meta.frames==1, "an image whose frame list GDI+ will not give is a single frame");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);
    }

    // ---- the resolution ------------------------------------------------------------------
    printf("  the resolution\n");
    {
        gShimReset();
        gShimFileDpi = 0.0f;
        int srcW = 0, srcH = 0;
        TpSrcMeta meta;
        Gdiplus::GpBitmap *out = tpGDIPload(L"C:\\p\\nodpi.emf", 250, 250, 0, 6, srcW, srcH, &meta);
        check(meta.dpi==0, "a zero resolution is recorded as nothing at all");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        gShimReset();
        gShimResolutionFails = 1;
        meta = TpSrcMeta();
        out = tpGDIPload(L"C:\\p\\nodpi.emf", 250, 250, 0, 6, srcW, srcH, &meta);
        check(out!=NULL && meta.dpi==0, "and so is one GDI+ refuses to report, without failing the load");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        gShimReset();
        gShimFileDpi = 149.6f;
        meta = TpSrcMeta();
        out = tpGDIPload(L"C:\\p\\dpi.emf", 250, 250, 0, 6, srcW, srcH, &meta);
        check(meta.dpi==150, "a real one is rounded, not truncated");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);
    }

    // ---- what is refused, and what it costs ----------------------------------------------
    printf("  the files it refuses\n");
    {
        gShimReset();
        int srcW = 0, srcH = 0;
        check(tpGDIPload(L"", 250, 250, 0, 6, srcW, srcH, NULL)==NULL, "an empty path is refused");
        check(gShimCreatedFromFile==0, "without asking GDI+ anything");

        gShimReset();
        gShimLoadFails = 1;
        check(tpGDIPload(L"C:\\p\\broken.gif", 250, 250, 0, 6, srcW, srcH, NULL)==NULL,
              "a file GDI+ cannot open either fails");
        check(gShimLiveCount()==0, "and leaves nothing behind");

        // a 1x1 is what a decoder hands back when it gave up rather than a picture; the WIC
        // loader applies the same floor
        gShimReset();
        gShimFileW = gShimFileH = 1;
        check(tpGDIPload(L"C:\\p\\pixel.gif", 250, 250, 0, 6, srcW, srcH, NULL)==NULL, "a 1x1 result is refused");
        check(gShimLiveCount()==0, "and the bitmap it came in is disposed");

        gShimReset();
        gShimGraphicsFails = 1;
        check(tpGDIPload(L"C:\\p\\ok.emf", 250, 250, 0, 6, srcW, srcH, NULL)==NULL,
              "a copy that cannot be made fails the load");
        check(gShimLiveCount()==0, "and still lets go of the file");
    }

    // ---- the resize itself ---------------------------------------------------------------
    printf("  the resize asks for the modes Gdip_ResizeBitmap() asks for\n");
    {
        gShimReset();
        int srcW = 0, srcH = 0;
        Gdiplus::GpBitmap *out = tpGDIPload(L"C:\\p\\a.emf", 250, 250, 0, 6, srcW, srcH, NULL);
        check(gShimDrawCalls==1, "one DrawImage, not a loop");
        check(gShimDrawInterp==6, "the interpolation the caller asked for");
        check(gShimDrawSmooth==Gdiplus::SmoothingModeAntiAlias, "antialiased smoothing");
        check(gShimDrawOffset==Gdiplus::PixelOffsetModeHighQuality, "high quality pixel offsets");
        check(gShimDrawW==250 && gShimDrawH==188,
              "and it draws over the whole destination");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        // an interpolation mode GDI+ does not have would fail the DrawImage on the real
        // thing; the loader clamps instead
        gShimReset();
        out = tpGDIPload(L"C:\\p\\a.emf", 250, 250, 0, 4242, srcW, srcH, NULL);
        check(out!=NULL && gShimDrawInterp==7, "an out of range mode is clamped, not passed on");
        if (out!=NULL) Gdiplus::DllExports::GdipDisposeImage(out);

        check(tpGdipResizeCopy(NULL, 8, 8, 6)==NULL, "a missing source is refused");
        gShimReset();
        Gdiplus::GpBitmap *src = NULL;
        Gdiplus::DllExports::GdipCreateBitmapFromScan0(8, 8, 0, PixelFormat32bppARGB, NULL, &src);
        check(tpGdipResizeCopy(src, 0, 8, 6)==NULL, "and so is a degenerate size");
        Gdiplus::DllExports::GdipDisposeImage(src);
    }

    gShimReset();
    printf("\n  %s\n", failures ? "GDI+ LOADER TEST FAILED" : "GDI+ loader test passed");
    return failures ? 1 : 0;
}
