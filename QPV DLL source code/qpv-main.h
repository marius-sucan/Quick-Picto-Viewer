// Le bloc ifdef suivant est la façon standard de créer des macros qui facilitent l'exportation
// à partir d'une DLL plus simple. Tous les fichiers contenus dans cette DLL sont compilés avec le symbole QPVMAIN_EXPORTS
// défini sur la ligne de commande. Ce symbole ne doit pas être défini pour un projet
// qui utilise cette DLL. Ainsi, les autres projets dont les fichiers sources comprennent ce fichier considèrent les fonctions
// QPVMAIN_API comme étant importées à partir d'une DLL, tandis que cette DLL considère les symboles
// définis avec cette macro comme étant exportés.

const DWORD dwHwndTabletProperty = 
    TABLET_DISABLE_PRESSANDHOLD |      // disables press and hold (right-click) gesture
    TABLET_DISABLE_PENTAPFEEDBACK |    // disables UI feedback on pen up (waves)
    TABLET_DISABLE_PENBARRELFEEDBACK | // disables UI feedback on pen button down (circle)
    TABLET_DISABLE_FLICKFALLBACKKEYS |
    TABLET_DISABLE_SMOOTHSCROLLING |
    TABLET_DISABLE_TOUCHUIFORCEON |
    TABLET_DISABLE_FLICKS;             // disables pen flicks (back, forward, drag down, drag up)

const double M_PI = 3.14159265358979323846;  // PI
const double div2sz = sqrt(2.0 / 32.0);      // used in calculateDCT()
const double div2sq = 1 / sqrt(2.0);         // used in calculateDCT()
const float div2s3 = 2.0f/3.0f;      // used in ConvertRGBtoHSL()
const float div1s3 = 1.0f/3.0f;      // used in ConvertRGBtoHSL()
float imgSelExclW = 0.0f;
float imgSelExclH = 0.0f;
float imgSelExclX = 0.0f;
float imgSelExclY = 0.0f;
int imgSelX1 = 0;
int imgSelY1 = 0;
int imgSelX2 = 0;
int imgSelY2 = 0;
int imgSelW = 0;
int imgSelH = 0;
int EllipseSelectMode = 0;
int flippedSelection = 0;
int invertSelection = 0;
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
INT64 blahImgH = 0;

IWICBitmapDecoder      *pWICclassDecoder;
IWICBitmapFrameDecode  *pWICclassFrameDecoded;
// IWICFormatConverter *pWICclassConverter;
IWICBitmapSource       *pWICclassPixelsBitmapSource;

std::vector<bool>  polygonMaskMap;
std::vector<bool>  polygonOtherMaskMap;
// std::vector<std::vector<short>> DrawLineCapsGrid;
vector<pair<float, float>> DrawLineCapsGrid;
// vector<pair<int, int>> DrawLineGrid;

std::vector<UINT>  dupesListIDsA(1);
std::vector<UINT>  dupesListIDsB(1);
std::vector<UINT>  dupesListIDsC(1);
// std::unordered_map<UINT, unsigned char>  brushMoveImgData(1);

std::array<double, 1025>  DCTcoeffs;

struct Point {
    double x, y;
};

struct RGBColor {
    double r, g, b;
};

struct RGBColorI {
    int r, g, b;
};

struct HSLColor {
    double h, s, l;

    double inline ConvertHueToRGB(const double &v1, const double &v2, double vH) {
           vH = ((vH<0) ? ++vH : vH);
           vH = ((vH>1) ? --vH : vH);
           return ((6.0f * vH) < 1) ? (v1 + (v2 - v1) * 6.0f * vH)
                  : ((2.0f * vH) < 1) ? (v2)
                  : ((3.0f * vH) < 2) ? (v1 + (v2 - v1) * ((2.0f / 3.0f) - vH) * 6.0f)
                  : v1;
    }

    RGBColorI ConvertHSLtoRGB() {
    // http://www.had2know.com/technology/hsl-rgb-color-converter.html

       double fH = h/360.0f;
       double var_1, var_2;
       RGBColorI newColor;
       if (s == 0)
       {
          newColor.r = clamp((float)l*255.0f, 0.0f, 255.0f);
          newColor.g = clamp((float)l*255.0f, 0.0f, 255.0f);
          newColor.b = clamp((float)l*255.0f, 0.0f, 255.0f);
       } else
       {
          if (l < 0.5)
             var_2 = l * (1.0f + s);
          else
             var_2 = (l + s) - (s * l);

          var_1 = 2.0f * l - var_2;
          newColor.r = clamp((float)(255.0f * ConvertHueToRGB(var_1, var_2, fH + div1s3) ), 0.0f, 255.0f);
          newColor.g = clamp((float)(255.0f * ConvertHueToRGB(var_1, var_2, fH) ), 0.0f, 255.0f);
          newColor.b = clamp((float)(255.0f * ConvertHueToRGB(var_1, var_2, fH - div1s3) ), 0.0f, 255.0f);
       }
       return newColor;
    };

