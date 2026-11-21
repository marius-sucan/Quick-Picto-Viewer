// dir-scan.h
//
// The per-file work of GetFilesList(). The script reads a folder in blocks of directory
// records [GetFileInformationByHandleEx()] and hands every block over:
//
//    DirScanCompileExts()   the image file extensions, as a lookup table      once
//    DirScanParseBlock()    one block: its image files and its sub-folders    per block
//    DirScanInsertRows()    the files of one parsed block, into the SLDB      per block
//
// Nothing here keeps any state: the table and the buffers belong to the script.
//
// File names are UTF-16 and are typed "unsigned short" throughout, so that the tests can
// compile this very file where wchar_t is 4 bytes wide.
//
// #included by qpv-main.cpp after qpvFileTimeToLocalStamp(): it also uses DLL_API,
// DLL_CALLCONV and QPV_FORCEINLINE from there.
//
// written by Marius Șucan with Claude Fable 5

#ifndef QPV_DIR_SCAN_H
#define QPV_DIR_SCAN_H

#include <cstring>
#include <cstdlib>
#include "sqlite-dynamic.h"

#define QPV_DS_EXT_MAGIC    0x54584551u   // "QEXT"
#define QPV_DS_FIXED_HEAD   24            // fixed records: size, modified, created; then the name
#define QPV_DS_PACKED_HEAD  40            // packed records: the same, row ID, record bytes, name bytes; then the name
#define QPV_DS_NO_ROW       -1            // the row ID of a record that has no row in the database
#define QPV_DS_KEEP_FILE    1
#define QPV_DS_SUB_FOLDER   2
#define QPV_DS_STACK_NAME   300           // characters; NTFS names hold 255 at most

static QPV_FORCEINLINE unsigned int qpvDSfold(unsigned int c) {
// ASCII only, the way AHK compares the string keys of an object
    return (c - 65u < 26u) ? c + 32u : c;
}

static QPV_FORCEINLINE unsigned int qpvDShashExt(const unsigned short *s, unsigned int n) {
    unsigned int h = 2166136261u;       // FNV-1a
    for (unsigned int i = 0; i < n; i++)
        h = (h ^ qpvDSfold(s[i])) * 16777619u;

    return h;
}

DLL_API int DLL_CALLCONV DirScanCompileExts(const unsigned short *extList, unsigned char *table, int tableBytes) {
// extList is "jpg|png|...", the RegExAllFilesPattern of the script.
// Returns the bytes written into the table. When the table is missing or too small,
// nothing is written and the bytes it needs are returned, as a negative number.
//
// The table: 4 unsigned ints [magic, slots, bytes, longest extension], one unsigned int
// per slot [the offset of an entry, 0 when free], then the entries, each one its length
// in characters followed by its characters, lower-cased.
    if (extList==NULL)
       return 0;

    unsigned int count = 0, poolBytes = 0, longest = 0;
    for (const unsigned short *p = extList; ; )
    {
        unsigned int n = 0;
        while (p[n] && p[n]!='|')
           n++;

        if (n)
        {
           count++;
           poolBytes += 2 + n*2;
           if (n > longest)
              longest = n;
        }

        if (!p[n])
           break;
        p += n + 1;
    }

    unsigned int slots = 16;
    while (slots < count*2)
       slots <<= 1;

    const unsigned int need = 16 + slots*4 + poolBytes;
    if (table==NULL || tableBytes < 0 || (unsigned int)tableBytes < need)
       return -(int)need;

    unsigned int *head = (unsigned int*)table;
    unsigned int *slot = head + 4;
    head[0] = QPV_DS_EXT_MAGIC;
    head[1] = slots;
    head[2] = need;
    head[3] = longest;
    std::memset(slot, 0, (size_t)slots*4);

    unsigned int at = 16 + slots*4;
    for (const unsigned short *p = extList; ; )
    {
        unsigned int n = 0;
        while (p[n] && p[n]!='|')
           n++;

        if (n)
        {
           unsigned short *e = (unsigned short*)(table + at);
           e[0] = (unsigned short)n;
           for (unsigned int k = 0; k < n; k++)
               e[k + 1] = (unsigned short)qpvDSfold(p[k]);

           // an extension listed twice keeps its first entry
           unsigned int i = qpvDShashExt(p, n) & (slots - 1);
           bool listed = false;
           while (slot[i])
           {
               const unsigned short *o = (const unsigned short*)(table + slot[i]);
               if (o[0]==n && std::memcmp(o + 1, e + 1, (size_t)n*2)==0)
               {
                  listed = true;
                  break;
               }
               i = (i + 1) & (slots - 1);
           }

           if (!listed)
           {
              slot[i] = at;
              at += 2 + n*2;
           }
        }

        if (!p[n])
           break;
        p += n + 1;
    }

    return (int)need;
}

