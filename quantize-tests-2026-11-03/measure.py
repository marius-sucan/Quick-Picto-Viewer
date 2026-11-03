#!/usr/bin/env python3
# Compares every <name>-<method>.png in this folder with <name>.png. Needs numpy and Pillow.
# usage: python measure.py [folder] [--crops]
import sys, os, re, glob
import numpy as np
from PIL import Image, ImageDraw

NAMES = ["rainbow", "gradients", "colorwheel"]
BLUR_SIGMA = 1.5
# crop boxes (x, y, w, h) where banding shows most
CROPS = {"rainbow": (500, 40, 400, 200), "gradients": (700, 1000, 400, 200), "colorwheel": (900, 650, 400, 200)}

def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.float64) / 255

def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def lin_to_lab(lin):
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216/24389, np.cbrt(xyz), (24389/27 * xyz + 16) / 116)
    return np.stack([116*f[..., 1] - 16, 500*(f[..., 0] - f[..., 1]), 200*(f[..., 1] - f[..., 2])], -1)

def de2000(a, b):
    L1, a1, b1 = a[..., 0], a[..., 1], a[..., 2]
    L2, a2, b2 = b[..., 0], b[..., 1], b[..., 2]
    C1, C2 = np.hypot(a1, b1), np.hypot(a2, b2)
    Cm7 = ((C1 + C2) / 2) ** 7
    G = 0.5 * (1 - np.sqrt(Cm7 / (Cm7 + 25.0**7)))
    a1p, a2p = a1 * (1 + G), a2 * (1 + G)
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360
    dLp, dCp = L2 - L1, C2p - C1p
    dh = h2p - h1p
    dh = np.where(dh > 180, dh - 360, np.where(dh < -180, dh + 360, dh))
    dh = np.where(C1p * C2p == 0, 0, dh)
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2))
    Lpm, Cpm = (L1 + L2) / 2, (C1p + C2p) / 2
    hs = h1p + h2p
    hpm = np.where(C1p * C2p == 0, hs,
          np.where(np.abs(h1p - h2p) <= 180, hs / 2, np.where(hs < 360, (hs + 360) / 2, (hs - 360) / 2)))
    T = (1 - 0.17*np.cos(np.radians(hpm - 30)) + 0.24*np.cos(np.radians(2*hpm))
         + 0.32*np.cos(np.radians(3*hpm + 6)) - 0.20*np.cos(np.radians(4*hpm - 63)))
    dTheta = 30 * np.exp(-((hpm - 275) / 25) ** 2)
    Cpm7 = Cpm ** 7
    Rc = 2 * np.sqrt(Cpm7 / (Cpm7 + 25.0**7))
    Sl = 1 + 0.015 * (Lpm - 50) ** 2 / np.sqrt(20 + (Lpm - 50) ** 2)
    Sc, Sh = 1 + 0.045 * Cpm, 1 + 0.015 * Cpm * T
    Rt = -np.sin(np.radians(2 * dTheta)) * Rc
    return np.sqrt((dLp/Sl)**2 + (dCp/Sc)**2 + (dHp/Sh)**2 + Rt * (dCp/Sc) * (dHp/Sh))

def blur(img, sigma):
    r = int(3 * sigma + 0.5)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    for ax in (0, 1):
        pad = [(0, 0)] * img.ndim
        pad[ax] = (r, r)
        p = np.pad(img, pad, mode="edge")
        n = img.shape[ax]
        img = sum(w * np.take(p, np.arange(i, i + n), axis=ax) for i, w in enumerate(k))
    return img

def steps(lab):
    # colour difference between each pixel and its right and lower neighbours
    return np.concatenate([de2000(lab[:, 1:], lab[:, :-1]).ravel(), de2000(lab[1:], lab[:-1]).ravel()])

def measure(orig, res):
    lab_o, lab_r = lin_to_lab(to_linear(orig)), lin_to_lab(to_linear(res))
    d = de2000(lab_o, lab_r)
    lab_ob = lin_to_lab(blur(to_linear(orig), BLUR_SIGMA))
    lab_rb = lin_to_lab(blur(to_linear(res), BLUR_SIGMA))
    db = de2000(lab_ob, lab_rb)
    # false edges: neighbour steps that grew by at least 1 dE00 over the original's, seen through the blur
    grow = steps(lab_rb) - steps(lab_ob)
    return {"mean": d.mean(), "p95": np.percentile(d, 95), "max": d.max(),
            "bmean": db.mean(), "bp95": np.percentile(db, 95),
            "edges": 100 * np.mean(grow >= 1.0), "maxstep": grow.max(),
            "colours": len(np.unique((res * 255 + 0.5).astype(np.uint8).reshape(-1, 3), axis=0))}

def band_rows(img, n=6):
    # distinct colours along the middle row of each gradient band
    h = img.shape[0] // n
    return [len(np.unique((img[i*h + h//2] * 255 + 0.5).astype(np.uint8), axis=0)) for i in range(n)]

def crop_sheet(folder, name, methods, scale=2):
    x, y, w, h = CROPS[name]
    tiles = [("original", os.path.join(folder, name + ".png"))] + [(m, os.path.join(folder, f"{name}-{m}.png")) for m in methods]
    sheet = Image.new("RGB", (len(tiles) * (w*scale + 10) - 10, h*scale + 24), "white")
    dr = ImageDraw.Draw(sheet)
    for i, (label, p) in enumerate(tiles):
        t = Image.open(p).convert("RGB").crop((x, y, x + w, y + h)).resize((w*scale, h*scale), Image.NEAREST)
        sheet.paste(t, (i * (w*scale + 10), 24))
        dr.text((i * (w*scale + 10) + 4, 5), f"{label}  [{x},{y} {w}x{h}, {scale}x zoom]", fill="black")
    os.makedirs(os.path.join(folder, "crops"), exist_ok=True)
    sheet.save(os.path.join(folder, "crops", name + "-crops.png"), optimize=True)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    folder = args[0] if args else os.path.dirname(os.path.abspath(__file__))
    print("| image | method | colours | mean dE00 | 95% dE00 | max dE00 | blurred mean | blurred 95% | false edges % | worst step |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for name in NAMES:
        orig = load(os.path.join(folder, name + ".png"))
        methods = sorted(re.match(rf"{name}-(.+)\.png$", os.path.basename(p)).group(1)
                         for p in glob.glob(os.path.join(folder, name + "-*.png")))
        for m in methods:
            res = load(os.path.join(folder, f"{name}-{m}.png"))
            r = measure(orig, res)
            print(f"| {name} | {m} | {r['colours']} | {r['mean']:.2f} | {r['p95']:.2f} | {r['max']:.2f} | "
                  f"{r['bmean']:.2f} | {r['bp95']:.2f} | {r['edges']:.2f} | {r['maxstep']:.2f} |", flush=True)
            if name == "gradients":
                print(f"|  |  | per band: {' / '.join(map(str, band_rows(res)))} (original {' / '.join(map(str, band_rows(orig)))}) | | | | | | | |")
        if "--crops" in sys.argv:
            crop_sheet(folder, name, methods)

if __name__ == "__main__":
    main()
