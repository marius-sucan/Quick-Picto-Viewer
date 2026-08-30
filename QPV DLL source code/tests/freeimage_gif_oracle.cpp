// freeimage_gif_oracle.cpp - what FreeImage actually does to the frames QPV feeds it.
//
// NOT part of run-tests.sh: this exercises the third-party FreeImage library rather than
// qpvmain.dll, and it needs a FreeImage development package that the suite does not require.
// Written for the 2026-08-30 audit of combineImagesFimMultiPage(); kept because the same
// four questions come up for every "why did the multipage save produce nothing" report.
//
// Part 1 reproduces the call order as it was BEFORE the 2026-08-30 fixes, and shows why the
// join produced nothing. Part 2 replays the fixed order and shows every source depth landing.
//
// The order under test, in quick-picto-viewer.ahk's .gif path:
//   combineImgsConvertDepth()  ->  FreeImage_ColorQuantize      (:62873)
//   trFreeImage_Rescale()      ->  FreeImage_Rescale fallback   (:62656 / :15223)
//   FreeImage_OpenMultiBitmap(create_new=1) / AppendPage / CloseMultiBitmap (:62629-62690)
//   FreeImage_SetMetadata(dib, NULL, FIMD_ANIMATION, NULL)      (:62665)
//
// Build (Debian/Ubuntu, no root needed):
//   apt-get download libfreeimage3 libfreeimage-dev
//   mkdir fi && for d in *.deb; do dpkg-deb -x "$d" fi/; done
//   g++ -x c++ freeimage_gif_oracle.cpp -o freeimage_gif_oracle \
//       -Ifi/usr/include -Lfi/usr/lib/x86_64-linux-gnu -lfreeimage \
//       -Wl,-rpath,$PWD/fi/usr/lib/x86_64-linux-gnu
//   ./freeimage_gif_oracle
//
// Caveat: QPV ships a custom r1909 build of FreeImage (initFIMGmodule() :99782), so this
// proves stock 3.18 behaviour. Both the GIF plugin's export-depth table and Rescale's
// palettised-input conversion are long-standing, but re-check here before blaming QPV if a
// future custom build changes either.
//
// written by Marius Șucan with Claude Opus 5

#include <stdio.h>
#include <unistd.h>
#include "FreeImage.h"

static FIBITMAP* make24(int w, int h) {
    FIBITMAP *d = FreeImage_Allocate(w, h, 24, 0, 0, 0);
    for (int y = 0; y < h; y++) {
        BYTE *line = FreeImage_GetScanLine(d, y);
        for (int x = 0; x < w; x++) { line[x*3+0] = x*3 & 0xFF; line[x*3+1] = y*5 & 0xFF; line[x*3+2] = (x+y) & 0xFF; }
    }
    return d;
}

static void report(const char *tag, const char *path) {
    if (access(path, F_OK) != 0) { printf("%s file exists after close: NO -- nothing written\n", tag); return; }
    FILE *f = fopen(path, "rb"); fseek(f, 0, SEEK_END);
    printf("%s file exists after close: YES, %ld bytes\n", tag, ftell(f)); fclose(f);
}

/* ---- part 2: the fixed order ---- */

/* combineImgsConvertDepth(k, modus, animus=1) after the fix */
static FIBITMAP* convertDepthGIF(FIBITMAP *k) {
    unsigned bpp = FreeImage_GetBPP(k);
    if (bpp == 8) return NULL;                    /* AHK: bare Return -> caller keeps k */
    if (bpp == 24 || bpp == 32) return FreeImage_ColorQuantize(k, FIQ_WUQUANT);
    FIBITMAP *d = FreeImage_ConvertTo24Bits(k);   /* 1/4/16/48/64 need a 24-bit step */
    if (!d) return NULL;
    FIBITMAP *q = FreeImage_ColorQuantize(d, FIQ_WUQUANT);
    FreeImage_Unload(d);
    return q;
}

/* combineImgsAddPage(k, ..., setW, setH, setRes) after the fix: rescale THEN convert */
static FIBITMAP* addPage(FIBITMAP *k, int setW, int setH, int setRes) {
    if (!k) return NULL;
    if (setW > 1 && setH > 1 && setRes == 1) {
        FIBITMAP *z = FreeImage_Rescale(k, setW, setH, FILTER_BSPLINE);
        if (z) { FreeImage_Unload(k); k = z; }
    }
    FIBITMAP *c = convertDepthGIF(k);
    if (c) { FreeImage_Unload(k); k = c; }
    return k;
}

