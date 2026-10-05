// tpFIMthumb(), the FreeImage loader both worker pools share, run against the real FreeImage:
// the Linux build of the fork QPV ships (github: marius-sucan/FreeImage-library).
//
// thumbs-pool.h cannot be compiled on this box, so run-tests.sh TEXT-SLICES the loader out of
// it, between qpv-fim-loader-begin and qpv-fim-loader-end, and the binding is the shipped
// freeimage-dynamic.h, bound with dlopen() through shim/fim/windows.h. What is pinned is the
// decision FIMapplyToneMapper() makes in the viewer, and where in the loader it can be made:
//
//   - FreeImage_MustTonemap() is asked about the bitmap as loaded. The rescale keeps neither
//     the ICC profile nor - through OpenCV - the CICP tag, and without them a PQ image reads
//     as display encoded and is shown as its raw code values.
//   - a PQ image is linearised at full size, before it is tone mapped.
//   - userPerformColorManagement reaches the decoder as FIF_LOAD_DISPLAY_ICC: a 16-bit RAW
//     then comes back display encoded and is no longer tone mapped.
//   - the marker FIMapplyToneMapper() appends to the pixel format, and the bit depth the
//     format is spelled with, which is the one the file was loaded with.
//   - a FreeImage.dll without FreeImage_MustTonemap() keeps the bit depth rule.
//
// Usage:  QPV_FREEIMAGE_SO=<fork>/Dist/libfreeimage-3.20.0.so ./fim_thumb <fork root> <scratch dir>
// The sample images are the fork's own; a test whose file is missing is skipped, not failed.
//
// written by Marius Șucan with Claude Opus 5

#include "shim/fim-env.h"
#include "../freeimage-dynamic.h"

// sliced out of ../thumbs-pool.h by run-tests.sh
#include "fim_defs.part"
#include "thumbs_structs.part"
#include "fim_config.part"
#include "calc_dims.part"

// enableCaching is 0 in every test: nothing is ever written
static int tpSavePngFIM(FIBITMAPptr, const std::wstring&) { return 0; }

#ifdef QPV_FIM_MUTANT
static int tpFIMtoneMapVerdictOnThumb(FIBITMAPptr dib, int GFT);
#endif

#include "fim_loader.part"

#ifdef QPV_FIM_MUTANT
// the verdict taken on the thumbnail rather than on the bitmap as loaded
static int tpFIMtoneMapVerdictOnThumb(FIBITMAPptr dib, int GFT) {
    int w = 0, h = 0;
    tpCalcIMGdimensions((int)FIM.GetWidth(dib), (int)FIM.GetHeight(dib), 250, 250, w, h);
    FIBITMAPptr small = tpFIMrescale(dib, w, h);
    const int v = (small!=NULL) ? tpFIMtoneMapVerdict(small, GFT) : FITM_ERROR;
    if (small!=NULL)
       FIM.Unload(small);
    return v;
}
#endif

#define FIF_TIFF_  18
#define FIF_AVIF_  37

