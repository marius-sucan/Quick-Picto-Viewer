// sqlite-dynamic.h
//
// Minimal run-time binding to sqlite3.dll for the duplicate-identification engine.
// qpvmain.dll does not link SQLite; Class_SQLiteDB.__New() already LoadLibrary()s it
// (lib\Class_SQLiteDB.ahk:601), so GetModuleHandleW() normally finds the very same
// module. If it is absent, LoadLibraryW() is tried once and, failing that, SQ.ok stays
// false and the engine falls back to being fed by AHK.
//
// Note the calling convention: SQLite is __cdecl, unlike FreeImage. Every DllCall in
// Class_SQLiteDB.ahk says "Cdecl" for the same reason. Getting this wrong on x86 would
// corrupt the stack; the DLL is x64-only in practice, where it does not matter, but the
// declarations say what is true.
//
// Two connections, deliberately:
//   - the engine opens its own SQLITE_OPEN_READONLY handle on the database file, so the
//     scan cannot write and does not care how sqlite3.dll was compiled for threading;
//   - writes still go through the handle AHK owns, so the AHK class's transaction state
//     and error reporting stay coherent.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_SQLITE_DYNAMIC_H
#define QPV_SQLITE_DYNAMIC_H

#include <windows.h>
#include <mutex>

typedef struct sqlite3      sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef long long           sqlite3_int64;   // "long long", not __int64: same width on
                                             // MSVC, and the tests build this with g++

// ---- result codes --------------------------------------------------------------------
#define SQLITE_OK            0
#define SQLITE_ERROR         1
#define SQLITE_BUSY          5
#define SQLITE_INTERRUPT     9
#define SQLITE_ROW         100
#define SQLITE_DONE        101

// ---- storage classes, as sqlite3_column_type() reports them --------------------------
#define SQLITE_INTEGER  1
#define SQLITE_FLOAT    2
#define SQLITE_TEXT     3
#define SQLITE_BLOB     4
#define SQLITE_NULL     5

// ---- open flags ----------------------------------------------------------------------
#define SQLITE_OPEN_READONLY   0x00000001
#define SQLITE_OPEN_READWRITE  0x00000002
#define SQLITE_OPEN_NOMUTEX    0x00008000
#define SQLITE_OPEN_FULLMUTEX  0x00010000

// The destructor sentinel that tells SQLite to copy a bound value. SQLITE_STATIC (0)
// promises instead that the buffer stays put and unchanged until the statement is
// finished with it - which holds for a literal, and equally for a caller-owned buffer
// that is still alive at the sqlite3_step()/sqlite3_reset() pair, the way dpWriteResult()
// binds the fingerprints straight out of the DupePixResult it is writing. What it must
// never be is a temporary that dies before the step, or a buffer some other thread edits.
#define QPV_SQLITE_TRANSIENT ((void(__cdecl*)(void*))-1)
#define QPV_SQLITE_STATIC    ((void(__cdecl*)(void*))0)

struct SQLiteAPI {
    bool ok = false;
    HMODULE hLib = NULL;

    int          (__cdecl *open_v2)(const char*, sqlite3**, int, const char*) = NULL;
    int          (__cdecl *close_v2)(sqlite3*) = NULL;
    int          (__cdecl *prepare16_v2)(sqlite3*, const void*, int, sqlite3_stmt**, const void**) = NULL;
    int          (__cdecl *step)(sqlite3_stmt*) = NULL;
    int          (__cdecl *reset)(sqlite3_stmt*) = NULL;
    int          (__cdecl *finalize)(sqlite3_stmt*) = NULL;
    int          (__cdecl *exec)(sqlite3*, const char*, void*, void*, char**) = NULL;
    void         (__cdecl *interrupt)(sqlite3*) = NULL;
    const void*  (__cdecl *errmsg16)(sqlite3*) = NULL;

    int          (__cdecl *column_count)(sqlite3_stmt*) = NULL;
    int          (__cdecl *column_type)(sqlite3_stmt*, int) = NULL;
    sqlite3_int64(__cdecl *column_int64)(sqlite3_stmt*, int) = NULL;
    double       (__cdecl *column_double)(sqlite3_stmt*, int) = NULL;
    const void*  (__cdecl *column_text16)(sqlite3_stmt*, int) = NULL;
    int          (__cdecl *column_bytes16)(sqlite3_stmt*, int) = NULL;
    const void*  (__cdecl *column_blob)(sqlite3_stmt*, int) = NULL;
    int          (__cdecl *column_bytes)(sqlite3_stmt*, int) = NULL;

