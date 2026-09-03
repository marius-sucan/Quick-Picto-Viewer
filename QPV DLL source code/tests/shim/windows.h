// Stand-in <windows.h> for the tests, found ahead of the real one via -Ishim.
//
// sqlite-dynamic.h binds sqlite3 by name through LoadLibraryW/GetProcAddress. Sending
// those to dlopen/dlsym is the whole trick that lets query_engine.cpp exercise the
// SHIPPED engine against a real libsqlite3 on a machine with no MSVC: nothing about the
// engine is mocked, only the loader underneath it.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_WINDOWS_H
#define QPV_TEST_WINDOWS_H

#include <cstring>
#include <cstdlib>
#include <string>
#include <dlfcn.h>

typedef void*              HMODULE;
typedef void*              FARPROC;
typedef void*              HWND;
typedef int                BOOL;
typedef unsigned long      DWORD;
typedef unsigned int       UINT;
typedef long long          INT64;
typedef unsigned long long UINT64;
typedef int                INT;
typedef int                LONG;      // Windows LONG is 32-bit; "long" here is 64-bit
typedef short              SHORT;
typedef const wchar_t*     LPCWSTR;

#define __cdecl
#define CP_UTF8 65001

// The engine tries GetModuleHandleW first ("AHK already loaded it") and LoadLibraryW as
// the fallback, so returning NULL here routes it down the dlopen path.
static inline HMODULE GetModuleHandleW(const wchar_t*) { return NULL; }
static inline HMODULE LoadLibraryW(const wchar_t*)     { return dlopen("libsqlite3.so.0", RTLD_NOW); }

// ---- the wchar_t adapters ------------------------------------------------------------
//
// wchar_t is 2 bytes on Windows and 4 here, while sqlite3's *16 entry points always speak
// 2-byte UTF-16. On Windows those coincide, which is exactly why the engine can read
// sqlite3_column_text16() straight into a const wchar_t* and skip a UTF-8 conversion per
// column. Here they do not, so GetProcAddress hands back adapters that speak this
// platform's wchar_t and call the UTF-8 entry points underneath.
//
// Only the loader lies: the engine itself is compiled verbatim and never learns about it.

#include <vector>
#include <map>

static inline std::string qpvT_toUTF8(const wchar_t *s) {
    std::string out;
    if (s==NULL) return out;
    for (const wchar_t *p = s; *p; p++)
    {
        const unsigned int c = (unsigned int)*p;
        if (c < 0x80) out.push_back((char)c);
        else if (c < 0x800) { out.push_back((char)(0xC0 | (c >> 6))); out.push_back((char)(0x80 | (c & 0x3F))); }
        else if (c < 0x10000) { out.push_back((char)(0xE0 | (c >> 12))); out.push_back((char)(0x80 | ((c >> 6) & 0x3F))); out.push_back((char)(0x80 | (c & 0x3F))); }
        else { out.push_back((char)(0xF0 | (c >> 18))); out.push_back((char)(0x80 | ((c >> 12) & 0x3F))); out.push_back((char)(0x80 | ((c >> 6) & 0x3F))); out.push_back((char)(0x80 | (c & 0x3F))); }
    }
    return out;
}

static inline std::wstring qpvT_fromUTF8(const unsigned char *s, int nbytes) {
    std::wstring out;
    if (s==NULL) return out;
    int i = 0;
    while (i < nbytes)
    {
        const unsigned char c = s[i];
        unsigned int cp; int len;
        if (c < 0x80)        { cp = c; len = 1; }
        else if ((c & 0xE0)==0xC0) { cp = c & 0x1F; len = 2; }
        else if ((c & 0xF0)==0xE0) { cp = c & 0x0F; len = 3; }
        else                 { cp = c & 0x07; len = 4; }
        if (i + len > nbytes) break;
        for (int k = 1; k < len; k++) cp = (cp << 6) | (s[i + k] & 0x3F);
        out.push_back((wchar_t)cp);
        i += len;
    }
    return out;
}

struct QpvSqliteReal {
    void *h = NULL;
    int   (*prepare_v2)(void*, const char*, int, void**, const char**) = NULL;
    const unsigned char* (*column_text)(void*, int) = NULL;
    int   (*column_bytes)(void*, int) = NULL;
    const char* (*errmsg)(void*) = NULL;
    int   (*bind_text)(void*, int, const char*, int, void(*)(void*)) = NULL;
};
static QpvSqliteReal qpvSQreal;

// One scratch buffer per column index: the engine reads a column's text and its length
// back to back, then moves on, so nothing has to survive past the next read of the SAME
// column. Keyed by (statement, column) so two statements cannot tread on each other.
static std::map<std::pair<void*,int>, std::wstring> qpvT_textCache;