static QPV_FORCEINLINE int qpvDSisListedExt(const unsigned char *table, const unsigned short *ext, unsigned int n) {
    const unsigned int *head = (const unsigned int*)table;
    if (n==0 || n > head[3])
       return 0;

    const unsigned int mask = head[1] - 1;
    const unsigned int *slot = head + 4;
    for (unsigned int i = qpvDShashExt(ext, n) & mask; slot[i]; i = (i + 1) & mask)
    {
        const unsigned short *e = (const unsigned short*)(table + slot[i]);
        if (e[0]!=n)
           continue;

        unsigned int k = 0;
        while (k < n && e[k + 1]==qpvDSfold(ext[k]))
           k++;

        if (k==n)
           return 1;
    }

    return 0;
}

static QPV_FORCEINLINE int qpvDSclassify(const unsigned char *entry, const unsigned short *name, unsigned int nameChars, const unsigned char *extTable, INT64 biggerThan, int flags) {
// What one directory record is to the scan: nothing, a file to keep or a sub-folder to walk.
// FileAttributes sits at offset 56 and EndOfFile at 40 in both record layouts.
    unsigned int attr;
    std::memcpy(&attr, entry + 56, 4);
    if (attr & 0x10)        // FILE_ATTRIBUTE_DIRECTORY
    {
       // 0x400 = FILE_ATTRIBUTE_REPARSE_POINT: junctions and symbolic links are not followed
       if (!(flags & 1) || nameChars==0 || (attr & 0x400))
          return 0;

       if (name[0]=='.' && (nameChars==1 || (nameChars==2 && name[1]=='.')))
          return 0;

       return QPV_DS_SUB_FOLDER;
    }

    INT64 fsize;
    std::memcpy(&fsize, entry + 40, 8);
    if (fsize <= biggerThan)
       return 0;

    unsigned int dot = nameChars;      // the extension starts after the last dot
    while (dot > 0 && name[dot - 1]!='.')
       dot--;

    if (dot==0)
       return 0;

    return qpvDSisListedExt(extTable, name + dot, nameChars - dot) ? QPV_DS_KEEP_FILE : 0;
}

