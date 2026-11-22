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
#define QPV_DBG(...) fnOutputDebug(__VA_ARGS__)

#include "../lib/sqlite-dynamic.h"   // verbatim, the shipped run-time binder
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

    // 2, 3 and 4 are the hashes. The step loop reads anything that is not dHash or lHash
    // as pHash, so a kind of 1 - userFriendly[1], "NONE", which the panel really can ask
    // for - would run a 1024 value DCT over a buffer sized for 72, and a fingerprint
    // length that does not belong to the kind is the same mistake from the other side.
    const std::wstring anySel = L"SELECT imgidu, 1 FROM images LIMIT ?1";
    const std::wstring anyUpd = L"UPDATE images SET lHash=?1 WHERE imgidu=?2";
    check(dupesHashBegin(refDB, anySel.c_str(), anyUpd.c_str(), 1, 72, 1, 1)==0,
          "a hash kind that is not one of the three is refused");
    check(dupesHashBegin(refDB, anySel.c_str(), anyUpd.c_str(), 4, 1024, 1, 1)==0,
          "and so is a fingerprint length that does not belong to the kind");
}

// ---- hash generation, end to end -----------------------------------------------------
//
// dupesHashStep() reads fingerprints, hashes them and writes the hex back through a
// prepared statement, all on one connection. Two things have to hold that no amount of
// arithmetic testing can show: the values land on the right rows, and the loop terminates
// - a batch that moved nothing would otherwise re-read the same rows for ever.
//
// Every case below runs twice, because one qpvmain.dll has to serve two query shapes.
// generateSQLimageFingerPrintHash() sends the keyset cursor when the DLL beside it exports
// dupesHashHasKeyset(), and the plain "LIMIT ?1" when it does not; a build that only
// worked with the form it ships with would break the other pairing silently, and hashing
// nothing at all while reporting success is not a failure anybody would notice.
static std::wstring hashSelectSQL(const char *pixCol, const char *hashCol, bool keyset) {
    std::string s = std::string("SELECT images.imgidu, p.") + pixCol
                  + " FROM images LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                  + " WHERE +images.isDeleted=0 AND p." + pixCol + " IS NOT NULL"
                  + " AND " + hashCol + " IS NULL";
    if (keyset)
       s += " AND images.imgidu>?2 ORDER BY images.imgidu";

    return widen(s + " LIMIT ?1");
}

