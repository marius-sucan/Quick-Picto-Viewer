// The shared decode throttle of qpvmain.dll.
//
// Both worker pools take a slot here before they decode anything: the thumbnails workers
// and the collection workers of dupes-pixels.h, through tpWaitForJobSlot(). While the
// machine is short of memory only one slot exists, so the whole DLL decodes one image at a
// time instead of asking a machine that is already swapping for several decoder-sized
// allocations at once.
//
// Five properties, and the pools are unusable without any of them:
//   - while memory is tight, no two decodes ever run at the same time;
//   - a worker that has to wait is always let through afterwards. Nothing here may hold a
//     slot back, because both pools drive a caller that polls them from AutoHotkey and
//     reports progress to the user; a slot that is never handed on shows up as a progress
//     bar that never moves and an application that looks hung;
//   - the throttle is entered and left at DIFFERENT readings. The pressure is largely its
//     own doing, so one set of thresholds means it lifts the moment it has worked, lets
//     every waiting worker start a decoder at once, and is straight back over the line;
//   - and it lifts one decode per sample rather than all of them at once, for the same
//     reason;
//   - neither pool can lock the other one out. A worker that has just released a slot is
//     asking for another one microseconds later, while everybody else is asleep.
//
// The functions are TEXT-SLICED out of the shipped thumbs-pool.h by run-tests.sh, so what
// runs here is what ships rather than a transcription of it. The memory readings and the
// clock are this file's, which is what makes any of it testable: the tests state what
// GlobalMemoryStatusEx() reports and move time forward themselves.
//
// written by Marius Șucan with Claude Opus 5

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <thread>
#include <vector>

typedef int                LONG;      // Windows LONG is 32-bit; "long" here is 64-bit
typedef unsigned long      DWORD;
typedef unsigned long long ULONGLONG;

// only the six fields the sampler reads, in no particular order
struct MEMORYSTATUSEX {
    DWORD     dwLength;
    DWORD     dwMemoryLoad;
    ULONGLONG ullAvailPhys;
    ULONGLONG ullAvailPageFile;
    ULONGLONG ullAvailVirtual;
};

// What the machine is going to report, and a clock nothing moves but the tests. Freezing
// the clock is what makes the concurrency tests below deterministic: the sampler refuses to
// take a new reading until TP_MEM_SAMPLE_MS have passed, so while the tests leave time
// alone the memory state cannot change under a running pool.
static MEMORYSTATUSEX         fakeMem = {sizeof(MEMORYSTATUSEX), 10, 8ull<<30, 8ull<<30, 8ull<<30};
static std::atomic<ULONGLONG> fakeTicks(100000);

static ULONGLONG GetTickCount64() { return fakeTicks.load(); }
static int GlobalMemoryStatusEx(MEMORYSTATUSEX *ms) { *ms = fakeMem; return 1; }

#include "mem_limits.part"

// what the sliced blocks expect to find around them, from the top of thumbs-pool.h
static std::atomic<LONG>       tpActiveJobs(0);
static std::atomic<LONG>       tpMemTight(0);
static std::atomic<ULONGLONG>  tpMemStamp(0);
static std::atomic<LONG>       tpSlotCap(TP_SLOT_CAP_MAX);
static std::atomic<LONG>       tpSlotWaiters(0);
static std::mutex              tpSlotMutex;
static std::condition_variable tpSlotCV;
static ULONGLONG               tpSlotQueue[TP_SLOT_CAP_MAX] = {0};
static int                     tpSlotQueued = 0;
static ULONGLONG               tpSlotTicket = 0;
static std::atomic<bool>       tpStopping(false);
static struct { volatile LONG memTight; volatile LONG activeJobs; } tpState = {0, 0};

#include "mem_sample.part"
#include "slots_extract.part"

