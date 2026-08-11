// Runs the shipped candidate-query engine against a real SQLite database.
//
// This is the one part of the duplicate pipeline that can be tested properly off Windows:
// the engine binds sqlite3 at run time through sqlite-dynamic.h, so pointing that binder
// at libsqlite3.so instead of sqlite3.dll gives the genuine article. The database is built
// by tests/make_test_db.py with the real images schema, and the reference answer is
// produced by the self-join the engine replaced - run here through the same sqlite3.
//
// What must hold, and what a naive ordered scan gets wrong:
//   - the same images in the same groups as the self-join, including the rule that a row
//     with a NULL in any grouping column is not a candidate at all;
//   - COLLATE NOCASE columns (imgfile, imgpixfmt) group case-insensitively;
//   - fingerprints and hashes come back decoded and attached to the right rows;
//   - the paths and metadata AHK reads back match the database row for row;
//   - a keep-mask drops rows and re-cuts the groups around them.
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

__attribute__((unused)) static void fnOutputDebug(std::string s) {
    if (getenv("QPV_TEST_VERBOSE")) printf("    [dbg] %s\n", s.c_str());
}
static void SetWindowText(HWND, LPCWSTR) {}

#include "../sqlite-dynamic.h"   // verbatim, the shipped run-time binder
#include "header_extract.h"      // verbatim from dupes-search.h

// three literal declarations from dupes-search.h, outside the sliced region
const double div2sz = sqrt(2.0 / 32.0);
const double div2sq = 1 / sqrt(2.0);
std::array<double, 1025> DCTcoeffs;

#include "dct_extract.cpp"       // verbatim: calculateDCT + calcPHashAlgo, for pHash
#include "block_extract.cpp"     // verbatim from dupes-search.h: the sweep
#include "query_extract.cpp"     // verbatim from dupes-search.h: the query engine

// ---- helpers -------------------------------------------------------------------------

static int failures = 0;
static void check(bool ok, const char *what) {
    printf("    %-62s %s\n", what, ok ? "ok" : "FAILED");
    if (!ok) failures++;
}

static std::wstring widen(const std::string &s) {
    std::wstring w;
    for (size_t i = 0; i < s.size(); i++) w.push_back((wchar_t)(unsigned char)s[i]);
    return w;
}

// A second, independent connection for the reference queries, opened straight through
// the bound API rather than through the engine.
static sqlite3 *refDB = NULL;

static std::vector<std::vector<std::string> > refQuery(const std::string &sql, int cols) {
    std::vector<std::vector<std::string> > out;
    sqlite3_stmt *st = NULL;
    const std::wstring w = widen(sql);
    if (SQ.prepare16_v2(refDB, w.c_str(), -1, &st, NULL)!=SQLITE_OK || st==NULL)
    {
        printf("    reference query failed: %s\n", sql.c_str());
        failures++;
        return out;
    }
    while (SQ.step(st)==SQLITE_ROW)
    {
        std::vector<std::string> row;
        for (int c = 0; c < cols; c++)
        {
            const wchar_t *t = (const wchar_t*)SQ.column_text16(st, c);
            std::string s;
            if (t) for (const wchar_t *p = t; *p; p++) s.push_back((char)(*p & 0xFF));
            row.push_back(s);
        }
        out.push_back(row);
    }
    SQ.finalize(st);
    return out;
}

// The fingerprints are raw BLOBs in imagesPixels since schema v3, so they come back
// byte for byte and need no wchar_t adapter at all - the shim only has to lie about the
// *16 text entry points.
static std::vector<unsigned char> refQueryBlob(const std::string &sql, bool &found) {
    std::vector<unsigned char> out;
    found = false;
    sqlite3_stmt *st = NULL;
    const std::wstring w = widen(sql);
    if (SQ.prepare16_v2(refDB, w.c_str(), -1, &st, NULL)!=SQLITE_OK || st==NULL)
       return out;

    if (SQ.step(st)==SQLITE_ROW)
    {
       const unsigned char *b = (const unsigned char*)SQ.column_blob(st, 0);
       const int n = SQ.column_bytes(st, 0);
       if (b!=NULL && n > 0)
       {
          out.assign(b, b + n);
          found = true;
       }
    }
    SQ.finalize(st);
    return out;
}

