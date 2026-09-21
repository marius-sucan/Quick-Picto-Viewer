// The environment pdf-writer.h expects to be #included into.
//
// In the real build that is qpv-main.cpp, after windows.h. Here the handful of Win32 file
// calls the writer makes are mapped onto POSIX, with three hooks the tests use to fail on
// purpose: a disk that fills up after a given number of bytes, a destination another
// program holds open, and a rename that is refused.
//
// written by Marius Șucan with Claude Opus 5

#ifndef QPV_TEST_PDF_ENV_H
#define QPV_TEST_PDF_ENV_H

#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cerrno>
#include <string>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

typedef unsigned char      BYTE;
typedef unsigned int       UINT;
typedef unsigned int       DWORD;       // 32 bits, as on Windows
typedef unsigned long long UINT64;
typedef long long          LONGLONG;
typedef int                BOOL;
typedef void*              HANDLE;
typedef union { struct { DWORD LowPart; int HighPart; } u; LONGLONG QuadPart; } LARGE_INTEGER;

#define DLL_API
#define DLL_CALLCONV
#define INVALID_HANDLE_VALUE       ((HANDLE)(intptr_t)-1)
#define GENERIC_READ               0x80000000u
#define GENERIC_WRITE              0x40000000u
#define DELETE                     0x00010000u
#define FILE_SHARE_READ            1
#define FILE_SHARE_WRITE           2
#define FILE_SHARE_DELETE          4
#define CREATE_NEW                 1
#define OPEN_EXISTING              3
#define FILE_ATTRIBUTE_NORMAL      0x80
#define FILE_FLAG_SEQUENTIAL_SCAN  0x08000000
#define FILE_BEGIN                 0
#define MOVEFILE_REPLACE_EXISTING  1
#define MOVEFILE_WRITE_THROUGH     8
#define ERROR_FILE_NOT_FOUND       2
#define ERROR_PATH_NOT_FOUND       3
#define ERROR_ACCESS_DENIED        5
#define ERROR_SHARING_VIOLATION    32
#define ERROR_FILE_EXISTS          80
#define ERROR_ALREADY_EXISTS       183

static std::string gShimDebug;
static inline void fnOutputDebug(std::string s) { gShimDebug = s; }

// the hooks
static long long   gShimDiskLeft = -1;       // bytes the disk still takes; -1 = unlimited
static std::string gShimBusyPath;            // opening this one for writing fails as "in use"
static bool        gShimRefuseRename = false;
static DWORD       gShimLastError = 0;

static inline DWORD GetLastError() { return gShimLastError; }

static inline std::string shimPath(const wchar_t *s) {
    std::string out;
    for (; s && *s; s++)
    {
        const unsigned int c = (unsigned int)*s;
        if (c < 0x80) out.push_back((char)c);
        else if (c < 0x800) { out.push_back((char)(0xC0 | (c >> 6))); out.push_back((char)(0x80 | (c & 0x3F))); }
        else if (c < 0x10000) { out.push_back((char)(0xE0 | (c >> 12))); out.push_back((char)(0x80 | ((c >> 6) & 0x3F))); out.push_back((char)(0x80 | (c & 0x3F))); }
        else { out.push_back((char)(0xF0 | (c >> 18))); out.push_back((char)(0x80 | ((c >> 12) & 0x3F))); out.push_back((char)(0x80 | ((c >> 6) & 0x3F))); out.push_back((char)(0x80 | (c & 0x3F))); }
    }
    return out;
}

static inline DWORD shimError(int e) {
    switch (e)
    {
       case ENOENT:  return ERROR_FILE_NOT_FOUND;
       case ENOTDIR: return ERROR_PATH_NOT_FOUND;
       case EEXIST:  return ERROR_FILE_EXISTS;
       default:      return ERROR_ACCESS_DENIED;
    }
}

static inline HANDLE CreateFileW(const wchar_t *name, DWORD access, DWORD, void*, DWORD disposition, DWORD, void*) {
    const std::string path = shimPath(name);
    if ((access & GENERIC_WRITE) && path==gShimBusyPath)
    {
       gShimLastError = ERROR_SHARING_VIOLATION;
       return INVALID_HANDLE_VALUE;
    }

    int flags = (access & GENERIC_WRITE) ? O_WRONLY : O_RDONLY;
    if (disposition==CREATE_NEW)
       flags |= O_CREAT | O_EXCL;

    const int fd = open(path.c_str(), flags, 0644);
    if (fd < 0)
    {
       gShimLastError = shimError(errno);
       return INVALID_HANDLE_VALUE;
    }
    return (HANDLE)(intptr_t)(fd + 1);
}

static inline int shimFd(HANDLE h) { return (int)(intptr_t)h - 1; }

static inline BOOL CloseHandle(HANDLE h) { return close(shimFd(h))==0; }

static inline BOOL ReadFile(HANDLE h, void *buf, DWORD n, DWORD *got, void*) {
    const ssize_t r = read(shimFd(h), buf, n);
    *got = (r > 0) ? (DWORD)r : 0;
    return r >= 0;
}

static inline BOOL WriteFile(HANDLE h, const void *buf, DWORD n, DWORD *wrote, void*) {
    *wrote = 0;
    DWORD take = n;
    if (gShimDiskLeft>=0 && (long long)take > gShimDiskLeft)
       take = (DWORD)gShimDiskLeft;
    if (take==0 && n>0)
       return 0;

    const ssize_t r = write(shimFd(h), buf, take);
    if (r < 0)
       return 0;
    if (gShimDiskLeft>=0)
       gShimDiskLeft -= r;
    *wrote = (DWORD)r;
    return 1;
}

static inline BOOL SetFilePointerEx(HANDLE h, LARGE_INTEGER pos, void*, DWORD) {
    return lseek(shimFd(h), (off_t)pos.QuadPart, SEEK_SET)>=0;
}

static inline BOOL SetEndOfFile(HANDLE h) {
    const off_t at = lseek(shimFd(h), 0, SEEK_CUR);
    return at>=0 && ftruncate(shimFd(h), at)==0;
}

static inline BOOL MoveFileExW(const wchar_t *from, const wchar_t *to, DWORD) {
    if (gShimRefuseRename)
       return 0;
    return rename(shimPath(from).c_str(), shimPath(to).c_str())==0;
}

static inline BOOL DeleteFileW(const wchar_t *name) {
    return unlink(shimPath(name).c_str())==0;
}

#endif
