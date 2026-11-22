// dupes-pixels.h
//
// Parallel collection of the per-image data the duplicate finder needs: the histogram
// statistics, the image properties, the file stamps, and the four pixel fingerprints.
//
// "The image properties" means every column the database keeps about the picture itself -
// imgwidth, imgheight, imgframes, imgdpi and imgpixfmt - and all five are read off the
// image as it came out of the decoder, before the loader scales it into the 350 pixel box
// or converts it to 32bppPARGB. Read afterwards they would describe the intermediate this
// file builds rather than the file on disk: one frame, 96 DPI and 32bppPARGB, for every
// image in the library.
//
// This is the phase collectSQLFileInfosNow() used to run strictly serially in AHK, one
// GDI+ decode at a time, with dumpBMPpixels() appending Chr(gray+161) one character at a
// time in the interpreter (72 + 1024 iterations per image, doubled when flipped detection
// is on) and one multi-kilobyte UPDATE built as a string literal per image. It is the
// most expensive thing QPV does on a fresh library and nothing about it was parallel,
// even though the cost is almost entirely image decoding.
//
// Here the decode runs on a pool of workers - WIC first, FreeImage for the formats WIC
// does not cover and whenever WIC fails - and everything that follows it happens on the
// worker too, so the calling thread only binds the finished values.
//
// Usage from AHK:
//    qpvSetPixelFormatNames(wic, fim, loaders)       once, from initQPVmainDLL()
//    dupesPixInit(nThreads)                          once, lazily
//    dupesPixBegin(ahkDb, selectSQL, packedOptions)  per collection run
//    dupesPixStep(msBudget)                          1 while more remains, 0 done, -1 error
//    dupesPixGetState()                              pointer polled with NumGet()
//    dupesPixEnd() / dupesPixShutdown()
//
// selectSQL yields (imgidu, fullPath) and must end in "AND imgidu>?2 ORDER BY imgidu
// LIMIT ?1" - see dpTopUpQueue() for why the keyset cursor is not optional here. Both
// statements run on the handle AHK owns, deliberately: a second connection would not see
// rows written inside AHK's open transaction and would hand them out again forever.
//
// This file is #included by qpv-main.cpp after thumbs-pool.h, so it can reuse that pool's
// loaders (tpRenderSVG, tpWICload, tpFIMthumb, tpGDIPload), its extension sets, the DLL's
// PDFium lock and its memory throttle rather than growing a second copy of them. dpDecodeFile()
// runs the same chain, in the same order, as tpRunJob(): what a thumbnail was drawn from
// and what a fingerprint was measured on should never be two different decodes of one file.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_DUPES_PIXELS_H
#define QPV_DUPES_PIXELS_H

// defined further down qpv-main.cpp, next to the directory-enumeration helpers
static INT64 qpvFileTimeToLocalStamp(INT64 ft);

#define DP_OK           0
#define DP_ERR_LOAD     1   // nothing could decode the file; the row is marked isDeleted=1
// It decoded, and then something after the decode failed. Counted as a failure but NOT
// marked, deliberately: a file that is genuinely unreadable fails at the decode and lands
// on DP_ERR_LOAD, so what reaches here is an allocation that did not come back, an
// exception out of the FreeImage/OpenCV rescale, or GDI+ refusing a bitmap it had just
// produced - all of them transient, and all of them far more likely now that the decode
// runs on up to 32 threads at once than they were in the serial AHK this replaced.
// isDeleted=1 is durable: it hides the image from every query in this path until the user
// finds PanelPurgeCachedSQLdata(). Losing a run's work on a tight machine is a retry; a
// library quietly marking good photos as dead is not.
#define DP_ERR_PROCESS  2

#define DP_MAX_READY   256  // finished images allowed to pile up before workers park
#define DP_MAX_WORKERS  32  // what dupesPixInit() clamps to, and the size of dpBusy below

#pragma pack(push, 8)
struct DupePixState {         // AHK NumGet()s these by byte offset
    volatile LONG phase;      //  0   0 idle, 1 collecting, 5 done, -1 cancelled or failed
    volatile LONG queued;     //  4
    volatile LONG inFlight;   //  8
    volatile LONG ready;      // 12   decoded, waiting to be written
    volatile LONG written;    // 16   rows committed to the database
    volatile LONG failed;     // 20   files that could not be read at all
    volatile LONG dbErrors;   // 24
    volatile LONG submitted;  // 28
    volatile LONG alive;      // 32   worker threads
    volatile LONG lastError;  // 36
    // 1 once the refill query has run out of rows. From that moment dupesPixStep() stops
    // asking it for more and the run is only finishing what the workers already hold, which
    // is the one thing the counters above cannot be read for: an empty queue with idle
    // workers is the TAIL of a run, and looks nothing like a pool that cannot keep up.
    volatile LONG drained;    // 40
};
#pragma pack(pop)

// One run's settings. Everything here is fixed for the whole run, so the jobs share one
// immutable copy rather than carrying their own.
struct DupePixCfg {
    int boxSize       = 350;  // the intermediate the histogram is measured on
    int interpolation = 5;    // GDI+ InterpolationMode for the 9x8 / 32x32 resize
    int wicQuality    = 5;    // tpWICload(): 7 asks for the high quality cubic scaler
    int applyBlur     = 0;    // dupesApplyBlur
    int wantFlipped   = 0;    // findFlippedDupes
    int allowWIC      = 1;
    int allowFIM      = 1;
    int userHQraw     = 1;
    int allowToneMap  = 1;
    int   toneMapAlgo      = 0;
    float tmParamA         = 0.0f;
    float tmParamB         = 0.0f;
    float tmParamC         = 0.0f;
    float tmParamD         = 0.0f;
    float tmOCVparamA      = 0.0f;
    float tmOCVparamB      = 0.0f;
    int   tmAltExpo        = 0;
    int   firstFIM         = 0;
    int smallW = 9, smallH = 8;
    int bigW  = 32, bigH  = 32;
};

struct DupePixJob {
    INT64        imgidu = 0;
    LONG         generation = 0;
    std::wstring path;
};

struct DupePixResult {
    INT64  imgidu = 0;
    int    status = DP_ERR_LOAD;
    int    loaderUsed = 0;          // 1 WIC, 2 FreeImage
    int    width = 0, height = 0;
    // imgframes, imgdpi and imgpixfmt: the properties of the file itself, read by the
    // loader before it scaled or converted anything - see TpSrcMeta in thumbs-pool.h
    TpSrcMeta meta;
    INT64  fsize = 0, fmodified = 0, fcreated = 0;
    // the eight values getImgHistoValuesSet() writes, already normalised the way
    // calcHistoAvgFile() normalises them
    double avg = 0, median = 0, peak = 0, low = 0, rms = 0, range = 0, mode = 0, minu = 0;
    std::vector<unsigned char> small, big, smallH, bigH;
};

// What one worker is holding right now, so that a run which has stopped moving can be
// asked WHICH file it is waiting for. The nine counters can say that one job is in flight
// and nothing is arriving; they cannot say whether that job is a 200 MB raw being decoded
// or a worker the shared throttle of thumbs-pool.h has not let through yet, and those two
// call for opposite answers from whoever is looking at them.
//
// One entry per worker, indexed by the slot dupesPixInit() gave the thread. Never resized -
// a worker that outlived a shutdown is detached, not stopped, and would still be writing
// here. path and startedMs are guarded by dpMutex; state is written without it, on the way
// past, and is only ever read for a message.
struct DpBusy {
    volatile INT64   startedMs = 0;   // GetTickCount64() when the job was taken; 0 = holding nothing
    std::atomic<int> state{0};        // 1 waiting for a decode slot, 2 decoding
    std::wstring     path;
};

struct DpPool {
    std::atomic<bool> stopping{false};
    size_t            exited = 0;      // guarded by dpMutex
    DpBusy            busy[DP_MAX_WORKERS];
};

static std::vector<std::thread>            dpWorkers;
static std::deque<DupePixJob>              dpQueue;
static std::deque<DupePixResult>           dpResults;
static std::shared_ptr<DpPool>             dpPool;            // guarded by dpMutex
static std::mutex                          dpMutex;
static std::condition_variable             dpJobCV;
static std::condition_variable             dpExitCV;
static std::atomic<LONG>                   dpGeneration(1);
static std::shared_ptr<const DupePixCfg>   dpConfig = std::make_shared<DupePixCfg>();
static DupePixState                        dpState = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
static LONG                                dpRunInFlight = 0; // guarded by dpMutex
static LONG                                dpDroppedResults = 0; // guarded by dpMutex
static bool                                dpHoldsCVclamp = false;

