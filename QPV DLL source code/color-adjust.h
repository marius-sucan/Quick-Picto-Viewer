// color-adjust.h
//
// AdjustImageColorsPrecise(): the per-call plan, the 16-bit pixel kernel RGBA16color with its
// HSL helpers, and the tables and helpers only they use.
//
// #included by qpv-main.cpp after selection-mask.h, whose clipMaskFilter() it uses, and ahead
// of PaintBrushLarge(), whose effects brush runs its pixels through RGBA16color.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_COLOR_ADJUST_H
#define QPV_COLOR_ADJUST_H

#include <algorithm>
#include <cmath>

const float div2s3 = 2.0f/3.0f;      // used in ConvertRGBtoHSL()
const float div1s3 = 1.0f/3.0f;      // used in ConvertRGBtoHSL()

static int LUTgammaBright[65536];
static int LUTshadows[65536];
static int LUThighs[65536];

int inline getInt16grayscale(int r, int g, int b) {
    return clamp((int)(int_to_grayRi[clamp(r, 0, 65535)] + int_to_grayGi[clamp(g, 0, 65535)] + int_to_grayBi[clamp(b, 0, 65535)]), 0, 65535);
}

int inline gammaMathsInt16(int i, double gamma) {
    return round(65535.0f * pow(int_to_float[clamp(i, 0, 65535)], gamma));
}

struct RGBColorI {
    int r, g, b;
};

struct HSLColor {
    double h, s, l;

    double inline ConvertHueToRGB(double v1, double v2, double vH) {
        if (vH < 0.0) vH += 1.0;
        if (vH > 1.0) vH -= 1.0;
        if (6.0 * vH < 1.0) return v1 + (v2 - v1) * 6.0 * vH;
        if (2.0 * vH < 1.0) return v2;
        if (3.0 * vH < 2.0) return v1 + (v2 - v1) * (div2s3 - vH) * 6.0;
        return v1;
    }

    RGBColorI ConvertHSLtoRGB() {
    // http://www.had2know.com/technology/hsl-rgb-color-converter.html

       double fH = h/360.0f;
       double var_1, var_2;
       RGBColorI newColor;
       if (s <= 0.0)
       {
          newColor.r = clamp((float)l*255.0f, 0.0f, 255.0f);
          newColor.g = clamp((float)l*255.0f, 0.0f, 255.0f);
          newColor.b = clamp((float)l*255.0f, 0.0f, 255.0f);
       } else
       {
          if (l < 0.5)
             var_2 = l * (1.0f + s);
          else
             var_2 = (l + s) - (s * l);

          var_1 = 2.0f * l - var_2;
          newColor.r = clamp((float)(255.0f * ConvertHueToRGB(var_1, var_2, fH + div1s3) ), 0.0f, 255.0f);
          newColor.g = clamp((float)(255.0f * ConvertHueToRGB(var_1, var_2, fH) ), 0.0f, 255.0f);
          newColor.b = clamp((float)(255.0f * ConvertHueToRGB(var_1, var_2, fH - div1s3) ), 0.0f, 255.0f);
       }
       return newColor;
    };

    RGBColorI ConvertHSLtoRGBint16() {
    // http://www.had2know.com/technology/hsl-rgb-color-converter.html

       const double fH = h/360.0f;
       double var_1, var_2;
       RGBColorI newColor;
       if (s <= 0)
       {
          newColor.r = clamp((float)l*65535.0f, 0.0f, 65535.0f);
          newColor.g = clamp((float)l*65535.0f, 0.0f, 65535.0f);
          newColor.b = clamp((float)l*65535.0f, 0.0f, 65535.0f);
       } else
       {
          if (l < 0.5)
             var_2 = l * (1.0f + s);
          else
             var_2 = (l + s) - (s * l);

          var_1 = 2.0f * l - var_2;
          newColor.r = clamp((float)(65535.0f * ConvertHueToRGB(var_1, var_2, fH + div1s3) ), 0.0f, 65535.0f);
          newColor.g = clamp((float)(65535.0f * ConvertHueToRGB(var_1, var_2, fH) ), 0.0f, 65535.0f);
          newColor.b = clamp((float)(65535.0f * ConvertHueToRGB(var_1, var_2, fH - div1s3) ), 0.0f, 65535.0f);
       }
       return newColor;
    };
  };


// ---------------------------------------------------------------------------
// RGBA16color - the 16-bit-internal pixel used by AdjustImageColorsPrecise().
//
// The 65536-entry LUTs stay: benchmarking says recomputing their closed forms
// per pixel is a LOSS (contraMathsInt16 hides a floor(), which is not a single
// instruction without SSE4.1, and the tables are cache-coherent in practice).
// What changed is WHO uses them:
//   UseLUT=true  -> the per-pixel path, reads the tables.
//   UseLUT=false -> the 256-entry table builders in AdjustPlan, which evaluate
//                   the closed form directly and so need no 65536-entry build.
// gammaMathsInt16(i,z)==LUTgammaBright[i], brightMathsInt16(i,f)==
// LUTbright[i] and contraMathsInt16(i,f,32768)==LUTcontra[i] by construction,
// so the two modes are bit-identical.
//
// Alpha is gone from the RGB ops: it never reads r/g/b and r/g/b never read it,
// so the caller resolves alpha with a 256-entry LUT instead.
//
// Everything per-pixel is QPV_FORCEINLINE: the pipeline is one ~2.5 KB body and
// the inliner otherwise gives up on it, spilling the pixel to memory and costing
// ~25 cycles/px.
// ---------------------------------------------------------------------------
struct RGBA16color {
    int b, g, r, a;