static int failures = 0, skipped = 0;
static void check(bool cond, const char *what) {
    printf("    %-70s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

// ---- the narrow entry points: FreeImage's *U functions read no path outside Windows --------

static struct {
    int         (*GetFileType)(const char*, int);
    int         (*GetFIFFromFilename)(const char*);
    FIBITMAPptr (*Load)(int, const char*, int);
    BOOL        (*Save)(int, FIBITMAPptr, const char*, int);
    FIBITMAPptr (*ConvertToRGB16)(FIBITMAPptr);
    FIBITMAPptr (*ConvertToUINT16)(FIBITMAPptr);
    BYTE*       (*GetScanLine)(FIBITMAPptr, int);
} X;

static int gLastLoadFlags = -1;

static std::string narrow(const wchar_t *w) {
    std::string s;
    for (; w && *w; w++) s.push_back((char)*w);
    return s;
}
static int shimGetFileTypeU(const wchar_t *p, int size) { return X.GetFileType(narrow(p).c_str(), size); }
static int shimGetFIFFromFilenameU(const wchar_t *p) { return X.GetFIFFromFilename(narrow(p).c_str()); }
static FIBITMAPptr shimLoadU(int fif, const wchar_t *p, int flags) {
    gLastLoadFlags = flags;
    return X.Load(fif, narrow(p).c_str(), flags);
}
static BOOL shimSaveU(int fif, FIBITMAPptr dib, const wchar_t *p, int flags) {
    return X.Save(fif, dib, narrow(p).c_str(), flags);
}

// ---- running the loader ---------------------------------------------------------------------

struct Thumb {
    int status = -1, srcW = 0, srcH = 0, outW = 0, outH = 0, saved = 0;
    double mean = -1;
    TpSrcMeta meta;
};

static ThumbsConfig baseConfig() {
    ThumbsConfig cfg;
    cfg.thumbSize = 250;
    cfg.enableCaching = 0;
    cfg.wantBitmap = 1;
    cfg.userHQraw = 1;
    cfg.allowToneMapping = 1;
    cfg.toneMapAlgo = 0;      // FreeImage_ToneMapping(), Drago 2003, its own defaults
    cfg.colorManage = 0;
    return cfg;
}

static Thumb thumb(const std::string &path, const ThumbsConfig &cfg) {
    Thumb t;
    const std::wstring w(path.begin(), path.end());
    Gdiplus::GpBitmap *b = tpFIMthumb(&cfg, w, L"", GetTickCount(), t.srcW, t.srcH, t.status, t.saved, &t.meta);
    if (b!=NULL)
    {
       t.outW = b->w;
       t.outH = b->h;
       t.mean = shimMeanBGR(b);
       Gdiplus::DllExports::GdipDisposeImage(b);
    }
    return t;
}

static bool have(const std::string &path) {
    FILE *f = fopen(path.c_str(), "rb");
    if (f==NULL)
    {
       printf("    %-70s skipped\n", ("missing: " + path).c_str());
       skipped++;
       return false;
    }
    fclose(f);
    return true;
}

static double meanOfDib(FIBITMAPptr dib) {
    const int w = (int)FIM.GetWidth(dib), h = (int)FIM.GetHeight(dib), step = (int)FIM.GetBPP(dib)/8;
    double sum = 0;
    for (int y = 0; y < h; y++)
    {
        const BYTE *row = X.GetScanLine(dib, y);
        for (int x = 0; x < w; x++)
            sum += row[x*step] + row[x*step + 1] + row[x*step + 2];
    }
    return sum/(3.0*w*h);
}

// a PQ image tone mapped at thumbnail size, from linear light or from its code values
static double toneMappedMean(const std::string &path, bool linear) {
    FIBITMAPptr dib = X.Load(FIF_AVIF_, path.c_str(), 0);
    if (dib==NULL)
       return -1;

    if (linear)
    {
       FIBITMAPptr lin = FIM.ConvertToLinear(dib, 0);
       FIM.Unload(dib);
       dib = lin;
    }

    int w = 0, h = 0;
    tpCalcIMGdimensions((int)FIM.GetWidth(dib), (int)FIM.GetHeight(dib), 250, 250, w, h);
    FIBITMAPptr small = tpFIMrescale(dib, w, h);
    FIM.Unload(dib);
    FIBITMAPptr mapped = FIM.ToneMapping(small, 0, 0, 0);
    FIM.Unload(small);
    const double m = (mapped!=NULL) ? meanOfDib(mapped) : -1;
    if (mapped!=NULL)
       FIM.Unload(mapped);
    return m;
}

// test.jpg widened to 16 bits a channel, as FreeImage widens: display encoded samples
static std::string makeWidenedTiff(const std::string &jpeg, const std::string &scratch, bool grey12) {
    FIBITMAPptr src = X.Load(2, jpeg.c_str(), 0);
    if (src==NULL)
       return "";

    FIBITMAPptr wide = grey12 ? X.ConvertToUINT16(src) : X.ConvertToRGB16(src);
    FIM.Unload(src);
    if (wide==NULL)
       return "";

    if (grey12)
    {
       // 12 significant bits, stored unscaled: the case MustTonemap() calls optional
       for (int y = 0; y < (int)FIM.GetHeight(wide); y++)
       {
           WORD *row = (WORD*)X.GetScanLine(wide, y);
           for (int x = 0; x < (int)FIM.GetWidth(wide); x++)
               row[x] = (WORD)(row[x] >> 4);
       }
    }

    const std::string out = scratch + (grey12 ? "/fim_thumb_uint16.tif" : "/fim_thumb_rgb16.tif");
    const BOOL ok = X.Save(FIF_TIFF_, wide, out.c_str(), 0);
    FIM.Unload(wide);
    return ok ? out : "";
}

int main(int argc, char **argv) {
    printf("thumbs-pool.h FreeImage loader, against the real FreeImage\n");
    if (argc<3)
    {
       printf("  usage: QPV_FREEIMAGE_SO=<library> %s <FreeImage fork root> <scratch dir>\n", argv[0]);
       return 2;
    }

    bindFreeImageOnce();
    if (!FIM.ok)
    {
       printf("  ERROR: the library named by QPV_FREEIMAGE_SO could not be bound\n");
       return 2;
    }

    #define BINDX(field, name) *(void**)&X.field = dlsym(FIM.hLib, name)
    BINDX(GetFileType, "FreeImage_GetFileType");
    BINDX(GetFIFFromFilename, "FreeImage_GetFIFFromFilename");
    BINDX(Load, "FreeImage_Load");
    BINDX(Save, "FreeImage_Save");
    BINDX(ConvertToRGB16, "FreeImage_ConvertToRGB16");
    BINDX(ConvertToUINT16, "FreeImage_ConvertToUINT16");
    BINDX(GetScanLine, "FreeImage_GetScanLine");
    #undef BINDX

    check(FIM.MustTonemap!=NULL && FIM.ConvertToLinear!=NULL,
          "freeimage-dynamic.h binds FreeImage_MustTonemap and FreeImage_ConvertToLinear");
    if (FIM.MustTonemap==NULL || !X.Load || !X.Save || !X.ConvertToRGB16 || !X.ConvertToUINT16 || !X.GetScanLine)
    {
       printf("  ERROR: this FreeImage build predates FreeImage_MustTonemap()\n");
       return 2;
    }

    FIM.GetFileTypeU = shimGetFileTypeU;
    FIM.GetFIFFromFilenameU = shimGetFIFFromFilenameU;
    FIM.LoadU = shimLoadU;
    FIM.SaveU = shimSaveU;

    const std::string root = argv[1], scratch = argv[2];
    const std::string pq    = root + "/TestAPI/AVIF/data/seine_hdr_rec2020.avif";
    const std::string heif  = root + "/TestAPI/HEIF/data/RGB_10__128x128.heif";
    const std::string jpeg  = root + "/TestAPI/test.jpg";
    const std::string cr2   = root + "/HDR-tests/canon_eos_70d_02.cr2";
    const std::string exr   = root + "/HDR-tests/rogland_clear_night_4k.exr";
    const std::string hdr   = root + "/HDR-tests/leadenhall_market_4k.hdr";

    // ---- PQ ----------------------------------------------------------------------------
    printf("  a PQ image: decided before the rescale, linearised before the tone mapping\n");
    if (have(pq))
    {
        ThumbsConfig cfg = baseConfig();
        Thumb t = thumb(pq, cfg);
        const double fromLinear = toneMappedMean(pq, true), fromCodes = toneMappedMean(pq, false);
        printf("      thumbnail mean %.2f; tone mapped from linear light %.2f, from the PQ code values %.2f\n",
               t.mean, fromLinear, fromCodes);
        check(t.status==TP_OK && t.outW==250 && t.outH==188, "the 400x300 AVIF comes back as a 250x188 thumbnail");
        check(t.meta.fimToneMap==1, "it is tone mapped: \" (TONE-MAPPED)\"");
        check(t.meta.fimBPP==48 && t.meta.fimColor==FIC_RGB,
              "its pixel format is spelled as loaded, 48-RGB, not as linearised");
        check(fabs(fromLinear - fromCodes)>10.0, "the two orders give visibly different thumbnails");
        check(fabs(t.mean - fromLinear)<0.5, "and the thumbnail is the one tone mapped from linear light");

        cfg.allowToneMapping = 0;
        t = thumb(pq, cfg);
        check(t.meta.fimToneMap==1, "PQ is tone mapped even with allowToneMappingImg off");

        cfg = baseConfig();
        cfg.colorManage = 1;
        t = thumb(pq, cfg);
        check((gLastLoadFlags & FIF_LOAD_DISPLAY_ICC)!=0, "colorManage=1 loads with FIF_LOAD_DISPLAY_ICC");
        check(t.status==TP_OK && t.meta.fimToneMap==1, "on an sRGB display it is still a PQ image, tone mapped");

        // a library with the verdict but without the linearisation tone maps the code values
        FIBITMAPptr (__stdcall *keep)(FIBITMAPptr, int) = FIM.ConvertToLinear;
        FIM.ConvertToLinear = NULL;
        t = thumb(pq, baseConfig());
        FIM.ConvertToLinear = keep;
        check(t.status==TP_OK && t.meta.fimToneMap==1 && fabs(t.mean - fromCodes)<0.5,
              "without FreeImage_ConvertToLinear() the code values are tone mapped, as the AHK does");
    }

    // ---- camera RAW at 16 bits: linear light, or display encoded with colour management -------
    printf("  a 16-bit camera RAW\n");
    if (have(cr2))
    {
        ThumbsConfig cfg = baseConfig();
        Thumb toned = thumb(cr2, cfg);
        check((gLastLoadFlags & FIF_LOAD_DISPLAY_ICC)==0, "colorManage=0 leaves FIF_LOAD_DISPLAY_ICC out");
        check(toned.status==TP_OK && toned.meta.fimToneMap==1, "linear light, tone mapped when allowed");
        check(toned.meta.fimBPP==48, "and recorded as the 48-bit image LibRaw decoded");

        cfg.allowToneMapping = 0;
        Thumb linear = thumb(cr2, cfg);
        check(linear.status==TP_OK && linear.meta.fimToneMap==2,
              "not tone mapped when it is not allowed: \" (TONE-MAPPABLE)\"");

        cfg = baseConfig();
        cfg.colorManage = 1;
        Thumb managed = thumb(cr2, cfg);
        printf("      means: tone mapped %.1f, linear %.1f, display encoded %.1f\n", toned.mean, linear.mean, managed.mean);
        check(managed.status==TP_OK && managed.meta.fimToneMap==2,
              "with colour management it comes back display encoded, and is not tone mapped");
        check(managed.mean>linear.mean + 20.0, "so it is shown with its tone curve rather than as linear light");

        cfg = baseConfig();
        cfg.userHQraw = 0;
        Thumb preview = thumb(cr2, cfg);
        check(preview.status==TP_OK && preview.meta.fimToneMap==2 && preview.meta.fimBPP==24,
              "the embedded preview of a low quality load is marked as LoadFimFile() marks it");
    }

    // ---- floating point: always tone mapped ------------------------------------------------
    printf("  floating point images\n");
    if (have(exr))
    {
        ThumbsConfig cfg = baseConfig();
        cfg.allowToneMapping = 0;
        Thumb t = thumb(exr, cfg);
        check(t.status==TP_OK && t.meta.fimToneMap==1, "an OpenEXR image is tone mapped even when it is not allowed");
    }
    if (have(hdr))
    {
        Thumb t = thumb(hdr, baseConfig());
        check(t.status==TP_OK && t.meta.fimToneMap==1, "and so is a Radiance HDR one");
    }

    // ---- display encoded 16-bit images: shown as they are -----------------------------------
    printf("  display encoded 16-bit images\n");
    std::string rgb16, uint12;
    if (have(heif))
    {
        Thumb t = thumb(heif, baseConfig());
        check(t.status==TP_OK && t.meta.fimToneMap==0 && t.meta.fimBPP==48,
              "a 10-bit HEIF is not tone mapped, and carries no marker");
    }
    if (have(jpeg))
    {
        Thumb plain = thumb(jpeg, baseConfig());
        rgb16 = makeWidenedTiff(jpeg, scratch, false);
        uint12 = makeWidenedTiff(jpeg, scratch, true);
        check(!rgb16.empty() && !uint12.empty(), "the 16-bit test images are written");

        Thumb wide = thumb(rgb16, baseConfig());
        printf("      means: 8-bit original %.2f, widened to 16 bits %.2f\n", plain.mean, wide.mean);
        check(wide.status==TP_OK && wide.meta.fimToneMap==0, "a 16-bit TIFF of 8-bit samples is not tone mapped");
        check(fabs(wide.mean - plain.mean)<1.0, "and looks like the 8-bit image it was made of");

        Thumb grey = thumb(uint12, baseConfig());
        check(grey.status==TP_OK && grey.meta.fimToneMap==0,
              "UINT16 is greyed to 24 bits, never tone mapped, as LoadFimFile() does");
    }

    // ---- a FreeImage.dll without FreeImage_MustTonemap() -------------------------------------
    printf("  the bit depth rule, for a FreeImage.dll that predates FreeImage_MustTonemap()\n");
    {
        int (__stdcall *keepMust)(FIBITMAPptr, int) = FIM.MustTonemap;
        FIBITMAPptr (__stdcall *keepLin)(FIBITMAPptr, int) = FIM.ConvertToLinear;
        FIM.MustTonemap = NULL;
        FIM.ConvertToLinear = NULL;
        if (have(exr))
        {
           ThumbsConfig cfg = baseConfig();
           cfg.allowToneMapping = 0;
           check(thumb(exr, cfg).meta.fimToneMap==1, "OpenEXR is tone mapped whether allowed or not");
        }
        if (have(heif))
        {
           ThumbsConfig cfg = baseConfig();
           check(thumb(heif, cfg).meta.fimToneMap==1, "a 48-bit HEIF is tone mapped when allowed");
           cfg.allowToneMapping = 0;
           check(thumb(heif, cfg).meta.fimToneMap==0, "and left alone when not");
        }
        if (!rgb16.empty())
           check(thumb(rgb16, baseConfig()).meta.fimToneMap==1, "so is a 48-bit TIFF");
        FIM.MustTonemap = keepMust;
        FIM.ConvertToLinear = keepLin;
    }

    // ---- what is refused -------------------------------------------------------------------
    printf("  the files it refuses\n");
    {
        Thumb t = thumb(scratch + "/no such file.png", baseConfig());
        check(t.status==TP_ERR_LOAD && t.mean<0, "a file that is not there fails the load");
    }

    check(gShimLiveBitmaps==0, "every GDI+ bitmap handed back was disposed");
    if (!rgb16.empty())  remove(rgb16.c_str());
    if (!uint12.empty()) remove(uint12.c_str());

    if (skipped)
       printf("\n  %d test(s) skipped for want of a sample image\n", skipped);
    printf("\n  %s\n", failures ? "FREEIMAGE LOADER TEST FAILED" : "FreeImage loader test passed");
    return failures ? 1 : 0;
}
