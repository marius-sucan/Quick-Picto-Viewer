// paint-brush.h
//
// The brush tool: PaintBrushLarge(), the per-stroke opacity chunks it paints through and
// ResetBrushOpacityMap(), which drops them.
//
// #included by qpv-main.cpp after color-adjust.h; it blends through CalculateNewBlendModes(),
// clips through clipMaskFilter() and runs its effects brush through RGBA16color, with tables
// of its own (brushLUTs).
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_PAINT_BRUSH_H
#define QPV_PAINT_BRUSH_H

#include <algorithm>
#include <cmath>
#include <new>
#include <vector>

std::vector<unsigned char*> brushOpacityChunks;
std::vector<unsigned char*> brushOriginalPixelChunks;
std::vector<size_t> activeBrushChunks;
// std::unordered_map<UINT, unsigned char>  brushMoveImgData(1);
int chunkGridW = 0;

// the effects brush's brightness and contrast tables
static AdjustLUTs brushLUTs;

DLL_API void DLL_CALLCONV ResetBrushOpacityMap() {
    for (unsigned char* ptr : brushOpacityChunks)
    {
        if (ptr)
           delete[] ptr;
    }

    std::vector<unsigned char*>().swap(brushOpacityChunks);
    for (size_t idx : activeBrushChunks)
    {
        if (idx < brushOriginalPixelChunks.size() && brushOriginalPixelChunks[idx])
        {
            delete[] brushOriginalPixelChunks[idx];
            brushOriginalPixelChunks[idx] = nullptr;
        }
    }
    activeBrushChunks.clear();
}

// bilinear sample of straight ARGB: taps of unequal alpha weigh their colours by it, so a transparent tap's colour stays hidden
static inline void brushBilinearSample(const unsigned char* p11, const unsigned char* p21, const unsigned char* p12, const unsigned char* p22,
    const double w11, const double w21, const double w12, const double w22, const int bytesPerPixel, int& b, int& g, int& r, int& a) {
    if (bytesPerPixel==4 && !(p11[3]==p21[3] && p11[3]==p12[3] && p11[3]==p22[3]))
    {
        const double a11 = w11 * p11[3], a21 = w21 * p21[3], a12 = w12 * p12[3], a22 = w22 * p22[3];
        const double sa = a11 + a21 + a12 + a22;
        if (sa>0)
        {
            b = (int)round((a11 * p11[0] + a21 * p21[0] + a12 * p12[0] + a22 * p22[0]) / sa);
            g = (int)round((a11 * p11[1] + a21 * p21[1] + a12 * p12[1] + a22 * p22[1]) / sa);
            r = (int)round((a11 * p11[2] + a21 * p21[2] + a12 * p12[2] + a22 * p22[2]) / sa);
            a = (int)round(sa);
            return;
        }
    }

    b = (int)round(w11 * p11[0] + w21 * p21[0] + w12 * p12[0] + w22 * p22[0]);
    g = (int)round(w11 * p11[1] + w21 * p21[1] + w12 * p12[1] + w22 * p22[1]);
    r = (int)round(w11 * p11[2] + w21 * p21[2] + w12 * p12[2] + w22 * p22[2]);
    a = (bytesPerPixel==4) ? (int)round(w11 * p11[3] + w21 * p21[3] + w12 * p12[3] + w22 * p22[3]) : 255;
}

// what one stamp of PaintBrushLarge() works with: its arguments, and what is worked out from them once
struct BrushStamp {
    // the arguments, in the order PaintBrushLarge() takes them
    unsigned char* imgData;
    int imgW, imgH, pitch, imgBpp, brushType;
    double tkX, tkY;
    int brushSize, softness;
    double angle, aspectRatio;
    int brushColor, opacity, blendMode;
    double offX, offY;
    unsigned char* cloneData;
    int clonePitch, eraserMode, useSelArea, linearGamma, flipLayers, bulgePinchFactor;
    int effectHue, effectSat, effectLight, effectGamma, effectBlur;
    unsigned char* texData;
    int texW, texH, texPitch, texBpp, brushOverDraw;
    int lockX, lockY, lockW, lockH;

    int bytesPerPixel, useBlendMode;
    int startX, endX, startY, endY;
    int cloneStartX, cloneEndX, cloneStartY, cloneEndY;
    double cloneOffsetX, cloneOffsetY;
    int cloneW, cloneH, localPitch;
    std::vector<unsigned char> localClone;
    int brushA, brushR, brushG, brushB;
    double falloff, cosA, sinA, rx, ry;
    cv::Mat blurredRoi;
    int roiStartX, roiEndX, roiStartY, roiEndY;
    bool hasBlurredRoi, blurIsWeighted;
    int brushHue, brushSat, brushBright, brushContra;
    float fiBright, factorContrast, fiContra, saturateFactor;
    int stepX, stepY, sX, eX, sY;
    int ropacity;
    float opaf;
    double falloff_sq, dest_radius;
    int overDrawOkay;
    double invRx, invRy, A_coeff, B_term_factor, C_term_factor;
    int totalStepsY;
};

// whether the blend reads the pixels from before the stroke, and the stroke's grid of 128 x 128 opacity chunks
static void brushSetupChunkGrid(BrushStamp &s) {
    s.useBlendMode = (s.brushType==2 || s.brushType==3 || s.brushType>=5) && (s.blendMode>=8) ? 1 : 0;
    if (s.blendMode==13 || s.blendMode==14 || s.blendMode==23)
       s.useBlendMode = 0;

    if (s.brushType<=5 && s.brushOverDraw==0)
    {
        int numChunksX = (s.imgW + 127) >> 7;
        int numChunksY = (s.imgH + 127) >> 7;
        size_t totalChunks = (size_t)numChunksX * numChunksY;
        if (brushOpacityChunks.empty() || brushOpacityChunks.size() != totalChunks || (s.useBlendMode == 1 && brushOriginalPixelChunks.size() != totalChunks))
        {
            for (unsigned char* ptr : brushOpacityChunks)
            {
                if (ptr)
                   delete[] ptr;
            }

            for (size_t idx : activeBrushChunks)
            {
                if (idx < brushOriginalPixelChunks.size() && brushOriginalPixelChunks[idx])
                   delete[] brushOriginalPixelChunks[idx];
            }

            activeBrushChunks.clear();
            brushOpacityChunks.assign(totalChunks, nullptr);
            if (s.useBlendMode == 1)
            {
                brushOriginalPixelChunks.assign(totalChunks, nullptr);
            } else if (!brushOriginalPixelChunks.empty())
            {
                brushOriginalPixelChunks.clear();
                brushOriginalPixelChunks.shrink_to_fit();
            }
            chunkGridW = numChunksX;
        }
    }
}

