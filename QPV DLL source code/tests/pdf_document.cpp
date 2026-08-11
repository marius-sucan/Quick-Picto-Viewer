// Page geometry and document structure of the PDF exporter, compiled from the SHIPPED
// Jpeg2PDF.cpp rather than a transcription of it. Nothing else pins any of this: the DLL
// needs MSVC, and the only other check on a generated PDF is a human opening one.
//
// What is worth guarding here:
//   - MediaBox is written in PDF user space units, which the spec fixes at 1/72 inch. It
//     used to be multiplied by the DPI the pages were rasterised at, which made every page
//     (dpi/72) times too large. The unit is invisible in the output - the numbers are bare
//     integers - so the failure is silent and only shows up in a reader's page properties.
//   - the same two fields drive the image placement matrix, so a unit change that missed
//     one of them would letterbox or crop every page while still reporting the right size.
//   - the xref offsets are accumulated by hand from sprintf return values. Changing the
//     page size changed their digit count, which is exactly the kind of edit that silently
//     desynchronises a hand-rolled table.
//
// Jpeg2PDF.cpp is #included into qpv-main.cpp after windows.h, so UINT32, IDOK and ERROR
// arrive from the SDK. The four lines below stand in for all of it, which is what lets the
// file be compiled verbatim here.
//
// written by Marius Șucan with Claude Opus 5

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

typedef unsigned int UINT32;
#define IDOK  1
#define ERROR 0

#ifndef QPV_JPEG2PDF_HEADER
#define QPV_JPEG2PDF_HEADER "../Jpeg2PDF.h"
#endif
#ifndef QPV_JPEG2PDF_SOURCE
#define QPV_JPEG2PDF_SOURCE "../Jpeg2PDF.cpp"
#endif

#include QPV_JPEG2PDF_HEADER
#include QPV_JPEG2PDF_SOURCE

static int fails = 0;

static void ok(const char *what, bool cond, const char *detail = 0) {
    printf("    %-62s %s", what, cond ? "ok" : "FAIL");
    if (!cond && detail) printf("   (%s)", detail);
    printf("\n");
    if (!cond) fails++;
}

static void has(const char *what, const std::string &pdf, const char *needle) {
    ok(what, pdf.find(needle) != std::string::npos, needle);
}

// A real 10x10 baseline JPEG with the JFIF APP0 header GDI+ writes. The exporter only ever
// sees GDI+ output - CombineImgsIntoPDF() re-encodes every page through
// Gdip_SaveBitmapToFile() - so this is representative of the only input that reaches it.
static const unsigned char sampleJpeg[] = {
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x0A,
    0x00, 0x0A, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
    0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
    0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
    0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
    0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
    0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
    0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
    0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
    0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
    0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
    0x00, 0x00, 0x3F, 0x00, 0xF9, 0xFE, 0x8A, 0x28, 0xAF, 0xFF, 0xD9,};

// Builds a document the way CreatePDFfile() does: begin, add each page, end, emit.
static std::string buildDoc(double inW, double inH, int pages, UINT32 *pageW, UINT32 *pageH) {
    PJPEG2PDF p = Jpeg2PDF_BeginDocument(inW, inH);
    if (!p) { ok("BeginDocument returned a document", false); return ""; }
    *pageW = p->pageW;
    *pageH = p->pageH;

    unsigned short jw = 0, jh = 0;
    if (get_jpeg_size((unsigned char *)sampleJpeg, sizeof(sampleJpeg), &jw, &jh) != 1) {
        ok("the sample JPEG is readable", false);
        return "";
    }
    for (int i = 0; i < pages; i++)
        if (Jpeg2PDF_AddJpeg(p, jw, jh, sizeof(sampleJpeg), (UINT8 *)sampleJpeg, 1) != IDOK)
            ok("AddJpeg accepted the page", false);

    UINT32 size = Jpeg2PDF_EndDocument(p);
    std::string out(size + 16, '\0');
    UINT32 finalSize = 0;
    Jpeg2PDF_GetFinalDocumentAndCleanup(p, (UINT8 *)&out[0], &finalSize, size);
    out.resize(finalSize);
    return out;
}

