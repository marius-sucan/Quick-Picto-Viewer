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

    int useBlendMode = (brushType==2 || brushType==3 || brushType>=5) && (blendMode>=8) ? 1 : 0;
    if (blendMode==13 || blendMode==14 || blendMode==23)
       useBlendMode = 0;

    if (brushType<=5 && brushOverDraw==0)
    {
        int numChunksX = (imgW + 127) >> 7;
        int numChunksY = (imgH + 127) >> 7;
        size_t totalChunks = (size_t)numChunksX * numChunksY;
        if (brushOpacityChunks.empty() || brushOpacityChunks.size() != totalChunks || (useBlendMode == 1 && brushOriginalPixelChunks.size() != totalChunks))
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
            if (useBlendMode == 1)
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

    int halfW = (texData && texW > 0) ? (texW / 2 + abs(bulgePinchFactor)) : (brushSize / 2 + abs(bulgePinchFactor));
    int halfH = (texData && texH > 0) ? (texH / 2 + abs(bulgePinchFactor)) : (brushSize / 2 + abs(bulgePinchFactor));
    int startX = clamp((int)(tkX - halfW), 0, imgW - 1);
    int endX = clamp((int)(tkX + halfW), 0, imgW - 1);
    int startY = clamp((int)(tkY - halfH), 0, imgH - 1);
    int endY = clamp((int)(tkY + halfH), 0, imgH - 1);

    int cloneStartX = startX;
    int cloneEndX = endX;
    int cloneStartY = startY;
    int cloneEndY = endY;
    double cloneOffsetX = offX;
    double cloneOffsetY = offY;
    if (brushType==6)
    {
        double scale = 3.0;
        if (bulgePinchFactor>0)
        {
            int wetness = bulgePinchFactor - 1;
            scale = 1.0 + 26.0 * (wetness / 22.0);
        }

        cloneOffsetX = offX * scale;
        cloneOffsetY = offY * scale;
        cloneStartX = clamp((int)floor(startX - std::max(0.0, cloneOffsetX)) - 2, 0, imgW - 1);
        cloneEndX = clamp((int)ceil(endX - std::min(0.0, cloneOffsetX)) + 2, 0, imgW - 1);
        cloneStartY = clamp((int)floor(startY - std::max(0.0, cloneOffsetY)) - 2, 0, imgH - 1);
        cloneEndY = clamp((int)ceil(endY - std::min(0.0, cloneOffsetY)) + 2, 0, imgH - 1);
    }

    if (lockW>0)
    {
        // a GDI+ lock holds only its rect, with top-down rows; samples past it take its edge pixels
        cloneStartX = max(cloneStartX, lockX);
        cloneEndX = min(cloneEndX, lockX + lockW - 1);
        cloneStartY = max(cloneStartY, imgH - lockY - lockH);
        cloneEndY = min(cloneEndY, imgH - 1 - lockY);
    }

    int cloneW = cloneEndX - cloneStartX + 1;
    int cloneH = cloneEndY - cloneStartY + 1;
    std::vector<unsigned char> localClone;
    int localPitch = cloneW * bytesPerPixel;
    if (!cloneData && brushType>=6 && cloneW>0 && cloneH>0)
    {
        try
        {
            // Limit allocation size to 150MB to prevent OOM
            if ((size_t)cloneW * cloneH * bytesPerPixel < 150 * 1024 * 1024)
            {
                localClone.resize((size_t)cloneW * cloneH * bytesPerPixel);
                for (int ry = 0; ry < cloneH; ++ry)
                {
                    int img_py = cloneStartY + ry;
                    int img_iy = imgH - 1 - img_py;
                    unsigned char* srcRow = imgData + (INT64)img_iy * pitch + cloneStartX * bytesPerPixel;
                    unsigned char* dstRow = localClone.data() + (INT64)ry * localPitch;
                    memcpy(dstRow, srcRow, localPitch);
                }
            }
        } catch (...) {
            localClone.clear();
        }
    }

    // without the copy, the samplers below read the image directly, past the lock rect
    if (lockW>0 && !cloneData && brushType>=6 && localClone.empty())
       return 0;

    // Parse foreground color channels
    int brushA = (brushColor >> 24) & 0xFF;
    int brushR = (brushColor >> 16) & 0xFF;
    int brushG = (brushColor >> 8) & 0xFF;
    int brushB = brushColor & 0xFF;

    // Softness calculations
    double falloff = (100.0 - softness) / 100.0;

    // Angle in radians (for rotated elliptical brush mask)
    double rad = -angle * M_PI / 180.0;
    double cosA = cos(rad);
    double sinA = sin(rad);

    // Calculate semi-axes rx, ry based on aspectRatio (-100 to 100)
    double thisAR = 1.0 - abs(aspectRatio) / 105.0;
    double rx = (aspectRatio > 0.0) ? (brushSize * thisAR) / 2.0 : brushSize / 2.0;
    double ry = (aspectRatio < 0.0) ? (brushSize * thisAR) / 2.0 : brushSize / 2.0;
    if (rx < 0.5) rx = 0.5;
    if (ry < 0.5) ry = 0.5;

    // Pre-calculate blurred ROI if needed
    cv::Mat blurredRoi;
    int roiStartX = 0, roiEndX = 0, roiStartY = 0, roiEndY = 0;
    bool hasBlurredRoi = false;
    bool blurIsWeighted = false;

    // LUT and scaling variables for brush type 5
    int brushHue = effectHue;
    int brushSat = (int)round(effectSat * 655.35);
    int brushBright = effectLight * 257;
    int brushContra = (int)round(effectGamma * 655.30);
    if (brushContra>65525)
       brushContra = 65525;

    float fiBright = 0.0f;
    float factorContrast = 0.0f;
    float fiContra = 0.0f;
    float saturateFactor = 0.0f;
    if (brushType==5 || brushType==3)
    {
        // Effects and cloner brushes
        // Prepare LUT tables as in AdjustImageColorsPrecise()
        // (no gammaBright build: brightness() is called with altMode==1 below,
        //  which never reads that table)
        fiBright = (brushBright > 0) ? brushBright / 32768.0f : -1.0f * int_to_float[-brushBright];
        if (brushBright!=0)
        {
            for (int i = 0; i < 65536; i++)
            {
                brushLUTs.bright[i] = brightMathsInt16(i, fiBright);
            }
        }

        factorContrast = brushContra / 98302.0f;
        fiContra = (65536.5f * (brushContra + 65535.0f)) / (65535.0f * (65536.5f - brushContra));
        if (brushContra!=0)
        {
            for (int i = 0; i < 65536; i++)
            {
                brushLUTs.contra[i] = contraMathsInt16(i, fiContra, 32768);
            }
        }

        saturateFactor = (brushSat < 0) ? (65535.0f - abs(brushSat)) / 131070.0f : 0.5f + brushSat / 131070.0f;
        if (effectBlur>2 && brushType==5)
        {
            int radius = effectBlur;
            int use_lockX = (lockW > 0 && !cloneData) ? lockX : 0;
            int use_lockY = (lockH > 0 && !cloneData) ? lockY : 0;
            int use_lockW = (lockW > 0 && !cloneData) ? lockW : imgW;
            int use_lockH = (lockH > 0 && !cloneData) ? lockH : imgH;

            // the ROI must stay inside the Mat below, which holds only the GDI+ lock rect on normal images
            roiStartX = clamp(startX - radius, use_lockX, use_lockX + use_lockW - 1);
            roiEndX = clamp(endX + radius, use_lockX, use_lockX + use_lockW - 1);
            roiStartY = clamp(startY - radius, imgH - use_lockY - use_lockH, imgH - 1 - use_lockY);
            roiEndY = clamp(endY + radius, imgH - use_lockY - use_lockH, imgH - 1 - use_lockY);

            int roiW = roiEndX - roiStartX + 1;
            int roiH = roiEndY - roiStartY + 1;
            if (roiW>0 && roiH>0)
            {
                unsigned char* srcData = cloneData ? cloneData : imgData;
                int srcPitch = cloneData ? clonePitch : pitch;
                int clr = (bytesPerPixel == 4) ? CV_8UC4 : CV_8UC3;

                // nothing may be thrown out of an exported function
                try
                {
                    cv::Mat srcMat(use_lockH, use_lockW, clr, srcData + (INT64)use_lockY * srcPitch + use_lockX * bytesPerPixel, srcPitch);
                    // Translate the vertical range [roiStartY, roiEndY] from bottom-up image coordinates
                    // to standard memory coordinates.
                    // py = roiStartY (bottom row) -> memory row = imgH - 1 - roiStartY (largest memory index)
                    // py = roiEndY (top row) -> memory row = imgH - 1 - roiEndY (smallest memory index)
                    cv::Rect roi(roiStartX - use_lockX, imgH - 1 - roiEndY - use_lockY, roiW, roiH);
                    cv::Mat srcRoi = srcMat(roi);

                    int kernelSize = 2 * radius + 1;
                    bool hasTransparency = false;
                    for (int y = 0; y < roiH && !hasTransparency && bytesPerPixel==4; y++)
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
                            const unsigned char* s = srcRoi.ptr<unsigned char>(y);
                            float* d = weighted.ptr<float>(y);
                            for (int x = 0; x < roiW * 4; x += 4)
                            {
                                const float a = s[x + 3];
                                d[x] = s[x] * a;
                                d[x + 1] = s[x + 1] * a;
                                d[x + 2] = s[x + 2] * a;
                                d[x + 3] = a;
                            }
                        }
                        cv::blur(weighted, blurredRoi, cv::Size(kernelSize, kernelSize));
                        blurIsWeighted = true;
                    } else
                    {
                        cv::blur(srcRoi, blurredRoi, cv::Size(kernelSize, kernelSize));
                    }
                    hasBlurredRoi = true;
                } catch (...)
                {
                    // fnOutputDebug("PaintBrushLarge(): the blur of the effects brush failed");
                    return 0;
                }
            }
        }
    }

    int stepX = 1;
    int stepY = 1;
    int sX = startX;
    int eX = endX;
    int sY = startY;
    int eY = endY;
    const int ropacity = opacity;
    float opaf = (opacity / 255.0f);
    if (brushType==6)
    {
        // smudge brush
        if (offX<0)
        {
           stepX = -1;
           sX = endX;
           eX = startX;
        }

        if (offY<0)
        {
           stepY = -1;
           sY = endY;
           eY = startY;
        }
    }

    // Pre-calculate bulge/pinch constants
    double falloff_sq = falloff * falloff;
    double dest_radius = (brushType==7 || brushType==8) ? (brushSize / 2.0) : (brushSize / 2.0 + bulgePinchFactor);
    if (dest_radius<0.5)
       dest_radius = 0.5;

    int overDrawOkay = (brushType==4 && eraserMode==1 && bytesPerPixel==4) ? 0 : 1;
    if (overDrawOkay==0)
    {
       opaf = (brushOverDraw==1) ? 0.75 : 0.35;
       opacity = (brushOverDraw==1) ? 191 : 89;
    }

    // Thread-safe chunk pre-allocation (Single-Threaded)
    if (brushType<=5 && brushOverDraw==0 && overDrawOkay==1)
    {
        int startCY = startY >> 7;
        int endCY = endY >> 7;
        int startCX = startX >> 7;
        int endCX = endX >> 7;
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
                        if (useBlendMode==1)
                        {
                           brushOriginalPixelChunks[chunkIdx] = new unsigned char[128 * 128 * bytesPerPixel]();
                           activeBrushChunks.push_back(chunkIdx);
                        }

                        chunkCreated = true;
                    } catch (const std::bad_alloc&) {
                        return 0;
                    }
                }

                if (useBlendMode==1 && chunkIdx<brushOpacityChunks.size())
                {
                    unsigned char* origBuf = brushOriginalPixelChunks[chunkIdx];
                    unsigned char* opaChunk = brushOpacityChunks[chunkIdx];
                    if (origBuf && opaChunk)
                    {
                        int startBlockX = cx << 7;
                        int startBlockY = cy << 7;
                        int copyW = min(128, imgW - startBlockX);
                        int copyH = min(128, imgH - startBlockY);
                        
                        int safeMemX1 = (lockW > 0) ? lockX : 0;
                        int safeMemX2 = (lockW > 0) ? (lockX + lockW - 1) : (imgW - 1);
                        int safeMemY1 = (lockH > 0) ? lockY : 0;
                        int safeMemY2 = (lockH > 0) ? (lockY + lockH - 1) : (imgH - 1);
                        for (int by = 0; by < copyH; ++by)
                        {
                            int py = startBlockY + by;
                            int iy = imgH - 1 - py;
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
                                
                                unsigned char* srcRow = imgData + (INT64)iy * pitch + validStartX * bytesPerPixel;
                                unsigned char* dstRow = origBuf + by * 128 * bytesPerPixel + offsetX * bytesPerPixel;
                                if (chunkCreated)
                                {
                                    memcpy(dstRow, srcRow, validCopyW * bytesPerPixel);
                                } else
                                {
                                    unsigned char* opaRow = opaChunk + by * 128 + offsetX;
                                    for (int p = 0; p < validCopyW; ++p)
                                    {
                                        if (opaRow[p]==0)
                                        {
                                            for (int b = 0; b < bytesPerPixel; ++b) {
                                                dstRow[p * bytesPerPixel + b] = srcRow[p * bytesPerPixel + b];
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

    double use_rx = rx;
    double use_ry = ry;
    double use_cosA = cosA;
    double use_sinA = sinA;
    if (brushType==7 || brushType==8)
    {
        // pinch and bulge brushes
        double max_rad = min(brushSize / 2.0, dest_radius);
        use_rx = max_rad;
        use_ry = max_rad;
        use_cosA = 1.0;
        use_sinA = 0.0;
    }

    double invRx = 1.0 / rx;
    double invRy = 1.0 / ry;
    double invUseRx = 1.0 / use_rx;
    double invUseRy = 1.0 / use_ry;

    // Pre-calculate constants for rotated ellipse mathematical boundaries
    double k1 = use_cosA * invUseRx;
    double k2 = use_sinA * invUseRx;
    double k3 = use_sinA * invUseRy;
    double k4 = use_cosA * invUseRy;
    double A_coeff = k1 * k1 + k3 * k3;
    double B_term_factor = 2.0 * (k3 * k4 - k1 * k2);
    double C_term_factor = k2 * k2 + k4 * k4;

    int minY = min(startY, endY);
    int maxY = max(startY, endY);
    int totalStepsY = maxY - minY + 1;
    blendMode = (brushType==2 || brushType==3 || brushType>=5) ? blendMode : 0;
    flipLayers = (brushType==2 || brushType==3 || brushType>=5) ? flipLayers : 0;

    // Multi-threaded outer loop (100% thread-safe)
    #pragma omp parallel for schedule(dynamic)
    for (int i=0; i < totalStepsY; ++i)
    {
        int py = (stepY>0) ? (sY + i) : (sY - i);
        int iy = imgH - 1 - py;
        INT64 rowOffset = (INT64)iy * pitch;

        // Pre-calculate Y-dependent values for standard brushes chunk lookup
        int cy = 0;
        int py_mod = 0;
        int py_mod_shift = 0;
        size_t cy_grid = 0;
        if (brushType<=5 && brushOverDraw==0)
        {
            cy = py >> 7;
            py_mod = py & 127;
            py_mod_shift = py_mod << 7;
            cy_grid = (size_t)cy * chunkGridW;
        }

        // Determine row-level pixel range
        int scan_sX = sX;
        int scan_eX = eX;
        if (!texData || texW<=0 || texH<=0)
        {
            double Y = py - tkY;
            double B_coeff = Y * B_term_factor;
            double C_coeff = Y * Y * C_term_factor - 1.0;
            double discriminant = B_coeff * B_coeff - 4.0 * A_coeff * C_coeff;
            if (discriminant<0)
               continue; // The row does not intersect the ellipse/circle

            double sqrt_d = sqrt(discriminant);
            double x_min = (-B_coeff - sqrt_d) / (2.0 * A_coeff);
            double x_max = (-B_coeff + sqrt_d) / (2.0 * A_coeff);

            // Map back to canvas coords & clamp to bounding box
            int leftX = clamp((int)floor(tkX + x_min), min(sX, eX), max(sX, eX));
            int rightX = clamp((int)ceil(tkX + x_max), min(sX, eX), max(sX, eX));
            if (stepX>0)
            {
               scan_sX = leftX;
               scan_eX = rightX;
            } else
            {
               scan_sX = rightX;
               scan_eX = leftX;
            }
        }

        for (int px = scan_sX; stepX>0 ? px<=scan_eX : px>=scan_eX; px += stepX)
        {
            if (lockW>0 && (px<lockX || px>=lockX+lockW || iy<lockY || iy>=lockY+lockH))
               continue;

            // 1. Calculate selection constraints
            if (useSelArea)
            {
                // the selection is prepared in bottom-up rows; the rows of a GDI+ lock [lockW>0] are top-down
                if (clipMaskFilter(px, (lockW>0) ? py : iy, NULL, 0) == 1)
                   continue;
            }

            // 2. Compute rotated coordinates and elliptical mask
            double dx = px - tkX;
            double dy = py - tkY;
            double src_dx = dx;
            double src_dy = dy;

            int mask_val = 255;
            if (texData && texW>0 && texH>0)
            {
                int tx = (int)(dx + texW / 2.0);
                int ty = (int)(dy + texH / 2.0);
                if (tx>=0 && tx<texW && ty>=0 && ty<texH)
                {
                    int texBytes = texBpp / 8;
                    int t_iy = texH - 1 - ty;
                    unsigned char* texPixel = texData + (INT64)t_iy * texPitch + tx * texBytes;
                    mask_val = texPixel[0];
                } else {
                    mask_val = 0;
                }
            } else
            {
                double rotX = src_dx * cosA - src_dy * sinA;
                double rotY = src_dx * sinA + src_dy * cosA;
                
                // Evaluate using squared distance (saves an expensive sqrt per pixel)
                double dist_norm_sq = (rotX * invRx) * (rotX * invRx) + (rotY * invRy) * (rotY * invRy);
                if (dist_norm_sq>1)
                   continue;

                if (softness>0)
                {
                    if (dist_norm_sq>=falloff_sq)
                    {
                        // Only compute sqrt if we are in the outer soft boundary
                        double dist_norm = sqrt(dist_norm_sq);
                        mask_val = (int)(255.0 * (1.0 - dist_norm) / (1.0 - falloff));
                        mask_val = clamp(mask_val, 0, 255);
                    }
                }
            }

            if (mask_val==0)
               continue;

            float mask_fval = mask_val / 255.0f;
            if (brushType==7 || brushType==8)
            {
                // bulge/pinch brushes
                double r_dest = sqrt(dx * dx + dy * dy);
                double R = brushSize / 2.0;
                if (r_dest>=R)
                   continue;

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
                    double wetness = (brushType==8) ? (double)(bulgePinchFactor - 1) : (double)(-bulgePinchFactor - 1);
                    double t = wetness / 32.0;
                    if (t < 0.0) t = 0.0;
                    if (t > 1.0) t = 1.0;

                    double t2 = t * t;
                    double p = 1.0;
                    if (brushType==8) // bulge
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
            }

            // Sequential/cache-friendly pixel lookups (100% L1/L2 hits)
            unsigned char* targetPixel = imgData + rowOffset + px * bytesPerPixel;

            // Read target color (BGRA or BGR)
            int tgtB = targetPixel[0];
            int tgtG = targetPixel[1];
            int tgtR = targetPixel[2];
            int tgtA = (bytesPerPixel==4) ? targetPixel[3] : 255;

            // Prepare output color
            int outB = tgtB;
            int outG = tgtG;
            int outR = tgtR;
            int outA = tgtA;
            int srcB = tgtB;
            int srcG = tgtG;
            int srcR = tgtR;
            int srcA = tgtA;
            float weight = mask_fval * opaf;
            if (brushType==6)
            {
                if (bulgePinchFactor>0)
                {
                    int wetness = bulgePinchFactor - 1;
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

            if (brushType<=5 && brushOverDraw==0 && overDrawOkay==1)
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
                if (chunk[pixelIdx]>=opacity)
                   continue;

                float accOpa = chunk[pixelIdx] / 255.0f;
                float newAccOpa = accOpa + weight - accOpa * weight;
                if (useBlendMode==1)
                {
                    if (newAccOpa>=opaf)
                       newAccOpa = opaf;

                    weight = newAccOpa;
                    chunk[pixelIdx] = (unsigned char)clamp(newAccOpa * 255.0f, 0.0f, 255.0f);
                    unsigned char* origBuf = brushOriginalPixelChunks[chunkIdx];
                    if (origBuf)
                    {
                        int localOffset = pixelIdx * bytesPerPixel;
                        tgtB = origBuf[localOffset + 0];
                        tgtG = origBuf[localOffset + 1];
                        tgtR = origBuf[localOffset + 2];
                        if (bytesPerPixel==4)
                           tgtA = origBuf[localOffset + 3];
                    }
                } else
                {
                    float maxAllowedWeight = (opaf - accOpa) / (1.0f - accOpa);
                    if (weight>=maxAllowedWeight)
                    {
                        weight = maxAllowedWeight;
                        chunk[pixelIdx] = opacity;
                    } else
                    {
                        chunk[pixelIdx] = (unsigned char)clamp(newAccOpa * 255.0f, 0.0f, 255.0f);
                    }
                }
            }

            int weightInt = clamp(weight * 255.0f, 0.0f, 255.0f);
            if (brushType==1 || brushType==2)
            {
                // Paint brush: Solid/Soft Color
                srcR = brushR;
                srcG = brushG;
                srcB = brushB;
                srcA = brushA;
            } else if (brushType==3)
            {
                // Cloner brush: sample from srcData
                int srcX_raw = (int)round(px - offX);
                int srcY_raw = (int)round(py - offY);
                if (srcX_raw<0 || srcX_raw>=imgW || srcY_raw<0 || srcY_raw>=imgH)
                   continue;

                int srcX = srcX_raw;
                int srcY = srcY_raw;
                unsigned char* srcData = cloneData ? cloneData : imgData;
                int srcPitch = cloneData ? clonePitch : pitch;
                int s_iy = imgH - 1 - srcY;
                unsigned char* srcPixel = srcData + (INT64)s_iy * srcPitch + srcX * bytesPerPixel;

                const int effB = srcPixel[0];
                const int effG = srcPixel[1];
                const int effR = srcPixel[2];
                const int effA = (bytesPerPixel == 4) ? srcPixel[3] : 255;

                RGBA16color pixel = { char_to_int[effB], char_to_int[effG], char_to_int[effR], char_to_int[effA] };
                if (brushBright!=0)
                   pixel.brightness<true>(brushBright, 1, 0, fiBright, 0.0, brushLUTs);

                if (brushContra!=0)
                   pixel.contrast<true>(brushContra, linearGamma, factorContrast, 0, fiContra, brushLUTs);

                if (brushHue!=0)
                   pixel.hueRotate(brushHue);

                if (brushSat!=0)
                   pixel.saturation(brushSat, 1, linearGamma, saturateFactor);

                srcB = int_to_char[pixel.b];
                srcG = int_to_char[pixel.g];
                srcR = int_to_char[pixel.r];
                srcA = int_to_char[pixel.a];
            } else if (brushType==4)
            {
                // Eraser brush
                if (bytesPerPixel==3)
                {
                    // Restore mode: restore color and alpha from cloneData
                    srcR = 0;
                    srcG = 0;
                    srcB = 0;
                    srcA = 255;
                } else if (bytesPerPixel==4)
                {
                    if (eraserMode==1)
                       srcA = ropacity;  // Replace/overdraw alpha
                    else
                       srcA = 0;        // Standard erase: reduce alpha
                }
            } else if (brushType==5)
            {
                // Effects brush: Hue, Saturation, Lightness, Gamma, Blur
                int effB = tgtB;
                int effG = tgtG;
                int effR = tgtR;
                int effA = tgtA;

                // 1. Box Blur using OpenCV
                if (hasBlurredRoi)
                {
                    int localX = px - roiStartX;
                    int localY = roiEndY - py;
                    if (localX >= 0 && localX < blurredRoi.cols && localY >= 0 && localY < blurredRoi.rows)
                    {
                        if (blurIsWeighted)
                        {
                            // colour = blur(c*a) / blur(a); with nothing visible around, the pixel keeps its own colour
                            const float* blurredPixel = blurredRoi.ptr<float>(localY, localX);
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
                            const unsigned char* blurredPixel = blurredRoi.ptr<unsigned char>(localY, localX);
                            effB = blurredPixel[0];
                            effG = blurredPixel[1];
                            effR = blurredPixel[2];
                            if (bytesPerPixel == 4)
                               effA = blurredPixel[3];
                        }
                    }
                }

                // 2. Lightness, Gamma/Contrast, Hue, Saturation adjustments using RGBA16color
                RGBA16color pixel = { char_to_int[effB], char_to_int[effG], char_to_int[effR], char_to_int[effA] };
                if (brushBright!=0)
                   pixel.brightness<true>(brushBright, 1, 0, fiBright, 0.0, brushLUTs);

                if (brushContra!=0)
                   pixel.contrast<true>(brushContra, linearGamma, factorContrast, 0, fiContra, brushLUTs);

                if (brushHue!=0)
                   pixel.hueRotate(brushHue);

                if (brushSat!=0)
                   pixel.saturation(brushSat, 1, linearGamma, saturateFactor);

                srcB = int_to_char[pixel.b];
                srcG = int_to_char[pixel.g];
                srcR = int_to_char[pixel.r];
                srcA = int_to_char[pixel.a];
            } else if (brushType==6)
            {
                // Smudge brush: grab pixels from previous offset position with bilinear interpolation
                double srcXf = clamp((double)px - cloneOffsetX, 0.0, (double)(imgW - 1));
                double srcYf = clamp((double)py - cloneOffsetY, 0.0, (double)(imgH - 1));

                int x1 = (int)floor(srcXf);
                int y1 = (int)floor(srcYf);
                int x2 = clamp(x1 + 1, 0, imgW - 1);
                int y2 = clamp(y1 + 1, 0, imgH - 1);

                double fx = srcXf - floor(srcXf);
                double fy = srcYf - floor(srcYf);

                double w11 = (1.0 - fx) * (1.0 - fy);
                double w21 = fx * (1.0 - fy);
                double w12 = (1.0 - fx) * fy;
                double w22 = fx * fy;

                unsigned char *p11, *p21, *p12, *p22;
                if (!localClone.empty())
                {
                    int lx1 = clamp(x1 - cloneStartX, 0, cloneW - 1);
                    int ly1 = clamp(y1 - cloneStartY, 0, cloneH - 1);
                    int lx2 = clamp(x2 - cloneStartX, 0, cloneW - 1);
                    int ly2 = clamp(y2 - cloneStartY, 0, cloneH - 1);

                    p11 = localClone.data() + (INT64)ly1 * localPitch + lx1 * bytesPerPixel;
                    p21 = localClone.data() + (INT64)ly1 * localPitch + lx2 * bytesPerPixel;
                    p12 = localClone.data() + (INT64)ly2 * localPitch + lx1 * bytesPerPixel;
                    p22 = localClone.data() + (INT64)ly2 * localPitch + lx2 * bytesPerPixel;
                } else
                {
                    unsigned char* srcData = cloneData ? cloneData : imgData;
                    int srcPitch = cloneData ? clonePitch : pitch;

                    int s_iy1 = imgH - 1 - y1;
                    int s_iy2 = imgH - 1 - y2;

                    p11 = srcData + (INT64)s_iy1 * srcPitch + x1 * bytesPerPixel;
                    p21 = srcData + (INT64)s_iy1 * srcPitch + x2 * bytesPerPixel;
                    p12 = srcData + (INT64)s_iy2 * srcPitch + x1 * bytesPerPixel;
                    p22 = srcData + (INT64)s_iy2 * srcPitch + x2 * bytesPerPixel;
                }

                brushBilinearSample(p11, p21, p12, p22, w11, w21, w12, w22, bytesPerPixel, srcB, srcG, srcR, srcA);
            } else if (brushType==7 || brushType==8)
            {
                // Pinch / Bulge brush: scale coordinate mapping with bilinear interpolation
                double srcXf = clamp(tkX + src_dx, 0.0, (double)(imgW - 1));
                double srcYf = clamp(tkY + src_dy, 0.0, (double)(imgH - 1));

                int x1 = (int)floor(srcXf);
                int y1 = (int)floor(srcYf);
                int x2 = clamp(x1 + 1, 0, imgW - 1);
                int y2 = clamp(y1 + 1, 0, imgH - 1);

                double fx = srcXf - floor(srcXf);
                double fy = srcYf - floor(srcYf);

                double w11 = (1.0 - fx) * (1.0 - fy);
                double w21 = fx * (1.0 - fy);
                double w12 = (1.0 - fx) * fy;
                double w22 = fx * fy;

                unsigned char *p11, *p21, *p12, *p22;
                if (!localClone.empty())
                {
                    int lx1 = clamp(x1 - cloneStartX, 0, cloneW - 1);
                    int ly1 = clamp(y1 - cloneStartY, 0, cloneH - 1);
                    int lx2 = clamp(x2 - cloneStartX, 0, cloneW - 1);
                    int ly2 = clamp(y2 - cloneStartY, 0, cloneH - 1);

                    p11 = localClone.data() + (INT64)ly1 * localPitch + lx1 * bytesPerPixel;
                    p21 = localClone.data() + (INT64)ly1 * localPitch + lx2 * bytesPerPixel;
                    p12 = localClone.data() + (INT64)ly2 * localPitch + lx1 * bytesPerPixel;
                    p22 = localClone.data() + (INT64)ly2 * localPitch + lx2 * bytesPerPixel;
                } else
                {
                    unsigned char* srcData = cloneData ? cloneData : imgData;
                    int srcPitch = cloneData ? clonePitch : pitch;

                    int s_iy1 = imgH - 1 - y1;
                    int s_iy2 = imgH - 1 - y2;

                    p11 = srcData + (INT64)s_iy1 * srcPitch + x1 * bytesPerPixel;
                    p21 = srcData + (INT64)s_iy1 * srcPitch + x2 * bytesPerPixel;
                    p12 = srcData + (INT64)s_iy2 * srcPitch + x1 * bytesPerPixel;
                    p22 = srcData + (INT64)s_iy2 * srcPitch + x2 * bytesPerPixel;
                }

                brushBilinearSample(p11, p21, p12, p22, w11, w21, w12, w22, bytesPerPixel, srcB, srcG, srcR, srcA);
            }

            if (brushType==4 && bytesPerPixel==4)
            {
               outA = weighTwoValues(srcA, tgtA, weight);
            } else if (blendMode==24)
            {
               // the stroke's opacity, capped by the source's alpha, becomes the alpha and the mask the weight [the
               // opacity argument is subtractive]; a product would compound where a brush samples its own output
               RGBAColor Orgb = { srcB, srcG, srcR, (bytesPerPixel==4) ? min(srcA, opacity) : 255 };
               RGBAColor Brgb = { tgtB, tgtG, tgtR, tgtA };
               RGBAColor replaced = CalculateNewBlendModes(Orgb, Brgb, 24, 0, linearGamma, 0, imgBpp, 255 - mask_val);
               outR = replaced.r;
               outG = replaced.g;
               outB = replaced.b;
               outA = replaced.a;
            } else
            {
               outA = (srcA * weightInt + 127) / 255;
               RGBAColor Orgb = { srcB, srcG, srcR, outA };
               RGBAColor Brgb = { tgtB, tgtG, tgtR, tgtA };
               RGBAColor blended = CalculateNewBlendModes(Orgb, Brgb, blendMode, flipLayers, linearGamma, eraserMode, imgBpp, 0);
               outR = blended.r;
               outG = blended.g;
               outB = blended.b;
               outA = blended.a;
            }

            // Write back to imgData
            targetPixel[0] = clamp(outB, 0, 255);
            targetPixel[1] = clamp(outG, 0, 255);
            targetPixel[2] = clamp(outR, 0, 255);
            if (bytesPerPixel==4)
               targetPixel[3] = clamp(outA, 0, 255);
        }
    }
    return 1;
}

#endif // QPV_PAINT_BRUSH_H