struct ColSet {
    const char *cols;
    int         prec;
    const char *notnull;
    int         wantHash;
    int         wantPix;
};

static const char *NOT_FLOATS[] = {"fcreated","fmodified","fsize","imgfile","dHash","lHash",
                                   "pHash","imgwidth","imgheight","imgframes","imgdpi","imgpixfmt", NULL};
static bool isNotFloat(const std::string &c) {
    for (int i = 0; NOT_FLOATS[i]; i++) if (c==NOT_FLOATS[i]) return true;
    return false;
}
static bool isNocase(const std::string &c) {
    return (c=="imgfile" || c=="imgpixfmt" || c=="imgfolder");
}

static std::vector<std::string> split(const std::string &s, char sep) {
    std::vector<std::string> out;
    size_t a = 0;
    for (;;) {
        const size_t b = s.find(sep, a);
        if (b==std::string::npos) { out.push_back(s.substr(a)); break; }
        out.push_back(s.substr(a, b - a));
        a = b + 1;
    }
    return out;
}

static std::string selExpr(const std::string &c, int prec) {
    if (isNotFloat(c)) return c;
    char buf[128];
    snprintf(buf, sizeof(buf), "Round(%s,%d)", c.c_str(), prec);
    return buf;
}

// The self-join retrieveDupesByProperties() used before the engine took over.
static std::string oldSQL(const std::vector<std::string> &cols, int prec, const char *notnull) {
    std::string selcols, grp, on;
    for (size_t i = 0; i < cols.size(); i++)
    {
        if (i) { selcols += ", "; grp += ", "; on += " AND "; }
        selcols += selExpr(cols[i], prec) + " AS " + cols[i];
        grp += selExpr(cols[i], prec);
        on += (isNotFloat(cols[i]) ? ("a." + cols[i]) : ("Round(a." + cols[i] + "," + std::to_string(prec) + ")"))
            + " = b." + cols[i];
    }
    return "SELECT a.imgidu, b.groupID FROM images AS a JOIN (SELECT " + selcols +
           ", ROWID AS groupID FROM images WHERE isDeleted=0 AND ifnull(" + notnull +
           ",'')!='' GROUP BY " + grp + " HAVING count(*)>1) AS b ON (" + on +
           ") WHERE a.isDeleted=0 AND ifnull(a." + std::string(notnull) + ",'')!=''";
}

// What AHK now builds for the engine: a plain ordered scan, columns in the fixed layout
// dupesQueryBegin() documents.
static std::string newSQL(const std::vector<std::string> &cols, int prec, const char *notnull,
                          bool wantHash, bool wantFlip, bool wantPix) {
    std::string s = "SELECT images.imgidu, fullPath, imgmegapix, fsize";
    if (wantHash) s += ", dHash";
    if (wantFlip) s += ", HdHash";
    if (wantPix)  s += ", p.big";
    std::string order;
    for (size_t i = 0; i < cols.size(); i++)
    {
        s += ", " + selExpr(cols[i], prec) + " AS k" + std::to_string(i);
        if (i) order += ", ";
        order += "k" + std::to_string(i);
    }
    s += " FROM images";
    if (wantPix) s += " LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu";
    s += " WHERE images.isDeleted=0 AND ifnull(" + std::string(notnull) + ",'')!=''";
    if (wantFlip) s += " AND ifnull(dHash,'')!=''";
    s += " ORDER BY " + order + ", imgmegapix, fsize";
    return s;
}

typedef std::set<std::set<long long> > Partition;

static Partition partitionOf(const std::map<long long, std::vector<long long> > &byGroup) {
    Partition p;
    for (std::map<long long, std::vector<long long> >::const_iterator it = byGroup.begin(); it != byGroup.end(); ++it)
        if (it->second.size() > 1)
           p.insert(std::set<long long>(it->second.begin(), it->second.end()));
    return p;
}

static UINT nocaseMaskFor(const std::vector<std::string> &cols) {
    UINT m = 0;
    for (size_t i = 0; i < cols.size(); i++) if (isNocase(cols[i])) m |= (1u << i);
    return m;
}

