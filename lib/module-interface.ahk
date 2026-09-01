; module-interface.ahk - the QPV user-interface module.
; Until 2026-08 this file ran as a separate AutoHotkey_H interpreter thread
; [ahkthread] so the UI stayed responsive while the main thread worked; it is now
; #Include'd at the BOTTOM of quick-picto-viewer.ahk and everything runs on one
; interpreter. initInterfaceModule() replaces the old thread auto-exec section and
; is called once from the main script startup, before BuildGUI().
; Merge plan and phase log: interface-thread-merge-plan.md

; State OWNED by this module - these names existed only in this file's interpreter
; before the merge [the 84 names both sides mirrored were deleted from here; the
; main script's Global blocks are authoritative for those]. This declaration stays
; at the TOP of the file, before any function, so the loader registers the names
; as super-globals regardless of include position. Initial values are seeded in
; initInterfaceModule() because control never flows through an #Include'd file.
Global PicOnGUI1, PicOnGUI2a, PicOnGUI2b, PicOnGUI2c, PicOnGUI3, ImgAnnoBox, ImgHistoBox, ImgInfoBox, ImgNavBox, OSDmsgsLine
     , picVscroll, picHscroll, hPic0, hPic1, hPic2, hPic3, hPic4, hPic5, hPic6, hPic7, hPic8, hPic9, hPic10, hPic11
     , hFlyOut, hFlyBtn1, hFlyBtn2, hFlyBtn3, hMenuBar, menuArray, menuCurrentIndex, menuTotalIndex, menusList
     , menusflyOutVisible, wasMenuFlierCreated, prevMenuBarItem, lastMenuBarUpdate, lastMenuHoverZeit, lastContextMenuZeit
     , allowMenuReader, taskBarUI, groppedFiles, LbtnDwn, penPressureRaw, hasPenPressureAPI
     , canCancelImageLoad, alterFilesIndex, mustAbandonCurrentOperations, userPendingAbortOperations
     , lastCloseInvoked, lastALclickX, lastALclickY, lastDoubleClickZeit, lastMouseLeave, lastSwipeZeitGesture
     , lastWinStatus, lastZeitPanCursor, lastZeitToolTip, statusBarTooltipVisible, doNormalCursor
     , prevFullIMGload, winGDIcreated, ThumbsWinGDIcreated
     , menuJITmap, menuJITlist, hCWPhook, hLLmouseHook, menuLoopActive, uiMenuReaderLastMsg, slideShowCadence, barMenuSession, menuNativeTimerID
     , flyoutNeedsPos, popupRootSeen, flyoutGraceZeit, flyoutAnchorMenu, menuNativeTimerID2

initInterfaceModule() {
; Replaces this module's old thread auto-exec: seeds the module state, detects the
; pen api and registers the input handlers. Message numbers that BOTH sides used
; to monitor go through the dispatch* composers defined below; the module-only
; numbers register their handlers directly. setPriorityThread(2) from the thread
; era is deliberately gone - there is only one thread now - and the tray icon is
; the main script's job [quick-picto-viewer.ahk sets it during its startup].

   ; module state seeds [the former Global-block initializers]
   LbtnDwn := 0, penPressureRaw := 0, canCancelImageLoad := 0, alterFilesIndex := 0
   mustAbandonCurrentOperations := 0, userPendingAbortOperations := 0, allowMenuReader := 0
   lastCloseInvoked := -1, lastALclickX := 0, lastALclickY := 0, statusBarTooltipVisible := 0
   lastContextMenuZeit := 1, lastDoubleClickZeit := 1, lastMenuBarUpdate := 1, lastMenuHoverZeit := 1
   lastMouseLeave := 1, lastSwipeZeitGesture := 1, lastZeitPanCursor := 1, lastZeitToolTip := 1
   doNormalCursor := 1, prevFullIMGload := 1, prevMenuBarItem := 1
   menusflyOutVisible := 0, wasMenuFlierCreated := 0, menuCurrentIndex := 0, menuTotalIndex := 0
   winGDIcreated := 0, ThumbsWinGDIcreated := 0
   lastWinStatus := "", menusList := "", groppedFiles := [], menuArray := []
   menuJITmap := {}, menuJITlist := [], hCWPhook := 0, hLLmouseHook := 0
   menuLoopActive := 0, uiMenuReaderLastMsg := "", slideShowCadence := 9000, barMenuSession := 0, menuNativeTimerID := 0
   flyoutNeedsPos := 0, popupRootSeen := 0, flyoutGraceZeit := 1, flyoutAnchorMenu := 0, menuNativeTimerID2 := 0
   ; "yes" matches the pre-merge de-facto state: showThisMenu passed a literal
   ; "yes" into menuFlyoutDisplay on EVERY programmatic menu open, so the reader
   ; flag was on from the first menu of a session; native bar opens never call it,
   ; and a 0 seed left bar sessions without the flyout or announcements until the
   ; first right-click menu. The "no" reset path still turns it off when main asks.
   allowMenuReader := "yes"

   ; input handlers. Module-only message numbers first:
   OnMessage(0x2a3, "WM_MOUSELEAVE")
   OnMessage(0x205, "WM_RBUTTONUP")
   OnMessage(0x207, "WM_MBUTTONDOWN")
   OnMessage(0x047, "WM_WINDOWPOSCHANGED") ; window moving
   OnMessage(0x06, "activateMainWin")   ; WM_ACTIVATE
   OnMessage(0x08, "activateMainWin")   ; WM_KILLFOCUS

   ; pen pressure [requires Windows 8 or newer]. The handler stays message-driven;
   ; the brush loops additionally drain the queue themselves while they hold
   ; Critical - see pumpPenMessages() / getBrushPenPressure().
   hasPenPressureAPI := DllCall("GetProcAddress", "UPtr", DllCall("GetModuleHandle", "Str", "user32", "UPtr"), "AStr", "GetPointerPenInfo", "UPtr") ? 1 : 0
   If (hasPenPressureAPI=1)
   {
      OnMessage(0x0245, "WM_PENpressure")  ; WM_POINTERUPDATE
      OnMessage(0x0246, "WM_PENpressure")  ; WM_POINTERDOWN
      OnMessage(0x0247, "WM_PENpressure")  ; WM_POINTERUP
      OnMessage(0x024A, "WM_PENpressure")  ; WM_POINTERLEAVE
   }

   ; keystroke-beep suppression for 0x101-0x103 and 0x105-0x108 - matching the
   ; pre-merge effective state, where the thread re-registered 0x100/0x104 onto
   ; its keyboard handler [string-mode OnMessage REPLACES, never chains]
   Loop, 9
   {
      If (A_Index=1 || A_Index=5)  ; 0x100 WM_KEYDOWN / 0x104 WM_SYSKEYDOWN
         Continue
      OnMessage(255+A_Index, "PreventKeyPressBeep")
   }

   ; [phase D] permanent same-thread WH_CALLWNDPROC hook [probes p7/p8]: receives
   ; the SENT menu messages during modal menu loops - where OnMessage monitors,
   ; timers and hotkey subroutines never run - and powers the JIT dropdown
   ; rebuilds, the menu reader and the menu-scoped wheel hook install
   Static cbCWP := 0
   If !cbCWP
      cbCWP := RegisterCallback("uiCallWndProc", "F")
   If !hCWPhook
      hCWPhook := DllCall("SetWindowsHookEx", "Int", 4, "Ptr", cbCWP, "Ptr", 0, "UInt", DllCall("GetCurrentThreadId"), "Ptr")

   ; numbers both sides monitored - composed dispatchers [see below]
   OnMessage(0x100, "dispatchKeyDown")
   OnMessage(0x104, "dispatchKeyDown")
   OnMessage(0x200, "dispatchMouseMove")
   OnMessage(0x201, "dispatchLButtonDown")
   OnMessage(0x202, "dispatchLButtonUp")
   OnMessage(0x203, "dispatchLButtonDbl")
   OnMessage(0x20A, "dispatchMouseWheel")
   OnMessage(0x20E, "dispatchMouseWheel")
}


; ______ main-thread facade [merged - phase C] ______
; The MT_* wrappers survive the merge so this module's call sites stay untouched;
; they now delegate to the IF_* facades in quick-picto-viewer.ahk - one interpreter,
; one implementation. Queued posts share IF_postRelay.

MT_post(funcName, args*) {
   fn := Func("IF_postRelay").Bind(funcName, args)
   SetTimer, % fn, -1
}

; ______ merged-thread input routing [merge phase C] ______
; Before the merge, each interpreter's OnMessage monitors received messages ONLY
; for its own windows, and every handler's guards assume exactly that universe.
; The dispatchers below preserve those universes by routing on the receiving
; window's top-level root: interface-owned roots go to the ui-side handler, all
; other windows [panels, toolbar, tooltips of the main script] go to the
; main-side handler. Never convert these to sequential chaining - the guards on
; either side were not written to see the other side's windows.

isUIrootWin(hwnd) {
   root := DllCall("user32\GetAncestor", "UPtr", hwnd, "UInt", 2, "UPtr")  ; GA_ROOT
   Return isVarEqualTo(root, PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin, hGuiTip, hFlyOut)
}

dispatchKeyDown(wP, lP, msg, hwnd) {
   If isUIrootWin(hwnd)
      Return uiWM_KEYDOWN(wP, lP, msg, hwnd)
   Return WM_KEYDOWN(wP, lP, msg, hwnd)
}

dispatchMouseMove(wP, lP, msg, hwnd) {
   If isUIrootWin(hwnd)
      Return uiWM_MOUSEMOVE(wP, lP, msg, hwnd)
   Return WM_MOUSEMOVE(wP, lP, msg, hwnd)
}

dispatchLButtonDown(wP, lP, msg, hwnd) {
   If isUIrootWin(hwnd)
      Return uiWM_LBUTTONDOWN(wP, lP, msg, hwnd)
   Return WM_LBUTTONdown(wP, lP, msg, hwnd)
}

dispatchLButtonUp(wP, lP, msg, hwnd) {
   root := DllCall("user32\GetAncestor", "UPtr", hwnd, "UInt", 2, "UPtr")  ; GA_ROOT
   If (root = hFlyOut)
      OutputDebug, % "QPVMERGE: btn-up on flyout window, flyVisible=" menusflyOutVisible
   If isVarEqualTo(root, PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin, hGuiTip, hFlyOut)
      Return uiWM_LBUTTONUP(wP, lP, msg, hwnd)
   Return WM_LBUTTONup(wP, lP, msg, hwnd)
}

dispatchLButtonDbl(wP, lP, msg, hwnd) {
   If isUIrootWin(hwnd)
      Return WM_LBUTTON_DBL(wP, lP, msg, hwnd)
   Return OnLButtonDblClk(wP, lP, msg, hwnd)
}

dispatchMouseWheel(wP, lP, msg, hwnd) {
   If isUIrootWin(hwnd)
      Return WM_MOUSEWHEEL(wP, lP, msg, hwnd)
   Return adjustWheelNumbersEditFields(wP, lP, msg)  ; it declares 3 params [the loader enforces arity on direct calls; monitors never did]
}

; ______ native menu machinery [merge phase D] ______
; The menu bar carries REAL attached submenus [BuildMenuBar], so hover-switching,
; F10 and Alt-accelerators are native. Dropdown content is rebuilt just-in-time
; when Windows sends WM_INITMENUPOPUP, and the reader announcements ride
; WM_MENUSELECT - both received by the permanent same-thread WH_CALLWNDPROC hook
; below, because during any same-interpreter menu modal loop OnMessage monitors,
; timers and hotkey subroutines NEVER run [probe rounds 1-2], while raw Win32
; callbacks do [probes p7/p8/p11/p13]. The in-menu wheel rides a menu-scoped
; WH_MOUSE_LL hook [p13]. CWPSTRUCT is REVERSED: lParam@0, wParam@PtrSize,
; message@2*PtrSize, hwnd@3*PtrSize.

uiMenuNameForBuilder(suffix) {
; every InvokeMenuBar<suffix> builder rebuilds exactly one named menu - extracted
; from the builders' own showThisMenu tails at phase D
   Static mapu := {"File":"pvMenuBarFile", "Edit":"pvMenuBarEdit", "Selection":"pvMenuBarSelection"
      , "Image":"pvMenuBarImage", "Captions":"PVsounds", "Slides":"PVslide", "Find":"pvMenuBarFind"
      , "List":"pvMenuBarList", "Sort":"PVsort", "Navigate":"PVnav", "View":"PVview"
      , "Interface":"PvUIprefs", "Settings":"PVprefs", "Help":"PVhelp"
      , "EditorFile":"pvMenuBarFile", "EditorSelection":"PVselv", "EditorTools":"PVlTools"
      , "AlphaMask":"PValpha", "VectorFile":"pvMenuBarFile", "VectorEdit":"pvMenuBarEdit"
      , "VectorSelection":"pvMenuBarSelection", "VectorView":"pvMenuBarView", "VectorInterface":"PvUIprefs"}
   Return mapu.HasKey(suffix) ? mapu[suffix] : ""
}

uiCallWndProc(nCode, wP, lP) {
   Critical
   If (nCode >= 0)
   {
      msg := NumGet(lP+0, 2*A_PtrSize, "UInt")
      If (msg=0x11F)      ; WM_MENUSELECT - sent to the owner during the modal loop
         uiMenuSelectTrack(NumGet(lP+0, A_PtrSize, "UPtr"), NumGet(lP+0, 0, "Ptr"))
      Else If (msg=0x117) ; WM_INITMENUPOPUP - the message wParam is the HMENU about to display
      {
         hMinit := NumGet(lP+0, A_PtrSize, "UPtr")
         isMapped := (IsObject(menuJITmap) && menuJITmap.HasKey(hMinit)) ? 1 : 0
         ; ORDER-PROOFING: menu-BAR tracking can deliver the first INITMENUPOPUP
         ; BEFORE ENTERMENULOOP [TrackPopupMenu sends ENTER first], so when no loop
         ; is active yet the session type is inferred here: a mapped HMENU is a bar
         ; dropdown, anything else is a programmatic popup's root
         If (menuLoopActive!=1)
            barMenuSession := isMapped
         ; the flyout anchors to ROOT popups only: bar dropdowns [mapped menus] and
         ; the FIRST popup of a right-click/AppsKey session - never to submenus,
         ; which used to drag it around the screen
         If (barMenuSession=1)
         {
            If isMapped
            {
               flyoutNeedsPos := 1
               flyoutAnchorMenu := hMinit
               OutputDebug, % "QPVMERGE: flyout flag raised [bar] anchor=" hMinit
            }
         } Else If (popupRootSeen!=1)
         {
            popupRootSeen := 1
            flyoutNeedsPos := 1
            flyoutAnchorMenu := hMinit
            OutputDebug, % "QPVMERGE: flyout flag raised [popup] anchor=" hMinit
         }
         uiMenuJITrebuild(hMinit)
      }
      Else If (msg=0x211) ; WM_ENTERMENULOOP - its wParam: 0 = menu bar tracking, 1 = TrackPopupMenu popup
         uiMenuLoopEnter(NumGet(lP+0, A_PtrSize, "UPtr"))
      Else If (msg=0x212) ; WM_EXITMENULOOP
         uiMenuLoopExit()
   }
   Return DllCall("user32\CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

uiMenuJITrebuild(hMenu) {
   Static busy := 0
   If (busy=1 || !IsObject(menuJITmap) || !menuJITmap.HasKey(hMenu))
      Return
   If (barMenuSession!=1)
   {
      OutputDebug, % "QPVMERGE: menu JIT skipped [popup session] " menuJITmap[hMenu]
      Return
   }
   busy := 1
   funcu := menuJITmap[hMenu]
   OutputDebug, % "QPVMERGE: menu JIT rebuild " funcu
   If (VisibleQuickMenuSearchWin=1)
      Try closeQuickSearch()
   mouseTurnOFFtooltip()
   lastOtherWinClose := A_TickCount
   ; justBuild=1: refresh the dropdown content in place, no Menu-Show - the popup
   ; Windows is about to display IS this menu [the builders use DeleteAll, which
   ; keeps the HMENU alive - a whole-menu Delete would orphan the bar attachment]
   Try
   {
      If (funcu="InvokeMenuBarVectorView")
         InvokeMenuBarVectorView(0, 0, 1)   ; its 2nd parameter is modus, not justBuild
      Else
         %funcu%(0, 1)
   }
   Catch weh
      OutputDebug, % "QPVMERGE: menu JIT rebuild FAILED for " funcu ": " weh.message
   busy := 0
}

uiMenuSelectTrack(mwParam, hMenuSel) {
   item := mwParam & 0xFFFF
   flags := (mwParam >> 16) & 0xFFFF
   If (flags=0xFFFF && !hMenuSel)  ; the menu was dismissed
      Return
   lastMenuHoverZeit := A_TickCount
   uiTryPlaceFlyout()
   If (allowMenuReader!="yes" || !hMenuSel)
      Return
   VarSetCapacity(bufu, 520, 0)
   If (flags & 0x10)  ; MF_POPUP: the loword is the item POSITION
      DllCall("user32\GetMenuStringW", "Ptr", hMenuSel, "UInt", item, "Ptr", &bufu, "Int", 255, "UInt", 0x400)
   Else               ; otherwise the loword is the command id
      DllCall("user32\GetMenuStringW", "Ptr", hMenuSel, "UInt", item, "Ptr", &bufu, "Int", 255, "UInt", 0x000)
   txt := StrGet(&bufu, "UTF-16")
   If !StrLen(txt)
      Return
   accel := ""
   If InStr(txt, "`t")
   {
      p := StrSplit(txt, "`t")
      txt := p[1], accel := p[2]
   }
   msgu := StrReplace(txt, "&")
   If (flags & 0x10)
      msgu .= " [submenu]"
   If (flags & 0x3)   ; MF_GRAYED / MF_DISABLED
      msgu .= " [unavailable]"
   If (flags & 0x8)   ; MF_CHECKED
      msgu .= " [checked]"
   If accel
      msgu .= "`nShortcut: " accel
   ; TRACK only - the announcement shows ON DEMAND, on right-click over the item
   ; [the LL hook's RButton branch], exactly like the old RButton reader hotkey;
   ; announcing on every highlight change flooded the OSD
   uiMenuReaderLastMsg := msgu
}

uiMenuLoopEnter(fromPopup:=0) {
   menuLoopActive := 1
   ; native WM_TIMER ticker for the menu session: the modal loop dispatches
   ; TIMERPROC-based timers [AHK's own timers never tick in there - probe p3], so
   ; this is what positions the flyout beside the open menu, the job the old 25ms
   ; AHK timer did from the second interpreter
   Static cbTick := 0
   If !cbTick
      cbTick := RegisterCallback("uiMenuNativeTick", "F")
   popupRootSeen := 0
   ; flyoutNeedsPos is deliberately NOT reset here: on menu-BAR sessions the first
   ; INITMENUPOPUP [which raises it] can precede ENTERMENULOOP - a reset here wiped
   ; the flag and the bar flyout never showed; the ticker consumes the flag itself
   If !menuNativeTimerID
      menuNativeTimerID := DllCall("user32\SetTimer", "Ptr", 0, "UPtr", 0, "UInt", 90, "Ptr", cbTick, "UPtr")
   ; belt: a second, WINDOW-bound native timer. A NULL-hwnd timer is a thread
   ; message; if the menu-BAR tracking loop retrieves only window messages it
   ; never dispatches the first one - the PVwin-bound WM_TIMER is dispatched by
   ; any GetMessage the loop runs, and DispatchMessage calls the TIMERPROC
   If !menuNativeTimerID2
      menuNativeTimerID2 := DllCall("user32\SetTimer", "Ptr", PVhwnd, "UPtr", 0xF17E, "UInt", 90, "Ptr", cbTick, "UPtr")
   ; JIT dropdown rebuilding applies ONLY to menu-bar sessions. The context menus
   ; [Menu, Show popups] attach the same shared submenus [PVview, PVnav, PVslide...]
   ; but pre-build everything before showing; letting the hook rebuild them
   ; mid-popup swapped in the BAR variants and the builders' deleteMenus() calls
   ; wrecked the open context menu [broken/missing items on reopen].
   barMenuSession := fromPopup ? 0 : 1
   If !hLLmouseHook
   {
      Static cbLL := 0
      If !cbLL
         cbLL := RegisterCallback("uiMenuMouseLL", "F")
      hLLmouseHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", cbLL, "Ptr", DllCall("GetModuleHandle", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
   }
}

uiMenuLoopExit() {
   menuLoopActive := 0
   barMenuSession := 0
   If menuNativeTimerID
   {
      DllCall("user32\KillTimer", "Ptr", 0, "UPtr", menuNativeTimerID)
      menuNativeTimerID := 0
   }
   If menuNativeTimerID2
   {
      DllCall("user32\KillTimer", "Ptr", PVhwnd, "UPtr", 0xF17E)
      menuNativeTimerID2 := 0
   }
   If (menusflyOutVisible=1)
   {
      ; hold the flyout 350ms after the menu closes [per Marius] so the click that
      ; dismissed the menu can land on the S/T/M buttons; then the hide pass runs
      flyoutGraceZeit := A_TickCount
      SetTimer, hideMenuFlyOut, -350
   }
   If hLLmouseHook
   {
      DllCall("user32\UnhookWindowsHookEx", "Ptr", hLLmouseHook)
      hLLmouseHook := 0
   }
   If (allowMenuReader="yes")
      mouseTurnOFFtooltip()
   ; self-healing pass, deferred until the loop is fully gone [timers work again]:
   ; re-resolve every bar attachment by NAME and repair any whose handle changed
   SetTimer, uiRefreshBarAttachments, -50
}

uiRefreshBarAttachments() {
; [phase D] safety net for the shared attached menus: if anything recreated one
; of them under a NEW HMENU [historically: a popup parent's whole-delete
; recursively destroying attached submenus - fixed at the source in deleteMenus],
; the bar item would silently point at a dead handle and the JIT map would miss.
; This re-resolves each attachment by name, re-attaches changed ones [Menu-Add on
; an existing item label updates its submenu link] and rebuilds the JIT map.
; Normally a complete no-op; repairs are logged.
   If (!IsObject(menuJITlist) || !menuJITlist.Count() || menuLoopActive=1)
      Return
   newMap := {}
   repaired := 0
   Loop, % menuJITlist.Count()
   {
      builderFn := menuJITlist[A_Index]
      suffix := StrReplace(builderFn, "InvokeMenuBar")
      menaName := uiMenuNameForBuilder(suffix)
      hSub := 0
      Try hSub := MenuGetHandle(menaName)
      If !hSub
      {
         Menu, % menaName, Add, building the menu..., dummy
         Try hSub := MenuGetHandle(menaName)
      }
      If !hSub
         Continue
      If !menuJITmap.HasKey(hSub)
      {
         labelu := menuArray[A_Index, 3]
         If StrLen(labelu)
         {
            Try Menu, PVbar, Add, % labelu, % ":" menaName
            repaired++
         }
      }
      newMap[hSub] := builderFn
   }
   menuJITmap := newMap
   If (repaired)
      OutputDebug, % "QPVMERGE: bar attachments repaired: " repaired
}

uiMenuNativeTick(hwnd:=0, msg:=0, idEvent:=0, tickCount:=0) {
; TIMERPROC [raw callback] fired BY the modal menu loop every ~90ms.
   Critical
   If (menuLoopActive!=1)
      Return
   uiTryPlaceFlyout()
}

uiTryPlaceFlyout() {
; Places the menuFlier flyout under the menu window ONCE PER ROOT POPUP
; [flyoutNeedsPos is raised by the WM_INITMENUPOPUP hook for bar dropdowns and
; for the first popup of a context-menu session]; submenus never move it. The
; flag clears only after a successful placement, so an attempt made before the
; menu window is visible simply retries. Called from the native ticker AND from
; every WM_MENUSELECT - the menu-BAR tracking loop may not dispatch NULL-hwnd
; thread timers at all, while MENUSELECT is SENT on every highlight change in
; both loop kinds, keyboard navigation included.
   If (flyoutNeedsPos!=1 || allowMenuReader!="yes")
      Return
   ; anchor by IDENTITY, not mere visibility: dismissed menus FADE OUT, so during
   ; fast context<->bar alternation the previous session's #32768 is still visible
   ; when this runs, and placing against it consumed the flag on a dying window's
   ; rectangle [the intermittent missing-flyout Marius reported]. Every #32768
   ; answers MN_GETHMENU with the menu it hosts - demand the one hosting the menu
   ; the flag was raised for; ghosts host the OLD menu and are skipped, retried past.
   a := 0
   If flyoutAnchorMenu
   {
      WinGet, menuWins, List, % "ahk_class #32768 ahk_pid " QPVpid
      Loop, % menuWins
      {
         w := menuWins%A_Index%
         If !DllCall("user32\IsWindowVisible", "UPtr", w)
            Continue
         hm := DllCall("user32\SendMessageW", "Ptr", w, "UInt", 0x01E1, "Ptr", 0, "Ptr", 0, "UPtr") ; MN_GETHMENU
         If (hm = flyoutAnchorMenu)
         {
            a := w
            Break
         }
      }
   } Else
      a := uiVisibleMenuWin()
   If !a
      Return
   If (wasMenuFlierCreated!=1)
      guiCreateMenuFlyout()
   WinGetPos, mX, mY, , Height, ahk_id %a%
   If (mX="" || Height="")
      Return
   flyoutNeedsPos := 0
   menusflyOutVisible := 1
   y := mY + Round(Height) + 2
   OutputDebug, % "QPVMERGE: flyout placed x" mX " y" y " bar=" barMenuSession
   Gui, menuFlier: Show, AutoSize x%mX% y%y% NoActivate
}

uiMenuMouseLL(nCode, wP, lP) {
; menu-scoped low-level mouse hook [probe p13]: while a menu of this process is
; visible, the wheel moves the highlight [eat the hardware event, post key-downs
; the modal loop consumes - p13 proved menus accept queue-posted key-downs] and
; RButton re-announces for the reader. Installed only between WM_ENTERMENULOOP
; and WM_EXITMENULOOP; the callback must stay minimal [system-wide hook budget].
   Critical
   If (nCode=0 && menuLoopActive=1)
   {
      ; third placement consumer [p13-proven vehicle]: the LL hook runs on every
      ; physical mouse event during menu sessions, hover jitter included - it
      ; covers a session where the user clicks and then never changes the
      ; highlight [no WM_MENUSELECT] on a loop that may not dispatch timers
      uiTryPlaceFlyout()
      If (wP=0x20A && uiVisibleMenuWin())
      {
         delta := NumGet(lP+0, 8, "Int") >> 16
         vk := (delta > 0) ? 0x26 : 0x28
         DllCall("user32\PostMessageW", "Ptr", PVhwnd, "UInt", 0x100, "Ptr", vk, "Ptr", 1)
         DllCall("user32\PostMessageW", "Ptr", PVhwnd, "UInt", 0x100, "Ptr", vk, "Ptr", 1)
         DllCall("user32\PostMessageW", "Ptr", PVhwnd, "UInt", 0x100, "Ptr", vk, "Ptr", 1)
         Return 1
      } Else If (wP=0x205 && allowMenuReader="yes" && uiVisibleMenuWin() && StrLen(uiMenuReaderLastMsg)>1)
      {
         mouseCreateOSDinfoLine(uiMenuReaderLastMsg, 1)
         showOSDinfoLineNow(1500)
         Return 1
      }
   }
   Return DllCall("user32\CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wP, "Ptr", lP, "Ptr")
}

; ______ liveness shims [merge phase C] ______
; Pre-merge, a busy main thread never stopped the interface interpreter from
; processing input - abort flags, pen pressure and click state stayed live. On one
; interpreter, a long operation holding Critical blocks all of that; these shims
; restore it at the operations' existing checkpoints.

; [merge] pumpUIevents() [the full Critical-off pump] was retired: its one caller
; [determineTerminateOperation] moved to drainUIinput after the full pump let queued
; canvas-rebuilds run inside Critical worker loops [the thumbnails GDI+ error].

drainUIinput() {
; SELECTIVE drain for long operations that hold Critical: reads the queued input
; of the interface windows and hands it straight to the ui handlers, so the
; abort/cancel flags [canCancelImageLoad, alterFilesIndex, colorPickerMustEnd,
; mustAbandonCurrentOperations] keep working exactly as when a separate
; interpreter processed this input live. Input for OTHER windows [panels,
; toolbar] stays queued - their handlers run when the operation unwinds, which
; matches the old queued-post semantics. No timers or posts fire in here.
; PeekMessage with the PVwin handle also drains its children [the hit-test
; controls and the reparented GDI viewport windows].
   Static busy := 0
   If busy  ; re-entrancy guard: a drained Escape can show a modal dialog that pumps,
      Return ; and the interrupted operation then reaches its next checkpoint mid-drain
   busy := 1
   gotKeyDown := 0
   dcount := 0
   VarSetCapacity(msgu, 48, 0)  ; MSG is 48 bytes on x64, 28 on x86
   prevCrit := A_IsCritical
   Loop, 40  ; hard cap per checkpoint, so an input flood cannot stall the operation
   {
      If !DllCall("user32\PeekMessageW", "Ptr", &msgu, "Ptr", PVhwnd, "UInt", 0x100, "UInt", 0x108, "UInt", 1) ; PM_REMOVE
      {
         If !DllCall("user32\PeekMessageW", "Ptr", &msgu, "Ptr", PVhwnd, "UInt", 0x200, "UInt", 0x20E, "UInt", 1)
            Break
      }
      dcount++
      mhwnd := NumGet(msgu, 0, "UPtr")
      mnum := NumGet(msgu, A_PtrSize, "UInt")
      mwp := NumGet(msgu, 2*A_PtrSize, "UPtr")
      mlp := NumGet(msgu, 3*A_PtrSize, "Ptr")
      If (mnum=0x100 || mnum=0x104)
      {
         gotKeyDown := 1
         uiWM_KEYDOWN(mwp, mlp, mnum, mhwnd)
      }
      Else If (mnum=0x200)
         uiWM_MOUSEMOVE(mwp, mlp, mnum, mhwnd)
      Else If (mnum=0x201)
         uiWM_LBUTTONDOWN(mwp, mlp, mnum, mhwnd)
      Else If (mnum=0x202)
         uiWM_LBUTTONUP(mwp, mlp, mnum, mhwnd)
      Else If (mnum=0x203)
         WM_LBUTTON_DBL(mwp, mlp, mnum, mhwnd)
      Else If (mnum=0x205)
         WM_RBUTTONUP(mwp, mlp, mnum, mhwnd)
      Else If (mnum=0x207)
         WM_MBUTTONDOWN(mwp, mlp, mnum, mhwnd)
      Else If (mnum=0x20A || mnum=0x20E)
         WM_MOUSEWHEEL(mwp, mlp, mnum, mhwnd)
      ; remaining numbers in the ranges [key-ups, dead moves] are swallowed: their
      ; consumers read async state via GetKeyState, which removal cannot alter
   }
   ; the title-bar close button, which the old interface thread answered live: a
   ; queued non-client click on the X becomes the same escalating close routine;
   ; other non-client input stays queued untouched
   If DllCall("user32\PeekMessageW", "Ptr", &msgu, "Ptr", PVhwnd, "UInt", 0x00A1, "UInt", 0x00A1, "UInt", 0)  ; WM_NCLBUTTONDOWN, peek only
   {
      If (NumGet(msgu, 2*A_PtrSize, "UPtr") = 20)  ; HTCLOSE
      {
         DllCall("user32\PeekMessageW", "Ptr", &msgu, "Ptr", PVhwnd, "UInt", 0x00A1, "UInt", 0x00A1, "UInt", 1)
         preByeRoutine()
      }
   }
   ; the keyboard handler defers its work to a 3ms timer that cannot fire while
   ; the caller holds Critical - run it now, then disarm the pending timer.
   ; ONLY when a key-down was actually drained: uiPreProcessKbdKey() processes the
   ; global hotkate, which otherwise still holds the LAST key ever pressed - an
   ; unconditional call here re-fired that stale key on every checkpoint [killing
   ; slideshows after one advance and making GIF playback flicker uninterruptibly].
   If (gotKeyDown)
   {
      uiPreProcessKbdKey()
      SetTimer, uiPreProcessKbdKey, Off
   }
   If (dcount)
      OutputDebug, % "QPVMERGE: drained " dcount " msgs, keydown=" gotKeyDown ", hotkate=" hotkate
   If (prevCrit)
      Critical, %prevCrit%
   Else
      Critical, Off
   busy := 0
}

pumpPenMessages() {
; The brush loops hold Critical, so WM_POINTER* messages queue up instead of
; reaching the WM_PENpressure monitor - read them here directly. The handler is
; called for its side effect on penPressureRaw, then the message is dispatched
; anyway so DefWindowProc keeps promoting pen input to the legacy mouse messages
; [see the note in WM_PENpressure]. The handler's own «Critical, off» is undone
; by restoring the caller's state afterwards.
   If (hasPenPressureAPI!=1)
      Return
   VarSetCapacity(msgu, 48, 0)
   prevCrit := A_IsCritical
   Loop, 20
   {
      If !DllCall("user32\PeekMessageW", "Ptr", &msgu, "Ptr", 0, "UInt", 0x0245, "UInt", 0x024A, "UInt", 1)
         Break
      mhwnd := NumGet(msgu, 0, "UPtr")
      mnum := NumGet(msgu, A_PtrSize, "UInt")
      mwp := NumGet(msgu, 2*A_PtrSize, "UPtr")
      mlp := NumGet(msgu, 3*A_PtrSize, "Ptr")
      WM_PENpressure(mwp, mlp, mnum, mhwnd)
      DllCall("user32\DispatchMessageW", "Ptr", &msgu)
   }
   If (prevCrit)
      Critical, %prevCrit%
   Else
      Critical, Off
}

updateWindowColor() {
  Sleep, 1
  ; WindowBgrColor := WindowBgrColor
  Gui, PVwin: Color, %WindowBgrColor%
}

destroyAllGUIs() {
  Gui, PVwin: Destroy
  Gui, PVgdiPic: Destroy
  Gui, PVgdiThumbs: Destroy
  Gui, PVgdiInfos: Destroy
  Gui, PVgdiSelect: Destroy
  taskBarUI.clearAll()
  Sleep, 50
}

infosUIAbtns(msgu) {
   Static lastu := 0, prevMsg
   If (prevMsg=msgu)
      Return

   lastu := !lastu
   GuiControl, PVwin:, UIAbtn%lastu%, % msgu
   Sleep, 1
   If (WinActive("A")=PVhwnd)
      GuiControl, PVwin: Focus, UIAbtn%lastu%
   prevMsg := msgu
}

BuildGUI() {
; De-parameterized at the merge [phase C]: the 16-field "$"-string handshake and
; its MT_get fallback existed only to marshal the main thread's settings into the
; interface interpreter - everything below now reads the shared globals directly.
; [This also retires the old restartEntireGui() bug that re-sent only 9 of the 16
; fields and blanked the OSD font preferences on every GUI rebuild.]
   Critical, on
   calcHUDsize()
   MinGUISize := "+MinSize" A_ScreenWidth//4 "x" A_ScreenHeight//4
   initialWh := "w" A_ScreenWidth//1.7 " h" A_ScreenHeight//1.5
   Global UIAbtn0, UIAbtn1
   Gui, PVwin: Color, %WindowBgrColor%
   Gui, PVwin: Margin, 0, 0
   Gui, PVwin: -DPIScale +Resize %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, PVwin: Font, s1
   Gui, PVwin: Add, Button, x1 y1 w1 h1 vUIAbtn0, Btn-A
   Gui, PVwin: Add, Button, x1 y1 w1 h1 vUIAbtn1, Btn-B
   Gui, PVwin: Add, Text, x3 y3 w2 h2 BackgroundTrans vOSDmsgsLine hwndhPic11, OSD messages.
   Gui, PVwin: Add, Text, x3 y3 w2 h2 BackgroundTrans vPicVscroll hwndhPic5, Vertical scrollbar
   Gui, PVwin: Add, Text, x3 y3 w2 h2 BackgroundTrans vPicHscroll hwndhPic6, Horizontal scrollbar
   Gui, PVwin: Add, Text, x3 y3 w2 h2 BackgroundTrans vImgInfoBox hwndhPic9, Image information box.
   Gui, PVwin: Add, Text, x3 y3 w3 h3 BackgroundTrans vImgNavBox hwndhPic7, Image navigation area.
   Gui, PVwin: Add, Text, x3 y3 w2 h2 BackgroundTrans vImgHistoBox hwndhPic8, Image histogram area.
   Gui, PVwin: Add, Text, x3 y3 w2 h2 BackgroundTrans vImgAnnoBox hwndhPic10, Image annotations box.
   Gui, PVwin: Add, Text, x0 y0 w1 h1 BackgroundTrans vPicOnGui1 hwndhPic0, Previous image
   Gui, PVwin: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2a hwndhPic1, Zoom in
   Gui, PVwin: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2b hwndhPic2, Image view. Center.
   Gui, PVwin: Add, Text, x2 y2 w2 h2 BackgroundTrans vPicOnGui2c hwndhPic3, Zoom out
   Gui, PVwin: Add, Text, x3 y3 w3 h3 BackgroundTrans vPicOnGui3 hwndhPic4, Next image
   Gui, PVwin: Add, Button, xp-100 yp-100 w1 h1 Default,a
   hPicOnGui1 := hPic0
   If (isTitleBarVisible=1)
      Gui, PVwin: +Caption
   Else
      Gui, PVwin: -Caption

   Gui, PVwin: Show, Maximize Hide Center %initialwh%, %appTitle%

   Try taskBarUI := new taskbarInterface(PVhwnd)
   UnregisterTouchWindow(PVhwnd)
   Loop, 4
       UnregisterTouchWindow(hPic%A_Index%)
   Sleep, 1
   createGDIwinThumbs()
   Sleep, 1
   createGDIwin()
   Sleep, 1
   createGDIselectorWin()
   Sleep, 1
   createGDIinfosWin()
   Sleep, 2
   uiUpdateUIctrl(1)
   WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%
   Sleep, 1
   WinActivate, ahk_id %PVhwnd%
   posu := StrSplit(mainWinPos, "|")
   sizeu := StrSplit(mainWinSize, "|")
   pX := posu[1], pY := posu[2]
   sW := sizeu[1], sH := sizeu[2]
   ; ToolTip, % mainWinPos "==" mainWinSize "==" mainWinMaximized , , , 2
   If (mainWinMaximized=2 || pX="" || pY="" || sW="" || sH="")
   {
      ; [merge fix] this passed the literal gui number 1 - correct when this file's
      ; interpreter owned Gui "1" [the main window], but on the merged interpreter
      ; the dynamic «Gui, %whichGUI%:» inside created a NEW anonymous Gui 1: an
      ; empty, visible-styled window titled with the app name - the phantom
      ; taskbar button Marius reported. The A1 rename sweep could not see a
      ; number that only exists as a call argument.
      uiRepositionWindowCenter("PVwin", PVhwnd, "mouse", appTitle)
      Sleep, 50
      Gui, PVwin: Show, Maximize
   } Else
   {
      Gui, PVwin: Show ; , x%pX% y%pY% w%sW% h%sH%
      WinMoveZ(PVhwnd, 0, pX, pY, sW, sH)
      Sleep, 2
   }

   r := PVhwnd "|" hGDIinfosWin "|" hGDIwin "|" hGDIthumbsWin "|" hGDIselectWin "|" hPicOnGui1 "|" winGDIcreated "|" ThumbsWinGDIcreated
   Return r
}

setMenuBarState(modus, mena:="PVbar") {
  Critical, on 
  If (showMainMenuBar!=1)
     Return

  ; causes a lot of flickers
  Loop, % menuTotalIndex
  {
     labelu := menuArray[A_Index, 3]
     s := menuArray[A_Index, 4]
     If (s!=modus)
     {
        Try Menu, % mena, % modus, % labelu
        menuArray[A_Index, 4] := modus
        Sleep, -1
     }
  }
  ; ToolTip, % modus " s=" menuTotalIndex , , , 2
}

initAppBusyMode() {
     mustAbandonCurrentOperations := 0
     userPendingAbortOperations := 0
     lastCloseInvoked := 0
     imageLoading := 1
     runningLongOperation := 1
     executingCanceableOperation := A_TickCount
     setTaskbarIconState("anim")
     ; setMenuBarState("Disable")
}

setTaskbarIconState(mode) {
   If (mode="anim")
      taskBarUI.SetProgressType("INDETERMINATE")
   Else If (mode="normal")
      taskBarUI.SetProgressType("off")
   Else If (mode="error" )
      taskBarUI.setTaskbarIconColor("red")
   Else If (mode="exclamation" && runningLongOperation!=1)
      ; taskBarUI.flashTaskbarIcon("yellow", 6, 150, 150)
      taskBarUI.setTaskbarIconColor("yellow")
   Else If (mode="question" && runningLongOperation!=1)
      taskBarUI.flashTaskbarIcon("green", 3, 150, 150)
      ; taskBarUI.setTaskbarIconColor("green")
}

updateUIctrlFromOutside(paramA) {
    p := StrSplit(paramA, "|")
    editingSelectionNow := p[1]
    isAlwaysOnTop := p[2]
    drawingShapeNow := p[3]
    IMGresizingMode := p[4]
    uiUpdateUIctrl(0)
}

detectToolbar(ByRef ToolbarWinW:=0, ByRef ToolbarWinH:=0) {
; Interface thread twin of adjustCanvas2Toolbar() in quick-picto-viewer.ahk; the two must
; agree, otherwise the painted viewport and the mouse hit-test controls end up offset
; differently. Keep both in sync, including the IsWindowVisible() test - this thread runs
; with DetectHiddenWindows off while the main one has it on, so WinExist() would not match.
    Static lastX := "", lastY := "", lW, lH
    If (ShowAdvToolbar!=1 || lockToolbar2Win!=1)
       Return 0

    thisX := thisY := ""
    If (hQPVtoolbar && DllCall("IsWindowVisible", "UPtr", hQPVtoolbar))
       WinGetPos, thisX, thisY, ToolbarWinW, ToolbarWinH, ahk_id %hQPVtoolbar%

    If (!ToolbarWinW || !ToolbarWinH)
    {
       ToolbarWinW := lW
       ToolbarWinH := lH
    } Else
    {
       lW := ToolbarWinW
       lH := ToolbarWinH
    }

    If (!ToolbarWinW || !ToolbarWinH)
       Return 0

    If (thisX="" || thisY="")
    {
       ; the toolbar GUI is being destroyed and re-created; bridge the gap
       If (lastX="" || lastY="")
          Return 0

       thisX := lastX, thisY := lastY
    } Else
    {
       lastX := thisX   ; kept in SCREEN space; converted to client space just below
       lastY := thisY
    }

    JEE_ScreenToClient(PVhwnd, thisX, thisY, cX, cY)
    tolerance := ToolBarBtnWidth//3 + 5
    ; ToolTip, % "t=" tolerance "||" cX "|" cY "|" ToolbarWinW "|" hQPVtoolbar , , , 2
    If (!isInRange(cX, -tolerance, tolerance) || !isInRange(cY, -tolerance, tolerance))
       Return 0

    Return isTlbrVertical() ? 1 : 2
}

uiUpdateUIctrl(forceThis:=0) {
   Static prevState
   If (forceThis="kill" || thumbsDisplaying=1 && maxFilesIndex>0)
   {
      prevState := ""
      Return
   }

   GetWinClientSize(GuiW, GuiH, PVhwnd, 0)
   hasTrans := detectToolbar(tW, tH)   ; guards ShowAdvToolbar / lockToolbar2Win itself
   tX := (hasTrans=1) ? tW : 0
   tY := (hasTrans=2) ? tH : 0
   If (hasTrans=1)
      GuiW -= tW
   If (hasTrans=2)
      GuiH -= tH

   lastWinStatus := ""
   ctrlW := (editingSelectionNow=1) ? GuiW//8 : GuiW//7
   ctrlH2 := (editingSelectionNow=1) ? GuiH//6 : GuiH//5
   ctrlH3 := GuiH - ctrlH2*2
   ctrlW2 := GuiW - ctrlW*2
   ctrlY1 := tY + ctrlH2
   ctrlY2 := tY + ctrlH2*2
   ctrlY3 := tY + ctrlH2 + ctrlH3
   ctrlX1 := tX + ctrlW
   ctrlX2 := tX + ctrlW + ctrlW2
   calcHUDsize()
   thisState := "a" GuiW GuiH ctrlW2 ctrlH2 ctrlY3 editingSelectionNow isAlwaysOnTop TouchScreenMode drawingShapeNow IMGresizingMode OSDfontSize imgHUDbaseUnit
   If (thisState!=prevState)
   {
      k := imgHUDbaseUnit//3 ; the thickness of scrollbars
      WinSet, AlwaysOnTop, % isAlwaysOnTop, ahk_id %PVhwnd%   
      GuiControl, PVwin: Move, PicOnGUI1, % "w" ctrlW " h" GuiH " x" tX " y" tY
      GuiControl, PVwin: Move, PicOnGUI2a, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" tY
      GuiControl, PVwin: Move, PicOnGUI2b, % "w" ctrlW2 " h" ctrlH3 " x" ctrlX1 " y" ctrlY1
      GuiControl, PVwin: Move, PicOnGUI2c, % "w" ctrlW2 " h" ctrlH2 " x" ctrlX1 " y" ctrlY3
      GuiControl, PVwin: Move, PicOnGUI3, % "w" ctrlW " h" GuiH " x" ctrlX2 " y" tY
      If (IMGresizingMode=4)
      {
         GuiControl, PVwin: Move, picVscroll, % "w" k " h" GuiH " x" GuiW - k + tX " y" tY
         GuiControl, PVwin: Move, picHscroll, % "w" GuiW " h" k " x " tX " y" GuiH - k + tY
      } Else
      {
         GuiControl, PVwin: Move, picVscroll, w1 h1 x1 y1
         GuiControl, PVwin: Move, picHscroll, w1 h1 x1 y1
      }
      uiAccessImgViewSetUIlabels()
      prevState := thisState
      uiAccessUpdateUiStatusBar(0, 0, "kill", 0)
   }
}

uiAccessUpdateHistoBox(msgu, tW, tH, tX, tY) {
   If (msgu="hide" || !tW || !tH)
   {
      GuiControl, PVwin: Move, ImgHistoBox, x1 y1 w1 h1
      Return
   }

   msgu := StrReplace(msgu, "`n", ".`n")
   msgu := StrReplace(msgu, " | ", ".`n")
   GuiControl, PVwin:, ImgHistoBox, % "Image histogram box:`nGraph focus: " msgu "`nClick to cycle modes. Right-click for histogram options."
   GuiControl, PVwin: Move, ImgHistoBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessUpdateAnnoBox(msgu, tW, tH, tX, tY) {
   If (msgu="hide" || !tW || !tH || msgu="")
   {
      GuiControl, PVwin: Move, ImgAnnoBox, x1 y1 w1 h1
      Return
   }

   GuiControl, PVwin:, ImgAnnoBox, % "Image caption:`n" msgu "`nThis viewport area is click-through. The action performed on click will be that as if this box is not visible."
   GuiControl, PVwin: Move, ImgAnnoBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessUpdateNavBox(msgu, tW, tH, tX, tY) {
   If (msgu="hide" || !tW || !tH)
   {
      GuiControl, PVwin: Move, ImgNavBox, x1 y1 w1 h1
      Return
   }

   GuiControl, PVwin:, ImgNavBox, % msgu
   GuiControl, PVwin: Move, ImgNavBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessUpdateInfoBox(msgu, tW, tH, flipV, flipH, bonusX:=0, bonusY:=0, scrollX:=0, scrollY:=0) {
   If (msgu="hide" || !tW || !tH)
   {
      GuiControl, PVwin: Move, ImgInfoBox, x1 y1 w1 h1
      Return
   }

   msgu := "Info-box. Image in view:`n" StrReplace(msgu, "`n", ".`n") ".`nThis viewport area is click-through."
   GuiControl, PVwin:, ImgInfoBox, % msgu
   GetClientSize(GuiW, GuiH, PVhwnd)
   tX := (flipH=1 && thumbsDisplaying!=1) ? GuiW - tW : 0
   tY := (flipV=1 && thumbsDisplaying!=1) ? GuiH - tH : 0
   If (flipH!=1 || thumbsDisplaying=1)
      tX += Round(bonusX)
   If (flipV!=1 || thumbsDisplaying=1)
      tY += Round(bonusY)

   tX -= Round(scrollX)
   tY -= Round(scrollY)
   GuiControl, PVwin: Move, ImgInfoBox, % " x" tX " y" tY " w" tW " h" tH 
}

uiAccessWelcomeView() {
   Static msgu := "Random predefined pattern-based image generated in the viewport. No image loaded. No indexed image files. Press O key or Left-Click to open a file or folder. Right-click for the context menu and more options."
        , lastInvoked := 1, runz := 0
   If (thumbsDisplaying=1 && maxFilesIndex>0)
      Return

   If (A_TickCount - lastInvoked<150)
   {
      SetTimer, uiAccessWelcomeView, -300
      Return
   }

   runz++
   ; ToolTip, % runz "=p" , , , 2
   uiUpdateUIctrl()
   uiAccessUpdateHistoBox("hide", 1, 1, 0, 0)
   uiAccessUpdateInfoBox("hide", 1, 1, 0, 0)
   uiAccessUpdateNavBox("hide", 1, 1, 0, 0)
   uiAccessUpdateAnnoBox("hide", 1, 1, 0, 0)
   GuiControl, PVwin:, PicOnGUI1, % msgu
   GuiControl, PVwin:, PicOnGUI2a, % msgu
   GuiControl, PVwin:, PicOnGUI2b, % msgu
   GuiControl, PVwin:, PicOnGUI2c, % msgu
   GuiControl, PVwin:, PicOnGUI3, % msgu
   GuiControl, PVwin: Move, picVscroll, w1 h1 x1 y1
   GuiControl, PVwin: Move, picHscroll, w1 h1 x1 y1
   uiUpdateUIctrl("kill")
   lastInvoked := A_TickCount
}

uiAccessImgViewSetUIlabels() {
   zr := (IMGresizingMode=4) ? " Hold the Space key plus left-click and drag to pan the image. Use the mouse wheel to change the zoom level." : " Use Control + mouse wheel to change the image zoom level."
   If (drawingShapeNow=1 || AnyWindowOpen)
   {
      msgu := AnyWindowOpen ? "Image view. A panel window is opened. " : "Image view. Drawing vector shape mode is activated. " zr " Press Escape to cancel. Press Enter to accept defined path or modifications. Swipe gestures are not allowed."
      If (imgEditPanelOpened=1)
         msgu := "Image view. An image editing live tool is currently in use. " zr " Swipe gestures are not allowed."

      GuiControl, PVwin:, PicOnGUI1, % msgu
      GuiControl, PVwin:, PicOnGUI2a, % msgu
      GuiControl, PVwin:, PicOnGUI2b, % msgu
      GuiControl, PVwin:, PicOnGUI2c, % msgu
      GuiControl, PVwin:, PicOnGUI3, % msgu
      Return
   }

   If (TouchScreenMode=1)
   {
      dr := (editingSelectionNow=1) ? " Double click outside selection area to deactivate it. " : " Press Shift + Left-Click anywhere to create a new selection area. "
      ; gr := " Otherwise, the movement is considered as a zoom in/out swipe gesture."
      fr := " `nIf the image is not larger than the viewport, swipe gestures are allowed."
      msgu := "Image view. Left. Click for previous image. Swipe gestures allowed." zr dr
      If (editingSelectionNow=1)
      {
         msgu := "Image view. " dr zr
         If (IMGresizingMode=4)
            msgu .= fr
      }

      GuiControl, PVwin:, PicOnGUI1, % msgu
      msgu := "Image view. Top. Click to zoom in. Swipe gestures allowed." zr 
      If (editingSelectionNow!=1)
         msgu .= dr

      GuiControl, PVwin:, PicOnGUI2a, % msgu
      msgu := "Image view. Center. Double-click to toggle view mode in this area. " zr dr
      If (editingSelectionNow=1)
         msgu := "Image view. " dr zr
      If (IMGresizingMode=4)
         msgu .= fr

      GuiControl, PVwin:, PicOnGUI2b, % msgu
      msgu := "Image view. Bottom. Click to zoom out. Swipe gestures allowed." zr
      If (editingSelectionNow!=1)
         msgu .= dr

      GuiControl, PVwin:, PicOnGUI2c, % msgu
      msgu := "Image view. Right. Click for next image. Swipe gestures allowed." zr dr
      If (editingSelectionNow=1)
      {
         msgu := "Image view. " dr zr 
         If (IMGresizingMode=4)
            msgu .= fr
      }

      GuiControl, PVwin:, PicOnGUI3, % msgu
   } Else
   {
      zr := (IMGresizingMode=4) ? " Left-click outside selection area and drag to pan the image. Use the mouse wheel to change the zoom level." : " Use Control + mouse wheel to change the image zoom level."
      dr := (editingSelectionNow=1) ? "Double click outside selection area to deactivate it." : "Double-click anywhere to toggle view mode. Press Shift + Left-Click anywhere to create a new selection area. "
      msgu := "Image view. " dr zr
      GuiControl, PVwin:, PicOnGUI1, % msgu
      GuiControl, PVwin:, PicOnGUI2a, % msgu
      GuiControl, PVwin:, PicOnGUI2b, % msgu
      GuiControl, PVwin:, PicOnGUI2c, % msgu
      GuiControl, PVwin:, PicOnGUI3, % msgu
   }
}

uiAccessUpdateOSDmsg(stringu, tW, tH) {
    If (stringu="-" || !tW || !tH)
    {
       GuiControl, PVwin: Move, OSDmsgsLine, x1 y1 w1 h1
       Return
    }

    GetClientSize(GuiW, GuiH, PVhwnd)
    GuiControl, PVwin:, OSDmsgsLine, % "OSD: " stringu
    GuiControl, PVwin: Move, OSDmsgsLine, % " x1 y1 w" GuiW " h" tH 
}

uiAccessUpdateUiStatusBar(stringu:=0, heightu:=0, mustResize:=0, infos:=0, fntSize:="n", itemz:="n") {
   Critical, on
   Static prevState
   If itemz is Number
      maxFilesIndex := itemz

   If fntSize is Number
   {
      OSDfontSize := fntSize
      calcHUDsize()
   }

   lastWinStatus := ""
   If (mustResize="kill")
   {
      prevState := mustResize
   } Else If (mustResize="list")
   {
      thumbsDisplaying := 1
      GetClientSize(GuiW, GuiH, PVhwnd)
      thisState := "a" mustResize GuiW GuiH heightu imgHUDbaseUnit
      If (thisState!=prevState)
      {
         k := imgHUDbaseUnit//3 ; the thickness of scrollbars
         GuiControl, PVwin: Move, picVscroll, % "w" k " h" GuiH " x" GuiW - k " y0"
         GuiControl, PVwin: Move, PicOnGUI1, % "w" GuiW " h" GuiH - heightu
         GuiControl, PVwin: Move, PicOnGUI2a, % "w" GuiW - heightu//2 " h" heightu " x1 y" GuiH - heightu
         GuiControl, PVwin: Move, PicOnGUI2b, w1 h1 x1 y1
         GuiControl, PVwin: Move, PicOnGUI2c, w1 h1 x1 y1
         GuiControl, PVwin: Move, PicOnGUI3, w1 h1 x1 y1
         GuiControl, PVwin: Move, picHscroll, w1 h1 x1 y1
         prevState := thisState
      }

      GuiControl, PVwin:, PicOnGUI1, Files list container
      GuiControl, PVwin:, PicOnGUI2a, Status bar
      uiAccessUpdateHistoBox("hide", 1, 1, 0, 0)
      uiAccessUpdateAnnoBox("hide", 1, 1, 0, 0)
      uiUpdateUIctrl("kill")
   } Else If (mustResize="image")
   {
      thumbsDisplaying := 0
      prevState := mustResize
      uiUpdateUIctrl()
   } Else If (stringu && heightu)
   {
      uiUpdateUIctrl("kill")
      prevState := mustResize
      GetClientSize(GuiW, GuiH, PVhwnd)
      GuiControl, PVwin: Move, PicOnGUI1, % "w" GuiW " h" GuiH - heightu
      GuiControl, PVwin: Move, PicOnGUI2a, % "w" GuiW - heightu//2 " h" heightu " x1 y" GuiH - heightu
      stringu := StrReplace(stringu, " | ", "`n")
      GuiControl, PVwin:, PicOnGUI2a, % "Status bar:`n" stringu
      lastWinStatus := stringu
      GuiControl, PVwin:, PicOnGUI1, % infos
   }
}

createGDIwin() {
   Critical, on
   ; WinGetPos, , , mainW, mainH, ahk_id %PVhwnd%
   Gui, PVgdiPic: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIwin +OwnerPVwin
   Gui, PVgdiPic: Show, NoActivate, %appTitle%: Picture container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIwin)

   UnregisterTouchWindow(hGDIwin)
   winGDIcreated := 1
}

createGDIwinThumbs() {
   Critical, on

   Gui, PVgdiThumbs: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIthumbsWin +OwnerPVwin
   Gui, PVgdiThumbs: Show, NoActivate, %appTitle%: Thumbnails container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIthumbsWin)

   UnregisterTouchWindow(hGDIthumbsWin)
   ThumbsWinGDIcreated := 1
}

createGDIinfosWin() {
   Critical, on

   Gui, PVgdiInfos: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIinfosWin +OwnerPVwin
   Gui, PVgdiInfos: Show, NoActivate, %appTitle%: Infos container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIinfosWin)
   UnregisterTouchWindow(hGDIinfosWin)
}

createGDIselectorWin() {
   Critical, on

   Gui, PVgdiSelect: -DPIScale +E0x20 +Disabled -Caption +E0x80000 +hwndhGDIselectWin +OwnerPVwin
   Gui, PVgdiSelect: Show, NoActivate, %appTitle%: Selector container
   If (A_OSVersion!="WIN_7")
      SetParentID(PVhwnd, hGDIselectWin)
   UnregisterTouchWindow(hGDIselectWin)
}

miniGDIupdater() {
   uiUpdateUIctrl(0)
   MT_post("GuiGDIupdaterResize", PrevGuiSizeEvent)
}

WM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
   isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
   If !isOkay
      Return 0

   If preventSillyGui(A_Gui)
      Return

   If (slideShowRunning=1 || animGIFplaying=1)
   {
      turnOffSlideshow()
      Return 0
   }

   prefix := ""
   prefix .= (wParam & 4) ? "+" : "" ; shift
   prefix .= (wParam & 8) ? "^" : "" ; ctrl
   prefix .= GetKeyState("Alt", "P") ? "!" : ""
   ; HI := (Value >> 16) & 0xFFFF
   ; LO := Value & 0xFFFF
   mouseData := (wParam >> 16)      ; return the HIWORD -  high-order word 
   ; TulTip(" == ", result, resultA, resultB, resultC, resultD, resultE)
   ; stepping := Round(Abs(mouseData) / 120)
   ; ToolTip, % prefix , , , 2
   If (msg=526) ; horizontal mouse wheel
      direction := (mouseData>0 && mouseData<51234) ? "Right" : "Left"
   Else
      direction := (mouseData>0 && mouseData<51234) ? "WheelUp" : "WheelDown"

   MT_post("KeyboardResponder", prefix direction, PVhwnd, 0, navKeysCounter)
   Return 0
}

preventSillyGui(thisGui) {
  r := (thisGui="mouseToolTipGuia" || thisGui="menuFlier") ? 1 : 0
  Return r
}

uiWM_LBUTTONDOWN(wP, lP, msg, hwnd) {
    Static lastInvoked := 1
    If TestDraggableWindow()
       Return

    pp := 0
    thisWin := isVarEqualTo(WinActive("A"), PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin)
    If (preventSillyGui(A_Gui) || !thisWin)
       Return

    ; If (runningLongOperation=1 || imageLoading=1 || whileLoopExec=1)
    ;    Return
 
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    If (A_TickCount - lastSwipeZeitGesture<350)
       pp := 0
    Else If ((drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0) && (thisWin=1 && isOkay=1))
       pp := 1

    If ((A_TickCount - scriptStartTime<500) || (A_TickCount - lastWinDrag<400) || (A_TickCount - lastDoubleClickZeit<400) && pp=1)
       Return 0

    LbtnDwn := 1
    lastInvoked := A_TickCount
    lastALclickX := lastLclickX := lP & 0xFFFF
    lastALclickY := lastLclickY := lP >> 16
    If detectToolbar()
    {
       whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
       JEE_ClientToScreen(PVhwnd, lastLclickX, lastLclickY, mXo, mYo)
       JEE_ScreenToClient(whichWin, mXo, mYo, lastALclickX, lastALclickY)
    }

    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    SetTimer, ResetLbtn, -55
    ; ToolTip, % OutputVarControl "|" hFlyBtn1 , , , 2
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1) ? 0 : 1
    If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900) && slideShowRunning!=1 && animGIFplaying!=1)
       askAboutStoppingOperations()
    Else If (slideShowRunning=1 || animGIFplaying=1)
       turnOffSlideshow()
    Else If isOkay
       uiWinClickAction()
    Return 0
}

uiWM_LBUTTONUP(wP, lP, msg, hwnd) {
    If (statusBarTooltipVisible=1)
       mouseTurnOFFtooltip()

    LbtnDwn := 0
    colorPickerMustEnd := 1
    If (menusflyOutVisible=1)
    {
       MouseGetPos, , , OutputVarWin, hwnd, 2
       OutputDebug, % "QPVMERGE: flyout btn-up ctrl=" hwnd " [S=" hFlyBtn1 " T=" hFlyBtn2 " M=" hFlyBtn3 "] win=" OutputVarWin
       If isVarEqualTo(hwnd, hFlyBtn1, hFlyBtn2, hFlyBtn3)
          Gui, MclickH: Destroy

       If (hwnd=hFlyBtn1)
          ; testPDFloader()
          uiPanelQuickSearchMenuOptions()
       Else If (hwnd=hFlyBtn2)
          uiToggleAppToolbar()
       Else If (hwnd=hFlyBtn3)
          uiToggleMenuBaru()
    }
    Return 0
}

WM_MBUTTONDOWN(wP, lP, msg, hwnd) {
    If !isUIrootWin(hwnd)  ; pre-merge this handler saw only the interface windows
       Return
    If (A_TickCount - scriptStartTime<500)
       Return 0

    If (statusBarTooltipVisible=1)
       mouseTurnOFFtooltip()

    colorPickerMustEnd := -1
    If preventSillyGui(A_Gui)
       Return

    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    LbtnDwn := 0
    canCancelImageLoad := 4
    If (slideShowRunning=1 || animGIFplaying=1)
    {
       turnOffSlideshow()
       Return 0
    }

    mX := lP & 0xFFFF
    mY := lP >> 16
    If detectToolbar()
    {
       whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
       JEE_ClientToScreen(PVhwnd, mX, mY, mXo, mYo)
       JEE_ScreenToClient(whichWin, mXo, mYo, mX, mY)
    }

    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1) ? 0 : 1
    If (drawingShapeNow=1)
       sendWinClickAct("remClick", "n", mX, mY)
    Else If (imgEditPanelOpened=1 && AnyWindowOpen)
       MT_post("toggleImgEditPanelWindow")
    Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
       askAboutStoppingOperations()
    Else If (!AnyWindowOpen && isOkay)
       MT_post("ToggleThumbsMode")
    Return 0
}

WM_LBUTTON_DBL(wP, lP, msg, hwnd) {
    Static lastInvoked := 1, thisX, thisY
    LbtnDwn := 0
    isOkay := (whileLoopExec=1 || runningLongOperation=1 || imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    thisWin := isVarEqualTo(WinActive("A"), PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin)
    oX := mX := lP & 0xFFFF
    oY := mY := lP >> 16
    If (!thisX || !thisY || (A_TickCount - lastInvoked>500))
       mm := 0
    Else
       mm := isDotInRect(mX, mY, 15, 15, thisX, thisY, 1)

    thisX := mX, thisY := mY
    If ((drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0) && (thisWin=1 && isOkay=1 && mm=1))
    {
       If detectToolbar()
       {
          whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
          JEE_ClientToScreen(PVhwnd, mX, mY, mXo, mYo)
          JEE_ScreenToClient(whichWin, mXo, mYo, mX, mY)
       }

       Sleep, 1
       lastDoubleClickZeit := A_TickCount
       uiInitGuiContextMenu(mX, mY, oX, oY)
       Return 0
    }

    zz := (A_TickCount - lastSwipeZeitGesture<350) ? 1 : 0
    If ((A_TickCount - scriptStartTime<500) || !isOkay || (A_TickCount - lastInvoked<350) && zz=0)
       Return 0

    If (preventSillyGui(A_Gui) || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0)
       Return 0

    lastInvoked := A_TickCount
    lastDoubleClickZeit := A_TickCount
    If (slideShowRunning=1 || animGIFplaying=1)
    {
       turnOffSlideshow()
       Return 0
    }
    ; ToolTip, % "z=" zz , , , 2
    If (zz=1)
       uiWinClickAction()
    Else If (A_TickCount - lastMouseLeave>350)
       uiWinClickAction("DoubleClick")

    Return 0
}

stopDupesEngineNow() {
   ; The main thread polls mustAbandonCurrentOperations, but it cannot poll anything while
   ; it is inside sqlite3_step() waiting for SQLite to sort the duplicate-candidate query -
   ; which on a large library is where most of the wait is. This thread is the only one
   ; left able to say stop, and sqlite3_interrupt() is documented as safe to call from
   ; another thread. A qpvmain.dll too old to export it just sets ErrorLevel.
   DllCall("qpvmain.dll\dupesEngineCancel", "int")
}

askAboutStoppingOperations() {
     If (mustAbandonCurrentOperations!=1)
     {
        userPendingAbortOperations := 1
        lastCloseInvoked := 0
        WinSet, Enable,, ahk_id %PVhwnd%
        msgResult := simpleMsgBoxWrapper(appTitle, "Do you want to stop the currently executing operation ?", 4, 0, "question")
        If (msgResult="yes")
        {
           mustAbandonCurrentOperations := 1
           userPendingAbortOperations := 0
           stopDupesEngineNow()
        } Else
           userPendingAbortOperations := 0
     } Else userPendingAbortOperations := 0
      ; Else SoundBeep , % 250 + 100*lastCloseInvoked, 100
}

WM_RBUTTONUP(wParam, lP, msg, hwnd) {
  If !isUIrootWin(hwnd)  ; pre-merge this handler saw only the interface windows
     Return
  LbtnDwn := 0
  If (A_TickCount - scriptStartTime<500)
     Return 0

  If (statusBarTooltipVisible=1)
     mouseTurnOFFtooltip()

  colorPickerMustEnd := -1
  If preventSillyGui(A_Gui)
     Return

  If (slideShowRunning=1 || animGIFplaying=1)
  {
     turnOffSlideshow()
     Return 0
  }

  If (mouseToolTipWinCreated=1)
     mouseTurnOFFtooltip()

  ; thumbsDisplaying := thumbsDisplaying
  ; AnyWindowOpen := AnyWindowOpen
  ; maxFilesIndex := maxFilesIndex
  If !identifyThisWin()
     Return 0

  If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
  {
     askAboutStoppingOperations()
     Return 0
  }

  prefix := ""
  ; masked one modifier at a time, see WM_MOUSEWHEEL() for why
  prefix .= (wParam & 4) ? "+" : "" ; shift
  prefix .= (wParam & 8) ? "^" : "" ; ctrl
  oX := mX := lP & 0xFFFF
  oY := mY := lP >> 16
  If (whileLoopExec!=1 && runningLongOperation!=1)
  {
     If detectToolbar()
     {
        whichWin := (thumbsDisplaying=1) ? hGDIthumbsWin : hGDIwin
        JEE_ClientToScreen(PVhwnd, mX, mY, mXo, mYo)
        JEE_ScreenToClient(whichWin, mXo, mYo, mX, mY)
     }

     If (prefix="^" && !AnyWindowOpen && drawingShapeNow!=1 && mustCaptureCloneBrush!=1 && thumbsDisplaying!=1)
        MT_post("restartGIFplayback")
     Else If (prefix="+" && !AnyWindowOpen && drawingShapeNow!=1 && mustCaptureCloneBrush!=1)
        MT_post("BuildSecondMenu")
     Else
        uiInitGuiContextMenu(mX, mY, oX, oY)
  }
  Return 0
}

uiPanelQuickSearchMenuOptions() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return
 
    If (VisibleQuickMenuSearchWin=1)
       MT_post("closeQuickSearch")
    Else
       MT_post("PanelQuickSearchMenuOptions")
    lastInvoked := A_TickCount
}

uiToggleAppToolbar() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return

    MT_post("toggleAppToolbar")
    lastInvoked := A_TickCount
}