// The names the database stores in imgpixfmt, exactly as the interpreter spells them:
// dpWicNames is indexed by indexedWICpixelFormats() and holds what WicPixelFormats()
// returns, dpFimNames by FREE_IMAGE_COLOR_TYPE and holds what FreeImage_GetColorType()
// returns, and dpLoaderNames by TpSrcMeta's loader number for the two loaders whose
// format is a constant - the SVG renderer and PDFium - the way RenderSVGfile() and
// RenderPDFpage() report theirs. qpvSetPixelFormatNames() fills all three once per
// session, so there is one copy of those strings in the product and a label can never be
// renamed on one side only.
//
// Both users of the names are single-threaded readers and both run after the tables are
// filled: dpWriteResult(), on the dupesPixStep() thread, and qpvGetPixelFormatName(),
// which QPV_ThumbsPoolDrain() calls for the images the thumbnails workers read off disk.
static std::vector<std::wstring> dpWicNames;
static std::vector<std::wstring> dpFimNames;
static std::vector<std::wstring> dpLoaderNames;

static sqlite3      *dpDB      = NULL;      // AHK's handle; never closed here
static sqlite3_stmt *dpSelect  = NULL;
static sqlite3_stmt *dpUpdHist = NULL;
static sqlite3_stmt *dpUpdPix  = NULL;
static sqlite3_stmt *dpMarkDead = NULL;
static bool          dpSelectDrained = false;
static INT64         dpLastID = 0;        // keyset cursor; see dpTopUpQueue()

// The flag the step loop tests and the number AHK reads are set together, in one place, so
// they can never disagree about whether anything more is coming.
static void dpSetDrained(bool drained) {
    dpSelectDrained = drained;
    dpState.drained = drained ? 1 : 0;
}

static void dpMarkBusy(DpPool *pool, size_t slot, const std::wstring *path, int state) {
    if (pool==NULL || slot >= (size_t)DP_MAX_WORKERS)
       return;

    if (path==NULL)
    {
       pool->busy[slot].state.store(state, std::memory_order_relaxed);
       return;
    }

    std::lock_guard<std::mutex> lk(dpMutex);
    pool->busy[slot].startedMs = (state!=0) ? (INT64)GetTickCount64() : 0;
    pool->busy[slot].state.store(state, std::memory_order_relaxed);
    try
    {
        pool->busy[slot].path = *path;
    } catch (...)
    {
        pool->busy[slot].path.clear();
    }
}

// ---------------------------------------------------------------------------------------
//  the GDI+ chain, reproduced from calcHistoAvgFile()
// ---------------------------------------------------------------------------------------

// Gdip_CreateEffect(6, 0, -100, 0) - HueSaturationLightness with the saturation pulled all
// the way down, which is how the AHK path turns the thumbnail grey before measuring it.
static const GUID dpHSLeffectGUID = {0x8B2DD6C3, 0xEB07, 0x4d87, {0xA5, 0xF0, 0x71, 0x08, 0xE2, 0x6A, 0x9C, 0x5F}};
static const GUID dpBlurEffectGUID = {0x633C80A4, 0x1843, 0x482b, {0x9E, 0xF2, 0xBE, 0x28, 0x34, 0xC5, 0xFD, 0xD4}};

struct DpHSLparams  { INT hue; INT saturation; INT lightness; };
struct DpBlurParams { float radius; BOOL expandEdge; };

// One set of effects per worker, made once and kept: GdipCreateEffect() is not free and
// every image in a run uses the same three.
//
// Note the namespace: GdipCreateEffect/GdipSetEffectParameters/GdipDeleteEffect are declared
// in gdipluseffects.h, which gdiplus.h includes at plain Gdiplus scope, so they are NOT
// members of Gdiplus::DllExports like the rest of the flat API. GdipBitmapApplyEffect() below
// comes from gdiplusflat.h and does stay in DllExports.
struct DpEffects {
    Gdiplus::CGpEffect *gray  = NULL;
    Gdiplus::CGpEffect *blurA = NULL;
    Gdiplus::CGpEffect *blurB = NULL;
};

static void dpMakeEffects(DpEffects &fx, int blurRadius) {
    if (fx.gray==NULL && Gdiplus::GdipCreateEffect(dpHSLeffectGUID, &fx.gray)==Gdiplus::Ok && fx.gray!=NULL)
    {
       DpHSLparams p = {0, -100, 0};
       if (Gdiplus::GdipSetEffectParameters(fx.gray, &p, (UINT)sizeof(p))!=Gdiplus::Ok)
       {
          Gdiplus::GdipDeleteEffect(fx.gray);
          fx.gray = NULL;
       }
    }

    if (blurRadius > 0)
    {
       DpBlurParams p;
       p.radius = (float)blurRadius;
       p.expandEdge = FALSE;
       if (fx.blurA==NULL && Gdiplus::GdipCreateEffect(dpBlurEffectGUID, &fx.blurA)==Gdiplus::Ok && fx.blurA!=NULL)
       {
          if (Gdiplus::GdipSetEffectParameters(fx.blurA, &p, (UINT)sizeof(p))!=Gdiplus::Ok)
          {
             Gdiplus::GdipDeleteEffect(fx.blurA);
             fx.blurA = NULL;
          }
       }
       if (fx.blurB==NULL && Gdiplus::GdipCreateEffect(dpBlurEffectGUID, &fx.blurB)==Gdiplus::Ok && fx.blurB!=NULL)
       {
          if (Gdiplus::GdipSetEffectParameters(fx.blurB, &p, (UINT)sizeof(p))!=Gdiplus::Ok)
          {
             Gdiplus::GdipDeleteEffect(fx.blurB);
             fx.blurB = NULL;
          }
       }
    }
}

static void dpFreeEffects(DpEffects &fx) {
    if (fx.gray!=NULL)  { Gdiplus::GdipDeleteEffect(fx.gray);  fx.gray = NULL; }
    if (fx.blurA!=NULL) { Gdiplus::GdipDeleteEffect(fx.blurA); fx.blurA = NULL; }
    if (fx.blurB!=NULL) { Gdiplus::GdipDeleteEffect(fx.blurB); fx.blurB = NULL; }
}

static bool dpApplyGaussian(Gdiplus::GpBitmap *bmp, const DpEffects &fx) {
    if (bmp==NULL || fx.blurA==NULL || fx.blurB==NULL)
       return false;

    return Gdiplus::DllExports::GdipImageRotateFlip(bmp, Gdiplus::Rotate90FlipNone)==Gdiplus::Ok
        && Gdiplus::DllExports::GdipBitmapApplyEffect(bmp, fx.blurA, NULL, FALSE, NULL, NULL)==Gdiplus::Ok
        && Gdiplus::DllExports::GdipImageRotateFlip(bmp, Gdiplus::Rotate270FlipNone)==Gdiplus::Ok
        && Gdiplus::DllExports::GdipBitmapApplyEffect(bmp, fx.blurB, NULL, FALSE, NULL, NULL)==Gdiplus::Ok;
}

// trGdip_ResizeBitmap(..., KeepRatio 0, InterpolationMode, KeepPixelFormat -1) ->
// Gdip_ResizeBitmap()'s non-indexed branch: a fresh 32bppARGB bitmap (coreDesiredPixFmt is
// 0x21808 from startup), a graphics context with the requested interpolation mode,
// SmoothingModeAntiAlias and PixelOffsetModeHighQuality, then one DrawImage.
static Gdiplus::GpBitmap* dpResizeBitmap(Gdiplus::GpBitmap *src, int w, int h, int interpolation) {
    if (src==NULL || w < 1 || h < 1)
       return NULL;

    Gdiplus::GpBitmap *dst = NULL;
    if (Gdiplus::DllExports::GdipCreateBitmapFromScan0(w, h, 0, PixelFormat32bppARGB, NULL, &dst)!=Gdiplus::Ok || dst==NULL)
       return NULL;

    Gdiplus::GpGraphics *g = NULL;
    if (Gdiplus::DllExports::GdipGetImageGraphicsContext(dst, &g)!=Gdiplus::Ok || g==NULL)
    {
       Gdiplus::DllExports::GdipDisposeImage(dst);
       return NULL;
    }

    Gdiplus::DllExports::GdipSetInterpolationMode(g, (Gdiplus::InterpolationMode)interpolation);
    Gdiplus::DllExports::GdipSetSmoothingMode(g, Gdiplus::SmoothingModeAntiAlias);
    Gdiplus::DllExports::GdipSetPixelOffsetMode(g, Gdiplus::PixelOffsetModeHighQuality);
    const Gdiplus::Status st = Gdiplus::DllExports::GdipDrawImageRectI(g, src, 0, 0, w, h);
    Gdiplus::DllExports::GdipDeleteGraphics(g);
    if (st!=Gdiplus::Ok)
    {
       Gdiplus::DllExports::GdipDisposeImage(dst);
       return NULL;
    }

    return dst;
}

