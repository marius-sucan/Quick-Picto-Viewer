// blend-modes.h
//
// The layer blend modes: CalculateNewBlendModes(), the tables only it reads, and
// initBlendLUTs(), which fills them.
//
// #included by qpv-main.cpp right after the shared tables it reads and ahead of initWICnow(),
// which calls initBlendLUTs(); the effects, flood-fill.h and the brush blend through it.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_BLEND_MODES_H
#define QPV_BLEND_MODES_H

#include <cmath>

// filled by initBlendLUTs()
static float blend_gray_R_float[256];          // r -> grayscale contribution as float [0..1]
static float blend_gray_G_float[256];          // g -> grayscale contribution as float [0..1]
static float blend_gray_B_float[256];          // b -> grayscale contribution as float [0..1]
static unsigned char* blend_lut_srgb = nullptr;
static unsigned short* blend_lut_linear = nullptr;
static unsigned short gamma_to_linear_16[256];

static unsigned short gamma_to_linear[256];
static unsigned char linear_to_gamma[32769];
static float char_to_float[256];
static float char_to_floatGamma[256];
static float char_to_grayRfloat[256];
static float char_to_grayGfloat[256];
static float char_to_grayBfloat[256];
static float int_to_float[65536];
static int int_to_char[65536];
static int char_to_int[256];
static int int_to_grayRi[65536];
static int int_to_grayGi[65536];
static int int_to_grayBi[65536];
static int linear_to_gammaInt16[65536];
static int gamma_to_linearInt16[65536];

// read by CalculateNewBlendModes() and the colour adjust; initialized in initWICnow
static unsigned char blend_degamma_lut[65536]; // maps fixed16 [0..65535] -> degamma'd byte [0..255]

static double LUT_X_R[256];
static double LUT_X_G[256];
static double LUT_X_B[256];
static double LUT_Y_R[256];
static double LUT_Y_G[256];
static double LUT_Y_B[256];
static double LUT_Z_R[256];
static double LUT_Z_G[256];
static double LUT_Z_B[256];

struct RGBAColor {
    int b, g, r, a;
};

// a pixel of a 24 or 32-bit buffer; a 24-bit one is opaque
QPV_FORCEINLINE RGBAColor readBGRA(const unsigned char *px, const int bpp) {
    return {px[0], px[1], px[2], (bpp==32) ? px[3] : 255};
}

// the alpha is written to 32-bit pixels only
QPV_FORCEINLINE void writeBGRA(unsigned char *px, const RGBAColor &c, const int bpp) {
    px[2] = c.r;
    px[1] = c.g;
    px[0] = c.b;
    if (bpp==32)
       px[3] = c.a;
}

static inline float blend_grayscale_float(int r, int g, int b) {
    return blend_gray_R_float[r] + blend_gray_G_float[g] + blend_gray_B_float[b];
}

inline double toLABfx(double Y) {
  // if (Y >= 0.00885645167903563082) // CIE epsilon = 216/24389
  if (Y >= 8.88564517) // intentionally chosen value
     Y = cbrt(Y);  // 1/3
  else
     Y = 7.7870370 * Y + 0.1379310; // (841.0/108.0) * Y + ( 4.0 / 29.0 );

  return Y;
}

inline int RGBtoGray(int &sR, int &sG, int &sB, int &alternateMode) {
  // https://getreuer.info/posts/colorspace/index.html
  // http://www.easyrgb.com/en/math.php
  // sR, sG and sB (Standard RGB) input range [0, 255]
  // X, Y and Z output refer to a D65/2° standard illuminant.
  // return value is L* - Luminance from L*ab, based on D65 luminant

  if (alternateMode==1)
     return round(char_to_grayRfloat[sR] + char_to_grayGfloat[sG] + char_to_grayBfloat[sB]); // weighted grayscale conversion

  double Y = LUT_Y_R[sR] + LUT_Y_G[sG] + LUT_Y_B[sB];

  Y = toLABfx(Y);
  double L = 116.0*Y - 16.0;
  return round(L/2); // return derived luminosity in pseudo-LAB color space
}

