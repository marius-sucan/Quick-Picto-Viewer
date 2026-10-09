// tpWICload() with colour management: the colour transform the thumbnails pool builds per
// call, as applyColorManagement() builds it for LoadWICimage() with objects of its own.
//
// thumbs-pool.h cannot be compiled on this box, so run-tests.sh TEXT-SLICES the WIC loader
// out of it, between qpv-wic-loader-begin and qpv-wic-loader-end, together with the guards of
// wic-loader.h it calls, and both are compiled against shim/wic-env.h: WIC interfaces with
// the SDK's signatures and fakes behind them that keep real reference counts.
//
// Colour fidelity cannot be judged here - that takes Windows' colour management. What is
// pinned is everything around it:
//   - which frames get a transform: an embedded profile, a non-sRGB EXIF colour space, and
//     the fallbacks applyColorManagement() applies; not an EXIF sRGB one, not without
//     colour management, not a pixel format it does not convert.
//   - where it sits: on the frame, read by the scaler - never under a scaler that
//     interpolates, which is what breaks colour management in coreWICgetBufferImage().
//   - that every way it can fail ends in the image decoded as without colour management,
//     rather than in a failed thumbnail or a full size one.
//   - that each decode releases every object it made, exactly once.
//
// written by Marius Șucan with Claude Opus 5

#include "shim/wic-env.h"

// sliced out of ../wic-loader.h and ../thumbs-pool.h by run-tests.sh
#include "thumbs_structs.part"
#include "wic_guards.part"
#include "adapt_size.part"
#include "wic_loader.part"

// the viewer's own: applyColorManagement() and the SafeRelease() it uses, on the global factory
static IWICImagingFactory *m_pIWICFactory = NULL;
#include "safe_release.part"
#include "icm_viewer.part"

