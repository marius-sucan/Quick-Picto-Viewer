// What the hash-generation loop costs, and where the cost goes.
//
// This is a BENCHMARK, not a correctness test - query_engine.cpp is what pins the result
// contract. What it answers is the two claims the comments make, on the machine reading
// them rather than on the one they were written on:
//
//   - what one batch costs as the run progresses, for the keyset cursor
//     generateSQLimageFingerPrintHash() sends and for the plain "LIMIT ?1" it falls back
//     to when the qpvmain.dll beside it predates dupesHashHasKeyset(). Nothing indexes
//     "dHash IS NULL", so the plain form restarts the scan at the first image of the
//     library on every batch and walks past everything already hashed; the claim is that
//     this grows with the run and that the cursor is flat.
//   - whether pHash is worth handing to a crew and the other two hashes are not, which is
//     what the worthATeam argument of dupesParallelFor() decides. dupesSweepSetThreads()
//     pins the width from outside, so the same batch can be run both ways.
//
// The loop is the shipped dupesHashBegin/Step/End, sliced out of dupes-search.h the way
// query_engine.cpp slices it, driven against a real SQLite through sqlite-dynamic.h with
// the real schema and the real indexes. Only the images are synthetic - the fingerprints
// are bytes, and a hash does not care where its bytes came from.
//
// Treat the absolute numbers as an order of magnitude - GCC's inliner is not MSVC's, and a
// mechanical drive pays seek time on every page these walks touch - and the ratios between
// the shapes as the real result.
//
// Usage:  ./hash_bench [images]        default 200000; 20000 for a quick look
//
// written by Marius Șucan with Claude Opus 5

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <chrono>
#include <atomic>
#include <mutex>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <algorithm>
#include <array>
#include <emmintrin.h>
#include <windows.h>             // tests/shim/windows.h, via -Ishim

#define DLL_API extern "C"
#define DLL_CALLCONV
#define QPV_FORCEINLINE inline __attribute__((always_inline))

__attribute__((unused)) static void fnOutputDebug(std::string) {}
static void SetWindowText(HWND, LPCWSTR) {}

#include "../sqlite-dynamic.h"
#include "header_extract.h"

const double div2sz = sqrt(2.0 / 32.0);
const double div2sq = 1 / sqrt(2.0);
std::array<double, 1025> DCTcoeffs;

#include "dct_extract.cpp"
#include "block_extract.cpp"
#include "query_extract.cpp"

#define SQLITE_OPEN_CREATE 0x00000004

static std::wstring widen(const std::string &s) {
    std::wstring w;
    for ( size_t i = 0 ; i < s.size() ; i++)
        w.push_back((wchar_t)(unsigned char)s[i]);

    return w;
}

