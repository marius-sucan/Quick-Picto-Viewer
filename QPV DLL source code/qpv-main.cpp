// qpv-main.cpp : Définit les fonctions exportées de la DLL.

#define GDIPVER 0x110
#include "pch.h"
#include "framework.h"
#include <wchar.h>
#include "omp.h"
#include "math.h"
#include "windows.h"
#include <string>
#include <sstream>
#include <vector>
#include <stack>
#include <map>
#include <unordered_map>
#include <list>
#include <array>
#include <cstdint>
#include <cstdio>
#include <numeric>
#include <algorithm>
#include <wincodec.h>
#include "Tchar.h"
#include "Tpcshrd.h"
#include "qpv-main.h"
#include <gdiplus.h>
#include <gdiplusflat.h>
#include <locale.h>
#include <codecvt>
#include <corecrt_io.h>
#include <direct.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include "Jpeg2PDF.h"
#include "Jpeg2PDF.cpp"
// #define cimg_plugin "include\gmic-master\gmic.cpp";
#define cimg_use_openmp 1
#include "include\CImg-3.1.4\CImg.h"
// #include "include\CImg-master\CImg.h"
// #include "include\gmic-master\gmic.h"
// #include "include\CImg-master\gmic.h"
// #include "include\CImg-master\gmic.cpp"
// #include "include\gmic-master\gmic.cpp"
// #include <Magick++.h>
// #include <include\vips\vips8>
// #include <bits/stdc++.h>
using namespace std;
using namespace cimg_library;

void fnOutputDebug(std::string input) {
    std::stringstream ss;
    ss << "qpv: " << input;
    OutputDebugStringA(ss.str().data());
}

/*
Function written with help provided by Spawnova. Thank you very much.
pBitmap and pBitmapMask must be the same width and height
and in 32-ARGB format: PXF32ARGB - 0x26200A.

The alpha channel will be applied directly on the pBitmap provided.

For best results, pBitmapMask should be grayscale.
*/

DLL_API int DLL_CALLCONV SetAlphaChannel(int *imageData, int *maskData, int w, int h, int invert, int replaceAlpha, int whichChannel, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int x = 0; x < w; x++)
    {
        int px;
        unsigned char alpha, alpha2, a;
        for (int y = 0; y < h; y++)
        {
            px = x + y * w;
            if (whichChannel==2)
               alpha = (maskData[px] >> 8) & 0xFF; // green
            else if (whichChannel==3)
               alpha = (maskData[px] >> 0) & 0xFF; // blue
            else if (whichChannel==4)
               alpha = (maskData[px] >> 24) & 0xFF; // alpha
            else
               alpha = (maskData[px] >> 16) & 0xFF; // red

            if (replaceAlpha!=1)
            {
               if (invert == 1)
                  alpha = 255 - alpha;
               a = (imageData[px] >> 24) & 0xFF;
               alpha2 = min(alpha, a);    // handles bitmaps that already have alpha
            }
            else {
               alpha2 = (invert == 1) ? 255 - alpha : alpha;
            }

            imageData[px] = (alpha2 << 24) | (imageData[px] & 0x00ffffff);
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV SetColorAlphaChannel(int *imageData, int w, int h, int newColor, int invert) {
    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            int px = x + y * w;
            unsigned char alpha1 = (imageData[px] >> 16) & 0xFF; // red
            alpha1 = (invert==1) ? 255 - alpha1 : alpha1;
            unsigned char alpha2 = (newColor >> 24) & 0xFF; // alpha
            // imageData[px] = newColor;
            imageData[px] = (min(alpha1,alpha2) << 24) | (newColor & 0x00ffffff);
        }
    }
    return 1;
}


int inline INTweighTwoValues(int A, int B, float w) {
    return (float)(A * w + B * (1.0 - w));
}

float inline weighTwoValues(float A, float B, float w) {
    return (A*w + B*(1.0 - w));
}

double inverseGamma(double X) {
  // Inverse sRGB gamma correction
  if (X>0.0404482362771076)
     X = pow((X + 0.055)/1.055, 2.4);
  else
     X = X / 12.92;

  return X;
}

double toLABf(double Y) {
  if (Y >= 0.00885645167903563082e-3)
     Y = pow(Y, 0.333333333333333);  // 1/3
  else
     Y = (841.0/108.0) * Y + (4.0/29.0);

  return Y;
}

double toLABfx(double Y) {
  if (Y >= 8.88564517)
     Y = pow(Y, 0.3333333);  // 1/3
  else
     Y = 7.7870370 * Y + 0.1379310; // (841.0/108.0) * Y + ( 4.0 / 29.0 );

  return Y;
}

double deg2rad(double degree) {
    // convert degree to radian
    const double p = M_PI / 180.0;
    return (degree * p);
}

double rad2deg(double radian) {
    // convert radian to degree
    const double p = 180.0 / M_PI;
    return (radian * p);
}

int fastRGBtoGray(int n) {
   return (((n&0xf0f0f0)*0x20a05)>>20)&255;
   // return (n&0xf0f0f0)*133637>>20&255;
}

int RGBtoGray(int sR, int sG, int sB, int alternateMode) {
  // https://getreuer.info/posts/colorspace/index.html
  // http://www.easyrgb.com/en/math.php
  // sR, sG and sB (Standard RGB) input range = 0 ÷ 255
  // X, Y and Z output refer to a D65/2° standard illuminant.
  // return value is L* - Luminance from L*ab, based on D65 luminant

  if (alternateMode==1)
     return round((float)(sR*0.299f + sG*0.587f + sB*0.114f)); // weighted grayscale conversion

  // convert RGB to XYZ color space
  double var_R = (float)sR/255.0;
  double var_G = (float)sG/255.0;
  double var_B = (float)sB/255.0;

  // Inverse sRGB gamma correction
  var_R = inverseGamma(var_R);
  var_G = inverseGamma(var_G);
  var_B = inverseGamma(var_B);

  double Y = var_R * 0.2125862 + var_G * 0.7151704 + var_B * 0.0722005;
  // if (alternateMode==2)
  //    return round(Y); // return derived luminosity in XYZ color space

  Y = toLABfx(Y);
  double L = 116.0*Y - 16.0;
  // if (L>499)
  //     L = 499;
  // else if (L<0)
  //     L = 1;
  // https://zschuessler.github.io/DeltaE/demos/
  return round(L/2); // return derived luminosity in pseudo-LAB color space
}

double CieLab2Hue(double var_a, double var_b ) {
// Function returns CIE-H° value
   double var_bias = 0;
   if ( var_a >= 0 && var_b == 0 ) return 0;
   if ( var_a <  0 && var_b == 0 ) return 180;
   if ( var_a == 0 && var_b >  0 ) return 90;
   if ( var_a == 0 && var_b <  0 ) return 270;
   if ( var_a >  0 && var_b >  0 ) var_bias = 0;
   if ( var_a <  0               ) var_bias = 180;
   if ( var_a >  0 && var_b <  0 ) var_bias = 360;
   return ( rad2deg( atan( var_b / var_a ) ) + var_bias );
}

float testCIEdeltaE2000(double Lab1_L, double Lab1_a, double Lab1_b, double Lab2_L, double Lab2_a, double Lab2_b, float k_L, float k_C, float k_H) {
// Cl_1,  Ca_1,  Cb_1   - Color #1 CIE-L*ab values
// Cl_2,  Ca_2,  Cb_2   - Color #2 CIE-L*ab values
// WHT_L, WHT_C, WHT_H  - Weight factors: luminance, chroma and hue
// https://github.com/tajmone/name-that-color/blob/master/ntc.color-funcs.pbi

    double LBar, deltaLPrime, aPrime1, aPrime2;
    double C1, C2, CPrime1, CPrime2, CBar, CBarPrime, deltaCPrime;
    double hPrime1, hPrime2, HBarPrime, deltahPrime;
    double SsubL, SsubC, SsubH, RsubC, RsubT;
    double g, Tvar, deltaRO, deltaE00;

    LBar      = (Lab1_L + Lab2_L) / 2;
    C1        = sqrt(pow(Lab1_a, 2) + pow(Lab1_b, 2));
    C2        = sqrt(pow(Lab2_a, 2) + pow(Lab2_b, 2));
    CBar      = (C1 + C2) / 2;
    g = (1 - sqrt(pow(CBar, 7) / (pow(CBar, 7) + pow(25, 7)))) / 2;
    aPrime1   = Lab1_a * (1 + g);
    aPrime2   = Lab2_a * (1 + g);
    CPrime1   = sqrt(pow(aPrime1, 2) + pow(Lab1_b, 2));
    CPrime2   = sqrt(pow(aPrime2, 2) + pow(Lab2_b, 2));
    CBarPrime = (CPrime1 + CPrime2) / 2;

    hPrime1 = rad2deg(atan2(aPrime1, Lab1_b));
    if (hPrime1<0)
       hPrime1 += 360;

    hPrime2 = rad2deg(atan2(aPrime2, Lab2_b));
    if (hPrime2 < 0)
       hPrime2 += 360;

    if (abs(hPrime1 - hPrime2) > 180)
       HBarPrime = (hPrime1 + hPrime2 + 360) / 2;
    else
       HBarPrime = (hPrime1 + hPrime2) / 2;

    Tvar = 1 - 0.17 * cos(deg2rad(HBarPrime - 30)) + 0.24 * cos(deg2rad(2 * HBarPrime)) + 0.32 * cos(deg2rad(3 * HBarPrime + 6)) - 0.2 * cos(deg2rad(4 * HBarPrime - 63));

    deltahPrime = hPrime2 - hPrime1;
    if (abs(deltahPrime) > 180)
    {
       if (hPrime2 <= hPrime1) 
          deltahPrime += 360;
       else 
          deltahPrime -= 360;
    }

    deltaLPrime = Lab2_L - Lab1_L;
    deltaCPrime = CPrime2 - CPrime1;
    deltahPrime = 2 * sqrt(CPrime1 * CPrime2) * sin(deg2rad(deltahPrime) / 2);
    SsubL = 1 + ((0.015 * pow(LBar - 50, 2)) / sqrt(20 + pow(LBar - 50, 2)));
    SsubC = 1 + 0.045 * CBarPrime;
    SsubH = 1 + 0.015 * CBarPrime * Tvar;

    // compute R sub T (RT)
    deltaRO = 30 * exp(-(pow((HBarPrime - 275) / 25, 2)));
    RsubC = 2 * sqrt(pow(CBarPrime, 7) / (pow(CBarPrime, 7) + pow(25, 7)));
    RsubT = -RsubC * sin(2 * deg2rad(deltaRO));

    deltaE00 = sqrt(pow(deltaLPrime / (SsubL * k_L), 2) + pow(deltaCPrime / (SsubC * k_C), 2) + pow(deltahPrime / (SsubH * k_H), 2) + RsubT * (deltaCPrime / (SsubC * k_C)) * (deltahPrime / (SsubH * k_H)));


    // std::stringstream ss;
    // ss << "qpv: deltaE00=" << deltaE00;
    // ss << " Lab1_L=" << Lab1_L;
    // ss << " Lab1_a=" << Lab1_a;
    // ss << " Lab1_b=" << Lab1_b;
    // ss << " Lab2_L=" << Lab2_L;
    // ss << " Lab2_a=" << Lab2_a;
    // ss << " Lab2_b=" << Lab2_b;
    // ss << " k_L=" << k_L;
    // ss << " k_C=" << k_C;
    // ss << " k_H=" << k_H;
    // ss << " LBar=" << LBar;
    // ss << " deltaLPrime=" << deltaLPrime;
    // ss << " aPrime1=" << aPrime1;
    // ss << " aPrime2=" << aPrime2;
    // ss << " C1=" << C1;
    // ss << " C2=" << C2;
    // ss << " CPrime1=" << CPrime1;
    // ss << " CPrime2=" << CPrime2;
    // ss << " CBar=" << CBar;
    // ss << " CBarPrime=" << CBarPrime;
    // ss << " deltaCPrime=" << deltaCPrime;
    // ss << " hPrime1=" << hPrime1;
    // ss << " hPrime2=" << hPrime2;
    // ss << " HBarPrime=" << HBarPrime;
    // ss << " deltahPrime=" << deltahPrime;
    // ss << " SsubL=" << SsubL;
    // ss << " SsubC=" << SsubC;
    // ss << " SsubH=" << SsubH;
    // ss << " RsubC=" << RsubC;
    // ss << " RsubT=" << RsubT;
    // ss << " g=" << g;
    // ss << " Tvar=" << Tvar;
    // ss << " deltaRO=" << deltaRO;
    // OutputDebugStringA(ss.str().data());

    return deltaE00;
}

float CIEdeltaE2000(double Cl_1, double Ca_1, double Cb_1, double Cl_2, double Ca_2, double Cb_2, float WHT_L, float WHT_C, float WHT_H) {
// Cl_1,  Ca_1,  Cb_1   - Color #1 CIE-L*ab values
// Cl_2,  Ca_2,  Cb_2   - Color #2 CIE-L*ab values
// WHT_L, WHT_C, WHT_H  - Weight factors: luminance, chroma and hue
// tested against http://www.brucelindbloom.com/index.html?ColorDifferenceCalc.html
// https://getreuer.info/posts/colorspace/index.html
// http://www.easyrgb.com/en/math.php
// https://zschuessler.github.io/DeltaE/demos/

  double xC1 = sqrt( pow(Ca_1, 2) + pow(Cb_1, 2) );
  double xC2 = sqrt( pow(Ca_2, 2) + pow(Cb_2, 2) );
  double xCX = ( xC1 + xC2 ) / 2;   // C-bar

  double xGX = 0.5 * ( 1 - sqrt( pow(xCX,7) / ( pow(xCX,7) + pow(25,7) ) ) );

  double xNN = ( 1 + xGX ) * Ca_1;            // A-Prime 1
  xC1 = sqrt( pow(xNN, 2) + pow(Cb_1, 2) );   // C-Prime 1
  double xH1 = CieLab2Hue( xNN, Cb_1 );       // H-Prime 1
 
  xNN = ( 1 + xGX ) * Ca_2;                   // A-Prime 2
  xC2 = sqrt( pow(xNN, 2) + pow(Cb_2, 2) );   // C-Prime 2
  double xH2 = CieLab2Hue( xNN, Cb_2 );       // H-Prime 2

  // compute Delta H-Prime based on H-Primes
  double xDH; 
  if ( ( xC1 * xC2 ) == 0 ) {
     xDH = 0;
  }
  else {
     xNN = xH2 - xH1;   // the diff between the H-Primes
     if ( abs( xNN ) <= 180 ) {
        xDH = xNN;
     }
     else {
        if ( xNN > 180 )         // if (hPrime2 <= hPrime1) ???
           xDH = xNN - 360;
        else
           xDH = xNN + 360;
     }
  }

  xDH = 2 * sqrt( xC1 * xC2 ) * sin( deg2rad( xDH / 2 ) ); // Delta H-Prime

  double xHX;  // compute the H-Bar Prime
  if ( ( xC1 *  xC2 ) == 0 ) {
     xHX = xH1 + xH2;
  }
  else {
     xNN = abs(xH1 - xH2);
     if ( xNN > 180 ) {
        if ( ( xH2 + xH1 ) < 360 )
           xHX = xH1 + xH2 + 360;
        else
           xHX = xH1 + xH2 - 360;
     }
     else {
        xHX = xH1 + xH2;
     }
     xHX /= 2; // the H-Bar Prime
  }

  // xTX, the T variable, based on H-Bar Prime
  double xTX = 1 - 0.17 * cos( deg2rad(xHX - 30) )     + 0.24
                        * cos( deg2rad(2 * xHX ) )     + 0.32
                        * cos( deg2rad(3 * xHX + 6 ) ) - 0.20
                        * cos( deg2rad(4 * xHX - 63) );

  double xCY = ( xC1 + xC2 ) / 2;        // C-Bar Prime based on C-Primes

  // compute R sub T
  double xPH = 60 * exp( - ( pow( ( xHX  - 275 ) / 25, 2) ) );           // based on H-Bar Prime
  double xRC = 2 * sqrt( pow(xCY, 7) / ( pow(xCY, 7) + pow(25, 7) ) );   // based on C-Bar Prime
  double xRT = - sin( deg2rad(xPH) ) * xRC;  // R sub T

  double xLX = ( Cl_1 + Cl_2 ) / 2 - 50; // L-Bar
  double xSL = 1 + ( 0.015 * pow(xLX, 2) ) / sqrt( 20 + pow(xLX, 2) );   // S sub L based on L-Bar
  double xSC = 1 + 0.045 * xCY;       // S sub C - based on C-Bar Prime
  double xSH = 1 + 0.015 * xCY * xTX; // S sub H - based on C-Bar Prime and T-var

  double xDL = Cl_2 - Cl_1;              // Delta L-Prime
  double xDC = xC2 - xC1;                // Delta C-Prime based on C-Primes
  xDL = xDL / ( WHT_L * xSL );
  xDC = xDC / ( WHT_C * xSC );
  xDH = xDH / ( WHT_H * xSH );

  double DeltaE = sqrt(pow(xDL, 2) + pow(xDC, 2) + pow(xDH, 2) + xRT * xDC * xDH);
  return DeltaE;
}

auto RGBtoLAB(int sR, int sG, int sB) {
  // https://getreuer.info/posts/colorspace/index.html
  // http://www.easyrgb.com/en/math.php
  // sR, sG and sB (Standard RGB) input range = 0 ÷ 255
  // X, Y and Z outputs refer to a D65/2° standard illuminant.
  // https://zschuessler.github.io/DeltaE/demos/
  // tested against ColorMine.org

  // convert RGB to XYZ color space
  double var_R = (double)sR/255.0;
  double var_G = (double)sG/255.0;
  double var_B = (double)sB/255.0;

  // Inverse sRGB gamma correction
  var_R = inverseGamma(var_R);
  var_G = inverseGamma(var_G);
  var_B = inverseGamma(var_B);

  var_R = var_R * 100;
  var_G = var_G * 100;
  var_B = var_B * 100;

  // compute XYZ color space values for given sRGB
  double X = var_R * 0.4123955889674142161 + var_G * 0.3575834307637148171 + var_B * 0.1804926473817015735;
  double Y = var_R * 0.2125862307855955516 + var_G * 0.7151703037034108499 + var_B * 0.07220049864333622685;
  double Z = var_R * 0.01929721549174694484 + var_G * 0.1191838645808485318 + var_B * 0.9504971251315797660;
  // std::stringstream ss;
  // ss << "qpv: color in XYZ - X=" << X;
  // ss << " Y=" << Y;
  // ss << " Z=" << Z;

  // compute XYZ according to the D65 reference illuminant specific to Daylight, sRGB and Adobe-RGB
  X /= 95.047;
  Y /= 100.000;
  Z /= 108.883;

  X = toLABf(X);
  Y = toLABf(Y);
  Z = toLABf(Z);

  std::array<double, 3> Lab;
  Lab[0] = 116*Y - 16;
  Lab[1] = 500*(X - Y);
  Lab[2] = 200*(Y - Z);

  // ss << " | in LAB - L=" << Lab[0];
  // ss << " a=" << Lab[1];
  // ss << " b=" << Lab[2];
  // OutputDebugStringA(ss.str().data());
  return Lab;
}