static inline const std::wstring& qpvT_colText(void *st, int col) {
    const std::pair<void*,int> key(st, col);
    const unsigned char *u = qpvSQreal.column_text(st, col);
    const int n = qpvSQreal.column_bytes(st, col);
    qpvT_textCache[key] = (u!=NULL) ? qpvT_fromUTF8(u, n) : std::wstring();
    return qpvT_textCache[key];
}

extern "C" {
static int qpvT_prepare16_v2(void *db, const void *sql, int, void **stmt, const void **tail) {
    const std::string u = qpvT_toUTF8((const wchar_t*)sql);
    if (tail) *tail = NULL;
    return qpvSQreal.prepare_v2(db, u.c_str(), -1, stmt, NULL);
}
static const void* qpvT_column_text16(void *st, int col) {
    const std::wstring &w = qpvT_colText(st, col);
    // a NULL column has to stay NULL: the engine tells "absent" from "empty" by it
    if (qpvSQreal.column_text(st, col)==NULL) return NULL;
    return (const void*)w.c_str();
}
static int qpvT_column_bytes16(void *st, int col) {
    const std::pair<void*,int> key(st, col);
    std::map<std::pair<void*,int>, std::wstring>::const_iterator it = qpvT_textCache.find(key);
    const std::wstring &w = (it!=qpvT_textCache.end()) ? it->second : qpvT_colText(st, col);
    return (int)(w.size() * sizeof(wchar_t));
}
static const void* qpvT_errmsg16(void *db) {
    static std::wstring w;
    const char *m = qpvSQreal.errmsg ? qpvSQreal.errmsg(db) : NULL;
    w = (m!=NULL) ? qpvT_fromUTF8((const unsigned char*)m, (int)strlen(m)) : std::wstring();
    return (const void*)w.c_str();
}
static int qpvT_bind_text16(void *st, int idx, const void *s, int, void(*d)(void*)) {
    static std::string u;
    u = qpvT_toUTF8((const wchar_t*)s);
    return qpvSQreal.bind_text(st, idx, u.c_str(), -1, d);
}
}

static inline FARPROC GetProcAddress(HMODULE h, const char *n) {
    if (h==NULL) return NULL;
    if (qpvSQreal.h!=h)
    {
       qpvSQreal.h = h;
       *(void**)&qpvSQreal.prepare_v2   = dlsym(h, "sqlite3_prepare_v2");
       *(void**)&qpvSQreal.column_text  = dlsym(h, "sqlite3_column_text");
       *(void**)&qpvSQreal.column_bytes = dlsym(h, "sqlite3_column_bytes");
       *(void**)&qpvSQreal.errmsg       = dlsym(h, "sqlite3_errmsg");
       *(void**)&qpvSQreal.bind_text    = dlsym(h, "sqlite3_bind_text");
    }

    if (!strcmp(n, "sqlite3_prepare16_v2"))   return (FARPROC)qpvT_prepare16_v2;
    if (!strcmp(n, "sqlite3_column_text16"))  return (FARPROC)qpvT_column_text16;
    if (!strcmp(n, "sqlite3_column_bytes16")) return (FARPROC)qpvT_column_bytes16;
    if (!strcmp(n, "sqlite3_errmsg16"))       return (FARPROC)qpvT_errmsg16;
    if (!strcmp(n, "sqlite3_bind_text16"))    return (FARPROC)qpvT_bind_text16;
    return dlsym(h, n);
}

// Only ever called on a database path. Enough of UTF-8 to carry one.
static inline int WideCharToMultiByte(int, int, const wchar_t *src, int, char *dst, int cap, void*, void*) {
    std::string out;
    for (const wchar_t *p = src; *p; p++)
    {
        const unsigned int c = (unsigned int)*p;
        if (c < 0x80)
           out.push_back((char)c);
        else if (c < 0x800)
        {
           out.push_back((char)(0xC0 | (c >> 6)));
           out.push_back((char)(0x80 | (c & 0x3F)));
        }
        else
        {
           out.push_back((char)(0xE0 | (c >> 12)));
           out.push_back((char)(0x80 | ((c >> 6) & 0x3F)));
           out.push_back((char)(0x80 | (c & 0x3F)));
        }
    }

    const int need = (int)out.size() + 1;
    if (dst==NULL || cap==0)
       return need;
    if (cap < need)
       return 0;

    memcpy(dst, out.c_str(), (size_t)need);
    return need;
}

#endif // QPV_TEST_WINDOWS_H