static void hashGenerationWritesBack(const char *dbPath, bool keyset) {
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

    const std::wstring sel = hashSelectSQL("small", "lHash", keyset);
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

    // O2: exercise compact uint8_t pHash path (dupesHashByteBuf + QPV_SQLITE_STATIC) at compressor 2
    if (keyset)
    {
       const std::wstring pclr = widen("UPDATE images SET pHash=NULL");
       SQ.prepare16_v2(db, pclr.c_str(), -1, &st, NULL);
       SQ.step(st); SQ.finalize(st);
       const std::wstring psel = hashSelectSQL("big", "pHash", true);
       const std::wstring pupd = widen("UPDATE images SET pHash=?1 WHERE imgidu=?2");
       check(dupesHashBegin(db, psel.c_str(), pupd.c_str(), /*pHash*/ 3, 1024, /*gray*/ 2, 1)==1,
             "O2: dupesHashBegin prepares pHash with compressor 2");
       int psteps = 0;
       while (dupesHashStep(64) > 0 && ++psteps < 10000) {}
       check(dupesHashWrittenCount() > 100 && dupesHashFailedCount()==0,
             "O2: pHash byte-buffer loop writes all rows cleanly");
       dupesHashEnd();

       const std::wstring pchk = widen("SELECT images.imgidu, p.big, pHash FROM images"
                                       " JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                                       " WHERE pHash IS NOT NULL AND length(p.big)=1024 LIMIT 40");
       int pbad = 0, pchecked = 0;
       SQ.prepare16_v2(db, pchk.c_str(), -1, &st, NULL);
       while (SQ.step(st)==SQLITE_ROW) {
           const unsigned char *pix = (const unsigned char*)SQ.column_blob(st, 1);
           const int n = SQ.column_bytes(st, 1);
           if (pix==NULL || n!=1024) continue;
           int decoded[1024];
           for (int i = 0; i < 1024; i++)
               decoded[i] = dupesDiscretize((int)pix[i], 2);
           wchar_t expect[32];
           dupesHexHash(dupesPHash(decoded, 1), expect, 32);
           const wchar_t *stored = (const wchar_t*)SQ.column_text16(st, 2);
           if (stored==NULL || wcscmp(stored, expect)!=0) pbad++;
           pchecked++;
       }
       SQ.finalize(st);
       check(pchecked > 10 && pbad==0, "O2: stored pHash matches dupesPHash() at compressor 2");
    }

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

static void hashGenerationSkipsShortFingerprints(const char *dbPath, bool keyset) {
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
    // is 64, so the first batch lands wholly inside the damaged run - which is exactly the
    // case that used to end the whole loop. The keyset form reads in imgidu order and hits
    // it by construction; the plain LIMIT scans, and lands there because those rows are
    // physically first as well.
    qeExec(db, "UPDATE images SET lHash=NULL");
    qeExec(db, "UPDATE imagesPixels SET small=substr(small, 1, 71) WHERE imgidu IN"
               " (SELECT imgidu FROM images WHERE isDeleted=0 ORDER BY imgidu LIMIT 80)");

    const char *scopeSQL = " FROM images LEFT JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                           " WHERE images.isDeleted=0 AND p.small IS NOT NULL";
    const long long shortRows = qeScalar(db, (std::string("SELECT count(*)") + scopeSQL + " AND length(p.small)!=72").c_str());
    const long long goodRows  = qeScalar(db, (std::string("SELECT count(*)") + scopeSQL + " AND length(p.small)=72").c_str());
    check(shortRows >= 64, "the scratch database has more short fingerprints than one batch holds");
    check(goodRows > 100,  "and good ones behind them");

    const std::wstring sel = hashSelectSQL("small", "lHash", keyset);
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

// ---- a database that refuses every write ----------------------------------------------
//
// The loop ends because rows stop matching the SELECT, and only a successful write makes
// that happen. A database that refuses the UPDATEs - out of space, opened read-only, a
// lock held by another connection - is therefore the one shape where the run has to be
// bounded by something else, and it is not a shape anybody reaches by hand.
//
// The keyset cursor is what bounds it: a row that could not be written is behind the
// cursor and is never offered again, so the run walks to the end of the library, reports
// every row as a failed write and stops. That is also the ONLY observable difference
// between a cursor that advances and one that stands still - on a healthy run the two
// produce identical output at very different cost - so this is the case that pins it.
// The plain LIMIT has no cursor to bound it and is stopped by the backstop in
// dupesHashStillMoving() instead, which answers -1 rather than re-reading for ever.
//
// A trigger stands in for the failure: RAISE(ABORT) makes every UPDATE against images
// come back SQLITE_CONSTRAINT, and nothing else about the database changes.
static void hashGenerationEndsWhenWritesFail(const char *dbPath, bool keyset) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "cp -f '%s' '%s.nowrite' 2>/dev/null", dbPath, dbPath);
    if (system(cmd)!=0) { printf("    could not copy the test database\n"); failures++; return; }

    std::string scratch = std::string(dbPath) + ".nowrite";
    sqlite3 *db = NULL;
    std::vector<char> u8(scratch.begin(), scratch.end());
    u8.push_back(0);
    if (SQ.open_v2(u8.data(), &db, SQLITE_OPEN_READWRITE, NULL)!=SQLITE_OK) {
        printf("    could not open the scratch database read-write\n"); failures++; return;
    }

    qeExec(db, "UPDATE images SET lHash=NULL");
    const long long want = qeScalar(db, "SELECT count(*) FROM images LEFT JOIN imagesPixels AS p"
                                        " ON p.imgidu=images.imgidu WHERE images.isDeleted=0"
                                        " AND p.small IS NOT NULL AND lHash IS NULL");
    // more rows than the backstop can reach in the batches it allows, or "it stopped early"
    // and "it walked the library" would be the same number
    check(want > 4*64, "there is more waiting to be hashed than a stalled loop could reach");
    qeExec(db, "CREATE TRIGGER qpvNoWrites BEFORE UPDATE ON images"
               " BEGIN SELECT RAISE(ABORT, 'the database is refusing writes'); END");

    const std::wstring sel = hashSelectSQL("small", "lHash", keyset);
    const std::wstring upd = widen("UPDATE images SET lHash=?1 WHERE imgidu=?2");
    check(dupesHashBegin(db, sel.c_str(), upd.c_str(), 4, 72, 1, 1)==1,
          "dupesHashBegin prepares both statements");

    // generous and still nothing like unbounded: offering every row once is 1200/64 = 19
    // batches, and the backstop gives up after 3 that moved nothing
    const int cap = 200;
    int steps = 0, answer = 1;
    while ((answer = dupesHashStep(64)) > 0)
    {
        steps++;
        if (steps > cap)
           break;
    }

    check(steps <= cap, "the run ends by itself rather than re-reading rows it cannot write");
    check(dupesHashWrittenCount()==0, "and nothing was written, because nothing could be");
    if (keyset)
    {
       check(answer==0, "the keyset run reaches the end of the library and says so");
       check(dupesHashFailedCount()==want, "having offered every row exactly once, though none of them took");
    } else
    {
       wchar_t err[512];
       check(answer==-1, "the plain LIMIT is stopped by the backstop instead, as an error");
       check(dupesEngineLastError(err, 511) > 0, "... with something for the journal to say");
       check(dupesHashFailedCount() < want, "long before the library has been walked");
    }

    dupesHashEnd();
    SQ.close_v2(db);
    snprintf(cmd, sizeof(cmd), "rm -f '%s'", scratch.c_str());
    if (system(cmd)) {}
}

static void pairsCacheSurvivesFailedSearch() {
    const std::vector<std::string> cols = split("imgwhratio,imgframes", ',');
    const std::wstring sqlMSD = widen(newSQL(cols, 1, "dHash", true, false, true));
    const std::wstring sqlNoMSD = widen(newSQL(cols, 1, "dHash", true, false, false));

    dupesClearPairs();
    dupesQueryBegin(sqlMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesScanBuildFromQuery(NULL, 0, 0)==1, "initial MSD search builds candidates");
    while (dupesScanStep(12, 0, 0, 0, 0, 50)) {}
    dupesScanEnd();
    const UINT initialRows = dupesApplyFilter(0, 12, 0, 400, 0, 0, NULL, 0);
    const UINT basePairs = dupesPairCount();
    const int baseMSD = dupesHaveMSD();
    const std::vector<DupePairRec> baseList = dupesPairsList;
    check(initialRows >= 2 && basePairs > 0 && baseMSD==1, "initial search leaves a live MSD pair cache");

    // 1. Bad SQL in dupesQueryBegin() keeps existing pairs intact.
    check(dupesQueryBegin(L"SELECT nope FROM nothing", 1, 0, 0, 0, 0, 0, 1)==0, "bad SQL is rejected");
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD, "bad query preserves cached pairs and MSD flag");

    // 2. Cancelled dupesQueryStep() keeps existing pairs intact.
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    dupesEngineCancel();
    check(dupesQueryStep(150)==-1, "cancelled query fails");
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD, "cancelled query preserves cached pairs");

    // 3. Empty keep mask (dupesScanBuildFromQuery returns 0) keeps existing pairs intact.
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    std::vector<unsigned char> none(dupesQueryRowCount(), 0);
    check(dupesScanBuildFromQuery(none.data(), (UINT)none.size(), 0)==0, "empty keep mask refuses build");
    dupesScanEnd();
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD, "empty keep mask + dupesScanEnd preserves cached pairs");

    // 4. Sweep that finds 0 pairs restores the previous cache on dupesScanEnd().
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesScanBuildFromQuery(NULL, 0, 0)==1, "zero-match sweep builds candidates");
    while (dupesScanStep(0, 0, 0, 0, 0, 50)) {}
    check(dupesScanState.pairs==0, "threshold 0 sweep finds zero pairs");
    dupesScanEnd();
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD && !dupesHasSavedPairs,
          "zero-match sweep restores cached pairs on dupesScanEnd");

    // 5. Mid-sweep abort (phase != 5 at dupesScanEnd) restores the previous cache.
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesScanBuildFromQuery(NULL, 0, 0)==1, "aborted sweep builds candidates");
    dupesScanState.phase = 3;
    dupesScanEnd();
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD && !dupesHasSavedPairs,
          "aborted sweep restores cached pairs on dupesScanEnd");

    // 6. Sweep with pairs that all fail dupesApplyFilter() restores the previous cache.
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesScanBuildFromQuery(NULL, 0, 0)==1, "post-sweep empty-filter search builds candidates");
    while (dupesScanStep(12, 0, 0, 0, 0, 50)) {}
    dupesScanEnd();
    check(dupesApplyFilter(64, 64, 0, 400, 0, 0, NULL, 0)==0, "impossible filter drops all rows");
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD && !dupesHasSavedPairs &&
          memcmp(dupesPairsList.data(), baseList.data(), baseList.size() * sizeof(DupePairRec))==0,
          "failed dupesApplyFilter restores cached pairs byte for byte");

    // 7. Ctrl+F re-filter with 0 matches (no saved backup) keeps the live cache intact.
    check(dupesApplyFilter(64, 64, 0, 400, 0, 0, NULL, 0)==0, "impossible Ctrl+F filter drops all rows");
    check(dupesPairCount()==basePairs && dupesHaveMSD()==baseMSD, "failed Ctrl+F filter keeps live cache");

    // 8. A successful second search commits the new pairs and drops the saved backup.
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesScanBuildFromQuery(NULL, 0, 0)==1, "second search builds candidates");
    while (dupesScanStep(12, 0, 0, 0, 0, 50)) {}
    dupesScanEnd();
    check(dupesApplyFilter(0, 12, 0, 400, 0, 0, NULL, 0) >= 2, "second search succeeds");
    check(dupesHaveMSD()==0 && !dupesHasSavedPairs && dupesSavedPairs.empty(),
          "successful second search commits new MSD flag and drops backup");

    // 9. Aborted first search with no prior cache clears partial pairs on dupesScanEnd().
    dupesClearPairs();
    dupesQueryBegin(sqlNoMSD.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 0, 1024, 1);
    while (dupesQueryStep(150) > 0) {}
    check(dupesScanBuildFromQuery(NULL, 0, 0)==1, "fresh aborted search builds candidates");
    dupesPairsList.push_back({1, 2, 0, QPV_MSD_NONE});
    dupesScanState.phase = 3;
    dupesScanEnd();
    check(dupesPairCount()==0 && dupesHaveMSD()==0, "aborted fresh sweep discards partial pairs");

    dupesClearPairs();
}

