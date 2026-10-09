// selection-mask.h
//
// The selection every effect clips to: the state prepareSelectionArea() sets, the rectangle
// and ellipse test, the polygon and line masks, and clipMaskFilter().
//
// #included by qpv-main.cpp right after CalcPixOffset(), ahead of every effect and of
// flood-fill.h, which read this state.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_SELECTION_MASK_H
#define QPV_SELECTION_MASK_H

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <new>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

float imgSelExclW = 0.0f;
float imgSelExclH = 0.0f;
float imgSelExclX = 0.0f;
float imgSelExclY = 0.0f;
int imgSelX1 = 0;
int imgSelY1 = 0;
int imgSelX2 = 0;
int imgSelY2 = 0;
int EllipseSelectMode = 0;
int flippedSelection = 0;
int invertSelection = 0;
int highDepthModeMask = 0;
float excludeSelectScale = 0;
float vpSelRotation = 0;
float cosVPselRotation = 0;
float sinVPselRotation = 0;
float hImgSelW = 0.0f;
float hImgSelH = 0.0f;
float imgSelXscale = 0.0f;
float imgSelYscale = 0.0f;
INT64 polyW = 0;
INT64 polyH = 0;
INT64 polyX = 0;
INT64 polyY = 0;
INT64 polyOffYa = 0;
INT64 polyOffYb = 0;

class MaskBitMap {
private:
    std::vector<uint64_t> data;
    size_t num_bits = 0;

public:
    void resize(size_t size) {
        // a failed allocation must leave size() at 0: MSVC's assign() frees the old buffer first
        num_bits = 0;
        data.assign((size + 63) / 64, 0ULL);
        num_bits = size;
    }

    void clear() {
        data.clear();
        num_bits = 0;
    }

    void shrink_to_fit() {
        data.shrink_to_fit();
    }

    size_t size() const {
        return num_bits;
    }

    const uint64_t* words() const {
        return data.data();
    }

    size_t word_count() const {
        return data.size();
    }

    struct Reference {
        uint64_t* word;
        uint64_t mask;

        Reference(uint64_t* w, uint64_t m) : word(w), mask(m) {}

        Reference& operator=(bool val) {
            auto* atomic_word = reinterpret_cast<std::atomic<uint64_t>*>(word);
            if (val) {
                atomic_word->fetch_or(mask, std::memory_order_relaxed);
            } else {
                atomic_word->fetch_and(~mask, std::memory_order_relaxed);
            }
            return *this;
        }

        Reference& operator=(const Reference& other) {
            return operator=(bool(other));
        }

        operator bool() const {
            return (*word & mask) != 0;
        }
    };

    Reference operator[](size_t idx) {
        return Reference(&data[idx / 64], 1ULL << (idx % 64));
    }

    bool operator[](size_t idx) const {
        return (data[idx / 64] & (1ULL << (idx % 64))) != 0;
    }

    void set_unsafe(size_t idx) {
        data[idx / 64] |= (1ULL << (idx % 64));
    }

    void fill_zero() {
        std::fill(data.begin(), data.end(), 0ULL);
    }

    void fill_zero(size_t start, size_t end) {
        if (start >= end) return;
        size_t start_word = start / 64;
        size_t end_word = (end - 1) / 64;

        if (start_word == end_word) {
            uint64_t mask = (~0ULL << (start % 64)) & (~0ULL >> (63 - ((end - 1) % 64)));
            auto* atomic_word = reinterpret_cast<std::atomic<uint64_t>*>(&data[start_word]);
            atomic_word->fetch_and(~mask, std::memory_order_relaxed);
        } else {
            // First word (partial)
            uint64_t start_mask = (~0ULL << (start % 64));
            reinterpret_cast<std::atomic<uint64_t>*>(&data[start_word])->fetch_and(~start_mask, std::memory_order_relaxed);

            // Middle words (full)
            for (size_t w = start_word + 1; w < end_word; ++w) {
                data[w] = 0ULL;
            }

            // Last word (partial)
            uint64_t end_mask = (~0ULL >> (63 - ((end - 1) % 64)));
            reinterpret_cast<std::atomic<uint64_t>*>(&data[end_word])->fetch_and(~end_mask, std::memory_order_relaxed);
        }
    }

    void set_range_to_1(size_t start, size_t end) {
        if (start > end) return;
        size_t start_word = start / 64;
        size_t end_word = end / 64;

        if (start_word == end_word) {
            uint64_t mask = (~0ULL << (start % 64)) & (~0ULL >> (63 - (end % 64)));
            auto* atomic_word = reinterpret_cast<std::atomic<uint64_t>*>(&data[start_word]);
            atomic_word->fetch_or(mask, std::memory_order_relaxed);
        } else {
            // First word (partial)
            uint64_t start_mask = (~0ULL << (start % 64));
            reinterpret_cast<std::atomic<uint64_t>*>(&data[start_word])->fetch_or(start_mask, std::memory_order_relaxed);

            // Middle words (full)
            for (size_t w = start_word + 1; w < end_word; ++w) {
                data[w] = ~0ULL;
            }

            // Last word (partial)
            uint64_t end_mask = (~0ULL >> (63 - (end % 64)));
            reinterpret_cast<std::atomic<uint64_t>*>(&data[end_word])->fetch_or(end_mask, std::memory_order_relaxed);
        }
    }
};

std::vector<unsigned char>  highDephMaskMap;
MaskBitMap  polygonMaskMap;
MaskBitMap  polygonOtherMaskMap;
// vector<pair<int, int>> DrawLineGrid;

struct Point {
    double x, y;
};

bool isInsideRectOval(const float &ox, const float &oy, const int &modus) {
    // Translate the coordinates
    const float tw = (modus==2) ? imgSelExclW : hImgSelW;
    const float th = (modus==2) ? imgSelExclH : hImgSelH;
    float x = (modus==2) ? ox - tw - imgSelExclX : ox - tw;
    float y = (modus==2) ? oy - th - imgSelExclY : oy - th;
    x *= imgSelXscale;
    y *= imgSelYscale;

    // Apply rotation to the coordinates
    float rotatedX, rotatedY;
    if (flippedSelection==1)
    {
       rotatedX = x * cosVPselRotation + y * sinVPselRotation;
       rotatedY = x * sinVPselRotation - y * cosVPselRotation;
    } else
    {
       rotatedX = x * cosVPselRotation - y * sinVPselRotation;
       rotatedY = x * sinVPselRotation + y * cosVPselRotation;
    }

    bool f;
    if (EllipseSelectMode==1)
    {
       const float result = (rotatedX * rotatedX) / (tw * tw) + (rotatedY * rotatedY) / (th * th);
       f = (result <= 1.0f);
    } else
    {
       f = ((fabs(rotatedX) < tw) && (fabs(rotatedY) < th));
    }

    if (f && modus==1 && excludeSelectScale!=0)
    {
       bool nf = isInsideRectOval(ox, oy, 2);
       return (f && nf) ? 0 : 1;
    }

    return f;
}

void bresenham_line_algo(const int &w, const int &h, int x0, int y0, const int &x1, const int &y1, std::vector<int> &polygonMapMin) {
// based on https://zingl.github.io/bresenham.html
//          https://github.com/zingl/Bresenham
// by Zingl Alois

   const int dx =  abs(x1-x0), sx = (x0<x1) ? 1 : -1;
   const int dy = -abs(y1-y0), sy = (y0<y1) ? 1 : -1;
   int err = dx + dy, e2;                              /* error value e_xy */

   for (;;)
   {                                             /* loop */
      if (y0>=0 && y0<=h)
      {
         // polygonMapMax[y0] = max(polygonMapMax[y0], x0);
         polygonMapMin[y0] = min(polygonMapMin[y0], x0);
         // fnOutputDebug("maxu=" + std::to_string(polygonMapMax[y0]) + " | minu=" + std::to_string(polygonMapMin[y0]));
         if (x0 >= polyX && x0 < polyX + polyW && y0 >= polyY && y0 < polyY + polyH)
            polygonMaskMap[(UINT64)(y0 - polyY) * polyW + (x0 - polyX)] = 1;
      }

      if (x0 == x1 && y0 == y1)
         break;

      e2 = 2*err;
      if (e2 >= dy) { err += dy; x0 += sx; }                        /* x step */
      if (e2 <= dx) { err += dx; y0 += sy; }                        /* y step */
   }
}

