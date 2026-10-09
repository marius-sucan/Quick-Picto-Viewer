// wic-loader.h
//
// Images through WIC: the pixel and container format tables, colour management, the SEH
// guards every codec call goes through, the preloaded-image exports and LoadWICimage().
//
// #included by qpv-main.cpp ahead of the PDF and SVG readers, thumbs-pool.h and
// dupes-pixels.h, which use SafeRelease(), the guards and adaptImageGivenSize(); it uses
// WideCharToString(), fnOutputDebug() and m_pIWICFactory from qpv-main.cpp.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_WIC_LOADER_H
#define QPV_WIC_LOADER_H

#include <array>
#include <chrono>
#include <map>
#include <new>
#include <string>
#include <thread>

IWICBitmapDecoder      *pWICclassDecoder;
IWICBitmapFrameDecode  *pWICclassFrameDecoded;
// IWICFormatConverter *pWICclassConverter;

struct GUIDComparer {
    bool operator()(const GUID& left, const GUID& right) const {
        return memcmp(&left, &right, sizeof(GUID)) < 0;
    }
};

template <typename T> inline void SafeRelease(T *&p, std::string infos, int d) {
    if (p!=NULL) {
        int x = p->Release();
        if (d==1 && x==1)
           x = p->Release();

        // fnOutputDebug(std::to_string((uintptr_t)p) + " oldSafeRelease: " + std::to_string(x) + " | " + infos);
        // std::this_thread::sleep_for(std::chrono::milliseconds(50));
        if (d!=2)
           p = NULL;
    }
}

INT indexedWICpixelFormats(const WICPixelFormatGUID oPixFmt) {
     static const std::map<GUID, INT, GUIDComparer> formatMap = {
         {GUID_WICPixelFormatDontCare, 1},
         {GUID_WICPixelFormat1bppIndexed, 2},
         {GUID_WICPixelFormat2bppIndexed, 3},
         {GUID_WICPixelFormat4bppIndexed, 4},
         {GUID_WICPixelFormat8bppIndexed, 5},
         {GUID_WICPixelFormatBlackWhite, 6},
         {GUID_WICPixelFormat2bppGray, 7},
         {GUID_WICPixelFormat4bppGray, 8},
         {GUID_WICPixelFormat8bppGray, 9},
         {GUID_WICPixelFormat8bppAlpha, 10},
         {GUID_WICPixelFormat16bppBGR555, 11},
         {GUID_WICPixelFormat16bppBGR565, 12},
         {GUID_WICPixelFormat16bppBGRA5551, 13},
         {GUID_WICPixelFormat16bppGray, 14},
         {GUID_WICPixelFormat24bppBGR, 15},
         {GUID_WICPixelFormat24bppRGB, 16},
         {GUID_WICPixelFormat32bppBGR, 17},
         {GUID_WICPixelFormat32bppBGRA, 18},
         {GUID_WICPixelFormat32bppPBGRA, 19},
         {GUID_WICPixelFormat32bppGrayFloat, 20},
         {GUID_WICPixelFormat32bppRGB, 21},
         {GUID_WICPixelFormat32bppRGBA, 22},
         {GUID_WICPixelFormat32bppPRGBA, 23},
         {GUID_WICPixelFormat48bppRGB, 24},
         {GUID_WICPixelFormat48bppBGR, 25},
         {GUID_WICPixelFormat64bppRGB, 26},
         {GUID_WICPixelFormat64bppRGBA, 27},
         {GUID_WICPixelFormat64bppBGRA, 28},
         {GUID_WICPixelFormat64bppPRGBA, 29},
         {GUID_WICPixelFormat64bppPBGRA, 30},
         {GUID_WICPixelFormat16bppGrayFixedPoint, 31},
         {GUID_WICPixelFormat32bppBGR101010, 32},
         {GUID_WICPixelFormat48bppRGBFixedPoint, 33},
         {GUID_WICPixelFormat48bppBGRFixedPoint, 34},
         {GUID_WICPixelFormat96bppRGBFixedPoint, 35},
         {GUID_WICPixelFormat96bppRGBFloat, 36},
         {GUID_WICPixelFormat128bppRGBAFloat, 37},
         {GUID_WICPixelFormat128bppPRGBAFloat, 38},
         {GUID_WICPixelFormat128bppRGBFloat, 39},
         {GUID_WICPixelFormat32bppCMYK, 40},
         {GUID_WICPixelFormat64bppRGBAFixedPoint, 41},
         {GUID_WICPixelFormat64bppBGRAFixedPoint, 42},
         {GUID_WICPixelFormat64bppRGBFixedPoint, 43},
         {GUID_WICPixelFormat128bppRGBAFixedPoint, 44},
         {GUID_WICPixelFormat128bppRGBFixedPoint, 45},
         {GUID_WICPixelFormat64bppRGBAHalf, 46},
         {GUID_WICPixelFormat64bppPRGBAHalf, 47},
         {GUID_WICPixelFormat64bppRGBHalf, 48},
         {GUID_WICPixelFormat48bppRGBHalf, 49},
         {GUID_WICPixelFormat32bppRGBE, 50},
         {GUID_WICPixelFormat16bppGrayHalf, 51},
         {GUID_WICPixelFormat32bppGrayFixedPoint, 52},
         {GUID_WICPixelFormat32bppRGBA1010102, 53},
         {GUID_WICPixelFormat32bppRGBA1010102XR, 54},
         {GUID_WICPixelFormat32bppR10G10B10A2, 55},
         {GUID_WICPixelFormat32bppR10G10B10A2HDR10, 56},
         {GUID_WICPixelFormat64bppCMYK, 57},
         {GUID_WICPixelFormat24bpp3Channels, 58},
         {GUID_WICPixelFormat32bpp4Channels, 59},
         {GUID_WICPixelFormat40bpp5Channels, 60},
         {GUID_WICPixelFormat48bpp6Channels, 61},
         {GUID_WICPixelFormat56bpp7Channels, 62},
         {GUID_WICPixelFormat64bpp8Channels, 63},
         {GUID_WICPixelFormat48bpp3Channels, 64},
         {GUID_WICPixelFormat64bpp4Channels, 65},
         {GUID_WICPixelFormat80bpp5Channels, 66},
         {GUID_WICPixelFormat96bpp6Channels, 67},
         {GUID_WICPixelFormat112bpp7Channels, 68},
         {GUID_WICPixelFormat128bpp8Channels, 69},
         {GUID_WICPixelFormat40bppCMYKAlpha, 70},
         {GUID_WICPixelFormat80bppCMYKAlpha, 71},
         {GUID_WICPixelFormat32bpp3ChannelsAlpha, 72},
         {GUID_WICPixelFormat40bpp4ChannelsAlpha, 73},
         {GUID_WICPixelFormat48bpp5ChannelsAlpha, 74},
         {GUID_WICPixelFormat56bpp6ChannelsAlpha, 75},
         {GUID_WICPixelFormat64bpp7ChannelsAlpha, 76},
         {GUID_WICPixelFormat72bpp8ChannelsAlpha, 77},
         {GUID_WICPixelFormat64bpp3ChannelsAlpha, 78},
         {GUID_WICPixelFormat80bpp4ChannelsAlpha, 79},
         {GUID_WICPixelFormat96bpp5ChannelsAlpha, 80},
         {GUID_WICPixelFormat112bpp6ChannelsAlpha, 81},
         {GUID_WICPixelFormat128bpp7ChannelsAlpha, 82},
         {GUID_WICPixelFormat144bpp8ChannelsAlpha, 83},
         {GUID_WICPixelFormat8bppY, 84},
         {GUID_WICPixelFormat8bppCb, 85},
         {GUID_WICPixelFormat8bppCr, 86},
         {GUID_WICPixelFormat16bppCbCr, 87},
         {GUID_WICPixelFormat16bppYQuantizedDctCoefficients, 88},
         {GUID_WICPixelFormat16bppCbQuantizedDctCoefficients, 89},
         {GUID_WICPixelFormat16bppCrQuantizedDctCoefficients, 90}
     };

     auto it = formatMap.find(oPixFmt);
     return (it != formatMap.end()) ? it->second : 0;
}

INT indexedWICcontainerFormats(const GUID containerFmt) {
    static const std::map<GUID, INT, GUIDComparer> formatMap = {
        {GUID_ContainerFormatBmp,  1},
        {GUID_ContainerFormatPng,  2},
        {GUID_ContainerFormatIco,  3},
        {GUID_ContainerFormatJpeg, 4},
        {GUID_ContainerFormatTiff, 5},
        {GUID_ContainerFormatGif,  6},
        {GUID_ContainerFormatWmp,  7},
        {GUID_ContainerFormatDds,  8},
        {GUID_ContainerFormatAdng, 9},
        {GUID_ContainerFormatHeif, 10},
        {GUID_ContainerFormatWebp, 11},
        {GUID_ContainerFormatRaw,  12}
    };

    auto it = formatMap.find(containerFmt);
    return (it != formatMap.end()) ? it->second : 0;
}

auto adaptImageGivenSize(const UINT keepAratio, const UINT ScaleAnySize, const UINT imgW, const UINT imgH, const UINT givenW, const UINT givenH, const float maxMPX = 536.45) {
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
         const double PicRatio = (float)(imgW)/imgH;
         const double givenRatio = (float)(givenW)/givenH;
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

  double mpx = ((UINT64)size[0] * size[1])/1000000.0f;
  // fnOutputDebug(std::to_string(mpx) + "mpx ; adapted: " + std::to_string(size[0]) + " x " + std::to_string(size[1]) );
  float g = 536.4f / mpx;
  if (mpx>maxMPX)
  {
     const float fw = size[0];
     const float fh = size[1];
     g = 1.0f;
     for (int i = 0; i < 987654321; i++)
     {
        g -= 0.0001;
        float npx = ((fw*g) * (fh*g))/1000000.0f;
        if (npx<maxMPX)
           break;
     }
     size[0] = fw*g;
     size[1] = fh*g;
     // fnOutputDebug("booooooooooooooooooooonkerzzzzzzzzzzzzzzz");
  }

  // double npx = (size[0] * size[1])/1000000;
  // fnOutputDebug( std::to_string(g) + "f ; " + std::to_string(npx) + "mpx ; adapted: " + std::to_string(size[0]) + " x " + std::to_string(size[1]) );
  // past an aspect ratio of twice the box the short side rounds to 0, which no caller can allocate or scale to
  if (size[0]<1)
     size[0] = 1;
  if (size[1]<1)
     size[1] = 1;
  return size;
}

