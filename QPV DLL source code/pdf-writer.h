// pdf-writer.h
//
// The PDF writer behind "Join images into a single file". Pages are written to
// <destination>.part as they are added, so memory use does not grow with the document, and
// PdfWriterEnd() puts the finished file in place of the destination only when it is complete.
//
// Every page holds one JPEG image placed at a given position and size, over a background
// rectangle wherever the image leaves the page uncovered. The JPEG comes from a GDI+ bitmap
// [PdfWriterAddBitmap(), in qpv-main.cpp] or unchanged from a JPEG file
// [PdfWriterAddJpegFile()], whose compressed data is copied without decoding it.
//
// Usage from AHK:
//    PdfWriterBegin(destination, &error)          handle, or NULL
//    PdfJpegFileInfo(file, &info)                 can the file be embedded as it is?
//    PdfWriterAddJpegFile(handle, file, ...)      one page each
//    PdfWriterAddBitmap(handle, pBitmap, ...)
//    PdfWriterEnd(handle, commit, ...)            always, also to abandon the document
//
// Page geometry is in PDF points [1/72 inch], with the origin at the bottom left corner.
//
// #included by qpv-main.cpp after windows.h: it uses fnOutputDebug(), DLL_API and
// DLL_CALLCONV from there.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_PDF_WRITER_H
#define QPV_PDF_WRITER_H

#include <vector>
#include <string>
#include <cstring>
#include <cmath>
#include <algorithm>

#define PDFW_MAGIC       0x57445051u
#define PDFW_OUT_SIZE    (1u << 20)
#define PDFW_READ_SIZE   (1u << 18)
#define PDFW_MAX_OFFSET  9999999999ULL   // a classic xref entry has ten digits for it
#define PDFW_MAX_ICC     (4u << 20)

// what the page functions return
#define PDFW_ADDED       0
#define PDFW_SKIPPED     1   // the image could not be used; the document is intact
#define PDFW_LOST        2   // writing failed; the document cannot be finished

// why a JPEG cannot be embedded as it is
#define PDFW_JPEG_UNREADABLE  1
#define PDFW_JPEG_NOT_JPEG    2
#define PDFW_JPEG_CODING      3   // arithmetic, lossless, hierarchical or 12 bits per sample
#define PDFW_JPEG_COLOURS     4   // CMYK, or colours PDF readers could interpret differently
#define PDFW_JPEG_DAMAGED     5

struct PdfwIcc {
    UINT64 hash;
    UINT obj;
    std::vector<BYTE> data;
};

struct PdfWriter {
    UINT magic = PDFW_MAGIC;
    HANDLE file = INVALID_HANDLE_VALUE;
    std::wstring dest, temp;
    std::vector<char> out;          // written, not yet flushed
    UINT64 flushed = 0;             // bytes already in the file
    std::vector<UINT64> offsets;    // byte offset of each object, by object number
    std::vector<UINT> pages;        // page objects, in page order
    std::vector<PdfwIcc> iccs;      // colour profiles written so far, shared by the images
    std::vector<BYTE> io;           // read buffer for JPEG files
    bool failed = false;
};

struct PdfwMark {
    UINT64 offset;
    size_t objs, pages, iccs;
};

struct PdfwPlace {
    double pageW, pageH, x, y, w, h;
    UINT bgColor;                   // 0xRRGGBB
    UINT orientation;               // EXIF orientation of the image data; 1 = as stored
};

static inline bool pdfwValid(const PdfWriter *w) {
    return w!=NULL && w->magic==PDFW_MAGIC;
}

static inline UINT64 pdfwTell(const PdfWriter *w) {
    return w->flushed + w->out.size();
}

static void pdfwWriteRaw(PdfWriter *w, const char *data, size_t n) {
    while (!w->failed && n>0)
    {
        DWORD wrote = 0;
        const DWORD chunk = (DWORD)std::min<size_t>(n, 1u << 30);
        if (!WriteFile(w->file, data, chunk, &wrote, NULL) || wrote==0)
        {
           fnOutputDebug("PdfWriter: failed to write the file");
           w->failed = true;
           return;
        }

        w->flushed += wrote;
        data += wrote;
        n -= wrote;
    }
}

static void pdfwFlush(PdfWriter *w) {
    if (!w->out.empty())
    {
       pdfwWriteRaw(w, w->out.data(), w->out.size());
       w->out.clear();
    }
}

static void pdfwPut(PdfWriter *w, const void *data, size_t n) {
    if (w->failed || n==0)
       return;

    if (w->out.size() + n > PDFW_OUT_SIZE)
    {
       pdfwFlush(w);
       if (n>=PDFW_OUT_SIZE)
       {
          pdfwWriteRaw(w, (const char*)data, n);
          return;
       }
    }

    const char *p = (const char*)data;
    w->out.insert(w->out.end(), p, p + n);
}

static int pdfwFormatUInt(char *b, UINT64 v) {
    char t[24];
    int n = 0;
    do {
        t[n++] = (char)('0' + v % 10);
        v /= 10;
    } while (v);

    for (int i = 0; i < n; i++)
        b[i] = t[n - 1 - i];
    return n;
}