bool initBoolMaskData() {
    INT64 s = (INT64)polyW * polyH + 2;
    if (s!=polygonMaskMap.size())
    {
       try
       {
          polygonMaskMap.resize(s);
       } catch(const std::bad_alloc& e)
       {
          EllipseSelectMode = 0;
          fnOutputDebug("polygonMaskMap failed. bad_alloc =" + std::to_string(s));
          return 0;
       } catch(const std::length_error& e)
       {
          EllipseSelectMode = 0;
          fnOutputDebug("polygonMaskMap failed. length_error =" + std::to_string(s));
          return 0;
       }
       fnOutputDebug("polygonMaskMap RESIZED=" + std::to_string(s) + "||" + std::to_string(polygonMaskMap.size()));
    } else
    {
       fnOutputDebug("polygonMaskMap size=" + std::to_string(s) + "||" + std::to_string(polygonMaskMap.size()));
    }

    polygonMaskMap.fill_zero();
    // fnOutputDebug("polygonMaskMap refilled to zero ; size = " + std::to_string(s) + "|" + std::to_string(polyW) + " x " + std::to_string(polyH) + "|" + std::to_string(polyX) + " x " + std::to_string(polyY));
    return 1;
}
inline bool isPointInPolygonOptimized(const INT64 pX, const INT64 pY, const float* PointsList, const std::vector<int>& activeEdges, const int PointsCount) {
    bool inside = false;
    for (int i : activeEdges)
    {
        int j = i - 2;
        if (j < 0)
            j = PointsCount * 2 - 2;

        const double xi = PointsList[i];
        const double yi = PointsList[i + 1];
        const double xj = PointsList[j];
        const double yj = PointsList[j + 1];

        if (pX < (xj - xi) * (pY - yi) / (yj - yi) + xi)
            inside = !inside;
    }
    return inside;
}

void traceMaskPolyBoundaries(const int &w, const int &h, const float* PointsList, const int &PointsCount, const int &ppx1, const int &ppy1, const int &ppx2, const int &ppy2, std::vector<std::vector<int>> &polygonMapEdges, std::vector<int> &polygonMapMin) {
    int i = 2;
    int xa = PointsList[0];
    int ya = PointsList[1];
    
    // do not shrink below the caller's sizing: FillMaskPolygon() sized this to
    // max(boundMaxY, h) + 1 because edges (and bresenham_line_algo's y0<=h guard)
    // can touch row h and beyond
    polygonMapMin.assign(max((size_t)h + 1, polygonMapMin.size()), INT_MAX);
    for (int pts = 0; pts < PointsCount; pts++)
    {
        int xb, yb;
        if (pts == PointsCount - 1)
        {
           xb = PointsList[0];
           yb = PointsList[1];
        } else
        {
           xb = PointsList[i];
           i++;
           yb = PointsList[i];
           i++;
        }

        if (max(ya, yb) < ppy1 || min(ya, yb) >= ppy2)
        {
           xa = xb;
           ya = yb;
           continue;
        }

        bresenham_line_algo(w, h, xa, ya, xb, yb, polygonMapMin);
        int maxu = (max(ya, yb) >= ppy2) ? ppy2 - 1 : max(ya, yb);
        int minu = (min(ya, yb) <= ppy1) ? ppy1 : min(ya, yb);
        if (minu < 0)
           minu = 0;
        for (int yy = minu; yy <= maxu; yy++)
        {
            if (polygonMapMin[yy]!=INT_MAX)
               polygonMapEdges[yy].push_back( polygonMapMin[yy] );
        }

        // Reset only the modified range of polygonMapMin back to INT_MAX
        for (int yy = minu; yy <= maxu; yy++)
        {
            polygonMapMin[yy] = INT_MAX;
        }

        // a tip pointing right has both runs starting left of it: the vertex is a crossing too
        if (ya >= minu && ya <= maxu)
           polygonMapEdges[ya].push_back(xa);

        xa = xb;
        ya = yb;
    }
}

void fillMaskPolyBounds(const int &w, const int &h, const float* PointsList, const int &PointsCount, const int &ppx1, const int &ppy1, const int &ppx2, const int &ppy2, const bool &simpleMode, std::vector<std::vector<int>> &polygonMapEdges) {
    // 1. Pre-calculate active edge counts to avoid reallocations
    std::vector<int> counts(h, 0);
    for (int i = 0; i < PointsCount * 2; i += 2)
    {
        int j = i - 2;
        if (j < 0)
            j = PointsCount * 2 - 2;

        int y_min = min((int)PointsList[i + 1], (int)PointsList[j + 1]);
        int y_max = max((int)PointsList[i + 1], (int)PointsList[j + 1]);
        int start_y = max(0, y_min);
        int end_y = min(h - 1, y_max - 1);
        for (int y = start_y; y <= end_y; ++y)
            counts[y]++;
    }

    // 2. Build Active Edge Index per scanline
    std::vector<std::vector<int>> crossingEdges(h);
    for (int y = 0; y < h; ++y)
    {
        crossingEdges[y].reserve(counts[y]);
    }

    for (int i = 0; i < PointsCount * 2; i += 2)
    {
        int j = i - 2;
        if (j < 0)
            j = PointsCount * 2 - 2;

        int y_min = min((int)PointsList[i + 1], (int)PointsList[j + 1]);
        int y_max = max((int)PointsList[i + 1], (int)PointsList[j + 1]);
        int start_y = max(0, y_min);
        int end_y = min(h - 1, y_max - 1);
        for (int y = start_y; y <= end_y; ++y)
        {
            crossingEdges[y].push_back(i);
        }
    }

    #pragma omp parallel for schedule(dynamic) default(none) shared(polygonMapEdges, crossingEdges, PointsList, ppy1, ppy2, ppx1, ppx2, simpleMode, PointsCount, polyY, polyW, polyX, polygonMaskMap)
    for (int y = 0; y < h; ++y)
    {
        if (polygonMapEdges[y].empty())
           continue;

        if (y < ppy1 || y >= ppy2)
           continue;

        std::vector<int>& listu = polygonMapEdges[y];
        
        // Sort and deduplicate in-place
        sort(listu.begin(), listu.end());
        listu.erase(unique(listu.begin(), listu.end()), listu.end());
        if (listu.empty() || listu.size() == 1)
           continue;

        const std::vector<int>& activeEdges = crossingEdges[y];
        for (INT64 i = 0; i < listu.size() - 1; i++)
        {
             INT64 xa = listu[i];
             INT64 xb = listu[i + 1];
             if (xb==xa)
                continue;

             if (max(xa,xb) < ppx1 || min(xa,xb) >= ppx2)
                continue;

             // two crossings left can be two tips of the shape touching this row, with the gap between them outside
             if (simpleMode==0)
             {
                  if (!isPointInPolygonOptimized((xa + xb)/2, y, PointsList, activeEdges, PointsCount))
                     continue;
             }

             if (xb<xa)
                swap(xa,xb);

             INT64 start_x = max(xa, (INT64)ppx1);
             INT64 end_x = min(xb, (INT64)(ppx2 - 1));
             if (start_x <= end_x)
             {
                  polygonMaskMap.set_range_to_1(
                      (INT64)(y - polyY) * polyW + start_x - polyX,
                      (INT64)(y - polyY) * polyW + end_x - polyX
                  );
             }
        }
    }
}

