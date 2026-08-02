// thumbs-pool.h
//
// Multi-threaded thumbnails generator, entirely managed in C++.
// QPV_ShowThumbnails() submits jobs, polls a shared status block and
// fetches finished GDI+ bitmaps that it owns.
//
// Usage from AHK:
//    thumbsPoolInit(nThreads)                  once per process
//    thumbsPoolSetFormats(wicExts, fimExts)    once, after initQPVmainDLL()
//    thumbsPoolGetState()                      pointer polled with NumGet()
//    thumbsPoolBegin(packedOptions)            per thumbnails run
//    thumbsPoolSubmit(id, kind, src, dst, frame)
//    thumbsPoolFetch(buffer, maxItems)
//    thumbsPoolCancel() / thumbsPoolEnd() / thumbsPoolShutdown()
//
// This file is #included by qpv-main.cpp after LoadSVGimage(), so it can use
// adaptImageGivenSize(), indexedWICcontainerFormats(), decideWICtoFIMpixelFormat(),
// IsFileExtension(), LoadSVGimage(), RenderPdfPageAsBitmap(), openCVresizeBitmapExtended()
// and openCVapplyToneMappingAlgos() directly.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_THUMBS_POOL_H
#define QPV_THUMBS_POOL_H

#include <thread>
#include <chrono>
#include <mutex>
#include <condition_variable>
#include <deque>
#include <memory>
#include <regex>
#include <cmath>
#include <cctype>
#include <cwctype>
#include <cstdlib>
#include <cstdio>
#include "freeimage-dynamic.h"

// ---------------------------------------------------------------------------------------
//  data exchanged with AHK
// ---------------------------------------------------------------------------------------

#define TP_JOB_THUMB      0   // build a thumbnail out of the original image file
#define TP_JOB_LOADCACHE  1   // decode an already cached thumbnail file, at its native size

#define TP_OK              0
#define TP_ERR_LOAD        1
#define TP_ERR_RESIZE      2
#define TP_ERR_CONVERT     3
#define TP_ERR_TONEMAP     4
#define TP_ERR_UNSUPPORTED 5
#define TP_ERR_PDFLOCKED  20  // QPV_ShowThumbnails() must not mark these files as dead

#define TP_MAX_READY      48  // undelivered results allowed before workers park
#define TP_MAX_READY_BYTES (48ull*1024*1024)  // ... and the memory they may hold on to

// Memory pressure. Above either of these the pool narrows down to a single running job,
// so that images keep coming - slowly - instead of everything grinding to a halt.
// The percentage mirrors what QPV_ShowThumbnails() used to test on every iteration of its
// inner loop; the absolute floor matters on machines where 10% of the RAM is still plenty.
#define TP_MEM_LOAD_HIGH   90
#define TP_MEM_FREE_FLOOR  (768ull*1024*1024)
#define TP_MEM_SAMPLE_MS   250

#pragma pack(push, 8)
struct ThumbResult {          // 48 bytes; AHK reads the fields with NumGet()
    INT64 jobId;              //  0
    void* pBitmap;            //  8   GpBitmap*; ownership is transfered to AHK
    int   status;             // 16
    int   savedToFile;        // 20
    int   srcW;               // 24
    int   srcH;               // 28
    int   outW;               // 32
    int   outH;               // 36
    int   elapsedMs;          // 40
    int   loaderUsed;         // 44   1=WIC 2=FreeImage 3=SVG 4=PDF 5=cached file
};

struct ThumbsPoolState {      // read-only for AHK
    volatile LONG queued;     //  0
    volatile LONG inFlight;   //  4
    volatile LONG ready;      //  8
    volatile LONG completed;  // 12
    volatile LONG failed;     // 16
    volatile LONG generation; // 20
    volatile LONG alive;      // 24
    volatile LONG memTight;   // 28   1 while the pool is throttled down to a single job
    volatile LONG activeJobs; // 32   images being decoded right now
    volatile LONG readyKB;    // 36   memory held by results nobody collected yet
};
#pragma pack(pop)

struct ThumbsConfig {
    int   thumbSize        = 250;
    int   timePerImg       = 25;
    int   enableCaching    = 1;
    int   userHQraw        = 1;
    int   allowToneMapping = 1;
    int   allowWIC         = 1;
    int   allowFIM         = 1;
    int   imgQuality       = 5;
    int   toneMapAlgo      = 0;
    float tmParamA         = 0.0f;
    float tmParamB         = 0.0f;
    float tmParamC         = 0.0f;
    float tmParamD         = 0.0f;
    float tmOCVparamA      = 0.0f;
    float tmOCVparamB      = 0.0f;
    int   tmAltExpo        = 0;
    int   wantBitmap       = 1;
    int   alwaysSave       = 0;
};

struct ThumbJob {
    INT64        jobId     = 0;
    int          kind      = TP_JOB_THUMB;
    int          frameIndex = 0;
    LONG         generation = 0;
    std::wstring src;
    std::wstring dst;
    std::shared_ptr<const ThumbsConfig> cfg;
};

// ---------------------------------------------------------------------------------------
//  pool state
// ---------------------------------------------------------------------------------------

static std::vector<std::thread>          tpWorkers;
static std::deque<ThumbJob>              tpQueue;
static std::deque<ThumbResult>           tpResults;
static std::mutex                        tpMutex;
static std::condition_variable           tpJobCV;
static std::condition_variable           tpExitCV;        // a worker announces it is leaving
static std::mutex                        tpPdfMutex;      // PDFium is not thread safe
static std::atomic<bool>                 tpStopping{false};
static std::atomic<LONG>                 tpGeneration{1};
static std::shared_ptr<const ThumbsConfig> tpConfig = std::make_shared<ThumbsConfig>();
static std::unordered_set<std::wstring>  tpWicExts;
static std::unordered_set<std::wstring>  tpFimExts;
static ThumbsPoolState                   tpState = {0, 0, 0, 0, 0, 1, 0, 0, 0, 0};
static int                               tpPrevCVthreads = -1;
static std::atomic<LONG>                 tpActiveJobs{0};
static std::atomic<LONG>                 tpMemTight{0};
static std::atomic<ULONGLONG>            tpMemStamp{0};
static ULONGLONG                         tpReadyBytes = 0;   // guarded by tpMutex
static size_t                            tpExited = 0;       // guarded by tpMutex

// ---------------------------------------------------------------------------------------
//  small helpers
// ---------------------------------------------------------------------------------------

static std::wstring tpLowerCase(const std::wstring &s) {
    std::wstring r = s;
    for (size_t i = 0; i < r.size(); i++)
        r[i] = (wchar_t)towlower(r[i]);
    return r;
}

static std::wstring tpFileExtension(const std::wstring &path) {
    size_t dot = path.find_last_of(L'.');
    size_t sep = path.find_last_of(L"\\/");
    if (dot==std::wstring::npos || (sep!=std::wstring::npos && dot<sep))
       return L"";
    return tpLowerCase(path.substr(dot + 1));
}

static void tpSplitExtensions(const wchar_t *list, std::unordered_set<std::wstring> &dest) {
    dest.clear();
    if (!list)
       return;

    std::wstring cur;
    for (const wchar_t *p = list; ; p++)
    {
        if (*p==L'|' || *p==L',' || *p==L';' || *p==0)
        {
           if (!cur.empty())
           {
              if (cur[0]==L'.')
                 cur.erase(0, 1);
              if (!cur.empty())
                 dest.insert(tpLowerCase(cur));
           }
           cur.clear();
           if (*p==0)
              break;
        } else if (*p!=L' ' && *p!=L'*')
           cur.push_back(*p);
    }
}