// At most four decimals, without trailing zeros. printf() is not used: its decimal
// separator follows the C locale of the process.
static int pdfwFormatNum(char *b, double v) {
    if (!std::isfinite(v))
       v = 0;

    const bool negative = (v < 0);
    const double a = std::min<double>(negative ? -v : v, 1e12);
    const UINT64 t = (UINT64)(a * 10000.0 + 0.5);
    int n = 0;
    if (negative && t>0)
       b[n++] = '-';

    n += pdfwFormatUInt(b + n, t / 10000);
    UINT frac = (UINT)(t % 10000);
    if (frac>0)
    {
       int digits = 4;
       while (frac % 10==0)
       {
           frac /= 10;
           digits--;
       }

       b[n++] = '.';
       for (int i = digits - 1; i >= 0; i--)
       {
           b[n + i] = (char)('0' + frac % 10);
           frac /= 10;
       }
       n += digits;
    }
    return n;
}

static void pdfwStr(PdfWriter *w, const char *s) {
    pdfwPut(w, s, strlen(s));
}

static void pdfwUInt(PdfWriter *w, UINT64 v) {
    char b[24];
    pdfwPut(w, b, pdfwFormatUInt(b, v));
}

static void pdfwNum(PdfWriter *w, double v) {
    char b[40];
    pdfwPut(w, b, pdfwFormatNum(b, v));
}

static void pdfwAppendNum(std::string &s, double v) {
    char b[40];
    s.append(b, pdfwFormatNum(b, v));
}

static UINT pdfwNewObj(PdfWriter *w) {
    w->offsets.push_back(0);
    return (UINT)(w->offsets.size() - 1);
}

static void pdfwBeginObj(PdfWriter *w, UINT n) {
    w->offsets[n] = pdfwTell(w);
    pdfwUInt(w, n);
    pdfwStr(w, " 0 obj\n");
}

static PdfwMark pdfwMark(const PdfWriter *w) {
    const PdfwMark m = { pdfwTell(w), w->offsets.size(), w->pages.size(), w->iccs.size() };
    return m;
}

// Takes the document back to a mark, so a page that could not be finished leaves nothing
// behind, not even the part of it already in the file.
static void pdfwRollback(PdfWriter *w, const PdfwMark &m) {
    if (w->failed)
       return;

    if (m.offset>=w->flushed)
    {
       w->out.resize((size_t)(m.offset - w->flushed));
    } else
    {
       w->out.clear();
       LARGE_INTEGER pos;
       pos.QuadPart = (LONGLONG)m.offset;
       if (!SetFilePointerEx(w->file, pos, NULL, FILE_BEGIN) || !SetEndOfFile(w->file))
       {
          fnOutputDebug("PdfWriter: failed to cut an unfinished page off the file");
          w->failed = true;
          return;
       }
       w->flushed = m.offset;
    }

    w->offsets.resize(m.objs);
    w->pages.resize(m.pages);
    w->iccs.resize(m.iccs);
}

// A JPEG being read: from a file through the `own` buffer, or straight from memory.
struct PdfwSrc {
    HANDLE file = INVALID_HANDLE_VALUE;
    BYTE *own = NULL;
    const BYTE *buf = NULL;
    size_t cap = 0, pos = 0, len = 0;
    bool readError = false;
};

// Makes at least `need` bytes available at buf + pos.
static bool pdfwSrcFill(PdfwSrc &s, size_t need) {
    if (s.len - s.pos>=need)
       return true;
    if (s.file==INVALID_HANDLE_VALUE || need>s.cap)
       return false;

    memmove(s.own, s.own + s.pos, s.len - s.pos);
    s.len -= s.pos;
    s.pos = 0;
    while (s.len < need)
    {
        DWORD got = 0;
        if (!ReadFile(s.file, s.own + s.len, (DWORD)(s.cap - s.len), &got, NULL))
        {
           s.readError = true;
           return false;
        }

        if (got==0)
           return false;
        s.len += got;
    }
    return true;
}

static int pdfwSrcByte(PdfwSrc &s) {
    if (!pdfwSrcFill(s, 1))
       return -1;
    return s.buf[s.pos++];
}

static bool pdfwSrcRead(PdfwSrc &s, BYTE *dst, size_t n) {
    while (n>0)
    {
        if (!pdfwSrcFill(s, 1))
           return false;

        const size_t take = std::min<size_t>(n, s.len - s.pos);
        memcpy(dst, s.buf + s.pos, take);
        s.pos += take;
        dst += take;
        n -= take;
    }
    return true;
}

static bool pdfwSrcSkip(PdfwSrc &s, size_t n) {
    while (n>0)
    {
        if (!pdfwSrcFill(s, 1))
           return false;

        const size_t take = std::min<size_t>(n, s.len - s.pos);
        s.pos += take;
        n -= take;
    }
    return true;
}

struct PdfwJpeg {
    UINT width = 0, height = 0, comps = 0, orientation = 1;
    int adobe = -1;                 // colour transform flag of an Adobe APP14 segment
    int reason = 0;                 // PDFW_JPEG_*; 0 when the data can be embedded
    UINT sosLength = 0;             // length field of the first SOS segment
    std::vector<BYTE> head;         // SOI and the header segments to embed, when asked for
    std::vector<BYTE> icc;          // the embedded colour profile, when PDF readers can use it
};

