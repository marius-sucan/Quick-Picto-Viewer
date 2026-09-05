// callwndproc-hook.h
//
// The native WH_CALLWNDPROC procedure behind the script's menu machinery
// [lib/module-interface.ahk: uiInstallSentMsgHook / uiSentMenuMsg / uiCallWndProcWork].
//
// Why the procedure lives here and not in the script. Since the interface-thread
// merge the script drives its native menus from the messages Windows SENDS to
// the menu owner during a modal menu loop: WM_INITMENUPOPUP for the just-in-time
// dropdown rebuilds, WM_MENUSELECT for the reader, WM_ENTERMENULOOP and
// WM_EXITMENULOOP for the menu-scoped mouse hook and the flyout ticker. OnMessage
// monitors cannot see them - AutoHotkey launches no script thread while a menu of
// the interpreter is being tracked - so a WH_CALLWNDPROC hook is the only vehicle.
// A hook procedure written as a RegisterCallback runs interpreter lines for EVERY
// message sent to any window of the thread, and Line::ExecUntil closes an open
// clipboard at the head of every line it executes. The WM_DESTROYCLIPBOARD that
// EmptyClipboard() sends to our own window while "Clipboard := text" is
// half-written therefore closed the clipboard under the write: SetClipboardData
// failed, the clipboard came out empty and every other copy failed [2026-09-05].
// With the procedure here, the interpreter is entered only for the messages the
// script asked for.
//
// Threading. qpvHookSentMessages() binds the hook to the CALLING thread - the
// script's UI thread - and every call into the procedure happens on that thread,
// inside the SendMessage that delivers the message. No other thread touches this
// state, so there is no locking. The callback is a RegisterCallback "F" address
// the script keeps alive for the life of the process.
//
// Usage from AHK [after initQPVmainDLL() loaded the DLL]:
//    qpvHookSentMessages(callbackAddr, &msgList, count)   returns the HHOOK, 0 on failure
//    qpvUnhookSentMessages()                              1 removed, 0 nothing to remove
//
// written by Marius Șucan with Claude Fable 5.1

#ifndef QPV_CALLWNDPROC_HOOK_H
#define QPV_CALLWNDPROC_HOOK_H

// The script callback, in OnMessage parameter order [wParam, lParam, msg, hwnd]
// so the handler reads like every other message handler in the module. Its
// return value is dropped: Windows ignores what a CALLWNDPROC hook returns.
typedef UINT_PTR (DLL_CALLCONV *QPV_SENTMSG_CALLBACK)(UINT_PTR wParam, UINT_PTR lParam, UINT_PTR msg, UINT_PTR hwnd);

#define QPV_SENTMSG_MAX_FILTER 16

static HHOOK                qpvSentMsgHook = NULL;
static QPV_SENTMSG_CALLBACK qpvSentMsgCallback = NULL;
static UINT                 qpvSentMsgFilter[QPV_SENTMSG_MAX_FILTER];
static int                  qpvSentMsgFilterCount = 0;

static LRESULT CALLBACK qpvSentMsgHookProc(int nCode, WPARAM wParam, LPARAM lParam) {
// Windows calls this before the window procedure of any window of the hooked
// thread receives a SENT message; lParam is the CWPSTRUCT. A negative nCode must
// be passed on untouched. Only a message on the script's list reaches the script.
    if (nCode >= 0 && lParam && qpvSentMsgCallback) {
        const CWPSTRUCT *cwp = reinterpret_cast<const CWPSTRUCT *>(lParam);
        for (int i = 0; i < qpvSentMsgFilterCount; i++) {
            if (qpvSentMsgFilter[i] == cwp->message) {
                // DebugView trace of every forwarded message, next to the script's own
                // "QPV: MERGE: sent msg" line - the pair shows where a message is lost
                char trace[128];
                wsprintfA(trace, "QPV: DLL hook fwd 0x%X w=%p l=%p h=%p", cwp->message, (void *)cwp->wParam, (void *)cwp->lParam, (void *)cwp->hwnd);
                OutputDebugStringA(trace);
                qpvSentMsgCallback((UINT_PTR)cwp->wParam, (UINT_PTR)cwp->lParam, (UINT_PTR)cwp->message, (UINT_PTR)cwp->hwnd);
                break;
            }
        }
    }
    return CallNextHookEx(qpvSentMsgHook, nCode, wParam, lParam);
}

DLL_API UINT_PTR DLL_CALLCONV qpvHookSentMessages(UINT_PTR callback, const UINT *messages, int count) {
// Installs the WH_CALLWNDPROC hook on the CALLING thread, or re-targets an
// installed one: the callback and the list [1..QPV_SENTMSG_MAX_FILTER message
// numbers, copied here] are replaced together. Returns the HHOOK, or 0 when the
// arguments are unusable or SetWindowsHookEx failed [GetLastError tells why]; the
// script then keeps its own hook procedure. hMod is NULL because the procedure
// belongs to the calling process and the thread is one of its own.
    if (!callback || !messages || count < 1 || count > QPV_SENTMSG_MAX_FILTER)
        return 0;
    for (int i = 0; i < count; i++)
        qpvSentMsgFilter[i] = messages[i];
    qpvSentMsgFilterCount = count;
    qpvSentMsgCallback = reinterpret_cast<QPV_SENTMSG_CALLBACK>(callback);
    if (!qpvSentMsgHook)
        qpvSentMsgHook = SetWindowsHookExW(WH_CALLWNDPROC, qpvSentMsgHookProc, NULL, GetCurrentThreadId());
    if (!qpvSentMsgHook) {
        qpvSentMsgCallback = NULL;
        qpvSentMsgFilterCount = 0;
    }
    char trace[128];
    wsprintfA(trace, "QPV: DLL hook install thread=%u hook=%p count=%d cb=%p", GetCurrentThreadId(), (void *)qpvSentMsgHook, count, (void *)callback);
    OutputDebugStringA(trace);
    return (UINT_PTR)qpvSentMsgHook;
}

DLL_API int DLL_CALLCONV qpvUnhookSentMessages() {
// Removes the hook: 1 on success, 0 when nothing was installed or the unhook
// failed. DllMain runs it on a dynamic unload too, so the procedure can never
// outlive its code.
    if (!qpvSentMsgHook)
        return 0;
    BOOL ok = UnhookWindowsHookEx(qpvSentMsgHook);
    qpvSentMsgHook = NULL;
    qpvSentMsgCallback = NULL;
    qpvSentMsgFilterCount = 0;
    return ok ? 1 : 0;
}

#endif // QPV_CALLWNDPROC_HOOK_H