uiToggleMenuBaru() {
    Static lastInvoked := 1
    If (A_TickCount - lastInvoked<300)
       Return

    MT_post("ToggleMenuBaru")
    lastInvoked := A_TickCount
}

uiInitGuiContextMenu(mX, mY, oX, oY) {
    ctrl := IdentifyCtrlUnderMouse(oX, oY)
    MT_post("InitGuiContextMenu", "extern", mX, mY, 0, ctrl)
}

; [merge] infosSlideShow() and initSlidesModes() are gone: they only mirrored the
; slideshow flags into this interpreter, and the globals are shared now.

slideshowsHandler(thisSlideSpeed, act, how, msgu:=0) {
   OutputDebug, % "QPVMERGE: slideshowsHandler act=" act " speed=" thisSlideSpeed " mode=" how
   SlideHowMode := how
   ; [merge fix] this line was «slideShowDelay := thisSlideSpeed». Pre-merge it set
   ; only the interface interpreter's own copy - the effective cadence, possibly
   ; stretched to the music length. On one interpreter it clobbered the USER
   ; PREFERENCE: the "stop" call passes 0, so every stop zeroed the speed and the
   ; next start ran wrong until the user set the speed again. The cadence is its
   ; own module variable now and only a "start" updates it.
   prevFullIMGload := 1
   If (act="start")
   {
      slideShowCadence := (thisSlideSpeed>0) ? thisSlideSpeed : slideShowDelay
      setTaskbarIconState("normal")
      slideShowRunning := 1
      SetTimer, theSlideShowCore, % -slideShowCadence
      If msgu
      {
         GuiControl, PVwin:, PicOnGUI1, % msgu
         GuiControl, PVwin:, PicOnGUI2a, % msgu
         GuiControl, PVwin:, PicOnGUI2b, % msgu
         GuiControl, PVwin:, PicOnGUI2c, % msgu
         GuiControl, PVwin:, PicOnGUI3, % msgu
      }
   } Else If (act="stop")
   {
      allowNextSlide := 1
      slideShowRunning := 0
      SetTimer, theSlideShowCore, Off
      uiUpdateUIctrl()
      uiAccessImgViewSetUIlabels()
   }
}

