// Runs the shipped lib/dir-scan.h, the per-file work of GetFilesList(), off Windows.
//
// The file is compiled VERBATIM. What it needs from Windows is CharLowerBuffW(), stood in
// for below, and sqlite3, which sqlite-dynamic.h binds at run time, so libsqlite3.so.0 gives
// the genuine article; without it the database part is skipped.
//
// What must hold:
//   - the files and the sub-folders one block yields are the ones the per-file loop of the
//     script picked [the reference below], in both record layouts and for both layouts of
//     the directory records, with every field in its slot;
//   - an output buffer that is too small is reported with the size that fits, and never
//     written past; a block that is cut short or damaged is never read past;
//   - the rows DirScanInsertRows() writes, the row IDs it hands out and the records it
//     refuses are the ones addSQLdbEntry() of the script produces, statement by statement.
//
// written by Marius Șucan with Claude Fable 5

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>
#include <set>
#include <algorithm>
#include <random>
#include <csignal>
#include <sys/mman.h>
#include <unistd.h>
#include <windows.h>             // tests/shim/windows.h, via -Ishim

#define DLL_API extern "C"
#define DLL_CALLCONV
#define QPV_FORCEINLINE inline __attribute__((always_inline))

__attribute__((unused)) static void fnOutputDebug(std::string s) {
    if (getenv("QPV_TEST_VERBOSE")) printf("    [dbg] %s\n", s.c_str());
}
#define QPV_DBG(...) fnOutputDebug(__VA_ARGS__)

typedef std::u16string U16;
static const unsigned short *US(const U16 &s) { return (const unsigned short*)s.c_str(); }
typedef wchar_t* LPWSTR;

// Stands in for the system: enough case pairs to show which text was folded, and how often.
static unsigned short lowerOne(unsigned short c) {
    if (c>='A' && c<='Z') return c + 32;
    if (c>=0xC0 && c<=0xDE && c!=0xD7) return c + 32;      // Latin-1
    if (c>=0x391 && c<=0x3A9 && c!=0x3A2) return c + 32;   // Greek
    if (c>=0x410 && c<=0x42F) return c + 32;               // Cyrillic
    return c;
}
static DWORD CharLowerBuffW(LPWSTR s, DWORD n) {
    unsigned short *p = (unsigned short*)s;
    for (DWORD i = 0; i < n; i++) p[i] = lowerOne(p[i]);
    return n;
}

// Stands in for the time zone arithmetic of qpv-main.cpp: any FILETIME becomes a stamp of
// the right shape, and the seconds differ from file to file so that dropping them shows.
static INT64 qpvFileTimeToLocalStamp(INT64 ft) {
    if (ft <= 0) return 0;
    return 20000101000000LL + (ft % 86400LL)/3600*10000 + (ft % 3600LL)/60*100 + ft % 60LL;
}

#include "../lib/sqlite-dynamic.h"   // verbatim, the shipped run-time binder
#ifndef QPV_DIR_SCAN_SOURCE
#define QPV_DIR_SCAN_SOURCE "../lib/dir-scan.h"
#endif
#include QPV_DIR_SCAN_SOURCE

// ---- helpers -------------------------------------------------------------------------

static int failures = 0;
static void check(bool ok, const char *what) {
    printf("    %-70s %s\n", what, ok ? "ok" : "FAILED");
    if (!ok) failures++;
}

static U16 u16(const char *s) {
    U16 w;
    for (; *s; s++) w.push_back((char16_t)(unsigned char)*s);
    return w;
}

static std::string toUTF8(const U16 &s) {
    std::string out;
    for (size_t i = 0; i < s.size(); i++)
    {
        const unsigned int c = s[i];
        if (c < 0x80) out.push_back((char)c);
        else if (c < 0x800) { out.push_back((char)(0xC0 | (c >> 6))); out.push_back((char)(0x80 | (c & 0x3F))); }
        else { out.push_back((char)(0xE0 | (c >> 12))); out.push_back((char)(0x80 | ((c >> 6) & 0x3F))); out.push_back((char)(0x80 | (c & 0x3F))); }
    }
    return out;
}

struct Entry {
    U16 name;
    unsigned int attr;
    INT64 size, ctime, mtime;
};

