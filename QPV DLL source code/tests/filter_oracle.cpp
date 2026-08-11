// Oracle for the threshold filter and the grouping: the SHIPPED dupesApplyFilter(), text
// -sliced out of dupes-search.h, against a line-by-line transcription of the AHK it
// replaced - changeHdistLevelCached()'s pair loop, its union-find, and sortDupeGroups().
//
// This is the part of the pipeline where a subtle difference is invisible: nothing
// crashes, the duplicates are simply grouped or ordered slightly differently, and only a
// user comparing two builds side by side would ever notice. Both modes are covered:
//
//   - the union path (BreakDupesGroups=0, the default), where the smallest image index is
//     always the group root so the grouping cannot depend on the order pairs arrived in;
//   - the incremental path (BreakDupesGroups=1), which deliberately re-labels a group by
//     the distance of the pair currently being walked, and IS order-dependent - the whole
//     reason the sweep emits its pairs in a reproducible order.
//
// written by Marius Șucan with Claude Opus 5

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <chrono>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <algorithm>
#include <emmintrin.h>

typedef unsigned int       UINT;
typedef unsigned long long UINT64;
typedef long long          INT64;
typedef int                INT;
typedef int                LONG;
typedef void*              HWND;
typedef const wchar_t*     LPCWSTR;
#define DLL_API extern "C"
#define DLL_CALLCONV
#define QPV_FORCEINLINE inline __attribute__((always_inline))

__attribute__((unused)) static void fnOutputDebug(std::string) {}
static void SetWindowText(HWND, LPCWSTR) {}

#include "header_extract.h"
void dupesQueryFreeRows() {}
#include "block_extract.cpp"

// ======================================================================================
// The reference: changeHdistLevelCached() + sortDupeGroups(), transcribed.
// AHK object fields are kept as separate maps so the shape of the original stays legible;
// "" (unset) is modelled by absence from the map.
// ======================================================================================

struct RefRow { std::string gid; long long ham; long long mse; };

static bool isInRange(long long v, long long lo, long long hi) { return (v >= lo && v <= hi); }

static long long refFindRoot(std::map<long long,long long> &parentu, long long x) {
    long long r = x;
    while (parentu.count(r)) r = parentu[r];
    while (parentu.count(x) && parentu[x]!=r) { long long nx = parentu[x]; parentu[x] = r; x = nx; }
    return r;
}

static std::string pad9(long long v) {
    char b[32]; snprintf(b, sizeof(b), "%09lld", v); return b;
}
static std::string gidOf(long long root, long long tag) {
    char b[64]; snprintf(b, sizeof(b), "%lld_%lld", root, tag); return b;
}
static std::string gidRoot(const std::string &gid) {
    return gid.substr(0, gid.find('_'));
}