static int failures = 0;
static void check(bool cond, const char *what) {
    printf("    %-70s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

// ---------------------------------------------------------------------------------------
//  driving the machine the throttle thinks it is running on

static const ULONGLONG MB = 1024ull*1024ull;

static void memoryIs(DWORD loadPercent, ULONGLONG freePhysMB, ULONGLONG commitMB, ULONGLONG addressSpaceMB) {
    fakeMem.dwMemoryLoad     = loadPercent;
    fakeMem.ullAvailPhys     = freePhysMB*MB;
    fakeMem.ullAvailPageFile = commitMB*MB;
    fakeMem.ullAvailVirtual  = addressSpaceMB*MB;
}

// takes n readings, each one far enough after the last that the sampler accepts it
static void sample(int n = 1) {
    for ( int i = 0 ; i < n ; i++)
    {
        fakeTicks.fetch_add(TP_MEM_SAMPLE_MS + 1);
        tpMemoryIsTight();
    }
}

static void plentyOfMemory() { memoryIs(10, 8192, 8192, 8192); }
static void machineIsShort() { memoryIs(96,  100,  100, 8192); }

// a machine with memory to spare, and the throttle fully lifted - which takes as many
// samples as the cap has steps, on purpose. See theRampBack() below.
static void plentyOfMemorySettled() {
    plentyOfMemory();
    sample(TP_SLOT_CAP_MAX + 2);
}

// what a thumbnails worker does; the collection pool passes a wider predicate of its own
static bool acquireAsThumbsWorker() {
    return tpWaitForJobSlot([] { return tpStopping.load(); });
}

// ---------------------------------------------------------------------------------------

static void theCountItself() {
    printf("  one slot while memory is tight, as many as asked for when it is not\n");
    plentyOfMemorySettled();
    tpStopping.store(false);
    tpActiveJobs.store(0);

    check(tpTryTakeJobSlot(), "a slot is given out on a machine with memory to spare");
    check(tpTryTakeJobSlot(), "and so is a second one, at the same time");
    check(tpActiveJobs.load()==2 && tpState.activeJobs==2, "both are counted, and the state block says so");
    tpReleaseJobSlot();
    tpReleaseJobSlot();
    check(tpActiveJobs.load()==0 && tpState.activeJobs==0, "and giving them back brings the count to zero");

    machineIsShort();
    sample();
    check(tpMemoryIsTight(), "a machine short of memory reads as short");
    check(tpState.memTight==1, "and says so where AHK can see it");
    check(tpTryTakeJobSlot(), "the first slot is still given out when memory is tight");
    check(!tpTryTakeJobSlot(), "the second is refused - one decode at a time is the whole point");
    tpReleaseJobSlot();
    check(tpTryTakeJobSlot(), "and it is granted the moment the first one is given back");
    tpReleaseJobSlot();

    {
        TpJobSlot slot;      // adopts the count, the way both worker bodies use it
        tpTryTakeJobSlot();
    }
    check(tpActiveJobs.load()==0, "TpJobSlot gives the slot back when its scope ends");

    tpStopping.store(true);
    check(!acquireAsThumbsWorker(), "a waiting thumbnails worker gives up when the pool shuts down");
    check(tpActiveJobs.load()==0, "without taking a slot on its way out");
    tpStopping.store(false);
}

// ---------------------------------------------------------------------------------------
//
// What it takes to enter the throttle, and what it takes to leave it - which are not the
// same reading, and must not be. Everything the old sampler could see was the percentage
// and the free physical memory; the commit headroom and the address space are what a 32
// bits build runs out of first, on a machine reporting gigabytes free.
static void theThresholdsThemselves() {
    printf("  what turns the throttle on, and what it takes to turn it off again\n");
    plentyOfMemory();
    sample();
    check(!tpMemoryIsTight(), "a machine with memory to spare is not throttled");

    memoryIs(TP_MEM_LOAD_HIGH, 8192, 8192, 8192);
    sample();
    check(tpMemoryIsTight(), "90% of the physical memory in use turns it on");

    memoryIs(TP_MEM_LOAD_HIGH - 5, 8192, 8192, 8192);
    sample();
    check(tpMemoryIsTight(), "85% does NOT turn it off again - one set of thresholds is what made it flap");

    memoryIs(TP_MEM_LOAD_LOW, 8192, 8192, 8192);
    sample();
    check(!tpMemoryIsTight(), "80% does");

    memoryIs(40, 500, 8192, 8192);
    sample();
    check(tpMemoryIsTight(), "half a gigabyte of free memory turns it on whatever the percentage says");

    memoryIs(40, 1000, 8192, 8192);
    sample();
    check(tpMemoryIsTight(), "a gigabyte does not turn it off - the clear line sits above the floor");

    memoryIs(40, 2048, 8192, 8192);
    sample();
    check(!tpMemoryIsTight(), "two gigabytes do");

    memoryIs(40, 8192, 300, 8192);
    sample();
    check(tpMemoryIsTight(), "no commit headroom turns it on with free physical memory to spare");

    plentyOfMemory();
    sample();
    memoryIs(40, 8192, 8192, 300);
    sample();
    check(tpMemoryIsTight(), "and so does a process with no address space left - the wall the 32 bits build hits");

    plentyOfMemorySettled();
    check(!tpMemoryIsTight(), "a machine with everything to spare ends up unthrottled again");
}

// ---------------------------------------------------------------------------------------
//
// Coming back. The decodes this throttles are what put the machine over the line, so the
// memory returns the moment it narrows down to one image - and letting every waiting worker
// through on that first good reading asks for exactly the burst of decoder-sized
// allocations the throttle exists to prevent, one sample before the machine is over the
// line again.
static void theRampBack() {
    printf("  coming back from tight: one more decode per reading, not all of them at once\n");
    machineIsShort();
    sample();
    tpActiveJobs.store(0);
    check(tpSlotCap.load()==1, "while the machine is short, one decode is all that is allowed");

    plentyOfMemory();
    sample();
    check(tpSlotCap.load()==2, "the first good reading allows a second decode, and only a second");
    check(tpTryTakeJobSlot() && tpTryTakeJobSlot(), "so two of them start");
    check(!tpTryTakeJobSlot(), "and the third is still refused - that burst is what used to undo this");
    tpReleaseJobSlot();
    tpReleaseJobSlot();

    sample(3);
    check(tpSlotCap.load()==5, "three readings later, five");
    sample(TP_SLOT_CAP_MAX + 2);
    check(tpSlotCap.load()==TP_SLOT_CAP_MAX, "and it climbs to more workers than either pool can start, so nothing is throttled for long");

    machineIsShort();
    sample();
    check(tpSlotCap.load()==1, "one short reading takes it straight back down to a single decode");
    check(tpActiveJobs.load()==0, "with nothing held");
}

// ---------------------------------------------------------------------------------------
//
// The liveness half. A worker that waits has to be let through once the slot comes back -
// with no timeout anywhere in the throttle, that is the only thing standing between a tight
// machine and a pool that never decodes anything again.
static void aWaiterIsLetThrough() {
    printf("  a worker that has to wait\n");
    machineIsShort();
    sample();
    tpStopping.store(false);
    tpActiveJobs.store(0);

    check(tpTryTakeJobSlot(), "one worker is decoding");

    std::atomic<bool> got(false);
    std::thread waiter([&got] {
        if (acquireAsThumbsWorker())
        {
           got.store(true);
           tpReleaseJobSlot();
        }
    });

    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    check(!got.load(), "the one that arrives second waits rather than decoding as well");

    tpReleaseJobSlot();
    const std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
    while (!got.load() && std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() < 5.0)
        std::this_thread::sleep_for(std::chrono::milliseconds(5));

    waiter.join();
    check(got.load(), "and is let through as soon as the slot comes back");
    check(tpActiveJobs.load()==0, "with nothing left held");
}

// ---------------------------------------------------------------------------------------
//
// The wait ends early for one reason only, and it is the reason both worker bodies pass in:
// the job in hand belongs to a run that no longer exists. On a tight machine the queue for
// the slot can outlast a whole run, and spending the single decode such a machine allows on
// an image whose result is going to be thrown away puts it in front of work somebody is
// waiting for.
static void aCancelledJobStopsWaiting() {
    printf("  a worker holding a job for a run that is over gives the wait up\n");
    machineIsShort();
    sample();
    tpStopping.store(false);
    tpActiveJobs.store(0);

    check(tpTryTakeJobSlot(), "one worker is decoding");

    std::atomic<LONG> generation(1);
    std::atomic<bool> finished(false), tookIt(false);
    std::thread waiter([&generation, &finished, &tookIt] {
        tookIt.store(tpWaitForJobSlot([&generation] { return generation.load()!=1; }));
        finished.store(true);
    });

    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    check(!finished.load(), "the second one is waiting for the slot");

    generation.fetch_add(1);      // the run it was decoding for is abandoned
    const std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
    while (!finished.load() && std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() < 5.0)
        std::this_thread::sleep_for(std::chrono::milliseconds(5));

    waiter.join();
    check(finished.load(), "and stops waiting when that run is abandoned");
    check(!tookIt.load(), "without spending the one slot the machine has on it");
    check(tpActiveJobs.load()==1, "which is still where it was - held by the worker that is decoding");
    tpReleaseJobSlot();
}

// ---------------------------------------------------------------------------------------
//
// The rule that keeps one pool from locking the other out, on its own and away from any
// timing. A worker that has just given a slot back is round its loop and asking for another
// one within microseconds; every other worker is asleep. Whoever arrives has to queue.
static void arrivalsQueueBehindWaiters() {
    printf("  a worker that has just released a slot does not walk straight back in\n");
    plentyOfMemorySettled();
    tpActiveJobs.store(0);
    tpSlotWaiters.store(0);

    check(tpTryTakeJobSlotNow(), "an arriving worker takes a free slot when nobody is queued");
    tpReleaseJobSlot();

    tpSlotWaiters.fetch_add(1);      // a worker of the other pool is queued for one
    check(!tpTryTakeJobSlotNow(), "and is refused that same free slot while one is");
    check(tpTryTakeJobSlot(), "a rule for arrivals only - the queued worker itself still takes it");
    tpReleaseJobSlot();
    tpSlotWaiters.fetch_sub(1);
    check(tpActiveJobs.load()==0, "and nothing was left held");
}

// ---------------------------------------------------------------------------------------
//
// The same rule end to end. One pool churning through short jobs - a page of thumbnails,
// most of them already cached - against one worker of the other pool, on a machine short
// enough of memory that there is a single slot for the two of them.
static void neitherPoolIsStarved() {
    printf("  one pool churning through short jobs does not lock the other one out\n");
    machineIsShort();
    sample();
    tpStopping.store(false);
    tpActiveJobs.store(0);

    std::atomic<bool> stop(false);
    std::atomic<int> busyPool(0), otherPool(0);
    std::thread hog([&stop, &busyPool] {
        while (!stop.load())
        {
            if (!acquireAsThumbsWorker())
               return;

            TpJobSlot slot;
            busyPool.fetch_add(1);
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
    });

    // the busy pool gets a head start, so it is the one holding the slot throughout
    std::this_thread::sleep_for(std::chrono::milliseconds(40));
    std::thread other([&stop, &otherPool] {
        while (!stop.load())
        {
            if (!acquireAsThumbsWorker())
               return;

            TpJobSlot slot;
            otherPool.fetch_add(1);
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
    });

    std::this_thread::sleep_for(std::chrono::milliseconds(400));
    stop.store(true);
    hog.join();
    other.join();

    check(busyPool.load() > 0, "the busy pool decoded its images");
    check(otherPool.load() > 0, "and the other pool was let through at all");
    check(otherPool.load() >= busyPool.load()/4, "not as an afterthought either - it got a real share of the hand-offs");
    check(tpActiveJobs.load()==0, "every slot taken was given back");
    printf("    [%d hand-offs to the busy pool, %d to the other]\n", busyPool.load(), otherPool.load());
}

// ---------------------------------------------------------------------------------------
//
// Every worker of both pools at once, on the shape that wedged the collection pool: each of
// them holding an image and wanting to decode it. The count must never reach two, and every
// one of them must get through all of its images.
static void everyWorkerAtOnce() {
    printf("  both pools hammering the throttle while memory is tight\n");
    machineIsShort();
    sample();
    tpStopping.store(false);
    tpActiveJobs.store(0);

    const int threads = 12, jobsEach = 40;
    std::atomic<int> maxSeen(0), done(0);
    std::vector<std::thread> workers;
    for ( int i = 0 ; i < threads ; i++)
        workers.push_back(std::thread([&maxSeen, &done, jobsEach] {
            for ( int j = 0 ; j < jobsEach ; j++)
            {
                if (!acquireAsThumbsWorker())
                   return;

                TpJobSlot slot;
                const int now = (int)tpActiveJobs.load();
                int seen = maxSeen.load();
                while (now > seen && !maxSeen.compare_exchange_weak(seen, now))
                    ;

                std::this_thread::sleep_for(std::chrono::milliseconds(1));
                done.fetch_add(1);
            }
        }));

    const std::chrono::steady_clock::time_point t0 = std::chrono::steady_clock::now();
    for ( size_t i = 0 ; i < workers.size() ; i++)
        workers[i].join();

    const double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    check(done.load()==threads*jobsEach, "every worker decoded every one of its images");
    check(maxSeen.load()==1, "and no two of them were ever decoding at the same time");
    check(tpActiveJobs.load()==0, "every slot taken was given back");
    check(tpSlotWaiters.load()==0, "and nobody was left queued");
    printf("    [%d threads, %d images each, %.2fs]\n", threads, jobsEach, secs);
}

int main() {
    printf("thumbs-pool.h decode throttle\n");
    theCountItself();
    theThresholdsThemselves();
    theRampBack();
    aWaiterIsLetThrough();
    aCancelledJobStopsWaiting();
    arrivalsQueueBehindWaiters();
    neitherPoolIsStarved();
    everyWorkerAtOnce();

    printf("\n  %s\n", failures ? "THROTTLE TEST FAILED" : "throttle test passed");
    return failures ? 1 : 0;
}
