// pdfium-reader.h
//
// PDF files through PDFium: the bookmarks, the text and the pages as GDI+ bitmaps, one
// call at a time under pdfiumMutex.
//
// #included by qpv-main.cpp after wic-loader.h, whose adaptImageGivenSize() it uses, and
// ahead of thumbs-pool.h and dupes-pixels.h, which render pages through
// coreRenderPdfPageAsBitmap() under the same mutex.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_PDFIUM_READER_H
#define QPV_PDFIUM_READER_H

#include <algorithm>
#include <chrono>
#include <cstring>
#include <mutex>
#include <string>
#include <unordered_set>
#include <vector>

void AppendUInt(std::vector<unsigned short>& out, unsigned int n) {
    // Helper: Append an unsigned integer as ASCII digits.
    // Use std::to_string to convert the number then push each digit.
    std::string s = std::to_string(n);
    for (char c : s) {
        out.push_back(static_cast<unsigned short>(c));
    }
}

void AppendCounters(std::vector<unsigned short>& out, const std::vector<unsigned int>& counters) {
    // Helper: Append a numbering chain from a vector of counters, e.g., "2.3.5. ".
    // Each number is appended followed by a dot, then a space after the complete chain.
    for (unsigned int num : counters) {
        AppendUInt(out, num);
        out.push_back('.');
    }
    if (!counters.empty()) {
        out.push_back(' ');
    }
}

void TraverseBookmarks(FPDF_DOCUMENT doc, FPDF_BOOKMARK bookmark,
                       std::vector<unsigned short>& out,
                       const std::vector<unsigned int>& parentCounters,
                       std::unordered_set<FPDF_BOOKMARK>& visited) {

// Recursive helper function to traverse the bookmark tree.
// 'parentCounters' holds the numbering from parent bookmarks.
// PDFium does not stop an outline whose /First or /Next leads back to an earlier item: each
// item is listed once, and the item count and the depth are capped

    unsigned int siblingCounter = 1;
    while (bookmark)
    {
        if (visited.size()>=50000 || !visited.insert(bookmark).second)
           return;

        // Build the current numbering chain: parent's counters + current sibling counter.
        std::vector<unsigned int> currentCounters = parentCounters;
        currentCounters.push_back(siblingCounter);

        // Retrieve the bookmark title (UTF‑16 data).
        unsigned long titleLen = FPDFBookmark_GetTitle(bookmark, nullptr, 0);
        std::vector<unsigned short> titleVec;
        if (titleLen > 0) {
            titleVec.resize(titleLen);
            FPDFBookmark_GetTitle(bookmark, titleVec.data(), titleLen);
        }
        
        // Retrieve the destination page number.
        int pageNumber = 0;
        FPDF_ACTION action = FPDFBookmark_GetAction(bookmark);
        if (action)
        {
            unsigned long type = FPDFAction_GetType(action);
            FPDF_DEST dest = FPDFAction_GetDest(doc, action);
            if (dest && type == PDFACTION_GOTO)
               pageNumber = FPDFDest_GetDestPageIndex(doc, dest);
        } else 
        {
           FPDF_DEST dest = FPDFBookmark_GetDest(doc, bookmark);
           if (dest)
              pageNumber = FPDFDest_GetDestPageIndex(doc, dest);
        }
        if (pageNumber<1)
           pageNumber = 0;

        AppendUInt(out, pageNumber);
        out.push_back('|');

        AppendCounters(out, currentCounters);   // Appends the numbering chain.
        for (unsigned short ch : titleVec) {
            // Append the bookmark title.
            if (ch!=0 && ch!=NULL)
               out.push_back(ch);
        }
        out.push_back('\n');

        // Recurse into any child bookmarks.
        FPDF_BOOKMARK child = FPDFBookmark_GetFirstChild(doc, bookmark);
        if (child && currentCounters.size()<256)
           TraverseBookmarks(doc, child, out, currentCounters, visited);
        
        // Move to the next sibling.
        siblingCounter++;
        bookmark = FPDFBookmark_GetNextSibling(doc, bookmark);
   }
}

