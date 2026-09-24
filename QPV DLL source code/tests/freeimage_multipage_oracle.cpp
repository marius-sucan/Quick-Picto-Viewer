// freeimage_multipage_oracle.cpp - the page-by-page join of combineImagesFimMultiPage(),
// replayed against the FreeImage fork QPV ships (github: marius-sucan/FreeImage-library).
//
// NOT part of run-tests.sh: it exercises FreeImage, not qpvmain.dll. Written 2026-09-21 for
// the rewrite that appends every page as soon as it is loaded instead of collecting them all.
//
// Build, with the fork checked out and built next to this repository (static, as the .so
// in Dist carries the soname libfreeimage.so.3 and no link of that name):
//   FI=~/repos/FreeImage-library
//   g++ -O2 freeimage_multipage_oracle.cpp -o freeimage_multipage_oracle -I$FI/Dist -I$FI/Source/LibTIFF4 $FI/Dist/libfreeimage.a -fopenmp -lpthread
//   ./freeimage_multipage_oracle ~/repos/FreeImage-library/TestAPI/exif.jpg
//   ./freeimage_multipage_oracle --tiff ~/repos/FreeImage-library/TestAPI/exif.jpg   (parts 7 and 8 only)
//
// Each prepare step mirrors an AHK function:
//   normalize()      - combineFimImgsAddPage(): tone mapping or ConvertToType() for non-FIT_BITMAP pages
//   convertDepth()   - combineFimImgsConvertDepth()
//   tagPage()        - combineFimImgsAddPage(): metadata models 0-11 and the thumbnail dropped, FrameTime set
//   dropMismatchedICC() - FIMdropMismatchedICC()
// Parts: 1 every source kind x depth x format goes in and reads back with its FrameTime;
// 2 a refused page; 3 the discard on abort; 4 the EXIF WebP and MNG take from the first
// page unless it is dropped; 5 sub-frames of an animation; 6 memory, collected vs streamed;
// 7 (added 2026-09-23) TIFF: every image type reads back as it went in, whatever the depth
// choice, except the ones TIFF cannot store; EXIF thumbnails; the tags libtiff reads, which
// need a fork build from aae78cf on (the TIFF writer's ExtraSamples fix); 8 ICC profiles made
// for another colour space than the page, which the PNG writer refuses.
// The .part renaming and the non-ASCII path handling are Windows-only and not covered.
// written by Marius Șucan with Claude Opus 5

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <time.h>
#include <vector>
#include <string>
#include <stdarg.h>
#include <stddef.h>
#include "FreeImage.h"
#include "tiffio.h"

static int g_fail = 0;
#define CHECK(cond, ...) do { if (!(cond)) { g_fail++; printf("  FAIL: "); printf(__VA_ARGS__); printf("\n"); } } while (0)

static const char *OUT = "freeimage_multipage_out";

static long fileSize(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0) ? (long)st.st_size : -1;
}

static double nowMs() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static void quietMessages(FREE_IMAGE_FORMAT, const char *) {}

// ---- sources: every kind of page the AHK loaders can hand over ----

static FIBITMAP* make24(int w, int h, int seed) {
    FIBITMAP *d = FreeImage_Allocate(w, h, 24);
    for (int y = 0; y < h; y++) {
        BYTE *line = FreeImage_GetScanLine(d, y);
        for (int x = 0; x < w; x++) {
            line[x*3+0] = (BYTE)(x*3 + seed*17);
            line[x*3+1] = (BYTE)(y*5 + seed*31);
            line[x*3+2] = (BYTE)((x+y) ^ (seed*7));
        }
    }
    return d;
}

// photo-like: smooth gradients plus a little noise, so the encoders have work to do
static FIBITMAP* makePhoto(int w, int h, int seed, int bpp) {
    FIBITMAP *d = FreeImage_Allocate(w, h, bpp);
    unsigned r = 12345u + seed * 7919u;
    const int n = bpp / 8;
    for (int y = 0; y < h; y++) {
        BYTE *line = FreeImage_GetScanLine(d, y);
        for (int x = 0; x < w; x++) {
            r = r * 1103515245u + 12345u;
            int noise = (int)((r >> 16) & 7) - 3;
            line[x*n+0] = (BYTE)(((x + seed*9) * 255 / w + noise) & 0xFF);
            line[x*n+1] = (BYTE)(((y + seed*5) * 255 / h + noise) & 0xFF);
            line[x*n+2] = (BYTE)((((x+y) * 128) / (w+h) + seed*3 + noise) & 0xFF);
            if (n == 4) line[x*n+3] = (BYTE)((x < w/4) ? 0 : 255);
        }
    }
    return d;
}

struct Source { const char *name; FIBITMAP *dib; };

static std::vector<Source> makeSources() {
    std::vector<Source> v;
    FIBITMAP *s24 = make24(160, 120, 1);
    v.push_back({"24-bit", s24});
    FIBITMAP *s32 = FreeImage_ConvertTo32Bits(s24);
    for (unsigned y = 0; y < FreeImage_GetHeight(s32); y++) {
        BYTE *line = FreeImage_GetScanLine(s32, y);
        for (unsigned x = 0; x < FreeImage_GetWidth(s32); x++) line[x*4+3] = (BYTE)(x < 40 ? 0 : 255);
    }
    v.push_back({"32-bit alpha", s32});
    FIBITMAP *s8 = FreeImage_ColorQuantize(s24, FIQ_WUQUANT);
    FreeImage_SetTransparentIndex(s8, 3);
    v.push_back({"8-bit palette+tRNS", s8});
    v.push_back({"1-bit", FreeImage_Threshold(s24, 128)});
    v.push_back({"16-bit 555", FreeImage_ConvertTo16Bits555(s24)});
    v.push_back({"RGB16", FreeImage_ConvertToRGB16(s24)});
    v.push_back({"UINT16 grey", FreeImage_ConvertToUINT16(s24)});
    v.push_back({"RGBF", FreeImage_ConvertToRGBF(s24)});
    v.push_back({"24-bit smaller", make24(100, 60, 2)});
    for (size_t i = 0; i < v.size(); i++) {
        if (!v[i].dib) { printf("could not build source %s\n", v[i].name); exit(2); }
    }
    return v;
}

// ---- the AHK pipeline ----

// ConvertToType() has no route from floating point RGB to FIT_BITMAP; those are tone mapped.
// TIFF stores every image type as it is.
static FIBITMAP* normalize(FIBITMAP *k, FREE_IMAGE_FORMAT fif) {
    const FREE_IMAGE_TYPE t = FreeImage_GetImageType(k);
    if (t == FIT_BITMAP || fif == FIF_TIFF) return k;
    FIBITMAP *d = (t == FIT_RGBF || t == FIT_RGBAF) ? FreeImage_ToneMapping(k, FITMO_DRAGO03, 0, 0) : FreeImage_ConvertToType(k, FIT_BITMAP, TRUE);
    FreeImage_Unload(k);
    return d;
}

static FIBITMAP* quantize(FIBITMAP *k) {
    unsigned bpp = FreeImage_GetBPP(k);
    if (bpp == 24 || bpp == 32) return FreeImage_ColorQuantize(k, FIQ_WUQUANT);
    FIBITMAP *d = FreeImage_ConvertTo24Bits(k);
    if (!d) return NULL;
    FIBITMAP *q = FreeImage_ColorQuantize(d, FIQ_WUQUANT);
    FreeImage_Unload(d);
    return q;
}

