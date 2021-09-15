// qpv-main.cpp : Définit les fonctions exportées de la DLL.

#include "pch.h"
#include "framework.h"
#include <wchar.h>
#include "qpv-main.h"
#include "omp.h"
#include "math.h"
#include "windows.h"
#include <string>
#include <sstream>
#include <vector>
#include <stack>
#include <map>
#include <array>
#include <cstdint>
#include <cstdio>
#include <numeric>
#include <algorithm>

// #include <bits/stdc++.h>

using namespace std;

/*
Function written with help provided by Spawnova. Thank you very much.
pBitmap and pBitmapMask must be the same width and height
and in 32-ARGB format: PXF32ARGB - 0x26200A.

The alpha channel will be applied directly on the pBitmap provided.

For best results, pBitmapMask should be grayscale.
*/

DLL_API int DLL_CALLCONV SetAlphaChannel(int *imageData, int *maskData, int w, int h, int invert, int replaceAlpha, int whichChannel, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) num_threads(3)
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
    return (degree * (M_PI / 180));
}

double rad2deg(double radian) {
    // convert radian to degree
    return (radian * (180 / M_PI));
}

int RGBtoGray(int sR, int sG, int sB, int alternateMode) {
  // https://getreuer.info/posts/colorspace/index.html
  // http://www.easyrgb.com/en/math.php
  // sR, sG and sB (Standard RGB) input range = 0 ÷ 255
  // X, Y and Z output refer to a D65/2° standard illuminant.
  // return value is L* - Luminance from L*ab, based on D65 luminant

  if (alternateMode==1)
     return round((float)(sR*0.299 + sG*0.587 + sB*0.114)); // weighted grayscale conversion

  // convert RGB to XYZ color space
  double var_R = (float)sR/255;
  double var_G = (float)sG/255;
  double var_B = (float)sB/255;

  // Inverse sRGB gamma correction
  var_R = inverseGamma(var_R);
  var_G = inverseGamma(var_G);
  var_B = inverseGamma(var_B);

  double Y = var_R * 0.2125862 + var_G * 0.7151704 + var_B * 0.0722005;
  // if (alternateMode==2)
  //    return round(Y); // return derived luminosity in XYZ color space

  Y = toLABfx(Y);
  double L = 116*Y - 16;
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

    std::stringstream ss;
  // compute XYZ color space values for given sRGB
  double X = var_R * 0.4123955889674142161 + var_G * 0.3575834307637148171 + var_B * 0.1804926473817015735;
  double Y = var_R * 0.2125862307855955516 + var_G * 0.7151703037034108499 + var_B * 0.07220049864333622685;
  double Z = var_R * 0.01929721549174694484 + var_G * 0.1191838645808485318 + var_B * 0.9504971251315797660;
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

void calculateBlendModes(int rO, int gO, int bO, int rB, int gB, int bB, int blendMode, int *results) {
    int rT = 0;
    int gT = 0;
    int bT = 0;

    if (blendMode == 1) { // darken
        rT = min(rO, rB);
        gT = min(gO, gB);
        bT = min(bO, bB);
    }
    else if (blendMode == 2) { // multiply
        rT = (rO * rB) / 255;
        gT = (gO * gB) / 255;
        bT = (bO * bB) / 255;
    }
    else if (blendMode == 3) { // linear burn
       rT = rO + rB - 255;
       gT = gO + gB - 255;
       bT = bO + bB - 255;
    }
    else if (blendMode == 4) { // color burn
        rT = (255 - ((255 - rB) * 255) / (1 + rO) < 1) ? 0 : 255 - ((255 - rB) * 255) / (1 + rO);
        gT = (255 - ((255 - gB) * 255) / (1 + gO) < 1) ? 0 : 255 - ((255 - gB) * 255) / (1 + gO);
        bT = (255 - ((255 - bB) * 255) / (1 + bO) < 1) ? 0 : 255 - ((255 - bB) * 255) / (1 + bO);
    }
    else if (blendMode == 5) { // lighten
        rT = max(rO, rB);
        gT = max(gO, gB);
        bT = max(bO, bB);
    }
    else if (blendMode == 6) { // screen
        rT = 255 - (((255 - rO) * (255 - rB)) / 255);
        gT = 255 - (((255 - gO) * (255 - gB)) / 255);
        bT = 255 - (((255 - bO) * (255 - bB)) / 255);
    }
    else if (blendMode == 7) { // linear dodge [add]
        rT = rO + rB;
        gT = gO + gB;
        bT = bO + bB;
    }
    else if (blendMode == 8) { // hard light
        rT = (rO < 127) ? (2 * rO * rB) / 255 : 255 - ((2 * (255 - rO) * (255 - rB)) / 255);
        gT = (gO < 127) ? (2 * gO * gB) / 255 : 255 - ((2 * (255 - gO) * (255 - gB)) / 255);
        bT = (bO < 127) ? (2 * bO * bB) / 255 : 255 - ((2 * (255 - bO) * (255 - bB)) / 255);
    }
    else if (blendMode == 9) { // overlay
        rT = (rB < 127) ? (2 * rO * rB) / 255 : 255 - ((2 * (255 - rO) * (255 - rB)) / 255);
        gT = (gB < 127) ? (2 * gO * gB) / 255 : 255 - ((2 * (255 - gO) * (255 - gB)) / 255);
        bT = (bB < 127) ? (2 * bO * bB) / 255 : 255 - ((2 * (255 - bO) * (255 - bB)) / 255);
    }
    else if (blendMode == 10) { // hard mix
        rT = (rO <= (255 - rB)) ? 0 : 255;
        gT = (gO <= (255 - gB)) ? 0 : 255;
        bT = (bO <= (255 - bB)) ? 0 : 255;
    }
    else if (blendMode == 11) { // linear light
        rT = rB + (2 * rO) - 255;
        gT = gB + (2 * gO) - 255;
        bT = bB + (2 * bO) - 255;
    }
    else if (blendMode == 12) { // color dodge
        rT = (rB * 255) / (256 - rO);
        gT = (gB * 255) / (256 - gO);
        bT = (bB * 255) / (256 - bO);
    }
    else if (blendMode == 13) { // vivid light 
        if (rO < 127)
            rT = 255 - ((255 - rB) * 255) / (1 + 2 * rO);
        else
            rT = (rB * 255) / (2 * (256 - rO));

        if (gO < 127)
            gT = 255 - ((255 - gB) * 255) / (1 + 2 * gO);
        else
            gT = (gB * 255) / (2 * (256 - gO));

        if (bO < 127)
            bT = 255 - ((255 - bB) * 255) / (1 + 2 * bO);
        else
            bT = (bB * 255) / (2 * (256 - bO));
    }
    else if (blendMode == 14) { // division
        rT = (rO * 255) / (1 + rB);
        gT = (gO * 255) / (1 + gB);
        bT = (bO * 255) / (1 + bB);
    }
    else if (blendMode == 15) { // exclusion
        rT = rO + rB - 2 * ((rO * rB) / 255);
        gT = gO + gB - 2 * ((gO * gB) / 255);
        bT = bO + bB - 2 * ((bO * bB) / 255);
    }
    else if (blendMode == 16) { // difference
        rT = (rO > rB) ? rO - rB : rB - rO;
        gT = (gO > gB) ? gO - gB : gB - gO;
        bT = (bO > bB) ? bO - bB : bB - bO;
    }
    else if (blendMode == 17) { // substract
        rT = rO - rB;
        gT = gO - gB;
        bT = bO - bB;
    }
    else if (blendMode == 18) { // luminosity
        int gray = RGBtoGray(rO, gO, bO, 1) - RGBtoGray(rB, gB, bB, 1);
        rT = gray + rB;
        gT = gray + gB;
        bT = gray + bB;
    }
    else if (blendMode == 19) { // substract reverse
        rT = rB - rO;
        gT = gB - gO;
        bT = bB - bO;
    }
    else if (blendMode == 20) { // inverted difference
        rT = (rO > rB) ? 255 - rO - rB : 255 - rB - rO;
        gT = (gO > gB) ? 255 - gO - gB : 255 - gB - gO;
        bT = (bO > bB) ? 255 - bO - bB : 255 - bB - bO;
    }

    if (blendMode != 10) {
        if (rT < 0)
            rT = 0;
        if (gT < 0)
            gT = 0;
        if (bT < 0)
            bT = 0;

        if (rT > 255)
            rT = 255;
        if (gT > 255)
            gT = 255;
        if (bT > 255)
            bT = 255;
    }

    results[0] = rT;   
    results[1] = gT;   
    results[2] = bT;   
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
  rgb[0] = -((c * (255-k)) / 255 + k - 255);
  rgb[1] = -((m * (255-k)) / 255 + k - 255);
  rgb[2] = -((y * (255-k)) / 255 + k - 255);
}

int INTweighTwoValues(int A, int B, float w) {
    return (float)(A * w + B * (1 - w));
}

float weighTwoValues(float A, float B, float w) {
    return (A*w + B*(1-w));
}

int mixColors(int colorB, float *colorA, float f, int dynamicOpacity, int blendMode, float prevCLRindex, float tolerance, int alternateMode, float thisCLRindex) {
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
     rO = results[0];
     gO = results[1];
     bO = results[2];
  }

  int aT = INTweighTwoValues(aO, aB, f);
  int rT = INTweighTwoValues(rO, rB, f);
  int gT = INTweighTwoValues(gO, gB, f);
  int bT = INTweighTwoValues(bO, bB, f);

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

bool inRange(float low, float high, float x) {        
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

int FloodFill8Stack(int *imageData, int w, int h, int x, int y, int newColor, float *nC, int oldColor, float tolerance, float prevCLRindex, float opacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay) {
// based on https://lodev.org/cgtutor/floodfill.html
// by Lode Vandevenne

  if (newColor==oldColor)
     return 0; //avoid infinite loop

  static const int dx[8] = {0, 1, 1, 1, 0, -1, -1, -1}; // relative neighbor x coordinates
  static const int dy[8] = {-1, -1, 0, 1, 1, 1, 0, -1}; // relative neighbor y coordinates
  static const int gx[4] = {0, 1, 0, -1}; // relative neighbor x coordinates
  static const int gy[4] = {-1, 0, 1, 0}; // relative neighbor y coordinates

  unsigned int maxPixels = w*h + 1;
  unsigned int loopsOccured = 0;
  unsigned int suchDeviations = 0;
  int suchAppliedDeviations = 0;
  std::vector<int> pixelzMap(maxPixels, 0);
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
            thisColor = mixColors(prevColor, nC, opacity, dynamicOpacity, blendMode, prevCLRindex, tolerance, alternateMode, indexes[pix]);

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
  unsigned int maxPixels = w*h + w;
  unsigned int loopsOccured = 0;

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

int ReplaceGivenColor(int *imageData, int w, int h, int x, int y, int newColor, float *nC, int prevColor, float tolerance, float prevCLRindex, float opacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode) {
    if ((x < 0) || (x >= (w-1)) || (y < 0) || (y >= (h-1)))  // out of bounds
       return 0;

    int loopsOccured = 0;
    #pragma omp parallel for schedule(static) default(none) num_threads(3)
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
                     thisColor = mixColors(prevColor, nC, opacity, dynamicOpacity, blendMode, prevCLRindex, tolerance, alternateMode, index);
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

DLL_API int DLL_CALLCONV FloodFyll(int *imageData, int modus, int w, int h, int x, int y, int newColor, int tolerance, int fillOpacity, int dynamicOpacity, int blendMode, int cartoonMode, int alternateMode, int eightWay) {
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

    float opacity = (float)fillOpacity / 255;
    if (tolerance==0 && (opacity<1 || blendMode>0))
       newColor = mixColors(prevColor, nC, opacity, 0, blendMode, 0, 0, 0, 0);

    int r;
    if (modus==1)
       r = ReplaceGivenColor(imageData, w, h, x, y, newColor, nC, prevColor, toleranza, prevCLRindex, opacity, dynamicOpacity, blendMode, cartoonMode, alternateMode);
    else if (toleranza>0)
       r = FloodFill8Stack(imageData, w, h, x, y, newColor, nC, prevColor, toleranza, prevCLRindex, opacity, dynamicOpacity, blendMode, cartoonMode, alternateMode, eightWay);
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

            alpha2 = (alpha2==a) ? a : ceil(alpha2*fintensity + a*max(0, 1.0f - fintensity));  // Formula: A*w + B*(1 – w)
            int haha = (alpha2!=a) ? 1 : 0;
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
   // if (dabugMode>1)
   //     OutputDebugStringA(ss.str().data());

        }
    }
 
    // std::stringstream ss;
    // ss << "qpv: eraser = " << levelAlpha;
    // OutputDebugStringA(ss.str().data());
    return 1;
}

DLL_API int DLL_CALLCONV SetGivenAlphaLevel(int *imageData, int w, int h, int givenLevel, int fillMissingOnly, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) num_threads(3)
    for (int x = 0; x < w; x++)
    {
        int px, y = 0;
        int defaultColor = 0;
        unsigned int BGRcolor = imageData[x + y * w];
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

    #pragma omp parallel for schedule(dynamic) default(none) num_threads(3)
    for (int x = w - 1; x >= 0; x--)
    {
        int px, y = h - 1;
        int defaultColor = 0;
        unsigned int BGRcolor = imageData[x + y * w];
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
The box blur will be applied on the provided pBitmap
C/C++ function by Tic:
https://autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/page-30
*/

DLL_API int DLL_CALLCONV BoxBlurBitmap(unsigned char* Bitmap, int w, int h, int Stride, int Passes) {
    #pragma omp parallel for schedule(dynamic) default(none)
    for (int i = 0; i < Passes; ++i)
    {
        int A1, R1, G1, B1, A2, R2, G2, B2, A3, R3, G3, B3;
        for (int y = 0; y < h * Stride; y += Stride)
        {
            // A1 = R1 = G1 = B1 = A2 = R2 = G2 = B2 = 0;
            for (int x = 0; x < w; ++x)
            {
                int tempCoord = (4 * x) + y;
                A3 = Bitmap[3 + tempCoord];
                R3 = Bitmap[2 + tempCoord];
                G3 = Bitmap[1 + tempCoord];
                B3 = Bitmap[tempCoord];

                Bitmap[3 + tempCoord] = (A1 + A2 + A3) / 3;
                Bitmap[2 + tempCoord] = (R1 + R2 + R3) / 3;
                Bitmap[1 + tempCoord] = (G1 + G2 + G3) / 3;
                Bitmap[tempCoord] = (B1 + B2 + B3) / 3;

                A1 = A2; R1 = R2; G1 = G2; B1 = B2; A2 = A3; R2 = R3; G2 = G3; B2 = B3;
            }

            // A1 = R1 = G1 = B1 = A2 = R2 = G2 = B2 = 0;
            for (int x = w - 1; x >= 0; --x)
            {
                int tempCoord = (4 * x) + y;
                A3 = Bitmap[3 + tempCoord];
                R3 = Bitmap[2 + tempCoord];
                G3 = Bitmap[1 + tempCoord];
                B3 = Bitmap[tempCoord];

                Bitmap[3 + tempCoord] = (A1 + A2 + A3) / 3;
                Bitmap[2 + tempCoord] = (R1 + R2 + R3) / 3;
                Bitmap[1 + tempCoord] = (G1 + G2 + G3) / 3;
                Bitmap[tempCoord] = (B1 + B2 + B3) / 3;

                A1 = A2; R1 = R2; G1 = G2; B1 = B2; A2 = A3; R2 = R3; G2 = G3; B2 = B3;
            }
        }

        for (int x = 0; x < w; ++x)
        {
            // A1 = R1 = G1 = B1 = A2 = R2 = G2 = B2 = 0;
            for (int y = 0; y < h * Stride; y += Stride)
            {
                int tempCoord = (4 * x) + y;
                A3 = Bitmap[3 + tempCoord];
                R3 = Bitmap[2 + tempCoord];
                G3 = Bitmap[1 + tempCoord];
                B3 = Bitmap[tempCoord];

                Bitmap[3 + tempCoord] = (A1 + A2 + A3) / 3;
                Bitmap[2 + tempCoord] = (R1 + R2 + R3) / 3;
                Bitmap[1 + tempCoord] = (G1 + G2 + G3) / 3;
                Bitmap[tempCoord] = (B1 + B2 + B3) / 3;

                A1 = A2; R1 = R2; G1 = G2; B1 = B2; A2 = A3; R2 = R3; G2 = G3; B2 = B3;
            }

            // A1 = R1 = G1 = B1 = A2 = R2 = G2 = B2 = 0;
            for (int y = (h - 1) * Stride; y >= 0; y -= Stride)
            {
                int tempCoord = (4 * x) + y;
                A3 = Bitmap[3 + tempCoord];
                R3 = Bitmap[2 + tempCoord];
                G3 = Bitmap[1 + tempCoord];
                B3 = Bitmap[tempCoord];

                Bitmap[3 + tempCoord] = (A1 + A2 + A3) / 3;
                Bitmap[2 + tempCoord] = (R1 + R2 + R3) / 3;
                Bitmap[1 + tempCoord] = (G1 + G2 + G3) / 3;
                Bitmap[tempCoord] = (B1 + B2 + B3) / 3;

                A1 = A2; R1 = R2; G1 = G2; B1 = B2; A2 = A3; R2 = R3; G2 = G3; B2 = B3;
            }
        }
    }
    return 1;
}


/*
pBitmap and pBitmap2Blend must be the same width and height
and in 32-ARGB format: PXF32ARGB - 0x26200A.
*/

DLL_API int DLL_CALLCONV BlendBitmaps(int* bgrImageData, int* otherData, int w, int h, int blendMode, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) num_threads(3)
    for (int x = 0; x < w; x++)
    {
        // int rT, gT, bT; // , aB, aO, aX;
        //  int rO, gO, bO, rB, gB, bB;

        // #pragma omp parallel for schedule(static) default(none) num_threads(threadz)
        for (int y = 0; y < h; y++)
        {
            unsigned int BGRcolor = bgrImageData[x + (y * w)];
            if (BGRcolor != 0x0)
            {
                unsigned int colorO = otherData[x + (y * w)];
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


DLL_API int DLL_CALLCONV RandomNoise(int* bgrImageData, int w, int h, int intensity, int mode, int threadz) {
    // srand (time(NULL));
    // #pragma omp parallel for default(none) num_threads(threadz)

    // std::stringstream ss;
    // ss << "qpv: results w " << w;
    // ss << " h " << h;
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            unsigned char aT = 255;
            unsigned char z = rand() % 101;
            // int px = x + (y * w);
            // if (x<5 && y<5)
            // {
            //    ss << " x=" << x;
            //    ss << " y=" << y;
            //    ss << " PX=" << px;
            // }

            // if (x>(w-5) && y>(h-5))
            // {
            //    ss << " x " << x;
            //    ss << " y " << y;
            //    ss << " PX " << px;
            // }

            if (z<intensity)
            {
               // unsigned char rT = 0;
               bgrImageData[x + (y * w)] = 0;
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
    // OutputDebugStringA(ss.str().data());
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

            {
                int tmp = (w % Size) * Size;
                sA = tmp ? (sA / tmp) : 0;
                sR = tmp ? (sR / tmp) : 0;
                sG = tmp ? (sG / tmp) : 0;
                sB = tmp ? (sB / tmp) : 0;
            }
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

        {
            int tmp = Size * (h % Size);
            sA = tmp ? (sA / tmp) : 0;
            sR = tmp ? (sR / tmp) : 0;
            sG = tmp ? (sG / tmp) : 0;
            sB = tmp ? (sB / tmp) : 0;
        }

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

    {
        int tmp = (w % Size) * (h % Size);
        sA = tmp ? (sA / tmp) : 0;
        sR = tmp ? (sR / tmp) : 0;
        sG = tmp ? (sG / tmp) : 0;
        sB = tmp ? (sB / tmp) : 0;
    }

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

/*
DLL_API int newBoxBlurBitmap(unsigned char* Bitmap, unsigned char* BitmapOut, int w, int h, int Stride, int r) {
// function boxBlurT_3 (scl, tcl, w, h, r) {
// http://blog.ivank.net/fastest-gaussian-blur.html

    for (int i=0; i<h*Stride; i+=Stride)
    {
        for(int j=0; j<w; j++)
        {
            int val = 0;
            for (int iy=i-r; iy<i+r+1; iy++)
            {
                int y = min(h-1, max(0, iy));
                val += Bitmap[y*w+j];
            }
            BitmapOut[i*w+j] = val/(2*r+1);
        }
    }

}


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

DLL_API int countStringOccurences(const wchar_t *mainStr, const wchar_t *toFind) {

    std::wstring base_string(mainStr);
    std::wstring str_to_find(toFind);

    int occurrences = 0;
    string::size_type start = 0;

    //std::stringstream ss;
    //ss << "qpv: ";
    //ss << "txt: " << str_to_find;
    //ss << "the other: " << base_string;
    //LPCWSTR stru = str_to_find.c_str();

    //OutputDebugStringW(stru);
    while ((start = base_string.find(str_to_find, start)) != string::npos) {
        ++occurrences;
        start += str_to_find.length();
    }
    return occurrences;
}

DLL_API unsigned int DLL_CALLCONV isInString(const wchar_t *mainStr, const wchar_t *toFind) {
    unsigned int occurrences = 0;

    if (wcsstr(mainStr, toFind))
       occurrences = 1;

    return occurrences; //  occurrences;
}

DLL_API int DLL_CALLCONV ResizePixels(int* pixelsData, int* destData, int w1, int h1, int w2, int h2) {
// source https://tech-algorithm.com/articles/nearest-neighbor-image-scaling/
// https://www.researchgate.net/figure/Nearest-neighbour-image-scaling-algorithm_fig2_272092207

    //double x_ratio = (double)(w1)/w2;
    //double y_ratio = (double)(h1)/h2;
    //#pragma omp simd simdlen(30) // schedule(dynamic) default(none)
    for (int i=0; i < h2; i++)
    {
        unsigned int py = i*(h1/h2);
        for (int j=0; j < w2; j++)
        {
            unsigned int px = j*(w1/w2);
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

DLL_API int DLL_CALLCONV hammingDistanceOverArray(int argc, char **argv) {
  //  GenerateCodeFor_globalNumberOfBits();   return 0;
  int result;

  std::vector<int64_t> values1;
  values1.push_back(713232);
  values1.push_back(212);

  std::vector<int64_t> values2;
  values2.push_back(73232);
  values2.push_back(2121);
  result = CountDifferentBits(&values1[0], &values2[0], min(values1.size(), values2.size()));
  printf("final = %d\n", result);

  std::stringstream ss;
  ss << "qpv: " << result;
  OutputDebugStringA(ss.str().data());

  return 1;
}

*/

DLL_API unsigned int DLL_CALLCONV dumbcalculateNCR(int n) {
// Calculates the number of combinations of N things taken r=2 at a time.

   unsigned int combinations = 0;
   for ( int secondIndex = 0 ; secondIndex<n+1 ; secondIndex++)
   {
       for ( int mainIndex = secondIndex + 1 ; mainIndex<n+1 ; mainIndex++)
       {
          if (secondIndex!=mainIndex && secondIndex<=n && mainIndex<=n) 
             combinations++;
       }
   }

   // std::stringstream ss;
   // ss << "qpv: " << combinations;
   // OutputDebugStringA(ss.str().data());
   return combinations;
}

inline int hammingDistance(unsigned long long n1, unsigned long long n2) { 
    unsigned long long x = n1 ^ n2; 
    int setBits = 0; 
  
    while (x > 0) { 
        setBits += x & 1; 
        x >>= 1; 
    } 
  
    return setBits; 
} 

DLL_API int DLL_CALLCONV hammingDistanceOverArray(unsigned long long *givenHashesArray, unsigned int *givenIDs, int arraySize, unsigned int *resultsArrayA, unsigned int *resultsArrayB, unsigned int *resultsArrayC, int threshold, int maxResults) {
    int results = 0;
    int n = arraySize;
    bool done = false;
    // int mainIndex = 1;
    // int returnVal = 1;

    #pragma omp parallel for schedule(dynamic) default(none) shared(results)
    for ( int secondIndex = 0 ; secondIndex<n+1 ; secondIndex++)
    {
        if (done==1)
           break;

        for ( int mainIndex = secondIndex + 1 ; mainIndex<n+1 ; mainIndex++)
        {
            if (done==1)
               break;

            int diff = hammingDistance(givenHashesArray[mainIndex], givenHashesArray[secondIndex]);
            if (diff<threshold)
            {
                #pragma omp critical
                {
                    results++;
                    resultsArrayA[results] = givenIDs[mainIndex];
                    resultsArrayB[results] = givenIDs[secondIndex];
                    resultsArrayC[results] = diff;
                    done = results > maxResults;
                };
            };
        };
    }

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
