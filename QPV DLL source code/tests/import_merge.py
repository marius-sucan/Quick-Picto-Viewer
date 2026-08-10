#!/usr/bin/env python3
# The database import, as importSLDBintoSLDB() performs it since schema v3.
#
# The merge renumbers every imgidu - it deletes the images table and re-inserts both
# databases' rows with fresh sequential identities - so the fingerprints, which live in a
# side table keyed by imgidu, cannot simply be copied. They are re-keyed instead: the old
# side table is set aside under another name, the imported database is ATTACHed, a small
# map of new -> (old main, old other) is filled as the rows are written, and one
# INSERT ... SELECT with a COALESCE per column puts them back.
#
# The COALESCE per column is what the "b" case - a file present in BOTH databases - rests
# on. Such a file occupies ONE plan slot: the first pass records the slot it gave the main
# row, the second pass finds that slot again and pairs the imported row with it, and the
# merge then takes the imported value wherever it has one and the existing value otherwise,
# column by column. The fingerprints follow the same rule rather than picking a row
# wholesale, so a record with a 9x8 fingerprint and no 32x32 one cannot wipe a 32x32 that
# was already there.
#
# Until 2026-08-10 that branch could not work: the second pass gave such a file a second
# plan slot, and the merge then looked its main row up as mainArrayu[thatNewSlot] - a slot
# the first pass never filled. The merge wrote the imported record alone, UNIQUE (fullPath)
# rejected it because the main record had already gone in under its own slot, and every
# shared file was counted as an error. This test is what says that is over.
#
# Everything here is executed by SQLite, not simulated: this is the specification the AHK
# implements, run against the real engine.
#
# written by Marius Șucan with Claude Opus 5

import sqlite3, os, sys, tempfile

V3_SCHEMA = """
CREATE TABLE images (imgidu NUMERIC PRIMARY KEY NOT NULL, imgfile TEXT COLLATE NOCASE NOT NULL,
 imgfolder TEXT COLLATE NOCASE NOT NULL, fullPath TEXT AS (imgfolder||'\\'||imgfile), fsize INT,
 fmodified INT, fcreated INT, imgwidth INT, imgheight INT, imgframes INT, imgdpi INT,
 imgpixfmt TEXT COLLATE NOCASE, imgmedian FLOAT, imgavg FLOAT, imghpeak FLOAT, imghlow FLOAT,
 imghmode FLOAT, imghrms FLOAT, imghminu FLOAT, imghrange FLOAT,
 dHash TEXT, pHash TEXT, lHash TEXT, isDeleted INT DEFAULT 0, UNIQUE (fullPath));
CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY NOT NULL, small BLOB, big BLOB,
 smallH BLOB, bigH BLOB);
CREATE TABLE settings (paramz TEXT COLLATE NOCASE NOT NULL ON CONFLICT REPLACE,
 valuez TEXT COLLATE NOCASE, PRIMARY KEY(paramz ASC));
"""

failures = []

def check(cond, what):
    print("    %-62s %s" % (what, "ok" if cond else "FAILED"))
    if not cond:
        failures.append(what)

def fp(tag, n):
    return bytes(((tag * 31 + i) & 0xFF) for i in range(n))

def build(path, rows):
    """rows: (imgidu, folder, file, dHash, small, big, smallH, bigH)"""
    if os.path.exists(path):
        os.remove(path)
    db = sqlite3.connect(path)
    db.executescript(V3_SCHEMA)
    db.executemany("INSERT INTO images (imgidu, imgfolder, imgfile, dHash) VALUES (?,?,?,?)",
                   [(r[0], r[1], r[2], r[3]) for r in rows])
    db.executemany("INSERT INTO imagesPixels (imgidu, small, big, smallH, bigH) VALUES (?,?,?,?,?)",
                   [(r[0], r[4], r[5], r[6], r[7]) for r in rows if any(r[4:])])
    db.execute("INSERT INTO settings VALUES ('dbVersion','3')")
    db.commit()
    db.close()