// mirrors calcIMGdimensions() of module-fim-thumbs.ahk; it also enlarges images
// smaller than the thumbnail box, exactly like the AHK original did
static void tpCalcIMGdimensions(int imgW, int imgH, int givenW, int givenH, int &resizedW, int &resizedH) {
    if (imgW<1 || imgH<1 || givenW<1 || givenH<1)
    {
       resizedW = max(1, imgW);
       resizedH = max(1, imgH);
       return;
    }

    const double picRatio   = floor(((double)imgW/imgH)*100000.0 + 0.5)/100000.0;
    const double givenRatio = floor(((double)givenW/givenH)*100000.0 + 0.5)/100000.0;
    if (imgW<=givenW && imgH<=givenH)
    {
       resizedW = givenW;
       resizedH = (int)floor(resizedW/picRatio + 0.5);
       if (resizedH>givenH)
       {
          resizedH = (imgH<=givenH) ? givenH : imgH;
          resizedW = (int)floor(resizedH*picRatio + 0.5);
       }
    } else if (picRatio>givenRatio)
    {
       resizedW = givenW;
       resizedH = (int)floor(resizedW/picRatio + 0.5);
    } else
    {
       resizedH = (imgH>=givenH) ? givenH : imgH;
       resizedW = (int)floor(resizedH*picRatio + 0.5);
    }

    resizedW = max(1, resizedW);
    resizedH = max(1, resizedH);
}

// PNG encoder CLSID; resolved statically instead of enumerating every GDI+ encoder per save,
// the way Gdip_SaveBitmapToFile() used to do in each ahk_h thread
static const CLSID tpPngEncoderCLSID = {0x557cf406, 0x1a04, 0x11d3, {0x9a, 0x73, 0x00, 0x00, 0xf8, 0x1e, 0xf3, 0x2e}};

static int tpSavePngGdip(Gdiplus::GpBitmap *bmp, const std::wstring &path) {
    if (!bmp || path.empty())
       return 0;

    // written aside then moved over, so that an interrupted save cannot leave behind a
    // truncated file that checkThumbExists() would happily serve later on
    std::wstring temp = path + L".tmp";
    Gdiplus::Status st = Gdiplus::DllExports::GdipSaveImageToFile(bmp, temp.c_str(), &tpPngEncoderCLSID, NULL);
    if (st!=Gdiplus::Ok)
    {
       DeleteFileW(temp.c_str());
       fnOutputDebug("thumbsPool: failed to save thumbnail: " + WideCharToString(path.c_str()));
       return 0;
    }

    if (!MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING))
    {
       DeleteFileW(temp.c_str());
       return 0;
    }
    return 1;
}

// Encodes the thumbnail with WIC instead of GDI+. GDI+ holds process wide locks in its
// engine, so several workers saving at once end up taking turns; WIC has no such lock and
// each worker owns its factory. The pixels are unchanged: locking the bitmap as 32bppARGB
// makes GDI+ perform the very same un-premultiply its own PNG encoder does, so what WIC
// compresses is byte for byte what GDI+ would have compressed. Only the deflate stream of
// the resulting file differs, and PNG is lossless
static int tpSavePngWIC(IWICImagingFactory *fac, Gdiplus::GpBitmap *bmp, const std::wstring &path) {
    if (!fac || !bmp || path.empty())
       return 0;

    UINT w = 0, h = 0;
    Gdiplus::DllExports::GdipGetImageWidth(bmp, &w);
    Gdiplus::DllExports::GdipGetImageHeight(bmp, &h);
    if (w<1 || h<1)
       return 0;

    Gdiplus::PixelFormat srcFmt = 0;
    Gdiplus::DllExports::GdipGetImagePixelFormat(bmp, &srcFmt);
    const bool opaque24 = (srcFmt==PixelFormat24bppRGB);
    const Gdiplus::PixelFormat lockFmt = opaque24 ? PixelFormat24bppRGB : PixelFormat32bppARGB;
    WICPixelFormatGUID wantFmt = opaque24 ? GUID_WICPixelFormat24bppBGR : GUID_WICPixelFormat32bppBGRA;

    Gdiplus::BitmapData bitmapDatu;
    Gdiplus::Rect rectu(0, 0, (INT)w, (INT)h);
    if (Gdiplus::DllExports::GdipBitmapLockBits(bmp, &rectu, Gdiplus::ImageLockModeRead, lockFmt, &bitmapDatu)!=Gdiplus::Ok)
       return 0;

    // a bottom-up bitmap answers with a negative stride, which WritePixels() cannot take;
    // every bitmap reaching this point is top-down, but the GDI+ encoder handles either
    if (bitmapDatu.Stride<1 || bitmapDatu.Scan0==NULL)
    {
       Gdiplus::DllExports::GdipBitmapUnlockBits(bmp, &bitmapDatu);
       return 0;
    }

    // written aside then moved over, so that an interrupted save cannot leave behind a
    // truncated file that checkThumbExists() would happily serve later on
    const std::wstring temp = path + L".tmp";
    IWICStream            *pStream = NULL;
    IWICBitmapEncoder     *pEnc    = NULL;
    IWICBitmapFrameEncode *pFrame  = NULL;
    IPropertyBag2         *pProps  = NULL;
    int done = 0;

    HRESULT hr = fac->CreateStream(&pStream);
    if (SUCCEEDED(hr))
       hr = pStream->InitializeFromFilename(temp.c_str(), GENERIC_WRITE);
    if (SUCCEEDED(hr))
       hr = fac->CreateEncoder(GUID_ContainerFormatPng, NULL, &pEnc);
    if (SUCCEEDED(hr))
       hr = pEnc->Initialize(pStream, WICBitmapEncoderNoCache);
    if (SUCCEEDED(hr))
       hr = pEnc->CreateNewFrame(&pFrame, &pProps);
    if (SUCCEEDED(hr))
       hr = pFrame->Initialize(pProps);
    if (SUCCEEDED(hr))
       hr = pFrame->SetSize(w, h);
    if (SUCCEEDED(hr))
    {
       WICPixelFormatGUID gotFmt = wantFmt;
       hr = pFrame->SetPixelFormat(&gotFmt);

       // SetPixelFormat() answers with the nearest format the encoder supports; PNG takes
       // both of ours, so anything else means this build cannot serve us. Rather than
       // inserting a converter, let the caller fall back to the GDI+ encoder
       if (SUCCEEDED(hr) && !(gotFmt==wantFmt))
          hr = E_FAIL;
    }

    if (SUCCEEDED(hr))
       hr = pFrame->WritePixels(h, (UINT)bitmapDatu.Stride, (UINT)bitmapDatu.Stride*h, (BYTE*)bitmapDatu.Scan0);
    if (SUCCEEDED(hr))
       hr = pFrame->Commit();
    if (SUCCEEDED(hr))
       hr = pEnc->Commit();

    done = SUCCEEDED(hr) ? 1 : 0;
    SafeRelease(pProps, "tpSavePngWIC: pProps", 0);
    SafeRelease(pFrame, "tpSavePngWIC: pFrame", 0);
    SafeRelease(pEnc, "tpSavePngWIC: pEnc", 0);

    // the stream keeps the file open; it must go before the file can be moved
    SafeRelease(pStream, "tpSavePngWIC: pStream", 0);
    Gdiplus::DllExports::GdipBitmapUnlockBits(bmp, &bitmapDatu);

    if (done==1 && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING))
       return 1;

    DeleteFileW(temp.c_str());
    return 0;
}

// WIC first, GDI+ as the safety net; a thumbnail that cannot be written at all would be
// regenerated from scratch on every visit to its folder
static int tpSavePng(IWICImagingFactory *fac, Gdiplus::GpBitmap *bmp, const std::wstring &path) {
    if (tpSavePngWIC(fac, bmp, path)==1)
       return 1;

    return tpSavePngGdip(bmp, path);
}

