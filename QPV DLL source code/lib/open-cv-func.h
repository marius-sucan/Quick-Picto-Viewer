DLL_API int DLL_CALLCONV openCVdiffBlendBitmap(unsigned char* bgrImageData, int w, int h, int Stride, int bpp, int offsetX, int offsetY, int preblur, int postblur, int invert, float prebrighten, float precontrast, float postbrighten, float postcontrast) {
// works best with 24 bits images 
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat bitmap(h, w, clr, bgrImageData, Stride);
    if (precontrast!=1 || prebrighten!=0)
       bitmap.convertTo(bitmap, -1, precontrast, prebrighten);

    cv::Mat otherData = bitmap.clone();
    if (preblur % 2 != 1)
       preblur++;
    if (postblur % 2 != 1)
       postblur++;
    if (preblur>0)
       cv::stackBlur(otherData, otherData, cv::Size(preblur, preblur));

    // Define the region of interest (ROI) for shifting; an offset as large as the selection
    // [3 px or less] leaves nothing to shift, and a negative ROI would throw
    const int roiW = bitmap.cols - abs(offsetX);
    const int roiH = bitmap.rows - abs(offsetY);
    if (roiW>0 && roiH>0)
    {
       cv::Rect sourceROI(max(0, offsetX), max(0, offsetY), roiW, roiH);
       cv::Rect destROI(max(0, -offsetX), max(0, -offsetY), roiW, roiH);
       otherData(sourceROI).copyTo(bitmap(destROI));
    }
    cv::subtract(bitmap, otherData, bitmap);
    if (postcontrast!=1 || postbrighten!=0)
       bitmap.convertTo(bitmap, -1, postcontrast, postbrighten);

    #pragma omp parallel for schedule(dynamic) default(none) // num_threads(3)
    for (int y = 0; y < bitmap.rows; y++) {
        // walk the row channel-aware: the Mat is CV_8UC4 for 32-bit images,
        // where at<Vec3b>() would step 3 bytes over 4-byte pixels
        const int nch = bitmap.channels();
        unsigned char* row = bitmap.ptr<unsigned char>(y);
        for (int x = 0; x < bitmap.cols; x++) {
            unsigned char* pixel = row + (INT64)x * nch;
            int gray = clamp( ( pixel[0] + pixel[1] + pixel[2] ) / 3, 0, 255 );
            if (invert==1)
               gray = 255 - gray;
            pixel[0] = gray;
            pixel[1] = gray;
            pixel[2] = gray;
        }
    }

    if (bpp==32)
    {
       bitmap.forEach<cv::Vec4b> ( [&](cv::Vec4b& pixel, const int* position) -> void {
             pixel[3] = 255;
       });
    }

    if (postblur>0)
       cv::stackBlur(bitmap, bitmap, cv::Size(postblur, postblur));

    return 1;
}