DLL_API int DLL_CALLCONV WICtestPreloadedImage(int id) {
  if (pWICclassFrameDecoded!=NULL)
     return 1;
  return 0;
}

static void WICguardedRelease(IUnknown *p);

DLL_API int DLL_CALLCONV WICdestroyPreloadedImage(int id) {
  // a codec has decoded through these, and one that faulted may fault again in Release()
  WICguardedRelease(pWICclassFrameDecoded);
  WICguardedRelease(pWICclassDecoder);
  pWICclassFrameDecoded = NULL;
  pWICclassDecoder = NULL;
  return id;
}

WICBitmapInterpolationMode indexedWICinterpolations(int givenQuality) {
    // i made these up, ignore this rubbish
    WICBitmapInterpolationMode wicScaleQuality;
    if (givenQuality==0)
       wicScaleQuality = WICBitmapInterpolationModeNearestNeighbor;
    else if (givenQuality==1)
       wicScaleQuality = WICBitmapInterpolationModeLinear;
    else if (givenQuality==2)
       wicScaleQuality = WICBitmapInterpolationModeLinear;
    else if (givenQuality==3)
       wicScaleQuality = WICBitmapInterpolationModeCubic;
    else if (givenQuality==5)
       wicScaleQuality = WICBitmapInterpolationModeNearestNeighbor;
    else if (givenQuality==7)
       wicScaleQuality = WICBitmapInterpolationModeHighQualityCubic;
    else
       wicScaleQuality = WICBitmapInterpolationModeFant;
   return wicScaleQuality;
}

int applyColorManagement(IWICBitmapSource* &thisWICbitmap, IWICBitmapFrameDecode* &pFrame, GUID destPixFormat, int useICM) {
      static IWICColorContext    *pSrcColorContext   = NULL;
      static IWICColorContext    *pDestColorContext  = NULL;
      static IWICColorContext    *pCmykColorContext  = NULL;
      static IWICColorTransform  *pColorTransform    = NULL;
      if (useICM==100)
      {
         SafeRelease(pColorTransform, "applyColorManagement: pColorTransform", 0);
         SafeRelease(pSrcColorContext, "applyColorManagement: pSrcColorContext", 0);
         SafeRelease(pCmykColorContext, "applyColorManagement: pCmykColorContext", 0);
         SafeRelease(pDestColorContext, "applyColorManagement: pDestColorContext", 0);
         return 0;
      } 

      if (!thisWICbitmap || !pFrame)
      {
         fnOutputDebug("applyColorManagement: no valid bitmaps given");
         return 0;
      }

      GUID sFmt;
      HRESULT hr = thisWICbitmap->GetPixelFormat(&sFmt);
      if (FAILED(hr))
      {
         fnOutputDebug("applyColorManagement: failed GetPixelFormat on source bitmap");
         return 0;
      }

      int okay = 0; // check if the pixel format is one of the supported formats by CreateColorTransformer
      if (sFmt == GUID_WICPixelFormat8bppGray    || sFmt == GUID_WICPixelFormat16bppGray
       || sFmt == GUID_WICPixelFormat16bppBGR555 || sFmt == GUID_WICPixelFormat16bppBGR565
       || sFmt == GUID_WICPixelFormat24bppBGR    || sFmt == GUID_WICPixelFormat24bppRGB
       || sFmt == GUID_WICPixelFormat32bppBGR    || sFmt == GUID_WICPixelFormat32bppBGRA
       || sFmt == GUID_WICPixelFormat32bppPBGRA  || sFmt == GUID_WICPixelFormat32bppPRGBA
       || sFmt == GUID_WICPixelFormat32bppRGBA   || sFmt == GUID_WICPixelFormat32bppBGR101010
       || sFmt == GUID_WICPixelFormat32bppCMYK   || sFmt == GUID_WICPixelFormat48bppBGR
       || sFmt == GUID_WICPixelFormat64bppBGRA   || sFmt == GUID_WICPixelFormat64bppPBGRA
       || sFmt == GUID_WICPixelFormat64bppPRGBA  || sFmt == GUID_WICPixelFormat64bppRGBA)
         okay = 1;

      UINT colorContextCount = 0;
      int isCMYKimg = 0;
      if (sFmt == GUID_WICPixelFormat32bppCMYK || sFmt == GUID_WICPixelFormat64bppCMYK || sFmt == GUID_WICPixelFormat40bppCMYKAlpha || sFmt == GUID_WICPixelFormat80bppCMYKAlpha)
         isCMYKimg = 1;

      UINT fmt = indexedWICpixelFormats(sFmt);
      // fnOutputDebug("isCMYKimg == " + std::to_string(isCMYKimg) + " // fmt=" + std::to_string(fmt));
      // fnOutputDebug("icm mode, here we goooo , or not...");
      if (useICM==1 && okay==1)
      {
         okay = 0;
         // get icc color profile embedded in the image 
         // fnOutputDebug("icm mode, GetColorContexts");
         hr = m_pIWICFactory->CreateColorContext(&pSrcColorContext);
         if (SUCCEEDED(hr))
            hr = pFrame->GetColorContexts(1, &pSrcColorContext, &colorContextCount);
         else
            fnOutputDebug("failed CreateColorContext"); 

         if (!(SUCCEEDED(hr)))
            fnOutputDebug("failed GetColorContexts: " + std::to_string(colorContextCount));

         if (FAILED(hr) || colorContextCount==0)
         {
             // without a profile an RGB image is sRGB already; only CMYK is given one, and only
             // when CreateColorContext() produced the context to give it in
             fnOutputDebug("fallback icc profile");
             if (isCMYKimg==1 && pSrcColorContext!=NULL) {
                 isCMYKimg = 2;
                 hr = pSrcColorContext->InitializeFromExifColorSpace(5); // Default CMYK
             } else {
                 hr = E_FAIL;
             }
             colorContextCount = (SUCCEEDED(hr)) ? 1 : 0;
         }
      } else okay = 0;

      if (useICM==1 && SUCCEEDED(hr) && colorContextCount>0)
      {
         // fnOutputDebug("icm mode, yay! contexts=" + std::to_string(colorContextCount));
         if (isCMYKimg==1)
         {
            // fnOutputDebug("CMYK color profile backup");
            hr = m_pIWICFactory->CreateColorContext(&pCmykColorContext);
            if (SUCCEEDED(hr))
            {
                hr = pCmykColorContext->InitializeFromExifColorSpace(5); // Standard CMYK
                if (SUCCEEDED(hr))
                   fnOutputDebug("yay cmyk color context backup");
            }
         }

         hr = m_pIWICFactory->CreateColorContext(&pDestColorContext);
         if (SUCCEEDED(hr))
            hr = pDestColorContext->InitializeFromExifColorSpace(1); // sRGB

         if (SUCCEEDED(hr))
         {
            // fnOutputDebug("icm mode, destination CLR context, yay");
            hr = m_pIWICFactory->CreateColorTransformer(&pColorTransform);
            if (SUCCEEDED(hr))
            {
               // fnOutputDebug("icm mode, clr transform, yay");
               hr = pColorTransform->Initialize(thisWICbitmap, pSrcColorContext, pDestColorContext, destPixFormat);
               if (FAILED(hr) && isCMYKimg==1 && pCmykColorContext!=NULL)
               {
                  hr = pColorTransform->Initialize(thisWICbitmap, pCmykColorContext, pDestColorContext, destPixFormat);
                  fnOutputDebug("icm mode, clr transform, trying again");
               }

               if (SUCCEEDED(hr))
               {
                  SafeRelease(thisWICbitmap, "applyColorManagement: pFinalBitmapSource / thisWICbitmap", 0);
                  hr = pColorTransform->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&thisWICbitmap));
                  okay = (SUCCEEDED(hr)) ? 1 : 0;
                  if (okay==0)
                     fnOutputDebug("applyColorManagement: pColorTransform > QueryInterface failed");
               } else 
               {
                  char errorMsg[256];
                  sprintf_s(errorMsg, "applyColorManagement: pColorTransform Initialize failed: 0x%08X\n", hr);
                  fnOutputDebug(errorMsg);
               }
            } else fnOutputDebug("applyColorManagement: failed CreateColorTransformer");
         } else fnOutputDebug("applyColorManagement: failed CreateColorContext.Init destination");
      }

      return okay;
}

// ---------------------------------------------------------------------------------------
// Guarded WIC decoding
//
// A malformed, truncated or hostile image file does not always come back as a failure
// HRESULT. WIC codecs - above all the third party ones users install for RAW, HEIF or
// JPEG-XL - do walk off their own buffers and raise an access violation instead; and
// because CreateDecoderFromFilename() reads the file through a memory mapping, a file on
// a network share or on a card that is pulled mid-read raises EXCEPTION_IN_PAGE_ERROR.
// Neither of those is a C++ exception, so no catch() handler in this file can ever see
// them under the synchronous exception model this project builds with - only __except().
//
// The helpers below exist because MSVC refuses __try inside any function that holds an
// object needing unwinding (C2712), which every function here does the moment it builds
// an std::string for fnOutputDebug(). They therefore keep to plain data and raw COM
// pointers, and they never read a local variable inside the __except block: a local
// modified inside a __try is not reliable in the handler.
//
// Every call that hands control to a codec goes through one of these: opening the file,
// reading the frame header, initializing a scaler or a converter (a codec may do a scaled
// decode of its own through IWICBitmapSourceTransform), reading the embedded colour
// profile, and above all CopyPixels(), which is where the pixels are actually decoded and
// therefore where a corrupt file is most likely to take the process down.
//
// This is damage control, not a guarantee. A codec that corrupts the heap before it
// faults, or that faults on a thread of its own, is still fatal.
// ---------------------------------------------------------------------------------------