HSLColor ConvertRGBtoHSL(float iR, float iG, float iB, int isFloat) {
   double R = (isFloat==1) ? iR : (iR / 255.0f);
   double G = (isFloat==1) ? iG : (iG / 255.0f);
   double B = (isFloat==1) ? iB : (iB / 255.0f);
   double minu    = min(R, min(G, B));
   double maxu    = max(R, max(G, B));
   double del_Max = maxu - minu;
   double L       = (maxu + minu) / 2.0f;
   // fnOutputDebug(std::to_string(R) + " / " + std::to_string(G) + " / " + std::to_string(B));
   // fnOutputDebug(std::to_string(del_Max) + " mi/ma:" + std::to_string(minu) + " / " + std::to_string(maxu));
   double H, S, del_R, del_G, del_B;
   if (del_Max == 0)
   {
      H = S = 0;
   } else
   {
      if (L < 0.5)
         S = del_Max / (maxu + minu);
      else
         S = del_Max / (2.0f - del_Max);

      del_R = (((maxu - R) / 6.0f) + (del_Max / 2.0f)) / del_Max;
      del_G = (((maxu - G) / 6.0f) + (del_Max / 2.0f)) / del_Max;
      del_B = (((maxu - B) / 6.0f) + (del_Max / 2.0f)) / del_Max;
      if (R == maxu)
      {
         H = del_B - del_G;
      } else
      {
         if (G == maxu)
            H = (1.0f / 3.0f) + del_R - del_B;
         else if (B == maxu)
            H = (2.0f / 3.0f) + del_G - del_R;
      }
      if (H < 0)
         H += 1.0f;
      if (H > 1)
         H -= 1.0f;
   }

   H = abs(H*360.0f);
   S = abs(S);
   L = abs(L);
   return {H, S, L};
}

double ConvertHueToRGB(double v1, double v2, double vH) {
   vH = ((vH<0) ? ++vH : vH);
   vH = ((vH>1) ? --vH : vH);
   return ((6.0f * vH) < 1) ? (v1 + (v2 - v1) * 6.0f * vH)
          : ((2.0f * vH) < 1) ? (v2)
          : ((3.0f * vH) < 2) ? (v1 + (v2 - v1) * ((2.0f / 3.0f) - vH) * 6.0f)
          : v1;
}

RGBColor ConvertHSLtoRGB(double H, double S, double L) {
// http://www.had2know.com/technology/hsl-rgb-color-converter.html

   H = H/360.0f;
   double var_1, var_2, R, G, B;

   if (S == 0)
   {
      R = L*255.0f;
      G = L*255.0f;
      B = L*255.0f;
   } else
   {
      if (L < 0.5)
         var_2 = L * (1.0f + S);
      else
         var_2 = (L + S) - (S * L);

      var_1 = 2.0f * L - var_2;
      R = 255.0f * ConvertHueToRGB(var_1, var_2, H + (1.0f / 3.0f));
      G = 255.0f * ConvertHueToRGB(var_1, var_2, H);
      B = 255.0f * ConvertHueToRGB(var_1, var_2, H - (1.0f / 3.0f));
   }
   return {R, G, B};
}

DLL_API int DLL_CALLCONV testHSLrgbConv(int rOh, int gOs, int bOl) {
  fnOutputDebug("yahoos");

  HSLColor hslO = ConvertRGBtoHSL(rOh, gOs, bOl, 0);
  fnOutputDebug("HSL: " + std::to_string(hslO.h) + " / " + std::to_string(hslO.s) + " / " + std::to_string(hslO.l) ); 
 
  RGBColor r = ConvertHSLtoRGB(hslO.h, hslO.s, hslO.l);
  fnOutputDebug("RGB: " + std::to_string(r.r) + " / " + std::to_string(r.g) + " / " + std::to_string(r.b) ); 
  return 1;
}

void calculateBlendModes(int rO, int gO, int bO, int rB, int gB, int bB, int blendMode, int *results) {
    float rT = 0;
    float gT = 0;
    float bT = 0;
    float rOf = char_to_float[rO];
    float gOf = char_to_float[gO];
    float bOf = char_to_float[bO];
    float rBf = char_to_float[rB];
    float gBf = char_to_float[gB];
    float bBf = char_to_float[bB];

    if (blendMode == 1) { // darken
        rT = min(rOf, rBf);
        gT = min(gOf, gBf);
        bT = min(bOf, bBf);
    }
    else if (blendMode == 2) { // multiply
        rT = rOf * rBf;
        gT = gOf * gBf;
        bT = bOf * bBf;
    }
    else if (blendMode == 3) { // linear burn
       rT = rOf + rBf - 1;
       gT = gOf + gBf - 1;
       bT = bOf + bBf - 1;
    }
    else if (blendMode == 4) { // color burn
       rT = 1 - ((1 - rBf) / rOf);
       gT = 1 - ((1 - gBf) / gOf);
       bT = 1 - ((1 - bBf) / bOf);
    }
    else if (blendMode == 5) { // lighten
        rT = max(rOf, rBf);
        gT = max(gOf, gBf);
        bT = max(bOf, bBf);
    }
    else if (blendMode == 6) { // screen
        rT = 1 - ( (1 - rBf) * (1 - rOf) );
        gT = 1 - ( (1 - gBf) * (1 - gOf) );
        bT = 1 - ( (1 - bBf) * (1 - bOf) );
    }
    else if (blendMode == 7) { // linear dodge [add]
        rT = rOf + rBf;
        gT = gOf + gBf;
        bT = bOf + bBf;
    }
    else if (blendMode == 8) { // hard light
        rT = (rOf < 0.5) ? 2 * rOf * rBf : 1 - (2 * (1 - rOf) * (1 - rBf) );
        gT = (gOf < 0.5) ? 2 * gOf * gBf : 1 - (2 * (1 - gOf) * (1 - gBf) );
        bT = (bOf < 0.5) ? 2 * bOf * bBf : 1 - (2 * (1 - bOf) * (1 - bBf) );
    }
    // else if (blendMode == 9) { // soft light A
    //     rT = (1 - 2*rOf) * pow(rBf, 2) + 2 * rOf * rBf;
    //     gT = (1 - 2*gOf) * pow(gBf, 2) + 2 * gOf * gBf;
    //     bT = (1 - 2*bOf) * pow(bBf, 2) + 2 * bOf * bBf;
    // }
    else if (blendMode == 9) { // soft light B
        rT = (rOf < 0.5) ? (1 - 2*rOf) * pow(rBf, 2) + 2 * rBf * rOf : 2 * rBf * (1 - rOf) + sqrt(rBf) * (2 * rOf - 1);
        gT = (gOf < 0.5) ? (1 - 2*gOf) * pow(gBf, 2) + 2 * gBf * gOf : 2 * gBf * (1 - gOf) + sqrt(gBf) * (2 * gOf - 1);
        bT = (bOf < 0.5) ? (1 - 2*bOf) * pow(bBf, 2) + 2 * bBf * bOf : 2 * bBf * (1 - bOf) + sqrt(bBf) * (2 * bOf - 1);
    }
    else if (blendMode == 10) { // overlay
        rT = (rBf < 0.5) ? 2 * rOf * rBf : 1 - (2 * (1 - rOf) * (1 - rBf) );
        gT = (gBf < 0.5) ? 2 * gOf * gBf : 1 - (2 * (1 - gOf) * (1 - gBf) );
        bT = (bBf < 0.5) ? 2 * bOf * bBf : 1 - (2 * (1 - bOf) * (1 - bBf) );
    }
    else if (blendMode == 11) { // hard mix
        rT = (rOf <= (1 - rBf)) ? 0 : 1;
        gT = (gOf <= (1 - gBf)) ? 0 : 1;
        bT = (bOf <= (1 - bBf)) ? 0 : 1;
    }
    else if (blendMode == 12) { // linear light
        rT = rBf + (2 * rOf) - 1;
        gT = gBf + (2 * gOf) - 1;
        bT = bBf + (2 * bOf) - 1;
    }
    else if (blendMode == 13) { // color dodge
        rT = rBf / (1 - rOf);
        gT = gBf / (1 - gOf);
        bT = bBf / (1 - bOf);
    }
    else if (blendMode == 14) { // vivid light 
        // this blend mode combines Color Dodge and Color Burn (rescaled so that neutral colors become middle gray). Dodge applies when values in the top layer are lighter than middle gray, and burn applies to darker values
        if (rOf < 0.5)
           rT = 1 - (1 - rBf) / (2 * rOf);
        else
           rT = rBf / (2 * (1 - rOf));

        if (gOf < 0.5)
           gT = 1 - (1 - gBf) / (2 * gOf);
        else
           gT = gBf / (2 * (1 - gOf));

        if (bOf < 0.5)
           bT = 1 - (1 - bBf) / (2 * bOf);
        else
           bT = bBf / (2 * (1 - bOf));
    }
    else if (blendMode == 15) { // average
        rT = (rBf + rOf)/2;
        gT = (gBf + gOf)/2;
        bT = (bBf + bOf)/2;
    }
    else if (blendMode == 16) { // divide
        rT = rBf / rOf;
        gT = gBf / gOf;
        bT = bBf / bOf;
    }
    else if (blendMode == 17) { // exclusion
        rT = rOf + rBf - 2 * (rOf * rBf);
        gT = gOf + gBf - 2 * (gOf * gBf);
        bT = bOf + bBf - 2 * (bOf * bBf);
    }
    else if (blendMode == 18) { // difference
        rT = abs(rBf - rOf);
        gT = abs(gBf - gOf);
        bT = abs(bBf - bOf);
    }
    else if (blendMode == 19) { // substract
        rT = rBf - rOf;
        gT = gBf - gOf;
        bT = bBf - bOf;
    }
    else if (blendMode == 20) { // luminosity
        double lO = (rO*0.2997f + gO*0.58713f + bO*0.11418f)/255.0f;
        double lB = (rB*0.2997f + gB*0.58713f + bB*0.11418f)/255.0f;
        rT = lO + rBf - lB;
        gT = lO + gBf - lB;
        bT = lO + bBf - lB;

        // HSLColor hslO = ConvertRGBtoHSL(rOf, gOf, bOf, 1);
        // HSLColor hslB = ConvertRGBtoHSL(rBf, gBf, bBf, 1);
        // // RGBColor rgbf = ConvertHSLtoRGB(hslB.h, hslB.s, hslB.l);
        // RGBColor rgbf = ConvertHSLtoRGB(hslO.h, hslO.s, hslO.l);
        // rT = rgbf.r/255.0f;
        // gT = rgbf.g/255.0f;
        // bT = rgbf.b/255.0f;
    }
    else if (blendMode == 21) { // ghosting
        double lO = (rO*0.2997f + gO*0.58713f + bO*0.11418f)/255.0f;
        double lB = (rB*0.2997f + gB*0.58713f + bB*0.11418f)/255.0f;
        rT = lB - lO + rBf + rOf/5;
        gT = lB - lO + gBf + gOf/5;
        bT = lB - lO + bBf + bOf/5;
    }
    // else if (blendMode == 22) { // substract reverse
    //     rT = rOf - rBf;
    //     gT = gOf - gBf;
    //     bT = bOf - bBf;
    // }
    else if (blendMode == 22) { // inverted difference
        rT = (rOf > rBf) ? 1 - rOf - rBf : 1 - rBf - rOf;
        gT = (gOf > gBf) ? 1 - gOf - gBf : 1 - gBf - gOf;
        bT = (bOf > bBf) ? 1 - bOf - bBf : 1 - bBf - bOf;
    }

    rT = clamp(rT, 0.0f, 1.0f);
    gT = clamp(gT, 0.0f, 1.0f);
    bT = clamp(bT, 0.0f, 1.0f); 

    results[0] = clamp((int)round(rT*255), 0, 255);
    results[1] = clamp((int)round(gT*255), 0, 255);
    results[2] = clamp((int)round(bT*255), 0, 255);
}

void toCMYK(float red, float green, float blue, float* cmyk) {
  float k = min(255-red, min(255-green,255-blue));
  float c = 255*(255-red-k)/(255-k); 
  float m = 255*(255-green-k)/(255-k); 
  float y = 255*(255-blue-k)/(255-k); 

  cmyk[0] = c;
  cmyk[1] = m;
  cmyk[2] = y;
  cmyk[3] = k;
}

void toRGB(float c, float m, float y, float k, float *rgb) {
  rgb[0] = -((c * (255.0 - k)) / 255.0 + k - 255.0);
  rgb[1] = -((m * (255.0 - k)) / 255.0 + k - 255.0);
  rgb[2] = -((y * (255.0 - k)) / 255.0 + k - 255.0);
}

int mixColors(int colorB, float *colorA, float f, int dynamicOpacity, int blendMode, float prevCLRindex, float tolerance, int alternateMode, float thisCLRindex, int linearGamma) {
// source https://stackoverflow.com/questions/10139833/adding-colours-colors-together-like-paint-blue-yellow-green-etc
// http://www.easyrgb.com/en/math.php
 
  int aB = (colorB >> 24) & 0xFF;
  int rB = (colorB >> 16) & 0xFF;
  int gB = (colorB >> 8) & 0xFF;
  int bB = colorB & 0xFF;
  int aO = colorA[0];
  int rO = colorA[1];
  int gO = colorA[2];
  int bO = colorA[3];

  int aBf, rBf, gBf, bBf, aOf, rOf, gOf, bOf;
  aBf = (linearGamma==1) ? gamma_to_linear[aB] : aB;
  rBf = (linearGamma==1) ? gamma_to_linear[rB] : rB;
  gBf = (linearGamma==1) ? gamma_to_linear[gB] : gB;
  bBf = (linearGamma==1) ? gamma_to_linear[bB] : bB;
  aOf = (linearGamma==1) ? gamma_to_linear[aO] : aO;
  rOf = (linearGamma==1) ? gamma_to_linear[rO] : rO;
  gOf = (linearGamma==1) ? gamma_to_linear[gO] : gO;
  bOf = (linearGamma==1) ? gamma_to_linear[bO] : bO;

  float fz;
  if (dynamicOpacity==1)
  {
     // int thisCLRindex = float(rB*0.299 + gB*0.587 + bB*0.115);
     // float thisCLRindex = RGBtoGray(rB, gB, bB, alternateMode);
     if (alternateMode==3)
     {
        fz = (float)thisCLRindex/tolerance;
     } else 
     {
        float diffu = max(thisCLRindex, prevCLRindex) - min(thisCLRindex, prevCLRindex);
        fz = (float)diffu/tolerance;
     }
     f = f - fz;
     if (f<0)
        f = 0;
  }

  if (blendMode>0)
  {
     int results[3];
     calculateBlendModes(rO, gO, bO, rB, gB, bB, blendMode, results);
     rOf = (linearGamma==1) ? gamma_to_linear[results[0]] : results[0];
     gOf = (linearGamma==1) ? gamma_to_linear[results[1]] : results[1];
     bOf = (linearGamma==1) ? gamma_to_linear[results[2]] : results[2];
  }

  int aT = INTweighTwoValues(aOf, aBf, f);
  int rT = INTweighTwoValues(rOf, rBf, f);
  int gT = INTweighTwoValues(gOf, gBf, f);
  int bT = INTweighTwoValues(bOf, bBf, f);
  if (linearGamma==1)
  {
     aT = linear_to_gamma[aT];
     rT = linear_to_gamma[rT];
     gT = linear_to_gamma[gT];
     bT = linear_to_gamma[bT];
  }

    // std::stringstream ss;
    // ss << "qpv: opacity = " << f;
    // ss << " rA=" << rA;
    // ss << "rB=" << rB;
    // ss << "rT=" << rT;
    // ss << " | gA=" << gA;
    // ss << "gB=" << gB;
    // ss << "gT=" << gT;
    // // ss << " r = " << result;
    // OutputDebugStringA(ss.str().data());

  return (aT << 24) | ((rT & 0xFF) << 16) | ((gT & 0xFF) << 8) | (bT & 0xFF);
}

int simpleMixColors(int colorB, float *colorA, float f, int blendMode, int linearGamma, int flipLayers) {
// source https://stackoverflow.com/questions/10139833/adding-colours-colors-together-like-paint-blue-yellow-green-etc
// http://www.easyrgb.com/en/math.php
 
  int aB = (colorB >> 24) & 0xFF;
  int rB = (colorB >> 16) & 0xFF;
  int gB = (colorB >> 8) & 0xFF;
  int bB = colorB & 0xFF;
  int aO = colorA[0];
  int rO = colorA[1];
  int gO = colorA[2];
  int bO = colorA[3];
  int aBf, rBf, gBf, bBf, aOf, rOf, gOf, bOf;
  aBf = (linearGamma==1) ? gamma_to_linear[aB] : aB;
  rBf = (linearGamma==1) ? gamma_to_linear[rB] : rB;
  gBf = (linearGamma==1) ? gamma_to_linear[gB] : gB;
  bBf = (linearGamma==1) ? gamma_to_linear[bB] : bB;
  aOf = (linearGamma==1) ? gamma_to_linear[aO] : aO;
  rOf = (linearGamma==1) ? gamma_to_linear[rO] : rO;
  gOf = (linearGamma==1) ? gamma_to_linear[gO] : gO;
  bOf = (linearGamma==1) ? gamma_to_linear[bO] : bO;

  if (blendMode>0)
  {
     int results[3];
     if (flipLayers==1)
        calculateBlendModes(rB, gB, bB, rO, gO, bO, blendMode, results);
     else
        calculateBlendModes(rO, gO, bO, rB, gB, bB, blendMode, results);

     rOf = (linearGamma==1) ? gamma_to_linear[results[0]] : results[0];
     gOf = (linearGamma==1) ? gamma_to_linear[results[1]] : results[1];
     bOf = (linearGamma==1) ? gamma_to_linear[results[2]] : results[2];
  }

  int aT = INTweighTwoValues(aOf, aBf, f);
  int rT = INTweighTwoValues(rOf, rBf, f);
  int gT = INTweighTwoValues(gOf, gBf, f);
  int bT = INTweighTwoValues(bOf, bBf, f);
  if (linearGamma==1)
  {
     aT = linear_to_gamma[aT];
     rT = linear_to_gamma[rT];
     gT = linear_to_gamma[gT];
     bT = linear_to_gamma[bT];
  }

    // std::stringstream ss;
    // ss << "qpv: opacity = " << f;
    // ss << " rA=" << rA;
    // ss << "rB=" << rB;
    // ss << "rT=" << rT;
    // ss << " | gA=" << gA;
    // ss << "gB=" << gB;
    // ss << "gT=" << gT;
    // // ss << " r = " << result;
    // OutputDebugStringA(ss.str().data());

  return (aT << 24) | ((rT & 0xFF) << 16) | ((gT & 0xFF) << 8) | (bT & 0xFF);
}

bool inline inRange(float low, float high, float x) {        
    return (low <= x && x <= high);
}

bool decideColorsEqual(int newColor, int oldColor, float tolerance, float prevCLRindex, int alternateMode, float *nC, float& index) {
    // should use , CIEDE2000
    if (oldColor==newColor)
       return 1;
    else if (tolerance<1)
       return 0;

    // int aB = (newColor >> 24) & 0xFF;
    int rB = (newColor >> 16) & 0xFF;
    int gB = (newColor >> 8) & 0xFF;
    int bB = newColor & 0xFF;
    bool result;
    // float index;
    // int index = float(rB*0.299 + gB*0.587 + bB*0.115);
    if (alternateMode==3)
    {
       // auto LabA = RGBtoLAB(nC[1], nC[2], nC[3]);
       auto LabB = RGBtoLAB(rB, gB, bB);
       index = CIEdeltaE2000(nC[4], nC[5], nC[6], LabB[0], LabB[1], LabB[2], 1, 1, 1);
       result = (index<=tolerance) ? 1 : 0;
    } else
    {
       index = RGBtoGray(rB, gB, bB, alternateMode);
       result = inRange(index - tolerance, index + tolerance, prevCLRindex);
    }
    return result;
}

int wrapRGBtoGray(int color, int mode) {
    int rB = (color >> 16) & 0xFF;
    int gB = (color >> 8) & 0xFF;
    int bB = color & 0xFF;
    int index = RGBtoGray(rB, gB, bB, mode);
    return index;
}

