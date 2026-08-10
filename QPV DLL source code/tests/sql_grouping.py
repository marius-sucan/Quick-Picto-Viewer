#!/usr/bin/env python3
# Does the ordered-scan grouping put the same images in the same groups as the self-join
# it replaces?
#
# retrieveDupesByProperties() used to discover the groups with
#
#   SELECT ... FROM images AS a
#   JOIN (SELECT <Round()ed cols>, ROWID AS groupID FROM images
#         WHERE ... GROUP BY <cols> HAVING count(*)>1) AS b ON (a.c1=b.c1 AND ...)
#
# i.e. a full scan, a temp B-tree for the GROUP BY, a second scan and a join probe. The
# DLL now runs one sorted scan and cuts a group wherever the key tuple changes.
#
# That moves the equality test out of SQLite and into C++, which is only safe if C++
# reproduces SQLite's comparison rules exactly. The images schema makes that non-trivial:
# imgfile and imgpixfmt are COLLATE NOCASE, several grouping columns are generated
# (imgwhratio, imgmegapix, kbfsize) and SQLite is dynamically typed, so a column can hold
# INTEGER and REAL at once.
#
# This builds the real schema, fills it with values chosen to break a naive comparison,
# and diffs the two groupings for every column set the Find Duplicates panel can produce.
# keyEquals() below is the specification the C++ has to implement.
#
# written by Marius Șucan with Claude Opus 5

import sqlite3, sys, itertools, random

# verbatim from quick-picto-viewer.ahk:72805
SCHEMA = """
CREATE TABLE images (imgidu NUMERIC PRIMARY KEY NOT NULL, imgfile TEXT COLLATE NOCASE NOT NULL,
 imgfolder TEXT COLLATE NOCASE NOT NULL, fullPath TEXT AS (imgfolder||'\\'||imgfile), fsize INT,
 kbfsize FLOAT AS (round(cast(fsize AS float)/1024,1)), fmodified INT, fcreated INT, imgwidth INT,
 imgheight INT, imgframes INT, imgdpi INT, imgpixfmt TEXT COLLATE NOCASE,
 imgwhratio FLOAT AS (round(cast(imgwidth AS float)/imgheight, 5)),
 imgmegapix FLOAT AS (round((cast(imgwidth AS float)*imgheight)/1000000, 5)), imgmedian FLOAT,
 imgavg FLOAT, imghpeak FLOAT, imghlow FLOAT, imghmode FLOAT, imghrms FLOAT, imghminu FLOAT,
 imghrange FLOAT,
 dHash TEXT, pHash TEXT, lHash TEXT, HdHash TEXT, HpHash TEXT, HlHash TEXT,
 isDeleted INT DEFAULT 0, UNIQUE (fullPath));
"""

# notFloatsRegEX from retrieveDupesByProperties(); everything else is wrapped in Round().
NOT_FLOATS = {"fcreated", "fmodified", "fsize", "imgfile", "dHash", "lHash", "pHash",
              "imgwidth", "imgheight", "imgframes", "imgdpi", "imgpixfmt"}
NOCASE = {"imgfile", "imgpixfmt", "imgfolder"}

# every preset BTNfindDupesNow() can hand over, plus the checkbox-built combinations
COLSETS = [
    "imgwhratio,imgframes",
    "fsize,imgmegapix,imgwhratio,imgframes",
    "kbfsize,imgframes,imgmegapix,imgwhratio,imgavg,imghpeak,imgmedian,imghlow",
    "imgfile,imgframes",
    "fsize,imgfile,imgframes",
    "imgpixfmt,imgwidth,imgheight",
    "imgmedian,imgavg,imghpeak",
    "fcreated,fmodified",
    "imgdpi,imgpixfmt",
    "imgmegapix",
    "imgavg,imghrms,imghmode,imghminu,imghrange",
]