    RGBColorI ConvertHSLtoRGBint16() {
    // http://www.had2know.com/technology/hsl-rgb-color-converter.html

       const double fH = h/360.0f;
       double var_1, var_2;
       RGBColorI newColor;
       if (s == 0)
       {
          newColor.r = clamp((float)l*65535.0f, 0.0f, 65535.0f);
          newColor.g = clamp((float)l*65535.0f, 0.0f, 65535.0f);
          newColor.b = clamp((float)l*65535.0f, 0.0f, 65535.0f);
       } else
       {
          if (l < 0.5)
             var_2 = l * (1.0f + s);
          else
             var_2 = (l + s) - (s * l);

          var_1 = 2.0f * l - var_2;
          newColor.r = clamp((float)(65535.0f * ConvertHueToRGB(var_1, var_2, fH + div1s3) ), 0.0f, 65535.0f);
          newColor.g = clamp((float)(65535.0f * ConvertHueToRGB(var_1, var_2, fH) ), 0.0f, 65535.0f);
          newColor.b = clamp((float)(65535.0f * ConvertHueToRGB(var_1, var_2, fH - div1s3) ), 0.0f, 65535.0f);
       }
       return newColor;
    };
  };

struct RGBAColor {
    int b;
    int g;
    int r;
    int a;

    // HSLColor ConvertRGBtoHSL(float iR, float iG, float iB, int isFloat) {

    HSLColor ConvertRGBtoHSL() {
       const double rf = char_to_float[r];
       const double gf = char_to_float[g];
       const double bf = char_to_float[b];
       const double minu    = min(rf, min(gf, bf));
       const double maxu    = max(rf, max(gf, bf));
       const double del_Max = maxu - minu;
       const double L       = (maxu + minu) / 2.0f;
       double H, S, del_R, del_G, del_B;

       if (del_Max == 0)
       {
          H = S = 0;
       } else
       {
          if (L < 0.5)
             S = del_Max / (maxu + minu);
          else
             S = del_Max / (2.0f - del_Max);

          del_R = (((maxu - rf) / 6.0f) + (del_Max / 2.0f)) / del_Max;
          del_G = (((maxu - gf) / 6.0f) + (del_Max / 2.0f)) / del_Max;
          del_B = (((maxu - bf) / 6.0f) + (del_Max / 2.0f)) / del_Max;
          if (rf == maxu)
          {
             H = del_B - del_G;
          } else
          {
             if (gf == maxu)
                H = div1s3 + del_R - del_B;
             else if (bf == maxu)
                H = div2s3 + del_G - del_R;
          }
          if (H < 0)
             H += 1.0f;
          if (H > 1)
             H -= 1.0f;
       }

       return {abs(H*360.0f), abs(S), abs(L)};
    }

    void channelOffset(const int &ao, const int &ro, const int &go, const int &bo) {
        a = clamp(a + ao, 0, 255);
        r = clamp(r + ro, 0, 255);
        g = clamp(g + go, 0, 255);
        b = clamp(b + bo, 0, 255);
    }

    void threshold(const int &ao, const int &ro, const int &go, const int &bo, const int &seeThrough) {
        if (seeThrough==2)
        {
           if (ao>=0)
              a = (a>ao) ? a : 0;
           if (ro>=0)
              r = (r>ro) ? r : 0;
           if (go>=0)
              g = (g>go) ? g : 0;
           if (bo>=0)
              b = (b>bo) ? b : 0;
       } else if (seeThrough==3)
       {
          if (ao>=0)
             a = (a>ao) ? 255 : a;
          if (ro>=0)
             r = (r>ro) ? 255 : r;
          if (go>=0)
             g = (g>go) ? 255 : g;
          if (bo>=0)
             b = (b>bo) ? 255 : b;
      } else
      {
         if (ao>=0)
            a = (a>ao) ? 255 : 0;
         if (ro>=0)
            r = (r>ro) ? 255 : 0;
         if (go>=0)
            g = (g>go) ? 255 : 0;
         if (bo>=0)
            b = (b>bo) ? 255 : 0;
      }
    }

    void invert() {
        r = 255 - r;
        g = 255 - g;
        b = 255 - b;
    }

    void blackPoint(const int &level, const int &noise) {
        const int rando = (noise==1) ? rand() % 10 : 0;
        r = max(r, level + rando);
        g = max(g, level + rando);
        b = max(b, level + rando);
    }

