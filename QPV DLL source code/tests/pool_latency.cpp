// What the collection pool's state counters look like when the decoders are slow.
//
// collectImgDataViaPool() prints nine numbers out of DupePixState every two seconds, and
// on a mechanical drive they read
//
//    phase = 1, queued = 0, inFlight = 1, ready = 0, written = 432, failed = 0,
//    dbErrors = 0, submitted = 433, alive = 8
//
// while the same build over an SSD reads queued = 7, inFlight = 8, submitted = 18673. The
// question this answers is what the OTHER seven workers are doing in the first case, and
// whether a slow disk can produce that reading at all - because a slow CONSUMER makes a
// queue grow, not shrink.
//
// Everything below the sampling loop is the shipped dupes-pixels.h, compiled verbatim
// against shim/pixels-env.h the way pixels_smoke.cpp compiles it, on a real SQLite with the
// real schema v3 and the real indexes. The only thing the shim adds is a sleep inside the
// synthetic decoder - gShimDecodeSleepMs - which is the one difference between a run over an
// SSD and a run over an HDD that the pool can possibly see.
//
// The loop that drives it is collectImgDataViaPool()'s: dupesPixStep(320) in a loop, the
// same nine NumGet() reads at the same byte offsets, a sample every two seconds. A second
// thread samples the same struct every 2 ms, so that a backlog that exists between two
// samples cannot be mistaken for one that never existed.
//
//   ./pool_latency                    the three scenarios
//   ./pool_latency cost               only the refill-cost measurement
//
// written by Marius Șucan with Claude Opus 5

#include "shim/pixels-env.h"

#ifndef QPV_PIXELS_HEADER
#define QPV_PIXELS_HEADER "../dupes-pixels.h"
#endif
#include QPV_PIXELS_HEADER

static INT64 qpvFileTimeToLocalStamp(INT64 ft) {
    return (ft > 0) ? (INT64)20260101120000ll : 0;
}

#define QPV_SQLITE_OPEN_CREATE 0x00000004

static std::wstring widenA(const char *s) {
    std::wstring w;
    for (; s && *s; s++) w.push_back((wchar_t)(unsigned char)*s);
    return w;
}

static int problems = 0;

