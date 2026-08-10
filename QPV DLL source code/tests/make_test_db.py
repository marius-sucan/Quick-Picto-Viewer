#!/usr/bin/env python3
# Builds a .sldb with the real QPV images schema for query_engine.cpp to run against.
#
# The values are chosen to break a naive ordered scan rather than to look realistic:
# mixed-case imgpixfmt and imgfile (both COLLATE NOCASE), NULLs in grouping columns,
# values that round to the same number at one precision and not another, images with no
# fingerprint, images with no flipped hash, and isDeleted rows that must never surface.
#
# written by Marius Șucan with Claude Opus 5

import sqlite3, sys, os, random

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
CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY NOT NULL, small BLOB, big BLOB,
 smallH BLOB, bigH BLOB);
CREATE INDEX imgsIndex ON images(imgidu, imgfolder, imgfile);
CREATE INDEX imgsAliveIndex ON images(isDeleted);
CREATE TABLE settings (paramz TEXT COLLATE NOCASE NOT NULL ON CONFLICT REPLACE,
 valuez TEXT COLLATE NOCASE, PRIMARY KEY(paramz ASC));
"""

def fingerprint(rnd, base=None, jitter=6, n=1024):
    """n raw bytes - schema v3 stores the fingerprints as BLOBs in imagesPixels, one
    byte per pixel, instead of the Chr(gray + 161) TEXT the images table used to hold."""
    if base is None:
        return bytes(rnd.randrange(256) for _ in range(n))
    return bytes(max(0, min(255, b + rnd.randrange(-jitter, jitter + 1))) for b in base)

def build(path, n=1200, seed=20260809):
    if os.path.exists(path):
        os.remove(path)
    rnd = random.Random(seed)
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)

    widths  = [640, 800, 1920, 1920, 1024, 3, 1]
    heights = [480, 600, 1080, 1081, 768, 4, 1]
    frames  = [1, 1, 1, 1, 2, 12, None]
    dpis    = [72, 96, 96, 300, None]
    fmts    = ["24bppRGB", "24BPPRGB", "24bpprgb", "32bppARGB", "8bppIndexed", None, ""]
    sizes   = [1024, 2048, 2048, 65536, 999999, 0, None]
    floats  = [0.5, 0.5000000001, 0.504, -0.0001, 0.0001, 0.0, 123.456789, None, 1.0]
    times   = [20260101120000, 20260101120000, 19991231235959, None]
    names   = ["a.jpg", "A.JPG", "b.png", "B.PNG", "c.tif", "D.Tif"]

    # a handful of "originals"; most images are a perturbation of one of them, so real
    # near-duplicate pairs exist at every Hamming distance
    bases = [fingerprint(rnd) for _ in range(24)]
    rows = []
    pixRows = []
    for i in range(n):
        b = bases[i % len(bases)]
        pix = small = None
        if rnd.random() > 0.12:                       # 12% have no fingerprint at all
            pix = fingerprint(rnd, b, jitter=rnd.choice([0, 1, 3, 9, 40]))
            # the 9x8 = 72 fingerprint dHash and lHash are computed from
            small = fingerprint(rnd, n=72)
        h = rnd.getrandbits(64)
        if rnd.random() > 0.5:                        # cluster the hashes too
            h = (i % 40) * 0x0101010101010101 ^ (1 << rnd.randrange(64))
        rows.append((
            i + 1,
            names[i % len(names)] + str(i),
            "C:\\pics\\" + str(i % 7),
            rnd.choice(sizes),
            rnd.choice(times), rnd.choice(times),
            rnd.choice(widths), rnd.choice(heights),
            rnd.choice(frames), rnd.choice(dpis), rnd.choice(fmts),
            rnd.choice(floats), rnd.choice(floats), rnd.choice(floats), rnd.choice(floats),
            rnd.choice(floats), rnd.choice(floats), rnd.choice(floats), rnd.choice(floats),
            "%x" % h,                                                     # dHash, lowercase hex
            ("%x" % rnd.getrandbits(64)) if rnd.random() > 0.3 else None,  # HdHash often absent
            "%x" % rnd.getrandbits(64),
            0 if rnd.random() > 0.08 else rnd.choice([1, 2]),
        ))
        # the fingerprints live in their own table now; a row with none simply has no
        # row there, which is what SQLpixelsMissingClause() tests for
        if pix is not None:
            pixRows.append((i + 1, small, pix, None, None))

    db.executemany("""INSERT INTO images (imgidu, imgfile, imgfolder, fsize, fmodified, fcreated,
        imgwidth, imgheight, imgframes, imgdpi, imgpixfmt, imgmedian, imgavg, imghpeak, imghlow,
        imghmode, imghrms, imghminu, imghrange, dHash, HdHash, pHash, isDeleted)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
    db.executemany("INSERT INTO imagesPixels (imgidu, small, big, smallH, bigH)"
                   " VALUES (?,?,?,?,?)", pixRows)
    db.execute("INSERT INTO settings VALUES ('dbVersion','3')")
    db.commit()
    got = db.execute("SELECT count(*), sum(isDeleted=0),"
                     " (SELECT count(*) FROM imagesPixels WHERE big IS NOT NULL),"
                     " (SELECT count(*) FROM imagesPixels WHERE small IS NOT NULL)"
                     " FROM images").fetchone()
    db.close()
    print("  %s: %d rows, %d live, %d big + %d small fingerprints" % (path, got[0], got[1], got[2], got[3]))

if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "testdb.sldb")