DLL_API int DLL_CALLCONV openCVedgeDetection(unsigned char *imageData, int w, int h, int xa, int ya, int ks, int preblur, int postblur, int invert, float prebrighten, float precontrast, float postbrighten, float postcontrast, int modus, int Stride, int bpp) {
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat image(h, w, clr, imageData, Stride);
    QPV_DBG("openCVedgeDetection step 1; modus = " + std::to_string( modus ) + " | xa = " + std::to_string( xa ) + " | ya = " + std::to_string( ya ) + " | ks= " + std::to_string( ks ) );
    QPV_DBG("openCVedgeDetection step 1; prebrighten = " + std::to_string( prebrighten ) + " | precontrast = " + std::to_string( precontrast ) );

    cv::Mat grayImage;
    if (precontrast!=1 || prebrighten!=0)
    {
       image.convertTo(image, -1, precontrast, prebrighten);
       if (bpp==32)
       {
          image.forEach<cv::Vec4b> ( [&](cv::Vec4b& pixel, const int* position) -> void {
                pixel[3] = 255;
          });
       }
    }

    if (preblur % 2 != 1)
       preblur++;
    if (postblur % 2 != 1)
       postblur++;

    cv::cvtColor(image, grayImage, cv::COLOR_BGR2GRAY);
    if (preblur>0)
       cv::stackBlur(grayImage, grayImage, cv::Size(preblur, preblur));

    cv::Mat gradXY, absGradXY, edgeImage;
    cv::Mat gradX, absGradX, gradY, absGradY;
    if (modus<=2)
    {
       if (ks==1)
       {
          if (xa > 2)
             xa = 2;
          if (ya > 2)
             ya = 2;
       } else if (ks>2)
       {
          if (xa >= ks)
             xa = ks - 1;
          if (ya >= ks)
             ya = ks - 1;
       }

       // fnOutputDebug("openCVedgeDetection step Sobel | xa = " + std::to_string( xa ) + " | ya = " + std::to_string( ya ) + " | ks= " + std::to_string( ks ) );
       // optimal values xa=1, ya=0, xb=0, yb=1, ks=3
       if (xa==0 && ya==0)
       {
          edgeImage = cv::Mat::zeros(grayImage.size(), CV_8UC1); // Creates a black image
       } else if (modus==2 && xa>0 && ya>0)
       {
          cv::Sobel(grayImage, gradX, CV_16S, xa, 0, ks);
          cv::Sobel(grayImage, gradY, CV_16S, 0, ya, ks);
          cv::convertScaleAbs(gradX, absGradX);
          cv::convertScaleAbs(gradY, absGradY);
          cv::addWeighted(absGradX, 0.5, absGradY, 0.5, 0, edgeImage);
       } else
       {
          cv::Sobel(grayImage, gradXY, CV_16S, xa, ya, ks);
          cv::convertScaleAbs(gradXY, edgeImage);
       }
    } else if (modus==3)
    {
       if (xa==1 && ya==1)
       {
          cv::Sobel(grayImage, gradX, CV_16S, 1, 0, cv::FILTER_SCHARR);
          cv::Sobel(grayImage, gradY, CV_16S, 0, 1, cv::FILTER_SCHARR);
          cv::convertScaleAbs(gradX, absGradX);
          cv::convertScaleAbs(gradY, absGradY);
          cv::addWeighted(absGradX, 0.5, absGradY, 0.5, 0, edgeImage);
       } else if (xa==1 && ya==0 || xa==0 && ya==1)
       {
          cv::Sobel(grayImage, gradXY, CV_16S, xa, ya, cv::FILTER_SCHARR);
          cv::convertScaleAbs(gradXY, edgeImage);
       } else 
       {
          edgeImage = cv::Mat::zeros(grayImage.size(), CV_8UC1); // Creates a black image
       }
    } else if (modus==4)
    {
       if (ks % 2 != 1)
          ks++;
       if (ks>7)
          ks = 7;
       cv::Canny(grayImage, edgeImage, xa, ya, ks);
    }

    if (postblur>0)
       cv::stackBlur(edgeImage, edgeImage, cv::Size(postblur, postblur));
    if (invert==1)
       edgeImage = 255 - edgeImage;

    if (postcontrast!=1 || postbrighten!=0)
       edgeImage.convertTo(edgeImage, -1, postcontrast, postbrighten);

    // Convert edge image to RGB
    clr = (bpp==32) ? cv::COLOR_GRAY2BGRA : cv::COLOR_GRAY2BGR;
    cv::cvtColor(edgeImage, image, clr);
    QPV_DBG("openCVedgeDetection() done");
    return 1;
}