static UINT pdfwBE32(const BYTE *p) {
    return ((UINT)p[0] << 24) | ((UINT)p[1] << 16) | ((UINT)p[2] << 8) | p[3];
}

// Reads tag 0x0112 [Orientation] off IFD0 of the TIFF structure in an Exif APP1 segment.
static UINT pdfwExifOrientation(const BYTE *t, size_t n) {
    if (n < 8)
       return 1;

    const bool le = (t[0]=='I' && t[1]=='I');
    if (!le && !(t[0]=='M' && t[1]=='M'))
       return 1;

    auto rd16 = [&](size_t o) -> UINT { return le ? (t[o] | (t[o + 1] << 8)) : ((t[o] << 8) | t[o + 1]); };
    auto rd32 = [&](size_t o) -> UINT { return le ? (rd16(o) | (rd16(o + 2) << 16)) : ((rd16(o) << 16) | rd16(o + 2)); };
    if (rd16(2)!=42)
       return 1;

    const size_t ifd = rd32(4);
    if (ifd < 8 || ifd + 2 > n)
       return 1;

    const UINT entries = rd16(ifd);
    for (UINT i = 0; i < entries; i++)
    {
        const size_t e = ifd + 2 + (size_t)i * 12;
        if (e + 12 > n)
           break;

        if (rd16(e)==0x0112)
        {
           // type SHORT, one value at least
           const UINT v = (rd16(e + 2)==3 && rd32(e + 4)>=1) ? rd16(e + 8) : 0;
           return (v>=1 && v<=8) ? v : 1;
        }
    }
    return 1;
}

// A profile an ICCBased colour space accepts: complete, of the image's colour space and of
// an input, display, output or colour space class.
static bool pdfwIccUsable(std::vector<BYTE> &icc, UINT comps) {
    if (icc.size() < 132)
       return false;

    const UINT declared = pdfwBE32(icc.data());
    if (declared < 132 || declared > icc.size())
       return false;

    icc.resize(declared);
    const UINT kind = pdfwBE32(&icc[12]), space = pdfwBE32(&icc[16]);
    if (kind!=0x6D6E7472 && kind!=0x73636E72 && kind!=0x70727472 && kind!=0x73706163)   // mntr scnr prtr spac
       return false;
    return (comps==3) ? (space==0x52474220) : (space==0x47524159);                     // 'RGB ' 'GRAY'
}

static bool pdfwJpegFail(PdfwJpeg &j, const PdfwSrc &s, int reason) {
    j.reason = s.readError ? PDFW_JPEG_UNREADABLE : reason;
    return false;
}