static int WICcodecCrashFilter(DWORD code) {
    switch (code)
    {
       case EXCEPTION_ACCESS_VIOLATION:
       case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
       case EXCEPTION_DATATYPE_MISALIGNMENT:
       case EXCEPTION_ILLEGAL_INSTRUCTION:
       case EXCEPTION_IN_PAGE_ERROR:
       case EXCEPTION_INT_DIVIDE_BY_ZERO:
       case EXCEPTION_INT_OVERFLOW:
       case EXCEPTION_PRIV_INSTRUCTION:
            return EXCEPTION_EXECUTE_HANDLER;
    }

    // everything else keeps unwinding: a stack overflow leaves no guard page to recover
    // into, and C++ exceptions (0xE06D7363) must still reach their own handlers
    return EXCEPTION_CONTINUE_SEARCH;
}

static void WICguardedRelease(IUnknown *p) {
    if (p==NULL)
       return;

    __try
    {
        p->Release();
    } __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        // a codec that faulted once can fault again on the way out; the object is then
        // abandoned - a few leaked bytes beat taking the whole viewer down
    }
}

// SafeRelease() for anything a codec has touched: same job, but it survives a faulting
// Release(). Worth using on every WIC object once a decode has begun, because the object
// most likely to fault on the way out is the one that just faulted on the way in.
template <typename T> inline void WICsafeRelease(T *&p) {
    if (p!=NULL)
    {
       WICguardedRelease(p);
       p = NULL;
    }
}

// Everything a caller reads out of a frame header, in one plain struct so the guarded
// reader below stays free of anything that would need unwinding. The three got* flags
// mark the fields that are metadata rather than structure: whether a missing one is fatal
// is the caller's policy, not this function's.
struct WICframeFacts {
    UINT   width;
    UINT   height;
    UINT   frames;
    UINT   activeFrame;
    double dpix;
    double dpiy;
    GUID   containerFmt;
    WICPixelFormatGUID pixelFmt;
    int    gotContainerFmt;
    int    gotPixelFmt;
    int    gotResolution;
};

// Opens szFileName, picks a frame and reads its header. The decoder and the frame are
// written straight into the caller's pointers, so the caller can release whatever was
// produced no matter where this failed. sehCode comes back non-zero when the codec
// faulted rather than returned an error.
static HRESULT WICguardedOpenFrame(IWICImagingFactory *fac, const wchar_t *szFileName, int givenFrame,
                                   IWICBitmapDecoder **ppDecoder, IWICBitmapFrameDecode **ppFrame,
                                   WICframeFacts *facts, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *sehCode = 0;
    __try
    {
        hr = fac->CreateDecoderFromFilename(szFileName, NULL, GENERIC_READ, WICDecodeMetadataCacheOnDemand, ppDecoder);
        if (SUCCEEDED(hr) && *ppDecoder==NULL)
           hr = E_POINTER;   // a success code with no object is still nothing to work with

        UINT tFrames = 0;
        if (SUCCEEDED(hr))
           hr = (*ppDecoder)->GetFrameCount(&tFrames);

        if (SUCCEEDED(hr) && tFrames<1)
           hr = E_FAIL;      // a container that declares no frame has nothing to decode

        if (SUCCEEDED(hr))
        {
           UINT useFrame = (givenFrame>0) ? (UINT)givenFrame : 0;
           if (useFrame>=tFrames)
              useFrame = tFrames - 1;

           facts->frames = tFrames;
           facts->activeFrame = useFrame;
           hr = (*ppDecoder)->GetFrame(useFrame, ppFrame);
           if (SUCCEEDED(hr) && *ppFrame==NULL)
              hr = E_POINTER;
        }

        if (SUCCEEDED(hr))
           hr = (*ppFrame)->GetSize(&facts->width, &facts->height);

        // from here on nothing is fatal by itself; the caller decides what it can do
        // without a container format, a pixel format or a resolution
        if (SUCCEEDED(hr))
        {
           if (SUCCEEDED((*ppDecoder)->GetContainerFormat(&facts->containerFmt)))
              facts->gotContainerFmt = 1;

           if (SUCCEEDED((*ppFrame)->GetPixelFormat(&facts->pixelFmt)))
              facts->gotPixelFmt = 1;

           if (SUCCEEDED((*ppFrame)->GetResolution(&facts->dpix, &facts->dpiy)))
              facts->gotResolution = 1;
           else
           {
              facts->dpix = 0;
              facts->dpiy = 0;
           }
        }
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;
    }

    return hr;
}

// bits per pixel and channel count for a pixel format GUID; reads no file data, but it
// still runs inside the codec that registered the format
static HRESULT WICguardedPixelFormatInfo(IWICImagingFactory *fac, const WICPixelFormatGUID *fmt,
                                         UINT *bpp, UINT *channels, DWORD *sehCode) {
    IWICComponentInfo   *pComponentInfo   = NULL;
    IWICPixelFormatInfo *pPixelFormatInfo = NULL;
    HRESULT hr = E_FAIL;
    *bpp = 0;
    *channels = 0;
    *sehCode = 0;
    __try
    {
        hr = fac->CreateComponentInfo(*fmt, &pComponentInfo);
        if (SUCCEEDED(hr) && pComponentInfo!=NULL)
        {
           hr = pComponentInfo->QueryInterface(IID_PPV_ARGS(&pPixelFormatInfo));
           if (SUCCEEDED(hr) && pPixelFormatInfo!=NULL)
           {
              pPixelFormatInfo->GetBitsPerPixel(bpp);
              hr = pPixelFormatInfo->GetChannelCount(channels);
           }
        }
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;   // both component objects are abandoned on purpose
    }

    WICguardedRelease(pPixelFormatInfo);
    WICguardedRelease(pComponentInfo);
    return hr;
}

// 1 when the frame's palette has an entry that is not opaque; a frame without a palette has none
static int WICguardedPaletteHasAlpha(IWICImagingFactory *fac, IWICBitmapFrameDecode *frame, DWORD *sehCode) {
    IWICPalette *pPalette = NULL;
    BOOL hasAlpha = FALSE;
    *sehCode = 0;
    __try
    {
        if (SUCCEEDED(fac->CreatePalette(&pPalette)) && pPalette!=NULL)
        {
           if (FAILED(frame->CopyPalette(pPalette)) || FAILED(pPalette->HasAlpha(&hasAlpha)))
              hasAlpha = FALSE;
        }
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return 0;   // the palette is abandoned on purpose
    }

    WICguardedRelease(pPalette);
    return hasAlpha ? 1 : 0;
}

// size and pixel format of whatever is at the end of a scaler/converter chain; the call
// walks back down that chain into the codec
static HRESULT WICguardedSourceInfo(IWICBitmapSource *src, UINT *width, UINT *height,
                                    WICPixelFormatGUID *fmt, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *width = 0;
    *height = 0;
    *sehCode = 0;
    if (src==NULL)
       return E_POINTER;

    __try
    {
        hr = src->GetSize(width, height);
        if (SUCCEEDED(hr) && fmt!=NULL)
           hr = src->GetPixelFormat(fmt);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;
    }

    return hr;
}

static HRESULT WICguardedScalerInit(IWICBitmapScaler *pScaler, IWICBitmapSource *src, UINT width, UINT height,
                                    WICBitmapInterpolationMode mode, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *sehCode = 0;
    if (pScaler==NULL || src==NULL)
       return E_POINTER;

    __try
    {
        hr = pScaler->Initialize(src, width, height, mode);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;
    }

    return hr;
}

static HRESULT WICguardedConverterInit(IWICFormatConverter *pConverter, IWICBitmapSource *src,
                                       const WICPixelFormatGUID *destFmt, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *sehCode = 0;
    if (pConverter==NULL || src==NULL)
       return E_POINTER;

    __try
    {
        hr = pConverter->Initialize(src, *destFmt, WICBitmapDitherTypeNone, NULL, 0.0f, WICBitmapPaletteTypeCustom);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;
    }

    return hr;
}

// a clipper validates the rectangle against the source, which means asking the codec how
// big the frame really is
static HRESULT WICguardedClipperInit(IWICBitmapClipper *pClipper, IWICBitmapSource *src,
                                     const WICRect *rc, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *sehCode = 0;
    if (pClipper==NULL || src==NULL || rc==NULL)
       return E_POINTER;

    __try
    {
        hr = pClipper->Initialize(src, rc);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;
    }

    return hr;
}

static HRESULT WICguardedCanConvert(IWICFormatConverter *pConverter, const GUID *srcFmt,
                                    const GUID *destFmt, BOOL *possible, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *sehCode = 0;
    *possible = 0;
    if (pConverter==NULL)
       return E_POINTER;

    __try
    {
        hr = pConverter->CanConvert(*srcFmt, *destFmt, possible);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        *possible = 0;
        return E_UNEXPECTED;
    }

    return hr;
}

// the decode itself
static HRESULT WICguardedCopyPixels(IWICBitmapSource *src, const WICRect *rc, UINT cbStride,
                                    UINT cbBufferSize, BYTE *buffer, DWORD *sehCode) {
    HRESULT hr = E_FAIL;
    *sehCode = 0;
    if (src==NULL || buffer==NULL || cbStride<1 || cbBufferSize<1)
       return E_INVALIDARG;

    __try
    {
        hr = src->CopyPixels(rc, cbStride, cbBufferSize, buffer);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return E_UNEXPECTED;
    }

    return hr;
}