DLL_API int DLL_CALLCONV openCVblurFilters(unsigned char *imageData, int w, int h, int intensityX, int intensityY, int modus, int circle, int Stride, int bpp) {
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat image(h, w, clr, imageData, Stride);
    bool equal = (intensityX == intensityY) ? 1 : 0;
    if (intensityX % 2 != 1)
       intensityX++;
    if (intensityY % 2 != 1)
       intensityY++;
 
    int avg = (intensityX + intensityY)/2;
    if (avg % 2 != 1)
       avg++;
 
    if (equal==1)
       intensityX = intensityY = min(intensityX, intensityY);

    QPV_DBG("openCVblurFilters step 1; modus = " + std::to_string( modus ) + " | inX = " + std::to_string( intensityX ) + " | inY = " + std::to_string( intensityY )  + " | w = " + std::to_string( w ) + " | h = " + std::to_string( h ) );
    int type = (circle==1) ? cv::MORPH_ELLIPSE : cv::MORPH_RECT;
    // cv::blur(image, image, cv::Size(951, 951));
    if (modus==0) {
       cv::blur(image, image, cv::Size(intensityX, intensityY));
    } else if (modus==1) {
       cv::stackBlur(image, image, cv::Size(intensityX, intensityY));
    } else if (modus==2) {
       cv::GaussianBlur(image, image, cv::Size(intensityX, intensityY), (intensityX + intensityY)/12.0f);
    } else if (modus==3) {
       cv::medianBlur(image, image, avg);
    } else if (modus==4) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::dilate(image, image, shape);
    } else if (modus==5) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::erode(image, image, shape);
    } else if (modus==6) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::morphologyEx(image, image, cv::MORPH_OPEN, shape);
    } else if (modus==7) {
       cv::Mat shape = cv::getStructuringElement(type, cv::Size(intensityX, intensityY));
       cv::morphologyEx(image, image, cv::MORPH_CLOSE, shape);
    }

    QPV_DBG("openCVblurFilters done");
    return 1;
}

DLL_API int DLL_CALLCONV openCVresizeBitmapExtended(unsigned char *imageData, unsigned char *otherData, int w, int h, int Stride, int rx, int ry, int rw, int rh, int nw, int nh, int mStride, int bpp, int interpolation) {
  int clr;
  if (bpp==24)
     clr = CV_8UC3;
  else if (bpp==32)
     clr = CV_8UC4;
  else if (bpp==48)
     clr = CV_16UC3;
  else if (bpp==64)
     clr = CV_16UC4;
  else if (bpp==96)
     clr = CV_32FC3;
  else if (bpp==128)
     clr = CV_32FC4;
  else return 0;

  cv::Mat image(h, w, clr, imageData, Stride);
  cv::Mat other(nh, nw, clr, otherData, mStride);

  cv::Rect subRect(rx, ry, rw, rh);
  subRect.x = min( max(0, subRect.x), w - 1);
  subRect.y = min( max(0, subRect.y), h - 1);
  subRect.width = min(subRect.width, image.cols - subRect.x);
  subRect.height = min(subRect.height, image.rows - subRect.y);
  cv::Mat cropped = image(subRect);

  try
  {
      cv::resize(cropped, other, cv::Size(nw, nh), 0, 0, interpolation);
  } catch (const cv::Exception &e)
  {
      QPV_DBG("OpenCV: error attempting to resize bitmap in openCVresizeBitmapExtended: " + std::to_string(w) + " x " + std::to_string(h) + " to " + std::to_string(rw) + " x " + std::to_string(rh));
      QPV_DBG( e.what() );
      return 0;
  }
  return 1;
}

// 1 when a pixel of these 32-bit rows is not fully opaque
static int gdipRowsNotOpaque(const unsigned char *data, INT64 stride, int w, int h) {
    int found = 0;
    #pragma omp parallel for reduction(|:found)
    for (int y = 0; y < h; y++)
    {
        const unsigned char *row = data + (INT64)y * stride;
        __m128i acc = _mm_set1_epi32(-1);
        int x = 0;
        for ( ; x + 4 <= w; x += 4)
            acc = _mm_and_si128(acc, _mm_loadu_si128((const __m128i*)(row + (INT64)x * 4)));

        // bits 3, 7, 11 and 15: the alpha bytes of the four pixels
        int opaque = ((_mm_movemask_epi8(_mm_cmpeq_epi8(acc, _mm_set1_epi32(-1))) & 0x8888)==0x8888) ? 1 : 0;
        for ( ; x < w; x++)
        {
            if (row[(INT64)x * 4 + 3]!=255)
               opaque = 0;
        }

        if (opaque==0)
           found |= 1;
    }
    return found;
}