int FloodFill8Stack(int *imageData, int w, int h, int x, int y, int newColor, float *nC, int oldColor, float tolerance, float prevCLRindex, float opacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay, int linearGamma) {
// based on https://lodev.org/cgtutor/floodfill.html
// by Lode Vandevenne

  if (newColor==oldColor)
     return 0; //avoid infinite loop

  static const int dx[8] = {0, 1, 1, 1, 0, -1, -1, -1}; // relative neighbor x coordinates
  static const int dy[8] = {-1, -1, 0, 1, 1, 1, 0, -1}; // relative neighbor y coordinates
  static const int gx[4] = {0, 1, 0, -1}; // relative neighbor x coordinates
  static const int gy[4] = {-1, 0, 1, 0}; // relative neighbor y coordinates

  UINT maxPixels = w*h + w;
  UINT loopsOccured = 0;
  UINT suchDeviations = 0;
  int suchAppliedDeviations = 0;
  std::vector<bool> pixelzMap(maxPixels, 0);
  std::vector<float> indexes(maxPixels, 0);
  std::stack<int> starkX;
  std::stack<int> starkY;

  int px = y * w + x;
  pixelzMap[px] = 1;
  starkX.push(x);
  starkY.push(y);
  int k = (eightWay==1) ? 8 : 4;
  float defIndex = (alternateMode==3) ? 0 : prevCLRindex;
  float index;
  while (starkX.size())
  {
     if (maxPixels<loopsOccured)
        break;

     loopsOccured++;
     int x = starkX.top();
     int y = starkY.top();
     starkX.pop();
     starkY.pop();
     // #pragma omp parallel for schedule(static) default(none) num_threads(3)
     for (int i = 0; i < k; i++)
     {
        int nx = (eightWay==1) ? x + dx[i] : x + gx[i] ;
        int ny = (eightWay==1) ? y + dy[i] : y + gy[i];

        if (nx>=0 && nx<w && ny>=0 && ny<h)
        {
           int tpx = ny * w + nx;
           if (pixelzMap[tpx]==1)
              continue;

           int thisColor = imageData[tpx];
           if (thisColor==oldColor)
           {
              pixelzMap[tpx] = 1;
              indexes[tpx] = defIndex;
              starkX.push(nx);
              starkY.push(ny);
           } else if (tolerance>0)
           {
              if (decideColorsEqual(thisColor, oldColor, tolerance, prevCLRindex, alternateMode, nC, index))
              {
                 pixelzMap[tpx] = 1;
                 indexes[tpx] = index;
                 // pixelzMap.insert( std::pair<int, bool>(tpx, 1) );
                 starkX.push(nx);
                 starkY.push(ny);
                 suchDeviations++;
              }
           }
        }
     }
  }

  // std::stringstream ss;
  // ss << "qpv: suchDeviations = " << suchDeviations;

  int thisColor = 0;
  for (std::size_t pix = 0; pix < pixelzMap.size(); ++pix)
  {
      if (pixelzMap[pix]!=1)
         continue;

      // std::cout << it->first << " => " << it->second << '\n';
      suchAppliedDeviations++;
      if (tolerance>0 && (opacity<1 || dynamicOpacity==1 || blendMode>0 || cartoonMode==1))
      {
         int prevColor = imageData[pix];
         if (cartoonMode==1)
            thisColor = oldColor;
         else
            thisColor = mixColors(prevColor, nC, opacity, dynamicOpacity, blendMode, prevCLRindex, tolerance, alternateMode, indexes[pix], linearGamma);

         imageData[pix] = thisColor;
      } else
      {
         imageData[pix] = newColor;   // second element , the colour, will be used to mix colours; to-do
      }
  }
  
  // ss << " suchAppliedDeviations = " << suchAppliedDeviations;
  // ss << " mapSize = " << pixelzMap.size();
  // OutputDebugStringA(ss.str().data());
  return suchAppliedDeviations;
}

int FloodFillScanlineStack(int *imageData, int w, int h, int x, int y, int newColor, int oldColor) {
// based on https://lodev.org/cgtutor/floodfill.html
// by Lode Vandevenne
  if (oldColor == newColor)
     return 0;

  int x1;
  bool spanAbove, spanBelow;
  UINT maxPixels = w*h + w;
  UINT loopsOccured = 0;

  // std::vector<int> stack;
  // push(stack, x, y);
  std::stack<int> starkX;
  std::stack<int> starkY;
  // std::vector<int> stack;
  starkX.push(x);
  starkY.push(y);
  while (starkX.size())
  {
    int x = starkX.top();
    int y = starkY.top();
    x1 = x;

    while (x1 >= 0 && imageData[y * w + x1] == oldColor)
    {
       x1--;
    }

    x1++;
    spanAbove = spanBelow = 0;
    starkX.pop();
    starkY.pop();

    while (x1 < w && imageData[y * w + x1] == oldColor)
    {
       imageData[y * w + x1] = newColor;
       if (maxPixels<loopsOccured)
          break;

       loopsOccured++;
       // int clrA = imageData[(y - 1) * w + x1];
       // int clrB = imageData[(y + 1) * w + x1];
       if (!spanAbove && y > 0 && imageData[(y - 1) * w + x1] == oldColor)
       // if (spanAbove==0 && y>0 && clrA==oldColor)
       {
          starkX.push(x1);
          starkY.push(y - 1);
          spanAbove = 1;
       } else if (spanAbove && y > 0 && imageData[(y - 1) * w + x1] != oldColor)
       // } else if (spanAbove==1 && y>0 && clrA!=oldColor)
       {
          spanAbove = 0;
       }

       if (!spanBelow && y < h - 1 && imageData[(y + 1) * w + x1] == oldColor)
       // if (spanBelow==0 && y<(h-1) && clrB==oldColor)
       {
          starkX.push(x1);
          starkY.push(y + 1);
          spanBelow = 1;
       // } else if (spanBelow==1 && y<(h-1) && clrB!=oldColor)
       } else if (spanBelow && y < h - 1 && imageData[(y + 1) * w + x1] != oldColor)
       {
          spanBelow = 0;
       }
       x1++;
    }
  }
  return loopsOccured;
}

int ReplaceGivenColor(int *imageData, int w, int h, int x, int y, int newColor, float *nC, int prevColor, float tolerance, float prevCLRindex, float opacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int linearGamma) {
    if ((x < 0) || (x >= (w-1)) || (y < 0) || (y >= (h-1)))  // out of bounds
       return 0;

    int loopsOccured = 0;
    #pragma omp parallel for schedule(static) default(none) // num_threads(3)
    for (int zx = 0; zx < w; zx++)
    {
        int oldColor = prevColor;
        float index;
        int thisColor = 0;
        for (int zy = 0; zy < h; zy++)
        {
            if (decideColorsEqual(imageData[zx + zy * w], prevColor, tolerance, prevCLRindex, alternateMode, nC, index))
            {
               if (tolerance>0 && (opacity<1 || dynamicOpacity==1 || blendMode>0 || cartoonMode==1))
               {
                  int prevColor = imageData[zx + zy * w];
                  if (cartoonMode==1)
                     thisColor = oldColor;
                  else
                     thisColor = mixColors(prevColor, nC, opacity, dynamicOpacity, blendMode, prevCLRindex, tolerance, alternateMode, index, linearGamma);
                  imageData[zx + zy * w] = thisColor;
               } else
               {
                  imageData[zx + zy * w] = newColor;
               }
               loopsOccured++;
            }
        }
    }
    return loopsOccured;
}

DLL_API int DLL_CALLCONV FloodFyll(int *imageData, int modus, int w, int h, int x, int y, int newColor, int tolerance, int fillOpacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay, int linearGamma) {
    if ((x < 0) || (x >= (w-1)) || (y < 0) || (y >= (h-1)))  // out of bounds
       return 0;

    float toleranza = (alternateMode==3) ? (float)tolerance/10.0 + 1 : tolerance;
    int prevColor = imageData[x + y * w];
    int aB = (prevColor >> 24) & 0xFF;
    int rB = (prevColor >> 16) & 0xFF;
    int gB = (prevColor >> 8) & 0xFF;
    int bB = prevColor & 0xFF;
    float prevCLRindex = RGBtoGray(rB, gB, bB, alternateMode);

    float nC[7];
    nC[0] = (newColor >> 24) & 0xFF;
    nC[1] = (newColor >> 16) & 0xFF;
    nC[2] = (newColor >> 8) & 0xFF;
    nC[3] = newColor & 0xFF;

    auto LabA = RGBtoLAB(rB, gB, bB);
    nC[4] = LabA[0];
    nC[5] = LabA[1];
    nC[6] = LabA[2];

    // auto LabB = RGBtoLAB(rB, gB, bB);
    // float CIE = CIEdeltaE2000(LabA[0], LabA[1], LabA[2], LabB[0], LabB[1], LabB[2], 1, 1, 1);
    // float CIE2 = testCIEdeltaE2000(LabA[0], LabA[1], LabA[2], LabB[0], LabB[1], LabB[2], 1, 1, 1);

    float opacity = (float)fillOpacity / 255.0f;
    if (tolerance==0 && (opacity<1 || blendMode>0))
       newColor = mixColors(prevColor, nC, opacity, 0, blendMode, 0, 0, 0, 0, linearGamma);

    int r;
    if (modus==1)
       r = ReplaceGivenColor(imageData, w, h, x, y, newColor, nC, prevColor, toleranza, prevCLRindex, opacity, dynamicOpacity, blendMode, cartoonMode, alternateMode, linearGamma);
    else if (toleranza>0)
       r = FloodFill8Stack(imageData, w, h, x, y, newColor, nC, prevColor, toleranza, prevCLRindex, opacity, dynamicOpacity, blendMode, cartoonMode, alternateMode, eightWay, linearGamma);
    else
       r = FloodFillScanlineStack(imageData, w, h, x, y, newColor, prevColor);

    // std::stringstream ss;
    // ss << "qpv: opacity = " << opacity;
    // ss << " newColor = " << newColor;
    // ss << " TolerMode = " << alternateMode;
    // // ss << " | CIE=" << CIE;
    // ss << " | L=" << nC[4];
    // ss << " | pix affected=" << r;
    // ss << " tolerance = " << toleranza;
    // ss << " clrIndex = " << prevCLRindex;
    // OutputDebugStringA(ss.str().data());

    return r;
}

DLL_API int DLL_CALLCONV autoCropAider(int* bitmapData, int Width, int Height, int adaptLevel, double threshold, double vTolrc, int whichLoop, int aaMode, int* fcoord) {
   int maxThresholdHitsW = round(Width*threshold) + 1;
   if (maxThresholdHitsW>floor(Width/2))
      maxThresholdHitsW = floor(Width/2);

   int maxThresholdHitsH = round(Height*threshold) + 1;
   if (maxThresholdHitsH>floor(Height/2))
      maxThresholdHitsH = floor(Height/2);

   if (threshold==0)
      maxThresholdHitsW = maxThresholdHitsH = 1;

   int clrPrimeA = bitmapData[0];
   int clrPrimeB = bitmapData[1];
   int clrPrimeC = bitmapData[Height];
   int prevR1 = wrapRGBtoGray(clrPrimeA, 1);
   int prevR2 = wrapRGBtoGray(clrPrimeB, 1);
   int prevR3 = wrapRGBtoGray(clrPrimeC, 1);
   int prevR4 = (prevR1 + prevR2 + prevR3)/3;
   int oprevR4 = prevR4;

   int ToleranceHits = 0;
   int loopDone = 0;
   int x = 0; int y = 0;
   if (whichLoop==1)
   {
      for (y = 0; y < Height; y++)
      {
         for (x = 0; x < Width; x++)
         {
            int clrR1 = bitmapData[x + (y * Width)];
            int R1 = wrapRGBtoGray(clrR1, 1);
            int d = abs(prevR4 - R1);

            if (aaMode==1)
            {
               if (inRange(d - adaptLevel, d + adaptLevel, vTolrc))
                  prevR4 = R1;

               // d = min(d, abs(oprevR4 - R1));
            }

            if (ToleranceHits<maxThresholdHitsW && d>vTolrc)
            {
               ToleranceHits++;
            } else if (d<=vTolrc)
            {
               d = 0;
            } else
            {
               loopDone = 1;
               break;
            }
            // fnOutputDebug(std::to_string(whichLoop) + " d" + std::to_string(d) + " R" + std::to_string(R1) + " H" + std::to_string(ToleranceHits) + " maxH" + std::to_string(maxThresholdHitsW) );
         }

         ToleranceHits = 0;
         if (loopDone==1)
         {
            *fcoord = y;
            break;
         }
      }
   } else if (whichLoop==2)
   {
      for (x = 0; x < Width; x++)
      {
         for (y = 0; y < Height; y++)
         {
            int clrR1 = bitmapData[x + (y * Width)];
            // int clrR1 = bitmapData[x * Height + y];
            int R1 = wrapRGBtoGray(clrR1, 1);
            int d = abs(prevR4 - R1);

            if (inRange(d - adaptLevel, d + adaptLevel, vTolrc) && aaMode==1)
               prevR4 = R1;

            if (ToleranceHits<maxThresholdHitsW && d>vTolrc)
            {
               ToleranceHits++;
            } else if (d<=vTolrc)
            {
               d = 0;
            } else
            {
               loopDone = 1;
               break;
            }
            // fnOutputDebug(std::to_string(whichLoop) + " d" + std::to_string(d) + " R" + std::to_string(R1) + " H" + std::to_string(ToleranceHits) + " maxH" + std::to_string(maxThresholdHitsW) );
         }

         ToleranceHits = 0;
         if (loopDone==1)
         {
            *fcoord = x;
            break;
         }
      }
   }
   // fnOutputDebug(std::to_string(whichLoop) + " fc" + std::to_string(*fcoord)  + " x" + std::to_string(x) + " y" + std::to_string(y) + " prev=" + std::to_string(prevR4) );

   return 1;
}

DLL_API int DLL_CALLCONV EraserBrush(int *imageData, int *maskData, int w, int h, int invertMask, int replaceMode, int levelAlpha, int *clonedData, int useClone) {

    // #pragma omp parallel for schedule(dynamic) default(none)
    for (int x = 0; x < w; x++)
    {
        // int px;
        for (int y = 0; y < h; y++)
        {
            const int px = x * h + y;
            int alpha2;
            int a = (imageData[px] >> 24) & 0xFF;
            int intensity = (maskData[px] >> 8) & 0xff;
            if (invertMask == 1)
               intensity = 255 - intensity;

            float fintensity = intensity/255.0f;
            if (a==0)
               continue;

            if (replaceMode == 1)
               alpha2 = min(levelAlpha, a);
            else if (replaceMode == 2)
               alpha2 = max(0, (int)a - levelAlpha);
            else
               alpha2 = levelAlpha;

            alpha2 = (alpha2==a) ? a : ceil(alpha2*fintensity + a*max(0.0f, 1.0f - fintensity));  // Formula: A*w + B*(1 – w)
            // int haha = (alpha2!=a) ? 1 : 0;
            if (alpha2!=a)
            {
                if (useClone==1)
                   imageData[px] = (alpha2 << 24) | (clonedData[px] & 0x00ffffff);
                else
                   imageData[px] = (alpha2 << 24) | (imageData[px] & 0x00ffffff);
            }
            // std::stringstream ss;
            // ss << "qpv: alpha2 = " << alpha2;
            // ss << " var a = " << a;
            // ss << " var haha = " << haha;
            // OutputDebugStringA(ss.str().data());
        }
    }
 
    // fnOutputDebug("eraser alpha = " + std::to_string(levelAlpha));
    return 1;
}

DLL_API int DLL_CALLCONV ColourBrush(int *opacityImgData, int *imageData, int *maskData, int newColor, int w, int h, int invertMask, int replaceMode, int brushAlpha, int blendMode, int *clonedData, int useClone, int overDraw, int linearGamma, int wa, int ha, int offX, int offY, int flipLayers) {
// only works with 32-PARGB bitmaps 
    float nC[4];
    nC[0] = (replaceMode==1) ? brushAlpha : (newColor >> 24) & 0xFF;
    nC[1] = (newColor >> 16) & 0xFF;
    nC[2] = (newColor >> 8) & 0xFF;
    nC[3] = newColor & 0xFF;
    int apx = (w/2) * h + h/2;
    int centerLevel = (maskData[apx] >> 8) & 0xff;

    float pK[4];
    pK[0] = 255;
    pK[1] = centerLevel;
    pK[2] = centerLevel;
    pK[3] = centerLevel;
    float fr = 2.5f;
    if (overDraw==1 && blendMode>0)
    {
       brushAlpha = clamp(brushAlpha + 128, 0, 255);
       fr = 3.25f;
    }

    float fb = (255.0f - brushAlpha)/255.0f;
    for (int y = 0; y < h; y++)
    {
        for (int x = 0; x < w; x++)
        {
            int px = x * h + y;
            int BGRcolor = (overDraw==0) ? clonedData[px] : imageData[px];
            int intensity = (maskData[px] >> 8) & 0xff;
            int clipFlag = (opacityImgData[px] >> 24) & 0xff;
            if (invertMask==1)
               intensity = 255 - intensity;

            float fintensity = intensity/255.0f;
            if (overDraw==1)
            {
               fintensity -= fb;
            } else
            {
               int altoAlpha = (opacityImgData[px] >> 8) & 0xff;
               int tL = INTweighTwoValues(255, altoAlpha, fintensity/fr);
               fintensity = tL/255.0f - fb;
               if (clipFlag<2)
                  tL = 0;

               if (overDraw==0 || blendMode>0)
                  opacityImgData[px] = (clipFlag << 24) | ((tL & 0xFF) << 16) | ((tL & 0xFF) << 8) | (tL & 0xFF);
            }
    
            if (fintensity<0 || clipFlag<2)
               fintensity = 0;

            imageData[px] = simpleMixColors(BGRcolor, nC, fintensity, blendMode, linearGamma, flipLayers);
        }
    }
 
    // fnOutputDebug("alles gut");
    return 1;
}


DLL_API int DLL_CALLCONV FillImageHoles(int *imageData, int w, int h, int newColor) {
    // fnOutputDebug("FillImageHoles newColor = " + std::to_string(newColor));
    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            const int px = x * h + y;
            int a = (imageData[px] >> 24) & 0xFF;
            if (a<2)
               imageData[px] = newColor;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV SetGivenAlphaLevel(int *imageData, int w, int h, int givenLevel, int fillMissingOnly, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int x = 0; x < w; x++)
    {
        int px, y = 0;
        int defaultColor = 0;
        UINT BGRcolor = imageData[x + y * w];
        if (BGRcolor!=0x0)
           defaultColor = BGRcolor & 0x00ffffff;

        for (y = 0; y < h; y++)
        {
            px = x + y * w;
            BGRcolor = imageData[px];
            if (BGRcolor==0x0 && defaultColor)
               imageData[px] = (givenLevel << 24) | defaultColor;
            else
               defaultColor = BGRcolor & 0x00ffffff;

            if (fillMissingOnly==0)
               imageData[px] = (givenLevel << 24) | (imageData[px] & 0x00ffffff);
        }
    }

    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int x = w - 1; x >= 0; x--)
    {
        int px, y = h - 1;
        int defaultColor = 0;
        UINT BGRcolor = imageData[x + y * w];
        if (BGRcolor!=0x0)
           defaultColor = BGRcolor & 0x00ffffff;

        for (y = h - 1; y >= 0; y--)
        {
            px = x + y * w;
            BGRcolor = imageData[px];
            if (BGRcolor==0x0 && defaultColor)
               imageData[px] = (givenLevel << 24) | defaultColor;
            else
               defaultColor = BGRcolor & 0x00ffffff;
        }
    }
    return 1;
}

/*
pBitmap and pBitmap2Blend must be the same width and height
and in 32-ARGB format: PXF32ARGB - 0x26200A.
*/