// applyColorManagement() parses the ICC profile embedded in the file, which is codec
// territory like any other; it builds std::strings of its own, so the __try has to sit
// out here rather than inside it
static int WICguardedColorManagement(IWICBitmapSource* &thisWICbitmap, IWICBitmapFrameDecode* &pFrame,
                                     GUID destPixFormat, int useICM, DWORD *sehCode) {
    int okay = 0;
    *sehCode = 0;
    __try
    {
        okay = applyColorManagement(thisWICbitmap, pFrame, destPixFormat, useICM);
    }
    __except (WICcodecCrashFilter(GetExceptionCode()))
    {
        *sehCode = GetExceptionCode();
        return 0;
    }

    return okay;
}

Gdiplus::GpBitmap* WICbmpSourceConvertGdip(IWICBitmapSource* &thisWICbitmap, UINT &width, UINT &height, UINT cbStride, UINT cbBufferSize, Gdiplus::PixelFormat destinationFormat) {
     Gdiplus::GpBitmap *myBitmap = NULL;
     if (thisWICbitmap==NULL || width<1 || height<1)
        return myBitmap;

     Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, cbStride, destinationFormat, NULL, &myBitmap);
     if (myBitmap!=NULL)
     {
         Gdiplus::BitmapData bitmapDatu;
         Gdiplus::Rect rect(0, 0, width, height);
         // the lock status used to go unchecked, and bitmapDatu is uninitialized until it
         // succeeds - CopyPixels() then wrote the decoded image over a junk Scan0
         Gdiplus::Status lockSt = Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rect, Gdiplus::ImageLockModeWrite, destinationFormat, &bitmapDatu);
         if (lockSt!=Gdiplus::Ok)
         {
            fnOutputDebug("WICbmpSourceConvertGdip: failed to lock the GDI+ bitmap");
            Gdiplus::DllExports::GdipDisposeImage(myBitmap);
            return (Gdiplus::GpBitmap*)NULL;
         }

         // the buffer size is computed in 64-bit: stride is an INT and height a UINT, so
         // the old product wrapped silently on very large images
         DWORD   sehCode = 0;
         UINT64  bufSize = (UINT64)(bitmapDatu.Stride<0 ? -bitmapDatu.Stride : bitmapDatu.Stride) * (UINT64)height;
         HRESULT hr = (bufSize>0xFFFFFFFFull) ? E_INVALIDARG
                    : WICguardedCopyPixels(thisWICbitmap, NULL, bitmapDatu.Stride, (UINT)bufSize, (BYTE*)bitmapDatu.Scan0, &sehCode);
         Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu);
         if (sehCode!=0)
            fnOutputDebug("WICbmpSourceConvertGdip: the codec faulted while decoding the pixels");

         if (!(SUCCEEDED(hr)))
         {
            fnOutputDebug("WICbmpSourceConvertGdip: copy pixels FAILED: " + std::to_string(cbStride) + "|" + std::to_string(cbBufferSize));
            // a half written bitmap is not worth handing back; it used to be returned as
            // though the decode had worked
            Gdiplus::DllExports::GdipDisposeImage(myBitmap);
            myBitmap = NULL;
         }
    }
    return myBitmap;
}

BYTE* coreWICgetBufferImage(int bitsDepth, UINT64 cbStride, UINT64 cbBufferSize, int sliceHeight, int useICM, int mustClip, int x, int y, int w, int h, int newW, int newH, int givenQuality, Gdiplus::GpBitmap* &myBitmap) {
  // WIC factory initialized in initWICnow()
  // WIC image object preloaded via WICpreLoadImage()
  if (m_pIWICFactory==NULL || pWICclassFrameDecoded==NULL)
  {
     // reached whenever a preload failed or was discarded and the caller asked for pixels
     // anyway; without this the frame is dereferenced below at GetSize()
     fnOutputDebug("coreWICgetBufferImage: there is no preloaded WIC image to read from");
     return NULL;
  }

  HRESULT hr = S_OK, phr = S_OK;
  DWORD   sehCode = 0;
  IWICBitmapSource    *pFinalBitmapSource = NULL;
  IWICFormatConverter *pConverter         = NULL;
  IWICBitmapClipper   *pIClipper          = NULL;
  IWICBitmapScaler    *pScaler            = NULL;
  UINT width  = 0, height = 0;
  WICRect rcClip = { x, y, w, h };
  // Known bug: when pIClipper and pScaler (with something other than WICBitmapInterpolationModeNearestNeighbor)
  // are used ... color management gets broken , found in applyColorManagement();
  // I do not know if I am doing something wrong or just I am dumb;
  if (mustClip==1 && w>0 && h>0)
  {
      hr = m_pIWICFactory->CreateBitmapClipper(&pIClipper);
      if (SUCCEEDED(hr))
      {
         hr = WICguardedClipperInit(pIClipper, pWICclassFrameDecoded, &rcClip, &sehCode);
         if (SUCCEEDED(hr))
            hr = pIClipper->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&pFinalBitmapSource));
      }
      // fnOutputDebug("clip wic img: " + std::to_string(w) + " / " + std::to_string(h));
  } else hr = S_OK; // pWICclassFrameDecoded->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&pFinalBitmapSource));

  if (SUCCEEDED(hr))
  {
     if (newW<1 || newH<1)
     {
        UINT srcW = 0, srcH = 0;
        hr = WICguardedSourceInfo(pFinalBitmapSource ? pFinalBitmapSource : (IWICBitmapSource*)pWICclassFrameDecoded,
                                  &srcW, &srcH, NULL, &sehCode);
        width  = srcW;
        height = srcH;
        newW = (pIClipper!=NULL) ? w : (int)width;
        newH = (pIClipper!=NULL) ? h : (int)height;
     }

     if (SUCCEEDED(hr))
     {
        hr = m_pIWICFactory->CreateBitmapScaler(&pScaler);
        if (SUCCEEDED(hr))
        {
           WICBitmapInterpolationMode wicScaleQuality = indexedWICinterpolations(givenQuality);
           hr = WICguardedScalerInit(pScaler, pFinalBitmapSource ? pFinalBitmapSource : (IWICBitmapSource*)pWICclassFrameDecoded,
                                     newW, newH, wicScaleQuality, &sehCode);
           if (SUCCEEDED(hr))
           {
              WICsafeRelease(pFinalBitmapSource);
              hr = pScaler->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&pFinalBitmapSource));
           }
        }
     }
  }

  if (FAILED(hr) || pFinalBitmapSource==NULL)
  {
     fnOutputDebug("coreWICgetBufferImage: init failed");
     WICsafeRelease(pFinalBitmapSource);
     WICsafeRelease(pScaler);
     WICsafeRelease(pIClipper);
     WICdestroyPreloadedImage(1);
     return NULL;
  }

  GUID destFmt = (bitsDepth==32) ? GUID_WICPixelFormat32bppBGRA : GUID_WICPixelFormat24bppBGR;
  if (bitsDepth==33)
     destFmt = GUID_WICPixelFormat32bppPBGRA;
  else if (bitsDepth==16)
     destFmt = GUID_WICPixelFormat16bppBGR555;
  else if (bitsDepth==48)
     destFmt = GUID_WICPixelFormat48bppRGB;
  else if (bitsDepth==64)
     destFmt = GUID_WICPixelFormat64bppRGBA;
  else if (bitsDepth==96)
     destFmt = GUID_WICPixelFormat96bppRGBFloat;
  else if (bitsDepth==128)
     destFmt = GUID_WICPixelFormat128bppRGBAFloat;

  int hasICM = (useICM!=1) ? 0 : WICguardedColorManagement(pFinalBitmapSource, pWICclassFrameDecoded, destFmt, useICM, &sehCode);
  if (sehCode!=0)
     fnOutputDebug("coreWICgetBufferImage: the codec faulted on the embedded colour profile");

  if (hasICM!=1)
  {
     hr = m_pIWICFactory->CreateFormatConverter(&pConverter);
     if (SUCCEEDED(hr))
     {
        GUID srcFmt = GUID_WICPixelFormatDontCare;
        UINT tmpW = 0, tmpH = 0;
        hr = WICguardedSourceInfo(pFinalBitmapSource, &tmpW, &tmpH, &srcFmt, &sehCode);
        BOOL possible = 0;
        if (SUCCEEDED(hr))
           hr = WICguardedCanConvert(pConverter, &srcFmt, &destFmt, &possible, &sehCode);

        if (SUCCEEDED(hr) && possible==1)
        {
           hr = WICguardedConverterInit(pConverter, pFinalBitmapSource, &destFmt, &sehCode);
        } else
        {
           fnOutputDebug("coreWICgetBufferImage failed: cannot convert source to destination format (pixel formats)");
           hr = E_FAIL;
        }
     }

     if (SUCCEEDED(hr))
     {
        WICsafeRelease(pFinalBitmapSource);
        hr = pConverter->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&pFinalBitmapSource));
     }
  } else hr = S_OK;

  if (pFinalBitmapSource!=NULL)
  {
     UINT finalW = 0, finalH = 0;
     phr = WICguardedSourceInfo(pFinalBitmapSource, &finalW, &finalH, NULL, &sehCode);
     width  = finalW;
     height = finalH;
  }

  if (FAILED(hr) || FAILED(phr) || pFinalBitmapSource==NULL || !width || !height)
  {
     fnOutputDebug("coreWICgetBufferImage: early failure");
     WICsafeRelease(pFinalBitmapSource);
     WICsafeRelease(pConverter);
     applyColorManagement(pFinalBitmapSource, pWICclassFrameDecoded, destFmt, 100);
     WICsafeRelease(pScaler);
     WICsafeRelease(pIClipper);
     WICdestroyPreloadedImage(1);
     return NULL;
  }

  if (cbBufferSize==0 && cbStride==0)
  {
     cbStride = (UINT64)width * sizeof(Gdiplus::ARGB);
     cbBufferSize = cbStride * height;
  }

  BYTE *m_pbBuffer = NULL;
  if (myBitmap!=NULL)
  {
      Gdiplus::DllExports::GdipDisposeImage(myBitmap);
      myBitmap = WICbmpSourceConvertGdip(pFinalBitmapSource, width, height, (UINT)cbStride, (UINT)cbBufferSize, PixelFormat32bppPARGB);
  } else if (cbStride>0 && cbStride<=0xFFFFFFFFull && cbBufferSize>=cbStride)
  {
      // CopyPixels() takes the stride and the buffer size as UINTs, so anything past that
      // has to be refused here rather than truncated on the way in
      m_pbBuffer = new (std::nothrow) BYTE[cbBufferSize];
      y = 0;
      int indexu = 0;
      UINT64 buffOffset = 0;
      if (m_pbBuffer==NULL)
         fnOutputDebug("coreWICgetBufferImage: failed to allocate the pixel buffer");
      else
      {
          // fnOutputDebug("WIC buffer created: " + std::to_string(cbBufferSize));
          if (sliceHeight>0)
          {
             fnOutputDebug("WIC copy pixels in slices of h=" + std::to_string(sliceHeight));
             while (y<(int)height)
             {
                 if (indexu>0)
                    y += sliceHeight;
                 if (y>=(int)height)
                    break;

                 int h = (y + sliceHeight>(int)height) ? (int)height - y : sliceHeight;
                 WICRect rc = { 0, y, (int)width, h };
                 // in 64-bit, and checked against what is left of the buffer: this used to
                 // be a UINT product that could wrap, and CopyPixels() writes as many bytes
                 // as it is told to at m_pbBuffer + buffOffset
                 UINT64 tmpBufferSize = cbStride * (UINT64)h;
                 if (tmpBufferSize<1 || tmpBufferSize>0xFFFFFFFFull || buffOffset+tmpBufferSize>cbBufferSize)
                 {
                    fnOutputDebug("coreWICgetBufferImage: the slice does not fit the buffer");
                    hr = E_FAIL;
                    break;
                 }

                 // fnOutputDebug(std::to_string(indexu) + "# y=" + std::to_string(y) + "; h=" + std::to_string(h));
                 // the result used to land in an inner HRESULT that shadowed this one, so a
                 // sliced copy could fail from end to end and still be reported as a success
                 hr = WICguardedCopyPixels(pFinalBitmapSource, &rc, (UINT)cbStride, (UINT)tmpBufferSize, m_pbBuffer + buffOffset, &sehCode);
                 if (FAILED(hr))
                    break;

                 buffOffset += tmpBufferSize;
                 indexu++;
             }
          } else {
             // fnOutputDebug("coreWICgetBufferImage: WIC copy pixels to buffer: JOKE");
             hr = (cbBufferSize>0xFFFFFFFFull) ? E_INVALIDARG
                : WICguardedCopyPixels(pFinalBitmapSource, NULL, (UINT)cbStride, (UINT)cbBufferSize, m_pbBuffer, &sehCode);
          }

          if (sehCode!=0)
             fnOutputDebug("coreWICgetBufferImage: the codec faulted while decoding the pixels");

          if (SUCCEEDED(hr)) {
             fnOutputDebug("coreWICgetBufferImage: WIC copy pixels to buffer: yay");
          } else
          {
             // the buffer is handed to FreeImage_ConvertFromRawBitsEx() as a finished image;
             // returning it half written means displaying uninitialized heap
             fnOutputDebug("coreWICgetBufferImage: copy pixels to buffer: FAILED");
             delete[] m_pbBuffer;
             m_pbBuffer = NULL;
          }
      }
  } else fnOutputDebug("coreWICgetBufferImage: the stride and buffer size given do not describe an image");

  WICsafeRelease(pFinalBitmapSource);
  WICsafeRelease(pConverter);
  applyColorManagement(pFinalBitmapSource, pWICclassFrameDecoded, destFmt, 100);
  WICsafeRelease(pScaler);
  WICsafeRelease(pIClipper);
  return m_pbBuffer;
}