// dumpBMPpixels(): the blue channel of a 32bpp bitmap, row by row. The image is grey by
// this point, so blue is the grey level; the AHK stored it as Chr(value + 161) purely to
// survive being pasted into an SQL string literal, which bound BLOBs make unnecessary.
static bool dpDumpBlue(Gdiplus::GpBitmap *bmp, int w, int h, std::vector<unsigned char> &out) {
    if (bmp==NULL || w < 1 || h < 1)
       return false;

    out.resize((size_t)w * h);

    Gdiplus::BitmapData bd;
    Gdiplus::Rect rect(0, 0, w, h);
    if (Gdiplus::DllExports::GdipBitmapLockBits(bmp, &rect, Gdiplus::ImageLockModeRead, PixelFormat32bppARGB, &bd)!=Gdiplus::Ok)
       return false;

    const unsigned char *base = (const unsigned char*)bd.Scan0;
    for ( int y = 0 ; y < h ; y++)
    {
        const unsigned char *row = base + (INT64)y * bd.Stride;
        unsigned char *dst = &out[(size_t)y * w];
        for ( int x = 0 ; x < w ; x++)
            dst[x] = row[x*4];        // BGRA in memory: byte 0 is blue
    }

    Gdiplus::DllExports::GdipBitmapUnlockBits(bmp, &bd);
    return true;
}

// A transcription of calcHistoAvgFile()'s single pass over the 256 luminance levels.
// Every statistic is gathered over the OCCUPIED levels only and normalised the same way,
// so the values land in the database identical to the ones the AHK path wrote.
static bool dpHistogram(Gdiplus::GpBitmap *bmp, int w, int h, DupePixResult &res) {
    if (bmp==NULL || w < 1 || h < 1)
       return false;

    UINT elements[256];
    if (Gdiplus::DllExports::GdipBitmapGetHistogram(bmp, Gdiplus::HistogramFormatGray, 256, elements, NULL, NULL, NULL)!=Gdiplus::Ok)
       return false;

    const double totalPixelz = (double)w * (double)h;
    if (totalPixelz < 1.0)
       return false;

    const UINT64 halfPix = (UINT64)((INT64)w * (INT64)h / 2);
    int medianValue = -1, minBrLvlK = -1;
    int modePointK = 0, peakPointK = 0, minPointK = 0;
    UINT64 modePointV = 0, thisSum = 0, sumTotalBr = 0, sumSq = 0;
    UINT64 pixMinu = (UINT64)((INT64)w * (INT64)h) + 1;   // above any count: a single level is the rarest too

    for ( int lvl = 0 ; lvl < 256 ; lvl++)
    {
        const UINT64 nrPixelz = (UINT64)elements[lvl];
        if (nrPixelz < 1)
           continue;

        sumTotalBr += nrPixelz * (UINT64)(lvl + 1);            // +1 so /256 maps 255 -> 1.0
        sumSq      += nrPixelz * (UINT64)lvl * (UINT64)lvl;
        if (nrPixelz > modePointV)                             // ties keep the lowest level
        {
           modePointV = nrPixelz;
           modePointK = lvl;
        }

        peakPointK = lvl;
        if (minBrLvlK==-1)
           minBrLvlK = lvl;

        if (nrPixelz < pixMinu)                                // rarest OCCUPIED level
        {
           pixMinu = nrPixelz;
           minPointK = lvl;
        }

        if (medianValue==-1)
        {
           thisSum += nrPixelz;
           if (thisSum > halfPix)
              medianValue = lvl;
        }
    }

    const double avgu     = (double)sumTotalBr/totalPixelz - 1.0;
    const double variance = (double)sumSq/totalPixelz - avgu*avgu;
    const double stdDev   = sqrt((variance > 0.0) ? variance : 0.0);

    // AHK's Round(x, 5) is half away from zero on a non-negative value here
    #define DPROUND5(x) (floor((x)*100000.0 + 0.5)/100000.0)
    res.avg    = DPROUND5((avgu + 1.0)/256.0);
    res.median = DPROUND5((double)(medianValue + 1)/256.0);
    res.peak   = DPROUND5((double)(peakPointK + 1)/256.0);
    res.low    = DPROUND5((double)(minBrLvlK + 1)/256.0);
    res.rms    = DPROUND5(stdDev/256.0);
    res.range  = DPROUND5((double)(peakPointK - minBrLvlK + 1)/256.0);
    res.mode   = DPROUND5((double)(modePointK + 1)/256.0);
    res.minu   = DPROUND5((double)(minPointK + 1)/256.0);
    #undef DPROUND5
    return true;
}

// ---------------------------------------------------------------------------------------
//  one job
// ---------------------------------------------------------------------------------------

static bool dpJobAbandoned(LONG jobGeneration, const DpPool *pool = NULL) {
    if (pool!=NULL && pool->stopping.load())
       return true;
    return dupesPixCancel.load()!=0 || jobGeneration!=dpGeneration.load();
}

static bool dpIsTransientFimStatus(int status) {
    return status==TP_ERR_RESIZE || status==TP_ERR_CONVERT || status==TP_ERR_TONEMAP;
}

struct DpBitmapGuard {
    Gdiplus::GpBitmap *p = NULL;
    ~DpBitmapGuard() { if (p!=NULL) Gdiplus::DllExports::GdipDisposeImage(p); }
};

static Gdiplus::GpBitmap* dpDecodeFile(IWICImagingFactory *fac, ID2D1Factory *&d2dFac, const DupePixCfg &cfg,
                                       const std::wstring &path, const ThumbsConfig &tcfg,
                                       int &srcW, int &srcH, int &loaderUsed, TpSrcMeta &meta,
                                       LONG jobGeneration, bool &transientErr,
                                       const DpPool *pool = NULL,
                                       std::unique_lock<std::timed_mutex> *heldPdfLock = NULL) {
    Gdiplus::GpBitmap *bmp = NULL;
    transientErr = false;
    const std::wstring ext = tpFileExtension(path);

    if (ext==L"svg")
    {
       if (d2dFac==NULL)
       {
          if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &d2dFac)))
             d2dFac = NULL;
       }

       bmp = tpRenderSVG(path, cfg.boxSize, cfg.boxSize, srcW, srcH, d2dFac, fac);
       if (bmp!=NULL)
       {
          loaderUsed = 3;
          meta.frames = 1;
          meta.dpi    = 96;
       }
       return bmp;
    }

    if (ext==L"pdf")
    {
       int maxW = cfg.boxSize, maxH = cfg.boxSize, pageCount = 0, errorType = -100;
       {
          // PDFium is held for the render alone, whoever took the lock
          std::unique_lock<std::timed_mutex> ownLock(pdfiumMutex, std::defer_lock);
          std::unique_lock<std::timed_mutex> &pdfLock = (heldPdfLock!=NULL) ? *heldPdfLock : ownLock;
          if (!pdfLock.owns_lock())
          {
             while (!pdfLock.try_lock_for(std::chrono::milliseconds(25)))
             {
                if (dpJobAbandoned(jobGeneration, pool))
                {
                   transientErr = true;
                   return NULL;
                }
             }
          }
          if (dpJobAbandoned(jobGeneration, pool))
          {
             transientErr = true;
             return NULL;
          }

          bmp = coreRenderPdfPageAsBitmap(path.c_str(), 0, 250.0f, &maxW, &maxH, 1, 0xffffffff,
                                          &pageCount, &errorType, L"", 0);
          pdfLock.unlock();
       }

       if (bmp!=NULL)
       {
          loaderUsed = 4;
          srcW = maxW;
          srcH = maxH;
          meta.frames = (pageCount > 0) ? pageCount : 1;
       } else
       {
          if (errorType==-4 || errorType==-5)
             transientErr = true;
          if (errorType!=0)
             QPV_DBG("dupesPixels: PDFium could not render " + WideCharToString(path.c_str())
                         + ", error " + std::to_string(errorType));
       }
       return bmp;
    }

    const bool fimHandles = (FIM.ok && ((cfg.allowFIM==1 && tpFimExts.count(ext) > 0) || cfg.firstFIM==1));
    int hasTriedFim = 0;
    if (bmp==NULL && fimHandles)
    {
       hasTriedFim = 1;
       meta = TpSrcMeta();
       int status = TP_ERR_LOAD, saved = 0, fw = 0, fh = 0;
       bmp = tpFIMthumb(&tcfg, path, L"", GetTickCount(), fw, fh, status, saved, &meta);
       if (bmp!=NULL)
       {
          loaderUsed = 2;
          if (fw > 0 && fh > 0)
          {
             srcW = fw;
             srcH = fh;
          }
       } else if (dpIsTransientFimStatus(status))
       {
          transientErr = true;
          return NULL;
       }
    }

    if (bmp==NULL && (tpWicExts.count(ext) > 0 || hasTriedFim==1))
    {
       const int fimNext = (FIM.ok && cfg.allowFIM==1 && hasTriedFim!=1) ? 1 : 0;
       if (cfg.allowWIC==1)
       {
          meta = TpSrcMeta();
          bmp = tpWICload(fac, path.c_str(), cfg.boxSize, cfg.boxSize, 0, cfg.wicQuality, fimNext, srcW, srcH, &meta);
       }

       if (bmp!=NULL)
       {
          loaderUsed = 1;
       } else if (fimNext==1)
       {
          meta = TpSrcMeta();
          int status = TP_ERR_LOAD, saved = 0, fw = 0, fh = 0;
          bmp = tpFIMthumb(&tcfg, path, L"", GetTickCount(), fw, fh, status, saved, &meta);
          if (bmp!=NULL)
          {
             loaderUsed = 2;
             if (fw > 0 && fh > 0)
             {
                srcW = fw;
                srcH = fh;
             }
          } else
          {
             if (dpIsTransientFimStatus(status))
             {
                transientErr = true;
                return NULL;
             }
             if (cfg.allowWIC==1 && (ext==L"tif" || ext==L"tiff"))
             {
                meta = TpSrcMeta();
                bmp = tpWICload(fac, path.c_str(), cfg.boxSize, cfg.boxSize, 0, cfg.wicQuality, 0, srcW, srcH, &meta);
                if (bmp!=NULL)
                   loaderUsed = 1;
             }
          }
       }
    }

    if (bmp==NULL)
    {
       meta = TpSrcMeta();
       bmp = tpGDIPload(path, cfg.boxSize, cfg.boxSize, 0, cfg.interpolation, srcW, srcH, &meta);
       if (bmp!=NULL)
          loaderUsed = 6;
    }

    return bmp;
}