    QPV_FORCEINLINE HSLColor ConvertRGBtoHSL() const {
       const double rf = int_to_float[r];
       const double gf = int_to_float[g];
       const double bf = int_to_float[b];
       const double minu    = min(rf, min(gf, bf));
       const double maxu    = max(rf, max(gf, bf));
       const double del_Max = maxu - minu;
       const double L       = (maxu + minu) / 2.0f;
       double H = 0.0, S = 0.0;

        if (del_Max > 0.0)
        {
            if (L < 0.5)
                S = del_Max / (maxu + minu);
            else
                S = del_Max / (2.0 - maxu - minu);

            const double del_R = (((maxu - rf) / 6.0) + (del_Max / 2.0)) / del_Max;
            const double del_G = (((maxu - gf) / 6.0) + (del_Max / 2.0)) / del_Max;
            const double del_B = (((maxu - bf) / 6.0) + (del_Max / 2.0)) / del_Max;

            if (rf == maxu)
                H = del_B - del_G;
            else if (gf == maxu)
                H = div1s3 + del_R - del_B;
            else
                H = div2s3 + del_G - del_R;

            if (H < 0.0)
                H += 1.0;
            if (H > 1.0)
                H -= 1.0;
        }

        return {H * 360.0, S, L};
    }

    QPV_FORCEINLINE void channelOffsetRGB(int ro, int go, int bo, int noClamping) {
        r = (noClamping==1) ? r + ro : clamp(r + ro, 0, 65535);
        g = (noClamping==1) ? g + go : clamp(g + go, 0, 65535);
        b = (noClamping==1) ? b + bo : clamp(b + bo, 0, 65535);
    }

    QPV_FORCEINLINE void thresholdRGB(int ro, int go, int bo, int seeThrough) {
        if (seeThrough==2)
        {
           if (ro>=0) r = (r>ro) ? r : 0;
           if (go>=0) g = (g>go) ? g : 0;
           if (bo>=0) b = (b>bo) ? b : 0;
       } else if (seeThrough==3)
       {
          if (ro>=0) r = (r>ro) ? 65535 : r;
          if (go>=0) g = (g>go) ? 65535 : g;
          if (bo>=0) b = (b>bo) ? 65535 : b;
      } else
      {
         if (ro>=0) r = (r>ro) ? 65535 : 0;
         if (go>=0) g = (g>go) ? 65535 : 0;
         if (bo>=0) b = (b>bo) ? 65535 : 0;
      }
    }

    QPV_FORCEINLINE void invert() {
        r = 65535 - r;
        g = 65535 - g;
        b = 65535 - b;
    }

    QPV_FORCEINLINE void blackPoint(int level, int noise) {
        int rando = 0;
        if (noise == 1) {
            thread_local unsigned int seed = 123456789U;
            seed = seed * 1103515245U + 12345U;
            rando = (int)((seed / 65536U) % 2600U);
        }
        r = max(r, level + rando);
        g = max(g, level + rando);
        b = max(b, level + rando);
    }

    QPV_FORCEINLINE void whitePoint(int level, int noise) {
        int rando = 0;
        if (noise == 1) {
            thread_local unsigned int seed = 123456789U;
            seed = seed * 1103515245U + 12345U;
            rando = (int)((seed / 65536U) % 2600U);
        }
        r = min(r, level - rando);
        g = min(g, level - rando);
        b = min(b, level - rando);
    }

    template<bool UseLUT>
    QPV_FORCEINLINE void brightness(int level, int altMode, int noClamping, float fintensity, double zammaBright) {
        if (altMode==0)
        {
           if (level<0 && noClamping==0)
           {
              if (UseLUT)
              {
                 r = LUTgammaBright[r];
                 g = LUTgammaBright[g];
                 b = LUTgammaBright[b];
              } else
              {
                 r = gammaMathsInt16(r, zammaBright);
                 g = gammaMathsInt16(g, zammaBright);
                 b = gammaMathsInt16(b, zammaBright);
              }
           }
           r = (noClamping==1) ? r + level : clamp(r + level, 0, 65535);
           g = (noClamping==1) ? g + level : clamp(g + level, 0, 65535);
           b = (noClamping==1) ? b + level : clamp(b + level, 0, 65535);
       } else
       {
           if (noClamping==1)
           {
              r = r + (float)r*fintensity;
              g = g + (float)g*fintensity;
              b = b + (float)b*fintensity;
           } else if (UseLUT)
           {
              r = LUTbright[r];
              g = LUTbright[g];
              b = LUTbright[b];
           } else
           {
              r = brightMathsInt16(r, fintensity);
              g = brightMathsInt16(g, fintensity);
              b = brightMathsInt16(b, fintensity);
           }
       }
    }