static int __cdecl qeInterruptNow(void*) { return 1; }

// Regression tests for S1, S3, S5, S6, S7, S9, S12.
static void auditRegressions(const char *dbPath) {
    // S1 + S6 + S7: run against a small dedicated scratch database
    const std::string scratch = std::string(dbPath) + ".audit";
    remove(scratch.c_str());
    sqlite3 *db = NULL;
    if (SQ.open_v2(scratch.c_str(), &db, SQLITE_OPEN_READWRITE | 0x00000004 /*CREATE*/, NULL)!=SQLITE_OK || db==NULL)
    {
        printf("    could not create audit scratch database\n");
        failures++;
        return;
    }

    const char *setupSQL =
        "CREATE TABLE images (imgidu INTEGER PRIMARY KEY, fullPath TEXT, imgmegapix REAL, fsize INT,"
        " dHash TEXT, grp INT, bigkey INTEGER, txt TEXT);"
        "CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY, small BLOB);"
        // Group 1: two valid dupes separated by an unparseable hash
        "INSERT INTO images VALUES (1, 'a.jpg', 1.0, 100, 'abcdef01', 1, 9223372036854775807, 'ABC');"
        "INSERT INTO images VALUES (2, 'bad.jpg', 1.0, 200, 'not_hex!', 1, 9223372036854775806, 'abc');"
        "INSERT INTO images VALUES (3, 'c.jpg', 1.0, 300, 'abcdef01', 1, 9223372036854775807, 'ABC');"
        // Group 2: four valid dupes separated by an overlong (>16 char) hash
        "INSERT INTO images VALUES (10, 'd1.jpg', 1.0, 100, '1234', 2, -9223372036854775808, 'XYZ');"
        "INSERT INTO images VALUES (11, 'd2.jpg', 1.0, 110, '1234', 2, -9223372036854775808, 'XYZ');"
        "INSERT INTO images VALUES (12, 'bad2.jpg', 1.0, 120, '0123456789abcdef0', 2, 0, 'xyz');"
        "INSERT INTO images VALUES (13, 'd3.jpg', 1.0, 130, '1234', 2, 18014398509481984, 'QWE');"
        "INSERT INTO images VALUES (14, 'd4.jpg', 1.0, 140, '1234', 2, 18014398509481984, 'qwe');"
        // Group 3: bad hash between distinct groups must not merge them
        "INSERT INTO images VALUES (20, 'e1.jpg', 1.0, 100, 'aaaa', 3, 1, 'k');"
        "INSERT INTO images VALUES (21, 'e2.jpg', 1.0, 110, 'aaaa', 3, 1, 'k');"
        "INSERT INTO images VALUES (22, 'bad3.jpg', 1.0, 120, 'zzz', 4, 2, 'k');"
        "INSERT INTO images VALUES (23, 'f1.jpg', 1.0, 100, 'bbbb', 5, 3, 'k');"
        "INSERT INTO images VALUES (24, 'f2.jpg', 1.0, 110, 'bbbb', 5, 3, 'k');"
        "INSERT INTO imagesPixels VALUES (1, zeroblob(72)), (2, zeroblob(72)), (3, zeroblob(72));";
    check(SQ.exec!=NULL && SQ.exec(db, setupSQL, NULL, NULL, NULL)==SQLITE_OK,
          "audit: populate scratch database");

    const std::wstring wScratch = widen(scratch);
    check(dupesEngineInit(wScratch.c_str())==1, "audit: open scratch database");

    // S1: unparseable hashes must not drop or split valid groups
    {
        const std::wstring sql =
            L"SELECT imgidu, fullPath, imgmegapix, fsize, dHash, grp AS k0"
            L" FROM images ORDER BY k0, imgmegapix, fsize";
        check(dupesQueryBegin(sql.c_str(), 1, 0, 1, 0, 0, 0, 1)==1, "S1: query begins");
        while (dupesQueryStep(100) > 0) {}
        check(dupesQueryRowCount()==10 && dupesQueryGroupCount()==4,
              "S1: bad hashes inside runs keep 2-row and 4-row groups intact (10 rows, 4 groups)");

        // Verify the 4-row group (grp=2) was not split and groups 3 and 5 stayed separate
        std::vector<DupeCandRow> rows(dupesQueryRowCount());
        dupesFetchRows(rows.data(), 0, (UINT)rows.size());
        bool okS1 = (rows.size()==10
                  && rows[0].imgidu==1 && rows[1].imgidu==3 && rows[0].groupID==rows[1].groupID
                  && rows[2].imgidu==10 && rows[5].imgidu==14 && rows[2].groupID==rows[5].groupID
                  && rows[6].imgidu==20 && rows[7].imgidu==21 && rows[6].groupID==rows[7].groupID
                  && rows[8].imgidu==23 && rows[9].imgidu==24 && rows[8].groupID==rows[9].groupID
                  && rows[6].groupID!=rows[8].groupID);
        check(okS1, "S1: exact group membership preserved across bad hashes");

        // S12: keepMask leaving only 1 image in each group (kept==2, comparisons==0)
        dupesClearPairs();
        dupesPairsList.push_back({9, 8, 0, QPV_MSD_NONE});
        dupesPairsMSD = 1;
        check(dupesQueryBegin(sql.c_str(), 1, 0, 1, 0, 0, 0, 1)==1, "S12: query restarts");
        while (dupesQueryStep(100) > 0) {}
        std::vector<unsigned char> onlySingles(dupesQueryRowCount(), 0);
        if (onlySingles.size() >= 3)
        {
           onlySingles[0] = 1;   // 1 from group 1
           onlySingles[2] = 1;   // 1 from group 2 -> kept==2, comparisons==0
        }
        check(dupesScanBuildFromQuery(onlySingles.data(), (UINT)onlySingles.size(), 0)==0,
              "S12: all-singleton keepMask returns 0 without starting a no-op sweep");
        check(dupesScanState.phase==5 && dupesScanState.groups==0 && dupesScanState.total==0,
              "S12: all-singleton build sets phase=5, groups=0, total=0");
        check(dupesPairCount()==1 && dupesHaveMSD()==1 && !dupesHasSavedPairs,
              "S12: all-singleton build leaves prior pairs cache untouched");
        dupesClearPairs();
    }

    // S7: near-INT64_MAX integers without UB, plus keyCount >= 32 nocaseMask shift guard
    {
        const std::wstring sqlInt =
            L"SELECT imgidu, fullPath, imgmegapix, fsize, bigkey AS k0"
            L" FROM images WHERE imgidu IN (1,2,3,10,11,13,14) ORDER BY k0, imgmegapix, fsize";
        check(dupesQueryBegin(sqlInt.c_str(), 1, 0, 0, 0, 0, 0, 1)==1, "S7: INT64_MAX query begins");
        while (dupesQueryStep(100) > 0) {}
        check(dupesQueryRowCount()==6 && dupesQueryGroupCount()==3,
              "S7: INT64_MAX, INT64_MIN, and 2^54 group accurately (INT64_MAX-1 stays distinct)");

        // 34 key columns with nocaseMask=1u: column 32 (txt) must NOT inherit bit 0 (no UB shift)
        std::string sel34 = "SELECT imgidu, fullPath, imgmegapix, fsize";
        std::string ord34;
        for (int k = 0; k < 32; k++) {
            sel34 += ", 1 AS k" + std::to_string(k);
            if (k) ord34 += ", ";
            ord34 += "k" + std::to_string(k);
        }
        sel34 += ", txt AS k32, 1 AS k33 FROM images WHERE imgidu IN (13, 14) ORDER BY " + ord34 + ", k32, k33";
        const std::wstring wSel34 = widen(sel34);
        check(dupesQueryBegin(wSel34.c_str(), 34, 1u, 0, 0, 0, 0, 1)==1, "S7: 34-key query begins");
        while (dupesQueryStep(100) > 0) {}
        check(dupesQueryRowCount()==0 && dupesQueryGroupCount()==0,
              "S7: keyCount>=32 does not wrap nocaseMask shift onto column 32");
    }

    // S9: decodeFingerprintBytes rejects 32-bit UINT wraparound
    {
        dupesPixStride = 4;
        dupesPixScale = 1;
        dupesPixData.assign(16, 0);
        dupesPixOK.assign(4, 0);
        const unsigned char raw[4] = {10, 20, 30, 40};
        decodeFingerprintBytes(raw, 0xFFFFFFFFu, 1);
        check(dupesPixOK[0]==0, "S9: decodeFingerprintBytes rejects UINT wraparound");
        dupesPixData.clear(); dupesPixOK.clear(); dupesPixStride = 0;
    }

    // S6 + S5: dupesHashStep returns -1 on SQLITE_INTERRUPT (not 0) and handles overflow batch
    if (SQ.progress_handler!=NULL)
    {
        qeExec(db, "UPDATE images SET dHash=NULL WHERE imgidu IN (1,2,3)");
        const std::wstring sel = L"SELECT images.imgidu, p.small FROM images"
                                 L" JOIN imagesPixels AS p ON p.imgidu=images.imgidu"
                                 L" WHERE dHash IS NULL AND images.imgidu>?2 ORDER BY images.imgidu LIMIT ?1";
        const std::wstring upd = L"UPDATE images SET dHash=?1 WHERE imgidu=?2";
        check(dupesHashBegin(db, sel.c_str(), upd.c_str(), 2, 72, 1, 1)==1, "S6: dupesHashBegin prepares");
        SQ.progress_handler(db, 1, qeInterruptNow, NULL);
        const int rInt = dupesHashStep(64);
        SQ.progress_handler(db, 0, NULL, NULL);
        wchar_t err[256] = {};
        const int elen = dupesEngineLastError(err, 256);
        check(rInt==-1 && elen > 0, "S6: dupesHashStep returns -1 with message on SQLITE_INTERRUPT");
        // Resuming after clearing interrupt still hashes all 3 rows because cursor was restored
        while (dupesHashStep(64) > 0) {}
        check(dupesHashWrittenCount()==3, "S6: cursor restored after interrupt so resuming hashes all rows");
        dupesHashEnd();
    }

    // S3: stale error cleared on dupesEngineInit() + concurrent dupesEngineCancel() vs Init/Release
    {
        check(dupesEngineInit(L"/nonexistent/path/that/cannot/open.sldb")==0, "S3: bad path sets error");
        wchar_t err[256] = {};
        check(dupesEngineLastError(err, 256) > 0, "S3: bad path left an error message");
        check(dupesEngineInit(NULL)==0, "S3: dupesEngineInit(NULL) fails");
        check(dupesEngineLastError(err, 256)==0, "S3: dupesEngineInit(NULL) cleared stale error");

        // Re-init on already-open DB + concurrent cancel stress test
        std::atomic<bool> stopCancel(false);
        std::thread canceler([&stopCancel]() {
            while (!stopCancel.load(std::memory_order_relaxed))
                dupesEngineCancel();
        });
        int initOk = 0;
        for (int i = 0; i < 80; i++)
        {
            if (dupesEngineInit(wScratch.c_str())==1)
               initOk++;
            if (i % 3 == 0)
               dupesEngineRelease();
        }
        stopCancel.store(true, std::memory_order_relaxed);
        canceler.join();
        check(initOk==80, "S3: concurrent dupesEngineCancel during Init/Release loop succeeds safely");
    }

    dupesEngineRelease();
    SQ.close_v2(db);
    remove(scratch.c_str());

    // Re-open the main test database for callers that follow
    const std::wstring wmain = widen(dbPath);
    dupesEngineInit(wmain.c_str());
}