DLL_API int DLL_CALLCONV DirScanParseBlock(const unsigned char *block, int blockBytes, int nameOffset, const unsigned char *extTable, INT64 biggerThan, int flags, unsigned char *out, int outBytes, int *info) {
// block        directory records, FILE_FULL_DIR_INFO or FILE_ID_BOTH_DIR_INFO, chained by
//              NextEntryOffset; blockBytes is the size of the buffer that holds them
// nameOffset   where FileName sits in a record: 68 or 104
// biggerThan   files of this size or smaller are left out
// flags        1 = list the sub-folders too; 2 = packed file records
//
// The files that carry a listed extension are written at the start of [out]:
//    fixed layout    size, modified, created [INT64 each], name; one stride for all of them
//    packed layout   size, modified, created, row ID [INT64 each], record bytes, name bytes
//                    [unsigned int each], name; every record padded to 8 bytes. The row ID
//                    is -1 until DirScanInsertRows() gives the record one
// The two times are local YYYYMMDDHHMISS numbers and the names are null terminated. The
// names of the sub-folders follow the file records, one stride each.
//
//    info[0]   bytes taken by the file records, which is where the folder names start
//    info[1]   the stride of the file records, fixed layout only
//    info[2]   how many sub-folders
//    info[3]   the stride of the folder names
//
// Returns the number of files written; -1 when [out] is too small, with the bytes it
// needs in info[0]; -2 on arguments that cannot be used.
    if (block==NULL || extTable==NULL || out==NULL || info==NULL || nameOffset < 64 || blockBytes < nameOffset || outBytes < 0)
       return -2;

    if (((const unsigned int*)extTable)[0]!=QPV_DS_EXT_MAGIC)
       return -2;

    const bool packed = (flags & 2)!=0;
    const unsigned char *blockEnd = block + blockBytes;
    unsigned int nFiles = 0, nDirs = 0, longestFile = 0, longestDir = 0, fileStride = 0, dirStride = 0;
    UINT64 filesBytes = 0;
    unsigned char *fileOut = out, *dirOut = out;

    // the first pass measures, the second one writes
    for (int pass = 0; pass < 2; pass++)
    {
        for (const unsigned char *e = block; blockEnd - e >= nameOffset; )
        {
            unsigned int nextOffset, nameBytes;
            std::memcpy(&nextOffset, e, 4);
            std::memcpy(&nameBytes, e + 60, 4);
            if (nameBytes > (size_t)(blockEnd - e - nameOffset))
               break;      // a record that runs past the block

            const unsigned short *name = (const unsigned short*)(e + nameOffset);
            const unsigned int nameChars = nameBytes/2;
            const int kind = qpvDSclassify(e, name, nameChars, extTable, biggerThan, flags);
            if (kind==QPV_DS_KEEP_FILE && pass==0)
            {
               nFiles++;
               filesBytes += (QPV_DS_PACKED_HEAD + (UINT64)nameChars*2 + 2 + 7) & ~(UINT64)7;
               if (nameChars > longestFile)
                  longestFile = nameChars;
            } else if (kind==QPV_DS_KEEP_FILE)
            {
               // CreationTime sits at offset 8 and LastWriteTime at 24, in both record layouts
               INT64 head[3], ctime, mtime;
               std::memcpy(&head[0], e + 40, 8);
               std::memcpy(&ctime, e + 8, 8);
               std::memcpy(&mtime, e + 24, 8);
               head[1] = qpvFileTimeToLocalStamp(mtime);
               head[2] = qpvFileTimeToLocalStamp(ctime);
               std::memcpy(fileOut, head, 24);

               unsigned int recBytes = fileStride, nameAt = QPV_DS_FIXED_HEAD;
               if (packed)
               {
                  const INT64 noRowID = QPV_DS_NO_ROW;
                  recBytes = (QPV_DS_PACKED_HEAD + nameChars*2 + 2 + 7) & ~7u;
                  nameAt = QPV_DS_PACKED_HEAD;
                  const unsigned int nameBytesKept = nameChars*2;
                  std::memcpy(fileOut + 24, &noRowID, 8);
                  std::memcpy(fileOut + 32, &recBytes, 4);
                  std::memcpy(fileOut + 36, &nameBytesKept, 4);
               }

               std::memcpy(fileOut + nameAt, name, (size_t)nameChars*2);
               std::memset(fileOut + nameAt + nameChars*2, 0, recBytes - nameAt - nameChars*2);
               fileOut += recBytes;
            } else if (kind==QPV_DS_SUB_FOLDER && pass==0)
            {
               nDirs++;
               if (nameChars > longestDir)
                  longestDir = nameChars;
            } else if (kind==QPV_DS_SUB_FOLDER)
            {
               std::memcpy(dirOut, name, (size_t)nameChars*2);
               std::memset(dirOut + nameChars*2, 0, dirStride - nameChars*2);
               dirOut += dirStride;
            }

            if (nextOffset==0 || nextOffset > (size_t)(blockEnd - e))
               break;
            e += nextOffset;
        }

        if (pass==0)
        {
           fileStride = (QPV_DS_FIXED_HEAD + (longestFile + 1)*2 + 7) & ~7u;
           dirStride = (longestDir + 1)*2;
           if (!packed)
              filesBytes = (UINT64)nFiles*fileStride;

           const UINT64 need = filesBytes + (UINT64)nDirs*dirStride;
           if (need > 0x7FFFFFFFu)
              return -2;

           if (need > (UINT64)outBytes)
           {
              info[0] = (int)need;
              return -1;
           }

           dirOut = out + filesBytes;
        }
    }

    info[0] = (int)filesBytes;
    info[1] = packed ? 0 : (int)fileStride;
    info[2] = (int)nDirs;
    info[3] = (int)dirStride;
    return (int)nFiles;
}

