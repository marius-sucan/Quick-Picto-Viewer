// dllmain.cpp : Définit le point d'entrée de l'application DLL.
#include "pch.h"

// callwndproc-hook.h [qpv-main.cpp]: the WH_CALLWNDPROC hook behind the menus
extern "C" __declspec(dllexport) int __stdcall qpvUnhookSentMessages();

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
        // NOTHING may run here: lpReserved is NULL for every thread attach and
        // detach as well, and this DLL starts and ends threads all the time
        // [thumbnails pool, WIC, OpenMP]. A fall-through into the unhook below
        // [2026-09-05] destroyed the menu hook a moment after it was installed.
        break;
    case DLL_PROCESS_DETACH:
        // A dynamic unload [lpReserved == NULL] with the WH_CALLWNDPROC hook still
        // installed would leave Windows calling code that is gone; at process exit
        // [lpReserved != NULL] the system tears the hook down itself.
        if (lpReserved == NULL)
            qpvUnhookSentMessages();
        break;
    }
    return TRUE;
}

