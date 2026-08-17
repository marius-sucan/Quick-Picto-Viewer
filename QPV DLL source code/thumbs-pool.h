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
// IsFileExtension(), LoadSVGimage(), RenderPdfPageAsBitmap(), openCVresizeBitmapExtended(),
// openCVapplyToneMappingAlgos() and the SEH filter of the WIC guards, WICcodecCrashFilter(),
// directly.
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
#include <cstddef>
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
#define TP_MAX_READY_BYTES (78ull*1024*1024)  // ... and the memory they may hold on to

// Memory pressure. Above any of these the pool narrows down to a single running job,
// so that images keep coming - slowly - instead of everything grinding to a halt.
// The percentage mirrors what QPV_ShowThumbnails() used to test on every iteration of its
// inner loop; the absolute floor matters on machines where 10% of the RAM is still plenty.
//
// TWO sets of thresholds, because most of the pressure is self-inflicted: the decodes this
// throttles are what pushed the machine over the line, so the moment it narrows down to one
// image the memory comes back and a single set would read "plenty" again one sample later -
// with every waiting worker let through at once, and the machine straight back over the
// line. The throttle is entered at the HIGH/FLOOR values and left only at the LOW/CLEAR
// ones, and even then one worker at a time; see tpMemoryIsTight() and tpSlotCap.
#define TP_MEM_LOAD_HIGH   90                   // % of the physical memory in use: throttle at or above
#define TP_MEM_LOAD_LOW    80                   // ... and stop throttling only at or below
#define TP_MEM_FREE_FLOOR  (768ull*1024*1024)   // 768 mb of free physical memory, or of commit headroom
#define TP_MEM_FREE_CLEAR  (1536ull*1024*1024)  // ... and twice that before the throttle is lifted
// The address space of THIS process, which is the wall the 32 bits build hits long before
// the machine runs out of anything: a GlobalMemoryStatusEx() reporting nine free gigabytes
// says nothing about a two gigabyte process with 300 mb of address space left, and one
// worker decoding a large photograph can want a few hundred megabytes of it. The process
// half of the GetProcessMemoryUsage() + GlobalMemoryStatusEx() pair this replaced was the
// only thing that ever saw that, and ullAvailVirtual is that half at no extra cost - it
// comes back in the same struct. On x64 both values are astronomical and never trip.
#define TP_MEM_VIRT_FLOOR  (512ull*1024*1024)
#define TP_MEM_VIRT_CLEAR  (768ull*1024*1024)
#define TP_MEM_SAMPLE_MS   950

// The most decodes the throttle ever allows at once. Both pools clamp themselves to 32
// workers, so this is "no limit at all" rather than a policy.
#define TP_SLOT_CAP_MAX    64
// How long a worker queued for a slot sleeps before looking again when nothing wakes it.
// Releasing a slot does wake it; this is the backstop, and what picks up a cap that grew
// while it slept.
#define TP_SLOT_POLL_MS    25

// ---------------------------------------------------------------------------------------
//  the properties of the image as it came off the disk
// ---------------------------------------------------------------------------------------

// Everything here describes the ORIGINAL file, and every field is read before the loader
// scales the image or converts it to anything: a 350 pixel box of 32bppPARGB says nothing
// about the frame count, the resolution or the pixel format of the RAW it came from, and
// those three are exactly what the database keeps in imgframes, imgdpi and imgpixfmt, and
// what resultedFilesList[] holds in its columns 9, 22 and 15.
//
// The pixel format is left as raw numbers on purpose. The strings are the interpreter's -
// WicPixelFormats() and FreeImage_GetColorType() in the AHK - and they reach the DLL
// through qpvSetPixelFormatNames(); composing them here would be a second copy of two
// lists that must agree, forever, or one format lands in the column under two spellings
// and every "group by pixel format" splits in half. qpvPixelFormatName() in
// dupes-pixels.h turns these numbers into that string, for both pools.
//
// A loader that is handed no TpSrcMeta pays nothing for it.
#pragma pack(push, 8)
struct TpSrcMeta {
    int frames    = 1;    // total, 1 for a single-frame image, the way imgframes counts
    int dpi       = 0;    // real DPI - NOT FreeImage's dots per metre; see tpFIMthumb()
    int wicFmt    = -1;   // indexedWICpixelFormats(); -1 when this was not a WIC decode
    int fimBPP    = 0;    // FreeImage: bits per pixel of the freshly loaded bitmap
    int fimColor  = -1;   // FreeImage: FREE_IMAGE_COLOR_TYPE; -1 when not a FreeImage decode
    int fimToneMap = 0;   // 0 none, 1 " (TONE-MAPPED)", 2 " (TONE-MAPPABLE)"
};