static double nowMs() {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

static int problems = 0;

static void exec(sqlite3 *db, const char *sql) {
    const std::wstring w = widen(sql);
    sqlite3_stmt *st = NULL;
    if (SQ.prepare16_v2(db, w.c_str(), -1, &st, NULL)!=SQLITE_OK || st==NULL)
    {
       printf("    SQL would not prepare: %.70s\n", sql);
       problems++;
       return;
    }

    while (SQ.step(st)==SQLITE_ROW) {}
    SQ.finalize(st);
}

static long long scalar(sqlite3 *db, const char *sql) {
    const std::wstring w = widen(sql);
    sqlite3_stmt *st = NULL;
    long long v = -1;
    if (SQ.prepare16_v2(db, w.c_str(), -1, &st, NULL)!=SQLITE_OK || st==NULL)
       return -1;

    if (SQ.step(st)==SQLITE_ROW)
       v = SQ.column_int64(st, 0);

    SQ.finalize(st);
    return v;
}

// The schema of make_test_db.py, which is the schema of the shipped database: imgidu is a
// NUMERIC primary key and so is NOT the rowid, the two indexes SLDBindexesSQL() creates are
// here, and nothing indexes any of the hash columns - which is the whole point.
static const char *kSchema[] = {
 "CREATE TABLE images (imgidu NUMERIC PRIMARY KEY NOT NULL, imgfile TEXT COLLATE NOCASE NOT NULL,"
 " imgfolder TEXT COLLATE NOCASE NOT NULL, fullPath TEXT AS (imgfolder||'\\'||imgfile), fsize INT,"
 " kbfsize FLOAT AS (round(cast(fsize AS float)/1024,1)), fmodified INT, fcreated INT, imgwidth INT,"
 " imgheight INT, imgframes INT, imgdpi INT, imgpixfmt TEXT COLLATE NOCASE,"
 " imgwhratio FLOAT AS (round(cast(imgwidth AS float)/imgheight, 5)),"
 " imgmegapix FLOAT AS (round((cast(imgwidth AS float)*imgheight)/1000000, 5)), imgmedian FLOAT,"
 " imgavg FLOAT, imghpeak FLOAT, imghlow FLOAT, imghmode FLOAT, imghrms FLOAT, imghminu FLOAT,"
 " imghrange FLOAT, dHash TEXT, pHash TEXT, lHash TEXT, HdHash TEXT, HpHash TEXT, HlHash TEXT,"
 " isDeleted INT DEFAULT 0, UNIQUE (fullPath));",
 "CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY NOT NULL, small BLOB, big BLOB,"
 " smallH BLOB, bigH BLOB);",
 "CREATE INDEX imgsIndex ON images(imgidu, imgfolder, imgfile);",
 "CREATE INDEX imgsAliveIndex ON images(isDeleted);",
 NULL };

static sqlite3 *buildDB(const char *path, int n) {
    remove(path);
    sqlite3 *db = NULL;
    if (SQ.open_v2(path, &db, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE, NULL)!=SQLITE_OK || db==NULL)
       return NULL;

    exec(db, "PRAGMA temp_store=MEMORY;");
    exec(db, "PRAGMA cache_size=-65536;");     // the two the application sets
    for ( int i = 0 ; kSchema[i]!=NULL ; i++)
        exec(db, kSchema[i]);

    const std::wstring wins = widen("INSERT INTO images (imgidu,imgfile,imgfolder,fsize,fmodified,"
        "fcreated,imgwidth,imgheight,imgframes,imgdpi,imgpixfmt,imgmedian,imgavg,isDeleted)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
    const std::wstring wpix = widen("INSERT INTO imagesPixels (imgidu,small,big) VALUES (?,?,?)");
    sqlite3_stmt *ins = NULL, *insp = NULL;
    if (SQ.prepare16_v2(db, wins.c_str(), -1, &ins, NULL)!=SQLITE_OK
     || SQ.prepare16_v2(db, wpix.c_str(), -1, &insp, NULL)!=SQLITE_OK)
    {
       printf("    could not prepare the inserts\n");
       problems++;
       return NULL;
    }

    unsigned char small[72], big[1024];
    unsigned int seed = 12345;
    for ( int i = 0 ; i < 1024 ; i++)
    {
        seed = seed * 1103515245u + 12345u;
        if (i < 72)
           small[i] = (unsigned char)((seed >> 16) & 0xFF);

        big[i] = (unsigned char)((seed >> 8) & 0xFF);
    }

    exec(db, "BEGIN");
    const std::wstring fmt = widen("24-RGB");
    for ( int i = 1 ; i <= n ; i++)
    {
        char f[64], d[64];
        snprintf(f, sizeof(f), "IMG_%08d.jpg", i);
        snprintf(d, sizeof(d), "D:\\photos\\%04d", i % 3000);
        const std::wstring wf = widen(f), wd = widen(d);
        SQ.reset(ins);
        SQ.bind_int64(ins, 1, i);
        SQ.bind_text16(ins, 2, wf.c_str(), -1, QPV_SQLITE_TRANSIENT);
        SQ.bind_text16(ins, 3, wd.c_str(), -1, QPV_SQLITE_TRANSIENT);
        SQ.bind_int64(ins, 4, 1234567 + i);
        SQ.bind_int64(ins, 5, 1700000000 + i);
        SQ.bind_int64(ins, 6, 1700000000 + i);
        SQ.bind_int64(ins, 7, 4000);
        SQ.bind_int64(ins, 8, 3000);
        SQ.bind_int64(ins, 9, 1);
        SQ.bind_int64(ins, 10, 300);
        SQ.bind_text16(ins, 11, fmt.c_str(), -1, QPV_SQLITE_TRANSIENT);
        SQ.bind_double(ins, 12, 128.5);
        SQ.bind_double(ins, 13, 130.2);
        SQ.bind_int64(ins, 14, (i % 37==0) ? 1 : 0);   // a few retired images, as a library has
        SQ.step(ins);

        SQ.reset(insp);
        SQ.bind_int64(insp, 1, i);
        SQ.bind_blob(insp, 2, small, 72, QPV_SQLITE_STATIC);
        SQ.bind_blob(insp, 3, big, 1024, QPV_SQLITE_STATIC);
        SQ.step(insp);
    }

    exec(db, "COMMIT");
    SQ.finalize(ins);
    SQ.finalize(insp);
    return db;
}

// One whole run of the shipped loop, driven the way generateSQLimageFingerPrintHash()
// drives it: one transaction around the lot, dupesHashStep(512) until it stops answering 1.
struct RunResult { double wall, first, last, worst; int batches; long long rows; };

static RunResult runHashLoop(sqlite3 *db, const char *hashCol, const char *pixCol,
                             int kind, int pixCount, bool keyset, int gray, bool plusHint = true) {
    RunResult r; r.wall = r.first = r.last = r.worst = 0; r.batches = 0; r.rows = 0;

    exec(db, (std::string("UPDATE images SET ") + hashCol + "=NULL").c_str());
    // the unary plus is what generateSQLimageFingerPrintHash() sends: it disqualifies
    // isDeleted from being answered from an index, which is the only way the planner will
    // drive the query off imgidu and satisfy the ORDER BY without sorting
    std::string sel = std::string("SELECT images.imgidu, p.") + pixCol
                    + " FROM images LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                    + " WHERE " + (plusHint ? "+" : "") + "images.isDeleted=0 AND p." + pixCol + " IS NOT NULL"
                    + " AND " + hashCol + " IS NULL";
    if (keyset)
       sel += " AND images.imgidu>?2 ORDER BY images.imgidu";

    sel += " LIMIT ?1;";
    const std::wstring wsel = widen(sel);
    const std::wstring wupd = widen(std::string("UPDATE images SET ") + hashCol + "=?1 WHERE imgidu=?2;");
    if (dupesHashBegin(db, wsel.c_str(), wupd.c_str(), kind, pixCount, gray, 1)!=1)
    {
       printf("    dupesHashBegin refused the query\n");
       problems++;
       return r;
    }

    exec(db, "BEGIN");
    const double t0 = nowMs();
    for (;;)
    {
        const double a = nowMs();
        const int more = dupesHashStep(512);
        const double d = nowMs() - a;
        if (more < 0)
        {
           printf("    the loop reported an error\n");
           problems++;
           break;
        }

        // the call that answers 0 read nothing and did nothing; it is the end of the run,
        // not a batch of it, so it is not what "last" means here
        if (more==0)
           break;

        r.batches++;
        if (r.batches==1)
           r.first = d;

        r.last = d;
        if (d > r.worst)
           r.worst = d;
    }

    r.wall = nowMs() - t0;
    r.rows = dupesHashWrittenCount();
    exec(db, "COMMIT");
    dupesHashEnd();
    return r;
}

static void report(const char *label, const RunResult &r) {
    printf("    %-40s %8.2f s   first batch %7.2f ms, last %7.2f ms, worst %7.2f ms   %d batches\n",
           label, r.wall/1000, r.first, r.last, r.worst, r.batches);
}

// What one image costs each hash, with nothing else in the way. The crew decision rests on
// this and on nothing else: the crew costs the same to start whatever it is asked to do.
static void perImageCost() {
    printf("\n  what one image costs each hash, on this core\n");
    const int BATCH = 512;
    std::vector<int> small((size_t)BATCH * 72), big((size_t)BATCH * 1024);
    unsigned int seed = 999;
    for ( size_t i = 0 ; i < big.size() ; i++)
    {
        seed = seed * 1103515245u + 12345u;
        if (i < small.size())
           small[i] = (int)((seed >> 16) & 0xFF);

        big[i] = (int)((seed >> 8) & 0xFF);
    }

    UINT64 sink = 0;
    for ( int kind = 0 ; kind < 3 ; kind++)
    {
        const int *base = (kind==2) ? big.data() : small.data();
        const int stride = (kind==2) ? 1024 : 72;
        const char *nm = (kind==0) ? "dHash" : (kind==1) ? "lHash" : "pHash";
        const int reps = (kind==2) ? 20 : 400;
        const double t0 = nowMs();
        for ( int r = 0 ; r < reps ; r++)
            for ( int i = 0 ; i < BATCH ; i++)
            {
                const int *p = base + (size_t)i * stride;
                sink += (kind==0) ? dupesDHash(p) : (kind==1) ? dupesLHash(p) : dupesPHash(p, 1);
            }

        const double per = (nowMs() - t0)/reps;
        printf("    %-6s %8.3f ms for a batch of %d   (%7.2f us per image)\n", nm, per, BATCH, per*1000/BATCH);
    }

    // one empty crew, which is what a batch pays for asking
    const double t0 = nowMs();
    const int reps = 200;
    for ( int r = 0 ; r < reps ; r++)
        dupesParallelFor(512, [](int) {}, true);

    printf("    %-6s %8.3f ms                            (starting and joining %d threads)\n",
           "crew", (nowMs() - t0)/reps, dupesSweepSetThreads(0));
    if (sink==1) printf(" ");
}

int main(int argc, char **argv) {
    bindSQLiteOnce();
    if (!SQ.ok)
    {
       printf("  SKIPPED: libsqlite3.so.0 is not available\n");
       return 0;
    }

    calculateDCTcoeffs(32);
    const int n = (argc > 1) ? atoi(argv[1]) : 200000;
    printf("  %d images, batches of 512, %d hardware threads\n", n, dupesSweepSetThreads(0));

    sqlite3 *db = buildDB("hash_bench.sldb", n);
    if (db==NULL)
    {
       printf("  could not build the database\n");
       return 1;
    }

    const long long live = scalar(db, "SELECT count(*) FROM images WHERE isDeleted=0");
    printf("  %lld of them live and carrying a fingerprint\n", live);

    printf("\n  the cursor: dHash over the whole library, both query shapes\n");
    report("keyset cursor, as sent now", runHashLoop(db, "dHash", "small", 2, 72, true, 1));
    report("plain LIMIT, the older fallback", runHashLoop(db, "dHash", "small", 2, 72, false, 1));
    report("keyset, but without the unary plus", runHashLoop(db, "dHash", "small", 2, 72, true, 1, false));

    printf("\n  the crew: pHash over the whole library, keyset cursor\n");
    dupesSweepSetThreads(1);
    report("pinned to one worker", runHashLoop(db, "pHash", "big", 3, 1024, true, 1));
    const int hw = dupesSweepSetThreads(0);
    char lbl[64];
    snprintf(lbl, sizeof(lbl), "one worker per hardware thread (%d)", hw);
    report(lbl, runHashLoop(db, "pHash", "big", 3, 1024, true, 1));

    // dupesHashBegin() builds discretizeValue() into a 256 entry table once per run, so
    // the compressor level is a load either way. It used to be a divide, a floor and a
    // multiply per byte - 1024 of them per pHash image - and these two lines were far apart.
    printf("\n  the fingerprint decode: pHash at graylevelCompressor 1 and 9\n");
    report("compressor 1, the default", runHashLoop(db, "pHash", "big", 3, 1024, true, 1));
    report("compressor 9, the heaviest", runHashLoop(db, "pHash", "big", 3, 1024, true, 9));

    perImageCost();

    SQ.close_v2(db);
    remove("hash_bench.sldb");
    printf("\n  %s\n", problems ? "HASH BENCH HIT PROBLEMS" : "hash bench done");
    return problems ? 1 : 0;
}
