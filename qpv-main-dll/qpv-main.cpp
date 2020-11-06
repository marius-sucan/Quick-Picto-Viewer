// qpv-main.cpp : Définit les fonctions exportées de la DLL.

#include "pch.h"
#include "framework.h"
#include <wchar.h>
#include "qpv-main.h"
#include "omp.h"
#include "math.h"
#include "time.h"
#include <string>
#include <sstream>

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
               alpha = maskData[px] >> 8; // green
            else if (whichChannel==3)
               alpha = maskData[px] >> 0; // blue
            else if (whichChannel==4)
               alpha = maskData[px] >> 24; // alpha
            else
               alpha = maskData[px] >> 16; // red

            if (replaceAlpha!=1)
            {
               if (invert == 1)
                  alpha = 255 - alpha;
               a = imageData[px] >> 24;
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
        int rT, gT, bT, aB, aO, aX;
        int rO, gO, bO, rB, gB, bB;

        // #pragma omp parallel for schedule(static) default(none) num_threads(threadz)
        for (int y = 0; y < h; y++)
        {
            unsigned int BGRcolor = bgrImageData[x + (y * w)];
            if (BGRcolor != 0x0)
            {
                unsigned int colorO = otherData[x + (y * w)];
                aO = (colorO >> 24) & 0xFF;
                aB = (BGRcolor >> 24) & 0xFF;
                aX = min(aO, aB);
                if (aX < 1)
                {
                    bgrImageData[x + (y * w)] = 0;
                    continue;
                }

                rO = (colorO >> 16) & 0xFF;
                gO = (colorO >> 8) & 0xFF;
                bO = colorO & 0xFF;

                rB = (BGRcolor >> 16) & 0xFF;
                gB = (BGRcolor >> 8) & 0xFF;
                bB = BGRcolor & 0xFF;

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
    #pragma omp parallel for default(none) num_threads(threadz)
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
*/