// changeHdistLevelCached(0, hamLo, hamHi, mseLo, mseHi) followed by sortDupeGroups().
// Returns the final ordered list of (imgIndex, gid, col33, col34).
static std::vector< std::pair<long long, RefRow> >
refFilter(const std::vector<DupePairRec> &pairs, int hamLo, int hamHi, int mseLo, int mseHi,
          int breakGroups, int remSingles, const std::vector<unsigned char> &imgKeep) {
    // allowMSE := testWasMSEdupes()
    const bool allowMSE = (pairs.size() >= 2 && pairs[0].mse < 2500 && pairs[1].mse < 2500);
    const bool doUnion = (breakGroups!=1);

    std::map<long long, RefRow> newArrayu;   // newArrayu[idu]
    std::map<long long, std::string> dupesIDs;
    std::map<long long,long long> parentu;
    std::vector<long long> keptA, keptB, keptH, keptM;

    for (size_t i = 0; i < pairs.size(); i++)
    {
        const long long idRa = pairs[i].idA, idRb = pairs[i].idB;
        const long long hamDist = pairs[i].hamDist, MSE = pairs[i].mse;
        if (!isInRange(hamDist, hamLo, hamHi)) continue;
        if (allowMSE && !isInRange(MSE, mseLo, mseHi)) continue;
        if (!imgKeep.empty()) {
            if ((size_t)idRa >= imgKeep.size() || imgKeep[idRa]==0) continue;
        }

        if (doUnion) {
            keptA.push_back(idRa); keptB.push_back(idRb);
            keptH.push_back(hamDist); keptM.push_back(MSE);
            const long long ra = refFindRoot(parentu, idRa), rb = refFindRoot(parentu, idRb);
            if (ra!=rb) parentu[std::max(ra, rb)] = std::min(ra, rb);
            continue;
        }

        const bool hasA = dupesIDs.count(idRa)!=0, hasB = dupesIDs.count(idRb)!=0;
        if (hasA && hasB) {
            // BreakDupesGroups=1 is the only way to get here
            std::string t = gidOf(atoll(gidRoot(newArrayu[idRa].gid).c_str()), hamDist);
            newArrayu[idRa].gid = t; newArrayu[idRa].ham = hamDist; newArrayu[idRa].mse = MSE;
            t = gidOf(atoll(gidRoot(newArrayu[idRb].gid).c_str()), hamDist);
            newArrayu[idRb].gid = t; newArrayu[idRb].ham = hamDist; newArrayu[idRb].mse = MSE;
            continue;
        }
        if (!hasA && !hasB) {
            const std::string t = gidOf(std::min(idRa, idRb), hamDist);
            dupesIDs[idRa] = t; dupesIDs[idRb] = t;
            RefRow ra0 = {t, hamDist, MSE}, rb0 = {t, hamDist, MSE};
            newArrayu[idRa] = ra0; newArrayu[idRb] = rb0;
            continue;
        }
        std::string t = hasA ? dupesIDs[idRa] : dupesIDs[idRb];
        t = gidOf(atoll(gidRoot(t).c_str()), hamDist);
        dupesIDs[idRa] = t; dupesIDs[idRb] = t;
        // pullDupeRowFromCache() seeds cols 33/34 at 100 and 2500
        if (!newArrayu.count(idRa)) { RefRow r = {t, 100, 2500}; newArrayu[idRa] = r; }
        else if (!newArrayu.count(idRb)) { RefRow r = {t, 100, 2500}; newArrayu[idRb] = r; }

        newArrayu[idRa].gid = t;
        newArrayu[idRa].ham = std::min(hamDist, std::min(newArrayu[idRa].ham, newArrayu[idRb].ham));
        newArrayu[idRa].mse = std::min(MSE, std::min(newArrayu[idRa].mse, newArrayu[idRb].mse));
        newArrayu[idRb].gid = t;
        newArrayu[idRb].ham = hamDist;   // BreakDupesGroups keeps the pair's own values here
        newArrayu[idRb].mse = MSE;
    }

    if (doUnion) {
        std::map<long long,long long> imgHam, imgMSE, grpHam;
        for (size_t k = 0; k < keptA.size(); k++) {
            const long long a = keptA[k], b = keptB[k], h = keptH[k], m = keptM[k];
            if (!imgHam.count(a) || h < imgHam[a]) imgHam[a] = h;
            if (!imgHam.count(b) || h < imgHam[b]) imgHam[b] = h;
            if (!imgMSE.count(a) || m < imgMSE[a]) imgMSE[a] = m;
            if (!imgMSE.count(b) || m < imgMSE[b]) imgMSE[b] = m;
            const long long r = refFindRoot(parentu, a);
            if (!grpHam.count(r) || h < grpHam[r]) grpHam[r] = h;
        }
        for (std::map<long long,long long>::const_iterator it = imgHam.begin(); it != imgHam.end(); ++it) {
            const long long idu = it->first;
            const long long r = refFindRoot(parentu, idu);
            RefRow row = {gidOf(r, grpHam[r]), it->second, imgMSE[idu]};
            newArrayu[idu] = row;
        }
    }

    // sortDupeGroups(fnewArrayu, ..., remSingles): count per root, flag per full group ID
    std::map<std::string, long long> grpIDv;
    std::set<std::string> groupies;
    std::vector< std::pair<std::string, long long> > listu;
    long long index = 0;
    for (std::map<long long, RefRow>::const_iterator it = newArrayu.begin(); it != newArrayu.end(); ++it) {
        const std::string &gid = it->second.gid;
        if (gid.empty() || gid.find('_')==std::string::npos) continue;
        index++;
        const std::string tg = gidRoot(gid);
        grpIDv[tg]++;
        if (grpIDv[tg] > remSingles) groupies.insert(gid);
        listu.push_back(std::make_pair(pad9(atoll(tg.c_str())) + "y" + gid + "z" + pad9(index), it->first));
    }
    std::sort(listu.begin(), listu.end());

    std::vector< std::pair<long long, RefRow> > out;
    for (size_t i = 0; i < listu.size(); i++) {
        const long long idu = listu[i].second;
        if (!groupies.count(newArrayu[idu].gid)) continue;
        out.push_back(std::make_pair(idu, newArrayu[idu]));
    }
    return out;
}