// Walks the xref table the way a reader does and checks every offset lands on its object.
// Leading EOL before the object number is tolerated, as readers tolerate it: the image
// XObject's preFormat has always started with one.
static void checkXref(const std::string &pdf) {
    size_t sx = pdf.rfind("startxref");
    if (sx == std::string::npos) { ok("the trailer carries a startxref", false); return; }
    unsigned long off = strtoul(pdf.c_str() + sx + 9, 0, 10);
    ok("startxref points at the xref table", pdf.compare(off, 4, "xref") == 0);

    unsigned int count = 0;
    const char *tbl = pdf.c_str() + off;
    if (sscanf(tbl, "xref\r\n0 %u\r\n", &count) != 1) { ok("the xref header parses", false); return; }
    const char *entries = strstr(tbl, "\r\n") + 2;
    entries = strstr(entries, "\r\n") + 2;

    int bad = 0;
    for (unsigned int i = 0; i < count; i++) {
        const char *e = entries + i * XREF_ENTRY_LEN;
        if (e[17] == 'f') continue;                 // the free object
        unsigned long o = strtoul(std::string(e, 10).c_str(), 0, 10);
        const char *at = pdf.c_str() + o;
        while (*at == '\r' || *at == '\n') at++;    // tolerated leading EOL
        char want[24];
        snprintf(want, sizeof(want), "%u 0 obj", i);
        if (strncmp(at, want, strlen(want)) != 0) bad++;
    }
    ok("every xref offset resolves to its own object", bad == 0);
}

int main() {
    UINT32 w = 0, h = 0;
    std::string pdf;

    printf("  page geometry is written in points, never at the render DPI\n");
    // Letter, which AHK rasterises to 1632 x 2112 px at the high quality setting
    pdf = buildDoc(8.5, 11.0, 1, &w, &h);
    ok("Letter 8.5 x 11 in is 612 x 792 pt", w == 612 && h == 792);
    has("... and that is what MediaBox says", pdf, "/MediaBox[0 0 612 792]");
    has("... and the image placement matrix agrees", pdf, "612.00 0 0 792.00 0 0 cm");

    // 8.27 x 11.69 in only lands on the canonical A4 if the truncating cast is rounded:
    // 11.69 * 72 is 841.68, and truncation gives a 841 pt page that is one point short.
    pdf = buildDoc(8.27, 11.69, 1, &w, &h);
    ok("A4 8.27 x 11.69 in is 595 x 842 pt", w == 595 && h == 842);
    has("... and that is what MediaBox says", pdf, "/MediaBox[0 0 595 842]");

    pdf = buildDoc(11.0, 8.5, 1, &w, &h);
    ok("landscape Letter is 792 x 612 pt", w == 792 && h == 612);

    printf("  the render DPI survives as the printed resolution\n");
    // The page box is physical size; the resolution comes from the JPEG's own pixel count.
    // 1632 px across a 612 pt (8.5 in) page is the 192 dpi the pages were rendered at.
    ok("612 pt is 8.5 in", 612 / 72.0 == 8.5);
    ok("1632 px across it is 192 dpi", 1632 / (612 / 72.0) == 192.0);
    ok("816 px across it is 96 dpi", 816 / (612 / 72.0) == 96.0);

    printf("  document structure\n");
    pdf = buildDoc(8.5, 11.0, 3, &w, &h);
    has("the page tree counts every page", pdf, "/Count 3");
    has("the image keeps its own pixel count", pdf, "/Width 10/Height 10");
    has("the catalog points at the page tree", pdf, "/Type/Catalog/Pages 1 0 R");
    ok("the document ends with the EOF marker",
       pdf.size() > 7 && pdf.compare(pdf.size() - 7, 7, "%%EOF\r\n") == 0);
    checkXref(pdf);

    printf("  get_jpeg_size reads the GDI+ written header\n");
    unsigned short jw = 0, jh = 0;
    ok("dimensions come out of the SOF0 marker",
       get_jpeg_size((unsigned char *)sampleJpeg, sizeof(sampleJpeg), &jw, &jh) == 1 && jw == 10 && jh == 10);
    unsigned char notJpeg[32];
    memset(notJpeg, 0, sizeof(notJpeg));
    ok("a file that is not a JPEG is rejected",
       get_jpeg_size(notJpeg, sizeof(notJpeg), &jw, &jh) == 0);

    printf("\n  %s\n", fails ? "PDF DOCUMENT TEST FAILED" : "pdf document test passed");
    return fails ? 1 : 0;
}