static int tpSavePngFIM(FIBITMAPptr dib, const std::wstring &path) {
    if (!FIM.ok || !FIM.SaveU || !dib || path.empty())
       return 0;

    std::wstring temp = path + L".tmp";
    if (!FIM.SaveU(FIF_PNG, dib, temp.c_str(), 0))
    {
       DeleteFileW(temp.c_str());
       return 0;
    }

    if (!MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING))
    {
       DeleteFileW(temp.c_str());
       return 0;
    }
    return 1;
}

// One shared memory sample for the whole pool, refreshed a few times per second. It
// replaces the GetProcessMemoryUsage() + GlobalMemoryStatusEx() pair QPV_ShowThumbnails()
// used to perform on every single iteration of its inner loop, in the calling thread.
static bool tpMemoryIsTight() {
    const ULONGLONG now = GetTickCount64();
    if (now - tpMemStamp.load(std::memory_order_relaxed) > TP_MEM_SAMPLE_MS)
    {
       MEMORYSTATUSEX ms;
       ms.dwLength = sizeof(ms);
       if (GlobalMemoryStatusEx(&ms))
       {
          const bool tight = (ms.dwMemoryLoad>=TP_MEM_LOAD_HIGH) || (ms.ullAvailPhys<TP_MEM_FREE_FLOOR);
          tpMemTight.store(tight ? 1 : 0, std::memory_order_relaxed);
          tpState.memTight = tight ? 1 : 0;
       }
       tpMemStamp.store(now, std::memory_order_relaxed);
    }

    return tpMemTight.load(std::memory_order_relaxed)!=0;
}

// Takes a slot to decode one image. While memory is plentiful every worker gets one
// straight away. When it is not, only the worker that finds no other job running may take
// one: the pool narrows down to a single decode at a time rather than stalling altogether,
// so thumbnails keep arriving - slowly - and QPV_ShowThumbnails() never waits forever.
// Returns false only when the pool is shutting down, in which case the job is dropped.
// There is no timeout: a worker that finds nothing else running is always let through, so
// the queue can never wedge, no matter how long memory stays scarce.
static bool tpAcquireJobSlot() {
    for (;;)
    {
        if (tpStopping.load())
           return false;

        LONG active = tpActiveJobs.load(std::memory_order_acquire);
        if (active<1 || !tpMemoryIsTight())
        {
           if (tpActiveJobs.compare_exchange_weak(active, active + 1, std::memory_order_acq_rel))
           {
              tpState.activeJobs = active + 1;
              return true;
           }
           continue;   // somebody else moved first, look again
        }

        // wait for the image being decoded right now to release its memory
        std::this_thread::sleep_for(std::chrono::milliseconds(25));
    }
}

static void tpReleaseJobSlot() {
    LONG active = tpActiveJobs.fetch_sub(1, std::memory_order_acq_rel) - 1;
    tpState.activeJobs = (active>0) ? active : 0;
}

static ULONGLONG tpResultBytes(const ThumbResult &res) {
    if (res.pBitmap==NULL || res.outW<1 || res.outH<1)
       return 0;

    return (ULONGLONG)res.outW * (ULONGLONG)res.outH * 4ull;
}

// ---------------------------------------------------------------------------------------
//  WIC loader
// ---------------------------------------------------------------------------------------

// Decodes szFileName and returns a 32bppPARGB GDI+ bitmap.
// When targetW/targetH are below 2 the image is decoded at its native size; otherwise the
// WIC scaler is initialized straight to the thumbnail size, which lets the JPEG / HEIF /
// JPEG-XR decoders perform a scaled decode through IWICBitmapSourceTransform instead of
// unpacking the full resolution image only to shrink it afterwards.
static Gdiplus::GpBitmap* tpWICload(IWICImagingFactory *fac, const wchar_t *szFileName, int targetW, int targetH,
                                    int frameIndex, int givenQuality, int isFIMokay, int &srcW, int &srcH) {
    Gdiplus::GpBitmap     *myBitmap    = NULL;
    IWICBitmapDecoder     *pDecoder    = NULL;
    IWICBitmapFrameDecode *pFrame      = NULL;
    IWICBitmapScaler      *pScaler     = NULL;
    IWICFormatConverter   *pConverter  = NULL;
    IWICBitmapSource      *pSource     = NULL;
    if (!fac || !szFileName)
       return myBitmap;

    HRESULT hr = S_OK;
    try
    {
        hr = fac->CreateDecoderFromFilename(szFileName, NULL, GENERIC_READ, WICDecodeMetadataCacheOnDemand, &pDecoder);
    } catch (const char* message)
    {
        fnOutputDebug("thumbsPool: WIC decoder error > " + std::string(message) + ". File: " + WideCharToString(szFileName));
        return myBitmap;
    }

    if (FAILED(hr))
    {
       SafeRelease(pDecoder, "tpWICload: pDecoder", 0);
       return myBitmap;
    }

    UINT tFrames = 0;
    hr = pDecoder->GetFrameCount(&tFrames);
    if (SUCCEEDED(hr))
    {
       UINT useFrame = (frameIndex>0) ? (UINT)frameIndex : 0;
       if (tFrames>0 && useFrame>=tFrames)
          useFrame = tFrames - 1;

       hr = pDecoder->GetFrame(useFrame, &pFrame);
    }

    UINT owidth = 0, oheight = 0;
    if (SUCCEEDED(hr))
       hr = pFrame->GetSize(&owidth, &oheight);

    if (SUCCEEDED(hr) && ((!owidth || !oheight) || (owidth==1 && oheight==1)))
       hr = E_FAIL;

    if (SUCCEEDED(hr))
    {
       srcW = (int)owidth;
       srcH = (int)oheight;

       // same two escape hatches as LoadWICimage(): a DNG that decoded into its embedded
       // 256x192 icon, and a high bit depth TIFF that FreeImage handles better
       GUID containerFmt;
       WICPixelFormatGUID opixelFormat = GUID_WICPixelFormatDontCare;
       if (SUCCEEDED(pDecoder->GetContainerFormat(&containerFmt)) && SUCCEEDED(pFrame->GetPixelFormat(&opixelFormat)))
       {
          UINT ucontainerFmt = indexedWICcontainerFormats(containerFmt);
          int destinationBPP = decideWICtoFIMpixelFormat(opixelFormat);
          int tif = (IsFileExtension(szFileName, L".tif")==1 || IsFileExtension(szFileName, L".tiff")==1) ? 1 : 0;
          if ((ucontainerFmt==9 && owidth==256 && oheight==192) || (tif==1 && destinationBPP>32 && isFIMokay==1))
             hr = E_FAIL;
       }
    }

    if (SUCCEEDED(hr))
    {
       pSource = pFrame;
       if (targetW>1 && targetH>1)
       {
          auto nSize = adaptImageGivenSize(1, 0, owidth, oheight, (UINT)targetW, (UINT)targetH);
          if (nSize[0]!=owidth || nSize[1]!=oheight)
          {
             if (SUCCEEDED(fac->CreateBitmapScaler(&pScaler)))
             {
                WICBitmapInterpolationMode mode = (givenQuality==7) ? WICBitmapInterpolationModeHighQualityCubic : WICBitmapInterpolationModeFant;
                HRESULT hrs = pScaler->Initialize(pFrame, nSize[0], nSize[1], mode);
                if (FAILED(hrs) && mode!=WICBitmapInterpolationModeFant)   // not available before WIC2
                   hrs = pScaler->Initialize(pFrame, nSize[0], nSize[1], WICBitmapInterpolationModeFant);

                if (SUCCEEDED(hrs))
                   pSource = pScaler;
                else
                   SafeRelease(pScaler, "tpWICload: pScaler", 0);
             }
          }
       }

       hr = fac->CreateFormatConverter(&pConverter);
       if (SUCCEEDED(hr))
          hr = pConverter->Initialize(pSource, GUID_WICPixelFormat32bppPBGRA, WICBitmapDitherTypeNone, NULL, 0.0f, WICBitmapPaletteTypeCustom);
    }

    if (SUCCEEDED(hr))
    {
       UINT width = 0, height = 0, cbStride = 0;
       hr = pConverter->GetSize(&width, &height);
       if (SUCCEEDED(hr))
          hr = UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);

       if (SUCCEEDED(hr) && width>0 && height>0)
       {
          Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, cbStride, PixelFormat32bppPARGB, NULL, &myBitmap);
          if (myBitmap!=NULL)
          {
             Gdiplus::BitmapData bitmapDatu;
             Gdiplus::Rect rectu(0, 0, width, height);
             Gdiplus::Status lockSt = Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, Gdiplus::ImageLockModeWrite, PixelFormat32bppPARGB, &bitmapDatu);
             HRESULT hrc = E_FAIL;
             if (lockSt==Gdiplus::Ok)
             {
                hrc = pConverter->CopyPixels(NULL, bitmapDatu.Stride, bitmapDatu.Stride*height, (BYTE*)bitmapDatu.Scan0);
                Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
             } else fnOutputDebug("thumbsPool: failed to lock the GDI+ bitmap for " + WideCharToString(szFileName));

             if (FAILED(hrc))
             {
                fnOutputDebug("thumbsPool: WIC failed to copy pixels for " + WideCharToString(szFileName));
                Gdiplus::DllExports::GdipDisposeImage(myBitmap);
                myBitmap = NULL;
             }
          } else fnOutputDebug("thumbsPool: failed to allocate the GDI+ bitmap for " + WideCharToString(szFileName));
       }
    }

    SafeRelease(pConverter, "tpWICload: pConverter", 0);
    SafeRelease(pScaler, "tpWICload: pScaler", 0);
    SafeRelease(pFrame, "tpWICload: pFrame", 0);
    SafeRelease(pDecoder, "tpWICload: pDecoder", 0);
    return myBitmap;
}