static void dpRunJob(IWICImagingFactory *fac, ID2D1Factory *&d2dFac, DpEffects &fx, const DupePixCfg &cfg,
                     const ThumbsConfig &tcfg, const DupePixJob &job, DupePixResult &res,
                     const DpPool *pool = NULL, std::unique_lock<std::timed_mutex> *heldPdfLock = NULL) {
    res.imgidu = job.imgidu;
    res.status = DP_ERR_LOAD;

    WIN32_FILE_ATTRIBUTE_DATA fad;
    if (GetFileAttributesExW(job.path.c_str(), GetFileExInfoStandard, &fad))
    {
       res.fsize = ((INT64)fad.nFileSizeHigh << 32) | (INT64)fad.nFileSizeLow;
       INT64 ft;
       memcpy(&ft, &fad.ftLastWriteTime, sizeof(INT64));
       res.fmodified = qpvFileTimeToLocalStamp(ft)/100;
       memcpy(&ft, &fad.ftCreationTime, sizeof(INT64));
       res.fcreated = qpvFileTimeToLocalStamp(ft)/100;
    }

    if (res.fsize < 3)
       return;

    try
    {
        int srcW = 0, srcH = 0;
        bool transientErr = false;
        DpBitmapGuard bmp;
        bmp.p = dpDecodeFile(fac, d2dFac, cfg, job.path, tcfg, srcW, srcH, res.loaderUsed, res.meta,
                             job.generation, transientErr, pool, heldPdfLock);
        if (bmp.p==NULL)
        {
           if (transientErr || dpJobAbandoned(job.generation, pool))
              res.status = DP_ERR_PROCESS;
           return;
        }

        res.width  = srcW;
        res.height = srcH;

        UINT bw = 0, bh = 0;
        Gdiplus::DllExports::GdipGetImageWidth(bmp.p, &bw);
        Gdiplus::DllExports::GdipGetImageHeight(bmp.p, &bh);
        if (bw < 1 || bh < 1)
           return;

        res.status = DP_ERR_PROCESS;
        bool ok = (fx.gray!=NULL && Gdiplus::DllExports::GdipBitmapApplyEffect(bmp.p, fx.gray, NULL, FALSE, NULL, NULL)==Gdiplus::Ok);

        ok = ok && dpHistogram(bmp.p, (int)bw, (int)bh, res);
        if (ok && cfg.applyBlur==1)
           ok = dpApplyGaussian(bmp.p, fx);

        if (ok)
        {
           DpBitmapGuard x1, x2;
           x1.p = dpResizeBitmap(bmp.p, cfg.smallW, cfg.smallH, cfg.interpolation);
           x2.p = dpResizeBitmap(bmp.p, cfg.bigW, cfg.bigH, cfg.interpolation);
           const bool okSmall = dpDumpBlue(x1.p, cfg.smallW, cfg.smallH, res.small);
           const bool okBig   = dpDumpBlue(x2.p, cfg.bigW, cfg.bigH, res.big);
           ok = okSmall && okBig;
        }

        if (ok && cfg.wantFlipped==1)
        {
           ok = (Gdiplus::DllExports::GdipImageRotateFlip(bmp.p, Gdiplus::RotateNoneFlipX)==Gdiplus::Ok);
           if (ok)
           {
              DpBitmapGuard x1, x2;
              x1.p = dpResizeBitmap(bmp.p, cfg.smallW, cfg.smallH, cfg.interpolation);
              x2.p = dpResizeBitmap(bmp.p, cfg.bigW, cfg.bigH, cfg.interpolation);
              const bool okSmall = dpDumpBlue(x1.p, cfg.smallW, cfg.smallH, res.smallH);
              const bool okBig   = dpDumpBlue(x2.p, cfg.bigW, cfg.bigH, res.bigH);
              ok = okSmall && okBig;
           }
        }

        if (ok)
           res.status = DP_OK;
    } catch (...)
    {
        res.status = DP_ERR_PROCESS;
        QPV_DBG("dupesPixels: an exception escaped while processing " + WideCharToString(job.path.c_str()));
    }
}

// ---------------------------------------------------------------------------------------
//  worker threads
// ---------------------------------------------------------------------------------------

// The collection pool's half of the shared throttle in thumbs-pool.h: while memory is
// scarce, only the worker that finds no decode running anywhere in the DLL starts one, so
// the machine is never asked for two decoder-sized allocations at once and the pool still
// moves - one image at a time - instead of stopping. Returns false only when the run is
// being abandoned, in which case the job is dropped without being decoded.
//
// The generation is part of that: without it a worker that waited out a whole run - which
// on a tight machine is minutes - would come through the slot and spend it decoding an
// image for a run that no longer exists, while the run that replaced it waits behind it.
//
// What this must never do is wait on a count that includes the waiter. dpState.inFlight is
// raised the moment a job leaves the queue, before any of this, so every worker holding a
// job counts towards it: waiting for it to fall to 1 asks the other workers to finish jobs
// that are themselves waiting for this one. With N workers each holding a job the count
// never falls below N, no decode ever starts, dupesPixStep() never sees the pool go idle
// and the loop in collectImgDataViaPool() spins on nothing written for as long as the user
// lets it. tpActiveJobs counts decodes actually running, and a worker waiting here is not
// one of them - which is also why dupesPixWorkStates() exists.
static bool dpAcquireJobSlot(LONG jobGeneration) {
    return tpWaitForJobSlot([jobGeneration] { return dpJobAbandoned(jobGeneration); });
}