DLL_API int DLL_CALLCONV BlendBitmaps(int* bgrImageData, int* otherData, int w, int h, int blendMode, int flipLayers, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            UINT BGRcolor = bgrImageData[x + (y * w)];
            if (BGRcolor != 0x0)
            {
                UINT colorO = otherData[x + (y * w)];
                int aO = (colorO >> 24) & 0xFF;
                int aB = (BGRcolor >> 24) & 0xFF;
                int aX = min(aO, aB);
                if (aX < 1)
                {
                    bgrImageData[x + (y * w)] = 0;
                    continue;
                }

                int rO = (colorO >> 16) & 0xFF;
                int gO = (colorO >> 8) & 0xFF;
                int bO = colorO & 0xFF;

                int rB = (BGRcolor >> 16) & 0xFF;
                int gB = (BGRcolor >> 8) & 0xFF;
                int bB = BGRcolor & 0xFF;

                int results[3];
                // int theGray = RGBtoGray(rO, gO, bO, 0);
                if (flipLayers==1)
                   calculateBlendModes(rB, gB, bB, rO, gO, bO, blendMode, results);
                else
                   calculateBlendModes(rO, gO, bO, rB, gB, bB, blendMode, results);
                bgrImageData[x + (y * w)] = (aX << 24) | ((results[0] & 0xFF) << 16) | ((results[1] & 0xFF) << 8) | (results[2] & 0xFF);
            }
        }
    }
    return 1;
}


/*
pBitmap will be filled with a random generated noise
It must be in 32-ARGB format: PXF32ARGB - 0x26200A.
*/


DLL_API int DLL_CALLCONV RandomNoise(int* bgrImageData, int w, int h, int intensity, int mode, int threadz, int fillBgr) {
    // srand (time(NULL));
    // #pragma omp parallel for default(none) num_threads(threadz)
    time_t nTime;
    srand((unsigned) time(&nTime));
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            unsigned char aT = 255;
            unsigned char z = rand() % 101;
            if (z<intensity)
            {
               // unsigned char rT = 0;
               bgrImageData[x + (y * w)] = (fillBgr!=1) ? 0 : (255 << 24) | (0 << 16) | (0 << 8) | 0;
               continue;
            }

            if (mode!=1)
            {
               unsigned char rT = rand() % 256;
               unsigned char gT = rand() % 256;
               unsigned char bT = rand() % 256;
               bgrImageData[x + (y * w)] = (aT << 24) | (rT << 16) | (gT << 8) | bT;
            } else
            {
               unsigned char rT = rand() % 256;
               bgrImageData[x + (y * w)] = (aT << 24) | (rT << 16) | (rT << 8) | rT;
            }
        }
    }

    return 1;
}

DLL_API int DLL_CALLCONV getPBitmapistoInfos(Gdiplus::GpBitmap* pBitmap, int w, int h, UINT* resultsArray) {
     UINT entries = 256;
     UINT elements[256];
     // Gdiplus::DllExports::GetHistogramSize(3, entries);
     Gdiplus::DllExports::GdipBitmapGetHistogram(pBitmap, Gdiplus::HistogramFormatR, entries, elements, NULL, NULL, NULL);
     
     int medianValue = -1;
     int peakPointK = -1;
     int minBrLvlK = -1;
     UINT minPointK = 0;
     UINT modePointV = 0;
     UINT modePointK = 0;
     UINT thisSum = 0;
     UINT sumTotalBr = 0;
     UINT pixRms = 0;
     UINT TotalPixelz = w*h;
     UINT pixMinu = TotalPixelz;

     for (int thisIndex = 0; thisIndex < 256; thisIndex++)
     {
        // fnOutputDebug("histo [" + to_string(i) +  "] = " + to_string(elements[i])) ;
        int nrPixelz = elements[thisIndex];
        if (nrPixelz>modePointV)
        {
           modePointV = nrPixelz;
           modePointK = thisIndex;
        }

        if (nrPixelz>0)
        {
           if (medianValue == -1)
           {
              thisSum += nrPixelz;
              if (thisSum>TotalPixelz/2)
                 medianValue = thisIndex;
           }

           sumTotalBr += nrPixelz * thisIndex;
           peakPointK = thisIndex;     // max range in histogram
           if (minBrLvlK == -1)
              minBrLvlK = thisIndex;   // min range in histogram
       
           if (nrPixelz<pixMinu)
           {
              pixMinu = nrPixelz;
              minPointK = thisIndex;
           }
        }

        pixRms += pow(nrPixelz, 2);       // root-mean square
     }

     UINT avgu = round((sumTotalBr/TotalPixelz - 1)/2);
     UINT rmsu = round(sqrt(pixRms / (peakPointK - minBrLvlK)));

     resultsArray[0] = avgu;
     resultsArray[1] = medianValue;
     resultsArray[2] = peakPointK;
     resultsArray[3] = minBrLvlK;
     resultsArray[4] = rmsu;
     resultsArray[5] = modePointK;
     resultsArray[6] = minPointK;
     // fnOutputDebug("histo avgu=" + to_string(avgu));
     // fnOutputDebug("histo medianValue=" + to_string(medianValue));
     // fnOutputDebug("histo peakPointK=" + to_string(peakPointK));
     // fnOutputDebug("histo minBrLvlK=" + to_string(minBrLvlK));
     // fnOutputDebug("histo rms=" + to_string(rmsu));
     // fnOutputDebug("histo modePointK=" + to_string(modePointK));
     // fnOutputDebug("histo minPointK=" + to_string(minPointK));
     return 1;
}

/*
Pixelate C/C++ Function by Tic and fixed by Fincs;
https://autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/page-55
*/