def merge(mainPath, otherPath):
    """Exactly the statements importSLDBintoSLDB() issues, in the same order."""
    db = sqlite3.connect(mainPath)
    db.isolation_level = None          # AHK drives BEGIN/COMMIT itself

    SQLa = ("SELECT imgfile, imgfolder, dHash, imgidu FROM images")
    mainRows  = db.execute(SQLa).fetchall()
    other = sqlite3.connect(otherPath)
    otherRows = other.execute(SQLa).fetchall()
    other.close()

    # totalArrayu: "m" main only, "o" imported only, "b" in both - keyed on folder\file.
    # uniqueArrayu holds the PLAN SLOT of the main row, so a file in both keeps one slot.
    slotOf = {}
    plan = []
    for r in mainRows:
        slotOf[(r[1] + "\\" + r[0]).lower()] = len(plan)
        plan.append(["m", r, None])
    for r in otherRows:
        key = (r[1] + "\\" + r[0]).lower()
        if key in slotOf:
            plan[slotOf[key]][0] = "b"
            plan[slotOf[key]][2] = r
        else:
            plan.append(["o", None, r])

    db.execute("ATTACH DATABASE ? AS srcdb", (otherPath,))
    db.execute("BEGIN TRANSACTION")
    db.execute("DROP TABLE IF EXISTS imagesPixelsOld")
    db.execute("ALTER TABLE imagesPixels RENAME TO imagesPixelsOld")
    db.execute("CREATE TABLE imagesPixels (imgidu INTEGER PRIMARY KEY NOT NULL, small BLOB,"
               " big BLOB, smallH BLOB, bigH BLOB)")
    db.execute("CREATE TEMP TABLE pixMap (newID INTEGER PRIMARY KEY, mainID INTEGER, otherID INTEGER)")
    db.execute("DELETE FROM images")

    newID = 0
    errors = 0
    for kind, m, o in plan:
        newID += 1
        if kind == "b":
            # the imported value wins per column, the existing one fills the gaps
            vals = [o[i] if o[i] else m[i] for i in range(3)]
            mainID, otherID = m[3], o[3]
        elif kind == "m":
            vals, mainID, otherID = list(m[:3]), m[3], None
        else:
            vals, mainID, otherID = list(o[:3]), None, o[3]

        try:
            db.execute("INSERT INTO images (imgidu, imgfile, imgfolder, dHash) VALUES (?,?,?,?)",
                       [newID] + vals)
        except sqlite3.IntegrityError:
            errors += 1
            newID -= 1                 # sqlDBrowID only advances on a successful insert
            continue

        db.execute("INSERT INTO pixMap (newID, mainID, otherID) VALUES (?,?,?)", (newID, mainID, otherID))

    db.execute("INSERT INTO imagesPixels (imgidu, small, big, smallH, bigH)"
               " SELECT m.newID, COALESCE(o.small, x.small), COALESCE(o.big, x.big),"
               " COALESCE(o.smallH, x.smallH), COALESCE(o.bigH, x.bigH)"
               " FROM pixMap AS m LEFT JOIN srcdb.imagesPixels AS o ON o.imgidu=m.otherID"
               " LEFT JOIN imagesPixelsOld AS x ON x.imgidu=m.mainID"
               " WHERE o.imgidu IS NOT NULL OR x.imgidu IS NOT NULL")
    db.execute("DROP TABLE pixMap")
    db.execute("DROP TABLE imagesPixelsOld")
    db.execute("COMMIT TRANSACTION")
    db.execute("DETACH DATABASE srcdb")
    return db, errors

def main():
    tmp = tempfile.mkdtemp(prefix="qpv-import-")
    mainPath = os.path.join(tmp, "main.sldb")
    otherPath = os.path.join(tmp, "other.sldb")

    # main: a.jpg (full set), b.jpg (no fingerprints at all), shared.jpg (full set)
    build(mainPath, [
        (10, "C:\\m", "a.jpg",      "aa", fp(1, 72), fp(2, 1024), fp(3, 72), fp(4, 1024)),
        (11, "C:\\m", "b.jpg",      "bb", None, None, None, None),
        (12, "C:\\m", "shared.jpg", "cc", fp(5, 72), fp(6, 1024), fp(7, 72), fp(8, 1024)),
    ])
    # other: shared.jpg with only the 9x8 pair, and c.jpg with everything
    build(otherPath, [
        (77, "C:\\m", "shared.jpg", "dd", fp(9, 72), None, None, None),
        (78, "C:\\o", "c.jpg",      "ee", fp(11, 72), fp(12, 1024), None, None),
    ])

    print("  import merge, schema v3")
    db, errors = merge(mainPath, otherPath)

    rows = db.execute("SELECT imgidu, imgfolder||'\\'||imgfile FROM images ORDER BY imgidu").fetchall()
    byName = dict((n.lower(), i) for i, n in rows)
    check(len(rows) == 4, "the merged database holds one row per distinct file")
    check(sorted(i for i, _ in rows) == [1, 2, 3, 4], "and the identities were renumbered from 1")

    def pixels(name):
        i = byName[name.lower()]
        r = db.execute("SELECT small, big, smallH, bigH FROM imagesPixels WHERE imgidu=?", (i,)).fetchone()
        return r if r else (None, None, None, None)

    a = pixels("C:\\m\\a.jpg")
    check(a == (fp(1, 72), fp(2, 1024), fp(3, 72), fp(4, 1024)),
          "a file only in the main database keeps all four fingerprints")

    b = db.execute("SELECT count(*) FROM imagesPixels WHERE imgidu=?", (byName["c:\\m\\b.jpg"],)).fetchone()[0]
    check(b == 0, "a file that had none gets no imagesPixels row")

    c = pixels("C:\\o\\c.jpg")
    check(c == (fp(11, 72), fp(12, 1024), None, None),
          "a file only in the imported database brings its own across")

    sh = pixels("C:\\m\\shared.jpg")
    check(sh[0] == fp(9, 72), "for a file in both, the imported fingerprint wins")
    check(sh[1] == fp(6, 1024), "... and the existing one fills the columns it does not have")
    check(sh[2] == fp(7, 72) and sh[3] == fp(8, 1024), "... including the flipped pair")
    check(db.execute("SELECT dHash FROM images WHERE imgidu=?",
                     (byName["c:\\m\\shared.jpg"],)).fetchone()[0] == "dd",
          "and its other columns merge the same way")
    check(errors == 0, "a file in both no longer collides with itself")

    check(db.execute("SELECT count(*) FROM sqlite_master WHERE name='imagesPixelsOld'").fetchone()[0] == 0,
          "the scratch table is gone afterwards")
    check(db.execute("SELECT count(*) FROM imagesPixels p LEFT JOIN images i ON i.imgidu=p.imgidu"
                     " WHERE i.imgidu IS NULL").fetchone()[0] == 0,
          "no fingerprint is left orphaned on a stale identity")

    db.close()
    for f in (mainPath, otherPath):
        os.remove(f)
    os.rmdir(tmp)

    if failures:
        print("\n  IMPORT MERGE TEST FAILED")
        return 1
    print("  import merge test passed")
    return 0

if __name__ == "__main__":
    sys.exit(main())