static void dpWorkerBody(std::shared_ptr<DpPool> pool, size_t mySlot) {
    HRESULT hrCo = CoInitializeEx(NULL, COINIT_MULTITHREADED);

    IWICImagingFactory *fac = NULL;
    HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory2, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&fac));
    if (FAILED(hr))
       hr = CoCreateInstance(CLSID_WICImagingFactory1, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&fac));

    const bool ownFactory = SUCCEEDED(hr) && fac!=NULL;
    if (!ownFactory)
       fac = m_pIWICFactory;

    DpEffects fx;
    std::shared_ptr<const DupePixCfg> madeFor;
    ID2D1Factory *d2dFac = NULL;

    for (;;)
    {
        DupePixJob job;
        std::shared_ptr<const DupePixCfg> cfg;
        {
            std::unique_lock<std::mutex> lk(dpMutex);
            dpJobCV.wait(lk, [&pool] {
                if (pool->stopping.load())
                   return true;
                return !dpQueue.empty() && dpResults.size() < DP_MAX_READY;
            });
            if (pool->stopping.load())
               break;

            job = std::move(dpQueue.front());
            dpQueue.pop_front();
            cfg = dpConfig;
            dpState.queued   = (LONG)dpQueue.size();
            dpState.inFlight = dpState.inFlight + 1;
            if (job.generation==dpGeneration.load())
               dpRunInFlight++;
        }

        if (madeFor!=cfg)
        {
           dpFreeEffects(fx);
           dpMakeEffects(fx, (cfg->applyBlur==1) ? 3 : 0);
           madeFor = cfg;
        }

        ThumbsConfig tcfg;
        tcfg.thumbSize        = cfg->boxSize;
        tcfg.enableCaching    = 0;
        tcfg.alwaysSave       = 0;
        tcfg.wantBitmap       = 1;
        tcfg.userHQraw        = cfg->userHQraw;
        tcfg.allowToneMapping = cfg->allowToneMap;
        tcfg.allowWIC         = cfg->allowWIC;
        tcfg.allowFIM         = cfg->allowFIM;
        tcfg.imgQuality       = cfg->wicQuality;
        tcfg.toneMapAlgo      = cfg->toneMapAlgo;
        tcfg.tmParamA         = cfg->tmParamA;
        tcfg.tmParamB         = cfg->tmParamB;
        tcfg.tmParamC         = cfg->tmParamC;
        tcfg.tmParamD         = cfg->tmParamD;
        tcfg.tmOCVparamA      = cfg->tmOCVparamA;
        tcfg.tmOCVparamB      = cfg->tmOCVparamB;
        tcfg.tmAltExpo        = cfg->tmAltExpo;
        tcfg.firstFIM         = cfg->firstFIM;
        tcfg.colorManage      = 0;

        DupePixResult res;
        bool ranIt = false;
        try
        {
            if (!dpJobAbandoned(job.generation, pool.get()))
            {
               dpMarkBusy(pool.get(), mySlot, &job.path, 1);
               if (tpFileExtension(job.path)==L"pdf")
               {
                  std::unique_lock<std::timed_mutex> pdfLock(pdfiumMutex, std::defer_lock);
                  while (!dpJobAbandoned(job.generation, pool.get()))
                  {
                     if (!pdfLock.try_lock_for(std::chrono::milliseconds(25)))
                        continue;
                     if (dpJobAbandoned(job.generation, pool.get()))
                        break;
                     // refused while anybody is queued for a slot; the queue below is the way in then
                     if (tpTryTakeJobSlotNow())
                     {
                        TpJobSlot slot;
                        dpMarkBusy(pool.get(), mySlot, NULL, 2);
                        dpRunJob(fac, d2dFac, fx, *cfg, tcfg, job, res, pool.get(), &pdfLock);
                        ranIt = true;
                        break;
                     }
                     pdfLock.unlock();
                     if (!dpAcquireJobSlot(job.generation))
                        break;
                     bool gotPdf = false;
                     {
                        TpJobSlot slot;
                        if (pdfLock.try_lock())
                        {
                           gotPdf = true;
                           if (!dpJobAbandoned(job.generation, pool.get()))
                           {
                              dpMarkBusy(pool.get(), mySlot, NULL, 2);
                              dpRunJob(fac, d2dFac, fx, *cfg, tcfg, job, res, pool.get(), &pdfLock);
                              ranIt = true;
                           }
                        }
                     }
                     if (gotPdf)
                        break;
                     std::this_thread::sleep_for(std::chrono::milliseconds(25));
                  }
               } else if (dpAcquireJobSlot(job.generation))
               {
                  dpMarkBusy(pool.get(), mySlot, NULL, 2);
                  TpJobSlot slot;
                  dpRunJob(fac, d2dFac, fx, *cfg, tcfg, job, res, pool.get());
                  ranIt = true;
               }
            }
        } catch (...)
        {
            res.imgidu = job.imgidu;
            res.status = DP_ERR_PROCESS;
            ranIt = true;
        }

        {
            std::lock_guard<std::mutex> lk(dpMutex);
            pool->busy[mySlot].startedMs = 0;
            pool->busy[mySlot].state.store(0, std::memory_order_relaxed);
            pool->busy[mySlot].path.clear();
            if (dpPool==pool)
            {
               if (dpState.inFlight > 0)
                  dpState.inFlight = dpState.inFlight - 1;
               if (job.generation==dpGeneration.load() && dpRunInFlight > 0)
                  dpRunInFlight--;

               if (ranIt && job.generation==dpGeneration.load())
               {
                  try
                  {
                      dpResults.push_back(std::move(res));
                      dpState.ready = (LONG)dpResults.size();
                  } catch (...)
                  {
                      dpDroppedResults++;
                  }
               }
            }
        }
    }

    dpFreeEffects(fx);
    SafeRelease(d2dFac, "dpWorkerBody: d2dFac", 0);
    if (ownFactory)
       SafeRelease(fac, "dpWorkerBody: fac", 0);

    if (SUCCEEDED(hrCo))
       CoUninitialize();

    {
        std::lock_guard<std::mutex> lk(dpMutex);
        pool->exited++;
    }
    dpExitCV.notify_all();
}

// drops everything queued and everything decoded but not yet written; jobs already in
// flight carry the old generation and are discarded by their worker
static void dpCancelLocked() {
    dpGeneration.fetch_add(1);
    dpRunInFlight = 0;
    dpDroppedResults = 0;
    dpQueue.clear();
    dpResults.clear();
    dpState.queued = 0;
    dpState.ready  = 0;
}

// ---------------------------------------------------------------------------------------
//  the database side; all of it runs on the thread that calls dupesPixStep()
// ---------------------------------------------------------------------------------------

static void dpFinalizeStatements() {
    if (!SQ.ok)
       return;

    if (dpSelect!=NULL)   { SQ.finalize(dpSelect);   dpSelect = NULL; }
    if (dpUpdHist!=NULL)  { SQ.finalize(dpUpdHist);  dpUpdHist = NULL; }
    if (dpUpdPix!=NULL)   { SQ.finalize(dpUpdPix);   dpUpdPix = NULL; }
    if (dpMarkDead!=NULL) { SQ.finalize(dpMarkDead); dpMarkDead = NULL; }
}

static void dpBindBlobOrNull(sqlite3_stmt *st, int idx, const std::vector<unsigned char> &v) {
    if (v.empty())
    {
       if (SQ.bind_null!=NULL)
          SQ.bind_null(st, idx);
       return;
    }

    if (SQ.bind_blob!=NULL)
       SQ.bind_blob(st, idx, v.data(), (int)v.size(), QPV_SQLITE_STATIC);
}

// imgpixfmt, spelled the way the loader that actually decoded the image spells it in
// mainLoadedIMGdetails.PixelFormat:
//    1 WIC        WicPixelFormats(index)                     "24-bpp - BGR"
//    2 FreeImage  bpp "-" colourType + tone mapping marker   "48-RGB (TONE-MAPPED)"
//    3 SVG, 4 PDF a constant, out of dpLoaderNames
//    5            the CACHED thumbnail file, which describes nothing about the original
//    6 GDI+       nothing: the interpreter sends no table for it, and the names
//                 Gdip_GetImagePixelFormat() spells are its own to give. The column is left
//                 as it was and the single threaded pass fills it - which is why the
//                 statement in dupesPixBegin() COALESCEs it.
// An empty result is written as NULL rather than as an empty string: "collected, and the
// format is blank" and "never collected" have to stay distinguishable, or the collection
// pass that fills the gaps decodes those images again on every single run.
//
// Shared: the collection pool writes the answer into the database, and the thumbnails pool
// hands it to QPV_ThumbsPoolDrain() through qpvGetPixelFormatName(). One format must have
// one spelling however it was produced, or every grouping and filter over the column
// splits in half.
static std::wstring qpvPixelFormatName(int loaderUsed, const TpSrcMeta &meta) {
    if (loaderUsed==1)
    {
       if (dpWicNames.empty())
          return std::wstring();

       // index 0 is what indexedWICpixelFormats() answers for a format it does not know
       // and what WicPixelFormats() spells "UNKNOWN" - which is also the honest answer for
       // a frame whose pixel format WIC would not report at all
       const size_t idx = (meta.wicFmt > 0 && (size_t)meta.wicFmt < dpWicNames.size())
                        ? (size_t)meta.wicFmt : 0;
       return dpWicNames[idx];
    }

    if (loaderUsed==2 && meta.fimBPP > 0
     && meta.fimColor >= 0 && (size_t)meta.fimColor < dpFimNames.size())
    {
       std::wstring out = std::to_wstring(meta.fimBPP);
       out += L"-";
       out += dpFimNames[meta.fimColor];
       if (meta.fimToneMap==1)
          out += L" (TONE-MAPPED)";
       else if (meta.fimToneMap==2)
          out += L" (TONE-MAPPABLE)";

       return out;
    }

    if (loaderUsed > 0 && (size_t)loaderUsed < dpLoaderNames.size())
       return dpLoaderNames[loaderUsed];

    return std::wstring();
}