int FillMaskPolygon(int w, int h, float* PointsList, int PointsCount, int ppx1, int ppy1, int ppx2, int ppy2) {
    fnOutputDebug("FillMaskPolygon() invoked; PointsCount=" + std::to_string(PointsCount));
    if (!PointsList || PointsCount < 3)
       return 0;

    bool goodState = initBoolMaskData();
    if (goodState==0)
       return 0;

    int boundMaxY = 0;
    
    std::vector<float> localPoints(PointsCount * 2);
    for ( int i = 0; i < PointsCount*2; i+=2)
    {
        localPoints[i] = round(PointsList[i]);
        localPoints[i + 1] = round(PointsList[i + 1]) + polyOffYa - polyOffYb;
        boundMaxY = max((int)localPoints[i + 1], boundMaxY);
    }

    std::vector<std::vector<int>>  polygonMapEdges;
    std::vector<int> polygonMapMin;

    int hmax = max(boundMaxY, h) + 1;
    polygonMapMin.resize(hmax);
    fnOutputDebug("polygonMapMin reserved");
    
    polygonMapEdges.resize(hmax);
    fnOutputDebug("polygonMapEdges reserved");

    traceMaskPolyBoundaries(w, h, localPoints.data(), PointsCount, ppx1, ppy1, ppx2, ppy2, polygonMapEdges, polygonMapMin);
    fnOutputDebug("traceMaskPolyBoundaries done");
    fillMaskPolyBounds(w, h, localPoints.data(), PointsCount, ppx1, ppy1, ppx2, ppy2, 0, polygonMapEdges);
    fnOutputDebug("fillMaskPolyBounds done");

    polygonMapEdges.clear();
    polygonMapEdges.shrink_to_fit();
    polygonMapMin.clear();
    polygonMapMin.shrink_to_fit();
    return 1;
}

bool inline isPointInOtherMask(const int &x, const int &y, const int &clipMode) {
    bool p = polygonOtherMaskMap[(INT64)y * polyW + x];
    return (clipMode==3) ? !p : p;
}

DLL_API int DLL_CALLCONV discardFilledPolygonCache(int m) {
    // polygonMapMin.clear();
    // polygonMapMin.shrink_to_fit();
    polygonMaskMap.clear();
    polygonMaskMap.shrink_to_fit();
    highDephMaskMap.clear();
    highDephMaskMap.shrink_to_fit();
    polygonOtherMaskMap.clear();
    polygonOtherMaskMap.shrink_to_fit();
    highDepthModeMask = 0;
    return 1;
}

bool inline isDotInRect(const int &mX, const int &mY, const int &x1, const int &x2, const int &y1, const int &y2) {
   return ( (min(x1, x2) <= mX && mX <= max(x1, x2))  &&  (min(y1, y2) <= mY && mY <= max(y1, y2)) ) ? 1 : 0;
}

void inline min_diff(int &va, int &vb, const int &diff) {
    int d = abs(va - vb);
    if (d < diff)
    {
       int dp = diff - d;
       int k = (floor(dp/2.0f) == dp/2.0f) ? 0 : 1;
       if (va<vb)
       {
          va -= dp/2;
          vb += dp/2 + k;
       } else
       {
          va += dp/2 + k;
          vb -= dp/2;
       }
    }
}

DLL_API int DLL_CALLCONV traverseCurvedPath(float* oPointsList, int oPointsCount, float* fPointsList, int fPointsCount, int gmx, int gmy, int sl, Gdiplus::GpPen *pPen, int* za, int* zb, int* f, int* l) {
// function used to identify the closest points, in a vector path, to a given pair of X/Y coordinates
// it determines the closest points [or the segment] in fPointsList and then the corresponding points [or segment] in oPointsList that is closest to gmX/gmY

// oPointsList -- original path, polygonal, unsubdivided 
// fPointsList -- subdivided path [using curved/cardinal/bezier GDI+ path modes], as a polygonal path 
// function invoked by coreAddUnorderedVectorPointCurveMode() in Quick Picto Viewer AHK file

    std::vector<int> PathsMap(fPointsCount + 3);
    fnOutputDebug("step 0: " + std::to_string(oPointsCount) + " / " + std::to_string(fPointsCount));
    for ( int i = 0; i < oPointsCount*2; i+=2)
    {
        oPointsList[i] = round( oPointsList[i] );
        oPointsList[i + 1] = round( oPointsList[i + 1] );
        // fnOutputDebug("step 0b=" + std::to_string(oPointsList[i]) + " / " + std::to_string(oPointsList[i + 1]));
    }

    int mapIndex = 0;
    int aIndex = 0;
    int bIndex = 0;
    int las = 0;
    for ( int i = 0; i < fPointsCount*2; i+=2)
    {
        aIndex++;
        fPointsList[i] = round( fPointsList[i] );
        fPointsList[i + 1] = round( fPointsList[i + 1] );
        int ax = fPointsList[i];
        int ay = fPointsList[i + 1];
        // fnOutputDebug("step 1a=" + std::to_string(ax) + " / " + std::to_string(ay));
        for ( int z = las; z < oPointsCount*2; z+=2)
        {
            bIndex++;
            int bx = oPointsList[z];
            int by = oPointsList[z + 1];
            if (ax==bx && ay==by)
            {
               mapIndex = bIndex;
               las = z;
               break;
            }
        }

        PathsMap[aIndex] = mapIndex;
        bIndex = mapIndex - 1;
        // fnOutputDebug("step 1=" + std::to_string(aIndex) + " / " + std::to_string(mapIndex));
    }

    // fnOutputDebug("step 2=" + std::to_string(gmx) + " / " + std::to_string(gmy));
    aIndex = 0;
    int hasFound = -1;
    // stop at the second-to-last point: each iteration reads the segment [i .. i+3]
    for ( int i = 0; i < fPointsCount*2 - 2; i+=2)
    {
        aIndex++;
        int ax = fPointsList[i];
        int ay = fPointsList[i + 1];
        int bx = fPointsList[i + 2];
        int by = fPointsList[i + 3];

        min_diff(ax, bx, sl);
        min_diff(ay, by, sl);
        int inn = isDotInRect(gmx, gmy, ax, bx, ay, by);
        if (inn==1)
        {
           ax = fPointsList[i];
           ay = fPointsList[i + 1];
           bx = fPointsList[i + 2];
           by = fPointsList[i + 3];
           BOOL r = NULL;
           // fnOutputDebug("inn");
           Gdiplus::GpPath *pPath = NULL;
           Gdiplus::DllExports::GdipCreatePath(Gdiplus::FillModeAlternate, &pPath);
           // fnOutputDebug("inn: path created");
           Gdiplus::DllExports::GdipAddPathLine(pPath, ax, ay, bx, by);
           // fnOutputDebug("inn: line added");
           Gdiplus::DllExports::GdipIsOutlineVisiblePathPoint(pPath, gmx, gmy, pPen, NULL, &r);
           // fnOutputDebug("inn: is outline");
           Gdiplus::DllExports::GdipDeletePath(pPath);
           // fnOutputDebug("inn: deleted path");
           // fnOutputDebug("inn: r=" + std::to_string(r));
           if (r)
           {
               hasFound = aIndex;
               break;
           }
        }
    }

    // fnOutputDebug("step 3 aIndex=" + std::to_string(aIndex));
    int last = (hasFound>=0) ? hasFound : -1;
    int first = (hasFound>=0) ? hasFound : -1;
    if (hasFound>=0)
    {
        for ( int i = hasFound; i < fPointsCount; i++)
        {
            if (PathsMap[i]!=PathsMap[last])
            {
                last = i;
                break;
            }
        }
        for ( int i = hasFound; i >= 0; i--)
        {
            if (PathsMap[i]!=PathsMap[first])
            {
                first = i;
                break;
            }
        }
    }

    int r = 1;
    int zza = 0;
    int zzb = 0;
    if (hasFound>=0)
    {
        zza = PathsMap[hasFound];
        zzb = (last==hasFound) ? zza + 1 : PathsMap[last + 1];
        if (last==hasFound)
           last = fPointsCount;

        r = 2;
        *za = zza;
        *zb = zzb;
        *f = first;
        *l = last;
    }

    fnOutputDebug("a=" + std::to_string(zza) + "; b=" + std::to_string(zzb) + "; f=" + std::to_string(first) + "; l=" + std::to_string(last));
    // fnOutputDebug("f=" + std::to_string(first) + "; h=" + std::to_string(hasFound) + "; l=" + std::to_string(last));
    return r;
}