DLL_API BYTE* DLL_CALLCONV WICgetBufferImage(int bitsDepth, UINT64 cbStride, UINT64 cbBufferSize, int sliceHeight, int useICM) {
    Gdiplus::GpBitmap *myBitmap = NULL;
    return coreWICgetBufferImage(bitsDepth, cbStride, cbBufferSize, sliceHeight, useICM, 0, 0, 0, 0, 0, 0, 0, 0, myBitmap);
}

Gdiplus::GpBitmap* BYTEconvertGdip(BYTE* &m_pbBuffer, UINT &width, UINT &height, UINT &cbStride) {
     Gdiplus::GpBitmap *myBitmap = NULL;
     Gdiplus::DllExports::GdipCreateBitmapFromScan0(width, height, cbStride, PixelFormat32bppPARGB, NULL, &myBitmap);
     if (myBitmap!=NULL)
     {
         Gdiplus::Rect rectu(0, 0, width, height);
         Gdiplus::BitmapData bitmapDatu;
         bitmapDatu.Width = width;
         bitmapDatu.Height = height;
         bitmapDatu.Stride = cbStride;
         bitmapDatu.Scan0 = m_pbBuffer;
         bitmapDatu.PixelFormat = PixelFormat32bppPARGB;

         // ImageLockModeWrite | ImageLockModeUserInputBuf: the unlock copies m_pbBuffer in, so a failed
         // lock or unlock leaves a blank bitmap that must not pass for the image
         if (Gdiplus::DllExports::GdipBitmapLockBits(myBitmap, &rectu, 6, PixelFormat32bppPARGB, &bitmapDatu)!=Gdiplus::Ok
          || Gdiplus::DllExports::GdipBitmapUnlockBits(myBitmap, &bitmapDatu)!=Gdiplus::Ok)
         {
            fnOutputDebug("BYTEconvertGdip: failed to copy the pixels into the GDI+ bitmap");
            Gdiplus::DllExports::GdipDisposeImage(myBitmap);
            myBitmap = NULL;
         }
     } else fnOutputDebug("BYTEconvertGdip: failed to create GDI+ bitmap object");

     return myBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV WICgetRectImage(int x, int y, int w, int h, int newW, int newH, int mustClip, int useICM, int givenQuality) {
  UINT Stride = 0;
  UIntMult(100, sizeof(Gdiplus::ARGB), &Stride);
  Gdiplus::GpBitmap* myBitmap = NULL;
  Gdiplus::DllExports::GdipCreateBitmapFromScan0(100, 100, Stride, PixelFormat32bppPARGB, NULL, &myBitmap);
  if (myBitmap!=NULL)
     BYTE* m_pbBuffer = coreWICgetBufferImage(33, 0, 0, 0, useICM, mustClip, x, y, w, h, newW, newH, givenQuality, myBitmap);
  return myBitmap;
}

bool IsWicDecoderAvailable(const GUID& formatGuid) {
    IWICComponentInfo     *pCompInfo  = NULL;
    IWICBitmapDecoderInfo *pDecInfo   = NULL;
    IEnumUnknown          *pEnum      = NULL;
    bool                  isAvailable = false;
    if (m_pIWICFactory==NULL)
       return false;

    // Create component enumerator for decoders
    HRESULT hr = m_pIWICFactory->CreateComponentEnumerator(WICDecoder, WICComponentEnumerateDefault, &pEnum);
    if (SUCCEEDED(hr)) {
        // Enumerate through decoders
        IUnknown* pElement = nullptr;
        ULONG fetched;
        
        while (pEnum->Next(1, &pElement, &fetched) == S_OK) {
            hr = pElement->QueryInterface(IID_PPV_ARGS(&pCompInfo));
            if (SUCCEEDED(hr)) {
                hr = pCompInfo->QueryInterface(IID_PPV_ARGS(&pDecInfo));
                if (SUCCEEDED(hr)) {
                    GUID decoderGuid;
                    hr = pDecInfo->GetContainerFormat(&decoderGuid);
                    if (SUCCEEDED(hr) && decoderGuid == formatGuid)
                        isAvailable = true;

                    pDecInfo->Release();
                }
                pCompInfo->Release();
            }
            pElement->Release();
            // the match used to break out from inside, before pCompInfo and pElement were
            // released, so every image loaded leaked two component references
            if (isAvailable)
                break;
        }
        pEnum->Release();
    }
    if (!isAvailable)
       fnOutputDebug("IsWicDecoderAvailable: no decoder identified by given GUID");

    return isAvailable;
}

int decideWICtoFIMpixelFormat(GUID fmt) {
      // grey, palette and 16-bit RGB formats get 24 bits as well: a 16-bit FreeImage bitmap
      // keeps 5 bits per channel
      int d = 24;
      if (fmt == GUID_WICPixelFormat24bppBGR           || fmt == GUID_WICPixelFormat24bppRGB
      || fmt == GUID_WICPixelFormat24bpp3Channels      || fmt == GUID_WICPixelFormat32bppBGR
      || fmt == GUID_WICPixelFormat32bppRGB            || fmt == GUID_WICPixelFormat32bppCMYK
      || fmt == GUID_WICPixelFormat16bppGrayFixedPoint || fmt == GUID_WICPixelFormat16bppGrayHalf)
         d = 24;  // 1 = FIT_BITMAP | 24 bits

      if (fmt == GUID_WICPixelFormat32bppBGRA          || fmt == GUID_WICPixelFormat16bppBGRA5551
      || fmt == GUID_WICPixelFormat32bppPBGRA          || fmt == GUID_WICPixelFormat32bppRGBA
      || fmt == GUID_WICPixelFormat32bppPRGBA          || fmt == GUID_WICPixelFormat32bpp4Channels
      || fmt == GUID_WICPixelFormat32bpp3ChannelsAlpha || fmt == GUID_WICPixelFormat40bppCMYKAlpha
      || fmt == GUID_WICPixelFormat8bppAlpha)
         d = 32;  // 1 = FIT_BITMAP | 32 bits

      if (fmt == GUID_WICPixelFormat48bppBGR          || fmt == GUID_WICPixelFormat32bppGrayFixedPoint
      || fmt == GUID_WICPixelFormat32bppGrayFloat     || fmt == GUID_WICPixelFormat32bppBGR101010
      || fmt == GUID_WICPixelFormat32bppRGBE          || fmt == GUID_WICPixelFormat48bppRGB
      || fmt == GUID_WICPixelFormat48bppRGBFixedPoint || fmt == GUID_WICPixelFormat48bppBGRFixedPoint
      || fmt == GUID_WICPixelFormat48bppRGBHalf       || fmt == GUID_WICPixelFormat48bpp3Channels
      || fmt == GUID_WICPixelFormat64bppCMYK          || fmt == GUID_WICPixelFormat64bppRGB)
         d = 48;   // 9 = FIT_RGB16 | 48-bit RGB image: 3 x unsigned 16-bit

      if (fmt == GUID_WICPixelFormat64bppBGRA            || fmt == GUID_WICPixelFormat32bppRGBA1010102
      || fmt == GUID_WICPixelFormat32bppRGBA1010102XR    || fmt == GUID_WICPixelFormat32bppR10G10B10A2
      || fmt == GUID_WICPixelFormat32bppR10G10B10A2HDR10 || fmt == GUID_WICPixelFormat64bppRGBA
      || fmt == GUID_WICPixelFormat64bppPRGBA            || fmt == GUID_WICPixelFormat64bppPBGRA
      || fmt == GUID_WICPixelFormat64bppRGBAHalf         || fmt == GUID_WICPixelFormat64bppPRGBAHalf
      || fmt == GUID_WICPixelFormat64bpp3ChannelsAlpha   || fmt == GUID_WICPixelFormat80bppCMYKAlpha)
         d = 64;   // 10 = FIT_RGBA16 | 64-bit RGBA image: 4 x unsigned 16-bit

      if (fmt == GUID_WICPixelFormat96bppRGBFixedPoint  || fmt == GUID_WICPixelFormat64bppRGBHalf
      || fmt == GUID_WICPixelFormat96bppRGBFloat        || fmt == GUID_WICPixelFormat128bppRGBFixedPoint
      || fmt == GUID_WICPixelFormat128bppRGBFloat       || fmt == GUID_WICPixelFormat64bppRGBFixedPoint)
         d = 96;   // 11 = FIT_RGBF | 96-bit RGB float image: 3 x 32-bit IEEE floating point

      if (fmt == GUID_WICPixelFormat128bppRGBAFloat     || fmt == GUID_WICPixelFormat128bppPRGBAFloat || fmt == GUID_WICPixelFormat128bppRGBAFixedPoint
      || fmt == GUID_WICPixelFormat64bppRGBAFixedPoint  || fmt == GUID_WICPixelFormat64bppBGRAFixedPoint)
         d = 128;   // 12 = FIT_RGBAF | 128-bit RGBA float image: 4 x 32-bit IEEE floating point

      return d;
}

bool IsFileExtension(const wchar_t* szFileName, const wchar_t* extension) {
    if (!szFileName || !extension) {
        return false;
    }

    // Make sure extension starts with a dot
    const wchar_t* dotExtension = (extension[0] == L'.') ? extension : nullptr;
    if (!dotExtension) {
        return false;
    }

    // Find the last occurrence of '.' in filename
    const wchar_t* fileExt = wcsrchr(szFileName, L'.');
    if (!fileExt) {
        return false;
    }

    // Compare the extensions (case-insensitive)
    return _wcsicmp(fileExt, dotExtension) == 0;
}

DLL_API int DLL_CALLCONV WICpreLoadImage(const wchar_t *szFileName, int givenFrame, UINT *resultsArray, int isFIMokay) {
  // WIC factory initialized in initWICnow()
  if (resultsArray==NULL || szFileName==NULL || szFileName[0]==L'\0')
     return 0;

  if (m_pIWICFactory==NULL)
  {
     fnOutputDebug("WICpreLoadImage: WIC was never initialized; initWICnow() must succeed first");
     return 0;
  }

  // whatever a previous preload left behind is released here instead of being overwritten:
  // the two globals are the only handle anybody holds on those objects, and the decoder
  // keeps the previous file mapped until it goes
  WICdestroyPreloadedImage(1);

  int destinationFormat = 0;
  try
  {
      WICframeFacts facts = {};
      DWORD   sehCode = 0;
      char    sehTxt[32];
      HRESULT hr = WICguardedOpenFrame(m_pIWICFactory, szFileName, givenFrame,
                                       &pWICclassDecoder, &pWICclassFrameDecoded, &facts, &sehCode);
      if (sehCode!=0)
      {
         sprintf_s(sehTxt, "0x%08X", (unsigned int)sehCode);
         fnOutputDebug("WICpreLoadImage: the WIC codec faulted (" + std::string(sehTxt) + ") on file: " + WideCharToString(szFileName));
         WICguardedRelease(pWICclassFrameDecoded);
         WICguardedRelease(pWICclassDecoder);
         pWICclassFrameDecoded = NULL;
         pWICclassDecoder = NULL;
         return 0;
      }

      // this loader hands the caller a container format and a pixel format that AHK
      // records and acts on, so unlike the thumbnailer it cannot proceed without either
      if (SUCCEEDED(hr) && (!facts.gotContainerFmt || !facts.gotPixelFmt))
      {
         fnOutputDebug("WICpreLoadImage: error: the frame reports no container or pixel format");
         hr = E_FAIL;
      }

      if (SUCCEEDED(hr) && !IsWicDecoderAvailable(facts.containerFmt))
         hr = E_FAIL;

      if (SUCCEEDED(hr) && ((!facts.width || !facts.height) || (facts.width==1 && facts.height==1)))
      {
         fnOutputDebug("WICpreLoadImage: error: no width and height for the decoded frame");
         hr = E_FAIL;
      }

      if (SUCCEEDED(hr) && (facts.width>0x7FFFFFFFu || facts.height>0x7FFFFFFFu))
      {
         // GDI+, FreeImage and the AHK side all carry these as signed ints further down;
         // a header claiming more than that is malformed by definition
         fnOutputDebug("WICpreLoadImage: error: the frame declares an impossible size");
         hr = E_FAIL;
      }

      if (SUCCEEDED(hr))
      {
         UINT ucontainerFmt = indexedWICcontainerFormats(facts.containerFmt);
         UINT bpp = 0, channels = 0;
         DWORD infoSehCode = 0;
         hr = WICguardedPixelFormatInfo(m_pIWICFactory, &facts.pixelFmt, &bpp, &channels, &infoSehCode);
         if (infoSehCode!=0)
         {
            sprintf_s(sehTxt, "0x%08X", (unsigned int)infoSehCode);
            fnOutputDebug("WICpreLoadImage: the pixel format component faulted (" + std::string(sehTxt) + ")");
         }

         destinationFormat = decideWICtoFIMpixelFormat(facts.pixelFmt);
         const GUID &pf = facts.pixelFmt;
         if (SUCCEEDED(hr) && (pf==GUID_WICPixelFormat1bppIndexed || pf==GUID_WICPixelFormat2bppIndexed
             || pf==GUID_WICPixelFormat4bppIndexed || pf==GUID_WICPixelFormat8bppIndexed))
         {
            // transparent palette entries need the alpha channel
            DWORD palSehCode = 0;
            if (WICguardedPaletteHasAlpha(m_pIWICFactory, pWICclassFrameDecoded, &palSehCode)==1)
               destinationFormat = 32;
            else if (palSehCode!=0)
               fnOutputDebug("WICpreLoadImage: the codec faulted on the palette");
         }

         int tif = (IsFileExtension(szFileName, L".tif")==1 || IsFileExtension(szFileName, L".tiff")==1) ? 1 : 0;
         if (tif==1 && destinationFormat>32 && isFIMokay==1)
         {
            fnOutputDebug("WICpreLoadImage: abandon loading HDR TIFF image with WIC; pass it to FreeImage");
            destinationFormat = 0;
            hr = E_FAIL;
         } else if (ucontainerFmt==9 && facts.width==256 && facts.height==192)
         {
            fnOutputDebug("WICpreLoadImage: error: DNG loaded could not be decoded properly; an icon was retrieved - to be discarded");
            hr = E_FAIL;
         }
         // fnOutputDebug("WICpreLoadImage: container format = " + std::to_string(ucontainerFmt));

         if (SUCCEEDED(hr))
         {
            // the results are published only once the frame is known to be usable, so a
            // half filled array can never be read back as if it described a real image
            double dpiAvg = (facts.dpix + facts.dpiy) * 0.5;
            resultsArray[0] = facts.width;
            resultsArray[1] = facts.height;
            resultsArray[2] = facts.frames;
            resultsArray[3] = indexedWICpixelFormats(facts.pixelFmt);
            // a NaN or an absurd resolution out of broken metadata would convert into
            // garbage; both comparisons are false for NaN, which lands on zero
            resultsArray[4] = (dpiAvg>0.0 && dpiAvg<1000000.0) ? (UINT)(dpiAvg + 0.5) : 0;
            resultsArray[5] = ucontainerFmt;
            resultsArray[6] = facts.activeFrame;
            resultsArray[7] = bpp;
            resultsArray[8] = channels;
         }
      }

      if (FAILED(hr))
      {
         WICdestroyPreloadedImage(1);
         fnOutputDebug("WICpreLoadImage: WIC decoder error on file: " + WideCharToString(szFileName));
         return 0;
      }

      // fnOutputDebug("WIC pixel format index: " + std::to_string(uPixFmt) + " | bpp = " + std::to_string(bpp) + " * " + std::to_string(channels) + " channels");
      return destinationFormat;
  } catch (...)
  {
      // an std::string that fails to allocate, or WideCharToString() choking on a path
      // with unpaired surrogates, would otherwise unwind straight out of this exported
      // function and into AHK, which has nothing to catch it with
      try
      {
          fnOutputDebug("WICpreLoadImage: an undefined error occured");
          WICdestroyPreloadedImage(1);
      } catch (...) { }
      return 0;
  }

  return 0;
}

static int openCVresizeBitmap(unsigned char *imageData, unsigned char *otherData, int w, int h, int Stride, int rw, int rh, int mStride, int bpp, int interpolation, int doFlipHV) {
  int clr = (bpp==32) ? CV_8UC4 : CV_8UC3;
  cv::Mat image(h, w, clr, imageData, Stride);
  if (doFlipHV==4)
     cv::flip(image, image, 1);
  else if (doFlipHV==6)
     cv::flip(image, image, 0);
  else if (doFlipHV==2)
     cv::flip(image, image, -1);

  cv::Mat other(rh, rw, clr, otherData, mStride);

  try
  {
      // cv::resize(image, other, cv::Size(rw, rh), 0, 0, interpolation);
      cv::resize(image, other, other.size(), 0, 0, interpolation);
  } catch (const cv::Exception &e)
  {
      fnOutputDebug("OpenCV: error attempting to resize bitmap in openCVresizeBitmap: " + std::to_string(w) + " x " + std::to_string(h) + " to " + std::to_string(rw) + " x " + std::to_string(rh));
      fnOutputDebug( e.what() );
      return 0;
  }
  return 1;
}

// what one LoadWICimage() call works with: its arguments, in its order, and what its stages build
struct WICload {
    int threadIDu;
    int noBPPconv;
    int givenQuality;
    UINT givenW;
    UINT givenH;
    UINT keepAratio;
    UINT ScaleAnySize;
    UINT givenFrame;
    int doFlipHV;
    int useICM;
    const wchar_t *szFileName;
    UINT *resultsArray;
    int isFIMokay;

    Gdiplus::GpBitmap     *myBitmap             = NULL;
    IWICBitmapSource      *pFinalBitmapSource   = NULL;
    IWICFormatConverter   *pConverter           = NULL;
    IWICBitmapDecoder     *pDecoder             = NULL;
    IWICBitmapScaler      *pScaler              = NULL;
    IWICBitmapFrameDecode *pFrame               = NULL;
    WICPixelFormatGUID    destinationFormat     = GUID_WICPixelFormat32bppPBGRA;
    Gdiplus::PixelFormat  destinationGdipFormat = PixelFormat32bppPARGB;
    UINT owidth = 0, oheight = 0, mustResize = 0;
    DWORD sehCode = 0;
};

static void wicLoadLog(const WICload &ld, const std::string &msg) {
    fnOutputDebug(std::to_string(ld.threadIDu) + "# | LoadWICimage: " + msg);
}

// the decoder and the frame, with the frame's header in facts; on a codec fault both are released
static HRESULT wicLoadOpenFrame(WICload &ld, WICframeFacts &facts) {
    // the decoder, the frame and the whole header read happen behind the SEH guard;
    // see the block above WICbmpSourceConvertGdip() for why a catch() cannot do this
    int wantFrame = (ld.givenFrame>0x7FFFFFFFu) ? 0x7FFFFFFF : (int)ld.givenFrame;
    HRESULT hr = WICguardedOpenFrame(m_pIWICFactory, ld.szFileName, wantFrame, &ld.pDecoder, &ld.pFrame, &facts, &ld.sehCode);
    if (ld.sehCode!=0)
    {
       char sehTxt[32];
       sprintf_s(sehTxt, "0x%08X", (unsigned int)ld.sehCode);
       wicLoadLog(ld, "the WIC codec faulted (" + std::string(sehTxt) + ") on file: " + WideCharToString(ld.szFileName));
       WICsafeRelease(ld.pFrame);
       WICsafeRelease(ld.pDecoder);
       return hr;
    }

    if (FAILED(hr))
       wicLoadLog(ld, "failed to open a frame of " + WideCharToString(ld.szFileName));
    return hr;
}

// the frame's size and pixel format, published with the other image properties in resultsArray; the
// icon a DNG falls back to is turned down, and so are HDR TIFFs when FreeImage can take them
static HRESULT wicLoadPixelFormat(WICload &ld, const WICframeFacts &facts, HRESULT hr) {
    ld.owidth  = facts.width;
    ld.oheight = facts.height;
    if (SUCCEEDED(hr) && ((!ld.owidth || !ld.oheight) || (ld.owidth==1 && ld.oheight==1)))
    {
       wicLoadLog(ld, "error: no width and height for the decoded frame");
       hr = E_FAIL;
    }

    if (SUCCEEDED(hr) && (ld.owidth>0x7FFFFFFFu || ld.oheight>0x7FFFFFFFu))
    {
       // everything downstream carries these as signed ints
       wicLoadLog(ld, "error: the frame declares an impossible size");
       hr = E_FAIL;
    }

    if (SUCCEEDED(hr) && !facts.gotPixelFmt)
    {
       // the pixel format decides destinationBPP and reaches AHK as image properties;
       // it used to be read into opixelFormat and the failure then silently overwritten
       // by the CreateComponentInfo() call that followed
       wicLoadLog(ld, "failed to retrieve image pixel format");
       hr = E_FAIL;
    }

    if (SUCCEEDED(hr))
    {
       WICPixelFormatGUID opixelFormat = facts.pixelFmt;
       UINT ucontainerFmt = facts.gotContainerFmt ? indexedWICcontainerFormats(facts.containerFmt) : 0;
       auto nSize = adaptImageGivenSize(ld.keepAratio, ld.ScaleAnySize, ld.owidth, ld.oheight, ld.givenW, ld.givenH);
       ld.mustResize = (nSize[0]!=ld.owidth || nSize[1]!=ld.oheight) ? 1 : 0;
       if (ld.mustResize==1)
       {
          ld.destinationFormat = GUID_WICPixelFormat32bppPBGRA;
          ld.destinationGdipFormat = PixelFormat32bppPARGB;
       }

       int destinationBPP = decideWICtoFIMpixelFormat(opixelFormat);
       UINT bpp = 0, channels = 0;
       DWORD infoSehCode = 0;
       hr = WICguardedPixelFormatInfo(m_pIWICFactory, &opixelFormat, &bpp, &channels, &infoSehCode);
       if (infoSehCode!=0)
          wicLoadLog(ld, "the pixel format component faulted");

       if (SUCCEEDED(hr))
       {
          // published in one go, so a failed load can no longer leave the caller with
          // half of an image description
          double dpiAvg = (facts.dpix + facts.dpiy) * 0.5;
          ld.resultsArray[0] = ld.owidth;
          ld.resultsArray[1] = ld.oheight;
          ld.resultsArray[2] = facts.frames;
          ld.resultsArray[3] = indexedWICpixelFormats(opixelFormat);
          // NaN and absurd resolutions out of broken metadata used to convert into
          // garbage; both comparisons are false for NaN, which lands on zero
          ld.resultsArray[4] = (dpiAvg>0.0 && dpiAvg<1000000.0) ? (UINT)(dpiAvg + 0.5) : 0;
          ld.resultsArray[5] = ucontainerFmt;
          ld.resultsArray[6] = destinationBPP;
          ld.resultsArray[7] = bpp;
          ld.resultsArray[8] = channels;
       }

       int tif = (IsFileExtension(ld.szFileName, L".tif")==1 || IsFileExtension(ld.szFileName, L".tiff")==1) ? 1 : 0;
       // fnOutputDebug("LoadWICimage: container format ID=" + std::to_string(ucontainerFmt));
       if (SUCCEEDED(hr) && (ucontainerFmt==9 && ld.owidth==256 && ld.oheight==192 || tif==1 && destinationBPP>32 && ld.isFIMokay==1))
       {
          if (ucontainerFmt==9 && ld.owidth==256 && ld.oheight==192)
             wicLoadLog(ld, "error: DNG loaded could not be decoded properly; an icon was retrieved - to be discarded");
          else
             wicLoadLog(ld, "abandon loading HDR TIFF image with WIC; pass it to FreeImage");
          hr = E_FAIL;
       }
    }
    return hr;
}

// the scaler: the frame brought within the GDI+ limits
static HRESULT wicLoadScale(WICload &ld) {
    HRESULT hr = m_pIWICFactory->CreateBitmapScaler(&ld.pScaler);
    if (SUCCEEDED(hr))
    {
        // this will scale the image to the GDI+ limits; 536 mgpx; it ignores the givenW/H;
        // the image is going to be rescaled to the givenW/H, if needed, with OpenCV
        // I use opencv because it is much faster and because pScaler breaks the color
        // management function applyColorManagement();
        auto nSize = adaptImageGivenSize(2, ld.ScaleAnySize, ld.owidth, ld.oheight, ld.givenW, ld.givenH);
        // auto nSize = adaptImageGivenSize(keepAratio, ScaleAnySize, owidth, oheight, givenW, givenH);
        //fnOutputDebug("LoadWICimage: " + std::to_string(nSize[0]) + " x " + std::to_string(nSize[1]));
        hr = WICguardedScalerInit(ld.pScaler, ld.pFrame, nSize[0], nSize[1], WICBitmapInterpolationModeNearestNeighbor, &ld.sehCode);
        if (SUCCEEDED(hr))
           hr = ld.pScaler->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&ld.pFinalBitmapSource));
        else
           wicLoadLog(ld, "failed to initialize image scaler");
    } else wicLoadLog(ld, "failed to create image scaler");
    return hr;
}