// Reads a JPEG up to the length field of its first SOS segment, which leaves the source on
// that segment's payload. The scans are only checked while pdfwJpegCopyScans() copies them.
// Of the header segments, keepHead collects the ones a decoder needs: the tables, the frame
// header, JFIF and the Adobe segment that says how to read the colours. Exif, XMP, comments
// and the like are dropped, and an ICC profile is returned apart, for an ICCBased colour space.
static bool pdfwJpegHeader(PdfwSrc &s, PdfwJpeg &j, bool keepHead) {
    std::vector<BYTE> seg;
    std::vector<std::vector<BYTE>> iccChunks;
    std::vector<char> iccSeen;
    bool iccBroken = false, gotExif = false, gotFrame = false, rgbIds = false;

    if (pdfwSrcByte(s)!=0xFF || pdfwSrcByte(s)!=0xD8)
       return pdfwJpegFail(j, s, PDFW_JPEG_NOT_JPEG);

    if (keepHead)
       j.head.assign({ 0xFF, 0xD8 });

    for (;;)
    {
        int c = pdfwSrcByte(s);
        if (c!=0xFF)
           return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);

        while (c==0xFF)
            c = pdfwSrcByte(s);      // fill bytes

        if (c<0 || c==0x00 || c==0xD8 || c==0xD9)
           return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);
        if (c==0x01 || (c>=0xD0 && c<=0xD7))
           continue;                 // markers without a segment

        const int hi = pdfwSrcByte(s), lo = pdfwSrcByte(s);
        if (hi<0 || lo<0 || ((hi << 8) | lo)<2)
           return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);

        const UINT segLength = (UINT)((hi << 8) | lo);
        if (c==0xDA)
        {
           if (!gotFrame)
              return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);

           j.sosLength = segLength;
           break;
        }

        // DAC, DNL, DHP, EXP and the reserved JPG markers belong to codings PDF readers lack
        if (c==0xC8 || c==0xCC || c==0xDC || c==0xDE || c==0xDF || (c>=0xF0 && c<=0xFD))
           return pdfwJpegFail(j, s, PDFW_JPEG_CODING);

        const bool isFrame = (c>=0xC0 && c<=0xCF && c!=0xC4);
        const bool keep = isFrame || c==0xC4 || c==0xDB || c==0xDD || c==0xE0 || c==0xEE;
        const size_t body = segLength - 2;
        if (keep || c==0xE1 || c==0xE2)
        {
           seg.resize(body);
           if (!pdfwSrcRead(s, seg.data(), body))
              return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);
        } else if (!pdfwSrcSkip(s, body))
        {
           return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);
        }

        if (isFrame)
        {
           if (gotFrame || body < 6)
              return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);

           gotFrame = true;
           j.height = (seg[1] << 8) | seg[2];
           j.width  = (seg[3] << 8) | seg[4];
           j.comps  = seg[5];
           if (body < 6 + 3 * (size_t)j.comps)
              return pdfwJpegFail(j, s, PDFW_JPEG_DAMAGED);

           // baseline, extended sequential or progressive Huffman coding, 8 bits per sample
           if ((c!=0xC0 && c!=0xC1 && c!=0xC2) || seg[0]!=8 || j.width==0 || j.height==0)
              return pdfwJpegFail(j, s, PDFW_JPEG_CODING);

           rgbIds = (j.comps==3 && seg[6]=='R' && seg[9]=='G' && seg[12]=='B');
        } else if (c==0xEE && body>=12 && memcmp(seg.data(), "Adobe", 5)==0)
        {
           j.adobe = seg[11];
        } else if (c==0xE1 && !gotExif && body>=6 && memcmp(seg.data(), "Exif\0\0", 6)==0)
        {
           gotExif = true;
           j.orientation = pdfwExifOrientation(seg.data() + 6, body - 6);
        } else if (c==0xE2 && body>14 && memcmp(seg.data(), "ICC_PROFILE\0", 12)==0)
        {
           const int seq = seg[12], count = seg[13];
           if (iccChunks.empty() && count>0)
           {
              iccChunks.resize(count);
              iccSeen.assign(count, 0);
           }

           if (seq<1 || seq>count || count!=(int)iccChunks.size() || iccSeen[seq - 1])
           {
              iccBroken = true;
           } else
           {
              iccSeen[seq - 1] = 1;
              iccChunks[seq - 1].assign(seg.begin() + 14, seg.end());
           }
        }

        if (keep && keepHead)
        {
           const BYTE m[4] = { 0xFF, (BYTE)c, (BYTE)hi, (BYTE)lo };
           j.head.insert(j.head.end(), m, m + 4);
           j.head.insert(j.head.end(), seg.begin(), seg.end());
        }
    }

    // Three components are YCbCr unless an Adobe segment says otherwise, and PDF readers go
    // by the same rule; an RGB image that only its component IDs mark as such would not.
    if ((j.comps==3) ? (j.adobe==2 || (j.adobe<0 && rgbIds)) : (j.comps!=1))
       return pdfwJpegFail(j, s, PDFW_JPEG_COLOURS);

    if (!iccBroken && !iccChunks.empty() && std::find(iccSeen.begin(), iccSeen.end(), 0)==iccSeen.end())
    {
       std::vector<BYTE> icc;
       for (const std::vector<BYTE> &chunk : iccChunks)
       {
           if (icc.size() + chunk.size() > PDFW_MAX_ICC)
           {
              icc.clear();
              break;
           }
           icc.insert(icc.end(), chunk.begin(), chunk.end());
       }

       if (pdfwIccUsable(icc, j.comps))
          j.icc.swap(icc);
    }
    return true;
}

// Markers that may follow the first scan of a JPEG PDF readers can decode.
static bool pdfwScanMarkerOk(int c) {
    return c==0xC4 || c==0xDA || c==0xDB || c==0xDD || c==0xFE || (c>=0xE0 && c<=0xEF);
}

// Copies the scans of a JPEG whose header pdfwJpegHeader() has read, from the first SOS
// segment up to and including EOI; whatever follows EOI [a second image, a video] is left
// out. Returns false when the data is truncated, damaged or unreadable, or holds markers
// PDF readers do not decode; the caller then rolls the page back.
static bool pdfwJpegCopyScans(PdfWriter *w, PdfwSrc &s, UINT sosLength, UINT64 &copied) {
    enum { BODY, ENTROPY, ENTROPY_FF, NEXT_FF, MARKER, LENGTH_HI, LENGTH_LO };
    const BYTE sos[4] = { 0xFF, 0xDA, (BYTE)(sosLength >> 8), (BYTE)(sosLength & 255) };
    pdfwPut(w, sos, 4);
    copied = 4;

    UINT64 remaining = sosLength - 2;
    int state = (remaining>0) ? BODY : ENTROPY, marker = 0xDA, lengthHi = 0;
    for (;;)
    {
        if (!pdfwSrcFill(s, 1))
           return false;

        const size_t start = s.pos;
        bool done = false, bad = false;
        while (s.pos < s.len && !done && !bad)
        {
            switch (state)
            {
               case BODY:
               {
                  const size_t take = (size_t)std::min<UINT64>(remaining, s.len - s.pos);
                  s.pos += take;
                  remaining -= take;
                  if (remaining==0)
                     state = (marker==0xDA) ? ENTROPY : NEXT_FF;
                  break;
               }
               case ENTROPY:
               {
                  const BYTE *ff = (const BYTE*)memchr(s.buf + s.pos, 0xFF, s.len - s.pos);
                  if (ff==NULL)
                  {
                     s.pos = s.len;
                  } else
                  {
                     s.pos = (size_t)(ff - s.buf) + 1;
                     state = ENTROPY_FF;
                  }
                  break;
               }
               case NEXT_FF:
                  if (s.buf[s.pos++]==0xFF)
                     state = MARKER;
                  else
                     bad = true;
                  break;
               case ENTROPY_FF:
               case MARKER:
               {
                  const int c = s.buf[s.pos++];
                  if (c==0xFF)
                     break;                      // fill byte
                  if (state==ENTROPY_FF && (c==0x00 || (c>=0xD0 && c<=0xD7)))
                     state = ENTROPY;            // a stuffed byte or a restart marker
                  else if (c==0xD9)
                     done = true;
                  else if (c==0x01 || (c>=0xD0 && c<=0xD7))
                     state = NEXT_FF;
                  else if (pdfwScanMarkerOk(c))
                  {
                     marker = c;
                     state = LENGTH_HI;
                  } else
                     bad = true;
                  break;
               }
               case LENGTH_HI:
                  lengthHi = s.buf[s.pos++];
                  state = LENGTH_LO;
                  break;
               case LENGTH_LO:
               {
                  const UINT length = (UINT)((lengthHi << 8) | s.buf[s.pos++]);
                  if (length<2)
                  {
                     bad = true;
                     break;
                  }
                  remaining = length - 2;
                  state = (remaining>0) ? BODY : ((marker==0xDA) ? ENTROPY : NEXT_FF);
                  break;
               }
            }
        }

        pdfwPut(w, s.buf + start, s.pos - start);
        copied += s.pos - start;
        if (bad || w->failed)
           return false;
        if (done)
           return true;
    }
}

