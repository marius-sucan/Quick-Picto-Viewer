// svg-render.h
//
// SVG documents drawn by Direct2D into a WIC bitmap and handed over as GDI+ bitmaps.
//
// #included by qpv-main.cpp after wic-loader.h, whose SafeRelease() and
// WICbmpSourceConvertGdip() it uses, and ahead of thumbs-pool.h, which renders SVG
// thumbnails through LoadSVGimageEx() with factories of its own.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_SVG_RENDER_H
#define QPV_SVG_RENDER_H

Gdiplus::GpBitmap* WICBitmapToGdipBitmap(IWICBitmap* &thisWICbitmap) {
    Gdiplus::GpBitmap *myBitmap = NULL;
    if (!thisWICbitmap)
    {
       fnOutputDebug("WICBitmapToGdipBitmap: no WIC bitmap given");
       return myBitmap;
    }

    // Get Bitmap width and height
    GUID format;
    HRESULT hr = thisWICbitmap->GetPixelFormat(&format);
    UINT width = 0, height = 0, cbStride = 0, cbBufferSize = 0;
    thisWICbitmap->GetSize(&width, &height);
    if (!width || !height || height<2 || width<2 || FAILED(hr))
    {
       fnOutputDebug("WICBitmapToGdipBitmap: invalid WIC bitmap dimensions");
       return myBitmap;
    }

    IWICBitmapSource* convertedWICbitmap = NULL;
    if (format!=GUID_WICPixelFormat32bppPBGRA)
       hr = WICConvertBitmapSource(GUID_WICPixelFormat32bppPBGRA, thisWICbitmap, &convertedWICbitmap);
    else
       hr = thisWICbitmap->QueryInterface(IID_IWICBitmapSource, reinterpret_cast<void**>(&convertedWICbitmap));

    if (SUCCEEDED(hr))
    {
       UIntMult(width, sizeof(Gdiplus::ARGB), &cbStride);
       UIntMult(cbStride, height, &cbBufferSize);
       myBitmap = WICbmpSourceConvertGdip(convertedWICbitmap, width, height, cbStride, cbBufferSize, PixelFormat32bppPARGB);
       SafeRelease(convertedWICbitmap, "WICBitmapToGdipBitmap: convertedWICbitmap", 0);
    } else
    {
       fnOutputDebug("WICBitmapToGdipBitmap: QueryInterface or WICConvertBitmapSource failed");
       Gdiplus::DllExports::GdipDisposeImage(myBitmap);
       myBitmap = NULL;
    }

    return myBitmap;
}