// One block of directory records the way GetFileInformationByHandleEx() fills it:
// records aligned to 8 bytes, chained by NextEntryOffset, the last one with 0.
static std::vector<unsigned char> buildBlock(const std::vector<Entry> &list, int nameOffset, size_t capacity, unsigned char junk) {
    std::vector<unsigned char> b(capacity, junk);
    size_t at = 0, prev = 0;
    for (size_t i = 0; i < list.size(); i++)
    {
        const Entry &e = list[i];
        const unsigned int nameBytes = (unsigned int)e.name.size()*2;
        const size_t rec = (nameOffset + nameBytes + 7) & ~(size_t)7;
        if (at + rec > capacity) { fprintf(stderr, "test block too small\n"); exit(2); }
        memset(&b[at], 0, rec);
        if (i > 0)
        {
           const unsigned int next = (unsigned int)(at - prev);
           memcpy(&b[prev], &next, 4);
        }
        memcpy(&b[at + 8], &e.ctime, 8);
        memcpy(&b[at + 24], &e.mtime, 8);
        memcpy(&b[at + 40], &e.size, 8);
        memcpy(&b[at + 56], &e.attr, 4);
        memcpy(&b[at + 60], &nameBytes, 4);
        if (nameBytes) memcpy(&b[at + nameOffset], e.name.data(), nameBytes);
        prev = at;
        at += rec;
    }
    return b;
}

static U16 foldASCII(const U16 &s) {
    U16 r = s;
    for (size_t i = 0; i < r.size(); i++) if (r[i]>='A' && r[i]<='Z') r[i] += 32;
    return r;
}

static std::set<U16> listSet(const U16 &extList) {
    std::set<U16> s;
    U16 cur;
    for (size_t i = 0; i <= extList.size(); i++)
    {
        if (i==extList.size() || extList[i]=='|')
        {
           if (!cur.empty()) s.insert(foldASCII(cur));
           cur.clear();
        } else cur.push_back(extList[i]);
    }
    return s;
}

// The reference: what the per-file loop of the script kept, one test at a time.
struct RefFile { U16 name; INT64 size, modified, created; };
static void refParse(const std::vector<Entry> &list, const std::set<U16> &exts, INT64 biggerThan, bool recursive,
                     std::vector<RefFile> &files, std::vector<U16> &dirs) {
    for (size_t i = 0; i < list.size(); i++)
    {
        const Entry &e = list[i];
        if (e.attr & 0x10)
        {
           if (!recursive || e.name.empty() || (e.attr & 0x400)) continue;
           if (e.name==u16(".") || e.name==u16("..")) continue;
           dirs.push_back(e.name);
           continue;
        }
        if (!(e.size > biggerThan)) continue;
        const size_t dot = e.name.rfind(u'.');
        if (dot==U16::npos) continue;
        if (!exts.count(foldASCII(e.name.substr(dot + 1)))) continue;
        RefFile f;
        f.name = e.name; f.size = e.size;
        f.modified = qpvFileTimeToLocalStamp(e.mtime);
        f.created = qpvFileTimeToLocalStamp(e.ctime);
        files.push_back(f);
    }
}

static std::vector<unsigned char> compile(const U16 &extList) {
    const int need = -DirScanCompileExts(US(extList), NULL, 0);
    std::vector<unsigned char> t((size_t)need + 16, 0xEE);
    const int got = DirScanCompileExts(US(extList), t.data(), need);
    if (got!=need || t[need]!=0xEE) { fprintf(stderr, "extension table: %d bytes asked, %d written\n", need, got); failures++; }
    return t;
}

static U16 nameAt(const unsigned char *p) {
    U16 s;
    for (const unsigned short *c = (const unsigned short*)p; *c; c++) s.push_back((char16_t)*c);
    return s;
}