static UINT64 pdfwHash(const std::vector<BYTE> &d) {
    UINT64 h = 1469598103934665603ULL;
    for (const BYTE b : d)
    {
        h ^= b;
        h *= 1099511628211ULL;
    }
    return h;
}

// Writes a colour profile once per document; the images with the same one share it.
static UINT pdfwIccObject(PdfWriter *w, const std::vector<BYTE> &icc, UINT comps) {
    if (icc.empty())
       return 0;

    const UINT64 hash = pdfwHash(icc);
    for (const PdfwIcc &e : w->iccs)
    {
        if (e.hash==hash && e.data==icc)
           return e.obj;
    }

    const UINT n = pdfwNewObj(w);
    pdfwBeginObj(w, n);
    pdfwStr(w, (comps==1) ? "<</N 1/Alternate/DeviceGray/Length " : "<</N 3/Alternate/DeviceRGB/Length ");
    pdfwUInt(w, icc.size());
    pdfwStr(w, ">>\nstream\n");
    pdfwPut(w, icc.data(), icc.size());
    pdfwStr(w, "\nendstream\nendobj\n");

    const PdfwIcc e = { hash, n, icc };
    w->iccs.push_back(e);
    return n;
}

// The image dictionary, up to the stream data. Pass lengthObj to have /Length point at an
// object written after the data, when its size is not known up front.
static void pdfwImageObject(PdfWriter *w, UINT obj, const PdfwJpeg &j, UINT iccObj, UINT64 length, UINT lengthObj) {
    pdfwBeginObj(w, obj);
    pdfwStr(w, "<</Type/XObject/Subtype/Image/Width ");
    pdfwUInt(w, j.width);
    pdfwStr(w, "/Height ");
    pdfwUInt(w, j.height);
    pdfwStr(w, "/BitsPerComponent 8/ColorSpace");
    if (iccObj>0)
    {
       pdfwStr(w, "[/ICCBased ");
       pdfwUInt(w, iccObj);
       pdfwStr(w, " 0 R]");
    } else
    {
       pdfwStr(w, (j.comps==1) ? "/DeviceGray" : "/DeviceRGB");
    }

    pdfwStr(w, "/Filter/DCTDecode");
    if (j.comps==3 && j.adobe==0)
       pdfwStr(w, "/DecodeParms<</ColorTransform 0>>");

    pdfwStr(w, "/Length ");
    pdfwUInt(w, (lengthObj>0) ? lengthObj : length);
    pdfwStr(w, (lengthObj>0) ? " 0 R>>\nstream\n" : ">>\nstream\n");
}

// The transformation that maps the image's unit square onto the placement rectangle, turned
// and mirrored the way the EXIF orientation says the stored rows are meant to be seen.
static void pdfwMatrix(const PdfwPlace &p, double m[6]) {
    const double x = p.x, y = p.y, w = p.w, h = p.h;
    switch (p.orientation)
    {
       case 2:  m[0] = -w; m[1] = 0;  m[2] = 0;  m[3] = h;  m[4] = x + w; m[5] = y;      break;
       case 3:  m[0] = -w; m[1] = 0;  m[2] = 0;  m[3] = -h; m[4] = x + w; m[5] = y + h;  break;
       case 4:  m[0] = w;  m[1] = 0;  m[2] = 0;  m[3] = -h; m[4] = x;     m[5] = y + h;  break;
       case 5:  m[0] = 0;  m[1] = -h; m[2] = -w; m[3] = 0;  m[4] = x + w; m[5] = y + h;  break;
       case 6:  m[0] = 0;  m[1] = -h; m[2] = w;  m[3] = 0;  m[4] = x;     m[5] = y + h;  break;
       case 7:  m[0] = 0;  m[1] = h;  m[2] = w;  m[3] = 0;  m[4] = x;     m[5] = y;      break;
       case 8:  m[0] = 0;  m[1] = h;  m[2] = -w; m[3] = 0;  m[4] = x + w; m[5] = y;      break;
       default: m[0] = w;  m[1] = 0;  m[2] = 0;  m[3] = h;  m[4] = x;     m[5] = y;      break;
    }
}