// the brush box, and the rectangle the smudge, pinch and bulge brushes sample, copied when no clone was
// handed over; false when the image is a GDI+ lock rect and there is no copy
static bool brushSetupClone(BrushStamp &s) {
    int halfW = (s.texData && s.texW > 0) ? (s.texW / 2 + abs(s.bulgePinchFactor)) : (s.brushSize / 2 + abs(s.bulgePinchFactor));
    int halfH = (s.texData && s.texH > 0) ? (s.texH / 2 + abs(s.bulgePinchFactor)) : (s.brushSize / 2 + abs(s.bulgePinchFactor));
    s.startX = clamp((int)(s.tkX - halfW), 0, s.imgW - 1);
    s.endX = clamp((int)(s.tkX + halfW), 0, s.imgW - 1);
    s.startY = clamp((int)(s.tkY - halfH), 0, s.imgH - 1);
    s.endY = clamp((int)(s.tkY + halfH), 0, s.imgH - 1);

    s.cloneStartX = s.startX;
    s.cloneEndX = s.endX;
    s.cloneStartY = s.startY;
    s.cloneEndY = s.endY;
    s.cloneOffsetX = s.offX;
    s.cloneOffsetY = s.offY;
    if (s.brushType==6)
    {
        double scale = 3.0;
        if (s.bulgePinchFactor>0)
        {
            int wetness = s.bulgePinchFactor - 1;
            scale = 1.0 + 26.0 * (wetness / 22.0);
        }

        s.cloneOffsetX = s.offX * scale;
        s.cloneOffsetY = s.offY * scale;
        s.cloneStartX = clamp((int)floor(s.startX - std::max(0.0, s.cloneOffsetX)) - 2, 0, s.imgW - 1);
        s.cloneEndX = clamp((int)ceil(s.endX - std::min(0.0, s.cloneOffsetX)) + 2, 0, s.imgW - 1);
        s.cloneStartY = clamp((int)floor(s.startY - std::max(0.0, s.cloneOffsetY)) - 2, 0, s.imgH - 1);
        s.cloneEndY = clamp((int)ceil(s.endY - std::min(0.0, s.cloneOffsetY)) + 2, 0, s.imgH - 1);
    }

    if (s.lockW>0)
    {
        // a GDI+ lock holds only its rect, with top-down rows; samples past it take its edge pixels
        s.cloneStartX = max(s.cloneStartX, s.lockX);
        s.cloneEndX = min(s.cloneEndX, s.lockX + s.lockW - 1);
        s.cloneStartY = max(s.cloneStartY, s.imgH - s.lockY - s.lockH);
        s.cloneEndY = min(s.cloneEndY, s.imgH - 1 - s.lockY);
    }

    s.cloneW = s.cloneEndX - s.cloneStartX + 1;
    s.cloneH = s.cloneEndY - s.cloneStartY + 1;
    s.localPitch = s.cloneW * s.bytesPerPixel;
    if (!s.cloneData && s.brushType>=6 && s.cloneW>0 && s.cloneH>0)
    {
        try
        {
            // Limit allocation size to 150MB to prevent OOM
            if ((size_t)s.cloneW * s.cloneH * s.bytesPerPixel < 150 * 1024 * 1024)
            {
                s.localClone.resize((size_t)s.cloneW * s.cloneH * s.bytesPerPixel);
                for (int ry = 0; ry < s.cloneH; ++ry)
                {
                    int img_py = s.cloneStartY + ry;
                    int img_iy = s.imgH - 1 - img_py;
                    unsigned char* srcRow = s.imgData + (INT64)img_iy * s.pitch + s.cloneStartX * s.bytesPerPixel;
                    unsigned char* dstRow = s.localClone.data() + (INT64)ry * s.localPitch;
                    memcpy(dstRow, srcRow, s.localPitch);
                }
            }
        } catch (...) {
            s.localClone.clear();
        }
    }

    // without the copy, the samplers would read the image directly, past the lock rect
    return !(s.lockW>0 && !s.cloneData && s.brushType>=6 && s.localClone.empty());
}

// the colour, and the rotated ellipse of the brush tip
static void brushSetupShape(BrushStamp &s) {
    // Parse foreground color channels
    s.brushA = (s.brushColor >> 24) & 0xFF;
    s.brushR = (s.brushColor >> 16) & 0xFF;
    s.brushG = (s.brushColor >> 8) & 0xFF;
    s.brushB = s.brushColor & 0xFF;

    // Softness calculations
    s.falloff = (100.0 - s.softness) / 100.0;

    // Angle in radians (for rotated elliptical brush mask)
    double rad = -s.angle * M_PI / 180.0;
    s.cosA = cos(rad);
    s.sinA = sin(rad);

    // Calculate semi-axes rx, ry based on aspectRatio (-100 to 100)
    double thisAR = 1.0 - abs(s.aspectRatio) / 105.0;
    s.rx = (s.aspectRatio > 0.0) ? (s.brushSize * thisAR) / 2.0 : s.brushSize / 2.0;
    s.ry = (s.aspectRatio < 0.0) ? (s.brushSize * thisAR) / 2.0 : s.brushSize / 2.0;
    if (s.rx < 0.5) s.rx = 0.5;
    if (s.ry < 0.5) s.ry = 0.5;
}