// Parses one block in the given layout and compares everything it hands back.
static bool parseMatches(const std::vector<unsigned char> &block, int nameOffset, const std::vector<unsigned char> &table,
                         INT64 biggerThan, int flags, const std::vector<RefFile> &files, const std::vector<U16> &dirs) {
    const bool packed = (flags & 2)!=0;
    int info[4] = {-9, -9, -9, -9};
    std::vector<unsigned char> out(1 << 16, 0xAB);
    int n = DirScanParseBlock(block.data(), (int)block.size(), nameOffset, table.data(), biggerThan, flags, out.data(), 0, info);
    if (files.empty() && dirs.empty())
    {
       if (n!=0) return false;
    } else
    {
       if (n!=-1) return false;                      // no room at all: the size is asked for
       const int need = info[0];
       if (need <= 0) return false;
       for (size_t i = 0; i < out.size(); i++) if (out[i]!=0xAB) return false;   // and nothing is written

       if (DirScanParseBlock(block.data(), (int)block.size(), nameOffset, table.data(), biggerThan, flags, out.data(), need - 1, info)!=-1 || info[0]!=need)
          return false;

       out.assign((size_t)need + 64, 0xAB);
       n = DirScanParseBlock(block.data(), (int)block.size(), nameOffset, table.data(), biggerThan, flags, out.data(), need, info);
       for (size_t i = (size_t)need; i < out.size(); i++) if (out[i]!=0xAB) return false;   // never past the size asked for
    }

    if (n!=(int)files.size() || info[2]!=(int)dirs.size()) return false;
    size_t longest = 0, at = 0;
    for (size_t i = 0; i < files.size(); i++) longest = std::max(longest, files[i].name.size());
    const size_t stride = (24 + (longest + 1)*2 + 7) & ~(size_t)7;
    if (!packed && info[1]!=(int)stride) return false;
    if (packed && info[1]!=0) return false;

    for (size_t i = 0; i < files.size(); i++)
    {
        const unsigned char *r = out.data() + at;
        INT64 v[4];
        memcpy(v, r, 32);
        if (v[0]!=files[i].size || v[1]!=files[i].modified || v[2]!=files[i].created) return false;
        if (packed)
        {
           unsigned int recBytes, nameBytes;
           memcpy(&recBytes, r + 32, 4);
           memcpy(&nameBytes, r + 36, 4);
           if (v[3]!=-1 || nameBytes!=files[i].name.size()*2) return false;     // no row yet
           if (recBytes!=((40 + nameBytes + 2 + 7) & ~7u)) return false;
           if (nameAt(r + 40)!=files[i].name) return false;
           for (unsigned int k = 40 + nameBytes; k < recBytes; k++) if (r[k]!=0) return false;
           at += recBytes;
        } else
        {
           if (nameAt(r + 24)!=files[i].name) return false;
           at += stride;
        }
    }

    if (info[0]!=(int)at) return false;
    size_t longestDir = 0;
    for (size_t i = 0; i < dirs.size(); i++) longestDir = std::max(longestDir, dirs[i].size());
    if (info[3]!=(int)((longestDir + 1)*2)) return false;
    for (size_t i = 0; i < dirs.size(); i++)
        if (nameAt(out.data() + at + i*info[3])!=dirs[i]) return false;

    return true;
}

static const char *EXTS = "ico|dib|dng|tif|tiff|png|bmp|gif|jpg|jpeg|jpe|DDS|EXR|HDR|JP2|JXR|AVIF|HEIC|JXL|TGA|G3|crw|cr2|nef|3fr|k25|x3f|jfif|webp|svg|pdf";

static U16 randomName(std::mt19937 &rng, const std::vector<U16> &exts) {
    static const char *stems[] = {"IMG_2024", "photo", "a", "Scan 001", "it's", "archive.tar", "UPPER", ".hidden", "x.y.z", "", "noext", "trailing."};
    U16 n = u16(stems[rng() % 12]);
    if (rng() % 5==0) { n.push_back(0xC9); n.push_back(0x3A9); n.push_back(0x416); }   // É Ω Ж
    if (rng() % 9==0) n.append(rng() % 220, u'w');
    switch (rng() % 6)
    {
        case 0: break;                                           // as it is
        case 1: n += u16(".txt"); break;
        case 2: n += u16(".jpgx"); break;
        default:
        {
           U16 e = exts[rng() % exts.size()];
           for (size_t i = 0; i < e.size(); i++)
               if (rng() % 2) e[i] = (e[i]>='a' && e[i]<='z') ? e[i] - 32 : ((e[i]>='A' && e[i]<='Z') ? e[i] + 32 : e[i]);
           n.push_back('.');
           n += e;
        }
    }
    return n;
}

static void testExtTable() {
    printf("  the extensions table\n");
    const U16 list = u16(EXTS);
    const std::vector<unsigned char> t = compile(list);
    const std::set<U16> ref = listSet(list);

    bool all = true;
    for (std::set<U16>::const_iterator it = ref.begin(); it!=ref.end(); ++it)
    {
        U16 up = *it;
        for (size_t i = 0; i < up.size(); i++) if (up[i]>='a' && up[i]<='z') up[i] -= 32;
        if (!qpvDSisListedExt(t.data(), US(*it), (unsigned int)it->size())) all = false;
        if (!qpvDSisListedExt(t.data(), US(up), (unsigned int)up.size())) all = false;
    }
    check(all, "every listed extension is found, in either case");

    const char *strangers[] = {"jp", "jpgg", "jpeg2", "", "p", "png ", " png", "tar", "txt", "jpxg", "3f", "g33", "0", "1"};
    bool none = true;
    for (size_t i = 0; i < sizeof(strangers)/sizeof(strangers[0]); i++)
    {
        const U16 s = u16(strangers[i]);
        if (qpvDSisListedExt(t.data(), US(s), (unsigned int)s.size())) none = false;
    }
    U16 kelvin = u16("xdc");                // K as U+212A folds to "k" only outside ASCII
    kelvin[0] = 0x212A;
    const std::vector<unsigned char> tk = compile(u16("kdc|jpg"));
    if (qpvDSisListedExt(tk.data(), US(kelvin), 3)) none = false;
    check(none, "near misses and non-ASCII look-alikes are not");

    std::vector<unsigned char> small(8, 0x55);
    const int need = -DirScanCompileExts(US(list), NULL, 0);
    bool refused = DirScanCompileExts(US(list), small.data(), 8)==-need;
    for (size_t i = 0; i < small.size(); i++) if (small[i]!=0x55) refused = false;
    check(refused && need > 16, "a table that is too small is refused, with the size that fits");

    std::mt19937 rng(11);
    bool same = true;
    for (int round = 0; round < 400 && same; round++)
    {
        U16 l;
        const int count = rng() % 60;
        for (int i = 0; i < count; i++)
        {
            const int len = (rng() % 7==0) ? 0 : 1 + rng() % ((rng() % 20==0) ? 40 : 5);
            for (int k = 0; k < len; k++) l.push_back((char16_t)("abcXYZ019_"[rng() % 10]));
            if (i + 1 < count || rng() % 4==0) l.push_back('|');
        }
        const std::vector<unsigned char> rt = compile(l);
        const std::set<U16> rs = listSet(l);
        for (int probe = 0; probe < 300; probe++)
        {
            U16 s;
            const int len = rng() % 6;
            for (int k = 0; k < len; k++) s.push_back((char16_t)("abcxyzABCXYZ019_"[rng() % 16]));
            if (rs.count(foldASCII(s))!=(size_t)qpvDSisListedExt(rt.data(), US(s), (unsigned int)s.size())) same = false;
        }
        for (std::set<U16>::const_iterator it = rs.begin(); it!=rs.end(); ++it)
            if (!qpvDSisListedExt(rt.data(), US(*it), (unsigned int)it->size())) same = false;
    }
    check(same, "400 random lists [empty items, repeats, long ones] answer as a set does");
}