DLL_API int DLL_CALLCONV PixelateBitmap(unsigned char* sBitmap, unsigned char* dBitmap, int w, int h, int Stride, int Size) {
    int sA, sR, sG, sB, o;
    for (int y1 = 0; y1 < h / Size; ++y1)
    {
        for (int x1 = 0; x1 < w / Size; ++x1)
        {
            sA = sR = sG = sB = 0;
            for (int y2 = 0; y2 < Size; ++y2)
            {
                for (int x2 = 0; x2 < Size; ++x2)
                {
                    o = 4 * (x2 + x1 * Size) + Stride * (y2 + y1 * Size);
                    sA += sBitmap[3 + o];
                    sR += sBitmap[2 + o];
                    sG += sBitmap[1 + o];
                    sB += sBitmap[o];
                }
            }

            sA /= Size * Size;
            sR /= Size * Size;
            sG /= Size * Size;
            sB /= Size * Size;
            for (int y2 = 0; y2 < Size; ++y2)
            {
                for (int x2 = 0; x2 < Size; ++x2)
                {
                    o = 4 * (x2 + x1 * Size) + Stride * (y2 + y1 * Size);
                    dBitmap[3 + o] = sA;
                    dBitmap[2 + o] = sR;
                    dBitmap[1 + o] = sG;
                    dBitmap[o] = sB;
                }
            }
        }

        if (w % Size != 0)
        {
            sA = sR = sG = sB = 0;
            for (int y2 = 0; y2 < Size; ++y2)
            {
                for (int x2 = 0; x2 < w % Size; ++x2)
                {
                    o = 4 * (x2 + (w / Size) * Size) + Stride * (y2 + y1 * Size);
                    sA += sBitmap[3 + o];
                    sR += sBitmap[2 + o];
                    sG += sBitmap[1 + o];
                    sB += sBitmap[o];
                }
            }

            int tmp = (w % Size) * Size;
            sA = tmp ? (sA / tmp) : 0;
            sR = tmp ? (sR / tmp) : 0;
            sG = tmp ? (sG / tmp) : 0;
            sB = tmp ? (sB / tmp) : 0;
            for (int y2 = 0; y2 < Size; ++y2)
            {
                for (int x2 = 0; x2 < w % Size; ++x2)
                {
                    o = 4 * (x2 + (w / Size) * Size) + Stride * (y2 + y1 * Size);
                    dBitmap[3 + o] = sA;
                    dBitmap[2 + o] = sR;
                    dBitmap[1 + o] = sG;
                    dBitmap[o] = sB;
                }
            }
        }
    }

    for (int x1 = 0; x1 < w / Size; ++x1)
    {
        sA = sR = sG = sB = 0;
        for (int y2 = 0; y2 < h % Size; ++y2)
        {
            for (int x2 = 0; x2 < Size; ++x2)
            {
                o = 4 * (x2 + x1 * Size) + Stride * (y2 + (h / Size) * Size);
                sA += sBitmap[3 + o];
                sR += sBitmap[2 + o];
                sG += sBitmap[1 + o];
                sB += sBitmap[o];
            }
        }

        int tmp = Size * (h % Size);
        sA = tmp ? (sA / tmp) : 0;
        sR = tmp ? (sR / tmp) : 0;
        sG = tmp ? (sG / tmp) : 0;
        sB = tmp ? (sB / tmp) : 0;

        for (int y2 = 0; y2 < h % Size; ++y2)
        {
            for (int x2 = 0; x2 < Size; ++x2)
            {
                o = 4 * (x2 + x1 * Size) + Stride * (y2 + (h / Size) * Size);
                dBitmap[3 + o] = sA;
                dBitmap[2 + o] = sR;
                dBitmap[1 + o] = sG;
                dBitmap[o] = sB;
            }
        }
    }

    sA = sR = sG = sB = 0;
    for (int y2 = 0; y2 < h % Size; ++y2)
    {
        for (int x2 = 0; x2 < w % Size; ++x2)
        {
            o = 4 * (x2 + (w / Size) * Size) + Stride * (y2 + (h / Size) * Size);
            sA += sBitmap[3 + o];
            sR += sBitmap[2 + o];
            sG += sBitmap[1 + o];
            sB += sBitmap[o];
        }
    }

    int tmp = (w % Size) * (h % Size);
    sA = tmp ? (sA / tmp) : 0;
    sR = tmp ? (sR / tmp) : 0;
    sG = tmp ? (sG / tmp) : 0;
    sB = tmp ? (sB / tmp) : 0;

    for (int y2 = 0; y2 < h % Size; ++y2)
    {
        for (int x2 = 0; x2 < w % Size; ++x2)
        {
            o = 4 * (x2 + (w / Size) * Size) + Stride * (y2 + (h / Size) * Size);
            dBitmap[3 + o] = sA;
            dBitmap[2 + o] = sR;
            dBitmap[1 + o] = sG;
            dBitmap[o] = sB;
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV ConvertToGrayScale(int *BitmapData, int w, int h, int modus) {
// NTSC // CCIR 601 luma RGB weights:
// r := 0.29970, g := 0.587130, b := 0.114180

    #pragma omp parallel for schedule(dynamic) default(none)
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            int G;
            UINT colorO = BitmapData[x + (y * w)];
            int aO = (colorO >> 24) & 0xFF;
            if (modus==1)
            {
               G = (colorO >> 16) & 0xFF;
            } else if (modus==2)
            {
               G = (colorO >> 8) & 0xFF;
            } else if (modus==3)
            {
               G = colorO & 0xFF;
            } else if (modus==4)
            {
               G = aO;
            } else // if (modus==5)
            {
               float rO = ((colorO >> 16) & 0xFF)*0.29970f;
               float gO = ((colorO >> 8) & 0xFF)*0.587130f;
               float bO = (colorO & 0xFF)*0.114180f;
               G = clamp((int)round(rO + gO + bO), 0, 255);
            }

            BitmapData[x + (y * w)] = (aO << 24) | (G << 16) | (G << 8) | G;
        }
    }
    return 1;
}

inline int hammingDistance(UINT64 n1, UINT64 n2, UINT hamDistLBorderCrop, UINT hamDistRBorderCrop, bool doRange) { 
    UINT64 x = n1 ^ n2; 
    int setBits = 0; 
    if (doRange==0)
    {
        while (x > 0)
        { 
           setBits += x & 1; 
           x >>= 1; 
        }
    } else
    {
        int loopsOccured = 0;
        while (x > 0)
        { 
           loopsOccured++;
           if (inRange(hamDistLBorderCrop, 64 - hamDistRBorderCrop, loopsOccured))
              setBits += x & 1; 
           x >>= 1; 
        }
    }  

    return setBits; 
} 

DLL_API UINT DLL_CALLCONV retrieveHammingDistanceResults(UINT *resultsArray, UINT whichArray, UINT results) {
   for ( int index = 0 ; index <= results ; index++)
   {
        if (whichArray==1)
           resultsArray[index] = dupesListIDsA[index];
        else if (whichArray==2)
           resultsArray[index] = dupesListIDsB[index];
        else if (whichArray==3)
           resultsArray[index] = dupesListIDsC[index];
   }

   if (whichArray==1)
   {
      // dupesListIDsA.clear();
      dupesListIDsA.resize(1);
   } else if (whichArray==2)
   {
      // dupesListIDsB.clear();
      dupesListIDsB.resize(1);
   } else if (whichArray==3)
   {
      // dupesListIDsC.clear();
      dupesListIDsC.resize(1);
   }

   return 1;
}

DLL_API UINT DLL_CALLCONV clearHammingDistanceResults() {
    // dupesListIDsA.clear();
    dupesListIDsA.resize(1);
    // dupesListIDsB.clear();
    dupesListIDsB.resize(1);
    // dupesListIDsC.clear();
    dupesListIDsC.resize(1);
    dupesListIDsA.shrink_to_fit();
    dupesListIDsB.shrink_to_fit();
    dupesListIDsC.shrink_to_fit();

    return 1;
}

void setMainWindowTitle(std::string str, HWND pvHwnd) {
  // std::string str = "Calculating hamming distance: " + std::to_string(yay) + " / " + std::to_string(yoyo);
  std::wstring temp = std::wstring(str.begin(), str.end());
  LPCWSTR wideString = temp.c_str();

  SetWindowText(pvHwnd, wideString);
}

DLL_API UINT DLL_CALLCONV hammingDistanceOverArray(UINT64 *givenHashesArray, UINT64 *givenFlippedHashesArray, UINT *givenIDs, UINT arraySize, int threshold, UINT hamDistLBorderCrop, UINT hamDistRBorderCrop, int checkInverted, int checkFlipped, int stepping, int offsetu, int* hoffset) {
   UINT results = 0;
   UINT n = arraySize;
   bool doRange = (hamDistLBorderCrop==0 && hamDistRBorderCrop==0) ? 0 : 1;
   // int mainIndex = 1;
   // int returnVal = 1;
   // std::stringstream ss;
   // ss << "qpv: arraySize " << n;
   // ss << " maxResults " << maxResults;
   // OutputDebugStringA(ss.str().data());

    int noffset = 0;
    for ( INT secondIndex = offsetu ; secondIndex<n+1 ; secondIndex++)
    {
        UINT64 invert2ndindex = 0;
        // UINT64 reversed2ndindex = 0;
        if (checkInverted==1)
           invert2ndindex = ~(givenHashesArray[secondIndex]);

        // if (checkFlipped==1)
        // {
        //    reversed2ndindex = revBits_entire(givenHashesArray[secondIndex]);
        //    // fnOutputDebug("reverso " + to_string(givenHashesArray[secondIndex]) + " -- " + to_string(reversed2ndindex));
        // }

        noffset++;
        #pragma omp parallel for schedule(dynamic) default(none) shared(results)
        for ( INT mainIndex = secondIndex + 1 ; mainIndex<n ; mainIndex++)
        {
            int diff2 = 900;
            int diff3 = 900;

            int diff = hammingDistance(givenHashesArray[mainIndex], givenHashesArray[secondIndex], hamDistLBorderCrop, hamDistRBorderCrop, doRange);
            if (checkInverted==1)
               diff2 = hammingDistance(givenHashesArray[mainIndex], invert2ndindex, hamDistLBorderCrop, hamDistRBorderCrop, doRange);
            if (checkFlipped==1)
               diff3 = hammingDistance(givenHashesArray[mainIndex], givenFlippedHashesArray[secondIndex], hamDistLBorderCrop, hamDistRBorderCrop, doRange);

            // if (threshold>2 && diff>=threshold)
            //    diff = hammingDistance(givenHashesArray[mainIndex], reversed2ndindex, hamDistLBorderCrop, hamDistRBorderCrop);

            #pragma omp critical
            {
               if (diff<threshold)
               {
                   dupesListIDsA.push_back(givenIDs[mainIndex]);
                   dupesListIDsB.push_back(givenIDs[secondIndex]);
                   dupesListIDsC.push_back(diff);
                   results++;
               };

               if (diff2<threshold)
               {
                   dupesListIDsA.push_back(givenIDs[mainIndex]);
                   dupesListIDsB.push_back(givenIDs[secondIndex]);
                   dupesListIDsC.push_back(diff2);
                   results++;
               }

               if (diff3<threshold)
               {
                   // fnOutputDebug("c++ dupe pair:" + to_string(givenHashesArray[mainIndex]) + "/" + to_string(givenFlippedHashesArray[secondIndex]));
                   dupesListIDsA.push_back(givenIDs[mainIndex]);
                   dupesListIDsB.push_back(givenIDs[secondIndex]);
                   dupesListIDsC.push_back(diff3);
                   results++;
               }
            }
        }
        if (noffset>stepping)
           break;
    }

   *hoffset = noffset;
   // fnOutputDebug("hamDist results=" + to_string(results));
   // int test = hammingDistance(givenHashesArray[5], givenHashesArray[7]);
   // std::stringstream ss;
   // ss << "qpv: hashes results " << results;
   // ss << " hA " << givenHashesArray[5];
   // ss << " hB " << givenHashesArray[7];
   // ss << " idA " << givenIDs[5];
   // ss << " idB " << givenIDs[7];
   // ss << " diff " << test;
   // OutputDebugStringA(ss.str().data());
   return results;
}

double calcArrayAvgMedian(std::array<double, 64> givenArray, int modus) {
    int size = givenArray.size() - 1;
    if (modus==1) // median
    {
        std::sort(givenArray.begin(), givenArray.end());
        if (size % 2 == 0) {
            return (givenArray[round(size / 2 - 1)] + givenArray[round(size / 2)]) / 2;
        }

        return givenArray[floor(size / 2)];
    } else
    {
        // Calculate the average value from top 8x8 pixels, except for the first one.
        double thisSum = 0;
        for (int i = 0; i < size; i++)
        {
            if (i > 0)
            {
                thisSum += givenArray[i];
            }
        }

        return (thisSum / size);
    }
}

DLL_API int DLL_CALLCONV calculateDCTcoeffs(int size) {
    int thisIndex = 0;
    for (int i = 0; i < size; i++)
    {
        for (int j = 0; j < size; j++) {
            thisIndex++;
            DCTcoeffs[thisIndex] = cos(i * M_PI * (j + 0.5) / size);
        }
    }

    return 1;
}

auto calculateDCT(const std::array<double, 32> &matrix, int col, int loopu) {
    // int size = 32;
    std::array<double, 32> transformed;
    // double div2sz = sqrt(2.0 / size);
    // double div2sq = 1 / sqrt(2.0);

    int thisIndex = 0;
    for (int i = 0; i < 32; i++)
    {
        double sum = 0.0;
        for (int j = 0; j < 32; j++) {
            thisIndex++;
            sum += matrix[j] * DCTcoeffs[thisIndex];
            // sum += matrix[j] * cos(i * M_PI * (j + 0.5) / 32);
        }

        sum *= div2sz;
        if (i == 0) {
            sum *= div2sq;
        }

        transformed[i] = sum;
        // fnOutputDebug("calcPHashAlgo: col=" + to_string(col) + " loopu=" + to_string(loopu) + " matrix[" + to_string(i) + "] DCT=" + to_string(matrix[i]));
    }

    return transformed;
}


DLL_API INT64 DLL_CALLCONV calcPHashAlgo(char *givenArray, UINT size, int compareMethod) {
// based on the PHP implementation found on https://github.com/jenssegers/imagehash

    // givenArray is the pixels fingerprint
    // calculte DCT for rows

    double rows[32][32];
    std::array<double, 32>  trow;
    // fnOutputDebug("calcPHashAlgo: init before loop" + to_string(size));
    for ( int y = 0; y < size; y++)
    {
        for (int x = 0; x < size; x++) 
        {
            trow[x] = abs(givenArray[x + size*y]);
        }

        auto transformed = calculateDCT(trow, y, 1);
        for (int x = 0; x < size; x++) 
        {
            rows[y][x] = transformed[x];
            // fnOutputDebug("calcPHashAlgo: row DCT=" + to_string(rows[y][x]));
        }
    }

    // fnOutputDebug("calcPHashAlgo: first for-loop" + to_string(rows[12][13]));
    // fnOutputDebug("calcPHashAlgo: trow" + to_string(trow[12]));
    // fnOutputDebug("calcPHashAlgo: givenArray" + to_string(givenArray[12]));

    // calculte DCT for columns
    double matrix[32][32];
    std::array<double, 32>  col;
    for (int x = 0; x < size; x++)
    {
        for (int y = 0; y < size; y++)
        {
            col[y] = rows[y][x];
        }

        auto transformed = calculateDCT(col, x, 2);
        for (int y = 0; y < size; y++)
        {
            matrix[x][y] = transformed[y];
        }
    }
    // fnOutputDebug("calcPHashAlgo: second for-loop" + to_string(matrix[12][13]));

    // extract the top 8x8 pixels from the DCT matrix
    int thisIndex = -1;
    std::array<double, 64>   fpexels;
    for (int y = 0; y < 8; y++)
    {
        for (int x = 0; x < 8; x++)
        {
            thisIndex++;
            fpexels[thisIndex] = matrix[y][x];
        }
    }
    // fnOutputDebug("calcPHashAlgo: third for-loop" + to_string(fpexels[13]));

    INT64 one = 0x0000000000000001;
    INT64 hash = 0x0000000000000000;

    // Calculate hash
    double compareTerm = calcArrayAvgMedian(fpexels, compareMethod);
    // fnOutputDebug("calcPHashAlgo: compareTerm =" + to_string(compareTerm));
    for (int x = 0; x < 64; x++)
    {
        // resultsArray[x] = (fpexels[x] > compareTerm) ? 1 : 0;
        if (fpexels[x] > compareTerm)
           hash |= one;
        one = one << 1;
    }

    // fnOutputDebug("calcPHashAlgo: ended=" + to_string(hash));
    return hash;
}

template <typename T>
inline void SafeRelease(T *&p)
{
    if (NULL != p)
    {
        p->Release();
        p = NULL;
    }
}

INT indexedPixelFmts(WICPixelFormatGUID oPixFmt) {
    INT uPixFmt = 0;
    if (oPixFmt==GUID_WICPixelFormatDontCare)
       uPixFmt = 1;
    else if (oPixFmt==GUID_WICPixelFormat1bppIndexed)
       uPixFmt = 2;
    else if (oPixFmt==GUID_WICPixelFormat2bppIndexed)
       uPixFmt = 3;
    else if (oPixFmt==GUID_WICPixelFormat4bppIndexed)
       uPixFmt = 4;
    else if (oPixFmt==GUID_WICPixelFormat8bppIndexed)
       uPixFmt = 5;
    else if (oPixFmt==GUID_WICPixelFormatBlackWhite)
       uPixFmt = 6;
    else if (oPixFmt==GUID_WICPixelFormat2bppGray)
       uPixFmt = 7;
    else if (oPixFmt==GUID_WICPixelFormat4bppGray)
       uPixFmt = 8;
    else if (oPixFmt==GUID_WICPixelFormat8bppGray)
       uPixFmt = 9;
    else if (oPixFmt==GUID_WICPixelFormat8bppAlpha)
       uPixFmt = 10;
    else if (oPixFmt==GUID_WICPixelFormat16bppBGR555)
       uPixFmt = 11;
    else if (oPixFmt==GUID_WICPixelFormat16bppBGR565)
       uPixFmt = 12;
    else if (oPixFmt==GUID_WICPixelFormat16bppBGRA5551)
       uPixFmt = 13;
    else if (oPixFmt==GUID_WICPixelFormat16bppGray)
       uPixFmt = 14;
    else if (oPixFmt==GUID_WICPixelFormat24bppBGR)
       uPixFmt = 15;
    else if (oPixFmt==GUID_WICPixelFormat24bppRGB)
       uPixFmt = 16;
    else if (oPixFmt==GUID_WICPixelFormat32bppBGR)
       uPixFmt = 17;
    else if (oPixFmt==GUID_WICPixelFormat32bppBGRA)
       uPixFmt = 18;
    else if (oPixFmt==GUID_WICPixelFormat32bppPBGRA)
       uPixFmt = 19;
    else if (oPixFmt==GUID_WICPixelFormat32bppGrayFloat)
       uPixFmt = 20;
    else if (oPixFmt==GUID_WICPixelFormat32bppRGB)
       uPixFmt = 21;
    else if (oPixFmt==GUID_WICPixelFormat32bppRGBA)
       uPixFmt = 22;
    else if (oPixFmt==GUID_WICPixelFormat32bppPRGBA)
       uPixFmt = 23;
    else if (oPixFmt==GUID_WICPixelFormat48bppRGB)
       uPixFmt = 24;
    else if (oPixFmt==GUID_WICPixelFormat48bppBGR)
       uPixFmt = 25;
    else if (oPixFmt==GUID_WICPixelFormat64bppRGB)
       uPixFmt = 26;
    else if (oPixFmt==GUID_WICPixelFormat64bppRGBA)
       uPixFmt = 27;
    else if (oPixFmt==GUID_WICPixelFormat64bppBGRA)
       uPixFmt = 28;
    else if (oPixFmt==GUID_WICPixelFormat64bppPRGBA)
       uPixFmt = 29;
    else if (oPixFmt==GUID_WICPixelFormat64bppPBGRA)
       uPixFmt = 30;
    else if (oPixFmt==GUID_WICPixelFormat16bppGrayFixedPoint)
       uPixFmt = 31;
    else if (oPixFmt==GUID_WICPixelFormat32bppBGR101010)
       uPixFmt = 32;
    else if (oPixFmt==GUID_WICPixelFormat48bppRGBFixedPoint)
       uPixFmt = 33;
    else if (oPixFmt==GUID_WICPixelFormat48bppBGRFixedPoint)
       uPixFmt = 34;
    else if (oPixFmt==GUID_WICPixelFormat96bppRGBFixedPoint)
       uPixFmt = 35;
    else if (oPixFmt==GUID_WICPixelFormat96bppRGBFloat)
       uPixFmt = 36;
    else if (oPixFmt==GUID_WICPixelFormat128bppRGBAFloat)
       uPixFmt = 37;
    else if (oPixFmt==GUID_WICPixelFormat128bppPRGBAFloat)
       uPixFmt = 38;
    else if (oPixFmt==GUID_WICPixelFormat128bppRGBFloat)
       uPixFmt = 39;
    else if (oPixFmt==GUID_WICPixelFormat32bppCMYK)
       uPixFmt = 40;
    else if (oPixFmt==GUID_WICPixelFormat64bppRGBAFixedPoint)
       uPixFmt = 41;
    else if (oPixFmt==GUID_WICPixelFormat64bppBGRAFixedPoint)
       uPixFmt = 42;
    else if (oPixFmt==GUID_WICPixelFormat64bppRGBFixedPoint)
       uPixFmt = 43;
    else if (oPixFmt==GUID_WICPixelFormat128bppRGBAFixedPoint)
       uPixFmt = 44;
    else if (oPixFmt==GUID_WICPixelFormat128bppRGBFixedPoint)
       uPixFmt = 45;
    else if (oPixFmt==GUID_WICPixelFormat64bppRGBAHalf)
       uPixFmt = 46;
    else if (oPixFmt==GUID_WICPixelFormat64bppPRGBAHalf)
       uPixFmt = 47;
    else if (oPixFmt==GUID_WICPixelFormat64bppRGBHalf)
       uPixFmt = 48;
    else if (oPixFmt==GUID_WICPixelFormat48bppRGBHalf)
       uPixFmt = 49;
    else if (oPixFmt==GUID_WICPixelFormat32bppRGBE)
       uPixFmt = 50;
    else if (oPixFmt==GUID_WICPixelFormat16bppGrayHalf)
       uPixFmt = 51;
    else if (oPixFmt==GUID_WICPixelFormat32bppGrayFixedPoint)
       uPixFmt = 52;
    else if (oPixFmt==GUID_WICPixelFormat32bppRGBA1010102)
       uPixFmt = 53;
    else if (oPixFmt==GUID_WICPixelFormat32bppRGBA1010102XR)
       uPixFmt = 54;
    else if (oPixFmt==GUID_WICPixelFormat32bppR10G10B10A2)
       uPixFmt = 55;
    else if (oPixFmt==GUID_WICPixelFormat32bppR10G10B10A2HDR10)
       uPixFmt = 56;
    else if (oPixFmt==GUID_WICPixelFormat64bppCMYK)
       uPixFmt = 57;
    else if (oPixFmt==GUID_WICPixelFormat24bpp3Channels)
       uPixFmt = 58;
    else if (oPixFmt==GUID_WICPixelFormat32bpp4Channels)
       uPixFmt = 59;
    else if (oPixFmt==GUID_WICPixelFormat40bpp5Channels)
       uPixFmt = 60;
    else if (oPixFmt==GUID_WICPixelFormat48bpp6Channels)
       uPixFmt = 61;
    else if (oPixFmt==GUID_WICPixelFormat56bpp7Channels)
       uPixFmt = 62;
    else if (oPixFmt==GUID_WICPixelFormat64bpp8Channels)
       uPixFmt = 63;
    else if (oPixFmt==GUID_WICPixelFormat48bpp3Channels)
       uPixFmt = 64;
    else if (oPixFmt==GUID_WICPixelFormat64bpp4Channels)
       uPixFmt = 65;
    else if (oPixFmt==GUID_WICPixelFormat80bpp5Channels)
       uPixFmt = 66;
    else if (oPixFmt==GUID_WICPixelFormat96bpp6Channels)
       uPixFmt = 67;
    else if (oPixFmt==GUID_WICPixelFormat112bpp7Channels)
       uPixFmt = 68;
    else if (oPixFmt==GUID_WICPixelFormat128bpp8Channels)
       uPixFmt = 69;
    else if (oPixFmt==GUID_WICPixelFormat40bppCMYKAlpha)
       uPixFmt = 70;
    else if (oPixFmt==GUID_WICPixelFormat80bppCMYKAlpha)
       uPixFmt = 71;
    else if (oPixFmt==GUID_WICPixelFormat32bpp3ChannelsAlpha)
       uPixFmt = 72;
    else if (oPixFmt==GUID_WICPixelFormat40bpp4ChannelsAlpha)
       uPixFmt = 73;
    else if (oPixFmt==GUID_WICPixelFormat48bpp5ChannelsAlpha)
       uPixFmt = 74;
    else if (oPixFmt==GUID_WICPixelFormat56bpp6ChannelsAlpha)
       uPixFmt = 75;
    else if (oPixFmt==GUID_WICPixelFormat64bpp7ChannelsAlpha)
       uPixFmt = 76;
    else if (oPixFmt==GUID_WICPixelFormat72bpp8ChannelsAlpha)
       uPixFmt = 77;
    else if (oPixFmt==GUID_WICPixelFormat64bpp3ChannelsAlpha)
       uPixFmt = 78;
    else if (oPixFmt==GUID_WICPixelFormat80bpp4ChannelsAlpha)
       uPixFmt = 79;
    else if (oPixFmt==GUID_WICPixelFormat96bpp5ChannelsAlpha)
       uPixFmt = 80;
    else if (oPixFmt==GUID_WICPixelFormat112bpp6ChannelsAlpha)
       uPixFmt = 81;
    else if (oPixFmt==GUID_WICPixelFormat128bpp7ChannelsAlpha)
       uPixFmt = 82;
    else if (oPixFmt==GUID_WICPixelFormat144bpp8ChannelsAlpha)
       uPixFmt = 83;
    else if (oPixFmt==GUID_WICPixelFormat8bppY)
       uPixFmt = 84;
    else if (oPixFmt==GUID_WICPixelFormat8bppCb)
       uPixFmt = 85;
    else if (oPixFmt==GUID_WICPixelFormat8bppCr)
       uPixFmt = 86;
    else if (oPixFmt==GUID_WICPixelFormat16bppCbCr)
       uPixFmt = 87;
    else if (oPixFmt==GUID_WICPixelFormat16bppYQuantizedDctCoefficients)
       uPixFmt = 88;
    else if (oPixFmt==GUID_WICPixelFormat16bppCbQuantizedDctCoefficients)
       uPixFmt = 89;
    else if (oPixFmt==GUID_WICPixelFormat16bppCrQuantizedDctCoefficients)
       uPixFmt = 90;
    return uPixFmt;
}

INT indexedContainerFmts(GUID containerFmt) {
    INT ucontainerFmt = 0;
    if (containerFmt == GUID_ContainerFormatBmp)
       ucontainerFmt = 1;
    else if (containerFmt == GUID_ContainerFormatPng)
       ucontainerFmt = 2;
    else if (containerFmt == GUID_ContainerFormatIco)
       ucontainerFmt = 3;
    else if (containerFmt == GUID_ContainerFormatJpeg)
       ucontainerFmt = 4;
    else if (containerFmt == GUID_ContainerFormatTiff)
       ucontainerFmt = 5;
    else if (containerFmt == GUID_ContainerFormatGif)
       ucontainerFmt = 6;
    else if (containerFmt == GUID_ContainerFormatWmp)
       ucontainerFmt = 7;
    else if (containerFmt == GUID_ContainerFormatDds)
       ucontainerFmt = 8;
    else if (containerFmt == GUID_ContainerFormatAdng)
       ucontainerFmt = 9;
    else if (containerFmt == GUID_ContainerFormatHeif)
       ucontainerFmt = 10;
    else if (containerFmt == GUID_ContainerFormatWebp)
       ucontainerFmt = 11;
    else if (containerFmt == GUID_ContainerFormatRaw)
       ucontainerFmt = 12;
    return ucontainerFmt;
}

auto adaptImageGivenSize(UINT keepAratio, UINT ScaleAnySize, UINT imgW, UINT imgH, UINT givenW, UINT givenH) {
  std::array<UINT, 3> size;
  size[0] = 0;
  size[1] = 0;
  size[2] = 0;

  if (keepAratio==2)
  {
     size[0] = imgW;
     size[1] = imgH;
     size[2] = 1;
  } else if (keepAratio==1) 
  {
     if (imgW>givenW || imgH>givenH || ScaleAnySize==1)
     {
         double PicRatio = (float)(imgW)/imgH;
         double givenRatio = (float)(givenW)/givenH;
         if (imgW<=givenW && imgH<=givenH)
         {
            size[0] = givenW;
            size[1] = round(size[0] / PicRatio);
            if (size[1]>givenH)
            {
               size[1] = (imgH <= givenH) ? givenH : imgH;
               size[0] = round(size[1] * PicRatio);
            }
         } else if (PicRatio>givenRatio)
         {
            size[0] = givenW;
            size[1] = round(size[0] / PicRatio);
         } else
         {
            size[1] = (imgH >= givenH) ? givenH : imgH;
            size[0] = round(size[1] * PicRatio);
         }
     } else
     {
         size[0] = imgW;
         size[1] = imgH;
         size[2] = 1;
     }
  } else
  {
     size[0] = givenW;
     size[1] = givenH;
  }

  double mpx = (size[0] * size[1])/1000000;
  if (mpx>536.4)
  {
     float g = 536.4/mpx;
     size[0] = floor(size[0] * g);
     size[1] = floor(size[1] * g);
  }

  return size;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV LoadWICimage(int threadIDu, int noBPPconv, int givenQuality, UINT givenW, UINT givenH, UINT keepAratio, UINT ScaleAnySize, UINT givenFrame, int doFlip, int doGrayScale, const wchar_t *szFileName, UINT *resultsArray) {
    Gdiplus::GpBitmap  *myBitmap = NULL;

    WICBitmapInterpolationMode wicScaleQuality;
    if (givenQuality==5)
       wicScaleQuality = WICBitmapInterpolationModeNearestNeighbor;
    else if (givenQuality==2)
       wicScaleQuality = WICBitmapInterpolationModeLinear;
    else if (givenQuality==3)
       wicScaleQuality = WICBitmapInterpolationModeCubic;
    else if (givenQuality==7)
       wicScaleQuality = WICBitmapInterpolationModeHighQualityCubic;
    else
       wicScaleQuality = WICBitmapInterpolationModeFant;

    // std::stringstream ss;
    if (szFileName)
    {
        IWICBitmapSource   *m_pOriginalBitmapSource = NULL;
        IWICBitmapSource   *pToRenderBitmapSource = NULL;
        // IWICBitmapSource   *gToRenderBitmapSource = NULL;
        HRESULT hr = S_OK;
        HRESULT hr2 = S_OK;
        HRESULT hrFlip = S_SERDDR;
        HRESULT hrGray = S_SERDDR;
        IWICBitmapFlipRotator* pIFlipRotator = NULL;
        IWICFormatConverter* pConverterGray = NULL;

        // Step 0: Create WIC factory [ see initWICnow() ]
        // Step 1: Create a decoder
        // Decode the source image to IWICBitmapSource
        IWICBitmapDecoder *pDecoder = NULL;
        try {
            hr = m_pIWICFactory->CreateDecoderFromFilename(szFileName,                   // Image to be decoded
                                                        NULL,                            // Do not prefer a particular vendor
                                                        GENERIC_READ,                    // Desired read access to the file
                                                        WICDecodeMetadataCacheOnDemand,  // Cache metadata when needed
                                                        &pDecoder);                      // Pointer to the decoder
        } catch (const char* message) {
            std::stringstream ss;
            ss << "qpv: threadu - " << threadIDu << " WIC decoder error on file " << szFileName;
            ss << " WIC error " << message;
            OutputDebugStringA(ss.str().data());
            return myBitmap;
        }

        // Step 2: Retrieve the first frame of the image from the decoder
        IWICBitmapFrameDecode *pFrame = NULL;
        if (SUCCEEDED(hr))
        {
            UINT tFrames = 0;
            hr2 = pDecoder->GetFrameCount(&tFrames);
            resultsArray[2] = tFrames;
            if (givenFrame > tFrames - 1)
               givenFrame = tFrames - 1;

            hr = pDecoder->GetFrame(givenFrame, &pFrame);
            // std::stringstream ss;
            // ss << "qpv: threadu - " << threadIDu << " decoder tFrames " << tFrames;
            // ss << " givenFrame " << givenFrame;
            // OutputDebugStringA(ss.str().data());
        } else
        {
            std::stringstream ss;
            ss << "qpv: threadu - " << threadIDu << " WIC decoder error on file " << szFileName;
            OutputDebugStringA(ss.str().data());
            return myBitmap;
        };

        // Retrieve IWICBitmapSource from the frame
        // m_pOriginalBitmapSource contains the original bitmap and acts as an intermediate
        if (SUCCEEDED(hr))
        {
            // SafeRelease(m_pOriginalBitmapSource);
            GUID containerFmt;
            hr2 = pDecoder->GetContainerFormat(&containerFmt);
            UINT ucontainerFmt = indexedContainerFmts(containerFmt);
            resultsArray[5] = ucontainerFmt;

            hr = pFrame->QueryInterface(IID_IWICBitmapSource, 
                         reinterpret_cast<void **>(&m_pOriginalBitmapSource));

            // std::stringstream ss;
            // ss << "qpv: threadu - " << threadIDu << " get WIC frame image " << hr;
            // OutputDebugStringA(ss.str().data());
        }

        // Step 3: Scale the original IWICBitmapSource to the given size
        // and convert the pixel format
        // IWICBitmapSource *pToRenderBitmapSource = NULL;

        if (SUCCEEDED(hr))
        {
            // std::stringstream ss;
            // ss << "qpv: threadu - " << threadIDu << " collect image infos ";
            // OutputDebugStringA(ss.str().data());
            hr = S_OK;
            // IWICBitmapSource** ppToRenderBitmapSource = NULL;
            // *ppToRenderBitmapSource = NULL;

            UINT owidth = 0;
            UINT oheight = 0;
            hr2 = m_pOriginalBitmapSource->GetSize(&owidth, &oheight); 
            resultsArray[0] = owidth;
            resultsArray[1] = oheight;

            double dpix = 0;
            double dpiy = 0;
            hr2 = m_pOriginalBitmapSource->GetResolution(&dpix, &dpiy); 
            resultsArray[4] = round((dpix + dpiy)/2);

            WICPixelFormatGUID opixelFormat;
            hr2 = m_pOriginalBitmapSource->GetPixelFormat(&opixelFormat);
            UINT uPixFmt = indexedPixelFmts(opixelFormat);

            resultsArray[3] = uPixFmt;
            if (noBPPconv==1)
            {
               resultsArray[6] = 1;
               SafeRelease(pToRenderBitmapSource);
               SafeRelease(pDecoder);
               SafeRelease(pFrame);
               SafeRelease(m_pOriginalBitmapSource);
               return myBitmap;
            }

            if (SUCCEEDED(hr) && doGrayScale==1)
            {
               hrGray = m_pIWICFactory->CreateFormatConverter(&pConverterGray);
               if (SUCCEEDED(hr))
               {
                   hrGray = pConverterGray->Initialize(m_pOriginalBitmapSource,
                                     GUID_WICPixelFormat8bppGray,
                                     WICBitmapDitherTypeNone, NULL, 0.f,
                                     WICBitmapPaletteTypeCustom);
   
                   // if (SUCCEEDED(hrGray))
                   // {
                   //    hrGray = pConverterGray->QueryInterface(IID_IWICBitmapSource, 
                   //                  reinterpret_cast<void **>(&gToRenderBitmapSource));
                   // }
               }
            }

            if (SUCCEEDED(hr))
            {
                if (doFlip==4)
                {
                   hrFlip = m_pIWICFactory->CreateBitmapFlipRotator(&pIFlipRotator);
                   if (SUCCEEDED(hrFlip))
                   {
                      if (SUCCEEDED(hrGray))
                         pIFlipRotator->Initialize(pConverterGray, WICBitmapTransformFlipHorizontal);
                      else
                         pIFlipRotator->Initialize(m_pOriginalBitmapSource, WICBitmapTransformFlipHorizontal);
                   }
                }

                // Create a BitmapScaler
                IWICBitmapScaler* pScaler = NULL;
                hr = m_pIWICFactory->CreateBitmapScaler(&pScaler);
                // std::stringstream ss;
                // ss << "qpv: threadu - " << threadIDu << " scale image " << hr;
                // OutputDebugStringA(ss.str().data());

                // Initialize the bitmap scaler from the original bitmap map bits
                if (SUCCEEDED(hr))
                {
                    auto nSize = adaptImageGivenSize(keepAratio, ScaleAnySize, owidth, oheight, givenW, givenH);
                    if (nSize[2]==1)
                       wicScaleQuality = WICBitmapInterpolationModeNearestNeighbor;

                    if (SUCCEEDED(hrFlip))
                    {
                       hr = pScaler->Initialize(pIFlipRotator, nSize[0], nSize[1], wicScaleQuality);
                    } else
                    {
                       if (SUCCEEDED(hrGray))
                          hr = pScaler->Initialize(pConverterGray, nSize[0], nSize[1], wicScaleQuality);
                       else
                          hr = pScaler->Initialize(m_pOriginalBitmapSource, nSize[0], nSize[1], wicScaleQuality);
                    }

                    // std::stringstream ss;
                    // ss << "qpv: threadu - " << threadIDu << " scaled image to W/H " << nSize[0] << "," << nSize[1];
                    // ss << " - quality " << wicScaleQuality;
                    // ss << " - oW/H " << owidth << "," << oheight;
                    // ss << " - gW/H " << givenW << "," << givenH;
                    // OutputDebugStringA(ss.str().data());
                }

                // Format convert the bitmap into 32bppBGR, a convenient 
                // pixel format for GDI+ rendering 
                if (SUCCEEDED(hr))
                {
                    IWICFormatConverter* pConverter = NULL;
                    hr = m_pIWICFactory->CreateFormatConverter(&pConverter);
                    // std::stringstream ss;
                    // ss << "qpv: threadu - " << threadIDu << " do convert pix format h=" << oheight;
                    // OutputDebugStringA(ss.str().data());

                    // Format convert to 32bppBGR 
                    if (SUCCEEDED(hr))
                    {
                        hr = pConverter->Initialize(pScaler,            // Input bitmap to convert
                                          GUID_WICPixelFormat32bppPBGRA,// Destination pixel format
                                          WICBitmapDitherTypeNone,      // Specified dither patterm
                                          NULL,                         // Specify a particular palette 
                                          0.f,                          // Alpha threshold
                                          WICBitmapPaletteTypeCustom);  // Palette translation type

                        // std::stringstream ss;
                        // ss << "qpv: threadu - " << threadIDu << " converted pix format h=" << oheight;
                        // OutputDebugStringA(ss.str().data());
                        // Store the converted bitmap as pToRenderBitmapSource 
                        if (SUCCEEDED(hr))
                        {
                           hr = pConverter->QueryInterface(IID_IWICBitmapSource, 
                                            reinterpret_cast<void **>(&pToRenderBitmapSource));
                                            // IID_PPV_ARGS(ppToRenderBitmapSource));
                           // std::stringstream ss;
                           // ss << "qpv: threadu - " << threadIDu << " get bitmap converted format w=" << owidth;
                           // OutputDebugStringA(ss.str().data());
                        };
                    };

                    SafeRelease(pConverter);
                };

                SafeRelease(pScaler);
            };

        };

        // Step 4: Create a DIB from the converted IWICBitmapSource
        if (SUCCEEDED(hr))
        {
            HRESULT hr = S_OK;
            UINT width = 0;
            UINT height = 0;

            // Check BitmapSource format
            WICPixelFormatGUID pixelFormat;
            hr = pToRenderBitmapSource->GetPixelFormat(&pixelFormat);

            if (SUCCEEDED(hr))
               hr = (pixelFormat == GUID_WICPixelFormat32bppPBGRA) ? S_OK : E_FAIL;

            if (SUCCEEDED(hr))
               hr = pToRenderBitmapSource->GetSize(&width, &height); 

            // Size of a scan line represented in bytes: 4 bytes each pixel
            UINT cbStride = 0;
            if (SUCCEEDED(hr))
               hr = UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);

            // Size of the image, represented in bytes
            UINT cbBufferSize = 0;
            if (SUCCEEDED(hr))
               hr = UIntMult(cbStride, height, &cbBufferSize);

            // std::stringstream ss;
            // ss << "qpv: threadu - " << threadIDu << " convert to dib format stride=" << cbStride;
            // OutputDebugStringA(ss.str().data());
            if (SUCCEEDED(hr))
            {
                BYTE *m_pbBuffer = NULL;  // the GDI+ bitmap buffer
                m_pbBuffer = new BYTE[cbBufferSize];
                hr = (m_pbBuffer) ? S_OK : E_FAIL;

                // std::stringstream ss;
                // ss << "qpv: threadu - " << threadIDu << " prepared dib format buffer ";
                // OutputDebugStringA(ss.str().data());

                if (SUCCEEDED(hr))
                {
                    // WICRect rc = { 0, 0, width, height };
                    // Extract the image into the GDI+ Bitmap
                    hr = pToRenderBitmapSource->CopyPixels(NULL, cbStride, cbBufferSize, m_pbBuffer);

                    // std::stringstream ss;
                    // ss << "qpv: threadu - " << threadIDu << " convert to dib format copied pixels " << hr;
                    // OutputDebugStringA(ss.str().data());
                    if (SUCCEEDED(hr))
                    {
                       Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, cbStride, PixelFormat32bppPARGB, NULL, &myBitmap);
                       // std::stringstream ss;
                       // ss << "qpv: threadu - " << threadIDu << " created gdip image " << hr;
                       // OutputDebugStringA(ss.str().data());
                       Gdiplus::Rect rectu(0, 0, width, height);
                       Gdiplus::BitmapData bitmapDatu;
                       bitmapDatu.Width = width;
                       bitmapDatu.Height = height;
                       bitmapDatu.Stride = cbStride;
                       bitmapDatu.PixelFormat = PixelFormat32bppPARGB;
                       bitmapDatu.Scan0 = m_pbBuffer;

                       Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, 6, PixelFormat32bppPARGB, &bitmapDatu);
                       Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
                       hr = myBitmap ? S_OK : E_FAIL;

                       // std::stringstream sb;
                       // sb << "qpv: threadu - " << threadIDu << " filled gdip image " << hr;
                       // OutputDebugStringA(sb.str().data());
                    };
                };
                delete[] m_pbBuffer;
                m_pbBuffer = NULL; 
            };
        };

        // std::stringstream ss;
        // ss << "qpv: threadu - " << threadIDu << " do safe releases";
        // OutputDebugStringA(ss.str().data());
        SafeRelease(pToRenderBitmapSource);
        // SafeRelease(gToRenderBitmapSource);
        SafeRelease(pDecoder);
        SafeRelease(pConverterGray);
        SafeRelease(pIFlipRotator);
        SafeRelease(pFrame);
        SafeRelease(m_pOriginalBitmapSource);
        // SafeRelease(m_pIWICFactory);
        // CoUninitialize();
    };

