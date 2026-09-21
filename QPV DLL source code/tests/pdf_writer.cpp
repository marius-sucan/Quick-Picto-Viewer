// The PDF writer of "Join images into a single file", compiled from the SHIPPED
// pdf-writer.h against the POSIX stand-ins of shim/pdf-env.h.
//
// What it pins:
//   - the file: every xref offset lands on its object, every stream is as long as its
//     /Length says, the page tree counts every page, and a page that fails leaves nothing
//     behind, not even the part of it already flushed to disk;
//   - kept JPEGs: the segments a decoder needs are kept, Exif, XMP, comments and colour
//     profiles are not, and the data stops at EOI, so a second image or a video appended to
//     the file stays out; codings PDF readers do not decode are refused;
//   - placement: the eight EXIF orientations turn the stored rows the right way, checked
//     against the expected matrices and, when pdftoppm is installed, by rendering pages;
//   - the destination: replaced only by a complete document, left alone when the document
//     is abandoned, and refused up front when another program holds it open.
//
// The JPEGs are made here by a small baseline and progressive encoder, so the test needs
// no image library.
//
// written by Marius Șucan with Claude Opus 5

#include "shim/pdf-env.h"
#ifndef QPV_PDF_WRITER_SOURCE
#define QPV_PDF_WRITER_SOURCE "../pdf-writer.h"
#endif
#include QPV_PDF_WRITER_SOURCE

#include <cstdlib>
#include <cmath>
#include <map>
#include <sys/stat.h>

typedef std::vector<unsigned char> Bytes;

static int fails = 0;
static std::string dir = "pdf_writer_out";

static void ok(const char *what, bool cond, const std::string &detail = std::string()) {
    printf("    %-68s %s", what, cond ? "ok" : "FAIL");
    if (!cond && !detail.empty())
       printf("   (%s)", detail.c_str());
    printf("\n");
    if (!cond)
       fails++;
}

static std::string path(const char *name) { return dir + "/" + name; }
static std::wstring wide(const std::string &s) { return std::wstring(s.begin(), s.end()); }

static bool exists(const std::string &p) {
    struct stat st;
    return stat(p.c_str(), &st)==0;
}

static std::string readAll(const std::string &p) {
    std::string d;
    FILE *f = fopen(p.c_str(), "rb");
    if (!f)
       return d;
    char b[65536];
    size_t n;
    while ((n = fread(b, 1, sizeof(b), f)) > 0)
        d.append(b, n);
    fclose(f);
    return d;
}

static void writeAll(const std::string &p, const Bytes &d) {
    FILE *f = fopen(p.c_str(), "wb");
    if (f)
    {
       fwrite(d.data(), 1, d.size(), f);
       fclose(f);
    }
}

static void writeAll(const std::string &p, const std::string &d) {
    writeAll(p, Bytes(d.begin(), d.end()));
}

// ---- a small JPEG encoder ---------------------------------------------------------------
// A quantiser of 1 and Huffman tables in which every DC category is a 4-bit code and every
// AC symbol an 8-bit one: nothing compresses well, and every decoder accepts it.

static const int naturalOrder[64] = {
     0,  1,  8, 16,  9,  2,  3, 10, 17, 24, 32, 25, 18, 11,  4,  5,
    12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13,  6,  7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63 };

struct Image {
    int w, h, comps;               // 1 = grey, 3 = RGB
    std::vector<int> px;           // top row first
};

struct BitOut {
    Bytes &o;
    unsigned acc = 0;
    int n = 0;
    explicit BitOut(Bytes &out) : o(out) {}
    void put(unsigned code, int len) {
        for (int i = len - 1; i >= 0; i--)
        {
            acc = (acc << 1) | ((code >> i) & 1);
            if (++n==8)
            {
               o.push_back((unsigned char)acc);
               if (acc==0xFF)
                  o.push_back(0);
               acc = 0;
               n = 0;
            }
        }
    }
    void flush() {
        while (n!=0)
            put(1, 1);
    }
};

static void segment(Bytes &o, int marker, const Bytes &body) {
    const size_t len = body.size() + 2;
    o.push_back(0xFF);
    o.push_back((unsigned char)marker);
    o.push_back((unsigned char)(len >> 8));
    o.push_back((unsigned char)(len & 255));
    o.insert(o.end(), body.begin(), body.end());
}

static std::vector<int> acSymbols() {
    std::vector<int> s = { 0x00, 0xF0 };
    for (int run = 0; run < 16; run++)
        for (int size = 1; size <= 10; size++)
            s.push_back((run << 4) | size);
    return s;
}

static int category(int v) {
    v = std::abs(v);
    int c = 0;
    while (v) { c++; v >>= 1; }
    return c;
}

static void putValue(BitOut &b, int v, int c) {
    if (c>0)
       b.put((unsigned)((v >= 0) ? v : v + (1 << c) - 1), c);
}

// the coefficients of one block of one component, in zigzag order
static void block(const Image &im, int comp, int bx, int by, int out[64]) {
    double f[64], coef[64];
    for (int y = 0; y < 8; y++)
        for (int x = 0; x < 8; x++)
        {
            const int sx = std::min(bx * 8 + x, im.w - 1), sy = std::min(by * 8 + y, im.h - 1);
            const int *p = &im.px[((size_t)sy * im.w + sx) * im.comps];
            double v;
            if (im.comps==1)
               v = p[0];
            else if (comp==0)
               v = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2];
            else if (comp==1)
               v = 128 - 0.168736 * p[0] - 0.331264 * p[1] + 0.5 * p[2];
            else
               v = 128 + 0.5 * p[0] - 0.418688 * p[1] - 0.081312 * p[2];
            f[y * 8 + x] = v - 128;
        }

    for (int v = 0; v < 8; v++)
        for (int u = 0; u < 8; u++)
        {
            double s = 0;
            for (int y = 0; y < 8; y++)
                for (int x = 0; x < 8; x++)
                    s += f[y * 8 + x] * cos((2 * x + 1) * u * M_PI / 16) * cos((2 * y + 1) * v * M_PI / 16);
            coef[v * 8 + u] = 0.25 * (u ? 1 : M_SQRT1_2) * (v ? 1 : M_SQRT1_2) * s;
        }

    for (int k = 0; k < 64; k++)
        out[k] = (int)lround(coef[naturalOrder[k]]);
}

