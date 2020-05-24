
IWICImagingFactory_Initialize(ByRef pWICimgFactory, debugMode:=0) {
   cslid := moreWIC_GUIDs("sCLSID_WICImagingFactory")
   iid := moreWIC_GUIDs("sIID_IWICImagingFactory")
   pWICimgFactory := ComObjCreate("{" cslid "}","{" iid "}")
   If (debugMode=1)
      WIC_hr("debug", ErrorLevel, A_ThisFunc)
}

IWICImagingFactory_CreateStream(thisObj, ByRef ppIWICStream) {
   ; thisObj must be pWICimgFactory
   hr := DllCall(vtable(thisObj, 14), "ptr", thisObj, "ptr*", ppIWICStream)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICImagingFactory_CreateDecoderFromFilename(thisObj, wzFilename, pguidVendor:="", dwDesiredAccess:="", metadataOptions:="", ByRef ppIDecoder:=0) {
   ; thisObj must be pWICimgFactory
   If (dwDesiredAccess="")
      dwDesiredAccess := WIC_Constants("WICGenericReadAccess")
   If (metadataOptions="")  ; WICDecodeOptions
      metadataOptions := WIC_Constants("WICBitmapCacheOnLoad")

   hr := DllCall(vtable(thisObj, 3), "ptr", thisObj
         ,"wstr", wzFilename
         ,"ptr", WIC_GUID(GUID, pguidVendor)
         ,"uint", dwDesiredAccess
         ,"uint", metadataOptions
         ,"ptr*", ppIDecoder)

   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}


IWICImagingFactory_CreateBitmapFromMemory(thisObj, uiWidth, uiHeight, pixelFormat, cbStride, cbBufferSize, pbBuffer, ByRef ppIBitmap) {
   ; thisObj must be pWICimgFactory
   hr := DllCall(vtable(thisObj, 20), "ptr", thisObj, "uint", uiWidth, "uint", uiHeight, "ptr", pixelFormat, "uint", cbStride, "uint", cbBufferSize, "ptr", pbBuffer, "ptr*", ppIBitmap)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICImagingFactory_CreateFormatConverter(thisObj, ByRef ppIFormatConverter) {
   ; thisObj must be pWICimgFactory
   hr := DllCall(vtable(thisObj, 10), "ptr", thisObj, "ptr*", ppIFormatConverter)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICImagingFactory_CreateEncoder(thisObj, guidContainerFormat, pguidVendor, ByRef ppIEncoder) {
   ; thisObj must be pWICimgFactory
   hr := DllCall(vtable(thisObj, 8), "ptr", thisObj, "ptr", WIC_GUID(GUID1, guidContainerFormat), "ptr", WIC_GUID(GUID2, pguidVendor), "ptr*", ppIEncoder)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICImagingFactory_CreateBitmapScaler(thisObj, ByRef ppIBitmapScaler) {
   ; thisObj must be pWICimgFactory
   hr := DllCall(vtable(thisObj, 11), "ptr", thisObj, "ptr*", ppIBitmapScaler)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapScaler_Initialize(thisObj, pWICBitmapSource, uiWidth,uiHeight,InterpolationMode:="") {
   ; Initializes the bitmap scaler with the provided parameters.
   ; IWICBitmapScaler can't be initialized multiple times. For example, when scaling every frame in a multi-frame image, a new IWICBitmapScaler must be created and initialized for each frame.
   ; thisObj must be ppIBitmapScaler
   If (InterpolationMode="")
      InterpolationMode := WIC_Constants("WICBitmapInterpolationModeLinear")

   hr := DllCall(vtable(thisObj, 8), "ptr", thisObj
         ,"ptr",pWICBitmapSource
         ,"uint",uiWidth
         ,"uint",uiHeight
         ,"int",InterpolationMode)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapDecoder_GetFrameCount(thisObj, ByRef pCount) {
   ; thisObj must be a ppIDecoder
   hr := DllCall(vtable(thisObj, 12), "ptr", thisObj, "uint*", pCount)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   return hr
}

IWICBitmapDecoder_GetFrame(thisObj, frameIndex, ByRef ppIBitmapSourceFrame) {
   hr := DllCall(vtable(thisObj, 13), "ptr", thisObj
      ,"uint",frameIndex
      ,"ptr*",ppIBitmapSourceFrame)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   return hr
}

IWICStream_InitializeFromFilename(thisObj, wzFileName, dwDesiredAccess) {
   ; thisObj must be ppIWICStream

   hr := DllCall(vtable(thisObj, 15), "ptr", thisObj, "str", wzFileName, "uint", dwDesiredAccess)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapEncoder_Initialize(thisObj, pIStream, cacheOption) {
   ; thisObj must bbe ppIEncoder
   hr := DllCall(vtable(thisObj, 3), "ptr", thisObj, "ptr", pIStream, "int", cacheOption)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapEncoder_CreateNewFrame(thisObj, ByRef ppIFrameEncode, ppIEncoderOptions := 0) {
   ; thisObj must bbe ppIEncoder
   hr := DllCall(vtable(thisObj, 10), "ptr", thisObj, "ptr*", ppIFrameEncode, "ptr*", ppIEncoderOptions)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapEncoder_Commit(thisObj) {
   ; thisObj must bbe ppIEncoder
   hr := DllCall(vtable(thisObj, 11), "ptr", thisObj)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapFrameEncode_Initialize(thisObj, pIEncoderOptions:=0) {
   ; thisObj must bbe ppIFrameEncode
   hr := DllCall(vtable(thisObj, 3), "ptr", thisObj, "ptr", pIEncoderOptions)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapFrameEncode_SetSize(thisObj, uiWidth, uiHeight) {
   ; thisObj must bbe ppIFrameEncode
   hr := DllCall(vtable(thisObj, 4), "ptr", thisObj, "uint", uiWidth, "uint", uiHeight)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapFrameEncode_WritePixels(thisObj, lineCount, cbStride, cbBufferSize, pbPixels) {
   ; thisObj must bbe ppIFrameEncode
   hr := DllCall(vtable(thisObj, 10), "ptr", thisObj, "uint", lineCount, "uint", cbStride, "uint", cbBufferSize, "ptr", pbPixels)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapFrameEncode_Commit(thisObj) {
   ; thisObj must bbe ppIFrameEncode
   hr := DllCall(vtable(thisObj, 12), "ptr", thisObj)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapFrameEncode_WriteSource(thisObj, pIBitmapSource, prc) {
   ; thisObj must bbe ppIFrameEncode
   hr := DllCall(vtable(thisObj, 11), "ptr", thisObj, "ptr", pIBitmapSource, "ptr", prc)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICBitmapFrameEncode_SetPixelFormat(thisObj, ByRef FormatGuid, ByRef NewFormat:="dontCheck", ByRef GUID:="") {
   ; thisObj must bbe ppIFrameEncode
   if (NewFormat="dontCheck")
   {
      hr := DllCall(vtable(thisObj, 6), "ptr", thisObj, "ptr", FormatGuid)
      WIC_hr(hr, ErrorLevel, A_ThisFunc)
      Return hr
   } else
   {
      FormatGuid := WIC_GUID(GUID, FormatGuid)
      VarSetCapacity(NewFormat, 16, 0)
      DllCall("msvcrt\memcpy", "ptr", &NewFormat, "ptr", FormatGuid, "uint", 16, "cdecl")
      hr := DllCall(vtable(thisObj, 6), "ptr", thisObj, "ptr", &NewFormat)
      WIC_hr(hr, ErrorLevel, A_ThisFunc)
      if (DllCall("msvcrt\memcmp", "ptr", FormatGuid, "ptr", &NewFormat, Ptr, 16) = 0)
         return true
   }
}

IWICFormatConverter_Initialize(thisObj, pISource, dstFormat, dither, pIPalette, alphaThresholdPercent, paletteTranslate) {
   ; thisObj must be ppIFormatConverter
   ; COM_CLSIDfromString(pDstFormat, "{" moreWIC_GUIDs(dstFormat) "}" )

   pDstFormat := WIC_GUID(pGUID, dstFormat)
 msgbox, % dstFormat "`n" pDstFormat
   hr := DllCall(vtable(thisObj, 20), "ptr", thisObj, "ptr", pISource, "ptr", pDstFormat, "uint", dither, "ptr", pIPalette, "double", alphaThresholdPercent, "uint", paletteTranslate)
   WIC_hr(hr, ErrorLevel, A_ThisFunc)
   Return hr
}

IWICFormatConverter_CanConvert(thisObj, srcPixelFormat, dstPixelFormat) {
   ; thisObj must be ppIFormatConverter

   hr := DllCall(vtable(thisObj, 9), "ptr", thisObj, "ptr", srcPixelFormat, "ptr", dstPixelFormat, "ptr*", pfCanConvert)
   WIC_hr(hr, ErrorLevel, A_ThisFunc "`npfCanConvert=0")
   Return hr
}


;;;;;;;;;;;;;;;;;
;;WIC Constants;;
;;;;;;;;;;;;;;;;;

WIC_Struct(name,p=0){
   static init:=1,_:=[]
   if init{
      init:=0
      ,_["WICRect"]:=struct("INT X;INT Y;INT Width;INT Height;")
      ,_["WICBitmapPattern"]:=struct("ULARGE_INTEGER Position;ULONG Length;BYTE *Pattern;BYTE *Mask;BOOL EndOfStream;")
      ,_["WICRawCapabilitiesInfo"]:=struct("UINT cbSize;UINT CodecMajorVersion;UINT CodecMinorVersion;int ExposureCompensationSupport;int ContrastSupport;int RGBWhitePointSupport;int NamedWhitePointSupport;UINT NamedWhitePointSupportMask;int KelvinWhitePointSupport;int GammaSupport;int TintSupport;int SaturationSupport;int SharpnessSupport;int NoiseReductionSupport;int DestinationColorProfileSupport;int ToneCurveSupport;WICRawRotationCapabilities RotationSupport;int RenderModeSupport;")
      ,_["WICRawToneCurvePoint"]:=struct("double Input;double Output;")
      ,_["WICRawToneCurve"]:=struct("UINT cPoints;WICRawToneCurvePoint aPoints[1];")
   }
   return _.haskey(name)?_[name].clone(p=0?[]:p):"Struct not exists."
}

WIC_Constants(type) {
   Static init:=1, _:=[]
   if init
   {
      init := 0
       _["WICColorContextUninitialized"]:=0
      ,_["WICColorContextProfile"]:=0x1
      ,_["WICColorContextExifColorSpace"]:=0x2
      ,_["WICGenericReadAccess"]:=0x80000000
      ,_["WICGenericWriteAccess"]:=0x40000000
      ,_["WICBitmapNoCache"]:=0
      ,_["WICBitmapCacheOnDemand"]:=0x1
      ,_["WICBitmapCacheOnLoad"]:=0x2
      ,_["WICBITMAPCREATECACHEOPTION_FORCE_DWORD"]:=0x7fffffff
      ,_["WICDecodeMetadataCacheOnDemand"]:=0
      ,_["WICDecodeMetadataCacheOnLoad"]:=0x1
      ,_["WICMETADATACACHEOPTION_FORCE_DWORD"]:=0x7fffffff
       _["WICBitmapEncoderCacheInMemory"]:=0
      ,_["WICBitmapEncoderCacheTempFile"]:=0x1
      ,_["WICBitmapEncoderNoCache"]:=0x2
      ,_["WICBITMAPENCODERCACHEOPTION_FORCE_DWORD"]:=0x7fffffff
      ,_["WICDecoder"]:=0x1
      ,_["WICEncoder"]:=0x2
      ,_["WICPixelFormatConverter"]:=0x4
      ,_["WICMetadataReader"]:=0x8
      ,_["WICMetadataWriter"]:=0x10
      ,_["WICPixelFormat"]:=0x20
       _["WICAllComponents"]:=0x3f
      ,_["WICCOMPONENTTYPE_FORCE_DWORD"]:=0x7fffffff
      ,_["WICComponentEnumerateDefault"]:=0
      ,_["WICComponentEnumerateRefresh"]:=0x1
      ,_["WICComponentEnumerateDisabled"]:=0x80000000
      ,_["WICComponentEnumerateUnsigned"]:=0x40000000
      ,_["WICComponentEnumerateBuiltInOnly"]:=0x20000000
      ,_["WICCOMPONENTENUMERATEOPTIONS_FORCE_DWORD"]:=0x7fffffff
      ,_["WICBitmapInterpolationModeNearestNeighbor"]:=0
      ,_["WICBitmapInterpolationModeLinear"]:=0x1
       _["WICBitmapInterpolationModeCubic"]:=0x2
      ,_["WICBitmapInterpolationModeFant"]:=0x3
      ,_["WICBITMAPINTERPOLATIONMODE_FORCE_DWORD"]:=0x7fffffff
      ,_["WICBitmapPaletteTypeCustom"]:=0
      ,_["WICBitmapPaletteTypeMedianCut"]:=0x1
      ,_["WICBitmapPaletteTypeFixedBW"]:=0x2
      ,_["WICBitmapPaletteTypeFixedHalftone8"]:=0x3
      ,_["WICBitmapPaletteTypeFixedHalftone27"]:=0x4
      ,_["WICBitmapPaletteTypeFixedHalftone64"]:=0x5
      ,_["WICBitmapPaletteTypeFixedHalftone125"]:=0x6
       _["WICBitmapPaletteTypeFixedHalftone216"]:=0x7
      ,_["WICBitmapPaletteTypeFixedWebPalette"]:=WICBitmapPaletteTypeFixedHalftone216
      ,_["WICBitmapPaletteTypeFixedHalftone252"]:=0x8
      ,_["WICBitmapPaletteTypeFixedHalftone256"]:=0x9
      ,_["WICBitmapPaletteTypeFixedGray4"]:=0xa
      ,_["WICBitmapPaletteTypeFixedGray16"]:=0xb
      ,_["WICBitmapPaletteTypeFixedGray256"]:=0xc
      ,_["WICBITMAPPALETTETYPE_FORCE_DWORD"]:=0x7fffffff
      ,_["WICBitmapDitherTypeNone"]:=0
      ,_["WICBitmapDitherTypeSolid"]:=0
       _["WICBitmapDitherTypeOrdered4x4"]:=0x1
      ,_["WICBitmapDitherTypeOrdered8x8"]:=0x2
      ,_["WICBitmapDitherTypeOrdered16x16"]:=0x3
      ,_["WICBitmapDitherTypeSpiral4x4"]:=0x4
      ,_["WICBitmapDitherTypeSpiral8x8"]:=0x5
      ,_["WICBitmapDitherTypeDualSpiral4x4"]:=0x6
      ,_["WICBitmapDitherTypeDualSpiral8x8"]:=0x7
      ,_["WICBitmapDitherTypeErrorDiffusion"]:=0x8
      ,_["WICBITMAPDITHERTYPE_FORCE_DWORD"]:=0x7fffffff
      ,_["WICBitmapUseAlpha"]:=0
       _["WICBitmapUsePremultipliedAlpha"]:=0x1
      ,_["WICBitmapIgnoreAlpha"]:=0x2
      ,_["WICBITMAPALPHACHANNELOPTIONS_FORCE_DWORD"]:=0x7fffffff
      ,_["WICBitmapTransformRotate0"]:=0
      ,_["WICBitmapTransformRotate90"]:=0x1
      ,_["WICBitmapTransformRotate180"]:=0x2
      ,_["WICBitmapTransformRotate270"]:=0x3
      ,_["WICBitmapTransformFlipHorizontal"]:=0x8
      ,_["WICBitmapTransformFlipVertical"]:=0x10
      ,_["WICBITMAPTRANSFORMOPTIONS_FORCE_DWORD"]:=0x7fffffff
       _["WICBitmapLockRead"]:=0x1
      ,_["WICBitmapLockWrite"]:=0x2
      ,_["WICBITMAPLOCKFLAGS_FORCE_DWORD"]:=0x7fffffff
      ,_["WICBitmapDecoderCapabilitySameEncoder"]:=0x1
      ,_["WICBitmapDecoderCapabilityCanDecodeAllImages"]:=0x2
      ,_["WICBitmapDecoderCapabilityCanDecodeSomeImages"]:=0x4
      ,_["WICBitmapDecoderCapabilityCanEnumerateMetadata"]:=0x8
      ,_["WICBitmapDecoderCapabilityCanDecodeThumbnail"]:=0x10
      ,_["WICBITMAPDECODERCAPABILITIES_FORCE_DWORD"]:=0x7fffffff
      ,_["WICProgressOperationCopyPixels"]:=0x1
       _["WICProgressOperationWritePixels"]:=0x2
      ,_["WICProgressOperationAll"]:=0xffff
      ,_["WICPROGRESSOPERATION_FORCE_DWORD"]:=0x7fffffff
      ,_["WICProgressNotificationBegin"]:=0x10000
      ,_["WICProgressNotificationEnd"]:=0x20000
      ,_["WICProgressNotificationFrequent"]:=0x40000
      ,_["WICProgressNotificationAll"]:=0xffff0000
      ,_["WICPROGRESSNOTIFICATION_FORCE_DWORD"]:=0x7fffffff
      ,_["WICComponentSigned"]:=0x1
      ,_["WICComponentUnsigned"]:=0x2
       _["WICComponentSafe"]:=0x4
      ,_["WICComponentDisabled"]:=0x80000000
      ,_["WICCOMPONENTSIGNING_FORCE_DWORD"]:=0x7fffffff
      ,_["WICGifLogicalScreenSignature"]:=0x1
      ,_["WICGifLogicalScreenDescriptorWidth"]:=0x2
      ,_["WICGifLogicalScreenDescriptorHeight"]:=0x3
      ,_["WICGifLogicalScreenDescriptorGlobalColorTableFlag"]:=0x4
      ,_["WICGifLogicalScreenDescriptorColorResolution"]:=0x5
      ,_["WICGifLogicalScreenDescriptorSortFlag"]:=0x6
      ,_["WICGifLogicalScreenDescriptorGlobalColorTableSize"]:=0x7
       _["WICGifLogicalScreenDescriptorBackgroundColorIndex"]:=0x8
      ,_["WICGifLogicalScreenDescriptorPixelAspectRatio"]:=0x9
      ,_["WICGifLogicalScreenDescriptorProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICGifImageDescriptorLeft"]:=0x1
      ,_["WICGifImageDescriptorTop"]:=0x2
      ,_["WICGifImageDescriptorWidth"]:=0x3
      ,_["WICGifImageDescriptorHeight"]:=0x4
      ,_["WICGifImageDescriptorLocalColorTableFlag"]:=0x5
      ,_["WICGifImageDescriptorInterlaceFlag"]:=0x6
      ,_["WICGifImageDescriptorSortFlag"]:=0x7
       _["WICGifImageDescriptorLocalColorTableSize"]:=0x8
      ,_["WICGifImageDescriptorProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICGifGraphicControlExtensionDisposal"]:=0x1
      ,_["WICGifGraphicControlExtensionUserInputFlag"]:=0x2
      ,_["WICGifGraphicControlExtensionTransparencyFlag"]:=0x3
      ,_["WICGifGraphicControlExtensionDelay"]:=0x4
      ,_["WICGifGraphicControlExtensionTransparentColorIndex"]:=0x5
      ,_["WICGifGraphicControlExtensionProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICGifApplicationExtensionApplication"]:=0x1
      ,_["WICGifApplicationExtensionData"]:=0x2
       _["WICGifApplicationExtensionProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICGifCommentExtensionText"]:=0x1
      ,_["WICGifCommentExtensionProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICJpegCommentText"]:=0x1
      ,_["WICJpegCommentProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICJpegLuminanceTable"]:=0x1
      ,_["WICJpegLuminanceProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICJpegChrominanceTable"]:=0x1
      ,_["WICJpegChrominanceProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WIC8BIMIptcPString"]:=0
       _["WIC8BIMIptcEmbeddedIPTC"]:=0x1
      ,_["WIC8BIMIptcProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WIC8BIMResolutionInfoPString"]:=0x1
      ,_["WIC8BIMResolutionInfoHResolution"]:=0x2
      ,_["WIC8BIMResolutionInfoHResolutionUnit"]:=0x3
      ,_["WIC8BIMResolutionInfoWidthUnit"]:=0x4
      ,_["WIC8BIMResolutionInfoVResolution"]:=0x5
      ,_["WIC8BIMResolutionInfoVResolutionUnit"]:=0x6
      ,_["WIC8BIMResolutionInfoHeightUnit"]:=0x7
      ,_["WIC8BIMResolutionInfoProperties_FORCE_DWORD"]:=0x7fffffff
       _["WIC8BIMIptcDigestPString"]:=0x1
      ,_["WIC8BIMIptcDigestIptcDigest"]:=0x2
      ,_["WIC8BIMIptcDigestProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngGamaGamma"]:=0x1
      ,_["WICPngGamaProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngBkgdBackgroundColor"]:=0x1
      ,_["WICPngBkgdProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngItxtKeyword"]:=0x1
      ,_["WICPngItxtCompressionFlag"]:=0x2
      ,_["WICPngItxtLanguageTag"]:=0x3
       _["WICPngItxtTranslatedKeyword"]:=0x4
      ,_["WICPngItxtText"]:=0x5
      ,_["WICPngItxtProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngChrmWhitePointX"]:=0x1
      ,_["WICPngChrmWhitePointY"]:=0x2
      ,_["WICPngChrmRedX"]:=0x3
      ,_["WICPngChrmRedY"]:=0x4
      ,_["WICPngChrmGreenX"]:=0x5
      ,_["WICPngChrmGreenY"]:=0x6
      ,_["WICPngChrmBlueX"]:=0x7
       _["WICPngChrmBlueY"]:=0x8
      ,_["WICPngChrmProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngHistFrequencies"]:=0x1
      ,_["WICPngHistProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngIccpProfileName"]:=0x1
      ,_["WICPngIccpProfileData"]:=0x2
      ,_["WICPngIccpProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngSrgbRenderingIntent"]:=0x1
      ,_["WICPngSrgbProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPngTimeYear"]:=0x1
       _["WICPngTimeMonth"]:=0x2
      ,_["WICPngTimeDay"]:=0x3
      ,_["WICPngTimeHour"]:=0x4
      ,_["WICPngTimeMinute"]:=0x5
      ,_["WICPngTimeSecond"]:=0x6
      ,_["WICPngTimeProperties_FORCE_DWORD"]:=0x7fffffff
      ,_["WICSectionAccessLevelRead"]:=0x1
      ,_["WICSectionAccessLevelReadWrite"]:=0x3
      ,_["WICSectionAccessLevel_FORCE_DWORD"]:=0x7fffffff
      ,_["WICPixelFormatNumericRepresentationUnspecified"]:=0
       _["WICPixelFormatNumericRepresentationIndexed"]:=0x1
      ,_["WICPixelFormatNumericRepresentationUnsignedInteger"]:=0x2
      ,_["WICPixelFormatNumericRepresentationSignedInteger"]:=0x3
      ,_["WICPixelFormatNumericRepresentationFixed"]:=0x4
      ,_["WICPixelFormatNumericRepresentationFloat"]:=0x5
      ,_["WICPixelFormatNumericRepresentation_FORCE_DWORD"]:=0x7fffffff
      ,_["WICTiffCompressionDontCare"]:=0
      ,_["WICTiffCompressionNone"]:=0x1
      ,_["WICTiffCompressionCCITT3"]:=0x2
      ,_["WICTiffCompressionCCITT4"]:=0x3
       _["WICTiffCompressionLZW"]:=0x4
      ,_["WICTiffCompressionRLE"]:=0x5
      ,_["WICTiffCompressionZIP"]:=0x6
      ,_["WICTiffCompressionLZWHDifferencing"]:=0x7
      ,_["WICTIFFCOMPRESSIONOPTION_FORCE_DWORD"]:=0x7fffffff
      ,_["WICJpegYCrCbSubsamplingDefault"]:=0
      ,_["WICJpegYCrCbSubsampling420"]:=0x1
      ,_["WICJpegYCrCbSubsampling422"]:=0x2
      ,_["WICJpegYCrCbSubsampling444"]:=0x3
      ,_["WICJPEGYCRCBSUBSAMPLING_FORCE_DWORD"]:=0x7fffffff
       _["WICPngFilterUnspecified"]:=0
      ,_["WICPngFilterNone"]:=0x1
      ,_["WICPngFilterSub"]:=0x2
      ,_["WICPngFilterUp"]:=0x3
      ,_["WICPngFilterAverage"]:=0x4
      ,_["WICPngFilterPaeth"]:=0x5
      ,_["WICPngFilterAdaptive"]:=0x6
      ,_["WICPNGFILTEROPTION_FORCE_DWORD"]:=0x7fffffff
      ,_["WICWhitePointDefault"]:=0x1
      ,_["WICWhitePointDaylight"]:=0x2
       _["WICWhitePointCloudy"]:=0x4
      ,_["WICWhitePointShade"]:=0x8
      ,_["WICWhitePointTungsten"]:=0x10
      ,_["WICWhitePointFluorescent"]:=0x20
      ,_["WICWhitePointFlash"]:=0x40
      ,_["WICWhitePointUnderwater"]:=0x80
      ,_["WICWhitePointCustom"]:=0x100
      ,_["WICWhitePointAutoWhiteBalance"]:=0x200
      ,_["WICWhitePointAsShot"]:=WICWhitePointDefault
      ,_["WICNAMEDWHITEPOINT_FORCE_DWORD"]:=0x7fffffff
       _["WICRawCapabilityNotSupported"]:=0
      ,_["WICRawCapabilityGetSupported"]:=0x1
      ,_["WICRawCapabilityFullySupported"]:=0x2
      ,_["WICRAWCAPABILITIES_FORCE_DWORD"]:=0x7fffffff
      ,_["WICRawRotationCapabilityNotSupported"]:=0
      ,_["WICRawRotationCapabilityGetSupported"]:=0x1
      ,_["WICRawRotationCapabilityNinetyDegreesSupported"]:=0x2
      ,_["WICRawRotationCapabilityFullySupported"]:=0x3
      ,_["WICRAWROTATIONCAPABILITIES_FORCE_DWORD"]:=0x7fffffff
      ,_["WICAsShotParameterSet"]:=0x1
       _["WICUserAdjustedParameterSet"]:=0x2
      ,_["WICAutoAdjustedParameterSet"]:=0x3
      ,_["WICRAWPARAMETERSET_FORCE_DWORD"]:=0x7fffffff
      ,_["WICRawRenderModeDraft"]:=0x1
      ,_["WICRawRenderModeNormal"]:=0x2
      ,_["WICRawRenderModeBestQuality"]:=0x3
      ,_["WICRAWRENDERMODE_FORCE_DWORD"]:=0x7fffffff
   }

   Return _[type]
}

moreWIC_GUIDs(which) {
   static init:=1,s:=[]
   if init {
      init:=0
      s["sCLSID_WICBmpDecoder"] := "6b462062-7cbf-400d-9fdb-813dd10f2778"
      s["sCLSID_WICPngDecoder"] := "389ea17b-5078-4cde-b6ef-25c15175c751"
      s["sCLSID_WICIcoDecoder"] := "c61bfcdf-2e0f-4aad-a8d7-e06bafebcdfe"
      s["sCLSID_WICJpegDecoder"] := "9456a480-e88b-43ea-9e73-0b2d9b71b1ca"
      s["sCLSID_WICGifDecoder"] := "381dda3c-9ce9-4834-a23e-1f98f8fc52be"
      s["sCLSID_WICTiffDecoder"] := "b54e85d9-fe23-499f-8b88-6acea713752b"
      s["sCLSID_WICWmpDecoder"] := "a26cec36-234c-4950-ae16-e34aace71d0d"
      s["sCLSID_WICBmpEncoder"] := "69be8bb4-d66d-47c8-865a-ed1589433782"
      s["sCLSID_WICPngEncoder"] := "27949969-876a-41d7-9447-568f6a35a4dc"
      s["sCLSID_WICJpegEncoder"] := "1a34f5c1-4a5a-46dc-b644-1f4567e7a676"
      s["sCLSID_WICGifEncoder"] := "114f5598-0b22-40a0-86a1-c83ea495adbd"
      s["sCLSID_WICTiffEncoder"] := "0131be10-2001-4c5f-a9b0-cc88fab64ce8"
      s["sCLSID_WICWmpEncoder"] := "ac4ce3cb-e1c1-44cd-8215-5a1665509ec2"
      s["sCLSID_WICDefaultFormatConverter"] := "1a3f11dc-b514-4b17-8c5f-2154513852f1"
      s["sGUID_ContainerFormatBmp"] := "0af1d87e-fcfe-4188-bdeb-a7906471cbe3"
      s["sGUID_ContainerFormatPng"] := "1b7cfaf4-713f-473c-bbcd-6137425faeaf"
      s["sGUID_ContainerFormatIco"] := "a3a860c4-338f-4c17-919a-fba4b5628f21"
      s["sGUID_ContainerFormatJpeg"] := "19e4a5aa-5662-4fc5-a0c0-1758028e1057"
      s["sGUID_ContainerFormatTiff"] := "163bcc30-e2e9-4f0b-961d-a3e9fdb788a3"
      s["sGUID_ContainerFormatGif"] := "1f8a5601-7d4d-4cbd-9c82-1bc8d4eeb9a5"
      s["sGUID_ContainerFormatWmp"] := "57a37caa-367a-4540-916b-f183c5093a4b"
      s["sGUID_VendorMicrosoft"] := "f0e749ca-edef-4589-a73a-ee0e626a2a2b"
      s["sCATID_WICBitmapDecoders"] := "7ed96837-96f0-4812-b211-f13c24117ed3"
      s["sCATID_WICBitmapEncoders"] := "ac757296-3522-4e11-9862-c17be5a1767e"
      s["sCATID_WICFormatConverters"] := "7835eae8-bf14-49d1-93ce-533a407b2248"
      s["sGUID_WICPixelFormatDontCare"] := "6fddc324-4e03-4bfe-b185-3d77768dc900"
      s["sGUID_WICPixelFormat1bppIndexed"] := "6fddc324-4e03-4bfe-b185-3d77768dc901"
      s["sGUID_WICPixelFormat2bppIndexed"] := "6fddc324-4e03-4bfe-b185-3d77768dc902"
      s["sGUID_WICPixelFormat4bppIndexed"] := "6fddc324-4e03-4bfe-b185-3d77768dc903"
      s["sGUID_WICPixelFormat8bppIndexed"] := "6fddc324-4e03-4bfe-b185-3d77768dc904"
      s["sGUID_WICPixelFormatBlackWhite"] := "6fddc324-4e03-4bfe-b185-3d77768dc905"
      s["sGUID_WICPixelFormat2bppGray"] := "6fddc324-4e03-4bfe-b185-3d77768dc906"
      s["sGUID_WICPixelFormat4bppGray"] := "6fddc324-4e03-4bfe-b185-3d77768dc907"
      s["sGUID_WICPixelFormat8bppGray"] := "6fddc324-4e03-4bfe-b185-3d77768dc908"
      s["sGUID_WICPixelFormat16bppGray"] := "6fddc324-4e03-4bfe-b185-3d77768dc90b"
      s["sGUID_WICPixelFormat16bppBGR555"] := "6fddc324-4e03-4bfe-b185-3d77768dc909"
      s["sGUID_WICPixelFormat16bppBGR565"] := "6fddc324-4e03-4bfe-b185-3d77768dc90a"
      s["sGUID_WICPixelFormat16bppBGRA5551"] := "05ec7c2b-f1e6-4961-ad46-e1cc810a87d2"
      s["sGUID_WICPixelFormat24bppBGR"] := "6fddc324-4e03-4bfe-b185-3d77768dc90c"
      s["sGUID_WICPixelFormat32bppBGR"] := "6fddc324-4e03-4bfe-b185-3d77768dc90e"
      s["sGUID_WICPixelFormat32bppBGRA"] := "6fddc324-4e03-4bfe-b185-3d77768dc90f"
      s["sGUID_WICPixelFormat32bppPBGRA"] := "6fddc324-4e03-4bfe-b185-3d77768dc910"
      s["sGUID_WICPixelFormat48bppRGB"] := "6fddc324-4e03-4bfe-b185-3d77768dc915"
      s["sGUID_WICPixelFormat64bppRGBA"] := "6fddc324-4e03-4bfe-b185-3d77768dc916"
      s["sGUID_WICPixelFormat64bppPRGBA"] := "6fddc324-4e03-4bfe-b185-3d77768dc917"
      s["sGUID_WICPixelFormat32bppCMYK"] := "6fddc324-4e03-4fbe-b185-3d77768dc91c"
      s["sCLSID_WICImagingFactory"] := "cacaf262-9370-4615-a13b-9f5539da4c0a"
      s["sIID_IWICStreamProvider"] := "449494BC-B468-4927-96D7-BA90D31AB505"
      s["sIID_IWICProgressiveLevelControl"] := "DAAC296F-7AA5-4dbf-8D15-225C5976F891"
      s["sIID_IWICProgressCallback"] := "4776F9CD-9517-45FA-BF24-E89C5EC5C60C"
      s["sIID_IWICComponentInfo"] := "23BC3F0A-698B-4357-886B-F24D50671334"
      s["sIID_IWICPixelFormatInfo"] := "E8EDA601-3D48-431a-AB44-69059BE88BBE"
      s["sIID_IWICPixelFormatInfo2"] := "A9DB33A2-AF5F-43C7-B679-74F5984B5AA4"
      s["sIID_IWICPersistStream"] := "00675040-6908-45F8-86A3-49C7DFD6D9AD"
      s["sIID_IWICPalette"] := "00000040-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICMetadataHandlerInfo"] := "ABA958BF-C672-44D1-8D61-CE6DF2E682C2"
      s["sIID_IWICMetadataWriterInfo"] := "B22E3FBA-3925-4323-B5C1-9EBFC430F236"
      s["sIID_IWICMetadataReader"] := "9204FE99-D8FC-4FD5-A001-9536B067A899"
      s["sIID_IWICMetadataWriter"] := "F7836E16-3BE0-470B-86BB-160D0AECD7DE"
      s["sIID_IWICMetadataReaderInfo"] := "EEBF1F5B-07C1-4447-A3AB-22ACAF78A804"
      s["sIID_IWICMetadataQueryReader"] := "30989668-E1C9-4597-B395-458EEDB808DF"
      s["sIID_IWICMetadataQueryWriter"] := "A721791A-0DEF-4d06-BD91-2118BF1DB10B"
      s["sIID_IWICMetadataBlockReader"] := "FEAA2A8D-B3F3-43E4-B25C-D1DE990A1AE1"
      s["sIID_IWICFormatConverterInfo"] := "9F34FB65-13F4-4f15-BC57-3726B5E53D9F"
      s["sIID_IWICMetadataBlockWriter"] := "08FB9676-B444-41E8-8DBE-6A53A542BFF1"
      s["sIID_IWICFastMetadataEncoder"] := "B84E2C09-78C9-4AC4-8BD3-524AE1663A2F"
      s["sIID_IWICEnumMetadataItem"] := "DC2BB46D-3F07-481E-8625-220C4AEDBB33"
      s["sIID_IWICDevelopRawNotificationCallback"] := "95c75a6e-3e8c-4ec2-85a8-aebcc551e59b"
      s["sIID_IWICBitmapSource"] := "00000120-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICBitmapFrameDecode"] := "3B16811B-6A43-4ec9-A813-3D930C13B940"
      s["sIID_IWICDevelopRaw"] := "fbec5e44-f7be-4b65-b7f8-c0c81fef026d"
      s["sIID_IWICImagingFactory"] := "ec5ec8a9-c395-4314-9c77-54d7a935ff70"
      s["sIID_IWICComponentFactory"] := "412D0C3A-9650-44FA-AF5B-DD2A06C8E8FB"
      s["sIID_IWICColorTransform"] := "B66F034F-D0E2-40ab-B436-6DE39E321A94"
      s["sIID_IWICColorContext"] := "3C613A02-34B2-44ea-9A7C-45AEA9C6FD6D"
      s["sIID_IWICBitmapSourceTransform"] := "3B16811B-6A43-4ec9-B713-3D5A0C13B940"
      s["sIID_IWICBitmapCodecInfo"] := "E87A44C4-B76E-4c47-8B09-298EB12A2714"
      s["sIID_IWICBitmapScaler"] := "00000302-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICBitmapLock"] := "00000123-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICBitmapFrameEncode"] := "00000105-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICBitmapFlipRotator"] := "5009834F-2D6A-41ce-9E1B-17C5AFF7A782"
      s["sIID_IWICBitmapEncoderInfo"] := "94C9B4EE-A09F-4f92-8A1E-4A9BCE7E76FB"
      s["sIID_IWICBitmapEncoder"] := "00000103-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICBitmapDecoderInfo"] := "D8CD007F-D08F-4191-9BFC-236EA7F0E4B5"
      s["sIID_IWICBitmapCodecProgressNotification"] := "64C1024E-C3CF-4462-8078-88C2B11C46D9"
      s["sIID_IWICBitmapClipper"] := "E4FBCF03-223D-4e81-9333-D635556DD1B5"
      s["sIID_IWICBitmap"] := "00000121-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICBitmapDecoder"] := "9EDDE9E7-8DEE-47ea-99DF-E6FAF2ED44BF"
      s["sIID_IWICFormatConverter"] := "00000301-a8f2-4877-ba0a-fd2b6645fb94"
      s["sIID_IWICStream"] := "135FF860-22B7-4ddf-B0F6-218F4F299A43"
      s["sIID_IPropertyBag2"] := "22F55882-280B-11d0-A8A9-00A0C90C2004"
   }

   Return s[which]
}

WIC_GUID(ByRef GUID, name) {
   static init:=1,_:={}
   if init
   {
      init:=0
      ; Decoders
       _.CLSID_WICBmpDecoder:=[0x6b462062, 0x7cbf, 0x400d, 0x9f, 0xdb, 0x81, 0x3d, 0xd1, 0xf, 0x27, 0x78]
      ,_.CLSID_WICPngDecoder:=[0x389ea17b, 0x5078, 0x4cde, 0xb6, 0xef, 0x25, 0xc1, 0x51, 0x75, 0xc7, 0x51]
      ,_.CLSID_WICIcoDecoder:=[0xc61bfcdf, 0x2e0f, 0x4aad, 0xa8, 0xd7, 0xe0, 0x6b, 0xaf, 0xeb, 0xcd, 0xfe]
      ,_.CLSID_WICJpegDecoder:=[0x9456a480, 0xe88b, 0x43ea, 0x9e, 0x73, 0xb, 0x2d, 0x9b, 0x71, 0xb1, 0xca]
      ,_.CLSID_WICGifDecoder:=[0x381dda3c, 0x9ce9, 0x4834, 0xa2, 0x3e, 0x1f, 0x98, 0xf8, 0xfc, 0x52, 0xbe]
      ,_.CLSID_WICTiffDecoder:=[0xb54e85d9, 0xfe23, 0x499f, 0x8b, 0x88, 0x6a, 0xce, 0xa7, 0x13, 0x75, 0x2b]
      ,_.CLSID_WICWmpDecoder:=[0xa26cec36, 0x234c, 0x4950, 0xae, 0x16, 0xe3, 0x4a, 0xac, 0xe7, 0x1d, 0x0d]
      ; Encoders
       _.CLSID_WICBmpEncoder:=[0x69be8bb4, 0xd66d, 0x47c8, 0x86, 0x5a, 0xed, 0x15, 0x89, 0x43, 0x37, 0x82]
      ,_.CLSID_WICPngEncoder:=[0x27949969, 0x876a, 0x41d7, 0x94, 0x47, 0x56, 0x8f, 0x6a, 0x35, 0xa4, 0xdc]
      ,_.CLSID_WICJpegEncoder:=[0x1a34f5c1, 0x4a5a, 0x46dc, 0xb6, 0x44, 0x1f, 0x45, 0x67, 0xe7, 0xa6, 0x76]
      ,_.CLSID_WICGifEncoder:=[0x114f5598, 0xb22, 0x40a0, 0x86, 0xa1, 0xc8, 0x3e, 0xa4, 0x95, 0xad, 0xbd]
      ,_.CLSID_WICTiffEncoder:=[0x0131be10, 0x2001, 0x4c5f, 0xa9, 0xb0, 0xcc, 0x88, 0xfa, 0xb6, 0x4c, 0xe8]
      ,_.CLSID_WICWmpEncoder:=[0xac4ce3cb, 0xe1c1, 0x44cd, 0x82, 0x15, 0x5a, 0x16, 0x65, 0x50, 0x9e, 0xc2]
      ; Container Formats
       _.GUID_ContainerFormatBmp:=[0xaf1d87e, 0xfcfe, 0x4188, 0xbd, 0xeb, 0xa7, 0x90, 0x64, 0x71, 0xcb, 0xe3]
      ,_.GUID_ContainerFormatPng:=[0x1b7cfaf4, 0x713f, 0x473c, 0xbb, 0xcd, 0x61, 0x37, 0x42, 0x5f, 0xae, 0xaf]
      ,_.GUID_ContainerFormatIco:=[0xa3a860c4, 0x338f, 0x4c17, 0x91, 0x9a, 0xfb, 0xa4, 0xb5, 0x62, 0x8f, 0x21]
      ,_.GUID_ContainerFormatJpeg:=[0x19e4a5aa, 0x5662, 0x4fc5, 0xa0, 0xc0, 0x17, 0x58, 0x2, 0x8e, 0x10, 0x57]
      ,_.GUID_ContainerFormatTiff:=[0x163bcc30, 0xe2e9, 0x4f0b, 0x96, 0x1d, 0xa3, 0xe9, 0xfd, 0xb7, 0x88, 0xa3]
      ,_.GUID_ContainerFormatGif:=[0x1f8a5601, 0x7d4d, 0x4cbd, 0x9c, 0x82, 0x1b, 0xc8, 0xd4, 0xee, 0xb9, 0xa5]
      ,_.GUID_ContainerFormatWmp:=[0x57a37caa, 0x367a, 0x4540, 0x91, 0x6b, 0xf1, 0x83, 0xc5, 0x09, 0x3a, 0x4b]
      ; Component Identifiers
       _.CLSID_WICImagingCategories:=[0xfae3d380, 0xfea4, 0x4623, 0x8c, 0x75, 0xc6, 0xb6, 0x11, 0x10, 0xb6, 0x81]
      ,_.CATID_WICBitmapDecoders:=[0x7ed96837, 0x96f0, 0x4812, 0xb2, 0x11, 0xf1, 0x3c, 0x24, 0x11, 0x7e, 0xd3]
      ,_.CATID_WICBitmapEncoders:=[0xac757296, 0x3522, 0x4e11, 0x98, 0x62, 0xc1, 0x7b, 0xe5, 0xa1, 0x76, 0x7e]
      ,_.CATID_WICPixelFormats:=[0x2b46e70f, 0xcda7, 0x473e, 0x89, 0xf6, 0xdc, 0x96, 0x30, 0xa2, 0x39, 0x0b]
      ,_.CATID_WICFormatConverters:=[0x7835eae8, 0xbf14, 0x49d1, 0x93, 0xce, 0x53, 0x3a, 0x40, 0x7b, 0x22, 0x48]
      ,_.CATID_WICMetadataReader:=[0x05af94d8, 0x7174, 0x4cd2, 0xbe, 0x4a, 0x41, 0x24, 0xb8, 0x0e, 0xe4, 0xb8]
      ,_.CATID_WICMetadataWriter:=[0xabe3b9a4, 0x257d, 0x4b97, 0xbd, 0x1a, 0x29, 0x4a, 0xf4, 0x96, 0x22, 0x2e]
      ; Format Converters
       _.CLSID_WICDefaultFormatConverter:=[0x1a3f11dc, 0xb514, 0x4b17, 0x8c, 0x5f, 0x21, 0x54, 0x51, 0x38, 0x52, 0xf1]
      ,_.CLSID_WICFormatConverterHighColor:=[0xac75d454, 0x9f37, 0x48f8, 0xb9, 0x72, 0x4e, 0x19, 0xbc, 0x85, 0x60, 0x11]
      ,_.CLSID_WICFormatConverterNChannel:=[0xc17cabb2, 0xd4a3, 0x47d7, 0xa5, 0x57, 0x33, 0x9b, 0x2e, 0xfb, 0xd4, 0xf1]
      ,_.CLSID_WICFormatConverterWMPhoto:=[0x9cb5172b, 0xd600, 0x46ba, 0xab, 0x77, 0x77, 0xbb, 0x7e, 0x3a, 0x00, 0xd9]
      ; Metadata Handlers
       _.GUID_MetadataFormatUnknown:=[0xA45E592F, 0x9078, 0x4A7C, 0xAD, 0xB5, 0x4E, 0xDC, 0x4F, 0xD6, 0x1B, 0x1F]
      ,_.GUID_MetadataFormatIfd:=[0x537396C6, 0x2D8A, 0x4BB6, 0x9B, 0xF8, 0x2F, 0x0A, 0x8E, 0x2A, 0x3A, 0xDF]
      ,_.GUID_MetadataFormatSubIfd:=[0x58A2E128, 0x2DB9, 0x4E57, 0xBB, 0x14, 0x51, 0x77, 0x89, 0x1E, 0xD3, 0x31]
      ,_.GUID_MetadataFormatExif:=[0x1C3C4F9D, 0xB84A, 0x467D, 0x94, 0x93, 0x36, 0xCF, 0xBD, 0x59, 0xEA, 0x57]
      ,_.GUID_MetadataFormatGps:=[0x7134AB8A, 0x9351, 0x44AD, 0xAF, 0x62, 0x44, 0x8D, 0xB6, 0xB5, 0x02, 0xEC]
      ,_.GUID_MetadataFormatInterop:=[0xED686F8E, 0x681F, 0x4C8B, 0xBD, 0x41, 0xA8, 0xAD, 0xDB, 0xF6, 0xB3, 0xFC]
      ,_.GUID_MetadataFormatApp0:=[0x79007028, 0x268D, 0x45d6, 0xA3, 0xC2, 0x35, 0x4E, 0x6A, 0x50, 0x4B, 0xC9]
      ,_.GUID_MetadataFormatApp1:=[0x8FD3DFC3, 0xF951, 0x492B, 0x81, 0x7F, 0x69, 0xC2, 0xE6, 0xD9, 0xA5, 0xB0]
      ,_.GUID_MetadataFormatApp13:=[0x326556A2, 0xF502, 0x4354, 0x9C, 0xC0, 0x8E, 0x3F, 0x48, 0xEA, 0xF6, 0xB5]
      ,_.GUID_MetadataFormatIPTC:=[0x4FAB0914, 0xE129, 0x4087, 0xA1, 0xD1, 0xBC, 0x81, 0x2D, 0x45, 0xA7, 0xB5]
      ,_.GUID_MetadataFormatIRB:=[0x16100D66, 0x8570, 0x4BB9, 0xB9, 0x2D, 0xFD, 0xA4, 0xB2, 0x3E, 0xCE, 0x67]
      ,_.GUID_MetadataFormat8BIMIPTC:=[0x0010568c, 0x0852, 0x4e6a, 0xb1, 0x91, 0x5c, 0x33, 0xac, 0x5b, 0x04, 0x30]
      ,_.GUID_MetadataFormat8BIMResolutionInfo:=[0x739F305D, 0x81DB, 0x43CB, 0xAC, 0x5E, 0x55, 0x01, 0x3E, 0xF9, 0xF0, 0x03]
       _.GUID_MetadataFormat8BIMIPTCDigest:=[0x1CA32285, 0x9CCD, 0x4786, 0x8B, 0xD8, 0x79, 0x53, 0x9D, 0xB6, 0xA0, 0x06]
      ,_.GUID_MetadataFormatXMP:=[0xBB5ACC38, 0xF216, 0x4CEC, 0xA6, 0xC5, 0x5F, 0x6E, 0x73, 0x97, 0x63, 0xA9]
      ,_.GUID_MetadataFormatThumbnail:=[0x243dcee9, 0x8703, 0x40ee, 0x8e, 0xf0, 0x22, 0xa6, 0x0, 0xb8, 0x5, 0x8c]
      ,_.GUID_MetadataFormatChunktEXt:=[0x568d8936, 0xc0a9, 0x4923, 0x90, 0x5d, 0xdf, 0x2b, 0x38, 0x23, 0x8f, 0xbc]
      ,_.GUID_MetadataFormatXMPStruct:=[0x22383CF1, 0xED17, 0x4E2E, 0xAF, 0x17, 0xD8, 0x5B, 0x8F, 0x6B, 0x30, 0xD0]
      ,_.GUID_MetadataFormatXMPBag:=[0x833CCA5F, 0xDCB7, 0x4516, 0x80, 0x6F, 0x65, 0x96, 0xAB, 0x26, 0xDC, 0xE4]
      ,_.GUID_MetadataFormatXMPSeq:=[0x63E8DF02, 0xEB6C,0x456C, 0xA2, 0x24, 0xB2, 0x5E, 0x79, 0x4F, 0xD6, 0x48]
      ,_.GUID_MetadataFormatXMPAlt:=[0x7B08A675, 0x91AA, 0x481B, 0xA7, 0x98, 0x4D, 0xA9, 0x49, 0x08, 0x61, 0x3B]
      ,_.GUID_MetadataFormatLSD:=[0xE256031E, 0x6299, 0x4929, 0xB9, 0x8D, 0x5A, 0xC8, 0x84, 0xAF, 0xBA, 0x92]
      ,_.GUID_MetadataFormatIMD:=[0xBD2BB086, 0x4D52, 0x48DD, 0x96, 0x77, 0xDB, 0x48, 0x3E, 0x85, 0xAE, 0x8F]
      ,_.GUID_MetadataFormatGCE:=[0x2A25CAD8, 0xDEEB, 0x4C69, 0xA7, 0x88, 0xE, 0xC2, 0x26, 0x6D, 0xCA, 0xFD]
      ,_.GUID_MetadataFormatAPE:=[0x2E043DC2, 0xC967, 0x4E05, 0x87, 0x5E, 0x61, 0x8B, 0xF6, 0x7E, 0x85, 0xC3]
       _.GUID_MetadataFormatJpegChrominance:=[0xF73D0DCF, 0xCEC6, 0x4F85, 0x9B, 0x0E, 0x1C, 0x39, 0x56, 0xB1, 0xBE, 0xF7]
      ,_.GUID_MetadataFormatJpegLuminance:=[0x86908007, 0xEDFC, 0x4860, 0x8D, 0x4B, 0x4E, 0xE6, 0xE8, 0x3E, 0x60, 0x58]
      ,_.GUID_MetadataFormatJpegComment:=[0x220E5F33, 0xAFD3, 0x474E, 0x9D, 0x31, 0x7D, 0x4F, 0xE7, 0x30, 0xF5, 0x57]
      ,_.GUID_MetadataFormatGifComment:=[0xC4B6E0E0, 0xCFB4, 0x4AD3, 0xAB, 0x33, 0x9A, 0xAD, 0x23, 0x55, 0xA3, 0x4A]
      ,_.GUID_MetadataFormatChunkgAMA:=[0xF00935A5, 0x1D5D, 0x4CD1, 0x81, 0xB2, 0x93, 0x24, 0xD7, 0xEC, 0xA7, 0x81]
      ,_.GUID_MetadataFormatChunkbKGD:=[0xE14D3571, 0x6B47, 0x4DEA, 0xB6, 0xA, 0x87, 0xCE, 0xA, 0x78, 0xDF, 0xB7]
      ,_.GUID_MetadataFormatChunkiTXt:=[0xC2BEC729, 0xB68, 0x4B77, 0xAA, 0xE, 0x62, 0x95, 0xA6, 0xAC, 0x18, 0x14]
      ,_.GUID_MetadataFormatChunkcHRM:=[0x9DB3655B, 0x2842, 0x44B3, 0x80, 0x67, 0x12, 0xE9, 0xB3, 0x75, 0x55, 0x6A]
      ,_.GUID_MetadataFormatChunkhIST:=[0xC59A82DA, 0xDB74, 0x48A4, 0xBD, 0x6A, 0xB6, 0x9C, 0x49, 0x31, 0xEF, 0x95]
      ,_.GUID_MetadataFormatChunkiCCP:=[0xEB4349AB, 0xB685, 0x450F, 0x91, 0xB5, 0xE8, 0x2, 0xE8, 0x92, 0x53, 0x6C]
      ,_.GUID_MetadataFormatChunksRGB:=[0xC115FD36, 0xCC6F, 0x4E3F, 0x83, 0x63, 0x52, 0x4B, 0x87, 0xC6, 0xB0, 0xD9]
      ,_.GUID_MetadataFormatChunktIME:=[0x6B00AE2D, 0xE24B, 0x460A, 0x98, 0xB6, 0x87, 0x8B, 0xD0, 0x30, 0x72, 0xFD]
      ; Vendor Identification
       _.GUID_VendorMicrosoft:=[0x69fd0fdc, 0xa866, 0x4108, 0xb3, 0xb2, 0x98, 0x44, 0x7f, 0xa9, 0xed, 0xd4]
      ,_.GUID_VendorMicrosoftBuiltIn:=[0x257a30fd, 0x6b6, 0x462b, 0xae, 0xa4, 0x63, 0xf7, 0xb, 0x86, 0xe5, 0x33]
      ; WICBitmapPaletteType
       _.GUID_WICPixelFormatDontCare:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x00]
      ,_.GUID_WICPixelFormat1bppIndexed:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x01]
      ,_.GUID_WICPixelFormat2bppIndexed:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x02]
      ,_.GUID_WICPixelFormat4bppIndexed:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x03]
      ,_.GUID_WICPixelFormat8bppIndexed:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x04]
      ,_.GUID_WICPixelFormatBlackWhite:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x05]
      ,_.GUID_WICPixelFormat2bppGray:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x06]
      ,_.GUID_WICPixelFormat4bppGray:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x07]
      ,_.GUID_WICPixelFormat8bppGray:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x08]
      ,_.GUID_WICPixelFormat8bppAlpha:=[0xe6cd0116, 0xeeba, 0x4161, 0xaa, 0x85, 0x27, 0xdd, 0x9f, 0xb3, 0xa8, 0x95]
      ,_.GUID_WICPixelFormat16bppBGR555:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x09]
      ,_.GUID_WICPixelFormat16bppBGR565:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0a]
      ,_.GUID_WICPixelFormat16bppBGRA5551:=[0x05ec7c2b, 0xf1e6, 0x4961, 0xad, 0x46, 0xe1, 0xcc, 0x81, 0x0a, 0x87, 0xd2]
       _.GUID_WICPixelFormat16bppGray:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0b]
      ,_.GUID_WICPixelFormat24bppBGR:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0c]
      ,_.GUID_WICPixelFormat24bppRGB:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0d]
      ,_.GUID_WICPixelFormat32bppBGR:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0e]
      ,_.GUID_WICPixelFormat32bppBGRA:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0f]
      ,_.GUID_WICPixelFormat32bppPBGRA:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x10]
      ,_.GUID_WICPixelFormat32bppGrayFloat:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x11]
      ,_.GUID_WICPixelFormat32bppRGBA:=[0xf5c7ad2d, 0x6a8d, 0x43dd, 0xa7, 0xa8, 0xa2, 0x99, 0x35, 0x26, 0x1a, 0xe9]
      ,_.GUID_WICPixelFormat32bppPRGBA:=[0x3cc4a650, 0xa527, 0x4d37, 0xa9, 0x16, 0x31, 0x42, 0xc7, 0xeb, 0xed, 0xba]
      ,_.GUID_WICPixelFormat48bppRGB:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x15]
      ,_.GUID_WICPixelFormat48bppBGR:=[0xe605a384, 0xb468, 0x46ce, 0xbb, 0x2e, 0x36, 0xf1, 0x80, 0xe6, 0x43, 0x13]
      ,_.GUID_WICPixelFormat64bppRGBA:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x16]
      ,_.GUID_WICPixelFormat64bppBGRA:=[0x1562ff7c, 0xd352, 0x46f9, 0x97, 0x9e, 0x42, 0x97, 0x6b, 0x79, 0x22, 0x46]
       _.GUID_WICPixelFormat64bppPRGBA:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x17]
      ,_.GUID_WICPixelFormat64bppPBGRA:=[0x8c518e8e, 0xa4ec, 0x468b, 0xae, 0x70, 0xc9, 0xa3, 0x5a, 0x9c, 0x55, 0x30]
      ,_.GUID_WICPixelFormat16bppGrayFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x13]
      ,_.GUID_WICPixelFormat32bppBGR101010:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x14]
      ,_.GUID_WICPixelFormat48bppRGBFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x12]
      ,_.GUID_WICPixelFormat48bppBGRFixedPoint:=[0x49ca140e, 0xcab6, 0x493b, 0x9d, 0xdf, 0x60, 0x18, 0x7c, 0x37, 0x53, 0x2a]
      ,_.GUID_WICPixelFormat96bppRGBFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x18]
      ,_.GUID_WICPixelFormat128bppRGBAFloat:=[ 0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x19]
      ,_.GUID_WICPixelFormat128bppPRGBAFloat:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x1a]
      ,_.GUID_WICPixelFormat128bppRGBFloat:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x1b]
      ,_.GUID_WICPixelFormat32bppCMYK:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x1c]
      ,_.GUID_WICPixelFormat64bppRGBAFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x1d]
      ,_.GUID_WICPixelFormat64bppBGRAFixedPoint:=[0x356de33c, 0x54d2, 0x4a23, 0xbb, 0x4, 0x9b, 0x7b, 0xf9, 0xb1, 0xd4, 0x2d]
       _.GUID_WICPixelFormat64bppRGBFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x40]
      ,_.GUID_WICPixelFormat128bppRGBAFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x1e]
      ,_.GUID_WICPixelFormat128bppRGBFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x41]
      ,_.GUID_WICPixelFormat64bppRGBAHalf:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x3a]
      ,_.GUID_WICPixelFormat64bppRGBHalf:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x42]
      ,_.GUID_WICPixelFormat48bppRGBHalf:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x3b]
      ,_.GUID_WICPixelFormat32bppRGBE:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x3d]
      ,_.GUID_WICPixelFormat16bppGrayHalf:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x3e]
      ,_.GUID_WICPixelFormat32bppGrayFixedPoint:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x3f]
      ,_.GUID_WICPixelFormat32bppRGBA1010102:=[0x25238D72, 0xFCF9, 0x4522, 0xb5, 0x14, 0x55, 0x78, 0xe5, 0xad, 0x55, 0xe0]
      ,_.GUID_WICPixelFormat32bppRGBA1010102XR:=[0x00DE6B9A, 0xC101, 0x434b, 0xb5, 0x02, 0xd0, 0x16, 0x5e, 0xe1, 0x12, 0x2c]
      ,_.GUID_WICPixelFormat64bppCMYK:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x1f]
      ,_.GUID_WICPixelFormat24bpp3Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x20]
       _.GUID_WICPixelFormat32bpp4Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x21]
      ,_.GUID_WICPixelFormat40bpp5Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x22]
      ,_.GUID_WICPixelFormat48bpp6Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x23]
      ,_.GUID_WICPixelFormat56bpp7Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x24]
      ,_.GUID_WICPixelFormat64bpp8Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x25]
      ,_.GUID_WICPixelFormat48bpp3Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x26]
      ,_.GUID_WICPixelFormat64bpp4Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x27]
      ,_.GUID_WICPixelFormat80bpp5Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x28]
      ,_.GUID_WICPixelFormat96bpp6Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x29]
      ,_.GUID_WICPixelFormat112bpp7Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x2a]
      ,_.GUID_WICPixelFormat128bpp8Channels:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x2b]
      ,_.GUID_WICPixelFormat40bppCMYKAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x2c]
      ,_.GUID_WICPixelFormat80bppCMYKAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x2d]
      ,_.GUID_WICPixelFormat32bpp3ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x2e]
       _.GUID_WICPixelFormat40bpp4ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x2f]
      ,_.GUID_WICPixelFormat48bpp5ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x30]
      ,_.GUID_WICPixelFormat56bpp6ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x31]
      ,_.GUID_WICPixelFormat64bpp7ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x32]
      ,_.GUID_WICPixelFormat72bpp8ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x33]
      ,_.GUID_WICPixelFormat64bpp3ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x34]
      ,_.GUID_WICPixelFormat80bpp4ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x35]
      ,_.GUID_WICPixelFormat96bpp5ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x36]
      ,_.GUID_WICPixelFormat112bpp6ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x37]
      ,_.GUID_WICPixelFormat128bpp7ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x38]
      ,_.GUID_WICPixelFormat144bpp8ChannelsAlpha:=[0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x39]
   }

   if _.haskey(name)
   {
      p:=_[name]
      VarSetCapacity(GUID,16)
      ,NumPut(p.1+(p.2<<32)+(p.3<<48),GUID,0,"int64")
      ,NumPut(p.4+(p.5<<8)+(p.6<<16)+(p.7<<24)+(p.8<<32)+(p.9<<40)+(p.10<<48)+(p.11<<56),GUID,8,"int64")
      return &GUID
   } else return name
}