// the adjustments of the cloner and effects brushes, and the effects brush's blur; false when the blur failed
static bool brushSetupEffects(BrushStamp &s) {
    // Pre-calculate blurred ROI if needed
    s.roiStartX = 0, s.roiEndX = 0, s.roiStartY = 0, s.roiEndY = 0;
    s.hasBlurredRoi = false;
    s.blurIsWeighted = false;

    // LUT and scaling variables for brush type 5
    s.brushHue = s.effectHue;
    s.brushSat = (int)round(s.effectSat * 655.35);
    s.brushBright = s.effectLight * 257;
    s.brushContra = (int)round(s.effectGamma * 655.30);
    if (s.brushContra>65525)
       s.brushContra = 65525;

    s.fiBright = 0.0f;
    s.factorContrast = 0.0f;
    s.fiContra = 0.0f;
    s.saturateFactor = 0.0f;
    if (s.brushType==5 || s.brushType==3)
    {
        // Effects and cloner brushes
        // Prepare LUT tables as in AdjustImageColorsPrecise()
        // (no gammaBright build: brightness() is called with altMode==1 below,
        //  which never reads that table)
        s.fiBright = (s.brushBright > 0) ? s.brushBright / 32768.0f : -1.0f * int_to_float[-s.brushBright];
        if (s.brushBright!=0)
        {
            for (int i = 0; i < 65536; i++)
            {
                brushLUTs.bright[i] = brightMathsInt16(i, s.fiBright);
            }
        }

        s.factorContrast = s.brushContra / 98302.0f;
        s.fiContra = (65536.5f * (s.brushContra + 65535.0f)) / (65535.0f * (65536.5f - s.brushContra));
        if (s.brushContra!=0)
        {
            for (int i = 0; i < 65536; i++)
            {
                brushLUTs.contra[i] = contraMathsInt16(i, s.fiContra, 32768);
            }
        }

        s.saturateFactor = (s.brushSat < 0) ? (65535.0f - abs(s.brushSat)) / 131070.0f : 0.5f + s.brushSat / 131070.0f;
        if (s.effectBlur>2 && s.brushType==5)
        {
            int radius = s.effectBlur;
            int use_lockX = (s.lockW > 0 && !s.cloneData) ? s.lockX : 0;
            int use_lockY = (s.lockH > 0 && !s.cloneData) ? s.lockY : 0;
            int use_lockW = (s.lockW > 0 && !s.cloneData) ? s.lockW : s.imgW;
            int use_lockH = (s.lockH > 0 && !s.cloneData) ? s.lockH : s.imgH;

            // the ROI must stay inside the Mat below, which holds only the GDI+ lock rect on normal images
            s.roiStartX = clamp(s.startX - radius, use_lockX, use_lockX + use_lockW - 1);
            s.roiEndX = clamp(s.endX + radius, use_lockX, use_lockX + use_lockW - 1);
            s.roiStartY = clamp(s.startY - radius, s.imgH - use_lockY - use_lockH, s.imgH - 1 - use_lockY);
            s.roiEndY = clamp(s.endY + radius, s.imgH - use_lockY - use_lockH, s.imgH - 1 - use_lockY);

            int roiW = s.roiEndX - s.roiStartX + 1;
            int roiH = s.roiEndY - s.roiStartY + 1;
            if (roiW>0 && roiH>0)
            {
                unsigned char* srcData = s.cloneData ? s.cloneData : s.imgData;
                int srcPitch = s.cloneData ? s.clonePitch : s.pitch;
                int clr = (s.bytesPerPixel == 4) ? CV_8UC4 : CV_8UC3;

                // nothing may be thrown out of an exported function
                try
                {
                    cv::Mat srcMat(use_lockH, use_lockW, clr, srcData + (INT64)use_lockY * srcPitch + use_lockX * s.bytesPerPixel, srcPitch);
                    // Translate the vertical range [roiStartY, roiEndY] from bottom-up image coordinates
                    // to standard memory coordinates.
                    // py = roiStartY (bottom row) -> memory row = imgH - 1 - roiStartY (largest memory index)
                    // py = roiEndY (top row) -> memory row = imgH - 1 - roiEndY (smallest memory index)
                    cv::Rect roi(s.roiStartX - use_lockX, s.imgH - 1 - s.roiEndY - use_lockY, roiW, roiH);
                    cv::Mat srcRoi = srcMat(roi);

                    int kernelSize = 2 * radius + 1;
                    bool hasTransparency = false;
                    for (int y = 0; y < roiH && !hasTransparency && s.bytesPerPixel==4; y++)
                    {
                        const unsigned char* row = srcRoi.ptr<unsigned char>(y);
                        for (int x = 0; x < roiW; x++)
                        {
                            if (row[x * 4 + 3]<255)
                            {
                               hasTransparency = true;
                               break;
                            }
                        }
                    }

                    if (hasTransparency)
                    {
                        // straight ARGB: blur the colours weighted by alpha, so the colour under transparent pixels stays hidden
                        cv::Mat weighted(roiH, roiW, CV_32FC4);
                        for (int y = 0; y < roiH; y++)
                        {
                            const unsigned char* sp = srcRoi.ptr<unsigned char>(y);
                            float* d = weighted.ptr<float>(y);
                            for (int x = 0; x < roiW * 4; x += 4)
                            {
                                const float a = sp[x + 3];
                                d[x] = sp[x] * a;
                                d[x + 1] = sp[x + 1] * a;
                                d[x + 2] = sp[x + 2] * a;
                                d[x + 3] = a;
                            }
                        }
                        cv::blur(weighted, s.blurredRoi, cv::Size(kernelSize, kernelSize));
                        s.blurIsWeighted = true;
                    } else
                    {
                        cv::blur(srcRoi, s.blurredRoi, cv::Size(kernelSize, kernelSize));
                    }
                    s.hasBlurredRoi = true;
                } catch (...)
                {
                    // fnOutputDebug("PaintBrushLarge(): the blur of the effects brush failed");
                    return false;
                }
            }
        }
    }
    return true;
}