static int failures = 0;
static void check(bool cond, const char *what) {
    printf("    %-70s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

static FakeFactory gFactory;

struct Decode {
    int ok = 0, w = 0, h = 0, grey = -1, srcW = 0, srcH = 0;
};

// one thumbnail of the 1000x800 fake frame, into a 250 box unless told otherwise
static Decode decode(int useICM, int box = 250) {
    shimResetCounters();
    Decode d;
    TpSrcMeta meta;
    Gdiplus::GpBitmap *b = tpWICload(&gFactory, L"C:\\p\\photo.jpg", box, box, 0, 5, 0, d.srcW, d.srcH, &meta, useICM);
    if (b!=NULL)
    {
       d.ok = 1;
       d.w = b->w;
       d.h = b->h;
       d.grey = b->px[0];
       Gdiplus::DllExports::GdipDisposeImage(b);
    }
    return d;
}

static void scenario(const ShimScenario &s) { gScn = s; }

static bool clean() { return gLiveCom==0 && gOverRelease==0 && gShimLiveBitmaps==0; }

// applyColorManagement() as LoadWICimage() drives it: the source it is handed is released and
// replaced when a transform is built, and the cleanup call (100) after the copy lets go of the
// colour contexts it keeps in statics. Returns what it returned; *transformed says whether the
// source was replaced.
static int viewerICM(const ShimScenario &s, bool *transformed) {
    scenario(s);
    shimResetCounters();
    m_pIWICFactory = &gFactory;
    IWICBitmapFrameDecode *frame = new FakeFrame();
    IWICBitmapSource *source = frame;
    frame->AddRef();
    const int r = applyColorManagement(source, frame, GUID_WICPixelFormat32bppPBGRA, 1);
    *transformed = (source!=frame);
    source->Release();
    applyColorManagement(source, frame, GUID_WICPixelFormat32bppPBGRA, 100);
    frame->Release();
    return r;
}

int main() {
    printf("thumbs-pool.h WIC loader, colour management\n");

    ShimScenario profiled;
    profiled.contexts = 1;
    profiled.contextType = WICColorContextProfile;

    printf("  without colour management\n");
    {
        scenario(profiled);
        Decode d = decode(0);
        check(d.ok && d.w==250 && d.h==200 && d.grey==100, "a profiled image is decoded and scaled as it is");
        check(gContextsMade==0 && gTransformsMade==0, "and no colour context is ever asked for");
        check(gScalerReadsTransform==0, "the scaler reads the frame, so a JPEG keeps its scaled decode");
        check(clean(), "nothing is left alive, nothing released twice");
    }

    printf("  an embedded profile\n");
    {
        scenario(profiled);
        gShimDebug.clear();
        Decode d = decode(1);
        check(d.ok && d.w==250 && d.h==200, "the thumbnail is made at its size");
        check(d.grey==150, "out of colour managed pixels");
        check(gTransformReadsFrame==1, "the transform reads the frame itself");
        check(gScalerReadsTransform==1, "and the scaler reads the transform, never the other way round");
        check(gTransformDestExif==1 && gTransformDestFmt==GUID_WICPixelFormat32bppPBGRA,
              "into sRGB and 32bppPBGRA, as applyColorManagement() converts");
        check(gTransformSrcType==WICColorContextProfile, "from the frame's own profile");
        check(gDecoders==1, "in one decode");
        check(clean(), "nothing is left alive, nothing released twice");

        decode(1);
        int said = 0;
        for (size_t i = 0; i < gShimDebug.size(); i++)
            if (gShimDebug[i].find("colour management applied")!=std::string::npos)
               said++;
        check(said==1, "the debug output says so once, not per file");
    }

    printf("  EXIF colour spaces\n");
    {
        ShimScenario s = profiled;
        s.contextType = WICColorContextExifColorSpace;
        s.exifSpace = 1;
        scenario(s);
        Decode d = decode(1);
        check(d.ok && d.grey==100 && gTransformsMade==0, "EXIF sRGB gets no transform: it would change nothing");
        check(gScalerReadsTransform==0, "so the scaler still reads the frame");
        check(clean(), "and the context it read is released");

        s.exifSpace = 2;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==150 && gTransformSrcType==WICColorContextExifColorSpace,
              "EXIF Adobe RGB is converted to sRGB");
        check(clean(), "nothing is left alive, nothing released twice");
    }

    printf("  no profile at all\n");
    {
        ShimScenario s;
        scenario(s);
        Decode d = decode(1);
        check(d.ok && d.grey==100 && gTransformsMade==0, "an untagged 24-bit image is left as it is");
        check(clean(), "and its unused context is released");

        s.pixelFmt = GUID_WICPixelFormat64bppRGBA;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100 && gTransformsMade==0, "an untagged 64bppRGBA image is sRGB: no transform");
        check(clean(), "nothing is left alive, nothing released twice");

        s.pixelFmt = GUID_WICPixelFormat32bppCMYK;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100 && gTransformsMade==0,
              "untagged CMYK: no EXIF colour space describes it, so no transform");
        check(clean(), "nothing is left alive, nothing released twice");

        s.pixelFmt = GUID_WICPixelFormat8bppIndexed;
        s.contexts = 1;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100 && gContextsMade==0, "a format the transform does not take is not asked about");
    }

    printf("  CMYK with a profile\n");
    {
        ShimScenario s = profiled;
        s.pixelFmt = GUID_WICPixelFormat32bppCMYK;
        scenario(s);
        Decode d = decode(1);
        check(d.ok && d.grey==150, "is converted with its own profile");
        check(gContextsMade==3, "with the standard CMYK context made as the fallback");
        check(clean(), "nothing is left alive, nothing released twice");

        s.transformInitFails = 1;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100 && gTransformInits==2, "a profile the transform refuses is retried, then left");
        check(clean(), "nothing is left alive, nothing released twice");
    }

    printf("  everything that can fail ends as a plain decode\n");
    {
        ShimScenario s = profiled;
        s.createContextFails = 1;
        scenario(s);
        Decode d = decode(1);
        check(d.ok && d.grey==100, "no colour context to be had");
        check(clean(), "nothing is left alive, nothing released twice");

        s = profiled;
        s.contextsHr = E_FAIL;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100, "the frame's contexts cannot be read");
        check(clean(), "nothing is left alive, nothing released twice");

        s = profiled;
        s.createTransformFails = 1;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100, "no transformer to be had");
        check(clean(), "nothing is left alive, nothing released twice");

        s = profiled;
        s.transformInitFails = 1;
        scenario(s);
        d = decode(1);
        check(d.ok && d.grey==100 && d.w==250, "the transform refuses the profile");
        check(clean(), "nothing is left alive, nothing released twice");

        s = profiled;
        s.scalerRejectsTransform = 1;
        scenario(s);
        d = decode(1);
        check(d.ok && d.w==250 && d.h==200 && d.grey==100,
              "the scaler cannot read the transform: a plain thumbnail, not a full size one");
        check(gDecoders==2, "decoded again for it");
        check(clean(), "nothing is left alive, nothing released twice");

        s = profiled;
        s.transformCopyFails = 1;
        scenario(s);
        d = decode(1);
        check(d.ok && d.w==250 && d.grey==100, "the transform fails only when the pixels are copied");
        check(gDecoders==2, "decoded again for it");
        check(clean(), "nothing is left alive, nothing released twice");
    }

    printf("  no thumbnail box\n");
    {
        scenario(profiled);
        Decode d = decode(1, 0);
        check(d.ok && d.w==1000 && d.h==800 && d.grey==150, "the native size, colour managed");
        check(gConverterReadsTransform==1, "the converter reads the transform directly");
        check(clean(), "nothing is left alive, nothing released twice");
    }

    printf("  the viewer's applyColorManagement()\n");
    {
        bool transformed = false;
        int r = viewerICM(profiled, &transformed);
        check(r==1 && transformed && gTransformReadsFrame==1, "a profiled frame is given its transform");
        check(gTransformDestExif==1 && gTransformDestFmt==GUID_WICPixelFormat32bppPBGRA, "into sRGB and 32bppPBGRA");
        check(clean(), "and the cleanup call lets go of everything, once");

        ShimScenario s;
        s.pixelFmt = GUID_WICPixelFormat64bppRGBA;
        r = viewerICM(s, &transformed);
        check(r==0 && !transformed && gTransformsMade==0, "an untagged 64bppRGBA frame is sRGB: no transform");
        check(clean(), "nothing is left alive, nothing released twice");

        // CreateColorContext() failing leaves no context to fall back on, for CMYK or RGB
        s.createContextFails = 1;
        r = viewerICM(s, &transformed);
        check(r==0 && !transformed, "64bppRGBA survives a failed CreateColorContext()");
        s.pixelFmt = GUID_WICPixelFormat32bppCMYK;
        r = viewerICM(s, &transformed);
        check(r==0 && !transformed, "and so does CMYK");
        check(clean(), "nothing is left alive, nothing released twice");
    }

    printf("\n  %s\n", failures ? "WIC COLOUR MANAGEMENT TEST FAILED" : "WIC colour management test passed");
    return failures ? 1 : 0;
}
