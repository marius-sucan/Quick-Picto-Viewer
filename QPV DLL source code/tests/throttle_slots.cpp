// The shared decode throttle of qpvmain.dll.
//
// Both worker pools take a slot here before they decode anything: the thumbnails workers
// through tpAcquireJobSlot(), the collection workers of dupes-pixels.h through
// dpAcquireJobSlot(). While the machine is short of memory only one slot exists, so the
// whole DLL decodes one image at a time instead of asking a machine that is already
// swapping for several decoder-sized allocations at once.
//
// Two properties, and the pools are unusable without either of them:
//   - while memory is tight, no two decodes ever run at the same time;
//   - a worker that has to wait is always let through afterwards. Nothing here may hold a
//     slot back, because both pools drive a caller that polls them from AutoHotkey and
//     reports progress to the user; a slot that is never handed on shows up as a progress
//     bar that never moves and an application that looks hung.
//
// The functions are TEXT-SLICED out of the shipped thumbs-pool.h by run-tests.sh, so what
// runs here is what ships rather than a transcription of it.
//
// written by Marius Șucan with Claude Opus 5

#include <atomic>
#include <chrono>
#include <cstdio>
#include <thread>
#include <vector>

typedef int LONG;      // Windows LONG is 32-bit; "long" here is 64-bit

// what the sliced block expects to find around it, from the top of thumbs-pool.h
static std::atomic<LONG> tpActiveJobs(0);
static std::atomic<bool> tpStopping(false);
static std::atomic<bool> tpMemTight(false);
static struct { volatile LONG activeJobs; } tpState = {0};

// the real one samples GlobalMemoryStatusEx() a few times a second
static bool tpMemoryIsTight() { return tpMemTight.load(); }

#include "slots_extract.part"

static int failures = 0;
static void check(bool cond, const char *what) {
    printf("    %-62s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

// ---------------------------------------------------------------------------------------

static void theCountItself() {
    printf("  one slot while memory is tight, as many as asked for when it is not\n");
    tpMemTight.store(false);
    tpStopping.store(false);
    tpActiveJobs.store(0);

    check(tpTryTakeJobSlot(), "a slot is given out on a machine with memory to spare");
    check(tpTryTakeJobSlot(), "and so is a second one, at the same time");
    check(tpActiveJobs.load()==2 && tpState.activeJobs==2, "both are counted, and the state block says so");
    tpReleaseJobSlot();
    tpReleaseJobSlot();
    check(tpActiveJobs.load()==0 && tpState.activeJobs==0, "and giving them back brings the count to zero");

    tpMemTight.store(true);
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
    check(!tpAcquireJobSlot(), "a waiting thumbnails worker gives up when the pool shuts down");
    tpStopping.store(false);
    tpMemTight.store(false);
}

// ---------------------------------------------------------------------------------------
//
// The liveness half. A worker that waits has to be let through once the slot comes back -
// with no timeout anywhere in the throttle, that is the only thing standing between a tight
// machine and a pool that never decodes anything again.
static void aWaiterIsLetThrough() {
    printf("  a worker that has to wait\n");
    tpMemTight.store(true);
    tpStopping.store(false);
    tpActiveJobs.store(0);

    check(tpTryTakeJobSlot(), "one worker is decoding");

    std::atomic<bool> got(false);
    std::thread waiter([&got] {
        if (tpAcquireJobSlot())
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
    tpMemTight.store(false);
}

// ---------------------------------------------------------------------------------------
//
// Every worker of both pools at once, on the shape that wedged the collection pool: each of
// them holding an image and wanting to decode it. The count must never reach two, and every
// one of them must get through all of its images.
static void everyWorkerAtOnce() {
    printf("  both pools hammering the throttle while memory is tight\n");
    tpMemTight.store(true);
    tpStopping.store(false);
    tpActiveJobs.store(0);

    const int threads = 12, jobsEach = 40;
    std::atomic<int> maxSeen(0), done(0);
    std::vector<std::thread> workers;
    for ( int i = 0 ; i < threads ; i++)
        workers.push_back(std::thread([&maxSeen, &done, jobsEach] {
            for ( int j = 0 ; j < jobsEach ; j++)
            {
                if (!tpAcquireJobSlot())
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
    printf("    [%d threads, %d images each, %.2fs]\n", threads, jobsEach, secs);
    tpMemTight.store(false);
}

int main() {
    printf("thumbs-pool.h decode throttle\n");
    theCountItself();
    aWaiterIsLetThrough();
    everyWorkerAtOnce();

    printf("\n  %s\n", failures ? "THROTTLE TEST FAILED" : "throttle test passed");
    return failures ? 1 : 0;
}