    QPV_FORCEINLINE int getGrayscaleAdvanced() const {
       const float minu = min(r, min(g, b));
       float maxu = max(r, max(g, b));
       float nr = r;
       float ng = g;
       float nb = b;
       if (minu<0)
       {
          nr = r - minu;
          ng = g - minu;
          nb = b - minu;
       }

       if (maxu<65535)
          maxu = 65535.0f;

       nr = nr*0.299701f;
       ng = ng*0.587130f;
       nb = nb*0.114180f;
       int gray = nr + ng + nb;
       if (gray>maxu)
          gray = maxu;

       return gray;
    }

    // shadows/highlights force the per-pixel path (they read the pixel's
    // grayscale), so they always use the tables.
    QPV_FORCEINLINE void shadows(int level, int altMode, int linearGamma, int gray, int noClamping, float fi) {
       int nr, ng, nb;
       if (noClamping==1)
       {
           float maxu = max(r, max(g, b));
           if (maxu<65535)
              maxu = 65535.0f;

           nr = r + (float)r*fi;
           ng = g + (float)g*fi;
           nb = b + (float)b*fi;
           float gz = getGrayscaleAdvanced();
           if (altMode!=1)
              gz = gz*2.0f;

           float fintensity = 1.0f - (gz / maxu);
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
       } else
       {
           if (altMode==1)
              gray = clamp(65535 - gray, 0, 65535);
           else
              gray = clamp(65535 - (gray*2), 0, 65535);

           nr = LUTshadows[r];
           ng = LUTshadows[g];
           nb = LUTshadows[b];
           float fintensity = int_to_float[gray];
           if (linearGamma==1)
           {
              fintensity += 0.1;
              r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nr], gamma_to_linearInt16[r], fintensity)];
              g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[ng], gamma_to_linearInt16[g], fintensity)];
              b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nb], gamma_to_linearInt16[b], fintensity)];
           } else
           {
              r = weighTwoValues(nr, r, fintensity);
              g = weighTwoValues(ng, g, fintensity);
              b = weighTwoValues(nb, b, fintensity);
           }
       }
    }

    QPV_FORCEINLINE void highlights(int level, int altMode, int linearGamma, float factor, int gray, int noClamping, float fi) {
       int nr, ng, nb;
       if (noClamping==1)
       {
           float maxu = max(r, max(g, b));
           if (maxu<65535)
              maxu = 65535.0f;

           nr = r + (float)r*fi;
           ng = g + (float)g*fi;
           nb = b + (float)b*fi;
           float gz = getGrayscaleAdvanced();
           if (altMode==1)
              gz = gz*1.25f;
           else
              gz = gz/1.25f;

           float fintensity = gz / (maxu/1.5f);
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
       } else
       {
           if (altMode==1)
              gray = contraMathsInt16(gray*1.5f, factor, 32768);
           else
              gray = contraMathsInt16(gray, factor, 32768);

           nr = LUThighs[r];
           ng = LUThighs[g];
           nb = LUThighs[b];
           float fintensity = int_to_float[gray];
           if (linearGamma==1)
           {
              r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nr], gamma_to_linearInt16[r], fintensity)];
              g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[ng], gamma_to_linearInt16[g], fintensity)];
              b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nb], gamma_to_linearInt16[b], fintensity)];
           } else
           {
              r = weighTwoValues(nr, r, fintensity);
              g = weighTwoValues(ng, g, fintensity);
              b = weighTwoValues(nb, b, fintensity);
           }
       }
    }

    // The clamped branch only ever ran on the 256 values reachable straight out
    // of char_to_int[]+invert, so it is always folded into the head table and
    // needs no 65536-entry LUT. zamma == 1.0/(gamma/300.0).
    QPV_FORCEINLINE void gamma(int level, int bright, int altMode, int noClamping, double zamma) {
      if (noClamping==0)
      {
          r = gammaMathsInt16(r, zamma);
          g = gammaMathsInt16(g, zamma);
          b = gammaMathsInt16(b, zamma);
      } else
      {
          const float minu = min(r, min(g, b));
          float maxu = max(r, max(g, b));
          float nr = r;
          float ng = g;
          float nb = b;
          float offset = 0.0f;
          if (minu < 0.0f)
          {
              nr = r - minu;
              ng = g - minu;
              nb = b - minu;
              offset = minu;
          }

          float denominator = (maxu < 65535.0f ? 65535.0f : maxu) - offset;
          if (denominator <= 0.0f)
             denominator = 1.0f;

          nr = clamp(nr / denominator, 0.0f, 1.0f);
          ng = clamp(ng / denominator, 0.0f, 1.0f);
          nb = clamp(nb / denominator, 0.0f, 1.0f);
          const int thisLevel = (bright < 0 && altMode == 0 && level > 300) ? level + abs(bright) / 300 : level;
          const double gamma_val = 300.0 / (double)thisLevel;
          r = (int)round(denominator * pow((double)nr, gamma_val) + offset);
          g = (int)round(denominator * pow((double)ng, gamma_val) + offset);
          b = (int)round(denominator * pow((double)nb, gamma_val) + offset);
          if (bright < 0 && altMode == 0)
          {
              if (r < -165535) r = -165535;
              if (g < -165535) g = -165535;
              if (b < -165535) b = -165535;
          }
      }
    }

    // RGB half only; altContra==1 touched nothing but alpha, which is a LUT now.
    template<bool UseLUT>
    QPV_FORCEINLINE void contrast(int level, int linearGamma, float fintensity, int noClamping, float fip) {
        if (noClamping==1)
        {
           // a channel below 0 goes through the same formula as any other value
           float maxu = max(r, max(g, b));
           float nr = r;
           float ng = g;
           float nb = b;
           float fi;
           if (level>=0)
           {
              // getGrayscaleAdvanced() lifts a pixel with a channel below 0; the mix needs its own grey
              int gray = getGrayscaleAdvanced();
              if (min(r, min(g, b))<0)
                 gray = (int)(r*0.299701f + g*0.587130f + b*0.114180f);
              nr = weighTwoValues(gray, r, fintensity);
              ng = weighTwoValues(gray, g, fintensity);
              nb = weighTwoValues(gray, b, fintensity);
              if (level<19500)
              {
                 fi = level/19500.0f;
                 r = weighTwoValues(nr, r, fi);
                 g = weighTwoValues(ng, g, fi);
                 b = weighTwoValues(nb, b, fi);
             } else
             {
                 r = nr;
                 g = ng;
                 b = nb;
             }
           }

           if (maxu<65535)
              maxu = 65535.0f;

           float mid = maxu/2.0f;
           if (level>0)
           {
              nr = floor( (float)fip * (nr - mid) ) + mid;
              ng = floor( (float)fip * (ng - mid) ) + mid;
              nb = floor( (float)fip * (nb - mid) ) + mid;
              if (level<16000)
              {
                 fi = level/16000.0f;
                 r = weighTwoValues(nr, r, fi);
                 g = weighTwoValues(ng, g, fi);
                 b = weighTwoValues(nb, b, fi);
              } else
              {
                 r = nr;
                 g = ng;
                 b = nb;
              }
           } else
           {
              r = weighTwoValues(r, 32768, fip);
              g = weighTwoValues(g, 32768, fip);
              b = weighTwoValues(b, 32768, fip);
           }
        } else
        {
           if (level>0)
           {
              int gray = getInt16grayscale(r, g, b);
              if (linearGamma==1)
              {
                 r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[r], fintensity)];
                 g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[g], fintensity)];
                 b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[b], fintensity)];
              } else
              {
                 r = weighTwoValues(gray, r, fintensity);
                 g = weighTwoValues(gray, g, fintensity);
                 b = weighTwoValues(gray, b, fintensity);
              }
           }

           if (UseLUT)
           {
              r = LUTcontra[r];
              g = LUTcontra[g];
              b = LUTcontra[b];
           } else
           {
              r = contraMathsInt16(r, fip, 32768);
              g = contraMathsInt16(g, fip, 32768);
              b = contraMathsInt16(b, fip, 32768);
           }
        }
    }

    QPV_FORCEINLINE void saturation(int level, int altMode, int linearGamma, float saturation) {
        if (altMode>1)
        {
           // the Desaturate panel's channels: 2 = red, 3 = green, 4 = blue
           int gray = (altMode==2) ? r : g;
           if (altMode>=4)
              gray = b;
           r = gray;
           g = gray;
           b = gray;
        } else if (altMode==1)
        {
            HSLColor HSLu = ConvertRGBtoHSL();
            saturation = (level<0) ? 0.001f : saturation;
            HSLColor newHSL = {HSLu.h, saturation, HSLu.l};
            RGBColorI newRGB = newHSL.ConvertHSLtoRGBint16();
            float fi = 0.0f;
            if (inRange(0, 16384, level))
               fi = level/16384.0f;
            else if (inRange(-65535, 0, level))
               fi = abs(level)/65535.0f;

            if (inRange(-65535, 16384, level))
            {
               r = weighTwoValues(newRGB.r, r, fi);
               g = weighTwoValues(newRGB.g, g, fi);
               b = weighTwoValues(newRGB.b, b, fi);
            } else
            {
               r = newRGB.r;
               g = newRGB.g;
               b = newRGB.b;
            }
        } else if (level<0)
        {
           const int gray = getInt16grayscale(r, g, b);
           const float fintensity = int_to_float[abs(level)];
           if (linearGamma==1)
           {
              r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[r], fintensity)];
              g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[g], fintensity)];
              b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[b], fintensity)];
           } else
           {
              r = weighTwoValues(gray, r, fintensity);
              g = weighTwoValues(gray, g, fintensity);
              b = weighTwoValues(gray, b, fintensity);
           }
        } else
        {
           const float max_val = max(max(r, g), b);
           const float min_val = min(min(r, g), b);
           const float luxAvg = (max_val + min_val) / 2.0f;
           const float factor = (level + 21823)/21823.0f;

           float lux = clamp(getInt16grayscale(r, g, b)/3.0f, 0.0f, 65535.0f);
           lux = weighTwoValues(lux, 0.0f, int_to_float[level]);

           r = clamp(factor * ((float)r - luxAvg) + luxAvg + lux, 0.0f, 65535.0f);
           g = clamp(factor * ((float)g - luxAvg) + luxAvg + lux, 0.0f, 65535.0f);
           b = clamp(factor * ((float)b - luxAvg) + luxAvg + lux, 0.0f, 65535.0f);
        }
    }

    QPV_FORCEINLINE void hueRotate(int degrees) {
        HSLColor HSLu = ConvertRGBtoHSL();
        float hue = HSLu.h + (float)degrees;
        while (hue > 360.0f) hue -= 360.0f;
        while (hue < 0.0f) hue += 360.0f;

        HSLColor newHSL = {hue, HSLu.s + 0.01, HSLu.l};
        RGBColorI newRGB = newHSL.ConvertHSLtoRGBint16();
        // small angles fade in; AdjustImageColorsPrecise() passes -15..-1 as 345..359
        const int sd = (degrees>180) ? degrees - 360 : degrees;
        float fi = 0.0f;
        if (inRange(0, 15, sd))
           fi = sd/15.0f;
        else if (inRange(-15, 0, sd))
           fi = abs(sd)/15.0f;

        if (inRange(-15, 15, sd))
        {
           r = weighTwoValues(newRGB.r, r, fi);
           g = weighTwoValues(newRGB.g, g, fi);
           b = weighTwoValues(newRGB.b, b, fi);
        } else
        {
           r = newRGB.r;
           g = newRGB.g;
           b = newRGB.b;
        }
    }

    QPV_FORCEINLINE void tinto(int degrees, int level, int linearGamma) {
        HSLColor HSLu = ConvertRGBtoHSL();
        HSLColor newHSL = {(double)degrees, 0.5, HSLu.l};
        RGBColorI newRGB = newHSL.ConvertHSLtoRGBint16();
        const float fintensity = int_to_float[level];
        if (linearGamma==1)
        {
           r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[newRGB.r], gamma_to_linearInt16[r], fintensity)];
           g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[newRGB.g], gamma_to_linearInt16[g], fintensity)];
           b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[newRGB.b], gamma_to_linearInt16[b], fintensity)];
        } else
        {
           r = weighTwoValues(newRGB.r, r, fintensity);
           g = weighTwoValues(newRGB.g, g, fintensity);
           b = weighTwoValues(newRGB.b, b, fintensity);
        }
    }

    QPV_FORCEINLINE void tint(float hue, int level, int altMode, int linearGamma) {
        if (altMode==1)
           return tinto(hue, level, linearGamma);

        int z = getInt16grayscale(r, g, b);
        const float gray = int_to_float[z];
        float normalized_hue = hue;
        while (normalized_hue > 360.0f) normalized_hue -= 360.0f;
        while (normalized_hue < 0.0f) normalized_hue += 360.0f;
        const int hi = (int)(floor(normalized_hue / 60.0f)) % 6;
        const float f = normalized_hue / 60.0f - floor(normalized_hue / 60.0f);
        const float q = gray * (1.0f - f);
        const float t = gray * (1.0f - (1.0f - f));
        int nr = 0, ng = 0, nb = 0;
        switch (hi) {
            case 0: nr = z; ng = t * 65535.0f; nb = 0; break;
            case 1: nr = q * 65535.0f; ng = z; nb = 0; break;
            case 2: nr = 0; ng = z; nb = t * 65535.0f; break;
            case 3: nr = 0; ng = q * 65535.0f; nb = z; break;
            case 4: nr = t * 65535.0f; ng = 0; nb = z; break;
            case 5: nr = z; ng = 0; nb = q * 65535.0f; break;
        }

        z = z/3; // gray
        const float fintensity = int_to_float[level];
        nr = clamp(nr + z, 0, 65535);
        ng = clamp(ng + z, 0, 65535);
        nb = clamp(nb + z, 0, 65535);
        if (linearGamma==1)
        {
           r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nr], gamma_to_linearInt16[r], fintensity)];
           g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[ng], gamma_to_linearInt16[g], fintensity)];
           b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nb], gamma_to_linearInt16[b], fintensity)];
        } else
        {
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
        }
    }
};