WIC_hr(hr, errlvl, funcName) {
; wic error codes
   static init:=1, debugMode:=0, err:={}

   If init
   {
      init:=0
       err[0x80004005]:="WINCODEC_ERR_GENERIC_ERROR"
      ,err[0x88982f51]:="WINCODEC_ERR_IMAGESIZEOUTOFRANGE"
      ,err[0x80004001]:="WINCODEC_ERR_NOTIMPLEMENTED"
      ,err[0x80004004]:="WINCODEC_ERR_ABORTED"
      ,err[0x8000FFFF]:="WINCODEC_ERR: Catastrophic failure error."
      ,err[0x80004002]:="WINCODEC_ERR: Interface not supported error."
      ,err[0x80004003]:="WINCODEC_ERR: Pointer not valid error."
      ,err[0x80070006]:="WINCODEC_ERR: Handle not valid error."
      ,err[0x800401E5]:="WINCODEC_ERR: The object identified by this moniker could not be found."
      ,err[0x80070005]:="WINCODEC_ERR_ACCESSDENIED"
      ,err[0x8007000E]:="WINCODEC_ERR_OUTOFMEMORY"
      ,err[0x80070057]:="WINCODEC_ERR_INVALIDPARAMETER"
      ,err[0x88982f04]:="WINCODEC_ERR_WRONGSTATE"
      ,err[0x88982f05]:="WINCODEC_ERR_VALUEOUTOFRANGE"
      ,err[0x88982f07]:="WINCODEC_ERR_UNKNOWNIMAGEFORMAT"
      ,err[0x88982f0B]:="WINCODEC_ERR_UNSUPPORTEDVERSION"
      ,err[0x88982f0C]:="WINCODEC_ERR_NOTINITIALIZED"
      ,err[0x88982f0D]:="WINCODEC_ERR_ALREADYLOCKED"
      ,err[0x88982f40]:="WINCODEC_ERR_PROPERTYNOTFOUND"
      ,err[0x88982f41]:="WINCODEC_ERR_PROPERTYNOTSUPPORTED"
      ,err[0x88982f42]:="WINCODEC_ERR_PROPERTYSIZE"
      ,err[0x88982f43]:="WINCODEC_ERR_CODECPRESENT"
      ,err[0x88982f44]:="WINCODEC_ERR_CODECNOTHUMBNAIL"
      ,err[0x88982f45]:="WINCODEC_ERR_PALETTEUNAVAILABLE"
      ,err[0x88982f46]:="WINCODEC_ERR_CODECTOOMANYSCANLINES"
      ,err[0x88982f48]:="WINCODEC_ERR_INTERNALERROR"
      ,err[0x88982f49]:="WINCODEC_ERR_SOURCERECTDOESNOTMATCHDIMENSIONS"
      ,err[0x88982f50]:="WINCODEC_ERR_COMPONENTNOTFOUND"
      ,err[0x88982f52]:="WINCODEC_ERR_TOOMUCHMETADATA"
      ,err[0x88982f60]:="WINCODEC_ERR_BADIMAGE"
      ,err[0x88982f61]:="WINCODEC_ERR_BADHEADER"
      ,err[0x88982f62]:="WINCODEC_ERR_FRAMEMISSING"
      ,err[0x88982f63]:="WINCODEC_ERR_BADMETADATAHEADER"
      ,err[0x88982f70]:="WINCODEC_ERR_BADSTREAMDATA"
      ,err[0x88982f71]:="WINCODEC_ERR_STREAMWRITE"
      ,err[0x88982f72]:="WINCODEC_ERR_STREAMREAD"
      ,err[0x88982f73]:="WINCODEC_ERR_STREAMNOTAVAILABLE"
      ,err[0x88982f80]:="WINCODEC_ERR_UNSUPPORTEDPIXELFORMAT"
      ,err[0x88982f81]:="WINCODEC_ERR_UNSUPPORTEDOPERATION"
      ,err[0x88982f8A]:="WINCODEC_ERR_INVALIDREGISTRATION"
      ,err[0x88982f8B]:="WINCODEC_ERR_COMPONENTINITIALIZEFAILURE"
      ,err[0x88982f8C]:="WINCODEC_ERR_INSUFFICIENTBUFFER"
      ,err[0x88982f8D]:="WINCODEC_ERR_DUPLICATEMETADATAPRESENT"
      ,err[0x88982f8E]:="WINCODEC_ERR_PROPERTYUNEXPECTEDTYPE"
      ,err[0x88982f8F]:="WINCODEC_ERR_UNEXPECTEDSIZE"
      ,err[0x88982f90]:="WINCODEC_ERR_INVALIDQUERYREQUEST"
      ,err[0x88982f91]:="WINCODEC_ERR_UNEXPECTEDMETADATATYPE"
      ,err[0x88982f92]:="WINCODEC_ERR_REQUESTONLYVALIDATMETADATAROOT"
      ,err[0x88982f93]:="WINCODEC_ERR_INVALIDQUERYCHARACTER"
   }

   If (hr="debug")
      debugMode := 1
   Else If (hr="silent")
      debugMode := 0

   If (hr && (hr&=0xFFFFFFFF))
      r := err.haskey(hr) ? err[hr] : a

   If (r || errlvl) && (debugMode=1)
      msgbox, % r "`n" errlvl "`n" funcName

   Return r ? r "`n" funcName : a
}