static void encodeAC(BitOut &b, const int *z, const std::map<int, int> &code) {
    int run = 0;
    for (int k = 1; k < 64; k++)
    {
        if (z[k]==0)
        {
           run++;
           continue;
        }
        while (run > 15)
        {
            b.put(code.at(0xF0), 8);
            run -= 16;
        }
        const int c = category(z[k]);
        b.put(code.at((run << 4) | c), 8);
        putValue(b, z[k], c);
        run = 0;
    }
    if (run > 0)
       b.put(code.at(0x00), 8);   // EOB
}

static Bytes makeJpeg(const Image &im, bool progressive, int restartInterval = 0) {
    Bytes o = { 0xFF, 0xD8 };
    segment(o, 0xE0, { 'J', 'F', 'I', 'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0 });
    Bytes dqt = { 0x00 };
    dqt.insert(dqt.end(), 64, 1);
    segment(o, 0xDB, dqt);

    Bytes sof = { 8, (unsigned char)(im.h >> 8), (unsigned char)(im.h & 255), (unsigned char)(im.w >> 8), (unsigned char)(im.w & 255), (unsigned char)im.comps };
    for (int c = 0; c < im.comps; c++)
    {
        sof.push_back((unsigned char)(c + 1));
        sof.push_back(0x11);
        sof.push_back(0);
    }
    segment(o, progressive ? 0xC2 : 0xC0, sof);

    const std::vector<int> ac = acSymbols();
    std::map<int, int> acCode;
    for (size_t i = 0; i < ac.size(); i++)
        acCode[ac[i]] = (int)i;

    Bytes dht = { 0x00 };
    for (int len = 1; len <= 16; len++)
        dht.push_back(len==4 ? 12 : 0);
    for (int v = 0; v < 12; v++)
        dht.push_back((unsigned char)v);
    dht.push_back(0x10);
    for (int len = 1; len <= 16; len++)
        dht.push_back(len==8 ? (unsigned char)ac.size() : 0);
    for (int v : ac)
        dht.push_back((unsigned char)v);
    segment(o, 0xC4, dht);

    if (restartInterval>0)
       segment(o, 0xDD, { (unsigned char)(restartInterval >> 8), (unsigned char)(restartInterval & 255) });

    const int bw = (im.w + 7) / 8, bh = (im.h + 7) / 8;
    std::vector<std::vector<int>> coef((size_t)im.comps * bw * bh, std::vector<int>(64));
    for (int c = 0; c < im.comps; c++)
        for (int by = 0; by < bh; by++)
            for (int bx = 0; bx < bw; bx++)
                block(im, c, bx, by, coef[((size_t)c * bh + by) * bw + bx].data());

    auto z = [&](int c, int bx, int by) -> const int* { return coef[((size_t)c * bh + by) * bw + bx].data(); };
    Bytes sos = { (unsigned char)im.comps };
    for (int c = 0; c < im.comps; c++)
    {
        sos.push_back((unsigned char)(c + 1));
        sos.push_back(0x00);
    }

    if (!progressive)
    {
       sos.insert(sos.end(), { 0, 63, 0 });
       segment(o, 0xDA, sos);
       BitOut b(o);
       int pred[3] = { 0, 0, 0 }, mcu = 0, rst = 0;
       for (int by = 0; by < bh; by++)
           for (int bx = 0; bx < bw; bx++, mcu++)
           {
               if (restartInterval>0 && mcu>0 && mcu % restartInterval==0)
               {
                  b.flush();
                  o.push_back(0xFF);
                  o.push_back((unsigned char)(0xD0 + (rst++ & 7)));
                  pred[0] = pred[1] = pred[2] = 0;
               }
               for (int c = 0; c < im.comps; c++)
               {
                   const int *q = z(c, bx, by), diff = q[0] - pred[c];
                   pred[c] = q[0];
                   b.put((unsigned)category(diff), 4);
                   putValue(b, diff, category(diff));
                   encodeAC(b, q, acCode);
               }
           }
       b.flush();
    } else
    {
       // spectral selection only: one DC scan, then all the AC coefficients per component
       sos.insert(sos.end(), { 0, 0, 0 });
       segment(o, 0xDA, sos);
       BitOut b(o);
       int pred[3] = { 0, 0, 0 };
       for (int by = 0; by < bh; by++)
           for (int bx = 0; bx < bw; bx++)
               for (int c = 0; c < im.comps; c++)
               {
                   const int diff = z(c, bx, by)[0] - pred[c];
                   pred[c] = z(c, bx, by)[0];
                   b.put((unsigned)category(diff), 4);
                   putValue(b, diff, category(diff));
               }
       b.flush();

       for (int c = 0; c < im.comps; c++)
       {
           segment(o, 0xDA, { 1, (unsigned char)(c + 1), 0x00, 1, 63, 0 });
           BitOut ba(o);
           for (int by = 0; by < bh; by++)
               for (int bx = 0; bx < bw; bx++)
                   encodeAC(ba, z(c, bx, by), acCode);
           ba.flush();
       }
    }

    o.push_back(0xFF);
    o.push_back(0xD9);
    return o;
}

// 64 x 32: red, green over blue, white; 8x8 blocks, so every block is one colour
static const int Q_RED[3] = { 255, 0, 0 }, Q_GREEN[3] = { 0, 255, 0 }, Q_BLUE[3] = { 0, 0, 255 }, Q_WHITE[3] = { 255, 255, 255 };

static Image quadrants(bool grey) {
    Image im;
    im.w = 64;
    im.h = 32;
    im.comps = grey ? 1 : 3;
    for (int y = 0; y < im.h; y++)
        for (int x = 0; x < im.w; x++)
        {
            const int *c = (y < 16) ? ((x < 32) ? Q_RED : Q_GREEN) : ((x < 32) ? Q_BLUE : Q_WHITE);
            if (grey)
               im.px.push_back((c[0] + c[1] * 2 + c[2]) / 4);
            else
               im.px.insert(im.px.end(), c, c + 3);
        }
    return im;
}

// ---- JPEG surgery ------------------------------------------------------------------------

static Bytes insertAfterApp0(const Bytes &jpeg, const Bytes &segments) {
    const size_t app0End = 4 + ((jpeg[4] << 8) | jpeg[5]);
    Bytes o(jpeg.begin(), jpeg.begin() + app0End);
    o.insert(o.end(), segments.begin(), segments.end());
    o.insert(o.end(), jpeg.begin() + app0End, jpeg.end());
    return o;
}

static Bytes exifSegment(int orientation, bool bigEndian) {
    Bytes t = bigEndian ? Bytes{ 'M', 'M', 0, 42, 0, 0, 0, 8 } : Bytes{ 'I', 'I', 42, 0, 8, 0, 0, 0 };
    auto u16 = [&](int v) { if (bigEndian) { t.push_back((unsigned char)(v >> 8)); t.push_back((unsigned char)v); } else { t.push_back((unsigned char)v); t.push_back((unsigned char)(v >> 8)); } };
    auto u32 = [&](unsigned v) { if (bigEndian) { u16(v >> 16); u16(v & 0xFFFF); } else { u16(v & 0xFFFF); u16(v >> 16); } };
    u16(2);                                   // two entries: an unrelated tag first
    u16(0x010F); u16(2); u32(4); t.insert(t.end(), { 'Q', 'P', 'V', 0 });
    u16(0x0112); u16(3); u32(1); u16(orientation); u16(0);
    u32(0);
    // a thumbnail inside the segment, with its own EOI, which must not end anything
    t.insert(t.end(), { 0xFF, 0xD8, 0xFF, 0xD9, 0xFF, 0xD9 });
    Bytes body = { 'E', 'x', 'i', 'f', 0, 0 };
    body.insert(body.end(), t.begin(), t.end());
    Bytes o;
    segment(o, 0xE1, body);
    return o;
}

static Bytes fakeIccProfile(unsigned char salt, bool grey = false) {
    Bytes p(200, salt);
    const unsigned size = (unsigned)p.size();
    p[0] = (unsigned char)(size >> 24); p[1] = (unsigned char)(size >> 16); p[2] = (unsigned char)(size >> 8); p[3] = (unsigned char)size;
    memcpy(&p[12], "mntr", 4);
    memcpy(&p[16], grey ? "GRAY" : "RGB ", 4);
    return p;
}

static Bytes iccSegments(const Bytes &profile, int chunks) {
    Bytes o;
    const size_t per = (profile.size() + chunks - 1) / chunks;
    for (int i = 0; i < chunks; i++)
    {
        Bytes body = { 'I', 'C', 'C', '_', 'P', 'R', 'O', 'F', 'I', 'L', 'E', 0, (unsigned char)(i + 1), (unsigned char)chunks };
        const size_t from = i * per, to = std::min(profile.size(), from + per);
        body.insert(body.end(), profile.begin() + from, profile.begin() + to);
        segment(o, 0xE2, body);
    }
    return o;
}

static size_t findMarker(const Bytes &j, int marker) {
    for (size_t i = 2; i + 1 < j.size(); i++)
        if (j[i]==0xFF && j[i + 1]==marker)
           return i;
    return std::string::npos;
}

// ---- reading the PDF back ----------------------------------------------------------------

struct Pdf {
    std::string d;
    std::map<int, size_t> at;       // object number -> offset, from the xref table
    int size = 0;
    std::string problem;
};

static long long numberAfter(const std::string &s, const std::string &key, size_t from = 0) {
    const size_t k = s.find(key, from);
    if (k==std::string::npos)
       return -1;
    return atoll(s.c_str() + k + key.size());
}

static bool parsePdf(const std::string &d, Pdf &p) {
    p.d = d;
    const size_t sx = d.rfind("startxref\n");
    if (sx==std::string::npos) { p.problem = "no startxref"; return false; }
    const size_t xref = (size_t)atoll(d.c_str() + sx + 10);
    if (xref>=d.size() || d.compare(xref, 7, "xref\n0 ")!=0) { p.problem = "startxref misses the table"; return false; }

    p.size = atoi(d.c_str() + xref + 7);
    const size_t entries = d.find('\n', xref + 7) + 1;
    if (d.compare(entries, 20, "0000000000 65535 f\r\n")!=0) { p.problem = "bad free entry"; return false; }
    for (int i = 1; i < p.size; i++)
    {
        const std::string e = d.substr(entries + (size_t)i * 20, 20);
        if (e.size()!=20 || e.compare(10, 10, " 00000 n\r\n")!=0) { p.problem = "bad entry " + std::to_string(i); return false; }
        const size_t off = (size_t)atoll(e.c_str());
        const std::string want = std::to_string(i) + " 0 obj\n";
        if (off>=d.size() || d.compare(off, want.size(), want)!=0) { p.problem = "entry " + std::to_string(i) + " misses its object"; return false; }
        p.at[i] = off;
    }

    const size_t trailer = entries + (size_t)p.size * 20;
    if (d.compare(trailer, 8, "trailer\n")!=0) { p.problem = "no trailer after the table"; return false; }
    if (numberAfter(d, "/Size ", trailer)!=p.size) { p.problem = "trailer /Size"; return false; }
    if (d.find("/Root 2 0 R", trailer)==std::string::npos) { p.problem = "trailer /Root"; return false; }
    return true;
}

static std::string object(const Pdf &p, int n) {
    auto it = p.at.find(n);
    if (it==p.at.end())
       return std::string();
    const size_t end = p.d.find("endobj", it->second);
    return p.d.substr(it->second, end - it->second);
}

// The data of a stream object, when its length agrees with /Length.
static bool streamOf(const Pdf &p, int n, std::string &data) {
    const std::string o = object(p, n);
    const size_t s = o.find(">>\nstream\n");
    if (s==std::string::npos)
       return false;

    const std::string dict = o.substr(0, s);
    long long len = -1;
    const size_t k = dict.find("/Length ");
    if (k!=std::string::npos)
    {
       const std::string rest = dict.substr(k + 8);
       const long long v = atoll(rest.c_str());
       if (rest.find(" 0 R")!=std::string::npos && rest.find(" 0 R") < rest.find_first_of("/>"))
          len = numberAfter(object(p, (int)v), " 0 obj\n");
       else
          len = v;
    }

    const size_t start = p.at.at(n) + s + 10;
    if (len<0 || start + len + 10 > p.d.size() || p.d.compare(start + len, 10, "\nendstream")!=0)
       return false;
    data = p.d.substr(start, (size_t)len);
    return true;
}

static std::vector<int> refsIn(const std::string &s) {
    std::vector<int> r;
    size_t i = 0;
    while ((i = s.find(" 0 R", i))!=std::string::npos)
    {
        size_t b = i;
        while (b>0 && isdigit((unsigned char)s[b - 1]))
            b--;
        r.push_back(atoi(s.c_str() + b));
        i += 4;
    }
    return r;
}

struct PageInfo {
    std::string contents, image, imageDict;
};

// Walks the page tree and every stream it reaches; returns the pages, or fewer on a fault.
static std::vector<PageInfo> checkDocument(const std::string &file, Pdf &p, std::string &problem) {
    std::vector<PageInfo> pages;
    const std::string d = readAll(file);
    if (d.compare(0, 9, "%PDF-1.7\n")!=0) { problem = "header"; return pages; }
    if (!parsePdf(d, p)) { problem = p.problem; return pages; }

    const std::string tree = object(p, 1);
    const size_t kids = tree.find("/Kids[");
    if (kids==std::string::npos) { problem = "no /Kids"; return pages; }
    const std::vector<int> kidRefs = refsIn(tree.substr(kids));
    if (tree.find("/Type/Pages")==std::string::npos || numberAfter(tree, "/Count ")!=(long long)kidRefs.size()) { problem = "page tree"; return pages; }
    if (object(p, 2).find("<</Type/Catalog/Pages 1 0 R>>")==std::string::npos) { problem = "catalog"; return pages; }

    for (int k : kidRefs)
    {
        const std::string page = object(p, k);
        if (page.find("/Type/Page/Parent 1 0 R/MediaBox[0 0 ")==std::string::npos) { problem = "page " + std::to_string(k); return pages; }
        PageInfo info;
        const int contents = (int)numberAfter(page, "/Contents ");
        const int image = (int)numberAfter(page, "/Im0 ");
        if (!streamOf(p, contents, info.contents) || !streamOf(p, image, info.image)) { problem = "a stream of page " + std::to_string(k); return pages; }
        info.imageDict = object(p, image).substr(0, object(p, image).find("stream\n"));
        pages.push_back(info);
    }
    return pages;
}

// ---- rendering, when pdftoppm is there ---------------------------------------------------

static bool haveRenderer() {
    return system("command -v pdftoppm > /dev/null 2>&1")==0;
}

struct Raster {
    int w = 0, h = 0;
    std::vector<unsigned char> rgb;
    const unsigned char* at(int x, int y) const { return &rgb[((size_t)y * w + x) * 3]; }
};

static bool renderPage(const std::string &file, int page, Raster &r) {
    const std::string cmd = "pdftoppm -r 72 -f " + std::to_string(page) + " -l " + std::to_string(page) + " '" + file + "'";
    FILE *f = popen(cmd.c_str(), "r");
    if (!f)
       return false;
    int maxv = 0;
    const bool header = fscanf(f, "P6 %d %d %d", &r.w, &r.h, &maxv)==3;
    fgetc(f);
    if (header)
    {
       r.rgb.resize((size_t)r.w * r.h * 3);
       if (fread(r.rgb.data(), 1, r.rgb.size(), f)!=r.rgb.size())
          r.w = 0;
    }
    pclose(f);
    return header && r.w>0;
}

static char colourName(const unsigned char *c) {
    const int *ref[4] = { Q_RED, Q_GREEN, Q_BLUE, Q_WHITE };
    const char names[4] = { 'R', 'G', 'B', 'W' };
    int best = 0, bestDist = 1 << 30;
    for (int i = 0; i < 4; i++)
    {
        const int d = abs(c[0] - ref[i][0]) + abs(c[1] - ref[i][1]) + abs(c[2] - ref[i][2]);
        if (d < bestDist) { bestDist = d; best = i; }
    }
    return (bestDist < 90) ? names[best] : '?';
}

// top left, top right, bottom left, bottom right
static std::string corners(const Raster &r, int x0, int y0, int w, int h) {
    std::string s;
    s += colourName(r.at(x0 + w / 4, y0 + h / 4));
    s += colourName(r.at(x0 + 3 * w / 4, y0 + h / 4));
    s += colourName(r.at(x0 + w / 4, y0 + 3 * h / 4));
    s += colourName(r.at(x0 + 3 * w / 4, y0 + 3 * h / 4));
    return s;
}

// ---- the tests ---------------------------------------------------------------------------

static void testFormatting() {
    printf("  numbers and text strings are written the way PDF reads them\n");
    char b[40];
    auto num = [&](double v) { return std::string(b, pdfwFormatNum(b, v)); };
    ok("595.28 stays 595.28", num(595.28)=="595.28", num(595.28));
    ok("0.05 keeps its leading zero", num(0.05)=="0.05", num(0.05));
    ok("an integer has no decimal point", num(612)=="612", num(612));
    ok("a tiny negative rounds to a plain 0", num(-0.00001)=="0", num(-0.00001));
    ok("negatives keep their sign", num(-32.5)=="-32.5", num(-32.5));
    ok("NaN is written as 0", num(NAN)=="0", num(NAN));

    PdfWriter w;
    pdfwText(&w, L"Plain (text) \\ here");
    ok("ASCII becomes an escaped literal string", std::string(w.out.begin(), w.out.end())=="(Plain \\(text\\) \\\\ here)");
    w.out.clear();
    pdfwText(&w, L"\x0218\x0103n");
    ok("anything else becomes UTF-16BE with a byte order mark", std::string(w.out.begin(), w.out.end())=="<FEFF02180103006E>", std::string(w.out.begin(), w.out.end()));
    w.out.clear();
    pdfwText(&w, L"\U0001F600");
    ok("a character past the BMP becomes a surrogate pair", std::string(w.out.begin(), w.out.end())=="<FEFFD83DDE00>", std::string(w.out.begin(), w.out.end()));
    w.magic = 0;

    BYTE px[16] = { 10, 20, 30, 255,   0, 0, 0, 0,   64, 64, 64, 128,   0, 0, 0, 0 };
    BYTE rgb[12];
    pdfwOverColor(px, 16, 3, 1, 0xFFFFFF, rgb, 12);
    ok("an opaque pixel is not touched by the background", rgb[0]==10 && rgb[1]==20 && rgb[2]==30);
    ok("a transparent one is the background", rgb[3]==255 && rgb[4]==255 && rgb[5]==255);
    ok("half transparency mixes premultiplied colour with it", rgb[6]==191 && rgb[7]==191 && rgb[8]==191, std::to_string(rgb[6]));
    pdfwOverColor(px, 16, 2, 1, 0x102030, rgb, 12);
    ok("the background is read as 0xRRGGBB into BGR bytes", rgb[3]==0x30 && rgb[4]==0x20 && rgb[5]==0x10);
}

static UINT infoOf(const Bytes &jpeg, const char *name, UINT *info) {
    writeAll(path(name), jpeg);
    return (UINT)PdfJpegFileInfo(wide(path(name)).c_str(), info);
}

static void testJpegHeaders(const Bytes &rgb, const Bytes &grey, const Bytes &prog) {
    printf("  which JPEG files are embedded as they are\n");
    UINT info[5];
    ok("a baseline colour JPEG is", infoOf(rgb, "h_rgb.jpg", info)==1 && info[0]==64 && info[1]==32 && info[2]==3 && info[3]==1 && info[4]==0);
    ok("a greyscale one is", infoOf(grey, "h_grey.jpg", info)==1 && info[2]==1);
    ok("a progressive one is", infoOf(prog, "h_prog.jpg", info)==1 && info[0]==64 && info[2]==3);
    ok("the EXIF orientation is read, little endian", infoOf(insertAfterApp0(rgb, exifSegment(6, false)), "h_ex6.jpg", info)==1 && info[3]==6);
    ok("... and big endian", infoOf(insertAfterApp0(rgb, exifSegment(8, true)), "h_ex8.jpg", info)==1 && info[3]==8);
    ok("an orientation out of range reads as 1", infoOf(insertAfterApp0(rgb, exifSegment(9, false)), "h_ex9.jpg", info)==1 && info[3]==1);

    Bytes b = rgb;
    b[findMarker(b, 0xC0) + 1] = 0xC9;
    ok("arithmetic coding is refused", infoOf(b, "h_arith.jpg", info)==0 && info[4]==PDFW_JPEG_CODING);
    b = rgb;
    b[findMarker(b, 0xC0) + 4] = 12;
    ok("12 bits per sample are refused", infoOf(b, "h_12bit.jpg", info)==0 && info[4]==PDFW_JPEG_CODING);
    b = rgb;
    b[findMarker(b, 0xC0) + 1] = 0xC3;
    ok("lossless coding is refused", infoOf(b, "h_lossless.jpg", info)==0 && info[4]==PDFW_JPEG_CODING);
    b = insertAfterApp0(rgb, { 0xFF, 0xCC, 0x00, 0x04, 0x00, 0x10 });
    ok("a DAC segment is refused", infoOf(b, "h_dac.jpg", info)==0 && info[4]==PDFW_JPEG_CODING);

    b = rgb;
    const size_t sof = findMarker(b, 0xC0);
    b[sof + 10] = 'R'; b[sof + 13] = 'G'; b[sof + 16] = 'B';
    ok("RGB that only the component IDs tell apart is refused", infoOf(b, "h_rgbids.jpg", info)==0 && info[4]==PDFW_JPEG_COLOURS);
    Bytes adobe;
    segment(adobe, 0xEE, { 'A', 'd', 'o', 'b', 'e', 0, 100, 0, 0, 0, 0, 0 });
    ok("... unless an Adobe segment says so", infoOf(insertAfterApp0(b, adobe), "h_rgbadobe.jpg", info)==1);

    Bytes cmyk = { 0xFF, 0xD8 };
    segment(cmyk, 0xC0, { 8, 0, 8, 0, 8, 4, 1, 0x11, 0, 2, 0x11, 0, 3, 0x11, 0, 4, 0x11, 0 });
    segment(cmyk, 0xDA, { 1, 1, 0, 0, 63, 0 });
    cmyk.insert(cmyk.end(), { 0x00, 0xFF, 0xD9 });
    ok("four components are refused", infoOf(cmyk, "h_cmyk.jpg", info)==0 && info[4]==PDFW_JPEG_COLOURS);

    ok("a file that is not a JPEG is refused", infoOf({ 0x89, 'P', 'N', 'G', 13, 10, 26, 10 }, "h_png.jpg", info)==0 && info[4]==PDFW_JPEG_NOT_JPEG);
    ok("a header cut short is damaged", infoOf(Bytes(rgb.begin(), rgb.begin() + 60), "h_cut.jpg", info)==0 && info[4]==PDFW_JPEG_DAMAGED);
    b = insertAfterApp0(rgb, { 0x12, 0x34 });
    ok("stray bytes between segments are damage", infoOf(b, "h_stray.jpg", info)==0 && info[4]==PDFW_JPEG_DAMAGED);
    ok("a missing file is unreadable", PdfJpegFileInfo(wide(path("does_not_exist.jpg")).c_str(), info)==0 && info[4]==PDFW_JPEG_UNREADABLE);
}

static PdfWriter* begin(const std::string &dest) {
    int error = -1;
    PdfWriter *w = PdfWriterBegin(wide(dest).c_str(), &error);
    if (w==NULL)
       printf("    (PdfWriterBegin failed with %d)\n", error);
    return w;
}

static int addFile(PdfWriter *w, const Bytes &jpeg, const char *name, double pw, double ph, double x, double y, double iw, double ih, int useOrientation = 0, UINT bg = 0xFFFFFF) {
    writeAll(path(name), jpeg);
    return PdfWriterAddJpegFile(w, wide(path(name)).c_str(), useOrientation, pw, ph, x, y, iw, ih, bg);
}

static void testDocument(const Bytes &rgb, const Bytes &grey, const Bytes &prog, const Bytes &restarts) {
    printf("  a document with every kind of page\n");
    const std::string dest = path("document.pdf");
    PdfWriter *w = begin(dest);
    if (!w) { ok("PdfWriterBegin", false); return; }
    ok("the document is written next to the destination", exists(dest + ".part") && !exists(dest));

    // everything that should be dropped, in front of a clean JPEG, and a video after it
    Bytes com, xmp, ps;
    segment(com, 0xFE, { 'c', 'o', 'm', 'm', 'e', 'n', 't' });
    const char *ns = "http://ns.adobe.com/xap/1.0/";
    segment(xmp, 0xE1, Bytes(ns, ns + strlen(ns) + 1));
    segment(ps, 0xED, { 'P', 'h', 'o', 't', 'o', 's', 'h', 'o', 'p', ' ', '3', '.', '0', 0 });
    const Bytes profileA = fakeIccProfile(0x11), profileB = fakeIccProfile(0x22);
    Bytes junk = exifSegment(6, false);
    junk.insert(junk.end(), xmp.begin(), xmp.end());
    junk.insert(junk.end(), com.begin(), com.end());
    junk.insert(junk.end(), ps.begin(), ps.end());
    Bytes dressed = insertAfterApp0(rgb, junk);
    const Bytes withIccA = insertAfterApp0(dressed, iccSegments(profileA, 3));
    Bytes withVideo = withIccA;
    static const char mp4[] = "\x00\x00\x00\x18" "ftypmp42 and a whole video after EOI \xFF\xD9\xFF\xD8";
    withVideo.insert(withVideo.end(), mp4, mp4 + sizeof(mp4) - 1);

    ok("a baseline JPEG, centred on an A4 page", addFile(w, rgb, "d_rgb.jpg", 595.28, 841.89, 137.64, 344.945, 320, 160)==PDFW_ADDED);
    ok("a progressive one", addFile(w, prog, "d_prog.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("a greyscale one", addFile(w, grey, "d_grey.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("one with restart markers", addFile(w, restarts, "d_rst.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("one with Exif, XMP, a comment, a profile and a video", addFile(w, withVideo, "d_video.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("the same profile again", addFile(w, withIccA, "d_iccA.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("another profile", addFile(w, insertAfterApp0(rgb, iccSegments(profileB, 1)), "d_iccB.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    const PdfwPlace place = { 64, 32, 0, 0, 64, 32, 0xFFFFFF, 1 };
    ok("JPEG data from memory, the way GDI+ hands it over", pdfwAddJpegData(w, rgb.data(), rgb.size(), place)==PDFW_ADDED);
    ok("the destination still does not exist", !exists(dest));
    ok("the document is finished", PdfWriterEnd(w, 1, L"Titlu \x0218\x0103n", L"Quick Picto Viewer v6.3.00", L"D:20260921120000")==0);
    ok("it replaced the destination, and the partial file is gone", exists(dest) && !exists(dest + ".part"));

    Pdf p;
    std::string problem;
    const std::vector<PageInfo> pages = checkDocument(dest, p, problem);
    ok("the xref table, the streams and the page tree all hold", pages.size()==8, problem);
    if (pages.size()!=8)
       return;

    const std::string rgbS(rgb.begin(), rgb.end());
    ok("a kept JPEG is embedded byte for byte", pages[0].image==rgbS);
    ok("... and so are the progressive, greyscale and restart ones", pages[1].image==std::string(prog.begin(), prog.end()) && pages[2].image==std::string(grey.begin(), grey.end()) && pages[3].image==std::string(restarts.begin(), restarts.end()));
    ok("the dropped segments and the video leave the original JPEG", pages[4].image==rgbS);
    ok("the colour space follows the components", pages[0].imageDict.find("/ColorSpace/DeviceRGB")!=std::string::npos && pages[2].imageDict.find("/ColorSpace/DeviceGray")!=std::string::npos);
    ok("the image size comes from the frame header", pages[0].imageDict.find("/Width 64/Height 32/BitsPerComponent 8")!=std::string::npos);

    auto iccRefs = [](const std::string &dict) {
        const size_t k = dict.find("/ICCBased");
        return (k==std::string::npos) ? std::vector<int>() : refsIn(dict.substr(k));
    };
    const std::vector<int> icc4 = iccRefs(pages[4].imageDict), icc5 = iccRefs(pages[5].imageDict), icc6 = iccRefs(pages[6].imageDict);
    ok("a colour profile becomes an ICCBased colour space", !icc4.empty() && object(p, icc4[0]).find("<</N 3/Alternate/DeviceRGB/Length 200>>")!=std::string::npos);
    std::string iccData;
    ok("... holding the profile the chunks add up to", !icc4.empty() && streamOf(p, icc4[0], iccData) && iccData==std::string(profileA.begin(), profileA.end()));
    ok("the same profile is written once and shared", !icc4.empty() && !icc5.empty() && icc4[0]==icc5[0]);
    ok("a different one gets its own object", !icc6.empty() && icc6[0]!=icc4[0]);

    ok("an image that leaves part of the page uncovered gets the background", pages[0].contents.find("1 1 1 rg\n0 0 595.28 841.89 re\nf\n")!=std::string::npos);
    ok("... and is placed where it was asked", pages[0].contents.find("320 0 0 160 137.64 344.945 cm")!=std::string::npos, pages[0].contents);
    ok("an image that covers the page does not", pages[1].contents.find(" rg")==std::string::npos);
    ok("the title is UTF-16BE, the rest plain", object(p, 3).find("/Title<FEFF005400690074006C0075002002180103006E>")!=std::string::npos, object(p, 3));
    ok("... with the producer and the date", object(p, 3).find("/Producer(Quick Picto Viewer v6.3.00)/CreationDate(D:20260921120000)")!=std::string::npos);
}

// the matrix PDF readers need for each EXIF orientation of the 64 x 32 test image
static void testOrientations(const Bytes &rgb, bool render) {
    printf("  the EXIF orientations turn the stored rows the right way\n");
    static const char *matrices[9] = { "",
        "64 0 0 32 0 0 cm",   "-64 0 0 32 64 0 cm", "-64 0 0 -32 64 32 cm", "64 0 0 -32 0 32 cm",
        "0 -64 -32 0 32 64 cm", "0 -64 32 0 0 64 cm", "0 64 32 0 0 0 cm",    "0 64 -32 0 32 0 cm" };
    // the quadrants once turned: top left, top right, bottom left, bottom right
    static const char *seen[9] = { "", "RGBW", "GRWB", "WBGR", "BWRG", "RBGW", "BRWG", "WGBR", "GWRB" };
    const std::string dest = path("orientations.pdf");
    PdfWriter *w = begin(dest);
    if (!w) { ok("PdfWriterBegin", false); return; }
    for (int o = 1; o <= 8; o++)
    {
        const bool turned = (o > 4);
        const double pw = turned ? 32 : 64, ph = turned ? 64 : 32;
        const std::string name = "o" + std::to_string(o) + ".jpg";
        if (addFile(w, insertAfterApp0(rgb, exifSegment(o, o % 2==0)), name.c_str(), pw, ph, 0, 0, pw, ph, 1)!=PDFW_ADDED)
           ok(("orientation " + std::to_string(o) + " was added").c_str(), false);
    }
    addFile(w, insertAfterApp0(rgb, exifSegment(6, false)), "o6_ignored.jpg", 64, 32, 0, 0, 64, 32, 0);
    PdfWriterEnd(w, 1, NULL, NULL, NULL);

    Pdf p;
    std::string problem;
    const std::vector<PageInfo> pages = checkDocument(dest, p, problem);
    ok("nine pages", pages.size()==9, problem);
    if (pages.size()!=9)
       return;

    for (int o = 1; o <= 8; o++)
    {
        const std::string what = "orientation " + std::to_string(o) + " is drawn with " + matrices[o];
        ok(what.c_str(), pages[o - 1].contents.find(matrices[o])!=std::string::npos, pages[o - 1].contents);
    }
    ok("with useOrientation=0 the stored rows are drawn as they are", pages[8].contents.find(matrices[1])!=std::string::npos);

    if (!render)
       return;

    for (int o = 1; o <= 8; o++)
    {
        Raster r;
        const bool rendered = renderPage(dest, o, r);
        const std::string got = rendered ? corners(r, 0, 0, r.w, r.h) : "no render";
        const std::string what = "rendered, orientation " + std::to_string(o) + " shows " + seen[o];
        ok(what.c_str(), got==seen[o], got);
    }
}

static void testRendering(bool render) {
    if (!render)
    {
       printf("  (pdftoppm is not installed: the pages are not rendered)\n");
       return;
    }

    printf("  PDF readers decode the kept JPEGs\n");
    const std::string dest = path("document.pdf");
    const char *what[4] = { "the baseline JPEG, centred on its A4 page", "the progressive one", "the greyscale one", "the one with restart markers" };
    for (int page = 1; page <= 4; page++)
    {
        Raster r;
        std::string got = "no render";
        if (renderPage(dest, page, r))
        {
           if (page==1)
              got = corners(r, (int)lround(137.64), (int)lround(841.89 - 344.945 - 160), 320, 160) + (colourName(r.at(5, 5))=='W' ? "" : " no white margin");
           else if (page==3)   // grey levels 63 [red] and 255 [white]
              got = (abs(r.at(16, 8)[0] - 63) < 8 && abs(r.at(48, 24)[0] - 255) < 8) ? "RGBW" : std::to_string(r.at(16, 8)[0]) + " " + std::to_string(r.at(48, 24)[0]);
           else
              got = corners(r, 0, 0, r.w, r.h);
        }
        ok(what[page - 1], got=="RGBW", got);
    }
}

static void testRollback(const Bytes &rgb) {
    printf("  a page that fails leaves nothing behind\n");
    const std::string dest = path("rollback.pdf");
    PdfWriter *w = begin(dest);
    if (!w) { ok("PdfWriterBegin", false); return; }

    Bytes truncated(rgb.begin(), rgb.end() - 2);
    // a scan larger than the output buffer, without EOI: some of it is on disk when it fails
    Bytes huge(rgb.begin(), rgb.begin() + findMarker(rgb, 0xDA));
    segment(huge, 0xDA, { 3, 1, 0x00, 2, 0x00, 3, 0x00, 0, 63, 0 });
    huge.insert(huge.end(), (size_t)3 << 20, 0x55);
    Bytes hugeDone = huge;
    hugeDone.insert(hugeDone.end(), { 0xFF, 0xD9 });

    ok("a good page", addFile(w, rgb, "r_1.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("a JPEG without EOI is skipped", addFile(w, truncated, "r_trunc.jpg", 64, 32, 0, 0, 64, 32)==PDFW_SKIPPED);
    ok("a 3 MB one without EOI too, after part of it reached the disk", addFile(w, huge, "r_huge.jpg", 64, 32, 0, 0, 64, 32)==PDFW_SKIPPED);
    Bytes bad = rgb;
    bad.insert(bad.end() - 2, { 0xFF, 0xC1, 0x00, 0x02 });
    ok("a frame header between the scans is refused", addFile(w, bad, "r_sof.jpg", 64, 32, 0, 0, 64, 32)==PDFW_SKIPPED);
    ok("an impossible placement is refused", addFile(w, rgb, "r_nan.jpg", 64, 32, 0, 0, NAN, 32)==PDFW_SKIPPED);
    ok("a missing file is skipped", PdfWriterAddJpegFile(w, L"pdf_writer_out/none.jpg", 0, 64, 32, 0, 0, 64, 32, 0)==PDFW_SKIPPED);
    ok("another good page", addFile(w, rgb, "r_2.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    ok("the document is finished", PdfWriterEnd(w, 1, NULL, NULL, NULL)==0);

    Pdf p;
    std::string problem;
    const std::vector<PageInfo> pages = checkDocument(dest, p, problem);
    ok("two pages, and the xref still resolves every object", pages.size()==2, problem);
    ok("nothing of the 3 MB page is left in the file", readAll(dest).size() < 20000, std::to_string(readAll(dest).size()));

    const std::string dest2 = path("huge.pdf");
    w = begin(dest2);
    if (!w) { ok("PdfWriterBegin", false); return; }
    ok("the 3 MB JPEG with its EOI is embedded", addFile(w, hugeDone, "r_hugedone.jpg", 64, 32, 0, 0, 64, 32)==PDFW_ADDED);
    PdfWriterEnd(w, 1, NULL, NULL, NULL);
    const std::vector<PageInfo> big = checkDocument(dest2, p, problem);
    ok("... whole", big.size()==1 && big[0].image==std::string(hugeDone.begin(), hugeDone.end()), problem);
}

static void testDestination(const Bytes &rgb) {
    printf("  the destination is replaced only by a finished document\n");
    const std::string dest = path("existing.pdf");

    writeAll(dest, std::string("the old file"));
    PdfWriter *w = begin(dest);
    addFile(w, rgb, "e_1.jpg", 64, 32, 0, 0, 64, 32);
    ok("an abandoned document returns 0", PdfWriterEnd(w, 0, NULL, NULL, NULL)==0);
    ok("... leaves the destination as it was and deletes the partial file", readAll(dest)=="the old file" && !exists(dest + ".part"));

    gShimDiskLeft = 200000;
    w = begin(dest);
    Bytes huge(rgb.begin(), rgb.begin() + findMarker(rgb, 0xDA));
    segment(huge, 0xDA, { 3, 1, 0x00, 2, 0x00, 3, 0x00, 0, 63, 0 });
    huge.insert(huge.end(), (size_t)2 << 20, 0x55);
    huge.insert(huge.end(), { 0xFF, 0xD9 });
    ok("a full disk loses the document", addFile(w, huge, "e_huge.jpg", 64, 32, 0, 0, 64, 32)==PDFW_LOST);
    ok("... and every later page", addFile(w, rgb, "e_2.jpg", 64, 32, 0, 0, 64, 32)==PDFW_LOST);
    ok("PdfWriterEnd reports the failure", PdfWriterEnd(w, 1, NULL, NULL, NULL)==2);
    gShimDiskLeft = -1;
    ok("... and the destination is untouched, the partial file gone", readAll(dest)=="the old file" && !exists(dest + ".part"));

    gShimBusyPath = dest;
    int error = 0;
    ok("a destination held open elsewhere is refused before any work", PdfWriterBegin(wide(dest).c_str(), &error)==NULL && error==2 && !exists(dest + ".part"));
    gShimBusyPath.clear();

    writeAll(dest + ".part", std::string("not ours"));
    w = begin(dest);
    ok("a .part name in use is left alone: .part1 is used", w!=NULL && exists(dest + ".part1"));
    addFile(w, rgb, "e_3.jpg", 64, 32, 0, 0, 64, 32);
    gShimRefuseRename = true;
    ok("a destination that cannot be replaced is reported", PdfWriterEnd(w, 1, NULL, NULL, NULL)==3);
    gShimRefuseRename = false;
    ok("... the old file stays, and so does the other .part", readAll(dest)=="the old file" && readAll(dest + ".part")=="not ours" && !exists(dest + ".part1"));

    w = begin(dest);
    addFile(w, rgb, "e_4.jpg", 64, 32, 0, 0, 64, 32);
    ok("a finished document replaces the old file", PdfWriterEnd(w, 1, NULL, NULL, NULL)==0 && readAll(dest).compare(0, 8, "%PDF-1.7")==0);

    w = begin(path("empty.pdf"));
    ok("a document without pages is not saved", PdfWriterEnd(w, 1, NULL, NULL, NULL)==1 && !exists(path("empty.pdf")) && !exists(path("empty.pdf.part")));
    ok("a handle that is not a writer is refused", PdfWriterEnd(NULL, 1, NULL, NULL, NULL)==2 && PdfWriterAddJpegFile(NULL, L"x", 0, 1, 1, 0, 0, 1, 1, 0)==PDFW_LOST);
}

static void testLargeOffsets(const Bytes &rgb) {
    printf("  offsets past 4 GiB fit the xref table, and past its ten digits fail\n");
    const std::string dest = path("offsets.pdf");
    PdfWriter *w = begin(dest);
    if (!w) { ok("PdfWriterBegin", false); return; }
    // the offsets are bookkeeping: pretend 5 GB were written before the first page
    w->flushed += 5000000000ULL;
    addFile(w, rgb, "l_1.jpg", 64, 32, 0, 0, 64, 32);
    ok("finished", PdfWriterEnd(w, 1, NULL, NULL, NULL)==0);
    const std::string d = readAll(dest);
    const size_t e = d.find("0000000000 65535 f\r\n");
    ok("an offset of 5 GB is written with ten digits in a 20 byte entry", e!=std::string::npos && d.compare(e + 20, 7, "5000000")==0 && d.compare(e + 30, 10, " 00000 n\r\n")==0, (e!=std::string::npos) ? d.substr(e + 20, 20) : "no xref");

    w = begin(path("offsets2.pdf"));
    w->flushed += 10000000000ULL;
    addFile(w, rgb, "l_2.jpg", 64, 32, 0, 0, 64, 32);
    ok("past 9999999999 the document is refused, not corrupted", PdfWriterEnd(w, 1, NULL, NULL, NULL)==2 && !exists(path("offsets2.pdf")));
}

int main(int argc, char **argv) {
    if (argc>1)
       dir = argv[1];
    mkdir(dir.c_str(), 0755);

    const Bytes rgb = makeJpeg(quadrants(false), false);
    const Bytes grey = makeJpeg(quadrants(true), false);
    const Bytes prog = makeJpeg(quadrants(false), true);
    const Bytes restarts = makeJpeg(quadrants(false), false, 3);
    const bool render = haveRenderer();

    testFormatting();
    testJpegHeaders(rgb, grey, prog);
    testDocument(rgb, grey, prog, restarts);
    testRendering(render);
    testOrientations(rgb, render);
    testRollback(rgb);
    testDestination(rgb);
    testLargeOffsets(rgb);

    printf("\n  %s\n", fails ? "PDF WRITER TEST FAILED" : "pdf writer test passed");
    return fails ? 1 : 0;
}