// straight BGRA rows into premultiplied ones, rounded to nearest; dst may be src
static void gdipPremultiplyRows(const unsigned char *src, INT64 srcStride, unsigned char *dst, INT64 dstStride, int w, int h) {
    #pragma omp parallel for schedule(static)
    for (int y = 0; y < h; y++)
    {
        const unsigned char *s = src + (INT64)y * srcStride;
        unsigned char *d = dst + (INT64)y * dstStride;
        for (int x = 0; x < w; x++, s += 4, d += 4)
        {
            const unsigned int a = s[3];
            if (a==255)
            {
               d[0] = s[0];
               d[1] = s[1];
               d[2] = s[2];
               d[3] = 255;
            } else if (a==0)
            {
               d[0] = d[1] = d[2] = d[3] = 0;
            } else
            {
               d[0] = (unsigned char)((s[0] * a + 127u) / 255u);
               d[1] = (unsigned char)((s[1] * a + 127u) / 255u);
               d[2] = (unsigned char)((s[2] * a + 127u) / 255u);
               d[3] = (unsigned char)a;
            }
        }
    }
}

static void gdipOpaqueRows(unsigned char *data, INT64 stride, int w, int h) {
    #pragma omp parallel for schedule(static)
    for (int y = 0; y < h; y++)
    {
        unsigned char *row = data + (INT64)y * stride;
        for (int x = 0; x < w; x++)
            row[(INT64)x * 4 + 3] = 255;
    }
}

// no channel above its alpha, as a premultiplied pixel requires
static void gdipClampToAlpha(unsigned char *data, INT64 stride, int w, int h) {
    #pragma omp parallel for schedule(static)
    for (int y = 0; y < h; y++)
    {
        unsigned char *px = data + (INT64)y * stride;
        for (int x = 0; x < w; x++, px += 4)
        {
            const unsigned char a = px[3];
            if (px[0]>a)
               px[0] = a;
            if (px[1]>a)
               px[1] = a;
            if (px[2]>a)
               px[2] = a;
        }
    }
}