struct ThumbResult {          // 72 bytes; AHK reads the fields with NumGet()
    INT64 jobId;              //  0
    void* pBitmap;            //  8   GpBitmap*; ownership is transfered to AHK
    int   status;             // 16
    int   savedToFile;        // 20
    int   srcW;               // 24
    int   srcH;               // 28
    int   outW;               // 32
    int   outH;               // 36
    int   elapsedMs;          // 40
    int   loaderUsed;         // 44   1=WIC 2=FreeImage 3=SVG 4=PDF 5=cached file 6=GDI+
    // The properties of the ORIGINAL image, for the files list QPV_ThumbsPoolDrain() keeps
    // - see TpSrcMeta. Filled only for a TP_JOB_THUMB job: loader 5 opened a cached
    // thumbnail, whose frame count, resolution and pixel format are the cache file's and
    // say nothing about the picture it was made from. loaderUsed is the test.
    TpSrcMeta meta;           // 48   frames 48, dpi 52, wicFmt 56, fimBPP 60, fimColor 64,
};                            //      fimToneMap 68

// QPV_ThumbsPoolDrain() walks the array thumbsPoolFetch() fills at a stride it hardcodes,
// and poolRecordImgProps() reads the metadata at a byte offset it hardcodes. Both are in
// quick-picto-viewer.ahk, where no compiler will notice a field added here; these two lines
// will. initThumbsPool() refuses a qpvmain.dll that predates the wider record.
static_assert(sizeof(ThumbResult)==72, "ThumbResult changed size: update resultSize in QPV_ThumbsPoolDrain()");
static_assert(offsetof(ThumbResult, meta)==48, "TpSrcMeta moved: update the offsets in poolRecordImgProps()");