// ---------------------------------------------------------------------------------------
//  SVG loader; port of RenderSVGfile() / convertSVGunitsToPixels() of module-fim-thumbs.ahk
// ---------------------------------------------------------------------------------------

static std::string tpReadTextFile(const std::wstring &path, DWORD maxBytes = 1u<<20) {
    HANDLE hFile = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                               FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (hFile==INVALID_HANDLE_VALUE)
       return "";

    // only as much as the file actually holds; SVGs are usually a couple of kilobytes
    LARGE_INTEGER fileSize;
    DWORD toRead = maxBytes;
    if (GetFileSizeEx(hFile, &fileSize) && fileSize.QuadPart<(LONGLONG)maxBytes)
       toRead = (DWORD)fileSize.QuadPart;

    if (toRead<1)
    {
       CloseHandle(hFile);
       return "";
    }

    std::string data;
    data.resize(toRead);
    DWORD readBytes = 0;
    BOOL gotIt = ReadFile(hFile, &data[0], toRead, &readBytes, NULL);
    CloseHandle(hFile);
    if (!gotIt)
       return "";

    data.resize((size_t)readBytes);
    if (data.size()>=2 && (unsigned char)data[0]==0xFF && (unsigned char)data[1]==0xFE)
    {
       // UTF-16 LE; the attribute names we look for are plain ASCII either way
       const wchar_t *w = (const wchar_t*)(data.c_str() + 2);
       size_t wlen = (data.size() - 2)/sizeof(wchar_t);
       std::wstring ws(w, wlen);
       return WideCharToString(ws.c_str());
    }
    if (data.size()>=3 && (unsigned char)data[0]==0xEF && (unsigned char)data[1]==0xBB && (unsigned char)data[2]==0xBF)
       return data.substr(3);

    return data;
}

static std::string tpRetrieveXMLattribute(const std::string &content, const std::string &attrib) {
    try
    {
        std::regex rx(attrib + "=[\"']([^\"']*)[\"']", std::regex::icase);
        std::smatch m;
        if (std::regex_search(content, m, rx))
           return m[1].str();
    } catch (const std::regex_error&) { }
    return "";
}

static double tpConvertSVGunitsToPixels(std::string &length) {
    const double w = (double)GetSystemMetrics(SM_CXSCREEN);
    const double h = (double)GetSystemMetrics(SM_CYSCREEN);
    const double base = floor((w + h)/2.0 + 0.5)*2.0;

    std::string s;
    for (size_t i = 0; i < length.size(); i++)
        if (length[i]!=' ')
           s.push_back((char)tolower((unsigned char)length[i]));

    length = s;
    if (s.empty())
    {
       length = std::to_string((int)base) + "v";
       return base;
    }

    double numeric = atof(s.c_str());
    bool isNumber = true;
    for (size_t i = 0; i < s.size(); i++)
    {
        char c = s[i];
        if (!(isdigit((unsigned char)c) || c=='.' || c=='-' || c=='+' || c=='e'))
        {
           isNumber = false;
           break;
        }
    }

    if (s.find("px")!=std::string::npos || (isNumber && numeric>0))
       return numeric;
    else if (s.find("pt")!=std::string::npos)
       return floor(numeric*1.33333 + 0.5);
    else if (s.find("pc")!=std::string::npos)
       return floor(numeric*16.0 + 0.5);
    else if (s.find("cm")!=std::string::npos)
       return floor(numeric*37.795275591 + 0.5);
    else if (s.find("mm")!=std::string::npos)
       return floor(numeric*3.7795275591 + 0.5);
    else if (s.find("in")!=std::string::npos)
       return floor(numeric*96.0 + 0.5);
    else if (s.find("vw")!=std::string::npos)
       return w*2.0;
    else if (s.find("vh")!=std::string::npos)
       return h*2.0;
    else if (s.find("vmin")!=std::string::npos)
       return min(w, h)*2.0;
    else if (s.find("vmax")!=std::string::npos)
       return max(w, h)*2.0;
    else if (s.find("%")!=std::string::npos)
       return floor(clamp(numeric/200.0, 0.1, 1.0)*max(w, h) + 0.5)*3.0;

    length = std::to_string((int)base) + "v";
    return base;
}

// port of capIMGdimensionsFormatlimits("given", ...) of module-fim-thumbs.ahk
static void tpCapSVGdimensions(int givenSize, int &resizedW, int &resizedH) {
    const double mpxLimit = 2.0;
    if (givenSize>1 && max(resizedW, resizedH)>givenSize)
    {
       double z = (double)givenSize/max(resizedW, resizedH);
       resizedW = (int)floor(resizedW*z);
       resizedH = (int)floor(resizedH*z);
    }

    double mpx = floor(((double)resizedW*resizedH)/100000.0 + 0.5)/10.0;
    if (mpx>mpxLimit)
    {
       double g = 1.0;
       int rw = resizedW, rh = resizedH;
       for (int i = 0; i < 1000; i++)
       {
           g -= 0.001;
           rw = (int)floor(resizedW*g);
           rh = (int)floor(resizedH*g);
           if (floor(((double)rw*rh)/100000.0 + 0.5)/10.0 < mpxLimit)
              break;
       }
       resizedW = rw;
       resizedH = rh;
    }

    resizedW = max(1, resizedW);
    resizedH = max(1, resizedH);
}