// combineFimImgsConvertDepth(k, modus, fif): NULL means "k goes in as it is"
static FIBITMAP* convertDepth(FIBITMAP *k, int modus, FREE_IMAGE_FORMAT fif) {
    unsigned bpp = FreeImage_GetBPP(k);
    FIBITMAP *c = NULL;
    if (fif == FIF_GIF) {
        if (bpp == 1 || bpp == 4 || bpp == 8) return NULL;
        return quantize(k);
    }
    if (fif == FIF_TIFF) {
        if (FreeImage_GetImageType(k) != FIT_BITMAP) return NULL;
        // the writer drops the transparency of 1 and 4 bits, and ConvertTo8Bits() drops the table
        if (bpp < 8 && FreeImage_IsTransparent(k)) return FreeImage_ConvertTo32Bits(k);
        return FreeImage_FIFSupportsExportBPP(fif, bpp) ? NULL : FreeImage_ConvertTo24Bits(k);
    }
    if (modus == 1 && bpp != 32) c = FreeImage_ConvertTo32Bits(k);
    else if (modus == 2 && bpp != 24) c = FreeImage_ConvertTo24Bits(k);
    else if (modus == 3 && bpp != 16) c = FreeImage_ConvertTo16Bits555(k);
    else if (modus == 4 && bpp != 8) c = quantize(k);

    FIBITMAP *t = c ? c : k;
    if (!FreeImage_FIFSupportsExportBPP(fif, FreeImage_GetBPP(t))) {
        FIBITMAP *d = FreeImage_ConvertTo24Bits(t);
        if (c) FreeImage_Unload(c);
        c = d;
    }
    return c;
}

static void tagPage(FIBITMAP *k, LONG frameTime, bool strip) {
    if (strip) {
        for (int m = FIMD_COMMENTS; m <= FIMD_EXIF_RAW; m++) FreeImage_SetMetadata((FREE_IMAGE_MDMODEL)m, k, NULL, NULL);
        FreeImage_SetThumbnail(k, NULL);
    } else {
        FreeImage_SetMetadata(FIMD_ANIMATION, k, NULL, NULL);
    }
    FITAG *tag = FreeImage_CreateTag();
    FreeImage_SetTagKey(tag, "FrameTime");
    FreeImage_SetTagType(tag, FIDT_LONG);
    FreeImage_SetTagCount(tag, 1);
    FreeImage_SetTagLength(tag, 4);
    FreeImage_SetTagValue(tag, &frameTime);
    FreeImage_SetMetadata(FIMD_ANIMATION, k, "FrameTime", tag);
    FreeImage_DeleteTag(tag);
}

// combineFimImgsAddPage(): takes ownership of k
// FIMdropMismatchedICC(): the AHK reads the FIICCPROFILE fields at these offsets
static_assert(offsetof(FIICCPROFILE, flags) == 0 && offsetof(FIICCPROFILE, size) == 4 && offsetof(FIICCPROFILE, data) == 8, "FIICCPROFILE layout");

static void dropMismatchedICC(FIBITMAP *k) {
    FIICCPROFILE *p = FreeImage_GetICCProfile(k);
    const unsigned size = p ? p->size : 0;
    const BYTE *data = size ? (const BYTE*)p->data : NULL;
    if (!data) return;
    const char *space = (p->flags & FIICC_COLOR_IS_CMYK) ? "CMYK" : (FreeImage_GetColorType(k) <= FIC_MINISBLACK) ? "GRAY" : "RGB ";
    if (size < 132 || memcmp(data + 16, space, 4) != 0) FreeImage_DestroyICCProfile(k);
}

static BOOL addPage(FIMULTIBITMAP *multi, FIBITMAP *k, FREE_IMAGE_FORMAT fif, int modus, LONG frameTime, bool strip = true, bool dropICC = true) {
    k = normalize(k, fif);
    if (!k) return FALSE;
    FIBITMAP *c = convertDepth(k, modus, fif);
    if (c) { FreeImage_Unload(k); k = c; }
    if (dropICC) dropMismatchedICC(k);
    tagPage(k, frameTime, strip);
    BOOL r = FreeImage_AppendPageEx(multi, k);
    FreeImage_Unload(k);
    return r;
}

static LONG frameTimeOf(FIBITMAP *dib) {
    FITAG *tag = NULL;
    if (FreeImage_GetMetadata(FIMD_ANIMATION, dib, "FrameTime", &tag) && tag && FreeImage_GetTagValue(tag))
        return *(LONG*)FreeImage_GetTagValue(tag);
    return -1;
}

// read the file back as a viewer would: page count and each page's FrameTime
static int verify(const char *path, FREE_IMAGE_FORMAT fif, std::vector<LONG> *times) {
    FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(fif, path, FALSE, TRUE, TRUE, 0);
    if (!m) return -1;
    int n = FreeImage_GetPageCount(m);
    for (int i = 0; times && i < n; i++) {
        FIBITMAP *p = FreeImage_LockPage(m, i);
        times->push_back(p ? frameTimeOf(p) : -2);
        if (p) FreeImage_UnlockPage(m, p, FALSE);
    }
    FreeImage_CloseMultiBitmap(m, 0);
    return n;
}

struct Fmt { FREE_IMAGE_FORMAT fif; const char *ext; };
static const Fmt FMTS[] = { {FIF_APNG, "apng"}, {FIF_GIF, "gif"}, {FIF_WEBP, "webp"}, {FIF_MNG, "mng"} };

// ---- part 1: every source kind x every depth choice, through the new pipeline ----

static void partPipeline(const std::vector<Source>& src) {
    printf("\n== part 1: page by page, every source kind, every depth choice ==\n");
    for (const Fmt& f : FMTS) {
        for (int modus = 1; modus <= 4; modus++) {
            char tmp[256];
            snprintf(tmp, sizeof tmp, "%s/p1-%s-m%d.part", OUT, f.ext, modus);
            unlink(tmp);
            FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(f.fif, tmp, TRUE, FALSE, TRUE, 0);
            CHECK(multi, "%s: OpenMultiBitmap", f.ext);
            if (!multi) continue;
            CHECK(fileSize(tmp) < 0, "%s: a file exists before the close", f.ext);
            int added = 0;
            std::vector<LONG> expect;
            for (size_t i = 0; i < src.size(); i++) {
                LONG ft = 40 + 30 * (LONG)i;
                if (addPage(multi, FreeImage_Clone(src[i].dib), f.fif, modus, ft)) {
                    added++;
                    expect.push_back(ft);
                } else {
                    CHECK(false, "%s m%d: page \"%s\" refused", f.ext, modus, src[i].name);
                }
            }
            BOOL r = FreeImage_CloseMultiBitmap(multi, 0);
            std::vector<LONG> times;
            int n = verify(tmp, f.fif, &times);
            printf("%-4s depth %d: added %d/%zu, close=%d, file %ld bytes, pages read back %d\n",
                   f.ext, modus, added, src.size(), r, fileSize(tmp), n);
            CHECK(r, "%s m%d: close returned FALSE", f.ext, modus);
            CHECK(n == added, "%s m%d: %d pages in the file, %d added", f.ext, modus, n, added);
            for (int i = 0; i < n && i < (int)expect.size(); i++) {
                LONG want = (f.fif == FIF_GIF) ? (expect[i] / 10) * 10 : expect[i];
                CHECK(times[i] == want, "%s m%d page %d: FrameTime %ld, expected %ld", f.ext, modus, i, (long)times[i], (long)want);
            }
        }
    }
}