// Tests for O6 (deferred imagesPixels.big fetch, UTF-8 buildRowKey/parseHexHash,
// pre-v3 fallback, cancel handling) and O5 (256-byte LUT in decodeFingerprintBytes).
static void o6DeferredAndO5Lut(const char *dbPath) {
    const std::vector<std::string> cols = split("imgwhratio,imgframes", ',');
    const std::wstring sqlInline = widen(newSQL(cols, 1, "dHash", true, false, true));
    // Deferred layout: same SELECT without p.big and without LEFT JOIN imagesPixels.
    const std::wstring sqlDeferred = widen(newSQL(cols, 1, "dHash", true, false, false));

    for (int comp = 1; comp <= 3; comp += 2)
    {
        // 1. Inline reference run (with partial keepMask that also leaves singletons)
        dupesClearPairs();
        check(dupesQueryBegin(sqlInline.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, comp)==1,
              comp==1 ? "O6: inline query begins (scale=1)" : "O6: inline query begins (scale=3)");
        while (dupesQueryStep(150) > 0) {}
        const UINT nInline = dupesQueryRowCount();
        std::vector<unsigned char> mask(nInline, 1);
        for (UINT i = 0; i < nInline; i++)
            if (i % 3 == 0) mask[i] = 0;
        check(dupesScanBuildFromQuery(mask.data(), nInline, 10)==1, "O6: inline build succeeds");
        const std::vector<UINT> inlineGrpStart = dupesScanGroupStart;
        const std::vector<unsigned char> inlinePixOK = dupesPixOK;
        const std::vector<unsigned char> inlinePixData = dupesPixData;
        while (dupesScanStep(12, 0, 0, 0, 0, 50)) {}
        const std::vector<DupePairRec> inlinePairs = dupesPairsList;
        dupesScanEnd();

        // 2. Deferred run with the exact same keepMask and compressor
        dupesClearPairs();
        check(dupesQueryBegin(sqlDeferred.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, comp)==1,
              comp==1 ? "O6: deferred query begins (scale=1)" : "O6: deferred query begins (scale=3)");
        while (dupesQueryStep(150) > 0) {}
        check(dupesQueryRowCount()==nInline && dupesPixData.empty() && dupesPixOK.empty(),
              "O6: deferred query keeps zero pixel bytes during ORDER BY step");
        check(dupesScanBuildFromQuery(mask.data(), nInline, 10)==1, "O6: deferred build fetches surviving pixels");

        // Every row in a surviving group of >= 2 must have identical pixOK and decoded bytes;
        // singleton groups after keepMask must be skipped (pixOK == 0).
        int pixMismatch = 0, skippedSingles = 0, verifiedMulti = 0;
        for (size_t g = 0; g + 1 < dupesScanGroupStart.size(); g++)
        {
            const UINT a = dupesScanGroupStart[g], b = dupesScanGroupStart[g + 1];
            if (b - a < 2)
            {
               if (dupesPixOK[a] != 0) pixMismatch++;
               skippedSingles++;
               continue;
            }
            for (UINT s = a; s < b; s++)
            {
                if (dupesPixOK[s] != inlinePixOK[s]) { pixMismatch++; continue; }
                if (dupesPixOK[s] == 1 &&
                    memcmp(&dupesPixData[(size_t)s * 1024], &inlinePixData[(size_t)s * 1024], 1024) != 0)
                   pixMismatch++;
                verifiedMulti++;
            }
        }
        check(pixMismatch==0 && verifiedMulti > 50,
              "O6: deferred sorted PK fetch matches inline pixels byte for byte");
        if (comp == 1)
           check(skippedSingles > 0, "O6: singleton groups after keepMask are not fetched");

        while (dupesScanStep(12, 0, 0, 0, 0, 50)) {}
        const bool sameOut = (dupesPairsList.size() == inlinePairs.size()) &&
                             (inlinePairs.empty() || memcmp(dupesPairsList.data(), inlinePairs.data(),
                                                            inlinePairs.size() * sizeof(DupePairRec)) == 0);
        check(sameOut && dupesHaveMSD()==1 && !inlinePairs.empty(),
              "O6: deferred MSD sweep output is byte-identical to inline mode");
        dupesScanEnd();
    }

    // Cancel before deferred dupesScanBuildFromQuery preserves prior pairs cache
    {
        dupesClearPairs();
        dupesPairsList.push_back({7, 8, 1, 20});
        dupesPairsMSD = 1;
        dupesQueryBegin(sqlDeferred.c_str(), (int)cols.size(), nocaseMaskFor(cols), 1, 0, 1, 1024, 1);
        while (dupesQueryStep(150) > 0) {}
        dupesEngineCancel();
        check(dupesScanBuildFromQuery(NULL, 0, 0)==0 && dupesScanState.phase==-1,
              "O6: cancel during deferred build aborts cleanly");
        check(dupesPairCount()==1 && dupesHaveMSD()==1 && !dupesHasSavedPairs,
              "O6: cancelled deferred build preserves prior pairs cache");
        dupesClearPairs();
    }

    // Pre-v3 database (no imagesPixels table) + UTF-8 NOCASE + O5 LUT transitions
    {
        const std::string scratch = std::string(dbPath) + ".o6";
        remove(scratch.c_str());
        sqlite3 *db = NULL;
        check(SQ.open_v2(scratch.c_str(), &db, SQLITE_OPEN_READWRITE | 0x00000004, NULL)==SQLITE_OK && db!=NULL,
              "O6: create scratch DB without imagesPixels");
        const char *sqlSetup =
            "CREATE TABLE images (imgidu INTEGER PRIMARY KEY, fullPath TEXT, imgmegapix REAL, fsize INT,"
            " dHash TEXT, imgfile TEXT COLLATE NOCASE);"
            "INSERT INTO images VALUES (1, 'a.jpg', 1.0, 100, 'abcdef01', 'Caf\xC3\xA9_Photo.jpg');"
            "INSERT INTO images VALUES (2, 'b.jpg', 1.0, 110, 'abcdef01', 'CAF\xC3\xA9_photo.JPG');"
            "INSERT INTO images VALUES (3, 'c.jpg', 1.0, 120, 'abcdef01', 'Caf\xC3\x89_Photo.jpg');"
            "INSERT INTO images VALUES (4, 'd.jpg', 1.0, 130, '1234', '\xC8\x98ucan.png');"
            "INSERT INTO images VALUES (5, 'e.jpg', 1.0, 140, '1234', '\xC8\x98UCAN.PNG');";
        check(SQ.exec(db, sqlSetup, NULL, NULL, NULL)==SQLITE_OK, "O6: populate pre-v3 + UTF-8 scratch DB");
        SQ.close_v2(db);

        const std::wstring wScratch = widen(scratch);
        check(dupesEngineInit(wScratch.c_str())==1, "O6: open pre-v3 scratch DB");
        const std::wstring q =
            L"SELECT images.imgidu, fullPath, imgmegapix, fsize, dHash, imgfile AS k0"
            L" FROM images ORDER BY k0, imgmegapix, fsize";
        // hasPix=1 must fail because imagesPixels does not exist; retrying with hasPix=0 succeeds.
        check(dupesQueryBegin(q.c_str(), 1, 1u, 1, 0, 1, 1024, 1)==0,
              "O6: deferred query fails cleanly on pre-v3 DB without imagesPixels");
        check(dupesQueryBegin(q.c_str(), 1, 1u, 1, 0, 0, 1024, 1)==1,
              "O6: retry without MSD succeeds on pre-v3 DB");
        while (dupesQueryStep(100) > 0) {}
        // Rows 1 & 2 share 'café_photo.jpg' (row 3 has uppercase 'É' U+00C9 which SQLite NOCASE does not fold);
        // rows 4 & 5 share 'Șucan.png'.
        check(dupesQueryRowCount()==4 && dupesQueryGroupCount()==2,
              "O6: UTF-8 buildRowKey matches SQLite ASCII-only NOCASE on non-ASCII text");

        dupesEngineRelease();
        remove(scratch.c_str());

        // O5: decodeFingerprintBytes 256-byte LUT across non-monotonic compressor scales
        unsigned char raw256[256];
        for (int v = 0; v < 256; v++) raw256[v] = (unsigned char)v;
        const int scales[] = { 1, 4, 2, 7, 3, 1 };
        int lutBad = 0;
        for (unsigned si = 0; si < sizeof(scales)/sizeof(scales[0]); si++)
        {
            dupesPixStride = 256;
            dupesPixScale = scales[si];
            dupesPixData.assign(256, 0);
            dupesPixOK.assign(1, 0);
            decodeFingerprintBytes(raw256, 0, 1);
            for (int v = 0; v < 256; v++)
            {
                const unsigned char want = (scales[si] > 1)
                    ? (unsigned char)floor((double)v / scales[si] + 0.5)
                    : (unsigned char)v;
                if (dupesPixData[v] != want) { lutBad++; break; }
            }
        }
        check(lutBad==0, "O5: decodeFingerprintBytes 256-byte LUT matches across scale changes");
        dupesPixData.clear(); dupesPixOK.clear(); dupesPixStride = 0; dupesPixScale = 1;
    }

    const std::wstring wmain = widen(dbPath);
    dupesEngineInit(wmain.c_str());
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
    printf("  pairs cache across failed searches\n");
    pairsCacheSurvivesFailedSearch();
    printf("  audit regressions (S1, S3, S5, S6, S7, S9, S12)\n");
    auditRegressions(dbPath);
    printf("  O6 deferred pixels + UTF-8 keys + O5 LUT\n");
    o6DeferredAndO5Lut(dbPath);
    // both query shapes, every time: the keyset cursor the interpreter sends this build,
    // and the plain LIMIT it falls back to for a qpvmain.dll without dupesHashHasKeyset()
    for ( int pass = 0 ; pass < 2 ; pass++)
    {
        const bool keyset = (pass==0);
        const char *shape = keyset ? "keyset cursor" : "plain LIMIT, as an older interpreter sends it";
        printf("  hash generation - %s\n", shape);
        hashGenerationWritesBack(dbPath, keyset);
        printf("  hash generation, unhashable fingerprints - %s\n", shape);
        hashGenerationSkipsShortFingerprints(dbPath, keyset);
        printf("  hash generation, a database refusing every write - %s\n", shape);
        hashGenerationEndsWhenWritesFail(dbPath, keyset);
    }

    dupesEngineRelease();
    SQ.close_v2(refDB);
    printf("\n  %s\n", failures ? "QUERY ENGINE TEST FAILED" : "query engine test passed");
    return failures ? 1 : 0;
}