static bool dpWriteResult(const DupePixResult &res) {
    if (res.status!=DP_OK)
    {
       if (res.status==DP_ERR_LOAD && dpMarkDead!=NULL)
       {
          SQ.reset(dpMarkDead);
          SQ.bind_int64(dpMarkDead, 1, res.imgidu);
          const bool ok = (SQ.step(dpMarkDead)==SQLITE_DONE);
          SQ.reset(dpMarkDead);
          return ok;
       }
       return true;
    }

    bool okay = true;
    if (dpUpdHist!=NULL)
    {
       // alive until the step/reset pair below, which is what lets it be bound STATIC;
       // nByte counts BYTES for bind_text16, so -1 and let SQLite measure the string
       const std::wstring pixFmt = qpvPixelFormatName(res.loaderUsed, res.meta);

       SQ.reset(dpUpdHist);
       SQ.bind_double(dpUpdHist,  1, res.median);
       SQ.bind_double(dpUpdHist,  2, res.avg);
       SQ.bind_double(dpUpdHist,  3, res.peak);
       SQ.bind_double(dpUpdHist,  4, res.low);
       SQ.bind_double(dpUpdHist,  5, res.rms);
       SQ.bind_double(dpUpdHist,  6, res.range);
       SQ.bind_double(dpUpdHist,  7, res.mode);
       SQ.bind_double(dpUpdHist,  8, res.minu);
       // NULL means "this loader could not say", which the COALESCE above turns into
       // "leave the column as it is"; every one of these is a real value or nothing
       if (res.width > 0)
          SQ.bind_int64(dpUpdHist, 9, res.width);
       else
          SQ.bind_null(dpUpdHist, 9);

       if (res.height > 0)
          SQ.bind_int64(dpUpdHist, 10, res.height);
       else
          SQ.bind_null(dpUpdHist, 10);

       SQ.bind_int64(dpUpdHist,  11, (res.meta.frames > 0) ? res.meta.frames : 1);
       if (res.meta.dpi > 0)
          SQ.bind_int64(dpUpdHist, 12, res.meta.dpi);
       else
          SQ.bind_null(dpUpdHist, 12);

       if (pixFmt.empty())
          SQ.bind_null(dpUpdHist, 13);
       else
          SQ.bind_text16(dpUpdHist, 13, pixFmt.c_str(), -1, QPV_SQLITE_STATIC);

       SQ.bind_int64(dpUpdHist,  14, res.fsize);
       SQ.bind_int64(dpUpdHist,  15, res.fmodified);
       SQ.bind_int64(dpUpdHist,  16, res.fcreated);
       SQ.bind_int64(dpUpdHist,  17, res.imgidu);
       if (SQ.step(dpUpdHist)!=SQLITE_DONE)
          okay = false;

       SQ.reset(dpUpdHist);
    }

    if (dpUpdPix!=NULL)
    {
       SQ.reset(dpUpdPix);
       SQ.bind_int64(dpUpdPix, 1, res.imgidu);
       dpBindBlobOrNull(dpUpdPix, 2, res.small);
       dpBindBlobOrNull(dpUpdPix, 3, res.big);
       dpBindBlobOrNull(dpUpdPix, 4, res.smallH);
       dpBindBlobOrNull(dpUpdPix, 5, res.bigH);
       if (SQ.step(dpUpdPix)!=SQLITE_DONE)
          okay = false;

       SQ.reset(dpUpdPix);
    }

    return okay;
}

// Refills the queue from the SELECT.
//
// The cursor is a keyset one - "... AND imgidu > ?2 ORDER BY imgidu LIMIT ?1" - which the
// hash loop of dupes-search.h now walks too, though for the other of the two reasons. Here
// it is a correctness one: a row is not written the moment it is handed out, it goes to a
// worker, comes back some milliseconds later and is written then, so re-running a bare
// LIMIT in the meantime would hand out the very same rows again because they still match.
// There a row is written before the next batch reads, and the cursor is what keeps the
// batch from re-walking every row already done. Remembering the highest imgidu handed out
// is what makes each row leave exactly once.
//
// It also bounds the run: a row that is decoded and then fails to be written is behind the
// cursor and is not offered again, so a persistent write failure cannot spin forever.
// Resuming later is unaffected - the cursor starts at zero and the rows that were written
// no longer match the WHERE at all.
static int dpTopUpQueue(int want) {
    if (dpSelect==NULL || want < 1)
       return 0;

    SQ.reset(dpSelect);
    if (SQ.bind_int64!=NULL)
    {
       SQ.bind_int64(dpSelect, 1, want);
       SQ.bind_int64(dpSelect, 2, dpLastID);
    }

    int added = 0, seen = 0;
    std::vector<INT64> deadIds;
    try
    {
        for (;;)
        {
            const int rc = SQ.step(dpSelect);
            if (rc!=SQLITE_ROW)
            {
               if (rc!=SQLITE_DONE)
               {
                  if (rc==SQLITE_INTERRUPT)
                  {
                     dupesSetError(L"the pixel-collection query was cancelled", dpDB);
                     dpState.lastError = 0;
                  } else
                  {
                     dupesSetError(L"the pixel-collection query failed", dpDB);
                     dpState.lastError = 6;
                  }
                  SQ.reset(dpSelect);
                  return -1;
               }
               break;
            }

            seen++;
            DupePixJob job;
            job.imgidu = (INT64)SQ.column_int64(dpSelect, 0);
            if (job.imgidu > dpLastID)
               dpLastID = job.imgidu;

            const wchar_t *p = (const wchar_t*)SQ.column_text16(dpSelect, 1);
            const int plen = (p!=NULL) ? SQ.column_bytes16(dpSelect, 1)/(int)sizeof(wchar_t) : 0;
            if (plen < 1)
            {
               deadIds.push_back(job.imgidu);
               dpState.submitted = dpState.submitted + 1;
               continue;
            }

            job.path.assign(p, (size_t)plen);
            job.generation = dpGeneration.load();
            {
                std::lock_guard<std::mutex> lk(dpMutex);
                dpQueue.push_back(std::move(job));
                dpState.queued = (LONG)dpQueue.size();
            }
            added++;
            dpState.submitted = dpState.submitted + 1;
        }
    } catch (...)
    {
        SQ.reset(dpSelect);
        dpState.lastError = 1;
        return -1;
    }

    SQ.reset(dpSelect);

    for ( size_t i = 0 ; i < deadIds.size() ; i++)
    {
        bool marked = true;
        if (dpMarkDead!=NULL)
        {
           SQ.reset(dpMarkDead);
           SQ.bind_int64(dpMarkDead, 1, deadIds[i]);
           marked = (SQ.step(dpMarkDead)==SQLITE_DONE);
           SQ.reset(dpMarkDead);
        }
        if (marked)
           dpState.failed = dpState.failed + 1;
        else
           dpState.dbErrors = dpState.dbErrors + 1;
    }

    if (seen < want)
       dpSetDrained(true);

    if (added > 0)
       dpJobCV.notify_all();

    return added;
}

// ---------------------------------------------------------------------------------------
//  exports
// ---------------------------------------------------------------------------------------

DLL_API int DLL_CALLCONV dupesPixInit(int nThreads) {
    std::lock_guard<std::mutex> lk(dpMutex);
    if (!dpWorkers.empty())
       return (int)dpWorkers.size();

    bindFreeImageOnce();
    if (m_pIWICFactory==NULL)
    {
       QPV_DBG("dupesPixels: cannot start, WIC was not initialized; call initWICnow() first");
       return 0;
    }

    nThreads = clamp(nThreads, 1, DP_MAX_WORKERS);
    try
    {
        std::shared_ptr<DpPool> pool = std::make_shared<DpPool>();
        dpWorkers.reserve(nThreads);
        dpPool = pool;
        for ( int i = 0 ; i < nThreads ; i++)
            dpWorkers.push_back(std::thread(dpWorkerBody, pool, (size_t)i));
    } catch (...)
    {
        if (dpWorkers.empty())
           dpPool.reset();
    }

    dpState.alive = (LONG)dpWorkers.size();
    QPV_DBG("dupesPixels: started with " + std::to_string(dpWorkers.size()) + " workers");
    return (int)dpWorkers.size();
}