    void whitePoint(const int &level, const int &noise) {
        const int rando = (noise==1) ? rand() % 10 : 0;
        r = min(r, level - rando);
        g = min(g, level - rando);
        b = min(b, level - rando);
    }

    void brightness(const int &level, const int &altMode) {
        if (altMode==0)
        {
           if (level<0)
           {
              r = LUTgammaBright[r];
              g = LUTgammaBright[g];
              b = LUTgammaBright[b];
           }
           r = clamp(r + level, 0, 255);
           g = clamp(g + level, 0, 255);
           b = clamp(b + level, 0, 255);
       } else
       {
           r = LUTbright[r];
           g = LUTbright[g];
           b = LUTbright[b];
       }
    }

    void shadows(const int &altMode, const int &linearGamma, int gray) {
       int nr, ng, nb;
       if (altMode==1)
          gray = clamp(255 - gray, 0, 255);
       else
          gray = clamp(255 - (gray*2), 0, 255);

       nr = LUTshadows[r];
       ng = LUTshadows[g];
       nb = LUTshadows[b];
       float fintensity = char_to_float[gray];
       if (linearGamma==1)
       {
          fintensity += 0.1;
          r = linear_to_gamma[weighTwoValues(gamma_to_linear[nr], gamma_to_linear[r], fintensity)];
          g = linear_to_gamma[weighTwoValues(gamma_to_linear[ng], gamma_to_linear[g], fintensity)];
          b = linear_to_gamma[weighTwoValues(gamma_to_linear[nb], gamma_to_linear[b], fintensity)];
       } else
       {
          r = weighTwoValues(nr, r, fintensity);
          g = weighTwoValues(ng, g, fintensity);
          b = weighTwoValues(nb, b, fintensity);
       }
    }

    void highlights(const int &altMode, const int &linearGamma, const float &factor, int gray) {
       int nr, ng, nb;
       if (altMode==1)
          gray = contraMaths(gray*1.5f, factor, 128);
       else
          gray = contraMaths(gray, factor, 128);

       nr = LUThighs[r];
       ng = LUThighs[g];
       nb = LUThighs[b];
       float fintensity = char_to_float[gray];
       if (linearGamma==1)
       {
          r = linear_to_gamma[weighTwoValues(gamma_to_linear[nr], gamma_to_linear[r], fintensity)];
          g = linear_to_gamma[weighTwoValues(gamma_to_linear[ng], gamma_to_linear[g], fintensity)];
          b = linear_to_gamma[weighTwoValues(gamma_to_linear[nb], gamma_to_linear[b], fintensity)];
       } else
       {
          r = weighTwoValues(nr, r, fintensity);
          g = weighTwoValues(ng, g, fintensity);
          b = weighTwoValues(nb, b, fintensity);
       }
    }

    void gamma() {
        r = LUTgamma[r];
        g = LUTgamma[g];
        b = LUTgamma[b];
    }

    void contrast(const int &level, const int &altContra, const int &linearGamma, const float &fintensity) {
        if (altContra==1)
        {
           a = LUTcontra[a];
           return;
        }

        if (level>0)
        {
           int gray = getGrayscale(r, g, b);
           if (linearGamma==1)
           {
              r = linear_to_gamma[weighTwoValues(gamma_to_linear[gray], gamma_to_linear[r], fintensity)];
              g = linear_to_gamma[weighTwoValues(gamma_to_linear[gray], gamma_to_linear[g], fintensity)];
              b = linear_to_gamma[weighTwoValues(gamma_to_linear[gray], gamma_to_linear[b], fintensity)];
           } else
           {
              r = weighTwoValues(gray, r, fintensity);
              g = weighTwoValues(gray, g, fintensity);
              b = weighTwoValues(gray, b, fintensity);
           }
        }

        r = LUTcontra[r];
        g = LUTcontra[g];
        b = LUTcontra[b];
    }

