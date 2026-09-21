// freeimage_multipage_oracle.cpp - the page-by-page join of combineImagesFimMultiPage(),
// replayed against the FreeImage fork QPV ships (github: marius-sucan/FreeImage-library).
//
// NOT part of run-tests.sh: it exercises FreeImage, not qpvmain.dll. Written 2026-09-21 for
// the rewrite that appends every page as soon as it is loaded instead of collecting them all.
//
// Build, with the fork checked out and built next to this repository (static, as the .so
// in Dist carries the soname libfreeimage.so.3 and no link of that name):
//   FI=~/repos/FreeImage-library/Dist
//   g++ -O2 freeimage_multipage_oracle.cpp -o freeimage_multipage_oracle -I$FI $FI/libfreeimage.a -fopenmp -lpthread
//   ./freeimage_multipage_oracle ~/repos/FreeImage-library/TestAPI/exif.jpg
//
// Each prepare step mirrors an AHK function:
//   normalize()      - combineFimImgsAddPage(): tone mapping or ConvertToType() for non-FIT_BITMAP pages
//   convertDepth()   - combineFimImgsConvertDepth()
//   tagPage()        - combineFimImgsAddPage(): metadata models 0-11 dropped, FrameTime set
// Parts: 1 every source kind x depth x format goes in and reads back with its FrameTime;
// 2 a refused page; 3 the discard on abort; 4 the EXIF WebP and MNG take from the first
// page unless it is dropped; 5 sub-frames of an animation; 6 memory, collected vs streamed.
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
#include "FreeImage.h"

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

// ConvertToType() has no route from floating point RGB to FIT_BITMAP; those are tone mapped
static FIBITMAP* normalize(FIBITMAP *k) {
    const FREE_IMAGE_TYPE t = FreeImage_GetImageType(k);
    if (t == FIT_BITMAP) return k;
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
static BOOL addPage(FIMULTIBITMAP *multi, FIBITMAP *k, FREE_IMAGE_FORMAT fif, int modus, LONG frameTime, bool strip = true) {
    k = normalize(k);
    if (!k) return FALSE;
    FIBITMAP *c = convertDepth(k, modus, fif);
    if (c) { FreeImage_Unload(k); k = c; }
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
    std::vector<Source> src = makeSources();

    partPipeline(src);
    partRefusedPage();
    partAbort();
    partMetadata(argc > 1 ? argv[1] : "exif.jpg");
    partSubFrames();
    partMemory(argv[0]);

    for (size_t i = 0; i < src.size(); i++) FreeImage_Unload(src[i].dib);
    printf("\n%s: %d failure(s)\n", g_fail ? "FAILED" : "PASSED", g_fail);
    FreeImage_DeInitialise();
    return g_fail ? 1 : 0;
}