static void testParse() {
    printf("  one block of directory records\n");
    const U16 list = u16(EXTS);
    const std::vector<unsigned char> table = compile(list);
    const std::set<U16> exts = listSet(list);
    std::vector<U16> extVec(exts.begin(), exts.end());

    // the cases the script's loop had a test for, one record each
    std::vector<Entry> edge;
    const INT64 T1 = 133500000000000000LL, T2 = 133500000123456789LL;
    #define ADD(n, a, s) { Entry e; e.name = u16(n); e.attr = a; e.size = s; e.ctime = T1 + edge.size()*10000000LL*61; e.mtime = T2 + edge.size()*10000000LL*3601; edge.push_back(e); }
    ADD(".", 0x10, 0)              ADD("..", 0x10, 0)
    ADD("plain.jpg", 0x20, 43)     ADD("small.jpg", 0x20, 42)      ADD("empty.jpg", 0x20, 0)
    ADD("UPPER.JPG", 0x20, 5000)   ADD("Mixed.JpEg", 0x20, 5000)   ADD("two.dots.png", 0x20, 99)
    ADD("noextension", 0x20, 99)   ADD(".jpg", 0x22, 99)           ADD("ends.with.dot.", 0x20, 99)
    ADD("readme.txt", 0x20, 99)    ADD("a.jpgx", 0x20, 99)         ADD("photo.jpg.bak", 0x20, 99)
    ADD("it's.g3", 0x20, 99)       ADD("huge.tif", 0x20, 9000000000LL)
    ADD("folder", 0x10, 0)         ADD("folder.jpg", 0x10, 4096)   ADD("...", 0x10, 0)
    ADD(".git", 0x12, 0)           ADD("junction", 0x410, 0)       ADD("", 0x10, 0)
    ADD("link.png", 0x420, 77)     ADD("last.webp", 0x20, 43)
    #undef ADD
    Entry longOne;
    longOne.name = U16(250, u'L') + u16(".avif");
    longOne.attr = 0x20; longOne.size = 100; longOne.ctime = T1; longOne.mtime = T2;
    edge.push_back(longOne);
    Entry greek = longOne;
    greek.name = u16("x.jpg");
    greek.name[0] = 0x3A9;
    edge.push_back(greek);

    bool ok = true;
    for (int nameOffset = 68; nameOffset <= 104; nameOffset += 36)
    for (int flags = 0; flags < 4; flags++)
    {
        std::vector<RefFile> files;
        std::vector<U16> dirs;
        refParse(edge, exts, 42, (flags & 1)!=0, files, dirs);
        const std::vector<unsigned char> block = buildBlock(edge, nameOffset, 1 << 15, 0x5A);
        if (!parseMatches(block, nameOffset, table, 42, flags, files, dirs)) ok = false;
        if (flags==1 && (files.size()!=11 || dirs.size()!=4)) ok = false;   // counted by hand
    }
    check(ok, "the hand-made cases: 11 files and 4 folders, every field in its slot");

    std::mt19937 rng(2026);
    bool same = true;
    int blocks = 0;
    for (int round = 0; round < 3000 && same; round++)
    {
        std::vector<Entry> l;
        const int count = rng() % 40;
        for (int i = 0; i < count; i++)
        {
            Entry e;
            e.name = randomName(rng, extVec);
            e.attr = (rng() % 6==0) ? 0x10 : 0x20;
            if (rng() % 13==0) e.attr |= 0x400;
            if ((e.attr & 0x10) && rng() % 7==0) e.name = u16(rng() % 2 ? "." : "..");
            static const INT64 sizes[] = {0, 1, 41, 42, 43, 44, 120, 121, 4096, 5000000000LL};
            e.size = sizes[rng() % 10];
            e.ctime = (rng() % 20==0) ? 0 : 130000000000000000LL + (INT64)(rng() % 1000000000)*10000000LL;
            e.mtime = (rng() % 20==0) ? 0 : 130000000000000000LL + (INT64)(rng() % 1000000000)*10000000LL;
            l.push_back(e);
        }
        const int nameOffset = (rng() % 2) ? 68 : 104;
        const int flags = rng() % 4;
        const INT64 biggerThan = (rng() % 3==0) ? 120 : 42;
        std::vector<RefFile> files;
        std::vector<U16> dirs;
        refParse(l, exts, biggerThan, (flags & 1)!=0, files, dirs);
        const std::vector<unsigned char> block = buildBlock(l, nameOffset, 1 << 16, (unsigned char)rng());
        if (!parseMatches(block, nameOffset, table, biggerThan, flags, files, dirs)) same = false;
        blocks++;
    }
    check(same && blocks==3000, "3000 random blocks, both layouts of each kind, match the reference");

    // A block that ends early or lies about its sizes: placed right against a page that
    // cannot be read, so one byte too far ends this test.
    const long page = sysconf(_SC_PAGESIZE);
    const size_t span = (size_t)page*8;
    unsigned char *arena = (unsigned char*)mmap(NULL, span + page, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
    mprotect(arena + span, page, PROT_NONE);
    std::vector<Entry> l;
    for (int i = 0; i < 60; i++)
    {
        Entry e;
        e.name = randomName(rng, extVec);
        e.attr = (i % 7==0) ? 0x10 : 0x20;
        e.size = 5000; e.ctime = T1; e.mtime = T2;
        l.push_back(e);
    }
    const std::vector<unsigned char> whole = buildBlock(l, 68, 1 << 15, 0);
    std::vector<unsigned char> out(1 << 18);
    int info[4];
    bool bounded = true;
    for (int round = 0; round < 20000; round++)
    {
        const size_t bytes = (68 + rng() % 9000 + 7) & ~(size_t)7;      // records start on 8 bytes, as the system lays them
        unsigned char *b = arena + span - bytes;
        memcpy(b, whole.data(), bytes);
        if (round % 3==1)
        {
           const unsigned int wild = rng();
           memcpy(b + (rng() % (bytes - 4)), &wild, 4);
        } else if (round % 3==2)
        {
           const unsigned int wild = (rng() % 4) ? rng() % 20000 : 0xFFFFFFF0u + rng() % 16;
           size_t rec = 0;
           for (int hop = rng() % 20; hop > 0; hop--)
           {
               unsigned int next;
               memcpy(&next, b + rec, 4);
               if (!next || rec + next + 64 > bytes) break;
               rec += next;
           }
           if (rec + 64 <= bytes) memcpy(b + rec + ((rng() % 2) ? 0 : 60), &wild, 4);
        }
        const int n = DirScanParseBlock(b, (int)bytes, 68, table.data(), 42, rng() % 4, out.data(), (int)out.size(), info);
        if (n < 0 && n!=-1) bounded = false;
        if (n >= 0 && (info[0] < 0 || (size_t)info[0] + (size_t)info[2]*info[3] > out.size())) bounded = false;
    }
    munmap(arena, span + page);
    check(bounded, "20000 cut or damaged blocks are never read past their end");

    int infoBad[4] = {7, 7, 7, 7};
    const std::vector<unsigned char> blk = buildBlock(edge, 68, 1 << 15, 0);
    std::vector<unsigned char> notTable(64, 0);
    bool refused = DirScanParseBlock(NULL, 100, 68, table.data(), 42, 1, out.data(), 100, infoBad)==-2
                && DirScanParseBlock(blk.data(), 60, 68, table.data(), 42, 1, out.data(), 100, infoBad)==-2
                && DirScanParseBlock(blk.data(), (int)blk.size(), 68, notTable.data(), 42, 1, out.data(), 100, infoBad)==-2
                && DirScanParseBlock(blk.data(), (int)blk.size(), 68, table.data(), 42, 1, out.data(), -1, infoBad)==-2
                && DirScanParseBlock(blk.data(), (int)blk.size(), 68, table.data(), 42, 1, out.data(), 100, NULL)==-2;
    check(refused, "missing buffers and a table that is not one are refused");
}

// ---- the database ----------------------------------------------------------------------

// The images table and its indexes, as SLDBinitSQLdb() and SLDBindexesSQL() of the script make them.
static const char *SCHEMA =
    "CREATE TABLE images (imgidu NUMERIC PRIMARY KEY NOT NULL, imgfile TEXT COLLATE NOCASE NOT NULL, imgfolder TEXT COLLATE NOCASE NOT NULL, "
    "fullPath TEXT AS (imgfolder||'\\'||imgfile), fsize INT, kbfsize FLOAT AS (round(cast(fsize AS float)/1024,1)), fmodified INT, fcreated INT, "
    "imgwidth INT, imgheight INT, imgframes INT, imgdpi INT, imgpixfmt TEXT COLLATE NOCASE, imgwhratio FLOAT AS (round(cast(imgwidth AS float)/imgheight, 5)), "
    "imgmegapix FLOAT AS (round((cast(imgwidth AS float)*imgheight)/1000000, 5)), imgmedian FLOAT, imgavg FLOAT, imghpeak FLOAT, imghlow FLOAT, imghmode FLOAT, "
    "imghrms FLOAT, imghminu FLOAT, imghrange FLOAT, dHash TEXT, pHash TEXT, lHash TEXT, HdHash TEXT, HpHash TEXT, HlHash TEXT, isDeleted INT DEFAULT 0, UNIQUE (fullPath));"
    "CREATE INDEX IF NOT EXISTS imgsIndex ON images(imgidu, imgfolder, imgfile); CREATE INDEX IF NOT EXISTS imgsAliveIndex ON images(isDeleted);";

static INT64 (*realLastRowID)(sqlite3*) = NULL;
static const char* (*realErrmsg)(sqlite3*) = NULL;

static sqlite3 *openDB(const char *seedSQL) {
    sqlite3 *db = NULL;
    if (SQ.open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | 0x4, NULL)!=SQLITE_OK) return NULL;   // 0x4 = SQLITE_OPEN_CREATE
    if (SQ.exec(db, SCHEMA, NULL, NULL, NULL)!=SQLITE_OK) return NULL;
    if (seedSQL && SQ.exec(db, seedSQL, NULL, NULL, NULL)!=SQLITE_OK) return NULL;
    return db;
}