    void saturation(const int &level, const int &altMode, const int &linearGamma, float saturation) {
        if (altMode>1)
        {
           int gray = (altMode==2) ? r : g;
           if (altMode==3)
              gray = b;
           r = gray;
           g = gray;
           b = gray;
        } else if (altMode==1)
        {
            HSLColor HSLu = ConvertRGBtoHSL();
            saturation = (level<0) ? 0.001 : saturation;
            HSLColor newHSL = {HSLu.h, saturation, HSLu.l};
            RGBColorI newRGB = newHSL.ConvertHSLtoRGB();
            float fi;
            if (inRange(0, 16384, level))
               fi = level/16384.0f;
            else if (inRange(-65535, 0, level))
               fi = abs(level)/65535.0f;

            if (inRange(-65535, 16384, level))
            {
               r = weighTwoValues(newRGB.r, r, fi);
               g = weighTwoValues(newRGB.g, g, fi);
               b = weighTwoValues(newRGB.b, b, fi);
            } else
            {
               r = newRGB.r;
               g = newRGB.g;
               b = newRGB.b;
            }
        } else if (level<0)
        {
           const int gray = getGrayscale(r, g, b);
           float fintensity = int_to_float[abs(level)];
           if (linearGamma==1)
           {
              r = linear_to_gamma[weighTwoValues(gamma_to_linear[gray], gamma_to_linear[r], fintensity)];
              g = linear_to_gamma[weighTwoValues(gamma_to_linear[gray], gamma_to_linear[g], fintensity)];
              b = linear_to_gamma[weighTwoValues(gamma_to_linear[gray], gamma_to_linear[b], fintensity)];
           } else
           {
              r = weighTwoValues(gray, r, fintensity);
              g = weighTwoValues(gray, g, fintensity);
              b = weighTwoValues(gray, b, fintensity);
           }
        } else
        {
           const float max_val = max(max(r, g), b);
           const float min_val = min(min(r, g), b);
           const float luxAvg = (max_val + min_val) / 2.0f;
           const float factor = (level + 21823)/21823.0f;

           float lux = clamp(getGrayscale(r, g, b)/3.0f, 0.0f, 255.0f);
           lux = weighTwoValues(lux, 0.0f, int_to_float[level]);;

           r = clamp(round(factor * ((float)r - luxAvg) + luxAvg + lux), 0.0f, 255.0f);
           g = clamp(round(factor * ((float)g - luxAvg) + luxAvg + lux), 0.0f, 255.0f);
           b = clamp(round(factor * ((float)b - luxAvg) + luxAvg + lux), 0.0f, 255.0f);
        };
    }

    void hueRotate(const int &degrees, const float &saturation, const int &altMode, const int &level) {
        HSLColor HSLu = ConvertRGBtoHSL();
        float hue = HSLu.h + (float)degrees;
        if (hue>360)
           hue -= 360.0f;

        HSLColor newHSL = {hue, HSLu.s + 0.01, HSLu.l};
        RGBColorI newRGB = newHSL.ConvertHSLtoRGB();
        float fi;
        if (inRange(0, 15, degrees))
           fi = degrees/15.0f;
        else if (inRange(-15, 0, degrees))
           fi = abs(degrees)/15.0f;

        if (inRange(-15, 15, degrees))
        {
           r = weighTwoValues(newRGB.r, r, fi);
           g = weighTwoValues(newRGB.g, g, fi);
           b = weighTwoValues(newRGB.b, b, fi);
        } else
        {
           r = newRGB.r;
           g = newRGB.g;
           b = newRGB.b;
        }
    }

    void tinto(const int &degrees, const int &level, const int &linearGamma) {
        HSLColor HSLu = ConvertRGBtoHSL();
        HSLColor newHSL = {degrees, 0.5, HSLu.l};
        RGBColorI newRGB = newHSL.ConvertHSLtoRGB();
        const float fintensity = int_to_float[level];
        if (linearGamma==1)
        {
           r = linear_to_gamma[weighTwoValues(gamma_to_linear[newRGB.r], gamma_to_linear[r], fintensity)];
           g = linear_to_gamma[weighTwoValues(gamma_to_linear[newRGB.g], gamma_to_linear[g], fintensity)];
           b = linear_to_gamma[weighTwoValues(gamma_to_linear[newRGB.b], gamma_to_linear[b], fintensity)];
        } else
        {
           r = weighTwoValues(newRGB.r, r, fintensity);
           g = weighTwoValues(newRGB.g, g, fintensity);
           b = weighTwoValues(newRGB.b, b, fintensity);
        }
    }

    void tint(const float &hue, int &level, int &altMode, int &linearGamma) {
        if (altMode==1)
           return tinto(hue, level, linearGamma);

        int z = getGrayscale(r, g, b);
        float gray = char_to_float[z];
        const int hi = (int)(floor(hue / 60.0f)) % 6;
        const float f = hue / 60.0f - floor(hue / 60.0f);
        const float q = gray * (1.0f - f);
        const float t = gray * (1.0f - (1.0f - f));
        int nr, ng, nb;
        switch (hi) {
            case 0:
                nr = z;
                ng = t * 255.0f;
                nb = 0;
                break;
            case 1:
                nr = q * 255.0f;
                ng = z;
                nb = 0;
                break;
            case 2:
                nr = 0;
                ng = z;
                nb = t * 255.0f;
                break;
            case 3:
                nr = 0;
                ng = q * 255.0f;
                nb = z;
                break;
            case 4:
                nr = t * 255.0f;
                ng = 0;
                nb = z;
                break;
            case 5:
                nr = z;
                ng = 0;
                nb = q * 255.0f;
                break;
        }

        z = z/3; // gray
        const float fintensity = int_to_float[level];
        nr = clamp(nr + z, 0, 255);
        ng = clamp(ng + z, 0, 255);
        nb = clamp(nb + z, 0, 255);
        if (linearGamma==1)
        {
           r = linear_to_gamma[weighTwoValues(gamma_to_linear[nr], gamma_to_linear[r], fintensity)];
           g = linear_to_gamma[weighTwoValues(gamma_to_linear[ng], gamma_to_linear[g], fintensity)];
           b = linear_to_gamma[weighTwoValues(gamma_to_linear[nb], gamma_to_linear[b], fintensity)];
        } else
        {
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
        }
    }
};


