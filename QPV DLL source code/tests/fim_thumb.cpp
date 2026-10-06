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
    const void* (*GetBuiltInICCProfile)(int, DWORD*);
    BOOL        (*SetDisplayICCProfile)(const void*, DWORD, int);
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
    double mean = -1, bgr[3] = {-1, -1, -1}, chroma = -1;
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
       t.mean = shimMeanBGR(b, t.bgr);
       t.chroma = shimMeanChroma(b);
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

struct Means {
    double all = -1, bgr[3] = {-1, -1, -1}, chroma = -1;
};

static Means meansOfDib(FIBITMAPptr dib) {
    const int w = (int)FIM.GetWidth(dib), h = (int)FIM.GetHeight(dib), step = (int)FIM.GetBPP(dib)/8;
    double sum[3] = {0, 0, 0}, chroma = 0;
    for (int y = 0; y < h; y++)
    {
        const BYTE *row = X.GetScanLine(dib, y);
        for (int x = 0; x < w; x++)
        {
            const BYTE *p = row + x*step;
            for (int c = 0; c < 3; c++)
                sum[c] += p[c];
            chroma += max(p[0], max(p[1], p[2])) - min(p[0], min(p[1], p[2]));
        }
    }

    Means m;
    for (int c = 0; c < 3; c++)
        m.bgr[c] = sum[c]/((double)w*h);
    m.all = (m.bgr[0] + m.bgr[1] + m.bgr[2])/3.0;
    m.chroma = chroma/((double)w*h);
    return m;
}

static double largestChannelGap(const double *a, const double *b) {
    double gap = 0;
    for (int c = 0; c < 3; c++)
        gap = max(gap, fabs(a[c] - b[c]));
    return gap;
}

// FreeImage's Display P3 profile as the display's; false when it was refused
static bool pinDisplayP3() {
    DWORD size = 0;
    const void *p3 = X.GetBuiltInICCProfile(5, &size);   // FICMS_PROFILE_DISPLAY_P3
    // FICMS_INTENT_RELATIVE_COLORIMETRIC | FICMS_BLACKPOINT_COMPENSATION
    return p3!=NULL && X.SetDisplayICCProfile(p3, size, 0x101);
}

static void unpinDisplay() {
    X.SetDisplayICCProfile(NULL, 0, 0x101);
}

// a PQ image tone mapped at thumbnail size, from linear light made with these
// FreeImage_ConvertToLinear() flags, or from its code values when linearFlags is -1
static Means toneMapped(const std::string &path, int linearFlags) {
    Means m;
    FIBITMAPptr dib = X.Load(FIF_AVIF_, path.c_str(), 0);
    if (dib==NULL)
       return m;

    if (linearFlags>=0)
    {
       FIBITMAPptr lin = FIM.ConvertToLinear(dib, linearFlags);
       FIM.Unload(dib);
       dib = lin;
    }

    int w = 0, h = 0;
    tpCalcIMGdimensions((int)FIM.GetWidth(dib), (int)FIM.GetHeight(dib), 250, 250, w, h);
    FIBITMAPptr small = tpFIMrescale(dib, w, h);
    FIM.Unload(dib);
    FIBITMAPptr mapped = FIM.ToneMapping(small, 0, 0, 0);
    FIM.Unload(small);
    if (mapped!=NULL)
    {
       m = meansOfDib(mapped);
       FIM.Unload(mapped);
    }
    return m;
}

// a horizontal ramp from lo to hi in a one-channel type, saved as TIFF, which keeps every type
static std::string makeScalarTiff(const std::string &scratch, const char *name, int type, int bpp, double lo, double hi) {
    const int w = 300, h = 200;
    FIBITMAPptr dib = FIM.AllocateT(type, w, h, bpp, 0, 0, 0);
    if (dib==NULL)
       return "";

    for (int y = 0; y < h; y++)
    {
        BYTE *row = X.GetScanLine(dib, y);
        for (int x = 0; x < w; x++)
        {
            const double v = lo + (hi - lo)*x/(w - 1);
            if (type==FIT_FLOAT)        ((float*)row)[x] = (float)v;
            else if (type==FIT_DOUBLE)  ((double*)row)[x] = v;
            else if (type==FIT_INT16)   ((short*)row)[x] = (short)v;
        }
    }

    const std::string out = scratch + "/" + name;
    const BOOL ok = X.Save(FIF_TIFF_, dib, out.c_str(), 0);
    FIM.Unload(dib);
    return ok ? out : "";
}