static std::string quoted(const std::string &s) {
    std::string r = "'";
    for (size_t i = 0; i < s.size(); i++) { r.push_back(s[i]); if (s[i]=='\'') r.push_back('\''); }
    return r + "'";
}

static U16 lowerAll(const U16 &s) {
    U16 r = s;
    for (size_t i = 0; i < r.size(); i++) r[i] = (char16_t)lowerOne((unsigned short)r[i]);
    return r;
}

// addSQLdbEntry() of the script, statement by statement: the texts interpolated as they
// are, a second attempt with them escaped, and the factCheck test on the last new row.
static bool legacyAdd(sqlite3 *db, const U16 &name, const U16 &folder, INT64 fsize, INT64 modified, INT64 created,
                      INT64 &rowID, int factCheck, INT64 &prevNewRow) {
    const std::string n = toUTF8(lowerAll(name)), f = toUTF8(lowerAll(folder));
    const std::string m = std::to_string(modified).substr(0, 12), c = std::to_string(created).substr(0, 12);
    const std::string tail = ", '" + std::to_string(fsize) + "', '" + m + "', '" + c + "') ON CONFLICT(fullPath) DO UPDATE SET isDeleted=0;";
    const std::string head = "INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize, fmodified, fcreated) VALUES (" + std::to_string(rowID) + ", 0, ";
    std::string sql = head + "'" + n + "', '" + f + "'" + tail;
    if (SQ.exec(db, sql.c_str(), NULL, NULL, NULL)!=SQLITE_OK)
    {
       if (strstr(realErrmsg(db), "constraint failed")) return false;
       sql = head + quoted(n) + ", " + quoted(f) + tail;
       if (SQ.exec(db, sql.c_str(), NULL, NULL, NULL)!=SQLITE_OK) return false;
    }

    if (factCheck==1)
    {
       const INT64 last = realLastRowID(db);
       if (last==prevNewRow || !last) return false;
       prevNewRow = last;
    }
    rowID++;
    return true;
}