// ---- part 2: a page the format refuses ----
// FreeImage_CloseMultiBitmap() then returns FALSE over a file that holds every other page,
// which is why the AHK decides by the pages it reads back from the file.

static void partRefusedPage() {
    printf("\n== part 2: one page the format cannot hold ==\n");
    char tmp[256];
    snprintf(tmp, sizeof tmp, "%s/p2-mixed.webp.part", OUT);
    unlink(tmp);
    FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(FIF_WEBP, tmp, TRUE, FALSE, TRUE, 0);
    FIBITMAP *good = make24(64, 64, 3), *bad = FreeImage_ColorQuantize(good, FIQ_WUQUANT);
    BOOL a = FreeImage_AppendPageEx(multi, good), b = FreeImage_AppendPageEx(multi, bad), c = FreeImage_AppendPageEx(multi, good);
    BOOL closed = FreeImage_CloseMultiBitmap(multi, 0);
    int n = verify(tmp, FIF_WEBP, NULL);
    printf("webp with one 8-bit page: appends %d/%d/%d, close=%d, file %ld bytes holding %d pages\n", a, b, c, closed, fileSize(tmp), n);
    CHECK(a && !b && c && !closed && n == 2, "expected close=0 over a written 2-page file");
    FreeImage_Unload(good);
    FreeImage_Unload(bad);
}

// ---- part 3: abandoning a session cheaply ----
// What the AHK does on an abort, or with fewer than two pages: delete every page but the
// last, which FreeImage refuses to delete, so that the close encodes one page instead of all.

static void partAbort() {
    printf("\n== part 3: discarding the pages before the close ==\n");
    for (const Fmt& f : FMTS) {
        char tmp[256];
        snprintf(tmp, sizeof tmp, "%s/p3-%s.part", OUT, f.ext);
        unlink(tmp);
        FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(f.fif, tmp, TRUE, FALSE, TRUE, 0);
        const int pages = 12;
        for (int i = 0; i < pages; i++) addPage(multi, makePhoto(640, 480, i, 24), f.fif, 2, 100);
        int count = FreeImage_GetPageCount(multi);
        double t0 = nowMs();
        int deleted = 0;
        for (int i = 0; i < count - 1; i++) deleted += FreeImage_DeletePageEx(multi, 0) ? 1 : 0;
        BOOL closed = FreeImage_CloseMultiBitmap(multi, 0);
        double t1 = nowMs();
        int left = verify(tmp, f.fif, NULL);
        printf("%-4s: %d pages, deleted %d, close=%d in %.1f ms, leftover file %ld bytes with %d page(s)\n",
               f.ext, count, deleted, closed, t1 - t0, fileSize(tmp), left);
        CHECK(count == pages && deleted == pages - 1 && closed && left == 1, "%s: discard", f.ext);
        unlink(tmp);
    }

    // the last page stays: a delete of it is refused, and it poisons the close result
    char tmp[256];
    snprintf(tmp, sizeof tmp, "%s/p3-last.part", OUT);
    unlink(tmp);
    FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(FIF_GIF, tmp, TRUE, FALSE, TRUE, 0);
    addPage(multi, make24(32, 32, 1), FIF_GIF, 4, 100);
    BOOL lastOne = FreeImage_DeletePageEx(multi, 0);
    BOOL closed = FreeImage_CloseMultiBitmap(multi, 0);
    printf("deleting the only page: %s, then close=%d\n", lastOne ? "ALLOWED" : "refused", closed);
    CHECK(!lastOne && !closed, "the last page is kept and the close reports the refused delete");
    unlink(tmp);
}

// ---- part 4: what a source's metadata does to the file ----

static bool fileHasExif(const char *path, FREE_IMAGE_FORMAT fif) {
    FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(fif, path, FALSE, TRUE, TRUE, 0);
    if (!m) return false;
    FIBITMAP *p = FreeImage_LockPage(m, 0);
    bool has = p && (FreeImage_GetMetadataCount(FIMD_EXIF_RAW, p) > 0 || FreeImage_GetMetadataCount(FIMD_EXIF_MAIN, p) > 0);
    if (p) FreeImage_UnlockPage(m, p, FALSE);
    FreeImage_CloseMultiBitmap(m, 0);
    return has;
}

static void partMetadata(const char *jpegPath) {
    printf("\n== part 4: EXIF of the first source, with and without the strip ==\n");
    FIBITMAP *j = FreeImage_Load(FIF_JPEG, jpegPath, JPEG_EXIFROTATE);
    if (!j) { printf("skipped: cannot load %s\n", jpegPath); return; }
    FITAG *tag = NULL;
    FreeImage_GetMetadata(FIMD_EXIF_MAIN, j, "Orientation", &tag);
    printf("source %s: %ux%u, EXIF raw %s, Orientation %d\n", jpegPath, FreeImage_GetWidth(j), FreeImage_GetHeight(j),
           FreeImage_GetMetadataCount(FIMD_EXIF_RAW, j) ? "present" : "absent", tag ? (int)*(WORD*)FreeImage_GetTagValue(tag) : 0);
    for (int strip = 0; strip <= 1; strip++) {
        for (const Fmt& f : FMTS) {
            char tmp[256];
            snprintf(tmp, sizeof tmp, "%s/p4-%s-strip%d.part", OUT, f.ext, strip);
            unlink(tmp);
            FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(f.fif, tmp, TRUE, FALSE, TRUE, 0);
            addPage(multi, FreeImage_Clone(j), f.fif, 2, 100, strip == 1);
            addPage(multi, FreeImage_Clone(j), f.fif, 2, 100, strip == 1);
            FreeImage_CloseMultiBitmap(multi, 0);
            bool has = fileHasExif(tmp, f.fif);
            printf("%-4s %s: EXIF in the file %s\n", f.ext, strip ? "stripped" : "as loaded", has ? "YES" : "no");
            if (strip) CHECK(!has, "%s: EXIF survived the strip", f.ext);
        }
    }
    FreeImage_Unload(j);
}

// ---- part 5: sub-frames of an animation, locked one at a time ----

static void partSubFrames() {
    printf("\n== part 5: a GIF played back (GIF_PLAYBACK) and joined page by page ==\n");
    char gif[256], out[256];
    snprintf(gif, sizeof gif, "%s/p5-source.gif", OUT);
    snprintf(out, sizeof out, "%s/p5-out.apng.part", OUT);
    unlink(gif);
    unlink(out);
    FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(FIF_GIF, gif, TRUE, FALSE, TRUE, 0);
    for (int i = 0; i < 7; i++) addPage(m, make24(120, 90, i), FIF_GIF, 4, 70);
    FreeImage_CloseMultiBitmap(m, 0);

    FIMULTIBITMAP *srcm = FreeImage_OpenMultiBitmap(FIF_GIF, gif, FALSE, TRUE, TRUE, GIF_PLAYBACK);
    int pages = srcm ? FreeImage_GetPageCount(srcm) : 0;
    FIMULTIBITMAP *dst = FreeImage_OpenMultiBitmap(FIF_APNG, out, TRUE, FALSE, TRUE, 0);
    int added = 0;
    unsigned bpp = 0;
    for (int i = 0; i < pages; i++) {
        FIBITMAP *p = FreeImage_LockPage(srcm, i);
        FIBITMAP *c = p ? FreeImage_Clone(p) : NULL;
        if (p) { bpp = FreeImage_GetBPP(p); FreeImage_UnlockPage(srcm, p, FALSE); }
        if (c && addPage(dst, c, FIF_APNG, 1, 55)) added++;
    }
    FreeImage_CloseMultiBitmap(srcm, 0);
    FreeImage_CloseMultiBitmap(dst, 0);
    int n = verify(out, FIF_APNG, NULL);
    printf("source pages %d (%u bpp as played), added %d, APNG holds %d\n", pages, bpp, added, n);
    CHECK(pages == 7 && added == 7 && n == 7, "sub-frame join");
}