struct RGBA16color {
    int b, g, r, a;

    HSLColor ConvertRGBtoHSL() {
       const double rf = int_to_float[r];
       const double gf = int_to_float[g];
       const double bf = int_to_float[b];
       const double minu    = min(rf, min(gf, bf));
       const double maxu    = max(rf, max(gf, bf));
       const double del_Max = maxu - minu;
       const double L       = (maxu + minu) / 2.0f;
       double H, S;

       if (del_Max == 0)
       {
          H = S = 0;
       } else
       {
          if (L < 0.5)
             S = del_Max / (maxu + minu);
          else
             S = del_Max / (2.0f - del_Max);

          const double del_R = (((maxu - rf) / 6.0f) + (del_Max / 2.0f)) / del_Max;
          const double del_G = (((maxu - gf) / 6.0f) + (del_Max / 2.0f)) / del_Max;
          const double del_B = (((maxu - bf) / 6.0f) + (del_Max / 2.0f)) / del_Max;
          if (rf == maxu)
          {
             H = del_B - del_G;
          } else
          {
             if (gf == maxu)
                H = div1s3 + del_R - del_B;
             else if (bf == maxu)
                H = div2s3 + del_G - del_R;
          }
          if (H < 0)
             H += 1.0f;
          if (H > 1)
             H -= 1.0f;
       }

       return {abs(H*360.0f), abs(S), abs(L)};
    }

    void channelOffset(const int &ao, const int &ro, const int &go, const int &bo, const int &noClamping) {
        a = clamp(a + ao, 0, 65535);
        r = (noClamping==1) ? r + ro : clamp(r + ro, 0, 65535);
        g = (noClamping==1) ? g + go : clamp(g + go, 0, 65535);
        b = (noClamping==1) ? b + bo : clamp(b + bo, 0, 65535);
    }

    void threshold(const int &ao, const int &ro, const int &go, const int &bo, const int &seeThrough) {
        if (seeThrough==2)
        {
           if (ao>=0)
              a = (a>ao) ? a : 0;
           if (ro>=0)
              r = (r>ro) ? r : 0;
           if (go>=0)
              g = (g>go) ? g : 0;
           if (bo>=0)
              b = (b>bo) ? b : 0;
       } else if (seeThrough==3)
       {
          if (ao>=0)
             a = (a>ao) ? 65535 : a;
          if (ro>=0)
             r = (r>ro) ? 65535 : r;
          if (go>=0)
             g = (g>go) ? 65535 : g;
          if (bo>=0)
             b = (b>bo) ? 65535 : b;
      } else
      {
         if (ao>=0)
            a = (a>ao) ? 65535 : 0;
         if (ro>=0)
            r = (r>ro) ? 65535 : 0;
         if (go>=0)
            g = (g>go) ? 65535 : 0;
         if (bo>=0)
            b = (b>bo) ? 65535 : 0;
      }
    }

    void invert() {
        r = 65535 - r;
        g = 65535 - g;
        b = 65535 - b;
    }

    void blackPoint(const int &level, const int &noise) {
        const int rando = (noise==1) ? rand() % 2600 : 0;
        r = max(r, level + rando);
        g = max(g, level + rando);
        b = max(b, level + rando);
    }

    void whitePoint(const int &level, const int &noise) {
        const int rando = (noise==1) ? rand() % 2600 : 0;
        r = min(r, level - rando);
        g = min(g, level - rando);
        b = min(b, level - rando);
    }