static bool exec(sqlite3 *db, const char *sql) {
    if (SQ.exec==NULL || SQ.exec(db, sql, NULL, NULL, NULL)!=SQLITE_OK)
    {
       printf("    SQL failed: %.70s\n", sql);
       problems++;
       return false;
    }
    return true;
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

static double nowMs() {
    static const std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
}

// ---------------------------------------------------------------------------------------
//  a library, with the schema and the indexes SLDBinitSQLdb() creates
// ---------------------------------------------------------------------------------------

// nCollected rows get a fingerprint up front, at the real sizes: that is what the refill
// query's NOT IN subquery has to walk past on every single refill.
static sqlite3* buildDB(const char *path, int nRows, int nCollected, int slowEvery) {
    remove(path);
    sqlite3 *db = NULL;
    if (SQ.open_v2(path, &db, SQLITE_OPEN_READWRITE | QPV_SQLITE_OPEN_CREATE, NULL)!=SQLITE_OK || db==NULL)
    {
       printf("    could not create %s\n", path);
       problems++;
       return NULL;
    }

    exec(db, "PRAGMA temp_store=MEMORY; PRAGMA cache_size=-65536;");
    exec(db,
        "CREATE TABLE images (imgidu NUMERIC PRIMARY KEY NOT NULL, imgfile TEXT COLLATE NOCASE NOT NULL,"
        " imgfolder TEXT COLLATE NOCASE NOT NULL, fullPath TEXT AS (imgfolder||'\\'||imgfile), fsize INT,"
        " fmodified INT, fcreated INT, imgwidth INT, imgheight INT, imgframes INT, imgdpi INT,"
        " imgpixfmt TEXT COLLATE NOCASE, imgmedian FLOAT, imgavg FLOAT,"
        " imghpeak FLOAT, imghlow FLOAT, imghmode FLOAT, imghrms FLOAT, imghminu FLOAT, imghrange FLOAT,"
        " isDeleted INT DEFAULT 0, UNIQUE (fullPath));"
        "CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY NOT NULL, small BLOB, big BLOB,"
        " smallH BLOB, bigH BLOB);");
    // SLDBindexesSQL(), verbatim
    exec(db, "CREATE INDEX IF NOT EXISTS imgsIndex ON images(imgidu, imgfolder, imgfile);"
             " CREATE INDEX IF NOT EXISTS imgsAliveIndex ON images(isDeleted);");

    std::string ins = "BEGIN;";
    for ( int i = 1 ; i <= nRows ; i++)
    {
        char row[256];
        const bool slow = (slowEvery > 0 && (i % slowEvery)==0);
        snprintf(row, sizeof(row), "INSERT INTO images (imgidu, imgfile, imgfolder) VALUES (%d,'%s%d.jpg','C:\\p');",
                 i, slow ? "slow" : "img", i);
        ins += row;
        if (ins.size() > 900000) { exec(db, (ins + "COMMIT;").c_str()); ins = "BEGIN;"; }
    }
    ins += "COMMIT;";
    exec(db, ins.c_str());

    if (nCollected > 0)
    {
       std::string p = "BEGIN;";
       for ( int i = 1 ; i <= nCollected ; i++)
       {
           char row[192];
           snprintf(row, sizeof(row), "INSERT INTO imagesPixels VALUES (%d, zeroblob(72), zeroblob(1024),"
                                      " zeroblob(72), zeroblob(1024));", i);
           p += row;
           if (p.size() > 900000) { exec(db, (p + "COMMIT;").c_str()); p = "BEGIN;"; }
       }
       p += "COMMIT;";
       exec(db, p.c_str());
    }

    return db;
}

// What collectSQLFileInfosNow() builds now, through SQLpixelsMissingClause()
static const wchar_t *kSelect =
    L"SELECT imgidu, fullPath FROM images"
    L" WHERE NOT EXISTS (SELECT 1 FROM imagesPixels AS px WHERE px.imgidu=images.imgidu"
    L" AND px.small IS NOT NULL) AND isDeleted=0 AND imgidu>?2 ORDER BY imgidu LIMIT ?1;";

// and what it built before, kept for the comparison below
static const wchar_t *kSelectNotIn =
    L"SELECT imgidu, fullPath FROM images"
    L" WHERE imgidu NOT IN (SELECT imgidu FROM imagesPixels WHERE small IS NOT NULL)"
    L" AND isDeleted=0 AND imgidu>?2 ORDER BY imgidu LIMIT ?1;";

// The two must select the same images, or the change is not a speed-up but a different run.
// A missing imagesPixels row, a row whose blob is NULL and a row with a real blob all have to
// keep meaning what they meant, and so do both spellings of isDeleted - 1 is durable, 2 is a
// rescan marker, and neither is 0.
static void clausesAgree() {
    printf("\n  NOT EXISTS selects exactly what NOT IN selected\n");
    sqlite3 *db = buildDB("pool_equiv.sldb", 900, 0, 0);
    if (db==NULL)
       return;

    exec(db, "INSERT INTO imagesPixels (imgidu, small, big) SELECT imgidu, zeroblob(72), zeroblob(1024)"
             " FROM images WHERE imgidu%3=0;");                       // collected
    exec(db, "INSERT INTO imagesPixels (imgidu, small, big) SELECT imgidu, NULL, zeroblob(1024)"
             " FROM images WHERE imgidu%3=1;");                       // a row, but no fingerprint
    exec(db, "UPDATE images SET isDeleted=1 WHERE imgidu%7=0;");
    exec(db, "UPDATE images SET isDeleted=2 WHERE imgidu%11=0;");

    // both directions, so neither can be a subset of the other
    const char *diffA = "SELECT count(*) FROM (SELECT imgidu FROM images WHERE NOT EXISTS"
                        " (SELECT 1 FROM imagesPixels AS px WHERE px.imgidu=images.imgidu AND px.small IS NOT NULL)"
                        " AND isDeleted=0 EXCEPT SELECT imgidu FROM images WHERE imgidu NOT IN"
                        " (SELECT imgidu FROM imagesPixels WHERE small IS NOT NULL) AND isDeleted=0);";
    const char *diffB = "SELECT count(*) FROM (SELECT imgidu FROM images WHERE imgidu NOT IN"
                        " (SELECT imgidu FROM imagesPixels WHERE small IS NOT NULL) AND isDeleted=0"
                        " EXCEPT SELECT imgidu FROM images WHERE NOT EXISTS"
                        " (SELECT 1 FROM imagesPixels AS px WHERE px.imgidu=images.imgidu AND px.small IS NOT NULL)"
                        " AND isDeleted=0);";
    const char *countNew = "SELECT count(*) FROM images WHERE NOT EXISTS (SELECT 1 FROM imagesPixels AS px"
                           " WHERE px.imgidu=images.imgidu AND px.small IS NOT NULL) AND isDeleted=0;";
    const char *countOld = "SELECT count(*) FROM images WHERE imgidu NOT IN (SELECT imgidu FROM imagesPixels"
                           " WHERE small IS NOT NULL) AND isDeleted=0;";
    const long long dA = scalar(db, diffA), dB = scalar(db, diffB);
    const long long cNew = scalar(db, countNew), cOld = scalar(db, countOld);
    printf("    %-62s %s\n", "the two row sets are identical, both ways round",
           (dA==0 && dB==0) ? "ok" : "FAILED");
    printf("    %-62s %s\n", "and getTotalIMGsSQLdb() counts the same population",
           (cNew==cOld && cNew > 0) ? "ok" : "FAILED");
    if (dA!=0 || dB!=0 || cNew!=cOld || cNew <= 0)
       problems++;

    printf("    (%lld of 900 images are still to collect: 300 have a fingerprint,"
           " 300 have a row with a NULL blob, 300 have no row at all, minus the deleted ones)\n", cNew);
    SQ.close_v2(db);
    remove("pool_equiv.sldb");
}

// ---------------------------------------------------------------------------------------
//  the AHK loop, and a 2 ms watcher over the same struct
// ---------------------------------------------------------------------------------------

struct Watch {
    std::atomic<bool> stop{false};
    std::atomic<int>  qMin{1 << 30}, qMax{-1}, fMin{1 << 30}, fMax{-1}, rMax{-1};
    std::atomic<long long> samples{0}, qZero{0};
    std::thread th;

    void reset() {
        qMin = 1 << 30; qMax = -1; fMin = 1 << 30; fMax = -1; rMax = -1;
        samples = 0; qZero = 0;
    }
    void start() {
        reset();
        stop = false;
        th = std::thread([this] {
            while (!stop.load())
            {
                // the same bytes AHK reads with NumGet(), read without the lock on purpose
                const int q = (int)dpState.queued, f = (int)dpState.inFlight, r = (int)dpState.ready;
                if (q < qMin.load()) qMin = q;
                if (q > qMax.load()) qMax = q;
                if (f < fMin.load()) fMin = f;
                if (f > fMax.load()) fMax = f;
                if (r > rMax.load()) rMax = r;
                if (q==0) qZero++;
                samples++;
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
            }
        });
    }
    void finish() { stop = true; if (th.joinable()) th.join(); }
};

struct ScenarioResult {
    int  samplesTaken = 0;
    int  maxQueuedEverSeen = 0;
    int  written = 0, failed = 0, dbErrors = 0, submitted = 0;
    double wallMs = 0;
    bool drainedWhileWorkersIdle = false;
    bool namedADecodingJob = false;      // dupesPixBusyJob() had something to say
    bool mirrorHeld = true;              // dpState.drained never disagreed with dpSelectDrained
};

// A transcription of collectImgDataViaPool()'s loop: the same 320 ms budget, the same nine
// reads, the same two second reporting interval, the same stall watch.
static ScenarioResult runScenario(const char *title, sqlite3 *db, int nRows, int decodeMs, int jitterMs,
                                  int sampleEveryMs, Watch &watch, const wchar_t *sel = NULL) {
    ScenarioResult out;
    printf("\n  %s\n", title);
    printf("    %d images, %d workers, decode %d-%d ms per image, dupesPixStep budget 320 ms\n",
           nRows, (int)dpWorkers.size(), decodeMs, decodeMs + jitterMs);

    gShimDecodeSleepMs = decodeMs;
    gShimDecodeJitterMs = jitterMs;

    if (dupesPixBegin(db, (sel!=NULL) ? sel : kSelect, L"350|5|0|0|1|1|1|1")!=1)
    {
       printf("    dupesPixBegin refused the run\n");
       problems++;
       return out;
    }

    exec(db, "BEGIN;");
    watch.start();
    const double t0 = nowMs();
    double prevMSGdisplay = t0, lastProgress = t0;
    int prevDone = -1, prevSampleWritten = 0;
    int lastQ = -1, lastF = -1;
    for (;;)
    {
        const double s0 = nowMs();
        const int more = dupesPixStep(320);
        const double stepMs = nowMs() - s0;

        // the nine NumGet()s of the tooltip, in the interpreter's order
        const int phase = (int)dpState.phase;
        const int queued = (int)dpState.queued;
        const int inFlight = (int)dpState.inFlight;
        const int ready = (int)dpState.ready;
        const int written = (int)dpState.written;
        const int failed = (int)dpState.failed;
        const int dbErrors = (int)dpState.dbErrors;
        const int submitted = (int)dpState.submitted;
        const int alive = (int)dpState.alive;
        const int countTFilez = written + failed + dbErrors;
        if (((int)dpState.drained!=0)!=dpSelectDrained)
           out.mirrorHeld = false;

        if (nowMs() - prevMSGdisplay > sampleEveryMs)
        {
           const double sinceMs = nowMs() - prevMSGdisplay;
           // the two lines collectImgDataViaPool() prints beside the nine counters
           wchar_t busyPath[512];
           int busyState = 0;
           const INT64 busyMs = dupesPixBusyJob(busyPath, 512, &busyState);
           if (busyMs >= 0 && busyState==2 && busyPath[0]!=0)
              out.namedADecodingJob = true;
           printf("    t=%6.1fs  phase=%d queued=%3d inFlight=%2d ready=%3d written=%6d failed=%d"
                  " dbErrors=%d submitted=%6d alive=%d | drained=%d cursor=%-6lld step=%4.0fms"
                  " %6.0f img/s  [2ms watcher: queued %d..%d, inFlight %d..%d, ready max %d]\n",
                  (nowMs() - t0)/1000.0, phase, queued, inFlight, ready, written, failed, dbErrors,
                  submitted, alive, dpSelectDrained ? 1 : 0, (long long)dpLastID, stepMs,
                  1000.0*(written - prevSampleWritten)/(sinceMs > 0 ? sinceMs : 1),
                  watch.qMin.load(), watch.qMax.load(), watch.fMin.load(), watch.fMax.load(),
                  watch.rMax.load());
           if (busyMs >= 0)
              printf("               oldest job: %.1fs %s %s\n", busyMs/1000.0,
                     (busyState==1) ? "WAITING for the shared decode slot" : "decoding",
                     WideCharToString(busyPath).c_str());
           out.samplesTaken++;
           prevSampleWritten = written;
           prevMSGdisplay = nowMs();
           if (dpSelectDrained && queued==0 && inFlight < (int)dpWorkers.size())
              out.drainedWhileWorkersIdle = true;
        }

        lastQ = queued;
        lastF = inFlight;
        if (more!=1)
           break;

        if (countTFilez!=prevDone) { prevDone = countTFilez; lastProgress = nowMs(); }
        else if (nowMs() - lastProgress > 180000)
        {
           printf("    the AHK stall watch would have fired here\n");
           break;
        }
    }

    out.wallMs = nowMs() - t0;
    watch.finish();
    exec(db, "COMMIT;");
    out.written = (int)dpState.written;
    out.failed = (int)dpState.failed;
    out.dbErrors = (int)dpState.dbErrors;
    out.submitted = (int)dpState.submitted;
    out.maxQueuedEverSeen = watch.qMax.load();
    dupesPixEnd();

    printf("    done in %.1fs: written=%d failed=%d dbErrors=%d submitted=%d;"
           " the queue was empty in %.1f%% of %lld watcher samples, deepest backlog %d\n",
           out.wallMs/1000.0, out.written, out.failed, out.dbErrors, out.submitted,
           100.0*(double)watch.qZero.load()/(double)(watch.samples.load() ? watch.samples.load() : 1),
           watch.samples.load(), out.maxQueuedEverSeen);
    (void)lastQ; (void)lastF;
    return out;
}

// ---------------------------------------------------------------------------------------
//  what one refill costs, and how that grows with the run
// ---------------------------------------------------------------------------------------
//
// dpTopUpQueue() resets and re-runs the SELECT on every call, and dupesPixStep() calls it on
// every iteration of its inner loop for as long as the queue is below its high water mark.
// The NOT IN subquery cannot be evaluated per row from an index because of its WHERE, so
// SQLite materialises it - a full walk of imagesPixels - once per CALL. That table is the one
// the run is filling, 2.2 KB per row.
static void refillCost() {
    printf("\n  what one refill of 31 rows costs as the run progresses\n");
    printf("    (this machine, warm page cache - a cold mechanical drive pays seek time on top\n"
           "     of every page these walks touch, and the images being decoded are on the same head)\n");
    printf("    %10s %14s %14s %14s\n", "collected", "old NOT IN", "shipped NOT EXISTS", "LEFT JOIN");
    const int totals = 40000;
    for ( int collected = 0 ; collected <= 32000 ; collected = collected ? collected*2 : 1000)
    {
        sqlite3 *db = buildDB("pool_cost.sldb", totals, collected, 0);
        if (db==NULL)
           return;

        struct Variant { const wchar_t *sql; double ms; };
        Variant vs[3] = {
            { kSelectNotIn, 0 },
            { kSelect, 0 },
            { L"SELECT i.imgidu, i.fullPath FROM images i LEFT JOIN imagesPixels p ON p.imgidu=i.imgidu"
              L" WHERE p.small IS NULL AND i.isDeleted=0 AND i.imgidu>?2 ORDER BY i.imgidu LIMIT ?1;", 0 }
        };

        for ( int v = 0 ; v < 3 ; v++)
        {
            sqlite3_stmt *st = NULL;
            if (SQ.prepare16_v2(db, vs[v].sql, -1, &st, NULL)!=SQLITE_OK || st==NULL)
            {
               printf("    variant %d would not prepare\n", v);
               problems++;
               continue;
            }

            // ten refills from where the run would be, exactly as dpTopUpQueue() runs them
            const double c0 = nowMs();
            const int reps = 10;
            int rows = 0;
            for ( int r = 0 ; r < reps ; r++)
            {
                SQ.reset(st);
                SQ.bind_int64(st, 1, 31);
                SQ.bind_int64(st, 2, collected);
                while (SQ.step(st)==SQLITE_ROW)
                    rows++;

                SQ.reset(st);
            }
            vs[v].ms = (nowMs() - c0)/reps;
            SQ.finalize(st);
            if (rows!=reps*31)
            {
               printf("    variant %d returned %d rows for %d refills of 31\n", v, rows, reps);
               problems++;
            }
        }

        printf("    %10d %11.2f ms %11.2f ms %11.2f ms\n", collected, vs[0].ms, vs[1].ms, vs[2].ms);
        SQ.close_v2(db);
        remove("pool_cost.sldb");
    }
}

// ---------------------------------------------------------------------------------------

int main(int argc, char **argv) {
    bindSQLiteOnce();
    if (!SQ.ok || SQ.exec==NULL || SQ.bind_double==NULL || SQ.bind_blob==NULL)
    {
       printf("  SKIPPED: libsqlite3.so.0 is not available\n");
       return 0;
    }

    for ( int i = 0 ; i < 256 ; i++) gShimHistogram[i] = 4;
    tpWicExts.clear();
    tpFimExts.clear();
    tpWicExts.insert(L"jpg");
    FIM.ok = true;
    m_pIWICFactory = (IWICImagingFactory*)1;

    clausesAgree();

    const bool costOnly = (argc > 1 && strcmp(argv[1], "cost")==0);
    if (costOnly)
    {
       refillCost();
       printf("\n  %s\n", problems ? "PROBLEMS" : "no problems");
       return problems ? 1 : 0;
    }

    if (dupesPixInit(8) < 8)
    {
       printf("  the pool would not start 8 workers\n");
       return 1;
    }

    Watch watch;
    // 1. an SSD: the decode is faster than the refill that feeds it
    {
        sqlite3 *db = buildDB("pool_ssd.sldb", 4000, 0, 0);
        if (db!=NULL)
        {
           runScenario("an SSD-like drive", db, 4000, 2, 2, 2000, watch);
           SQ.close_v2(db);
           remove("pool_ssd.sldb");
        }
    }

    // 2. a mechanical drive: every decode waits on the head
    {
        sqlite3 *db = buildDB("pool_hdd.sldb", 600, 0, 0);
        if (db!=NULL)
        {
           const ScenarioResult r = runScenario("a mechanical drive - slow decodes, nothing else changed",
                                                db, 600, 220, 160, 2000, watch);
           printf("    => a slow CONSUMER keeps the queue FULL: the deepest backlog seen was %d,"
                  " and the queue was never the thing missing\n", r.maxQueuedEverSeen);
           SQ.close_v2(db);
           remove("pool_hdd.sldb");
        }
    }

    // 3. the same drive, with one file per 200 that takes 25 times as long. The tail of the
    //    run is the interesting part: the cursor drains, and what is left is stragglers.
    {
        sqlite3 *db = buildDB("pool_tail.sldb", 400, 0, 200);
        if (db!=NULL)
        {
           const ScenarioResult r = runScenario("the same drive with a few huge files - watch the tail",
                                                db, 400, 60, 40, 1500, watch);
           printf("    %-62s %s\n", "the straggler that holds the run open is named",
                  r.namedADecodingJob ? "ok" : "FAILED");
           printf("    %-62s %s\n", "and dpState.drained never disagreed with the flag itself",
                  r.mirrorHeld ? "ok" : "FAILED");
           if (!r.namedADecodingJob || !r.mirrorHeld)
              problems++;

           printf("    => %s\n", r.drainedWhileWorkersIdle
                  ? "reproduced: at the tail the cursor is drained, the queue is empty and the"
                    " workers that are left are idle - queued=0 with a low inFlight"
                  : "the tail did not reproduce the reported reading");
           SQ.close_v2(db);
           remove("pool_tail.sldb");
        }
    }

    // 4a/4b. the producer's own limit, with the decoders deliberately cheap. Nothing about the
    //    disk changes here; what changes is how many rows imagesPixels already holds, which
    //    is what every refill of the queue has to walk past. This is the regime the reported
    //    SSD reading sits in: queued well below the high water mark of 32, every worker busy.
    {
        double shipped = 0, exists = 0;
        sqlite3 *db = buildDB("pool_prod.sldb", 20000, 0, 0);
        if (db!=NULL)
        {
           shipped = runScenario("a fast drive, and a library the run keeps making bigger", db, 20000,
                                 2, 2, 4000, watch).wallMs;
           SQ.close_v2(db);
           remove("pool_prod.sldb");
        }

        // the same run, the same pool, the same decoders - only the way the refill asks for
        // "no fingerprint yet" differs. NOT EXISTS is answered from imagesPixels' own primary
        // key, one probe per candidate row, instead of a fresh copy of the whole table.
        db = buildDB("pool_prod2.sldb", 20000, 0, 0);
        if (db!=NULL)
        {
           exists = runScenario("the same run, with the NOT IN this replaced", db, 20000,
                                2, 2, 4000, watch, kSelectNotIn).wallMs;
           SQ.close_v2(db);
           remove("pool_prod2.sldb");
        }

        if (shipped > 0 && exists > 0)
           printf("    => %.1fs with NOT EXISTS vs %.1fs with the old NOT IN: %.2fx"
                  " on the same decoders\n", shipped/1000.0, exists/1000.0, exists/shipped);
    }

    // with nothing running there is nothing to name, and nothing left marked busy either
    {
        wchar_t idlePath[64] = {L'x', 0};
        int idleState = 7;
        const INT64 idleMs = dupesPixBusyJob(idlePath, 64, &idleState);
        printf("\n    %-62s %s\n", "an idle pool reports no job at all",
               (idleMs==-1 && idlePath[0]==0 && idleState==0) ? "ok" : "FAILED");
        if (idleMs!=-1 || idlePath[0]!=0 || idleState!=0)
           problems++;
    }

    dupesPixShutdown();
    refillCost();
    printf("\n  %s\n", problems ? "PROBLEMS" : "no problems");
    return problems ? 1 : 0;
}