// 1 when the embedded colour profile, or a fallback one, now converts the scaled frame
static int wicLoadColourManage(WICload &ld) {
    // convert the bitmap into 32bppBGR, a convenient pixel format for GDI+ rendering
    // the profile parsing sits behind the guard too: a corrupt embedded ICC is
    // read by the codec like any other part of the file
    int hasICM = (ld.useICM!=1) ? 0 : WICguardedColorManagement(ld.pFinalBitmapSource, ld.pFrame, ld.destinationFormat, ld.useICM, &ld.sehCode);
    if (ld.sehCode!=0)
       wicLoadLog(ld, "the codec faulted on the embedded colour profile");
    return hasICM;
}

// the format converter to destinationFormat, when no colour transform does it
static HRESULT wicLoadConvert(WICload &ld) {
    HRESULT hr = m_pIWICFactory->CreateFormatConverter(&ld.pConverter);
    if (SUCCEEDED(hr))
    {
        hr = WICguardedConverterInit(ld.pConverter, ld.pFinalBitmapSource, &ld.destinationFormat, &ld.sehCode);
        if (SUCCEEDED(hr))
        {
           WICsafeRelease(ld.pFinalBitmapSource);
           hr = ld.pConverter->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void **>(&ld.pFinalBitmapSource));
        } else
           wicLoadLog(ld, "failed to initialize image pixel format converter");
    } else wicLoadLog(ld, "failed to create the image pixel format converter");
    return hr;
}