// d2dFac and wicFac let a caller supply its own factories; the thumbnails pool hands over
// per worker ones, so several SVGs render at the same time. pD2D1Factory is created
// MULTI_THREADED, which makes it safe to share but also puts a lock around the factory and
// every resource made from it, so workers sharing it would take turns
// NULL unless the document was drawn: a bitmap nothing was drawn into must not pass for the image
IWICBitmap* WicD2DrenderSVG(const wchar_t* szFileName, UINT width, UINT height, float fSx, float fSy,
                            ID2D1Factory *d2dFac = NULL, IWICImagingFactory *wicFac = NULL) {
    // Create file stream and SVG document
    IStream*           pStream       = NULL;
    IWICBitmap*        pWICBitmap    = NULL;
    ID2D1RenderTarget* pRenderTarget = NULL;
    ID2D1SvgDocument*  pSvgDocument  = NULL;
    if (d2dFac==NULL)
       d2dFac = pD2D1Factory;
    if (wicFac==NULL)
       wicFac = m_pIWICFactory;

    HRESULT hr = SHCreateStreamOnFile(szFileName, STGM_READ | STGM_SHARE_DENY_WRITE, &pStream);
    if (pStream==NULL) {
        fnOutputDebug("WicD2DrenderSVG: failed SHCreateStreamOnFile()");
        return NULL;
    }

    // Create WIC Bitmap
    hr = wicFac->CreateBitmap(width, height, GUID_WICPixelFormat32bppPBGRA, WICBitmapCacheOnDemand, &pWICBitmap);
    if (!(SUCCEEDED(hr))) {
        fnOutputDebug("WicD2DrenderSVG: failed WIC factory - CreateBitmap()");
        pStream->Release();
        return NULL;
    }

    // Create render target properties
    D2D1_RENDER_TARGET_PROPERTIES props = D2D1::RenderTargetProperties( D2D1_RENDER_TARGET_TYPE_DEFAULT,
                                          D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED), 96.0f, 96.0f );

    // Create WIC Bitmap render target
    hr = d2dFac->CreateWicBitmapRenderTarget(pWICBitmap, props, &pRenderTarget);
    if (!(SUCCEEDED(hr))) {
        fnOutputDebug("WicD2DrenderSVG: failed CreateWicBitmapRenderTarget()");
        pStream->Release();
        pWICBitmap->Release();
        return NULL;
    }

    // Create SVG Document
    ID2D1DeviceContext5* pDeviceContext = nullptr;
    bool rendered = false;
    hr = pRenderTarget->QueryInterface(IID_ID2D1DeviceContext5, reinterpret_cast<void **>(&pDeviceContext));
    if (SUCCEEDED(hr) && pDeviceContext!=NULL)
    {
        D2D1_SIZE_F size = D2D1::SizeF((float)width, (float)height);
        hr = pDeviceContext->CreateSvgDocument(pStream, size, &pSvgDocument);
        if (SUCCEEDED(hr))
        {
            // D2D1_COLOR_F purple{0.459f, 0.227f, 0.533f, 1.0f};
            // D2D1_COLOR_F white{1.0f, 1.0f, 1.0f, 1.0f};
            // ID2D1SolidColorBrush* D2D1Brush = NULL;
            // HRESULT hrz = pRenderTarget->CreateSolidColorBrush(white, &D2D1Brush);
            // if (!(SUCCEEDED(hrz)))
            //    fnOutputDebug("alt-svg: failed CreateSolidColorBrush()");

            // Render SVG
            pRenderTarget->BeginDraw();
            if (fSx!=1 || fSy!=1)
            {
               D2D1_MATRIX_3X2_F matrix = D2D1::Matrix3x2F::Scale(fSx, fSy);
               pRenderTarget->SetTransform(&matrix);
            }
            // pRenderTarget->Clear(purple);
            // pRenderTarget->DrawLine({10, 10}, {310, 246}, D2D1Brush, 10);
            pDeviceContext->DrawSvgDocument(pSvgDocument);
            hr = pRenderTarget->EndDraw();
            if (SUCCEEDED(hr))
               rendered = true;
            else
               fnOutputDebug("WicD2DrenderSVG: failed EndDraw()");

            // D2D1Brush->Release();
        } else fnOutputDebug("WicD2DrenderSVG: failed pDeviceContext->CreateSvgDocument(pStream)");

        SafeRelease(pDeviceContext, "WicD2DrenderSVG: pDeviceContext", 0);
    } else fnOutputDebug("WicD2DrenderSVG: failed pRenderTarget->QueryInterface(&pDeviceContext)");

    SafeRelease(pSvgDocument, "WicD2DrenderSVG: pSvgDocument", 0);
    SafeRelease(pRenderTarget, "WicD2DrenderSVG: pRenderTarget", 0);
    SafeRelease(pStream, "WicD2DrenderSVG: pStream", 0);
    if (!rendered)
       SafeRelease(pWICBitmap, "WicD2DrenderSVG: pWICBitmap", 0);
    return pWICBitmap; // Caller is responsible for releasing this
}

// the body of LoadSVGimage(), with the two factories left to the caller; not exported.
// Passing NULL for either one falls back to the process wide factory, so this behaves
// exactly like LoadSVGimage() unless the caller has its own
Gdiplus::GpBitmap* LoadSVGimageEx(UINT givenW, UINT givenH, float fSx, float fSy, const wchar_t *szFileName,
                                  ID2D1Factory *d2dFac, IWICImagingFactory *wicFac) {
    Gdiplus::GpBitmap* myBitmap = NULL;
    IWICBitmap* thisWICbitmap = NULL;
    if (givenW<2 || givenH<2)
       return myBitmap;

    thisWICbitmap = WicD2DrenderSVG(szFileName, givenW, givenH, fSx, fSy, d2dFac, wicFac);
    if (thisWICbitmap!=NULL)
       myBitmap = WICBitmapToGdipBitmap(thisWICbitmap);

    SafeRelease(thisWICbitmap, "LoadSVGimage: thisWICbitmap", 0);
    return myBitmap;
}

DLL_API Gdiplus::GpBitmap* DLL_CALLCONV LoadSVGimage(int threadIDu, UINT givenW, UINT givenH, float fSx, float fSy, const wchar_t *szFileName) {
    return LoadSVGimageEx(givenW, givenH, fSx, fSy, szFileName, NULL, NULL);
}

#endif // QPV_SVG_RENDER_H