// ---------------------------------------------------------------------------
// AdjustImageColorsPrecise
//
// The entry point reads and writes 8-bit pixels and only computes at 16 bits,
// so the whole filter is a pure 4-bytes-in / 4-bytes-out map. Two things fall
// out of that, and they are where the speed comes from:
//
//  * alpha never reads r/g/b and r/g/b never read alpha  ->  alpha ALWAYS
//    collapses to a 256-entry byte table, whatever the settings;
//  * when no cross-channel op is live (no hue / saturation / tint / shadows /
//    highlights, and contrast<=0) r/g/b are separable too, so the entire
//    pipeline collapses to 4 byte tables and the inner loop is 4 lookups.
//
// AdjustColorsFXplan::pixelRGB() is the single scalar kernel. The table builders and
// the per-pixel path both go through it, so the two cannot drift apart.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Per-call plan. Everything loop-invariant is resolved here, once.
// ---------------------------------------------------------------------------
struct OutRGB { unsigned char b, g, r; };

struct AdjustColorsFXplan {
    int invertColors, gammaLvl, brightness, altBright, altContra, contrast;
    int altHiLows, shadows, highs, hue, tintDegrees, tintAmount, altTint;
    int altSat, saturation, seeThrough, linearGamma, noClamping;
    int whitePoint, blackPoint, noiseMode;
    int rOffset, gOffset, bOffset, aOffset;
    int rThreshold, gThreshold, bThreshold, aThreshold;
    float fiBright, fiShadows, fiHighs, fiContra, factorContrast, factorHiLows;
    float saturateFactor, fintensity;
    double zammaGamma, zammaBright;
    bool headCoversGamma, headCoversBright;
    bool anyOffset, anyThreshold, doHiLows;
    bool skipZeroAlpha;