/*
    std::wstring string_to_convert(szFileName);

    //setup converter
    using convert_type = std::codecvt_utf8<wchar_t>;
    std::wstring_convert<convert_type, wchar_t> converter;

    //use converter (.to_bytes: wstr->str, .from_bytes: str->wstr)
    std::string converted_str = converter.to_bytes( string_to_convert );

    // std::stringstream ss;
    ss << "qpv: threadu - " << threadIDu << " bmp file " << converted_str;
    OutputDebugStringA(ss.str().data());
*/
    return myBitmap;
}

DLL_API int DLL_CALLCONV initWICnow(UINT modus, int threadIDu) {
    HRESULT hr = S_OK;
    // to do - fix this; make it work on Windows 7 

    if (SUCCEEDED(hr))
    {
       hr = CoCreateInstance(CLSID_WICImagingFactory,
                    NULL, CLSCTX_INPROC_SERVER,
                    IID_PPV_ARGS(&m_pIWICFactory));
    }

    // source https://www.teamten.com/lawrence/graphics/gamma/
    static const float GAMMA = 2.2;
    int result;

    for (int i = 0; i < 256; i++) {
        result = (int)(pow(i/255.0, GAMMA)*32768.0 + 0.5);
        gamma_to_linear[i] = (unsigned short)result;
    }

    for (int i = 0; i < 32769; i++) {
        result = (int)(pow(i/32768.0, 1/GAMMA)*255.0 + 0.5);
        linear_to_gamma[i] = (unsigned char)result;
    }

    for (int i = 0; i < 256; i++) {
        char_to_float[i] = i/255.0f;
    }

    // std::stringstream ss;
    // ss << "qpv: threadu - " << threadIDu << " HRESULT " << hr;
    // OutputDebugStringA(ss.str().data());
    if (SUCCEEDED(hr))
       return 1;
    else 
       return 0;
}

int myRound(double x) {
    return (x<0) ? (int)(x-0.5) : (int)(x+0.5);
}

STATUS InsertJPEGFile2PDF(const char *fileName, int fileSize, PJPEG2PDF pdfId) {
  FILE *fp;
  unsigned char *jpegBuf;
  int readInSize; 
  unsigned short jpegImgW, jpegImgH;
  STATUS r = IDOK;

  jpegBuf = (unsigned char *)malloc(fileSize);
  fp = fopen(fileName, "rb");
  readInSize = (int)fread(jpegBuf, sizeof(UINT8), fileSize, fp);
  fclose(fp);

  if (readInSize != fileSize) 
     fnOutputDebug("file size in bytes mismatched: " + std::to_string(readInSize) + " / " + std::to_string(fileSize));

  // Add JPEG File into PDF
  if (1 == get_jpeg_size(jpegBuf, readInSize, &jpegImgW, &jpegImgH))
  {
     std::string s = fileName;
     r = Jpeg2PDF_AddJpeg(pdfId, jpegImgW, jpegImgH, readInSize, jpegBuf, 1);
     fnOutputDebug("Image dimensions: " + std::to_string(jpegImgW) + " x " + std::to_string(jpegImgH) + " | " + s);
  } else
  {
     std::string s = fileName;
     fnOutputDebug("failed to obtain image dimensions from file: " + s);
     r = ERROR;
  }

  free(jpegBuf);
  return r;
}

DLL_API int DLL_CALLCONV CreatePDFfile(const char* tempDir, const char* destinationPDFfile, const char* scriptDir, UINT *fListArray, int arraySize, float pageW, float pageH, int dpi) {
// based on https://www.codeproject.com/Articles/29879/Simplest-PDF-Generating-API-for-JPEG-Image-Content

  // Initializd the PDF Object with Page Size Information
  fnOutputDebug("function CreatePDFfile called" + std::to_string(pageW) + " x " + std::to_string(pageH) );
  PJPEG2PDF pdfId;
  pdfId = Jpeg2PDF_BeginDocument(pageW, pageH, dpi);
  if (pdfId < 0) 
     return -1;
 
  UINT32 pdfSize, pdfFinalSize;
  UINT8  *pdfBuf;

  int dirErr = 0;
  if (_chdir(tempDir))
  {
      switch (errno)
      {
        case ENOENT:
           dirErr = -2;
           break;
        case EINVAL:
           dirErr = -3;
           break;
        default:
           dirErr = -4;
      }
      return dirErr;
  }

  // Process the jpeg files
  fnOutputDebug("about to load images pointed by fListArray.size=" + std::to_string(arraySize));
  struct _finddata_t jpeg_file;
  long hFile;
  int somePagesError = 0;
  for (int i = 0; i < arraySize; ++i)
  {
      std::string s = std::to_string(fListArray[i]) + ".jpg";
      // const char * c = str.c_str();
      // fnOutputDebug("looping array " + std::to_string(i) + " file=" + s);
      if ( (hFile = _findfirst(s.c_str(), &jpeg_file )) == -1L )
         continue;
 
      // fnOutputDebug("found file: " + s);
      STATUS z = InsertJPEGFile2PDF(jpeg_file.name, jpeg_file.size, pdfId);
      if (z==ERROR)
      {
         fnOutputDebug("Failed to add image to PDF: " + s);
         somePagesError++;
      }
      _findclose( hFile );
  }

  // Finalize the PDF and get the PDF Size
  fnOutputDebug("Finalize the PDF and get the PDF Size");
  pdfSize = Jpeg2PDF_EndDocument(pdfId);
  // Prepare the PDF Data Buffer based on the PDF Size
  pdfBuf = (UINT8 * )malloc(pdfSize);

  // Get the PDF into the Data Buffer and do the cleanup
  fnOutputDebug("PDF size = " + std::to_string(pdfSize) + "; next function Jpeg2PDF_GetFinalDocumentAndCleanup()");
  // Output the PDF Data Buffer to file
  STATUS g = Jpeg2PDF_GetFinalDocumentAndCleanup(pdfId, pdfBuf, &pdfFinalSize, pdfSize);
  if (g=IDOK)
  {
     fnOutputDebug("writing PDF: final size =" + std::to_string(pdfFinalSize));
     FILE *fp = fopen(destinationPDFfile, "wb");
     if (fp!=NULL)
     {
        fwrite(pdfBuf, sizeof(UINT8), pdfFinalSize, fp);
        fclose(fp);
     } else 
     {
        fnOutputDebug("Failed to create PDF file");
        dirErr = -6;
     }
  } else 
  {
     fnOutputDebug("Failed to PDF GetFinalDocument");
     dirErr = -7;
  }

  _chdir(scriptDir);
  free(pdfBuf);
  if (dirErr == 0 && somePagesError != 0)
     dirErr = somePagesError;

  return dirErr;
}

Gdiplus::GpBitmap* CreateBitmapFromCImg(CImg<float> & img, int width, int height) {
    fnOutputDebug("CreateBitmapFromCImg called, yay");
    // Size of a scan line represented in bytes: 4 bytes each pixel
    UINT cbStride = 0;
    UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);

    // Size of the image, represented in bytes
    UINT cbBufferSize = 0;
    UIntMult(cbStride, height, &cbBufferSize);
    // hr = (m_pbBuffer) ? S_OK : E_FAIL;

    Gdiplus::GpBitmap  *myBitmap = NULL;
    Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, cbStride, PixelFormat32bppARGB, NULL, &myBitmap);
    BYTE *m_pbBuffer = NULL;  // the GDI+ bitmap buffer
    m_pbBuffer = new BYTE[cbBufferSize];
    // fnOutputDebug("gdip bmp created, yay");

    Gdiplus::Rect rectu(0, 0, width, height);
    Gdiplus::BitmapData bitmapDatu;
    bitmapDatu.Width = width;
    bitmapDatu.Height = height;
    bitmapDatu.Stride = cbStride;
    bitmapDatu.PixelFormat = PixelFormat32bppARGB;
    bitmapDatu.Scan0 = m_pbBuffer;
 
    Gdiplus::Status s = Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, 6, PixelFormat32bppARGB, &bitmapDatu);
    // Step through cimg and bitmap, copy values to bitmap.
    const int nPlanes = 4; // NOTE we assume alpha plane is the 4th plane.
    if (s == Gdiplus::Ok)
    {
        // fnOutputDebug("gdip bmp locked, yay");
        // fnOutputDebug("init vars for conversion; stride=" + std::to_string(dLineDest));
        BYTE *pStartDest = (BYTE *) bitmapDatu.Scan0;
        UINT dPixelDest = nPlanes;             // pixel step in destination
        UINT dLineDest = bitmapDatu.Stride;    // line step in destination
        #pragma omp parallel for schedule(dynamic)
        for (int y = 0; y < height; y++)
        {
            // loop through lines
            BYTE *pLineDest = pStartDest + dLineDest*y;
            BYTE    *pPixelDest = pLineDest;
            for (int x = 0; x < width; x++)
            {
                // loop through pixels on line
                // T & operator() (const unsigned int x, const unsigned int y=0, const unsigned int z=0, const unsigned int v=0) const
                // Fast access to pixel value for reading or writing.

                float    redCompF = img(x,y,0,0);
                if (redCompF < 0.0f)
                    redCompF = 0.0f;
                else if (redCompF > 255.0f)
                    redCompF = 255.0f;

                float    greenCompF = img(x,y,0,1);
                if (greenCompF < 0.0f)
                    greenCompF = 0.0f;
                else if (greenCompF > 255.0f)
                    greenCompF = 255.0f;

                float    blueCompF = img(x,y,0,2);
                if (blueCompF < 0.0f)
                    blueCompF = 0.0f;
                else if (blueCompF > 255.0f)
                    blueCompF = 255.0f;

                float    alphaCompF = img(x,y,0,3);
                if (alphaCompF < 0.0f)
                    alphaCompF = 0.0f;
                else if (alphaCompF > 255.0f)
                    alphaCompF = 255.0f;

                BYTE    redComp = BYTE(redCompF + 0.4999f);
                BYTE    greenComp = BYTE(greenCompF + 0.4999f);
                BYTE    blueComp = BYTE(blueCompF + 0.4999f);
                BYTE    alphaComp = BYTE(alphaCompF + 0.4999f);
                *(pPixelDest) = blueComp;
                *(pPixelDest+1) = greenComp;
                *(pPixelDest+2) = redComp;
                *(pPixelDest+3) = alphaComp;
                pPixelDest += dPixelDest;
            }
            // pLineDest += dLineDest;
        }
        // fnOutputDebug("for loops done");
        Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
        // fnOutputDebug("gdip bmp unlocked");
    }
    delete[] m_pbBuffer;
    m_pbBuffer = NULL; 

    return myBitmap;
}