DLL_API void* DLL_CALLCONV dupesPixGetState() {
    return (void*)&dpState;
}

DLL_API INT64 DLL_CALLCONV dupesPixBusyJob(wchar_t *out, int cch, int *state) {
    if (out!=NULL && cch > 0)
       out[0] = 0;
    if (state!=NULL)
       *state = 0;

    const INT64 now = (INT64)GetTickCount64();
    INT64 oldest = -1;
    size_t which = 0;
    std::lock_guard<std::mutex> lk(dpMutex);
    if (!dpPool)
       return -1;

    for ( size_t i = 0 ; i < (size_t)DP_MAX_WORKERS ; i++)
    {
        const INT64 started = dpPool->busy[i].startedMs;
        if (started==0)
           continue;

        const INT64 held = (now > started) ? now - started : 0;
        if (held > oldest)
        {
           oldest = held;
           which = i;
        }
    }

    if (oldest < 0)
       return -1;

    if (state!=NULL)
       *state = dpPool->busy[which].state.load(std::memory_order_relaxed);

    if (out!=NULL && cch > 1)
    {
       const std::wstring &p = dpPool->busy[which].path;
       const size_t room = (size_t)cch - 1;
       const size_t n = (p.size() < room) ? p.size() : room;
       if (n > 0)
          memcpy(out, p.c_str(), n*sizeof(wchar_t));

       out[n] = 0;
    }

    return oldest;
}

DLL_API int DLL_CALLCONV dupesPixWorkStates(int *waiting, int *decoding, int *active, int *cap) {
    std::shared_ptr<DpPool> pool;
    {
        std::lock_guard<std::mutex> lk(dpMutex);
        pool = dpPool;
    }

    int nWait = 0, nDecode = 0;
    if (pool)
    {
       for ( size_t i = 0 ; i < (size_t)DP_MAX_WORKERS ; i++)
       {
           const int st = pool->busy[i].state.load(std::memory_order_relaxed);
           if (st==1)
              nWait++;
           else if (st==2)
              nDecode++;
       }
    }

    if (waiting!=NULL)
       *waiting = nWait;
    if (decoding!=NULL)
       *decoding = nDecode;
    if (active!=NULL)
       *active = (int)tpActiveJobs.load(std::memory_order_relaxed);
    if (cap!=NULL)
       *cap = (tpMemTight.load(std::memory_order_relaxed)!=0) ? 1 : (int)tpSlotCap.load(std::memory_order_relaxed);

    return 1;
}

// "|" separated, one entry per index, all three tables built by the interpreter out of the
// very functions that name a pixel format everywhere else in the product -
// WicPixelFormats(), the colour type table of FreeImage_GetColorType(), and the constants
// RenderSVGfile() and RenderPDFpage() report. Sent once by initQPVmainDLL(), the way
// thumbsPoolSetFormats() sends the extension lists.
//
// Without it imgpixfmt is simply left NULL, which the next collection pass fills in; what
// must never happen is this file inventing its own spelling for a format, because then one
// format sits in the column under two names and every grouping and filter over it splits.
static void dpSplitNames(const wchar_t *packed, std::vector<std::wstring> &out) {
    out.clear();
    if (packed==NULL)
       return;

    std::wstring cur;
    for ( const wchar_t *p = packed ; ; p++)
    {
        if (*p==L'|' || *p==0)
        {
           out.push_back(cur);
           cur.clear();
           if (*p==0)
              break;
        } else cur.push_back(*p);
    }
}

DLL_API int DLL_CALLCONV qpvSetPixelFormatNames(const wchar_t *wicNames, const wchar_t *fimColorNames,
                                                const wchar_t *loaderNames) {
    dpSplitNames(wicNames, dpWicNames);
    dpSplitNames(fimColorNames, dpFimNames);
    dpSplitNames(loaderNames, dpLoaderNames);
    return (int)(dpWicNames.size() + dpFimNames.size() + dpLoaderNames.size());
}

// The same name, for the caller that is not writing a database row: QPV_ThumbsPoolDrain()
// asks for it once per image the thumbnails workers read off disk, so that a thumbnail and
// a collection run put the same string in front of the user for the same file.
// Returns the number of characters written, 0 when there is no name for that loader.
DLL_API int DLL_CALLCONV qpvGetPixelFormatName(int loaderUsed, int wicFmt, int fimBPP, int fimColor,
                                               int fimToneMap, wchar_t *out, int cch) {
    if (out==NULL || cch < 1)
       return 0;

    out[0] = 0;
    TpSrcMeta meta;
    meta.wicFmt     = wicFmt;
    meta.fimBPP     = fimBPP;
    meta.fimColor   = fimColor;
    meta.fimToneMap = fimToneMap;

    const std::wstring name = qpvPixelFormatName(loaderUsed, meta);
    if (name.empty())
       return 0;

    const size_t room = (size_t)cch - 1;
    const size_t n = (name.size() < room) ? name.size() : room;
    memcpy(out, name.c_str(), n*sizeof(wchar_t));
    out[n] = 0;
    return (int)n;
}

// packedOptions is "|" delimited, the same shape thumbsPoolBegin() takes:
//   0 boxSize | 1 interpolation | 2 applyBlur | 3 wantFlipped | 4 allowWIC | 5 allowFIM
//   6 userHQraw | 7 allowToneMapping
DLL_API int DLL_CALLCONV dupesPixBegin(void *ahkDb, const wchar_t *selectSQL, const wchar_t *packedOptions) {
    bindSQLiteOnce();
    dupesEngineError.clear();
    bool hasWorkers = false;
    {
        std::lock_guard<std::mutex> lk(dpMutex);
        hasWorkers = !dpWorkers.empty();
    }
    if (!SQ.ok || ahkDb==NULL || selectSQL==NULL || !hasWorkers)
       return 0;

    if (SQ.bind_double==NULL || SQ.bind_blob==NULL || SQ.bind_null==NULL)
    {
       QPV_DBG("dupesPixels: sqlite3.dll is missing the bind entry points this needs");
       return 0;
    }

    std::shared_ptr<DupePixCfg> cfg = std::make_shared<DupePixCfg>();
    if (packedOptions!=NULL)
    {
       std::vector<double> v;
       std::wstring cur;
       for ( const wchar_t *p = packedOptions ; ; p++)
       {
           if (*p==L'|' || *p==0)
           {
              v.push_back(cur.empty() ? 0.0 : _wtof(cur.c_str()));
              cur.clear();
              if (*p==0)
                 break;
           } else cur.push_back(*p);
       }

       #define DPOPT(i, def) ((v.size() > (size_t)(i)) ? v[i] : (double)(def))
       cfg->boxSize        = (int)DPOPT(0, 350);
       cfg->interpolation  = (int)DPOPT(1, 5);
       cfg->applyBlur      = (int)DPOPT(2, 0);
       cfg->wantFlipped    = (int)DPOPT(3, 0);
       cfg->allowWIC       = (int)DPOPT(4, 1);
       cfg->allowFIM       = (int)DPOPT(5, 1);
       cfg->userHQraw      = (int)DPOPT(6, 1);
       cfg->allowToneMap   = (int)DPOPT(7, 1);
       cfg->toneMapAlgo    = (int)DPOPT(8, 0);
       cfg->tmParamA       = (float)DPOPT(9, 0);
       cfg->tmParamB       = (float)DPOPT(10, 0);
       cfg->tmParamC       = (float)DPOPT(11, 0);
       cfg->tmParamD       = (float)DPOPT(12, 0);
       cfg->tmOCVparamA    = (float)DPOPT(13, 0);
       cfg->tmOCVparamB    = (float)DPOPT(14, 0);
       cfg->tmAltExpo      = (int)DPOPT(15, 0);
       cfg->firstFIM       = (int)DPOPT(16, 0);
       #undef DPOPT
    }

    cfg->boxSize = clamp(cfg->boxSize, 32, 4096);
    // hamDistInterpolation picks NearestNeighbor or HighQualityBilinear for the shrink to
    // 9x8 / 32x32; the same choice asks WIC for its better scaler on the way in
    cfg->interpolation = (cfg->interpolation==6) ? 6 : 5;
    cfg->wicQuality    = (cfg->interpolation==6) ? 7 : 5;

    dpFinalizeStatements();
    dpDB = (sqlite3*)ahkDb;
    dpSetDrained(false);
    dpLastID = 0;

    if (SQ.prepare16_v2(dpDB, selectSQL, -1, &dpSelect, NULL)!=SQLITE_OK || dpSelect==NULL)
    {
       dupesSetError(L"could not prepare the pixel-collection query", dpDB);
       dpSelect = NULL;
       return 0;
    }

    // Every column the serial collection this replaced wrote out of one decode:
    // getImgHistoValuesSet(), then getImgPropsValuesSet() - imgwidth, imgheight, imgframes,
    // imgdpi and imgpixfmt - then getImgFileValuesSet(). imgwhratio and imgmegapix are
    // generated from imgwidth and imgheight and follow on their own.
    //
    // The five image properties are COALESCEd, the eight statistics and the three file
    // stamps are not. Not every loader can describe the original: PDFium's render says
    // nothing about the document's pixel format, and GDI+ has no name table here at all, so
    // those come back empty - and binding them straight would erase what another producer
    // had already written and leave the next collection pass re-decoding those files for
    // ever, because "collected, and the format is blank" and "never collected" are the same
    // thing to ifnull(imgpixfmt,'')=''. This is poolRecordImgProps()'s rule in the AHK: a
    // loader that could not name the format must not erase a name something else knew.
    static const wchar_t *updHistSQL =
        L"UPDATE images SET imgmedian=?1, imgavg=?2, imghpeak=?3, imghlow=?4, imghrms=?5,"
        L" imghrange=?6, imghmode=?7, imghminu=?8,"
        L" imgwidth=COALESCE(?9, imgwidth), imgheight=COALESCE(?10, imgheight),"
        L" imgframes=COALESCE(?11, imgframes), imgdpi=COALESCE(?12, imgdpi),"
        L" imgpixfmt=COALESCE(?13, imgpixfmt),"
        L" fsize=?14, fmodified=?15, fcreated=?16 WHERE imgidu=?17;";
    static const wchar_t *updPixSQL =
        L"INSERT INTO imagesPixels (imgidu, small, big, smallH, bigH) VALUES (?1,?2,?3,?4,?5)"
        L" ON CONFLICT(imgidu) DO UPDATE SET"
        L" small=COALESCE(excluded.small, imagesPixels.small),"
        L" big=COALESCE(excluded.big, imagesPixels.big),"
        L" smallH=COALESCE(excluded.smallH, imagesPixels.smallH),"
        L" bigH=COALESCE(excluded.bigH, imagesPixels.bigH);";
    static const wchar_t *markDeadSQL =
        L"UPDATE images SET isDeleted=1 WHERE imgidu=?1;";

    if (SQ.prepare16_v2(dpDB, updHistSQL, -1, &dpUpdHist, NULL)!=SQLITE_OK
     || SQ.prepare16_v2(dpDB, updPixSQL, -1, &dpUpdPix, NULL)!=SQLITE_OK
     || SQ.prepare16_v2(dpDB, markDeadSQL, -1, &dpMarkDead, NULL)!=SQLITE_OK)
    {
       dupesSetError(L"could not prepare the pixel-collection updates", dpDB);
       dpFinalizeStatements();
       return 0;
    }

    {
        std::lock_guard<std::mutex> lk(dpMutex);
        dpCancelLocked();
        dpConfig = cfg;
        dpState.written = dpState.failed = dpState.dbErrors = dpState.submitted = 0;
        dpState.lastError = 0;
        dpState.phase = 1;
    }

    if (!dpHoldsCVclamp)
    {
       dpHoldsCVclamp = true;
       tpCVclampAcquire();
    }

    dupesPixCancel.store(0, std::memory_order_relaxed);
    dpJobCV.notify_all();
    return 1;
}

