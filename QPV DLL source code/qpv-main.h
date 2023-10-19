// Le bloc ifdef suivant est la façon standard de créer des macros qui facilitent l'exportation
// à partir d'une DLL plus simple. Tous les fichiers contenus dans cette DLL sont compilés avec le symbole QPVMAIN_EXPORTS
// défini sur la ligne de commande. Ce symbole ne doit pas être défini pour un projet
// qui utilise cette DLL. Ainsi, les autres projets dont les fichiers sources comprennent ce fichier considèrent les fonctions
// QPVMAIN_API comme étant importées à partir d'une DLL, tandis que cette DLL considère les symboles
// définis avec cette macro comme étant exportés.

#define DLL_API extern "C" __declspec(dllexport)
#define DLL_CALLCONV __stdcall
#define GDIPVER 0x110
#define cimg_use_openmp 1
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
static unsigned short gamma_to_linear[256];
static unsigned char linear_to_gamma[32769];
static float char_to_float[256];

IWICImagingFactory *m_pIWICFactory;
IWICBitmapDecoder *pWICclassDecoder;
IWICBitmapFrameDecode *pWICclassFrameDecoded;
// IWICFormatConverter *pWICclassConverter;
IWICBitmapSource *pWICclassPixelsBitmapSource;



std::vector<UINT>  dupesListIDsA(1);
std::vector<UINT>  dupesListIDsB(1);
std::vector<UINT>  dupesListIDsC(1);
// std::unordered_map<UINT, unsigned char>  brushMoveImgData(1);

std::array<double, 1025>  DCTcoeffs;

// for the Windows 7 dll edition
// DEFINE_GUID(GUID_ContainerFormatDds,  0x9967cb95, 0x2e85, 0x4ac8, 0x8c, 0xa2, 0x83, 0xd7, 0xcc, 0xd4, 0x25, 0xc9);
// DEFINE_GUID(GUID_ContainerFormatAdng, 0xf3ff6d0d, 0x38c0, 0x41c4, 0xb1, 0xfe, 0x1f, 0x38, 0x24, 0xf1, 0x7b, 0x84);
// DEFINE_GUID(GUID_ContainerFormatHeif, 0xe1e62521, 0x6787, 0x405b, 0xa3, 0x39, 0x50, 0x07, 0x15, 0xb5, 0x76, 0x3f);
// DEFINE_GUID(GUID_ContainerFormatWebp, 0xe094b0e2, 0x67f2, 0x45b3, 0xb0, 0xea, 0x11, 0x53, 0x37, 0xca, 0x7c, 0xf3);
// DEFINE_GUID(GUID_ContainerFormatRaw,  0xfe99ce60, 0xf19c, 0x433c, 0xa3, 0xae, 0x00, 0xac, 0xef, 0xa9, 0xca, 0x21);

// DEFINE_GUID(GUID_WICPixelFormat32bppRGB,  0xd98c6b95, 0x3efe, 0x47d6, 0xbb, 0x25, 0xeb, 0x17, 0x48, 0xab, 0x0c, 0xf1);
// DEFINE_GUID(GUID_WICPixelFormat64bppRGB,   0xa1182111, 0x186d, 0x4d42, 0xbc, 0x6a, 0x9c, 0x83, 0x03, 0xa8, 0xdf, 0xf9);
// DEFINE_GUID(GUID_WICPixelFormat96bppRGBFloat, 0xe3fed78f, 0xe8db, 0x4acf, 0x84, 0xc1, 0xe9, 0x7f, 0x61, 0x36, 0xb3, 0x27);
// DEFINE_GUID(GUID_WICPixelFormat64bppPRGBAHalf, 0x58ad26c2, 0xc623, 0x4d9d, 0xb3, 0x20, 0x38, 0x7e, 0x49, 0xf8, 0xc4, 0x42);


struct HSLColor {
    double h;
    double s;
    double l;
};

struct RGBColor {
    double r;
    double g;
    double b;
};