static std::string dump(sqlite3 *db) {
    std::string all;
    sqlite3_stmt *st = NULL;
    const wchar_t *q = L"SELECT imgidu, typeof(imgidu), hex(imgfile), hex(imgfolder), hex(fullPath), fsize, typeof(fsize), fmodified, typeof(fmodified), "
                       L"fcreated, typeof(fcreated), kbfsize, isDeleted, imgwidth IS NULL FROM images ORDER BY imgidu;";
    if (SQ.prepare16_v2(db, q, -1, &st, NULL)!=SQLITE_OK) return "prepare failed";
    while (SQ.step(st)==SQLITE_ROW)
    {
        for (int c = 0; c < SQ.column_count(st); c++)
        {
            const std::wstring &w = qpvT_colText(st, c);
            for (size_t i = 0; i < w.size(); i++) all.push_back((char)w[i]);
            all.push_back('|');
        }
        all.push_back('\n');
    }
    SQ.finalize(st);
    return all;
}

struct Folder { U16 path; std::vector<RefFile> files; };

// Packs the files of one folder the way DirScanParseBlock() does, by running it.
static std::vector<unsigned char> packFolder(const Folder &f, const std::vector<unsigned char> &table, std::vector<INT64> &ftimes) {
    std::vector<Entry> l;
    for (size_t i = 0; i < f.files.size(); i++)
    {
        Entry e;
        e.name = f.files[i].name; e.attr = 0x20; e.size = f.files[i].size;
        e.mtime = ftimes[i*2]; e.ctime = ftimes[i*2 + 1];
        l.push_back(e);
    }
    const std::vector<unsigned char> block = buildBlock(l, 68, 1 << 18, 0);
    std::vector<unsigned char> out(1 << 18);
    int info[4];
    const int n = DirScanParseBlock(block.data(), (int)block.size(), 68, table.data(), 42, 2, out.data(), (int)out.size(), info);
    if (n!=(int)f.files.size()) { fprintf(stderr, "packing a test folder kept %d of %d files\n", n, (int)f.files.size()); failures++; }
    out.resize(info[0]);
    return out;
}