// ---- the grouping equivalence --------------------------------------------------------

static void groupingMatchesSelfJoin(const char *dbPath) {
    static const ColSet sets[] = {
        {"imgwhratio,imgframes",                                            1, "dHash", 1, 1},
        {"imgwhratio,imgframes",                                            5, "dHash", 1, 0},
        {"fsize,imgmegapix,imgwhratio,imgframes",                           2, "dHash", 1, 1},
        {"kbfsize,imgframes,imgmegapix,imgwhratio,imgavg,imghpeak,imgmedian,imghlow", 2, "dHash", 0, 0},
        {"imgfile,imgframes",                                               1, "dHash", 0, 0},
        {"fsize,imgfile,imgframes",                                         1, "dHash", 1, 0},
        {"imgpixfmt,imgwidth,imgheight",                                    1, "dHash", 1, 1},
        {"imgmedian,imgavg,imghpeak",                                       3, "dHash", 0, 0},
        {"fcreated,fmodified",                                              1, "dHash", 0, 0},
        {"imgdpi,imgpixfmt",                                                1, "dHash", 1, 0},
        {"imgmegapix",                                                      0, "dHash", 1, 1},
        {"imgavg,imghrms,imghmode,imghminu,imghrange",                      2, "dHash", 0, 0},
    };
    const int n = (int)(sizeof(sets)/sizeof(sets[0]));

    int mismatches = 0, totalGroups = 0, totalRows = 0;
    for (int s = 0; s < n; s++)
    {
        const std::vector<std::string> cols = split(sets[s].cols, ',');

        std::map<long long, std::vector<long long> > refByGroup;
        const std::vector<std::vector<std::string> > ref = refQuery(oldSQL(cols, sets[s].prec, sets[s].notnull), 2);
        for (size_t i = 0; i < ref.size(); i++)
            refByGroup[atoll(ref[i][1].c_str())].push_back(atoll(ref[i][0].c_str()));

        const std::wstring sql = widen(newSQL(cols, sets[s].prec, sets[s].notnull,
                                              sets[s].wantHash!=0, false, sets[s].wantPix!=0));
        if (!dupesQueryBegin(sql.c_str(), (int)cols.size(), nocaseMaskFor(cols),
                             sets[s].wantHash, 0, sets[s].wantPix, 1024, 1))
        {
            printf("    dupesQueryBegin failed for %s\n", sets[s].cols);
            failures++;
            continue;
        }
        while (dupesQueryStep(/*msBudget*/ 1) > 0) {}

        std::map<long long, std::vector<long long> > gotByGroup;
        std::vector<DupeCandRow> rows(dupesQueryRowCount());
        if (!rows.empty())
           dupesFetchRows(rows.data(), 0, (UINT)rows.size());
        for (size_t i = 0; i < rows.size(); i++)
            gotByGroup[rows[i].groupID].push_back(rows[i].imgidu);

        totalRows += (int)rows.size();
        totalGroups += (int)gotByGroup.size();
        if (partitionOf(refByGroup)!=partitionOf(gotByGroup))
        {
            mismatches++;
            printf("    MISMATCH cols=%s prec=%d  selfjoin=%d groups, scan=%d groups\n",
                   sets[s].cols, sets[s].prec, (int)partitionOf(refByGroup).size(),
                   (int)partitionOf(gotByGroup).size());
        }
    }

    char msg[160];
    snprintf(msg, sizeof(msg), "%d column sets, %d candidates in %d groups: same as the self-join",
             n, totalRows, totalGroups);
    check(mismatches==0, msg);
    check(totalRows > 100 && totalGroups > 20, "the test database really does contain duplicates");
    (void)dbPath;
}

// ---- the rows AHK reads back ---------------------------------------------------------

