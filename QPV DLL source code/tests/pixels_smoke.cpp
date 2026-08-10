// Compiles the shipped dupes-pixels.h verbatim and exercises everything in it that is not
// an image decoder.
//
// The DLL cannot be built here, so a syntax or type error in the collector would otherwise
// only surface on the Windows box - after the whole schema has already changed underneath
// it. Compiling it against shim/pixels-env.h catches that, and the checks below cover the
// parts that carry meaning:
//
//   - dpHistogram() against a transcription of calcHistoAvgFile(), which is the AHK it
//     replaces. Those eight numbers are stored, rounded and then GROUPed on by the
//     duplicate finder, so a difference in the last decimal changes which images are
//     called duplicates.
//   - dpDumpBlue() reads the blue channel, row by row, at the right stride.
//   - the resize asks GDI+ for the interpolation, smoothing and pixel-offset modes
//     Gdip_ResizeBitmap() asked for.
//   - the job pipeline: WIC first, FreeImage when WIC fails, a missing file marked rather
//     than decoded, the flipped fingerprint being a mirror of the unflipped one, and the
//     cancel flag stopping the run.
//
// written by Marius Șucan with Claude Opus 5

#include "shim/pixels-env.h"

// Normally the shipped header. run-tests.sh points this at a deliberately broken COPY for
// the mutation check, so that the check never has to edit the source that ships.
#ifndef QPV_PIXELS_HEADER
#define QPV_PIXELS_HEADER "../dupes-pixels.h"
#endif
#include QPV_PIXELS_HEADER

// declared by dupes-pixels.h, defined in qpv-main.cpp next to the directory helpers.
// The real one folds a UTC file time into a local YYYYMMDDHHMISS number; only the
// division by 100 that drops the seconds matters to the collector.
static INT64 qpvFileTimeToLocalStamp(INT64 ft) {
    return (ft > 0) ? (INT64)20260101120000ll : 0;
}

static std::wstring widenA(const char *s) {
    std::wstring w;
    for (; s && *s; s++) w.push_back((wchar_t)(unsigned char)*s);
    return w;
}