// Keeps the queue fed, writes back whatever the workers finished, and returns 1 while
// there is more to do, 0 when the run is complete, -1 on a database failure.
// The caller keeps its transaction and its periodic COMMIT, so an interrupted run keeps
// every image it finished - which is what "you can stop and resume this process at
// anytime" rests on.
DLL_API int DLL_CALLCONV dupesPixStep(int msBudget) {
    if (!SQ.ok || dpSelect==NULL)
       return -1;

    if (msBudget < 1)
       msBudget = 1;

    if (dupesPixCancel.load()!=0)
    {
       dpState.phase = -1;
       return 0;
    }

    const int workers = (int)dpWorkers.size();
    const int highWater = clamp(workers*5 + 2, 8, 128);
    const std::chrono::steady_clock::time_point tStart = std::chrono::steady_clock::now();

    for (;;)
    {
        // 1. keep every worker busy
        if (!dpSelectDrained)
        {
           int pending;
           {
               std::lock_guard<std::mutex> lk(dpMutex);
               pending = (int)dpQueue.size() + (int)dpState.inFlight;
           }
           if (pending < highWater)
           {
              if (dpTopUpQueue(highWater - pending) < 0)
              {
                 dpState.phase = -1;
                 return -1;
              }
           }
        }

        // 2. write back whatever is ready
        std::deque<DupePixResult> batch;
        LONG dropped = 0;
        {
            std::lock_guard<std::mutex> lk(dpMutex);
            batch.swap(dpResults);
            dpState.ready = 0;
            dropped = dpDroppedResults;
            dpDroppedResults = 0;
        }
        if (dropped > 0)
           dpState.failed = dpState.failed + dropped;

        if (!batch.empty())
        {
           for ( size_t i = 0 ; i < batch.size() ; i++)
           {
               if (batch[i].status==DP_OK)
               {
                  if (dpWriteResult(batch[i]))
                     dpState.written = dpState.written + 1;
                  else
                     dpState.dbErrors = dpState.dbErrors + 1;
               } else
               {
                  if (dpWriteResult(batch[i]))
                     dpState.failed = dpState.failed + 1;
                  else
                     dpState.dbErrors = dpState.dbErrors + 1;
               }
           }
           dpJobCV.notify_all();   // room was made, parked workers may resume
        }

        // 3. is anything still outstanding?
        bool idle;
        {
            std::lock_guard<std::mutex> lk(dpMutex);
            idle = dpQueue.empty() && dpRunInFlight==0 && dpResults.empty() && dpDroppedResults==0;
        }
        if (idle && dpSelectDrained)
        {
           dpState.phase = 5;
           return 0;
        }

        if (std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - tStart).count() >= msBudget)
           return 1;

        if (batch.empty())
           std::this_thread::sleep_for(std::chrono::milliseconds(2));

        if (dupesPixCancel.load()!=0)
        {
           dpState.phase = -1;
           return 0;
        }
    }
}

DLL_API INT64 DLL_CALLCONV dupesPixWrittenCount() { return (INT64)dpState.written; }
DLL_API INT64 DLL_CALLCONV dupesPixFailedCount()  { return (INT64)dpState.failed; }

DLL_API int DLL_CALLCONV dupesPixEnd() {
    {
        std::lock_guard<std::mutex> lk(dpMutex);
        dpCancelLocked();
    }
    dpJobCV.notify_all();

    if (dpHoldsCVclamp)
    {
       dpHoldsCVclamp = false;
       tpCVclampRelease();
    }

    dpFinalizeStatements();
    dpDB = NULL;
    dpSetDrained(false);
    dpLastID = 0;
    if (dpState.phase!=-1)
       dpState.phase = 0;

    return 1;
}

DLL_API int DLL_CALLCONV dupesPixShutdown() {
    std::vector<std::thread> workers;
    std::shared_ptr<DpPool> pool;
    {
        std::lock_guard<std::mutex> lk(dpMutex);
        if (dpWorkers.empty())
        {
           dpFinalizeStatements();
           dpDB = NULL;
           if (dpHoldsCVclamp)
           {
              dpHoldsCVclamp = false;
              tpCVclampRelease();
           }
           return 1;
        }

        dpCancelLocked();
        pool = dpPool;
        dpPool.reset();
        if (pool)
           pool->stopping.store(true);
        workers.swap(dpWorkers);
    }

    dpJobCV.notify_all();

    bool allOut = false;
    {
        std::unique_lock<std::mutex> lk(dpMutex);
        allOut = dpExitCV.wait_for(lk, std::chrono::seconds(5), [&workers, &pool] {
            return !pool || pool->exited >= workers.size();
        });
    }

    for ( size_t i = 0 ; i < workers.size() ; i++)
    {
        if (!workers[i].joinable())
           continue;

        if (allOut)
           workers[i].join();
        else
           workers[i].detach();
    }

    {
        std::lock_guard<std::mutex> lk(dpMutex);
        dpCancelLocked();
        dpState.alive    = 0;
        dpState.inFlight = 0;
    }

    if (dpHoldsCVclamp)
    {
       dpHoldsCVclamp = false;
       tpCVclampRelease();
    }

    dpFinalizeStatements();
    dpDB = NULL;
    QPV_DBG(allOut ? "dupesPixels: shut down" : "dupesPixels: shut down with a worker still busy");
    return allOut ? 1 : 0;
}

#endif // QPV_DUPES_PIXELS_H