static bool pdfwPlaceUsable(const PdfwPlace &p) {
    const double v[6] = { p.pageW, p.pageH, p.x, p.y, p.w, p.h };
    for (const double d : v)
    {
        if (!std::isfinite(d) || std::fabs(d) > 1e7)
           return false;
    }
    return p.pageW>0 && p.pageH>0 && p.w>0 && p.h>0;
}

// The content stream and the page object of an image already written.
static void pdfwPageObjects(PdfWriter *w, const PdfwPlace &p, UINT imageObj) {
    std::string cs = "q\n";
    const double e = 0.01;
    if (p.x > e || p.y > e || p.x + p.w < p.pageW - e || p.y + p.h < p.pageH - e)
    {
       for (int shift = 16; shift >= 0; shift -= 8)
       {
           pdfwAppendNum(cs, ((p.bgColor >> shift) & 255) / 255.0);
           cs += ' ';
       }
       cs += "rg\n0 0 ";
       pdfwAppendNum(cs, p.pageW);
       cs += ' ';
       pdfwAppendNum(cs, p.pageH);
       cs += " re\nf\n";
    }

    double m[6];
    pdfwMatrix(p, m);
    cs += "q\n";
    for (int i = 0; i < 6; i++)
    {
        pdfwAppendNum(cs, m[i]);
        cs += ' ';
    }
    cs += "cm\n/Im0 Do\nQ\nQ\n";

    const UINT contents = pdfwNewObj(w), page = pdfwNewObj(w);
    pdfwBeginObj(w, contents);
    pdfwStr(w, "<</Length ");
    pdfwUInt(w, cs.size());
    pdfwStr(w, ">>\nstream\n");
    pdfwPut(w, cs.data(), cs.size());
    pdfwStr(w, "\nendstream\nendobj\n");

    pdfwBeginObj(w, page);
    pdfwStr(w, "<</Type/Page/Parent 1 0 R/MediaBox[0 0 ");
    pdfwNum(w, p.pageW);
    pdfwStr(w, " ");
    pdfwNum(w, p.pageH);
    pdfwStr(w, "]/Resources<</XObject<</Im0 ");
    pdfwUInt(w, imageObj);
    pdfwStr(w, " 0 R>>>>/Contents ");
    pdfwUInt(w, contents);
    pdfwStr(w, " 0 R>>\nendobj\n");
    w->pages.push_back(page);
}

// Lays premultiplied BGRA pixels over an opaque colour [0xRRGGBB], into 24-bit BGR rows.
static void pdfwOverColor(const BYTE *src, int srcStride, UINT width, UINT height, UINT color, BYTE *dst, int dstStride) {
    const UINT back[3] = { color & 255, (color >> 8) & 255, (color >> 16) & 255 };
    for (UINT y = 0; y < height; y++)
    {
        const BYTE *s = src + (size_t)y * srcStride;
        BYTE *d = dst + (size_t)y * dstStride;
        for (UINT x = 0; x < width; x++, s += 4, d += 3)
        {
            const UINT uncovered = 255 - s[3];
            for (int c = 0; c < 3; c++)
            {
                const UINT v = s[c] + (back[c] * uncovered + 127) / 255;
                d[c] = (BYTE)((v > 255) ? 255 : v);
            }
        }
    }
}

// A PDF text string: literal when it is plain ASCII, otherwise UTF-16BE after a byte order mark.
static void pdfwText(PdfWriter *w, const wchar_t *s) {
    bool ascii = true;
    for (const wchar_t *p = s; *p; p++)
    {
        if (*p < 0x20 || *p > 0x7E)
        {
           ascii = false;
           break;
        }
    }

    std::string o;
    if (ascii)
    {
       o += '(';
       for (const wchar_t *p = s; *p; p++)
       {
           if (*p==L'(' || *p==L')' || *p==L'\\')
              o += '\\';
           o += (char)*p;
       }
       o += ')';
    } else
    {
       static const char hex[] = "0123456789ABCDEF";
       o += "<FEFF";
       for (const wchar_t *p = s; *p; p++)
       {
           UINT cp = (UINT)*p, units[2] = { cp, 0 };
           int n = 1;
           if (cp > 0xFFFF)          // only where wchar_t is 32 bits wide
           {
              cp -= 0x10000;
              units[0] = 0xD800 | (cp >> 10);
              units[1] = 0xDC00 | (cp & 0x3FF);
              n = 2;
           }

           for (int k = 0; k < n; k++)
           {
               for (int b = 12; b >= 0; b -= 4)
                   o += hex[(units[k] >> b) & 15];
           }
       }
       o += '>';
    }
    pdfwPut(w, o.data(), o.size());
}

static void pdfwInfoEntry(PdfWriter *w, const char *key, const wchar_t *text) {
    if (text==NULL || text[0]==0)
       return;

    pdfwStr(w, key);
    pdfwText(w, text);
}