dummySlideshow() {
   OutputDebug, % "QPVMERGE: dummySlideshow running=" slideShowRunning " allowNext=" allowNextSlide
   If (slideShowRunning=1 && allowNextSlide=1)
   {
      setTaskbarIconState("Normal")
      SetTimer, theSlideShowCore, % -slideShowCadence
   }
}

theSlideShowCore(paramu:=0) {
  thisZeit :=  A_TickCount - prevFullIMGload
  OutputDebug, % "QPVMERGE: slideCore param=" paramu " zeit=" thisZeit " cadence=" slideShowCadence " allowNext=" allowNextSlide " running=" slideShowRunning
  If (thisZeit < slideShowCadence//1.25) || (allowNextSlide!=1 && paramu!="force")
     Return

  mouseTurnOFFtooltip()
  prevFullIMGload := A_TickCount
  Try DllCall("user32\SetCursor", "Ptr", 0)
  If (slideShowRunning=1 && slidesFXrandomize=1)
     MT_post("VPimgFXrandomizer")

  If (SlideHowMode=1)
     MT_post("RandomPicture")
  Else If (SlideHowMode=2)
     MT_post("PreviousPicture")
  Else If (SlideHowMode=3)
     MT_post("NextPicture")
}

WM_PENpressure(wp, lp, msg, hwnd) {
; Records the current pen pressure so the painting loops in the main thread can poll it.
; Never returns a value: the message must keep flowing to DefWindowProc, otherwise
; Windows stops promoting pen input to the legacy mouse messages the app relies on.
   Critical, off
   Static penInfoBuf, bufReady := 0

   If (msg=0x0247 || msg=0x024A) ; WM_POINTERUP / WM_POINTERLEAVE
   {
      penPressureRaw := 0
      Return
   }

   If (bufReady!=1)
   {
      ; sizeof(POINTER_PEN_INFO): POINTER_INFO (96 on x64, 88 on x86) + 6 x 4 bytes
      VarSetCapacity(penInfoBuf, (A_PtrSize=8) ? 120 : 112, 0)
      bufReady := 1
   }

   ; GetPointerPenInfo() fails for touch and mouse pointers, so only a real pen gets through
   If !DllCall("user32\GetPointerPenInfo", "UInt", wp & 0xFFFF, "UPtr", &penInfoBuf)
      Return

   pointerFlags := NumGet(penInfoBuf, 12, "UInt")
   If !(pointerFlags & 0x4) ; POINTER_FLAG_INCONTACT ; hovering, not touching
   {
      penPressureRaw := 0
      Return
   }

   thisPressure := NumGet(penInfoBuf, (A_PtrSize=8) ? 104 : 96, "UInt")
   If (thisPressure<1) ; the digitizer does not report pressure at all
      Return

   penPressureRaw := thisPressure ; normalized by Windows to the 0-1024 range
}

updateGDIwinPos() {
  ; thumbsDisplaying := thumbsDisplaying
  ; If (A_OSVersion="WIN_7")
  JEE_ClientToScreen(hPicOnGui1, 0, 0, GuiX, GuiY)
  ; Else GuiX := GuiY := 1

  GetClientSize(mainWidth, mainHeight, PVhwnd)
  If (thumbsDisplaying=1)
  {
     WinMove, ahk_id %hGDIthumbsWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
     WinSet, Region, 0-0 R6-6 w%mainWidth% h%mainHeight% , ahk_id %hGDIthumbsWin%
  }
  WinMove, ahk_id %hGDIWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
  WinMove, ahk_id %hGDIselectWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
  WinMove, ahk_id %hGDIinfosWin%,, %GuiX%, %GuiY% ; , %mainWidth%, %mainHeight%
}

IdentifyCtrlUnderMouse(mX, mY) {
  Static ctrlsList := {11:"OSDmsgsLine", 5:"PicVscroll", 6:"PicHscroll", 9:"ImgInfoBox", 7:"ImgNavBox", 8:"ImgHistoBox", 10:"ImgAnnoBox", 0:"PicOnGui1", 1:"PicOnGui2a", 2:"PicOnGui2b", 3:"PicOnGui2c", 4:"PicOnGui3"}

  ctrlName := A_GuiControl
  Loop, 12
  {
      a := A_Index - 1
      r := GetWindowPlacement(hPic%a%)
      ; fnOutDebug(a "=" mX "|" mY "=" r.x "|" r.y)
      If isDotInRect(mX, mY, r.x, r.x + r.w, r.y, r.y + r.h)
      {
         ctrlName .= "|" ctrlsList[a]
         ; Break
      }
  }
  ; ToolTip, % ctrlName , , , 2
  Return ctrlName "|"
}

uiWinClickAction(thisEvent:="normal") {
    Static lastInvoked := 1
    MouseGetPos, ,, OutputVarWin
    If ((A_TickCount - lastInvoked<25) || (OutputVarWin=hGuiTip))
       Return

    ; GetMouseCoord2wind(PVhwnd, mX, mY, mXo, mYo)
    mX := lastALclickX,    mY := lastALclickY
    ; ToolTip, % mX "=" mY "`n" lastLclickX "=" lastLclickY , , , 2
    canCancelImageLoad := 4
    If (mouseToolTipWinCreated=1)
       mouseTurnOFFtooltip()

    ; ToolTip, % mX "=" mY "=" param "==" ctrlName "--" A_GuiControl "--" A_GuiControlEvent , , , 2
    lastInvoked := A_TickCount
    If (slideShowRunning=1)
       turnOffSlideshow()
    ; Else If (A_TickCount - lastZeitPanCursor<350) && (thumbsDisplaying=0)
    ;    MT_post("simplePanIMGonClick", 0, 1, 1)
    Else
       sendWinClickAct(thisEvent, IdentifyCtrlUnderMouse(lastLclickX, lastLclickY), mX, mY)
}

sendWinClickAct(ctrlEvent, guiCtrl, mX, mY) {
   ; ToolTip, % guiCtrl "|" mX "|" mY , , , 2
   ; fnOutDebug("UI event: " ctrlEvent "==" guiCtrl "|" mX "|" mY)
   MT_post("WinClickAction", ctrlEvent, guiCtrl, mX, mY)
}

ResetLbtn() {
  If GetKeyState("LButton", "P")
     SetTimer, ResetLbtn, -60
  Else
     LbtnDwn := 0
}

WM_WINDOWPOSCHANGED(wP:=0, lP:=0, msg:=0, hwnd:=0) {
   If (hwnd && hwnd!=PVhwnd)  ; post-merge every window's pos-changes arrive; act only for the main window
      Return
   Static b
   WinGet, winStateu, MinMax, ahk_id %PVhwnd%
   If (winStateu=-1)
      Return

   WinGetPos, winX, winY, winWidth, winHeight, ahk_id %PVhwnd%
   a := "a" winX winY winWidth winHeight
   If (a!=b)
   {
      ; Random, z, -900, 900
      ; ToolTip, % z , , , 2
      If (tempBtnVisible!="null")
         SetTimer, uiRepositionTempBtnGui, -95

      SetTimer, uiSaveMainWinPos, -35
      Global lastWinDrag := A_TickCount
      If (A_OSVersion="WIN_7" || isWinXP=1)
         SetTimer, updateGDIwinPos, -5
      If (ShowAdvToolbar=1 && lockToolbar2Win=1)
         SetTimer, updateTlbrPosition, -10
      b := a
  }
}

uiRepositionTempBtnGui() {
     MT_post("RepositionTempBtnGui")
}

uiSaveMainWinPos() {
     MT_post("saveMainWinPos")
}

uiChangeMcursor(whichCursor) {
   Static hCursBusy := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32514, "Ptr")  ; IDC_WAIT
        , hCursN := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32512, "Ptr")  ; IDC_ARROW
        , hCursMove := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32646, "Ptr")  ; IDC_Hand
        , hCursCross := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32515, "Ptr")  ; IDC_Cross
        , hCursFinger := DllCall("user32\LoadCursorW", "UPtr", NULL, "Int", 32649, "Ptr")

  If (slideShowRunning=1 || animGIFplaying=1)
     Return

  If (A_TickCount - lastZeitPanCursor<50)
     thisCursor := hCursMove

  If (whichCursor="normal-extra")
  {
     userPendingAbortOperations := imageLoading := mustAbandonCurrentOperations := 0
     runningLongOperation := lastCloseInvoked := 0
     setTaskbarIconState("normal")
     ; setMenuBarState("Enable")
     thisCursor := hCursN
  } Else If (whichCursor="busy-img")
  {
     imageLoading := 1
     lastCloseInvoked := 0
     setTaskbarIconState("anim")
     thisCursor := hCursBusy
  } Else If (whichCursor="busy" && LbtnDwn!=1)
  {
     setTaskbarIconState("anim")
     thisCursor := hCursBusy
  } Else If (whichCursor="normal")
  {
     imageLoading := 0
     setTaskbarIconState("normal")
     thisCursor := hCursN
  } Else If (whichCursor="finger")
  {
     thisCursor := hCursFinger
  } Else If (whichCursor="move")
  {
     lastZeitPanCursor := A_TickCount
     thisCursor := hCursMove
  } Else If (whichCursor="cross")
  {
     thisCursor := hCursCross
  } Else Return

  Try DllCall("user32\SetCursor", "UPtr", thisCursor)
}