    // head[c] : source byte -> 16-bit channel value with every leading
    // per-channel op already folded in.  c: 0=B 1=G 2=R.
    int head[3][256];
    unsigned char aLUT[256];

    // Fast path: out_k = chanLUT[k][ q[k] ], or chanLUT[k][ q[swapIdx] ] when
    // altSat>1 collapsed every channel onto one source channel.
    bool lutPath, chanSwap;
    int swapIdx;
    unsigned char chanLUT[3][256];

    template<bool UseLUT>
    QPV_FORCEINLINE void applyRGB(RGBA16color& px) const {
        if (!headCoversGamma && gammaLvl!=300)
           px.gamma(gammaLvl, brightness, altBright, noClamping, zammaGamma);
        if (!headCoversBright)
        {
           if (doHiLows)
           {
              int gray = (noClamping==1) ? 0 : getInt16grayscale(px.r, px.g, px.b);
              if (shadows!=0)
                 px.shadows(shadows, altHiLows, linearGamma, gray, noClamping, fiShadows);
              if (highs!=0)
                 px.highlights(highs, altHiLows, linearGamma, factorHiLows, gray, noClamping, fiHighs);
           }
           if (anyOffset)
              px.channelOffsetRGB(rOffset, gOffset, bOffset, noClamping);
           if (brightness!=0)
              px.brightness<UseLUT>(brightness, altBright, noClamping, fiBright, zammaBright);
        }
        if (contrast!=0 && altContra==0)
           px.contrast<UseLUT>(contrast, linearGamma, factorContrast, noClamping, fiContra);
        if (noClamping==1)
        {
           px.r = clamp(px.r, 0, 65535);
           px.g = clamp(px.g, 0, 65535);
           px.b = clamp(px.b, 0, 65535);
        }
        if (hue!=0)
           px.hueRotate(hue);
        if (saturation!=0)
           px.saturation(saturation, altSat, linearGamma, saturateFactor);
        if (blackPoint>0)
           px.blackPoint(blackPoint, noiseMode);
        if (whitePoint<65535)
           px.whitePoint(whitePoint, noiseMode);
        if (tintAmount>0)
           px.tint(tintDegrees, tintAmount, altTint, linearGamma);
        if (anyThreshold)
           px.thresholdRGB(rThreshold, gThreshold, bThreshold, seeThrough);

        if (blackPoint>0 || whitePoint<65535)
        {
           // blackPoint()/whitePoint() with noise can push a channel outside
           // [0,65535]; the original then indexed int_to_char[] out of bounds.
           px.r = clamp(px.r, 0, 65535);
           px.g = clamp(px.g, 0, 65535);
           px.b = clamp(px.b, 0, 65535);
        }
    }