// ======================================================================================

static int failures = 0;
static void check(bool ok, const char *what) {
    printf("    %-62s %s\n", what, ok ? "ok" : "FAILED");
    if (!ok) failures++;
}

static UINT64 rngState = 1;
static void rngSeed(UINT64 s) { rngState = s ? s : 1; }
static UINT64 rnd64() {
    rngState ^= rngState << 13; rngState ^= rngState >> 7; rngState ^= rngState << 17;
    return rngState;
}
static UINT rndBelow(UINT n) { return (UINT)(rnd64() % n); }

// A pair list shaped like a real sweep's: images cluster into groups, distances are small,
// and some pairs carry no MSD at all.
static std::vector<DupePairRec> makePairs(UINT64 seed, UINT images, bool withMSD) {
    rngSeed(seed);
    std::vector<DupePairRec> out;
    const UINT clusters = 1 + images / 6;
    for (UINT i = 1; i <= images; i++)
        for (UINT j = i + 1; j <= images; j++)
        {
            if ((i % clusters)!=(j % clusters) && rndBelow(40)!=0)
               continue;

            DupePairRec p;
            p.idA = j; p.idB = i;      // the sweep reports (inner, outer), inner > outer
            p.hamDist = rndBelow(13);
            p.mse = withMSD ? rndBelow(400) : 2500;
            if (withMSD && rndBelow(15)==0)
               p.mse = 2500;           // a fingerprint was missing for this pair

            out.push_back(p);
        }
    return out;
}

static bool sameResult(const std::vector<std::pair<long long, RefRow> > &ref,
                       const std::vector<DupeResultRow> &got, std::string &why) {
    if (ref.size()!=got.size())
    {
       char b[128]; snprintf(b, sizeof(b), "row count %zu vs %zu", ref.size(), got.size());
       why = b; return false;
    }
    for (size_t i = 0; i < ref.size(); i++)
    {
        const std::string wantGid = ref[i].second.gid;
        const std::string gotGid = dupesGroupID(got[i].groupRoot, got[i].grpTag);
        if ((long long)got[i].imgIndex != ref[i].first || gotGid != wantGid
            || (long long)got[i].hamDist != ref[i].second.ham
            || (long long)got[i].mse != ref[i].second.mse)
        {
           char b[256];
           snprintf(b, sizeof(b), "row %zu: want id=%lld gid=%s ham=%lld mse=%lld, got id=%u gid=%s ham=%u mse=%u",
                    i, ref[i].first, wantGid.c_str(), ref[i].second.ham, ref[i].second.mse,
                    got[i].imgIndex, gotGid.c_str(), got[i].hamDist, got[i].mse);
           why = b; return false;
        }
    }
    return true;
}

static std::vector<DupeResultRow> runShipped(const std::vector<DupePairRec> &pairs,
                                             int hamLo, int hamHi, int mseLo, int mseHi,
                                             int breakGroups, int remSingles,
                                             const std::vector<unsigned char> &imgKeep) {
    dupesPairsList = pairs;
    dupesPairsRead = 0;
    dupesApplyFilter(hamLo, hamHi, mseLo, mseHi, breakGroups, remSingles,
                     imgKeep.empty() ? NULL : imgKeep.data(), (UINT)imgKeep.size());
    std::vector<DupeResultRow> out(dupesFilterRowCount());
    if (!out.empty())
       dupesFetchFiltered(out.data(), 0, (UINT)out.size());
    return out;
}