static void rowsMatchTheDatabase() {
    const std::vector<std::string> cols = split("imgpixfmt,imgwidth,imgheight", ',');
    const std::wstring sql = widen(newSQL(cols, 1, "dHash", true, true, true));
    check(dupesQueryBegin(sql.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 1, 1, 1024, 1)==1,
          "dupesQueryBegin accepts the flipped-hash + fingerprint layout");
    while (dupesQueryStep(150) > 0) {}

    const UINT n = dupesQueryRowCount();
    std::vector<DupeCandRow> rows(n);
    if (n) dupesFetchRows(rows.data(), 0, n);
    const wchar_t *paths = (const wchar_t*)dupesGetPathBuffer();

    // every candidate's path, fsize and megapix must be what the database holds
    int bad = 0, checked = 0, withPix = 0;
    for (UINT i = 0; i < n; i += 7)
    {
        char q[256];
        snprintf(q, sizeof(q), "SELECT fullPath, fsize, imgmegapix, ifnull((SELECT length(big) FROM imagesPixels WHERE imgidu=images.imgidu),0) FROM images WHERE imgidu=%lld",
                 (long long)rows[i].imgidu);
        const std::vector<std::vector<std::string> > r = refQuery(q, 4);
        if (r.size()!=1) { bad++; continue; }

        std::string got;
        for (const wchar_t *p = paths + rows[i].pathOffset; *p; p++) got.push_back((char)(*p & 0xFF));
        if (got!=r[0][0]) bad++;
        else if (atoll(r[0][1].c_str())!=rows[i].fsize) bad++;
        else if (fabs(atof(r[0][2].c_str()) - rows[i].megapix) > 1e-9) bad++;
        if (atoi(r[0][3].c_str())==1024) withPix++;
        checked++;
    }
    check(checked > 10, "enough rows sampled to be meaningful");
    check(bad==0, "path, fsize and megapix match the database row for row");
    check(withPix > 0, "the sample includes rows that carry a fingerprint");

    // fingerprints have to land on the right row: read one straight from the database and
    // compare it with what the engine put in the sweep's byte array
    int pixBad = 0, pixChecked = 0, pixAbsent = 0;
    for (UINT i = 0; i < n && pixChecked < 25; i++)
    {
        char q[256];
        snprintf(q, sizeof(q), "SELECT big FROM imagesPixels WHERE imgidu=%lld", (long long)rows[i].imgidu);
        bool found = false;
        const std::vector<unsigned char> r = refQueryBlob(q, found);
        if (!found || r.size()!=1024)
        {
            if (dupesPixOK[i]!=0) pixBad++;   // no fingerprint stored -> must be flagged absent
            else pixAbsent++;
            continue;
        }
        if (dupesPixOK[i]!=1) { pixBad++; continue; }
        for (int k = 0; k < 1024; k++)
        {
            if (dupesPixData[(size_t)i * 1024 + k] != r[k]) { pixBad++; break; }
        }
        pixChecked++;
    }
    check(pixChecked > 5 && pixBad==0, "fingerprints decode to the stored bytes, on the right rows");
    check(pixAbsent > 0, "and a row with no fingerprint is flagged absent, not decoded as zeros");

    // the hashes: parsed straight out of the hex text
    int hashBad = 0, hashChecked = 0;
    for (UINT i = 0; i < n && hashChecked < 25; i += 3)
    {
        char q[256];
        snprintf(q, sizeof(q), "SELECT dHash, ifnull(HdHash,'') FROM images WHERE imgidu=%lld", (long long)rows[i].imgidu);
        const std::vector<std::vector<std::string> > r = refQuery(q, 2);
        if (r.size()!=1) continue;
        const UINT64 want = strtoull(r[0][0].c_str(), NULL, 16);
        if (dupesScanHashes[i]!=want) hashBad++;
        const UINT64 wantFlip = r[0][1].empty() ? want : strtoull(r[0][1].c_str(), NULL, 16);
        if (dupesScanFlipped[i]!=wantFlip) hashBad++;
        hashChecked++;
    }
    check(hashChecked > 5 && hashBad==0, "hashes parse to the stored value; a missing flip mirrors it");
}

// ---- the keep mask -------------------------------------------------------------------