static FIBITMAP* allocSrc(int bpp, int w, int h) {
    if (bpp == 48) return FreeImage_AllocateT(FIT_RGB16, w, h, 48, 0, 0, 0);
    FIBITMAP *d = FreeImage_Allocate(w, h, bpp, 0, 0, 0);
    if (d && (bpp == 24 || bpp == 32)) {
        int s = bpp / 8;
        for (int y = 0; y < h; y++) {
            BYTE *l = FreeImage_GetScanLine(d, y);
            for (int x = 0; x < w; x++) { l[x*s] = x*3 & 0xFF; l[x*s+1] = y*5 & 0xFF; l[x*s+2] = (x+y) & 0xFF; }
        }
    }
    return d;
}

static void fixedRun(const char *label, int srcBpp, int setRes) {
    char path[128];
    snprintf(path, sizeof path, "/tmp/qpv_fixed_%d_%d.gif", srcBpp, setRes);
    unlink(path);

    FIBITMAP *pages[3];
    for (int i = 0; i < 3; i++) {
        FIBITMAP *raw = allocSrc(srcBpp == 8 ? 24 : srcBpp, 64 + i, 48);
        if (srcBpp == 8) { FIBITMAP *q = FreeImage_ColorQuantize(raw, FIQ_WUQUANT); FreeImage_Unload(raw); raw = q; }
        pages[i] = addPage(raw, 32, 24, setRes);
    }

    FIMULTIBITMAP *mb = FreeImage_OpenMultiBitmap(FIF_GIF, path, TRUE, FALSE, FALSE, 0);
    for (int i = 0; i < 3; i++) {
        FreeImage_SetMetadata(FIMD_ANIMATION, pages[i], NULL, NULL);   /* the fixed clear */
        FreeImage_AppendPage(mb, pages[i]);
    }
    int got = FreeImage_GetPageCount(mb);
    FreeImage_CloseMultiBitmap(mb, 0);

    unsigned w = FreeImage_GetWidth(pages[0]), h = FreeImage_GetHeight(pages[0]);
    unsigned bpp = FreeImage_GetBPP(pages[0]);
    for (int i = 0; i < 3; i++) FreeImage_Unload(pages[i]);
    printf("%-34s page bpp=%2u  %ux%u  pages=%d/3  file=%s\n",
           label, bpp, w, h, got, access(path, F_OK) == 0 ? "yes" : "MISSING");
}