// the scan direction, the opacity limits, the warp radius and this stamp's chunks; false when a chunk could not be allocated
static bool brushSetupPass(BrushStamp &s) {
    s.stepX = 1;
    s.stepY = 1;
    s.sX = s.startX;
    s.eX = s.endX;
    s.sY = s.startY;
    s.ropacity = s.opacity;
    s.opaf = (s.opacity / 255.0f);
    if (s.brushType==6)
    {
        // smudge brush
        if (s.offX<0)
        {
           s.stepX = -1;
           s.sX = s.endX;
           s.eX = s.startX;
        }

        if (s.offY<0)
        {
           s.stepY = -1;
           s.sY = s.endY;
        }
    }

    // Pre-calculate bulge/pinch constants
    s.falloff_sq = s.falloff * s.falloff;
    s.dest_radius = (s.brushType==7 || s.brushType==8) ? (s.brushSize / 2.0) : (s.brushSize / 2.0 + s.bulgePinchFactor);
    if (s.dest_radius<0.5)
       s.dest_radius = 0.5;

    s.overDrawOkay = (s.brushType==4 && s.eraserMode==1 && s.bytesPerPixel==4) ? 0 : 1;
    if (s.overDrawOkay==0)
    {
       s.opaf = (s.brushOverDraw==1) ? 0.75 : 0.35;
       s.opacity = (s.brushOverDraw==1) ? 191 : 89;
    }

    // Thread-safe chunk pre-allocation (Single-Threaded)
    if (s.brushType<=5 && s.brushOverDraw==0 && s.overDrawOkay==1)
    {
        int startCY = s.startY >> 7;
        int endCY = s.endY >> 7;
        int startCX = s.startX >> 7;
        int endCX = s.endX >> 7;
        for (int cy = startCY; cy <= endCY; ++cy)
        {
            size_t cy_grid = (size_t)cy * chunkGridW;
            for (int cx = startCX; cx <= endCX; ++cx)
            {
                size_t chunkIdx = cy_grid + cx;
                bool chunkCreated = false;
                if (chunkIdx < brushOpacityChunks.size() && !brushOpacityChunks[chunkIdx])
                {
                    try
                    {
                        brushOpacityChunks[chunkIdx] = new unsigned char[128 * 128]();
                        if (s.useBlendMode==1)
                        {
                           brushOriginalPixelChunks[chunkIdx] = new unsigned char[128 * 128 * s.bytesPerPixel]();
                           activeBrushChunks.push_back(chunkIdx);
                        }

                        chunkCreated = true;
                    } catch (const std::bad_alloc&) {
                        return false;
                    }
                }

                if (s.useBlendMode==1 && chunkIdx<brushOpacityChunks.size())
                {
                    unsigned char* origBuf = brushOriginalPixelChunks[chunkIdx];
                    unsigned char* opaChunk = brushOpacityChunks[chunkIdx];
                    if (origBuf && opaChunk)
                    {
                        int startBlockX = cx << 7;
                        int startBlockY = cy << 7;
                        int copyW = min(128, s.imgW - startBlockX);
                        int copyH = min(128, s.imgH - startBlockY);

                        int safeMemX1 = (s.lockW > 0) ? s.lockX : 0;
                        int safeMemX2 = (s.lockW > 0) ? (s.lockX + s.lockW - 1) : (s.imgW - 1);
                        int safeMemY1 = (s.lockH > 0) ? s.lockY : 0;
                        int safeMemY2 = (s.lockH > 0) ? (s.lockY + s.lockH - 1) : (s.imgH - 1);
                        for (int by = 0; by < copyH; ++by)
                        {
                            int py = startBlockY + by;
                            int iy = s.imgH - 1 - py;
                            if (iy<safeMemY1 || iy>safeMemY2)
                               continue;

                            int chunkStartX = startBlockX;
                            int chunkEndX = startBlockX + copyW - 1;
                            int validStartX = max(chunkStartX, safeMemX1);
                            int validEndX = min(chunkEndX, safeMemX2);
                            if (validStartX <= validEndX)
                            {
                                int validCopyW = validEndX - validStartX + 1;
                                int offsetX = validStartX - startBlockX;

                                unsigned char* srcRow = s.imgData + (INT64)iy * s.pitch + validStartX * s.bytesPerPixel;
                                unsigned char* dstRow = origBuf + by * 128 * s.bytesPerPixel + offsetX * s.bytesPerPixel;
                                if (chunkCreated)
                                {
                                    memcpy(dstRow, srcRow, validCopyW * s.bytesPerPixel);
                                } else
                                {
                                    unsigned char* opaRow = opaChunk + by * 128 + offsetX;
                                    for (int p = 0; p < validCopyW; ++p)
                                    {
                                        if (opaRow[p]==0)
                                        {
                                            for (int b = 0; b < s.bytesPerPixel; ++b) {
                                                dstRow[p * s.bytesPerPixel + b] = srcRow[p * s.bytesPerPixel + b];
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return true;
}

// the ellipse each row is scanned across (a circle for the pinch and bulge brushes), and the blend mode,
// normal unless the brush type takes one
static void brushSetupEllipse(BrushStamp &s) {
    double use_rx = s.rx;
    double use_ry = s.ry;
    double use_cosA = s.cosA;
    double use_sinA = s.sinA;
    if (s.brushType==7 || s.brushType==8)
    {
        // pinch and bulge brushes
        double max_rad = min(s.brushSize / 2.0, s.dest_radius);
        use_rx = max_rad;
        use_ry = max_rad;
        use_cosA = 1.0;
        use_sinA = 0.0;
    }

    s.invRx = 1.0 / s.rx;
    s.invRy = 1.0 / s.ry;
    double invUseRx = 1.0 / use_rx;
    double invUseRy = 1.0 / use_ry;

    // Pre-calculate constants for rotated ellipse mathematical boundaries
    double k1 = use_cosA * invUseRx;
    double k2 = use_sinA * invUseRx;
    double k3 = use_sinA * invUseRy;
    double k4 = use_cosA * invUseRy;
    s.A_coeff = k1 * k1 + k3 * k3;
    s.B_term_factor = 2.0 * (k3 * k4 - k1 * k2);
    s.C_term_factor = k2 * k2 + k4 * k4;

    int minY = min(s.startY, s.endY);
    int maxY = max(s.startY, s.endY);
    s.totalStepsY = maxY - minY + 1;
    s.blendMode = (s.brushType==2 || s.brushType==3 || s.brushType>=5) ? s.blendMode : 0;
    s.flipLayers = (s.brushType==2 || s.brushType==3 || s.brushType>=5) ? s.flipLayers : 0;
}

// lightness, gamma/contrast, hue and saturation of the cloner and effects brushes
static QPV_FORCEINLINE void brushAdjust(const BrushStamp &s, const int effB, const int effG, const int effR, const int effA,
                                        int &srcB, int &srcG, int &srcR, int &srcA) {
    RGBA16color pixel = { char_to_int[effB], char_to_int[effG], char_to_int[effR], char_to_int[effA] };
    if (s.brushBright!=0)
       pixel.brightness<true>(s.brushBright, 1, 0, s.fiBright, 0.0, brushLUTs);

    if (s.brushContra!=0)
       pixel.contrast<true>(s.brushContra, s.linearGamma, s.factorContrast, 0, s.fiContra, brushLUTs);

    if (s.brushHue!=0)
       pixel.hueRotate(s.brushHue);

    if (s.brushSat!=0)
       pixel.saturation(s.brushSat, 1, s.linearGamma, s.saturateFactor);

    srcB = int_to_char[pixel.b];
    srcG = int_to_char[pixel.g];
    srcR = int_to_char[pixel.r];
    srcA = int_to_char[pixel.a];
}

// Cloner brush: sample from srcData; false when the source pixel is off the image
static QPV_FORCEINLINE bool brushSourceCloner(const BrushStamp &s, const int px, const int py, int &srcB, int &srcG, int &srcR, int &srcA) {
    int srcX_raw = (int)round(px - s.offX);
    int srcY_raw = (int)round(py - s.offY);
    if (srcX_raw<0 || srcX_raw>=s.imgW || srcY_raw<0 || srcY_raw>=s.imgH)
       return false;

    int srcX = srcX_raw;
    int srcY = srcY_raw;
    const unsigned char* srcData = s.cloneData ? s.cloneData : s.imgData;
    int srcPitch = s.cloneData ? s.clonePitch : s.pitch;
    int s_iy = s.imgH - 1 - srcY;
    const unsigned char* srcPixel = srcData + (INT64)s_iy * srcPitch + srcX * s.bytesPerPixel;

    const int effB = srcPixel[0];
    const int effG = srcPixel[1];
    const int effR = srcPixel[2];
    const int effA = (s.bytesPerPixel == 4) ? srcPixel[3] : 255;
    brushAdjust(s, effB, effG, effR, effA, srcB, srcG, srcR, srcA);
    return true;
}

// Eraser brush
static QPV_FORCEINLINE void brushSourceEraser(const BrushStamp &s, int &srcB, int &srcG, int &srcR, int &srcA) {
    if (s.bytesPerPixel==3)
    {
        // Restore mode: restore color and alpha from cloneData
        srcR = 0;
        srcG = 0;
        srcB = 0;
        srcA = 255;
    } else if (s.bytesPerPixel==4)
    {
        if (s.eraserMode==1)
           srcA = s.ropacity;  // Replace/overdraw alpha
        else
           srcA = 0;        // Standard erase: reduce alpha
    }
}

// Effects brush: Hue, Saturation, Lightness, Gamma, Blur
static QPV_FORCEINLINE void brushSourceEffects(const BrushStamp &s, const int px, const int py, const int tgtB, const int tgtG, const int tgtR,
                                               const int tgtA, int &srcB, int &srcG, int &srcR, int &srcA) {
    int effB = tgtB;
    int effG = tgtG;
    int effR = tgtR;
    int effA = tgtA;

    // 1. Box Blur using OpenCV
    if (s.hasBlurredRoi)
    {
        int localX = px - s.roiStartX;
        int localY = s.roiEndY - py;
        if (localX >= 0 && localX < s.blurredRoi.cols && localY >= 0 && localY < s.blurredRoi.rows)
        {
            if (s.blurIsWeighted)
            {
                // colour = blur(c*a) / blur(a); with nothing visible around, the pixel keeps its own colour
                const float* blurredPixel = s.blurredRoi.ptr<float>(localY, localX);
                const float ba = blurredPixel[3];
                if (ba>=0.5f)
                {
                   effB = clamp((int)(blurredPixel[0] / ba + 0.5f), 0, 255);
                   effG = clamp((int)(blurredPixel[1] / ba + 0.5f), 0, 255);
                   effR = clamp((int)(blurredPixel[2] / ba + 0.5f), 0, 255);
                }
                effA = clamp((int)(ba + 0.5f), 0, 255);
            } else
            {
                const unsigned char* blurredPixel = s.blurredRoi.ptr<unsigned char>(localY, localX);
                effB = blurredPixel[0];
                effG = blurredPixel[1];
                effR = blurredPixel[2];
                if (s.bytesPerPixel == 4)
                   effA = blurredPixel[3];
            }
        }
    }

    // 2. Lightness, Gamma/Contrast, Hue, Saturation adjustments using RGBA16color
    brushAdjust(s, effB, effG, effR, effA, srcB, srcG, srcR, srcA);
}

// Smudge, pinch and bulge brushes: a bilinear sample of the clone, or of the image, at srcXf, srcYf
static QPV_FORCEINLINE void brushSampleAt(const BrushStamp &s, const double srcXf, const double srcYf, int &srcB, int &srcG, int &srcR, int &srcA) {
    int x1 = (int)floor(srcXf);
    int y1 = (int)floor(srcYf);
    int x2 = clamp(x1 + 1, 0, s.imgW - 1);
    int y2 = clamp(y1 + 1, 0, s.imgH - 1);

    double fx = srcXf - floor(srcXf);
    double fy = srcYf - floor(srcYf);

    double w11 = (1.0 - fx) * (1.0 - fy);
    double w21 = fx * (1.0 - fy);
    double w12 = (1.0 - fx) * fy;
    double w22 = fx * fy;

    const unsigned char *p11, *p21, *p12, *p22;
    if (!s.localClone.empty())
    {
        int lx1 = clamp(x1 - s.cloneStartX, 0, s.cloneW - 1);
        int ly1 = clamp(y1 - s.cloneStartY, 0, s.cloneH - 1);
        int lx2 = clamp(x2 - s.cloneStartX, 0, s.cloneW - 1);
        int ly2 = clamp(y2 - s.cloneStartY, 0, s.cloneH - 1);

        p11 = s.localClone.data() + (INT64)ly1 * s.localPitch + lx1 * s.bytesPerPixel;
        p21 = s.localClone.data() + (INT64)ly1 * s.localPitch + lx2 * s.bytesPerPixel;
        p12 = s.localClone.data() + (INT64)ly2 * s.localPitch + lx1 * s.bytesPerPixel;
        p22 = s.localClone.data() + (INT64)ly2 * s.localPitch + lx2 * s.bytesPerPixel;
    } else
    {
        const unsigned char* srcData = s.cloneData ? s.cloneData : s.imgData;
        int srcPitch = s.cloneData ? s.clonePitch : s.pitch;

        int s_iy1 = s.imgH - 1 - y1;
        int s_iy2 = s.imgH - 1 - y2;

        p11 = srcData + (INT64)s_iy1 * srcPitch + x1 * s.bytesPerPixel;
        p21 = srcData + (INT64)s_iy1 * srcPitch + x2 * s.bytesPerPixel;
        p12 = srcData + (INT64)s_iy2 * srcPitch + x1 * s.bytesPerPixel;
        p22 = srcData + (INT64)s_iy2 * srcPitch + x2 * s.bytesPerPixel;
    }

    brushBilinearSample(p11, p21, p12, p22, w11, w21, w12, w22, s.bytesPerPixel, srcB, srcG, srcR, srcA);
}

// bulge/pinch brushes: where the pixel dx, dy from the centre takes its colour from; false outside the brush
static QPV_FORCEINLINE bool brushWarpOffset(const BrushStamp &s, const double dx, const double dy, const int mask_val, double &src_dx, double &src_dy) {
    double r_dest = sqrt(dx * dx + dy * dy);
    double R = s.brushSize / 2.0;
    if (r_dest>=R)
       return false;

    if (r_dest<1e-6)
    {
        src_dx = 0.0;
        src_dy = 0.0;
    } else
    {
        double r = r_dest / R;
        // Extract wetness from bulgePinchFactor
        // bulgePinchFactor = wetness + 1 (for bulge)
        // bulgePinchFactor = -wetness - 1 (for pinch)
        double wetness = (s.brushType==8) ? (double)(s.bulgePinchFactor - 1) : (double)(-s.bulgePinchFactor - 1);
        double t = wetness / 32.0;
        if (t < 0.0) t = 0.0;
        if (t > 1.0) t = 1.0;

        double t2 = t * t;
        double p = 1.0;
        if (s.brushType==8) // bulge
            p = 1.0 + 7.0 * (t2/5);
        else // pinch
            p = 1.0 - 0.9 * (t2/2);

        double warped_r = R * pow(r, p);
        double warped_dx = dx * (warped_r / r_dest);
        double warped_dy = dy * (warped_r / r_dest);

        // Blend coordinates based on softness mask
        double w = mask_val / 255.0;
        src_dx = dx * (1.0 - w) + warped_dx * w;
        src_dy = dy * (1.0 - w) + warped_dy * w;
    }
    return true;
}

// the brush kinds the pixel loop is compiled for; Other is any other brushType, whose source is the pixel itself
enum class BrushKind { Other, Paint, Cloner, Eraser, Effects, Smudge, Warp };

template<BrushKind K>
static void brushRows(const BrushStamp &s) {
    // Multi-threaded outer loop (100% thread-safe)
    #pragma omp parallel for schedule(dynamic)
    for (int i=0; i < s.totalStepsY; ++i)
    {
        int py = (s.stepY>0) ? (s.sY + i) : (s.sY - i);
        int iy = s.imgH - 1 - py;
        INT64 rowOffset = (INT64)iy * s.pitch;

        // Pre-calculate Y-dependent values for standard brushes chunk lookup
        int cy = 0;
        int py_mod = 0;
        int py_mod_shift = 0;
        size_t cy_grid = 0;
        if (s.brushType<=5 && s.brushOverDraw==0)
        {
            cy = py >> 7;
            py_mod = py & 127;
            py_mod_shift = py_mod << 7;
            cy_grid = (size_t)cy * chunkGridW;
        }

        // Determine row-level pixel range
        int scan_sX = s.sX;
        int scan_eX = s.eX;
        if (!s.texData || s.texW<=0 || s.texH<=0)
        {
            double Y = py - s.tkY;
            double B_coeff = Y * s.B_term_factor;
            double C_coeff = Y * Y * s.C_term_factor - 1.0;
            double discriminant = B_coeff * B_coeff - 4.0 * s.A_coeff * C_coeff;
            if (discriminant<0)
               continue; // The row does not intersect the ellipse/circle

            double sqrt_d = sqrt(discriminant);
            double x_min = (-B_coeff - sqrt_d) / (2.0 * s.A_coeff);
            double x_max = (-B_coeff + sqrt_d) / (2.0 * s.A_coeff);

            // Map back to canvas coords & clamp to bounding box
            int leftX = clamp((int)floor(s.tkX + x_min), min(s.sX, s.eX), max(s.sX, s.eX));
            int rightX = clamp((int)ceil(s.tkX + x_max), min(s.sX, s.eX), max(s.sX, s.eX));
            if (s.stepX>0)
            {
               scan_sX = leftX;
               scan_eX = rightX;
            } else
            {
               scan_sX = rightX;
               scan_eX = leftX;
            }
        }

        for (int px = scan_sX; s.stepX>0 ? px<=scan_eX : px>=scan_eX; px += s.stepX)
        {
            if (s.lockW>0 && (px<s.lockX || px>=s.lockX+s.lockW || iy<s.lockY || iy>=s.lockY+s.lockH))
               continue;

            // 1. Calculate selection constraints
            if (s.useSelArea)
            {
                // the selection is prepared in bottom-up rows; the rows of a GDI+ lock [lockW>0] are top-down
                if (clipMaskFilter(px, (s.lockW>0) ? py : iy, NULL, 0) == 1)
                   continue;
            }

            // 2. Compute rotated coordinates and elliptical mask
            double dx = px - s.tkX;
            double dy = py - s.tkY;
            double src_dx = dx;
            double src_dy = dy;

            int mask_val = 255;
            if (s.texData && s.texW>0 && s.texH>0)
            {
                int tx = (int)(dx + s.texW / 2.0);
                int ty = (int)(dy + s.texH / 2.0);
                if (tx>=0 && tx<s.texW && ty>=0 && ty<s.texH)
                {
                    int texBytes = s.texBpp / 8;
                    int t_iy = s.texH - 1 - ty;
                    unsigned char* texPixel = s.texData + (INT64)t_iy * s.texPitch + tx * texBytes;
                    mask_val = texPixel[0];
                } else {
                    mask_val = 0;
                }
            } else
            {
                double rotX = src_dx * s.cosA - src_dy * s.sinA;
                double rotY = src_dx * s.sinA + src_dy * s.cosA;

                // Evaluate using squared distance (saves an expensive sqrt per pixel)
                double dist_norm_sq = (rotX * s.invRx) * (rotX * s.invRx) + (rotY * s.invRy) * (rotY * s.invRy);
                if (dist_norm_sq>1)
                   continue;

                if (s.softness>0)
                {
                    if (dist_norm_sq>=s.falloff_sq)
                    {
                        // Only compute sqrt if we are in the outer soft boundary
                        double dist_norm = sqrt(dist_norm_sq);
                        mask_val = (int)(255.0 * (1.0 - dist_norm) / (1.0 - s.falloff));
                        mask_val = clamp(mask_val, 0, 255);
                    }
                }
            }

            if (mask_val==0)
               continue;

            float mask_fval = mask_val / 255.0f;
            if constexpr (K == BrushKind::Warp)
            {
                if (!brushWarpOffset(s, dx, dy, mask_val, src_dx, src_dy))
                   continue;
            }

            // Sequential/cache-friendly pixel lookups (100% L1/L2 hits)
            unsigned char* targetPixel = s.imgData + rowOffset + px * s.bytesPerPixel;

            // Read target color (BGRA or BGR)
            int tgtB = targetPixel[0];
            int tgtG = targetPixel[1];
            int tgtR = targetPixel[2];
            int tgtA = (s.bytesPerPixel==4) ? targetPixel[3] : 255;

            // Prepare output color
            int outB = tgtB;
            int outG = tgtG;
            int outR = tgtR;
            int outA = tgtA;
            int srcB = tgtB;
            int srcG = tgtG;
            int srcR = tgtR;
            int srcA = tgtA;
            float weight = mask_fval * s.opaf;
            if constexpr (K == BrushKind::Smudge)
            {
                if (s.bulgePinchFactor>0)
                {
                    int wetness = s.bulgePinchFactor - 1;
                    if (wetness>15)
                    {
                        double weight_boost = 1.0 + 1.5 * ((wetness - 15) / 7.0);
                        weight = clamp((float)(weight * weight_boost), 0.0f, 1.0f);
                    }
                } else
                {
                    weight = clamp(weight * 1.5f, 0.0f, 1.0f);
                }
            }

            if (s.brushType<=5 && s.brushOverDraw==0 && s.overDrawOkay==1)
            {
                int cx = px >> 7;
                size_t chunkIdx = cy_grid + cx;
                unsigned char* chunk = brushOpacityChunks[chunkIdx];
                if (!chunk)
                {
                    try
                    {
                        chunk = new unsigned char[128 * 128]();
                        #pragma omp critical
                        {
                            if (!brushOpacityChunks[chunkIdx])
                            {
                                brushOpacityChunks[chunkIdx] = chunk;
                            } else
                            {
                                delete[] chunk;
                                chunk = brushOpacityChunks[chunkIdx];
                            }
                        }
                    } catch (const std::bad_alloc&) {
                        continue;
                    }
                }

                int px_mod = px & 127;
                int pixelIdx = py_mod_shift + px_mod;
                if (chunk[pixelIdx]>=s.opacity)
                   continue;

                float accOpa = chunk[pixelIdx] / 255.0f;
                float newAccOpa = accOpa + weight - accOpa * weight;
                if (s.useBlendMode==1)
                {
                    if (newAccOpa>=s.opaf)
                       newAccOpa = s.opaf;

                    weight = newAccOpa;
                    chunk[pixelIdx] = (unsigned char)clamp(newAccOpa * 255.0f, 0.0f, 255.0f);
                    unsigned char* origBuf = brushOriginalPixelChunks[chunkIdx];
                    if (origBuf)
                    {
                        int localOffset = pixelIdx * s.bytesPerPixel;
                        tgtB = origBuf[localOffset + 0];
                        tgtG = origBuf[localOffset + 1];
                        tgtR = origBuf[localOffset + 2];
                        if (s.bytesPerPixel==4)
                           tgtA = origBuf[localOffset + 3];
                    }
                } else
                {
                    float maxAllowedWeight = (s.opaf - accOpa) / (1.0f - accOpa);
                    if (weight>=maxAllowedWeight)
                    {
                        weight = maxAllowedWeight;
                        chunk[pixelIdx] = s.opacity;
                    } else
                    {
                        chunk[pixelIdx] = (unsigned char)clamp(newAccOpa * 255.0f, 0.0f, 255.0f);
                    }
                }
            }

            int weightInt = clamp(weight * 255.0f, 0.0f, 255.0f);
            if constexpr (K == BrushKind::Paint)
            {
                // Paint brush: Solid/Soft Color
                srcR = s.brushR;
                srcG = s.brushG;
                srcB = s.brushB;
                srcA = s.brushA;
            } else if constexpr (K == BrushKind::Cloner)
            {
                if (!brushSourceCloner(s, px, py, srcB, srcG, srcR, srcA))
                   continue;
            } else if constexpr (K == BrushKind::Eraser)
            {
                brushSourceEraser(s, srcB, srcG, srcR, srcA);
            } else if constexpr (K == BrushKind::Effects)
            {
                brushSourceEffects(s, px, py, tgtB, tgtG, tgtR, tgtA, srcB, srcG, srcR, srcA);
            } else if constexpr (K == BrushKind::Smudge)
            {
                // Smudge brush: grab pixels from previous offset position with bilinear interpolation
                double srcXf = clamp((double)px - s.cloneOffsetX, 0.0, (double)(s.imgW - 1));
                double srcYf = clamp((double)py - s.cloneOffsetY, 0.0, (double)(s.imgH - 1));
                brushSampleAt(s, srcXf, srcYf, srcB, srcG, srcR, srcA);
            } else if constexpr (K == BrushKind::Warp)
            {
                // Pinch / Bulge brush: scale coordinate mapping with bilinear interpolation
                double srcXf = clamp(s.tkX + src_dx, 0.0, (double)(s.imgW - 1));
                double srcYf = clamp(s.tkY + src_dy, 0.0, (double)(s.imgH - 1));
                brushSampleAt(s, srcXf, srcYf, srcB, srcG, srcR, srcA);
            }

            if (K == BrushKind::Eraser && s.bytesPerPixel==4)
            {
               outA = weighTwoValues(srcA, tgtA, weight);
            } else if (s.blendMode==24)
            {
               // the stroke's opacity, capped by the source's alpha, becomes the alpha and the mask the weight [the
               // opacity argument is subtractive]; a product would compound where a brush samples its own output
               RGBAColor Orgb = { srcB, srcG, srcR, (s.bytesPerPixel==4) ? min(srcA, s.opacity) : 255 };
               RGBAColor Brgb = { tgtB, tgtG, tgtR, tgtA };
               RGBAColor replaced = CalculateNewBlendModes(Orgb, Brgb, 24, 0, s.linearGamma, 0, s.imgBpp, 255 - mask_val);
               outR = replaced.r;
               outG = replaced.g;
               outB = replaced.b;
               outA = replaced.a;
            } else
            {
               outA = (srcA * weightInt + 127) / 255;
               RGBAColor Orgb = { srcB, srcG, srcR, outA };
               RGBAColor Brgb = { tgtB, tgtG, tgtR, tgtA };
               RGBAColor blended = CalculateNewBlendModes(Orgb, Brgb, s.blendMode, s.flipLayers, s.linearGamma, s.eraserMode, s.imgBpp, 0);
               outR = blended.r;
               outG = blended.g;
               outB = blended.b;
               outA = blended.a;
            }

            // Write back to imgData
            targetPixel[0] = clamp(outB, 0, 255);
            targetPixel[1] = clamp(outG, 0, 255);
            targetPixel[2] = clamp(outR, 0, 255);
            if (s.bytesPerPixel==4)
               targetPixel[3] = clamp(outA, 0, 255);
        }
    }
}

DLL_API int DLL_CALLCONV PaintBrushLarge(
    unsigned char* imgData,  // FreeImage pixel buffer (from FreeImage_GetBits)
    int imgW,                // Image width
    int imgH,                // Image height
    int pitch,               // Image pitch/stride (FreeImage_GetPitch)
    int imgBpp,              // Bits per pixel (24 or 32)
    int brushType,           // BrushToolType (1-8)
    double tkX,              // Current stroke point X (image space)
    double tkY,              // Current stroke point Y (image space)
    int brushSize,           // Brush diameter
    int softness,            // BrushToolSoftness (0-100)
    double angle,            // BrushToolAngle (-180 to 180)
    double aspectRatio,      // BrushToolAspectRatio (-100 to 100)
    int brushColor,          // ARGB color
    int opacity,             // Stroke opacity (0-255)
    int blendMode,           // BlendMode index (0-25)
    double offX,             // Smudge/Cloner offset X
    double offY,             // Smudge/Cloner offset Y
    unsigned char* cloneData, // Backup pixel buffer (null if memory limits reached)
    int clonePitch,          // Backup buffer pitch
    int eraserMode,          // Eraser mode (0=std, 1=replace)
    int useSelArea,          // Selection clip active flag (0/1)
    int linearGamma,         // Gamma correct flag
    int flipLayers,          // Flip blend layers flag
    int bulgePinchFactor,    // Bulge/pinch factor (+ for bulge, - for pinch)
    int effectHue,           // Effects brush: Hue adjustment
    int effectSat,           // Effects brush: Saturation adjustment
    int effectLight,         // Effects brush: Lightness adjustment
    int effectGamma,         // Effects brush: Gamma adjustment
    int effectBlur,          // Effects brush: Blur strength
    unsigned char* texData,  // Texture pixel buffer (null if BrushToolTexture = 1/circular)
    int texW,                // Texture width
    int texH,                // Texture height
    int texPitch,            // Texture stride
    int texBpp,              // Texture bits-per-pixel
    int brushOverDraw,       // BrushToolOverDraw (0 or 1)
    int lockX = 0,
    int lockY = 0,
    int lockW = 0,
    int lockH = 0
) {
    if (!imgData || imgW<=0 || imgH<=0 || pitch<=0 || brushSize<=0)
    {
       fnOutputDebug("PaintBrushLarge(): incorrect data provided");
       return 0;
    }

    int bytesPerPixel = imgBpp / 8;
    if (bytesPerPixel!=3 && bytesPerPixel!=4)
    {
       fnOutputDebug("PaintBrushLarge() only supports 24-bit (BGR) and 32-bit (BGRA) formats.");
       return 0;
    }

    BrushStamp s = {imgData, imgW, imgH, pitch, imgBpp, brushType, tkX, tkY, brushSize, softness, angle, aspectRatio,
                    brushColor, opacity, blendMode, offX, offY, cloneData, clonePitch, eraserMode, useSelArea, linearGamma,
                    flipLayers, bulgePinchFactor, effectHue, effectSat, effectLight, effectGamma, effectBlur,
                    texData, texW, texH, texPitch, texBpp, brushOverDraw, lockX, lockY, lockW, lockH};
    s.bytesPerPixel = bytesPerPixel;
    brushSetupChunkGrid(s);
    if (!brushSetupClone(s))
       return 0;

    brushSetupShape(s);
    if (!brushSetupEffects(s) || !brushSetupPass(s))
       return 0;

    brushSetupEllipse(s);
    switch (brushType)
    {
        case 1: case 2: brushRows<BrushKind::Paint>(s); break;
        case 3: brushRows<BrushKind::Cloner>(s); break;
        case 4: brushRows<BrushKind::Eraser>(s); break;
        case 5: brushRows<BrushKind::Effects>(s); break;
        case 6: brushRows<BrushKind::Smudge>(s); break;
        case 7: case 8: brushRows<BrushKind::Warp>(s); break;
        default: brushRows<BrushKind::Other>(s);
    }
    return 1;
}

#endif // QPV_PAINT_BRUSH_H