static inline float compute_blend_float(int mode, float rOf, float rBf) {
    float rT = rOf;
    switch (mode)
    {
        case 1: rT = min(rOf, rBf); break;
        case 2: rT = rOf * rBf; break;
        case 3: rT = rOf + rBf - 1.0f; break;
        case 4: rT = (rOf > 0.0f) ? (1.0f - ((1.0f - rBf) / rOf)) : 0.0f; break;
        case 5: rT = max(rOf, rBf); break;
        case 6: rT = 1.0f - ((1.0f - rBf) * (1.0f - rOf)); break;
        case 7: rT = rOf + rBf; break;
        case 8: rT = (rOf < 0.5f) ? (2.0f * rOf * rBf) : (1.0f - (2.0f * (1.0f - rOf) * (1.0f - rBf))); break;
        case 9: {
            float sqrt_rBf = sqrt(rBf);
            rT = (rOf < 0.5f) ? ((1.0f - 2.0f * rOf) * (rBf * rBf) + 2.0f * rBf * rOf) : (2.0f * rBf * (1.0f - rOf) + sqrt_rBf * (2.0f * rOf - 1.0f));
            break;
        }
        case 10: rT = (rBf < 0.5f) ? (2.0f * rOf * rBf) : (1.0f - (2.0f * (1.0f - rOf) * (1.0f - rBf))); break;
        case 11: rT = (rOf <= (1.0f - rBf)) ? 0.0f : 1.0f; break;
        case 12: rT = rBf + (2.0f * rOf) - 1.0f; break;
        case 13: rT = (rOf < 1.0f) ? (rBf / (1.0f - rOf)) : 1.0f; break;
        case 14: rT = (rOf < 0.5f) ? ((rOf > 0.0f) ? (1.0f - (1.0f - rBf) / (2.0f * rOf)) : 0.0f) : ((rOf < 1.0f) ? (rBf / (2.0f * (1.0f - rOf))) : 1.0f); break;
        case 15: rT = (rBf + rOf) * 0.5f; break;
        case 16: rT = (rOf > 0.0f) ? (rBf / rOf) : 1.0f; break;
        case 17: rT = rOf + rBf - 2.0f * (rOf * rBf); break;
        case 18: rT = abs(rBf - rOf); break;
        case 19: rT = rBf - rOf; break;
        case 22: rT = 1.0f - abs(rOf - rBf); break;
    }
    return max(0.0f, min(1.0f, rT));
}

// called by initWICnow()
static void initBlendLUTs() {
    for (int i = 0; i < 256; i++)
    {
        float f = i / 255.0f;
        blend_gray_R_float[i] = f * 0.299701f;
        blend_gray_G_float[i] = f * 0.587130f;
        blend_gray_B_float[i] = f * 0.114180f;
    }

    if (!blend_lut_srgb)
       blend_lut_srgb = new unsigned char[23 * 256 * 256];
    if (!blend_lut_linear)
       blend_lut_linear = new unsigned short[23 * 256 * 256];

    for (int i = 0; i < 256; i++){
        gamma_to_linear_16[i] = (unsigned short)(pow(i / 255.0f, 2.1f) * 65535.0f + 0.5f);
    }

    for (int mode = 1; mode <= 22; mode++)
    {
        if (mode == 20 || mode == 21)
           continue;

        for (int t = 0; t < 256; t++)
        {
            for (int b = 0; b < 256; b++)
            {
                float rOf = t / 255.0f;
                float rBf = b / 255.0f;
                float rT = compute_blend_float(mode, rOf, rBf);
                blend_lut_srgb[mode * 65536 + t * 256 + b] = (unsigned char)(rT * 255.0f + 0.5f);

                float rOf_lin = pow(rOf, 2.1f);
                float rBf_lin = pow(rBf, 2.1f);
                float rT_lin = compute_blend_float(mode, rOf_lin, rBf_lin);
                blend_lut_linear[mode * 65536 + t * 256 + b] = (unsigned short)(rT_lin * 65535.0f + 0.5f);
            }
        }
    }
}