// The pixels of cur resized into dst [32-bit, premultiplied]. alphaKind: 0 = cur has no alpha,
// 1 = straight alpha, 2 = premultiplied; bottomUp=1: its rows are stored last to first.
static void gdipResizeToPremultiplied(cv::Mat cur, cv::Mat &dst, int interpolation, int alphaKind, int bottomUp) {
    const int nw = dst.cols, nh = dst.rows;
    int straightAlpha = (alphaKind==1) ? 1 : 0;
    if (straightAlpha==1 && gdipRowsNotOpaque(cur.data, (INT64)cur.step, cur.cols, cur.rows)==0)
       alphaKind = straightAlpha = 0;

    // exact halvings ahead of an area reduction: the x2 case is by far the fastest one cv::resize() has;
    // an odd last column or row of the image is left out, which is under one pixel of the result
    while (interpolation==cv::INTER_AREA && cur.cols>=nw*2 && cur.rows>=nh*2)
    {
        const int hw = cur.cols/2, hh = cur.rows/2;
        const int firstRow = (bottomUp==1) ? cur.rows - hh*2 : 0;
        cv::Mat half(hh, hw, cur.type());
        if (straightAlpha==1)
        {
           // premultiplied band by band: the only full-size copy is the halved one
           const int bandRows = 128;
           cv::Mat band(bandRows, hw*2, cur.type());
           for (int y = 0; y < hh*2; y += bandRows)
           {
               const int rows = min(bandRows, hh*2 - y);
               gdipPremultiplyRows(cur.data + (INT64)(firstRow + y) * (INT64)cur.step, (INT64)cur.step, band.data, (INT64)band.step, hw*2, rows);
               cv::Mat bandPart = band(cv::Rect(0, 0, hw*2, rows));
               cv::Mat halfPart = half(cv::Rect(0, y/2, hw, rows/2));
               cv::resize(bandPart, halfPart, halfPart.size(), 0, 0, cv::INTER_AREA);
           }
           straightAlpha = 0;
        } else
        {
           cv::Mat evenPart = cur(cv::Rect(0, firstRow, hw*2, hh*2));
           cv::resize(evenPart, half, half.size(), 0, 0, cv::INTER_AREA);
        }
        cur = half;
    }

    // nearest neighbour and a same-size copy pick whole pixels, which can be premultiplied afterwards;
    // anything that mixes pixels needs them premultiplied beforehand
    const bool picksPixels = (interpolation==cv::INTER_NEAREST || interpolation==cv::INTER_NEAREST_EXACT || (cur.cols==nw && cur.rows==nh));
    if (straightAlpha==1 && !picksPixels)
    {
       cv::Mat premultiplied(cur.rows, cur.cols, cur.type());
       gdipPremultiplyRows(cur.data, (INT64)cur.step, premultiplied.data, (INT64)premultiplied.step, cur.cols, cur.rows);
       cur = premultiplied;
       straightAlpha = 0;
    }

    if (cur.channels()==3)
    {
       cv::Mat rgb(nh, nw, cur.type());
       cv::resize(cur, rgb, rgb.size(), 0, 0, interpolation);
       cv::cvtColor(rgb, dst, cv::COLOR_BGR2BGRA);
    } else
       cv::resize(cur, dst, dst.size(), 0, 0, interpolation);

    if (straightAlpha==1)
       gdipPremultiplyRows(dst.data, (INT64)dst.step, dst.data, (INT64)dst.step, nw, nh);
    else if (alphaKind!=0 && (interpolation==cv::INTER_CUBIC || interpolation==cv::INTER_LANCZOS4))
       gdipClampToAlpha(dst.data, (INT64)dst.step, nw, nh);    // their negative lobes overshoot
}