static void keepMaskRecutsGroups() {
    const std::vector<std::string> cols = split("imgwhratio,imgframes", ',');
    const std::wstring sql = widen(newSQL(cols, 1, "dHash", true, false, true));
    dupesQueryBegin(sql.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, 1);
    while (dupesQueryStep(150) > 0) {}

    const UINT n = dupesQueryRowCount();
    std::vector<DupeCandRow> rows(n);
    dupesFetchRows(rows.data(), 0, n);

    // remember the fingerprint and hash of a row that will survive the mask, so the
    // compaction can be checked for having moved the right bytes
    std::vector<unsigned char> keep(n, 1);
    for (UINT i = 0; i < n; i += 3) keep[i] = 0;
    UINT witness = 0;
    for (UINT i = 0; i < n; i++) if (keep[i]) { witness = i; break; }
    const UINT64 witnessHash = dupesScanHashes[witness];
    std::vector<unsigned char> witnessPix(dupesPixData.begin() + (size_t)witness * 1024,
                                          dupesPixData.begin() + (size_t)(witness + 1) * 1024);
    const unsigned char witnessOK = dupesPixOK[witness];

    // what the groups should look like afterwards
    std::map<UINT, UINT> keptPerGroup;
    for (UINT i = 0; i < n; i++) if (keep[i]) keptPerGroup[rows[i].groupID]++;
    UINT wantGroups = 0, wantRows = 0;
    for (std::map<UINT, UINT>::const_iterator it = keptPerGroup.begin(); it != keptPerGroup.end(); ++it)
    { wantGroups++; wantRows += it->second; }

    const int built = dupesScanBuildFromQuery(keep.data(), n, /*idBase*/ 100);
    check(built==1, "dupesScanBuildFromQuery accepts a partial keep mask");
    check(dupesScanRows==wantRows, "the candidate set holds exactly the kept rows");
    check(dupesScanGroupStart.size()==(size_t)wantGroups + 1, "one boundary per surviving group, plus the close");
    check(dupesScanIDs.size()==wantRows && dupesScanIDs[0]==101,
          "row IDs continue from idBase, one per kept row");
    check(dupesScanHashes.size()==wantRows && dupesScanHashes[0]==witnessHash,
          "compaction moved the hashes, not just the count");
    check(dupesPixOK.size()==wantRows && dupesPixOK[0]==witnessOK &&
          memcmp(&dupesPixData[0], witnessPix.data(), 1024)==0,
          "compaction moved the fingerprints with them");

    // boundaries must be strictly ascending and end exactly on the row count
    bool ascending = true;
    for (size_t g = 1; g < dupesScanGroupStart.size(); g++)
        if (dupesScanGroupStart[g] <= dupesScanGroupStart[g - 1]) ascending = false;
    check(ascending, "group boundaries ascend");
    check(dupesScanGroupStart.back()==dupesScanRows, "the last boundary closes the candidate set");

    // and the sweep runs on it
    INT64 total = 0;
    for (size_t g = 0; g + 1 < dupesScanGroupStart.size(); g++)
    {
        const INT64 m = dupesScanGroupStart[g + 1] - dupesScanGroupStart[g];
        total += m * (m - 1) / 2;
    }
    check(dupesScanState.total==total, "the comparison total counts only the surviving groups");
    while (dupesScanStep(12, 0, 0, 0, 0, 50)) {}
    check(dupesScanState.phase==5 && dupesScanState.done==dupesScanState.total,
          "the sweep runs to completion on a masked candidate set");

    // a mask that keeps nothing must not leave a half-built candidate set behind
    dupesQueryBegin(sql.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    std::vector<unsigned char> none(dupesQueryRowCount(), 0);
    check(dupesScanBuildFromQuery(none.data(), (UINT)none.size(), 0)==0, "an empty keep mask builds nothing");
    check(dupesScanStep(12, 0, 0, 0, 0, 50)==0, "... and the sweep has nothing to do");
}

// ---- cancellation --------------------------------------------------------------------

static void cancelStopsTheQuery() {
    const std::vector<std::string> cols = split("imgwhratio,imgframes", ',');
    const std::wstring sql = widen(newSQL(cols, 1, "dHash", true, false, true));
    dupesQueryBegin(sql.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, 1);
    dupesEngineCancel();
    const int r = dupesQueryStep(150);
    check(r==-1, "a cancelled query reports failure rather than an empty result");
    check(dupesScanState.phase==-1, "... and the phase says so");
    wchar_t err[256];
    const int len = dupesEngineLastError(err, 256);
    check(len > 0, "... and leaves a message for the journal");
    if (getenv("QPV_TEST_VERBOSE")) { std::string s; for (int i = 0; i < len; i++) s.push_back((char)err[i]); printf("    [dbg] %s\n", s.c_str()); }

    // and the engine recovers: the next query runs normally
    dupesQueryBegin(sql.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesQueryRowCount() > 0, "the engine recovers for the next scan");
}

static void rejectsBadInput() {
    const std::wstring bad = L"SELECT imgidu FROM images";
    check(dupesQueryBegin(bad.c_str(), 2, 0, 0, 0, 0, 0, 1)==0, "a SELECT with the wrong column count is rejected");
    const std::wstring nonsense = L"SELECT nope FROM nothing";
    check(dupesQueryBegin(nonsense.c_str(), 1, 0, 0, 0, 0, 0, 1)==0, "an unpreparable statement is rejected");
    check(dupesQueryStep(10)==-1, "... and stepping it reports an error");
}

// ---- hash generation, end to end -----------------------------------------------------
//
// dupesHashStep() reads fingerprints, hashes them and writes the hex back through a
// prepared statement, all on one connection. Two things have to hold that no amount of
// arithmetic testing can show: the values land on the right rows, and the loop terminates
// - it re-runs the same SELECT every batch and relies on the rows dropping out of it as
// they are updated, so a write that did not take would spin forever.
static void hashGenerationWritesBack(const char *dbPath) {
    // a scratch copy, so the shared test database keeps its NULL hashes for other runs
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "cp -f '%s' '%s.hash' 2>/dev/null", dbPath, dbPath);
    if (system(cmd)!=0) { printf("    could not copy the test database\n"); failures++; return; }

    std::string scratch = std::string(dbPath) + ".hash";
    sqlite3 *db = NULL;
    std::vector<char> u8(scratch.begin(), scratch.end());
    u8.push_back(0);
    if (SQ.open_v2(u8.data(), &db, SQLITE_OPEN_READWRITE, NULL)!=SQLITE_OK) {
        printf("    could not open the scratch database read-write\n"); failures++; return;
    }

    // clear one hash column so there is work to do, and count what should be filled
    const std::wstring clr = widen("UPDATE images SET lHash=NULL");
    sqlite3_stmt *st = NULL;
    SQ.prepare16_v2(db, clr.c_str(), -1, &st, NULL);
    SQ.step(st); SQ.finalize(st);

    const std::wstring cnt = widen("SELECT count(*) FROM images LEFT JOIN imagesPixels AS p"
                                   " ON p.imgidu=images.imgidu WHERE images.isDeleted=0 "
                                   "AND p.small IS NOT NULL AND lHash IS NULL");
    long long want = 0;
    SQ.prepare16_v2(db, cnt.c_str(), -1, &st, NULL);
    if (SQ.step(st)==SQLITE_ROW) want = SQ.column_int64(st, 0);
    SQ.finalize(st);
    check(want > 100, "the scratch database has fingerprints waiting to be hashed");

    const std::wstring sel = widen("SELECT images.imgidu, p.small FROM images"
                                   " LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                                   " WHERE images.isDeleted=0 AND p.small IS NOT NULL"
                                   " AND lHash IS NULL LIMIT ?1");
    const std::wstring upd = widen("UPDATE images SET lHash=?1 WHERE imgidu=?2");
    check(dupesHashBegin(db, sel.c_str(), upd.c_str(), /*lHash*/ 4, 72, /*gray*/ 1, 1)==1,
          "dupesHashBegin prepares both statements");

    int steps = 0;
    while (dupesHashStep(64) > 0) {
        steps++;
        if (steps > 10000) { printf("    the hash loop did not terminate\n"); failures++; break; }
    }
    check(steps > 1, "the batch loop really does iterate");
    check(dupesHashWrittenCount()==want, "every waiting row was written exactly once");
    check(dupesHashFailedCount()==0, "no update failed");
    dupesHashEnd();

    // nothing left to do, and the values are right: recompute one by hand
    long long left = 0;
    SQ.prepare16_v2(db, cnt.c_str(), -1, &st, NULL);
    if (SQ.step(st)==SQLITE_ROW) left = SQ.column_int64(st, 0);
    SQ.finalize(st);
    check(left==0, "the SELECT is empty afterwards, which is what ends the loop");

    const std::wstring chk = widen("SELECT images.imgidu, p.small, lHash FROM images"
                                   " JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                                   " WHERE lHash IS NOT NULL AND length(p.small)=72 LIMIT 40");
    int bad = 0, checked = 0;
    SQ.prepare16_v2(db, chk.c_str(), -1, &st, NULL);
    while (SQ.step(st)==SQLITE_ROW) {
        const unsigned char *pix = (const unsigned char*)SQ.column_blob(st, 1);
        const int n = SQ.column_bytes(st, 1);
        if (pix==NULL || n!=72) continue;
        int decoded[72];
        for (int i = 0; i < 72; i++)
            decoded[i] = (int)pix[i];             // grayCompressor 1
        wchar_t expect[32];
        dupesHexHash(dupesLHash(decoded), expect, 32);
        const wchar_t *stored = (const wchar_t*)SQ.column_text16(st, 2);
        if (stored==NULL || wcscmp(stored, expect)!=0) bad++;
        checked++;
    }
    SQ.finalize(st);
    check(checked > 10 && bad==0, "the stored hex is this row's own lHash");

    SQ.close_v2(db);
    snprintf(cmd, sizeof(cmd), "rm -f '%s'", scratch.c_str());
    if (system(cmd)) {}
}

// ---- hash generation over fingerprints that cannot be hashed -------------------------
//
// A fingerprint of the wrong length has no hash, so the row has to be taken out of the
// "hash IS NULL" result set some other way or the loop re-reads it forever. Three things
// about how that is done are load-bearing and none of them is obvious:
//
//   - the marker is the EMPTY string, never "0". "0" is a real hash value - a uniform
//     image hashes to zero - and the candidate query keeps every row for which
//     ifnull(hash,'')!='', so "0" would collect all of these into one phantom duplicate
//     group together with every flat image in the library.
//   - a batch that is entirely unhashable must NOT report the run as finished. The SELECT
//     is capped at the batch size, so such a batch says nothing about the rows behind it.
//   - they are not write failures, and are counted apart from them.
static long long qeScalar(sqlite3 *db, const char *sql) {
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

static void qeExec(sqlite3 *db, const char *sql) {
    const std::wstring w = widen(sql);
    sqlite3_stmt *st = NULL;
    if (SQ.prepare16_v2(db, w.c_str(), -1, &st, NULL)!=SQLITE_OK || st==NULL)
       return;

    SQ.step(st);
    SQ.finalize(st);
}

static void hashGenerationSkipsShortFingerprints(const char *dbPath) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "cp -f '%s' '%s.short' 2>/dev/null", dbPath, dbPath);
    if (system(cmd)!=0) { printf("    could not copy the test database\n"); failures++; return; }

    std::string scratch = std::string(dbPath) + ".short";
    sqlite3 *db = NULL;
    std::vector<char> u8(scratch.begin(), scratch.end());
    u8.push_back(0);
    if (SQ.open_v2(u8.data(), &db, SQLITE_OPEN_READWRITE, NULL)!=SQLITE_OK) {
        printf("    could not open the scratch database read-write\n"); failures++; return;
    }

    // Truncate the fingerprints of the 80 lowest identities by one byte. The batch below
    // is 64, and the SELECT has no ORDER BY - it scans - so the first batch lands wholly
    // inside the damaged run, which is exactly the case that used to end the whole loop.
    qeExec(db, "UPDATE images SET lHash=NULL");
    qeExec(db, "UPDATE imagesPixels SET small=substr(small, 1, 71) WHERE imgidu IN"
               " (SELECT imgidu FROM images WHERE isDeleted=0 ORDER BY imgidu LIMIT 80)");

    const char *scopeSQL = " FROM images LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                           " WHERE images.isDeleted=0 AND p.small IS NOT NULL";
    const long long shortRows = qeScalar(db, (std::string("SELECT count(*)") + scopeSQL + " AND length(p.small)!=72").c_str());
    const long long goodRows  = qeScalar(db, (std::string("SELECT count(*)") + scopeSQL + " AND length(p.small)=72").c_str());
    check(shortRows >= 64, "the scratch database has more short fingerprints than one batch holds");
    check(goodRows > 100,  "and good ones behind them");

    const std::wstring sel = widen("SELECT images.imgidu, p.small FROM images"
                                   " LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                                   " WHERE images.isDeleted=0 AND p.small IS NOT NULL"
                                   " AND lHash IS NULL LIMIT ?1");
    const std::wstring upd = widen("UPDATE images SET lHash=?1 WHERE imgidu=?2");
    check(dupesHashBegin(db, sel.c_str(), upd.c_str(), 4, 72, 1, 1)==1,
          "dupesHashBegin prepares both statements");

    int steps = 0;
    while (dupesHashStep(64) > 0) {
        steps++;
        if (steps > 10000) { printf("    the hash loop did not terminate\n"); failures++; break; }
    }

    check(dupesHashWrittenCount()==goodRows, "every hashable row was hashed, not just the ones before the damage");
    check(dupesHashSkippedCount()==shortRows, "and every unhashable one was counted as skipped");
    check(dupesHashFailedCount()==0, "a skipped fingerprint is not a failed write");
    dupesHashEnd();

    check(qeScalar(db, (std::string("SELECT count(*)") + scopeSQL + " AND lHash IS NULL").c_str())==0,
          "the SELECT is empty afterwards, which is what ends the loop");
    check(qeScalar(db, "SELECT count(*) FROM images WHERE lHash=''")==shortRows,
          "the short rows carry an empty hash");
    check(qeScalar(db, "SELECT count(*) FROM images WHERE lHash='0' AND imgidu IN"
                       " (SELECT imgidu FROM imagesPixels WHERE length(small)!=72)")==0,
          "... and never the string \"0\", which is a legitimate hash value");
    check(qeScalar(db, "SELECT count(*) FROM images WHERE ifnull(lHash,'')!='' AND imgidu IN"
                       " (SELECT imgidu FROM imagesPixels WHERE length(small)!=72)")==0,
          "so the candidate query's ifnull() guard drops them");

    SQ.close_v2(db);
    snprintf(cmd, sizeof(cmd), "rm -f '%s'", scratch.c_str());
    if (system(cmd)) {}
}