// Writes the page tree, the catalog, the document information and the cross-reference table.
static bool pdfwFinish(PdfWriter *w, const wchar_t *title, const wchar_t *producer, const wchar_t *created) {
    pdfwBeginObj(w, 1);
    pdfwStr(w, "<</Type/Pages/Count ");
    pdfwUInt(w, w->pages.size());
    pdfwStr(w, "/Kids[");
    for (size_t i = 0; i < w->pages.size(); i++)
    {
        pdfwStr(w, (i % 8==0) ? "\n" : " ");
        pdfwUInt(w, w->pages[i]);
        pdfwStr(w, " 0 R");
    }
    pdfwStr(w, "]>>\nendobj\n");

    pdfwBeginObj(w, 2);
    pdfwStr(w, "<</Type/Catalog/Pages 1 0 R>>\nendobj\n");

    pdfwBeginObj(w, 3);
    pdfwStr(w, "<<");
    pdfwInfoEntry(w, "/Title", title);
    pdfwInfoEntry(w, "/Producer", producer);
    pdfwInfoEntry(w, "/CreationDate", created);
    pdfwStr(w, ">>\nendobj\n");

    const UINT64 xref = pdfwTell(w);
    pdfwStr(w, "xref\n0 ");
    pdfwUInt(w, w->offsets.size());
    pdfwStr(w, "\n0000000000 65535 f\r\n");
    for (size_t i = 1; i < w->offsets.size(); i++)
    {
        UINT64 v = w->offsets[i];
        if (v==0 || v>PDFW_MAX_OFFSET)
        {
           fnOutputDebug("PdfWriter: an object has no usable offset in the cross-reference table");
           return false;
        }

        char e[20];
        for (int k = 9; k >= 0; k--)
        {
            e[k] = (char)('0' + v % 10);
            v /= 10;
        }
        memcpy(e + 10, " 00000 n\r\n", 10);
        pdfwPut(w, e, 20);
    }

    pdfwStr(w, "trailer\n<</Size ");
    pdfwUInt(w, w->offsets.size());
    pdfwStr(w, "/Root 2 0 R/Info 3 0 R>>\nstartxref\n");
    pdfwUInt(w, xref);
    pdfwStr(w, "\n%%EOF\n");
    pdfwFlush(w);
    return !w->failed;
}

// The page of PdfWriterAddBitmap(): JPEG data in memory, embedded whole.
static int pdfwAddJpegData(PdfWriter *w, const BYTE *data, size_t size, const PdfwPlace &p) {
    if (!pdfwValid(w) || w->failed)
       return PDFW_LOST;

    const PdfwMark mark = pdfwMark(w);
    int result = PDFW_SKIPPED;
    try
    {
       PdfwSrc s;
       s.buf = data;
       s.cap = s.len = size;
       PdfwJpeg j;
       if (data!=NULL && pdfwJpegHeader(s, j, false))
       {
          const UINT image = pdfwNewObj(w);
          pdfwImageObject(w, image, j, 0, size, 0);
          pdfwPut(w, data, size);
          pdfwStr(w, "\nendstream\nendobj\n");
          pdfwPageObjects(w, p, image);
          result = PDFW_ADDED;
       }
    } catch (...)
    {
       result = PDFW_SKIPPED;
    }

    if (result!=PDFW_ADDED)
       pdfwRollback(w, mark);
    return w->failed ? PDFW_LOST : result;
}