DLL_API int DLL_CALLCONV testFilledPolygonCache(int m) {
    int r = 1;
    if (polygonMaskMap.size()<2000) // || polygonMapMin.size()<100)
       r = 0;
    return r;
}

void extendLine(const Point p1, const Point p2, const double distance, Point &newP1, Point &newP2) {
// Function to extend the line by a given parameter on both ends
    // Calculate the direction vector of the line
    double dx = p2.x - p1.x;
    double dy = p2.y - p1.y;

    // Calculate the length of the line segment
    double length = std::sqrt(dx * dx + dy * dy);

    // Normalize the direction vector
    double ux = dx / length;
    double uy = dy / length;

    // Extend the points by the distance parameter
    newP1.x = p1.x - ux * distance;
    newP1.y = p1.y - uy * distance;
    newP2.x = p2.x + ux * distance;
    newP2.y = p2.y + uy * distance;
}

void translateLine(const Point &p1, const Point &p2, const double &dx, const double &dy, const double distance, Point &np1, Point &np2, Point &np3, Point &np4) {
// Function to translate a line by a given distance parallel to the initial one

    // Calculate the direction vector of the line
    // const double dx = p2.x - p1.x;
    // const double dy = p2.y - p1.y;
    const double length = sqrt(dx * dx + dy * dy);

    // Normalize the direction vector
    // const double nx = dx / length;
    // const double ny = dy / length;

    // Calculate the perpendicular vector
    // const double px = -ny;
    // const double py = nx;

    // Calculate the translated line
    // const double ppx = px * distance;
    // const double ppy = py * distance;

    const double ppx = (-1*(dy / length)) * distance;
    const double ppy = (dx / length) * distance;

    // Translate the points
    np1 = {p1.x + ppx, p1.y + ppy};
    np2 = {p2.x + ppx, p2.y + ppy};
    np3 = {p1.x - ppx, p1.y - ppy};
    np4 = {p2.x - ppx, p2.y - ppy};
}

short inline testPointsOrientation(Point p, Point q, Point r) {
// Function to check the orientation of the triplet (p, q, r).
// The function returns:
// 0 -> p, q and r are collinear
// 1 -> Clockwise
// 2 -> Counterclockwise
    float val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
    if (fabs(val) < 1e-4f)
       return 0;               // collinear

    return (val > 0) ? 1 : 2;  // clock or counterclockwise
}

bool findLinesIntersection(Point A, Point B, Point C, Point D, float &x, float &y) {
    // Function to find the intersection point of two line segments if they intersect
    // Line AB represented as a1x + b1y = c1
    float a1 = B.y - A.y;
    float b1 = A.x - B.x;
    float c1 = a1 * (A.x) + b1 * (A.y);

    // Line CD represented as a2x + b2y = c2
    float a2 = D.y - C.y;
    float b2 = C.x - D.x;
    float c2 = a2 * (C.x) + b2 * (C.y);

    float determinant = a1 * b2 - a2 * b1;
    if (fabs(determinant) < 1e-4f)
       return 0; // The lines are parallel

    x = (b2 * c1 - b1 * c2) / determinant;
    y = (a1 * c2 - a2 * c1) / determinant;
    return 1;
}

void prepareTranslatedLineSegments(const float &thickness, vector<double> &offsetPointsListA, vector<double> &offsetPointsListB, float* PointsList, const int &PointsCount, const int &closed, const bool &expand, const int &offsetY) {
   const int pci = PointsCount - 1;
   for (int pts = 0; pts < PointsCount; pts++)
   {
       const int i = pts*2;
       const int N = PointsCount * 2;
       Point a = {PointsList[i], PointsList[i + 1]};
       Point b = {PointsList[(i + 2) % N], PointsList[(i + 3) % N]};
       Point c = {PointsList[(i + 4) % N], PointsList[(i + 5) % N]};   // it is meant as a backup, if A and B are too close, the AC segment will be used
  
       double dx = b.x - a.x;
       double dy = b.y - a.y;
       if (fabs(dx) < 0.01f && fabs(dy) < 0.01f)
       {
          dx = c.x - a.x;
          dy = c.y - a.y;
          b = c;
          // fnOutputDebug("segment too short: AB");
          // if (fabs(dx) < 0.01f && fabs(dy) < 0.01f)
          //    fnOutputDebug("segment too short: AC");
       }

       Point np1, np2, np3, np4;
       if (fabs(dx) < 0.01f && fabs(dy) < 0.01f)
          np1 = np2 = np3 = np4 = a;
       else
          translateLine(a, b, dx, dy, thickness, np1, np2, np3, np4);

       offsetPointsListA.push_back(np1.x);
       offsetPointsListA.push_back(np1.y);
       offsetPointsListA.push_back(np2.x);
       offsetPointsListA.push_back(np2.y);
       offsetPointsListB.push_back(np3.x);
       offsetPointsListB.push_back(np3.y);
       offsetPointsListB.push_back(np4.x);
       offsetPointsListB.push_back(np4.y);

       // i *= 2;
       // int kx = offsetPointsListA[i];
       // int ky = offsetPointsListA[i + 1];
       // fnOutputDebug(std::to_string(pts) + " kA=" + std::to_string(kx) + " // " + std::to_string(ky));
       // kx = offsetPointsListB[i];
       // ky = offsetPointsListB[i + 1];
       // fnOutputDebug(std::to_string(pts) + " kB=" + std::to_string(kx) + " // " + std::to_string(ky));
   }
}

// cv::polylines() asserts a thickness of at most 32767, which the live preview passes at extreme thickness x zoom.
// Past it the line is drawn the way OpenCV builds a thick one: a filled band per segment and a disc on each point.
static void drawThickPolylineRound(cv::Mat &img, const std::vector<cv::Point> &pts, bool closed, const cv::Scalar &color, int thickness) {
    const double r = thickness / 2.0;
    const size_t n = pts.size();
    const size_t segs = closed ? n : n - 1;
    for (size_t i = 0; i < segs; i++)
    {
        const cv::Point a = pts[i], b = pts[(i + 1) % n];
        const double dx = b.x - a.x, dy = b.y - a.y, len = sqrt(dx*dx + dy*dy);
        if (len<=0)
           continue;

        const double nx = -dy / len * r, ny = dx / len * r;
        const cv::Point band[4] = { cv::Point(cvRound(a.x + nx), cvRound(a.y + ny)), cv::Point(cvRound(b.x + nx), cvRound(b.y + ny)),
                                    cv::Point(cvRound(b.x - nx), cvRound(b.y - ny)), cv::Point(cvRound(a.x - nx), cvRound(a.y - ny)) };
        cv::fillConvexPoly(img, band, 4, color, cv::LINE_8);
    }

    for (size_t i = 0; i < n; i++)
        cv::circle(img, pts[i], cvRound(r), color, cv::FILLED, cv::LINE_8);
}