int main(void) {
    FreeImage_Initialise(FALSE);
    printf("FreeImage version: %s\n\n", FreeImage_GetVersion());

    /* B: which depths may the GIF plugin export?  Anything else is dropped by AppendPage. */
    printf("[B] FIF_GIF SupportsExportBPP:");
    for (int bpp = 1; bpp <= 32; bpp++)
        if (FreeImage_FIFSupportsExportBPP(FIF_GIF, bpp)) printf(" %d", bpp);
    printf("\n\n");

    /* A: quantise then rescale, exactly as phase 1 then phase 2 do. */
    FIBITMAP *src = make24(64, 48);
    FIBITMAP *q   = FreeImage_ColorQuantize(src, FIQ_WUQUANT);
    printf("[A] after ColorQuantize:  bpp=%u colortype=%d\n",
           FreeImage_GetBPP(q), (int)FreeImage_GetColorType(q));
    FIBITMAP *rs  = FreeImage_Rescale(q, 32, 24, FILTER_BSPLINE);
    printf("[A] after Rescale(32x24): bpp=%u colortype=%d   <-- trFreeImage_Rescale fallback\n\n",
           FreeImage_GetBPP(rs), (int)FreeImage_GetColorType(rs));

    /* The combineImgsConvertDepth() modus=1 leak: an already-8-bit page widened to 32. */
    FIBITMAP *q32 = FreeImage_ConvertTo32Bits(q);
    printf("[2] ConvertTo32Bits(8-bit page): bpp=%u\n\n", FreeImage_GetBPP(q32));

    /* C: every page >8bpp -> nothing is appended, and no file is created at all. */
    const char *p1 = "/tmp/qpv_oracle_bad.gif"; unlink(p1);
    FIMULTIBITMAP *mb = FreeImage_OpenMultiBitmap(FIF_GIF, p1, TRUE, FALSE, FALSE, 0);
    printf("[C] OpenMultiBitmap(create_new=TRUE) handle=%p; file exists right after open: %s\n",
           (void*)mb, access(p1, F_OK) == 0 ? "YES" : "no");
    FreeImage_AppendPage(mb, rs);   /* 24-bit, from the rescale  */
    FreeImage_AppendPage(mb, q32);  /* 32-bit, from the modus leak */
    printf("[C] GetPageCount after 2 appends of >8bpp pages = %d\n", FreeImage_GetPageCount(mb));
    printf("[C] CloseMultiBitmap -> %d (success)\n", FreeImage_CloseMultiBitmap(mb, 0));
    report("[C]", p1); printf("\n");

    /* Control: the same flow with pages the plugin accepts. */
    const char *p2 = "/tmp/qpv_oracle_good.gif"; unlink(p2);
    FIBITMAP *q2 = FreeImage_ColorQuantize(src, FIQ_WUQUANT);
    FIMULTIBITMAP *mb2 = FreeImage_OpenMultiBitmap(FIF_GIF, p2, TRUE, FALSE, FALSE, 0);
    FreeImage_AppendPage(mb2, q); FreeImage_AppendPage(mb2, q2);
    printf("[ctl] GetPageCount after 2 appends of 8-bit pages = %d\n", FreeImage_GetPageCount(mb2));
    FreeImage_CloseMultiBitmap(mb2, 0);
    report("[ctl]", p2); printf("\n");

    /* Mixed selection: the quantised JPEG-style page survives, the widened one does not. */
    const char *p3 = "/tmp/qpv_oracle_mixed.gif"; unlink(p3);
    FIMULTIBITMAP *mb3 = FreeImage_OpenMultiBitmap(FIF_GIF, p3, TRUE, FALSE, FALSE, 0);
    FreeImage_AppendPage(mb3, q); FreeImage_AppendPage(mb3, rs);
    printf("[mix] GetPageCount after 8-bit + 24-bit = %d (asked for 2)\n", FreeImage_GetPageCount(mb3));
    FreeImage_CloseMultiBitmap(mb3, 0);
    report("[mix]", p3); printf("\n");

    /* D: an empty-string key is not a NULL key, so the model is never deleted. */
    FITAG *tag = FreeImage_CreateTag();
    FreeImage_SetTagKey(tag, "FrameLeft");
    FreeImage_SetTagType(tag, FIDT_SHORT);
    FreeImage_SetTagCount(tag, 1);
    FreeImage_SetTagLength(tag, 2);
    WORD v = 17; FreeImage_SetTagValue(tag, &v);
    FreeImage_SetMetadata(FIMD_ANIMATION, q, FreeImage_GetTagKey(tag), tag);
    FreeImage_DeleteTag(tag);
    printf("[D] ANIMATION tags after seeding:                %u\n", FreeImage_GetMetadataCount(FIMD_ANIMATION, q));
    FreeImage_SetMetadata(FIMD_ANIMATION, q, "", NULL);   /* what AHK's blank NULL sends */
    printf("[D] after SetMetadata(model, dib, \"\", NULL):    %u   <-- QPV's call\n",
           FreeImage_GetMetadataCount(FIMD_ANIMATION, q));
    FreeImage_SetMetadata(FIMD_ANIMATION, q, NULL, NULL); /* what was intended */
    printf("[D] after SetMetadata(model, dib, NULL, NULL):  %u   <-- intended\n",
           FreeImage_GetMetadataCount(FIMD_ANIMATION, q));

    /* part 3: what coreImgCombinerLoadFimFile() actually gets out of a source GIF.
       It passes multiFlags = GIF_PLAYBACK (2) for GFT=25, so pages come back composited
       at 32bpp carrying only FrameTime; the raw path returns 8bpp with the whole
       animation model. This is what decides which sources findings 2 and 5 really hit. */
    printf("=== part 3: PLAYBACK vs raw page depth and metadata ===\n");
    for (int fl = 2; fl >= 0; fl -= 2) {
        FIMULTIBITMAP *s = FreeImage_OpenMultiBitmap(FIF_GIF, p2, FALSE, TRUE, FALSE, fl);
        if (!s) continue;
        FIBITMAP *pg = FreeImage_LockPage(s, 1);
        if (pg) {
            FIBITMAP *cl = FreeImage_Clone(pg);          /* what QPV keeps */
            FreeImage_UnlockPage(s, pg, FALSE);
            printf("  flags=%d %-22s clone=%2ubpp  ANIMATION:", fl,
                   fl == 2 ? "(GIF_PLAYBACK, QPV)" : "(raw)", FreeImage_GetBPP(cl));
            FITAG *tg = NULL;
            FIMETADATA *h = FreeImage_FindFirstMetadata(FIMD_ANIMATION, cl, &tg);
            if (h) { do printf(" %s", FreeImage_GetTagKey(tg)); while (FreeImage_FindNextMetadata(h, &tg));
                     FreeImage_FindCloseMetadata(h); }
            printf("\n");
            FreeImage_Unload(cl);
        }
        FreeImage_CloseMultiBitmap(s, 0);
    }
    printf("\n");

    printf("=== part 2: the fixed combineImgsAddPage() order ===\n");
    fixedRun("24-bit source, no resize",   24, 0);
    fixedRun("24-bit source, resize on",   24, 1);
    fixedRun("32-bit source, resize on",   32, 1);
    fixedRun("8-bit source, no resize",     8, 0);
    fixedRun("8-bit (GIF page), resize on", 8, 1);
    fixedRun("48-bit HDR source, resize",  48, 1);

    FreeImage_DeInitialise();
    return 0;
}