    // The one scalar kernel. The 256-entry table builders and the general loop
    // both go through here, so the two paths cannot drift apart.
    template<bool UseLUT>
    QPV_FORCEINLINE OutRGB pixelRGB(int oR, int oG, int oB) const {
        RGBA16color px;
        px.b = head[0][oB];
        px.g = head[1][oG];
        px.r = head[2][oR];
        px.a = 0;
        applyRGB<UseLUT>(px);

        OutRGB o;
        if (linearGamma==1 && fintensity<1.0f)
        {
            // rounded back from linear light: the 16-bit round trip of a shadow level can land just below it
            o.r = blend_degamma_lut[weighTwoValues(gamma_to_linearInt16[px.r], gamma_to_linearInt16[char_to_int[oR]], fintensity)];
            o.g = blend_degamma_lut[weighTwoValues(gamma_to_linearInt16[px.g], gamma_to_linearInt16[char_to_int[oG]], fintensity)];
            o.b = blend_degamma_lut[weighTwoValues(gamma_to_linearInt16[px.b], gamma_to_linearInt16[char_to_int[oB]], fintensity)];
        } else
        {
            o.r = weighTwoValues(int_to_char[px.r], oR, fintensity);
            o.g = weighTwoValues(int_to_char[px.g], oG, fintensity);
            o.b = weighTwoValues(int_to_char[px.b], oB, fintensity);
        }
        return o;
    }
};

