#include <iostream>
#include <fstream>
#include <vector>
#include "qpv-main.h"

DLL_API int DLL_CALLCONV EraserBrush(int *imageData, int *maskData,
             int w, int h, int invert, int replaceMode, int levelAlpha);

int main(int argc, char **argv) {
   std::ifstream f("c:\\temp\bub.txt");
   int w, h;
   int invert, replaceMode, levelAlpha;
   f >> w >> h;
   f >> invert >> replaceMode >> levelAlpha;
   const int n = w *h;
   std::vector<int> imageData(n);
   std::vector<int> maskData(n);
   for (int i = 0 ; i < n ; ++i) {
      f >> imageData[i] >> maskData[i];      
   }
   EraserBrush(&imageData[0], &maskData[0],
               w, h, invert, replaceMode, levelAlpha);
   return 0;
}