struct ThumbsPoolState {      // read-only for AHK
    volatile LONG queued;     //  0
    volatile LONG inFlight;   //  4
    volatile LONG ready;      //  8
    volatile LONG completed;  // 12
    volatile LONG failed;     // 16
    volatile LONG generation; // 20
    volatile LONG alive;      // 24
    volatile LONG memTight;   // 28   1 while decoding is throttled down to a single job
    volatile LONG activeJobs; // 32   images being decoded right now, by EITHER pool of the
                              //      DLL - see tpTryTakeJobSlot(); diagnostic only
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
// How many decodes the throttle allows at this moment, and the workers - of BOTH pools -
// queued for one, oldest first. tpSlotMutex is a leaf lock: it is never taken while tpMutex
// or the collection pool's dpMutex is held, and nothing under it does more than move a few
// numbers about. tpSlotWaiters mirrors tpSlotQueued so that the two places which only need
// to know WHETHER anybody is queued can ask without taking the lock.
//
// A fixed array rather than a container, because this is the code that runs when the
// machine is short of memory and it has no business asking for any: a std::deque takes a
// block from the heap as workers come and go, and a bad_alloc thrown out of here would
// leave a worker thread with nothing to catch it. Both pools clamp themselves to 32
// workers, so TP_SLOT_CAP_MAX places is every thread that can ever be in here at once.
static std::atomic<LONG>                 tpSlotCap{TP_SLOT_CAP_MAX};
static std::atomic<LONG>                 tpSlotWaiters{0};
static std::mutex                        tpSlotMutex;
static std::condition_variable           tpSlotCV;
static ULONGLONG                         tpSlotQueue[TP_SLOT_CAP_MAX] = {0};  // guarded by tpSlotMutex
static int                               tpSlotQueued = 0;                    // guarded by tpSlotMutex
static ULONGLONG                         tpSlotTicket = 0;                    // guarded by tpSlotMutex
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

// qpv-calc-dims-begin
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
// qpv-calc-dims-end

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

// qpv-mem-sample-begin
// One shared memory sample for the whole DLL, refreshed a few times per second. It
// replaces the GetProcessMemoryUsage() + GlobalMemoryStatusEx() pair QPV_ShowThumbnails()
// used to perform on every single iteration of its inner loop, in the calling thread -
// including the process half of it, which ullAvailVirtual is; see TP_MEM_VIRT_FLOOR.
//
// It also carries the cap the throttle enforces, because the two belong together. Snapping
// the cap back to the full worker count the instant a sample reads "plenty" is what made
// this flap: memory recovers precisely BECAUSE the pool narrowed down to one image, so the
// first good sample would let all thirty-two of them start a decoder-sized allocation at
// once - the one thing the throttle exists to prevent - and the sample after that would
// find the machine over the line again. So the cap is raised by ONE per sample instead:
// additive increase, and back to a single decode the moment the machine is short again.
// Nothing here throttles a machine with memory to spare - the cap climbs to
// TP_SLOT_CAP_MAX, which is more workers than either pool can start.
static bool tpMemoryIsTight() {
    const ULONGLONG now = GetTickCount64();
    ULONGLONG stamp = tpMemStamp.load(std::memory_order_relaxed);
    // whoever moves the stamp owns this sample. Without the exchange every worker that
    // arrives in the same millisecond takes one, and the cap below would climb by as many
    // steps as there are workers rather than by one
    if (now - stamp > TP_MEM_SAMPLE_MS && tpMemStamp.compare_exchange_strong(stamp, now))
    {
       MEMORYSTATUSEX ms;
       ms.dwLength = sizeof(ms);
       if (GlobalMemoryStatusEx(&ms))
       {
          const bool wasTight = tpMemTight.load(std::memory_order_relaxed)!=0;
          const bool tight = wasTight
                           ? !(ms.dwMemoryLoad    <= TP_MEM_LOAD_LOW
                            && ms.ullAvailPhys     >= TP_MEM_FREE_CLEAR
                            && ms.ullAvailPageFile >= TP_MEM_FREE_CLEAR
                            && ms.ullAvailVirtual  >= TP_MEM_VIRT_CLEAR)
                           :  (ms.dwMemoryLoad    >= TP_MEM_LOAD_HIGH
                            || ms.ullAvailPhys     <  TP_MEM_FREE_FLOOR
                            || ms.ullAvailPageFile <  TP_MEM_FREE_FLOOR
                            || ms.ullAvailVirtual  <  TP_MEM_VIRT_FLOOR);

          tpMemTight.store(tight ? 1 : 0, std::memory_order_relaxed);
          tpState.memTight = tight ? 1 : 0;
          if (tight)
             tpSlotCap.store(1, std::memory_order_release);
          else
          {
             const LONG cap = tpSlotCap.load(std::memory_order_relaxed);
             if (cap < TP_SLOT_CAP_MAX)
                tpSlotCap.store(cap + 1, std::memory_order_release);
          }
       }
    }

    return tpMemTight.load(std::memory_order_relaxed)!=0;
}
// qpv-mem-sample-end

// One attempt at taking a slot to decode one image. While memory is plentiful every worker
// gets one straight away. When it is not, the cap is one and only the worker that finds no
// other decode running may take it: decoding narrows down to a single image at a time
// rather than stalling altogether, so images keep arriving - slowly - and nobody waits
// forever. Returns false when the caller has to wait and ask again.
//
// The count is one count for the whole DLL, deliberately. Both pools decode images on
// their own worker threads and both can be doing it at the same moment: QPV_ShowThumbnails()
// is reached from a timer and lists a page while a data collection run is in progress -
// that is what the sqlite3_get_autocommit() test around its transaction is there for - so
// the collection workers of dupes-pixels.h keep decoding while it draws. A counter per pool
// would let each of them believe it is the only one and the machine would be asked for two
// decoder-sized allocations at once, which is the single thing this exists to prevent.
//
// Whoever takes a slot must give it back, however the scope is left; TpJobSlot below is the
// way to do that. There is no timeout anywhere in here: the count only ever falls back to
// zero, so a waiting worker is always let through eventually and the queues can never
// wedge, no matter how long memory stays scarce.
static bool tpTryTakeJobSlot() {
    for (;;)
    {
        // Asking for the sample here is also what keeps it fresh: every worker that wants to
        // decode passes through, so while anything at all is waiting on the memory reading it
        // is never older than one sample period. Tight is answered immediately rather than
        // through the cap, which the same sample sets, so that a machine that has just gone
        // short narrows down on this attempt and not on the next one.
        const LONG cap = tpMemoryIsTight() ? 1 : tpSlotCap.load(std::memory_order_acquire);
        LONG active = tpActiveJobs.load(std::memory_order_acquire);
        if (active>=cap)
           return false;

        if (tpActiveJobs.compare_exchange_weak(active, active + 1, std::memory_order_acq_rel))
        {
           tpState.activeJobs = active + 1;
           return true;
        }
        // somebody else moved first, look again
    }
}

// A slot for a worker that has only just arrived, refused while anybody is already queued
// for one - otherwise the queue in tpWaitForJobSlot() would order the workers waiting in it
// and be walked straight past by everyone else. The pair is the fairness between the pools.
static bool tpTryTakeJobSlotNow() {
    return tpSlotWaiters.load(std::memory_order_acquire)==0 && tpTryTakeJobSlot();
}

static void tpReleaseJobSlot() {
    LONG active = tpActiveJobs.fetch_sub(1, std::memory_order_acq_rel) - 1;
    tpState.activeJobs = (active>0) ? active : 0;
    if (tpSlotWaiters.load(std::memory_order_acquire)>0)
    {
       // Taken and dropped again with nothing done under it. The waiters test the count
       // while they hold it, so passing through here is what makes sure this release cannot
       // land between one of those tests and the wait that follows it - the wake that never
       // comes, and a free slot nobody takes for as long as the machine stays short.
       tpSlotMutex.lock();
       tpSlotMutex.unlock();
       // all of them, not one: only the worker at the head of the queue may take this, and
       // waking any of the others instead would leave the slot standing empty
       tpSlotCV.notify_all();
    }
}

// Gives the slot back however the scope is left. Neither decode is supposed to throw -
// both wrap themselves - but the count is shared by both pools now, so one slot leaked by
// either of them would stop the other from ever decoding again for as long as memory stays
// scarce. That is far too much to hang on a catch block somebody may narrow later.
struct TpJobSlot {
    ~TpJobSlot() { tpReleaseJobSlot(); }
};

// Waits for a slot and returns true holding one. Returns false only when shouldQuit() says
// this worker must give up - its pool is shutting down, the run was cancelled, the job it
// is holding belongs to a run that no longer exists - and then nothing was taken.
//
// The queue is what keeps one pool from locking the other out, and it has to be a QUEUE.
// A worker that has just released a slot is back around its loop asking for another one
// microseconds later, while everybody else is asleep: it wins any race that is decided by
// who asks first, every single time, whether that race is over the count or over the mutex
// the waiters share. So the count is not raced for at all - only the worker at the head of
// tpSlotQueue may take a slot, everybody else waits their turn, and a worker that has just
// been served goes to the back. Whichever pool is churning through short jobs then hands
// over to the other one every time instead of never.
//
// Which is not an abstract fairness argument: collectImgDataViaPool() reads a pool that has
// delivered nothing for three minutes as a pool that has stopped, and used to abandon the
// user's run over one that was merely queued.
//
// shouldQuit() is the only reason a wait ends early, and it is asked before every sleep - a
// worker holding a job for a cancelled run must not spend the one decode a machine short of
// memory allows on an image whose result is going to be thrown away.
template <class QuitFn>
static bool tpWaitForJobSlot(QuitFn shouldQuit) {
    // asked before anything else, and before every sleep below: a pool being shut down must
    // not start one more decode, and neither must a worker holding a job nobody wants
    if (shouldQuit())
       return false;

    if (tpTryTakeJobSlotNow())
       return true;

    bool got = false;
    std::unique_lock<std::mutex> lk(tpSlotMutex);
    const ULONGLONG mine = tpSlotTicket++;
    // a caller with no room left in the queue waits without a place in it: it is served
    // less orderly than the others, never wrongly, and with both pools clamped to 32
    // workers there is no such caller
    const bool queued = (tpSlotQueued < TP_SLOT_CAP_MAX);
    if (queued)
    {
       tpSlotQueue[tpSlotQueued] = mine;
       tpSlotQueued++;
       tpSlotWaiters.store((LONG)tpSlotQueued, std::memory_order_release);
    }

    for (;;)
    {
        if (shouldQuit())
           break;

        if ((!queued || tpSlotQueue[0]==mine) && tpTryTakeJobSlot())
        {
           got = true;
           break;
        }

        // A released slot notifies, so this is not really a poll; the timeout is what picks
        // up a cap that grew while this slept, and what keeps a missed notification costing
        // one short sleep rather than the run.
        tpSlotCV.wait_for(lk, std::chrono::milliseconds(TP_SLOT_POLL_MS));
    }

    if (queued)
    {
       for ( int i = 0 ; i < tpSlotQueued ; i++)
           if (tpSlotQueue[i]==mine)
           {
              for ( int j = i + 1 ; j < tpSlotQueued ; j++)
                  tpSlotQueue[j - 1] = tpSlotQueue[j];

              tpSlotQueued--;
              break;
           }

       tpSlotWaiters.store((LONG)tpSlotQueued, std::memory_order_release);
    }

    const bool anyoneLeft = (tpSlotQueued > 0);
    lk.unlock();
    if (anyoneLeft)
       tpSlotCV.notify_all();   // there is a new worker at the head of the queue now

    return got;
}

// qpv-job-slot-end

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
//
// Every call that reaches a codec goes through the SEH guards declared in qpv-main.cpp: a
// worker thread that faults on a corrupt file kills the whole application just as surely
// as the viewport thread would, and the pool is the part of QPV that walks over every
// file in a folder without anyone asking it to.
static Gdiplus::GpBitmap* tpWICload(IWICImagingFactory *fac, const wchar_t *szFileName, int targetW, int targetH,
                                    int frameIndex, int givenQuality, int isFIMokay, int &srcW, int &srcH,
                                    TpSrcMeta *meta = NULL) {
    Gdiplus::GpBitmap     *myBitmap    = NULL;
    IWICBitmapDecoder     *pDecoder    = NULL;
    IWICBitmapFrameDecode *pFrame      = NULL;
    IWICBitmapScaler      *pScaler     = NULL;
    IWICFormatConverter   *pConverter  = NULL;
    IWICBitmapSource      *pSource     = NULL;
    if (!fac || !szFileName || !szFileName[0])
       return myBitmap;

    WICframeFacts facts = {};
    DWORD   sehCode = 0;
    HRESULT hr = WICguardedOpenFrame(fac, szFileName, frameIndex, &pDecoder, &pFrame, &facts, &sehCode);
    if (sehCode!=0)
    {
       fnOutputDebug("thumbsPool: the WIC codec faulted while opening " + WideCharToString(szFileName));
       WICsafeRelease(pFrame);
       WICsafeRelease(pDecoder);
       return myBitmap;
    }

    const UINT owidth = facts.width, oheight = facts.height;
    if (SUCCEEDED(hr) && ((!owidth || !oheight) || (owidth==1 && oheight==1)))
       hr = E_FAIL;

    if (SUCCEEDED(hr) && (owidth>0x7FFFFFFFu || oheight>0x7FFFFFFFu))
       hr = E_FAIL;   // srcW/srcH are ints, and so is everything downstream of them

    if (SUCCEEDED(hr))
    {
       srcW = (int)owidth;
       srcH = (int)oheight;

       if (meta!=NULL)
       {
          // WICpreLoadImage() records exactly these two, off the same frame and before
          // anything is scaled or converted; the numbers reach the database through
          // WicPixelFormats() and mainLoadedIMGdetails.DPI
          if (facts.frames>0)
             meta->frames = (int)facts.frames;

          if (facts.gotPixelFmt)
             meta->wicFmt = (int)indexedWICpixelFormats(facts.pixelFmt);

          // a NaN or absurd resolution out of broken metadata used to convert into
          // garbage; both comparisons are false for NaN, which lands on nothing recorded
          const double dpiAvg = (facts.dpix + facts.dpiy) * 0.5;
          if (facts.gotResolution && dpiAvg>0.0 && dpiAvg<1000000.0)
             meta->dpi = (int)(dpiAvg + 0.5);
       }

       // same two escape hatches as LoadWICimage(): a DNG that decoded into its embedded
       // 256x192 icon, and a high bit depth TIFF that FreeImage handles better
       if (facts.gotPixelFmt && facts.gotContainerFmt)
       {
          UINT ucontainerFmt = indexedWICcontainerFormats(facts.containerFmt);
          int destinationBPP = decideWICtoFIMpixelFormat(facts.pixelFmt);
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
             if (SUCCEEDED(fac->CreateBitmapScaler(&pScaler)) && pScaler!=NULL)
             {
                WICBitmapInterpolationMode mode = (givenQuality==7) ? WICBitmapInterpolationModeHighQualityCubic : WICBitmapInterpolationModeFant;
                HRESULT hrs = WICguardedScalerInit(pScaler, pFrame, nSize[0], nSize[1], mode, &sehCode);
                // the retry is for HighQualityCubic being unavailable before WIC2, which
                // reports an error; a codec that faulted is not asked a second time
                if (FAILED(hrs) && sehCode==0 && mode!=WICBitmapInterpolationModeFant)
                   hrs = WICguardedScalerInit(pScaler, pFrame, nSize[0], nSize[1], WICBitmapInterpolationModeFant, &sehCode);

                if (SUCCEEDED(hrs))
                   pSource = pScaler;
                else
                   WICsafeRelease(pScaler);
             }
          }
       }

       hr = fac->CreateFormatConverter(&pConverter);
       if (SUCCEEDED(hr))
          hr = WICguardedConverterInit(pConverter, pSource, &GUID_WICPixelFormat32bppPBGRA, &sehCode);
    }