DLL_API int DLL_CALLCONV DirScanInsertRows(void *ahkDb, void *ahkStmt, unsigned char *records, int count, const unsigned short *folderLower, INT64 *nextRowID, int factCheck) {
// Runs the statement the script prepared once for every packed record of one block:
//    INSERT INTO images (imgidu, isDeleted, imgfile, imgfolder, fsize, fmodified, fcreated)
//    VALUES (?1, 0, ?2, ?3, ?4, ?5, ?6) ON CONFLICT(fullPath) DO UPDATE SET isDeleted=0;
//
// It decides what addSQLdbEntry() of the script decides. The file name is stored lower-
// cased, as the folder already is, and the two times without their seconds. A row takes
// *nextRowID and moves it on, unless the statement fails, or, with factCheck=1, unless
// the file was in the database already and no new row came out of it.
//
// Every record receives the row ID it took, or -1. Returns how many took one; -1 on
// arguments that cannot be used.
    bindSQLiteOnce();
    if (!SQ.ok || SQ.last_insert_rowid==NULL || ahkDb==NULL || ahkStmt==NULL || records==NULL
    || folderLower==NULL || nextRowID==NULL || count < 0)
       return -1;

    sqlite3 *db = (sqlite3*)ahkDb;
    sqlite3_stmt *stmt = (sqlite3_stmt*)ahkStmt;
    int folderBytes = 0;
    while (folderLower[folderBytes])
       folderBytes++;
    folderBytes *= 2;

    INT64 rowID = *nextRowID;
    INT64 lastNewRow = (factCheck==1) ? SQ.last_insert_rowid(db) : 0;
    unsigned short stackName[QPV_DS_STACK_NAME];
    int added = 0;
    unsigned char *rec = records;
    for (int i = 0; i < count; i++)
    {
        INT64 fsize, modified, created, given = QPV_DS_NO_ROW;
        unsigned int recBytes, nameBytes;
        std::memcpy(&fsize, rec, 8);
        std::memcpy(&modified, rec + 8, 8);
        std::memcpy(&created, rec + 16, 8);
        std::memcpy(&recBytes, rec + 32, 4);
        std::memcpy(&nameBytes, rec + 36, 4);

        const unsigned int nameChars = nameBytes/2;
        unsigned short *lower = stackName;
        if (nameChars >= QPV_DS_STACK_NAME)
           lower = (unsigned short*)std::malloc(((size_t)nameChars + 1)*2);

        if (lower!=NULL)
        {
           std::memcpy(lower, rec + QPV_DS_PACKED_HEAD, (size_t)nameChars*2);
           lower[nameChars] = 0;
           CharLowerBuffW((LPWSTR)lower, nameChars);    // what Format("{:L}") of AHK calls

           // the two texts stay where they are until the statement is reset
           SQ.bind_int64(stmt, 1, rowID);
           SQ.bind_text16(stmt, 2, lower, (int)(nameChars*2), QPV_SQLITE_STATIC);
           SQ.bind_text16(stmt, 3, folderLower, folderBytes, QPV_SQLITE_STATIC);
           SQ.bind_int64(stmt, 4, fsize);
           SQ.bind_int64(stmt, 5, modified/100);
           SQ.bind_int64(stmt, 6, created/100);
           const int rc = SQ.step(stmt);
           SQ.reset(stmt);
           if (rc==SQLITE_DONE)
           {
              if (factCheck==1)
              {
                 // an entry that was only brought back to life inserts nothing
                 const INT64 last = SQ.last_insert_rowid(db);
                 if (last!=lastNewRow && last!=0)
                 {
                    lastNewRow = last;
                    given = rowID;
                 }
              } else given = rowID;
           }

           if (lower!=stackName)
              std::free(lower);
        }

        if (given >= 0)
        {
           rowID++;
           added++;
        }

        std::memcpy(rec + 24, &given, 8);
        rec += recBytes;
    }

    // nothing of this call may stay bound once its buffers are gone
    if (SQ.bind_null!=NULL)
    {
       SQ.bind_null(stmt, 2);
       SQ.bind_null(stmt, 3);
    }

    *nextRowID = rowID;
    return added;
}

#endif // QPV_DIR_SCAN_H