// Starts a document for `destination`. On failure it returns NULL and sets *error to 1 [no
// memory or no destination given], 2 [the destination is in use or read-only] or 3 [no file
// can be created next to it]. The destination itself is not touched until PdfWriterEnd().
DLL_API PdfWriter* DLL_CALLCONV PdfWriterBegin(const wchar_t *destination, int *error) {
    int unused = 0;
    if (error==NULL)
       error = &unused;

    *error = 1;
    if (destination==NULL || destination[0]==0)
       return NULL;

    PdfWriter *w = NULL;
    try
    {
       // a destination that could not be replaced at the end is refused before any work is done
       HANDLE probe = CreateFileW(destination, GENERIC_WRITE | DELETE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
       if (probe!=INVALID_HANDLE_VALUE)
       {
          CloseHandle(probe);
       } else
       {
          const DWORD e = GetLastError();
          if (e!=ERROR_FILE_NOT_FOUND && e!=ERROR_PATH_NOT_FOUND)
          {
             *error = 2;
             return NULL;
          }
       }

       w = new PdfWriter();
       w->dest = destination;
       for (int i = 0; i < 100; i++)
       {
           std::wstring t = w->dest + L".part";
           if (i>0)
              t += std::to_wstring(i);

           w->file = CreateFileW(t.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
           if (w->file!=INVALID_HANDLE_VALUE)
           {
              w->temp = t;
              break;
           }

           const DWORD e = GetLastError();
           if (e!=ERROR_FILE_EXISTS && e!=ERROR_ALREADY_EXISTS)
              break;
       }

       if (w->file==INVALID_HANDLE_VALUE)
       {
          delete w;
          *error = 3;
          return NULL;
       }

       w->out.reserve(PDFW_OUT_SIZE);
       w->io.resize(PDFW_READ_SIZE);
       w->offsets.assign(4, 0);      // 1 the page tree, 2 the catalog, 3 the document information
       pdfwStr(w, "%PDF-1.7\n%\xE2\xE3\xCF\xD3\n");
       *error = 0;
       return w;
    } catch (...)
    {
       if (w!=NULL)
       {
          if (w->file!=INVALID_HANDLE_VALUE)
          {
             CloseHandle(w->file);
             DeleteFileW(w->temp.c_str());
          }
          delete w;
       }
       *error = 1;
       return NULL;
    }
}

// Tells whether a JPEG file can be embedded as it is. info receives five UINTs: width,
// height, components, EXIF orientation [1 to 8] and the PDFW_JPEG_* reason when it cannot.
// Only the header is read; a file damaged further in is caught by PdfWriterAddJpegFile().
DLL_API int DLL_CALLCONV PdfJpegFileInfo(const wchar_t *path, UINT *info) {
    if (info==NULL)
       return 0;

    memset(info, 0, 5 * sizeof(UINT));
    info[4] = PDFW_JPEG_UNREADABLE;
    if (path==NULL)
       return 0;

    HANDLE h = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (h==INVALID_HANDLE_VALUE)
       return 0;

    int ok = 0;
    try
    {
       std::vector<BYTE> io(1u << 16);
       PdfwSrc s;
       s.file = h;
       s.own = io.data();
       s.buf = s.own;
       s.cap = io.size();
       PdfwJpeg j;
       ok = pdfwJpegHeader(s, j, false) ? 1 : 0;
       info[0] = j.width;
       info[1] = j.height;
       info[2] = j.comps;
       info[3] = j.orientation;
       info[4] = j.reason;
    } catch (...)
    {
       ok = 0;
    }

    CloseHandle(h);
    return ok;
}

// Adds a page that shows a JPEG file with its compressed data copied unchanged. With
// useOrientation=1 the EXIF orientation of the file decides how the stored rows are turned
// into the placement rectangle. Returns PDFW_ADDED, PDFW_SKIPPED when the file cannot be
// embedded [the document stays as it was] or PDFW_LOST.
DLL_API int DLL_CALLCONV PdfWriterAddJpegFile(PdfWriter *w, const wchar_t *path, int useOrientation, double pageW, double pageH, double x, double y, double width, double height, UINT bgColor) {
    if (!pdfwValid(w) || w->failed)
       return PDFW_LOST;

    const PdfwPlace p = { pageW, pageH, x, y, width, height, bgColor, 1 };
    if (path==NULL || !pdfwPlaceUsable(p))
       return PDFW_SKIPPED;

    HANDLE h = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (h==INVALID_HANDLE_VALUE)
       return PDFW_SKIPPED;

    const PdfwMark mark = pdfwMark(w);
    int result = PDFW_SKIPPED;
    try
    {
       PdfwSrc s;
       s.file = h;
       s.own = w->io.data();
       s.buf = s.own;
       s.cap = w->io.size();
       PdfwJpeg j;
       if (pdfwJpegHeader(s, j, true))
       {
          PdfwPlace q = p;
          q.orientation = (useOrientation==1) ? j.orientation : 1;
          const UINT icc = pdfwIccObject(w, j.icc, j.comps);
          const UINT image = pdfwNewObj(w), length = pdfwNewObj(w);
          pdfwImageObject(w, image, j, icc, 0, length);
          pdfwPut(w, j.head.data(), j.head.size());
          UINT64 copied = 0;
          if (pdfwJpegCopyScans(w, s, j.sosLength, copied))
          {
             pdfwStr(w, "\nendstream\nendobj\n");
             pdfwBeginObj(w, length);
             pdfwUInt(w, j.head.size() + copied);
             pdfwStr(w, "\nendobj\n");
             pdfwPageObjects(w, q, image);
             result = PDFW_ADDED;
          }
       }
    } catch (...)
    {
       result = PDFW_SKIPPED;
    }

    CloseHandle(h);
    if (result!=PDFW_ADDED)
       pdfwRollback(w, mark);
    return w->failed ? PDFW_LOST : result;
}

// Finishes the document and puts it in place of the destination [commit=1], or abandons
// it [commit=0]: the partial file is deleted and the destination left as it was. The writer
// is freed either way. Returns 0 on success, 1 when there was no page to save, 2 when
// writing failed and 3 when the destination could not be replaced.
DLL_API int DLL_CALLCONV PdfWriterEnd(PdfWriter *w, int commit, const wchar_t *title, const wchar_t *producer, const wchar_t *created) {
    if (!pdfwValid(w))
       return 2;

    int result = 0;
    try
    {
       if (commit==1 && w->failed)
          result = 2;
       else if (commit==1 && w->pages.empty())
          result = 1;
       else if (commit==1 && !pdfwFinish(w, title, producer, created))
          result = 2;
    } catch (...)
    {
       result = 2;
    }

    if (!CloseHandle(w->file) && commit==1 && result==0)
       result = 2;

    if (commit==1 && result==0 && !MoveFileExW(w->temp.c_str(), w->dest.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
    {
       fnOutputDebug("PdfWriter: failed to replace the destination file");
       result = 3;
    }

    if (commit!=1 || result!=0)
       DeleteFileW(w->temp.c_str());

    w->magic = 0;
    delete w;
    return result;
}

#endif // QPV_PDF_WRITER_H