// the tables the pixel code reads; initWICnow() fills them once
static void initColorLUTs() {
    // source https://www.teamten.com/lawrence/graphics/gamma/
    static const float GAMMA = 2.1;
    int result;
    for (int i = 0; i < 32769; i++)
    {
        result = (int)(pow(i/32768.0, 1/GAMMA)*255.0 + 0.5);
        linear_to_gamma[i] = (unsigned char)result;
    }

    for (int i = 0; i < 256; i++)
    {
        char_to_float[i] = i/255.0f;
        result = (int)(pow(char_to_float[i], GAMMA)*32768.0f + 0.5f);
        gamma_to_linear[i] = (unsigned short)result;
        char_to_grayRfloat[i] = i*0.299701f;
        char_to_grayGfloat[i] = i*0.587130f;
        char_to_grayBfloat[i] = i*0.114180f;
        char_to_int[i] = char_to_float[i] * 65535.0f;
        char_to_floatGamma[i] = pow(char_to_float[i], GAMMA);

        double val = char_to_float[i];
        if (val > 0.0404482362771076)
            val = pow((val + 0.055)/1.055, 2.4);
        else
            val = val / 12.92;

        double val100 = val * 100.0;
        
        LUT_X_R[i] = val100 * 0.4123955889674142161 / 95.047;
        LUT_X_G[i] = val100 * 0.3575834307637148171 / 95.047;
        LUT_X_B[i] = val100 * 0.1804926473817015735 / 95.047;

        LUT_Y_R[i] = val100 * 0.2125862307855955516 / 100.000;
        LUT_Y_G[i] = val100 * 0.7151703037034108499 / 100.000;
        LUT_Y_B[i] = val100 * 0.07220049864333622685 / 100.000;

        LUT_Z_R[i] = val100 * 0.01929721549174694484 / 108.883;
        LUT_Z_G[i] = val100 * 0.1191838645808485318 / 108.883;
        LUT_Z_B[i] = val100 * 0.9504971251315797660 / 108.883;
    }

    for (int i = 0; i < 65536; i++)
    {
        int_to_float[i] = (float)i/65535.0f;
        int_to_char[i] = int_to_float[i] * 255.0f;
        int_to_grayRi[i] = i*0.299701f;
        int_to_grayGi[i] = i*0.587130f;
        int_to_grayBi[i] = i*0.114180f;

        result = (int)(pow(int_to_float[i], 1.0f/GAMMA)*65535.0f + 0.5f);
        linear_to_gammaInt16[i] = result;
        result = (int)(pow(int_to_float[i], GAMMA)*65535.0f + 0.5f);
        gamma_to_linearInt16[i] = result;
    }

    // Initialize LUTs for CalculateNewBlendModes
    static const float invGAMMA = 1.0f / GAMMA;
    for (int i = 0; i < 65536; i++)
    {
        float v = (float)i / 65535.0f;
        blend_degamma_lut[i] = (unsigned char)(pow(v, invGAMMA) * 255.0f + 0.5f);
    }
}