int main(int argc, char **argv) {
    const char *dbPath = (argc > 1) ? argv[1] : "testdb.sldb";

    const std::wstring wpath = widen(dbPath);
    if (!dupesEngineInit(wpath.c_str()))
    {
        printf("    could not open %s through sqlite-dynamic.h\n", dbPath);
        return 1;
    }
    printf("  sqlite3 bound at run time, threadsafe=%d\n", SQ.threadsafe ? SQ.threadsafe() : -1);

    // the reference connection, deliberately separate from the engine's
    std::vector<char> utf8(strlen(dbPath) + 1);
    memcpy(utf8.data(), dbPath, strlen(dbPath) + 1);
    if (SQ.open_v2(utf8.data(), &refDB, SQLITE_OPEN_READONLY, NULL)!=SQLITE_OK)
    {
        printf("    could not open the reference connection\n");
        return 1;
    }

    printf("  grouping\n");
    groupingMatchesSelfJoin(dbPath);
    printf("  candidate rows\n");
    rowsMatchTheDatabase();
    printf("  keep mask\n");
    keepMaskRecutsGroups();
    printf("  cancellation and bad input\n");
    cancelStopsTheQuery();
    rejectsBadInput();
    printf("  hash generation\n");
    hashGenerationWritesBack(dbPath);
    printf("  hash generation, unhashable fingerprints\n");
    hashGenerationSkipsShortFingerprints(dbPath);

    dupesEngineRelease();
    SQ.close_v2(refDB);
    printf("\n  %s\n", failures ? "QUERY ENGINE TEST FAILED" : "query engine test passed");
    return failures ? 1 : 0;
}