DLL_API int DLL_CALLCONV NewDrawLinesOnMask(float* PointsList, int PointsCount, int thickness, int closed, int roundedJoins, int fillMode, int roundCaps, int clipMode, int offsetY) {
    // Uses OpenCV drawing functions to render thick polylines onto polygonMaskMap.
    // The function renders onto a temporary cv::Mat using OpenCV's optimized line
    // rasterizer, then transfers the result into the bit-packed polygonMaskMap.
    //
    // Parameters:
    //   PointsList    - flat array of float [x0,y0, x1,y1, ...] in image-space
    //   PointsCount   - number of points (PointsList has PointsCount*2 floats)
    //   thickness     - half-thickness (radius) of the line stroke
    //   closed        - 1 = close the polyline (last point -> first point)
    //   roundedJoins  - 1 = round joins, otherwise = miter joins
    //   fillMode      - value to write into the mask (1 = draw, 0 = erase)
    //   roundCaps     - 1 = no caps; 2 = box/square caps, 3 = round caps (only for open paths)
    //   clipMode      - 2 = no clipping, 1/3 = clip against polygonOtherMaskMap
    //   offsetY       - vertical pixel offset applied during drawing

    fnOutputDebug(std::to_string(clipMode) + " NewDrawLinesOnMask() invoked; PointsCount=" + std::to_string(PointsCount));
    if (PointsCount < 2)
       return 0;

    // Validate polygonMaskMap size
    INT64 s = (INT64)polyW * polyH + 2;
    if (s != polygonMaskMap.size())
    {
       fnOutputDebug("NewDrawLinesOnMask: polygonMaskMap[] incorrect size=" + std::to_string(s) + " != " + std::to_string(polygonMaskMap.size()));
       return 0;
    }

    if (polyW < 1 || polyH < 1)
       return 0;

    if (clipMode!=2 && s!=polygonOtherMaskMap.size())
    {
       fnOutputDebug("NewDrawLinesOnMask: polygonOtherMaskMap[] incorrect size; it should match the size of polygonMaskMap[] size=" + std::to_string(s) + " != " + std::to_string(polygonOtherMaskMap.size()));
       return 0;
    }

    // Adjust Y-coordinates by polyOffYa - polyOffYb (same as drawLineAllSegmentsMask)
    for (int i = 0; i < PointsCount * 2; i += 2)
    {
        PointsList[i + 1] = PointsList[i + 1] + polyOffYa - polyOffYb;
    }

    // OpenCV thickness is the full diameter; the input 'thickness' is a radius.
    // OpenCV minimum thickness for a visible line is 1.
    const int cvThickness = max(1, thickness * 2 + 1);

    // Convert points from image-space to mask-local coordinates.
    // In mask-local coords: localX = imageX - polyX, localY = imageY - polyY + offsetY
    std::vector<cv::Point> cvPoints;
    cvPoints.reserve(PointsCount);
    for (int i = 0; i < PointsCount; i++)
    {
        int lx = (int)round(PointsList[i * 2]     - polyX);
        int ly = (int)round(PointsList[i * 2 + 1]  - polyY + offsetY);
        cvPoints.push_back(cv::Point(lx, ly));
    }

    const cv::Scalar drawColor(255);
    const cv::Scalar drawBlackColor(0);
    const bool useFill = (fillMode != 0);

    // --- Bounding-box + row-band tiling to reduce temporary memory ---
    // Compute the bounding box of all points in mask-local space.
    // Only allocate a cv::Mat for this region (and tile it if still too large).
    int bbMinX = cvPoints[0].x, bbMaxX = cvPoints[0].x;
    int bbMinY = cvPoints[0].y, bbMaxY = cvPoints[0].y;
    for (size_t i = 1; i < cvPoints.size(); i++)
    {
        if (cvPoints[i].x < bbMinX) bbMinX = cvPoints[i].x;
        if (cvPoints[i].x > bbMaxX) bbMaxX = cvPoints[i].x;
        if (cvPoints[i].y < bbMinY) bbMinY = cvPoints[i].y;
        if (cvPoints[i].y > bbMaxY) bbMaxY = cvPoints[i].y;
    }

    // Expand by a margin for line thickness, caps, and miter join extensions
    const int bbMargin = max(cvThickness * 4, thickness + 10);
    bbMinX = max(0, bbMinX - bbMargin);
    bbMinY = max(0, bbMinY - bbMargin);
    bbMaxX = min((int)polyW - 1, bbMaxX + bbMargin);
    bbMaxY = min((int)polyH - 1, bbMaxY + bbMargin);

    if (bbMinX > bbMaxX || bbMinY > bbMaxY)
        return 1; // all points are outside the mask bounds

    const int roiX = bbMinX;
    const int roiW = bbMaxX - bbMinX + 1;
    const int roiH = bbMaxY - bbMinY + 1;

    // Keep each tile under 64 MB to limit peak temporary memory
    const INT64 maxTileBytes = 64LL * 1024 * 1024;
    const int bandHeight = (roiW > 0)
        ? max(64, (int)min((INT64)roiH, maxTileBytes / (INT64)roiW))
        : roiH;

    // Pre-compute translated line segments for miter joins (tile-independent)
    std::vector<double> offsetPointsListA;
    std::vector<double> offsetPointsListB;
    if (roundedJoins != 1)
    {
        offsetPointsListA.reserve(PointsCount * 4 + 5);
        offsetPointsListB.reserve(PointsCount * 4 + 5);
        prepareTranslatedLineSegments(thickness, offsetPointsListA, offsetPointsListB,
                                      PointsList, PointsCount, closed, 0, offsetY);
    }

    // --- Tile loop: process the bounding-box ROI in horizontal bands ---
    cv::Mat tileMat;
    for (int tileStartY = bbMinY; tileStartY <= bbMaxY; tileStartY += bandHeight)
    {
        const int tileH = min(bandHeight, bbMaxY - tileStartY + 1);
        const int tileOffX = roiX;
        const int tileOffY = tileStartY;

        // Create (or re-create) tile-sized temporary mask
        tileMat = cv::Mat::zeros(tileH, roiW, CV_8UC1);

        if (roundedJoins == 1)
        {
            // Round joins mode: offset cvPoints to tile-local coordinates
            std::vector<cv::Point> tilePoints(cvPoints.size());
            for (size_t i = 0; i < cvPoints.size(); i++)
                tilePoints[i] = cv::Point(cvPoints[i].x - tileOffX, cvPoints[i].y - tileOffY);

            if (cvThickness <= 32767)
            {
               std::vector<std::vector<cv::Point>> polyContours = { tilePoints };
               cv::polylines(tileMat, polyContours, (closed == 1), drawColor, cvThickness, cv::LINE_8);
            } else
               drawThickPolylineRound(tileMat, tilePoints, (closed == 1), drawColor, cvThickness);

            // For an open path, handle cap styles at the two endpoints
            if (closed != 1 && PointsCount >= 2)
            {
                if (roundCaps <= 2)
                {
                    // Box/square caps: extend the line at each endpoint by 'thickness' pixels
                    // and draw a filled rectangle for the cap
                    for (int capIdx = 0; capIdx < 2; capIdx++)
                    {
                        cv::Point pA, pB;
                        if (capIdx == 0)
                        {
                           pA = tilePoints[0];
                           pB = tilePoints[1];
                        } else
                        {
                           pA = tilePoints[PointsCount - 1];
                           pB = tilePoints[PointsCount - 2];
                        }

                        // Direction from the interior toward the endpoint
                        double dx = (double)(pA.x - pB.x);
                        double dy = (double)(pA.y - pB.y);
                        double len = sqrt(dx * dx + dy * dy);
                        if (len < 0.01)
                           continue;

                        // Normalize direction
                        double nx = dx / len;
                        double ny = dy / len;
                        // Perpendicular
                        double px = -ny;
                        double py = nx;

                        // Start the cap 2 pixels earlier (overlap with the line) to prevent seams
                        double startX = (roundCaps == 2) ? pA.x - nx : pA.x - nx * 4.0;
                        double startY = (roundCaps == 2) ? pA.y - ny : pA.y - ny * 4.0;

                        // Cap extends 'thickness' + 2 pixels beyond the endpoint,
                        // making it 2 pixels longer
                        double extX = pA.x + nx * (thickness + 2.0);
                        double extY = pA.y + ny * (thickness + 2.0);

                        // Build the 4 corners of the box cap rectangle
                        cv::Point capRect[4];
                        int tk = (roundCaps == 2) ? thickness : thickness + 1;
                        capRect[0] = cv::Point((int)round(startX + px * tk), (int)round(startY + py * tk));
                        capRect[1] = cv::Point((int)round(startX - px * tk), (int)round(startY - py * tk));
                        capRect[2] = cv::Point((int)round(extX - px * tk), (int)round(extY - py * tk));
                        capRect[3] = cv::Point((int)round(extX + px * tk), (int)round(extY + py * tk));

                        std::vector<std::vector<cv::Point>> capContour = { {capRect[0], capRect[1], capRect[2], capRect[3]} };
                        if (roundCaps == 2)
                           cv::fillPoly(tileMat, capContour, drawColor);
                        else
                           cv::fillPoly(tileMat, capContour, drawBlackColor);
                    }
                } else if (roundCaps == 3)
                {
                    // Round caps: draw a filled circle at the endpoints
                    for (int capIdx = 0; capIdx < 2; capIdx++)
                    {
                        cv::Point pEnd = (capIdx == 0) ? tilePoints[0] : tilePoints[PointsCount - 1];
                        cv::circle(tileMat, pEnd, thickness, drawColor, cv::FILLED, cv::LINE_8);
                    }
                }
            }
        } else
        {
            // Miter joins mode: draw each segment as a filled rectangle (the thick line body),
            // then fill the miter join regions between consecutive segments.

            const int pci = PointsCount - 1;

            // Draw each line segment as a filled rectangle
            for (int pts = 0; pts < PointsCount; pts++)
            {
                int i = pts * 2;
                float xa = PointsList[i];
                float ya = PointsList[i + 1];
                float xb, yb;
                if (pts == pci)
                {
                    if (closed != 1)
                       break;
                    xb = PointsList[0];
                    yb = PointsList[1];
                } else
                {
                    xb = PointsList[i + 2];
                    yb = PointsList[i + 3];
                }

                double orig_dx = xb - xa;
                double orig_dy = yb - ya;
                if (fabs(orig_dx) < 0.01f && fabs(orig_dy) < 0.01f)
                {
                    // Degenerate segment: stamp a circle
                    int cx = (int)round(xa - polyX) - tileOffX;
                    int cy = (int)round(ya - polyY + offsetY) - tileOffY;
                    cv::circle(tileMat, cv::Point(cx, cy), thickness, drawColor, cv::FILLED, cv::LINE_8);
                    continue;
                }

                // Compute the 4 corners of the thick rectangle for this segment
                Point npA, npB, np1, np2, np3, np4;
                extendLine({xa, ya}, {xb, yb}, 1.0f, npA, npB);
                double dx = npB.x - npA.x;
                double dy = npB.y - npA.y;
                translateLine(npA, npB, dx, dy, thickness, np1, np2, np3, np4);

                // Convert to mask-local coordinates with tile offset, and draw as filled polygon
                cv::Point rectPts[4];
                rectPts[0] = cv::Point((int)round(np1.x - polyX) - tileOffX, (int)round(np1.y - polyY + offsetY) - tileOffY);
                rectPts[1] = cv::Point((int)round(np3.x - polyX) - tileOffX, (int)round(np3.y - polyY + offsetY) - tileOffY);
                rectPts[2] = cv::Point((int)round(np4.x - polyX) - tileOffX, (int)round(np4.y - polyY + offsetY) - tileOffY);
                rectPts[3] = cv::Point((int)round(np2.x - polyX) - tileOffX, (int)round(np2.y - polyY + offsetY) - tileOffY);
                std::vector<std::vector<cv::Point>> segContour = { {rectPts[0], rectPts[1], rectPts[2], rectPts[3]} };
                cv::fillPoly(tileMat, segContour, drawColor);
            }

            // Handle open-path caps
            if (closed == 0 && PointsCount >= 2)
            {
                for (int capIdx = 0; capIdx < 2; capIdx++)
                {
                    float pxA, pyA, pxB, pyB;
                    if (capIdx == 0)
                    {
                        pxA = PointsList[0];
                        pyA = PointsList[1];
                        pxB = PointsList[2];
                        pyB = PointsList[3];
                    } else
                    {
                        pxA = PointsList[(PointsCount - 1) * 2];
                        pyA = PointsList[(PointsCount - 1) * 2 + 1];
                        pxB = PointsList[(PointsCount - 2) * 2];
                        pyB = PointsList[(PointsCount - 2) * 2 + 1];
                    }

                    if (roundCaps == 3)
                    {
                        // Round cap: draw a filled circle at the endpoint
                        int cx = (int)round(pxA - polyX) - tileOffX;
                        int cy = (int)round(pyA - polyY + offsetY) - tileOffY;
                        cv::circle(tileMat, cv::Point(cx, cy), thickness, drawColor, cv::FILLED, cv::LINE_8);
                    } else if (roundCaps == 2)
                    {
                        // Box/square cap: extend the line and fill a rectangle
                        double dx = pxA - pxB;
                        double dy = pyA - pyB;
                        double len = sqrt(dx * dx + dy * dy);
                        if (len >= 0.01)
                        {
                            double nx = dx / len;
                            double ny = dy / len;
                            double px = -ny;
                            double py = nx;
                            double extX = pxA + nx * thickness;
                            double extY = pyA + ny * thickness;

                            cv::Point capPts[4];
                            capPts[0] = cv::Point((int)round(pxA + px * thickness - polyX) - tileOffX, (int)round(pyA + py * thickness - polyY + offsetY) - tileOffY);
                            capPts[1] = cv::Point((int)round(pxA - px * thickness - polyX) - tileOffX, (int)round(pyA - py * thickness - polyY + offsetY) - tileOffY);
                            capPts[2] = cv::Point((int)round(extX - px * thickness - polyX) - tileOffX, (int)round(extY - py * thickness - polyY + offsetY) - tileOffY);
                            capPts[3] = cv::Point((int)round(extX + px * thickness - polyX) - tileOffX, (int)round(extY + py * thickness - polyY + offsetY) - tileOffY);

                            std::vector<std::vector<cv::Point>> capContour = { {capPts[0], capPts[1], capPts[2], capPts[3]} };
                            cv::fillPoly(tileMat, capContour, drawColor);
                        }
                    }
                }
            }

            // Fill miter join regions between consecutive segments
            if (PointsCount > 2)
            {
                for (int pts = 0; pts < PointsCount; pts++)
                {
                    if (pts == 0 && closed == 0)
                       continue;

                    if (pts == pci)
                    {
                       if (closed != 1)
                          break;
                    }

                    int i = pts * 2;
                    int z = (pts == 0) ? (PointsCount - 1) * 4 : (pts - 1) * 4;
                    int k = (pts == 0) ? (PointsCount - 1) * 2 : (pts - 1) * 2;
                    int n = (pts == pci) ? 0 : (pts + 1) * 2;
                    Point c  = {PointsList[i], PointsList[i + 1]};
                    Point cp = {PointsList[k], PointsList[k + 1]};
                    Point cn = {PointsList[n], PointsList[n + 1]};
                    Point a, b, az, bz;
                    short orientation = testPointsOrientation(cp, c, cn);

                    if (orientation == 2)
                    {
                        a = (pts == 0) ? Point{offsetPointsListB[0], offsetPointsListB[1]} : Point{offsetPointsListB[z + 4], offsetPointsListB[z + 5]};
                        b = {offsetPointsListB[z + 2], offsetPointsListB[z + 3]};
                    } else if (orientation == 1)
                    {
                        a = (pts == 0) ? Point{offsetPointsListA[0], offsetPointsListA[1]} : Point{offsetPointsListA[z + 4], offsetPointsListA[z + 5]};
                        b = {offsetPointsListA[z + 2], offsetPointsListA[z + 3]};
                    } else
                    {
                        // Colinear: stamp a circle at the vertex
                        if (pts == 0 || pts == pci)
                        {
                            int cx = (int)round(c.x - polyX) - tileOffX;
                            int cy = (int)round(c.y - polyY + offsetY) - tileOffY;
                            cv::circle(tileMat, cv::Point(cx, cy), thickness, drawColor, cv::FILLED, cv::LINE_8);
                        }
                    }

                    if (orientation == 2 || orientation == 1)
                    {
                        z = (pts == 0) ? (PointsCount - 1) * 4 : (pts - 2) * 4;
                        if (orientation == 2)
                           bz = (pts == 0) ? Point{offsetPointsListB[z], offsetPointsListB[z + 1]} : Point{offsetPointsListB[z + 4], offsetPointsListB[z + 5]};
                        else
                           bz = (pts == 0) ? Point{offsetPointsListA[z], offsetPointsListA[z + 1]} : Point{offsetPointsListA[z + 4], offsetPointsListA[z + 5]};

                        z = pts * 4;
                        if (orientation == 2)
                           az = (pts == 0) ? Point{offsetPointsListB[2], offsetPointsListB[3]} : Point{offsetPointsListB[z + 2], offsetPointsListB[z + 3]};
                        else
                           az = (pts == 0) ? Point{offsetPointsListA[2], offsetPointsListA[3]} : Point{offsetPointsListA[z + 2], offsetPointsListA[z + 3]};

                        float nx_f, ny_f;
                        bool hasIntersection = findLinesIntersection(a, az, b, bz, nx_f, ny_f);

                        if (hasIntersection)
                        {
                            // Miter join: 4-point polygon (a, intersection, b, center)
                            cv::Point joinPts[4];
                            joinPts[0] = cv::Point((int)round(a.x - polyX) - tileOffX,    (int)round(a.y - polyY + offsetY) - tileOffY);
                            joinPts[1] = cv::Point((int)round(nx_f - polyX) - tileOffX,   (int)round(ny_f - polyY + offsetY) - tileOffY);
                            joinPts[2] = cv::Point((int)round(b.x - polyX) - tileOffX,    (int)round(b.y - polyY + offsetY) - tileOffY);
                            joinPts[3] = cv::Point((int)round(c.x - polyX) - tileOffX,    (int)round(c.y - polyY + offsetY) - tileOffY);
                            std::vector<std::vector<cv::Point>> joinContour = { {joinPts[0], joinPts[1], joinPts[2], joinPts[3]} };
                            cv::fillPoly(tileMat, joinContour, drawColor);
                        } else
                        {
                            // Bevel join fallback: 3-point triangle (a, b, center)
                            cv::Point joinPts[3];
                            joinPts[0] = cv::Point((int)round(a.x - polyX) - tileOffX,  (int)round(a.y - polyY + offsetY) - tileOffY);
                            joinPts[1] = cv::Point((int)round(b.x - polyX) - tileOffX,  (int)round(b.y - polyY + offsetY) - tileOffY);
                            joinPts[2] = cv::Point((int)round(c.x - polyX) - tileOffX,  (int)round(c.y - polyY + offsetY) - tileOffY);
                            std::vector<std::vector<cv::Point>> joinContour = { {joinPts[0], joinPts[1], joinPts[2]} };
                            cv::fillPoly(tileMat, joinContour, drawColor);
                        }
                    }
                }
            }
        }

        // Transfer this tile's pixels into polygonMaskMap, respecting fillMode and clipMode.
        // tileMat pixels with value > 0 correspond to drawn areas.
        if (clipMode == 2)
        {
            // No clipping: fastest path
            #pragma omp parallel for schedule(static) num_threads(4)
            for (int y = 0; y < tileH; y++)
            {
                const unsigned char* row = tileMat.ptr<unsigned char>(y);
                const int globalY = tileOffY + y;
                const INT64 rowStart = (INT64)globalY * polyW;
                for (int x = 0; x < roiW; x++)
                {
                    if (row[x] > 0)
                       polygonMaskMap[rowStart + tileOffX + x] = useFill;
                }
            }
        } else
        {
            // Clipping against polygonOtherMaskMap
            #pragma omp parallel for schedule(static) num_threads(4)
            for (int y = 0; y < tileH; y++)
            {
                const unsigned char* row = tileMat.ptr<unsigned char>(y);
                const int globalY = tileOffY + y;
                const INT64 rowStart = (INT64)globalY * polyW;
                for (int x = 0; x < roiW; x++)
                {
                    if (row[x] > 0)
                    {
                        const int globalX = tileOffX + x;
                        if (isPointInOtherMask(globalX, globalY, clipMode) == 1)
                           polygonMaskMap[rowStart + globalX] = useFill;
                    }
                }
            }
        }
    } // end tile loop

    // fnOutputDebug("NewDrawLinesOnMask() - done");
    return 1;
}