    int          (__cdecl *bind_int64)(sqlite3_stmt*, int, sqlite3_int64) = NULL;
    int          (__cdecl *bind_double)(sqlite3_stmt*, int, double) = NULL;
    int          (__cdecl *bind_text16)(sqlite3_stmt*, int, const void*, int, void(__cdecl*)(void*)) = NULL;
    int          (__cdecl *bind_blob)(sqlite3_stmt*, int, const void*, int, void(__cdecl*)(void*)) = NULL;
    int          (__cdecl *bind_null)(sqlite3_stmt*, int) = NULL;

    void         (__cdecl *progress_handler)(sqlite3*, int, int(__cdecl*)(void*), void*) = NULL;
    int          (__cdecl *libversion_number)(void) = NULL;
    int          (__cdecl *threadsafe)(void) = NULL;
    int          (__cdecl *changes)(sqlite3*) = NULL;
    void         (__cdecl *free_)(void*) = NULL;
};

static SQLiteAPI SQ;
static std::once_flag SQbindOnce;

static void bindSQLiteOnce() {
    std::call_once(SQbindOnce, []() {
        SQ.hLib = GetModuleHandleW(L"sqlite3.dll");
        if (SQ.hLib==NULL)
           SQ.hLib = LoadLibraryW(L"sqlite3.dll");

        if (SQ.hLib==NULL)
        {
           fnOutputDebug("dupesEngine: sqlite3.dll not present; the DLL cannot read the database itself");
           return;
        }

        #define BINDSQ(field, name) *(FARPROC*)&SQ.field = GetProcAddress(SQ.hLib, name)
        BINDSQ(open_v2,           "sqlite3_open_v2");
        BINDSQ(close_v2,          "sqlite3_close_v2");
        BINDSQ(prepare16_v2,      "sqlite3_prepare16_v2");
        BINDSQ(step,              "sqlite3_step");
        BINDSQ(reset,             "sqlite3_reset");
        BINDSQ(finalize,          "sqlite3_finalize");
        BINDSQ(exec,              "sqlite3_exec");
        BINDSQ(interrupt,         "sqlite3_interrupt");
        BINDSQ(errmsg16,          "sqlite3_errmsg16");
        BINDSQ(column_count,      "sqlite3_column_count");
        BINDSQ(column_type,       "sqlite3_column_type");
        BINDSQ(column_int64,      "sqlite3_column_int64");
        BINDSQ(column_double,     "sqlite3_column_double");
        BINDSQ(column_text16,     "sqlite3_column_text16");
        BINDSQ(column_bytes16,    "sqlite3_column_bytes16");
        BINDSQ(column_blob,       "sqlite3_column_blob");
        BINDSQ(column_bytes,      "sqlite3_column_bytes");
        BINDSQ(bind_int64,        "sqlite3_bind_int64");
        BINDSQ(bind_double,       "sqlite3_bind_double");
        BINDSQ(bind_text16,       "sqlite3_bind_text16");
        BINDSQ(bind_blob,         "sqlite3_bind_blob");
        BINDSQ(bind_null,         "sqlite3_bind_null");
        BINDSQ(progress_handler,  "sqlite3_progress_handler");
        BINDSQ(libversion_number, "sqlite3_libversion_number");
        BINDSQ(threadsafe,        "sqlite3_threadsafe");
        BINDSQ(changes,           "sqlite3_changes");
        BINDSQ(free_,             "sqlite3_free");
        #undef BINDSQ

        // close_v2 arrived in 3.7.14 and prepare16_v2 in 3.3.9; the AHK class already
        // refuses anything below 3.6, and the engine needs both, so a shipped DLL that
        // predates them simply leaves the engine off rather than crashing later.
        // bind_text16 and bind_int64 belong in this list as much as the column readers do:
        // the hash loop only wraps them in a NULL test, so without them its UPDATE would
        // run on unbound (NULL) parameters, match no row, still report SQLITE_DONE, and
        // hand the same rows back on every batch forever.
        SQ.ok = (SQ.open_v2 && SQ.close_v2 && SQ.prepare16_v2 && SQ.step && SQ.reset && SQ.finalize
              && SQ.column_type && SQ.column_int64 && SQ.column_double && SQ.column_text16
              && SQ.column_bytes16 && SQ.column_blob && SQ.column_bytes && SQ.column_count && SQ.interrupt
              && SQ.bind_int64 && SQ.bind_text16);

        if (SQ.ok)
           fnOutputDebug("dupesEngine: sqlite3.dll bound successfully");
        else
           fnOutputDebug("dupesEngine: sqlite3.dll found but required entry points are missing");
    });
}

#endif // QPV_SQLITE_DYNAMIC_H