// the size at the end of the chain, which must have come out in destinationFormat
static HRESULT wicLoadSourceSize(WICload &ld, UINT &width, UINT &height) {
    // double check bitmap source format, and take the size off the same guarded call
    WICPixelFormatGUID pixelFormat = GUID_WICPixelFormatDontCare;
    HRESULT hr = WICguardedSourceInfo(ld.pFinalBitmapSource, &width, &height, &pixelFormat, &ld.sehCode);
    if (ld.sehCode!=0)
       wicLoadLog(ld, "the codec faulted while reporting the converted source");

    if (SUCCEEDED(hr))
       hr = (pixelFormat == ld.destinationFormat) ? S_OK : E_FAIL;
    return hr;
}

// the pixels copied into m_pbBuffer, resized to givenW/H [and flipped] with OpenCV and handed to GDI+
static void wicLoadResized(WICload &ld, BYTE *m_pbBuffer, UINT width, UINT height, UINT cbStride, UINT cbBufferSize) {
    auto nSize = adaptImageGivenSize(ld.keepAratio, ld.ScaleAnySize, width, height, ld.givenW, ld.givenH);
    HRESULT hr = WICguardedCopyPixels(ld.pFinalBitmapSource, NULL, cbStride, cbBufferSize, m_pbBuffer, &ld.sehCode);
    if (ld.sehCode!=0)
       wicLoadLog(ld, "the codec faulted while decoding the pixels");

    if (SUCCEEDED(hr))
    {
       // resize image with OpenCV;
       UINT NcbStride = 0, NcbBufferSize = 0;
       UIntMult(nSize[0], sizeof(Gdiplus::ARGB), &NcbStride);
       UIntMult(NcbStride, nSize[1], &NcbBufferSize);

       BYTE *otherData = NULL;  // the GDI+ bitmap buffer ... resized ^_^
       if (NcbStride>0 && NcbBufferSize>=NcbStride)
          otherData = new (std::nothrow) BYTE[NcbBufferSize];

       hr = (otherData!=NULL) ? S_OK : E_FAIL;
       if (SUCCEEDED(hr))
       {
           int k = (ld.givenQuality==7) ? 3 : 0;
           k = openCVresizeBitmap(m_pbBuffer, otherData, width, height, cbStride, nSize[0], nSize[1], NcbStride, 32, k, ld.doFlipHV);
           if (k==1)
              ld.myBitmap = BYTEconvertGdip(otherData, nSize[0], nSize[1], NcbStride);
           else
              wicLoadLog(ld, "failed to rescale bitmap using OpenCV");

           delete[] otherData;
           otherData = NULL;
       } else wicLoadLog(ld, "failed to allocate buffer for the resized bitmap");
    } else wicLoadLog(ld, "failed to copy pixels to the allocated buffer");
}