static void buildAdjustColorsFXplan(AdjustColorsFXplan& p, int opacity, int invertColors, int altSat, int saturation,
    int altBright, int brightness, int altContra, int contrast, int altHiLows, int shadows,
    int highs, int hue, int tintDegrees, int tintAmount, int altTint, int gamma,
    int rOffset, int gOffset, int bOffset, int aOffset, int rThreshold, int gThreshold,
    int bThreshold, int aThreshold, int seeThrough, int linearGamma, int noClamping,
    int whitePoint, int blackPoint, int noiseMode)
{
    // ---- scalars, in the exact order the original computed them ----
    p.zammaGamma  = (gamma!=300) ? 1.0f / ((float)gamma/300.0f) : 1.0;
    p.zammaBright = (altBright==0 && brightness<0) ? 1.0f / ((float)(77069.0f - brightness)/77069.0f) : 1.0;
    p.fiBright    = (brightness>0) ? brightness/32768.0f : -1*int_to_float[-1*brightness];

    float azx = (altHiLows==1) ? 25 : 95;
    p.factorHiLows = (65536.5f * (azx + 65535.0f)) / (65535.0f * (65536.5f - azx));
    p.fiShadows    = (shadows>0) ? shadows/32768.0f : -1*int_to_float[-1*shadows];
    p.fiHighs      = (highs>0) ? highs/32768.0f : -1*int_to_float[-1*highs];

    p.factorContrast = contrast/98302.0f;   // NOTE: pre-clamp, as in the original
    if (contrast>65525)
       contrast = 65525;
    p.fiContra = (65536.5f * (contrast + 65535.0f)) / (65535.0f * (65536.5f - contrast));

    if (hue<0)
       hue += 360;
    if (tintDegrees<0)
       tintDegrees += 360;

    p.saturateFactor = (saturation<0) ? (65535.0f - abs(saturation))/131070.0f : 0.5f + saturation/131070.0f;
    p.fintensity = char_to_float[opacity];

    p.invertColors = invertColors; p.gammaLvl = gamma; p.brightness = brightness;
    p.altBright = altBright; p.altContra = altContra; p.contrast = contrast;
    p.altHiLows = altHiLows; p.shadows = shadows; p.highs = highs; p.hue = hue;
    p.tintDegrees = tintDegrees; p.tintAmount = tintAmount; p.altTint = altTint;
    p.altSat = altSat; p.saturation = saturation; p.seeThrough = seeThrough;
    p.linearGamma = linearGamma; p.noClamping = noClamping;
    p.whitePoint = whitePoint; p.blackPoint = blackPoint; p.noiseMode = noiseMode;
    p.rOffset = rOffset; p.gOffset = gOffset; p.bOffset = bOffset; p.aOffset = aOffset;
    p.rThreshold = rThreshold; p.gThreshold = gThreshold; p.bThreshold = bThreshold;
    p.aThreshold = aThreshold;

    p.anyOffset    = (aOffset!=0 || rOffset!=0 || gOffset!=0 || bOffset!=0);
    p.anyThreshold = (aThreshold>=0 || rThreshold>=0 || gThreshold>=0 || bThreshold>=0);
    p.doHiLows     = (shadows!=0 || highs!=0);
    p.skipZeroAlpha = (altContra==0 && aOffset==0);

    // gamma()'s noClamping branch mixes channels, so it cannot be folded.
    p.headCoversGamma  = (gamma==300 || noClamping==0);
    p.headCoversBright = p.headCoversGamma && !p.doHiLows;

    // ---- head tables (256 evaluations, so the closed forms are used) ----
    const int chanOff[3] = { bOffset, gOffset, rOffset };
    for (int c = 0; c < 3; c++)
    {
        for (int i = 0; i < 256; i++)
        {
            int v = char_to_int[i];
            if (invertColors==1)
               v = 65535 - v;
            if (p.headCoversGamma && gamma!=300)
               v = gammaMathsInt16(v, p.zammaGamma);
            if (p.headCoversBright)
            {
                if (p.anyOffset)
                   v = (noClamping==1) ? v + chanOff[c] : clamp(v + chanOff[c], 0, 65535);
                if (brightness!=0)
                {
                    RGBA16color t; t.r = t.g = t.b = v; t.a = 0;
                    t.brightness<false>(brightness, altBright, noClamping, p.fiBright, p.zammaBright);
                    v = t.r;
                }
            }
            p.head[c][i] = v;
        }
    }

    // ---- alpha: always a 256-entry LUT (alpha never reads r/g/b) ----
    for (int i = 0; i < 256; i++)
    {
        int a = char_to_int[i];
        if (p.anyOffset)
           a = clamp(a + aOffset, 0, 65535);
        if (contrast!=0 && altContra==1)
           a = contraMathsInt16(a, p.fiContra, 32768);        // == LUTcontra[a]
        if (p.anyThreshold && aThreshold>=0)
        {
           if (seeThrough==2)      a = (a>aThreshold) ? a : 0;
           else if (seeThrough==3) a = (a>aThreshold) ? 65535 : a;
           else                    a = (a>aThreshold) ? 65535 : 0;
        }
        if (linearGamma==1 && p.fintensity<1.0f)
           p.aLUT[i] = blend_degamma_lut[weighTwoValues(gamma_to_linearInt16[a], gamma_to_linearInt16[char_to_int[i]], p.fintensity)];
        else
           p.aLUT[i] = weighTwoValues(int_to_char[a], i, p.fintensity);
    }

    // ---- can the whole RGB pipeline collapse to 3 byte tables? ----
    const bool noiseFree   = (noiseMode!=1 || (blackPoint<=0 && whitePoint>=65535));
    const bool contraSep   = (contrast==0 || altContra==1 || contrast<0);
    const bool preSatSep   = p.headCoversBright && contraSep && hue==0 && noiseFree;
    const bool caseA       = preSatSep && saturation==0 && tintAmount<=0;
    // altSat>1 collapses r=g=b to one source channel, so everything downstream
    // becomes a function of that one byte - but only if opacity does not blend
    // the per-channel original back in.
    const bool caseB       = preSatSep && saturation!=0 && altSat>1 && p.fintensity>=1.0f;

    p.lutPath  = caseA || caseB;
    p.chanSwap = false;
    p.swapIdx  = 0;
    if (p.lutPath)
    {
        int c = 1;                       // altSat 3 -> G
        if (caseB && altSat==2) c = 2;   // -> R
        if (caseB && altSat>=4) c = 0;   // -> B
        p.chanSwap = caseB;
        p.swapIdx  = c;
        for (int i = 0; i < 256; i++)
        {
            OutRGB o = p.pixelRGB<false>(i, i, i);
            p.chanLUT[0][i] = o.b; p.chanLUT[1][i] = o.g; p.chanLUT[2][i] = o.r;
        }
        return;                          // no 65536-entry table is needed at all
    }

    // ---- 65536-entry tables: only what the per-pixel path will actually read ----
    if (p.doHiLows)
    {
        if (shadows!=0)
        {
           // #pragma omp parallel for schedule(static)
           for (int i = 0; i < 65536; i++) LUTshadows[i] = brightMathsInt16(i, p.fiShadows);
        }
        if (highs!=0)
        {
           // #pragma omp parallel for schedule(static)
           for (int i = 0; i < 65536; i++) LUThighs[i] = brightMathsInt16(i, p.fiHighs);
        }
    }
    if (!p.headCoversBright && brightness!=0 && noClamping==0)
    {
        if (altBright==1)
        {
           // #pragma omp parallel for schedule(static)
           for (int i = 0; i < 65536; i++) LUTbright[i] = brightMathsInt16(i, p.fiBright);
        } else if (brightness<0)
        {
           // #pragma omp parallel for schedule(static)
           for (int i = 0; i < 65536; i++) LUTgammaBright[i] = gammaMathsInt16(i, p.zammaBright);
        }
    }
    if (contrast!=0 && altContra==0 && noClamping==0)
    {
        // #pragma omp parallel for schedule(static)
        for (int i = 0; i < 65536; i++) LUTcontra[i] = contraMathsInt16(i, p.fiContra, 32768);
    }
}