static bool insertScenario(const char *seedSQL, int factCheck, INT64 firstRowID, std::mt19937 &rng, const std::vector<unsigned char> &table, bool &sawRefusal) {
    std::vector<Folder> folders;
    std::vector<std::vector<INT64> > ftimes;
    const char *paths[] = {"C:\\Photos\\2019", "C:\\Photos\\It's a \"trip\"", "D:", "C:\\Photos\\2019\\sub"};
    for (int d = 0; d < 4; d++)
    {
        Folder f;
        f.path = u16(paths[d]);
        if (d==1) { f.path.push_back(0xC9); f.path.push_back(0x416); }
        std::vector<INT64> t;
        const int count = (d==2) ? 0 : 3 + rng() % 40;
        for (int i = 0; i < count; i++)
        {
            RefFile r;
            r.name = u16("IMG_") + u16(std::to_string(i).c_str());
            if (i % 5==0) r.name += u16(" it's");
            if (i % 6==0) { r.name.push_back(0xC9); r.name.push_back(0x3A9); }
            if (i==7) r.name.append(340, u'N');        // longer than the stack buffer
            r.name += u16((i % 2) ? ".JPG" : ".png");
            r.size = 43 + rng() % 100000;
            const INT64 mt = (i % 11==10) ? 0 : 130000000000000000LL + (INT64)(rng() % 1000000000)*10000000LL;
            const INT64 ct = 130000000000000000LL + (INT64)(rng() % 1000000000)*10000000LL;
            r.modified = qpvFileTimeToLocalStamp(mt);
            r.created = qpvFileTimeToLocalStamp(ct);
            t.push_back(mt); t.push_back(ct);
            f.files.push_back(r);
        }
        folders.push_back(f);
        ftimes.push_back(t);
    }

    sqlite3 *dbNew = openDB(seedSQL), *dbRef = openDB(seedSQL);
    if (!dbNew || !dbRef) return false;

    sqlite3_stmt *st = NULL;
    const wchar_t *ins = L"INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize, fmodified, fcreated) VALUES (?1, 0, ?2, ?3, ?4, ?5, ?6) ON CONFLICT(fullPath) DO UPDATE SET isDeleted=0;";
    if (SQ.prepare16_v2(dbNew, ins, -1, &st, NULL)!=SQLITE_OK) return false;

    bool same = true;
    INT64 idNew = firstRowID, idRef = firstRowID, prevNewRow = realLastRowID(dbRef);
    for (size_t d = 0; d < folders.size(); d++)
    {
        std::vector<unsigned char> packed = packFolder(folders[d], table, ftimes[d]);
        const U16 folderLower = lowerAll(folders[d].path);
        const int added = DirScanInsertRows(dbNew, st, packed.data(), (int)folders[d].files.size(), US(folderLower), &idNew, factCheck);

        int addedRef = 0;
        const unsigned char *r = packed.data();
        for (size_t i = 0; i < folders[d].files.size(); i++)
        {
            const RefFile &f = folders[d].files[i];
            const INT64 before = idRef;
            const bool took = legacyAdd(dbRef, f.name, folders[d].path, f.size, f.modified, f.created, idRef, factCheck, prevNewRow);
            INT64 given;
            unsigned int recBytes;
            memcpy(&given, r + 24, 8);
            memcpy(&recBytes, r + 32, 4);
            if (given!=(took ? before : -1)) same = false;
            if (nameAt(r + 40)!=f.name) same = false;           // the record keeps the name as it was found
            if (!took) sawRefusal = true;
            addedRef += took;
            r += recBytes;
        }
        if (added!=addedRef || idNew!=idRef) same = false;
    }

    SQ.finalize(st);
    if (dump(dbNew)!=dump(dbRef)) same = false;
    if (dump(dbNew).size() < 40) same = false;
    SQ.close_v2(dbNew);
    SQ.close_v2(dbRef);
    return same;
}