def build(db, n=900, seed=7):
    rnd = random.Random(seed)
    db.executescript(SCHEMA)
    rows = []
    # a small pool of values per column, so collisions - i.e. real groups - are common
    widths  = [640, 800, 1920, 1920, 3, 1]
    heights = [480, 600, 1080, 1081, 4, 1]
    frames  = [1, 1, 1, 2, 12, None]
    dpis    = [72, 96, 300, None]
    # deliberately mixed case: imgpixfmt is COLLATE NOCASE, so "24bppRGB" and "24BPPrgb"
    # are the same group to SQLite and must be to the C++ too
    fmts    = ["24bppRGB", "24BPPRGB", "32bppARGB", "8bppIndexed", None, ""]
    sizes   = [1024, 2048, 2048, 999999, 0, None, 4503599627370497]
    floats  = [0.5, 0.5000000001, -0.0001, 0.0001, 0.0, 123.456789, None, 1.0]
    times   = [20260101120000, 20260101120000, 19991231235959, None]
    names   = ["a.jpg", "A.JPG", "b.png", "B.PNG", "c.tif"]

    for i in range(n):
        rows.append((
            i + 1,
            names[i % len(names)] + str(i),           # imgfile is UNIQUE via fullPath
            "C:\\pics\\" + str(i % 5),
            rnd.choice(sizes),
            rnd.choice(times), rnd.choice(times),
            rnd.choice(widths), rnd.choice(heights),
            rnd.choice(frames), rnd.choice(dpis), rnd.choice(fmts),
            rnd.choice(floats), rnd.choice(floats), rnd.choice(floats), rnd.choice(floats),
            rnd.choice(floats), rnd.choice(floats), rnd.choice(floats), rnd.choice(floats),
            "x" * 8,                                   # a non-empty dHash for the guard
            0 if rnd.random() > 0.1 else rnd.choice([1, 2]),
        ))
    db.executemany("""INSERT INTO images (imgidu, imgfile, imgfolder, fsize, fmodified, fcreated,
        imgwidth, imgheight, imgframes, imgdpi, imgpixfmt, imgmedian, imgavg, imghpeak, imghlow,
        imghmode, imghrms, imghminu, imghrange, dHash, isDeleted)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
    db.commit()

def sel(col, prec):
    return col if col in NOT_FLOATS else "Round(%s,%d)" % (col, prec)

def oldQuery(cols, prec, notnull):
    on = " AND ".join("a.%s = b.%s" % (sel(c, prec).replace(c, "a." + c, 1) if False else sel(c, prec), c)
                      for c in cols)
    on = " AND ".join(("Round(a.%s,%d) = b.%s" % (c, prec, c)) if c not in NOT_FLOATS
                      else ("a.%s = b.%s" % (c, c)) for c in cols)
    selcols = ", ".join("%s AS %s" % (sel(c, prec), c) for c in cols)
    grp = ", ".join(sel(c, prec) for c in cols)
    return ("SELECT a.imgidu, b.groupID FROM images AS a JOIN "
            "(SELECT %s, ROWID AS groupID FROM images WHERE isDeleted=0 AND ifnull(%s,'')!='' "
            "GROUP BY %s HAVING count(*)>1) AS b ON (%s) "
            "WHERE a.isDeleted=0 AND ifnull(a.%s,'')!='' "
            "ORDER BY b.groupID, a.imgmegapix, a.fsize" % (selcols, notnull, grp, on, notnull))

def newQuery(cols, prec, notnull):
    keys = ", ".join("%s AS k%d" % (sel(c, prec), i) for i, c in enumerate(cols))
    order = ", ".join("k%d" % i for i in range(len(cols)))
    return ("SELECT imgidu, %s FROM images WHERE isDeleted=0 AND ifnull(%s,'')!='' "
            "ORDER BY %s, imgmegapix, fsize" % (keys, notnull, order))

# ---- the specification the C++ ordered scan has to implement -------------------------
#
# SQLite compares two values by storage class first (NULL < numeric < TEXT < BLOB), then
# within the class. Python's sqlite3 hands back None/int/float/str/bytes, which is the
# storage class, so this is a faithful stand-in.
def keyEquals(a, b, cols):
    for va, vb, col in zip(a, b, cols):
        if va is None or vb is None:
            if va is not vb:      # NULLs group together, NULL never equals a value
                return False
            continue
        na, nb = isinstance(va, (int, float)), isinstance(vb, (int, float))
        if na != nb:
            return False
        if na:
            # INTEGER and REAL compare numerically, and -0.0 == 0.0
            if isinstance(va, int) and isinstance(vb, int):
                if va != vb: return False
            elif float(va) != float(vb):
                return False
            continue
        if isinstance(va, bytes) != isinstance(vb, bytes):
            return False
        if col in NOCASE:
            # SQLite's NOCASE folds ASCII A-Z only, which is what _stricmp does for ASCII
            if va.lower() != vb.lower():
                # ... but only for ASCII: fold non-ASCII nowhere
                if "".join(c.lower() if c.isascii() else c for c in va) != \
                   "".join(c.lower() if c.isascii() else c for c in vb):
                    return False
        elif va != vb:
            return False
    return True

def partitions(pairs):
    """(groupKey, imgidu) list -> frozenset of frozensets, i.e. the grouping alone."""
    byGroup = {}
    for gid, iid in pairs:
        byGroup.setdefault(gid, set()).add(iid)
    return frozenset(frozenset(v) for v in byGroup.values() if len(v) > 1)

def run():
    db = sqlite3.connect(":memory:")
    build(db)
    bad = 0
    print("  sqlite3 %s" % sqlite3.sqlite_version)
    for prec in (0, 1, 2, 5):
        for cs in COLSETS:
            cols = cs.split(",")
            notnull = "dHash"
            old = db.execute(oldQuery(cols, prec, notnull)).fetchall()
            oldPart = partitions([(g, i) for i, g in old])

            rows = db.execute(newQuery(cols, prec, notnull)).fetchall()
            newPart, cur, gid = [], None, 0
            for r in rows:
                key = r[1:]
                # The self-join drops these: its ON clause is a chain of "=", and
                # NULL = NULL is NULL, not true. GROUP BY would have put the NULLs in
                # one bucket, but no row of "a" ever joins to it. The ordered scan has
                # to drop them too, or it invents groups the old query never produced.
                if any(v is None for v in key):
                    cur = None
                    continue
                if cur is None or not keyEquals(cur, key, cols):
                    gid += 1
                    cur = key
                newPart.append((gid, r[0]))
            newPart = partitions(newPart)

            if oldPart != newPart:
                bad += 1
                miss = oldPart - newPart
                extra = newPart - oldPart
                print("  MISMATCH prec=%d cols=%s" % (prec, cs))
                print("    only in self-join : %s" % (sorted(sorted(g) for g in miss)[:3],))
                print("    only in scan      : %s" % (sorted(sorted(g) for g in extra)[:3],))
            else:
                sys.stdout.write(".")
                sys.stdout.flush()
    print()
    if bad:
        print("  %d of %d groupings differ" % (bad, 4 * len(COLSETS)))
        return 1
    print("  all %d groupings identical (%d column sets x 4 precisions)" %
          (4 * len(COLSETS), len(COLSETS)))
    return 0

if __name__ == "__main__":
    sys.exit(run())