inline RGBAColor CalculateNewBlendModes(
  RGBAColor Orgb,
  RGBAColor Brgb,
  int blendMode,
  int flipLayers,
  int linearGamma,
  int keepAlpha,
  int bpp,
  int opacity) {
// CalculateNewBlendModes - Optimized blend mode computation

    // ---------- Special modes: Replace / Replace-with-blend / Alpha-clip ----------
    // Behind [25] fades the new layer here, before the swap below puts it underneath
    if (blendMode < 24 || blendMode == 25)
       Orgb.a = (Orgb.a * (255 - opacity)) / 255;

    const int oA = (blendMode >= 23 || blendMode == 0) ? -1 : Brgb.a;
    if (blendMode == 34 || blendMode == 110)
    {
       int opa = (blendMode == 34 || (Orgb.a > 0 && bpp == 32) || (Orgb.r == 0 && Orgb.g == 0 && Orgb.b == 0 && bpp != 32)) ? 1 : 0;
       if (bpp != 32 && opa == 1)
       {
          const int invA = 255 - Orgb.a;
          Orgb.r = max(Orgb.r - invA, 0);
          Orgb.g = max(Orgb.g - invA, 0);
          Orgb.b = max(Orgb.b - invA, 0);
       }
       if (keepAlpha == 1)
          Orgb.a = max(Brgb.a - (255 - Orgb.a), 0);

       return (opa == 1) ? Orgb : Brgb;
    } else if (blendMode == 24 || blendMode == 100)
    {
       const int opa = (blendMode == 24 || (Orgb.a > 0 && bpp == 32) || (Orgb.r == 0 && Orgb.g == 0 && Orgb.b == 0 && bpp != 32)) ? 1 : 0;
       if (opa != 1)
          return Brgb;

       const float f = char_to_float[255 - opacity];
       // the colours mix by how much of each layer is visible; with equal alphas that is f exactly
       const float wO = f * Orgb.a, wB = (1.0f - f) * Brgb.a;
       const float g = (Orgb.a == Brgb.a || wO + wB <= 0) ? f : wO / (wO + wB);
       int fR, fG, fB;
       if (linearGamma == 1)
       {
          fR = linear_to_gamma[weighTwoValues(gamma_to_linear[Orgb.r], gamma_to_linear[Brgb.r], g)];
          fG = linear_to_gamma[weighTwoValues(gamma_to_linear[Orgb.g], gamma_to_linear[Brgb.g], g)];
          fB = linear_to_gamma[weighTwoValues(gamma_to_linear[Orgb.b], gamma_to_linear[Brgb.b], g)];
       } else
       {
          fR = weighTwoValues(Orgb.r, Brgb.r, g);
          fG = weighTwoValues(Orgb.g, Brgb.g, g);
          fB = weighTwoValues(Orgb.b, Brgb.b, g);
       }

       int fA = weighTwoValues(Orgb.a, Brgb.a, f);
       if (keepAlpha == 1)
          fA = max(fA - (255 - Brgb.a), 0);
       return {fB, fG, fR, fA};
    } else if (blendMode == 23)
    {
       const float f = char_to_float[Orgb.a];
       int fR, fG, fB;
       if (linearGamma == 1)
       {
          fR = linear_to_gamma[weighTwoValues(gamma_to_linear[Orgb.r], gamma_to_linear[Brgb.r], f)];
          fG = linear_to_gamma[weighTwoValues(gamma_to_linear[Orgb.g], gamma_to_linear[Brgb.g], f)];
          fB = linear_to_gamma[weighTwoValues(gamma_to_linear[Orgb.b], gamma_to_linear[Brgb.b], f)];
       } else
       {
          fR = weighTwoValues(Orgb.r, Brgb.r, f);
          fG = weighTwoValues(Orgb.g, Brgb.g, f);
          fB = weighTwoValues(Orgb.b, Brgb.b, f);
       }
       return {fB, fG, fR, Brgb.a};
    }

    // ---------- Layer swap for flip / behind mode ----------
    const bool do_swap = (flipLayers == 1 && blendMode > 0) || (blendMode == 25 && bpp == 32);
    if (do_swap)
    {
       RGBAColor tmp = Orgb;
       Orgb = Brgb;
       Brgb = tmp;
    }

    if (Orgb.a == 0)
    {
       if (keepAlpha == 1 && flipLayers == 1 && oA != -1 && (blendMode >= 1 && blendMode <= 22))
          Brgb.a = oA;
       return Brgb;
    }

    if ((Brgb.a == 0) || (Orgb.a == 255 && (blendMode == 0 || blendMode == 25))) {
       if (keepAlpha == 1 && oA != -1)
          Orgb.a = oA;
       return Orgb;
    }

    const int sa = Orgb.a;
    const int da = Brgb.a;
    const int resultA = sa + ((da * (255 - sa)) / 255);
    if (resultA == 0)
       return {0, 0, 0, 0};

    const unsigned int sa_scaled = (sa * 65536U) / resultA;
    const unsigned int da_1_sa_scaled = 65536U - sa_scaled;
    // ---------- FAST PATH: Normal blend (mode 0/25), no linear gamma ----------
    if ((blendMode == 0 || blendMode == 25) && linearGamma == 0)
    {
       int rR = (sa_scaled * Orgb.r + da_1_sa_scaled * Brgb.r + 32768U) >> 16;
       int rG = (sa_scaled * Orgb.g + da_1_sa_scaled * Brgb.g + 32768U) >> 16;
       int rB = (sa_scaled * Orgb.b + da_1_sa_scaled * Brgb.b + 32768U) >> 16;

       RGBAColor result;
       result.r = (rR < 0) ? 0 : (rR > 255) ? 255 : rR;
       result.g = (rG < 0) ? 0 : (rG > 255) ? 255 : rG;
       result.b = (rB < 0) ? 0 : (rB > 255) ? 255 : rB;
       result.a = resultA;
       if (keepAlpha == 1 && oA != -1)
          result.a = oA;
       return result;
    }

    // ---------- NEW LUT PATH for all other modes ----------
    RGBAColor result = {0, 0, 0, 0};
    const bool mix = (keepAlpha != 1 || blendMode >= 22 || blendMode < 2);
    const int blend65k = blendMode * 65536;
    if (blendMode == 20 || blendMode == 21)
    {
       // Luminosity and ghosting (scalar float fallback)
       const float* const lut = (linearGamma == 1) ? char_to_floatGamma : char_to_float;
       // the lumas are taken in the space of the channels they are added to
       const float lO = (linearGamma == 1) ? lut[Orgb.r] * 0.299701f + lut[Orgb.g] * 0.587130f + lut[Orgb.b] * 0.114180f
                                           : blend_grayscale_float(Orgb.r, Orgb.g, Orgb.b);
       const float lB = (linearGamma == 1) ? lut[Brgb.r] * 0.299701f + lut[Brgb.g] * 0.587130f + lut[Brgb.b] * 0.114180f
                                           : blend_grayscale_float(Brgb.r, Brgb.g, Brgb.b);

       float rT, gT, bT;
       if (blendMode == 20)
       {
           rT = lO + lut[Brgb.r] - lB;
           gT = lO + lut[Brgb.g] - lB;
           bT = lO + lut[Brgb.b] - lB;
       } else
       {
           rT = lB - lO + lut[Brgb.r] + lut[Orgb.r] * 0.2f;
           gT = lB - lO + lut[Brgb.g] + lut[Orgb.g] * 0.2f;
           bT = lB - lO + lut[Brgb.b] + lut[Orgb.b] * 0.2f;
       }
       
       rT = (rT < 0.0f) ? 0.0f : (rT > 1.0f ? 1.0f : rT);
       gT = (gT < 0.0f) ? 0.0f : (gT > 1.0f ? 1.0f : gT);
       bT = (bT < 0.0f) ? 0.0f : (bT > 1.0f ? 1.0f : bT);
       if (Brgb.a < 255 && mix)
       {
           float w = 1.0f - (Brgb.a / 255.0f);
           rT = w * (lut[Orgb.r] - rT) + rT;
           gT = w * (lut[Orgb.g] - gT) + gT;
           bT = w * (lut[Orgb.b] - bT) + bT;
       }

       float saF = sa / 255.0f;
       float da_1_saF = (da / 255.0f) * (1.0f - saF);
       float inv_ra = 1.0f / (saF + da_1_saF);

       rT = (saF * rT + da_1_saF * lut[Brgb.r]) * inv_ra;
       gT = (saF * gT + da_1_saF * lut[Brgb.g]) * inv_ra;
       bT = (saF * bT + da_1_saF * lut[Brgb.b]) * inv_ra;

       if (linearGamma == 1)
       {
           int iR = (int)(rT * 65535.0f + 0.5f);
           int iG = (int)(gT * 65535.0f + 0.5f);
           int iB = (int)(bT * 65535.0f + 0.5f);
           iR = (iR < 0) ? 0 : ( (iR > 65535) ? 65535 : iR);
           iG = (iG < 0) ? 0 : ( (iG > 65535) ? 65535 : iG);
           iB = (iB < 0) ? 0 : ( (iB > 65535) ? 65535 : iB);
           result.r = blend_degamma_lut[iR];
           result.g = blend_degamma_lut[iG];
           result.b = blend_degamma_lut[iB];
       } else
       {
           result.r = (int)(rT * 255.0f + 0.5f);
           result.g = (int)(gT * 255.0f + 0.5f);
           result.b = (int)(bT * 255.0f + 0.5f);
       }
    } else
    {
        // CHANNELS INDEPENDENT: modes 0-19, 22
        if (linearGamma == 0)
        {
            int idxR = blend65k + Orgb.r * 256 + Brgb.r;
            int idxG = blend65k + Orgb.g * 256 + Brgb.g;
            int idxB = blend65k + Orgb.b * 256 + Brgb.b;
            
            // the LUTs only cover modes 1..22; treat anything else as normal/pass-through
            int rT = (blendMode < 1 || blendMode > 22) ? Orgb.r : blend_lut_srgb[idxR];
            int gT = (blendMode < 1 || blendMode > 22) ? Orgb.g : blend_lut_srgb[idxG];
            int bT = (blendMode < 1 || blendMode > 22) ? Orgb.b : blend_lut_srgb[idxB];

            if (da < 255 && blendMode > 0 && mix)
            {
                rT = ((255 - da) * Orgb.r + da * rT + 127) / 255;
                gT = ((255 - da) * Orgb.g + da * gT + 127) / 255;
                bT = ((255 - da) * Orgb.b + da * bT + 127) / 255;
            }

            result.r = (sa_scaled * rT + da_1_sa_scaled * Brgb.r + 32768U) >> 16;
            result.g = (sa_scaled * gT + da_1_sa_scaled * Brgb.g + 32768U) >> 16;
            result.b = (sa_scaled * bT + da_1_sa_scaled * Brgb.b + 32768U) >> 16;
        } else
        {
            int idxR = blend65k + Orgb.r * 256 + Brgb.r;
            int idxG = blend65k + Orgb.g * 256 + Brgb.g;
            int idxB = blend65k + Orgb.b * 256 + Brgb.b;

            int o_r_lin = gamma_to_linear_16[Orgb.r];
            int o_g_lin = gamma_to_linear_16[Orgb.g];
            int o_b_lin = gamma_to_linear_16[Orgb.b];
            
            // the LUTs only cover modes 1..22; treat anything else as normal/pass-through
            int rT = (blendMode < 1 || blendMode > 22) ? o_r_lin : blend_lut_linear[idxR];
            int gT = (blendMode < 1 || blendMode > 22) ? o_g_lin : blend_lut_linear[idxG];
            int bT = (blendMode < 1 || blendMode > 22) ? o_b_lin : blend_lut_linear[idxB];

            if (da < 255 && blendMode > 0 && mix)
            {
                rT = ((255 - da) * o_r_lin + da * rT + 127) / 255;
                gT = ((255 - da) * o_g_lin + da * gT + 127) / 255;
                bT = ((255 - da) * o_b_lin + da * bT + 127) / 255;
            }

            int final_lin_r = (sa_scaled * rT + da_1_sa_scaled * gamma_to_linear_16[Brgb.r] + 32768U) >> 16;
            int final_lin_g = (sa_scaled * gT + da_1_sa_scaled * gamma_to_linear_16[Brgb.g] + 32768U) >> 16;
            int final_lin_b = (sa_scaled * bT + da_1_sa_scaled * gamma_to_linear_16[Brgb.b] + 32768U) >> 16;

            result.r = blend_degamma_lut[final_lin_r];
            result.g = blend_degamma_lut[final_lin_g];
            result.b = blend_degamma_lut[final_lin_b];
        }
    }

    result.a = resultA;
    if (keepAlpha == 1 && oA != -1)
       result.a = oA;
    return result;
}

#endif // QPV_BLEND_MODES_H