// ---- part 6: peak memory, collecting every page first vs appending as loaded ----
// Each case runs in a process of its own, started with exec: a forked child would inherit
// the parent's peak resident size, and ru_maxrss can only grow.

static long peakKB() {
    struct rusage ru;
    getrusage(RUSAGE_SELF, &ru);
    return ru.ru_maxrss;
}

static int memoryCase(const Fmt& f, bool stream, int frames, int w, int h) {
    char tmp[256];
    snprintf(tmp, sizeof tmp, "%s/p6-%s-%d.part", OUT, f.ext, stream ? 1 : 0);
    unlink(tmp);
    long base = peakKB();
    double t0 = nowMs();
    FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(f.fif, tmp, TRUE, FALSE, TRUE, 0);
    if (stream) {
        for (int i = 0; i < frames; i++) addPage(multi, makePhoto(w, h, i, 32), f.fif, 1, 100);
    } else {
        // the old two phases: every page prepared and kept, then appended
        std::vector<FIBITMAP*> list;
        for (int i = 0; i < frames; i++) {
            FIBITMAP *k = makePhoto(w, h, i, 32);
            FIBITMAP *c = convertDepth(k, 1, f.fif);
            if (c) { FreeImage_Unload(k); k = c; }
            list.push_back(k);
        }
        for (FIBITMAP *k : list) {
            tagPage(k, 100, true);
            FreeImage_AppendPageEx(multi, k);
            FreeImage_Unload(k);
        }
    }
    double t1 = nowMs();
    long beforeClose = peakKB();
    FreeImage_CloseMultiBitmap(multi, 0);
    double t2 = nowMs();
    int n = verify(tmp, f.fif, NULL);
    printf("%-4s %-9s %3d x %dx%d: peak while adding %5ld MB, after the close %5ld MB, file %6.1f MB (%d pages), add %6.0f ms, close %6.0f ms\n",
           f.ext, stream ? "streamed" : "collected", frames, w, h, (beforeClose - base) / 1024, (peakKB() - base) / 1024,
           fileSize(tmp) / 1048576.0, n, t1 - t0, t2 - t1);
    unlink(tmp);
    return (n == frames) ? 0 : 1;
}

static void partMemory(const char *self) {
    printf("\n== part 6: peak resident memory, 32-bit photo-like frames ==\n");
    for (int fi = 0; fi < 4; fi++) {
        const int frames = (FMTS[fi].fif == FIF_WEBP) ? 8 : 40;
        for (int stream = 0; stream <= 1; stream++) {
            char a1[8], a2[8], a3[8];
            snprintf(a1, sizeof a1, "%d", fi);
            snprintf(a2, sizeof a2, "%d", stream);
            snprintf(a3, sizeof a3, "%d", frames);
            fflush(stdout);
            pid_t pid = fork();
            if (pid == 0) {
                execl(self, self, "--mem", a1, a2, a3, (char*)NULL);
                _exit(3);
            }
            int st = 0;
            waitpid(pid, &st, 0);
            CHECK(WIFEXITED(st) && WEXITSTATUS(st) == 0, "memory case %s/%d", FMTS[fi].ext, stream);
        }
    }
}

// ---- part 7: TIFF keeps every page as it is, unless TIFF cannot store it ----
// Not in FMTS: TIFF stores no FrameTime, and it takes pages part 1 expects to be converted.

enum Want { SAME, TO24, TO32 };
struct TiffSource { const char *name; FIBITMAP *dib; Want want; };

static FIBITMAP* makeIndexed(int bpp, int w, int h, bool colour) {
    FIBITMAP *d = FreeImage_Allocate(w, h, bpp);
    const int n = 1 << bpp;
    RGBQUAD *pal = FreeImage_GetPalette(d);
    for (int i = 0; i < n; i++) {
        pal[i].rgbRed = (BYTE)(colour ? i * 97 + 30 : i * 255 / (n - 1));
        pal[i].rgbGreen = (BYTE)(colour ? i * 53 + 90 : i * 255 / (n - 1));
        pal[i].rgbBlue = (BYTE)(colour ? 200 - i * 31 : i * 255 / (n - 1));
    }
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            BYTE v = (BYTE)((x / 7 + y / 5) % n);
            FreeImage_SetPixelIndex(d, x, y, &v);
        }
    }
    return d;
}

static FIBITMAP* withTrns(FIBITMAP *d) {
    const int n = (int)FreeImage_GetColorsUsed(d);
    BYTE t[256];
    for (int i = 0; i < n; i++) t[i] = (BYTE)((i % 3 == 0) ? 0 : (i % 3 == 1) ? 128 : 255);
    FreeImage_SetTransparencyTable(d, t, n);
    return d;
}

