// The layout of the records the thumbnails pool shares with AutoHotkey.
//
// thumbsPoolFetch() fills an array of ThumbResult and thumbsPoolGetState() hands over a
// ThumbsPoolState; on the other side QPV_ThumbsPoolDrain(), poolRecordImgProps() and
// QPV_ThumbsPoolPending() walk them with a stride and byte offsets written out by hand in
// quick-picto-viewer.ahk. Nothing connects the two: a field inserted in the middle of
// ThumbResult compiles perfectly and then hands AHK a GDI+ bitmap pointer read out of the
// middle of another record.
//
// The structs are TEXT-SLICED out of the shipped thumbs-pool.h by run-tests.sh, so what is
// pinned here is what actually ships. Every offset below is one that appears as a literal
// in the AHK; when this test fails, the AHK is what has to change.
//
// written by Marius Șucan with Claude Opus 5

#include <cstdio>
#include <cstddef>
#include <cstdint>

// The two Windows types the sliced structs use. LONG is 32 bits on Windows and 64 on this
// box, so it has to be spelled out or every offset below drifts.
typedef int64_t INT64;
#define LONG int32_t

#include "thumbs_structs.part"

#undef LONG

static int failures = 0;
static void check(bool cond, const char *what) {
    printf("    %-62s %s\n", what, cond ? "ok" : "FAILED");
    if (!cond) failures++;
}

int main() {
    printf("thumbs-pool.h record layout\n");

    // QPV_ThumbsPoolDrain(): Static maxItems := 32, resultSize := 72
    printf("  ThumbResult, as QPV_ThumbsPoolDrain() reads it\n");
    check(sizeof(ThumbResult)==72,               "resultSize := 72");
    check(offsetof(ThumbResult, jobId)==0,       "jobId  at 0,  read as Int64");
    check(offsetof(ThumbResult, pBitmap)==8,     "pBitmap at 8, read as UPtr");
    check(offsetof(ThumbResult, status)==16,     "status at 16");
    check(offsetof(ThumbResult, srcW)==24,       "srcW   at 24");
    check(offsetof(ThumbResult, srcH)==28,       "srcH   at 28");
    check(offsetof(ThumbResult, loaderUsed)==44, "loaderUsed at 44 - the test for a cached thumbnail");

    // poolRecordImgProps() reads the six metadata fields at these offsets
    printf("  TpSrcMeta, as poolRecordImgProps() reads it\n");
    const size_t m = offsetof(ThumbResult, meta);
    check(m==48,                                   "meta       at 48");
    check(m + offsetof(TpSrcMeta, frames)==48,     "frames     at 48");
    check(m + offsetof(TpSrcMeta, dpi)==52,        "dpi        at 52");
    check(m + offsetof(TpSrcMeta, wicFmt)==56,     "wicFmt     at 56");
    check(m + offsetof(TpSrcMeta, fimBPP)==60,     "fimBPP     at 60");
    check(m + offsetof(TpSrcMeta, fimColor)==64,   "fimColor   at 64");
    check(m + offsetof(TpSrcMeta, fimToneMap)==68, "fimToneMap at 68");

    // an unfilled record must not look like a collected one: QPV_ThumbsPoolDrain() decides
    // on loaderUsed, and 0 - what tpRunJob() resets it to - means nothing ran
    printf("  the defaults\n");
    TpSrcMeta fresh;
    check(fresh.frames==1,      "a fresh record claims one frame, the way imgframes counts");
    check(fresh.dpi==0,         "and no resolution");
    check(fresh.wicFmt==-1 && fresh.fimColor==-1,
                                "and no pixel format from either loader");
    check(fresh.fimToneMap==0,  "and no tone mapping marker");

    // QPV_ThumbsPoolPending() and QPV_ThumbsPoolReady()
    printf("  ThumbsPoolState, as the AHK polls it\n");
    check(offsetof(ThumbsPoolState, queued)==0,   "queued   at 0");
    check(offsetof(ThumbsPoolState, inFlight)==4, "inFlight at 4");
    check(offsetof(ThumbsPoolState, ready)==8,    "ready    at 8");

    printf("\n  %s\n", failures ? "THUMBS RECORD TEST FAILED" : "thumbs record test passed");
    return failures ? 1 : 0;
}
