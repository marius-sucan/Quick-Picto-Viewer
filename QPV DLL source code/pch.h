// pch.h: the system and third-party headers, compiled once into the precompiled header every .cpp
// of the DLL starts with [/Yu]. The project's own headers stay out: an edit to anything here rebuilds it.
// /Yu skips whatever comes before #include "pch.h", so the macros these headers read [GDIPVER,
// cimg_use_openmp] are defined here.

#ifndef PCH_H
#define PCH_H

#include "framework.h"
#include <wchar.h>
#include "omp.h"
#include "math.h"
#include "windows.h"
#include <string>
#include <vector>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <stack>
#include <map>
#include <unordered_set>
#include <unordered_map>
#include <list>
#include <array>
#include <cstdint>
#include <cstdio>
#include <chrono>   // steady_clock, for the duplicate sweep's time budget
#include <new>      // std::bad_alloc, thrown by the candidate-set allocation
#include <numeric>
#include <algorithm>
#include <emmintrin.h> // SSE2 intrinsics for CalculateNewBlendModes
#if defined(_MSC_VER)
#include <intrin.h>
#endif
#include <d2d1.h>
#include <d2d1_3.h>
#include <wincodec.h>
#include <shlwapi.h>
#include "Tchar.h"
#define GDIPVER 0x110
#include <gdiplus.h>
#include <gdiplusflat.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <locale>
#include <codecvt>
#define cimg_use_openmp 1
#include "includes\CImg-3.4.3\CImg.h"
// #include <opencv2/opencv.hpp>
#include "includes\opencv2\opencv.hpp"
#include "includes\pdfium\fpdfview.h"
#include "includes\pdfium\fpdf_text.h"
#include "includes\pdfium\fpdf_annot.h"
#include "includes\pdfium\fpdf_doc.h"
#include "includes\pdfium\fpdf_edit.h"

#endif //PCH_H