DLL_API int DLL_CALLCONV mergePolyMaskIntoHighDepthMask(int px1, int py1, int px2, int py2, int imgW, int imgH, int thickness) {
  INT64 s = (INT64)polyW * polyH + 2; // variables set by prepareSelectionArea()
  fnOutputDebug("mergePolyMaskIntoHighDepthMask() invoked: w / h= " + std::to_string(polyW) + " x " + std::to_string(polyH) + "; SIZE desired=" + std::to_string(s));
  if (s!=polygonMaskMap.size())
  {
     fnOutputDebug("mergePolyMaskIntoHighDepthMask() error: SIZE MISMATCHED polygonMaskMap=" + std::to_string(polygonMaskMap.size()));
     return 0;
  }

  if (s!=highDephMaskMap.size())
  {
     fnOutputDebug("mergePolyMaskIntoHighDepthMask() error: SIZE MISMATCHED highDephMaskMap=" + std::to_string(highDephMaskMap.size()));
     return 0;
  }

  // the window comes in the coordinates of the points NewDrawLinesOnMask() was given: map it the same way
  const INT64 offY = polyOffYa - polyOffYb - polyY;
  const int mw = (int)min((INT64)px2 - polyX + thickness, polyW - 1);
  const int mh = (int)min((INT64)py2 + offY + thickness, polyH - 1);
  const int mx = (int)max((INT64)px1 - polyX - thickness, (INT64)0);
  const int my = (int)max((INT64)py1 + offY - thickness, (INT64)0);
  if (mx>mw || my>mh)
     return 1; // the stroke lies off the mask

  #pragma omp parallel for schedule(static) default(none) num_threads(4)
  for (int y = my; y <= mh; y++) {
      const INT64 start = (INT64)y * polyW;
      for (INT64 i = start + mx; i <= start + mw; i++) {
          if (polygonMaskMap[i]==1)
             highDephMaskMap[i] = clamp(highDephMaskMap[i] + polygonMaskMap[i], 0, 255);
     }
  }

  const INT64 rstart = (INT64)my * polyW + mx;
  const INT64 rend = (INT64)mh * polyW + mw;
  polygonMaskMap.fill_zero(rstart, rend + 1); // fill_zero() treats the end as exclusive
  return 1;
}