isQPVactive() {
    Static lastInvoked := 1, last := 1
    If ((A_TickCount - lastInvoked<450) && (last=0))
       Return last

    A := WinActive("A")
    lastInvoked := A_TickCount
    ; last := (A=hSetWinGui && AnyWindowOpen || A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin || A=hGDIinfosWin || A=hGuiTip && mouseToolTipWinCreated=1 || A=hquickMenuSearchWin && VisibleQuickMenuSearchWin=1 || A=hQPVtoolbar && ShowAdvToolbar=1 || A=hfdTreeWinGui && folderTreeWinOpen=1) ? 1 : 0
    last := (A=hSetWinGui && AnyWindowOpen || A=PVhwnd || A=hGDIwin || A=hGDIthumbsWin || A=hGDIinfosWin || A=hGuiTip && mouseToolTipWinCreated=1 || A=hquickMenuSearchWin && VisibleQuickMenuSearchWin=1 || A=hQPVtoolbar && ShowAdvToolbar=1 || A=hfdTreeWinGui && folderTreeWinOpen=1 || A=hFlyOut && menusflyOutVisible=1) ? 1 : 0
    Return last
}

showMouseTooltipStatusbar() {
    MouseGetPos, ,, OutputVarWin
    If (LbtnDwn=1 || menusflyOutVisible=1 || !lastWinStatus || !thumbsDisplaying) || (A_TickCount - lastZeitToolTip<1000) || (OutputVarWin!=PVhwnd)
       Return

    thisSize := OSDfontSize//3.5 + 2
    statusBarTooltipVisible := 1
    mouseCreateOSDinfoLine(lastWinStatus, thisSize)
    SetTimer, mouseTurnOFFtooltip, -4500
}