// PDFium serves one call at a time in the whole process. The pools' workers wait for it;
// the exports AHK calls give up after pdfiumWaitMs with pdfiumBusy, so a render that does
// not end cannot freeze the interface
static std::timed_mutex pdfiumMutex;
static const int pdfiumWaitMs = 15000;
static const int pdfiumBusy = -8;

DLL_API unsigned short* DLL_CALLCONV ExtractPDFBookmarks(const wchar_t *pdfPath, const wchar_t *password, int* pageCount, int* errorType, int* bufferSize) {
// Main function that loads the PDF, traverses bookmarks, and returns the data
// in an unsigned short buffer (UTF‑16 encoded).
// The output is a series of lines formatted as:
// "page number | parentCounters.currentCounter. bookmark title\n"
// The caller must free the returned buffer

    *errorType = 0;
    std::unique_lock<std::timed_mutex> pdfLock(pdfiumMutex, std::chrono::milliseconds(pdfiumWaitMs));
    if (!pdfLock.owns_lock())
    {
        *errorType = pdfiumBusy;
        return NULL;
    }

    FPDF_DOCUMENT doc = FPDF_LoadDocument(WideCharToString(pdfPath).c_str(), WideCharToString(password).c_str());
    if (!doc)
    {
        *errorType = FPDF_GetLastError();
        return NULL;
    }

    std::vector<unsigned short> out;
    *pageCount = FPDF_GetPageCount(doc);
    if (*pageCount<3)
    {
        FPDF_CloseDocument(doc);
        return NULL;
    }

    FPDF_BOOKMARK root = FPDFBookmark_GetFirstChild(doc, nullptr);
    if (root)
    {
        std::vector<unsigned int> emptyChain;  // At root level, no parent numbering.
        std::unordered_set<FPDF_BOOKMARK> visited;
        TraverseBookmarks(doc, root, out, emptyChain, visited);
    } else
    {
        *errorType = -2;
        FPDF_CloseDocument(doc);
        return NULL;
    }

    // Allocate an unsigned short buffer with space for a null terminator.
    unsigned short* buffer = new unsigned short[out.size() + 1];
    std::memcpy(buffer, out.data(), out.size() * sizeof(unsigned short));
    buffer[out.size()] = 0;  // Null terminate.
    *bufferSize = out.size() + 1;    
    FPDF_CloseDocument(doc);
    return buffer;
}

DLL_API int DLL_CALLCONV RenderPdfPageAsText(const wchar_t *pdfPath, int *givenIndex, int *pages, const wchar_t* password, unsigned short* textBuffer, int *bufferSize) {
    std::unique_lock<std::timed_mutex> pdfLock(pdfiumMutex, std::chrono::milliseconds(pdfiumWaitMs));
    if (!pdfLock.owns_lock())
       return pdfiumBusy;

    int errorType = 0;
    FPDF_DOCUMENT document = FPDF_LoadDocument(WideCharToString(pdfPath).c_str(), WideCharToString(password).c_str());
    if (!document)
    {
        errorType = FPDF_GetLastError();
        if (errorType==4)
           QPV_DBG("failed to load PDF document: incorrect password " + std::to_string(errorType));
        else
           QPV_DBG("failed to load PDF document: " + std::to_string(errorType) );

        return errorType;
    }

    int pageCount = FPDF_GetPageCount(document);
    if (pageCount<=0)
    {
       QPV_DBG("failed to load PDF: no pages found");
       errorType = -2;
       FPDF_CloseDocument(document);
       return errorType;
    }

    // if (permissions == (unsigned long)-1)
    //    std::cout << "Document is not encrypted, all permissions granted.\n";
    // if (permissions & 0x0004) std::cout << " - Printing Allowed\n";
    // if (permissions & 0x0008) std::cout << " - Modifying Allowed\n";
    if (*givenIndex==-1)
    {
       unsigned long permissions = FPDF_GetDocPermissions(document);
       QPV_DBG("perms=" + std::to_string(permissions));
       if (!(permissions & 0x0010))
          *givenIndex = 1; // copy not allowed

       *pages = pageCount;
       FPDF_CloseDocument(document);
       return errorType;
    }

    *pages = pageCount;
    int pageIndex = std::clamp(*givenIndex, 0, pageCount - 1);
    FPDF_PAGE PDFpage = FPDF_LoadPage(document, pageIndex);
    if (PDFpage)
    {
       FPDF_TEXTPAGE textPage = FPDFText_LoadPage(PDFpage);
       if (textPage)
       {
          UINT textLength = FPDFText_CountChars(textPage);
          if (textBuffer!=NULL)
          {
             UINT extracted = 0;
             UINT err = 0;
             if (textLength>2)
             {
                for (UINT i = 0; i < textLength; ++i)
                {
                    int p = FPDFText_HasUnicodeMapError(textPage, i);
                    err += abs(p);
                }

                if (textLength<15 || ( (float)err / (float)textLength < 0.8) )
                   extracted = FPDFText_GetText(textPage, 0, textLength, textBuffer);
                else
                   errorType = -7;
             }

             *bufferSize = extracted;
             // fnOutputDebug("unicode errors = " + std::to_string(err) + " /  " + std::to_string(textLength));
          } else
          {
             textLength += FPDFPage_CountObjects(PDFpage);
             *bufferSize = textLength;
          }

          FPDFText_ClosePage(textPage);
       } else {
          errorType = -6;
       }
       FPDF_ClosePage(PDFpage);
    } else {
       errorType = -3;
    }

    FPDF_CloseDocument(document);
    return errorType;
}