DLL_API int DLL_CALLCONV prepareDrawLinesMask(int radius, int clipMode, int highDepth) {
     // relies on prepareSelectionArea()
     EllipseSelectMode = 2;
     invertSelection = 0;
     highDepthModeMask = highDepth;
     INT64 s = (INT64)polyW * polyH + 2; // variables set by prepareSelectionArea()
     fnOutputDebug("prepareDrawLinesMask() invoked: w / h= " + std::to_string(polyW) + " x " + std::to_string(polyH) + "; size=" + std::to_string(s));

     if (s!=polygonMaskMap.size())
     {
        try
        {
           polygonMaskMap.resize(s);
        } catch(const std::bad_alloc& e)
        {
           fnOutputDebug("polygonMaskMap failed. bad_alloc");
           return 0;
        } catch(const std::length_error& e)
        {
           fnOutputDebug("polygonMaskMap failed. length_error");
           return 0;
        }
 
        fnOutputDebug("polygonMaskMap RESIZED");
     }

     if (clipMode!=2)
     {
        try
        {
           polygonOtherMaskMap.resize(s);
        } catch(const std::bad_alloc& e)
        {
           fnOutputDebug("polygonOtherMaskMap failed. bad_alloc");
           return 0;
        } catch(const std::length_error& e)
        {
           fnOutputDebug("polygonOtherMaskMap failed. length_error");
           return 0;
        }
 
        polygonOtherMaskMap = polygonMaskMap;
        bool pp = (polygonMaskMap.size()==s) ? 1 : 0;
        fnOutputDebug(std::to_string(clipMode) + "polygonOtherMaskMap RESIZED " + std::to_string(pp) + " size = " + std::to_string(polygonMaskMap.size()));
    }

    if (s!=highDephMaskMap.size() && highDepthModeMask==1)
    {
       try
       {
          highDephMaskMap.resize(s);
       } catch(const std::bad_alloc& e)
       {
          fnOutputDebug("highDephMaskMap failed. bad_alloc");
          return 0;
       } catch(const std::length_error& e)
       {
          fnOutputDebug("highDephMaskMap failed. length_error");
          return 0;
       }

       fnOutputDebug("highDephMaskMap RESIZED");
       fill(highDephMaskMap.begin(), highDephMaskMap.end(), 0);
    } else if (highDepthModeMask==0)
    {
       highDephMaskMap.clear();
       highDephMaskMap.shrink_to_fit();
    }

    polygonMaskMap.fill_zero();
    fnOutputDebug("prepareDrawLinesMask() - polygonMaskMap DONE; radius = " + std::to_string(radius));
    return 1;
}