// The rect [rx, ry, rw, rh] of a GDI+ bitmap resized to nw x nh. The result is a new 32-PARGB bitmap,
// meant to be drawn. The bitmap is locked in its own pixel format: GDI+ converts nothing for 24-RGB,
// 32-RGB, 32-ARGB and 32-PARGB bitmaps. interpolation follows cv::resize(): 0 = nearest neighbour,
// 1 = linear, 2 = cubic, 3 = area, 4 = Lanczos, 5 = linear [bit exact], 6 = nearest neighbour on pixel centres.
DLL_API Gdiplus::GpBitmap* DLL_CALLCONV openCVresizeGdipBitmap(Gdiplus::GpBitmap *pBitmap, int rx, int ry, int rw, int rh, int nw, int nh, int interpolation) {
    if (pBitmap==NULL || nw<1 || nh<1)
       return NULL;

    // a metafile handed to GdipBitmapLockBits() would be read as if it were a bitmap
    Gdiplus::ImageType imgType = Gdiplus::ImageTypeUnknown;
    if (Gdiplus::DllExports::GdipGetImageType(pBitmap, &imgType)!=Gdiplus::Ok || imgType!=Gdiplus::ImageTypeBitmap)
       return NULL;

    UINT imgW = 0, imgH = 0;
    Gdiplus::PixelFormat srcFormat = 0;

    if (Gdiplus::DllExports::GdipGetImageWidth(pBitmap, &imgW)!=Gdiplus::Ok
    ||  Gdiplus::DllExports::GdipGetImageHeight(pBitmap, &imgH)!=Gdiplus::Ok
    ||  Gdiplus::DllExports::GdipGetImagePixelFormat(pBitmap, &srcFormat)!=Gdiplus::Ok
    ||  imgW<1 || imgH<1 || imgW>0x7FFFFFFFu || imgH>0x7FFFFFFFu)
       return NULL;

    rx = max(0, min(rx, (int)imgW - 1));
    ry = max(0, min(ry, (int)imgH - 1));
    if (rw<1 || rw>(int)imgW - rx)
       rw = (int)imgW - rx;
    if (rh<1 || rh>(int)imgH - ry)
       rh = (int)imgH - ry;
    if (interpolation<cv::INTER_NEAREST || interpolation>cv::INTER_NEAREST_EXACT)
       interpolation = cv::INTER_LINEAR;

    Gdiplus::PixelFormat lockFormat = srcFormat;
    if (srcFormat!=PixelFormat24bppRGB && srcFormat!=PixelFormat32bppRGB && srcFormat!=PixelFormat32bppARGB && srcFormat!=PixelFormat32bppPARGB)
    {
       // any other format is converted by GDI+ while locking
       if (srcFormat & PixelFormatPAlpha)
          lockFormat = PixelFormat32bppPARGB;
       else
          lockFormat = (srcFormat & (PixelFormatAlpha | PixelFormatIndexed)) ? PixelFormat32bppARGB : PixelFormat24bppRGB;
    }

    Gdiplus::BitmapData srcData;
    Gdiplus::Rect srcRect(rx, ry, rw, rh);
    if (Gdiplus::DllExports::GdipBitmapLockBits(pBitmap, &srcRect, Gdiplus::ImageLockModeRead, lockFormat, &srcData)!=Gdiplus::Ok)
    {
       QPV_DBG("openCVresizeGdipBitmap: failed to lock the bitmap");
       return NULL;
    }

    Gdiplus::GpBitmap *newBitmap = NULL;
    Gdiplus::BitmapData newData;
    int newLocked = 0, good = 0;
    try
    {
        Gdiplus::Rect newRect(0, 0, nw, nh);
        if (Gdiplus::DllExports::GdipCreateBitmapFromScan0(nw, nh, 0, PixelFormat32bppPARGB, NULL, &newBitmap)==Gdiplus::Ok && newBitmap!=NULL)
           newLocked = (Gdiplus::DllExports::GdipBitmapLockBits(newBitmap, &newRect, Gdiplus::ImageLockModeWrite, PixelFormat32bppPARGB, &newData)==Gdiplus::Ok) ? 1 : 0;

        if (newLocked==1 && newData.Stride>0 && srcData.Stride!=0)
        {
           // a negative stride means bottom-up rows: resized as a flipped image, flipped back at the end
           const bool bottomUp = (srcData.Stride<0);
           const INT64 srcStride = bottomUp ? -(INT64)srcData.Stride : (INT64)srcData.Stride;
           unsigned char *srcBase = (unsigned char*)srcData.Scan0 + (bottomUp ? (INT64)(rh - 1) * srcData.Stride : 0);
           cv::Mat src(rh, rw, (lockFormat==PixelFormat24bppRGB) ? CV_8UC3 : CV_8UC4, srcBase, (size_t)srcStride);
           cv::Mat dst(nh, nw, CV_8UC4, newData.Scan0, (size_t)newData.Stride);
           const int alphaKind = (lockFormat==PixelFormat32bppARGB) ? 1 : (lockFormat==PixelFormat32bppPARGB) ? 2 : 0;
           gdipResizeToPremultiplied(src, dst, interpolation, alphaKind, bottomUp ? 1 : 0);
           if (lockFormat==PixelFormat32bppRGB)
              gdipOpaqueRows(dst.data, (INT64)dst.step, nw, nh);
           if (bottomUp)
              cv::flip(dst, dst, 0);

           // cv::resize() must have written into the GDI+ buffer, not into one of its own
           good = (dst.data==(unsigned char*)newData.Scan0) ? 1 : 0;
        }
    } catch (...)
    {
        good = 0;
    }

    if (newLocked==1)
       Gdiplus::DllExports::GdipBitmapUnlockBits(newBitmap, &newData);
    Gdiplus::DllExports::GdipBitmapUnlockBits(pBitmap, &srcData);
    if (good!=1)
    {
       QPV_DBG("openCVresizeGdipBitmap: failed to resize " + std::to_string(rw) + " x " + std::to_string(rh) + " to " + std::to_string(nw) + " x " + std::to_string(nh));
       if (newBitmap!=NULL)
          Gdiplus::DllExports::GdipDisposeImage(newBitmap);
       newBitmap = NULL;
    }
    return newBitmap;
}

