// qpv-main.cpp : Définit les fonctions exportées de la DLL.

#include "pch.h"
#include "framework.h"
#include <wchar.h>
#include "qpv-main.h"
#include "omp.h"
#include "math.h"
#include "time.h"
#include "windows.h"
#include <string>
#include <sstream>
#include <vector>
#include <cstdint>
#include <cstdio>
#include <numeric>
#include <algorithm>
#include <bits/stdc++.h>

using namespace std;

/*
Function written with help provided by Spawnova. Thank you very much.
pBitmap and pBitmapMask must be the same width and height
and in 32-ARGB format: PXF32ARGB - 0x26200A.

The alpha channel will be applied directly on the pBitmap provided.

For best results, pBitmapMask should be grayscale.
*/

DLL_API int DLL_CALLCONV SetAlphaChannel(int *imageData, int *maskData, int w, int h, int invert, int replaceAlpha, int whichChannel, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) num_threads(threadz)
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

DLL_API int DLL_CALLCONV blahErserBrush(int *imageData, int *maskData, int w, int h, int invert, int replaceMode, int levelAlpha, int stride, int dabugMode) {
    int debug = 0;

    if (debug==1) {
      std::ofstream f("c:\\temp\bub.txt");
      f << w << " " << h<< std::endl;
      f << invert << " " << replaceMode << " " << levelAlpha << std::endl;
      for (int i = 0, n = w*h ; i < n; ++i) {
         f << imageData[i] << " " << maskData[i] <<std::endl;
      }
      f.close();  
    }

    // #pragma omp parallel for schedule(dynamic) default(none)
    for (int y = 0; y < h * stride; y += stride)
    {
        // A1 = R1 = G1 = B1 = A2 = R2 = G2 = B2 = 0;
        for (int x = 0; x < w; ++x)
        {
// https://www.graphicsmill.com/docs/gm/accessing-pixel-data.htm
// https://stackoverflow.com/questions/42735499/lockbits-of-bitmap-as-different-format-in-c

            int alpha2;
            const int px = (4 * x) + y *4;
            int a = imageData[3 + px];
            unsigned char intensity = maskData[px] & 0xff; // blue
            if (invert == 1)
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

            alpha2 = 252;  // (alpha2==a) ? a : alpha2*fintensity + a*max(0, 1.0f - fintensity);  // Formula: A*w + B*(1 – w)
            // int haha = (alpha2!=a) ? 1 : 0;
            // if (haha==1)
               imageData[3 + px] = alpha2;
   // std::stringstream ss;
   // ss << "qpv: alpha2 = " << alpha2;
   // ss << " var a = " << a;
   // ss << " var haha = " << haha;
   // if (dabugMode>1)
   //     OutputDebugStringA(ss.str().data());

        }
    }
    return 1;
}


DLL_API int DLL_CALLCONV offsetsEraserBrush(int *imageData, int *maskData, int w3, int h3, int invertMask, int replaceMode, int levelAlpha, int maskOffX, int maskOffY, int offsetX, int offsetY, int w, int h, int mW, int mH, int Stride) {

    // #pragma omp parallel for schedule(dynamic) default(none)
    for (int x = offsetX; x < offsetX + w3; ++x)
    {
        int tX = 0;
        tX++;
        // int px;
        for (int y = offsetY * Stride; y < (offsetY + h3) * Stride; y += Stride)
        {
            int tY = 0;
            tY++;

            const int px = x * 4 + y;
            const int mpx = (tX + maskOffX) * mH + tY;
            int alpha2;
            int a = 254; // (imageData[px] >> 24) & 0xFF;
            int intensity = (maskData[mpx] >> 8) & 0xff;
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

            alpha2 = (alpha2==a) ? a : alpha2*fintensity + a*max(0, 1.0f - fintensity);  // Formula: A*w + B*(1 – w)
            int haha = (alpha2!=a) ? 1 : 0;
            if (alpha2!=a)
               imageData[px] = (alpha2 << 24) | (imageData[px] & 0x00ffffff);
   // std::stringstream ss;
   // ss << "qpv: alpha2 = " << alpha2;
   // ss << " var a = " << a;
   // ss << " var haha = " << haha;
   // if (dabugMode>1)
   //     OutputDebugStringA(ss.str().data());

        }
    }
 
    std::stringstream ss;
    ss << "qpv: eraser = " << levelAlpha;
    OutputDebugStringA(ss.str().data());
    return 1;
}


DLL_API int DLL_CALLCONV blahaaaaaaEraserBrush(int *imageData, int *maskData, int w, int h, int invertMask, int replaceMode, int levelAlpha) {

    // #pragma omp parallel for schedule(dynamic) default(none)
    for (int x = 0; x < w; x++)
    {
        // int px;
        for (int y = 0; y < h; y++)
        {
            const int px = (x * h + y) * 4 - 4;
            int alpha2;
            int a = imageData[px + 3];
            int intensity = maskData[px + 2];
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

            alpha2 = (alpha2==a) ? a : alpha2*fintensity + a*max(0, 1.0f - fintensity);  // Formula: A*w + B*(1 – w)
            int haha = (alpha2!=a) ? 1 : 0;
            if (alpha2!=a)
               imageData[px + 3] = alpha2;
   // std::stringstream ss;
   // ss << "qpv: alpha2 = " << alpha2;
   // ss << " var a = " << a;
   // ss << " var haha = " << haha;
   // if (dabugMode>1)
   //     OutputDebugStringA(ss.str().data());

        }
    }
 
    std::stringstream ss;
    ss << "qpv: eraser = " << levelAlpha;
    OutputDebugStringA(ss.str().data());
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
 
    std::stringstream ss;
    ss << "qpv: eraser = " << levelAlpha;
    OutputDebugStringA(ss.str().data());
    return 1;
}

DLL_API int DLL_CALLCONV SetGivenAlphaLevel(int *imageData, int w, int h, int givenLevel, int fillMissingOnly, int threadz) {
    #pragma omp parallel for schedule(dynamic) default(none) num_threads(threadz)
    for (int x = 0; x < w; x++)
    {
        int px, y = 0;
        int defaultColor;
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

    #pragma omp parallel for schedule(dynamic) default(none) num_threads(threadz)
    for (int x = w - 1; x >= 0; x--)
    {
        int px, y = h - 1;
        int defaultColor;
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
    #pragma omp parallel for schedule(dynamic) default(none) num_threads(threadz)
    for (int x = 0; x < w; x++)
    {
        int rT, gT, bT; // , aB, aO, aX;
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
                    rT = (float(rO*0.299+gO*0.587+bO*0.115) - float(rB*0.299+gB*0.587+bB*0.115)) + rB;
                    gT = (float(rO*0.299+gO*0.587+bO*0.115) - float(rB*0.299+gB*0.587+bB*0.115)) + gB;
                    bT = (float(rO*0.299+gO*0.587+bO*0.115) - float(rB*0.299+gB*0.587+bB*0.115)) + bB;
                }
                else if (blendMode == 19) { // substract revverse
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

                bgrImageData[x + (y * w)] = (aX << 24) | ((rT & 0xFF) << 16) | ((gT & 0xFF) << 8) | (bT & 0xFF);
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
    for (int x = 0; x < w; x++)
    {
        for (int y = 0; y < h; y++)
        {
            unsigned char aT = 255;
            unsigned char z = rand() % 101;
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