    void brightness(const int &level, const int &altMode, const int &noClamping, const float &fintensity) {
        if (altMode==0)
        {
           if (level<0 && noClamping==0)
           {
              r = LUTgammaBright[r];
              g = LUTgammaBright[g];
              b = LUTgammaBright[b];
           }
           r = (noClamping==1) ? r + level : clamp(r + level, 0, 65535);
           g = (noClamping==1) ? g + level : clamp(g + level, 0, 65535);
           b = (noClamping==1) ? b + level : clamp(b + level, 0, 65535);
       } else
       {
           if (noClamping==1)
           {
              // float fintensity = (level>0) ? level/32768.0f : -1*int_to_float[-1*level];
              r = r + (float)r*fintensity;
              g = g + (float)g*fintensity;
              b = b + (float)b*fintensity;
           } else
           {
              r = LUTbright[r];
              g = LUTbright[g];
              b = LUTbright[b];
           }
       }
    }

    int getGrayscaleAdvanced() {
       const float minu = min(r, min(g, b));
       float maxu = max(r, max(g, b));
       float nr = r;
       float ng = g;
       float nb = b;
       if (minu<0)
       {
          nr = r + minu;
          ng = g + minu;
          nb = b + minu;
       }
       if (maxu<65535)
          maxu = 65535.0f;

       nr = nr*0.299701f;
       ng = ng*0.587130f;
       nb = nb*0.114180f;
       int gray = nr + ng + nb;
       if (gray>maxu)
          gray = maxu;

       return gray;
    }