static int coreOpenCVapplyToneMappingAlgos(float* hdrData, int hStride, int width, int height, unsigned char* ldrData, int lStride, int algo, float paramA, float paramB, float paramC, float addExposure, int altModeExposure) {
// the tone-mapping algorithms do not give correct results with 4 channels [RGBA]

    // fnOutputDebug("openCVapplyToneMappingAlgos: hStride=" + std::to_string(hStride));
    cv::Mat hdrImage(height, width, CV_32FC3, hdrData, hStride);
    cv::Mat ldrFinal(height, width, CV_8UC3, ldrData, lStride);
    // fnOutputDebug("openCVapplyToneMappingAlgos: hdrStride=" + std::to_string(hdrImage.step) + " // ldrStride=" + std::to_string(ldrFinal.step));
    cv::Mat ldrImage;
    if (algo==0)
    {
       cv::Ptr<cv::TonemapDrago> Drago = cv::createTonemapDrago(paramA, paramB, paramC);
       Drago->process(hdrImage, ldrImage);
    } else if (algo==1)
    {
       cv::Ptr<cv::TonemapReinhard> reinhard = cv::createTonemapReinhard(paramA, paramB, paramC, 0);
       reinhard->process(hdrImage, ldrImage);
    } else if (algo==2)
    {
       cv::Ptr<cv::Tonemap> tnmp = cv::createTonemap(paramA);
       tnmp->process(hdrImage, ldrImage);
    } else
    {
       cv::Ptr<cv::TonemapMantiuk> mantiuk = cv::createTonemapMantiuk(paramA, paramB, paramC);
       mantiuk->process(hdrImage, ldrImage);
    }

    if (addExposure>0.002)
    {
       float p = (addExposure + 0.33f) * 3.0f;
       if (altModeExposure==1)
          cv::scaleAdd(hdrImage, addExposure, ldrImage, ldrImage);
       else if (p>1.001)
          cv::normalize(ldrImage, ldrImage, 0.0f, p, cv::NORM_MINMAX);
    }

    // fnOutputDebug("openCVapplyToneMappingAlgos: addExposure=" + std::to_string(addExposure));
    ldrImage = ldrImage * 255.0f;
    ldrImage.convertTo(ldrFinal, CV_8UC3);
    cv::cvtColor(ldrFinal, ldrFinal, cv::COLOR_RGB2BGR);
    return 1;
}

// nothing may be thrown out of an exported function, and the thumbnail pool calls this one directly:
// Drago asserts on an all-black image, and any of the algorithms can run out of memory
DLL_API int DLL_CALLCONV openCVapplyToneMappingAlgos(float* hdrData, int hStride, int width, int height, unsigned char* ldrData, int lStride, int algo, float paramA, float paramB, float paramC, float addExposure, int altModeExposure) {
    try
    {
        return coreOpenCVapplyToneMappingAlgos(hdrData, hStride, width, height, ldrData, lStride, algo, paramA, paramB, paramC, addExposure, altModeExposure);
    } catch (...)
    {
        return 0;
    }
}