static Gdiplus::GpBitmap* tpRenderSVG(const std::wstring &path, int givenW, int givenH, int &srcW, int &srcH,
                                      ID2D1Factory *d2dFac, IWICImagingFactory *wicFac) {
    std::string content = tpReadTextFile(path);
    if (content.empty())
       return NULL;

    size_t foundPos = std::string::npos;
    try
    {
        std::regex rx("<svg", std::regex::icase);
        std::smatch m;
        if (std::regex_search(content, m, rx))
           foundPos = (size_t)m.position(0);
    } catch (const std::regex_error&) { }

    if (foundPos==std::string::npos)
       return NULL;

    size_t closePos = content.find('>', foundPos + 1);
    std::string svgRoot = (closePos==std::string::npos) ? content.substr(foundPos) : content.substr(foundPos, closePos - foundPos + 1);
    std::string widthStr  = tpRetrieveXMLattribute(svgRoot, "width");
    std::string heightStr = tpRetrieveXMLattribute(svgRoot, "height");

    double ow = tpConvertSVGunitsToPixels(widthStr);
    double oh = tpConvertSVGunitsToPixels(heightStr);
    int w = (int)ow, h = (int)oh;
    srcW = w;
    srcH = h;
    tpCapSVGdimensions(max(givenW, givenH), w, h);

    float fScaleX = 1.0f, fScaleY = 1.0f;
    if (widthStr.find('v')==std::string::npos && widthStr.find('%')==std::string::npos && ow>0)
       fScaleX = (float)(floor((w/ow)*1000000.0 + 0.5)/1000000.0);
    else if (widthStr.find('%')!=std::string::npos)
    {
       double pct = atof(widthStr.c_str());
       fScaleX = (pct>100.0) ? (float)(100.0/pct) : 1.0f;
    }

    if (heightStr.find('v')==std::string::npos && heightStr.find('%')==std::string::npos && oh>0)
       fScaleY = (float)(floor((h/oh)*1000000.0 + 0.5)/1000000.0);
    else if (heightStr.find('%')!=std::string::npos)
    {
       double pct = atof(heightStr.c_str());
       fScaleY = (pct>100.0) ? (float)(100.0/pct) : 1.0f;
    }

    return LoadSVGimageEx((UINT)w, (UINT)h, fScaleX, fScaleY, path.c_str(), d2dFac, wicFac);
}

// ---------------------------------------------------------------------------------------
//  FreeImage loader; port of the FreeImage branch of MonoGenerateThumb()
// ---------------------------------------------------------------------------------------

// mirrors trFreeImage_Rescale() -> OpenCV_FimResizeBitmap() with a FreeImage_Rescale fallback.
// module-fim-thumbs.ahk always ended up using cv::INTER_NEAREST here, because the
// ResizeQualityHigh variable it consulted was missing from its Global block and therefore
// always blank; area averaging is used instead when shrinking.
static FIBITMAPptr tpFIMrescale(FIBITMAPptr dib, int newW, int newH) {
    if (!FIM.ok || !dib || newW<1 || newH<1)
       return NULL;

    unsigned iw = FIM.GetWidth(dib), ih = FIM.GetHeight(dib);
    if ((int)iw==newW && (int)ih==newH)
       return (FIM.Clone!=NULL) ? FIM.Clone(dib) : FIM.Rescale(dib, newW, newH, FILTER_BOX);

    const int shrinking   = ((int)iw>newW || (int)ih>newH) ? 1 : 0;
    const int cvInterp    = shrinking ? cv::INTER_AREA : cv::INTER_CUBIC;
    const int fimFilter   = shrinking ? FILTER_BOX : FILTER_CATMULLROM;
    const int imageType   = FIM.GetImageType(dib);
    const int bpp         = (int)FIM.GetBPP(dib);

    if (FIM.AllocateT!=NULL && !(imageType==FIT_BITMAP && bpp<24) && imageType!=FIT_UNKNOWN
    && !(imageType>=FIT_UINT16 && imageType<=FIT_COMPLEX))
    {
       FIBITMAPptr out = FIM.AllocateT(imageType, newW, newH, bpp, 0xFF000000, 0x00FF0000, 0x0000FF00);
       if (out!=NULL)
       {
          int r = openCVresizeBitmapExtended(FIM.GetBits(dib), FIM.GetBits(out), (int)iw, (int)ih, (int)FIM.GetPitch(dib),
                                             0, 0, (int)iw, (int)ih, newW, newH, (int)FIM.GetPitch(out), bpp, cvInterp);
          if (r==1)
             return out;

          FIM.Unload(out);
       }
    }

    return FIM.Rescale(dib, newW, newH, fimFilter);
}

// mirrors OpenCV_FimToneMapping()
static FIBITMAPptr tpFIMtoneMapOpenCV(FIBITMAPptr dib, const ThumbsConfig *cfg) {
    if (!FIM.ok || !dib || FIM.AllocateT==NULL)
       return NULL;

    unsigned w = FIM.GetWidth(dib), h = FIM.GetHeight(dib);
    if (!w || !h)
       return NULL;

    FIBITMAPptr out = FIM.AllocateT(FIT_BITMAP, (int)w, (int)h, 24, 0xFF000000, 0x00FF0000, 0x0000FF00);
    if (out==NULL)
       return NULL;

    int r = openCVapplyToneMappingAlgos((float*)FIM.GetBits(dib), (int)FIM.GetPitch(dib), (int)w, (int)h,
                                        FIM.GetBits(out), (int)FIM.GetPitch(out), cfg->toneMapAlgo - 3,
                                        cfg->tmOCVparamA, cfg->tmOCVparamB, cfg->tmParamC, cfg->tmParamD, cfg->tmAltExpo);
    if (r!=1)
    {
       FIM.Unload(out);
       return NULL;
    }
    return out;
}

// mirrors ConvertFimObj2pBitmap(); the intermediate 32bppARGB / GdiDib wrapper and the
// GdipCloneBitmapArea() to 32bppPARGB are kept as they were, so that GDI+ performs the
// premultiplication exactly the way it used to
static Gdiplus::GpBitmap* tpFIMtoGdip(FIBITMAPptr dib, int w, int h) {
    Gdiplus::GpBitmap *nBitmap = NULL, *pBitmap = NULL;
    if (!FIM.ok || !dib || w<1 || h<1)
       return NULL;

    BYTE *pBits = FIM.GetBits(dib);
    if (!pBits)
       return NULL;

    unsigned bpp = FIM.GetBPP(dib);
    if (bpp==32)
    {
       FIM.FlipVertical(dib);
       Gdiplus::DllExports::GdipCreateBitmapFromScan0(w, h, (INT)FIM.GetPitch(dib), PixelFormat32bppARGB, pBits, &nBitmap);
    } else
    {
       Gdiplus::DllExports::GdipCreateBitmapFromGdiDib(FIM.GetInfo(dib), pBits, &nBitmap);
    }

    if (nBitmap==NULL)
    {
       fnOutputDebug("thumbsPool: failed to wrap the FreeImage bitmap into a GDI+ object");
       return NULL;
    }

    Gdiplus::DllExports::GdipCloneBitmapAreaI(0, 0, w, h, PixelFormat32bppPARGB, nBitmap, &pBitmap);
    Gdiplus::DllExports::GdipDisposeImage(nBitmap);
    return pBitmap;
}