uiWM_MOUSEMOVE(wP, lP, msg, hwnd) {
  Static lastInvoked := 1, prevPos, lastTip := 1, prevArrayPos := [], darked := 0
  If ((A_TickCount - lastZeitPanCursor < 300) || !isQPVactive())
     Return

  If (wP&0x1)
  {
     LbtnDwn := 1
     SetTimer, ResetLbtn, -55
  }

  mX := lP & 0xFFFF
  mY := lP >> 16
  If (A_TickCount - prevFullIMGload<150)
     prevArrayPos := [mX, mY]
  ; MouseGetPos, mX, mY, OutputVarWin
  isSamePos := (isInRange(mX, prevArrayPos[1] + 3, prevArrayPos[1] - 3) && isInRange(mY, prevArrayPos[2] + 3, prevArrayPos[2] - 3)) ? 1 : 0
  thisWin := isVarEqualTo(hwnd, PVhwnd, hGDIwin, hGDIthumbsWin, hGDIinfosWin, hGDIselectWin) ? 1 : 0
  If (slideShowRunning=1 && isSamePos=1)
     Try DllCall("user32\SetCursor", "Ptr", 0)
  Else If (drawingShapeNow=1 && doNormalCursor=0 || liveDrawingBrushTool=1 || AnyWindowOpen=66 && FloodFillSelectionAdj=0) && (thisWin=1)
     uiChangeMcursor("cross")
  Else If ((runningLongOperation=1 || imageLoading=1) && slideShowRunning!=1)
     uiChangeMcursor("busy")
  Else If (thumbsDisplaying=1 && !AnyWindowOpen && runningLongOperation!=2 && imageLoading!=1 && lastWinStatus)
  {
     ctrlu := IdentifyCtrlUnderMouse(mX, mY) 
     If VarContainsThis(ctrlu, "|PicOnGUI2a|", "|picVscroll|", "|ImgNavBox|")
     {
        uiChangeMcursor("finger")
        If (isSamePos=0 && (A_TickCount - lastZeitToolTip>1000) && InStr(ctrlu, "|PicOnGUI2a|"))
           SetTimer, showMouseTooltipStatusbar, -500
     } Else If (isSamePos=0)
        SetTimer, showMouseTooltipStatusbar, Off
  }

  If ((A_TickCount - scriptStartTime < 900) || (whileLoopExec=1 || runningLongOperation=1 || slideShowRunning=1))
     Return

  If (menusflyOutVisible=1)
  {
     WinGetPos, xu, yu, ww, hh, ahk_id %hFlyOut%
     If (xu && yu && ww && hh && (A_TickCount - lastTip>250))
     {
        MouseGetPos, , , OutputVarWin, hwnd, 2
        yu += hh + 2
        If (hwnd=hFlyBtn1)
           Tooltip, Search options [ `; ], % xu, % yu
        Else If (hwnd=hFlyBtn2)
           Tooltip, Toolbar [ Shift+F10 ], % xu, % yu
        Else If (hwnd=hFlyBtn3)
           Tooltip, Menu bar [ F10 ], % xu, % yu
        lastTip := A_TickCount
     } Else If (uiUseDarkMode=1)
     {
        HTT := GetWindowFromPos(xu + 5, yu + hh + 5)
        WinGetClass, classu, ahk_id %HTT%
        If (InStr(classu, "tooltips") && HTT!=darked)
        {
           darked := HTT
           DllCall("uxtheme\SetWindowTheme", "uptr", HTT, "str", "DarkMode_Explorer", "ptr", 0)
        }
        ; ToolTip, % "p=" classu "`n" xu "|" yu "`n" xu2 "|" yu2 , , , 2
     } 
  }

  thisPos := mX "-" mY
  prevArrayPos := [mX, mY]
  If (A_TickCount - lastInvoked > 55) && (thisPos!=prevPos)
  {
     ; isThisWin :=(OutputVarWin=PVhwnd) ? 1 : 0
     thisPrefsWinOpen := (imgEditPanelOpened=1) ? 0 : AnyWindowOpen
     lastInvoked := A_TickCount
     If (slideShowRunning!=1 && !thisPrefsWinOpen && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1 && whileLoopExec!=1)
        MT_post("MouseMoveResponder")
 
     prevPos := mX "-" mY
  }

  ; ToolTip, % title "= " isTitleBarVisible " - " TouchScreenMode " = " OutputVarWin " = " actif
  ; If (isTitleBarVisible=0 && userAllowWindowDrag=1 && TouchScreenMode=0 && (wP&0x1))
  specials := TestDraggableWindow()
  If (specials=1 && (wP&0x1) && (A_TickCount - lastWinDrag>45))
  {
     PostMessage, 0xA1, 2,,, ahk_id %PVhwnd%
     Global lastWinDrag := A_TickCount
     ; lastWinDrag := lastWinDrag ; [was MT_set - plain global since phase E]
     SetTimer, trackMouseDragging, -55
  } 
}

TestDraggableWindow() {
   If (isTitleBarVisible=0 && slideShowRunning!=1 && imageLoading!=1 && runningLongOperation!=1 && whileLoopExec!=1)
      specials := (GetKeyState("Shift", "T") && GetKeyState("Ctrl", "P")) ? 1 : 0
   Return specials
}

trackMouseDragging() {
    Global lastWinDrag := A_TickCount
}

WM_MOUSELEAVE(wP, lP, msg, hwnd) {
   If !isUIrootWin(hwnd)  ; pre-merge this handler saw only the interface windows
      Return
    lastMouseLeave := A_TickCount
}

activateMainWin(wP:=0, lP:=0, msg:=0, hwnd:=0) {
   If (hwnd && !isUIrootWin(hwnd))  ; pre-merge this handler saw only the interface windows
      Return
   If (A_TickCount - scriptStartTime<2000)
      Return

   lastMouseLeave := A_TickCount
   If (A_TickCount - lastOtherWinClose>500)
      colorPickerMustEnd := 1

   LbtnDwn := 0
   Sleep, -1
   MouseGetPos, ,, winu
   ; z := identifyThisWin()
   If (winu!=hQPVtoolbar && editingSelectionNow=1 && slideShowRunning!=1 && imageLoading!=1 && runningLongOperation!=1 && thumbsDisplaying!=1
   && (A_TickCount - lastMenuHoverZeit>300) && (A_TickCount - lastMenuZeit>300) && (A_TickCount - lastContextMenuZeit>200))
      MT_post("MouseMoveResponder", "krill")

   If (menusflyOutVisible=1 && !identifyMenus())
      SetTimer, hideMenuFlyOut, -50

   ; If (mouseToolTipWinCreated=1 && !z && !identifyParentWind())
   If (mouseToolTipWinCreated=1)
      SetTimer, mouseTurnOFFtooltip, -150
}

PVwinGuiSize(GuiHwnd, EventInfo, Width, Height) {
    If (A_TickCount - lastMenuBarUpdate < 150)
       Return

    PrevGuiSizeEvent := EventInfo
    ; ToolTip, % "l=" EventInfo , , , 2
    turnOffSlideshow()
    canCancelImageLoad := 4
    delayu := (isWinXP=1 || thumbsDisplaying=1) ? -15 : -5
    SetTimer, miniGDIupdater, % delayu
}

PVwinGuiDropFiles(GuiHwnd, FileArray, CtrlHwnd, X, Y) {
   Static lastInvoked := 1
   If (AnyWindowOpen>0 || mustCaptureCloneBrush=1 || whileLoopExec=1 || drawingShapeNow=1 || imageLoading=1 || runningLongOperation=1 || groppedFiles.Count()>0) || (A_TickCount - lastInvoked<300)
      Return

   lastInvoked := A_TickCount
   GuiHwnd := Format("{1:#x}", GuiHwnd)
   ; ToolTip, % GuiHwnd "`n" PVhwnd "`n" hGDIwin "`n" hGDIthumbsWin "`n" hGDIselectWin "`n" hGDIinfosWin, , , 2
   For i, file in FileArray
       groppedFiles[A_Index] := Trimmer(file)

   SetTimer, dummyTimerProcessDroppedFiles, -200
   lastInvoked := A_TickCount
   Return
}

dummyTimerProcessDroppedFiles() {
   Static lastInvoked := 1
   totalGroppy := groppedFiles.Count()
   If (!totalGroppy || (A_TickCount - lastInvoked<400))
      Return

   ; [merge] RegExFilesPattern is the live main-script global now - the registry
   ; round-trip existed only for the separate interpreter
   isCtrlDown := GetKeyState("Ctrl", "P")
   lastInvoked := A_TickCount
   vectorShape := imgFiles := foldersList := sldFile := ""
   turnOffSlideshow()
   canCancelImageLoad := 4
   countD := countV := countF := countFiles := 0
   ToolTip, Please wait - processing dropped files list , , , 2
   Loop, % totalGroppy
   {
      uiChangeMcursor("busy")
      line := groppedFiles[A_Index]
      If !line
         Continue

      ; MsgBox, % A_LoopField
      If (A_Index>98700)
      {
         Break
      } Else If RegExMatch(line, "i)(.\.sld|.\.sldb)$")
      {
         countD++
         If !sldFile
            sldFile := line
      } Else If RegExMatch(line, "i)(.\.vqpv)$")
      {
         countV++
         vectorShape := line
      } Else If InStr(FileExist(line), "D")
      {
         countF++
         foldersList .= line "`n"
      } Else If RegExMatch(line, RegExFilesPattern)
      {
         countFiles++
         imgFiles .= line "`n"
      }
   }

   ; fnOutDebug("regex: " RegExFilesPattern)
   If (countFiles>1 || countF>1)
      sldFile := ""

   ToolTip, , , , 2
   If !isCtrlDown
      isCtrlDown := GetKeyState("Ctrl", "P")
   If (!imgFiles && !sldFile && vectorShape)
      sldFile := vectorShape

   groppedFiles := []
   MT_post("GuiDroppedFiles", imgFiles, foldersList, sldFile, countFiles, isCtrlDown)
   lastInvoked := A_TickCount
}

PVwinGuiClose:
   byeByeRoutine()
Return

byeByeRoutine() {
   Static lastInvokedThis := 1
   If (A_TickCount - lastInvokedThis < 250)
      Return

   If (runningLongOperation!=1 && imageLoading=1 && animGIFplaying!=1)
   {
      ; SoundBeep , % 250 + 100*lastCloseInvoked, 100
      canCancelImageLoad := 4
      WinSet, Enable,, ahk_id %PVhwnd%
      msgResult := simpleMsgBoxWrapper(appTitle, "The main window seems to be busy at the moment. Do you want to force exit this application ?", 4, 0, "question")
      If (msgResult="yes")
      {
         ; [merge] the old force-exit killed the process within 10ms - issued from
         ; the RESPONSIVE interface interpreter. On one thread, a truly stuck
         ; operation [blocked inside a long DllCall] pumps nothing, so neither a
         ; queued TrueCleanup nor the TimerExit watchdog can fire. The detached
         ; taskkill below is therefore the only guaranteed force-exit: ~8s grace,
         ; then it kills the PID - a no-op if the clean path exited first.
         mustAbandonCurrentOperations := 1
         SetTimer, TimerExit, -8000
         MT_post("TrueCleanup")
         Try Run, %ComSpec% /c ping -n 9 127.0.0.1 >nul 2>&1 && taskkill /PID %QPVpid% /T /F,, Hide
      } Else lastCloseInvoked := -1
      lastCloseInvoked++
   } Else If (runningLongOperation=1 && (A_TickCount - executingCanceableOperation > 900))
   {
      If (mustAbandonCurrentOperations!=1)
         askAboutStoppingOperations()
      Else
         lastCloseInvoked++
   } Else If (drawingShapeNow=1)
   {
       drawingShapeNow := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MT_post("stopDrawingShape", "cancel")
   } Else If (colorPickerModeNow=1)
   {
       colorPickerModeNow := 0
       colorPickerMustEnd := -1
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
   } Else If (VisibleQuickMenuSearchWin=1)
   {
       VisibleQuickMenuSearchWin := omniBoxMode := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MT_post("closeQuickSearch")
   } Else If (mustCaptureCloneBrush=1)
   {
       mustCaptureCloneBrush := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MT_post("StopCaptureClickStuff", "Escape")
   } Else If (folderTreeWinOpen=1)
   {
       folderTreeWinOpen := 0
       lastInvokedThis := A_TickCount
       lastOtherWinClose := A_TickCount
       MT_post("fdTreeClose")
   } Else If ((AnyWindowOpen || thumbsDisplaying=1 || slideShowRunning=1) && (imageLoading!=1 && runningLongOperation!=1)) || (animGIFplaying=1)
   {
      lastInvokedThis := A_TickCount
      If AnyWindowOpen
      {
         lastOtherWinClose := A_TickCount
         AnyWindowOpen := 0
         MT_post("CloseWindow")
      } Else If (animGIFplaying=1)
      {
         lastOtherWinClose := A_TickCount
         If (slideShowRunning=1)
            turnOffSlideshow()

         stopGiFsPlayback()
      } Else If (slideShowRunning=1)
      {
         lastOtherWinClose := A_TickCount
         turnOffSlideshow()
      } Else If (thumbsDisplaying=1)
      {
         lastCloseInvoked := 5 ; exit application 
         ; thumbsDisplaying := 0
         ; lastOtherWinClose := A_TickCount
         ; MT_post("MenuReturnIMGedit")
      } Else lastCloseInvoked++
   } Else If (StrLen(UserMemBMP)>3 && undoLevelsRecorded>1) || (currentFilesListModified=1)
   {
      MT_post("exitAppu", "external")
      ;  lastCloseInvoked++
   } Else If (markedSelectFile>50 && maxFilesIndex>100)
   {
      MT_post("exitAppu", "select-external")
      ;  lastCloseInvoked++
   } Else lastCloseInvoked := 5

   If (A_TickCount - lastOtherWinClose < 650)
      Return

   If (lastCloseInvoked>3)
   {
      ; [merge] the old exit posted TrueCleanup to the main thread and hard-killed
      ; the shared process ~10ms later - RACING the seen-images DB COMMIT inside
      ; TrueCleanup. One interpreter now: run the cleanup synchronously [it ends in
      ; ForceExitNow -> ExitApp]; TimerExit stays armed as a watchdog in case the
      ; cleanup hangs at one of its pump points.
      SetTimer, TimerExit, -8000
      TrueCleanup()
   }
}


TimerExit() {
   ; SoundBeep , 900, 2000
   thisPID := GetCurrentProcessId()
   OutputDebug, QPV: forced exit. Secondary thread. PID=%thisPID%
   Process, Close, % thisPID
   ExitApp
}

; the sole PreventKeyPressBeep [the main script's dead unregistered copy was deleted
; at merge phase C]; registered for 0x101-0x103 and 0x105-0x108 in initInterfaceModule()
PreventKeyPressBeep() {
   IfEqual,A_Gui,PVwin,Return 0 ; prevent keystrokes for the main window [PVwin] only
}

destroyMenuFlyout() {
   wasMenuFlierCreated := 0
   Gui, menuFlier: Destroy
   Tooltip
}

guiCreateMenuFlyout() {
   Critical, on
   Static m := 2
   h := LargeUIfontValue * 2 + 1
   Gui, menuFlier: +AlwaysOnTop -MinimizeBox -SysMenu -Caption +ToolWindow +hwndhFlyOut
   If (uiUseDarkMode=1)
   {
      brd := "+border"
      Gui, menuFlier: Color, 212121
      Gui, menuFlier: Font, s12 Bold cFFffFF
   } Else
   {
      brd := ""
      Gui, menuFlier: Color, EEeeEE
      Gui, menuFlier: Font, s12 Bold c111111
   }

   Gui, menuFlier: Margin, 0, 0
   Gui, menuFlier: Add, Text, %brd% Center +0x200 x0 y0 w%h% h%h% hwndhFlyBtn1 +TabStop, S
   Gui, menuFlier: Add, Text, %brd% Center +0x200 x+%m% wp hp hwndhFlyBtn2 +TabStop, T
   Gui, menuFlier: Add, Text, %brd% Center +0x200 x+%m% wp hp hwndhFlyBtn3 +TabStop, M
   ; AddTooltip2Ctrl(hFlyBtn1, "Search through the available options [ `; ]",, uiUseDarkMode)
   ; AddTooltip2Ctrl(hFlyBtn2, "Toggle app toolbar [ Shift+F10 ]",, uiUseDarkMode)
   ; AddTooltip2Ctrl(hFlyBtn3, "Toggle menu bar [ F10 ]",, uiUseDarkMode)
   ; AddTooltip2Ctrl("AutoPop", 0.1)
   wasMenuFlierCreated := 1
}

menuFlyoutDisplay(actu, mX, mY, isOkay, darkMode:=0, thisHwnd:=0, idu:=0) {
   Critical, on
   lastOtherWinClose := A_TickCount
   lastContextMenuZeit := A_TickCount
   uiUseDarkMode := (darkMode="yes") ? 1 : 0
   ; [phase D fix] «allowMenuReader := actu» is GONE: setWinCloseZeit posts a "no"
   ; after every menu-item selection, and pre-merge the next programmatic menu
   ; open re-armed the flag - native bar opens never do, so choosing any item
   ; [e.g. opening a favourites image] killed the bar flyout until the next
   ; right-click menu. The flag stays a stable "yes" [seeded]; a non-"yes" call
   ; still performs its hide/reset duties below.
   ; ToolTip, % "d=" darkMode , , , 2
   If (IsNumber(idu) && idu>0)
      menuCurrentIndex := idu

   If (idu="reset")
      menuCurrentIndex := 0
   Else

   If (!isOkay && actu="yes")
      Return

   If (wasMenuFlierCreated!=1)
      guiCreateMenuFlyout()

   ; [merge fix] the old display leg armed dummyMenuFlyoutDisplay on a -25 AHK
   ; timer. Post-merge that timer sat PENT UP through the modal loop and fired the
   ; moment the menu closed - found no visible menu and HID the flyout right under
   ; the user's finger, so the S/T/M buttons never received their click. Display
   ; belongs to the native ticker now [uiMenuNativeTick]; a non-"yes" call still
   ; requests the hide pass.
   If (actu!="yes")
      SetTimer, hideMenuFlyOut, -35
}

hideMenuFlyOut() {
    If (A_TickCount - flyoutGraceZeit < 350)  ; post-menu-close grace: keep the buttons clickable
    {
       SetTimer, hideMenuFlyOut, -120
       Return
    }
    MouseGetPos,,, OutputVarWin
    ; WinGetClass, glassu, ahk_id %OutputVarWin%
    ; WinGetTitle, titlu, ahk_id %OutputVarWin%
    ; ToolTip, % OutputVarWin "==" hFlyOut "`n" glassu "==" titlu , , , 2
    If (OutputVarWin!=hFlyOut && !identifyMenus())
    {
       Tooltip
       menusflyOutVisible := 0
       Gui, menuFlier: Hide
       Gui, MclickH: Hide
       SetTimer, hideMenuFlyOut, Off
    } Else If (menusflyOutVisible=1)
       SetTimer, hideMenuFlyOut, -35
}

stopGiFsPlayback() {
   If (animGIFplaying!=0)
   {
      OutputDebug, % "QPVMERGE: stopGiFsPlayback via " Exception("", -2).What

      lastOtherWinClose := A_TickCount
      animGIFplaying := 0
      MT_post("autoChangeDesiredFrame", "stop")
      uiChangeMcursor("normal-extra")
   }
}

turnOffSlideshow() {
   OutputDebug, % "QPVMERGE: turnOffSlideshow via " Exception("", -2).What " running=" slideShowRunning
   stopGiFsPlayback()
   If (slideShowRunning!=1)
      Return

   slideShowRunning := 0
   SetTimer, theSlideShowCore, Off
   MT_post("dummyInfoToggleSlideShowu", "stop")
   If (slideShowCadence<950)
      SoundBeep , 900, 100
   lastOtherWinClose := A_TickCount
}

invokeGivenMenuBarPopup(n) {
; [phase D] menuArray[n,2] now holds the ":menuName" submenu attachment, so the
; builder comes from menuJITlist instead; the builder shows at the bar-item rect
; itself [showThisMenu manubarMode], no F10 focus dance needed
   n := clampInRange(n, 1, menuTotalIndex, 1)
   funcu := menuJITlist[n]
   If IsFunc(funcu)
   {
      lastMenuZeit := A_TickCount
      %funcu%(n)
   }
}

uiAlphaMaskTrigger(a, b, c, d, e) {
  AnyWindowOpen := a
  liveDrawingBrushTool := b
  editingSelectionNow := c
  UserMemBMP := d
  showMainMenuBar := e
  thumbsDisplaying := 0
  UpdateMenuBar()
}

BuildMenuBar(modus:=0, applyFilter:=0) {
   Static menusListView := "File:File|Edit:Edit|Selection:Selection|Image:Image|Captions:Captions|Slides:Slides|Find:Find|List:List|Navigate:Navigate|View:View|Interface:Interface|Settings:Settings|Help:Help"
        , menusListEditor := "File:EditorFile|Edit:Edit|Selection:EditorSelection|Image:Image|Live tools:EditorTools|View:View|Interface:Interface"
        , menusListAlphaMasking := "Alpha mask:AlphaMask|View:View|Interface:Interface"
        , menusListVector := "File:VectorFile|Edit:VectorEdit|Selection:VectorSelection|View:VectorView|Interface:VectorInterface"
        , menusListThumbs := "File:File|Edit:Edit|Selection:Selection|Image:Image|Slides:Slides|Find:Find|List:List|Sort:Sort|Navigate:Navigate|View:View|Interface:Interface|Settings:Settings|Help:Help"
        , menusListWelcome := "File:File|Edit:Edit|Interface:Interface|Settings:Settings|Help:Help"

   If (modus="welcome")
      menusList := menusListWelcome
   Else If (modus="freeform" || drawingShapeNow=1)
      menusList := menusListVector
   Else If isNowAlphaPainting()
      menusList := menusListAlphaMasking
   Else If (imgEditPanelOpened=1 && AnyWindowOpen)
      menusList := menusListEditor
   Else If (thumbsDisplaying=1)
      menusList := menusListThumbs
   Else
      menusList := menusListView

   menuArray := []
   menuTotalIndex := 0
   menuHotkeys := "|"
   menuJITmap := {}, menuJITlist := []  ; [phase D] HMENU -> builder map for the WM_INITMENUPOPUP hook
   If (applyFilter=1)
   {
      Menu, PVbar, Add, >>, dummy
      Gui, PVwin: Menu, PVbar
      ; GetClientSize(mainWidth, mainHeight, PVhwnd)
   }

   rr := 0
   hMenuBar := DllCall("GetMenu", "UPtr", PVhwnd, "UPtr")
   hMenuBar := "0x" Format("{:x}", hMenuBar)
   Loop, Parse, menusList, |
   {
      ; generate the list of hotkeys for the menu bar items: eg. alt + f
      k := StrSplit(A_LoopField, ":")
      n := SubStr(k[1], 1, 1)
      n2 := SubStr(k[1], 2, 1)
      lbl := (forbiddenAltKeys(n) || InStr(menuHotkeys, "!" n "|")) ? k[1] : "&" k[1]
      ; [phase D] every bar item carries its REAL dropdown as an attached submenu, so
      ; Windows provides hover-switching, F10 and Alt-accelerators natively; the
      ; dropdown content is rebuilt just-in-time by the WM_INITMENUPOPUP hook via
      ; menuJITmap [see uiCallWndProc / uiMenuJITrebuild]. The old flow [bar click ->
      ; invokeMenuBarItem -> post -> builder -> Menu Show] and its MSAA hover
      ; machinery are gone.
      suffix := k[2]
      menaName := uiMenuNameForBuilder(suffix)
      hSub := 0
      Try hSub := MenuGetHandle(menaName)
      If !hSub
      {
         Menu, % menaName, Add, building the menu..., dummy
         Try hSub := MenuGetHandle(menaName)
      }
      rr := uiKmenu(lbl, ":" menaName, hMenuBar, applyFilter)
      If (rr=-1)
         Break

      If hSub
      {
         menuJITmap[hSub] := "InvokeMenuBar" suffix
         menuJITlist.Push("InvokeMenuBar" suffix)
      }

      If !InStr(lbl, "&")
      {
         lbl := (forbiddenAltKeys(n2) || InStr(menuHotkeys, "!" n2 "|")) ? k[1] : n "&" SubStr(k[1], 2)
         menuHotkeys .= (!InStr(menuHotkeys, "!" n2 "|") && InStr(lbl, "&")) ? "!" n2 "|" : ".|"
      } Else
         menuHotkeys .= (!InStr(menuHotkeys, "!" n "|") && InStr(lbl, "&")) ? "!" n "|" : ".|"
   }

   If (applyFilter=1)
      Menu, PVbar, Delete, >>

   If (rr=-1)
      Menu, PVbar, Add, >>, MenuBonusOptions
}

MenuBonusOptions() {
  SoundBeep 
}

forbiddenAltKeys(n) {
   If (thumbsDisplaying=1)
      Return isVarEqualTo(n, "e","u")
   Else
      Return isVarEqualTo(n, "a","e","u","p","r","y","g")
}

simpleGetMenuItemRect(hwnd, hMenuBar, indexu, ByRef mX, ByRef mY, ByRef mW, ByRef mH) {
    rect := GetMenuItemRect(hwnd, hMenuBar, indexu - 1)
    mX := Trim(rect.left)
    mY := Trim(rect.bottom)
    mYz := Trim(rect.top)
    mH := max(rect.bottom, rect.top) - min(rect.bottom, rect.top)
    mW := max(rect.left, rect.right) - min(rect.left, rect.right)
}

uiKmenu(labelu, funcu, hMenuBar, applyFilter, mena:="PVbar", actu:="Add") {
   If (actu="add")
   {
      If (funcu="-")
         Menu, % mena, % actu
      Else
         Menu, % mena, % actu, % labelu, % funcu

      menuTotalIndex++
      If (applyFilter=1)
      {
          simpleGetMenuItemRect(PVhwnd, hMenuBar, menuTotalIndex, mX, mY, mW, mH)
          JEE_ScreenToClient(PVhwnd, mX, mY, mX, mY)
          If (abs(mY)>3)
          {
             menuTotalIndex--
             Menu, % mena, Delete, % labelu
             Return -1
          }
      }

      t := StrReplace(labelu, "&")
      menuArray[menuTotalIndex] := [t, funcu, labelu, "Enable"]
      menuArray[t] := [funcu, menuTotalIndex, labelu]
      ; fnOutDebug(A_ThisFunc "(" menuTotalIndex "): " mX + mW "|" mY "||" mW "|" mH "||" mainWidth)
   }
}

; [merge] tlbrInitPrefs() is gone: it re-parsed the 7 toolbar prefs the main script
; pushed across the thread boundary; detectToolbar() reads the shared globals now.

updateTlbrPosition() {
  If (lockToolbar2Win!=1 || ShowAdvToolbar!=1)
     Return

  JEE_ClientToScreen(PVhwnd, 0, 0, UserToolbarX, UserToolbarY)
  ; fnOutDebug(UserToolbarX "|" UserToolbarY)
  tX := Round(UserToolbarX),    tY := Round(UserToolbarY)
  WinMove, ahk_id %hQPVtoolbar%, , % tX, % tY
  SetTimer, uiUpdateUIctrl, -100
  ; Gui, OSDguiToolbar: Show, NoActivate x%tX% y%tY%, QPV toolbar
}

UpdateMenuBar(modus:=0, tt:=0) {
   Static hasRan := 0, prevState
   If !hasRan
   {
      Menu, PVmanu, Add, MENU, dummy
      hasRan := 1
   }

   thisState := "a" imgEditPanelOpened tt AnyWindowOpen thumbsDisplaying maxFilesIndex drawingShapeNow modus undoLevelsRecorded showMainMenuBar isNowAlphaPainting()
   ; ToolTip, % "lol"  isNowAlphaPainting() isAlphaMaskWindow()  , , , 2
   If !showMainMenuBar
      prevState := thisState

   ; ToolTip, % thisState "`n" prevState , , , 2
   If (prevState=thisState)
   {
      ; updateTlbrPosition()
      SetTimer, updateTlbrPosition, -300
      Return
   }

   ; ToolTip, % "l = " modus , , , 2
   ; If (thumbsDisplaying=1)
   ;    uiAccessUpdateUiStatusBar(0, 0, "list", 0)
   ; Else 
   ;    uiUpdateUIctrl()

   lastMenuBarUpdate := A_TickCount
   Gui, PVwin: Menu, PVmanu
   Try Menu, PVbar, Delete
   If (showMainMenuBar!=1)
   {
      Sleep, -1
      Gui, PVwin: Menu
      Return
   }

   ; Sleep, -1
   BuildMenuBar(modus, 0)
   ; SetMenuInfo(MenuGetHandle("PVbar"), 2, 1, 0, 1)
   ; Sleep, -1
   ; Gui, PVwin: Menu, PVmanu
   Gui, PVwin: Menu, PVbar
   lastMenuBarUpdate := A_TickCount

   prevState := thisState
   ; updateTlbrPosition()
   SetTimer, updateTlbrPosition, -300
}

VarContainsThis(value, vals*) {
   yay := 0
   for index, param in vals
   {
       If InStr(value, param)
       {
          yay := 1
          Break
       }
   }
   Return yay
}

preByeRoutine() {
    canCancelImageLoad := 4
    If (AnyWindowOpen || animGIFplaying=1 || slideShowRunning=1 || thumbsDisplaying=1)
       lastOtherWinClose := A_TickCount
    byeByeRoutine()
}

uiKeyboardResponder(givenKey, abusive) {
    ; ToolTip, % givenKey "=" abusive "=" runningLongOperation "|" mustAbandonCurrentOperations , , , 2
    If isVarEqualTo(givenKey, "Left","Right","Up","Down","PgUp","PgDn","Home","End","BackSpace","Delete","Enter")
    {
       If (runningLongOperation=1 && givenKey="Enter")
       {
          preByeRoutine()
       } Else If (slideShowRunning=1)
       {
          turnOffSlideshow()
       } Else If (animGIFplaying!=0 || canCancelImageLoad=1) || (thumbsDisplaying=1 && imageLoading=1)
       {
          alterFilesIndex++
          canCancelImageLoad := 4
          If (givenKey!="PLUS" && givenKey!="MINUS")   ; plus/minus
             stopGiFsPlayback()

       } Else callMain := 1
    } Else If (givenKey="Escape" || givenKey="!F4")
    {
       preByeRoutine()
    } Else If (givenKey="Space")
    {
       isOkay := AnyWindowOpen ? 0 : 1
       If (AnyWindowOpen && imgEditPanelOpened=1)
          isOkay := 1

       stopGiFsPlayback()
       If (slideShowRunning=1)
          turnOffSlideshow()
       Else If (thumbsDisplaying!=1 && isOkay && maxFilesIndex>0 && slideShowRunning!=1 && IMGresizingMode=4)
          uiChangeMcursor("move")
       Else callMain := 1
    } Else callMain := 1

    isOkay := (imageLoading=1 && animGIFplaying!=1) ? 0 : 1
    ; ToolTip, % callMain "=" isOkay "(" imageLoading "|" animGIFplaying ")=" runningLongOperation "=" whileLoopExec "=" givenKey , , , 2
    If (callMain=1 && isOkay=1 && runningLongOperation!=1 && whileLoopExec!=1 && givenKey)
    {
       MT_post("KeyboardResponder", givenKey, PVhwnd, abusive, navKeysCounter)
    }
}

uiPreProcessKbdKey() {
   Static lastInvoked := 1, counter := 0, prevKey
   If (!identifyThisWin() || (A_TickCount - lastOtherWinClose<300))
      Return

   ; ToolTip, % hotkate , , , 2
   If (A_TickCount - lastInvoked>250)
      counter := 0

   If isVarEqualTo(hotkate, "Escape","Enter","Space")
   {
       pp := (animGIFplaying=1 || slideShowRunning=1) ? 1 : 0
       If (animGIFplaying=1)
          stopGiFsPlayback()
       If (slideShowRunning=1)
          turnOffSlideshow()
       If pp
          Return
   }

   If ((A_TickCount - lastInvoked>30) && (whileLoopExec=0 && runningLongOperation=0 || isVarEqualTo(givenKey, "Escape", "Enter","!F4")))
   {
      lastInvoked := A_TickCount
      abusive := (counter>25) ? 1 : 0
      OutputDebug, % "QPVMERGE: kbd dispatch hotkate=" hotkate " via " Exception("", -2).What
      uiKeyboardResponder(hotkate, abusive)
      ; MT_post("KeyboardResponder", hotkate, PVhwnd, abusive)
      If (hotkate=prevKey)
         counter++
      Else 
         counter := 0

      prevKey := hotkate
   } Else If (hotkate=prevKey)
      counter++
   Else 
      counter := 0
}

uiWM_KEYDOWN(wParam, lParam, msg, hwnd) {
    ; [phase D, per Marius] Alt+letter must open the bar menu as NATIVE bar
    ; tracking [so Left/Right switch menus, like a mouse open] instead of the old
    ; detached positioned popup. Merely returning empty and hoping DefWindowProc
    ; activates the mnemonic does NOT work here [focus sits on PVwin's hidden
    ; controls and the SYSCHAR chain never completes - Alt+I went dead]; the
    ; mechanism Windows itself uses is posted instead: WM_SYSCOMMAND SC_KEYMENU
    ; with the character enters keyboard menu mode for that mnemonic natively.
    If (msg=0x104 && showMainMenuBar=1 && wParam>=0x41 && wParam<=0x5A)
    {
       If InStr(menuHotkeys, "!" Chr(wParam + 32) "|")
       {
          DllCall("user32\PostMessageW", "Ptr", PVhwnd, "UInt", 0x0112, "Ptr", 0xF100, "Ptr", wParam + 32)
          Return 0
       }
    }
    If (msg=0x104 && wParam=0x20)
    {
       ; Alt+Space: the very same mechanism - SC_KEYMENU with the SPACE character
       ; is what DefWindowProc generates for the real Alt+Space, and Windows opens
       ; the SYSTEM menu natively [position, Alt-held semantics, keyboard nav all
       ; native]. It replaced the thread-era TrackPopupMenu emulation, which stopped
       ; opening anything after the merge and was deleted; Win_ShowSysMenu in
       ; shell-stuff.ahk stays as the library helper for a programmatic sys menu.
       OutputDebug, % "QPVMERGE: Alt+Space -> native SC_KEYMENU sysmenu post"
       DllCall("user32\PostMessageW", "Ptr", PVhwnd, "UInt", 0x0112, "Ptr", 0xF100, "Ptr", 0x20)
       Return 0
    }
    vk_code := Format("{1:x}", wParam)
    If (isInRange(vk_code, 21, 28) || isVarEqualTo(vk_code, "6B", "6D", "BB", "BD", "D"))
       navKeysCounter++

    If (statusBarTooltipVisible=1)
       mouseTurnOFFtooltip()

    If (A_TickCount - lastOtherWinClose<300)
       Return 0

    If (vk_code!="1B")
    {
       If ((whileLoopExec=1 || runningLongOperation=1 || imageLoading=1) && animGIFplaying!=1 && slideShowRunning!=1)
          Return 0
    } Else
    {
       ; escape key was pressed
       preByeRoutine()
       Return 0
    }

    vk_shift := DllCall("GetKeyState","Int", 0x10, "short") >> 16
    vk_ctrl := DllCall("GetKeyState","Int", 0x11, "short") >> 16
    vk_alt := (msg=260) ? -1 : DllCall("GetKeyState","Int", 0x12, "short") >> 16
    hotkate := constructKbdKey(vk_shift, vk_ctrl, vk_alt, vk_code)
    ; ToolTip, % vk_code "|" whileLoopExec "|" runningLongOperation "|" imageLoading "|" animGIFplaying "|" hotkate , , , 2
    If (vk_code!=10 && vk_code!=11 && vk_code!=12)
    {
       SetTimer, uiPreProcessKbdKey, -3
       Return 0
    }

    ; TulTip("|   ", wParam, vk_shift, vk_ctrl, vk_alt, msg, "ui thread")
}

uiVisibleMenuWin() {
; [merge] The main script runs DetectHiddenWindows ON, and a HIDDEN #32768 window
; persists in the process once any menu has ever shown - probing without a
; visibility check matches it forever. Every menu-window probe in this module
; goes through here, so it sees what the old interface interpreter [DHW off] saw.
   h := WinExist("ahk_class #32768 ahk_pid " QPVpid)
   If (h && DllCall("user32\IsWindowVisible", "UPtr", h))
      Return h
   Return 0
}

identifyMenus(){
; Without the visibility filter [see uiVisibleMenuWin] this would return 1 forever
; and the menu-reader #If hotkeys below [RButton, Left, Right, Space...] would
; swallow those keys SYSTEM-WIDE.
   Return uiVisibleMenuWin() ? 1 : 0
}

; [phase D] the menu-reader #If hotkey block is gone: hotkey subroutines never
; run during same-interpreter menu loops [probe p4], so it could not function
; after the merge. Its features ride the hooks now: wheel + RButton-announce via
; uiMenuMouseLL, announcements via uiMenuSelectTrack, native Left/Right/F10.

ShowClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu:="", stay:=0) {
    Static lastInvoked := 1, wasCreated := 0, hClickHalo

    Critical, On
    If ((A_TickCount - lastInvoked < 100) || !BoxW || !BoxH)
       Return

    lastInvoked := A_TickCount
    If (!mX && !mY)
       GetPhysicalCursorPos(mX, mY)

    If (boxMode=0)
    {
       mX := mX - BoxW//2
       mY := mY - BoxW//2
    }

    If (wasCreated=1)
    {
       displayClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu, hClickHalo, stay)
       Return
    }

    Gui, MclickH: Destroy
    Sleep, 20
    modus := msgu ? "" : "+E0x20 +E0x8000000"
    Gui, MclickH: +AlwaysOnTop -DPIScale -Caption +ToolWindow +Owner %modus% +hwndhClickHalo
    Gui, MclickH: Color, 0099FF
    ; Gui, MclickH: Show, NoActivate Hide x%mX% y%mY% w%BoxW% h%BoxH%, WinMouseClick
    ; WinSet, ExStyle, 0x20, WinMouseClick
    If !msgu
       msgu := "QPV blip"

    ; fnOutDebug(msgu "|" stay)
    displayClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu, hClickHalo, stay)
    WinSet, Transparent, 128, ahk_id %hClickHalo%
}