/*
Classes implemented:
 - IWICBitmap(ppIBitmap)
 - IWICBitmapClipper(ppIBitmapClipper)
 - IWICBitmapDecoder(ppIDecoder)
 - IWICBitmapEncoder(ppIEncoder)
 - IWICBitmapFlipRotator(ppIBitmapFlipRotator)
 - IWICBitmapFrameDecode(ppIBitmapFrame)
 - IWICBitmapScaler(ppIBitmapScaler)
 - IWICBitmapSource(ppIBitmapSource)
 - IWICColorTransform(IWICColorTransform)
 - IWICFormatConverter(ppIFormatConverter)
 - IWICMetadataQueryReader(ppIMetadataQueryReader)
 - IWICMetadataQueryWriter(ppIQueryWriter)
 - IWICStream(ppIWICStream)

Classes not yet implemented:
 - IWICBitmapDecoderInfo(ppIDecoderInfo)
 - IWICBitmapEncoderInfo(ppIEncoderInfo)
 - IWICBitmapFrameEncode(ppIFrameEncode)
 - IWICColorContext(ppIWICColorContext)
 - IWICComponentInfo(ppIInfo)
 - IWICFastMetadataEncoder(ppIFastEncoder)
 - IWICPalette(ppIPalette)
*/

vtable(ptr, n) {
    ; NumGet(ptr+0) returns the address of the object's virtual function
    ; table (vtable for short). The remainder of the expression retrieves
    ; the address of the nth function's address from the vtable.
    return NumGet(NumGet(ptr+0), n*A_PtrSize)
}