static Gdiplus::GpBitmap* coreRenderPdfPageAsBitmap(const wchar_t *pdfPath, int pageIndex, float dpi, int* givenW, int* givenH, int fillBehind, int bgrColor, int *varOut, int *errorType, const wchar_t* password, int do24bits) {
// https://github.com/bblanchon/pdfium-binaries
// the caller holds pdfiumMutex
    int act = *varOut;
    *errorType = 0;
    // act == -1; retrieve the total page count 
    // act == -2; retrieve the width and height of on a given page and total page count
    // errorType > 0; error codes from PDFium
    // errorType = -2; PDF seems to have no pages
    // errorType = -3; failed to retrieve PDF page from document 
    // errorType = -4; failed to allocate or lock the GDI+ bitmap
    // errorType = -5; failed to create the FPDF bitmap to render PDF
    // errorType = -6; failed to retrieve PDF text page from PDF page 
    // errorType = -8; [pdfiumBusy] RenderPdfPageAsBitmap() did not get pdfiumMutex in time

    Gdiplus::GpBitmap *myBitmap = NULL;
    FPDF_DOCUMENT document = FPDF_LoadDocument(WideCharToString(pdfPath).c_str(), WideCharToString(password).c_str());
    if (!document)
    {
        *errorType = FPDF_GetLastError();
        if (*errorType==4)
           QPV_DBG("failed to load PDF document: incorrect password " + std::to_string(*errorType));
        else
           QPV_DBG("failed to load PDF document: " + std::to_string(*errorType) );

        return myBitmap;
    }

    int pageCount = FPDF_GetPageCount(document);
    if (pageCount<=0 || act==-1)
    {
        if (pageCount<=0)
        {
           QPV_DBG("failed to load PDF: no pages found");
           *errorType = -2;
        }
        *varOut = pageCount;
        FPDF_CloseDocument(document);
        return myBitmap;
    }
    
    *varOut = pageCount;
    pageIndex = std::clamp(pageIndex, 0, pageCount - 1);
    FPDF_PAGE PDFpage = FPDF_LoadPage(document, pageIndex);
    if (!PDFpage) {
        QPV_DBG("failed to load PDF page");
        FPDF_CloseDocument(document);
        *errorType = -3;
        return myBitmap;
    }

    int ScaleAnySize = (dpi<0) ? 1 : 0;
    dpi = abs(dpi);
    float scale = (dpi<2) ? 1.0f : dpi / 72.0f;  // PDF uses 72 DPI as base
    double pageWidth = FPDF_GetPageWidth(PDFpage);
    double pageHeight = FPDF_GetPageHeight(PDFpage);
    int bitmapWidth = (float)pageWidth * scale;
    int bitmapHeight = (float)pageHeight * scale;
    if (act==-2)
    {
       *varOut = pageCount;
       *givenW = (int)pageWidth;
       *givenH = (int)pageHeight;
       FPDF_ClosePage(PDFpage);
       FPDF_CloseDocument(document);
       return myBitmap;
    }

    if (*givenW<2)
       *givenW = 32650;
    if (*givenH<2)
       *givenH = 32650;

    float maxMPX = (do24bits==1) ? 715.25f : 536.45f;
    auto nSize = adaptImageGivenSize(1, ScaleAnySize, bitmapWidth, bitmapHeight, *givenW, *givenH, maxMPX);
    bitmapWidth = (dpi==0) ? *givenW : nSize[0];
    bitmapHeight = (dpi==0) ? *givenH : nSize[1];
    *givenW = (int)pageWidth;
    *givenH = (int)pageHeight;
    int cbStride = (do24bits==1) ? bitmapWidth * 3 : bitmapWidth * 4;
    Gdiplus::PixelFormat destinationGdipFormat = (do24bits==1) ? PixelFormat24bppRGB : PixelFormat32bppPARGB;
    Gdiplus::DllExports::GdipCreateBitmapFromScan0(bitmapWidth, bitmapHeight, cbStride, destinationGdipFormat, NULL, &myBitmap);
    if (myBitmap==NULL)
    {
       QPV_DBG("failed to load PDF page; unable to allocate the GDI+ bitmap: " + std::to_string(bitmapWidth) + " x " + std::to_string(bitmapHeight));
       FPDF_ClosePage(PDFpage);
       FPDF_CloseDocument(document);
       *errorType = -4;
       return myBitmap;
    }

    Gdiplus::BitmapData bitmapDatu;
    Gdiplus::Rect rect(0, 0, bitmapWidth, bitmapHeight);
    destinationGdipFormat = (do24bits==1) ? PixelFormat24bppRGB : PixelFormat32bppARGB;
    // locking the PARGB bitmap as ARGB takes a second full-size buffer, so this can fail where the bitmap did not
    if (Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rect, Gdiplus::ImageLockModeWrite, destinationGdipFormat, &bitmapDatu)!=Gdiplus::Ok)
    {
       QPV_DBG("failed to load PDF page; unable to lock the GDI+ bitmap: " + std::to_string(bitmapWidth) + " x " + std::to_string(bitmapHeight));
       Gdiplus::DllExports::GdipDisposeImage(myBitmap);
       FPDF_ClosePage(PDFpage);
       FPDF_CloseDocument(document);
       *errorType = -4;
       return NULL;
    }

    int PDFcolorFormat = (do24bits==1) ? FPDFBitmap_BGR : FPDFBitmap_BGRA;
    // Create bitmap for PDFium to render into over the GDI+ Scan0
    FPDF_BITMAP pdfBitmap = FPDFBitmap_CreateEx(bitmapWidth, bitmapHeight, PDFcolorFormat, bitmapDatu.Scan0, bitmapDatu.Stride);
    if (pdfBitmap)
    {
        if (fillBehind==1)
           FPDFBitmap_FillRect(pdfBitmap, 0, 0, bitmapWidth, bitmapHeight, bgrColor);

        FPDF_RenderPageBitmap(pdfBitmap, PDFpage, 0, 0, bitmapWidth, bitmapHeight, 0, FPDF_ANNOT);
        FPDFBitmap_Destroy(pdfBitmap);
        Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
    } else
    {
        *errorType = -5;
        QPV_DBG("failed to create the FPDF bitmap to render PDF");
        Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
        Gdiplus::DllExports::GdipDisposeImage(myBitmap);
        myBitmap = NULL;
    }

    FPDF_ClosePage(PDFpage);
    FPDF_CloseDocument(document);
    return myBitmap;
}; // coreRenderPdfPageAsBitmap

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV RenderPdfPageAsBitmap(const wchar_t *pdfPath, int pageIndex, float dpi, int* givenW, int* givenH, int fillBehind, int bgrColor, int *varOut, int *errorType, const wchar_t* password, int do24bits) {
    std::unique_lock<std::timed_mutex> pdfLock(pdfiumMutex, std::chrono::milliseconds(pdfiumWaitMs));
    if (!pdfLock.owns_lock())
    {
        *errorType = pdfiumBusy;
        return NULL;
    }

    return coreRenderPdfPageAsBitmap(pdfPath, pageIndex, dpi, givenW, givenH, fillBehind, bgrColor, varOut, errorType, password, do24bits);
}

#endif // QPV_PDFIUM_READER_H