unsigned char clipMaskFilter(const int &x, const int &y, const unsigned char *maskBitmap, const int &mStride) {
    // see comments for prepareSelectionArea()
    if (invertSelection==1)
    {
       // the polygon mask maps its rows as in the branch below: from polyOffYa rows under imgSelY1
       const INT64 selY1 = (maskBitmap==NULL && EllipseSelectMode==2) ? imgSelY1 - polyOffYa : imgSelY1;
       if (inRange(imgSelX1, imgSelX2, x) && inRange(selY1, imgSelY2, y))
       {
          if (maskBitmap!=NULL)
          {
             INT64 mo = CalcPixOffset(x - imgSelX1, y - imgSelY1, mStride, 24);
             if (maskBitmap[mo]>128)
                return 1;
          } else if (EllipseSelectMode==2)
          {
             bool r = 0;
             if (inRange(0, polyH - 1, y - imgSelY1 - polyY + polyOffYa) && inRange(0, polyW - 1, x - imgSelX1 - polyX))
                r = polygonMaskMap[(INT64)(y - imgSelY1 - polyY + polyOffYa) * polyW + x - imgSelX1 - polyX];
             return r;
          } else if (EllipseSelectMode==1 || EllipseSelectMode==0 && (vpSelRotation!=0 || excludeSelectScale!=0))
          {
             return isInsideRectOval(x - imgSelX1, y - imgSelY1, 1);
          } else 
          {
             return 1;
          }
       }
    } else
    {
       if (!inRange(imgSelX1, imgSelX2, x) || !inRange(imgSelY1 - polyOffYa, imgSelY2, y))
          return (highDepthModeMask==1) ? 0 : 1;

       if (maskBitmap!=NULL)
       {
          INT64 mo = CalcPixOffset(x - imgSelX1, y - imgSelY1, mStride, 24);
          if (maskBitmap[mo]<128)
             return 1;
       } else if (EllipseSelectMode==2)
       {
          bool r = (highDepthModeMask==1) ? 1 : 0;
          if (inRange(0, polyH - 1, y - imgSelY1 - polyY + polyOffYa) && inRange(0, polyW - 1, x - imgSelX1 - polyX))
          {
             if (highDepthModeMask==1) // flag set by prepareDrawLinesMask() and used by mergePolyMaskIntoHighDepthMask() invoked from AHK by HugeImagesDrawParametricLines()
                return highDephMaskMap[(INT64)(y - imgSelY1 - polyY + polyOffYa) * polyW + x - imgSelX1 - polyX];

             r = polygonMaskMap[(INT64)(y - imgSelY1 - polyY + polyOffYa) * polyW + x - imgSelX1 - polyX];
          }

          // fnOutputDebug("clipMaskFilter y=" + std::to_string(y - imgSelY1 - polyY + polyOffYa));
          return !r;
       } else if (EllipseSelectMode==1 || EllipseSelectMode==0 && (vpSelRotation!=0 || excludeSelectScale!=0))
       {
          return !isInsideRectOval(x - imgSelX1, y - imgSelY1, 1);
       }
    }
    return 0;
}

DLL_API int DLL_CALLCONV prepareSelectionArea(
  int x1, int y1,
  int x2, int y2,
  int w, int h,
  float xf, float yf,
  float angle, int mode, int flip,
  float exclusion, int invertArea,
  float* PointsList, int PointsCount,
  int ppx1, int ppy1,
  int ppx2, int ppy2,
  int useCache, int ppofYa, int ppofYb) {
/*
This function is called from AHK, from QPV_PrepareHugeImgSelectionArea().
The AHK wrapper function calculates the coordinates this function receives.

Parameters:
    x1, y1, x2, y2, w, h   / these are the coordinates of the image selection area bounding box, within the image
    xf, yf                 / selection area scale factors on X and Y used when the selection area is rotated; with these scales, i can ensure that the viewport selection area in QPV created via GDI+ matches with the c++ results 
    angle                  / selection area rotation angle ; it applies for ellipses and rectangles only
    mode                   / the selection area shapes: 0 = rect; 1 = ellipse; 2 = freeform polygonal shape
    flip                   / FreeImage works with images flipped on Y; this parameter is used to accomodate this when using rotated ellipses and rectangles; otherwise it does not apply; freeform polygonal shapes are Y-flipped in QPV_PrepareHugeImgSelectionArea()
    exclusion              / used to create a cavity/hole in the selection area; eg. an ellipse can be turned into a torus; parameter does not apply to mode==2
    invertArea             / invert selection area

Parameters relevant only for selection areas based on freeform vector paths:
    PointsList             / a pointer to a freeform polygonal shape created with GDI+; the points are in image/pixel coordinates, but are relative to the image selection are bounding box
    PointsCount            / the number of points the vector shape has 
    ppx1, ppy1, ppx2, ppy2 / the coordinates of the subsection of the selection area bounding box intended to be drawn; it is used primarily when dealing with viewport live previews, but also when the selection area exceeds the image bounding box; with these coordinates i can avoid excessive memory usage and drastically reduce computations
    useCache               / if TRUE then polygonMaskMap[] will be reused
    ppofYa, ppofYb         / Y offsets used to accomodate FreeImage's Y-flipped crap

How selection areas work:
Almost any image editing tool in QPV will invoke QPV_PrepareHugeImgSelectionArea() which
will call this function from the compiled DLL: prepareSelectionArea().

Only the C++ image editing functions I wrote rely on this, eg, FillSelectArea().
Such functions rely on clipMaskFilter() in the For Loop that traverses the image 
being edited. The function determines if any given pixel within the image bounds is to 
be modified or not. It works with different types of selection areas or sources: rects,
ellipses, polygonal shapes, and bitmaps.

When (mode==2) a polygonal shape is used, FillMaskPolygon() is invoked by prepareSelectionArea().
FillMaskPolygon() fills the polygonMaskMap boolean vector with 0/1 values. The vector is 
sized according to the ppxy subsection coordinates in order to minimize memory usage.

When clipMaskFilter() is called, it uses the polygonMaskMap vector precalculated data.

If the selection area shape is set to be a rect or an ellipse, isInsideRectOval() is used
to determine if the pixel is to be modified or not, in clipMaskFilter(). In this case, no 
precalculated data is used.

clipMaskFilter() can also rely on a bitmap, but it must be passed directly to it.
*/

    imgSelX1 = x1;
    imgSelY1 = y1;
    imgSelX2 = x2;
    imgSelY2 = y2;
    imgSelExclX = w - (w*exclusion);
    imgSelExclY = h - (h*exclusion);
    imgSelExclW = (w - imgSelExclX*2) / 2.0f;
    imgSelExclH = (h - imgSelExclY*2) / 2.0f;
    imgSelXscale = xf;
    imgSelYscale = yf;
    hImgSelW = w / 2.0f;
    hImgSelH = h / 2.0f;
    EllipseSelectMode = mode;
    flippedSelection = flip;
    invertSelection = invertArea;
    excludeSelectScale = exclusion;
    vpSelRotation = (angle * M_PI) / 180.0f; // convert to radians
    cosVPselRotation = cos(vpSelRotation);
    sinVPselRotation = sin(vpSelRotation);
    polyX = ppx1;
    polyY = ppy1;
    polyW = ppx2 - ppx1;
    polyH = ppy2 - ppy1;
    polyOffYa = ppofYa;
    polyOffYb = ppofYb;
    if (polygonMaskMap.size()<2000) // || polygonMapMin.size()<100)
       useCache = 0;

    int z = 1;
    if (mode==2 && PointsList!=NULL && useCache!=1 && polyW>1 && polyH>1)
       z = FillMaskPolygon(w, h, PointsList, PointsCount, ppx1, ppy1, ppx2, ppy2);
    else if (mode==2 && useCache!=1)
       EllipseSelectMode = 0;

    return z;
}

#endif // QPV_SELECTION_MASK_H