static Gdiplus::GpBitmap* tpFIMthumb(const ThumbsConfig *cfg, const std::wstring &path, const std::wstring &dst,
                                     DWORD startTick, int &srcW, int &srcH, int &status, int &savedToFile) {
    if (!FIM.ok)
    {
       status = TP_ERR_UNSUPPORTED;
       return NULL;
    }

    int GFT = FIM.GetFileTypeU(path.c_str(), 0);
    if (GFT==FIF_UNKNOWN && FIM.GetFIFFromFilenameU!=NULL)
       GFT = FIM.GetFIFFromFilenameU(path.c_str());

    int loadArgs = 0;
    if (GFT==FIF_RAW && IsFileExtension(path.c_str(), L".dng")==1)
       loadArgs = (cfg->userHQraw==1) ? RAW_DEFAULT : RAW_DISPLAY;
    else if (GFT==FIF_RAW)
       loadArgs = (cfg->userHQraw==1) ? RAW_DEFAULT : RAW_PREVIEW;
    else if (GFT==FIF_JPEG)
       loadArgs = JPEG_EXIFROTATE;

    FIBITMAPptr dib = FIM.LoadU(GFT, path.c_str(), loadArgs);
    if (dib==NULL)
    {
       status = TP_ERR_LOAD;
       fnOutputDebug("thumbsPool: FreeImage failed to load " + WideCharToString(path.c_str()));
       return NULL;
    }

    unsigned imgW = FIM.GetWidth(dib), imgH = FIM.GetHeight(dib);
    srcW = (int)imgW;
    srcH = (int)imgH;
    if (!imgW || !imgH || (imgW==1 && imgH==1))
    {
       FIM.Unload(dib);
       status = TP_ERR_LOAD;
       return NULL;
    }

    int resizedW = 0, resizedH = 0;
    tpCalcIMGdimensions((int)imgW, (int)imgH, cfg->thumbSize, cfg->thumbSize, resizedW, resizedH);

    FIBITMAPptr tmp = tpFIMrescale(dib, resizedW, resizedH);
    FIM.Unload(dib);
    if (tmp==NULL)
    {
       status = TP_ERR_RESIZE;
       fnOutputDebug("thumbsPool: failed to rescale " + WideCharToString(path.c_str()));
       return NULL;
    }
    dib = tmp;

    int colorType   = FIM.GetColorType(dib);
    int imgBPP      = (int)FIM.GetBPP(dib);
    int imageType   = FIM.GetImageType(dib);
    if (imageType==FIT_UINT16)
    {
       tmp = FIM.ConvertToGreyscale ? FIM.ConvertToGreyscale(dib) : NULL;
       if (tmp==NULL)
       {
          FIM.Unload(dib);
          status = TP_ERR_CONVERT;
          fnOutputDebug("thumbsPool: failed to convert an UINT16 bitmap to greyscale");
          return NULL;
       }
       FIM.Unload(dib);
       dib = tmp;

       tmp = FIM.ConvertTo24Bits(dib);
       if (tmp==NULL)
       {
          FIM.Unload(dib);
          status = TP_ERR_CONVERT;
          fnOutputDebug("thumbsPool: failed to convert a greyscale bitmap to 24 bits");
          return NULL;
       }
       FIM.Unload(dib);
       dib = tmp;
       imgBPP    = (int)FIM.GetBPP(dib);
       imageType = FIM.GetImageType(dib);
       colorType = FIM.GetColorType(dib);
    }

    const int thisAllow = ((GFT==FIF_PFM || GFT==FIF_HDR || GFT==FIF_EXR) && imgBPP>32) ? 1 : cfg->allowToneMapping;
    const int mustToneMap = ((imgBPP>32 && colorType!=FIC_RGBALPHA && GFT!=FIF_PNG) || imgBPP>64) ? 1 : 0;
    if (mustToneMap==1 && thisAllow==1)
    {
       if (imageType!=FIT_RGBF && cfg->toneMapAlgo>2 && FIM.ConvertToRGBF!=NULL)
       {
          tmp = FIM.ConvertToRGBF(dib);
          if (tmp!=NULL)
          {
             FIM.Unload(dib);
             dib = tmp;
          }
       }

       imageType = FIM.GetImageType(dib);
       FIBITMAPptr mapped = NULL;
       if (cfg->toneMapAlgo>2 && imageType==FIT_RGBF)
          mapped = tpFIMtoneMapOpenCV(dib, cfg);

       if (mapped==NULL && FIM.ToneMapping!=NULL)
          mapped = FIM.ToneMapping(dib, clamp(cfg->toneMapAlgo - 1, 0, 1), cfg->tmParamA, cfg->tmParamB);

       FIM.Unload(dib);
       if (mapped==NULL)
       {
          status = TP_ERR_TONEMAP;
          fnOutputDebug("thumbsPool: failed to tone map " + WideCharToString(path.c_str()));
          return NULL;
       }
       dib = mapped;
    }

    if ((int)FIM.GetWidth(dib)!=resizedW || (int)FIM.GetHeight(dib)!=resizedH)
    {
       tmp = tpFIMrescale(dib, resizedW, resizedH);
       FIM.Unload(dib);
       if (tmp==NULL)
       {
          status = TP_ERR_RESIZE;
          fnOutputDebug("thumbsPool: failed to rescale [second attempt] " + WideCharToString(path.c_str()));
          return NULL;
       }
       dib = tmp;
    }

    imgBPP = (int)FIM.GetBPP(dib);
    if (imgBPP!=24 && imgBPP!=32)
    {
       tmp = FIM.ConvertTo24Bits(dib);
       if (tmp!=NULL)
       {
          FIM.Unload(dib);
          dib = tmp;
       }
    }

    const int elapsed = (int)(GetTickCount() - startTick);
    if (cfg->enableCaching==1 && !dst.empty() && (elapsed>cfg->timePerImg || cfg->alwaysSave==1))
       savedToFile = tpSavePngFIM(dib, dst);

    Gdiplus::GpBitmap *result = NULL;
    if (cfg->wantBitmap==1 || savedToFile!=1)
       result = tpFIMtoGdip(dib, resizedW, resizedH);

    FIM.Unload(dib);
    if (result==NULL && savedToFile!=1)
    {
       status = TP_ERR_CONVERT;
       return NULL;
    }

    status = TP_OK;
    return result;
}

// ---------------------------------------------------------------------------------------
//  one job
// ---------------------------------------------------------------------------------------

