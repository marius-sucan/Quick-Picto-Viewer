# 256-colour quantizer test, 2026-11-03

FreeImage's NeuQuant and Wu quantizers, on three synthetic 2000×1500 (3 MP) images.
GDI+ with dithering is still to be added (see the end).

## Files

| original (24-bit PNG) | NeuQuant (8-bit PNG) | Wu (8-bit PNG) | crops |
|---|---|---|---|
| `rainbow.png`: hue across, white → full colour → black down | `rainbow-neuquant.png` | `rainbow-wu.png` | `crops/rainbow-crops.png` |
| `gradients.png`: six two-colour ramps, 250 px each | `gradients-neuquant.png` | `gradients-wu.png` | `crops/gradients-crops.png` |
| `colorwheel.png`: hue by angle, saturation by radius, on grey | `colorwheel-neuquant.png` | `colorwheel-wu.png` | `crops/colorwheel-crops.png` |

The crops show original | NeuQuant | Wu at 2× zoom, where banding shows most.

## How the results were made

The repo's FreeImage.dll (3.20.0 fork, x64), run under Wine through `lib/freeimage-wrapper.ahk`, as `FIMquantizeImage()` uses it:
`FreeImage_ConvertTo(…, "24Bits")`, then `FreeImage_ColorQuantize()` with FIQ_NNQUANT (sampling 1) or FIQ_WUQUANT, saved as PNG with PNG_Z_BEST_COMPRESSION.
Time per image: Wu about 20 ms, NeuQuant 4.0–4.4 s.

## Results

`python measure.py` prints this table (`--crops` also redraws the crops).
ΔE00 is the CIEDE2000 colour difference: below 1 is invisible, 2–3 is visible at a glance.

| image | method | colours | mean ΔE00 | 95% ΔE00 | max ΔE00 | blurred mean | blurred 95% | false edges % | worst step |
|---|---|---|---|---|---|---|---|---|---|
| rainbow | NeuQuant | 243 | 4.54 | 11.12 | 22.88 | 4.36 | 10.72 | 3.88 | 9.84 |
| rainbow | Wu | 256 | **3.65** | **8.15** | **20.97** | **3.47** | **7.74** | **3.80** | **7.87** |
| gradients | NeuQuant | 247 | 1.16 | 3.73 | 6.67 | 1.12 | 3.63 | 0.35 | 2.96 |
| gradients | Wu | 256 | **0.46** | **1.06** | **1.58** | **0.43** | **0.99** | **0.00** | **2.28** |
| colorwheel | NeuQuant | 254 | 1.90 | 6.70 | **33.16** | 1.82 | 6.34 | 1.28 | 8.76 |
| colorwheel | Wu | 256 | **1.16** | **4.53** | 34.77 | **1.08** | **4.22** | **1.18** | **6.07** |

Colours along the middle row of each gradient band (the original has 256 / 476 / 371 / 380 / 406 / 411):

| method | grey | navy → sky | red → blue | orange → teal | beige → brown | green → yellow |
|---|---|---|---|---|---|---|
| NeuQuant | 37 | 70 | 46 | **13** | 53 | 28 |
| Wu | 32 | 51 | 46 | 40 | 39 | 48 |

- **colours**: distinct colours in the result. NeuQuant's palettes hold duplicate entries (244–256 distinct of 256).
- **blurred**: both images blurred first (Gaussian σ 1.5 px, linear light), roughly what is seen at normal viewing distance. This is the fair measure for dithered images, whose per-pixel error is high by design.
- **false edges %**: share of neighbouring pixel pairs (after the blur) whose colour step grew by 1 ΔE00 or more over the original's step. These are the band edges.
- **worst step**: the largest such growth.
- The colour wheel's max ΔE00 comes from the anti-aliased rim pixels; both methods are equally bad there.

## Verdict

**Wu is closer to the original and smoother on all three images.** Its mean error is 20–60% lower than NeuQuant's (95th percentile 27–72% lower), its band steps are smaller and more even, and it is about 200× faster.
NeuQuant spends the palette unevenly (13 colours on the orange → teal ramp, 70 on the navy one) and wastes entries on duplicates. Its band edges are jagged (see the crops).

Neither quantizer dithers, so both give visible bands on smooth gradients. Only error diffusion hides them.

Only synthetic images were tested; photographs were not.

## Adding GDI+

In QPV's Save panel choose PNG, 8 bits, tick «Dithering», and save each original into this folder as `<name>-gdiplus.png`.
Then run `python measure.py --crops` (needs numpy and Pillow).
Every `<name>-<method>.png` file gets a row in the table and a tile in the crops.
For GDI+ judge by the blurred columns, the false edges and the crops, not by the per-pixel columns.