    if (SUCCEEDED(hr))
    {
       UINT width = 0, height = 0, cbStride = 0;
       hr = WICguardedSourceInfo(pConverter, &width, &height, NULL, &sehCode);
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
                // in 64-bit: Stride is an INT and height a UINT, so the old product wrapped
                // silently once an image passed roughly one gigapixel of output
                const UINT64 bufSize = (UINT64)(bitmapDatu.Stride<0 ? -bitmapDatu.Stride : bitmapDatu.Stride) * (UINT64)height;
                hrc = (bufSize>0xFFFFFFFFull) ? E_INVALIDARG
                    : WICguardedCopyPixels(pConverter, NULL, bitmapDatu.Stride, (UINT)bufSize, (BYTE*)bitmapDatu.Scan0, &sehCode);
                Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
                if (sehCode!=0)
                   fnOutputDebug("thumbsPool: the codec faulted while decoding " + WideCharToString(szFileName));
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

    WICsafeRelease(pConverter);
    WICsafeRelease(pScaler);
    WICsafeRelease(pFrame);
    WICsafeRelease(pDecoder);
    return myBitmap;
}

// qpv-gdip-loader-begin
// ---------------------------------------------------------------------------------------
//  GDI+ loader; port of LoadFileWithGDIp()
// ---------------------------------------------------------------------------------------

// The third loader of the product, and the last one either pool tries. It is here because
// GDI+ reads files the other two do not: EMF and WMF have no FreeImage plugin and no WIC
// codec at all, and a GIF that FreeImage refuses - and that WIC either has no codec for or
// cannot decode - is still drawn in the viewport, by LoadFileWithGDIp(). Without this, a
// file the viewer displays perfectly reaches QPV_ShowThumbnails() as a failure, and the
// collection pool of dupes-pixels.h marks it isDeleted=1.
//
// What comes back is always a COPY, even when no resize was needed. GdipCreateBitmapFromFile()
// keeps the file mapped for as long as its bitmap lives - GDIbmpFileConnected tracks exactly
// that in the AHK - and a worker must not leave a lock behind on a file the user may be
// about to move or delete. The copy is also what turns the 8bpp indexed bitmap a GIF decodes
// into into the 32bpp one GdipBitmapApplyEffect() and GdipBitmapGetHistogram() need in
// dpRunJob().
struct TpGdipFacts {
    UINT   width = 0, height = 0;
    UINT   frames = 1;
    double dpix = 0.0, dpiy = 0.0;
};

// The load, the header reads and the frame selection all run inside a codec, so they sit
// behind the same guard the WIC helpers use: a worker that faults on a malformed file takes
// the whole application down with it. Nothing in here owns anything that would need
// unwinding, which is what lets __try wrap it at all.
static Gdiplus::Status tpGuardedGdipOpen(const wchar_t *path, int frameIndex, Gdiplus::GpBitmap **ppBmp,
                                         TpGdipFacts *facts, DWORD *sehCode) {
    Gdiplus::Status st = Gdiplus::GenericError;
    *sehCode = 0;
    __try
    {
        st = Gdiplus::DllExports::GdipCreateBitmapFromFile(path, ppBmp);
        if (st==Gdiplus::Ok && *ppBmp==NULL)
           st = Gdiplus::GenericError;

        if (st==Gdiplus::Ok)
        {
           // Gdip_GetBitmapFramesCount(): the count belongs to a frame DIMENSION, and the
           // first one is the only one GDI+ reports for the two formats it pages at all -
           // time for a GIF, page for a TIFF
           UINT dimensions = 0;
           GUID dimensionID;
           if (Gdiplus::DllExports::GdipImageGetFrameDimensionsCount(*ppBmp, &dimensions)==Gdiplus::Ok && dimensions>0
            && Gdiplus::DllExports::GdipImageGetFrameDimensionsList(*ppBmp, &dimensionID, 1)==Gdiplus::Ok)
           {
              UINT count = 0;
              if (Gdiplus::DllExports::GdipImageGetFrameCount(*ppBmp, &dimensionID, &count)==Gdiplus::Ok && count>0)
              {
                 facts->frames = count;
                 // selected before the size is read, the way LoadFileWithGDIp() does it:
                 // the frames of an animated GIF need not all be the size of the first
                 if (frameIndex>0 && count>1)
                    Gdiplus::DllExports::GdipImageSelectActiveFrame(*ppBmp, &dimensionID,
                                                                    (UINT)min(frameIndex, (int)count - 1));
              }
           }

           Gdiplus::DllExports::GdipGetImageWidth(*ppBmp, &facts->width);
           Gdiplus::DllExports::GdipGetImageHeight(*ppBmp, &facts->height);
           Gdiplus::REAL dpix = 0.0f, dpiy = 0.0f;
           if (Gdiplus::DllExports::GdipGetImageHorizontalResolution(*ppBmp, &dpix)==Gdiplus::Ok
            && Gdiplus::DllExports::GdipGetImageVerticalResolution(*ppBmp, &dpiy)==Gdiplus::Ok)
           {
              facts->dpix = (double)dpix;
              facts->dpiy = (double)dpiy;
           }
        }
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return Gdiplus::GenericError;
    }

    return st;
}

// Gdip_ResizeBitmap()'s non-indexed branch, which is also the chain dpResizeBitmap() runs in
// dupes-pixels.h: a fresh 32bppARGB bitmap, the interpolation the caller asked for,
// antialiased smoothing, high quality pixel offsets, one DrawImage.
static Gdiplus::GpBitmap* tpGdipResizeCopy(Gdiplus::GpBitmap *src, int w, int h, int interpolation) {
    if (src==NULL || w<1 || h<1)
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

    Gdiplus::DllExports::GdipSetInterpolationMode(g, (Gdiplus::InterpolationMode)clamp(interpolation, 0, 7));
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

static Gdiplus::GpBitmap* tpGDIPload(const std::wstring &path, int targetW, int targetH, int frameIndex,
                                     int interpolation, int &srcW, int &srcH, TpSrcMeta *meta = NULL) {
    if (path.empty())
       return NULL;

    Gdiplus::GpBitmap *loaded = NULL;
    TpGdipFacts facts;
    DWORD sehCode = 0;
    const Gdiplus::Status st = tpGuardedGdipOpen(path.c_str(), frameIndex, &loaded, &facts, &sehCode);
    if (sehCode!=0)
    {
       // whatever the codec left behind is abandoned on purpose: the object most likely to
       // fault on the way out is the one that just faulted on the way in
       fnOutputDebug("thumbsPool: GDI+ faulted while opening " + WideCharToString(path.c_str()));
       return NULL;
    }

    if (st!=Gdiplus::Ok || loaded==NULL)
    {
       if (loaded!=NULL)
          Gdiplus::DllExports::GdipDisposeImage(loaded);

       return NULL;
    }

    // the same floor tpWICload() applies: a 1x1 is what a decoder hands back when it gave up
    if (facts.width<1 || facts.height<1 || (facts.width==1 && facts.height==1)
     || facts.width>0x7FFFFFFFu || facts.height>0x7FFFFFFFu)
    {
       Gdiplus::DllExports::GdipDisposeImage(loaded);
       return NULL;
    }

    srcW = (int)facts.width;
    srcH = (int)facts.height;
    if (meta!=NULL)
    {
       meta->frames = (facts.frames>0) ? (int)facts.frames : 1;
       // an absurd resolution out of broken metadata is recorded as nothing at all; both
       // comparisons are false for a NaN, which lands on the same place
       const double dpiAvg = (facts.dpix + facts.dpiy)*0.5;
       if (dpiAvg>0.0 && dpiAvg<1000000.0)
          meta->dpi = (int)(dpiAvg + 0.5);
    }

    int outW = 0, outH = 0;
    tpCalcIMGdimensions((int)facts.width, (int)facts.height,
                        (targetW>1) ? targetW : (int)facts.width,
                        (targetH>1) ? targetH : (int)facts.height, outW, outH);

    Gdiplus::GpBitmap *out = tpGdipResizeCopy(loaded, outW, outH, interpolation);
    Gdiplus::DllExports::GdipDisposeImage(loaded);
    if (out==NULL)
       fnOutputDebug("thumbsPool: failed to copy the GDI+ bitmap of " + WideCharToString(path.c_str()));

    return out;
}
// qpv-gdip-loader-end

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
                                     DWORD startTick, int &srcW, int &srcH, int &status, int &savedToFile,
                                     TpSrcMeta *meta = NULL) {
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

    // Read off the bitmap as it came out of the decoder. Everything below rescales it,
    // greyscales UINT16, tone maps and forces 24 or 32 bits, and LoadFimFile() reads the
    // same three at the same point - before any of that - which is what makes the values
    // the pool writes comparable with the ones the interpreter writes for the same file.
    //
    // FreeImage stores the resolution in dots per METRE. The interpreter's wrapper,
    // FreeImage_GetDPIresolution(), converts it back to DPI, and so does this: imgdpi is a
    // DPI column, and the WIC branch above fills it with a real DPI.
    int fimSrcBPP = 0, fimSrcColor = -1;
    if (meta!=NULL)
    {
       fimSrcBPP   = (int)FIM.GetBPP(dib);
       fimSrcColor = FIM.GetColorType(dib);
       meta->fimBPP   = fimSrcBPP;
       meta->fimColor = fimSrcColor;
       // A page count needs the file reopened as a multi-bitmap, which this loader never
       // does - and neither does FreeImage_SimpleGetPageCount(), whose DllCall names an
       // entry point that does not exist and which therefore always answers 1. The formats
       // that really carry pages, GIF and TIFF, are WIC's here.
       meta->frames = 1;
       if (FIM.GetDotsPerMeterX!=NULL && FIM.GetDotsPerMeterY!=NULL)
       {
          const double dpmX = (double)FIM.GetDotsPerMeterX(dib);
          const double dpmY = (double)FIM.GetDotsPerMeterY(dib);
          meta->dpi = (int)round(((dpmX + dpmY)/2) * 0.0254);
       }
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
       if (meta!=NULL)
          meta->fimToneMap = 1;    // " (TONE-MAPPED)"
    }

    // The rest of the suffix FIMapplyToneMapper() appends to mainLoadedIMGdetails.PixelFormat,
    // decided the way the interpreter decides it - off the bit depth and colour type of the
    // ORIGINAL bitmap, which is why they were kept above. The pool's own tone-mapping test a
    // few lines up runs on the rescaled one and is left exactly as it was: changing which
    // images get tone mapped would change the thumbnails, and the histogram the collection
    // pool measures on this very bitmap.
    if (meta!=NULL && meta->fimToneMap==0)
    {
       const int ahkMust = ((fimSrcBPP>32 && fimSrcColor!=FIC_RGBALPHA && GFT!=FIF_PNG) || fimSrcBPP>=48) ? 1 : 0;
       const bool hdrish = (GFT==FIF_PFM || GFT==FIF_RAW || GFT==FIF_JXR || GFT==FIF_HDR || GFT==FIF_EXR);
       if ((ahkMust==1 || hdrish) && fimSrcBPP>32)
          meta->fimToneMap = 2;    // " (TONE-MAPPABLE)"
       else if (GFT==FIF_RAW && cfg->userHQraw!=1)
          meta->fimToneMap = 2;    // LoadFimFile() marks a low quality RAW the same way
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
    res.meta        = TpSrcMeta();

    // OpenCV happily throws out of openCVapplyToneMappingAlgos(), and allocations may
    // throw when memory is scarce; letting that escape would tear the worker thread down
    // and silently shrink the pool for the rest of the session
    try
    {
        if (job.kind==TP_JOB_LOADCACHE)
        {
           // no TpSrcMeta, deliberately: this opens the cached thumbnail PNG, so its frame
           // count, resolution and pixel format are the cache file's own and describe
           // nothing about the image it was made from. loaderUsed 5 is what tells
           // QPV_ThumbsPoolDrain() to leave the files list alone.
           bmp = tpWICload(fac, job.src.c_str(), 0, 0, 0, cfg->imgQuality, 0, res.srcW, res.srcH);
           res.loaderUsed = 5;
           res.status = (bmp!=NULL) ? TP_OK : TP_ERR_LOAD;
        } else
        {
           const std::wstring ext = tpFileExtension(job.src);
           const bool fimHandles  = (FIM.ok && cfg->allowFIM==1 && tpFimExts.count(ext)>0);

           if (ext==L"svg")
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
              // what RenderSVGfile() reports: one frame, 96 DPI, and a pixel format that is
              // the renderer's rather than the file's, since an SVG has none of its own
              res.meta.frames = 1;
              res.meta.dpi    = 96;
           } else if (ext==L"pdf")
           {
              int maxW = cfg->thumbSize, maxH = cfg->thumbSize, pageCount = 0, errorType = -100;
              {
                 // PDFium keeps global state;
                 std::lock_guard<std::mutex> pdfLock(tpPdfMutex);
                 bmp = RenderPdfPageAsBitmap(job.src.c_str(), 0, 250.0f, &maxW, &maxH, 1, 0xffffffff, &pageCount, &errorType, L"", 1);
              }
              res.loaderUsed = 4;
              res.srcW = maxW;
              res.srcH = maxH;
              res.status = (bmp!=NULL) ? TP_OK : TP_ERR_PDFLOCKED;
              // No TpSrcMeta for a PDF, deliberately, and QPV_ThumbsPoolDrain() ignores
              // loader 4 for the same reason. Not one of the five columns would say
              // anything about the document: srcW and srcH above are the size of THIS
              // render, which is fitted into the thumbnail box at the 250 DPI this pool
              // picked, while RenderPDFpage() fits it at userVPpdfDPI and reports 32-PARGB
              // where this asks PDFium for 24 bits. The same PDF would land in the files
              // list with different numbers depending on whether the workers or the single
              // threaded branch happened to draw it, which is the whole thing this is
              // meant to stop. The page count is real - and the single threaded branch
              // still collects it, through GetCachableImgFileDetails().
           }

           int hasFIMtried = 0;
           if (bmp==NULL && res.status!=TP_ERR_PDFLOCKED && FIM.ok && fimHandles && cfg->allowFIM==1)
           {
              int status = TP_ERR_LOAD, saved = 0;
              int fw = 0, fh = 0;
              res.meta = TpSrcMeta();  // reset the record
              bmp = tpFIMthumb(cfg, job.src, job.dst, startTick, fw, fh, status, saved, &res.meta);
              res.loaderUsed  = 2;
              res.status      = status;
              res.savedToFile = saved;
              hasFIMtried = 1;
              if (fw>0 && fh>0)
              {
                 res.srcW = fw;
                 res.srcH = fh;
              }
           }

           if (bmp==NULL && tpWicExts.count(ext)>0 && res.status!=TP_ERR_PDFLOCKED)
           {
              // if FreeImage failed, try with WIC; WIC is NOT entirely multi-thread ready.
              // WIC always serializes image processing operations
              res.meta = TpSrcMeta();  // reset the record
              bmp = tpWICload(fac, job.src.c_str(), cfg->thumbSize, cfg->thumbSize, job.frameIndex, cfg->imgQuality,
                              0, res.srcW, res.srcH, &res.meta);
              res.loaderUsed = 1;
              res.status = (bmp!=NULL) ? TP_OK : TP_ERR_LOAD;
              if (bmp==NULL && FIM.ok && cfg->allowFIM==1 && hasFIMtried!=1)
              {
                 int status = TP_ERR_LOAD, saved = 0;
                 int fw = 0, fh = 0;
                 res.meta = TpSrcMeta();  // reset the record
                 bmp = tpFIMthumb(cfg, job.src, job.dst, startTick, fw, fh, status, saved, &res.meta);
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

           // The last resort, and for some files the only one: EMF and WMF have neither a
           // FreeImage plugin nor a WIC codec, and the GIFs those two refuse are read here
           // as well - LoadFileWithGDIp() is what draws them in the viewport. A file this
           // cannot open either is unreadable in every sense the product has.
           if (bmp==NULL && res.status!=TP_ERR_PDFLOCKED)
           {
              res.meta = TpSrcMeta();
              bmp = tpGDIPload(job.src, cfg->thumbSize, cfg->thumbSize, job.frameIndex, cfg->imgQuality,
                               res.srcW, res.srcH, &res.meta);
              res.loaderUsed = 6;
              res.status = (bmp!=NULL) ? TP_OK : TP_ERR_LOAD;
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
          res.savedToFile = tpSavePngGdip(bmp, job.dst);

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
        // The generation is tested on the way THROUGH the throttle as well, not only here.
        // On a machine short of memory the wait for a slot can outlast the page this job was
        // listed for, and spending the single decode such a machine allows on a thumbnail
        // nobody is going to look at holds up whichever pool still has work worth doing.
        if (job.generation==tpGeneration.load()
         && tpWaitForJobSlot([&job] { return tpStopping.load() || job.generation!=tpGeneration.load(); }))
        {
           TpJobSlot slot;      // released at the end of this block, whatever happens in it
           tpRunJob(fac, d2dFac, job, res);
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