static void tpRunJob(IWICImagingFactory *fac, ID2D1Factory *&d2dFac, const ThumbJob &job, ThumbResult &res) {
    const ThumbsConfig *cfg = job.cfg.get();
    const DWORD startTick   = GetTickCount();
    Gdiplus::GpBitmap *bmp  = NULL;

    res.jobId       = job.jobId;
    res.pBitmap     = NULL;
    res.status      = TP_ERR_LOAD;
    res.savedToFile = 0;
    res.srcW = res.srcH = res.outW = res.outH = 0;
    res.elapsedMs   = 0;
    res.loaderUsed  = 0;

    // OpenCV happily throws out of openCVapplyToneMappingAlgos(), and allocations may
    // throw when memory is scarce; letting that escape would tear the worker thread down
    // and silently shrink the pool for the rest of the session
    try
    {
    if (job.kind==TP_JOB_LOADCACHE)
    {
       bmp = tpWICload(fac, job.src.c_str(), 0, 0, 0, cfg->imgQuality, 0, res.srcW, res.srcH);
       res.loaderUsed = 5;
       res.status = (bmp!=NULL) ? TP_OK : TP_ERR_LOAD;
    } else
    {
       const std::wstring ext = tpFileExtension(job.src);
       const bool fimHandles  = (FIM.ok && cfg->allowFIM==1 && tpFimExts.count(ext)>0);

       if (ext==L"svg" && cfg->allowWIC==1)
       {
          // a factory of this worker's own, made on first use so a session that never opens
          // an SVG pays nothing for it. SINGLE_THREADED carries no internal lock, which is
          // the whole point; it is safe because the factory, its render target and the SVG
          // document all live and die inside one WicD2DrenderSVG() call on this thread
          if (d2dFac==NULL)
          {
             if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &d2dFac)))
                d2dFac = NULL;   // LoadSVGimageEx() then shares the process wide one
          }

          bmp = tpRenderSVG(job.src, cfg->thumbSize, cfg->thumbSize, res.srcW, res.srcH, d2dFac, fac);
          res.loaderUsed = 3;
          res.status = (bmp!=NULL) ? TP_OK : TP_ERR_LOAD;
       } else if (ext==L"pdf" && cfg->allowWIC==1)
       {
          int maxW = cfg->thumbSize, maxH = cfg->thumbSize, pageCount = 0, errorType = -100;
          {
             // PDFium keeps global state; the ahk_h threads used to call into it unguarded.
             // do24bits stays 0, so the page arrives as 32bppPARGB like every other loader
             // here; RenderPDFpage() of module-fim-thumbs.ahk slipped an extra argument in
             // ahead of it, so the trailing 1 of that DllCall was never do24bits
             std::lock_guard<std::mutex> pdfLock(tpPdfMutex);
             bmp = RenderPdfPageAsBitmap(job.src.c_str(), 0, 250.0f, &maxW, &maxH, 1, 0xffffffff, &pageCount, &errorType, L"", 0);
          }
          res.loaderUsed = 4;
          res.srcW = maxW;
          res.srcH = maxH;
          res.status = (bmp!=NULL) ? TP_OK : TP_ERR_PDFLOCKED;
       } else if (!fimHandles && cfg->allowWIC==1 && tpWicExts.count(ext)>0)
       {
          bmp = tpWICload(fac, job.src.c_str(), cfg->thumbSize, cfg->thumbSize, job.frameIndex, cfg->imgQuality,
                          (FIM.ok && cfg->allowFIM==1) ? 1 : 0, res.srcW, res.srcH);
          res.loaderUsed = 1;
          res.status = (bmp!=NULL) ? TP_OK : TP_ERR_LOAD;
       }

       if (bmp==NULL && res.status!=TP_ERR_PDFLOCKED && FIM.ok && cfg->allowFIM==1)
       {
          int status = TP_ERR_LOAD, saved = 0;
          int fw = 0, fh = 0;
          bmp = tpFIMthumb(cfg, job.src, job.dst, startTick, fw, fh, status, saved);
          res.loaderUsed  = 2;
          res.status      = status;
          res.savedToFile = saved;
          if (fw>0 && fh>0)
          {
             res.srcW = fw;
             res.srcH = fh;
          }
       }
    }
    } catch (...)
    {
        if (bmp!=NULL)
        {
           Gdiplus::DllExports::GdipDisposeImage(bmp);
           bmp = NULL;
        }
        res.status = TP_ERR_LOAD;
        fnOutputDebug("thumbsPool: an exception escaped while processing " + WideCharToString(job.src.c_str()));
    }

    res.elapsedMs = (int)(GetTickCount() - startTick);
    if (bmp!=NULL)
    {
       UINT bw = 0, bh = 0;
       Gdiplus::DllExports::GdipGetImageWidth(bmp, &bw);
       Gdiplus::DllExports::GdipGetImageHeight(bmp, &bh);
       res.outW = (int)bw;
       res.outH = (int)bh;

       if (job.kind==TP_JOB_THUMB && res.savedToFile!=1 && cfg->enableCaching==1 && !job.dst.empty()
       && (res.elapsedMs>cfg->timePerImg || cfg->alwaysSave==1))
          res.savedToFile = tpSavePng(fac, bmp, job.dst);

       if (cfg->wantBitmap!=1)
       {
          Gdiplus::DllExports::GdipDisposeImage(bmp);
          bmp = NULL;
       }
    }

    res.pBitmap = bmp;
}

// ---------------------------------------------------------------------------------------
//  worker threads
// ---------------------------------------------------------------------------------------

static void tpWorkerBody() {
    HRESULT hrCo = CoInitializeEx(NULL, COINIT_MULTITHREADED);

    // one OpenMP team member per worker; the ICV is per thread, so the main thread keeps
    // its own full width for the viewport operations
    omp_set_num_threads(1);

    // a private WIC factory avoids any apartment question about the one initWICnow() made
    IWICImagingFactory *fac = NULL;
    HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory2, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&fac));
    if (FAILED(hr))
       hr = CoCreateInstance(CLSID_WICImagingFactory1, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&fac));

    bool ownFactory = SUCCEEDED(hr) && fac!=NULL;
    if (!ownFactory)
    {
       fac = m_pIWICFactory;
       fnOutputDebug("thumbsPool: worker could not create its own WIC factory; sharing the global one");
    }

    // made on the first SVG this worker meets; see the tpRunJob() branch that creates it
    ID2D1Factory *d2dFac = NULL;

    for (;;)
    {
        ThumbJob job;
        {
            std::unique_lock<std::mutex> lk(tpMutex);
            // the byte cap only bites once something is already waiting to be collected,
            // so a single oversized thumbnail can never block the pool
            tpJobCV.wait(lk, [] {
                if (tpStopping.load())
                   return true;
                if (tpQueue.empty() || tpResults.size()>=TP_MAX_READY)
                   return false;
                return tpResults.empty() || tpReadyBytes<TP_MAX_READY_BYTES;
            });
            if (tpStopping.load())
               break;

            job = std::move(tpQueue.front());
            tpQueue.pop_front();
            tpState.queued = (LONG)tpQueue.size();
            tpState.inFlight = tpState.inFlight + 1;
        }

        ThumbResult res;
        bool ranIt = false;
        if (job.generation==tpGeneration.load() && tpAcquireJobSlot())
        {
           tpRunJob(fac, d2dFac, job, res);
           tpReleaseJobSlot();
           ranIt = true;
        }

        {
            std::lock_guard<std::mutex> lk(tpMutex);
            if (tpState.inFlight>0)
               tpState.inFlight = tpState.inFlight - 1;

            // abandoned before it started, or the run was cancelled while it was decoding
            if (!ranIt || job.generation!=tpGeneration.load())
            {
               if (ranIt && res.pBitmap!=NULL)
                  Gdiplus::DllExports::GdipDisposeImage((Gdiplus::GpBitmap*)res.pBitmap);
            } else
            {
               tpReadyBytes += tpResultBytes(res);
               tpResults.push_back(res);
               tpState.ready = (LONG)tpResults.size();
               tpState.readyKB = (LONG)(tpReadyBytes/1024ull);
               tpState.completed = tpState.completed + 1;
               if (res.status!=TP_OK)
                  tpState.failed = tpState.failed + 1;
            }
        }
    }

    SafeRelease(d2dFac, "tpWorkerBody: d2dFac", 0);
    if (ownFactory)
       SafeRelease(fac, "tpWorkerBody: fac", 0);

    if (SUCCEEDED(hrCo))
       CoUninitialize();

    // the very last thing a worker does; thumbsPoolShutdown() waits on this count rather
    // than joining blind, so a decoder that never returns cannot keep the process alive
    {
        std::lock_guard<std::mutex> lk(tpMutex);
        tpExited++;
    }
    tpExitCV.notify_all();
}

// drops everything that is queued and every result nobody collected; in flight jobs are
// tagged with the old generation and discarded by their worker, so nothing has to be waited on
static void tpCancelLocked() {
    tpGeneration.fetch_add(1);
    tpQueue.clear();
    for (size_t i = 0; i < tpResults.size(); i++)
    {
        if (tpResults[i].pBitmap!=NULL)
           Gdiplus::DllExports::GdipDisposeImage((Gdiplus::GpBitmap*)tpResults[i].pBitmap);
    }
    tpResults.clear();
    tpReadyBytes      = 0;
    tpState.queued    = 0;
    tpState.ready     = 0;
    tpState.readyKB   = 0;
    tpState.completed = 0;
    tpState.failed    = 0;
    tpState.generation = tpGeneration.load();
}

// ---------------------------------------------------------------------------------------
//  exports
// ---------------------------------------------------------------------------------------

DLL_API int DLL_CALLCONV thumbsPoolInit(int nThreads) {
    std::lock_guard<std::mutex> lk(tpMutex);
    if (!tpWorkers.empty())
       return 1;

    bindFreeImageOnce();
    if (m_pIWICFactory==NULL)
    {
       fnOutputDebug("thumbsPool: cannot start, WIC was not initialized; call initWICnow() first");
       return 0;
    }

    nThreads = clamp(nThreads, 1, 32);
    tpStopping.store(false);
    tpWorkers.reserve(nThreads);
    for (int i = 0; i < nThreads; i++)
        tpWorkers.push_back(std::thread(tpWorkerBody));

    tpState.alive = (LONG)tpWorkers.size();
    tpState.generation = tpGeneration.load();
    fnOutputDebug("thumbsPool: started with " + std::to_string(tpWorkers.size()) + " workers");
    return (int)tpWorkers.size();
}