static std::vector<TiffSource> makeTiffSources() {
    std::vector<TiffSource> v;
    const int w = 96, h = 64;
    FIBITMAP *s24 = make24(w, h, 5);
    FIBITMAP *s32 = FreeImage_ConvertTo32Bits(s24);
    for (int y = 0; y < h; y++) {
        BYTE *line = FreeImage_GetScanLine(s32, y);
        for (int x = 0; x < w; x++) line[x*4+3] = (BYTE)(x * 2 + y);
    }
    FIBITMAP *grey = FreeImage_ConvertToGreyscale(s24);
    FIBITMAP *pal8 = FreeImage_ColorQuantize(s24, FIQ_WUQUANT);

    v.push_back({"1-bit black/white", makeIndexed(1, w, h, false), SAME});
    v.push_back({"1-bit two colours", makeIndexed(1, w, h, true), SAME});
    v.push_back({"4-bit palette", makeIndexed(4, w, h, true), SAME});
    v.push_back({"8-bit palette", FreeImage_Clone(pal8), SAME});
    v.push_back({"8-bit grey", FreeImage_Clone(grey), SAME});
    v.push_back({"1-bit+tRNS", withTrns(makeIndexed(1, w, h, true)), TO32});
    v.push_back({"4-bit+tRNS", withTrns(makeIndexed(4, w, h, true)), TO32});
    v.push_back({"8-bit palette+tRNS", withTrns(FreeImage_Clone(pal8)), SAME});
    v.push_back({"8-bit grey+tRNS", withTrns(FreeImage_Clone(grey)), SAME});
    v.push_back({"16-bit 555", FreeImage_ConvertTo16Bits555(s24), TO24});
    v.push_back({"16-bit 565", FreeImage_ConvertTo16Bits565(s24), TO24});
    v.push_back({"24-bit", FreeImage_Clone(s24), SAME});
    v.push_back({"32-bit opaque", FreeImage_ConvertTo32Bits(s24), SAME});
    v.push_back({"32-bit alpha", FreeImage_Clone(s32), SAME});
    v.push_back({"UINT16", FreeImage_ConvertToUINT16(s24), SAME});
    v.push_back({"INT16", FreeImage_ConvertToType(grey, FIT_INT16, TRUE), SAME});
    v.push_back({"UINT32", FreeImage_ConvertToType(grey, FIT_UINT32, TRUE), SAME});
    v.push_back({"INT32", FreeImage_ConvertToType(grey, FIT_INT32, TRUE), SAME});
    v.push_back({"FLOAT", FreeImage_ConvertToFloat(s24), SAME});
    v.push_back({"DOUBLE", FreeImage_ConvertToType(grey, FIT_DOUBLE, TRUE), SAME});
    v.push_back({"COMPLEX", FreeImage_ConvertToType(grey, FIT_COMPLEX, TRUE), SAME});
    v.push_back({"RGB16", FreeImage_ConvertToRGB16(s24), SAME});
    v.push_back({"RGBA16", FreeImage_ConvertToRGBA16(s32), SAME});
    v.push_back({"RGBF", FreeImage_ConvertToRGBF(s24), SAME});
    v.push_back({"RGBAF", FreeImage_ConvertToRGBAF(s32), SAME});

    FIBITMAP *icc = FreeImage_Clone(s24);
    BYTE blob[256];
    for (int i = 0; i < 256; i++) blob[i] = (BYTE)(i * 7);
    memcpy(blob + 16, "RGB ", 4);
    FreeImage_CreateICCProfile(icc, blob, sizeof blob);
    FreeImage_SetDotsPerMeterX(icc, 11811);   // 300 DPI
    FreeImage_SetDotsPerMeterY(icc, 11811);
    v.push_back({"24-bit ICC 300 DPI", icc, SAME});

    FreeImage_Unload(s24);
    FreeImage_Unload(s32);
    FreeImage_Unload(grey);
    FreeImage_Unload(pal8);
    for (size_t i = 0; i < v.size(); i++) {
        if (!v[i].dib) { printf("could not build TIFF source %s\n", v[i].name); exit(2); }
    }
    return v;
}

static FIBITMAP* expectedPage(const TiffSource& s) {
    return (s.want == TO24) ? FreeImage_ConvertTo24Bits(s.dib) : (s.want == TO32) ? FreeImage_ConvertTo32Bits(s.dib) : FreeImage_Clone(s.dib);
}

// type, depth, colour type, transparency, resolution, ICC profile and every pixel
static bool samePage(FIBITMAP *a, FIBITMAP *b, char *why, size_t n) {
    const FREE_IMAGE_TYPE t = FreeImage_GetImageType(a);
    const unsigned w = FreeImage_GetWidth(a), h = FreeImage_GetHeight(a);
    if (t != FreeImage_GetImageType(b) || FreeImage_GetBPP(a) != FreeImage_GetBPP(b)) {
        snprintf(why, n, "type %d at %u bpp, expected type %d at %u bpp", FreeImage_GetImageType(b), FreeImage_GetBPP(b), t, FreeImage_GetBPP(a));
        return false;
    }
    if (w != FreeImage_GetWidth(b) || h != FreeImage_GetHeight(b)) {
        snprintf(why, n, "%ux%u, expected %ux%u", FreeImage_GetWidth(b), FreeImage_GetHeight(b), w, h);
        return false;
    }
    if (FreeImage_GetColorType(a) != FreeImage_GetColorType(b) || FreeImage_IsTransparent(a) != FreeImage_IsTransparent(b)) {
        snprintf(why, n, "colour type %d transparent %d, expected %d and %d", FreeImage_GetColorType(b), FreeImage_IsTransparent(b), FreeImage_GetColorType(a), FreeImage_IsTransparent(a));
        return false;
    }
    if (FreeImage_GetDotsPerMeterX(a) != FreeImage_GetDotsPerMeterX(b) || FreeImage_GetDotsPerMeterY(a) != FreeImage_GetDotsPerMeterY(b)) {
        snprintf(why, n, "%u dots per metre, expected %u", FreeImage_GetDotsPerMeterX(b), FreeImage_GetDotsPerMeterX(a));
        return false;
    }
    const FIICCPROFILE *ia = FreeImage_GetICCProfile(a), *ib = FreeImage_GetICCProfile(b);
    if (ia->size != ib->size || (ia->size && memcmp(ia->data, ib->data, ia->size) != 0)) {
        snprintf(why, n, "ICC profile of %u bytes, expected %u", (unsigned)ib->size, (unsigned)ia->size);
        return false;
    }
    FIBITMAP *x = (t == FIT_BITMAP) ? FreeImage_ConvertTo32Bits(a) : a;
    FIBITMAP *y = (t == FIT_BITMAP) ? FreeImage_ConvertTo32Bits(b) : b;
    const unsigned bytes = (t == FIT_BITMAP) ? w * 4 : FreeImage_GetLine(a);
    bool same = true;
    for (unsigned r = 0; r < h && same; r++) same = memcmp(FreeImage_GetScanLine(x, r), FreeImage_GetScanLine(y, r), bytes) == 0;
    if (t == FIT_BITMAP) {
        FreeImage_Unload(x);
        FreeImage_Unload(y);
    }
    if (!same) snprintf(why, n, "pixels differ");
    return same;
}

struct TiffDir { uint16_t spp, bps, photo, comp, fmt, extra, extraType; bool subifd; int warnings; };

static std::string g_tiffWarnings;
static int g_tiffWarned = 0;

static void collectTiffWarning(const char *module, const char *fmt, va_list ap) {
    char buf[512];
    vsnprintf(buf, sizeof buf, fmt, ap);
    g_tiffWarnings += std::string("    libtiff: ") + buf + "\n";
    g_tiffWarned++;
}

// FreeImage stubs TIFFOpen() out, so the file goes through TIFFClientOpen()
static tmsize_t stdioRead(thandle_t h, void *buf, tmsize_t n) { return (tmsize_t)fread(buf, 1, (size_t)n, (FILE*)h); }
static tmsize_t stdioWrite(thandle_t, void*, tmsize_t) { return 0; }
static toff_t stdioSeek(thandle_t h, toff_t off, int whence) { return fseeko((FILE*)h, (off_t)off, whence) == 0 ? (toff_t)ftello((FILE*)h) : (toff_t)-1; }
static int stdioClose(thandle_t) { return 0; }
static toff_t stdioSize(thandle_t h) {
    const off_t at = ftello((FILE*)h);
    fseeko((FILE*)h, 0, SEEK_END);
    const off_t size = ftello((FILE*)h);
    fseeko((FILE*)h, at, SEEK_SET);
    return (toff_t)size;
}
static int stdioMap(thandle_t, void**, toff_t*) { return 0; }
static void stdioUnmap(thandle_t, void*, toff_t) {}