// whether every pixel of a thumbnail is grey, and the darkest and brightest of them
struct GreyRange {
    bool grey = false;
    int lo = 255, hi = 0;
};

static GreyRange greyRange(const std::string &path, const ThumbsConfig &cfg, int &status) {
    GreyRange g;
    int sw = 0, sh = 0, saved = 0;
    TpSrcMeta meta;
    const std::wstring w(path.begin(), path.end());
    Gdiplus::GpBitmap *b = tpFIMthumb(&cfg, w, L"", GetTickCount(), sw, sh, status, saved, &meta);
    if (b==NULL)
       return g;

    g.grey = true;
    const int step = b->bpp/8;
    for (int y = 0; y < b->h; y++)
        for (int x = 0; x < b->w; x++)
        {
            const BYTE *p = &b->px[(size_t)y*b->stride + (size_t)x*step];
            if (p[0]!=p[1] || p[1]!=p[2] || (step==4 && p[3]!=255))
               g.grey = false;
            g.lo = min(g.lo, (int)p[0]);
            g.hi = max(g.hi, (int)p[0]);
        }
    Gdiplus::DllExports::GdipDisposeImage(b);
    return g;
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
    BINDX(GetBuiltInICCProfile, "FreeImage_GetBuiltInICCProfile");
    BINDX(SetDisplayICCProfile, "FreeImage_SetDisplayICCProfile");
    #undef BINDX

    check(FIM.MustTonemap!=NULL && FIM.ConvertToLinear!=NULL,
          "freeimage-dynamic.h binds FreeImage_MustTonemap and FreeImage_ConvertToLinear");
    if (FIM.MustTonemap==NULL || !X.Load || !X.Save || !X.ConvertToRGB16 || !X.ConvertToUINT16 || !X.GetScanLine
     || !X.GetBuiltInICCProfile || !X.SetDisplayICCProfile)
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
        const Means inSRGB = toneMapped(pq, FI_LINEAR_SRGB_PRIMARIES), inBT2020 = toneMapped(pq, 0);
        const Means fromCodes = toneMapped(pq, -1);
        printf("      thumbnail mean %.2f, chroma %.2f; from linear light in sRGB's primaries %.2f, %.2f;\n"
               "      in BT.2020's %.2f, %.2f; from the PQ code values %.2f\n",
               t.mean, t.chroma, inSRGB.all, inSRGB.chroma, inBT2020.all, inBT2020.chroma, fromCodes.all);
        check(t.status==TP_OK && t.outW==250 && t.outH==188, "the 400x300 AVIF comes back as a 250x188 thumbnail");
        check(t.meta.fimToneMap==1, "it is tone mapped: \" (TONE-MAPPED)\"");
        check(t.meta.fimBPP==48 && t.meta.fimColor==FIC_RGB,
              "its pixel format is spelled as loaded, 48-RGB, not as linearised");
        check(fabs(inSRGB.all - fromCodes.all)>10.0, "the two orders give visibly different thumbnails");
        check(inSRGB.chroma>inBT2020.chroma*1.15, "BT.2020's primaries read as sRGB's wash the colours out");
        check(largestChannelGap(t.bgr, inSRGB.bgr)<0.5 && fabs(t.chroma - inSRGB.chroma)<0.5,
              "the thumbnail is the one tone mapped from linear light, in sRGB's primaries");

        cfg.allowToneMapping = 0;
        t = thumb(pq, cfg);
        check(t.meta.fimToneMap==1, "PQ is tone mapped even with allowToneMappingImg off");

        cfg = baseConfig();
        cfg.colorManage = 1;
        t = thumb(pq, cfg);
        check((gLastLoadFlags & FIF_LOAD_DISPLAY_ICC)!=0, "colorManage=1 loads with FIF_LOAD_DISPLAY_ICC");
        check(t.status==TP_OK && t.meta.fimToneMap==1, "on an sRGB display it is still a PQ image, tone mapped");

        const Thumb onSRGB = t;
        if (pinDisplayP3())
        {
           t = thumb(pq, cfg);
           unpinDisplay();
           check(t.status==TP_OK && t.meta.fimToneMap==1,
                 "and on a Display P3 one: the display conversion leaves PQ alone");
           printf("      Display P3: chroma %.2f, against %.2f on sRGB\n", t.chroma, onSRGB.chroma);
           check(t.chroma<onSRGB.chroma*0.95, "then converts the tone mapped thumbnail to it");
        } else check(false, "a Display P3 display could be set up");

        // a library with the verdict but without the linearisation tone maps the code values
        FIBITMAPptr (__stdcall *keep)(FIBITMAPptr, int) = FIM.ConvertToLinear;
        FIM.ConvertToLinear = NULL;
        t = thumb(pq, baseConfig());
        FIM.ConvertToLinear = keep;
        check(t.status==TP_OK && t.meta.fimToneMap==1 && fabs(t.mean - fromCodes.all)<0.5,
              "without FreeImage_ConvertToLinear() the code values are tone mapped, as the AHK does");
    }

    // ---- camera RAW at 16 bits: linear light, tone mapped before the display's colours ---------
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
        check((gLastLoadFlags & FIF_LOAD_DISPLAY_ICC)==0, "colour managed, it is still loaded as linear light");
        check(managed.status==TP_OK && managed.meta.fimToneMap==1 && fabs(managed.mean - toned.mean)<0.5,
              "and tone mapped first: on an sRGB display it looks as without colour management");

        // the thumbnail the load flag gives, as with a FreeImage.dll without FreeImage_ApplyDisplayICCProfile()
        BOOL (__stdcall *keepApply)(FIBITMAPptr) = FIM.ApplyDisplayICCProfile;
        cfg.allowToneMapping = 0;
        Thumb plain = thumb(cr2, cfg);
        FIM.ApplyDisplayICCProfile = NULL;
        Thumb onLoad = thumb(cr2, cfg);
        const bool flagged = (gLastLoadFlags & FIF_LOAD_DISPLAY_ICC)!=0;
        FIM.ApplyDisplayICCProfile = keepApply;
        printf("      means: tone mapped %.1f, linear %.1f, display encoded %.1f, by the load flag %.1f\n",
               toned.mean, linear.mean, plain.mean, onLoad.mean);
        check(plain.status==TP_OK && plain.meta.fimToneMap==2, "not tone mapped when it is not allowed, still \" (TONE-MAPPABLE)\"");
        check(plain.mean>linear.mean + 20.0, "and shown with the display's tone curve rather than as linear light");
        check(onLoad.status==TP_OK && largestChannelGap(plain.bgr, onLoad.bgr)<0.5,
              "the display's colours given after the load are the ones the load flag gives");
        check(flagged && onLoad.meta.fimToneMap==0,
              "a library without FreeImage_ApplyDisplayICCProfile() gets them on load, display encoded, no marker");

        if (pinDisplayP3())
        {
           cfg = baseConfig();
           cfg.colorManage = 1;
           Thumb wide = thumb(cr2, cfg);
           cfg.allowToneMapping = 0;
           Thumb widePlain = thumb(cr2, cfg);
           FIM.ApplyDisplayICCProfile = NULL;
           Thumb wideOnLoad = thumb(cr2, cfg);
           FIM.ApplyDisplayICCProfile = keepApply;
           unpinDisplay();
           printf("      Display P3: chroma tone mapped %.2f, against %.2f on sRGB\n", wide.chroma, managed.chroma);
           check(wide.status==TP_OK && wide.meta.fimToneMap==1 && wide.chroma<managed.chroma*0.95,
                 "on a Display P3 display the tone mapped thumbnail is converted to it");
           check(widePlain.status==TP_OK && wideOnLoad.status==TP_OK && largestChannelGap(widePlain.bgr, wideOnLoad.bgr)<0.5,
                 "and, not tone mapped, it gets the colours the load flag gives there");
        } else check(false, "a Display P3 display could be set up");

        cfg = baseConfig();
        cfg.userHQraw = 0;
        Thumb preview = thumb(cr2, cfg);
        check(preview.status==TP_OK && preview.meta.fimToneMap==2 && preview.meta.fimBPP==24,
              "the embedded preview of a low quality load is marked as LoadFimFile() marks it");

        cfg.colorManage = 1;
        Thumb managedPreview = thumb(cr2, cfg);
        check(managedPreview.status==TP_OK && managedPreview.meta.fimToneMap==2,
              "with colour management too: at high quality it is tone mapped first");
        FIM.ApplyDisplayICCProfile = NULL;
        managedPreview = thumb(cr2, cfg);
        FIM.ApplyDisplayICCProfile = keepApply;
        check(managedPreview.status==TP_OK && managedPreview.meta.fimToneMap==0,
              "but not when the display's colours could only come on load");
    }

    // ---- floating point: always tone mapped ------------------------------------------------
    printf("  floating point images\n");
    if (have(exr))
    {
        ThumbsConfig cfg = baseConfig();
        cfg.allowToneMapping = 0;
        Thumb t = thumb(exr, cfg);
        check(t.status==TP_OK && t.meta.fimToneMap==1, "an OpenEXR image is tone mapped even when it is not allowed");

        cfg = baseConfig();
        const Thumb plain = thumb(exr, cfg);
        cfg.colorManage = 1;
        t = thumb(exr, cfg);
        check(t.status==TP_OK && largestChannelGap(t.bgr, plain.bgr)<0.5,
              "colour managed on an sRGB display, it looks as without colour management");
        if (pinDisplayP3())
        {
           t = thumb(exr, cfg);
           unpinDisplay();
           printf("      Display P3: chroma %.2f, against %.2f on sRGB\n", t.chroma, plain.chroma);
           check(t.status==TP_OK && t.chroma<plain.chroma*0.95, "on a Display P3 one it is converted after the tone mapping");
        } else check(false, "a Display P3 display could be set up");
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

    // ---- floating point grey and the scalar types, when nothing tone maps them ----------------
    printf("  one-channel float and integer images that are not tone mapped\n");
    std::vector<std::string> scalars;
    {
        struct { const char *name; int type, bpp; double lo, hi; int allow; const char *what; } cases[] = {
            { "fim_thumb_float_signed.tif", FIT_FLOAT,  32, -0.5,   0.5, 1, "signed FLOAT, verdict 0, is scaled into 8 bits grey" },
            { "fim_thumb_float_unit.tif",   FIT_FLOAT,  32,  0.0,   1.0, 0, "FLOAT within 0..1, tone mapping off, too" },
            { "fim_thumb_int16.tif",        FIT_INT16,  16, -9000, 9000, 1, "INT16 too" },
            { "fim_thumb_double.tif",       FIT_DOUBLE, 64, -3.0,   7.0, 1, "DOUBLE too" },
        };
        for (size_t i = 0; i < sizeof(cases)/sizeof(cases[0]); i++)
        {
            const std::string path = makeScalarTiff(scratch, cases[i].name, cases[i].type, cases[i].bpp, cases[i].lo, cases[i].hi);
            if (path.empty())
            {
               check(false, (std::string("written: ") + cases[i].name).c_str());
               continue;
            }
            scalars.push_back(path);
            ThumbsConfig cfg = baseConfig();
            cfg.allowToneMapping = cases[i].allow;
            int status = -1;
            const GreyRange g = greyRange(path, cfg, status);
            check(status==TP_OK && g.grey && g.lo<=2 && g.hi>=253, cases[i].what);
        }
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
           check(thumb(heif, cfg).meta.fimToneMap==2, "and left alone when not, marked \" (TONE-MAPPABLE)\"");
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
    for (size_t i = 0; i < scalars.size(); i++)
        remove(scalars[i].c_str());

    if (skipped)
       printf("\n  %d test(s) skipped for want of a sample image\n", skipped);
    printf("\n  %s\n", failures ? "FREEIMAGE LOADER TEST FAILED" : "FreeImage loader test passed");
    return failures ? 1 : 0;
}
