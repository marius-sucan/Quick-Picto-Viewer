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

DLL_API int DLL_CALLCONV openCVresizeBlendEachChannel(unsigned char *imageData, int w, int h, int bpp, int Stride, int posX, int posY, int newWidth, int newHeight, float alpha) {
    float opacity = clamp(alpha, 0.0f, 1.0f);
    int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
    cv::Mat image(h, w, clr, imageData, Stride);

    // Make sure the ROI starts within the image
    int startX = std::max(0, posX);
    int startY = std::max(0, posY);
    
    // Calculate valid width and height for the ROI
    int validWidth = std::min(newWidth - (startX - posX), image.cols - startX);
    int validHeight = std::min(newHeight - (startY - posY), image.rows - startY);
    if (validWidth <= 0 || validHeight <= 0) {
        QPV_DBG("openCVresizeBitmap: No valid overlap between resized channel and image");
        return 0;
    }

    // Split channels
    std::vector<cv::Mat> channels;
    cv::split(image, channels);
    cv::Rect srcRoi(startX - posX, startY - posY, validWidth, validHeight);
    cv::Rect dstRoi(startX, startY, validWidth, validHeight);

    // Resize each channel
    int maxu = (bpp==32) ? 4 : 3;
    for (int channelIndex = 0; channelIndex < maxu; channelIndex++)
    {
        cv::Mat resizedChannel;
        cv::resize(channels[channelIndex], resizedChannel, cv::Size(newWidth, newHeight));
        cv::Mat blendCanvas = cv::Mat::zeros(channels[channelIndex].size(), channels[channelIndex].type());
        resizedChannel(srcRoi).copyTo(blendCanvas(dstRoi));
        cv::addWeighted(blendCanvas, opacity, channels[channelIndex], 1.0 - opacity, 0, channels[channelIndex]);
    }

    // Merge channels back into the original image
    cv::merge(channels, image);
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