    void shadows(const int &level, const int &altMode, const int &linearGamma, int gray, const int &noClamping, const float &fi) {
       int nr, ng, nb;
       if (noClamping==1)
       {
           float maxu = max(r, max(g, b));
           float minu = min(r, min(g, b));
           if (maxu<65535)
              maxu = 65535.0f;

           nr = r + (float)r*fi;
           ng = g + (float)g*fi;
           nb = b + (float)b*fi;
           float gz = getGrayscaleAdvanced();
           if (altMode!=1)
              gz = gz*2.0f;

           float fintensity = 1.0f - (gz / maxu);
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
       } else
       {
           if (altMode==1)
              gray = clamp(65535 - gray, 0, 65535);
           else
              gray = clamp(65535 - (gray*2), 0, 65535);

           nr = LUTshadows[r];
           ng = LUTshadows[g];
           nb = LUTshadows[b];
           float fintensity = int_to_float[gray];
           if (linearGamma==1)
           {
              fintensity += 0.1;
              r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nr], gamma_to_linearInt16[r], fintensity)];
              g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[ng], gamma_to_linearInt16[g], fintensity)];
              b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nb], gamma_to_linearInt16[b], fintensity)];
           } else
           {
              r = weighTwoValues(nr, r, fintensity);
              g = weighTwoValues(ng, g, fintensity);
              b = weighTwoValues(nb, b, fintensity);
           }
       }
    }

    void highlights(const int &level, const int &altMode, const int &linearGamma, const float &factor, int gray, const int &noClamping, const float &fi) {
       int nr, ng, nb;
       if (noClamping==1)
       {
           float maxu = max(r, max(g, b));
           if (maxu<65535)
              maxu = 65535.0f;

           nr = r + (float)r*fi;
           ng = g + (float)g*fi;
           nb = b + (float)b*fi;
           float gz = getGrayscaleAdvanced();
           if (altMode==1)
              gz = gz*1.25f;
           else
              gz = gz/1.25f;

           float fintensity = gz / (maxu/1.5f);
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
       } else
       {
           if (altMode==1)
              gray = contraMathsInt16(gray*1.5f, factor, 32768);
           else
              gray = contraMathsInt16(gray, factor, 32768);

           nr = LUThighs[r];
           ng = LUThighs[g];
           nb = LUThighs[b];
           float fintensity = int_to_float[gray];
           if (linearGamma==1)
           {
              r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nr], gamma_to_linearInt16[r], fintensity)];
              g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[ng], gamma_to_linearInt16[g], fintensity)];
              b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nb], gamma_to_linearInt16[b], fintensity)];
           } else
           {
              r = weighTwoValues(nr, r, fintensity);
              g = weighTwoValues(ng, g, fintensity);
              b = weighTwoValues(nb, b, fintensity);
           }
       }
    }

    void gamma(const int &level, const int &bright, const int &altMode, const int &noClamping) {
      if (noClamping==0)
      {
         r = LUTgamma[r];
         g = LUTgamma[g];
         b = LUTgamma[b];
      } else
      {
         const float minu = min(r, min(g, b));
         float maxu = max(r, max(g, b));
         float nr = r;
         float ng = g;
         float nb = b;
         float offset = 0;
         if (minu<0)
         {
            nr = r + minu;
            ng = g + minu;
            nb = b + minu;
            offset = minu;
         }
         if (maxu<65535)
            maxu = 65535.0f;  

         nr = (float)nr / maxu;
         ng = (float)ng / maxu;
         nb = (float)nb / maxu;

         const int thisLevel = (bright<0 && altMode==0 && level>300) ? level + abs(bright)/300 : level;
         const double gamma = 1.0f / ((float)thisLevel/300.0f);
         r = (maxu - offset) * pow(nr, gamma);
         if (r<-165535 && bright<0 && altMode==0)
            r = -165535;

         g = (maxu - offset) * pow(ng, gamma);
         if (g<-165535 && bright<0 && altMode==0)
            g = -165535;

         b = (maxu - offset) * pow(nb, gamma);
         if (b<-165535 && bright<0 && altMode==0)
            b = -165535;
      }
    }

    void contrast(const int &level, const int &altContra, const int &linearGamma, const float &fintensity, const int &noClamping, const float &fip) {
        if (altContra==1)
        {
           a = LUTcontra[a];
           return;
        }

        if (noClamping==1)
        {
           const float minu = min(r, min(g, b));
           float maxu = max(r, max(g, b));
           float nr = r;
           float ng = g;
           float nb = b;
           float offset = 0;
           const float thisMin = (level>0) ? minu : abs(minu);
           float fi;
           if (level>=0)
           {
              int gray = getGrayscaleAdvanced();
              nr = weighTwoValues(gray, r, fintensity);
              ng = weighTwoValues(gray, g, fintensity);
              nb = weighTwoValues(gray, b, fintensity);
              if (level<19500)
              {
                 fi = level/19500.0f;
                 r = weighTwoValues(nr, r, fi);
                 g = weighTwoValues(ng, g, fi);
                 b = weighTwoValues(nb, b, fi);
             } else
             {
                 r = nr;
                 g = ng;
                 b = nb;
             }
           }

           if (minu<0)
           {
              nr = r + thisMin;
              ng = g + thisMin;
              nb = b + thisMin;
              offset = thisMin*2 + level;
           }
    
           if (maxu<65535)
              maxu = 65535.0f;
    
           float mid = maxu/2.0f;
           if (level>0)
           {
              nr = floor( (float)fip * (nr - mid) ) + mid - offset;
              ng = floor( (float)fip * (ng - mid) ) + mid - offset;
              nb = floor( (float)fip * (nb - mid) ) + mid - offset;
              if (level<16000)
              {
                 // level = clamp(level, 0, 16000);
                 fi = level/16000.0f;
                 r = weighTwoValues(nr, r, fip);
                 g = weighTwoValues(ng, g, fip);
                 b = weighTwoValues(nb, b, fip);
              } else
              {
                 r = nr;
                 g = ng;
                 b = nb;
              }
           } else
           {
              r = weighTwoValues(r, 32768, fip);
              g = weighTwoValues(g, 32768, fip);
              b = weighTwoValues(b, 32768, fip);
           }
        } else
        {
           // clamped mode
           if (level>0)
           {
              int gray = getInt16grayscale(r, g, b);
              if (linearGamma==1)
              {
                 r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[r], fintensity)];
                 g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[g], fintensity)];
                 b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[b], fintensity)];
              } else
              {
                 r = weighTwoValues(gray, r, fintensity);
                 g = weighTwoValues(gray, g, fintensity);
                 b = weighTwoValues(gray, b, fintensity);
              }
           }
   
           r = LUTcontra[r];
           g = LUTcontra[g];
           b = LUTcontra[b];
        }
    }

    void saturation(const int &level, const int &altMode, const int &linearGamma, float saturation) {
        if (altMode>1)
        {
           int gray = (altMode==2) ? r : g;
           if (altMode==3)
              gray = b;
           r = gray;
           g = gray;
           b = gray;
        } else if (altMode==1)
        {
            HSLColor HSLu = ConvertRGBtoHSL();
            saturation = (level<0) ? 0.001 : saturation;
            HSLColor newHSL = {HSLu.h, saturation, HSLu.l};
            RGBColorI newRGB = newHSL.ConvertHSLtoRGBint16();
            float fi;
            if (inRange(0, 16384, level))
               fi = level/16384.0f;
            else if (inRange(-65535, 0, level))
               fi = abs(level)/65535.0f;

            if (inRange(-65535, 16384, level))
            {
               r = weighTwoValues(newRGB.r, r, fi);
               g = weighTwoValues(newRGB.g, g, fi);
               b = weighTwoValues(newRGB.b, b, fi);
            } else
            {
               r = newRGB.r;
               g = newRGB.g;
               b = newRGB.b;
            }
        } else if (level<0)
        {
           const int gray = getInt16grayscale(r, g, b);
           const float fintensity = int_to_float[abs(level)];
           if (linearGamma==1)
           {
              r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[r], fintensity)];
              g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[g], fintensity)];
              b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[gray], gamma_to_linearInt16[b], fintensity)];
           } else
           {
              r = weighTwoValues(gray, r, fintensity);
              g = weighTwoValues(gray, g, fintensity);
              b = weighTwoValues(gray, b, fintensity);
           }
        } else
        {
           const float max_val = max(max(r, g), b);
           const float min_val = min(min(r, g), b);
           const float luxAvg = (max_val + min_val) / 2.0f;
           const float factor = (level + 21823)/21823.0f;

           float lux = clamp(getInt16grayscale(r, g, b)/3.0f, 0.0f, 65535.0f);
           lux = weighTwoValues(lux, 0.0f, int_to_float[level]);

           r = clamp(factor * ((float)r - luxAvg) + luxAvg + lux, 0.0f, 65535.0f);
           g = clamp(factor * ((float)g - luxAvg) + luxAvg + lux, 0.0f, 65535.0f);
           b = clamp(factor * ((float)b - luxAvg) + luxAvg + lux, 0.0f, 65535.0f);
        };
    }

    void hueRotate(const int &degrees, const float &saturation, const int &altMode, const int &level) {
        HSLColor HSLu = ConvertRGBtoHSL();
        float hue = HSLu.h + (float)degrees;
        if (hue>360)
           hue -= 360.0f;

        HSLColor newHSL = {hue, HSLu.s + 0.01, HSLu.l};
        RGBColorI newRGB = newHSL.ConvertHSLtoRGBint16();
        float fi;
        if (inRange(0, 15, degrees))
           fi = degrees/15.0f;
        else if (inRange(-15, 0, degrees))
           fi = abs(degrees)/15.0f;
        
        if (inRange(-15, 15, degrees))
        {
           r = weighTwoValues(newRGB.r, r, fi);
           g = weighTwoValues(newRGB.g, g, fi);
           b = weighTwoValues(newRGB.b, b, fi);
        } else
        {
           r = newRGB.r;
           g = newRGB.g;
           b = newRGB.b;
        }
    }

    void tinto(const int &degrees, const int &level, const int &linearGamma) {
        HSLColor HSLu = ConvertRGBtoHSL();
        HSLColor newHSL = {degrees, 0.5, HSLu.l};
        RGBColorI newRGB = newHSL.ConvertHSLtoRGBint16();
        const float fintensity = int_to_float[level];
        if (linearGamma==1)
        {
           r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[newRGB.r], gamma_to_linearInt16[r], fintensity)];
           g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[newRGB.g], gamma_to_linearInt16[g], fintensity)];
           b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[newRGB.b], gamma_to_linearInt16[b], fintensity)];
        } else
        {
           r = weighTwoValues(newRGB.r, r, fintensity);
           g = weighTwoValues(newRGB.g, g, fintensity);
           b = weighTwoValues(newRGB.b, b, fintensity);
        }
    }

    void tint(const float &hue, const int &level, const int &altMode, const int &linearGamma) {
        if (altMode==1)
           return tinto(hue, level, linearGamma);

        int z = getInt16grayscale(r, g, b);
        const float gray = int_to_float[z];
        const int hi = (int)(floor(hue / 60.0f)) % 6;
        const float f = hue / 60.0f - floor(hue / 60.0f);
        const float q = gray * (1.0f - f);
        const float t = gray * (1.0f - (1.0f - f));
        int nr, ng, nb;
        switch (hi) {
            case 0:
                nr = z;
                ng = t * 65535.0f;
                nb = 0;
                break;
            case 1:
                nr = q * 65535.0f;
                ng = z;
                nb = 0;
                break;
            case 2:
                nr = 0;
                ng = z;
                nb = t * 65535.0f;
                break;
            case 3:
                nr = 0;
                ng = q * 65535.0f;
                nb = z;
                break;
            case 4:
                nr = t * 65535.0f;
                ng = 0;
                nb = z;
                break;
            case 5:
                nr = z;
                ng = 0;
                nb = q * 65535.0f;
                break;
        }

        z = z/3; // gray
        const float fintensity = int_to_float[level];
        nr = clamp(nr + z, 0, 65535);
        ng = clamp(ng + z, 0, 65535);
        nb = clamp(nb + z, 0, 65535);
        if (linearGamma==1)
        {
           r = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nr], gamma_to_linearInt16[r], fintensity)];
           g = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[ng], gamma_to_linearInt16[g], fintensity)];
           b = linear_to_gammaInt16[weighTwoValues(gamma_to_linearInt16[nb], gamma_to_linearInt16[b], fintensity)];
        } else
        {
           r = weighTwoValues(nr, r, fintensity);
           g = weighTwoValues(ng, g, fintensity);
           b = weighTwoValues(nb, b, fintensity);
        }
    }
};