static int failures = 0;
static void check(bool cond, const char *what) {
    printf("    %-62s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

// ---------------------------------------------------------------------------------------
//  the histogram statistics, as calcHistoAvgFile() computes them
// ---------------------------------------------------------------------------------------

struct RefHisto { double avg, median, peak, low, rms, range, mode, minu; };

// A transcription of the AHK, kept deliberately literal - including the details that look
// like slips and are not: sumTotalBr accumulates (level + 1) so that the /256 at the end
// maps level 255 to exactly 1.0, the mode keeps the LOWEST level on a tie, "rarest level"
// means rarest among the OCCUPIED ones, and the median is the first level past half the
// pixels rather than an interpolated one.
static RefHisto refHistogram(const unsigned int *h, int w, int hh) {
    const double TotalPixelz = (double)w*hh;
    const long long halfPix = (long long)w*hh/2;
    int medianValue = -1, minBrLvlK = -1;
    int modePointK = 0, peakPointK = 0, minPointK = 0;
    long long modePointV = 0, thisSum = 0, sumTotalBr = 0, sumSq = 0;
    long long pixMinu = (long long)w*hh;

    for ( int i = 0 ; i < 256 ; i++)
    {
        const long long n = (long long)h[i];
        if (n < 1)
           continue;

        sumTotalBr += n*(long long)(i + 1);
        sumSq      += n*(long long)i*(long long)i;
        if (n > modePointV) { modePointV = n; modePointK = i; }
        peakPointK = i;
        if (minBrLvlK==-1) minBrLvlK = i;
        if (n < pixMinu) { pixMinu = n; minPointK = i; }
        if (medianValue==-1)
        {
           thisSum += n;
           if (thisSum > halfPix) medianValue = i;
        }
    }

    const double avgu = (double)sumTotalBr/TotalPixelz - 1.0;
    const double variance = (double)sumSq/TotalPixelz - avgu*avgu;
    const double stdDev = sqrt((variance > 0) ? variance : 0);

    RefHisto r;
    #define R5(x) (floor((x)*100000.0 + 0.5)/100000.0)
    r.avg    = R5((avgu + 1.0)/256.0);
    r.median = R5((double)(medianValue + 1)/256.0);
    r.peak   = R5((double)(peakPointK + 1)/256.0);
    r.low    = R5((double)(minBrLvlK + 1)/256.0);
    r.rms    = R5(stdDev/256.0);
    r.range  = R5((double)(peakPointK - minBrLvlK + 1)/256.0);
    r.mode   = R5((double)(modePointK + 1)/256.0);
    r.minu   = R5((double)(minPointK + 1)/256.0);
    #undef R5
    return r;
}

static unsigned int rngState = 12345;
static unsigned int rnd() {
    rngState = rngState*1664525u + 1013904223u;
    return rngState >> 8;
}

static void histogramMatchesTheAHK() {
    printf("  histogram statistics\n");
    Gdiplus::GpBitmap *bmp = NULL;
    Gdiplus::DllExports::GdipCreateBitmapFromScan0(64, 64, 0, PixelFormat32bppARGB, NULL, &bmp);

    int cases = 0, bad = 0, sawSingleLevel = 0, sawFullSpread = 0;
    for ( int t = 0 ; t < 4000 ; t++)
    {
        // five shapes, so the median / mode / rarest-level branches all get walked:
        // a full spread, a single occupied level, two levels, a sparse tail, and an
        // image whose whole histogram sits at one end
        const int shape = t % 5;
        memset(gShimHistogram, 0, sizeof(gShimHistogram));
        long long total = 0;
        if (shape==0)
        {
           for ( int i = 0 ; i < 256 ; i++) { gShimHistogram[i] = rnd() % 64; total += gShimHistogram[i]; }
           sawFullSpread++;
        } else if (shape==1)
        {
           const int k = (int)(rnd() % 256);
           gShimHistogram[k] = 4096;
           total = 4096;
           sawSingleLevel++;
        } else if (shape==2)
        {
           const int a = (int)(rnd() % 256), b = (int)(rnd() % 256);
           gShimHistogram[a] += 2000;
           gShimHistogram[b] += 2096;
           total = 4096;
        } else if (shape==3)
        {
           for ( int i = 0 ; i < 256 ; i += 1 + (int)(rnd() % 20)) { gShimHistogram[i] = 1 + rnd() % 900; total += gShimHistogram[i]; }
        } else
        {
           for ( int i = 200 ; i < 256 ; i++) { gShimHistogram[i] = rnd() % 300; total += gShimHistogram[i]; }
        }

        if (total < 1)
           continue;

        // the pixel count the statistics divide by is the bitmap's, not the histogram's
        const int w = 64, h = (int)((total + 63)/64);
        Gdiplus::GpBitmap *b2 = NULL;
        Gdiplus::DllExports::GdipCreateBitmapFromScan0(w, h, 0, PixelFormat32bppARGB, NULL, &b2);

        DupePixResult got;
        if (!dpHistogram(b2, w, h, got)) { bad++; Gdiplus::DllExports::GdipDisposeImage(b2); continue; }
        const RefHisto want = refHistogram(gShimHistogram, w, h);
        Gdiplus::DllExports::GdipDisposeImage(b2);

        if (got.avg!=want.avg || got.median!=want.median || got.peak!=want.peak || got.low!=want.low
         || got.rms!=want.rms || got.range!=want.range || got.mode!=want.mode || got.minu!=want.minu)
        {
           if (bad < 3)
              printf("      case %d: avg %.6f/%.6f median %.6f/%.6f rms %.6f/%.6f mode %.6f/%.6f\n",
                     t, got.avg, want.avg, got.median, want.median, got.rms, want.rms, got.mode, want.mode);
           bad++;
        }
        cases++;
    }

    Gdiplus::DllExports::GdipDisposeImage(bmp);
    check(cases > 3000, "enough histogram shapes exercised");
    check(sawSingleLevel > 0 && sawFullSpread > 0, "both the degenerate and the full-spread shapes ran");
    check(bad==0, "every statistic matches calcHistoAvgFile() exactly");
}

// ---------------------------------------------------------------------------------------
//  the blue-channel dump and the resize
// ---------------------------------------------------------------------------------------

static void dumpReadsTheBlueChannel() {
    printf("  fingerprint extraction\n");
    Gdiplus::GpBitmap *b = shimMakeBitmap(9, 8, 3);
    std::vector<unsigned char> out;
    check(dpDumpBlue(b, 9, 8, out), "dpDumpBlue succeeds on a 9x8 bitmap");
    check(out.size()==72, "one byte per pixel, no padding");

    int bad = 0;
    for ( int y = 0 ; y < 8 ; y++)
        for ( int x = 0 ; x < 9 ; x++)
            if (out[(size_t)y*9 + x] != b->bgra[((size_t)y*9 + x)*4])
               bad++;

    check(bad==0, "every value is the blue byte of its own pixel");

    // green and red differ from blue everywhere in the synthetic bitmap, so a dump that
    // read the wrong channel could not have matched above
    check(b->bgra[1]!=b->bgra[0] && b->bgra[2]!=b->bgra[0], "the channels really are distinguishable");

    // the mirroring itself, at the one place it is exact: on the bitmap, before any
    // resampling. A resampler that samples at fixed offsets is never mirror-equivariant,
    // which is why the flipped fingerprint is taken from a flipped BITMAP rather than by
    // reversing the unflipped fingerprint.
    Gdiplus::DllExports::GdipImageRotateFlip(b, Gdiplus::RotateNoneFlipX);
    std::vector<unsigned char> flipped;
    dpDumpBlue(b, 9, 8, flipped);
    int mirrorBad = 0;
    for ( int y = 0 ; y < 8 ; y++)
        for ( int x = 0 ; x < 9 ; x++)
            if (flipped[(size_t)y*9 + x] != out[(size_t)y*9 + (8 - x)])
               mirrorBad++;

    check(mirrorBad==0, "RotateNoneFlipX mirrors each row, and the dump follows it");
    Gdiplus::DllExports::GdipDisposeImage(b);

    check(!dpDumpBlue(NULL, 9, 8, out), "a missing bitmap is refused rather than read");
}

static void resizeAsksForTheRightModes() {
    printf("  resize\n");
    Gdiplus::GpBitmap *src = shimMakeBitmap(40, 30, 9);
    Gdiplus::GpBitmap *dst = dpResizeBitmap(src, 32, 32, 6);
    check(dst!=NULL, "dpResizeBitmap produces a bitmap");
    if (dst!=NULL)
    {
       unsigned int w = 0, h = 0;
       Gdiplus::DllExports::GdipGetImageWidth(dst, &w);
       Gdiplus::DllExports::GdipGetImageHeight(dst, &h);
       check(w==32 && h==32, "at exactly the size asked for");

       // it must actually have been drawn into, not left as the zero-filled allocation
       bool nonZero = false;
       for (size_t i = 0; i < dst->bgra.size(); i += 4)
           if (dst->bgra[i]!=0) { nonZero = true; break; }
       check(nonZero, "and filled from the source");
       Gdiplus::DllExports::GdipDisposeImage(dst);
    }

    check(dpResizeBitmap(src, 0, 8, 5)==NULL, "a degenerate size is refused");
    check(dpResizeBitmap(NULL, 9, 8, 5)==NULL, "a missing source is refused");
    Gdiplus::DllExports::GdipDisposeImage(src);
}

// ---------------------------------------------------------------------------------------
//  one job, end to end
// ---------------------------------------------------------------------------------------

static void runOne(const wchar_t *path, const DupePixCfg &cfg, DupePixResult &res) {
    DpEffects fx;
    dpMakeEffects(fx, (cfg.applyBlur==1) ? 3 : 0);
    ThumbsConfig tcfg;
    tcfg.thumbSize = cfg.boxSize;
    DupePixJob job;
    job.imgidu = 42;
    job.path = path;
    dpRunJob(NULL, fx, cfg, tcfg, job, res);
    dpFreeEffects(fx);
}

static void jobPipeline() {
    printf("  one job\n");
    tpWicExts.clear();
    tpFimExts.clear();
    tpWicExts.insert(L"jpg");
    tpFimExts.insert(L"exr");
    FIM.ok = true;

    // a flat histogram so dpHistogram() always succeeds
    for ( int i = 0 ; i < 256 ; i++) gShimHistogram[i] = 4;

    DupePixCfg cfg;
    cfg.wantFlipped = 0;
    cfg.applyBlur = 0;

    gShimWicFails = 0;
    gShimWicCalls = gShimFimCalls = gShimGrayCalls = 0;
    DupePixResult res;
    runOne(L"img1.jpg", cfg, res);
    check(res.status==DP_OK, "a WIC format is collected");
    check(gShimWicCalls==1 && gShimFimCalls==0, "WIC was asked, FreeImage was not");
    check(res.loaderUsed==1, "and the result says so");
    check(res.small.size()==72 && res.big.size()==1024, "both fingerprints have their full length");
    check(res.smallH.empty() && res.bigH.empty(), "no flipped fingerprints were asked for");
    check(gShimGrayCalls==1, "the grey effect ran exactly once");
    check(res.fsize==4096 && res.fmodified==202601011200ll, "the file stamps are collected, seconds dropped");

    // a format WIC does not declare goes straight to FreeImage
    gShimWicCalls = gShimFimCalls = 0;
    DupePixResult res2;
    runOne(L"img2.exr", cfg, res2);
    check(res2.status==DP_OK && gShimWicCalls==0 && gShimFimCalls==1, "a FreeImage-only format skips WIC");
    check(res2.loaderUsed==2, "and reports the FreeImage loader");

    // ... and so does one WIC declares but cannot open
    gShimWicFails = 1;
    gShimWicCalls = gShimFimCalls = 0;
    DupePixResult res3;
    runOne(L"img3.jpg", cfg, res3);
    check(res3.status==DP_OK && gShimWicCalls==1 && gShimFimCalls==1, "a WIC failure falls back to FreeImage");
    gShimWicFails = 0;

    // a file that is not there is never handed to a decoder
    gShimWicCalls = gShimFimCalls = 0;
    DupePixResult res4;
    runOne(L"gone.jpg", cfg, res4);
    check(res4.status==DP_ERR_LOAD, "a missing file fails");
    check(gShimWicCalls==0 && gShimFimCalls==0, "... without either decoder being started");

    // the blur is two passes, the way Gdip_GaussianBlur() applied it
    cfg.applyBlur = 1;
    gShimBlurCalls = 0;
    DupePixResult res5;
    runOne(L"img5.jpg", cfg, res5);
    check(res5.status==DP_OK && gShimBlurCalls==2, "the blur runs as two passes");
    check(gShimHistogramCalls > 0, "the histogram was measured");
    cfg.applyBlur = 0;

    // the flipped fingerprint is the mirror of the unflipped one, and no second decode
    cfg.wantFlipped = 1;
    gShimWicCalls = 0;
    gShimFlipCalls = 0;
    DupePixResult res6;
    runOne(L"img6.jpg", cfg, res6);
    check(res6.status==DP_OK, "the flipped variant is collected");
    check(gShimWicCalls==1, "from one decode, not two");
    check(gShimFlipCalls==1, "the decoded bitmap is mirrored once");
    check(res6.smallH.size()==72 && res6.bigH.size()==1024, "both flipped fingerprints are full length");
    check(res6.smallH!=res6.small && res6.bigH!=res6.big, "and they are not copies of the unflipped ones");
}

// ---------------------------------------------------------------------------------------
//  the queue, the generation counter and the cancel flag
// ---------------------------------------------------------------------------------------

static void poolPlumbing() {
    printf("  pool plumbing\n");
    check(dupesPixGetState()==(void*)&dpState, "dupesPixGetState hands back the state block");

    // the byte offsets AHK reads with NumGet(); LONG is 32-bit on Windows and here
    const char *base = (const char*)&dpState;
    check((const char*)&dpState.phase    - base==0,  "phase sits at offset 0");
    check((const char*)&dpState.inFlight - base==8,  "inFlight sits at offset 8");
    check((const char*)&dpState.written  - base==16, "written sits at offset 16");
    check((const char*)&dpState.failed   - base==20, "failed sits at offset 20");
    check((const char*)&dpState.dbErrors - base==24, "dbErrors sits at offset 24");
    check((const char*)&dpState.submitted- base==28, "submitted sits at offset 28");

    // with no workers, nothing may be started - the AHK driver falls back on that
    check(dupesPixBegin(NULL, L"SELECT 1", L"350|5|0|0|1|1|1|1")==0, "dupesPixBegin refuses without a database handle");

    // a cancel raised between runs must not be inherited by the next one
    dupesPixCancel.store(1);
    check(dupesPixStep(5)==-1, "stepping without a prepared query is an error, not a hang");
    dupesPixCancel.store(0);

    // the generation counter is what makes an abandoned run's results get dropped
    const LONG before = dpGeneration.load();
    {
        std::lock_guard<std::mutex> lk(dpMutex);
        dpQueue.push_back(DupePixJob());
        dpResults.push_back(DupePixResult());
        dpCancelLocked();
    }
    check(dpGeneration.load()==before + 1, "cancelling bumps the generation");
    check(dpQueue.empty() && dpResults.empty(), "and drops the queue and the undelivered results");
    check(dpState.queued==0 && dpState.ready==0, "and says so in the state block");

    check(dupesPixEnd()==1, "dupesPixEnd is safe with nothing running");
    check(dupesPixShutdown()==1, "dupesPixShutdown is safe with no workers");
}


// ---------------------------------------------------------------------------------------
//  the whole collection run, against a real SQLite database
// ---------------------------------------------------------------------------------------
//
// The decoders are synthetic, but everything else here is the shipped code doing the real
// thing: the keyset cursor, the prepared writes, the worker threads, the termination
// condition, and the resumability the collect-data dialog promises.

#define QPV_SQLITE_OPEN_CREATE 0x00000004

static void execOrDie(sqlite3 *db, const char *sql, const char *what) {
    if (SQ.exec==NULL || SQ.exec(db, sql, NULL, NULL, NULL)!=SQLITE_OK)
    {
       printf("    could not %s\n", what);
       failures++;
    }
}

static long long scalar(sqlite3 *db, const char *sql) {
    sqlite3_stmt *st = NULL;
    const std::wstring w = widenA(sql);
    if (SQ.prepare16_v2(db, w.c_str(), -1, &st, NULL)!=SQLITE_OK || st==NULL)
       return -1;

    long long v = -1;
    if (SQ.step(st)==SQLITE_ROW)
       v = (long long)SQ.column_int64(st, 0);

    SQ.finalize(st);
    return v;
}

static void collectionAgainstRealSQLite() {
    printf("  a whole collection run\n");
    bindSQLiteOnce();
    if (!SQ.ok || SQ.exec==NULL || SQ.bind_double==NULL || SQ.bind_blob==NULL)
    {
       printf("    SKIPPED: libsqlite3.so.0 is not available\n");
       return;
    }

    const char *path = "pixels_scratch.sldb";
    remove(path);
    sqlite3 *db = NULL;
    if (SQ.open_v2(path, &db, SQLITE_OPEN_READWRITE | QPV_SQLITE_OPEN_CREATE, NULL)!=SQLITE_OK || db==NULL)
    {
       printf("    could not create the scratch database\n");
       failures++;
       return;
    }

    execOrDie(db,
        "CREATE TABLE images (imgidu NUMERIC PRIMARY KEY NOT NULL, imgfile TEXT COLLATE NOCASE NOT NULL,"
        " imgfolder TEXT COLLATE NOCASE NOT NULL, fullPath TEXT AS (imgfolder||'\\'||imgfile), fsize INT,"
        " fmodified INT, fcreated INT, imgwidth INT, imgheight INT, imgmedian FLOAT, imgavg FLOAT,"
        " imghpeak FLOAT, imghlow FLOAT, imghmode FLOAT, imghrms FLOAT, imghminu FLOAT, imghrange FLOAT,"
        " isDeleted INT DEFAULT 0, UNIQUE (fullPath));"
        "CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY NOT NULL, small BLOB, big BLOB,"
        " smallH BLOB, bigH BLOB);", "create the v3 schema");

    // 3000 images, every seventh of them missing from the disk. The count is what makes
    // the step loop below run more than once at a 1 ms budget, which is the whole point:
    // AHK re-enters dupesPixStep() and a step that never yielded would freeze the UI.
    std::string ins = "BEGIN;";
    const int total = 3000, missingEvery = 7;
    int wantOK = 0, wantDead = 0;
    for ( int i = 1 ; i <= total ; i++)
    {
        const bool gone = (i % missingEvery)==0;
        char row[256];
        snprintf(row, sizeof(row), "INSERT INTO images (imgidu, imgfile, imgfolder) VALUES (%d,'%s%d.jpg','C:\\p');",
                 i, gone ? "gone" : "img", i);
        ins += row;
        if (gone) wantDead++; else wantOK++;
    }
    ins += "COMMIT;";
    execOrDie(db, ins.c_str(), "insert the rows");

    // the collector's own settings, and a flat histogram for the stubbed GDI+ to hand back
    for ( int i = 0 ; i < 256 ; i++) gShimHistogram[i] = 4;
    tpWicExts.clear();
    tpFimExts.clear();
    tpWicExts.insert(L"jpg");
    FIM.ok = true;
    m_pIWICFactory = (IWICImagingFactory*)1;      // "initWICnow() has run"

    check(dupesPixInit(3) >= 1, "the pool starts");

    const wchar_t *sel = L"SELECT imgidu, fullPath FROM images"
                         L" WHERE imgidu NOT IN (SELECT imgidu FROM imagesPixels WHERE small IS NOT NULL)"
                         L" AND isDeleted=0 AND imgidu>?2 ORDER BY imgidu LIMIT ?1;";
    check(dupesPixBegin(db, sel, L"350|5|0|1|1|1|1|1")==1, "dupesPixBegin prepares the run");

    execOrDie(db, "BEGIN;", "open the transaction");
    int steps = 0;
    while (dupesPixStep(1)==1)
    {
        if (++steps > 200000) { printf("    the collection loop did not terminate\n"); failures++; break; }
    }
    execOrDie(db, "COMMIT;", "commit the collected data");
    dupesPixEnd();

    check(steps > 1, "a budgeted step yields and is re-entered, rather than running to the end");
    check(dpState.written==wantOK, "every readable image was written exactly once");
    check(dpState.failed==wantDead, "and every missing one was counted as a failure");
    check(dpState.dbErrors==0, "no write failed");
    check(dpState.submitted==total, "each row was handed out exactly once - the cursor holds");

    check(scalar(db, "SELECT count(*) FROM imagesPixels")==wantOK, "one imagesPixels row per collected image");
    check(scalar(db, "SELECT count(*) FROM imagesPixels WHERE length(small)=72 AND length(big)=1024")==wantOK,
          "every fingerprint has its full length");
    check(scalar(db, "SELECT count(*) FROM imagesPixels WHERE length(smallH)=72 AND length(bigH)=1024")==wantOK,
          "and so does every flipped one, which this run asked for");
    check(scalar(db, "SELECT count(*) FROM images WHERE imgavg IS NOT NULL AND imghrms IS NOT NULL")==wantOK,
          "the histogram statistics landed on the same rows");
    check(scalar(db, "SELECT count(*) FROM images WHERE fsize=4096")==wantOK, "so did the file size");
    check(scalar(db, "SELECT count(*) FROM images WHERE isDeleted=1")==wantDead,
          "the images that could not be read are marked, not retried forever");
    check(scalar(db, "SELECT count(*) FROM imagesPixels p JOIN images i ON i.imgidu=p.imgidu"
                     " WHERE i.imgfile LIKE 'gone%'")==0, "and no fingerprint was written for them");

    // running it again must find nothing to do: that is the property the resume promise
    // rests on, and the one a bare LIMIT would have broken
    check(dupesPixBegin(db, sel, L"350|5|0|1|1|1|1|1")==1, "the same run can be started again");
    int steps2 = 0;
    while (dupesPixStep(20)==1)
        if (++steps2 > 1000) break;

    dupesPixEnd();
    check(dpState.submitted==0 && dpState.written==0, "a second pass has nothing left to hand out");

    check(dupesPixShutdown()==1, "the pool shuts down cleanly");
    SQ.close_v2(db);
    remove(path);
}

// ---------------------------------------------------------------------------------------

int main() {
    printf("dupes-pixels.h\n");
    histogramMatchesTheAHK();
    dumpReadsTheBlueChannel();
    resizeAsksForTheRightModes();
    jobPipeline();
    poolPlumbing();
    collectionAgainstRealSQLite();

    printf("\n  %s\n", failures ? "PIXEL COLLECTOR TEST FAILED" : "pixel collector test passed");
    return failures ? 1 : 0;
}