DLL_API int DLL_CALLCONV AdjustImageColorsPrecise(unsigned char *BitmapData, int w, int h, int Stride, int bpp, int opacity, int invertColors, int altSat, int saturation, int altBright, int brightness, int altContra, int contrast, int altHiLows, int shadows, int highs, int hue, int tintDegrees, int tintAmount, int altTint, int gamma, int rOffset, int gOffset, int bOffset, int aOffset, int rThreshold, int gThreshold, int bThreshold, int aThreshold, int seeThrough, int linearGamma, int noClamping, int whitePoint, int blackPoint, int noiseMode, unsigned char *maskBitmap, int mStride) {
    if (opacity<2)
      return 1;

    AdjustColorsFXplan p;
    buildAdjustColorsFXplan(p, opacity, invertColors, altSat, saturation, altBright, brightness, altContra,
        contrast, altHiLows, shadows, highs, hue, tintDegrees, tintAmount, altTint, gamma,
        rOffset, gOffset, bOffset, aOffset, rThreshold, gThreshold, bThreshold, aThreshold,
        seeThrough, linearGamma, noClamping, whitePoint, blackPoint, noiseMode);

    const int bpc = bpp/8;
    const bool has32 = (bpp==32);

    #pragma omp parallel for schedule(dynamic) if ((INT64)w*h >= 16384)
    for (int y = 0; y < h; y++)
    {
        unsigned char* row = BitmapData + (INT64)y * Stride;
        if (p.lutPath)
        {
            const unsigned char* LB = p.chanLUT[0];
            const unsigned char* LG = p.chanLUT[1];
            const unsigned char* LR = p.chanLUT[2];
            for (int x = 0; x < w; x++)
            {
                if (clipMaskFilter(x, y, maskBitmap, mStride)==1)
                   continue;

                unsigned char* q = row + (INT64)x * bpc;
                unsigned char na = 0;
                if (has32)
                {
                   if (p.skipZeroAlpha && q[3]==0)
                      continue;
                   na = p.aLUT[q[3]];
                }
                if (p.chanSwap)
                {
                   const unsigned char v = q[p.swapIdx];
                   const unsigned char nb = LB[v], ng = LG[v], nr = LR[v];
                   q[0] = nb; q[1] = ng; q[2] = nr;
                } else
                {
                   const unsigned char nb = LB[q[0]], ng = LG[q[1]], nr = LR[q[2]];
                   q[0] = nb; q[1] = ng; q[2] = nr;
                }
                if (has32)
                   q[3] = na;
            }
        } else
        {
            for (int x = 0; x < w; x++)
            {
                if (clipMaskFilter(x, y, maskBitmap, mStride)==1)
                   continue;

                unsigned char* q = row + (INT64)x * bpc;
                unsigned char na = 0;
                if (has32)
                {
                   if (p.skipZeroAlpha && q[3]==0)
                      continue;
                   na = p.aLUT[q[3]];
                }
                OutRGB o = p.pixelRGB<true>(q[2], q[1], q[0]);
                q[0] = o.b; q[1] = o.g; q[2] = o.r;
                if (has32)
                   q[3] = na;
            }
        }
    }
    return 1;
}

#endif // QPV_COLOR_ADJUST_H