// the tags as libtiff reads them; libtiff invents the ExtraSamples a file leaves out, and warns
static std::vector<TiffDir> readTiffDirs(const char *path) {
    std::vector<TiffDir> v;
    FILE *f = fopen(path, "rb");
    if (!f) return v;
    TIFFErrorHandler old = TIFFSetWarningHandler(collectTiffWarning);
    g_tiffWarned = 0;
    TIFF *t = TIFFClientOpen(path, "r", (thandle_t)f, stdioRead, stdioWrite, stdioSeek, stdioClose, stdioSize, stdioMap, stdioUnmap);
    if (t) {
        do {
            // the warnings of a directory come while TIFFReadDirectory() reads it
            TiffDir d = {};
            d.warnings = g_tiffWarned;
            g_tiffWarned = 0;
            TIFFGetFieldDefaulted(t, TIFFTAG_SAMPLESPERPIXEL, &d.spp);
            TIFFGetFieldDefaulted(t, TIFFTAG_BITSPERSAMPLE, &d.bps);
            TIFFGetField(t, TIFFTAG_PHOTOMETRIC, &d.photo);
            TIFFGetFieldDefaulted(t, TIFFTAG_COMPRESSION, &d.comp);
            TIFFGetFieldDefaulted(t, TIFFTAG_SAMPLEFORMAT, &d.fmt);
            uint16_t count = 0, *types = NULL;
            if (TIFFGetField(t, TIFFTAG_EXTRASAMPLES, &count, &types) && count) {
                d.extra = count;
                d.extraType = types[0];
            }
            uint16_t subs = 0;
            uint64_t *offsets = NULL;
            d.subifd = TIFFGetField(t, TIFFTAG_SUBIFD, &subs, &offsets) && subs > 0;
            v.push_back(d);
        } while (TIFFReadDirectory(t));
        TIFFClose(t);
    }
    TIFFSetWarningHandler(old);
    fclose(f);
    return v;
}

static void printTiffDir(const char *name, const TiffDir& d) {
    printf("    %-20s spp %u bps %3u photometric %u compression %u sampleformat %u extrasamples %u (type %u)%s%s\n",
           name, d.spp, d.bps, d.photo, d.comp, d.fmt, d.extra, d.extraType, d.subifd ? " SubIFD" : "", d.warnings ? " WARNED" : "");
}

// every page of the file against what it should hold
static void verifyTiff(const char *path, const std::vector<TiffSource>& src, const char *label) {
    FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(FIF_TIFF, path, FALSE, TRUE, TRUE, 0);
    CHECK(m, "%s: the file does not open", label);
    if (!m) return;
    const int n = FreeImage_GetPageCount(m);
    CHECK(n == (int)src.size(), "%s: %d pages, expected %zu", label, n, src.size());
    for (int i = 0; i < n && i < (int)src.size(); i++) {
        FIBITMAP *p = FreeImage_LockPage(m, i);
        CHECK(p, "%s page %d: cannot be read", label, i);
        if (!p) continue;
        FIBITMAP *want = expectedPage(src[i]);
        char why[160] = "";
        CHECK(samePage(want, p, why, sizeof why), "%s page %d \"%s\": %s", label, i, src[i].name, why);
        CHECK(!FreeImage_GetThumbnail(p), "%s page %d \"%s\": has a thumbnail", label, i, src[i].name);
        FreeImage_Unload(want);
        FreeImage_UnlockPage(m, p, FALSE);
    }
    FreeImage_CloseMultiBitmap(m, 0);
}