DLL_API int DLL_CALLCONV thumbsPoolSetFormats(const wchar_t *wicExts, const wchar_t *fimExts) {
    std::lock_guard<std::mutex> lk(tpMutex);
    tpSplitExtensions(wicExts, tpWicExts);
    tpSplitExtensions(fimExts, tpFimExts);
    return (int)(tpWicExts.size() + tpFimExts.size());
}

DLL_API void* DLL_CALLCONV thumbsPoolGetState() {
    return (void*)&tpState;
}

// 1 when the machine is short on memory. The sample behind it is shared with the workers
// and refreshed at most every TP_MEM_SAMPLE_MS, so AHK may call this per thumbnail without
// paying for a syscall every time. Usable whether or not the pool is running.
DLL_API int DLL_CALLCONV thumbsPoolMemoryTight() {
    return tpMemoryIsTight() ? 1 : 0;
}

DLL_API int DLL_CALLCONV thumbsPoolBegin(const wchar_t *packedOptions) {
    if (tpWorkers.empty())
       return 0;

    std::shared_ptr<ThumbsConfig> cfg = std::make_shared<ThumbsConfig>();
    if (packedOptions!=NULL)
    {
       std::vector<double> v;
       const wchar_t *p = packedOptions;
       std::wstring cur;
       for (;; p++)
       {
           if (*p==L'|' || *p==0)
           {
              v.push_back(cur.empty() ? 0.0 : _wtof(cur.c_str()));
              cur.clear();
              if (*p==0)
                 break;
           } else cur.push_back(*p);
       }

       #define TPOPT(i, def) ((v.size()>(size_t)(i)) ? v[i] : (double)(def))
       cfg->thumbSize        = (int)TPOPT(0, 250);
       cfg->timePerImg       = (int)TPOPT(1, 25);
       cfg->enableCaching    = (int)TPOPT(2, 1);
       cfg->userHQraw        = (int)TPOPT(3, 1);
       cfg->allowToneMapping = (int)TPOPT(4, 1);
       cfg->allowWIC         = (int)TPOPT(5, 1);
       cfg->allowFIM         = (int)TPOPT(6, 1);
       cfg->imgQuality       = (int)TPOPT(7, 5);
       cfg->toneMapAlgo      = (int)TPOPT(8, 0);
       cfg->tmParamA         = (float)TPOPT(9, 0);
       cfg->tmParamB         = (float)TPOPT(10, 0);
       cfg->tmParamC         = (float)TPOPT(11, 0);
       cfg->tmParamD         = (float)TPOPT(12, 0);
       cfg->tmOCVparamA      = (float)TPOPT(13, 0);
       cfg->tmOCVparamB      = (float)TPOPT(14, 0);
       cfg->tmAltExpo        = (int)TPOPT(15, 0);
       cfg->wantBitmap       = (int)TPOPT(16, 1);
       cfg->alwaysSave       = (int)TPOPT(17, 0);
       #undef TPOPT
    }

    cfg->thumbSize = clamp(cfg->thumbSize, 8, 4096);
    {
        std::lock_guard<std::mutex> lk(tpMutex);
        tpCancelLocked();
        tpConfig = cfg;
    }

    // thumbnails are far too small for OpenCV's own threading to pay off, and every worker
    // would otherwise spawn a full team of its own; the viewport value is put back by
    // thumbsPoolEnd()
    if (tpPrevCVthreads<0)
    {
       tpPrevCVthreads = cv::getNumThreads();
       cv::setNumThreads(1);
    }

    tpJobCV.notify_all();
    return 1;
}

DLL_API int DLL_CALLCONV thumbsPoolSubmit(INT64 jobId, int kind, const wchar_t *src, const wchar_t *dst, int frameIndex) {
    if (tpWorkers.empty() || src==NULL || src[0]==0)
       return 0;

    ThumbJob job;
    job.jobId      = jobId;
    job.kind       = (kind==TP_JOB_LOADCACHE) ? TP_JOB_LOADCACHE : TP_JOB_THUMB;
    job.frameIndex = frameIndex;
    job.src        = src;
    job.dst        = (dst!=NULL) ? dst : L"";
    job.generation = tpGeneration.load();

    {
        std::lock_guard<std::mutex> lk(tpMutex);
        job.cfg = tpConfig;
        tpQueue.push_back(std::move(job));
        tpState.queued = (LONG)tpQueue.size();
    }

    tpJobCV.notify_one();
    return 1;
}

DLL_API int DLL_CALLCONV thumbsPoolFetch(void *outArray, int maxItems) {
    if (outArray==NULL || maxItems<1)
       return 0;

    ThumbResult *out = (ThumbResult*)outArray;
    int n = 0;
    {
        std::lock_guard<std::mutex> lk(tpMutex);
        while (n<maxItems && !tpResults.empty())
        {
            const ULONGLONG bytes = tpResultBytes(tpResults.front());
            tpReadyBytes = (tpReadyBytes>bytes) ? tpReadyBytes - bytes : 0;
            out[n++] = tpResults.front();
            tpResults.pop_front();
        }
        tpState.ready   = (LONG)tpResults.size();
        tpState.readyKB = (LONG)(tpReadyBytes/1024ull);
    }

    if (n>0)
       tpJobCV.notify_all();   // room was made, parked workers may resume

    return n;
}

DLL_API int DLL_CALLCONV thumbsPoolCancel() {
    {
        std::lock_guard<std::mutex> lk(tpMutex);
        tpCancelLocked();
    }
    tpJobCV.notify_all();
    return 1;
}

DLL_API int DLL_CALLCONV thumbsPoolEnd() {
    thumbsPoolCancel();
    if (tpPrevCVthreads>=0)
    {
       cv::setNumThreads(tpPrevCVthreads);
       tpPrevCVthreads = -1;
    }
    return 1;
}

DLL_API int DLL_CALLCONV thumbsPoolShutdown() {
    std::vector<std::thread> workers;
    {
        std::lock_guard<std::mutex> lk(tpMutex);
        if (tpWorkers.empty())
           return 1;

        tpCancelLocked();
        tpStopping.store(true);
        tpExited = 0;
        workers.swap(tpWorkers);
    }

    tpJobCV.notify_all();

    // a decoder that never returns [a malformed PDF, a file on a share that went away] must
    // not keep the whole application from closing; join only if every worker announced it
    // reached the end of tpWorkerBody(), otherwise let the stragglers go
    bool allOut = false;
    {
        std::unique_lock<std::mutex> lk(tpMutex);
        allOut = tpExitCV.wait_for(lk, std::chrono::seconds(5), [&workers] { return tpExited>=workers.size(); });
    }

    for (size_t i = 0; i < workers.size(); i++)
    {
        if (!workers[i].joinable())
           continue;

        if (allOut)
           workers[i].join();
        else
           workers[i].detach();
    }

    {
        std::lock_guard<std::mutex> lk(tpMutex);
        tpCancelLocked();
        tpState.alive    = 0;
        tpState.inFlight = 0;

        // a detached worker is still alive and will come back through this loop; leaving the
        // flag raised is what makes it quit on its own instead of parking on tpJobCV again
        if (allOut)
           tpStopping.store(false);
    }

    if (tpPrevCVthreads>=0)
    {
       cv::setNumThreads(tpPrevCVthreads);
       tpPrevCVthreads = -1;
    }

    if (!allOut)
    {
       fnOutputDebug("thumbsPool: shut down, but a worker was still busy and had to be abandoned");
       return 0;
    }

    fnOutputDebug("thumbsPool: shut down");
    return 1;
}

#endif // QPV_THUMBS_POOL_H