int FillCImgFromBitmap(cimg_library::CImg<float> & img, Gdiplus::GpBitmap *myBitmap, int width, int height) {

    // fnOutputDebug("FillCImgFromBitmap called, yay");
    // Size of a scan line represented in bytes: 4 bytes each pixel
    UINT cbStride = 0;
    UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);

    // Size of the image, represented in bytes
    UINT cbBufferSize = 0;
    UIntMult(cbStride, height, &cbBufferSize);

    Gdiplus::Rect rectu(0, 0, width, height);
    Gdiplus::BitmapData bitmapDatu;
    Gdiplus::Status s = Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, 1, PixelFormat32bppARGB, &bitmapDatu);
    // fnOutputDebug("bits locked: FillCImgFromBitmap()");
    if (s == Gdiplus::Ok)
    {
        // fnOutputDebug("for loops begin: FillCImgFromBitmap(); w=" + std::to_string(nPixels) + "; h=" + std::to_string(nLines) );
        // fnOutputDebug("moar; stride=" + std::to_string(dLineSrc) + "/scan0=" + std::to_string(*pStartSrc));
        BYTE *pStartSrc = (BYTE *) bitmapDatu.Scan0;
        UINT dPixelSrc = 4;          // pixel step in source ; nPlanes
        UINT dLineSrc = cbStride;    // line step in source
        #pragma omp parallel for schedule(dynamic)
        for (int y = 0; y < height; y++)
        {
            // loop through lines
            BYTE *pLineSrc = pStartSrc + dLineSrc*y;
            BYTE    *pPixelSrc = pLineSrc;
            // fnOutputDebug("Y loop: " + std::to_string(y) + "//stride=" + std::to_string(dLineSrc));
            for (int x = 0; x < width; x++)
            {
                // loop through pixels on line
                BYTE    alphaComp = *(pPixelSrc+3);
                BYTE    redComp = *(pPixelSrc+2);
                BYTE    greenComp = *(pPixelSrc+1);
                BYTE    blueComp = *(pPixelSrc+0);
                img(x,y,0,0) = float(redComp);
                img(x,y,0,1) = float(greenComp);
                img(x,y,0,2) = float(blueComp);
                img(x,y,0,3) = float(alphaComp);
                pPixelSrc += dPixelSrc;
                // fnOutputDebug("x loop B: " + std::to_string(x));
            }
            // pLineSrc += dLineSrc;
        }
        // fnOutputDebug("for loops done: FillCImgFromBitmap()");
        Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
        // fnOutputDebug("gdip bmp unlocked: FillCImgFromBitmap()");
        return 1;
    } else return 0;
}


DLL_API Gdiplus::GpBitmap* DLL_CALLCONV AddGaussianNoiseOnBitmap(Gdiplus::GpBitmap *myBitmap, int width, int height, int intensity) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;

  img.noise(intensity, 0);
  newBitmap = CreateBitmapFromCImg(img, width, height);
  return newBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV SharpenBitmap(Gdiplus::GpBitmap *myBitmap, int width, int height, int intensity, int typ, float edge, float ralph, float flegma) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;

  img.sharpen(intensity, typ, edge, ralph, flegma);
  newBitmap = CreateBitmapFromCImg(img, width, height);
  return newBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV BlurBitmapFilters(Gdiplus::GpBitmap *myBitmap, int width, int height, int intensityX, int intensityY, int modus, int circle, int preview) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  int ow = width;  int oh = height;

  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;

  if (preview==1)
  {
     width /=2;          height /=2;
     intensityX /=2;     intensityY /=2;
     img.resize(width,height, -100, -100, 3);
  }

  CImg<unsigned char> shape(intensityX,intensityX,1,3,0);
  const unsigned char clr[] = {254, 254, 254};
  if (circle==1)
  {
     shape.draw_circle(intensityX/2, intensityX/2, intensityX/2, clr);
     // shape.blur(3, 3, 0, 1, 3);
     if (intensityX!=intensityY)
        shape.resize(intensityX, intensityY);
  }

  if (modus==1)
  {
     img.blur_box(intensityX, intensityY, 0, 3);
  } else if (modus==2)
  {
     if (circle==1)
        img.dilate(shape);
     else
        img.dilate(intensityX, intensityY, 1);
  } else if (modus==3)
  {
     if (circle==1)
        img.erode(shape);
     else
        img.erode(intensityX, intensityY, 1);
  } else if (modus==4)
  {
     if (circle==1)
        img.opening(shape);
     else
        img.opening(intensityX, intensityY, 1);
  } else if (modus==5)
  {
     if (circle==1)
        img.closing(shape);
     else
        img.closing(intensityX, intensityY, 1);
  } else
  {
     img.blur(intensityX, intensityY, 0, 1, 3);
  }

  if (circle==1)
     img.blur(3, 3, 0, 1, 3);

  if (preview==1)
     img.resize(ow, oh, -100, -100, 3);

  newBitmap = CreateBitmapFromCImg(img, ow, oh);
  return newBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV cImgRotateBitmap(Gdiplus::GpBitmap *myBitmap, int width, int height, float angle, int interpolation, int bond) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;

  img.rotate(angle, interpolation, bond);

  newBitmap = CreateBitmapFromCImg(img, img.width(), img.height());
  return newBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV cImgResizeBitmap(Gdiplus::GpBitmap *myBitmap, int width, int height, int resizedW, int resizedH, int interpolation, int bond) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;

  img.resize(resizedW, resizedH, -100, -100, interpolation, bond);

  newBitmap = CreateBitmapFromCImg(img, img.width(), img.height());
  return newBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV GenerateCIMGnoiseBitmap(int width, int height, int intensity, int details, int scale, int blurX, int blurY, int doBlur) {
  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);

  img.draw_plasma((float)intensity/2.0f, (float)details/2.0f, (float)scale/9.5f);
  if (doBlur==1)
     img.blur(blurX, blurY, 0, 1, 2);

  newBitmap = CreateBitmapFromCImg(img, width, height);
  return newBitmap;
}


DLL_API int DLL_CALLCONV dissolveBitmap(int *imageData, int *newData, int Width, int Height, int rx, int ry) {
      // fnOutputDebug("maxR===" + std::to_string(maxuRadius) + "; rS=" + std::to_string(rScale) + "; imgAR=" + std::to_string(imgAR));
      const UINT maxPixels = Width + Height * Width;
      std::vector<bool> pixelzMap(maxPixels, 0);
      time_t nTime;
      srand((unsigned) time(&nTime));

      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            int gx = rand() % (rx*2) - rx;
            int gy = rand() % (ry*2) - ry;
            int dx = clamp(x + gx, 0, Width - 1);
            int dy = clamp(y + gy, 0, Height - 1);
            if (pixelzMap[dx + dy*Width]==1)
            {
               gx = rand() % (rx*2) - rx;
               gy = rand() % (ry*2) - ry;
               dx = clamp(x + gx, 0, Width - 1);
               dy = clamp(y + gy, 0, Height - 1);
            }

            pixelzMap[dx + dy*Width] = 1;
            newData[x + y*Width] = imageData[dx + (dy * Width)];
         }
      }

      if (rx>35 || ry>35)
      {
          #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
          for (int y = 0; y < Height; y++)
          {
             for (int x = 0; x < Width; x++)
             {
                int gx = rand() % (rx*2) - rx;
                int gy = rand() % (ry*2) - ry;
                int dx = clamp(x + gx, 0, Width - 1);
                int dy = clamp(y + gy, 0, Height - 1);
                if (pixelzMap[dx + dy*Width]==1)
                {
                   gx = rand() % (rx*2) - rx;
                   gy = rand() % (ry*2) - ry;
                   dx = clamp(x + gx, 0, Width - 1);
                   dy = clamp(y + gy, 0, Height - 1);
                }

                pixelzMap[dx + dy*Width] = 1;
                newData[x + y*Width] = imageData[dx + (dy * Width)];
            }
          }
      }

      if (rx>350 || ry>350)
      {
          #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
          for (int y = 0; y < Height; y++)
          {
             for (int x = 0; x < Width; x++)
             {
                int gx = rand() % (rx*2) - rx;
                int gy = rand() % (ry*2) - ry;
                int dx = clamp(x + gx, 0, Width - 1);
                int dy = clamp(y + gy, 0, Height - 1);
                if (pixelzMap[dx + dy*Width]==1)
                {
                   gx = rand() % (rx*2) - rx;
                   gy = rand() % (ry*2) - ry;
                   dx = clamp(x + gx, 0, Width - 1);
                   dy = clamp(y + gy, 0, Height - 1);
                }

                pixelzMap[dx + dy*Width] = 1;
                newData[x + y*Width] = imageData[dx + (dy * Width)];
            }
          }
      }

      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            if (pixelzMap[x + y*Width]!=1)
               newData[x + y*Width] = imageData[x + (y * Width)];
        }
      }
      return 1;
}

DLL_API int DLL_CALLCONV symmetricaBitmap(int *imageData, int Width, int Height, int rx, int ry) {
// only works with 32-ARGB bitmaps 

      if (rx>0)
      {
         #pragma omp parallel for schedule(static) default(none) // num_threads(3)
         for (int y = 0; y < Height; y++)
         {
            // fnOutputDebug("y=" + std::to_string(y) + "; rx=" + std::to_string(rx));
            int p = -1;
            for (int x = 0; x < Width; x++)
            {
               if (x>=rx)
               {
                  p++;
                  int gx = (p>=rx) ? clamp(x - rx*2, 0, Width - 1) : clamp(rx - p, 0, Width - 1);
                  // fnOutputDebug(std::to_string(p) + "=p; x="  +  std::to_string(x) + "; gx=" + std::to_string(gx));
                  imageData[x + y*Width] = imageData[gx + (y * Width)];
               }
            }
            p = 0;
         }
      }

      if (ry>0)
      {
         #pragma omp parallel for schedule(static) default(none) // num_threads(3)
         for (int x = 0; x < Width; x++)
         {
            // fnOutputDebug("y=" + std::to_string(y) + "; rx=" + std::to_string(rx));
            int p = -1;
            for (int y = 0; y < Height; y++)
            {
               if (y>=ry)
               {
                  p++;
                  int gy = (p>=ry) ? clamp(y - ry*2, 0, Height - 1) : clamp(ry - p, 0, Height - 1);
                  // fnOutputDebug(std::to_string(p) + "=p; x="  +  std::to_string(x) + "; gx=" + std::to_string(gx));
                  imageData[x + y*Width] = imageData[x + (gy * Width)];
               }
            }
            p = 0;
         }
      }

      return 1;
}


DLL_API int DLL_CALLCONV autoContrastBitmap(int *imageData, int *miniData, int Width, int Height, int mw, int mh, int modus, int intensity) {
      int maxRLevel = 0;      int minRLevel = 255;
      int maxGLevel = 0;      int minGLevel = 255;
      int maxBLevel = 0;      int minBLevel = 255;
      for (int y = 0; y < mh; y++)
      {
         for (int x = 0; x < mw; x++)
         {
            if (modus==2)
            {
               int aR = (miniData[x + (y * mw)] >> 16) & 0xFF; // red
               int aB = (miniData[x + (y * mw)] >> 0) & 0xFF;  // blue
               maxRLevel = max(aR, maxRLevel);    minRLevel = min(aR, minRLevel);
               maxBLevel = max(aB, maxBLevel);    minBLevel = min(aB, minBLevel);
            }

            int aG = (miniData[x + (y * mw)] >> 8) & 0xFF;  // green
            maxGLevel = max(aG, maxGLevel);    minGLevel = min(aG, minGLevel);
         }
      }
      if ((maxGLevel==minGLevel || maxGLevel==0 && minGLevel==255) && modus==1)
         return 1;

      minGLevel = clamp(minGLevel - intensity, 0, 255);
      maxGLevel = clamp(maxGLevel + intensity, 0, 255);
      maxGLevel -= minGLevel;
      double fG = 255.0f / maxGLevel;
      double fR = fG;
      double fB = fG;
      if (modus==2)
      {
         minRLevel = clamp(minRLevel - intensity, 0, 255);
         maxRLevel = clamp(maxRLevel + intensity, 0, 255);
         minBLevel = clamp(minBLevel - intensity, 0, 255);
         maxBLevel = clamp(maxBLevel + intensity, 0, 255);
         maxRLevel -= minRLevel;
         fR = 255.0f / maxRLevel;
         maxBLevel -= minBLevel;
         fB = 255.0f / maxBLevel;
      } else
      {
         minRLevel = minGLevel;
         minBLevel = minGLevel;
         maxRLevel = maxGLevel;
         maxBLevel = maxGLevel;
      }

      // fnOutputDebug("maxL===" + std::to_string(maxRLevel) + "; minL=" + std::to_string(minRLevel) + "; fR=" + std::to_string(fR) + "; m=" + std::to_string(modus));
      // fnOutputDebug("maxL===" + std::to_string(maxGLevel) + "; minL=" + std::to_string(minGLevel) + "; fG=" + std::to_string(fG)  );
      // fnOutputDebug("maxL===" + std::to_string(maxBLevel) + "; minL=" + std::to_string(minBLevel) + "; fB=" + std::to_string(fB)  );
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            int tR, tG, tB;
            int colorO = imageData[x + (y * Width)];
            // fnOutputDebug("x===" + std::to_string(x) + "; y=" + std::to_string(y));
            int aO = (colorO >> 24) & 0xFF;
            float rO = round( ((float)((colorO >> 16) & 0xFF) - minRLevel)*fR  );
            float gO = round( ((float)((colorO >> 8) & 0xFF) - minGLevel)*fG  );
            float bO = round( ((float)(colorO & 0xFF) - minBLevel)*fB  );
            tR = clamp((int)rO, 0, 255);
            tG = clamp((int)gO, 0, 255);
            tB = clamp((int)bO, 0, 255);

            // imageData[x + (y * Width)] = 0;
            imageData[x + (y * Width)] = (aO << 24) | (tR << 16) | (tG << 8) | tB;
         }
      }
      return 1;
}

DLL_API int DLL_CALLCONV rect2polarIMG(int *imageData, int *newData, int Width, int Height, double cx, double cy, double userScale) {
// inspired by https://imagej.nih.gov/ij/plugins/polar-transformer.html
      double maxuRadius = 0;
      double minBoundary = min(Width, Height);

      #pragma omp parallel for schedule(dynamic) default(none) shared(maxuRadius) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            double px = x - cx;     double py = y - cy;
            double r = sqrt(px*px + py*py);
            if (r<0)
               r = 0;

            maxuRadius = max(r, maxuRadius);
        }
      }

      double desiredRadius = minBoundary/2;
      double rScale = maxuRadius/desiredRadius;

      // fnOutputDebug("maxR===" + std::to_string(maxuRadius) + "; rS=" + std::to_string(rScale) + "; imgAR=" + std::to_string(imgAR));
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height; y++)
      {
         for (int x = 0; x < Width; x++)
         {
            double angle = 0;
            double px = x - cx;     double py = y - cy;
            double r = sqrt(px*px + py*py);
            // if ((y - cy)<=0)
            //    angle = 2*M_PI + atan2(y - cy, x - cx);
            // else
               angle = atan2(py, px);

            angle = rad2deg(angle) + 90;
            if (angle<0)
               angle += 360;
            // double zx = r*cos(angle);
            // double zy = r*sin(angle);
            int dx = (angle / 360.0f) * Width;
            int dy = (r / maxuRadius) * Height * rScale * userScale;
            dx = clamp(dx, 0, Width - 1);
            dy = clamp(dy, 0, Height - 1);
            newData[x + y*Width] = imageData[dx + (dy * Width)];
        }
      }
      return (int)maxuRadius;
}