static void partTiff(const char *jpegPath) {
    printf("\n== part 7: TIFF, every image type as it is ==\n");
    std::vector<TiffSource> src = makeTiffSources();
    char first[256] = "";
    for (int modus = 1; modus <= 4; modus++) {
        char tmp[256];
        snprintf(tmp, sizeof tmp, "%s/p7-tiff-m%d.part", OUT, modus);
        unlink(tmp);
        FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(FIF_TIFF, tmp, TRUE, FALSE, TRUE, 0);
        CHECK(multi, "tiff: OpenMultiBitmap");
        if (!multi) return;
        int added = 0;
        for (size_t i = 0; i < src.size(); i++) {
            if (addPage(multi, FreeImage_Clone(src[i].dib), FIF_TIFF, modus, 100)) added++;
            else CHECK(false, "tiff m%d: page \"%s\" refused", modus, src[i].name);
        }
        BOOL r = FreeImage_CloseMultiBitmap(multi, 0);
        printf("tiff depth %d: added %d/%zu, close=%d, file %ld bytes\n", modus, added, src.size(), r, fileSize(tmp));
        CHECK(r, "tiff m%d: close returned FALSE", modus);
        char label[32];
        snprintf(label, sizeof label, "tiff m%d", modus);
        verifyTiff(tmp, src, label);
        if (modus == 1) {
            snprintf(first, sizeof first, "%s", tmp);
            std::vector<TiffDir> dirs = readTiffDirs(tmp);
            CHECK(dirs.size() == src.size(), "tiff: libtiff reads %zu directories", dirs.size());
            for (size_t i = 0; i < dirs.size() && i < src.size(); i++) {
                printTiffDir(src[i].name, dirs[i]);
                CHECK(!dirs[i].warnings, "tiff: libtiff warned about \"%s\"", src[i].name);
                // 8-bit + alpha and RGBAF pages carry the tag since the fork's aae78cf
                const bool alpha = (dirs[i].spp == 2) || (dirs[i].spp == 4 && dirs[i].photo == PHOTOMETRIC_RGB);
                CHECK(!alpha || (dirs[i].extra == 1 && dirs[i].extraType == EXTRASAMPLE_UNASSALPHA), "tiff: \"%s\" does not mark its alpha", src[i].name);
                CHECK(!dirs[i].subifd, "tiff: \"%s\" has a SubIFD", src[i].name);
                CHECK(dirs[i].comp == ((dirs[i].bps == 1) ? COMPRESSION_CCITTFAX4 : COMPRESSION_LZW), "tiff: \"%s\" compression %u", src[i].name, dirs[i].comp);
            }
            printf("%s", g_tiffWarnings.c_str());
            g_tiffWarnings.clear();
        }
    }

    // the pages of a TIFF, locked one at a time as combineFimOpenPages() reads them, go in unchanged
    char again[256];
    snprintf(again, sizeof again, "%s/p7-tiff-from-tiff.part", OUT);
    unlink(again);
    FIMULTIBITMAP *srcm = FreeImage_OpenMultiBitmap(FIF_TIFF, first, FALSE, TRUE, TRUE, 0);
    FIMULTIBITMAP *dst = FreeImage_OpenMultiBitmap(FIF_TIFF, again, TRUE, FALSE, TRUE, 0);
    const int pages = srcm ? FreeImage_GetPageCount(srcm) : 0;
    for (int i = 0; i < pages; i++) {
        FIBITMAP *p = FreeImage_LockPage(srcm, i);
        FIBITMAP *c = p ? FreeImage_Clone(p) : NULL;
        if (p) FreeImage_UnlockPage(srcm, p, FALSE);
        CHECK(c && addPage(dst, c, FIF_TIFF, 2, 100), "tiff from tiff: page %d", i);
    }
    FreeImage_CloseMultiBitmap(srcm, 0);
    FreeImage_CloseMultiBitmap(dst, 0);
    printf("a TIFF of %d pages joined page by page into another\n", pages);
    verifyTiff(again, src, "tiff from tiff");

    // an EXIF thumbnail: TIFF stores it as a SubIFD of the page, unless it is dropped
    FIBITMAP *j = FreeImage_Load(FIF_JPEG, jpegPath, JPEG_EXIFROTATE);
    if (!j) {
        printf("skipped the thumbnail check: cannot load %s\n", jpegPath);
    } else {
        FIBITMAP *th = FreeImage_GetThumbnail(j);
        printf("%s: thumbnail %s\n", jpegPath, th ? "present" : "absent");
        CHECK(th, "the JPEG has no thumbnail, so the check below proves nothing");
        for (int strip = 0; strip <= 1; strip++) {
            char tmp[256];
            snprintf(tmp, sizeof tmp, "%s/p7-thumb-strip%d.part", OUT, strip);
            unlink(tmp);
            FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(FIF_TIFF, tmp, TRUE, FALSE, TRUE, 0);
            addPage(multi, FreeImage_Clone(j), FIF_TIFF, 2, 100, strip == 1);
            addPage(multi, FreeImage_Clone(j), FIF_TIFF, 2, 100, strip == 1);
            FreeImage_CloseMultiBitmap(multi, 0);
            FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(FIF_TIFF, tmp, FALSE, TRUE, TRUE, 0);
            FIBITMAP *p = m ? FreeImage_LockPage(m, 1) : NULL;
            const bool has = p && FreeImage_GetThumbnail(p);
            const int n = m ? FreeImage_GetPageCount(m) : -1;
            if (p) FreeImage_UnlockPage(m, p, FALSE);
            if (m) FreeImage_CloseMultiBitmap(m, 0);
            std::vector<TiffDir> dirs = readTiffDirs(tmp);
            printf("%s: %d pages, thumbnail read back %s, SubIFD tags %d/%zu\n", strip ? "dropped" : "as loaded", n,
                   has ? "YES" : "no", (int)(dirs.size() > 1 && dirs[0].subifd) + (int)(dirs.size() > 1 && dirs[1].subifd), dirs.size());
            CHECK(n == 2, "thumbnail case: %d pages", n);
            CHECK(strip ? !has : has, "thumbnail %s", strip ? "survived the drop" : "not written, the check is dead");
        }
        FreeImage_Unload(j);
    }

    // «Set dimensions»: qpvmain.dll's OpenCV resize takes 24/32/48/64/96/128 bits, the rest
    // falls to FreeImage_Rescale(); combineFimImgsAddPage() does not resize the BLANK ones
    printf("-- FreeImage_Rescale() of the types OpenCV refuses --\n");
    for (size_t i = 0; i < src.size(); i++) {
        const FREE_IMAGE_TYPE t = FreeImage_GetImageType(src[i].dib);
        if (t == FIT_BITMAP || t >= FIT_RGB16) continue;
        FIBITMAP *r = FreeImage_Rescale(src[i].dib, 48, 32, FILTER_BSPLINE);
        bool blank = true;
        for (unsigned y = 0; r && blank && y < FreeImage_GetHeight(r); y++) {
            const BYTE *line = FreeImage_GetScanLine(r, y);
            for (unsigned x = 0; blank && x < FreeImage_GetLine(r); x++) blank = (line[x] == 0);
        }
        printf("    %-20s %s\n", src[i].name, !r ? "refused" : blank ? "BLANK" : "resized");
        if (r) FreeImage_Unload(r);
    }

    // what the writer does with the pages the pipeline converts first
    printf("-- raw, no conversion --\n");
    char raw[256];
    snprintf(raw, sizeof raw, "%s/p7-tiff-raw.part", OUT);
    unlink(raw);
    FIMULTIBITMAP *multi = FreeImage_OpenMultiBitmap(FIF_TIFF, raw, TRUE, FALSE, TRUE, 0);
    std::vector<size_t> rawIdx;
    for (size_t i = 0; i < src.size(); i++) {
        if (src[i].want != TO32) continue;
        BOOL a = FreeImage_AppendPageEx(multi, src[i].dib);
        printf("    %-20s append %d\n", src[i].name, a);
        if (a) rawIdx.push_back(i);
    }
    BOOL closed = FreeImage_CloseMultiBitmap(multi, 0);
    FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(FIF_TIFF, raw, FALSE, TRUE, TRUE, 0);
    const int n = m ? FreeImage_GetPageCount(m) : -1;
    printf("    close=%d, %d pages\n", closed, n);
    for (int i = 0; i < n && i < (int)rawIdx.size(); i++) {
        FIBITMAP *p = FreeImage_LockPage(m, i);
        const TiffSource& s = src[rawIdx[i]];
        char why[160] = "";
        FIBITMAP *want = FreeImage_Clone(s.dib);
        const bool same = p && samePage(want, p, why, sizeof why);
        printf("    %-20s read back %u bpp, colour type %d, transparent %d: %s\n", s.name, p ? FreeImage_GetBPP(p) : 0,
               p ? FreeImage_GetColorType(p) : -1, p ? FreeImage_IsTransparent(p) : -1, same ? "same" : why);
        FreeImage_Unload(want);
        if (p) FreeImage_UnlockPage(m, p, FALSE);
    }
    if (m) FreeImage_CloseMultiBitmap(m, 0);
    std::vector<TiffDir> dirs = readTiffDirs(raw);
    for (size_t i = 0; i < dirs.size() && i < rawIdx.size(); i++) printTiffDir(src[rawIdx[i]].name, dirs[i]);
    printf("%s", g_tiffWarnings.c_str());
    g_tiffWarnings.clear();

    char r555[256];
    snprintf(r555, sizeof r555, "%s/p7-tiff-555.part", OUT);
    unlink(r555);
    multi = FreeImage_OpenMultiBitmap(FIF_TIFF, r555, TRUE, FALSE, TRUE, 0);
    FIBITMAP *s555 = FreeImage_ConvertTo16Bits555(src[0].dib);
    FIBITMAP *s24 = FreeImage_ConvertTo24Bits(src[3].dib);
    BOOL a1 = FreeImage_AppendPageEx(multi, s24), a2 = FreeImage_AppendPageEx(multi, s555), a3 = FreeImage_AppendPageEx(multi, s24);
    closed = FreeImage_CloseMultiBitmap(multi, 0);
    printf("    a 555 page between two 24-bit ones: appends %d/%d/%d, close=%d, %d pages in the file\n", a1, a2, a3, closed, verify(r555, FIF_TIFF, NULL));
    CHECK(a1 && !a2 && a3, "the 555 page should be refused by this build");
    FreeImage_Unload(s555);
    FreeImage_Unload(s24);

    for (size_t i = 0; i < src.size(); i++) FreeImage_Unload(src[i].dib);
}

// ---- part 8: an ICC profile made for another colour space than the page ----
// FreeImage builds older than the fork's cd91101 leave the CMYK profile of a CMYK JPEG on
// the RGB pixels they load: a PNG save and the MNG writer refuse such a page, TIFF embeds it.
// APNG does not: it converts its frames to 32 bits, which drops the profile.

// a header libpng accepts in every field but, where it does not fit, the colour space
static void attachProfile(FIBITMAP *d, const char *space, unsigned size) {
    static const BYTE d50[12] = {0, 0, 0xF6, 0xD6, 0, 1, 0, 0, 0, 0, 0xD3, 0x2D};
    std::vector<BYTE> icc(size, 0);
    icc[0] = (BYTE)(size >> 24);
    icc[1] = (BYTE)(size >> 16);
    icc[2] = (BYTE)(size >> 8);
    icc[3] = (BYTE)size;
    if (size >= 20) memcpy(&icc[16], space, 4);
    if (size >= 132) {
        icc[8] = 2;
        icc[9] = 0x10;
        memcpy(&icc[12], "mntr", 4);
        memcpy(&icc[20], "XYZ ", 4);
        memcpy(&icc[36], "acsp", 4);
        memcpy(&icc[68], d50, sizeof d50);
    }
    FreeImage_CreateICCProfile(d, icc.data(), (long)size);
}

