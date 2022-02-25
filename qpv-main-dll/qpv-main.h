// Le bloc ifdef suivant est la façon standard de créer des macros qui facilitent l'exportation
// à partir d'une DLL plus simple. Tous les fichiers contenus dans cette DLL sont compilés avec le symbole QPVMAIN_EXPORTS
// défini sur la ligne de commande. Ce symbole ne doit pas être défini pour un projet
// qui utilise cette DLL. Ainsi, les autres projets dont les fichiers sources comprennent ce fichier considèrent les fonctions
// QPVMAIN_API comme étant importées à partir d'une DLL, tandis que cette DLL considère les symboles
// définis avec cette macro comme étant exportés.

#define DLL_API extern "C" __declspec(dllexport)
#define DLL_CALLCONV __stdcall
#define GDIPVER 0x110

const double M_PI = 3.14159265358979323846;  // PI
const double div2sz = sqrt(2.0 / 32.0);      // used in calculateDCT()
const double div2sq = 1 / sqrt(2.0);         // used in calculateDCT()

IWICImagingFactory *m_pIWICFactory;
std::vector<UINT>  dupesListIDsA(1);
std::vector<UINT>  dupesListIDsB(1);
std::vector<UINT>  dupesListIDsC(1);
std::array<double, 1025>  DCTcoeffs;