static void testInsert() {
    printf("  rows into the database\n");
    bindSQLiteOnce();
    if (!SQ.ok)
    {
       printf("    SKIPPED: libsqlite3.so.0 not available\n");
       return;
    }

    // the binder's stand-in speaks 4-byte wchar_t; the records hold real UTF-16, so the
    // genuine entry point takes over, as on Windows
    *(void**)&SQ.bind_text16 = dlsym(SQ.hLib, "sqlite3_bind_text16");
    *(void**)&realLastRowID = dlsym(SQ.hLib, "sqlite3_last_insert_rowid");
    *(void**)&realErrmsg = dlsym(SQ.hLib, "sqlite3_errmsg");
    check(SQ.last_insert_rowid!=NULL && SQ.bind_null!=NULL, "the binder has the entry points this needs");

    const std::vector<unsigned char> table = compile(u16(EXTS));
    std::mt19937 rng(77);
    bool refusals = false, none = false;

    check(insertScenario(NULL, 0, 1, rng, table, none) && !none, "an empty database, factCheck=0: same rows, same row IDs");
    check(insertScenario(NULL, 1, 1, rng, table, none) && !none, "an empty database, factCheck=1: the same");

    // files that are in the database already, marked for a rescan the way coreRegenerateEntireList() marks them
    const char *seeded =
        "INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize, imgwidth) VALUES (5, 2, 'img_2.png', 'c:\\photos\\2019', 9, 640);"
        "INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize) VALUES (6, 2, 'img_1.jpg', 'c:\\photos\\2019', 9);"
        "INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize) VALUES (7, 2, 'img_3.jpg', 'c:\\photos\\2019\\sub', 9);"
        "INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize) VALUES (8, 1, 'gone.jpg', 'c:\\photos\\2019', 9);";
    check(insertScenario(seeded, 0, 9, rng, table, none) && !none, "files already in it, factCheck=0: brought back, an ID used up each");
    check(insertScenario(seeded, 1, 9, rng, table, refusals) && refusals, "files already in it, factCheck=1: brought back, refused, no ID used");

    // a row ID that is taken stops every later row, exactly as it stops the script
    const char *taken = "INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder) VALUES (12, 0, 'other.jpg', 'e:\\elsewhere');";
    refusals = false;
    check(insertScenario(taken, 0, 9, rng, table, refusals) && refusals, "a row ID already taken: refused from there on, in both");

    sqlite3 *db = openDB(NULL);
    INT64 id = 1;
    std::vector<unsigned char> nothing(64, 0);
    sqlite3_stmt *st = NULL;
    SQ.prepare16_v2(db, L"INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize, fmodified, fcreated) VALUES (?1, 0, ?2, ?3, ?4, ?5, ?6);", -1, &st, NULL);
    const U16 folder = u16("c:");
    bool edges = DirScanInsertRows(db, st, nothing.data(), 0, US(folder), &id, 0)==0 && id==1
              && DirScanInsertRows(NULL, st, nothing.data(), 0, US(folder), &id, 0)==-1
              && DirScanInsertRows(db, NULL, nothing.data(), 0, US(folder), &id, 0)==-1
              && DirScanInsertRows(db, st, nothing.data(), 0, NULL, &id, 0)==-1
              && DirScanInsertRows(db, st, nothing.data(), -1, US(folder), &id, 0)==-1;
    SQ.finalize(st);
    SQ.close_v2(db);
    check(edges, "no records is no rows; missing handles are refused");
}

// Reading or writing out of bounds ends here, as a failed test rather than as a crash.
static void onFault(int) {
    static const char msg[] = "    memory was touched outside the buffers handed over                     FAILED\n";
    if (write(1, msg, sizeof(msg) - 1)) {}
    _exit(1);
}

int main() {
    setvbuf(stdout, NULL, _IOLBF, 0);
    signal(SIGSEGV, onFault);
    printf("  dir-scan.h, compiled as shipped\n");
    testExtTable();
    testParse();
    testInsert();
    printf(failures ? "  %d FAILED\n" : "  all passed\n", failures);
    return failures ? 1 : 0;
}