struct IccCase { const char *name; FIBITMAP *dib; bool keep; };

static void partICC() {
    printf("\n== part 8: ICC profiles made for another colour space than the page ==\n");
    FIBITMAP *s24 = make24(64, 48, 3);
    FIBITMAP *grey = FreeImage_ConvertToGreyscale(s24);
    FIBITMAP *pal = FreeImage_ColorQuantize(s24, FIQ_WUQUANT);
    std::vector<IccCase> cases;
    auto add = [&](const char *n, FIBITMAP *d, const char *space, unsigned size, bool keep) {
        attachProfile(d, space, size);
        cases.push_back({n, d, keep});
    };
    add("24-bit + CMYK", FreeImage_Clone(s24), "CMYK", 1024, false);
    add("24-bit + RGB", FreeImage_Clone(s24), "RGB ", 1024, true);
    add("24-bit + short RGB", FreeImage_Clone(s24), "RGB ", 100, false);
    add("8-bit grey + RGB", FreeImage_Clone(grey), "RGB ", 1024, false);
    add("8-bit grey + GRAY", FreeImage_Clone(grey), "GRAY", 1024, true);
    add("8-bit palette + RGB", FreeImage_Clone(pal), "RGB ", 1024, true);
    add("8-bit palette + GRAY", FreeImage_Clone(pal), "GRAY", 1024, false);
    add("UINT16 + GRAY", FreeImage_ConvertToUINT16(s24), "GRAY", 1024, true);
    add("RGB16 + RGB", FreeImage_ConvertToRGB16(s24), "RGB ", 1024, true);
    add("RGBF + CMYK", FreeImage_ConvertToRGBF(s24), "CMYK", 1024, false);
    add("32-bit + Lab", FreeImage_ConvertTo32Bits(s24), "Lab ", 1024, false);

    // TIFF keeps every page as it is, so the guard alone decides what each one carries
    char tmp[256];
    snprintf(tmp, sizeof tmp, "%s/p8-icc.tif.part", OUT);
    unlink(tmp);
    FIMULTIBITMAP *m = FreeImage_OpenMultiBitmap(FIF_TIFF, tmp, TRUE, FALSE, TRUE, 0);
    for (auto &c : cases) CHECK(addPage(m, FreeImage_Clone(c.dib), FIF_TIFF, 2, 100), "tiff: \"%s\" refused", c.name);
    CHECK(FreeImage_CloseMultiBitmap(m, 0), "tiff: the close failed");
    m = FreeImage_OpenMultiBitmap(FIF_TIFF, tmp, FALSE, TRUE, TRUE, 0);
    for (int i = 0; m && i < (int)cases.size(); i++) {
        FIBITMAP *p = FreeImage_LockPage(m, i);
        const unsigned got = p ? (unsigned)FreeImage_GetICCProfile(p)->size : 0;
        const unsigned want = cases[i].keep ? (unsigned)FreeImage_GetICCProfile(cases[i].dib)->size : 0;
        printf("    %-22s profile %s\n", cases[i].name, got ? "kept" : "dropped");
        CHECK(p && got == want, "tiff: \"%s\" has a %u-byte profile, expected %u", cases[i].name, got, want);
        if (p) FreeImage_UnlockPage(m, p, FALSE);
    }
    if (m) FreeImage_CloseMultiBitmap(m, 0);

    // a plain PNG save, as the format converter makes one, takes a page only with a fitting profile
    for (auto &c : cases) {
        if (!FreeImage_FIFSupportsExportType(FIF_PNG, FreeImage_GetImageType(c.dib))) continue;
        for (int guard = 0; guard <= 1; guard++) {
            FIBITMAP *k = FreeImage_Clone(c.dib);
            if (guard) dropMismatchedICC(k);
            snprintf(tmp, sizeof tmp, "%s/p8-png.part", OUT);
            const BOOL saved = FreeImage_Save(FIF_PNG, k, tmp, 0);
            FreeImage_Unload(k);
            CHECK(saved == (guard || c.keep), "png: \"%s\" %s %s", c.name, guard ? "with the guard" : "without it", saved ? "saved" : "was refused");
        }
    }

    // at 24 bits a 24-bit page goes into MNG unconverted, profile and all
    for (int guard = 0; guard <= 1; guard++) {
        snprintf(tmp, sizeof tmp, "%s/p8-cmyk-guard%d.mng.part", OUT, guard);
        unlink(tmp);
        m = FreeImage_OpenMultiBitmap(FIF_MNG, tmp, TRUE, FALSE, TRUE, 0);
        BOOL a = addPage(m, FreeImage_Clone(cases[0].dib), FIF_MNG, 2, 100, true, guard == 1);
        BOOL b = addPage(m, FreeImage_Clone(s24), FIF_MNG, 2, 100, true, guard == 1);
        FreeImage_CloseMultiBitmap(m, 0);
        printf("mng  %-15s the page with a CMYK profile %s\n", guard ? "with the guard:" : "without it:", a ? "goes in" : "is REFUSED");
        CHECK(b, "mng: a plain page was refused");
        CHECK(guard ? a : !a, "mng: the CMYK page %s", guard ? "was refused with the guard" : "went in without the guard, so the check proves nothing");
    }
    for (auto &c : cases) FreeImage_Unload(c.dib);
    FreeImage_Unload(s24);
    FreeImage_Unload(grey);
    FreeImage_Unload(pal);
}

int main(int argc, char **argv) {
    FreeImage_Initialise(FALSE);
    FreeImage_SetOutputMessage(quietMessages);
    mkdir(OUT, 0755);
    if (argc == 5 && strcmp(argv[1], "--mem") == 0) {
        int r = memoryCase(FMTS[atoi(argv[2]) & 3], atoi(argv[3]) != 0, atoi(argv[4]), 1280, 720);
        FreeImage_DeInitialise();
        return r;
    }

    printf("FreeImage %s\n", FreeImage_GetVersion());
    if (argc >= 2 && strcmp(argv[1], "--tiff") == 0) {
        partTiff(argc > 2 ? argv[2] : "exif.jpg");
        partICC();
        printf("\n%s: %d failure(s)\n", g_fail ? "FAILED" : "PASSED", g_fail);
        FreeImage_DeInitialise();
        return g_fail ? 1 : 0;
    }
    std::vector<Source> src = makeSources();

    partPipeline(src);
    partRefusedPage();
    partAbort();
    partMetadata(argc > 1 ? argv[1] : "exif.jpg");
    partSubFrames();
    partTiff(argc > 1 ? argv[1] : "exif.jpg");
    partICC();
    partMemory(argv[0]);

    for (size_t i = 0; i < src.size(); i++) FreeImage_Unload(src[i].dib);
    printf("\n%s: %d failure(s)\n", g_fail ? "FAILED" : "PASSED", g_fail);
    FreeImage_DeInitialise();
    return g_fail ? 1 : 0;
}