DLL_API int DLL_CALLCONV polar2rectIMG(int *imageData, int *newData, int Width, int Height, double cx, double cy, double userScale) {
// TO-DO: this is an absolutely dumb implementation; I do not know how to optimize it
// inspired by https://imagej.nih.gov/ij/plugins/polar-transformer.html

      double maxuRadius = 0;
      double minBoundary = min(Width, Height);

      // identify the maximum radius
      // #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < Height*2; y++)
      {
         for (int x = 0; x < Width*2; x++)
         {
            double px = x/2.0f - cx;     double py = y/2.0f - cy;
            double r = sqrt(px*px + py*py);
            if (r<0)
               r = 0;

            maxuRadius = max(r, maxuRadius);
        }
      }

      double desiredRadius = minBoundary/2;
      double rScale = maxuRadius/desiredRadius;
      const UINT maxPixels = Width + Height * Width;
      // int *pixelzMap{ new int[maxPixels]{} };  // dynamically allocated array
      // memset(pixelzMap, -1, maxPixels * sizeof(int*)); // and fill it with -1
      // std::fill(pixelzMap, pixelzMap + maxPixels, -1); 
      std::vector<int> pixelzMap(maxPixels, -1);
      double imgAR = Width/Height;
      if (imgAR<1)
         imgAR = 1;

      // fill image with accuracy 2x, 4x, 8x, 16x and 32x
      // the upper sections of the image need high accuracy
      double acX = 1.0;
      double acY = 1.0;
      int ph = Height;
      int pw = Width;


      acX = 2.0;       acY = 2.0;
      ph = Height*acY; pw = Width*acX;
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < ph; y++)
      {
         // if (y>=ph*0.425)
         //   continue;
         for (int x = 0; x < pw; x++)
         {
            if (x>=pw*0.41 && x<=pw*0.59)
              continue;

            double angle = 0;
            double px = (double)x/acX - cx;     double py = (double)y/acY - cy;
            double r = sqrt(px*px + py*py);
            // if ((y - cy)<=0)
            //    angle = 2*M_PI + atan2(y - cy, x - cx);
            // else
               angle = atan2(py, px);

            angle = rad2deg(angle) + 90;
            if (angle<0)
               angle += 360;

            int dx = (angle / 360.0f) * Width;
            int dy = (r / maxuRadius) * Height * rScale * userScale;
            dx = clamp(dx, 0, Width - 1);
            dy = clamp(dy, 0, Height - 1);

            int zx = x/acX; int zy = y/acY;
            zx = clamp(zx, 0, Width - 1);
            zy = clamp(zy, 0, Height - 1);

            pixelzMap[dx + dy*Width] = zx;
            newData[dx + dy*Width] = imageData[zx + (zy * Width)];
        }
      }

      acX = 4.0;       acY = 4.0;
      ph = Height*acY; pw = Width*acX;
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < ph; y++)
      {
         // if (y>ph*0.455)
         //   continue;
         for (int x = 0; x < pw; x++)
         {
            if (x<pw*0.4)
              continue;
            if (x>pw*0.6)
              continue;

            double px = (double)x/acX - cx;     double py = (double)y/acY - cy;
            double r = sqrt(px*px + py*py);
            double angle = atan2(py, px);
            angle = rad2deg(angle) + 90;
            if (angle<0)
               angle += 360;

            int dx = (angle / 360.0f) * Width;
            int dy = (r / maxuRadius) * Height * rScale * userScale;
            dx = clamp(dx, 0, Width - 1);
            dy = clamp(dy, 0, Height - 1);

            int zx = x/acX; int zy = y/acY;
            zx = clamp(zx, 0, Width - 1);
            zy = clamp(zy, 0, Height - 1);

            pixelzMap[dx + dy*Width] = zx;
            newData[dx + dy*Width] = imageData[zx + (zy * Width)];
        }
      }

      acX = 8.0;       acY = 8.0;
      ph = Height*acY; pw = Width*acX;
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < ph; y++)
      {
         if (y<ph*0.45)
           continue;
         for (int x = 0; x < pw; x++)
         {
            if (x<pw*0.45)
              continue;
            if (x>pw*0.55)
              continue;

            double px = (double)x/acX - cx;     double py = (double)y/acY - cy;
            double r = sqrt(px*px + py*py);
            double angle = atan2(py, px);
            angle = rad2deg(angle) + 90;
            if (angle<0)
               angle += 360;

            int dx = (angle / 360.0f) * Width;
            int dy = (r / maxuRadius) * Height * rScale * userScale;
            dx = clamp(dx, 0, Width - 1);
            dy = clamp(dy, 0, Height - 1);

            int zx = x/acX; int zy = y/acY;
            zx = clamp(zx, 0, Width - 1);
            zy = clamp(zy, 0, Height - 1);

            pixelzMap[dx + dy*Width] = zx;
            newData[dx + dy*Width] = imageData[zx + (zy * Width)];
        }
      }

      acX = 16.0;      acY = 16.0;
      ph = Height*acY; pw = Width*acX;
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < ph; y++)
      {
         if (y<ph*0.47)
           continue;
         for (int x = 0; x < pw; x++)
         {
            if (x<pw*0.47)
              continue;
            if (x>pw*0.53)
              continue;

            double px = (double)x/acX - cx;     double py = (double)y/acY - cy;
            double r = sqrt(px*px + py*py);
            double angle = atan2(py, px);
            angle = rad2deg(angle) + 90;
            if (angle<0)
               angle += 360;

            int dx = (angle / 360.0f) * Width;
            int dy = (r / maxuRadius) * Height * rScale * userScale;
            dx = clamp(dx, 0, Width - 1);
            dy = clamp(dy, 0, Height - 1);

            int zx = x/acX; int zy = y/acY;
            zx = clamp(zx, 0, Width - 1);
            zy = clamp(zy, 0, Height - 1);

            pixelzMap[dx + dy*Width] = zx;
            newData[dx + dy*Width] = imageData[zx + (zy * Width)];
        }
      }

      acX = 32.0;       acY = 32.0;
      ph = Height*acY;  pw = Width*acX;
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 0; y < ph; y++)
      {
         if (y<ph*0.49)
           continue;
         for (int x = 0; x < pw; x++)
         {
            if (x<pw*0.49)
              continue;
            if (x>pw*0.51)
              continue;

            double px = (double)x/acX - cx;     double py = (double)y/acY - cy;
            double r = sqrt(px*px + py*py);
            double angle = atan2(py, px);
            angle = rad2deg(angle) + 90;
            if (angle<0)
               angle += 360;

            int dx = (angle / 360.0f) * Width;
            int dy = (r / maxuRadius) * Height * rScale * userScale;
            dx = clamp(dx, 0, Width - 1);
            dy = clamp(dy, 0, Height - 1);

            int zx = x/acX; int zy = y/acY;
            zx = clamp(zx, 0, Width - 1);
            zy = clamp(zy, 0, Height - 1);

            pixelzMap[dx + dy*Width] = zx;
            newData[dx + dy*Width] = imageData[zx + (zy * Width)];
        }
      }

      int failed = 0; int fixt = 0;
      // fill missing pixels; silly algorithm
      #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
      for (int y = 1; y < Height - 1; y++)
      {
         for (int x = 1; x < Width - 1; x++)
         {
               int px = x + y*Width;
               if (pixelzMap[px]==-1)
               {
                   fixt++;
                   if (pixelzMap[x-1 + y*Width]==(x-1))
                   {
                      pixelzMap[px] = pixelzMap[x-1 + y*Width];
                      newData[px] = newData[x-1 + (y * Width)];
                   } else if (pixelzMap[x+1 + y*Width]==(x+1))
                   {
                      pixelzMap[px] = pixelzMap[x+1 + y*Width];
                      newData[px] = newData[x+1 + (y * Width)];
                   } else if (pixelzMap[x + (y-1)*Width]==x)
                   {
                      pixelzMap[px] = pixelzMap[x + (y-1)*Width];
                      newData[px] = newData[x + ((y-1) * Width)];
                   } else if (pixelzMap[x + (y+1)*Width]==x)
                   {
                      pixelzMap[px] = pixelzMap[x + (y+1)*Width];
                      newData[px] = newData[x + ((y+1) * Width)];
                   } else if (pixelzMap[x + (y-1)*Width]>=0)
                   {
                      pixelzMap[px] = pixelzMap[x + (y-1)*Width];
                      newData[px] = newData[x + ((y-1) * Width)];
                   } else if (pixelzMap[x + (y+1)*Width]>=0)
                   {
                      pixelzMap[px] = pixelzMap[x + (y+1)*Width];
                      newData[px] = newData[x + ((y+1) * Width)];
                   } else if (pixelzMap[x-1 + y*Width]>=0)
                   {
                      pixelzMap[px] = pixelzMap[x-1 + y*Width];
                      newData[px] = newData[x-1 + (y * Width)];
                   } else if (pixelzMap[x+1 + y*Width]>=0)
                   {
                      pixelzMap[px] = pixelzMap[x+1 + y*Width];
                      newData[px] = newData[x+1 + (y * Width)];
                   } else 
                      failed++;
               }
        }
      }

      fixt -= failed;
      // fnOutputDebug("failed= " + std::to_string(failed) + " yay= " + std::to_string(fixt));
      int y = 0;
      for (int x = 1; x < Width - 1; x++)
      {
          int px = x + y*Width;
          if (pixelzMap[px]==-1)
          {
              fixt++;
              pixelzMap[px] = pixelzMap[x-1 + y*Width];
              newData[px] = newData[x-1 + (y * Width)];
          }
      }

      y = Height - 1;
      for (int x = 1; x < Width - 1; x++)
      {
          int px = x + y*Width;
          if (pixelzMap[px]==-1)
          {
              fixt++;
              pixelzMap[px] = pixelzMap[x-1 + y*Width];
              newData[px] = newData[x-1 + (y * Width)];
          }
      }

      // delete[] pixelzMap;
      return (int)maxuRadius;
}

DLL_API int DLL_CALLCONV SetTabletPenServiceProperties(HWND hWnd) {
    // https://learn.microsoft.com/en-us/windows/win32/tablet/wm-tablet-querysystemgesturestatus-message
    ATOM atom = ::GlobalAddAtom(MICROSOFT_TABLETPENSERVICE_PROPERTY);    
    ::SetProp(hWnd, MICROSOFT_TABLETPENSERVICE_PROPERTY, reinterpret_cast<HANDLE>(dwHwndTabletProperty));
    ::GlobalDeleteAtom(atom);
    return 1;
}        

/*
DLL_API Gdiplus::GpBitmap* DLL_CALLCONV testCimgQPV(Gdiplus::GpBitmap *myBitmap, int width, int height, int intensityX, int intensityY, int modus) {

    // Load input image files, using the CImg Library.
    Gdiplus::GpBitmap *newBitmap = NULL;
    CImg<float> img(width,height,1,4);
    int r = FillCImgFromBitmap(img, myBitmap, width, height);
    if (r==0)
       return newBitmap;

    // Move input images into a list.
    CImgList<float> image_list;
    img.move_to(image_list);

    // Define the corresponding image names.
    CImgList<char> image_names;
    CImg<char>::string("First image").move_to(image_names);

    // Invoke libgmic to execute a G'MIC pipeline.
    gmic("blur_angular 2% name \"Result image\"", image_list, image_names);

    // Display resulting image.
    const char *const title_bar = image_names[0];
    image_list.display(title_bar);

    newBitmap = CreateBitmapFromCImg(img, width, height);
    return newBitmap;
}


DLL_API Gdiplus::GpBitmap* DLL_CALLCONV testOtherCimgQPV(Gdiplus::GpBitmap *myBitmap, int width, int height, int intensityX, int intensityY, int modus) {
  // width = 129;
  // height = 129;
  // CImg<float> img(129,129,1,3,"0,64,128,192,255",true); // Construct image from a value sequence
  //             img2(129,129,1,3,"if(c==0,255*abs(cos(x/10)),1.8*y)",false); // Construct image from a formula
  // (img1,img2).display();

  Gdiplus::GpBitmap *newBitmap = NULL;
  CImg<float> img(width,height,1,4);
  int r = FillCImgFromBitmap(img, myBitmap, width, height);
  if (r==0)
     return newBitmap;
  char k = 'x';

  // if (modus==1)
  //    img.blur_median(intensityX, 3);   // size, distance threshold
  if (modus==2)
     img.blur_guided(img, intensityX, intensityY/2);     // guide, radius, regularization
  // else if (modus==3)
  //    img.vanvliet(intensityX, 1, k);       // sigma, order, axis
  else if (modus==4)
     img.dilate(intensityX, intensityY, 1);
  else if (modus==5)
     img.erode(intensityX, intensityY, 1);
  else if (modus==6)
     img.opening(intensityX, intensityY, 1);
  else if (modus==7)
     img.closing(intensityX, intensityY, 1);
  else if (modus==8)
     img.normalize(intensityX, intensityY);  // min.val , max.val
  else if (modus==9)
     img.equalize(255, intensityX, intensityY);   // nr.levels , min.val , max.val
  else if (modus==10)
     img.threshold(intensityX);         // value, soft, strict
  else if (modus==11)
     img.quantize(intensityX, 1);   // nr.levels, keepRange
  else if (modus==12)
     img.warp(img);          /// img, mode, interpolation
  else if (modus==13)
     img.watershed(img);
  else
     return newBitmap;

// img.display();

// warp()
// Vanvliet()
// edges()
// deriche()
// blur_angular()
// blur_radial()
// blur_linear()
// deblur()
// syntexturize()
// sharpen()
// watershed()
// noise_perlin()
// rorschach()
// turbulence()
// polka_dots()
// voronoi()
// maze()
// mosaic()
// boxfitting()
// fractalize()
// houghsketchbw()
// stained_glass()
// stencil()
// cubism()
// sponge()
// deform()
// kaleidoscope()
// twirl()
// ripple()
// water()
// spherize()
// fisheye()
// wave()
// wind()
// raindrops()

  newBitmap = CreateBitmapFromCImg(img, width, height);
  // ~Cimg(img);
  return newBitmap;
}

*/


/*
DLL_API Gdiplus::GpBitmap* DLL_CALLCONV testFunc(UINT width, UINT height, const wchar_t *szFileName) {
    Gdiplus::GpBitmap* myBitmap = NULL;
    Gdiplus::DllExports::GdipCreateBitmapFromFile(szFileName, &myBitmap);
    // Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, 0, PixelFormat32bppRGB, NULL, &myBitmap);

    std::wstring string_to_convert(szFileName);

    //setup converter
    using convert_type = std::codecvt_utf8<wchar_t>;
    std::wstring_convert<convert_type, wchar_t> converter;

    //use converter (.to_bytes: wstr->str, .from_bytes: str->wstr)
    std::string converted_str = converter.to_bytes( string_to_convert );

    std::stringstream ss;
    ss << "qpv: bmp file " << converted_str;
    OutputDebugStringA(ss.str().data());
    return myBitmap;
}
*/


/*
DLL_API int DLL_CALLCONV testFuncNow(int givenQuality, UINT width, UINT height, const wchar_t *szFileName, const wchar_t *szFileNameOut) {
  //  VImage in = VImage::new_from_file (szFileName,
  //   VImage::option ()->set ("access", VIPS_ACCESS_SEQUENTIAL));

  // double avg = in.avg ();

  // printf ("avg = %g\n", avg);
  // printf ("width = %d\n", in.width ());
  in = VImage::new_from_file (szFileName,
    VImage::option ()->set ("access", VIPS_ACCESS_SEQUENTIAL));

  VImage out = in.embed (10, 10, 1000, 1000,
    VImage::option ()->
      set ("extend", "background")->
      set ("background", 128));

  out.write_to_file (szFileNameOut);

  vips_shutdown ();
  return 1
}
*/


/*
DLL_API int DLL_CALLCONV BlurImage(unsigned char *Bitmap, int width, int height, int Stride, int radius) {
// https://stackoverflow.com/questions/47209262/c-blur-effect-on-bit-map-is-working-but-colors-are-changed

    float rs = ceil(radius * 2.57);
    for (int i = 0; i < height; ++i)
    {
        for (int j = 0; j < width; ++j)
        {
            int tempCoord;
            double a = 0, r = 0, g = 0, b = 0;
            double count = 0;

            for (int iy = i - rs; iy < i + rs + 1; ++iy)
            {
                for (int ix = j - rs; ix < j + rs + 1; ++ix)
                {
                    auto x = min(width - 1, max(0, ix));
                    auto y = min(height - 1, max(0, iy));

                    auto dsq = ((ix - j) * (ix - j)) + ((iy - i) * (iy - i));
                    float wght = std::exp(-dsq / (2.0 * radius * radius)) / (M_PI * 2.0 * radius * radius);

                    tempCoord = (4 * x) + y*Stride;
                    a = Bitmap[3 + tempCoord] * wght;
                    r = Bitmap[2 + tempCoord] * wght;
                    g = Bitmap[1 + tempCoord] * wght;
                    b = Bitmap[tempCoord] * wght;
                    // rgb32* pixel = bmp->getPixel(x, y);
                    // r += pixel->r * wght;
                    // g += pixel->g * wght;
                    // b += pixel->b * wght;
                    count += wght;
                }
            }

            tempCoord = (4 * j) + i*Stride;
            // if a
               Bitmap[3 + tempCoord] = round(a);
            // if r
               Bitmap[2 + tempCoord] = round(r);
            // if g
               Bitmap[1 + tempCoord] = round(g);
            // if b
               Bitmap[tempCoord] = round(b);
            // rgb32* pixel = bmp->getPixel(j, i);
            // pixel->r = std::round(r / count);
            // pixel->g = std::round(g / count);
            // pixel->b = std::round(b / count);
        }
    }
    return 1;
}

DLL_API int DLL_CALLCONV ResizePixels(int* pixelsData, int* destData, int w1, int h1, int w2, int h2) {
// source https://tech-algorithm.com/articles/nearest-neighbor-image-scaling/
// https://www.researchgate.net/figure/Nearest-neighbour-image-scaling-algorithm_fig2_272092207

    //double x_ratio = (double)(w1)/w2;
    //double y_ratio = (double)(h1)/h2;
    //#pragma omp simd simdlen(30) // schedule(dynamic) default(none)
    for (int i=0; i < h2; i++)
    {
        UINT py = i*(h1/h2);
        for (int j=0; j < w2; j++)
        {
            UINT px = j*(w1/w2);
            destData[(i*w2) + j] = pixelsData[(py*w1) + px];
        }
    }
    return 1;
}


DLL_API int DLL_CALLCONV hammingDistance(char str1[], char str2[])
{
    int i = 0, count = 0;
    while(str1[i]!='\0')
    {
        if (str1[i] != str2[i])
            count++;
        i++;
    }
    return count;
}

DLL_API int DLL_CALLCONV hamming_distance(int* a, int*b, int n) {
    int dist = 0;
    std::stringstream ss;
    ss << "qpv: a " << a;
    ss << "qpv: b " << b;

    for(int i=0; i<n; i++) {
        if (a[i] != b[i])
           dist++;
    }
    return dist;
}

// For every integer on 8bits (from 0 to 255), keep track of how many
// bits are set in the binary representation of that integer.
// Note, the only 8bit integer that has all 8 bits set is 255 (last element here)
// and 0 is the only element with no bits set.
const std::vector<int> globalNumberOfBits = {
0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8,
};

// Used once, to populate the variable above.
void GenerateCodeFor_globalNumberOfBits() {
  printf("const std::vector<int> globalNumberOfBits = {\n");
  for (int i = 0; i < 256; ++i) {
    int count = 0;
    for (int bit = 0; bit < 8; ++bit) {
      if (i & (1 << bit)) count++;
    }
    printf("%d, ", count);
    if (i % 16 == 15) printf("\n");
  }
  printf("};\n");
}

int CountDifferentBits(int64_t a, int64_t b) {
  int nr_diff_bits = 0;
  int64_t diffs = a ^ b;
  for (int i = 0; i < sizeof(int64_t); ++i) {
    const int last_8_bits = diffs & 0xFF;
    diffs = diffs >> 8;
    nr_diff_bits += globalNumberOfBits[last_8_bits];
  }
  return nr_diff_bits;
}

int CountDifferentBits(int64_t *img1, int64_t *img2, int nr_values) {
  int n_diff = 0;
  for (int i = 0; i < nr_values; ++i) {
    n_diff += CountDifferentBits(img1[i], img2[i]);
  }
  return n_diff;
}

unsigned long long int fact(UINT n) {
   if (n == 0 || n == 1)
      return 1;

   unsigned long long int r = n;
   for (unsigned long long int i = 1; i < n; i++)
   {
       r *= i;
   }
   return r;
}

DLL_API unsigned long long int DLL_CALLCONV dumbcalculateNCR(UINT n) {
// Calculates the number of combinations of N things taken r=2 at a time.

   // std::stringstream ss;
   // ss << "qpv: n=" << n;
 
   unsigned long long int combinations = 0;
   for ( unsigned long long int secondIndex = 0 ; secondIndex<n+1 ; secondIndex++)
   {
       for ( unsigned long long int mainIndex = secondIndex + 1 ; mainIndex<n ; mainIndex++)
       {
          // if (secondIndex!=mainIndex && secondIndex<n && mainIndex<n) 
          // {
             // std::stringstream ss;
             // ss << "qpv: sI=" << secondIndex;
             // ss << " mI=" << mainIndex;
             // OutputDebugStringA(ss.str().data());
             combinations++;
          // }
       }
   }

   // std::stringstream ss;
   // ss << " combos=" << combinations;
   // OutputDebugStringA(ss.str().data());
   return combinations;
}


UINT64 reverse_8bits(UINT64 n) {
  for (int i = 0, bytes = sizeof(n); i < bytes; ++i) {
    const int bit_offset = i * 8;
    for (int j = 0; j < 4; ++j) {
      // Calculam care e bit de schimbat, in cadrul la byte current (situat
      // la bit_offset, pe spatiu de 8 bits, numerotati de la 0 la 7.
      const int bit = bit_offset + j;
      const int sym_bit = bit_offset + 7 - j;

      // testam daca e setat bit
      // 1 << i face shift to left la bitul 1 cu i bits.
      const bool bit_s = (n & (1 << bit)) ? 1 : 0;

      // testam daca e setat bit sym_bit
      const bool bit_sym_s = (n & (1 << sym_bit)) ? 1 : 0;

      // Daca bit e setat, seteaza sym_i in loc (sau sterge)
      if (bit_s) {
        // bitwise or pe bit sym_i
        n |= 1 << sym_bit;
      } else {
        // bitwise and cu un numar care e
        // doar 1, si un singur 0 pe pozitia sym_bit (~ face negare)
        n &= ~(1 << sym_bit);
      }

      // La fel ca mai sus, la bit.
      if (bit_sym_s) {
        n |= 1 << bit;
      } else {
        n &= ~(1 << bit);
      }
    }
  }
  return n;
}

UINT64 revBits(UINT64 n){
  return (
     n    &0x0101010101010101 |  n>>5&0x0202020202020202 |  n>>3&0x0404040404040404 | n>>1&0x0808080808080808
  & ~n<< 1&0x1010101010101010 & ~n<<3&0x2020202020202020 & ~n<<5&0x4040404040404040 | n   &0x8080808080808080
  );
}

UINT64 revBits_entire(UINT64 n){
  return (
    n>> 7&0x0101010101010101 | n>>5&0x0202020202020202 | n>>3&0x0404040404040404 | n>>1&0x0808080808080808
  | n<< 1&0x1010101010101010 | n<<3&0x2020202020202020 | n<<5&0x4040404040404040 | n<<7&0x8080808080808080
  );
}


int reverse_bits(int n) {
  for (int i = 0, bits = sizeof(n) * 8; i < bits / 2; ++i)
  {
      // punctul simetric la i
      const int sym_i = bits - i - 1;

      // testam daca e setat bit i
      // 1 << i face shift to left la bitul 1 cu i bits.
      const bool bit_i = (n & (1 << i)) ? 1 : 0;

      // testam daca e setat bit sym_i
      const bool bit_sym_i = (n & (1 << sym_i)) ? 1 : 0;

      // Daca i e setat, seteaza sym_i in loc (sau sterge)
      if (bit_i)
      {
         // bitwise or pe bit sym_i
         n |= 1 << sym_i;
      } else
      {
         // bitwise and cu un numar care e
         // doar 1, si un singur 0 pe pozitia sym_i (~ face negare)
         n &= ~(1 << sym_i);
      }

      // La fel ca mai sus, la bit i.
      if (bit_sym_i)
      {
         n |= 1 << i;
      } else {
         n &= ~(1 << i);
      }
  }
  return n;
}
*/