displayClickHalo(mX, mY, BoxW, BoxH, boxMode, msgu, hwnd, stay) {
    If (mX!="" && mY!="")
       Gui, MclickH: Show, NoActivate x%mX% y%mY% w%BoxW% h%BoxH%, %msgu% ; ahk_id %hClickHalo%

    If (boxMode=0)
       WinSet, Region, 0-0 W%BoxW% H%BoxH% E, ahk_id %hwnd%
    Else
       WinSet, Region,, ahk_id %hwnd%

    WinSet, AlwaysOnTop, On, ahk_id %hwnd%
    If !stay
       SetTimer, DestroyClickHalo, -300
}

DestroyClickHalo() {
    Gui, MclickH: Hide
}

uiRepositionWindowCenter(whichGUI, hwndGUI, referencePoint, winTitle:="", winPos:="") {
    If !winPos
    {
       SysGet, MonitorCount, 80
       ActiveMonDetails := calcScreenLimits(referencePoint)
       ResWidth := ActiveMonDetails.w, ResHeight:= ActiveMonDetails.h
       mCoordLeft := ActiveMonDetails.mCLeft
       mCoordTop := ActiveMonDetails.mCTop
    }

    If (MonitorCount>1 && !winPos && A_OSVersion!="WIN_XP")
    {
       ; center window on the monitor/screen where the mouse cursor is
       semiFinal_x := mCoordLeft + 2
       semiFinal_y := mCoordTop + 2
       If !semiFinal_y
          semiFinal_y := 1
       If !semiFinal_x
          semiFinal_x := 1

       Gui, %whichGUI%: Show, Hide AutoSize x%semiFinal_x% y%semiFinal_y%, % winTitle
       Sleep, 25
       GetWinClientSize(msgWidth, msgHeight, hwndGUI, 1)
       If !msgWidth
          msgWidth := 1
       If !msgHeight
          msgHeight := 1

       Final_x := Round(mCoordLeft + ResWidth/2 - msgWidth/2)
       Final_y := Round(mCoordTop + ResHeight/2 - msgHeight/2)
       If (!Final_x) || (Final_x + 1<mCoordLeft)
          Final_x := mCoordLeft + 1
       If (!Final_y) || (Final_y + 1<mCoordTop)
          Final_y := mCoordTop + 1
       If !Final_y
          Final_y := A_ScreenHeight//3
       If !Final_x
          Final_x := A_ScreenWidth//3
       Gui, %whichGUI%: Show, x%Final_x% y%Final_y%, % Chr(160) winTitle
    } Else Gui, %whichGUI%: Show, AutoSize %winPos%, % Chr(160) winTitle

}

AccGetLocation(Acc, ChildId=0) {
  Static x := 0, y := 0, w := 0, h := 0
  coord := []
  try Acc.accLocation(ComObj(0x4003,&x), ComObj(0x4003,&y), ComObj(0x4003,&w), ComObj(0x4003,&h), ChildId)
  coord.x := NumGet(x,0,"int"),  coord.y := NumGet(y,0,"int")
  coord.w := NumGet(w,0,"int"),  coord.h := NumGet(h,0,"int")
  ; AccCoord[1]:=NumGet(x,0,"int"), AccCoord[2]:=NumGet(y,0,"int"), AccCoord[3]:=NumGet(w,0,"int"), AccCoord[4]:=NumGet(h,0,"int")
  Return coord
}

GetClientSize(ByRef w, ByRef h, hwnd) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
    Static prevW, prevH, lastInvoked := 1
    If (A_TickCount - lastInvoked<95)
    {
       W := prevW
       H := prevH
       Return
    }

    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    prevW := W := NumGet(rc, 8, "int")
    prevH := H := NumGet(rc, 12, "int")
    lastInvoked := A_TickCount
} 