int main() {
    printf("  threshold filter and grouping vs the AHK it replaced\n");

    int cases = 0, mismatches = 0, nonEmpty = 0, totalRows = 0;
    std::string why;
    for (UINT64 seed = 1; seed <= 40; seed++)
    {
        const bool withMSD = (seed % 3)!=0;
        const UINT images = 4 + (UINT)(seed % 22);
        const std::vector<DupePairRec> pairs = makePairs(seed * 6151, images, withMSD);
        if (pairs.empty())
           continue;

        for (int variant = 0; variant < 6; variant++)
        {
            rngSeed(seed * 31 + variant);
            const int hamLo = 0, hamHi = (int)rndBelow(13);
            const int mseLo = 0, mseHi = (int)(50 + rndBelow(400));
            const int breakGroups = (variant & 1);
            const int remSingles = (variant >> 1) & 1;

            std::vector<unsigned char> keep;
            if (variant >= 4)
            {
               keep.assign(images + 2, 1);
               for (size_t i = 0; i < keep.size(); i += 3) keep[i] = 0;
            }

            const std::vector<std::pair<long long, RefRow> > ref =
                refFilter(pairs, hamLo, hamHi, mseLo, mseHi, breakGroups, remSingles, keep);
            const std::vector<DupeResultRow> got =
                runShipped(pairs, hamLo, hamHi, mseLo, mseHi, breakGroups, remSingles, keep);

            cases++;
            totalRows += (int)ref.size();
            if (!ref.empty()) nonEmpty++;
            if (!sameResult(ref, got, why))
            {
               mismatches++;
               if (mismatches <= 4)
                  printf("    MISMATCH seed=%llu variant=%d break=%d mono=%d hamHi=%d: %s\n",
                         (unsigned long long)seed, variant, breakGroups, remSingles, hamHi, why.c_str());
            }
        }
    }

    char msg[160];
    snprintf(msg, sizeof(msg), "%d filter cases, %d result rows: identical to the AHK", cases, totalRows);
    check(mismatches==0, msg);
    check(nonEmpty > cases / 2, "most cases actually produce a filtered list");
    check(totalRows > 2000, "enough rows compared to be worth something");

    // the mutation check: a union-find that does not force the smaller index to be the
    // root still groups correctly but labels the groups differently, and the oracle has
    // to notice. Done by hand rather than by sed because it is a semantic change.
    {
        std::vector<DupePairRec> pairs;
        DupePairRec a = {5, 9, 1, 2500}; pairs.push_back(a);
        DupePairRec b = {9, 2, 1, 2500}; pairs.push_back(b);
        const std::vector<unsigned char> none;
        const std::vector<std::pair<long long, RefRow> > ref = refFilter(pairs, 0, 12, 0, 2500, 0, 0, none);
        const std::vector<DupeResultRow> got = runShipped(pairs, 0, 12, 0, 2500, 0, 0, none);
        check(sameResult(ref, got, why), "A~B then B~C makes ONE group of three");
        check(got.size()==3 && got[0].groupRoot==2, "and its ID is the smallest image index");
    }

    // re-filtering must be repeatable: the same bounds twice give the same list, and a
    // narrower bound can only ever shrink it
    {
        const std::vector<DupePairRec> pairs = makePairs(777, 20, true);
        const std::vector<unsigned char> none;
        const std::vector<DupeResultRow> wide = runShipped(pairs, 0, 12, 0, 2500, 0, 0, none);
        const std::vector<DupeResultRow> again = runShipped(pairs, 0, 12, 0, 2500, 0, 0, none);
        const std::vector<DupeResultRow> tight = runShipped(pairs, 0, 2, 0, 2500, 0, 0, none);
        check(wide.size()==again.size() &&
              (wide.empty() || memcmp(wide.data(), again.data(), wide.size()*sizeof(DupeResultRow))==0),
              "the same thresholds twice give byte-identical results");
        check(tight.size() <= wide.size(), "a narrower threshold cannot add rows");
        check(dupesPairsList.size()==pairs.size(), "the pair list survives being filtered");
    }

    printf("\n  %s\n", failures ? "FILTER ORACLE FAILED" : "filter oracle passed");
    return failures ? 1 : 0;
}
