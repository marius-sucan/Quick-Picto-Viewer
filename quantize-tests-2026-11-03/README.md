# 256-colour quantizer test, 2026-11-03

GDI+ with dithering, FreeImage's NeuQuant and FreeImage's Wu, on three synthetic 2000×1500 (3 MP) images.

## Files

| original (24-bit PNG) | GDI+ (8-bit PNG) | NeuQuant (8-bit PNG) | Wu (8-bit PNG) |
|---|---|---|---|
| `rainbow.png`: hue across, white → full colour → black down | `rainbow-gdip.png` | `rainbow-neuquant.png` | `rainbow-wu.png` |
| `gradients.png`: six two-colour ramps, 250 px each | `gradients-gdip.png` | `gradients-neuquant.png` | `gradients-wu.png` |
| `colorwheel.png`: hue by angle, saturation by radius, on grey | `colorwheel-gdip.png` | `colorwheel-neuquant.png` | `colorwheel-wu.png` |

`crops/` shows original | GDI+ | NeuQuant | Wu at 2× zoom, where banding shows most; `crops/gradients-grey-crops.png` is the grey ramp.

## How the results were made

- **GDI+**: made on Windows with GDI+ dithering (7ebddb9). QPV's 8-bit save with «Dithering» runs `QPV_GdipPalettizeBitmap()`: `GdipInitializePalette` (PaletteTypeOptimal, 256 colours), then `GdipBitmapConvertFormat` with DitherTypeErrorDiffusion.
- **NeuQuant, Wu**: the repo's FreeImage.dll (3.20.0 fork, x64), run under Wine through `lib/freeimage-wrapper.ahk`, as `FIMquantizeImage()` uses it: `FreeImage_ConvertTo(…, "24Bits")`, then `FreeImage_ColorQuantize()` with FIQ_NNQUANT (sampling 1) or FIQ_WUQUANT, saved as PNG with PNG_Z_BEST_COMPRESSION. Time per image: Wu about 20 ms, NeuQuant 4.0–4.4 s. Neither dithers.

## Results

`python measure.py` prints these numbers (`--crops` also redraws the crops); it needs numpy and Pillow.
ΔE00 is the CIEDE2000 colour difference: below 1 is invisible, 2–3 is visible at a glance. Lower is better everywhere; the best of each column is in bold.

| image | method | colours | mean ΔE00 | 95% ΔE00 | max ΔE00 | blurred mean | blurred 95% | false edges % | worst step |
|---|---|---|---|---|---|---|---|---|---|
| rainbow | GDI+ | 240 | 5.11 | 12.25 | 32.08 | **1.27** | **3.42** | **0.03** | **2.55** |
| rainbow | NeuQuant | 243 | 4.54 | 11.12 | 22.88 | 4.36 | 10.72 | 3.88 | 9.84 |
| rainbow | Wu | 256 | **3.65** | **8.15** | **20.97** | 3.47 | 7.74 | 3.80 | 7.87 |
| gradients | GDI+ | 240 | 3.79 | 8.30 | 36.03 | **0.40** | 1.20 | 0.83 | 4.33 |
| gradients | NeuQuant | 247 | 1.16 | 3.73 | 6.67 | 1.12 | 3.63 | 0.35 | 2.96 |
| gradients | Wu | 256 | **0.46** | **1.06** | **1.58** | 0.43 | **0.99** | **0.00** | **2.28** |
| colorwheel | GDI+ | 254 | 3.81 | 16.64 | 37.42 | **0.89** | **2.61** | **0.70** | **4.18** |
| colorwheel | NeuQuant | 254 | 1.90 | 6.70 | **33.16** | 1.82 | 6.34 | 1.28 | 8.76 |
| colorwheel | Wu | 256 | **1.16** | **4.53** | 34.77 | 1.08 | 4.22 | 1.18 | 6.07 |

Gradient bands, blurred mean ΔE00 inside each band (10 px away from the band borders):

| method | grey | navy → sky | red → blue | orange → teal | beige → brown | green → yellow |
|---|---|---|---|---|---|---|
| GDI+ | 0.87 | **0.22** | 0.47 | **0.37** | **0.28** | **0.17** |
| NeuQuant | 1.25 | 0.70 | 1.17 | 1.59 | 0.43 | 1.60 |
| Wu | **0.55** | 0.38 | **0.41** | 0.48 | 0.44 | 0.35 |

Colours along the middle row of each band (the original has 256 / 476 / 371 / 380 / 406 / 411). For the undithered methods this is the number of bands; GDI+ mixes its colours instead.

| method | grey | navy → sky | red → blue | orange → teal | beige → brown | green → yellow |
|---|---|---|---|---|---|---|
| GDI+ | 50 | 42 | 43 | 43 | 41 | 37 |
| NeuQuant | 37 | 70 | 46 | 13 | 53 | 28 |
| Wu | 32 | 51 | 46 | 40 | 39 | 48 |

- **colours**: distinct colours in the result. NeuQuant's palettes hold duplicate entries (244–256 distinct of 256); GDI+ leaves 16 of its 256 entries unused on the rainbow and the gradients.
- **blurred**: both images blurred first (Gaussian σ 1.5 px, linear light), roughly what is seen at normal viewing distance. This is the fair measure for GDI+, whose per-pixel error is high by design: dithering trades exact pixels for the right average.
- **false edges %**: share of neighbouring pixel pairs (after the blur) whose colour step grew by 1 ΔE00 or more over the original's step. For Wu and NeuQuant these are the band edges. Finer bands stay below that after the blur and are not counted: Wu's 0.00% on the gradients does not mean no bands, the per-band colour counts and the crops show them. For GDI+ they are dither grain that the blur does not smooth out.
- **worst step**: the largest such growth.
- The colour wheel's max ΔE00 comes from the anti-aliased rim pixels; every method is bad there.

## Verdict

**GDI+ with dithering looks closest to the original and is the only one without bands.**
On the rainbow its blurred error is 63% lower than Wu's (95th percentile 56% lower), on the colour wheel 18% lower (38%), and its false edges almost vanish (0.03% against 3.80% on the rainbow).
The price is grain: seen at 1:1 or zoomed in, every pixel is off (its per-pixel error is the highest of the three), and pale areas show light specks.

**Its weak spot is the grey ramp.** The optimal palette has few neutral greys, so GDI+ dithers grey with tinted colours: 86% of the ramp's pixels are not neutral (R, G, B differ by more than 6 levels, at most by 123). That leaves yellow-green specks the blur does not hide, and the ramp's blurred error is 0.87 against Wu's 0.55. On the five colour ramps GDI+ beats Wu on four and is close on the fifth (red → blue, 0.47 against 0.41).

**Without dithering, Wu is better than NeuQuant on every measure** and about 200× faster. Its mean error is 20–60% lower, its bands are finer and evenly spaced, and it keeps greys neutral. NeuQuant spends the palette unevenly (13 colours on the orange → teal ramp, 70 on the navy one), wastes entries on duplicates, and its band edges are jagged.

In short: GDI+ dithering where smoothness at normal size matters most, Wu where exact flat colours and neutral greys matter more (and as the fallback when GDI+ fails); NeuQuant never wins here.

Only synthetic images were tested; photographs were not.

## Adding more methods

Save each original into this folder as `<name>-<method>.png`, then run `python measure.py --crops`.
Every such file gets a row in the tables and a tile in the crops.