// the GDI+ bitmap: through wicLoadResized() when the image must be resized, straight from WIC otherwise
static void wicLoadToGdip(WICload &ld, UINT width, UINT height) {
    // create a DIB from the converted IWICBitmapSource
    // Size of a scan line represented in bytes: 4 bytes each pixel
    UINT cbStride = 0, cbBufferSize = 0;
    HRESULT hr = UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);
    if (SUCCEEDED(hr))
       hr = UIntMult(cbStride, height, &cbBufferSize);

    if (SUCCEEDED(hr) && width>0 && height>0 && cbStride>0 && cbBufferSize>=cbStride)
    {
        BYTE *m_pbBuffer = NULL;  // the GDI+ bitmap buffer
        if (ld.mustResize==1)
           m_pbBuffer = new (std::nothrow) BYTE[cbBufferSize];

        hr = (m_pbBuffer!=NULL || ld.mustResize!=1) ? S_OK : E_FAIL;
        if (SUCCEEDED(hr))
        {
            if (ld.mustResize==1)
               wicLoadResized(ld, m_pbBuffer, width, height, cbStride, cbBufferSize);
            else
               ld.myBitmap = WICbmpSourceConvertGdip(ld.pFinalBitmapSource, width, height, cbStride, cbBufferSize, ld.destinationGdipFormat);
        } else wicLoadLog(ld, "failed to allocate the buffer for copy pixels");

        delete[] m_pbBuffer;
        m_pbBuffer = NULL;
    } else wicLoadLog(ld, "failed to prepare buffer for copy pixels");
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV LoadWICimage(int threadIDu, int noBPPconv, int givenQuality, UINT givenW, UINT givenH, UINT keepAratio, UINT ScaleAnySize, UINT givenFrame, int doFlipHV, int useICM, const wchar_t *szFileName, UINT *&resultsArray, int isFIMokay) {
// this function is meant to be self-contained and can be executed by different threads, via AHK
    // WIC factory initialized in initWICnow()
    if (szFileName==NULL || szFileName[0]==L'\0' || resultsArray==NULL)
       return NULL;

    if (m_pIWICFactory==NULL)
    {
       fnOutputDebug(std::to_string(threadIDu) + "# | LoadWICimage: WIC was never initialized; initWICnow() must succeed first");
       return NULL;
    }

    WICload ld = {threadIDu, noBPPconv, givenQuality, givenW, givenH, keepAratio, ScaleAnySize, givenFrame, doFlipHV, useICM, szFileName, resultsArray, isFIMokay};
    if (noBPPconv==32)
       ld.destinationFormat = GUID_WICPixelFormat32bppBGRA;
    else if (noBPPconv==24)
       ld.destinationFormat = GUID_WICPixelFormat24bppBGR;
    else if (noBPPconv==16)
       ld.destinationFormat = GUID_WICPixelFormat16bppBGR555;

    if (noBPPconv==32)
       ld.destinationGdipFormat = PixelFormat32bppARGB;
    else if (noBPPconv==24)
       ld.destinationGdipFormat = PixelFormat24bppRGB;
    else if (noBPPconv==16)
       ld.destinationGdipFormat = PixelFormat16bppRGB555;

    try
    {
        WICframeFacts facts = {};
        HRESULT hr = wicLoadOpenFrame(ld, facts);
        if (ld.sehCode!=0)
           return NULL;

        hr = wicLoadPixelFormat(ld, facts, hr);
        if (FAILED(hr))
        {
            WICsafeRelease(ld.pFrame);
            WICsafeRelease(ld.pDecoder);
            wicLoadLog(ld, "WIC decoder error on file " + WideCharToString(szFileName));
            return NULL;
        }

        // computed in 64-bit: the old UINT product wrapped, and a header claiming
        // 65536 x 65536 then reported 0 megapixels and walked straight past this gate
        const double mpx = ((UINT64)ld.owidth * (UINT64)ld.oheight)/1000000.0;
        if (noBPPconv==1 || noBPPconv==2 && mpx>536.4)
        {
           WICsafeRelease(ld.pFrame);
           WICsafeRelease(ld.pDecoder);
           return NULL;
        }

        hr = wicLoadScale(ld);
        if (SUCCEEDED(hr))
        {
            if (wicLoadColourManage(ld)!=1)
               hr = wicLoadConvert(ld);
        } else wicLoadLog(ld, "failed to rescale image");

        UINT width = 0, height = 0;
        if (SUCCEEDED(hr))
           hr = wicLoadSourceSize(ld, width, height);

        if (SUCCEEDED(hr))
           wicLoadToGdip(ld, width, height);
    } catch (...)
    {
        // nothing here may escape into AHK, which has no handler for a C++ exception
        try
        {
            wicLoadLog(ld, "an undefined error occured");
        } catch (...) { }

        if (ld.myBitmap!=NULL)
        {
           Gdiplus::DllExports::GdipDisposeImage(ld.myBitmap);
           ld.myBitmap = NULL;
        }
    }

    WICsafeRelease(ld.pFinalBitmapSource);
    WICsafeRelease(ld.pConverter);
    // useICM==100 is the cleanup mode: it releases the static colour contexts the
    // function keeps between calls, and returns before it looks at the two pointers
    applyColorManagement(ld.pFinalBitmapSource, ld.pFrame, ld.destinationFormat, 100);
    WICsafeRelease(ld.pScaler);
    WICsafeRelease(ld.pFrame);
    WICsafeRelease(ld.pDecoder);
    return ld.myBitmap;
}

#endif // QPV_WIC_LOADER_H
